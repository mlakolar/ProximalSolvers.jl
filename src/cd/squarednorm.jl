# Direct model for a centered squared Euclidean norm with an unweighted L1 penalty.
# Every coordinate is independent; no identity design, residual vector or matrix
# product is needed. It uses the existing CD pass, stopping and commit machinery.
struct SquareModel{T<:AbstractFloat, S<:AbstractFloat, V<:Vector{T}} <: CDModel{T}
  y::V
  s::S
end

function cdmodel(f::SqrNormL2, x)
  y = f.y                              # validated by _check_data
  S = _scale_type(eltype(x), f.λ)
  SquareModel(y, convert(S, f.λ))
end

initialize!(m::SquareModel, x::SparseIterate) = m
loss_value(m::SquareModel, f::SqrNormL2, x) = f(x)

# The curvature of each coordinate is s, with the same loss and penalty
# normalization as the full objective (s/2)||x-y||² + λ||x||₁.
function coordinate_step!(m::SquareModel{T}, g, x::SparseIterate{T}, k::Int) where T
  old = x[k]
  γ = inv(m.s)
  S = typeof(m.s)
  new = (floatmin(S) <= m.s) & (floatmin(S) <= γ) ?
    prox_block(g, m.y[k], k, γ) :
    _exceptional_step(g, m.y[k], m.s, one(T), k)
  h = new - old
  isfinite(new) && isfinite(h) ||
    throw(ArgumentError("a coordinate step is not finite"))
  iszero(h) || (x[k] = new)
  h
end

# Keep the existing CD relative-change convention: sqrt(s)||y|| on the
# response and sqrt(s) on each coordinate, without introducing another
# squared-norm accumulator or a dense identity matrix.
function response_scale(m::SquareModel{T}, x) where T
  W = T === Float32 ? Float64 : T
  ny = _se_norm(W, m.y)
  ny === nothing && _refuse_response_scale(T, false)
  _se_scale(T, _se_mul(_root_scale(W, m.s), ny))
end
coordinate_scale(m::SquareModel{T}, x, k::Int) where T = T(sqrt(m.s))
