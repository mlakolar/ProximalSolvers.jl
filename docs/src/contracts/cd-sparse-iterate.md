# Coordinate descent on a SparseIterate

The scalar algorithm is specified in [CD-01](@ref). These clauses specify the
additional ownership and transaction behavior of a one-dimensional ProximalBase
`SparseIterate`, together with the shared [inputs](@ref IN-01) and [results](@ref RES-01).

## [CDS-01 Validation before ownership or RNG changes](@id CDS-01)

**Statement.**

Only public active values of a `SparseIterate` are checked for finiteness. Every input
validation failure occurs before copying the owner and before any RNG draw, leaving the
owner untouched. This includes an unsupported owner, element type or shape; active
NaN/Inf; invalid data, loss, penalty, scalar, option or keyword; and prohibited aliasing.

**Applies to.** One-dimensional `SparseIterate{Float32}` or `SparseIterate{Float64}` passed to `CDSolver`.

**Code.** `src/solve.jl`: owner preflight and `solve!` wrapper.

**Tests.** `test/sparse_cd.jl`: "owner refusals happen before copying, mutation or RNG draws", "buffers of the owner cannot be borrowed as data".

**Sources.** `docs/src/developer/implementation-notes.md:L215`, `docs/src/developer/implementation-notes.md:L217`, `docs/src/developer/implementation-notes.md:L221`, `docstring:src/solvers/proximal_gradient_descent.jl:L346`.

## [CDS-02 Private work and initial ordering](@id CDS-02)

**Statement.**

The solve uses `work = copy(x)`, retaining the initial active zeros and slot order.
It does not rebuild the owner through a dense vector and needs `O(p)` extra storage.
Passes, momentum and stopping are those of the dense wrapper. A dense solve and an
owner solve from the same canonical state have the same arithmetic and RNG schedule;
another slot order of the same active set can produce another trajectory and final point.

**Applies to.** Scalar CD owner solves with the supported least-squares or square-root loss.

**Code.** `src/solve.jl`: private owner copy; `src/cd/solver.jl`: common engine.

**Tests.** `test/sparse_cd.jl`: "dense and owner solves agree from the same state", "slot order changes the trajectory, not the accuracy".

**Sources.** `docs/src/developer/implementation-notes.md:L221`, `docs/src/developer/implementation-notes.md:L260`, `docstring:src/cd/solver.jl:L79`, `docs/src/developer/implementation-notes.md:L442`, `docstring:src/solvers/proximal_gradient_descent.jl:L346`.

## [CDS-03 Commit after a finite completed run](@id CDS-03)

**Statement.**

A run that completes with a finite objective commits its complete final state through
a same-shape `copyto!(x, work)` and returns the caller's `x` itself as `minimizer`.
This includes a finite pass-limit return (`converged = false`, with a warning).
With `maxpasses = 0`, the entry state is preserved exactly, including active zeros,
signed zeros and order. After a normal pass, zero coordinates are compacted and are
not restored; compaction moves the last active coordinate into a removed slot, so the
order is not sorted. After success, acquire `activevalues(x)` and
`activecoordinates(x)` again because their active lists may have been replaced or reordered.

**Applies to.** Completed finite scalar CD owner solves, whether converged, uncertified after a square-root fallback, or at the pass limit.

**Code.** `src/solve.jl`: final objective check and owner commit; `src/cd/solver.jl`: compaction.

**Tests.** `test/sparse_cd.jl`: "pass semantics: zero passes, limits, activation and compaction", "finite pass limits commit a nonconverged state", "the result is the caller's owner, with an independent state".

**Sources.** `docs/src/developer/implementation-notes.md:L224`, `docs/src/developer/implementation-notes.md:L235`, `docs/src/developer/implementation-notes.md:L260`, `docstring:src/cd/solver.jl:L79`, `docs/src/developer/implementation-notes.md:L442`, `docstring:src/solvers/proximal_gradient_descent.jl:L356`.

## [CDS-04 Failure leaves the caller owner unchanged](@id CDS-04)

**Statement.**

A numerical exception propagated out of `solve!`, including a nonfinite coordinate
step, an underflowing or nonfinite curvature, or a nonfinite final objective,
leaves the caller's values, active set,
signed zeros and slot order unchanged. A borrowed RNG can already have advanced;
RNG rollback is not promised. Process termination, out-of-memory conditions and
concurrent mutation of `x`, `X` or `y` are outside this transaction guarantee.

A square-root fallback stage can instead catch an `ArgumentError` and return
the initial stopped point as a completed uncertified result. That point can
differ from the caller's original point and commits when its final objective
is finite. [CDQ-05](@ref) owns this recovery rule, its pass accounting and RNG
semantics; it does not weaken the guarantee for an exception that propagates.

**Applies to.** Numerical failures of scalar CD owner solves.

**Code.** `src/solve.jl`: private run and finite-objective commit boundary.

**Tests.** `test/sparse_cd.jl`: "nonfinite updates and objectives leave the owner unchanged", "a runtime failure may advance the RNG but preserves the owner".

**Sources.** `docs/src/developer/implementation-notes.md:L230`, `docs/src/developer/implementation-notes.md:L260`, `docstring:src/solvers/proximal_gradient_descent.jl:L356`. The later handled-stage refusal is [f573224f, `_fallback!`](https://github.com/mlakolar/ProximalSolvers.jl/blob/f573224f70058be24b81378ab2d6e1c752eb93e8/src/cd/sqrtlasso.jl#L602-L665), covered by its dense/owner refusal tests.
