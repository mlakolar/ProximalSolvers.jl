"""
    CDSolver(; maxpasses=100_000, tol=1e-7, order=:random, relative=true,
               momentum=nothing, rng=Random.default_rng(), anderson=0,
               gaptol=0, gapsafe=false)

Coordinate descent for the least-squares lasso. Call
`solve!(beta, f, g, CDSolver())` with matching `Float32` or `Float64`
design/response data and coefficients. The coefficient storage can be
a dense `Vector` or a one-dimensional ProximalBase `SparseIterate`.

`CDSolver()` uses random coordinate order and the algorithm's default
momentum behavior, a reasonable exploratory choice. For deterministic
tutorial examples use `CDSolver(order=:cyclic, momentum=false)`;
for repeatable random order supply `rng=Xoshiro(seed)` from `Random`.
The borrowed RNG advances when used. Cyclic order does not support
`momentum=true`.

`tol` (default `1e-7`) measures coefficient change, **not** independent
optimality. With `relative=true`, the stopping threshold is `tol` times the
response scale `sqrt(s * sum(abs2, y))`, `s` the loss scale; the sum of
squares and its product with `s` may leave the range of the working type.
For `y = 0` the threshold is the absolute `tol`. A response scale whose
computed value, rounded to the working type, is not a normal number is refused
with an `ArgumentError` before the first pass: rescale the data or use
`relative=false` (an objective that overflows is still refused). `tol` times a
normal response scale can be subnormal or 0. The test `change < threshold`
cannot hold for a threshold of 0, so the run cannot converge by it and ends at
`maxpasses` with a warning, unless an independent numerical failure (for
example a non-finite coordinate step) stops it first with an error.
A column whose squared norm `a` is not finite in the working type is refused with
an `ArgumentError` before the first change of its coordinate, and the starting
point is unchanged. Where the product `s * a` or its reciprocal is outside the
normal range of the type that combines `s` with the working type, the
coordinate step forms its threshold `lambda / (s * a)` without them.
`relative=false` makes the threshold an absolute change threshold;
`maxpasses` limits the run. An end-of-pass convergence flag does not
guarantee a small KKT residual. For reported fits, check optimality
independently. Anderson acceleration, gap certificates and screening
are not implemented: `anderson`, `gaptol` and `gapsafe` are accepted only
at their defaults, are not stored, and other values are rejected.

Once the active passes since the last full pass have together visited 20 times
as many coordinates as a full pass, the next pass is a full pass even when the
active changes have not fallen below the threshold. Float32 rounding of the
coefficients can also keep the largest change of every full pass at or above the
effective threshold (the reported `tolerance`; with `relative=true` and a
positive response scale, each coordinate change is first multiplied by
`sqrt(s * a)`, `a` the squared norm of its column); the run then ends at
`maxpasses` without converging, with the warning. A threshold well above that
rounding level avoids this; Float64 data has a much lower rounding level.

A `SparseIterate` is solved on a private copy retaining its initial
active zeros and coordinate order. After a completed finite run the caller
receives the complete final state, including any zero-coordinate
compaction. The copy needs `O(p)` extra storage. See [`solve!`](@ref)
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
passes, converged, maxchange and tolerance. Compatibility fields kkt_checks=0 and
gap=NaN are sentinels, never computed certificates.
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
# full after a converged pass, active otherwise. Only a converged full pass stops.
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
      st.converged = true
      break
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
      st.converged = true
      break
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
function _warn_not_converged(st::_CDState, s::CDSolver)
  st.converged && return
  @warn "coordinate descent did not converge in maxpasses = $(s.maxpasses) passes (last change $(round(st.maxchange; sigdigits = 3)), tolerance $(round(st.tolerance; sigdigits = 3)))."
end
# The run shared by the dense and owner wrappers, on a private SparseIterate: the
# solve, the not-converged warning and the finite-objective check. It returns the
# state and the final objective; the caller commits the point only afterwards.
function _run_cd!(work::SparseIterate, f, g, method::CDSolver)
  m = cdmodel(f, work)
  initialize!(m, work)
  st = _CDState(eltype(work), work, method)
  _cd!(work, m, g, st, method)
  _warn_not_converged(st, method)
  result_value = loss_value(m, work)+g(work)
  isfinite(result_value) || throw(ArgumentError("coordinate descent produced a nonfinite objective; rescale the problem"))
  st, result_value
end
function _solve_dense!(x::Vector, f, g, method::CDSolver)
  xs = SparseIterate(x)
  st, result_value = _run_cd!(xs, f, g, method)
  _copy_dense!(x, xs)
  CDResults(x, result_value, st.passes, st.converged, st.maxchange, st.tolerance, 0)
end
# The run does not touch the caller's owner: it works on a state-preserving private
# copy (values, active zeros and slot order), and the owner changes only at the final
# same-shape owner-to-owner copy, which carries the compaction order with it.
function _solve_owner!(x::SparseIterate, f, g, method::CDSolver)
  work = copy(x)
  st, result_value = _run_cd!(work, f, g, method)
  copyto!(x, work)
  CDResults(x, result_value, st.passes, st.converged, st.maxchange, st.tolerance, 0)
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
  end
  _check_problem(x, f, g)
  _solve_dense!(x, f, g, method)
end
solve!(x, f, g, method::ProximalSolver, args...; kwargs...) =
  throw(ArgumentError("unsupported solver/options combination"))
