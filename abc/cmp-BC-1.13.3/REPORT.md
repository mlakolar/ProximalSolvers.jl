# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 38. Excluded cases: 14.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| cd/lasso-B/cd/dense-f32/call | 1.13.3 | 0.996891 [0.986941, 1.00694] | 2.90908e-06 / 2.90908e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/dense-f64/call | 1.13.3 | 0.996773 [0.966708, 1.02777] | 1.06546e-11 / 1.06546e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/sparse-f32/call | 1.13.3 | 0.997568 [0.985832, 1.00944] | 2.90908e-06 / 2.90908e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/sparse-f64/call | 1.13.3 | 1.00992 [0.979137, 1.04167] | 1.06546e-11 / 1.06546e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/warm-dense-f32/call | 1.13.3 | 0.987461 [0.962411, 1.01316] | 2.89053e-06 / 2.89053e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/warm-dense-f64/call | 1.13.3 | 1.00941 [0.991438, 1.0277] | 2.62505e-11 / 2.62505e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.13.3 | 0.99835 [0.967414, 1.03027] | 2.89053e-06 / 2.89053e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.13.3 | 1.00311 [0.981969, 1.02471] | 2.62505e-11 / 2.62505e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-C/cd/dense-f32/call | 1.13.3 | 0.999675 [0.979936, 1.01981] | 4.79371e-07 / 4.79371e-07 | 7096 / 7096 | inconclusive |
| cd/lasso-C/cd/dense-f64/call | 1.13.3 | 1.00013 [0.99336, 1.00695] | 7.24643e-12 / 7.24643e-12 | 11256 / 11256 | inconclusive |
| cd/lasso-C/cd/sparse-f32/call | 1.13.3 | 1.0082 [0.999537, 1.01694] | 4.79371e-07 / 4.79371e-07 | 7096 / 7096 | inconclusive |
| cd/lasso-C/cd/sparse-f64/call | 1.13.3 | 1.00536 [0.999751, 1.01101] | 7.24643e-12 / 7.24643e-12 | 11256 / 11256 | inconclusive |
| cd/lasso-D/cd/dense-f32/call | 1.13.3 | 0.999384 [0.991533, 1.0073] | 4.3274e-07 / 4.3274e-07 | 16192 / 16192 | inconclusive |
| cd/lasso-D/cd/dense-f64/call | 1.13.3 | 1.00019 [0.995276, 1.00512] | 4.40968e-13 / 4.40968e-13 | 21632 / 21632 | inconclusive |
| cd/lasso-D/cd/sparse-f32/call | 1.13.3 | 1.00906 [0.966842, 1.05313] | 4.3274e-07 / 4.3274e-07 | 16192 / 16192 | inconclusive |
| cd/lasso-D/cd/sparse-f64/call | 1.13.3 | 0.992796 [0.975226, 1.01068] | 4.40968e-13 / 4.40968e-13 | 21632 / 21632 | inconclusive |
| cd/lasso-dense/cd/R/call | 1.13.3 | 0.993558 [0.981087, 1.00619] | 5.75233e-08 / 5.75233e-08 | 6752 / 6752 | inconclusive |
| cd/lasso/cd/dense-f32/call | 1.13.3 | 1.01076 [0.969493, 1.05379] | 3.57172e-07 / 3.57172e-07 | 2096 / 2096 | inconclusive |
| cd/lasso/cd/dense-f64/call | 1.13.3 | 1.00926 [0.993146, 1.02564] | 1.3083e-12 / 1.3083e-12 | 2832 / 2832 | inconclusive |
| cd/lasso/cd/sparse-f32/call | 1.13.3 | 1.02331 [0.990373, 1.05735] | 3.57172e-07 / 3.57172e-07 | 2096 / 2096 | inconclusive |
| cd/lasso/cd/sparse-f64/call | 1.13.3 | 0.987174 [0.972416, 1.00216] | 1.3083e-12 / 1.3083e-12 | 2832 / 2832 | inconclusive |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.13.3 | 0.985973 [0.949927, 1.02339] | 5.34974e-10 / 5.34974e-10 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.13.3 | 1.0107 [0.972522, 1.05038] | 7.59748e-11 / 7.59748e-11 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.13.3 | 1.00207 [0.959671, 1.04633] | 4.81707e-09 / 4.81707e-09 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.13.3 | 1.00542 [0.964548, 1.04803] | 1.81193e-10 / 1.81193e-10 | 11696 / 11696 | inconclusive |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.13.3 | 0.996938 [0.972737, 1.02174] | 7.27499e-11 / 7.27499e-11 | 11696 / 11696 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.13.3 | 0.999428 [0.997438, 1.00142] | 1.66286e-10 / 1.66286e-10 | 32032 / 32032 | inconclusive |
| gradient/lasso-C/apg/dense-f64/call | 1.13.3 | 1.00052 [0.998573, 1.00247] | 1.8743e-09 / 1.8743e-09 | 32032 / 32032 | inconclusive |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.13.3 | 0.999946 [0.998459, 1.00144] | 1.29959e-10 / 1.29959e-10 | 18752 / 18752 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.13.3 | 1.00224 [1.00044, 1.00403] | 1.36519e-10 / 1.36519e-10 | 31384 / 31384 | slower |
| gradient/lasso-D/apg/dense-f64/call | 1.13.3 | 1.00121 [0.99962, 1.00279] | 3.71883e-09 / 3.71883e-09 | 31384 / 31384 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.13.3 | 0.985712 [0.941939, 1.03152] | 1.41756e-10 / 1.41756e-10 | 28008 / 28008 | inconclusive |
| gradient/lasso-D/pg/dense-f64/call | 1.13.3 | 0.988596 [0.952609, 1.02594] | 4.01926e-09 / 4.01926e-09 | 28008 / 28008 | inconclusive |
| gradient/lasso/apg/acc-dense-f64/call | 1.13.3 | 1.00501 [0.989853, 1.0204] | 1.0779e-10 / 1.0779e-10 | 6256 / 6256 | inconclusive |
| gradient/lasso/apg/dense-f64/call | 1.13.3 | 1.0059 [0.999074, 1.01278] | 2.05048e-09 / 2.05048e-09 | 6256 / 6256 | inconclusive |
| gradient/lasso/pg/R/call | 1.13.3 | 0.998295 [0.979996, 1.01694] | 2.9973e-05 / 2.9973e-05 | 4688 / 4688 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.13.3 | 1.00647 [0.988937, 1.02431] | 1.28759e-10 / 1.28759e-10 | 4064 / 4064 | inconclusive |
| gradient/lasso/pg/dense-f64/call | 1.13.3 | 1.00686 [0.991096, 1.02287] | 2.60529e-09 / 2.60529e-09 | 4064 / 4064 | inconclusive |

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
