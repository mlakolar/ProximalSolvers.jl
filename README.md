# ProximalSolvers.jl #110: current-master baseline of the 62-case extended catalog (2026-11-18)

This is the evidence for the descriptive current-master reference that the maintainer accepted on #110:
the [baseline report](https://github.com/mlakolar/ProximalSolvers.jl/issues/110#issuecomment-6987228427) (`tables/post-110.md` is the text as posted).
This archive is not part of the package; nothing here is built or tested. The readout describes each case on its own:
it does not rank solvers, and its per-case intervals are not paired cross-solver comparisons. The frozen historical
Stage 2A baseline is separate and unchanged; this archive does not replace it.

## Identities

| Item | Value |
|---|---|
| ProximalSolvers | `a0a064778acb34d0535408a31ab2f09ae657e4aa` (master), clean; enforced by `PS_EXPECTED_PACKAGE_REVISION` |
| ProximalBase | `a19c59aa723d085d5d7cf5242895bda16eb77214`, git tree `138929aa27c6221284ee1763e66b1110dd6ec418`; enforced by `PS_EXPECTED_PROXIMALBASE_REV` |
| Harness hash | `11b291250927e604d7a6e6af3ea343258b775570` |
| Julia | 1.10.13 and 1.13.3 (official binaries) |
| Machine | one exclusive cluster node, Intel Xeon E5-2640 v4 (broadwell), 20 cores, 1 thread per core; OpenBLAS ILP64 |
| Threads | 1 Julia thread, 1 BLAS thread |
| Job | 15 min 52 s, one attempt; no other job on the node at start, after setup or at the end (`logs/node.txt`) |

## Reproduce

From a clean clone of ProximalSolvers.jl at `a0a0647`, for each Julia version (fresh depot per version):

```sh
julia benchmark/setup.jl "$PWD" "$ENV" pinned
for rep in $(seq 1 10); do
  PS_SUITE=extended PS_REPETITION=$rep PS_OUTPUT="$OUT" JULIA_NUM_THREADS=1 \
    PS_EXPECTED_PACKAGE_ROOT="$PWD" \
    PS_EXPECTED_PACKAGE_REVISION=a0a064778acb34d0535408a31ab2f09ae657e4aa \
    PS_EXPECTED_PROXIMALBASE_REV=a19c59aa723d085d5d7cf5242895bda16eb77214 \
    julia --project="$ENV" benchmark/run.jl    # exit 2 = complete records with non-ok cases
done
```

`scripts/job110.sh` is the job body that was run: it alternates which Julia version goes first in each repetition and
records the node state. The scheduler wrapper is omitted. Analysis (Python 3.11+, standard library), with the
benchmark scripts of the same revision:

```sh
mkdir both && cp results/j110/* results/j113/* both/
python3 benchmark/validate.py both validation.json --expected-runs 10
python3 benchmark/summarize.py both summary --expected-runs 10
python3 benchmark/cross_solver.py both summary cross-solver --expected-runs 10
python3 scripts/baseline_table.py cross-solver/cross_solver.csv fresh-table.md "fresh campaign, PS a0a06477"
python3 scripts/extra_tables.py existing-cross_solver.csv cross-solver/cross_solver.csv existing-records both extra-tables.md
```

Generated from the scrubbed records in this archive, `summary.csv`, `SUMMARY.md`, `cross_solver.csv` and `REPORT.md` are
byte-identical to those in `analysis/`. The validation counts are identical too.

## Contents

- `results/j110/`, `results/j113/`: the raw records of all 20 processes. Each process wrote catalog, metrics, samples,
  errors and start/final metadata files.
- `env/`: `Project.toml` and `Manifest.toml` of the two benchmark environments.
- `logs/`: the node and co-tenant log (`node.txt`), runner exit codes with wall time and load (`exit-codes.txt`),
  per-process runner logs, the case lists, the setup logs, the on-node validation of each version, the job's standard
  output (`job-stdout.log`) and a one-line summary of the scheduler accounting (`job-accounting.txt`).
- `analysis/`: `validate.py` (`validation.json`), `summarize.py` (`summary/`) and `cross_solver.py` (`cross-solver/REPORT.md`, `cross_solver.csv`) outputs for both versions together.
- `existing-readout/`: the same three outputs for the earlier validated series at `637f06a`, which the report uses as a
  revision reference. That series covers 52 cases, with PB `c123d56b` and harness `164fab53`. Its raw records are **not
  duplicated** here: they are `baseline/<version>/formal-A1/` on the branch
  [`archive/issue-307-evidence`](https://github.com/mlakolar/ProximalSolvers.jl/tree/7f11f67d0e1daf66f9c5b1baa6ef819383951f84/baseline)
  at `7f11f67d0e1daf66f9c5b1baa6ef819383951f84`, and all 120 files are byte-identical to the copy this readout used.
- `scripts/`: `job110.sh` and the two table scripts. The table scripts read only `cross_solver.csv` and the metrics TSVs.
- `tables/`: the per-configuration tables (`fresh-table.md`, `existing-table.md`), the comparison between the series
  and the timing tables (`extra-tables.md`), the extended case list (`list-extended.txt`) and the report as posted
  (`post-110.md`).

## Scrubbing and omissions

- Cluster paths, the Julia install root, the node name, the user name and the scheduler queue name are replaced by
  `<cluster-dir>`, `<julia-root>`, `<node>`, `<user>` and `<partition>`. In `scripts/job110.sh` and the logs, the
  scheduler's environment variables read `JOB_ID` and `RESTART_COUNT`; the queue and node-list fields are removed.
- Dependency depots, precompiled caches and the combined records directory (a copy of `results/j110` plus
  `results/j113`) are omitted.
- `SHA256SUMS` lists every other file.
