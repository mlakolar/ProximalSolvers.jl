# Results and troubleshooting

The solver writes into the array or coordinate owner that you supply.
The returned result reports the final point, objective and stopping information.

## Read the result

~~~julia
using ProximalBase, ProximalSolvers

X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
f = (1 / length(y)) * LeastSquaresLoss(y, X)
g = NormL1(0.1)
x = zeros(2)

r = solve!(x, f, g, CDSolver())
@show r.minimum                  # value of f(x) + g(x)
@show r.passes                   # CD passes performed
@show r.converged                # historical change stopping
@assert r.minimizer === x        # not a separate coefficient copy
saved_coefficients = copy(x)
~~~

Both result families provide `minimizer`, `minimum` and `converged`, but the
iteration details differ.

| Field | CD result | PGD result |
| --- | --- | --- |
| Iteration count | `passes` | `iterations` |
| Change diagnostics | `maxchange`, `tolerance` | `x_residual`, `f_residual`, `g_residual` and tolerances |
| History | No full trace | `trace` when `store_trace=true` |
| Other | `kkt_checks=0` and `gap=NaN` are placeholders | `gap=NaN` is a placeholder; call and backtracking counts are available |

A true `converged` flag is **not** a KKT certificate and does not by itself
certify statistical or optimization accuracy. Check the objective and, where
necessary, the optimality conditions independently. On this small example
the analytic coefficients are `[1.7, -0.925]`; do not use that reference
for your own data.

## Avoid accidental overwrites

`solve!` modifies `x` in place. In particular:

~~~julia
first_solution = copy(x)
another_result = solve!(x, f, NormL1(0.2), CDSolver())
# first_solution is preserved; r.minimizer refers to the now-reused x
~~~

If `x` is a `SparseIterate`, the final state is committed to the same owner
only after a finite completed CD run. Its active coordinates may be compacted
or reordered; do not hold old `activevalues` or `activecoordinates` views
across solves. A numerical exception leaves the caller's owner unchanged,
but the RNG used by random-order CD may have advanced. PGD instead restores
the last accepted dense point after a numerical step exception.

## Common questions

| Symptom | Likely cause and next step |
| --- | --- |
| `ArgumentError` about types or unsupported loss/penalty | Check that `X`, `y` and `x` all use the same Float32/Float64 type and that the model uses dense least squares and unweighted L1 |
| `DimensionMismatch` | Check `size(X) == (length(y), length(x))` |
| Unexpected penalty strength | Raw `LeastSquaresLoss` is `1/2` of the residual sum of squares; multiply by `1/n` for the normalized convention |
| PGD refuses `SparseIterate` | Use a dense vector for PGD, or choose coordinate descent |
| `converged == false` | Inspect the pass/iteration limit and independent objective accuracy; do not treat the flag as an optimality certificate |
| `gap` is `NaN` | Gap certificates are deferred, not broken computations |
| `NaN` or overflow in extreme data | Inputs must be finite and intermediate computations must remain finite; rescale the problem or inspect the numerical contract |
| Earlier result appears to change | `result.minimizer` shares the caller's `x`; use `copy(x)` before the next solve |

## Where to look next

The [Getting started](getting-started.md) guide explains the objective
and the first run. [Choosing a solver](choosing-solver.md) describes
configuration, [Supported API and migration](support.md) records the
full current limitations, and [Numerical behavior](numerics.md)
documents stopping and exceptional arithmetic. The [API reference](api.md)
contains individual Julia docstrings.

If you are looking for sparse design matrices, generalized losses, group
penalties, path algorithms or the historical larger solver suite, these are
**not** features of the current development `master`. They remain separate
restoration work; the historical code is preserved under `legacy/full`.
