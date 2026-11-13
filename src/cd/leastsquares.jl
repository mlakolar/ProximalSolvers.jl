# Borrowed scalar unweighted LS data and native residual/curvature caches. The loss scale `s`
# has its own type `S`: the promotion of `T` and the type of the supplied scale where that is a
# concrete `AbstractFloat` (an IEEE scale wider than `T` keeps its precision), else `T`. X, y,
# the residual and the curvature cache are in `T`, and so are the loops over them (the column
# sums, the residual update, the sum in `loss_value` and the sum in the first two forms of
# `response_scale`).
mutable struct LSModel{T<:AbstractFloat, S<:AbstractFloat, MX<:AbstractMatrix{T}, VY<:AbstractVector{T}} <: CDModel{T}
  X::MX
  y::VY
  s::S
  r::Vector{T}
  a::Vector{T}
end
function _scale_type(::Type{T}, α) where T
  S = promote_type(T, typeof(α))
  isconcretetype(S) && S <: AbstractFloat ? S : T
end
LSModel(y::AbstractVector{T}, X::AbstractMatrix{T}, α::Real) where T =
  LSModel(X, y, convert(_scale_type(T, α), α), zeros(T, length(y)), fill(T(NaN), size(X, 2)))
cdmodel(f::LeastSquaresLoss{T, <:AbstractVector}, x) where T = LSModel(f.Y, f.X, one(T))
cdmodel(f::Scaled{<:LeastSquaresLoss{T, <:AbstractVector}}, x) where T = LSModel(f.f.Y, f.f.X, f.α)
_activeentries(x::SparseIterate) = activecoordinates(x)
initialize!(m::LSModel{T}, x::SparseIterate{T}) where T = _initialize!(m, x, true)
function _initialize!(m::LSModel{T}, x::SparseIterate{T}, fresh::Bool) where T
  length(x)==size(m.X,2) || throw(DimensionMismatch("iterate length differs from X columns"))
  copyto!(m.r, m.y)
  for k in _activeentries(x)
    v = x[k]
    iszero(v) && continue
    _residual_axpy!(m, k, v)
  end
  fill!(m.a, T(NaN))
  m
end
@inline function _column_dot(X::AbstractMatrix{T}, r::AbstractVector{T}, k::Int, a::T) where T
  b = zero(T)
  if isnan(a)
    a = zero(T)
    @inbounds @simd for i in eachindex(r)
      a += X[i, k]*X[i, k]
      b += r[i]*X[i, k]
    end
  else
    @inbounds @simd for i in eachindex(r)
      b += r[i]*X[i, k]
    end
  end
  a, b
end
@inline _column_dot(m::LSModel, k::Int) = _column_dot(m.X, m.r, k, m.a[k])
@inline function _residual_axpy!(m::LSModel{T}, k::Int, h::T) where T
  r, X = m.r, m.X
  @inbounds @simd for i in eachindex(r)
    r[i] -= X[i, k]*h
  end
  r
end
function _sqnorm!(m::LSModel{T}, k::Int) where T
  a = m.a[k]
  if isnan(a)
    a = zero(T)
    @inbounds for i in axes(m.X, 1)
      a += m.X[i, k]*m.X[i, k]
    end
    m.a[k] = a
  end
  a
end
function _flat_column(m::LSModel{T}, k::Int) where T
  for i in axes(m.X, 1)
    m.X[i, k] == zero(T) || return false
  end
  true
end
@inline function coordinate_step!(m::LSModel{T}, g, x::SparseIterate{T}, k::Int) where {T}
  a, b = _column_dot(m, k)
  iszero(a) && !_flat_column(m, k) &&
    throw(ArgumentError("the coordinate curvature underflows; rescale the data or loss"))
  old = x[k]
  new = iszero(a) ? _coordinate_minimizer(g, old, k) : prox_block(g, old + b / a, k, inv(m.s * a))
  m.a[k] = a
  h = new - old
  iszero(h) && return h      # x and the residuals do not change
  x[k] = new
  _residual_axpy!(m, k, h)
  h
end

_cache(m::LSModel) = m.r
# The stopping scales form the product `p` of the loss scale with a sum of squares in `S`.
# A zero response scale selects the absolute fallback of `_tolerances`. Where relative scaling is
# active (`relative=true` and a positive response scale, `scaled` in `_tolerances`), a zero
# coordinate scale makes that coordinate's change count as 0 in `_visit!`, and an infinite one makes
# a nonzero change infinite, which `_visit!` refuses. Otherwise `_visit!` does not use the
# coordinate scale.
# Response scale √(m.s Σy²): the sum Σy² is formed in `T` and is clean when it is finite and at
# least 4 length(y) floatmin(T), where the squares that underflow change it by less than u/4
# relative (u = eps(T)/2, the bound of `_se_norm_onepass`). With p = m.s Σy² in `S` and q = T(p),
# the scale is
#   1. sqrt(q), if the sum is clean and q is a normal number of `T`;
#   2. T(sqrt(p)), if `S` is wider than `T`, the sum is clean, p is a normal number of `S` and the
#      rounded root is a normal number of `T`;
#   3. otherwise the exponent-separated value of `_response_scale_exceptional`.
# Coordinate scale √(m.s a), with a the curvature of column k, p = m.s a in `S` and q = T(p):
#   1. sqrt(q), if q is a normal number of `T`;
#   2. otherwise T(sqrt(p)), if p is not below floatmin(S): this is Inf where p is Inf (an
#      overflowing product), and where relative scaling is active `_visit!` refuses a nonzero change
#      times Inf;
#   3. otherwise (p is zero or subnormal in `S`) T(sqrt(m.s) sqrt(S(a))), formed in `S`: each root is
#      taken before the two are multiplied, so the result does not depend on the rounded product p.
#      It is 0 for a = 0 (a column of zero curvature), and 0 where it is at most half the smallest
#      subnormal of `T`.
# For `S == T` the first two expressions have the same value where p is normal. For m.s > 0 an
# infinite curvature a gives Inf by the second. The step does not form this scale: its coefficient inv(m.s a)
# is the reciprocal of p, which is Inf where p is below 1/floatmax(S) and 0 where p is Inf. The
# overflow of m.s a, the step reciprocal and the infinite curvature are #294.
function coordinate_scale(m::LSModel{T}, x, k::Int) where T
  a = _sqnorm!(m, k)
  p = m.s*a
  q = T(p)
  floatmin(T) <= q <= floatmax(T) && return sqrt(q)
  S = typeof(p)
  p < floatmin(S) && return T(sqrt(m.s)*sqrt(S(a)))
  T(sqrt(p))
end
function response_scale(m::LSModel{T}, x) where T
  s = zero(T)
  @inbounds for i in eachindex(m.y)
    s += m.y[i]*m.y[i]
  end
  p = m.s*s
  q = T(p)
  if isfinite(s) && s >= 4*length(m.y)*floatmin(T)
    floatmin(T) <= q <= floatmax(T) && return sqrt(q)
    S = typeof(p)
    if S !== T && floatmin(S) <= p <= floatmax(S)
      r = T(sqrt(p))
      floatmin(T) <= r <= floatmax(T) && return r
    end
  end
  _response_scale_exceptional(m)
end
# √(m.s) ‖y‖ with the root of m.s and the norm of y carried as `_SE` (a significand and an Int
# exponent, from solvers/image_models.jl: `_se_norm`, `_root_scale`, `_se_mul`), in Float64 for
# Float32 data and in `T` otherwise, so that the exponent of the result is not limited by the range
# of `T`; the result is rounded once to `T`. It is 0 for y = 0 and for m.s = 0, which `_tolerances`
# turns into the absolute fallback, and a result that is not a normal number of `T` is refused.
# The sum of squares in `_se_norm` is `@simd`, so the value can differ in the last bits between CPUs.
function _response_scale_exceptional(m::LSModel{T}) where T
  iszero(m.s) && return zero(T)
  W = T === Float32 ? Float64 : T
  ny = _se_norm(W, m.y)
  ny === nothing && _refuse_response_scale(T, false)
  _se_scale(T, _se_mul(_root_scale(W, m.s), ny))
end
function _se_scale(::Type{T}, r::_SE) where T
  iszero(r.s) && return zero(T)
  v = T(ldexp(r.s, r.e))
  floatmin(T) <= v <= floatmax(T) || _refuse_response_scale(T, true)
  v
end
# The throw is out of line, so that `response_scale` carries no string interpolation.
@noinline function _refuse_response_scale(::Type{T}, finite_y::Bool) where T
  finite_y || throw(ArgumentError("the response scale is not defined: y has a non-finite entry"))
  throw(ArgumentError("the response scale (the root of the loss scale times the norm of y) is not a normal number of $T; rescale y or the loss scale, or use relative=false (an objective that overflows is still refused)"))
end
function loss_value(m::LSModel{T}, x) where T
  v = zero(T)
  @inbounds @simd for i in eachindex(m.r)
    v += m.r[i]*m.r[i]
  end
  T(m.s*v/2)
end
