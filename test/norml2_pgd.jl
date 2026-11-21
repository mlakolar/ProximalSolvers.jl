module NormL2PGDTests

using LinearAlgebra, ProximalBase, ProximalSolvers, Test

const PS = ProximalSolvers
const PGD = ProximalGradientDescent
const APG = AccProxGradDescent

# Evaluate the objective and stationarity from the stored data, independently of
# the package's objective, gradient, and proximal oracles.
function reference(X, y, s, λ, x)
  setprecision(BigFloat, 256) do
    A, b, z, scale, level = BigFloat.(X), BigFloat.(y), BigFloat.(x), BigFloat(s), BigFloat(λ)
    d = A * z - b
    grad = scale * (A' * d)
    nz = norm(z)
    kkt = iszero(nz) ? max(norm(grad) - level, 0) : norm(grad + (level / nz) * z)
    (; objective = scale * dot(d, d) / 2 + level * nz,
       kkt, stop_scale = max(level, norm(scale * (A' * b))))
  end
end

function check_solution(x, result, expected, X, y, s, λ)
  T = eltype(x)
  tolerance = T === Float32 ? 2e-4 : 2e-8
  actual = reference(X, y, s, λ, x)
  optimum = reference(X, y, s, λ, expected)
  @test result.minimizer === x
  @test norm(x - expected) <= tolerance * max(1, norm(expected))
  @test actual.objective ≈ optimum.objective atol=tolerance^2 * max(1, optimum.objective)
  @test result.minimum ≈ actual.objective rtol=32eps(T) atol=32eps(T)
  @test actual.kkt <= tolerance * actual.stop_scale
  if result.converged
    # Account for rounding in the solver's working-precision gradient and score.
    @test actual.kkt <= (1e-10 + 96eps(T)) * actual.stop_scale
  end
end

@testset "NormL2 minimizers ($T, $method)" for T in (Float32, Float64), method in (PGD(), APG())
  opts = ProximalOptions(; maxiter=2000, allow_f_increases=true, gradtol=1e-10)
  X = Matrix{T}(I, 2, 2)
  y = T[3, 4]
  f = LeastSquaresLoss(y, X)
  for (s, loss) in ((one(T), f), (T(0.5), T(0.5) * f)), λ in T[0, 0.5, 4.5, 6]
    # With X = I, the solution is y times the analytic shrinkage factor.
    expected = setprecision(BigFloat, 256) do
      max(0, 1 - BigFloat(λ) / (5 * BigFloat(s))) * BigFloat.(y)
    end
    x = T[-1, 0.5]
    result = solve!(x, loss, NormL2(λ), method, opts)
    check_solution(x, result, expected, X, y, s, λ)
    if λ > 5s
      @test iszero(x)
      @test result.converged
    end
  end

  # For x* = [3, 4], choose y so that s X'(X*x* - y) = -(λ/5)x*.
  # Full column rank then makes x* the unique optimum.
  X = T[1 1; 0 1]
  y = T[7.75, 4.25]
  s, λ = T(0.5), T(0.625)
  loss = s * LeastSquaresLoss(y, X)
  expected = T[3, 4]
  @test iszero(reference(X, y, s, λ, expected).kkt)
  x = zeros(T, 2)
  result = solve!(x, loss, NormL2(λ), method, opts)
  check_solution(x, result, expected, X, y, s, λ)
  group_x = zeros(T, 2)
  group_result = solve!(group_x, loss, GroupNormL2(λ, [1:2], [one(T)]), method, opts)
  check_solution(group_x, group_result, expected, X, y, s, λ)
end

@testset "NormL2 stopping scale and counters ($T, $method)" for T in (Float32, Float64), method in (PGD(), APG())
  f = LeastSquaresLoss(T[3, 4], Matrix{T}(I, 2, 2))
  opts = ProximalOptions(; gradtol=0.052)
  g = NormL2(T(4.75))
  state = PS.initial_state(method, opts, f, g, zeros(T, 2))
  @test state.λmax < 0
  prox_calls, grad_calls = state.prox_calls, state.grad_calls
  # Residual 0.25 passes against 0.052 * 5, but fails if the scale is 4.75.
  @test PS._stationary!(state, f, g, opts)
  @test state.λmax == T(5)
  @test state.prox_calls == prox_calls
  @test state.grad_calls == grad_calls + (method isa APG)
  @test !PS._stationary!(state, f, NormL2(T(4.5)), opts)

  result = solve!(zeros(T, 2), f, NormL2(T(6)), method)
  @test result.converged
  if method isa APG
    @test result.prox_calls == result.backtrack_steps
  end
end

@testset "APG scores the accepted point" begin
  X, y = Matrix{Float64}(I, 2, 2), [3.0, 4.0]
  f, g = LeastSquaresLoss(y, X), NormL2(1.0)
  method, opts = APG(; α=1.0), ProximalOptions(; gradtol=0.6)
  state = PS.initial_state(method, opts, f, g, zeros(2))
  state.L = 2.0
  PS.update_state!(f, g, state, method)
  @test state.x ≈ [1.2, 1.6]
  # The accepted-point score is 2. The extrapolated gradient gives 4.
  @test reference(X, y, 1, 1, state.x).kkt ≈ 2
  @test PS._stationary!(state, f, g, opts)
end

@testset "NormL2 with APG certified backtracking ($T)" for T in (Float32, Float64)
  X, y = T[1 1; 0 1], T[3, 4]
  f, g, method = LeastSquaresLoss(y, X), NormL2(T(0.5)), APG(; α=1.0)
  state = PS.initial_state(method, ProximalOptions(), f, g, zeros(T, 2))
  state.L = T(0.125)
  PS.update_state!(f, g, state, method)
  @test state.backtrack_steps > 1
  setprecision(BigFloat, 256) do
    d = BigFloat.(state.x) - BigFloat.(state.y)
    @test !iszero(d)
    @test norm(BigFloat.(X) * d) <= (1 + 4eps(T)) * sqrt(BigFloat(state.L)) * norm(d)
  end
end

function refused(x, f, g, method)
  before = copy(x)
  @test_throws ArgumentError solve!(x, f, g, method)
  @test isequal(x, before)
end

@testset "NormL2 conversion and refusals ($method)" for method in (PGD(), APG())
  X, y = Float32[1 1; 0 1], Float32[3, 4]
  f = LeastSquaresLoss(y, X)
  x, native = zeros(Float32, 2), zeros(Float32, 2)
  g = NormL2(0.1)
  a = solve!(x, f, g, method)
  b = solve!(native, f, NormL2(0.1f0), method)
  @test isequal(x, native)
  @test isequal(a.minimum, b.minimum)
  @test g.λ === 0.1
  @test isnothing(PS._check_problem(copy(x), f, NormL2(1e-40)))
  for invalid in (Inf, 1e40, 1e-60)
    refused(x, f, NormL2(invalid), method)
  end
  refused(x, f, Scaled(g, 2), method)
  refused(zeros(Float32, 2, 1), LeastSquaresLoss(reshape(y, 2, 1), X), g, method)
  refused(x, SqrtLeastSquaresLoss(y, X), g, method)
  refused([0.3, -0.2], LogisticLoss([0.0, 1.0], Float64.(X)), g, method)
  refused(x, f, g, CDSolver())
end

@testset "NormL2 rollback ($T, $method)" for T in (Float32, Float64), method in (PGD(), APG())
  # The loss is finite and independent of x[2]. The penalty overflows even
  # after the first proximal shrinkage, so the trial cannot be returned.
  X, y = T[2 0], T[2]
  start = T === Float32 ? T[1, 1f20] : T[1, 1e200]
  λ = T === Float32 ? T(1f19) : T(1e110)
  f, g = LeastSquaresLoss(y, X), NormL2(λ)
  @test isfinite(f(start)) && !isfinite(g(start))
  x = copy(start)
  @test_throws ErrorException solve!(x, f, g, method)
  @test isequal(x, start)
end

end
