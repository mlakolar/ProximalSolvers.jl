# Test suite: inventory, runner and measurements

This file records what `Pkg.test()` runs, how the files are isolated from each other, which
tier each file belongs to and why, and the measurements behind the tiers and CI's worker counts
(#121). [CONTRIBUTING.md](../CONTRIBUTING.md) has the commands.

## Inventory

- **53 regular test files** in `test/`, each listed once in `test/tiers.toml` under the lowest
  of the cumulative tiers quick, standard and full (see Tiers). Each is a module of its own
  (`module CDTests … end`). `Pkg.test()` runs all of them. An unclassified, missing or
  duplicated file, or a file filter that matches nothing, stops the run before any test starts.
  Until the tiers there were 48; the tiers moved representative testsets of four files into
  four `*_basics.jl` files and added `tier_selection.jl`.
- **Helpers:** `symmetric_penalty_helpers.jl`, included by `symmetric_penalties.jl`,
  `symmetric_penalties_basics.jl` and `symmetric_penalty_combinations.jl`; `tiers.jl`, the tier
  selection used by `runtests.jl` and `tier_selection.jl`. Neither runs on its own.
- **Separate environment:** `test/oracles/` (Hypatia, JuMP, HiGHS; see its README) compares
  QUIC, square-root and primal–dual solutions with independent conic/LP/QP solvers. It is run by
  hand or on a cluster and is **not** part of `Pkg.test()`, before or after this change.
- `examples.jl` runs every script in `examples/`; `aqua.jl` runs Aqua; `naming.jl` checks the
  option names. CI's `scripts/check_naming.py` and the benchmark-analysis job are separate.

## Runner

`test/runtests.jl` hands the files to
[ParallelTestRunner](https://github.com/JuliaTesting/ParallelTestRunner.jl) (a test-only
dependency, compat 2.9). Each file runs in a fresh module on one of `--jobs=N` (or
`PTR_NUM_JOBS`) worker processes. The workers inherit the test process's flags
(`--check-bounds`, `--code-coverage`, `--depwarn`) and project, and run with
`JULIA_NUM_THREADS=1` and `OPENBLAS_NUM_THREADS=1`, so N workers use N cores. This was checked by
printing `Base.JLOptions()`, `Threads.nthreads()` and `BLAS.get_num_threads()` inside a worker,
and on Windows and Linux by the coverage files that workers write. The runner schedules the
longest files first from a duration history in the Julia depot's scratch space
(`julia-actions/cache` keeps that directory by default); without a history the order is random.
Workers whose RSS exceeds a memory-based limit are replaced between files.

A failed assertion, an error and a crashed worker are each attributed to their file; the other
files still run, and the run fails. Run
[41527299635](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41527299635) (a
scratch branch with a failing assertion in `naming.jl` and `ccall(:abort)` in `low_rank.jl`)
shows it on all four CI jobs: `naming` 8 passed / 1 failed, `low_rank` "crashed" with the
abort's source line, the other 46 files passed (115811 assertions), and every job failed. In
the old sequential runner all files shared one process, which a crash ended.

### Bounds checking

`Pkg.test` runs the tests with `--check-bounds=yes` on **Julia 1.10**, but on Julia 1.11 and
later with **the session's setting** (the default, unless Julia was started with
`--check-bounds`). The previous CI command, `Pkg.test(; coverage=true)`, therefore ran the
Julia 1.10 job with bounds checks forced on and the three current-Julia jobs without. This change
keeps that: `scripts/test.jl` leaves the setting to `Pkg.test`, and the test banner names it
(`check-bounds yes` / `default`). `julia --check-bounds=yes scripts/test.jl` forces it on any
Julia.

A first version of this change passed `--check-bounds=yes` on every Julia. That made a check in
`active_set.jl` fail on Intel Xeon runners (see below), and roughly tripled the compile time of
the most expensive files. Forcing bounds checks on current Julia is a separate decision; it needs
the two checks below fixed first.

### Isolation review

Checked for #121 before the change (commit `1f62540`):

- **Random numbers.** The runner calls `Random.seed!(1)` before each file. The old runner
  shared one global stream across all 48 files, so a file's unseeded draws depended on the files
  before it. Files that draw from the global stream either seed it first (`active_set`, `admm`,
  `call_limits`, `group_lasso`, `linesearch`, `low_rank`, `prox_solvers`, and locally in
  `coordinate_descent`, `sparse_group_paths`, `sparse_x`) or use it only for shapes in
  `@test_throws`. `CDSolver`'s default `order = :random` draws from the global stream; its
  results are now reproducible per file rather than per file order.
- **Global state.** The only mutable global in `src` is the test hook
  `ProximalSolvers._group_eig_failure`; `group_curvature.jl` resets it in `finally`.
- **Methods.** Test files extend `Base`, `LinearAlgebra` and `ProximalBase` functions only for
  types they define (no type piracy), inside their own modules.
- **Files and directories.** No test writes files, uses temporary paths or changes directory;
  `examples.jl` reads `examples/` relative to the test file.
- **Timing.** No test checks elapsed time. The `@allocated` checks measure allocations in the
  calling process after a warm-up, which other workers do not affect.

## Baseline: the sequential runner

Pinned at `1f62540` (master, 2026-11-02), run
[41514398527](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41514398527):
ProximalBase 0.5.4, Julia 1.13.3 and 1.10.13, `Pkg.test(; coverage=true)` on every job. Two
more runs of the same code give the spread
([41509492348](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41509492348) at
`5697ac9`, [41506260650](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41506260650)
for #166). Test step (setup, precompilation, tests, coverage):

| Job | 41514398527 | 41509492348 | 41506260650 | Median | Assertions (41514398527) |
|---|---:|---:|---:|---:|---:|
| Julia 1, Ubuntu | 852 s | 592 s | 784 s | 784 s | 115830 |
| Julia 1.10, Ubuntu | 651 s | 912 s | 782 s | 782 s | 115819 |
| Julia 1, macOS (aarch64) | 763 s | 634 s | 701 s | 701 s | 115830 |
| Julia 1, Windows | 847 s | 875 s | 619 s | 847 s | 115830 |

Julia 1.10 counts 11 assertions fewer, by design: `coordinate_descent` (839 vs 849) and
`apg_numerical_failure` (3 vs 4) have version-dependent checks. The costliest files in
41514398527 (Julia 1 / 1.10, Ubuntu, seconds): `coordinate_descent` 156 / 53,
`symmetric_penalty_combinations` 92 / 98, `audit_regressions` 41 / 43, `examples` 41 / 20,
`float32_certificates` 37 / 27, `flat_coordinates` 36 / 32, `symmetric_penalties` 30 / 34.

## Parallel runs

### What the time is

Compilation, not execution, dominates: ParallelTestRunner's `--verbose` column shows 85–100%
compile time for almost every file (Julia 1.13), as in ProximalBase. On an Apple M3 Pro
(Julia 1.13.3, default bounds, no coverage):

- Running a file through the runner costs the same as including it in a fresh process
  (`flat_coordinates` 20.4 vs 20.2 s).
- Files reuse some of what earlier files compiled in the same process:
  `symmetric_penalty_combinations` took 57 s alone, 42 s after `symmetric_penalties`, and 45 s
  at its place in the old sequential order; `flat_coordinates` 20 s alone and 18 s in the
  sequence.
- Forced bounds checks multiply the compile time: with `--check-bounds=yes` the same files took
  183 s and 35 s alone. This is why the Julia 1.10 job, where `Pkg.test` forces bounds checks,
  is now the slowest.

With N workers the summed per-file time grows (locally 305 s with 1 worker, 414 s with 4;
on GitHub's 4-vCPU Ubuntu runners about 610 s with 1 and 1000–1180 s with 4): the workers
compete for cores and each compiles the shared solver code. The wall time therefore falls by
less than the number of workers.

### GitHub-hosted runners

Scratch matrix (branch `ci/parallel-tests-measure`: the CI test step with `PTR_NUM_JOBS`
varied, coverage on as in CI, ProximalBase 0.5.4, ParallelTestRunner 2.10.0, Julia 1.13.3 /
1.10.13). Test step time (setup, precompilation and tests), summed per-file worker time, and
the peak summed RSS of all Julia processes (sampled every 2 s; not available on Windows).

**Julia 1**, bounds left to `Pkg.test` (default), rounds
[41549852193](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41549852193) and
[41552960517](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41552960517):

| Job | Workers | Test step | Worker time | Peak RSS |
|---|---:|---|---|---:|
| Ubuntu | 1 | 657, 668 s | 603, 616 s | 3.2 GB |
| | 2 | 351, 481 s | 647, 890 s | 4.1 GB |
| | 3 | 335, 375 s | 934, 1047 s | 4.6 GB |
| | **4** | **320, 269 s** | 1176, 997 s | 5.3 GB |
| macOS | 1 | 793, 559 s | 737, 524 s | 2.4 GB |
| | 2 | 488, 410 s | 879, 756 s | 2.7 GB |
| | **3** | **389, 363 s** | 1052, 987 s | 3.2 GB |
| Windows | 2 | 432, 517 s | 794, 954 s | |
| | 3 | 480, 516 s | 1326, 1444 s | |
| | **4** | **473, 462 s** | 1733, 1715 s | |

**Julia 1.10** (`Pkg.test` forces bounds checks, before and after this change), the two rounds
above and three earlier ones
([41527237662](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41527237662),
[41530541059](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41530541059),
[41530554871](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41530554871)):

| Workers | Test step | Median | Worker time | Peak RSS |
|---:|---|---:|---|---:|
| 1 | 747, 637, 950, 974, 950 s | 950 s | 587–909 s | 3.8 GB |
| 2 | 624, 610, 434, 605, 363 s | 605 s | 656–1117 s | 4.7 GB |
| 3 | 616, 607, 481, 579, 558 s | 579 s | 1314–1669 s | 5.4 GB |
| **4** | 557, 577, 412, 537, 582 s | **557 s** | 1487–2097 s | 5.9 GB |

The three earlier rounds also ran the Julia 1 jobs, but with bounds checks forced (the first
version of this change); those Julia 1 numbers are superseded. Every job of all five rounds
counted 115830 (Julia 1) or 115819 (Julia 1.10) assertions; all with coverage passed. A 4-worker
Ubuntu job without coverage, run for #121's later coverage decision, failed `product_space.jl`
in two of the five rounds (see below).

**PR #170's CI** at the chosen worker counts, run
[41549696314](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41549696314)
(three attempts), against the sequential baseline above. Test step and whole job, with the
runner's CPU:

| Job | Test step (3 attempts) | Median | Baseline median | Job, median (baseline) |
|---|---|---:|---:|---:|
| Julia 1, Ubuntu, 4 workers | 404 (Xeon 8573C), 416 (Xeon 8370C), 426 s (EPYC 7763) | 416 s | 784 s | 487 s (867 s) |
| Julia 1.10, Ubuntu, 4 workers | 544 (EPYC 7763), 490 (Xeon 8573C), 321 s (EPYC 9V45) | 490 s | 782 s | 579 s (886 s) |
| Julia 1, macOS, 3 workers | 483, 270, 382 s | 382 s | 701 s | 446 s (798 s) |
| Julia 1, Windows, 4 workers | 471, 494, 458 s (EPYC 7763) | 471 s | 847 s | 568 s (927 s) |

All twelve jobs passed with the baseline assertion totals, including the Julia 1 jobs on Intel
Xeon runners.

**The hardware varies as much as the worker count.** Ubuntu and Windows jobs landed on AMD EPYC
7763, 9V45 or 9V74 or Intel Xeon 8370C, 8573C, 6973P-C or 6975P-C runners; the same
configuration can differ by a factor of 1.5–2 between them (Julia 1.10, 2 workers: 363 s on a
9V45, 605 s on a 7763).

**Chosen worker counts:** 4 on Ubuntu (both Julia versions) and Windows, 3 on macOS. They gave
the lowest times on comparable CPUs (Windows: 462–473 s with 4 workers against 480–516 s with 3,
all on EPYC 7763s); the peak memory leaves room on every runner (16 GB on Ubuntu and Windows,
7 GB on macOS). ParallelTestRunner's default would pick 1 worker on macOS, which reports about
3.3 GiB of free memory against an assumed 2 GiB per worker, so CI sets `PTR_NUM_JOBS`
explicitly.

**Balance.** With a duration history, the workers of every multi-worker job finished within
16 s of each other, mostly within 5 s: the jobs are bound by total work, not by one long file.
Without a history (the first round, random order) the spread reached 46%:
`symmetric_penalty_combinations` started late on one worker. Splitting that file, or reducing
its compilation, is left to the tier work of #121.

### Local runs

Apple M3 Pro (12 cores, 18 GB), macOS, no coverage, `Pkg.test()` / `scripts/test.jl` wall time
including setup and precompilation, one run each. Julia 1.13.3 with default bounds, Julia
1.10.12 with bounds checks (as `Pkg.test` runs them on each):

| | Sequential | 1 worker | 2 workers | 3 workers | 4 workers |
|---|---:|---:|---:|---:|---:|
| Julia 1.13.3 | 326 s | 333 s | 190 s | 146 s | 115 s |
| Worker time, Julia 1.13.3 | 322 s | 305 s | 349 s | 397 s | 414 s |
| Julia 1.10.12 | 380 s | 393 s | 229 s | 163 s | 190 s |

The largest process RSS was 1.6 GB for the sequential runner and 0.9–2.0 GB per worker.

## Equivalence with the sequential runner

- **Files:** the same 48 files (the list in `runtests.jl` was compared with the old one).
- **Assertions:** identical totals, and identical counts for every file, in every passing job
  above, the local runs and the PR's CI.
- **Order:** the files ran in random order (no history), in history order, and with 1–4
  workers; the per-file counts did not change.
- **Bounds checks, threads, coverage flags:** as `Pkg.test` sets them, inherited by the workers
  (see Runner).
- **Coverage:** on the M3 Pro (Julia 1.13.3), the sequential runner at `1f62540` and the new
  runner with 4 workers, both with `coverage=true`, covered the same 6010 of 6142 instrumented
  lines of `src` (CoverageTools), line for line. The workers' `.cov` files carry their process
  ids and are merged by CoverageTools, as CI's `julia-processcoverage` does.
- **Numerical checks:** unchanged; no tolerance, seed or test was edited.

### Two checks that depend on the CPU and the compilation mode

Two exact checks pass only in some configurations. Probe run
[41549785906](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41549785906)
(scratch branch `ci/probe-product-space`, 25 Ubuntu and 25 Windows runners, Julia 1.13.3) ran
each file in plain Julia processes (no ParallelTestRunner) with each combination of bounds
checking (default, `yes`) and coverage (none, the package root):

| Check | Fails on | Configurations that fail there |
|---|---|---|
| `active_set.jl:227`: Float32 `res.minimum` within one `eps` of `f(x) + g(x)` | every Intel Xeon runner (8573C, 8370C, 6973P-C, 6975P-C; 7 of 7, Linux and Windows) | every configuration except default bounds with coverage |
| `product_space.jl:61`: bitwise-equal residuals of a vector and a 1-tuple solve | some AMD EPYC 9V45/9V74 runners (1 of 50 here; 2 of 20 in [41536083129](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41536083129); 2 of 5 no-coverage measurement jobs) | no coverage, either bounds setting |

Both fail the same way through ParallelTestRunner. Default bounds with coverage, CI's
configuration on current Julia before and after this change, passed both checks on all 50
runners, and through the runner on all 50 as well. The values are reproducible:
`active_set` misses by two ulps (`1.1920929f-7 <= 5.9604645f-8`), `product_space` in the last
digits of `f_residual` (`8.628673554114886e-13` vs `8.627460980540671e-13`), while the
iterates, minima and call counts agree. On the M3 Pro, two of the `active_set` cases sit
exactly at the one-ulp limit with any BLAS thread count.

Consequences: `Pkg.test()` without coverage on an Intel Xeon fails `active_set.jl`, with or
without this change. Collecting coverage only on a designated job (#121, phase 3) or forcing
bounds checks on current Julia would expose both checks in CI, so they need a fix (a test change,
outside this PR) first.

## Tiers

Three cumulative tiers, **quick ⊂ standard ⊂ full** (`test/tiers.toml`, selected by
`test/tiers.jl`): `--tier=quick` runs the quick files, `--tier=standard` adds the standard
files, and `--tier=full` or no tier, as in `Pkg.test()`, runs every file. `--extra=a,b` adds
files whatever their tier, for the test files a change touches. The targets on GitHub-hosted
runners are 3–5 minutes for a quick job and 6–10 for a standard one. Full keeps every test.

### Why each file sits where it does

**Quick** holds the central solver contracts on representative problems, checked numerically
(solutions against closed forms, KKT conditions, independent oracles or Float64 references, not
only the absence of errors). It is meant to run on every pull request:

| File | Why it is in quick |
|---|---|
| `aqua`, `naming` | package quality (ambiguities, piracy, stale dependencies) and the option names |
| `tier_selection` | the tier manifest: every file classified once, tiers cumulative, problems rejected |
| `prox_solvers` | proximal gradient, accelerated and monotone accelerated solvers: solutions, stopping on the gradient residual, callbacks, `SparseIterate` and Float32 iterates |
| `linesearch` | the backtracking line search: solver reuse, the switch to gradients near convergence, trial points off the cone |
| `call_limits` | the call counts the solvers report and the call limits that stop them (gradient solvers, ADMM) |
| `apg_numerical_failure` | cancellation near a solution must not give a false success |
| `product_space` | tuple (product-space) iterates: a one-block tuple is its array, two problems as one, the fused graphical lasso |
| `admm`, `primal_dual` | ADMM and primal-dual splitting on problems with known solutions |
| `coordinate_descent_basics` | coordinate descent: closed forms, the lasso and its variants against KKT, warm starts, the group lasso, starts from zero (FT26) |
| `group_lasso`, `path_snapshots` | the group lasso against its optimality conditions; independent snapshots of solution paths |
| `duality_gap` | weak duality and a zero gap at solutions, gap stopping in every solver, gap-safe screening, the KKT residual |
| `float32_certificates_basics` | Float32 lasso and group-lasso certificates against a Float64 oracle; the final certificate sets the flag and the reported gap |
| `audit_regressions_basics` | false-success guards: active set, square-root losses, invalid certificates, failed line searches |
| `workspaces` | workspace initialization, reset and reuse for the gradient, coordinate and ADMM solvers, including FT26 |
| `sparse_x` | sparse design matrices take the steps of dense ones (least squares, square-root, logistic, paths, refits, groups, Float32) |
| `symmetric_penalties_basics` | symmetric iterates and penalties on hand-computed and independently checked optima |

**Standard** adds every solver family in depth: `active_set`, `audit_regressions`,
`box_paths`, `convolution_gap`, `coordinate_descent`, `diagonal_preconditioner`,
`flat_coordinates`, `gap_stopping`, `generic_newton`, `glm`, `group_curvature`,
`group_momentum`, `group_penalties`, `image_models`, `lla_paths`, `low_rank`, `mixed_precision`,
`multiresponse`, `newton_nonconvex`, `nonconvex`, `nonconvex_blocks`, `nonconvex_penalties`,
`quic`, `refit_cache`, `slope`, `slope_hybrid`, `sparse_group_paths`, `sqrt_certificates`,
`structured_quadratics` and `symmetric_penalties`. Each tests one family (losses, penalties,
iterate types, paths, preconditioning, precision or certificates) beyond its representative
cases, and is what a change to that family should run before merging.

**Full** adds four files that are exhaustive or end to end:

| File | Why it is only in full |
|---|---|
| `symmetric_penalty_combinations` | the exhaustive grid of every symmetric penalty family × wrapper and every strict case × entry point; its representative companion `symmetric_penalties` is in standard and `symmetric_penalties_basics` in quick (the original #121 finding) |
| `float32_certificates` | the remaining Float32 certificate cases: multitask, weighted and grouped, wide and large-response gaps, Newton models |
| `mixed_precision_extended` | the extended mixed-precision grid; `mixed_precision` is in standard |
| `examples` | every script in `examples/`, end to end; the slowest file after the grids |

### Representative cases moved, not copied

Four expensive files gave whole top-level testsets, unchanged, to new `*_basics.jl` files in
quick; their other testsets stay where they were. No assertion was duplicated, removed or
edited; helpers the moved testsets use were copied:

| From | To | Testsets moved | Assertions moved | Left in the source |
|---|---|---|---:|---:|
| `coordinate_descent` (standard) | `coordinate_descent_basics` | closed forms; lasso and its variants; warm starts from nonzero iterates; group lasso; start from zero clears the working set (#164) | 121 | 728 of 849 |
| `float32_certificates` (full) | `float32_certificates_basics` | Float32 lasso and group-lasso certificates; Float32 stagnation and a reachable tight target; final Float32 certificates control the flag and reported gap | 692 | 947 of 1639 |
| `symmetric_penalties` (standard) | `symmetric_penalties_basics` | asymmetric L1 reproduction; independent optimality from the supplied weights; hand computed optima; linear constraints require symmetric parameters | 108 | 1839 of 1947 |
| `audit_regressions` (standard) | `audit_regressions_basics` | active-set success needs a full residual; square-root losses converge only with a duality gap; invalid certificates cannot pass stopping; line-search failure preserves the accepted point | 35 | 148 of 183 |

The source files keep a comment that points to the moved cases. Moving top-level testsets does
not change the random numbers any testset draws: each file starts from `Random.seed!(1)` (the
runner), and every `@testset` reseeds the global generator from that seed before its body and
restores the state after it (Julia 1.10 and 1.13), so a testset draws the same stream whatever
ran before it in the file. The moved cases also draw their data from their own seeded
generators; only the random coordinate order of `CDSolver()` uses the global stream. As a
check, each of the eight files gave the same assertion count and passed when started from
`Random.seed!(s)` for s = 1, …, 5 (Julia 1.13.3, M3 Pro).

### Equivalence

- **Assertions:** full counts 115867 on Julia 1.13 and 115856 on Julia 1.10: the 115830 and
  115819 of the 48 files before, plus the 37 of the new `tier_selection.jl`. Each split file and
  its `*_basics.jl` file add up to the original count (849, 1639, 1947, 183); the other 44 files
  are unchanged.
- **Coverage:** full with coverage covers the same 6010 of 6142 instrumented lines of `src`,
  line for line, as the sequential runner at `1f62540` (M3 Pro, Julia 1.13.3).
- **`Pkg.test()`** without arguments runs full; CI still runs full on every job (the tier
  selection of pull requests is #121's phase 3).

### Measurements

GitHub-hosted Ubuntu runners, 4 workers, scratch branch `ci/test-tiers-measure` (this change
at an earlier commit with 33 `tier_selection` assertions, and with #173 merged so that the
no-coverage runs do not hit the two CPU-dependent checks; #173 adds 4 assertions, so the full
counts there were also 115867 and 115856). Three rounds:
[41571032834](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41571032834),
[41572016738](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41572016738),
[41573095244](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41573095244). Whole job
(checkout, Julia, cache, test environment, precompilation, tests), with the runner's CPU:

| Tier, coverage | Julia 1 (default bounds) | Median | Julia 1.10 (bounds checks) | Median |
|---|---|---:|---|---:|
| quick, none | 162 (Xeon 8370C), 184 (EPYC 7763), 109 s (EPYC 9V74) | **2.7 min** | 256 (7763), 219 (7763), 225 s (Xeon 8573C) | **3.8 min** |
| standard, none | 401 (7763), 235 (9V45), 368 s (7763) | **6.1 min** | 513 (7763), 384 (9V74), 305 s (9V45) | **6.4 min** |
| full, none | 501 (7763), 449 (7763), 470 s (7763) | 7.8 min | 485 (9V45), 635 (7763), 633 s (7763) | 10.6 min |
| full, coverage | 557 (7763), 305 (9V45), 483 s (7763) | 8.1 min | 483 (9V74), 635 (7763), 483 s (8573C) | 8.1 min |

Worker time (summed over files) on EPYC 7763 runners: quick 370 s (Julia 1) and 399–411 s
(Julia 1.10), standard 1189–1230 s and 1393 s, full 1564–1676 s and 1903–2006 s. Quick is
about a quarter of full's work and standard about three quarters. About 1.5–2 minutes of each
job is setup and precompilation, the same for every tier, so quick saves less wall time than
work. Both targets hold: quick 2.7 / 3.8 minutes against 3–5, standard 6.1 / 6.4 against 6–10.
The CPU of the runner still moves a job by up to a factor of two.

Locally (M3 Pro, 4 workers, no coverage), quick, standard and full took 39, 109 and 155 s on
Julia 1.13.3 and 52, 105 and 137 s on Julia 1.10.12, including setup.
