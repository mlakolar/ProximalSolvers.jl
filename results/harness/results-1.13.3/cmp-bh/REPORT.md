# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 19. Excluded cases: 12.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| gradient/lasso-B/apg/acc-dense-f64/call | 1.13.3 | 0.992758 [0.981583, 1.00406] | 2.66063e-10 / 2.66063e-10 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.13.3 | 0.991732 [0.977172, 1.00651] | 2.09161e-11 / 2.09161e-11 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.13.3 | 1.00368 [0.985263, 1.02244] | 1.2377e-09 / 1.2377e-09 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.13.3 | 0.994266 [0.976925, 1.01191] | 1.45107e-10 / 1.45107e-10 | 11696 / 11696 | inconclusive |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.13.3 | 1.00005 [0.966498, 1.03476] | 5.43171e-11 / 5.43171e-11 | 11696 / 11696 | inconclusive |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.13.3 | 0.987422 [0.972516, 1.00256] | 4.49957e-09 / 4.49957e-09 | 11696 / 11696 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.13.3 | 0.964052 [0.908582, 1.02291] | 4.73501e-11 / 4.73501e-11 | 32032 / 32032 | inconclusive |
| gradient/lasso-C/apg/dense-f64/call | 1.13.3 | 0.969782 [0.794705, 1.18343] | 3.15712e-10 / 3.15712e-10 | 32032 / 32032 | inconclusive |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.13.3 | 0.965007 [0.853517, 1.09106] | 8.03318e-11 / 8.03318e-11 | 18752 / 18752 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.13.3 | 0.988575 [0.923568, 1.05816] | 3.69123e-11 / 3.69123e-11 | 31384 / 31384 | inconclusive |
| gradient/lasso-D/apg/dense-f64/call | 1.13.3 | 0.99602 [0.810516, 1.22398] | 7.43739e-10 / 7.43739e-10 | 31384 / 31384 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.13.3 | 0.983414 [0.945862, 1.02246] | 5.47538e-11 / 5.47538e-11 | 28008 / 28008 | inconclusive |
| gradient/lasso-D/pg/dense-f32/call | 1.13.3 | 0.999817 [0.998075, 1.00156] | 9.28296e-06 / 9.28296e-06 | 14792 / 14792 | inconclusive |
| gradient/lasso-D/pg/dense-f64/call | 1.13.3 | 1.01776 [0.915068, 1.13198] | 2.21993e-09 / 2.21993e-09 | 28008 / 28008 | inconclusive |
| gradient/lasso/apg/acc-dense-f64/call | 1.13.3 | 0.979349 [0.943039, 1.01706] | 1.0779e-10 / 1.0779e-10 | 6256 / 6256 | inconclusive |
| gradient/lasso/apg/dense-f64/call | 1.13.3 | 0.986864 [0.940381, 1.03564] | 7.61811e-10 / 7.61811e-10 | 6256 / 6256 | inconclusive |
| gradient/lasso/pg/R/call | 1.13.3 | 1.00193 [0.973068, 1.03166] | 2.9973e-05 / 2.9973e-05 | 4688 / 4688 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.13.3 | 1.00441 [0.945433, 1.06706] | 9.3398e-11 / 9.3398e-11 | 4064 / 4064 | inconclusive |
| gradient/lasso/pg/dense-f64/call | 1.13.3 | 1.01678 [0.999328, 1.03453] | 2.60529e-09 / 2.60529e-09 | 4064 / 4064 | inconclusive |

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
