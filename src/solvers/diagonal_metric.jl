# Nothing specializes to the original scalar operations, without metric buffers.
_preconditioner(p::Symbol) = p === :none ? nothing : p === :diagonal ? p :
  throw(ArgumentError("preconditioner must be :none or :diagonal, got $p."))

struct _DiagonalMetric{A}
  diagonal::A
  root::A
  steps::A
end

_diagonal_metric(::Nothing, f, x) = nothing
function _diagonal_metric(::Symbol, f, x::AbstractArray{T}) where {T<:AbstractFloat}
  d = _dense_similar(x)
  coordinate_lipschitz!(d, f)
  for i in eachindex(d)
    isfinite(d[i]) && d[i] >= 0 ||
      throw(ArgumentError("diagonal preconditioning needs finite nonnegative coordinate curvatures; entry $i is $(d[i])."))
    # A flat coordinate still needs a positive metric (and can have a linear term).
    iszero(d[i]) && (d[i] = one(T))
  end
  _DiagonalMetric(d, sqrt.(d), similar(d))
end
_diagonal_metric(::Symbol, f, x::SymmetricSparseIterate) =
  throw(ArgumentError("diagonal preconditioning needs independent entries; use a dense matrix instead of SymmetricSparseIterate."))
_diagonal_metric(::Symbol, f, x) =
  throw(ArgumentError("diagonal preconditioning needs an array of real floating point entries."))

_metric_step!(y, x, g, L, ::Nothing) = _step!(y, x, g, L)
_metric_steps!(::Nothing, L) = one(L) / L
_metric_norm2(::Nothing, x) = _sumabs2(x)
_metric_norm(::Nothing, x) = _norm(x)
_metric_normdiff(::Nothing, x, y) = _norm_diff(x, y, 2.)
function _metric_normdiff(m::_DiagonalMetric, x, y)
  s = zero(eltype(x))
  @inbounds @simd for i in eachindex(x)
    s += m.diagonal[i] * abs2(x[i] - y[i])
  end
  sqrt(s)
end
_metric_norm(m::_DiagonalMetric, x) = sqrt(_metric_norm2(m, x))
_pgd_norm2(::Nothing, x) = _norm(x)^2
_pgd_norm2(m::_DiagonalMetric, x) = _metric_norm2(m, x)
_metric_residual(::Nothing, a, b, d, L) = _maxabs_residual(a, b, d, L)
_metric_mapping(::Nothing, x, y, L) = L * _maxabs_diff(x, y)
_metric_subgrad(::Nothing, L, d, g) = _maxabs_axpy(L, d, g)
_metric_subgrad_diff(::Nothing, L, y, x, g) = _maxabs_stepdiff(L, y, x, g)
_metric_dualnorm(::Nothing, g) = _norm_inf(g)

function _metric_step!(y, x, g, L, m::_DiagonalMetric)
  @. y = x - (g / m.diagonal) / L
  y
end
function _metric_steps!(m::_DiagonalMetric, L)
  @. m.steps = (one(L) / L) / m.diagonal
  m.steps
end
function _metric_norm2(m::_DiagonalMetric, x)
  s = zero(eltype(x))
  @inbounds @simd for i in eachindex(x)
    s += m.diagonal[i] * abs2(x[i])
  end
  s
end

# Residuals and normalizers are measured in u = sqrt(D) x coordinates.
function _metric_residual(m::_DiagonalMetric, a, b, d, L)
  r = zero(eltype(a))
  @inbounds @simd for i in eachindex(a)
    r = max(r, abs((a[i] - b[i]) / m.root[i] - L * m.root[i] * d[i]))
  end
  r
end
function _metric_mapping(m::_DiagonalMetric, x, y, L)
  r = zero(eltype(x))
  @inbounds @simd for i in eachindex(x)
    r = max(r, abs(L * m.root[i] * (x[i] - y[i])))
  end
  r
end
function _metric_subgrad(m::_DiagonalMetric, L, d, g)
  r = zero(eltype(g))
  @inbounds @simd for i in eachindex(g)
    r = max(r, abs(L * m.root[i] * d[i] + g[i] / m.root[i]))
  end
  r
end
function _metric_subgrad_diff(m::_DiagonalMetric, L, y, x, g)
  r = zero(eltype(g))
  @inbounds @simd for i in eachindex(g)
    r = max(r, abs(L * m.root[i] * (y[i] - x[i]) - g[i] / m.root[i]))
  end
  r
end
function _metric_dualnorm(m::_DiagonalMetric, g)
  r = zero(eltype(g))
  @inbounds @simd for i in eachindex(g)
    r = max(r, abs(g[i] / m.root[i]))
  end
  r
end

_metric_prox!(x, g, z, L, m) = convert(_eltype(x), value_and_prox!(x, g, z, _metric_steps!(m, L)))

# The step of the gradient solvers, with w a dense buffer of the shape of z that
# the solver does not read until it writes it again (delta_x); w serves an owner x.
_metric_prox!(x, g, z, L, m, w) = _metric_prox!(x, g, z, L, m)
# For the penalties below, and Scaled, Translate and Tilt around them, an owner x
# takes the proximal point over matrices: it goes into w, and the checked
# copyto! of ProximalBase moves it into x, or throws an ArgumentError before
# writing x when w is not exactly symmetric. (A ProximalBase in which the owner
# is not an AbstractArray, such as ProximalBase #737, has no proximal operator
# into an owner for these three families; the route is taken with every
# ProximalBase.) When z is symmetric and g(X') = g(X) (symmetric parameters,
# which _symmetric_penalty requires), a unique proximal point over matrices is
# symmetric, and it is then the proximal point over symmetric matrices.
_owner_prox(g) = true
_owner_prox(::Union{ProximalBase.PointwiseMinimum, ProximalBase.IndIntersection, ProximalBase.LinearConstrained}) = false
_owner_prox(g::Union{Scaled, Translate, ProximalBase.Tilt}) = _owner_prox(g.f)
function _metric_prox!(x::SymmetricSparseIterate, g, z::AbstractMatrix, L, ::Nothing, w::AbstractMatrix)
  _owner_prox(g) && return convert(_eltype(x), value_and_prox!(x, g, z, one(L) / L))
  v = value_and_prox!(w, g, z, one(L) / L)
  copyto!(x, w)
  convert(_eltype(x), v)
end

# Whether the step of x with the penalty g takes the dense route: an owner whose
# penalty is one of the three families above (_owner_prox), or a tuple whose
# penalty is a SeparableSum with one penalty per block, also inside Scaled, and
# inside Translate and Tilt with a tuple parameter of one block per block of x,
# in which some block takes the dense route. Any other pair keeps the step of
# ProximalBase on x.
_dense_route(x, g) = false
_dense_route(x::SymmetricSparseIterate, g) = !_owner_prox(g)
_dense_route(x::Tuple, g::SeparableSum) = length(g.fs) == length(x) && any(map(_dense_route, x, g.fs))
_dense_route(x::Tuple, g::Scaled) = _dense_route(x, g.f)
_dense_route(x::Tuple, g::Translate) = g.b isa Tuple && length(g.b) == length(x) && _dense_route(x, g.f)
_dense_route(x::Tuple, g::ProximalBase.Tilt) = g.c isa Tuple && length(g.c) == length(x) && _dense_route(x, g.f)

# On the dense route a tuple x takes the proximal step of ProximalBase for the
# whole penalty g at once, into the blocks of w: a dense matrix for each owner
# and a block of the type of x for the others (_trial_similar). Then the blocks
# of w are committed into x: owners through the checked copyto!, the others with
# _copyto!. Refused before any block of x is written, with an ArgumentError:
# blocks of w that do not match x in number, shape or element type, or that share
# storage with each other, with a block of x or with z (checked before the
# proximal step), and an owner block of w that is not exactly symmetric (checked
# after it, by the copyto! of that block, which throws before writing). An
# exception during the commit itself, such as an interrupt or running out of
# memory, can leave earlier blocks written.
_exactly_symmetric(w::AbstractMatrix) = all(_symmetric_pair(w[r, c], w[c, r]) for c in axes(w, 2) for r in c+1:size(w, 1))
_route_block_ok(xk, wk) = typeof(wk) === typeof(xk) && _size(wk) == _size(xk)
_route_block_ok(xk::SymmetricSparseIterate, wk) = wk isa Matrix{eltype(xk)} && size(wk) == size(xk)
function _route_preflight(x::Tuple, z::Tuple, w::Tuple)
  length(w) == length(x) == length(z) && all(map(_route_block_ok, x, w)) ||
    throw(ArgumentError("the scratch blocks of the proximal step must match the iterate blocks in number, shape and element type."))
  for j in eachindex(w)
    any(k -> _mightalias(w[j], x[k]) || _mightalias(w[j], z[k]) || (k != j && _mightalias(w[j], w[k])), eachindex(x)) &&
      throw(ArgumentError("the scratch blocks of the proximal step must have storage of their own."))
  end
  nothing
end
_commit_block!(xk, wk) = _copyto!(xk, wk)
function _metric_prox!(x::Tuple, g, z::Tuple, L, m::Nothing, w::Tuple)
  _dense_route(x, g) || return _metric_prox!(x, g, z, L, m)
  _route_preflight(x, z, w)
  v = value_and_prox!(w, g, z, one(L) / L)
  foreach((xk, wk) -> (xk isa SymmetricSparseIterate && !_exactly_symmetric(wk) && copyto!(xk, wk); nothing), x, w)
  foreach(_commit_block!, x, w)
  convert(_eltype(x), v)
end
# The identity prox is independent of the metric. ZeroFunction only has a
# scalar-step method in ProximalBase.
function _metric_prox!(x, ::ZeroFunction, z, L, m::_DiagonalMetric)
  _copyto!(x, z)
  zero(eltype(x))
end

# ProximalBase's group steps are constant within a group. For a genuinely
# entrywise metric, solve the one-dimensional optimality equation instead.
function _metric_prox!(x, g::ProximalBase.AbstractGroupNorm, z, L, m::_DiagonalMetric)
  length(x) >= length(g.group_of) || throw(DimensionMismatch("penalty groups exceed the iterate length."))
  _copyto!(x, z)  # entries outside the groups are unpenalized
  for k in eachindex(g.groups)
    _metric_group!(x, z, g.groups[k], g.λ0 * g.w[k] / L, m.diagonal, g)
  end
  convert(_eltype(x), g(x))
end

function _metric_group!(x, z, G, c, d, ::GroupNormL2)
  T = eltype(x)
  c = T(c)
  iszero(c) && return x
  dual2, nz2 = zero(T), zero(T)
  @inbounds for i in G
    dual2 += abs2(d[i] * z[i])
    nz2 += abs2(z[i])
  end
  if sqrt(dual2) <= c
    @inbounds for i in G
      x[i] = zero(T)
    end
    return x
  end
  # r = norm(x[G]); x_i = z_i r / (r + c/d_i), and the norm equation is
  # sum((z_i / (r + c/d_i))^2) = 1. It is decreasing on [0, norm(z[G])].
  lo, hi = zero(T), sqrt(nz2)
  for _ in 1:2precision(T)
    r = lo + (hi - lo) / 2
    (r == lo || r == hi) && break
    s = zero(T)
    @inbounds for i in G
      s += abs2(z[i] / (r + c / d[i]))
    end
    if s > one(T)
      lo = r
    else
      hi = r
    end
  end
  r = hi
  @inbounds for i in G
    x[i] = z[i] * (r / (r + c / d[i]))
  end
  x
end

function _metric_group!(x, z, G, c, d, ::GroupNormLinf)
  T = eltype(x)
  c = T(c)
  iszero(c) && return x
  total = zero(T)
  @inbounds for i in G
    total += d[i] * abs(z[i])
  end
  if total <= c
    @inbounds for i in G
      x[i] = zero(T)
    end
    return x
  end
  # Clip at tau where sum(d_i * max(abs(z_i) - tau, 0)) = c.
  tau, last = T(-Inf), typemax(Int)
  while true
    s, w, count = zero(T), zero(T), 0
    @inbounds for i in G
      if abs(z[i]) > tau
        s += d[i] * abs(z[i])
        w += d[i]
        count += 1
      end
    end
    (count >= last || count == 0) && break
    last = count
    tau = max((s - c) / w, zero(T))
  end
  @inbounds for i in G
    x[i] = sign(z[i]) * min(abs(z[i]), tau)
  end
  x
end

function _metric_prox!(x, g::Scaled{<:ProximalBase.AbstractGroupNorm}, z, L, m::_DiagonalMetric)
  if iszero(g.α)
    _copyto!(x, z)
    return zero(eltype(x))
  end
  convert(_eltype(x), g.α * _metric_prox!(x, g.f, z, L / g.α, m))
end
