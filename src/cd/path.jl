####################################
#
#  Penalty levels: λmax, paths, screening
#
####################################

# a zero iterate of the type and size of x
_zero_like(x::SparseIterate{T}) where {T} = SparseIterate(T, size(x)...)
_zero_like(x::SymmetricSparseIterate{T}) where {T} = SymmetricSparseIterate(T, x.p)
_zero_like(x::AtomIterate{T}) where {T} = AtomIterate(T, length(x), x.groups)

# the smallest level of g with a zero solution, from the gradient grad at zero:
# maxₖ ‖∇ₖ f(0)‖ / wₖ over the penalized coordinates; those with weight zero are
# not zero at any level
function _lambda_max(x, grad::AbstractArray{T}, g) where {T}
  λmax = zero(T)
  for k in 1:ncoordinates(x)
    w = _coordweight(g, x, k)
    iszero(w) && continue
    t = _screengrad(g, grad, x, k) / w
    t > λmax && (λmax = t)
  end
  λmax
end

"""
    lambda_max(f, g, x)

The smallest penalty level `λ` for which zero minimizes `f + g` with the level
of `g` replaced by `λ` (`NormL1(λ, w)` for `g = NormL1(λ0, w)`, and so on):
`maxₖ |∇ₖf(0)| / wₖ` over the coordinates of iterates like `x` whose weight is
not zero, with `‖∇_G f(0)‖₂` for the groups of a `GroupNormL2`. The level of
`Scaled(ElasticNet(α, 1 - α, w), λ)` is its scale `λ`, and its weights are
`α wₖ`. So is the level of the sparse group lasso at a fixed mixture,
`Scaled(SparseGroupNormL2(α, 1 - α, groups, w), λ)`: group `G` is zero at the
level `λ` when `‖soft(∇_G f(0), αλ)‖₂ ≤ (1 - α)λ w_G`, and `λmax` is the largest
of the levels at which this starts to hold, each the exact root of a quadratic.
On a box, `Constrained(g, IndBox(l, u))` with `l ≤ 0 ≤ u`, only the
part of the gradient that points into the box counts: `(-∇ₖf(0))₊` when
`uₖ > 0` and `(∇ₖf(0))₊` when `lₖ < 0`, so that `λmax` of the nonnegative
lasso, `Constrained(NormL1(λ), IndBox(0, Inf))`, is `maxₖ (-∇ₖf(0))₊ / wₖ`.

`CappedL1(λ, a, w)` and `LogPenalty(λ, ε, w)` have paths by [`LLA`](@ref)
only, and their `λmax` is that of the first stage, the lasso with the slopes at
zero: the weights `wₖ` and `wₖ/ε`. Zero is then a stationary point of
`f + g`, and the first stage of LLA from zero stays there.

For an unpenalized coordinate with nonzero gradient, this routine returns
only the threshold over penalized coordinates; it is not a certificate that
the whole coefficient vector can be zero. For nonconvex penalties the slope
threshold describes stationarity at zero, not global optimality.
"""
function lambda_max(f::Union{AbstractFunction, CDModel}, g::AbstractFunction, x)
  g isa _BoxConstrained && _check_zero_in_box(g.box)
  m = f isa CDModel ? f : cdmodel(f, x)
  x0 = _zero_like(x)
  initialize!(m, x0)
  grad = _gradient_buffer(x0)
  gradient!(grad, m, x0)
  _lambda_max(x0, grad, g)
end

# The exact coordinate steps of MCP and SCAD, and of their group versions, agree
# with the test at zero of λmax, the strong rule and the optimality checks only
# when each coordinate problem is convex: when the curvature L of the step
# exceeds the concavity of the penalty, a·L > 1 for MCP and (a - 1)·L > 1 for
# SCAD, as ncvreg requires a > 1 and a > 2 on standardized columns. Otherwise
# the step can leave zero where the slope test says that zero is optimal, and
# λmax and screening go wrong. Paths and continuation refuse such a penalty; a
# single solve does not use the test and is left alone. L is the curvature that
# the step divides by, over the number of entries a coordinate of a
# SymmetricSparseIterate sets, and the curvature of the group on an AtomIterate.
_needsconvexsteps(g) = false
_needsconvexsteps(::Union{MCP, SCAD, GroupMCP, GroupSCAD}) = true
_needsconvexsteps(c::_BoxConstrained) = _needsconvexsteps(c.f)

function _check_convex_steps(m::CDModel, g, x)
  _needsconvexsteps(g) || return nothing
  _hasstepcurvature(m, x) || return nothing     # a model that does not give its curvatures
  ρ = _concavity(g)
  for k in 1:ncoordinates(x)
    _penalized(g, x, k) || continue
    L = _stepcurvature(m, x, k)
    (iszero(L) || L > ρ) && continue       # with L = 0 the loss does not depend on the coordinate
    throw(ArgumentError(_convex_steps_message(g, x, k, L)))
  end
  return nothing
end

_penalized(g, x, k::Int) = true
_penalized(g::Union{GroupMCP, GroupSCAD}, x::AtomIterate, k::Int) = !iszero(g.w[k])

_hasstepcurvature(m::CDModel, x) = applicable(coordinate_derivatives, m, x, 1)
_hasstepcurvature(m::CDModel, x::AtomIterate) = applicable(_groupcurvature!, m, x, 1)
_stepcurvature(m::CDModel, x::SparseIterate, k::Int) = coordinate_derivatives(m, x, k)[2]
# the curvatures that the models cache, which their steps then reuse: one pass
# over the column for least squares, none for a GLM's bound
_stepcurvature(m::LSModel, x::SparseIterate, k::Int) = m.s * _sqnorm!(m, k)
_stepcurvature(m::GLMModel, x::SparseIterate, k::Int) = _curvaturebound!(m, k)
function _stepcurvature(m::CDModel{T}, x::SymmetricSparseIterate, k::Int) where {T}
  r, c = tril_cartesian(x.p, k)
  coordinate_derivatives(m, x, k)[2] / _multiplicity(T, r, c)
end
_stepcurvature(m::CDModel, x::AtomIterate, k::Int) = _groupcurvature!(m, x, k)

function _convex_steps_message(g, x, k::Int, L)
  p = g isa _BoxConstrained ? g.f : g
  mcp = p isa Union{MCP, GroupMCP}
  cond = mcp ? "a·L > 1" : "(a - 1)·L > 1"
  val = mcp ? p.a * L : (p.a - 1) * L
  what = x isa AtomIterate ? "group $k" : "coordinate $k"
  "a path or continuation with $(nameof(typeof(p))) needs every coordinate step to be convex, $cond, " *
    "where L is the curvature of the step, but $what has L = $(round(L; sigdigits = 4)) and a = $(p.a), " *
    "so that $cond fails ($(round(val; sigdigits = 4))). The exact step could then leave zero where the slope " *
    "test of λmax and screening says that zero is optimal. Standardize the columns (L = 1 for the loss " *
    "‖y - Xβ‖²/(2n) with columns of unit variance, as in ncvreg), take a larger a, or use the path of " *
    "local linear approximation, solve_path(f, g, λs, LLA())."
end

# Solves at the penalty g, warm started from x, with the sequential strong rule
# of Tibshirani et al. (2012) for the step from the level λprev to λ = level(g):
# full passes visit only the coordinates with ‖∇ₖf‖ ≥ (2λ - λprev) wₖ at the
# previous solution, the nonzero ones and the unpenalized ones. After
# convergence the optimality conditions ‖∇ₖf‖ ≤ λ wₖ of the other coordinates
# are checked with one full gradient, and violators are added and the problem
# solved again. m must be current for x, and grad holds the gradient at x on
# entry and on return; inS has one entry per coordinate. Returns the number of
# checks; st.passes holds the passes of all the solves.
#
# With gaptol, each solve stops on the gap of the problem restricted to the
# candidates, and the full gradient of the check gives the gap of the whole
# problem, which st.relgap then holds: without violators, the two agree up to
# rounding. If the whole gap still exceeds gaptol, the candidates are solved
# again to a tenfold smaller restricted gap, at most _GAPRETRIES times.
function _screened!(x, m::CDModel{T}, g, λprev, grad::AbstractArray, st::_CDState{T}, s::CDSolver,
                    inS::BitVector) where {T}
  λ = _level(g)
  threshold = 2λ - λprev
  for k in eachindex(inS)
    w = _coordweight(g, x, k)
    inS[k] = iszero(w) || _isnonzero(x, k) || _strongkeep(g, grad, x, k, threshold, w)
  end
  passes, checks, retries = 0, 0, 0
  sk = s
  while true
    st.candidates = findall(inS)
    _cd!(x, m, g, st, sk)
    passes += st.passes
    gradient!(grad, m, x)
    checks += 1
    violated = false
    for k in eachindex(inS)
      if !inS[k] && _kktviolated(g, grad, x, k, λ)
        inS[k] = true
        violated = true
      end
    end
    violated && continue
    st.gapmode || break
    _fullgap!(st, m, g, x, grad) <= s.gaptol && break
    (st.converged && retries < _GAPRETRIES) || break
    retries += 1
    sk = _with(sk; gaptol = sk.gaptol / 10)
  end
  st.candidates = nothing
  st.passes = passes
  checks
end

const _GAPRETRIES = 3

"""
    PATH_GAPTOL = 1e-4

The default target of the relative duality gap at each level of
[`solve_path`](@ref) and at the last level of continuation; see
[`solve_path`](@ref). This controls objective error when a feasible dual certificate is available.
Coefficient error requires additional curvature or identifiability assumptions.
`gaptol = 1e-3` is the documented faster setting, for cross-validation and
prediction, and `gaptol = 0` gives back the rule on the changes.
"""
const PATH_GAPTOL = 1e-4

# PATH_GAPTOL, but at least 64 roundings: the gap is computed to about eps |P|
_default_gaptol(::Type{T}) where {T} = max(PATH_GAPTOL, 64 * Float64(eps(T)))

# The solver of the levels of a path or of the last level of continuation, with
# the gap target gaptol: nothing for the default, the gaptol of s when it has
# one and _default_gaptol otherwise; 0 for the rule on the changes. The default
# is dropped without a warning when m and g have no duality gap, which then
# keep the rule on the changes.
function _path_solver(s::CDSolver, gaptol::Union{Nothing, Real}, m, g)
  if gaptol === nothing
    s.gaptol > 0 && return s
    _hasgap(m, g) || return s
    return _with(s; gaptol = _default_gaptol(eltype(m)))
  end
  isfinite(Float64(gaptol)) && gaptol >= 0 || throw(ArgumentError("gaptol must be nonnegative, but it is $gaptol."))
  _with(s; gaptol = Float64(gaptol))
end

"""
    solve!(x, f, g, method::CDSolver; continuation, continuation_tol, screening, gaptol)

With `continuation = n > 0`, `x` is set to zero and `f + g` is minimized along
`n` penalty levels spaced geometrically from [`lambda_max`](@ref) down to the
level of `g`, then at `g` itself, each warm started from the previous solution.
The levels before `g` only give warm starts, so they are solved to the looser
tolerance `continuation_tol` (`√tol` for the tolerance `tol` of `method`, by
default) by the rule on the changes, and only `g` to the final accuracy;
`continuation_tol = method.tol` solves every level to `tol`. As the levels of
[`solve_path`](@ref), the level of `g` stops on a relative duality gap of at
most `gaptol` when `f` and `g` have one: [`PATH_GAPTOL`](@ref) `= 1e-4` by
default (or `method.gaptol` when it is positive), `1e-3` for a faster, looser
solve, `0` for the rule on the changes with `tol`. The `gap` of the results
reports the gap reached. With `screening`, each level is screened with the strong rule
(see [`solve_path`](@ref)); the default screens except on a
`SymmetricSparseIterate`, whose coordinate steps update the gradient
everywhere, so that the optimality checks of screening cost more passes than
they save. When the level of `g` is zero or at least `lambda_max`, `f + g` is
minimized from zero directly, and so it is for a penalty without a level
(`ZeroFunction`, `IndBox`, …), which has no path. As for [`solve_path`](@ref),
MCP, SCAD and their group versions need convex coordinate steps along the
levels, and an `ArgumentError` says so when they are not.
"""
function solve!(x::Union{SparseIterate, SymmetricSparseIterate, AtomIterate}, f::Union{AbstractFunction, CDModel},
                g::AbstractFunction, method::CDSolver; continuation::Integer,
                continuation_tol::Real = sqrt(method.tol), screening::Bool = !(x isa SymmetricSparseIterate),
                gaptol::Union{Nothing, Real} = nothing)
  continuation_tol >= 0 || throw(ArgumentError("continuation_tol must be nonnegative, but it is $continuation_tol."))
  tol = max(Float64(continuation_tol), method.tol)
  _continuation!(x, f, g, method, continuation, screening, k -> tol, gaptol)
end

# continuation along n levels, solving level k < n to the tolerance tolk(k)
# and the last one, g, with method and the gap target gaptol (see _path_solver)
function _continuation!(x, f, g, method::CDSolver, continuation::Integer, screening::Bool, tolk, gaptol = nothing)
  continuation >= 0 || throw(ArgumentError("continuation must be nonnegative, but it is $continuation."))
  continuation == 0 && return solve!(x, f, g, gaptol === nothing ? method : _with(method; gaptol = Float64(gaptol)))
  m = f isa CDModel ? f : cdmodel(f, x)
  _check_iterate(g, x)
  check_penalty(m, g)
  method = _path_solver(method, gaptol, m, g)
  T = eltype(m)
  fill!(x, zero(T))
  initialize!(m, x)
  _check_convex_steps(m, g, x)
  st = _CDState(T, x, method)
  _haslevel(g) || return _continuation_direct!(x, m, g, st, method)
  grad = _gradient_buffer(x)
  gradient!(grad, m, x)
  λmax = _lambda_max(x, grad, g)
  λ = _level(g)::Real
  zero(λmax) < λ < λmax || return _continuation_direct!(x, m, g, st, method)
  passes, checks = 0, 0
  l1, l2 = log(λmax), log(λ)
  inS = falses(ncoordinates(x))
  λprev = λmax
  for k in 0:continuation
    gk = k == continuation ? g : _with_level(g, exp(l1 + k * (l2 - l1) / continuation))
    sk = k == continuation ? method : _with_tol(method, tolk(k))
    if screening
      checks += _screened!(x, m, gk, λprev, grad, st, sk, inS)
    else
      _cd!(x, m, gk, st, sk)
    end
    passes += st.passes
    λprev = _level(gk)
  end
  _warn_not_converged(st, method)
  CDResults(x, loss_value(m, x) + g(x), passes, st.converged, st.maxchange, st.tolerance, checks, st.relgap)
end

# The no-path branch has no gradient or previous penalty level.
function _continuation_direct!(x, m, g, st, method)
  _cd!(x, m, g, st, method)
  _warn_not_converged(st, method)
  CDResults(x, loss_value(m, x) + g(x), st.passes, st.converged, st.maxchange, st.tolerance, 0, st.relgap)
end

# the solver for the levels before the target, which only give warm starts:
# the tolerance tol, and no stopping on the duality gap
_with_tol(s::CDSolver, tol::Real) = _with(s; tol = Float64(tol), gaptol = 0.0)

Base.eltype(::CDModel{T}) where {T} = T

"""
    PathResults

Returned by [`solve_path`](@ref): the penalty levels `λ` that were solved
for, the `solutions` (a `SparseVector` per level for a vector iterate, a sparse
matrix for a matrix iterate), the objective `values`, and per level the
`passes`, whether coordinate descent `converged`, the number of `kkt_checks`
of the screening, the number of `stages` (1, except along a path of
[`LLA`](@ref), where the passes and the checks are summed over the stages),
and the relative duality `gap` certified at each level when the levels stop on
the gap (see `gaptol` in [`solve_path`](@ref)), `NaN` where they stop on the
rule on the changes.
"""
struct PathResults{S, T}
  λ::Vector{T}
  solutions::Vector{S}
  values::Vector{T}
  passes::Vector{Int}
  converged::Vector{Bool}
  kkt_checks::Vector{Int}
  stages::Vector{Int}
  gap::Vector{T}
end

# a compact copy of the solution
_snapshot(x::SparseIterate{T, 1}) where {T} = _sparsevec(x)
_snapshot(x::AtomIterate) = _snapshot_dense(x) ? sparsevec(Vector(x)) : _sparsevec(x)
_snapshot(x::SymmetricSparseIterate) = _snapshot_dense(x) ? sparse(Matrix(x)) : sparse(x)

# Triplet construction saves a dense copy for sparse solutions, but its index
# arrays and SparseArrays' workspace can cost more at higher densities. Keep
# the dense conversion above a conservative stored-entry fraction of 1/16.
_snapshot_dense(x::SparseIterate) = nactive(x) > length(x) ÷ 16
_snapshot_dense(x::SymmetricSparseIterate) = nactive(x) > ncoordinates(x) ÷ 16

function _snapshot_dense(x::AtomIterate)
  n = 0
  limit = length(x) ÷ 16
  for k in activecoordinates(x)
    n += length(x.groups[k])
    n > limit && return true
  end
  false
end

function _sparsevec(x::Union{SparseIterate{T, 1}, AtomIterate{T}}) where {T}
  ind = Int[]
  val = T[]
  for k in _activeentries(x)
    v = x[k]
    iszero(v) && continue
    push!(ind, k); push!(val, v)
  end
  sparsevec(ind, val, length(x))
end

function _snapshot(x::SparseIterate{T, 2}) where {T}
  _snapshot_dense(x) && return sparse(Matrix(x))
  rows, cols, vals = Int[], Int[], T[]
  n, p = size(x)
  for k in activecoordinates(x)
    v = x[k]
    iszero(v) && continue
    push!(rows, mod1(k, n)); push!(cols, div(k - 1, n) + 1); push!(vals, v)
  end
  sparse(rows, cols, vals, n, p)
end

function _screening_state(x, m, g, screening::Bool)
  T = eltype(m)
  grad = screening ? _gradient_buffer(x) : T[]
  inS = falses(screening ? ncoordinates(x) : 0)
  λprev = zero(T)
  if screening
    gradient!(grad, m, x)
    λprev = _lambda_max(x, grad, g)   # at the possibly nonzero starting point
  end
  grad, inS, λprev
end

"""
    solve_path(f, g, λs, method = CDSolver(); x, screening = true, maxnnz = Inf, callback = nothing, gaptol)

Minimize `f + gₖ` along the decreasing penalty levels `λs`, where `gₖ` is `g`
with level `λs[k]`, each warm started from the previous solution. The level of
`ElasticNet(λ1, λ2, w)` is `λ1`, with `λ2` fixed; for glmnet's elastic-net path
at a fixed `α`, `λ(α ∑ᵢ wᵢ|xᵢ| + (1 - α)‖x‖²/2)`, take
`g = Scaled(ElasticNet(α, 1 - α, w), 1)`, whose level is the scale; for the
sparse group lasso path of R's SGL and sparsegl,
`λ(α‖x‖₁ + (1 - α)Σₖ wₖ‖x_Gₖ‖₂)`, take
`g = Scaled(SparseGroupNormL2(α, 1 - α, groups, w), 1)` and `x = AtomIterate(p, groups)`. The iterate
`x` (a zero `SparseIterate` of the right length when `f` has columns, which
must otherwise be given) is the starting point and holds the last solution on
return.

With `screening`, each level is solved first over the coordinates kept by the
sequential strong rule of Tibshirani et al. (2012), and the optimality
conditions of the others are checked afterwards; violators are added and the
problem solved again. The path stops early after the first solution with more
than `maxnnz` nonzero coordinates, or when `callback(k, λ, x, m)` returns `true`
(`m` is the [`CDModel`](@ref), current for `x`; use it, for example, to compute
a validation loss). Returns [`PathResults`](@ref).

Each level stops on a certified relative duality gap, `(P - D)/|P| ≤ gaptol`
with `P = f + gₖ` at the solution and `D` the dual objective at the dual point
built from the gradient (see [`duality_gap`](@ref)), when `f` and `g` have a
gap: least squares and the GLMs with the squared, logistic, Poisson or Huber
loss, with `NormL1`, `NormL1Nonneg`, `ElasticNet`, `GroupNormL2` or the sparse
group lasso. The default `gaptol` is [`PATH_GAPTOL`](@ref) `= 1e-4` (or
`method.gaptol` when it is positive); `gaptol = 1e-3` is the faster setting for
cross-validation and prediction. During the solve the gap is that of the
problem restricted to the candidates of the strong rule, at the cost of one
pass over them; the full gradient of the optimality check of screening then
gives the gap of the whole problem, which the `gap` of the results reports.
A valid relative gap `ε` bounds objective suboptimality by `ε * abs(P)`.
It does not bound coefficient error without additional assumptions. Historical
workload-specific comparisons are retained in the
[snapshot](https://github.com/mlakolar/ProximalSolvers.jl/tree/f7e3f28026a8e83e0fa18203b39839cf57a1c949/benchmark/gap).
Other losses and penalties, a coordinate without penalty whose gradient is
nonzero, and `gaptol = 0` use
the coordinate-change rule with `tol` instead.

The slope test at zero, on which λmax and screening rest, agrees with the
exact coordinate steps of `MCP(λ, a)`, `SCAD(λ, a)`, `GroupMCP` and `GroupSCAD`
only when each coordinate problem is convex: `a·Lₖ > 1` for MCP and
`(a - 1)·Lₖ > 1` for SCAD, where `Lₖ` is the curvature of the step along
coordinate `k` (of group `k`, for a group penalty). A path, and continuation,
with these penalties throws an `ArgumentError` when a penalized coordinate
fails it. For least squares, standardized columns give `Lₖ = 1` with the loss
`‖y - Xβ‖²/(2n)`, so that ncvreg's conditions `a > 1` and `a > 2` suffice.
The path of [`LLA`](@ref), `solve_path(f, g, λs, LLA())`, has no such
condition.
"""
function solve_path(f::Union{AbstractFunction, CDModel}, g::AbstractFunction, λs::AbstractVector{<:Real},
                    method::CDSolver = CDSolver(); x = _default_iterate(f), screening::Bool = true,
                    maxnnz::Real = Inf, callback = nothing, gaptol::Union{Nothing, Real} = nothing)
  all(λ -> isfinite(λ) && λ >= 0, λs) || throw(ArgumentError("The penalty levels must be finite and nonnegative."))
  issorted(λs; rev = true) || throw(ArgumentError("The penalty levels must be decreasing."))
  m = f isa CDModel ? f : cdmodel(f, x)
  T = eltype(m)
  _check_iterate(g, x)
  check_penalty(m, g)
  isempty(λs) || _with_level(g, T(first(λs)))      # a penalty with a level
  method = _path_solver(method, gaptol, m, g)
  initialize!(m, x)
  _check_convex_steps(m, g, x)
  st = _CDState(T, x, method)
  grad, inS, λprev = _screening_state(x, m, g, screening)
  solutions = Any[]
  out = PathResults(T[], [], T[], Int[], Bool[], Int[], Int[], T[])
  for (k, λ) in enumerate(λs)
    gk = _with_level(g, T(λ))
    if screening
      _initialize!(m, x, false)   # no drift of the cache along the path; the data are the same
      checks = _screened!(x, m, gk, λprev, grad, st, method, inS)
      λprev = T(λ)
    else
      _cd!(x, m, gk, st, method)
      checks = 0
    end
    _warn_not_converged(st, method)
    push!(out.λ, T(λ)); push!(solutions, _snapshot(x)); push!(out.values, loss_value(m, x) + gk(x))
    push!(out.passes, st.passes); push!(out.converged, st.converged); push!(out.kkt_checks, checks); push!(out.stages, 1)
    push!(out.gap, st.relgap)
    (callback !== nothing && callback(k, T(λ), x, m) === true) && break
    nactive(x) > maxnnz && break
  end
  S = isempty(solutions) ? Any : typeof(first(solutions))
  PathResults{S, T}(out.λ, convert(Vector{S}, solutions), out.values, out.passes, out.converged, out.kkt_checks,
                    out.stages, out.gap)
end

_default_iterate(f::LeastSquaresLoss{T, <:AbstractVector}) where {T} = SparseIterate(T, size(f.X, 2))
_default_iterate(f::Scaled) = _default_iterate(f.f)
_default_iterate(f::GLMLoss{L, T}) where {L, T} = SparseIterate(T, size(f.X, 2))
_default_iterate(f::QuadraticFunction{T}) where {T} = SparseIterate(T, size(f.A, 2))
_default_iterate(f::SqrtQuadraticFunction{T}) where {T} = SparseIterate(T, length(f.b))
_default_iterate(f) = throw(ArgumentError("give the starting iterate x of the path"))
