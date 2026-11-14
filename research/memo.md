## #311 decision memo: a scheduling-only fix for CD's active-set stall

> **Correction (2026-11-14).** Earlier versions of this memo said CW20 "cannot add more than 5% coordinate work to any run" compared with master. That is wrong. A forced full pass visits p coordinates after active passes that together made at least 20·p visits, so the forced passes of a run make at most 1/20 of that run's active-pass visits. A forced pass also changes the iterates that follow, though, so this does not bound the run's total work against master. The measurements show it: CW10's worst run made 1.149× master's visits, above its 1/10. The two sentences are corrected below (§3 and §5). Cluster details were also generalized. The implementation is PR #313.

Base: master `eb3332f`, which includes #295, #293 and #294. No production code changed and no PR opened.
- Candidates live on disposable local commits.
- Runs: Julia 1.10.13 and 1.13.3 locally (i5-13600K), and Julia **1.10.12 and 1.13.3** on a cluster (Slurm; AMD EPYC 7513).
- Accuracy oracle: an independent BigFloat-256 KKT and objective computed from the raw data.

### 1. Root cause (confirmed): starvation of zero coordinates

This is a scheduling problem, not a problem with the proximal arithmetic or the curvature.

The issue's fixture: §18 Float32 reciprocal case, warm start, random order, `momentum=false`, `tol=1e-7`, `--code-coverage=user`. Master's trace, identical on all four Julia/CPU combinations:

| pass | kind | active set | x |
|---|---|---|---|
| 1 | full | {2} | (0, −2181814.2, 0) |
| 2–2000 | active | {2} | alternates −2181813.2 ↔ −2181814.2 |

- **The dither.** Coordinate 2 moves 1.0 coefficient unit every pass, which is 4 ulp of x. Its change threshold is 0.675 units, so `maxchange/tol` is 1.48 on every pass, and the full pass that would revisit the zero coordinates never runs.
- **Where the violation sits.** Coordinates 1 and 3 are held at 0 with |αX_kᵀr|/λ = 1.38 and 1.41. They carry the whole KKT violation of 0.204, while coordinate 2's own violation is 9e-8. The BigFloat minimizer has all three coordinates nonzero.
- **The arithmetic is correct.**
  - Each Float32 step, replayed, is within 1.6 ulp of the exact BigFloat soft-threshold step from the same Float32 state.
  - Every a_k is within 1 ulp of its exact value.
- **Restart and looser tolerance.** A restart from the stalled point converges in 18 passes (KKT 9.9e-8). With `tol=1e-6` the run converges in 19 passes.

**Not only under coverage.** Seed scan of the fixture, 500 seeds × 32 configurations per build:

| build | stalls in warm, `momentum=false`, 0.5 λmax | other configurations |
|---|---|---|
| coverage, both versions | 356 / 1000 | 0 |
| Julia 1.10.12, EPYC 7513, **no coverage** | 191 / 1000 | 0 |
| Julia 1.13.3 and local, no coverage | 0 | 0 |

The stall depends on how the column sums are rounded: SIMD order and code generation.

**Deterministic, CPU-independent case.** With 2 rows, every column sum has two terms, so the result does not depend on summation order. With cyclic order the runs are bit-identical on 1.10 and 1.13, with and without coverage. Master ends at maxpasses in 15 of the first 846 random draws, in two classes:
- **(a) Starvation, 9 draws.** Master's KKT is 1e-5 to 1.1.
  - Seed 598: the BigFloat minimizer is x = (0, 0, 0.1579). Master stops at (0, −0.2249, 0) with KKT 0.20; coordinate 3 is never visited.
- **(b) Dither at the solution, 6 draws.** Master's KKT is already 6e-8 to 2e-6, because the full set itself dithers above `tol`.
  - No schedule helps here: every candidate ends honestly at maxpasses with the same KKT. This is the documented-limitation case, not part of the fix.

### 2. Candidates and results on the reproducer

I tested three simple fixed intervals:
- **C50:** force a full pass after 50 consecutive active passes.
- **CW10 / CW20:** force a full pass once the active passes since the last full pass have visited 10·p / 20·p coordinates, that is, 10 / 20 full passes' worth of work.

What stays the same: coordinate updates, prox, tolerances and kernels; no options, fields or numerical state are added. Only a converged full pass stops, so `converged=true` keeps its meaning.

**#311 reproducer** (coverage; dense and owner; identical on 1.10.12 and 1.13.3):

| | converged | passes (full/active) | KKT | rel. objective gap |
|---|---|---|---|---|
| master | false | 2000 (1/1999) | **2.04e-1** | 2.6e-2 |
| C50 | true | 71 (4/67) | 1.9e-7 | 8e-15 |
| CW10 | true | 50 (4/46) | 1.9e-7 | 8e-15 |
| **CW20** | true | 81 (4/77) | 1.9e-7 | 8e-15 |

The other 11 start/order/storage combinations are unchanged under every candidate.

**Seed scans.** Every master stall above (356 per coverage build and 191 on 1.10.12 without coverage) drops to 0 under every candidate. The worst KKT among converged runs is unchanged (≤ 3.1e-7). CW20 needs at most 104 passes.

**Tiny seed 598.** CW20 converges in 60 passes with KKT 5.4e-7, at the BigFloat minimizer.

**Existing tests.**
- The standard tier passes on CW20 with coverage: 39,498 tests on 1.13.3.
- I removed §18's Float32 workaround (`tol32 = 1e-6` → `1e-7`) and ran with coverage. Master fails 4 tests, on both 1.10 and 1.13, which is the original CI failure. CW20 passes all 436.

### 3. Performance and allocations

**Coordinate visits (deterministic, proportional to time).** 392 runs per schedule:
- 7 designs: core-lasso, B, C, D, explore, plus 2 stress designs with long active phases and p ≫ |A|.
- Float32 and Float64; cold and warm starts; 2 tolerances.
- Orders: cyclic, random with momentum (3 seeds), random without momentum (3 seeds).

| | runs changed | total visits vs master (1.13 / 1.10) | worst single run (1.13 / 1.10) | not converged | KKT > 10× master |
|---|---|---|---|---|---|
| C50 | 99 / 95 | 0.62 / 0.52 | **1.50 / 1.34** | 0 | 0 |
| CW10 | 28 / 24 | 0.80 / 0.69 | 1.095 / 1.149 | 0 | 0 |
| **CW20** | 12 / 13 | 0.89 / 0.76 | **1.034 / 1.000** | 0 | 0 |

- On the 5 ordinary designs every run is bit-identical to master under all three candidates, because the forced pass never fires.
- C50's cost per forced pass is p/|A| active passes, so its overhead is unbounded. On a stress run it does 1.50× the work in the same number of passes.
- CW-K bounds the cost of its own forced passes: each costs at most 1/K of the active-pass visits before it, so the forced passes of a run make at most 1/K (5% for CW20) of that run's active-pass visits. This is not a bound on total work against master, because a forced pass changes the later iterates. CW10's worst run made 1.149× master's visits, and CW20's worst made 1.034× (1.13) and 1.000× (1.10).

**Wall time, cluster (Slurm).** AMD EPYC 7513; fresh process per tree; rotated rounds; A/A = master against master. The queue estimate for exclusive nodes was 10–13 h, so these ran on shared nodes. Geometric mean of the per-case time ratio vs master:

| | 1.13.3, ordinary (60 cases) | 1.13.3, stress (24) | 1.10.12, ordinary, re-run* | 1.10.12, stress |
|---|---|---|---|---|
| A/A | 0.997 | 1.001 | 0.978 | 1.000 |
| C50 | 0.995 | 0.777 | 0.996 | 0.777 |
| CW10 | 1.001 | 0.945 | 0.994 | 0.955 |
| **CW20** | **1.001** (no case > 5%) | **0.998** | **0.979** | **0.999** |

\*The first 1.10.12 run showed CW20 at 1.045 on the ordinary cases, concentrated in 5–9 µs core-lasso solves, on a node where A/A varied ±6% from round to round. CW20 does exactly the same passes and visits there. A focused re-run (one core per process, 101 samples, 12 rounds) gave 0.979 against an A/A of 0.978, so I treat the first result as noise, not a reproducible slowdown.
- Caveat: per-case resolution of µs-scale solves on a shared 1.10 node is about ±15%. An exclusive-node run would settle individual cases if you want it.

**Allocations.**
- Master, C50, CW10 and CW20 all allocate 0 bytes per full pass and per active pass, in F32 and F64, cyclic and random, with and without momentum.
- Bytes per solve are the same for `maxpasses` = 10 and 1000.

### 4. Proposed code change (CW20)

`src/cd/solver.jl`, the only source change:

```diff
 # After each pass, the strict change test `maxh < tol` selects the next pass:
 # full after a converged pass, active otherwise. Only a converged full pass stops.
+# A full pass is the only one that visits the coordinates at 0, so one also follows
+# active passes that together visited `_FULL_PASS_WORK` times as many coordinates as a
+# full pass: active passes whose changes stay above `tol` through rounding alone
+# (Float32 steps near the tolerance, #311) then cannot keep a coordinate at 0 from being
+# visited again. (Corrected: the forced passes make at most 1/_FULL_PASS_WORK of the
+# run's active-pass visits; this does not bound total work against master.)
+const _FULL_PASS_WORK = 20
 function _cd_plain!(x, m, g, st::_CDState{T}, s::CDSolver) where {T}
   ...
-  converged = true
+  converged, visits = true, 0
   for pass in 1:s.maxpasses
-    full = converged
+    full = converged || visits >= _FULL_PASS_WORK * ncoordinates(x)
+    visits = full ? 0 : visits + nactive(x)
     maxh = _pass!(x, m, g, st, full, scaled)
```

`_cd_momentum!` gets the same three changed lines. A forced full pass resets the momentum history exactly as any full pass does today. (Added at approval: a forced full pass in `_cd_momentum!` first gets the cache refresh `_momentum_refresh!` that an ordinary full pass gets after its converged active pass. The final code is in PR #313.)

**Tests.**
- **§18:** revert the `tol32 = 1e-6` workaround to `1e-7` and replace the stall paragraph in its comment.
- **New deterministic regression test** from seed 598, with literal Float32 data:
  - `X = reshape(Float32[0.1623875f0, 0.3975033f0, 0.38066474f0, 1.0014724f0, 0.031295117f0, -2.3836505f0], 2, 3)`
  - `y = Float32[-1.0195396f0, -0.7663379f0]`, `λ = 0.89738756f0`
  - `x0 = Float32[-0.46727893f0, -3.7358327f0, -2.9755993f0]`
  - Raw least squares; cyclic order; `momentum=false`; `tol=1e-7`; `maxpasses=2000`; dense and owner.
  - Assert `converged`, passes < 2000, and BigFloat KKT ≤ `kkt_tolerance(Float32)`.
  - Master fails it on every CPU.

**Docs.** One sentence in the `CDSolver` docstring, next to `maxpasses`: after active passes worth 20 full passes, CD runs a full pass even if the active changes have not met `tol`.

### 5. Recommendation

**Implement CW20.**
- It is a two-line scheduling change in each CD loop.
- It removes the #311 starvation in every reproduction: the issue fixture, the coverage and 1.10.12 seed scans (every stall → 0), and the deterministic tiny case.
- It is bit-identical on every ordinary design.
- Its forced passes make at most 5% of a run's active-pass visits. That bounds what the schedule itself adds along a trajectory, not total work against master, since a forced pass changes the later iterates. Measured on the 392-run grid, its worst run made 1.034× master's visits (1.13) and 1.000× (1.10). On long active phases it often reduces work.
- It shows no measurable wall-time cost on 1.13.3 or 1.10.12.

**Document the limitations rather than fixing them here.**
1. **Class (b).** When `tol` is at the Float32 rounding level of the coefficients, the full set can itself dither above `tol`. CD then ends honestly at `maxpasses`, usually with a small KKT, and the remedy is a looser `tol`. The tiny-problem class (b) shows this.
2. **Escape latency.** The forced pass comes after 20·p/|A| active passes. At the default `maxpasses = 100_000`, a starved run escapes when p/|A| ≤ 5000. Beyond that it still ends honestly at `maxpasses`.

**Observed, out of scope.** C50 reduces work substantially on long active phases (stress designs: about 0.54–0.77× the visits and 0.78× the time). Some cold ρ = 0.95 runs that hit 1000 passes on master converge in about 400 under C50. Its per-run cost is unbounded, though, so I do not propose it. If faster CD on such problems is wanted, it belongs in a separate issue.

**Evidence.** Probes, raw logs and summaries are archived on the pinned evidence branch `archive/issue-311-evidence` (see the link in the comment below this memo).
- `research/probes/`: repro, diagnosis, seed scan, tiny case, work counts, timing, allocations.
- `research/results/cluster/RUN.md`: commits, job IDs, and the deviation to shared nodes.
