# Elastic net with proximal gradient descent, accelerated proximal gradient descent and coordinate
# descent on a normalized least-squares problem with correlated features:
#
# ``\min_b \; \frac{1}{2n}\|y - Xb\|^2 + \lambda_1 \|b\|_1 + \frac{\lambda_2}{2}\|b\|^2``.
#
# `ElasticNet(λ1, λ2)` is accepted by `ProximalGradientDescent`, `AccProxGradDescent` and `CDSolver`.
# This page solves the problem with `AccProxGradDescent` and `ProximalGradientDescent` on a dense
# `Vector`, and with `CDSolver` on a dense `Vector` and on a `SparseIterate`; see
# [Supported problems](../../support.md). Accuracy is checked with the objective computed from X and y
# and with the KKT residual, ProximalBase's `kkt_violation` of `g` at the gradient computed from X and y,
# not with the solvers' `converged` flags.
using LinearAlgebra, Random, ProximalBase, ProximalSolvers

rng = Xoshiro(2026)
n, p = 200, 50
X = randn(rng, n, p)
for j in 2:p                      # neighbouring columns with correlation 0.9
  X[:, j] .= 0.9 .* X[:, j - 1] .+ sqrt(1 - 0.9^2) .* X[:, j]
end
y = X[:, 1:5] * [2.0, -1.5, 1.0, 0.5, -0.5] .+ 0.1 .* randn(rng, n)
f = (1 / n) * LeastSquaresLoss(y, X)
lambda1, lambda2 = 0.02, 0.05
g = ElasticNet(lambda1, lambda2)

# The objective from the data, and the residual of the optimality condition
# 0 ∈ Xᵀ(Xβ - y)/n + λ2 β + λ1 ∂‖β‖₁, computed by ProximalBase's public `kkt_violation` at the gradient of the loss.
objective(beta) = sum(abs2, y - X * beta) / (2n) + lambda1 * sum(abs, beta) + lambda2 / 2 * sum(abs2, beta)
function elasticnet_residual(beta)
    grad = X' * (X * beta - y) / n
    ProximalBase.kkt_violation(g, grad, beta)
end

options = ProximalOptions(maxiter = 10_000, ftol = 1e-14, xtol = 1e-12, gradtol = 1e-10)
beta_apg, beta_pgd = zeros(p), zeros(p)
apg = solve!(beta_apg, f, g, AccProxGradDescent(), options)
pgd = solve!(beta_pgd, f, g, ProximalGradientDescent(), options)
@assert apg.minimizer === beta_apg && pgd.minimizer === beta_pgd
@assert elasticnet_residual(beta_apg) <= 1e-6 && elasticnet_residual(beta_pgd) <= 1e-6
# the reported objective is the one computed from the data, up to rounding
@assert isapprox(apg.minimum, objective(beta_apg); rtol = 1e-10)
@assert isapprox(pgd.minimum, objective(beta_pgd); rtol = 1e-10)
# the two runs reach the same point of this strongly convex problem
@assert maximum(abs, beta_apg - beta_pgd) <= 1e-5

# ## Coordinate descent
#
# `CDSolver` solves the same problem, from zeros, on a dense `Vector` and on a `SparseIterate`; the
# design stays dense, and the `SparseIterate` starts with no active coordinates, which the solver
# discovers. For least squares, `converged = true` is the solver's change test on the coefficients over a
# pass, not a certificate of optimality, so each run is checked on its own with the KKT residual, the
# objective and its agreement with the accelerated proximal gradient solution.
cd_solver = CDSolver(order = :cyclic, tol = 1e-10)
beta_cd = zeros(p)
x_sparse = SparseIterate(p)
cd_dense = solve!(beta_cd, f, g, cd_solver)
cd_sparse = solve!(x_sparse, f, g, cd_solver)
@assert cd_dense.minimizer === beta_cd && cd_sparse.minimizer === x_sparse
@assert elasticnet_residual(beta_cd) <= 1e-6 && elasticnet_residual(Vector(x_sparse)) <= 1e-6
# the reported objective is the one computed from the data, up to rounding
@assert isapprox(cd_dense.minimum, objective(beta_cd); rtol = 1e-10)
@assert isapprox(cd_sparse.minimum, objective(Vector(x_sparse)); rtol = 1e-10)
# both runs reach the accelerated proximal gradient solution
@assert maximum(abs, beta_cd - beta_apg) <= 1e-5
@assert maximum(abs, Vector(x_sparse) - beta_apg) <= 1e-5

# The elastic-net solution has a smaller Euclidean norm than the lasso solution with the same ℓ1
# level, for the exact minimizers: comparing the two objectives at the two solutions shows
# ‖β_EN‖ ≤ ‖β_lasso‖.
beta_lasso = zeros(p)
solve!(beta_lasso, f, NormL1(lambda1), AccProxGradDescent(), options)
@assert norm(beta_apg) < norm(beta_lasso)

for (name, r, beta) in (("AccProxGradDescent", apg, beta_apg), ("ProximalGradientDescent", pgd, beta_pgd))
  println(rpad(name, 24), " iterations = ", r.iterations, ", KKT residual = ", elasticnet_residual(beta),
          ", nonzeros = ", count(!iszero, beta))
end
for (name, r, beta) in (("CDSolver, Vector", cd_dense, beta_cd), ("CDSolver, SparseIterate", cd_sparse, Vector(x_sparse)))
  println(rpad(name, 24), " passes = ", r.passes, ", KKT residual = ", elasticnet_residual(beta),
          ", nonzeros = ", count(!iszero, beta))
end
