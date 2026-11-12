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

# The accelerated method's backtracking test for a trial w from u with displacement
# d = w - u ≠ 0 and scale = max |dᵢ| > 0. For least squares the Taylor remainder at w
# around u is exactly α‖A d‖²/2; comparing it with L‖d‖²/2 avoids subtracting nearly
# equal objectives. zw - zu, the difference of the cached images, approximates A d
# (each is a separately rounded product or extrapolation). Both sides are divided by
# scale², so that their comparison does not depend on whether ‖d‖² underflows or
# overflows in T.
function _majorization_ok(model::_LSImage, zu, zw, fw, L, d, scale)
  isfinite(fw) || return false
  T = typeof(L)
  α = T(model.α)        # validated as representable in T
  step2, image2 = zero(T), zero(T)
  @inbounds @simd for i in eachindex(d)
    step2 += abs2(d[i] / scale)
  end
  @inbounds @simd for i in eachindex(zu, zw)
    image2 += abs2((zw[i] - zu[i]) / scale)
  end
  remainder, bound = α * image2, L * step2
  isfinite(remainder) && isfinite(bound) || return false
  remainder <= bound + 8 * eps(T) * max(remainder, bound) && return true
  # A heuristic allowance for the rounding of the images: an extrapolated and a
  # freshly multiplied image can differ by a few roundings even when the points
  # coincide. It is measured in image units relative to the images' size, so an image
  # displacement inside it passes with any L.
  rounding = 8 * eps(T) * sqrt(α) * max(norm(zu), norm(zw)) / scale
  sqrt(remainder) <= sqrt(bound) + rounding
end
