# The numerical route for IndBallL1 under PGD and APG (#457, policy B1 of #515; IN-12): dense Float32 or Float64 least
# squares, raw or with one positive scale, on a Vector{T}. solve! takes it for every IndBallL1; the keyword
# `feasibility = NumericalFeasibility(...)` overrides the tolerances. The gate is _check_numerical_l1 (src/solve.jl).
# The route runs the engine of the other penalties (_solve_gradient!, PGD's update_state! and backtrack!, APG's
# update_state!, restart and certified bound) with this file's methods of trial!, search!, _prox_grad_step!,
# convergence_assessment, _stationary! and _stop_on_gradient_increase. Apart from the underflow allowance, the
# formulas and the reduction order of the decision (without its membership class), the budgets and the full check are
# those of research/issue-515/b1.jl at d58b9099 and of the B0 helpers it imports (research/issue-514), for comparable
# finite calculations (FP-05).
#
# Within a completed step only trials write state.x; each trial that projects into state.x stores the decision of that
# vector in `decision`, and a trial with a nonfinite xhat writes neither, so `decision` describes state.x after every
# completed trial. After a failed step the engine copies x_previous into x and rethrows. The solver does not detect a
# change of x by a callback; these statements assume that callbacks leave x unchanged.

# The trials from one base point after which the next trial raises the line-search error
const _L1_TRIAL_LIMIT = 64

# The decision of a vector (_l1_decision): the code against the cap, the widened mass s and its noise
struct _L1Decision
  code::Symbol         # :pass, :over or :unresolved
  s::Float64
  noise::Float64
end

# The route's working constraint, built once per solve after the gate: the private ball, the data and loss scale, the
# budgets, the decision of the vector last projected into state.x (initially the start's), the full-check workspace,
# the trials from the current base point, whether the current assessment ran the full check, and the resolved
# objective and mapping tolerances of B1's progress proposals.
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
  trials::Int
  checked::Bool
  objective_rtol::Float64
  mapping_rtol::Float64
  underflow::@NamedTuple{n_p_eta::Float64, n_eta::Float64, p1_eta::Float64, p_eta::Float64, p_eta_t::Float64,
                         sqrt_n_col_product::Float64, gradient_error_product::Float64,
                         curvature_eta_t_product::Float64, division_cap_product::Float64,
                         curvature_p_eta_t_product::Float64}
  # (underflow: _l1_underflow_terms(T, n, p, α, C, L))
end

# The penalty value that initial_state and the trials store (g_x = 0). A start that passes the cap can lie outside the
# ball, where the mathematical indicator is Inf; the route does not evaluate it, and minimum is the monitored
# f_x + g_x (IN-12).
(g::_NumericalL1Ball{T})(x) where T = zero(T)

function _NumericalL1Ball(ball::IndBallL1{T}, X::Matrix{T}, y::Vector{T}, alpha::Float64, b, tolerances,
                          decision::_L1Decision) where T
  n, p = size(X)
  _NumericalL1Ball{T}(ball, X, y, alpha, b.cap, b.gap, b.mapping, b.curvature, b.col, b.frob, b.ynorm, decision,
                      zeros(p), zeros(n), zeros(p), zeros(T, p), zeros(T, p), 0, false,
                      tolerances.objective_rtol, tolerances.mapping_rtol,
                      _l1_underflow_terms(T, n, p, alpha, b.col, Float64(T(b.curvature))))
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

# The decision of x against the radius of `ball` and the cap (B1's norm_decision without its membership class, which
# the route does not read): m = s - r; with noise ν = γ(p+2) max(s, r), code :pass when m - cap < -ν, :over when
# m - cap > ν, :unresolved otherwise; a nonfinite m is :unresolved with noise NaN.
function _l1_decision(x, ball::IndBallL1, cap::Float64)
  s = _l1_mass64(x)
  r = Float64(ball.r)
  m = s - r
  isfinite(m) || return _L1Decision(:unresolved, s, NaN)
  noise = _l1_noise(length(x), s, r)
  separation = m - cap
  code = separation < -noise ? :pass : separation > noise ? :over : :unresolved
  _L1Decision(code, s, noise)
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

# ---- the absolute underflow allowance of the full check (FP-05) ----------------------------------------------------------

const _ETA64 = nextfloat(0.0)

# An upper bound of the exact product of two nonnegative upper bounds a and b under the model fl(a b) = a b (1 + δ) + ε,
# |δ| ≤ u, |ε| ≤ nextfloat(0.0): Inf when a factor is not finite, so that a selected term is Inf and the check fails (an
# overflowed factor, such as 2α, carries no bound, and the other factor can be a computed zero whose exact value is
# positive; a min with an independent finite cap, itself an upper bound for that error contribution, can replace the
# Inf); otherwise 0 when a factor is 0, and fl(a b) (1 + 4 eps) + η, which covers a product that rounds to a subnormal
# number or to zero, and is Inf when the product overflows.
_mulup(a::Float64, b::Float64) =
  !(isfinite(a) && isfinite(b)) ? Inf : (iszero(a) || iszero(b)) ? 0.0 : (c = a * b; c + 4 * eps(Float64) * c + _ETA64)

# The absolute allowances (gap, mapping) that FP-05 adds to the support-gap and mapping noise of the full check, from
# computed magnitudes: n × p the design, α the loss scale, ρ the radius, C the largest column norm, rnorm = ‖X w - y‖₂,
# sw = ‖w‖₁ and winf = ‖w‖∞ of the witness, dual = ‖g‖∞ of the scaled gradient, L the inverse step as Float64, tinf
# the largest magnitude of the mapping's trial point in T, m0 the largest computed difference of the mapping before
# its product by L, and the computed mapping. The allowance is a sum of terms: the underflow terms are min(k η, a
# product of magnitudes), the propagated terms are products of magnitudes (_mulup), and each term is 0 when its
# magnitudes are exact zeros. The one exception is the final product by L of the mapping, which adds η whenever
# m0 > 0 and the mapping is finite, also when the exact product is below η. Both are Inf (the check fails) when the growth factor 2 of the argument does not hold,
# (n + p + 2) eps(Float64) > 1. k holds the terms of the allowance that depend only on the solve (_l1_underflow_terms
# for the same n, p, T, α, C and L), formed once per solve in the route object.
function _l1_underflow_allowance(::Type{T}, n::Int, p::Int, k, alpha::Float64, ρ::Float64, C::Float64, rnorm::Float64,
                                 sw::Float64, winf::Float64, dual::Float64, L::Float64, tinf::Float64,
                                 m0::Float64, mapping::Float64) where T
  η, ηT = _ETA64, Float64(nextfloat(zero(T)))
  (n + p + 2) * eps(Float64) <= 1 || return Inf, Inf
  # the residual X w - y: one product (or fused multiply-add) per entry of X; the subtraction of y adds no absolute
  # error under gradual underflow. ‖Δr‖₂ ≤ ‖Δr‖₁ ≤ Σᵢⱼ min(η, |Xᵢⱼ wⱼ|) ≤ min(n p η, √n C ‖w‖₁)
  A_r = min(k.n_p_eta, _mulup(k.sqrt_n_col_product, sw))
  # Xᵀ r, per coordinate: Σᵢ min(η, |Xᵢⱼ rᵢ|) ≤ min(n η, C ‖r‖₂), plus the residual error carried through, ‖Xⱼ‖₂ ‖Δr‖₂ ≤ C A_r
  u = _mulup(C, rnorm)
  A_s = min(k.n_eta, u)
  # the multiplication by α scales both and adds one product error, at most min(η, α |Xⱼᵀ r|) ≤ min(η, 2 α C ‖r‖₂); when
  # both minima select their k η term, the first product is the stored k.gradient_error_product
  E_g1 = A_r == k.n_p_eta && A_s == k.n_eta ? k.gradient_error_product : _mulup(alpha, _mulup(C, A_r) + A_s)
  E_g = E_g1 + min(η, _mulup(2alpha, u))
  # the support gap: the gradient error through δ and the sum, 2 max(ρ, ‖w‖₁) E_g; the p + 1 products of its Float64
  # sum, min((p + 1) η, δ (ρ + 2 ‖w‖₁)); the witness entries' product errors through the ρ δ term, min(p η, ‖w‖₁) δ
  gap_abs = _mulup(2 * max(ρ, sw), E_g) + min(k.p1_eta, _mulup(dual, ρ + 2sw)) + _mulup(min(k.p_eta, sw), dual)
  # the mapping L (v - P(v - g/L)) at v = T(w). For the exact projection P(z)ᵢ = sign(zᵢ) max(|zᵢ| - τ(z), 0), each
  # output moves by at most |Δzᵢ| + |Δτ| ≤ 2 ‖Δz‖∞ (the level τ moves by at most ‖Δz‖∞), so an error of the projection
  # input enters the mapping with the factor 2: the gradient error, 2 E_g; for Float32, the conversion of w, which also
  # enters directly (3L), and that of g (2); the division of the converted T(g) by L, which loses at most min(η_T,
  # |T(g)|/L) in its absolute component. The code's term before the inflation is 2 min(L η_T, δ), with δ the Float64
  # gradient; the factor two of FP-05 for computed magnitudes covers the difference for a finite conversion under
  # gradual underflow. It is formed without the quotient δ/L, which can round to zero: the stored double of L η_T
  # (times 2) when that arm wins, _mulup(2.0, δ) when δ wins. The computed projection's own
  # underflow in T and the final product by L in Float64 enter after the projection, with the factor 1. The final
  # product L m0 is exact when m0 = 0; when m0 > 0 the term η bounds the absolute underflow component of that
  # product's error, in FP-05's relative-plus-absolute model, not its full rounding error; it is added also when the
  # computed mapping is 0.
  conv = T === Float64 ? 0.0 : _mulup(3L, min(ηT, winf)) + 2 * min(ηT, dual)
  # (a minimum that selects its per-solve term L η_T or p η_T uses the stored product k.division_cap_product or
  # k.curvature_p_eta_t_product)
  d, q = min(k.curvature_eta_t_product, dual), min(k.p_eta_t, tinf)
  cap_d = d == k.curvature_eta_t_product ? k.division_cap_product : _mulup(2.0, d)
  cap_q = q == k.p_eta_t ? k.curvature_p_eta_t_product : _mulup(L, q)
  final = iszero(m0) ? 0.0 : iszero(mapping) ? η : min(η, mapping)
  map_abs = 2 * E_g + conv + cap_d + cap_q + final
  # the factor 4: 2 for the growth (1 + u)^k ≤ 2 of an absolute error through the later roundings, k ≤ n + p + 2, and
  # 2 for the computed magnitudes in place of the exact ones
  4 * gap_abs, 4 * map_abs
end

# The terms of _l1_underflow_allowance that depend only on the solve, η = nextfloat(0.0) and η_T = nextfloat(zero(T)):
# n p η, n η, (p + 1) η, p η and p η_T, each formed with the expression that the allowance used before they were
# stored, and the _mulup results on per-solve inputs (α, C = maxⱼ‖Xⱼ‖ and the inverse step L as Float64): √n C, the
# product α (C n p η + n η) of E_g, L η_T, its double 2 (L η_T) and L p η_T. The allowance uses a stored product only
# where its minimum selects the same inputs, so each stored value is the one that the same _mulup call returns there.
function _l1_underflow_terms(::Type{T}, n::Int, p::Int, alpha::Float64, C::Float64, L::Float64) where T
  np, nη, pT = Float64(n) * Float64(p) * _ETA64, Float64(n) * _ETA64, Float64(p) * Float64(nextfloat(zero(T)))
  LηT = _mulup(L, Float64(nextfloat(zero(T))))
  (; n_p_eta = np, n_eta = nη, p1_eta = Float64(p + 1) * _ETA64, p_eta = Float64(p) * _ETA64, p_eta_t = pT,
     sqrt_n_col_product = _mulup(sqrt(Float64(n)), C), gradient_error_product = _mulup(alpha, _mulup(C, np) + nη),
     curvature_eta_t_product = LηT, division_cap_product = _mulup(2.0, LηT),
     curvature_p_eta_t_product = _mulup(L, pT))
end

# ---- the hooks ----------------------------------------------------------------------------------------------------------

@noinline _l1_trial_limit_error() =
  error("line search failed: $_L1_TRIAL_LIMIT trials from one base point were not accepted (IndBallL1 numerical route, IN-12)")

# One trial (IN-12): the step into xhat, then the trial limit. With a nonfinite xhat, f_x = Inf without a projection.
# Otherwise PB's projection of xhat into x (one prox call) and the decision of x, stored in g.decision; for :pass the
# loss value of x (one f call) with g_x = 0, and for :over and :unresolved f_x = Inf, which backtrack! and APG reject.
function LineSearches.trial!(state::Union{ProximalGradientDescentState, AccProxGradDescentState}, f,
                             g::_NumericalL1Ball{T}) where T
  _trial_step!(state)
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

# Each search from one base point starts with no trials. After PGD's search, two cases raise an error inside the step,
# so the engine restores x_previous and rethrows: an accepted trial that differs from x_previous while the squared norm
# of x - x_previous (state.delta_x after an acceptance) is zero, which backtrack! accepted as a zero step without its
# test (IN-12), and a nonfinite entry of the gradient at the accepted trial.
@noinline _l1_underflowed_step_error() =
  error("line search failed: the step is nonzero but its squared norm underflows (IndBallL1 numerical route, IN-12)")
@noinline _l1_gradient_error() =
  error("the gradient at the accepted trial has a nonfinite entry (IndBallL1 numerical route, IN-12)")
function LineSearches.search!(state::ProximalGradientDescentState, ls::LineSearches.BackTracking, f,
                              g::_NumericalL1Ball)
  g.trials = 0
  invoke(LineSearches.search!, Tuple{Any, LineSearches.BackTracking, Any, Any}, state, ls, f, g)
  iszero(_norm(state.delta_x)^2) && !_unchanged(state.x, state.x_previous) && _l1_underflowed_step_error()
  _allfinite(state.grad_f_x) || _l1_gradient_error()
end
function _prox_grad_step!(f, g::_NumericalL1Ball, state::AccProxGradDescentState{T}, β::T, limits::Tuple{}) where T
  g.trials = 0
  invoke(_prox_grad_step!, Tuple{Any, Any, AccProxGradDescentState{T}, T, Tuple}, f, g, state, β, limits)
end

# The engine's three proposals and, when one fires, the full check below, through the method of the other penalties.
# When that method ran no check, B1's unchanged-iterate and progress proposals (‖x - x_previous‖∞ at most
# √mapping_rtol ‖x‖∞, or the relative change of the loss at most objective_rtol) trigger it; a pass then reports
# x_converged. So the check runs at most once per assessment, and a proposal is only a trigger. converged is the
# result of the check; when it is false, the three proposal flags are cleared, as in the method of the other penalties.
function convergence_assessment(state::Union{ProximalGradientDescentState, AccProxGradDescentState},
                                f, g::_NumericalL1Ball, options::ProximalOptions)
  g.checked = false
  x_converged, f_converged, grad_converged, passed, f_increased =
    invoke(convergence_assessment, Tuple{Union{ProximalGradientDescentState, AccProxGradDescentState}, Any, Any,
                                         ProximalOptions}, state, f, g, options)
  if !g.checked && (_unchanged(state.x, state.x_previous) ||
                    maximum(abs, state.delta_x) <= sqrt(g.mapping_rtol) * maximum(abs, state.x) ||
                    f_residual(state.f_x, state.f_x_previous, g.objective_rtol) <= g.objective_rtol)
    passed = x_converged = _stationary!(state, f, g, options)
  end
  passed || (x_converged = f_converged = grad_converged = false)
  return x_converged, f_converged, grad_converged, passed, f_increased
end

# The full check (FP-05) at state.x with the cached decision g.decision. A decision other than :pass returns false.
# Otherwise: the radial witness from the cached s and noise; the residual and gradient at the witness in Float64, times
# α; the support gap and the fixed-step mapping at the inverse step T(curvature) through PB's projection, each with its
# noise and underflow allowance; the check passes when the four values are finite, gap + gap noise ≤ gap budget and
# mapping + map noise ≤ mapping budget. The witness, residual and gradient are tested together after the gradient is
# evaluated and counted; then the mapping trial point before its projection, so a nonfinite trial point is never
# projected, and then the projection. A nonfinite entry in any of them (the guarded vectors w, e, g, the trial and q) fails
# the check, as does an infinite product in a selected allowance term (the allowance is then Inf; a min with an
# independent finite cap, itself an upper bound for that error contribution, can replace an infinite inner product).
# It counts the gradient and the prox call that it evaluates (one
# each when it reaches the projection), writes no other field of state and records in g.checked that the assessment
# ran it.
function _stationary!(state, f, g::_NumericalL1Ball{T}, options::ProximalOptions) where T
  g.checked = true
  dec = g.decision
  dec.code === :pass || return false
  x = state.x
  w, res, grad = g.witness, g.residual, g.gradient
  r = Float64(g.ball.r)
  _l1_witness!(w, x, r, dec.s, dec.noise)
  _residual_score64!(grad, res, g.X, g.y, w)
  grad .*= g.alpha
  state.grad_calls += 1
  _allfinite(w) && _allfinite(res) && _allfinite(grad) || return false
  dual = maximum(abs, grad)
  n, p = size(g.X)
  alpha = g.alpha
  # ‖res‖₂ and ‖w‖∞ are formed once; the noise terms and the allowance reuse them
  rnorm = _norm2_64(res)
  winf = maximum(abs, w)
  residual_noise = _gamma64(p+2) * (g.frob * _norm2_64(w) + g.ynorm)
  score_noise = alpha * (residual_noise + _gamma64(n+2) * rnorm)
  gap_noise = 2r * g.col * score_noise +
              _gamma64(2p+12) * (2r * dual) + _l1_noise(length(w), r, r) * dual
  gap = _l1_support_gap(w, grad, r, dual)
  L = T(g.curvature)
  trial, projected = g.trial, g.projected
  @. trial = T(w) - T(grad) / L
  _allfinite(trial) || return false
  prox!(projected, g.ball, trial, one(T)/L)
  state.prox_calls += 1
  _allfinite(projected) || return false
  m0 = maximum(j -> abs(Float64(T(w[j])) - Float64(projected[j])), eachindex(w))
  mapping = Float64(L) * m0
  map_noise = g.col * score_noise + Float64(eps(T)) * (Float64(L) * winf + maximum(abs, grad))
  # the absolute allowance for gradual underflow, added after B1's noise terms
  gap_abs, map_abs = _l1_underflow_allowance(T, n, p, g.underflow, alpha, r, g.col, rnorm, _l1_mass64(w),
                                             winf, dual, Float64(L), Float64(maximum(abs, trial)), m0, mapping)
  gap_noise = gap_noise + gap_abs
  map_noise = map_noise + map_abs
  finite = all(isfinite, (gap, gap_noise, mapping, map_noise))
  finite && gap + gap_noise <= g.gap_budget && mapping + map_noise <= g.mapping_budget
end

# An objective increase does not end the solve on this route; f_increased still reports it (IN-12).
_stop_on_gradient_increase(state, ::_NumericalL1Ball, options) = false

# The route's solve after the keyword check of solve!: the gate (before any write to x), then the clock, the route
# object with a private ball of the same radius (a projection can use a buffer stored in the ball), the state and the
# engine.
function _solve_numerical_l1!(x, f, g::IndBallL1, feasibility, method, options, kind::Symbol)
  a = something(feasibility, NumericalFeasibility())
  a isa NumericalFeasibility ||
    throw(ArgumentError("feasibility must be a NumericalFeasibility, such as NumericalFeasibility() (got $(typeof(a)))"))
  checked = _check_numerical_l1(x, f, g, a, method, kind)
  t0 = time()
  T = eltype(x)
  d = checked.data
  route = _NumericalL1Ball(IndBallL1{T}(g.r), d.X, d.Y, checked.alpha, checked.budgets, checked.tolerances,
                           checked.decision)
  state = initial_state(method, options, f, route, x)
  _solve_gradient!(state, f, route, method, options, t0)
end
