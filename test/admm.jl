module ADMMTests

using LinearAlgebra: norm
using ProximalBase: LeastSquaresLoss, NormL1, SqrNormL2
import ProximalSolvers
using ProximalSolvers: ADMMResults, ADMMSolver, ProximalOptions, solve!
using SparseArrays: sparsevec
using Test

# These references use the stored data directly, independently of the PB oracles
# and the ADMM implementation.
soft_threshold(x, level) = sign(x) * max(abs(x) - level, 0)

function raw_objective(z, center, curvature, penalty)
  zb, cb = BigFloat.(z), BigFloat.(center)
  BigFloat(curvature) * sum(abs2, zb - cb) / 2 + BigFloat(penalty) * sum(abs, zb)
end

function raw_stationarity(z, center, curvature, penalty)
  gradient = BigFloat(curvature) .* (BigFloat.(z) - BigFloat.(center))
  level = BigFloat(penalty)
  maximum(eachindex(z)) do j
    iszero(z[j]) ? max(abs(gradient[j]) - level, 0) : abs(gradient[j] + level * sign(z[j]))
  end
end

function reference_step(previous, dual, center, curvature, penalty, rho, alpha)
  zb, ub, cb = BigFloat.(previous), BigFloat.(dual), BigFloat.(center)
  λ, τ, ρ, α = BigFloat.((curvature, penalty, rho, alpha))
  xb = (ρ .* (zb - ub) + λ .* cb) ./ (ρ + λ)
  relaxed = α .* xb + (1 - α) .* zb
  next = soft_threshold.(relaxed + ub, τ / ρ)
  next_dual = ub + relaxed - next
  (; x = xb, z = next, u = next_dual,
     r_norm = norm(xb - next), s_norm = ρ * norm(next - zb))
end

function check_accurate(result, center, curvature, penalty, accuracy)
  z = result.minimizer
  reference = soft_threshold.(BigFloat.(center), BigFloat(penalty) / BigFloat(curvature))
  @test norm(BigFloat.(z) - reference, Inf) <= accuracy
  @test raw_stationarity(z, center, curvature, penalty) <= accuracy
  objective = raw_objective(z, center, curvature, penalty)
  @test objective - raw_objective(reference, center, curvature, penalty) <= accuracy^2
  @test isapprox(result.minimum, objective; rtol = 32eps(eltype(z)), atol = 32eps(eltype(z)))
end

@testset "Fixed-penalty ADMM against the centered lasso solution" begin
  for T in (Float32, Float64)
    @testset "$T" begin
      center = T[2, -3/2, 1/2, -1/4, 3/4, 0]
      original_center = copy(center)
      curvature = T(3/2)
      tol = T === Float32 ? T(3e-6) : T(1e-11)
      accuracy = T === Float32 ? 3e-5 : 1e-9
      for penalty in (zero(T), T(3/4)), rho in (T(1/2), T(4)), alpha in (T(3/4), one(T), T(3/2)),
          start in (zeros(T, length(center)), T[1, -2, 3, -4, 5, -6])
        z = copy(start)
        method = ADMMSolver(; ρ = rho, α = alpha, abstol = tol, reltol = 0)
        result = solve!(z, SqrNormL2(curvature, center), NormL1(penalty), method, ProximalOptions(maxiter = 500))
        @test result isa ADMMResults
        @test result.minimizer === z
        @test z != start
        @test result.u isa Vector{T} && !Base.mightalias(result.u, z)
        @test result.minimum isa T
        @test result.ρ === rho
        @test result.converged && result.status === :converged
        @test 0 < result.iterations <= 500
        @test result.prox_calls == 2 * result.iterations
        @test 0 <= result.r_norm <= result.eps_pri
        @test 0 <= result.s_norm <= result.eps_dual
        check_accurate(result, center, curvature, penalty, accuracy)
      end
      @test center == original_center
    end
  end
end

@testset "Residuals and tolerances of a completed step" begin
  for T in (Float32, Float64), alpha in (one(T), T(3/2))
    start = T[1/4, 1/2]
    center = T[2, -7/4]
    z = copy(start)
    rho, curvature, penalty = T(2), one(T), T(1/4)
    abstol, abstol_dual, reltol = T.((1/32, 1/64, 1/16))
    method = ADMMSolver(; ρ = rho, α = alpha, abstol, abstol_dual, reltol)
    result = solve!(z, SqrNormL2(curvature, center), NormL1(penalty), method,
                    ProximalOptions(prox_calls_limit = 3))
    oracle = reference_step(start, zeros(T, 2), center, curvature, penalty, rho, alpha)
    comparison_rtol = 16eps(T)
    @test z ≈ oracle.z rtol = comparison_rtol
    @test result.u ≈ oracle.u rtol = comparison_rtol
    @test result.r_norm ≈ oracle.r_norm rtol = comparison_rtol
    @test result.s_norm ≈ oracle.s_norm rtol = comparison_rtol
    @test result.eps_pri ≈ sqrt(big(2.0)) * abstol + reltol * max(norm(oracle.x), norm(oracle.z)) rtol = comparison_rtol
    @test result.eps_dual ≈ sqrt(big(2.0)) * abstol_dual + reltol * rho * norm(oracle.u) rtol = comparison_rtol
    @test result.minimum ≈ raw_objective(z, center, curvature, penalty) rtol = comparison_rtol
    @test !result.converged && result.status === :prox_calls_limit
    @test result.iterations == 1 && result.prox_calls == 2
  end
end

@testset "Representable relaxation close to zero" begin
  for T in (Float32, Float64)
    z = T[0]
    α = eps(T) / 8
    method = ADMMSolver(; α, abstol = 0, reltol = 0)
    options = ProximalOptions(prox_calls_limit = 2)
    result = solve!(z, SqrNormL2(1, T[2]), NormL1(0), method, options)
    @test z == T[α] && result.u == T[0]
    @test result.r_norm == one(T) - α && result.s_norm == α
    @test result.status === :prox_calls_limit && !result.converged

    z = T[1]
    center = T[T(2)^(T === Float32 ? 30 : 60)]
    α = T(2)^(-100)
    method = ADMMSolver(; α, abstol = 0, reltol = 0)
    expected_z = T.(reference_step(z, T[0], center, 1, 0, 1, α).z)
    result = solve!(z, SqrNormL2(1, center), NormL1(0), method, options)
    @test z == expected_z && result.s_norm == abs(only(expected_z) - one(T)) < result.r_norm
    @test result.status === :prox_calls_limit && !result.converged
  end
end

@testset "Limits, zero tolerances and stagnation" begin
  for T in (Float32, Float64)
    start, center = T[3, -3], T[1, -1]
    f, g = SqrNormL2(1, center), NormL1(0)
    method = ADMMSolver(; abstol = 0, reltol = 0)
    for (opts, status) in ((ProximalOptions(prox_calls_limit = 1), :prox_calls_limit),
                           (ProximalOptions(time_limit = 0), :time_limit),
                           (ProximalOptions(time_limit = -1), :time_limit))
      z = copy(start)
      result = solve!(z, f, g, method, opts)
      @test result.minimizer === z && z == start
      @test iszero(norm(result.u))
      @test !result.converged && result.status === status
      @test result.iterations == 0 && result.prox_calls == 0
      @test all(isnan, (result.r_norm, result.s_norm, result.eps_pri, result.eps_dual))
      @test result.minimum == raw_objective(start, center, 1, 0)
    end

    z = copy(start)
    result = solve!(z, f, g, method, ProximalOptions(maxiter = 2))
    @test !result.converged && result.status === :iteration_limit
    @test result.iterations == 2 && result.prox_calls == 4
    @test z == T[3/2, -3/2]
    @test result.r_norm == result.eps_pri == result.eps_dual == 0
    @test result.s_norm > 0
    @test ProximalSolvers.iteration_limit_reached(result)

    # An exact fixed point can pass a zero tolerance, even with a subnormal reciprocal.
    result = solve!(copy(center), f, g, ADMMSolver(; ρ = floatmax(T), abstol = 0, reltol = 0))
    @test result.converged && result.status === :converged
    @test result.iterations == 1 && result.prox_calls == 2
    @test result.r_norm == result.s_norm == result.minimum == 0

    # At this penalty the two prox updates can round back to the initial point.
    z = T[2]
    center = T[1]
    result = solve!(z, SqrNormL2(1, center), g, ADMMSolver(; ρ = T(2)^100))
    @test z == T[2]
    @test result.r_norm == result.s_norm == 0
    @test raw_stationarity(z, center, 1, 0) == 1
    @test !result.converged && result.status === :stagnated
    @test result.iterations == 1 && result.prox_calls == 2
  end
end

@testset "Warm starts, borrowed dual storage and stopping precedence" begin
  for T in (Float32, Float64)
    center = T[2, -3/2, 1/4, -3/4]
    original_center = copy(center)
    curvature, penalty = T(2), T(3/4)
    f, g = SqrNormL2(curvature, center), NormL1(penalty)
    tol = T === Float32 ? T(3e-7) : T(1e-12)
    accuracy = T === Float32 ? 2e-5 : 1e-9
    setup = (; α = T(5/4), abstol = tol, reltol = tol)
    first = solve!(zeros(T, length(center)), f, g, ADMMSolver(; ρ = 64, adaptive = true, setup...),
                   ProximalOptions(maxiter = 3))
    @test first.status === :iteration_limit && first.ρ < 64 && !first.converged
    z, u = copy(first.minimizer), copy(first.u)
    initial_z, initial_u = copy(z), copy(u)
    partial = solve!(z, f, g, ADMMSolver(; ρ = first.ρ, setup...), ProximalOptions(time_limit = 0); u)
    @test partial.minimizer === z && partial.u === u
    @test z == initial_z && u == initial_u && partial.status === :time_limit
    warm = solve!(z, f, g, ADMMSolver(; ρ = first.ρ, setup...), ProximalOptions(maxiter = 500); u)
    fresh = solve!(zeros(T, length(center)), f, g, ADMMSolver(; ρ = curvature, setup...))
    @test warm.converged && fresh.converged
    @test warm.minimizer === z && warm.u === u
    @test z != initial_z && u != initial_u
    @test first.minimizer == initial_z && first.u == initial_u && center == original_center
    @test norm(warm.minimizer - fresh.minimizer, Inf) <= 2accuracy
    check_accurate(warm, center, curvature, penalty, accuracy)
    check_accurate(fresh, center, curvature, penalty, accuracy)

    # The nonzero explicit u gives z = 2 on the first step and an exact
    # fixed point on the second, where both limits also become binding.
    z, u = T[3/2], T[1/2]
    method = ADMMSolver(; abstol = 0, reltol = 0)
    exact = solve!(z, SqrNormL2(1, T[2]), NormL1(0), method,
                   ProximalOptions(maxiter = 2, prox_calls_limit = 4); u)
    @test exact.converged && exact.status === :converged
    @test exact.iterations == 2 && exact.prox_calls == 4
    @test exact.minimizer === z && z == T[2]
    @test exact.u === u && u == T[0]
    @test exact.r_norm == exact.s_norm == 0
    @test ProximalSolvers.f_calls(exact) == 1 && ProximalSolvers.grad_calls(exact) == 0
    @test ProximalSolvers.prox_calls(exact) == 4
    @test !ProximalSolvers.iteration_limit_reached(exact) && !ProximalSolvers.call_limit_reached(exact)
  end
end

@testset "Adaptive balancing agrees with independently replayed steps" begin
  for T in (Float32, Float64)
    center = T[2]
    δ = nextfloat(zero(T))
    # With zero tolerances, a positive residual scores Inf, a zero residual scores
    # zero, and two infinite scores tie. The tiny positive tolerances exercise
    # balancing when computing each normalized residual directly would overflow.
    for (penalty, abstol, abstol_dual, rho_next) in ((4, 0, 0, 2), (0, 0, 0, 1/2),
        (1/4, 0, 0, 1), (1/4, δ, 128δ, 2), (1/4, 128δ, δ, 1/2))
      z = T[0]
      g = NormL1(T(penalty))
      method = ADMMSolver(; adaptive = true, ρ = one(T), abstol = T(abstol),
                          abstol_dual = T(abstol_dual), reltol = 0)
      first = reference_step(z, T[0], center, 1, penalty, 1, 1)
      oracle = reference_step(first.z, first.u / rho_next, center, 1, penalty, rho_next, 1)
      result = solve!(z, SqrNormL2(1, center), g, method, ProximalOptions(maxiter = 2))
      comparison_rtol = 16eps(T)
      @test result.ρ === T(rho_next)
      @test z ≈ oracle.z rtol = comparison_rtol
      @test result.u ≈ oracle.u rtol = comparison_rtol
      @test result.r_norm ≈ oracle.r_norm atol = comparison_rtol
      @test result.s_norm ≈ oracle.s_norm rtol = comparison_rtol
      @test result.eps_pri === T(abstol) && result.eps_dual === T(abstol_dual)
      @test !result.converged && result.status === :iteration_limit
      @test result.iterations == 2 && result.prox_calls == 4
    end

    # Keep a nonzero primal residual and an identically zero dual residual.
    # After 60 iterations an uncapped policy would have made 59 doublings.
    center = T[1]
    f, g = SqrNormL2(T(2)^80, center), NormL1(T(2)^81)
    method = ADMMSolver(; adaptive = true, abstol = 0, reltol = 0)
    limited = solve!(T[0], f, g, method, ProximalOptions(maxiter = 60))
    @test limited.ρ === T(2)^50
    @test limited.minimizer == T[0] && limited.r_norm > 0 && limited.s_norm == 0
    @test limited.status === :iteration_limit && !limited.converged
    @test limited.iterations == 60 && limited.prox_calls == 120
  end
end

@testset "Adaptive proposals outside working range" begin
  for T in (Float32, Float64)
    options = ProximalOptions(maxiter = 2)
    # The dual residual proposes an invalid halving. The first candidate's
    # reciprocal overflows. The second halving rounds to a different ratio.
    small_rho = floatmin(T) / 2
    odd_rho = prevfloat(floatmin(T))
    @test isfinite(inv(small_rho)) && isinf(inv(small_rho / 2))
    @test isfinite(inv(odd_rho / 2)) && 2 * (odd_rho / 2) != odd_rho
    for rho in (small_rho, odd_rho)
      method = ADMMSolver(; adaptive = true, ρ = rho, abstol = 0, reltol = 0)
      result = solve!(T[0], SqrNormL2(1, T[2]), NormL1(0), method, options)
      @test result.ρ === rho && result.converged
      @test result.minimizer == T[2] && result.prox_calls == 4
    end

    # The primal residual asks for a doubling of the largest finite penalty.
    large_rho = floatmax(T)
    method = ADMMSolver(; adaptive = true, ρ = large_rho, abstol = 0, reltol = 0)
    f, g = SqrNormL2(large_rho, T[1/2]), NormL1(large_rho)
    result = solve!(T[0], f, g, method, options)
    @test result.ρ === large_rho && result.status === :iteration_limit
    @test result.minimizer == T[0] && result.r_norm > 0 && result.s_norm == 0
    @test result.prox_calls == 4

    # Both candidate penalty and reciprocal are representable. Doubling the
    # scaled dual at the first update would overflow, so keep the old penalty.
    high = ldexp(one(T), exponent(floatmax(T)))
    rho = floatmin(T)
    method = ADMMSolver(; adaptive = true, ρ = rho, abstol = 0, reltol = 0)
    z, u = T[-high / 4], T[high]
    result = solve!(z, SqrNormL2(rho, T[T(5/4) * high]), NormL1(T(2)), method, options; u)
    @test result.ρ === rho && result.status === :iteration_limit
    @test result.u === u && u == T[high]
    @test z == T[high / 8] && result.r_norm == 0 && result.s_norm == T(1/4)
    @test result.prox_calls == 4 && isfinite(result.minimum)

    # A proposed doubling must preserve a nonzero subnormal scaled dual entry.
    δ = nextfloat(zero(T))
    method = ADMMSolver(; adaptive = true, abstol = 0, reltol = 0)
    result = solve!(T[0], SqrNormL2(1, T[2δ]), NormL1(δ), method, options)
    @test result.ρ === one(T) && result.prox_calls == 4
  end
end

@testset "Constructor and preflight refusals" begin
  for rho in (0, -1, Inf, NaN)
    @test_throws ArgumentError ADMMSolver(; ρ = rho)
  end
  for alpha in (0, 2, Inf, NaN)
    @test_throws ArgumentError ADMMSolver(; α = alpha)
  end
  for option in (:abstol, :abstol_dual, :reltol), value in (-1, Inf, NaN)
    @test_throws ArgumentError ADMMSolver(; option => value)
  end
  @test_throws MethodError ADMMSolver(; norm = norm)

  for T in (Float32, Float64)
    center = T[1, -1]
    z = T[1/2, -1/2]
    initial = copy(z)
    f, g, method = SqrNormL2(1, center), NormL1(1), ADMMSolver()
    for wrong in (T[0], T[], T[0, 0, 0])
      @test_throws DimensionMismatch solve!(wrong, f, g, method)
    end
    @test_throws DimensionMismatch solve!(z, SqrNormL2(1, T[1]), g, method)
    @test_throws ArgumentError solve!(reshape(z, 1, 2), f, g, method)
    @test_throws ArgumentError solve!((z,), f, g, method)
    @test_throws ArgumentError solve!(view(z, :), f, g, method)
    @test_throws ArgumentError solve!(sparsevec(z), f, g, method)
    @test_throws ArgumentError solve!(BigFloat.(z), f, g, method)
    @test_throws ArgumentError solve!(center, f, g, method)
    @test center == T[1, -1]
    # A wide design (n = 1 < p = 2) stays unsupported for both element types.
    @test_throws ArgumentError solve!(z, LeastSquaresLoss(T[1], T[1 0]), g, method)
    @test_throws ArgumentError solve!(z, SqrNormL2(1), g, method)
    @test_throws ArgumentError solve!(z, SqrNormL2(1, BigFloat.(center)), g, method)
    @test_throws ArgumentError solve!(z, SqrNormL2(0, center), g, method)
    @test_throws ArgumentError solve!(z, SqrNormL2(Inf, center), g, method)
    @test_throws ArgumentError solve!(z, SqrNormL2(1//3, center), g, method)
    @test_throws ArgumentError solve!(z, f, f, method)
    @test_throws ArgumentError solve!(z, f, NormL1(1, ones(T, 2)), method)
    @test_throws ArgumentError solve!(z, f, NormL1(Inf), method)
    @test_throws ArgumentError solve!(z, f, NormL1(1//3), method)
    @test_throws DimensionMismatch solve!(z, f, g, method; u = T[1])
    @test_throws ArgumentError solve!(z, f, g, method; u = BigFloat.(z))
    @test_throws ArgumentError solve!(z, f, g, method; u = view(z, :))
    @test_throws ArgumentError solve!(z, f, g, method; u = z)
    @test_throws ArgumentError solve!(z, f, g, method; u = center)
    @test center == T[1, -1]
    for nonfinite in (T(Inf), T(NaN))
      invalid = T[8, nonfinite]
      @test_throws ArgumentError solve!(invalid, f, g, method)
      @test isequal(invalid, T[8, nonfinite])
      @test_throws ArgumentError solve!(z, SqrNormL2(1, invalid), g, method)
      @test_throws ArgumentError solve!(z, f, g, method; u = invalid)
      @test isequal(invalid, T[8, nonfinite])
    end
    for (option, value) in ((:ftol, 0.0), (:xtol, 1e-4), (:gradtol, 0.0),
                            (:f_calls_limit, 1), (:grad_calls_limit, 1), (:allow_f_increases, true),
                            (:store_trace, true), (:show_trace, true), (:extended_trace, true),
                            (:callback, identity), (:print_every, 2))
      @test_throws ArgumentError solve!(z, f, g, method, ProximalOptions(; option => value))
    end
    @test z == initial
  end

  union_z = Union{Float32, Float64}[1.0f0, 2.0]
  union_center = Union{Float32, Float64}[2.0f0, 1.0]
  @test_throws ArgumentError solve!(union_z, SqrNormL2(1, union_center), NormL1(1), ADMMSolver())
  @test union_z == Union{Float32, Float64}[1.0f0, 2.0]

  center32, z32 = Float32[1], Float32[2]
  f, g = SqrNormL2(1, center32), NormL1(0)
  for options in ((; ρ = 1e40), (; ρ = 1e-50), (; ρ = Float64(nextfloat(0.0f0))),
                  (; α = 1e-50), (; α = prevfloat(2.0)), (; abstol = 1e40), (; reltol = 1e-50))
    @test_throws ArgumentError solve!(z32, f, g, ADMMSolver(; options...))
    @test z32 == Float32[2]
  end
end

@testset "Nonfinite arithmetic leaves the starting point intact" begin
  for T in (Float32, Float64)
    center = zeros(T, 2)
    f, g = SqrNormL2(1, center), NormL1(0)
    z = T[2, -2]
    @test_throws ErrorException solve!(z, f, g, ADMMSolver(; abstol = floatmax(T)))
    @test z == T[2, -2]

    # A complete iterate and its diagnostic norms are finite, but its value is not.
    large = T(2)^(T === Float32 ? 90 : 700)
    z, u = T[large], T[large / 4]
    f = SqrNormL2(1, T[0])
    @test_throws ErrorException solve!(z, f, g, ADMMSolver(), ProximalOptions(prox_calls_limit = 2); u)
    @test z == T[large] && u == T[large / 4]

    z, u = T[floatmax(T)], T[-floatmax(T)]
    @test_throws ErrorException solve!(z, f, g, ADMMSolver(); u)
    @test z == T[floatmax(T)] && u == T[-floatmax(T)]
  end
end

@testset "Independently wrapped vector storage" begin
  for T in (Float32, Float64)
    backing = T[1, -1, 2, -2]
    GC.@preserve backing begin
      first = unsafe_wrap(Vector{T}, pointer(backing), 2)
      overlapping = unsafe_wrap(Vector{T}, pointer(backing, 2), 2)
      adjacent = unsafe_wrap(Vector{T}, pointer(backing, 3), 2)
      f, g = SqrNormL2(1, T[3, -3]), NormL1(1)
      method = ADMMSolver()
      @test_throws ArgumentError solve!(first, f, g, method; u = overlapping)
      @test_throws ArgumentError solve!(overlapping, SqrNormL2(1, first), g, method)
      @test_throws ArgumentError solve!(T[0, 0], SqrNormL2(1, overlapping), g, method; u = first)
      @test backing == T[1, -1, 2, -2]

      result = solve!(first, f, g, method; u = adjacent)
      @test result.converged && result.minimizer === first && result.u === adjacent
      @test backing[1:2] ≈ T[2, -2] atol = T(1e-3)
    end
  end
end

end
