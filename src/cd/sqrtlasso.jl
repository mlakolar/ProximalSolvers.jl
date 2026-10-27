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
relative duality gap of the dual point `t r/‖r‖` (see [`duality_gap`](@ref) for
its meaning) is at most `gaptol`, or `1e-4` with the default `gaptol = 0`; the
results report this gap. That dual point cannot certify an exact or nearly
exact fit with a positive penalty, which is reported as not converged. With a
coordinate without penalty (a zero weight or level), the dual point exists
only where its derivative vanishes; otherwise the rule on the changes decides
alone and exact fits are not detected.
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
  N::T                  # n, or ∑ᵢ wᵢ: the scales of the stopping rule are per observation
  tmp::Vector{T}        # wᵢ rᵢ, for the gradient of a weighted loss
  δ::T                  # the residuals are r .+ δ (a sparse X with an intercept)
  rbuf::Vector{T}       # r .+ δ, for residuals(m)
  grad::Vector{T}       # ∇f, for the duality gap at the end of a run
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
                                                  intercept ? _mean_response(y, nothing, w) : zero(T), N,
                                                  w === nothing ? T[] : zeros(T, length(y)), zero(T), T[], zeros(T, p))
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

# The square-root losses f = ‖r‖ are not differentiable where r = 0. Near a
# nearly exact fit the curvature along a coordinate, about 1/‖r‖, far exceeds
# the scale of the stopping rule, so tiny coordinate changes do not show that x
# is a minimizer: with p ≥ n and a small penalty they can stop at several times
# the minimum. A stop is accepted only with a relative duality gap. Since
# ∇f(x) = -X̃'r/‖r‖ (centered and weighted with an intercept and weights),
# θ = t r/‖r‖ is dual feasible for t = _dualscale(g, ∇f(x)), with dual value
# θ'ỹ = t (f(x) - ∇f(x)'x); this holds for any norm ‖ỹ - X̃x‖, so for
# SqrtQuadraticFunction too. Its residual direction cannot certify an exact or
# nearly exact fit, which is then reported as not converged.
# Match the default objective-accuracy target of penalty paths. An explicit
# positive gaptol overrides this target; tol still controls coordinate changes.
const _SQRT_GAPCHECK = 1e-4

_certified!(st, m::SqrtLSModel, g, x, s) = _sqrt_certified!(st, m, g, x, s)

function _sqrt_certified!(st, m, g, x, s)
  T = eltype(m)
  f = loss_value(m, x)
  P = f + T(g(x))
  D = zero(T)
  if f > 0
    G = gradient!(m.grad, m, x)
    t = _dualscale(g, G)
    if t === nothing
      # a coordinate without penalty and a nonzero gradient: no dual point, and
      # the rule on the changes decides, as for the other losses
      st.relgap = T(NaN)
      return true
    end
    Gx = zero(T)
    for k in eachindex(G)
      xk = x[k]
      iszero(xk) || (Gx += G[k] * xk)
    end
    D = t * (f - Gx)
  end
  st.relgap = _relative_gap(P, D)
  st.relgap <= (s.gaptol > 0 ? s.gaptol : _SQRT_GAPCHECK)
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
