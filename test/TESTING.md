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
No required check runs on macOS or Windows. macOS ARM and Windows run the full suite nightly, on
Julia `1`, in `Nightly.yml` (below); those runs are not required checks, and the macOS leg is where
the deferred macOS C0 case (run42949840807) is checked again. Historical full-suite/platform
measurements and that deferred failure are preserved in
[the historical record](../docs/audit/historical-full-testing.md). See
[complete test provenance](../docs/audit/minimal-core-test-provenance.md).

**Nightly compatibility runs.** `.github/workflows/Nightly.yml` runs the full suite
(`scripts/test.jl --tier=full`), scheduled daily, as four legs that run concurrently, each its own
job: Linux with Julia 1.10, which resolves from `Manifest-v1.10.toml`, and Julia `1` on Linux, on
macOS ARM (`aarch64`) and on Windows, which resolve from `Project.toml` with ProximalBase taken from
`[sources]`. The matrix lists one `include` entry per leg, with 4 test workers (3 on macOS). It is
not a required check and does not change the required Linux Julia 1 jobs of `CI.yml`. It has no skip
or reuse logic: a test job does not read the runs of `CI.yml`, of earlier nights or of another leg,
so a success on one leg cannot suppress the run of another, and each leg has its own record and issue
title. A pull request that edits `Nightly.yml`, `Manifest-v1.10.toml` or `Project.toml` also starts
the four legs, as an advisory result that opens no issue. On scheduled and manual runs the report
job attempts an issue titled `Nightly
failing: Julia <version> - <os>` (the branch name in parentheses when the ref is not `master`), or a
comment on the open issue with that title, for each listed leg that did not succeed; a "Green again"
comment on the open issue of a listed leg that succeeded; and a fallback issue when the leg list
cannot be read or shows no failing leg although the test job did not succeed (the exact conditions
are in `Nightly.yml`). A failed write turns the report job red. Issues are closed by hand. Each leg
attempts to leave a record with its step outcomes and, when the test log contains them, the
recognised final test table and, for a test step that did not succeed, a bounded excerpt of the
failure lines; runner loss can leave no record. Rerun with
`gh workflow run Nightly.yml --ref master`, or locally with
`julia +<version> scripts/test.jl --tier=full` with the leg's Julia version (`1.10` or `1`). GitHub
can delay scheduled runs, and in a public
repository disables them after 60 days without repository activity. Julia 1.11 and later take
ProximalBase from `[sources]` in `Project.toml` and Julia 1.10 ignores it, so the quick test in
`test/aqua.jl` (`pin_problems`) compares the two: `[sources].ProximalBase` must have exactly `url`
and a 40-character lowercase `rev`, and `Manifest-v1.10.toml` must have one ProximalBase entry whose
`repo-url` and `repo-rev` equal the `[sources]` `url` and `rev` and whose `uuid` equals the
ProximalBase UUID in `[deps]`, with a `git-tree-sha1` and no `path` or `repo-subdir`. When
`[sources]` or its ProximalBase entry is removed, or a key other than `url` and `rev` is added
inside that entry, that test fails until `pin_problems` and its cases are changed to the new policy
(`PIN_POLICY` only labels it).

**Native code.** A test in `test/tier_selection.jl` (quick tier; a change to `src/` plans the full
tier, which includes it) scans every line of the `.jl` files under `src/` (and `ext/`, if it exists)
for text that names a native call or module: `ccall`, `@ccall`, `cglobal`, `llvmcall`;
`LinearAlgebra.LAPACK`, `LinearAlgebra.BLAS` and `Base.Libc`, whatever follows the name; an unqualified
word `LAPACK`, `BLAS` or `Libc`, unless whitespace and then a letter or underscore follow it (so that
"BLAS kernel" in prose does not match); a `:LAPACK`-style symbol; `Libdl`; and a `using` or `import`
statement (`import ... as` included) that names one of these modules, also when it continues on lines
after a trailing `,` or `:`. Comments and strings are scanned too, so a match in a comment or a string
counts (reword it or register the file). `src/` has no match today. The test reads source text only:
an unqualified module name followed by whitespace and an identifier (the macro argument in `@m BLAS x`),
names built at run time (`eval(Symbol(...))`, `getfield` with a computed symbol) and the expansion of
external macros are outside it, and generic calls such as `mul!` or `dot`, which reach BLAS, are not matched; the
nightly legs run them on macOS and Windows. A file with a match fails the test unless a `[[native]]`
entry in `.github/tier-rules.toml` lists it. An entry has the keys `why`, `paths`, `checks`,
`platforms` and `enforcement`: its paths must exist and have a match, its checks must be tests of the
tier lists, its platforms are `macos-latest` and `windows-latest`, and its `enforcement` must name a
mechanism in `IMPLEMENTED_NATIVE_ENFORCEMENT` in `test/tier_selection.jl`. That list is empty,
because `CI.yml` has no macOS or Windows job, so every entry fails the test until a pull request
implements such a mechanism (the pre-merge platform job in the plan and verdict of `CI.yml`, running
the entry's checks on the entry's platforms) and names it there; that pull request also has to
change the assertion in `test/ci_gate.jl` that `CI.yml` has no macOS or Windows job. In short, a
file whose text matches the guard needs a registration, and a registration needs an implemented
enforcement mechanism.

The existing Benchmark analysis controls job has no tier or test-reuse condition, so it is
independent of the main tier and nightly test reuse. It runs as three separate matrix
legs (`comparator`, `campaign` and `controls`) that GitHub can run concurrently. The `controls`
leg also executes small exact-source A/B diagnostics using fresh isolated processes, after its
earlier steps succeed, and the job retains the Python benchmark controls. The normal package suite uses the exact current PB pin. Run
`julia --startup-file=no --project=@stdlib scripts/paired_master_diagnostics.jl`
for the paired control; it needs Git/network access and ordinary Julia package
resolution. Its signed-support reference and wider-precision objective/KKT checks
are independent of PB proximal operators and PS stopping/caches. The full suite
continues to exercise the broader unchanged C0 oracle and behavioral fixtures.
