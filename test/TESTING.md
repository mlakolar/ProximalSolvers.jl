# Test suite: inventory, runner and measurements

This file records what `Pkg.test()` runs, how the files are isolated from each other, and the
measurements behind CI's worker counts (#121). [CONTRIBUTING.md](../CONTRIBUTING.md) has the
commands.

## Inventory

- **48 regular test files** in `test/`, listed in `test/runtests.jl`. Each is a module of its
  own (`module CDTests … end`). `Pkg.test()` runs all of them; an unlisted file or a listed
  file that is missing stops the run before any test starts.
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
(`--check-bounds=yes`, `--code-coverage`, `--depwarn`) and project, and run with
`JULIA_NUM_THREADS=1` and `OPENBLAS_NUM_THREADS=1`, so N workers use N cores (checked on
Julia 1.13 by printing `Base.JLOptions()`, `Threads.nthreads()` and `BLAS.get_num_threads()`
inside a worker). The runner schedules the longest files first from a duration history kept in
the Julia depot's scratch space; CI caches that directory, and without a history the order is
random. Workers whose RSS exceeds a memory-based limit are replaced between files.

A failed assertion, an error and a crashed worker are each attributed to their file; the other
files still run, and the run fails. Run
[41527299635](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41527299635) (a
scratch branch with a failing assertion in `naming.jl` and `ccall(:abort)` in `low_rank.jl`)
shows it on all four CI jobs: `naming` 8 passed / 1 failed, `low_rank` "crashed" with the
abort's source line, the other 46 files passed (115811 assertions), and every job failed. In
the old sequential runner all files shared one process, which a crash ended.

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
compile time for almost every file (Julia 1.13), as in ProximalBase. Within one process, files
reuse what earlier files compiled. On an Apple M3 Pro (Julia 1.13.3, no coverage),
`symmetric_penalty_combinations` took 183 s alone in a fresh process, 131 s after
`symmetric_penalties`, and 45 s at its place in the old sequential order;
`flat_coordinates` took 35 s alone against 18 s in the sequence. Running a single file through
the runner costs the same as including it in a fresh process (35.3 vs 35.5 s), so the
runner itself adds little; the extra work comes from the workers each compiling the shared
solver code. The summed per-file time therefore grows with the number of workers (below),
and the wall time falls much less than the worker count rises.

### GitHub-hosted runners

Three rounds of a scratch matrix (branch `ci/parallel-tests-measure`, the CI test step with
`PTR_NUM_JOBS` varied, coverage on as in CI, Julia 1.13.3 / 1.10.13, ProximalBase 0.5.4,
ParallelTestRunner 2.10.0):
runs [41527237662](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41527237662)
(no duration history, random order),
[41530541059](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41530541059) and
[41530554871](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41530554871)
(history from the first). Test step time (setup, precompilation and tests) for each round,
summed per-file worker time, and the peak summed RSS of all Julia processes (sampled every
2 s; not available on Windows):

| Job | Workers | Test step (3 rounds) | Median | Worker time | Peak RSS |
|---|---:|---|---:|---|---:|
| Julia 1, Ubuntu | 1 | 1059, 997, 1053 s | 1053 s | 966, 943, 993 s | 3.3 GB |
| | 2 | 678, 368, 559 s | 559 s | 1182, 687, 1053 s | 3.7 GB |
| | 3 | 616, 437, 562 s | 562 s | 1528, 1232, 1590 s | 4.4 GB |
| | **4** | 616, 349, 342 s | **349 s** | 1778, 1306, 1281 s | 5.3 GB |
| Julia 1.10, Ubuntu | 1 | 747, 637, 950 s | 747 s | 684, 587, 884 s | 3.8 GB |
| | 2 | 624, 610, 434 s | 610 s | 1097, 1117, 785 s | 4.5 GB |
| | 3 | 616, 607, 481 s | 607 s | 1622, 1669, 1314 s | 5.1 GB |
| | **4** | 557, 577, 412 s | **557 s** | 1931, 2089, 1487 s | 5.9 GB |
| Julia 1, macOS | 1 | 1003, 948, 775 s | 948 s | 887, 896, 736 s | 2.5 GB |
| | 2 | 489, 641, 653 s | 641 s | 791, 1189, 1202 s | 3.0 GB |
| | **3** | 503, 421, 363 s | **421 s** | 1147, 1143, 998 s | 3.1 GB |
| Julia 1, Windows | 2 | 759, 481, 650 s | 650 s | 1249, 904, 1229 s | |
| | 3 | 679, 628, 581 s | 628 s | 1662, 1767, 1648 s | |
| | **4** | 393, 619, 623 s | **619 s** | 1337, 2161, 2163 s | |

Every one of these 42 jobs counted 115830 assertions (Julia 1) or 115819 (Julia 1.10), the
baseline totals; all passed. A 4-worker Ubuntu job without coverage (for #121's later coverage
decision) ran 751, 457 and 647 s; one of its three rounds failed a bit-exact check in
`product_space.jl` (see below).

**The hardware varies more than the worker count.** Ubuntu jobs landed on AMD EPYC 7763,
9V45 or 9V74 or Intel Xeon 8370C or 6975P-C runners, with up to twofold differences in the
same configuration (Julia 1, 4 workers: 616 s on a 9V74, 349 and 342 s on 9V45s); Windows
runners vary too (393 s on a 9V45, against 619 and 623 s). The medians
above mix CPUs; the PR's own CI runs add further samples.

**Chosen worker counts:** 4 on Ubuntu (both Julia versions) and Windows, 3 on macOS. They gave
the lowest medians; the peak memory leaves room on every runner (16 GB on Ubuntu and Windows,
7 GB on macOS). ParallelTestRunner's default would pick 1 worker on macOS, which reports about
3.3 GiB of free memory against an assumed 2 GiB per worker, so CI sets `PTR_NUM_JOBS`
explicitly. With CI's medians, the test step drops from 784 to 349 s (Julia 1, Ubuntu), 782 to
557 s (Julia 1.10, Ubuntu), 701 to 421 s (macOS) and 847 to 619 s (Windows); the test job remains
the slowest part of a run.

**Balance.** With a duration history (rounds 2 and 3), the workers of every multi-worker job
finished within 16 s of each other, mostly within 5 s: the jobs are bound by total work, not
by one long file. Without a history (round 1, random order) the spread reached 46%: with 4
workers on Ubuntu, `symmetric_penalty_combinations` (193 s on its worker) started late and its
worker finished at 556 s, the first one at 382 s. Splitting that file, or reducing its
compilation, is left to the tier work of #121.

### Local runs

Apple M3 Pro (12 cores, 18 GB), macOS, no coverage, `Pkg.test()` / `scripts/test.jl` wall time
including setup and precompilation, one run each (the 3-worker Julia 1.13 run overlapped with a
diagnostic run):

| | Sequential | 1 worker | 2 workers | 3 workers | 4 workers |
|---|---:|---:|---:|---:|---:|
| Julia 1.13.3 | 326 s | 529 s | 318 s | 237 s | 226 s |
| Julia 1.10.12 | 380 s | 393 s | 229 s | 163 s | 190 s |
| Worker time, Julia 1.13.3 | 322 s | 500 s | 601 s | 666 s | 657 s |

The largest process RSS was 1.6 GB for the sequential runner and 0.9–1.9 GB per worker. One
worker is slower than the sequential runner even though all files then share one process:
the history order starts with the most expensive files on a cold process.

## Equivalence with the sequential runner

- **Files:** the same 48 files (the list in `runtests.jl` was compared with the old one).
- **Assertions:** identical totals on every passing job above and in the PR's CI.
- **Order:** the files ran in random order (no history), in history order, and with 1–4
  workers; the per-file counts did not change.
- **Bounds checks and threads:** checked inside a worker, see Runner.
- **Coverage:** on the M3 Pro (Julia 1.13.3), the sequential runner at `1f62540` and the new
  runner with 4 workers, both with `coverage=true`, covered the same 6010 of 6142 instrumented
  lines of `src` (CoverageTools), line for line. The workers' `.cov` files carry their process
  ids and are merged by CoverageTools, as CI's `julia-processcoverage` does.
- **Numerical checks:** unchanged; no tolerance, seed or test was edited.

### A bit-exact check that depends on the CPU

`product_space.jl:61` requires the plain-vector solve and the 1-tuple (`SeparableSum`) solve to
return bitwise-equal residuals. Without coverage, on some AMD EPYC 9V45 and 9V74 runners, the
`f_residual` values differ in the last digits (`8.628673554114886e-13` vs
`8.627460980540671e-13`) while the iterates, minimum and call counts agree. This predates the
runner and does not depend on it: probe run
[41536083129](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/41536083129)
(scratch branch `ci/probe-product-space`) ran the file on 20 Ubuntu runners without coverage,
both with a plain `include` in a fresh process and through the runner with one worker. The two
failed together, with the same values, on 2 runners (a 9V45, znver5, and a 9V74, znver4) and
passed together on the other 18, including two other 9V74s. It also failed once in the
4-worker no-coverage measurement job above (a 9V74). It passed in all 42 coverage jobs of the
measurement rounds (ten of them on 9V45 or 9V74 runners) and in the 4 jobs of the failure
demonstration; coverage changes how package code is compiled, which is consistent with this
but was not isolated. CI collects coverage on every job, before and
after this change, so it does not see the failure; turning coverage off on routine jobs (a
#121 goal) would expose it. Fixing the check is a test change outside this PR.
