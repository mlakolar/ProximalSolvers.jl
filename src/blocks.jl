module Blocks
# Private native-vector operations; historical reductions are retained.
using LinearAlgebra
using ProximalBase: norm_diff
export _eltype, _copy, _similar, _dense_similar, _copyto!, _copy!, _sub!, _step!, _norm, _norm_diff, _norm_inf, _dot, _dot_diff, _maxabs_axpy, _maxabs_residual
_eltype(x::AbstractArray) = eltype(x)
_copy(x::AbstractArray) = copy(x)
_similar(x::AbstractArray) = similar(x)
_dense_similar(x::AbstractArray{T}) where {T} = Array{T}(undef, size(x))
_copyto!(y::AbstractArray, x::AbstractArray) = copyto!(y, x)
_copy!(y::AbstractArray, x::AbstractArray) = copy!(y, x)
_sub!(y::AbstractArray, a, b) = (@. y = a - b; y)
_step!(y::AbstractArray, x, g, L) = (@. y = x - g / L; y)
_norm(x::AbstractArray) = norm(x)
_norm_diff(x::AbstractArray, y::AbstractArray, p::Real = 2) = norm_diff(x, y, p)
_norm_inf(x::AbstractArray) = norm(x, Inf)
_dot(x::AbstractArray, y::AbstractArray) = dot(x, y)
function _dot_diff(::Type{T}, a::AbstractArray, b::AbstractArray, c::AbstractArray) where {T}
  s = zero(T)
  @inbounds @simd for i in eachindex(a)
    s += (a[i] - b[i]) * c[i]
  end
  s
end

function _maxabs_axpy(L::T, d::AbstractArray, g::AbstractArray) where {T}
  m = zero(T)
  @inbounds @simd for i in eachindex(d)
    m = max(m, abs(L * d[i] + g[i]))
  end
  m
end

function _maxabs_residual(a::AbstractArray, b::AbstractArray, d::AbstractArray, L::T) where {T}
  m = zero(T)
  @inbounds @simd for i in eachindex(d)
    m = max(m, abs(a[i] - b[i] - d[i] * L))
  end
  m
end

end
