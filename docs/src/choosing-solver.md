# Choosing a solver

The three supported algorithms solve the **same dense least-squares lasso**; CD, PGD and APG
also solve a group lasso (see [Group lasso](choosing-solver.md#Group-lasso-with-block-coordinate-descent)), and CD
also solves the square-root lasso `norm(y - X*beta) + lambda * norm(beta, 1)` (see [Supported problems](support.md)).
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
reasonable first choice, especially when you want active-coordinate storage.
PGD offers full-vector gradient iterations and detailed traces. APG accelerates
those updates while sharing PGD's options and results.

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
**step-change stopping test**, not an optimality certificate; for the square-root lasso, CD
reports `converged = true` only when a duality certificate also passes (see [`CDSolver`](@ref)).

The response scale, per-coordinate scaling and range-sensitive refusals are
specified together in [the scalar CD contract](@ref CD-01). Rescale the problem
or consider `relative=false` when a response scale is refused; a smaller
tolerance alone does not establish optimality.

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

Defaults are useful for an exploratory first run. The meaning of `converged`
is given by [the stopping contract](@ref STOP-01); the example displays both
coefficient error and an independent KKT residual for a problem with a known
answer.

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

The defaults are `maxiter=200`, `ftol=1e-6`, `xtol=1e-8` and `gradtol=1e-5`.
Tighter tolerances can be useful, but they do not promise a corresponding number
of correct digits. The three tests combine by OR, followed by a stationarity
check; `ftol=0` disables the objective-change test. See
[the stopping contract](@ref STOP-01).

With `allow_f_increases=false`, a computed objective increase can end a strict
solve before a convergence test succeeds. Allowing increases removes that exit;
it does not certify the answer. Compare the independent errors displayed above,
or check a [KKT residual](@ref learn-02) on a problem without an analytic solution.
The historical strict-configuration observations are in
[the evidence record](contracts/evidence/strict-accuracy-config.md).

## Accelerated proximal gradient

`AccProxGradDescent` uses the same options and result type as PGD, and updates
from an extrapolated point with objective-based restart. The exact extrapolation,
size limits and bound test are in [the APG contract](@ref APG-01).
Acceleration can change the iteration count in either direction, so compare
solvers at the same independently measured accuracy, as in
[the solver comparison](examples/comparisons/lasso_solvers.md).

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

The constructor defaults are `AccProxGradDescent(β=0.5, α=0.9)`: `β` shrinks the
step after a rejected trial and `α` lets it grow before the next iteration.
APG shares [PGD's stopping rules](@ref STOP-01), while its reported
iteration residual is measured from the extrapolated point; see
[the APG contract](@ref APG-01).

## Group lasso with block coordinate descent

Use it when the coefficients come in known groups that should enter or leave the
model together. The penalty is `GroupNormL2(lambda, groups)`, that is
`lambda * sum_k w_k * norm(beta[G_k])` with the default weights
`w_k = sqrt(length(G_k))`, and the objective is the least-squares loss plus this
penalty. `CDSolver` solves it with a ProximalBase `BlockIterate` that has the
groups of the penalty, and `ProximalGradientDescent` with a dense `Vector{T}` and a
`GroupNormL2{T}` (level and weights of the element type of the data), as does
`AccProxGradDescent`. The groups may be any disjoint index sets, in any order, and together they must
cover every coefficient. The [group lasso tutorial](examples/problems/group_lasso.md) uses
noncontiguous groups; [Supported problems](support.md) lists the restrictions.

~~~@example choosing_group
using ProximalBase, ProximalSolvers
X = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0; 0.0 0.0 0.0]
y = [3.0, 0.2, 4.0, 1.0]
lambda = 0.5
groups = [[1, 3], [2]]
g = GroupNormL2(lambda, groups)
x = BlockIterate(Float64, 3, g)
result = solve!(x, LeastSquaresLoss(y, X), g,
                CDSolver(order=:cyclic, tol=1e-12, relative=false))
# With orthonormal columns, each group is the soft-thresholded block of y:
# (1 - lambda * sqrt(2) / ||y[[1, 3]]||) * y[[1, 3]], and the group {2} is zero.
@assert result.converged
@assert isapprox(Vector(x), [(1 - lambda * sqrt(2) / 5) * 3, 0.0, (1 - lambda * sqrt(2) / 5) * 4];
                 atol=1e-10)
(; coefficients=Vector(x), active_groups=sort(collect(activecoordinates(x))))
~~~

A coordinate is a whole group: `passes` counts group passes and the iterate's
active coordinates are group numbers. CD does not support group momentum.
The group update, curvature preparation and change test are specified in
[the group CD contract](@ref CDG-01).

Check group KKT conditions independently when assessing a fit. PGD and APG also
solve the group lasso with dense coefficients and a same-type `GroupNormL2`;
their stopping proposal must pass [the group stationarity check](@ref STOP-01).
The [group tutorial](examples/problems/group_lasso.md) and
[group solver comparison](examples/comparisons/group_lasso_solvers.md) demonstrate
all three algorithms.

### Cost of the lazy curvature

Curvature work depends on the groups visited and screened during the whole
solve. The original measurements and their limitations are preserved in
[the lazy-curvature evidence](contracts/evidence/lazy-curvature-cost.md).

## What is supported now?

The [Problem × solver matrix](@ref "Problem × solver matrix") on
[Supported problems](support.md) lists verified problem, solver, storage and
element-type combinations. Follow each section's links to the exact
[input rules](@ref IN-01). In addition to the lasso family, PGD and APG accept
`NormLinf`; its zero-solution threshold and stopping interpretation are described
under [supported ℓ∞ problems](support.md#ℓ∞-penalty-with-PGD-and-APG) and
[the stopping contract](@ref STOP-01).

CD solves group lasso on a `BlockIterate` with `GroupNormL2`, as in the
[group example above](#Group-lasso-with-block-coordinate-descent).
It also supports one-dimensional
[ProximalBase SparseIterate](https://mlakolar.github.io/ProximalBase.jl/dev/)
coefficient storage. It tracks active coefficients while the design remains
dense, which can be useful for a sparse fit. In the
[worked sparse-iterate example](examples/problems/lasso.md#Coordinate-descent-on-a-SparseIterate),
the first coefficient is exactly zero and the second is active. See also
[the storage contract](@ref CDS-01).

Unsupported historical knobs are listed in one
[deferred-features table](support.md). Do not use gap, screening or
preconditioning settings, or accelerated variants other than `AccProxGradDescent`,
until they are implemented and tested.

