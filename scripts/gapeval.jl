# #320 Stage 2, candidate C: an experimental widened lasso gap evaluator (research only; not part
# of the package). Problem: F(x) = s‖y - Xx‖²/2 + λ‖x‖₁ with unweighted NormL1, data X, y, s, λ
# as the solver received them (element type T), coefficients x::Vector{T}.
#
# Everything is computed in Float64 from the stored T values; no rounded T product of the solver
# is reused. For T = Float32 every product X[i,j]*x[j] is exact in Float64 (24 + 24 bits), so the
# only rounding in X*x and Xᵀr is the Float64 summation.
#
# Dual point (as STOP-13): θ = κ s r, r = y - Xx, κ = min(1, λ / (s‖Xᵀr‖∞)) (κ = 1 when Xᵀr = 0).
# Two algebraically equal forms of the gap P - D(θ), D(θ) = ⟨θ, y⟩ - ‖θ‖²/(2s):
#   :pd        P - D computed directly;
#   :identity  (1-κ)² f + (1-κ) λ‖x‖₁ + κ (λ‖x‖₁ + ⟨∇f, x⟩), ∇f = -s Xᵀr  (no P - D cancellation).
# The relative gap is gap / P; at P = 0 it is 0 when the gap is 0 (then x = 0 and y = 0).
# This is a floating-point evaluation, not a rigorous certificate: the computed Xᵀr can make θ
# infeasible by a few Float64 ulps, and r carries Float64 summation error.
module GapEval320
using LinearAlgebra

export GapWork, gap_widened!, gap_widened_blas!, gap_rounded, GapResult

struct GapResult
  P::Float64
  D::Float64
  gap_pd::Float64
  gap_id::Float64
  rel::Float64      # max(gap_id, 0) / P (0 at P = gap = 0)
  rel_pd::Float64
  kappa::Float64
  status::Symbol    # :ok, :zero_objective, :nonfinite
end

struct GapWork
  r::Vector{Float64}
  z::Vector{Float64}
end
GapWork(n::Integer, p::Integer) = GapWork(zeros(n), zeros(p))

# r = y - X x, widened on the fly (no copy of X); zero coefficients are skipped (an exact no-op).
function residual_widened!(r::Vector{Float64}, X::AbstractMatrix, y::AbstractVector, x::AbstractVector)
  @inbounds for i in eachindex(r)
    r[i] = Float64(y[i])
  end
  @inbounds for j in axes(X, 2)
    xj = Float64(x[j])
    iszero(xj) && continue
    @simd for i in axes(X, 1)
      r[i] = muladd(-Float64(X[i, j]), xj, r[i])
    end
  end
  r
end

# z = Xᵀ r, widened on the fly.
function xtr_widened!(z::Vector{Float64}, X::AbstractMatrix, r::Vector{Float64})
  @inbounds for j in axes(X, 2)
    acc = 0.0
    @simd for i in axes(X, 1)
      acc = muladd(Float64(X[i, j]), r[i], acc)
    end
    z[j] = acc
  end
  z
end

function _finish(r, z, x, y, s::Float64, λ::Float64)
  rr = 0.0; ry = 0.0
  @inbounds for i in eachindex(r)
    rr = muladd(r[i], r[i], rr)
    ry = muladd(r[i], Float64(y[i]), ry)
  end
  l1 = 0.0; zx = 0.0; zmax = 0.0
  @inbounds for j in eachindex(z)
    xj = Float64(x[j])
    l1 += abs(xj)
    zx = muladd(z[j], xj, zx)
    zmax = max(zmax, abs(z[j]))
  end
  f = s * rr / 2
  P = f + λ * l1
  κ = s * zmax <= λ ? 1.0 : λ / (s * zmax)
  D = κ * s * ry - κ^2 * s * rr / 2
  gap_pd = P - D
  gap_id = (1 - κ)^2 * f + (1 - κ) * λ * l1 + κ * (λ * l1 - s * zx)
  if !(isfinite(P) && isfinite(D) && isfinite(gap_id))
    return GapResult(P, D, gap_pd, gap_id, NaN, NaN, κ, :nonfinite)
  end
  if iszero(P)
    return GapResult(P, D, gap_pd, gap_id, iszero(gap_id) ? 0.0 : Inf, iszero(gap_pd) ? 0.0 : Inf, κ, :zero_objective)
  end
  GapResult(P, D, gap_pd, gap_id, max(gap_id, 0.0) / P, max(gap_pd, 0.0) / P, κ, :ok)
end

"""
    gap_widened!(work, X, y, s, λ, x) -> GapResult

On-the-fly widening (variant W1): two Float64 passes over the T matrix, no allocation.
"""
function gap_widened!(work::GapWork, X::AbstractMatrix, y::AbstractVector, s, λ, x::AbstractVector)
  residual_widened!(work.r, X, y, x)
  xtr_widened!(work.z, X, work.r)
  _finish(work.r, work.z, x, y, Float64(s), Float64(λ))
end

"""
    gap_widened_blas!(work, X64, y, s, λ, x, x64) -> GapResult

Variant W2: a caller-held Float64 copy `X64` of the T matrix (n×p extra Float64 storage) and BLAS
products. `x64` is a length-p Float64 buffer.
"""
function gap_widened_blas!(work::GapWork, X64::Matrix{Float64}, y::AbstractVector, s, λ, x::AbstractVector,
                           x64::Vector{Float64})
  @inbounds for j in eachindex(x64)
    x64[j] = Float64(x[j])
  end
  @inbounds for i in eachindex(work.r)
    work.r[i] = Float64(y[i])
  end
  mul!(work.r, X64, x64, -1.0, 1.0)
  mul!(work.z, transpose(X64), work.r)
  _finish(work.r, work.z, x, y, Float64(s), Float64(λ))
end

"""
    gap_rounded(X, y, s, λ, x) -> GapResult

Comparator R32: reuses rounded products in the data type T (r = y - X*x and Xᵀr with T BLAS, as a
solver holding its T image would), then forms the gap in Float64 from those rounded vectors.
"""
function gap_rounded(X::AbstractMatrix{T}, y::AbstractVector{T}, s, λ, x::AbstractVector{T}) where T
  rT = y - X * x
  zT = transpose(X) * rT
  _finish(Float64.(rT), Float64.(zT), x, y, Float64(s), Float64(λ))
end

end # module
