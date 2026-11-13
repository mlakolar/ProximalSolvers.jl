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

CD forms this scale without the sum of squares `sum(abs2, y)` or its product
with `s` having to stay in the range of `Float32` or `Float64`: where either
overflows or underflows it uses wider or exponent-separated arithmetic. There
are three outcomes. A scale that is a normal floating-point number of the
working type is used. For `y = 0` the scale is 0 and CD uses the absolute
threshold. If the computed `sqrt(s) * norm(y)`, after rounding to the working
type, is not a normal number (above its largest finite value or below its
smallest normal number), `solve!` throws an `ArgumentError` before the first
pass and leaves the starting point unchanged. A value within a rounding error
of those limits can fall on either side. In that case rescale the data or the
loss, or use `relative=false`; with `relative=false` a problem whose objective
overflows can still end in the `nonfinite objective` error described in
[Numerical behavior](numerics.md). A normal scale can still give a threshold
`tol * scale` that is subnormal or 0. The change test `change < threshold`
cannot hold for a threshold of 0, so the solve cannot converge by this test:
it ends at `maxpasses` with a warning, unless an independent numerical failure
(for example a non-finite coordinate step) stops it first with an error.

Each coordinate change is also multiplied by `sqrt(s * a)`, where `a` is the
squared norm of the column. Where the product `s * a` is zero or subnormal (in
the type that combines `s` with the working type), CD takes the square roots of
`s` and of `a` separately and multiplies them, so the scale does not become 0
because the product underflowed. It is still 0 where that root is at most half
the smallest subnormal number. Where the product overflows, the scale is
infinite, and a nonzero coordinate change then makes `solve!` throw an
`ArgumentError` ("a coordinate step or its stopping scale is not finite") and
leave the starting point unchanged. That overflow, the reciprocal
`1 / (s * a)` that the coordinate step uses (which can be infinite or 0), and an
infinite squared column norm are not changed by this and are tracked in issue
#294.

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
test can stop the run even when the KKT residual is not small;
`ftol = 0` switches that test off, as described under Strict accuracy in
[Numerical behavior](numerics.md).
The two results above report both coefficient error (possible here because
the analytic answer is known) and an independently computed
[KKT violation](sparsity-and-kkt.md). On other problems, evaluate the KKT
condition directly instead of trusting `converged` alone.

## Accelerated proximal gradient

`AccProxGradDescent` takes the same inputs, `ProximalOptions` and result type
as PGD, up to a dimension limit that its line search needs (for Float32,
`max(n, p) < 2,097,148`; see [Numerical behavior](numerics.md)). Each step starts from the extrapolated point
`y = x + k/(k+3) (x - x_previous)`, where `k` counts iterations since the start
or the last restart, and the momentum is restarted when an extrapolated step
would increase the objective. On ill-conditioned problems this can need
fewer iterations than PGD; on well-conditioned ones it can need more. An
iteration evaluates the gradient at `y` and then backtracks; a restart adds a
second gradient evaluation and line search in that iteration. Compare the two at
the same independently measured accuracy, as in
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

