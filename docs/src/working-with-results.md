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

Both solvers report `minimizer`, `minimum` and `converged`.
Coordinate descent also provides `passes`, `maxchange`, and `tolerance`.
PGD provides `iterations`, more detailed stopping residuals and
an optional iteration `trace`. These differ because the current package
retains two algorithm-specific result types.

**Warning:** `converged=true` means a stopping rule was satisfied, not
that the output is certified optimal. For the lasso, use the separate
[numerical KKT check](sparsity-and-kkt.md). A result's `gap=NaN` and
CD's `kkt_checks=0` are placeholders: neither is a computed certificate.

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
PGD can stop when **any** of its historical stopping criteria
is met, so a small `gradtol` does not by itself force a small KKT residual.

Trace fields such as `dxx` describe relative iterate changes, and
`backtrack_steps` counts line-search trials. These are solver
diagnostics, not changes to the statistical model.

## Common problems

| Symptom | Check |
| --- | --- |
| `DimensionMismatch` | `size(X, 1) == length(y)` and `size(X, 2) == length(beta)` |
| Type/unsupported input error | Dense Float32 or Float64 `X` and `y` with matching coefficient type; only ordinary least squares + unweighted L1 |
| Penalty seems too strong or too weak | `LeastSquaresLoss` is a sum; explicitly multiply by `1/n` for mean-normalized lasso |
| PGD rejects `SparseIterate` | PGD needs a dense coefficient vector; CD supports one-dimensional `SparseIterate` |
| Convergence flag is false | Inspect the solver's iteration/pass limit; check the [KKT residual](sparsity-and-kkt.md) |
| `gap` is NaN | Gap certification is not implemented |
| Float32 precision looks poor | Start with native Float32 inputs/scales, check the KKT residual; Float32 has lower precision |
| Coefficients appear to change unexpectedly | `solve!` mutates the supplied coefficients; copy them to save the old solution |

A [`SparseIterate`](https://mlakolar.github.io/ProximalBase.jl/dev/)
stores active coordinate values. With CD, the caller's object is updated
only after a completed finite run. The active-coordinate list may change:
re-read `activecoordinates` and `activevalues` after solving rather
than retaining old views. See [Supported problems](support.md).

For other limitations, see [Numerical behavior](numerics.md) and
the [Glossary](glossary.md).

