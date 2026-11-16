# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 38. Excluded cases: 14.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| cd/lasso-B/cd/dense-f32/call | 1.10.13 | 1.01073 [0.99274, 1.02905] | 3.19554e-06 / 3.19554e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/dense-f64/call | 1.10.13 | 1.00098 [0.961119, 1.0425] | 3.17081e-11 / 3.17081e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/sparse-f32/call | 1.10.13 | 0.987316 [0.96766, 1.00737] | 3.19554e-06 / 3.19554e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/sparse-f64/call | 1.10.13 | 1.0123 [0.986432, 1.03885] | 3.17081e-11 / 3.17081e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/warm-dense-f32/call | 1.10.13 | 0.99858 [0.984718, 1.01264] | 1.37177e-06 / 1.37177e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/warm-dense-f64/call | 1.10.13 | 0.991662 [0.968302, 1.01559] | 3.3179e-11 / 3.3179e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.10.13 | 1.00659 [0.990896, 1.02253] | 1.37177e-06 / 1.37177e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.10.13 | 1.02897 [0.988966, 1.07059] | 3.3179e-11 / 3.3179e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-C/cd/dense-f32/call | 1.10.13 | 1.00459 [0.997333, 1.0119] | 5.59476e-07 / 5.59476e-07 | 7376 / 7376 | inconclusive |
| cd/lasso-C/cd/dense-f64/call | 1.10.13 | 1.00295 [0.998039, 1.00789] | 6.05071e-12 / 6.05071e-12 | 11696 / 11696 | inconclusive |
| cd/lasso-C/cd/sparse-f32/call | 1.10.13 | 1.0031 [1.00027, 1.00593] | 5.59476e-07 / 5.59476e-07 | 7376 / 7376 | slower |
| cd/lasso-C/cd/sparse-f64/call | 1.10.13 | 0.996354 [0.9892, 1.00356] | 6.05071e-12 / 6.05071e-12 | 11696 / 11696 | inconclusive |
| cd/lasso-D/cd/dense-f32/call | 1.10.13 | 1.00366 [0.987057, 1.02054] | 4.48279e-07 / 4.48279e-07 | 16576 / 16576 | inconclusive |
| cd/lasso-D/cd/dense-f64/call | 1.10.13 | 1.00984 [1.00058, 1.01919] | 7.20869e-13 / 7.20869e-13 | 22160 / 22160 | slower |
| cd/lasso-D/cd/sparse-f32/call | 1.10.13 | 1.00994 [0.993079, 1.02708] | 4.48279e-07 / 4.48279e-07 | 16576 / 16576 | inconclusive |
| cd/lasso-D/cd/sparse-f64/call | 1.10.13 | 1.00982 [0.995261, 1.02459] | 7.20869e-13 / 7.20869e-13 | 22160 / 22160 | inconclusive |
| cd/lasso-dense/cd/R/call | 1.10.13 | 1.01276 [0.99763, 1.02812] | 5.75233e-08 / 5.75233e-08 | 6864 / 6864 | inconclusive |
| cd/lasso/cd/dense-f32/call | 1.10.13 | 1.01863 [0.976365, 1.06272] | 5.95994e-07 / 5.95994e-07 | 2336 / 2336 | inconclusive |
| cd/lasso/cd/dense-f64/call | 1.10.13 | 1.02283 [0.992179, 1.05444] | 2.74712e-12 / 2.74712e-12 | 3056 / 3056 | inconclusive |
| cd/lasso/cd/sparse-f32/call | 1.10.13 | 1.00912 [0.976807, 1.0425] | 5.95994e-07 / 5.95994e-07 | 2336 / 2336 | inconclusive |
| cd/lasso/cd/sparse-f64/call | 1.10.13 | 1.01778 [0.99412, 1.042] | 2.74712e-12 / 2.74712e-12 | 3056 / 3056 | inconclusive |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.10.13 | 0.976834 [0.936385, 1.01903] | 3.38453e-10 / 3.38453e-10 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.10.13 | 0.97961 [0.952783, 1.00719] | 5.60574e-11 / 5.60574e-11 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.10.13 | 0.980605 [0.945539, 1.01697] | 5.15948e-09 / 5.15948e-09 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.10.13 | 0.996386 [0.942957, 1.05284] | 6.11044e-09 / 6.11044e-09 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.10.13 | 0.9876 [0.945413, 1.03167] | 1.81951e-10 / 1.81951e-10 | 11504 / 11504 | inconclusive |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.10.13 | 1.00325 [0.97013, 1.0375] | 8.27036e-11 / 8.27036e-11 | 11504 / 11504 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.10.13 | 0.997763 [0.996551, 0.998977] | 1.4471e-10 / 1.4471e-10 | 32528 / 32528 | faster |
| gradient/lasso-C/apg/dense-f64/call | 1.10.13 | 0.99969 [0.998543, 1.00084] | 7.08895e-09 / 7.08895e-09 | 32528 / 32528 | inconclusive |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.10.13 | 1.02328 [0.971235, 1.07812] | 2.40199e-10 / 2.40199e-10 | 19136 / 19136 | inconclusive |
| gradient/lasso-C/pg/dense-f64/call | 1.10.13 | 1.00327 [0.997612, 1.00896] | 3.48906e-09 / 3.48906e-09 | 19136 / 19136 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.10.13 | 1.00092 [0.999109, 1.00274] | 1.67664e-10 / 1.67664e-10 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/apg/dense-f64/call | 1.10.13 | 1.00135 [0.999981, 1.00271] | 5.17253e-09 / 5.17253e-09 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.10.13 | 1.01609 [0.974825, 1.0591] | 1.65263e-10 / 1.65263e-10 | 28544 / 28544 | inconclusive |
| gradient/lasso/apg/acc-dense-f64/call | 1.10.13 | 1.01867 [1.007, 1.03047] | 1.23409e-10 / 1.23409e-10 | 6240 / 6240 | slower |
| gradient/lasso/pg/R/call | 1.10.13 | 1.00179 [0.987174, 1.01662] | 2.88018e-05 / 2.88018e-05 | 4816 / 4816 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.10.13 | 1.02733 [1.01135, 1.04357] | 1.13688e-10 / 1.13688e-10 | 4112 / 4112 | slower |
| gradient/lasso/pg/dense-f64/call | 1.10.13 | 1.02348 [1.01715, 1.02985] | 5.49245e-09 / 5.49245e-09 | 4112 / 4112 | slower |

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
| gradient/lasso-C/pg/dense-f32/call | 1.10.13 | rep01: target_missed; rep04: target_missed; rep05: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep04: target_missed; rep05: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso-D/apg/dense-f32/call | 1.10.13 | rep01: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep10: target_missed | rep01: target_missed; rep04: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep10: target_missed |
| gradient/lasso-D/pg/dense-f32/call | 1.10.13 | rep01: target_missed; rep05: target_missed; rep06: target_missed | rep01: target_missed; rep05: target_missed; rep06: target_missed; rep07: target_missed; rep09: target_missed |
| gradient/lasso-D/pg/dense-f64/call | 1.10.13 | rep03: target_missed | rep03: target_missed |
| gradient/lasso/apg/dense-f32/call | 1.10.13 | rep01: target_missed; rep02: target_missed; rep04: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep02: target_missed; rep04: target_missed; rep06: target_missed; rep07: target_missed; rep08: target_missed; rep09: target_missed; rep10: target_missed |
| gradient/lasso/apg/dense-f64/call | 1.10.13 | rep03: target_missed | rep03: target_missed |
| gradient/lasso/pg/dense-f32/call | 1.10.13 | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep06: target_missed; rep07: target_missed; rep09: target_missed; rep10: target_missed | rep01: target_missed; rep02: target_missed; rep03: target_missed; rep04: target_missed; rep06: target_missed; rep07: target_missed; rep09: target_missed; rep10: target_missed |
