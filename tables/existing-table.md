# Per-configuration baseline table (existing records, PS 637f06a)

Counts are repetitions (runs) unless marked cases. `worst cert / target` is the largest worst certificate over the configuration's cases divided by their target (> 1 means at least one sample missed). `timed` = cases with every run ok and a finite target, the only cases that get a time in the readout. Copied from cross_solver.csv; no ranking, no between-solver statistics.

## Julia 1.10.13

| Configuration | Settings | Cases | Ok runs / total | Target missed (runs; cases) | Error | Timeout | Uncertifiable / incomplete | Worst cert / target | Timed cases |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| apg acc-dense-f64 | accuracy | 4 | 40 / 40 | 0; 0 | 0 | 0 | 0 | 0.0338 | 4 / 4 |
| apg acc-warm-dense-f64 | accuracy | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | 0.00561 | 1 / 1 |
| pg acc-dense-f64 | accuracy | 4 | 40 / 40 | 0; 0 | 0 | 0 | 0 | 0.024 | 4 / 4 |
| pg acc-warm-dense-f64 | accuracy | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | 0.00827 | 1 / 1 |
| apg dense-f32 | default | 4 | 9 / 40 | 31; 4 | 0 | 0 | 0 | 31.5 | 0 / 4 |
| apg dense-f64 | default | 4 | 39 / 40 | 1; 1 | 0 | 0 | 0 | 1.25 | 3 / 4 |
| apg warm-dense-f32 | default | 1 | 1 / 10 | 9; 1 | 0 | 0 | 0 | 33.3 | 0 / 1 |
| apg warm-dense-f64 | default | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | 0.611 | 1 / 1 |
| cd dense-f32 | default | 4 | 40 / 40 | 0; 0 | 0 | 0 | 0 | 0.32 | 4 / 4 |
| cd dense-f64 | default | 4 | 40 / 40 | 0; 0 | 0 | 0 | 0 | 0.00317 | 4 / 4 |
| cd sparse-f32 | default | 4 | 40 / 40 | 0; 0 | 0 | 0 | 0 | 0.32 | 4 / 4 |
| cd sparse-f64 | default | 4 | 40 / 40 | 0; 0 | 0 | 0 | 0 | 0.00317 | 4 / 4 |
| cd warm-dense-f32 | default | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | 0.137 | 1 / 1 |
| cd warm-dense-f64 | default | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | 0.00332 | 1 / 1 |
| cd warm-sparse-f32 | default | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | 0.137 | 1 / 1 |
| cd warm-sparse-f64 | default | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | 0.00332 | 1 / 1 |
| pg dense-f32 | default | 4 | 13 / 40 | 27; 4 | 0 | 0 | 0 | 23.8 | 0 / 4 |
| pg dense-f64 | default | 4 | 38 / 40 | 2; 2 | 0 | 0 | 0 | 2.74 | 2 / 4 |
| pg warm-dense-f32 | default | 1 | 1 / 10 | 9; 1 | 0 | 0 | 0 | 64.4 | 0 / 1 |
| pg warm-dense-f64 | default | 1 | 8 / 10 | 2; 1 | 0 | 0 | 0 | 1.09 | 0 / 1 |
| cd R | record-only | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | n/a | 0 / 1 |
| pg R | record-only | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | n/a | 0 / 1 |

### Exclusions, Julia 1.10.13

- **no finite target (accuracy recorded only)** (2 cases): `cd/lasso-dense/cd/R/call` (10/10 ok, worst 5.75e-08); `gradient/lasso/pg/R/call` (10/10 ok, worst 2.88e-05)
- **target missed, default settings, f32** (10 cases): `gradient/lasso-B/apg/dense-f32/call` (0/10 ok, worst 0.000315); `gradient/lasso-B/apg/warm-dense-f32/call` (1/10 ok, worst 0.000333); `gradient/lasso-B/pg/dense-f32/call` (0/10 ok, worst 0.000238); `gradient/lasso-B/pg/warm-dense-f32/call` (1/10 ok, worst 0.000644); `gradient/lasso-C/apg/dense-f32/call` (4/10 ok, worst 6.82e-05); `gradient/lasso-C/pg/dense-f32/call` (4/10 ok, worst 0.000163); `gradient/lasso-D/apg/dense-f32/call` (3/10 ok, worst 3.44e-05); `gradient/lasso-D/pg/dense-f32/call` (7/10 ok, worst 8.38e-05); `gradient/lasso/apg/dense-f32/call` (2/10 ok, worst 9.1e-05); `gradient/lasso/pg/dense-f32/call` (2/10 ok, worst 9.23e-05)
- **target missed, default settings, f64** (4 cases): `gradient/lasso-B/pg/dense-f64/call` (9/10 ok, worst 2.74e-08); `gradient/lasso-B/pg/warm-dense-f64/call` (8/10 ok, worst 1.09e-08); `gradient/lasso-D/pg/dense-f64/call` (9/10 ok, worst 1.16e-08); `gradient/lasso/apg/dense-f64/call` (9/10 ok, worst 1.25e-08)

## Julia 1.13.3

| Configuration | Settings | Cases | Ok runs / total | Target missed (runs; cases) | Error | Timeout | Uncertifiable / incomplete | Worst cert / target | Timed cases |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| apg acc-dense-f64 | accuracy | 4 | 40 / 40 | 0; 0 | 0 | 0 | 0 | 0.0535 | 4 / 4 |
| apg acc-warm-dense-f64 | accuracy | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | 0.0076 | 1 / 1 |
| pg acc-dense-f64 | accuracy | 4 | 40 / 40 | 0; 0 | 0 | 0 | 0 | 0.0181 | 4 / 4 |
| pg acc-warm-dense-f64 | accuracy | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | 0.00727 | 1 / 1 |
| apg dense-f32 | default | 4 | 7 / 40 | 33; 4 | 0 | 0 | 0 | 29 | 0 / 4 |
| apg dense-f64 | default | 4 | 40 / 40 | 0; 0 | 0 | 0 | 0 | 0.482 | 4 / 4 |
| apg warm-dense-f32 | default | 1 | 2 / 10 | 8; 1 | 0 | 0 | 0 | 25.4 | 0 / 1 |
| apg warm-dense-f64 | default | 1 | 8 / 10 | 2; 1 | 0 | 0 | 0 | 1.35 | 0 / 1 |
| cd dense-f32 | default | 4 | 40 / 40 | 0; 0 | 0 | 0 | 0 | 0.291 | 4 / 4 |
| cd dense-f64 | default | 4 | 40 / 40 | 0; 0 | 0 | 0 | 0 | 0.00107 | 4 / 4 |
| cd sparse-f32 | default | 4 | 40 / 40 | 0; 0 | 0 | 0 | 0 | 0.291 | 4 / 4 |
| cd sparse-f64 | default | 4 | 40 / 40 | 0; 0 | 0 | 0 | 0 | 0.00107 | 4 / 4 |
| cd warm-dense-f32 | default | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | 0.289 | 1 / 1 |
| cd warm-dense-f64 | default | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | 0.00263 | 1 / 1 |
| cd warm-sparse-f32 | default | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | 0.289 | 1 / 1 |
| cd warm-sparse-f64 | default | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | 0.00263 | 1 / 1 |
| pg dense-f32 | default | 4 | 12 / 40 | 28; 4 | 0 | 0 | 0 | 41.4 | 0 / 4 |
| pg dense-f64 | default | 4 | 36 / 40 | 4; 2 | 0 | 0 | 0 | 2.16 | 2 / 4 |
| pg warm-dense-f32 | default | 1 | 1 / 10 | 9; 1 | 0 | 0 | 0 | 43.5 | 0 / 1 |
| pg warm-dense-f64 | default | 1 | 9 / 10 | 1; 1 | 0 | 0 | 0 | 2.36 | 0 / 1 |
| cd R | record-only | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | n/a | 0 / 1 |
| pg R | record-only | 1 | 10 / 10 | 0; 0 | 0 | 0 | 0 | n/a | 0 / 1 |

### Exclusions, Julia 1.13.3

- **no finite target (accuracy recorded only)** (2 cases): `cd/lasso-dense/cd/R/call` (10/10 ok, worst 5.75e-08); `gradient/lasso/pg/R/call` (10/10 ok, worst 3e-05)
- **target missed, default settings, f32** (10 cases): `gradient/lasso-B/apg/dense-f32/call` (1/10 ok, worst 0.000259); `gradient/lasso-B/apg/warm-dense-f32/call` (2/10 ok, worst 0.000254); `gradient/lasso-B/pg/dense-f32/call` (2/10 ok, worst 0.000276); `gradient/lasso-B/pg/warm-dense-f32/call` (1/10 ok, worst 0.000435); `gradient/lasso-C/apg/dense-f32/call` (2/10 ok, worst 0.00029); `gradient/lasso-C/pg/dense-f32/call` (1/10 ok, worst 0.000414); `gradient/lasso-D/apg/dense-f32/call` (3/10 ok, worst 4.15e-05); `gradient/lasso-D/pg/dense-f32/call` (5/10 ok, worst 6.83e-05); `gradient/lasso/apg/dense-f32/call` (1/10 ok, worst 9.67e-05); `gradient/lasso/pg/dense-f32/call` (4/10 ok, worst 0.000107)
- **target missed, default settings, f64** (4 cases): `gradient/lasso-B/apg/warm-dense-f64/call` (8/10 ok, worst 1.35e-08); `gradient/lasso-B/pg/dense-f64/call` (7/10 ok, worst 2.16e-08); `gradient/lasso-B/pg/warm-dense-f64/call` (9/10 ok, worst 2.36e-08); `gradient/lasso-C/pg/dense-f64/call` (9/10 ok, worst 1e-08)
