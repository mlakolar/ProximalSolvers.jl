# Related packages and benchmarks

These packages use ProximalSolvers directly or supply its optimization primitives:

| Package | |
|:--------|:--|
| [HighDimensionalModels.jl](https://github.com/mlakolar/HighDimensionalModels.jl) | the lasso and its paths; the group, square-root, scaled and heteroscedastic lasso; varying-coefficient models |
| [CovarianceSelection.jl](https://github.com/mlakolar/CovarianceSelection.jl) | Gaussian graphical models: the graphical lasso, CLIME and ACLIME, precision matrices by the scaled lasso, the fused graphical lasso, and the difference of two precision matrices |
| [DiffPrecTest.jl](https://github.com/mlakolar/DiffPrecTest.jl) | confidence intervals and tests for the difference of two precision matrices |
| **ProximalSolvers.jl** (this package) | the solvers: coordinate descent with penalty paths, screening and active sets; proximal gradient methods, proximal Newton and ADMM |
| [ProximalBase.jl](https://github.com/mlakolar/ProximalBase.jl) | the building blocks: losses, penalties and constraints with their gradients and proximal operators, and sparse iterates; [documentation](https://mlakolar.github.io/ProximalBase.jl/dev/) with the mathematics |

Use the estimation and inference packages for their statistical procedures.
ProximalSolvers provides the optimization algorithms, and ProximalBase provides
the functions and iterates used to construct them.

## Benchmarks

The [benchmark harness in `benchmark/`](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/benchmark/README.md)
times the solvers to an independently certified accuracy and compares revisions.
The [CoordinateDescent comparison](performance.md) reports public-API timings against CoordinateDescent 0.6.1 at matched certified accuracy.
Historical comparisons with HighDimensionalModels.jl, glmnet, Lasso.jl and the
replaced coordinate-descent code are retained in the
[snapshot](https://github.com/mlakolar/ProximalSolvers.jl/tree/f7e3f28026a8e83e0fa18203b39839cf57a1c949/benchmark).
