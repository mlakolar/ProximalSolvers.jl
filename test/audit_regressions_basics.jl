# Audit regressions that guard against false success: an active-set or square-root result, an
# invalid certificate or a failed line search must not report convergence or move the accepted
# point. Moved from test/audit_regressions.jl to run in the quick tier (#121); the other cases
# of `audit_regressions.jl` stay there.

module AuditRegressionBasics

using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

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
    @test isfinite(r.gap) && r.gap >= 0.95 - 1e-12
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
    @test isfinite(r.gap) && r.gap >= 0.95 - 1e-9
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

end
