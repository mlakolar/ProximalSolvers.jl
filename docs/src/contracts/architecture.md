# [Developer architecture](@id architecture)

This page is for implementation contributors. Begin with
[Getting started](../getting-started.md) and the [input contract](@ref IN-01) for
package use, or [the algorithm introduction](../concepts.md) for an explanation of
the methods. These internal relationships do not create public extension APIs.

## [ARCH-01 Separate engines and shared gradient machinery](@id ARCH-01)

**Statement.**

The development core keeps coordinate descent separate from proximal gradient
descent. Both least-squares engines support the lasso, weighted `NormL1` and
`ElasticNet`, with or without weights on its L1 term ([IN-03](@ref)); the full
dispatch matrix is [IN-01](@ref). CD retains its
own options and result type. PGD and APG share the least-squares image model, dense
iterate/gradient buffers, gradient engine `_solve_gradient!`, stopping rules and
`OptimizationResults`. APG adds its own extrapolation, restart state and line
search. The separation is intentional; no untested common CD/gradient engine is
introduced.

Small native helpers support the separately cached algorithms and existing result
types. The source snapshot reconciled in [issue #416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416) contains **15**
`.jl` files: the `src/ProximalSolvers.jl` module; six shared files
(`types.jl`, `blocks.jl`, `line_searches.jl`, `solve.jl`, `utils.jl`,
`precompile.jl`); three gradient files under `src/solvers/`
(`image_models.jl`, `proximal_gradient_descent.jl`,
`accelerated_proximal_gradient_descent.jl`); and five CD files under `src/cd/`
(`models.jl`, `solver.jl`, `leastsquares.jl`, `multiresponse.jl`,
`sqrtlasso.jl`). This is a dated source inventory, not a permanent file-count
guarantee. The superseded thirteen-file list is preserved as
[retired historical evidence](@ref ARCH-UNRECONCILED). Among later additions,
`src/solvers/l1ball.jl` holds the ℓ1-ball route of PGD and APG ([IN-12](@ref)): its
working constraint and its methods of the engine's trial and stopping hooks.

ProximalBase supplies losses, L1 proximal operations and sparse coefficient
storage; ProximalSolvers owns orchestration and algorithm-specific results. CD
uses ProximalBase's scalar `prox_block`; regression PGD retains fused `value_and_prox!`, except on
the ℓ1-ball route, whose trials call ProximalBase's `prox!` ([IN-12](@ref)), and graphical-lasso PGD
uses `prox!`.
Ownership of least-squares value/gradient oracles and solver caches is specified
once in [FP-01](@ref). Dependency and diagnostic provenance is in [HIST-03](@ref).

**Applies to.** The current source organization; internal relationships rather than extension guarantees.

**Code.** `src/ProximalSolvers.jl`; `src/solve.jl`; `src/solvers/image_models.jl`; the two gradient solver implementations and `src/cd/`.

**Tests.** `test/minimal_core_characterization.jl`, `test/core_regressions.jl`, `test/accelerated_pgd.jl`, `test/l1ball_numerical.jl`; implementation organization is also visible in the source tree.

**Sources.** `docs/src/internals.md:L1`, `docs/src/internals.md:L3`, `docs/src/internals.md:L7`, `docs/src/internals.md:L9`, `docs/src/internals.md:L13`, `docs/src/internals.md:L18`, `docs/src/internals.md:L57`, `docs/src/internals.md:L62`, `docs/src/developer/implementation-notes.md:L434`, `docs/src/developer/implementation-notes.md:L456`.

## [ARCH-02 CD wrappers, owners and model-specific hooks](@id ARCH-02)

**Statement.**

Dense-vector and `SparseIterate` CD entry points run the same private model, state,
passes, warning and finite-objective check on a ProximalBase `SparseIterate`.
The dense wrapper builds that internal owner from the vector and scatters the
completed result back. The owner wrapper uses `copy`, then commits with same-shape
`copyto!` through ProximalBase's public storage methods after the finite-objective
check; it does not rebuild the owner through a dense vector. Initial/final slot
state, compaction and failure atomicity are specified by [CDS-02](@ref) through
[CDS-04](@ref). Validation separates shared data checks from an owner gate that
inspects public active values and checks aliasing against the original owner. PGD
retains the dense gate and refuses these owners.

Group CD uses the same engine on a ProximalBase `BlockIterate`, treating groups as
coordinates. Its private `BlockLSModel` wraps the scalar least-squares model's data,
residual and column kernels, and adds a curvature bound per group, stored as `NaN`
while uncomputed. `_prepare!` runs after residual initialization and before the
first pass when `maxpasses > 0`; the scalar model's default `_prepare!` is a no-op.
The complete curvature/step refusal timing, cheap Gram bounds, deferred eigenvalue
work, closed-form two-column route and zero-block screen are defined in
[CDG-03](@ref) through [CDG-06](@ref). A group update uses `prox_block!` on a compact
scratch vector. Pass scheduling, the group change statistic and the private-copy
transaction are the scalar engine's corresponding mechanisms with group-specific
rules in [CDG-07](@ref) and [CDG-08](@ref).

Square-root-lasso CD uses the `SparseIterate` engine with a private `SqrtLSModel`.
It wraps the least-squares model at loss scale one (data, residual, curvature cache,
residual updates and stopping scales) and supplies its own coordinate step. A
unsmoothed full-pass change stop calls `_stop_check!`, returning `:converged`, `:uncertified`,
or `:retry`; the retry lowers the threshold, which the loop reads again. The
generic hook returns the constant `:converged`, preserving the least-squares and
group change tests. The square-root model performs its duality certificate there
and records the certified bound in `gap`; [CDQ-03](@ref) and [CDQ-04](@ref) specify
the numerical rules. After a terminal uncertified stop, `_run_cd!` invokes the
model's `_fallback!` before issuing the warning and checking the final objective.
That hook is a no-op for models without a certificate. The square-root model
supplies the bounded smoothing continuation in [CDQ-05](@ref), whose smoothed
stages use the same private engine and whose original-objective bounds decide
the returned point. The outer wrappers still commit only after a finite
completed run.

**Applies to.** Private CD engines, wrappers and model hooks.

**Code.** `src/cd/models.jl`; `src/cd/solver.jl`: `_run_cd!`, `_prepare!`, `_stop_check!`; `src/cd/leastsquares.jl`: model implementations; `src/solve.jl`: wrappers.

**Tests.** `test/sparse_cd.jl`, `test/group_cd.jl`, `test/group_cd_preflight.jl`, `test/multiresponse_cd.jl`, `test/sqrt_lasso.jl`.

**Sources.** `docs/src/internals.md:L13`, `docs/src/internals.md:L23`, `docs/src/internals.md:L48`, `docs/src/developer/implementation-notes.md:L442`. The later fallback seam is [f573224f, the generic model hook](https://github.com/mlakolar/ProximalSolvers.jl/blob/f573224f70058be24b81378ab2d6e1c752eb93e8/src/cd/models.jl#L20-L25) and [the private run boundary](https://github.com/mlakolar/ProximalSolvers.jl/blob/f573224f70058be24b81378ab2d6e1c752eb93e8/src/cd/solver.jl#L562-L577).

## [ARCH-03 Private seams and public support boundaries](@id ARCH-03)

**Statement.**

`CDModel` and state hooks are private extraction and test seams. Their existence
does not promise support for custom losses or public workspaces. Generic block,
metric, certificate and logging frameworks remain deferred under [DEF-01](@ref).
The private ProximalBase `SparseIterate` contract remains unchanged; the historical
group/workspace migration in PR #237 is not imported. Public supported combinations,
validation and transaction boundaries are in the contract pages, not inferred from
private implementation dispatch.

Historical platform and performance records, dependency pins and paired-analysis
provenance are kept in [HIST-03](@ref) and [HIST-04](@ref). Contributor workflow and
CI policy remain governed by the repository's contributor guidance.

**Applies to.** Contributor use of private models/state and the development core support boundary.

**Code.** `src/cd/models.jl`, `src/cd/solver.jl`, public `src/solve.jl` gates.

**Tests.** `test/core_contracts.jl` and private-seam characterization tests; no extension API is claimed by those tests.

**Sources.** `docs/src/internals.md:L62`, `docs/src/developer/implementation-notes.md:L434`, `docs/src/developer/implementation-notes.md:L456`.

## [ARCH-UNRECONCILED Retired: historical source inventory](@id ARCH-UNRECONCILED)

**Retired by [issue #416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416).** [ARCH-01](@ref) gives the authoritative
description of the 15-file source snapshot, including the two CD files omitted
from this earlier list.

**Statement.**

**Original wording retained verbatim for provenance; not a current file-count claim.** The
baseline implementation notes state:

> The thirteen active files are module/types/blocks/line_searches/solve/utils/precompile,
> solvers/image_models, proximal_gradient_descent and accelerated_proximal_gradient_descent,
> and cd/models/solver/leastsquares.

The immutable baseline source tree already contains fifteen `.jl` files, including
`src/cd/multiresponse.jl` and `src/cd/sqrtlasso.jl`, which this older list omits.
The main module file is `src/ProximalSolvers.jl`. The reconciliation retires the obsolete list without treating it as a support
restriction or removing either implementation.

**Applies to.** Provenance of the source inventory in the baseline implementation notes.

**Code.** The immutable baseline `src/` tree, including `src/cd/multiresponse.jl` and `src/cd/sqrtlasso.jl`.

**Tests.** A source-tree inventory establishes this documentation discrepancy; no numerical behavior or new solver test is claimed.

**Sources.** `docs/src/developer/implementation-notes.md:L434`.
