# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 46. Excluded cases: 4.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| cd/group-lasso/cd/block-f32/call | 1.10.13 | 0.961271 [0.922603, 1.00156] | 1.08829e-06 / 1.08829e-06 | 16728 / 16728 | inconclusive |
| cd/group-lasso/cd/block-f64/call | 1.10.13 | 0.978984 [0.961461, 0.996827] | 4.75226e-12 / 4.75226e-12 | 17672 / 17672 | faster |
| cd/group-lasso/cd/warm-block-f32/call | 1.10.13 | 0.965946 [0.933264, 0.999773] | 6.82772e-07 / 6.82772e-07 | 15632 / 15632 | faster |
| cd/group-lasso/cd/warm-block-f64/call | 1.10.13 | 0.982815 [0.952131, 1.01449] | 7.27282e-12 / 7.27282e-12 | 16576 / 16576 | inconclusive |
| cd/lasso-B/cd/dense-f32/call | 1.10.13 | 0.989558 [0.972396, 1.00702] | 3.19554e-06 / 3.19554e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/dense-f64/call | 1.10.13 | 0.985423 [0.959943, 1.01158] | 3.17081e-11 / 3.17081e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/sparse-f32/call | 1.10.13 | 0.994476 [0.986468, 1.00255] | 3.19554e-06 / 3.19554e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/sparse-f64/call | 1.10.13 | 1.00253 [0.982572, 1.02289] | 3.17081e-11 / 3.17081e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/warm-dense-f32/call | 1.10.13 | 1.00148 [0.973632, 1.03013] | 1.37177e-06 / 1.37177e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/warm-dense-f64/call | 1.10.13 | 0.989757 [0.968351, 1.01164] | 3.3179e-11 / 3.3179e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.10.13 | 0.992896 [0.960806, 1.02606] | 1.37177e-06 / 1.37177e-06 | 6064 / 6064 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.10.13 | 1.00113 [0.981753, 1.02088] | 3.3179e-11 / 3.3179e-11 | 8288 / 8288 | inconclusive |
| cd/lasso-C/cd/dense-f32/call | 1.10.13 | 0.992885 [0.984483, 1.00136] | 5.59476e-07 / 5.59476e-07 | 7376 / 7376 | inconclusive |
| cd/lasso-C/cd/dense-f64/call | 1.10.13 | 0.996673 [0.983857, 1.00966] | 6.05071e-12 / 6.05071e-12 | 11696 / 11696 | inconclusive |
| cd/lasso-C/cd/sparse-f32/call | 1.10.13 | 0.997441 [0.985259, 1.00977] | 5.59476e-07 / 5.59476e-07 | 7376 / 7376 | inconclusive |
| cd/lasso-C/cd/sparse-f64/call | 1.10.13 | 0.997882 [0.986136, 1.00977] | 6.05071e-12 / 6.05071e-12 | 11696 / 11696 | inconclusive |
| cd/lasso-D/cd/dense-f32/call | 1.10.13 | 0.986934 [0.974346, 0.999685] | 4.48279e-07 / 4.48279e-07 | 16576 / 16576 | faster |
| cd/lasso-D/cd/dense-f64/call | 1.10.13 | 0.996562 [0.976845, 1.01668] | 7.20869e-13 / 7.20869e-13 | 22160 / 22160 | inconclusive |
| cd/lasso-D/cd/sparse-f32/call | 1.10.13 | 0.995126 [0.98834, 1.00196] | 4.48279e-07 / 4.48279e-07 | 16576 / 16576 | inconclusive |
| cd/lasso-D/cd/sparse-f64/call | 1.10.13 | 1.00491 [0.986255, 1.02391] | 7.20869e-13 / 7.20869e-13 | 22160 / 22160 | inconclusive |
| cd/lasso-weighted/cd/dense-f32/call | 1.10.13 | 0.985259 [0.962279, 1.00879] | 3.79078e-07 / 3.79078e-07 | 2352 / 2352 | inconclusive |
| cd/lasso-weighted/cd/dense-f64/call | 1.10.13 | 0.999398 [0.977349, 1.02194] | 1.05681e-12 / 1.05681e-12 | 3072 / 3072 | inconclusive |
| cd/lasso-weighted/cd/sparse-f32/call | 1.10.13 | 1.00888 [0.977579, 1.04118] | 3.79078e-07 / 3.79078e-07 | 2352 / 2352 | inconclusive |
| cd/lasso-weighted/cd/sparse-f64/call | 1.10.13 | 0.996522 [0.957685, 1.03693] | 1.05681e-12 / 1.05681e-12 | 3072 / 3072 | inconclusive |
| cd/lasso/cd/dense-f32/call | 1.10.13 | 0.9764 [0.939212, 1.01506] | 5.95994e-07 / 5.95994e-07 | 2336 / 2336 | inconclusive |
| cd/lasso/cd/dense-f64/call | 1.10.13 | 1.00916 [0.991996, 1.02662] | 2.74712e-12 / 2.74712e-12 | 3056 / 3056 | inconclusive |
| cd/lasso/cd/sparse-f32/call | 1.10.13 | 1.00332 [0.961918, 1.04651] | 5.95994e-07 / 5.95994e-07 | 2336 / 2336 | inconclusive |
| cd/lasso/cd/sparse-f64/call | 1.10.13 | 1.01012 [0.99483, 1.02564] | 2.74712e-12 / 2.74712e-12 | 3056 / 3056 | inconclusive |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.10.13 | 0.991767 [0.964403, 1.01991] | 3.38453e-10 / 3.38453e-10 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.10.13 | 0.991577 [0.970449, 1.01317] | 5.60574e-11 / 5.60574e-11 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.10.13 | 1.00343 [0.986684, 1.02046] | 5.15948e-09 / 5.15948e-09 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.10.13 | 1.00452 [0.986394, 1.02298] | 6.11044e-09 / 6.11044e-09 | 15904 / 15904 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.10.13 | 0.970001 [0.932144, 1.0094] | 1.81951e-10 / 1.81951e-10 | 11504 / 11504 | inconclusive |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.10.13 | 1.00787 [0.960723, 1.05733] | 8.27036e-11 / 8.27036e-11 | 11504 / 11504 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.10.13 | 0.999815 [0.997114, 1.00252] | 1.4471e-10 / 1.4471e-10 | 32528 / 32528 | inconclusive |
| gradient/lasso-C/apg/dense-f64/call | 1.10.13 | 1.00031 [0.997622, 1.00301] | 7.08895e-09 / 7.08895e-09 | 32528 / 32528 | inconclusive |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.10.13 | 0.999861 [0.997517, 1.00221] | 2.40199e-10 / 2.40199e-10 | 19136 / 19136 | inconclusive |
| gradient/lasso-C/pg/dense-f64/call | 1.10.13 | 0.999868 [0.996778, 1.00297] | 3.48906e-09 / 3.48906e-09 | 19136 / 19136 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.10.13 | 0.999577 [0.997497, 1.00166] | 1.67664e-10 / 1.67664e-10 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/apg/dense-f64/call | 1.10.13 | 1.00011 [0.997519, 1.00272] | 5.17253e-09 / 5.17253e-09 | 32144 / 32144 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.10.13 | 0.997989 [0.994456, 1.00153] | 1.65263e-10 / 1.65263e-10 | 28544 / 28544 | inconclusive |
| gradient/lasso-weighted/apg/acc-dense-f64/call | 1.10.13 | 1.00949 [0.984711, 1.0349] | 4.16952e-11 / 4.16952e-11 | 6256 / 6256 | inconclusive |
| gradient/lasso-weighted/pg/acc-dense-f64/call | 1.10.13 | 0.995501 [0.983094, 1.00806] | 6.73921e-11 / 6.73921e-11 | 4128 / 4128 | inconclusive |
| gradient/lasso/apg/acc-dense-f64/call | 1.10.13 | 0.997852 [0.984381, 1.01151] | 1.23409e-10 / 1.23409e-10 | 6240 / 6240 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.10.13 | 1.00167 [0.99276, 1.01066] | 1.13688e-10 / 1.13688e-10 | 4112 / 4112 | inconclusive |
| gradient/lasso/pg/dense-f64/call | 1.10.13 | 0.996325 [0.984431, 1.00836] | 5.49245e-09 / 5.49245e-09 | 4112 / 4112 | inconclusive |

## Excluded cases

| Case | Julia | Before reasons | After reasons |
|---|---|---|---|
| gradient/lasso-B/pg/dense-f64/call | 1.10.13 | rep10: target_missed | rep10: target_missed |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.10.13 | rep06: target_missed; rep10: target_missed | rep06: target_missed; rep10: target_missed |
| gradient/lasso-D/pg/dense-f64/call | 1.10.13 | rep03: target_missed | rep03: target_missed |
| gradient/lasso/apg/dense-f64/call | 1.10.13 | rep03: target_missed | rep03: target_missed |
