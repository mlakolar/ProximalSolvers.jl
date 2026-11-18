# Covariance thresholding (Rothman, Levina and Zhu, 2009,
# [doi:10.1198/jasa.2009.0101](https://doi.org/10.1198/jasa.2009.0101)) estimates a covariance matrix
# with many exactly zero off-diagonal entries by soft-thresholding the entries of the sample
# covariance matrix `S`. For a symmetric matrix `Σ`, it minimizes
#
# ``\tfrac12\|\Sigma - S\|_F^2 + \lambda \sum_{i \ne j} |\Sigma_{ij}|``,
#
# with the diagonal left out of the penalty. The minimizer keeps the diagonal of `S` and sets each
# off-diagonal entry to `sign(Sᵢⱼ) max(|Sᵢⱼ| − λ, 0)`.
#
# This is covariance thresholding, **not the graphical lasso**. The graphical lasso estimates a
# sparse *inverse* covariance matrix from a log-determinant objective, which this package does not
# solve (see [Supported problems](../../support.md)). Here the zeros are zeros of the covariance
# estimate itself, and the estimate **is not guaranteed to be positive semidefinite**: no projection
# onto the positive semidefinite matrices is applied on this page, and the last section shows an
# estimate that has a negative eigenvalue.
#
# The problem is solved through the centered squared norm. With `s` the vector of the entries
# `Sᵢⱼ` above the diagonal, `solve!(b, SqrNormL2(1.0, s), NormL1(λ), method)` minimizes
# `‖b − s‖²/2 + λ‖b‖₁`, which is the problem below. This is the centered squared norm row of
# [Supported problems](../../support.md) (`CDSolver` on a dense `Vector` here, and the two gradient
# methods once for comparison); the page adds no solver support. The `converged` flag of `CDSolver`
# reports a small coordinate change and is not an optimality certificate, so the statements about the
# solution below rest on a closed form and on optimality conditions computed from `s` and `λ`
# alone, not on that flag and not on a ProximalBase proximal operator.
using LinearAlgebra, Random, ProximalBase, ProximalSolvers

# ## Data
#
# The data are drawn from a seeded generator: `n = 10` observations of `p = 12` variables, whose
# population covariance is the identity except for three correlated pairs. The columns are centered
# and `S = XᵀX/(n − 1)`. With `n − 1 = 9` below `p`, the sample covariance matrix has rank at most 9
# and is singular.
rng = Xoshiro(2026)
n, p = 10, 12
Sigma_true = Matrix{Float64}(I, p, p)
for (i, j, correlation) in ((1, 2, 0.7), (3, 4, -0.6), (5, 6, 0.5))
  Sigma_true[i, j] = correlation
  Sigma_true[j, i] = correlation
end
X = randn(rng, n, p) * cholesky(Symmetric(Sigma_true)).U
X .-= sum(X; dims = 1) ./ n
S = Matrix(Symmetric((X' * X) / (n - 1)))
@assert rank(S; atol = 1e-10) <= n - 1

# ## From the matrix problem to a lasso-type problem
#
# Write `Σ = Σᵀ` through its diagonal and its entries above the diagonal, `b = (Σᵢⱼ)ᵢ<ⱼ`, and
# `s = (Sᵢⱼ)ᵢ<ⱼ`. Each off-diagonal entry occurs twice in the Frobenius norm and twice in the penalty,
#
# ``\|\Sigma - S\|_F^2 = \sum_i (\Sigma_{ii} - S_{ii})^2 + 2\|b - s\|_2^2``  and
# ``\sum_{i \ne j} |\Sigma_{ij}| = 2\|b\|_1``,
#
# so the objective is
#
# ``\tfrac12 \sum_i (\Sigma_{ii} - S_{ii})^2 + 2\Big(\tfrac12\|b - s\|_2^2 + \lambda\|b\|_1\Big)``.
#
# The diagonal enters only through the first term, which is zero at `Σᵢᵢ = Sᵢᵢ`: the diagonal is
# unpenalized and the minimizer keeps it. The factor 2 multiplies both the squared norm and the
# penalty, so the minimizer in `b` does not depend on it and is that of `‖b − s‖²/2 + λ‖b‖₁` at
# the same `λ`, the problem of `SqrNormL2(1.0, s)` with `NormL1(λ)`.
pairs = [(i, j) for j in 2:p for i in 1:j-1]
s = [S[i, j] for (i, j) in pairs]
m = length(s)
lambda = 0.2
@assert m == p * (p - 1) ÷ 2

# ## Solving it with coordinate descent
#
# `SqrNormL2(1.0, s)` is `‖b − s‖²/2`. Its centre `s` must be a `Vector` of the element type of `b`.
# Cyclic order and no momentum make the run reproducible. For this loss each coordinate is its own
# minimizer, so the second pass changes nothing and the run stops there.
f = SqrNormL2(1.0, s)
g = NormL1(lambda)
b = zeros(m)
result = solve!(b, f, g, CDSolver(order = :cyclic, momentum = false, tol = 1e-12))
@assert result.converged && result.minimizer === b

# ## Checking the solution independently
#
# The closed form is computed from `s` and `λ`, without the solver and without a ProximalBase
# proximal operator.
expected = sign.(s) .* max.(abs.(s) .- lambda, 0.0)
@assert maximum(abs, b - expected) <= 1e-12

# The optimality conditions are checked in the same way. At a minimizer, `0` is in `b − s + λ ∂|b|`:
# at `bₖ = 0` the condition is `|sₖ| ≤ λ`, and otherwise `bₖ − sₖ + λ sign(bₖ) = 0`. The function
# returns the largest violation.
function kkt_residual(b, s, λ)
  maximum(eachindex(b)) do k
    gradient = b[k] - s[k]
    iszero(b[k]) ? max(abs(gradient) - λ, 0.0) : abs(gradient + λ * sign(b[k]))
  end
end
@assert kkt_residual(b, s, lambda) <= 1e-12
@assert kkt_residual(s, s, lambda) >= lambda - 1e-12    # the unthresholded entries are not a solution

# The gradient methods give the same point. They count a stop only where a computed residual is below a
# bound (see [Numerical behavior](../../numerics.md)), and `gradtol = 1e-10` sets that bound.
options = ProximalOptions(maxiter = 1000, gradtol = 1e-10)
b_pgd, b_apg = zeros(m), zeros(m)
solve!(b_pgd, f, g, ProximalGradientDescent(), options)
solve!(b_apg, f, g, AccProxGradDescent(), options)
@assert kkt_residual(b_pgd, s, lambda) <= 1e-8 && kkt_residual(b_apg, s, lambda) <= 1e-8
@assert maximum(abs, b_pgd - b) <= 1e-8 && maximum(abs, b_apg - b) <= 1e-8

# ## The covariance estimate
#
# Put the entries of `b` back above and below the diagonal and keep the diagonal of `S`.
Sigma_hat = copy(S)
for (k, (i, j)) in enumerate(pairs)
  Sigma_hat[i, j] = b[k]
  Sigma_hat[j, i] = b[k]
end
@assert issymmetric(Sigma_hat) && diag(Sigma_hat) == diag(S)
@assert all(abs.(b) .<= abs.(s))                    # thresholding only shrinks entries
@assert count(iszero, b) > 0 && count(!iszero, b) > 0

# The matrix objective of `Σ̂` is twice the reduced objective that the solver reports. The objective is
# convex, so no symmetric perturbation of a minimizer, of the diagonal included, lowers it; the loop
# tries 200 random perturbations of size about `1e-3`, a check that an estimate that was not a
# minimizer could fail, and not a proof.
matrix_objective(Σ) = sum(abs2, Σ - S) / 2 + lambda * (sum(abs, Σ) - sum(abs, diag(Σ)))
@assert isapprox(matrix_objective(Sigma_hat), 2 * result.minimum; rtol = 1e-10)
let rng = Xoshiro(7), base = matrix_objective(Sigma_hat)
  for _ in 1:200
    E = randn(rng, p, p)
    E = 1e-3 * (E + E') / 2
    @assert matrix_objective(Sigma_hat + E) >= base - 1e-10
  end
end

# ## The estimate need not be positive semidefinite
#
# Soft thresholding changes each entry separately and has no reason to keep the eigenvalues of the
# sample covariance matrix nonnegative. `S` is positive semidefinite, and singular here. The
# thresholded estimate has a negative smallest eigenvalue, so it is not a covariance matrix. This page
# does not repair it: a projection onto the positive semidefinite matrices, or an estimator that
# constrains the eigenvalues, is a different problem.
lambda_min_S = eigmin(Symmetric(S))
lambda_min_hat = eigmin(Symmetric(Sigma_hat))
@assert lambda_min_S > -1e-12
@assert lambda_min_hat < 0

println("Distinct off-diagonal entries: ", m)
println("Nonzero entries after thresholding: ", count(!iszero, b), " (true nonzero entries: 3)")
println("Frobenius error of the sample covariance: ", norm(S - Sigma_true))
println("Frobenius error of the thresholded estimate: ", norm(Sigma_hat - Sigma_true))
println("Smallest eigenvalue of S: ", lambda_min_S, ", of the estimate: ", lambda_min_hat)
