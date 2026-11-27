module LineSearches

using ..Blocks

export
  backtrack!,has_updated_gradient,
  BackTracking

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

# trial!(state, f, g) forms and evaluates one trial at state.L (methods: utils.jl, solvers/l1ball.jl).
function trial! end

include("backtracking.jl")

end
