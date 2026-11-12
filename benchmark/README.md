# Benchmarks

Master supports coordinate descent (`CDSolver`, with a dense `Vector` or a vector
`SparseIterate`) and proximal gradient descent (`ProximalGradientDescent`, with a dense `Vector`)
on Float32 and Float64 least-squares lasso. This directory has three parts: benchmarks that run
against master, a historical harness kept for the unfinished Stage 2B migration campaign, and the
campaign definitions.

## Current benchmarks (run against master)

| Path | Use |
|---|---|
| [`minimal/explore.jl`](minimal/explore.jl) | Exploratory timings of dense CD and dense PGD on Float32/Float64 lasso, with an optimality (KKT) residual computed from the problem data. One process, no baseline and no noise control: it can show that a change is worth a closer look, not that it is faster. Writes nothing. |
| [`sparse_cd/`](sparse_cd/) | Paired, controlled CD measurements: dense base against head, head against head (noise control), and dense against `SparseIterate` input, plus `SparseIterate` copy costs. Includes the analyzer and its refusal controls. See [`sparse_cd/README.md`](sparse_cd/README.md) and the evidence in [`docs/audit/sparse-cd/`](../docs/audit/sparse-cd/README.md). |

Both run under the root project. No extra package is needed.

```sh
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 julia --startup-file=no --project=. benchmark/minimal/explore.jl
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 julia --startup-file=no --project=. \
  benchmark/sparse_cd/measure.jl BASE_TREE HEAD_TREE NEW_OUTPUT
python3 -I benchmark/sparse_cd/analyze.py NEW_OUTPUT
```

### CI analysis controls

The `Benchmark analysis controls` job runs on every CI run. It needs no Julia benchmark
environment and takes no timings:

```sh
python3 benchmark/check_analysis.py              # compare.py, summarize.py, validate.py on synthetic records
python3 -I benchmark/sparse_cd/check_analysis.py # the sparse-CD analyzer's refusal controls
julia --startup-file=no --project=@stdlib scripts/paired_master_diagnostics.jl
```

## Historical harness kept for Stage 2B

The files below are the matched-accuracy harness of the full package (#110). **They do not run
against master.** Their cases use solvers that the minimal core does not have (ADMM, proximal
Newton, QUIC, Condat–Vũ, APG and others), and `Project.toml` requires ProximalBase 0.5 while master
requires 0.6. They are kept, unedited, because unfinished work depends on these exact files:

| Files | Needed by |
|---|---|
| `problems.jl`, `certificates.jl`, `cases.jl`, `run.jl` | Stage 2B: `campaigns/stage2b/test_stage2b_files.py` requires their harness hash to equal `new_harness_hash` in `case-mapping.toml` (the approved P14 port); `test_migration_compare.py` pins the SHA-256 of `run.jl`, `problems.jl` and `certificates.jl`. `test_p14_reset.jl` and `export_fingerprints.jl` load them. |
| `compare.py`, `validate.py`, `summarize.py` | The CI analysis controls; Stage 2B pins their SHA-256 and imports `validate.py`; Stage 2A verification (`campaigns/pre06/campaign.py`) imports `validate.py` and `summarize.py` from this directory. |
| `Project.toml` | Stage 2A verification compares archived environments with it; the Stage 2B Julia tests run in an environment built from it. Its move to ProximalBase 0.6 is tracked by #225. |
| `setup.jl`, `local.jl` | The runner interface the campaigns record; `STAGE2B_PLAN.md` reads work counters from `local.jl`. |
| `check_certificates.jl`, `check_local.jl` | The self-checks of `certificates.jl` and `local.jl`. |

Any byte change to the four harness files changes the harness identity of the Stage 2B campaign.
The campaigns never execute the copies on master: each role runs `benchmark/run.jl` of its own
pinned checkout. The documentation of the runner (settings, certificates, phases, records, the
revision-comparison recipe and the fixed workloads of #103–#109) is the
[benchmark README at the protected archive](https://github.com/mlakolar/ProximalSolvers.jl/blob/9be1773e911a44ec21d49df28cb01fea37c4316e/benchmark/README.md);
use it with a full-package checkout such as `legacy/full`, not with master.

## Campaigns

| Path | Status |
|---|---|
| [`campaigns/pre06/`](campaigns/pre06/README.md) | Stage 2A pre-0.6 baseline (#110). Complete and frozen; the archive is the Release `bench-pre06-v1`. Stage 2B reads its definition. |
| [`campaigns/stage2b/`](campaigns/stage2b/README.md) | Stage 2B migration comparison across ProximalBase 0.6 (#110, #220, #229). Tooling only; no official measurement yet. |

The offline Stage 2B Python tests run from the repository root:

```sh
python3 -B benchmark/campaigns/stage2b/test_migration_compare.py
python3 -B benchmark/campaigns/stage2b/test_stage2b_files.py
python3 -B benchmark/campaigns/stage2b/test_stage2b_campaign.py
python3 -B benchmark/campaigns/stage2b/probes/test_check_reset_probes.py
```

## Removed material

Everything removed from this directory remains in Git history and in the protected annotated
tag `archive/full-before-reset-2026-11-10` (commit `9be1773e911a44ec21d49df28cb01fea37c4316e`,
also `legacy/full` at the time of removal):

- `external/`: the CoordinateDescent 0.6.1 comparison suite (#117; analysis cited by #137).
  Retrieve it with
  `git archive archive/full-before-reset-2026-11-10 benchmark/external | tar -x -C DIR`.
- Studies for #18–#95, including comparisons with glmnet, Lasso.jl, R packages, SLOPE.jl/libslope and
  ProximalAlgorithms: the
  [pre-cleanup tree](https://github.com/mlakolar/ProximalSolvers.jl/tree/f7e3f28026a8e83e0fa18203b39839cf57a1c949/benchmark).

Generated results, environments, logs and archives are not committed.
