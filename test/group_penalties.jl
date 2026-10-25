# Block coordinate descent on an AtomIterate with penalties other than
# GroupNormL2: the group norms of ProximalBase through their own block step, and
# separable penalties entry by entry after the group's gradient step.

module GroupPenaltiesTests

using Test, LinearAlgebra, Random, SparseArrays
using ProximalBase
using ProximalSolvers
const PS = ProximalSolvers

function groupdata(; n = 80, p = 60, seed = 21)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  β = zeros(p); β[1:4] .= [2, -1.5, 1, -1]; β[11:13] .= [1, 1, -1]
  X, X * β + 0.3 * randn(rng, n)
end

# a reference solution by accelerated proximal gradient to high accuracy
function reference(f, g, x0)
  res = solve!(copy(x0), f, g, AccProxGradDescent(), ProximalOptions(; maxiter = 50_000, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-12))
  res.minimizer
end

@testset "GroupNormLinf" begin
  X, y = groupdata()
  n, p = size(X)
  groups = [i:i+4 for i in 1:5:p]
  λ = 0.1 * maximum(G -> norm(X[:, G]' * y, 1), groups) / n
  g = GroupNormLinf(λ, groups)
  for f in ((1 / n) * LeastSquaresLoss(y, X), QuadraticFunction(X' * X / n, -X' * y / n))
    for order in (:cyclic, :random)
      x = AtomIterate(Float64, p, groups)
      r = solve!(x, f, g, CDSolver(; order, tol = 1e-12))
      @test r.converged
      xref = reference(f, g, zeros(p))
      @test Vector(x) ≈ xref atol = 1e-6
      @test f(Vector(x)) + g(Vector(x)) ≈ f(xref) + g(xref) rtol = 1e-10
      # optimality of the zero groups: ‖∇_G f‖₁ ≤ λ wₖ
      grad = gradient(f, Vector(x))
      for (k, G) in enumerate(groups)
        all(iszero, Vector(x)[G]) && @test norm(grad[G], 1) <= λ + 1e-8
      end
    end
  end
  # a dense vector becomes an AtomIterate with the groups of g
  f = (1 / n) * LeastSquaresLoss(y, X)
  xd = zeros(p)
  solve!(xd, f, g, CDSolver(; tol = 1e-12))
  @test xd ≈ reference(f, g, zeros(p)) atol = 1e-6
  # the iterate must have the groups of g
  @test_throws ArgumentError solve!(SparseIterate(p), f, g, CDSolver())
  @test_throws ArgumentError solve!(AtomIterate(Float64, p, [1:p]), f, g, CDSolver())
end

@testset "separable penalties on an AtomIterate" begin
  X, y = groupdata(; seed = 22)
  n, p = size(X)
  groups = [i:i+2 for i in 1:3:p]
  f = (1 / n) * LeastSquaresLoss(y, X)
  λ = 0.1 * norm(X' * y, Inf) / n
  for g in (NormL1(λ), ElasticNet(λ, 0.1), IndBox(-0.5, 0.5))
    xa = AtomIterate(Float64, p, groups)
    solve!(xa, f, g, CDSolver(; tol = 1e-12))
    xs = SparseIterate(p)
    solve!(xs, f, g, CDSolver(; tol = 1e-12))
    @test Vector(xa) ≈ Vector(xs) atol = 1e-7
  end
end

@testset "a group that f does not depend on" begin
  X, y = groupdata(; seed = 23)
  n, p = size(X)
  X[:, 6:10] .= 0
  groups = [i:i+4 for i in 1:5:p]
  f = (1 / n) * LeastSquaresLoss(y, X)
  x = AtomIterate(ones(p), groups)
  solve!(x, f, GroupNormLinf(0.01, groups), CDSolver(; tol = 1e-10))
  @test all(iszero, Vector(x)[6:10])             # the minimizer of the penalty
  x = AtomIterate(ones(p), groups)
  solve!(x, f, GroupNormLinf(0.01, groups, [1, 0, ones(length(groups) - 2)...]), CDSolver(; tol = 1e-10))
  @test all(==(1), Vector(x)[6:10])              # an unpenalized group keeps its values
end

@testset "weighted gradients after large group steps" begin
  # The specialized L2 step needs |G| entries and the generic Linf step needs
  # 2|G|. Both can exceed the n entries of the weighted-gradient workspace.
  n = 12
  for T in (Float32, Float64), sparse_design in (false, true), fit_intercept in (false, true),
      (penalty, groups) in ((GroupNormL2, [1:15, 16:18]), (GroupNormLinf, [1:7, 8:10]))
    rng = Xoshiro(59)
    p = last(last(groups))
    X = randn(rng, T, n, p)
    X[rand(rng, n, p) .< 0.5] .= 0
    A = sparse_design ? sparse(X) : X
    y = randn(rng, T, n)
    w = rand(rng, T, n) .+ T(0.5)
    offset = T(0.1) .* randn(rng, T, n)
    f = (one(T) / n) * GLMLoss(ProximalBase.Squared(), y, A; weights = w, offset)
    x = AtomIterate(T(0.1) .* randn(rng, T, p), groups)
    m = cdmodel(f, x; intercept = fit_intercept)
    g = penalty(T(0.05), groups, ones(T, length(groups)))
    PS.initialize!(m, x)
    grad = zeros(T, p)
    atol = T === Float32 ? 2f-6 : 1e-13
    rtol = T === Float32 ? 2f-5 : 1e-12
    for _ in 1:2, k in eachindex(groups)
      PS._groupstep!(m, g, x, k, false)
      PS.gradient!(grad, m, x)
      b0 = fit_intercept ? PS.intercept(m, x) : zero(T)
      residual = y .- offset .- b0 .- A * Vector(x)
      expected = -(transpose(A) * (w .* residual)) / n
      @test grad ≈ expected atol = atol rtol = rtol
      @test PS.residuals(m) ≈ residual atol = atol rtol = rtol
    end
  end
end

@testset "weighted paths with a group larger than n" begin
  n, p = 12, 18
  groups = [1:15, 16:18]
  for T in (Float32, Float64), sparse_design in (false, true), fit_intercept in (false, true)
    rng = Xoshiro(60)
    X = randn(rng, T, n, p)
    X[rand(rng, n, p) .< 0.5] .= 0
    A = sparse_design ? sparse(X) : X
    y = A[:, 1] .+ T(0.2) .* randn(rng, T, n) .+ T(0.5)
    w = rand(rng, T, n) .+ T(0.5)
    f = (one(T) / n) * GLMLoss(ProximalBase.Squared(), y, A; weights = w)
    g = GroupNormL2(one(T), groups, ones(T, length(groups)))
    x = AtomIterate(T, p, groups)
    m = cdmodel(f, x; intercept = fit_intercept)
    λmax = lambda_max(m, g, x)
    λs = λmax .* T[1.01, 0.6, 0.3]
    tol = T === Float32 ? 2e-5 : 1e-10
    method = CDSolver(; order = :cyclic, tol)
    screened = solve_path(m, g, λs, method; x)
    xplain = AtomIterate(T, p, groups)
    plain = solve_path(cdmodel(f, xplain; intercept = fit_intercept), g, λs, method;
                       x = xplain, screening = false)
    @test all(screened.converged) && all(plain.converged)
    @test all(screened.kkt_checks .>= 1)
    @test iszero(norm(screened.solutions[1]))
    @test norm(screened.solutions[end]) > 0
    @test screened.values ≈ plain.values rtol = (T === Float32 ? 5e-4 : 1e-8)
  end
end

@testset "allocations" begin
  X, y = groupdata()
  n, p = size(X)
  groups = [i:i+4 for i in 1:5:p]
  # the group curvatures, which initialize! resets, are kept from the first run:
  # computing them allocates (ProximalSolvers #20), the steps must not
  function passes_bytes(x, m, g, s)
    PS.initialize!(m, x)
    st = PS._CDState(Float64, x, s.random)
    PS._cd!(x, m, g, st, s)
    L = copy(m.L)
    fill!(x, 0.0); PS.initialize!(m, x)
    copyto!(m.L, L)
    @allocated PS._cd!(x, m, g, st, s)
  end
  for f in ((1 / n) * LeastSquaresLoss(y, X), QuadraticFunction(X' * X / n, -X' * y / n)),
      g in (GroupNormLinf(0.05, groups), NormL1(0.05)), s in (CDSolver(; order = :cyclic), CDSolver(; order = :random))
    x = AtomIterate(Float64, p, groups)
    @test passes_bytes(x, cdmodel(f, x), g, s) == 0
  end
  # a weighted model whose groups need more scratch space than its n entries
  Xw, yw = X[1:20, :], y[1:20]
  big = [1:15, 16:30, 31:45, 46:60]
  fw = GLMLoss(ProximalBase.Squared(), yw, Xw; weights = rand(Xoshiro(3), 20) .+ 0.5)
  for g in (GroupNormL2(0.5, big), GroupNormLinf(0.5, big), SparseGroupNormL2(0.2, 0.5, big))
    x = AtomIterate(Float64, p, big)
    @test passes_bytes(x, cdmodel(fw, x), g, CDSolver()) == 0
  end
end

# LSModel kept the scratch space of the group steps in the buffer of the weighted
# gradient, which then no longer had n entries (ProximalSolvers #59)
@testset "weighted models with groups larger than n" begin
  rng = Xoshiro(59)
  n, p = 20, 60
  X, y = randn(rng, n, p), randn(rng, n)
  w = rand(rng, n) .+ 0.5
  f = GLMLoss(ProximalBase.Squared(), y, X; weights = w)
  wgrad(β) = -X' * (w .* (y - X * β))

  # the reproduction of the issue: the strong rule takes the gradient after the
  # group steps
  groups = [1:30, 31:60]
  λmax = lambda_max(f, GroupNormL2(1.0, groups), AtomIterate(p, groups))
  λs = λmax .* [1.0, 0.5, 0.25, 0.1]
  path = solve_path(f, GroupNormL2(1.0, groups), λs, CDSolver(; tol = 1e-12); x = AtomIterate(p, groups), gaptol = 0)
  @test all(path.converged)
  plain = solve_path(f, GroupNormL2(1.0, groups), λs, CDSolver(; tol = 1e-12); x = AtomIterate(p, groups), screening = false, gaptol = 0)
  @test all(norm(Vector(a) - Vector(b)) <= 1e-8 * (1 + norm(Vector(b))) for (a, b) in zip(path.solutions, plain.solutions))
  @test path.values ≈ plain.values rtol = 1e-12
  # duality gaps and gap-safe screening also take the gradient
  for s in (CDSolver(; gaptol = 1e-10), CDSolver(; tol = 1e-12, gapsafe = true))
    x = AtomIterate(Float64, p, groups)
    r = solve!(x, f, GroupNormL2(λs[3], groups), s)
    @test r.converged
    @test Vector(x) ≈ Vector(plain.solutions[3]) atol = 1e-6
  end

  # the generic block step, which takes 2|G| entries, along warm-started levels
  # on one model, whose gradient must stay right
  groups = [1:12, 13:24, 25:36, 37:48, 49:60]
  for g0 in (GroupNormLinf(1.0, groups), SparseGroupNormL2(0.5, 0.5, groups))
    x = AtomIterate(Float64, p, groups)
    m = cdmodel(f, x)
    λ0 = maximum(G -> norm(wgrad(zeros(p))[G], Inf), groups)
    for λ in λ0 .* [0.5, 0.2, 0.1]
      g = g0 isa GroupNormLinf ? GroupNormLinf(λ, groups) : SparseGroupNormL2(λ / 2, λ / 2, groups)
      r = solve!(x, m, g, CDSolver(; tol = 1e-12))
      @test r.converged
      grad = zeros(p)
      PS.gradient!(grad, m, x)
      @test grad ≈ wgrad(Vector(x)) atol = 1e-10
      xref = reference(f, g, zeros(p))
      @test f(Vector(x)) + g(Vector(x)) ≈ f(xref) + g(xref) rtol = 1e-9
    end
    @test length(m.tmp) == n
  end
end

end
