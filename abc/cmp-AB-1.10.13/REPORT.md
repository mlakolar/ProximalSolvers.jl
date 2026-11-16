# CROSS-DEPENDENCY comparison (#307)

Produced by compare_crossdep.py: the harness's compare.py with only the declared
ProximalBase identity keys exempted from series matching: proximalbase_version, proximalbase_hash.

| julia | key | before | after |
|---|---|---|---|
| 1.10.13 | proximalbase_hash | 8041f0d0159031ecbe45097cd4239e2609165ff2 | 9b951b73f59e5bbf78b502cdec3c7aa954153b96 |
| 1.10.13 | proximalbase_version | 0.6.0-DEV | 0.6.0-DEV |

# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 38. Excluded cases: 14.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| cd/lasso-B/cd/dense-f32/call | 1.10.13 | 0.999854 [0.987705, 1.01215] | 3.19554e-06 / 3.19554e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/dense-f64/call | 1.10.13 | 1.01054 [0.982267, 1.03963] | 3.17081e-11 / 3.17081e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/sparse-f32/call | 1.10.13 | 1.00817 [0.986696, 1.03012] | 3.19554e-06 / 3.19554e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/sparse-f64/call | 1.10.13 | 0.994513 [0.96914, 1.02055] | 3.17081e-11 / 3.17081e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/warm-dense-f32/call | 1.10.13 | 0.998722 [0.98129, 1.01646] | 1.37177e-06 / 1.37177e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/warm-dense-f64/call | 1.10.13 | 1.01656 [0.999825, 1.03358] | 3.3179e-11 / 3.3179e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.10.13 | 0.99269 [0.974374, 1.01135] | 1.37177e-06 / 1.37177e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.10.13 | 0.995859 [0.9801, 1.01187] | 3.3179e-11 / 3.3179e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-C/cd/dense-f32/call | 1.10.13 | 1.00107 [0.994454, 1.00774] | 5.59476e-07 / 5.59476e-07 | 7376 / 7376 | inconclusive |
| cd/lasso-C/cd/dense-f64/call | 1.10.13 | 0.990604 [0.980777, 1.00053] | 6.05071e-12 / 6.05071e-12 | 11696 / 11696 | inconclusive |
| cd/lasso-C/cd/sparse-f32/call | 1.10.13 | 0.997977 [0.992413, 1.00357] | 5.59476e-07 / 5.59476e-07 | 7376 / 7376 | inconclusive |
| cd/lasso-C/cd/sparse-f64/call | 1.10.13 | 1.00088 [0.989335, 1.01255] | 6.05071e-12 / 6.05071e-12 | 11696 / 11696 | inconclusive |
| cd/lasso-D/cd/dense-f32/call | 1.10.13 | 0.99934 [0.983299, 1.01564] | 4.48279e-07 / 4.48279e-07 | 16576 / 16576 | inconclusive |
| cd/lasso-D/cd/dense-f64/call | 1.10.13 | 0.993198 [0.975844, 1.01086] | 7.20869e-13 / 7.20869e-13 | 22160 / 22160 | inconclusive |
| cd/lasso-D/cd/sparse-f32/call | 1.10.13 | 0.993434 [0.980868, 1.00616] | 4.48279e-07 / 4.48279e-07 | 16576 / 16576 | inconclusive |
| cd/lasso-D/cd/sparse-f64/call | 1.10.13 | 1.00613 [0.998603, 1.01372] | 7.20869e-13 / 7.20869e-13 | 22160 / 22160 | inconclusive |
| cd/lasso-dense/cd/R/call | 1.10.13 | 1.00157 [0.993079, 1.01014] | 5.75233e-08 / 5.75233e-08 | 6864 / 6864 | inconclusive |
| cd/lasso/cd/dense-f32/call | 1.10.13 | 0.998789 [0.950957, 1.04903] | 5.95994e-07 / 5.95994e-07 | 2336 / 2336 | inconclusive |
| cd/lasso/cd/dense-f64/call | 1.10.13 | 1.00651 [0.981727, 1.03192] | 2.74712e-12 / 2.74712e-12 | 3056 / 3056 | inconclusive |
| cd/lasso/cd/sparse-f32/call | 1.10.13 | 1.00073 [0.969712, 1.03274] | 5.95994e-07 / 5.95994e-07 | 2336 / 2336 | inconclusive |
| cd/lasso/cd/sparse-f64/call | 1.10.13 | 0.9992 [0.974524, 1.0245] | 2.74712e-12 / 2.74712e-12 | 3056 / 3056 | inconclusive |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.10.13 | 1.01765 [0.973337, 1.06397] | 3.38453e-10 / 3.38453e-10 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.10.13 | 1.02021 [0.992629, 1.04855] | 5.60574e-11 / 5.60574e-11 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.10.13 | 1.01852 [0.981361, 1.05708] | 5.15948e-09 / 5.15948e-09 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.10.13 | 0.99142 [0.955037, 1.02919] | 6.11044e-09 / 6.11044e-09 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.10.13 | 1.02029 [0.978948, 1.06339] | 1.81951e-10 / 1.81951e-10 | 11504 / 11504 | inconclusive |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.10.13 | 1.0204 [0.989661, 1.05209] | 8.27036e-11 / 8.27036e-11 | 11504 / 11504 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.10.13 | 1.00106 [0.998612, 1.0035] | 1.4471e-10 / 1.4471e-10 | 32528 / 32528 | inconclusive |
| gradient/lasso-C/apg/dense-f64/call | 1.10.13 | 0.998996 [0.99632, 1.00168] | 7.08895e-09 / 7.08895e-09 | 32528 / 32528 | inconclusive |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.10.13 | 1.00255 [1.00033, 1.00477] | 2.40199e-10 / 2.40199e-10 | 19136 / 19136 | slower |
| gradient/lasso-C/pg/dense-f64/call | 1.10.13 | 0.99986 [0.996835, 1.00289] | 3.48906e-09 / 3.48906e-09 | 19136 / 19136 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.10.13 | 0.999014 [0.997219, 1.00081] | 1.67664e-10 / 1.67664e-10 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/apg/dense-f64/call | 1.10.13 | 0.998668 [0.996508, 1.00083] | 5.17253e-09 / 5.17253e-09 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.10.13 | 0.99951 [0.994906, 1.00413] | 1.65263e-10 / 1.65263e-10 | 28544 / 28544 | inconclusive |
| gradient/lasso/apg/acc-dense-f64/call | 1.10.13 | 1.00093 [0.990195, 1.01179] | 1.23409e-10 / 1.23409e-10 | 6240 / 6240 | inconclusive |
| gradient/lasso/pg/R/call | 1.10.13 | 1.00734 [0.993666, 1.0212] | 2.88018e-05 / 2.88018e-05 | 4816 / 4816 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.10.13 | 1.00666 [0.997188, 1.01622] | 1.13688e-10 / 1.13688e-10 | 4112 / 4112 | inconclusive |
| gradient/lasso/pg/dense-f64/call | 1.10.13 | 1.00502 [0.997544, 1.01256] | 5.49245e-09 / 5.49245e-09 | 4112 / 4112 | inconclusive |

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
