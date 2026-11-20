module PGDGraphicalLassoTests

using LinearAlgebra: Diagonal, I, Symmetric, SymTridiagonal, cholesky, diag, diagind, dot, eigmin, issuccess, logdet
using ProximalBase: LogDetLoss, NormL1, NormLinf
using ProximalSolvers: ADMMSolver, AccProxGradDescent, LineSearches, OptimizationResults, ProximalGradientDescent, ProximalOptions, solve!
using Random: Xoshiro, randn
using Test

identity_matrix(T, p) = Matrix{T}(I, p, p)
function weights(T, p, level)
  W = fill(T(level), p, p)
  W[diagind(W)] .= 0
  W
end
# Symmetric weights with off-diagonal entries `level` and the given diagonal entries.
function full_weights(T, p, level, diagonal)
  W = fill(T(level), p, p)
  W[diagind(W)] .= T.(diagonal)
  W
end
offdiagonal(p) = [(i, j) for j in 1:p for i in 1:p if i != j]
soft(x, level) = sign(x) * max(abs(x) - level, 0)
# The effective weights λ₀Λ of the penalty λ₀ Σᵢⱼ Λᵢⱼ|Θᵢⱼ|, in BigFloat.
effective(g) = BigFloat(g.λ0) .* BigFloat.(g.w)
target(::Type{Float32}) = 5e-4
target(::Type{Float64}) = 1e-8
pg_options() = ProximalOptions(; maxiter=20000, gradtol=5e-10, ftol=0)

# Symmetric Gaussian elimination without pivoting on the upper triangle of a symmetric
# rational matrix. The matrix is positive definite if and only if every pivot is positive.
function positive_definite_exactly(M)
  M = copy(M)
  p = size(M, 1)
  for k in 1:p
    M[k, k] > 0 || return false
    for j in k+1:p
      factor = M[k, j] / M[k, k]
      for i in k+1:j
        M[i, j] -= M[k, i] * factor
      end
    end
  end
  true
end

# Use BigFloat independently of PB and the solver's working-precision gradient.
# The dual candidate W is built in BigFloat with Wᵢᵢ = Sᵢᵢ + Cᵢᵢ and, off the diagonal,
# Wᵢⱼ = Sᵢⱼ + clamp((Θ⁻¹ - S)ᵢⱼ, -Cᵢⱼ, Cᵢⱼ). A symmetric W ≻ 0 with
# |Wᵢⱼ - Sᵢⱼ| ≤ Cᵢⱼ for all entries, diagonal included, gives logdet(W) + p as a lower
# bound on the objective over Θ ≻ 0. The helper returns a gap only when W == W' holds for
# the stored BigFloat entries, the box and positive definiteness hold in rational
# arithmetic, and the BigFloat Cholesky factorization of W succeeds. The gap then uses
# the BigFloat logdet, a numerical estimate of that bound. Otherwise the gap is NaN,
# which fails the gap assertions of the accuracy fixtures.
function independent(Θ, S, g)
  X, A, C = BigFloat.(Θ), BigFloat.(S), effective(g)
  p = size(X, 1)
  factor = cholesky(Symmetric(X))
  inverse = inv(factor)
  G = A - inverse
  scale = max(big(1), maximum(abs, A), maximum(C))
  score = maximum(eachindex(G)) do i
    iszero(X[i]) ? max(abs(G[i]) - C[i], 0) : abs(G[i] + sign(X[i]) * C[i])
  end / scale
  trace, ld, penalty = dot(A, X), logdet(factor), dot(C, abs.(X))
  primal = trace - ld + penalty
  W = copy(A)
  for i in 1:p
    W[i, i] = A[i, i] + C[i, i]
  end
  for j in 2:p, i in 1:j-1
    W[i, j] = W[j, i] = A[i, j] + clamp(inverse[i, j] - A[i, j], -C[i, j], C[i, j])
  end
  exact(x) = Rational{BigInt}(x)
  certified = W == W' && all(abs(exact(W[i, j]) - exact(A[i, j])) <= exact(C[i, j])
                             for j in 1:p for i in 1:p) &&
              positive_definite_exactly(exact.(W))
  dual_factor = certified ? cholesky(Symmetric(W); check=false) : nothing
  gap = certified && issuccess(dual_factor) ? primal - (logdet(dual_factor) + p) : big(NaN)
  (; score, primal, gap, scale_objective=1 + abs(trace) + abs(ld) + penalty)
end

# Θ is the point that solve! returns for (S, g). With `original=(S0, g0)`, the
# independent reference judges it against (S0, g0) instead.
function check_solution!(Θ, S, g; method=ProximalGradientDescent(), reference=nothing, original=nothing)
  f = LogDetLoss(S)
  S_snapshot, W_snapshot = copy(f.S), copy(g.w)
  r = solve!(Θ, f, g, method, pg_options())
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
  d = independent(Θ, original === nothing ? S : original[1], original === nothing ? g : original[2])
  @test d.score <= target(T)
  # The score comparison runs when `original === nothing`. The reported score is
  # normalized by the solved problem's S and weights, which can differ from the original's.
  original === nothing && @test abs(d.score - r.g_residual) <= 32eps(T)
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

@testset "Matrix PGD analytic optima with diagonal weights" begin
  for T in (Float32, Float64)
    @testset "$T" begin
      # p = 1: Θ* = 1/(S₁₁ + C₁₁). Both (λ₀, Λ₁₁) pairs give C₁₁ = 1/4.
      for s in (T(1/2), T(4)), (λ0, w) in ((1/2, T(1/2)), (1/4, T(1)))
        g = NormL1(λ0, fill(w, 1, 1))
        check_solution!(ones(T, 1, 1), fill(s, 1, 1), g;
                        reference=fill(inv(BigFloat(s) + only(effective(g))), 1, 1))
      end

      # Diagonal S with heterogeneous diagonal weights, one of them zero, and
      # nonnegative off-diagonal weights, some of them zero: Θ* = diag(1 ./ (Sᵢᵢ + Cᵢᵢ)).
      S = Matrix(Diagonal(T[1/2, 1, 2, 4]))
      Λ = T[1/8 0 1/4 1/16; 0 0 1/8 0; 1/4 1/8 1/4 1/2; 1/16 0 1/2 3/8]
      g = NormL1(1, Λ)
      Θ = identity_matrix(T, 4)
      check_solution!(Θ, S, g; reference=Diagonal(inv.(BigFloat.(diag(S)) .+ diag(effective(g)))))
      @test all(iszero(Θ[i, j]) for (i, j) in offdiagonal(4))

      # p = 2: W*ᵢᵢ = Sᵢᵢ + Cᵢᵢ, W*₁₂ = soft(S₁₂, C₁₂) and Θ* = inv(W*), with C₁₂ = 1/4
      # and |S₁₂| below, at or above the threshold C₁₂, for two (λ₀, Λ) decompositions of C.
      Λ = T[1/8 1/4; 1/4 3/8]
      for (name, s12) in (("below", 1/8), ("at", 1/4), ("above, positive", 3/4), ("above, negative", -3/4))
        S = T[1 s12; s12 2]
        for (λ0, Λcase) in ((1, Λ), (1/2, 2Λ))
          g = NormL1(λ0, Λcase)
          C = effective(g)
          W = BigFloat.(S) + Diagonal(diag(C))
          W[1, 2] = W[2, 1] = soft(BigFloat(s12), C[1, 2])
          @test issuccess(cholesky(Symmetric(W); check=false))
          Θ = identity_matrix(T, 2)
          check_solution!(Θ, S, g; reference=inv(W))
          if abs(s12) <= C[1, 2]
            @test iszero(Θ[1, 2])
          else
            @test sign(Θ[1, 2]) == -sign(s12)
          end
        end
      end

      # A zero level with stored positive diagonal weights removes the penalty: Θ* = inv(S).
      S = T[2 0.5 0; 0.5 1 0.125; 0 0.125 1.25]
      check_solution!(identity_matrix(T, 3), S, NormL1(0, full_weights(T, 3, 1/8, T[1/8, 1/4, 3/8]));
                      reference=inv(BigFloat.(S)))

      # Zero off-diagonal weights with positive diagonal weights: Θ* = inv(S + Diagonal(C)).
      g = NormL1(1, Matrix(Diagonal(T[1/8, 1/4, 3/8])))
      check_solution!(identity_matrix(T, 3), S, g;
                      reference=inv(BigFloat.(S) + Diagonal(diag(effective(g)))))

      # Heterogeneous full weights with some zero entries. This case has no analytic
      # reference; it is checked by the KKT score and the dual bound.
      S = T[2 5/8 1/16; 5/8 3/2 0; 1/16 0 1]
      Λ = T[1/4 1/4 3/8; 1/4 1/2 0; 3/8 0 3/4]
      check_solution!(identity_matrix(T, 3), S, NormL1(1/2, Λ))

      # Off-diagonal effective weights above the largest off-diagonal |Sᵢⱼ|, so that
      # Θ* = diag(1 ./ (Sᵢᵢ + Cᵢᵢ)) with Sᵢᵢ + Cᵢᵢ > 0.
      S = T[2 1/2 1/4; 1/2 3/2 1/8; 1/4 1/8 1]
      g = NormL1(1, full_weights(T, 3, 5/8, T[1/8, 1/4, 3/8]))
      Θ = identity_matrix(T, 3)
      check_solution!(Θ, S, g; reference=Diagonal(inv.(BigFloat.(diag(S)) .+ diag(effective(g)))))
      @test all(iszero(Θ[i, j]) for (i, j) in offdiagonal(3))
    end
  end
end

# The gap is withheld when the dual candidate is not certified.
@testset "Matrix PGD independent reference withholds an uncertified gap" begin
  # Exact positive definiteness: a positive-definite matrix, a singular one, and one
  # whose determinant 1 - (1 + ε)² is negative for ε = 2⁻³⁰⁰.
  rational(M) = Rational{BigInt}.(M)
  ε = 1 // big(2)^300
  @test positive_definite_exactly(rational([2 1 0; 1 2 1; 0 1 2]))
  @test !positive_definite_exactly(rational([5 5; 5 5]))
  @test !positive_definite_exactly([one(ε) 1+ε; 1+ε one(ε)])
  # W = S + C = -3/2 is not positive definite, so no bound is reported.
  d = independent(ones(1, 1), fill(-2.0, 1, 1), NormL1(1, fill(0.5, 1, 1)))
  @test isfinite(d.primal) && isnan(d.gap)
  # S = [9/2 5; 5 9/2] and C = I/2 give W = fill(5, 2, 2), which is singular. A BigFloat
  # Cholesky factorization of it can succeed on rounded pivots. The objective P is
  # unbounded below along Θ = I + t[1 -1; -1 1], where P = 10 - log(1 + 2t), so no
  # finite lower bound exists.
  d = independent(Matrix(1.0I, 2, 2), [4.5 5; 5 4.5], NormL1(1.0, [0.5 0.0; 0.0 0.5]))
  @test d.primal == 10 && isnan(d.gap)
  # W = 3/2 is positive definite, and Θ = 2/3 is within rounding of the minimizer.
  d = independent(fill(2/3, 1, 1), ones(1, 1), NormL1(1, fill(0.5, 1, 1)))
  @test -big"1e-60" <= d.gap <= big"1e-30"
end

function seeded_covariance(p, n)
  truth = Matrix(SymTridiagonal(fill(1.5, p), fill(-0.35, p - 1)))
  Σ = inv(truth)
  X = randn(Xoshiro(444 + n), n, p) * cholesky(Symmetric(Σ)).U
  X .-= sum(X; dims=1) ./ n
  Matrix(Symmetric(X' * X / n))
end

@testset "Matrix PGD seeded and ADMM cross-check" begin
  for (p, n) in ((10, 150), (30, 300), (30, 20))
    S64 = seeded_covariance(p, n)
    for T in (Float32, Float64)
      @testset "p=$p, n=$n, $T" begin
        S = T.(S64)
        g = NormL1(one(T), weights(T, p, n < p ? 0.25 : 0.12))
        Θ = identity_matrix(T, p)
        # At the larger sizes, hold the accepted step between iterations.
        # The smaller fixture exercises step growth with the default settings.
        method = p == 10 ? ProximalGradientDescent() :
                 ProximalGradientDescent(; ls=LineSearches.BackTracking(α=1))
        d = check_solution!(Θ, S, g; method)
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
end

# Positive diagonal weights on the seeded fixtures. In exact arithmetic, direct PGD,
# PGD on the shifted covariance S + Diagonal(λ₀ diag(Λ)) with zero-diagonal weights,
# and (at p = 10) direct ADMM have the same minimizer. Each point is judged against the
# original S, Λ and λ₀ in BigFloat. The shifted covariance is formed in T, so the
# objectives of the routes can differ by its rounding.
@testset "Matrix PGD diagonal weights: direct, shifted and ADMM routes" begin
  for (p, n) in ((10, 150), (30, 20))
    S64 = seeded_covariance(p, n)
    for T in (Float32, Float64)
      @testset "p=$p, n=$n, $T" begin
        S = T.(S64)
        g = NormL1(one(T), full_weights(T, p, n < p ? 0.25 : 0.12, T[(1 + mod(i, 4)) / 16 for i in 1:p]))
        @test all(>(0), diag(g.w))
        method = p == 10 ? ProximalGradientDescent() :
                 ProximalGradientDescent(; ls=LineSearches.BackTracking(α=1))
        direct = check_solution!(identity_matrix(T, p), S, g; method)

        Sshift, Λzero = copy(S), copy(g.w)
        for i in 1:p
          Sshift[i, i] += T(g.λ0) * g.w[i, i]
          Λzero[i, i] = zero(T)
        end
        shifted = check_solution!(identity_matrix(T, p), Sshift, NormL1(g.λ0, Λzero); method,
                                  original=(S, g))
        @test abs(direct.primal - shifted.primal) <= target(T) * max(1, abs(direct.primal))

        if p == 10
          other = identity_matrix(T, p)
          tol = T === Float32 ? 1e-6 : 1e-11
          result = solve!(other, LogDetLoss(S), g, ADMMSolver(; abstol=tol, reltol=tol),
                          ProximalOptions(; maxiter=5000))
          @test result.converged && all(isfinite, other) && other == other'
          ref = independent(other, S, g)
          @test ref.score <= target(T)
          @test -big"1e-60" <= ref.gap <= target(T) * max(1, abs(ref.primal))
          @test abs(direct.primal - ref.primal) <= target(T) * max(1, abs(direct.primal))
          @test abs(shifted.primal - ref.primal) <= target(T) * max(1, abs(shifted.primal))
        end
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
    # Positive diagonal weights are accepted. With C = ones, W*₁₁ = W*₂₂ = 2, and
    # S₁₂ = 1/8 lies within the threshold C₁₂ = 1, so W*₁₂ = 0 and Θ* = I/2.
    check_solution!(identity_matrix(T, 2), T[1 1/8; 1/8 1], NormL1(1, ones(T, 2, 2));
                    reference=Diagonal(fill(inv(big(2)), 2)))
    refused(ArgumentError, Θ, f, NormL1(1, T[0 0; 0 Inf]))
    refused(ArgumentError, Θ, f, NormL1(1, T[0 1; 2 0]))
    refused(ArgumentError, Θ, f, NormL1(1, T[0 Inf; Inf 0]))
    refused(ArgumentError, Θ, f, NormL1(Inf, g.w))
    refused(ArgumentError, Θ, f, NormL1(1//3, g.w))
    refused(ArgumentError, Θ, f, NormL1(floatmax(T), weights(T, 2, 2)))
    refused(ArgumentError, Θ, f, NormL1(floatmax(T), T[2 0; 0 0]))
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
    # The NormL1 constructor refuses a negative weight, so these cases change the stored
    # array after construction.
    for i in 1:2, bad in (-T(1/2), T(NaN))
      mod_weights = copy(g.w)
      penalty = NormL1(1, mod_weights)
      mod_weights[i, i] = bad
      refused(ArgumentError, Θ, f, penalty)
    end
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
    @test_throws ErrorException("matrix PGD line search failed after 64 trials") solve!(z, f, g, ProximalGradientDescent(; ls), pg_options())
    @test z ≈ accepted && z != start && eigmin(Symmetric(z)) > 0

    # Interrupt the second search after its first rejected trial. Its work
    # counts, while the result diagnostics still describe the accepted step.
    snapshot = copy(z)
    z = copy(start)
    r = solve!(z, f, g, ProximalGradientDescent(; ls), ProximalOptions(prox_calls_limit=2))
    @test r.call_limit_reached && !r.converged && !r.stagnated
    @test (r.iterations, r.backtrack_steps, r.prox_calls, r.f_calls, r.grad_calls) == (1, 2, 2, 3, 2)
    @test r.minimizer === z && z == snapshot && r.minimum == f(z)
    @test r.x_residual == abs(only(z) - only(start))
    @test r.f_residual ≈ abs(f(z) - f(start)) / abs(f(z)) rtol=eps(T)

    f = LogDetLoss(array(4))
    z = array(1)
    @test_throws ErrorException("matrix PGD line search failed after 64 trials") solve!(z, f, g, ProximalGradientDescent(; ls), pg_options())
    @test z == array(1)
    tiny = LineSearches.BackTracking(α=one(T), β=nextfloat(zero(T)))
    @test_throws ErrorException("matrix PGD line search requires a finite positive step and reciprocal") solve!(z, f, g, ProximalGradientDescent(; ls=tiny), pg_options())
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

    # A diagonal threshold can zero a proposal's diagonal. At Θ = 1, G = 1/4 - 1 = -3/4
    # and C = 2. The trial V = 1 - tG is 7/4 at t = 1, below the threshold tC = 2,
    # so the prox output is zero and fails Cholesky before any loss call. At
    # t = β = 1/2, V = 11/8 exceeds tC = 1, and Z = 3/8 is positive definite and
    # passes both comparisons.
    S, g = array(1/4), NormL1(one(T), array(2))
    f, z = LogDetLoss(S), array(1)
    G = only(f.S) - inv(only(z))
    V1, V2 = only(z) - G, only(z) - G / 2
    @test (G, V1, V2) == (-3/4, 7/4, 11/8) && V1 < 1 * 2 && V2 > 1/2 * 2
    r = solve!(z, f, g, m, ProximalOptions(time_limit=0))
    @test !r.converged && z == array(1) && r.g_residual == 5/8
    @test (r.iterations, r.backtrack_steps, r.prox_calls, r.f_calls, r.grad_calls) == (0, 0, 0, 1, 1)
    r = solve!(z, f, g, m, ProximalOptions(prox_calls_limit=2))
    @test r.call_limit_reached && !r.converged && z == array(3/8) && r.x_residual == 5/8
    @test (r.iterations, r.backtrack_steps, r.prox_calls, r.f_calls, r.grad_calls) == (1, 2, 2, 2, 2)
    @test r.g_residual ≈ 5/24 rtol=64eps(T)
    check_solution!(array(1), S, g; reference=fill(inv(BigFloat(1/4) + 2), 1, 1))
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
