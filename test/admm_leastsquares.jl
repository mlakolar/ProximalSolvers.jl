module ADMMLeastSquaresTests

using LinearAlgebra: Diagonal, I, inv, norm
using ProximalBase: LeastSquaresLoss, NormL1, SqrNormL2
import ProximalSolvers
using ProximalSolvers: ADMMResults, ADMMSolver, ProximalOptions, solve!
using Random: Xoshiro, randn
using Test

# The references use the stored data directly, in BigFloat arithmetic, independently of the
# PB oracles and of the ADMM implementation.
soft_threshold(x, level) = sign(x) * max(abs(x) - level, 0)

lasso_objective(β, X, y, λ) =
  sum(abs2, BigFloat.(y) - BigFloat.(X) * BigFloat.(β)) / 2 + BigFloat(λ) * sum(abs, BigFloat.(β))

# The largest violation of 0 ∈ X'(Xβ - y) + λ ∂‖β‖₁.
function kkt_score(β, X, y, λ)
  gradient = BigFloat.(X)' * (BigFloat.(X) * BigFloat.(β) - BigFloat.(y))
  level = BigFloat(λ)
  maximum(eachindex(β)) do j
    iszero(β[j]) ? max(abs(gradient[j]) - level, 0) : abs(gradient[j] + level * sign(β[j]))
  end
end

# Cyclic coordinate descent in BigFloat, run to a fixed point.
function reference_lasso(X, y, λ; sweeps = 20_000)
  Xb, yb, λb = BigFloat.(X), BigFloat.(y), BigFloat(λ)
  β = zeros(BigFloat, size(X, 2))
  residual = copy(yb)
  curvature = [sum(abs2, Xb[:, j]) for j in eachindex(β)]
  for _ in 1:sweeps
    change = big(0.0)
    for j in eachindex(β)
      rho = Xb[:, j]' * residual + curvature[j] * β[j]
      updated = soft_threshold(rho, λb) / curvature[j]
      residual -= (updated - β[j]) * Xb[:, j]
      change = max(change, abs(updated - β[j]))
      β[j] = updated
    end
    change < big"1e-40" && break
  end
  β
end

# One iteration of the scaled recurrence of ADM-02 from (z, u), with X'X + ρI inverted in BigFloat.
function reference_step(z, u, X, y, λ, ρ, α)
  Xb, zb, ub, ρb, αb = BigFloat.(X), BigFloat.(z), BigFloat.(u), BigFloat(ρ), BigFloat(α)
  x = inv(Xb' * Xb + ρb * I) * (Xb' * BigFloat.(y) + ρb * (zb - ub))
  relaxed = αb * x + (1 - αb) * zb
  next = soft_threshold.(relaxed + ub, BigFloat(λ) / ρb)
  (; x, z = next, u = ub + relaxed - next, r_norm = norm(x - next), s_norm = ρb * norm(next - zb))
end

# The result of a solve against the independent references.
function check_solution(result, X, y, λ, accuracy)
  z = result.minimizer
  reference = reference_lasso(X, y, λ)
  @test result.converged && result.status === :converged
  @test norm(BigFloat.(z) - reference, Inf) <= accuracy
  @test kkt_score(z, X, y, λ) <= accuracy
  objective = lasso_objective(z, X, y, λ)
  @test objective - lasso_objective(reference, X, y, λ) <= accuracy^2
  @test isapprox(result.minimum, objective; rtol = 64eps(), atol = 64eps())
  # The scaled dual at the reported penalty is -X'(Xz - y)/ρ.
  gradient = BigFloat.(X)' * (BigFloat.(X) * BigFloat.(z) - BigFloat.(y))
  @test norm(gradient + BigFloat(result.ρ) * BigFloat.(result.u), Inf) <= 8accuracy * max(1, result.ρ)
end

# Orthogonal columns with X'X = Diagonal([4, 16, 1]), so each coordinate is soft(X'y, λ) / d.
orthogonal_design() = [1.0 1 1; 1 -1 1; 1 1 -1; 1 -1 -1] * Diagonal([1.0, 2.0, 0.5])
orthogonal_response() = [3.0, 1.0, -1.0, 2.0]

function correlated_design()
  rng = Xoshiro(467)
  X = randn(rng, 30, 8)
  X[:, 2:end] .+= 0.8 .* X[:, 1]
  β = [2.0, 0.0, 0.0, -1.5, 0.0, 0.0, 0.5, 0.0]
  X, X * β + 0.1 * randn(rng, 30)
end

@testset "Orthogonal design against the closed form" begin
  X, y = orthogonal_design(), orthogonal_response()
  d, c = [4.0, 16.0, 1.0], X' * y
  for λ in (0.0, 1.75, 10.0), ρ in (0.5, 4.0), α in (0.75, 1.0, 1.5), start in ([0.0, 0.0, 0.0], [1.0, -2.0, 3.0])
    expected = soft_threshold.(BigFloat.(c), BigFloat(λ)) ./ d
    z, X0, y0 = copy(start), copy(X), copy(y)
    method = ADMMSolver(; ρ, α, abstol = 1e-13, reltol = 0)
    result = solve!(z, LeastSquaresLoss(y, X), NormL1(λ), method, ProximalOptions(maxiter = 5000))
    @test result isa ADMMResults{Float64, Vector{Float64}} && result.minimizer === z
    @test result.prox_calls == 2 * result.iterations && ProximalSolvers.f_calls(result) == 1
    @test norm(BigFloat.(z) - expected, Inf) <= 1e-10
    check_solution(result, X, y, λ, 1e-9)
    @test X == X0 && y == y0
  end
end

@testset "Correlated tall design: fixed, relaxed and adaptive" begin
  X, y = correlated_design()
  λ = 20.0
  reference = reference_lasso(X, y, λ)
  @test any(iszero, reference) && any(!iszero, reference)
  for (name, method) in (("fixed", ADMMSolver(; abstol = 1e-12, reltol = 0)),
                         ("relaxed", ADMMSolver(; α = 1.6, abstol = 1e-12, reltol = 0)),
                         ("under-relaxed", ADMMSolver(; α = 0.7, abstol = 1e-12, reltol = 0)),
                         ("adaptive", ADMMSolver(; ρ = 1e-3, abstol = 1e-12, reltol = 0, adaptive = true)))
    @testset "$name" begin
      z, u = zeros(8), zeros(8)
      result = solve!(z, LeastSquaresLoss(y, X), NormL1(λ), method, ProximalOptions(maxiter = 200_000); u)
      @test result.minimizer === z && result.u === u
      check_solution(result, X, y, λ, 1e-7)
      @test findall(iszero, z) == findall(iszero, reference)
      name == "adaptive" && @test result.ρ != 1e-3
    end
  end
end

@testset "One iteration against an independent replay" begin
  X, y = correlated_design()
  rng = Xoshiro(7)
  z0, u0 = randn(rng, 8), 0.1 * randn(rng, 8)
  λ, ρ = 12.0, 0.7
  for α in (0.6, 1.0, 1.3)
    z, u = copy(z0), copy(u0)
    method = ADMMSolver(; ρ, α)
    result = solve!(z, LeastSquaresLoss(y, X), NormL1(λ), method, ProximalOptions(prox_calls_limit = 2); u)
    step = reference_step(z0, u0, X, y, λ, ρ, α)
    scale = max(1, norm(step.z, Inf), norm(step.u, Inf))
    @test result.iterations == 1 && result.prox_calls == 2 && result.status === :prox_calls_limit
    @test !result.converged && result.ρ == ρ
    @test norm(BigFloat.(z) - step.z, Inf) <= 1e-11 * scale
    @test norm(BigFloat.(u) - step.u, Inf) <= 1e-11 * scale
    @test result.r_norm ≈ step.r_norm rtol = 1e-9
    @test result.s_norm ≈ step.s_norm rtol = 1e-9
    @test result.eps_pri ≈ sqrt(8) * 1e-6 + 1e-4 * Float64(max(norm(step.x), norm(step.z))) rtol = 1e-9
    @test result.eps_dual ≈ sqrt(8) * 1e-6 + 1e-4 * ρ * Float64(norm(step.u)) rtol = 1e-9
    @test result.minimum ≈ lasso_objective(z, X, y, λ) rtol = 64eps()
  end
end

@testset "Statuses and counters" begin
  X, y = correlated_design()
  λ = 20.0
  tight = ADMMSolver(; abstol = 0, reltol = 0)
  z = fill(0.5, 8)
  result = solve!(z, LeastSquaresLoss(y, X), NormL1(λ), tight, ProximalOptions(maxiter = 2))
  @test result.status === :iteration_limit && result.iterations == 2 && result.prox_calls == 4 && !result.converged
  z = fill(0.5, 8)
  result = solve!(z, LeastSquaresLoss(y, X), NormL1(λ), tight, ProximalOptions(prox_calls_limit = 5))
  @test result.status === :prox_calls_limit && result.iterations == 2 && result.prox_calls == 4
  @test ProximalSolvers.call_limit_reached(result)

  # A nonpositive time limit permits no iteration: the start is returned and the diagnostics are NaN.
  z, u = fill(0.5, 8), fill(0.25, 8)
  f = LeastSquaresLoss(y, X)
  result = solve!(z, f, NormL1(λ), ADMMSolver(; ρ = 3.0), ProximalOptions(time_limit = 0.0); u)
  @test result.status === :time_limit && result.iterations == 0 && result.prox_calls == 0 && !result.converged
  @test all(isnan, (result.r_norm, result.s_norm, result.eps_pri, result.eps_dual)) && result.ρ == 3.0
  @test z == fill(0.5, 8) && u == fill(0.25, 8) && result.minimizer === z && result.u === u
  @test result.minimum ≈ lasso_objective(z, X, y, λ) rtol = 64eps()
  @test !f.svd_ready

  # y = 0 and z = u = 0 is stationary: both residuals are exactly zero and the guard passes.
  z = zeros(8)
  result = solve!(z, LeastSquaresLoss(zeros(30), X), NormL1(λ), ADMMSolver())
  @test result.status === :converged && result.converged && result.iterations == 1 && iszero(result.minimum)

  # With a huge penalty, rounding gives two zero residuals at a point that is not stationary.
  ones_design = ones(2, 1)
  z = [1.0]
  result = solve!(z, LeastSquaresLoss(zeros(2), ones_design), NormL1(1.0), ADMMSolver(; ρ = 1e20))
  @test result.status === :stagnated && !result.converged && ProximalSolvers.stagnated(result)
  @test result.iterations == 1 && iszero(result.r_norm) && iszero(result.s_norm) && z == [1.0]
  @test result.minimum == 2
end

@testset "Warm start and reuse of the loss" begin
  X, y = correlated_design()
  λ = 20.0
  f, g = LeastSquaresLoss(y, X), NormL1(λ)
  z, u = zeros(8), 0.5 * ones(8)
  first = solve!(z, f, g, ADMMSolver(; ρ = 1e-3, abstol = 1e-3, reltol = 0, adaptive = true),
                 ProximalOptions(maxiter = 200_000); u)
  @test first.converged && first.ρ != 1e-3 && f.svd_ready
  X0, y0 = copy(X), copy(y)
  second = solve!(z, f, g, ADMMSolver(; ρ = first.ρ, abstol = 1e-12, reltol = 0), ProximalOptions(maxiter = 200_000); u)
  @test second.minimizer === z && second.u === u
  check_solution(second, X, y, λ, 1e-7)
  # The same loss gives the same answer again, and the borrowed data are unchanged.
  z2 = zeros(8)
  third = solve!(z2, f, g, ADMMSolver(; ρ = first.ρ, abstol = 1e-12, reltol = 0), ProximalOptions(maxiter = 200_000))
  check_solution(third, X, y, λ, 1e-7)
  @test X == X0 && y == y0
end

@testset "No cutoff on the penalty or the coefficients" begin
  X, y = orthogonal_design(), orthogonal_response()
  for ρ in (1e-6, 1e6)
    result = solve!(zeros(3), LeastSquaresLoss(y, X), NormL1(1.0), ADMMSolver(; ρ), ProximalOptions(maxiter = 3))
    @test result.iterations == 3 && isfinite(result.minimum)
  end
  scale = 1e8
  z = zeros(3)
  result = solve!(z, LeastSquaresLoss(scale * y, X), NormL1(1.75scale), ADMMSolver(; abstol = 1e-4, reltol = 1e-12),
                  ProximalOptions(maxiter = 10_000))
  expected = soft_threshold.(BigFloat.(X' * y), BigFloat(1.75)) ./ [4, 16, 1] .* scale
  @test result.converged && norm(BigFloat.(z) - expected, Inf) <= 1e-8 * scale
end

# A refused solve raises `exception` and leaves z, u and the data untouched.
function refuse(exception, z, f, g, method = ADMMSolver(); u = nothing, options = ProximalOptions())
  before = (copy(z), u === nothing ? nothing : copy(u), copy(f.Y), copy(f.X), copy(f.tmp), f.svd_ready)
  @test_throws exception solve!(z, f, g, method, options; u)
  @test isequal(z, before[1]) && (u === nothing || isequal(u, before[2]))
  @test isequal(f.Y, before[3]) && isequal(f.X, before[4])
  # A preflight refusal also leaves the scratch of the loss alone; a numerical failure may use it.
  exception === ErrorException || @test isequal(f.tmp, before[5]) && f.svd_ready == before[6]
end

@testset "Refusals leave the caller's buffers untouched" begin
  X, y = orthogonal_design(), orthogonal_response()
  g = NormL1(1.0)
  z, u = [0.5, -0.5, 0.25], [0.1, 0.2, 0.3]
  f() = LeastSquaresLoss(y, X)

  @testset "shape" begin
    wide = randn(Xoshiro(1), 3, 5)
    refuse(ArgumentError, zeros(5), LeastSquaresLoss(ones(3), wide), g)
    refuse(ArgumentError, zeros(5), LeastSquaresLoss(ones(3), wide), g; u = zeros(5))
    refuse(ArgumentError, zeros(4), LeastSquaresLoss(ones(3), wide[:, 1:4]), g)
    refuse(DimensionMismatch, zeros(3), LeastSquaresLoss(ones(3), wide), g)
    refuse(DimensionMismatch, Float64[], LeastSquaresLoss(Float64[], zeros(0, 2)), g)
    refuse(DimensionMismatch, Float64[], LeastSquaresLoss(ones(3), zeros(3, 0)), g)
    refuse(DimensionMismatch, zeros(2), LeastSquaresLoss(Float64[], zeros(0, 2)), g)
    refuse(DimensionMismatch, zeros(2), f(), g)
    refuse(DimensionMismatch, zeros(4), f(), g)
    refuse(DimensionMismatch, copy(z), f(), g; u = zeros(2))
    refuse(DimensionMismatch, copy(z), f(), g; u = zeros(4))
    # The scratch of the loss must match the data and its cached decomposition the design.
    tampered = f()
    tampered.tmp = zeros(5)
    refuse(DimensionMismatch, copy(z), tampered, g)
    stale = f()
    stale.svd_ready = true
    refuse(DimensionMismatch, copy(z), stale, g)
    prepared = f()
    solve!(zeros(3), prepared, g, ADMMSolver(), ProximalOptions(maxiter = 2))
    prepared.s2 = zeros(2)
    refuse(DimensionMismatch, copy(z), prepared, g)
  end

  @testset "storage and penalty" begin
    refuse(ArgumentError, copy(z), f(), g; u = Float32.(u))
    refuse(ArgumentError, copy(z), f(), g; u = view(copy(u), :))
    refuse(ArgumentError, copy(z), LeastSquaresLoss(Float32.(y), Float32.(X)), g)
    refuse(ArgumentError, copy(z), LeastSquaresLoss(Float32.(y), X), g)
    refuse(ArgumentError, copy(z), LeastSquaresLoss(y, view(X, :, :)), g)
    refuse(ArgumentError, copy(z), LeastSquaresLoss(view(y, :), X), g)
    refuse(ArgumentError, copy(z), LeastSquaresLoss([1, 2, 3, 4], [1 0 0; 0 1 0; 0 0 1; 1 1 1]), g)
    @test_throws ArgumentError solve!(Float32.(z), f(), g, ADMMSolver())
    @test_throws ArgumentError solve!(view(copy(z), :), f(), g, ADMMSolver())
    @test_throws ArgumentError solve!(copy(z), 2.0 * f(), g, ADMMSolver())
    @test_throws ArgumentError solve!(copy(z), f(), NormL1(1.0, ones(3)), ADMMSolver())
    @test_throws ArgumentError solve!(copy(z), f(), NormL1(-1.0), ADMMSolver())
    @test_throws ArgumentError solve!(copy(z), f(), NormL1(Inf), ADMMSolver())
    @test_throws ArgumentError solve!(copy(z), f(), NormL1(0.1), ADMMSolver(); kwargs = 1)
    @test_throws ArgumentError solve!(copy(z), f(), SqrNormL2(1.0), ADMMSolver())
  end

  @testset "nonfinite data" begin
    for bad in (NaN, Inf, -Inf)
      Xbad, ybad = copy(X), copy(y)
      Xbad[2, 2] = bad
      refuse(ArgumentError, copy(z), LeastSquaresLoss(y, Xbad), g)
      ybad[1] = bad
      refuse(ArgumentError, copy(z), LeastSquaresLoss(ybad, X), g)
      refuse(ArgumentError, [0.0, bad, 0.0], f(), g)
      refuse(ArgumentError, copy(z), f(), g; u = [0.0, bad, 0.0])
    end
    # Finite data whose objective overflows fails after the iterations and before any write.
    refuse(ErrorException, copy(z), LeastSquaresLoss(fill(1e200, 3), Matrix(1.0I, 3, 3)), g;
           options = ProximalOptions(maxiter = 2))
    refuse(ErrorException, fill(1e300, 3), LeastSquaresLoss(ones(3), Matrix(1.0I, 3, 3)), g;
           options = ProximalOptions(maxiter = 3))
  end

  @testset "overlapping storage" begin
    backing = collect(1.0:8.0)
    GC.@preserve backing begin
      response = unsafe_wrap(Vector{Float64}, pointer(backing), 4)
      start = unsafe_wrap(Vector{Float64}, pointer(backing, 4), 3)
      refuse(ArgumentError, start, LeastSquaresLoss(response, X), g)
      @test backing == collect(1.0:8.0)
    end
    design = copy(X)
    GC.@preserve design begin
      dual = unsafe_wrap(Vector{Float64}, pointer(design, 10), 3)
      refuse(ArgumentError, copy(z), LeastSquaresLoss(y, design), g; u = dual)
      inside = unsafe_wrap(Vector{Float64}, pointer(design, 2), 3)
      refuse(ArgumentError, inside, LeastSquaresLoss(y, design), g)
    end
    square, right = Matrix(Diagonal([1.0, 2.0, 3.0])), [1.0, 1.0, 1.0]
    refuse(ArgumentError, right, LeastSquaresLoss(right, square), g)
    refuse(ArgumentError, copy(z), LeastSquaresLoss(right, square), g; u = right)
    shared = zeros(3)
    refuse(ArgumentError, shared, LeastSquaresLoss(right, square), g; u = shared)
    own = LeastSquaresLoss(right, square)
    refuse(ArgumentError, own.tmp, own, g)
    refuse(ArgumentError, copy(z), own, g; u = own.tmp)
    ready = LeastSquaresLoss(right, square)
    solve!(zeros(3), ready, g, ADMMSolver(), ProximalOptions(maxiter = 2))
    refuse(ArgumentError, ready.w, ready, g)
    refuse(ArgumentError, copy(z), ready, g; u = ready.s2)
  end
end

end
