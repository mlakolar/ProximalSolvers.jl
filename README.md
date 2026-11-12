# ProximalSolvers.jl

**Coordinate descent and (accelerated) proximal gradient descent for least-squares lasso in Julia.**

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
options = ProximalOptions(maxiter=2000, ftol=1e-14,
                          xtol=1e-12, gradtol=1e-10)
pgd = solve!(beta_pgd, f, g, ProximalGradientDescent(), options)

beta_apg = zeros(T, size(X, 2))
apg = solve!(beta_apg, f, g, AccProxGradDescent(), options)
```

The examples use **cyclic CD without momentum for reproducible output**.
For an exploratory lasso solve, `CDSolver()` is a reasonable starting
point; it uses random coordinate order, and its results can depend on
the random number generator. Set an explicit `rng` if you want to
reproduce that order.

**PGD's default stopping rules can report `converged=true` with only
about 3–4 correct digits on the tutorial examples.** Use tighter options
and independently check optimality for results you plan to report.
`converged` is not a KKT certificate. See the
[numerical guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/)
and [solver settings](https://mlakolar.github.io/ProximalSolvers.jl/dev/choosing-solver/).

The supported problem uses a finite dense `Matrix{T}`, finite `Vector{T}`
response and matching coefficients, where `T` is `Float32` or `Float64`.
CD additionally accepts one-dimensional ProximalBase `SparseIterate`
coefficients; PGD and accelerated PGD (`AccProxGradDescent`) accept dense
coefficients only. Generalized models,
sparse designs, penalty paths, ADMM and other algorithms are not part
of this development branch; see
[Supported problems](https://mlakolar.github.io/ProximalSolvers.jl/dev/support/).

ProximalBase's linked `/dev/` documentation follows its evolving
`master`, while ProximalSolvers uses a **fixed dependency commit**.
Details can therefore differ; consult the
[exact pinned source and installation guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/getting-started/)
for compatibility.

For development, archival branches, exact dependency pins and CI policy,
see [CONTRIBUTING.md](CONTRIBUTING.md).
