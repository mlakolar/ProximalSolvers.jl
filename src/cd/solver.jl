"""
    CDSolver(; maxpasses=100_000, tol=1e-7, order=:random, relative=true,
               momentum=nothing, rng=Random.default_rng(), anderson=0,
               gaptol=0, gapsafe=false)

Coordinate descent for dense Float32/Float64 least-squares lasso (including
weights), elastic net, ridge, group lasso and square-root lasso. Use a dense vector
or one-dimensional `SparseIterate` for scalar problems, a `BlockIterate` for
groups, or matrix coefficients for row-group multi-response regression.
`solve!` updates the supplied coefficients. For deterministic scalar examples,
choose `order=:cyclic, momentum=false`.

```julia
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
beta = zeros(2)
result = solve!(beta, (1/3)*LeastSquaresLoss(y, X), NormL1(0.1),
                CDSolver(order=:cyclic, momentum=false))
```

`converged` is a change test, with an additional certificate for square-root
lasso; see [result semantics](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/results-failures/#RES-01).

## Keywords

- `maxpasses=100_000`: maximum number of coordinate passes.
- `tol=1e-7`: change tolerance; it is not an independent accuracy target.
- `order=:random`: random coordinate order; `:cyclic` is deterministic.
- `relative=true`: scale the change test using the response and coordinate curvature;
  `false` uses an absolute change threshold.
- `momentum=nothing`: use the algorithm's default momentum policy. `false` disables
  momentum. `true` is unsupported for cyclic order and group problems.
- `rng=Random.default_rng()`: borrowed random generator, advanced when used.
  Create a fresh seeded generator to reproduce a random order.
- `anderson=0`: reserved Anderson-acceleration setting; only `0` is accepted.
- `gaptol=0`: reserved dual-gap stopping target; only `0` is accepted.
- `gapsafe=false`: reserved gap-safe screening switch; only `false` is accepted.
  These three compatibility settings are not stored or used.

# Extended help

The data arrays share one `Float32` or `Float64` element type. With least squares,
use `NormL1(lambda)`, `NormL1(lambda, w)`, an unweighted `ElasticNet` or an
uncentered `SqrNormL2(lambda)` for scalar coefficients. Ridge via `SqrNormL2`
is supported only by CD, for dense vectors or one-dimensional `SparseIterate`;
a centered penalty is refused, even with an all-zero center. Weights must be a
matching `Vector{T}` satisfying the validated
coefficient-range rules; a zero weight leaves its coordinate unpenalized.
Group penalties require matching partitions; matrix-response groups are the rows
of the coefficient matrix, indexed through `vec(B)`.

Square-root lasso requires an unscaled `SqrtLeastSquaresLoss` and unweighted
`NormL1(lambda)` with `lambda > 0`. For the normalized square-root objective,
use `lambda = sqrt(n)*lambda_n` in this unnormalized interface.
For a positive minimum, `converged=true` proves a relative objective error of at
most `1e-4`. The certificate bound is rounded upward to the working type `T` for
`gap`, so its stored Float32 value can be slightly above `1e-4`.
After an uncertified change-test stop, a bounded smoothing
fallback can certify the stopped point or return a point with a proved lower
objective. It uses the remaining `maxpasses` budget and the solver's order,
momentum, RNG and tolerances; its passes count in the result and its random
passes advance the borrowed RNG. A run that reaches `maxpasses` does not start
this fallback. Recovery at exact fits is not guaranteed: a final uncertified
result has `converged=false`, `gap=NaN` and a warning. See the
[bounded square-root fallback](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/cd-sqrt-lasso/#CDQ-05).

CD commits coefficients only after a completed run with a finite objective.
An exception escaping `solve!` preserves the caller's starting coefficients,
although a borrowed RNG may have advanced. After a successful sparse/group solve, obtain
fresh active-coordinate/value views because compaction can change the storage.

Detailed rules:

- [Scalar steps, schedules and change tests](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/cd-scalar/#CD-01).
- [Sparse storage and commit semantics](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/cd-sparse-iterate/#CDS-01).
- [Group steps, curvature and refusals](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/cd-group/#CDG-01).
- [Multi-response shapes and row groups](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/cd-multiresponse/#CDM-01).
- [Square-root steps and bounded certificate](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/cd-sqrt-lasso/#CDQ-01).

See [`solve!`](@ref)
and the [solver guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/choosing-solver/).
"""
struct CDSolver{R<:AbstractRNG} <: ProximalSolver
  maxpasses::Int
  tol::Float64
  random::Bool
  relative::Bool
  momentum::Union{Nothing, Bool}
  rng::R
  # The only constructor, so every route into a CDSolver is validated.
  function CDSolver(maxpasses::Integer, tol::Real, random::Bool, relative::Bool,
                    momentum::Union{Nothing, Bool}, rng::R) where {R<:AbstractRNG}
    maxpasses >= 0 || throw(ArgumentError("maxpasses must be nonnegative, but it is $maxpasses."))
    isfinite(Float64(tol)) && tol >= 0 || throw(ArgumentError("tol must be nonnegative, but it is $tol."))
    momentum === true && !random &&
      throw(ArgumentError("momentum needs order = :random; with the cyclic order it can stall far from the minimizer."))
    new{R}(maxpasses, tol, random, relative, momentum, rng)
  end
end

# anderson, gaptol and gapsafe are accepted at their defaults only and not stored.
function CDSolver(; maxpasses::Integer = 100_000, tol::Real = 1e-7, order::Symbol = :random,
                  relative::Bool = true, anderson::Integer = 0, momentum::Union{Nothing, Bool} = nothing,
                  rng::AbstractRNG = default_rng(), gaptol::Real = 0.0, gapsafe::Bool = false)
  order in (:random, :cyclic) || throw(ArgumentError("order must be :random or :cyclic, but it is :$order."))
  solver = CDSolver(maxpasses, tol, order === :random, relative, momentum, rng)
  anderson >= 0 || throw(ArgumentError("anderson must be nonnegative, but it is $anderson."))
  isfinite(Float64(gaptol)) && gaptol >= 0 || throw(ArgumentError("gaptol must be nonnegative, but it is $gaptol."))
  iszero(anderson) || throw(ArgumentError("Anderson acceleration is deferred"))
  iszero(gaptol) || throw(ArgumentError("gap certificates are deferred"))
  !gapsafe || throw(ArgumentError("gap screening is deferred"))
  solver
end

Base.summary(::CDSolver) = "Coordinate Descent"
"""
    CDResults

Result sharing the caller's vector or `SparseIterate` as minimizer, with minimum,
passes, converged, maxchange and tolerance. The compatibility field `kkt_checks = 0` is a
sentinel. `gap` is `NaN` except after a certified square-root lasso run (see [`CDSolver`](@ref)),
where `converged = true` and `gap` is the certified upper bound on `(P - P*)/P*`. For the square-root
lasso, `passes` includes the passes of the fallback after an uncertified stop, and is at most `maxpasses`.
For the
least-squares lasso, elastic net, ridge and group lasso, `converged` reports the change test and
`gap` is `NaN`.
"""
struct CDResults{X, T}
  minimizer::X
  minimum::T
  passes::Int
  converged::Bool
  maxchange::T
  tolerance::T
  kkt_checks::Int
  gap::T
end

CDResults(x, minimum::T, passes, converged, maxchange, tolerance, kkt_checks) where {T} =
  CDResults(x, minimum, passes, converged, maxchange, tolerance, kkt_checks, T(NaN))

Base.summary(::CDResults) = "Coordinate Descent"
minimizer(r::CDResults) = r.minimizer
minimum(r::CDResults) = r.minimum
iterations(r::CDResults) = r.passes
converged(r::CDResults) = r.converged

function Base.show(io::IO, r::CDResults)
  @printf io "Results of Optimization Algorithm\n"
  @printf io " * Algorithm: %s\n" summary(r)
  @printf io " * Minimum: %e\n" r.minimum
  @printf io " * Passes: %d\n" r.passes
  @printf io " * Convergence: %s\n" r.converged
  @printf io "   * largest change in the last pass %.2e (tolerance %.2e)\n" r.maxchange r.tolerance
  isnan(r.gap) || @printf io "   * relative duality gap %.2e\n" r.gap
  r.kkt_checks > 0 && @printf io " * Optimality checks after screening: %d\n" r.kkt_checks
  return
end

# Nesterov momentum on the passes over the active set (see CDSolver), as in
mutable struct _Momentum{T}
  xprev::Vector{T}      # the active values after the pass before the last
  xcur::Vector{T}       # the active values after the last pass
  y::Vector{T}          # the active values the last pass started from
  cprev::Vector{T}      # the cache of the model at xprev
  ccur::Vector{T}       # the cache of the model at xcur
  n::Int                # number of active values in the history
  na::Int               # number of active coordinates in the history
  k::Int
  moved::Bool           # whether the cache moved since it was last computed
end

_Momentum{T}() where {T} = _Momentum{T}(T[], T[], T[], T[], T[], 0, 0, 1, false)
mutable struct _CDState{T, R<:AbstractRNG}
  random::Bool
  rng::R
  order::Vector{Int}
  momentum::_Momentum{T}
  passes::Int
  converged::Bool
  maxchange::T
  tolerance::T
end
_CDState(::Type{T}, x, s::CDSolver) where T =
  _CDState{T, typeof(s.rng)}(s.random, s.rng, Vector{Int}(undef, s.random ? ncoordinates(x) : 0),
                          _Momentum{T}(), 0, false, T(NaN), T(NaN))
function _shuffle!(order::Vector{Int}, n::Int, rng::AbstractRNG)
  @inbounds for i in 1:n
    order[i] = i
  end
  @inbounds for i in 1:n-1
    j = rand(rng, i:n)
    order[i], order[j] = order[j], order[i]
  end
  order
end

# one pass over the candidate coordinates (full) or the active ones; returns the
# largest change of a coordinate, scaled if `scaled`
function _pass!(x, m, g, st::_CDState{T}, full::Bool, scaled::Bool) where {T}
  maxh = if full
    _sweep!(x, m, g, st, scaled, Base.OneTo(ncoordinates(x)))
  else
    _sweep!(x, m, g, st, scaled, activecoordinates(x))
  end
  dropzeros!(x)
  maxh
end

# visits `coords` (all coordinates, or the stored active ones) in order or in a
# fresh random permutation. An active pass needs `coords` to stay the same during
# the pass: `LSModel`'s step writes only the coordinate it visits, which is stored,
# and a zero write keeps it stored; `dropzeros!` runs after the pass, in `_pass!`.
function _sweep!(x, m, g, st::_CDState{T}, scaled::Bool, coords) where {T}
  n = length(coords)
  maxh = zero(T)
  if st.random
    order = _shuffle!(st.order, n, st.rng)
    for i in 1:n
      h = _visit!(m, g, x, @inbounds(coords[order[i]]), scaled)
      h > maxh && (maxh = h)
    end
  else
    for i in 1:n
      h = _visit!(m, g, x, @inbounds(coords[i]), scaled)
      h > maxh && (maxh = h)
    end
  end
  maxh
end
function _cd!(x, m, g, st::_CDState{T}, s::CDSolver) where T
  if _usemomentum(s, x, m)
    _cd_momentum!(x, m, g, st, s)
  else
    _cd_plain!(x, m, g, st, s)
  end
  x
end
function _tolerances(m, x, s::CDSolver, ::Type{T}) where T
  sy = s.relative ? response_scale(m, x) : one(T)
  scaled = s.relative && sy>0
  u = scaled ? sy : one(T)
  T(s.tol)*u, scaled
end
# After each pass, the strict change test `maxh < tol` selects the next pass:
# full after a converged pass, active otherwise. Only a converged full pass stops, through the model's
# `_stop_check!`: for least squares and the group lasso it stops with `converged = true`; for the
# square-root loss it stops certified or uncertified, or it lowers the threshold, and the loop then
# reads `tol` again and continues (in the momentum loop, after `_momentum_reset!`, as after any full
# pass that does not stop).
#
# A full pass is the only pass that visits the coordinates outside the active set, which are at 0.
# A full pass also follows active passes that, since the last full pass, together visited
# `_FULL_PASS_WORK` times as many coordinates as a full pass, p = `ncoordinates(x)`: active changes
# that stay above `tol` through rounding, as with Float32 steps near the tolerance (#311), then
# still lead to a full pass. A forced full pass visits p coordinates after active passes that
# visited at least `_FULL_PASS_WORK * p`, so the forced passes of a run make at most
# `1 / _FULL_PASS_WORK` of the visits of that run's active passes; a forced pass also changes the
# iterates that follow, so this does not bound the run's total work against a schedule without
# forced passes. In the momentum loop, a forced full pass first refreshes the cache if momentum
# moved it, as the converged active pass before an ordinary full pass does.
const _FULL_PASS_WORK = 20
function _cd_plain!(x, m, g, st::_CDState{T}, s::CDSolver) where {T}
  tol, scaled = _tolerances(m, x, s, T)
  st.passes, st.converged, st.maxchange, st.tolerance = 0, false, T(NaN), tol
  converged, visits = true, 0
  for pass in 1:s.maxpasses
    full = converged || visits >= _FULL_PASS_WORK * ncoordinates(x)
    visits = full ? 0 : visits + nactive(x)
    maxh = _pass!(x, m, g, st, full, scaled)
    st.passes, st.maxchange = pass, maxh
    converged = maxh<tol
    if full && converged
      status = _stop_check!(m, g, x, st, maxh, scaled)
      if status === :retry
        tol = st.tolerance
        converged = maxh<tol
      else
        st.converged = status === :converged
        break
      end
    end
  end
  x
end
function _usemomentum(s::CDSolver, x, m)
  s.momentum === false && return false
  s.momentum === nothing && return s.random && x isa SparseIterate && _momentum_default(m)
  x isa SparseIterate ||
    throw(ArgumentError("momentum needs a private SparseIterate, not a $(typeof(x))."))
  true
end

# the cache of a model that is affine in x, which momentum moves with the
# point; nothing for a model that momentum initializes at the point instead
_cache(m::CDModel) = nothing

# called after momentum moved the cache with the point, for a model that derives
# from the cache what is not affine in x (such as a derived cache value)
_cache_moved!(m::CDModel, x) = m

# whether momentum is used by default, with a random order on a SparseIterate:
# for the models whose cache moves with the point, where it pays off
_momentum_default(m::CDModel) = _cache(m) !== nothing
function _cd_momentum!(x, m, g, st::_CDState{T}, s::CDSolver) where {T}
  tol, scaled = _tolerances(m, x, s, T)
  st.passes, st.converged, st.maxchange, st.tolerance = 0, false, T(NaN), tol
  mom = _momentum_start!(st.momentum, x, m)
  converged, visits = true, 0
  for pass in 1:s.maxpasses
    full = converged || visits >= _FULL_PASS_WORK * ncoordinates(x)
    visits = full ? 0 : visits + nactive(x)
    if !full
      _momentum_step!(mom, x, m)
    elseif !converged
      _momentum_refresh!(mom, x, m)
    end
    maxh = _pass!(x, m, g, st, full, scaled)
    st.passes, st.maxchange = pass, maxh
    converged = maxh<tol
    if full && converged
      status = _stop_check!(m, g, x, st, maxh, scaled)
      if status === :retry
        tol = st.tolerance
        converged = maxh<tol
      else
        st.converged = status === :converged
        break
      end
    end
    if full
      _momentum_reset!(mom, x, m)
    elseif converged
      _momentum_refresh!(mom, x, m)
    else
      _momentum_update!(mom, x, m)
    end
  end
  x
end

# a new history for a run, with buffers for every entry and for the cache
function _momentum_start!(s::_Momentum, x, m)
  n = _maxvalues(x)
  if length(s.xcur) < n
    resize!(s.xprev, n); resize!(s.xcur, n); resize!(s.y, n)
  end
  c = _cache(m)
  if c !== nothing && length(s.ccur) != length(c)
    resize!(s.ccur, length(c)); resize!(s.cprev, length(c))
  end
  s.n, s.na, s.k, s.moved = 0, 0, 1, false
  s
end

# starts the history at x, as after a full pass or when the active set shrank
function _momentum_reset!(s::_Momentum, x, m)
  n = _nvalues(x)
  s.n, s.na, s.k = n, nactive(x), 1
  _values!(s.xcur, x, n)
  copyto!(s.xprev, 1, s.xcur, 1, n)
  c = _cache(m)
  if c !== nothing
    copyto!(s.ccur, c)
    copyto!(s.cprev, c)
  end
  s
end

# moves x and the cache of m to the point the next pass over the active set
# starts from; a model without a cache that moves is initialized there, keeping
# the curvatures of the groups, which depend only on the data
function _momentum_step!(s::_Momentum{T}, x, m) where {T}
  n = s.n
  β = s.k > 1 ? T((s.k - 1) / (s.k + 2)) : zero(T)
  @inbounds for j in 1:n
    s.y[j] = s.xcur[j] + β * (s.xcur[j] - s.xprev[j])
  end
  iszero(β) && return s
  _setvalues!(x, s.y, n)
  c = _cache(m)
  if c === nothing
    _initialize!(m, x, false)
  else
    @inbounds @simd for i in eachindex(c)
      c[i] = s.ccur[i] + β * (s.ccur[i] - s.cprev[i])
    end
    _cache_moved!(m, x)
    s.moved = true
  end
  s
end

# after a pass over the active set: restarts when its step points against the
# momentum, and records the new point
function _momentum_update!(s::_Momentum{T}, x, m) where {T}
  nactive(x) == s.na || return _momentum_reset!(s, x, m)
  n = s.n
  d = _restartdot(s, x, n)
  s.k = s.k > 1 && d < 0 ? 1 : s.k + 1
  s.xprev, s.xcur = s.xcur, s.xprev
  _values!(s.xcur, x, n)
  c = _cache(m)
  if c !== nothing
    s.cprev, s.ccur = s.ccur, s.cprev
    copyto!(s.ccur, c)
  end
  s
end

# computes the cache again where repeated moves may have let it drift, keeping
# the curvatures of the groups, before full-pass stopping checks
function _momentum_refresh!(s::_Momentum, x, m)
  s.moved && _initialize!(m, x, false)
  s.moved = false
  s
end
_nvalues(x::SparseIterate) = nactive(x)
_maxvalues(x::SparseIterate) = ncoordinates(x)
_values!(v::Vector, x::SparseIterate, n::Int) = copyto!(v, 1, activevalues(x), 1, n)
_setvalues!(x::SparseIterate, v::Vector, n::Int) = copyto!(activevalues(x), 1, v, 1, n)
function _restartdot(s::_Momentum{T}, x::SparseIterate, n::Int) where {T}
  av, d = activevalues(x), zero(T)
  @inbounds for j in 1:n
    d += (av[j] - s.y[j]) * (s.xcur[j] - s.xprev[j])
  end
  d
end
# The warning of a run that did not converge: an uncertified stop of the square-root loss
# (`uncertified`, from the model's `_uncertified`) has its own text; any other such run ended at maxpasses.
function _warn_not_converged(st::_CDState, s::CDSolver, uncertified::Bool)
  st.converged && return
  if uncertified
    @warn "coordinate descent stopped without a duality certificate after $(st.passes) passes (last change $(round(st.maxchange; sigdigits = 3)), tolerance $(round(st.tolerance; sigdigits = 3))): the point is not certified to be within a relative 1e-4 of the minimum (for example at an exact fit y = X*beta with a positive penalty, where a coordinatewise minimum need not be a minimum)."
  else
    @warn "coordinate descent did not converge in maxpasses = $(s.maxpasses) passes (last change $(round(st.maxchange; sigdigits = 3)), tolerance $(round(st.tolerance; sigdigits = 3)))."
  end
end
# The run shared by the dense and owner wrappers, on a private SparseIterate: the
# solve, the model's fallback after an uncertified stop (`_fallback!`, which updates the state and the
# model's outcome), the not-converged warning and the finite-objective check. It returns the
# state, the final objective and the result's gap (`_result_gap` of the model); the caller commits
# the point only afterwards.
function _run_cd!(work::Union{SparseIterate, BlockIterate}, f, g, method::CDSolver)
  m = cdmodel(f, work)
  initialize!(m, work)
  method.maxpasses > 0 && _prepare!(m, g, work)
  st = _CDState(eltype(work), work, method)
  _cd!(work, m, g, st, method)
  _uncertified(m) && _fallback!(m, g, work, st, method)
  _warn_not_converged(st, method, _uncertified(m))
  result_value = loss_value(m, f, work)+g(work)
  isfinite(result_value) || throw(ArgumentError("coordinate descent produced a nonfinite objective; rescale the problem"))
  st, result_value, _result_gap(m)
end
function _solve_dense!(x::Vector, f, g, method::CDSolver)
  xs = SparseIterate(x)
  st, result_value, gap = _run_cd!(xs, f, g, method)
  _copy_dense!(x, xs)
  CDResults(x, result_value, st.passes, st.converged, st.maxchange, st.tolerance, 0, gap)
end
# The run does not touch the caller's owner: it works on a state-preserving private
# copy (values, active zeros and slot order), and the owner changes only at the final
# same-shape owner-to-owner copy, which carries the compaction order with it.
function _solve_owner!(x::Union{SparseIterate, BlockIterate}, f, g, method::CDSolver)
  work = copy(x)
  st, result_value, gap = _run_cd!(work, f, g, method)
  copyto!(x, work)
  CDResults(x, result_value, st.passes, st.converged, st.maxchange, st.tolerance, 0, gap)
end
# The matrix-response route: the run is on a private BlockIterate over vec(B), built with the groups of the
# penalty (the rows of B, which `_check_matrix_problem` checks), and B changes only at the final copy. The gate
# refuses a B that shares memory with X, Y, the penalty weights or the scratch of the loss.
function _solve_matrix!(B::Matrix, f, g, method::CDSolver)
  work = BlockIterate(vec(B), g.groups)
  st, result_value, gap = _run_cd!(work, f, g, method)
  copyto!(vec(B), work)
  CDResults(B, result_value, st.passes, st.converged, st.maxchange, st.tolerance, 0, gap)
end
function _copy_dense!(dest::Vector{T}, src::SparseIterate{T}) where {T}
  fill!(dest, zero(T))
  @inbounds for k in _activeentries(src)
    dest[k] = src[k]
  end
  dest
end

function solve!(x, f, g, method::CDSolver; kwargs...)
  _check_keywords(kwargs)
  if x isa SparseIterate
    _check_owner_problem(x, f, g)
    return _solve_owner!(x, f, g, method)
  elseif x isa BlockIterate
    _check_block_problem(x, f, g, method)
    return _solve_owner!(x, f, g, method)
  elseif x isa Matrix && _is_matrix_response(f)
    _check_matrix_problem(x, f, g, method)
    return _solve_matrix!(x, f, g, method)
  end
  _check_problem(x, f, g, :cd)
  _solve_dense!(x, f, g, method)
end
solve!(x, f, g, method::ProximalSolver, args...; kwargs...) =
  throw(ArgumentError("unsupported solver/options combination"))
