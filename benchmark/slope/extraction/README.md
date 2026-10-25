# Extracted screened SLOPE APG engine

The screened path driver belongs in ProximalSolvers. HighDimensionalModels
(currently named CoordinateDescent on PR #84's branch) prepares data and weights,
recovers intercepts and coefficient units, and provides statistical model results.
It calls `SLOPEAPG`, `solve!`, `solve_path` and `lambda_max` from ProximalSolvers.
The cluster-coordinate hybrid remains deferred.

## Discovery extraction comparison

The old HDM driver is frozen verbatim from `95993030f5fa34b01364dcdf9eebf42a4eab15ba`
in `legacy_slope_9599303.jl` as a benchmark fixture. It is not a second runtime
implementation. Compare it with the new numerical driver and the thin HDM wrapper:

- Final PS engine commit `335ea905da207a6cc1cd3bd945bb7bbbf9f4eba4`.
- HDM integration commit `307753be26f739282658db45369b02d43d3c2399`.
- The same current inner APG, ProximalBase `1f93b03c9c4652636ab0f173e6027268d877aa3a`,
  Julia 1.13.2 and one BLAS thread for all three backends on AMD EPYC 7313
  (`b11-09`, Discovery debug partition). This isolates the driver
  extraction; it does not compare the complete historical dependency environment.
- Dense n=320, p=640; seeds 1–3, rho=0/.9; raw data or centering plus nontrivial
  rescaling/standardization/intercept; BH weights, 12 identical positive path
  factors ending at .15 of the null threshold. No statistical FDR claim.
- Three fresh processes, each with three randomized complete timing blocks per
  case. Each backend is warmed before timing; compilation and final checks are
  excluded. Timing includes model preprocessing for the old and new wrappers;
  the direct engine receives prepared data and excludes model preprocessing.
- Every result is checked against the old driver for coefficients, fitted values,
  iterations, convergence flags, working-set sizes and repair counts. A separately
  evaluated full proximal residual divided by `max(1,norm(X'y/n,Inf))` must be at
  most 1e-7. This is a fixed-point criterion, distinct from the independent duality
  gap used in earlier specialist comparisons.

All **324/324 paths and 3,888/3,888 levels** passed. Coefficient and fitted-value
differences were exactly zero, and all checked diagnostics were identical.
Maximum normalized full residual was **8.43e-8**. The three processes each passed
612 assertions. These checks cover this workload; nonunique problems should also
be assessed through predictions/objectives rather than coefficient equality.

Median paired new-wrapper/old-wrapper time (27 pairs per stratum):

| rho | Center and standardize | Time ratio | Julia allocated-byte ratio |
|---:|:---|---:|---:|
| 0 | no | 0.878 | 0.539 |
| 0 | yes | 0.847 | 0.539 |
| .9 | no | 0.851 | 0.188 |
| .9 | yes | 0.896 | 0.188 |

The extraction avoids copying the full design for a full working set and avoids
redundant initial-gradient work. It shows no regression here and reduces observed
end-to-end time by about 10–15%. The direct-engine/old-wrapper ratios .661–.845
exclude model preprocessing from the direct call and are not an end-to-end solver
comparison. Julia allocation bytes are not peak RSS. Sparse accuracy, process RSS
and comparisons to SLOPE.jl/R belong to the coordinated PR #84 campaign, not this
small dense extraction comparison. Earlier benchmark conclusions are unchanged.

## Validation, failures and recreation

All numerical work ran under Discovery Slurm, run
`20261025T1210Z-ps-slope-extract`:

- Initial canary 13424016 exited after 2 seconds on test syntax `.8.*`; retained.
- Recovery 13424019 ran 43 seconds: **50/50 numerical engine assertions passed
  Julia 1.13.2**. Its subsequent Julia 1.10 command failed before testing because
  the copied 1.13 environment selected incompatible PrecompileTools (`StaticData`
  undefined). This is retained as an environment failure, not a passed LTS check.
  Final checks use PR #84's compatible Julia 1.10 environment.
- Benchmark 13424032 completed in **1m46s**, all three worker exit codes/signals zero.
  Steps were serialized by Slurm; each timing used one CPU/BLAS thread. Peak request
  two CPUs/4GB. Initial-phase allocation time including failures **2m31s**; overlapping
  tasks count once in the shared run budget.
- Final API checks 13424116 completed in **1m14s**: **53/53 assertions on both
  Julia 1.13.2 and 1.10.12**. This includes three additional input-contract checks.
- Final frozen-API benchmark 13424137 completed in **1m28s**: all 324 paths,
  3,888 levels and 1,836 assertions passed; all worker exit codes/signals zero.
  Both jobs used one CPU/2GB on EPYC 7313. Main was saturated by unrelated jobs;
  only these pending jobs were moved to the documented short debug/testing
  partition, keeping job QoS, requested resources and dependency unchanged.
  No unrelated jobs were changed. Total owned allocation time across all attempts
  **5m13s**.

The first successful comparison (engine `ffdc26c`, EPYC 7513, job 13424032)
remains in the top-level evidence tables and `summary_before_input_guards.json`.
The final input-guard commit adds an O(p) finite-weight check per level, so the
reported primary timing table was rerun on the exact final API. Its records are
in `evidence/20261025/final/`; `check_results.py` checks both complete cohorts.
Do not combine absolute times across these CPU models or attribute their timing
differences to the input guards.

`evidence/20261025/` contains complete timing rows, process test summaries, worker
outcomes, canary failures and the exact copied Project/Manifest files. Regenerate:

```sh
python3 benchmark/slope/extraction/check_results.py
```

To repeat on Discovery, extract snapshots of the two source commits into `source/`
and `hdm/`, and these harness files into `harness/` under a new run directory.
`prepare.py` rebinds copies of the established HDM comparison environment; it does
not resolve moving dependencies. Supply equivalent paths when recreating elsewhere.
Submit `harness/main.sbatch`; it runs three fresh processes via GNU Parallel/srun.
The compatible pinned environment is recorded in
`evidence/20261025/final/validation/combined-env335/`.
For the primary table, stage PS `335ea90` into `source335/`, then run
`python3 harness/prepare.py "$PWD" --final` and submit
`harness/final_main.sbatch`; the earlier `main.sbatch` and environment reproduce the preserved initial
cohort. The debug partition is documented by
[USC CARC](https://www.carc.usc.edu/user-guides/hpc-systems/discovery/resource-overview-discovery)
for short debugging jobs. These are bounded development validation runs.

The numerical unit suite is `test/slope.jl`; it covers a known orthogonal optimum,
forced screening repairs, finite/invalid inputs, failed-level retention and budget
limits, warm starts, input preservation, snapshot ownership, normalized/unscaled
losses, Float32, dense/sparse and screened/full agreement. The model-layer tests
cover sparse centering/standardization and wrapper delegation.

## Compatibility with concurrent master updates

While the extraction was being validated, HDM master `77a62cd` added calls to
ProximalSolvers #86's `gaptol` path API. Pinning the earlier SLOPE-only snapshot
caused the GitHub merge build to fail before tests. Combined API commit
`36f623a1747dfec6cac964fba8341819685c5146` merges existing PS master `73a1c8e`
into this branch, preserving the new gap-stopping semantics. It also retains
master's policy of tracking ProximalBase master in package/docs/Julia 1.10 CI.

`integration.json` records exact Git blob identity of the SLOPE driver, inner APG,
image models, generic gradient iteration loop and options/results types between
the benchmark snapshot and this merge. No SLOPE numerical source was changed.
The old timing cohorts retain their original dependency snapshots; constructor
and cache changes in newer ProximalBase are not assigned performance claims from
these old measurements. Combined dependency validation is recorded by the
coordinated HDM Discovery run using a separate immutable source/environment.

The subsequent canonical-naming/dependency-bootstrap master `b00e869` is included
in API `3bee2f91604fe08d34a07d45bcc638e3b4face3a`. The SLOPE driver, image models
and generic gradient loop remain byte-identical to the benchmark snapshot; APG
changes only the internal field identifiers `deltaX`/`maxResidual` to snake case.
The default numerical options are unchanged. Current development follows the
new sibling-master bootstrap. The companion HDM feature PR needs a documented,
temporary exact-revision exception until #90 is merged; normal dependencies and
existing checkouts retain master behavior. Historical workers keep their frozen
package names and pins, as allowed by `CONTRIBUTING.md`.
