module ImageModelsTest

using Test
using Random
using LinearAlgebra
using ProximalBase
using ProximalSolvers

const PS = ProximalSolvers

# a matrix that counts the products with it and with its transpose
mutable struct CountingMatrix{T} <: AbstractMatrix{T}
  A::Matrix{T}
  n::Int
  nt::Int
end
CountingMatrix(A::Matrix) = CountingMatrix(A, 0, 0)
Base.size(M::CountingMatrix) = size(M.A)
Base.getindex(M::CountingMatrix, i::Int, j::Int) = M.A[i, j]
function LinearAlgebra.mul!(y::StridedVecOrMat, M::CountingMatrix, x::StridedVecOrMat)
  M.n += 1
  mul!(y, M.A, x)
end
function LinearAlgebra.mul!(y::StridedVecOrMat, Mt::Transpose{<:Any, <:CountingMatrix}, x::StridedVecOrMat)
  M = parent(Mt)
  M.nt += 1
  mul!(y, transpose(M.A), x)
end

function data(rng = Xoshiro(1); n = 80, p = 40)
  X = randn(rng, n, p)
  β = vcat(randn(rng, 5), zeros(p - 5))
  X, X * β + 0.1 * randn(rng, n)
end

# the same function without a model: Tilt adds ⟨0, x⟩ + 0 to the value and 0 to
# the gradient, which changes neither, and hides the structure of f
opaque(f, x) = Tilt(f, zero(x))

# Steps both states for `iterations` iterations, and returns the largest
# relative difference of the iterates over the first `early` of them, up to the
# first iteration where the two runs take a different number of trial steps.
# The value and the gradient at the extrapolated point of AccProxGradDescent come
# from an image that differs from a product by rounding. The values of
# ProximalGradientDescent are computed as the loss computes them, the same to the
# bit in an optimized build; with bounds checks or coverage (as in Pkg.test and
# CI) the loss's own loop can sum in another order. A comparison of values in
# the line search (a retried step, a restart) can then go the other way, after
# which the runs follow other paths to the same minimizer, so only the iterates
# before it are compared, and the objective values at the end.
function compare_steps!(method, f, g, x0, iterations; early = 10)
  s1 = PS.initial_state(method, ProximalOptions(), f, g, copy(x0))
  s2 = PS.initial_state(method, ProximalOptions(), opaque(f, x0), g, copy(x0))
  d = 0.0
  same = true
  for k in 1:iterations
    PS.update_state!(f, g, s1, method)
    PS.update_state!(opaque(f, x0), g, s2, method)
    same &= (s1.grad_calls, s1.prox_calls) == (s2.grad_calls, s2.prox_calls)
    if same && k <= early
      d = max(d, norm(s1.x - s2.x) / max(norm(s2.x), 1))
    end
  end
  d, s1, s2, same
end

# the objective values agree at the end when the runs took the same steps; runs
# that parted are compared at convergence in "solutions" below
same_objective(s1, s2, same) = !same || isapprox(s1.f_x + s1.g_x, s2.f_x + s2.g_x; rtol = 1e-10)

solvers = (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())

@testset "products per iteration $(summary(method))" for method in solvers
  X, y = data()
  n = size(X, 1)
  C = CountingMatrix(X)
  f = (1 / n) * LeastSquaresLoss(y, C)
  g = NormL1(0.05)
  state = PS.initial_state(method, ProximalOptions(), f, g, zeros(size(X, 2)))
  @test state.model !== nothing
  @test (C.n, C.nt) == (1, method isa ProximalGradientDescent ? 1 : 0)
  two = 0
  for k in 1:100
    n0, nt0 = C.n, C.nt
    p0, g0 = state.prox_calls, state.grad_calls
    PS.update_state!(f, g, state, method)
    # one product with A per trial point and one with Aᵀ per gradient: no
    # product to evaluate f at the extrapolated point or after a step
    @test C.n - n0 == state.prox_calls - p0
    @test C.nt - nt0 == state.grad_calls - g0
    two += (C.n - n0) + (C.nt - nt0) == 2
  end
  # iterations without a retried step take two products
  @test two > 0
end

@testset "the iterates agree with those without a model $(summary(method))" for method in solvers
  X, y = data(Xoshiro(2))
  n, p = size(X)
  λ = 0.1 * norm(X'y / n, Inf)
  # least squares, scaled least squares, logistic and Poisson losses with weights and an offset
  w = rand(Xoshiro(3), n) .+ 0.5
  o = 0.1 * randn(Xoshiro(4), n)
  yb = Float64.(rand(Xoshiro(5), n) .< 0.5)
  yc = Float64.(rand(Xoshiro(6), 0:3, n))
  for f in (LeastSquaresLoss(y, X), (1 / n) * LeastSquaresLoss(y, X),
            (1 / n) * LogisticLoss(yb, X), (1 / n) * LogisticLoss(yb, X; weights = w, offset = o),
            (1 / n) * PoissonLoss(yc, X / 4; offset = o))
    d, s1, s2, same = compare_steps!(method, f, NormL1(λ), zeros(p), 200)
    @test s1.model !== nothing && s2.model === nothing
    @test d < 1e-12
    @test same_objective(s1, s2, same)
  end
end

@testset "solutions $(summary(method))" for method in (solvers..., ActiveAccProxGradDescent())
  X, y = data(Xoshiro(7))
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  g = NormL1(0.1 * norm(X'y / n, Inf))
  opt = ProximalOptions(; ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12, maxiter = 10_000)
  x1, x2 = zeros(p), zeros(p)
  solve!(x1, f, g, method, opt)
  solve!(x2, opaque(f, zeros(p)), g, method, opt)
  # Objective stopping at ftol does not imply an O(ftol) coefficient error.
  # Certify both solutions with the lasso dual and compare objective values;
  # rounding can send the two line searches along different converged paths.
  λ = 0.1 * norm(X'y / n, Inf)
  function relative_gap(x)
    residual = y - X*x
    dual = residual / n
    dual .*= min(1.0, λ / max(norm(X'dual, Inf), eps(Float64)))
    primal = dot(residual, residual) / (2n) + λ*norm(x, 1)
    bound = dot(y, dual) - n*dot(dual, dual)/2
    max(primal - bound, 0.0) / max(abs(primal), 1.0)
  end
  @test f(x1) + g(x1) ≈ f(x2) + g(x2) rtol = 1e-12
  # The dual gap is first-order in coefficient error, while the objective
  # stopping test is second-order near this strongly convex minimizer.
  @test relative_gap(x1) <= sqrt(opt.ftol)
  @test relative_gap(x2) <= sqrt(opt.ftol)
end

@testset "SparseIterate, Float32 and several responses $(summary(method))" for method in solvers
  X, y = data(Xoshiro(8))
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  g = NormL1(0.1 * norm(X'y / n, Inf))
  d, s1, s2, same = compare_steps!(method, f, g, SparseIterate(p), 100)
  @test d < 1e-12
  @test same_objective(s1, s2, same)

  f32 = (1f0 / n) * LeastSquaresLoss(Float32.(y), Float32.(X))
  d, s1, _, _ = compare_steps!(method, f32, NormL1(0.05f0), zeros(Float32, p), 40)
  @test d < 1e-5
  @test eltype(s1.z_x) == Float32

  Y = X * randn(Xoshiro(9), p, 3) + 0.1 * randn(Xoshiro(10), n, 3)
  fY = (1 / n) * LeastSquaresLoss(Y, X)
  d, s1, s2, same = compare_steps!(method, fY, NuclearNorm(0.5), zeros(p, 3), 100)
  @test d < 1e-12
  @test same_objective(s1, s2, same)
  @test size(s1.z_x) == (n, 3)
end

@testset "no allocations per iteration $(summary(method))" for method in solvers
  X, y = data(Xoshiro(11))
  n, p = size(X)
  g = NormL1(0.05)
  function bytes(f, g, method, x0)
    state = PS.initial_state(method, ProximalOptions(), f, g, x0)
    for _ in 1:5
      PS.update_state!(f, g, state, method)
    end
    @allocated PS.update_state!(f, g, state, method)
  end
  @test bytes((1 / n) * LeastSquaresLoss(y, X), g, method, zeros(p)) == 0
  yb = Float64.(rand(Xoshiro(12), n) .< 0.5)
  @test bytes((1 / n) * LogisticLoss(yb, X), g, method, zeros(p)) == 0
end

@testset "monotone images follow both candidates and the accepted point" begin
  for T in (Float32, Float64), δ in (1e-3, 1e3)
    X, y = data(Xoshiro(14))
    X, y = T.(X), T.(y)
    n, p = size(X)
    C = CountingMatrix(X)
    f, g = (one(T) / n) * LeastSquaresLoss(y, C), NormL1(T(0.05))
    method = MonotoneAccProxGradDescent(; δ)
    state = PS.initial_state(method, ProximalOptions(), f, g, zeros(T, p))
    previous = state.f_x + state.g_x
    for k in 1:60
      PS.update_state!(f, g, state, method)
      @test state.z_x ≈ X * state.x rtol = 100eps(T) atol = 100eps(T)
      @test state.z_previous ≈ X * state.x_previous rtol = 100eps(T) atol = 100eps(T)
      @test state.z_y ≈ X * state.y rtol = 100eps(T) atol = 100eps(T)
      @test state.z_z ≈ X * state.z rtol = 100eps(T) atol = 100eps(T)
      @test state.f_x ≈ f(state.x) rtol = 100eps(T) atol = 100eps(T)
      objective = state.f_x + state.g_x
      @test objective <= previous + 100eps(T) * max(one(T), abs(previous))
      previous = objective
    end
    # A stricter sufficient-decrease test makes the plain branch run too.
    δ == 1e3 && @test state.grad_calls > 60
    @test state.prox_calls == state.backtrack_steps
  end
end

@testset "monotone cache reset reuses the images" begin
  X, y = data(Xoshiro(15))
  n, p = size(X)
  f, g = (1 / n) * LeastSquaresLoss(y, X), NormL1(0.05)
  method = MonotoneAccProxGradDescent()
  state = PS.initial_state(method, ProximalOptions(), f, g, zeros(p))
  for _ in 1:8
    PS.update_state!(f, g, state, method)
  end
  buffers = (state.z_x, state.z_previous, state.z_y, state.z_z, state.z_v, state.dz)
  # Buffer swaps are permitted; restarting does not allocate new image arrays.
  fill!(state.x, 0.0)
  PS.reinitialize_state!(state, f, g, method)
  @test all(image -> any(buffer -> image === buffer, buffers),
            (state.z_x, state.z_previous, state.z_y, state.z_z, state.z_v, state.dz))
  @test (state.f_calls, state.grad_calls, state.prox_calls, state.accelerated) == (1, 0, 0, 0)
  fresh = PS.initial_state(method, ProximalOptions(), f, g, zeros(p))
  for _ in 1:5
    PS.update_state!(f, g, state, method)
    PS.update_state!(f, g, fresh, method)
    @test state.x == fresh.x
    @test state.z_x == fresh.z_x
    @test state.f_x == fresh.f_x
  end
end

end
