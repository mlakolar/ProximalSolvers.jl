# First-order controls and APG profiling

This benchmark asks which parts of the SLOPE timing gap come from solver choice,
screening and APG work. Matching libslope is not a requirement for retaining a
correct, useful generic solver. A hybrid is deferred unless it adds useful
capability beyond chasing the specialist's runtime. No production code changes.

## Protocol fixed before execution

Use the same pinned Julia 1.13.2 / ProximalBase 1f93b03 / SLOPE.jl 1.3.1 /
slope_jll 6.5.2+0 environment. `bridge.cpp` exposes PGD, FISTA and hybrid solvers from
libslope v6.5.2, source commit a9899cbf3677ea63236d54dc18626ad3a5aeddc6, each
with screening `none` or `strong`; all other fit settings match the original
Julia adapter. Strong rules retain the library's KKT checks. A bridge hybrid /
strong control is compared to the existing SLOPE.jl adapter to reveal bridge or
build differences. The bridge's templated path code is compiled with GCC 13.3,
Eigen 3.4, `-O3 -DNDEBUG -std=c++17 -fPIC -shared -fopenmp`. Its implementation is
rebuilt consistently from the pinned source, with hidden symbols / symbolic
binding to isolate it from the separately loaded Julia artifact. The first
canary linking against the artifact static library crashed during native fitting;
that failed attempt is retained. Do not interpret bridge/build differences as
purely algorithm effects.

Compare these six native controls with existing SLOPE.jl and APG workspace/L
reuse. Every independent path starts from zero; all use the same 12 alphas from
alpha_max to .05 alpha_max, n=1000, p=2000, AR(1) rho=0/.9, 10/100 true nonzeros,
linear/BH weights. Main seeds 1–3, three randomized complete timing blocks;
confirmation seeds 11–12, two blocks. Both internal library tolerances and the
independent final certificate target are 1e-6. Max 20,000 iterations per level;
10-second soft whole-path caps. Native interruption is checked every 100 outer
iterations, so caps and iteration units are not identical. Hybrid passes include
inner cluster sweeps, whereas the exposed pass count records outer passes.
Report uncertified/truncated paths as failures, not speed wins. Final validation
is outside all timings; APG's independent stopping certificates remain inside
its timed loop, while native methods use library stopping.

For the main grid, additionally time three paired plain/instrumented APG paths
per case after the comparison blocks. Phase timers mirror the unchanged APG
kernels and split gradient/value, proximal operator, trial loss, remaining update
work, certificate, setup/handoff and remaining path bookkeeping. Every instrumented
path must reproduce the plain iterates and all oracle/iteration/restart counters
exactly. Report instrumentation overhead; these are phase measurements, not a
claim that the timers are free. The certificate phase includes full matrix
products and sorted dual-norm checks. Native pass counts are not compared as if
they were APG iterations. Julia allocation bytes do not include C++ allocations.

Run a short canary with known orthogonal solutions, unchanged inputs, bridge
controls and exact profiler replays before the main study. All numerical work
and bridge compilation run in Slurm on Discovery, one thread per worker, four
workers / 16GB maximum. Results and a recreation recipe will be retained.

The purpose is diagnostic and capability-oriented. There is no runtime-ratio
gate for adding a hybrid. A native hybrid would need a concrete useful workload
or algorithmic capability, a maintainable API and correctness validation.

## Results (2026-10-25)

**Keep the generic APG implementation and defer a native hybrid.** The specialist
gap is not an acceptance failure for a collection of useful implementations.
Screening is a major measured contributor, while the APG profile is dominated by
full-problem gradient and trial-loss evaluations. A future hybrid needs a useful
capability or concrete workload and a maintainable implementation, rather than
a requirement to match libslope's solve time.

The main grid contains 576 requested paths / 6,912 points; 552 paths / 6,855
points were certified. Unused-seed confirmation contains 256 paths / 3,072
points; 244 paths / 3,041 points were certified. **All 36 failed paths were
unscreened native FISTA at rho=.9**, with elapsed times 10.015--10.403s around the
10-second soft cap. Other methods, including every APG path, had 100% success.
The smaller canary certified 32/32 paths / 384/384 points. Across all stages:
**828/864 paths and 10,280/10,368 requested points certified**; failures and missing
points are retained, not treated as speed wins.

For correlated designs, each row below reports median **paired method/APG
whole-path time**, with APG workspace/L reuse as the reference. Lower favors
the native method. Main has 36 requested pairs per method, confirmation 16.

| Method | Main / APG | Unused seeds / APG | Certified main / confirmation |
|---|---:|---:|---:|
| APG workspace/L reuse | 1.000 | 1.000 | 36/36, 16/16 |
| SLOPE.jl adapter (artifact hybrid/strong) | 0.288 | 0.271 | 36/36, 16/16 |
| Native PGD, no screening | 6.296 | 6.935 | 36/36, 16/16 |
| Native PGD, strong screening | 0.286 | 0.291 | 36/36, 16/16 |
| Native FISTA, no screening | not representative | not representative | 12/36, 4/16 |
| Native FISTA, strong screening | 0.637 | 0.837 | 36/36, 16/16 |
| Native hybrid, no screening | 0.601 | 0.629 | 36/36, 16/16 |
| Native hybrid, strong screening | 0.209 | 0.187 | 36/36, 16/16 |

Unscreened FISTA's conditional timings on successful pairs remain in the raw
summaries, with all pair outcomes; they are not a representative aggregate
comparison. This is a finding about the pinned implementation and this path
protocol, not about FISTA as an algorithm class.

### What the controls isolate

Within the consistently rebuilt native implementation, strong/no-screening
ratios for PGD are **0.0521 main / 0.0519 confirmation** on rho=.9: about 95%
less time. Corresponding hybrid ratios are **0.368 / 0.315**. Thus screening
alone is a large contributor, and the hybrid retains an additional useful
advantage in this specialized workload. Screened PGD is already close to the
existing SLOPE.jl adapter (PGD/adapter **1.098 / 1.043**), despite having no cluster
sweeps. This does not mean that all of the APG/adapter gap is caused by screening.

**Build/interface effects are material:** rebuilt native hybrid/strong divided
by the existing adapter is **0.705 / 0.674**. Therefore use within-native-build
comparisons to assess solver and screening choices. Do not interpret a cross-build
ratio as a pure algorithm effect or evidence that C++ is faster than Julia.
The current APG/adapter ratios, computed directly, are 3.509/4.154; these are
different draws/timing blocks from the preceding reuse study. Ratios are
separately computed medians and need not multiply or be exact reciprocals.

The independent-design control points in the same direction: native no-screen
PGD/APG **1.666 / 1.715**, FISTA/APG **4.093 / 4.263**, all certified. Native
strong/no-screen ratios are PGD **0.124 / 0.139**, FISTA **0.064 / 0.070**, hybrid
**0.423 / 0.431**. These controls support retaining generic APG as a useful
first-order method, while preserving the specialist as a performance reference.
Native first-order methods use their library's stopping machinery; our APG
uses its own acceleration/restarts and independent certificates, so this is
not a comparison of identical iteration kernels.

### APG phase profile

All **72 main profile pairs** reproduced the plain iterates and counters exactly
(plus four exact canary pairs). Median instrumented/plain whole-path time was
**1.019** for rho=0 and **1.006** for rho=.9. Percentages below are medians of
per-path time shares and need not add to exactly 100%.

| Phase | Independent design | Correlated design |
|---|---:|---:|
| Gradient and loss value at extrapolated point | 33.8% | 33.2% |
| Trial loss evaluation | 43.0% | 43.3% |
| Sorted-penalty proximal operation | 9.4% | 12.9% |
| Independent stopping certificate | 11.9% | 9.2% |
| Other APG update work | 0.7% | 0.7% |
| Setup and penalty handoff | 0.6% | 0.2% |
| Other path bookkeeping | 0.1% | 0.1% |

Gradient and trial-loss work dominate; the phase timings include their matrix
products. Certificate overhead is real but is too small to explain a 3--4x
runtime gap by itself. On correlated paths the median trial/accepted-iteration
ratio is 1.191 and gradient/accepted-iteration ratio 1.037, so retries are not an
order-of-magnitude workload multiplier. These results prioritize avoiding full
problem work through mathematically valid restrictions/screening or improving
reusable loss kernels if there is a concrete need. They do not establish a
benefit for a new step rule or require a specialized public solver.

### Validation, provenance and recreation

Canary **13423555** passed **100 assertions**: known orthogonal solutions, all
six native controls, unchanged inputs, equal objectives and exact profiler
replays. Main **13423561** and confirmation **13423578** completed with all four
worker exit values and signals zero. Coverage checks enforce exact identities,
shared alpha grids, point/path validity, phase/counter consistency and complete
failure pairing; CI reproduces summaries from raw records.

Initial canary **13423534** failed with a native bridge segmentation fault before
producing comparison records. Its source and failure are recorded; rebuilding
the pinned source consistently resolved the crash. All numerical runs and builds
were under Slurm on Discovery. This follow-up used **9m42s**, including the failed
attempt; **21m16s** including preceding related work, peak four CPUs/16GB. SSH was
closed after transfers.

Numerical source: **2a9a097e01a9067b7f5d52da1fea515094f2bb8e**. Pinned native source:
**a9899cbf3677ea63236d54dc18626ad3a5aeddc6**. Environment versions remain those in
`../evidence/20261025/environment.toml`. Stage this source, copy the preceding
lockfile and rebind only its ProximalSolvers source path. Clone libslope v6.5.2
at the recorded commit; submit `canary.sbatch`, validate, then submit
`main.sbatch` and `confirmation.sbatch` sequentially. The scripts contain the
compiler, resources, one-thread settings and exact worker commands.

Run **20261025T1030Z-ps-slope-first-order**; raw data, complete/failure-aware
summaries, compiler and check output, worker outcomes and provenance are in
[evidence/20261025](evidence/20261025). Reproduce with:

```sh
python3 benchmark/slope/first_order/check_summary.py
python3 benchmark/slope/first_order/check_evidence.py
```
