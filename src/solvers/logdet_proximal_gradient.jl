using ProximalBase: gradient!, value_and_gradient!

function _logdet_pgd_preflight(Θ::Matrix{T}, f, g, ls, options) where T
  isone(f.w) || throw(ArgumentError("matrix PGD requires a LogDetLoss weight of one"))
  g.w isa Matrix{T} || throw(ArgumentError("matrix PGD requires dense $T NormL1 weights"))
  S, Λ = f.S, g.w
  !isempty(Θ) && size(Θ, 1) == size(Θ, 2) ||
    throw(DimensionMismatch("Θ must be a nonempty square matrix"))
  size(Θ) == size(S) == size(Λ) ||
    throw(DimensionMismatch("Θ, S and the NormL1 weights must have the same size"))
  λ0 = _admm_level(g.λ0, T, "the NormL1 level")
  _allfinite(Θ) && _allfinite(S) && _allfinite(Λ) ||
    throw(ArgumentError("Θ, S and the NormL1 weights must be finite"))
  _admm_issymmetric(Θ) && _admm_issymmetric(S) && _admm_issymmetric(Λ) ||
    throw(ArgumentError("Θ, S and the NormL1 weights must be exactly symmetric"))
  all(>=(zero(T)), Λ) ||
    throw(ArgumentError("the NormL1 weights must be nonnegative"))
  (_admm_mightalias(Θ, S) || _admm_mightalias(Θ, Λ) || _admm_mightalias(S, Λ)) &&
    throw(ArgumentError("Θ, S and the NormL1 weights must be independent buffers"))
  (options.allow_f_increases || options.store_trace || options.show_trace ||
   options.extended_trace || options.callback !== nothing || options.print_every != 1) &&
    throw(ArgumentError("matrix PGD requires default objective-increase, trace, callback and print settings"))
  ls.Lexact == Inf || throw(ArgumentError("matrix PGD requires Lexact = Inf"))
  α, β = T(ls.α), T(ls.β)
  zero(T) < α <= one(T) && isfinite(inv(α)) && zero(T) < β < one(T) ||
    throw(ArgumentError("matrix PGD requires 0 < α ≤ 1 with finite 1/α and 0 < β < 1 in $T"))
  C = λ0 .* Λ
  _allfinite(C) || throw(ArgumentError("matrix PGD requires finite effective NormL1 weights"))
  scratch = similar(Θ)
  _admm_passes_cholesky!(scratch, Θ) ||
    throw(ArgumentError("Θ must have a successful Cholesky factorization in $T"))
  # Finite Sᵢᵢ and Cᵢᵢ can have a sum that overflows in T. An infinite aᵢ would make every scale
  # dᵢⱼ of its row infinite, so that its violations score 0, and beside a zero root sⱼ it would give a
  # NaN scale (Inf·0); this check prevents both. Under round-to-nearest, sqrt(floatmax(T)) rounds below
  # the next power of two in Float32 and Float64 and its square is finite, so a product sᵢsⱼ of two
  # roots does not overflow. A product that underflows is below the unit floor of dᵢⱼ. A subnormal aᵢ
  # alone does not give dᵢⱼ = 1: in Float64, aᵢ = prevfloat(floatmin) with aⱼ = 0.75 floatmax gives
  # sᵢsⱼ ≈ sqrt(3).
  scales = Vector{T}(undef, size(S, 1))
  for i in axes(S, 1)
    a = S[i, i] + C[i, i]
    isfinite(a) || throw(ArgumentError("matrix PGD requires finite sums Sᵢᵢ + Cᵢᵢ of the diagonal data and effective weights in $T"))
    scales[i] = sqrt(abs(a))
  end
  C, scales, α, β, scratch
end

function _logdet_pgd_symmetrize!(G::Matrix{T}, S) where T
  _allfinite(G) || error("matrix PGD produced a nonfinite logdet gradient")
  @inbounds for j in axes(G, 2), i in 1:j-1
    a, b = G[i, j], G[j, i]
    # Include the scale of S in case of cancellation in S - inv(Θ).
    abs(a - b) / max(one(T), abs(a), abs(b), abs(S[i, j])) <= 8eps(T) ||
      error("matrix PGD received a logdet gradient with excessive asymmetry")
    G[i, j] = G[j, i] = a + (b - a) / 2
  end
  nothing
end

# The KKT violation of entry (i, j) from the gradient G = S - inv(Θ): at a nonzero Θᵢⱼ the
# distance of Gᵢⱼ from -Cᵢⱼ sign(Θᵢⱼ), at an exact zero the excess of |Gᵢⱼ| over Cᵢⱼ.
@inline _logdet_pgd_violation(θ, g, c) =
  iszero(θ) ? max(abs(g) - c, zero(g)) : abs(g + c * sign(θ))

# Knuth's TwoSum: s = fl(a + b) and e with a + b = s + e exactly when s and e are both finite. These
# operations are written without @fastmath, which permits reassociation, and without muladd, which
# permits contraction.
@inline function _logdet_pgd_two_sum(a, b)
  s = a + b
  bb = s - a
  s, (a - (s - bb)) + (b - bb)
end

# One side of the zero-entry violation, a + b + l with the sum a + b = u + lu from TwoSum. With a
# finite inverse entry, a sum u that overflows outward has the sign that makes the side negative, so
# the side cannot be violated. A side whose other terms are not finite takes its value `gside` from G.
@inline function _logdet_pgd_side(a, b, l, gside)
  u, lu = _logdet_pgd_two_sum(a, b)
  isfinite(u) || return oftype(u, -Inf)
  v = u + (lu + l)
  isfinite(v) ? v : gside
end

# The same violation from the stored Sᵢⱼ, the weight cᵢⱼ and the inverse entry wᵢⱼ = (Θ⁻¹)ᵢⱼ, without
# forming Sᵢⱼ ± cᵢⱼ. TwoSum gives x = Sᵢⱼ - wᵢⱼ as h + l when h and l are both finite. At a nonzero Θᵢⱼ the
# violation is |x + cᵢⱼ sign(Θᵢⱼ)|; at a zero it is the larger of x - cᵢⱼ, -x - cᵢⱼ and 0, each side
# computed from its own two-sum, and the final recombination rounds. Each sum keeps the cancellation of a
# large Sᵢⱼ against wᵢⱼ and cᵢⱼ. Starting from wᵢⱼ, the violation has a relative error of a few eps(T); the
# error of wᵢⱼ itself is separate. An entry whose h, l or result is not finite takes its value from G, and
# so does a side of a zero entry whose other terms are not finite.
@inline function _logdet_pgd_violation(θ, g, c, sij, w)
  h, l = _logdet_pgd_two_sum(sij, -w)
  isfinite(h) && isfinite(l) || return _logdet_pgd_violation(θ, g, c)
  if iszero(θ)
    upper = _logdet_pgd_side(h, -c, l, g - c)
    lower = _logdet_pgd_side(-h, -c, -l, -g - c)
    max(upper, lower, zero(upper))
  else
    h2, l2 = _logdet_pgd_two_sum(h, c * sign(θ))
    r = abs(h2 + (l + l2))
    isfinite(r) ? r : _logdet_pgd_violation(θ, g, c)
  end
end

# The score R = maxᵢⱼ rᵢⱼ / max(1, sᵢsⱼ) of PGD-08 from G, over the upper triangle, with a flag for
# entries whose computed violation may carry an absolute error above about 8eps(T) dᵢⱼ. Θ, G, C and S
# are symmetric by entrywise equality when this runs (G after `_logdet_pgd_symmetrize!`), so the
# entries below the diagonal equal those above it. Starting from the working inverse, the violation from
# G is a few roundings of terms bounded by mᵢⱼ = |Sᵢⱼ| + |Gᵢⱼ| + c̃ᵢⱼ, where c̃ᵢⱼ = Cᵢⱼ at a nonzero Θᵢⱼ or at
# a zero with |Gᵢⱼ| ≥ Cᵢⱼ/2, and c̃ᵢⱼ = 0 at a zero with |Gᵢⱼ| < Cᵢⱼ/2. There, the computed violation is 0
# and so is the true one unless the error of |Gᵢⱼ| reaches Cᵢⱼ/2. This is an estimate, not a proof: the
# absolute error of that arithmetic is about 2eps(T) mᵢⱼ, which for mᵢⱼ ≤ 4dᵢⱼ is at most about
# 8eps(T) dᵢⱼ, an eighth of the floor of g_tol. The error of the working inverse itself also enters G
# and the score, and this estimate does not cover it. An entry is uncertain if mᵢⱼ > 4dᵢⱼ; an
# overflowing mᵢⱼ is uncertain. The comparison uses mᵢⱼ/4, which does not overflow where 4dᵢⱼ could.
function _logdet_pgd_gform(Θ::Matrix{T}, S, G, C, scales) where T
  worst = zero(T)
  uncertain = false
  @inbounds for j in axes(Θ, 2), i in 1:j
    θ, g, c = Θ[i, j], G[i, j], C[i, j]
    d = max(one(T), scales[i] * scales[j])
    worst = max(worst, _logdet_pgd_violation(θ, g, c) / d)
    m = abs(S[i, j]) + abs(g) + ifelse(!iszero(θ) || 2abs(g) >= c, c, zero(T))
    uncertain |= m * T(0.25) > d
  end
  worst, uncertain
end

# The same score from the inputs and W = inv(Θ). Every entry is evaluated by
# `_logdet_pgd_violation(θ, g, c, S, W)`, with that method's fallback to G for an entry whose terms are
# not finite. Its violations equal those of the method above up to the rounding of G. The returned score
# is checked for finiteness.
function _logdet_pgd_wform(Θ::Matrix{T}, S, W, G, C, scales) where T
  worst = zero(T)
  @inbounds for j in axes(Θ, 2), i in 1:j
    violation = _logdet_pgd_violation(Θ[i, j], G[i, j], C[i, j], S[i, j], W[i, j])
    worst = max(worst, violation / max(one(T), scales[i] * scales[j]))
  end
  isfinite(worst) || error("matrix PGD produced a nonfinite KKT violation")
  Float64(worst)
end

# The score of a point Θ whose upper Cholesky factor, from `_admm_passes_cholesky!`, is in `scratch`.
# If the pass from G finds an uncertain entry, W = inv(Θ) is rebuilt in place from that factor and the
# score is the one from the inputs and W, which evaluates every entry (with the fallback to G for an entry
# whose terms are not finite). The factor is then overwritten, so a later use of `scratch` as a factor
# must factorize into it again; a trial that reaches its factorization does. The returned score is checked
# for finiteness: the score from G on the first path and the score from the inputs on the second. The
# score from G that the second path discards is not checked.
function _logdet_pgd_kkt!(scratch, Θ, S, G, C, scales)
  worst, uncertain = _logdet_pgd_gform(Θ, S, G, C, scales)
  if !uncertain
    isfinite(worst) || error("matrix PGD produced a nonfinite KKT violation")
    return Float64(worst)
  end
  W = LinearAlgebra.inv!(Cholesky(scratch, 'U', 0))
  _logdet_pgd_wform(Θ, S, W, G, C, scales)
end

function _logdet_pgd_trial_argument!(V, Θ, G, t)
  @inbounds for j in axes(Θ, 2), i in 1:j
    V[i, j] = V[j, i] = Θ[i, j] - t * G[i, j]
  end
  _allfinite(V)
end

function _logdet_pgd_majorizes(G, D, t::T, loss, next_loss) where T
  linear = dot(G, D)
  quadratic = (dot(D, D) / 2) / t
  model = loss + linear + quadratic
  isfinite(model) || return false
  # Scale the comparison slack by its terms so loss/model cancellation does
  # not shrink the allowance. This is a working-precision comparison.
  slack = 16eps(T) * max(one(T), abs(loss), abs(next_loss), abs(linear), quadratic)
  next_loss - model <= slack
end

# The shared driver reads the accepted objective and oracle counts. The
# matrix line search keeps all proposals in buffers separate from x.
mutable struct LogDetPGDState{T}
  x::Matrix{T}
  f_x::T
  g_x::T
  f_x_previous::T
  g_x_previous::T
  gradient::Matrix{T}
  argument::Matrix{T}
  trial::Matrix{T}
  displacement::Matrix{T}
  cholesky_scratch::Matrix{T}
  weights::Matrix{T}
  scales::Vector{T}
  step::T
  α::T
  β::T
  score::Float64
  x_change::Float64
  unchanged::Bool
  backtrack_steps::Int
  f_calls::Int
  grad_calls::Int
  prox_calls::Int
end

_strict_gradient_limits(::LogDetPGDState) = true
_gradient_tracing(::LogDetPGDState, options) = false
# The line search already enforces composite descent with a rounding allowance.
_stop_on_gradient_increase(::LogDetPGDState, options) = false
_rollback_gradient_step!(::LogDetPGDState) = nothing
_gradient_tolerance(::LogDetPGDState{T}, options) where T = max(options.gradtol, Float64(64eps(T)))
_state_normdiff(state::LogDetPGDState) = state.x_change
g_residual(state::LogDetPGDState) = state.score
_stagnated(state::LogDetPGDState, options) =
  state.unchanged && state.score > _gradient_tolerance(state, options)

function convergence_assessment(state::LogDetPGDState, f, g, options)
  objective = state.f_x + state.g_x
  previous = state.f_x_previous + state.g_x_previous
  stationary = state.score <= _gradient_tolerance(state, options)
  x_converged = stationary && state.x_change < options.xtol
  f_converged = stationary && options.ftol > 0 &&
                f_residual(objective, previous, options.ftol) < options.ftol
  x_converged, f_converged, stationary, stationary, objective > previous
end

function _gradient_step!(state::LogDetPGDState{T}, f, g, method, options, t0) where T
  Θ, G, V, Z, D = state.x, state.gradient, state.argument, state.trial, state.displacement
  loss = state.f_x
  objective = loss + state.g_x
  t = min(one(T), state.step / state.α)
  for attempt in 1:64
    isfinite(t) && t > zero(T) && isfinite(inv(t)) && inv(t) > zero(T) ||
      error("matrix PGD line search requires a finite positive step and reciprocal")
    state.backtrack_steps += 1
    if _logdet_pgd_trial_argument!(V, Θ, G, t)
      state.prox_calls += 1
      prox!(Z, g, V, t)
      if _admm_passes_cholesky!(state.cholesky_scratch, Z)
        state.f_calls += 1
        next_loss, penalty = f(Z), g(Z)
        next_objective = next_loss + penalty
        if isfinite(next_objective)
          D .= Z .- Θ
          slack = 16eps(T) * max(one(T), abs(next_objective), abs(objective))
          if next_objective - objective <= slack && _logdet_pgd_majorizes(G, D, t, loss, next_loss)
            state.grad_calls += 1
            gradient!(G, f, Z)
            _logdet_pgd_symmetrize!(G, f.S)
            # The check of Z above factored it into `scratch`, and no later trial has written to it,
            # so it holds the upper factor of Z. An uncertain score overwrites it with inv(Z); the
            # next trial that reaches its factorization writes it again.
            state.score = _logdet_pgd_kkt!(state.cholesky_scratch, Z, f.S, G, state.weights,
                                          state.scales)
            state.x_change = Float64(norm(D))
            state.unchanged = Z == Θ
            state.f_x_previous, state.g_x_previous = state.f_x, state.g_x
            state.f_x, state.g_x = next_loss, penalty
            state.step = t
            copyto!(Θ, Z)
            return true
          end
        end
      end
    end
    attempt == 64 && error("matrix PGD line search failed after 64 trials")
    (_gradient_call_limit(state, options) || _gradient_time_limit(t0, options)) && return false
    next_t = t * state.β
    next_t < t || error("matrix PGD line search could not reduce the step")
    t = next_t
  end
end

function solve!(Θ::Matrix{T}, f::LogDetLoss{T}, g::NormL1, method::ProximalGradientDescent,
                options::ProximalOptions = ProximalOptions(); kwargs...) where T
  _check_keywords(kwargs)
  start = time_ns()
  C, scales, α, β, scratch = _logdet_pgd_preflight(Θ, f, g, method.ls, options)
  G = similar(Θ)
  loss, penalty = value_and_gradient!(G, f, Θ), g(Θ)
  isfinite(loss + penalty) || throw(ArgumentError("matrix PGD requires a finite starting objective"))
  _logdet_pgd_symmetrize!(G, f.S)
  # `scratch` holds the upper factor of Θ from the preflight check: nothing has written to it since.
  score = _logdet_pgd_kkt!(scratch, Θ, f.S, G, C, scales)
  state = LogDetPGDState(Θ, loss, penalty, T(NaN), T(NaN), G, similar(Θ), similar(Θ),
                         similar(Θ), scratch, C, scales, one(T), α, β, score, NaN, false,
                         0, 1, 1, 0)
  _solve_gradient!(state, f, g, method, options, start)
end
