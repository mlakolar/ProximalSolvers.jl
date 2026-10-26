####################################
#
#  the square root of a quadratic  √(x'Ax + 2b'x + c)
#
####################################

"""
    SqrtQuadraticFunction(A, b, c; check = true)

The loss `f(x) = √(x'Ax + 2b'x + c)`, with symmetric positive semidefinite `A`
and a nonnegative quadratic: with `A = X'X/n`, `b = -X'y/n` and `c = y'y/n` it
is `‖y - Xx‖ / √n`, the loss of [`SqrtLeastSquaresLoss`](@ref) divided by
`√n`, from the sufficient statistics. Coordinate descent ([`CDSolver`](@ref))
minimizes `f + g` exactly over each coordinate, for `g = NormL1(λ, w)`, at a
cost of O(p) per update instead of O(n). With `A = S`, `b = -S[:, j]`,
`c = S[j, j]` and an infinite weight on coordinate `j`, it is the square-root
(scaled) lasso of variable `j` on the others from their covariance matrix `S`,
as in the precision matrix estimator of Sun and Zhang (2013).

A dense `Matrix` `A` is used as it is, any other matrix is copied into one.
With `check`, `A` must be finite and symmetric, which costs O(p²); pass
`check = false` when many losses share one `A` checked once, as the columns of
a covariance matrix do. `b` and `c` are always checked.
"""
struct SqrtQuadraticFunction{T<:AbstractFloat, M<:AbstractMatrix{T}, V<:AbstractVector{T}} <: AbstractFunction
  A::M
  b::V
  c::T
  tmp::Vector{T}
end

function SqrtQuadraticFunction(A::AbstractMatrix, b::AbstractVector, c::Real; check::Bool = true)
  n = LinearAlgebra.checksquare(A)
  length(b) == n || throw(DimensionMismatch("A is $n × $n and b has length $(length(b))"))
  T = float(promote_type(eltype(A), eltype(b), typeof(c)))
  At = A isa Matrix{T} ? A : Matrix{T}(A)
  bt = convert(AbstractVector{T}, b)
  if check
    _check_finite(At, "A")
    issymmetric(At) || throw(ArgumentError("A must be symmetric"))
  end
  _check_finite(bt, "b")
  isfinite(c) || throw(ArgumentError("c must be finite, but it is $c."))
  SqrtQuadraticFunction{T, typeof(At), typeof(bt)}(At, bt, T(c), zeros(T, n))
end

ProximalBase.isconvex(::Type{<:SqrtQuadraticFunction}) = true

function (f::SqrtQuadraticFunction{T})(x::AbstractVector) where {T}
  mul!(f.tmp, f.A, x)
  sqrt(max(dot(x, f.tmp) + 2 * dot(f.b, x) + f.c, zero(T)))
end

# The model caches u = Ax, which is affine in x, so that momentum moves it with
# the point, and the value q = x'Ax + 2b'x + c, which is not, so that it is
# computed again after such a move (_cache_moved!). Building the model does not
# check A, which SqrtQuadraticFunction did, or not, as asked.
mutable struct SqrtQuadModel{T<:AbstractFloat, M<:AbstractMatrix{T}, V<:AbstractVector{T}} <: CDModel{T}
  A::M
  b::V
  c::T
  u::Vector{T}          # A x
  q::T                  # x'Ax + 2b'x + c
end

cdmodel(f::SqrtQuadraticFunction{T}, x) where {T} =
  SqrtQuadModel{T, typeof(f.A), typeof(f.b)}(f.A, f.b, f.c, zeros(T, length(f.b)), f.c)

# x'Ax + 2b'x + c over the active entries of x, from u = Ax
function _quadratic_value(m::SqrtQuadModel{T}, x::SparseIterate{T}) where {T}
  q = m.c
  for k in activecoordinates(x)
    v = x[k]
    q += v * (m.u[k] + 2 * m.b[k])
  end
  q
end

function initialize!(m::SqrtQuadModel{T}, x::SparseIterate{T}) where {T}
  length(x) == length(m.b) || throw(DimensionMismatch("x has length $(length(x)) and A has $(length(m.b)) columns"))
  u, A = m.u, m.A
  fill!(u, zero(T))
  for k in activecoordinates(x)
    v = x[k]
    iszero(v) && continue
    @inbounds @simd for i in eachindex(u)
      u[i] += A[i, k] * v
    end
  end
  m.q = _quadratic_value(m, x)
  m
end

# The exact minimizer over coordinate k. With xₖ = t and the other coordinates
# fixed, the quadratic is q₀ - 2st + at², with a = A[k, k], q₀ its value at
# t = 0 and s = a xₖ - (Ax + b)ₖ, the form of ‖r - X[:, k] t‖² for
# SqrtLeastSquaresLoss, whose closed form this uses. The coordinate is zero when
# |s| ≤ λ √q₀, when the loss does not depend on it (a = 0), and for an infinite
# weight; otherwise λ² < a, which rounding can break, so it is enforced.
function coordinate_step!(m::SqrtQuadModel{T}, g::NormL1, x::SparseIterate{T}, k::Int) where {T}
  A, u = m.A, m.u
  a = @inbounds A[k, k]
  old = x[k]
  gk = @inbounds u[k] + m.b[k]
  s = a * old - gk
  q0 = max(m.q - old * (2 * gk - a * old), zero(T))
  λ = T(g.λ0 * _weight(g, k))
  new = zero(T)
  if a > 0 && isfinite(λ)
    r = 1 - λ^2 / a
    if abs(s) > λ * sqrt(q0) && r > 0
      new = (s - copysign(λ / sqrt(r) * sqrt(max(q0 - s^2 / a, zero(T))), s)) / a
    end
  end
  h = new - old
  iszero(h) && return h
  x[k] = new
  m.q = max(q0 + new * (a * new - 2 * s), zero(T))
  @inbounds @simd for i in eachindex(u)
    u[i] += A[i, k] * h
  end
  h
end

_cache(m::SqrtQuadModel) = m.u
_cache_moved!(m::SqrtQuadModel, x) = (m.q = _quadratic_value(m, x); m)

check_penalty(::SqrtQuadModel, g) = g isa NormL1 ||
  throw(ArgumentError("coordinate descent on SqrtQuadraticFunction needs a NormL1 penalty, but g is a $(typeof(g))."))

# with A = X'X/n, √A[k, k] = ‖X[:, k]‖ / √n, and √c = ‖y‖ / √n
coordinate_scale(m::SqrtQuadModel{T}, x, k::Int) where {T} = sqrt(max(m.A[k, k], zero(T)))
response_scale(m::SqrtQuadModel{T}, x) where {T} = sqrt(max(m.c, zero(T)))

loss_value(m::SqrtQuadModel{T}, x) where {T} = sqrt(max(m.q, zero(T)))

_cd_solution_valid(m::SqrtQuadModel, g, x) = loss_value(m, x) > 0 || iszero(g(x))

gradient!(G::AbstractVector{T}, m::SqrtQuadModel{T}, x) where {T} = (G .= (m.u .+ m.b) ./ sqrt(m.q))
