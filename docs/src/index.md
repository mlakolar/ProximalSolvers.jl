# ProximalSolvers.jl

**Learn least-squares lasso with coordinate descent (CD) and proximal gradient descent (PGD) in Julia**, and the square-root lasso with CD. The [ProximalBase.jl documentation](https://mlakolar.github.io/ProximalBase.jl/dev/) covers the loss, penalty and iterate types; this package supplies algorithms to optimize them.

## Is this package for me?

Use the current development version if you want to study lasso algorithms, control their updates, or experiment with ProximalBase. If you mainly want a ready-to-use statistical modeling workflow with regularization paths and cross-validation, also consider [GLMNet.jl](https://github.com/JuliaStats/GLMNet.jl) and [Lasso.jl](https://github.com/JuliaStats/Lasso.jl). We make no comparative speed or accuracy claim.

!!! note "Current development version"
    This site describes GitHub `master`; the registered release can have different
    interfaces and features. Follow [installation](getting-started.md) and check
    the [support matrix](support.md) for the problem and storage you need.

## Start here

| Your goal | Start here |
| --- | --- |
| **Learn** the mathematics and statistics | [The lasso problem](@ref learn-01), then seven chapters with derivations, plots and exercises |
| **Use** the package for a supported problem | [Getting started](getting-started.md), [choosing a solver](choosing-solver.md), [supported problems](support.md) and [reading results](working-with-results.md) |
| **Implement or review** a numerical routine | [Contracts](contracts/index.md): inputs, stopping, precision and failure behavior |

The [example gallery](examples-gallery.md) organizes complete worked problems,
statistical applications and solver comparisons. The original entry points remain:
[lasso](examples/problems/lasso.md), [weighted lasso](examples/problems/weighted_lasso.md),
[elastic net](examples/problems/elastic_net.md), [group lasso](examples/problems/group_lasso.md),
[square-root lasso](examples/problems/square_root_lasso.md) and
[solvers at equal accuracy](examples/comparisons/lasso_solvers.md).
Learn [proximal operators](@ref learn-03) or
[how sparsity and KKT checks work](@ref learn-02) before choosing an algorithm.

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

The solvers optimize the same objective; they differ in how they update
coefficients. These examples choose `CDSolver(order=:cyclic,
momentum=false)` for reproducible output. For routine exploratory
lasso work, `CDSolver()` is a reasonable starting point (random order
and its default momentum behavior); set a seeded `rng` for repeatability.
Always check optimality independently before reporting fitted coefficients.
See [Choosing a solver](choosing-solver.md) for the difference between
the settings.

A larger L1 penalty can make coefficients **exactly zero**, as the
[next tutorial](sparsity-and-kkt.md) shows.

The **Problems** and **Solver comparisons** sections of the sidebar have runnable scripts. The introductory guide examples above and below also execute during the documentation CI build.

## Package API

~~~@docs
ProximalSolvers
~~~
