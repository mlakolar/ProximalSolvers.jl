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
