# Benchmarks

This directory holds the benchmarking infrastructure of ProximalSolvers: reproducible runners and
problem generators, accuracy certificates that are independent of solver stopping rules,
matched-accuracy comparisons, statistical A/B comparisons with A/A noise controls, fresh-process
timing and allocation records, an external-solver comparison suite and the historical and migration
campaigns. All of it is kept and maintained, to be reused as solvers return to the package.

Master currently supports coordinate descent (`CDSolver`, with a dense `Vector` or a vector
`SparseIterate`) and proximal gradient descent (`ProximalGradientDescent`, dense `Vector`) on Float32
and Float64 least-squares lasso. Parts of the infrastructure run against master today; the rest is
**deferred**: executable and maintained, but it needs historical package versions until the work in
[Enabling the formal harness on master](#enabling-the-formal-harness-on-master) is done.

| Component | Path | Runs against master? |
|---|---|---|
| Formal harness: problems, certificates, cases, runner, local exploration | `problems.jl`, `certificates.jl`, `cases.jl`, `run.jl`, `setup.jl`, `local.jl`, `Project.toml` | No (deferred): needs ProximalBase 0.5 and the full package. Documented in [HARNESS.md](HARNESS.md). |
| Harness self-checks | `check_certificates.jl`, `check_local.jl` | No (deferred), as above. |
| Record validation, summaries, paired statistics | `validate.py`, `summarize.py`, `compare.py` | Yes. Python only; they read records and never load the package. |
| Analysis controls of the above | `check_analysis.py` | Yes, in CI. |
| Sparse-CD paired measurement and analysis | [`sparse_cd/`](sparse_cd/README.md) | Yes; analyzer controls in CI. |
| Exploratory CD/PGD timing | [`minimal/explore.jl`](minimal/explore.jl) | Yes; tested by `test/benchmark_explore.jl`. |
| External-solver comparison (CoordinateDescent 0.6.1) | [`external/`](external/README.md) | Measurements: no (deferred), frozen environments of the #117 comparison. Analysis controls: yes, in CI. |
| Stage 2A pre-0.6 baseline campaign | [`campaigns/pre06/`](campaigns/pre06/README.md) | Historical, frozen; its tests run offline. |
| Stage 2B migration campaign | [`campaigns/stage2b/`](campaigns/stage2b/README.md) | Unfinished (#110, #220, #229); runs pinned checkouts; its tests run offline. |

## What runs against master

```sh
# Exploratory timings of dense CD and PGD (root project; prints a table, writes nothing)
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 julia --startup-file=no --project=. benchmark/minimal/explore.jl

# Paired, controlled CD measurements between two clean checkouts, then the analysis
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 julia --startup-file=no --project=. \
  benchmark/sparse_cd/measure.jl BASE_TREE HEAD_TREE NEW_OUTPUT
python3 -I benchmark/sparse_cd/analyze.py NEW_OUTPUT
```

`minimal/explore.jl` is **not** the formal benchmark framework. It runs one process with no paired
baseline, no A/A control and no record validation, and checks a KKT residual computed from the
problem data. Its timings show whether a change deserves a closer look. They are not evidence of a
speedup or of noninferiority. Such claims need a paired comparison: `sparse_cd/` for CD today, and
the formal harness with `compare.py` once it is enabled on master.

The CI job `Benchmark analysis controls` runs these, with no Julia benchmark environment and no timing:

```sh
python3 benchmark/check_analysis.py               # validate.py, summarize.py, compare.py on synthetic records
python3 -I benchmark/sparse_cd/check_analysis.py  # sparse-CD analyzer refusal controls
python3 -B benchmark/external/coordinatedescent/check_analysis.py  # external-comparison analysis controls
julia --startup-file=no --project=@stdlib scripts/paired_master_diagnostics.jl
```

## The formal harness (deferred)

[HARNESS.md](HARNESS.md) documents the harness in full: setup and case selection, local exploration
with `local.jl`, certificates and statuses, timed phases, the fixed workloads of #103–#109, revision
comparisons with A/A controls, record formats, provenance and exit codes.

**Current limitation.** `benchmark/Project.toml` requires ProximalBase 0.5, and `setup.jl` copies
that compat into every environment it creates, while master requires ProximalBase 0.6. Resolving the
benchmark environment against master fails (`Unsatisfiable requirements detected for package
ProximalBase`). `cases.jl` also constructs solvers and APIs that the minimal core does not have yet
(`ProxNewton`, `ADMMSolver`, `AccProxGradDescent`, `SolverWorkspace`, `reinit!`,
`SqrtLeastSquaresLoss` and others). The harness therefore runs only against full-package checkouts
with ProximalBase 0.5.4, such as Stack A `b0de3f7` of Stage 2B or `legacy/full`.

**Frozen identities.** The Stage 2B harness identities are verified against pinned historical
commits, not against the working tree, so the four harness files (`problems.jl`, `certificates.jl`,
`cases.jl`, `run.jl`) can change on master without invalidating them:

- `campaigns/stage2b/test_stage2b_campaign.py` reads the four files with git at
  `412063d8ac24b84a10ccde09cf072bb396109ffd` (byte-identical to the P14 port commit of #217) and
  requires the harness hash `0fd2b44dfea0b1f77c2c67228bf149207982ab8b`, the `new_harness_hash` in
  `campaigns/stage2b/case-mapping.toml`; and at Stack A `b0de3f7fc91767b97197ff4b458207e308998943`
  it requires `b7bf3d953ec6e9f9720e74d7895b5cf95a629fd4`, the `[stack_a] harness_hash` in
  `schedule.toml`. A missing commit or file fails the test; it is never skipped. These approved
  hashes are unchanged, and the official Stage 2B campaign still runs its own pinned checkouts.
- `test_migration_compare.py` still pins the SHA-256 of `compare.py`, `validate.py` and
  `summarize.py` in the working tree, because the current comparator imports `validate.py` and
  `summarize.py`. Do not edit these three files on master until the plan below is approved.
- `campaigns/pre06/campaign.py` verification compares archived environments with
  `benchmark/Project.toml` and imports `validate.py` and `summarize.py` from this directory.

## External-solver comparison (deferred)

[`external/`](external/README.md) compares ProximalSolvers with CoordinateDescent 0.6.1 on frozen,
certified cases (#117; findings in #137). It has the runner and adapters, input generation shared with
`problems.jl`, an independent certificate cross-check, the matched-accuracy statistical analysis with
calibration and A/A arms, synthetic analysis controls, the frozen case catalog and the environment
locks. It is kept unchanged as a reusable template for external comparisons. Its `current/`
environment develops this repository, so it needs a full-package checkout. Adapting it to master
means a new adapter and environment, with the catalog and analysis kept.

Its analysis controls (`python3 -B benchmark/external/coordinatedescent/check_analysis.py`, about
4 s, fixed seeds, no Julia) run in CI. **Compatibility fix (PR #253).** Since `b0de3f7` (#110 Stage 1),
`validate.SERIES_SETTINGS` has included the optional key `case_filter`, which `validate.setting` reads
as `""` (no filter) when absent. `analysis.py` read it as `meta[key]` and stopped with
`KeyError: 'case_filter'`, so it now reads `base_validate.setting(meta, key)`, as `validate.py` does.
No other line of the analysis changed. The `optional-case-filter` control checks that a missing and an
explicitly empty `case_filter` give identical results, also when mixed within an arm, and that a
nonempty filter that differs between blocks of an arm is refused (`series settings changed`). As
before, the comparison across arms checks a fixed list of settings that does not include `groups` or
`case_filter`; matched case coverage is enforced through the catalog and block cells. The source
before the fix is in the protected archive `9be1773e911a44ec21d49df28cb01fea37c4316e`.

## Enabling the formal harness on master

The aim is to use the one existing framework for the current CD/PGD cases and for each solver as it
returns, without a second runner, a second record format or duplicate statistics. Minimum work, in order:

1. **Sequencing with Stage 2B.** Done: the Stage 2B tests read the frozen harness from its pinned
   commits instead of the working tree (see "Frozen identities" above), so editing the four harness
   files on master changes the working-tree harness hash but not the approved Stage 2B identities.
2. **Environment (#225).** Allow ProximalBase 0.6 in `benchmark/Project.toml`, and let `setup.jl` take
   the exact source pin of the root `Project.toml` (a URL and revision) as well as a version or a
   path. Keep the Stage 2A comparison valid by running it from its freeze checkout, as its README
   already requires.
3. **Capability-gated catalog.** In `cases.jl`, add each case only if its solver and phase exist in
   the loaded package (for example a table from solver ID to a predicate such as
   `isdefined(ProximalSolvers, :ADMMSolver)`), and list the excluded cases with the reason in the
   start metadata, never silently. Drop the hard-coded `Union{PS.CDSolver, PS.ProxNewton, ...}` in
   favour of a per-solver options rule. Restoring a solver then re-enables its existing cases with
   no other change.
4. **Current API.** Adapt the CD and PGD case constructors to the minimal core: `CDSolver` options,
   dense `Vector` and vector `SparseIterate` starts, no `SolverWorkspace` phase until workspaces
   return, and Float32 cases for the supported precisions. `problems.jl` and `certificates.jl` should
   need no change: they use plain data and returned minimizers.
5. **External suite.** Its analysis already works on current records and runs in CI. Port
   `current.jl` (and the `current/` environment) to the master API when a comparison is wanted,
   keeping the catalog and the analysis.
6. **Retire duplicates.** When steps 3 and 4 are done, `local.jl` replaces `minimal/explore.jl`.
   `sparse_cd/` can become a harness phase or variant (dense vs `SparseIterate` input, copy costs)
   that uses `validate.py` and `compare.py`, so its separate analyzer can go.

Records keep their format throughout, so `validate.py`, `summarize.py`, `compare.py` and
`check_analysis.py` stay unchanged and continue to compare new records with historical ones where
the catalog and data hashes match.

## History

Studies for #18–#95, including comparisons with glmnet, Lasso.jl, R packages, SLOPE.jl/libslope and
ProximalAlgorithms, are in the
[pre-cleanup tree](https://github.com/mlakolar/ProximalSolvers.jl/tree/f7e3f28026a8e83e0fa18203b39839cf57a1c949/benchmark).
The full package, including this directory as of the minimal-core rebuild, is preserved at the
protected tag `archive/full-before-reset-2026-11-10` (`9be1773e911a44ec21d49df28cb01fea37c4316e`).
Generated results, environments, logs and archives are not committed.
