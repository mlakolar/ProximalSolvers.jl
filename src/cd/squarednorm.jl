# Coordinate descent for (α/2)‖b - s‖² + λ‖b‖₁, the centered squared norm of ProximalBase's SqrNormL2 with
# an unweighted NormL1. The coordinates are independent: the model keeps the centre s (borrowed) and the
# level α, with no residual, design or per-column cache, so a visit costs O(1) and a pass O(p). It is the
# least-squares model with X the identity, whose column curvature is 1 and whose residual entry k is
# s[k] - x[k], so the centre of a visit is s[k]. The step, the stopping scales and the refusals follow
# `LSModel` (src/cd/leastsquares.jl). The level α has the type `S` of `_scale_type`, as the scale of `LSModel`.
struct SquareModel{T<:AbstractFloat, S<:AbstractFloat} <: CDModel{T}
  s::Vector{T}      # the centre, borrowed
  α::S              # the level of the loss
  rootα::T          # the coordinate scale, see `coordinate_scale`
end

function cdmodel(f::SqrNormL2{<:Real, Vector{T}}, x) where T
  α = convert(_scale_type(T, f.λ), f.λ)
  q = T(α)
  SquareModel(f.y, α, floatmin(T) <= q ? sqrt(q) : T(sqrt(α)))
end

# The model holds no state that depends on x.
function initialize!(m::SquareModel, x::SparseIterate)
  length(x) == length(m.s) || throw(DimensionMismatch("iterate length differs from the centre length"))
  m
end

# The loss value from ProximalBase's SqrNormL2 oracle at the iterate.
loss_value(m::SquareModel, f, x) = f(x)

# The coordinate step is the minimizer over b_k of (α/2)(b_k - s_k)² + λ|b_k|: the soft threshold of s_k at
# λ/α. With p = α in the type S and γ = 1/p, it is `prox_block(g, s_k, k, γ)` where p and γ are both at least
# floatmin(S) (the band of `LSModel`'s `_scaled_prox` with the column curvature 1), and `_exceptional_step`
# outside it, where γ is not usable as a step. `solve!` requires α to convert to T without overflow or
# underflow to 0, so an S wider than T stays in the band, and the exceptional step is reached only for
# S == T, as for `LSModel`.
@inline function coordinate_step!(m::SquareModel{T}, g, x::SparseIterate{T}, k::Int) where {T}
  old = x[k]
  c = @inbounds m.s[k]
  γ = inv(m.α)
  S = typeof(γ)
  new = (floatmin(S) <= m.α) & (floatmin(S) <= γ) ? prox_block(g, c, k, γ) :
        _exceptional_step(g, c, m.α, one(T), k)
  h = new - old
  iszero(h) && return h      # x does not change
  x[k] = new
  h
end

# The coordinate scale is the root of the level, as `LSModel`'s `_curvature_scale` forms it with the column
# curvature 1: sqrt(T(α)) where T(α) is a normal number of T, and T(√α) otherwise (α subnormal in T).
coordinate_scale(m::SquareModel, x, k::Int) = m.rootα

# The response scale √α ‖s‖, under the rules of `LSModel`'s `response_scale` with s in place of y: with the
# sum of squares in T, p = α Σ sᵢ² in S and q = T(p), it is sqrt(q) where the sum is finite and at least
# 4 length(s) floatmin(T) and q is a normal number of T; T(√p) where that holds for S wider than T, p is in
# the range of S and the rounded root is a normal number of T; otherwise the exponent-separated value
# from `_se_norm` and `_root_scale`, which is 0 for s = 0 (`_tolerances` then uses the absolute tolerance)
# and is refused by `_refuse_response_scale` where it is not a normal number of T.
function response_scale(m::SquareModel{T}, x) where T
  sq = zero(T)
  @inbounds for i in eachindex(m.s)
    sq += m.s[i]*m.s[i]
  end
  p = m.α*sq
  q = T(p)
  if isfinite(sq) && sq >= 4*length(m.s)*floatmin(T)
    floatmin(T) <= q <= floatmax(T) && return sqrt(q)
    S = typeof(p)
    if S !== T && floatmin(S) <= p <= floatmax(S)
      r = T(sqrt(p))
      floatmin(T) <= r <= floatmax(T) && return r
    end
  end
  W = T === Float32 ? Float64 : T
  ns = _se_norm(W, m.s)
  ns === nothing && _refuse_response_scale(T, false)
  _se_scale(T, _se_mul(_root_scale(W, m.α), ns))
end
