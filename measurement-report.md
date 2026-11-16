## Three-arm measurement (A, B, C)

**Arms.** A = PS `637f06a` + PB `c123d56` (existing code), B = PS `45da3de` (unchanged PS algorithms) + PB `50db4b1`, C = PS `fd4f552` (migrated) + PB `50db4b1`. Every later commit on this branch changes only documentation and one test comment (`git diff fd4f552 HEAD -- src` is empty), so these results stand for the final source. Each arm: a fresh detached checkout, its own environment and private depot, loaded PB revision and tree read back in every process. Cluster (Slurm), one exclusive node per Julia version, Intel Xeon E5-2640 v4 (the baseline's CPU kind), 1 Julia thread, 1 BLAS thread; Julia 1.10.13 (job 14277245) and 1.13.3 (job 14277246); all steps exited 0. The arm-A/A control is the baseline job (same CPU kind, two separately built copies of A).

### First raw-LS solve (A7) — each solver and precision measured as the first solver call of a fresh process; medians of 10 processes per order and arm, arms interleaved

**Julia 1.10.13**

| solver | T | loss | order | A s | B s | C s | C/A | C/B |
|---|---|---|---|---|---|---|---|---|
| cd | Float32 | raw | raw-scaled | 0.057 | 0.050 | 0.042 | 0.729 | 0.837 |
| cd | Float32 | raw | scaled-raw | 0.057 | 0.049 | 0.041 | 0.724 | 0.841 |
| cd | Float64 | raw | raw-scaled | 0.059 | 0.052 | 0.044 | 0.747 | 0.853 |
| cd | Float64 | raw | scaled-raw | 0.059 | 0.052 | 0.044 | 0.739 | 0.850 |
| pg | Float32 | raw | raw-scaled | 0.364 | 0.364 | 0.199 | 0.548 | 0.547 |
| pg | Float32 | raw | scaled-raw | 0.363 | 0.363 | 0.208 | 0.574 | 0.574 |
| pg | Float64 | raw | raw-scaled | 0.315 | 0.309 | 0.176 | 0.558 | 0.570 |
| pg | Float64 | raw | scaled-raw | 0.308 | 0.308 | 0.176 | 0.570 | 0.569 |
| apg | Float32 | raw | raw-scaled | 0.559 | 0.559 | 0.286 | 0.511 | 0.512 |
| apg | Float32 | raw | scaled-raw | 0.559 | 0.558 | 0.295 | 0.528 | 0.528 |
| apg | Float64 | raw | raw-scaled | 0.554 | 0.546 | 0.281 | 0.506 | 0.514 |
| apg | Float64 | raw | scaled-raw | 0.546 | 0.547 | 0.281 | 0.514 | 0.514 |
| **six-solve sum** | | raw | raw-scaled | 1.908 | 1.879 | 1.027 | 0.539 | 0.547 |
| **six-solve sum** | | raw | scaled-raw | 1.892 | 1.877 | 1.045 | 0.552 | 0.557 |

**Julia 1.13.3**

| solver | T | loss | order | A s | B s | C s | C/A | C/B |
|---|---|---|---|---|---|---|---|---|
| cd | Float32 | raw | raw-scaled | 0.091 | 0.084 | 0.087 | 0.954 | 1.035 |
| cd | Float32 | raw | scaled-raw | 0.091 | 0.083 | 0.086 | 0.952 | 1.044 |
| cd | Float64 | raw | raw-scaled | 0.090 | 0.082 | 0.086 | 0.950 | 1.044 |
| cd | Float64 | raw | scaled-raw | 0.090 | 0.083 | 0.091 | 1.013 | 1.105 |
| pg | Float32 | raw | raw-scaled | 0.461 | 0.460 | 0.271 | 0.587 | 0.588 |
| pg | Float32 | raw | scaled-raw | 0.461 | 0.457 | 0.271 | 0.586 | 0.592 |
| pg | Float64 | raw | raw-scaled | 0.423 | 0.408 | 0.236 | 0.558 | 0.579 |
| pg | Float64 | raw | scaled-raw | 0.422 | 0.407 | 0.236 | 0.558 | 0.580 |
| apg | Float32 | raw | raw-scaled | 0.798 | 0.796 | 0.414 | 0.519 | 0.520 |
| apg | Float32 | raw | scaled-raw | 0.798 | 0.818 | 0.414 | 0.518 | 0.506 |
| apg | Float64 | raw | raw-scaled | 0.788 | 0.777 | 0.395 | 0.501 | 0.508 |
| apg | Float64 | raw | scaled-raw | 0.790 | 0.779 | 0.395 | 0.500 | 0.507 |
| **six-solve sum** | | raw | raw-scaled | 2.651 | 2.607 | 1.488 | 0.561 | 0.571 |
| **six-solve sum** | | raw | scaled-raw | 2.653 | 2.626 | 1.493 | 0.563 | 0.568 |


- **The six first raw-LS solves take 1.03–1.05 s in C against 1.89–1.91 s in A on 1.10.13 (C/A 0.54–0.55), and 1.49 s against 2.65 s on 1.13.3 (C/A 0.56).** PGD and APG take about half as long; the A/A spread of these medians in the baseline was within 1%.
- **CD separately:** C/A 0.72–0.75 on 1.10.13 and 0.95–1.01 on 1.13.3 (largest: Float64, scaled then raw, 0.091 s against 0.090 s). On 1.13.3 the dependency upgrade made CD's first solve faster (A→B 0.91–0.92) and the migration gives part of that back (B→C 1.04–1.11); every CD cell is within the A7 bound (C median ≤ A median × 1.05).
- First scaled solves (the precompiled shape) stay under 1 ms in all arms.
- A plausible reason for the PGD/APG gain, not separately measured: raw LS now stores the scale `one(T)` instead of `true`, so its model type matches the precompiled scaled one, and PB's oracles are in PB's own precompile workload.
- **A7 passes in every cell; `src/precompile.jl` is unchanged** (no Trial A, as the ruling requires).

### Precompile, cache and load (A8) — medians of 3 precompiles and 10 loads per arm

| Julia | arm | PB precompile s | PS precompile s | PB cache MB | PS cache MB | `using` s |
|---|---|---|---|---|---|---|
| 1.10.13 | A | 6.47 | 5.34 | 10.59 | 6.74 | 0.331 |
| 1.10.13 | B | 8.87 | 5.47 | 14.37 | 6.89 | 0.338 |
| 1.10.13 | C | 8.95 | 5.33 | 14.38 | 6.84 | 0.338 |
| 1.13.3 | A | 7.23 | 5.82 | 9.57 | 5.14 | 0.417 |
| 1.13.3 | B | 9.51 | 5.95 | 12.00 | 5.20 | 0.424 |
| 1.13.3 | C | 9.15 | 5.86 | 12.00 | 5.16 | 0.423 |

- **PS:** precompile time, cache size and load time unchanged within noise (A→C: PS precompile 5.34 → 5.33 s and 5.82 → 5.86 s; load 0.331 → 0.338 s and 0.417 → 0.423 s, +2% and +1%).
- **PB (dependency upgrade, A→B, not the migration):** PB's precompile time grows by 37% (6.47 → 8.87 s) on 1.10.13 and 32% (7.23 → 9.51 s) on 1.13.3, and its cache by 36% (10.6 → 14.4 MB) and 25% (9.6 → 12.0 MB). PB+PS precompile together: +21% (11.8 → 14.3 s) and +15% (13.1 → 15.0 s). **Above A8's 10%: a maintainer decision (below).**

### Formal series (A6) — the #318 harness unchanged, extended suite, `cd,gradient`, 52 cases × 10 repetitions per arm and version

B→C with the harness's own `compare.py`; A→B and A→C with the run-directory cross-dependency wrapper, which exempts only `proximalbase_version` and `proximalbase_hash` (all other settings, catalog, certificates, data hashes, threads and CPU must match, and did).

- **No case reaches the 5% investigation trigger in any contrast on either version.** Ratio ranges (median): 1.10.13 A→B 0.991–1.020 (1.001), B→C 0.977–1.029 (1.004), A→C 0.988–1.034 (1.007); 1.13.3 A→B 0.962–1.025 (0.998), B→C 0.986–1.023 (1.001), A→C 0.963–1.024 (0.999). The baseline A/A ranged 0.982–1.025 and 0.963–1.049.
- **One consistent small effect:** on 1.10.13 the smallest problem (`lasso`, 100×32) is 2–3% slower in PGD/APG after the migration with intervals above 1 (`pg/dense-f64` B→C 1.023 [1.017, 1.030], `pg/acc-dense-f64` 1.027 [1.011, 1.044], `apg/acc-dense-f64` 1.019 [1.007, 1.030]; A→C up to 1.034 [1.018, 1.051]); these cases do not show it on 1.13.3. A likely contributor is PB's per-call argument and overlap checks, a fixed cost per evaluation, but this has not been measured separately. Below the trigger; reported, not a claimed regression or noninferiority.
- **Warm bytes per call:** no case allocates more in C than in A (median bytes identical or lower in every case).
- Cases with a non-inconclusive assessment in any contrast, beside the A/A control:


**Julia 1.10.13** — cases with a non-inconclusive assessment in any contrast (ratio after/before, paired 95% interval; A/A from the baseline job):

| case | A/A | A→B | B→C | A→C |
|---|---|---|---|---|
| `cd/lasso-C/cd/sparse-f32/call` | 1.000 [0.998, 1.003] | 0.998 [0.992, 1.004] | 1.003 [1.000, 1.006] | 1.001 [0.995, 1.007] |
| `cd/lasso-D/cd/dense-f64/call` | 0.995 [0.986, 1.005] | 0.993 [0.976, 1.011] | 1.010 [1.001, 1.019] | 1.003 [0.983, 1.023] |
| `cd/lasso-D/cd/sparse-f64/call` | 1.008 [0.994, 1.023] | 1.006 [0.999, 1.014] | 1.010 [0.995, 1.025] | 1.016 [1.003, 1.030] |
| `cd/lasso-dense/cd/R/call` | 0.993 [0.981, 1.004] | 1.002 [0.993, 1.010] | 1.013 [0.998, 1.028] | 1.014 [1.004, 1.025] |
| `cd/lasso/cd/sparse-f64/call` | 0.998 [0.960, 1.038] | 0.999 [0.975, 1.024] | 1.018 [0.994, 1.042] | 1.017 [1.003, 1.031] |
| `gradient/lasso-C/apg/acc-dense-f64/call` | 1.000 [0.998, 1.002] | 1.001 [0.999, 1.004] | 0.998 [0.997, 0.999] | 0.999 [0.997, 1.001] |
| `gradient/lasso-C/pg/acc-dense-f64/call` | 1.000 [0.998, 1.003] | 1.003 [1.000, 1.005] | 1.023 [0.971, 1.078] | 1.026 [0.974, 1.081] |
| `gradient/lasso/apg/acc-dense-f64/call` | 0.987 [0.968, 1.006] | 1.001 [0.990, 1.012] | 1.019 [1.007, 1.030] | 1.020 [1.006, 1.033] |
| `gradient/lasso/pg/acc-dense-f64/call` | 1.004 [0.992, 1.016] | 1.007 [0.997, 1.016] | 1.027 [1.011, 1.044] | 1.034 [1.018, 1.051] |
| `gradient/lasso/pg/dense-f64/call` | 1.011 [1.004, 1.019] | 1.005 [0.998, 1.013] | 1.023 [1.017, 1.030] | 1.029 [1.018, 1.039] |


**Julia 1.13.3** — cases with a non-inconclusive assessment in any contrast (ratio after/before, paired 95% interval; A/A from the baseline job):

| case | A/A | A→B | B→C | A→C |
|---|---|---|---|---|
| `cd/lasso-B/cd/warm-sparse-f32/call` | 1.020 [0.995, 1.046] | 1.025 [0.995, 1.057] | 0.998 [0.967, 1.030] | 1.024 [1.001, 1.047] |
| `cd/lasso-C/cd/sparse-f32/call` | 1.007 [1.000, 1.013] | 0.993 [0.987, 1.000] | 1.008 [1.000, 1.017] | 1.001 [0.993, 1.010] |
| `cd/lasso-C/cd/sparse-f64/call` | 0.998 [0.992, 1.004] | 0.996 [0.993, 1.000] | 1.005 [1.000, 1.011] | 1.002 [0.996, 1.008] |
| `cd/lasso-D/cd/dense-f64/call` | 0.987 [0.973, 1.000] | 0.988 [0.974, 1.002] | 1.000 [0.995, 1.005] | 0.988 [0.977, 0.999] |
| `cd/lasso-D/cd/sparse-f64/call` | 0.992 [0.974, 1.010] | 0.995 [0.975, 1.017] | 0.993 [0.975, 1.011] | 0.988 [0.979, 0.997] |
| `cd/lasso/cd/dense-f64/call` | 0.991 [0.961, 1.022] | 0.977 [0.955, 1.000] | 1.009 [0.993, 1.026] | 0.986 [0.964, 1.009] |
| `cd/lasso/cd/sparse-f32/call` | 1.013 [0.987, 1.040] | 0.962 [0.930, 0.995] | 1.023 [0.990, 1.057] | 0.985 [0.961, 1.009] |
| `gradient/lasso-C/apg/dense-f64/call` | 0.999 [0.996, 1.001] | 0.998 [0.996, 0.999] | 1.001 [0.999, 1.002] | 0.998 [0.996, 1.001] |
| `gradient/lasso-D/apg/acc-dense-f64/call` | 0.999 [0.997, 1.001] | 0.998 [0.996, 0.999] | 1.002 [1.000, 1.004] | 1.000 [0.998, 1.002] |
| `gradient/lasso-D/pg/acc-dense-f64/call` | 0.998 [0.995, 1.001] | 0.996 [0.994, 0.999] | 0.986 [0.942, 1.032] | 0.982 [0.937, 1.030] |
| `gradient/lasso-D/pg/dense-f64/call` | 0.996 [0.994, 0.998] | 0.996 [0.994, 0.998] | 0.989 [0.953, 1.026] | 0.985 [0.948, 1.023] |
| `gradient/lasso/apg/dense-f64/call` | 0.979 [0.972, 0.987] | 0.980 [0.962, 0.999] | 1.006 [0.999, 1.013] | 0.986 [0.966, 1.007] |


### Accuracy and work (A3, A4)

- **Certificates (independent relative duality gap, the harness's):** the ten `acc-…-f64` cases are `ok` in 10/10 repetitions in every arm and version (100/100). A→B: every `ok` record's certificate value is bit-identical (439/439 and 435/435). B→C: identical in 429/436 (1.10.13) and 432/434 (1.13.3) records; every CD record identical (210/210 per version). Two Float64 PGD records worsen by more than 10× and stay inside the 1e-8 target (`lasso-D/pg/acc-dense-f64` rep 10: 1.3e-12 → 1.2e-10; `lasso-C/pg/dense-f64` rep 2: 5.2e-11 → 1.4e-9); one improves by more than 10× on 1.13.3. Cause: PGD stopping at a different iterate after last-bit changes of the value.
- **Status changes (B→C only):** default-setting Float32 PGD cases, which the harness documents as stopping near the target by chance, move in both directions — 1.10.13: three records `ok` → `target_missed` (`lasso-C/pg/dense-f32` rep 7, `lasso-D/pg/dense-f32` reps 7 and 9; gaps 6.0e-5, 1.4e-5, 1.6e-5 against the 1e-5 target); 1.13.3: one each way. No Float64 status changes.
- **Product counts** (counting probe, 60 fixed solves per arm): in every PGD and APG row of all three arms, adjoint products = gradient evaluations + 1 (the once-per-solve λmax) and forward products = 1 + trials + verification/fallback products; CD performs no matrix-vector product. **No extra product per evaluation.** B→C: identical products and counters in 36/40 (1.10.13) and 32/40 (1.13.3) rows; the rest are a ±1 rejection-verification product with identical counters, or Float32 trajectories of different length.
- **Numerical sweep in the same job** (294 solves per arm): A→B no row differs on either version. B→C: the D1 refusals (caller's iterate unchanged in every refusal; `f.tmp` unchanged in every solve), large-n objective error 1.0e-6 → 1.7e-8 (one Float32 PGD case now converges, KKT 4.5e-5 → 4.6e-6), and the R5 and overflow cases below.

### Decisions for the maintainer

1. **R5 stopping behaviour (changed by the migration).** For a raw or scaled LS whose squares overflow while the value is representable (#277 R5: `X = ones(5,1)`, `y = fill(1e160, 5)`, scale 1e-100, value 2.5e220), PGD and APG used to refuse the start ("start from a point where f is finite"). Now the start is evaluated by PB, and both solvers run to `maxiter` (200 by default) with `converged = false`, an accurate reported objective (relative error 1.9e-16) and a KKT residual of 1.0, i.e. no progress: their curvature estimate starts at 1, the problem's curvature is 5e-100, and the estimate shrinks by a constant factor per iteration. The outcome is truthful (not converged); CD solves R5 exactly in every arm. Options: accept and document the no-progress outcome (recommended: the result is truthful, a user sees `converged = false`, and the old refusal was an artifact of the PS sum overflowing); or ask for a follow-up issue on PGD/APG's initial curvature for badly scaled problems (out of scope here).
2. **PB precompile cost of the dependency upgrade (A8).** PB's precompile time +37% / +32% and cache +36% / +25% (1.10.13 / 1.13.3), from PB's own changes between `c123d56` and `50db4b1` (including #918's workload); PS's own precompile, cache and load are unchanged, and first raw-LS solves are 44–46% faster. Recommended: accept (it is the cost of the approved PB revision; the alternative is not upgrading).
3. **Overflow-boundary classification** (`cd_numerics.jl` §8, reported in round 2): a Float32 objective just under the overflow tie can now be `floatmax` or `Inf`, per PB's documented range statement, where PS's old sum reported a finite value; the test now asserts outside PB's uncertainty band. Recommended: accept as the documented PB contract.
4. **The 1.10.13 small-problem PGD/APG +2–3%** (above): below the 5% trigger, not reproduced on 1.13.3; recorded for awareness, no action recommended.

Raw records, probes and analysis scripts are kept in the run directory and will be archived with the final report.
