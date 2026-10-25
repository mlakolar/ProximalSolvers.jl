# Focused APG path-state reuse comparison

This follow-up to #57/PR #90 isolates APG path handoffs before deciding whether
the large-path libslope advantage motivates a hybrid cluster-coordinate
prototype. Everything is benchmark-only; production solver code is unchanged.

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

The main grid has 720 paths / 8,640 points; confirmation has 288 / 3,456.
Checks cover cached values/images after penalty changes, equality to the
original reset trajectory, carried L values, known orthogonal optima and failed
path truncation. No Julia execution runs on the local Mac.

## Focused decision

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
