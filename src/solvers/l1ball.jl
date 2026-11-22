# The opt-in numerical route for IndBallL1 under PGD and APG (#457 Phase B, policy B1 of #515): dense Float32 or
# Float64 least squares, raw or with one positive scale, on a Vector{T}, selected by
# solve!(x, f, IndBallL1(r), method, options; feasibility = NumericalFeasibility(...)). The gate is
# _check_numerical_l1 (src/solve.jl, IN-12). The route runs the engine of the other penalties (_solve_gradient!, PGD's
# update_state! and backtrack!, APG's update_state!, restart and certified bound) with this file's methods of the
# engine's hooks: _trial! and _begin_trials! (PGD-09); convergence_assessment, _stationary! and
# _stop_on_gradient_increase (STOP-22); and the result hooks of _solve_gradient! (RES-04). The arithmetic of the
# decision, the budgets and the full check is that of research/issue-515/b1.jl at d58b9099 and of the B0 helpers it
# imports (research/issue-514), with the same reductions, loops and Float64 conversions in the same order (FP-05).
#
# Ownership (PGD-09): within an iteration only trials write state.x; each trial that projects into state.x stores the
# decision of that vector in `decision` right after the projection, and a trial with a nonfinite xhat writes neither,
# so `decision` describes state.x after every trial. The full check (_stationary! below) writes this object's
# workspace and the two counters, not state.x. After a failed step the engine copies x_previous into x and rethrows,
# so no result is built from a rolled-back state, whose `decision` can describe a rejected trial.

# The trials from one base point after which the next trial raises the line-search error (B1's 64, maintainer's I4)
const _L1_TRIAL_LIMIT = 64

# B1's `Decision` without its `refined` field (always false in B1): the code against the cap, the membership, the
# margin s - r, the widened mass s and its noise, all from _l1_decision.
struct _L1Decision
  code::Symbol         # :pass, :over or :unresolved
  membership::Symbol   # :inside, :outside or :unknown
  margin::Float64
  s::Float64
  noise::Float64
end

# The route's working constraint: the user's ball, the data and loss scale, the budgets of the solve, the decision of
# the vector last projected into state.x (initialised with the decision of the start), the full-check workspace, the
# diagnostics of the last full check (NaN before the first) and the counts of full checks, of trials from the current
# base point and of iterations. Built once per solve after the gate.
mutable struct _NumericalL1Ball{T<:Union{Float32, Float64}}
  ball::IndBallL1{T}
  X::Matrix{T}
  y::Vector{T}
  alpha::Float64          # Float64 of the loss scale as supplied, 1.0 for a raw loss
  cap::Float64
  gap_budget::Float64
  mapping_budget::Float64
  curvature::Float64      # α maxⱼ ‖Xⱼ‖² (1.0 for X = 0), the fixed inverse step of the mapping
  col::Float64            # maxⱼ ‖Xⱼ‖
  frob::Float64           # ‖X‖_F
  ynorm::Float64          # ‖y‖
  decision::_L1Decision
  witness::Vector{Float64}
  residual::Vector{Float64}
  gradient::Vector{Float64}
  trial::Vector{T}
  projected::Vector{T}
  gap::Float64
  gap_noise::Float64
  mapping::Float64
  map_noise::Float64
  checks::Int
  approximate::Bool       # the last assessment passed its full check at a point not classified inside
  trials::Int
  maxiter::Int
  iteration::Int
end

# The penalty value that initial_state reads (g_x = T(g(x0))); a start that passes the cap can lie outside PB's ball,
# whose indicator would then be Inf. The trials set g_x = 0 too.
(g::_NumericalL1Ball{T})(x) where T = zero(T)

function _NumericalL1Ball(ball::IndBallL1{T}, X::Matrix{T}, y::Vector{T}, alpha::Float64, b, decision::_L1Decision,
                          maxiter::Int) where T
  n, p = size(X)
  _NumericalL1Ball{T}(ball, X, y, alpha, b.cap, b.gap, b.mapping, b.curvature, b.col, b.frob, b.ynorm, decision,
                      zeros(p), zeros(n), zeros(p), zeros(T, p), zeros(T, p), NaN, NaN, NaN, NaN, 0, false, 0,
                      maxiter, 0)
end

# ---- B1's arithmetic (FP-05) -------------------------------------------------------------------------------------------

# ‖x‖₂ in Float64 by scaling with m = maxᵢ |Float64(xᵢ)|; m itself when m is 0 or not finite (B1's norm2_64, with the
# annotation on the maximum that makes it concrete for Float32 input).
function _norm2_64(x)
  m = maximum(a -> abs(Float64(a)), x)::Float64
  (iszero(m) || !isfinite(m)) && return m
  m * sqrt(sum(a -> abs2(Float64(a) / m), x))
end

# The widened mass s = Σ |Float64(xᵢ)| (B1's norm_64 for the ℓ1 ball)
_l1_mass64(x) = sum(a -> abs(Float64(a)), x)

# γₖ = k u / (1 - k u), u = eps(Float64)/2 (B0's gamma64)
_gamma64(k) = (c = k * (eps(Float64) / 2); c / (1 - c))

# The noise of a widened mass s of a vector with `len` entries against the radius r (B1's norm_noise)
_l1_noise(len, s, r) = _gamma64(len + 2) * max(s, r)

# The decision of x against the radius of `ball` and the cap (B1's norm_decision): m = s - r; with noise
# ν = γ(p+2) max(s, r), membership :outside when m > ν, :inside when m < -ν or s = 0 < r, :unknown otherwise, and
# code :pass when m - cap < -ν, :over when m - cap > ν, :unresolved otherwise; a nonfinite m is :unresolved and
# :unknown with noise NaN.
function _l1_decision(x, ball::IndBallL1, cap::Float64)
  s = _l1_mass64(x)
  r = Float64(ball.r)
  m = s - r
  isfinite(m) || return _L1Decision(:unresolved, :unknown, m, s, NaN)
  noise = _l1_noise(length(x), s, r)
  membership = m > noise ? :outside : m < -noise ? :inside :
               iszero(s) && r > 0 ? :inside : :unknown
  separation = m - cap
  code = separation < -noise ? :pass : separation > noise ? :over : :unresolved
  _L1Decision(code, membership, m, s, noise)
end

# The budgets of a solve (B1's budgets for the ℓ1 ball), from the Float64 loss scale α, the Float64 radius r and the
# Float64 tolerances: with M = √α maxⱼ‖Xⱼ‖ and ŷ = √α ‖y‖, the objective scale max(ŷ, M r)²/2, the gap budget
# objective_rtol times half of it, the cap min(r, coefficient_atol + coefficient_rtol r, gap/(M ŷ + 1.5 M² r)) (the
# last term Inf when its denominator is 0), the curvature α maxⱼ‖Xⱼ‖² (1.0 for X = 0) and the mapping budget
# mapping_rtol M max(ŷ, M r).
function _l1_budgets(X, y, alpha::Float64, r::Float64, a)
  ynorm = _norm2_64(y)
  yscaled = sqrt(alpha) * ynorm
  col = maximum(_norm2_64, eachcol(X))
  frob = _norm2_64(X)
  M = sqrt(alpha) * col
  cost = M * yscaled + 1.5 * M^2 * r
  scale = max(yscaled, sqrt(alpha) * col * r)^2 / 2
  gap = a.objective_rtol * scale / 2
  cap = min(r, a.coefficient_atol + a.coefficient_rtol * r, iszero(cost) ? Inf : gap / cost)
  curvature = col > 0 ? alpha * col^2 : 1.0
  mapping = a.mapping_rtol * sqrt(alpha) * col * max(yscaled, sqrt(alpha) * col * r)
  (; cap, gap, mapping, curvature, col, frob, ynorm)
end

# The radial witness w = factor x in Float64 from the widened mass s of x and its noise (B1's numerical_witness!):
# factor = 1 when s + noise < r, min(1, (r - noise)/s) otherwise.
function _l1_witness!(w, x, r::Float64, s::Float64, noise::Float64)
  factor = s + noise < r ? 1.0 : min(1.0, (r - noise) / s)
  @. w = factor * Float64(x)
end

# res = X w - y and grad = Xᵀ res in Float64 (B0's residual_score64!): BLAS for Float64 data, and for Float32 data the
# products of Float64(Xᵢⱼ) in column loops.
function _residual_score64!(grad, res, X::Matrix{Float64}, y, w)
  mul!(res, X, w)
  res .-= y
  mul!(grad, transpose(X), res)
  nothing
end

function _residual_score64!(grad, res, X::Matrix{Float32}, y, w)
  fill!(res, 0)
  @inbounds for j in eachindex(w)
    wj = w[j]
    @simd for i in eachindex(res)
      res[i] += Float64(X[i,j]) * wj
    end
  end
  res .-= y
  @inbounds for j in eachindex(grad)
    s = 0.0
    @simd for i in eachindex(res)
      s += Float64(X[i,j]) * res[i]
    end
    grad[j] = s
  end
  nothing
end

# The support gap max(0, r - ‖w‖₁) δ + Σⱼ |wⱼ| (δ + sign(wⱼ) gradⱼ), δ = ‖grad‖∞ (B0's estimate_gap for the ℓ1 ball)
function _l1_support_gap(w, grad, r::Float64, dual)
  s = max(0.0, r - _l1_mass64(w)) * dual
  @inbounds for j in eachindex(w, grad)
    s += abs(w[j]) * (dual + (signbit(w[j]) ? -grad[j] : grad[j]))
  end
  s
end

# ---- the hooks ----------------------------------------------------------------------------------------------------------

# PGD-09: a search from one base point starts with no trials.
_begin_trials!(g::_NumericalL1Ball) = (g.trials = 0; nothing)

@noinline _l1_trial_limit_error() =
  error("line search failed: $_L1_TRIAL_LIMIT trials from one base point were not accepted (IndBallL1 numerical route, PGD-09)")

# PGD-09: B1's trial_value!, after the trial limit. With a nonfinite xhat, f_x = Inf without a projection or a count.
# Otherwise PB's projection of xhat into x (one prox call), the decision of x, stored in g.decision, and for :pass the
# image and loss value of x (one f call) with g_x = 0; for :over and :unresolved, f_x = Inf without a loss value, so
# that backtrack! takes its nonfinite branch and APG raises L.
function _trial!(state, f, g::_NumericalL1Ball{T}) where T
  g.trials < _L1_TRIAL_LIMIT || _l1_trial_limit_error()
  g.trials += 1
  if !_allfinite(state.xhat)
    state.f_x = T(Inf)
    return nothing
  end
  prox!(state.x, g.ball, state.xhat, one(state.L) / state.L)
  state.prox_calls += 1
  test = _l1_decision(state.x, g.ball, g.cap)
  g.decision = test
  if test.code === :pass
    state.f_calls += 1
    state.f_x = _value!(state.x, f, state.model, state.z_x)
    state.g_x = zero(T)
  else
    state.f_x = T(Inf)
  end
  nothing
end

# STOP-22: the engine's three proposals, computed by the method of the other penalties (through _PROPOSALS, whose
# check passes), and B1's two structural proposals: the last iteration (maxiter) and an accepted iterate equal to the
# previous one elementwise, also with ftol = 0. A proposal runs the full check. When it passes at a point classified
# :inside, converged = true and the proposal flags are kept; otherwise they are cleared and converged = false, and a
# passing check at a point classified :outside or :unknown stops the solve as an approximate solution
# (_approximate_solution below).
function convergence_assessment(state::Union{ProximalGradientDescentState, AccProxGradDescentState},
                                f, g::_NumericalL1Ball, options::ProximalOptions)
  x_converged, f_converged, grad_converged, _, f_increased = convergence_assessment(state, f, _PROPOSALS, options)
  g.iteration += 1
  proposed = x_converged || f_converged || grad_converged || g.iteration == g.maxiter ||
             _unchanged(state.x, state.x_previous)
  passed = proposed && _stationary!(state, f, g, options)
  inside = g.decision.membership === :inside
  g.approximate = passed && !inside
  converged = passed && inside
  converged || (x_converged = f_converged = grad_converged = false)
  return x_converged, f_converged, grad_converged, converged, f_increased
end

# STOP-22: B1's stop_scores! at state.x with the cached decision g.decision (which describes state.x after an accepted
# step, PGD-09). A decision other than :pass runs no check and returns false, as in B1. Otherwise: the radial witness
# from the cached s and noise; the residual and gradient at the witness in Float64, times α; the support gap and the
# fixed-step mapping at the inverse step T(curvature) through PB's projection, each with its noise; the check passes
# when the four values are finite, gap + gap noise ≤ gap budget and mapping + map noise ≤ mapping budget. It counts one
# gradient and one prox call, stores the diagnostics in g, and writes no other field of state.
function _stationary!(state, f, g::_NumericalL1Ball{T}, options::ProximalOptions) where T
  dec = g.decision
  dec.code === :pass || return false
  x = state.x
  w, res, grad = g.witness, g.residual, g.gradient
  r = Float64(g.ball.r)
  _l1_witness!(w, x, r, dec.s, dec.noise)
  _residual_score64!(grad, res, g.X, g.y, w)
  grad .*= g.alpha
  dual = maximum(abs, grad)
  n, p = size(g.X)
  alpha = g.alpha
  residual_noise = _gamma64(p+2) * (g.frob * _norm2_64(w) + g.ynorm)
  score_noise = alpha * (residual_noise + _gamma64(n+2) * _norm2_64(res))
  gap_noise = 2r * g.col * score_noise +
              _gamma64(2p+12) * (2r * dual) + _l1_noise(length(w), r, r) * dual
  gap = _l1_support_gap(w, grad, r, dual)
  L = T(g.curvature)
  trial, projected = g.trial, g.projected
  @. trial = T(w) - T(grad) / L
  prox!(projected, g.ball, trial, one(T)/L)
  mapping = Float64(L) * maximum(j -> abs(Float64(T(w[j])) - Float64(projected[j])), eachindex(w))
  map_noise = g.col * score_noise + Float64(eps(T)) * (Float64(L) * maximum(abs, w) + maximum(abs, grad))
  finite = all(isfinite, (gap, gap_noise, mapping, map_noise))
  pass = finite && gap + gap_noise <= g.gap_budget && mapping + map_noise <= g.mapping_budget
  state.grad_calls += 1
  state.prox_calls += 1
  g.checks += 1
  g.gap, g.gap_noise, g.mapping, g.map_noise = gap, gap_noise, mapping, map_noise
  pass
end

# STOP-22 and RES-04: an objective increase does not end the solve on this route (the decision I5).
_stop_on_gradient_increase(state, ::_NumericalL1Ball, options) = false

# RES-04: the result hooks of _solve_gradient!. The membership is that of g.decision, the vector last projected into
# state.x, which on a normal return is the returned point.
_approximate_solution(g::_NumericalL1Ball) = g.approximate
function _composite_minimum(state, g::_NumericalL1Ball)
  membership = g.decision.membership
  membership === :inside ? state.f_x : membership === :outside ? oftype(state.f_x, Inf) : oftype(state.f_x, NaN)
end
_feasibility_report(g::_NumericalL1Ball) =
  NumericalFeasibilityReport(g.decision.membership, g.decision.margin, g.cap, g.gap, g.gap_noise, g.gap_budget,
                             g.mapping, g.map_noise, g.mapping_budget, g.checks)

# The route's solve after the keyword check of solve!: the gate (before any write to x), then the clock, the route
# object, the state and the engine, as for the other penalties.
function _solve_numerical_l1!(x, f, g, feasibility, method, options, kind::Symbol)
  checked = _check_numerical_l1(x, f, g, feasibility, method, kind)
  t0 = time()
  _run_numerical_l1!(x, f, g, checked, method, options, t0)
end

function _run_numerical_l1!(x::Vector{T}, f, ball::IndBallL1{T}, checked, method, options, t0) where T
  d = checked.data
  route = _NumericalL1Ball(ball, d.X, d.Y, checked.alpha, checked.budgets, checked.decision, Int(options.maxiter))
  state = initial_state(method, options, f, route, x)
  _solve_gradient!(state, f, route, method, options, t0)
end
