# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 38. Excluded cases: 14.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| cd/lasso-B/cd/dense-f32/call | 1.13.3 | 1.01291 [0.991233, 1.03506] | 2.90908e-06 / 2.90908e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/dense-f64/call | 1.13.3 | 1.0205 [0.992773, 1.049] | 1.06546e-11 / 1.06546e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/sparse-f32/call | 1.13.3 | 0.996321 [0.9793, 1.01364] | 2.90908e-06 / 2.90908e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/sparse-f64/call | 1.13.3 | 1.00236 [0.974149, 1.03139] | 1.06546e-11 / 1.06546e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/warm-dense-f32/call | 1.13.3 | 0.982447 [0.945527, 1.02081] | 2.89053e-06 / 2.89053e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/warm-dense-f64/call | 1.13.3 | 1.02401 [0.998025, 1.05066] | 2.62505e-11 / 2.62505e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.13.3 | 1.02039 [0.995133, 1.04629] | 2.89053e-06 / 2.89053e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.13.3 | 1.0098 [0.985552, 1.03464] | 2.62505e-11 / 2.62505e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-C/cd/dense-f32/call | 1.13.3 | 0.992745 [0.975882, 1.0099] | 4.79371e-07 / 4.79371e-07 | 7096 / 7096 | inconclusive |
| cd/lasso-C/cd/dense-f64/call | 1.13.3 | 0.995607 [0.98512, 1.00621] | 7.24643e-12 / 7.24643e-12 | 11256 / 11256 | inconclusive |
| cd/lasso-C/cd/sparse-f32/call | 1.13.3 | 1.00654 [0.999996, 1.01313] | 4.79371e-07 / 4.79371e-07 | 7096 / 7096 | inconclusive |
| cd/lasso-C/cd/sparse-f64/call | 1.13.3 | 0.997996 [0.991901, 1.00413] | 7.24643e-12 / 7.24643e-12 | 11256 / 11256 | inconclusive |
| cd/lasso-D/cd/dense-f32/call | 1.13.3 | 0.997713 [0.988637, 1.00687] | 4.3274e-07 / 4.3274e-07 | 16192 / 16192 | inconclusive |
| cd/lasso-D/cd/dense-f64/call | 1.13.3 | 0.986561 [0.973373, 0.999926] | 4.40968e-13 / 4.40968e-13 | 21632 / 21632 | faster |
| cd/lasso-D/cd/sparse-f32/call | 1.13.3 | 1.00462 [0.993126, 1.01624] | 4.3274e-07 / 4.3274e-07 | 16192 / 16192 | inconclusive |
| cd/lasso-D/cd/sparse-f64/call | 1.13.3 | 0.992111 [0.974075, 1.01048] | 4.40968e-13 / 4.40968e-13 | 21632 / 21632 | inconclusive |
| cd/lasso-dense/cd/R/call | 1.13.3 | 1.00201 [0.985056, 1.01926] | 5.75233e-08 / 5.75233e-08 | 6752 / 6752 | inconclusive |
| cd/lasso/cd/dense-f32/call | 1.13.3 | 1.01508 [0.972585, 1.05944] | 3.57172e-07 / 3.57172e-07 | 2096 / 2096 | inconclusive |
| cd/lasso/cd/dense-f64/call | 1.13.3 | 0.990908 [0.960891, 1.02186] | 1.3083e-12 / 1.3083e-12 | 2832 / 2832 | inconclusive |
| cd/lasso/cd/sparse-f32/call | 1.13.3 | 1.01321 [0.987322, 1.03979] | 3.57172e-07 / 3.57172e-07 | 2096 / 2096 | inconclusive |
| cd/lasso/cd/sparse-f64/call | 1.13.3 | 0.971373 [0.933948, 1.0103] | 1.3083e-12 / 1.3083e-12 | 2832 / 2832 | inconclusive |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.13.3 | 0.962842 [0.926924, 1.00015] | 5.34974e-10 / 5.34974e-10 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.13.3 | 0.997394 [0.96382, 1.03214] | 7.59748e-11 / 7.59748e-11 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.13.3 | 0.999497 [0.982788, 1.01649] | 4.81707e-09 / 4.81707e-09 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.13.3 | 1.04901 [1.01473, 1.08444] | 1.81193e-10 / 1.81193e-10 | 11696 / 11696 | slower |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.13.3 | 1.03128 [0.997353, 1.06637] | 7.27499e-11 / 7.27499e-11 | 11696 / 11696 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.13.3 | 0.996553 [0.994572, 0.998537] | 1.66286e-10 / 1.66286e-10 | 32032 / 32032 | faster |
| gradient/lasso-C/apg/dense-f64/call | 1.13.3 | 0.998828 [0.996399, 1.00126] | 1.8743e-09 / 1.8743e-09 | 32032 / 32032 | inconclusive |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.13.3 | 0.998716 [0.996669, 1.00077] | 1.29959e-10 / 1.29959e-10 | 18752 / 18752 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.13.3 | 0.998972 [0.997241, 1.00071] | 1.36519e-10 / 1.36519e-10 | 31384 / 31384 | inconclusive |
| gradient/lasso-D/apg/dense-f64/call | 1.13.3 | 0.999947 [0.997964, 1.00193] | 3.71883e-09 / 3.71883e-09 | 31384 / 31384 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.13.3 | 0.997881 [0.994877, 1.00089] | 1.41756e-10 / 1.41756e-10 | 28008 / 28008 | inconclusive |
| gradient/lasso-D/pg/dense-f64/call | 1.13.3 | 0.996263 [0.994413, 0.998117] | 4.01926e-09 / 4.01926e-09 | 28008 / 28008 | faster |
| gradient/lasso/apg/acc-dense-f64/call | 1.13.3 | 0.978387 [0.965769, 0.99117] | 1.0779e-10 / 1.0779e-10 | 6256 / 6256 | faster |
| gradient/lasso/apg/dense-f64/call | 1.13.3 | 0.979247 [0.971979, 0.986569] | 2.05048e-09 / 2.05048e-09 | 6256 / 6256 | faster |
| gradient/lasso/pg/R/call | 1.13.3 | 1.00568 [0.994906, 1.01657] | 2.9973e-05 / 2.9973e-05 | 4688 / 4688 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.13.3 | 0.989889 [0.972423, 1.00767] | 1.28759e-10 / 1.28759e-10 | 4064 / 4064 | inconclusive |
| gradient/lasso/pg/dense-f64/call | 1.13.3 | 0.989434 [0.976324, 1.00272] | 2.60529e-09 / 2.60529e-09 | 4064 / 4064 | inconclusive |

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
