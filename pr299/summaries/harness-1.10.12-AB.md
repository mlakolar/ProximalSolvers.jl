# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 1. Excluded cases: 20.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| gradient/lasso/pg/R/call | 1.10.12 | 0.999673 [0.980846, 1.01886] | 0.000769421 / 0.000769421 | 4800 / 4800 | inconclusive |

## Excluded cases

| Case | Julia | Before reasons | After reasons |
|---|---|---|---|
| gradient/lasso-B/apg/dense-f32/call | 1.10.12 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-B/apg/dense-f64/call | 1.10.12 | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.10.12 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.10.12 | rep03: target_missed; rep04: target_missed; rep05: target_missed | rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-B/pg/dense-f32/call | 1.10.12 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-B/pg/dense-f64/call | 1.10.12 | rep02: target_missed; rep03: target_missed | rep02: target_missed; rep03: target_missed |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.10.12 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.10.12 | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-C/apg/dense-f32/call | 1.10.12 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-C/apg/dense-f64/call | 1.10.12 | rep01: target_missed; rep02: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep05: target_missed |
| gradient/lasso-C/pg/dense-f32/call | 1.10.12 | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-C/pg/dense-f64/call | 1.10.12 | rep01: target_missed; rep03: target_missed; rep04: target_missed | rep01: target_missed; rep03: target_missed; rep04: target_missed |
| gradient/lasso-D/apg/dense-f32/call | 1.10.12 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-D/apg/dense-f64/call | 1.10.12 | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-D/pg/dense-f32/call | 1.10.12 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso-D/pg/dense-f64/call | 1.10.12 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso/apg/dense-f32/call | 1.10.12 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso/apg/dense-f64/call | 1.10.12 | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso/pg/dense-f32/call | 1.10.12 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed |
| gradient/lasso/pg/dense-f64/call | 1.10.12 | rep02: target_missed; rep03: target_missed | rep02: target_missed; rep03: target_missed |
