using ProximalBase: shrink, leastsquares_data, value_from_residual
# Borrowed scalar unweighted LS data and native residual/curvature caches. The loss scale `s`
# has its own type `S`: the promotion of `T` and the type of the supplied scale where that is a
# concrete `AbstractFloat` (an IEEE scale wider than `T` keeps its precision), else `T`. X, y,
# the residual and the curvature cache are in `T`, and so are the loops over them (the column
# sums, the residual update and the sum in the first two forms of `response_scale`). The loss
# value is not formed here: `loss_value` takes it from ProximalBase.
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
function cdmodel(f::Union{LeastSquaresLoss{T, <:AbstractVector}, Scaled{<:LeastSquaresLoss{T, <:AbstractVector}}}, x) where T
  d = leastsquares_data(f)
  LSModel(d.Y, d.X, d.α)
end
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
# prox forms the threshold γλ in its own working type. Where one of them is smaller, `_outside_band`
# takes over. There γ is not a usable coefficient at a positive penalty: it is 0 where p overflows (the
# threshold γλ is 0 and the penalty is ignored), Inf where p is below 1/floatmax(S) (the threshold is
# Inf, which sets a finite centre to 0), and has fewer significant bits where p or γ is subnormal. At
# λ = 0 the prox keeps a zero threshold for any γ. `_exceptional_step` forms τ without p or γ. A
# curvature a that is not finite gives p = Inf and γ = 0 for a positive finite scale, so it leaves the
# band and is refused in `_outside_band`. In exact arithmetic a fixed point of
# x = shrink(x + b/a′, λ/(m.s a′)) satisfies m.s b ∈ λ ∂|x| for any positive a′ used in both places, so
# a rounded or subnormal curvature does not move the fixed point (whether and how fast the iteration
# reaches it can change).
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
# Out of line, with the refusal of a curvature that is not finite: p = m.s a is Inf and γ = 0 for it.
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
# p lies between about 1e-90 and 1e77 for S = Float64 on Float32 data. Another scale type (`solve!` refuses
# one that is not Float32, Float64 or an integer; an LSModel built directly can have S = BigFloat), or a
# penalty other than the unweighted NormL1, is refused.
@noinline function _exceptional_step(g::NormL1{<:Real, Nothing}, c::T, α::T, a::T, k::Int) where {T<:Union{Float32, Float64}}
  shrink(c, min(_threshold(T, g.λ0, α, a), floatmax(T)))
end
@noinline _exceptional_step(g, c, α, a, k::Int) =
  throw(ArgumentError("the coordinate step of coordinate $k has no range-safe form for a $(typeof(g)) penalty and a loss scale of type $(typeof(α))"))
# τ = λ/(α a) with λ the penalty level converted to Float64. Float32: α and a are Float32, so their
# product is exact in Float64 (24 + 24 ≤ 53 bits, inside its range), and the quotient is rounded to
# Float64 and then to Float32. That double rounding keeps the result within one Float32 ulp of the exact
# quotient where the quotient is below floatmax, and the result is not always the correctly rounded
# one. Float64: significands and exponents are separated, mλ/(mα ma) 2^(eλ - eα - ea); the
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
#      for an infinite a, and for `S` wider than `T` where the rounded root of p overflows `T`;
#   3. otherwise (p is zero or subnormal in `S`, or p is Inf for a finite a) T(sqrt(m.s) sqrt(S(a))),
#      formed in `S`: each root is taken before the two are multiplied, so the result does not depend
#      on the rounded product p. It is 0 for a = 0 (a column of zero curvature), and 0 where it is at
#      most half the smallest subnormal of `T`; rounding to `T` gives Inf where the value overflows.
# Where relative scaling is active, `_visit!` refuses a nonzero change times an infinite scale.
# For `S == T` the first two expressions have the same value where p is normal. The step does not
# form this scale (see `coordinate_step!`).
coordinate_scale(m::LSModel, x, k::Int) = _curvature_scale(m, _sqnorm!(m, k))
# The scale for the curvature a, which `coordinate_scale` takes from the column cache and the block model
# from the group curvature.
@inline function _curvature_scale(m::LSModel{T}, a::T) where T
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
# The loss value at the current residual, from ProximalBase's residual oracle with the original loss f.
loss_value(m::LSModel, f, x) = value_from_residual(f, m.r)

# Block least squares: the group-lasso step on a BlockIterate. The LSModel `ls` supplies the data, the
# residual and the column kernels. `ℓ[k]` is the unscaled curvature bound of group k, a number with
# ℓ[k] ≥ λmax(X_kᵀX_k) of the stored data after rounding (for a group of two or more columns, under
# the eigensolver model of `_gram_curvature`); the loss scale s is applied where the step is formed.
# It is 0 for a flat group, where all entries of X_k are 0, and NaN while it is not computed: before
# `_prepare!` has run, and for a group of the Gram route whose curvature `_prepare!` left to the first
# visit that needs it (`_curvature_deferrable`, `coordinate_step!`). `old`, `u` and `b` are scratch
# vectors as long as the largest group (`b` holds the correlations rᵀX_k of the visit). `Bbuf` and
# `Gbuf` are the Float64 buffers of `_gram_curvature`, empty until a curvature of the Gram route is
# computed. The model has no `_cache`, so momentum stays off.
mutable struct BlockLSModel{T<:AbstractFloat, S<:AbstractFloat, M<:LSModel{T, S}} <: CDModel{T}
  ls::M
  ℓ::Vector{T}
  old::Vector{T}
  u::Vector{T}
  b::Vector{T}
  Bbuf::Matrix{Float64}
  Gbuf::Matrix{Float64}
end
function cdmodel(f::Union{LeastSquaresLoss{T, <:AbstractVector}, Scaled{<:LeastSquaresLoss{T, <:AbstractVector}}}, x::BlockIterate{T}) where T
  d = leastsquares_data(f)
  ls = LSModel(d.Y, d.X, d.α)
  K = ncoordinates(x)
  mmax = maximum(length(blockindices(x, k)) for k in 1:K)
  BlockLSModel{T, typeof(ls.s), typeof(ls)}(ls, fill(T(NaN), K), Vector{T}(undef, mmax), Vector{T}(undef, mmax),
    Vector{T}(undef, mmax), Matrix{Float64}(undef, 0, 0), Matrix{Float64}(undef, 0, 0))
end
# r = y − Σ X[:, j] x[j] over the entries j of the active groups (entry indices, not group numbers).
function initialize!(m::BlockLSModel{T}, x::BlockIterate{T}) where T
  ls = m.ls
  length(x)==size(ls.X, 2) || throw(DimensionMismatch("iterate length differs from X columns"))
  copyto!(ls.r, ls.y)
  for k in activecoordinates(x)
    for j in blockindices(x, k)
      v = x[j]
      iszero(v) || _residual_axpy!(ls, Int(j), v)
    end
  end
  fill!(ls.a, T(NaN))
  m
end
response_scale(m::BlockLSModel, x) = response_scale(m.ls, x)
loss_value(m::BlockLSModel, f, x) = loss_value(m.ls, f, x)
# The stopping scale of group k is √(s ℓ[k]), through the range-safe formula of `coordinate_scale`. It
# is 0 for a flat group. `_visit!` takes it after a nonzero change; `coordinate_step!` returns a nonzero
# value from the full step, after ℓ[k] has been computed (a flat group has ℓ[k] = 0), so ℓ[k] is not
# NaN there.
coordinate_scale(m::BlockLSModel, x, k::Int) = _curvature_scale(m.ls, m.ℓ[k])

# Per-solve preparation, before the first pass and the first random draw. A group whose columns are all
# 0 has ℓ = 0 and no band. A group of one column takes the sum of squares of the column (`_sqnorm!`, in
# T, without `@simd`) with the rounding margin of `_singleton_curvature`, and the band check, at once;
# the same for a singleton with n eps(T) > 1/8 (n rows) below, which takes the Gram route. A group of
# the Gram route (two or more columns, or that singleton) is left with ℓ = NaN where
# `_curvature_deferrable` decides from cheap bounds that neither `_gram_curvature` nor the band check
# can refuse it; its curvature is then computed at the first visit that needs it (`coordinate_step!`).
# Otherwise it is computed and checked here, so the refusals of `_gram_curvature` and of the band check
# for that group are made here, before the first pass. A refusal names the group; `_prepare!` changes
# neither the coordinates nor the residual. The block path refuses a curvature below floatmin(T), which
# the scalar path accepts as a subnormal value. `_sqnorm!` sums in order, while the scalar step takes the
# sum from `_column_dot`, which `@simd` reassociates, so the two can differ by rounding, and the block
# curvature of a singleton is larger than the scalar one by about its margin.
function _prepare!(m::BlockLSModel{T}, g::GroupNormL2, x::BlockIterate{T}) where T
  ls = m.ls
  n = size(ls.X, 1)
  for k in 1:ncoordinates(x)
    idx = blockindices(x, k)
    if _flat_group(ls, idx)
      m.ℓ[k] = zero(T)
    elseif length(idx) == 1 && n*eps(T) <= 1/8
      ℓ = _singleton_curvature(ls, Int(idx[1]), k)
      _check_step_band(ls, ℓ, k)
      m.ℓ[k] = ℓ
    elseif _curvature_deferrable(ls, idx)
      m.ℓ[k] = T(NaN)
    else
      m.ℓ[k] = _group_curvature!(m, idx, k)
    end
  end
  m
end
# The curvature of group k by the Gram route and the check of its step band, with the buffers of the model
# (allocated at the first use, for the largest group). It throws the refusals of `_gram_curvature` and of
# the band; it allocates (the eigensolve), once per group and solve.
@noinline function _group_curvature!(m::BlockLSModel, idx, k::Int)
  mmax = length(m.old)
  if size(m.Bbuf, 2) < mmax
    n = size(m.ls.X, 1)
    m.Bbuf = Matrix{Float64}(undef, n, mmax)
    m.Gbuf = Matrix{Float64}(undef, mmax, mmax)
  end
  ℓ = _gram_curvature(m.ls, idx, k, m.Bbuf, m.Gbuf)
  _check_step_band(m.ls, ℓ, k)
  ℓ
end
# The step band of group k: p = s ℓ in S and its reciprocal at least floatmin(S), the test of
# `_scaled_prox`.
@inline function _check_step_band(ls::LSModel, ℓ, k::Int)
  p = ls.s*ℓ
  (floatmin(typeof(p)) <= p) & (floatmin(typeof(p)) <= inv(p)) || _refuse_group_step(typeof(p), k)
  nothing
end
function _flat_group(ls::LSModel, idx)
  for j in idx
    _flat_column(ls, Int(j)) || return false
  end
  true
end
# ℓ = nextfloat(a (1 + 2 n eps(T))) for a = Σ x_i², the recursive sum of the n rounded squares of the
# column in T. Where n eps(T) ≤ 1/8, that is n u ≤ 1/16 for u = eps(T)/2, the computed a satisfies
# S (1 − γ_n) ≤ a + (n η/2)(1 + γ_n) for the exact sum S, with γ_n = n u/(1 − n u) ≤ 16 n u/15 = 8 n eps(T)/15 and
# η = nextfloat(zero(T)): assuming IEEE gradual underflow (subnormals not flushed to zero), the
# rounding of a square that underflows is an absolute error of at most η/2, which the later additions
# scale by at most 1 + γ_n. A computed a ≥ floatmin(T) gives η ≤ eps(T) a, so
# S ≤ a (1 + n eps(T) (1 + γ_n)/2)/(1 − γ_n), which is below a (1 + 2 n eps(T)) when
# n eps(T) ≤ 1/8. The factor 1 + 2 n eps(T) is exact in T, and `nextfloat` covers the rounding of the
# product, so ℓ ≥ S. A computed a below floatmin(T), zero or subnormal, is refused as underflow, and
# an a or an ℓ that is not finite as overflow.
function _singleton_curvature(ls::LSModel{T}, j::Int, k::Int) where T
  a = _sqnorm!(ls, j)
  a < floatmin(T) && return _refuse_group_curvature(T, k, false)
  isfinite(a) || return _refuse_group_curvature(T, k, true)
  n = size(ls.X, 1)
  ℓ = nextfloat(a*(one(T) + 2n*eps(T)))
  isfinite(ℓ) || return _refuse_group_curvature(T, k, true)
  ℓ
end
# The curvature bound of a group from the Gram matrix Ĝ of its columns B (n rows, mk columns), formed
# in W = Float64 with `mul!` on a copy of B held in the buffer Bbuf (n × mmax; Gbuf is mmax × mmax).
# A nonfinite Ĝ or trace t̂ is refused as overflow, and t̂ < mk floatmin(W) as underflow, both before
# the eigensolve. With μ̂ the largest eigenvalue of Ĝ (the entry Ĝ[1, 1] for one column), the bound
# in W is
#   ℓW = nextfloat(max(μ̂, max_i Ĝ_ii) + 4 (n + mk²) eps(W) t̂),
# which is rounded up to T. With u = eps(W)/2 and γ_n = n u/(1 − n u), which needs n eps(W) ≤ 1/8 and
# holds for any n that fits in memory as Float64, the bound adds three error terms to μ̂, each a
# multiple of t̂, assuming IEEE gradual underflow (subnormals not flushed to zero):
#   - Gram rounding, the relative component: where no product underflows, entrywise
#     |Ĝ − G| ≤ γ_n |B|ᵀ|B| for any order of summation, so ‖Ĝ − G‖₂ ≤ γ_n ‖B‖_F² = γ_n tr G, and
#     tr G ≤ t̂ (1 + O((n + mk) u)). The term is about n eps(W) t̂/2. This inequality alone does not
#     bound the total error: a product that underflows can have a relative error of 1.
#   - Underflowing products, the absolute component before propagation: each adds an absolute error
#     of at most η/2, and t̂ ≥ mk floatmin(W) bounds their total in ‖·‖₂ by mk n η/2 ≤ n eps(W) t̂/2,
#     with η = nextfloat(0.0) = eps(W) floatmin(W). The later additions scale this error by at most
#     1 + γ_{n−1}, the propagation allowance. The total Gram error is bounded by the relative
#     component plus (1 + γ_{n−1}) times the absolute component. A product of two Float32 values does
#     not underflow in W.
#   - Eigensolver, for mk ≥ 2 (for mk = 1 there is no eigensolve and no model): the computed
#     eigenvalues are modelled as exact eigenvalues of Ĝ + E with ‖E‖₂ ≤ p(mk) u t̂, and
#     4 mk² eps(W) t̂ covers p(mk) ≤ 8 mk². The eigensolver's documentation describes p as a modestly
#     growing function of mk, so this term is a modelling assumption, not a proven bound.
# The three terms need about (n + 4 mk²) eps(W) t̂. The remaining 3 n eps(W) t̂ or so of the margin
# 4 (n + mk²) eps(W) t̂ covers the rounding of the trace, the (1 + γ) propagation factors (including
# the (1 + γ_{n−1}) factor of the underflow term) and the rounding of the margin product; the final
# `nextfloat` covers the last addition. By Weyl's inequality λmax(G) is then at most μ̂ plus the
# margin. The entry max_i Ĝ_ii, a lower bound of λmax(Ĝ), guards a μ̂ that is computed below it. The
# rounding to T takes the nearest value, then `nextfloat` where that value is below ℓW. A nonfinite
# μ̂ or an ℓ that is Inf is refused as overflow, and an ℓ below floatmin(T) as underflow; an
# eigensolver failure propagates as an exception before any pass.
function _gram_curvature(ls::LSModel{T}, idx, k::Int, Bbuf::Matrix{Float64}, Gbuf::Matrix{Float64}) where T
  W = Float64
  X = ls.X
  n, mk = size(X, 1), length(idx)
  Bv = view(Bbuf, 1:n, 1:mk)
  for c in 1:mk
    j = Int(idx[c])
    @inbounds for i in 1:n
      Bv[i, c] = X[i, j]
    end
  end
  Gv = view(Gbuf, 1:mk, 1:mk)
  mul!(Gv, transpose(Bv), Bv)
  t = zero(W)
  dmax = zero(W)
  for c in 1:mk
    d = Gv[c, c]
    t += d
    dmax = max(dmax, d)
  end
  all(isfinite, Gv) && isfinite(t) || return _refuse_group_curvature(T, k, true)
  t < mk*floatmin(W) && return _refuse_group_curvature(T, k, false)
  μ = mk == 1 ? dmax : maximum(eigvals(Symmetric(Gv)))
  isfinite(μ) || return _refuse_group_curvature(T, k, true)
  ℓW = nextfloat(max(μ, dmax) + 4(n + mk^2)*eps(W)*t)
  ℓ = T(ℓW)
  W(ℓ) < ℓW && (ℓ = nextfloat(ℓ))
  isinf(ℓ) && return _refuse_group_curvature(T, k, true)
  ℓ < floatmin(T) && return _refuse_group_curvature(T, k, false)
  ℓ
end
# Whether the curvature of a group of the Gram route can be left uncomputed by `_prepare!`: true where
# bounds decide that `_gram_curvature` and `_check_step_band` do not refuse the group, false where a
# bound does not decide. The bounds come
# from q_c = Σ_i X[i, j_c]² for each column c, formed in W = Float64 by loop summation (n rows, mk
# columns), t = Σ_c q_c and d = max_c q_c, in O(n mk) operations and without products between columns.
# Notation as in `_gram_curvature`: u = eps(W)/2, γ_k = k u/(1 − k u), η = nextfloat(0.0), and gradual
# underflow is assumed. The function first requires S = typeof(s) to be Float32 or Float64 and
# 4 (n + mk²) eps(W) ≤ 1/16, which gives n eps(W) ≤ 1/64 and γ_{n+mk} < 1/100; it returns false for a t
# that is not finite.
#   Errors of the diagonal. Let G_cc = Σ_i X[i, j_c]² be the exact diagonal entry. Each of q_c and the
#   computed diagonal Ĝ_cc of `_gram_curvature` (any order of summation) lies within γ_n G_cc + A of G_cc,
#   where A = (n η/2)(1 + γ_{n−1}) ≤ n η bounds the error of the squares that underflow.
#   Lower bound, without the eigensolver model. For c* with q_{c*} = d, G_{c*} ≥ (d − A)/(1 + γ_n), so
#   the computed maximum diagonal dmax̂ ≥ Ĝ_{c*c*} ≥ (1 − γ_n)(d − A)/(1 + γ_n) − A
#   ≥ d (1 − 2 γ_n) − 2 A ≥ lo := d (1 − 2 n eps(W)) − 2 n η. The computed trace t̂ ≥ dmax̂ (a sum of
#   nonnegative terms), ℓW ≥ dmax̂ (the bound adds a positive margin to a maximum that contains dmax̂),
#   and the stored ℓ ≥ ℓW. So t̂ ≥ lo and ℓ ≥ lo.
#   Upper bound, under the eigensolver model of `_gram_curvature`. With tr G = Σ_c G_cc and all γ
#   below 1/15 (they are below 1/100): tr G ≤ (t/(1 − γ_mk) + mk A)/(1 − γ_n) ≤ 1.15 t + 1.1 mk A; λmax(Ĝ) ≤ (1 + γ_n) tr G + mk A
#   by Weyl's inequality and the entrywise bound of `_gram_curvature`; μ̂ ≤ λmax(Ĝ) + 4 mk² eps(W) t̂ with
#   4 mk² eps(W) ≤ 1/16; t̂ ≤ (1 + γ_mk) ((1 + γ_n) tr G + mk A) ≤ 1.31 t + 2.3 mk A. Then
#   ℓW ≤ (1 + 4 (n + mk²) eps(W)) (1 + u)² max(μ̂, dmax̂) ≤ 1.4 t + 2.5 mk A, and mk A ≤ mk n η
#   = mk (n eps(W)) floatmin(W) ≤ mk floatmin(W)/64 ≤ lo/128 ≤ t/128 where the threshold (1) below
#   holds, so the stored ℓ ≤ 1.5 t (the rounding up to T adds at most 1.5 eps(T) relative). The code
#   uses the generous hi := 4 t.
# The bounds hold for the values of the stored matrix, computed in W; the comparisons below are made in
# W with the factor 2 (or 1/2) that absorbs the rounding of lo, hi and the products with s (relative
# error below 4u). The group is left uncomputed if all four hold, and computed at once otherwise:
#   (1) lo ≥ 2 mk floatmin(W): then t̂ ≥ mk floatmin(W), so the underflow refusal of the trace is not made;
#   (2) lo ≥ 2 floatmin(T): then ℓ ≥ floatmin(T), so the underflow refusal of ℓ is not made;
#   (3) hi ≤ floatmax(T)/2: then the Gram entries (each at most (1 + γ_n) tr G in magnitude) and t̂ are
#       finite and ℓ is finite in T (it is at most 1.5 t ≤ hi/2.6), so the overflow refusals are not
#       made;
#   (4) s lo ≥ 2 floatmin(S) and s hi ≤ 1/(2 floatmin(S)), with s converted to W: then p = s ℓ rounded in S
#       satisfies p ≥ floatmin(S) and 1/p ≥ floatmin(S), so `_check_step_band` does not refuse.
# The eigensolver model enters the upper bound hi but not the lower bound lo. Neither an eigensolver
# failure nor a nonfinite μ̂ is decided here: such a failure surfaces at the lazy computation.
function _curvature_deferrable(ls::LSModel{T}, idx) where T
  S = typeof(ls.s)
  (S === Float32 || S === Float64) || return false
  W = Float64
  X = ls.X
  n, mk = size(X, 1), length(idx)
  4(n + mk^2)*eps(W) <= 1/16 || return false
  t = zero(W)
  d = zero(W)
  for c in 1:mk
    j = Int(idx[c])
    q = zero(W)
    @inbounds @simd for i in 1:n
      v = W(X[i, j])
      q += v*v
    end
    t += q
    d = max(d, q)
  end
  isfinite(t) || return false
  lo = d*(1 - 2n*eps(W)) - 2n*nextfloat(0.0)
  hi = 4t
  sW = W(ls.s)
  fS = W(floatmin(S))
  lo >= 2mk*floatmin(W) && lo >= 2*W(floatmin(T)) && hi <= W(floatmax(T))/2 &&
    sW*lo >= 2fS && sW*hi <= 1/(2fS)
end
# The throws are out of line, so that the success path carries no string interpolation.
@noinline function _refuse_group_curvature(::Type{T}, k::Int, overflow::Bool) where T
  overflow && throw(ArgumentError("the curvature of group $k (a bound on the largest eigenvalue of the Gram matrix of its columns) overflows in $T; rescale the data"))
  throw(ArgumentError("the curvature of group $k (a bound on the largest eigenvalue of the Gram matrix of its columns) underflows in $T; rescale the data or loss"))
end
@noinline _refuse_group_step(::Type{S}, k::Int) where S =
  throw(ArgumentError("the step of group $k is not representable in $S: the loss scale times the group curvature, or its reciprocal, is outside the normal range; rescale the data or the loss"))
@noinline _refuse_block_value(::Type{T}, k::Int) where T =
  throw(ArgumentError("the trial point or the displacement of group $k is not finite in $T; rescale the data"))

# The group step. With the curvature bound ℓ, b_i = rᵀX[:, j_i] and the trial point u = old + b/ℓ, the
# new block is `prox_block!(u, g, u, k, 1/(s ℓ))`, the proximal point of the majorizing surrogate of the
# loss in the group. A flat group (ℓ = 0) takes `prox_block!` at the step Inf: the penalty's minimizer,
# which is the zero block for a positive level and weight and the block itself where the level or the
# weight is 0. A trial point or a displacement that is not finite is refused before the block or the
# residual changes. The displacement is written into `old`. A group whose displacement is 0 is not
# written, which keeps an inactive group inactive; otherwise the block is written with one `copyto!` of
# the compact scratch `u` and the residual is updated by one pass per nonzero entry of the displacement.
# The step returns the 2-norm of the displacement, formed by LinearAlgebra's `norm`, which scales the
# squares.
# Screen. For a group other than a flat one whose current block is identically 0 (active or not), the
# step first applies `prox_block!` to a copy of b at the step γs = 1/s in S, when γs is a normal number
# of S (floatmin(S) ≤ γs ≤ floatmax(S)); otherwise the screen is bypassed, because a γs that rounded to
# Inf or 0 would not describe the step 1/(s ℓ). The prox of b/ℓ at the step 1/(s ℓ) is 0 where
# ‖b‖ ≤ λ0 w_k/s, for any ℓ > 0, so a copy that `prox_block!` returns as all 0 gives the displacement 0
# without the curvature: the step returns zero(T) with x and the residual unchanged. The screen and the
# full step both decide by ProximalBase's range-safe comparison, but at a tie ‖b‖ = λ0 w_k/s they
# take different quantities (γs and 1/(s ℓ)) and can decide differently by rounding. A nonfinite b is
# not screened and is refused by the full step.
# Curvature. Where ℓ[k] is NaN (`_prepare!` left it uncomputed) and the screen did not return, the
# curvature and the step band are computed now by `_group_curvature!` and stored; the arithmetic of the
# step is then as for a curvature computed in `_prepare!`. A refusal or an eigensolver failure there
# occurs during a pass: the run is on a private copy, so the caller's iterate is unchanged, and the
# borrowed generator may have advanced. A refusal that is predictable from the data is made in
# `_prepare!` (see `_curvature_deferrable`). The band of the step, s ℓ and its reciprocal at least
# floatmin(typeof(s ℓ)), is checked where ℓ is computed.
function coordinate_step!(m::BlockLSModel{T}, g::GroupNormL2, x::BlockIterate{T}, k::Int) where T
  ls = m.ls
  idx = blockindices(x, k)
  mk = length(idx)
  old = view(m.old, 1:mk)
  u = view(m.u, 1:mk)
  b = view(m.b, 1:mk)
  zeroblock = true
  for i in 1:mk
    v = x[idx[i]]
    old[i] = v
    iszero(v) || (zeroblock = false)
  end
  ℓ = m.ℓ[k]
  if iszero(ℓ)
    prox_block!(u, g, old, k, Inf)
  else
    for i in 1:mk
      b[i] = _column_dot(ls.X, ls.r, Int(idx[i]), one(T))[2]
    end
    if zeroblock
      γs = inv(ls.s)
      if floatmin(typeof(γs)) <= γs <= floatmax(typeof(γs))
        copyto!(u, b)
        prox_block!(u, g, u, k, γs)
        screened = true
        for i in 1:mk
          iszero(u[i]) || (screened = false)
        end
        screened && return zero(T)
      end
    end
    if isnan(ℓ)
      ℓ = _group_curvature!(m, idx, k)
      m.ℓ[k] = ℓ
    end
    for i in 1:mk
      v = old[i] + b[i]/ℓ
      isfinite(v) || _refuse_block_value(T, k)
      u[i] = v
    end
    prox_block!(u, g, u, k, inv(ls.s*ℓ))
  end
  moved = false
  for i in 1:mk
    d = u[i] - old[i]
    isfinite(d) || _refuse_block_value(T, k)
    old[i] = d
    iszero(d) || (moved = true)
  end
  moved || return zero(T)
  copyto!(blockview(x, k), u)
  for i in 1:mk
    iszero(old[i]) || _residual_axpy!(ls, Int(idx[i]), old[i])
  end
  norm(old)
end
