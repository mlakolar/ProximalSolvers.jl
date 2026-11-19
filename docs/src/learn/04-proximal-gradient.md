# [Proximal gradient descent](@id learn-04)

## Proximal gradient descent (PGD)

PGD updates **all coefficients together**. It first follows a gradient of the smooth squared-error loss, then soft-thresholds the proposed coefficient vector to account for the L1 penalty. Backtracking chooses a suitable step size. Here is the same objective:

~~~@example concepts_pgd
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
f = (1 / length(y)) * LeastSquaresLoss(y, X)
lambda = 1.0
penalty = NormL1(lambda)
beta = zeros(2)
result = solve!(beta, f, penalty, ProximalGradientDescent())
@assert all(isfinite, beta) && isfinite(result.minimum)
analytic = [0.0, -0.25]
grad = (X' * (X * beta - y)) / length(y)
kkt = [iszero(beta[j]) ?
       max(abs(grad[j]) - lambda, 0.0) :
       abs(grad[j] + lambda * sign(beta[j]))
       for j in eachindex(beta)]
(; coefficients=beta, converged=result.converged,
   max_coefficient_error=maximum(abs.(beta .- analytic)),
   max_kkt_violation=maximum(kkt))
~~~
