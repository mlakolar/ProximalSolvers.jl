### ['mxd1-2640', 'mxd2-2640'] 637f06a 1.10.13 Float32
| variant | n | conv=true | missed | false success | truthful missed | runs on (traj. ended) | median stop it | median it after k* |
|---|---|---|---|---|---|---|---|---|
| H (harness settings) | 50 | 35 | 36 | 22 | 14 | 0 | 14.0 | -1.0 |
| H, increase <= 2 ulp(F) is noise | 50 | 50 | 31 | 31 | 0 | 0 | 14.0 | -1.0 |
| H, increase <= 4 ulp(F) is noise | 50 | 50 | 31 | 31 | 0 | 0 | 14.0 | -1.0 |
| H, gate floor 32 eps | 50 | 33 | 25 | 10 | 15 | 0 | 14.0 | -0.5 |
| H, gate floor 16 eps | 50 | 28 | 21 | 2 | 19 | 0 | 14.0 | 0.0 |
| H, gate floor 8 eps | 50 | 27 | 20 | 0 | 20 | 0 | 15.0 | 0.0 |
| H, gate floor 4 eps | 50 | 25 | 20 | 0 | 20 | 0 | 15.0 | 0.0 |
| H, floor 8 eps + increase<=4 ulp | 50 | 50 | 0 | 0 | 0 | 0 | 15.5 | 1.0 |
| H + computable gap <= 1e-5 (T arithmetic) | 50 | 28 | 20 | 0 | 20 | 0 | 14.0 | 0.0 |
| H + computable gap <= 1e-5 (Float64 accum.) | 50 | 28 | 20 | 0 | 20 | 0 | 14.0 | 0.0 |
| H + gap <= 1e-5 (independent, idealized) | 50 | 28 | 20 | 0 | 20 | 0 | 14.0 | 0.0 |
| H + computable gap <= 5e-6 (T arithmetic) | 50 | 27 | 20 | 0 | 20 | 0 | 14.0 | 0.0 |
| C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T) | 50 | 50 | 0 | 0 | 0 | 0 | 15.0 | 0.0 |
| C1b: same with gap <= 5e-6 (T) | 50 | 50 | 0 | 0 | 0 | 0 | 15.5 | 1.0 |
| C1c: same, idealized independent gap <= 1e-5 | 50 | 50 | 0 | 0 | 0 | 0 | 15.0 | 0.0 |
| C2: Q + computable gap <= 1e-5 (T) | 50 | 17 | 0 | 0 | 0 | 0 | 23.5 | 8.0 |
| C2b: Q + idealized independent gap <= 1e-5 | 50 | 17 | 0 | 0 | 0 | 0 | 23.5 | 8.0 |
| D (library defaults) | 50 | 37 | 39 | 26 | 13 | 0 | 14.0 | -1.0 |
| S strict stress | 50 | 0 | 0 | 0 | 0 | 0 | 26.0 | 11.0 |
| A (ftol 0, gradtol 1e-10) | 50 | 0 | 0 | 0 | 0 | 0 | 26.0 | 11.0 |
| Q (ftol 0, gradtol target/100) | 50 | 17 | 0 | 0 | 0 | 0 | 23.5 | 8.0 |
### ['mxd1-2640', 'mxd2-2640'] 9f86a80 1.10.13 Float32
| variant | n | conv=true | missed | false success | truthful missed | runs on (traj. ended) | median stop it | median it after k* |
|---|---|---|---|---|---|---|---|---|
| H (harness settings) | 50 | 36 | 39 | 25 | 14 | 0 | 14.0 | -1.0 |
| H, increase <= 2 ulp(F) is noise | 50 | 50 | 34 | 34 | 0 | 0 | 14.5 | -1.0 |
| H, increase <= 4 ulp(F) is noise | 50 | 50 | 34 | 34 | 0 | 0 | 14.5 | -1.0 |
| H, gate floor 32 eps | 50 | 33 | 27 | 11 | 16 | 0 | 14.5 | -1.0 |
| H, gate floor 16 eps | 50 | 28 | 22 | 2 | 20 | 0 | 15.0 | 0.0 |
| H, gate floor 8 eps | 50 | 27 | 21 | 0 | 21 | 0 | 15.0 | 0.0 |
| H, gate floor 4 eps | 50 | 25 | 21 | 0 | 21 | 0 | 15.0 | 0.0 |
| H, floor 8 eps + increase<=4 ulp | 50 | 50 | 0 | 0 | 0 | 0 | 16.0 | 1.0 |
| H + computable gap <= 1e-5 (T arithmetic) | 50 | 28 | 21 | 0 | 21 | 0 | 15.0 | 0.0 |
| H + computable gap <= 1e-5 (Float64 accum.) | 50 | 28 | 21 | 0 | 21 | 0 | 15.0 | 0.0 |
| H + gap <= 1e-5 (independent, idealized) | 50 | 28 | 21 | 0 | 21 | 0 | 15.0 | 0.0 |
| H + computable gap <= 5e-6 (T arithmetic) | 50 | 27 | 21 | 0 | 21 | 0 | 15.0 | 0.0 |
| C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T) | 50 | 50 | 0 | 0 | 0 | 0 | 15.5 | 0.0 |
| C1b: same with gap <= 5e-6 (T) | 50 | 50 | 0 | 0 | 0 | 0 | 16.0 | 1.0 |
| C1c: same, idealized independent gap <= 1e-5 | 50 | 50 | 0 | 0 | 0 | 0 | 15.5 | 0.0 |
| C2: Q + computable gap <= 1e-5 (T) | 50 | 16 | 0 | 0 | 0 | 0 | 24.5 | 8.0 |
| C2b: Q + idealized independent gap <= 1e-5 | 50 | 16 | 0 | 0 | 0 | 0 | 24.5 | 8.0 |
| D (library defaults) | 50 | 37 | 42 | 29 | 13 | 0 | 14.0 | -1.0 |
| S strict stress | 50 | 0 | 0 | 0 | 0 | 0 | 28.5 | 10.0 |
| A (ftol 0, gradtol 1e-10) | 50 | 0 | 0 | 0 | 0 | 0 | 28.5 | 10.0 |
| Q (ftol 0, gradtol target/100) | 50 | 16 | 0 | 0 | 0 | 0 | 24.5 | 8.0 |
### ['mxd1-2640', 'mxd2-2640'] dac9f4b 1.10.13 Float32
| variant | n | conv=true | missed | false success | truthful missed | runs on (traj. ended) | median stop it | median it after k* |
|---|---|---|---|---|---|---|---|---|
| H (harness settings) | 50 | 36 | 39 | 25 | 14 | 0 | 14.0 | -1.0 |
| H, increase <= 2 ulp(F) is noise | 50 | 50 | 34 | 34 | 0 | 0 | 14.5 | -1.0 |
| H, increase <= 4 ulp(F) is noise | 50 | 50 | 34 | 34 | 0 | 0 | 14.5 | -1.0 |
| H, gate floor 32 eps | 50 | 33 | 27 | 11 | 16 | 0 | 14.5 | -1.0 |
| H, gate floor 16 eps | 50 | 28 | 22 | 2 | 20 | 0 | 15.0 | 0.0 |
| H, gate floor 8 eps | 50 | 27 | 21 | 0 | 21 | 0 | 15.0 | 0.0 |
| H, gate floor 4 eps | 50 | 25 | 21 | 0 | 21 | 0 | 15.0 | 0.0 |
| H, floor 8 eps + increase<=4 ulp | 50 | 50 | 0 | 0 | 0 | 0 | 16.0 | 1.0 |
| H + computable gap <= 1e-5 (T arithmetic) | 50 | 28 | 21 | 0 | 21 | 0 | 15.0 | 0.0 |
| H + computable gap <= 1e-5 (Float64 accum.) | 50 | 28 | 21 | 0 | 21 | 0 | 15.0 | 0.0 |
| H + gap <= 1e-5 (independent, idealized) | 50 | 28 | 21 | 0 | 21 | 0 | 15.0 | 0.0 |
| H + computable gap <= 5e-6 (T arithmetic) | 50 | 27 | 21 | 0 | 21 | 0 | 15.0 | 0.0 |
| C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T) | 50 | 50 | 0 | 0 | 0 | 0 | 15.5 | 0.0 |
| C1b: same with gap <= 5e-6 (T) | 50 | 50 | 0 | 0 | 0 | 0 | 16.0 | 1.0 |
| C1c: same, idealized independent gap <= 1e-5 | 50 | 50 | 0 | 0 | 0 | 0 | 15.5 | 0.0 |
| C2: Q + computable gap <= 1e-5 (T) | 50 | 16 | 0 | 0 | 0 | 0 | 24.5 | 8.0 |
| C2b: Q + idealized independent gap <= 1e-5 | 50 | 16 | 0 | 0 | 0 | 0 | 24.5 | 8.0 |
| D (library defaults) | 50 | 37 | 42 | 29 | 13 | 0 | 14.0 | -1.0 |
| S strict stress | 50 | 0 | 0 | 0 | 0 | 0 | 28.5 | 10.0 |
| A (ftol 0, gradtol 1e-10) | 50 | 0 | 0 | 0 | 0 | 0 | 28.5 | 10.0 |
| Q (ftol 0, gradtol target/100) | 50 | 16 | 0 | 0 | 0 | 0 | 24.5 | 8.0 |
### ['mxd1-2640', 'mxd2-2640'] 637f06a 1.13.3 Float32
| variant | n | conv=true | missed | false success | truthful missed | runs on (traj. ended) | median stop it | median it after k* |
|---|---|---|---|---|---|---|---|---|
| H (harness settings) | 50 | 28 | 37 | 15 | 22 | 0 | 14.0 | -1.5 |
| H, increase <= 2 ulp(F) is noise | 50 | 50 | 34 | 34 | 0 | 0 | 15.0 | -1.0 |
| H, increase <= 4 ulp(F) is noise | 50 | 50 | 34 | 34 | 0 | 0 | 15.0 | -1.0 |
| H, gate floor 32 eps | 50 | 25 | 33 | 8 | 25 | 0 | 14.0 | -1.0 |
| H, gate floor 16 eps | 50 | 21 | 29 | 1 | 28 | 0 | 14.5 | -1.0 |
| H, gate floor 8 eps | 50 | 19 | 28 | 0 | 28 | 0 | 15.0 | -1.0 |
| H, gate floor 4 eps | 50 | 17 | 28 | 0 | 28 | 0 | 15.0 | -1.0 |
| H, floor 8 eps + increase<=4 ulp | 50 | 50 | 0 | 0 | 0 | 0 | 16.0 | 1.0 |
| H + computable gap <= 1e-5 (T arithmetic) | 50 | 22 | 28 | 0 | 28 | 0 | 14.0 | -1.0 |
| H + computable gap <= 1e-5 (Float64 accum.) | 50 | 22 | 28 | 0 | 28 | 0 | 14.0 | -1.0 |
| H + gap <= 1e-5 (independent, idealized) | 50 | 22 | 28 | 0 | 28 | 0 | 14.0 | -1.0 |
| H + computable gap <= 5e-6 (T arithmetic) | 50 | 18 | 28 | 0 | 28 | 0 | 14.5 | -1.0 |
| C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T) | 50 | 50 | 0 | 0 | 0 | 0 | 16.0 | 0.0 |
| C1b: same with gap <= 5e-6 (T) | 50 | 50 | 0 | 0 | 0 | 0 | 16.5 | 0.5 |
| C1c: same, idealized independent gap <= 1e-5 | 50 | 50 | 0 | 0 | 0 | 0 | 16.0 | 0.0 |
| C2: Q + computable gap <= 1e-5 (T) | 50 | 22 | 0 | 0 | 0 | 0 | 25.5 | 9.0 |
| C2b: Q + idealized independent gap <= 1e-5 | 50 | 22 | 0 | 0 | 0 | 0 | 25.5 | 9.0 |
| D (library defaults) | 50 | 30 | 38 | 18 | 20 | 0 | 14.0 | -1.5 |
| S strict stress | 50 | 0 | 0 | 0 | 0 | 0 | 30.0 | 14.0 |
| A (ftol 0, gradtol 1e-10) | 50 | 0 | 0 | 0 | 0 | 0 | 30.0 | 14.0 |
| Q (ftol 0, gradtol target/100) | 50 | 22 | 0 | 0 | 0 | 0 | 25.5 | 9.0 |
### ['mxd1-2640', 'mxd2-2640'] 9f86a80 1.13.3 Float32
| variant | n | conv=true | missed | false success | truthful missed | runs on (traj. ended) | median stop it | median it after k* |
|---|---|---|---|---|---|---|---|---|
| H (harness settings) | 50 | 28 | 37 | 16 | 21 | 0 | 14.0 | -1.0 |
| H, increase <= 2 ulp(F) is noise | 50 | 50 | 34 | 34 | 0 | 0 | 15.5 | -1.0 |
| H, increase <= 4 ulp(F) is noise | 50 | 50 | 34 | 34 | 0 | 0 | 15.5 | -1.0 |
| H, gate floor 32 eps | 50 | 25 | 32 | 8 | 24 | 0 | 14.5 | -1.0 |
| H, gate floor 16 eps | 50 | 21 | 28 | 1 | 27 | 0 | 15.0 | -1.0 |
| H, gate floor 8 eps | 50 | 19 | 27 | 0 | 27 | 0 | 15.0 | -1.0 |
| H, gate floor 4 eps | 50 | 18 | 27 | 0 | 27 | 0 | 15.5 | -1.0 |
| H, floor 8 eps + increase<=4 ulp | 50 | 50 | 0 | 0 | 0 | 0 | 16.0 | 1.0 |
| H + computable gap <= 1e-5 (T arithmetic) | 50 | 22 | 27 | 0 | 27 | 0 | 14.5 | -1.0 |
| H + computable gap <= 1e-5 (Float64 accum.) | 50 | 22 | 27 | 0 | 27 | 0 | 14.5 | -1.0 |
| H + gap <= 1e-5 (independent, idealized) | 50 | 22 | 27 | 0 | 27 | 0 | 14.5 | -1.0 |
| H + computable gap <= 5e-6 (T arithmetic) | 50 | 18 | 27 | 0 | 27 | 0 | 15.0 | -1.0 |
| C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T) | 50 | 50 | 0 | 0 | 0 | 0 | 16.0 | 0.0 |
| C1b: same with gap <= 5e-6 (T) | 50 | 50 | 0 | 0 | 0 | 0 | 16.5 | 1.0 |
| C1c: same, idealized independent gap <= 1e-5 | 50 | 50 | 0 | 0 | 0 | 0 | 16.0 | 0.0 |
| C2: Q + computable gap <= 1e-5 (T) | 50 | 23 | 0 | 0 | 0 | 0 | 24.0 | 8.5 |
| C2b: Q + idealized independent gap <= 1e-5 | 50 | 23 | 0 | 0 | 0 | 0 | 24.0 | 8.5 |
| D (library defaults) | 50 | 31 | 38 | 19 | 19 | 0 | 14.0 | -1.0 |
| S strict stress | 50 | 0 | 0 | 0 | 0 | 0 | 29.5 | 14.0 |
| A (ftol 0, gradtol 1e-10) | 50 | 0 | 0 | 0 | 0 | 0 | 29.5 | 14.0 |
| Q (ftol 0, gradtol target/100) | 50 | 23 | 0 | 0 | 0 | 0 | 24.0 | 8.5 |
### ['mxd1-2640', 'mxd2-2640'] dac9f4b 1.13.3 Float32
| variant | n | conv=true | missed | false success | truthful missed | runs on (traj. ended) | median stop it | median it after k* |
|---|---|---|---|---|---|---|---|---|
| H (harness settings) | 50 | 28 | 37 | 16 | 21 | 0 | 14.0 | -1.0 |
| H, increase <= 2 ulp(F) is noise | 50 | 50 | 34 | 34 | 0 | 0 | 15.5 | -1.0 |
| H, increase <= 4 ulp(F) is noise | 50 | 50 | 34 | 34 | 0 | 0 | 15.5 | -1.0 |
| H, gate floor 32 eps | 50 | 25 | 32 | 8 | 24 | 0 | 14.5 | -1.0 |
| H, gate floor 16 eps | 50 | 21 | 28 | 1 | 27 | 0 | 15.0 | -1.0 |
| H, gate floor 8 eps | 50 | 19 | 27 | 0 | 27 | 0 | 15.0 | -1.0 |
| H, gate floor 4 eps | 50 | 18 | 27 | 0 | 27 | 0 | 15.5 | -1.0 |
| H, floor 8 eps + increase<=4 ulp | 50 | 50 | 0 | 0 | 0 | 0 | 16.0 | 1.0 |
| H + computable gap <= 1e-5 (T arithmetic) | 50 | 22 | 27 | 0 | 27 | 0 | 14.5 | -1.0 |
| H + computable gap <= 1e-5 (Float64 accum.) | 50 | 22 | 27 | 0 | 27 | 0 | 14.5 | -1.0 |
| H + gap <= 1e-5 (independent, idealized) | 50 | 22 | 27 | 0 | 27 | 0 | 14.5 | -1.0 |
| H + computable gap <= 5e-6 (T arithmetic) | 50 | 18 | 27 | 0 | 27 | 0 | 15.0 | -1.0 |
| C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T) | 50 | 50 | 0 | 0 | 0 | 0 | 16.0 | 0.0 |
| C1b: same with gap <= 5e-6 (T) | 50 | 50 | 0 | 0 | 0 | 0 | 16.5 | 1.0 |
| C1c: same, idealized independent gap <= 1e-5 | 50 | 50 | 0 | 0 | 0 | 0 | 16.0 | 0.0 |
| C2: Q + computable gap <= 1e-5 (T) | 50 | 23 | 0 | 0 | 0 | 0 | 24.0 | 8.5 |
| C2b: Q + idealized independent gap <= 1e-5 | 50 | 23 | 0 | 0 | 0 | 0 | 24.0 | 8.5 |
| D (library defaults) | 50 | 31 | 38 | 19 | 19 | 0 | 14.0 | -1.0 |
| S strict stress | 50 | 0 | 0 | 0 | 0 | 0 | 29.5 | 14.0 |
| A (ftol 0, gradtol 1e-10) | 50 | 0 | 0 | 0 | 0 | 0 | 29.5 | 14.0 |
| Q (ftol 0, gradtol target/100) | 50 | 23 | 0 | 0 | 0 | 0 | 24.0 | 8.5 |
