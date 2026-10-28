module MixedPrecisionExtendedTests

using Test
using Random
using LinearAlgebra
using SparseArrays
using ProximalBase
using ProximalSolvers

const PS = ProximalSolvers

_check_point(x::AbstractArray) = @test eltype(x) == Float32
_check_point(x::Tuple) = foreach(_check_point, x)

function _check_minimum(r, f, g)
  _check_point(r.minimizer)
  @test r.converged
  value = Float32(f(r.minimizer) + g(r.minimizer))
  @test r.minimum ≈ value rtol = 0 atol = 8eps(value)
end

function _check_result(r::PS.OptimizationResults, f, g)
  @test r.minimum isa Float32
  @test r.x_residual isa Float64
  @test r.f_residual isa Float64
  @test r.g_residual isa Float64
  _check_minimum(r, f, g)
end

function _check_result(r::SLOPEResults, f, g)
  _check_point(r.minimizer)
  @test r.converged
  @test r.kkt_residual isa Float32
  @test eltype(r.gradient) == Float32
end

function _check_objective(r, f, g, reference)
  x = r.minimizer isa Tuple ? map(x -> Float64.(x), r.minimizer) : Float64.(r.minimizer)
  @test f(x) + g(x) ≈ reference rtol = 1e-4 atol = 1e-6
end

rng = Xoshiro(129)
n, p = 40, 10
X = randn(rng, Float32, n, p)
y = X * Float32[3, -2, 1.5, 0, 0, 0, 0, 0, 0, 0] + 0.05f0 * randn(rng, Float32, n)
X64, y64 = Float64.(X), Float64.(y)
A, b = X'X / n, -X'y / n
A64, b64 = X64'X64 / n, -X64'y64 / n
options = ProximalOptions(; maxiter = 2000, ftol = 1e-7, xtol = 1e-6, gradtol = 1e-5,
                           allow_f_increases = true)
reference_options = ProximalOptions(; maxiter = 2000, ftol = 1e-13, xtol = 1e-13, gradtol = 1e-10)

@testset "debiasing refits a stable support" begin
  method = ProximalGradientDescent(; debias = 2)
  g = IndBallL0(3)
  f64 = (1 / n) * LeastSquaresLoss(y64, X64)
  reference = solve!(zeros(p), f64, g, method, reference_options)
  @test reference.converged
  value = f64(reference.minimizer) + g(reference.minimizer)
  for scale in (1 / n, 1f0 / n)
    f = scale * LeastSquaresLoss(y, X)
    ws = SolverWorkspace(zeros(Float32, p), f, g, method, options)
    result = solve!(ws)
    _check_result(result, f, g)
    _check_objective(result, f64, g, value)
    @test ws.buffers.state.refitted
    @test ws.buffers.state.stable >= method.debias
    support = findall(!iszero, result.minimizer)
    @test support == [1, 2, 3]
    @test result.minimizer[support] ≈ X[:, support] \ y rtol = 2e-5 atol = 1e-6
  end
end

@testset "SLOPE keeps dense and sparse certificates in Float32" begin
  lambda = collect(range(0.03f0, 0.01f0; length = p))
  g, g64 = SLOPE(lambda), SLOPE(Float64.(lambda))
  f64 = (1 / n) * LeastSquaresLoss(y64, X64)
  reference = solve!(zeros(p), f64, g64, SLOPEAPG(; maxiter = 2000, tol = 1e-9))
  @test reference.converged
  value = f64(reference.minimizer) + g64(reference.minimizer)
  for design in (X, sparse(X)), scale in (1 / n, 1f0 / n),
      method in (SLOPEAPG(; maxiter = 2000, tol = 1e-4), SLOPEHybrid(; maxiter = 2000, tol = 1e-4))
    f = scale * LeastSquaresLoss(y, design)
    result = solve!(zeros(Float32, p), f, g, method)
    _check_result(result, f, g)
    _check_objective(result, f64, g64, value)
    grad = zeros(Float32, p)
    value_and_gradient!(grad, f, result.minimizer)
    @test result.gradient ≈ grad rtol = 1e-5 atol = 1e-6
    trial = prox(g, result.minimizer - grad, 1f0)
    @test result.kkt_residual ≈ norm(result.minimizer - trial, Inf) atol = 2e-6
  end
end

@testset "a workspace resets promoted loss and penalty values" begin
  method = AccProxGradDescent()
  for scale in (1 / n, 1f0 / n)
    f = scale * LeastSquaresLoss(y, X)
    f64 = (1 / n) * LeastSquaresLoss(y64, X64)
    g = 2.0 * NormL1(0.005f0)
    ws = SolverWorkspace(zeros(Float32, p), f, g, method, options)
    state = ws.buffers.state
    for parameter in (0.005f0, 0.0025f0)
      penalty = 2.0 * NormL1(parameter)
      g64 = 2.0 * NormL1(Float64(parameter))
      reference = solve!(zeros(p), f64, g64, method, reference_options)
      @test reference.converged
      result = solve!(ws, penalty)
      _check_result(result, f, penalty)
      _check_objective(result, f64, g64, f64(reference.minimizer) + g64(reference.minimizer))
      @test ws.buffers.state === state
    end
    reinit!(ws, zeros(Float32, p))
    result = solve!(ws)
    _check_result(result, f, g)
    g64 = 2.0 * NormL1(Float64(0.005f0))
    reference = solve!(zeros(p), f64, g64, method, reference_options)
    @test reference.converged
    _check_objective(result, f64, g64, f64(reference.minimizer) + g64(reference.minimizer))
  end
end

@testset "tuple iterates use the block element type" begin
  method = AccProxGradDescent()
  g = SeparableSum(2.0 * NormL1(0.005f0))
  f64 = SeparableSum(0.5 * QuadraticFunction(A64, b64))
  g64 = SeparableSum(2.0 * NormL1(Float64(0.005f0)))
  reference = solve!((zeros(p),), f64, g64, method, reference_options)
  @test reference.converged
  value = f64(reference.minimizer) + g64(reference.minimizer)
  for scale in (0.5, 0.5f0)
    f = SeparableSum(scale * QuadraticFunction(A, b))
    result = solve!((zeros(Float32, p),), f, g, method, options)
    _check_result(result, f, g)
    _check_objective(result, f64, g64, value)
  end
end

end
