# [Contract and implementation history](@id contract-history)

These notes preserve development history and the provenance of the documented
behavior. They do not turn historical measurements or platform runs into current
performance or support guarantees.

## [HIST-01 Reduced development core and historical branches](@id HIST-01)

**Statement.**

The supported core is a breaking support reduction. Version selection,
registration and a public release remain separate decisions; existing releases
are untouched. Protected archive references preserve the complete snapshot and
`legacy/full` remains the historical working branch. Restore capabilities
selectively rather than merging that branch wholesale.

Registered versions and `legacy/full` may expose features intentionally absent
from this development branch. They represent different development stages, and
this documentation does not give a migration procedure for every historical
algorithm. [Getting started](../getting-started.md) describes source installation;
[DEF-01](@ref) lists deferred capabilities. Numerical, stopping and internal
contracts are now collected under [working precision](@ref FP-01),
[results](@ref RES-01) and [architecture](@ref ARCH-01).

**Applies to.** Development/release history and the relation of the reduced core to older branches.

**Code.** Repository branch/archive policy; current public dispatch in `src/solve.jl`.

**Tests.** This is release and provenance history, not a new claim that historical algorithms pass current tests.

**Sources.** `docs/src/developer/implementation-notes.md:L3`, `docs/src/support.md:L392`, `docs/src/support.md:L394`, `docs/src/support.md:L400`, `docs/src/developer/implementation-notes.md:L249`, `docs/src/developer/implementation-notes.md:L255`, `docs/src/index.md:L9`.

The earlier implementation-notes page collected detailed contracts for contributors
before the beginner rewrite; it was not a prerequisite for solving a lasso.
Those full statements now live in this Contracts layer, while
[Supported problems](../support.md) and the retained
[Numerical behavior entry point](../numerics.md) continue to guide practitioners.

## [HIST-02 Least-squares oracle and scalar-scale alignment](@id HIST-02)

**Statement.**

The homogeneous numerical policy was aligned with
[ProximalBase PR #857](https://github.com/mlakolar/ProximalBase.jl/pull/857).
Failure atomicity was retained. The accepted loss-scale types narrowed when loss
values and gradients moved to ProximalBase's least-squares oracles (#307).

Before that narrowing, a `BigFloat`, `BigInt` or `Rational{BigInt}` scale made CD's
scalar arithmetic `BigFloat`; an `Int`, `Rational{Int}`, `Irrational`, `Bool` or
`Float16` scale was used there as `T(s)`. These historical cases do not expand the
current scale contract in [IN-02](@ref).

CD coordinate steps and stopping arithmetic stayed as before where the loss scale
promotes to `T`. For a wider accepted loss scale, they use the supplied scale
(#295). The loss part of the reported objective is now ProximalBase's reduction,
which differs from the former reduction in `T` (#307). Exceptional oracle recovery
can evaluate values for which the old direct sum of squares overflowed, subject
to the current [range limits](@ref FP-02). CD formerly refused a finished solve
when that sum overflowed; PGD/APG formerly formed the sum in `T` without this
oracle recovery.

**Applies to.** Historical rationale for current input types, scale arithmetic and objective oracles.

**Code.** `src/solve.jl`: scale gate; `src/cd/leastsquares.jl`; `src/solvers/image_models.jl`; the pinned ProximalBase oracles.

**Tests.** Current behavior is covered by the tests cited in [IN-02](@ref), [FP-02](@ref) and [CD-09](@ref); this note preserves the previous behavior without reinstating it.

**Sources.** `docs/src/numerics.md:L743`, `docs/src/numerics.md:L812`, `docs/src/numerics.md:L827`, `docs/src/developer/implementation-notes.md:L179`.

## [HIST-03 Dependency pin and paired-diagnostic provenance](@id HIST-03)

**Statement.**

At the migration baseline, the exact ProximalBase pin is
`7d5d1e006b02814fb28f8cfb5eca20a05d73ee9e`. The private `SparseIterate` contract
is unchanged and PR #237's group/workspace migration is not imported.

ProximalBase's linked `/dev/` documentation follows its evolving `master`, while
ProximalSolvers uses a fixed dependency commit, so details can differ. Consult the
exact pinned source and [installation guide](../getting-started.md) for
compatibility.

The preserved analysis policy runs isolated exact-source paired diagnostics against
ProximalBase A `e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291` and frozen
ProximalSolvers `64930401cfc0451e886728d916263c4dab2baf36`, for CD and PGD only,
including when package tests are not selected or are reused. Loaded paths, clean
Git HEADs and source digests are checked; version strings never skip probes.
C0 and the provenance audit describe the independent full-suite mathematical and
behavioral tests. These identifiers and requirements are provenance for that
analysis; the documentation migration does not change dependency pins or claim
a new diagnostic run.

**Applies to.** Pinned-source and paired-analysis provenance retained from the implementation notes.

**Code.** `Project.toml`, dependency manifests and `.github/workflows`; the paired-analysis harness.

**Tests.** `test/paired_master.jl` and the existing C0/provenance audit; no new run is asserted here.

**Sources.** `docs/src/developer/implementation-notes.md:L456`, `README.md:L111`.

## [HIST-04 CI scope and historical performance records](@id HIST-04)

**Statement.**

The preserved baseline CI scope is stable Julia 1 on Linux x64 for every tier.
Required checks, full master validation, coverage, benchmark-analysis and
conservative policy-aware nightly reuse are to be preserved. Historical platform
runs and the deferred macOS C0 warm-convergence failure remain historical; this
migration does not present them as newly passing checks. The contributor guidance
is the operational home for CI policy.

Historical measured performance tables remain in the
[full-package performance record](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/docs/audit/historical-full-performance.md).
They are not replaced by unmeasured claims about the minimal core. Numerical
audit measurements likewise retain their original populations and environments
in the contract evidence pages.

**Applies to.** Historical CI/platform/performance statements preserved from the migration baseline.

**Code.** Repository CI configuration, contributor guidance, and `docs/audit/historical-full-performance.md`.

**Tests.** Existing CI tier, reuse and provenance tests; no additional platform or benchmark outcome is claimed.

**Sources.** `docs/src/developer/implementation-notes.md:L466`, `docs/src/developer/implementation-notes.md:L471`.
