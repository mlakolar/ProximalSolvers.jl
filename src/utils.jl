###################################
# tracing based on optim package
# removed grad norm field
#

# Records iteration `iteration` and calls the callback; returns whether it stopped the solve.
function trace!(tr, state, iteration, options)
    dt = Dict()
    if options.extended_trace
        dt["x"] = _copy(state.x)
        extended_trace!(dt, state)
    end
    os = eltype(tr)(iteration, state.f_x + state.g_x,
                    _state_normdiff(state) / _state_norm(state, state.x), state.L, dt)
    options.store_trace && push!(tr, os)
    options.show_trace && mod(iteration, options.print_every) == 0 && show(os)
    options.callback !== nothing && iteration % options.print_every == 0 || return false
    options.store_trace ? options.callback(tr) : options.callback(os)
end

extended_trace!(dt, state::ProximalGradientDescentState) = dt["grad_f(x)"] = _copy(state.grad_f_x)

# The objective-change residual of the relative objective test and of the result:
# |F - F'| / |F|, evaluated in Float64. It is 0 when F == F' (an explicit branch: 0/0 is NaN),
# so it is 0 for F = F' = 0, and Inf for F = 0 != F'. There is no absolute term in the
# denominator, so a small objective is judged on its own scale. `f_tol` is not used: the value
# is the same whether the test is on (f_tol > 0) or off (f_tol = 0, where it only reports).
function f_residual(f_x, f_x_previous, f_tol)
  change = Float64(abs(f_x-f_x_previous))
  iszero(change) ? 0.0 : change / abs(Float64(f_x))
end
g_residual(state::ProximalGradientDescentState) = _maxabs_residual(state.grad_f_x, state.grad_f_x_previous, state.delta_x, state.L)
function convergence_assessment(
  state::Union{ProximalGradientDescentState, AccProxGradDescentState},
  f, g, options::ProximalOptions
  )

  x_converged, f_converged, grad_converged, f_increased = false, false, false, false

  norm_x = _state_norm(state, state.x)
  norm_dx = _state_norm(state, state.delta_x)

  # With ftol = 0 only, an accepted iterate that equals the previous one elementwise
  # is no progress, not convergence: it satisfies neither the x test nor the gradient
  # test. The elementwise comparison runs only when the norm of the difference is 0,
  # because a positive norm already shows a difference and a norm that rounds to 0
  # does not show equality.
  stalled = iszero(options.ftol) && iszero(norm_dx) && _unchanged(state.x, state.x_previous)

  if !stalled && norm_dx < options.xtol * max( norm_x, 1. )
    x_converged = true
  end

  # Relative Tolerance. ftol = 0 switches off both objective tests.
  fval = state.f_x + state.g_x
  fval_prev = state.f_x_previous + state.g_x_previous
  if !iszero(options.ftol) &&
        (f_residual(fval, fval_prev, options.ftol) < options.ftol ||
         abs(fval - fval_prev) < eps(abs(fval)+abs(fval_prev)))
    f_converged = true
  end

  if fval > fval_prev
    f_increased = true
  end

  # evaluated on a stalled iteration too, so max_residual is updated as without the rule
  grad_converged = gradient_converged!(state, options) && !stalled

  # A stop proposed by any of the three tests counts only if the accepted iterate passes the
  # stationarity check (_stationary!); otherwise the solve continues. The check's prox (and APG's
  # gradient at x) are counted here, before the call limits are compared in _solve_gradient!.
  if (x_converged || f_converged || grad_converged) && !_stationary!(state, f, g, options)
    x_converged, f_converged, grad_converged = false, false, false
  end

  converged = x_converged || f_converged || grad_converged

  return x_converged, f_converged, grad_converged, converged, f_increased
end
function gradient_converged!(state::ProximalGradientDescentState{T}, options::ProximalOptions) where T
  residual = g_residual(state)
  state.max_residual = max(state.max_residual, residual)
  # (xhat - x) / τ = -(L (x - x_previous) + ∇f(x_previous))
  subgrad = _maxabs_axpy(state.L, state.delta_x, state.grad_f_x_previous)
  _gradient_test(state, options, residual, max(_norm_inf(state.grad_f_x), subgrad))
end

# The gradient test of PGD and APG, for the residual r of the iteration, the largest residual so
# far m = state.max_residual and the scale N of the gradient and the proximal step. It holds
# when r < gradtol m or r < gradtol N, with no absolute term added to m or N (a test on a scale
# of 0 does not hold), and only against a scale that exceeds ρ = L eps(T) ‖x‖∞, the rounding
# resolution of L x. A residual that is zero because a step rounded to nothing does not hold
# when ρ is at least as large as both m and N.
function _gradient_test(state::Union{ProximalGradientDescentState{T}, AccProxGradDescentState{T}},
                        options::ProximalOptions, residual, N) where T
  ρ = _resolution(state)
  m = state.max_residual
  (residual < options.gradtol * m && ρ < m) || (residual < options.gradtol * N && ρ < N)
end

# ρ = L eps(T) ‖x‖∞, the rounding resolution of L x at the accepted x
_resolution(state) = state.L * eps(eltype(state.x)) * _norm_inf(state.x)

# The stationarity check of a proposed stop, shared by every penalty of PGD and APG. At the accepted x, with
# t = 1/L (the accepted curvature), it forms u = x - t ∇f(x) and p = prox_{t g}(u) with the iterations'
# value_and_prox! call, and r = ‖x - p‖∞ / t, the ∞-norm of the proximal-gradient mapping G_t(x). The stop is
# kept when r < τ S, with S = max(‖∇f(0)‖∞, ‖∇f(x)‖∞) and τ = max(gradtol, 64 eps(T)). It is refused when t is
# not finite and positive, S or r is not finite, τ S is below floatmin(T), τ S does not exceed the rounding
# resolution L eps(T) ‖x‖∞ of the gradient test, or the step t τ S at the threshold is below floatmin(T)/eps(T)
# (a step that subnormal rounding can lose at x = 0). The prox counts in prox_calls; APG's gradient at x
# (_gradient_at_x!) counts in grad_calls. u goes to xhat and p to delta_x, which is then restored to
# x - x_previous. With a small accepted L the step t is large and G_t a weaker measure of stationarity than
# with the true curvature. A kept stop is a working-precision indication, not a certificate.
function _stationary!(state, f, g, options::ProximalOptions)
  T = eltype(state.x)
  t = one(T) / state.L
  λmax = _lambda_max!(state)       # first: it uses xhat, which APG's gradient below also uses
  grad = _gradient_at_x!(state, f)
  S = max(λmax, _norm_inf(grad))
  _step!(state.xhat, state.x, grad, state.L)   # elementwise, so APG's grad === xhat is safe
  value_and_prox!(state.delta_x, g, state.xhat, t)
  state.prox_calls += 1
  r = _norm_diff(state.x, state.delta_x, Inf) / t
  _sub!(state.delta_x, state.x, state.x_previous)
  threshold = T(max(options.gradtol, 64 * Float64(eps(T)))) * S
  isfinite(t) && t > 0 && isfinite(S) && isfinite(r) && threshold >= floatmin(T) &&
    threshold > _resolution(state) && t * threshold >= floatmin(T) / eps(T) && r < threshold
end

# ‖∇f(0)‖∞ = α‖Xᵀy‖∞, computed at most once per solve, at the first check (state.λmax is negative
# until then), with the arithmetic of the gradient oracle at x = 0, in state.xhat (written before it
# is read at every use in the iterations; the convergence tests and the trace do not read it). It is
# not a counted call.
function _lambda_max!(state)
  state.λmax < 0 || return state.λmax
  m = state.model
  mul!(state.xhat, transpose(m.X), m.Y)
  state.xhat .*= m.α
  state.λmax = _norm_inf(state.xhat)
end

# ∇f at the accepted x. PGD holds it.
_gradient_at_x!(state::ProximalGradientDescentState, f) = state.grad_f_x

# APG holds ∇f(y), not ∇f(x). It forms ∇f(x) from the cached image A x with the gradient oracle,
# in state.xhat with state.dz (scratch that APG writes before it reads it), and counts the
# evaluation in grad_calls.
function _gradient_at_x!(state::AccProxGradDescentState, f)
  _value_and_gradient!(state.xhat, state.x, f, state.z_x, state.dz)
  state.grad_calls += 1
  state.xhat
end

# x == y elementwise, by value (so -0.0 == 0.0), without allocating
function _unchanged(x::AbstractArray, y::AbstractArray)
  @inbounds for i in eachindex(x, y)
    x[i] == y[i] || return false
  end
  true
end

_state_norm(s::Union{ProximalGradientDescentState, AccProxGradDescentState}, x) = _norm(x)
_state_normdiff(s::Union{ProximalGradientDescentState, AccProxGradDescentState}) = _norm_diff(s.x, s.x_previous, 2.)
