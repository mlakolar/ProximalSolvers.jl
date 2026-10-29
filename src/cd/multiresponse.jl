####################################
#
#  multi-response least squares  s ‖Y - 1β₀' - XB‖²_F / 2
#
####################################

# The model of a LeastSquaresLoss with an n × q matrix Y, of a p × q matrix B,
# iterated as an AtomIterate over vec(B) whose groups are the rows of B: entries
# k, k + p, …, k + (q - 1)p for row k, as in `[k:p:p*q for k in 1:p]`. With
# GroupNormL2 on these groups it is the multi-response lasso, which selects the
# same predictors for all the responses. It caches the residuals
# R = Y - 1β₀' - XB, so that a step on a row costs O(nq), and the squared norms
# of the centered columns of X: the curvature of the loss over row k is exactly
# s ‖X[:, k] - x̄ₖ‖² times the identity, so each block step minimizes the loss
# plus the penalty over the row exactly. With an intercept, β₀ = ȳ - B'x̄
# minimizes the loss for each response, and X and Y are centered on the fly.
mutable struct MLSModel{T<:AbstractFloat, MX<:AbstractMatrix{T}, MY<:AbstractMatrix{T}} <: CDModel{T}
  X::MX
  Y::MY
  s::T
  R::Matrix{T}
  a::Vector{T}          # ‖X[:, k] - x̄ₖ‖², NaN until computed
  xbar::Vector{T}       # column means with an intercept, otherwise zeros
  ybar::Vector{T}       # response means with an intercept, otherwise zeros
  u::Vector{T}          # the row of a block step
end

function MLSModel(Y::AbstractMatrix, X::AbstractMatrix, s::Real; intercept::Bool = false)
  T = float(promote_type(eltype(Y), eltype(X)))
  n, p = size(X)
  q = size(Y, 2)
  size(Y, 1) == n || throw(DimensionMismatch("X has $n rows and Y has $(size(Y, 1))"))
  Xt, Yt = convert(AbstractMatrix{T}, X), convert(AbstractMatrix{T}, Y)
  _check_finite(Yt, "Y"); _check_finite(Xt, "X")
  xbar = intercept ? _column_means(Xt) : zeros(T, p)
  ybar = intercept ? Vector{T}(vec(sum(Yt; dims = 1)) ./ n) : zeros(T, q)
  MLSModel{T, typeof(Xt), typeof(Yt)}(Xt, Yt, T(s), zeros(T, n, q), fill(T(NaN), p), xbar, ybar, zeros(T, q))
end

cdmodel(f::LeastSquaresLoss{T, <:AbstractMatrix}, x; intercept::Bool = false) where {T} =
  MLSModel(f.Y, f.X, one(T); intercept)
cdmodel(f::Scaled{<:LeastSquaresLoss{T, <:AbstractMatrix}}, x; intercept::Bool = false) where {T} =
  MLSModel(f.f.Y, f.f.X, f.α; intercept)

_rowgroups(p::Int, q::Int) = [collect(k:p:p*q) for k in 1:p]
_default_iterate(f::LeastSquaresLoss{T, <:AbstractMatrix}) where {T} =
  AtomIterate(T, size(f.X, 2) * size(f.Y, 2), _rowgroups(size(f.X, 2), size(f.Y, 2)))
_default_iterate(m::MLSModel{T}) where {T} = AtomIterate(T, size(m.X, 2) * size(m.Y, 2), _rowgroups(size(m.X, 2), size(m.Y, 2)))

# the model takes GroupNormL2 on the rows of B only
function check_penalty(m::MLSModel, g)
  p, q = size(m.X, 2), size(m.Y, 2)
  g isa GroupNormL2 ||
    throw(ArgumentError("the multi-response least-squares model takes GroupNormL2 on the rows of B, but g is a $(typeof(g))."))
  length(g.groups) == p && all(k -> g.groups[k] == k:p:p*q, 1:p) ||
    throw(ArgumentError("the groups of g must be the rows of the $p × $q matrix B: [k:p:p*q for k in 1:p]."))
  nothing
end

function initialize!(m::MLSModel{T}, x::AtomIterate{T}) where {T}
  X, Y, R = m.X, m.Y, m.R
  p, q = size(X, 2), size(Y, 2)
  length(x) == p * q || throw(DimensionMismatch("x has length $(length(x)) and B is $p × $q"))
  @inbounds for c in 1:q
    ȳ = m.ybar[c]
    @simd for i in axes(Y, 1)
      R[i, c] = Y[i, c] - ȳ
    end
  end
  for k in activecoordinates(x)
    for (c, j) in enumerate(x.groups[k])
      v = x[j]
      iszero(v) || _residual_axpy!(R, c, X, k, m.xbar[k], v)
    end
  end
  fill!(m.a, T(NaN))          # X may have changed in place
  m
end

# R[:, c] -= (X[:, k] - x̄ₖ) h, written on the matrix rather than on a view of
# the column, which Julia 1.10 allocates when it passes the view on
@inline function _residual_axpy!(R::Matrix{T}, c::Int, X::AbstractMatrix{T}, k::Int, xb::T, h::T) where {T}
  if iszero(xb)
    @inbounds @simd for i in axes(R, 1)
      R[i, c] -= X[i, k] * h
    end
  else
    @inbounds @simd for i in axes(R, 1)
      R[i, c] -= (X[i, k] - xb) * h
    end
  end
  R
end

# ‖X[:, k] - x̄ₖ‖², from the cache, computed and cached if needed
function _sqnorm!(m::MLSModel{T}, k::Int) where {T}
  a = m.a[k]
  if isnan(a)
    a = zero(T)
    X, c = m.X, m.xbar[k]
    @inbounds @simd for i in axes(X, 1)
      a += (X[i, k] - c) * (X[i, k] - c)
    end
    m.a[k] = a
  end
  a
end

# row k of B ← the proximal operator of λ0 wₖ ‖⋅‖₂ with step 1/L at
# B[k, :] - ∇_k f / L, L = s ‖X[:, k] - x̄ₖ‖² the exact curvature over the row.
# A row at zero stays there if ‖∇_k f‖ ≤ λ0 wₖ. Returns the largest change of
# an entry, scaled with `scaled`.
function _groupstep!(m::MLSModel{T}, g::GroupNormL2, x::AtomIterate{T}, k::Int, scaled::Bool) where {T}
  X, R, u = m.X, m.R, m.u
  G = x.groups[k]
  c = T(g.λ0 * g.w[k])
  xb = m.xbar[k]

  # u = -∇_k f / s = (X[:, k] - x̄ₖ)' R
  t = zero(T)
  @inbounds for ci in eachindex(G)
    b = zero(T)
    @simd for i in axes(X, 1)
      b += (X[i, k] - xb) * R[i, ci]
    end
    u[ci] = b
    t += b * b
  end
  !isactive(x, k) && m.s * sqrt(t) <= c && return zero(T)

  # u = B[k, :] - ∇_k f / L
  L = m.s * _sqnorm!(m, k)
  t = zero(T)
  @inbounds for (ci, j) in enumerate(G)
    v = iszero(L) ? x[j] : x[j] + m.s * u[ci] / L
    u[ci] = v
    t += v * v
  end

  shrink = _groupshrink(sqrt(t), c, L)
  maxh = zero(T)
  for (ci, j) in enumerate(G)
    new = shrink * u[ci]
    h = new - x[j]
    iszero(h) && continue
    x[j] = new
    _residual_axpy!(R, ci, X, k, xb, h)
    maxh = max(maxh, _scaledchange(m, x, j, h, scaled))
  end
  maxh
end

# entry j of vec(B) is in row mod1(j, p)
coordinate_scale(m::MLSModel, x, j::Int) = sqrt(m.s * _sqnorm!(m, mod1(j, size(m.X, 2))))

function response_scale(m::MLSModel{T}, x) where {T}
  Y, v = m.Y, zero(T)
  @inbounds for c in axes(Y, 2)
    ȳ = m.ybar[c]
    for i in axes(Y, 1)
      v += (Y[i, c] - ȳ) * (Y[i, c] - ȳ)
    end
  end
  sqrt(m.s * v)
end

function loss_value(m::MLSModel{T}, x) where {T}
  v = zero(T)
  @inbounds @simd for i in eachindex(m.R)
    v += m.R[i] * m.R[i]
  end
  m.s * v / 2
end

# the gradient over vec(B): -s (X - 1x̄')'R
function gradient!(G::AbstractVector{T}, m::MLSModel{T}, x) where {T}
  X, R = m.X, m.R
  p, q = size(X, 2), size(R, 2)
  Gm = reshape(G, p, q)
  mul!(Gm, transpose(X), R)
  @inbounds for c in 1:q
    sr = zero(T)
    for i in axes(R, 1)
      sr += R[i, c]
    end
    iszero(sr) && continue
    for k in 1:p
      Gm[k, c] -= m.xbar[k] * sr
    end
  end
  G .*= -m.s
end

# β₀ = ȳ - B'x̄, one intercept per response
function intercept(m::MLSModel{T}, x::AbstractArray) where {T}
  p, q = size(m.X, 2), size(m.Y, 2)
  b = copy(m.ybar)
  for c in 1:q, k in 1:p
    v = x[(c - 1) * p + k]
    iszero(v) || (b[c] -= m.xbar[k] * v)
  end
  b
end

residuals(m::MLSModel) = m.R

# R = Y - 1ȳ' - (X - 1x̄')B is affine in B, with or without an intercept (x̄ and
# ȳ are zero without one), so momentum (momentum = true; it is off by default on
# an AtomIterate) moves it with the point instead of initializing the model there
_cache(m::MLSModel) = m.R
