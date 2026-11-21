# Predictor-splitting ADMM for sparse logistic regression (LA-01 to LA-05). The constraint is t = X b with a dual u of
# length n, held as w = ρ u. Each iteration runs a warm-started cyclic coordinate descent on the least-squares
# subproblem in b (the private `_cd!` on a SparseIterate, with `LSModel(t - u, X, ρ)`), a scalar logistic proximal
# root per observation for t, and the update u⁺ = v - t with v = X b + u. The iterates and the work buffers are
# private to one solve. The caller's coefficients are written once, at a normal return; a supplied t and u are written
# then too when an iteration completed, and keep their entries otherwise.

# The accepted range of ρ after conversion to Float64 (LA-01)
const _LA_RHO_MIN = 1e-10
const _LA_RHO_MAX = 1e10
# Tenfold tightenings of the coefficient-change threshold of the β step after a missed forcing target
const _LA_REFINEMENTS = 4
# The multiple of eps(Float64) in the stopping threshold of the computed scalar residual h, a threshold formed from the
# computed terms of h (LA-03)
const _LA_ROOT_BOUND = 4
# The default step budget `cap` of `_la_root` (LA-03). No bound on the steps that a root needs is claimed. A pass of
# `_la_root` that reaches its budget check with `steps >= cap` returns ok = false, and the solve then ends with
# :prox_failed.
const _LA_ROOT_CAP = 3 * (34 + 1074 + 2)

# A tolerance of the solver: finite and nonnegative, and not a positive value that rounds to zero in Float64
function _la_tolerance(v::Real, name::String)
  x = Float64(v)
  isfinite(x) && v >= 0 || throw(ArgumentError("$name must be finite and nonnegative, but it is $v."))
  v > 0 && iszero(x) &&
    throw(ArgumentError("$name is positive but rounds to 0 in Float64; pass 0 for a threshold of exactly zero."))
  x
end

"""
    LogisticADMM(; ρ = 0.25, maxiter = 10_000, tol = 1e-7, abstol = 1e-8, reltol = 1e-6, abstol_dual = abstol,
                   inner = CDSolver(order = :cyclic, momentum = false, relative = false, tol = 1e-8, maxpasses = 1000))

Alternating direction method of multipliers (ADMM) for sparse logistic regression: the raw `LogisticLoss(y, X)` of
ProximalBase, with a binary response, dense `Float64` data and `NormL1(lambda)` or `NormL1(lambda, w)` on a dense
`Vector{Float64}`, passed to [`solve!`](@ref). The objective is that of [`ProxNewton`](@ref): the summed loss
`sum(log(1 + exp(eta_i)) - y_i * eta_i)` with `eta = X * b`, plus the penalty; a column of ones with penalty weight
zero is an unpenalized intercept. It returns a [`LogisticADMMResults`](@ref) that shares the caller's coefficients.

```julia
using ProximalBase, ProximalSolvers
X = [1.0 -1.0; 1.0 0.5; 1.0 1.5; 1.0 -0.5; 1.0 2.0; 1.0 -2.0]
y = [0.0, 1.0, 1.0, 0.0, 1.0, 1.0]
beta = zeros(2)
result = solve!(beta, LogisticLoss(y, X), NormL1(0.5, [0.0, 1.0]), LogisticADMM())
result.converged, result.stop_reason
```

The method splits the predictor from the coefficients with the constraint `t = X * b` and a scaled dual `u` with one
entry per observation (not per coefficient, as in the consensus [`ADMMSolver`](@ref)). Each iteration approximately
minimizes the penalty plus `(ρ/2) * norm(X * b - t + u)^2` over `b` by warm-started cyclic coordinate descent within a
pass budget, solves one scalar logistic proximal problem per observation for `t`, and updates `u` by `X * b - t`.
The solve stops with
`converged = true` when the primal residual `norm(X * b - t)`, the dual residual `ρ * norm(X' * (t - t_previous))`
and the largest ProximalBase KKT score of the original problem at the returned coefficients are within their
thresholds. That is a computed check of the returned point, not a certificate of the minimizer or of the accuracy of
the coefficients. ADMM is not presumed to be faster than [`ProximalGradientDescent`](@ref) or [`ProxNewton`](@ref) on
this problem; its iteration count depends on `ρ`, a tuning parameter.

`solve!(b, f, g, LogisticADMM(); t = t0, u = u0)` starts from a given predictor and dual (each a `Vector{Float64}` of
length `n`); without them `t = X * b` and `u = (σ(t) - y) / ρ`. With this dual, an exact minimizer of the same
objective and its own predictor are a fixed point of the ideal iteration. A warm start from another solver's solution
or from a fit at another level can move (a computed solution can also coincide with an exact fixed point), and the
number of iterations it takes depends on the fit. To restart with a different `ρ`, pass `u * ρ_old / ρ_new`: `u` is
the scaled dual of the `ρ` it was computed with.

# Extended help

## Keywords

- `ρ = 0.25`: the penalty of the augmented Lagrangian, in `[1e-10, 1e10]` after conversion to `Float64`. The default is
  the bound `1/4` on the curvature of the loss of one observation.
- `maxiter = 10_000`: the largest number of completed iterations; `0` evaluates the starting point only.
- `tol = 1e-7`: absolute tolerance on the largest ProximalBase KKT score of the original summed problem at the
  returned coefficients, in the units of the gradient of the loss. It is a computed residual, not a certificate: it
  does not bound the error in the coefficients, and where no minimizer exists (separated data, an unpenalized
  intercept) a small residual does not prove one does.
- `abstol = 1e-8`, `reltol = 1e-6`: the primal threshold `sqrt(n) * abstol + reltol * max(norm(X * b), norm(t))`;
  `abstol_dual = abstol` with `reltol`: the dual threshold `sqrt(p) * abstol_dual + reltol * norm(ρ * X' * u)`.
- `inner`: a `CDSolver` in cyclic order with `maxpasses >= 1` (any other value is refused). Its `maxpasses` is the budget of coordinate passes of
  the coefficient step of one iteration and its `tol` the first absolute threshold on the largest coefficient change
  of a pass, lowered tenfold, at most four times, while the step misses its forcing target. Its `relative`,
  `momentum`, `rng` and the other settings are not used.

Memory: vectors of length `n` and `p`; no `n × p` array beyond the borrowed `X`.

## Contract

- [Inputs, result and stop reasons](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-admm/#LA-01).
- [The coefficient step and its inner accuracy](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-admm/#LA-02).
- [The scalar logistic proximal root and the dual update](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-admm/#LA-03).
- [Residuals, stopping and certification](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-admm/#LA-04).
- [Mutation and failure boundary](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-admm/#LA-05).
"""
struct LogisticADMM{C<:CDSolver} <: ProximalSolver
  ρ::Float64
  maxiter::Int
  tol::Float64
  abstol::Float64
  reltol::Float64
  abstol_dual::Float64
  inner::C
  # The only constructor, so every route into a LogisticADMM is validated.
  function LogisticADMM(ρ::Real, maxiter::Integer, tol::Real, abstol::Real, reltol::Real, abstol_dual::Real,
                        inner::C) where {C<:CDSolver}
    r = Float64(ρ)
    isfinite(r) && _LA_RHO_MIN <= r <= _LA_RHO_MAX ||
      throw(ArgumentError("ρ must be in [1e-10, 1e10] after conversion to Float64, but it is $ρ."))
    maxiter >= 0 || throw(ArgumentError("maxiter must be nonnegative, but it is $maxiter."))
    inner.random &&
      throw(ArgumentError("LogisticADMM needs a cyclic inner solver, CDSolver(order = :cyclic, ...); the random order is not supported."))
    inner.maxpasses >= 1 ||
      throw(ArgumentError("LogisticADMM needs inner.maxpasses >= 1: with no pass the coefficient step cannot move the coefficients."))
    new{C}(r, maxiter, _la_tolerance(tol, "tol"), _la_tolerance(abstol, "abstol"), _la_tolerance(reltol, "reltol"),
           _la_tolerance(abstol_dual, "abstol_dual"), inner)
  end
end

# `inner` is untyped here so that a value other than a CDSolver is refused with an ArgumentError (LA-01)
function LogisticADMM(; ρ::Real = 0.25, maxiter::Integer = 10_000, tol::Real = 1e-7, abstol::Real = 1e-8,
                      reltol::Real = 1e-6, abstol_dual::Real = abstol,
                      inner = CDSolver(order = :cyclic, momentum = false, relative = false, tol = 1e-8, maxpasses = 1000))
  inner isa CDSolver ||
    throw(ArgumentError("LogisticADMM needs inner to be a CDSolver in cyclic order, but it is a $(typeof(inner))."))
  LogisticADMM(ρ, maxiter, tol, abstol, reltol, abstol_dual, inner)
end

Base.summary(::LogisticADMM) = "Logistic ADMM"

"""
    LogisticADMMResults

Result of [`LogisticADMM`](@ref), sharing the caller's coefficient vector as `minimizer`. It is a type of its own, not
an [`ADMMResults`](@ref): its predictor `t` and dual `u` have one entry per observation. The main fields are:

- `minimum`: the original summed objective (loss plus penalty) at the returned coefficients;
- `kkt`: the largest ProximalBase KKT score of that problem at the returned coefficients, from a gradient formed there;
- `tolerance`: the `tol` of the solver;
- `iterations`: the completed iterations;
- `t`, `u`: the returned predictor and scaled dual, each the caller's vector when one was passed to `solve!` (left with
  its entries when no iteration completed), and a new vector otherwise; `ρ`: the penalty of the solver;
- `converged`: whether the last completed iteration passed the primal and dual residual tests and `kkt` is at most
  `tolerance`;
- `stop_reason`: `:converged`; `:maxiter`, the iteration budget was spent (also for `maxiter = 0`); `:stalled`, an
  iteration left `b`, `t` and the working dual `w = ρ u` unchanged in every bit without converging; or `:prox_failed`,
  a scalar root failed (a nonfinite argument or the step budget) and that iteration was discarded.

A small `kkt` is a computed residual, not a certificate of the minimizer or of the accuracy of the coefficients.
A `converged = false` result returns the last completed iteration. The accessors `minimizer`, `minimum`, `iterations`
and `converged` read the fields of the same names.

# Extended help

The diagnostics and work counters are:

- `r_norm`, `s_norm`: the primal residual `norm(X * b - t)` and the dual residual `ρ * norm(X' * (t - t_previous))`
  of the last completed iteration, and `eps_pri`, `eps_dual` their thresholds; all four are `NaN` when no iteration
  completed;
- `inner_kkt`, `inner_met`: the KKT score of the coefficient step of the last completed iteration, formed from a fresh
  product at its coefficients, and whether it met its forcing target (`NaN` and `false` when no iteration completed);
- `dual_kkt`: the largest ProximalBase KKT score of `0 ∈ ∂g(b) + ρ X' u` at the returned `b` and `u`, evaluated in
  `Float64` from the fresh product `X' * (ρ .* u)` (the scaled dual is formed first). It can be `Inf` or `NaN`, without
  an error, when terms or partial sums of that product overflow, also where the exact sum is representable or zero, and
  subnormal rounding of an entry `ρ * u[i]` can distort its contribution, upward or downward, or remove it when the
  entry rounds to zero;
- `predictor_residual`: the largest entry of `abs.(σ.(t) .- y .- ρ .* u)` at the returned `t` and `u`; these two are
  formed from the returned values, while the residuals, thresholds and inner score are those of the last completed
  iteration;
- `passes`: all coordinate passes of the coefficient steps, including those of an iteration discarded by
  `:prox_failed`; `root_iterations`: all steps of the scalar roots, counted in the same way.

See [the result contract](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-admm/#LA-01).
"""
struct LogisticADMMResults{X}
  minimizer::X
  minimum::Float64
  kkt::Float64
  tolerance::Float64
  iterations::Int
  passes::Int
  root_iterations::Int
  r_norm::Float64
  s_norm::Float64
  eps_pri::Float64
  eps_dual::Float64
  inner_kkt::Float64
  inner_met::Bool
  dual_kkt::Float64
  predictor_residual::Float64
  t::Vector{Float64}
  u::Vector{Float64}
  ρ::Float64
  converged::Bool
  stop_reason::Symbol
end

Base.summary(::LogisticADMMResults) = "Logistic ADMM"
minimizer(r::LogisticADMMResults) = r.minimizer
minimum(r::LogisticADMMResults) = r.minimum
iterations(r::LogisticADMMResults) = r.iterations
converged(r::LogisticADMMResults) = r.converged

function Base.show(io::IO, r::LogisticADMMResults)
  @printf io "Results of Optimization Algorithm\n"
  @printf io " * Algorithm: %s\n" summary(r)
  @printf io " * Minimum: %e\n" r.minimum
  @printf io " * Iterations: %d\n" r.iterations
  @printf io " * Coordinate passes: %d\n" r.passes
  @printf io " * Scalar root steps: %d\n" r.root_iterations
  @printf io " * Convergence: %s\n" r.converged
  @printf io "   * largest KKT score %.2e (tolerance %.2e)\n" r.kkt r.tolerance
  @printf io "   * primal residual %.2e (threshold %.2e)\n" r.r_norm r.eps_pri
  @printf io "   * dual residual %.2e (threshold %.2e)\n" r.s_norm r.eps_dual
  @printf io " * Stop reason: %s\n" r.stop_reason
  return
end

# ---- the scalar logistic proximal root ---------------------------------------------------------------------------
# σ(s) - y for a binary y (`one_label` is y == 1), formed from e = exp(-|s|), which does not overflow: for y = 0,
# 1/(1 + e) at s ≥ 0 and e/(1 + e) at s < 0; for y = 1, -e/(1 + e) at s ≥ 0 and -1/(1 + e) at s < 0. For y = 0 and
# s < 0 the value e/(1 + e) is positive while exp(-|s|) is positive (s above about -745.13), and subnormal for s
# below about -708.40 until exp(-|s|) underflows to 0. There 1/(1 + exp(-s)) gives 0 once exp(-s) overflows, for s
# below -log(floatmax(Float64)) ≈ -709.78.
@inline function _la_residual(s::Float64, one_label::Bool)
  e = exp(-abs(s))
  if one_label
    s >= 0 ? -e / (1 + e) : -1 / (1 + e)
  else
    s >= 0 ? 1 / (1 + e) : e / (1 + e)
  end
end

# σ(s)(1 - σ(s)) = e/(1 + e)² with e = exp(-|s|)
@inline _la_curvature(s::Float64) = (e = exp(-abs(s)); e / (1 + e)^2)

# The computed h(s) = (σ(s) - y) + ρ(s - v) and the stopping threshold `_LA_ROOT_BOUND * eps * (|σ(s) - y| + |ρ(s - v)|)`,
# both from the two computed terms. The threshold is not a bound on the error of the computed h: at s = v = -746 with
# y = 0, exp(-746) underflows and both are 0 while the exact h is positive.
@inline function _la_scalar(s::Float64, v::Float64, one_label::Bool, ρ::Float64)
  r = _la_residual(s, one_label)
  q = ρ * (s - v)
  r + q, _LA_ROOT_BOUND * eps(Float64) * (abs(r) + abs(q))
end

# The endpoint of the bracket with the smaller |h|; hlo and hhi are h at lo and hi, or NaN where h was not evaluated
function _la_endpoint(lo, hlo, hi, hhi, v, one_label, ρ)
  isnan(hlo) && (hlo = first(_la_scalar(lo, v, one_label, ρ)))
  isnan(hhi) && (hhi = first(_la_scalar(hi, v, one_label, ρ)))
  abs(hlo) <= abs(hhi) ? lo : hi
end

# The root of h(s) = σ(s) - y + ρ(s - v) for a binary y (`one_label` is y == 1) and ρ in [1e-10, 1e10], LA-03.
# Returns (s, steps, ok). A nonfinite v returns (v, 0, false). Otherwise γ = inv(ρ) is rounded first, then the far end
# v - γ (y = 0) or v + γ (y = 1) is rounded and clamped to ±floatmax, giving the working bracket [lo, hi] with v as the
# other end (in exact arithmetic the root lies in [v - 1/ρ, v] or [v, v + 1/ρ]). s starts at v and h and its threshold B
# (`_la_scalar`) are evaluated there; `steps` counts the points that become s after v, `window` counts loop passes
# since its last reset, and `ref` starts at the initial width. Each pass, in this order: returns (s, steps, true) when
# |h| ≤ B; sets lo = s when h < 0 and hi = s otherwise; resets `window` to 0 and `ref` to the width when the width is at
# most ref/2, and otherwise adds 1 to `window`; when no Float64 lies strictly inside (lo, hi), returns the end with the
# smaller computed |h|, lo on a tie (h is evaluated at an end where it was not), and no further pass follows; returns
# (s, steps, false) when steps ≥ cap; forms the Newton point s - h/(σ(1 - σ) + ρ) and returns (s, steps, true) when it
# equals s; replaces it by lo/2 + hi/2 when window ≥ 2 or it is not strictly inside (lo, hi), and, when that midpoint
# is not strictly inside, returns the end chosen as above; otherwise moves s to the point, adds 1 to `steps` and
# evaluates h and B at the new s, which the next pass compares. At an s returned with ok = true the caller forms
# w = ρ(v - s), and the computed h there equals the computed σ(s) - y - w up to the sign of zero (ρ(s - v) = -ρ(v - s)
# exactly), which need not be small (|h| = 1 for y = 0, v = 2^55 + 8, ρ = 1/4). With ok = false the caller leaves its
# loop over the observations before it forms w. A cap below `_LA_ROOT_CAP` is for tests.
function _la_root(v::Float64, one_label::Bool, ρ::Float64, cap::Int = _LA_ROOT_CAP)
  isfinite(v) || return v, 0, false
  γ = inv(ρ)
  lo, hi = one_label ? (v, min(v + γ, floatmax(Float64))) : (max(v - γ, -floatmax(Float64)), v)
  hlo, hhi = NaN, NaN
  s = v
  h, bound = _la_scalar(s, v, one_label, ρ)
  ref, window, steps = hi - lo, 0, 0
  while true
    abs(h) <= bound && return s, steps, true          # also h == 0
    if h < 0
      lo, hlo = s, h
    else
      hi, hhi = s, h
    end
    width = hi - lo
    if width <= ref / 2
      ref, window = width, 0
    else
      window += 1
    end
    nextfloat(lo) < hi || return _la_endpoint(lo, hlo, hi, hhi, v, one_label, ρ), steps, true
    steps >= cap && return s, steps, false
    next = s - h / (_la_curvature(s) + ρ)
    next == s && return s, steps, true
    if window >= 2 || !(lo < next < hi)
      next = lo / 2 + hi / 2
      lo < next < hi || return _la_endpoint(lo, hlo, hi, hhi, v, one_label, ρ), steps, true
    end
    s = next
    steps += 1
    h, bound = _la_scalar(s, v, one_label, ρ)
  end
end

# ---- the private state of one solve ------------------------------------------------------------------------------
mutable struct _LAWork{L, P<:NormL1, M, S, D}
  f::L                       # the loss, borrowed
  g::P                       # the penalty with its level converted to Float64
  X::Matrix{Float64}         # f.X, borrowed
  y::Vector{Float64}         # f.y, borrowed
  rho::Float64               # ρ
  b::Vector{Float64}         # the coefficients of the last completed iteration (or the start)
  eta::Vector{Float64}       # X b
  t::Vector{Float64}         # the predictor
  w::Vector{Float64}         # ρ u, the dual in the units of the gradient
  b_new::Vector{Float64}     # the same four quantities during an iteration
  eta_new::Vector{Float64}
  t_new::Vector{Float64}
  w_new::Vector{Float64}
  resp::Vector{Float64}      # t - u, the response of the β step (the `y` of `model`)
  diff::Vector{Float64}      # a scratch vector of length n
  q::Vector{Float64}         # ρ Xᵀ(X b_new - resp), the gradient of the β step's loss at b_new
  sv::Vector{Float64}        # Xᵀ(t_new - t)
  xw::Vector{Float64}        # Xᵀ w_new, a fresh product for the dual threshold
  G::Vector{Float64}         # the gradient of the loss at b_new
  d::Vector{Float64}         # the observation derivative at b_new
  F::Float64                 # the objective at b
  kkt::Float64               # the KKT score of the original problem at b
  model::M                   # LSModel(resp, X, ρ)
  work::S                    # the SparseIterate of the β step, carried across iterations
  cd::D                      # the state of the β step
  passes::Int
  roots::Int
  r_norm::Float64
  s_norm::Float64
  eps_pri::Float64
  eps_dual::Float64
  inner_kkt::Float64
  inner_met::Bool
  cap::Int                   # the step budget of each scalar root: `_LA_ROOT_CAP`, or less in tests
end

# The checks of a supplied t or u (`name`), before any write: a Vector{Float64} of length n that does not overlap x, X,
# y, the scratch of the loss, the penalty weights or `other` (the other supplied vector), with finite entries
function _check_la_vector(v, name::String, n::Int, x, f, g, other)
  v isa Vector{Float64} || throw(ArgumentError("$name must be a dense Vector{Float64} with one entry per row of X"))
  length(v) == n || throw(DimensionMismatch("$name has $(length(v)) entries but X has $n rows"))
  (_admm_mightalias(v, x) || _admm_mightalias(v, f.X) || _admm_mightalias(v, f.y) || _admm_mightalias(v, f.tmp) ||
   (g.w !== nothing && _admm_mightalias(v, g.w)) || (other isa Vector{Float64} && _admm_mightalias(v, other))) &&
    throw(ArgumentError("$name must not overlap x, X, y, the scratch of the loss, the penalty weights, t or u"))
  _allfinite(v) || throw(ArgumentError("$name must contain only finite values"))
  nothing
end

# The private state at the supplied coefficients, with the objective, gradient and score there, the predictor t0 (X b
# when t0 is nothing) and the dual w = ρ u0 (σ(t) - y when u0 is nothing). In this order, each with an ArgumentError
# except a wrong length (DimensionMismatch): coefficients x whose memory range overlaps X, y, the scratch of the loss or
# the penalty weights (a check on byte ranges, which also catches overlaps that Base.mightalias in the shared gate does
# not report); a start with a nonfinite predictor X b, objective, gradient or score; a supplied t0 or u0
# (`_check_la_vector`); with a supplied u0,
# a product ρ u0 or a difference t - u0, formed directly in Float64, that is not finite; a working response t - w/ρ
# that is not finite. Every refusal is before any write to the caller's arrays. `cap` is the step budget of each scalar
# root; a smaller one is for tests.
function _la_workspace(x::Vector{Float64}, f, g::NormL1, method::LogisticADMM, t0, u0, cap::Int = _LA_ROOT_CAP)
  X, y = f.X, f.y
  n, p = size(X)
  ρ = method.ρ
  (_admm_mightalias(x, X) || _admm_mightalias(x, y) || _admm_mightalias(x, f.tmp) ||
   (g.w !== nothing && _admm_mightalias(x, g.w))) &&
    throw(ArgumentError("x must not overlap the memory of X, y, the scratch of the loss or the penalty weights"))
  gT = _converted_penalty(g, Float64)
  b = copy(x)
  eta = X * b
  _allfinite(eta) || throw(ArgumentError("start from a point where f is finite"))
  G, d = zeros(p), zeros(n)
  F = Float64(value_and_gradient_from_predictor!(G, d, f, eta)) + gT(b)
  isfinite(F) || throw(ArgumentError("start from a point where f is finite"))
  _allfinite(G) || throw(ArgumentError("start from a point where the gradient of f is finite"))
  kkt = kkt_violation(gT, G, b)
  isfinite(kkt) || throw(ArgumentError("start from a point where the KKT score is finite"))
  t0 === nothing || _check_la_vector(t0, "t", n, x, f, g, u0)
  u0 === nothing || _check_la_vector(u0, "u", n, x, f, g, t0)
  t = t0 === nothing ? copy(eta) : copy(t0)
  w = similar(t)
  if u0 === nothing
    @inbounds for i in eachindex(w)
      w[i] = _la_residual(t[i], isone(y[i]))
    end
  else
    @. w = ρ * u0
    _allfinite(w) || throw(ArgumentError("ρ * u must be finite"))
    @inbounds for i in eachindex(t)
      isfinite(t[i] - u0[i]) || throw(ArgumentError("t - u must be finite"))
    end
  end
  resp = similar(t)
  @. resp = t - w / ρ
  _allfinite(resp) || throw(ArgumentError("t - u must be finite"))
  work = _pn_load!(SparseIterate(zeros(p)), b)
  model = LSModel(resp, X, ρ)
  _LAWork(f, gT, X, y, ρ, b, eta, t, w, similar(b), similar(eta), similar(t), similar(w), resp, zeros(n), zeros(p),
          zeros(p), zeros(p), G, d, F, kkt, model, work, _CDState(Float64, work, method.inner), 0, 0, NaN, NaN, NaN, NaN, NaN,
          false, cap)
end

# The β step (LA-02): coordinate descent in cyclic order on LSModel(resp, X, ρ) with resp = t - w/ρ, from the
# SparseIterate of the last completed iteration. The residual of the model is seeded as resp - X b from the image
# `eta` of those coefficients, and the curvature cache of the model is kept (X is fixed). After each run, the score is
# ProximalBase's kkt_violation of q = ρ Xᵀ(X b_new - resp) at b_new, from a fresh product X b_new, independent of the
# residual maintained by CD. While the score misses the forcing target max(0.1 tol, 0.1 kkt), with kkt the score of
# the original problem at b, the change threshold is divided by ten and the run continues, at most
# `_LA_REFINEMENTS` times and within inner.maxpasses passes. Leaves b_new, eta_new and q at the last run and records
# the score and whether it met the target.
function _la_beta_step!(w::_LAWork, method::LogisticADMM)
  ρ, model = w.rho, w.model
  @. w.resp = w.t - w.w / ρ
  @. model.r = w.resp - w.eta
  target = max(0.1 * method.tol, 0.1 * w.kkt)
  delta = method.inner.tol
  used, score, met = 0, NaN, false
  for _ in 0:_LA_REFINEMENTS
    left = method.inner.maxpasses - used
    left > 0 || break
    _cd!(w.work, model, w.g, w.cd, CDSolver(left, delta, false, false, false, w.cd.rng))
    used += w.cd.passes
    _copy_dense!(w.b_new, w.work)
    mul!(w.eta_new, w.X, w.b_new)
    @. w.diff = w.eta_new - w.resp
    mul!(w.q, transpose(w.X), w.diff)
    w.q .*= ρ
    score = _allfinite(w.q) ? kkt_violation(w.g, w.q, w.b_new) : NaN
    met = isfinite(score) && score <= target
    met && break
    delta /= 10
  end
  w.passes += used
  score, met
end

# The t and u steps (LA-03): for each observation, v = X b_new + w/ρ, t_new the scalar root of σ(t) - y + ρ(t - v) and
# w_new = ρ(v - t_new), from the same v. Returns false at the first root that fails (a nonfinite v or the step cap),
# without computing the later roots; the steps of the roots computed, including the failed one, are counted.
function _la_predictor_step!(w::_LAWork)
  ρ, y = w.rho, w.y
  steps = 0
  ok = true
  @inbounds for i in eachindex(w.t_new)
    v = w.eta_new[i] + w.w[i] / ρ
    s, k, ok = _la_root(v, isone(y[i]), ρ, w.cap)
    steps += k
    ok || break
    w.t_new[i] = s
    w.w_new[i] = ρ * (v - s)
  end
  w.roots += steps
  ok
end

# The residuals of the iteration from (b, t, w) to (b_new, t_new, w_new) and their thresholds (LA-04), each from a
# product formed for it: X b_new (from the β step), Xᵀ(t_new - t) for the dual residual and Xᵀ w_new for the dual
# threshold. (q - ρ Xᵀ(t_new - t) equals Xᵀ w_new in exact arithmetic, but the rounding of its two terms can leave a
# value where the direct product is 0, so the threshold does not use it.)
function _la_residuals!(w::_LAWork, method::LogisticADMM)
  ρ = w.rho
  n, p = size(w.X)
  @. w.diff = w.eta_new - w.t_new
  w.r_norm = norm(w.diff)
  @. w.diff = w.t_new - w.t
  mul!(w.sv, transpose(w.X), w.diff)
  w.s_norm = ρ * norm(w.sv)
  w.eps_pri = sqrt(n) * method.abstol + method.reltol * max(norm(w.eta_new), norm(w.t_new))
  mul!(w.xw, transpose(w.X), w.w_new)
  w.eps_dual = sqrt(p) * method.abstol_dual + method.reltol * norm(w.xw)
  w
end

# The residual tests and the KKT test of LA-04; a nonfinite residual or threshold fails its test
_la_passes(r, eps) = isfinite(r) && isfinite(eps) && r <= eps
_la_converged(w::_LAWork, tol::Float64) =
  _la_passes(w.r_norm, w.eps_pri) && _la_passes(w.s_norm, w.eps_dual) && w.kkt <= tol

# One iteration from the last completed one (LA-02 to LA-04). Returns :prox_failed, and leaves the completed state as
# it was, when a scalar root fails; otherwise the new state replaces the completed one and the result is :stalled when
# b, t and the working dual w are unchanged in every bit (isequal), or :continue. A nonfinite objective or KKT score of
# the original problem at b_new raises an error.
function _la_iterate!(w::_LAWork, method::LogisticADMM)
  w.inner_kkt, w.inner_met = _la_beta_step!(w, method)
  _la_predictor_step!(w) || return :prox_failed
  _la_residuals!(w, method)
  F = Float64(value_and_gradient_from_predictor!(w.G, w.d, w.f, w.eta_new)) + w.g(w.b_new)
  kkt = _allfinite(w.G) ? kkt_violation(w.g, w.G, w.b_new) : NaN
  isfinite(F) && isfinite(kkt) ||
    error("LogisticADMM produced a nonfinite objective or KKT score at the coefficients of an iteration")
  unchanged = isequal(w.b_new, w.b) && isequal(w.t_new, w.t) && isequal(w.w_new, w.w)
  w.b, w.b_new = w.b_new, w.b
  w.eta, w.eta_new = w.eta_new, w.eta
  w.t, w.t_new = w.t_new, w.t
  w.w, w.w_new = w.w_new, w.w
  w.F, w.kkt = F, kkt
  unchanged ? :stalled : :continue
end

# The step budget of each scalar root in iteration k: an Int for every iteration, or a function of k (tests)
_la_cap(cap::Int, k::Int) = cap
_la_cap(cap, k::Int) = cap(k)::Int

# The solve of `solve!` after its gate. `cap` is the step budget of each scalar root: `solve!` passes the default
# `_LA_ROOT_CAP`, and the tests pass smaller values, or a function of the iteration number, to reach `:prox_failed`.
function _solve_logistic_admm!(x::Vector{Float64}, f, g::NormL1, method::LogisticADMM, t0, u0;
                               cap = _LA_ROOT_CAP)
  w = _la_workspace(x, f, g, method, t0, u0, _la_cap(cap, 1))
  ρ = w.rho
  iterations = 0
  reason = :maxiter
  saved = (NaN, NaN, NaN, NaN, NaN, false)
  while iterations < method.maxiter
    w.cap = _la_cap(cap, iterations + 1)
    status = _la_iterate!(w, method)
    if status === :prox_failed
      # the residuals and the inner score of the discarded iteration are not reported
      w.r_norm, w.s_norm, w.eps_pri, w.eps_dual, w.inner_kkt, w.inner_met = saved
      reason = :prox_failed
      break
    end
    iterations += 1
    saved = (w.r_norm, w.s_norm, w.eps_pri, w.eps_dual, w.inner_kkt, w.inner_met)
    if _la_converged(w, method.tol)
      reason = :converged
      break
    elseif status === :stalled
      reason = :stalled
      break
    end
  end
  # The reported dual: with no completed iteration a supplied u keeps its entries; otherwise u = w/ρ, formed in a private
  # vector. dual_kkt and predictor_residual are those of the reported b, t and u, formed before any write to the
  # caller's arrays, from the scaled dual ŵ = ρ .* u (in w.diff, free at this point): dual_kkt is the Float64 score of
  # Xᵀŵ and predictor_residual the largest |σ(t) - y - ŵ|. These are Float64 evaluations with range limits (LA-01):
  # dual_kkt can be Inf or NaN when terms X[i, j] ŵ[i] or partial sums of Xᵀŵ overflow, also where the exact sum is
  # representable or 0, and subnormal rounding of an entry ρ u[i] can distort its contribution, upward or downward, or
  # remove it when the entry rounds to 0. Neither is refused.
  kept = iterations == 0 && u0 !== nothing
  uout = kept ? u0 : w.w ./ ρ
  ŵ = w.diff
  @. ŵ = ρ * uout
  mul!(w.sv, transpose(w.X), ŵ)
  dual_kkt = kkt_violation(w.g, w.sv, w.b)
  residual = 0.0
  @inbounds for i in eachindex(w.t)
    residual = max(residual, abs(_la_residual(w.t[i], isone(w.y[i])) - ŵ[i]))
  end
  copyto!(x, w.b)
  # with no completed iteration a supplied t keeps its entries (the predictor of the start is that t)
  t = t0 === nothing ? copy(w.t) : (iterations == 0 ? t0 : copyto!(t0, w.t))
  u = u0 === nothing || kept ? uout : copyto!(u0, uout)
  LogisticADMMResults(x, w.F, w.kkt, method.tol, iterations, w.passes, w.roots, w.r_norm, w.s_norm, w.eps_pri,
                      w.eps_dual, w.inner_kkt, w.inner_met, dual_kkt, residual, t, u, ρ, reason === :converged, reason)
end

function solve!(x, f, g, method::LogisticADMM; t = nothing, u = nothing, kwargs...)
  _check_keywords(kwargs)
  _check_admm_logistic_problem(x, f, g)
  _solve_logistic_admm!(x, f, g, method, t, u)
end
