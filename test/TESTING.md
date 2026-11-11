# Test suite: inventory, runner and measurements

This file records what `Pkg.test()` runs, how the files are isolated from each other, which
tier each file belongs to and why, and the measurements behind the tiers and CI's worker counts
(#121). [CONTRIBUTING.md](../CONTRIBUTING.md) has the commands.

**Current rebuild CI policy (2026-11-10):** every automated event and tier runs
Julia `1` (current stable) on Ubuntu x64 only, with four workers. Full retains
coverage; automatic macOS, Windows and LTS runs are deferred. Historical platform
and Julia 1.10 measurements and scenario records remain below as historical evidence.

Deferred cross-platform follow-up: [C0 run 42949840807](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/42949840807)
passed on Linux and Windows, while macOS failed the `warm.converged` assertion in
`test/minimal_core_characterization.jl:113`. That assertion and the solver code are
unchanged by this CI policy change. The macOS result remains unresolved and deferred;
Linux-only validation does not establish that it is fixed or identify an algorithm defect.

## Inventory

- **54 regular test files** in `test/`, each listed once in `test/tiers.toml` under the lowest
  of the cumulative tiers quick, standard and full (see Tiers). Each is a module of its own
  (`module CDTests … end`). `Pkg.test()` runs all of them. An unclassified, missing or
  duplicated file, or a file filter that matches nothing, stops the run before any test starts.
  Until the tiers there were 48; the tiers moved representative testsets of four files into
  four `*_basics.jl` files and added `tier_selection.jl`, and the risk-based CI added
  `ci_gate.jl` (see Risk-based CI).
- **Helpers:** `symmetric_penalty_helpers.jl`, included by `symmetric_penalties.jl`,
  `symmetric_penalties_basics.jl` and `symmetric_penalty_combinations.jl`; `tiers.jl`, the tier
  selection and CI rules used by `runtests.jl`, `tier_selection.jl` and `scripts/ci_plan.jl`.
  Neither runs on its own.
- **Separate environment:** `test/oracles/` (Hypatia, JuMP, HiGHS; see its README) compares
  QUIC, square-root and primal–dual solutions with independent conic/LP/QP solvers. It is run by
  hand or on a cluster and is **not** part of `Pkg.test()`, before or after this change.
- `examples.jl` runs every script in `examples/`; `aqua.jl` runs Aqua; `naming.jl` checks the
  option names. CI's `scripts/check_naming.py` (in the plan job) and the benchmark-analysis job
  are separate and run on every CI run.

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

**Historical chosen worker counts:** 4 on Ubuntu (both Julia versions) and Windows, 3 on macOS. They gave
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
| `tier_selection` | the tier manifest: every file classified once, tiers cumulative, problems rejected; the CI risk rules, labels and the nightly plan |
| `ci_gate` | the CI verdict and merge gate on job states: failed, cancelled, skipped, missing and re-run jobs, stale labels, API errors |
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

- **Assertions:** at #174, full counted 115871 on Julia 1.13 and 115860 on Julia 1.10 (the
  risk-based CI adds its own tests; see below): the 115834 and
  115823 of the 48 files before (115830 and 115819, plus the 4 that #173 split out of
  `product_space`), plus the 37 of the new `tier_selection.jl`. Each split file and
  its `*_basics.jl` file add up to the original count (849, 1639, 1947, 183); the other 44 files
  are unchanged.
- **Coverage:** full with coverage covers the same 6010 of 6142 instrumented lines of `src`,
  line for line, as the sequential runner at `1f62540` (M3 Pro, Julia 1.13.3).
- **`Pkg.test()`** without arguments runs full. Until the risk-based CI (below), CI ran full on
  every job.

### Measurements

GitHub-hosted Ubuntu runners, 4 workers, scratch branch `ci/test-tiers-measure` (this change
at an earlier commit with 33 `tier_selection` assertions, and with #173 merged so that the
no-coverage runs do not hit the two CPU-dependent checks; the full counts there were 115867 and
115856, 4 fewer than now). Three rounds:
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

## Risk-based CI

`.github/workflows/CI.yml` chooses a tier per run (`scripts/ci_plan.jl`, rules in
`.github/tier-rules.toml`, read by `test/tiers.jl`); `CONTRIBUTING.md` describes the workflow
for contributors. Adapted from ProximalBase.jl #430, with three tiers and the differences below.

| Event | Tier | Jobs | Coverage |
|---|---|---|---|
| pull request | quick, standard or full by the changed paths, raised by `test:standard` / `test:full`; none when every path needs no package tests (documentation, benchmarks) | Julia 1 Ubuntu x64 | full only, Julia 1 Ubuntu |
| push to master, tag | full, always | Julia 1 Ubuntu x64 | Julia 1 Ubuntu |
| nightly (06:17 UTC) | full, or none after a verified full run (below) | Julia 1 Ubuntu x64 | Julia 1 Ubuntu |
| manual | the chosen tier, full by default | as for a pull request | full only |

The plan, the naming check (`scripts/check_naming.py`, moved from the test jobs to the plan job,
so it runs once per run, also for documentation) and the benchmark analysis controls run on
every run. Every test tier uses four workers on Ubuntu x64; full changes test scope and
coverage, without expanding the platform matrix. macOS, Windows and LTS are deferred
during the rebuild. The timing measurements above describe the historical matrix.

### Rules

Each changed path takes the first rule that matches it; the PR gets the highest tier:

- **none:** documentation (`docs/**`, `**/*.md`, `LICENSE`, `.gitignore`, `codecov.yml`), the
  benchmarks (their analysis controls run anyway), `test/oracles/**`, the naming script, the
  scripts for development sources, and the Documentation, TagBot and CompatHelper workflows and
  Dependabot's configuration.
- **full:** the runner and CI (`CI.yml`, `tier-rules.toml`, the four `scripts/ci_*.jl`,
  `scripts/test.jl`, `scripts/test_report.jl`, `test/runtests.jl`, `test/tiers.jl`),
  `Project.toml`, `test/tiers.toml` (unless the edit only adds files new in the PR); shared
  solver architecture (`ProximalSolvers.jl`, `types.jl`, `solve.jl`, `blocks.jl`,
  `line_searches.jl`, `workspaces.jl`, `precompile.jl`, `cd/models.jl`, `cd/solver.jl`);
  convergence and certification semantics (`utils.jl`, with the stopping tests,
  `cd/gap.jl`, `cd/sqrtdual.jl`, `cd/path.jl`, `solvers/primal_dual.jl` with the public
  primal-dual `duality_gap`, `cd/glm.jl` with ProxNewton's certificate guard); native code
  (`cd/groupcurvature.jl`, which calls LAPACK's `syevr` through `ccall`); and every path no
  rule names, including a new source file (which `tier_selection` then rejects until a rule
  names it) and any file under `test/` that is not Julia code (the test environment, data).
- **quick:** a test file (it runs beside the tier), the shared symmetric-penalty helpers (with
  the three files that include them, checked by a test) and `examples/**` (with `examples`).
- **standard:** every other source file, each named in a rule, with its focus files.

Standard runs every file but the four full-only ones, so the focus files of a solver rule are
chosen among those four: a full-only file is a focus file of a source file when it covers lines
there that standard does not, or at least a quarter of the lines standard covers there. Per-file
coverage of `src` (Julia 1.13.3, M3 Pro, `src` as in master at `ba11f52`): lines standard covers, and for
each full-only file the lines it covers (with those standard does not, after the slash) and
their share of standard's.

| Source file | Standard | `examples` | `float32_certificates` | `mixed_precision_extended` | `symmetric_penalty_combinations` |
|---|---:|---:|---:|---:|---:|
| `solvers/proximal_gradient_descent` | 80 | 42 / 0, 52% | 0 | 66 / 0, 82% | 42 / 0, 52% |
| `solvers/accelerated_proximal_gradient_descent` | 70 | 64 / 0, 91% | 0 | 67 / 0, 96% | 60 / 0, 86% |
| `solvers/active_accelerated_proximal_gradient_descent` | 129 | 114 / 0, 88% | 0 | 95 / 0, 74% | 0 |
| `solvers/monotone_accelerated_proximal_gradient_descent` | 89 | 0 | 0 | 0 | 81 / 0, 91% |
| `solvers/image_models` | 72 | 30 / 0, 42% | 0 | 33 / 0, 46% | 5 / 0, 7% |
| `solvers/diagonal_metric` | 127 | 14 / 0, 11% | 0 | 14 / 0, 11% | 14 / 0, 11% |
| `solvers/admm` | 102 | 69 / 0, 68% | 0 | 0 | 0 |
| `solvers/primal_dual` | 175 | 144 / 0, 82% | 0 | 0 | 0 |
| `solvers/slope` | 130 | 0 | 0 | 83 / 0, 64% | 0 |
| `solvers/slope_hybrid` | 270 | 0 | 0 | 218 / 0, 81% | 0 |
| `cd/drivers` | 96 | 70 / 0, 73% | 0 | 31 / 0, 32% | 0 |
| `cd/leastsquares` | 358 | 178 / 0, 50% | 305 / **6**, 84% | 38 / 0, 11% | 0 |
| `cd/glm` | 458 | 189 / 0, 41% | 299 / 0, 65% | 0 | 6 / 0, 1% |
| `cd/groupcurvature` | 52 | 29 / 0, 56% | 29 / 0, 56% | 2 / 0, 4% | 0 |
| `cd/groups` | 50 | 0 | 25 / 0, 50% | 0 | 0 |
| `cd/sparsegroup` | 95 | 0 | 72 / 0, 76% | 0 | 0 |
| `cd/kron` | 135 | 77 / 0, 57% | 0 | 0 | 51 / 0, 38% |
| `cd/kronu` | 75 | 0 | 0 | 0 | 34 / 0, 45% |
| `cd/quic` | 166 | 0 | 0 | 0 | 161 / 0, 97% |
| `cd/lla` | 102 | 82 / 0, 80% | 0 | 0 | 0 |
| `cd/sqrtlasso` | 286 | 132 / 0, 46% | 0 | 0 | 0 |
| `cd/sqrtquadratic` | 202 | 134 / 0, 66% | 0 | 0 | 0 |
| `cd/generic_newton`, `cd/multiresponse`, `cd/quadratic`, `cd/refit_cache` | 117, 124, 137, 116 | 0 | 0 | 0 | 0 |

`solvers/primal_dual`, `cd/glm` and `cd/groupcurvature` became full in the reviews (below); their rows show what
the focus files would be. Of the files that are full anyway, `float32_certificates` alone covers 76 lines of `cd/gap.jl`
that standard does not. The selection reads coverage, not behavior: a full-only file that runs
the same lines with other types (Float32, mixed precision) is chosen through its share, and a
change whose risk the paths do not show needs a label.

### Differences from ProximalBase

- **Current labels.** The plan takes the labels of the event and the labels the PR has now, so
  Re-run all jobs of an older run uses today's labels. The verdict reads the PR's labels again
  and fails if one asks for more than the run's plan chose. The scenarios below show that GitHub
  already counts, for each required check, the run created last, not the check that finished
  last: re-running an older quick run, passing or failed, left a PR whose labeled full run had
  failed blocked even without this check (controls #188 and #190). The check is defense in depth
  for that undocumented behavior, and it names the cause when it fails.
- **The verdict is a script** (`scripts/ci_verdict.jl`, tested in `test/ci_gate.jl`), and it
  also requires full for a push and full or none for the nightly run.
- **Every push runs full**, also for documentation, as #121 asks for every merge and release.
- **The nightly skip** requires the same dependencies and CI policy. A non-PR full run
  records its Julia version and resolved package versions on Ubuntu, and a separate digest of
  `CI.yml` plus the planner, verdict, gate and environment scripts. It uploads
  `environment-<julia>-<policy>-<digest>` only after its tests pass. The nightly plan resolves
  the same environment and skips only if a successful non-PR run on the same commit in the
  preceding 24 hours has `CI required jobs` and `Julia 1 - ubuntu-latest - x64 - full`
  successful in its latest attempt, and the exact artifact name. Missing/duplicate/failed
  jobs, an absent record, different Julia/package versions or different CI policy run full.
  A re-run of an old checkout keeps that checkout's policy fingerprint; neither its old-format
  nor its different-policy artifact qualifies for the current policy. Unknown additional
  full test jobs must also have passed. Runner images are not fingerprinted. API errors or
  malformed answers run full.
- No benchmark reference checks, conformance reports or `test:iterate-narrow` label, which
  ProximalSolvers does not have; the gate script is ProximalBase's, unchanged but for its header.

### Historical review (integration with master before the rebuild)

Four independent reviews (tier selection; merge protection and security; the nightly skip;
documentation and evidence) of the integrated head `e568c5a` found no way to get both checks
green without the tests the paths or labels require. Changes made:

- **A new base branch reruns CI** (`edited` in the pull request types). Required checks are keyed
  to the head commit, so a PR retargeted from another branch kept checks computed against that
  branch. A title or body edit now also restarts the run.
- **The verdict** fails on two jobs of one name (they count as `duplicated`, never success) and
  on any failed test job of the planned tier that its list of expected jobs does not name.
- **No checkout keeps the token** in `.git/config` (`persist-credentials: false`), so PR code in
  the test job cannot reuse its token through git (the token is now read-only as well, below).
- **The gate's deadline** is 160 minutes, so its startup retries fit the 180-minute job timeout.
- **The environment record** is taken before the job resolves the dependencies the tests use
  (Pkg.test keeps that manifest), and the extras resolve with the package's `[compat]` bounds,
  as in Pkg.test's sandbox. Before, a dependency released between resolution and the record, or
  an extra with a release outside its compat bounds, could let a nightly run skip although its
  tests would have used other versions. Only push, schedule and manual runs count as evidence.
- **Rules:** `solvers/primal_dual.jl` (the public primal-dual `duality_gap` and CondatVu's gap
  stop) and `cd/glm.jl` (ProxNewton's certificate guard) became full; files under `test/` that
  are not Julia code (the test environment, data) fall through to full instead of quick; a test
  checks the helper rule's focus files against the files that include the helper.
- **Workflow tests** pin the properties the checks rely on: the event types, no
  `paths-ignore` or `pull_request_target`, the record before the resolution, the upload only
  after passing tests, a gate without `needs`, a verdict that always runs.

Not changed: the planner, verdict and gate come from the PR's merge commit, so they are only as
strong as required review of `.github/**` and `scripts/ci_*.jl` (CODEOWNERS or required review
are recommended).

### Maintainer review (#191, review 5761207188)

- **The test job's token is read-only** (`actions: read`, `contents: read`). It had
  `actions: write` only so that `julia-actions/cache` could delete older caches, and it runs the
  PR's code. The cache action now has `delete-old-caches: false`; restoring and saving go
  through the runner's cache service and need no token scope, and GitHub evicts caches unused
  for 7 days or beyond the repository's 10 GB. A workflow test fails if any permission of the
  test job is `write` or deletion is turned back on. Checked on GitHub at `0ddcaac` (run
  41746737170): each of the four test jobs reported `Actions: read`, `Contents: read`, restored the
  cache of the previous run and saved its own ("Cache saved successfully").
- **`src/cd/groupcurvature.jl` is full.** It calls LAPACK's `syevr` through `ccall`, and an
  out-of-bounds write there crashed Julia on macOS (#131, fixed in #146); standard's line
  coverage of the file does not test the other platforms. A test pins the rule, also against a
  `test:standard` label.
- **Codecov's comparison changes baseline.** Master's coverage is the union of four uploads (Julia
  1.10 and 1 on Ubuntu, macOS, Windows): 39 files, 6204 of 6374 lines. A full run now uploads
  only the Julia 1 Ubuntu job: 38 files, 6010 of 6142. The difference is the Julia 1.10 job,
  whose coverage also instruments `src/ProximalSolvers.jl` and `src/precompile.jl` (module and
  precompile code that Julia 1.13 does not report), not lost tests: the Julia 1.13 file set and
  covered lines are unchanged, and the coverage parity here compares single Julia 1.13 runs (6010
  of 6142 before and after). The first comparison after the merge, and Codecov's PR comments
  until master has a single-job baseline, therefore show a spurious change of about half a
  percentage point.
- **Documentation is not one of the two checks.** A PR whose `Documentation` workflow fails still
  gets a green `PR required jobs`, unless branch protection also requires `Documentation`. That
  workflow runs on every pull request (no path filter), so it can be a third required check;
  doing so is the maintainer's choice, and is better made after the hardening below.
- **The Documentation workflow runs PR code with write access (existing, not changed here).**
  `.github/workflows/Documentation.yml` runs `docs/make.jl` from the PR with `contents: write`,
  `actions: write` and `statuses: write`, and passes `GITHUB_TOKEN` and `DOCUMENTER_KEY` to that
  step. Fork PRs get a read-only token and no secrets, but a same-repository PR's branch can
  change `docs/make.jl` (which the proposed review rule on `.github/**` does not cover) and use
  them. Proposed follow-up, separate from this PR: build on pull requests with `contents: read`
  only, no `DOCUMENTER_KEY` and no write token (Documenter can build without deploying); deploy
  in a separate job that runs only on pushes to master and tags, with `contents: write` and the
  key, and runs no PR code; keep `persist-credentials: false`; then consider requiring the PR
  build as a third check.

### Scenarios

Checked on GitHub with scratch PRs (#175–#190, closed unmerged) against scratch copies of this
branch, so that each diff held only the scenario's change: `ci/gate-scenarios` (at `8908d5f`)
and, after the review fixes, `ci/gate-scenarios2` (at `f634274`); the controls ran on copies of
the latter with the verdict's label check removed (`ci/gate-scenarios2-nolabelcheck` for #187,
`ci/gate-scenarios3-nolabelcheck`, which also drops the unit tests of that check, for #188 and
#190). A temporary ruleset required `PR merge gate` and `PR required jobs` from GitHub Actions
on those branches only, as branch protection should on master; master's protection was not changed, and the ruleset and branches
were deleted afterwards. A watcher polled each PR's merge state and checks every 3–8 s (UTC).
These first scenarios ran before the final review; the next section repeats those that its
changes touch.

| Scenario | PR (run) | Plan | Outcome | Merge state |
|---|---|---|---|---|
| a test file changed (`test/glm.jl`) | #175 (41637851372) | quick and `glm` | passed, 3.7 min end to end | CLEAN 12:45:15 |
| label `test:standard` added | #175 (41638428519) | standard | label request 12:45:37.5–40.0; new pending gate at the next poll; passed | BLOCKED 12:45:45 to 12:56:36, then CLEAN |
| label `test:full` added | #175 (41640671387) | full, four jobs | passed (22 min, queued behind other scenarios) | BLOCKED until the gate passed |
| documentation only | #176 (41637855636) | none | no test jobs; both checks passed in 0.8 min | mergeable |
| a solver file (`src/cd/quic.jl`) | #177 (41637864018) | standard and `symmetric_penalty_combinations` | passed, 9.2 min | CLEAN |
| certification code (`src/cd/gap.jl`) | #178 (41637872435) | full, four jobs, coverage on Julia 1 Ubuntu only | passed, 10.5 min | CLEAN |
| a test file missing from `tiers.toml` | #179 (41637879340) | the plan failed | no test jobs; both checks failed | BLOCKED |
| a new test file and its `tiers.toml` line | #180 (41638146833) | quick and `scenario_new` | passed, 5.2 min | CLEAN |
| `tiers.toml` moves `workspaces` from quick to standard | #181 (41638154173) | full | `tier_selection` failed: its manifest-edit tests named `workspaces`; they now take their names from the manifest (`f634274`) | BLOCKED |
| a test fails on Julia 1 in attempt 1 | #182 (41640684390, 1) | quick | PR required jobs: "Julia 1 - ubuntu-latest - x64 - quick: failure."; gate failed | BLOCKED |
| Re-run failed jobs | #182 (2) | | request 13:17:28.9–30.4; only Julia 1, the verdict and the gate re-ran | BLOCKED until CLEAN 13:26:01 |
| Re-run job on the passing Julia 1.10 job | #182 (3) | | request 13:26:25.3–26.5; PR required jobs absent until the job finished | BLOCKED 13:26:32 to 13:29:20, then CLEAN |
| Re-run all jobs | #182 (4) | quick (new plan) | request 13:29:31.4–32.8; new pending gate | BLOCKED 13:29:34 to 13:34:36, then CLEAN |
| the run cancelled by hand | #183 (41640697631) | quick | gate cancelled; PR required jobs: "The test jobs are cancelled." | BLOCKED |
| no Windows job (stub workflow) | #184 (41640706119) | full | PR required jobs: "Julia 1 - windows-latest - x64 - full: missing." | BLOCKED |
| the verdict renamed (stub workflow) | #185 (41640714101) | full | gate: "every job finished 92 s ago, but this run has no job `PR required jobs`" | BLOCKED |
| stale checks: quick passes, `test:full` fails on Windows, then Re-run job on the older quick run | #186 (41644465071, 41645823697) | quick, then full | request 13:50:05.6–06.9; the re-run's PR required jobs: "Label `test:full` asks for at least full, but this run's plan chose quick" | BLOCKED throughout |
| the same, control without the verdict's label check | #188 (41645817333, 41646840925) | quick, then full | request 14:09:57.9–14:10:05.8; the re-run's PR required jobs passed (14:23:41) | BLOCKED: GitHub kept the checks of the newer run |
| stale checks: quick fails, `test:full` fails on Windows, then Re-run failed jobs on the older quick run | #189 (41653452805, 41655307633) | quick, then full | request 14:55:26.4–28.0; the re-run's PR required jobs: "Label `test:full` asks for at least full, but this run's plan chose quick"; gate failed | BLOCKED throughout |
| the same, control without the verdict's label check | #190 (41653458810, 41655411867) | quick, then full | the re-run's PR required jobs and gate passed at 14:58:26 and 14:58:33, after the full run's failed checks (14:55:03, 14:55:08) | BLOCKED: GitHub kept the checks of the newer run |
| `test:full` removed after the full run failed | #186 (41659290286) | quick | label request 15:00:05.3–07.9; a new quick run passed | BLOCKED, then CLEAN 15:05:01 |
| manual quick run | 41637469134 | quick | checks named `CI result` and `CI required jobs` | — |
| nightly path: a manual full run, then the scheduled path on the same commit | 41645877388, 41650828067 | full, then none | the full run recorded `environment-1.10-d933144b703c7470` and `environment-1-08074b6a7de2f8f9`; the second plan: "Run 41645877388 passed the full tier on this commit in the last 24 hours, with the same Julia and package versions" | — |

The nightly path ran on `ci/scenario-nightly`, which maps a manual run of tier `nightly` to the
scheduled path (the schedule fires only on master); pushes to master and tags can be observed
only after the merge. The Julia 1 digest of the runners equals the one on an M3 Pro: the record
does not depend on the platform. A first control (#187) failed its quick run: with the label
check removed, `test/ci_gate.jl` fails, so the unit tests guard the check.

The scenarios ran with up to 13 runs at a time, so later runs queued for runners (macOS
especially); the end-to-end times of the first batch (#175–#180, started together) are the
representative ones. From the last test job to the gate's result took 22–48 s in the first
batch, and 93 s once, in the queued full run of #175 (the verdict installs Julia, about 15 s,
and the gate polls every 5 s once the verdict exists).

### Scenarios on the final head

The final review changed the verdict and the workflow, so the scenarios that depend on them ran
again (#192–#202, closed unmerged) against `ci/gate-final` (at `36239b0`) and `ci/gate-final2`
(at `4c09c7c`, the head; it differs from `36239b0` only in `test/ci_gate.jl`), with a temporary
ruleset requiring both checks on those branches only; ruleset and branches were deleted.

| Scenario | PR (run) | Plan | Outcome | Merge state |
|---|---|---|---|---|
| documentation only | #192 (41707757514) | none | both checks passed | CLEAN |
| a test file changed (`test/glm.jl`) | #193 (41707762444) | quick and `glm` | passed | CLEAN |
| label `test:full` added to that green commit | #193 | full | label request 20:10:55.4–57.7 | BLOCKED at 20:10:58.6, 0.9 s after the request returned |
| a solver file (`src/solvers/admm.jl`) | #194 (41707771342) | standard and `examples` | passed | CLEAN |
| certification code (`src/cd/gap.jl`) | #195 (41707779196), #201 (41715523687) | full, four jobs | #195: Windows failed in the new workflow test (CRLF, fixed in `4c09c7c`), BLOCKED; #201 at the head: passed | CLEAN |
| a failing benchmark analysis control | #196 (41707782632) | none | PR required jobs: "Benchmark analysis controls: failure." | BLOCKED |
| a PR retargeted from a docs-only diff to a risky one | #197 (41707790301, 41709921692) | none against `fin/retarget-base`; after `gh pr edit --base ci/gate-final` (20:09:15.6–18.4) a new run (created 20:09:20) planned full | the second run failed on the CRLF test | BLOCKED from the retarget on |
| `tiers.toml` moves `workspaces` from quick to standard | #198 (41710125731), #202 (41715530071) | full: "`workspaces` moves from `quick` to `standard`" | #198 hit the CRLF test; #202 at the head passed, including the manifest-edit tests | CLEAN |
| a test fails on Julia 1 in attempt 1 | #199 (41710134011, 1) | quick | PR required jobs and the gate failed | BLOCKED |
| Re-run job on the failed job | #199 (2) | | request 20:21:40.0–41.4; the job and PR required jobs passed, the gate kept its failure | BLOCKED (20:25:04) |
| then Re-run failed jobs | #199 (3) | | only the gate re-ran: "`PR required jobs` passed (attempt 3)" | CLEAN at 20:26:34 |
| no Windows job (stub workflow) | #200 (41710144245) | full | PR required jobs: "Julia 1 - windows-latest - x64 - full: missing." | BLOCKED |

### Measurements

Manual runs of each tier on the final head `4c09c7c`, three rounds (the three tiers of a round
started together; one quick run of round 3 was started alone), from the run's creation to the
gate's result:

| Tier | Runs | End to end | Median | Test jobs (median) | Gate after the last test job |
|---|---|---|---:|---|---|
| quick | 41718249865, 41721488129, 41728762271 | 4.3, 4.2, 4.5 min | **4.3 min** | Julia 1 2.6, Julia 1.10 3.4 min | 23–31 s |
| standard | 41718288918, 41721510225, 41725898799 | 9.2, 7.4, 9.5 min | **9.2 min** | Julia 1 6.2, Julia 1.10 8.3 min | 25–37 s |
| full | 41718336146, 41721531808, 41725990213 | 19.9, 10.3, 11.5 min | **11.5 min** | Ubuntu 6.4, Julia 1.10 10.7, macOS 7.6, Windows 9.0 min | 26–36 s |

The 19.9 min full run waited 4.0 min for a runner and its macOS job took 15.0 min; the other
runs waited at most 6 s. Other repositories of the account ran CI at the same time, and GitHub
runners differ in CPU (test/TESTING.md, Parallel runs), so single runs vary by up to a factor of
two. Before this change every PR ran full with coverage on four jobs; the same measure for
pull-request runs that did not queue gave 9.7 min (41576419157) and 10.4 min (41556070197), and
15.8 and 20.3 min for two that queued. A test-only PR now finishes in about 4.3 minutes with two
test jobs (about 6 runner minutes instead of about 32), and a localized solver change in about
9 minutes with two; that historical full CI used multiple platforms. Historical targets hold:
quick 4.2–4.5 minutes against 3–5, standard 7.4–9.5 against 6–10, end to end.

**Counts and coverage at `0ddcaac`.** Full runs 54 files and counts **116341** assertions on
Julia 1.13.3 (Ubuntu, macOS aarch64, Windows) and **116330** on Julia 1.10.13 (#191's run
41746737170). That is #174's 115871 and 115860 plus 470 in `ci_gate.jl` and the extended
`tier_selection.jl`; the other 52 files are unchanged. At `4c09c7c`, before the maintainer
review's 4 policy assertions, the counts were 116337 and 116326 (run 41715378305, and locally). Full with coverage covers the same **6010 of 6142** `src` lines,
line for line, as before the tiers (local, Julia 1.13.3). Earlier commits of this PR counted
116333 / 116322 (`8908d5f`) and 116315 / 116304 (`f634274`, `e568c5a`) as the CI tests changed.

### What remains

- **Window of seconds.** Between a label, push or re-run and GitHub creating the run or
  attempt, the earlier checks are still the newest (ProximalBase measured 2–6 s for labels).
- **Removing a label** starts a new run of the path tier, whose checks then count (#186): the
  labels raise the tier of a run, and the paths set the minimum that every PR must pass. The
  full run after the merge still runs everything.
- **Branch protection (maintainer, after the merge).** Master is not protected today. Once
  this workflow is on master and both checks have run there, add a branch ruleset (or classic
  protection) for `master` with **Require status checks to pass**, listing exactly
  `PR required jobs` and `PR merge gate`, each with GitHub Actions as its source
  (integration id 15368), and leave "require branches to be up to date" off. Do not require the
  test jobs: their names end in the tier (`Julia 1 - ubuntu-latest - x64 - quick`) and the
  matrix depends on it, so a required job name would be missing on every PR of another tier,
  and PR required jobs already checks every job the plan asked for. Also require a review, or
  CODEOWNERS, for `.github/**` and `scripts/ci_*.jl`: a PR's own merge commit supplies the
  planner, the verdict and the gate. Then open an ordinary PR with a failing assertion and
  check that GitHub blocks its merge.
- **Pushes and tags** run full and open the issue "CI failing on master" on failure; that path
  and the real schedule can be observed only on master.
