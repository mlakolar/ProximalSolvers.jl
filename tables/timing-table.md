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
