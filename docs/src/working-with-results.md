# Results and troubleshooting

`solve!` writes the coefficients into the array you pass to it, and returns
a result describing the last point and the stopping process.

## Read a result

~~~@example results_cd
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
f = (1 / length(y)) * LeastSquaresLoss(y, X)
penalty = NormL1(0.1)
beta = zeros(2)
r = solve!(beta, f, penalty,
           CDSolver(order=:cyclic, momentum=false))
@assert r.minimizer === beta
@assert isapprox(beta, [1.7, -0.925]; atol=1e-7)
(; coefficients=beta, objective=r.minimum, passes=r.passes,
   converged=r.converged)
~~~

Every solver reports `minimizer`, `minimum` and `converged`.
Coordinate descent also provides `passes`, `maxchange`, and `tolerance`.
PGD and APG provide `iterations`, more detailed stopping residuals and
an optional iteration `trace`. ADMM provides `iterations`, `status`, and
primal and dual residuals with their tolerances. `ProxNewton` provides `iterations`,
`passes`, the largest KKT score `kkt` of the returned point, its `tolerance` and a
`stop_reason` (`:converged`, `:maxiter` or `:stalled`). `LogisticADMM` provides the same, the
steps of its scalar roots, its primal and dual residuals with their thresholds, two diagnostics of
its optimality conditions (`dual_kkt` and `predictor_residual`), its predictor `t` and dual `u`, with
one entry per observation, and the stop reason `:prox_failed` for a failed scalar root.

A convergence flag reports the solver's implemented stopping criterion;
[the result contract](@ref RES-01) gives the precise meaning and qualifications.

| Solver/problem | Meaning of `converged=true` |
| --- | --- |
| Least-squares CD, including group and multi-response fits | The pass-change test succeeded; it is not an independent optimality check |
| PGD/APG | A stopping proposal passed the applicable computed stationarity check; with `IndBallL1`, at a point classified inside the ball, and `approximate_solution` marks a passing check elsewhere ([IN-12](@ref)) |
| `ProxNewton` (logistic regression) | The largest KKT score of the returned point is finite and at most `tol`; see [PN-05](@ref) |
| `LogisticADMM` (logistic regression) | The primal and dual residual tests passed and the largest KKT score of the returned point is at most `tol`; see [LA-04](@ref) |
| Square-root lasso with CD | The square-root certificate succeeded under its documented conditions |
| Consensus ADMM | The primal and dual residual tests and any required stagnation check passed. See [ADM-02](@ref) |

Use an [independent KKT check](@ref learn-02) or an appropriate
[duality gap](@ref learn-07) when assessing a fit. An unavailable `gap` is `NaN`,
not zero; CD's `kkt_checks=0` is also a placeholder. The square-root certificate
is the documented exception; see [its contract](@ref CDQ-01).

Square-root lasso can try bounded smoothing recovery after an uncertified
change-test stop. Its `passes` includes that work and stays within `maxpasses`.
Recovery can certify the stopped point or return a point with a proved lower
objective, but it need not recover an exact fit. Read `converged` and `gap`
together; [the bounded recovery contract](@ref CDQ-05) specifies the return rule.

For nonnegative lasso, the independent check must include the coefficient
constraint. At a positive coefficient the score is `abs(grad[j] + lambda)`;
at zero it is `max(-(grad[j] + lambda), 0)`. A positive derivative at zero
satisfies the constraint's optimality condition. See the
[nonnegative example](examples/problems/nonnegative_lasso.md) and
[the constrained stopping rule](@ref STOP-16).

## Avoid accidentally overwriting results

~~~@example results_cd
saved_coefficients = copy(beta)
new_result = solve!(beta, f, NormL1(1.0),
                    CDSolver(order=:cyclic, momentum=false))
@assert isapprox(saved_coefficients, [1.7, -0.925]; atol=1e-7)
@assert isapprox(beta, [0.0, -0.25]; atol=1e-7)
(; saved_coefficients, new_coefficients=beta)
~~~

The old `r.minimizer` points to the same `beta` that the second solve
overwrote. Save a copy when keeping past fits. For ADMM, the same applies
to the scaled dual if you pass it as `u` in another solve.

## What PGD's output labels mean

The result display's `|g(x)|` refers to an **internal
gradient/proximal stopping residual**, **not** the value of your
penalty object, even if you named that object `g`. Likewise,
the displayed `|x - x'|` abbreviates a stopping diagnostic;
see the [API documentation](api.md) for precise definitions.
PGD's stopping tests combine by OR and a proposal must pass the applicable
stationarity check; see [the stopping contract](@ref STOP-01).

Trace fields such as `dxx` describe relative iterate changes, and
`backtrack_steps` counts line-search trials. These are solver
diagnostics, not changes to the statistical model.

## Common problems

| Symptom | Check |
| --- | --- |
| `DimensionMismatch` | `size(X, 1) == length(y)` and `size(X, 2) == length(beta)` |
| Type/unsupported input error | Compare the problem, solver, iterate and element type with the [Problem × solver matrix](@ref "Problem × solver matrix"), and the input with the rules of [Supported problems](support.md) |
| Penalty seems too strong or too weak | `LeastSquaresLoss` is a sum; explicitly multiply by `1/n` for mean-normalized lasso |
| PGD rejects `SparseIterate` | PGD needs a dense coefficient vector; CD supports one-dimensional `SparseIterate` |
| PGD or APG rejects `BlockIterate` | PGD and APG take a dense `Vector{T}`, with a `GroupNormL2{T}` penalty for the group lasso; only CD takes a `BlockIterate` |
| `DimensionMismatch` naming groups, or an error naming a group | The groups of `BlockIterate` and `GroupNormL2` must be equal in number, order and members; an error naming a group is a curvature or step refusal, see [Numerical behavior](numerics.md), or a weight or parameter refusal such as `group weight 2 …` |
| Convergence flag is false | Inspect the solver's iteration/pass limit; check the [KKT residual](sparsity-and-kkt.md); for `ProxNewton`, read `stop_reason` (`:maxiter` spent the iteration budget, `:stalled` found no accepted step); for `LogisticADMM`, compare `r_norm`, `s_norm` and `kkt` with their thresholds, and try another `ρ` when the residuals decrease slowly |
| `gap` is NaN | Gap certification is implemented only for the square-root lasso with CD; there, `NaN` means that the run stopped without a certificate |
| Square-root lasso: `converged = false` with a warning about a missing duality certificate | No certificate was proved, at the stop or in the fallback that follows it (where the fallback runs), for example at an exact fit (`y = X*beta`), where coordinate descent can stop at a coordinatewise minimum that is not a minimum and the fallback need not recover; see [`CDSolver`](@ref) and [an example](@ref sqrt-lasso-exact-fit) |
| Float32 precision looks poor | Start with native Float32 inputs/scales, check the KKT residual; Float32 has lower precision |
| Coefficients appear to change unexpectedly | `solve!` mutates the supplied coefficients; copy them to save the old solution |

A [`SparseIterate`](https://mlakolar.github.io/ProximalBase.jl/dev/)
stores active coordinate values. With CD, the caller's object is updated
only after a completed finite run. The active-coordinate list may change:
re-read `activecoordinates` and `activevalues` after solving rather
than retaining old views. See [Supported problems](support.md).

For other limitations, see [Numerical behavior](numerics.md) and
the [Glossary](glossary.md).

