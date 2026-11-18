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
