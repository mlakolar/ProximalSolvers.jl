# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 20. Excluded cases: 11.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| gradient/lasso-B/apg/acc-dense-f64/call | 1.10.13 | 0.999876 [0.985029, 1.01495] | 2.02681e-10 / 2.02681e-10 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.10.13 | 0.997101 [0.985916, 1.00841] | 3.93359e-11 / 3.93359e-11 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.10.13 | 0.999345 [0.982916, 1.01605] | 2.02681e-10 / 2.02681e-10 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.10.13 | 0.997647 [0.986512, 1.00891] | 2.79879e-09 / 2.79879e-09 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.10.13 | 0.99545 [0.99244, 0.99847] | 1.1664e-10 / 1.1664e-10 | 11504 / 11504 | faster |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.10.13 | 0.99843 [0.987643, 1.00934] | 7.3579e-11 / 7.3579e-11 | 11504 / 11504 | inconclusive |
| gradient/lasso-B/pg/dense-f64/call | 1.10.13 | 0.997643 [0.985654, 1.00978] | 8.18861e-09 / 8.18861e-09 | 11504 / 11504 | inconclusive |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.10.13 | 0.999472 [0.992386, 1.00661] | 8.93278e-09 / 8.93278e-09 | 11504 / 11504 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.10.13 | 1.00197 [0.968395, 1.03671] | 7.77237e-11 / 7.77237e-11 | 32528 / 32528 | inconclusive |
| gradient/lasso-C/apg/dense-f64/call | 1.10.13 | 1.01023 [0.795451, 1.28301] | 2.87634e-10 / 2.87634e-10 | 32528 / 32528 | inconclusive |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.10.13 | 1.02862 [0.951916, 1.1115] | 7.89294e-11 / 7.89294e-11 | 19136 / 19136 | inconclusive |
| gradient/lasso-C/pg/dense-f64/call | 1.10.13 | 0.99016 [0.836219, 1.17244] | 1.44168e-09 / 1.44168e-09 | 19136 / 19136 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.10.13 | 1.04505 [0.94668, 1.15364] | 5.95423e-11 / 5.95423e-11 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/apg/dense-f64/call | 1.10.13 | 0.993968 [0.899219, 1.0987] | 1.6669e-09 / 1.6669e-09 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.10.13 | 0.991269 [0.923331, 1.06421] | 6.24013e-11 / 6.24013e-11 | 28544 / 28544 | inconclusive |
| gradient/lasso-D/pg/dense-f64/call | 1.10.13 | 0.999083 [0.803766, 1.24186] | 2.51151e-09 / 2.51151e-09 | 28544 / 28544 | inconclusive |
| gradient/lasso/apg/acc-dense-f64/call | 1.10.13 | 0.9878 [0.958875, 1.0176] | 6.6077e-11 / 6.6077e-11 | 6240 / 6240 | inconclusive |
| gradient/lasso/pg/R/call | 1.10.13 | 1.0062 [0.981201, 1.03184] | 2.88018e-05 / 2.88018e-05 | 4816 / 4816 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.10.13 | 0.9933 [0.979013, 1.0078] | 5.87474e-11 / 5.87474e-11 | 4112 / 4112 | inconclusive |
| gradient/lasso/pg/dense-f64/call | 1.10.13 | 1.00251 [0.965741, 1.04068] | 2.20345e-09 / 2.20345e-09 | 4112 / 4112 | inconclusive |

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
