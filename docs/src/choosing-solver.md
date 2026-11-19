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
**step-change stopping test**, not an optimality certificate; for the square-root lasso, CD
reports `converged = true` only when a duality certificate also passes (see [`CDSolver`](@ref)).

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

When relative scaling is active (`relative=true` and a positive response
scale), each coordinate change is also multiplied by `sqrt(s * a)`, where `a` is
the squared norm of the column. With `relative=false`, or with `y = 0`, the
coordinate scale is not used. Where the product `s * a` is zero, subnormal or
overflowing for a finite `a` (in the type that combines `s` with the working
type), CD takes the square roots of `s` and of `a` separately and multiplies
them, so the scale does not become 0 or infinite because the product left the
range. The computed scale is still 0 where the root is at most half the
smallest subnormal number, and infinite where the computed, rounded scale
overflows the working type; with relative scaling active a nonzero coordinate
change times an infinite scale makes
`solve!` throw an `ArgumentError` ("a coordinate step or its stopping scale is
not finite") and leave the starting point unchanged.

The coordinate step soft-thresholds the unpenalized minimizer along the
coordinate at `lambda / (s * a)` (with weights, `lambda` stands for the coefficient `lambda * w[k]` of the coordinate; where the step forms its
threshold without the product, it uses `T(lambda) * w[k]` formed in `T`, which is 0 or a normal number on the inputs `solve!` accepts). Where `s * a` and its reciprocal are both at
least the smallest normal number of the type that combines `s` with the working
type, it applies the proximal operator with the coefficient `1 / (s * a)`.
Where one of them is smaller (the product is zero or subnormal, or it is large
enough that its reciprocal is subnormal or zero), that coefficient can be 0,
infinite or inexact. With a positive penalty, 0 would ignore the penalty and an
infinite coefficient would set a finite unpenalized minimizer to 0; a zero
penalty stays unpenalized for any coefficient. The step then forms the
threshold without the product and its reciprocal. A threshold above the largest finite number sets a
finite unpenalized minimizer to 0. A column whose squared norm `a` is not finite
in the working type makes `solve!` throw an `ArgumentError` that names the
curvature, with the starting point unchanged.

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
coefficient accuracy. With them, `converged=true` means that the computed
KKT residual `‖G‖∞` is below `max(gradtol, 64eps(T)) * max(λ, λmax)` (`λ` the ℓ1 level of the penalty), which
does not bound the coefficient error, shown here next to the KKT violation
on this two-coefficient problem:

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
not assume smaller tolerances guarantee a correspondingly smaller error:
`gradtol` below `64eps(T)` is not resolved by the check of a stop, and the
residual that is checked does not bound the coefficient error.
PGD's stopping tests combine by **OR**, so any one of them can propose a stop,
and a proposed stop counts only if the computed KKT residual `‖G‖∞` is below
`max(gradtol, 64eps(T)) * max(λ, λmax)`, with `λmax = α‖Xᵀy‖∞` and `λ` the ℓ1 level of the penalty
(`λ1` for an `ElasticNet`, whose residual includes the ridge term `λ2 x`; for a `GroupNormL2`, the group residual
and scale of [the stationarity check](@ref "The stationarity check of a stop"); a `NormLinf` penalty uses the
[generic check](numerics.md#The-generic-stationarity-check)). A solve
that the check keeps from stopping continues, and can end at `maxiter` with
`converged=false`. `ftol = 0` switches the objective-change test off, as
described under Strict accuracy in [Numerical behavior](numerics.md).
With these stricter tolerances and the default `allow_f_increases=false`, PGD on
this problem ended on the objective-increase stop with `converged=false` in a
test run on Julia 1.13.3; `allow_f_increases=true` lets it continue to a stop
that passes the check (see "Strict accuracy" in [Numerical behavior](numerics.md)).
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
[the solver comparison](examples/comparisons/lasso_solvers.md), before
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

A coordinate of the solver is a group, so `passes` counts passes over groups and the
active coordinates are group numbers. Each group needs, at most once per solve, a bound
on the largest eigenvalue of `X[:, G]' * X[:, G]`. With `maxpasses = 0` none is prepared.
A group whose columns are all zero needs no product and no eigenvalue computation, and a
group of one column (when `n eps(T) ≤ 1/8`, `n` the number of rows) takes the sum of
squares of its column, as the lasso does. A group of two columns takes the three entries
of its Gram matrix in one pass over its columns and its bound in closed form; inside the
range of that rule (finite `Float32` data, and `Float64` data whose columns are not
extremely small or large, see [Numerical behavior](numerics.md#The-curvature-bound)) it
needs no eigenvalue computation and no `Float64` copy of its columns. Any other group, and
a group of two columns outside that range, needs the Gram matrix of its columns in
`Float64` from a copy of the columns and, for two or more columns, an eigenvalue
computation. These are done at the first visit that needs them, so a group that stays at
zero and is screened out at each visit never pays for them, except where cheap bounds
cannot rule out a refusal (under the eigenvalue model, for a group that takes the eigenvalue
computation), in which case the bound is computed before the first pass (such a group, or
an ordinary one-column group, already has its bound when it is screened). A visit to a
nonflat group whose block is zero is screened this way, whether or not the group is active,
when the reciprocal of the loss scale is a normal number of its type and either all
correlations of the group are zero or the largest magnitude is at least `2^53 floatmin(T)`;
otherwise the visit takes the full step. The `Float64` copy of the columns and the Gram
matrix are workspace of the solver, allocated when the first bound that uses them is
computed and sized by the largest group of the iterate: `n` times that size, and its
square, in `Float64`. The solver keeps no other copy of the columns. For a group of one coefficient, the penalty is a term of an L1 penalty, and
with the default weights `GroupNormL2` with only singleton groups is the same problem
as `NormL1`, which the dense-vector solvers accept. Momentum does not apply:
`momentum = true` is refused for a `BlockIterate`, and `nothing` or `false` both mean
plain block coordinate descent. The stopping test works as in the relative-tolerance
discussion above with the change of a group, the norm of its displacement; see
[Numerical behavior](numerics.md). As for the lasso, `converged = true` is not an
optimality certificate: check the group KKT conditions independently, as in the example.
`ProximalGradientDescent` and `AccProxGradDescent` take the block soft threshold of every group at each step and
report `converged = true` only where the group KKT residual passes its check; the
[group lasso tutorial](examples/problems/group_lasso.md) solves one problem with all three solvers, and
[Group lasso: CD, PGD and APG](examples/comparisons/group_lasso_solvers.md) compares the three on one
seeded problem.

### Cost of the lazy curvature

The measurements in this section were made before groups of two columns had their own
rule: the bound of a group of two columns, like that of a larger group, took the copy of
its columns, the Gram matrix and an eigenvalue computation.

The lazy curvature and the zero-group screen save the curvature of a Gram-route group only
while that group passes the screen at every visit. A screened visit still computes the
correlations of the group. In one profile, a screened visit took 155 ns and a visit to a
zero group whose curvature was already computed took 135 ns (neither changed a
coefficient), so these zero-group visits cost about the same in that profile: the screen
saves the curvature, not the visit.

From a cold start (`x = 0`, residual `y`), the first full pass starts at the residual `y`
and screens each eligible group against the current residual, after the updates of the
groups before it; the guards of the screen can bypass it for a group. A group that fails the
screen needs its curvature, and it can leave the active set again later. The saving
therefore depends on how many groups ever fail the screen, not on the number of active
groups at the solution. In the low-occupancy designs measured below, many groups entered the
active set in the first pass at a small `λ / λmax` and left it later. Starting a path from a
nearby solution can reduce the number of groups that fail the screen in the first pass; this
has not been measured.

Measured on these designs, with `n = 500` rows, groups of 2 or 8 columns, and `λ` set so that
about 5% of the groups were active at the solution (`λ / λmax` about 0.06 to 0.10):

- On one exclusive node, with one thread, Julia 1.10 and 1.13, the solve was 1.05 to 1.45
  times faster than computing every curvature before the first pass at `p = 1024`, and 1.5
  to 3.3 times at `p = 256`, except 1.2 to 1.3 times in one layout and group size on Julia
  1.13. At high occupancy the largest slowdown against computing every curvature before the
  first pass was about 4%. The two computations gave bit-identical iterates in every cell.
- A separate diagnostic profile on a shared node (absolute times noisy) found that 40% to 68%
  of the groups computed a curvature in the first pass. In a `λ` sweep on one of these
  designs (`p = 1024`) in that profile, the ratio was about 1.9 to 3.6 for `λ / λmax ≥ 0.2`,
  and about 1 for `λ / λmax ≤ 0.04`.

These are measurements on these designs, not general claims: the ratio depends on `n`, the
group sizes, the layout and `λ`.

## What is supported now?

The [Problem × solver matrix](@ref "Problem × solver matrix") of
[Supported problems](support.md) lists, for each problem, the solvers, iterates and
element types with verified support, and the sections below it give the exact input rules.

For PGD and APG on a dense `Vector`, `NormLinf(lambda)` (`lambda * maximum(abs, beta)`) is also accepted, with least squares or one
positive scalar multiple of it; use `ProximalGradientDescent` or `AccProxGradDescent` for it, because this `CDSolver` needs a
separable penalty for its coordinate step and refuses `NormLinf` for a dense `Vector`, a `SparseIterate` and a `BlockIterate`. The
ℓ∞ penalty can tie the largest coefficients at a common magnitude and does not in general give zeros; in exact arithmetic, 0 is a
minimizer exactly when `lambda` is at least `‖∇f(0)‖₁ = α‖Xᵀy‖₁`. A proposed stop is verified by the
[generic proximal-gradient check](numerics.md#The-generic-stationarity-check). See [the ℓ∞ tutorial](examples/problems/linf_regularized_regression.md).

Coordinate descent can also solve a group lasso on a `BlockIterate` with a
`GroupNormL2` penalty, as described above and in [Supported problems](support.md).
Coordinate descent can additionally store coefficients in a one-dimensional
[ProximalBase SparseIterate](https://mlakolar.github.io/ProximalBase.jl/dev/).
It tracks coordinates that are explicitly active, and can be helpful for
a sparse result. It does **not** make the feature matrix sparse.
In the [SparseIterate section of the lasso tutorial](examples/problems/lasso.md#Coordinate-descent-on-a-SparseIterate),
the first coefficient is exactly zero and the second is active.

Unsupported historical knobs are listed in one
[deferred-features table](support.md). Do not use gap, screening or
preconditioning settings, or accelerated variants other than `AccProxGradDescent`,
until they are implemented and tested.

