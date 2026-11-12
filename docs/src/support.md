# Supported API, ownership and migration

Vector y and Matrix X with the same Float32 or Float64 element type are
supported, with positive consistent dimensions and finite entries. The iterate
is a dense Vector of that type for both solvers, and additionally a
one-dimensional `SparseIterate` of that type for [`CDSolver`](@ref) only;
[`ProximalGradientDescent`](@ref) refuses every `SparseIterate`. Use raw PB LS or
one positive finite scalar Scaled LS, and unweighted finite nonnegative NormL1.
Parameters must be representable; positive values must not round to zero.
Scaling is explicit: raw LS means sum(abs2,y-X*x)/2; divide by n explicitly for
normalized lasso. Accepted wider scalars retain historical conversion sites.

X/y are borrowed read-only during solves and must not alias mutable x; for a
`SparseIterate` the check uses the owner's whole backing storage, so even an
owner with no active entries is refused when `parent(activevalues(x))` or a
reshape of it is passed as y or X. Results share x; extended traces copy
x/gradient. Unsupported requests fail before mutation. A CD numerical exception
preserves input x; PGD numerical step exceptions restore its last accepted point
and rethrow. Counters/buffers are not generally transactional. Shape errors are
DimensionMismatch; unsupported combinations/options are informative
ArgumentError.

## CD on a `SparseIterate`

- Only the public active values are checked for finiteness. Every validation
  failure (unsupported owner, element type, shape, active NaN/Inf, data, loss,
  penalty, scalar, option, keyword or alias) happens before the owner is copied
  and before any RNG draw, and leaves the owner untouched.
- The run uses `work = copy(x)`, which keeps the active zeros and the slot order,
  and nothing is rebuilt through a dense vector. Passes, momentum and stopping
  are those of the dense wrapper; the extra storage is O(p).
- A run that completes with a finite objective commits the complete final state
  with a same-shape `copyto!(x, work)` and returns `x` itself as `minimizer`.
  This covers a finite `maxpasses` limit (`converged = false`, with a warning)
  and `maxpasses = 0`, which leaves exactly the entry state, including active
  zeros, signed zeros and order. A normal pass compacts zero coordinates, and
  they are not restored; the order is not sorted.
- A numerical error, such as a nonfinite step, a curvature that underflows or a
  nonfinite final objective, leaves the values, active set, signed zeros and
  order of `x` unchanged. The borrowed RNG may already have advanced; no rollback
  of the RNG is promised. Process termination, out-of-memory conditions and
  concurrent mutation of x, X or y are not covered.
- After a successful call take `activevalues(x)` and `activecoordinates(x)` again:
  the active list may have been replaced or reordered.

## Deferred

Sparse designs, sparse vectors and views as iterates, `SparseIterate` for proximal
gradient descent, matrix-shaped, group and symmetric owners, weighted/group
penalties, matrix responses, intercepts/offsets, generalized losses/compositions, acceleration, ADMM/Newton,
primal-dual/SLOPE/graphical models, paths/screening/certificates/workspaces/refit
and reweighting are deferred. Nondefault feature requests are refused. gap=NaN
and CD kkt_checks=0 are compatibility sentinels, not computed diagnostics.

This is a breaking support reduction. Version/registration and any public
release remain a separate decision; existing releases are untouched. Protected
archive refs preserve the complete snapshot; legacy/full remains the historical
working branch. Restore capabilities selectively; do not merge it wholesale.
