####################################
#
#  Kronecker quadratic of a symmetric Θ with the cache U = ΘB (QUIC's cache)
#
####################################

# The model of ⟨Θ, AΘB⟩/2 + ⟨C, Θ⟩, scaled by s, for symmetric A, B and a
# symmetric Θ held in a SymmetricSparseIterate, caching U = ΘB instead of
# KronModel's M = AΘB (Hsieh, Sustik, Dhillon and Ravikumar, *QUIC: quadratic
# approximation for sparse inverse covariance estimation*, 2014). The derivative
# along a coordinate then costs O(p), a dot product of columns of A and U,
# instead of O(1), but a move costs O(p), one or two rows of U, instead of
# KronModel's O(p²): cheaper when most visits move a coordinate, as on the free
# set of proximal Newton for the graphical lasso. Not reached by cdmodel.
mutable struct KronUModel{T<:AbstractFloat, MC<:Union{Nothing, Matrix{T}}} <: CDModel{T}
  A::Matrix{T}
  B::Matrix{T}
  C::MC
  s::T
  U::Matrix{T}          # Θ B
end

KronUModel(A::Matrix{T}, B::Matrix{T}, C, s) where {T} =
  KronUModel{T, typeof(C)}(A, B, C, T(s), zeros(T, size(A, 1), size(B, 1)))

# (AΘB)ᵢⱼ = A[:, i]' U[:, j] for a symmetric A
@inline function _AUB(m::KronUModel{T}, i::Int, j::Int) where {T}
  A, U = m.A, m.U
  v = zero(T)
  @inbounds @simd for k in axes(A, 1)
    v += A[k, i] * U[k, j]
  end
  v
end

# U[i, :] += h B[:, j]', for a symmetric B
@inline function _rowaxpy!(U::Matrix{T}, B::Matrix{T}, i::Int, j::Int, h::T) where {T}
  @inbounds for k in axes(U, 2)
    U[i, k] += h * B[k, j]
  end
  U
end

function initialize!(m::KronUModel{T}, x::SymmetricSparseIterate{T}) where {T}
  size(x) == size(m.U) || throw(DimensionMismatch("x is $(size(x, 1)) × $(size(x, 2)) and the loss takes $(size(m.U, 1)) × $(size(m.U, 2)) matrices"))
  fill!(m.U, zero(T))
  cx = coordinates(x)
  for k in activecoordinates(x)
    v = cx[k]
    iszero(v) && continue
    r, c = tril_cartesian(x.p, k)
    _rowaxpy!(m.U, m.B, r, c, v)
    r == c || _rowaxpy!(m.U, m.B, c, r, v)
  end
  m
end

# the derivative along the lower-triangle coordinate (r, c), which moves Θ[r, c]
# and Θ[c, r] together, as KronModel's _symderivative
@inline _symderivative(m::KronUModel{T}, r::Int, c::Int) where {T} =
  r == c ? _AUB(m, r, r) + _C(m.C, r, r, T) : (_AUB(m, r, c) + _AUB(m, c, r)) + (_C(m.C, r, c, T) + _C(m.C, c, r, T))

@inline function _move!(m::KronUModel{T}, r::Int, c::Int, h::T) where {T}
  _rowaxpy!(m.U, m.B, r, c, h)
  r == c || _rowaxpy!(m.U, m.B, c, r, h)
  m
end

@inline function coordinate_step!(m::KronUModel{T}, g, x::SymmetricSparseIterate{T}, k::Int) where {T}
  p = x.p
  r, c = tril_cartesian(p, k)
  a = m.s * _symcurvature(m.A, m.B, r, c)
  G = m.s * _symderivative(m, r, c)
  cx = coordinates(x)
  old = cx[k]
  i = _entry(p, r, c)
  new = _coordinate_minimizer(g, old, G, a, i, _multiplicity(T, r, c))
  h = new - old
  iszero(h) && return h
  cx[k] = new
  _move!(m, r, c, h)
  h
end

@inline function coordinate_derivatives(m::KronUModel{T}, x::SymmetricSparseIterate{T}, k::Int) where {T}
  r, c = tril_cartesian(x.p, k)
  m.s * _symderivative(m, r, c), m.s * _symcurvature(m.A, m.B, r, c)
end

@inline function update_cache!(m::KronUModel{T}, x::SymmetricSparseIterate{T}, k::Int, h::T) where {T}
  r, c = tril_cartesian(x.p, k)
  _move!(m, r, c, h)
end

# U = ΘB moves with Θ, but, as for KronModel, momentum is off by default
_cache(m::KronUModel) = m.U
_momentum_default(::KronUModel) = false

function coordinate_scale(m::KronUModel, x::SymmetricSparseIterate, k::Int)
  r, c = tril_cartesian(x.p, k)
  sqrt(m.s * _symcurvature(m.A, m.B, r, c))
end

function response_scale(m::KronUModel{T}, x::SymmetricSparseIterate) where {T}
  m.C === nothing && return zero(T)
  A, B, C = m.A, m.B, m.C
  s = zero(T)
  for c in axes(C, 2), r in c:size(C, 1)
    a = _symcurvature(A, B, r, c)
    d = r == c ? C[r, r] : C[r, c] + C[c, r]
    a > 0 && (s = max(s, abs(d) / sqrt(a)))
  end
  sqrt(m.s) * s
end

function loss_value(m::KronUModel{T}, x::SymmetricSparseIterate) where {T}
  v = zero(T)
  cx = coordinates(x)
  for k in activecoordinates(x)
    r, c = tril_cartesian(x.p, k)
    v += cx[k] * (r == c ? _AUB(m, r, r) / 2 + _C(m.C, r, r, T) :
                           (_AUB(m, r, c) + _AUB(m, c, r)) / 2 + _C(m.C, r, c, T) + _C(m.C, c, r, T))
  end
  m.s * v
end

# the gradient over symmetric matrices, s ((AU + (AU)')/2 + (C + C')/2), with one
# product AU
function gradient!(G::AbstractMatrix{T}, m::KronUModel{T}, x::SymmetricSparseIterate) where {T}
  size(G) == size(m.U) || throw(DimensionMismatch())
  mul!(G, m.A, m.U)
  C = m.C
  @inbounds for c in axes(G, 2), r in c:size(G, 1)
    v = m.s * ((G[r, c] + G[c, r]) / 2 + (_C(C, r, c, T) + _C(C, c, r, T)) / 2)
    G[r, c] = v
    G[c, r] = v
  end
  G
end
