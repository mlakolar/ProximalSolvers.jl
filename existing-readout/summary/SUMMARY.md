# ProximalSolvers benchmark summary

Record integrity: valid. Repetitions per Julia version: 10.

Time is the arithmetic mean of the per-repetition medians. Each median uses only ok samples. The Student-t interval uses independent repetitions, never individual samples. One repetition has a NaN interval. The fastest run is never selected.

Every repetition contributes to the summary. If any repetition has no ok samples, the aggregate time and interval are NaN. Status counts include all repetitions, including those with numerical failures. Bytes are aggregated from the same ok samples; mean bytes is the mean of repetition medians. Worst accuracy is the maximum reported worst_value, ignoring NaN values; status counts retain uncertifiable results.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory.

| Case | Julia | Runs with timing / total | Mean median (ns) | 95% interval (ns) | Mean / median bytes | Worst accuracy | Status counts |
|---|---|---:|---:|---:|---:|---:|---|
| cd/lasso-B/cd/dense-f32/call | 1.10.13 | 10 / 10 | 49226.5 | [42577, 55876] | 6064 / 6064 | 3.19554e-06 | ok=10 |
| cd/lasso-B/cd/dense-f64/call | 1.10.13 | 10 / 10 | 69524.2 | [54203.3, 84845.1] | 8288 / 8288 | 3.17081e-11 | ok=10 |
| cd/lasso-B/cd/sparse-f32/call | 1.10.13 | 10 / 10 | 49033.4 | [42317.9, 55748.9] | 6064 / 6064 | 3.19554e-06 | ok=10 |
| cd/lasso-B/cd/sparse-f64/call | 1.10.13 | 10 / 10 | 70869.4 | [53574, 88164.8] | 8288 / 8288 | 3.17081e-11 | ok=10 |
| cd/lasso-B/cd/warm-dense-f32/call | 1.10.13 | 10 / 10 | 38819 | [35877.9, 41760.1] | 6064 / 6064 | 1.37177e-06 | ok=10 |
| cd/lasso-B/cd/warm-dense-f64/call | 1.10.13 | 10 / 10 | 54499.9 | [46816.9, 62182.9] | 8288 / 8288 | 3.3179e-11 | ok=10 |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.10.13 | 10 / 10 | 38528.9 | [35623.2, 41434.6] | 6064 / 6064 | 1.37177e-06 | ok=10 |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.10.13 | 10 / 10 | 55160.9 | [45905.9, 64415.9] | 8288 / 8288 | 3.3179e-11 | ok=10 |
| cd/lasso-C/cd/dense-f32/call | 1.10.13 | 10 / 10 | 79084.1 | [78306.2, 79862] | 7376 / 7376 | 5.59476e-07 | ok=10 |
| cd/lasso-C/cd/dense-f64/call | 1.10.13 | 10 / 10 | 109177 | [106778, 111576] | 11696 / 11696 | 6.05071e-12 | ok=10 |
| cd/lasso-C/cd/sparse-f32/call | 1.10.13 | 10 / 10 | 78813.4 | [77996.3, 79630.5] | 7376 / 7376 | 5.59476e-07 | ok=10 |
| cd/lasso-C/cd/sparse-f64/call | 1.10.13 | 10 / 10 | 108294 | [105756, 110831] | 11696 / 11696 | 6.05071e-12 | ok=10 |
| cd/lasso-D/cd/dense-f32/call | 1.10.13 | 10 / 10 | 113101 | [110885, 115317] | 16576 / 16576 | 4.48279e-07 | ok=10 |
| cd/lasso-D/cd/dense-f64/call | 1.10.13 | 10 / 10 | 135595 | [133087, 138103] | 22160 / 22160 | 7.20869e-13 | ok=10 |
| cd/lasso-D/cd/sparse-f32/call | 1.10.13 | 10 / 10 | 112680 | [110048, 115312] | 16576 / 16576 | 4.48279e-07 | ok=10 |
| cd/lasso-D/cd/sparse-f64/call | 1.10.13 | 10 / 10 | 133647 | [131337, 135957] | 22160 / 22160 | 7.20869e-13 | ok=10 |
| cd/lasso-dense/cd/R/call | 1.10.13 | 10 / 10 | 56590.2 | [55905.2, 57275.2] | 6864 / 6864 | 5.75233e-08 | ok=10 |
| cd/lasso/cd/dense-f32/call | 1.10.13 | 10 / 10 | 7785.2 | [7392.83, 8177.57] | 2336 / 2336 | 5.95994e-07 | ok=10 |
| cd/lasso/cd/dense-f64/call | 1.10.13 | 10 / 10 | 10400.2 | [9989.74, 10810.7] | 3056 / 3056 | 2.74712e-12 | ok=10 |
| cd/lasso/cd/sparse-f32/call | 1.10.13 | 10 / 10 | 7654.2 | [7157.2, 8151.2] | 2336 / 2336 | 5.95994e-07 | ok=10 |
| cd/lasso/cd/sparse-f64/call | 1.10.13 | 10 / 10 | 10217.4 | [9783.69, 10651.1] | 3056 / 3056 | 2.74712e-12 | ok=10 |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 994348 | [727281, 1.26141e+06] | 15904 / 15904 | 3.38453e-10 | ok=10 |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.10.13 | 10 / 10 | 804810 | [477460, 1.13216e+06] | 15904 / 15904 | 5.60574e-11 | ok=10 |
| gradient/lasso-B/apg/dense-f32/call | 1.10.13 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.0003147 | target_missed=10 |
| gradient/lasso-B/apg/dense-f64/call | 1.10.13 | 10 / 10 | 983866 | [775437, 1.19229e+06] | 15904 / 15904 | 5.15948e-09 | ok=10 |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.10.13 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000332694 | ok=1, target_missed=9 |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.10.13 | 10 / 10 | 720316 | [514261, 926370] | 15904 / 15904 | 6.11044e-09 | ok=10 |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.39245e+06 | [745464, 2.03945e+06] | 11504 / 11504 | 1.81951e-10 | ok=10 |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.10.13 | 10 / 10 | 1.00629e+06 | [385101, 1.62748e+06] | 11504 / 11504 | 8.27036e-11 | ok=10 |
| gradient/lasso-B/pg/dense-f32/call | 1.10.13 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.000237667 | target_missed=10 |
| gradient/lasso-B/pg/dense-f64/call | 1.10.13 | 9 / 10 | nan | [nan, nan] | nan / nan | 2.74234e-08 | ok=9, target_missed=1 |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.10.13 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000644369 | ok=1, target_missed=9 |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.10.13 | 8 / 10 | nan | [nan, nan] | nan / nan | 1.08631e-08 | ok=8, target_missed=2 |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.32811e+06 | [1.22192e+06, 1.4343e+06] | 32528 / 32528 | 1.4471e-10 | ok=10 |
| gradient/lasso-C/apg/dense-f32/call | 1.10.13 | 4 / 10 | nan | [nan, nan] | nan / nan | 6.82462e-05 | ok=4, target_missed=6 |
| gradient/lasso-C/apg/dense-f64/call | 1.10.13 | 10 / 10 | 1.35672e+06 | [1.23114e+06, 1.48231e+06] | 32528 / 32528 | 7.08895e-09 | ok=10 |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.12778e+06 | [936095, 1.31946e+06] | 19136 / 19136 | 2.40199e-10 | ok=10 |
| gradient/lasso-C/pg/dense-f32/call | 1.10.13 | 4 / 10 | nan | [nan, nan] | nan / nan | 0.000162929 | ok=4, target_missed=6 |
| gradient/lasso-C/pg/dense-f64/call | 1.10.13 | 10 / 10 | 1.04401e+06 | [918036, 1.16999e+06] | 19136 / 19136 | 3.48906e-09 | ok=10 |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.71205e+06 | [1.6209e+06, 1.80321e+06] | 32144 / 32144 | 1.67664e-10 | ok=10 |
| gradient/lasso-D/apg/dense-f32/call | 1.10.13 | 3 / 10 | nan | [nan, nan] | nan / nan | 3.43689e-05 | ok=3, target_missed=7 |
| gradient/lasso-D/apg/dense-f64/call | 1.10.13 | 10 / 10 | 1.71487e+06 | [1.55507e+06, 1.87467e+06] | 32144 / 32144 | 5.17253e-09 | ok=10 |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.33998e+06 | [1.25431e+06, 1.42565e+06] | 28544 / 28544 | 1.65263e-10 | ok=10 |
| gradient/lasso-D/pg/dense-f32/call | 1.10.13 | 7 / 10 | nan | [nan, nan] | nan / nan | 8.38089e-05 | ok=7, target_missed=3 |
| gradient/lasso-D/pg/dense-f64/call | 1.10.13 | 9 / 10 | nan | [nan, nan] | nan / nan | 1.16163e-08 | ok=9, target_missed=1 |
| gradient/lasso/apg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 54693.5 | [51720.9, 57666.1] | 6240 / 6240 | 1.23409e-10 | ok=10 |
| gradient/lasso/apg/dense-f32/call | 1.10.13 | 2 / 10 | nan | [nan, nan] | nan / nan | 9.09694e-05 | ok=2, target_missed=8 |
| gradient/lasso/apg/dense-f64/call | 1.10.13 | 9 / 10 | nan | [nan, nan] | nan / nan | 1.24599e-08 | ok=9, target_missed=1 |
| gradient/lasso/pg/R/call | 1.10.13 | 10 / 10 | 53832.3 | [53003.8, 54660.8] | 4816 / 4816 | 2.88018e-05 | ok=10 |
| gradient/lasso/pg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 37587.3 | [34449.4, 40725.2] | 4112 / 4112 | 1.13688e-10 | ok=10 |
| gradient/lasso/pg/dense-f32/call | 1.10.13 | 2 / 10 | nan | [nan, nan] | nan / nan | 9.23022e-05 | ok=2, target_missed=8 |
| gradient/lasso/pg/dense-f64/call | 1.10.13 | 10 / 10 | 34618.9 | [30313, 38924.8] | 4112 / 4112 | 5.49245e-09 | ok=10 |
| cd/lasso-B/cd/dense-f32/call | 1.13.3 | 10 / 10 | 35694.8 | [30570.7, 40818.9] | 5824 / 5824 | 2.90908e-06 | ok=10 |
| cd/lasso-B/cd/dense-f64/call | 1.13.3 | 10 / 10 | 60833.1 | [48543.2, 73123] | 8256 / 8256 | 1.06546e-11 | ok=10 |
| cd/lasso-B/cd/sparse-f32/call | 1.13.3 | 10 / 10 | 36033.4 | [30688.7, 41378.1] | 5824 / 5824 | 2.90908e-06 | ok=10 |
| cd/lasso-B/cd/sparse-f64/call | 1.13.3 | 10 / 10 | 61227.2 | [48298.7, 74155.7] | 8256 / 8256 | 1.06546e-11 | ok=10 |
| cd/lasso-B/cd/warm-dense-f32/call | 1.13.3 | 10 / 10 | 25962.3 | [23721.3, 28203.3] | 5824 / 5824 | 2.89053e-06 | ok=10 |
| cd/lasso-B/cd/warm-dense-f64/call | 1.13.3 | 10 / 10 | 47979.1 | [39779.3, 56178.9] | 8256 / 8256 | 2.62505e-11 | ok=10 |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.13.3 | 10 / 10 | 25823.8 | [23065.2, 28582.4] | 5824 / 5824 | 2.89053e-06 | ok=10 |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.13.3 | 10 / 10 | 46715.1 | [39033.4, 54396.8] | 8256 / 8256 | 2.62505e-11 | ok=10 |
| cd/lasso-C/cd/dense-f32/call | 1.13.3 | 10 / 10 | 45139.6 | [43786.9, 46492.3] | 7096 / 7096 | 4.79371e-07 | ok=10 |
| cd/lasso-C/cd/dense-f64/call | 1.13.3 | 10 / 10 | 89799.1 | [86252.2, 93346] | 11256 / 11256 | 7.24643e-12 | ok=10 |
| cd/lasso-C/cd/sparse-f32/call | 1.13.3 | 10 / 10 | 44587.8 | [43587.2, 45588.4] | 7096 / 7096 | 4.79371e-07 | ok=10 |
| cd/lasso-C/cd/sparse-f64/call | 1.13.3 | 10 / 10 | 89154.5 | [85344.3, 92964.7] | 11256 / 11256 | 7.24643e-12 | ok=10 |
| cd/lasso-D/cd/dense-f32/call | 1.13.3 | 10 / 10 | 75018.4 | [73654.4, 76382.4] | 16192 / 16192 | 4.3274e-07 | ok=10 |
| cd/lasso-D/cd/dense-f64/call | 1.13.3 | 10 / 10 | 111705 | [110181, 113229] | 21632 / 21632 | 4.40968e-13 | ok=10 |
| cd/lasso-D/cd/sparse-f32/call | 1.13.3 | 10 / 10 | 74195.6 | [72580.7, 75810.5] | 16192 / 16192 | 4.3274e-07 | ok=10 |
| cd/lasso-D/cd/sparse-f64/call | 1.13.3 | 10 / 10 | 110540 | [108093, 112986] | 21632 / 21632 | 4.40968e-13 | ok=10 |
| cd/lasso-dense/cd/R/call | 1.13.3 | 10 / 10 | 47130 | [46554, 47706] | 6752 / 6752 | 5.75233e-08 | ok=10 |
| cd/lasso/cd/dense-f32/call | 1.13.3 | 10 / 10 | 5242.6 | [5041.96, 5443.24] | 2096 / 2096 | 3.57172e-07 | ok=10 |
| cd/lasso/cd/dense-f64/call | 1.13.3 | 10 / 10 | 7735.3 | [7382.16, 8088.44] | 2832 / 2832 | 1.3083e-12 | ok=10 |
| cd/lasso/cd/sparse-f32/call | 1.13.3 | 10 / 10 | 5301.2 | [5053.68, 5548.72] | 2096 / 2096 | 3.57172e-07 | ok=10 |
| cd/lasso/cd/sparse-f64/call | 1.13.3 | 10 / 10 | 7919.3 | [7629.43, 8209.17] | 2832 / 2832 | 1.3083e-12 | ok=10 |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.00799e+06 | [840567, 1.17542e+06] | 16160 / 16160 | 5.34974e-10 | ok=10 |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.13.3 | 10 / 10 | 893111 | [657102, 1.12912e+06] | 16160 / 16160 | 7.59748e-11 | ok=10 |
| gradient/lasso-B/apg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000258525 | ok=1, target_missed=9 |
| gradient/lasso-B/apg/dense-f64/call | 1.13.3 | 10 / 10 | 1.01054e+06 | [851727, 1.16935e+06] | 16160 / 16160 | 4.81707e-09 | ok=10 |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 0.000254159 | ok=2, target_missed=8 |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.13.3 | 8 / 10 | nan | [nan, nan] | nan / nan | 1.35043e-08 | ok=8, target_missed=2 |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.51926e+06 | [1.0118e+06, 2.02671e+06] | 11696 / 11696 | 1.81193e-10 | ok=10 |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.13.3 | 10 / 10 | 1.22538e+06 | [624972, 1.82579e+06] | 11696 / 11696 | 7.27499e-11 | ok=10 |
| gradient/lasso-B/pg/dense-f32/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 0.000275767 | ok=2, target_missed=8 |
| gradient/lasso-B/pg/dense-f64/call | 1.13.3 | 7 / 10 | nan | [nan, nan] | nan / nan | 2.15671e-08 | ok=7, target_missed=3 |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000435403 | ok=1, target_missed=9 |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.13.3 | 9 / 10 | nan | [nan, nan] | nan / nan | 2.36082e-08 | ok=9, target_missed=1 |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.40633e+06 | [1.27866e+06, 1.534e+06] | 32032 / 32032 | 1.66286e-10 | ok=10 |
| gradient/lasso-C/apg/dense-f32/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 0.000289786 | ok=2, target_missed=8 |
| gradient/lasso-C/apg/dense-f64/call | 1.13.3 | 10 / 10 | 1.4508e+06 | [1.27468e+06, 1.62693e+06] | 32032 / 32032 | 1.8743e-09 | ok=10 |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.22136e+06 | [993239, 1.44948e+06] | 18752 / 18752 | 1.29959e-10 | ok=10 |
| gradient/lasso-C/pg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000413605 | ok=1, target_missed=9 |
| gradient/lasso-C/pg/dense-f64/call | 1.13.3 | 9 / 10 | nan | [nan, nan] | nan / nan | 1.00388e-08 | ok=9, target_missed=1 |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.61694e+06 | [1.50018e+06, 1.7337e+06] | 31384 / 31384 | 1.36519e-10 | ok=10 |
| gradient/lasso-D/apg/dense-f32/call | 1.13.3 | 3 / 10 | nan | [nan, nan] | nan / nan | 4.15191e-05 | ok=3, target_missed=7 |
| gradient/lasso-D/apg/dense-f64/call | 1.13.3 | 10 / 10 | 1.63216e+06 | [1.49512e+06, 1.7692e+06] | 31384 / 31384 | 3.71883e-09 | ok=10 |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.42892e+06 | [1.31724e+06, 1.54061e+06] | 28008 / 28008 | 1.41756e-10 | ok=10 |
| gradient/lasso-D/pg/dense-f32/call | 1.13.3 | 5 / 10 | nan | [nan, nan] | nan / nan | 6.82582e-05 | ok=5, target_missed=5 |
| gradient/lasso-D/pg/dense-f64/call | 1.13.3 | 10 / 10 | 1.37923e+06 | [1.26196e+06, 1.4965e+06] | 28008 / 28008 | 4.01926e-09 | ok=10 |
| gradient/lasso/apg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 51167 | [48696.7, 53637.3] | 6256 / 6256 | 1.0779e-10 | ok=10 |
| gradient/lasso/apg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 9.67056e-05 | ok=1, target_missed=9 |
| gradient/lasso/apg/dense-f64/call | 1.13.3 | 10 / 10 | 52873.2 | [49824.8, 55921.6] | 6256 / 6256 | 2.05048e-09 | ok=10 |
| gradient/lasso/pg/R/call | 1.13.3 | 10 / 10 | 48596 | [48256.9, 48935.1] | 4688 / 4688 | 2.9973e-05 | ok=10 |
| gradient/lasso/pg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 32676.8 | [30452.6, 34901] | 4064 / 4064 | 1.28759e-10 | ok=10 |
| gradient/lasso/pg/dense-f32/call | 1.13.3 | 4 / 10 | nan | [nan, nan] | nan / nan | 0.00010668 | ok=4, target_missed=6 |
| gradient/lasso/pg/dense-f64/call | 1.13.3 | 10 / 10 | 31112.9 | [28354.6, 33871.2] | 4064 / 4064 | 2.60529e-09 | ok=10 |
