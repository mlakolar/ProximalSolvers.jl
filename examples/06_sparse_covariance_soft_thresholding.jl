# # Sparse covariance estimation by soft-thresholding
#
# Rothman, Levina and Zhu (2009), "Generalized Thresholding of Large Covariance
# Matrices" (https://doi.org/10.1198/jasa.2009.0101), include soft-thresholding
# as a sparse covariance estimator. This is a covariance estimator, not the
# graphical lasso (which penalizes an inverse covariance matrix).
#
# For the sample covariance S, consider
#
#   min_{Sigma=Sigma'}  1/2 ||Sigma-S||_F^2 + lambda * sum_{i!=j} |Sigma[i,j]|.
#
# The diagonal is unpenalized. Each off-diagonal pair has the exact solution
# sign(S[i,j]) * max(abs(S[i,j]) - lambda, 0).
#
# Current ProximalSolvers master accepts dense least-squares lasso, so this
# educational example solves an equivalent lasso over the upper triangle of
# Sigma. The identity design is deliberately small; its O(p^4) storage is NOT
# a scalable approach to covariance thresholding.
using LinearAlgebra, Random, ProximalBase, ProximalSolvers

# ## Generate observations with a sparse population covariance
rng = Xoshiro(2026)
n, p = 120, 6
Sigma_true = Matrix{Float64}(I, p, p)
for (i, j, correlation) in ((1, 2, 0.7), (3, 4, -0.6), (5, 6, 0.5))
  Sigma_true[i, j] = correlation
  Sigma_true[j, i] = correlation
end
X = randn(rng, n, p) * cholesky(Symmetric(Sigma_true)).U
X .-= sum(X; dims=1) ./ n
S = Matrix(Symmetric((X' * X) / (n - 1)))

# ## Reduce to the strictly upper-triangular entries
#
# Every symmetric off-diagonal entry occurs twice in the Frobenius term and
# twice in the L1 penalty. After fixing the diagonal and dividing by two, the
# reduced objective is exactly
#
#   min_b  1/2 ||b-s||_2^2 + lambda * ||b||_1,
#
# where s lists the entries S[i,j] with i<j.
pairs = [(i, j) for j in 2:p for i in 1:j-1]
s = [S[i, j] for (i, j) in pairs]
m = length(s)
lambda = 0.2

# ## Solve using the existing lasso API
#
# LeastSquaresLoss is the unnormalized 1/2 squared residual. No 1/m
# factor is needed, and the penalty is unweighted because the diagonal
# does not appear in the decision vector.
design = Matrix{Float64}(I, m, m)
f = LeastSquaresLoss(s, design)
g = NormL1(lambda)
b = zeros(m)
result = solve!(b, f, g, CDSolver(order=:cyclic, momentum=false,
                                  relative=false, tol=1e-10))

# ## Independent analytical and optimality checks
#
# The closed form is deliberately computed without calling the solver or the
# ProximalBase proximal operator.
expected = sign.(s) .* max.(abs.(s) .- lambda, 0.0)
@assert result.converged && result.minimizer === b
@assert isapprox(b, expected; atol=1e-9, rtol=0.0)

# KKT: at b[k]=0, |b[k]-s[k]| <= lambda; otherwise
# b[k]-s[k] + lambda*sign(b[k]) = 0.
function kkt_violation(b, s, lambda)
  maximum(eachindex(b)) do k
    gradient = b[k] - s[k]
    iszero(b[k]) ? max(abs(gradient) - lambda, 0.0) :
                    abs(gradient + lambda * sign(b[k]))
  end
end
@assert kkt_violation(b, s, lambda) <= 1e-9

# ## Reconstruct the symmetric covariance estimate
Sigma_hat = copy(S)
for (k, (i, j)) in enumerate(pairs)
  Sigma_hat[i, j] = b[k]
  Sigma_hat[j, i] = b[k]
end
@assert issymmetric(Sigma_hat)
@assert diag(Sigma_hat) == diag(S)
@assert count(!iszero, b) <= m

println("Number of distinct off-diagonal entries: ", m)
println("Nonzero entries after thresholding: ", count(!iszero, b))
println("Frobenius error of sample covariance: ", norm(S - Sigma_true))
println("Frobenius error of thresholded estimate: ", norm(Sigma_hat - Sigma_true))
println("Smallest eigenvalue of estimate: ", eigmin(Symmetric(Sigma_hat)))

# ## Important limitation
#
# Thresholding need not preserve positive semidefiniteness. A negative
# smallest eigenvalue would make Sigma_hat unsuitable for applications that
# require a valid covariance matrix. This example does not impose a PSD
# constraint or silently repair the estimate. For a large p, use the closed
# form directly instead of creating the identity design above.
