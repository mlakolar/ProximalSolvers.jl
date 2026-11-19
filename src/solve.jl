# Once-per-solve validation; no numeric solver arithmetic or conversion changes.
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

# The penalty check of _check_data for an x that is not a BlockIterate. `kind` is the gate's:
# :gradient (PGD and APG) and :cd (CDSolver on a dense Vector or a SparseIterate, and the default of a call
# without `kind`) both accept a NormL1, with or without weights, and an unweighted ElasticNet; :gradient also
# accepts a NormLinf, which :cd refuses with a message of its own (this CDSolver needs a separable penalty for
# its coordinate step), and a GroupNormL2 that passes _check_dense_group_penalty. Under :cd a GroupNormL2 is refused with a
// pointer to the supported alternatives. The levels must pass _scalar_parameter for T (finite, nonnegative,
# representable without overflow or underflow; a level that is subnormal in T passes it). A NormL1 with
# weights also passes _check_l1_weights, which refuses a level that is subnormal in T. A wrapper such as
# Scaled(NormLinf(λ)) is refused as any other penalty.
function _check_penalty(g, x, ::Type{T}, kind::Symbol = :cd) where T
  if g isa NormL1
    g.w === nothing ? _scalar_parameter(g.λ0, T, "penalty lambda") : _check_l1_weights(g, x, T)
  elseif g isa ElasticNet && g.w === nothing
    _scalar_parameter(g.λ1, T, "penalty lambda1")
    _scalar_parameter(g.λ2, T, "penalty lambda2")
  elseif g isa NormLinf && kind === :gradient
    _scalar_parameter(g.λ, T, "penalty lambda")
  elseif g isa NormLinf
    throw(ArgumentError("CDSolver does not support NormLinf (its coordinate step needs a separable penalty); use ProximalGradientDescent or AccProxGradDescent"))
  elseif g isa GroupNormL2 && kind === :gradient
    _check_dense_group_penalty(g, x, T)
  elseif g isa GroupNormL2
    throw(ArgumentError("CDSolver does not support GroupNormL2 (the group lasso) on a dense Vector or a SparseIterate; use CDSolver on a BlockIterate, or ProximalGradientDescent or AccProxGradDescent on a dense Vector"))
  elseif kind === :gradient
    throw(ArgumentError("only NormL1, unweighted ElasticNet, NormLinf or GroupNormL2 is supported"))
  else
    throw(ArgumentError("only NormL1 or unweighted ElasticNet is supported"))
  end
  nothing
end

# The weights of a NormL1 for data of type T. They must be a Vector{T} with one entry per entry of x,
# finite and nonnegative, and x must not alias them (x is the caller's array or owner, as for X and y).
# The level and the coefficients pass _weighted_level and _check_coefficients.
function _check_l1_weights(g, x, ::Type{T}) where T
  λ = _weighted_level(g.λ0, T)
  w = g.w
  w isa Vector{T} ||
    throw(ArgumentError("penalty weights must be a Vector{$T} (the element type of the data); convert an array with collect($T, vec(w)), which takes it in linear order"))
  length(w) == length(x) ||
    throw(DimensionMismatch("the penalty has $(length(w)) weights but x has $(length(x)) entries"))
  Base.mightalias(x, w) && throw(ArgumentError("mutable x must not alias the penalty weights"))
  _check_coefficients(λ, w, :entry)
  nothing
end

# The level λ = T(λ0) of a penalty with weights: it passes _scalar_parameter and must be zero or a normal
# number of T (not subnormal). Returns λ.
function _weighted_level(λ0, ::Type{T}) where T
  _scalar_parameter(λ0, T, "penalty lambda")
  λ = T(λ0)
  issubnormal(λ) && _l1_level_error(λ0, λ, T)
  λ
end

# The weights w of a weighted NormL1 (unit :entry, one weight per entry) or of a GroupNormL2 (unit :group, one
# weight per group) at the level λ, both of type T. Each weight must be finite and nonnegative. The coefficient
# checked is c = λ w of the entry or group, the product rounded in T (the stopping check of PGD and APG and the
# exceptional CD step use this c; ProximalBase's ordinary steps form their thresholds from λ0 and w in its working
# type): it must be finite and, where λ and w are both positive, a normal number of T (so not zero and not
# subnormal). The rule is on the rounded c: an exact product slightly below floatmin(T) that rounds up to
# floatmin(T) passes. A zero level or weight gives the coefficient 0, which leaves the entry or group
# unpenalized when it comes from w = 0.
function _check_coefficients(λ::T, w::Vector{T}, unit::Symbol) where T
  @inbounds for j in eachindex(w)
    wj = w[j]
    c = λ * wj
    isfinite(wj) && wj >= 0 && isfinite(c) && (iszero(c) ? (iszero(λ) | iszero(wj)) : floatmin(T) <= c) ||
      _l1_weight_error(λ, wj, j, T, unit)
  end
  nothing
end

@noinline _l1_level_error(λ0, λ::T, ::Type{T}) where T =
  throw(ArgumentError("penalty lambda $λ0 is subnormal in $T (it converts to $λ); with weights the level must be zero " *
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
# :cd or :block) is passed to _check_penalty.
function _check_data(x, f, g, ::Type{T}, kind::Symbol) where T
  base = if f isa LeastSquaresLoss
    f
  elseif f isa Scaled && f.f isa LeastSquaresLoss
    _check_loss_scale(leastsquares_data(f).α, T)
    f.f
  else
    throw(ArgumentError("only LeastSquaresLoss or one positive Scaled(LeastSquaresLoss) is supported"))
  end
  base.X isa Matrix{T} && base.Y isa Vector{T} ||
    throw(ArgumentError("X must be Matrix{$T} and y Vector{$T}; sparse designs and mixed array types are deferred, and matrix responses are supported only by CDSolver with a row-group GroupNormL2 on a Matrix or BlockIterate coefficient"))
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
  kind === :gradient &&
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

# The dense gate. `kind` is :cd for CDSolver and :gradient, the default, for PGD and APG. Under
# :gradient `_check_sqrt_data` refuses the square-root loss and `_check_penalty` accepts a NormLinf and a GroupNormL2,
# which it refuses under :cd.
function _check_problem(x, f, g, kind::Symbol = :gradient)
  x isa Vector && eltype(x) in (Float32, Float64) ||
    throw(ArgumentError("x must be a dense Vector{Float32} or Vector{Float64}"))
  base = _is_sqrt_loss(f) ? _check_sqrt_data(x, f, g, eltype(x), kind) : _check_data(x, f, g, eltype(x), kind)
  _allfinite(x) && _allfinite(base.Y) && _allfinite(base.X) ||
    throw(ArgumentError("x, X and y must contain only finite values"))
  nothing
end

# Coordinate descent also accepts a one-dimensional SparseIterate. Only its
# public active values are inspected; the aliasing check uses the owner itself,
# so an empty owner whose backing storage is shared with X or y is refused too.
_is_cd_owner(x) = x isa SparseIterate{<:Any, 1} && eltype(x) in (Float32, Float64)
function _check_owner_problem(x, f, g)
  _is_cd_owner(x) ||
    throw(ArgumentError("x must be a dense Vector or a one-dimensional SparseIterate of Float32 or Float64"))
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

function _solve_gradient!(state, f, g, method, options, t0 = time())

  tr = OptimizationTrace{typeof(method)}()
  tracing = options.store_trace || options.show_trace || options.extended_trace || options.callback !== nothing
  stopped, stopped_by_callback, stopped_by_time_limit = false, false, false
  stagnated = false
  f_limit_reached, grad_limit_reached, prox_limit_reached = false, false, false
  x_converged, fg_converged, grad_converged, f_increased = false, false, false, false

  converged = false
  iteration = 0

  options.show_trace && @printf "Iter     Function value       |dx|/|x|       Step Size\n"

  while !converged && !stopped && iteration < options.maxiter
    iteration += 1

    try
      update_state!(f, g, state, method)
      isfinite(state.f_x + state.g_x) || error("the gradient step did not produce a finite objective")
    catch
      # Trials overwrite x for allocation-free iteration. An unsuccessful
      # search must still leave the caller's last accepted point intact.
      _copyto!(state.x, state.x_previous)
      rethrow()
    end

    x_converged, fg_converged,
    grad_converged, converged, f_increased = convergence_assessment(state, f, g, options)

    if tracing
      # update trace; callbacks can stop routine early by returning true
      stopped_by_callback = trace!(tr, state, iteration, options)
    end

    stopped_by_time_limit = time()-t0 > options.time_limit ? true : false
    f_limit_reached = options.f_calls_limit > 0 && state.f_calls >= options.f_calls_limit
    grad_limit_reached = options.grad_calls_limit > 0 && state.grad_calls >= options.grad_calls_limit
    prox_limit_reached = options.prox_calls_limit > 0 && state.prox_calls >= options.prox_calls_limit

    # a numerical-stagnation stop (see _stagnated), checked after trace! and any callback call
    # that is due at this iteration under print_every
    stagnated = _stagnated(state, options)

    increased = f_increased && !options.allow_f_increases
    if increased || stagnated || stopped_by_callback ||
        stopped_by_time_limit || f_limit_reached || grad_limit_reached || prox_limit_reached
        stopped = true
    end
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
                options.gradtol,
                Float64(g_residual(state)),
                f_increased,
                tr,
                state.backtrack_steps,
                state.f_calls,
                state.grad_calls,
                state.prox_calls,
                f_limit_reached || grad_limit_reached || prox_limit_reached,
                stagnated,
                NaN)           # gap sentinel, never computed

end
