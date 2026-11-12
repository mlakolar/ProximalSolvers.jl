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

# The accelerated method's backtracking test. For least squares the Taylor remainder at
# w around u is exactly α‖A(w - u)‖²/2; comparing it with L‖w - u‖²/2 avoids
# subtracting nearly equal objectives, and the image buffers zu = A u and zw = A w
# supply A(w - u) without another product.
function _majorization_ok(model::_LSImage, zu, zw, fw, L, stepnorm2)
  isfinite(fw) || return false
  image_step2 = zero(eltype(zw))
  @inbounds @simd for i in eachindex(zu, zw)
    image_step2 += abs2(zw[i] - zu[i])
  end
  T = typeof(L)
  α = T(model.α)        # validated as representable in T
  remainder, bound = α * image_step2, L * stepnorm2
  isfinite(remainder) && isfinite(bound) || return false
  remainder <= bound + 8 * eps(T) * max(remainder, bound) && return true
  # An extrapolated and a freshly multiplied image can differ by a few roundings even
  # when the points coincide. Account for that error in image units, rather than with
  # an objective-scale slack that would mask a curvature estimate that is too small.
  rounding = 8 * eps(T) * sqrt(α) * max(norm(zu), norm(zw))
  sqrt(remainder) <= sqrt(bound) + rounding
end
