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
# ℓ[k] ≥ λmax(X_kᵀX_k) in exact arithmetic (the loss scale s is applied where the step is formed). It
# is 0 for a flat group, where all entries of X_k are 0, and NaN until `_prepare!` has run. `old` and
# `u` are scratch vectors as long as the largest group. The model has no `_cache`, so momentum stays
# off.
struct BlockLSModel{T<:AbstractFloat, S<:AbstractFloat, M<:LSModel{T, S}} <: CDModel{T}
  ls::M
  ℓ::Vector{T}
  old::Vector{T}
  u::Vector{T}
end
function cdmodel(f::Union{LeastSquaresLoss{T, <:AbstractVector}, Scaled{<:LeastSquaresLoss{T, <:AbstractVector}}}, x::BlockIterate{T}) where T
  d = leastsquares_data(f)
  ls = LSModel(d.Y, d.X, d.α)
  K = ncoordinates(x)
  mmax = maximum(length(blockindices(x, k)) for k in 1:K)
  BlockLSModel{T, typeof(ls.s), typeof(ls)}(ls, fill(T(NaN), K), Vector{T}(undef, mmax), Vector{T}(undef, mmax))
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
# is 0 for a flat group.
coordinate_scale(m::BlockLSModel, x, k::Int) = _curvature_scale(m.ls, m.ℓ[k])

# Per-solve preparation: the curvature bound and the step band of each group, before the first pass.
# A group whose columns are all 0 has ℓ = 0 and no band. A refusal names the group; `_prepare!`
# changes neither the coordinates nor the residual. The curvature of a group of one column is the sum
# of squares of the column (`_sqnorm!`, in T, without `@simd`) with the rounding margin of
# `_singleton_curvature`; any other group, and a singleton with n eps(T) > 1/8 (n rows), takes
# `_gram_curvature`. The block path refuses a curvature below floatmin(T), which the scalar path
# accepts as a subnormal value. `_sqnorm!` sums in order, while the scalar step takes the sum from
# `_column_dot`, which `@simd` reassociates, so the two can differ by rounding, and the block
# curvature of a singleton is larger than the scalar one by its margin.
function _prepare!(m::BlockLSModel{T}, g::GroupNormL2, x::BlockIterate{T}) where T
  ls = m.ls
  n = size(ls.X, 1)
  mmax = length(m.old)
  Bbuf = Matrix{Float64}(undef, 0, 0)
  Gbuf = Matrix{Float64}(undef, 0, 0)
  for k in 1:ncoordinates(x)
    idx = blockindices(x, k)
    if _flat_group(ls, idx)
      m.ℓ[k] = zero(T)
      continue
    end
    if length(idx) == 1 && n*eps(T) <= 1/8
      ℓ = _singleton_curvature(ls, Int(idx[1]), k)
    else
      if size(Bbuf, 2) < length(idx)
        Bbuf = Matrix{Float64}(undef, n, mmax)
        Gbuf = Matrix{Float64}(undef, mmax, mmax)
      end
      ℓ = _gram_curvature(ls, idx, k, Bbuf, Gbuf)
    end
    p = ls.s*ℓ
    (floatmin(typeof(p)) <= p) & (floatmin(typeof(p)) <= inv(p)) || _refuse_group_step(typeof(p), k)
    m.ℓ[k] = ℓ
  end
  m
end
function _flat_group(ls::LSModel, idx)
  for j in idx
    _flat_column(ls, Int(j)) || return false
  end
  true
end
# ℓ = nextfloat(a (1 + 2 n eps(T))) for a = Σ x_i², the recursive sum of the n rounded squares of the
# column in T. Where n eps(T) ≤ 1/8, that is n u ≤ 1/16 for u = eps(T)/2, the computed a satisfies
# S (1 − γ_n) ≤ a + n η/2 for the exact sum S, with γ_n = n u/(1 − n u) ≤ 16 n u/15 = 8 n eps(T)/15 and
# η = nextfloat(zero(T)) (the rounding of a square that underflows adds at most η/2). A computed
# a ≥ floatmin(T) gives η ≤ eps(T) a, so S ≤ a (1 + n eps(T)/2)/(1 − γ_n), which is below
# a (1 + 2 n eps(T)) when n eps(T) ≤ 1/8. The factor 1 + 2 n eps(T) is exact in T, and `nextfloat`
# covers the rounding of the product, so ℓ ≥ S. A computed a below floatmin(T), zero or subnormal,
# is refused as underflow, and an a or an ℓ that is not finite as overflow.
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
# which is rounded up to T. It adds three error terms to μ̂, each a multiple of t̂:
#   - Gram rounding: entrywise |Ĝ − G| ≤ γ_n |B|ᵀ|B| for any order of summation, with
#     γ_n = n u/(1 − n u) and u = eps(W)/2, so ‖Ĝ − G‖₂ ≤ γ_n ‖B‖_F² = γ_n tr G, and tr G is at most
#     t̂/(1 − γ_n). The term is about n eps(W) t̂/2.
#   - Underflowing products: t̂ ≥ mk floatmin(W) bounds their total error in ‖·‖₂ by
#     mk n η/2 ≤ n eps(W) t̂/2, with η = nextfloat(0.0) = eps(W) floatmin(W). A product of two
#     Float32 values does not underflow in W.
#   - Eigensolver: the symmetric eigensolver's backward error is modelled as
#     ‖E‖₂ ≤ p(mk) u ‖Ĝ‖₂ ≤ p(mk) u t̂, and 4 mk² eps(W) t̂ covers p(mk) ≤ 8 mk². The eigensolver's
#     documentation describes p as a modestly growing function of mk, so this term is a modelling
#     assumption, not a proven bound.
# By Weyl's inequality λmax(G) is at most μ̂ plus the three terms. The entry max_i Ĝ_ii, a lower bound
# of λmax(Ĝ), guards a μ̂ that is computed below it. The rounding to T takes the nearest value, then
# `nextfloat` where that value is below ℓW. An ℓ that is Inf is refused as overflow, and an ℓ below
# floatmin(T) as underflow.
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
  ℓW = nextfloat(max(μ, dmax) + 4(n + mk^2)*eps(W)*t)
  ℓ = T(ℓW)
  W(ℓ) < ℓW && (ℓ = nextfloat(ℓ))
  isinf(ℓ) && return _refuse_group_curvature(T, k, true)
  ℓ < floatmin(T) && return _refuse_group_curvature(T, k, false)
  ℓ
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

# The group step. With the curvature bound ℓ of `_prepare!`, b_i = rᵀX[:, j_i] and the trial point
# u = old + b/ℓ, the new block is `prox_block!(u, g, u, k, 1/(s ℓ))`, the proximal point of the
# majorizing surrogate of the loss in the group. A flat group (ℓ = 0) takes `prox_block!` at the step
# Inf: the penalty's minimizer, which is the zero block for a positive level and weight and the block
# itself where the level or the weight is 0. A trial point or a displacement that is not finite is
# refused before the block or the residual changes. The displacement is written into `old`. A group
# whose displacement is 0 is not written, which keeps an inactive group inactive; otherwise the block
# is written with one `copyto!` of the compact scratch `u` and the residual is updated by one pass per
# nonzero entry of the displacement. The step returns the 2-norm of the displacement, formed by
# LinearAlgebra's `norm`, which scales the squares. The band of the step, s ℓ and its reciprocal at
# least floatmin(typeof(s ℓ)), was checked in `_prepare!`.
function coordinate_step!(m::BlockLSModel{T}, g::GroupNormL2, x::BlockIterate{T}, k::Int) where T
  ls = m.ls
  idx = blockindices(x, k)
  mk = length(idx)
  old = view(m.old, 1:mk)
  u = view(m.u, 1:mk)
  for i in 1:mk
    old[i] = x[idx[i]]
  end
  ℓ = m.ℓ[k]
  if iszero(ℓ)
    prox_block!(u, g, old, k, Inf)
  else
    for i in 1:mk
      b = _column_dot(ls.X, ls.r, Int(idx[i]), one(T))[2]
      v = old[i] + b/ℓ
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
