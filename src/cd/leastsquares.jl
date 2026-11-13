using ProximalBase: shrink
# Borrowed scalar unweighted LS data and native residual/curvature caches. The loss scale `s`
# has its own type `S`: the promotion of `T` and the type of the supplied scale where that is a
# concrete `AbstractFloat` (an IEEE scale wider than `T` keeps its precision), else `T`. X, y,
# the residual and the curvature cache are in `T`, and so are the loops over them (the column
# sums, the residual update, the sum in `loss_value` and the sum in the first two forms of
# `response_scale`).
mutable struct LSModel{T<:AbstractFloat, S<:AbstractFloat, MX<:AbstractMatrix{T}, VY<:AbstractVector{T}} <: CDModel{T}
  X::MX
  y::VY
  s::S
  r::Vector{T}
  a::Vector{T}
end
function _scale_type(::Type{T}, α) where T
  S = promote_type(T, typeof(α))
  isconcretetype(S) && S <: AbstractFloat ? S : T
end
LSModel(y::AbstractVector{T}, X::AbstractMatrix{T}, α::Real) where T =
  LSModel(X, y, convert(_scale_type(T, α), α), zeros(T, length(y)), fill(T(NaN), size(X, 2)))
cdmodel(f::LeastSquaresLoss{T, <:AbstractVector}, x) where T = LSModel(f.Y, f.X, one(T))
cdmodel(f::Scaled{<:LeastSquaresLoss{T, <:AbstractVector}}, x) where T = LSModel(f.f.Y, f.f.X, f.α)
_activeentries(x::SparseIterate) = activecoordinates(x)
initialize!(m::LSModel{T}, x::SparseIterate{T}) where T = _initialize!(m, x, true)
function _initialize!(m::LSModel{T}, x::SparseIterate{T}, fresh::Bool) where T
  length(x)==size(m.X,2) || throw(DimensionMismatch("iterate length differs from X columns"))
  copyto!(m.r, m.y)
  for k in _activeentries(x)
    v = x[k]
    iszero(v) && continue
    _residual_axpy!(m, k, v)
  end
  fill!(m.a, T(NaN))
  m
end
@inline function _column_dot(X::AbstractMatrix{T}, r::AbstractVector{T}, k::Int, a::T) where T
  b = zero(T)
  if isnan(a)
    a = zero(T)
    @inbounds @simd for i in eachindex(r)
      a += X[i, k]*X[i, k]
      b += r[i]*X[i, k]
    end
  else
    @inbounds @simd for i in eachindex(r)
      b += r[i]*X[i, k]
    end
  end
  a, b
end
@inline _column_dot(m::LSModel, k::Int) = _column_dot(m.X, m.r, k, m.a[k])
@inline function _residual_axpy!(m::LSModel{T}, k::Int, h::T) where T
  r, X = m.r, m.X
  @inbounds @simd for i in eachindex(r)
    r[i] -= X[i, k]*h
  end
  r
end
function _sqnorm!(m::LSModel{T}, k::Int) where T
  a = m.a[k]
  if isnan(a)
    a = zero(T)
    @inbounds for i in axes(m.X, 1)
      a += m.X[i, k]*m.X[i, k]
    end
    m.a[k] = a
  end
  a
end
function _flat_column(m::LSModel{T}, k::Int) where T
  for i in axes(m.X, 1)
    m.X[i, k] == zero(T) || return false
  end
  true
end
# The coordinate step. With a = ‖X_k‖², b = rᵀX_k and the centre c = old + b/a, the step is the soft
# threshold of c at τ = λ/(m.s a). A flat column (a = 0 and X_k = 0) takes the penalty's minimizer. A
# curvature a that is 0 for a column that is not flat (its squares underflow), or that is not finite, is
# refused before the coordinate or the residual changes. For a finite a, p = m.s a is formed in `S` and
# γ = 1/p. Where p and γ are both at least floatmin(S), the step is `prox_block(g, c, k, γ)`, whose NormL1
# prox forms the threshold γλ in its own working type. Where one of them is smaller (or NaN, which a
# non-finite a gives), `_outside_band` takes over: γ is not a usable coefficient there, as it is 0 where p
# overflows, Inf where p is below 1/floatmax(S), and has fewer significant bits where p or γ is
# subnormal, and the threshold γλ would be 0 or Inf, or inexact, in place of τ. `_exceptional_step`
# forms τ without p or γ. In exact arithmetic a fixed point of x = shrink(x + b/a′, λ/(m.s a′))
# satisfies m.s b ∈ λ ∂|x| for any positive a′ used in both places, so a rounded or subnormal curvature,
# within a factor of 2 of the exact one, changes the convergence rate and not the fixed point.
@inline function coordinate_step!(m::LSModel{T}, g, x::SparseIterate{T}, k::Int) where {T}
  a, b = _column_dot(m, k)
  iszero(a) && !_flat_column(m, k) &&
    throw(ArgumentError("the coordinate curvature underflows; rescale the data or loss"))
  old = x[k]
  new = iszero(a) ? _coordinate_minimizer(g, old, k) : _scaled_prox(m, g, old + b / a, k, a)
  m.a[k] = a
  h = new - old
  iszero(h) && return h      # x and the residuals do not change
  x[k] = new
  _residual_axpy!(m, k, h)
  h
end
@inline function _scaled_prox(m::LSModel{T}, g, c::T, k::Int, a::T) where T
  p = m.s * a
  γ = inv(p)
  S = typeof(p)
  (floatmin(S) <= p) & (floatmin(S) <= γ) ? prox_block(g, c, k, γ) : _outside_band(m, g, c, k, a)
end
# Out of line, with the refusal of a curvature that is not finite: p = m.s a is Inf or NaN for it.
@noinline function _outside_band(m::LSModel{T}, g, c::T, k::Int, a::T) where T
  isfinite(a) || _refuse_curvature(T, k)
  _exceptional_step(g, c, m.s, a, k)
end
# The throws are out of line, so that the step carries no string interpolation.
@noinline _refuse_curvature(::Type{T}, k::Int) where T =
  throw(ArgumentError("the curvature of coordinate $k (the squared norm of its column) is not finite in $T; rescale the data"))
# The soft threshold of c at τ = λ/(α a) for a finite positive α and a, formed without the product α a
# or its reciprocal and capped at floatmax(T). At a finite c the cap leaves the result 0 that a larger τ
# gives; at a c that is infinite or NaN it keeps that non-finite value, which `_visit!` refuses, where an
# infinite level passed to PB's NormL1 prox would fix the entry at 0 instead. For τ in [0, floatmax(T)]
# `shrink(c, τ)` is what that prox returns at the level τ and the step 1.
# This method is for S == T ∈ {Float32, Float64}. For a finite a, an `S` wider than `T` keeps p = α a
# in the band of the fast path: α is representable in T (`solve!` checks it) and a is finite in T, so
# p lies between about 1e-90 and 1e77 for S = Float64 on Float32 data and inside the far wider range of
# BigFloat. Another scale type, or a penalty other than the unweighted NormL1, is refused.
@noinline function _exceptional_step(g::NormL1{<:Real, Nothing}, c::T, α::T, a::T, k::Int) where {T<:Union{Float32, Float64}}
  shrink(c, min(_threshold(T, g.λ0, α, a), floatmax(T)))
end
@noinline _exceptional_step(g, c, α, a, k::Int) =
  throw(ArgumentError("the coordinate step of coordinate $k has no range-safe form for a $(typeof(g)) penalty and a loss scale of type $(typeof(α))"))
# τ = λ/(α a) with λ the penalty level converted to Float64. Float32: α and a are Float32, so their
# product is exact in Float64 (24 + 24 ≤ 53 bits, inside its range), and the quotient is rounded to
# Float64 and then to Float32; for a Float32 level that equals the correctly rounded quotient, as
# 53 ≥ 2·24 + 2. Float64: significands and exponents are separated, mλ/(mα ma) 2^(eλ - eα - ea); the
# relative error is below 3 eps(Float64) where τ is normal, and a subnormal τ is formed by `ldexp` (the
# tests allow an error of nextfloat(0.0) there). τ is 0 for λ = 0.
_threshold(::Type{Float32}, λ, α::Float32, a::Float32) = Float32(Float64(λ) / (Float64(α) * Float64(a)))
function _threshold(::Type{Float64}, λ, α::Float64, a::Float64)
  mλ, eλ = frexp(Float64(λ))
  mα, eα = frexp(α)
  ma, ea = frexp(a)
  ldexp(mλ / (mα * ma), eλ - eα - ea)
end

_cache(m::LSModel) = m.r
# The stopping scales form the product `p` of the loss scale with a sum of squares in `S`.
# A zero response scale selects the absolute fallback of `_tolerances`. Where relative scaling is
# active (`relative=true` and a positive response scale, `scaled` in `_tolerances`), a zero
# coordinate scale makes that coordinate's change count as 0 in `_visit!`, and an infinite one makes
# a nonzero change infinite, which `_visit!` refuses. Otherwise `_visit!` does not use the
# coordinate scale.
# Response scale √(m.s Σy²): the sum Σy² is formed in `T` and is clean when it is finite and at
# least 4 length(y) floatmin(T), where the squares that underflow change it by less than u/4
# relative (u = eps(T)/2, the bound of `_se_norm_onepass`). With p = m.s Σy² in `S` and q = T(p),
# the scale is
#   1. sqrt(q), if the sum is clean and q is a normal number of `T`;
#   2. T(sqrt(p)), if `S` is wider than `T`, the sum is clean, p is a normal number of `S` and the
#      rounded root is a normal number of `T`;
#   3. otherwise the exponent-separated value of `_response_scale_exceptional`.
# Coordinate scale √(m.s a), with a the curvature of column k, p = m.s a in `S` and q = T(p):
#   1. sqrt(q), if q is a normal number of `T`;
#   2. otherwise T(sqrt(p)), if p is not below floatmin(S) and is finite or a is infinite. This is Inf
#      for an infinite a, and for `S` wider than `T` where the root of p is above floatmax(T);
#   3. otherwise (p is zero or subnormal in `S`, or p is Inf for a finite a) T(sqrt(m.s) sqrt(S(a))),
#      formed in `S`: each root is taken before the two are multiplied, so the result does not depend
#      on the rounded product p. It is 0 for a = 0 (a column of zero curvature), and 0 where it is at
#      most half the smallest subnormal of `T`; a value above floatmax(T) rounds to Inf.
# Where relative scaling is active, `_visit!` refuses a nonzero change times an infinite scale.
# For `S == T` the first two expressions have the same value where p is normal. The step does not
# form this scale (see `coordinate_step!`).
function coordinate_scale(m::LSModel{T}, x, k::Int) where T
  a = _sqnorm!(m, k)
  p = m.s*a
  q = T(p)
  floatmin(T) <= q <= floatmax(T) && return sqrt(q)
  S = typeof(p)
  (p < floatmin(S) || isinf(p) && isfinite(a)) && return T(sqrt(m.s)*sqrt(S(a)))
  T(sqrt(p))
end
function response_scale(m::LSModel{T}, x) where T
  s = zero(T)
  @inbounds for i in eachindex(m.y)
    s += m.y[i]*m.y[i]
  end
  p = m.s*s
  q = T(p)
  if isfinite(s) && s >= 4*length(m.y)*floatmin(T)
    floatmin(T) <= q <= floatmax(T) && return sqrt(q)
    S = typeof(p)
    if S !== T && floatmin(S) <= p <= floatmax(S)
      r = T(sqrt(p))
      floatmin(T) <= r <= floatmax(T) && return r
    end
  end
  _response_scale_exceptional(m)
end
# √(m.s) ‖y‖ with the root of m.s and the norm of y carried as `_SE` (a significand and an Int
# exponent, from solvers/image_models.jl: `_se_norm`, `_root_scale`, `_se_mul`), in Float64 for
# Float32 data and in `T` otherwise, so that the exponent of the result is not limited by the range
# of `T`; the result is rounded once to `T`. It is 0 for y = 0 and for m.s = 0, which `_tolerances`
# turns into the absolute fallback, and a result that is not a normal number of `T` is refused.
# The sum of squares in `_se_norm` is `@simd`, so the value can differ in the last bits between CPUs.
function _response_scale_exceptional(m::LSModel{T}) where T
  iszero(m.s) && return zero(T)
  W = T === Float32 ? Float64 : T
  ny = _se_norm(W, m.y)
  ny === nothing && _refuse_response_scale(T, false)
  _se_scale(T, _se_mul(_root_scale(W, m.s), ny))
end
function _se_scale(::Type{T}, r::_SE) where T
  iszero(r.s) && return zero(T)
  v = T(ldexp(r.s, r.e))
  floatmin(T) <= v <= floatmax(T) || _refuse_response_scale(T, true)
  v
end
# The throw is out of line, so that `response_scale` carries no string interpolation.
@noinline function _refuse_response_scale(::Type{T}, finite_y::Bool) where T
  finite_y || throw(ArgumentError("the response scale is not defined: y has a non-finite entry"))
  throw(ArgumentError("the response scale (the root of the loss scale times the norm of y) is not a normal number of $T; rescale y or the loss scale, or use relative=false (an objective that overflows is still refused)"))
end
function loss_value(m::LSModel{T}, x) where T
  v = zero(T)
  @inbounds @simd for i in eachindex(m.r)
    v += m.r[i]*m.r[i]
  end
  T(m.s*v/2)
end
