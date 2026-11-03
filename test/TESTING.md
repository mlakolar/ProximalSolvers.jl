# Test suite: inventory, runner and measurements

This file records what `Pkg.test()` runs, how the files are isolated from each other, and the
measurements behind CI's worker counts (#121). [CONTRIBUTING.md](../CONTRIBUTING.md) has the
commands.

## Inventory

- **48 regular test files** in `test/`, listed in `test/runtests.jl`. Each is a module of its
  own (`module CDTests … end`). `Pkg.test()` runs all of them. An unlisted file, a listed file
  that is missing, or a file filter that matches nothing stops the run before any test starts.
- **Helper:** `symmetric_penalty_helpers.jl`, included by `symmetric_penalties.jl` and
  `symmetric_penalty_combinations.jl`; never run on its own.
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
the most expensive files. Forcing bounds checks on current Julia is a separate decision; the two
checks below, which blocked it, now pass in every mode (#173).

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
in two of the five rounds (see below; made portable in #173).

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

### Two checks that depended on the CPU and the compilation mode

Until #173, two exact checks passed only in some configurations. Probe run
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

So `Pkg.test()` without coverage failed `active_set.jl` on Intel Xeons, with either runner.

**Resolution (#173).** Both compare two evaluations of the same objective at the same point by
differently associated sums: the solver's `value_and_gradient!` and the test's `f(x)` (a pairwise
or a vectorized sum of squares, a sparse or a dense product), or the same component code
compiled into the vector and the 1-tuple solves. Neither value is stale: the reported minimum is
within 0.83 ulp of the Float64 objective at the same point. The checks now allow the standard
worst-case rounding error of the two evaluations, computed from each case's data
(`_objective_error` in both files): 6.6–89.5 ulps for the `active_set` cases (0 when the
minimizer is 0) and `4.8e-14` for `f_residual` (observed: 2 ulps and `1.2e-16`). The
quantities that are identical, such as minimizers, minima, iteration and call counts,
`x_residual` and `g_residual`, are still compared exactly. Probe runs
[41564183662](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41564183662) (42 runners,
original and changed files in each bounds × coverage mode, then the whole suite with `Pkg.test()`
without coverage) and
[41568144831](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41568144831)
(`product_space` on 60 runners) reproduced both failures (all 8 Intel Xeons; 10 AMD EPYC
9V45/9V74 runners) and passed the changed checks, and the whole suite, everywhere.
