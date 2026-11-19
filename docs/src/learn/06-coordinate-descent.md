# [Coordinate descent](@id learn-06)

## Coordinate descent (CD)

CD updates **one coefficient at a time** while holding the rest fixed, using a scalar soft-thresholding update for the lasso. It repeats sweeps (`passes`) over coordinates, sometimes focusing on the nonzero ones. It is a natural starting point for lasso and supports either a dense coefficient vector or a one-dimensional ProximalBase `SparseIterate`. For a group lasso, CD updates one whole group of coefficients at a time on a ProximalBase `BlockIterate`; see [Choosing a solver](../choosing-solver.md).

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
