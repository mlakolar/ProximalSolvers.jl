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
| cd/lasso-B/cd/dense-f32/call | 1.10.13 | 1.01058 [0.99582, 1.02556] | 3.19554e-06 / 3.19554e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/dense-f64/call | 1.10.13 | 1.01154 [0.986178, 1.03754] | 3.17081e-11 / 3.17081e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/sparse-f32/call | 1.10.13 | 0.995386 [0.984976, 1.00591] | 3.19554e-06 / 3.19554e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/sparse-f64/call | 1.10.13 | 1.00675 [0.977195, 1.03719] | 3.17081e-11 / 3.17081e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/warm-dense-f32/call | 1.10.13 | 0.997304 [0.981339, 1.01353] | 1.37177e-06 / 1.37177e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/warm-dense-f64/call | 1.10.13 | 1.00809 [0.994539, 1.02182] | 3.3179e-11 / 3.3179e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.10.13 | 0.999232 [0.990003, 1.00855] | 1.37177e-06 / 1.37177e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.10.13 | 1.02471 [0.985845, 1.0651] | 3.3179e-11 / 3.3179e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-C/cd/dense-f32/call | 1.10.13 | 1.00567 [0.995246, 1.0162] | 5.59476e-07 / 5.59476e-07 | 7376 / 7376 | inconclusive |
| cd/lasso-C/cd/dense-f64/call | 1.10.13 | 0.993527 [0.983284, 1.00388] | 6.05071e-12 / 6.05071e-12 | 11696 / 11696 | inconclusive |
| cd/lasso-C/cd/sparse-f32/call | 1.10.13 | 1.00107 [0.994932, 1.00724] | 5.59476e-07 / 5.59476e-07 | 7376 / 7376 | inconclusive |
| cd/lasso-C/cd/sparse-f64/call | 1.10.13 | 0.997226 [0.988954, 1.00557] | 6.05071e-12 / 6.05071e-12 | 11696 / 11696 | inconclusive |
| cd/lasso-D/cd/dense-f32/call | 1.10.13 | 1.003 [0.980792, 1.0257] | 4.48279e-07 / 4.48279e-07 | 16576 / 16576 | inconclusive |
| cd/lasso-D/cd/dense-f64/call | 1.10.13 | 1.00297 [0.983421, 1.02291] | 7.20869e-13 / 7.20869e-13 | 22160 / 22160 | inconclusive |
| cd/lasso-D/cd/sparse-f32/call | 1.10.13 | 1.00331 [0.989028, 1.01779] | 4.48279e-07 / 4.48279e-07 | 16576 / 16576 | inconclusive |
| cd/lasso-D/cd/sparse-f64/call | 1.10.13 | 1.01601 [1.00262, 1.02959] | 7.20869e-13 / 7.20869e-13 | 22160 / 22160 | slower |
| cd/lasso-dense/cd/R/call | 1.10.13 | 1.01436 [1.00373, 1.0251] | 5.75233e-08 / 5.75233e-08 | 6864 / 6864 | slower |
| cd/lasso/cd/dense-f32/call | 1.10.13 | 1.01739 [0.96589, 1.07164] | 5.95994e-07 / 5.95994e-07 | 2336 / 2336 | inconclusive |
| cd/lasso/cd/dense-f64/call | 1.10.13 | 1.02949 [0.996886, 1.06316] | 2.74712e-12 / 2.74712e-12 | 3056 / 3056 | inconclusive |
| cd/lasso/cd/sparse-f32/call | 1.10.13 | 1.00986 [0.967647, 1.05391] | 5.95994e-07 / 5.95994e-07 | 2336 / 2336 | inconclusive |
| cd/lasso/cd/sparse-f64/call | 1.10.13 | 1.01696 [1.00277, 1.03136] | 2.74712e-12 / 2.74712e-12 | 3056 / 3056 | slower |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.10.13 | 0.994072 [0.96329, 1.02584] | 3.38453e-10 / 3.38453e-10 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.10.13 | 0.999405 [0.983927, 1.01513] | 5.60574e-11 / 5.60574e-11 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.10.13 | 0.998763 [0.966048, 1.03258] | 5.15948e-09 / 5.15948e-09 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.10.13 | 0.987837 [0.94677, 1.03069] | 6.11044e-09 / 6.11044e-09 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.10.13 | 1.00764 [0.966218, 1.05084] | 1.81951e-10 / 1.81951e-10 | 11504 / 11504 | inconclusive |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.10.13 | 1.02371 [0.989233, 1.05939] | 8.27036e-11 / 8.27036e-11 | 11504 / 11504 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.10.13 | 0.998816 [0.99655, 1.00109] | 1.4471e-10 / 1.4471e-10 | 32528 / 32528 | inconclusive |
| gradient/lasso-C/apg/dense-f64/call | 1.10.13 | 0.998686 [0.996092, 1.00129] | 7.08895e-09 / 7.08895e-09 | 32528 / 32528 | inconclusive |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.10.13 | 1.02589 [0.973517, 1.08108] | 2.40199e-10 / 2.40199e-10 | 19136 / 19136 | inconclusive |
| gradient/lasso-C/pg/dense-f64/call | 1.10.13 | 1.00313 [0.995107, 1.01122] | 3.48906e-09 / 3.48906e-09 | 19136 / 19136 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.10.13 | 0.999936 [0.998647, 1.00123] | 1.67664e-10 / 1.67664e-10 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/apg/dense-f64/call | 1.10.13 | 1.00001 [0.997447, 1.00258] | 5.17253e-09 / 5.17253e-09 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.10.13 | 1.01559 [0.973137, 1.05989] | 1.65263e-10 / 1.65263e-10 | 28544 / 28544 | inconclusive |
| gradient/lasso/apg/acc-dense-f64/call | 1.10.13 | 1.01962 [1.00643, 1.03297] | 1.23409e-10 / 1.23409e-10 | 6240 / 6240 | slower |
| gradient/lasso/pg/R/call | 1.10.13 | 1.00914 [0.998257, 1.02015] | 2.88018e-05 / 2.88018e-05 | 4816 / 4816 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.10.13 | 1.03417 [1.01776, 1.05084] | 1.13688e-10 / 1.13688e-10 | 4112 / 4112 | slower |
| gradient/lasso/pg/dense-f64/call | 1.10.13 | 1.02862 [1.01804, 1.03931] | 5.49245e-09 / 5.49245e-09 | 4112 / 4112 | slower |

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
