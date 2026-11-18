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
