# Proximal Newton through ProximalBase's quadratic-model oracle, independently
# of the specialized GLM and graphical-lasso implementations.
module GenericNewtonTests

using Test, LinearAlgebra, Random
using ProximalBase
using ProximalSolvers

function l1_residual(f, x, λ)
  b = Vector(x)
  d = gradient(f, b)
  maximum(eachindex(b)) do i
    iszero(b[i]) ? max(abs(d[i]) - λ, zero(λ)) : abs(d[i] + λ * sign(b[i]))
  end
end

# A non-GLM loss with positive definite Hessian. The optional open box makes
# an oversized first Newton trial return Inf, while the solution stays inside.
mutable struct QuarticLoss{T} <: AbstractFunction
  c::Vector{T}
  cap::T
  rejected::Int
  invalid_gradients::Int
  model_updates::Int
end
QuarticLoss(c::Vector{T}; cap = T(Inf)) where {T} = QuarticLoss(c, T(cap), 0, 0, 0)
ProximalBase.issmooth(::Type{<:QuarticLoss}) = true
ProximalBase.isconvex(::Type{<:QuarticLoss}) = true
ProximalBase.hashessian(::Type{<:QuarticLoss}) = true

function (f::QuarticLoss{T})(x::AbstractVector) where {T}
  if any(v -> abs(v) >= f.cap, x)
    f.rejected += 1
    return T(Inf)
  end
  sum(x[i]^4 / 4 + x[i]^2 / 2 - f.c[i] * x[i] for i in eachindex(x))
end

function ProximalBase.value_and_gradient!(out::AbstractVector, f::QuarticLoss, x::AbstractVector)
  any(v -> abs(v) >= f.cap, x) && (f.invalid_gradients += 1)
  @. out = x^3 + x - f.c
  f(x)
end
ProximalBase.gradient!(out::AbstractVector, f::QuarticLoss, x::AbstractVector) =
  (value_and_gradient!(out, f, x); out)
ProximalBase.hessian_vec!(out::AbstractVector, ::QuarticLoss, x::AbstractVector, v::AbstractVector) =
  (@. out = (1 + 3x^2) * v)

function ProximalBase.quadratic_model(f::QuarticLoss{T}, x::AbstractVector) where {T}
  p = length(x)
  # cdmodel copies a Diagonal matrix, so each updated oracle must refresh the
  # inner model rather than keep a stale dense copy of the first Hessian.
  quadratic_model!(QuadraticFunction(Diagonal(zeros(T, p)), zeros(T, p), zero(T)), f, x)
end

function ProximalBase.quadratic_model!(q::QuadraticFunction, f::QuarticLoss, x::AbstractVector)
  f.model_updates += 1
  fill!(q.A, 0)
  for i in eachindex(x)
    q.A[i, i] = 1 + 3x[i]^2
    # q is a function of the new point, not of the Newton displacement.
    q.b[i] = -2x[i]^3 - f.c[i]
  end
  q
end

function quartic_problem(::Type{T}; cap = T(Inf)) where {T}
  target = T[1.2, -1.1, 0, 0.4, -0.7, 0]
  λ = T(0.2)
  c = target .^ 3 .+ target .+ λ .* sign.(target)
  c[iszero.(target)] .= λ / 2
  QuarticLoss(c; cap), NormL1(λ), target
end

@testset "quadratic and least-squares models" begin
  for T in (Float32, Float64)
    rng = Xoshiro(22)
    n, p = 45, 12
    X = randn(rng, T, n, p)
    y = X * vcat(T[1, -1, 0.5], zeros(T, p - 3)) .+ T(0.1) .* randn(rng, T, n)
    f_ls = (one(T) / n) * LeastSquaresLoss(y, X)
    f_q = QuadraticFunction(X' * X / n, -X' * y / n, dot(y, y) / (2n))
    g = NormL1(T(0.05))
    inner_tol = T === Float32 ? 1e-6 : 1e-12
    outer_tol = T === Float32 ? 3e-5 : 1e-10
    inner = CDSolver(; order = :cyclic, tol = inner_tol, momentum = false)
    method = ProxNewton(; tol = outer_tol, inner)
    for f in (f_ls, f_q)
      reference = SparseIterate(T, p)
      ref = solve!(reference, f, g, inner)
      @test ref.converged
      for x in (zeros(T, p), SparseIterate(T, p))
        r = solve!(x, f, g, method)
        @test r.converged && r.minimizer === x
        @test r.minimum isa T
        @test Vector(x) ≈ Vector(reference) atol = (T === Float32 ? 5e-4 : 2e-7)
        @test r.minimum ≈ f(Vector(x)) + g(Vector(x)) rtol = (T === Float32 ? 2e-5 : 1e-12)
        @test l1_residual(f, x, g.λ0) <= (T === Float32 ? 2e-4 : 2e-7)
      end
    end
  end
end

@testset "default inner tolerance on an unscaled loss" begin
  rng = Xoshiro(2222)
  X = randn(rng, 45, 12)
  y = randn(rng, 45)
  f, g = LeastSquaresLoss(y, X), NormL1(0.05)
  x = zeros(12)
  r = solve!(x, f, g, ProxNewton())
  @test r.converged && r.maxchange <= r.tolerance
  @test l1_residual(f, x, g.λ0) <= 2r.tolerance
end

@testset "a custom quadratic-model oracle" begin
  for T in (Float32, Float64), sparse_iterate in (false, true)
    f, g, target = quartic_problem(T)
    p = length(target)
    x = sparse_iterate ? SparseIterate(T, p) : zeros(T, p)
    inner = CDSolver(; order = :cyclic, tol = (T === Float32 ? 1e-6 : 1e-12))
    method = ProxNewton(; maxiter = 100, tol = (T === Float32 ? 3e-5 : 1e-10), inner)
    r = solve!(x, f, g, method)
    @test r.converged && r.minimizer === x
    @test r.maxchange <= r.tolerance
    @test Vector(x) ≈ target atol = (T === Float32 ? 5e-4 : 2e-7)
    @test l1_residual(f, x, g.λ0) <= (T === Float32 ? 2e-4 : 2e-7)
    @test r.minimum ≈ f(target) + g(target) rtol = (T === Float32 ? 2e-5 : 1e-10)
    @test f.model_updates > 1
    @test f.invalid_gradients == 0
    # The fixture itself follows the new-point model convention.
    q = quadratic_model(f, Vector(x))
    @test gradient(q, Vector(x)) ≈ gradient(f, Vector(x)) atol = (T === Float32 ? 2e-6 : 1e-13)
  end
end

@testset "symmetric Kronecker models and pair multiplicities" begin
  for T in (Float32, Float64)
    C = T[-2 -1.4 0.2; -1.4 0.5 0.8; 0.2 0.8 -1.7]
    W = T[0 0.5 2; 0.5 1 1; 2 1 0]
    f = KronQuadratic(Matrix{T}(I, 3, 3), Matrix{T}(I, 3, 3), C)
    g = NormL1(T(0.3), W)
    expected = -sign.(C) .* max.(abs.(C) .- T(0.3) .* W, zero(T))
    method = ProxNewton(; maxiter = 1, tol = (T === Float32 ? 3e-5 : 1e-10),
                        inner = CDSolver(; order = :cyclic, tol = (T === Float32 ? 1e-6 : 1e-12)))
    for x in (zeros(T, 3, 3), SymmetricSparseIterate(T, 3))
      r = solve!(x, f, g, method)
      @test r.converged && r.minimizer === x
      @test r.maxchange <= r.tolerance
      @test Matrix(x) ≈ expected atol = (T === Float32 ? 2e-6 : 1e-12)
      @test r.minimum ≈ f(expected) + g(expected) rtol = (T === Float32 ? 2e-6 : 1e-12)
    end
  end
end

@testset "asymmetric penalty weights on symmetric iterates" begin
  f = KronQuadratic(Matrix{Float64}(I, 2, 2), Matrix{Float64}(I, 2, 2),
                    [0.0 -2.0; -2.0 0.0])
  weights = [0.0 2.0; 0.0 0.0]
  mean_weights = [0.0 1.0; 1.0 0.0]
  # On X12 = X21 = t, the objective is t² - 4t + 2|t|.
  expected = [0.0 1.0; 1.0 0.0]
  method = ProxNewton(; tol = 1e-10, inner = CDSolver(; order = :cyclic, tol = 1e-12))
  for w in (weights, vec(weights))
    g = NormL1(1.0, w)
    saved = copy(w)
    # a dense matrix takes asymmetric weights and solves with the means of their pairs
    x = zeros(2, 2)
    r = solve!(x, f, g, method)
    @test r.converged && r.minimizer === x
    @test Matrix(x) ≈ expected atol = 1e-12
    @test r.minimum ≈ f(expected) + g(expected) atol = 1e-12
    @test r.maxchange <= r.tolerance
    # an owner has the pair as one variable: asymmetric weights are rejected, nothing is written
    xs = SymmetricSparseIterate(2)
    xs[2, 1] = 0.25
    before = Matrix(xs)
    err = try
      solve!(xs, f, g, method)
      nothing
    catch e
      e
    end
    @test err isa ArgumentError
    @test err isa ArgumentError && occursin("must be symmetric on a SymmetricSparseIterate", sprint(showerror, err))
    @test Matrix(xs) == before
    @test isequal(w, saved)
    # the weights of the pair given as is take the same solution
    wbar = w isa Vector ? vec(mean_weights) : mean_weights
    gbar = NormL1(1.0, wbar)
    xs = SymmetricSparseIterate(2)
    r = solve!(xs, f, gbar, method)
    @test r.converged && r.minimizer === xs
    @test Matrix(xs) ≈ expected atol = 1e-12
    @test r.minimum ≈ f(expected) + gbar(expected) atol = 1e-12
    @test r.maxchange <= r.tolerance
  end
end

# The first-order decrease of a Newton step counts an off-diagonal coordinate for both of its
# entries. On X12 = X21 = t, ½‖X - B‖² + 2‖X‖₁ with B12 = B21 = 3 is t² - 6t + 4|t| up to a
# constant, minimized at t = 1. From zero the step to t = 1 has the decrease
# g(1) - g(0) + ⟨∇f(0), D⟩ = 4 - 6 = -2 for D = E12 + E21; with the gradient entry counted once it
# would be 4 - 3 = 1 > 0, and the solver would stop without taking the step.
@testset "the Newton decrease counts both entries of an off-diagonal coordinate" begin
  B = [0.0 3.0; 3.0 0.0]
  f = KronQuadratic(Matrix(1.0I, 2, 2), Matrix(1.0I, 2, 2), -B)
  g = NormL1(2.0)
  Xstar = [0.0 1.0; 1.0 0.0]
  grad = -B                                         # ∇f(0)
  trial, x0 = SymmetricSparseIterate(Xstar), SymmetricSparseIterate(2)
  @test ProximalSolvers._newton_slope(grad, trial, x0) == dot(grad, Xstar) == -6.0
  method = ProxNewton(; tol = 1e-10, inner = CDSolver(; order = :cyclic, tol = 1e-12))
  x = SymmetricSparseIterate(2)
  r = solve!(x, f, g, method)
  @test r.converged && r.minimizer === x
  @test Matrix(x) ≈ Xstar atol = 1e-12
  @test r.minimum ≈ f(Xstar) + g(Xstar) atol = 1e-12
  @test r.maxchange <= r.tolerance
end

# ProxNewton on LogDetLoss, the negative log-likelihood w (tr(SX) - log det X), with no penalty
# takes the generic path, whose quadratic model is ProximalBase's model at the matrix of the
# iterate: the minimizer, the maximum likelihood estimate S⁻¹, from an owner and from a dense start
@testset "generic ProxNewton on LogDetLoss and a SymmetricSparseIterate" begin
  rng = Xoshiro(23)
  p = 5
  A = randn(rng, 60, p)
  S = A'A / 60
  Ω = Matrix(Symmetric(inv(S)))
  method = ProxNewton(; tol = 1e-10, inner = CDSolver(; order = :cyclic, tol = 1e-12))
  x = SymmetricSparseIterate(Matrix(1.0I, p, p))
  r = solve!(x, LogDetLoss(S), ZeroFunction(), method)
  @test r.converged && r.minimizer === x
  @test Matrix(x) ≈ Ω rtol = 1e-8
  @test r.minimum ≈ LogDetLoss(S)(Ω) rtol = 1e-10
  xd = Matrix(1.0I, p, p)
  rd = solve!(xd, LogDetLoss(S), ZeroFunction(), method)
  @test rd.converged && rd.minimizer === xd
  @test xd ≈ Ω rtol = 1e-8
end

@testset "Inf trials are rejected without taking their gradient" begin
  for sparse_iterate in (false, true)
    f, g, target = quartic_problem(Float64; cap = 1.5)
    x = sparse_iterate ? SparseIterate(length(target)) : zeros(length(target))
    r = solve!(x, f, g, ProxNewton(; maxiter = 100, tol = 1e-10,
                                  inner = CDSolver(; order = :cyclic, tol = 1e-12)))
    @test r.converged
    @test f.rejected > 0
    @test f.invalid_gradients == 0
    @test all(abs.(Vector(x)) .< f.cap)
    @test Vector(x) ≈ target atol = 2e-7
    @test isfinite(r.minimum) && r.minimum < f(zeros(length(target)))
  end
end

@testset "stopping reports stationarity, not a failed or truncated step" begin
  f, g, target = quartic_problem(Float64)
  x = zeros(length(target))
  r = solve!(x, f, g, ProxNewton(; maxiter = 1, tol = 1e-10,
                                inner = CDSolver(; order = :cyclic, tol = 1e-12)))
  @test !r.converged
  @test l1_residual(f, x, g.λ0) > 1e-5

  x = zeros(length(target))
  r = solve!(x, f, g, ProxNewton(; maxiter = 3, tol = 1e-10,
                                inner = CDSolver(; maxpasses = 0)))
  @test !r.converged
  @test all(iszero, x)
  @test r.minimum ≈ f(x) + g(x)
end

# Deliberately inconsistent oracle: its minimizer is an ascent direction for
# the actual smooth function. This checks the direction safeguard.
struct UphillModelLoss <: AbstractFunction end
ProximalBase.issmooth(::Type{UphillModelLoss}) = true
ProximalBase.hashessian(::Type{UphillModelLoss}) = true
(::UphillModelLoss)(x) = sum(abs2, x) / 2 - sum(x)
ProximalBase.value_and_gradient!(out, f::UphillModelLoss, x) = (out .= x .- 1; f(x))
ProximalBase.quadratic_model(::UphillModelLoss, x) =
  QuadraticFunction(Matrix{eltype(x)}(I, length(x), length(x)), ones(eltype(x), length(x)))
ProximalBase.quadratic_model!(q::QuadraticFunction, ::UphillModelLoss, x) = q

@testset "an ascent direction is refused" begin
  for x in (zeros(3), SparseIterate(3))
    r = solve!(x, UphillModelLoss(), NormL1(0.1), ProxNewton())
    @test !r.converged
    @test all(iszero, x)
    @test r.minimum == 0
    @test r.maxchange > r.tolerance
  end
end

struct NoHessianLoss <: AbstractFunction end
ProximalBase.issmooth(::Type{NoHessianLoss}) = true
(::NoHessianLoss)(x) = sum(abs2, x) / 2
ProximalBase.value_and_gradient!(out, f::NoHessianLoss, x) = (copyto!(out, x); f(x))

# A valid quadratic oracle whose returned function is not a CD model.
struct UnsupportedModelLoss <: AbstractFunction end
ProximalBase.issmooth(::Type{UnsupportedModelLoss}) = true
ProximalBase.hashessian(::Type{UnsupportedModelLoss}) = true
(::UnsupportedModelLoss)(x) = sum(abs2, x) / 2 - sum(x)
ProximalBase.value_and_gradient!(out, f::UnsupportedModelLoss, x) = (out .= x .- 1; f(x))
ProximalBase.quadratic_model(::UnsupportedModelLoss, x) = Tilt(SqrNormL2(one(eltype(x))), -ones(eltype(x), length(x)))
ProximalBase.quadratic_model!(q, ::UnsupportedModelLoss, x) = q

@testset "oracle and model errors" begin
  for x in (zeros(3), SparseIterate(3))
    @test_throws ArgumentError solve!(copy(x), NoHessianLoss(), NormL1(0.1), ProxNewton())
    @test_throws ArgumentError solve!(copy(x), UnsupportedModelLoss(), NormL1(0.1), ProxNewton())
  end
  f, g, target = quartic_problem(Float64; cap = 1.5)
  @test_throws ArgumentError solve!(fill(1.5, length(target)), f, g, ProxNewton())
  @test_throws ArgumentError solve!(zeros(length(target)), f, NormL2(0.1), ProxNewton())
end

end
