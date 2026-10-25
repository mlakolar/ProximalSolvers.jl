# Examples

Each script is a short, complete program that solves one problem with
ProximalSolvers. Run one from the repository root with

```sh
julia --project=. examples/01_lasso.jl
```

or with ProximalSolvers and ProximalBase installed in your environment. They
need only these two packages and the standard library.

Every script ends by checking its result, usually the optimality conditions of
the problem, so a script that runs to the end has found a correct solution. The
test suite runs all of them, and the
[documentation](https://mlakolar.github.io/ProximalSolvers.jl/dev/) renders them
with their output.

| Script | Problem | What it shows |
|:-------|:--------|:--------------|
| [`01_lasso.jl`](01_lasso.jl) | the lasso | `CDSolver` on a `SparseIterate`, `lambda_max`, the optimality conditions, an unpenalized intercept with `cdmodel(f, x; intercept = true)` |
| [`02_lasso_path.jl`](02_lasso_path.jl) | a lasso path | `solve_path` with the sequential strong rule and its checks; a `callback` that picks λ on held-out data and stops the path |
| [`03_accelerations.jl`](03_accelerations.jl) | the lasso with correlated columns | the random and cyclic orders, momentum, Anderson acceleration |
| [`04_penalties.jl`](04_penalties.jl) | sparse regression | `ElasticNet`, `MCP` and `SCAD`, paths and `continuation` for nonconvex penalties, `LLA` paths for `CappedL1` and the two-step SCAD, `NormL1Nonneg`, `IndBox`, zero weights for unpenalized coordinates |
| [`05_group_lasso.jl`](05_group_lasso.jl) | the group lasso | `GroupNormL2` with groups of unequal sizes: coordinate descent on an `AtomIterate`, a path, `AccProxGradDescent` and `ActiveAccProxGradDescent` |
| [`06_glm.jl`](06_glm.jl) | generalized linear models | logistic regression by `CDSolver` and `ProxNewton`, an unpenalized intercept; Poisson regression with an exposure offset; Huber regression with outliers |
| [`07_sqrt_lasso.jl`](07_sqrt_lasso.jl) | the square-root and scaled lasso | `SqrtLeastSquaresLoss` across noise levels, the scaled lasso by `reweight!`, `SqrtQuadraticFunction` from sufficient statistics, a sparse precision matrix column by column |
| [`08_refit_and_reweight.jl`](08_refit_and_reweight.jl) | estimators built from lasso fits | `refit!` on the support, the adaptive lasso and reweighted ℓ1 by `reweight!` |
| [`09_differential_network.jl`](09_differential_network.jl) | a differential network | the D-trace loss as `KronQuadratic` on a `SymmetricSparseIterate`: a path, momentum, `refit!` |
| [`10_proximal_gradient.jl`](10_proximal_gradient.jl) | the lasso | `ProximalGradientDescent`, `AccProxGradDescent` and `ActiveAccProxGradDescent`; `ProximalOptions`, traces, `Float32`, a `SparseIterate` |
| [`11_low_rank_regression.jl`](11_low_rank_regression.jl) | multi-response regression | `NuclearNorm` with a matrix iterate; the subgradient of the nuclear norm as a check |
| [`12_graphical_lasso.jl`](12_graphical_lasso.jl) | the graphical lasso | `ADMMSolver` with `LogDetLoss` and a weighted `NormL1`: adaptive ρ, over-relaxation, warm starts along a path |
| [`13_custom_model.jl`](13_custom_model.jl) | the lasso with a sparse design | a `CDModel` of your own: `initialize!`, `coordinate_derivatives`, `update_cache!` and the optional functions |
| [`14_primal_dual.jl`](14_primal_dual.jl) | second-difference generalized lasso | `CondatVu`, KKT residuals, primal/dual warm starts |
| [`15_graph_fusion.jl`](15_graph_fusion.jl) | sparse regression on an irregular graph | separate coefficient and edge penalties; a common accuracy certificate; comparison with factorization-based ADMM |
| [`16_trend_filtering.jl`](16_trend_filtering.jl) | piecewise linear signal estimation | ordinary and TV-split ADMM compared with Condat–Vũ; why specialized splittings matter |

The building blocks, the functions and their proximal operators, have their
own examples in [ProximalBase.jl](https://github.com/mlakolar/ProximalBase.jl/tree/master/examples).

Examples 15 and 16 are accompanied by a lecture on composite splitting in the
documentation. Their reference algorithms are in `support/`, outside the
package API. Independent QP checks and repeated timings live in the separate
`benchmark/composite_lessons` environment; JuMP and HiGHS are not required by
the examples, normal tests, or documentation build.
