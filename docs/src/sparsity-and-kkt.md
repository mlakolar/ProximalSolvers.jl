# Sparsity, lambda and a KKT check

The lasso's L1 penalty can make some fitted coefficients **exactly zero**.
This tutorial shows both the threshold where everything becomes zero and
a more realistic problem with a few important predictors.

## Start with the 3-by-2 example

The previous [first example](getting-started.md) has two nonzero coefficients
when `lambda = 0.1`. Increasing the penalty to `1.0` makes the first coefficient
exactly zero:

~~~@example zeros
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
n = length(y)
f = (1 / n) * LeastSquaresLoss(y, X)

beta = zeros(2)
lambda = 1.0
result = solve!(beta, f, NormL1(lambda),
                CDSolver(order=:cyclic, momentum=false))
@assert isapprox(beta, [0.0, -0.25]; atol=1e-7)
beta
~~~

For the normalized lasso, a vector of all zeros is optimal when

~~~math
\lambda \geq \lambda_{\max}
=\frac{1}{n}\max_j |X_j^\mathsf{T}y|.
~~~

This assumes the problem has **no unpenalized intercept**, as in these examples.

~~~@example zeros
lambda_max = maximum(abs, X' * y) / n
@assert isapprox(lambda_max, 4 / 3; atol=1e-12)
all_zero_beta = zeros(2)
zero_result = solve!(all_zero_beta, f, NormL1(1.01 * lambda_max),
                     CDSolver(order=:cyclic, momentum=false))
@assert all(iszero, all_zero_beta)
all_zero_beta
~~~

## A larger reproducible problem

Now generate a dense design with 100 observations and 20 predictors.
Only three coefficients in the data-generating model are nonzero.
We use `Xoshiro(1)` so the generated data are reproducible, a deterministic
coordinate order, and a penalty below `lambda_max`:

~~~@example realistic_lasso
using Random, LinearAlgebra, ProximalBase, ProximalSolvers

rng = Xoshiro(1)
n, p = 100, 20
X = randn(rng, n, p)
true_beta = zeros(p)
true_beta[[2, 8, 15]] = [2.0, -1.5, 1.0]
y = X * true_beta + 0.2 * randn(rng, n)

lambda_max = maximum(abs, X' * y) / n
lambda = lambda_max / 4
f = (1 / n) * LeastSquaresLoss(y, X)
penalty = NormL1(lambda)

beta = zeros(p)
solver = CDSolver(order=:cyclic, momentum=false,
                  relative=false, tol=1e-9)
result = solve!(beta, f, penalty, solver)

nonzeros = count(b -> !iszero(b), beta)
@assert 0 < nonzeros < p
(; lambda_max, lambda, nonzeros, converged=result.converged)
~~~

The number of fitted nonzeros need not equal the three truly nonzero
coefficients. With noise and correlated predictors, selected variables
also depend on the strength of the penalty.

## Check optimality independently

For the normalized least-squares lasso, the smooth loss gradient is

~~~math
\nabla f(\beta)=-X^\mathsf{T}(y-X\beta)/n.
~~~

The **Karush–Kuhn–Tucker (KKT)** condition says that for each **nonzero**
coefficient `j`, the gradient must be `-lambda * sign(beta[j])`.
For each **zero** coefficient, the gradient's magnitude must be no larger
than `lambda`. The following code measures violations of those conditions:

~~~@example realistic_lasso
grad = -X' * (y - X * beta) / n
kkt = [iszero(beta[j]) ?
       max(abs(grad[j]) - lambda, 0) :
       abs(grad[j] + lambda * sign(beta[j]))
       for j in eachindex(beta)]
max_kkt = maximum(kkt)
@assert max_kkt < 1e-3
max_kkt
~~~

The **smaller** `max_kkt`, the closer this solution is to satisfying
first-order optimality. The threshold used to judge it depends on the
scale and numerical precision of your problem. For this convex lasso,
the KKT conditions characterize an optimum; this check is separate
from the solver's `converged` flag.

## What about SparseIterate?

A [`SparseIterate`](https://mlakolar.github.io/ProximalBase.jl/dev/)
stores active coefficient coordinates and their values, rather than
using an ordinary dense coefficient vector. It can be useful when
the fitted coefficients have many zeros, but the **design `X` is still dense**
in this development version. CD accepts it; PGD currently does not.
See the [sparse coordinate descent example](examples/03_sparse_cd_lasso.md)
and [Choosing a solver](choosing-solver.md).

The complete beginner workflow is [Getting started](getting-started.md);
the solver's numerical limits appear under [Numerical behavior](numerics.md).

