####################################
#
#  Reweighting and refitting
#
####################################

"""
    ReweightResults

Returned by [`reweight!`](@ref): the minimizer `x`, the `penalty` at which it
was computed, the `next` penalty that `update` proposed from it, the number of
outer `iterations`, whether the relative `change` fell below the tolerance
(`converged`), and the coordinate descent `passes` summed over the solves,
with whether every solve `cd_converged`.
"""
struct ReweightResults{X, G1, G2, T}
  minimizer::X
  penalty::G1
  next::G2
  iterations::Int
  converged::Bool
  change::T
  passes::Int
  cd_converged::Bool
end

"""
    reweight!(x, f, g, update, method = CDSolver(); maxiter = 20, tol = 1e-2)

Alternate between minimizing `f + g` over `x`, warm started from the previous
solution, and updating the penalty: `update(g, x, m)` returns the next penalty
and the relative change that it makes, from the solution `x` and the
[`CDModel`](@ref) `m`, which is current for `x` (its residuals, gradient,
…). Stops when the change is below `tol`, or after `maxiter` solves. Returns
[`ReweightResults`](@ref).

On a `SymmetricSparseIterate`, each solve prepares the penalty by the parameter
rule of [`solve!`](@ref). `update` receives the supplied penalty, which is also
kept in the results; normalization does not replace it there.

This covers the iterative lasso procedures: the scaled lasso (the level
`λσ̂` with `σ̂ = ‖r‖/√n` from the residuals) and the lasso with data-driven
penalty loadings. `update` follows every solve, the last one included, which
gives `converged` and `next`. A two-stage estimator, which recomputes its
weights once at a first solution, can use `maxiter = 2, tol = 0` when the
weights are cheap. When they are not, it solves twice with one model
(`m = cdmodel(f, x)`, then `solve!(x, m, g, method)` for each penalty), which
computes them once.
"""
function reweight!(x, f::Union{AbstractFunction, CDModel}, g::AbstractFunction, update,
                   method::CDSolver = CDSolver(); maxiter::Integer = 20, tol::Real = 1e-2)
  maxiter >= 1 || throw(ArgumentError("maxiter must be positive, but it is $maxiter."))
  m = f isa CDModel ? f : cdmodel(f, x)
  T = eltype(m)
  passes, cd_converged = 0, true
  next, change, converged, iterations = g, T(NaN), false, 0
  for it in 1:maxiter
    iterations = it
    g = next
    r = solve!(x, m, g, method)
    passes += r.passes
    cd_converged &= r.converged
    next, change = update(g, x, m)
    if change < tol
      converged = true
      break
    end
  end
  ReweightResults(x, g, next, iterations, converged, T(change), passes, cd_converged)
end

"""
    refit!(x, f; support, cache = nothing)

Overwrite `x` with the minimizer of the loss `f` over the iterates supported on
`support` (entries outside it are set to zero), the nonzero coordinates of `x` unless given: the refit after a
penalized fit, for least squares and the other quadratic losses (a model
supports it if its coordinates are those of a quadratic, as for
`LeastSquaresLoss`, a least-squares `GLMLoss`, `QuadraticFunction` and
[`KronQuadratic`](@ref)). Least squares solves the least-squares problem on
the columns of the support by a pivoted QR factorization, and the others the
linear system of the Hessian on the support; when the minimizer is not unique,
a solution of the rank-deficient system. Returns `x`.

With a [`RefitCache`](@ref), least squares and `QuadraticFunction` keep the
Cholesky factor of the Hessian on the support between calls and update it when
the support changes, which makes refits along a path of supports much cheaper.
"""
function refit!(x::Union{SparseIterate, SymmetricSparseIterate}, f::Union{AbstractFunction, CDModel};
                support = _support(x), cache::Union{Nothing, RefitCache} = nothing)
  m = f isa CDModel ? f : cdmodel(f, x)
  S = collect(Int, support)
  all(k -> 1 <= k <= ncoordinates(x), S) || throw(ArgumentError("support indices must be in 1:ncoordinates(x)"))
  allunique(S) || throw(ArgumentError("support indices must be unique"))
  cx = coordinates(x)
  keep = Set(S)
  for k in activecoordinates(x)
    k in keep || (cx[k] = zero(eltype(x)))
  end
  initialize!(m, x)
  δ = cache === nothing ? nothing : _refit_step(cache, f, m, x, S)
  δ === nothing && (δ = _refit_step(m, x, S))
  T = eltype(m)
  for (j, k) in enumerate(S)
    h = T(δ[j])
    iszero(h) && continue
    cx[k] += h
    update_cache!(m, x, k, h)
  end
  dropzeros!(x)
  x
end

_support(x::Union{SparseIterate, SymmetricSparseIterate}) =
  (cx = coordinates(x); sort!([k for k in activecoordinates(x) if !iszero(cx[k])]))

# the Newton step on the support, -H_SS⁻¹ G_S, from the Hessian of the
# coordinates of S; exact for a quadratic loss
function _refit_step(m::CDModel{T}, x, S::Vector{Int}) where {T}
  isempty(S) && return T[]
  G = [coordinate_derivatives(m, x, k)[1] for k in S]
  H = _hessian(m, x, S)
  -(qr(Symmetric(H), ColumnNorm()) \ G)
end

# least squares: the residuals r regressed on the columns of S (centered with
# an intercept, weighted by √w), so the step solves min ‖√w (r - X_S δ)‖
function _refit_step(m::LSModel{T}, x::SparseIterate{T}, S::Vector{Int}) where {T}
  isempty(S) && return T[]
  XS = _support_columns(m.X, S) .- transpose(m.xbar[S])
  r = copy(residuals(m))
  if m.w !== nothing
    sw = sqrt.(m.w)
    XS .*= sw
    r .*= sw
  end
  qr(XS, ColumnNorm()) \ r
end

# the columns S of X as a dense matrix, which the pivoted QR factorization needs
_support_columns(X::AbstractMatrix, S) = X[:, S]
_support_columns(X::SparseMatrixCSC, S) = Matrix(X[:, S])

# the Hessian of f over the coordinates S, column by column from the changes of
# the derivatives after a unit step: exact for a quadratic, up to rounding
function _hessian(m::CDModel{T}, x, S::Vector{Int}) where {T}
  n = length(S)
  G0 = [coordinate_derivatives(m, x, k)[1] for k in S]
  H = zeros(T, n, n)
  cx = coordinates(x)
  for (j, k) in enumerate(S)
    cx[k] += one(T)
    update_cache!(m, x, k, one(T))
    for (i, l) in enumerate(S)
      H[i, j] = coordinate_derivatives(m, x, l)[1] - G0[i]
    end
    cx[k] -= one(T)
    update_cache!(m, x, k, -one(T))
  end
  (H .+ H') ./ 2
end

function _hessian(m::QuadModel{T}, x::SparseIterate{T}, S::Vector{Int}) where {T}
  H = m.A[S, S]
  # Pivoted QR works on a dense support Hessian, including for sparse and
  # diagonal models. Densify this small submatrix only, never the full Hessian.
  H isa Matrix || (H = Matrix(H))
  m.s .* H
end

function _hessian(m::KronModel{T}, x::SparseIterate{T}, S::Vector{Int}) where {T}
  p = size(m.M, 1)
  A, B = m.A, m.B
  [m.s * A[mod1(k, p), mod1(l, p)] * B[div(k - 1, p) + 1, div(l - 1, p) + 1] for k in S, l in S]
end

# along the symmetric directions d = e_r e_c' + e_c e_r' (e_r e_r' on the
# diagonal), the Hessian entry of coordinates (r, c) and (u, v) is ⟨d₁, A d₂ B⟩
function _hessian(m::KronModel{T}, x::SymmetricSparseIterate{T}, S::Vector{Int}) where {T}
  A, B, p = m.A, m.B, x.p
  rc = [tril_cartesian(p, k) for k in S]
  n = length(S)
  H = zeros(T, n, n)
  for j in 1:n, i in 1:n
    (r, c), (u, v) = rc[i], rc[j]
    h = A[r, u] * B[v, c]
    u != v && (h += A[r, v] * B[u, c])
    if r != c
      h += A[c, u] * B[v, r]
      u != v && (h += A[c, v] * B[u, r])
    end
    H[i, j] = m.s * h
  end
  H
end
