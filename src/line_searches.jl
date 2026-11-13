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

For [`ProximalGradientDescent`](@ref) on its supported least-squares model, a
rejection is checked by the certified least-squares bound that
`AccProxGradDescent` uses: `√α ‖X d‖ ≤ (1 + 4eps) √L ‖d‖` for function-value
estimates, and the same with `2α` for gradient estimates. A rejection is not
checked, and keeps TFOCS's update, when its trial value is not finite, when the
computed `‖d̂‖²` is zero (the zero-step exit, which includes a tiny nonzero step
whose square underflows), when `L̂` is NaN, or when a gradient estimate comes
from a gradient `∇f(x)` with a nonfinite entry. When the bound is certified, the
rejection was decided by rounding or lies within the slack `(1 + 4eps)²` on `L`:
the trial is accepted, and function-value estimates end for the rest of the
solve. Otherwise the retry uses
`L ← min(Lexact, max(min(L̂, U), L / β))`, where `U` is a certified upper bound
on the `L` that the bound needs for that step. Accepted trials are not checked.
When `max(n, p) + 4 ≥ 1/(4 eps(T))` or `n p + 3 ≥ 1/(4 eps(Float64))`, the check
is skipped and the rejection stands. See
[numerical behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/).

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

# verify_rejection!(state, gradient_mode) checks a rejected trial with d ≠ 0 against the
# curvature bound of its mode: (true, _) when the bound is certified, otherwise (false, U)
# with U an upper bound on the L the bound needs, Inf when there is none. The PGD state
# implements it with its LS image cache (proximal_gradient_descent.jl).
function verify_rejection! end

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
    # A rejection with a non-NaN estimate is checked against the bound of the mode in which
    # the estimate was formed; in gradient mode, only when ∇f(x) is finite. When the bound is
    # certified, the estimate was decided by rounding or lies within the slack (1 + 4eps)² on
    # L: the trial is accepted, and function-value mode ends as at a switch. Otherwise the
    # estimate is capped by the upper bound U. A NaN estimate, or a gradient estimate from a
    # nonfinite ∇f(x), is kept: the update and the error check below run on it as before. A
    # NaN estimate raises the error; an infinite one raises it unless a finite Lexact caps L.
    if !isnan(local_l) && (!gradient_mode || all(isfinite, state.grad_f_x))
        refuted, U = verify_rejection!(state, gradient_mode)
        if refuted
            if state.backtrack_simple
                state.backtrack_simple = false
                value_and_gradient_at_x!(state, f)
                state.f_calls += 1
                state.grad_calls += 1
            end
            return true
        end
        local_l = min(local_l, U)
    end
    state.L = min( ls.Lexact, max( local_l, next_curvature(state.L, ls.β) ) )
    isfinite(state.L) || error("line search failed: nonfinite curvature estimate")

    return false
end

has_updated_gradient(state, ::BackTracking) = state.backtrack_simple == false

end
