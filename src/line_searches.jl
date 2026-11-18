module LineSearches

using ..Blocks

export
  backtrack!,has_updated_gradient,
  BackTracking

#################################
#
# TFOCS Backtrack
#
#################################

"""
    BackTracking(; α = 0.9, β = 0.5, Lexact = Inf)

The backtracking line search of TFOCS (`private/tfocs_backtrack.m`). Each
iteration starts from `L ← α L`, where `1/L` is the step size, and while the
local Lipschitz estimate `L̂` of the step exceeds `L` it retries with
`L ← min(Lexact, max(L̂, L / β))`. `L̂` comes from function values until they
are too close to compare in floating point, and from gradients after that.
An LS trial whose image or value overflows is never accepted: it gives no
estimate, and the search retries with `L ← L / β`.

For [`ProximalGradientDescent`](@ref ProximalSolvers.ProximalGradientDescent)
on its supported least-squares model, a rejected trial with step `d̂ = x - x'`
is decided again by the computed curvature of the step,
`c = m α ‖fl(X d̂)‖²/‖d̂‖²`, from one product `X d̂`, with `m = 1` for
function-value estimates and `m = 2` for gradient estimates (TFOCS's gradient
test `2α ‖X d‖² ≤ L ‖d‖²`). When `L ≥ c` the trial is accepted and the estimate
mode is unchanged; otherwise the retry uses `L ← min(Lexact, max(c, L / β))`
when `c` is finite, and TFOCS's `L ← min(Lexact, max(L̂, L / β))` when it is
not. `c` carries no rounding certificate: when `L` is within rounding of the
curvature along `d̂`, the decision can go either way. For Float32 data the
squared norms are accumulated in Float64, and two allowances are added to
`‖fl(X d̂)‖` before squaring: `2√n p floatmin(Float32)` for underflow of the
results, and `√n floatmin(Float32) ‖d̂‖₁` for subnormal entries of `X` that a
thread flushing subnormals to zero (the calling thread or a BLAS thread) drops
from the product. They assume that flushing affects only subnormal operands and
results, and give no certificate. The curvature value compared with `L`, in
Float64, is then positive when finite, so a product lost to underflow or
flushing does not make it zero. The estimate used for a retry is that value
rounded to Float32, which may round to Inf (when the conversion overflows).
TFOCS's update is kept when the product overflowed, when the calling thread
flushes subnormals to zero, and when `d̂` has a subnormal entry. For Float64 data,
overflow or underflow of `‖fl(X d̂)‖²`, underflow of `‖d̂‖²`, and overflow of `‖d̂‖²` for a
step with a nonfinite entry or in a narrow band around the overflow threshold of `‖d‖²`
(where `norm(d)^2` can be finite and `sum(abs2, d)` not) can make `c` nonfinite (TFOCS's
update is then kept) or spuriously zero (the trial is then accepted). A rejection is not
checked, and keeps TFOCS's update, when its trial value is not finite, when the
computed `‖d̂‖²` is zero (the zero-step exit, which includes a tiny nonzero step
whose square underflows), when `L̂` is NaN, or when a gradient estimate comes
from a gradient `∇f(x)` with a nonfinite entry. Accepted trials are not checked.

When the step `d = x - x'` of a trial has finite entries, `norm(d)^2` overflows in the type of
`x` (the squared norm is `Inf`) and the trial value `f(x)` is finite, the trial is decided on the
scaled step `d̃ = s d`, `s = 2^(-e)` with `e = min(exponent(max |dᵢ|), exponent(floatmax(T)) - 1)`
for the type `T` of `x`, so that `s` is a normal number and the largest entry of `d̃` is in
`[1, 2)`, or in `[2, 4)` when `exponent(max |dᵢ|)` is `exponent(floatmax(T))`. A trial whose
value `f(x)` is not finite is not scaled: it gives no estimate and the search retries with
`L ← L / β`, as above. `L̂` is formed from `d̃`, from `f(x)` and `f(x')` multiplied by `s²` (by
shifting their exponents, since `s²` can underflow), and from the products of `d̃` and `∇f`
multiplied by `s`; in exact arithmetic it equals the estimate at `d`. The trial is then decided
as at a representable scale, up to the rounding of the computed `f` and `∇f`, overflow of the
products `⟨d̃, ∇f(x')⟩` and `⟨∇f(x) - ∇f(x'), d̃⟩` before they are multiplied by `s` (an overflow,
or a NaN from overflowed terms of opposite sign), and underflow of an entry of `d̃`, of a scaled
function value or of `L̂`. The check of a rejected trial reads `d̃`, with `‖d̃‖²` between 1 and
about `16n`; for Float32 data it is also subject to the allowances above, and an entry of `d̃`
that is subnormal keeps TFOCS's update, while an entry of `d` with `|s dᵢ| ≤ 2^-150` rounds to zero
in `d̃`, is not detected, and drops out of both sums of squares and of the product. After an
accepted trial the solver state holds `x - x'` again. A step with a nonfinite entry is not
scaled, and neither is a step whose squared norm underflows.
See [numerical behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/).

The object holds settings only and can be shared between solves; the
bookkeeping lives in the solver state.
"""
struct BackTracking{T<:Real}
    α::T
    β::T
    Lexact::T
    # The only constructor, so every route into a BackTracking is validated.
    function BackTracking(α::T, β::T, Lexact::T) where {T<:Real}
        0 < α <= 1 && 0 < β < 1 && Lexact > 0 ||
            throw(ArgumentError("backtracking needs 0 < α <= 1, 0 < β < 1, and Lexact > 0"))
        new{T}(α, β, Lexact)
    end
end

# The settings are also checked before their conversion to floating point.
function BackTracking(; α::Real = 0.9, β::Real = 0.5, Lexact::Real = Inf)
    0 < α <= 1 && 0 < β < 1 && Lexact > 0 ||
        throw(ArgumentError("backtracking needs 0 < α <= 1, 0 < β < 1, and Lexact > 0"))
    BackTracking(promote(float(α), float(β), float(Lexact))...)
end

function next_curvature(L, β)
    next = typeof(L)(L / β)
    isfinite(next) && next > L || error("line search failed: the curvature estimate cannot increase finitely")
    next
end

# f(x) and ∇f(x) at the trial point state.x, into state.grad_f_x; the PGD state
# computes them from its LS image cache (see image_models.jl)
function value_and_gradient_at_x! end

# check_rejection!(state, gradient_mode) returns (c ≤ L, c) for a rejected trial with d̂ ≠ 0,
# with c the computed curvature of the step in the mode of its estimate (twice α‖X d̂‖²/‖d̂‖²
# in gradient mode). d̂ is state.delta_x: the step x - x', or, when backtrack! has scaled it (its
# squared norm overflows with finite entries and f(x) is finite), that step times a power of two,
# for which c is the same in exact arithmetic. The PGD state implements it with its LS model
# (proximal_gradient_descent.jl).
function check_rejection! end

# The step of a trial whose squared norm overflowed while its entries are finite, with m the
# largest absolute entry: scale state.delta_x in place by s = 2^k, with
# k = -min(exponent(m), exponent(floatmax(T)) - 1) for the type T of m, so that s ≥ floatmin(T)
# is a normal number and the largest entry is in [1, 2), or in [2, 4) when exponent(m) is
# exponent(floatmax(T)). It returns (s² f(x), s² f(x'), s, the squared norm of the scaled
# step). The function values are scaled by shifting their exponents by 2k, so that s², which can
# underflow, is not formed. It is a separate, non-inlined function so that its code stays out of
# backtrack!.
@noinline function _scale_overflowing_step!(state, m::T) where T
    k = -min(exponent(m), exponent(floatmax(T)) - 1)
    s = ldexp(one(T), k)
    state.delta_x .*= s
    ldexp(state.f_x, 2k), ldexp(state.f_x_previous, 2k), s, _norm(state.delta_x)^2
end

function backtrack!(state, ls::BackTracking{T}, f, g) where T

    # Quick exit if no progress made
    _sub!(state.delta_x, state.x, state.x_previous)
    xy_sq = _norm(state.delta_x)^2

    if xy_sq == zero(T) && isfinite(state.f_x)
      # in the gradient mode, update_state! expects ∇f(x), but state.grad_f_x may
      # hold the gradient at a rejected trial point
      if !state.backtrack_simple
          value_and_gradient_at_x!(state, f)
          state.f_calls += 1
          state.grad_calls += 1
      end
      return true
    end

    # A nonfinite LS trial value supplies neither curvature estimate. Shrink
    # the step, past Lexact if need be, since such a point
    # is never accepted. Taking L̂ = Inf would set L = Inf, and the next trial,
    # with step 0, would return x_previous as if converged.
    if !isfinite(state.f_x)
        state.backtrack_steps += 1
        state.L = next_curvature(state.L, ls.β)
        state.verified_rejection = false
        return false
    end

    # When the squared norm of the step overflows while its entries are finite (and f(x) is
    # finite, since a trial with a nonfinite f(x) has already returned above), the estimates
    # below and the check of a rejection use the step scaled by a power of two, with f(x) and
    # f(x') scaled to match (fx, fp) and the gradient products by sd; otherwise fx and fp are
    # f(x) and f(x'), sd is 1 and the step is unchanged. With a nonfinite entry the step is not
    # scaled.
    fx, fp, sd = state.f_x, state.f_x_previous, one(state.f_x)
    scaled = false
    if isinf(xy_sq)
        m = _norm_inf(state.delta_x)
        if isfinite(m)
            fx, fp, sd, xy_sq = _scale_overflowing_step!(state, m)
            scaled = true
        end
    end

    local_l = Inf
    gradient_mode = !state.backtrack_simple
    # Compute Lipschitz estimate
    if state.backtrack_simple
        q_x = fp + sd * _dot( state.delta_x, state.grad_f_x_previous ) + 0.5 * state.L * xy_sq
        local_l = state.L + 2. * max( fx - q_x, zero(T) ) / xy_sq
        # as in TFOCS, keep the function value estimate while f(x) and f(x') are far
        # enough apart to compare in floating point, then switch for good to the
        # gradient estimate, which needs ∇f(x)
        state.backtrack_simple = abs( state.f_x_previous - state.f_x ) >= 1e-10 * max( abs( state.f_x ), abs( state.f_x_previous ) )
        if !state.backtrack_simple
            value_and_gradient_at_x!(state, f)
            state.f_calls += 1
            state.grad_calls += 1
        end
    else
        value_and_gradient_at_x!(state, f)
        state.f_calls += 1
        state.grad_calls += 1
        local_l = _dot_diff(T, state.grad_f_x, state.grad_f_x_previous, state.delta_x)
        local_l *= 2. / xy_sq
        local_l *= sd
    end

    # Exit if Lipschitz criterion satisfied, or if we hit Lexact. After an acceptance of a
    # scaled step, state.delta_x is set back to x - x_previous, which the stopping tests read.
    # A rejection after the scaling returns with the scaled step in state.delta_x: the next trial
    # starts with _sub!, and an error ends the update, after which solve! restores x from
    # x_previous.
    state.backtrack_steps += 1;
    if local_l <= state.L || state.L >= ls.Lexact
        scaled && _sub!(state.delta_x, state.x, state.x_previous)
        return true
    end
    # A rejection with a non-NaN estimate is decided again by the computed curvature c of the
    # step in the mode in which the estimate was formed (of the scaled step when it was
    # scaled); in gradient mode, only when ∇f(x) is finite. With L ≥ c the trial is accepted
    # and the mode is unchanged; for Float64 data this includes a c that over- or underflow of
    # a sum of squares makes spuriously zero (see _step_curvature). Otherwise a finite c
    # replaces the estimate; a nonfinite c (Inf or NaN, from overflow in the product, for
    # Float32 data also from a calling thread that flushes subnormals or a subnormal entry of
    # d̂, and for Float64 data from over- or underflow of a sum of squares) leaves TFOCS's
    # estimate. A NaN estimate, or a gradient estimate from a nonfinite ∇f(x), is kept: the
    # update and the error check below run on it as before. A
    # NaN estimate raises the error; an infinite one raises it unless a finite Lexact caps L.
    # verified: this rejection's check ran and replaced L̂ by a finite computed curvature c
    verified = false
    if !isnan(local_l) && (!gradient_mode || all(isfinite, state.grad_f_x))
        accepted, c = check_rejection!(state, gradient_mode)
        if accepted
            scaled && _sub!(state.delta_x, state.x, state.x_previous)
            return true
        end
        verified = isfinite(c)
        verified && (local_l = c)
    end
    # recorded for PGD's stagnation test: whether this retry's L̂ is such a curvature
    state.verified_rejection = verified
    state.L = min( ls.Lexact, max( local_l, next_curvature(state.L, ls.β) ) )
    isfinite(state.L) || error("line search failed: nonfinite curvature estimate")

    return false
end

has_updated_gradient(state, ::BackTracking) = state.backtrack_simple == false

end
