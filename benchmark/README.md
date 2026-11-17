# Benchmarks

This directory holds the benchmarking infrastructure of ProximalSolvers: reproducible runners and
problem generators, accuracy certificates that are independent of solver stopping rules,
matched-accuracy comparisons, statistical A/B comparisons with A/A noise controls, fresh-process
timing and allocation records, an external-solver comparison suite and the historical and migration
campaigns. All of it is kept and maintained, to be reused as solvers return to the package.

Master currently supports coordinate descent (`CDSolver`) with dense `Vector` or vector
`SparseIterate` iterates for least-squares lasso, and `BlockIterate` for group lasso.
Proximal gradient descent (`ProximalGradientDescent`) and accelerated proximal gradient
descent (`AccProxGradDescent`) support dense `Vector` least-squares lasso iterates.
All three solvers support Float32 and Float64. The formal harness runs their supported
cases on master; cases for other solvers and features are **deferred**: kept with their IDs
and definitions, listed with what they lack, and enabled again by declaring the
capability when the solver returns ([HARNESS.md](HARNESS.md#restoring-a-solver)).

| Component | Path | Runs against master? |
|---|---|---|
| Formal harness: problems, certificates, cases, runner, local exploration | `problems.jl`, `certificates.jl`, `cases.jl`, `run.jl`, `setup.jl`, `local.jl` | Yes: 30 quick or 56 extended cases (extended includes quick) with `setup.jl ... pinned`; 100 historical cases deferred in the extended suite. Documented in [HARNESS.md](HARNESS.md); `test/benchmark_formal.jl` tests it. |
| Historical environment template | `Project.toml` | Kept with ProximalBase 0.5 for full-package checkouts and Stage 2A verification (#225). |
| Harness self-checks | `check_certificates.jl`, `check_local.jl` | No (deferred): they exercise historical solvers. |
| Record validation, summaries, paired statistics | `validate.py`, `summarize.py`, `compare.py` | Yes. Python only; they read records and never load the package. |
| Analysis controls of the above | `check_analysis.py` | Yes, in CI. |
| Sparse-CD paired measurement and analysis | [`sparse_cd/`](sparse_cd/README.md) | Yes; analyzer controls in CI. |
| Exploratory CD/PGD timing | [`minimal/explore.jl`](minimal/explore.jl) | Yes; tested by `test/benchmark_explore.jl`. |
| External-solver comparison (CoordinateDescent 0.6.1) | [`external/`](external/README.md) | Measurements: no (deferred), frozen environments of the #117 comparison. Analysis controls: yes, in CI. |
| Stage 2A pre-0.6 baseline campaign | [`campaigns/pre06/`](campaigns/pre06/README.md) | Historical, frozen; its tests run offline. |
| Stage 2B migration campaign | [`campaigns/stage2b/`](campaigns/stage2b/README.md) | Unfinished (#110, #220, #229); runs pinned checkouts; its tests run offline. |

## What runs against master

```sh
# Formal, independently certified records (HARNESS.md): environment, supported and deferred cases, a run
julia benchmark/setup.jl "$PWD" benchmark/results/env pinned
PS_LIST=true julia --project=benchmark/results/env benchmark/run.jl                   # quick: 30 supported
PS_SUITE=extended PS_LIST=true julia --project=benchmark/results/env benchmark/run.jl # extended: 56 supported (includes quick)
PS_SUITE=extended PS_LIST=deferred julia --project=benchmark/results/env benchmark/run.jl # 100 deferred, with missing capabilities
JULIA_NUM_THREADS=1 PS_EXPECTED_PROXIMALBASE_REV=a19c59aa723d085d5d7cf5242895bda16eb77214 \
  julia --project=benchmark/results/env benchmark/run.jl
python3 benchmark/validate.py benchmark/results benchmark/results/validation.json
python3 benchmark/summarize.py benchmark/results benchmark/results/summary

# Exploratory timings of dense CD and PGD (root project; prints a table, writes nothing)
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 julia --startup-file=no --project=. benchmark/minimal/explore.jl

# Paired, controlled CD measurements between two clean checkouts, then the analysis
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 julia --startup-file=no --project=. \
  benchmark/sparse_cd/measure.jl BASE_TREE HEAD_TREE NEW_OUTPUT
python3 -I benchmark/sparse_cd/analyze.py NEW_OUTPUT
```

`minimal/explore.jl` and `local.jl` are **exploratory**: one process, no paired baseline, no A/A
control and no record validation (`local.jl` does use the harness's cases and certificates). Their
timings show whether a change deserves a closer look. They are not evidence of a speedup or of
noninferiority. Such claims need a formal comparison: fresh processes of two clean, committed
revisions run alternately by one fixed harness, with an A/A control on the same machine, then
`compare.py` ([HARNESS.md](HARNESS.md#compare-revisions)); `sparse_cd/` remains a paired
alternative for CD owner and copy costs.

The CI job `Benchmark analysis controls` runs these, with no Julia benchmark environment and no timing:

```sh
python3 benchmark/check_analysis.py               # validate.py, summarize.py, compare.py on synthetic records
python3 -I benchmark/sparse_cd/check_analysis.py  # sparse-CD analyzer refusal controls
python3 -B benchmark/external/coordinatedescent/check_analysis.py  # external-comparison analysis controls
julia --startup-file=no --project=@stdlib scripts/paired_master_diagnostics.jl
```

## The formal harness

[HARNESS.md](HARNESS.md) documents the harness in full: the current core, setup and case selection,
supported and deferred cases, local exploration with `local.jl`, certificates and statuses, timed
phases, the fixed workloads of #103–#109, revision comparisons with A/A controls, record formats,
provenance, exit codes and restoring a solver.

**Current core.** `setup.jl CHECKOUT ENV pinned` builds an environment from the checkout's exact
ProximalBase pin (URL and full commit of the root `Project.toml` `[sources]`) on Julia 1.10 and
current stable; `benchmark/Project.toml` keeps ProximalBase 0.5 for the historical modes. `run.jl`
refuses a ProximalBase other than the loaded checkout's pin (URL, commit and committed manifest
tree), at a moving revision or outside its manifest tree, records its manifest identity, and checks `PS_EXPECTED_PROXIMALBASE_REV` and `PS_EXPECTED_PACKAGE_REVISION` when set.
`cases.jl` declares the core's capabilities. With all groups selected, the default quick suite
supports 30 cases: 24 standard least-squares lasso cases, 4 group-lasso CD cases on a
`BlockIterate`, and 2 unchanged historical cases. The extended suite includes quick and
supports 56 cases: 40 standard least-squares lasso cases (dense and `SparseIterate` CD,
dense PGD and APG, Float32/Float64), 10 accuracy-focused Float64 PGD/APG `acc-` cases,
4 group-lasso CD cases, and the same 2 historical cases. The other 100 historical
cases are deferred in the extended suite (`PS_LIST=deferred`). Requesting a deferred
case stops the runner with what it lacks.

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

Status after #110 (the PR that restored the harness on master): steps 1, 3 and 4 are done, step 2
is done without changing `benchmark/Project.toml`, and steps 5 and 6 remain.

1. **Sequencing with Stage 2B.** Done: the Stage 2B tests read the frozen harness from its pinned
   commits instead of the working tree (see "Frozen identities" above), so editing the four harness
   files on master changes the working-tree harness hash but not the approved Stage 2B identities.
2. **Environment.** Done: `setup.jl ... pinned` takes the exact source pin and ProximalBase compat
   of the checkout's root `Project.toml`; `benchmark/Project.toml` is unchanged (ProximalBase 0.5),
   because Stage 2A verification reads it. Moving the template to a registered ProximalBase 0.6
   release is #225.
3. **Capability-gated catalog.** Done, with declared capabilities instead of `isdefined`
   predicates (a solver type can exist without supporting a problem, iterate or phase): each case
   lists its requirements, `CAPABILITIES` lists the core's, and the per-solver options rule replaces
   the hard-coded `Union`. Start metadata records the capabilities and the deferred count.
4. **Current API.** Done for #110: 40 standard least-squares lasso cases, 10 of them for APG
   (HARNESS.md, "Supported and deferred cases"). Later restorations added 10 extended
   accuracy-focused PGD/APG cases (#314, #318) and 4 group-lasso CD cases (#275, #326).
   `problems.jl` and `certificates.jl` are unchanged; Float32 problems are certified in exact
   Float64.
5. **External suite.** Its analysis already works on current records and runs in CI. Port
   `current.jl` (and the `current/` environment) to the master API when a comparison is wanted,
   keeping the catalog and the analysis.
6. **Retire duplicates.** Not done, and a separate change: `minimal/explore.jl` and `sparse_cd/`
   stay until the formal harness shows equivalent coverage, diagnostics and usability for them
   (`sparse_cd/` measures owner and copy costs that are not harness phases yet).

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
