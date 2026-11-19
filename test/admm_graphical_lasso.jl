module ADMMGraphicalLassoTests

using LinearAlgebra: Diagonal, I, Symmetric, cholesky, diag, diagind, dot, eigen, eigmin, isposdef, issuccess, logdet, norm
using ProximalBase: BlockIterate, LogDetLoss, NormL1, SparseIterate, SqrNormL2
import ProximalSolvers
using ProximalSolvers: ADMMResults, ADMMSolver, AccProxGradDescent, CDSolver, ProximalGradientDescent, ProximalOptions, solve!
using Random: Xoshiro, randn
using Test

# The objective, KKT and certificate references below use the stored data
# directly, in BigFloat arithmetic, independently of the PB oracles and the ADMM
# implementation. Their `Λ` is the effective weight matrix λ₀Λ of the penalty
# `λ₀ Σᵢⱼ Λᵢⱼ |Θᵢⱼ|`.
soft_threshold(x, level) = sign(x) * max(abs(x) - level, 0)
effective(λ0, Λ) = BigFloat(λ0) .* BigFloat.(Λ)

# P(Θ) = -logdet Θ + tr(SΘ) + Σᵢⱼ Λᵢⱼ|Θᵢⱼ| and its three terms, with logdet from a
# BigFloat Cholesky factorization.
function gl_objective(Θ, S, Λ)
  Θb, Sb, Λb = BigFloat.(Θ), BigFloat.(S), BigFloat.(Λ)
  factor = cholesky(Symmetric(Θb); check = false)
  issuccess(factor) || return (; value = big(Inf), logdet = big(NaN), trace = big(NaN), penalty = big(NaN))
  ld = logdet(factor)
  trace = dot(Sb, Θb)
  penalty = sum(Λb .* abs.(Θb))
  (; value = trace - ld + penalty, logdet = ld, trace, penalty)
end

# With G = S - inv(Θ): |Gᵢᵢ| on the diagonal, |Gᵢⱼ + Λᵢⱼ sign(Θᵢⱼ)| at a nonzero
# off-diagonal entry and max(|Gᵢⱼ| - Λᵢⱼ, 0) at an exact zero. The relative score
# divides the largest score by max(1, maximum(abs, S)).
function kkt_scores(Θ, S, Λ)
  Sb, Λb = BigFloat.(S), BigFloat.(Λ)
  G = Sb - inv(BigFloat.(Θ))
  p = size(Θ, 1)
  worst = big(0.0)
  for j in 1:p, i in 1:p
    score = if i == j
      abs(G[i, i])
    elseif iszero(Θ[i, j])
      max(abs(G[i, j]) - Λb[i, j], 0)
    else
      abs(G[i, j] + Λb[i, j] * sign(Θ[i, j]))
    end
    worst = max(worst, score)
  end
  (; abs = Float64(worst), rel = Float64(worst / max(1, maximum(abs, Sb))))
end

# A dual-feasible W = S + U with Uᵢᵢ = 0 and |Uᵢⱼ| ≤ Λᵢⱼ, from the KKT relation
# U = inv(Θ) - S clipped into the box. When W is positive definite, weak duality
# gives P(Θ) ≥ D(W) = logdet W + p. Otherwise the point is not certified.
function dual_certificate(Θ, S, Λ)
  Sb, Λb = BigFloat.(S), BigFloat.(Λ)
  inverse = inv(BigFloat.(Θ))
  p = size(Θ, 1)
  U = zeros(BigFloat, p, p)
  for j in 2:p, i in 1:j-1
    U[i, j] = U[j, i] = clamp(inverse[i, j] - Sb[i, j], -Λb[i, j], Λb[i, j])
  end
  factor = cholesky(Symmetric(Sb + U); check = false)
  issuccess(factor) || return (; certified = false, gap = big(NaN), dual = big(NaN))
  dual = logdet(factor) + p
  (; certified = true, gap = gl_objective(Θ, S, Λ).value - dual, dual)
end

uint(::Type{Float32}) = UInt32
uint(::Type{Float64}) = UInt64
samebits(a::Array{T}, b::Array{T}) where {T<:Union{Float32, Float64}} =
  size(a) == size(b) && reinterpret(uint(T), a) == reinterpret(uint(T), b)
samebits(a, b) = typeof(a) == typeof(b) && isequal(a, b)

# Pre-registered acceptance bounds: absolute error and relative KKT score at most
# 1e-8 in Float64, and relative error and relative KKT score at most 1e-3 in Float32.
accuracy(::Type{Float64}) = 1e-8
accuracy(::Type{Float32}) = 1e-3
# Solver tolerances chosen to meet those bounds.
solver_tolerance(::Type{Float64}) = 1e-12
solver_tolerance(::Type{Float32}) = 1e-6
accurate_method(T; ρ = 1) = ADMMSolver(; ρ, abstol = solver_tolerance(T), reltol = solver_tolerance(T))
const LONG = ProximalOptions(maxiter = 5000)
final_error(T) = ErrorException("ADMM reached a consensus iterate that is not exactly symmetric with a successful Cholesky factorization in $T")
logdet_error(T) = ErrorException("ADMM produced a logdet prox output that is not finite and exactly symmetric with a successful Cholesky factorization in $T")

function within(Θ, reference, T)
  error = maximum(abs, BigFloat.(Θ) - BigFloat.(reference))
  T === Float64 ? error <= accuracy(T) : error <= accuracy(T) * max(1, maximum(abs, BigFloat.(reference)))
end

offdiagonal(p) = [(i, j) for j in 1:p for i in 1:p if i != j]

# Checks on a normal return, called by check_accurate and by the one-step and
# limit testsets. They compare the residual tests with the reported residuals and
# recompute eps_dual from the returned dual; the one-step testset replays both
# residuals and both tolerances independently. The objective tolerance of these
# fixtures is 32 p eps(T) times one plus the term magnitudes.
function check_solution(result, Θ, S, Λ, method)
  T = eltype(Θ)
  p = size(Θ, 1)
  @test result isa ADMMResults{T, Matrix{T}}
  @test result.minimizer === Θ
  @test Θ == Θ'
  @test issuccess(cholesky(Symmetric(Θ); check = false))
  @test result.u isa Matrix{T} && result.u == result.u' && !Base.mightalias(result.u, Θ)
  terms = gl_objective(Θ, S, Λ)
  @test all(isfinite, (terms.logdet, terms.trace, terms.penalty)) && isfinite(result.minimum)
  bound = 32 * p * eps(T) * (1 + abs(terms.logdet) + abs(terms.trace) + terms.penalty)
  @test abs(result.minimum - terms.value) <= bound
  @test result.prox_calls == 2 * result.iterations
  @test result.converged == (result.status === :converged)
  if result.iterations > 0
    @test all(isfinite, (result.r_norm, result.s_norm, result.eps_pri, result.eps_dual))
    expected_eps_dual = p * BigFloat(T(method.abstol_dual)) +
                        BigFloat(T(method.reltol)) * BigFloat(result.ρ) * norm(BigFloat.(result.u))
    @test isapprox(result.eps_dual, expected_eps_dual; rtol = 16eps(T))
  end
  if result.converged
    @test 0 <= result.r_norm <= result.eps_pri && 0 <= result.s_norm <= result.eps_dual
  end
  terms
end

function check_accurate(result, Θ, S, Λ, method; reference = nothing)
  T = eltype(Θ)
  terms = check_solution(result, Θ, S, Λ, method)
  @test result.converged && result.status === :converged
  scores = kkt_scores(Θ, S, Λ)
  @test scores.rel <= accuracy(T)
  certificate = dual_certificate(Θ, S, Λ)
  # In exact arithmetic weak duality gives P(Θ) ≥ D(W) for a positive-definite Θ
  # and a feasible W; the slack allows for BigFloat rounding.
  @test certificate.certified
  if certificate.certified
    @test certificate.gap >= -1e-30
    @test certificate.gap <= accuracy(T) * max(1, abs(terms.value))
  end
  reference === nothing || @test within(Θ, reference, T)
  (; terms, scores, certificate)
end

@testset "Graphical lasso: analytic references" begin
  for T in (Float32, Float64)
    @testset "$T" begin
      method = accurate_method(T)

      # p = 1 with S₁₁ > 0: the diagonal is unpenalized, so Θ* = 1/S₁₁ for any level.
      for s in (T(1/2), T(4))
        Θ, S, Λ = ones(T, 1, 1), fill(s, 1, 1), zeros(T, 1, 1)
        result = solve!(Θ, LogDetLoss(S), NormL1(T(0.75), Λ), method, LONG)
        check_accurate(result, Θ, S, effective(0.75, Λ), method; reference = inv.(BigFloat.(S)))
      end

      # Diagonal S with a positive diagonal and λ > 0: Θ* = diag(1 ./ diag(S)), whose
      # off-diagonals are zero.
      S = Matrix(Diagonal(T[1/2, 1, 2, 4]))
      Λ = fill(T(0.3), 4, 4)
      Λ[diagind(Λ)] .= 0
      Θ = Matrix{T}(I, 4, 4)
      result = solve!(Θ, LogDetLoss(S), NormL1(one(T), Λ), method, LONG)
      check_accurate(result, Θ, S, effective(1, Λ), method;
                     reference = Diagonal(inv.(BigFloat.(diag(S)))))
      @test all(Θ[i, j] == 0 for (i, j) in offdiagonal(4))

      # p = 2: W* = [S₁₁ soft(S₁₂, λ); soft(S₁₂, λ) S₂₂] and Θ* = inv(W*), in the
      # zero regime |S₁₂| ≤ λ and in the nonzero regime |S₁₂| > λ.
      for (s12, λ) in ((0.3, 0.5), (0.8, 0.3), (-0.8, 0.3))
        S = T[1 s12; s12 2]
        Λ = T[0 λ; λ 0]
        W = BigFloat.(S)
        W[1, 2] = W[2, 1] = soft_threshold(W[1, 2], BigFloat(Λ[1, 2]))
        @test isposdef(Symmetric(Float64.(W)))
        reference = inv(W)
        for (λ0, weights) in ((one(T), Λ), (T(1/2), 2Λ))
          Θ = Matrix{T}(I, 2, 2)
          result = solve!(Θ, LogDetLoss(S), NormL1(λ0, weights), method, LONG)
          check_accurate(result, Θ, S, effective(λ0, weights), method; reference)
          if abs(s12) <= λ
            @test Θ[1, 2] == Θ[2, 1] == 0
          else
            @test Θ[1, 2] != 0 && sign(Θ[1, 2]) == -sign(s12)
          end
        end
      end

      # Zero penalty with an SPD S: Θ* = inv(S). The certificate uses W = S, whose gap
      # is zero at the exact inverse and positive at an approximate fit. The penalty is
      # zero through zero weights or through a zero level with nonzero weights.
      S = T[2 1/2 1/4 0; 1/2 3/2 1/4 1/8; 1/4 1/4 1 3/8; 0 1/8 3/8 5/4]
      @test isposdef(S)
      nonzero_weights = fill(T(3/10), 4, 4)
      nonzero_weights[diagind(nonzero_weights)] .= 0
      for penalty in (NormL1(one(T), zeros(T, 4, 4)), NormL1(zero(T), nonzero_weights))
        Θ = Matrix{T}(I, 4, 4)
        result = solve!(Θ, LogDetLoss(S), penalty, method, LONG)
        outcome = check_accurate(result, Θ, S, effective(penalty.λ0, penalty.w), method; reference = inv(BigFloat.(S)))
        @test outcome.certificate.dual == logdet(cholesky(Symmetric(BigFloat.(S)))) + 4
      end

      # λ ≥ max_{i≠j} |Sᵢⱼ| and a positive diagonal: the diagonal optimum
      # diag(1 ./ diag(S)), whose off-diagonals are zero.
      λ = T(5/4) * maximum(abs(S[i, j]) for (i, j) in offdiagonal(4))
      Λ = fill(λ, 4, 4)
      Λ[diagind(Λ)] .= 0
      Θ = Matrix{T}(I, 4, 4)
      result = solve!(Θ, LogDetLoss(S), NormL1(one(T), Λ), method, LONG)
      check_accurate(result, Θ, S, effective(1, Λ), method; reference = Diagonal(inv.(BigFloat.(diag(S)))))
      @test all(Θ[i, j] == 0 for (i, j) in offdiagonal(4))
    end
  end
end

# A sparse symmetric positive-definite precision matrix: a chain with three extra edges.
function sparse_precision(p)
  Θ = Matrix(1.5I, p, p)
  for i in 1:p-1
    Θ[i, i+1] = Θ[i+1, i] = 0.5
  end
  for (i, j) in ((1, 5), (3, 9), (2, p))
    Θ[i, j] = Θ[j, i] = -0.4
  end
  Θ
end

@testset "Graphical lasso: seeded sparse precision matrix" begin
  p, n, λ = 16, 100, 0.08
  Θ_true = sparse_precision(p)
  @test isposdef(Θ_true)
  Σ_true = inv(Θ_true)
  U = cholesky(Symmetric(Σ_true)).U
  @test U' * U ≈ Σ_true
  # Rows of randn(n, p) * U have covariance U'U = Σ_true.
  X = randn(Xoshiro(436), n, p) * U
  X .-= sum(X; dims = 1) ./ n
  S64 = Matrix(Symmetric(X' * X / n))
  edges = [(i, j) for j in 2:p for i in 1:j-1]
  true_edges = count(e -> Θ_true[e...] != 0, edges)
  for T in (Float32, Float64)
    @testset "$T" begin
      S = T.(S64)
      @test S == S'
      Λ = fill(T(λ), p, p)
      Λ[diagind(Λ)] .= 0
      method = accurate_method(T)
      Θ = Matrix{T}(I, p, p)
      result = solve!(Θ, LogDetLoss(S), NormL1(one(T), Λ), method, LONG)
      check_accurate(result, Θ, S, effective(1, Λ), method)

      # Statistical sanity, not exact draws: each unordered pair counted once.
      tp = count(e -> Θ_true[e...] != 0 && Θ[e...] != 0, edges)
      fp = count(e -> Θ_true[e...] == 0 && Θ[e...] != 0, edges)
      fn = count(e -> Θ_true[e...] != 0 && Θ[e...] == 0, edges)
      @test tp + fn == true_edges
      @test tp >= 3true_edges ÷ 4
      @test tp + fp == count(e -> Θ[e...] != 0, edges)
      estimate_error = norm(Float64.(Θ) - Θ_true)
      inverse_error = norm(inv(Float64.(S)) - Θ_true)
      @test estimate_error < inverse_error
      @test estimate_error <= norm(Θ_true) / 2
    end
  end
end

@testset "Graphical lasso: one step, residuals and tolerances" begin
  for T in (Float32, Float64)
    S = T[2 1/2 0; 1/2 3/2 1/4; 0 1/4 1]
    Λ = T[0 1/5 1/5; 1/5 0 1/5; 1/5 1/5 0]
    start = T[1 1/8 0; 1/8 1 1/4; 0 1/4 1]
    dual = T[0 1/16 0; 1/16 0 -1/16; 0 -1/16 0]
    rho, abstol, abstol_dual, reltol = T(2), T(1/32), T(1/64), T(1/16)
    γ = inv(Float64(rho))
    # Independent replay of one iteration in Float64 from the stored data.
    B = Float64.(start - dual) - γ * Float64.(S)
    E = eigen(Symmetric(B))
    x = E.vectors * Diagonal((E.values .+ sqrt.(E.values .^ 2 .+ 4γ)) ./ 2) * E.vectors'
    v = x + Float64.(dual)
    thresholds = γ .* Float64.(Λ)
    @test minimum(abs(abs(v[i, j]) - thresholds[i, j]) for (i, j) in offdiagonal(3)) > 1e-2
    z = soft_threshold.(v, thresholds)
    next_dual = v - z
    r_norm, s_norm = norm(x - z), Float64(rho) * norm(z - Float64.(start))
    eps_pri = 3 * Float64(abstol) + Float64(reltol) * max(norm(x), norm(z))
    eps_dual = 3 * Float64(abstol_dual) + Float64(reltol) * Float64(rho) * norm(next_dual)
    @test isposdef(Symmetric(z))

    Θ, u = copy(start), copy(dual)
    method = ADMMSolver(; ρ = rho, abstol, abstol_dual, reltol)
    result = solve!(Θ, LogDetLoss(S), NormL1(one(T), Λ), method, ProximalOptions(prox_calls_limit = 3); u)
    comparison_rtol = 1000eps(T)
    @test result.iterations == 1 && result.prox_calls == 2
    @test result.status === :prox_calls_limit && !result.converged
    @test result.minimizer === Θ && result.u === u
    @test isapprox(Θ, z; rtol = comparison_rtol) && isapprox(u, next_dual; rtol = comparison_rtol, atol = comparison_rtol)
    @test isapprox(result.r_norm, r_norm; rtol = comparison_rtol)
    @test isapprox(result.s_norm, s_norm; rtol = comparison_rtol)
    @test isapprox(result.eps_pri, eps_pri; rtol = comparison_rtol)
    @test isapprox(result.eps_dual, eps_dual; rtol = comparison_rtol)
    @test result.ρ === rho
    check_solution(result, Θ, S, effective(1, Λ), method)
  end
end

@testset "Graphical lasso: limits and statuses" begin
  for T in (Float32, Float64)
    S = T[2 1/2 0; 1/2 3/2 1/4; 0 1/4 1]
    Λ = T[0 1/5 1/5; 1/5 0 1/5; 1/5 1/5 0]
    start = T[1 1/8 0; 1/8 1 1/4; 0 1/4 1]
    dual = T[0 1/16 0; 1/16 0 -1/16; 0 -1/16 0]
    f, g = LogDetLoss(S), NormL1(one(T), Λ)
    method = ADMMSolver(; abstol = 0, reltol = 0)
    # ProximalOptions requires maxiter ≥ 2; zero iterations come from the call
    # budget or a nonpositive time limit.
    for (options, status) in ((ProximalOptions(prox_calls_limit = 1), :prox_calls_limit),
                              (ProximalOptions(time_limit = 0), :time_limit),
                              (ProximalOptions(time_limit = -1), :time_limit))
      Θ, u = copy(start), copy(dual)
      result = solve!(Θ, f, g, method, options; u)
      @test result.minimizer === Θ && samebits(Θ, start)
      @test result.u === u && samebits(u, dual)
      @test !result.converged && result.status === status
      @test result.iterations == 0 && result.prox_calls == 0
      @test all(isnan, (result.r_norm, result.s_norm, result.eps_pri, result.eps_dual))
      @test result.ρ === one(T)
      terms = gl_objective(start, S, effective(1, Λ))
      @test abs(result.minimum - terms.value) <= 32 * 3 * eps(T) * (1 + abs(terms.logdet) + abs(terms.trace) + terms.penalty)
    end

    for (options, iterations, status) in ((ProximalOptions(prox_calls_limit = 3), 1, :prox_calls_limit),
                                          (ProximalOptions(prox_calls_limit = 4), 2, :prox_calls_limit),
                                          (ProximalOptions(maxiter = 2), 2, :iteration_limit))
      Θ = copy(start)
      result = solve!(Θ, f, g, method, options)
      @test !result.converged && result.status === status
      @test result.iterations == iterations && result.prox_calls == 2iterations
      @test result.r_norm > 0 && result.eps_pri == result.eps_dual == 0
      @test ProximalSolvers.iteration_limit_reached(result) == (status === :iteration_limit)
      @test ProximalSolvers.call_limit_reached(result) == (status === :prox_calls_limit)
      check_solution(result, Θ, S, effective(1, Λ), method)
    end
    @test occursin("ADMM results", sprint(show, solve!(copy(start), f, g, method, ProximalOptions(maxiter = 2))))
  end
end

@testset "Graphical lasso: zero residuals and stagnation" begin
  for T in (Float32, Float64)
    # An exact fixed point passes zero tolerances: Θ = 1/S₁₁.
    Θ = ones(T, 1, 1)
    result = solve!(Θ, LogDetLoss(ones(T, 1, 1)), NormL1(one(T), zeros(T, 1, 1)), ADMMSolver(; abstol = 0, reltol = 0))
    @test result.converged && result.status === :converged
    @test result.iterations == 1 && result.r_norm == result.s_norm == 0 && Θ == ones(T, 1, 1)
    @test ProximalSolvers.f_calls(result) == 1 && ProximalSolvers.grad_calls(result) == 0

    # At this penalty the logdet prox rounds back to Θ = 1 and the zero-weight
    # penalty copies its input, although the stationarity score |S₁₁ - 1/Θ₁₁| is 1.
    Θ, S = ones(T, 1, 1), fill(T(2), 1, 1)
    result = solve!(Θ, LogDetLoss(S), NormL1(one(T), zeros(T, 1, 1)), ADMMSolver(; ρ = T(2)^100))
    @test Θ == ones(T, 1, 1) && result.r_norm == result.s_norm == 0
    @test kkt_scores(Θ, S, zeros(T, 1, 1)).abs == 1
    @test !result.converged && result.status === :stagnated && ProximalSolvers.stagnated(result)
    @test result.iterations == 1 && result.prox_calls == 2

    # An off-diagonal score: from the start diag(1, 4), the logdet prox returns the
    # start (the asserted zero residuals check this), and the penalty keeps the zero
    # off-diagonal entry, while max(|S₁₂| - λ₀Λ₁₂, 0) is 3/10.
    start, S, Λ = Matrix(Diagonal(T[1, 4])), T[1 2/5; 2/5 1/4], T[0 1/10; 1/10 0]
    Θ = copy(start)
    result = solve!(Θ, LogDetLoss(S), NormL1(one(T), Λ), ADMMSolver(; ρ = T(2)^100))
    @test Θ == start && result.r_norm == result.s_norm == 0
    @test kkt_scores(Θ, S, Λ).abs ≈ 3/10
    @test !result.converged && result.status === :stagnated
    @test result.iterations == 1 && result.prox_calls == 2
  end
end

@testset "Graphical lasso: indefinite intermediate consensus iterate" begin
  for T in (Float32, Float64)
    S = T[2 1/2; 1/2 1]
    Λ = T[0 1/10; 1/10 0]
    rho = T(1/4)
    start, dual = Matrix{T}(I, 2, 2), T[-50 0; 0 -50]
    # Replay the two prox calls of the first iteration independently.
    γ = inv(Float64(rho))
    B = Float64.(start - dual) - γ * Float64.(S)
    E = eigen(Symmetric(B))
    x = E.vectors * Diagonal((E.values .+ sqrt.(E.values .^ 2 .+ 4γ)) ./ 2) * E.vectors'
    z = soft_threshold.(x + Float64.(dual), γ .* Float64.(Λ))
    @test eigmin(Symmetric(x)) > 1 && eigmin(Symmetric(z)) < -1

    # After one iteration the call budget ends the solve at that indefinite z, and
    # the return-point check raises its error.
    f, g = LogDetLoss(S), NormL1(one(T), Λ)
    Θ, u = copy(start), copy(dual)
    @test_throws final_error(T) solve!(Θ, f, g, ADMMSolver(; ρ = rho), ProximalOptions(prox_calls_limit = 2); u)
    @test samebits(Θ, start) && samebits(u, dual)

    # The same start continues through the indefinite iterate to an SPD optimum.
    method = accurate_method(T; ρ = rho)
    result = solve!(Θ, f, g, method, LONG; u)
    @test result.u === u
    check_accurate(result, Θ, S, effective(1, Λ), method)
  end
end

@testset "Graphical lasso: warm starts" begin
  for T in (Float32, Float64)
    S = T[2 1/2 1/4 0; 1/2 3/2 1/4 1/8; 1/4 1/4 1 3/8; 0 1/8 3/8 5/4]
    Λ = fill(T(1/10), 4, 4)
    Λ[diagind(Λ)] .= 0
    f, g = LogDetLoss(S), NormL1(one(T), Λ)
    method = accurate_method(T)
    fresh = solve!(Matrix{T}(I, 4, 4), f, g, method, LONG)
    check_accurate(fresh, fresh.minimizer, S, effective(1, Λ), method)

    # Continue an unfinished solve from its returned iterate, dual and penalty.
    first = solve!(Matrix{T}(I, 4, 4), f, g, method, ProximalOptions(maxiter = 3))
    @test first.status === :iteration_limit
    Θ, u = copy(first.minimizer), copy(first.u)
    warm = solve!(Θ, f, g, ADMMSolver(; ρ = first.ρ, abstol = solver_tolerance(T), reltol = solver_tolerance(T)), LONG; u)
    @test warm.minimizer === Θ && warm.u === u
    check_accurate(warm, Θ, S, effective(1, Λ), method)
    @test within(Θ, fresh.minimizer, T)

    # Restarting from a converged result takes few iterations and agrees with it
    # within the accuracy bound.
    Θ, u = copy(fresh.minimizer), copy(fresh.u)
    again = solve!(Θ, f, g, method, LONG; u)
    @test again.iterations <= 5 && again.u === u
    check_accurate(again, Θ, S, effective(1, Λ), method)
    @test within(Θ, fresh.minimizer, T)
  end
end

@testset "Graphical lasso: refusals leave caller buffers unchanged" begin
  function refuses(E, Θ, f, g, method = ADMMSolver(), options = ProximalOptions(); u = nothing, kwargs...)
    Θ0, u0 = deepcopy(Θ), deepcopy(u)
    @test_throws E solve!(Θ, f, g, method, options; u, kwargs...)
    @test samebits(Θ, Θ0)
    u === nothing || @test samebits(u, u0)
  end

  for T in (Float32, Float64)
    @testset "$T" begin
      S = T[2 1/2 0; 1/2 3/2 1/4; 0 1/4 1]
      Λ = T[0 1/5 1/5; 1/5 0 1/5; 1/5 1/5 0]
      Θ = T[1 1/8 0; 1/8 1 1/4; 0 1/4 1]
      u = T[0 1/16 0; 1/16 0 -1/16; 0 -1/16 0]
      f, g = LogDetLoss(S), NormL1(one(T), Λ)
      Λ0 = copy(Λ)

      # S is stored by LogDetLoss; break it after construction.
      for (index, value) in (((1, 2), T(1)), ((2, 2), T(NaN)), ((1, 1), T(Inf)))
        broken = LogDetLoss(S)
        broken.S[index...] = value
        refuses(ArgumentError, Θ, broken, g; u)
      end
      # Weights: asymmetric, nonzero diagonal, infinite, then negative and NaN
      # after a valid construction (NormL1 retains the weights by reference).
      for (index, value) in (((1, 2), T(1/4)), ((2, 2), T(1/10)), ((1, 3), T(Inf)))
        weights = copy(Λ)
        weights[index...] = value
        index == (1, 3) && (weights[3, 1] = value)
        refuses(ArgumentError, Θ, f, NormL1(one(T), weights); u)
      end
      for value in (T(-1/10), T(NaN))
        weights = copy(Λ)
        penalty = NormL1(one(T), weights)
        weights[1, 2] = weights[2, 1] = value
        refuses(ArgumentError, Θ, f, penalty; u)
      end
      # The start and the dual.
      asymmetric = copy(Θ)
      asymmetric[1, 2] += T(1/64)
      refuses(ArgumentError, asymmetric, f, g; u)
      refuses(ArgumentError, T[1 2 0; 2 1 0; 0 0 1], f, g; u)
      for value in (T(NaN), T(Inf))
        invalid = copy(Θ)
        invalid[2, 2] = value
        refuses(ArgumentError, invalid, f, g; u)
        invalid_dual = copy(u)
        invalid_dual[3, 3] = value
        refuses(ArgumentError, Θ, f, g; u = invalid_dual)
      end
      asymmetric_dual = copy(u)
      asymmetric_dual[1, 2] = T(1/8)
      refuses(ArgumentError, Θ, f, g; u = asymmetric_dual)
      refuses(DimensionMismatch, Θ, f, g; u = zeros(T, 2, 2))
      refuses(ArgumentError, Θ, f, g; u = zeros(T, 9))
      refuses(ArgumentError, Θ, f, g; u = zeros(T === Float32 ? Float64 : Float32, 3, 3))
      refuses(ArgumentError, Θ, f, g; u = view(copy(u), :, :))
      # Shapes.
      refuses(DimensionMismatch, Matrix{T}(I, 2, 2), f, g)
      refuses(DimensionMismatch, Θ, f, NormL1(one(T), zeros(T, 2, 2)))
      refuses(DimensionMismatch, zeros(T, 0, 0), f, g)
      refuses(DimensionMismatch, ones(T, 3, 2), f, g)
      # Functions, weights and levels.
      refuses(ArgumentError, Θ, LogDetLoss(S, 2), g)
      refuses(ArgumentError, Θ, f, NormL1(one(T)))
      refuses(ArgumentError, Θ, f, NormL1(one(T), vec(Λ)))
      refuses(ArgumentError, Θ, SqrNormL2(one(T)), g)
      refuses(ArgumentError, Θ, f, SqrNormL2(one(T)))
      refuses(ArgumentError, Θ, f, NormL1(Inf, Λ))
      refuses(ArgumentError, Θ, f, NormL1(1//3, Λ))
      # Aliasing among the start, the dual, S and the weights.
      refuses(ArgumentError, Θ, f, g; u = Θ)
      refuses(ArgumentError, Θ, f, g; u = g.w)
      refuses(ArgumentError, Θ, f, g; u = f.S)
      refuses(ArgumentError, f.S, f, g)
      # Weights identical to Θ are refused by the zero-diagonal check before the
      # alias check; the overlapping storage below reaches the alias check.
      refuses(ArgumentError, Θ, f, NormL1(one(T), Θ))
      graph = LogDetLoss(T[0 1; 1 0])
      refuses(ArgumentError, Matrix{T}(I, 2, 2), graph, NormL1(one(T), graph.S))
      backing = T[1, 0, 0, 2, 2, 0]
      GC.@preserve backing begin
        # Θ = [1 0; 0 2] and the weights [0 2; 2 0] share two entries.
        start = unsafe_wrap(Matrix{T}, pointer(backing), (2, 2))
        weights = unsafe_wrap(Matrix{T}, pointer(backing, 3), (2, 2))
        @test start == T[1 0; 0 2] && weights == T[0 2; 2 0]
        refuses(ArgumentError, start, LogDetLoss(T[2 0; 0 1]), NormL1(one(T), weights))
        @test backing == T[1, 0, 0, 2, 2, 0]
      end
      # Methods, settings and options.
      for method in (ADMMSolver(; α = 3/2), ADMMSolver(; α = 1/2), ADMMSolver(; adaptive = true))
        refuses(ArgumentError, Θ, f, g, method; u)
      end
      refuses(ArgumentError, Θ, f, g, ADMMSolver(; ρ = nextfloat(zero(T))); u)
      for (option, value) in ((:ftol, 0.0), (:xtol, 1e-4), (:gradtol, 0.0), (:f_calls_limit, 1),
                              (:store_trace, true), (:callback, identity))
        refuses(ArgumentError, Θ, f, g, ADMMSolver(), ProximalOptions(; option => value); u)
      end
      refuses(ArgumentError, Θ, f, g; u, unknown = 1)
      for wrapped in (view(copy(Θ), :, :), Symmetric(copy(Θ)), BigFloat.(Θ))
        refuses(ArgumentError, wrapped, f, g)
      end
      @test S == f.S && Λ == Λ0 && g.w === Λ
    end
  end

  # Mixed precision and settings that do not convert to Float32.
  S32, Λ32 = Float32[2 1/2; 1/2 1], Float32[0 1/4; 1/4 0]
  Θ32 = Matrix{Float32}(I, 2, 2)
  refuses(ArgumentError, Θ32, LogDetLoss(Float64.(S32)), NormL1(1f0, Λ32))
  refuses(ArgumentError, Θ32, LogDetLoss(S32), NormL1(1f0, Float64.(Λ32)))
  refuses(ArgumentError, Matrix(1.0I, 2, 2), LogDetLoss(S32), NormL1(1.0, Float64.(Λ32)))
  refuses(ArgumentError, Θ32, LogDetLoss(S32), NormL1(0.1, Λ32))
  for options in ((; ρ = 1e40), (; ρ = 1e-50), (; ρ = Float64(nextfloat(0.0f0))), (; abstol = 1e40), (; reltol = 1e-50))
    refuses(ArgumentError, Θ32, LogDetLoss(S32), NormL1(1f0, Λ32), ADMMSolver(; options...))
  end
end

@testset "Graphical lasso: numerical failures leave caller buffers unchanged" begin
  for T in (Float32, Float64)
    S = T[2 1/2; 1/2 1]
    Λ = T[0 1/10; 1/10 0]
    f, g = LogDetLoss(S), NormL1(one(T), Λ)
    start, dual = Matrix{T}(I, 2, 2), T[0 1/8; 1/8 0]
    # sqrt(p²) * abstol overflows.
    Θ, u = copy(start), copy(dual)
    @test_throws ErrorException solve!(Θ, f, g, ADMMSolver(; abstol = floatmax(T)); u)
    @test samebits(Θ, start) && samebits(u, dual)
    # z - u overflows in the first x-prox argument.
    Θ, u = fill(floatmax(T), 1, 1), fill(-floatmax(T), 1, 1)
    @test_throws ErrorException solve!(Θ, LogDetLoss(ones(T, 1, 1)), NormL1(one(T), zeros(T, 1, 1)), ADMMSolver(); u)
    @test samebits(Θ, fill(floatmax(T), 1, 1)) && samebits(u, fill(-floatmax(T), 1, 1))
    # With ρ = floatmax(T) and u = floatmax(T), the logdet prox of 1 - u rounds to
    # zero, which fails the Cholesky check of the logdet prox output.
    Θ, u = ones(T, 1, 1), fill(floatmax(T), 1, 1)
    @test_throws logdet_error(T) solve!(Θ, LogDetLoss(fill(T(2), 1, 1)), NormL1(one(T), zeros(T, 1, 1)),
                                        ADMMSolver(; ρ = floatmax(T)); u)
    @test samebits(Θ, ones(T, 1, 1)) && samebits(u, fill(floatmax(T), 1, 1))
  end
end

@testset "Graphical lasso: other solvers and iterates refuse it" begin
  for T in (Float32, Float64)
    S = T[2 1/2; 1/2 1]
    f, g = LogDetLoss(S), NormL1(one(T), T[0 1/10; 1/10 0])
    Θ = Matrix{T}(I, 2, 2)
    for (start, method) in ((Θ, CDSolver()), (vec(copy(Θ)), CDSolver()), (SparseIterate(vec(copy(Θ))), CDSolver()),
                            (BlockIterate(T, 4, [[1, 2], [3, 4]]), CDSolver()),
                            (vec(copy(Θ)), ProximalGradientDescent()), (vec(copy(Θ)), AccProxGradDescent()),
                            (vec(copy(Θ)), ADMMSolver()))
      @test_throws ArgumentError solve!(start, f, g, method)
    end
    @test Θ == Matrix{T}(I, 2, 2)
  end
end

@testset "Graphical lasso: penalties with declared abstract weight types" begin
  for T in (Float32, Float64)
    S = T[2 1/2 0; 1/2 3/2 1/4; 0 1/4 1]
    Λ = T[0 1/5 1/5; 1/5 0 1/5; 1/5 1/5 0]
    f, method = LogDetLoss(S), accurate_method(T)
    level = T(3/4)
    reference = solve!(Matrix{T}(I, 3, 3), f, NormL1(level, Λ), method, LONG)
    check_accurate(reference, reference.minimizer, S, effective(level, Λ), method)
    # The stored weights are a Matrix{T} although the declared weight type is wider.
    for g in (NormL1{T, AbstractMatrix{T}}(level, Λ), NormL1{T, Union{Nothing, Matrix{T}}}(level, Λ))
      @test g.w === Λ
      Θ = Matrix{T}(I, 3, 3)
      result = solve!(Θ, f, g, method, LONG)
      @test Θ == reference.minimizer && result.iterations == reference.iterations
      @test result.minimum == reference.minimum && result.status === :converged
    end
    # Weights stored as a view are refused before any write.
    for g in (NormL1(level, view(Λ, :, :)), NormL1{T, AbstractMatrix{T}}(level, view(Λ, :, :)))
      Θ, u = Matrix{T}(I, 3, 3), zeros(T, 3, 3)
      @test_throws ArgumentError solve!(Θ, f, g, method; u)
      @test samebits(Θ, Matrix{T}(I, 3, 3)) && samebits(u, zeros(T, 3, 3))
    end
  end
end

@testset "Vector ADMM results keep vector fields" begin
  for T in (Float32, Float64)
    z = zeros(T, 3)
    result = solve!(z, SqrNormL2(one(T), T[1, -2, 1/10]), NormL1(T(1/2)), ADMMSolver())
    @test result isa ADMMResults{T} && result isa ADMMResults{T, Vector{T}}
    @test result.minimizer === z && result.minimizer isa Vector{T} && result.u isa Vector{T}
    @test result.converged
    # The positional constructor with the element type alone takes the array type
    # from the minimizer and converts the scalar fields.
    direct = ADMMResults{T}(T[1, 2], 1/2, 3, true, 0.0, 0.0, 1e-6, 1e-6, T[0, 0], 1.0, 6, :converged)
    @test direct isa ADMMResults{T, Vector{T}}
    @test direct.minimizer == T[1, 2] && direct.minimum === T(1/2) && direct.u == T[0, 0]
    @test direct.iterations == 3 && direct.prox_calls == 6 && direct.status === :converged
  end
end

end
