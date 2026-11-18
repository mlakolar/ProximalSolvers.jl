## Current-master baseline: accuracy and reliability of the 62-case extended catalog (2026-11-18)

This is a descriptive baseline built with the cross-solver readout from #374 / PR #385. It does not rank solvers. Each interval below is the case's own Student-t interval over 10 repetitions; these are not paired comparisons, and overlapping or separate intervals are not a test. Nothing in the package, the harness or the stopping rules changed.

### 1. Existing validated records (reused first)

- **Records:** the #307-era 10-repetition extended series at `637f06a`, with PB `c123d56b` and harness `164fab53`. Julia 1.10.13 and 1.13.3 on an exclusive Xeon E5-2640 v4 node. This is the series PR #385 used as its real-record test.
- **Catalog:** 52 cases. The 4 group-lasso and 6 weighted-lasso cases came later.
- **Checks:** `validate.py --expected-runs 10` reports valid, with 874 ok, 166 `target_missed` and nothing else. `summarize.py` and `cross_solver.py` at master both exit 0, giving `REPORT.md` and `cross_solver.csv`.
- **Use here:** the per-configuration counts match the fresh series below except for the differences listed in section 3. These records are therefore only a revision reference, not part of the baseline.

### 2. Fresh baseline campaign

| Item | Value |
|---|---|
| ProximalSolvers | `a0a064778acb34d0535408a31ab2f09ae657e4aa` (master), clean tree (`proximalsolvers_dirty = false`), enforced through `PS_EXPECTED_PACKAGE_REVISION` |
| ProximalBase | `a19c59aa723d085d5d7cf5242895bda16eb77214`, tree `138929aa27c6221284ee1763e66b1110dd6ec418` (the root `[sources]` pin), enforced through `PS_EXPECTED_PROXIMALBASE_REV` |
| Harness | hash `11b291250927e604d7a6e6af3ea343258b775570`; `PS_SUITE=extended`, default sample and time limits |
| Environments | `benchmark/setup.jl <checkout> <env> pinned`, one per Julia version, with fresh private depots |
| Julia | 1.10.13 and 1.13.3, the same versions as section 1 |
| Machine | one exclusive cluster node, Intel Xeon E5-2640 v4 (broadwell, 20 cores, OpenBLAS ILP64). No other job ran on the node at start, after setup or at the end. 1 Julia thread, 1 BLAS thread |
| Design | `PS_REPETITION=1..10` in fresh processes. Repetition k runs both versions back to back, alternating which goes first. Records for each version go to their own directory, separate from earlier campaigns |
| Outcome | 20 of 20 processes finished, each with exit 2 (complete records with non-ok cases). `validate.py --expected-runs 10` is valid for each version and for the combined directory: 1,240 measurements, 1,071 ok, 169 `target_missed`, and 0 uncertifiable, incomplete, timeout or error |

### 3. Per-configuration table (fresh series)

"Runs" counts repetitions. A case gets a time only with a finite target and every run ok, which is the readout's rule. "Worst / target" is the largest worst certificate over the configuration's cases divided by the target.

| Configuration (cases per version) | Settings | Ok runs 1.10.13 | Ok runs 1.13.3 | Target missed (runs) 1.10 / 1.13 | Errors, timeouts, uncertifiable | Worst / target 1.10 / 1.13 | Timed cases 1.10 / 1.13 |
|---|---|---:|---:|---:|---:|---:|---:|
| CD dense, sparse, block; cold and warm; f64 and f32 (28) | default | 280 / 280 | 280 / 280 | 0 / 0 | 0 | 0.32 / 0.29 | 28 / 28 |
| PGD `acc-` f64, incl. warm and weighted (6) | accuracy | 60 / 60 | 60 / 60 | 0 / 0 | 0 | 0.024 / 0.028 | 6 / 6 |
| APG `acc-` f64, incl. warm and weighted (6) | accuracy | 60 / 60 | 60 / 60 | 0 / 0 | 0 | 0.034 / 0.054 | 6 / 6 |
| PGD dense-f64, warm-dense-f64 (5) | default | 46 / 50 | 45 / 50 | 4 / 5 | 0 | 2.74 / 2.36 | 2 / 2 |
| APG dense-f64, warm-dense-f64 (5) | default | 49 / 50 | 48 / 50 | 1 / 2 | 0 | 1.25 / 1.35 | 4 / 4 |
| PGD dense-f32, warm-dense-f32 (5) | default | 11 / 50 | 13 / 50 | 39 / 37 | 0 | 64.4 / 43.5 | 0 / 0 |
| APG dense-f32, warm-dense-f32 (5) | default | 10 / 50 | 9 / 50 | 40 / 41 | 0 | 33.3 / 29.0 | 0 / 0 |
| Historical `cd …/R`, `pg …/R` (2) | record-only | 20 / 20 | 20 / 20 | n/a | 0 | n/a (worst 5.75e-8 and 3e-5) | 0 / 0 |

This gives 46 of 62 cases with an eligible timing on each version. The table for each configuration (CD split by iterate, start and precision), the exclusion list for each case and the timing table for each case are in the archive (`tables/fresh-table.md`, `tables/extra-tables.md`). The full readout is in `fresh/analysis/cross-solver/REPORT.md` (36 groups) and `cross_solver.csv`.

**Eligible timings** (mean of the repetition medians). The 95% interval half-width per case has a median of 9.2% of the mean on 1.10.13 (range 1.0–63%) and 8.5% on 1.13.3 (range 1.8–49%). The widest intervals are on `lasso-B`, for PGD/APG `acc-` (±17–63%) and for CD f64 (±15–23%). The draws differ between repetitions, so these intervals include input variation as well as machine noise; they are not a noise floor.

**Against section 1 (52 shared cases):** the input hashes for every repetition are equal in all 52 cases on both versions. Ok counts or worst certificates differ in 2 cases on 1.10.13 and 3 on 1.13.3, all Float32 PGD default settings: `lasso-C` 4→3 and `lasso-D` 7→5 ok on 1.10; `lasso-B` 2→1 and `lasso-D` 5→6 ok, plus a changed worst certificate on `lasso-C`, on 1.13. These are separate jobs at two revisions, so this is descriptive. HARNESS.md (from #320 Phase 0) records that Float32 PGD miss counts changed by up to 3 of 50 between the revisions before and after #319.

### 4. Exclusions, classified

Each version excludes 16 of 62 cases from timing. The two versions match in each class.

1. **No finite target (2 cases):** `cd/lasso-dense/cd/R/call` and `gradient/lasso/pg/R/call`. They are 10/10 ok, with accuracy recorded only. These are not failures.
2. **Default (harness) settings, Float32, `target_missed` (10 cases):** every Float32 PGD and APG case. 79 of 100 runs missed on 1.10.13 and 78 of 100 on 1.13.3, with the largest gap 6.4e-4 on 1.10.13 and 4.4e-4 on 1.13.3, against `1e-5`. This is the limit already documented in HARNESS.md ("Float32 PGD and APG against the `1e-5` target", from #320 Phase 0): 36–41 misses of 50 there, against 37–41 of 50 here for each solver and version. It is a stopping-criterion limit under the harness options, not an error. It is owned by #320, which is open for 0.7.
3. **Default settings, Float64, `target_missed` (4 cases per version):** 1–3 of 10 runs miss in each case, with the worst gap 1.0e-8 to 2.7e-8 against `1e-8`. On 1.10.13 these are `lasso-B` pg dense/warm, `lasso-D` pg and `lasso` apg. On 1.13.3 they are `lasso-B` pg dense/warm and apg warm, and `lasso-C` pg. HARNESS.md documents this ("PGD stops once the objective changes by less than one rounding unit"; 4–5 of 50 Float64 PGD misses in #320 Phase 0; here 4 on 1.10.13 and 5 on 1.13.3). Which cases miss differs between the Julia versions.
4. **Accuracy-focused settings (`acc-`):** 0 misses (120 of 120 runs on each version). The worst certificate is at most 0.054 times the target.
5. **Actual failures (error, timeout, uncertifiable, incomplete):** none in either series.

### 5. Cross-references

- **#320 (open, 0.7):** exclusion classes 2 and 3 are its subject. Stage 1 ("explicitly distinguish benchmark harness options from library defaults") applies directly. The counts here are consistent with its Phase 0 table and need no new issue.
- **#352 / #378:** no CD case failed or missed in 560 CD runs (including the group and weighted cases). The F2 scenario of #378 (warm starts far above the solution scale) is not exercised by the catalog's warm starts, so this baseline gives no evidence on it either way. F4 concerns the `ftol = 0` exact-stall rule that the `acc-` profile uses. The harness reads certificates, not the `converged` flag, so this baseline does not test F4.
- **#364 / PR #381 (merge suspended for a performance follow-up):** this series measures master `a0a0647` without #381. Its PGD/APG cases can serve as a master reference for that follow-up, but they do not replace its paired, A/A-controlled design.
- **#333 readout §12 (1.13.3 A/A installation offset, recorded here as nonblocking):** this series has one installation per version, so it cannot speak to that offset.
- **#314:** the 10 Float64 `acc-` cases reproduce their 10/10 ok in all draws, and the 2 new weighted `acc-` cases do too.

### 6. Recommended investigations (at most three, for maintainer decision; none started)

1. **Timed PGD/APG coverage under the harness options, within #320 Stage 1.** Float32 PGD/APG has no eligible timing anywhere in this baseline (0 of 10 cases on both versions). Under default settings, only 6 of 20 PGD/APG cases are timed, and which ones depends on the Julia version. The question is which settings define the timed PGD/APG baseline, given that #320 Phase 0 found 0/50 Float32 PGD misses with its strict profiles on these designs, while on its adverse set those profiles ended at the iteration limit in 40–41 of 70 Float32 PGD solves. Today only the Float64 `acc-` cases give stable PGD/APG timings. This is a decision about the protocol or catalog; no harness change is proposed here.
2. **Noise calibration before this baseline serves as a regression reference (#110 Stage 2).** Run one A/A pair of `a0a0647` against itself (two fresh environments, the same node type, catalog and protocol, alternating order), with a work receipt for each draw (iterations or passes, untimed, as in the #333 work receipts). The goal is to separate machine noise from input variation in the ±9% median (±63% maximum) intervals per case, and to check whether the §12 offset recurs on Julia 1.13.3. At this catalog size an A/A pair for both versions should take about 30 minutes on one exclusive node; this series took 16. It is a new campaign, so it needs a separate decision.
3. **No third investigation recommended.** CD, the group and weighted lasso cases, and the `acc-` profiles show no failure, and the Float64 default-settings misses are documented and fall under item 1.

### Reproducibility

- **Run:** the job script follows the HARNESS.md "Current core" commands with `PS_SUITE=extended`, `PS_REPETITION=$rep`, `PS_EXPECTED_PACKAGE_ROOT`, `PS_EXPECTED_PACKAGE_REVISION` and `PS_EXPECTED_PROXIMALBASE_REV`, alternating versions per repetition.
- **Analysis:** `validate.py`, `summarize.py` and `cross_solver.py` at master, all with `--expected-runs 10`, plus two small table scripts that only read `cross_solver.csv` and the metrics TSVs.
- **Archive:** the maintainer's local run archive `issue110-baseline-20261118`, with 299 files listed in `SHA256SUMS`, including this text. It holds all 20 processes' records and logs, the node information and co-tenant log, both environments' `Project.toml`/`Manifest.toml`, the setup logs, the scheduler accounting, the job script, the table scripts and outputs, and the section 1 readout. The section 1 records are in the #374 archive tarball (`sha256 86e23959…`).
- No public archive branch was created. One can be pushed if wanted.
- **Readout cosmetic issue:** when every case is grouped, `cross_solver.py` prints a "Cases not grouped" table with a single `None` row instead of omitting it. This has no effect on any value.
