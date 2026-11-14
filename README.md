# Evidence for #311: CD active-set starvation and the full-pass work budget

This orphan branch archives the evidence behind the [#311 decision memo](https://github.com/mlakolar/ProximalSolvers.jl/issues/311#issuecomment-6873427618) and its implementation, PR #313. It is pinned by commit SHA and is never merged into `master`.

## Layout

- `research/memo.md`: the decision memo as corrected on #311. The work-bound statement was corrected and the cluster details generalized.
- `research/probes/`: the Julia and Python probes.
  - `repro311.jl`, `diag311.jl`, `fixture311.jl`: the §18 Float32 fixture, its trace, and the BigFloat-256 step and curvature replay.
  - `seeds311.jl`: seed scans of the fixture.
  - `tiny311.jl`, `tinyfixture311.jl`: the 2-row deterministic search, including seed 598.
  - `problems311.jl`, `counts311.jl`, `analyze_counts.py`: deterministic coordinate-visit counts on 7 designs.
  - `time311.jl`, `analyze_timing.py`: paired wall-time measurement.
  - `alloc311.jl`: bytes per full pass, per active pass and per solve.
- `research/results/`: raw outputs and summaries. Files ending in `_local_*` come from the local machine; `results/cluster/` holds the cluster run (see its `RUN.md`).
- `research/cluster/`: the job scripts. Scheduler headers and paths were removed; set the run root and Julia binary yourself.
- `pr313/` (added with the PR): the paired measurements and battery summaries at the PR's commits.

## Revisions

| label | commit | what |
|---|---|---|
| master (memo) | eb3332f8674fb013b958cd1d02698258e14582c3 | base of the research: #295, #293, #294 merged |
| E | 9407ac34545bbb328e2fdc6eb4d6d69defd4d86c | exploration build: `_FULL_PASS_INTERVAL` / `_FULL_PASS_MODE` `Ref`s switch the schedule in one process (research only) |
| C50 | a7672d9bf71b5dd32963f23e1bc28006cc8a0847 | full pass after 50 consecutive active passes |
| CW10 | 0e400796b9ff3b1b2c42ea0731ecc4216029361f | full pass after 10·p active visits |
| CW20 | ea7dcb3de23e26f9efd318bd96175ae773b1f10a | full pass after 20·p active visits (the approved design) |

The research commits are on local branches and were never pushed. Their source change is the diff in the memo's §4, which the probes do not need: `counts311.jl`, `seeds311.jl`, `tiny311.jl` and `repro311.jl` take the schedule as an argument and run on tree E. The PR's probes (`pr313/`) run on each tree's own schedule.

## Machines

- Local: Intel Core i5-13600K, Julia 1.10.13 and 1.13.3.
- Cluster (Slurm): AMD EPYC 7513 (no AVX-512), Julia 1.10.12 and 1.13.3, shared nodes. Exclusive nodes were not available within the time budget.

## Method

- **Accuracy oracle.** The KKT violation and the objective are recomputed in BigFloat with 256 bits from the raw Float32/Float64 data and the supplied loss scale, independently of the package. The KKT violation is relative to max(λ, ‖αXᵀy‖∞).
- **Work.** Coordinate visits are counted at the private `_pass!` boundary: p per full pass, `nactive` per active pass. They are deterministic for a given tree, Julia version and CPU, so they compare schedules without timing noise.
- **Time.** Fresh process per tree, rotated rounds, master-against-master (A/A) control, geometric mean of per-case ratios.
- **Allocations.** `@allocated` around single full and active passes after warm-up, and around whole solves with `maxpasses` = 10 and 1000.

## Limitations

- The stall depends on how column sums are rounded (SIMD order, inlining, coverage instrumentation). Results differ between builds and CPUs, except for the 2-row fixture, whose sums have two terms.
- Wall-time resolution of microsecond-scale solves on shared Julia 1.10 nodes is about ±15% per case.
- Not addressed by the fix: when `tol` is at the Float32 rounding level of the coefficients, the changes of full passes can also stay above `tol`, and CD ends at `maxpasses` without converging (memo §5, class (b)).
- Coverage `.cov` files and the local exploration worktrees are not archived.

## Integrity

`MANIFEST.sha256` lists the SHA-256 of every file. Check it with `sha256sum -c MANIFEST.sha256`.
