# #110 A/A campaign: analysis (statistics of PREREGISTRATION-aa110.md)

## j110

- Cases 50; ok in every run on both sides: 46. Input hashes equal A vs B in 500 of 500 case-repetitions.
- Per-case intervals, primary: below 1 3, contains 1 37
- Per-case intervals, diagnostic: contains 1 6, excluded (not ok in every run) 4

| Subset | Cases | G = exp(mean log B/A) | 95% bootstrap over repetitions | Cases with ratio > 1 / < 1 |
|---|---:|---:|---:|---:|
| all primary | 40 | 0.9941 | [0.9869, 1.0016] | 11 / 29 |
| Float64 primary | 26 | 0.9967 | [0.9902, 1.0037] | 8 / 18 |
| Float32 primary | 14 | 0.9893 | [0.9791, 0.9983] | 3 / 11 |

- §12 offset reading (Float64 primary): G = 0.9967, share of cases on the majority side 0.69 → **did not recur in this campaign**.
- Work receipts: 500 of 500 case-repetitions present on both sides; work counters unequal A vs B in 0; receipt data hash differs from the timed record in 0.

| Class | Case | B/A ratio | 95% interval | Interval |
|---|---|---:|---:|---|
| diagnostic | `gradient/lasso-B/apg/dense-f64/call` | 1.0034 | [0.9867, 1.0205] | contains 1 |
| diagnostic | `gradient/lasso-B/apg/warm-dense-f64/call` | 1.0045 | [0.9864, 1.0230] | contains 1 |
| diagnostic | `gradient/lasso-B/pg/dense-f64/call` |  |  | excluded |
| diagnostic | `gradient/lasso-B/pg/warm-dense-f64/call` |  |  | excluded |
| diagnostic | `gradient/lasso-C/apg/dense-f64/call` | 1.0003 | [0.9976, 1.0030] | contains 1 |
| diagnostic | `gradient/lasso-C/pg/dense-f64/call` | 0.9999 | [0.9968, 1.0030] | contains 1 |
| diagnostic | `gradient/lasso-D/apg/dense-f64/call` | 1.0001 | [0.9975, 1.0027] | contains 1 |
| diagnostic | `gradient/lasso-D/pg/dense-f64/call` |  |  | excluded |
| diagnostic | `gradient/lasso/apg/dense-f64/call` |  |  | excluded |
| diagnostic | `gradient/lasso/pg/dense-f64/call` | 0.9963 | [0.9844, 1.0084] | contains 1 |
| primary | `cd/group-lasso/cd/block-f32/call` | 0.9613 | [0.9226, 1.0016] | contains 1 |
| primary | `cd/group-lasso/cd/block-f64/call` | 0.9790 | [0.9615, 0.9968] | below 1 |
| primary | `cd/group-lasso/cd/warm-block-f32/call` | 0.9659 | [0.9333, 0.9998] | below 1 |
| primary | `cd/group-lasso/cd/warm-block-f64/call` | 0.9828 | [0.9521, 1.0145] | contains 1 |
| primary | `cd/lasso-B/cd/dense-f32/call` | 0.9896 | [0.9724, 1.0070] | contains 1 |
| primary | `cd/lasso-B/cd/dense-f64/call` | 0.9854 | [0.9599, 1.0116] | contains 1 |
| primary | `cd/lasso-B/cd/sparse-f32/call` | 0.9945 | [0.9865, 1.0025] | contains 1 |
| primary | `cd/lasso-B/cd/sparse-f64/call` | 1.0025 | [0.9826, 1.0229] | contains 1 |
| primary | `cd/lasso-B/cd/warm-dense-f32/call` | 1.0015 | [0.9736, 1.0301] | contains 1 |
| primary | `cd/lasso-B/cd/warm-dense-f64/call` | 0.9898 | [0.9684, 1.0116] | contains 1 |
| primary | `cd/lasso-B/cd/warm-sparse-f32/call` | 0.9929 | [0.9608, 1.0261] | contains 1 |
| primary | `cd/lasso-B/cd/warm-sparse-f64/call` | 1.0011 | [0.9818, 1.0209] | contains 1 |
| primary | `cd/lasso-C/cd/dense-f32/call` | 0.9929 | [0.9845, 1.0014] | contains 1 |
| primary | `cd/lasso-C/cd/dense-f64/call` | 0.9967 | [0.9839, 1.0097] | contains 1 |
| primary | `cd/lasso-C/cd/sparse-f32/call` | 0.9974 | [0.9853, 1.0098] | contains 1 |
| primary | `cd/lasso-C/cd/sparse-f64/call` | 0.9979 | [0.9861, 1.0098] | contains 1 |
| primary | `cd/lasso-D/cd/dense-f32/call` | 0.9869 | [0.9743, 0.9997] | below 1 |
| primary | `cd/lasso-D/cd/dense-f64/call` | 0.9966 | [0.9768, 1.0167] | contains 1 |
| primary | `cd/lasso-D/cd/sparse-f32/call` | 0.9951 | [0.9883, 1.0020] | contains 1 |
| primary | `cd/lasso-D/cd/sparse-f64/call` | 1.0049 | [0.9863, 1.0239] | contains 1 |
| primary | `cd/lasso-weighted/cd/dense-f32/call` | 0.9853 | [0.9623, 1.0088] | contains 1 |
| primary | `cd/lasso-weighted/cd/dense-f64/call` | 0.9994 | [0.9773, 1.0219] | contains 1 |
| primary | `cd/lasso-weighted/cd/sparse-f32/call` | 1.0089 | [0.9776, 1.0412] | contains 1 |
| primary | `cd/lasso-weighted/cd/sparse-f64/call` | 0.9965 | [0.9577, 1.0369] | contains 1 |
| primary | `cd/lasso/cd/dense-f32/call` | 0.9764 | [0.9392, 1.0151] | contains 1 |
| primary | `cd/lasso/cd/dense-f64/call` | 1.0092 | [0.9920, 1.0266] | contains 1 |
| primary | `cd/lasso/cd/sparse-f32/call` | 1.0033 | [0.9619, 1.0465] | contains 1 |
| primary | `cd/lasso/cd/sparse-f64/call` | 1.0101 | [0.9948, 1.0256] | contains 1 |
| primary | `gradient/lasso-B/apg/acc-dense-f64/call` | 0.9918 | [0.9644, 1.0199] | contains 1 |
| primary | `gradient/lasso-B/apg/acc-warm-dense-f64/call` | 0.9916 | [0.9704, 1.0132] | contains 1 |
| primary | `gradient/lasso-B/pg/acc-dense-f64/call` | 0.9700 | [0.9321, 1.0094] | contains 1 |
| primary | `gradient/lasso-B/pg/acc-warm-dense-f64/call` | 1.0079 | [0.9607, 1.0573] | contains 1 |
| primary | `gradient/lasso-C/apg/acc-dense-f64/call` | 0.9998 | [0.9971, 1.0025] | contains 1 |
| primary | `gradient/lasso-C/pg/acc-dense-f64/call` | 0.9999 | [0.9975, 1.0022] | contains 1 |
| primary | `gradient/lasso-D/apg/acc-dense-f64/call` | 0.9996 | [0.9975, 1.0017] | contains 1 |
| primary | `gradient/lasso-D/pg/acc-dense-f64/call` | 0.9980 | [0.9945, 1.0015] | contains 1 |
| primary | `gradient/lasso-weighted/apg/acc-dense-f64/call` | 1.0095 | [0.9847, 1.0349] | contains 1 |
| primary | `gradient/lasso-weighted/pg/acc-dense-f64/call` | 0.9955 | [0.9831, 1.0081] | contains 1 |
| primary | `gradient/lasso/apg/acc-dense-f64/call` | 0.9979 | [0.9844, 1.0115] | contains 1 |
| primary | `gradient/lasso/pg/acc-dense-f64/call` | 1.0017 | [0.9928, 1.0107] | contains 1 |

## j113

- Cases 50; ok in every run on both sides: 46. Input hashes equal A vs B in 500 of 500 case-repetitions.
- Per-case intervals, primary: contains 1 40
- Per-case intervals, diagnostic: contains 1 6, excluded (not ok in every run) 4

| Subset | Cases | G = exp(mean log B/A) | 95% bootstrap over repetitions | Cases with ratio > 1 / < 1 |
|---|---:|---:|---:|---:|
| all primary | 40 | 0.9997 | [0.9948, 1.0053] | 20 / 20 |
| Float64 primary | 26 | 0.9998 | [0.9938, 1.0054] | 11 / 15 |
| Float32 primary | 14 | 0.9997 | [0.9926, 1.0070] | 9 / 5 |

- §12 offset reading (Float64 primary): G = 0.9998, share of cases on the majority side 0.58 → **did not recur in this campaign**.
- Work receipts: 500 of 500 case-repetitions present on both sides; work counters unequal A vs B in 0; receipt data hash differs from the timed record in 0.

| Class | Case | B/A ratio | 95% interval | Interval |
|---|---|---:|---:|---|
| diagnostic | `gradient/lasso-B/apg/dense-f64/call` | 0.9883 | [0.9440, 1.0346] | contains 1 |
| diagnostic | `gradient/lasso-B/apg/warm-dense-f64/call` |  |  | excluded |
| diagnostic | `gradient/lasso-B/pg/dense-f64/call` |  |  | excluded |
| diagnostic | `gradient/lasso-B/pg/warm-dense-f64/call` |  |  | excluded |
| diagnostic | `gradient/lasso-C/apg/dense-f64/call` | 0.9991 | [0.9962, 1.0021] | contains 1 |
| diagnostic | `gradient/lasso-C/pg/dense-f64/call` |  |  | excluded |
| diagnostic | `gradient/lasso-D/apg/dense-f64/call` | 0.9987 | [0.9962, 1.0013] | contains 1 |
| diagnostic | `gradient/lasso-D/pg/dense-f64/call` | 1.0003 | [0.9982, 1.0024] | contains 1 |
| diagnostic | `gradient/lasso/apg/dense-f64/call` | 1.0075 | [0.9996, 1.0155] | contains 1 |
| diagnostic | `gradient/lasso/pg/dense-f64/call` | 1.0020 | [0.9904, 1.0136] | contains 1 |
| primary | `cd/group-lasso/cd/block-f32/call` | 0.9924 | [0.9664, 1.0192] | contains 1 |
| primary | `cd/group-lasso/cd/block-f64/call` | 0.9974 | [0.9806, 1.0145] | contains 1 |
| primary | `cd/group-lasso/cd/warm-block-f32/call` | 1.0026 | [0.9761, 1.0298] | contains 1 |
| primary | `cd/group-lasso/cd/warm-block-f64/call` | 1.0077 | [0.9811, 1.0350] | contains 1 |
| primary | `cd/lasso-B/cd/dense-f32/call` | 0.9979 | [0.9708, 1.0258] | contains 1 |
| primary | `cd/lasso-B/cd/dense-f64/call` | 0.9808 | [0.9544, 1.0079] | contains 1 |
| primary | `cd/lasso-B/cd/sparse-f32/call` | 1.0023 | [0.9863, 1.0185] | contains 1 |
| primary | `cd/lasso-B/cd/sparse-f64/call` | 1.0101 | [0.9856, 1.0352] | contains 1 |
| primary | `cd/lasso-B/cd/warm-dense-f32/call` | 1.0160 | [0.9909, 1.0416] | contains 1 |
| primary | `cd/lasso-B/cd/warm-dense-f64/call` | 0.9945 | [0.9658, 1.0240] | contains 1 |
| primary | `cd/lasso-B/cd/warm-sparse-f32/call` | 1.0054 | [0.9807, 1.0307] | contains 1 |
| primary | `cd/lasso-B/cd/warm-sparse-f64/call` | 1.0202 | [0.9920, 1.0492] | contains 1 |
| primary | `cd/lasso-C/cd/dense-f32/call` | 1.0045 | [0.9901, 1.0192] | contains 1 |
| primary | `cd/lasso-C/cd/dense-f64/call` | 0.9962 | [0.9880, 1.0045] | contains 1 |
| primary | `cd/lasso-C/cd/sparse-f32/call` | 1.0031 | [0.9915, 1.0148] | contains 1 |
| primary | `cd/lasso-C/cd/sparse-f64/call` | 0.9996 | [0.9930, 1.0062] | contains 1 |
| primary | `cd/lasso-D/cd/dense-f32/call` | 1.0107 | [0.9892, 1.0326] | contains 1 |
| primary | `cd/lasso-D/cd/dense-f64/call` | 0.9894 | [0.9751, 1.0039] | contains 1 |
| primary | `cd/lasso-D/cd/sparse-f32/call` | 1.0015 | [0.9974, 1.0055] | contains 1 |
| primary | `cd/lasso-D/cd/sparse-f64/call` | 1.0008 | [0.9936, 1.0082] | contains 1 |
| primary | `cd/lasso-weighted/cd/dense-f32/call` | 0.9925 | [0.9503, 1.0366] | contains 1 |
| primary | `cd/lasso-weighted/cd/dense-f64/call` | 0.9983 | [0.9699, 1.0274] | contains 1 |
| primary | `cd/lasso-weighted/cd/sparse-f32/call` | 0.9902 | [0.9650, 1.0162] | contains 1 |
| primary | `cd/lasso-weighted/cd/sparse-f64/call` | 1.0194 | [0.9959, 1.0434] | contains 1 |
| primary | `cd/lasso/cd/dense-f32/call` | 1.0057 | [0.9827, 1.0293] | contains 1 |
| primary | `cd/lasso/cd/dense-f64/call` | 0.9830 | [0.9528, 1.0142] | contains 1 |
| primary | `cd/lasso/cd/sparse-f32/call` | 0.9716 | [0.9294, 1.0158] | contains 1 |
| primary | `cd/lasso/cd/sparse-f64/call` | 0.9759 | [0.9519, 1.0006] | contains 1 |
| primary | `gradient/lasso-B/apg/acc-dense-f64/call` | 0.9811 | [0.9366, 1.0276] | contains 1 |
| primary | `gradient/lasso-B/apg/acc-warm-dense-f64/call` | 1.0215 | [0.9846, 1.0597] | contains 1 |
| primary | `gradient/lasso-B/pg/acc-dense-f64/call` | 0.9702 | [0.9206, 1.0225] | contains 1 |
| primary | `gradient/lasso-B/pg/acc-warm-dense-f64/call` | 1.0291 | [0.9870, 1.0731] | contains 1 |
| primary | `gradient/lasso-C/apg/acc-dense-f64/call` | 0.9999 | [0.9969, 1.0029] | contains 1 |
| primary | `gradient/lasso-C/pg/acc-dense-f64/call` | 1.0012 | [0.9979, 1.0045] | contains 1 |
| primary | `gradient/lasso-D/apg/acc-dense-f64/call` | 0.9985 | [0.9959, 1.0011] | contains 1 |
| primary | `gradient/lasso-D/pg/acc-dense-f64/call` | 0.9996 | [0.9972, 1.0020] | contains 1 |
| primary | `gradient/lasso-weighted/apg/acc-dense-f64/call` | 1.0089 | [0.9929, 1.0252] | contains 1 |
| primary | `gradient/lasso-weighted/pg/acc-dense-f64/call` | 0.9961 | [0.9774, 1.0152] | contains 1 |
| primary | `gradient/lasso/apg/acc-dense-f64/call` | 1.0041 | [0.9881, 1.0204] | contains 1 |
| primary | `gradient/lasso/pg/acc-dense-f64/call` | 1.0135 | [0.9979, 1.0294] | contains 1 |

