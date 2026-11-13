# Developing the minimal dense core

Keep PB's committed exact source pin fixed outside a reviewed integration PR. The supported surface is dense
Float32/Float64 LS+unweighted L1; unsupported features need separate reviewed
restoration PRs. No version bump or release follows from the reduction.

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia scripts/test.jl --tier=quick --jobs=2
julia scripts/test.jl --tier=full --jobs=2
python3 scripts/check_naming.py
python3 benchmark/check_analysis.py
python3 -I benchmark/sparse_cd/check_analysis.py
python3 -B benchmark/external/coordinatedescent/check_analysis.py
python3 -B benchmark/campaigns/stage2b/test_migration_compare.py
python3 -B benchmark/campaigns/stage2b/test_stage2b_files.py
python3 -B benchmark/campaigns/stage2b/test_stage2b_campaign.py
python3 -B benchmark/campaigns/stage2b/probes/test_check_reset_probes.py
julia --project=docs -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

The four Stage 2B suites also run in the `Benchmark analysis controls` job, which is required through `PR required jobs`: the comparator and campaign suites each in a leg of their own, the other two in the `controls` leg. Run
`test_stage2b_campaign.py` in a full-history clone: its fingerprint tests read two pinned commits and fail
without them, and CI also fails on any skipped test.

Every pull request builds and checks the documentation on Linux Julia 1 with a
read-only token. Download the rendered HTML from the
`documentation-linux-current-julia` Actions artifact. For same-repository,
non-draft PRs, a separate publisher places the validated pages at
`https://mlakolar.github.io/ProximalSolvers.jl/previews/PR<NUMBER>/`. The URL
appears in the `Publish PR documentation preview` job summary after publishing.
Fork PRs and draft PRs build docs but do not publish previews. The privileged
publisher checks out `gh-pages`, never executes PR code, and has no
`DOCUMENTER_KEY`; master and `v*` releases retain their existing protected
deployment path.

Pkg.test defaults to full. Test tiers are cumulative and fail-closed: every
regular test appears exactly once; missing/duplicate/unlisted files and empty
selections fail. Every source has an explicit risk rule; unknown source defaults
full. Changed tests run alongside the chosen tier; labels only raise it. All
13 shared source files currently require full. Generic discovery, runner,
verdict/gate and benchmark-analysis controls remain active.

Separately approved PR #241 selects stable Julia1 Linux x64 only for every tier.
Keep the exact `PR required jobs`, `PR merge gate` and Documentation semantics,
required Linux full validation on master, coverage and policy/provenance-aware
nightly behavior. macOS/Windows jobs are temporarily disabled; minimal Linux
green neither validates those platforms nor proves legacy algorithms still work.
Historical full-suite/platform measurements and the deferred macOS C0 warm
convergence failure remain in docs/audit/historical-full-testing.md.

A separate `Nightly` workflow runs the full suite on Linux with Julia 1.10, scheduled daily. It is
not a required check. On scheduled and manual runs it attempts to open an issue, or comment on the
open one, for a failing leg; pull request runs open none. See "Nightly compatibility runs" in
`test/TESTING.md`. When you change the ProximalBase pin, change `[sources]` in `Project.toml` and
`Manifest-v1.10.toml` together, as the quick test in `test/aqua.jl` requires.

CD preserves private PB SparseIterate storage/compaction, full-active scheduling,
Fisher–Yates/RNG ownership, native residual/lazy curvature, scalar prox_block and
default random momentum/restarts/cache refresh. PGD keeps native LS image math,
TFOCS modes, fused prox, FASTA/x/objective OR stopping, trace/callback/counts and
last-accepted rollback. APG (`AccProxGradDescent`) reuses the LS image model, the
gradient engine, the stopping rules and the result type, with its own k/(k+3)
extrapolation, objective-increase restart and backtracking that accepts a step only
when the LS bound is certified by rounding-error bounds under the assumptions stated
in the implementation notes; its
tests in `test/accelerated_pgd.jl` check accuracy against BigFloat references from
the raw data, never only against CD or PGD. Retain C0 numerical fixtures unchanged. Test correctness
independently using raw objective/KKT and analytic/finite-support references.
The nonfinite-CD-objective refusal is a separate bounded guard, not range recovery.

A native Float32 scaled cyclic regression is known to hit its pass limit despite
an accurate point; preserve the historical warning/status rather than loosen
tolerances or pretend success. Float32 precision and convergence semantics are
separate from independent accuracy checks.

Preserve immutable archive refs and separate legacy/full. Existing PRs
#134/#231/#233/#237 and working-sets remain independent histories. Escalate
unexplained finite trajectory, precision/stopping/storage or performance tradeoffs.
Every CI run executes `julia --startup-file=no --project=@stdlib
scripts/paired_master_diagnostics.jl` in the gated analysis job, even when the
main test tier is none or nightly full tests are reused. It fetches immutable PB
A/B commits and the frozen reduced PS baseline, checks actual loaded paths, clean
Git HEADs and source digests, then compares fresh child-process diagnostics.
Version-only fingerprints or unverified sibling checkouts are insufficient. Old workspace helper scripts
are historical conveniences, not proof a sibling directory is current master.

## Rebuild provenance and repository maintenance

The current `master` is a reviewed minimal solver core; `refactor/minimal-core`
records its reduction, and `compat/minimal-core-pb-master` isolates the
ProximalBase integration. `legacy/full` is a working reference, not a
branch to merge wholesale. The protected
`archive/full-before-reset-2026-11-10` and
`archive/pre-rebuild-2026-11-10` refs preserve the complete
snapshot `9be1773e911a44ec21d49df28cb01fea37c4316e`.
Restore capabilities selectively with focused numerical checks.

The ProximalBase source pin for this development branch is
`c123d56ba1948e36a8fdbf183a9eea396a16e0d5`;
the isolated historical comparison baseline is
`e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291`.
Every relevant CI run performs exact-source independent probes in
isolated environments, including documentation-only runs. The
[PB integration record](docs/audit/minimal-core-pb-integration.md),
[test provenance](docs/audit/minimal-core-test-provenance.md) and
[reduction evidence](docs/audit/minimal-core-reduction.md) record
the reconstruction and coverage.

Current rebuild CI uses stable Julia on Linux x64; macOS/Windows
automatic jobs are temporarily disabled under separately approved
PR #241. Their absence is not validation on those platforms.
Historical measurements and the deferred macOS C0 warm-convergence
case remain in the repository audits. No public release or
registry version decision follows automatically from the rebuild.
Existing release tags and preserved PR branches remain separate.
