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

# The accelerated method's backtracking test for a trial w = u + d with d ≠ 0. For least
# squares the Taylor remainder at w around u is exactly α‖A d‖²/2, so the bound
# f(w) ≤ f(u) + ⟨∇f(u), d⟩ + L‖d‖²/2 holds iff √α ‖A d‖ ≤ √L ‖d‖. The test compares
# these norms, never their squares, so that it is evaluated over the whole range in
# which √α‖A d‖/‖d‖ (the square root of the curvature along d) is representable:
#
#   accept  ⟺  √α (‖Δz‖ - a) ≤ (1 + 4eps) √L ‖d‖,   Δz = zw - zu,  a = 8eps max(‖zu‖, ‖zw‖).
#
# Δz, the difference of the cached images zw ≈ A w and zu ≈ A u, approximates A d. Both
# norms use the scaled two-pass form ‖v‖ = m √s with m = max|vᵢ| and s = Σ(vᵢ/m)² ∈ [1, n],
# so no square leaves the range of T; the products of both sides are compared through
# their significands and binary exponents (_product_le), so neither side, nor a ratio
# of the scale factors, is formed. 1 + 4eps is legacy's relative slack 8eps on the
# squared bound, √(1 + 8eps). The allowance a, legacy's, absorbs a difference between
# an extrapolated and a freshly multiplied image of up to 8 roundings of the image
# norm: with Δz in place of A d, an accepted trial satisfies the bound up to about a
# relative 8eps on L and an additive 8eps √(αL) ‖d‖ max‖z‖ + 32α(eps max‖z‖)² on the
# remainder, besides the evaluation error of the norms; the rounding error of the
# cached images themselves adds to that (see the implementation notes). A nonfinite value, displacement or image norm, or
# L = 0 with a nonzero image difference, is never accepted; a nonfinite allowance
# counts as none.
function _majorization_ok(model::_LSImage, zu, zw, fw, L, d, md)
  T = typeof(L)
  isfinite(fw) && isfinite(md) && md > 0 || return false
  sd = _sumsq_scaled(d, md)
  mz = _maxabs_diff(zw, zu)
  isfinite(sd) && isfinite(mz) || return false
  iszero(mz) && return true
  image = mz * sqrt(_sumsq_scaled_diff(zw, zu, mz))
  isfinite(image) || return false
  L > 0 || return false
  α = T(model.α)        # validated as positive and representable in T
  bound = (one(T) + 4 * eps(T), sqrt(L), md, sqrt(sd))
  _product_le((sqrt(α), image), bound) && return true
  # Only when the plain comparison fails, as in legacy: the allowance can only widen
  # acceptance, so the decision equals that of the single inequality above.
  allowance = 8 * eps(T) * max(norm(zu), norm(zw))
  isfinite(allowance) || return false      # no allowance
  excess = image - allowance
  excess <= 0 || _product_le((sqrt(α), excess), bound)
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

# Whether the product of the finite positive floats as is at most that of bs. Each product
# is carried as a significand in [1, 2) and an integer binary exponent, so no partial
# product overflows or underflows; the significand products round, as ordinary
# multiplication would.
function _product_le(as, bs)
  sa, ea = _significand_exponent(as)
  sb, eb = _significand_exponent(bs)
  ea < eb || (ea == eb && sa <= sb)
end

function _significand_exponent(xs)
  s, e = one(first(xs)), 0
  for x in xs
    p = s * significand(x)       # in [1, 4)
    s, e = significand(p), e + exponent(x) + exponent(p)
  end
  s, e
end
