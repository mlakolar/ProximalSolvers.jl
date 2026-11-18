# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 19. Excluded cases: 12.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| gradient/lasso-B/apg/acc-dense-f64/call | 1.13.3 | 0.997373 [0.981018, 1.014] | 2.66063e-10 / 2.66063e-10 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.13.3 | 0.999474 [0.984788, 1.01438] | 2.09161e-11 / 2.09161e-11 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.13.3 | 1.00282 [0.992974, 1.01275] | 1.2377e-09 / 1.2377e-09 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.13.3 | 1.00001 [0.995843, 1.0042] | 1.45107e-10 / 1.45107e-10 | 11696 / 11696 | inconclusive |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.13.3 | 0.996185 [0.985752, 1.00673] | 5.43171e-11 / 5.43171e-11 | 11696 / 11696 | inconclusive |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.13.3 | 0.993886 [0.973482, 1.01472] | 4.49957e-09 / 4.49957e-09 | 11696 / 11696 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.13.3 | 0.996087 [0.868603, 1.14228] | 4.73501e-11 / 4.73501e-11 | 32032 / 32032 | inconclusive |
| gradient/lasso-C/apg/dense-f64/call | 1.13.3 | 0.996778 [0.93091, 1.06731] | 3.15712e-10 / 3.15712e-10 | 32032 / 32032 | inconclusive |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.13.3 | 0.982958 [0.897627, 1.0764] | 8.03318e-11 / 8.03318e-11 | 18752 / 18752 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.13.3 | 0.972691 [0.907067, 1.04306] | 3.69123e-11 / 3.69123e-11 | 31384 / 31384 | inconclusive |
| gradient/lasso-D/apg/dense-f64/call | 1.13.3 | 0.971715 [0.869556, 1.08588] | 7.43739e-10 / 7.43739e-10 | 31384 / 31384 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.13.3 | 0.94744 [0.865071, 1.03765] | 5.47538e-11 / 5.47538e-11 | 28008 / 28008 | inconclusive |
| gradient/lasso-D/pg/dense-f32/call | 1.13.3 | 1.00036 [0.995684, 1.00506] | 9.28296e-06 / 9.28296e-06 | 14792 / 14792 | inconclusive |
| gradient/lasso-D/pg/dense-f64/call | 1.13.3 | 1.05285 [1.00708, 1.10071] | 2.21993e-09 / 2.21993e-09 | 28008 / 28008 | slower |
| gradient/lasso/apg/acc-dense-f64/call | 1.13.3 | 1.00382 [0.965681, 1.04346] | 1.0779e-10 / 1.0779e-10 | 6256 / 6256 | inconclusive |
| gradient/lasso/apg/dense-f64/call | 1.13.3 | 0.998924 [0.937913, 1.0639] | 7.61811e-10 / 7.61811e-10 | 6256 / 6256 | inconclusive |
| gradient/lasso/pg/R/call | 1.13.3 | 0.98486 [0.952046, 1.0188] | 2.9973e-05 / 2.9973e-05 | 4688 / 4688 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.13.3 | 1.00645 [0.99219, 1.02092] | 9.3398e-11 / 9.3398e-11 | 4064 / 4064 | inconclusive |
| gradient/lasso/pg/dense-f64/call | 1.13.3 | 0.992149 [0.960994, 1.02431] | 2.60529e-09 / 2.60529e-09 | 4064 / 4064 | inconclusive |

## Excluded cases

| Case | Julia | Before reasons | After reasons |
|---|---|---|---|
| gradient/lasso-B/apg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.13.3 | rep01: target_missed; rep03: target_missed | rep01: target_missed; rep03: target_missed |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.13.3 | rep03: target_missed | rep03: target_missed |
| gradient/lasso-B/pg/dense-f32/call | 1.13.3 | rep02: target_missed; rep03: target_missed | rep02: target_missed; rep03: target_missed |
| gradient/lasso-B/pg/dense-f64/call | 1.13.3 | rep03: target_missed | rep03: target_missed |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.13.3 | rep01: target_missed; rep03: target_missed | rep01: target_missed; rep03: target_missed |
| gradient/lasso-C/apg/dense-f32/call | 1.13.3 | rep02: target_missed; rep03: target_missed | rep02: target_missed; rep03: target_missed |
| gradient/lasso-C/pg/dense-f32/call | 1.13.3 | rep01: target_missed; rep03: target_missed | rep01: target_missed; rep03: target_missed |
| gradient/lasso-C/pg/dense-f64/call | 1.13.3 | rep01: target_missed | rep01: target_missed |
| gradient/lasso-D/apg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed | rep01: target_missed; rep02: target_missed |
| gradient/lasso/apg/dense-f32/call | 1.13.3 | rep01: target_missed; rep03: target_missed | rep01: target_missed; rep03: target_missed |
| gradient/lasso/pg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed |
