# Accelerated proximal gradient descent (`AccProxGradDescent`) on a normalized lasso with
# correlated features, next to plain proximal gradient descent with the same options.
# Accuracy is checked with an independent KKT residual computed from X and y, not with
# the solvers' `converged` flags.
using LinearAlgebra, Random, ProximalBase, ProximalSolvers

rng = Xoshiro(2026)
n, p = 200, 50
X = randn(rng, n, p)
for j in 2:p                      # neighbouring columns with correlation 0.9
  X[:, j] .= 0.9 .* X[:, j - 1] .+ sqrt(1 - 0.9^2) .* X[:, j]
end
y = X[:, 1:5] * [2.0, -1.5, 1.0, 0.5, -0.5] .+ 0.1 .* randn(rng, n)
f = (1 / n) * LeastSquaresLoss(y, X)
lambda = 0.02
g = NormL1(lambda)

# The largest violation of 0 ∈ Xᵀ(Xβ - y)/n + λ ∂‖β‖₁.
function kkt_violation(beta)
  grad = X' * (X * beta - y) / n
  maximum(iszero(beta[j]) ? max(abs(grad[j]) - lambda, 0.0) :
                            abs(grad[j] + lambda * sign(beta[j])) for j in eachindex(beta))
end

options = ProximalOptions(maxiter = 10_000, ftol = 1e-14, xtol = 1e-12, gradtol = 1e-10)
beta_apg, beta_pgd = zeros(p), zeros(p)
apg = solve!(beta_apg, f, g, AccProxGradDescent(), options)
pgd = solve!(beta_pgd, f, g, ProximalGradientDescent(), options)
@assert apg.minimizer === beta_apg
@assert kkt_violation(beta_apg) <= 1e-6 && kkt_violation(beta_pgd) <= 1e-6

# Iterations and oracle calls of the two runs. The iteration count of the accelerated
# method is often smaller on correlated designs, but compare solvers at the same
# independently measured accuracy before choosing one for speed.
for (name, r, beta) in (("AccProxGradDescent", apg, beta_apg), ("ProximalGradientDescent", pgd, beta_pgd))
  println(rpad(name, 24), " iterations = ", r.iterations, ", gradient calls = ", r.grad_calls,
          ", prox calls = ", r.prox_calls, ", KKT violation = ", kkt_violation(beta),
          ", nonzeros = ", count(!iszero, beta))
end
