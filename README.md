# ProximalSolvers.jl #321 implementation evidence (scale-aware PGD/APG initial curvature)

This is the archive of the measurements behind [PR #361](https://github.com/mlakolar/ProximalSolvers.jl/pull/361), which closes [issue #321](https://github.com/mlakolar/ProximalSolvers.jl/issues/321). It is not part of the package; nothing here is built or tested.

- **Change:** PGD and APG start their curvature estimate at `min(1, α‖X‖_F²)`, rounded to `T` and floored at `floatmin(T)`. `X = 0` keeps the start 1. The PR was merged as `16a0bb7baf81f1ec85bdf37831e001d663f1a90b`.
- **Revisions:**
  - first base `bb20b6a36cc040f7f00088919e331dce27cf257b`;
  - heads `f6fd344` … `fe3c763`, `a44c3dd`/`045428f`, then the catch-up merge `6af5afaea12ba681ea4d5b1e45c909714ce711f7`;
  - second base `8cc022222d3c90ef86a24ca0c957b02faaf4fc1f`.
  - ProximalBase is pinned at `a19c59aa723d085d5d7cf5242895bda16eb77214` throughout.
- **Machine:** cluster (Slurm), Intel Xeon Silver 4116 (AVX-512, `skylake-avx512`). Timing jobs had exclusive use of a node, with 1 Julia thread and 1 BLAS thread.
- **Julia:** 1.10.13 and 1.13.3.
- **Scrubbing:** paths, host names and scheduler settings are replaced by placeholders (`<cluster-dir>`, `<node>`, `<julia-root>`, …). Scheduler command lines, job-submission scripts (`timing321.jl` reads its job ID from `JOB_ID` here), and stderr noise from the shell and module system at the top of some outputs are omitted.

## Files

**`scripts/`** (Julia probes run from a ProximalSolvers.jl checkout; `common.jl` holds the shared problem builders):
- `sweep.jl`: compares the start of both solvers with a 256-bit reference `min(1, α‖X‖_F²)` over loss scales, design scales and shapes, in Float32 and Float64.
- `outcomes.jl`: the outcomes of the cases in `test/initial_curvature.jl`, at base or head. Only its base run (`8cc0222`) is archived. The head outcomes are what `test/initial_curvature.jl` asserts in CI, and the round comments on the PR tabulate both.
- `docs_cases.jl`: the numbers quoted in `docs/src/numerics.md`.
- `basecheck.jl`: the new assertions run at the base, where they fail. Its output was overwritten during the run and is not archived; the round 1 comment on the PR records the failures (12 of 12).
- `inflated.jl`: the #308 inflated-start fixture, base `solve!` against head with `L0 = 1`.
- `ridge.jl`: the ElasticNet overflow-start fixtures at base and head.
- `overflow_repro.jl`: PGD's backtracking test at steps whose squared norm overflows, at the base (#364).
- `timing321.jl` (the `timing-smoke-*` outputs are one-cell smoke runs of it): the paired in-process timing. Base, head, an A/A head copy and option A are loaded as separate modules and alternated in one process; the script also measures warmed allocations. `make_opta.py` builds the option A copy (no early exit in PGD).
- `recordcheck.py`: the record-by-record comparison of formal-harness records.

**`results/`:**
- `timing/`: paired timing outputs.
  - `timing-*.out`: round 1, head `34e73c7` against `bb20b6a`.
  - `timing2-*.out`: round 2, head `045428f` source against `bb20b6a`.
  - `timing3-*.out`: round 3, merge `6af5afa` against `8cc0222`.
  - `job-*.out`: the repeat jobs that are not copies of the files above: r2 and m4 for both versions, and r3 for 1.13.3. The round 2 and round 3 files above are the t2 and m3 jobs.
- `sweep/`: sweep outputs at `34e73c7`, `a44c3dd` and `6af5afa`.
- `outcomes/`:
  - `outcomes-base-8cc0222-*`: `outcomes.jl` at the second base.
  - `docs-cases-f6fd344-*`: `docs_cases.jl` at the first docs head.
  - `timing-smoke-*`: one-cell `timing321.jl` smoke runs, with allocations and start costs, at `34e73c7`, `a44c3dd` and `6af5afa`.
- `fixtures/`: `inflated-*`, `ridge-*` and `overflow-base-bb20b6a-1.13.3.out`. The overflow run stops at scale `1e155` with `start from a point where f is finite`: PGD refuses a start whose value overflows. That is the base result the #364 discussion cites, so the rows for `1e155` and `1e160` do not exist.
- `harness/`: the formal benchmark harness (`benchmark/run.jl`, extended suite, gradient group, 3 alternating repetitions), base `bb20b6a` against head `fe3c763`, plus an A/A head-against-head series.
  - `results-<ver>/`: `REPORT.md`, `comparison.csv`, `coverage.json`, the record checks, the validation JSON and one repetition's metadata per side.
  - `tsv-<ver>/`: the metrics, catalog and error TSVs of every repetition. Raw samples are not archived.
- `SHA256SUMS`: checksums of every other file.

The Codex review rounds, round comments and the run report are on the PR.

## `phase0/`: the Phase 0 research of #321

This is the evidence behind the [Phase 0 report](https://github.com/mlakolar/ProximalSolvers.jl/issues/321#issuecomment-6966984106).
- **Base:** `dac9f4b6819d9321117ee3cf3549e9e46a043f01`, with ProximalBase at `a19c59aa`, Julia 1.10.13 and 1.13.3.
- **CPU kind:** where an output records its CPU, it is `skylake-avx512`, the Intel Xeon Silver 4116 where the model is printed. The exception is `workaround-110.out`, which records `broadwell`. `lbstat-110.out`, `controls-table-110.md` and `Manifest-1.13.3.toml` record none. `controls-smoke.out` is a short `controls.jl` run; `smoke.jl` has no archived output.
- **`phase0/scripts/`:** the probe scripts.
  - Problem builders and a 256/1024-bit reference: `problems.jl`, `ref.jl`.
  - Baseline and candidate traces: `r5_trace.jl`, `trace_defs.jl`.
  - Long runs: `r5_long.jl`.
  - Rescaling workarounds: `workaround.jl`.
  - Range sweep: `range_sweep.jl`.
  - Control problems: `controls.jl`.
  - Tiny-α family: `tinyalpha.jl`.
  - Start checks: `l0check.jl`, `lbstat.jl`.
  - The CD control: `cd_control.jl`.
  - Paired timing of the candidate starts: `timing.jl`, `timing_worst.jl`.
  - A smoke test: `smoke.jl`.
- **`phase0/results/`:** their outputs. The suffix `-110` or `-113` gives the Julia version. `controls-table-110.md` tabulates every control row, and `Manifest-1.13.3.toml` is the offline-resolved 1.13 manifest.
