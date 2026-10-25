# Focused APG path-state reuse comparison

This follow-up to #57/PR #90 isolates APG path handoffs before deciding whether
the large-path libslope advantage motivates a hybrid cluster-coordinate
prototype. Everything is benchmark-only; production solver code is unchanged.
The subsequent [first-order controls/profiling](../first_order/README.md)
supersede the speed-based development recommendation: a hybrid is deferred
unless it adds useful capability beyond matching a specialist's solve time.

## Protocol fixed before measurements

Keep the original problem generator, n=1000/p=2000, AR(1) rho=0/0.9, 10/100
signals, linear/BH weights, and 12-point alpha/alpha_max path from 1 to 0.05.
Use seeds 1--5 and three randomized complete timing blocks, then unused seeds
8--10 and two blocks without retuning. Compare six methods in each block:

| Method | Allocation/cached images | Curvature L | Momentum |
|---|---|---|---|
| reset | new each level | reset to 1 | reset |
| carry_L | new each level | carry | reset |
| workspace_reset | reuse | reset to 1 | reset |
| workspace_L (primary) | reuse | carry | reset |
| full_state (diagnostic) | reuse | carry | carry |
| SLOPE.jl | native path | native path | native path |

The APG updates are the production initial_state/update_state! methods. At a
workspace handoff, x and the loss are unchanged, so f(x) and X*x remain valid.
Refresh g(x) under the new alpha. Reset previous x/image and momentum for the
workspace variants. The full-state variant also refreshes g(x_previous),
preserves its loss/image caches and keeps the production objective-increase
restart. Reuse SLOPE and certificate buffers only in workspace variants. All
paths begin from zero, and nothing carries between independent paths.

Use the same external gap <=1e-6, initially and every ten APG iterations, with
fresh final validation. SLOPE.jl uses the fixed 1e-6 internal tolerance validated
in the previous control. Keep its native path safeguards/settings unchanged.
Time a complete path, including all initial workspace allocation and handoff
work. Exclude GC, warmup and final validation. Retain failures and missing points;
a failed point never seeds the next. Keep the same 10-second soft APG path cap,
20,000 iterations/level and library max_it cap. Native C++ allocations are not
included in Julia bytes. Report iteration/oracle counts and handoff L/k values
to distinguish less work from less allocation.
The backtracking field is the production trial-evaluation counter, not just
the number of step halvings.

The main grid has 720 paths / 8,640 points; confirmation has 288 / 3,456.
Checks cover cached values/images after penalty changes, equality to the
original reset trajectory, carried L values, known orthogonal optima and failed
path truncation. No Julia execution runs on the local Mac.

## Historical focused decision rule

The earlier broad gate remains unchanged and failed. This is a new, narrower
decision for the already identified large correlated path workload. A focused
hybrid benchmark prototype is supported if library success is >=99%, primary
workspace_L success is >=99%, and the median paired workspace_L/library time
is >=3 in rho=0.9 on both main and unused-seed confirmation (>=90% both-valid
pair coverage). Inspect all predeclared reuse variants: if a reliable simple
variant closes the gap below 3x in either stage, defer the hybrid and prioritize
validating that APG path strategy. Never select the fastest variant per instance.
Report all variants, both correlations and failure outcomes. A supported focused
prototype is neither a general solver recommendation nor a claim that cluster
updates, rather than language or other implementation choices, cause the gap.

## Recreate

Reuse the pinned Julia 1.13.2, ProximalBase 1f93b03 and SLOPE.jl 1.3.1 environment
from the preceding run, rebinding this checkout's path in its copied lockfile.
Run all Julia commands under Slurm with one Julia/BLAS/OpenMP thread per worker:

```sh
julia --startup-file=no --project=benchmark/slope benchmark/slope/path_reuse/checks.jl
julia --startup-file=no --project=benchmark/slope benchmark/slope/path_reuse/run.jl \
  --shard 1 --shards 4 --out main
julia --startup-file=no --project=benchmark/slope benchmark/slope/path_reuse/run.jl \
  --seeds 8,9,10 --rounds 2 --shard 1 --shards 4 --out confirmation
```

Run `20261025T0930Z-ps-slope-reuse`, peak four CPUs/16GB. Prior related running
time is 7m29s and counts against the same conservative two-hour task allowance.

## Results and reassessment (2026-10-25)

**Both grids met the historical focused timing gate.** This motivated a
prototype recommendation that is superseded by the capability-oriented framing
above. Curvature/workspace reuse improves allocation substantially
but explains little of the runtime gap. Even the diagnostic full-state handoff
leaves a median ratio above three in both stages. This supersedes the request
for a path-state control; it does not change the earlier failed broad gate or
recommend a public solver.

All **720/720 main paths (8,640 points)** and **288/288 confirmation paths
(3,456 points)** met the common external target. No failed pair is omitted.
The expanded correctness checks passed **146 assertions**, including equality
of cache-only and reset iterates/iteration counts. Exact identities, all shared
alpha grids, complete-path validity, recorded L/k handoffs and reproducible
summaries are checked in Python and CI.

The following are median **paired** whole-path ratios for rho=0.9. Method/reset
below one favors reuse; method/library above one favors SLOPE.jl. Each main row
has 60 pairs across both sparsities and weight shapes; confirmation has 24.
The ratios are separately computed medians, not products of table entries.

| APG handoff | main / reset | main / library | unused seeds / reset | unused seeds / library |
|---|---:|---:|---:|---:|
| reset | 1.000 | 3.336 | 1.000 | 3.659 |
| carry L only | 0.979 | 3.270 | 0.958 | 3.570 |
| reuse workspace/cache, reset L | 0.992 | 3.288 | 0.992 | 3.583 |
| reuse workspace/cache and L (primary) | 0.978 | 3.224 | 0.968 | 3.429 |
| carry full state | 0.958 | 3.123 | 0.950 | 3.295 |

Primary reuse saved **2.2%** main and **3.2%** confirmation paired time; full
state saved **4.2%** and **5.0%**. Median Julia allocations fell about **85.1%**
(3,088,432 to 461,440 bytes main; 3,088,464 to 461,440 confirmation). These are
Julia allocation comparisons within APG, not total memory comparisons to C++.
The primary variant's median iteration counts were 755 versus reset's 755 main,
and 715 versus 725 confirmation. Full state used 735 and 695, respectively.
Carrying L reduced some backtracking, but the main iteration workload remained.

On the independent-design control (rho=0), reuse also did not remove the
library advantage: primary/library ratios were **2.412** main and **2.329**
confirmation; full state **2.399** and **2.365**. Carrying L alone was slightly
slower than reset in these controls (ratios 1.026 and 1.020), so it is not a
universal speed improvement. All detailed sparsity/weight strata remain in
the summaries.

### Interpretation and next step

Use only the contemporaneous paired ratios to assess reuse. This study's reset
driver specializes the numerical loop to APG; the earlier comparison used a
PG/APG driver. Across jobs, driver and machine timing effects also vary. All
120 matching main reset iteration counts equal the preceding APG path counts,
but the reset/library ratio is now 3.336 rather than the earlier 6.358. That
cross-run change is **not attributed to path reuse**. The paired ablation gives
the much smaller 2--5% reuse effects above.

The remaining gap motivated first-order/screening controls and APG profiling;
it does not require a hybrid. The earlier proposal to follow the
[hybrid method of Larsson et al.](https://proceedings.mlr.press/v206/larsson23a.html)
is deferred unless it adds useful capability. If such a use case emerges,
compare a benchmark prototype with workspace_L, full_state and SLOPE.jl at the
same external target, isolate screening and retain a full certificate. No
hybrid implementation or native-hybrid speed claim is made by this PR.

### Evidence and recreation

[Evidence](evidence/20261025) retains both grids, three summaries per stage,
the clean 146-check output, launchers and provenance. Regenerate using:

```sh
python3 benchmark/slope/path_reuse/check_summary.py
python3 benchmark/slope/path_reuse/check_evidence.py
```

Discovery jobs **13423208** (canary, 1m58s), **13423213** (main, 1m26s) and
**13423214** (confirmation, 41s) all completed. This follow-up used **4m05s**;
including the preceding evaluation, related running time is **11m34s**, peak
four CPUs/16GB and one Julia/BLAS/OpenMP thread per worker. Canary checks passed
143 assertions; the main job added three checks and passed 146. Numerical
source was `5b1b751`; main/confirmation assembly `f8ba6a0` only added checks.
The pinned environment and production solver sources are unchanged.
