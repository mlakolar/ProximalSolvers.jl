# Once-per-solve validation; no numeric solver arithmetic or conversion changes. `_allfinite` is also called on
# the image of each logistic trial (src/solvers/image_models.jl).
using ProximalBase: leastsquares_data
function _allfinite(A::Array)
  finite = true
  @inbounds @simd for i in eachindex(A)
    finite &= isfinite(A[i])
  end
  finite
end

function _scalar_parameter(v, ::Type{T}, name; positive = false) where T
  v isa Real && isfinite(v) && (positive ? v > 0 : v >= 0) ||
    throw(ArgumentError("$name must be finite and $(positive ? "positive" : "nonnegative")"))
  native = try
    T(v)
  catch
    throw(ArgumentError("$name is not representable in $T"))
  end
  isfinite(native) && (!iszero(v) ? native > 0 : iszero(native)) ||
    throw(ArgumentError("$name is not representable without overflow or underflow in $T"))
  nothing
end

# The loss scale of a Scaled loss, for data of type T. A Float32 or Float64 scale must be finite and
# positive with a conversion to T that is finite and nonzero (a value that is subnormal in T is
# accepted). A fixed-width integer or Bool scale must be positive and equal to its conversion to T, so
# that ProximalBase's oracles and the solvers' own T-valued scale use the same number. A scale of any
# other type is refused.
function _check_loss_scale(α, ::Type{T}) where T
  if α isa Union{Float32, Float64}
    _scalar_parameter(α, T, "loss scale"; positive = true)
  elseif α isa Union{Base.BitInteger, Bool}
    α > 0 || throw(ArgumentError("loss scale must be finite and positive"))
    T(α) == α || _loss_scale_error(α, T, "is not exactly representable in $T")
  else
    _loss_scale_error(α, T, "has an unsupported type")
  end
  nothing
end

# Whether the Float64 value a passes the rule of _check_loss_scale for data of type T
_float64_scale_ok(a::Float64, ::Type{T}) where T = isfinite(a) && a > 0 && (n = T(a); isfinite(n) && n > 0)

@noinline function _loss_scale_error(α, ::Type{T}, why) where T
  a = try Float64(α) catch; nothing end
  # the hint is offered when Float64(α) passes the rule of _check_loss_scale for T and, for an integer α, a == α
  # returns true (a comparison that throws or returns another value omits the hint); for an α that is not an
  # integer the hint notes that the conversion may round α
  exact = !(α isa Integer) || (try (a == α) === true catch; false end)
  ok = a isa Float64 && _float64_scale_ok(a, T) && exact
  hint = !ok ? "" :
    "; convert it explicitly with Float64(α) * LeastSquaresLoss(y, X), where Float64(α) = $a" *
    (α isa Integer ? "" : " (the conversion may round α)")
  throw(ArgumentError("loss scale $α of type $(typeof(α)) $why; only Float32 and Float64 scales and fixed-width integer scales that $T represents exactly are supported$hint"))
end

# IndNonnegative and unweighted NormL1Nonneg are accepted under :pgd and :cd, with the vector-response
# LeastSquaresLoss (raw or one supported positive Scaled, IN-02) and a feasible start checked by _check_problem on a dense Vector (a SparseIterate is refused by _check_owner_problem).
# :gradient retains the APG gate.
# The penalty check of _check_data for an x that is not a BlockIterate. `kind` is the gate's:
# :gradient (APG), :pgd (PGD) and :cd (CDSolver on a dense Vector or a SparseIterate, and the default of a call
# without `kind`) accept a NormL1 and an ElasticNet, each with or without weights. :cd also accepts
# SqrNormL2 with the Nothing center type. Both gradient kinds also accept a NormLinf, which :cd refuses
# with a message of its own (this CDSolver needs a separable penalty for
# its coordinate step), a NormL2 (the Euclidean norm of the whole vector; :cd refuses it with the general list of
# its penalties) and a GroupNormL2 that passes _check_dense_group_penalty. Under :cd a GroupNormL2 is refused with a
# pointer to the supported alternatives. The levels must pass _scalar_parameter for T (finite, nonnegative,
# representable without overflow or underflow; a level that is subnormal in T passes it). A NormL1 with
# weights also passes _check_l1_weights, which refuses a level that is subnormal in T. An ElasticNet with weights
# passes _check_elasticnet_weights: the L1 level λ1 and the weights are checked as for a NormL1 with weights, and the
# ridge level λ2 only by _scalar_parameter, so that a subnormal λ2 passes it (IN-03). A wrapper such as
# Scaled(NormLinf(λ)), Scaled(NormL2(λ)) or Scaled(ElasticNet(λ1, λ2, w)) is refused. NormL2 is supported only on
# the dense vector gradient paths. The matrix-response least-squares, BlockIterate, logistic and
# square-root routes refuse NormL2.
function _check_penalty(g, x, ::Type{T}, kind::Symbol = :cd) where T
  if g isa NormL1
    g.w === nothing ? _scalar_parameter(g.λ0, T, "penalty lambda") : _check_l1_weights(g, x, T)
  elseif g isa ElasticNet && g.w === nothing
    _scalar_parameter(g.λ1, T, "penalty lambda1")
    _scalar_parameter(g.λ2, T, "penalty lambda2")
  elseif g isa ElasticNet
    _check_elasticnet_weights(g, x, T)
  elseif g isa SqrNormL2 && kind === :cd
    # The scalar prox dispatches on the declared center type.
    g isa SqrNormL2{<:Real, Nothing} ||
      throw(ArgumentError("CDSolver requires an uncentered SqrNormL2 penalty constructed as SqrNormL2(lambda)"))
    _scalar_parameter(g.λ, T, "penalty lambda")
  elseif g isa NormLinf && kind in (:gradient, :pgd)
    _scalar_parameter(g.λ, T, "penalty lambda")
  elseif g isa NormLinf
    throw(ArgumentError("CDSolver does not support NormLinf (its coordinate step needs a separable penalty); use ProximalGradientDescent or AccProxGradDescent"))
  elseif g isa NormL2 && kind in (:gradient, :pgd)
    _scalar_parameter(g.λ, T, "penalty lambda")
  elseif g isa GroupNormL2 && kind in (:gradient, :pgd)
    _check_dense_group_penalty(g, x, T)
  elseif g isa GroupNormL2
    throw(ArgumentError("CDSolver does not support GroupNormL2 (the group lasso) on a dense Vector or a SparseIterate; use CDSolver on a BlockIterate, or ProximalGradientDescent or AccProxGradDescent on a dense Vector"))
  elseif g isa IndBox && kind in (:gradient, :pgd)
    _check_box(g, x, T)
  elseif g isa IndBallL2 && kind in (:gradient, :pgd)
    length(x) == 4 || throw(ArgumentError("IndBallL2 requires four coefficients"))
    g.r isa T || throw(ArgumentError("IndBallL2 requires a radius of type $T"))
    _scalar_parameter(g.r, T, "ball radius")
  elseif g isa NormL1Nonneg
    kind in (:pgd, :cd) ||
      throw(ArgumentError("NormL1Nonneg is supported only by ProximalGradientDescent and CDSolver on a dense Vector"))
    g.w === nothing || throw(ArgumentError("weighted NormL1Nonneg is not supported"))
    _scalar_parameter(g.λ0, T, "penalty lambda")
  elseif g isa IndNonnegative
    kind in (:pgd, :cd) ||
      throw(ArgumentError("IndNonnegative is supported only by ProximalGradientDescent and CDSolver on a dense Vector"))
  elseif kind === :pgd
    throw(ArgumentError("only NormL1, ElasticNet (with optional weights), NormLinf, NormL2, GroupNormL2, unweighted NormL1Nonneg, IndNonnegative, IndBox or IndBallL2 is supported"))
  elseif kind === :gradient
    throw(ArgumentError("only NormL1, ElasticNet (with optional weights), NormLinf, NormL2, GroupNormL2, IndBox or IndBallL2 is supported"))
  else
    throw(ArgumentError("CDSolver supports NormL1, ElasticNet (with optional weights), and uncentered SqrNormL2, and on a dense Vector also unweighted NormL1Nonneg and IndNonnegative"))
  end
  nothing
end

# The projection stores bounds in T, while the value compares to the original bounds.
# Exact scalar conversion makes these two operations agree at a face of the box.
function _check_box_bound(bound::Union{Float32, Float64, Base.BitInteger, Bool}, x, ::Type{T}) where T
  T(bound) == bound || throw(ArgumentError("box scalar bounds must be exactly representable in $T"))
  nothing
end

function _check_box_bound(bound::Vector{T}, x, ::Type{T}) where T
  length(bound) == length(x) ||
    throw(DimensionMismatch("box bounds must have one entry per coefficient"))
  Base.mightalias(x, bound) && throw(ArgumentError("mutable x must not alias the box bounds"))
  nothing
end

_check_box_bound(bound, x, ::Type{T}) where T =
  throw(ArgumentError("box bounds must be Float32, Float64, a fixed-width integer, Bool, or Vector{$T}"))

function _check_box(g, x, ::Type{T}) where T
  _check_box_bound(g.l, x, T)
  _check_box_bound(g.u, x, T)
  # Stored array bounds can be mutated after the constructor has validated them.
  for i in eachindex(x)
    lo = g.l isa Real ? g.l : g.l[i]
    hi = g.u isa Real ? g.u : g.u[i]
    lo <= hi && lo < Inf && hi > -Inf ||
      throw(ArgumentError("box bounds must define nonempty intervals and contain no NaNs"))
  end
  nothing
end

# The weights of a NormL1 for data of type T: the level passes _weighted_level, and the weights _check_weights.
function _check_l1_weights(g, x, ::Type{T}) where T
  _check_weights(_weighted_level(g.λ0, T), g.w, x, T)
end

# The weights of an ElasticNet for data of type T, checked in this order: the L1 level λ1 (_weighted_level, named
# "penalty lambda1"), the ridge level λ2 (_scalar_parameter only: a ridge level that is subnormal in T is accepted,
# as for an unweighted ElasticNet), then the weights and the coefficients λ1 wⱼ (_check_weights). The weights
# scale the L1 term only; the ridge term is common to all entries.
function _check_elasticnet_weights(g, x, ::Type{T}) where T
  λ = _weighted_level(g.λ1, T, "penalty lambda1")
  _scalar_parameter(g.λ2, T, "penalty lambda2")
  _check_weights(λ, g.w, x, T)
end

# The weights w of a penalty with the L1 level λ = T(λ0), for data of type T. They must be a Vector{T} with one entry
# per entry of x, finite and nonnegative, and x must not alias them (x is the caller's array or owner, as for X and
# y). The coefficients λ wⱼ pass _check_coefficients. The weights are read at every call, so a change since their
# construction is checked.
function _check_weights(λ::T, w, x, ::Type{T}) where T
  w isa Vector{T} ||
    throw(ArgumentError("penalty weights must be a Vector{$T} (the element type of the data); convert an array with collect($T, vec(w)), which takes it in linear order"))
  length(w) == length(x) ||
    throw(DimensionMismatch("the penalty has $(length(w)) weights but x has $(length(x)) entries"))
  Base.mightalias(x, w) && throw(ArgumentError("mutable x must not alias the penalty weights"))
  _check_coefficients(λ, w, :entry)
  nothing
end

# The level λ = T(λ0) of a penalty with weights: it passes _scalar_parameter and must be zero or a normal
# number of T (not subnormal). Returns λ. `name` names the level in the messages ("penalty lambda1" for an
# ElasticNet). The conversion is `_converted_level`, the one that builds the working penalty, so the level that is
# checked is the level that is used.
function _weighted_level(λ0, ::Type{T}, name::String = "penalty lambda") where T
  _scalar_parameter(λ0, T, name)
  λ = _converted_level(T, λ0)
  issubnormal(λ) && _l1_level_error(λ0, λ, T, name)
  λ
end

# The weights of NormL1 and ElasticNet (one per entry, at the L1 level) and GroupNormL2 (one per group)
# must be finite and nonnegative. Check the coefficient c = λ w rounded in T. It must be finite and,
# for positive factors, normal. An exact product slightly below floatmin(T) can round up and pass.
# A zero factor gives coefficient zero here. ElasticNet's separate ridge term still applies.
function _check_coefficients(λ::T, w::Vector{T}, unit::Symbol) where T
  @inbounds for j in eachindex(w)
    wj = w[j]
    c = λ * wj
    isfinite(wj) && wj >= 0 && isfinite(c) && (iszero(c) ? (iszero(λ) | iszero(wj)) : floatmin(T) <= c) ||
      _l1_weight_error(λ, wj, j, T, unit)
  end
  nothing
end

@noinline _l1_level_error(λ0, λ::T, ::Type{T}, name::String = "penalty lambda") where T =
  throw(ArgumentError("$name $λ0 is subnormal in $T (it converts to $λ); with weights the level must be zero " *
                      "or at least floatmin($T); rescale the level or the weights"))

@noinline function _l1_weight_error(λ::T, wj::T, j, ::Type{T}, unit::Symbol = :entry) where T
  isfinite(wj) && wj >= 0 ||
    throw(ArgumentError(unit === :entry ? "penalty weight $j must be finite and nonnegative" :
                                          "the penalty weight of group $j must be finite and nonnegative"))
  c = λ * wj
  why = isinf(c) ? "overflows" : iszero(c) ? "underflows to zero" : "is subnormal (below floatmin($T))"
  throw(ArgumentError("the penalty coefficient of $unit $j, lambda * weight in $T, $why; rescale the level or the weights"))
end

# A GroupNormL2 under the :gradient gate, for a dense x of type T, checked in this order: its parameters have the
# element type T; it has one weight per group; its groups, read at this call, partition 1:p (p = length(x)) and match
# the layout stored in the penalty at construction; the level and the coefficients λ wₖ pass _weighted_level and
# _check_coefficients; x does not alias the weights. The groups are checked with one mask of p entries: an empty group,
# an index below 1, an index that appears twice and an index in no group are ArgumentErrors, and an index above p is
# a DimensionMismatch. ProximalBase's value, prox and full-point residual loops iterate g.groups, while its extent and
# free-coordinate logic use the arrays stored at construction (group_of, free). A change of g.groups after construction
# is refused where it disagrees with them: each member i of group k must have group_of[i] == k, group_of must have p
# entries and free must be empty (free is a separate array, so it is checked itself).
function _check_dense_group_penalty(g::GroupNormL2, x, ::Type{T}) where T
  g isa GroupNormL2{T} ||
    throw(ArgumentError("the parameters of GroupNormL2 must have the element type $T of the data; convert the penalty " *
                        "with GroupNormL2($T(λ0), groups, $T.(w)) (CDSolver on a BlockIterate accepts Float32 or Float64 parameters)"))
  length(g.w) == length(g.groups) ||
    throw(DimensionMismatch("GroupNormL2 has $(length(g.w)) weights but $(length(g.groups)) groups"))
  p = length(x)
  seen = falses(p)
  group_of = g.group_of
  for (k, G) in enumerate(g.groups)
    isempty(G) && _partition_error(p, "group $k is empty")
    for i in G
      i > p && throw(DimensionMismatch("group $k of GroupNormL2 holds the index $i, but x has $p entries"))
      (i >= 1 && !seen[i]) || _partition_error(p, i < 1 ? "group $k holds the index $i" : "the index $i appears a second time (in group $k)")
      (i <= length(group_of) && group_of[i] == k) || _layout_error()
      seen[i] = true
    end
  end
  j = findfirst(!, seen)
  j === nothing || _partition_error(p, "the index $j is in no group")
  length(group_of) == p && isempty(g.free) || _layout_error()
  _check_coefficients(_weighted_level(g.λ0, T), g.w, :group)
  Base.mightalias(x, g.w) && throw(ArgumentError("mutable x must not alias the penalty weights"))
  nothing
end

@noinline _partition_error(p, why) =
  throw(ArgumentError("the groups of GroupNormL2 must partition 1:p (p = $p, the length of x): $why"))
@noinline _layout_error() =
  throw(ArgumentError("the groups of GroupNormL2 differ from the layout it was constructed with (they were changed after construction); construct the penalty again"))

# The declared GroupNormL2 parameter type, which may differ from the runtime type of the level.
_group_parameter_type(::GroupNormL2{P}) where P = P

# The type, level and weights of a group penalty for data of type T: a GroupNormL2 with Float32 or Float64
# parameters, whose level and weights convert to T without overflow, or underflow to 0 from a nonzero value.
# `holder` names the coefficient storage in the message.
function _check_group_penalty(g, ::Type{T}, holder::String) where T
  g isa GroupNormL2{<:Union{Float32, Float64}} ||
    throw(ArgumentError("$holder needs a GroupNormL2 penalty with Float32 or Float64 parameters"))
  _scalar_parameter(g.λ0, T, "penalty lambda")
  for k in eachindex(g.w)
    _weight_ok(g.w[k], T) || _weight_error(g.w[k], k, T)
  end
  nothing
end

# The penalty of group coordinate descent on a BlockIterate: a GroupNormL2 as above, whose groups are those
# of x, in the same order and with the same ordered members.
function _check_penalty(g, x::BlockIterate, ::Type{T}) where T
  g isa GroupNormL2 ||
    throw(ArgumentError("a BlockIterate needs a GroupNormL2 penalty (got $(nameof(typeof(g))))"))
  g isa GroupNormL2{<:Union{Float32, Float64}} ||
    throw(ArgumentError("a BlockIterate needs a GroupNormL2 penalty with Float32 or Float64 parameters (got $(_group_parameter_type(g)) parameters)"))
  _check_group_penalty(g, T, "a BlockIterate")
  ncoordinates(x) == length(g.groups) ||
    throw(DimensionMismatch("x has $(ncoordinates(x)) groups but the penalty has $(length(g.groups))"))
  for k in 1:ncoordinates(x)
    blockindices(x, k) == g.groups[k] ||
      throw(DimensionMismatch("the groups of x and of the penalty differ at group $k"))
  end
  nothing
end
# The gates pass a `kind` (:gradient, :cd or :block) to _check_penalty; a BlockIterate ignores it. This method is
# more specific in x than the generic one, so a BlockIterate reaches the checks above for each `kind`.
_check_penalty(g, x::BlockIterate, ::Type{T}, kind::Symbol) where T = _check_penalty(g, x, T)

# The rule of _scalar_parameter for a nonnegative value
function _weight_ok(w, ::Type{T}) where T
  native = T(w)
  isfinite(w) && w >= 0 && isfinite(native) && (iszero(w) ? iszero(native) : native > 0)
end

@noinline function _weight_error(w, k, ::Type{T}) where T
  _scalar_parameter(w, T, "group weight $k")
  throw(ArgumentError("group weight $k is not valid in $T"))
end

# Loss, data, shape, penalty and alias checks shared by the dense gate, the CD owner gate and the
# block gate; `x` is the caller's original array or owner, of length `length(x)`. `kind` (:gradient,
# :cd, :pgd or :block) is passed to _check_penalty.
function _check_data(x, f, g, ::Type{T}, kind::Symbol) where T
  base = if f isa LeastSquaresLoss
    f
  elseif f isa Scaled && f.f isa LeastSquaresLoss
    _check_loss_scale(leastsquares_data(f).α, T)
    f.f
  else
    # the CD owner gate reaches this with a logistic loss (the block gate refuses it earlier)
    _is_logistic_loss(f) && _logistic_method_error(kind)
    throw(ArgumentError("only LeastSquaresLoss or one positive Scaled(LeastSquaresLoss) is supported"))
  end
  base.X isa Matrix{T} && base.Y isa Vector{T} ||
    throw(ArgumentError("X must be Matrix{$T} and y Vector{$T}; sparse designs and mixed array types are deferred. Matrix responses need a compatible matrix coefficient layout and penalty"))
  n, p = size(base.X)
  n > 0 && p > 0 || throw(DimensionMismatch("X must have positive row and column counts"))
  length(base.Y) == n && length(x) == p || throw(DimensionMismatch("x/y dimensions do not match X"))
  _check_penalty(g, x, T, kind)
  (Base.mightalias(x, base.X) || Base.mightalias(x, base.Y)) &&
    throw(ArgumentError("mutable x must not alias borrowed X or y"))
  base
end

# The square-root least-squares loss, unwrapped or in one Scaled wrapper (which _check_sqrt_data refuses).
_is_sqrt_loss(f) = f isa SqrtLeastSquaresLoss || (f isa Scaled && f.f isa SqrtLeastSquaresLoss)

# The checks of _check_data for the square-root loss, used in its place by the gates below; `kind` is
# :cd (CDSolver with a dense Vector or a one-dimensional SparseIterate), :block (a BlockIterate) or
# :gradient (PGD and APG, whose calls of the dense gate take its default `kind`). Each refusal is an ArgumentError
# (a DimensionMismatch for the shapes) with its own message, in this order: a BlockIterate; PGD and APG;
# a Scaled wrapper; the data, read through `leastsquares_data` and checked as for least squares (types,
# shapes), with the element type of the loss equal to T; the penalty (`_check_sqrt_penalty`); an x that
# may alias X or y. It returns the data
# `(; Y, X, α)`, whose `Y` and `X` the gates check for finite values.
function _check_sqrt_data(x, f, g, ::Type{T}, kind::Symbol) where T
  kind === :block &&
    throw(ArgumentError("SqrtLeastSquaresLoss does not support a BlockIterate (there is no group square-root lasso); use a dense Vector or a one-dimensional SparseIterate"))
  kind in (:gradient, :pgd) &&
    throw(ArgumentError("ProximalBase provides no gradient for SqrtLeastSquaresLoss (for X ≠ 0 it is not differentiable where y = X*x), so ProximalGradientDescent and AccProxGradDescent do not support it; use CDSolver"))
  f isa Scaled &&
    throw(ArgumentError("Scaled(SqrtLeastSquaresLoss, alpha) is not supported; for a positive finite alpha, use the unscaled SqrtLeastSquaresLoss with the penalty level lambda/alpha, which has the same minimizers (the scaled objective is alpha times the unscaled one)"))
  d = leastsquares_data(f)
  d.X isa Matrix{T} && d.Y isa Vector{T} && f isa SqrtLeastSquaresLoss{T} ||
    throw(ArgumentError("X must be Matrix{$T} and y Vector{$T}; sparse designs, matrix responses and mixed array types are deferred for SqrtLeastSquaresLoss"))
  n, p = size(d.X)
  n > 0 && p > 0 || throw(DimensionMismatch("X must have positive row and column counts"))
  length(d.Y) == n && length(x) == p || throw(DimensionMismatch("x/y dimensions do not match X"))
  _check_sqrt_penalty(g, T)
  (Base.mightalias(x, d.X) || Base.mightalias(x, d.Y)) &&
    throw(ArgumentError("mutable x must not alias borrowed X or y"))
  d
end

# The penalty of the square-root loss: an unweighted NormL1 whose level is positive, finite and
# representable in T without overflow or underflow. Refused in this order: an ElasticNet (which CDSolver
# accepts with least squares, not with this loss); a penalty that
# is not a NormL1; a weighted NormL1 (all-ones weights included); a zero level (-0.0 included), with a
# pointer to LeastSquaresLoss; then the checks of `_scalar_parameter` with `positive = true`.
function _check_sqrt_penalty(g, ::Type{T}) where T
  g isa ElasticNet &&
    throw(ArgumentError("SqrtLeastSquaresLoss with an ElasticNet penalty is not supported; use an unweighted NormL1"))
  g isa NormL1 || throw(ArgumentError("only unweighted NormL1 is supported with SqrtLeastSquaresLoss"))
  g.w === nothing ||
    throw(ArgumentError("a weighted NormL1 with SqrtLeastSquaresLoss is deferred (weighted square-root lasso); use an unweighted NormL1"))
  iszero(g.λ0) &&
    throw(ArgumentError("SqrtLeastSquaresLoss needs a positive penalty level; at lambda = 0 use LeastSquaresLoss, which has the same minimizers"))
  _scalar_parameter(g.λ0, T, "penalty lambda"; positive = true)
  nothing
end

# A LogisticLoss, unwrapped or in one Scaled wrapper (which _check_logistic_problem refuses).
_is_logistic_loss(f) = f isa LogisticLoss || (f isa Scaled && f.f isa LogisticLoss)

# The refusal of a logistic loss by CDSolver, reached from the dense gate (_check_logistic_problem, for a `kind` that is
# none of :pgd, :gradient, :newton and :admm), from the CD owner gate (_check_data, with `kind` :cd) and from the block
# gate (:block). The gate of PGD, APG, ProxNewton and LogisticADMM does not call it. An owner call that
# _check_owner_problem refuses earlier (IndNonnegative or NormL1Nonneg on a SparseIterate) does not reach it.
@noinline _logistic_method_error(::Symbol) =
  throw(ArgumentError("LogisticLoss is supported only by ProximalGradientDescent, AccProxGradDescent, ProxNewton and " *
                      "LogisticADMM, on a dense Vector{Float64} with a NormL1 penalty; CDSolver does not support it"))

# The solver named in the refusal of a nonbinary response: the gate runs for PGD (`kind` :pgd), APG (:gradient),
# ProxNewton (:newton) and LogisticADMM (:admm).
_logistic_solver_name(kind::Symbol) =
  kind === :newton ? "ProxNewton" : kind === :gradient ? "AccProxGradDescent" :
  kind === :admm ? "LogisticADMM" : "ProximalGradientDescent"

# The gate of a logistic loss (IN-09, PN-01, APG-08, LA-01), in place of the checks below, at each call of PGD, APG,
# ProxNewton and LogisticADMM that reaches it (after the keyword check of solve!) and before any write to x; the dense CD
# route calls it only for the refusal of its own kind. Each refusal is an ArgumentError (a DimensionMismatch for the
# shapes), in this order: a solver other than PGD, APG, ProxNewton and LogisticADMM (`kind` is none of :pgd, :gradient,
# :newton and :admm); a Scaled wrapper; a loss, X, y or x that is not LogisticLoss{Float64}, Matrix{Float64},
# Vector{Float64} and Vector{Float64}; observation weights or an offset; X without rows or columns, y without one entry
# per row of X, x without one entry per column; a penalty that is not a NormL1, then the NormL1 rules of _check_penalty
# (with weights, _check_l1_weights, which also refuses an x that may alias the weights); an x that may alias X, y or the
# scratch f.tmp of the loss; a nonfinite entry of x or X; an entry of y other than 0 and 1 (a NaN included), read at
# this call, so a change of y after the construction of the loss is checked.
function _check_logistic_problem(x, f, g, kind::Symbol)
  kind === :pgd || kind === :gradient || kind === :newton || kind === :admm || _logistic_method_error(kind)
  f isa Scaled &&
    throw(ArgumentError("Scaled(LogisticLoss) is not supported (ProximalBase provides no predictor oracles for it); " *
                        "for a positive finite scale a, use the raw LogisticLoss(y, X) with the penalty level lambda/a, " *
                        "which has the same minimizers in exact arithmetic when the penalty with that level passes the " *
                        "level and weight rules of solve! (with weights, for the level, the weights and their products): " *
                        "for the mean loss " *
                        "(1/n) * LogisticLoss(y, X) with NormL1(lambda), use LogisticLoss(y, X) with NormL1(n * lambda)"))
  f isa LogisticLoss{Float64} && f.X isa Matrix{Float64} && f.y isa Vector{Float64} ||
    throw(ArgumentError("LogisticLoss needs X::Matrix{Float64} and y::Vector{Float64}; Float32 data, sparse designs " *
                        "and other array types are deferred"))
  x isa Vector{Float64} ||
    throw(ArgumentError("LogisticLoss needs x to be a dense Vector{Float64}"))
  f.weights === nothing && f.offset === nothing ||
    throw(ArgumentError("LogisticLoss with observation weights or an offset is not supported; construct the loss " *
                        "without them (penalty weights are given to NormL1(lambda, w))"))
  n, p = size(f.X)
  n > 0 && p > 0 || throw(DimensionMismatch("X must have positive row and column counts"))
  length(f.y) == n && length(x) == p || throw(DimensionMismatch("x/y dimensions do not match X"))
  g isa NormL1 ||
    throw(ArgumentError("only NormL1, with or without weights, is supported with LogisticLoss"))
  _check_penalty(g, x, Float64, kind)
  (Base.mightalias(x, f.X) || Base.mightalias(x, f.y) || Base.mightalias(x, f.tmp)) &&
    throw(ArgumentError("mutable x must not alias borrowed X or y or the scratch of the loss"))
  _allfinite(x) && _allfinite(f.X) || throw(ArgumentError("x and X must contain only finite values"))
  y = f.y
  @inbounds for i in eachindex(y)
    yi = y[i]
    iszero(yi) || isone(yi) ||
      throw(ArgumentError("LogisticLoss with $(_logistic_solver_name(kind)) needs a binary response: entry $i of y is $yi, not 0 or 1"))
  end
  nothing
end

# The gate of ProxNewton (PN-01): the raw logistic loss only, then the gate of _check_logistic_problem with
# `kind = :newton`. Any other loss is refused before the coefficients are read, with a pointer to the solvers that take it.
function _check_newton_problem(x, f, g)
  _is_logistic_loss(f) ||
    throw(ArgumentError("ProxNewton supports only the raw LogisticLoss(y, X) with NormL1 on a dense Vector{Float64}; " *
                        "use CDSolver, ProximalGradientDescent or AccProxGradDescent for least squares"))
  _check_logistic_problem(x, f, g, :newton)
end

# The gate of LogisticADMM (LA-01): the raw logistic loss only, then the gate of _check_logistic_problem with
# `kind = :admm`. Any other loss is refused before the coefficients are read, with a pointer to the solvers that take it.
function _check_admm_logistic_problem(x, f, g)
  _is_logistic_loss(f) ||
    throw(ArgumentError("LogisticADMM supports only the raw LogisticLoss(y, X) with NormL1 on a dense Vector{Float64}; " *
                        "use CDSolver, ProximalGradientDescent, AccProxGradDescent or ADMMSolver for least squares"))
  _check_logistic_problem(x, f, g, :admm)
end

# The dense gate: :cd for CDSolver, :pgd for PGD and :gradient (the default) for APG.
# Both gradient kinds refuse square-root loss and accept NormLinf, NormL2 and GroupNormL2;
# :pgd and :cd also accept IndNonnegative and unweighted NormL1Nonneg, with the vector-response least-squares
# loss and a feasible start (checked here, before any write, for each of these kinds; a negative entry
# is refused rather than projected).
# A logistic loss goes to _check_logistic_problem, whatever the kind.
function _check_problem(x, f, g, kind::Symbol = :gradient)
  _is_logistic_loss(f) && return _check_logistic_problem(x, f, g, kind)
  x isa Vector && eltype(x) in (Float32, Float64) ||
    throw(ArgumentError("x must be a dense Vector{Float32} or Vector{Float64}"))
  base = _is_sqrt_loss(f) ? _check_sqrt_data(x, f, g, eltype(x), kind) : _check_data(x, f, g, eltype(x), kind)
  _allfinite(x) && _allfinite(base.Y) && _allfinite(base.X) ||
    throw(ArgumentError("x, X and y must contain only finite values"))
  if g isa Union{NormL1Nonneg, IndNonnegative}
    all(>=(zero(eltype(x))), x) ||
      throw(ArgumentError("$(nameof(typeof(g))) requires a feasible starting point: x must be nonnegative"))
  elseif g isa Union{IndBox, IndBallL2}
    iszero(g(x)) || throw(ArgumentError("$(nameof(typeof(g))) requires a feasible starting point"))
  end
  nothing
end

_check_gradient_problem(x, f, g, kind) = _check_problem(x, f, g, kind)

function _check_gradient_problem(B::Matrix{T}, f, g, kind) where T
  _is_logistic_loss(f) && return _check_logistic_problem(B, f, g, kind)
  _is_matrix_response(f) ||
    throw(ArgumentError("a matrix coefficient needs a LeastSquaresLoss, or one positive Scaled of it, with a matrix response Y"))
  base = f isa Scaled ? f.f : f
  T in (Float32, Float64) && base.X isa Matrix{T} && base.Y isa Matrix{T} ||
    throw(ArgumentError("matrix-response PGD and APG need dense Matrix inputs B, X and Y of the same Float32 or Float64 type"))
  f isa Scaled && _check_loss_scale(leastsquares_data(f).α, T)
  n, p = size(base.X)
  K = size(base.Y, 2)
  n > 0 && p > 0 && K > 0 || throw(DimensionMismatch("X and Y must have positive row and column counts"))
  size(base.Y, 1) == n || throw(DimensionMismatch("X has $n rows but Y has $(size(base.Y, 1))"))
  size(B) == (p, K) ||
    throw(DimensionMismatch("B has size $(size(B)), expected ($p, $K) from X and Y"))
  g isa NormL1 && g.w === nothing ||
    throw(ArgumentError("matrix-response PGD and APG require an unweighted NormL1 penalty; their other regression penalties require a dense Vector"))
  _scalar_parameter(g.λ0, T, "penalty lambda")
  (Base.mightalias(B, base.X) || Base.mightalias(B, base.Y) || Base.mightalias(B, base.tmp)) &&
    throw(ArgumentError("mutable B must not alias borrowed X or Y or the scratch of the loss"))
  _allfinite(B) && _allfinite(base.X) && _allfinite(base.Y) ||
    throw(ArgumentError("B, X and Y must contain only finite values"))
  nothing
end

# Coordinate descent also accepts a one-dimensional SparseIterate. Only its
# public active values are inspected; the aliasing check uses the owner itself,
# so an empty owner whose backing storage is shared with X or y is refused too.
_is_cd_owner(x) = x isa SparseIterate{<:Any, 1} && eltype(x) in (Float32, Float64)
function _check_owner_problem(x, f, g)
  _is_cd_owner(x) ||
    throw(ArgumentError("x must be a dense Vector or a one-dimensional SparseIterate of Float32 or Float64"))
  # The nonnegative penalties are supported for a dense Vector only; this refusal is before any copy of x or
  # draw from the RNG.
  g isa Union{NormL1Nonneg, IndNonnegative} &&
    throw(ArgumentError("$(nameof(typeof(g))) is supported by CDSolver on a dense Vector only; a SparseIterate is not supported for it"))
  base = _is_sqrt_loss(f) ? _check_sqrt_data(x, f, g, eltype(x), :cd) : _check_data(x, f, g, eltype(x), :cd)
  all(isfinite, activevalues(x)) && _allfinite(base.Y) && _allfinite(base.X) ||
    throw(ArgumentError("x, X and y must contain only finite values"))
  nothing
end

# Group-lasso block coordinate descent on a BlockIterate. Runs before any copy of x or draw from the
# RNG; the entries of inactive groups are zero.
function _check_block_problem(x, f, g, method)
  x isa BlockIterate{<:Union{Float32, Float64}} ||
    throw(ArgumentError("block coordinate descent needs a BlockIterate of Float32 or Float64"))
  _is_matrix_response(f) && return _check_multiresponse(x, f, g, method)
  # a logistic loss is refused with its own message before the momentum check
  _is_logistic_loss(f) && _logistic_method_error(:block)
  method.momentum === true &&
    throw(ArgumentError("block coordinate descent does not support momentum; use momentum = false or nothing"))
  base = _is_sqrt_loss(f) ? _check_sqrt_data(x, f, g, eltype(x), :block) : _check_data(x, f, g, eltype(x), :block)
  all(isfinite, x) && _allfinite(base.Y) && _allfinite(base.X) ||
    throw(ArgumentError("x, X and y must contain only finite values"))
  nothing
end

# Matrix-response least squares with CDSolver: B is a Matrix{T} (p × K) or a BlockIterate over vec(B), the loss
# is a LeastSquaresLoss or one positive Scaled of it with X::Matrix{T} (n × p) and Y::Matrix{T} (n × K), and the
# penalty is a GroupNormL2 whose group j is row j of B, the entries j:p:p*K of vec(B).
_is_matrix_response(f) = (f isa Scaled ? f.f : f) isa LeastSquaresLoss{<:Any, <:AbstractMatrix}

# The gate for a Matrix coefficient; its checks are those of `_check_multiresponse`.
function _check_matrix_problem(x, f, g, method)
  x isa Matrix{<:Union{Float32, Float64}} ||
    throw(ArgumentError("a matrix coefficient must be a Matrix{Float32} or Matrix{Float64}"))
  _check_multiresponse(x, f, g, method)
end

# The checks of the two matrix-response routes (x a Matrix{T} or a BlockIterate{T}), before any copy of x or
# draw from the RNG, each refusal an ArgumentError unless noted, in this order: the loss; the types of X and Y;
# the shapes (DimensionMismatch: positive sizes, the rows of X and Y, the size of x); the penalty type, level
# and weights, and for a BlockIterate its groups against the penalty's (DimensionMismatch); the row layout of
# the groups (DimensionMismatch); momentum; aliasing of x with X, Y, the scratch of the loss or the penalty
# weights; finite entries of x, X and Y.
function _check_multiresponse(x, f, g, method)
  T = eltype(x)
  _is_matrix_response(f) ||
    throw(ArgumentError("a matrix coefficient needs a LeastSquaresLoss, or one positive Scaled of it, with a matrix response Y"))
  base = f isa Scaled ? f.f : f
  f isa Scaled && _check_loss_scale(leastsquares_data(f).α, T)
  base.X isa Matrix{T} && base.Y isa Matrix{T} ||
    throw(ArgumentError("X and Y must be Matrix{$T} for a matrix coefficient of type $T; sparse designs and mixed array types are deferred"))
  n, p = size(base.X)
  K = size(base.Y, 2)
  n > 0 && p > 0 && K > 0 || throw(DimensionMismatch("X and Y must have positive row and column counts"))
  size(base.Y, 1) == n || throw(DimensionMismatch("X has $n rows but Y has $(size(base.Y, 1))"))
  if x isa Matrix
    size(x) == (p, K) ||
      throw(DimensionMismatch("B is $(size(x, 1)) × $(size(x, 2)) but X has $p columns and Y has $K columns"))
    _check_group_penalty(g, T, "a Matrix coefficient")
  else
    length(x) == p*K ||
      throw(DimensionMismatch("x has $(length(x)) entries but X has $p columns and Y has $K columns"))
    _check_penalty(g, x, T)
  end
  _check_row_groups(g, p, K)
  method.momentum === true &&
    throw(ArgumentError("matrix-response coordinate descent does not support momentum; use momentum = false or nothing"))
  # `loss_value` evaluates the loss, which writes its scratch `tmp` (n × K), and the final copy writes x: x must
  # not share memory with X, Y, that scratch or the penalty weights.
  (Base.mightalias(x, base.X) || Base.mightalias(x, base.Y) || Base.mightalias(x, base.tmp)) &&
    throw(ArgumentError("mutable x must not alias borrowed X or Y or the scratch of the loss"))
  Base.mightalias(x, g.w) && throw(ArgumentError("mutable x must not alias the penalty weights"))
  (x isa Array ? _allfinite(x) : all(isfinite, x)) && _allfinite(base.Y) && _allfinite(base.X) ||
    throw(ArgumentError("x, X and Y must contain only finite values"))
  nothing
end

# The groups of the penalty are the p rows of B, in order: g.groups[j] == j:p:p*K.
function _check_row_groups(g, p::Int, K::Int)
  length(g.groups) == p ||
    throw(DimensionMismatch("the penalty has $(length(g.groups)) groups but B has $p rows; the groups must be the rows of B, [collect(j:$p:$(p*K)) for j in 1:$p]"))
  for j in 1:p
    g.groups[j] == j:p:p*K ||
      throw(DimensionMismatch("group $j of the penalty is not row $j of B (the entries $j:$p:$(p*K) of vec(B))"))
  end
  nothing
end

_check_keywords(kwargs) = isempty(kwargs) ||
  throw(ArgumentError("unsupported solve! keywords: $(join(keys(kwargs), ", "))"))
_check_start(f_x) = isfinite(f_x) || throw(ArgumentError("start from a point where f is finite"))

# ---- the gate of the IndBallL1 route of PGD and APG (IN-12) ----------------------------------------------------------
#
# Whether solve! takes the IndBallL1 route: for every IndBallL1. After the keyword check of solve!, a `feasibility`
# other than `nothing` with another penalty is refused.
_numerical_route(::IndBallL1, feasibility) = true
_numerical_route(g, feasibility) = feasibility === nothing ? false :
  throw(ArgumentError("feasibility applies only to IndBallL1 with ProximalGradientDescent or AccProxGradDescent; " *
                      "omit it for $(nameof(typeof(g)))"))

# The tolerances of a NumericalFeasibility for coefficients of type T, as Float64: a `nothing` takes the default of T. A
# value must be a Real that is finite and, with its Float64 conversion, nonnegative for the coefficient tolerances and
# positive for the objective and mapping tolerances; -0.0 is stored as 0.0.
function _feasibility_tolerances(a::NumericalFeasibility, ::Type{T}) where T
  coefficient, objective, mapping = T === Float32 ? (1e-5, 1e-5, 1e-4) : (1e-10, 1e-9, 1e-8)
  (; coefficient_rtol = _feasibility_tolerance(a.coefficient_rtol, coefficient, "coefficient_rtol", false),
     coefficient_atol = _feasibility_tolerance(a.coefficient_atol, 0.0, "coefficient_atol", false),
     objective_rtol = _feasibility_tolerance(a.objective_rtol, objective, "objective_rtol", true),
     mapping_rtol = _feasibility_tolerance(a.mapping_rtol, mapping, "mapping_rtol", true))
end

function _feasibility_tolerance(v, default::Float64, name::String, positive::Bool)
  v === nothing && return default
  rule = positive ? "finite and positive" : "finite and nonnegative"
  v isa Real || throw(ArgumentError("NumericalFeasibility: $name must be a real number or nothing (got $(typeof(v)))"))
  w = try
    Float64(v)
  catch
    throw(ArgumentError("NumericalFeasibility: $name = $v does not convert to Float64"))
  end
  isfinite(v) && isfinite(w) && (positive ? v > 0 && w > 0 : v >= 0 && w >= 0) ||
    throw(ArgumentError("NumericalFeasibility: $name must be $rule, as given and in Float64 (got $v)"))
  iszero(w) ? 0.0 : w
end

# A finite number of at least floatmin of its type (zero, subnormal and nonfinite numbers fail)
_normal_positive(v::AbstractFloat) = isfinite(v) && v >= floatmin(v)

# The checks of the IndBallL1 route (IN-12), before any write to x, in this order: a logistic loss; coefficients that
# are not a dense Vector{Float32} or Vector{Float64}; the data checks of _check_problem with the placeholder
# NormL1(zero(T)); for APG, _check_method and _check_bound_size; the radius; the tolerances; finite budgets and
# curvature; for a design with a nonzero column, a normal positive curvature (in Float64 and in T), gap budget and
# mapping budget; the start's decision, which must be :pass. initial_state then refuses a start whose loss is not finite.
function _check_numerical_l1(x, f, g::IndBallL1, a::NumericalFeasibility, method, kind::Symbol)
  _is_logistic_loss(f) &&
    throw(ArgumentError("IndBallL1 with PGD or APG needs LeastSquaresLoss or one positive " *
                        "Scaled(LeastSquaresLoss); LogisticLoss is not supported"))
  x isa Vector && eltype(x) in (Float32, Float64) ||
    throw(ArgumentError("IndBallL1 with PGD or APG needs x to be a dense Vector{Float32} or " *
                        "Vector{Float64}; matrix and other coefficient storage is not supported"))
  T = eltype(x)
  _check_problem(x, f, NormL1(zero(T)), kind)
  if method isa AccProxGradDescent
    _check_method(method, T)
    _check_bound_size(f, x)
  end
  r = g.r
  r isa T && isfinite(r) && r > 0 ||
    throw(ArgumentError("IndBallL1 with PGD or APG needs a finite positive radius of type $T " *
                        "(got $r of type $(typeof(r)))"))
  tolerances = _feasibility_tolerances(a, T)
  d = leastsquares_data(f)
  alpha = Float64(d.α)
  b = _l1_budgets(d.X, d.Y, alpha, Float64(r), tolerances)
  all(isfinite, (b.cap, b.gap, b.mapping, b.curvature)) && isfinite(T(b.curvature)) && T(b.curvature) > 0 ||
    throw(ArgumentError("IndBallL1: the feasibility cap, the stopping budgets or " *
                        "the curvature α maxⱼ‖Xⱼ‖² are not finite in Float64, or the curvature is not finite and positive in $T; " *
                        "rescale the data, the radius or the tolerances"))
  # A design with a nonzero column needs a normal curvature in Float64 and in T and normal budgets: under gradual
  # underflow a zero or subnormal curvature or budget can let the full check pass at a point that is not stationary.
  # A design whose columns are all zero (C = 0, curvature 1.0) is exempt from this check only; the others apply to it.
  b.col > 0 && !(_normal_positive(b.curvature) && _normal_positive(T(b.curvature)) && _normal_positive(b.gap) &&
                 _normal_positive(b.mapping)) &&
    throw(ArgumentError("IndBallL1: for a design with a nonzero column, the curvature " *
                        "α maxⱼ‖Xⱼ‖² (in Float64 and in $T), the gap budget and the mapping budget must be normal positive " *
                        "numbers; one is zero or subnormal (underflow); rescale the data, the radius or the tolerances"))
  decision = _l1_decision(x, g, b.cap)
  decision.code === :over &&
    throw(ArgumentError("IndBallL1: the starting point is infeasible, its widened ℓ1 " *
                        "norm exceeds the radius by more than the feasibility cap $(b.cap)"))
  decision.code === :pass ||
    throw(ArgumentError("IndBallL1: the feasibility of the starting point against the " *
                        "cap $(b.cap) is unresolved at the rounding allowance of its widened ℓ1 norm"))
  (; budgets = b, tolerances, decision, alpha, data = d)
end

# The penalty value that a gradient step monitors for a trial point x, with v the value that
# ProximalBase's value_and_prox! returned for it (IN-08).
#
# For IndBallL2, ProximalBase stores a rounded projection and evaluates that stored point strictly, so v can be Inf for a
# point within rounding of the ball. This can occur for a radius below 2sqrt(4floatmin(T) / eps(T)) and for entries
# whose sum of squares leaves the normal range of T, where the projection takes ProximalBase's general route. The
# IndBallL2 method returns zero, the value of a clipped IndBox trial, when v == Inf and _within_ball_tolerance
# accepts x. Otherwise it returns v: an unadmitted Inf stays Inf, and 0 and NaN are returned unchanged without a scan
# of x. Backtracking or an APG momentum restart can supersede a trial that carries Inf before the step returns. The
# finiteness guard of _solve_gradient! sees the trial that the step returns, and raises and restores the last accepted
# point when its monitored composite is not finite. The generic method returns v for any other penalty, and for an
# IndBallL2 whose radius or coefficient array does not have the element type T (the gates refuse that problem).
@inline _trial_penalty_value(g, v, x) = v

@inline function _trial_penalty_value(g::IndBallL2{T}, v, x::Vector{T}) where {T<:Union{Float32, Float64}}
  v == T(Inf) && _within_ball_tolerance(x, g.r) ? zero(T) : v
end

# Whether the stored point x of an IndBallL2(r) trial is within the numerical tolerance of the Euclidean ball, so that
# the trial is admitted (IN-08); the caller supplies the condition that the
# fused value is Inf, which this function does not read. It requires r finite and positive, every entry finite, and
# the computed norm of x at most the computed threshold r (1 + 8eps(T)). The error bounds below assume round-to-nearest
# with gradual underflow (flushing subnormals to zero can erase an entry), hold to first order in u = eps(T) / 2, and are
# for the n = 4 entries of the supported IndBallL2.
#
# Projection. Suppose the quotient r / n̂ and the stored products are normal numbers. Its general route can then store
# y_i = fl(fl(r / n̂) x_i) with n̂ = fl(sqrt(fl(x_1² + ... + x_4²))). The sum of four squares has relative error at most
# 4u, so n̂ has at most 3u, the quotient adds u and the product adds u: ‖y‖ ≤ r (1 + 5u) = r (1 + 2.5 eps(T)). The scaled
# route, which sums compensated in Float64, counts at most 4u: two for the norm, one for the quotient and one for the
# entry. Under these assumptions a stored point with fused value Inf violates the ball by at most 2.5 eps(T). Outside
# them the relative estimate can fail, for example when the quotient is outside the normal range; and the final rounding of
# a product that falls in the subnormal range has an absolute error of at most nextfloat(zero(T)) / 2 (the recovered route
# can round the significand before that step), which relative to the radius is not bounded by u. For r = nextfloat(zero(T)) and x = (1, 1, 0, 0) the projection stores two entries equal to r, so
# ‖y‖ = sqrt(2) r, and the check rejects that point.
#
# Check, Float64. The entries and the radius are scaled by two normal powers of two, 2^k1 and 2^(k - k1), with
# k = -exponent(m) for the largest magnitude m and k1 = clamp(k, -1022, 1023). ProximalBase's `_normal_power` builds each
# factor from exponent bits over the normal range, and `_scale_value` applies them as two multiplications, so that the
# scaled maximum lies in [1, 2) and no square overflows. Both factors are exact for the largest entry. `_power_factors` is
# not used: for k = -1023 (m at least 2^1023) its single factor 2^-1023 is subnormal and can be treated as zero when
# subnormals are flushed.
# A scaled entry or square in the subnormal range is rounded, or lost to zero, with
# an absolute error (an entry can also round up to floatmin(Float64): prevfloat(2floatmin) beside a largest entry 2).
# Each affected scaled entry changes by at most 2^-1074 and each affected square by at most 2^-1075, so before the
# rounding of the sum the sum of squares changes by less than 2^-1072, against a sum of at least 1. This error is
# negligible in the bound below; the other operations contribute the relative errors accounted for there. It does not
# leave the correctly rounded norm unchanged: at a rounding tie, losing such a term can change it (the helper decides with
# its computed norm).
# The sum of squares is formed in order by ProximalBase's `_ball_l2_sum4`, ((a² + b²) + c²) + d², and not by its
# `_square_scaled_sum`, whose compensated sum can change decisions near the admission cutoff. The ordered sum has relative
# error at most 4u (the first two squares go through four roundings),
# so the computed norm has at most 3u; the threshold (r 2^k)(1 + 8eps) adds u. The computed norm is at most the computed
# threshold, so an admitted point has ‖y‖ ≤ r (1 + 8eps + 4u) = r (1 + 10 eps). The scaled radius r 2^k can overflow:
# it is then Inf, while the scaled norm is below 2sqrt(n) = 4, so the point is far inside the ball and is admitted. It can
# also underflow or be subnormal: it is then below 2^-1022, while the scaled norm is at least 1, so the point is
# rejected, as it is far outside.
# Check, Float32. The finite entries are widened to Float64 and summed in the same order by `_ball_l2_sum4`; the
# compensated `_square_scaled_sum` is not used, for the reason above. Float64 holds the exact square of every finite Float32, which neither overflows nor underflows, so
# there is no scaling, and under gradual underflow no entry or square is lost. The sum has relative error at most
# 3·2^-53, and the square root and the product with the radius add at most 2^-53 each, below 7e-16 in all. An admitted point has
# ‖y‖ ≤ r (1 + 8eps(Float32) + 7e-16).
# The decision compares computed values, not the exact test ‖y‖ ≤ r (1 + 8eps); the bound of 10 eps(T) covers the
# roundings. Under the assumptions of the projection estimate, a stored point of the general route violates by at most
# 2.5 eps(T), so in Float64 its computed norm is at most r (1 + 5u)(1 + 3u), about r (1 + 4 eps(T)), below the threshold
# r (1 + 8eps(T))(1 - u), and the point is admitted.
# In the Float64 method, once the radius is validated as positive and finite and the length is four, an all-zero x is
# admitted before any exponent is taken, because exponent(0.0) throws. Through the public solve! route the function is
# reached only for the four-coefficient IndBallL2 that solve! gates; a vector of another length returns false, so the trial
# keeps the value Inf.
function _within_ball_tolerance(x::Vector{Float32}, r::Float32)
  (isfinite(r) && r > 0 && length(x) == 4) || return false
  for xi in x
    isfinite(xi) || return false
  end
  s = ProximalBase._ball_l2_sum4(Float64(x[1]), Float64(x[2]), Float64(x[3]), Float64(x[4]))
  sqrt(s) <= Float64(r) * (1 + 8 * Float64(eps(Float32)))
end

function _within_ball_tolerance(x::Vector{Float64}, r::Float64)
  (isfinite(r) && r > 0 && length(x) == 4) || return false
  m = 0.0
  for xi in x
    isfinite(xi) || return false
    m = max(m, abs(xi))
  end
  iszero(m) && return true
  k = -exponent(m)
  k1 = clamp(k, -1022, 1023)
  p = (ProximalBase._normal_power(Float64, k1), ProximalBase._normal_power(Float64, k - k1))
  s = ProximalBase._ball_l2_sum4(ProximalBase._scale_value(x[1], p), ProximalBase._scale_value(x[2], p),
                                 ProximalBase._scale_value(x[3], p), ProximalBase._scale_value(x[4], p))
  sqrt(s) <= ProximalBase._scale_value(r, p) * (1 + 8 * eps(Float64))
end

_gradient_call_limit(state, options) =
  (0 < options.f_calls_limit <= state.f_calls ||
   0 < options.grad_calls_limit <= state.grad_calls ||
   0 < options.prox_calls_limit <= state.prox_calls)

_gradient_time_limit(t0, options) = time() - t0 > options.time_limit
_gradient_time_limit(t0::UInt64, options) = (time_ns() - t0) * 1e-9 >= options.time_limit

# Vector PGD/APG preserve their after-iteration limit and stopping semantics.
# A strict-budget search can return false when a limit interrupts a trial.
_strict_gradient_limits(state) = false
_stop_on_gradient_increase(state, options) = !options.allow_f_increases
# The IndBallL1 route has a method of this three-argument form that returns false (IN-12).
_stop_on_gradient_increase(state, g, options) = _stop_on_gradient_increase(state, options)
_gradient_tolerance(state, options) = options.gradtol
_gradient_tracing(state, options) =
  options.store_trace || options.show_trace || options.extended_trace || options.callback !== nothing
_rollback_gradient_step!(state) = _copyto!(state.x, state.x_previous)

@inline function _gradient_step!(state, f, g, method, options, t0)
  update_state!(f, g, state, method)
  true
end

function _solve_gradient!(state, f, g, method, options, t0 = time())

  tr = OptimizationTrace{typeof(method)}()
  tracing = _gradient_tracing(state, options)
  strict_limits = _strict_gradient_limits(state)
  call_limit_reached = strict_limits && _gradient_call_limit(state, options)
  stopped = call_limit_reached || (strict_limits && _gradient_time_limit(t0, options))
  stopped_by_callback = false
  stagnated = false
  x_converged, fg_converged, grad_converged, f_increased = false, false, false, false

  converged = false
  iteration = 0

  options.show_trace && @printf "Iter     Function value       |dx|/|x|       Step Size\n"

  while !converged && !stopped && iteration < options.maxiter
    completed = try
      accepted = _gradient_step!(state, f, g, method, options, t0)
      (!accepted || isfinite(state.f_x + state.g_x)) ||
        error("the gradient step did not produce a finite objective")
      accepted
    catch
      _rollback_gradient_step!(state)
      rethrow()
    end
    if !completed
      call_limit_reached = _gradient_call_limit(state, options)
      break
    end
    iteration += 1

    x_converged, fg_converged,
    grad_converged, converged, f_increased = convergence_assessment(state, f, g, options)

    if tracing
      # update trace; callbacks can stop routine early by returning true
      stopped_by_callback = trace!(tr, state, iteration, options)
    end

    stopped_by_time_limit = _gradient_time_limit(t0, options)
    call_limit_reached = _gradient_call_limit(state, options)
    if strict_limits && (stopped_by_time_limit || call_limit_reached || iteration == options.maxiter)
      x_converged = fg_converged = grad_converged = converged = false
    end

    # a numerical-stagnation stop (see _stagnated), checked after trace! and any callback call
    # that is due at this iteration under print_every
    stagnated = _stagnated(state, options)

    increased = f_increased && _stop_on_gradient_increase(state, g, options)
    stopped = increased || stagnated || stopped_by_callback || stopped_by_time_limit || call_limit_reached
  end # while
  # the residuals are stored as Float64, like the tolerances, whatever the element type
  return OptimizationResults{typeof(method), typeof(state.f_x), ndims(state.x), typeof(method), typeof(state.x)}(
                method,
                state.x,
                state.f_x + state.g_x,
                iteration,
                iteration == options.maxiter,
                converged,
                x_converged,
                options.xtol,
                Float64(_state_normdiff(state)),
                fg_converged,
                options.ftol,
                Float64(f_residual(state.f_x + state.g_x, state.f_x_previous + state.g_x_previous, options.ftol)),
                grad_converged,
                _gradient_tolerance(state, options),
                Float64(g_residual(state)),
                f_increased,
                tr,
                state.backtrack_steps,
                state.f_calls,
                state.grad_calls,
                state.prox_calls,
                call_limit_reached,
                stagnated,
                NaN)           # gap sentinel, never computed

end
