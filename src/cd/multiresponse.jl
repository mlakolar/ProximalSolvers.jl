using ProximalBase: leastsquares_data
# Least squares for a matrix response: the loss (s/2)‖Y − XB‖_F² for X (n × p), Y (n × K) and B (p × K),
# iterated as a BlockIterate over vec(B) whose group j is row j of B, the entries j, j + p, …, j + (K − 1) p
# (`solve!` checks this layout). The loss scale `s` has the type of `LSModel`'s. X and Y are borrowed, not
# copied. `R` is the residual Y − XB. `a[j]` is the squared norm of column j of X, in `T`, and is NaN until
# `_prepare!` computes it. `old`, `u` and `b` are the K-long scratch vectors of the row step, and `fit` is the
# p × K copy of the iterate from which `loss_value` takes the objective. `solve!` refuses `momentum = true`
# for this model, and `_usemomentum` is false for a BlockIterate otherwise.
mutable struct MLSModel{T<:AbstractFloat, S<:AbstractFloat, MX<:AbstractMatrix{T}, MY<:AbstractMatrix{T}} <: CDModel{T}
  X::MX
  y::MY
  s::S
  R::Matrix{T}
  a::Vector{T}
  old::Vector{T}
  u::Vector{T}
  b::Vector{T}
  fit::Matrix{T}
end
function cdmodel(f::Union{LeastSquaresLoss{T, <:AbstractMatrix}, Scaled{<:LeastSquaresLoss{T, <:AbstractMatrix}}}, x::BlockIterate{T}) where T
  d = leastsquares_data(f)
  n, p = size(d.X)
  K = size(d.Y, 2)
  MLSModel(d.X, d.Y, convert(_scale_type(T, d.α), d.α), Matrix{T}(undef, n, K), fill(T(NaN), p),
    Vector{T}(undef, K), Vector{T}(undef, K), Vector{T}(undef, K), Matrix{T}(undef, p, K))
end
# R = Y − Σⱼ X[:, j] B[j, :] over the active rows. The loops index the matrices directly instead of passing
# views of their columns.
function initialize!(m::MLSModel{T}, x::BlockIterate{T}) where T
  X, R = m.X, m.R
  length(x) == size(X, 2)*size(R, 2) ||
    throw(DimensionMismatch("iterate length differs from the number of coefficients of X and Y"))
  copyto!(R, m.y)
  for j in activecoordinates(x)
    idx = blockindices(x, j)
    for c in eachindex(idx)
      v = x[idx[c]]
      iszero(v) || _residual_update!(R, c, X, Int(j), v)
    end
  end
  fill!(m.a, T(NaN))
  m
end
# R[:, c] −= X[:, j] h
@inline function _residual_update!(R::AbstractMatrix{T}, c::Int, X::AbstractMatrix{T}, j::Int, h::T) where T
  @inbounds @simd for i in axes(R, 1)
    R[i, c] -= X[i, j]*h
  end
  R
end
# X[:, j]ᵀ R[:, c]
@inline function _column_correlation(X::AbstractMatrix{T}, R::AbstractMatrix{T}, j::Int, c::Int) where T
  b = zero(T)
  @inbounds @simd for i in axes(R, 1)
    b += X[i, j]*R[i, c]
  end
  b
end
function _zero_column(X::AbstractMatrix, j::Int)
  @inbounds for i in axes(X, 1)
    iszero(X[i, j]) || return false
  end
  true
end

# Per-solve preparation, run where maxpasses > 0, before the first pass and the first random draw. It sets
# the curvature a[j] of every row, the squared norm of column j of X summed in order in `T`. A column of zeros
# has a[j] = 0. A column with a nonzero entry is refused with an `ArgumentError` naming the row where a[j] is
# not finite or is below floatmin(T), or where the step band of `_check_step_band` fails. `_prepare!` changes
# neither the coefficients nor the residual.
function _prepare!(m::MLSModel{T}, g::GroupNormL2, x::BlockIterate{T}) where T
  X = m.X
  for j in 1:size(X, 2)
    a = zero(T)
    @inbounds for i in axes(X, 1)
      a += X[i, j]*X[i, j]
    end
    if iszero(a)
      _zero_column(X, j) || _refuse_row_curvature(T, j, false)
    elseif !isfinite(a)
      _refuse_row_curvature(T, j, true)
    elseif a < floatmin(T)
      _refuse_row_curvature(T, j, false)
    else
      _check_step_band(m, a, j)
    end
    m.a[j] = a
  end
  m
end
# The throws are out of line, so that the success path carries no string interpolation.
@noinline function _refuse_row_curvature(::Type{T}, j::Int, overflow::Bool) where T
  overflow && throw(ArgumentError("the curvature of row $j (the squared norm of column $j of X) is not finite in $T; rescale the data"))
  throw(ArgumentError("the curvature of row $j (the squared norm of column $j of X) is below floatmin($T); rescale the data or loss"))
end

# The row step. With a = ‖X[:, j]‖² > 0, b = X[:, j]ᵀR (one entry per response) and the trial point
# u = B[j, :] + b/a, the new row is `prox_block!(u, g, u, j, 1/(s a))`. In exact arithmetic that is the
# minimizer of the loss plus the penalty over row j, because the loss is quadratic in the row with Hessian
# s a I. In exact arithmetic, a fixed point B[j, :] = prox(B[j, :] + b/a′, 1/(s a′)) satisfies
# s b ∈ λ w_j ∂‖B[j, :]‖ for any positive a′ used in both places, so the rounding of a changes how the iteration
# approaches a fixed point and not which points are fixed. A column of zeros (a = 0)
# takes `prox_block!` at the step Inf: the zero row for a positive level and weight, and the row itself where
# the level or the weight is 0. A trial point or a displacement that is not finite is refused before the row
# or the residual changes. A row whose displacement is 0 is not written, which keeps an inactive row
# inactive. Otherwise the row is written with one `copyto!` of `u` and each response with a nonzero
# displacement updates its column of R. The step returns the 2-norm of the displacement.
function coordinate_step!(m::MLSModel{T}, g::GroupNormL2, x::BlockIterate{T}, j::Int) where T
  X, R = m.X, m.R
  K = size(R, 2)
  idx = blockindices(x, j)
  old, u, b = m.old, m.u, m.b
  for c in 1:K
    old[c] = x[idx[c]]
  end
  a = m.a[j]
  if iszero(a)
    prox_block!(u, g, old, j, Inf)
  else
    for c in 1:K
      b[c] = _column_correlation(X, R, j, c)
    end
    for c in 1:K
      v = old[c] + b[c]/a
      isfinite(v) || _refuse_block_value(T, j)
      u[c] = v
    end
    prox_block!(u, g, u, j, inv(m.s*a))
  end
  moved = false
  for c in 1:K
    d = u[c] - old[c]
    isfinite(d) || _refuse_block_value(T, j)
    old[c] = d
    iszero(d) || (moved = true)
  end
  moved || return zero(T)
  copyto!(blockview(x, j), u)
  for c in 1:K
    iszero(old[c]) || _residual_update!(R, c, X, j, old[c])
  end
  norm(old)
end
# The stopping scale of row j is √(s a[j]), through the range-safe formula of `_curvature_scale`; it is 0 for
# a column of zeros. `response_scale` is that of `LSModel`, with the response Y in place of y, and the loss
# value is ProximalBase's, at a p × K copy of the iterate, so it does not depend on the cached residual.
coordinate_scale(m::MLSModel, x, j::Int) = _curvature_scale(m, m.a[j])
function loss_value(m::MLSModel, f, x)
  fit = m.fit
  @inbounds for i in eachindex(fit)
    fit[i] = x[i]
  end
  f(fit)
end
