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
squared norms are accumulated in Float64, and the allowance
`2√n p floatmin(Float32)` for the underflow contribution to the product under
gradual underflow is added to `‖fl(X d̂)‖` before squaring; the curvature value
compared with `L`, in Float64, is then positive when finite, so a product lost
to underflow does not make it zero. The estimate used for a retry is that value
rounded to Float32 (Inf above `floatmax(Float32)`). A product that overflowed
gives a nonfinite value, and TFOCS's update is kept; so it is when the calling
thread flushes subnormals to zero, where the product can drop subnormal
operands. For Float64 data, over- or underflow of `‖fl(X d̂)‖²` or
`‖d̂‖²` can make `c` nonfinite (TFOCS's update is then kept) or spuriously zero
(the trial is then accepted). A rejection is not
checked, and keeps TFOCS's update, when its trial value is not finite, when the
computed `‖d̂‖²` is zero (the zero-step exit, which includes a tiny nonzero step
whose square underflows), when `L̂` is NaN, or when a gradient estimate comes
from a gradient `∇f(x)` with a nonfinite entry. Accepted trials are not checked.
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
# in gradient mode). The PGD state implements it with its LS model (proximal_gradient_descent.jl).
function check_rejection! end

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
        return false
    end

    local_l = Inf
    gradient_mode = !state.backtrack_simple
    # Compute Lipschitz estimate
    if state.backtrack_simple
        q_x = state.f_x_previous + _dot( state.delta_x, state.grad_f_x_previous ) + 0.5 * state.L * xy_sq
        local_l = state.L + 2. * max( state.f_x - q_x, zero(T) ) / xy_sq
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
    end

    # Exit if Lipschitz criterion satisfied, or if we hit Lexact
    state.backtrack_steps += 1;
    (local_l <= state.L || state.L >= ls.Lexact) && return true
    # A rejection with a non-NaN estimate is decided again by the computed curvature c of the
    # step in the mode in which the estimate was formed; in gradient mode, only when ∇f(x) is
    # finite. With L ≥ c the trial is accepted and the mode is unchanged; for Float64 data
    # this includes a c that over- or underflow of a sum of squares makes spuriously zero (see
    # _step_curvature). Otherwise a finite c replaces the estimate; a nonfinite c (Inf or NaN,
    # from overflow in the product, for Float32 data from a thread that flushes subnormals, and
    # for Float64 data from over- or underflow of a sum of squares) leaves TFOCS's estimate. A NaN estimate, or a gradient estimate from a
    # nonfinite ∇f(x), is kept: the update and the error check below run on it as before. A
    # NaN estimate raises the error; an infinite one raises it unless a finite Lexact caps L.
    if !isnan(local_l) && (!gradient_mode || all(isfinite, state.grad_f_x))
        accepted, c = check_rejection!(state, gradient_mode)
        accepted && return true
        isfinite(c) && (local_l = c)
    end
    state.L = min( ls.Lexact, max( local_l, next_curvature(state.L, ls.β) ) )
    isfinite(state.L) || error("line search failed: nonfinite curvature estimate")

    return false
end

has_updated_gradient(state, ::BackTracking) = state.backtrack_simple == false

end
