# Working sets for coordinate descent: the same solutions as the plain passes,
# the stopping rule at the end, paths, gaptol, and the iterates and models that
# fall back to the plain passes.

module WorkingSetTests

using Test, LinearAlgebra, Random, Statistics
using ProximalBase
using ProximalSolvers
const PS = ProximalSolvers

function lassodata(; n = 100, p = 600, seed = 1)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  β = zeros(p); β[1:8] .= [2, -1.5, 1, -1, 0.5, 0.8, -0.6, 0.4]
  X, X * β + 0.3 * randn(rng, n), β
end

@testset "the same solutions as the plain passes" begin
  X, y, β = lassodata()
  n, p = size(X)
  rng = Xoshiro(4)
  ls = (1 / n) * LeastSquaresLoss(y, X)
  λmax = lambda_max(ls, NormL1(1.0), SparseIterate(p))
  yb = Float64.(rand(rng, n) .< 1 ./ (1 .+ exp.(-X * β)))
  logit = (1 / n) * GLMLoss(ProximalBase.Logistic(), yb, X)
  λl = lambda_max(logit, NormL1(1.0), SparseIterate(p))
  q = QuadraticFunction(X'X / n, -X'y / n)
  cases = Any[(ls, NormL1(0.05λmax)), (ls, NormL1(0.02λmax, rand(rng, p) .+ 0.5)), (ls, NormL1Nonneg(0.05λmax)),
              (ls, ElasticNet(0.05λmax, 0.1)), (ls, MCP(0.1λmax)), (ls, IndBox(-0.5, 0.5)),
              (logit, NormL1(0.1λl)), (q, NormL1(0.05λmax))]
  for (f, g) in cases, s in (CDSolver(; tol = 1e-10, workingset = true),
                             CDSolver(; tol = 1e-10, workingset = true, order = :cyclic),
                             CDSolver(; tol = 1e-10, workingset = true, momentum = false))
    xref = SparseIterate(p)
    solve!(xref, f, g, CDSolver(; tol = 1e-13))
    x = SparseIterate(p)
    r = solve!(x, f, g, s)
    @test r.converged
    @test kkt_residual(f, g, x) <= 1e-10
    Pref = f(xref) + g(xref)
    @test r.minimum <= Pref + 1e-9 * max(1, abs(Pref))
    # with the box and n < p the least-squares fit is exact and not unique
    g isa IndBox || @test norm(Vector(x) - Vector(xref)) <= 1e-6 * max(1, norm(Vector(xref)))
  end
  # an intercept, through the model
  m = cdmodel(ls, SparseIterate(p); intercept = true)
  xref, x = SparseIterate(p), SparseIterate(p)
  solve!(xref, m, NormL1(0.05λmax), CDSolver(; tol = 1e-13))
  solve!(x, m, NormL1(0.05λmax), CDSolver(; tol = 1e-10, workingset = true))
  @test norm(Vector(x) - Vector(xref)) <= 1e-6 * max(1, norm(Vector(xref)))
end

@testset "gaptol, paths and continuation" begin
  X, y, _ = lassodata(; seed = 2)
  n, p = size(X)
  ls = (1 / n) * LeastSquaresLoss(y, X)
  λmax = lambda_max(ls, NormL1(1.0), SparseIterate(p))
  x = SparseIterate(p)
  r = solve!(x, ls, NormL1(0.02λmax), CDSolver(; workingset = true, gaptol = 1e-9))
  @test r.converged && r.gap <= 1e-9
  dg = duality_gap(ls, NormL1(0.02λmax), x)
  @test dg.gap / dg.primal <= 1e-9 * (1 + 1e-6)
  λs = λmax .* 10 .^ range(0, -1.7; length = 15)
  ref = solve_path(ls, NormL1(1.0), λs, CDSolver(; tol = 1e-12))
  path = solve_path(ls, NormL1(1.0), λs, CDSolver(; tol = 1e-10, workingset = true))
  for k in eachindex(λs)
    @test norm(path.solutions[k] - ref.solutions[k]) <= 1e-5 * max(1, norm(ref.solutions[k]))
  end
  x = SparseIterate(p)
  solve!(x, ls, NormL1(0.02λmax), CDSolver(; tol = 1e-10, workingset = true); continuation = 8)
  @test kkt_residual(ls, NormL1(0.02λmax), x) <= 1e-9
end

@testset "fallback to the plain passes" begin
  X, y, _ = lassodata(; p = 200)
  n, p = size(X)
  ls = (1 / n) * LeastSquaresLoss(y, X)
  λmax = lambda_max(ls, NormL1(1.0), SparseIterate(p))
  groups = [((k - 1) * 4 + 1):(k * 4) for k in 1:50]
  gg = GroupNormL2(0.1λmax, groups)
  @test !PS._useworkingset(CDSolver(; workingset = true), cdmodel(ls, AtomIterate(p, groups)), AtomIterate(p, groups), PS._CDState(Float64, AtomIterate(p, groups), true))
  xa = AtomIterate(p, groups)
  @test solve!(xa, ls, gg, CDSolver(; workingset = true)).converged
  Sx, Sy = cov(randn(Xoshiro(15), 50, 8)), cov(randn(Xoshiro(16), 50, 8))
  fk = KronQuadratic(Sx, Sy, Sx - Sy)
  @test !PS._useworkingset(CDSolver(; workingset = true), cdmodel(fk, SymmetricSparseIterate(8)), SymmetricSparseIterate(8), PS._CDState(Float64, SymmetricSparseIterate(8), true))
  # the square-root lasso steps exactly, without coordinate_derivatives
  fs = SqrtLeastSquaresLoss(y, X)
  @test !PS._useworkingset(CDSolver(; workingset = true), cdmodel(fs, SparseIterate(p)), SparseIterate(p), PS._CDState(Float64, SparseIterate(p), true))
  st = PS._CDState(Float64, SparseIterate(p), true)
  @test PS._useworkingset(CDSolver(; workingset = true), cdmodel(ls, SparseIterate(p)), SparseIterate(p), st)
  # inside the screening of a path, the strong rule's candidates are the working set
  st.candidates = collect(1:10)
  @test !PS._useworkingset(CDSolver(; workingset = true), cdmodel(ls, SparseIterate(p)), SparseIterate(p), st)
end

end
