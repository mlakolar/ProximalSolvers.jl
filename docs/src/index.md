# ProximalSolvers.jl

**Solve least-squares lasso problems in Julia using coordinate descent or
proximal gradient descent.** Build your objective with
[ProximalBase.jl](https://github.com/mlakolar/ProximalBase.jl), choose an
algorithm, and call `solve!`.

!!! warning "Current development scope"
    This is the **minimal development core**, not the historical full solver
    collection. It currently supports dense Float32/Float64 least-squares
    designs with an unweighted L1 penalty. Coordinate descent also accepts a
    one-dimensional `SparseIterate` for coefficients; proximal gradient descent
    requires a dense vector. The narrowed `master` has not been released as a
    new package version.

## Start here

| I want to... | Read |
| --- | --- |
| Install from source and solve my first lasso | **[Getting started](getting-started.md)** |
| Decide between coordinate descent and proximal gradient | [Choosing a solver](choosing-solver.md) |
| Interpret a result or troubleshoot an error | [Results and troubleshooting](working-with-results.md) |
| Understand exactly what is and is not supported | [Supported API and migration](support.md) |
| Look up types, options and function signatures | [API reference](api.md) |

## A complete first example

This fits a normalized least-squares lasso:

~~~julia
using ProximalBase, ProximalSolvers

X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]

f = (1 / length(y)) * LeastSquaresLoss(y, X)
g = NormL1(0.1)
beta = zeros(size(X, 2))

result = solve!(beta, f, g, CDSolver())
@show beta, result.converged
# beta is approximately [1.7, -0.925]
~~~

`LeastSquaresLoss` is half the **sum** of squared residuals, so multiplying
it by `1 / length(y)` gives the familiar `1/(2n)` normalization.
The solver mutates `beta`; the result's `minimizer` refers to that same array.
`converged` is a stopping flag, not an optimality certificate.

For runnable, checked versions of this example and its proximal-gradient and
`SparseIterate` counterparts, open **Examples** in the sidebar. See
[Getting started](getting-started.md) for installation instructions and a
walkthrough of the model.

## Two algorithms, one optimization problem

- **Coordinate descent** (`CDSolver`): updates individual coefficients and
  supports both dense vectors and one-dimensional `SparseIterate` coefficient
  storage.
- **Proximal gradient descent** (`ProximalGradientDescent`): makes full-vector
  updates with backtracking; its coefficient destination must be dense.

Both minimize **the exact loss and penalty you provide**. They do not
automatically add an intercept, normalize the data, or tune the penalty.
See [Choosing a solver](choosing-solver.md) before changing algorithms or options.

## Package overview

~~~@docs
ProximalSolvers
~~~
