# [Coordinate descent on a SparseIterate](@id CDS-01)

<!-- Migration source: docs/src/developer/implementation-notes.md:L215-L237 -->

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
- A numerical error, such as a nonfinite step, a curvature that underflows or is
  not finite, or a nonfinite final objective, leaves the values, active set, signed zeros and
  order of `x` unchanged. The borrowed RNG may already have advanced; no rollback
  of the RNG is promised. Process termination, out-of-memory conditions and
  concurrent mutation of x, X or y are not covered.
- After a successful call take `activevalues(x)` and `activecoordinates(x)` again:
  the active list may have been replaced or reordered.

<!-- Migration source: src/cd/solver.jl:L79-L82 -->

A `SparseIterate` is solved on a private copy retaining its initial
active zeros and coordinate order. After a completed finite run the caller
receives the complete final state, including any zero-coordinate
compaction. The copy needs `O(p)` extra storage.

