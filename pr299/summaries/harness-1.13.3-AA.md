# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 2. Excluded cases: 19.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| gradient/lasso/pg/R/call | 1.13.3 | 1.01359 [0.984099, 1.04396] | 0.000772446 / 0.000772446 | 4672 / 4672 | inconclusive |
| gradient/lasso/pg/dense-f64/call | 1.13.3 | 1.00383 [0.993673, 1.01409] | 5.33247e-09 / 5.33247e-09 | 4048 / 4048 | inconclusive |

## Excluded cases

| Case | Julia | Before reasons | After reasons |
|---|---|---|---|
| gradient/lasso-B/apg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-B/apg/dense-f64/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.13.3 | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-B/pg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-B/pg/dense-f64/call | 1.13.3 | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-C/apg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-C/apg/dense-f64/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed |
| gradient/lasso-C/pg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-C/pg/dense-f64/call | 1.13.3 | rep01: target_missed | rep01: target_missed |
| gradient/lasso-D/apg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-D/apg/dense-f64/call | 1.13.3 | rep05: target_missed | rep05: target_missed |
| gradient/lasso-D/pg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-D/pg/dense-f64/call | 1.13.3 | rep02: target_missed | rep02: target_missed |
| gradient/lasso/apg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso/apg/dense-f64/call | 1.13.3 | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso/pg/dense-f32/call | 1.13.3 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
