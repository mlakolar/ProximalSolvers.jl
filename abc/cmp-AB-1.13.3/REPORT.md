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
| cd/lasso-B/cd/dense-f32/call | 1.13.3 | 1.00194 [0.988388, 1.01568] | 2.90908e-06 / 2.90908e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/dense-f64/call | 1.13.3 | 1.01039 [0.98292, 1.03863] | 1.06546e-11 / 1.06546e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/sparse-f32/call | 1.13.3 | 1.0029 [0.982041, 1.02421] | 2.90908e-06 / 2.90908e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/sparse-f64/call | 1.13.3 | 0.987128 [0.969019, 1.00558] | 1.06546e-11 / 1.06546e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/warm-dense-f32/call | 1.13.3 | 1.00995 [0.980374, 1.04043] | 2.89053e-06 / 2.89053e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/warm-dense-f64/call | 1.13.3 | 1.00109 [0.982265, 1.02027] | 2.62505e-11 / 2.62505e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.13.3 | 1.02547 [0.994773, 1.05712] | 2.89053e-06 / 2.89053e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.13.3 | 0.985429 [0.956158, 1.0156] | 2.62505e-11 / 2.62505e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-C/cd/dense-f32/call | 1.13.3 | 0.990181 [0.979948, 1.00052] | 4.79371e-07 / 4.79371e-07 | 7096 / 7096 | inconclusive |
| cd/lasso-C/cd/dense-f64/call | 1.13.3 | 1.001 [0.997682, 1.00432] | 7.24643e-12 / 7.24643e-12 | 11256 / 11256 | inconclusive |
| cd/lasso-C/cd/sparse-f32/call | 1.13.3 | 0.993305 [0.987142, 0.999507] | 4.79371e-07 / 4.79371e-07 | 7096 / 7096 | faster |
| cd/lasso-C/cd/sparse-f64/call | 1.13.3 | 0.996496 [0.993118, 0.999885] | 7.24643e-12 / 7.24643e-12 | 11256 / 11256 | faster |
| cd/lasso-D/cd/dense-f32/call | 1.13.3 | 0.99998 [0.991754, 1.00827] | 4.3274e-07 / 4.3274e-07 | 16192 / 16192 | inconclusive |
| cd/lasso-D/cd/dense-f64/call | 1.13.3 | 0.988019 [0.973754, 1.00249] | 4.40968e-13 / 4.40968e-13 | 21632 / 21632 | inconclusive |
| cd/lasso-D/cd/sparse-f32/call | 1.13.3 | 0.989796 [0.953692, 1.02727] | 4.3274e-07 / 4.3274e-07 | 16192 / 16192 | inconclusive |
| cd/lasso-D/cd/sparse-f64/call | 1.13.3 | 0.995447 [0.974744, 1.01659] | 4.40968e-13 / 4.40968e-13 | 21632 / 21632 | inconclusive |
| cd/lasso-dense/cd/R/call | 1.13.3 | 0.99674 [0.978078, 1.01576] | 5.75233e-08 / 5.75233e-08 | 6752 / 6752 | inconclusive |
| cd/lasso/cd/dense-f32/call | 1.13.3 | 0.998996 [0.96593, 1.03319] | 3.57172e-07 / 3.57172e-07 | 2096 / 2096 | inconclusive |
| cd/lasso/cd/dense-f64/call | 1.13.3 | 0.976863 [0.954596, 0.99965] | 1.3083e-12 / 1.3083e-12 | 2832 / 2832 | faster |
| cd/lasso/cd/sparse-f32/call | 1.13.3 | 0.962203 [0.930372, 0.995123] | 3.57172e-07 / 3.57172e-07 | 2096 / 2096 | faster |
| cd/lasso/cd/sparse-f64/call | 1.13.3 | 0.975592 [0.945976, 1.00613] | 1.3083e-12 / 1.3083e-12 | 2832 / 2832 | inconclusive |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.13.3 | 0.9982 [0.965854, 1.03163] | 5.34974e-10 / 5.34974e-10 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.13.3 | 0.999928 [0.955036, 1.04693] | 7.59748e-11 / 7.59748e-11 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.13.3 | 1.00483 [0.971932, 1.03884] | 4.81707e-09 / 4.81707e-09 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.13.3 | 1.01349 [0.98526, 1.04253] | 1.81193e-10 / 1.81193e-10 | 11696 / 11696 | inconclusive |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.13.3 | 1.02254 [0.993661, 1.05226] | 7.27499e-11 / 7.27499e-11 | 11696 / 11696 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.13.3 | 0.998734 [0.995745, 1.00173] | 1.66286e-10 / 1.66286e-10 | 32032 / 32032 | inconclusive |
| gradient/lasso-C/apg/dense-f64/call | 1.13.3 | 0.997507 [0.995687, 0.99933] | 1.8743e-09 / 1.8743e-09 | 32032 / 32032 | faster |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.13.3 | 0.99784 [0.995525, 1.00016] | 1.29959e-10 / 1.29959e-10 | 18752 / 18752 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.13.3 | 0.997547 [0.996171, 0.998924] | 1.36519e-10 / 1.36519e-10 | 31384 / 31384 | faster |
| gradient/lasso-D/apg/dense-f64/call | 1.13.3 | 0.99889 [0.995807, 1.00198] | 3.71883e-09 / 3.71883e-09 | 31384 / 31384 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.13.3 | 0.996432 [0.993983, 0.998887] | 1.41756e-10 / 1.41756e-10 | 28008 / 28008 | faster |
| gradient/lasso-D/pg/dense-f64/call | 1.13.3 | 0.996281 [0.99439, 0.998174] | 4.01926e-09 / 4.01926e-09 | 28008 / 28008 | faster |
| gradient/lasso/apg/acc-dense-f64/call | 1.13.3 | 0.989118 [0.969817, 1.0088] | 1.0779e-10 / 1.0779e-10 | 6256 / 6256 | inconclusive |
| gradient/lasso/apg/dense-f64/call | 1.13.3 | 0.980365 [0.961814, 0.999275] | 2.05048e-09 / 2.05048e-09 | 6256 / 6256 | faster |
| gradient/lasso/pg/R/call | 1.13.3 | 0.998775 [0.984366, 1.0134] | 2.9973e-05 / 2.9973e-05 | 4688 / 4688 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.13.3 | 0.992715 [0.974616, 1.01115] | 1.28759e-10 / 1.28759e-10 | 4064 / 4064 | inconclusive |
| gradient/lasso/pg/dense-f64/call | 1.13.3 | 0.992086 [0.973534, 1.01099] | 2.60529e-09 / 2.60529e-09 | 4064 / 4064 | inconclusive |

## Excluded cases

| Case | Julia | Before reasons | After reasons |
|---|---|---|---|
| gradient/lasso-B/apg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.13.3 | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.13.3 | rep03: target_missed; rep06: target_missed | rep03: target_missed; rep06: target_missed |
| gradient/lasso-B/pg/dense-f32/call | 1.13.3 | rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-B/pg/dense-f64/call | 1.13.3 | rep03: target_missed; rep05: target_missed; rep08: target_missed | rep03: target_missed; rep05: target_missed; rep08: target_missed |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.13.3 | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.13.3 | rep06: target_missed | rep06: target_missed |
| gradient/lasso-C/apg/dense-f32/call | 1.13.3 | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed |
| gradient/lasso-C/pg/dense-f32/call | 1.13.3 | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-C/pg/dense-f64/call | 1.13.3 | rep01: target_missed | rep01: target_missed |
| gradient/lasso-D/apg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed | rep01: target_missed; rep02: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed |
| gradient/lasso-D/pg/dense-f32/call | 1.13.3 | rep04: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep10: target_missed | rep04: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep10: target_missed |
| gradient/lasso/apg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep02: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso/pg/dense-f32/call | 1.13.3 | rep01: target_missed; rep03: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed | rep01: target_missed; rep03: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed |
