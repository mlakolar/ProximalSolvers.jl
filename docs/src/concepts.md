# What problem, which algorithm?

## The lasso

Given a response vector `y`, a matrix `X` of `n` rows and `p` columns, and a coefficient vector `beta`, the lasso minimizes

~~~math
\frac{1}{2n}\|y-X\beta\|_2^2+\lambda\sum_{j=1}^p|\beta_j|.
~~~

The first term fits the observations. The L1 penalty shrinks coefficients and can make them **exactly zero**. A larger `lambda` strengthens this penalty relative to the scaled loss.

## Soft-thresholding and proximal operators

A **proximal operator** trades off staying near a proposed value and reducing a penalty. For L1, its scalar form is **soft-thresholding**:

~~~math
\operatorname{soft}(z,t)=\operatorname{sign}(z)\max(|z|-t,0).
~~~

For example, soft-thresholding `0.3` at threshold `0.5` gives `0`, while thresholding `-0.9` gives `-0.4`. The exact zero is the key to lasso sparsity. ProximalBase provides the [losses and penalties](https://mlakolar.github.io/ProximalBase.jl/dev/) used here.

## Coordinate descent (CD)

CD updates **one coefficient at a time** while holding the rest fixed, using a scalar soft-thresholding update for the lasso. It repeats sweeps (`passes`) over coordinates, sometimes focusing on the nonzero ones. It is a natural starting point for lasso and supports either a dense coefficient vector or a one-dimensional ProximalBase `SparseIterate`.

~~~@example concepts_cd
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
f = (1 / length(y)) * LeastSquaresLoss(y, X)
penalty = NormL1(1.0)
beta = zeros(2)
result = solve!(beta, f, penalty, CDSolver(order=:cyclic, momentum=false))
@assert isapprox(beta, [0.0, -0.25]; atol=1e-7)
beta
~~~

## Proximal gradient descent (PGD)

PGD updates **all coefficients together**. It first follows a gradient of the smooth squared-error loss, then soft-thresholds the proposed coefficient vector to account for the L1 penalty. Backtracking chooses a suitable step size. Here is the same objective:

~~~@example concepts_pgd
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
f = (1 / length(y)) * LeastSquaresLoss(y, X)
penalty = NormL1(1.0)
beta = zeros(2)
result = solve!(beta, f, penalty, ProximalGradientDescent())
@assert isapprox(beta, [0.0, -0.25]; atol=1e-4)
beta
~~~

These are two algorithms for **the same optimization problem**. Neither is universally faster. Start with CD for lasso experiments or active-coordinate storage; consider PGD if you want full-vector gradient iterations or detailed traces.

Continue to [sparsity and the KKT check](sparsity-and-kkt.md), then [solver options](choosing-solver.md).
