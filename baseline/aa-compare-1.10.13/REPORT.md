# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 38. Excluded cases: 14.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| cd/lasso-B/cd/dense-f32/call | 1.10.13 | 0.996453 [0.986286, 1.00673] | 3.19554e-06 / 3.19554e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/dense-f64/call | 1.10.13 | 0.991102 [0.977621, 1.00477] | 3.17081e-11 / 3.17081e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/sparse-f32/call | 1.10.13 | 0.999926 [0.992748, 1.00716] | 3.19554e-06 / 3.19554e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/sparse-f64/call | 1.10.13 | 0.993053 [0.971328, 1.01526] | 3.17081e-11 / 3.17081e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/warm-dense-f32/call | 1.10.13 | 1.00144 [0.992997, 1.00994] | 1.37177e-06 / 1.37177e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/warm-dense-f64/call | 1.10.13 | 1.0045 [0.992602, 1.01654] | 3.3179e-11 / 3.3179e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.10.13 | 0.995282 [0.9884, 1.00221] | 1.37177e-06 / 1.37177e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.10.13 | 1.00407 [0.995582, 1.01262] | 3.3179e-11 / 3.3179e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-C/cd/dense-f32/call | 1.10.13 | 0.99875 [0.98963, 1.00795] | 5.59476e-07 / 5.59476e-07 | 7376 / 7376 | inconclusive |
| cd/lasso-C/cd/dense-f64/call | 1.10.13 | 0.999537 [0.987669, 1.01155] | 6.05071e-12 / 6.05071e-12 | 11696 / 11696 | inconclusive |
| cd/lasso-C/cd/sparse-f32/call | 1.10.13 | 1.00035 [0.997595, 1.00311] | 5.59476e-07 / 5.59476e-07 | 7376 / 7376 | inconclusive |
| cd/lasso-C/cd/sparse-f64/call | 1.10.13 | 1.00006 [0.996786, 1.00334] | 6.05071e-12 / 6.05071e-12 | 11696 / 11696 | inconclusive |
| cd/lasso-D/cd/dense-f32/call | 1.10.13 | 1.00672 [0.992469, 1.02118] | 4.48279e-07 / 4.48279e-07 | 16576 / 16576 | inconclusive |
| cd/lasso-D/cd/dense-f64/call | 1.10.13 | 0.995087 [0.98572, 1.00454] | 7.20869e-13 / 7.20869e-13 | 22160 / 22160 | inconclusive |
| cd/lasso-D/cd/sparse-f32/call | 1.10.13 | 0.996945 [0.980219, 1.01396] | 4.48279e-07 / 4.48279e-07 | 16576 / 16576 | inconclusive |
| cd/lasso-D/cd/sparse-f64/call | 1.10.13 | 1.00842 [0.994032, 1.02301] | 7.20869e-13 / 7.20869e-13 | 22160 / 22160 | inconclusive |
| cd/lasso-dense/cd/R/call | 1.10.13 | 0.992533 [0.981316, 1.00388] | 5.75233e-08 / 5.75233e-08 | 6864 / 6864 | inconclusive |
| cd/lasso/cd/dense-f32/call | 1.10.13 | 0.997036 [0.973791, 1.02084] | 5.95994e-07 / 5.95994e-07 | 2336 / 2336 | inconclusive |
| cd/lasso/cd/dense-f64/call | 1.10.13 | 0.982224 [0.941733, 1.02446] | 2.74712e-12 / 2.74712e-12 | 3056 / 3056 | inconclusive |
| cd/lasso/cd/sparse-f32/call | 1.10.13 | 1.01913 [0.993786, 1.04511] | 5.95994e-07 / 5.95994e-07 | 2336 / 2336 | inconclusive |
| cd/lasso/cd/sparse-f64/call | 1.10.13 | 0.9981 [0.959792, 1.03794] | 2.74712e-12 / 2.74712e-12 | 3056 / 3056 | inconclusive |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.10.13 | 0.984702 [0.96327, 1.00661] | 3.38453e-10 / 3.38453e-10 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.10.13 | 1.0064 [0.987469, 1.0257] | 5.60574e-11 / 5.60574e-11 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.10.13 | 0.986392 [0.954427, 1.01943] | 5.15948e-09 / 5.15948e-09 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.10.13 | 1.02507 [0.99534, 1.05569] | 6.11044e-09 / 6.11044e-09 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.10.13 | 1.01661 [0.981687, 1.05277] | 1.81951e-10 / 1.81951e-10 | 11504 / 11504 | inconclusive |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.10.13 | 0.995646 [0.974344, 1.01741] | 8.27036e-11 / 8.27036e-11 | 11504 / 11504 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.10.13 | 0.999695 [0.997622, 1.00177] | 1.4471e-10 / 1.4471e-10 | 32528 / 32528 | inconclusive |
| gradient/lasso-C/apg/dense-f64/call | 1.10.13 | 0.99813 [0.995265, 1.001] | 7.08895e-09 / 7.08895e-09 | 32528 / 32528 | inconclusive |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.10.13 | 1.00043 [0.997954, 1.0029] | 2.40199e-10 / 2.40199e-10 | 19136 / 19136 | inconclusive |
| gradient/lasso-C/pg/dense-f64/call | 1.10.13 | 1.00115 [0.998653, 1.00366] | 3.48906e-09 / 3.48906e-09 | 19136 / 19136 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.10.13 | 0.999659 [0.997422, 1.0019] | 1.67664e-10 / 1.67664e-10 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/apg/dense-f64/call | 1.10.13 | 0.999479 [0.99541, 1.00356] | 5.17253e-09 / 5.17253e-09 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.10.13 | 0.997313 [0.995462, 0.999168] | 1.65263e-10 / 1.65263e-10 | 28544 / 28544 | faster |
| gradient/lasso/apg/acc-dense-f64/call | 1.10.13 | 0.986842 [0.967896, 1.00616] | 1.23409e-10 / 1.23409e-10 | 6240 / 6240 | inconclusive |
| gradient/lasso/pg/R/call | 1.10.13 | 0.998047 [0.984743, 1.01153] | 2.88018e-05 / 2.88018e-05 | 4816 / 4816 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.10.13 | 1.00431 [0.992458, 1.01631] | 1.13688e-10 / 1.13688e-10 | 4112 / 4112 | inconclusive |
| gradient/lasso/pg/dense-f64/call | 1.10.13 | 1.01146 [1.00438, 1.01858] | 5.49245e-09 / 5.49245e-09 | 4112 / 4112 | slower |

## Excluded cases

| Case | Julia | Before reasons | After reasons |
|---|---|---|---|
| gradient/lasso-B/apg/dense-f32/call | 1.10.13 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.10.13 | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-B/pg/dense-f32/call | 1.10.13 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-B/pg/dense-f64/call | 1.10.13 | rep10: target_missed | rep10: target_missed |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.10.13 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep10: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep10: target_missed |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.10.13 | rep06: target_missed; rep10: target_missed | rep06: target_missed; rep10: target_missed |
| gradient/lasso-C/apg/dense-f32/call | 1.10.13 | rep02: target_missed; rep04: target_missed; rep05: target_missed; rep07: target_missed; rep08: target_missed; rep10: target_missed | rep02: target_missed; rep04: target_missed; rep05: target_missed; rep07: target_missed; rep08: target_missed; rep10: target_missed |
| gradient/lasso-C/pg/dense-f32/call | 1.10.13 | rep01: target_missed; rep04: target_missed; rep05: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep04: target_missed; rep05: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-D/apg/dense-f32/call | 1.10.13 | rep01: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep10: target_missed | rep01: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep10: target_missed |
| gradient/lasso-D/pg/dense-f32/call | 1.10.13 | rep01: target_missed; rep05: target_missed; rep06: target_missed | rep01: target_missed; rep05: target_missed; rep06: target_missed |
| gradient/lasso-D/pg/dense-f64/call | 1.10.13 | rep03: target_missed | rep03: target_missed |
| gradient/lasso/apg/dense-f32/call | 1.10.13 | rep01: target_missed; rep02: target_missed; rep04: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep02: target_missed; rep04: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso/apg/dense-f64/call | 1.10.13 | rep03: target_missed | rep03: target_missed |
| gradient/lasso/pg/dense-f32/call | 1.10.13 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep06: target_missed; rep07: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep06: target_missed; rep07: target_missed; rep09: target_missed; rep10: target_missed |
