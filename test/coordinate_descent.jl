# Coordinate descent: correctness against closed forms and KKT conditions
# computed from dense algebra, the behaviors carried over from
# CoordinateDescent.jl, and allocations.

module CDTests

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

@testset "KronQuadratic" begin
  rng = Xoshiro(11)
  q = 8
  Sx = cov(randn(rng, 40, q)); Sy = cov(randn(rng, 40, q))
  C = randn(rng, q, q)
  f = KronQuadratic(Sx, Sy, C)
  K = kron(Sy, Sx)

  @testset "value and gradient" begin
    Θ = randn(rng, q, q)
    @test f(Θ) ≈ dot(vec(Θ), K * vec(Θ)) / 2 + dot(C, Θ)
    @test f(vec(Θ)) ≈ f(Θ)
    G = similar(Θ)
    @test ProximalBase.value_and_gradient!(G, f, Θ) ≈ f(Θ)
    @test vec(G) ≈ K * vec(Θ) + vec(C)
    S = SymmetricSparseIterate(Matrix(Symmetric(Θ)))
    gradient!(G, f, S)
    D = Matrix(S)
    @test G ≈ (Sx * D * Sy + Sy * D * Sx) / 2 + (C + C') / 2
    @test f(S) ≈ f(D)
    @test_throws DimensionMismatch f(randn(q, q + 1))
    @test_throws ArgumentError KronQuadratic(randn(3, 3), Sy)
  end

  @testset "coordinate descent on vec Θ" begin
    ω = fill(0.05, q * q)
    x = SparseIterate(q * q)
    r = solve!(x, f, NormL1(1.0, ω), CDSolver(; tol = 1e-12))
    θ = Vector(x)
    @test kkt_l1(K * θ + vec(C), θ, 1.0, ω) < 1e-9
    @test r.minimum ≈ f(θ) + sum(ω .* abs.(θ))
    # the same as a QuadraticFunction of vec Θ with the Kronecker product formed
    x2 = SparseIterate(q * q)
    solve!(x2, QuadraticFunction(K, vec(C)), NormL1(1.0, ω), CDSolver(; tol = 1e-12))
    @test Vector(x2) ≈ θ atol = 1e-8
    # a matrix iterate is the same
    x3 = SparseIterate(q, q)
    solve!(x3, f, NormL1(1.0, reshape(ω, q, q)), CDSolver(; tol = 1e-12))
    @test vec(Matrix(x3)) ≈ θ atol = 1e-8
  end

  @testset "coordinate descent on a symmetric Θ" begin
    Cs = (C + C') / 2
    fs = KronQuadratic(Sx, Sy, Cs)
    λ = 0.3 * maximum(abs, Cs)
    for order in (:cyclic, :random)
      x = SymmetricSparseIterate(q)
      r = solve!(x, fs, NormL1(λ), CDSolver(; order, tol = 1e-12))
      D = Matrix(x)
      gr = (Sx * D * Sy + Sy * D * Sx) / 2 + Cs
      @test kkt_l1(vec(gr), vec(D), λ) < 1e-9
      @test r.minimum ≈ fs(D) + λ * sum(abs, D)
    end
    # Anderson acceleration on a symmetric iterate
    x = SymmetricSparseIterate(q)
    solve!(x, fs, NormL1(λ), CDSolver(; order = :cyclic, anderson = 5, tol = 1e-12))
    D = Matrix(x)
    @test kkt_l1(vec((Sx * D * Sy + Sy * D * Sx) / 2 + Cs), vec(D), λ) < 1e-9
    # weights on the entries, and an unpenalized diagonal
    W = fill(1.0, q, q); W[diagind(W)] .= 0
    x = SymmetricSparseIterate(q)
    solve!(x, fs, NormL1(λ, W), CDSolver(; tol = 1e-12))
    D = Matrix(x)
    @test all(!iszero, diag(D))
    @test kkt_l1(vec((Sx * D * Sy + Sy * D * Sx) / 2 + Cs), vec(D), λ, vec(W)) < 1e-9
  end
end

@testset "paths, continuation and λmax" begin
  X, y = lassodata()
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  λmax = lambda_max(f, NormL1(1.0), SparseIterate(p))
  @test λmax ≈ maximum(abs, X' * y) / n
  x = SparseIterate(p)
  solve!(x, f, NormL1(λmax * (1 + 1e-9)), CDSolver())
  @test nnz(x) == 0

  λ = 0.05λmax
  x = SparseIterate(p)
  r = solve!(x, f, NormL1(λ), CDSolver(; tol = 1e-10); continuation = 20, gaptol = 0)
  @test kkt_l1(lsgrad(X, y, Vector(x)), Vector(x), λ) < 1e-7
  @test r.kkt_checks >= 21
  # the levels before λ are solved to √tol by default, and λ itself to tol
  for ctol in (1e-10, 1e-3, 0.0)
    xc = SparseIterate(p)
    rc = solve!(xc, f, NormL1(λ), CDSolver(; tol = 1e-10); continuation = 20, continuation_tol = ctol, gaptol = 0)
    @test rc.converged && rc.tolerance == r.tolerance
    @test kkt_l1(lsgrad(X, y, Vector(xc)), Vector(xc), λ) < 1e-7
    @test Vector(xc) ≈ Vector(x) atol = 1e-7
  end
  @test_throws ArgumentError solve!(SparseIterate(p), f, NormL1(λ), CDSolver(); continuation = 5, continuation_tol = -1)

  λs = λmax .* 10 .^ range(0, -2; length = 15)
  for screening in (true, false)
    path = solve_path(f, NormL1(1.0), λs, CDSolver(; tol = 1e-10); screening, gaptol = 0)
    @test path.λ == λs
    for k in eachindex(λs)
      b = Vector(path.solutions[k])
      @test kkt_l1(lsgrad(X, y, b), b, λs[k]) < 1e-6
      @test path.values[k] ≈ sum(abs2, y - X * b) / (2n) + λs[k] * sum(abs, b)
    end
    @test all(path.converged)
    @test screening ? all(>=(1), path.kkt_checks) : all(iszero, path.kkt_checks)
  end
  # early stops
  @test length(solve_path(f, NormL1(1.0), λs; maxnnz = 10).λ) < length(λs)
  @test length(solve_path(f, NormL1(1.0), λs; callback = (k, λ, x, m) -> k == 3).λ) == 3
  @test_throws ArgumentError solve_path(f, NormL1(1.0), reverse(λs))
  @test_throws ArgumentError solve_path(f, NormL1(1.0), [-1.0])
  # paths of other penalties with a level
  for g in (ElasticNet(1.0, 0.1), MCP(1.0, 3.0), SCAD(1.0, 3.7))
    @test length(solve_path(f, g, λs[1:5]).λ) == 5
  end
  @test_throws ArgumentError solve_path(f, IndBox(-1, 1), λs)

  @testset "the elastic net at a fixed α: the level is the scale" begin
    w = rand(Xoshiro(37), p) .+ 0.5
    for α in (0.2, 0.5, 1.0)
      g = Scaled(ElasticNet(α, 1 - α, w), 1.0)
      lm = lambda_max(f, g, SparseIterate(p))
      @test lm ≈ maximum(abs.(X' * y / n) ./ (α .* w))
      x = SparseIterate(p)
      solve!(x, f, Scaled(ElasticNet(α, 1 - α, w), lm * (1 + 1e-9)), CDSolver())
      @test nnz(x) == 0
      ls = lm .* 10 .^ range(0, -2; length = 12)
      for screening in (true, false)
        path = solve_path(f, g, ls, CDSolver(; tol = 1e-10); screening, gaptol = 0)
        @test path.λ == ls && all(path.converged)
        @test screening ? all(>=(1), path.kkt_checks) : all(iszero, path.kkt_checks)
        for k in eachindex(ls)
          b = Vector(path.solutions[k])
          # the lasso at level λα of the loss plus the ridge λ(1 - α)‖b‖²/2
          @test kkt_l1(lsgrad(X, y, b) .+ ls[k] * (1 - α) .* b, b, ls[k] * α, w) < 1e-6
          @test path.values[k] ≈ sum(abs2, y - X * b) / (2n) + ls[k] * (α * sum(w .* abs.(b)) + (1 - α) * sum(abs2, b) / 2)
        end
        # the solution of ElasticNet(λα, λ(1 - α), w)
        x1 = SparseIterate(p)
        solve!(x1, f, ElasticNet(ls[6] * α, ls[6] * (1 - α), w), CDSolver(; tol = 1e-10))
        @test Vector(path.solutions[6]) ≈ Vector(x1) atol = 1e-6
      end
      # continuation down to a level
      λ = 0.05lm
      xc = SparseIterate(p)
      rc = solve!(xc, f, Scaled(ElasticNet(α, 1 - α, w), λ), CDSolver(; tol = 1e-10); continuation = 10, gaptol = 0)
      @test rc.kkt_checks >= 11
      @test kkt_l1(lsgrad(X, y, Vector(xc)) .+ λ * (1 - α) .* Vector(xc), Vector(xc), λ * α, w) < 1e-6
    end
    # only the scaled elastic net has its scale as a level
    @test_throws ArgumentError solve_path(f, Scaled(NormL1(1.0), 2.0), λs)
  end

  @testset "cyclic order, weights, and a level of λmax or more" begin
    pc = solve_path(f, NormL1(1.0), λs, CDSolver(; order = :cyclic, tol = 1e-10); gaptol = 0)
    for k in eachindex(λs)
      b = Vector(pc.solutions[k])
      @test kkt_l1(lsgrad(X, y, b), b, λs[k]) < 1e-6
    end
    # a weighted least-squares loss screens with its weighted gradient
    w = rand(Xoshiro(36), n) .+ 0.5
    fw = GLMLoss(ProximalBase.Squared(), y, X; weights = w ./ n)
    pw = solve_path(fw, NormL1(1.0), λs, CDSolver(; tol = 1e-10); gaptol = 0)
    for k in eachindex(λs)
      b = Vector(pw.solutions[k])
      @test kkt_l1(X' * (w .* (X * b - y)) / n, b, λs[k]) < 1e-6
    end
    # continuation to a level at or above λmax solves directly
    x = SparseIterate(p)
    r = solve!(x, f, NormL1(2λmax), CDSolver(); continuation = 10)
    @test nnz(x) == 0 && r.kkt_checks == 0
    # and so does continuation with a penalty without a level, from zero
    f20 = (1 / n) * LeastSquaresLoss(y, X[:, 1:20])
    for g in (ZeroFunction(), IndBox(-0.5, 0.5))
      x1 = SparseIterate(20); x1[3] = 1.0
      x2 = SparseIterate(20)
      Random.seed!(5); r1 = solve!(x1, f20, g, CDSolver(; tol = 1e-10); continuation = 10, gaptol = 0)
      Random.seed!(5); r2 = solve!(x2, f20, g, CDSolver(; tol = 1e-10))
      @test Vector(x1) == Vector(x2) && r1.passes == r2.passes && r1.converged && r1.kkt_checks == 0
    end
    @test_throws ArgumentError lambda_max(f, IndBox(-1, 1), SparseIterate(p))
  end

  @testset "the strong rule is corrected by the optimality checks" begin
    # a coordinate whose gradient is small at λmax but large at the next level
    # is discarded by the strong rule and added back by the check
    rng = Xoshiro(21)
    Xs = randn(rng, 100, 30)
    ys = Xs[:, 1] - 0.9 * Xs[:, 2] + 0.01 * randn(rng, 100)
    fs = (1 / 100) * LeastSquaresLoss(ys, Xs)
    lm = lambda_max(fs, NormL1(1.0), SparseIterate(30))
    path = solve_path(fs, NormL1(1.0), [lm, 0.05lm], CDSolver(; tol = 1e-10); gaptol = 0)
    b = Vector(path.solutions[2])
    @test kkt_l1(lsgrad(Xs, ys, b), b, 0.05lm) < 1e-7
  end

  @testset "symmetric iterates" begin
    rng = Xoshiro(12)
    q = 12
    Sx = cov(randn(rng, 80, q)); Sy = cov(randn(rng, 80, q) * cholesky([0.6^abs(i - j) for i in 1:q, j in 1:q]).U)
    fk = KronQuadratic(Sx, Sy, Sx - Sy)
    lm = lambda_max(fk, NormL1(1.0), SymmetricSparseIterate(q))
    @test lm ≈ maximum(abs, Sy - Sx)
    # continuation, which does not screen a symmetric iterate by default
    xs = SymmetricSparseIterate(q)
    solve!(xs, fk, NormL1(0.2lm), CDSolver(; tol = 1e-12); continuation = 10, gaptol = 0)
    D = Matrix(xs)
    @test kkt_l1(vec((Sx * D * Sy + Sy * D * Sx) / 2 + (Sx - Sy)), vec(D), 0.2lm) < 1e-8
    for screening in (true, false)
      pk = solve_path(fk, NormL1(1.0), lm .* 10 .^ range(0, -1; length = 6), CDSolver(; tol = 1e-12);
                      x = SymmetricSparseIterate(q), screening, gaptol = 0)
      for k in eachindex(pk.λ)
        D = Matrix(pk.solutions[k])
        @test kkt_l1(vec((Sx * D * Sy + Sy * D * Sx) / 2 + (Sx - Sy)), vec(D), pk.λ[k]) < 1e-8
      end
    end
  end
end

@testset "square-root lasso" begin
  X, y = lassodata()
  n, p = size(X)
  λ = 0.5 * maximum(abs, X' * y) / norm(y)
  for intercept in (false, true)
    x = SparseIterate(p)
    m = cdmodel(SqrtLeastSquaresLoss(y, X), x; intercept)
    r = solve!(x, m, NormL1(λ), CDSolver(; tol = 1e-12))
    b0 = intercept ? PS.intercept(m, Vector(x)) : 0.0
    res = y .- b0 .- X * Vector(x)
    @test kkt_l1(-X' * res / norm(res), Vector(x), λ) < 1e-7
    @test r.minimum ≈ norm(res) + λ * sum(abs, Vector(x))
  end
  # with weights, the weighted norm, with and without an intercept; integer
  # weights give the solution of the replicated rows
  w = rand(Xoshiro(12), n) .+ 0.5
  Xs = X .+ randn(Xoshiro(13), 1, p)
  for intercept in (false, true)
    f = SqrtLeastSquaresLoss(y, Xs; weights = w)
    x = SparseIterate(p)
    m = cdmodel(f, x; intercept)
    r = solve!(x, m, NormL1(λ), CDSolver(; tol = 1e-12))
    β = Vector(x)
    b0 = intercept ? PS.intercept(m, β) : 0.0
    res = y .- b0 .- Xs * β
    nw = sqrt(sum(w .* res .^ 2))
    @test kkt_l1(-Xs' * (w .* res) / nw, β, λ) < 1e-7
    @test r.minimum ≈ nw + λ * sum(abs, β)
    intercept || @test f(β) ≈ nw
    intercept && @test abs(dot(w, res)) < 1e-8 * norm(y)
  end
  k = rand(Xoshiro(14), 1:3, n)
  rows = reduce(vcat, [fill(i, k[i]) for i in 1:n])
  x1, x2 = SparseIterate(p), SparseIterate(p)
  solve!(x1, cdmodel(SqrtLeastSquaresLoss(y, Xs; weights = float.(k)), x1; intercept = true), NormL1(λ), CDSolver(; tol = 1e-12))
  solve!(x2, cdmodel(SqrtLeastSquaresLoss(y[rows], Xs[rows, :]), x2; intercept = true), NormL1(λ), CDSolver(; tol = 1e-12))
  @test Vector(x1) ≈ Vector(x2) atol = 1e-7
  @test_throws ArgumentError SqrtLeastSquaresLoss(y, X; weights = -ones(n))
  @test_throws DimensionMismatch SqrtLeastSquaresLoss(y, X; weights = ones(n - 1))

  # near a perfect fit the step stays finite
  yp = X[:, 1] * 2.0
  x = SparseIterate(p)
  r = solve!(x, SqrtLeastSquaresLoss(yp, X), NormL1(1e-3), CDSolver(; maxpasses = 1000))
  @test all(isfinite, Vector(x))
  @test_throws ArgumentError solve!(SparseIterate(p), SqrtLeastSquaresLoss(y, X), MCP(1.0, 3.0), CDSolver())
end

@testset "square root of a quadratic" begin
  X, y = lassodata()
  n, p = size(X)
  A, b, c = X' * X / n, -X' * y / n, dot(y, y) / n
  f = SqrtQuadraticFunction(A, b, c)     # ‖y - Xx‖ / √n
  λls = 0.5 * maximum(abs, X' * y) / norm(y)
  λ = λls / sqrt(n)
  x = SparseIterate(p)
  r = solve!(x, f, NormL1(λ), CDSolver(; tol = 1e-12))
  xd = Vector(x)
  q = dot(xd, A * xd) + 2 * dot(b, xd) + c
  @test kkt_l1((A * xd + b) / sqrt(q), xd, λ) < 1e-7
  @test r.minimum ≈ sqrt(q) + λ * sum(abs, xd)
  @test f(xd) ≈ sqrt(q)
  # the square-root lasso from the data, with the penalty scaled by √n
  xs = SparseIterate(p)
  solve!(xs, SqrtLeastSquaresLoss(y, X), NormL1(λls), CDSolver(; tol = 1e-12))
  @test xd ≈ Vector(xs) atol = 1e-8
  # without momentum, the same solution
  x0 = SparseIterate(p)
  solve!(x0, f, NormL1(λ), CDSolver(; tol = 1e-12, momentum = false))
  @test Vector(x0) ≈ xd atol = 1e-8
  # λmax, and a path from the default iterate
  @test lambda_max(f, NormL1(1.0), SparseIterate(p)) ≈ maximum(abs, b) / sqrt(c)
  path = solve_path(f, NormL1(1.0), [4λ, 2λ, λ], CDSolver(; tol = 1e-12); gaptol = 0)
  @test Vector(path.solutions[3]) ≈ xd atol = 1e-6

  # momentum moves the cache Ax with the point, and the value of the quadratic,
  # which is not affine in x, is computed again from it
  g = NormL1(λ)
  m = cdmodel(f, SparseIterate(p))
  xm = SparseIterate(p)
  for k in 1:5
    xm[k] = 0.5
  end
  PS.initialize!(m, xm)
  mom = PS._momentum_start!(PS._Momentum{Float64}(), xm, m)
  PS._momentum_reset!(mom, xm, m)
  for k in 1:5
    PS.coordinate_step!(m, g, xm, k)      # a pass over the active set
  end
  PS._momentum_update!(mom, xm, m)
  PS._momentum_step!(mom, xm, m)          # β = 1/4
  xv = Vector(xm)
  @test mom.k == 2 && mom.moved             # the cache moved
  @test m.u ≈ A * xv
  @test m.q ≈ dot(xv, A * xv) + 2 * dot(b, xv) + c

  # the scaled lasso of variable j on the others from their covariance matrix,
  # with an infinite weight that keeps coordinate j at zero (Sun and Zhang,
  # 2013), is the square-root lasso of X[:, j] on the other columns
  j = 4
  others = setdiff(1:p, j)
  w = ones(p); w[j] = Inf
  λjls = 0.5 * maximum(abs, X[:, others]' * X[:, j]) / norm(X[:, j])
  fj = SqrtQuadraticFunction(A, -A[:, j], A[j, j]; check = false)
  xj = SparseIterate(p)
  solve!(xj, fj, NormL1(λjls / sqrt(n), w), CDSolver(; tol = 1e-12))
  xo = SparseIterate(p - 1)
  solve!(xo, SqrtLeastSquaresLoss(X[:, j], X[:, others]), NormL1(λjls), CDSolver(; tol = 1e-12))
  @test xj[j] == 0
  @test Vector(xj)[others] ≈ Vector(xo) atol = 1e-8
  # with λ0 = 0 the weight gives NaN, which keeps the coordinate at zero too:
  # least squares on the other columns
  X20 = X[:, 1:20]
  A20 = X20' * X20 / n
  w20 = zeros(20); w20[j] = Inf
  x20 = SparseIterate(20)
  r20 = solve!(x20, SqrtQuadraticFunction(A20, -A20[:, j], A20[j, j]), NormL1(0.0, w20), CDSolver(; tol = 1e-12))
  o20 = setdiff(1:20, j)
  @test r20.converged && x20[j] == 0
  @test Vector(x20)[o20] ≈ X20[:, o20] \ X20[:, j] atol = 1e-6

  # A is used as it is, and checked only when asked
  @test cdmodel(f, SparseIterate(p)).A === A
  @test_throws DimensionMismatch SqrtQuadraticFunction(randn(3, 4), zeros(3), 1.0)
  @test_throws DimensionMismatch SqrtQuadraticFunction(A, zeros(p + 1), c)
  An = copy(A); An[1, 2] += 1
  @test_throws ArgumentError SqrtQuadraticFunction(An, b, c)
  @test SqrtQuadraticFunction(An, b, c; check = false) isa SqrtQuadraticFunction
  @test_throws ArgumentError SqrtQuadraticFunction(A, fill(NaN, p), c)
  @test_throws ArgumentError SqrtQuadraticFunction(A, b, Inf)
  @test_throws ArgumentError solve!(SparseIterate(p), f, ElasticNet(λ, 0.1), CDSolver())
end

@testset "reweighting" begin
  X, y = lassodata()
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  λ0 = sqrt(2 * log(p) / n)
  # the scaled lasso: the level λ0 σ̂ at the fixed point σ̂ = ‖r‖/√n
  update = (g, x, m) -> (σ = norm(residuals(m)) / sqrt(n); (NormL1(λ0 * σ), abs(σ - g.λ0 / λ0) / (g.λ0 / λ0)))
  x = SparseIterate(p)
  res = reweight!(x, f, NormL1(λ0 * std(y)), update, CDSolver(; tol = 1e-12); tol = 1e-10, maxiter = 100)
  @test res.converged && res.cd_converged
  σ = norm(y - X * Vector(x)) / sqrt(n)
  @test kkt_l1(lsgrad(X, y, Vector(x)), Vector(x), λ0 * σ) < 1e-7
  @test res.penalty.λ0 ≈ λ0 * σ rtol = 1e-8
  # two stages with weights from the first solution
  stages = Ref(0)
  update2 = (g, x, m) -> (stages[] += 1; (NormL1(g.λ0, 1 .+ abs.(Vector(x))), Inf))
  res2 = reweight!(SparseIterate(p), f, NormL1(0.1), update2; maxiter = 2, tol = 0)
  @test res2.iterations == 2 && stages[] == 2 && !res2.converged
end

@testset "refit" begin
  X, y = lassodata()
  n, p = size(X)
  λ = 0.1 * maximum(abs, X' * y) / n
  f = (1 / n) * LeastSquaresLoss(y, X)
  x = SparseIterate(p)
  solve!(x, f, NormL1(λ), CDSolver())
  S = findall(!iszero, Vector(x))
  refit!(x, f)
  @test Vector(x)[S] ≈ X[:, S] \ y
  @test all(iszero, Vector(x)[setdiff(1:p, S)])
  # with an intercept
  y1 = y .+ 2
  x = SparseIterate(p)
  m = cdmodel((1 / n) * LeastSquaresLoss(y1, X), x; intercept = true)
  solve!(x, m, NormL1(λ), CDSolver())
  S = findall(!iszero, Vector(x))
  refit!(x, m)
  coef = [ones(n) X[:, S]] \ y1
  @test Vector(x)[S] ≈ coef[2:end]
  @test intercept(m, Vector(x)) ≈ coef[1]
  # weighted least squares: the weighted fit on the support
  w = rand(Xoshiro(37), n) .+ 0.5
  fw = GLMLoss(ProximalBase.Squared(), y, X; weights = w)
  x = SparseIterate(p)
  solve!(x, fw, NormL1(n * λ), CDSolver())
  S = findall(!iszero, Vector(x))
  refit!(x, fw)
  @test Vector(x)[S] ≈ (X[:, S]' * (w .* X[:, S])) \ (X[:, S]' * (w .* y))
  # quadratic, and a given support
  A = Matrix(Symmetric(X' * X / n)) + 0.1I; b = -X' * y / n
  xq = SparseIterate(p)
  refit!(xq, QuadraticFunction(A, b); support = [1, 2, 7])
  @test Vector(xq)[[1, 2, 7]] ≈ -(A[[1, 2, 7], [1, 2, 7]] \ b[[1, 2, 7]])
  # symmetric Kronecker: the gradient vanishes on the support
  rng = Xoshiro(13)
  q = 10
  Sx = cov(randn(rng, 100, q)); Sy = cov(randn(rng, 100, q))
  fk = KronQuadratic(Sx, Sy, Sx - Sy)
  xs = SymmetricSparseIterate(q)
  solve!(xs, fk, NormL1(0.3 * maximum(abs, Sy - Sx)), CDSolver())
  refit!(xs, fk)
  D = Matrix(xs)
  @test maximum(abs, ((Sx * D * Sy + Sy * D * Sx) / 2 + (Sx - Sy))[D .!= 0]) < 1e-10
end

# the quadratic x'Ax/2 + b'x through the generic model interface only
mutable struct MyQuadratic <: CDModel{Float64}
  A::Matrix{Float64}
  b::Vector{Float64}
  u::Vector{Float64}
end
PS.initialize!(m::MyQuadratic, x) = (m.u .= m.A * Vector(x); m)
PS.coordinate_derivatives(m::MyQuadratic, x, k::Int) = (m.u[k] + m.b[k], m.A[k, k])
PS.update_cache!(m::MyQuadratic, x, k::Int, h) = (m.u .+= h .* view(m.A, :, k); m)
PS.coordinate_scale(m::MyQuadratic, x, k::Int) = sqrt(m.A[k, k])
PS.response_scale(m::MyQuadratic, x) = 1.0
PS.loss_value(m::MyQuadratic, x) = dot(Vector(x), m.u) / 2 + dot(m.b, Vector(x))
ProximalBase.gradient!(G, m::MyQuadratic, x) = (G .= m.u .+ m.b)

@testset "scales of the stopping rule" begin
  # the scale of a coordinate is √aₖ, computed when the cache has no aₖ yet
  X, y = lassodata()
  n, p = size(X)
  w = rand(Xoshiro(38), n) .+ 0.5
  for (f, a) in (((1 / n) * LeastSquaresLoss(y, X), vec(sum(abs2, X; dims = 1)) ./ n),
                 (GLMLoss(ProximalBase.Squared(), y, X; weights = w), vec(sum(w .* X .^ 2; dims = 1))),
                 (SqrtLeastSquaresLoss(y, X), vec(sum(abs2, X; dims = 1)) ./ n))
    x = SparseIterate(p)
    m = cdmodel(f, x)
    PS.initialize!(m, x)
    @test [PS.coordinate_scale(m, x, k) for k in (1, 7)] ≈ sqrt.(a[[1, 7]])
  end

  # the quadratic of least squares, x'(X'X/n)x/2 - (X'y/n)'x + y'y/(2n), has the
  # scales of the least-squares model, so it takes the same passes
  A, b, c = X'X / n, -X'y / n, dot(y, y) / (2n)
  x = SparseIterate(p)
  mq, ml = cdmodel(QuadraticFunction(A, b, c), x), cdmodel((1 / n) * LeastSquaresLoss(y, X), x)
  PS.initialize!(mq, x); PS.initialize!(ml, x)
  @test PS.response_scale(mq, x) ≈ PS.response_scale(ml, x)
  @test [PS.coordinate_scale(mq, x, k) for k in 1:p] ≈ [PS.coordinate_scale(ml, x, k) for k in 1:p]
  r1 = solve!(SparseIterate(p), QuadraticFunction(A, b, c), NormL1(0.05), CDSolver(; order = :cyclic))
  r2 = solve!(SparseIterate(p), (1 / n) * LeastSquaresLoss(y, X), NormL1(0.05), CDSolver(; order = :cyclic))
  @test r1.passes == r2.passes
  @test Vector(r1.minimizer) ≈ Vector(r2.minimizer) atol = 1e-8
  # and with the centered data of an intercept
  yc, Xc = y .- mean(y), X .- mean(X; dims = 1)
  mc = cdmodel(QuadraticFunction(Xc'Xc / n, -Xc'yc / n, dot(yc, yc) / (2n)), x)
  mi = cdmodel((1 / n) * LeastSquaresLoss(y, X), x; intercept = true)
  PS.initialize!(mc, x); PS.initialize!(mi, x)
  @test PS.response_scale(mc, x) ≈ PS.response_scale(mi, x)
  # without c, the lower bound maxₖ |bₖ| / √Aₖₖ, as before; a small c leaves it,
  # and a quadratic without b and c has the absolute rule
  m0 = cdmodel(QuadraticFunction(A, b), x)
  @test PS.response_scale(m0, x) ≈ maximum(abs.(b) ./ sqrt.(diag(A)))
  @test PS.response_scale(cdmodel(QuadraticFunction(A, b, 1e-12), x), x) == PS.response_scale(m0, x)
  @test PS.response_scale(cdmodel(QuadraticFunction(A), x), x) == 0
  @test PS.response_scale(cdmodel(2 * QuadraticFunction(A, b, c), x), x) ≈ sqrt(2) * PS.response_scale(mq, x)
end

# ½‖Δ - T‖²_F of a symmetric Δ through the generic interface: along the
# coordinate (r, c) the derivative is (Δ - T)[r, c] times the number of entries
# the coordinate moves, and so is the curvature
mutable struct SymmetricDistance <: CDModel{Float64}
  T::Matrix{Float64}
end
PS.initialize!(m::SymmetricDistance, x) = m
function PS.coordinate_derivatives(m::SymmetricDistance, x::SymmetricSparseIterate, k::Int)
  r, c = ProximalBase.tril_cartesian(x.p, k)
  mult = r == c ? 1.0 : 2.0
  (mult * (coordinates(x)[k] - m.T[r, c]), mult)
end
PS.update_cache!(m::SymmetricDistance, x, k::Int, h) = m
PS.coordinate_scale(m::SymmetricDistance, x, k::Int) = 1.0
PS.response_scale(m::SymmetricDistance, x) = 1.0
PS.loss_value(m::SymmetricDistance, x) = sum(abs2, Matrix(x) - m.T) / 2
ProximalBase.gradient!(G, m::SymmetricDistance, x) = (G .= Matrix(x) .- m.T)

# x'Ax/2 + b'x with only the required functions of the interface
struct MinimalQuadratic <: CDModel{Float64}
  A::Matrix{Float64}
  b::Vector{Float64}
  u::Vector{Float64}
end
PS.initialize!(m::MinimalQuadratic, x) = (m.u .= m.A * Vector(x); m)
PS.coordinate_derivatives(m::MinimalQuadratic, x, k::Int) = (m.u[k] + m.b[k], m.A[k, k])
PS.update_cache!(m::MinimalQuadratic, x, k::Int, h) = (m.u .+= h .* view(m.A, :, k); m)

@testset "more losses, iterates and drivers" begin
  X, y = lassodata()
  n, p = size(X)
  λ = 0.1 * maximum(abs, X' * y) / n
  λs = maximum(abs, X' * y) / n .* 10 .^ range(0, -1.5; length = 6)

  # the generic step on a symmetric iterate: entrywise soft thresholding
  q = 6
  Tm = Matrix(Symmetric(randn(Xoshiro(41), q, q)))
  xs = SymmetricSparseIterate(q)
  solve!(xs, SymmetricDistance(Tm), NormL1(0.5), CDSolver(; tol = 1e-12))
  @test Matrix(xs) ≈ sign.(Tm) .* max.(abs.(Tm) .- 0.5, 0) atol = 1e-12

  # the generic Hessian of a refit: the quadratic through the generic interface
  rng = Xoshiro(42)
  B = randn(rng, 30, 20); A = B' * B / 30; b = randn(rng, 20)
  x = SparseIterate(20)
  refit!(x, MyQuadratic(A, b, zeros(20)); support = [2, 5, 9])
  @test Vector(x)[[2, 5, 9]] ≈ -(A[[2, 5, 9], [2, 5, 9]] \ b[[2, 5, 9]])

  # the Kronecker quadratic on vec Θ: a screened path, a refit, and its scaled form
  Sx = cov(randn(Xoshiro(43), 60, q)); Sy = cov(randn(Xoshiro(44), 60, q))
  C = randn(Xoshiro(45), q, q)
  fk = KronQuadratic(Sx, Sy, C)
  K = kron(Sy, Sx)
  lk = lambda_max(fk, NormL1(1.0), SparseIterate(q * q))
  @test lk ≈ maximum(abs, C)
  pk = solve_path(fk, NormL1(1.0), lk .* [1.0, 0.5, 0.2], CDSolver(; tol = 1e-12); x = SparseIterate(q * q), gaptol = 0)
  θ = Vector(pk.solutions[3])
  @test kkt_l1(K * θ + vec(C), θ, 0.2lk) < 1e-9
  xk = SparseIterate(θ)
  refit!(xk, fk)
  S = findall(!iszero, θ)
  @test (K * Vector(xk) + vec(C))[S] ≈ zeros(length(S)) atol = 1e-10
  x2 = SparseIterate(q * q)
  solve!(x2, 2 * fk, NormL1(0.4lk), CDSolver(; tol = 1e-12))
  @test Vector(x2) ≈ θ atol = 1e-8
  # a matrix iterate keeps its shape along a path
  pm = solve_path(fk, NormL1(1.0), lk .* [1.0, 0.2], CDSolver(; tol = 1e-12); x = SparseIterate(q, q), gaptol = 0)
  @test size(pm.solutions[2]) == (q, q)
  @test vec(Matrix(pm.solutions[2])) ≈ θ atol = 1e-8
  @test_throws ArgumentError solve_path(fk, NormL1(1.0), [lk])        # no iterate to start from

  # paths of the quadratic, the square-root lasso, a logistic loss, groups,
  # and the nonnegative lasso
  Aq, bq = Matrix(Symmetric(X' * X / n)), -X' * y / n
  pq = solve_path(QuadraticFunction(Aq, bq), NormL1(1.0), λs, CDSolver(; tol = 1e-10); gaptol = 0)
  @test kkt_l1(Aq * Vector(pq.solutions[end]) + bq, Vector(pq.solutions[end]), λs[end]) < 1e-8
  fs = SqrtLeastSquaresLoss(y, X)
  @test fs(ones(p)) ≈ norm(y - X * ones(p))
  ls = maximum(abs, X' * y) / norm(y)
  ps = solve_path(fs, NormL1(1.0), ls .* [1.0, 0.7, 0.5], CDSolver(; tol = 1e-12); x = SparseIterate(p), gaptol = 0)
  bs = Vector(ps.solutions[3]); rs = y - X * bs
  @test kkt_l1(-X' * rs / norm(rs), bs, 0.5ls) < 1e-7
  m = cdmodel(fs, SparseIterate(bs)); PS.initialize!(m, SparseIterate(bs))
  @test PS.residuals(m) ≈ rs
  yl = Float64.(X[:, 1] .+ 0.5 .* randn(Xoshiro(46), n) .> 0)
  w = rand(Xoshiro(47), n) .+ 0.5
  fl = LogisticLoss(yl, X; weights = w)
  gl(b) = X' * (w .* (1 ./ (1 .+ exp.(-X * b)) .- yl))
  ll = maximum(abs, gl(zeros(p)))
  pl = solve_path(fl, NormL1(1.0), ll .* [1.0, 0.5, 0.3], CDSolver(; tol = 1e-10, maxpasses = 10^6); gaptol = 0)
  bl = Vector(pl.solutions[3])
  @test kkt_l1(gl(bl), bl, 0.3ll) < 1e-6 * ll
  groups = [i:i+4 for i in 1:5:p]
  gg = GroupNormL2(1.0, groups, ones(length(groups)))
  lg = lambda_max((1 / n) * LeastSquaresLoss(y, X), gg, AtomIterate(Float64, p, groups))
  @test lg ≈ maximum(G -> norm(X[:, G]' * y / n), groups)
  pg = solve_path((1 / n) * LeastSquaresLoss(y, X), gg, lg .* [1 + 1e-9, 0.5], CDSolver(; tol = 1e-10);
                  x = AtomIterate(Float64, p, groups), gaptol = 0)
  @test length(pg.solutions[2]) == p && nnz(pg.solutions[1]) == 0
  pn = solve_path((1 / n) * LeastSquaresLoss(y, X), NormL1Nonneg(1.0), λs, CDSolver(; tol = 1e-10); gaptol = 0)
  @test all(b -> all(>=(0), b), pn.solutions)

  # scaled least squares with weights; an intercept with an offset
  x3, x4 = SparseIterate(p), SparseIterate(p)
  solve!(x3, (1 / n) * GLMLoss(ProximalBase.Squared(), y, X; weights = w), NormL1(λ), CDSolver(; tol = 1e-12))
  solve!(x4, GLMLoss(ProximalBase.Squared(), y, X; weights = w), NormL1(n * λ), CDSolver(; tol = 1e-12))
  @test Vector(x3) ≈ Vector(x4) atol = 1e-8
  o = randn(Xoshiro(48), n)
  x5 = SparseIterate(p)
  m5 = cdmodel(GLMLoss(ProximalBase.Squared(), y, X; offset = o), x5; intercept = true)
  solve!(x5, m5, NormL1(n * λ), CDSolver(; tol = 1e-10))
  res5 = y .- o .- PS.intercept(m5, Vector(x5)) .- X * Vector(x5)
  @test abs(sum(res5)) < 1e-8
  @test kkt_l1(-X' * res5, Vector(x5), n * λ) < 1e-6
  # a quadratic without a linear term has the minimizer 0
  x6 = SparseIterate(p)
  solve!(x6, QuadraticFunction(Aq), NormL1(λ), CDSolver())
  @test nnz(x6) == 0

  # a dense starting vector with a model built once
  m7 = cdmodel((1 / n) * LeastSquaresLoss(y, X), SparseIterate(p))
  x7 = zeros(p)
  @test solve!(x7, m7, NormL1(λ), CDSolver(; tol = 1e-10)).minimizer === x7
  @test kkt_l1(lsgrad(X, y, x7), x7, λ) < 1e-7

  # a Kronecker quadratic without a linear term has the minimizer 0
  x8 = SparseIterate(q * q)
  solve!(x8, KronQuadratic(Sx, Sy), NormL1(0.1), CDSolver())
  @test nnz(x8) == 0
  # the derivative and curvature of a least-squares coordinate
  m9 = cdmodel((1 / n) * LeastSquaresLoss(y, X), SparseIterate(p))
  x9 = SparseIterate(p)
  PS.initialize!(m9, x9)
  @test collect(PS.coordinate_derivatives(m9, x9, 3)) ≈ [-dot(X[:, 3], y) / n, sum(abs2, X[:, 3]) / n]
  @test ProximalBase.isconvex(SqrtLeastSquaresLoss(y, X))

  # results, summaries and errors
  r = solve!(SparseIterate(p), (1 / n) * LeastSquaresLoss(y, X), NormL1(λ), CDSolver(); continuation = 5)
  out = sprint(show, r)
  @test occursin("Coordinate Descent", out) && occursin("Passes: $(r.passes)", out) && occursin("Optimality checks", out)
  @test PS.minimizer(r) === r.minimizer && PS.minimum(r) == r.minimum
  @test PS.iterations(r) == r.passes && PS.converged(r) == r.converged
  @test summary(CDSolver()) == summary(r) == "Coordinate Descent" && summary(ProxNewton()) == "Proximal Newton"
  # Least squares now supplies the quadratic-model oracle used by ProxNewton.
  xn = SparseIterate(p)
  rn = solve!(xn, LeastSquaresLoss(y, X), NormL1(1.0), ProxNewton())
  @test rn.converged && rn.maxchange <= rn.tolerance
  @test kkt_l1(n .* lsgrad(X, y, Vector(xn)), Vector(xn), 1.0) < 1e-7
  @test_throws ArgumentError ProxNewton(; β = 1.5)
end

@testset "user-defined model" begin
  rng = Xoshiro(14)
  B = randn(rng, 30, 20); A = B' * B / 30; b = randn(rng, 20)
  x = SparseIterate(20)
  r = solve!(x, MyQuadratic(A, b, zeros(20)), NormL1(0.2), CDSolver(; tol = 1e-12))
  @test kkt_l1(A * Vector(x) + b, Vector(x), 0.2) < 1e-9
  # and a path through it
  path = solve_path(MyQuadratic(A, b, zeros(20)), NormL1(1.0), [1.0, 0.5, 0.2]; x = SparseIterate(20))
  @test Vector(path.solutions[3]) ≈ Vector(x) atol = 1e-6
  # the required functions alone: the absolute stopping rule, and no value
  xm = SparseIterate(20)
  rm = solve!(xm, MinimalQuadratic(A, b, zeros(20)), NormL1(0.2), CDSolver(; tol = 1e-12))
  @test rm.converged && rm.tolerance == 1e-12 && isnan(rm.minimum)
  @test Vector(xm) ≈ Vector(x) atol = 1e-9
  # the interface is public, not exported
  if VERSION >= v"1.11"
    for name in (:initialize!, :coordinate_step!, :coordinate_derivatives, :update_cache!, :coordinate_scale,
                 :response_scale, :loss_value, :check_penalty, :intercept, :residuals)
      @test Base.ispublic(ProximalSolvers, name) && !Base.isexported(ProximalSolvers, name)
    end
  end
end

@testset "momentum" begin
  @test CDSolver().momentum === nothing
  @test CDSolver(; momentum = true).momentum === true
  @test CDSolver(; momentum = false).momentum === false
  @test CDSolver(; order = :cyclic).momentum === nothing
  @test_throws ArgumentError CDSolver(; order = :cyclic, momentum = true)    # it can stall
  @test_throws ArgumentError CDSolver(; order = :cyclic, anderson = 5, momentum = true)

  # a common factor between the columns, where the random order is fast and
  # the momentum makes it faster
  rng = Xoshiro(41)
  n, p, s = 300, 1000, 20
  X = sqrt(0.5) * randn(rng, n) .+ sqrt(0.5) * randn(rng, n, p)
  y = X[:, 1:s] * randn(rng, s) + randn(rng, n)
  w = 0.5 .+ rand(rng, n)
  λ = 0.02 * maximum(abs, X' * y) / n
  λs = 0.2 * maximum(abs, X' * y) / norm(y)
  f = (1 / n) * LeastSquaresLoss(y, X)
  A, b = X' * X / n, -X' * y / n
  plain = CDSolver(; tol = 1e-10, momentum = false)
  mom = CDSolver(; tol = 1e-10, momentum = true)

  # the same solution in fewer passes over all the losses together; MyQuadratic
  # has a cache that ProximalSolvers does not know, so it is initialized at the
  # extrapolated points
  passes0, passes1 = 0, 0
  for (fm, g) in ((f, NormL1(λ)),
                  (cdmodel(f, SparseIterate(p); intercept = true), NormL1(λ)),
                  (GLMLoss(ProximalBase.Squared(), y, X; weights = w ./ n), NormL1(λ)),
                  (QuadraticFunction(A, b), NormL1(λ)),
                  (SqrtLeastSquaresLoss(y, X), NormL1(λs)),
                  (f, NormL1(λ, rand(rng, p))),
                  (MyQuadratic(A, b, zeros(p)), NormL1(λ)))
    x0, x1 = SparseIterate(p), SparseIterate(p)
    r0 = solve!(x0, fm, g, plain)
    r1 = solve!(x1, fm, g, mom)
    @test r1.converged
    @test Vector(x1) ≈ Vector(x0) atol = 1e-6
    passes0 += r0.passes
    passes1 += r1.passes
  end
  @test passes1 < passes0 / 1.3

  # from a path of levels, without a penalty, and along solve_path
  xref = SparseIterate(p)
  solve!(xref, f, NormL1(λ), plain)
  x = SparseIterate(p)
  @test solve!(x, f, NormL1(λ), mom; continuation = 10).converged
  @test Vector(x) ≈ Vector(xref) atol = 1e-6
  f100 = (1 / n) * LeastSquaresLoss(y, X[:, 1:100])
  x0, x1 = SparseIterate(100), SparseIterate(100)
  solve!(x0, f100, ZeroFunction(), plain)
  solve!(x1, f100, ZeroFunction(), mom)
  @test Vector(x1) ≈ Vector(x0) atol = 1e-6
  λpath = [0.2, 0.1, 0.05, 0.02] .* (maximum(abs, X' * y) / n)
  path0 = solve_path(f, NormL1(1.0), λpath, plain)
  path1 = solve_path(f, NormL1(1.0), λpath, mom)
  @test all(path1.converged)
  for k in eachindex(λpath)
    @test Vector(path1.solutions[k]) ≈ Vector(path0.solutions[k]) atol = 1e-6
  end

  # a logistic GLMLoss, and momentum = true on a symmetric iterate
  Xl = X[:, 1:100]
  yl = Float64.(Xl[:, 1:5] * ones(5) + randn(rng, n) .> 0)
  fl = (1 / n) * LogisticLoss(yl, Xl)
  λl = 0.05 * maximum(abs, Xl' * (yl .- 0.5)) / n
  x0, x1 = SparseIterate(100), SparseIterate(100)
  solve!(x0, fl, NormL1(λl), plain)
  @test solve!(x1, fl, NormL1(λl), mom).converged
  @test Vector(x1) ≈ Vector(x0) atol = 1e-5
  q = 10
  Sx = cov(randn(rng, 60, q)); Sy = cov(randn(rng, 60, q))
  fk = KronQuadratic(Sx, Sy, Sx - Sy)
  λk = 0.2 * maximum(abs, Sy - Sx)
  xs0, xs1 = SymmetricSparseIterate(q), SymmetricSparseIterate(q)
  solve!(xs0, fk, NormL1(λk), plain)
  @test solve!(xs1, fk, NormL1(λk), mom).converged
  @test Matrix(xs1) ≈ Matrix(xs0) atol = 1e-6
  # not on the groups of an AtomIterate
  groups = [((k - 1) * 10 + 1):(k * 10) for k in 1:100]
  gg = GroupNormL2(λ, groups, ones(100))
  @test_throws ArgumentError solve!(AtomIterate(Float64, p, groups), f, gg, mom)

  # by default it is used with the random order, a SparseIterate and a
  # built-in model other than that of KronQuadratic, and not otherwise: the
  # runs of momentum = true or false
  passes(f, g, x, s) = (Random.seed!(7); solve!(x, f, g, s).passes)
  auto = CDSolver(; tol = 1e-10)
  @test passes(f, NormL1(λ), SparseIterate(p), auto) == passes(f, NormL1(λ), SparseIterate(p), mom)
  @test passes(f, NormL1(λ), SparseIterate(p), auto) != passes(f, NormL1(λ), SparseIterate(p), plain)
  mq = MyQuadratic(A, b, zeros(p))
  @test passes(mq, NormL1(λ), SparseIterate(p), auto) == passes(mq, NormL1(λ), SparseIterate(p), plain)
  fsq = SqrtQuadraticFunction(A, b, dot(y, y) / n)
  @test passes(fsq, NormL1(λs / sqrt(n)), SparseIterate(p), auto) == passes(fsq, NormL1(λs / sqrt(n)), SparseIterate(p), mom)
  @test passes(fl, NormL1(λl), SparseIterate(100), auto) == passes(fl, NormL1(λl), SparseIterate(100), mom)
  @test passes(fk, NormL1(λk), SymmetricSparseIterate(q), auto) ==
        passes(fk, NormL1(λk), SymmetricSparseIterate(q), plain)
  @test passes(fk, NormL1(λk), SparseIterate(q * q), auto) == passes(fk, NormL1(λk), SparseIterate(q * q), plain)
  @test passes(f, gg, AtomIterate(Float64, p, groups), auto) == passes(f, gg, AtomIterate(Float64, p, groups), plain)
  @test passes(f, NormL1(λ), SparseIterate(p), CDSolver(; tol = 1e-10, order = :cyclic)) ==
        passes(f, NormL1(λ), SparseIterate(p), CDSolver(; tol = 1e-10, order = :cyclic, momentum = false))

  # every run starts a new history
  m = cdmodel(f, SparseIterate(p))
  st = PS._CDState(Float64, SparseIterate(p), true)
  runs = map(1:2) do _
    x = SparseIterate(p)
    PS.initialize!(m, x)
    Random.seed!(9)
    PS._cd!(x, m, NormL1(λ), st, mom)
    (st.passes, Vector(x))
  end
  @test runs[1] == runs[2]
end

@testset "argument checks" begin
  X, y = lassodata()
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  @test_throws ArgumentError CDSolver(; tol = -1)
  @test_throws ArgumentError CDSolver(; maxpasses = -1)
  @test_throws ArgumentError CDSolver(; order = :sideways)
  @test_throws ArgumentError solve!(SparseIterate(p), f, NormL2(1.0), CDSolver())        # not separable
  @test_throws DimensionMismatch solve!(SparseIterate(p + 1), f, NormL1(1.0), CDSolver())
  @test_throws ArgumentError solve!(SparseIterate(p), NormL2(1.0), NormL1(1.0), CDSolver()) # no model
  Xn = copy(X); Xn[1, 1] = NaN
  @test_throws ArgumentError solve!(SparseIterate(p), LeastSquaresLoss(y, Xn), NormL1(1.0), CDSolver())
  @test_throws ArgumentError solve!(SparseIterate(p), f, NormL1(1.0), CDSolver(); continuation = -1)
  # a weight or a bound for every entry of x, checked before the passes
  for g in (NormL1(1.0, ones(p - 1)), ElasticNet(1.0, 0.1, ones(p + 1)), IndBox(zeros(p - 1), ones(p - 1)))
    x = SparseIterate(p)
    @test_throws DimensionMismatch solve!(x, f, g, CDSolver())
    @test nnz(x) == 0
  end
  @test_throws DimensionMismatch solve!(SparseIterate(p), f, NormL1(1.0, ones(p - 1)), CDSolver(); continuation = 5)
  @test_throws DimensionMismatch solve_path(f, NormL1(1.0, ones(p - 1)), [1.0, 0.5])
  fk = KronQuadratic(Matrix(1.0I, 4, 4), Matrix(1.0I, 4, 4), ones(4, 4))
  @test_throws DimensionMismatch solve!(SymmetricSparseIterate(4), fk, NormL1(1.0, ones(10)), CDSolver())
end

@testset "allocations" begin
  X, y = lassodata()
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  # the passes allocate nothing once the model and the state exist
  function passes_bytes(x, m, g, s)
    PS.initialize!(m, x)
    st = PS._CDState(Float64, x, s)
    PS._cd!(x, m, g, st, s)
    fill!(x, 0.0); PS.initialize!(m, x)
    @allocated PS._cd!(x, m, g, st, s)
  end
  for s in (CDSolver(; order = :cyclic), CDSolver(; order = :random), CDSolver(; momentum = true),
            CDSolver(; rng = Xoshiro(1)))
    @test passes_bytes(SparseIterate(p), cdmodel(f, SparseIterate(p)), NormL1(0.1), s) == 0
    q = 10
    Sx = cov(randn(Xoshiro(15), 50, q)); Sy = cov(randn(Xoshiro(16), 50, q))
    fk = KronQuadratic(Sx, Sy, Sx - Sy)
    @test passes_bytes(SymmetricSparseIterate(q), cdmodel(fk, SymmetricSparseIterate(q)), NormL1(0.05), s) == 0
    @test passes_bytes(SparseIterate(q * q), cdmodel(fk, SparseIterate(q * q)), NormL1(0.05), s) == 0
    fq = SqrtQuadraticFunction(X' * X / n, -X' * y / n, dot(y, y) / n)
    @test passes_bytes(SparseIterate(p), cdmodel(fq, SparseIterate(p)), NormL1(0.02), s) == 0
    # weights with an intercept, for least squares and the square-root lasso
    w = rand(Xoshiro(18), n) .+ 0.5
    fw = (1 / n) * GLMLoss(ProximalBase.Squared(), y, X; weights = w)
    @test passes_bytes(SparseIterate(p), cdmodel(fw, SparseIterate(p); intercept = true), NormL1(0.1), s) == 0
    fs = SqrtLeastSquaresLoss(y, X; weights = w)
    @test passes_bytes(SparseIterate(p), cdmodel(fs, SparseIterate(p); intercept = true), NormL1(0.5), s) == 0
  end
  # block coordinate descent: initialize! clears the group curvatures, which the
  # second run computes again in the workspace that the first one allocated
  groups = vcat([[k] for k in 1:5], [i:min(i + 6, p) for i in 6:7:p])
  g = GroupNormL2(0.05, groups, ones(length(groups)))
  w = rand(Xoshiro(17), n) .+ 0.5
  for s in (CDSolver(; order = :cyclic), CDSolver(; order = :random))
    x = AtomIterate(Float64, p, groups)
    @test passes_bytes(x, cdmodel(f, x), g, s) == 0
    @test passes_bytes(x, cdmodel(f, x; intercept = true), g, s) == 0
    @test passes_bytes(x, cdmodel(GLMLoss(ProximalBase.Squared(), y, X; weights = w), x), g, s) == 0
    @test passes_bytes(x, cdmodel(QuadraticFunction(X' * X / n, -X' * y / n), x), g, s) == 0
  end
end

@testset "group curvatures" begin
  # the curvature of the loss over each group, λmax of the Gram matrix of its
  # centered, weighted columns (of A[G, G] for a quadratic), as eigmax computes it
  X, y = lassodata()
  n, p = size(X)
  groups = vcat([[1], 2:3, 4:6], [i:min(i + 9, p) for i in 7:10:p])
  w = rand(Xoshiro(18), n) .+ 0.5
  for T in (Float64, Float32)
    Xt, yt, wt = T.(X), T.(y), T.(w)
    x = AtomIterate(T, p, groups)
    for (f, intercept) in (((one(T) / n) * LeastSquaresLoss(yt, Xt), false), (LeastSquaresLoss(yt, Xt), true),
                           (GLMLoss(ProximalBase.Squared(), yt, Xt; weights = wt), false))
      m = cdmodel(f, x; intercept)
      PS.initialize!(m, x)
      for k in reverse(eachindex(groups))      # the workspace grows to the largest group first
        G = groups[k]
        XG = Xt[:, G] .- transpose(m.xbar[G])
        f isa GLMLoss && (XG .*= sqrt.(wt))
        @test PS._groupcurvature!(m, x, k) ≈ m.s * eigmax(Symmetric(XG' * XG)) rtol = 10 * eps(T)
      end
    end
    A = Xt' * Xt / n
    m = cdmodel(QuadraticFunction(A, -Xt' * yt / n), x)
    PS.initialize!(m, x)
    for k in eachindex(groups)
      G = groups[k]
      @test PS._groupcurvature!(m, x, k) ≈ eigmax(Symmetric(A[G, G])) rtol = 10 * eps(T)
    end
  end
  # the levels of a path keep the curvatures, which initialize! clears, as the
  # data may have changed in place
  x = AtomIterate(Float64, p, groups)
  for m in (cdmodel((1 / n) * LeastSquaresLoss(y, X), x), cdmodel(QuadraticFunction(X' * X / n, -X' * y / n), x))
    PS.initialize!(m, x)
    L = PS._groupcurvature!(m, x, 2)
    PS._initialize!(m, x, false)
    @test m.L[2] == L
    PS.initialize!(m, x)
    @test isnan(m.L[2])
  end
end

end
