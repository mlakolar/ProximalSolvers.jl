####################################
#
#  The losses of coordinate descent, and what it needs from iterates and penalties
#
####################################

"""
    CDModel{T}

A loss together with the cache that makes its coordinate updates cheap, such as
the residuals of least squares. [`cdmodel`](@ref) builds one from a loss of
ProximalBase; [`solve!`](@ref) accepts a model in place of the loss, so that a
model built once serves many solves (paths, reweighting).

# A new model

A new loss is a subtype of `CDModel{T}` with these functions for the iterates
it supports. They are public but not exported: extend them as
`ProximalSolvers.initialize!` and so on.

- [`initialize!`](@ref)`(m, x)`, which makes the cache current for `x`.
- The coordinate step: either [`coordinate_derivatives`](@ref) and
  [`update_cache!`](@ref), from which coordinate descent takes a proximal
  step, or the whole step, [`coordinate_step!`](@ref).

Optional:

- [`coordinate_scale`](@ref) and [`response_scale`](@ref), the scales of the
  relative stopping rule. Without them the rule is absolute.
- [`loss_value`](@ref), the value of the loss from the cache. The results
  report it, and Anderson acceleration needs it.
- `gradient!(G, m, x)`, the gradient at `x` from the cache, as an array of the
  size of `x` (one entry per entry of `x`, also for a
  `SymmetricSparseIterate`). [`lambda_max`](@ref), screening, continuation and
  [`solve_path`](@ref) need it.
- [`check_penalty`](@ref), for a model that takes only some penalties.

Group penalties (`GroupNormL2`, `GroupNormLinf` and the other group norms of
ProximalBase, on an `AtomIterate`) work with the built-in least-squares and
quadratic models only. Momentum (see [`CDSolver`](@ref)) calls `initialize!` at each
extrapolated point of a new model.
"""
abstract type CDModel{T} end

"""
    initialize!(m::CDModel, x)

Make the cache of the model `m` current for the iterate `x`.
"""
function initialize! end

# initialize! that keeps the curvatures of the groups of an AtomIterate, which
# depend only on the data, with curvatures = false: for the levels of a path,
# where only the cache of x must be computed again. Models that cache no
# curvatures, as those defined outside the package, compute everything again.
_initialize!(m::CDModel, x, curvatures::Bool) = initialize!(m, x)

"""
    coordinate_derivatives(m::CDModel, x, k) -> (G, a)

The derivative `G` of the loss along coordinate `k` of `x` and its curvature
`a`, exact for a quadratic and otherwise an upper bound, from the cache of `m`.
The default [`coordinate_step!`](@ref) moves the coordinate to
[`prox_entry`](@ref)`(g, xₖ - G/a, i, μ/a)`, where `i` is the index of the
entry in `x` and `μ` the number of entries the coordinate sets (2 for an
off-diagonal coordinate of a `SymmetricSparseIterate`). The step is exact for a
quadratic loss, and a majorization step when `a` bounds the curvature.
"""
function coordinate_derivatives end

"""
    update_cache!(m::CDModel, x, k, h)

Update the cache of `m` for the change `h` of coordinate `k`, which is already
written into `x`.
"""
function update_cache! end

"""
    coordinate_step!(m::CDModel, g, x, k) -> h

Move coordinate `k` of `x` to decrease the loss plus the penalty `g`, update the
cache of `m`, and return the change of the coordinate. The default takes the
proximal step from [`coordinate_derivatives`](@ref) and
[`update_cache!`](@ref). A model can define it to fuse the computations, as
the built-in models do.
"""
function coordinate_step! end

"""
    coordinate_scale(m::CDModel, x, k)

The scale by which the relative stopping rule of [`CDSolver`](@ref) multiplies
the change of coordinate `k`: the square root of the curvature along it, such
as `‖X[:, k]‖ √s` for `s ‖y - Xβ‖² / 2`. Defaults to 1.
"""
coordinate_scale(m::CDModel{T}, x, k::Int) where {T} = one(T)

"""
    response_scale(m::CDModel, x)

The scale by which the relative stopping rule of [`CDSolver`](@ref) multiplies
`tol`, such as `‖y‖ √s` for `s ‖y - Xβ‖² / 2`. It defaults to zero, which
makes the rule absolute.
"""
response_scale(m::CDModel{T}, x) where {T} = zero(T)

"""
    loss_value(m::CDModel, x)

The value of the loss at `x`, from the cache of `m`. Defaults to `NaN`.
"""
loss_value(m::CDModel{T}, x) where {T} = T(NaN)

"""
    check_penalty(m::CDModel, g)

Throw an `ArgumentError` when the model `m` cannot take the penalty `g`. By
default a model takes every penalty.
"""
check_penalty(m::CDModel, g) = nothing

"""
    cdmodel(f, x)

The [`CDModel`](@ref) of the loss `f` for iterates like `x`: for
`LeastSquaresLoss`, a least-squares `GLMLoss` (with weights and an offset),
`LeastSquaresLoss` with a matrix `Y` (the multi-response lasso: `x` an
`AtomIterate` over `vec(B)` with the rows of `B` as groups,
`[k:p:p*q for k in 1:p]`, and `GroupNormL2` on them),
`QuadraticFunction` and [`KronQuadratic`](@ref), each possibly scaled, as in
`(1/n) * LeastSquaresLoss(y, X)`, for a logistic or Huber `GLMLoss`, and for
[`SqrtLeastSquaresLoss`](@ref) and [`SqrtQuadraticFunction`](@ref).
"""
function cdmodel end

cdmodel(f::AbstractFunction, x) =
  throw(ArgumentError("coordinate descent does not know the structure of $(typeof(f)); see the documentation of cdmodel."))

# The minimizer of a(x - old)²/2 + G(x - old) + μ gᵢ(x), the coordinate step
# shared by the fused quadratic kernels and the fixed-point diagnostic.
@inline function _coordinate_minimizer(g, old::T, G, a, i, μ = one(T)) where {T}
  isfinite(G) && isfinite(a) && a >= 0 ||
    throw(ArgumentError("coordinate descent needs finite derivatives and nonnegative curvature"))
  if iszero(a)
    new = _flat_minimizer(g, old, T(G), i, μ)
    new === nothing &&
      throw(ArgumentError("coordinate $i has zero curvature and its linear term $G makes f + g unbounded below along it, or no minimizer is available for this penalty"))
    return new
  end
  ainv = inv(a)
  isfinite(ainv) || throw(ArgumentError("the inverse coordinate curvature overflows; rescale the problem"))
  new = prox_entry(g, old - G * ainv, i, μ * ainv)
  isfinite(new) || throw(ArgumentError("the coordinate step is not finite; rescale the problem or check the model and penalty"))
  new
end

# With zero curvature the coordinate problem is min G(x - old) + μ gᵢ(x), which
# has a minimizer x exactly when x = prox_{tμgᵢ}(x - tG) for some (every) t > 0.
# Two candidates cover the separable penalties: the minimizer of the penalty
# nearest zero (the minimizer of a norm while |G| ≤ μλ) and the far end of a
# proximal step against G (a bound of a box). The step t scales G to the size
# of the candidate, so that rounding cannot make a huge point look fixed.
# Returns nothing when neither candidate is a minimizer.
function _flat_minimizer(g, old::T, G::T, i, μ) where {T}
  c = prox_entry(g, zero(T), i, floatmax(T))
  iszero(G) && return c
  _flat_fixed(g, c, G, i, μ) && return c
  c = prox_entry(g, -copysign(floatmax(T), G), i, μ)
  _flat_fixed(g, c, G, i, μ) ? c : nothing
end

function _flat_fixed(g, c::T, G::T, i, μ) where {T}
  isfinite(c) || return false
  t = max(one(T), abs(c) / abs(G))
  v = c - t * G
  isfinite(v) && prox_entry(g, v, i, t * μ) == c
end

# the coordinate step from coordinate_derivatives and update_cache!, for models
# that do not define their own; a coordinate with zero curvature, which the loss
# does not depend on, goes to the minimizer of the penalty nearest zero
@inline function coordinate_step!(m::CDModel{T}, g, x::SparseIterate{T}, k::Int) where {T}
  G, a = coordinate_derivatives(m, x, k)
  old = x[k]
  new = _coordinate_minimizer(g, old, G, a, k)
  h = new - old
  iszero(h) && return h
  x[k] = new
  update_cache!(m, x, k, h)
  h
end

@inline function coordinate_step!(m::CDModel{T}, g, x::SymmetricSparseIterate{T}, k::Int) where {T}
  G, a = coordinate_derivatives(m, x, k)
  r, c = tril_cartesian(x.p, k)
  cx = coordinates(x)
  old = cx[k]
  i = _entry(x.p, r, c)
  new = _coordinate_minimizer(g, old, G, a, i, _multiplicity(T, r, c))
  h = new - old
  iszero(h) && return h
  cx[k] = new
  update_cache!(m, x, k, h)
  h
end

# the change of coordinate k in the stopping rule, scaled only when the
# coordinate moved, which most coordinates of a full pass do not; for the groups
# of an AtomIterate, _groupstep! returns the largest scaled change of an entry
@inline function _visit!(m::CDModel, g, x, k::Int, scaled::Bool)
  h = abs(coordinate_step!(m, g, x, k))
  change = scaled && !iszero(h) ? h * coordinate_scale(m, x, k) : h
  isfinite(change) || throw(ArgumentError("a coordinate step or its stopping scale is not finite"))
  change
end

@inline function _visit!(m::CDModel, g, x::AtomIterate, k::Int, scaled::Bool)
  change = _groupstep!(m, g, x, k, scaled)
  isfinite(change) || throw(ArgumentError("a group step or its stopping scale is not finite"))
  change
end

####################################
#  coordinates of the iterates
####################################

# For a SymmetricSparseIterate, coordinate k is the lower-triangle entry (r, c),
# r ≥ c: its index as an entry of the p × p matrix, which penalties take, and
# the number of entries it sets, which multiplies the penalty
@inline _entry(p::Int, r::Int, c::Int) = (c - 1) * p + r
@inline _multiplicity(::Type{T}, r::Int, c::Int) where {T} = r == c ? one(T) : T(2)

# the size of the gradient over coordinate k, and the weight of the penalty on
# it, for screening and for λmax
_gradnorm(grad::AbstractArray, ::SparseIterate, k::Int) = abs(grad[k])
function _gradnorm(grad::AbstractArray, x::SymmetricSparseIterate, k::Int)
  r, c = tril_cartesian(x.p, k)
  abs(grad[_entry(x.p, r, c)])
end
_gradnorm(grad::AbstractArray, x::AtomIterate, k::Int) = norm(view(grad, x.groups[k]))

_coordweight(g, ::SparseIterate, k::Int) = _weight(g, k)
function _coordweight(g, x::SymmetricSparseIterate, k::Int)
  r, c = tril_cartesian(x.p, k)
  _weight(g, _entry(x.p, r, c))
end
_coordweight(g::Union{GroupNormL2, GroupMCP, GroupSCAD}, ::AtomIterate, k::Int) = g.w[k]

_isnonzero(x::SparseIterate, k::Int) = !iszero(x[k])
_isnonzero(x::SymmetricSparseIterate, k::Int) = !iszero(coordinates(x)[k])
_isnonzero(x::AtomIterate, k::Int) = isactive(x, k) && any(!iszero, atom(x, k))

_gradient_buffer(x::AbstractArray{T}) where {T} = similar(Array{T}, axes(x))

####################################
#  penalties
####################################

# The penalty level λ of g, g with level λ instead, and the weight of entry i
# (of group i for a group penalty): a coordinate at zero is optimal while the
# gradient over it is at most λ times its weight. Paths and screening need these.
# The level of ElasticNet(λ1, λ2, w) is λ1, with λ2 fixed; that of
# Scaled(ElasticNet(α, 1 - α, w), λ) is its scale λ, so that both terms move
# with it, as along glmnet's paths at a fixed α, and the weight of entry i is
# then α wᵢ. Likewise the level of the sparse group lasso at a fixed mixture,
# Scaled(SparseGroupNormL2(α, 1 - α, groups, w), λ), is λ (see sparsegroup.jl
# for its screening). The capped ℓ1, log and ℓq penalties of ProximalBase have none:
# their exact coordinate steps can jump away from zero at levels where zero is
# locally optimal, so the slope at zero would give neither λmax nor a safe
# screening test. The capped ℓ1 and log penalties have paths by LLA instead
# (lla.jl), whose stages are weighted lassos; their weights below, the slopes at
# zero over λ, give λmax of the first stage.
_haslevel(g) = false
_haslevel(::Union{NormL1, NormL1Nonneg, GroupNormL2, ElasticNet, MCP, SCAD, Scaled{<:ElasticNet}, GroupMCP, GroupSCAD,
                  Scaled{<:SparseGroupNormL2}}) = true
_level(g::Union{NormL1, NormL1Nonneg, GroupNormL2}) = g.λ0
_level(g::ElasticNet) = g.λ1
_level(g::Union{MCP, SCAD}) = g.λ
_level(g::Union{Scaled{<:ElasticNet}, Scaled{<:SparseGroupNormL2}}) = g.α
_level(g::Union{GroupMCP, GroupSCAD}) = g.λ0

_with_level(g::NormL1, λ) = NormL1(λ, g.w)
_with_level(g::NormL1Nonneg, λ) = NormL1Nonneg(λ, g.w)
_with_level(g::GroupNormL2, λ) = GroupNormL2(λ, g.groups, g.w)
_with_level(g::ElasticNet, λ) = ElasticNet(λ, g.λ2, g.w)
_with_level(g::MCP, λ) = MCP(λ, g.a)
_with_level(g::SCAD, λ) = SCAD(λ, g.a)
_with_level(g::GroupMCP, λ) = GroupMCP(λ, g.groups, g.w; a = g.a)
_with_level(g::GroupSCAD, λ) = GroupSCAD(λ, g.groups, g.w; a = g.a)
_with_level(g::Union{Scaled{<:ElasticNet}, Scaled{<:SparseGroupNormL2}}, λ) = Scaled(g.f, λ)
_with_level(g, λ) = throw(ArgumentError("$(typeof(g)) has no penalty level for a path; use NormL1, ElasticNet, Scaled(ElasticNet(α, 1 - α), λ), MCP, SCAD, GroupNormL2, GroupMCP, GroupSCAD or Scaled(SparseGroupNormL2(α, 1 - α, groups), λ), the separable ones possibly on a box (Constrained(g, IndBox(l, u)))."))

_weight(g::Union{NormL1, NormL1Nonneg}, i::Int) = _entryweight(g.w, i, typeof(g.λ0))
_weight(g::ElasticNet, i::Int) = _entryweight(g.w, i, typeof(g.λ1))
_entryweight(::Nothing, ::Int, ::Type{T}) where {T} = one(T)
_entryweight(w::AbstractArray, i::Int, ::Type) = @inbounds w[i]
_weight(g::Union{MCP{T}, SCAD{T}}, ::Int) where {T} = one(T)
_weight(g::Scaled{<:ElasticNet}, i::Int) = g.f.λ1 * _weight(g.f, i)
_weight(g::CappedL1, i::Int) = _entryweight(g.w, i, typeof(g.λ))
_weight(g::LogPenalty, i::Int) = _entryweight(g.w, i, typeof(g.λ)) / g.ε
_weight(g, ::Int) = throw(ArgumentError("$(typeof(g)) has no penalty level for paths and screening; use NormL1, ElasticNet, Scaled(ElasticNet(α, 1 - α), λ), MCP, SCAD, GroupNormL2, GroupMCP or GroupSCAD, possibly on a box (Constrained(g, IndBox(l, u)))."))

# A penalty with a level on a box, Constrained(g, IndBox(l, u)), has the level
# and the weights of g. Zero must be in the box (l ≤ 0 ≤ u, as glmnet requires
# of its limits), so that the path starts from it and λmax means what it means
# for g. A coordinate at zero is then optimal while the gradient over it is at
# most λ times its weight in the directions the box allows (_screengrad).
const _BoxConstrained = ProximalBase.BoxConstrained
_haslevel(c::_BoxConstrained) = _haslevel(c.f)
_level(c::_BoxConstrained) = _level(c.f)
_with_level(c::_BoxConstrained, λ) = (_check_zero_in_box(c.box); _BoxConstrained(_with_level(c.f, λ), c.box))
_weight(c::_BoxConstrained, i::Int) = _weight(c.f, i)

# The concavity of a weakly convex penalty, the largest ρ for which
# g(x) + ρx²/2 is convex: 1/a for MCP and 1/(a - 1) for SCAD, of the group norm
# for their group versions. A proximal Newton step may need a proximal term with
# it (glm.jl), and an exact coordinate step is convex when its curvature exceeds
# it (path.jl).
_concavity(g::Union{MCP{T}, GroupMCP{T}}) where {T} = inv(T(g.a))
_concavity(g::Union{SCAD{T}, GroupSCAD{T}}) where {T} = inv(T(g.a) - 1)
_concavity(c::_BoxConstrained) = _concavity(c.f)

_check_zero_in_box(box::IndBox) =
  box.zp ? nothing : throw(ArgumentError("a path, λmax and screening on Constrained(g, IndBox(l, u)) need zero in the box, l ≤ 0 ≤ u."))

# the size of the gradient over coordinate k that λ times its weight bounds when
# the coordinate is optimal at zero: |∇ₖf| (its norm over a group), and on a
# box, the part of it that points into the box from zero, (-∇ₖf)₊ when uₖ > 0
# and (∇ₖf)₊ when lₖ < 0. λmax and screening compare it with λwₖ.
_screengrad(g, grad::AbstractArray, x, k::Int) = _gradnorm(grad, x, k)
function _screengrad(c::_BoxConstrained, grad::AbstractArray, x::SparseIterate, k::Int)
  d = grad[k]
  if d < 0
    ProximalBase._entry(c.box.u, k) > 0 ? -d : zero(d)
  else
    ProximalBase._entry(c.box.l, k) < 0 ? d : zero(d)
  end
end

# The tests of screening at a level μ, for coordinate k with weight w > 0: the
# strong rule keeps it when the statistic reaches μw, and it violates the
# optimality condition of a coordinate at zero at the level λ when the statistic
# exceeds λw. The sparse group lasso has methods of its own (sparsegroup.jl).
@inline _strongkeep(g, grad::AbstractArray, x, k::Int, μ, w) = _screengrad(g, grad, x, k) >= μ * w
@inline _kktviolated(g, grad::AbstractArray, x, k::Int, λ) = _screengrad(g, grad, x, k) > λ * _coordweight(g, x, k)


# the penalty g goes with iterates like x: it is separable, with a weight or
# bound for every entry of x (the coordinate steps read them unchecked), or a
# group penalty (GroupNormL2, GroupNormLinf, ...) on an AtomIterate with its
# groups; a scaled penalty goes with the iterates of the penalty it scales
_check_iterate(g::Scaled, x) = _check_iterate(g.f, x)
function _check_iterate(g::AbstractFunction, x)
  if isseparable(g)
    ProximalBase._checkparams(g, x)
    if x isa SymmetricSparseIterate && g isa Union{NormL1, NormL1Nonneg, ElasticNet} && g.w !== nothing
      issymmetric(reshape(g.w, size(x))) ||
        throw(ArgumentError("coordinate descent on a symmetric iterate needs symmetric penalty weights"))
    end
    return nothing
  end
  if g isa ProximalBase.AbstractGroupNorm
    x isa AtomIterate || throw(ArgumentError("$(nameof(typeof(g))) needs an AtomIterate with its groups, as in AtomIterate(p, g.groups)."))
    x.groups === g.groups || x.groups == g.groups ||
      throw(ArgumentError("The groups of x must be the groups of g, as in AtomIterate(p, g.groups)."))
    return nothing
  end
  throw(ArgumentError("coordinate descent needs a separable penalty (isseparable(g)) or a group penalty (GroupNormL2, GroupNormLinf, ...), but g is a $(typeof(g))."))
end

# the factor max(1 - c / (L ‖u‖), 0) by which the proximal operator of c‖⋅‖₂
# with step 1/L shrinks a vector u, given nu = ‖u‖. With L = 0 the loss does not
# depend on the group, which then goes to zero if it is penalized and keeps its
# values otherwise
function _groupshrink(nu::T, c::T, L::T) where {T<:AbstractFloat}
  iszero(L) && return iszero(c) ? one(T) : zero(T)
  nu > c / L ? one(T) - c / (L * nu) : zero(T)
end

# the change of an entry in the stopping rule, scaled as in _visit!
_scaledchange(m, x, j::Int, h, scaled::Bool) = scaled ? abs(h) * coordinate_scale(m, x, j) : abs(h)
