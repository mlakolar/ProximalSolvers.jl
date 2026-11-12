# Choosing a solver

Both supported algorithms solve the **same dense least-squares lasso**.
The difference is how they update coefficients, not what objective is minimized.
For definitions of soft-thresholding, CD and PGD, see [What problem, which algorithm?](concepts.md).

| | Coordinate descent (CD) | Proximal gradient descent (PGD) |
| --- | --- | --- |
| Start | `CDSolver()` | `ProximalGradientDescent()` |
| Steps | Update one coefficient at a time | Update the full vector |
| Coefficient storage | Dense `Vector` or one-dimensional `SparseIterate` | Dense `Vector` only |
| Tolerances | Constructor keywords | `ProximalOptions` passed to `solve!` |
| Result | `CDResults` with `passes` | `OptimizationResults` with `iterations` |

The APIs differ because they preserve the two historical algorithm implementations;
the present minimal core does not yet provide a unified options/result wrapper.
Neither approach is always faster. For a new lasso experiment, CD is a
reasonable first choice.

## Coordinate descent

~~~@example choosing_cd
using Random, ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
f = (1 / length(y)) * LeastSquaresLoss(y, X)
penalty = NormL1(0.1)
beta = zeros(2)
solver = CDSolver(order=:cyclic, momentum=false, relative=false, tol=1e-7)
result = solve!(beta, f, penalty, solver)
@assert isapprox(beta, [1.7, -0.925]; atol=1e-7)
beta
~~~

Useful settings are `maxpasses` (up to 100,000 by default), `tol`
(default `1e-7`), `order=:random` or `:cyclic`,
`momentum`, `relative`, and `rng`. For the exact current signatures, see
the [API reference](api.md).

**Relative tolerance:** With `relative=true` (the default), the change
threshold is scaled by a response-dependent quantity. Thus
`CDSolver(tol=1e-7)` can report an *effective* tolerance such as
`1.66e-7`. Set `relative=false` to interpret the threshold in the
coefficient-change units. This is a **step-change stopping test**, not
an optimality certificate.

**Randomness and momentum:** By default `order=:random`, and the
historical CD algorithm can apply momentum to active passes and restart
it when the active set changes. Momentum attempts to accelerate convergence
using previous iterates, but may change the numerical trajectory.
To reproduce a run, provide an explicit random generator:

~~~@example choosing_cd
x_repro = zeros(2)
seeded = CDSolver(rng=Xoshiro(1), momentum=false)
seeded_result = solve!(x_repro, f, penalty, seeded)
@assert isapprox(x_repro, [1.7, -0.925]; atol=1e-5)
x_repro
~~~

Construct a **fresh** seeded generator to repeat the sequence: an RNG
is mutable and advances as the solver draws from it. For a deterministic
coordinate order and no momentum, use
`CDSolver(order=:cyclic, momentum=false)`. Cyclic order rejects
`momentum=true`, **not** `momentum=false`.

## Proximal gradient descent

For a first experiment, **the defaults are a valid starting point**:

~~~@example choosing_pgd
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
f = (1 / length(y)) * LeastSquaresLoss(y, X)
penalty = NormL1(0.1)
beta = zeros(2)
result = solve!(beta, f, penalty, ProximalGradientDescent())
@assert isapprox(beta, [1.7, -0.925]; atol=1e-3)
beta
~~~

Use `ProximalOptions` when you want to change the iteration limit,
stopping tolerances or trace storage:

~~~@example choosing_pgd
beta_stricter = zeros(2)
options = ProximalOptions(maxiter=2000, ftol=1e-14,
                          xtol=1e-12, gradtol=1e-10,
                          store_trace=true)
stricter_result = solve!(beta_stricter, f, penalty,
                         ProximalGradientDescent(), options)
@assert isapprox(beta_stricter, [1.7, -0.925]; atol=1e-6)
(; coefficients=beta_stricter, iterations=stricter_result.iterations,
   stored_steps=length(stricter_result.trace))
~~~

The default `maxiter=200`, `ftol=1e-6`, `xtol=1e-8`,
and `gradtol=1e-5` are not "bad"; they are general-purpose starting
settings. Tighter tolerances might help on a particular problem, but
small requested tolerances do not guarantee matching coefficient error.
PGD's stopping tests combine by **OR**, so one criterion can stop the run.
Use an independent [KKT check](sparsity-and-kkt.md) for numerical assurance.

## What is supported now?

`X` must be a finite dense `Matrix{T}`, `y` a finite `Vector{T}`,
and the coefficients the same type, with `T` equal to Float32 or Float64.
The penalty is unweighted L1 and the loss is ordinary least squares
(or a single positive finite scalar multiple of it).

Coordinate descent can additionally store coefficients in a one-dimensional
[ProximalBase SparseIterate](https://mlakolar.github.io/ProximalBase.jl/dev/).
It tracks coordinates that are explicitly active, and can be helpful for
a sparse result. It does **not** make the feature matrix sparse.
In [Example 3](examples/03_sparse_cd_lasso.md), the first coefficient is
exactly zero and the second is active.

Unsupported historical knobs are listed in one
[deferred-features table](support.md). Do not use gap, screening,
preconditioning or acceleration settings until implemented and tested.

