# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 20. Excluded cases: 11.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| gradient/lasso-B/apg/acc-dense-f64/call | 1.10.13 | 1.00142 [0.99299, 1.00992] | 2.02681e-10 / 2.02681e-10 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.10.13 | 0.999747 [0.988391, 1.01123] | 3.93359e-11 / 3.93359e-11 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.10.13 | 0.999472 [0.989837, 1.0092] | 2.02681e-10 / 2.02681e-10 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.10.13 | 1.0008 [0.991714, 1.00997] | 2.79879e-09 / 2.79879e-09 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.10.13 | 1.00102 [0.992047, 1.01008] | 1.1664e-10 / 1.1664e-10 | 11504 / 11504 | inconclusive |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.10.13 | 1.00081 [0.988279, 1.01349] | 7.3579e-11 / 7.3579e-11 | 11504 / 11504 | inconclusive |
| gradient/lasso-B/pg/dense-f64/call | 1.10.13 | 1.00427 [1.00095, 1.00761] | 8.18861e-09 / 8.18861e-09 | 11504 / 11504 | slower |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.10.13 | 0.998546 [0.9916, 1.00554] | 8.93278e-09 / 8.93278e-09 | 11504 / 11504 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.10.13 | 1.03177 [0.917224, 1.16062] | 7.77237e-11 / 7.77237e-11 | 32528 / 32528 | inconclusive |
| gradient/lasso-C/apg/dense-f64/call | 1.10.13 | 1.02286 [0.924662, 1.13148] | 2.87634e-10 / 2.87634e-10 | 32528 / 32528 | inconclusive |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.10.13 | 1.02722 [0.954452, 1.10554] | 7.89294e-11 / 7.89294e-11 | 19136 / 19136 | inconclusive |
| gradient/lasso-C/pg/dense-f64/call | 1.10.13 | 1.00942 [0.89019, 1.14463] | 1.44168e-09 / 1.44168e-09 | 19136 / 19136 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.10.13 | 1.0456 [0.931732, 1.17339] | 5.95423e-11 / 5.95423e-11 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/apg/dense-f64/call | 1.10.13 | 1.0141 [0.979363, 1.05007] | 1.6669e-09 / 1.6669e-09 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.10.13 | 1.02661 [0.914219, 1.15282] | 6.24013e-11 / 6.24013e-11 | 28544 / 28544 | inconclusive |
| gradient/lasso-D/pg/dense-f64/call | 1.10.13 | 1.0265 [0.904511, 1.16494] | 2.51151e-09 / 2.51151e-09 | 28544 / 28544 | inconclusive |
| gradient/lasso/apg/acc-dense-f64/call | 1.10.13 | 0.995584 [0.981501, 1.00987] | 6.6077e-11 / 6.6077e-11 | 6240 / 6240 | inconclusive |
| gradient/lasso/pg/R/call | 1.10.13 | 0.995435 [0.970375, 1.02114] | 2.88018e-05 / 2.88018e-05 | 4816 / 4816 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.10.13 | 0.988265 [0.979696, 0.996908] | 5.87474e-11 / 5.87474e-11 | 4112 / 4112 | faster |
| gradient/lasso/pg/dense-f64/call | 1.10.13 | 0.995896 [0.963357, 1.02953] | 2.20345e-09 / 2.20345e-09 | 4112 / 4112 | inconclusive |

## Excluded cases

| Case | Julia | Before reasons | After reasons |
|---|---|---|---|
| gradient/lasso-B/apg/dense-f32/call | 1.10.13 | rep01: target_missed; rep02: target_missed; rep03: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.10.13 | rep02: target_missed; rep03: target_missed | rep02: target_missed; rep03: target_missed |
| gradient/lasso-B/pg/dense-f32/call | 1.10.13 | rep01: target_missed; rep02: target_missed; rep03: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.10.13 | rep01: target_missed; rep02: target_missed; rep03: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed |
| gradient/lasso-C/apg/dense-f32/call | 1.10.13 | rep02: target_missed | rep02: target_missed |
| gradient/lasso-C/pg/dense-f32/call | 1.10.13 | rep01: target_missed | rep01: target_missed |
| gradient/lasso-D/apg/dense-f32/call | 1.10.13 | rep01: target_missed | rep01: target_missed |
| gradient/lasso-D/pg/dense-f32/call | 1.10.13 | rep01: target_missed | rep01: target_missed |
| gradient/lasso/apg/dense-f32/call | 1.10.13 | rep02: target_missed | rep02: target_missed |
| gradient/lasso/apg/dense-f64/call | 1.10.13 | rep03: target_missed | rep03: target_missed |
| gradient/lasso/pg/dense-f32/call | 1.10.13 | rep01: target_missed; rep02: target_missed; rep03: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed |
