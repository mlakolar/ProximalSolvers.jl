# Comparison with libslope

This note compares the implemented `SLOPEHybrid()` with the specialist C++
libslope hybrid. It separates source-level differences from the bounded
Discovery measurements. The comparator is libslope **6.5.2**, commit
`a9899cbf3677ea63236d54dc18626ad3a5aeddc6`. The [earlier source audit](../REPORT.md#what-libslope-actually-does-source-audit-2026-10-26)
also checked the basic hybrid loop and solver factory in 6.5.4. Neither audit
establishes which implementation is globally fastest or describes every later
release.

## Algorithm and workspace

Both methods follow the PG-plus-cluster approach of
[Larsson et al. (2023)](https://proceedings.mlr.press/v206/larsson23a.html).
A proximal-gradient step can split tied magnitudes and activate zero
coefficients. Cluster-coordinate sweeps optimize one signed group magnitude
with the other groups fixed. The sorted penalty's weights belong to ranks;
updates may cross ranks, merge groups or reverse a group's signs. This is a
conditional scalar minimization, not a joint exact solve of all clusters.

| Aspect | `SLOPEHybrid()` | Pinned libslope hybrid |
|---|---|---|
| Cycle | One unaccelerated PG step, then up to ten CD sweeps by default | Same basic schedule |
| Membership and ranks | Arrays and linked membership reused across sweeps and path levels; memberships rebuilt after PG; incremental relocation/merging within a CD block | Clusters constructed after PG and maintained incrementally within the CD block; local rank-threshold searches |
| Signed columns | At most 32 cached columns and curvatures; dense and CSC accumulation kernels; generic column restriction for implicit matrices | Specialized singleton updates and a sparse workspace that tracks touched entries |
| Traversal | Deterministic current-rank traversal, saved at the start of each sweep | Permuted traversal in this benchmark; selectable in the library |
| Rejected updates | Restore the entire CD block to the preceding PG point and permanently switch that reduced solve to APG | Restore the preceding sweep, retain earlier accepted sweeps and end that CD block; PG/CD is tried again on the next outer call |
| Slow finite progress | Two cycles without a 20% fixed-point residual reduction trigger APG; a bounded trial reserves at least half the remaining iteration allowance | No permanent slow-progress APG switch in the audited loop |
| Screening and checks | Shared SLOPE strong screening, full fixed-point checks and working-set repairs | Specialist strong screening, working-set repairs and gap checks |
| Selection | Explicit opt-in; existing APG choice retained | `auto` selects hybrid without estimating predictor correlation |

Dense cache capacity is `n * min(p, 32)` entries, including for sparse inputs.
It can hold every group in a small problem. Cached values are refreshed after
PG and invalidated by relevant membership/sign changes; their storage is reused
across path levels. This bounds the dense cache independently of larger cluster
counts. Reused buffers do not make the complete Julia fit allocation free. The native implementation also allocates: for example, its audited loop
creates working arrays and snapshots cluster/residual/coefficient state before
each sweep. A source inspection alone does not quantify their total cost.

Primary sources at the benchmarked commit:
[solver selection](https://github.com/jolars/libslope/blob/a9899cbf3677ea63236d54dc18626ad3a5aeddc6/src/slope/solvers/setup_solver.cpp),
[PG/CD loop and rollback](https://github.com/jolars/libslope/blob/a9899cbf3677ea63236d54dc18626ad3a5aeddc6/include/slope/solvers/hybrid.h),
[CD implementation](https://github.com/jolars/libslope/blob/a9899cbf3677ea63236d54dc18626ad3a5aeddc6/include/slope/solvers/hybrid_cd.h),
and [path implementation](https://github.com/jolars/libslope/blob/a9899cbf3677ea63236d54dc18626ad3a5aeddc6/include/slope/slope.h).

Our public option currently covers single-response least-squares SLOPE,
optionally scaled. It does not add other losses or a general cluster solver for
other penalties. Data preparation and statistical calibration remain in the
model layer.

## What the timing study supports

[RESULTS.md](RESULTS.md) contains all strata; [README.md](README.md) fixes the
protocol and [RUN.md](RUN.md) identifies sources, jobs and validation. The study
uses 220 workloads, three warm timing blocks per method, identical inputs,
weights and alpha grids, and one thread. Every requested level must pass both
an independent feasible dual-gap target of `1e-6` and a full normalized
fixed-point residual target of `1e-7`. Timed native output conversion is included;
fixture preparation, CSC index conversion, certification and allocation replay
are outside the timed fit. Backend and wrapper differences are part of this
implementation comparison; it does not isolate the effect of the APG fallback
with an ablation study.

For these confirmation strata, both comparisons have identical eligible
workload coverage. Each entry is the median of per-case time ratios against the
same screened APG baseline:

| Workloads | Eligible cases, each comparison | Our hybrid/APG | Native hybrid/APG |
|---|---:|---:|---:|
| Original correlated dense, rho=.99 | 16/16 | 0.715 | 2.737 |
| Larger independent dense | 4/4 | 1.015 | 1.636 |
| Larger correlated sparse, rho=.9 | 4/4 | 1.031 | 1.683 |

These are baseline-relative summaries. Dividing two reported medians does not
give the median direct Julia/native speedup. Rows with different certified
subsets, such as the larger rho=.99 dense cohort, also cannot be treated as
an identical-case comparison without filtering the raw records first.

The Julia hybrid and APG each pass the common targets on 660/660 requested fits.
Six APG fits retain false flags for the stricter internal target. Native libslope
passes on 612/660 fits under its uniformly selected native tolerance and soft
10-second path cap; three requested native levels were not returned. All
inaccurate/truncated paths and allocation-replay diagnostics remain visible.
These outcomes do not establish that libslope cannot converge with more time
or a different internal tolerance. The methods have different stopping rules
and iteration units. Uncertified fits do not count as timing wins.

The useful regime demonstrated against APG is correlated dense least squares:
on larger confirmation cases, hybrid/APG time ratios are 0.491 at rho=.9 and
0.322 at rho=.99. Sparse and independent controls do not show a consistent
benefit. This supports an explicit option rather than changing the default.

The timing/allocation study is tied to the recorded pre-integration source
snapshot. The later master/APG-state integration passed a fresh full suite and
eight representative fits reproduced saved coefficients exactly. The complete
220-workload timing study was not rerun after integration or the later review
fix for extreme sweep-count arithmetic. The review fix leaves the default
trial budget unchanged.

## Allocations and process memory

The overall confirmation median hybrid/APG Julia allocation ratio is **1.239**.
Thus fewer temporary bytes is a benefit in some correlated dense strata, not
an overall property. A warmed cluster-column kernel and a complete path fit
have different allocation scopes.

The native replay counter measures requested bytes/calls from wrapped
static-library allocators and C++ `new`; allocations internal to dynamic
libraries are excluded. Julia's counter measures GC allocation bytes and
includes Julia bridge/output buffers. In particular, the small native bridge
GC count is not the native solver's heap traffic. The report keeps the counters
separate and asserts no cross-runtime heap-byte ratio. Allocation traffic also
differs from live memory and peak RSS.

RSS includes startup, imports, compilation, fixture creation, warm-up and a
repeated fit in a separate process. It shows no Julia hybrid memory reduction
in the four measured cases. Native RSS was lower on the certified small-case
checks. Native fits that fail the common targets, including in the uniformly
tighter RSS-only followup, cannot support matched-accuracy memory conclusions.
The bounded study establishes neither a universal memory advantage nor
statistical FDR guarantees.

The Julia block objective guard allows roundoff slack of
`10 * eps(eltype(x)) * max(1, abs(objective_before))`. The audited native loop
checks each sweep with a strict floating-point objective comparison. The two
rollback policies therefore differ in both granularity and roundoff treatment.
