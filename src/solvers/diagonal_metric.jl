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

_metric_prox!(x, g, z, L, m) = value_and_prox!(x, g, z, _metric_steps!(m, L))
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
  g(x)
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
  g.α * _metric_prox!(x, g.f, z, L / g.α, m)
end
