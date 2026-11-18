### ['advd-2640'] 637f06a 1.10.13 Float32
| variant | n | conv=true | missed | false success | truthful missed | runs on (traj. ended) | median stop it | median it after k* |
|---|---|---|---|---|---|---|---|---|
| H (harness settings) | 70 | 5 | 69 | 4 | 65 | 0 | 135.0 | -30.5 |
| H, increase <= 2 ulp(F) is noise | 70 | 49 | 64 | 43 | 21 | 0 | 181.5 | -17.5 |
| H, increase <= 4 ulp(F) is noise | 70 | 60 | 63 | 53 | 10 | 0 | 204.5 | -16.5 |
| H, gate floor 32 eps | 70 | 4 | 69 | 3 | 66 | 0 | 135.0 | -30.5 |
| H, gate floor 16 eps | 70 | 2 | 69 | 1 | 68 | 0 | 135.0 | -30.5 |
| H, gate floor 8 eps | 70 | 2 | 69 | 1 | 68 | 0 | 135.0 | -30.5 |
| H, gate floor 4 eps | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| H, floor 8 eps + increase<=4 ulp | 70 | 56 | 59 | 45 | 14 | 0 | 210.5 | -4.0 |
| H + computable gap <= 1e-5 (T arithmetic) | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| H + computable gap <= 1e-5 (Float64 accum.) | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| H + gap <= 1e-5 (independent, idealized) | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| H + computable gap <= 5e-6 (T arithmetic) | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T) | 70 | 56 | 21 | 7 | 14 | 0 | 214.0 | 0.0 |
| C1b: same with gap <= 5e-6 (T) | 70 | 54 | 14 | 0 | 14 | 0 | 219.0 | 6.0 |
| C1c: same, idealized independent gap <= 1e-5 | 70 | 56 | 14 | 0 | 14 | 0 | 214.0 | 0.0 |
| C2: Q + computable gap <= 1e-5 (T) | 70 | 53 | 17 | 3 | 14 | 0 | 271.5 | 22.5 |
| C2b: Q + idealized independent gap <= 1e-5 | 70 | 53 | 14 | 0 | 14 | 0 | 271.5 | 27.0 |
| D (library defaults) | 70 | 6 | 69 | 5 | 64 | 0 | 135.0 | -33.0 |
| S strict stress | 70 | 0 | 14 | 0 | 14 | 0 | 10000.0 | 6216.0 |
| A (ftol 0, gradtol 1e-10) | 70 | 0 | 14 | 0 | 14 | 0 | 10000.0 | 6216.0 |
| Q (ftol 0, gradtol target/100) | 70 | 53 | 17 | 3 | 14 | 0 | 271.5 | 22.5 |
### ['advd-2640'] 9f86a80 1.10.13 Float32
| variant | n | conv=true | missed | false success | truthful missed | runs on (traj. ended) | median stop it | median it after k* |
|---|---|---|---|---|---|---|---|---|
| H (harness settings) | 70 | 5 | 69 | 4 | 65 | 0 | 135.0 | -30.5 |
| H, increase <= 2 ulp(F) is noise | 70 | 49 | 64 | 43 | 21 | 0 | 181.5 | -17.5 |
| H, increase <= 4 ulp(F) is noise | 70 | 60 | 63 | 53 | 10 | 0 | 204.5 | -16.5 |
| H, gate floor 32 eps | 70 | 4 | 69 | 3 | 66 | 0 | 135.0 | -30.5 |
| H, gate floor 16 eps | 70 | 2 | 69 | 1 | 68 | 0 | 135.0 | -30.5 |
| H, gate floor 8 eps | 70 | 2 | 69 | 1 | 68 | 0 | 135.0 | -30.5 |
| H, gate floor 4 eps | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| H, floor 8 eps + increase<=4 ulp | 70 | 56 | 59 | 45 | 14 | 0 | 210.5 | -4.0 |
| H + computable gap <= 1e-5 (T arithmetic) | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| H + computable gap <= 1e-5 (Float64 accum.) | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| H + gap <= 1e-5 (independent, idealized) | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| H + computable gap <= 5e-6 (T arithmetic) | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T) | 70 | 56 | 21 | 7 | 14 | 0 | 214.0 | 0.0 |
| C1b: same with gap <= 5e-6 (T) | 70 | 54 | 14 | 0 | 14 | 0 | 219.0 | 6.0 |
| C1c: same, idealized independent gap <= 1e-5 | 70 | 56 | 14 | 0 | 14 | 0 | 214.0 | 0.0 |
| C2: Q + computable gap <= 1e-5 (T) | 70 | 53 | 17 | 3 | 14 | 0 | 269.0 | 22.5 |
| C2b: Q + idealized independent gap <= 1e-5 | 70 | 53 | 14 | 0 | 14 | 0 | 269.0 | 27.0 |
| D (library defaults) | 70 | 6 | 69 | 5 | 64 | 0 | 135.0 | -33.0 |
| S strict stress | 70 | 0 | 14 | 0 | 14 | 0 | 10000.0 | 6216.0 |
| A (ftol 0, gradtol 1e-10) | 70 | 0 | 14 | 0 | 14 | 0 | 10000.0 | 6216.0 |
| Q (ftol 0, gradtol target/100) | 70 | 53 | 17 | 3 | 14 | 0 | 269.0 | 22.5 |
### ['advd-2640'] dac9f4b 1.10.13 Float32
| variant | n | conv=true | missed | false success | truthful missed | runs on (traj. ended) | median stop it | median it after k* |
|---|---|---|---|---|---|---|---|---|
| H (harness settings) | 70 | 5 | 69 | 4 | 65 | 0 | 135.0 | -30.5 |
| H, increase <= 2 ulp(F) is noise | 70 | 49 | 64 | 43 | 21 | 0 | 181.5 | -17.5 |
| H, increase <= 4 ulp(F) is noise | 70 | 60 | 63 | 53 | 10 | 0 | 204.5 | -16.5 |
| H, gate floor 32 eps | 70 | 4 | 69 | 3 | 66 | 0 | 135.0 | -30.5 |
| H, gate floor 16 eps | 70 | 2 | 69 | 1 | 68 | 0 | 135.0 | -30.5 |
| H, gate floor 8 eps | 70 | 2 | 69 | 1 | 68 | 0 | 135.0 | -30.5 |
| H, gate floor 4 eps | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| H, floor 8 eps + increase<=4 ulp | 70 | 56 | 59 | 45 | 14 | 0 | 210.5 | -4.0 |
| H + computable gap <= 1e-5 (T arithmetic) | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| H + computable gap <= 1e-5 (Float64 accum.) | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| H + gap <= 1e-5 (independent, idealized) | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| H + computable gap <= 5e-6 (T arithmetic) | 70 | 1 | 69 | 0 | 69 | 0 | 135.0 | -30.5 |
| C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T) | 70 | 56 | 21 | 7 | 14 | 0 | 214.0 | 0.0 |
| C1b: same with gap <= 5e-6 (T) | 70 | 54 | 14 | 0 | 14 | 0 | 219.0 | 6.0 |
| C1c: same, idealized independent gap <= 1e-5 | 70 | 56 | 14 | 0 | 14 | 0 | 214.0 | 0.0 |
| C2: Q + computable gap <= 1e-5 (T) | 70 | 53 | 17 | 3 | 14 | 0 | 269.0 | 22.5 |
| C2b: Q + idealized independent gap <= 1e-5 | 70 | 53 | 14 | 0 | 14 | 0 | 269.0 | 27.0 |
| D (library defaults) | 70 | 6 | 69 | 5 | 64 | 0 | 135.0 | -33.0 |
| S strict stress | 70 | 0 | 14 | 0 | 14 | 0 | 10000.0 | 6216.0 |
| A (ftol 0, gradtol 1e-10) | 70 | 0 | 14 | 0 | 14 | 0 | 10000.0 | 6216.0 |
| Q (ftol 0, gradtol target/100) | 70 | 53 | 17 | 3 | 14 | 0 | 269.0 | 22.5 |
### ['advd-2640'] 637f06a 1.13.3 Float32
| variant | n | conv=true | missed | false success | truthful missed | runs on (traj. ended) | median stop it | median it after k* |
|---|---|---|---|---|---|---|---|---|
| H (harness settings) | 70 | 7 | 69 | 6 | 63 | 0 | 116.5 | -33 |
| H, increase <= 2 ulp(F) is noise | 70 | 58 | 66 | 54 | 12 | 0 | 144.0 | -20 |
| H, increase <= 4 ulp(F) is noise | 70 | 60 | 65 | 55 | 10 | 0 | 144.0 | -20 |
| H, gate floor 32 eps | 70 | 4 | 69 | 3 | 66 | 0 | 116.5 | -33 |
| H, gate floor 16 eps | 70 | 2 | 69 | 2 | 67 | 0 | 116.5 | -33 |
| H, gate floor 8 eps | 70 | 0 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H, gate floor 4 eps | 70 | 0 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H, floor 8 eps + increase<=4 ulp | 70 | 60 | 52 | 42 | 10 | 0 | 160.5 | -4 |
| H + computable gap <= 1e-5 (T arithmetic) | 70 | 1 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H + computable gap <= 1e-5 (Float64 accum.) | 70 | 1 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H + gap <= 1e-5 (independent, idealized) | 70 | 1 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H + computable gap <= 5e-6 (T arithmetic) | 70 | 1 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T) | 70 | 59 | 26 | 15 | 11 | 0 | 167.5 | 0 |
| C1b: same with gap <= 5e-6 (T) | 70 | 58 | 11 | 0 | 11 | 0 | 171.0 | 6 |
| C1c: same, idealized independent gap <= 1e-5 | 70 | 59 | 11 | 0 | 11 | 0 | 168.0 | 0 |
| C2: Q + computable gap <= 1e-5 (T) | 70 | 48 | 12 | 1 | 11 | 0 | 285.5 | 33 |
| C2b: Q + idealized independent gap <= 1e-5 | 70 | 48 | 11 | 0 | 11 | 0 | 285.5 | 33 |
| D (library defaults) | 70 | 9 | 69 | 8 | 61 | 0 | 116.5 | -33 |
| S strict stress | 70 | 0 | 11 | 0 | 11 | 0 | 10000.0 | 7483 |
| A (ftol 0, gradtol 1e-10) | 70 | 0 | 11 | 0 | 11 | 0 | 10000.0 | 7483 |
| Q (ftol 0, gradtol target/100) | 70 | 49 | 13 | 3 | 10 | 0 | 285.5 | 33 |
### ['advd-2640'] 9f86a80 1.13.3 Float32
| variant | n | conv=true | missed | false success | truthful missed | runs on (traj. ended) | median stop it | median it after k* |
|---|---|---|---|---|---|---|---|---|
| H (harness settings) | 70 | 9 | 69 | 8 | 61 | 0 | 116.5 | -33 |
| H, increase <= 2 ulp(F) is noise | 70 | 58 | 66 | 54 | 12 | 0 | 144.0 | -20 |
| H, increase <= 4 ulp(F) is noise | 70 | 60 | 65 | 55 | 10 | 0 | 144.0 | -20 |
| H, gate floor 32 eps | 70 | 5 | 69 | 4 | 65 | 0 | 116.5 | -33 |
| H, gate floor 16 eps | 70 | 2 | 69 | 2 | 67 | 0 | 116.5 | -33 |
| H, gate floor 8 eps | 70 | 0 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H, gate floor 4 eps | 70 | 0 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H, floor 8 eps + increase<=4 ulp | 70 | 60 | 51 | 41 | 10 | 0 | 158.0 | -5 |
| H + computable gap <= 1e-5 (T arithmetic) | 70 | 1 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H + computable gap <= 1e-5 (Float64 accum.) | 70 | 1 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H + gap <= 1e-5 (independent, idealized) | 70 | 1 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H + computable gap <= 5e-6 (T arithmetic) | 70 | 1 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T) | 70 | 59 | 27 | 16 | 11 | 0 | 165.5 | 0 |
| C1b: same with gap <= 5e-6 (T) | 70 | 58 | 11 | 0 | 11 | 0 | 172.0 | 5 |
| C1c: same, idealized independent gap <= 1e-5 | 70 | 59 | 11 | 0 | 11 | 0 | 166.0 | 0 |
| C2: Q + computable gap <= 1e-5 (T) | 70 | 49 | 12 | 1 | 11 | 0 | 285.5 | 32 |
| C2b: Q + idealized independent gap <= 1e-5 | 70 | 49 | 11 | 0 | 11 | 0 | 285.5 | 32 |
| D (library defaults) | 70 | 11 | 69 | 10 | 59 | 0 | 116.5 | -33 |
| S strict stress | 70 | 0 | 11 | 0 | 11 | 0 | 10000.0 | 7483 |
| A (ftol 0, gradtol 1e-10) | 70 | 0 | 11 | 0 | 11 | 0 | 10000.0 | 7483 |
| Q (ftol 0, gradtol target/100) | 70 | 50 | 13 | 3 | 10 | 0 | 285.5 | 32 |
### ['advd-2640'] dac9f4b 1.13.3 Float32
| variant | n | conv=true | missed | false success | truthful missed | runs on (traj. ended) | median stop it | median it after k* |
|---|---|---|---|---|---|---|---|---|
| H (harness settings) | 70 | 9 | 69 | 8 | 61 | 0 | 116.5 | -33 |
| H, increase <= 2 ulp(F) is noise | 70 | 58 | 66 | 54 | 12 | 0 | 144.0 | -20 |
| H, increase <= 4 ulp(F) is noise | 70 | 60 | 65 | 55 | 10 | 0 | 144.0 | -20 |
| H, gate floor 32 eps | 70 | 5 | 69 | 4 | 65 | 0 | 116.5 | -33 |
| H, gate floor 16 eps | 70 | 2 | 69 | 2 | 67 | 0 | 116.5 | -33 |
| H, gate floor 8 eps | 70 | 0 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H, gate floor 4 eps | 70 | 0 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H, floor 8 eps + increase<=4 ulp | 70 | 60 | 51 | 41 | 10 | 0 | 158.0 | -5 |
| H + computable gap <= 1e-5 (T arithmetic) | 70 | 1 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H + computable gap <= 1e-5 (Float64 accum.) | 70 | 1 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H + gap <= 1e-5 (independent, idealized) | 70 | 1 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| H + computable gap <= 5e-6 (T arithmetic) | 70 | 1 | 69 | 0 | 69 | 0 | 116.5 | -33 |
| C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T) | 70 | 59 | 27 | 16 | 11 | 0 | 165.5 | 0 |
| C1b: same with gap <= 5e-6 (T) | 70 | 58 | 11 | 0 | 11 | 0 | 172.0 | 5 |
| C1c: same, idealized independent gap <= 1e-5 | 70 | 59 | 11 | 0 | 11 | 0 | 166.0 | 0 |
| C2: Q + computable gap <= 1e-5 (T) | 70 | 49 | 12 | 1 | 11 | 0 | 285.5 | 32 |
| C2b: Q + idealized independent gap <= 1e-5 | 70 | 49 | 11 | 0 | 11 | 0 | 285.5 | 32 |
| D (library defaults) | 70 | 11 | 69 | 10 | 59 | 0 | 116.5 | -33 |
| S strict stress | 70 | 0 | 11 | 0 | 11 | 0 | 10000.0 | 7483 |
| A (ftol 0, gradtol 1e-10) | 70 | 0 | 11 | 0 | 11 | 0 | 10000.0 | 7483 |
| Q (ftol 0, gradtol target/100) | 70 | 50 | 13 | 3 | 10 | 0 | 285.5 | 32 |
