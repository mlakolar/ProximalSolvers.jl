####################################
#
#  Kronecker quadratic  ⟨Θ, A Θ B⟩ / 2 + ⟨C, Θ⟩ (KronQuadratic of ProximalBase)
#
####################################

####################################
#  the coordinate descent model
####################################

# caches M = AΘB, so a coordinate step costs O(pq); the coordinates are the
# entries of a SparseIterate holding Θ (or vec Θ), or the lower-triangle entries
# of a SymmetricSparseIterate
mutable struct KronModel{T<:AbstractFloat, MC<:Union{Nothing, Matrix{T}}} <: CDModel{T}
  A::Matrix{T}
  B::Matrix{T}
  C::MC
  s::T
  M::Matrix{T}
end

cdmodel(f::KronQuadratic{T}, x) where {T} = KronModel{T, typeof(f.C)}(f.A, f.B, f.C, one(T), zeros(T, size(f)))
cdmodel(f::Scaled{<:KronQuadratic{T}}, x) where {T} =
  KronModel{T, typeof(f.f.C)}(f.f.A, f.f.B, f.f.C, T(f.α), zeros(T, size(f.f)))

@inline _C(::Nothing, r::Int, c::Int, ::Type{T}) where {T} = zero(T)
@inline _C(C::Matrix, r::Int, c::Int, ::Type{T}) where {T} = @inbounds C[r, c]

# M += h A[:, r] B[c, :]
@inline function _rank1!(M::Matrix{T}, A::Matrix{T}, B::Matrix{T}, r::Int, c::Int, h::T) where {T}
  @inbounds for j in axes(M, 2)
    t = h * B[j, c]
    @simd for i in axes(M, 1)
      M[i, j] += A[i, r] * t
    end
  end
  M
end

# M += h (A[:, r] B[c, :] + A[:, c] B[r, :])
@inline function _rank2!(M::Matrix{T}, A::Matrix{T}, B::Matrix{T}, r::Int, c::Int, h::T) where {T}
  @inbounds for j in axes(M, 2)
    t1 = h * B[j, c]
    t2 = h * B[j, r]
    @simd for i in axes(M, 1)
      M[i, j] += A[i, r] * t1 + A[i, c] * t2
    end
  end
  M
end

function initialize!(m::KronModel{T}, x::SparseIterate{T}) where {T}
  p, q = size(m.M)
  length(x) == p * q || throw(DimensionMismatch("x has $(length(x)) entries and the loss takes $p × $q matrices"))
  fill!(m.M, zero(T))
  for k in activecoordinates(x)
    v = x[k]
    iszero(v) && continue
    r, c = mod1(k, p), div(k - 1, p) + 1
    _rank1!(m.M, m.A, m.B, r, c, v)
  end
  m
end

function initialize!(m::KronModel{T}, x::SymmetricSparseIterate{T}) where {T}
  size(x) == size(m.M) || throw(DimensionMismatch("x is $(size(x, 1)) × $(size(x, 2)) and the loss takes $(size(m.M, 1)) × $(size(m.M, 2)) matrices"))
  fill!(m.M, zero(T))
  cx = coordinates(x)
  for k in activecoordinates(x)
    v = cx[k]
    iszero(v) && continue
    r, c = tril_cartesian(x.p, k)
    r == c ? _rank1!(m.M, m.A, m.B, r, r, v) : _rank2!(m.M, m.A, m.B, r, c, v)
  end
  m
end

# entry (r, c) of Θ = vec index k: curvature s A[r, r] B[c, c], derivative
# s (M[r, c] + C[r, c])
@inline function coordinate_step!(m::KronModel{T}, g, x::SparseIterate{T}, k::Int) where {T}
  A, B, M = m.A, m.B, m.M
  p = size(M, 1)
  r, c = mod1(k, p), div(k - 1, p) + 1
  a = m.s * (@inbounds(A[r, r]) * @inbounds(B[c, c]))
  G = m.s * (@inbounds(M[r, c]) + _C(m.C, r, c, T))
  old = x[k]
  new = _coordinate_minimizer(g, old, G, a, k)
  h = new - old
  iszero(h) && return h      # nothing to update, as for most coordinates at zero
  x[k] = new
  _rank1!(M, A, B, r, c, h)
  h
end

# the curvature along the lower-triangle coordinate (r, c) of a symmetric Θ,
# which moves Θ[r, c] and Θ[c, r] together
@inline _symcurvature(A, B, r::Int, c::Int) =
  @inbounds r == c ? A[r, r] * B[r, r] : (A[r, r] * B[c, c] + A[c, c] * B[r, r]) + 2 * A[r, c] * B[r, c]

# the derivative along it; the penalty counts an off-diagonal entry twice
@inline _symderivative(M, C, r::Int, c::Int, ::Type{T}) where {T} =
  @inbounds r == c ? M[r, r] + _C(C, r, r, T) : (M[r, c] + M[c, r]) + (_C(C, r, c, T) + _C(C, c, r, T))

@inline function coordinate_step!(m::KronModel{T}, g, x::SymmetricSparseIterate{T}, k::Int) where {T}
  A, B, M = m.A, m.B, m.M
  p = x.p
  r, c = tril_cartesian(p, k)
  a = m.s * _symcurvature(A, B, r, c)
  G = m.s * _symderivative(M, m.C, r, c, T)
  cx = coordinates(x)
  old = cx[k]
  i = _entry(p, r, c)
  new = _coordinate_minimizer(g, old, G, a, i, _multiplicity(T, r, c))
  h = new - old
  iszero(h) && return h
  cx[k] = new
  r == c ? _rank1!(M, A, B, r, r, h) : _rank2!(M, A, B, r, c, h)
  h
end

@inline function coordinate_derivatives(m::KronModel{T}, x::SparseIterate{T}, k::Int) where {T}
  p = size(m.M, 1)
  r, c = mod1(k, p), div(k - 1, p) + 1
  m.s * (@inbounds(m.M[r, c]) + _C(m.C, r, c, T)), m.s * (@inbounds(m.A[r, r]) * @inbounds(m.B[c, c]))
end

@inline function update_cache!(m::KronModel{T}, x::SparseIterate{T}, k::Int, h::T) where {T}
  p = size(m.M, 1)
  _rank1!(m.M, m.A, m.B, mod1(k, p), div(k - 1, p) + 1, h)
  m
end

@inline function coordinate_derivatives(m::KronModel{T}, x::SymmetricSparseIterate{T}, k::Int) where {T}
  r, c = tril_cartesian(x.p, k)
  m.s * _symderivative(m.M, m.C, r, c, T), m.s * _symcurvature(m.A, m.B, r, c)
end

@inline function update_cache!(m::KronModel{T}, x::SymmetricSparseIterate{T}, k::Int, h::T) where {T}
  r, c = tril_cartesian(x.p, k)
  r == c ? _rank1!(m.M, m.A, m.B, r, r, h) : _rank2!(m.M, m.A, m.B, r, c, h)
  m
end

# M = AΘB moves with Θ, but momentum is not used by default: on vec Θ with the
# two nonzero entries of DiffPrecTest's inverse Hessians it cost more than it
# saved (1.1 to 1.2 times slower). With momentum = true it is up to 1.3 times
# faster on the D-trace loss of a symmetric Θ
_cache(m::KronModel) = m.M
_momentum_default(::KronModel) = false

function coordinate_scale(m::KronModel, x::SparseIterate, k::Int)
  p = size(m.M, 1)
  r, c = mod1(k, p), div(k - 1, p) + 1
  sqrt(m.s * m.A[r, r] * m.B[c, c])
end
function coordinate_scale(m::KronModel, x::SymmetricSparseIterate, k::Int)
  r, c = tril_cartesian(x.p, k)
  sqrt(m.s * _symcurvature(m.A, m.B, r, c))
end

# maxₖ |∂ₖf(0)| / √aₖ over the coordinates, as for a quadratic; zero without C
function response_scale(m::KronModel{T}, x::SparseIterate) where {T}
  m.C === nothing && return zero(T)
  A, B, C = m.A, m.B, m.C
  s = zero(T)
  for c in axes(C, 2), r in axes(C, 1)
    a = A[r, r] * B[c, c]
    a > 0 && (s = max(s, abs(C[r, c]) / sqrt(a)))
  end
  sqrt(m.s) * s
end

function response_scale(m::KronModel{T}, x::SymmetricSparseIterate) where {T}
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

function loss_value(m::KronModel{T}, x::SparseIterate) where {T}
  v = zero(T)
  for k in activecoordinates(x)
    v += x[k] * (m.M[k] / 2 + (m.C === nothing ? zero(T) : m.C[k]))
  end
  m.s * v
end

function loss_value(m::KronModel{T}, x::SymmetricSparseIterate) where {T}
  v = zero(T)
  cx = coordinates(x)
  for k in activecoordinates(x)
    r, c = tril_cartesian(x.p, k)
    v += cx[k] * (r == c ? m.M[r, r] / 2 + _C(m.C, r, r, T) : (m.M[r, c] + m.M[c, r]) / 2 + _C(m.C, r, c, T) + _C(m.C, c, r, T))
  end
  m.s * v
end

# the gradient AΘB + C, entry by entry like x; over symmetric matrices for a
# symmetric x
function gradient!(G::AbstractArray{T}, m::KronModel{T}, x::SparseIterate) where {T}
  length(G) == length(m.M) || throw(DimensionMismatch())
  @inbounds for k in eachindex(m.M)
    G[k] = m.s * (m.M[k] + (m.C === nothing ? zero(T) : m.C[k]))
  end
  G
end

function gradient!(G::AbstractMatrix{T}, m::KronModel{T}, x::SymmetricSparseIterate) where {T}
  size(G) == size(m.M) || throw(DimensionMismatch())
  M, C = m.M, m.C
  @inbounds for c in axes(M, 2), r in axes(M, 1)
    G[r, c] = m.s * ((M[r, c] + M[c, r]) / 2 + (_C(C, r, c, T) + _C(C, c, r, T)) / 2)
  end
  G
end
