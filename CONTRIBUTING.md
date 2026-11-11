# Developing the minimal dense core

Keep PB's committed extraction pin fixed. The supported surface is dense
Float32/Float64 LS+unweighted L1; unsupported features need separate reviewed
restoration PRs. No version bump or release follows from the reduction.

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia scripts/test.jl --tier=quick --jobs=2
julia scripts/test.jl --tier=full --jobs=2
python3 scripts/check_naming.py
python3 benchmark/check_analysis.py
julia --project=docs -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

Pkg.test defaults to full. Test tiers are cumulative and fail-closed: every
regular test appears exactly once; missing/duplicate/unlisted files and empty
selections fail. Every source has an explicit risk rule; unknown source defaults
full. Changed tests run alongside the chosen tier; labels only raise it. All
12 shared source files currently require full. Generic discovery, runner,
verdict/gate and benchmark-analysis controls remain active.

Separately approved PR #241 selects stable Julia1 Linux x64 only for every tier.
Keep the exact `PR required jobs`, `PR merge gate` and Documentation semantics,
required Linux full validation on master, coverage and policy/provenance-aware
nightly behavior. macOS/Windows jobs are temporarily disabled; minimal Linux
green neither validates those platforms nor proves legacy algorithms still work.
Historical full-suite/platform measurements and the deferred macOS C0 warm
convergence failure remain in docs/audit/historical-full-testing.md.

CD preserves private PB SparseIterate storage/compaction, full-active scheduling,
Fisher–Yates/RNG ownership, native residual/lazy curvature, scalar prox_entry and
default random momentum/restarts/cache refresh. PGD keeps native LS image math,
TFOCS modes, fused prox, FASTA/x/objective OR stopping, trace/callback/counts and
last-accepted rollback. Retain C0 numerical fixtures unchanged. Test correctness
independently using raw objective/KKT and analytic/finite-support references.
The nonfinite-CD-objective refusal is a separate bounded guard, not range recovery.

A native Float32 scaled cyclic regression is known to hit its pass limit despite
an accurate point; preserve the historical warning/status rather than loosen
tolerances or pretend success. Float32 precision and convergence semantics are
separate from independent accuracy checks.

Preserve immutable archive refs and separate legacy/full. Existing PRs
#134/#231/#233/#237 and working-sets remain independent histories. Escalate
unexplained finite trajectory, precision/stopping/storage or performance tradeoffs.
The later PB integration must identify exact current source SHA in isolated A/B
runs and initially run paired diagnostics every time; version-only fingerprints
or unverified sibling checkouts are insufficient. Old workspace helper scripts
are historical conveniences, not proof a sibling directory is current master.
