# Run record and validation

Run: `20261026-ps95-hybrid-v2` on Discovery.
Remote root: `/home1/mkolar/juliaPkg/runs/20261026-ps95-hybrid-v2`.
Local registry: `/Users/mladen.kolar/projects/juliaPkg/.slurm/runs/20261026-ps95-hybrid-v2.json`.

All compilation, numerical tests, fitting, certification, memory measurement and
report aggregation were executed on Discovery. Local work was source editing,
transport, reading outputs and Git operations. Jobs were sequential allocations;
workers within the matched and RSS jobs used GNU Parallel and exclusive
single-CPU `srun` steps. Thread counts were one. Account `mkolar_1314`, partition
`main`, constraint `epyc-7513`; GCC 13.3.0, Eigen 3.4.0, GNU Parallel 20240522.
The allocation ceiling was 8 CPUs, 16 GB and 7,200 active seconds across retries.

## Sources

- Parent branch commit: `1685eedc4383b59f181fa1b3632869f259c9214d`.
- Measured implementation: preserved `source-fallback2.tar`, SHA-256
  `8b6e88b3bd787beeba00143c2a5ca91f30c29d465acecef8c9fcd974553071a8`.
  This archive contains the uncommitted solver, tests and harness used by the
  successful full suite and main comparison. Later report/aggregation edits and
  eight additional test assertions do not change the fitting implementation.
  The final test-file hash is also retained in `source-sha256.txt`.
- ProximalBase: `b6c949f3dd26cad09252e1c2c9e49810eb69403e`.
- Unchanged native libslope source: `a9899cbf3677ea63236d54dc18626ad3a5aeddc6`.
  Existing static build: `20261025T1030Z-ps-slope-first-order/native-build/src/libslope.a`.
- Plain bridge SHA-256:
  `acfc219a2304a6864963637a25bae89f578dfb2a5f9372deef9f5f3c703f08ce`.
- Counted bridge SHA-256:
  `dbc09755c8e275bbeb0faffd48178a4a64eed8ff5882f0775bc7ac8bf70a134f`.
- Julia 1.13.2 for the full suite and comparison. Julia 1.10.12 for the
  minimum-supported-version focused check. Worker environment TOMLs retain
  actual CPU/BLAS descriptions, target tolerances, budgets and Slurm IDs.

## Attempts, including failures

| Job | Stage | Allocation | Elapsed seconds | Outcome |
|---|---|---|---:|---|
| 13455673 | Initial build/tests canary | 2 CPUs, 8 GB, 15 min | 95 | Failed: budget test reached an exact optimum before consuming its allowance. Test assumption corrected; log retained. |
| 13455729 | Recovery canary and suite | 1 CPU, 8 GB, 15 min | 608 | 382 focused checks passed. Failed suite: source staging included AppleDouble metadata interpreted as example scripts. Actual examples passed. Native bitwise replay assertion was too strong; small prediction differences were independently checked instead. |
| 13455865 | Corrected staging/calibration | 1 CPU, 8 GB, 10 min | 152 | 882 focused checks, 16 examples and 11 Aqua checks passed. Hard canary failures retained. Its fallback exhausted reduced problems unnecessarily; repaired before the heldout comparison. |
| 13455933 | Fallback repair validation | 1 CPU, 8 GB, 15 min | 48 | Failed: APG options reject a one-step remaining budget. Added direct final-step handling. |
| 13455948 | Final focused checks, canary and complete suite | 1 CPU, 8 GB, 15 min | 587 | Passed: 888 focused checks; complete suite 18,298 assertions; naming check. |
| 13455962 | Matched comparison | 4 CPUs, 16 GB, 45 min | 469 | Passed coverage/integrity: 1,980 requests and 19,437 returned levels; 54 requests with accuracy, replay or internal-flag issues retained. |
| 13456031 | Initial RSS launcher | 4 CPUs, 16 GB, 10 min | 1 | Failed before fitting: GNU time unavailable on compute nodes. Replaced with Python child-resource accounting. |
| 13456084 | First aggregation and historical integrity checks | 1 CPU, 4 GB, 5 min | 6 | Passed; report initially lacked RSS, which was added after recovery. |
| 13456110 | RSS recovery and Julia 1.10 | 4 CPUs, 16 GB, 10 min | 81 | Twelve isolated RSS fits recorded; eight Julia and two native paths met common targets. Two native failures retained. Julia 1.10: 888 focused checks passed. |
| 13456165 | Uniform tighter native RSS followup | 2 CPUs, 8 GB, 5 min | 44 | Four additional native RSS fits at 1e-10; two still missed complete-path accuracy within the cap. Original and followup results retained separately. |
| 13456194 | Final aggregation and integrity | 1 CPU, 4 GB, 5 min | 5 | Passed: both RSS cohorts, primary matched summary, report and all historical CI benchmark integrity checks. |
| 13456227 | Explicit production-kernel edge checks | 2 CPUs, 8 GB, 3 min | 21 | Passed 896 focused assertions on each Julia version, adding exact zero-curvature and initially tied PG splitting checks; solver unchanged. |
| 13456300 | Integration with updated master/APG state | 2 CPUs, 16 GB, 15 min | 540 | Passed merged full suite: 18,533 assertions on Julia 1.13.2; 896 focused checks on Julia 1.10.12; eight representative fits reproduced saved coefficients exactly. |

The final focused checks cover independent scalar minimization oracles,
objective decrease, residual consistency, membership and ranks through repeated
sweeps, dense/CSC/product-only implicit designs, rank deficiency, excluded-set
repairs, Float32, retained budget failures, rejected-update fallback and a bounded
allocation check on a warmed cluster sweep. The APG fallback uses established
stopping logic and reuses its state; its final full check remains the shared
path driver's responsibility.

The first calibration used native tolerance 1e-10, a 30-second soft cap and an
inappropriate bitwise replay assertion. The final protocol fixes native
tolerance 1e-8 and a 10-second soft cap for every main/confirmation workload.
The native RSS-only followup tightened all four selected cases uniformly to
1e-10; it did not change the primary benchmark. Both RSS cohorts and their
failed targets remain visible. Both calibrations and their adverse outputs are retained. These settings were
chosen on seed-1 canaries before the main and confirmation run. There was no
per-case tolerance adjustment or removal of difficult cases.

Total allocation-active time was 2,657 seconds (44 minutes 17 seconds), including
all failed attempts. All task allocations finished. The source and dependency
archives, native libraries and serialized RSS solutions remain at the remote run
root. Compact raw reporting inputs, environment manifests, logs, source hashes
and scheduler receipts are checked in under `evidence/`. No original adverse
results were removed. The full suite passed before the eight additional focused
assertions; those final focused tests passed separately on both Julia versions.

## Integration with updated master

PR #98 merged diagonal preconditioning while the hybrid study was running.
The branch integrates master `fbb6d93b187c7cab30a61a2762b9838ae3df3c68` and
preserves both sets of CI evidence checks. APG now carries a metric field; its
default `nothing` dispatch delegates to the original scalar operations. The
hybrid's numerical kernel required no adjustment.

Job `13456300` tested this integration with the full Julia 1.13.2 suite (18,533
assertions), the final Julia 1.10.12 focused suite (896 assertions), naming and
both new benchmark integrity checks. It also replayed the four RSS workloads
with APG and hybrid: all eight fits met the common targets and reproduced every
saved coefficient exactly. These are representative integration replays. The
220-workload timing/allocation study remains tied to its original measured
snapshot; it was not rerun after this merge.

The integration source archive is `source-integration.tar`, SHA-256
`ae66c9df58d12033107193352819ce758680ac00ca2dd5a12ffec4e769ad5dd5`.
The source archive, manifests, Slurm/worker receipts and complete logs identify
the tested integration independently of later reporting edits.

## Pre-merge review followup

The self-review in [REVIEW.md](REVIEW.md) found and fixed overflow of the hybrid
trial-budget expression for extreme positive sweep counts. Three new assertions
check both the integer limits and unchanged ordinary parameter behavior.
Discovery job `13456761` (2 CPUs, 8 GB, five-minute allowance) completed in
56 seconds. Both Julia versions passed all 899 focused assertions. The existing
full-suite and benchmark receipts remain applicable to their recorded snapshots;
no full benchmark rerun is claimed for this boundary-arithmetic fix.

Including this review followup, total task allocation-active time is **2,713
seconds (45 minutes 13 seconds)**. The earlier total above describes the study
through master integration. All failures and earlier source snapshots remain
preserved. The review patch archive and hash identify the additionally tested
implementation.
