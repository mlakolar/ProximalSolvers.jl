# Getting started

In this section, we fit a lasso by coordinate descent, compute a penalty path,
and solve the same problem by proximal gradient. The examples use the same
loss and penalty objects throughout.

## Installation

ProximalSolvers requires Julia 1.10 or later, and we install both packages
to use the losses and penalties directly:

```julia
using Pkg
Pkg.add(["ProximalBase", "ProximalSolvers"])
```

For development, run these commands from the ProximalSolvers checkout:

```sh
julia scripts/instantiate.jl
julia scripts/test_master.jl
```

The bootstrap develops the sibling ProximalBase `master` checkout, cloning it
if missing. The test runner uses an isolated environment with the full test
extras and master dependencies, including on Julia 1.10, without changing the
package's `Project.toml`. To prepare the documentation environment, use
`julia scripts/instantiate.jl docs`.

The package was called ProximalOPT before its first release.

## Specify the objective

Let ``X \in \mathbb R^{n\times p}`` be the design matrix and
``y \in \mathbb R^n`` the response. We consider the lasso

```math
\min_{\beta\in\mathbb R^p}
P_\lambda(\beta)
= \underbrace{\frac{1}{2n}\|y-X\beta\|_2^2}_{f(\beta)}
+ \underbrace{\lambda\|\beta\|_1}_{g(\beta)},
```

where ``\lambda\ge0`` controls the penalty on the coefficients. For this
example, the intercept is fixed at zero, and the columns are used without
standardization.

```@example getting_started
using ProximalBase, ProximalSolvers, LinearAlgebra, Random

rng = Xoshiro(1)
n, p = 200, 1000
X = randn(rng, n, p)
y = X[:, 1:5] * [2.0, -1.5, 1.0, -1.0, 0.5] + randn(rng, n)
f = (1 / n) * LeastSquaresLoss(y, X)
nothing # hide
```

`LeastSquaresLoss(y, X)` is ``\|y-X\beta\|_2^2/2``. Therefore, the factor
`1 / n` is needed for the objective above. Changing the loss normalization
changes the penalty level that gives the same solution.

## Fit by coordinate descent

The largest penalty level needed for this path follows from the optimality
conditions at zero:

```math
\lambda_{\max} = \|\nabla f(0)\|_\infty = \frac{\|X^\top y\|_\infty}{n}.
```

For ``\lambda\ge\lambda_{\max}``, zero is a minimizer. We fit at one tenth
of this level, using a sparse iterate to store the active coefficients:

```@example getting_started
β = SparseIterate(p)
λmax = lambda_max(f, NormL1(1.0), β)
λ = 0.1 * λmax
g = NormL1(λ)
res = solve!(β, f, g, CDSolver(; rng = Xoshiro(2), gaptol = 1e-8))
(converged = res.converged, relative_gap = res.gap,
 nonzeros = count(!iszero, β))
```

`solve!` overwrites `β`, and `res.minimizer` refers to that same iterate,
which we can convert to a dense vector with `Vector(β)`.

With `gaptol`, we ask coordinate descent to check a duality gap before
declaring convergence, as described in [Checking a solution](@ref).
In particular, `res.gap` bounds the objective error relative to the attained
objective value, up to floating point error.

## Compute a penalty path

Next, we solve the problem along a decreasing sequence of penalty levels.
Each solve starts from the preceding solution, screening reduces the
coordinates considered at the new level, and each level stops once its
relative duality gap is at most `1e-4` (`path.gap`), which puts the
coefficients within about `1e-4` of the solution, relative to the largest:

```@example getting_started
λs = λmax .* 10 .^ range(0, -2; length = 50)
path = solve_path(f, NormL1(1.0), λs)
(levels = length(path.λ), converged = all(path.converged),
 first_support = count(!iszero, path.solutions[1]),
 last_support = count(!iszero, path.solutions[end]))
```

`NormL1(1.0)` specifies the penalty family, and `λs` supplies the levels.
The solutions, objective values and convergence flags are stored in
`path.solutions`, `path.values` and `path.converged`. To choose a penalty level from these fits, we need a statistical criterion,
such as the validation error in [A lasso path](@ref).

Furthermore, the strong screening rule is followed by checks of the excluded
coordinates, as described in [Penalty paths and screening](@ref). That page
also covers group penalties and nonconvex paths by local linear approximation.

## Solve by proximal gradient

The same objective can be solved using the gradient of ``f`` and the proximal
operator of ``g``. We start from a separate zero iterate and use the same
duality gap tolerance:

```@example getting_started
βpg = zeros(p)
pg = solve!(βpg, f, g, AccProxGradDescent(),
            ProximalOptions(; maxiter = 10_000, gaptol = 1e-8))
cd_gap = duality_gap(f, g, β)
pg_gap = duality_gap(f, g, βpg)
(cd_relative_gap = res.gap, pg_relative_gap = pg.gap,
 objective_difference = abs(cd_gap.primal - pg_gap.primal))
```

Both algorithms minimize the same convex objective, so we compare their
objective values using the duality gaps computed at the fitted coefficients.
However, their iterates need not agree when the minimizer is not unique. For penalties that couple the coordinates,
such as the nuclear norm, proximal gradient remains applicable when a
coordinate descent model is unavailable.

## Continue with your problem

[Choosing a solver](@ref) describes the requirements of each method, while
[Coordinate descent](@ref) derives the coordinate update and its residual cache.
[The lasso](@ref) adds an unpenalized intercept, while [The group lasso](@ref)
and [Generalized linear models](@ref) extend the regression example.
