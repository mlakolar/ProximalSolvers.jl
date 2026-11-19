# [Developer architecture](@id architecture)

Verbatim migration checkpoint; source provenance is recorded below.

<!-- baseline: docs/src/internals.md:1-67 -->

# Developer architecture

This page is for **contributors working on the implementation**, not a
prerequisite for using the package. Begin with [Getting started](getting-started.md)
and [Supported problems](support.md) if you are new.

## High-level organization

The development core keeps two separate least-squares lasso engines, the
second with an accelerated variant (both engines also accept an
unweighted `ElasticNet` and a `NormL1` with weights):

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
  when the bounds rule out a refusal (under the eigenvalue model, for groups of three
  or more columns and for groups of two columns outside the range of their closed
  form), and computed in `_prepare!` otherwise. The predictable curvature and step
  refusals therefore happen before any random draw. A lazily computed curvature that
  refuses, or an exception of the eigenvalue routine, happens during a pass. A group
  of two columns takes its curvature in closed form from the three entries of its
  Gram matrix, formed in one pass, where their trace is inside the range that its
  proof covers (`_gram2_curvature`), and the general eigenvalue route otherwise. The
  default `_prepare!` of the scalar models does nothing. A visit to a nonflat group whose block is zero first screens it,
  when the reciprocal `1 / s` is a normal number of the scale's type and either all
  correlations are zero or the largest magnitude is at least `2^53 floatmin(T)`, with ProximalBase's
  `prox_block!` at the step `1 / s`, and returns without computing a still-deferred
  curvature when the result is zero; otherwise a group step uses `prox_block!` on
  a compact scratch vector. The engine, the pass schedule, the change test (with
  the change of a group as its statistic) and the private-copy transaction are
  those of the `SparseIterate` path. The rules are in
  [Numerical behavior](numerics.md).
- **Square-root lasso coordinate descent:** the `SparseIterate` engine with a private
  `SqrtLSModel`, which wraps the least-squares model with the loss scale 1 (data, residual,
  curvature cache, residual update and stopping scales) and adds its own coordinate step. A
  converged full pass calls the model hook `_stop_check!`, which returns `:converged`,
  `:uncertified` or `:retry` (after lowering the threshold, which the loop then reads again). Its
  generic method returns the constant `:converged`, so the least-squares and group models keep the
  change test as their stop; the square-root model runs its duality certificate there and records
  the certified bound in the result's `gap`.

Losses, L1 proximal operations and sparse coefficient storage live
in ProximalBase. Solver orchestration and algorithm-specific results
live here. CD and the gradient solvers intentionally retain separate option and
result types rather than introducing an untested shared engine.

For exact source-level contracts, exceptional recovery, branch history,
validation policy and deferred APIs, consult
[Contributor implementation notes](developer/implementation-notes.md).
For a beginner explanation of the algorithms, see
[What problem, which algorithm?](concepts.md).

<!-- baseline: docs/src/developer/implementation-notes.md:431-473 -->

## internals.md (previous detailed notes)


The thirteen active files are module/types/blocks/line_searches/solve/utils/precompile,
solvers/image_models, proximal_gradient_descent and accelerated_proximal_gradient_descent,
and cd/models/solver/leastsquares. Small native helpers support the separately cached
algorithms and existing result types; PGD and APG share the LS image model, the
gradient engine `_solve_gradient!`, the stopping rules and the result type. CDModel and state hooks are private extraction/test seams, not
promises of custom loss or workspace support. Generic block/metric/certificate/
logging frameworks are deferred.

The dense and `SparseIterate` entry points of CD share one private run on a
PB SparseIterate (model, state, passes, warning and finite-objective check). The
dense wrapper builds that iterate from the vector and scatters the result back.
The owner wrapper copies the caller's owner with `copy`, runs on the copy and
commits with a same-shape `copyto!` through PB's public storage methods only,
after the finite-objective check; it does not rebuild through a dense vector.
Each copy preserves the state of its source: the initial copy keeps the entry
state (active zeros and slot order), and the commit writes the final state of the
working copy, after any compaction, which removes zeros and can reorder slots
during the passes. Validation is split into data
checks shared by both gates and an owner gate that inspects only public active
values and tests aliasing against the original owner. PGD keeps the dense gate and
refuses owners.

The current exact PB pin is `7d5d1e006b02814fb28f8cfb5eca20a05d73ee9e`. CD uses
its scalar `prox_block` oracle; PGD retains fused `value_and_prox!`. All three solvers take the least-squares value from the PB oracles named above, and PGD and APG take the coefficient gradient from them. The private PB
SparseIterate contract remains unchanged. PR #237's group/workspace migration is
not imported. The gated analysis job always runs isolated exact-source paired
diagnostics against PB A e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291 and frozen
PS 64930401cfc0451e886728d916263c4dab2baf36 (CD and PGD only), including when package tests are
not selected or reused. Loaded paths, clean Git HEADs and source digests are
checked; version strings never skip probes. C0 and the provenance audit describe
the independent full-suite mathematical/behavioral tests.

Current CI is stable Julia1 Linux x64 only for every tier. Preserve required
checks, full master validation, coverage, benchmark-analysis and conservative
policy-aware nightly reuse. Historical platform runs and the deferred macOS C0
warm-convergence failure remain historical, not newly passing claims.

Historical measured performance tables remain in the repository's
[full-package performance record](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/docs/audit/historical-full-performance.md).
They are not replaced by unmeasured minimal-core claims.
