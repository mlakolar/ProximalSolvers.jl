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
  all(>=(zero(T)), Λ) && all(i -> iszero(Λ[i, i]), axes(Λ, 1)) ||
    throw(ArgumentError("the NormL1 weights must be nonnegative with zero diagonal"))
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
  C, max(one(T), maximum(abs, S), maximum(C)), α, β, scratch
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

function _logdet_pgd_kkt(Θ, G, C, scale)
  worst = zero(eltype(Θ))
  @inbounds for i in eachindex(Θ, G, C)
    violation = iszero(Θ[i]) ? max(abs(G[i]) - C[i], zero(worst)) :
                               abs(G[i] + C[i] * sign(Θ[i]))
    worst = max(worst, violation)
  end
  isfinite(worst) || error("matrix PGD produced a nonfinite KKT violation")
  Float64(worst / scale)
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
  scale::T
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
            state.score = _logdet_pgd_kkt(Z, G, state.weights, state.scale)
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
  C, scale, α, β, scratch = _logdet_pgd_preflight(Θ, f, g, method.ls, options)
  G = similar(Θ)
  loss, penalty = value_and_gradient!(G, f, Θ), g(Θ)
  isfinite(loss + penalty) || throw(ArgumentError("matrix PGD requires a finite starting objective"))
  _logdet_pgd_symmetrize!(G, f.S)
  score = _logdet_pgd_kkt(Θ, G, C, scale)
  state = LogDetPGDState(Θ, loss, penalty, T(NaN), T(NaN), G, similar(Θ), similar(Θ),
                         similar(Θ), scratch, C, scale, one(T), α, β, score, NaN, false,
                         0, 1, 1, 0)
  _solve_gradient!(state, f, g, method, options, start)
end
