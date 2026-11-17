# Developer architecture

This page is for **contributors working on the implementation**, not a
prerequisite for using the package. Begin with [Getting started](getting-started.md)
and [Supported problems](support.md) if you are new.

## High-level organization

The development core keeps two separate least-squares lasso engines, the
second with an accelerated variant (the proximal gradient engine also accepts an
unweighted `ElasticNet`):

- **Coordinate descent:** builds and updates a ProximalBase
  `SparseIterate` internally, visiting full coordinate sets and then
  active ones. Dense vectors are copied into the internal representation;
  caller-supplied sparse coefficient storage is copied privately and
  committed on a finite completed run.
- **Proximal gradient descent:** maintains full dense iterate and gradient
  buffers, using a least-squares image cache and backtracking line search.
  The accelerated variant (`AccProxGradDescent`) reuses the same image model,
  iteration engine, stopping tests and result type, with its own state,
  extrapolation, restart and line search.
- **Group coordinate descent:** the same engine on a ProximalBase
  `BlockIterate`, with groups as the coordinates. A private `BlockLSModel`
  wraps the least-squares model of the lasso (data, residual and column
  kernels) and adds a curvature bound per group, `NaN` while not computed.
  After the residual is initialized and before the first pass (when
  `maxpasses > 0`), a `_prepare!` step sets the bound of a flat group and of an
  ordinary one-column group, and checks the step band; a group on the Gram route
  gets cheap bounds, and its curvature is left for the first visit that needs it
  when the bounds rule out a refusal (under the eigenvalue model, for groups of two
  or more columns), and computed in `_prepare!` otherwise. The
  predictable curvature and step refusals therefore happen before any random draw.
  A lazily computed curvature that refuses, or an exception of the eigenvalue
  routine, happens during a pass. The default `_prepare!` of the scalar models
  does nothing. A visit to a nonflat group whose block is zero first screens it,
  when the reciprocal `1 / s` is a normal number of the scale's type and either all
  correlations are zero or the largest magnitude is at least `2^53 floatmin(T)`, with ProximalBase's
  `prox_block!` at the step `1 / s`, and returns without computing a still-deferred
  curvature when the result is zero; otherwise a group step uses `prox_block!` on
  a compact scratch vector. The engine, the pass schedule, the change test (with
  the change of a group as its statistic) and the private-copy transaction are
  those of the `SparseIterate` path. The rules are in
  [Numerical behavior](numerics.md).

Losses, L1 proximal operations and sparse coefficient storage live
in ProximalBase. Solver orchestration and algorithm-specific results
live here. CD and the gradient solvers intentionally retain separate option and
result types rather than introducing an untested shared engine.

For exact source-level contracts, exceptional recovery, branch history,
validation policy and deferred APIs, consult
[Contributor implementation notes](developer/implementation-notes.md).
For a beginner explanation of the algorithms, see
[What problem, which algorithm?](concepts.md).

