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
an optional iteration `trace`. These differ because the current package
retains two algorithm-specific result types.

**Warning:** for PGD and APG, `converged=true` means that a stopping test
proposed a stop and that the computed KKT residual `‖G‖∞` at the returned point
is below `max(gradtol, 64eps(T)) * max(λ, λmax)`, with `λmax = α‖Xᵀy‖∞` and `λ` the ℓ1 level of the
penalty (`λ` of `NormL1`, `λ1` of `ElasticNet(λ1, λ2)`): a
working-precision value. `converged = true` guarantees only that the computed,
normalized KKT residual `‖G‖∞ / max(λ, λmax)` is below `max(gradtol, 64eps(T))` (the
threshold is formed in `T`, where it can round or overflow; see
[the stationarity check](numerics.md)). It is not
an exact-arithmetic certificate, not a bound on the distance to a minimizer, and
does not guarantee coefficient accuracy on ill-conditioned designs (see
[the stationarity check](numerics.md)). For CD with least squares or the group lasso it
means that a stopping rule was satisfied. Neither certifies the output as optimal. For the lasso,
use the separate [numerical KKT check](sparsity-and-kkt.md). For CD with the square-root loss,
`converged=true` means that a duality certificate proved `(P − P*)/P* ≤ 1e-4`, and `gap` holds the
proved bound (see [`CDSolver`](@ref)). Otherwise a result's `gap=NaN` and CD's `kkt_checks=0` are
placeholders: neither is a computed certificate.

For PGD and APG with a `NormLinf(λ)` penalty, `converged=true` means that a stopping test proposed a stop and that the
direct KKT residual `min over v ∈ ∂‖x‖∞ of ‖∇f(x) + λ v‖₁` (an ℓ1 norm) at the returned point is below
`max(gradtol, 64eps(T)) * max(λ, ‖∇f(0)‖₁)` (see
[the ℓ∞ check](numerics.md#The-stationarity-check-for-NormLinf)). It is a working-precision value computed from the computed
gradient with compensated sums formed in `Float64` (the check refuses for more than `2^24 - 1` entries of `Float64` data and more than `2^32` of `Float32` data), not an
exact-arithmetic certificate: within that range a kept stop has an exact residual (for the supplied gradient) below the computed threshold times `1 + 2^-10`,
and the computed gradient's own rounding error is not covered (see [the ℓ∞ check](numerics.md#The-stationarity-check-for-NormLinf)). A proposed stop costs one
more gradient for APG (counted in `grad_calls` before the call limits are compared, so a stop that the check refuses can reach
`grad_calls_limit`) and no proximal evaluation. A solve can also end through a limit, an objective increase or stagnation with
`converged=false` and without a stop that passed the check. The active set is found by exact equality of magnitudes, without tolerance; the
iterates of PGD and APG store the entries that the clip ties as `±τ` with the same `τ`. An iterate whose entries near the maximum have unequal
magnitudes has the smaller ones off the active set, which can make the check refuse when their gradient contribution is too large.

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
overwrote. Save a copy when keeping past fits.

## What PGD's output labels mean

The result display's `|g(x)|` refers to an **internal
gradient/proximal stopping residual**, **not** the value of your
penalty object, even if you named that object `g`. Likewise,
the displayed `|x - x'|` abbreviates a stopping diagnostic;
see the [API documentation](api.md) for precise definitions.
PGD can propose a stop when **any** of its stopping criteria is met, and the
stop counts only if the computed KKT residual `‖G‖∞` is below
`max(gradtol, 64eps(T)) * max(λ, λmax)`; `gradtol` below `64eps(T)` is
not resolved by that check. See [Numerical behavior](numerics.md).

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
| PGD or APG rejects `BlockIterate` | Only CD solves the group lasso, with a `BlockIterate` and a `GroupNormL2` penalty |
| `DimensionMismatch` naming groups, or an error naming a group | The groups of `BlockIterate` and `GroupNormL2` must be equal in number, order and members; an error naming a group is a curvature or step refusal, see [Numerical behavior](numerics.md), or a weight or parameter refusal such as `group weight 2 …` |
| Convergence flag is false | Inspect the solver's iteration/pass limit; check the [KKT residual](sparsity-and-kkt.md) |
| `gap` is NaN | Gap certification is implemented only for the square-root lasso with CD; there, `NaN` means that the run stopped without a certificate |
| Square-root lasso: `converged = false` with a warning about a missing duality certificate | The certificate did not pass, for example at an exact fit (`y = X*beta`), where coordinate descent can stop at a coordinatewise minimum that is not a minimum; see [`CDSolver`](@ref) and [an example](@ref sqrt-lasso-exact-fit) |
| Float32 precision looks poor | Start with native Float32 inputs/scales, check the KKT residual; Float32 has lower precision |
| Coefficients appear to change unexpectedly | `solve!` mutates the supplied coefficients; copy them to save the old solution |

A [`SparseIterate`](https://mlakolar.github.io/ProximalBase.jl/dev/)
stores active coordinate values. With CD, the caller's object is updated
only after a completed finite run. The active-coordinate list may change:
re-read `activecoordinates` and `activevalues` after solving rather
than retaining old views. See [Supported problems](support.md).

For other limitations, see [Numerical behavior](numerics.md) and
the [Glossary](glossary.md).

