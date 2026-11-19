# Covariance thresholding (Rothman, Levina and Zhu, 2009,
# [doi:10.1198/jasa.2009.0101](https://doi.org/10.1198/jasa.2009.0101)) estimates a covariance matrix
# by soft-thresholding the off-diagonal entries of the sample covariance matrix `S`, which can set some of
# them exactly to zero. For a symmetric matrix `Σ`, the estimate minimizes
#
# ``\tfrac12\|\Sigma - S\|_F^2 + \lambda \sum_{i \ne j} |\Sigma_{ij}|``,
#
# and the diagonal is left out of the penalty.
#
# This is covariance thresholding, **not the graphical lasso**, which estimates a sparse *inverse*
# covariance matrix from a log-determinant objective. The zeros here are zeros of the covariance estimate.
#
# The problem has a closed-form solution, so this page uses **no iterative solver**: the solvers of
# ProximalSolvers are not used, and the computation is ProximalBase's proximal operator `prox` of
# `NormL1`, which soft-thresholds a vector. The estimate is then stored in ProximalBase's
# `SymmetricSparseIterate`, the storage type for a symmetric matrix. The estimate **is not guaranteed to be positive
# semidefinite**, and no projection onto the positive semidefinite matrices is applied; the last section shows an
# estimate with a negative eigenvalue.
using LinearAlgebra, Random, ProximalBase

# ## Data
#
# The data are drawn from a seeded generator: `n = 10` observations of `p = 30` variables, whose
# population covariance is the identity except for three correlated pairs. The columns are centered and
# `S = XᵀX/(n − 1)`. With `n − 1 = 9` below `p`, the sample covariance matrix has rank at most 9 and is
# singular.
rng = Xoshiro(2026)
n, p = 10, 30
Sigma_true = Matrix{Float64}(I, p, p)
for (i, j, correlation) in ((1, 2, 0.7), (3, 4, -0.6), (5, 6, 0.5))
  Sigma_true[i, j] = correlation
  Sigma_true[j, i] = correlation
end
X = randn(rng, n, p) * cholesky(Symmetric(Sigma_true)).U
X .-= sum(X; dims = 1) ./ n
S = Matrix(Symmetric((X' * X) / (n - 1)))
@assert rank(S; atol = 1e-10) <= n - 1

# ## From the matrix problem to a vector problem
#
# Write `Σ = Σᵀ` through its diagonal and the vector `b = (Σᵢⱼ)ᵢ<ⱼ` of its entries above the diagonal, and
# let `s = (Sᵢⱼ)ᵢ<ⱼ`. Each off-diagonal entry occurs twice in the Frobenius norm and twice in the penalty,
#
# ``\|\Sigma - S\|_F^2 = \sum_i (\Sigma_{ii} - S_{ii})^2 + 2\|b - s\|_2^2``  and
# ``\sum_{i \ne j} |\Sigma_{ij}| = 2\|b\|_1``,
#
# so the objective is
#
# ``\tfrac12 \sum_i (\Sigma_{ii} - S_{ii})^2 + 2\Big(\tfrac12\|b - s\|_2^2 + \lambda\|b\|_1\Big)``.
#
# The diagonal appears in the first term alone, which is zero at `Σᵢᵢ = Sᵢᵢ`, so the diagonal is unpenalized and
# the estimate keeps it. The factor 2 multiplies both the squared norm and the penalty, so the minimizer in `b`
# is that of `‖b − s‖²/2 + λ‖b‖₁` at the same `λ`.
pairs = [(i, j) for j in 2:p for i in 1:j-1]
s = [S[i, j] for (i, j) in pairs]
m = length(s)
lambda = 0.15
@assert m == p * (p - 1) ÷ 2

# ## Soft thresholding with `prox`
#
# The minimizer of `‖b − s‖²/2 + λ‖b‖₁` is the proximal point of `λ‖·‖₁` at `s` with step 1,
# `bⱼ = sign(sⱼ) max(|sⱼ| − λ, 0)`. ProximalBase computes it with `prox(NormL1(λ), s, 1.0)`.
b = prox(NormL1(lambda), s, 1.0)

# ## Checks against the closed form
#
# The closed form is written out here, with `sign` and `max`, without calling `prox`.
expected = sign.(s) .* max.(abs.(s) .- lambda, 0.0)
@assert maximum(abs, b - expected) <= 1e-15
@assert all(abs.(b) .<= abs.(s))                  # thresholding shrinks entries toward 0
@assert count(iszero, b) > 0 && count(!iszero, b) > 0

# ## Storing the estimate in a `SymmetricSparseIterate`
#
# A `SymmetricSparseIterate(p)` holds the `p(p + 1)/2` independent entries of a symmetric `p × p` matrix. It is not
# an `AbstractArray`: a write `Σ̂[i, j] = v` sets the entries `(i, j)` and `(j, i)` together. A nonzero write makes the
# coordinate active, so here, where the diagonal is nonzero and only nonzero thresholded entries are written, `nactive`
# counts the diagonal and the nonzero thresholded entries (in general it also counts active coordinates that hold a zero). Its documentation
# gives `O(p²)` reserved storage with `O(1)` access: the type records which coordinates are active and does not
# reduce the memory in use, so it is a convenient representation here and not a saving.
Sigma_hat = SymmetricSparseIterate(p)
for i in 1:p
  Sigma_hat[i, i] = S[i, i]                       # the diagonal is not penalized
end
for (k, (i, j)) in enumerate(pairs)
  iszero(b[k]) || (Sigma_hat[i, j] = b[k])
end
@assert ncoordinates(Sigma_hat) == p * (p + 1) ÷ 2
@assert nactive(Sigma_hat) == p + count(!iszero, b)
@assert nactive(Sigma_hat) < ncoordinates(Sigma_hat)

# The dense matrix of the estimate is `Matrix(Σ̂)`. It is symmetric, keeps the diagonal of `S` and agrees
# with the matrix that is built directly from `S` and `b`.
Sigma_dense = Matrix(Sigma_hat)
reconstructed = copy(S)
for (k, (i, j)) in enumerate(pairs)
  reconstructed[i, j] = b[k]
  reconstructed[j, i] = b[k]
end
@assert issymmetric(Sigma_dense) && diag(Sigma_dense) == diag(S)
@assert Sigma_dense == reconstructed
@assert count(iszero, [Sigma_dense[i, j] for (i, j) in pairs]) == count(iszero, b)

# ## The estimate need not be positive semidefinite
#
# Soft thresholding changes each entry separately, and nothing in it keeps the eigenvalues of the sample covariance
# matrix nonnegative. `S` is positive semidefinite and singular here. The thresholded estimate has a negative
# smallest eigenvalue (about `-0.09`, printed below), so it is not a covariance matrix. This page does not repair
# it: a projection onto the positive semidefinite matrices, or an estimator that constrains the eigenvalues, is a
# different problem.
lambda_min_S = eigmin(Symmetric(S))
lambda_min_hat = eigmin(Symmetric(Sigma_dense))
@assert lambda_min_S > -1e-12
@assert lambda_min_hat < -0.05

println("Distinct off-diagonal entries: ", m, ", nonzero after thresholding: ", count(!iszero, b), " (true nonzero entries: 3)")
println("Active coordinates of the SymmetricSparseIterate: ", nactive(Sigma_hat), " of ", ncoordinates(Sigma_hat))
println("Largest difference from the closed form: ", maximum(abs, b - expected))
println("Frobenius error of the sample covariance: ", norm(S - Sigma_true))
println("Frobenius error of the thresholded estimate: ", norm(Sigma_dense - Sigma_true))
println("Smallest eigenvalue of S: ", lambda_min_S, ", of the estimate: ", lambda_min_hat)
