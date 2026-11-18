"""
    CDSolver(; maxpasses=100_000, tol=1e-7, order=:random, relative=true,
               momentum=nothing, rng=Random.default_rng(), anderson=0,
               gaptol=0, gapsafe=false)

Coordinate descent for the least-squares lasso and elastic net, and, with ProximalBase's
`SqrtLeastSquaresLoss`, the square-root lasso (described below). Call
`solve!(beta, f, g, CDSolver())` with matching `Float32` or `Float64`
design/response data and coefficients. The coefficient storage can be
a dense `Vector` or a one-dimensional ProximalBase `SparseIterate`. With the least-squares
loss, the penalty is `NormL1(lambda)`, `NormL1(lambda, w)` or an unweighted `ElasticNet(lambda1, lambda2)`
(the square-root lasso, below, takes an unweighted `NormL1` with a positive level). The weights `w`
of a `NormL1` are a `Vector{T}` (`T` the element type of the data) with finite nonnegative entries (see
[`solve!`](@ref)): `solve!` checks the coefficient `T(lambda) w[j]` of entry `j`, the product rounded in `T`, to be zero
or a normal number of `T` (with `T(lambda)` zero or normal as well), and a zero weight leaves it unpenalized. The
coordinate step in the normal range is ProximalBase's `prox_block`, which forms its threshold from `lambda` and
`w[j]` in its working type; see [Supported problems](https://mlakolar.github.io/ProximalSolvers.jl/dev/support/#weighted-lasso-support)
for how that threshold and the checked coefficient can differ.
For an `ElasticNet` the coordinate step of a visit in the normal range is ProximalBase's
`prox_block` of the penalty. Let `s` be the loss scale and `a` the squared norm of the
column, finite and positive. At a visit where `s * a` or its reciprocal is below
`floatmin` of the type that combines `s` with the working type, the step with
`lambda2 = 0` is the lasso's range-safe form (the threshold formed without the product
or its reciprocal), and with `lambda2 > 0` the visit is refused with an `ArgumentError`
that names the coordinate; for a `NormL1` with weights the step there is the lasso's range-safe form at
the coefficient `T(lambda) w[k]` of the coordinate. The refusal happens during the pass: the iterate passed to
`solve!` is unchanged, and a borrowed RNG may have advanced. A visit to a flat column
(all entries 0) sets its coordinate to 0, at the levels that `solve!` accepts, for each of these
penalties (also where a weight is zero); a visit to a column that is not flat and whose `a` underflows to 0 is refused
as for the lasso. With `maxpasses = 0` no coordinate is visited.
For a group lasso it can be a ProximalBase `BlockIterate`, as described below.

`CDSolver()` uses random coordinate order and the algorithm's default
momentum behavior, a reasonable exploratory choice. For deterministic
tutorial examples use `CDSolver(order=:cyclic, momentum=false)`;
for repeatable random order supply `rng=Xoshiro(seed)` from `Random`.
The borrowed RNG advances when used. Cyclic order does not support
`momentum=true`.

`tol` (default `1e-7`) measures coefficient change, **not** independent
optimality (the square-root lasso adds a certificate, below). With `relative=true`, the
stopping threshold is `tol` times the
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
`maxpasses` limits the run. For least squares (lasso and elastic net) and the group lasso, an end-of-pass
convergence flag does not guarantee a small KKT residual; for reported fits, check
optimality independently. What the change test implies, and where it can be met away
from a minimizer (a product that underflows or cancels, a warm start far above the
solution scale), is described in the
[numerical guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/stopping-limits/).
Anderson acceleration, a user-set gap target and screening
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
compaction. The copy needs `O(p)` extra storage.

**Group lasso.** With `T` equal to `Float32` or `Float64`, `x = BlockIterate(T, p, g)`
and `g = GroupNormL2(lambda, groups)` (or with weights), the call
`solve!(x, f, g, CDSolver(order=:cyclic, tol=1e-10))` minimizes the least-squares
loss plus `lambda * sum(w[k] * norm(x[groups[k]]))`. The loss is as for the lasso. `g` is a
`GroupNormL2{Float32}` or `GroupNormL2{Float64}` whose level and weights are finite,
nonnegative and representable in `T`, and its groups and those of `x` agree in number,
order and ordered members, otherwise a `DimensionMismatch` is thrown. The coordinates are
the groups, and a pass visits whole groups. `momentum = true` is refused with an
`ArgumentError`; `nothing` and `false` give plain block coordinate descent. The change of
a group is `norm` of its displacement, which `relative=true` multiplies by
`sqrt(s * l)` for a positive response scale, where `l` bounds the largest eigenvalue of
the Gram matrix of the columns of the group; the forced full pass counts group visits.
As for the lasso, `converged` reports this change test and is not a KKT certificate.
The curvature of a flat group, and of a group of one column when `n eps(T) <= 1/8` (`n`
the number of rows), is set before the first pass. That of any other group is computed
at the first visit that needs it when cheap bounds show that no refusal can occur (under the
eigenvalue model for groups of three or more columns and for groups of two columns outside the
range of their closed-form bound), and before the first pass otherwise. A visit to a nonflat group whose block is zero, active or
not, first applies ProximalBase's `prox_block!` to the correlations at the step `1/s`
(skipped when `1/s` is not a normal number of the scale's arithmetic type, or when the
correlations are not all zero and the largest magnitude is below `2^53 * floatmin(T)`) and ends without a
change, and without computing a still-deferred curvature, when the result is zero. Before
the first pass, and before any draw from the RNG, an `ArgumentError` that names the group
refuses a curvature that underflows or overflows in `T` and a step outside the normal
range, for each group whose curvature is computed then. An exception of the eigenvalue
routine (which a group of two columns inside the range of its closed-form bound does not
call), a refusal of a lazily computed curvature, and a trial point or displacement that
is not finite can occur during a pass; `x` is then unchanged, and the RNG may have
advanced. The curvature rule and the refusals are described in the numerical
guide.

**Square-root lasso.** With `T` equal to `Float32` or `Float64`, `X::Matrix{T}`, `y::Vector{T}`,
ProximalBase's `f = SqrtLeastSquaresLoss(y, X)` and `g = NormL1(lambda)`, the call
`solve!(x, f, g, CDSolver(...))` minimizes `P(beta) = norm(y - X*beta) + lambda * norm(beta, 1)`,
without a `1/sqrt(n)` factor, for a dense `Vector{T}` or a one-dimensional `SparseIterate{T}` `x`.
The normalized objective `norm(y - X*beta)/sqrt(n) + lambda_n * norm(beta, 1)` has the same
minimizers at `lambda = sqrt(n) * lambda_n`, and its values are those of `P` divided by `sqrt(n)`; a
scaled-lasso noise estimate is then `norm(y - X*beta)/sqrt(n)` at the solution. `lambda` must be
positive (at `lambda = 0`, use `LeastSquaresLoss`, which has the same minimizers), finite and
representable in `T`; it may be given in another `Real` type. A weighted `NormL1`, an `ElasticNet`,
`Scaled(SqrtLeastSquaresLoss, alpha)` (for a positive finite `alpha`, use the unscaled loss at the
level `lambda/alpha`), a `BlockIterate`, and `ProximalGradientDescent` or `AccProxGradDescent`
(ProximalBase provides no gradient for this loss; for `X != 0` it is not differentiable where
`y = X*beta`) are refused with an `ArgumentError` before `x` changes. A visit computes the minimizer
of `P` over its coordinate, up to rounding: a soft threshold at the least-squares centre with a threshold
that depends on the residual. The order, momentum, the change threshold and `maxpasses` are as for least
squares.

A full pass whose largest change is below the threshold runs a duality certificate: a dual point along
the residual `y - X*beta`, recomputed in `Float64`, with a proved bound on the rounding of each computed
term. `converged = true` only when it proves `(P(beta) - P*)/P* <= 1e-4`, `P*` the minimum, and `gap`
then holds that bound, rounded up; its denominator is a lower bound of `P*` from the dual point. When
the certificate does not pass, the change threshold (the reported `tolerance`) is divided by 100 and the
run continues, at most twice per solve, where `tolerance/100` is finite, positive and below `tolerance`
(an effective threshold that overflowed to `Inf` is not lowered), and not below a floor in the units of
the threshold: with a
relative threshold (`relative=true` and `y != 0`), `16 eps(T)` times `norm(y)`; with an absolute one
(`relative=false`, or `y = 0`), `16 eps(T)` times the largest `abs(beta[k])` at the check, and no
tightening at `beta = 0`. Otherwise the run stops with `converged = false`, `gap = NaN` and a warning that
differs from the `maxpasses` warning. This happens where the recomputed residual is 0 with a nonzero
coefficient, so that the dual direction is undefined: the usual outcome at an exact fit (`y = X*beta`)
with a positive penalty, where a coordinatewise minimum need not be a minimum (the residual can also
round to 0 where `y - X*beta` is not 0, and an exact fit whose recomputed residual is not 0 can be
certified, validly); after a full pass that changed nothing; with `y = 0` and a nonzero start, where `P* = 0`, so that no relative bound
can be certified unless `beta` reaches 0, and coordinate descent can approach 0 without reaching it; and
when the threshold cannot be lowered further, for example where the rounding of the recomputed residual
is not small against the residual itself (as where the fitted values dwarf it), or for `Float32` data
at the default `tol` with a relative threshold, where `tol/100` is below that floor. With `tol = 0`, or
a threshold below the changes that rounding produces, the change test does not pass, the certificate
does not run, and the run ends at `maxpasses` with that warning. At a stop of the certificate,
`minimum` is evaluated from the residual that it recomputed, when every entry of it is representable
in `T`.

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
where `converged = true` and `gap` is the certified upper bound on `(P - P*)/P*`. For the
least-squares lasso and elastic net and the group lasso, `converged` reports the change test and
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
# solve, the not-converged warning and the finite-objective check. It returns the
# state, the final objective and the result's gap (`_result_gap` of the model); the caller commits
# the point only afterwards.
function _run_cd!(work::Union{SparseIterate, BlockIterate}, f, g, method::CDSolver)
  m = cdmodel(f, work)
  initialize!(m, work)
  method.maxpasses > 0 && _prepare!(m, g, work)
  st = _CDState(eltype(work), work, method)
  _cd!(work, m, g, st, method)
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
  end
  _check_problem(x, f, g, :cd)
  _solve_dense!(x, f, g, method)
end
solve!(x, f, g, method::ProximalSolver, args...; kwargs...) =
  throw(ArgumentError("unsupported solver/options combination"))
