# Related packages and benchmarks

ProximalSolvers is one of five Julia packages for high-dimensional statistics,
three for estimation and inference and two for the optimization beneath them:

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

The [`benchmark/`](https://github.com/mlakolar/ProximalSolvers.jl/tree/master/benchmark)
folder compares the solvers on the lasso with HighDimensionalModels.jl, glmnet and
Lasso.jl. Its README gives the environments, commands and results.
Furthermore,
[`benchmark/engine/`](https://github.com/mlakolar/ProximalSolvers.jl/tree/master/benchmark/engine)
compares the coordinate descent engine with the implementations it replaces in
HighDimensionalModels.jl, CovarianceSelection.jl and DiffPrecTest.jl.
