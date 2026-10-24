module Blocks

# The vector-space operations of the gradient solvers and ADMM on their
# iterates, for an array and for a tuple of arrays: the blocks of a product
# space, which SeparableSum and other functions of several blocks take. For an
# array each operation is the broadcast or the loop that the solvers apply to
# it; for a tuple it applies that block by block and combines the results, so
# that a tuple of one array computes exactly what the array does.

using LinearAlgebra
using ProximalBase: norm_diff

export _Blocks, _copy, _similar, _zero, _dense_similar, _copyto!, _copy!, _sub!, _step!, _extrapolate_point!,
       _relax!, _rdiv!, _norm, _norm_diff, _norm_inf, _dot, _dot_diff, _sumabs2, _length, _size,
       _maxabs_diff, _maxabs_axpy, _maxabs_stepdiff, _maxabs_residual, _allzero, _restricted_step!

# the iterates of a product space: a tuple of arrays with one element type
const _Blocks{T} = Tuple{AbstractArray{T}, Vararg{AbstractArray{T}}}

_copy(x::AbstractArray) = copy(x)
_copy(x::Tuple) = map(_copy, x)

_similar(x::AbstractArray) = similar(x)
_similar(x::Tuple) = map(_similar, x)

_zero(x::AbstractArray) = zero(x)
_zero(x::Tuple) = map(_zero, x)

# a dense array of the shape of x, for gradients
_dense_similar(x::AbstractArray{T}) where {T} = Array{T}(undef, size(x))
_dense_similar(x::Tuple) = map(_dense_similar, x)

_copyto!(y::AbstractArray, x::AbstractArray) = copyto!(y, x)
_copyto!(y::Tuple, x::Tuple) = (foreach(_copyto!, y, x); y)

_copy!(y::AbstractArray, x::AbstractArray) = copy!(y, x)
_copy!(y::Tuple, x::Tuple) = (foreach(_copy!, y, x); y)

# y = a - b
_sub!(y::AbstractArray, a, b) = (@. y = a - b; y)
_sub!(y::Tuple, a::Tuple, b::Tuple) = (foreach(_sub!, y, a, b); y)

# y = x - g / L
_step!(y::AbstractArray, x, g, L) = (@. y = x - g / L; y)
_step!(y::Tuple, x::Tuple, g::Tuple, L) = (foreach((yk, xk, gk) -> _step!(yk, xk, gk, L), y, x, g); y)

# y = x + ω (x - xp)
_extrapolate_point!(y::AbstractArray, x, xp, ω) = (@. y = x + ω * (x - xp); y)
_extrapolate_point!(y::Tuple, x::Tuple, xp::Tuple, ω) = (foreach((yk, xk, pk) -> _extrapolate_point!(yk, xk, pk, ω), y, x, xp); y)

# y = x + a (z - x) + b (x - xp), the extrapolation of monotone APG
_extrapolate_point!(y::AbstractArray, x, z, xp, a, b) = (@. y = x + a * (z - x) + b * (x - xp); y)
_extrapolate_point!(y::Tuple, x::Tuple, z::Tuple, xp::Tuple, a, b) =
  (foreach((yk, xk, zk, pk) -> _extrapolate_point!(yk, xk, zk, pk, a, b), y, x, z, xp); y)

# The support of a product-space iterate is the union of its block supports.
# Decide whether the WHOLE iterate is zero before constructing any block trial:
# a zero block in a nonzero tuple must not use its unrestricted gradient.
_allzero(x::AbstractArray) = all(iszero, x)
_allzero(x::Tuple) = all(_allzero, x)

# w = x - τ d, where d is the gradient on the support of x, or the whole
# gradient when whole is true. Return ‖d‖², over all blocks for a tuple.
function _restricted_step!(w::AbstractArray, x::AbstractArray{T}, grad::AbstractArray, τ, whole::Bool) where {T}
  dd = zero(T)
  @inbounds for i in eachindex(x)
    d = (whole || !iszero(x[i])) ? grad[i] : zero(T)
    dd += d^2
    w[i] = x[i] - τ * d
  end
  dd
end
_restricted_step!(w::Tuple, x::Tuple, grad::Tuple, τ, whole::Bool) =
  sum(map((wk, xk, gk) -> _restricted_step!(wk, xk, gk, τ, whole), w, x, grad))

# y = α x + (1 - α) z + u
_relax!(y::AbstractArray, α, x, z, u) = (@. y = α * x + (one(α) - α) * z + u; y)
_relax!(y::Tuple, α, x::Tuple, z::Tuple, u::Tuple) = (foreach((yk, xk, zk, uk) -> _relax!(yk, α, xk, zk, uk), y, x, z, u); y)

# u = u / c
_rdiv!(u::AbstractArray, c) = (u ./= c; u)
_rdiv!(u::Tuple, c) = (foreach(uk -> _rdiv!(uk, c), u); u)

# the Euclidean norm over all the blocks
_norm(x::AbstractArray) = norm(x)
_norm(x::Tuple{Any}) = _norm(x[1])
_norm(x::Tuple) = norm(map(_norm, x))

_norm_diff(x::AbstractArray, y::AbstractArray, p::Real = 2) = norm_diff(x, y, p)
_norm_diff(x::Tuple{Any}, y::Tuple{Any}, p::Real = 2) = _norm_diff(x[1], y[1], p)
_norm_diff(x::Tuple, y::Tuple, p::Real = 2) = norm(map((xk, yk) -> _norm_diff(xk, yk, p), x, y), p)

_norm_inf(x::AbstractArray) = norm(x, Inf)
_norm_inf(x::Tuple) = maximum(map(_norm_inf, x))

_dot(x::AbstractArray, y::AbstractArray) = dot(x, y)
_dot(x::Tuple, y::Tuple) = sum(map(_dot, x, y))

_sumabs2(x::AbstractArray) = sum(abs2, x)
_sumabs2(x::Tuple) = sum(map(_sumabs2, x))

_length(x::AbstractArray) = length(x)
_length(x::Tuple) = sum(map(length, x))

_size(x::AbstractArray) = size(x)
_size(x::Tuple) = map(size, x)

# ∑ᵢ (aᵢ - bᵢ) cᵢ, accumulated in the type T
function _dot_diff(::Type{T}, a::AbstractArray, b::AbstractArray, c::AbstractArray) where {T}
  s = zero(T)
  @inbounds @simd for i in eachindex(a)
    s += (a[i] - b[i]) * c[i]
  end
  s
end
_dot_diff(::Type{T}, a::Tuple, b::Tuple, c::Tuple) where {T} = sum(map((ak, bk, ck) -> _dot_diff(T, ak, bk, ck), a, b, c))

# maxᵢ |xᵢ - yᵢ|
function _maxabs_diff(x::AbstractArray{T}, y::AbstractArray) where {T}
  m = zero(T)
  @inbounds @simd for i in eachindex(x)
    m = max(m, abs(x[i] - y[i]))
  end
  m
end
_maxabs_diff(x::Tuple, y::Tuple) = maximum(map(_maxabs_diff, x, y))

# maxᵢ |L dᵢ + gᵢ|
function _maxabs_axpy(L::T, d::AbstractArray, g::AbstractArray) where {T}
  m = zero(T)
  @inbounds @simd for i in eachindex(d)
    m = max(m, abs(L * d[i] + g[i]))
  end
  m
end
_maxabs_axpy(L, d::Tuple, g::Tuple) = maximum(map((dk, gk) -> _maxabs_axpy(L, dk, gk), d, g))

# maxᵢ |L (yᵢ - xᵢ) - gᵢ|
function _maxabs_stepdiff(L::T, y::AbstractArray, x::AbstractArray, g::AbstractArray) where {T}
  m = zero(T)
  @inbounds @simd for i in eachindex(x)
    m = max(m, abs(L * (y[i] - x[i]) - g[i]))
  end
  m
end
_maxabs_stepdiff(L, y::Tuple, x::Tuple, g::Tuple) = maximum(map((yk, xk, gk) -> _maxabs_stepdiff(L, yk, xk, gk), y, x, g))

# maxᵢ |aᵢ - bᵢ - L dᵢ|
function _maxabs_residual(a::AbstractArray, b::AbstractArray, d::AbstractArray, L::T) where {T}
  m = zero(T)
  @inbounds @simd for i in eachindex(d)
    m = max(m, abs(a[i] - b[i] - d[i] * L))
  end
  m
end
_maxabs_residual(a::Tuple, b::Tuple, d::Tuple, L) = maximum(map((ak, bk, dk) -> _maxabs_residual(ak, bk, dk, L), a, b, d))

end
