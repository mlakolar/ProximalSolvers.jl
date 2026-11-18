# #110 A/A campaign: preregistration (fixed before any A/A measurement)

Maintainer decision of 2026-11-18 (item 2): exactly one A/A campaign of master against itself. This
document fixes the design, statistics and the reading of "offset recurs" before the job is submitted.
Its sha256 is recorded in `PREREGISTRATION-aa110.sha256` and in the job log.

## Design
- Revision: ProximalSolvers `a0a064778acb34d0535408a31ab2f09ae657e4aa`, ProximalBase `a19c59aa723d085d5d7cf5242895bda16eb77214`
  (loaded tree `138929aa27c6221284ee1763e66b1110dd6ec418`), both enforced by `run.jl`.
- Installations: per Julia version (1.10.13, 1.13.3), two independently prepared installations A and B:
  separate clean clones of the package (`ps-A`, `ps-B`), separate `benchmark/setup.jl ... pinned` environments
  and separate private depots (each downloads and precompiles on its own). One harness checkout `ps-H`
  (third clone, same revision) runs for both sides, as HARNESS.md "Compare revisions" prescribes.
- Machine: one exclusive node, Intel Xeon E5-2640 v4 (same CPU kind as the posted baseline); 1 Julia thread,
  1 BLAS thread. Co-tenants recorded at start, after setup, end.
- Cases (`PS_SUITE=extended`, `PS_CASES` = `cd/*/cd/*-f64/call,cd/*/cd/*-f32/call,gradient/*/*/acc-*/call,gradient/*/*/dense-f64/call,gradient/*/*/warm-dense-f64/call`), 50 cases:
  - **Primary (40):** the 28 CD cases with a finite target and the 12 Float64 `acc-` PGD/APG cases.
  - **Diagnostic (10 run, reported only if ok in every run on both sides):** the default-setting Float64 PGD/APG
    `dense-f64` / `warm-dense-f64` cases. All 10 are run because which 6 were timing-eligible differed between the
    Julia versions in the baseline. No Float32 PGD/APG and no record-only cases.
- Repetitions: `PS_REPETITION=1..10`; inputs depend only on case and repetition, so A and B receive identical inputs
  (checked by data hash). Repetition k runs, for each version in turn, A and B back to back; the side order is
  A,B on odd k and B,A on even k; the version order is 1.10,1.13 on odd k and 1.13,1.10 on even k.
- Work receipts: after all timed processes, untimed, `benchmark/local.jl` (unchanged harness tool, separate
  processes, its timings discarded) for each version × side × repetition on the 50 cases, saving the work counters
  read from returned results (`passes`, `iterations`, `f_calls`, `grad_calls`, ...) and the data hash.
- Installation identity for diagnosis: sha256 of every file under each depot's `compiled/` directory, and `versioninfo()`
  per installation.

## Statistics (per Julia version, separately; B/A, so > 1 means B slower)
1. **Per case:** `compare.py A B out --expected-runs 10` — paired 95% Student-t interval of the log ratio of
   repetition medians; reported as given (ratio, interval). Count primary cases whose interval lies above 1,
   below 1, or contains 1. No multiplicity correction; these counts are descriptive.
2. **Installation offset (summary):** over the primary cases that are ok in every run on both sides, `d_rc = log(med_B,rc) − log(med_A,rc)`
   from the metrics TSVs; offset `G = exp(mean_{r,c} d_rc)`. 95% interval: percentile bootstrap over the 10
   repetitions (resample repetitions with replacement, all cases of a repetition kept together; 10,000 resamples,
   seed 110). Reported for all primary cases, the Float64 primary subset (every primary case whose ID ends in
   `f64/call`: 14 CD + 12 `acc-` = 26) and the Float32 subset (the 14 CD `f32` cases).
3. **Recurrence of the #333 §12 offset** (one installation 11–30% slower on every Float64 case on 1.13.3), a
   descriptive reading for this question only, not a regression threshold: it **recurs** on a version if the
   Float64-subset G lies outside [1/1.10, 1.10] **and** at least 90% of the Float64 primary cases have their
   per-case ratio (statistic 1) on that same side of 1. Otherwise it **did not recur in this campaign**; G and its
   interval are reported either way. A smaller consistent offset (G outside [0.97, 1.03] with the bootstrap interval
   excluding 1) is reported as "a smaller installation offset", without a cause claim.
4. **Work equality:** per case and repetition, A and B work counters (the full counter string) and data hashes
   must be equal; report the number of unequal pairs. Also check the receipts' data hashes against the timed records.
5. **Diagnostics:** statistic 1 for the diagnostic cases that are ok in every run on both sides; not included in 2–3.

## Not done
No regression threshold, no claim of a universal noise floor, no cross-solver comparison, no second campaign.
If the offset recurs: compare the two installations' compiled-file checksums, environments, setup logs and
`versioninfo()`, and name the most likely source; no new measurement.
