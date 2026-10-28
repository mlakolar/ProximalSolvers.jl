####################################
#
#  the square root of a quadratic  √(x'Ax + 2b'x + c)
#
####################################

"""
    SqrtQuadraticFunction(A, b, c; check = true)

The loss `f(x) = √(x'Ax + 2b'x + c)`, assuming the augmented matrix
`[A -b; -b' c]` is positive semidefinite, so the quadratic is nonnegative:
with `A = X'X/n`, `b = -X'y/n` and `c = y'y/n` it
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

As for [`SqrtLeastSquaresLoss`](@ref), a final relative duality gap must be at
most `gaptol`, or `1e-4` by default. A support/residual witness is tried
when the residual direction does not certify, including with unpenalized
coordinates. The support solve allows dependent columns and at most 2000
coordinates. Its Gram matrix is equilibrated before the rank decision; it
can still miss feasible dual points at some exact minimizers.
`Ax` and the quadratic are recomputed for certification. A conservative
rounding budget bounds the loss, dual norm and penalized correlations.
Unrestricted directions require a projection correction to the dual value,
unless their correlation intervals are exactly zero, when no inverse is needed.
Otherwise an unresolved span uses the zero witness. Compensated
accumulation retains small products and tightens cancellation bounds.
A quadratic negative beyond its budget
violates the PSD assumption and is not certified. Nonfinite penalty loadings
fix coordinates at zero and are excluded from the dual constraints, including
a zero level times an infinite weight. The public `duality_gap` interface
remains unsupported for this loss.
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
  grad::Vector{T}       # ∇f, for the duality gap at the end of a run
  dualx::Vector{T}      # dense iterate for certification
  dualu::Vector{T}      # recomputed Ax
  dualau::Vector{T}     # |A||x|, for the rounding budget
  duals::Vector{T}      # recomputed residual products -(Ax + b)
  dualerror::Vector{T}  # rounding bounds for those products
  dualactive::Vector{Int}
  dualeig::_GroupEig{T}
  dualvectors::Matrix{T}
  dualsupport::Vector{Int}
  dualc::Vector{T}
  dualrhs::Vector{T}
  dualα::Vector{T}
  dualγ::Vector{T}
  dualcorrerr::Vector{T}
  dualscale::Vector{T}
  dualunpen::Vector{Int}
  dualunpenscale::Vector{T}
  dualbound::T
  dualinv::T
end

cdmodel(f::SqrtQuadraticFunction{T}, x) where {T} =
  SqrtQuadModel{T, typeof(f.A), typeof(f.b)}(f.A, f.b, f.c, zeros(T, length(f.b)), f.c, zeros(T, length(f.b)),
                                         zeros(T, length(f.b)), zeros(T, length(f.b)), zeros(T, length(f.b)),
                                         zeros(T, length(f.b)), zeros(T, length(f.b)), sizehint!(Int[], length(f.b)),
                                         _GroupEig{T}(), Matrix{T}(undef, 0, 0), sizehint!(Int[], min(length(f.b), _SQRT_DUAL_MAXSUPPORT)),
                                         sizehint!(T[], min(length(f.b), _SQRT_DUAL_MAXSUPPORT)), T[], T[], T[],
                                         zeros(T, length(f.b)), T[], sizehint!(Int[], min(length(f.b), _SQRT_DUAL_MAXSUPPORT)),
                                         sizehint!(T[], min(length(f.b), _SQRT_DUAL_MAXSUPPORT)), zero(T), zero(T))

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

_certified!(st, m::SqrtQuadModel, g, x, s) = _sqrt_certified!(st, m, g, x, s)

@inline _sqrt_gram(m::SqrtQuadModel{T}, k, j) where {T} =
  (k < 0 ? m.c : m.A[k, j], zero(T))
@inline _sqrt_zerocol(m::SqrtQuadModel, k) = iszero(m.A[k, k])
@inline _sqrt_samecol(m::SqrtQuadModel, k, j) =
  m.A[k, k] == m.A[j, j] && (m.A[k, j] == m.A[k, k] || m.A[k, j] == -m.A[k, k])

# Accumulate product roundings as well as sum roundings. Near cancellation
# this tightens the first-order budget without losing an exact binary fit.
# The final error includes eps times the residual and 64m eps times the
# accumulated remainder magnitudes, bounded by second-order term magnitudes.
# The upper q, not its possibly cancelled cache, supplies the upper loss.
@inline function _sqrt_qadd(hi::T, lo::T, errors::T, value::T, error::T) where {T}
  total = hi + value
  v = total - hi
  e = (hi - (total - v)) + (value - v)
  total, lo + (e + error), errors + abs(e) + abs(error)
end

function _sqrt_compensated_q(m::SqrtQuadModel{T}, xv, active) where {T}
  hi, lo, errors = m.c, zero(T), zero(T)
  for k in active
    for _ in 1:2
      hi, lo, errors = _sqrt_addproduct(hi, lo, errors, m.b[k], xv[k])
    end
    for j in active
      hi, lo, errors = _sqrt_addtriple(hi, lo, errors, m.A[j, k], xv[k], xv[j])
    end
  end
  count = length(active)^2 + 2length(active) + 1
  _sqrt_finish(hi, lo, errors, count)
end

# Recompute Ax, q and the scales of their roundings, independently of the
# update cache. A materially negative q violates the augmented PSD assumption.
@inline function _sqrt_dualdata(m::SqrtQuadModel{T}, x) where {T}
  xv, active, u, au = m.dualx, m.dualactive, m.dualu, m.dualau
  xv .= x
  empty!(active)
  for k in eachindex(xv)
    iszero(xv[k]) || push!(active, k)
  end
  fill!(u, zero(T))
  fill!(au, zero(T))
  for k in active
    @inbounds @simd for i in eachindex(au)
      u[i] += m.A[i, k] * xv[k]
      au[i] += abs(m.A[i, k]) * abs(xv[k])
    end
  end
  bx = dot(m.b, xv)
  ax, abx = zero(T), zero(T)
  for k in eachindex(xv)
    ax += abs(xv[k]) * au[k]
    abx += abs(m.b[k]) * abs(xv[k])
  end
  scale = ax + 2abx + abs(m.c)
  rounding = _SQRT_DUAL_ROUNDING * max(1, length(active)) * eps(T)
  budget = rounding * scale
  q = dot(xv, u) + 2bx + m.c
  isfinite(q) && isfinite(budget) && q >= -budget || return nothing
  δq = budget
  refined, error = _sqrt_compensated_q(m, xv, active)
  if refined >= 0 && isfinite(error)
    q, δq = refined, error
  end
  f = _sqrt_upper(sqrt(max(_sqrt_upper(q + δq), zero(T))))
  s, serror = m.duals, m.dualerror
  for i in eachindex(s)
    hi, lo, errors = m.b[i], zero(T), zero(T)
    for k in active
      hi, lo, errors = _sqrt_addproduct(hi, lo, errors, m.A[i, k], xv[k])
    end
    value, serror[i] = _sqrt_finish(hi, lo, errors, length(active))
    s[i] = -value
  end
  ry, ryerror = _sqrt_dotbounds(m.b, xv, m.c)
  allowance = budget / max(f, sqrt(budget), floatmin(T)) + rounding * sqrt(scale)
  (; q, δq, f, s, serror, ry, ryerror, rounding = allowance)
end

function _sqrt_residualdual(m::SqrtQuadModel{T}, data, g, scale) where {T}
  nθ = _sqrt_upmul(abs(scale), data.f)
  D = scale * data.ry
  producterror = abs(fma(scale, data.ry, -D))
  _sqrt_productrisk(scale, data.ry, D) && (producterror += eps(zero(T)))
  D = _sqrt_lower(D - _sqrt_upper(_sqrt_upmul(abs(scale), data.ryerror) + producterror))
  for i in eachindex(m.grad)
    m.grad[i] = scale * data.s[i]
    producterror = abs(fma(scale, data.s[i], -m.grad[i]))
    _sqrt_productrisk(scale, data.s[i], m.grad[i]) && (producterror += eps(zero(T)))
    m.dualcorrerr[i] = _sqrt_upper(_sqrt_upmul(abs(scale), data.serror[i]) + producterror)
  end
  _sqrt_validated_dual(m, g, m.grad, nθ, D)
end

@inline function _sqrt_supportdata(m::SqrtQuadModel, data, S)
  n = length(S)
  K = reshape(view(m.dualeig.C, 1:n^2), n, n)
  s = view(m.dualrhs, 1:n)
  for i in 1:n
    s[i] = data.s[S[i]]
  end
  geometry = (; K, s)
  _sqrt_restore_support!(m, geometry, S)
  geometry
end

# LAPACK overwrites its Gram matrix; the norm identities need the original.
function _sqrt_restore_support!(m::SqrtQuadModel, geometry, S)
  for j in eachindex(S), i in eachindex(S)
    geometry.K[i, j] = m.A[S[i], S[j]]
  end
  nothing
end

function _sqrt_jointpoint(m::SqrtQuadModel{T}, data, g, S, geometry, α, γ) where {T}
  K, s = geometry.K, geometry.s
  ah, al, ae = zero(T), zero(T), zero(T)
  dh, dl, de = data.q, zero(T), zero(T)
  hh, hl, he = zero(T), zero(T), zero(T)
  for j in eachindex(S), i in eachindex(S)
    value = K[i, j]
    ah, al, ae = _sqrt_addtriple(ah, al, ae, α[i], value, α[j])
    dh, dl, de = _sqrt_addtriple(dh, dl, de, γ[i], value, γ[j])
    hh, hl, he = _sqrt_addtriple(hh, hl, he, -α[i], value, γ[j])
  end
  derror, herror = data.δq, zero(T)
  for i in eachindex(S)
    dh, dl, de = _sqrt_addtriple(dh, dl, de, -T(2), γ[i], s[i])
    hh, hl, he = _sqrt_addproduct(hh, hl, he, α[i], s[i])
    derror = _sqrt_upper(derror + _sqrt_upmul(T(2), _sqrt_upmul(abs(γ[i]), data.serror[S[i]])))
    herror = _sqrt_upper(herror + _sqrt_upmul(abs(α[i]), data.serror[S[i]]))
  end
  n = length(S)^2 + 3length(S) + 1
  a, aerror = _sqrt_finish(ah, al, ae, n)
  d, error = _sqrt_finish(dh, dl, de, n)
  derror = _sqrt_upper(derror + error)
  h, error = _sqrt_finish(hh, hl, he, n)
  herror = _sqrt_upper(herror + error)
  a >= -aerror && d >= -derror || return nothing
  β = _sqrt_residualpart(max(a, zero(T)), h, max(d - derror, zero(T)))
  nh, nl, ne = _sqrt_addtriple(a, zero(T), zero(T), T(2), β, h)
  nh, nl, ne = _sqrt_addtriple(nh, nl, ne, β, β, d)
  norm2, error = _sqrt_finish(nh, nl, ne, 6)
  normerror = _sqrt_upper(aerror + _sqrt_upmul(T(2), _sqrt_upmul(β, herror)) +
                         _sqrt_upmul(β, _sqrt_upmul(β, derror)) + error)
  norm2 >= -normerror || return nothing
  nθ = _sqrt_upper(sqrt(max(_sqrt_upper(norm2 + normerror), zero(T))))
  z = m.grad
  for i in eachindex(z)
    hi, lo, errors = _sqrt_addproduct(zero(T), zero(T), zero(T), β, data.s[i])
    for j in eachindex(S)
      hi, lo, errors = _sqrt_addproduct(hi, lo, errors, m.A[i, S[j]], α[j])
      hi, lo, errors = _sqrt_addtriple(hi, lo, errors, m.A[i, S[j]], γ[j], -β)
    end
    z[i], error = _sqrt_finish(hi, lo, errors, 4length(S) + 1)
    m.dualcorrerr[i] = _sqrt_upper(error + _sqrt_upmul(β, data.serror[i]))
  end
  # These identities retain the support-solve error and its cross term.
  hi, lo, errors = _sqrt_addproduct(zero(T), zero(T), zero(T), β, data.ry)
  for i in eachindex(S)
    hi, lo, errors = _sqrt_addproduct(hi, lo, errors, -α[i], m.b[S[i]])
    hi, lo, errors = _sqrt_addtriple(hi, lo, errors, β, γ[i], m.b[S[i]])
  end
  D, error = _sqrt_finish(hi, lo, errors, 4length(S) + 1)
  Derror = _sqrt_upper(error + _sqrt_upmul(β, data.ryerror))
  _sqrt_validated_dual(m, g, z, nθ, _sqrt_lower(D - Derror))
end

gradient!(G::AbstractVector{T}, m::SqrtQuadModel{T}, x) where {T} = (G .= (m.u .+ m.b) ./ sqrt(m.q))
