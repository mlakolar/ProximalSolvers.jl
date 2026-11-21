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
# of 0 does not hold), and only against a scale that exceeds ρ = (L ‖x‖∞) eps(T), the rounding
# resolution of L x. Form L ‖x‖∞ first to avoid premature underflow of L eps(T).
# A residual that is zero because a step rounded to nothing does not hold
# when ρ is at least as large as both m and N.
function _gradient_test(state::Union{ProximalGradientDescentState{T}, AccProxGradDescentState{T}},
                        options::ProximalOptions, residual, N) where T
  ρ = (state.L * _norm_inf(state.x)) * eps(T)
  m = state.max_residual
  (residual < options.gradtol * m && ρ < m) || (residual < options.gradtol * N && ρ < N)
end

# ---- the stationarity check of a proposed stop -------------------------------------------------
#
# Least squares ½α‖Xb - y‖² (α = 1 for a raw LeastSquaresLoss) with NormL1 or ElasticNet, each with or without weights,
# on a dense Vector{Float32} or Vector{Float64}: the state carries a _CoordinateScales (see _coordinate_scales) and
# the coordinatewise check below decides (STOP-21).
#
# The column data of the coordinatewise check, filled at the first check of a solve for the λ2 of that check (the
# penalty is fixed in a solve); `filled` is false until then. h[j] is hⱼ = √(a nⱼ² + λ2) as an _SE{Float64}
# (significand × 2^exponent, see src/solvers/image_models.jl), or one of two markers: _CASE_A (significand -1) for a
# column whose stored entries are all ±0 when λ2 is a stored ±0, and _REFUSED (significand NaN) for a nonzero column
# whose norm, computed with scaling, is 0 or not finite. y_zero says that every stored entry of y is ±0.
mutable struct _CoordinateScales
  h::Vector{_SE{Float64}}
  y_zero::Bool
  filled::Bool
end
const _CASE_A = _SE{Float64}(-1.0, 0)
const _REFUSED = _SE{Float64}(NaN, 0)

# The column data for the problems of the coordinatewise check, allocated (length p) and not filled; nothing for
# the other problems, which keep the λmax-based or the generic check.
_coordinate_scales(model, g, x) = nothing
_coordinate_scales(::_LSImage, ::Union{NormL1, ElasticNet}, x::Vector{T}) where {T<:Union{Float32, Float64}} =
  _CoordinateScales(Vector{_SE{Float64}}(undef, length(x)), false, false)

# The states that carry the column data
const _CoordinatewiseState{T<:Union{Float32, Float64}} = Union{
  ProximalGradientDescentState{T, Vector{T}, Vector{T}, <:_LSImage, <:Any, _CoordinateScales},
  AccProxGradDescentState{T, Vector{T}, <:_LSImage, <:Any, _CoordinateScales}}

# Whether the stored value is +0.0 or -0.0, from its bits: a subnormal is not zero here, also on a thread that flushes
# subnormals to zero (where iszero and == treat it as 0)
_stored_zero(v::Base.IEEEFloat) = (reinterpret(Unsigned, v) << 1) == 0

# √a and 2a for an _SE a = s·2^e: for √a an odd e is lowered by one with s doubled (s in [2, 4)), so that √a = √s·2^(e/2)
# with one Float64 rounding of √s
function _se_sqrt(a::_SE{T}) where {T}
  iszero(a.s) && return a
  s, e = a.s, a.e
  if isodd(e)
    s *= 2
    e -= 1
  end
  r = _SE{T}(sqrt(s))
  _SE{T}(r.s, r.e + e ÷ 2)
end
_se_twice(a::_SE{T}) where {T} = iszero(a.s) ? a : _SE{T}(a.s, a.e + 1)

# h = λ‖·‖₁ for NormL1(λ), h = Σⱼ λ wⱼ |bⱼ| for NormL1(λ, w), h = λ1‖·‖₁ + (λ2/2)‖·‖² for ElasticNet(λ1, λ2), and
# h = Σⱼ λ1 wⱼ |bⱼ| + (λ2/2)‖·‖² for ElasticNet(λ1, λ2, w). The working penalty gT has its levels in T
# (_converted_penalty) and the coefficients cᵢ = λ wᵢ (λ1 wᵢ) rounded in T. The score of coordinate i is ProximalBase's
# signed kkt_violation(gT, ∇f(x), x, i): |∇fᵢ| - cᵢ where xᵢ = 0, and |∇fᵢ + λ2 xᵢ + cᵢ sign xᵢ| otherwise (λ2 = 0 for
# NormL1). A zero weight gives cᵢ = 0, so its score is |∇fᵢ + λ2 xᵢ| at a nonzero xᵢ.
#
# In exact arithmetic t ↦ F(x + t eᵢ) is convex with curvature μᵢ = α‖Xᵢ‖² + λ2, and the magnitude of its least-norm
# subgradient at t = 0 is g⁺ᵢ = max(Gᵢ, 0) for the signed score Gᵢ. When μᵢ > 0 the decrease of F that coordinate i
# alone can give is at most (g⁺ᵢ)²/(2μᵢ); with the smooth part Φ = ½α‖Xx - y‖² + (λ2/2)‖x‖² and sᵢ = √(2μᵢΦ), a score
# Gᵢ < τ sᵢ makes that decrease less than τ²Φ. The check keeps a proposed stop when every coordinate passes, in one
# pass that ends at the first failure:
# - when λ2 is a stored ±0, a coordinate whose column has only stored ±0 entries (μᵢ = 0; the computed ∇fᵢ is ±0 for
#   a finite residual) passes when its computed score is finite and at most 0 (case A);
# - when every stored entry of x and of y is ±0 (F(0) = 0 is the minimum), every coordinate passes when its computed
#   score is finite and at most 0 (case B); x is scanned only when y is zero;
# - every other coordinate passes when its score is finite and below the threshold tᵢ = T(τ hᵢ ρ), which must be
#   finite and at least floatmin(T). Here τ = T(max(gradtol, 64 eps(T))), hᵢ = √(a nᵢ² + λ2) from the column data,
#   a = Float64(α), nᵢ = ‖Xᵢ‖, and ρ = √(2Φ). The factors are carried as _SE{Float64} values, whose exponents do not
#   overflow or underflow, and the product is rounded once to T. A threshold refuses the stop when it is NaN (the
#   _REFUSED marker), infinite or below floatmin(T) (which includes a computed ρ = 0 outside case B), and when τ, the
#   loss value or ‖x‖ is not finite.
# The case predicates read stored bits, not computed values; the column class is stored by the column pass.
# Φ is formed from state.f_x, the loss value that ProximalBase computed at the accepted x, and (λ2/2)‖x‖²; the scale
# does not form Xx - y (APG's gradient at x, see _gradient_at_x!, forms the residual from the cached image). After the
# column pass of the first check, a check adds O(p) work to that gradient: the pass over the coordinates, ‖x‖ when
# λ2 > 0, the zero test of x when y = 0 and, for a weighted NormL1, the scan of the weights in the constructor of the
# converted penalty. It does not compute λmax.
# The decision compares computed scores with computed thresholds; it is not a certificate in exact arithmetic.
function _stationary!(state::_CoordinatewiseState{T}, f, g::Union{NormL1, ElasticNet},
                      options::ProximalOptions) where {T<:Union{Float32, Float64}}
  grad = _gradient_at_x!(state, f)
  gT = _converted_penalty(g, T)
  λ2 = _ridge_level(gT)
  scales = _filled_scales!(state.scales, state.model, λ2)
  τ = T(max(options.gradtol, 64 * Float64(eps(T))))
  trivial = scales.y_zero && all(_stored_zero, state.x)
  c = _threshold_factor(τ, state.f_x, λ2, state.x)
  _coordinates_pass(gT, grad, state.x, scales.h, c, trivial)
end

# The coordinates of the check above. With `trivial` (case B), and where hᵢ is _CASE_A, the score must be finite and at
# most 0; elsewhere it must be finite and below the threshold _coordinate_threshold(T, c, hᵢ), which must be finite and
# at least floatmin(T). c = nothing (an infinite τ, or a nonfinite loss value or ‖x‖) refuses those coordinates, and so
# does the NaN threshold of a _REFUSED column.
function _coordinates_pass(gT, grad::Vector{T}, x::Vector{T}, h::Vector{_SE{Float64}}, c, trivial::Bool) where T
  for i in eachindex(x, grad, h)
    G = kkt_violation(gT, grad, x, i)
    hᵢ = @inbounds h[i]
    if trivial || hᵢ.s < 0
      (isfinite(G) && G <= 0) || return false
    else
      c === nothing && return false
      t = _coordinate_threshold(T, c, hᵢ)
      (isfinite(t) && t >= floatmin(T) && isfinite(G) && G < t) || return false
    end
  end
  true
end

# The threshold of coordinate i from c = τ ρ and hᵢ, both _SE{Float64}: the significands' product (in [1, 4), one Float64
# rounding) scaled by 2^(exponents' sum), which is exact in the normal range of Float64, then rounded once to T. A zero c
# gives 0 and a NaN hᵢ gives NaN.
_coordinate_threshold(::Type{T}, c::_SE{Float64}, hᵢ::_SE{Float64}) where T = T(ldexp(c.s * hᵢ.s, c.e + hᵢ.e))

# λ2 of the working penalty, of type T; nothing for NormL1
_ridge_level(g::NormL1) = nothing
_ridge_level(g::ElasticNet) = g.λ2

# c = τ ρ as an _SE{Float64}, ρ = √(2 f_x + λ2 ‖x‖²): 2 f_x and λ2 ‖x‖² are formed and added as _SE values, with ‖x‖ from
# a Float64 sum of squares or, when that sum is not finite or below 4 p floatmin(Float64), the scaled form of _se_norm.
# nothing when τ, f_x or ‖x‖ is not finite. f_x is the stored least-squares value, which is not negative.
function _threshold_factor(τ, f_x, λ2, x)
  isfinite(τ) && isfinite(f_x) || return nothing
  ρ2 = _se_twice(_SE{Float64}(Float64(f_x)))
  if !(λ2 === nothing || _stored_zero(λ2))
    nx = _se_norm_onepass(Float64, _sumsq64(x), x)
    nx === nothing && return nothing
    ρ2 = _se_add(ρ2, _se_mul(_SE{Float64}(Float64(λ2)), _se_mul(nx, nx)))
  end
  _se_mul(_SE{Float64}(Float64(τ)), _se_sqrt(ρ2))
end

# One pass over the columns of X, at the first check of a solve. sⱼ = Σᵢ Float64(Xᵢⱼ)² (exact squares for Float32
# entries, rounded sum). nⱼ = √sⱼ when sⱼ is finite and at least floatmin(Float64); otherwise a column whose stored
# entries are all ±0 is a zero column, and any other column has nⱼ from _se_norm of the column (scaled by its largest
# magnitude). hⱼ = √a nⱼ, or √(a nⱼ² + λ2) when λ2 is not a stored ±0, formed with _SE values; a zero column has _CASE_A
# when λ2 is a stored ±0 and √λ2 otherwise; a nonzero column whose nⱼ is 0 or not finite has _REFUSED. The stored
# entries of y are tested for ±0 once.
function _filled_scales!(c::_CoordinateScales, m::_LSImage, λ2)
  c.filled && return c
  X = m.X
  ra = _root_scale(Float64, m.α)
  ridge = !(λ2 === nothing || _stored_zero(λ2))
  l2 = ridge ? _SE{Float64}(Float64(λ2)) : _se_zero(Float64)
  for (k, j) in enumerate(axes(X, 2))
    s = 0.0
    @inbounds @simd for i in axes(X, 1)
      s += abs2(Float64(X[i, j]))
    end
    c.h[k] = if isfinite(s) && s >= floatmin(Float64)
      _column_scale(ra, _SE{Float64}(sqrt(s)), l2, ridge)
    elseif all(_stored_zero, view(X, :, j))
      ridge ? _se_sqrt(l2) : _CASE_A
    else
      n = _se_norm(Float64, view(X, :, j))
      n === nothing || iszero(n.s) || !isfinite(n.s) ? _REFUSED : _column_scale(ra, n, l2, ridge)
    end
  end
  c.y_zero = all(_stored_zero, m.Y)
  c.filled = true
  c
end

# √(a n² + λ2) from √a and n, as _SE values; √a n without a ridge term
function _column_scale(ra::_SE{Float64}, n::_SE{Float64}, l2::_SE{Float64}, ridge::Bool)
  u = _se_mul(ra, n)
  ridge ? _se_sqrt(_se_add(_se_mul(u, u), l2)) : u
end

# The λmax-based check, for the other problems with a dedicated penalty: a logistic loss with NormL1 (PGD and APG,
# IN-09, APG-08), a matrix response with NormL1 (IN-10), NormL1Nonneg and IndNonnegative (PGD), GroupNormL2 and NormL2.
# Its signature contains NormL1 and ElasticNet, so the coordinatewise method above, whose state and penalty types are
# subtypes of these, is the more specific one where both apply. solve! builds the column data for each ElasticNet
# problem that it accepts (a least-squares vector response, IN-03), so ElasticNet reaches this method only from a
# state built without them; the ElasticNet comments below describe that case.
#
# For NormL1, G is the element of ∇f(x) + ∂h(x) of least norm: |∇fᵢ| - cᵢ clipped at 0 where xᵢ = 0 and
# |∇fᵢ + cᵢ sign xᵢ| otherwise, with cᵢ = λ (cᵢ = λ wᵢ with weights). A zero weight gives cᵢ = 0, so its score is |∇fᵢ|.
# The full-point check requires ‖G‖∞ < τ S, with S = max(maxᵢ cᵢ, λmax), λmax = ‖∇f(0)‖∞ (α‖XᵀY‖∞ for a least-squares
# matrix response), and τ = max(gradtol, 64 eps(T)). The threshold is relative to S, which a
# common positive factor on the loss and the penalty levels scales alike (within the range of T), and
# 64 eps(T) is a floor of a few dozen units of roundoff, chosen without a bound on the error of the
# computed gradient. It is not kept when S is not finite, when τ S is below floatmin(T) (a threshold
# that may have underflowed; a computed S = 0 is one) or when ‖G‖∞ is not finite.
# ‖G‖∞ is ProximalBase's full-point kkt_violation(h, ∇f(x), x) for NormL1(T(λ0)) or NormL1(T(λ0), w). For ElasticNet the
# scores add λ2 xᵢ to ∇fᵢ where xᵢ ≠ 0, with S = max(maxᵢ cᵢ, λmax) independent of λ2, and the weighted form has the
# entry thresholds below. The same native penalty gives both S and the residual.
# For NormL1(λ0, w), solve! requires w to be a Vector{T}, so ProximalBase's coefficient of entry i is the product
# T(λ0) wᵢ rounded in T: the cᵢ that solve! checked (finite and, where both factors are positive, a normal number of T).
# Rounding is monotone, so T(λ0) maximum(w) is maxᵢ cᵢ. The weights are not converted or copied. A proposed
# stop adds to the O(p) pass of kkt_violation one O(p) scan of w for `maximum` and one in the constructor of
# the NormL1 that holds the converted level; for w ≡ 1 the coefficients and S are those of NormL1(λ0).
# For weighted NormL1, each entry is also held to its own scale: the signed score sᵢ (ProximalBase's
# kkt_violation(h, ∇f(x), x, i), negative at a zero entry with |∇fᵢ| < cᵢ) must be below τ max(cᵢ, λmax). That
# threshold is at most τ S, so the comparison with τ S above is necessary; when maxᵢ cᵢ ≤ λmax every entry threshold
# equals τ S and nothing more is done. Otherwise, after that comparison has passed, _entry_thresholds_hold compares each score with its threshold, which
# must be at least floatmin(T), in one more pass that ends at the first failure. Without it, a coefficient far above
# λmax (a large weight, or one that excludes a column) would set the threshold of entry i to τ maxⱼ cⱼ instead of
# τ max(cᵢ, λmax), larger in exact arithmetic by the factor maxⱼ cⱼ / max(cᵢ, λmax) where that scale is positive
# (maxⱼ cⱼ / λmax at a zero-weight entry with λmax > 0).
# An infinite entry of x gives a non-finite residual (Inf, or NaN when a NaN is read), so such a stop is
# not kept.
# It is a computed residual, not a certificate in exact arithmetic.
# For a logistic loss with NormL1 (PGD and APG, IN-09, APG-08) ∇f is the logistic gradient and
# λmax = ‖Xᵀ(½ - y)‖∞ = ‖∇f(0)‖∞ (see _zero_gradient!).
#
# GroupNormL2(λ0, groups, w) (ProximalGradientDescent and AccProxGradDescent; solve! requires a GroupNormL2{T} whose groups partition 1:p
# and match the layout stored in the penalty at construction), h = Σₖ cₖ ‖b[Gₖ]‖₂ with cₖ = λ0 wₖ rounded in T. The residual is ProximalBase's full-point
# kkt_violation(g, ∇f(x), x) = max(0, maxₖ scoreₖ), with scoreₖ = ‖∇_G f + cₖ x_G/‖x_G‖₂‖₂ at a group with a nonzero
# entry and ‖∇_G f‖₂ - cₖ at a zero group (a zero weight gives the score ‖∇_G f‖₂). S = max(c_max, Λ), with
# c_max = λ0 maximum(w) = maxₖ cₖ (rounding is monotone) and Λ = maxₖ ‖[∇f(0)]_{Gₖ}‖₂ = α maxₖ ‖[Xᵀy]_{Gₖ}‖₂
# (_scale_norm, LinearAlgebra's norm of each block); 0 is a minimizer iff ‖[∇f(0)]_{Gₖ}‖₂ ≤ cₖ for each k. τ, the
# threshold and the guards are those above, and as for weighted NormL1 each group is also held to τ max(cₖ, Λ) when
# maxₖ cₖ > Λ (its score is ProximalBase's kkt_violation(g, ∇f(x), x, i) at the first entry i of the group). As for the ℓ1 penalties, a kept stop says that the computed residual is
# below the computed threshold, not that the residual in exact arithmetic is. For singleton groups with unit weights,
# S equals the S of NormL1(λ0) where no entry of ∇f(0) has a subnormal square (there the computed norm of a one-entry
# block is its magnitude); the iterates and the residuals of the two penalties can differ by rounding, since
# ProximalBase's group operations are not its ℓ1 operations.
#
# NormL2 uses the full-point KKT score and Euclidean zero-gradient norm.
# In exact arithmetic these equal the single-group results with unit weight (STOP-17).
function _stationary!(state, f, g::Union{NormL1, NormL1Nonneg, IndNonnegative, ElasticNet, GroupNormL2, NormL2}, options::ProximalOptions)
  T = eltype(state.x)
  λmax = _lambda_max!(state, _scale_norm(g))   # first: it uses xhat, which APG's gradient below also uses
  grad = _gradient_at_x!(state, f)
  gT = _converted_penalty(g, T)
  λ = _l1_level(gT)
  residual = kkt_violation(gT, grad, state.x)
  S = max(λ, λmax)
  τ = T(max(options.gradtol, 64 * Float64(eps(T))))
  threshold = τ * S
  isfinite(S) && threshold >= floatmin(T) && isfinite(residual) && residual < threshold &&
    (λ <= λmax || _entry_thresholds_hold(gT, grad, state.x, τ, λmax))
end

# Each entry (each group) of a weighted penalty against its own threshold τ max(cᵢ, λmax), when the full-point
# comparison has passed and the largest coefficient exceeds λmax (see above). The unweighted penalties take
# the fallback, since their entry thresholds are τ S. If unit weights reach the entry check, each threshold
# equals τ S.
_entry_thresholds_hold(g, grad, x, τ, λmax) = true
function _entry_thresholds_hold(g::NormL1{T, Vector{T}}, grad, x, τ::T, λmax::T) where T
  @inbounds for i in eachindex(x, grad, g.w)
    t = τ * max(g.λ0 * g.w[i], λmax)
    (t >= floatmin(T) && kkt_violation(g, grad, x, i) < t) || return false
  end
  true
end
function _entry_thresholds_hold(g::ElasticNet{T, Vector{T}}, grad, x, τ::T, λmax::T) where T
  @inbounds for i in eachindex(x, grad, g.w)
    t = τ * max(g.λ1 * g.w[i], λmax)
    (t >= floatmin(T) && kkt_violation(g, grad, x, i) < t) || return false
  end
  true
end
function _entry_thresholds_hold(g::GroupNormL2{T}, grad, x, τ::T, λmax::T) where T
  @inbounds for k in eachindex(g.groups, g.w)
    t = τ * max(g.λ0 * g.w[k], λmax)
    (t >= floatmin(T) && kkt_violation(g, grad, x, first(g.groups[k])) < t) || return false
  end
  true
end

# For NormL1Nonneg, ProximalBase uses the point-aware constrained residual: abs(∇fᵢ + λ)
# at xᵢ > 0 and max(-(∇fᵢ + λ), 0) at xᵢ = 0, with Inf for an infeasible point.
# The scale is S = max(λ, α‖Xᵀy‖∞), as above; this is not the one-sided zero-solution threshold.

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

# ‖∇f(0)‖ in the norm `nrm` (the ∞-norm by default, as in the default check; the dedicated check passes _scale_norm(g)),
# computed once per solve (state.λmax is negative until then; the penalty, and so the norm, is fixed in a
# solve) by _zero_gradient! below. It is formed in state.xhat. At
# every use in the solvers xhat is written before it is read (the input of the proximal step in
# PGD's update_state!, the same input and the difference x - y in APG's _prox_grad_step!), and
# the convergence tests and the trace do not read it, so a stop that is assessed after an
# iteration can overwrite it. It is not a counted call.
function _lambda_max!(state, nrm = _norm_inf)
  state.λmax < 0 || return state.λmax
  _zero_gradient!(state.xhat, state, state.model)
  state.λmax = nrm(state.xhat)
end

# Least squares: α Xᵀy = -∇f(0), whose norm is ‖∇f(0)‖, with the arithmetic of the gradient oracle at x = 0
# (Xᵀ times a vector, then the scale α).
function _zero_gradient!(G, state, m::_LSImage)
  mul!(G, transpose(m.X), m.Y)
  G .*= m.α
end

# Logistic loss without observation weights or offset (the logistic loss of the image model that PGD and APG share, IN-09):
# ∇f(0) = Xᵀ(σ(0) - y) = Xᵀ(½ - y), with ½ - yᵢ = ±½ exact for a binary yᵢ. The difference is written
# to state.dz, the image-length buffer of both solvers. On the PGD path that buffer is written before it is read at its
# other uses (by ProximalBase as the derivative d in _value_and_gradient!, and by the product X d̂ in
# check_rejection!), so its content is not needed when this runs between iterations. APG writes it before each of its
# uses as well: ProximalBase's derivative d in the value and gradient at y (_prox_grad_step!), the fresh product X d̂ of
# _bound_certified!, and the gradient at the accepted x (_gradient_at_x!).
function _zero_gradient!(G, state, m::_LogisticImage)
  state.dz .= 0.5 .- m.Y
  mul!(G, transpose(m.X), state.dz)
end

# The norm of ∇f(0) in the stop scale S: the ∞-norm, and for GroupNormL2 the largest 2-norm of a group block
_scale_norm(g) = _norm_inf
_scale_norm(g::GroupNormL2) = v -> maximum(G -> norm(view(v, G)), g.groups)
# NormL2 is one group of all the entries: the 2-norm of the whole vector
_scale_norm(::NormL2) = norm

# ∇f at the accepted x. PGD holds it.
_gradient_at_x!(state::ProximalGradientDescentState, f) = state.grad_f_x

# APG holds ∇f(y), not ∇f(x). It forms ∇f(x) from the cached image A x with the gradient oracle,
# in state.xhat (the length-p buffer above) with state.dz, the image-length buffer that APG writes
# before it reads it at each use (the value and gradient at y, the fresh product of the bound
# test), and counts the evaluation in grad_calls. For a logistic loss, _value_and_gradient! returns Inf without writing
# its gradient buffer when the image has a nonfinite entry. Here the cached image z_x is finite: it is the image of the
# accepted x, and each trial that the line search accepts, the zero step included, lies in the isfinite(state.f_x) branch
# of _prox_grad_step!, where a logistic value is finite only for a finite image.
function _gradient_at_x!(state::AccProxGradDescentState, f)
  _value_and_gradient!(state.xhat, state.x, f, state.z_x, state.dz)
  state.grad_calls += 1
  state.xhat
end

# After validation, an unweighted lasso, NormL2 or weighted ElasticNet solve uses one working penalty for the
# initial value, value_and_prox! trials and stationarity. The working ElasticNet uses levels in T and
# borrows its Vector{T} weights (IN-03). Unweighted ElasticNet and weighted NormL1 keep their supplied
# levels in the value and prox.
_working_gradient_penalty(g, ::Type) = g
_working_gradient_penalty(g::Union{NormL1{<:Real, Nothing}, NormL1Nonneg{<:Real, Nothing}, NormL2}, ::Type{T}) where T =
  _converted_penalty(g, T)
_working_gradient_penalty(g::ElasticNet{<:Real, <:Vector}, ::Type{T}) where T = _converted_penalty(g, T)

# The penalty that CDSolver's private run receives on a dense Vector or a one-dimensional SparseIterate, after the
# gates: only a weighted ElasticNet is converted (to the working penalty of _converted_penalty); a native one is
# returned as it is. The run uses it for every coordinate step and for the final objective.
_working_cd_penalty(g, ::Type) = g
_working_cd_penalty(g::ElasticNet{<:Real, <:Vector}, ::Type{T}) where T = _converted_penalty(g, T)

# Penalties with levels in T for the dedicated stationarity check.
# The Real bound makes the native identity methods more specific than the mixed conversions.
_converted_penalty(g::NormL1{T, Nothing}, ::Type{T}) where {T<:Real} = g
_converted_penalty(g::NormL1{<:Real, Nothing}, ::Type{T}) where T = NormL1(T(g.λ0))
# weights that are already in T are not converted or copied
_converted_penalty(g::NormL1{<:Real, Vector{T}}, ::Type{T}) where T = NormL1(T(g.λ0), g.w)
# Each ElasticNet level that is not of type T is converted in a call of its own (#351): when two conversions are
# in one function, LLVM can combine them into one vector conversion, and the AArch64 NEON lowering of LLVM before
# 21 (llvm/llvm-project#130665) converts a pair of Int64 to Float32 through Float64, which rounds twice (as for
# Rational{Int64} levels). A level of type T is returned as it is.
_converted_level(::Type{T}, λ::T) where T = λ
@noinline _converted_level(::Type{T}, λ) where T = T(λ)
_converted_penalty(g::ElasticNet{<:Real, Nothing}, ::Type{T}) where T = ElasticNet(_converted_level(T, g.λ1), _converted_level(T, g.λ2))
# A weighted ElasticNet (solve! requires its weights to be a Vector{T}) keeps its weights, which are not converted or
# copied. A penalty whose levels are both of type T is returned as it is, so a native weighted object keeps its
# identity; otherwise each level that is not of type T is converted in a call of its own, as above.
_converted_penalty(g::ElasticNet{<:Real, Vector{T}}, ::Type{T}) where T =
  g.λ1 isa T && g.λ2 isa T ? g : ElasticNet(_converted_level(T, g.λ1), _converted_level(T, g.λ2), g.w)
_converted_penalty(g::NormL1Nonneg{T, Nothing}, ::Type{T}) where {T<:Real} = g
_converted_penalty(g::NormL1Nonneg{<:Real, Nothing}, ::Type{T}) where T = NormL1Nonneg(T(g.λ0))
# For stopping, the indicator and NormL1Nonneg(0) have the same normal cone.
# This uses the point-aware score at positive and zero coordinates.
_converted_penalty(::IndNonnegative, ::Type{T}) where T = NormL1Nonneg(zero(T))
_l1_level(g::NormL1Nonneg) = g.λ0
_l1_level(g::NormL1) = g.λ0
# the largest coefficient λ0 wᵢ of a penalty with weights in T and a level in T
_l1_level(g::NormL1{<:Real, <:Vector}) = g.λ0 * maximum(g.w)
_l1_level(g::ElasticNet{<:Real, Nothing}) = g.λ1
# the largest L1 coefficient λ1 wᵢ of a weighted ElasticNet with weights in T and a level in T (the ridge level is not
# part of the scale)
_l1_level(g::ElasticNet{<:Real, <:Vector}) = g.λ1 * maximum(g.w)
_converted_penalty(g::NormL2{T}, ::Type{T}) where {T<:Real} = g
_converted_penalty(g::NormL2, ::Type{T}) where T = NormL2(T(g.λ))
_l1_level(g::NormL2) = g.λ
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
