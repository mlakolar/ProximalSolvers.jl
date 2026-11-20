module PGDGraphicalLassoTests

using LinearAlgebra: Diagonal, I, Symmetric, SymTridiagonal, cholesky, diagind, dot, eigmin, issuccess, logdet, norm
using ProximalBase: LogDetLoss, NormL1, NormLinf, prox!
using ProximalSolvers: ADMMSolver, AccProxGradDescent, LineSearches, OptimizationResults, ProximalGradientDescent, ProximalOptions, solve!
using Random: Xoshiro, randn
using Test

identity_matrix(T, p) = Matrix{T}(I, p, p)
function weights(T, p, level)
  W = fill(T(level), p, p)
  W[diagind(W)] .= 0
  W
end
target(::Type{Float32}) = 5e-4
target(::Type{Float64}) = 1e-8
pg_options() = ProximalOptions(; maxiter=20000, gradtol=5e-10, ftol=0)

# Use BigFloat independently of PB and the solver's working-precision gradient.
function independent(Θ, S, g)
  X, A, C = BigFloat.(Θ), BigFloat.(S), BigFloat(g.λ0) .* BigFloat.(g.w)
  factor = cholesky(Symmetric(X))
  inverse = inv(factor)
  G = A - inverse
  scale = max(big(1), maximum(abs, A), maximum(C))
  score = maximum(eachindex(G)) do i
    iszero(X[i]) ? max(abs(G[i]) - C[i], 0) : abs(G[i] + sign(X[i]) * C[i])
  end / scale
  trace, ld, penalty = dot(A, X), logdet(factor), dot(C, abs.(X))
  primal = trace - ld + penalty
  # U satisfies the dual box and has zero diagonal. A Cholesky check is
  # required before logdet(A + U) + p gives a dual lower bound.
  U = clamp.(inverse - A, -C, C)
  dual_factor = cholesky(Symmetric(A + U); check=false)
  gap = issuccess(dual_factor) ? primal - (logdet(dual_factor) + size(X, 1)) : big(NaN)
  (; score, primal, gap, scale_objective=1 + abs(trace) + abs(ld) + penalty)
end

function check_solution!(Θ, S, g; reference=nothing, expected_backtracks=nothing)
  f = LogDetLoss(S)
  S_snapshot, W_snapshot = copy(f.S), copy(g.w)
  r = solve!(Θ, f, g, ProximalGradientDescent(), pg_options())
  T = eltype(Θ)
  @test r isa OptimizationResults && r.minimizer === Θ
  @test r.converged && r.grad_converged && !r.stagnated && !r.call_limit_reached
  @test !r.iteration_converged && !r.f_converged
  @test r.g_residual <= r.g_tol && r.g_tol == max(5e-10, 64eps(T))
  @test Θ == Θ' && all(isfinite, Θ)
  @test issuccess(cholesky(Symmetric(Θ); check=false))
  @test r.minimum === (f(Θ) + g(Θ))
  @test isequal(f.S, S_snapshot) && isequal(g.w, W_snapshot)
  @test r.grad_calls == r.iterations + 1
  @test r.iterations + 1 <= r.f_calls <= r.prox_calls + 1 <= r.backtrack_steps + 1
  @test r.backtrack_steps <= 64 * r.iterations
  @test isfinite(r.x_residual) && isfinite(r.f_residual)
  @test isnan(r.gap) && isempty(r.trace)
  expected_backtracks === nothing || @test r.backtrack_steps == expected_backtracks
  d = independent(Θ, S, g)
  @test d.score <= target(T)
  @test abs(d.score - r.g_residual) <= 32eps(T)
  @test abs(r.minimum - d.primal) <= 32 * size(Θ, 1) * eps(T) * d.scale_objective
  @test -big"1e-60" <= d.gap <= target(T) * max(1, abs(d.primal))
  if reference !== nothing
    @test maximum(abs, BigFloat.(Θ) - reference) <= target(T) * max(1, maximum(abs, reference))
  end
  d
end

@testset "Matrix PGD analytic optima" begin
  for T in (Float32, Float64)
    for s in (T(0.5), T(4))
      check_solution!(ones(T, 1, 1), fill(s, 1, 1), NormL1(0.25, zeros(T, 1, 1));
                      reference=fill(inv(BigFloat(s)), 1, 1))
    end
    S = Matrix(Diagonal(T[0.5, 1, 2, 4]))
    check_solution!(identity_matrix(T, 4), S, NormL1(1, weights(T, 4, 0.125));
                    reference=inv(BigFloat.(S)))

    for (s, level) in ((0.3, 0.5), (0.8, 0.3), (-0.8, 0.3))
      S = T[1 s; s 2]
      g = NormL1(0.5, weights(T, 2, 2level))
      W = BigFloat.(S)
      threshold = BigFloat(g.λ0) * BigFloat(g.w[1, 2])
      W[1, 2] = W[2, 1] = sign(W[1, 2]) * max(abs(W[1, 2]) - threshold, 0)
      Θ = identity_matrix(T, 2)
      check_solution!(Θ, S, g; reference=inv(W))
      @test iszero(Θ[1, 2]) == (abs(s) <= level)
    end

    S = T[2 0.5 0; 0.5 1 0.125; 0 0.125 1.25]
    check_solution!(identity_matrix(T, 3), S, NormL1(0, weights(T, 3, 0.125));
                    reference=inv(BigFloat.(S)))
    check_solution!(identity_matrix(T, 3), S, NormL1(1, weights(T, 3, 0.5));
                    reference=Diagonal(inv.(BigFloat.([S[i, i] for i in 1:3]))))
  end
end

@testset "Matrix PGD seeded and ADMM cross-check" begin
  for (p, n) in ((10, 150), (30, 300), (30, 20))
    truth = Matrix(SymTridiagonal(fill(1.5, p), fill(-0.35, p - 1)))
    Σ = inv(truth)
    X = randn(Xoshiro(444 + n), n, p) * cholesky(Symmetric(Σ)).U
    X .-= sum(X; dims=1) ./ n
    S64 = Matrix(Symmetric(X' * X / n))
    for T in (Float32, Float64)
      S = T.(S64)
      g = NormL1(one(T), weights(T, p, n < p ? 0.25 : 0.12))
      Θ = identity_matrix(T, p)
      d = check_solution!(Θ, S, g)
      if p == 10
        other = identity_matrix(T, p)
        tol = T === Float32 ? 1e-6 : 1e-11
        result = solve!(other, LogDetLoss(S), g, ADMMSolver(; abstol=tol, reltol=tol),
                        ProximalOptions(; maxiter=5000))
        @test result.converged && all(isfinite, other) && other == other'
        ref = independent(other, S, g)
        @test ref.score <= target(T)
        @test -big"1e-60" <= ref.gap <= target(T) * max(1, abs(ref.primal))
        @test abs(d.primal - ref.primal) <= target(T) * max(1, abs(d.primal))
        @test maximum(abs, Θ - other) <= target(T) * max(1, maximum(abs, other))
      end
    end
  end
end

@testset "Matrix PGD preflight and nonmutation" begin
  m = ProximalGradientDescent()
  for T in (Float32, Float64)
    Θ = identity_matrix(T, 2)
    f = LogDetLoss(T[1 0.125; 0.125 1])
    g = NormL1(one(T), weights(T, 2, 0.125))
    other = T === Float32 ? Float64 : Float32
    function refused(E, X=Θ, loss=f, penalty=g, method=m, options=ProximalOptions(); kwargs...)
      before = copy(X)
      S_before = copy(loss.S)
      W_before = penalty isa NormL1 && penalty.w !== nothing ? copy(penalty.w) : nothing
      @test_throws E solve!(X, loss, penalty, method, options; kwargs...)
      @test isequal(X, before) && isequal(loss.S, S_before)
      W_before === nothing || @test isequal(penalty.w, W_before)
    end
    refused(DimensionMismatch, zeros(T, 0, 0))
    refused(DimensionMismatch, ones(T, 2, 3))
    refused(DimensionMismatch, Θ, LogDetLoss(ones(T, 1, 1)))
    refused(DimensionMismatch, Θ, f, NormL1(1, zeros(T, 1, 4)))
    refused(ArgumentError, T[1 0; 0.5 1])
    refused(ArgumentError, T[1 2; 2 1])
    refused(ArgumentError, T[0 0; 0 1])
    refused(ArgumentError, T[Inf 0; 0 1])
    refused(ArgumentError, Θ, LogDetLoss(other.(f.S)))
    refused(ArgumentError, Θ, LogDetLoss(f.S, 2))
    refused(ArgumentError, Symmetric(Θ))
    refused(ArgumentError, view(Θ, :, :))
    refused(ArgumentError, Θ, f, NormLinf(1))
    refused(ArgumentError, Θ, f, NormL1(1))
    refused(ArgumentError, Θ, f, NormL1(1, other.(g.w)))
    refused(ArgumentError, Θ, f, NormL1(1, Symmetric(g.w)))
    refused(ArgumentError, Θ, f, NormL1(1, ones(T, 2, 2)))
    refused(ArgumentError, Θ, f, NormL1(1, T[0 1; 2 0]))
    refused(ArgumentError, Θ, f, NormL1(1, T[0 Inf; Inf 0]))
    refused(ArgumentError, Θ, f, NormL1(Inf, g.w))
    refused(ArgumentError, Θ, f, NormL1(1//3, g.w))
    refused(ArgumentError, Θ, f, NormL1(floatmax(T), weights(T, 2, 2)))
    refused(ArgumentError, Θ, f, g, AccProxGradDescent())
    for bad in (T(0.5), T(NaN))
      modified = LogDetLoss(f.S)
      modified.S[1, 2] = bad
      refused(ArgumentError, Θ, modified)
    end
    mod_weights = copy(g.w)
    penalty = NormL1(1, mod_weights)
    mod_weights[1, 2] = mod_weights[2, 1] = -one(T)
    refused(ArgumentError, Θ, f, penalty)
    refused(ArgumentError, f.S)
    shared = LogDetLoss(g.w)
    refused(ArgumentError, Θ, shared, NormL1(1, shared.S))
    GC.@preserve f begin
      # Independently wrapped dense arrays can overlap without a shared array identity.
      X = unsafe_wrap(Array, pointer(f.S), size(f.S); own=false)
      refused(ArgumentError, X)
    end
    refused(ArgumentError, Θ, f, g, ProximalGradientDescent(; ls=LineSearches.BackTracking(Lexact=1)))
    for options in (ProximalOptions(allow_f_increases=true), ProximalOptions(store_trace=true),
                    ProximalOptions(show_trace=true), ProximalOptions(extended_trace=true),
                    ProximalOptions(print_every=2), ProximalOptions(callback=identity))
      refused(ArgumentError, Θ, f, g, m, options)
    end
    refused(ArgumentError; u=nothing)
    if T === Float32
      for ls in (LineSearches.BackTracking(α=1e-100), LineSearches.BackTracking(β=1e-100),
                 LineSearches.BackTracking(β=prevfloat(1.0)))
        refused(ArgumentError, Θ, f, g, ProximalGradientDescent(; ls))
      end
    end
  end
end

@testset "Matrix PGD keeps its last accepted SPD point" begin
  for T in (Float32, Float64)
    array(x) = fill(T(x), 1, 1)
    g = NormL1(one(T), array(0))
    m = ProximalGradientDescent()
    f = LogDetLoss(array(4))
    z = array(1)
    @test only(z) - (only(f.S) - inv(only(z))) < 0
    r = solve!(z, f, g, m, pg_options())
    @test r.converged && z == array(0.25)
    @test (r.iterations, r.backtrack_steps, r.prox_calls, r.f_calls, r.grad_calls) == (1, 3, 3, 2, 2)
    @test r.x_residual == 0.75 && r.g_residual == 0

    # With β essentially one, the first step succeeds and the second fails
    # every trial. The accepted first scalar update is computable by hand.
    ls = LineSearches.BackTracking(α=one(T), β=prevfloat(one(T)))
    start = array(2.125)
    f = LogDetLoss(array(2))
    accepted = start - (f.S - inv.(start))
    z = copy(start)
    @test_throws "matrix PGD line search failed after 64 trials" solve!(z, f, g, ProximalGradientDescent(; ls), pg_options())
    @test z ≈ accepted && z != start && eigmin(Symmetric(z)) > 0

    f = LogDetLoss(array(4))
    z = array(1)
    @test_throws "matrix PGD line search failed after 64 trials" solve!(z, f, g, ProximalGradientDescent(; ls), pg_options())
    @test z == array(1)
    tiny = LineSearches.BackTracking(α=one(T), β=nextfloat(zero(T)))
    @test_throws "finite positive step and reciprocal" solve!(z, f, g, ProximalGradientDescent(; ls=tiny), pg_options())
    @test z == array(1)

    # The first proposal is SPD and the logdet term is finite, but the smooth
    # objective is out of range. The value budget stops before a second trial.
    scale = sqrt(floatmax(T))
    z = array(inv(8scale))
    f = LogDetLoss(array(4scale))
    snapshot = copy(z)
    proposal = z - (f.S - inv.(z))
    @test only(proposal) > 0 && isfinite(f(z)) && !isfinite(f(proposal))
    r = solve!(z, f, g, m, ProximalOptions(f_calls_limit=2))
    @test r.call_limit_reached && !r.converged && z == snapshot
    @test (r.iterations, r.backtrack_steps, r.prox_calls, r.f_calls, r.grad_calls) == (0, 1, 1, 2, 1)
  end
end

@testset "Matrix PGD proposals, stagnation, and budget precedence" begin
  for T in (Float32, Float64)
    start = ones(T, 1, 1)
    m, g = ProximalGradientDescent(), NormL1(one(T), zeros(T, 1, 1))
    f = LogDetLoss(fill(T(4), 1, 1))
    for (options, limits, counts) in (
      (ProximalOptions(f_calls_limit=1), true, (0, 0, 0, 1, 1)),
      (ProximalOptions(grad_calls_limit=1), true, (0, 0, 0, 1, 1)),
      (ProximalOptions(prox_calls_limit=1), true, (0, 1, 1, 1, 1)),
      (ProximalOptions(time_limit=0), false, (0, 0, 0, 1, 1)))
      z = copy(start)
      r = solve!(z, f, g, m, options)
      @test r.call_limit_reached == limits && !r.converged && !r.stagnated
      @test !r.x_converged && !r.f_converged && !r.grad_converged
      @test (r.iterations, r.backtrack_steps, r.prox_calls, r.f_calls, r.grad_calls) == counts
      @test z == start && r.minimum == f(z) && r.g_residual == 0.75
      @test isnan(r.x_residual) && isnan(r.f_residual)
    end
    z = copy(start)
    r = solve!(z, f, g, m, ProximalOptions(prox_calls_limit=3))
    @test r.call_limit_reached && !r.converged && !r.grad_converged
    @test z == fill(T(0.25), 1, 1) && r.g_residual == 0

    z = copy(start)
    f = LogDetLoss(fill(T(0.5), 1, 1))
    r = solve!(z, f, g, m, ProximalOptions(maxiter=2, ftol=1, xtol=1, gradtol=0))
    @test r.iteration_converged && !r.converged && !r.x_converged && !r.f_converged
    @test r.iterations == 2 && 0 < r.x_residual < r.x_tol && r.f_residual < r.f_tol
  end

  # At x = 10^6, a positive unit step times a gradient of about 10^-4 is
  # rounded away in Float32, even though the normalized KKT score is too large.
  z = fill(1f6, 1, 1)
  f, g = LogDetLoss(fill(1f-4, 1, 1)), NormL1(1f0, zeros(Float32, 1, 1))
  r = solve!(z, f, g, ProximalGradientDescent(), ProximalOptions(ftol=1, xtol=1, gradtol=0))
  @test z == fill(1f6, 1, 1) && r.stagnated && !r.converged
  @test !r.x_converged && !r.f_converged && !r.grad_converged
  @test r.g_residual > r.g_tol && r.x_residual == r.f_residual == 0
  @test (r.iterations, r.backtrack_steps, r.prox_calls, r.f_calls, r.grad_calls) == (1, 1, 1, 2, 2)

  # An exact fixed point may return success under the same positive step.
  z = ones(Float32, 1, 1)
  r = solve!(z, LogDetLoss(z), g, ProximalGradientDescent(), ProximalOptions(ftol=0))
  @test r.converged && r.grad_converged && r.x_converged && !r.f_converged && !r.stagnated
end

end
