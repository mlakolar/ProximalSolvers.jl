# Proximal Newton for sparse logistic regression (PN-01 to PN-05). Each outer iteration builds a weighted
# least-squares model of the loss at the accepted point, solves it with the existing scalar coordinate step in
# cyclic order (the private `_cd!` on a SparseIterate, with `LSModel`), and searches along the direction on the true
# objective. The accepted point, the trial buffers and the models are private to one solve; the caller's coefficients
# are written once, at a normal return.

"""
    ProxNewton(; inner = CDSolver(order = :cyclic, momentum = false, relative = false, tol = 1e-11, maxpasses = 2000),
                 maxiter = 100, tol = 1e-7)

Proximal Newton method for sparse logistic regression: the raw `LogisticLoss(y, X)` of ProximalBase, with a binary
response, dense `Float64` data and `NormL1(lambda)` or `NormL1(lambda, w)` on a dense `Vector{Float64}`, passed to
[`solve!`](@ref). The objective is the summed loss `sum(log(1 + exp(eta_i)) - y_i * eta_i)` with `eta = X * b`, plus
the penalty; a column of ones with penalty weight zero is an unpenalized intercept. The call starts from the supplied
coefficients and returns a [`ProxNewtonResults`](@ref) that shares them.

```julia
using ProximalBase, ProximalSolvers
X = [1.0 -1.0; 1.0 0.5; 1.0 1.5; 1.0 -0.5; 1.0 2.0; 1.0 -2.0]
y = [0.0, 1.0, 1.0, 0.0, 1.0, 1.0]
beta = zeros(2)
result = solve!(beta, LogisticLoss(y, X), NormL1(0.5, [0.0, 1.0]), ProxNewton())
result.converged, result.stop_reason
```

Each outer iteration forms a weighted least-squares model of the loss at the current point, with one weight per
observation, and finds its composite minimizer approximately by cyclic coordinate descent. A search on the true
objective then accepts a step along that direction. If the weighted model gives no accepted step, one model with
the constant curvature `1/4` of the logistic loss is tried within the remaining pass budget. The result reports the
objective, the largest ProximalBase KKT score `kkt` of the original problem at the returned point, the accepted
iterations, all coordinate passes (including those of rejected trials) and a `stop_reason`: `:converged`,
`:maxiter` or `:stalled`.

## Keywords

- `inner`: a `CDSolver` in cyclic order (`order = :cyclic`; a random order is refused). Its `maxpasses` is the
  budget of coordinate passes of one outer iteration, shared by the weighted model, its refinements and the fixed
  model. Its `tol` is an absolute threshold on the largest coefficient change of one full pass, in the units of
  the coefficients (`relative` is not used); it is the threshold of the first coordinate-descent run of each model,
  and it is lowered tenfold for each refinement. Zero turns the change test off, so that each run spends all
  its passes. Its `momentum`, `rng` and the other settings are not used.
- `maxiter = 100`: the largest number of accepted outer iterations; `0` only tests the starting point.
- `tol = 1e-7`: absolute tolerance on the largest ProximalBase KKT score of the original summed problem, in the
  units of the gradient of the loss. It is a computed residual, not a certificate: it does not bound the error in
  the coefficients, and where no minimizer exists (separated data, an unpenalized intercept) a small residual does not prove one does.

Memory: one `n × p` weighted design plus vectors of length `n` and `p`.

# Extended help

- [Inputs, result and stop reasons](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-proxnewton/#PN-01).
- [Weighted and fixed models](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-proxnewton/#PN-02).
- [Inner solve, tolerances and pass budget](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-proxnewton/#PN-03).
- [Composite slope and objective search](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-proxnewton/#PN-04).
- [Stopping, mutation and failure boundary](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-proxnewton/#PN-05).
"""
struct ProxNewton{C<:CDSolver} <: ProximalSolver
  inner::C
  maxiter::Int
  tol::Float64
  # The only constructor, so every route into a ProxNewton is validated.
  function ProxNewton(inner::C, maxiter::Integer, tol::Real) where {C<:CDSolver}
    inner.random &&
      throw(ArgumentError("ProxNewton needs a cyclic inner solver, CDSolver(order = :cyclic, ...); the random order is not supported."))
    maxiter >= 0 || throw(ArgumentError("maxiter must be nonnegative, but it is $maxiter."))
    t = Float64(tol)
    isfinite(t) && tol >= 0 || throw(ArgumentError("tol must be finite and nonnegative, but it is $tol."))
    tol > 0 && iszero(t) &&
      throw(ArgumentError("tol is positive but rounds to 0 in Float64; pass 0 for a residual of exactly zero."))
    new{C}(inner, maxiter, t)
  end
end

ProxNewton(; inner::CDSolver = CDSolver(order = :cyclic, momentum = false, relative = false, tol = 1e-11, maxpasses = 2000),
           maxiter::Integer = 100, tol::Real = 1e-7) = ProxNewton(inner, maxiter, tol)

Base.summary(::ProxNewton) = "Proximal Newton"

"""
    ProxNewtonResults

Result of [`ProxNewton`](@ref), sharing the caller's coefficient vector as `minimizer`. The fields are:

- `minimum`: the original summed objective (loss plus penalty) at the returned point;
- `kkt`: the largest ProximalBase KKT score of that problem at the returned point, formed from a fresh gradient;
- `tolerance`: the `tol` of the solver;
- `iterations`: the accepted outer iterations;
- `passes`: all coordinate passes, including those of a model whose step the objective search then rejected;
- `converged`: whether `kkt` is finite and at most `tolerance`, the computed check of the returned point;
- `stop_reason`: `:converged`; `:maxiter`, the iteration budget was spent before convergence; or `:stalled`, no
  direction with a negative composite slope was accepted by the search (no pass budget, an exhausted search, or a
  step that rounds to no change).

A small `kkt` is a computed residual, not a certificate of the minimizer or of the accuracy of the coefficients.
A `converged = false` result returns the last accepted point. The accessors `minimizer`, `minimum`, `iterations`
and `converged` read the fields of the same names. See [the result contract](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-proxnewton/#PN-01).
"""
struct ProxNewtonResults{X}
  minimizer::X
  minimum::Float64
  kkt::Float64
  tolerance::Float64
  iterations::Int
  passes::Int
  converged::Bool
  stop_reason::Symbol
end

Base.summary(::ProxNewtonResults) = "Proximal Newton"
minimizer(r::ProxNewtonResults) = r.minimizer
minimum(r::ProxNewtonResults) = r.minimum
iterations(r::ProxNewtonResults) = r.iterations
converged(r::ProxNewtonResults) = r.converged

function Base.show(io::IO, r::ProxNewtonResults)
  @printf io "Results of Optimization Algorithm\n"
  @printf io " * Algorithm: %s\n" summary(r)
  @printf io " * Minimum: %e\n" r.minimum
  @printf io " * Iterations: %d\n" r.iterations
  @printf io " * Coordinate passes: %d\n" r.passes
  @printf io " * Convergence: %s\n" r.converged
  @printf io "   * largest KKT score %.2e (tolerance %.2e)\n" r.kkt r.tolerance
  @printf io " * Stop reason: %s\n" r.stop_reason
  return
end

# ---- constants ---------------------------------------------------------------------------------------------------
# Trials of the objective search, at the steps 1, 1/2, ..., 2^-39
const _PN_TRIALS = 40
# The Armijo constant of the search
const _PN_ARMIJO = 1e-4
# Tenfold tightenings of the coefficient-change threshold after a missed forcing target, per model
const _PN_REFINEMENTS = 4
# The largest |derivative| / root ratio that an adaptive row keeps: 1/sqrt(eps(Float64))
const _PN_RATIO = 2.0^26

# ---- the models --------------------------------------------------------------------------------------------------
# The adaptive weighted least-squares model of the logistic loss at the predictor eta, with d the observation
# derivative σ(eta) - y from ProximalBase. A row i has the root s = q/(1 + q²), q = exp(-|eta_i|/2), which is
# √(σ(eta_i)σ(-eta_i)) in exact arithmetic. It gives the design row A[i, :] = s X[i, :] and the response
# resp[i] = s eta_i - d_i/s, so that Aᵀ(A b - resp) = Xᵀ d, the gradient of the loss, and AᵀA = Xᵀ diag(s²) X.
# A row whose |d_i| exceeds s 2^26 (the comparison is made on the product, which cannot overflow, and not on the
# ratio d/s) has the fixed row root 1/2 in place of s: it keeps the tangent (resp[i] = eta_i/2 - 2 d_i) and gives the
# row the curvature 1/4 of the global bound. A saturated row on the side of its label keeps its small root. A row whose
# root and derivative are both zero is a zero row. The adaptive model is unusable when a nonzero column
# has every entry square to zero in Float64. Testing the largest magnitude is sufficient because the
# rounded square is monotone on nonnegative inputs. The fixed model can still supply a direction.
function _pn_adaptive_model!(A::Matrix{Float64}, resp::Vector{Float64}, rows::Vector{Float64},
                             X::Matrix{Float64}, eta::Vector{Float64}, d::Vector{Float64})
  @inbounds for i in eachindex(eta)
    q = exp(-abs(eta[i]) / 2)
    s = q / (1 + q^2)
    abs(d[i]) > s * _PN_RATIO && (s = 0.5)
    rows[i] = s
    resp[i] = iszero(s) ? 0.0 : muladd(s, eta[i], -d[i] / s)
  end
  n, p = size(X)
  @inbounds for j in 1:p
    largest = 0.0
    @simd for i in 1:n
      entry = rows[i] * X[i, j]
      A[i, j] = entry
      largest = max(largest, abs(entry))
    end
    isfinite(largest) && (iszero(largest) || !iszero(abs2(largest))) || return false
  end
  _allfinite(resp)
end

# The response of the fixed model, used with the borrowed X and the loss scale 1/4 of an LSModel: eta - 4d, so that
# (1/4) Xᵀ(X b - resp) = Xᵀ d and the Hessian is XᵀX/4, the bound of the logistic Hessian. Returns whether it is finite.
function _pn_fixed_response!(resp::Vector{Float64}, eta::Vector{Float64}, d::Vector{Float64})
  @inbounds @simd for i in eachindex(eta)
    resp[i] = eta[i] - 4 * d[i]
  end
  _allfinite(resp)
end

# ---- the composite slope and the search rule ---------------------------------------------------------------------
# The first-order change of f(b) + Σ cⱼ|bⱼ| along the step from b to cand: G·(cand - b) + Σ cⱼ(|candⱼ| - |bⱼ|),
# formed by coordinate before the products are added, so that the gradient and the penalty slope of a coordinate
# cancel in the factor that multiplies its displacement. Where old and new have the same sign (zero counts for
# either) the penalty adds sign·cⱼ to Gⱼ; where they differ it is split at zero.
function _pn_slope(G::Vector{Float64}, b::Vector{Float64}, cand::Vector{Float64}, c::Vector{Float64})
  s = 0.0
  @inbounds for j in eachindex(b)
    old, new = b[j], cand[j]
    if old >= 0 && new >= 0
      s += (G[j] + c[j]) * (new - old)
    elseif old <= 0 && new <= 0
      s += (G[j] - c[j]) * (new - old)
    else
      s += (G[j] + sign(new) * c[j]) * new - (G[j] + sign(old) * c[j]) * old
    end
  end
  s
end

# The acceptance rule of one trial of the search, for the actual change `actual` of the objective, the Armijo
# requirement `required` (at most zero), the objective F at the accepted point and the original KKT scores rho at the
# accepted point and rho_trial at the trial. When both changes are within the near-tie band of 8 eps(F), the
# trial must improve the score. Otherwise the trial must decrease the objective by more than the band
# and by at least the required amount.
function _pn_accepts(actual::Float64, required::Float64, F::Float64, rho::Float64, rho_trial::Float64)
  slack = 8 * eps(F)
  if abs(actual) <= slack && abs(required) <= slack
    rho_trial < rho
  else
    actual < -slack && actual <= required
  end
end

# The inner KKT forcing target for the model at an accepted point whose score is rho
_pn_forcing(rho::Float64, tol::Float64) = max(0.1 * tol, min(0.25, sqrt(rho)) * rho)

# ---- the private state of one solve ------------------------------------------------------------------------------
mutable struct _PNWork{L, P<:NormL1, S, D}
  f::L                       # the loss, borrowed
  g::P                       # the penalty with its level converted to Float64
  X::Matrix{Float64}         # f.X, borrowed
  c::Vector{Float64}         # the coefficients cⱼ = λ wⱼ of the penalty
  b::Vector{Float64}         # the accepted point
  eta::Vector{Float64}       # X b
  G::Vector{Float64}         # the gradient of the loss at b
  d::Vector{Float64}         # the observation derivative at b
  F::Float64                 # the objective at b
  rho::Float64               # the KKT score at b
  cand::Vector{Float64}      # the candidate of the inner solve
  delta::Vector{Float64}     # cand - b
  grad_model::Vector{Float64}  # the gradient of the model at cand
  u::Vector{Float64}         # the image of delta
  trial::Vector{Float64}     # the trial of the search
  eta_trial::Vector{Float64}
  grad_trial::Vector{Float64}
  d_trial::Vector{Float64}
  A::Matrix{Float64}         # the weighted design
  resp::Vector{Float64}      # the response of the weighted model
  rows::Vector{Float64}      # the row roots
  resp_fixed::Vector{Float64}
  adaptive::LSModel{Float64, Float64, Matrix{Float64}, Vector{Float64}}
  fixed::LSModel{Float64, Float64, Matrix{Float64}, Vector{Float64}}
  work::S                    # the SparseIterate of the inner solve
  cd::D                      # the state of the inner solve
  passes::Int                # all coordinate passes
end

# The coefficients cⱼ of NormL1(λ0, w) in the arithmetic of ProximalBase's KKT score: T(λ0) wⱼ rounded in Float64
_pn_coefficients(g::NormL1, p::Int) = g.w === nothing ? fill(Float64(g.λ0), p) : Float64(g.λ0) .* g.w

# The private state at the supplied coefficients, with the objective, gradient and score there. A start with a
# nonfinite predictor, objective, gradient or score is refused here, before any write to the caller's coefficients.
function _pn_workspace(x::Vector{Float64}, f, g::NormL1, method::ProxNewton)
  X = f.X
  n, p = size(X)
  gT = _converted_penalty(g, Float64)
  c = _pn_coefficients(gT, p)
  b = copy(x)
  eta = X * b
  _allfinite(eta) || throw(ArgumentError("start from a point where f is finite"))
  G, d = zeros(p), zeros(n)
  F = Float64(value_and_gradient_from_predictor!(G, d, f, eta)) + gT(b)
  isfinite(F) || throw(ArgumentError("start from a point where f is finite"))
  _allfinite(G) || throw(ArgumentError("start from a point where the gradient of f is finite"))
  rho = kkt_violation(gT, G, b)
  isfinite(rho) || throw(ArgumentError("start from a point where the KKT score is finite"))
  A, resp, resp_fixed = similar(X), zeros(n), zeros(n)
  work = SparseIterate(zeros(p))
  _PNWork(f, gT, X, c, b, eta, G, d, F, rho,
          similar(b), similar(b), similar(b), zeros(n),
          similar(b), similar(eta), similar(G), similar(d),
          A, resp, zeros(n), resp_fixed,
          LSModel(resp, A, 1.0), LSModel(resp_fixed, X, 0.25),
          work, _CDState(Float64, work, method.inner), 0)
end

# Loads the dense point b into the SparseIterate: the stored entries are zeroed (a zero write keeps an entry stored)
# and dropped, then the nonzero entries of b are written in index order, so that the result, and the order of the
# cyclic passes over its active entries, depend on b alone.
function _pn_load!(work, b::Vector{Float64})
  for k in activecoordinates(work)
    work[k] = 0.0
  end
  dropzeros!(work)
  for j in eachindex(b)
    iszero(b[j]) || (work[j] = b[j])
  end
  work
end

# The gradient of the model at the candidate: the original gradient plus the curvature action of the model on the
# displacement, scale·matᵀ(mat (cand - b)), not the model's own residual (which subtracts the working response a
# second time). Its original-problem KKT score at cand, or NaN when the displacement or the gradient is not finite.
function _pn_surrogate_residual!(w::_PNWork, mat::Matrix{Float64}, scale::Float64)
  @. w.delta = w.cand - w.b
  mul!(w.u, mat, w.delta)
  mul!(w.grad_model, transpose(mat), w.u)
  @. w.grad_model = w.G + scale * w.grad_model
  _allfinite(w.grad_model) ? kkt_violation(w.g, w.grad_model, w.cand) : NaN
end

# The inner solve of one model, from the accepted point: coordinate descent in cyclic order with an absolute change
# threshold, which is lowered tenfold and the run continued while the model's score at the candidate misses the
# forcing target, at most `_PN_REFINEMENTS` times and within `limit` passes. The candidate is left in w.cand, whatever
# the outcome. Counts the passes of every run in w.passes and returns them. With limit = 0 no run is made, and the
# candidate is the accepted point.
function _pn_direction!(w::_PNWork, adaptive::Bool, limit::Int, delta0::Float64, tol::Float64)
  model = adaptive ? w.adaptive : w.fixed
  mat = adaptive ? w.A : w.X
  scale = adaptive ? 1.0 : 0.25
  _pn_load!(w.work, w.b)
  initialize!(model, w.work)
  copyto!(w.cand, w.b)
  target = _pn_forcing(w.rho, tol)
  delta = delta0
  used = 0
  for _ in 0:_PN_REFINEMENTS
    left = limit - used
    left > 0 || break
    _cd!(w.work, model, w.g, w.cd, CDSolver(left, delta, false, false, false, w.cd.rng))
    used += w.cd.passes
    _copy_dense!(w.cand, w.work)
    rq = _pn_surrogate_residual!(w, mat, scale)
    isfinite(rq) && rq <= target && break
    delta /= 10
  end
  w.passes += used
  used
end

# The search along cand - b on the true objective, with the steps t = 1, 1/2, ... (`_PN_TRIALS` of them). A trial
# with a nonfinite predictor, objective, gradient or score is ineligible. The first trial that `_pn_accepts` becomes
# the accepted point, with its fresh objective, gradient and score. A step that rounds to no change ends the search
# without success, as does the last trial.
function _pn_search!(w::_PNWork, slope::Float64)
  for j in 0:(_PN_TRIALS - 1)
    t = ldexp(1.0, -j)
    @. w.trial = w.b + t * (w.cand - w.b)
    w.trial == w.b && return false
    mul!(w.eta_trial, w.X, w.trial)
    _allfinite(w.eta_trial) || continue
    F = Float64(value_and_gradient_from_predictor!(w.grad_trial, w.d_trial, w.f, w.eta_trial)) + w.g(w.trial)
    (isfinite(F) && _allfinite(w.grad_trial)) || continue
    rho = kkt_violation(w.g, w.grad_trial, w.trial)
    isfinite(rho) || continue
    _pn_accepts(F - w.F, _PN_ARMIJO * t * slope, w.F, w.rho, rho) || continue
    copyto!(w.b, w.trial)
    copyto!(w.eta, w.eta_trial)
    copyto!(w.G, w.grad_trial)
    copyto!(w.d, w.d_trial)
    w.F, w.rho = F, rho
    return true
  end
  false
end

# One outer iteration: the models of `modes` in order, each with its own coordinate-descent run from the accepted
# point and a refreshed state. The weighted model leaves a quarter of the budget for the fixed one where both can
# run. A direction is searched when its composite slope is finite and negative, whether or not the forcing target was
# met. Returns whether a step was accepted; the passes of every run are counted either way.
function _pn_step!(w::_PNWork, method::ProxNewton, modes::Tuple = (:adaptive, :fixed))
  budget = method.inner.maxpasses
  used = 0
  for mode in modes
    remaining = budget - used
    adaptive = mode === :adaptive
    limit = adaptive && length(modes) > 1 && remaining > 1 ? remaining - cld(remaining, 4) : remaining
    limit > 0 || continue
    built = adaptive ? _pn_adaptive_model!(w.A, w.resp, w.rows, w.X, w.eta, w.d) :
                       _pn_fixed_response!(w.resp_fixed, w.eta, w.d)
    built || continue
    used += _pn_direction!(w, adaptive, limit, method.inner.tol, method.tol)
    slope = _pn_slope(w.G, w.b, w.cand, w.c)
    isfinite(slope) && slope < 0 && _pn_search!(w, slope) && return true
  end
  false
end

function _solve_newton!(x::Vector{Float64}, f, g::NormL1, method::ProxNewton)
  w = _pn_workspace(x, f, g, method)
  accepted = 0
  reason = :stalled
  while true
    if w.rho <= method.tol
      reason = :converged
      break
    elseif accepted >= method.maxiter
      reason = :maxiter
      break
    end
    _pn_step!(w, method) || break
    accepted += 1
  end
  copyto!(x, w.b)
  ProxNewtonResults(x, w.F, w.rho, method.tol, accepted, w.passes, reason === :converged, reason)
end

function solve!(x, f, g, method::ProxNewton; kwargs...)
  _check_keywords(kwargs)
  _check_newton_problem(x, f, g)
  _solve_newton!(x, f, g, method)
end
