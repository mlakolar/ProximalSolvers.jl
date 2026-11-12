# ProximalSolvers.jl

**Learn least-squares lasso with coordinate descent (CD) and proximal gradient descent (PGD) in Julia.** The [ProximalBase.jl documentation](https://mlakolar.github.io/ProximalBase.jl/dev/) covers the loss, penalty and iterate types; this package supplies algorithms to optimize them.

## Is this package for me?

Use the current development version if you want to study lasso algorithms, control their updates, or experiment with ProximalBase. If you mainly want a ready-to-use statistical modeling workflow with regularization paths and cross-validation, also consider [GLMNet.jl](https://github.com/JuliaStats/GLMNet.jl) and [Lasso.jl](https://github.com/JuliaStats/Lasso.jl). We make no comparative speed or accuracy claim.

!!! note "Current development version"
    This site documents the GitHub `master` branch, **not necessarily** the registered `ProximalSolvers` release. Development master currently supports dense Float32/Float64 least-squares lasso with unweighted L1 penalty, with CD or PGD. Its previously broader feature set, including paths and ADMM, is not in this branch. See [installation](getting-started.md).

## Start here

| What do you want to learn? | Read |
| --- | --- |
| Install into a Julia project and solve your first lasso | **[Getting started](getting-started.md)** |
| Understand proximal operators, soft-thresholding, CD and PGD | [What problem, which algorithm?](concepts.md) |
| See coefficients become zero and verify KKT conditions | [Sparsity and an optimality check](sparsity-and-kkt.md) |
| Choose solver settings | [Choosing a solver](choosing-solver.md) |
| Understand results and common errors | [Results and troubleshooting](working-with-results.md) |
| Check what is supported | [Supported problems](support.md) |

## Your first solution

~~~@example home
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
f = (1 / length(y)) * LeastSquaresLoss(y, X)
penalty = NormL1(0.1)
beta = zeros(2)
result = solve!(beta, f, penalty, CDSolver(order=:cyclic, momentum=false))
@assert isapprox(beta, [1.7, -0.925]; atol=1e-7)
beta
~~~

`LeastSquaresLoss` means **half the sum** of squared residuals, not their mean. Multiplication by `1/n` produces the conventional lasso objective. `solve!` modifies `beta` in place, and `result.minimizer === beta`.

Both solvers optimize the same objective; they differ in how they update
coefficients. These examples choose `CDSolver(order=:cyclic,
momentum=false)` for reproducible output. For routine exploratory
lasso work, `CDSolver()` is a reasonable starting point (random order
and its default momentum behavior); set a seeded `rng` for repeatability.
Always check optimality independently before reporting fitted coefficients.
See [Choosing a solver](choosing-solver.md) for the difference between
the settings.

A larger L1 penalty can make coefficients **exactly zero**, as the
[next tutorial](sparsity-and-kkt.md) shows.

The **Examples** sidebar has runnable scripts. The introductory guide examples above and below also execute during the documentation CI build.

## Package API

~~~@docs
ProximalSolvers
~~~
