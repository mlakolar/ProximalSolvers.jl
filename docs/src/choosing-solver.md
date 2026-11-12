# Choosing a solver

The three supported algorithms solve the **same dense least-squares lasso**.
The difference is how they update coefficients, not what objective is minimized.
For definitions of soft-thresholding, CD and PGD, see [What problem, which algorithm?](concepts.md).

| | Coordinate descent (CD) | Proximal gradient descent (PGD) | Accelerated proximal gradient (APG) |
| --- | --- | --- | --- |
| Start | `CDSolver()` | `ProximalGradientDescent()` | `AccProxGradDescent()` |
| Steps | Update one coefficient at a time | Update the full vector | Update the full vector from an extrapolated point |
| Coefficient storage | Dense `Vector` or one-dimensional `SparseIterate` | Dense `Vector` only | Dense `Vector` only |
| Tolerances | Constructor keywords | `ProximalOptions` passed to `solve!` | `ProximalOptions` passed to `solve!` |
| Result | `CDResults` with `passes` | `OptimizationResults` with `iterations` | `OptimizationResults` with `iterations` |

The APIs differ because they preserve the historical algorithm implementations;
the present minimal core does not yet provide a unified options/result wrapper.
No approach is always faster. For a new lasso experiment, CD is a
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
threshold is multiplied by `sqrt(s * sum(abs2, y))`, where `s` is the
least-squares scale (`1/n` for our normalized lasso). In the tiny example,
this equals `sqrt(8.25 / 3) ≈ 1.658`, so a constructor tolerance of
`1e-7` appears in the result as about `1.66e-7`. Set `relative=false`
to use the unscaled coefficient-change threshold. This is a
**step-change stopping test**, not an optimality certificate.

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

Defaults are useful for an **exploratory first run**, not for claiming
coefficient accuracy. Even on this two-coefficient problem they can stop with
only around 3–4 correct digits, despite `converged=true`:

~~~@example choosing_pgd
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
f = (1 / length(y)) * LeastSquaresLoss(y, X)
lambda = 0.1
penalty = NormL1(lambda)
beta = zeros(2)
result = solve!(beta, f, penalty, ProximalGradientDescent())
default_grad = (X' * (X * beta - y)) / length(y)
default_kkt = maximum([
    iszero(beta[j]) ? max(abs(default_grad[j]) - lambda, 0.0) :
                      abs(default_grad[j] + lambda * sign(beta[j]))
    for j in eachindex(beta)])
(; coefficients=beta, converged=result.converged,
   max_coefficient_error=maximum(abs.(beta .- [1.7, -0.925])),
   max_kkt_violation=default_kkt)
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
strict_grad = (X' * (X * beta_stricter - y)) / length(y)
strict_kkt = maximum([
    iszero(beta_stricter[j]) ? max(abs(strict_grad[j]) - lambda, 0.0) :
                               abs(strict_grad[j] + lambda * sign(beta_stricter[j]))
    for j in eachindex(beta_stricter)])
(; coefficients=beta_stricter, converged=stricter_result.converged,
   max_coefficient_error=maximum(abs.(beta_stricter .- [1.7, -0.925])),
   max_kkt_violation=strict_kkt, iterations=stricter_result.iterations,
   stored_steps=length(stricter_result.trace))
~~~

The default `maxiter=200`, `ftol=1e-6`, `xtol=1e-8`
and `gradtol=1e-5` target convenience, **not a specified number of
accurate digits**. Tighten them for results you intend to report, but do
not assume smaller tolerances guarantee a correspondingly smaller error.
PGD's stopping tests combine by **OR**, so a satisfied objective-change
test can stop the run even when the KKT residual is not small.
The two results above report both coefficient error (possible here because
the analytic answer is known) and an independently computed
[KKT violation](sparsity-and-kkt.md). On other problems, evaluate the KKT
condition directly instead of trusting `converged` alone.

## Accelerated proximal gradient

`AccProxGradDescent` takes the same inputs, `ProximalOptions` and result type
as PGD. Each step starts from the extrapolated point
`y = x + k/(k+3) (x - x_previous)`, where `k` counts iterations since the start
or the last restart, and the momentum is restarted when an extrapolated step
would increase the objective. On ill-conditioned problems this often needs
fewer iterations than PGD; each iteration evaluates the gradient at `y`, so the
work per iteration is similar. Compare the two at the same independently
measured accuracy, as in
[the solver comparison](examples/04_lasso_solver_comparison.md), before
choosing one for speed.

~~~@example choosing_apg
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
f = (1 / length(y)) * LeastSquaresLoss(y, X)
lambda = 0.1
beta = zeros(2)
options = ProximalOptions(maxiter=2000, ftol=1e-14, xtol=1e-12, gradtol=1e-10)
result = solve!(beta, f, NormL1(lambda), AccProxGradDescent(), options)
@assert isapprox(beta, [1.7, -0.925]; atol=1e-6)
grad = (X' * (X * beta - y)) / length(y)
kkt = maximum([iszero(beta[j]) ? max(abs(grad[j]) - lambda, 0.0) :
                                 abs(grad[j] + lambda * sign(beta[j]))
               for j in eachindex(beta)])
(; coefficients=beta, converged=result.converged, iterations=result.iterations,
   max_kkt_violation=kkt)
~~~

The constructor keywords are the backtracking factor `β ∈ (0, 1)`, which
shrinks the step `1/L` after a rejected trial, and `α ∈ (0, 1]`, which lets the
step grow again before each iteration (`AccProxGradDescent(β=0.5, α=0.9)` by
default). APG uses PGD's stopping tests, so the remarks above about defaults,
the OR combination and the objective-change test apply unchanged; its
gradient-mapping residual is measured at the extrapolated point. See
[Numerical behavior](numerics.md).

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
[deferred-features table](support.md). Do not use gap, screening or
preconditioning settings, or accelerated variants other than `AccProxGradDescent`,
until they are implemented and tested.

