module AuditRegressions
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

@testset "flat curvature retains the linear term" begin
  # min -x + 0.1|x| is unbounded below: no point may be returned as a solution
  f = QuadraticFunction(zeros(1, 1), [-1.0])
  x = SparseIterate(1)
  @test_throws ArgumentError solve!(x, f, NormL1(0.1), CDSolver())
  @test iszero(x[1])
  @test kkt_residual(f, NormL1(0.1), x) == Inf
  f = KronQuadratic(zeros(1, 1), ones(1, 1), -ones(1, 1))
  for x in (SparseIterate(1), SymmetricSparseIterate(1))
    @test_throws ArgumentError solve!(x, f, NormL1(0.1), CDSolver())
  end
  # Bounded flat directions have minimizers, which the subgradient condition
  # -G ∈ ∂g(x) identifies: a bound of a box, or zero for |G| ≤ λ.
  for (A, b, g, expected) in ((zeros(1, 1), [-1.0], IndBox(-1.0, 1.0), [1.0]),
                              (zeros(1, 1), [1.0], IndBox(-1.0, 1.0), [-1.0]),
                              (zeros(1, 1), [-0.05], NormL1(0.1), [0.0]),
                              (zeros(1, 1), [-0.1], NormL1(0.1), [0.0]),
                              (zeros(1, 1), [1.0], NormL1Nonneg(0.1), [0.0]),
                              ([0.0 0.0; 0.0 1.0], [0.05, -1.0], NormL1(0.1), [0.0, 0.9]))
    f = QuadraticFunction(A, b)
    x = SparseIterate(length(b))
    @test solve!(x, f, g, CDSolver()).converged
    @test Vector(x) ≈ expected
    @test kkt_residual(f, g, x) <= 1e-12
  end
  x = SparseIterate([0.5])
  f = QuadraticFunction(zeros(1, 1), [-0.05])
  @test solve!(x, f, NormL1(0.1), CDSolver()).converged && iszero(x[1])
  f = KronQuadratic([0.0 0.0; 0.0 1.0], ones(1, 1), reshape([0.05, -1.0], 2, 1))
  x = SparseIterate(2)
  @test solve!(x, f, NormL1(0.1), CDSolver()).converged
  @test Vector(x) ≈ [0.0, 0.9]
  # an active group with zero curvature and ‖∇‖ ≤ λ moves to zero
  groups = [1:2]
  xg = AtomIterate([1.0, -1.0], groups)
  @test solve!(xg, QuadraticFunction(zeros(2, 2), [0.03, 0.04]), GroupNormL2(0.1, groups), CDSolver()).converged
  @test all(iszero, Vector(xg))
  # A flat loss does not make a nonzero penalized coefficient stationary.
  x = SparseIterate([2.0])
  f = QuadraticFunction(zeros(1, 1), zeros(1))
  @test kkt_residual(f, NormL1(0.1), x) == 2
  @test solve!(x, f, NormL1(0.1), CDSolver()).converged
  @test iszero(x[1])
  groups = [1:1]
  xg = AtomIterate(1, groups)
  @test_throws ArgumentError solve!(xg, QuadraticFunction(zeros(1,1), [-1.0]), GroupNormL2(0.1, groups), CDSolver())
end

@testset "symmetric coordinate penalties and QUIC use both weights" begin
  S = [1.0 0.5; 0.5 1.0]
  g = NormL1(0.1, [0.0 1.0; 3.0 0.0])
  @test_throws ArgumentError solve!(SymmetricSparseIterate(2), KronQuadratic(S, S, S), g, CDSolver())
  x, reference = Matrix(1.0I, 2, 2), Matrix(1.0I, 2, 2)
  solve!(x, LogDetLoss(S), g, ProxNewton(inner = CDSolver(rng = Xoshiro(1))))
  solve!(reference, LogDetLoss(S), NormL1(0.1, [0.0 2.0; 2.0 0.0]), ProxNewton(inner = CDSolver(rng = Xoshiro(1))))
  @test x ≈ reference
  @test isposdef(Symmetric(x))
  @test duality_gap(LogDetLoss(S), g, x).gap < 1e-7
end

@testset "bounded result display" begin
  r = solve!([big"1.1"], ZeroFunction(), ZeroFunction(), AccProxGradDescent())
  @test occursin("Minimizer", sprint(show, r))
  large = solve!(ones(10_000), ZeroFunction(), ZeroFunction(), AccProxGradDescent())
  sprint(show, large)
  @test (@allocated sprint(show, large)) < 16_000
end

@testset "refit restricts the whole point" begin
  f = LeastSquaresLoss([3.0, 4.0], Matrix(1.0I, 2, 2))
  for cache in (nothing, RefitCache())
    x = SparseIterate([1.0, 2.0])
    @test refit!(x, f; support = [1], cache) === x
    @test Vector(x) ≈ [3.0, 0.0]
    refit!(x, f; support = Int[], cache)
    @test all(iszero, x)
    @test_throws ArgumentError refit!(x, f; support = [1, 1])
    @test_throws ArgumentError refit!(x, f; support = [3])
  end
end

@testset "ADMM storage and finite stopping" begin
  x = [2.0]
  @test_throws ArgumentError solve!(x, SqrNormL2(1.0), NormL1(0.2), ADMMSolver(); u = x)
  @test x == [2.0]
  x = ([2.0], [3.0]); u = (x[2], [0.0])
  @test_throws ArgumentError solve!(x, SeparableSum(SqrNormL2(), SqrNormL2()),
                                  SeparableSum(NormL1(0.2), NormL1(0.2)), ADMMSolver(); u)
  @test_throws ArgumentError ADMMSolver(abstol = Inf)
  @test_throws ArgumentError ADMMSolver(reltol = -1)
  @test_throws ArgumentError ADMMSolver(ρ = Inf)
end

@testset "active-set success needs a full residual" begin
  f = QuadraticFunction(Matrix(Diagonal([1.0, 100.0])), [-1.0, -1.0])
  x = zeros(2)
  r = solve!(x, f, NormL1(0.1), ActiveAccProxGradDescent(max_outer = 1),
             ProximalOptions(maxiter = 2, ftol = 1.0, xtol = 1.0, gradtol = 1e-8))
  gradient = f.A*x + f.b
  residual = maximum(abs.(x - sign.(x-gradient).*max.(abs.(x-gradient).-0.1,0)))
  @test residual > 1e-3
  @test !r.converged
  rng = Xoshiro(88)
  X, y = randn(rng, Float32, 60, 25), randn(rng, Float32, 60)
  x = zeros(Float32, 25)
  r = solve!(x, LeastSquaresLoss(y, X), NormL1(0.05f0), ActiveAccProxGradDescent(),
             ProximalOptions(maxiter = 5000, ftol = 1e-6, xtol = 1e-6, gradtol = 1e-5))
  gradient = X'*(X*x-y)
  residual = maximum(abs.(x - sign.(x-gradient).*max.(abs.(x-gradient).-0.05f0,0)))
  @test r.converged
  @test residual <= 1e-5 * max(1, norm(X'y, Inf))
end

@testset "square-root losses converge only with a duality gap" begin
  # Coordinatewise stops at an exact fit: objective 0.2, while zero gives 0.01.
  X = [1.0 1.0; 0.0 0.01]
  start = [1.0, -1.0]; y = X * start; g = NormL1(0.1)
  for f in (SqrtLeastSquaresLoss(y, X), SqrtQuadraticFunction(X'X, -X'y, dot(y,y)))
    x = SparseIterate(start)
    r = @test_logs (:warn, r"coordinate descent") solve!(x, f, g, CDSolver(order = :cyclic))
    @test !r.converged
    @test r.minimum > f(zeros(2)) + g(zeros(2))
  end
  # The same trap with a residual outside the column space, which never
  # becomes exactly zero
  X3 = [1.0 1.0; 0.0 0.01; 0.0 0.0]
  for δ in (1e-12, 1e-9)
    y3 = X3 * start + [0.0, 0.0, δ]
    x = SparseIterate(start)
    r = @test_logs (:warn, r"coordinate descent") solve!(x, SqrtLeastSquaresLoss(y3, X3), g, CDSolver(order = :cyclic))
    @test !r.converged
    @test r.gap > 0.5
  end
  x = SparseIterate(2)
  @test solve!(x, SqrtLeastSquaresLoss(zeros(2), X), g, CDSolver()).converged
  # an ordinary fit is certified, and its gap bounds the suboptimality
  rng = Xoshiro(3)
  Xn = randn(rng, 100, 10); yn = Xn[:, 1:2] * [1.0, -1.0] + 0.5randn(rng, 100)
  λ = 0.2 * norm(Xn'yn, Inf) / norm(yn)
  x = SparseIterate(10)
  r = solve!(x, SqrtLeastSquaresLoss(yn, Xn), NormL1(λ), CDSolver())
  @test r.converged
  @test 0 <= r.gap <= 1e-4
  θ = (yn - Xn*Vector(x)) / norm(yn - Xn*Vector(x))
  θ .*= min(1, λ / norm(Xn'θ, Inf))
  @test r.minimum - dot(yn, θ) <= 1e-4 * r.minimum
end

# Adding a constant must not let an incomplete Newton step certify stationarity.
struct ShiftedLogistic <: ProximalBase.ScalarLoss end
(::ShiftedLogistic)(η, y) = ProximalBase.Logistic()(η, y) + 1e12
ProximalBase.deriv(::ShiftedLogistic, η, y) = ProximalBase.deriv(ProximalBase.Logistic(), η, y)
ProximalBase.deriv2(::ShiftedLogistic, η, y) = ProximalBase.deriv2(ProximalBase.Logistic(), η, y)
ProximalBase.curvature(::ShiftedLogistic) = 0.25

@testset "GLM stopping checks the original gradient" begin
  X = reshape([1.0, 2.0, -1.0], :, 1); y = [1.0, 1.0, 0.0]
  f = GLMLoss(ShiftedLogistic(), y, X); g = NormL1(0.1)
  x = SparseIterate(1)
  r = solve!(x, f, g, ProxNewton(maxiter = 1))
  grad = sum(X[i] * ProximalBase.deriv(ProximalBase.Logistic(), X[i]*x[1], y[i]) for i in eachindex(y))
  @test abs(grad + 0.1sign(x[1])) > 1e-3
  @test !r.converged
end

@testset "invalid certificates cannot pass stopping" begin
  @test PS._relative_gap(1.0, 2.0) == Inf
  @test PS._relative_gap(-Inf, 0.0) == Inf
  @test PS._relative_gap(Inf, Inf) == Inf
  @test PS._relative_gap(NaN, 0.0) == Inf
  @test 0 <= PS._relative_gap(1.0, nextfloat(1.0)) <= 8eps()
  # The public certificate exposes its raw arithmetic, including NaN.
  c = duality_gap(SqrNormL2(1.0), ZeroFunction(), NormL1(1.0), ones(1,1), [NaN], [0.0])
  @test isnan(c.gap)
end

@testset "zero-weight Poisson observations do not overflow the loss" begin
  f = PoissonLoss([0.0, 0.0], reshape([1.0, 1000.0], :, 1); weights = [1.0, 0.0])
  @test f([1.0]) ≈ exp(1.0)
  for method in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent(), ProxNewton())
    x = [1.0]
    r = solve!(x, f, NormL1(0.1), method)
    @test isfinite(r.minimum)
    @test r.minimum ≈ f(x) + 0.1abs(x[1])
    @test abs(exp(x[1]) - 0.1) < 1e-3
  end
end

struct InvalidGradient <: AbstractFunction end
(::InvalidGradient)(x) = zero(eltype(x))
ProximalBase.issmooth(::Type{InvalidGradient}) = true
ProximalBase.value_and_gradient!(out, ::InvalidGradient, x) = (fill!(out, eltype(out)(NaN)); zero(eltype(x)))

@testset "line-search failure preserves the accepted point" begin
  @test_throws ErrorException PS.LineSearches.next_curvature(floatmax(Float32), 0.5)
  for method in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())
    x = [1.0, 2.0]
    @test_throws ErrorException solve!(x, InvalidGradient(), ZeroFunction(), method)
    @test x == [1.0, 2.0]
  end
end

@testset "finite tolerances and penalty grids" begin
  @test_throws ArgumentError ProximalOptions(gaptol = Inf)
  @test_throws ArgumentError CDSolver(gaptol = Inf)
  @test_throws ArgumentError ProxNewton(tol = Inf)
  @test_throws ArgumentError LLA(tol = Inf)
  f = LeastSquaresLoss([1.0], ones(1,1))
  for method in (CDSolver(), ProxNewton(), LLA())
    @test_throws ArgumentError solve_path(f, NormL1(1.0), [Inf], method)
  end
end
end
