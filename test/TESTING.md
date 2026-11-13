# Minimal-core test tiers

Quick: Aqua, naming, unchanged required Linux CI/gate contracts, fail-closed
inventory/selection, unchanged C0 independent numerical characterization and
new public refusal contracts and exact-source paired-control policy tests. Standard adds ported scalar cache/scale/helper
regressions, the vector `SparseIterate` coordinate-descent contracts
(`sparse_cd`) and the accelerated proximal gradient contracts (`accelerated_pgd`:
analytic, duality-gap, KKT and finite-support references from the raw data;
momentum, rejected trials, restarts and image caches; refusals, nonfinite trials,
curvature overflow and rollback; trace, callbacks, limits and counters). Full adds every runnable lasso example under `examples/`, which
`test/examples.jl` discovers by itself, the exploratory benchmark script
(`benchmark_explore`) and the formal benchmark harness on the current core
(`benchmark_formal`: case selection and deferral, inputs, certificates, resets,
source checks and records accepted by `benchmark/validate.py`, with no timing
comparison); a PR that edits a harness file runs the latter. Tiers are cumulative;
Pkg.test defaults full. Every regular file is listed once, missing/duplicate/
unlisted tests and empty selections fail; unknown source defaults full.

The separately approved Linux-only matrix and required gate graph remain
unchanged: stable Julia1 Linux x64 for every tier, full master checks, coverage,
required jobs/merge gate, benchmark analysis and provenance-aware nightly reuse.
No automatic macOS/Windows result is implied. Historical full-suite/platform
measurements and deferred macOS C0 failure run42949840807 are preserved in
[the historical record](../docs/audit/historical-full-testing.md). See
[complete test provenance](../docs/audit/minimal-core-test-provenance.md).

The existing always-run Benchmark analysis controls job runs as three parallel
legs (`comparator`, `campaign` and `controls`). The `controls` leg also executes small
exact-source A/B diagnostics using fresh isolated processes on every invocation.
The job is independent of the main tier and nightly test reuse, and retains the Python
benchmark controls. The normal package suite uses the exact current PB pin. Run
`julia --startup-file=no --project=@stdlib scripts/paired_master_diagnostics.jl`
for the paired control; it needs Git/network access and ordinary Julia package
resolution. Its signed-support reference and wider-precision objective/KKT checks
are independent of PB proximal operators and PS stopping/caches. The full suite
continues to exercise the broader unchanged C0 oracle and behavioral fixtures.
