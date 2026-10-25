# First-order controls and APG profiling

This benchmark asks which parts of the SLOPE timing gap come from solver choice,
screening and APG work. Matching libslope is not a requirement for retaining a
correct, useful generic solver. A hybrid is deferred unless it adds useful
capability beyond chasing the specialist's runtime. No production code changes.

## Protocol fixed before execution

Use the same pinned Julia 1.13.2 / ProximalBase 1f93b03 / SLOPE.jl 1.3.1 /
slope_jll 6.5.2+0 environment. The installed artifact contains libslope's headers
and static library. `bridge.cpp` exposes its PGD, FISTA and hybrid solvers, each
with screening `none` or `strong`; all other fit settings match the original
Julia adapter. Strong rules retain the library's KKT checks. A bridge hybrid /
strong control is compared to the existing SLOPE.jl adapter to reveal bridge or
build differences. The bridge's templated path code is compiled with GCC 13.3,
Eigen 3.4, `-O3 -DNDEBUG -std=c++17 -fPIC -shared -fopenmp`; linked implementation
code comes from the unchanged artifact. Do not interpret a bridge change as
purely an algorithm effect.

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
