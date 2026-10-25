# Paths of nonconvex penalties by local linear approximation (reweighted ℓ1),
# and the guard of the exact-proximal paths of MCP and SCAD.

module LLAPathsTests

using Test, LinearAlgebra, Random, SparseArrays
using ProximalBase
using ProximalSolvers
const PS = ProximalSolvers

# columns of mean zero and unit variance, so that the curvatures of (1/n)‖y - Xb‖²/2 are 1
function standardized(rng, n, p)
  X = randn(rng, n, p)
  X .-= sum(X; dims = 1) ./ n
  X ./= sqrt.(sum(abs2, X; dims = 1) ./ n)
  X
end

function lladata(; n = 80, p = 50, seed = 7)
  rng = Xoshiro(seed)
  X = standardized(rng, n, p)
  β = zeros(p); β[1:4] .= [2, -1.5, 1, -1]; β[11:13] .= [1, 1, -1]
  X, X * β + 0.5 * randn(rng, n)
end

const TIGHT = CDSolver(; tol = 1e-12)
cov_(Z) = (Zc = Z .- sum(Z; dims = 1) ./ size(Z, 1); Zc' * Zc / (size(Z, 1) - 1))
atlevel(g::Union{MCP, SCAD}, λ) = typeof(g).name.wrapper(λ, g.a)
atlevel(g::CappedL1, λ) = CappedL1(λ, g.a, g.w)
atlevel(g::LogPenalty, λ) = LogPenalty(λ, g.ε, g.w)
atlevel(g::NormL1, λ) = NormL1(λ, g.w)
atlevel(g::GroupMCP, λ) = GroupMCP(λ, g.groups, g.w; a = g.a)
atlevel(g::GroupSCAD, λ) = GroupSCAD(λ, g.groups, g.w; a = g.a)

# a stage by hand: the weighted lasso at the level λ with the weights of gλ at x
stage_penalty(gλ, λ, x) = NormL1(λ, lla_weights(gλ, Vector(x)) ./ λ)
group_stage_penalty(gλ, λ, x) = GroupNormL2(λ, gλ.groups, lla_weights(gλ, Vector(x)) ./ λ)

X, y = lladata()
n, p = size(X)
f = (1 / n) * LeastSquaresLoss(y, X)
w = 0.5 .+ rand(Xoshiro(2), p)
penalties = (MCP(1.0, 3.0), SCAD(1.0, 3.7), CappedL1(1.0, 0.5), CappedL1(1.0, 0.5, w), LogPenalty(1.0, 0.5, w))

@testset "the stages of a level, from the lasso" begin
  for g in penalties
    λmax = lambda_max(f, g, SparseIterate(p))
    # just above λmax the lasso is zero, and the weights do not change (at λmax
    # itself rounding can leave an entry of order eps)
    λs = λmax .* [1.001; exp.(range(log(0.8), log(0.05); length = 7))]
    r = solve_path(f, g, λs, LLA(TIGHT))
    @test r.λ == λs
    @test r.stages[1] == 1
    @test iszero(r.solutions[1])
    w0 = lla_weights(atlevel(g, 1.0), zeros(p))
    for (k, λ) in enumerate(λs)
      x1 = SparseIterate(p)
      solve!(x1, f, NormL1(λ, w0), TIGHT)
      x2 = copy(x1)
      g2 = stage_penalty(atlevel(g, λ), λ, x1)
      solve!(x2, f, g2, TIGHT)
      @test Vector(r.solutions[k]) ≈ Vector(x2) atol = 1e-7
      # a second stage unless the weights did not change, as for a capped ℓ1
      # penalty when the lasso has no entry beyond the cap
      @test r.stages[k] == (maximum(abs.(g2.w .- w0)) <= 1e-12 * maximum(w0) ? 1 : 2)
      b = Vector(r.solutions[k])
      @test r.values[k] ≈ f(b) + atlevel(g, λ)(b)
    end
    # screening changes nothing; nor does the order of the coordinates
    r2 = solve_path(f, g, λs, LLA(TIGHT); screening = false)
    @test maximum(norm.(r.solutions .- r2.solutions, Inf)) < 1e-8
    @test sum(r2.kkt_checks) == 0
    @test all(r.converged)
    # the checks of screening: one per stage when the strong set is right
    @test sum(r.kkt_checks) >= sum(r.stages)
  end
end

@testset "more stages decrease the objective" begin
  for g in penalties
    λmax = lambda_max(f, g, SparseIterate(p))
    λs = λmax .* exp.(range(log(0.5), log(0.05); length = 5))
    vals = [solve_path(f, g, λs, LLA(TIGHT; stages)).values for stages in (1, 2, 3, 6)]
    for j in 1:3
      @test all(vals[j + 1] .<= vals[j] .+ 1e-10)
    end
  end
end

@testset "stages until the weights stop changing" begin
  for g in penalties
    λmax = lambda_max(f, g, SparseIterate(p))
    λs = λmax .* [0.6, 0.3, 0.1]
    tol = g isa CappedL1 ? 1e-12 : 1e-10      # the capped ℓ1 weights repeat
    r = solve_path(f, g, λs, LLA(TIGHT; stages = 200, tol))
    @test all(r.stages .< 200)
    for (k, λ) in enumerate(λs)
      # a fixed point: the weighted lasso of its own weights, so a stationary point of f + g
      b = Vector(r.solutions[k])
      gr = X' * (X * b - y) / n
      wb = lla_weights(atlevel(g, λ), b)
      for j in 1:p
        if iszero(b[j])
          @test abs(gr[j]) <= wb[j] + 1e-7
        else
          @test abs(gr[j] + wb[j] * sign(b[j])) <= 1e-6
        end
      end
    end
  end
end

@testset "first weights from the previous level" begin
  for g in penalties
    λmax = lambda_max(f, g, SparseIterate(p))
    λs = λmax .* exp.(range(0, log(0.05); length = 6))
    r = solve_path(f, g, λs, LLA(TIGHT; start = :previous))
    xp = SparseIterate(p)
    for (k, λ) in enumerate(λs)
      gλ = atlevel(g, λ)
      x1 = copy(xp)
      solve!(x1, f, stage_penalty(gλ, λ, xp), TIGHT)
      x2 = copy(x1)
      w1, w2 = lla_weights(gλ, Vector(xp)), lla_weights(gλ, Vector(x1))
      maximum(abs.(w1 .- w2)) <= 1e-12 * maximum(w1) || solve!(x2, f, stage_penalty(gλ, λ, x1), TIGHT)
      @test Vector(r.solutions[k]) ≈ Vector(x2) atol = 1e-7
      xp = x2
    end
    r2 = solve_path(f, g, λs, LLA(TIGHT; start = :previous); screening = false)
    @test maximum(norm.(r.solutions .- r2.solutions, Inf)) < 1e-8
  end
end

@testset "the lasso is its own linearization" begin
  λmax = lambda_max(f, NormL1(1.0, w), SparseIterate(p))
  λs = λmax .* exp.(range(0, log(0.02); length = 10))
  r = solve_path(f, NormL1(1.0, w), λs, LLA(TIGHT))
  rl = solve_path(f, NormL1(1.0, w), λs, TIGHT; gaptol = 0)
  @test all(==(1), r.stages)
  @test all(==(1), rl.stages)
  @test maximum(norm.(r.solutions .- rl.solutions, Inf)) < 1e-8
  @test r.values ≈ rl.values
end

@testset "group MCP and group SCAD" begin
  groups = [3(k - 1)+1:3k for k in 1:div(p, 3)]
  push!(groups, 49:50)
  for g in (GroupMCP(1.0, groups; a = 3.0), GroupSCAD(1.0, groups; a = 3.7))
    x0 = AtomIterate(p, g)
    λmax = lambda_max(f, g, x0)
    λs = λmax .* exp.(range(0, log(0.05); length = 6))
    r = solve_path(f, g, λs, LLA(TIGHT); x = AtomIterate(p, g))
    w0 = lla_weights(atlevel(g, 1.0), zeros(p))
    @test w0 ≈ g.w
    for (k, λ) in enumerate(λs)
      x1 = AtomIterate(p, g)
      solve!(x1, f, GroupNormL2(λ, groups, w0), TIGHT)
      x2 = copy(x1)
      solve!(x2, f, group_stage_penalty(atlevel(g, λ), λ, x1), TIGHT)
      @test Vector(r.solutions[k]) ≈ Vector(x2) atol = 1e-7
      @test r.values[k] ≈ f(Vector(x2)) + atlevel(g, λ)(Vector(x2)) atol = 1e-9
    end
    r2 = solve_path(f, g, λs, LLA(TIGHT); x = AtomIterate(p, g), screening = false)
    @test maximum(norm.(r.solutions .- r2.solutions, Inf)) < 1e-8
    r3 = solve_path(f, g, λs, LLA(TIGHT; start = :previous, stages = 50, tol = 1e-10); x = AtomIterate(p, g))
    @test all(r3.stages .< 50)
    # a group penalty needs an AtomIterate
    @test_throws ArgumentError solve_path(f, g, λs, LLA())
  end
end

@testset "logistic regression, and a quadratic" begin
  rng = Xoshiro(5)
  Xl = standardized(rng, 120, 20)
  yl = Float64.(rand(rng, 120) .< 1 ./ (1 .+ exp.(-Xl[:, 1] .+ Xl[:, 2])))
  fl = (1 / 120) * LogisticLoss(yl, Xl)
  g = MCP(1.0, 3.0)
  λmax = lambda_max(fl, g, SparseIterate(20))
  λs = λmax .* [1.0, 0.5, 0.2]
  r = solve_path(fl, g, λs, LLA(TIGHT))
  for (k, λ) in enumerate(λs)
    x1 = SparseIterate(20)
    solve!(x1, fl, NormL1(λ), TIGHT)
    x2 = copy(x1)
    solve!(x2, fl, stage_penalty(atlevel(g, λ), λ, x1), TIGHT)
    @test Vector(r.solutions[k]) ≈ Vector(x2) atol = 1e-6
  end
  # a quadratic: the same path as least squares
  fq = QuadraticFunction(X' * X / n, -X' * y / n)
  λs = lambda_max(f, g, SparseIterate(p)) .* [0.5, 0.2]
  rq = solve_path(fq, SCAD(1.0, 3.7), λs, LLA(TIGHT))
  rf = solve_path(f, SCAD(1.0, 3.7), λs, LLA(TIGHT))
  @test maximum(norm.(rq.solutions .- rf.solutions, Inf)) < 1e-7
end

@testset "one level: solve! with LLA" begin
  g = MCP(1.0, 3.0)
  λ = 0.2 * lambda_max(f, g, SparseIterate(p))
  x = SparseIterate(p)
  res = solve!(x, f, MCP(λ, 3.0), LLA(TIGHT))
  @test res isa ReweightResults
  @test res.minimizer === x
  @test res.iterations == 2 && !res.converged
  @test res.penalty isa NormL1
  rp = solve_path(f, g, [λ], LLA(TIGHT))
  @test Vector(x) ≈ Vector(rp.solutions[1]) atol = 1e-8
  # the one-step estimator of Zou and Li from the least-squares fit
  b0 = X \ y
  x = SparseIterate(b0)
  res = solve!(x, f, SCAD(λ, 3.7), LLA(TIGHT; stages = 1))
  @test res.iterations == 1
  xr = SparseIterate(b0)
  solve!(xr, f, stage_penalty(SCAD(λ, 3.7), λ, b0), TIGHT)
  @test Vector(x) ≈ Vector(xr) atol = 1e-8
  # until the weights repeat, for the capped ℓ1 penalty
  x = SparseIterate(p)
  res = solve!(x, f, CappedL1(λ, 0.5), LLA(TIGHT; stages = 100))
  @test res.converged && res.iterations < 100 && res.change <= 1e-12
  # at the level zero the stages have no penalty
  x = SparseIterate(p)
  solve!(x, f, MCP(0.0, 3.0), LLA(TIGHT))
  @test Vector(x) ≈ b0 atol = 1e-7
  # a group penalty on its AtomIterate
  groups = [1:25, 26:50]
  x = AtomIterate(p, groups)
  res = solve!(x, f, GroupSCAD(0.3, groups; a = 3.7), LLA(TIGHT))
  @test res.penalty isa GroupNormL2
  @test_throws ArgumentError solve!(SparseIterate(p), f, ElasticNet(1.0, 1.0), LLA())
end

@testset "λmax of the capped ℓ1 and log penalties" begin
  x0 = SparseIterate(p)
  λl = lambda_max(f, NormL1(1.0, w), x0)
  @test lambda_max(f, CappedL1(0.3, 0.5, w), x0) ≈ λl
  @test lambda_max(f, LogPenalty(0.3, 0.25, w), x0) ≈ 0.25 * λl
  @test lambda_max(f, CappedL1(0.3, 0.5), x0) ≈ lambda_max(f, NormL1(1.0), x0)
  # zero at λmax, not below
  for g in (CappedL1(1.0, 0.5, w), LogPenalty(1.0, 0.25, w))
    λmax = lambda_max(f, g, x0)
    r = solve_path(f, g, λmax .* [1 + 1e-9, 0.99], LLA(TIGHT))
    @test iszero(r.solutions[1]) && !iszero(r.solutions[2])
  end
end

@testset "early stops and errors" begin
  g = MCP(1.0, 3.0)
  λs = lambda_max(f, g, SparseIterate(p)) .* exp.(range(0, log(0.01); length = 30))
  r = solve_path(f, g, λs, LLA(); maxnnz = 5)
  @test length(r.λ) < 30 && nnz(r.solutions[end]) > 5
  seen = Int[]
  r = solve_path(f, g, λs, LLA(); callback = (k, λ, x, m) -> (push!(seen, k); k == 4))
  @test length(r.λ) == 4 && seen == 1:4
  @test isempty(solve_path(f, g, Float64[], LLA()).λ)
  @test_throws ArgumentError LLA(; stages = 0)
  @test_throws ArgumentError LLA(; tol = -1)
  @test_throws ArgumentError LLA(; start = :zero)
  @test_throws ArgumentError solve_path(f, g, [0.1, 0.2], LLA())
  @test_throws ArgumentError solve_path(f, g, [0.1, -0.2], LLA())
  @test_throws ArgumentError solve_path(f, ElasticNet(1.0, 1.0), [0.1], LLA())
  @test_throws "infinite slope" solve_path(f, NormLq(1.0, 0.5), [0.1], LLA())
  @test_throws DimensionMismatch solve_path(f, CappedL1(1.0, 0.5, ones(3)), [0.1], LLA())
end

# a model that gives only its steps, not its curvatures
struct StepOnly{M} <: PS.CDModel{Float64}
  m::M
end
PS.initialize!(s::StepOnly, x) = PS.initialize!(s.m, x)
PS.coordinate_step!(s::StepOnly, g, x::SparseIterate, k::Int) = PS.coordinate_step!(s.m, g, x, k)
PS.loss_value(s::StepOnly, x) = PS.loss_value(s.m, x)
ProximalBase.gradient!(G, s::StepOnly, x) = gradient!(G, s.m, x)

@testset "the guard of exact-proximal MCP and SCAD paths" begin
  # columns of variance 0.16: the curvatures are 0.16
  fs = (1 / n) * LeastSquaresLoss(y, 0.4 .* X)
  λs = [0.3, 0.1]
  for g in (MCP(1.0, 3.0), SCAD(1.0, 3.7), Constrained(MCP(1.0, 3.0), IndBox(-1, 1)))
    @test_throws ArgumentError solve_path(fs, g, λs)
    @test_throws "coordinate 1" solve_path(fs, g, λs)
    @test_throws ArgumentError solve!(SparseIterate(p), fs, PS._with_level(g, 0.1), CDSolver(); continuation = 5)
    # a single solve, and LLA, are left alone
    @test solve!(SparseIterate(p), fs, PS._with_level(g, 0.1), CDSolver()).converged
  end
  @test solve_path(fs, MCP(1.0, 3.0), λs, LLA()).stages == [2, 2]
  # a larger a passes: a·L = 1.12 and (a - 1)·L = 1.12
  @test length(solve_path(fs, MCP(1.0, 7.0), λs).λ) == 2
  @test length(solve_path(fs, SCAD(1.0, 8.0), λs).λ) == 2
  @test solve!(SparseIterate(p), fs, MCP(0.1, 7.0), CDSolver(); continuation = 3).converged
  # standardized columns, the convention of ncvreg, pass with a > 1 and a > 2
  @test length(solve_path(f, MCP(1.0, 1.5), λs).λ) == 2
  @test length(solve_path(f, SCAD(1.0, 2.5), λs).λ) == 2
  # a zero column, which the loss does not depend on, is not checked
  X0 = copy(X); X0[:, 3] .= 0
  @test length(solve_path((1 / n) * LeastSquaresLoss(y, X0), MCP(1.0, 3.0), λs).λ) == 2
  # logistic regression by coordinate descent: the curvature bound is 1/4 on standardized columns
  rng = Xoshiro(5)
  Xl = standardized(rng, 100, 10)
  yl = Float64.(rand(rng, 100) .< 0.5)
  fl = (1 / 100) * LogisticLoss(yl, Xl)
  @test_throws ArgumentError solve_path(fl, MCP(1.0, 3.0), [0.1, 0.05])
  @test length(solve_path(fl, MCP(1.0, 5.0), [0.1, 0.05]).λ) == 2
  # groups: the curvature of the group
  groups = [1:5, 6:10]
  Xg = 0.4 .* X[:, 1:10]
  fg = (1 / n) * LeastSquaresLoss(y, Xg)
  gm = GroupMCP(1.0, groups; a = 2.0)
  L = [eigmax(Symmetric(Xg[:, G]' * Xg[:, G] / n)) for G in groups]
  @test all(2 .* L .<= 1)
  @test_throws "group 1" solve_path(fg, gm, λs; x = AtomIterate(10, gm))
  @test_throws ArgumentError solve_path(fg, GroupSCAD(1.0, groups; a = 3.0), λs; x = AtomIterate(10, gm))
  # a group of weight zero is not penalized, and not checked
  fx = (1 / n) * LeastSquaresLoss(y, [Xg X[:, 11:15]])
  gz = GroupMCP(1.0, [groups; [11:15]], [0.0, 0.0, 1.0]; a = 2.0)
  @test length(solve_path(fx, gz, λs; x = AtomIterate(15, gz)).λ) == 2
  # a symmetric matrix: the curvature over the two entries of an off-diagonal coordinate
  rngk = Xoshiro(11)
  q = 6
  Sx = cov_(randn(rngk, 200, q)); Sy = cov_(randn(rngk, 200, q))
  C = randn(rngk, q, q); C = (C + C') / 2
  fk = KronQuadratic(Sx, Sy, C)
  @test_throws ArgumentError solve_path(fk, MCP(1.0, 0.5), [0.5, 0.2]; x = SymmetricSparseIterate(q))
  @test length(solve_path(fk, MCP(1.0, 3.0), [0.5, 0.2]; x = SymmetricSparseIterate(q)).λ) == 2
  # a model without curvatures is not checked
  ms = StepOnly(PS.cdmodel(fs, SparseIterate(p)))
  @test length(solve_path(ms, MCP(1.0, 3.0), λs; x = SparseIterate(p)).λ) == 2
end

end
