####################################
#
#  least squares  s ∑ᵢ wᵢ (yᵢ - oᵢ - Xᵢ'β)² / 2
#
####################################

# The model of LeastSquaresLoss (s = 1, w = 1, o = 0), of a GLMLoss with the
# Squared loss (weights w, offset o), and of either scaled by s. It caches the
# residuals r = y - o - Xβ, so a coordinate step costs O(n), and the weighted
# squared column norms, computed on the first visit to each coordinate after
# initialize!. With an intercept, the loss is minimized over an unpenalized
# intercept β₀ as well, whose minimizer is β₀ = ȳ - x̄'β for the column means x̄
# and the mean ȳ of y - o, both weighted by w; the columns and y are centered
# on the fly, so X is not copied, and the residuals keep ∑ᵢ wᵢ rᵢ = 0. A sparse
# X (SparseMatrixCSC) is read only at its nonzeros: a step costs O(nnz) of the
# column. Centering a sparse column would touch every residual, so with an
# intercept the model keeps r = y - o - ȳ - Xβ and the scalar δ = x̄'β apart, the
# residuals being r .+ δ (δ is zero otherwise).
mutable struct LSModel{T<:AbstractFloat, MX<:AbstractMatrix{T}, VY<:AbstractVector{T},
                       W<:Union{Nothing, AbstractVector{T}}, O<:Union{Nothing, AbstractVector{T}}} <: CDModel{T}
  X::MX
  y::VY
  w::W
  offset::O
  s::T
  r::Vector{T}
  a::Vector{T}          # ∑ᵢ wᵢ (Xᵢₖ - x̄ₖ)², NaN until computed
  xbar::Vector{T}       # (weighted) column means with an intercept, otherwise zeros
  ybar::T               # (weighted) mean of y - o with an intercept, otherwise zero
  L::Vector{T}          # curvatures of the groups of an AtomIterate, NaN until computed
  tmp::Vector{T}        # wᵢ rᵢ, for the gradient of a weighted loss: n entries with weights
  eig::_GroupEig{T}     # workspace of the group curvatures
  δ::T                  # the residuals are r .+ δ (a sparse X with an intercept)
  rbuf::Vector{T}       # r .+ δ, for residuals(m)
  wsum::T               # ∑ᵢ wᵢ (n without weights), for the centering of a sparse X
  gbuf::Vector{T}       # scratch space of the group steps, grown to the largest need
end

function LSModel(y::AbstractVector, X::AbstractMatrix, w, offset, s::Real; intercept::Bool = false)
  T = float(promote_type(eltype(y), eltype(X)))
  n, p = size(X)
  length(y) == n || throw(DimensionMismatch("X has $n rows and y has length $(length(y))"))
  Xt, yt = convert(AbstractMatrix{T}, X), convert(AbstractVector{T}, y)
  wt = w === nothing ? nothing : convert(AbstractVector{T}, w)
  ot = offset === nothing ? nothing : convert(AbstractVector{T}, offset)
  _check_finite(yt, "y"); _check_finite(Xt, "X")
  intercept && wt !== nothing && !(sum(wt) > 0) &&
    throw(ArgumentError("an intercept needs weights with a positive sum"))
  xbar = intercept ? _column_means(Xt, wt) : zeros(T, p)
  ybar = intercept ? _mean_response(yt, ot, wt) : zero(T)
  LSModel{T, typeof(Xt), typeof(yt), typeof(wt), typeof(ot)}(Xt, yt, wt, ot, T(s), zeros(T, n), fill(T(NaN), p),
                                                             xbar, ybar, T[], wt === nothing ? T[] : zeros(T, n),
                                                             _GroupEig{T}(), zero(T), T[],
                                                             wt === nothing ? T(n) : T(sum(wt)), T[])
end

_mean_response(y, ::Nothing) = sum(y) / length(y)
_mean_response(y, o) = (sum(y) - sum(o)) / length(y)
_mean_response(y, o, ::Nothing) = _mean_response(y, o)
_mean_response(y, ::Nothing, w::AbstractVector) = dot(w, y) / sum(w)
_mean_response(y, o, w::AbstractVector) = (dot(w, y) - dot(w, o)) / sum(w)

cdmodel(f::LeastSquaresLoss{T, <:AbstractVector}, x; intercept::Bool = false) where {T} =
  LSModel(f.Y, f.X, nothing, nothing, one(T); intercept)
cdmodel(f::Scaled{<:LeastSquaresLoss{T, <:AbstractVector}}, x; intercept::Bool = false) where {T} =
  LSModel(f.f.Y, f.f.X, nothing, nothing, f.α; intercept)
cdmodel(f::GLMLoss{ProximalBase.Squared}, x; intercept::Bool = false) =
  LSModel(f.y, f.X, f.weights, f.offset, 1; intercept)
cdmodel(f::Scaled{<:GLMLoss{ProximalBase.Squared}}, x; intercept::Bool = false) =
  LSModel(f.f.y, f.f.X, f.f.weights, f.f.offset, f.α; intercept)

"""
    intercept(m::CDModel, x)

The unpenalized intercept that goes with `x` in a least-squares model built
with `intercept = true` (see [`cdmodel`](@ref)); zero without one. For the
multi-response model of a matrix `Y`, the vector of the intercepts of the
responses.
"""
intercept(m::LSModel, x::AbstractArray) = m.ybar - dot(m.xbar, x)

"""
    residuals(m::CDModel)

The residuals `y - o - β₀ - Xβ` of a least-squares model, for the iterate it is
current for.
"""
residuals(m::LSModel) = m.r
residuals(m::LSModel{T, <:SparseMatrixCSC}) where {T<:AbstractFloat} = _shifted_residuals!(m.rbuf, m.r, m.δ)

# r .+ δ, into the buffer when δ is not zero
function _shifted_residuals!(rbuf::Vector{T}, r::Vector{T}, δ::T) where {T}
  iszero(δ) && return r
  resize!(rbuf, length(r))
  rbuf .= r .+ δ
end

_check_finite(A::AbstractArray, name::AbstractString) =
  all(isfinite, A) || throw(ArgumentError("$name contains NaN or Inf."))
_check_finite(A::SparseMatrixCSC, name::AbstractString) =
  all(isfinite, nonzeros(A)) || throw(ArgumentError("$name contains NaN or Inf."))

# the column means of X, weighted by w if given; a constant column gets its value
# exactly, so that it is exactly zero once centered (the computed mean can
# differ in the last bits)
function _column_means(X::AbstractMatrix{T}, w::Union{Nothing, AbstractVector} = nothing) where {T}
  n = size(X, 1)
  xbar = w === nothing ? Vector{T}(vec(sum(X; dims = 1)) ./ n) : Vector{T}((transpose(X) * w) ./ sum(w))
  n > 0 || return xbar
  for k in axes(X, 2)
    c = X[1, k]
    all(==(c), view(X, :, k)) && (xbar[k] = c)
  end
  xbar
end

# the same for a sparse X, from the stored entries: a column with an implicit
# zero is constant only when it stores zeros alone
function _column_means(X::SparseMatrixCSC{T}, w::Union{Nothing, AbstractVector} = nothing) where {T}
  n = size(X, 1)
  xbar = zeros(T, size(X, 2))
  n > 0 || return xbar
  rows, vals = rowvals(X), nonzeros(X)
  W = w === nothing ? T(n) : T(sum(w))
  for k in axes(X, 2)
    rng = nzrange(X, k)
    s = zero(T)
    for j in rng
      s += w === nothing ? vals[j] : w[rows[j]] * vals[j]
    end
    xbar[k] = s / W
    if length(rng) < n
      all(j -> iszero(vals[j]), rng) && (xbar[k] = zero(T))
    elseif !isempty(rng)
      c = vals[first(rng)]
      all(j -> vals[j] == c, rng) && (xbar[k] = c)
    end
  end
  xbar
end

# the entries of the active coordinates of x: the stored entries of a
# SparseIterate, the entries of the active groups of an AtomIterate
_activeentries(x::SparseIterate) = activecoordinates(x)
_activeentries(x::AtomIterate) = Iterators.flatten(x.groups[k] for k in activecoordinates(x))

initialize!(m::LSModel{T}, x::Union{SparseIterate{T}, AtomIterate{T}}) where {T} = _initialize!(m, x, true)

function _initialize!(m::LSModel{T}, x::Union{SparseIterate{T}, AtomIterate{T}}, curvatures::Bool) where {T}
  length(x) == size(m.X, 2) || throw(DimensionMismatch("x has length $(length(x)) and X has $(size(m.X, 2)) columns"))
  r, y, X = m.r, m.y, m.X
  if m.offset === nothing
    r .= y .- m.ybar
  else
    r .= y .- m.offset .- m.ybar
  end
  m.δ = zero(T)
  for k in _activeentries(x)
    v = x[k]
    iszero(v) && continue
    _residual_axpy!(m, k, v)
  end
  fill!(m.a, T(NaN))          # X may have changed in place
  curvatures && x isa AtomIterate && fill!(resize!(m.L, ncoordinates(x)), T(NaN))
  m
end

# Columns centered at c, where c is the column mean when the model fits an
# intercept and zero otherwise; a zero c takes the plain loops.

# (a, b) with b = (X[:, k] - c)' r and a = ‖X[:, k] - c‖², which is computed
# only when the cached a is NaN
@inline function _column_dot(X::AbstractMatrix{T}, r::AbstractVector{T}, k::Int, c::T, a::T) where {T}
  b = zero(T)
  if isnan(a)
    a = zero(T)
    if iszero(c)
      @inbounds @simd for i in eachindex(r)
        a += X[i, k] * X[i, k]
        b += r[i] * X[i, k]
      end
    else
      @inbounds @simd for i in eachindex(r)
        d = X[i, k] - c
        a += d * d
        b += r[i] * d
      end
    end
  elseif iszero(c)
    @inbounds @simd for i in eachindex(r)
      b += r[i] * X[i, k]
    end
  else
    @inbounds @simd for i in eachindex(r)
      b += r[i] * (X[i, k] - c)
    end
  end
  a, b
end

# the same with weights: b = ∑ᵢ wᵢ (Xᵢₖ - c) rᵢ and a = ∑ᵢ wᵢ (Xᵢₖ - c)²
@inline function _column_dot(X::AbstractMatrix{T}, r::AbstractVector{T}, w::AbstractVector{T}, k::Int, c::T,
                             a::T) where {T}
  b = zero(T)
  if isnan(a)
    a = zero(T)
    if iszero(c)
      @inbounds @simd for i in eachindex(r)
        a += X[i, k] * X[i, k] * w[i]
        b += r[i] * X[i, k] * w[i]
      end
    else
      @inbounds @simd for i in eachindex(r)
        d = X[i, k] - c
        a += d * d * w[i]
        b += r[i] * d * w[i]
      end
    end
  elseif iszero(c)
    @inbounds @simd for i in eachindex(r)
      b += r[i] * X[i, k] * w[i]
    end
  else
    @inbounds @simd for i in eachindex(r)
      b += r[i] * (X[i, k] - c) * w[i]
    end
  end
  a, b
end

# r -= h (X[:, k] - c)
@inline function _column_axpy!(r::AbstractVector{T}, X::AbstractMatrix{T}, k::Int, c::T, h::T) where {T}
  if iszero(c)
    @inbounds @simd for i in eachindex(r)
      r[i] -= X[i, k] * h
    end
  else
    @inbounds @simd for i in eachindex(r)
      r[i] -= (X[i, k] - c) * h
    end
  end
  r
end

# The kernels for a sparse X walk the nonzeros of column k. The residuals are
# r .+ δ, and with an intercept they sum to zero, so that
# b = (X[:, k] - c)' (r .+ δ) = X[:, k]' r + n c δ; ‖X[:, k] - c‖² is the sum of
# (Xᵢₖ - c)² over the nonzeros and (n - nnz) c² over the zeros. Without an
# intercept c and δ are zero, as they are with weights.
@inline function _column_dot(X::SparseMatrixCSC{T}, r::AbstractVector{T}, k::Int, c::T, a::T, δ::T) where {T}
  rows, vals = rowvals(X), nonzeros(X)
  rng = nzrange(X, k)
  b = zero(T)
  if isnan(a)
    a = zero(T)
    @inbounds for j in rng
      v = vals[j]
      b += r[rows[j]] * v
      a += (v - c) * (v - c)
    end
    a += (size(X, 1) - length(rng)) * c * c
  else
    @inbounds for j in rng
      b += r[rows[j]] * vals[j]
    end
  end
  iszero(c) || (b += size(X, 1) * c * δ)
  a, b
end

# the same with weights: the weighted residuals sum to zero with an intercept,
# so b = ∑ᵢ wᵢ (Xᵢₖ - c)(rᵢ + δ) = ∑ᵢ wᵢ Xᵢₖ rᵢ + W c δ, with W = ∑ᵢ wᵢ and c the
# weighted mean; ‖X[:, k] - c‖²_W adds (W - ∑ wᵢ over the nonzeros) c² for the zeros
@inline function _column_dot(X::SparseMatrixCSC{T}, r::AbstractVector{T}, w::AbstractVector{T}, k::Int, c::T,
                             a::T, δ::T, W::T) where {T}
  rows, vals = rowvals(X), nonzeros(X)
  rng = nzrange(X, k)
  b = zero(T)
  if isnan(a)
    a = zero(T)
    wnz = zero(T)
    @inbounds for j in rng
      i, v = rows[j], vals[j]
      b += r[i] * v * w[i]
      a += (v - c) * (v - c) * w[i]
      wnz += w[i]
    end
    a += _zeroweight(W, wnz, length(rng), size(X, 1)) * c * c
  else
    @inbounds for j in rng
      i = rows[j]
      b += r[i] * vals[j] * w[i]
    end
  end
  iszero(c) || (b += W * c * δ)
  a, b
end

# r -= h (X[:, k] - c); a centered column changes every entry
@inline function _column_axpy!(r::AbstractVector{T}, X::SparseMatrixCSC{T}, k::Int, c::T, h::T) where {T}
  rows, vals = rowvals(X), nonzeros(X)
  @inbounds for j in nzrange(X, k)
    r[rows[j]] -= vals[j] * h
  end
  iszero(c) || (r .+= c * h)
  r
end

# the weight of the zeros of a sparse column, W less the weights of the stored
# entries: none when every entry is stored, and never negative from rounding
@inline _zeroweight(W::T, wnz::T, nnz::Int, n::Int) where {T} = nnz == n ? zero(T) : max(W - wnz, zero(T))

# ∑ᵢ wᵢ (Xᵢₖ - c)², with w = nothing for unit weights and W = ∑ᵢ wᵢ
function _column_sqnorm(X::AbstractMatrix{T}, k::Int, c::T, w, W::T) where {T}
  a = zero(T)
  if w === nothing
    @inbounds @simd for i in axes(X, 1)
      a += (X[i, k] - c) * (X[i, k] - c)
    end
  else
    @inbounds @simd for i in axes(X, 1)
      a += (X[i, k] - c) * (X[i, k] - c) * w[i]
    end
  end
  a
end

function _column_sqnorm(X::SparseMatrixCSC{T}, k::Int, c::T, w, W::T) where {T}
  rows, vals = rowvals(X), nonzeros(X)
  rng = nzrange(X, k)
  a = zero(T)
  if w === nothing
    @inbounds for j in rng
      a += (vals[j] - c) * (vals[j] - c)
    end
    a += (size(X, 1) - length(rng)) * c * c
  else
    wnz = zero(T)
    @inbounds for j in rng
      i = rows[j]
      a += (vals[j] - c) * (vals[j] - c) * w[i]
      wnz += w[i]
    end
    a += _zeroweight(W, wnz, length(rng), size(X, 1)) * c * c
  end
  a
end

@inline _column_dot(m::LSModel, k::Int) = _column_dot(m, m.w, k)
@inline _column_dot(m::LSModel, ::Nothing, k::Int) = _column_dot(m.X, m.r, k, m.xbar[k], m.a[k])
@inline _column_dot(m::LSModel{T, <:SparseMatrixCSC}, ::Nothing, k::Int) where {T<:AbstractFloat} =
  _column_dot(m.X, m.r, k, m.xbar[k], m.a[k], m.δ)
@inline _column_dot(m::LSModel, w::AbstractVector, k::Int) = _column_dot(m.X, m.r, w, k, m.xbar[k], m.a[k])
@inline _column_dot(m::LSModel{T, <:SparseMatrixCSC}, w::AbstractVector, k::Int) where {T<:AbstractFloat} =
  _column_dot(m.X, m.r, w, k, m.xbar[k], m.a[k], m.δ, m.wsum)

# the residuals after a step h of coordinate k: r -= h (X[:, k] - x̄ₖ), or for a
# sparse X, r -= h X[:, k] and δ += h x̄ₖ
@inline _residual_axpy!(m::LSModel{T}, k::Int, h::T) where {T} = _column_axpy!(m.r, m.X, k, m.xbar[k], h)
@inline function _residual_axpy!(m::LSModel{T, <:SparseMatrixCSC}, k::Int, h::T) where {T<:AbstractFloat}
  _column_axpy!(m.r, m.X, k, zero(T), h)
  m.δ += h * m.xbar[k]
  m.r
end

# ∑ᵢ wᵢ (Xᵢₖ - x̄ₖ)², from the cache, computed and cached if needed
function _sqnorm!(m::LSModel{T}, k::Int) where {T}
  a = m.a[k]
  if isnan(a)
    a = _column_sqnorm(m.X, k, m.xbar[k], m.w, m.wsum)
    m.a[k] = a
  end
  a
end

# the coordinate goes to xₖ + b/a, with step 1/(s a) for the penalty; a column
# that the loss does not depend on (a zero column, or a constant one with an
# intercept) gets the minimizer of the penalty nearest zero
@inline function coordinate_step!(m::LSModel{T}, g, x::SparseIterate{T}, k::Int) where {T}
  a, b = _column_dot(m, k)
  m.a[k] = a
  old = x[k]
  new = iszero(a) ? prox_entry(g, zero(T), k, floatmax(T)) : prox_entry(g, old + b / a, k, inv(m.s * a))
  h = new - old
  iszero(h) && return h      # x and the residuals do not change
  x[k] = new
  _residual_axpy!(m, k, h)
  h
end

function coordinate_derivatives(m::LSModel{T}, x::SparseIterate{T}, k::Int) where {T}
  a, b = _column_dot(m, k)
  m.a[k] = a
  -m.s * b, m.s * a
end

update_cache!(m::LSModel{T}, x::SparseIterate{T}, k::Int, h::T) where {T} = (_residual_axpy!(m, k, h); m)

# the residuals are affine in β, also with the centering of an intercept; so are
# r and δ = x̄'β for a sparse X: momentum moves r, and δ is computed at the point
_cache(m::LSModel) = m.r
_cache_moved!(m::LSModel{T, <:SparseMatrixCSC}, x::SparseIterate{T}) where {T<:AbstractFloat} =
  (m.δ = _dot_active(m.xbar, x); m)

# x̄'x over the stored entries of x
function _dot_active(c::Vector{T}, x::SparseIterate{T}) where {T}
  s = zero(T)
  for k in activecoordinates(x)
    s += c[k] * x[k]
  end
  s
end

coordinate_scale(m::LSModel, x, k::Int) = sqrt(m.s * _sqnorm!(m, k))

function response_scale(m::LSModel{T}, x) where {T}
  y, o, w, ȳ = m.y, m.offset, m.w, m.ybar
  s = zero(T)
  @inbounds for i in eachindex(y)
    d = (o === nothing ? y[i] : y[i] - o[i]) - ȳ
    s += (w === nothing ? d * d : w[i] * d * d)
  end
  sqrt(m.s * s)
end

function loss_value(m::LSModel{T}, x) where {T}
  r, w = m.r, m.w
  v = zero(T)
  if w === nothing
    @inbounds @simd for i in eachindex(r)
      v += r[i] * r[i]
    end
  else
    @inbounds @simd for i in eachindex(r)
      v += w[i] * r[i] * r[i]
    end
  end
  m.s * v / 2
end

function loss_value(m::LSModel{T, <:SparseMatrixCSC}, x) where {T<:AbstractFloat}
  r, w, δ = m.r, m.w, m.δ
  v = zero(T)
  if w === nothing
    @inbounds @simd for i in eachindex(r)
      v += (r[i] + δ) * (r[i] + δ)
    end
  else
    @inbounds @simd for i in eachindex(r)
      v += w[i] * (r[i] + δ) * (r[i] + δ)
    end
  end
  m.s * v / 2
end

# -s (X - 1x̄')' W r, with one product; the same from r for a sparse X, since the
# product with centered columns does not change when a constant is added to r
function gradient!(G::AbstractVector{T}, m::LSModel{T}, x) where {T}
  if m.w === nothing
    mul!(G, transpose(m.X), m.r)
    sr = sum(m.r)
    G .= m.s .* (m.xbar .* sr .- G)
  else
    m.tmp .= m.w .* m.r
    mul!(G, transpose(m.X), m.tmp)
    swr = sum(m.tmp)
    G .= m.s .* (m.xbar .* swr .- G)
  end
  G
end

# the curvature of f over group k of x, s λmax((X[:, G] - 1x̄_G')' W (X[:, G] - 1x̄_G')),
# from the cache, computed and cached if needed
function _groupcurvature!(m::LSModel{T}, x::AtomIterate{T}, k::Int) where {T}
  L = m.L[k]
  if isnan(L)
    G = x.groups[k]
    L = length(G) == 1 ? m.s * _sqnorm!(m, first(G)) : max(m.s * _gram_eigmax!(m, x, G), zero(T))
    L = T(L)
    m.L[k] = L
  end
  L
end

# λmax((X[:, G] - 1x̄_G')' W (X[:, G] - 1x̄_G')), for least squares
function _gram_eigmax!(m::LSModel{T}, x::AtomIterate{T}, G) where {T<:Union{Float32, Float64}}
  q = length(G)
  ws = m.eig.nmax >= q ? m.eig : _reserve!(m.eig, _maxgroup(x), size(m.X, 1))
  B = view(ws.B, :, 1:q)
  X, w = m.X, m.w
  for (i, j) in enumerate(G)
    c = m.xbar[j]
    if w === nothing
      @views B[:, i] .= X[:, j] .- c
    else
      @views B[:, i] .= (X[:, j] .- c) .* sqrt.(w)
    end
  end
  BLAS.syrk!('U', 'T', one(T), B, zero(T), reshape(view(ws.C, 1:q^2), q, q))
  L = _eigmax!(ws, q)
  L === nothing ? _eigmax_all(transpose(B) * B) : L
end

function _gram_eigmax!(m::LSModel{T}, x::AtomIterate{T}, G) where {T}
  XG = Matrix(m.X[:, G] .- transpose(m.xbar[G]))
  m.w === nothing || (XG .*= sqrt.(m.w))
  _eigmax_generic(XG' * XG)
end

# group k of x ← the proximal operator of λ0 wₖ ‖⋅‖₂ with step 1/L at
# x[G] - ∇_G f(x) / L, where L is the curvature of f over G, so that the
# quadratic with curvature L majorizes f over the group (groupwise majorization
# descent, Yang and Zou, 2015). A group at zero stays there if
# ‖∇_G f(x)‖ ≤ λ0 wₖ, whatever L, which is then not needed. Returns the largest
# change of an entry, scaled with `scaled`; u is a buffer of at least |G| entries.
function _groupstep!(m::LSModel{T}, g::GroupNormL2, x::AtomIterate{T}, k::Int, scaled::Bool) where {T}
  G = x.groups[k]
  c = T(g.λ0 * g.w[k])
  u = _groupbuffer!(m, length(G))

  # u = -∇_G f(x) / s, where ∇ⱼf(x) = -s (X[:, j] - x̄ⱼ)' W r
  t = zero(T)
  for (i, j) in enumerate(G)
    a, b = _column_dot(m, j)
    m.a[j] = a
    u[i] = b
    t += b * b
  end
  !isactive(x, k) && m.s * sqrt(t) <= c && return zero(T)

  # u = x[G] - ∇_G f(x) / L
  L = _groupcurvature!(m, x, k)
  t = zero(T)
  for (i, j) in enumerate(G)
    v = iszero(L) ? x[j] : x[j] + m.s * u[i] / L
    u[i] = v
    t += v * v
  end

  shrink = _groupshrink(sqrt(t), c, L)
  maxh = zero(T)
  for (i, j) in enumerate(G)
    new = shrink * u[i]
    h = new - x[j]
    iszero(h) && continue
    x[j] = new
    _residual_axpy!(m, j, h)
    maxh = max(maxh, _scaledchange(m, x, j, h, scaled))
  end
  maxh
end

# a buffer of at least n entries for the group steps, kept in the model; it is
# not m.tmp, which the gradient of a weighted model needs at n entries
_groupbuffer!(m::LSModel{T}, n::Int) where {T} = (length(m.gbuf) < n && resize!(m.gbuf, n); m.gbuf)
