## A/A campaign on current master (`a0a0647` against itself): findings

This is the single A/A campaign the maintainer approved after the [baseline](https://github.com/mlakolar/ProximalSolvers.jl/issues/110#issuecomment-6987228427). The design, statistics and the reading of "offset recurs" were fixed in a preregistration before the job ran (sha256 `7cff22e5…`, in the archive). It is one campaign on one CPU kind. It sets no regression threshold and does not establish a general noise floor.

**Setup.**
- **Revisions:** PS `a0a064778acb34d0535408a31ab2f09ae657e4aa` and PB `a19c59aa723d085d5d7cf5242895bda16eb77214` (tree `138929aa`), both enforced by `run.jl`.
- **Installations:** two independent installations per Julia version (1.10.13 and 1.13.3), each with its own clean clone, `setup.jl … pinned` environment and private depot. One harness clone runs both.
- **Machine:** one exclusive Xeon E5-2640 v4 node (same CPU kind as the baseline, different node), with no co-tenants, 1 Julia thread and 1 BLAS thread.
- **Repetitions:** `PS_REPETITION=1..10`. A and B run back to back, A,B on odd repetitions and B,A on even ones, and the version order alternates too.
- **Cases:** 40 primary (28 CD and 12 Float64 `acc-` PGD/APG) and the 10 default-setting Float64 PGD/APG cases as diagnostics. No Float32 PGD/APG.
- **Work receipts:** collected afterwards with the unchanged `local.jl`, which reads the counters from the returned results in separate, untimed processes.
- **Outcome:** the job took 48 min. All 40 timed processes exited 0 or 2, and all 4 record sets are valid. Each side has 495 ok and 5 `target_missed` on 1.10.13, and 493 ok and 7 on 1.13.3.

**Identity checks.**
- **Inputs:** data hashes are equal for A and B in 500 of 500 case-repetitions per version.
- **Status and accuracy:** status and worst certificate are identical between A and B in every case-repetition. They are also identical to the baseline series for the same 50 cases (500 of 500 per version, including the data hash), so the misses are the same cases and draws as in the baseline.
- **Work:** the counters (`passes` for CD; `iterations`, `f_calls`, `grad_calls`, `prox_calls`, `backtrack_steps` for PGD/APG) are equal for A and B in 500 of 500 case-repetitions per version.

**Paired B/A time ratios** (from `compare.py`; per case, a paired Student-t 95% interval on the log ratio of repetition medians, with no multiplicity correction):

| Julia | Primary cases with interval above 1 / containing 1 / below 1 | Summary offset G over the primary cases, B/A [95% bootstrap over repetitions] | Float64 primary (26) | Float32 primary (14) |
|---|---|---|---|---|
| 1.10.13 | 0 / 37 / 3 | 0.9941 [0.9869, 1.0016] | 0.9967 [0.9902, 1.0037] | 0.9893 [0.9791, 0.9983] |
| 1.13.3 | 0 / 40 / 0 | 0.9997 [0.9948, 1.0053] | 0.9998 [0.9938, 1.0054] | 0.9997 [0.9926, 1.0070] |

- **The three intervals below 1 (1.10.13, all CD):**
  - `cd/group-lasso/cd/block-f64` 0.979 [0.962, 0.997]
  - `cd/group-lasso/cd/warm-block-f32` 0.966 [0.933, 1.000]
  - `cd/lasso-D/cd/dense-f32` 0.987 [0.974, 1.000]

  With 40 intervals at 95%, about 2 are expected to exclude 1 when the two installations do not differ.
- **The #333 §12 offset did not recur.** That offset was one installation 11–30% slower on every Float64 case on 1.13.3. Here, on 1.13.3, the Float64 G is 0.9998 [0.9938, 1.0054], with 11 cases above 1 and 15 below. On 1.10.13 it is 0.9967, with 8 above and 18 below. The preregistered reading (G outside [1/1.10, 1.10] with at least 90% of the Float64 cases on one side) is not met on either version.
- **Float32 subset on 1.10.13:** G is 0.989, and its bootstrap interval excludes 1. It lies inside the preregistered [0.97, 1.03] band, so it is not labelled an installation offset; it is reported here as measured.
- **Paired precision:** the paired intervals on the 40 primary cases have a median half-width of ±2.0% on 1.10.13 and ±2.4% on 1.13.3, with a maximum of ±4.8% and ±5.3%. The baseline's unpaired per-case intervals for the same 40 cases have a median of ±8.0% and a maximum of ±63% and ±49%. Pairing on identical inputs therefore removes most of the width of the baseline intervals, which is consistent with that width coming mainly from draw-to-draw input variation. This holds for this node type and catalog; no threshold is derived from it.
- **Diagnostics:** six of the ten default-setting Float64 cases are ok in every run on both sides, per version. These are the same cases as in the baseline, and the set differs between the versions. All six intervals contain 1, with ratios of 0.996–1.005 on 1.10.13 and 0.988–1.008 on 1.13.3.

**Installation note.**
- No file under `compiled/` is shared between A and B on either version: the cache file names and the checksums all differ. Even so, the times agree as above. In this campaign, byte-level differences between package images did not come with a time offset.
- The cause of the §12 offset remains unidentified. Since it did not recur, no source analysis or further campaign follows.

**Evidence.** The branch [`archive/issue-110-aa-20261118`](https://github.com/mlakolar/ProximalSolvers.jl/tree/archive/issue-110-aa-20261118) holds:
- the preregistration;
- the job body and analysis script;
- all records and work receipts;
- the `compare.py` outputs;
- the environments, the compiled-file checksums and `versioninfo` of each installation;
- the logs.

`SHA256SUMS` lists every file. Paths, host, user and queue names are replaced by placeholders. Recomputing from the scrubbed records reproduces `comparison.csv`, `REPORT.md` and the analysis byte for byte.

No production code, stopping rule, target or benchmark setting changed, and no issue was opened.
