# ProximalSolvers.jl #110: A/A campaign on current master (2026-11-18)

This directory is the evidence for the A/A findings posted on #110. `analysis/post-110-aa.md` is the text as posted.
It covers the single A/A campaign the maintainer approved after the current-master baseline
([`archive/issue-110-baseline-20261118`](https://github.com/mlakolar/ProximalSolvers.jl/tree/792ddedec3d3ed137ad56c2bc491370123496579), `792ddede`).
None of it is part of the package, and none of it is built or tested.

## Design (fixed before the run)

`preregistration/PREREGISTRATION-aa110.md` and its checksums (`PREREGISTRATION-aa110.sha256`) were written and frozen
before the job was submitted. The checksums cover the preregistration, the job body and the analysis script. On the
node, the job log recorded the preregistration's sha256 (`logs/node.txt`).

| Item | Value |
|---|---|
| ProximalSolvers | `a0a064778acb34d0535408a31ab2f09ae657e4aa`, three clean clones (`ps-H` runs the harness for both sides; `ps-A`, `ps-B` are the package) |
| ProximalBase | `a19c59aa723d085d5d7cf5242895bda16eb77214`, tree `138929aa27c6221284ee1763e66b1110dd6ec418` |
| Installations | for each of Julia 1.10.13 and 1.13.3, two (A, B), each with its own clone, `benchmark/setup.jl … pinned` environment and private depot |
| Machine | one exclusive Intel Xeon E5-2640 v4 node; 1 Julia thread, 1 BLAS thread; no co-tenants (`logs/node.txt`) |
| Cases | 50 (`PS_SUITE=extended`; `PS_CASES` in `scripts/aa110.sh`): 40 primary (28 CD, 12 Float64 `acc-`), 10 default-setting Float64 PGD/APG diagnostics |
| Order | repetitions 1–10; A and B back to back, A,B on odd and B,A on even repetitions; the version order alternates too |
| Work receipts | `benchmark/local.jl` (unchanged), separate processes after all timing; counters read from the returned results; its timings unused |
| Job | 47 min 50 s, one attempt (`logs/job-accounting.txt`) |

## Contents

- `results/<v>-<s>/`: the raw `run.jl` records, with 10 processes for each of the four installations.
- `work/<v>-<s>-rep<r>.tsv`, `.log`: the `local.jl` work receipts, with work counters and data hash for each case.
- `analysis/cmp/<v>/`: the `compare.py <v>-A <v>-B` outputs (`comparison.csv`, `REPORT.md`, `coverage.json`).
- `analysis/aa-report.md`: the output of `scripts/aa_analysis.py`, statistics 1–5 of the preregistration.
- `installation/`: `versioninfo` and the loaded package paths of each installation, plus a sha256 of every file under
  each depot's `compiled/` directory.
- `env/`: `Project.toml` and `Manifest.toml` of each installation.
- `logs/`: the node and co-tenant log, exit codes with wall time and load, per-process runner logs, the case lists,
  the setup logs, the on-node validation of each installation and the job's standard output.

## Reproduce the analysis

Use Python 3.11+ and the benchmark scripts of ProximalSolvers `a0a0647`. Run them without `python3 -I`, because
`summarize.py` and `compare.py` import `validate` from their own directory.

```sh
for v in j110 j113; do
  python3 benchmark/compare.py results/$v-A results/$v-B cmp/$v --expected-runs 10
done
mkdir out && cp -r results/* work out/
python3 scripts/aa_analysis.py out cmp aa-report.md
```

With the scrubbed records, these commands reproduce `analysis/cmp/*/comparison.csv`, `REPORT.md`, `coverage.json` and
`analysis/aa-report.md` byte for byte.

## Scrubbing

- Cluster paths, the Julia install root, the node name, the user name and the scheduler queue name are replaced by
  `<cluster-dir>`, `<julia-root>`, `<node>`, `<user>` and `<partition>`.
- The site `LD_LIBRARY_PATH` in `versioninfo` is replaced by a note. It was identical in all four installations.
- In `scripts/aa110.sh` and the logs, the scheduler's environment variables read `JOB_ID` and `RESTART_COUNT`, and
  the queue and node-list fields are removed.
- These two lines are the only difference between `scripts/aa110.sh` and the preregistered job body
  (sha256 `f7530823…` in `PREREGISTRATION-aa110.sha256`). `scripts/aa_analysis.py` and the preregistration are
  unchanged and match their recorded checksums.
- The scheduler wrapper and the dependency depots are omitted.
- `SHA256SUMS` lists every other file.
