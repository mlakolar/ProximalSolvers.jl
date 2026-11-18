# ProximalSolvers revision comparison

Ratios are after/before; a ratio below one indicates a shorter time after. Intervals use paired log ratios of per-repetition medians, matched by Julia version, case and repetition. All repetitions of an included case must be ok.

Single-run ratios are exploratory and have no confidence interval. An interval containing one is inconclusive. Excluded cases are not ties.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory. Median bytes is the median of repetition medians. Unexpected allocations flag workspace pairs with zero bytes before and positive bytes after.

Included cases: 46. Excluded cases: 4.

| Case | Julia | After/before [95% interval] | Worst accuracy before / after | Median bytes before / after | Assessment |
|---|---|---:|---:|---:|---|
| cd/group-lasso/cd/block-f32/call | 1.13.3 | 0.992438 [0.96637, 1.01921] | 5.83059e-07 / 5.83059e-07 | 16968 / 16968 | inconclusive |
| cd/group-lasso/cd/block-f64/call | 1.13.3 | 0.997373 [0.98058, 1.01445] | 6.71717e-12 / 6.71717e-12 | 17800 / 17800 | inconclusive |
| cd/group-lasso/cd/warm-block-f32/call | 1.13.3 | 1.00259 [0.976087, 1.02981] | 9.51463e-07 / 9.51463e-07 | 14904 / 14904 | inconclusive |
| cd/group-lasso/cd/warm-block-f64/call | 1.13.3 | 1.00771 [0.981117, 1.03503] | 5.78772e-12 / 5.78772e-12 | 15736 / 15736 | inconclusive |
| cd/lasso-B/cd/dense-f32/call | 1.13.3 | 0.997912 [0.970765, 1.02582] | 2.90908e-06 / 2.90908e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/dense-f64/call | 1.13.3 | 0.980801 [0.954439, 1.00789] | 1.06546e-11 / 1.06546e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/sparse-f32/call | 1.13.3 | 1.00226 [0.986262, 1.01852] | 2.90908e-06 / 2.90908e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/sparse-f64/call | 1.13.3 | 1.01006 [0.985568, 1.03516] | 1.06546e-11 / 1.06546e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/warm-dense-f32/call | 1.13.3 | 1.01596 [0.990909, 1.04165] | 2.89053e-06 / 2.89053e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/warm-dense-f64/call | 1.13.3 | 0.994483 [0.965791, 1.02403] | 2.62505e-11 / 2.62505e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.13.3 | 1.00539 [0.980706, 1.0307] | 2.89053e-06 / 2.89053e-06 | 5824 / 5824 | inconclusive |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.13.3 | 1.02022 [0.992013, 1.04922] | 2.62505e-11 / 2.62505e-11 | 8256 / 8256 | inconclusive |
| cd/lasso-C/cd/dense-f32/call | 1.13.3 | 1.00452 [0.990061, 1.01919] | 4.79371e-07 / 4.79371e-07 | 7096 / 7096 | inconclusive |
| cd/lasso-C/cd/dense-f64/call | 1.13.3 | 0.996242 [0.988029, 1.00452] | 7.24643e-12 / 7.24643e-12 | 11256 / 11256 | inconclusive |
| cd/lasso-C/cd/sparse-f32/call | 1.13.3 | 1.00306 [0.991504, 1.01475] | 4.79371e-07 / 4.79371e-07 | 7096 / 7096 | inconclusive |
| cd/lasso-C/cd/sparse-f64/call | 1.13.3 | 0.999588 [0.992986, 1.00623] | 7.24643e-12 / 7.24643e-12 | 11256 / 11256 | inconclusive |
| cd/lasso-D/cd/dense-f32/call | 1.13.3 | 1.01066 [0.98919, 1.0326] | 4.3274e-07 / 4.3274e-07 | 16192 / 16192 | inconclusive |
| cd/lasso-D/cd/dense-f64/call | 1.13.3 | 0.989415 [0.97514, 1.0039] | 4.40968e-13 / 4.40968e-13 | 21632 / 21632 | inconclusive |
| cd/lasso-D/cd/sparse-f32/call | 1.13.3 | 1.00146 [0.99742, 1.00552] | 4.3274e-07 / 4.3274e-07 | 16192 / 16192 | inconclusive |
| cd/lasso-D/cd/sparse-f64/call | 1.13.3 | 1.00083 [0.993556, 1.00816] | 4.40968e-13 / 4.40968e-13 | 21632 / 21632 | inconclusive |
| cd/lasso-weighted/cd/dense-f32/call | 1.13.3 | 0.992532 [0.95033, 1.03661] | 4.32305e-07 / 4.32305e-07 | 2112 / 2112 | inconclusive |
| cd/lasso-weighted/cd/dense-f64/call | 1.13.3 | 0.998251 [0.96992, 1.02741] | 1.57511e-12 / 1.57511e-12 | 2848 / 2848 | inconclusive |
| cd/lasso-weighted/cd/sparse-f32/call | 1.13.3 | 0.990239 [0.964961, 1.01618] | 4.32305e-07 / 4.32305e-07 | 2112 / 2112 | inconclusive |
| cd/lasso-weighted/cd/sparse-f64/call | 1.13.3 | 1.01936 [0.995853, 1.04342] | 1.57511e-12 / 1.57511e-12 | 2848 / 2848 | inconclusive |
| cd/lasso/cd/dense-f32/call | 1.13.3 | 1.00569 [0.982658, 1.02927] | 3.57172e-07 / 3.57172e-07 | 2096 / 2096 | inconclusive |
| cd/lasso/cd/dense-f64/call | 1.13.3 | 0.98302 [0.952777, 1.01422] | 1.3083e-12 / 1.3083e-12 | 2832 / 2832 | inconclusive |
| cd/lasso/cd/sparse-f32/call | 1.13.3 | 0.971629 [0.929386, 1.01579] | 3.57172e-07 / 3.57172e-07 | 2096 / 2096 | inconclusive |
| cd/lasso/cd/sparse-f64/call | 1.13.3 | 0.975946 [0.951894, 1.00061] | 1.3083e-12 / 1.3083e-12 | 2832 / 2832 | inconclusive |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.13.3 | 0.981063 [0.936611, 1.02762] | 5.34974e-10 / 5.34974e-10 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.13.3 | 1.02146 [0.98462, 1.05968] | 7.59748e-11 / 7.59748e-11 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/apg/dense-f64/call | 1.13.3 | 0.988268 [0.944035, 1.03457] | 4.81707e-09 / 4.81707e-09 | 16160 / 16160 | inconclusive |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.13.3 | 0.97019 [0.920596, 1.02246] | 1.81193e-10 / 1.81193e-10 | 11696 / 11696 | inconclusive |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.13.3 | 1.02914 [0.986987, 1.0731] | 7.27499e-11 / 7.27499e-11 | 11696 / 11696 | inconclusive |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.13.3 | 0.999874 [0.996885, 1.00287] | 1.66286e-10 / 1.66286e-10 | 32032 / 32032 | inconclusive |
| gradient/lasso-C/apg/dense-f64/call | 1.13.3 | 0.999103 [0.996151, 1.00206] | 1.8743e-09 / 1.8743e-09 | 32032 / 32032 | inconclusive |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.13.3 | 1.00117 [0.997877, 1.00448] | 1.29959e-10 / 1.29959e-10 | 18752 / 18752 | inconclusive |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.13.3 | 0.998492 [0.995914, 1.00108] | 1.36519e-10 / 1.36519e-10 | 31384 / 31384 | inconclusive |
| gradient/lasso-D/apg/dense-f64/call | 1.13.3 | 0.998725 [0.996174, 1.00128] | 3.71883e-09 / 3.71883e-09 | 31384 / 31384 | inconclusive |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.13.3 | 0.999571 [0.997155, 1.00199] | 1.41756e-10 / 1.41756e-10 | 28008 / 28008 | inconclusive |
| gradient/lasso-D/pg/dense-f64/call | 1.13.3 | 1.00026 [0.99816, 1.00236] | 4.01926e-09 / 4.01926e-09 | 28008 / 28008 | inconclusive |
| gradient/lasso-weighted/apg/acc-dense-f64/call | 1.13.3 | 1.00893 [0.992906, 1.02522] | 1.9928e-10 / 1.9928e-10 | 6272 / 6272 | inconclusive |
| gradient/lasso-weighted/pg/acc-dense-f64/call | 1.13.3 | 0.996136 [0.977392, 1.01524] | 2.79256e-10 / 2.79256e-10 | 4080 / 4080 | inconclusive |
| gradient/lasso/apg/acc-dense-f64/call | 1.13.3 | 1.00409 [0.988063, 1.02037] | 1.0779e-10 / 1.0779e-10 | 6256 / 6256 | inconclusive |
| gradient/lasso/apg/dense-f64/call | 1.13.3 | 1.00748 [0.999561, 1.01547] | 2.05048e-09 / 2.05048e-09 | 6256 / 6256 | inconclusive |
| gradient/lasso/pg/acc-dense-f64/call | 1.13.3 | 1.01351 [0.997902, 1.02937] | 1.28759e-10 / 1.28759e-10 | 4064 / 4064 | inconclusive |
| gradient/lasso/pg/dense-f64/call | 1.13.3 | 1.00198 [0.990443, 1.01365] | 2.60529e-09 / 2.60529e-09 | 4064 / 4064 | inconclusive |

## Excluded cases

| Case | Julia | Before reasons | After reasons |
|---|---|---|---|
| gradient/lasso-B/apg/warm-dense-f64/call | 1.13.3 | rep03: target_missed; rep06: target_missed | rep03: target_missed; rep06: target_missed |
| gradient/lasso-B/pg/dense-f64/call | 1.13.3 | rep03: target_missed; rep05: target_missed; rep08: target_missed | rep03: target_missed; rep05: target_missed; rep08: target_missed |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.13.3 | rep06: target_missed | rep06: target_missed |
| gradient/lasso-C/pg/dense-f64/call | 1.13.3 | rep01: target_missed | rep01: target_missed |
