####################################
#
#  square-root least squares  ‖y - Xβ‖
#
####################################

"""
    SqrtLeastSquaresLoss(y, X; weights = nothing)

The loss `f(β) = ‖y - Xβ‖₂` of the square-root lasso (Belloni, Chernozhukov and
Wang, 2011), whose optimal penalty level does not depend on the noise level,
or with observation weights `w ≥ 0` the weighted norm `√(∑ᵢ wᵢ (yᵢ - Xᵢ'β)²)`.
It is not differentiable where the residuals vanish, so coordinate descent
([`CDSolver`](@ref)) minimizes `f + g` exactly over each coordinate, which it
does for `g = NormL1(λ, w)`. With [`cdmodel`](@ref)`(f, x; intercept = true)`
the loss is minimized over an unpenalized intercept as well.

Near an exact fit (`p ≥ n` with a small penalty, or nearly noiseless data),
coordinate steps can stop far from the minimizer, since the loss is not
differentiable at zero residuals. A run therefore converges only when the
relative duality gap (see [`duality_gap`](@ref) for its meaning) is at most
`gaptol`, or `1e-4` with the default `gaptol = 0`; the results report this gap.
The residual direction `t r/‖r‖` is tried first. Otherwise a joint witness
is built from the nonzero and unpenalized coordinates and the residual
orthogonal to their span. Its norm and penalized correlations use conservative
rounding bounds. A projection bound subtracts the possible contribution of
unpenalized coordinates and the uncentered intercept from the dual value;
a small equality residual alone never certifies a run. Residuals are
recomputed from the data, including sparse centering and weights. If no
point passes, the always-feasible zero point gives a relative gap of one
when the objective is positive. Coordinate changes alone never certify a run.

The support solve allows dependent columns and at most 2000 coordinates.
The Gram matrix is equilibrated before deciding its numerical rank. At an
exact fit, the support equations can certify when their retained directions
determine the dual point, or their least-norm point meets the other
constraints, and the rounding and unrestricted projection bounds are small
enough. An unresolved unrestricted span uses the zero witness. The method may
miss another feasible point, so some exact minimizers still return
`converged = false`. Nonfinite penalty loadings, including a zero level times
an infinite weight, fix coordinates at zero and are excluded from the dual
constraints. The certificate is for this convention of the coordinate steps.
The public `duality_gap` interface remains unsupported for this loss.
"""
struct SqrtLeastSquaresLoss{T<:AbstractFloat, Ty<:AbstractVector, TX<:AbstractMatrix,
                            W<:Union{Nothing, AbstractVector}} <: AbstractFunction
  y::Ty
  X::TX
  w::W
  tmp::Vector{T}
end

function SqrtLeastSquaresLoss(y::AbstractVector, X::AbstractMatrix; weights::Union{Nothing, AbstractVector} = nothing)
  n = size(X, 1)
  n == length(y) || throw(DimensionMismatch("X has $n rows and y has length $(length(y))"))
  if weights !== nothing
    length(weights) == n || throw(DimensionMismatch("X has $n rows and weights has length $(length(weights))"))
    all(w -> isfinite(w) && w >= 0, weights) || throw(ArgumentError("the weights must be finite and nonnegative."))
  end
  T = float(promote_type(eltype(y), eltype(X)))
  SqrtLeastSquaresLoss{T, typeof(y), typeof(X), typeof(weights)}(y, X, weights, zeros(T, n))
end

ProximalBase.isconvex(::Type{<:SqrtLeastSquaresLoss}) = true

function (f::SqrtLeastSquaresLoss)(β::AbstractVector)
  mul!(f.tmp, f.X, β)
  f.tmp .= f.y .- f.tmp
  f.w === nothing ? norm(f.tmp) : sqrt(sum(i -> f.w[i] * f.tmp[i]^2, eachindex(f.tmp)))
end

# As LSModel, a sparse X is read at its nonzeros, and with an intercept the
# residuals are r .+ δ. ‖r‖ is computed at every step, in O(n), as for a dense X.
mutable struct SqrtLSModel{T<:AbstractFloat, MX<:AbstractMatrix{T}, VY<:AbstractVector{T},
                           W<:Union{Nothing, AbstractVector{T}}} <: CDModel{T}
  X::MX
  y::VY
  w::W
  r::Vector{T}
  a::Vector{T}          # ∑ᵢ wᵢ (Xᵢₖ - x̄ₖ)², the squared norms of the centered columns, NaN until computed
  xbar::Vector{T}       # (weighted) column means with an intercept, otherwise zeros
  ybar::T               # (weighted) mean of y with an intercept, otherwise zero
  centered::Bool        # whether the dual point must be orthogonal to the intercept
  N::T                  # n, or ∑ᵢ wᵢ: the scales of the stopping rule are per observation
  tmp::Vector{T}        # weighted residuals and projection work
  δ::T                  # the residuals are r .+ δ (a sparse X with an intercept)
  rbuf::Vector{T}       # shifted residuals or dual residual work
  grad::Vector{T}       # ∇f, for the duality gap at the end of a run
  dualy::Vector{T}      # centered weighted response for certification
  dualθ::Vector{T}      # dual point in weighted observation space
  dualsw::Vector{T}     # square roots of the observation weights
  dualeig::_GroupEig{T}
  dualvectors::Matrix{T}
  dualsupport::Vector{Int}
  dualc::Vector{T}
  dualrhs::Vector{T}
  dualα::Vector{T}
  dualγ::Vector{T}
  dualcorrerr::Vector{T}
  dualscale::Vector{T}
  dualunpen::Vector{Int}
  dualunpenscale::Vector{T}
  dualbound::T
  dualinv::T
  dualweighterror::Vector{T}
  dualswerror::Vector{T}
end

function cdmodel(f::SqrtLeastSquaresLoss{T}, x; intercept::Bool = false) where {T}
  X, y = convert(AbstractMatrix{T}, f.X), convert(AbstractVector{T}, f.y)
  w = f.w === nothing ? nothing : convert(AbstractVector{T}, f.w)
  _check_finite(y, "y"); _check_finite(X, "X")
  N = w === nothing ? T(length(y)) : sum(w)
  intercept && !(N > 0) && throw(ArgumentError("an intercept needs weights with a positive sum"))
  p = size(X, 2)
  SqrtLSModel{T, typeof(X), typeof(y), typeof(w)}(X, y, w, zeros(T, length(y)), fill(T(NaN), p),
                                                  intercept ? _column_means(X, w) : zeros(T, p),
                                                  intercept ? _mean_response(y, nothing, w) : zero(T), intercept, N,
                                                  zeros(T, length(y)), zero(T), zeros(T, length(y)), zeros(T, p),
                                                  zeros(T, length(y)), zeros(T, length(y)), w === nothing ? T[] : zeros(T, length(y)),
                                                  _GroupEig{T}(), Matrix{T}(undef, 0, 0), sizehint!(Int[], min(p, _SQRT_DUAL_MAXSUPPORT)),
                                                  sizehint!(T[], min(p, _SQRT_DUAL_MAXSUPPORT)), T[], T[], T[],
                                                  zeros(T, p), T[], sizehint!(Int[], min(p + 1, _SQRT_DUAL_MAXSUPPORT)),
                                                  sizehint!(T[], min(p + 1, _SQRT_DUAL_MAXSUPPORT)), zero(T), zero(T),
                                                  zeros(T, length(y)), zeros(T, length(y)))
end

intercept(m::SqrtLSModel, x::AbstractArray) = m.ybar - dot(m.xbar, x)
residuals(m::SqrtLSModel) = m.r
residuals(m::SqrtLSModel{T, <:SparseMatrixCSC}) where {T<:AbstractFloat} = _shifted_residuals!(m.rbuf, m.r, m.δ)

function initialize!(m::SqrtLSModel{T}, x::SparseIterate{T}) where {T}
  length(x) == size(m.X, 2) || throw(DimensionMismatch("x has length $(length(x)) and X has $(size(m.X, 2)) columns"))
  m.r .= m.y .- m.ybar
  m.δ = zero(T)
  for k in activecoordinates(x)
    v = x[k]
    iszero(v) || _residual_axpy!(m, k, v)
  end
  fill!(m.a, T(NaN))
  m
end

# the residuals after a step h of coordinate k, as for LSModel
@inline _residual_axpy!(m::SqrtLSModel{T}, k::Int, h::T) where {T} = _column_axpy!(m.r, m.X, k, m.xbar[k], h)
@inline function _residual_axpy!(m::SqrtLSModel{T, <:SparseMatrixCSC}, k::Int, h::T) where {T<:AbstractFloat}
  _column_axpy!(m.r, m.X, k, zero(T), h)
  m.δ += h * m.xbar[k]
  m.r
end

# (a, s, ρ) with s = (X[:, k] - c)' r, ρ = r' r and a = ‖X[:, k] - c‖², which
# is computed only when the cached a is NaN
@inline function _column_dot_rsqr(X::AbstractMatrix{T}, r::AbstractVector{T}, k::Int, c::T, a::T) where {T}
  s = zero(T)
  ρ = zero(T)
  if isnan(a)
    a = zero(T)
    if iszero(c)
      @inbounds @simd for i in eachindex(r)
        a += X[i, k] * X[i, k]
        s += r[i] * X[i, k]
        ρ += r[i] * r[i]
      end
    else
      @inbounds @simd for i in eachindex(r)
        d = X[i, k] - c
        a += d * d
        s += r[i] * d
        ρ += r[i] * r[i]
      end
    end
  elseif iszero(c)
    @inbounds @simd for i in eachindex(r)
      s += r[i] * X[i, k]
      ρ += r[i] * r[i]
    end
  else
    @inbounds @simd for i in eachindex(r)
      s += r[i] * (X[i, k] - c)
      ρ += r[i] * r[i]
    end
  end
  a, s, ρ
end

# the same with weights: s = ∑ᵢ wᵢ (Xᵢₖ - c) rᵢ, ρ = ∑ᵢ wᵢ rᵢ² and a = ∑ᵢ wᵢ (Xᵢₖ - c)²
@inline function _column_dot_rsqr(X::AbstractMatrix{T}, r::AbstractVector{T}, w::AbstractVector{T}, k::Int, c::T,
                                  a::T) where {T}
  s = zero(T)
  ρ = zero(T)
  if isnan(a)
    a = zero(T)
    @inbounds @simd for i in eachindex(r)
      d = X[i, k] - c
      a += d * d * w[i]
      s += r[i] * d * w[i]
      ρ += r[i] * r[i] * w[i]
    end
  else
    @inbounds @simd for i in eachindex(r)
      s += r[i] * (X[i, k] - c) * w[i]
      ρ += r[i] * r[i] * w[i]
    end
  end
  a, s, ρ
end

# the same for a sparse X and the residuals r .+ δ, which sum to zero with an
# intercept: s = X[:, k]' r + n c δ over the nonzeros, ρ = ‖r .+ δ‖² over all
@inline function _column_dot_rsqr(X::SparseMatrixCSC{T}, r::AbstractVector{T}, k::Int, c::T, a::T, δ::T) where {T}
  a, s = _column_dot(X, r, k, c, a, δ)
  ρ = zero(T)
  @inbounds @simd for i in eachindex(r)
    ρ += (r[i] + δ) * (r[i] + δ)
  end
  a, s, ρ
end

# the same with weights, whose weighted residuals sum to zero with an intercept:
# s = ∑ᵢ wᵢ Xᵢₖ rᵢ + W c δ over the nonzeros, with W = ∑ᵢ wᵢ, ρ = ∑ᵢ wᵢ (rᵢ + δ)²
@inline function _column_dot_rsqr(X::SparseMatrixCSC{T}, r::AbstractVector{T}, w::AbstractVector{T}, k::Int, c::T,
                                  a::T, δ::T, W::T) where {T}
  a, s = _column_dot(X, r, w, k, c, a, δ, W)
  ρ = zero(T)
  @inbounds @simd for i in eachindex(r)
    ρ += w[i] * (r[i] + δ) * (r[i] + δ)
  end
  a, s, ρ
end

@inline _column_dot_rsqr(m::SqrtLSModel, ::Nothing, k::Int) = _column_dot_rsqr(m.X, m.r, k, m.xbar[k], m.a[k])
@inline _column_dot_rsqr(m::SqrtLSModel, w::AbstractVector, k::Int) = _column_dot_rsqr(m.X, m.r, w, k, m.xbar[k], m.a[k])
@inline _column_dot_rsqr(m::SqrtLSModel{T, <:SparseMatrixCSC}, ::Nothing, k::Int) where {T<:AbstractFloat} =
  _column_dot_rsqr(m.X, m.r, k, m.xbar[k], m.a[k], m.δ)
@inline _column_dot_rsqr(m::SqrtLSModel{T, <:SparseMatrixCSC}, w::AbstractVector, k::Int) where {T<:AbstractFloat} =
  _column_dot_rsqr(m.X, m.r, w, k, m.xbar[k], m.a[k], m.δ, m.N)

# the exact minimizer of ‖r - X[:,k] t‖ + λ|t| over the coordinate, with the
# columns centered at their means when the model fits an intercept, and the
# inner products weighted by w if the loss has weights
function coordinate_step!(m::SqrtLSModel, g::NormL1, x::SparseIterate, k::Int)
  T = eltype(m)

  # partial residuals with coordinate k removed: r = y - X*x + X[:,k]*x[k]
  old = x[k]
  iszero(old) || _residual_axpy!(m, k, -old)

  xsqr, s, rsqr = _column_dot_rsqr(m, m.w, k)
  m.a[k] = xsqr
  λ = T(g.λ0 * _weight(g, k))

  # zero when the subgradient condition |X[:,k]'r| ≤ λ‖r‖ holds. Otherwise
  # λ² < ‖X[:,k]‖² and (X[:,k]'r)² ≤ ‖X[:,k]‖² ‖r‖² by Cauchy–Schwarz, but
  # rounding can break either when r is nearly parallel to X[:,k], so both are
  # enforced
  q = 1 - λ^2 / xsqr
  new = if abs(s) <= λ * sqrt(rsqr) || !(q > 0)
    zero(T)
  else
    (s - copysign(λ / sqrt(q) * sqrt(max(rsqr - s^2 / xsqr, zero(T))), s)) / xsqr
  end

  iszero(new) || _residual_axpy!(m, k, new)
  new != old && (x[k] = new)
  new - old
end

_cache(m::SqrtLSModel) = m.r
_cache_moved!(m::SqrtLSModel{T, <:SparseMatrixCSC}, x::SparseIterate{T}) where {T<:AbstractFloat} =
  (m.δ = _dot_active(m.xbar, x); m)

check_penalty(::SqrtLSModel, g) = g isa NormL1 ||
  throw(ArgumentError("coordinate descent on SqrtLeastSquaresLoss needs a NormL1 penalty, but g is a $(typeof(g))."))

_certified!(st, m::SqrtLSModel, g, x, s) = _sqrt_certified!(st, m, g, x, s)

@inline _sqrt_observation(m::SqrtLSModel{T}, i, k) where {T} =
  k == 0 ? one(T) : k < 0 ? m.y[i] : m.X[i, k]

@inline function _sqrt_gram(m::SqrtLSModel{T}, k, j) where {T}
  hi, lo, errors = zero(T), zero(T), zero(T)
  for i in eachindex(m.y)
    a, b = _sqrt_observation(m, i, k), _sqrt_observation(m, i, j)
    w = m.w === nothing ? one(T) : m.w[i]
    hi, lo, errors = _sqrt_addtriple(hi, lo, errors, a, b, w)
  end
  _sqrt_finish(hi, lo, errors, 3length(m.y))
end

function _sqrt_zerocol(m::SqrtLSModel, k)
  for i in eachindex(m.y)
    m.w !== nothing && iszero(m.w[i]) && continue
    iszero(m.X[i, k]) || return false
  end
  true
end

function _sqrt_samecol(m::SqrtLSModel{T}, k, j) where {T}
  same = opposite = constantk = constantj = true
  seen = false
  firstk, firstj = zero(T), zero(T)
  for i in eachindex(m.y)
    m.w !== nothing && iszero(m.w[i]) && continue
    a, b = _sqrt_observation(m, i, k), _sqrt_observation(m, i, j)
    if !seen
      firstk, firstj, seen = a, b, true
    end
    same &= a == b
    opposite &= a == -b
    constantk &= a == firstk
    constantj &= b == firstj
  end
  same || opposite || (constantk && constantj)
end

# The residual of the square root bounds its rounding. Near underflow the
# relative bound avoids losing that residual to zero.
@inline function _sqrt_rooterror(sw::T, w::T) where {T}
  iszero(w) && return zero(T)
  w < sqrt(floatmin(T)) && return _sqrt_upper(eps(T) * sw)
  residual = abs(fma(sw, sw, -w))
  _sqrt_upper(_sqrt_upper(residual / (2sw)) * (1 + 4eps(T)))
end

# This includes both the compensated dot and uncertainty in √wᵢ θᵢ.
@inline function _sqrt_observation_product(m::SqrtLSModel{T}, k, weighted) where {T}
  hi, lo, errors, uncertainty = zero(T), zero(T), zero(T), zero(T)
  for i in eachindex(weighted)
    a = _sqrt_observation(m, i, k)
    hi, lo, errors = _sqrt_addproduct(hi, lo, errors, a, weighted[i])
    uncertainty = _sqrt_upper(uncertainty + _sqrt_upmul(abs(a), m.dualweighterror[i]))
  end
  value, error = _sqrt_finish(hi, lo, errors, length(weighted))
  value, _sqrt_upper(error + uncertainty)
end

# Work in weighted observation space, including rows with zero weight. The
# fresh residual includes the centering shift of a sparse design.
@inline function _sqrt_dualdata(m::SqrtLSModel{T}, x) where {T}
  Y, R = m.dualy, m.rbuf
  fill!(R, zero(T))
  shift = zero(T)
  nactive = 0
  for k in activecoordinates(x)
    v = x[k]
    iszero(v) && continue
    nactive += 1
    _column_axpy!(R, m.X, k, zero(T), v)
    shift += m.xbar[k] * v
  end
  sw = m.w === nothing ? nothing : m.dualsw
  fitted2 = zero(T)
  for i in eachindex(Y)
    Y[i] = m.y[i] - m.ybar
    R[i] += Y[i] + shift
    if sw !== nothing
      sw[i] = sqrt(m.w[i])
      m.dualswerror[i] = _sqrt_rooterror(sw[i], m.w[i])
      Y[i] *= sw[i]
      R[i] *= sw[i]
    end
    fitted2 += (Y[i] - R[i])^2
  end
  f = norm(R)
  rounding = _SQRT_DUAL_ROUNDING * max(1, nactive) * eps(T) *
             (norm(Y) + sqrt(fitted2) + abs(m.ybar) * sqrt(m.N))
  all(isfinite, R) && isfinite(f) ? (; R, Y, sw, f, rounding) : nothing
end

# Form and test the vector itself, rather than identities that assume an
# exact support solve. Centering twice removes the last rounding of the mean.
function _sqrt_vectordual(m::SqrtLSModel{T}, data, g, θ) where {T}
  if m.centered
    for _ in 1:2
      if data.sw === nothing
        θ .-= sum(θ) / m.N
      else
        θ .-= data.sw .* (dot(data.sw, θ) / m.N)
      end
    end
  end
  nθ = _sqrt_normupper(θ)
  weighted = if data.sw === nothing
    fill!(m.dualweighterror, zero(T))
    θ
  else
    m.tmp .= data.sw .* θ
    for i in eachindex(θ)
      producterror = abs(fma(data.sw[i], θ[i], -m.tmp[i]))
      _sqrt_productrisk(data.sw[i], θ[i], m.tmp[i]) && (producterror += eps(zero(T)))
      m.dualweighterror[i] = _sqrt_upper(producterror + _sqrt_upmul(abs(θ[i]), m.dualswerror[i]))
    end
    m.tmp
  end
  z, errors = m.grad, m.dualcorrerr
  for k in eachindex(z)
    z[k], errors[k] = _sqrt_observation_product(m, k, weighted)
  end
  z₀, e₀ = m.centered ? _sqrt_observation_product(m, 0, weighted) : (zero(T), zero(T))
  D, error = _sqrt_observation_product(m, -1, weighted)
  _sqrt_validated_dual(m, g, z, nθ, _sqrt_lower(D - error), z₀, e₀)
end

function _sqrt_residualdual(m::SqrtLSModel, data, g, scale)
  m.dualθ .= scale .* data.R
  _sqrt_vectordual(m, data, g, m.dualθ)
end

@inline function _sqrt_supportdata(m::SqrtLSModel{T}, data, S) where {T}
  n = length(S)
  B = view(m.dualeig.B, :, 1:n)
  for (j, k) in enumerate(S), i in axes(B, 1)
    v = m.X[i, k] - m.xbar[k]
    B[i, j] = data.sw === nothing ? v : data.sw[i] * v
  end
  K = reshape(view(m.dualeig.C, 1:n^2), n, n)
  s = view(m.dualrhs, 1:n)
  mul!(K, transpose(B), B)
  mul!(s, transpose(B), data.R)
  (; B, K, s)
end

function _sqrt_jointpoint(m::SqrtLSModel{T}, data, g, S, geometry, α, γ) where {T}
  base = mul!(m.dualθ, geometry.B, α)
  projected = mul!(m.tmp, geometry.B, γ)
  oldnorm = norm(data.R)
  projectednorm = norm(projected)
  perp = data.R
  perp .-= projected
  d = norm(perp)^2
  # A residual in the support span has no reliable orthogonal direction.
  if sqrt(d) <= _SQRT_DUAL_ROUNDING * eps(T) * (oldnorm + projectednorm)
    d = zero(T)
  end
  β = _sqrt_residualpart(norm(base)^2, dot(base, perp), d)
  base .+= β .* perp
  _sqrt_vectordual(m, data, g, base)
end

function _sqnorm!(m::SqrtLSModel{T}, k::Int) where {T}
  a = m.a[k]
  if isnan(a)
    a = _column_sqnorm(m.X, k, m.xbar[k], m.w, m.N)
    m.a[k] = a
  end
  a
end

coordinate_scale(m::SqrtLSModel, x, k::Int) = sqrt(_sqnorm!(m, k) / m.N)
function response_scale(m::SqrtLSModel{T}, x) where {T}
  s = zero(T)
  w = m.w
  @inbounds for i in eachindex(m.y)
    d = m.y[i] - m.ybar
    s += w === nothing ? d * d : w[i] * d * d
  end
  sqrt(s / m.N)
end

loss_value(m::SqrtLSModel{T}, x) where {T} =
  m.w === nothing ? norm(m.r) : sqrt(sum(i -> m.w[i] * m.r[i]^2, eachindex(m.r); init = zero(T)))
loss_value(m::SqrtLSModel{T, <:SparseMatrixCSC}, x) where {T<:AbstractFloat} =
  m.w === nothing ? _shifted_norm(m.r, m.δ) :
                    sqrt(sum(i -> m.w[i] * (m.r[i] + m.δ)^2, eachindex(m.r); init = zero(T)))

function gradient!(G::AbstractVector{T}, m::SqrtLSModel{T}, x) where {T}
  if m.w === nothing
    mul!(G, transpose(m.X), m.r)
    G .= (m.xbar .* sum(m.r) .- G) ./ norm(m.r)
  else
    m.tmp .= m.w .* m.r
    mul!(G, transpose(m.X), m.tmp)
    G .= (m.xbar .* sum(m.tmp) .- G) ./ loss_value(m, x)
  end
  G
end

# the numerator does not change when a constant is added to r, with or without
# weights, since the columns are centered at their (weighted) means
function gradient!(G::AbstractVector{T}, m::SqrtLSModel{T, <:SparseMatrixCSC}, x) where {T<:AbstractFloat}
  if m.w === nothing
    mul!(G, transpose(m.X), m.r)
    G .= (m.xbar .* sum(m.r) .- G) ./ _shifted_norm(m.r, m.δ)
  else
    m.tmp .= m.w .* m.r
    mul!(G, transpose(m.X), m.tmp)
    G .= (m.xbar .* sum(m.tmp) .- G) ./ loss_value(m, x)
  end
  G
end

# ‖r .+ δ‖
function _shifted_norm(r::Vector{T}, δ::T) where {T}
  iszero(δ) && return norm(r)
  ρ = zero(T)
  @inbounds @simd for i in eachindex(r)
    ρ += (r[i] + δ) * (r[i] + δ)
  end
  sqrt(ρ)
end
