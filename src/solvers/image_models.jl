####################################
#
#  losses of a linear image, f(x) = F(Ax), in the gradient solvers
#
####################################

# For a loss of a linear image, f(x) = F(Ax), the gradient solvers keep the
# image Ax of their iterates. f and ∇f = AᵀF'(Ax) follow from an image, and the
# image of the extrapolated point of AccProxGradDescent is the same combination
# of the images of the last two iterates. An iteration then costs one product
# with A per trial point and one with Aᵀ, where evaluating f and ∇f at the
# extrapolated point takes another product with A. The image of every iterate is
# a product, so the images do not drift. The values and gradients from an image
# are computed exactly as those of the loss itself. The models: LeastSquaresLoss,
# F(z) = ‖z - Y‖²/2; GLMLoss, F(η) = Σᵢ wᵢ ℓ(ηᵢ + oᵢ, yᵢ); and either Scaled.
# For any other f, `_image_model` is nothing and the solvers evaluate f.

struct _LSImage{TY<:AbstractVecOrMat, TX<:AbstractMatrix, A<:Real, T<:AbstractFloat}
  Y::TY
  X::TX
  α::A                  # the scale of a Scaled loss, one otherwise
end

struct _GLMImage{F<:GLMLoss, A<:Real, T<:AbstractFloat}
  f::F
  α::A
end

_LSImage(f::LeastSquaresLoss{T}, α::Real) where {T} = _LSImage{typeof(f.Y), typeof(f.X), typeof(α), T}(f.Y, f.X, α)
_GLMImage(f::GLMLoss{L, T}, α::Real) where {L, T} = _GLMImage{typeof(f), typeof(α), T}(f, α)

_image_model(f) = nothing
_image_model(f::LeastSquaresLoss) = _LSImage(f, true)
_image_model(f::Scaled{<:LeastSquaresLoss}) = _LSImage(f.f, f.α)
_image_model(f::GLMLoss) = _GLMImage(f, true)
_image_model(f::Scaled{<:GLMLoss}) = _GLMImage(f.f, f.α)

# a buffer for an image, or for F' at an image
_image_buffer(m::_LSImage{TY, TX, A, T}) where {TY, TX, A, T} = zeros(T, size(m.Y))
_image_buffer(m::_GLMImage{F, A, T}) where {F, A, T} = zeros(T, length(m.f.y))

# z = Ax
_image!(z, m::_LSImage, x) = mul!(z, m.X, x)
_image!(z, m::_GLMImage, x) = mul!(z, m.f.X, x)

# F(z), as the loss computes f(x) from z = Ax
function _image_value(m::_LSImage{TY, TX, A, T}, z) where {TY, TX, A, T}
  Y = m.Y
  v = zero(T)
  @inbounds @simd for i in eachindex(z, Y)
    v += abs2(Y[i] - z[i])
  end
  m.α * (v / 2)
end

function _image_value(m::_GLMImage{F, A, T}, z) where {F, A, T}
  f = m.f
  w, o = f.weights, f.offset
  s = zero(T)
  @inbounds for i in eachindex(z)
    η = o === nothing ? z[i] : z[i] + o[i]
    wᵢ = w === nothing ? one(T) : convert(T, w[i])
    iszero(wᵢ) && continue
    s += wᵢ * convert(T, f.loss(η, f.y[i]))
  end
  m.α * s
end

# F(z) and G = AᵀF'(z), with d a buffer for F'(z)
function _image_value_and_gradient!(G, m::_LSImage, z, d)
  d .= z .- m.Y
  mul!(G, transpose(m.X), d)
  v = sum(abs2, d) / 2
  G .*= m.α
  m.α * v
end

function _image_value_and_gradient!(G, m::_GLMImage{F, A, T}, z, d) where {F, A, T}
  f = m.f
  w, o = f.weights, f.offset
  s = zero(T)
  @inbounds for i in eachindex(z)
    η = o === nothing ? z[i] : z[i] + o[i]
    wᵢ = w === nothing ? one(T) : convert(T, w[i])
    if iszero(wᵢ)
      d[i] = zero(T)
      continue
    end
    v, dv = ProximalBase.value_and_deriv(f.loss, η, f.y[i])
    s += wᵢ * convert(T, v)
    d[i] = wᵢ * dv
  end
  mul!(G, transpose(f.X), d)
  G .*= m.α
  m.α * s
end

# f(x), which with a model also computes the image z of x
_value!(f, x, ::Nothing, z) = f(x)
_value!(f, x, m, z) = (_image!(z, m, x); _image_value(m, z))

# f(x) and ∇f(x) into G, from the image z of x when f has a model; d is a buffer
_value_and_gradient!(G, f, x, ::Nothing, z, d) = value_and_gradient!(G, f, x)
_value_and_gradient!(G, f, x, m, z, d) = _image_value_and_gradient!(G, m, z, d)

_majorization_ok(model, zu, zw, fu, fw, upper, L, stepnorm2) =
  isfinite(fw) && fw <= upper + 10 * eps(typeof(L)) * max(abs(fu), one(L))

# For least squares the Taylor remainder is exactly α*norm(A(w-u))²/2.
# Comparing it with L*norm(w-u)²/2 avoids subtracting nearly equal objectives.
# The existing image buffers supply the difference without another product.
function _majorization_ok(model::_LSImage, zu, zw, fu, fw, upper, L, stepnorm2)
  isfinite(fw) || return false
  image_step2 = zero(eltype(zw))
  @inbounds @simd for i in eachindex(zu, zw)
    image_step2 += abs2(zw[i] - zu[i])
  end
  remainder, bound = model.α * image_step2, L * stepnorm2
  isfinite(remainder) && isfinite(bound) || return false
  remainder <= bound + 8 * eps(typeof(L)) * max(remainder, bound) && return true
  # Extrapolated and freshly multiplied images can differ by a few roundings,
  # even when the points coincide. Account for that error in image units,
  # rather than adding an objective-scale slack that masks a bad curvature.
  rounding = 8 * eps(typeof(L)) * sqrt(abs(model.α)) * max(norm(zu), norm(zw))
  sqrt(remainder) <= sqrt(bound) + rounding
end
