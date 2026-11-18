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
  # stationarity check of the penalty (_stationary!: the KKT residual of the iterate, with the penalty's own
  # subdifferential for NormL1, ElasticNet and NormLinf), to the working precision; otherwise the solve continues.
  # For APG the check counts its one gradient evaluation here, before the call limits are compared in _solve_gradient!.
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
function _stationary!(state, f, g, options::ProximalOptions)
  T = eltype(state.x)
  λmax = _lambda_max!(state)       # first: it uses xhat, which APG's gradient below also uses
  grad = _gradient_at_x!(state, f)
  gT = _converted_penalty(g, T)
  λ = _l1_level(gT)
  residual = kkt_violation(gT, grad, state.x)
  S = max(λ, λmax)
  τ = T(max(options.gradtol, 64 * Float64(eps(T))))
  threshold = τ * S
  isfinite(S) && threshold >= floatmin(T) && isfinite(residual) && residual < threshold
end

# ---- the stationarity check of a proposed stop, NormLinf --------------------------------------
#
# The check is for ½α‖Xb - y‖² + λ‖b‖∞ (α = 1 for a raw LeastSquaresLoss), f the least-squares part. It is the
# direct KKT residual at the accepted iterate x, with g = ∇f(x):
#     r(x) = min over v in ∂‖x‖∞ of ‖g + λ v‖₁,
# so that r(x) = 0 iff 0 ∈ ∇f(x) + λ ∂‖x‖∞, iff x minimizes f + λ‖·‖∞ (a convex problem, in exact arithmetic).
# The ℓ1 norm is the dual norm of ‖·‖∞, and ‖·‖₁ ≥ ‖·‖∞, so it is the stricter of the two natural norms.
# There is no step, no curvature L and no proximal evaluation in it.
#
# The subdifferential. At x = 0 it is the unit ℓ1 ball {v: ‖v‖₁ ≤ 1}, and min_v ‖g + λ v‖₁ = max(‖g‖₁ - λ, 0): the
# triangle inequality gives ‖g + λ v‖₁ ≥ ‖g‖₁ - λ‖v‖₁ ≥ ‖g‖₁ - λ, and v = -g/max(‖g‖₁, λ) attains the minimum when
# max(‖g‖₁, λ) > 0 (then g + λ v = g (1 - λ/max(‖g‖₁, λ)); for λ = 0 the minimum is ‖g‖₁ whatever v is, and v = 0 attains
# it when g = 0 too). At x ≠ 0, with m = maxᵢ|xᵢ|, M = {i : |xᵢ| = m} and sᵢ = sign xᵢ, it is the set of v with vᵢ = 0 off M,
# vᵢ = sᵢ wᵢ on M, wᵢ ≥ 0 and Σ wᵢ = 1. Then r = off + min_w Σ_{i∈M} |sᵢgᵢ + λ wᵢ|, off = Σ_{i∉M} |gᵢ|. For λ = 0 this is
# ‖g‖₁. For λ > 0, the term |aᵢ + λ wᵢ| (aᵢ = sᵢgᵢ) has slope +λ in wᵢ if aᵢ ≥ 0, and slope -λ until wᵢ = -aᵢ/λ and +λ after
# if aᵢ < 0. With N = Σ_{i∈M} max(sᵢgᵢ, 0) and P = Σ_{i∈M} max(-sᵢgᵢ, 0), the unit of mass is spent first where the slope
# is -λ (a total capacity P/λ) and then at slope +λ: the minimum is N + (P - λ) if λ ≤ P and N + (λ - P) otherwise, that is
#     r = off + N + |λ - P|,
# which also holds at λ = 0. This closed form was checked against an exact (rational) vertex enumeration of the
# minimization for |M| ≤ 3.
#
# The stop is kept when r < τ S, with S = max(λ, λcrit), λcrit = ‖∇f(0)‖₁ = α‖Xᵀy‖₁ (_lambda_max! with the 1-norm)
# and τ = max(gradtol, 64 eps(T)), all in T, as for the lasso check (λ here and below is λ_T = T(g.λ), the level of the
# penalty converted once to T; "The original level" below relates it to g.λ); it is not kept when S is not finite, when τ S is
# below floatmin(T) (a threshold that may have underflowed) or when r is not finite. For the penalty λ‖·‖∞, 0 is a minimizer
# iff ‖∇f(0)‖₁ ≤ λ (the case x = 0 above), so λcrit is the smallest level for which 0 is a minimizer; it is an ℓ1
# quantity, not the lasso's ‖∇f(0)‖∞. In exact arithmetic, the change (f, λ) → (c f, c λ) for a constant c > 0 scales g,
# λ, r and S by c, so the comparison r < τ S does not change (within the range of T).
#
# The active set M is found by exact equality of the stored values, with no tolerance. The accepted iterate of PGD and of
# APG is the output of PB's value_and_prox! for NormLinf, which for a positive clip level stores each clipped entry as ±τ with the
# same τ, so the entries that the clip ties at the maximum have equal magnitudes (their signed values differ when their signs do).
# Exact equality of the magnitudes makes the subdifferential, and so r in exact arithmetic, those of the stored point. An iterate
# whose entries near the maximum have unequal magnitudes has the smaller ones off M, so their |gᵢ| count in r: that can make
# the check refuse (when their gradient contribution is too large), but it does not always (a point with M = {1} and a
# smaller entry whose gradient is 0 can have r = 0), and a point whose exact residual is above τ S is not accepted for that reason.
#
# Summation. The residual is a difference of sums, r = off + N + |λ - P| (and max(‖g‖₁ - λ, 0) at x = 0), in which λ is
# cancelled against P (resp. ‖g‖₁), so a plain sequential sum can lose small terms before the subtraction (a sum at 1 does not
# change when 2^-24 is added to it in Float32, however many times). Each accumulator is therefore a Neumaier-compensated sum,
# written inline, with λ folded into it: D = λ - Σ_{i∈M} max(-sᵢgᵢ, 0) at x ≠ 0 and D0 = -λ + Σ|gᵢ| at x = 0, so that the
# cancellation happens inside the compensated sum; off and N, which enter r with the same sign, share one. The sums are formed in
# A = Float64 for Float32 and for Float64 data (each term is converted to A, which is exact for Float32, and then accumulated),
# because the correction of a compensated sum is itself a sum in the accumulation type and stagnates when p eps(A) is of order 1
# (in Float32 at p about 2^24, where a correction at -w stops changing under terms of 2^-24 w).
# The error bound. For a Neumaier-compensated sum of the k terms xᵢ in IEEE binary arithmetic with round-to-nearest and gradual
# underflow (no fused or reordered operations), with k u < 1 and no overflow in an intermediate result, and with unit roundoff u of
# the accumulator, whose result includes the final addition of the sum and its correction, |computed - exact| ≤
# u |S| + γ_{k-1}² Σ|xᵢ|, S the exact sum, γ_k = k u/(1 - k u) (Ogita, Rump and Oishi 2005, Proposition 4.5). The second term is
# quadratic in the number of terms; it does not fold into a bound of order p u² Σ|xᵢ|. Here u = eps(Float64)/2 = 2^-53, B = γ_p², and
# S below is max(λ, λcrit) of the threshold, not the sum of the proposition.
# The residual. Let R be the exact residual of the supplied gradient at the level λ_T (R = off + N + |D| at x ≠ 0, R = max(D0, 0)
# at x = 0, with the exact D = λ - P and D0 = -λ + ‖g‖₁), and r_c the computed one, finite. At x ≠ 0 the sum a = off + N has p
# nonnegative terms, so |â - a| ≤ (u + B) a. D has p + 1 terms with Σ|terms| = λ + P ≤ 2λ + |D| ≤ 2 S + |D| (P = λ - D ≤ λ + |D|,
# λ ≤ S), so |D̂ - D| ≤ (u + B) |D| + 2 B S. Then â + |D̂| ≥ (1 - u - B) (a + |D|) - 2 B S = (1 - u - B) R - 2 B S, and the final
# addition adds a relative error of at most u, so r_c ≥ (1 - u) ((1 - u - B) R - 2 B S) ≥ (1 - 2u - B) R - 2 B S (when the bracket
# is negative, r_c ≥ 0 is already above the right side). At x = 0, D̂0 has p + 1 terms with Σ|terms| = λ + ‖g‖₁, and
# r_c = max(D̂0, 0). If D0 ≥ 0, R = D0 and ‖g‖₁ = D0 + λ, so r_c ≥ D̂0 ≥ (1 - u - B) R - 2 B S; if D0 < 0, R = 0 ≤ r_c. So in both
# branches, with no assumption on the size of R against S,
#   r_c ≥ (1 - 2u - B) R - 2 B S.
# The regime. Let F = 64 eps(T), a power of two, and H the computed threshold fl(τ S) in T, with τ ≥ F. If a stop is kept, r_c < H.
# H passed the guard H ≥ floatmin(T), and τ S ≥ F S exactly. If F S ≥ floatmin(T), F S is S scaled by a power of two with a
# normal result, so it is representable and monotonic rounding gives H = fl(τ S) ≥ F S. If F S < floatmin(T) (F S is then subnormal or
# underflows, and its computed value may be inexact or 0), H ≥ floatmin(T) > F S directly. In both cases H ≥ F S (a larger
# gradtol cannot decrease H). B is required to satisfy 4 B ≤ 2^-10 F, so that 2 B S ≤ 2^-11 F S ≤ 2^-11 H; that is
#   γ_p² ≤ 2^-12 F = 2^-6 eps(T), that is γ_p ≤ 2^-3 sqrt(eps(T)).
# For T = Float64, sqrt(eps) = 2^-26, so γ_p ≤ 2^-29, that is p u (1 + 2^-29) ≤ 2^-29, that is p ≤ 2^24/(1 + 2^-29) = 2^24 - 2^-5 + ...,
# so the largest p is 2^24 - 1 (at p = 2^24, γ_p = 2^-29/(1 - 2^-29), a factor 1/(1 - 2^-29) above 2^-29). For T = Float32, sqrt(eps) =
# 2^-11.5, γ_p ≤ 2^-14.5, that is p ≤ 2^-14.5/(u (1 + 2^-14.5)), about 3.9e11, which is above the cap 2^32 that is used
# (2^32 entries of Float32 are 16 GiB); at the cap γ_p ≈ 2^-21 and B ≈ 2^-42, below 2^-12 F = 2^-29. The caps are Int64 values
# (_linf_max_entries), so that the comparison does not overflow where Int is 32 bits wide. The helper is therefore used for
# p ≤ 2^24 - 1 entries of Float64 data and p ≤ 2^32 entries of Float32 data; for a longer x of those types it returns NaN, before any
# pass, and the check refuses. Other element types (the exact rational inputs of the tests) have no cap.
# What a kept stop gives within the regime, under the bound above. With r_c < H and 2 B S ≤ 2^-11 H,
#   R < (H + 2 B S)/(1 - 2u - B) ≤ H (1 + 2^-11)/(1 - 2u - B) < (1 + 2^-10) H,
# since u = 2^-53 and B ≤ 2^-12 F (B ≤ 2^-29 for Float32, 2^-58 for Float64, so 1 - 2u - B > 1 - 2^-28). That is, the exact residual R
# of the supplied gradient at the level λ_T is below the computed threshold times 1 + 2^-10, also when R is larger than S. If the
# threshold is infinite the statement is vacuous. This is not a bound on the error of the computed gradient itself, which is not covered (below). An infinite
# or NaN gradient entry, or an overflowing sum, makes the compensation NaN (Inf - Inf) or infinite, so that r is not finite and the
# check refuses; a NaN or infinite entry of x gives r = NaN. r is returned in A, and the comparison with the threshold, a T converted
# exactly to A, is made in A.
# The original level. The level g.λ of the penalty is accepted in other types than T (Int, Rational, BigFloat, a Float64 level
# with Float32 data), and λ_T = T(g.λ) can differ from it. For every v in ∂‖x‖∞, ‖v‖₁ ≤ 1, so ‖g + λ v‖₁ changes by at most
# |λ - λ_T| when λ_T is replaced by λ, and so does its minimum over v (and max(‖g‖₁ - λ, 0) at x = 0): the residual at the
# original level satisfies R(g.λ) ≤ R(λ_T) + |g.λ - λ_T|, for the same supplied gradient. When the conversion rounds g.λ to
# nearest (Float16, Float32, Float64 and Int levels, a BigFloat level under BigFloat's default rounding mode, and a Rational of a
# fixed-width integer type whose numerator and denominator are exact in T, which Julia converts by one division in T), |g.λ - λ_T|
# ≤ (eps(T)/2) λ_T ≤ (eps(T)/2) S ≤ 2^-7 H if λ_T is normal (H ≥ F S = 64 eps(T) S), and |g.λ - λ_T| ≤ nextfloat(zero(T))/2 <
# 2^-7 H otherwise (H ≥ floatmin(T)), so within the regime a kept stop gives R(g.λ) < (1 + 2^-10 + 2^-7) H. Another Rational level
# (a numerator or denominator rounded in the conversion, or a Rational{BigInt} rounded through BigFloat) has only the first
# inequality, with its own |g.λ - λ_T|.
#
# What it is and is not. r is computed from the computed gradient, so the rounding error of the gradient is not
# covered (as for the lasso check): the true residual at a kept stop can be above τ S by the gradient's error, and by the summation's
# error within the bounds above (a sweep of 1608 Float32 solves against a BigFloat reference found at most 1.002 τ S: a measured value
# of that sweep, not a bound). The remaining error sources are that gradient error, the compensated summation's error above and, for the
# original level g.λ, its conversion to λ_T (above). It is not a certificate in exact arithmetic and it does not bound the distance
# to a minimizer. It reads x and g in at most two passes (m, then the sums; the dimension cap returns before either, and a
# non-finite m returns after the first). ∇f(x) is _gradient_at_x! (PGD: the accepted gradient, no new evaluation; APG: one
# gradient from the cached image A x, counted in grad_calls). ∇f(0) is computed first, at most once per solve (at the first
# check of the solve; a solve that never runs the check never forms it), into state.xhat, which the iterations write before
# they read. _linf_kkt_residual reads x and g and writes neither. _stationary!
# caches λcrit in the state, overwrites state.xhat and, for APG, writes the gradient and residual scratch of its accepted-point
# gradient and counts one gradient; it leaves x, delta_x and the engines' gradients as they were, evaluates no proximal operator
# and uses no other buffer. Warm (compiled) on validated inputs, it allocates nothing for a level of type Float32, Float64, Int,
# Float16 or Rational{Int}; the conversion of a BigFloat or a Rational{BigInt} level to T can allocate.
function _stationary!(state, f, g::NormLinf, options::ProximalOptions)
  T = eltype(state.x)
  λcrit = _lambda_max!(state, v -> norm(v, 1))   # first: it uses xhat, which the gradient below may also use
  λ = T(g.λ)                                     # the one level, converted once (not paired with another conversion, as in #351)
  S = max(λ, λcrit)
  τ = T(max(options.gradtol, 64 * Float64(eps(T))))
  threshold = τ * S
  grad = _gradient_at_x!(state, f)
  r = _linf_kkt_residual(state.x, grad, λ)
  isfinite(S) && threshold >= floatmin(T) && isfinite(r) && r < threshold    # r in Float64 (A), the threshold is converted exactly
end

# r = min over v in ∂‖x‖∞ of ‖grad + λ v‖₁ for the level λ ≥ 0 (see the comment above): the active set is the set of entries of
# maximal magnitude, by exact equality; the sums are Neumaier-compensated, with λ folded into the one that it is cancelled
# against, and formed in A = Float64 for Float32 and Float64 data (and in the type of λ otherwise, as for the Rational inputs of the
# tests). For Float64 data and more than 2^24 - 1 entries, and for Float32 data and more than 2^32 entries, it returns NaN before any
# pass (the regime derived above); `p` is the number of entries, a keyword so that the guard can be tested on a short vector. It is
# also NaN for a non-finite entry of x. It reads x and grad and writes neither.
# The largest number of entries that _linf_kkt_residual accepts for data of type T (derived in the comment above): an Int64, so that
# 2^32 does not overflow where Int is 32 bits wide.
_linf_max_entries(::Type{Float64}) = (Int64(1) << 24) - 1
_linf_max_entries(::Type{Float32}) = Int64(1) << 32
_linf_max_entries(::Type) = typemax(Int64)

function _linf_kkt_residual(x, grad, λ; p = length(x))
  T = typeof(λ)
  A = T <: Union{Float32, Float64} ? Float64 : T
  z = zero(A)
  Int64(p) > _linf_max_entries(T) && return oftype(z, NaN)
  λ = A(λ)
  m = maximum(abs, x)
  isfinite(m) || return oftype(z, NaN)           # a NaN or infinite entry of x: no residual
  if iszero(m)
    s, c = -λ, z                                 # D0 = -λ + Σ|gᵢ|
    @inbounds for i in eachindex(grad)
      t = abs(A(grad[i]))
      u = s + t
      c += abs(s) >= t ? (s - u) + t : (t - u) + s
      s = u
    end
    return max(s + c, z)
  end
  d, cd = λ, z                                   # D = λ - Σ_{i∈M} max(-sᵢgᵢ, 0)
  a, ca = z, z                                   # off + N = Σ_{i∉M} |gᵢ| + Σ_{i∈M} max(sᵢgᵢ, 0)
  @inbounds for i in eachindex(x, grad)
    gi = A(grad[i])
    if abs(x[i]) == m
      sg = sign(x[i]) * gi
      q = max(-sg, z)
      if q > z
        u = d - q
        cd += abs(d) >= q ? (d - u) - q : (-q - u) + d
        d = u
      end
      t = max(sg, z)
    else
      t = abs(gi)
    end
    u = a + t
    ca += abs(a) >= t ? (a - u) + t : (t - u) + a
    a = u
  end
  (a + ca) + abs(d + cd)
end

# α‖Xᵀy‖ = ‖∇f(0)‖ in the norm `nrm`: the ∞-norm by default (NormL1 and ElasticNet) and the 1-norm for
# NormLinf (the dual norm of the penalty). It is computed at most once per solve, at the first check (state.λmax is
# negative until then; the penalty, and so the norm, is fixed in a solve) with the arithmetic of the
# gradient oracle at x = 0 (Xᵀ times a vector, then the scale α). It is formed in state.xhat. At
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

# The penalty with its levels converted to T, for NormL1 (with or without weights) and ElasticNet (the penalties of
# the KKT check above; a NormLinf object is not rebuilt: its check converts its scalar level itself), and the ℓ1 level of a
# converted penalty
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

# x == y elementwise, by value (so -0.0 == 0.0), without allocating
function _unchanged(x::AbstractArray, y::AbstractArray)
  @inbounds for i in eachindex(x, y)
    x[i] == y[i] || return false
  end
  true
end

_state_norm(s::Union{ProximalGradientDescentState, AccProxGradDescentState}, x) = _norm(x)
_state_normdiff(s::Union{ProximalGradientDescentState, AccProxGradDescentState}) = _norm_diff(s.x, s.x_previous, 2.)
