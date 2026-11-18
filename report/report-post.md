> **Orchestrator note.** Phase 0 report for this issue, from the research agent, checked before posting: the harness settings H (`benchmark_options(residual = true)`: `maxiter 10_000, ftol 1e-15, xtol 1e-14, gradtol 1e-11`, `benchmark/cases.jl:78-83`) and the stationarity threshold `max(gradtol, 64 eps(T))` (`src/types.jl:29-56`) were read at `dac9f4b`; the headline counts were recomputed from the raw per-record files (Float32 PGD, H, five harness designs × 10 draws: ok/missed/`converged=true`-with-missed-target = 14/36/22 → 11/39/25 on 1.10.13 and 13/37/15 → 13/37/16 on 1.13.3 across #319, master identical to `9f86a80`), and they match. **Terminology:** "false success" below means `converged=true` while the benchmark's independent 1e-5 gap target is missed; it is not a violation of the solver's documented contract, which every such record met (independent KKT residual below `64 eps(Float32)`). "Default settings" in the issue's records are the harness settings H, not `ProximalOptions()`; the library defaults (D) are reported too. The agent's curvature observation (the first accepted `L` differs by exactly a factor 2 between arms in the records whose stop changed) is referred to #321 and needs no curvature change here. **Decision for the maintainer:** option A (documentation only, files in §7) or a separately designed opt-in gap tolerance (option C); no implementation will start without an explicit GO.

# #320 Phase 0 report: default Float32 PGD stopping and the independent 1e-5 target

Research only. No production change, no PR. Base: master `dac9f4b`; merged #319 revision `9f86a80` (loaded PB `50db4b1`); pre-#319 reference PS `637f06a` + PB `c123d56`. Everything below is observed unless it is labelled hypothesis. "Target" is the harness's unchanged independent relative duality gap of `1e-5` (Float32) or `1e-8` (Float64), evaluated in Float64 on the rounded Float32 data (checked against BigFloat(256) below). "Missed" means the independent gap exceeds the target. "False success" means `converged=true` with a missed target. "Truthful miss" means a missed target with `converged=false`.

## Summary

1. **The three changed records reproduce exactly, and they are three of many.** On `9f86a80`, Julia 1.10.13, Float32 PGD with the harness settings gives gaps 5.973e-05 (lasso-C draw 7), 1.361e-05 (lasso-D draw 7) and 1.626e-05 (lasso-D draw 9), against 6.0e-5, 1.4e-5 and 1.6e-5 in the issue; the pre-#319 arm gives 1.947e-06, 6.751e-06 and 6.805e-06. The same probe over the five harness designs x 10 draws reproduces the #319 report's status changes exactly (1.10.13: three records `ok` to `target_missed`, none back; 1.13.3: one each way, lasso-B draw 2 and lasso-D draw 7) and no Float64 change. Master `dac9f4b` stops at the same iteration with the same flags as `9f86a80` in all 100 Float32 PGD harness records.
2. **Default-settings Float32 PGD misses the Float32 target in most draws in every arm, before and after #319.** Harness designs, 50 solves per cell: 1.10.13 14 ok / 36 missed (22 with `converged=true`) (pre-#319), 11 ok / 39 missed (25 with `converged=true`) (`9f86a80`); 1.13.3 13 ok / 37 missed (15 with `converged=true`) (pre-#319), 13 ok / 37 missed (16 with `converged=true`) (`9f86a80`). #319 moved which draws miss (14 to 11 `ok` on 1.10.13, 13 to 13 on 1.13.3), not how many do. The same settings in Float64 miss 4 to 5 of 50, never with `converged=true`; Float32 APG with the same options misses 40 to 41 of 50 with 26 to 29 false successes. On the adverse set (section 3) 69 of 70 Float32 PGD solves miss in every arm.
3. **The diagnosis is a mixture of false convergence and truthful, premature nonconvergence, both caused by the Float32 objective, not by the gradient evaluation.**
   - In all 240 Float32 PGD H records on master (both Julia versions, harness and adverse) the first stop proposal came from the objective test in 237 (its one-ulp branch `|F-F'| < eps(|F|+|F'|)`, since `ftol = 1e-15` is below Float32 resolution) and from nothing in 3. No x-test or gradient-mapping proposal came first.
   - Every false success on the harness designs (119 over the six arm/version cells; gaps 1.07e-05 to 3.75e-05) ended on the objective test and was accepted by the stationarity check. The independent KKT residual was below the check's threshold `64 eps(Float32) = 7.63e-06` in all 231 `converged=true` H records (harness and adverse): the check is honest to its documented contract; its threshold is simply looser than the benchmark's gap target (gap / KKT_rel was 2.3 to 7.0 on the harness designs and 16.9 to 47.2 on the adverse set).
   - The truthful misses end on the objective-increase stop after the check refused earlier proposals; all 156 objective-increase stops on master (harness and adverse) were increases of 1 to 3 Float32 spacings of F (142 of exactly 1), i.e. rounding noise; the 486 truthful misses of the six arm/version cells have a median gap of 7.20e-04 (maximum 5.22e-02).
   - Gradient evaluation is not the limit: the solver's Float32 gradient differs from the Float64 gradient of the same rounded data by at most 2.5e-7 of the scale S over about 957 000 recorded iterations, 30 times below the check's threshold.
4. **Strict and accuracy-oriented settings are accurate but do not report convergence; the cost is stagnation or the iteration limit.** With `ftol = 0` (S, A) no harness-design solve misses (0 of 50 per cell) and none reports `converged=true` (all `stagnated`; median 10 to 14 iterations after the target is reached). `gradtol = 1e-7` (Q) misses nothing on the harness designs and reports convergence in 16 to 23 of 50. On the adverse set S/A reach the iteration limit in 40 or 41 of 70 solves, the two ill-conditioned low-lambda designs do not reach 1e-5 within 10 000 iterations (25 of 140 solves, `maxiter`), and Q has 3 false successes per Julia version (all `adv-ill-low-cold`, gaps 1.17e-05 to 9.74e-05), as #314 found.
5. **Recommendation: option A, no code change, improved documentation.** Narrow stopping-rule changes (B) replayed on the recorded trajectories either convert truthful misses into false successes (an objective-increase tolerance: 34 of 50 false successes on the harness designs, 53 to 55 of 70 on the adverse set) or remove the false successes on the harness designs only by tightening the check's floor to 8 eps (a new default tolerance), leaving 41 to 45 of 70 false successes on the adverse set once the increase stop is relaxed. A computable gap check (C) is exact on the harness designs but underestimates the independent gap by more than a factor 2 on 17% of the adverse iterates in the relevant range, so it is not a certificate at 1e-5 without a margin or a widened product. Files and tests of the proposed documentation change are in section 7.
6. **One curvature observation, for #321:** the migration changed the first accepted curvature L of the line search in only 8 of 50 (1.10.13) and 6 of 50 (1.13.3) harness Float32 PGD records, always by exactly a factor 2 (6 of 8 and 5 of 6 doubled), and the stop iteration changed in exactly those records. Nothing here depends on a curvature fix.

## 1. Provenance and what ran

- **Sources.** Detached exports of PS `637f06a2713f1b6727869f84c22aa21e69f81d55` (PB `c123d56ba1948e36a8fdbf183a9eea396a16e0d5`, tree `c2e2ddde114a1e7800358595193ee0869830180d`), PS `9f86a808bfac968f5421b9efeb6d0aecd7c1c775` (PB `50db4b1ef376cbe01831c3dd019b6be0027db0b6`, tree `4556e470aea2da876ea3b5a5998618f4c17326b1`) and PS master `dac9f4b6819d9321117ee3cf3549e9e46a043f01` (PB `a19c59aa723d085d5d7cf5242895bda16eb77214`, tree `138929aa27c6221284ee1763e66b1110dd6ec418`), `git status --porcelain` empty. The SHA-1 of `Project.toml` plus `src/**/*.jl` read back in every process equals the value computed from git (`637f06a`: `c2aeaab4fc9c54c20aaad0fe16e563dffdea964e`; `9f86a80`: `dc9cb31ffa76847c45f185a47370dfe34832ee47`; `dac9f4b`: `be88997a50372494e019f1cb1270e0e70f80ca8a`). Each revision has its own environment; the loaded PB revision and tree are read back from the manifest in every process, and the PB tree equals the tree in the committed Julia 1.10 manifest of each revision. Julia 1.13.3 manifests are not tracked and were resolved fresh, so their other dependencies can differ from the #319 report's.
- **Harness.** The probe includes master's `problems.jl`, `certificates.jl`, `cases.jl` (file SHA-1 `03cde44d8e7362435dad8bd74eaf17be8289cdb6`, `78d12af7069e7cb99410213f8227c48068e94834`, `eb6f1f9430f842e613a12c941e3ce41a2eded21c`) and builds each case with the harness's own `regression_problem`, `core_problem`, `exact_problem`, `benchmark_model`, `benchmark_options`, `accuracy_options` and `certify`. Float32 inputs are the Float64 draw rounded once; the data hash is recorded and, within one CPU kind, identical across the three revisions for every case. `problems.jl` and `certificates.jl` are byte-identical at `637f06a`. The "harness settings" H of the #320 records are `benchmark_options(residual = true)`: `maxiter 10_000, ftol 1e-15, xtol 1e-14, gradtol 1e-11, allow_f_increases = false` (not `ProximalOptions()`).
- **Hardware and runtime.** Cluster (Slurm), Intel Xeon E5-2640 v4 for every run reported here (the #319 report's CPU kind); Intel Xeon Silver 4116 (AVX-512) additionally for master and for the timings. Julia 1.10.13 (official build) and 1.13.3, 1 Julia thread, 1 BLAS thread (`libopenblas64`), offline package resolution, one private depot per Julia version.
- **Probe.** A disposable script (not in the package or the harness; `src/`, `test/`, `benchmark/` and the pins are untouched) follows one PGD trajectory with a copy of the solver loop built on the loaded revision's own `initial_state`, `update_state!`, `_gradient_test`, `_stationary!` and `_stagnated`; it evaluates every stopping profile on that trajectory and, for every iterate, the independent gap and KKT residual (Float64, harness certificate on the rounded data). The stop options do not enter `update_state!`, so one trajectory serves all profiles. **Cross-check:** for each named profile the library's own loop (`_solve_gradient!`) and `solve!` were run separately and compared with the probe: iteration, every flag and the returned iterate bit for bit agree in all 9 600 compared records (0 mismatches), and an offline replay of the recorded per-iteration quantities reproduces the stop iteration and `converged` of all 9 600 of those records (five named profiles, Float32 and Float64, harness and adverse sets, both CPU kinds). **BigFloat(256):** the Float64 gap of the returned point of every library-run record (14 400) classifies identically against the target as the BigFloat gap (0 disagreements). Two independent submissions of the same matrix (without and with per-iteration detail) agree in every discrete column except `mode_switch_iter`, which the second computes over a longer trajectory.
- **CPU kinds.** For Float32 PGD with H on master the two CPU kinds give 214 and 215 missed and 53 and 53 false successes of 240 records (3 status flips, 11 different iteration counts); for the three-draw reproduction all discrete results are identical. Float64 PGD controls change more (30 status flips of 240). The data hash of the warm designs and of a few `lasso` draws differs between the CPU kinds (BLAS-dependent generation and warm start), so cross-CPU comparisons are of nearly identical inputs; within a CPU kind they are identical across revisions.
- **Runs.** Reproduction: 3 revisions x 2 Julia versions x two CPU kinds. Matrix: harness designs (lasso, lasso-B cold and warm, lasso-C, lasso-D) x 10 draws and the adverse set x 10 draws, Float32 PGD with Float64 PGD and Float32 APG controls, 3 revisions x 2 Julia versions on the E5-2640 v4, repeated for master on the 4116 (6 300 harness-design and 8 820 adverse-set records on the E5-2640 v4). Timing: master, 2 jobs on an otherwise idle node. Raw TSVs, the probe, the preregistration with its checksum, an interim note and the job registry are kept in the run directory.

## 2. Reproduction of the three changed records (Float32 PGD, harness settings H, Xeon E5-2640 v4)

| PS revision (PB) | Julia | case | `converged` | stop | iterations | first proposal | k* | gap at return | KKT_rel at return | status |
|---|---|---|---|---|---|---|---|---|---|---|
| 637f06a + PB c123d56 | 1.10.13 | lasso-C draw 7 | true | f | 14 | it 14, one-ulp objective, check accepted; 1 proposal(s), 0 refused | 14 | 1.947e-06 | 4.23e-07 | ok |
| 637f06a + PB c123d56 | 1.10.13 | lasso-D draw 7 | false | f_increased | 15 | none | 15 | 6.751e-06 | 1.69e-06 | ok |
| 637f06a + PB c123d56 | 1.10.13 | lasso-D draw 9 | true | f | 13 | it 13, rel.+ulp objective, check accepted; 1 proposal(s), 0 refused | 13 | 6.805e-06 | 2.43e-06 | ok |
| 637f06a + PB c123d56 | 1.13.3 | lasso-C draw 7 | false | f_increased | 11 | it 10, one-ulp objective, check refused; 2 proposal(s), 2 refused | 12 | 3.618e-05 | 1.73e-05 | target_missed |
| 637f06a + PB c123d56 | 1.13.3 | lasso-D draw 7 | false | f_increased | 13 | it 13, one-ulp objective, check refused; 1 proposal(s), 1 refused | 14 | 6.826e-05 | 1.41e-05 | target_missed |
| 637f06a + PB c123d56 | 1.13.3 | lasso-D draw 9 | true | f | 14 | it 14, one-ulp objective, check accepted; 1 proposal(s), 0 refused | 14 | 1.199e-06 | 1.73e-07 | ok |
| 9f86a80 + PB 50db4b1 | 1.10.13 | lasso-C draw 7 | false | f_increased | 10 | it 9, rel.+ulp objective, check refused; 2 proposal(s), 2 refused | 12 | 5.973e-05 | 1.14e-05 | target_missed |
| 9f86a80 + PB 50db4b1 | 1.10.13 | lasso-D draw 7 | true | f | 21 | it 20, one-ulp objective, check refused; 2 proposal(s), 1 refused | 22 | 1.361e-05 | 3.22e-06 | target_missed |
| 9f86a80 + PB 50db4b1 | 1.10.13 | lasso-D draw 9 | true | f | 19 | it 19, rel.+ulp objective, check accepted; 1 proposal(s), 0 refused | 20 | 1.626e-05 | 6.38e-06 | target_missed |
| 9f86a80 + PB 50db4b1 | 1.13.3 | lasso-C draw 7 | false | f_increased | 11 | it 10, one-ulp objective, check refused; 2 proposal(s), 2 refused | 12 | 3.618e-05 | 1.73e-05 | target_missed |
| 9f86a80 + PB 50db4b1 | 1.13.3 | lasso-D draw 7 | false | f_increased | 20 | it 19, one-ulp objective, check refused; 1 proposal(s), 1 refused | 20 | 6.356e-06 | 1.20e-06 | ok |
| 9f86a80 + PB 50db4b1 | 1.13.3 | lasso-D draw 9 | true | f | 14 | it 14, one-ulp objective, check accepted; 1 proposal(s), 0 refused | 14 | 1.199e-06 | 1.73e-07 | ok |
| dac9f4b + PB a19c59a | 1.10.13 | lasso-C draw 7 | false | f_increased | 10 | it 9, rel.+ulp objective, check refused; 2 proposal(s), 2 refused | 12 | 5.973e-05 | 1.14e-05 | target_missed |
| dac9f4b + PB a19c59a | 1.10.13 | lasso-D draw 7 | true | f | 21 | it 20, one-ulp objective, check refused; 2 proposal(s), 1 refused | 22 | 1.361e-05 | 3.22e-06 | target_missed |
| dac9f4b + PB a19c59a | 1.10.13 | lasso-D draw 9 | true | f | 19 | it 19, rel.+ulp objective, check accepted; 1 proposal(s), 0 refused | 20 | 1.626e-05 | 6.38e-06 | target_missed |
| dac9f4b + PB a19c59a | 1.13.3 | lasso-C draw 7 | false | f_increased | 11 | it 10, one-ulp objective, check refused; 2 proposal(s), 2 refused | 12 | 3.618e-05 | 1.73e-05 | target_missed |
| dac9f4b + PB a19c59a | 1.13.3 | lasso-D draw 7 | false | f_increased | 20 | it 19, one-ulp objective, check refused; 1 proposal(s), 1 refused | 20 | 6.356e-06 | 1.20e-06 | ok |
| dac9f4b + PB a19c59a | 1.13.3 | lasso-D draw 9 | true | f | 14 | it 14, one-ulp objective, check accepted; 1 proposal(s), 0 refused | 14 | 1.199e-06 | 1.73e-07 | ok |

k* is the first accepted iterate whose independent gap meets the target; KKT_rel is the independent normalized KKT residual `||G||_inf / max(lambda, lambda_max)` in Float64 on the rounded data; the stationarity check accepts when its computed value is below `64 eps(Float32) = 7.63e-06`. The results are identical on the Xeon Silver 4116. In the 1.10.13 records of `9f86a80` and master: lasso-C draw 7 is a truthful nonconvergence (`f_increased` at iteration 10 after the check refused the proposals at iterations 9 and 10; the target is first met at iteration 12); lasso-D draws 7 and 9 are false successes on the objective test (the check accepted at KKT_rel 3.2e-06 and 6.4e-06; the target is first met one iteration later).

## 3. The records in context: five designs, an adverse set, controls

Fixed before the matrix ran (preregistration with checksum): harness designs lasso (100x32), lasso-B (240x160, rho 0.8) cold and warm, lasso-C (800x120, rho 0.5), lasso-D (180x600), 10 draws each; adverse set, 10 draws each, keys `issue320/adv/*`: correlated low lambda (0.02 lambda_max) cold and warm, equicorrelated low lambda cold, ill-conditioned (column scales over two decades) at 0.15 lambda_max cold and at 0.02 lambda_max cold and warm, wide (180x600) low lambda cold. Profiles: H harness settings; D `ProximalOptions()`; S strict stress (`ftol 0, xtol 1e-300, gradtol 1e-11, allow_f_increases`); A the #314 research candidate (`ftol 0, xtol 1e-14, gradtol 1e-10, allow_f_increases`); Q the one other candidate, #314's P2 applied to Float32 (`ftol 0, xtol 1e-14, gradtol = target/100 = 1e-7, allow_f_increases`).

**Harness designs, 5 designs x 10 draws** (Float32 PGD; cells are `converged=true` / target missed / false success = `converged=true` and missed, out of n)

| profile | 637f06a + PB c123d56, 1.10.13 | 9f86a80 + PB 50db4b1, 1.10.13 | dac9f4b + PB a19c59a, 1.10.13 | 637f06a + PB c123d56, 1.13.3 | 9f86a80 + PB 50db4b1, 1.13.3 | dac9f4b + PB a19c59a, 1.13.3 |
|---|---|---|---|---|---|---|
| H | 35 / 36 / 22 (n=50) | 36 / 39 / 25 (n=50) | 36 / 39 / 25 (n=50) | 28 / 37 / 15 (n=50) | 28 / 37 / 16 (n=50) | 28 / 37 / 16 (n=50) |
| D | 37 / 39 / 26 (n=50) | 37 / 42 / 29 (n=50) | 37 / 42 / 29 (n=50) | 30 / 38 / 18 (n=50) | 31 / 38 / 19 (n=50) | 31 / 38 / 19 (n=50) |
| S | 0 / 0 / 0 (n=50) | 0 / 0 / 0 (n=50) | 0 / 0 / 0 (n=50) | 0 / 0 / 0 (n=50) | 0 / 0 / 0 (n=50) | 0 / 0 / 0 (n=50) |
| A | 0 / 0 / 0 (n=50) | 0 / 0 / 0 (n=50) | 0 / 0 / 0 (n=50) | 0 / 0 / 0 (n=50) | 0 / 0 / 0 (n=50) | 0 / 0 / 0 (n=50) |
| Q | 17 / 0 / 0 (n=50) | 16 / 0 / 0 (n=50) | 16 / 0 / 0 (n=50) | 22 / 0 / 0 (n=50) | 23 / 0 / 0 (n=50) | 23 / 0 / 0 (n=50) |

**Adverse set, 7 designs x 10 draws** (Float32 PGD; cells are `converged=true` / target missed / false success = `converged=true` and missed, out of n)

| profile | 637f06a + PB c123d56, 1.10.13 | 9f86a80 + PB 50db4b1, 1.10.13 | dac9f4b + PB a19c59a, 1.10.13 | 637f06a + PB c123d56, 1.13.3 | 9f86a80 + PB 50db4b1, 1.13.3 | dac9f4b + PB a19c59a, 1.13.3 |
|---|---|---|---|---|---|---|
| H | 5 / 69 / 4 (n=70) | 5 / 69 / 4 (n=70) | 5 / 69 / 4 (n=70) | 7 / 69 / 6 (n=70) | 9 / 69 / 8 (n=70) | 9 / 69 / 8 (n=70) |
| D | 6 / 69 / 5 (n=70) | 6 / 69 / 5 (n=70) | 6 / 69 / 5 (n=70) | 9 / 69 / 8 (n=70) | 11 / 69 / 10 (n=70) | 11 / 69 / 10 (n=70) |
| S | 0 / 14 / 0 (n=70) | 0 / 14 / 0 (n=70) | 0 / 14 / 0 (n=70) | 0 / 11 / 0 (n=70) | 0 / 11 / 0 (n=70) | 0 / 11 / 0 (n=70) |
| A | 0 / 14 / 0 (n=70) | 0 / 14 / 0 (n=70) | 0 / 14 / 0 (n=70) | 0 / 11 / 0 (n=70) | 0 / 11 / 0 (n=70) | 0 / 11 / 0 (n=70) |
| Q | 53 / 17 / 3 (n=70) | 53 / 17 / 3 (n=70) | 53 / 17 / 3 (n=70) | 49 / 13 / 3 (n=70) | 50 / 13 / 3 (n=70) | 50 / 13 / 3 (n=70) |

**Harness designs** (Float64 PGD; cells are `converged=true` / target missed / false success = `converged=true` and missed, out of n)

| profile | 637f06a + PB c123d56, 1.10.13 | 9f86a80 + PB 50db4b1, 1.10.13 | dac9f4b + PB a19c59a, 1.10.13 | 637f06a + PB c123d56, 1.13.3 | 9f86a80 + PB 50db4b1, 1.13.3 | dac9f4b + PB a19c59a, 1.13.3 |
|---|---|---|---|---|---|---|
| H | 15 / 4 / 0 (n=50) | 14 / 4 / 0 (n=50) | 14 / 4 / 0 (n=50) | 16 / 5 / 0 (n=50) | 17 / 5 / 0 (n=50) | 17 / 5 / 0 (n=50) |
| D | 50 / 50 / 50 (n=50) | 50 / 50 / 50 (n=50) | 50 / 50 / 50 (n=50) | 50 / 50 / 50 (n=50) | 50 / 50 / 50 (n=50) | 50 / 50 / 50 (n=50) |
| S | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) |
| A | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) |
| Q | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) |

**Adverse set** (Float64 PGD; cells are `converged=true` / target missed / false success = `converged=true` and missed, out of n)

| profile | 637f06a + PB c123d56, 1.10.13 | 9f86a80 + PB 50db4b1, 1.10.13 | dac9f4b + PB a19c59a, 1.10.13 | 637f06a + PB c123d56, 1.13.3 | 9f86a80 + PB 50db4b1, 1.13.3 | dac9f4b + PB a19c59a, 1.13.3 |
|---|---|---|---|---|---|---|
| H | 2 / 58 / 0 (n=70) | 2 / 58 / 0 (n=70) | 2 / 58 / 0 (n=70) | 0 / 63 / 0 (n=70) | 0 / 62 / 0 (n=70) | 0 / 62 / 0 (n=70) |
| D | 35 / 70 / 35 (n=70) | 35 / 70 / 35 (n=70) | 35 / 70 / 35 (n=70) | 41 / 70 / 41 (n=70) | 41 / 70 / 41 (n=70) | 41 / 70 / 41 (n=70) |
| S | 54 / 16 / 0 (n=70) | 54 / 16 / 0 (n=70) | 54 / 16 / 0 (n=70) | 58 / 12 / 0 (n=70) | 58 / 12 / 0 (n=70) | 58 / 12 / 0 (n=70) |
| A | 54 / 16 / 0 (n=70) | 54 / 16 / 0 (n=70) | 54 / 16 / 0 (n=70) | 58 / 12 / 0 (n=70) | 58 / 12 / 0 (n=70) | 58 / 12 / 0 (n=70) |
| Q | 54 / 16 / 0 (n=70) | 54 / 16 / 0 (n=70) | 54 / 16 / 0 (n=70) | 58 / 12 / 0 (n=70) | 58 / 12 / 0 (n=70) | 58 / 12 / 0 (n=70) |

**Harness designs** (Float32 APG; cells are `converged=true` / target missed / false success = `converged=true` and missed, out of n)

| profile | 637f06a + PB c123d56, 1.10.13 | 9f86a80 + PB 50db4b1, 1.10.13 | dac9f4b + PB a19c59a, 1.10.13 | 637f06a + PB c123d56, 1.13.3 | 9f86a80 + PB 50db4b1, 1.13.3 | dac9f4b + PB a19c59a, 1.13.3 |
|---|---|---|---|---|---|---|
| H | 35 / 40 / 26 (n=50) | 35 / 40 / 26 (n=50) | 35 / 40 / 26 (n=50) | 35 / 41 / 29 (n=50) | 35 / 41 / 29 (n=50) | 35 / 41 / 29 (n=50) |
| D | 37 / 46 / 33 (n=50) | 37 / 46 / 33 (n=50) | 37 / 46 / 33 (n=50) | 39 / 42 / 32 (n=50) | 39 / 42 / 32 (n=50) | 39 / 42 / 32 (n=50) |
| S | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) |
| A | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) |
| Q | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) | 50 / 0 / 0 (n=50) |

**Adverse set** (Float32 APG; cells are `converged=true` / target missed / false success = `converged=true` and missed, out of n)

| profile | 637f06a + PB c123d56, 1.10.13 | 9f86a80 + PB 50db4b1, 1.10.13 | dac9f4b + PB a19c59a, 1.10.13 | 637f06a + PB c123d56, 1.13.3 | 9f86a80 + PB 50db4b1, 1.13.3 | dac9f4b + PB a19c59a, 1.13.3 |
|---|---|---|---|---|---|---|
| H | 19 / 70 / 19 (n=70) | 19 / 70 / 19 (n=70) | 19 / 70 / 19 (n=70) | 19 / 69 / 19 (n=70) | 19 / 69 / 19 (n=70) | 19 / 69 / 19 (n=70) |
| D | 23 / 70 / 23 (n=70) | 23 / 70 / 23 (n=70) | 23 / 70 / 23 (n=70) | 24 / 69 / 24 (n=70) | 24 / 69 / 24 (n=70) | 24 / 69 / 24 (n=70) |
| S | 13 / 5 / 0 (n=70) | 13 / 5 / 0 (n=70) | 13 / 5 / 0 (n=70) | 11 / 3 / 0 (n=70) | 11 / 3 / 0 (n=70) | 11 / 3 / 0 (n=70) |
| A | 13 / 5 / 0 (n=70) | 13 / 5 / 0 (n=70) | 13 / 5 / 0 (n=70) | 11 / 3 / 0 (n=70) | 11 / 3 / 0 (n=70) | 11 / 3 / 0 (n=70) |
| Q | 57 / 11 / 9 (n=70) | 57 / 11 / 9 (n=70) | 57 / 11 / 9 (n=70) | 54 / 8 / 8 (n=70) | 54 / 8 / 8 (n=70) | 54 / 8 / 8 (n=70) |

**Per design, Float32 PGD, harness settings H, master (dac9f4b): `converged=true` / missed / false success (n=10 per cell)**

| design | 1.10.13 | 1.13.3 |
|---|---|---|
| lasso | 8 / 8 / 6 | 8 / 6 / 4 |
| lasso-B | 5 / 10 / 5 | 5 / 9 / 4 |
| lasso-B-warm | 6 / 9 / 5 | 3 / 9 / 2 |
| lasso-C | 8 / 7 / 5 | 4 / 9 / 3 |
| lasso-D | 9 / 5 / 4 | 8 / 4 / 3 |
| adv-cor-low-cold | 1 / 10 / 1 | 2 / 10 / 2 |
| adv-cor-low-warm | 0 / 10 / 0 | 1 / 10 / 1 |
| adv-equi-low-cold | 0 / 10 / 0 | 1 / 10 / 1 |
| adv-ill-mid-cold | 1 / 9 / 0 | 1 / 9 / 0 |
| adv-ill-low-cold | 0 / 10 / 0 | 0 / 10 / 0 |
| adv-ill-low-warm | 0 / 10 / 0 | 0 / 10 / 0 |
| adv-wide-low-cold | 3 / 10 / 3 | 4 / 10 / 4 |

**Mechanism of the missed records, Float32 PGD, harness settings H (Harness designs)**

| class | 637f06a + PB c123d56, 1.10.13 | 9f86a80 + PB 50db4b1, 1.10.13 | dac9f4b + PB a19c59a, 1.10.13 | 637f06a + PB c123d56, 1.13.3 | 9f86a80 + PB 50db4b1, 1.13.3 | dac9f4b + PB a19c59a, 1.13.3 |
|---|---|---|---|---|---|---|
| false convergence: objective test proposed (one-ulp), stationarity check accepted | 3 | 3 | 3 | 3 | 2 | 2 |
| false convergence: objective test proposed (one-ulp), stationarity check accepted after earlier refusals | 9 | 11 | 11 | 5 | 7 | 7 |
| false convergence: objective test proposed (relative+one-ulp), stationarity check accepted | 2 | 3 | 3 | 1 | 1 | 1 |
| false convergence: objective test proposed (relative+one-ulp), stationarity check accepted after earlier refusals | 8 | 8 | 8 | 6 | 6 | 6 |
| truthful stop on a rounding-level objective increase, stationarity check had refused 1 or more proposal(s) | 14 | 14 | 14 | 20 | 19 | 19 |
| truthful stop on a rounding-level objective increase, stationarity check had refused no (none made) proposal(s) | 0 | 0 | 0 | 2 | 2 | 2 |
| **total missed** | 36 | 39 | 39 | 37 | 37 | 37 |

**Mechanism of the missed records, Float32 PGD, harness settings H (Adverse set)**

| class | 637f06a + PB c123d56, 1.10.13 | 9f86a80 + PB 50db4b1, 1.10.13 | dac9f4b + PB a19c59a, 1.10.13 | 637f06a + PB c123d56, 1.13.3 | 9f86a80 + PB 50db4b1, 1.13.3 | dac9f4b + PB a19c59a, 1.13.3 |
|---|---|---|---|---|---|---|
| false convergence: objective test proposed (one-ulp), stationarity check accepted after earlier refusals | 2 | 2 | 2 | 4 | 5 | 5 |
| false convergence: objective test proposed (relative+one-ulp), stationarity check accepted after earlier refusals | 2 | 2 | 2 | 2 | 3 | 3 |
| truthful stop on a rounding-level objective increase, stationarity check had refused 1 or more proposal(s) | 63 | 63 | 63 | 59 | 57 | 57 |
| truthful stop: maxiter | 2 | 2 | 2 | 4 | 4 | 4 |
| **total missed** | 69 | 69 | 69 | 69 | 69 | 69 |

**Stationarity check versus the independent KKT residual (Float32 PGD, H)**: among `converged=true` records, the independent normalized KKT residual (Float64, rounded data) relative to the check threshold `64 eps(Float32) = 7.63e-06`

| set | converged=true | independent KKT_rel >= 7.63e-06 | max independent KKT_rel | max gap among converged=true |
|---|---|---|---|---|
| harness | 191 | 0 | 7.616e-06 | 3.753e-05 |
| adverse | 40 | 0 | 7.114e-06 | 3.145e-04 |

Among the 119 false successes on the harness designs (H, Float32 PGD, all arms and versions): gap 1.07e-05 to 3.75e-05 (median 2.39e-05); gap / KKT_rel 2.3 to 7.0 (median 5.0).
Among the 34 false successes on the adverse set: gap 1.06e-04 to 3.14e-04; gap / KKT_rel 16.9 to 47.2 (median 29.5).
Gap at the return of the 486 truthful misses (H, Float32 PGD, harness+adverse): median 7.20e-04, maximum 5.22e-02.

**Accuracy versus work by option profile, Float32 PGD, master (dac9f4b)**: `n`, `converged=true`, missed, false success, truthful misses, median iterations, median products (1 + gradient + prox evaluations + curvature verifications), median iterations after the first iterate that meets the target (k*; negative = the solve returned before it)

| set | Julia | profile | n | converged | missed | false success | truthful miss | iterations med | products med | it after k* med | terminations |
|---|---|---|---|---|---|---|---|---|---|---|---|
| harness | 1.10.13 | D | 50 | 37 | 42 | 29 | 13 | 14 | 35 | -2.0 | f 37, f_increased 13 |
| harness | 1.10.13 | H | 50 | 36 | 39 | 25 | 14 | 14 | 35.5 | -2.0 | f 36, f_increased 14 |
| harness | 1.10.13 | S | 50 | 0 | 0 | 0 | 0 | 28.5 | 75 | 10.0 | stagnated 50 |
| harness | 1.10.13 | A | 50 | 0 | 0 | 0 | 0 | 28.5 | 75 | 10.0 | stagnated 50 |
| harness | 1.10.13 | Q | 50 | 16 | 0 | 0 | 0 | 24.5 | 64.5 | 8.0 | g 16, stagnated 34 |
| harness | 1.13.3 | D | 50 | 31 | 38 | 19 | 19 | 14 | 34.5 | -2 | f 29, f+g 2, f_increased 19 |
| harness | 1.13.3 | H | 50 | 28 | 37 | 16 | 21 | 14 | 34.5 | -2.0 | f 28, f_increased 22 |
| harness | 1.13.3 | S | 50 | 0 | 0 | 0 | 0 | 29.5 | 78.5 | 14.0 | stagnated 50 |
| harness | 1.13.3 | A | 50 | 0 | 0 | 0 | 0 | 29.5 | 78.5 | 14.0 | stagnated 50 |
| harness | 1.13.3 | Q | 50 | 23 | 0 | 0 | 0 | 24 | 63 | 8.5 | g 23, stagnated 27 |
| adverse | 1.10.13 | D | 70 | 6 | 69 | 5 | 64 | 135 | 317 | -33.0 | f 6, f_increased 31, maxiter 33 |
| adverse | 1.10.13 | H | 70 | 5 | 69 | 4 | 65 | 135 | 317 | -30.5 | f 5, f_increased 63, maxiter 2 |
| adverse | 1.10.13 | S | 70 | 0 | 14 | 0 | 14 | 10000 | 23243.5 | 6216.0 | maxiter 40, stagnated 30 |
| adverse | 1.10.13 | A | 70 | 0 | 14 | 0 | 14 | 10000 | 23243.5 | 6216.0 | maxiter 40, stagnated 30 |
| adverse | 1.10.13 | Q | 70 | 53 | 17 | 3 | 14 | 269 | 645.5 | 22.5 | g 53, maxiter 17 |
| adverse | 1.13.3 | D | 70 | 11 | 69 | 10 | 59 | 116.5 | 268 | -33 | f 11, f_increased 32, maxiter 27 |
| adverse | 1.13.3 | H | 70 | 9 | 69 | 8 | 61 | 116.5 | 268 | -33 | f 9, f_increased 57, maxiter 4 |
| adverse | 1.13.3 | S | 70 | 0 | 11 | 0 | 11 | 10000 | 23413 | 7483 | maxiter 41, stagnated 29 |
| adverse | 1.13.3 | A | 70 | 0 | 11 | 0 | 11 | 10000 | 23413 | 7483 | maxiter 41, stagnated 29 |
| adverse | 1.13.3 | Q | 70 | 50 | 13 | 3 | 10 | 285.5 | 672 | 32 | g 50, maxiter 17, stagnated 3 |


## 4. Classification of the missed records

Observed mechanisms (H, Float32 PGD):

| mechanism | evidence (observed) | where |
|---|---|---|
| (1) false convergence | `converged=true`, target missed; objective test proposed, check accepted | 119 of 300 harness records over the six cells (22 to 25 per 50 on 1.10.13, 15 to 16 on 1.13.3); adverse 4 to 8 of 70 |
| (2) truthful nonconvergence | `converged=false`, stop `f_increased` (increases of 1 to 3 spacings of F); the check had refused an earlier proposal in 222 of 240 H records | harness 14 per 50 (1.10.13), 21 to 22 (1.13.3); adverse 57 to 63 of 70; `maxiter` in 2 to 4 of 70 |
| (3) numerical limit of the KKT or gradient evaluation | solver Float32 gradient vs Float64 gradient: at most 2.5e-7 of S; independent KKT_rel below the check threshold at every `converged=true` H record | not observed |
| (4) sensitivity to objective rounding | F identical to the last bit while the independent gap falls (lasso-C draw 7, `9f86a80`, 1.10.13: F = 0.776399076 at iterations 8 and 9 while the gap falls from 4.7e-04 to 1.8e-04; F rises by one spacing at iteration 10, gap 5.97e-05); over the missed harness records the stop falls a median of 2 iterations before k* | the cause of (1) and (2) |
| (5) line search or step size | first accepted L differs by exactly a factor 2 between the arms in 8 of 50 and 6 of 50 harness records and the stop changes only there; L / L_exact at the first accept has median 0.658 (0.150 to 1.257) on the harness designs; the TFOCS mode switch to gradient estimates occurred at or before the H stop in 0 of 100 harness and 12 of 140 adverse records | recorded; refer to #321 |
| (6) target unattainable | S also misses: `adv-ill-low-cold` and `adv-ill-low-warm` only, 25 of 140 solves, all `maxiter`, minimum gap on the 10 000-iteration trajectory above the target | adverse set only; Float64 S/A/Q also miss 16 (1.10.13) and 12 (1.13.3) of 70 on the same designs |

Hypotheses (not established here): (4) arises because the objective error F - F* is second order in the coefficient error while the duality gap is first order in it, so a Float32 objective that resolves one part in 1e7 cannot resolve a relative gap of 1e-5; the trace above is consistent with that, and so are gap / KKT_rel ratios of 2.3 to 7.0. (5): the factor-2 change of the first accepted L is a borderline accept or reject in the first backtracking test under a changed rounding of the loss value; I did not analyse it (#321). `ftol = 0` removes (1) and (2) at the price of never reporting convergence on the harness designs and of long runs on the adverse set (section 5); it is not a fix of the default behaviour.

## 5. Option-only comparison: accuracy, work, time

The table "Accuracy versus work by option profile" in section 3 has the accuracy and work of each profile. Return time versus time to target (master, Float32 PGD):

**Return time and time to target, Float32 PGD, master (dac9f4b), Intel Xeon Silver 4116 (idle node), 1 Julia thread, 1 BLAS thread, minimum over 11 rounds of rotating arms, 5 draws of each of 4 harness designs per Julia version**

Median over the 20 problems of each Julia version of the per-problem ratio (arm minimum time) / (H minimum time); range in brackets. `TTT` = time to target: the solve stopped at k*, the first iterate whose independent gap meets 1e-5.

| arm | 1.10.13 | 1.13.3 |
|---|---|---|
| Haa: H again (A/A control) | 0.998 [0.993, 1.009] | 0.999 [0.991, 1.009] |
| D: D library defaults | 1.001 [0.888, 1.009] | 1.001 [0.933, 1.010] |
| TTT: time to target | 1.018 [0.962, 1.140] | 1.029 [0.889, 1.605] |
| Q: Q (ftol 0, gradtol 1e-7) | 1.530 [1.105, 2.809] | 1.762 [1.173, 3.188] |
| S: S strict stress | 1.623 [1.163, 2.811] | 1.988 [1.294, 4.414] |
| A: A (#314 candidate) | 1.625 [1.164, 2.814] | 1.987 [1.281, 4.419] |

Median minimum return time of H in microseconds, by design (the A/A copy agrees to 0.2%):

| design | 1.10.13 H | 1.10.13 TTT | 1.10.13 S | 1.13.3 H | 1.13.3 TTT | 1.13.3 S |
|---|---|---|---|---|---|---|
| lasso | 27.2 | 29.1 | 48.5 | 19.4 | 20.3 | 57.1 |
| lasso-B | 516.4 | 535.3 | 743.3 | 584.1 | 699.2 | 1086.6 |
| lasso-C | 420.5 | 428.6 | 701.6 | 312.9 | 331.5 | 748.1 |
| lasso-D | 632.3 | 613.3 | 1049.2 | 476.9 | 462.8 | 861.9 |

Warmed allocation per `solve!` (bytes, `Base.gc_bytes` difference of a repeated call) does not depend on the option profile: 
- Julia 1.10.13: 20 of 20 problems allocate the same number of bytes in every arm; range over all runs 2384 to 14864 bytes; exceptions: none
- Julia 1.13.3: 19 of 20 problems allocate the same number of bytes in every arm; range over all runs 2320 to 14744 bytes; exceptions: lasso-D draw 2 {'D': 14616, 'H': 14616, 'Haa': 14616, 'S': 14744, 'A': 14616, 'Q': 14616, 'TTT': 14616}


H returns at about the time to the target (ratio 1.018 and 1.029) but with the accuracy of the section 3 tables; the accurate profiles cost 1.5 to 2 times as much to return, because they continue past the target until stagnation (S, A: median 10 to 14 iterations on the harness designs) or until the gradient test fires at 1e-7 (Q). Allocations do not depend on the profile. The timing covers 4 harness designs x 5 draws on master only; it is not an A/B timing of a code change, since none is proposed.

Exploratory sweep of the gradient test (trajectory-derived only, `ftol 0, xtol 1e-14, allow_f_increases`, not library-run): gradtol 1e-6 reports convergence in 50 of 50 harness solves with 0 misses on both Julia versions, but on the adverse set 56 (1.10.13) and 60 (1.13.3) of 70 report convergence with 37 and 34 missed and 23 and 24 false successes; gradtol 1e-5: 9 and 8 false successes on the harness designs, 39 and 41 on the adverse set; gradtol 1e-8: no harness solve reports convergence, adverse 1 and 0 false successes (21 and 19 report convergence). No gradtol is both reliable and productive, as in #314. The library defaults D are looser than either target by design (every Float64 D harness solve reports convergence above the 1e-8 target), which is not a defect.

## 6. Candidate remedies

Assessed by replaying each rule on the recorded per-iteration quantities of the master Float32 PGD trajectories (the replay reproduces the library's stop of the named profiles in 9 600 of 9 600 records; variants use the probe's widened recomputation of the check's residual, so a count can differ from a library run at a borderline comparison; no variant ran off the recorded trajectory).

**Simulated stopping-rule variants on the recorded Float32 PGD trajectories (master dac9f4b)**: cells are `converged=true` / missed / false success / truthful miss (n = 50 harness, 70 adverse)

| variant | harness 1.10.13 | harness 1.13.3 | adverse 1.10.13 | adverse 1.13.3 |
|---|---|---|---|---|
| H (harness settings) | 36 / 39 / 25 / 14 | 28 / 37 / 16 / 21 | 5 / 69 / 4 / 65 | 9 / 69 / 8 / 61 |
| H, increase <= 4 ulp(F) is noise | 50 / 34 / 34 / 0 | 50 / 34 / 34 / 0 | 60 / 63 / 53 / 10 | 60 / 65 / 55 / 10 |
| H, gate floor 16 eps | 28 / 22 / 2 / 20 | 21 / 28 / 1 / 27 | 2 / 69 / 1 / 68 | 2 / 69 / 2 / 67 |
| H, gate floor 8 eps | 27 / 21 / 0 / 21 | 19 / 27 / 0 / 27 | 2 / 69 / 1 / 68 | 0 / 69 / 0 / 69 |
| H, floor 8 eps + increase<=4 ulp | 50 / 0 / 0 / 0 | 50 / 0 / 0 / 0 | 56 / 59 / 45 / 14 | 60 / 51 / 41 / 10 |
| C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T) | 50 / 0 / 0 / 0 | 50 / 0 / 0 / 0 | 56 / 21 / 7 / 14 | 59 / 27 / 16 / 11 |
| C1b: same with gap <= 5e-6 (T) | 50 / 0 / 0 / 0 | 50 / 0 / 0 / 0 | 54 / 14 / 0 / 14 | 58 / 11 / 0 / 11 |
| C1c: same, idealized independent gap <= 1e-5 | 50 / 0 / 0 / 0 | 50 / 0 / 0 / 0 | 56 / 14 / 0 / 14 | 59 / 11 / 0 / 11 |
| S strict stress | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | 0 / 14 / 0 / 14 | 0 / 11 / 0 / 11 |
| Q (ftol 0, gradtol target/100) | 16 / 0 / 0 / 0 | 23 / 0 / 0 / 0 | 53 / 17 / 3 / 14 | 50 / 13 / 3 / 10 |

(Trajectories ended before a stop for 0 of the simulated variant evaluations above; the others stopped within the recorded trajectory.)


- **A. No code change, documentation.** The solver meets its documented contract: every `converged=true` H record had an independent KKT_rel below the check threshold, and `converged=true` is documented not to be an accuracy certificate. The missed targets come from the harness's gap target being stricter than that contract in Float32 (and unattainable for ill-conditioned low-lambda designs), plus objective rounding that stops solves early with `converged=false`.
- **B. Narrow stop-rule corrections: not justified.** (i) Treating a rounding-level objective increase (at most 4 spacings of F) as noise removes the truthful misses on the harness designs but turns them into false successes (34 of 50 on both versions, 53 and 55 of 70 on the adverse set, against 25 and 16 of 50 and 4 and 8 of 70 now). (ii) Lowering the check's floor from 64 eps to 8 eps removes the harness false successes (0 of 50) but cuts the number of solves that report convergence to 27 and 19 of 50, and on the adverse set 0 to 2 of 70 report convergence. With (i), the harness designs give 50 of 50 converged and 0 misses, but the adverse set has 45 and 41 false successes of 70, because the gap / KKT_rel ratio of the H false successes on the adverse set is 17 to 47, which no residual floor covers. (ii) is a new default tolerance; applied through `max(gradtol, 64 eps(T))` it also changes the Float64 floor (with no effect on the simulated Float64 records) unless it is special-cased to Float32. I found no defect in an individual stop test to correct: the objective tests do what they document (propose a stop on a flat computed objective) and the check refuses what it documents.
- **C. A computable duality-gap stop: costed, not recommended now.** A gap from data the solver already holds (the image `X x`, `y`, the gradient formed for the check, the penalty level) costs two dot products of length n and one pass over p per proposal, no extra matrix product, no hot-path change. In Float32 arithmetic it has no false success on the harness designs (with the increase tolerance of B(i)), but on the adverse set it admits 7 and 16 false successes of 70 at a tolerance equal to the target and 0 at half the target. It underestimated the independent gap by more than a factor 2 on 20 067 of 117 734 recorded iterates with an independent gap between 3e-6 and 3e-5 (all on the adverse set; Float64 accumulation does not remove it: 18 545), because the Float32 image `X x` limits the residual. A trustworthy version needs a widened (Float64) recomputation of `X x` and a user-chosen tolerance (the reserved but refused `gaptol`): the certification machinery this issue excludes, and no protection for a user who does not set it.

## 7. Recommendation

**A: no change to the solvers; documentation only.** The three #319 records are inside a population in which most default Float32 PGD solves miss the target in every arm, so they are not a regression caused by #319 (the number missing is unchanged: 36 to 39 and 37 of 50); `converged=true` is accurate to its contract; no narrow B rule is reliable on the adverse set; C needs a new tolerance and widened arithmetic. A code change would also have to preserve Float64 PGD/APG, rollback, counters, callbacks and APG's certified line search, and nothing here shows a defect to fix.

Proposed documentation PR (separate maintainer GO; coordinate with the docs work in #327 to avoid duplicate text):
- `docs/src/numerics.md`: a short section on Float32 stopping: the objective test (and the objective-increase stop) cannot resolve a relative gap of 1e-5; `converged=true` guarantees only `KKT_rel < max(gradtol, 64 eps(T))`; on the harness designs the gap was up to about 7 times that residual, and 17 to 47 times on the ill-conditioned low-lambda designs; `ftol = 0` with a `gradtol` is accurate on the harness designs but ends on stagnation or the iteration limit and does not certify in Float32; no Float32 `ProximalOptions` is both reliable and productive.
- `src/types.jl` (`ProximalOptions` docstring) and the PGD and APG docstrings in `src/solvers/`: one sentence each pointing to that section, placed next to the sentence that says `converged=true` is not an accuracy certificate. Docstring-only edits.
- `benchmark/HARNESS.md`: state that the default-settings Float32 PGD and APG cases miss the target in 72 to 82% of draws before and after #319 (PGD 72 to 78%, APG 80 to 82%), and that a status change of an individual record is not evidence for or against a change.
- Tests: none for behaviour (no behaviour change); the docs build and the existing docstring checks in CI. No performance requirement beyond "no source change in a hot path", so the 5% gate, Float64 PGD/APG, rollback, counters, callbacks and APG's line search are untouched by construction.
- Risk: documentation can overstate or understate; the numbers come from 10 draws per design on small designs, 3 revisions, two Julia versions and one CPU kind per run.

If the maintainer wants Float32 `converged=true` to imply a gap bound, that is a feature decision (option C with a widened product and an opt-in tolerance) needing its own design and approval; this report does not propose it.

## 8. Remaining uncertainties

- Ten draws per design, five harness designs and one adverse set of my own choosing (preregistered); other sizes, lambda levels, sparse designs and iterate types are not covered. The adverse set was chosen to be hard.
- Julia 1.13.3 environments were resolved fresh; CPU kind matters little for Float32 PGD here (3 of 240 status flips) but a lot for Float64 PGD (30 of 240).
- The replay of rule variants uses a widened recomputation of the check's residual; variants are not library runs. The replay of the named profiles agrees with the library in all 9 600 records.
- Timing covers 20 problems per Julia version on one CPU kind and one revision; allocation figures are `Base.gc_bytes` differences of a warmed call.
- The explanations of (4) and of the factor-2 first-L changes (5) are hypotheses (section 4); the observed counts do not depend on them.
- #309 (TFOCS mode switch): in the harness Float32 PGD records the line search is still in function-value mode at the H stop in 100 of 100 records, so the switch does not affect these stops; I did not evaluate removing it.

(raw per-draw records: kept in the run directory, `raw-per-draw` table)


<details><summary>Raw per-draw records (harness designs and adverse set)</summary>

**Harness designs, Float32 PGD, harness settings H: T/F = `converged`**

| design | draw | 637f06a + PB c123d56, 1.10.13: conv / stop / iter / gap / k* | dac9f4b + PB a19c59a, 1.10.13: conv / stop / iter / gap / k* | 637f06a + PB c123d56, 1.13.3: conv / stop / iter / gap / k* | dac9f4b + PB a19c59a, 1.13.3: conv / stop / iter / gap / k* |
|---|---|---|---|---|---|
| lasso | 1 | T / f / 13 / 2.22e-05 / 14 | T / f / 13 / 2.22e-05 / 14 | T / f / 10 / 2.94e-05 / 11 | T / f / 10 / 2.94e-05 / 11 |
| lasso | 2 | T / f / 11 / 3.08e-05 / 13 | T / f / 11 / 3.08e-05 / 13 | T / f / 10 / 8.07e-06 / 10 | T / f / 10 / 8.07e-06 / 10 |
| lasso | 3 | T / f / 9 / 2.80e-05 / 10 | T / f / 9 / 2.80e-05 / 10 | T / f / 12 / 1.51e-05 / 13 | T / f / 12 / 1.51e-05 / 13 |
| lasso | 4 | F / f_increased / 13 / 9.23e-05 / 15 | F / f_increased / 13 / 9.23e-05 / 15 | T / f / 11 / 3.69e-06 / 10 | T / f / 11 / 3.69e-06 / 10 |
| lasso | 5 | T / f / 11 / 3.81e-06 / 11 | T / f / 11 / 3.81e-06 / 11 | T / f / 9 / 7.71e-06 / 9 | T / f / 9 / 7.71e-06 / 9 |
| lasso | 6 | T / f / 10 / 1.11e-05 / 11 | T / f / 10 / 1.11e-05 / 11 | F / f_increased / 11 / 4.02e-05 / 13 | F / f_increased / 11 / 4.02e-05 / 13 |
| lasso | 7 | T / f / 11 / 2.32e-05 / 12 | T / f / 11 / 2.32e-05 / 12 | F / f_increased / 9 / 1.07e-04 / 12 | F / f_increased / 9 / 1.07e-04 / 12 |
| lasso | 8 | T / f / 10 / 1.32e-06 / 9 | T / f / 10 / 1.32e-06 / 9 | T / f / 9 / 3.69e-05 / 11 | T / f / 9 / 3.69e-05 / 11 |
| lasso | 9 | T / f / 10 / 2.83e-05 / 16 | T / f / 10 / 2.83e-05 / 16 | T / f / 9 / 3.41e-05 / 11 | T / f / 9 / 3.41e-05 / 11 |
| lasso | 10 | F / f_increased / 9 / 5.90e-05 / 11 | F / f_increased / 9 / 5.90e-05 / 11 | T / f / 11 / 9.70e-07 / 11 | T / f / 11 / 9.70e-07 / 11 |
| lasso-B | 1 | T / f / 37 / 2.66e-05 / 38 | T / f / 37 / 2.66e-05 / 38 | T / f / 26 / 8.55e-06 / 26 | T / f / 26 / 8.55e-06 / 26 |
| lasso-B | 2 | T / f / 34 / 2.32e-05 / 35 | T / f / 34 / 2.32e-05 / 35 | T / f / 33 / 4.86e-06 / 33 | T / f / 39 / 3.00e-05 / 40 |
| lasso-B | 3 | T / f / 39 / 3.07e-05 / 41 | T / f / 39 / 3.07e-05 / 41 | F / f_increased / 62 / 4.10e-05 / 68 | F / f_increased / 59 / 2.52e-04 / 75 |
| lasso-B | 4 | F / f_increased / 47 / 1.02e-04 / 51 | F / f_increased / 47 / 1.02e-04 / 51 | F / f_increased / 56 / 1.56e-04 / 67 | F / f_increased / 56 / 1.56e-04 / 67 |
| lasso-B | 5 | T / f / 42 / 2.20e-05 / 43 | T / f / 42 / 2.20e-05 / 43 | F / f_increased / 59 / 1.68e-04 / 73 | F / f_increased / 59 / 1.68e-04 / 73 |
| lasso-B | 6 | F / f_increased / 36 / 2.38e-04 / 48 | F / f_increased / 36 / 2.38e-04 / 48 | F / f_increased / 49 / 2.76e-04 / 63 | F / f_increased / 49 / 2.76e-04 / 63 |
| lasso-B | 7 | F / f_increased / 80 / 1.26e-04 / 98 | F / f_increased / 80 / 1.26e-04 / 98 | T / f / 34 / 2.80e-05 / 35 | T / f / 34 / 2.80e-05 / 35 |
| lasso-B | 8 | F / f_increased / 36 / 2.20e-05 / 38 | F / f_increased / 36 / 2.20e-05 / 38 | F / f_increased / 49 / 8.40e-05 / 65 | F / f_increased / 49 / 8.40e-05 / 65 |
| lasso-B | 9 | T / f / 32 / 3.73e-05 / 34 | T / f / 32 / 3.73e-05 / 34 | T / f / 48 / 3.55e-05 / 50 | T / f / 48 / 3.55e-05 / 50 |
| lasso-B | 10 | F / f_increased / 48 / 1.85e-04 / 60 | F / f_increased / 55 / 1.51e-04 / 67 | T / f / 47 / 2.93e-05 / 49 | T / f / 54 / 2.06e-05 / 56 |
| lasso-B-warm | 1 | F / f_increased / 11 / 5.95e-05 / 13 | T / f / 15 / 2.12e-05 / 16 | T / f / 6 / 3.05e-05 / 7 | T / f / 6 / 3.05e-05 / 7 |
| lasso-B-warm | 2 | T / f / 14 / 2.08e-05 / 15 | T / f / 14 / 2.08e-05 / 15 | T / f / 12 / 2.02e-06 / 12 | T / f / 12 / 2.02e-06 / 12 |
| lasso-B-warm | 3 | T / f / 15 / 2.21e-05 / 17 | T / f / 15 / 2.21e-05 / 17 | F / f_increased / 30 / 2.07e-04 / 45 | F / f_increased / 30 / 2.07e-04 / 45 |
| lasso-B-warm | 4 | F / f_increased / 19 / 1.54e-04 / 23 | F / f_increased / 19 / 1.54e-04 / 23 | F / f_increased / 24 / 4.16e-04 / 48 | F / f_increased / 24 / 4.16e-04 / 48 |
| lasso-B-warm | 5 | T / f / 12 / 3.19e-05 / 13 | T / f / 12 / 3.19e-05 / 13 | F / f_increased / 23 / 4.35e-04 / 42 | F / f_increased / 23 / 4.35e-04 / 42 |
| lasso-B-warm | 6 | T / f / 24 / 3.75e-05 / 31 | T / f / 24 / 3.75e-05 / 31 | F / f_increased / 20 / 4.33e-04 / 37 | F / f_increased / 20 / 4.33e-04 / 37 |
| lasso-B-warm | 7 | F / f_increased / 34 / 3.15e-04 / 58 | F / f_increased / 34 / 3.15e-04 / 58 | T / f / 11 / 1.15e-05 / 12 | T / f / 11 / 1.15e-05 / 12 |
| lasso-B-warm | 8 | F / f_increased / 9 / 5.42e-05 / 12 | F / f_increased / 9 / 5.42e-05 / 12 | F / f_increased / 26 / 2.72e-04 / 44 | F / f_increased / 26 / 2.72e-04 / 44 |
| lasso-B-warm | 9 | T / f / 7 / 7.53e-06 / 7 | T / f / 7 / 7.53e-06 / 7 | F / f_increased / 11 / 3.97e-04 / 20 | F / f_increased / 11 / 3.97e-04 / 20 |
| lasso-B-warm | 10 | F / f_increased / 18 / 6.44e-04 / 31 | F / f_increased / 18 / 6.44e-04 / 31 | F / f_increased / 18 / 6.17e-05 / 21 | F / f_increased / 18 / 6.17e-05 / 21 |
| lasso-C | 1 | T / f / 14 / 1.48e-05 / 15 | T / f / 14 / 1.48e-05 / 15 | T / f / 12 / 2.13e-05 / 13 | T / f / 12 / 2.13e-05 / 13 |
| lasso-C | 2 | T / f / 9 / 6.27e-06 / 9 | T / f / 15 / 1.04e-06 / 15 | T / f / 16 / 2.42e-06 / 16 | T / f / 16 / 2.42e-06 / 16 |
| lasso-C | 3 | T / f / 12 / 5.70e-06 / 12 | T / f / 12 / 5.70e-06 / 12 | F / f_increased / 9 / 2.24e-04 / 13 | F / f_increased / 9 / 2.24e-04 / 13 |
| lasso-C | 4 | T / f / 17 / 1.69e-05 / 19 | T / f / 17 / 1.69e-05 / 19 | F / f_increased / 13 / 1.91e-04 / 21 | F / f_increased / 13 / 1.91e-04 / 21 |
| lasso-C | 5 | T / f / 10 / 1.68e-05 / 11 | T / f / 10 / 1.68e-05 / 11 | F / f_increased / 10 / 7.52e-05 / 12 | F / f_increased / 10 / 7.52e-05 / 12 |
| lasso-C | 6 | T / f / 13 / 5.51e-06 / 13 | T / f / 13 / 5.51e-06 / 13 | F / f_increased / 12 / 4.14e-04 / 18 | F / f_increased / 18 / 5.91e-05 / 19 |
| lasso-C | 7 | T / f / 14 / 1.95e-06 / 14 | F / f_increased / 10 / 5.97e-05 / 12 | F / f_increased / 11 / 3.62e-05 / 12 | F / f_increased / 11 / 3.62e-05 / 12 |
| lasso-C | 8 | T / f / 14 / 3.71e-05 / 16 | T / f / 14 / 3.71e-05 / 16 | T / f / 14 / 3.64e-05 / 16 | T / f / 14 / 3.64e-05 / 16 |
| lasso-C | 9 | T / f / 10 / 2.17e-05 / 11 | T / f / 10 / 2.17e-05 / 11 | F / f_increased / 15 / 1.92e-04 / 18 | F / f_increased / 15 / 1.92e-04 / 18 |
| lasso-C | 10 | F / f_increased / 11 / 1.63e-04 / 14 | F / f_increased / 11 / 1.63e-04 / 14 | T / f / 15 / 2.61e-05 / 17 | T / f / 13 / 1.37e-05 / 14 |
| lasso-D | 1 | T / f / 18 / 2.39e-05 / 19 | T / f / 18 / 2.39e-05 / 19 | T / f / 14 / 4.12e-06 / 14 | T / f / 14 / 4.12e-06 / 14 |
| lasso-D | 2 | T / f / 19 / 3.93e-06 / 19 | T / f / 13 / 1.07e-06 / 13 | T / f / 20 / 7.12e-06 / 20 | T / f / 20 / 7.12e-06 / 20 |
| lasso-D | 3 | T / f / 14 / 8.96e-06 / 14 | T / f / 14 / 8.96e-06 / 14 | T / f / 13 / 9.28e-06 / 13 | T / f / 13 / 9.28e-06 / 13 |
| lasso-D | 4 | T / f / 19 / 8.16e-06 / 19 | T / f / 19 / 8.16e-06 / 19 | T / f / 13 / 1.29e-05 / 14 | T / f / 13 / 1.29e-05 / 14 |
| lasso-D | 5 | T / f / 13 / 2.42e-05 / 14 | T / f / 13 / 2.42e-05 / 14 | T / f / 14 / 9.91e-06 / 14 | T / f / 14 / 9.91e-06 / 14 |
| lasso-D | 6 | F / f_increased / 12 / 8.38e-05 / 13 | F / f_increased / 12 / 8.38e-05 / 13 | F / f_increased / 20 / 1.28e-05 / 21 | F / f_increased / 20 / 1.28e-05 / 21 |
| lasso-D | 7 | F / f_increased / 15 / 6.75e-06 / 15 | T / f / 21 / 1.36e-05 / 22 | F / f_increased / 13 / 6.83e-05 / 14 | F / f_increased / 20 / 6.36e-06 / 20 |
| lasso-D | 8 | T / f / 20 / 1.86e-06 / 20 | T / f / 20 / 1.86e-06 / 20 | T / f / 15 / 1.07e-05 / 16 | T / f / 15 / 1.07e-05 / 16 |
| lasso-D | 9 | T / f / 13 / 6.80e-06 / 13 | T / f / 19 / 1.63e-05 / 20 | T / f / 14 / 1.20e-06 / 14 | T / f / 14 / 1.20e-06 / 14 |
| lasso-D | 10 | T / f / 14 / 4.69e-06 / 14 | T / f / 20 / 8.03e-06 / 20 | T / f / 19 / 2.99e-05 / 20 | T / f / 19 / 2.99e-05 / 20 |

**Adverse set, Float32 PGD, harness settings H, master only**

| design | draw | dac9f4b + PB a19c59a, 1.10.13: conv / stop / iter / gap / k* | dac9f4b + PB a19c59a, 1.13.3: conv / stop / iter / gap / k* |
|---|---|---|---|
| adv-cor-low-cold | 1 | F / f_increased / 86 / 6.59e-04 / 118 | F / f_increased / 111 / 8.40e-04 / 168 |
| adv-cor-low-cold | 2 | F / f_increased / 129 / 1.52e-03 / 208 | F / f_increased / 106 / 3.61e-03 / 130 |
| adv-cor-low-cold | 3 | T / f / 90 / 1.28e-04 / 101 | F / f_increased / 104 / 1.33e-03 / 191 |
| adv-cor-low-cold | 4 | F / f_increased / 74 / 5.93e-04 / 99 | F / f_increased / 93 / 4.35e-04 / 123 |
| adv-cor-low-cold | 5 | F / f_increased / 122 / 7.35e-04 / 148 | T / f / 77 / 2.03e-04 / 87 |
| adv-cor-low-cold | 6 | F / f_increased / 98 / 1.42e-03 / 127 | F / f_increased / 82 / 6.50e-04 / 119 |
| adv-cor-low-cold | 7 | F / f_increased / 90 / 5.09e-04 / 108 | F / f_increased / 78 / 5.78e-04 / 91 |
| adv-cor-low-cold | 8 | F / f_increased / 96 / 7.20e-04 / 133 | T / f / 94 / 2.26e-04 / 113 |
| adv-cor-low-cold | 9 | F / f_increased / 67 / 5.81e-04 / 87 | F / f_increased / 106 / 2.13e-03 / 164 |
| adv-cor-low-cold | 10 | F / f_increased / 109 / 9.82e-04 / 159 | F / f_increased / 90 / 1.18e-03 / 129 |
| adv-cor-low-warm | 1 | F / f_increased / 25 / 9.13e-04 / 59 | F / f_increased / 29 / 1.42e-03 / 94 |
| adv-cor-low-warm | 2 | F / f_increased / 27 / 8.81e-04 / 113 | F / f_increased / 19 / 9.00e-04 / 54 |
| adv-cor-low-warm | 3 | F / f_increased / 15 / 1.96e-04 / 29 | F / f_increased / 21 / 1.24e-03 / 103 |
| adv-cor-low-warm | 4 | F / f_increased / 18 / 1.20e-03 / 41 | F / f_increased / 25 / 4.28e-04 / 58 |
| adv-cor-low-warm | 5 | F / f_increased / 49 / 6.54e-04 / 79 | F / f_increased / 14 / 8.44e-04 / 39 |
| adv-cor-low-warm | 6 | F / f_increased / 18 / 1.05e-03 / 49 | F / f_increased / 18 / 6.01e-04 / 43 |
| adv-cor-low-warm | 7 | F / f_increased / 18 / 3.75e-04 / 42 | T / f / 20 / 3.14e-04 / 33 |
| adv-cor-low-warm | 8 | F / f_increased / 23 / 1.48e-03 / 58 | F / f_increased / 18 / 4.71e-04 / 37 |
| adv-cor-low-warm | 9 | F / f_increased / 15 / 5.76e-04 / 33 | F / f_increased / 24 / 1.45e-03 / 84 |
| adv-cor-low-warm | 10 | F / f_increased / 20 / 6.24e-04 / 69 | F / f_increased / 23 / 5.31e-04 / 54 |
| adv-equi-low-cold | 1 | F / f_increased / 231 / 2.47e-03 / 275 | F / f_increased / 138 / 3.65e-04 / 158 |
| adv-equi-low-cold | 2 | F / f_increased / 227 / 1.00e-03 / 266 | F / f_increased / 187 / 2.79e-04 / 200 |
| adv-equi-low-cold | 3 | F / f_increased / 209 / 8.84e-04 / 241 | F / f_increased / 236 / 6.16e-04 / 270 |
| adv-equi-low-cold | 4 | F / f_increased / 209 / 2.37e-03 / 235 | F / f_increased / 166 / 3.05e-04 / 180 |
| adv-equi-low-cold | 5 | F / f_increased / 201 / 1.03e-03 / 218 | F / f_increased / 141 / 3.91e-04 / 157 |
| adv-equi-low-cold | 6 | F / f_increased / 215 / 2.53e-03 / 273 | F / f_increased / 207 / 1.34e-03 / 255 |
| adv-equi-low-cold | 7 | F / f_increased / 199 / 5.49e-04 / 217 | T / f / 165 / 2.03e-04 / 177 |
| adv-equi-low-cold | 8 | F / f_increased / 215 / 9.58e-04 / 242 | F / f_increased / 181 / 2.48e-03 / 224 |
| adv-equi-low-cold | 9 | F / f_increased / 201 / 6.87e-04 / 211 | F / f_increased / 218 / 1.43e-03 / 285 |
| adv-equi-low-cold | 10 | F / f_increased / 225 / 7.40e-04 / 259 | F / f_increased / 221 / 1.02e-03 / 265 |
| adv-ill-mid-cold | 1 | F / f_increased / 72 / 1.32e-04 / 108 | F / f_increased / 77 / 2.15e-04 / 114 |
| adv-ill-mid-cold | 2 | F / f_increased / 203 / 1.13e-03 / 379 | F / f_increased / 420 / 2.15e-03 / 1034 |
| adv-ill-mid-cold | 3 | F / f_increased / 141 / 5.16e-04 / 229 | F / f_increased / 287 / 1.30e-03 / 579 |
| adv-ill-mid-cold | 4 | F / f_increased / 127 / 2.16e-04 / 222 | F / f_increased / 40 / 1.84e-04 / 60 |
| adv-ill-mid-cold | 5 | F / f_increased / 699 / 4.25e-03 / 1669 | F / f_increased / 15 / 1.03e-04 / 20 |
| adv-ill-mid-cold | 6 | F / f_increased / 247 / 8.52e-04 / 457 | T / f / 10 / 3.32e-07 / 10 |
| adv-ill-mid-cold | 7 | T / f / 13 / 7.28e-07 / 12 | F / f_increased / 735 / 3.70e-03 / 2096 |
| adv-ill-mid-cold | 8 | F / f_increased / 68 / 6.51e-04 / 121 | F / f_increased / 122 / 9.95e-04 / 217 |
| adv-ill-mid-cold | 9 | F / f_increased / 228 / 1.58e-03 / 515 | F / f_increased / 53 / 1.32e-04 / 76 |
| adv-ill-mid-cold | 10 | F / f_increased / 44 / 6.45e-04 / 72 | F / f_increased / 200 / 4.83e-04 / 344 |
| adv-ill-low-cold | 1 | F / f_increased / 1774 / 5.48e-03 / 4887 | F / f_increased / 3644 / 5.59e-03 / -1 |
| adv-ill-low-cold | 2 | F / maxiter / 10000 / 5.22e-02 / -1 | F / maxiter / 10000 / 2.54e-02 / -1 |
| adv-ill-low-cold | 3 | F / maxiter / 10000 / 1.60e-02 / -1 | F / f_increased / 894 / 1.30e-02 / 2294 |
| adv-ill-low-cold | 4 | F / f_increased / 3323 / 5.21e-03 / 9847 | F / f_increased / 9995 / 1.30e-02 / -1 |
| adv-ill-low-cold | 5 | F / f_increased / 9791 / 2.12e-02 / -1 | F / f_increased / 344 / 1.83e-03 / 628 |
| adv-ill-low-cold | 6 | F / f_increased / 7962 / 1.74e-02 / -1 | F / f_increased / 1471 / 2.48e-03 / 3640 |
| adv-ill-low-cold | 7 | F / f_increased / 1040 / 3.90e-03 / -1 | F / maxiter / 10000 / 3.08e-02 / -1 |
| adv-ill-low-cold | 8 | F / f_increased / 2485 / 6.78e-03 / -1 | F / maxiter / 10000 / 2.58e-02 / -1 |
| adv-ill-low-cold | 9 | F / f_increased / 1409 / 1.02e-02 / 3529 | F / f_increased / 596 / 3.53e-03 / 1315 |
| adv-ill-low-cold | 10 | F / f_increased / 4782 / 9.73e-03 / -1 | F / f_increased / 7456 / 1.25e-02 / -1 |
| adv-ill-low-warm | 1 | F / f_increased / 1122 / 3.08e-03 / 4001 | F / f_increased / 2494 / 7.06e-03 / 9430 |
| adv-ill-low-warm | 2 | F / f_increased / 8456 / 3.03e-02 / -1 | F / f_increased / 6069 / 2.18e-02 / -1 |
| adv-ill-low-warm | 3 | F / f_increased / 9481 / 2.05e-02 / -1 | F / f_increased / 461 / 9.17e-03 / 1968 |
| adv-ill-low-warm | 4 | F / f_increased / 2718 / 5.73e-03 / 9317 | F / f_increased / 8851 / 1.29e-02 / -1 |
| adv-ill-low-warm | 5 | F / f_increased / 3494 / 1.83e-02 / -1 | F / f_increased / 171 / 1.72e-03 / 482 |
| adv-ill-low-warm | 6 | F / f_increased / 3661 / 1.44e-02 / -1 | F / f_increased / 862 / 3.79e-03 / 3185 |
| adv-ill-low-warm | 7 | F / f_increased / 558 / 4.57e-03 / -1 | F / f_increased / 4665 / 2.24e-02 / -1 |
| adv-ill-low-warm | 8 | F / f_increased / 2442 / 6.79e-03 / -1 | F / maxiter / 10000 / 2.47e-02 / -1 |
| adv-ill-low-warm | 9 | F / f_increased / 717 / 7.62e-03 / 2995 | F / f_increased / 399 / 2.58e-03 / 1073 |
| adv-ill-low-warm | 10 | F / f_increased / 2479 / 9.72e-03 / -1 | F / f_increased / 5356 / 9.44e-03 / -1 |
| adv-wide-low-cold | 1 | F / f_increased / 53 / 5.86e-04 / 73 | F / f_increased / 56 / 2.73e-04 / 66 |
| adv-wide-low-cold | 2 | F / f_increased / 49 / 2.65e-04 / 59 | F / f_increased / 45 / 3.35e-04 / 55 |
| adv-wide-low-cold | 3 | T / f / 50 / 1.28e-04 / 60 | T / f / 58 / 1.33e-04 / 69 |
| adv-wide-low-cold | 4 | T / f / 51 / 1.06e-04 / 59 | T / f / 43 / 1.28e-04 / 50 |
| adv-wide-low-cold | 5 | F / f_increased / 64 / 2.07e-04 / 76 | F / f_increased / 41 / 3.30e-04 / 50 |
| adv-wide-low-cold | 6 | F / f_increased / 76 / 4.83e-04 / 103 | T / f / 43 / 2.00e-04 / 52 |
| adv-wide-low-cold | 7 | F / f_increased / 60 / 3.61e-04 / 73 | T / f / 49 / 1.70e-04 / 54 |
| adv-wide-low-cold | 8 | T / f / 57 / 2.55e-04 / 70 | F / f_increased / 71 / 7.60e-04 / 89 |
| adv-wide-low-cold | 9 | F / f_increased / 45 / 4.97e-04 / 56 | F / f_increased / 79 / 5.47e-04 / 109 |
| adv-wide-low-cold | 10 | F / f_increased / 52 / 4.17e-04 / 66 | F / f_increased / 58 / 2.34e-04 / 69 |


</details>
