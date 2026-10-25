####################################
#
#  Nonconvex penalties by local linear approximation (reweighted ℓ1)
#
####################################

"""
    LLA(inner = CDSolver(); stages = 2, tol = 1e-12, start = :lasso)

Local linear approximation (LLA), also called reweighted ℓ1, for the
nonconvex penalties `CappedL1`, `LogPenalty`, `MCP`, `SCAD`, `GroupMCP` and
`GroupSCAD` of ProximalBase, with the penalty as defined (a fixed cap, a fixed
`ε`, a fixed `a`). Each stage minimizes the loss plus the tangent of the
penalty at the previous solution: the weighted lasso with the weights
`pⱼ′(|xⱼ|)` of `ProximalBase.lla_weights!`, or the weighted group lasso with
`pₖ′(‖x_Gₖ‖₂)` for a group penalty. Each stage is convex and is solved by
`inner`; alternating stages and weights decreases the loss plus the penalty
(majorization-minimization).

- `stages`: the most stages at a level, the first one included. The stages
  stop early once the weights change by at most `tol`, relative to the largest
  weight; the default `tol` is rounding, so that a stage is skipped only when
  it would repeat the last one. The default, two stages from zero, is the lasso followed by one
  weighted lasso: the two-step estimator of Fan, Xue and Zou (2014). A large
  `stages`, such as 100, with `tol` iterates until the weights stop changing,
  as do the multi-stage convex relaxation of T. Zhang (2010), the difference
  of convex functions of Shen, Pan and Zhu (2012) and the reweighted ℓ1 of
  Candès, Wakin and Boyd (2008). For `CappedL1` the weights take finitely many
  values, and the default `tol` stops when they repeat.
- `start`: where the first stage of a level of [`solve_path`](@ref) takes its
  weights. With `:lasso`, the default, from zero, so that the first stage is
  the lasso with the weights `pⱼ′(0)` and every level starts again from it, as
  the papers do. With `:previous`, from the solution at the previous level,
  which follows the path more cheaply.

[`solve_path`](@ref)`(f, g, λs, LLA())` gives the path, and `solve!(x, f, g,
LLA())` one level, with the first weights at `x`: from zero the first stage is
the lasso, and from an initial estimate one stage is the one-step estimator of
Zou and Li (2008).
"""
struct LLA
  inner::CDSolver
  stages::Int
  tol::Float64
  start::Symbol

  function LLA(inner::CDSolver, stages::Integer, tol::Real, start::Symbol)
    stages >= 1 || throw(ArgumentError("stages must be positive, but it is $stages."))
    tol >= 0 || throw(ArgumentError("tol must be nonnegative, but it is $tol."))
    start in (:lasso, :previous) || throw(ArgumentError("start must be :lasso or :previous, but it is :$start."))
    new(inner, Int(stages), Float64(tol), start)
  end
end
LLA(inner::CDSolver = CDSolver(); stages::Integer = 2, tol::Real = 1e-12, start::Symbol = :lasso) =
  LLA(inner, stages, tol, start)

# The penalties that LLA takes, at the level λ: CappedL1, LogPenalty, MCP, SCAD
# and their group versions, and NormL1 and GroupNormL2, their own linearizations.
_lla_with_level(g::NormL1, λ) = NormL1(λ, g.w)
_lla_with_level(g::CappedL1, λ) = CappedL1(λ, g.a, g.w)
_lla_with_level(g::LogPenalty, λ) = LogPenalty(λ, g.ε, g.w)
_lla_with_level(g::Union{MCP, SCAD, GroupNormL2, GroupMCP, GroupSCAD}, λ) = _with_level(g, λ)
_lla_with_level(g, λ) = _unsupported_lla(g)
_unsupported_lla(g) =
  throw(ArgumentError("LLA takes CappedL1, LogPenalty, MCP, SCAD, GroupMCP or GroupSCAD (or NormL1 and GroupNormL2), but g is a $(typeof(g))" *
                      (g isa NormLq ? "; NormLq has an infinite slope at zero, so its LLA weights there are infinite." : ".")))

_lla_level(g::Union{CappedL1, LogPenalty, MCP, SCAD}) = g.λ
_lla_level(g::Union{NormL1, GroupNormL2, GroupMCP, GroupSCAD}) = g.λ0
_lla_level(g) = _unsupported_lla(g)

# The penalty of a stage at the level λ, with the weights w relative to λ, so that
# the stage has the level λ of the path: a weighted lasso, or a weighted group
# lasso for a group penalty
_lla_isgroup(g) = g isa Union{GroupNormL2, GroupMCP, GroupSCAD}
_lla_stage(g, λ, w) = _lla_isgroup(g) ? GroupNormL2(λ, g.groups, w) : NormL1(λ, w)

# a buffer for the weights: one per entry of x, or one per group
_lla_buffer(g, x::AbstractArray{T}) where {T} =
  _lla_isgroup(g) ? Vector{T}(undef, length(g.groups)) : _gradient_buffer(x)

# w ← the LLA weights of gλ at x, relative to the level λ (zero at λ = 0, where
# the stage has no penalty)
function _lla_weights!(w, gλ, λ, x)
  lla_weights!(w, gλ, x)
  if iszero(λ)
    fill!(w, zero(eltype(w)))
  else
    w ./= λ
  end
  return w
end

# the largest change of a weight, relative to the largest old weight
function _lla_change(wnew, wold)
  d, s = zero(eltype(wold)), zero(eltype(wold))
  for i in eachindex(wnew, wold)
    d = max(d, abs(wnew[i] - wold[i]))
    s = max(s, abs(wold[i]))
  end
  return iszero(d) ? d : d / max(s, floatmin(s))
end

# The next stage from the solution x of the stage gs, with the weights in
# whichever of the buffers a and b gs does not use: (the next stage, the change
# of the weights). The update of reweight!.
function _lla_next(gλ, λ, gs, x, a, b)
  w = gs.w === a ? b : a
  _lla_weights!(w, gλ, λ, x)
  _lla_stage(gλ, λ, w), _lla_change(w, gs.w)
end

"""
    solve!(x, f, g, method::LLA)

Local linear approximation at one level: the stages of `method` (see
[`LLA`](@ref)) for the nonconvex penalty `g`, the first with the weights at `x`,
each warm started from the previous solution, by [`reweight!`](@ref). From
`x = 0` the first stage is the lasso; from an initial estimate, such as the
unpenalized fit, `LLA(stages = 1)` is the one-step estimator of Zou and Li
(2008). `x` is a `SparseIterate`, a `SymmetricSparseIterate`, or an
`AtomIterate` with the groups of a group penalty, and holds the solution on
return. Returns [`ReweightResults`](@ref): `iterations` is the number of stages,
`converged` whether the weights stopped changing, `penalty` the weighted lasso
of the last stage and `next` that of the stage after it.
"""
function solve!(x::Union{SparseIterate, SymmetricSparseIterate, AtomIterate}, f::Union{AbstractFunction, CDModel},
                g::AbstractFunction, method::LLA)
  λ = _lla_level(g)
  m = f isa CDModel ? f : cdmodel(f, x)
  T = eltype(m)
  a, b = _lla_buffer(g, x), _lla_buffer(g, x)
  g1 = _lla_stage(g, T(λ), _lla_weights!(a, g, λ, x))
  _check_iterate(g1, x)
  check_penalty(m, g1)
  # a change at most tol is below the next float above tol
  reweight!(x, m, g1, (gs, x, m) -> _lla_next(g, T(λ), gs, x, a, b), method.inner;
            maxiter = method.stages, tol = nextfloat(method.tol))
end

"""
    solve_path(f, g, λs, method::LLA; x, screening = true, maxnnz = Inf, callback = nothing)

The path of local linear approximation (see [`LLA`](@ref)) along the
decreasing levels `λs`, for `g` a `CappedL1`, `LogPenalty`, `MCP`, `SCAD`,
`GroupMCP` or `GroupSCAD` of ProximalBase, whose level is `λ` (for
`LogPenalty(λ, ε)`, the slope at zero is `λ/ε`). At each level the stages of
`method` run; with `start = :lasso` the first stage is the lasso with the
weights `pⱼ′(0)`, warm started from the lasso at the previous level, and with
`start = :previous` it takes its weights from the solution at the previous
level and starts from it. The later stages start from the stage before.

Every stage is a weighted lasso (a weighted group lasso for a group penalty),
convex, so its screening is exact: with `screening`, the first stage uses the
sequential strong rule for the step from the previous level, and the later
stages the coordinates that are nonzero or violate their optimality condition
at the previous stage; the optimality conditions of the others are checked
after each stage, as for [`solve_path`](@ref) with `CDSolver`, and the gap-safe
rule of `CDSolver(; gapsafe = true)` applies inside the stages that have a
duality gap. The first level of a grid is usually [`lambda_max`](@ref)`(f, g,
x)`, the level of the first stage. The path stops early after the first
solution with more than `maxnnz` nonzero coordinates, or when
`callback(k, λ, x, m)` returns `true`.

Returns [`PathResults`](@ref): its `values` are the loss plus `g` at each level,
the passes and checks are summed over the stages, `converged` says whether
coordinate descent converged in every stage, and `stages` gives the number of
stages at each level.
"""
function solve_path(f::Union{AbstractFunction, CDModel}, g::AbstractFunction, λs::AbstractVector{<:Real},
                    method::LLA; x = _default_iterate(f), screening::Bool = true, maxnnz::Real = Inf,
                    callback = nothing)
  all(λ -> λ >= 0, λs) || throw(ArgumentError("The penalty levels must be nonnegative."))
  issorted(λs; rev = true) || throw(ArgumentError("The penalty levels must be decreasing."))
  m = f isa CDModel ? f : cdmodel(f, x)
  T = eltype(m)
  s = method.inner
  g1 = _lla_with_level(g, one(T))
  # the weights at zero, relative to the level, which do not depend on it
  w0 = lla_weights!(_lla_buffer(g, x), g1, _zero_like(x))
  a, b = _lla_buffer(g, x), _lla_buffer(g, x)
  _check_iterate(_lla_stage(g1, one(T), w0), x)
  check_penalty(m, _lla_stage(g1, one(T), w0))
  lasso = method.start === :lasso
  initialize!(m, x)
  st = _CDState(T, x, s)
  xl = lasso ? copy(x) : x                  # the iterate of the lasso stages
  grad = _gradient_buffer(x)
  gradient!(grad, m, x)
  gradl = lasso ? copy(grad) : grad         # the gradient at xl
  inS = falses(ncoordinates(x))
  λprev = _lambda_max(x, grad, _lla_stage(g1, one(T), w0))      # λmax at the starting point
  solutions = Any[]
  out = PathResults(T[], [], T[], Int[], Bool[], Int[], Int[], T[])
  for (k, λ) in enumerate(λs)
    λ = T(λ)
    gλ = _lla_with_level(g, λ)
    # the first stage: the lasso, on xl, or with the weights at the previous solution
    gs = lasso ? _lla_stage(gλ, λ, w0) : _lla_stage(gλ, λ, _lla_weights!(a, gλ, λ, x))
    _initialize!(m, xl, false)    # the cache may be that of x, and does not drift along the path
    checks = _lla_solve!(xl, m, gs, λprev, gradl, st, s, inS, screening)
    passes, converged = st.passes, st.converged
    if lasso
      copyto!(x, xl)
      copyto!(grad, gradl)
    end
    stages = 1
    while stages < method.stages
      gnext, change = _lla_next(gλ, λ, gs, x, a, b)
      change <= method.tol && break
      gs = gnext
      # from the previous stage at the same level: the strong set is the nonzero
      # coordinates and the violators of the new stage's optimality conditions
      checks += _lla_solve!(x, m, gs, λ, grad, st, s, inS, screening)
      passes += st.passes
      converged &= st.converged
      stages += 1
    end
    λprev = λ
    push!(out.λ, λ); push!(solutions, _snapshot(x)); push!(out.values, loss_value(m, x) + gλ(x))
    push!(out.passes, passes); push!(out.converged, converged); push!(out.kkt_checks, checks)
    push!(out.stages, stages); push!(out.gap, st.relgap)
    (callback !== nothing && callback(k, λ, x, m) === true) && break
    nactive(x) > maxnnz && break
  end
  S = isempty(solutions) ? Any : typeof(first(solutions))
  PathResults{S, T}(out.λ, convert(Vector{S}, solutions), out.values, out.passes, out.converged, out.kkt_checks,
                    out.stages, out.gap)
end

# one stage, screened for the step from the level λprev, or not; m is current
# for x, and grad holds the gradient at x on return when screening
function _lla_solve!(x, m, g, λprev, grad, st, s::CDSolver, inS, screening::Bool)
  if screening
    checks = _screened!(x, m, g, λprev, grad, st, s, inS)
  else
    _cd!(x, m, g, st, s)
    checks = 0
  end
  _warn_not_converged(st, s)
  return checks
end
