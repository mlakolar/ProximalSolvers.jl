# Numerical behavior

This page explains what a successful solve does **and does not** promise.
You can start using the package without understanding its internal algorithm
code.

## What does converged mean?

- **Coordinate descent (CD):** the change during a full pass has fallen
  below the effective `tol`. With `relative=true` this threshold is
  scaled by a response-dependent quantity; the reported effective
  tolerance can differ from the value passed to the constructor.
- **Proximal gradient descent (PGD):** the algorithm applies multiple
  stopping tests for relative coefficient change, objective change and
  a gradient/proximal residual. These combine by **OR**: passing one can
  stop the algorithm, even if the others remain large.

Neither `converged=true` is a certificate of mathematical optimality.
For the convex lasso, compute the [independent KKT residual](sparsity-and-kkt.md).
PGD's printed `|g(x)|` label is an internal stopping residual, **not**
the value of the user's L1 penalty.

## Float32 and Float64

Use a consistent element type for `X`, `y` and the coefficients.
We support Float32 and Float64; all entries must be finite, and
intermediate arithmetic must remain finite. Float32 calculations have
less precision; requesting a tolerance below that precision cannot
guarantee the same coefficient accuracy.

For Float32, prefer a native scale:
`(one(Float32)/Float32(n))*LeastSquaresLoss(y,X)`
and `NormL1(Float32(lambda))`. A representable Float64 scalar
from `1/n` is allowed, but the arrays are not converted.

## Results and failures

- CD on dense coefficients calculates on private storage, avoiding a
  partially written dense result if a numerical failure occurs.
- CD on a `SparseIterate` uses a **private copy** and commits the final
  set of active coordinates only after finite completion. This means
  the original coefficient storage is unchanged if the numerical
  solve fails. A pass can remove zeros from the active list and
  change the order of stored coordinates. The RNG can still advance.
- PGD uses in-place dense arrays, and restores the **last accepted**
  iterate if a numerical step fails. Its counters and other internals
  are not transactional.
- Reaching a pass or iteration limit is not convergence. CD can return
  a finite nonconverged solution with a warning.

Gap certificates are not implemented: `gap=NaN` is a placeholder.
For more precise treatment of exceptional arithmetic, compaction,
momentum, callbacks and test provenance, consult the
[technical contract notes](developer/implementation-notes.md).

Continue with [Results and troubleshooting](working-with-results.md)
or the [Glossary](glossary.md).

