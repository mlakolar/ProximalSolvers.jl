# CROSS-DEPENDENCY comparison (#307)

Produced by compare_crossdep.py: the harness's compare.py with only the declared
ProximalBase identity keys exempted from series matching: proximalbase_version, proximalbase_hash.

| julia | key | before | after |
|---|---|---|---|
| 1.13.3 | proximalbase_hash | 8041f0d0159031ecbe45097cd4239e2609165ff2 | 9b951b73f59e5bbf78b502cdec3c7aa954153b96 |
| 1.13.3 | proximalbase_version | 0.6.0-DEV | 0.6.0-DEV |

# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 38. Excluded cases: 14.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| cd/lasso-B/cd/dense-f32/call | 1.13.3 | 0.998825 [0.989931, 1.0078] | 2.90908e-06 / 2.90908e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/dense-f64/call | 1.13.3 | 1.00713 [0.974481, 1.04088] | 1.06546e-11 / 1.06546e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/sparse-f32/call | 1.13.3 | 1.00046 [0.981777, 1.0195] | 2.90908e-06 / 2.90908e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/sparse-f64/call | 1.13.3 | 0.996921 [0.970386, 1.02418] | 1.06546e-11 / 1.06546e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/warm-dense-f32/call | 1.13.3 | 0.99729 [0.968363, 1.02708] | 2.89053e-06 / 2.89053e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/warm-dense-f64/call | 1.13.3 | 1.0105 [0.98388, 1.03784] | 2.62505e-11 / 2.62505e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.13.3 | 1.02378 [1.0009, 1.04718] | 2.89053e-06 / 2.89053e-06 | 5824 / 5824 | slower |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.13.3 | 0.988498 [0.962181, 1.01553] | 2.62505e-11 / 2.62505e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-C/cd/dense-f32/call | 1.13.3 | 0.989859 [0.9717, 1.00836] | 4.79371e-07 / 4.79371e-07 | 7096 / 7096 | inconclusive |
| cd/lasso-C/cd/dense-f64/call | 1.13.3 | 1.00113 [0.994046, 1.00827] | 7.24643e-12 / 7.24643e-12 | 11256 / 11256 | inconclusive |
| cd/lasso-C/cd/sparse-f32/call | 1.13.3 | 1.00145 [0.993349, 1.00962] | 4.79371e-07 / 4.79371e-07 | 7096 / 7096 | inconclusive |
| cd/lasso-C/cd/sparse-f64/call | 1.13.3 | 1.00184 [0.995964, 1.00775] | 7.24643e-12 / 7.24643e-12 | 11256 / 11256 | inconclusive |
| cd/lasso-D/cd/dense-f32/call | 1.13.3 | 0.999364 [0.990677, 1.00813] | 4.3274e-07 / 4.3274e-07 | 16192 / 16192 | inconclusive |
| cd/lasso-D/cd/dense-f64/call | 1.13.3 | 0.988204 [0.977077, 0.999457] | 4.40968e-13 / 4.40968e-13 | 21632 / 21632 | faster |
| cd/lasso-D/cd/sparse-f32/call | 1.13.3 | 0.998765 [0.985646, 1.01206] | 4.3274e-07 / 4.3274e-07 | 16192 / 16192 | inconclusive |
| cd/lasso-D/cd/sparse-f64/call | 1.13.3 | 0.988276 [0.979193, 0.997444] | 4.40968e-13 / 4.40968e-13 | 21632 / 21632 | faster |
| cd/lasso-dense/cd/R/call | 1.13.3 | 0.990319 [0.964878, 1.01643] | 5.75233e-08 / 5.75233e-08 | 6752 / 6752 | inconclusive |
| cd/lasso/cd/dense-f32/call | 1.13.3 | 1.00975 [0.96047, 1.06155] | 3.57172e-07 / 3.57172e-07 | 2096 / 2096 | inconclusive |
| cd/lasso/cd/dense-f64/call | 1.13.3 | 0.985914 [0.963756, 1.00858] | 1.3083e-12 / 1.3083e-12 | 2832 / 2832 | inconclusive |
| cd/lasso/cd/sparse-f32/call | 1.13.3 | 0.984635 [0.960642, 1.00923] | 3.57172e-07 / 3.57172e-07 | 2096 / 2096 | inconclusive |
| cd/lasso/cd/sparse-f64/call | 1.13.3 | 0.963078 [0.926771, 1.00081] | 1.3083e-12 / 1.3083e-12 | 2832 / 2832 | inconclusive |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.13.3 | 0.984198 [0.953259, 1.01614] | 5.34974e-10 / 5.34974e-10 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.13.3 | 1.01063 [0.98029, 1.04191] | 7.59748e-11 / 7.59748e-11 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.13.3 | 1.0069 [0.98248, 1.03194] | 4.81707e-09 / 4.81707e-09 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.13.3 | 1.01899 [0.977012, 1.06276] | 1.81193e-10 / 1.81193e-10 | 11696 / 11696 | inconclusive |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.13.3 | 1.01941 [0.991336, 1.04828] | 7.27499e-11 / 7.27499e-11 | 11696 / 11696 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.13.3 | 0.998163 [0.995982, 1.00035] | 1.66286e-10 / 1.66286e-10 | 32032 / 32032 | inconclusive |
| gradient/lasso-C/apg/dense-f64/call | 1.13.3 | 0.998026 [0.995507, 1.00055] | 1.8743e-09 / 1.8743e-09 | 32032 / 32032 | inconclusive |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.13.3 | 0.997786 [0.99536, 1.00022] | 1.29959e-10 / 1.29959e-10 | 18752 / 18752 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.13.3 | 0.999779 [0.997921, 1.00164] | 1.36519e-10 / 1.36519e-10 | 31384 / 31384 | inconclusive |
| gradient/lasso-D/apg/dense-f64/call | 1.13.3 | 1.00009 [0.99781, 1.00238] | 3.71883e-09 / 3.71883e-09 | 31384 / 31384 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.13.3 | 0.982194 [0.937052, 1.02951] | 1.41756e-10 / 1.41756e-10 | 28008 / 28008 | inconclusive |
| gradient/lasso-D/pg/dense-f64/call | 1.13.3 | 0.984919 [0.948044, 1.02323] | 4.01926e-09 / 4.01926e-09 | 28008 / 28008 | inconclusive |
| gradient/lasso/apg/acc-dense-f64/call | 1.13.3 | 0.994073 [0.969773, 1.01898] | 1.0779e-10 / 1.0779e-10 | 6256 / 6256 | inconclusive |
| gradient/lasso/apg/dense-f64/call | 1.13.3 | 0.986152 [0.966196, 1.00652] | 2.05048e-09 / 2.05048e-09 | 6256 / 6256 | inconclusive |
| gradient/lasso/pg/R/call | 1.13.3 | 0.997072 [0.975862, 1.01874] | 2.9973e-05 / 2.9973e-05 | 4688 / 4688 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.13.3 | 0.999137 [0.979052, 1.01963] | 1.28759e-10 / 1.28759e-10 | 4064 / 4064 | inconclusive |
| gradient/lasso/pg/dense-f64/call | 1.13.3 | 0.998889 [0.983903, 1.0141] | 2.60529e-09 / 2.60529e-09 | 4064 / 4064 | inconclusive |

## Excluded cases

| Case | Julia | Before reasons | After reasons |
|---|---|---|---|
| gradient/lasso-B/apg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.13.3 | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.13.3 | rep03: target_missed; rep06: target_missed | rep03: target_missed; rep06: target_missed |
| gradient/lasso-B/pg/dense-f32/call | 1.13.3 | rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-B/pg/dense-f64/call | 1.13.3 | rep03: target_missed; rep05: target_missed; rep08: target_missed | rep03: target_missed; rep05: target_missed; rep08: target_missed |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.13.3 | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.13.3 | rep06: target_missed | rep06: target_missed |
| gradient/lasso-C/apg/dense-f32/call | 1.13.3 | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed |
| gradient/lasso-C/pg/dense-f32/call | 1.13.3 | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-C/pg/dense-f64/call | 1.13.3 | rep01: target_missed | rep01: target_missed |
| gradient/lasso-D/apg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed | rep01: target_missed; rep02: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed |
| gradient/lasso-D/pg/dense-f32/call | 1.13.3 | rep04: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep10: target_missed | rep04: target_missed; rep06: target_missed; rep08: target_missed; rep10: target_missed |
| gradient/lasso/apg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep02: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso/pg/dense-f32/call | 1.13.3 | rep01: target_missed; rep03: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed | rep01: target_missed; rep03: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed |
