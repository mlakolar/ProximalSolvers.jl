# Historical LS image evaluation; no exceptional-range recovery is added.

struct _LSImage{TY<:AbstractVecOrMat, TX<:AbstractMatrix, A<:Real, T<:AbstractFloat}
  Y::TY
  X::TX
  α::A                  # the scale of a Scaled loss, one otherwise
end

_LSImage(f::LeastSquaresLoss{T}, α::Real) where {T} = _LSImage{typeof(f.Y), typeof(f.X), typeof(α), T}(f.Y, f.X, α)
_image_model(f::LeastSquaresLoss) = _LSImage(f, true)
_image_model(f::Scaled{<:LeastSquaresLoss}) = _LSImage(f.f, f.α)
_image_buffer(m::_LSImage{TY, TX, A, T}) where {TY, TX, A, T} = zeros(T, size(m.Y))
_image!(z, m::_LSImage, x) = mul!(z, m.X, x)
_value!(f, x, m, z) = (_image!(z, m, x); convert(_eltype(x), _image_value(m, z)))
_value_and_gradient!(G, f, x, m, z, d) = convert(_eltype(x), _image_value_and_gradient!(G, m, z, d))
function _image_value(m::_LSImage{TY, TX, A, T}, z) where {TY, TX, A, T}
  Y = m.Y
  v = zero(T)
  @inbounds @simd for i in eachindex(z, Y)
    v += abs2(Y[i] - z[i])
  end
  m.α * (v / 2)
end

function _image_value_and_gradient!(G, m::_LSImage, z, d)
  d .= z .- m.Y
  mul!(G, transpose(m.X), d)
  v = sum(abs2, d) / 2
  G .*= m.α
  m.α * v
end

# ---- The accelerated method's certified backtracking test ----------------------------
#
# Nonnegative reals carried as s·2^e, s ∈ [1, 2) of type T and e an Int (zero as s = 0),
# so that products and sums of norms neither overflow nor lose precision to subnormal
# rounding in T. Only significands in [0, 4) are ever multiplied or added.
struct _SE{T}
  s::T
  e::Int
end
_se_zero(::Type{T}) where {T} = _SE{T}(zero(T), 0)
_renormal(s::T, e::Int) where {T} = iszero(s) ? _se_zero(T) : _SE{T}(significand(s), e + exponent(s))
# x finite and nonnegative, of any floating-point type; its significand is rounded to T
_SE{T}(x::AbstractFloat) where {T} = iszero(x) ? _se_zero(T) : _renormal(T(significand(x)), exponent(x))
_se_mul(a::_SE{T}, b::_SE{T}) where {T} =
  iszero(a.s) || iszero(b.s) ? _se_zero(T) : _renormal(a.s * b.s, a.e + b.e)
_se_mul(a::_SE, b::_SE, c::_SE...) = _se_mul(_se_mul(a, b), c...)
_se_le(a::_SE, b::_SE) = iszero(a.s) || (!iszero(b.s) && (a.e < b.e || (a.e == b.e && a.s <= b.s)))
function _se_add(a::_SE{T}, b::_SE{T}) where {T}
  iszero(a.s) && return b
  iszero(b.s) && return a
  a.e < b.e && ((a, b) = (b, a))
  _renormal(a.s + ldexp(b.s, b.e - a.e), a.e)
end
# max(a - b, 0)
function _se_sub(a::_SE{T}, b::_SE{T}) where {T}
  iszero(b.s) && return a
  _se_le(a, b) && return _se_zero(T)
  _renormal(a.s - ldexp(b.s, b.e - a.e), a.e)     # a > b > 0, so a.e ≥ b.e
end

# Σ (vᵢ / m)² for m = max|vᵢ| > 0, in [1, length(v)]
function _sumsq_scaled(v, m)
  s = zero(m)
  @inbounds @simd for i in eachindex(v)
    s += abs2(v[i] / m)
  end
  s
end

# Σ ((aᵢ - bᵢ) / m)² for m = max|aᵢ - bᵢ| > 0
function _sumsq_scaled_diff(a, b, m)
  s = zero(m)
  @inbounds @simd for i in eachindex(a, b)
    s += abs2((a[i] - b[i]) / m)
  end
  s
end

# The computed ‖v‖ (v a vector or matrix of T) in the scaled two-pass form m √s, m = max|vᵢ|,
# as an _SE; nothing when an entry is not finite.
function _se_norm(::Type{T}, v) where {T}
  m = T(maximum(abs, v))           # NaN when an entry is NaN
  isfinite(m) || return nothing
  iszero(m) && return _se_zero(T)
  _se_mul(_SE{T}(m), _SE{T}(sqrt(_sumsq_scaled(v, m))))
end

# The computed ‖a - b‖ of the rounded differences aᵢ - bᵢ
function _se_norm_diff(::Type{T}, a, b) where {T}
  m = _maxabs_diff(a, b)
  isfinite(m) || return nothing
  iszero(m) && return _se_zero(T)
  s = _sumsq_scaled_diff(a, b, m)
  isfinite(s) || return nothing
  _se_mul(_SE{T}(m), _SE{T}(sqrt(s)))
end

# Σ dᵢ² and Σ xᵢ² in one pass
function _sumsq2(d, x)
  sd, sx = zero(eltype(d)), zero(eltype(x))
  @inbounds @simd for i in eachindex(d, x)
    sd += abs2(d[i])
    sx += abs2(x[i])
  end
  sd, sx
end

# Σ (aᵢ - bᵢ)² in one pass
function _sumsq_diff(a, b)
  s = zero(eltype(a))
  @inbounds @simd for i in eachindex(a, b)
    s += abs2(a[i] - b[i])
  end
  s
end

# ‖v‖ from s = Σ vᵢ² summed in one pass when that sum is finite and at least
# 4 length(v) floatmin(T): each underflowing square then loses less than floatmin(T) u,
# which is below u s / length(v), so the bound γ_{n+4} on the relative error still holds.
# Otherwise the scaled two-pass form is used.
function _se_norm_onepass(::Type{T}, s, v) where {T}
  isfinite(s) && s >= 4 * length(v) * floatmin(T) && return _SE{T}(sqrt(s))
  _se_norm(T, v)
end
function _se_norm_diff_onepass(::Type{T}, s, a, b) where {T}
  isfinite(s) && s >= 4 * length(a) * floatmin(T) && return _SE{T}(sqrt(s))
  _se_norm_diff(T, a, b)
end

# u, the unit roundoff, and γₖ = k u / (1 - k u), which bounds the relative error of k
# rounded operations (k u < 1/8 is checked before a solve, see _check_bound_size).
_unit(::Type{T}) where {T} = eps(T) / 2
_gamma(::Type{T}, k) where {T} = (ku = k * _unit(T); ku / (1 - ku))

# Whether the least-squares bound
#     f(x) ≤ f(y) + ⟨∇f(y), d⟩ + L‖d‖²/2,  d = x - y ≠ 0,   ⟺   √α ‖X d‖ ≤ √L ‖d‖,
# relaxed to √α ‖X d‖ ≤ (1 + 4eps) √L ‖d‖ (legacy's slack 8eps on L), is certified for the
# stored x and y, D being the computed ‖d̂‖ as an _SE. Returns (accepted, used the fresh
# product).
#
# Cheap path: Δz = zw - zu, the difference of the cached images zw ≈ X x and zu ≈ X y, with
# ‖Δz - X d‖ ≤ E = γ_p ‖X‖_F ‖x‖ (zw = fl(X x)) + Ey (the bound on the error of zu, formed
# by the caller). With the evaluation error of the computed norms (γ_{n+4}, γ_{p+4}, u),
# the bound is accepted when it holds with ‖X d‖ replaced by an upper bound, and rejected
# when it fails with a lower bound. Otherwise X d̂ is formed afresh in buf (d̂ = fl(x - y),
# the stored d), whose error γ_p ‖X‖_F ‖d̂‖ plus u ‖X‖_F ‖d‖ is proportional to the step,
# and the trial is accepted only when the bound holds with that upper bound; an ambiguous
# trial is rejected. The margin κ = 32u covers the roundings of the square roots, of the
# loss scale's significand and of the _SE products and sums. All quantities stay in _SE
# form, so the decision is evaluated for any representable data, displacement, L and
# loss scale (rootα is √α taken in the scale's own type).
function _bound_certified!(buf, model::_LSImage, zu, zw, d, D::_SE{T}, L, Ey::_SE{T}, normX::_SE{T},
                           normx::_SE{T}, rootα::_SE{T}, fresh_only::Bool) where {T}
  !iszero(D.s) && L > 0 || return false, false
  n, p = length(zu), length(d)
  u = _unit(T)
  δn, δp, γp = _gamma(T, n + 4), _gamma(T, p + 4), _gamma(T, p)
  κ = 32u
  Dlo = _se_mul(D, _SE{T}(inv((1 + δp) * (1 + u))))        # ≤ ‖d‖
  Dup = _se_mul(D, _SE{T}(inv((1 - δp) * (1 - u))))        # ≥ ‖d‖ and ≥ ‖d̂‖
  rootL = _SE{T}(sqrt(L))
  accept_rhs = _se_mul(_SE{T}((1 + 4eps(T)) / (1 + κ)), rootL, Dlo)
  reject_rhs = _se_mul(_SE{T}((1 + 4eps(T)) * (1 + κ)), rootL, Dup)
  if !fresh_only
    N = _se_norm_diff_onepass(T, _sumsq_diff(zw, zu), zw, zu)
    if N !== nothing
      E = _se_add(_se_mul(_SE{T}(γp), normX, normx), Ey)
      upper = _se_add(_se_mul(N, _SE{T}(inv((1 - δn) * (1 - u)))), E)
      _se_le(_se_mul(rootα, upper), accept_rhs) && return true, false
      lower = _se_sub(_se_mul(N, _SE{T}(inv((1 + δn) * (1 + u)))), E)
      _se_le(_se_mul(rootα, lower), reject_rhs) || return false, false
    end
  end
  mul!(buf, model.X, d)
  W = _se_norm_onepass(T, sum(abs2, buf), buf)
  W === nothing && return false, true
  Ew = _se_mul(_SE{T}(γp + 2u), normX, Dup)
  upper = _se_add(_se_mul(W, _SE{T}(inv(1 - δn))), Ew)
  _se_le(_se_mul(rootα, upper), accept_rhs), true
end

# Error bound of the cached image zu ≈ X y of the current step: a fresh product of
# x_a (first step and after a restart: y = x_a, zu = fl(X x_a)), or the extrapolation
# zu = fl(z_a + ω(z_a - z_b)) of the fresh products z_a = fl(X x_a), z_b = fl(X x_b) with
# y = fl(x_a + ω(x_a - x_b)), 0 < ω < 1. With ‖z‖ ≤ (1 + γ_p)‖X‖_F ‖x‖ and three roundings
# in each combination, (2γ_p + 16u) ‖X‖_F (‖x_a‖ + ‖x_b‖) bounds the error of zu, the
# image error of the rounded y and the roundings of both combinations.
function _image_error_bound(::Type{T}, n, p, normX::_SE{T}, normxa::_SE{T}, normxb::_SE{T},
                            extrapolated::Bool) where {T}
  γp = _gamma(T, p)
  extrapolated || return _se_mul(_SE{T}(γp), normX, normxa)
  _se_mul(_SE{T}(2γp + 16 * _unit(T)), normX, _se_add(normxa, normxb))
end
