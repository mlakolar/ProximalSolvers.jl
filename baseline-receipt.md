## Arm A baseline (unchanged code), recorded before any production or pin change

**Identities.** PS `637f06a2713f1b6727869f84c22aa21e69f81d55`; PB `c123d56ba1948e36a8fdbf183a9eea396a16e0d5`, tree `c2e2ddde114a1e7800358595193ee0869830180d` (read back from the loaded manifest entry in every process). Two separately built copies of arm A (A1, A2: two detached checkouts, each with its own environment and private depot) form the A/A control. Cluster (Slurm), one exclusive node per Julia version, Intel Xeon E5-2640 v4 (20 cores), 1 Julia thread, 1 BLAS thread; Julia 1.10.13 (job 14273059) and 1.13.3 (job 14273060), after a clean pilot (jobs 14272836, 14272837). Every child process verified that the PS and PB caches it loaded came from its own arm's depot.

### First-call latency: first raw-LS solve in a fresh process (one solver and precision per process)

| Julia | solver | T | A1 first raw solve, s (median [min–max] over 20 fresh processes, 10 per order) | A2 | A1 compile share |
|---|---|---|---|---|---|
| 1.10.13 | cd | Float32 | 0.057 [0.057–0.060] | 0.057 [0.057–0.061] | 0.999 |
| 1.10.13 | cd | Float64 | 0.059 [0.059–0.063] | 0.059 [0.059–0.063] | 0.999 |
| 1.10.13 | pg | Float32 | 0.361 [0.351–0.388] | 0.363 [0.361–0.381] | 1.000 |
| 1.10.13 | pg | Float64 | 0.314 [0.307–0.331] | 0.314 [0.306–0.332] | 1.000 |
| 1.10.13 | apg | Float32 | 0.558 [0.555–0.562] | 0.560 [0.555–0.587] | 1.000 |
| 1.10.13 | apg | Float64 | 0.552 [0.544–0.582] | 0.553 [0.543–0.582] | 1.000 |
| 1.13.3 | cd | Float32 | 0.091 [0.090–0.096] | 0.091 [0.090–0.092] | 0.998 |
| 1.13.3 | cd | Float64 | 0.090 [0.089–0.096] | 0.090 [0.089–0.094] | 0.998 |
| 1.13.3 | pg | Float32 | 0.461 [0.457–0.462] | 0.460 [0.459–0.482] | 1.000 |
| 1.13.3 | pg | Float64 | 0.422 [0.418–0.477] | 0.421 [0.418–0.440] | 1.000 |
| 1.13.3 | apg | Float32 | 0.798 [0.794–0.804] | 0.797 [0.791–0.837] | 1.000 |
| 1.13.3 | apg | Float64 | 0.787 [0.784–0.833] | 0.789 [0.785–0.828] | 1.000 |

- Compile share = compile time / wall time of that first call: the first raw solve is essentially all compilation. Second solves take 17–36 µs.
- The first **scaled** solve (the shape of the precompile workload) takes under 1 ms in every cell, and solving scaled first does not shorten the first raw solve (same medians in both orders), so raw LS is not covered by the current workload.
- Six-solve raw sum (medians of per-index sums): 1.90 s (A1) / 1.90–1.92 s (A2) on 1.10.13; 2.65 s / 2.65 s on 1.13.3. CD alone: 0.057–0.059 s on 1.10.13 and 0.090–0.091 s on 1.13.3.
- A1 against A2: every median within 1%; the A/A spread is far below the 5% of A7.

### Precompile, cache and load (medians of 3 precompiles, 10 loads)

| Julia | PB precompile s (A1 / A2) | PS precompile s (A1 / A2) | cache MB PB / PS | `using` s (A1 / A2) |
|---|---|---|---|---|
| 1.10.13 | 6.50 / 6.51 | 5.23 / 5.35 | 10.59 / 6.74 | 0.331 / 0.332 |
| 1.13.3 | 6.98 / 7.04 | 5.86 / 5.83 | 9.57 / 5.14 | 0.422 / 0.416 |

### Formal series (the #318 harness, unchanged): extended suite, groups `cd,gradient`, repetitions 1–10, A1 and A2 alternating first

- 52 cases × 10 repetitions per arm and version; `validate.py` valid for all four series. 1.10.13: 439 `ok`, 81 `target_missed`; 1.13.3: 435 `ok`, 85 `target_missed` (per arm, identical in A1 and A2). The `target_missed` records are the default-setting Float32 and some Float64 PGD/APG cases that the harness documents as stopping before the target; no `uncertifiable`, `incomplete`, `timeout` or `error`.
- The ten `acc-…-f64` cases: `ok` in 10/10 repetitions per arm and version.
- A/A with the unmodified `compare.py` (38 cases included per version, worst accuracy identical on both sides in every case, bytes identical): ratios 0.982–1.025 on 1.10.13 and 0.963–1.049 on 1.13.3; 1 "slower" and 1 "faster" on 1.10.13, 1 "slower" and 5 "faster" on 1.13.3, with interval upper bounds up to 1.056 and 1.084. These are the noise level that the A6 rule compares a flagged case against.
- The cross-dependency wrapper ran on the A/A records as a dry run (no PB difference, so it only checked that it reproduces `compare.py`).

### Product counts (probe, no timings)

PGD and APG forward/adjoint product counts, counters and objective values are identical in A1 and A2 for all 40 PGD/APG rows. CD calls no matrix-vector product (its residual updates are column loops) and its pass counts differ between processes because its default coordinate order is random; CD pass counts are therefore reported, not compared as deterministic.

Raw files, the probes and the summaries are kept in the run directory and will be archived with the final report.
