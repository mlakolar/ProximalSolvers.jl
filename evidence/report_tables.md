untight refs wl1 Float64 {'rankdef': 192, 'yzero': 384}
untight refs linf_sweep Float64 {'rankdef': 144, 'zerocol': 144}
untight refs wl1 Float32 {'rankdef': 192, 'yzero': 384}
untight refs linf_sweep Float32 {'rankdef': 144, 'zerocol': 144}

#### Weighted `NormL1`, Float64: all options, starts, levels, fixtures, both solvers (1.13.4; 1.10.13 in parentheses where it differs)

| Weights | Solves | Converged | Converged with independent ‖G‖∞/S ≥ bound | Max ‖G‖∞/S / bound | Converged, objective above target | Converged, coef. error > 1e-4 (orth, gauss, tall_exact, corr95) | Not converged, within target |
|---|---|---|---|---|---|---|---|
| unweighted (control) | 2976 | 2231 (2234) | 0 | 1.0000 | 215 (218) | 1 | 605 (601) |
| unit | 2976 | 2235 (2238) | 0 | 1.0000 | 215 (218) | 1 | 601 (597) |
| spread 2^[−2,2] | 2976 | 2249 (2248) | 0 | 1.0000 | 216 | 1 | 582 |
| spread + two zeros | 2976 | 2598 (2586) | 0 | 1.0000 | 405 | 34 (36) | 140 (151) |

#### Weighted `NormL1`, Float32: all options, starts, levels, fixtures, both solvers (1.13.4; 1.10.13 in parentheses where it differs)

| Weights | Solves | Converged | Converged with independent ‖G‖∞/S ≥ bound | Max ‖G‖∞/S / bound | Converged, objective above target | Converged, coef. error > 1e-4 (orth, gauss, tall_exact, corr95) | Not converged, within target |
|---|---|---|---|---|---|---|---|
| unweighted (control) | 2976 | 1568 (1532) | 0 | 0.9992 (0.9957) | 101 (99) | 0 | 1150 (1190) |
| unit | 2976 | 1563 (1537) | 0 | 0.9992 | 101 (99) | 0 | 1155 (1185) |
| spread 2^[−2,2] | 2976 | 1598 (1595) | 0 | 0.9990 (0.9907) | 101 (99) | 0 | 1103 (1101) |
| spread + two zeros | 2976 | 1684 (1644) | 0 | 0.9989 (0.9996) | 321 (316) | 30 | 845 (886) |

#### `NormLinf` sweep, Float64: PGD + APG, all levels, fixtures and starts (1.13.4; 1.10.13 in parentheses where it differs)

| Options | Solves | Converged | Converged with independent ∞-norm KKT/S ≥ bound | Max Euclidean KKT/S / bound | Converged, objective above target | Converged, coef. error > 1e-4 (unique ref.) | Not converged, within target |
|---|---|---|---|---|---|---|---|
| default | 624 | 527 | 0 | 3.03 | 109 (110) | 36 | 20 |
| ftol0 | 624 | 465 | 0 | 2.34 | 100 (101) | 59 (58) | 137 |
| gradtol1e-8 | 624 | 541 (538) | 0 | 3.63 (3.13) | 52 | 32 | 43 (46) |
| strict | 624 | 382 | 0 | 3.29 (3.31) | 26 (25) | 0 | 184 (183) |

#### `NormLinf` sweep, Float32: PGD + APG, all levels, fixtures and starts (1.13.4; 1.10.13 in parentheses where it differs)

| Options | Solves | Converged | Converged with independent ∞-norm KKT/S ≥ bound | Max Euclidean KKT/S / bound | Converged, objective above target | Converged, coef. error > 1e-4 (unique ref.) | Not converged, within target |
|---|---|---|---|---|---|---|---|
| default | 624 | 431 (416) | 1 | 2.57 | 45 (42) | 48 (41) | 113 (124) |
| ftol0 | 624 | 234 (223) | 0 | 2.19 | 42 | 39 (36) | 322 (334) |
| gradtol1e-8 | 624 | 393 (385) | 0 | 2.78 | 20 (21) | 38 (34) | 138 (148) |
| strict | 624 | 89 | 0 | 0.40 (0.37) | 5 | 2 (5) | 458 |

#### `NormLinf` criteria along trajectories, Float64 (1.13.4; 1.10.13 in parentheses where it differs)

Each cell: at the first iterate where the criterion is below τ, coefficient error ≤ 1e-4 / fired / trajectories with a unique certified reference. Well-conditioned: orth, gauss, tall_exact, corr95 (160 trajectories); ill-conditioned: colscale, offset (80). Last column: fired with the proved objective lower bound within target / fired, over all 416 trajectories (gap: 328 with λ > 0).

| Criterion | τ | Well-conditioned | Ill-conditioned | Objective within target |
|---|---|---|---|---|
| `gen` | 1e-05 | 151/160/160 | 16/72/80 | 255/390 (254/390) |
| `gen` | 1e-08 | 160/160/160 | 28/60/80 | 328/370 |
| `kkt` | 1e-05 | 160/160/160 | 16/72/80 | 283/386 |
| `kkt` | 1e-08 | 160/160/160 | 28/60/80 | 328/368 |
| `kktl` | 1e-05 | 130/160/160 (131/160/160) | 16/72/80 | 213/396 |
| `kktl` | 1e-08 | 160/160/160 | 28/60/80 | 336/376 |
| `gap` | 1e-05 | 122/128/128 | 16/60/64 | 268/312 |
| `gap` | 1e-08 | 128/128/128 | 36/52/64 | 296/296 |
| `dx` | 1e-05 | 136/160/160 | 16/80/80 | 270/416 (268/416) |
| `dx` | 1e-08 | 160/160/160 | 18/74/80 | 330/400 |
| `df` | 1e-05 | 60/160/160 | 16/80/80 | 106/416 (107/416) |
| `df` | 1e-08 | 120/160/160 | 24/78/80 | 253/413 (255/413) |

#### `NormLinf` criteria along trajectories, Float32 (1.13.4; 1.10.13 in parentheses where it differs)

Each cell: at the first iterate where the criterion is below τ, coefficient error ≤ 1e-4 / fired / trajectories with a unique certified reference. Well-conditioned: orth, gauss, tall_exact, corr95 (160 trajectories); ill-conditioned: colscale, offset (80). Last column: fired with the proved objective lower bound within target / fired, over all 416 trajectories (gap: 328 with λ > 0).

| Criterion | τ | Well-conditioned | Ill-conditioned | Objective within target |
|---|---|---|---|---|
| `gen` | 1e-05 | 144/160/160 (146/160/160) | 16/62/80 | 328/380 |
| `gen` | 1e-08 | 137/137/160 | 16/48/80 | 287/325 (288/326) |
| `kkt` | 1e-05 | 160/160/160 | 16/62/80 | 332/376 |
| `kkt` | 1e-08 | 43/43/160 (46/46/160) | 16/36/80 (16/38/80) | 122/150 (132/160) |
| `kktl` | 1e-05 | 131/160/160 (128/160/160) | 16/62/80 | 334/386 |
| `kktl` | 1e-08 | 95/95/160 (99/99/160) | 16/48/80 | 253/289 (258/294) |
| `gap` | 1e-05 | 117/124/128 (118/124/128) | 16/58/64 | 301/303 (302/304) |
| `gap` | 1e-08 | 62/62/128 (63/63/128) | 16/44/64 | 180/180 (188/188) |
| `dx` | 1e-05 | 134/160/160 | 16/80/80 | 318/416 (320/416) |
| `dx` | 1e-08 | 160/160/160 | 16/69/80 (16/68/80) | 342/392 (341/391) |
| `df` | 1e-05 | 60/160/160 | 16/80/80 | 261/416 |
| `df` | 1e-08 | 99/160/160 (100/160/160) | 16/80/80 | 314/416 (316/416) |
