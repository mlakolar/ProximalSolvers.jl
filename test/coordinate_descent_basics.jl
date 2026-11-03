# Coordinate descent, representative cases: closed forms, the lasso and its variants against KKT
# conditions, warm starts, the group lasso and starts from zero (FT26). Moved from
# test/coordinate_descent.jl to run in the quick tier (#121); the other cases of
# `coordinate_descent.jl` stay there.

module CDBasicsTests

using Test, LinearAlgebra, Random, SparseArrays, Statistics
using ProximalBase
using ProximalSolvers
using ProximalSolvers: intercept, residuals
const PS = ProximalSolvers

# largest violation of 0 ∈ ∇ + λ ∂(Σ wᵢ|xᵢ|)
function kkt_l1(grad, x, λ, w = ones(length(x)))
  v = 0.0
  for i in eachindex(x)
    v = max(v, x[i] == 0 ? max(abs(grad[i]) - λ * w[i], 0.0) : abs(grad[i] + λ * w[i] * sign(x[i])))
  end
  v
end

lsgrad(X, y, x) = X' * (X * x - y) / size(X, 1)

function lassodata(; n = 80, p = 200, seed = 1)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  β = zeros(p); β[1:5] .= [2, -1.5, 1, -1, 0.5]
  X, X * β + 0.3 * randn(rng, n)
end

@testset "closed forms" begin
  # orthogonal columns: the lasso solution soft-thresholds X'y/n
  n = 64
  Q = Matrix(qr(randn(Xoshiro(2), n, 8)).Q)[:, 1:8] .* sqrt(n)   # ‖Xⱼ‖² = n, X'X = nI
  y = randn(Xoshiro(3), n)
  λ = 0.3
  z = Q' * y / n
  for order in (:cyclic, :random)
    x = SparseIterate(8)
    r = solve!(x, (1 / n) * LeastSquaresLoss(y, Q), NormL1(λ), CDSolver(; order, tol = 1e-12))
    @test Vector(x) ≈ sign.(z) .* max.(abs.(z) .- λ, 0) atol = 1e-12
    @test r.converged
  end
  # a group penalty on orthogonal columns shrinks each group's norm
  groups = [1:3, 4:5, 6:8]
  x = AtomIterate(Float64, 8, groups)
  solve!(x, (1 / n) * LeastSquaresLoss(y, Q), GroupNormL2(λ, groups, ones(3)), CDSolver(; tol = 1e-12))
  for G in groups
    @test Vector(x)[G] ≈ max(1 - λ / norm(z[G]), 0) * z[G] atol = 1e-12
  end
end

@testset "lasso and its variants" begin
  X, y = lassodata()
  n, p = size(X)
  λ = 0.1 * maximum(abs, X' * y) / n
  f = (1 / n) * LeastSquaresLoss(y, X)

  @testset "$order order" for order in (:cyclic, :random)
    x = SparseIterate(p)
    r = solve!(x, f, NormL1(λ), CDSolver(; order, tol = 1e-10))
    @test r isa CDResults && r.converged && r.minimizer === x
    @test kkt_l1(lsgrad(X, y, Vector(x)), Vector(x), λ) < 1e-7
    @test r.minimum ≈ sum(abs2, y - X * Vector(x)) / (2n) + λ * sum(abs, Vector(x))
  end

  @testset "unscaled loss and penalty" begin
    x1, x2 = SparseIterate(p), SparseIterate(p)
    solve!(x1, f, NormL1(λ), CDSolver(; tol = 1e-12))
    solve!(x2, LeastSquaresLoss(y, X), NormL1(n * λ), CDSolver(; tol = 1e-12))
    @test Vector(x1) ≈ Vector(x2) atol = 1e-9
  end

  @testset "a dense starting vector" begin
    x = zeros(p)
    r = solve!(x, f, NormL1(λ), CDSolver(; tol = 1e-10))
    @test r.minimizer === x && r.converged
    @test kkt_l1(lsgrad(X, y, x), x, λ) < 1e-7
    groups = [i:i+4 for i in 1:5:p]
    xg = zeros(p)
    solve!(xg, f, GroupNormL2(λ, groups, ones(length(groups))), CDSolver(; tol = 1e-10); continuation = 5, gaptol = 0)
    @test any(!iszero, xg)
  end

  @testset "a seeded random order is reproducible" begin
    run() = (Random.seed!(7); x = SparseIterate(p); r = solve!(x, f, NormL1(λ), CDSolver()); (Vector(x), r.passes))
    @test run() == run()
  end

  @testset "the random order comes from rng" begin
    run(s) = (x = SparseIterate(p); r = solve!(x, f, NormL1(λ), s); (Vector(x), r.passes))
    @test run(CDSolver(; rng = Xoshiro(3))) == run(CDSolver(; rng = Xoshiro(3)))
    @test run(CDSolver(; rng = Xoshiro(3))) != run(CDSolver(; rng = Xoshiro(4)))
    # the default is the task-local generator, which draws as the global one
    @test CDSolver().rng === Random.default_rng()
    @test (Random.seed!(7); run(CDSolver())) == (Random.seed!(7); run(CDSolver(; rng = Random.default_rng())))
    # a generator of its own leaves the global stream alone
    Random.seed!(11); u = rand()
    Random.seed!(11); run(CDSolver(; rng = Xoshiro(1))); @test rand() == u
    # so do paths and continuation, whose passes draw from the same generator
    path(s) = (r = solve_path(f, NormL1(1.0), [2λ, λ, λ / 2], s); (r.solutions, r.passes))
    @test path(CDSolver(; rng = Xoshiro(5))) == path(CDSolver(; rng = Xoshiro(5)))
    cont(s) = (x = SparseIterate(p); r = solve!(x, f, NormL1(λ / 2), s; continuation = 5); (Vector(x), r.passes))
    @test cont(CDSolver(; rng = Xoshiro(6))) == cont(CDSolver(; rng = Xoshiro(6)))
    Random.seed!(11); path(CDSolver(; rng = Xoshiro(5))); cont(CDSolver(; rng = Xoshiro(6))); @test rand() == u
    # the inner solver of ProxNewton keeps its generator
    @test ProxNewton(; inner = CDSolver(; rng = Xoshiro(2))).inner.rng == Xoshiro(2)
  end

  @testset "unpenalized coordinates" begin
    w = ones(p); w[[3, 50]] .= 0
    x = SparseIterate(p)
    solve!(x, f, NormL1(10 * λ, w), CDSolver(; tol = 1e-10))
    @test x[3] != 0 && x[50] != 0
    @test kkt_l1(lsgrad(X, y, Vector(x)), Vector(x), 10λ, w) < 1e-7
    # λmax ignores the unpenalized coordinates
    @test lambda_max(f, NormL1(1.0, w), SparseIterate(p)) ≈ maximum(abs.(X' * y / n)[w .> 0])
  end

  @testset "warm start from a dense starting point" begin
    x = SparseIterate(randn(Xoshiro(4), p))
    solve!(x, f, NormL1(λ), CDSolver(; tol = 1e-10))
    @test kkt_l1(lsgrad(X, y, Vector(x)), Vector(x), λ) < 1e-7
  end

  @testset "data changed in place" begin
    Xc, yc = copy(X), copy(y)
    fc = (1 / n) * LeastSquaresLoss(yc, Xc)
    m = cdmodel(fc, SparseIterate(p))
    x = SparseIterate(p)
    solve!(x, m, NormL1(λ), CDSolver(; tol = 1e-10))
    Xc .*= 2
    x = SparseIterate(p)
    solve!(x, m, NormL1(λ), CDSolver(; tol = 1e-10))   # initialize! rereads the columns
    @test kkt_l1(lsgrad(Xc, yc, Vector(x)), Vector(x), λ) < 1e-7
  end

  @testset "zero and constant columns" begin
    Xz = copy(X); Xz[:, 2] .= 0; Xz[:, 4] .= 3.0
    x = SparseIterate(p)
    r = solve!(x, (1 / n) * LeastSquaresLoss(y, Xz), NormL1(λ), CDSolver())
    @test x[2] == 0 && r.converged
    # with an intercept a constant column does not enter the loss
    x = SparseIterate(p)
    m = cdmodel((1 / n) * LeastSquaresLoss(y, Xz), x; intercept = true)
    solve!(x, m, NormL1(λ), CDSolver())
    @test x[2] == 0 && x[4] == 0
    # an unpenalized column the loss does not depend on goes to the penalty's
    # minimizer nearest zero, here the projection of 0 onto [1, 2]
    x = SparseIterate(p)
    lo = zeros(p); lo[2] = 1
    hi = fill(Inf, p); hi[2] = 2
    solve!(x, (1 / n) * LeastSquaresLoss(y, Xz), IndBox(lo, hi), CDSolver(; maxpasses = 50))
    @test x[2] == 1
  end

  @testset "the stopping rule does not depend on the units" begin
    run(c) = (Random.seed!(1); x = SparseIterate(p);
              r = solve!(x, (1 / n) * LeastSquaresLoss(c * y, c * X), NormL1(c^2 * λ), CDSolver()); (Vector(x), r.passes))
    # a power of 2 scales every number exactly
    (x1, k1), (x2, k2) = run(1.0), run(1024.0)
    @test k1 == k2
    @test x1 == x2
  end

  @testset "intercept" begin
    y1 = y .+ 3.0
    x = SparseIterate(p)
    m = cdmodel((1 / n) * LeastSquaresLoss(y1, X), x; intercept = true)
    solve!(x, m, NormL1(λ), CDSolver(; tol = 1e-10))
    b0 = intercept(m, Vector(x))
    res = y1 .- b0 .- X * Vector(x)
    @test abs(sum(res)) < 1e-8
    @test residuals(m) ≈ res
    @test kkt_l1(-X' * res / n, Vector(x), λ) < 1e-7
  end

  @testset "weights and offset" begin
    w = rand(Xoshiro(5), n) .+ 0.5
    o = randn(Xoshiro(6), n)
    ω = rand(Xoshiro(7), p) .+ 0.5
    x = SparseIterate(p)
    solve!(x, GLMLoss(ProximalBase.Squared(), y, X; weights = w, offset = o), NormL1(n * λ, ω), CDSolver(; tol = 1e-10))
    @test kkt_l1(X' * (w .* (X * Vector(x) + o - y)), Vector(x), n * λ, ω) < 1e-6
  end

  @testset "an intercept with weights" begin
    w = rand(Xoshiro(8), n) .+ 0.5
    o = randn(Xoshiro(9), n)
    Xs = X .+ randn(Xoshiro(10), 1, p)                    # columns with nonzero means
    for off in (nothing, o)
      x = SparseIterate(p)
      m = cdmodel(GLMLoss(ProximalBase.Squared(), y, Xs; weights = w, offset = off), x; intercept = true)
      solve!(x, m, NormL1(n * λ), CDSolver(; tol = 1e-12))
      β = Vector(x)
      β0 = PS.intercept(m, β)
      r = y .- (off === nothing ? 0 : off) .- β0 .- Xs * β
      @test PS.residuals(m) ≈ r
      @test abs(dot(w, r)) < 1e-8 * norm(y)                # the intercept is optimal
      @test kkt_l1(-Xs' * (w .* r), β, n * λ) < 1e-6
      # the weighted means
      @test m.xbar ≈ Xs' * w / sum(w)
      @test m.ybar ≈ dot(w, y .- (off === nothing ? 0 : off)) / sum(w)
    end
    # integer weights give the solution of the replicated rows
    k = rand(Xoshiro(11), 1:3, n)
    rows = reduce(vcat, [fill(i, k[i]) for i in 1:n])
    x1, x2 = SparseIterate(p), SparseIterate(p)
    m1 = cdmodel(GLMLoss(ProximalBase.Squared(), y, Xs; weights = float.(k)), x1; intercept = true)
    m2 = cdmodel(LeastSquaresLoss(y[rows], Xs[rows, :]), x2; intercept = true)
    solve!(x1, m1, NormL1(n * λ), CDSolver(; tol = 1e-12))
    solve!(x2, m2, NormL1(n * λ), CDSolver(; tol = 1e-12))
    @test Vector(x1) ≈ Vector(x2) atol = 1e-7
    @test PS.intercept(m1, Vector(x1)) ≈ PS.intercept(m2, Vector(x2)) atol = 1e-7
    # a constant column has an exact mean, and its coefficient stays at zero
    Xc = copy(Xs); Xc[:, 3] .= 2.5
    mc = cdmodel(GLMLoss(ProximalBase.Squared(), y, Xc; weights = w), SparseIterate(p); intercept = true)
    @test mc.xbar[3] == 2.5
    xc = SparseIterate(p)
    solve!(xc, mc, NormL1(n * λ), CDSolver(; tol = 1e-10))
    @test xc[3] == 0
    # the weights must have a positive sum
    @test_throws ArgumentError cdmodel(GLMLoss(ProximalBase.Squared(), y, X; weights = zeros(n)), x1; intercept = true)
  end

  @testset "quadratic" begin
    A = Matrix(Symmetric(X' * X / n)) + 0.1I
    b = -X' * y / n
    x = SparseIterate(p)
    r = solve!(x, QuadraticFunction(A, b), NormL1(λ), CDSolver(; tol = 1e-10))
    @test kkt_l1(A * Vector(x) + b, Vector(x), λ) < 1e-8
    @test r.minimum ≈ dot(Vector(x), A * Vector(x)) / 2 + dot(b, Vector(x)) + λ * sum(abs, Vector(x))
    # a Symmetric matrix and a scaled quadratic
    x2 = SparseIterate(p)
    solve!(x2, 2 * QuadraticFunction(Symmetric(A), b), NormL1(2λ), CDSolver(; tol = 1e-10))
    @test Vector(x2) ≈ Vector(x) atol = 1e-8
    # a dense Matrix{T} is used as it is, any other matrix is copied
    @test cdmodel(QuadraticFunction(A, b), x).A === A
    @test cdmodel(QuadraticFunction(Symmetric(A), b), x).A == A
    @test cdmodel(QuadraticFunction(Float32.(A), Float32.(b)), x).A isa Matrix{Float32}
  end

  @testset "other separable penalties" begin
    for g in (ElasticNet(λ, 0.5λ), MCP(λ, 3.0), SCAD(λ, 3.7), NormL1Nonneg(λ), IndBox(-0.5, 0.5), ZeroFunction())
      x = SparseIterate(p)
      r = solve!(x, f, g, CDSolver(; tol = 1e-10, maxpasses = 10^5))
      @test r.converged
      @test isfinite(r.minimum)
    end
    # nonnegative lasso: KKT with the sign constraint
    x = SparseIterate(p)
    solve!(x, f, NormL1Nonneg(λ), CDSolver(; tol = 1e-10))
    xd = Vector(x); gr = lsgrad(X, y, xd)
    @test all(xd .>= 0)
    @test maximum(i -> xd[i] > 0 ? abs(gr[i] + λ) : max(-gr[i] - λ, 0.0), 1:p) < 1e-7
  end

  @testset "Float32" begin
    X32, y32 = Float32.(X), Float32.(y)
    x = SparseIterate(Float32, p)
    r = solve!(x, (1f0 / n) * LeastSquaresLoss(y32, X32), NormL1(Float32(λ)), CDSolver(; tol = 1e-5))
    @test eltype(x) == Float32 && r.minimum isa Float32
    x64 = SparseIterate(p)
    solve!(x64, f, NormL1(λ), CDSolver(; tol = 1e-10))
    @test Vector(x) ≈ Vector(x64) atol = 1e-3
  end

  @testset "Anderson acceleration" begin
    x0, x5 = SparseIterate(p), SparseIterate(p)
    r0 = solve!(x0, f, NormL1(0.2λ), CDSolver(; order = :cyclic, tol = 1e-10))
    r5 = solve!(x5, f, NormL1(0.2λ), CDSolver(; order = :cyclic, tol = 1e-10, anderson = 5))
    @test r5.converged && r5.passes < r0.passes
    @test kkt_l1(lsgrad(X, y, Vector(x5)), Vector(x5), 0.2λ) < 1e-7
    @test Vector(x5) ≈ Vector(x0) atol = 1e-6
    # ignored with a random order
    run(K) = (Random.seed!(3); x = SparseIterate(p); solve!(x, f, NormL1(λ), CDSolver(; anderson = K)).passes)
    @test run(5) == run(0)
    @test_throws ArgumentError CDSolver(; anderson = -1)
  end

  @testset "maxpasses" begin
    x = SparseIterate(p)
    r = @test_logs (:warn, r"did not converge") solve!(x, f, NormL1(0.01λ), CDSolver(; maxpasses = 3))
    @test !r.converged && r.passes == 3
  end
end

@testset "warm starts from nonzero iterates" begin
  X, y = lassodata()
  n, p = size(X)
  λ = 0.1 * maximum(abs, X' * y) / n
  start = randn(Xoshiro(31), p)
  # the quadratic
  A = Matrix(Symmetric(X' * X / n)) + 0.1I; b = -X' * y / n
  x0, x1 = SparseIterate(p), SparseIterate(start)
  solve!(x0, QuadraticFunction(A, b), NormL1(λ), CDSolver(; tol = 1e-12))
  solve!(x1, QuadraticFunction(A, b), NormL1(λ), CDSolver(; tol = 1e-12))
  @test Vector(x1) ≈ Vector(x0) atol = 1e-8
  # the square-root lasso
  λs = 0.5 * maximum(abs, X' * y) / norm(y)
  x0, x1 = SparseIterate(p), SparseIterate(start)
  solve!(x0, SqrtLeastSquaresLoss(y, X), NormL1(λs), CDSolver(; tol = 1e-12))
  solve!(x1, SqrtLeastSquaresLoss(y, X), NormL1(λs), CDSolver(; tol = 1e-12))
  @test Vector(x1) ≈ Vector(x0) atol = 1e-7
  # the Kronecker quadratic on vec Θ
  q = 8
  Sx = cov(randn(Xoshiro(32), 40, q)); Sy = cov(randn(Xoshiro(33), 40, q))
  fk = KronQuadratic(Sx, Sy, randn(Xoshiro(34), q, q))
  x0, x1 = SparseIterate(q * q), SparseIterate(randn(Xoshiro(35), q * q))
  solve!(x0, fk, NormL1(0.05), CDSolver(; tol = 1e-12))
  solve!(x1, fk, NormL1(0.05), CDSolver(; tol = 1e-12))
  @test Vector(x1) ≈ Vector(x0) atol = 1e-8
end

@testset "group lasso" begin
  X, y = lassodata()
  n, p = size(X)
  groups = [i:i+4 for i in 1:5:p]
  λ = 0.1 * maximum(G -> norm(X[:, G]' * y), groups) / n
  g = GroupNormL2(λ, groups, ones(length(groups)))
  for f in ((1 / n) * LeastSquaresLoss(y, X), QuadraticFunction(X' * X / n, -X' * y / n))
    x = AtomIterate(Float64, p, groups)
    solve!(x, f, g, CDSolver(; tol = 1e-10))
    xd = Vector(x); gr = lsgrad(X, y, xd)
    @test maximum(G -> norm(xd[G]) == 0 ? max(norm(gr[G]) - λ, 0) : norm(gr[G] + λ * xd[G] / norm(xd[G])), groups) < 1e-6
  end
  @test_throws ArgumentError solve!(SparseIterate(p), (1 / n) * LeastSquaresLoss(y, X), g, CDSolver())
  @test_throws ArgumentError solve!(AtomIterate(Float64, p, [1:p]), (1 / n) * LeastSquaresLoss(y, X), g, CDSolver())
  # groups of one coordinate among larger ones
  groups1 = vcat([[k] for k in 1:10], [i:i+4 for i in 11:5:p])
  g1 = GroupNormL2(λ, groups1, ones(length(groups1)))
  x = AtomIterate(Float64, p, groups1)
  solve!(x, (1 / n) * LeastSquaresLoss(y, X), g1, CDSolver(; tol = 1e-10))
  xd = Vector(x); gr = lsgrad(X, y, xd)
  @test maximum(G -> norm(xd[G]) == 0 ? max(norm(gr[G]) - λ, 0) : norm(gr[G] + λ * xd[G] / norm(xd[G])), groups1) < 1e-6
end

# FT26 (#164): the starts from zero clear the working set explicitly, so that they do
# not depend on whether `fill!(x, 0)` removes coordinates (ProximalBase 0.5.x) or
# only writes zeros (0.6, where `dropzeros!` alone removes them).
@testset "start from zero clears the working set (#164)" begin
  function dirty(::Type{SparseIterate})
    x = SparseIterate(8)
    x[2] = 0.7; x[5] = -0.4; x[7] = 1.0; x[7] = 0.0     # a stored (active) zero
    x
  end
  function dirty(::Type{AtomIterate})
    x = AtomIterate(8, [[1, 5], [2, 6], [3, 7], [4, 8]])
    x[2] = 0.7; x[5] = -0.4; x[3] = 1.0; x[3] = 0.0
    x
  end
  groups = [[1, 5], [2, 6], [3, 7], [4, 8]]
  fresh(::Type{SparseIterate}) = SparseIterate(8)
  fresh(::Type{AtomIterate}) = AtomIterate(8, groups)
  penalty(::Type{SparseIterate}, λ) = NormL1(λ)
  penalty(::Type{AtomIterate}, λ) = GroupNormL2(λ, groups)

  for X in (SparseIterate, AtomIterate)
    x = dirty(X)
    @test nactive(x) > 0 && any(!iszero, Vector(x))
    @test PS._clear_start!(x) === x
    @test all(iszero, Vector(x))
    @test isempty(activecoordinates(x)) && nactive(x) == 0
  end

  rng = Xoshiro(164)
  A, b = randn(rng, 30, 8), randn(rng, 30)
  f = (1 / 30) * LeastSquaresLoss(b, A)
  method = CDSolver(; order = :cyclic, tol = 1e-12)
  for X in (SparseIterate, AtomIterate), screening in (true, false)
    λmax = lambda_max(f, penalty(X, 1.0), fresh(X))
    g = penalty(X, 0.2λmax)
    x = dirty(X)
    r = solve!(x, f, g, method; continuation = 5, screening, gaptol = 0)
    xf = fresh(X)
    rf = solve!(xf, f, g, method; continuation = 5, screening, gaptol = 0)
    @test r.converged && rf.converged
    @test Vector(x) ≈ Vector(xf) atol = 1e-10
    @test r.minimum ≈ rf.minimum atol = 1e-10
    @test r.passes == rf.passes
    @test activecoordinates(x) == activecoordinates(xf)
  end
end

end
