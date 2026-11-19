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
  # stationarity check of _stationary!, to the working precision; otherwise the solve continues.
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
# whose gradient ∇f the solver forms, with h = λ‖·‖₁ for NormL1(λ), h = Σⱼ λ wⱼ |bⱼ| for NormL1(λ, w), or
# h = λ1‖·‖₁ + (λ2/2)‖·‖² for ElasticNet(λ1, λ2). G is the element of ∇f(x) + ∂h(x) of least norm:
# for NormL1, |∇fᵢ| - cᵢ clipped at 0 where xᵢ = 0 and |∇fᵢ + cᵢ sign xᵢ| otherwise, with cᵢ = λ (cᵢ = λ wᵢ
# with weights); for ElasticNet, the same with cᵢ = λ1 and the term λ2 xᵢ added to ∇fᵢ where xᵢ ≠ 0 (the ridge
# part has gradient λ2 x, which is 0 where xᵢ = 0). A zero weight leaves its entry unpenalized: cᵢ = 0 and
# the score is |∇fᵢ|. The stop is kept when ‖G‖∞ < τ S, with S = max(λ1, λmax) (λ1 = λ for NormL1(λ); for
# NormL1(λ, w) the largest coefficient, S = max(maxᵢ cᵢ, λmax)), λmax = α‖Xᵀy‖∞ = ‖∇f(0)‖∞, and
# τ = max(gradtol, 64 eps(T)). S does not contain λ2: for
# ElasticNet the problem is the lasso with level λ1 on the data [√α X; √λ2 I], [√α y; 0], whose
# gradient is ∇f(x) + λ2 x and whose λmax is the λmax above. The threshold is relative to S, which a
# common positive factor on the loss and the penalty levels scales alike (within the range of T), and
# 64 eps(T) is a floor of a few dozen units of roundoff, chosen without a bound on the error of the
# computed gradient. It is not kept when S is not finite, when τ S is below floatmin(T) (a threshold
# that may have underflowed; a computed S = 0, as for λ1 = 0 and y = 0, is one) or when ‖G‖∞ is not finite.
# ‖G‖∞ is ProximalBase's full-point kkt_violation(h, ∇f(x), x) for NormL1(T(λ0)), NormL1(T(λ0), w) or
# ElasticNet(T(λ1), T(λ2)), the coefficients of the formulas above: each level is converted to T once, into
# a penalty that gives both S and the residual, so that ProximalBase does not round the levels again.
# For NormL1(λ0, w), solve! requires w to be a Vector{T}, so ProximalBase's coefficient of entry i is the product
# T(λ0) wᵢ rounded in T: the cᵢ that solve! checked (finite and, where both factors are positive, a normal number of T).
# Rounding is monotone, so T(λ0) maximum(w) is maxᵢ cᵢ. The weights are not converted or copied. A proposed
# stop adds to the O(p) pass of kkt_violation one O(p) scan of w for `maximum` and one in the constructor of
# the NormL1 that holds the converted level; for w ≡ 1 the coefficients and S are those of NormL1(λ0).
# An infinite entry of x gives a non-finite residual (Inf, or NaN when a NaN is read), so such a stop is
# not kept.
# It is a computed residual, not a certificate in exact arithmetic.
#
# GroupNormL2(λ0, groups, w) (ProximalGradientDescent; solve! requires a GroupNormL2{T} whose groups partition 1:p
# and hold the members they were constructed with), h = Σₖ cₖ ‖b[Gₖ]‖₂ with cₖ = λ0 wₖ rounded in T. The residual is ProximalBase's full-point
# kkt_violation(g, ∇f(x), x) = max(0, maxₖ scoreₖ), with scoreₖ = ‖∇_G f + cₖ x_G/‖x_G‖₂‖₂ at a group with a nonzero
# entry and ‖∇_G f‖₂ - cₖ at a zero group (a zero weight gives the score ‖∇_G f‖₂). S = max(c_max, Λ), with
# c_max = λ0 maximum(w) = maxₖ cₖ (rounding is monotone) and Λ = maxₖ ‖[∇f(0)]_{Gₖ}‖₂ = α maxₖ ‖[Xᵀy]_{Gₖ}‖₂
# (_scale_norm, LinearAlgebra's norm of each block); 0 is a minimizer iff ‖[∇f(0)]_{Gₖ}‖₂ ≤ cₖ for each k. τ, the
# threshold and the guards are those above. As for the ℓ1 penalties, a kept stop says that the computed residual is
# below the computed threshold, not that the residual in exact arithmetic is. For singleton groups with unit weights,
# S equals the S of NormL1(λ0) where no entry of ∇f(0) has a subnormal square (there the computed norm of a one-entry
# block is its magnitude); the iterates and the residuals of the two penalties can differ by rounding, since
# ProximalBase's group operations are not its ℓ1 operations.
function _stationary!(state, f, g::Union{NormL1, ElasticNet, GroupNormL2}, options::ProximalOptions)
  T = eltype(state.x)
  λmax = _lambda_max!(state, _scale_norm(g))   # first: it uses xhat, which APG's gradient below also uses
  grad = _gradient_at_x!(state, f)
  gT = _converted_penalty(g, T)
  λ = _l1_level(gT)
  residual = kkt_violation(gT, grad, state.x)
  S = max(λ, λmax)
  τ = T(max(options.gradtol, 64 * Float64(eps(T))))
  threshold = τ * S
  isfinite(S) && threshold >= floatmin(T) && isfinite(residual) && residual < threshold
end

# The default stationarity check, for a penalty without a dedicated check above (today NormLinf): a new
# proximable g needs no convergence code of its own. At the accepted x, with t = 1/L (the accepted curvature),
# it forms u = x - t ∇f(x) and p = prox_{t g}(u) with the iterations' value_and_prox! call, and r = ‖x - p‖∞ / t,
# the ∞-norm of the proximal-gradient mapping G_t(x). The stop is kept when r < τ S, with S = max(‖∇f(0)‖∞,
# ‖∇f(x)‖∞) and τ = max(gradtol, 64 eps(T)). It is refused when t is not finite and positive (before the prox),
# S or r is not finite, τ S is below floatmin(T) (so S = 0, as for X = 0 or at x = 0 when y = 0, never converges), τ S does not
# exceed the rounding resolution L eps(T) ‖x‖∞ of the gradient test, or the step t τ S is below floatmin(T)/eps(T)
# (a step that subnormal rounding can lose at x = 0). The prox counts in prox_calls; APG's gradient at x counts in
# grad_calls. u goes to xhat and p to delta_x, which is then restored to x - x_previous. A small accepted L makes
# t large and ‖G_t‖ a weaker measure of stationarity; a penalty with curvature of its own, far above L, is the
# extreme case. A kept stop is a working-precision indication, not a certificate.
function _stationary!(state, f, g, options::ProximalOptions)
  T = eltype(state.x)
  t = one(T) / state.L
  isfinite(t) && t > 0 || return false
  λmax = _lambda_max!(state)       # first: it uses xhat, which APG's gradient below also uses
  grad = _gradient_at_x!(state, f)
  S = max(λmax, _norm_inf(grad))
  _step!(state.xhat, state.x, grad, state.L)   # elementwise, so APG's grad === xhat is safe
  value_and_prox!(state.delta_x, g, state.xhat, t)
  state.prox_calls += 1
  r = _norm_diff(state.x, state.delta_x, Inf) / t
  _sub!(state.delta_x, state.x, state.x_previous)
  threshold = T(max(options.gradtol, 64 * Float64(eps(T)))) * S
  # (L ‖x‖∞) eps(T): a product in this order underflows only where ρ < floatmin(T) ≤ τ S, and overflows to Inf (refused)
  ρ = (state.L * _norm_inf(state.x)) * eps(T)
  isfinite(S) && isfinite(r) && threshold >= floatmin(T) && threshold > ρ &&
    t * threshold >= floatmin(T) / eps(T) && r < threshold
end

# α‖Xᵀy‖ = ‖∇f(0)‖ in the norm `nrm` (the ∞-norm by default, as in the default check; the dedicated check passes _scale_norm(g)),
# computed once per solve (state.λmax is negative until then; the penalty, and so the norm, is fixed in a
# solve) with the arithmetic of the gradient oracle at x = 0 (Xᵀ times a vector, then the scale α). It is formed in state.xhat. At
# every use in the solvers xhat is written before it is read (the input of the proximal step in
# PGD's update_state!, the same input and the difference x - y in APG's _prox_grad_step!), and
# the convergence tests and the trace do not read it, so a stop that is assessed after an
# iteration can overwrite it. It is not a counted call.
function _lambda_max!(state, nrm = _norm_inf)
  state.λmax < 0 || return state.λmax
  m = state.model
  mul!(state.xhat, transpose(m.X), m.Y)
  state.xhat .*= m.α
  state.λmax = nrm(state.xhat)
end

# The norm of ∇f(0) in the stop scale S: the ∞-norm, and for GroupNormL2 the largest 2-norm of a group block
_scale_norm(g) = _norm_inf
_scale_norm(g::GroupNormL2) = v -> maximum(G -> norm(view(v, G)), g.groups)

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

# The penalty with its levels converted to T, for NormL1, ElasticNet and GroupNormL2 (the penalties of the dedicated check above),
# and the ℓ1 level of a converted penalty
_converted_penalty(g::NormL1{<:Real, Nothing}, ::Type{T}) where T = NormL1(T(g.λ0))
# weights that are already in T are not converted or copied
_converted_penalty(g::NormL1{<:Real, Vector{T}}, ::Type{T}) where T = NormL1(T(g.λ0), g.w)
# Each ElasticNet level that is not of type T is converted in a call of its own (#351): when two conversions are
# in one function, LLVM can combine them into one vector conversion, and the AArch64 NEON lowering of LLVM before
# 21 (llvm/llvm-project#130665) converts a pair of Int64 to Float32 through Float64, which rounds twice (as for
# Rational{Int64} levels). A level of type T is returned as it is.
_converted_level(::Type{T}, λ::T) where T = λ
@noinline _converted_level(::Type{T}, λ) where T = T(λ)
_converted_penalty(g::ElasticNet, ::Type{T}) where T = ElasticNet(_converted_level(T, g.λ1), _converted_level(T, g.λ2))
_l1_level(g::NormL1) = g.λ0
# the largest coefficient λ0 wᵢ of a penalty with weights in T and a level in T
_l1_level(g::NormL1{<:Real, <:Vector}) = g.λ0 * maximum(g.w)
_l1_level(g::ElasticNet) = g.λ1
# solve! requires the parameters of a GroupNormL2 to be of type T; the level of the scale is the largest coefficient
_converted_penalty(g::GroupNormL2{T}, ::Type{T}) where T = g
_l1_level(g::GroupNormL2) = g.λ0 * maximum(g.w)

# x == y elementwise, by value (so -0.0 == 0.0), without allocating
function _unchanged(x::AbstractArray, y::AbstractArray)
  @inbounds for i in eachindex(x, y)
    x[i] == y[i] || return false
  end
  true
end

_state_norm(s::Union{ProximalGradientDescentState, AccProxGradDescentState}, x) = _norm(x)
_state_normdiff(s::Union{ProximalGradientDescentState, AccProxGradDescentState}) = _norm_diff(s.x, s.x_previous, 2.)
