# Borrowed scalar unweighted LS data and native residual/curvature caches. The loss scale `s`
# has its own type `S`: the promotion of `T` and the type of the supplied scale where that is a
# concrete `AbstractFloat` (an IEEE scale wider than `T` keeps its precision), else `T`. X, y,
# the residual and the curvature cache are in `T`, and so are the loops over them (the column
# sums, the residual update and the sums in `response_scale` and `loss_value`).
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
# The products of the loss scale with a sum of squares are formed in `S` and rounded to `T`
# before the square root (for `S == T` this is the product in `T`). A product that rounds to 0
# gives a scale of 0, which `_tolerances` reads as no response scale; rounding the root instead
# could leave a subnormal scale whose product with the tolerance rounds to 0.
coordinate_scale(m::LSModel{T}, x, k::Int) where T = sqrt(T(m.s*_sqnorm!(m, k)))
function response_scale(m::LSModel{T}, x) where T
  s = zero(T)
  @inbounds for i in eachindex(m.y)
    s += m.y[i]*m.y[i]
  end
  sqrt(T(m.s*s))
end
function loss_value(m::LSModel{T}, x) where T
  v = zero(T)
  @inbounds @simd for i in eachindex(m.r)
    v += m.r[i]*m.r[i]
  end
  T(m.s*v/2)
end
