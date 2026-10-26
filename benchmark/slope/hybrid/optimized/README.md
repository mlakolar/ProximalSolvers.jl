# Opt-in reusable-state SLOPE hybrid

Results are in [RESULTS.md](RESULTS.md); validation and source receipts are in
[RUN.md](RUN.md).

This follow-up to issue #95 implements `SLOPEHybrid()` explicitly. `SLOPEAPG()`
remains the default. The earlier prototype, its failures and its decision report
in the parent directory are historical evidence and remain unchanged.

## Implementation

The shared screened path driver still performs the full optimality check and
working-set repairs. The hybrid reuses arrays for cluster membership, ordering,
ranks and scratch across sweeps and levels. Linked lists permit merging without
allocating coefficient-index sets. Rank-local scalar minimization crosses only
neighboring clusters. Up to 32 signed cluster columns and their curvatures are
cached. Dense and CSC column accumulation have allocation-free kernels; an
implicit matrix must provide efficient products and column restriction.

Each hybrid cycle takes one unaccelerated PG step and up to ten cluster sweeps.
PG can split clusters and activate zeros. Two cycles without a 20% residual
reduction switch that reduced solve permanently to APG. Invalid or increasing
cluster blocks are restored to the preceding PG point and also switch to APG.
A hybrid trial is capped at `min(remaining_budget ÷ 2, 110)` iteration units for
the default sweep count. The remaining budget is available to APG. One unit is
a PG/APG step or a complete cluster sweep. These units have different costs.
Fresh products check the hybrid residual. Fallback reuses APG state and its
established stopping rules, returning control for working-set repairs rather
than exhausting the budget on a restricted fit. The shared driver independently
checks the full residual before declaring convergence. There is no correlation
estimator or promise that the hybrid trial will pay for itself.

This differs from the pinned libslope hybrid, which alternates PG and cluster
sweeps without a permanent slow-progress APG fallback. The native comparator is
the unchanged libslope 6.5.2 source at
[`a9899cb`](https://github.com/jolars/libslope/tree/a9899cbf3677ea63236d54dc18626ad3a5aeddc6).
The prior source audit in `../REPORT.md` records the corresponding control
experiments and the comparison with 6.5.4. No universal fastest-solver claim is
made here.

## Matched comparison protocol

All compilation, tests, fitting, certification and aggregation run on Discovery.
Each worker uses one Julia, BLAS and OpenMP thread on an EPYC 7513 node.
The three methods receive the same matrices, responses, weights and explicit
alpha grids, with no intercept, centering or scaling. Inputs are checked for
mutation. Both Julia methods use the same screened path driver. Native libslope
uses its strong screening, hybrid solver, permuted traversal with seed 95,
cluster updates, and disabled deviance/cluster-count path truncation.

There are 220 workloads:

- The original 160 fixtures: `n=80, p=120`, seeds 1, 2, 3, 11, 12; rho 0 or .99;
  dense or independently masked CSC; 8 or 32 signals; linear or stepped weights;
  6 or 12 path levels. Independent sparse masks weaken the original latent
  correlation, so these sparse cases alone cannot establish performance on
  strongly correlated sparse designs.
- Sixty larger fixtures: `n=600, p=1000`, the same seeds; rho 0, .9 or .99;
  dense AR predictors or CSC predictors sharing row support and a common anchor
  within ten-column blocks; 32 signals; both weight sequences; 12 levels.
  The shared-support sparse construction retains within-block correlation.

Seeds 1–3 form the main cohort; 11–12 are confirmation seeds. Each path is timed
three times with randomized method order within each paired block. All methods
are warmed for both storage types before measurement. GC runs before each fit.
Fixture generation, native CSC index conversion, independent certificates and
native allocation replay are outside the timed fit. CSC values are shared and
zero-based 32-bit index arrays are prepared once per fixture. Returned solution
snapshots and native output conversion are included in the timed fit.

Every requested level must have relative feasible dual gap at most `1e-6` and
null-gradient-normalized full fixed-point residual at most `1e-7`. The gap uses
a dual-feasible scaled residual, independently of either solver's stopping rule.
Julia's internal tolerance is `1e-8`, with 10,000 iteration units per level.
Native tolerance is uniformly `1e-8`, with 20,000 outer passes and a soft
10-second path cap. Internal stopping quantities and iteration units differ;
only the external targets define a certified comparison. Native convergence
flags are unavailable and are recorded as unknown, rather than inferred.
Failures, truncated paths and internal flag failures remain in the evidence.
Timing ratios use per-case medians of three repetitions and require every
repetition of both compared methods to pass the external targets. A stricter
internal Julia flag can remain false when the common external target passes;
those cases are reported explicitly and are eligible for external-accuracy
timing comparisons. This study records PG/APG steps and sweeps, not exact
design-product counts.

## Allocation and memory interpretation

`@timed` records Julia GC allocation bytes, including the bridge's Julia output
buffers. A separate untimed native replay counts requested bytes/calls from
static-library `malloc`, `calloc`, `realloc` and C++ `new` through a task-owned
link wrapper. The pinned library source is unchanged. A 422-byte mixed allocator
probe checks the counter. Replay predictions must agree within
`1e-7 * max(1, norm(y, Inf))`, and replay outputs must pass the same certificates.
Bitwise coefficient equality is inappropriate for this comparison.

Native counts are cumulative allocation traffic, not live heap or RSS. They
exclude allocations internal to dynamically linked libraries and do not form a
complete process allocation profile. Julia and native counters therefore remain
separate. Only the Julia hybrid/APG allocation ratio is directly reported.

Separate processes measure peak RSS for cases 1, 20, 169 and 171 with each
method. Each process warms only its selected method, then fits it again. Peak
RSS includes Julia startup, imports, compilation, fixture construction and both
fits. It is a process footprint, not solver workspace alone. Saved solutions
are certified in a separate process so validation does not inflate that RSS.
The Linux child peak-RSS counter is read with Python `resource.getrusage`;
GNU `time` is not required. The first native RSS fits at tolerance `1e-8`
missed the common residual target in two cases. `rss_native.sbatch` repeats
all four native cases uniformly at `1e-10`; both sets are retained. This
RSS-only followup does not replace the primary timing/allocation protocol.

## Recreate

The run is `20261026-ps95-hybrid-v2` under
`/home1/mkolar/juliaPkg/runs/` on Discovery. Its local lightweight registry is
`.slurm/runs/20261026-ps95-hybrid-v2.json` in the parent Julia workspace.
The recorded source archive includes the uncommitted implementation used for
measurement. `source-sha256.txt` identifies each preserved staging snapshot.
`ProximalBase` is pinned at `b6c949f3dd26cad09252e1c2c9e49810eb69403e`.

`canary.sbatch` builds plain and counted bridges against the existing pinned
native static library and creates the offline Julia environment with `setup.jl`.
`calibrate.sbatch` exercises the corrected canary and tests. `matched.sbatch`
uses GNU Parallel and four exclusive one-CPU `srun` steps for the comparison.
Run `rss.sbatch` after the matched allocation finishes; the two allocations
must not overlap under this task's 16 GB allowance. If reproducing the final
RSS comparison, follow with `rss_native.sbatch`. Stage the complete benchmark
evidence for the integrity checks in `finalize.sbatch`. Then regenerate the summary:

```sh
python3 source/benchmark/slope/hybrid/optimized/summarize.py --input . --output summary.json
python3 source/benchmark/slope/hybrid/optimized/summarize.py --input . --output summary.json --check
```

Use the project Slurm profile and task-scoped SSH transport. The scripts contain
this run's resolved paths and module versions. Preserve failed attempts; rerun
only understood failures within the remaining task budget.
