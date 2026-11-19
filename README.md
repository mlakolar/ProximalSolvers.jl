# ProximalSolvers.jl

**Coordinate descent and (accelerated) proximal gradient descent for least-squares lasso in Julia,
and coordinate descent for the square-root lasso.**

[Documentation](https://mlakolar.github.io/ProximalSolvers.jl/dev/) ·
[Getting started](https://mlakolar.github.io/ProximalSolvers.jl/dev/getting-started/) ·
[Choosing a solver](https://mlakolar.github.io/ProximalSolvers.jl/dev/choosing-solver/) ·
[Sparsity and KKT checks](https://mlakolar.github.io/ProximalSolvers.jl/dev/sparsity-and-kkt/)

The current GitHub **development** version solves

```math
\min_{\beta}\; \frac{1}{2n}\lVert y-X\beta\rVert_2^2
 +\lambda\lVert\beta\rVert_1.
```

It uses [ProximalBase.jl](https://mlakolar.github.io/ProximalBase.jl/dev/)
for losses, penalties and coefficient storage. The registered release may
offer a different API; use the [development installation instructions](https://mlakolar.github.io/ProximalSolvers.jl/dev/getting-started/)
for the version described here.

```julia
using ProximalBase, ProximalSolvers

T = Float64                       # Float32 is also supported
X = T[1 0; 0 2; 0 0]
y = T[2, -2, 0.5]
f = (one(T) / T(length(y))) * LeastSquaresLoss(y, X)
g = NormL1(T(0.1))

beta_cd = zeros(T, size(X, 2))
cd = solve!(beta_cd, f, g, CDSolver(order=:cyclic, momentum=false))

beta_pgd = zeros(T, size(X, 2))
# allow_f_increases=true: at gradtol=1e-10 a solve can otherwise end on a computed
# objective increase (converged = false, f_increased = true)
options = ProximalOptions(maxiter=2000, ftol=1e-14,
                          xtol=1e-12, gradtol=1e-10, allow_f_increases=true)
pgd = solve!(beta_pgd, f, g, ProximalGradientDescent(), options)

beta_apg = zeros(T, size(X, 2))
apg = solve!(beta_apg, f, g, AccProxGradDescent(), options)
```

The examples use **cyclic CD without momentum for reproducible output**.
For an exploratory lasso solve, `CDSolver()` is a reasonable starting
point; it uses random coordinate order, and its results can depend on
the random number generator. Set an explicit `rng` if you want to
reproduce that order.

Choose a path:

- **[Learn](https://mlakolar.github.io/ProximalSolvers.jl/dev/learn/01-lasso-problem/):** derivations, plots, reference algorithms and exercises.
- **[Use](https://mlakolar.github.io/ProximalSolvers.jl/dev/getting-started/):** installation, solver selection and interpreting results.
- **[Contracts](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/):** numerical guarantees, input requirements and failure behavior.

The [support matrix](https://mlakolar.github.io/ProximalSolvers.jl/dev/support/) also covers
weighted lasso, elastic net, group and multi-response models, and ℓ∞ penalties.
Browse the [worked examples](https://mlakolar.github.io/ProximalSolvers.jl/dev/examples-gallery/)
for statistical applications and convergence diagnostics.

`converged` reports each solver's own stopping rule; check optimality independently
before reporting a fit. See the [result semantics](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/results-failures/#RES-01).

For development, archival branches, exact dependency pins and CI policy,
see [CONTRIBUTING.md](CONTRIBUTING.md).
