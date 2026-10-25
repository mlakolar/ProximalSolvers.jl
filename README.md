# ProximalSolvers.jl

[![Docs: dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://mlakolar.github.io/ProximalSolvers.jl/dev/)
[![CI](https://github.com/mlakolar/ProximalSolvers.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/mlakolar/ProximalSolvers.jl/actions/workflows/CI.yml?query=branch%3Amaster)

ProximalSolvers.jl provides coordinate descent and proximal methods for
penalized estimation in Julia. We consider problems of the form

$$
\min_x \; f(x) + g(x),
$$

where $f$ is a loss and $g$ is a penalty or a constraint. Examples include
sparse regression, generalized linear models, low-rank regression and Gaussian
graphical models.

Coordinate descent is a central part of the package. It uses the structure of
the loss to update one coordinate or group at a time, with cached residuals
and passes over the active coordinates. Furthermore, it supports penalty
paths with screening, reweighting and refits on a selected support.

Proximal gradient methods and ADMM cover problems with tractable proximal
operators, including penalties such as the nuclear norm that couple all
coordinates. The losses, penalties, constraints and sparse iterates come from
[ProximalBase.jl](https://github.com/mlakolar/ProximalBase.jl).

## Installation

With Julia 1.10 or later:

```julia
using Pkg
Pkg.add(["ProximalBase", "ProximalSolvers"])
```

For the development version and its dependencies, see the
[installation guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/getting_started/#Installation).

## The lasso by coordinate descent

We fit the lasso with objective $\|y-X\beta\|_2^2/(2n)+\lambda\|\beta\|_1$.
The factor `1 / n` sets the loss normalization, so the penalty level has the
same meaning across sample sizes.

```julia
using ProximalBase, ProximalSolvers, Random

rng = Xoshiro(1)
n, p = 200, 1000
X = randn(rng, n, p)
y = X[:, 1:5] * [2.0, -1.5, 1.0, -1.0, 0.5] + randn(rng, n)

f = (1 / n) * LeastSquaresLoss(y, X)
β = SparseIterate(p)
λmax = lambda_max(f, NormL1(1.0), β)  # ‖X'y‖∞ / n
g = NormL1(0.1 * λmax)
res = solve!(β, f, g, CDSolver(; rng = Xoshiro(2), gaptol = 1e-8))

res.converged  # whether the stopping rule was met
res.gap        # relative duality gap
Vector(β)      # fitted coefficients
```

`solve!` starts from `β`, overwrites it with the fitted coefficients, and
returns a summary of the run. Next, we can fit a decreasing sequence of
penalty levels with warm starts and screening:

```julia
λs = λmax .* 10 .^ range(0, -2; length = 50)
path = solve_path(f, NormL1(1.0), λs)
path.gap       # each level stops at a relative duality gap of at most 1e-4
```

## Choosing a method

| Problem structure | Solver |
|:------------------|:-------|
| Supported loss and a separable or group penalty | `CDSolver` |
| Penalized GLM, graphical lasso, or a supported quadratic model | `ProxNewton` |
| Smooth loss and a convex penalty with a proximal operator | `AccProxGradDescent`, `ProximalGradientDescent` |
| Smooth loss and a nonconvex penalty with a proximal operator | `MonotoneAccProxGradDescent`, `ProximalGradientDescent` |
| Smooth loss, a sparse solution, and supported restrictions to active coordinates | `ActiveAccProxGradDescent` |
| Two terms with proximal operators | `ADMMSolver` |
| Convex `f(x) + g(x) + h(D*x)` with smooth `f` | `CondatVu` |

The [solver guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/choosing_solver/)
states the requirements of each method. In particular, a separable penalty
alone is not sufficient for coordinate descent: the loss must provide a
supported coordinate model.

## Documentation

Start with the [worked example](https://mlakolar.github.io/ProximalSolvers.jl/dev/getting_started/),
then read about [coordinate descent](https://mlakolar.github.io/ProximalSolvers.jl/dev/coordinate_descent/)
or [proximal gradient methods](https://mlakolar.github.io/ProximalSolvers.jl/dev/proximal_gradient/).
The documentation includes the mathematical steps,
[optimality checks](https://mlakolar.github.io/ProximalSolvers.jl/dev/optimality/),
and the [API reference](https://mlakolar.github.io/ProximalSolvers.jl/dev/api/solvers/).

The thirteen [examples](examples) are complete programs for regression,
penalty paths, group penalties, low-rank models and graphical models.
[Related packages and benchmarks](https://mlakolar.github.io/ProximalSolvers.jl/dev/related_packages/)
place these solvers in the statistical software collection and describe the
performance comparisons.

## Development and tests

From the package checkout, resolve dependencies and run the complete suite with:

```sh
julia scripts/instantiate.jl
julia scripts/test_master.jl
```

The bootstrap uses sibling `master` checkouts for workspace dependencies. The
runner creates an isolated environment containing the package and its test
extras, including extra-only master dependencies on Julia 1.10, while keeping
this package's `Project.toml` unchanged. See [CONTRIBUTING.md](CONTRIBUTING.md)
for the naming policy and development setup.

## License

MIT, see [LICENSE](LICENSE).

### Convex penalties composed with a linear map

`CondatVu` solves `f(x) + g(x) + h(D*x)` with a gradient of `f`, proximal
operators of `g` and `h`, and products by a dense or sparse `D` and its adjoint.
It returns the primal and dual variables and step sizes for warm starts,
checks both KKT residuals (or a Fenchel gap), and supports Float32 and
`SparseIterate` primal vectors. See the
[primal–dual guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/primal_dual/)
and [generalized-lasso example](examples/14_primal_dual.jl).
