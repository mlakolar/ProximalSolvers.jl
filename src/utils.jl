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

  # A stop proposed by any of the three tests counts only if the accepted iterate is stationary
  # for the lasso, to the working precision (see _stationary!); otherwise the solve continues.
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
  ρ = state.L * eps(T) * _norm_inf(state.x)
  m = state.max_residual
  (residual < options.gradtol * m && ρ < m) || (residual < options.gradtol * N && ρ < N)
end

# ---- the stationarity check of a proposed stop -------------------------------------------------
#
# The check is for the least-squares problem ½α‖Xb - y‖² + h(b) (α = 1 for a raw LeastSquaresLoss),
# whose gradient ∇f the solver forms, with h = λ‖·‖₁ for NormL1(λ), or
# h = λ1‖·‖₁ + (λ2/2)‖·‖² for ElasticNet(λ1, λ2). G is the element of ∇f(x) + ∂h(x) of least norm:
# for NormL1, |∇fᵢ| - λ clipped at 0 where xᵢ = 0 and |∇fᵢ + λ sign xᵢ| otherwise; for ElasticNet, the
# same with λ = λ1 and the term λ2 xᵢ added to ∇fᵢ where xᵢ ≠ 0 (the ridge part has gradient λ2 x,
# which is 0 where xᵢ = 0). The stop is kept when ‖G‖∞ < τ S, with S = max(λ1, λmax) (λ1 = λ for
# NormL1), λmax = α‖Xᵀy‖∞ = ‖∇f(0)‖∞, and τ = max(gradtol, 64 eps(T)). S does not contain λ2: for
# ElasticNet the problem is the lasso with level λ1 on the data [√α X; √λ2 I], [√α y; 0], whose
# gradient is ∇f(x) + λ2 x and whose λmax is the λmax above. The threshold is relative to S, which a
# common positive factor on the loss and the penalty levels scales alike (within the range of T), and
# 64 eps(T) is a floor of a few dozen units of roundoff, chosen without a bound on the error of the
# computed gradient. It is not kept when S is not finite, when τ S is below floatmin(T) (a threshold
# that may have underflowed; a computed S = 0, as for λ1 = 0 and y = 0, is one) or when ‖G‖∞ is not finite.
# It is a computed residual, not a certificate in exact arithmetic.
function _stationary!(state, f, g, options::ProximalOptions)
  T = eltype(state.x)
  λmax = _lambda_max!(state)       # first: it uses xhat, which APG's gradient below also uses
  grad = _gradient_at_x!(state, f)
  λ = _l1_level(g, T)
  residual = _stationarity_residual(g, grad, state.x, T)
  S = max(λ, λmax)
  τ = T(max(options.gradtol, 64 * Float64(eps(T))))
  threshold = τ * S
  isfinite(S) && threshold >= floatmin(T) && isfinite(residual) && residual < threshold
end

# α‖Xᵀy‖∞, computed once per solve (state.λmax is negative until then) with the arithmetic of the
# gradient oracle at x = 0 (Xᵀ times a vector, then the scale α). It is formed in state.xhat. At
# every use in the solvers xhat is written before it is read (the input of the proximal step in
# PGD's update_state!, the same input and the difference x - y in APG's _prox_grad_step!), and
# the convergence tests and the trace do not read it, so a stop that is assessed after an
# iteration can overwrite it. It is not a counted call.
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
# in state.xhat (the length-p buffer above) with state.dz, the image-length buffer that APG writes
# before it reads it at each use (the value and gradient at y, the fresh product of the bound
# test), and counts the evaluation in grad_calls.
function _gradient_at_x!(state::AccProxGradDescentState, f)
  _value_and_gradient!(state.xhat, state.x, f, state.z_x, state.dz)
  state.grad_calls += 1
  state.xhat
end

# The ℓ1 level of the penalty in T, and the residual of ∇f(x) + ∂h(x) at x in T, for the penalties that
# _check_penalty accepts for PGD and APG
_l1_level(g::NormL1, ::Type{T}) where T = T(g.λ0)
_l1_level(g::ElasticNet, ::Type{T}) where T = T(g.λ1)
_stationarity_residual(g::NormL1, grad, x, ::Type{T}) where T = _kkt_residual(grad, x, T(g.λ0))
_stationarity_residual(g::ElasticNet, grad, x, ::Type{T}) where T = _kkt_residual(grad, x, T(g.λ1), T(g.λ2))

# maxᵢ of max(|gᵢ| - λ, 0) where xᵢ = 0, and of |gᵢ + λ sign xᵢ| elsewhere; NaN if an entry is
# NaN (max propagates it)
function _kkt_residual(grad::AbstractArray, x::AbstractArray, λ::T) where {T}
  m = zero(T)
  @inbounds for i in eachindex(grad, x)
    xi = x[i]
    r = iszero(xi) ? max(abs(grad[i]) - λ, zero(T)) : abs(grad[i] + λ * sign(xi))
    m = max(m, r)
  end
  m
end

# The residual for the elastic net: maxᵢ of max(|gᵢ| - λ1, 0) where xᵢ = 0, and of
# |gᵢ + λ2 xᵢ + λ1 sign xᵢ| elsewhere; NaN if an entry is NaN (max propagates it). For λ2 = 0 and
# finite x it equals the value of the 3-argument method.
function _kkt_residual(grad::AbstractArray, x::AbstractArray, λ1::T, λ2::T) where {T}
  m = zero(T)
  @inbounds for i in eachindex(grad, x)
    xi = x[i]
    r = iszero(xi) ? max(abs(grad[i]) - λ1, zero(T)) : abs(grad[i] + λ2 * xi + λ1 * sign(xi))
    m = max(m, r)
  end
  m
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
