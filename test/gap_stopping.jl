# Paths and continuation stop each level on a certified relative duality gap
# (PATH_GAPTOL by default): every reported gap is at most the target and agrees
# with duality_gap recomputed from the solution; models and penalties without a
# gap keep the rule on the changes, with identical results.

module GapStoppingTests

using Test, LinearAlgebra, Random, SparseArrays, Statistics
using ProximalBase
using ProximalSolvers
const PS = ProximalSolvers

function data(; n = 100, p = 300, seed = 1)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  for j in 2:p
    @views X[:, j] .= 0.5 .* X[:, j-1] .+ sqrt(0.75) .* X[:, j]
  end
  β = zeros(p); β[randperm(rng, p)[1:10]] .= rand(rng, (-1.0, 1.0), 10)
  y = X * β + randn(rng, n)
  yb = Float64.(rand(rng, n) .< 1 ./ (1 .+ exp.(-0.5 .* (X * β))))
  X, y, yb
end

relgap(dg) = dg.gap / abs(dg.primal)

# every level of the path: the reported gap is at most gaptol, and the gap
# recomputed from the solution with gapof(k, solution) agrees with it
function checkgaps(r, gaptol, gapof)
  @test length(r.gap) == length(r.λ)
  @test all(r.converged)
  for k in eachindex(r.λ)
    @test r.gap[k] <= gaptol
    g = gapof(k, r.solutions[k])
    @test g <= gaptol * (1 + 1e-6) + 1e-14
    @test isapprox(g, r.gap[k]; rtol = 1e-3, atol = 1e-13)
  end
end

@testset "lasso paths stop on the gap" begin
  X, y, _ = data()
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  λmax = lambda_max(f, NormL1(1.0), SparseIterate(p))
  λs = λmax .* 10 .^ range(0, -2; length = 30)
  ref = solve_path(f, NormL1(1.0), λs, CDSolver(; tol = 1e-13); gaptol = 0)
  @test all(isnan, ref.gap)
  lassogap(k, s) = relgap(duality_gap(f, NormL1(λs[k]), SparseIterate(Vector(s))))
  @test PS.PATH_GAPTOL == 1e-4
  passes = Dict{Float64, Int}()
  for screening in (true, false), (kw, gaptol) in (((;), 1e-4), ((; gaptol = 1e-3), 1e-3), ((; gaptol = 1e-8), 1e-8))
    r = solve_path(f, NormL1(1.0), λs, CDSolver(; rng = Xoshiro(1)); screening, kw...)
    checkgaps(r, gaptol, lassogap)
    screening && (passes[gaptol] = sum(r.passes))
    # a relative gap ε certifies P - P* ≤ ε|P|; in practice the coefficients
    # are within about ε of the solution, relative to the largest, and about
    # 50ε at worst
    for k in eachindex(λs)
      @test r.values[k] - ref.values[k] <= gaptol * abs(ref.values[k]) + 1e-14
      @test norm(r.solutions[k] - ref.solutions[k], Inf) <= 200 * gaptol * max(norm(ref.solutions[k], Inf), 1e-3)
    end
  end
  @test passes[1e-3] < passes[1e-4] < passes[1e-8]
  # gaptol of the method is the default target; gaptol = 0 is the rule on the changes
  r = solve_path(f, NormL1(1.0), λs, CDSolver(; gaptol = 1e-5, rng = Xoshiro(1)))
  checkgaps(r, 1e-5, lassogap)
  r0 = solve_path(f, NormL1(1.0), λs, CDSolver(; rng = Xoshiro(1)); gaptol = 0)
  @test all(isnan, r0.gap)
  @test_throws ArgumentError solve_path(f, NormL1(1.0), λs; gaptol = -1)
end

@testset "weights, elastic net, intercept, sparse X" begin
  X, y, _ = data(; seed = 2)
  n, p = size(X)
  rng = Xoshiro(3)
  w = rand(rng, p) .+ 0.5
  f = (1 / n) * LeastSquaresLoss(y, X)
  for (g, gapg) in ((NormL1(1.0, w), λ -> NormL1(λ, w)), (ElasticNet(1.0, 0.1), λ -> ElasticNet(λ, 0.1)),
                    (NormL1Nonneg(1.0), λ -> NormL1Nonneg(λ)))
    λmax = lambda_max(f, g, SparseIterate(p))
    λs = λmax .* 10 .^ range(0, -1.5; length = 20)
    for screening in (true, false)
      r = solve_path(f, g, λs, CDSolver(; rng = Xoshiro(1)); screening)
      checkgaps(r, PS.PATH_GAPTOL, (k, s) -> relgap(duality_gap(f, gapg(λs[k]), SparseIterate(Vector(s)))))
    end
  end

  # an intercept, through the model, and a sparse X
  Xs = sprand(Xoshiro(4), n, p, 0.1)
  ys = Xs * [ones(5); zeros(p - 5)] + 0.5 * randn(Xoshiro(5), n) .+ 2
  for (XX, yy) in ((X, y .+ 3), (Xs, ys)), icpt in (false, true)
    fx = (1 / n) * LeastSquaresLoss(yy, XX)
    m = icpt ? cdmodel(fx, SparseIterate(p); intercept = true) : fx
    λmax = lambda_max(m, NormL1(1.0), SparseIterate(p))
    λs = λmax .* 10 .^ range(0, -1.5; length = 20)
    for screening in (true, false)
      r = solve_path(m, NormL1(1.0), λs, CDSolver(; rng = Xoshiro(1)); x = SparseIterate(p), screening)
      gapof(k, s) = icpt ? relgap(duality_gap(cdmodel(fx, SparseIterate(p); intercept = true), NormL1(λs[k]), SparseIterate(Vector(s)))) :
                           relgap(duality_gap(fx, NormL1(λs[k]), SparseIterate(Vector(s))))
      checkgaps(r, PS.PATH_GAPTOL, gapof)
    end
  end
end

@testset "group lasso and sparse group lasso paths" begin
  X, y, _ = data(; p = 120, seed = 6)
  n, p = size(X)
  groups = [collect(i:i+3) for i in 1:4:p]
  f = (1 / n) * LeastSquaresLoss(y, X)
  wg = sqrt.(length.(groups))
  g = GroupNormL2(1.0, groups, wg)
  x0 = AtomIterate(p, groups)
  λmax = lambda_max(f, g, x0)
  λs = λmax .* 10 .^ range(0, -1.5; length = 20)
  for screening in (true, false)
    r = solve_path(f, g, λs, CDSolver(; rng = Xoshiro(1)); x = AtomIterate(p, groups), screening)
    checkgaps(r, PS.PATH_GAPTOL, (k, s) -> relgap(duality_gap(f, GroupNormL2(λs[k], groups, wg), AtomIterate(Vector(s), groups))))
  end
  sg = Scaled(SparseGroupNormL2(0.5, 0.5, groups, wg), 1.0)
  λmax = lambda_max(f, sg, x0)
  λs = λmax .* 10 .^ range(0, -1.5; length = 20)
  r = solve_path(f, sg, λs, CDSolver(; rng = Xoshiro(1)); x = AtomIterate(p, groups))
  checkgaps(r, PS.PATH_GAPTOL, (k, s) -> relgap(duality_gap(f, Scaled(SparseGroupNormL2(0.5, 0.5, groups, wg), λs[k]),
                                                  AtomIterate(Vector(s), groups))))
end

@testset "logistic paths: coordinate descent and proximal Newton" begin
  X, _, yb = data(; seed = 7)
  n, p = size(X)
  f = (1 / n) * LogisticLoss(yb, X)
  λmax = lambda_max(f, NormL1(1.0), SparseIterate(p))
  λs = λmax .* 10 .^ range(0, -1.5; length = 20)
  gapof(k, s) = relgap(duality_gap(f, NormL1(λs[k]), SparseIterate(Vector(s))))
  for gaptol in (1e-3, 1e-4, 1e-8)
    checkgaps(solve_path(f, NormL1(1.0), λs, CDSolver(; rng = Xoshiro(1)); gaptol), gaptol, gapof)
    for screening in (true, false)
      r = solve_path(f, NormL1(1.0), λs, ProxNewton(; inner = CDSolver(; rng = Xoshiro(1))); gaptol, screening, devmax = 1)
      checkgaps(r, gaptol, gapof)
      # with an intercept, fitted exactly before each gap
      m = cdmodel(f, SparseIterate(p); intercept = true)
      λmi = lambda_max(m, NormL1(1.0), SparseIterate(p))
      λi = λmi .* 10 .^ range(0, -1.5; length = 20)
      r = solve_path(m, NormL1(1.0), λi, ProxNewton(; inner = CDSolver(; rng = Xoshiro(1))); x = SparseIterate(p), gaptol,
                     screening, devmax = 1)
      checkgaps(r, gaptol, (k, s) -> relgap(duality_gap(cdmodel(f, SparseIterate(p); intercept = true), NormL1(λi[k]),
                                                       SparseIterate(Vector(s)))))
    end
  end
  # gaptol = 0: the rule on the change of the objective
  r = solve_path(f, NormL1(1.0), λs, ProxNewton(); gaptol = 0, devmax = 1)
  @test all(isnan, r.gap)
end

@testset "continuation stops its last level on the gap" begin
  X, y, _ = data(; seed = 8)
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  λ = 0.05 * lambda_max(f, NormL1(1.0), SparseIterate(p))
  for (kw, gaptol) in (((;), 1e-4), ((; gaptol = 1e-3), 1e-3), ((; gaptol = 1e-8), 1e-8)), screening in (true, false)
    x = SparseIterate(p)
    r = solve!(x, f, NormL1(λ), CDSolver(; rng = Xoshiro(1)); continuation = 10, screening, kw...)
    @test r.converged
    @test r.gap <= gaptol
    @test relgap(duality_gap(f, NormL1(λ), x)) <= gaptol * (1 + 1e-6) + 1e-14
  end
  # a single solve keeps the rule on the changes
  r = solve!(SparseIterate(p), f, NormL1(λ), CDSolver())
  @test isnan(r.gap)
  r = solve!(SparseIterate(p), f, NormL1(λ), CDSolver(); continuation = 10, gaptol = 0)
  @test isnan(r.gap)
end

@testset "no gap: the rule on the changes, unchanged" begin
  X, y, _ = data(; seed = 9)
  n, p = size(X)
  # a quadratic, which has no gap: the default is the rule on the changes,
  # with identical results and no warning
  A = X' * X / n + 0.1I
  q = QuadraticFunction(A, -X' * y / n)
  λmax = lambda_max(q, NormL1(1.0), SparseIterate(p))
  λs = λmax .* 10 .^ range(0, -1.5; length = 15)
  r1 = @test_logs solve_path(q, NormL1(1.0), λs, CDSolver(; rng = Xoshiro(1)))
  r0 = solve_path(q, NormL1(1.0), λs, CDSolver(; rng = Xoshiro(1)); gaptol = 0)
  @test r1.solutions == r0.solutions && r1.passes == r0.passes && r1.values == r0.values
  @test all(isnan, r1.gap)
  # MCP has no conjugate: the same
  f = (1 / n) * LeastSquaresLoss(y, X ./ std(X; dims = 1, corrected = false))
  λm = lambda_max(f, MCP(1.0, 3.0), SparseIterate(p))
  λs = λm .* 10 .^ range(0, -1; length = 15)
  r1 = @test_logs solve_path(f, MCP(1.0, 3.0), λs, CDSolver(; rng = Xoshiro(1)))
  r0 = solve_path(f, MCP(1.0, 3.0), λs, CDSolver(; rng = Xoshiro(1)); gaptol = 0)
  @test r1.solutions == r0.solutions && r1.passes == r0.passes
  @test all(isnan, r1.gap)
  # LLA paths keep the rule on the changes
  rl = solve_path(f, MCP(1.0, 3.0), λs, LLA())
  @test all(isnan, rl.gap)
  # a coordinate without penalty with a nonzero gradient has no dual point: the
  # rule on the changes with the tolerance of the method
  w = ones(p); w[1:3] .= 0
  fl = (1 / n) * LeastSquaresLoss(y, X)
  λs = lambda_max(fl, NormL1(1.0, w), SparseIterate(p)) .* 10 .^ range(0, -1.5; length = 15)
  r1 = solve_path(fl, NormL1(1.0, w), λs, CDSolver(; rng = Xoshiro(1)))
  r0 = solve_path(fl, NormL1(1.0, w), λs, CDSolver(; tol = 1e-12, rng = Xoshiro(1)); gaptol = 0)
  @test all(r1.converged)
  @test maximum(norm(r1.solutions[k] - r0.solutions[k], Inf) for k in eachindex(λs)) < 1e-5
end

end
