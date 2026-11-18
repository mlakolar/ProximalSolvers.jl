# ProximalSolvers benchmark summary

Record integrity: valid. Repetitions per Julia version: 10.

Time is the arithmetic mean of the per-repetition medians. Each median uses only ok samples. The Student-t interval uses independent repetitions, never individual samples. One repetition has a NaN interval. The fastest run is never selected.

Every repetition contributes to the summary. If any repetition has no ok samples, the aggregate time and interval are NaN. Status counts include all repetitions, including those with numerical failures. Bytes are aggregated from the same ok samples; mean bytes is the mean of repetition medians. Worst accuracy is the maximum reported worst_value, ignoring NaN values; status counts retain uncertifiable results.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory.

| Case | Julia | Runs with timing / total | Mean median (ns) | 95% interval (ns) | Mean / median bytes | Worst accuracy | Status counts |
|---|---|---:|---:|---:|---:|---:|---|
| cd/group-lasso/cd/block-f32/call | 1.10.13 | 10 / 10 | 48909.1 | [43831.5, 53986.7] | 17166.4 / 16728 | 1.08829e-06 | ok=10 |
| cd/group-lasso/cd/block-f64/call | 1.10.13 | 10 / 10 | 64603.6 | [58441.3, 70765.9] | 18110.4 / 17672 | 4.75226e-12 | ok=10 |
| cd/group-lasso/cd/warm-block-f32/call | 1.10.13 | 10 / 10 | 43249.3 | [38899.2, 47599.4] | 14974.4 / 15632 | 6.82772e-07 | ok=10 |
| cd/group-lasso/cd/warm-block-f64/call | 1.10.13 | 10 / 10 | 57051.4 | [51228.4, 62874.4] | 15918.4 / 16576 | 7.27282e-12 | ok=10 |
| cd/lasso-B/cd/dense-f32/call | 1.10.13 | 10 / 10 | 49013.5 | [42819.5, 55207.5] | 6064 / 6064 | 3.19554e-06 | ok=10 |
| cd/lasso-B/cd/dense-f64/call | 1.10.13 | 10 / 10 | 69737.8 | [54255.6, 85220] | 8288 / 8288 | 3.17081e-11 | ok=10 |
| cd/lasso-B/cd/sparse-f32/call | 1.10.13 | 10 / 10 | 48490.9 | [42038.3, 54943.5] | 6064 / 6064 | 3.19554e-06 | ok=10 |
| cd/lasso-B/cd/sparse-f64/call | 1.10.13 | 10 / 10 | 69806.1 | [53604.1, 86008.1] | 8288 / 8288 | 3.17081e-11 | ok=10 |
| cd/lasso-B/cd/warm-dense-f32/call | 1.10.13 | 10 / 10 | 38288.6 | [35463.7, 41113.5] | 6064 / 6064 | 1.37177e-06 | ok=10 |
| cd/lasso-B/cd/warm-dense-f64/call | 1.10.13 | 10 / 10 | 55487.5 | [46646, 64329] | 8288 / 8288 | 3.3179e-11 | ok=10 |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.10.13 | 10 / 10 | 39175.6 | [36266.3, 42084.9] | 6064 / 6064 | 1.37177e-06 | ok=10 |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.10.13 | 10 / 10 | 55715 | [47207.8, 64222.2] | 8288 / 8288 | 3.3179e-11 | ok=10 |
| cd/lasso-C/cd/dense-f32/call | 1.10.13 | 10 / 10 | 78980.6 | [78189.5, 79771.7] | 7376 / 7376 | 5.59476e-07 | ok=10 |
| cd/lasso-C/cd/dense-f64/call | 1.10.13 | 10 / 10 | 108646 | [105934, 111359] | 11696 / 11696 | 6.05071e-12 | ok=10 |
| cd/lasso-C/cd/sparse-f32/call | 1.10.13 | 10 / 10 | 78659.7 | [77728, 79591.4] | 7376 / 7376 | 5.59476e-07 | ok=10 |
| cd/lasso-C/cd/sparse-f64/call | 1.10.13 | 10 / 10 | 108291 | [106050, 110531] | 11696 / 11696 | 6.05071e-12 | ok=10 |
| cd/lasso-D/cd/dense-f32/call | 1.10.13 | 10 / 10 | 110971 | [108088, 113855] | 16576 / 16576 | 4.48279e-07 | ok=10 |
| cd/lasso-D/cd/dense-f64/call | 1.10.13 | 10 / 10 | 134301 | [131735, 136866] | 22160 / 22160 | 7.20869e-13 | ok=10 |
| cd/lasso-D/cd/sparse-f32/call | 1.10.13 | 10 / 10 | 111020 | [107466, 114575] | 16576 / 16576 | 4.48279e-07 | ok=10 |
| cd/lasso-D/cd/sparse-f64/call | 1.10.13 | 10 / 10 | 131114 | [129457, 132771] | 22160 / 22160 | 7.20869e-13 | ok=10 |
| cd/lasso-dense/cd/R/call | 1.10.13 | 10 / 10 | 54024.1 | [53748.1, 54300.1] | 6864 / 6864 | 5.75233e-08 | ok=10 |
| cd/lasso-weighted/cd/dense-f32/call | 1.10.13 | 10 / 10 | 8170.4 | [7622.33, 8718.47] | 2352 / 2352 | 3.79078e-07 | ok=10 |
| cd/lasso-weighted/cd/dense-f64/call | 1.10.13 | 10 / 10 | 11189.1 | [10069.4, 12308.8] | 3072 / 3072 | 1.05681e-12 | ok=10 |
| cd/lasso-weighted/cd/sparse-f32/call | 1.10.13 | 10 / 10 | 8123.4 | [7375.62, 8871.18] | 2352 / 2352 | 3.79078e-07 | ok=10 |
| cd/lasso-weighted/cd/sparse-f64/call | 1.10.13 | 10 / 10 | 11117.6 | [10138, 12097.2] | 3072 / 3072 | 1.05681e-12 | ok=10 |
| cd/lasso/cd/dense-f32/call | 1.10.13 | 10 / 10 | 7851.5 | [7368.71, 8334.29] | 2336 / 2336 | 5.95994e-07 | ok=10 |
| cd/lasso/cd/dense-f64/call | 1.10.13 | 10 / 10 | 10249.1 | [9782.55, 10715.6] | 3056 / 3056 | 2.74712e-12 | ok=10 |
| cd/lasso/cd/sparse-f32/call | 1.10.13 | 10 / 10 | 7879.7 | [7463.35, 8296.05] | 2336 / 2336 | 5.95994e-07 | ok=10 |
| cd/lasso/cd/sparse-f64/call | 1.10.13 | 10 / 10 | 10402.4 | [9893.12, 10911.7] | 3056 / 3056 | 2.74712e-12 | ok=10 |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.00205e+06 | [758401, 1.24569e+06] | 15904 / 15904 | 3.38453e-10 | ok=10 |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.10.13 | 10 / 10 | 846954 | [478808, 1.2151e+06] | 15904 / 15904 | 5.60574e-11 | ok=10 |
| gradient/lasso-B/apg/dense-f32/call | 1.10.13 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.0003147 | target_missed=10 |
| gradient/lasso-B/apg/dense-f64/call | 1.10.13 | 10 / 10 | 1.02032e+06 | [798448, 1.2422e+06] | 15904 / 15904 | 5.15948e-09 | ok=10 |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.10.13 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000332694 | ok=1, target_missed=9 |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.10.13 | 10 / 10 | 751372 | [520363, 982381] | 15904 / 15904 | 6.11044e-09 | ok=10 |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.45056e+06 | [748011, 2.1531e+06] | 11504 / 11504 | 1.81951e-10 | ok=10 |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.10.13 | 10 / 10 | 1.0356e+06 | [381112, 1.69008e+06] | 11504 / 11504 | 8.27036e-11 | ok=10 |
| gradient/lasso-B/pg/dense-f32/call | 1.10.13 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.000237667 | target_missed=10 |
| gradient/lasso-B/pg/dense-f64/call | 1.10.13 | 9 / 10 | nan | [nan, nan] | nan / nan | 2.74234e-08 | ok=9, target_missed=1 |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.10.13 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000644369 | ok=1, target_missed=9 |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.10.13 | 8 / 10 | nan | [nan, nan] | nan / nan | 1.08631e-08 | ok=8, target_missed=2 |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.33351e+06 | [1.2249e+06, 1.44212e+06] | 32528 / 32528 | 1.4471e-10 | ok=10 |
| gradient/lasso-C/apg/dense-f32/call | 1.10.13 | 4 / 10 | nan | [nan, nan] | nan / nan | 6.82462e-05 | ok=4, target_missed=6 |
| gradient/lasso-C/apg/dense-f64/call | 1.10.13 | 10 / 10 | 1.35912e+06 | [1.23109e+06, 1.48714e+06] | 32528 / 32528 | 7.08895e-09 | ok=10 |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.15609e+06 | [969390, 1.34278e+06] | 19136 / 19136 | 2.40199e-10 | ok=10 |
| gradient/lasso-C/pg/dense-f32/call | 1.10.13 | 3 / 10 | nan | [nan, nan] | nan / nan | 0.000162929 | ok=3, target_missed=7 |
| gradient/lasso-C/pg/dense-f64/call | 1.10.13 | 10 / 10 | 1.05013e+06 | [924947, 1.17531e+06] | 19136 / 19136 | 3.48906e-09 | ok=10 |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.71705e+06 | [1.62315e+06, 1.81095e+06] | 32144 / 32144 | 1.67664e-10 | ok=10 |
| gradient/lasso-D/apg/dense-f32/call | 1.10.13 | 3 / 10 | nan | [nan, nan] | nan / nan | 3.43689e-05 | ok=3, target_missed=7 |
| gradient/lasso-D/apg/dense-f64/call | 1.10.13 | 10 / 10 | 1.72021e+06 | [1.56198e+06, 1.87844e+06] | 32144 / 32144 | 5.17253e-09 | ok=10 |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.36721e+06 | [1.2644e+06, 1.47002e+06] | 28544 / 28544 | 1.65263e-10 | ok=10 |
| gradient/lasso-D/pg/dense-f32/call | 1.10.13 | 5 / 10 | nan | [nan, nan] | nan / nan | 8.38089e-05 | ok=5, target_missed=5 |
| gradient/lasso-D/pg/dense-f64/call | 1.10.13 | 9 / 10 | nan | [nan, nan] | nan / nan | 1.16163e-08 | ok=9, target_missed=1 |
| gradient/lasso-weighted/apg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 58517.3 | [53964.5, 63070.1] | 6256 / 6256 | 4.16952e-11 | ok=10 |
| gradient/lasso-weighted/pg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 39809 | [34601.1, 45016.9] | 4128 / 4128 | 6.73921e-11 | ok=10 |
| gradient/lasso/apg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 55029.9 | [52983.6, 57076.2] | 6240 / 6240 | 1.23409e-10 | ok=10 |
| gradient/lasso/apg/dense-f32/call | 1.10.13 | 2 / 10 | nan | [nan, nan] | nan / nan | 9.09694e-05 | ok=2, target_missed=8 |
| gradient/lasso/apg/dense-f64/call | 1.10.13 | 9 / 10 | nan | [nan, nan] | nan / nan | 1.24599e-08 | ok=9, target_missed=1 |
| gradient/lasso/pg/R/call | 1.10.13 | 10 / 10 | 54205.8 | [53755.1, 54656.5] | 4816 / 4816 | 2.88018e-05 | ok=10 |
| gradient/lasso/pg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 37521.3 | [34584.7, 40457.9] | 4112 / 4112 | 1.13688e-10 | ok=10 |
| gradient/lasso/pg/dense-f32/call | 1.10.13 | 2 / 10 | nan | [nan, nan] | nan / nan | 9.23022e-05 | ok=2, target_missed=8 |
| gradient/lasso/pg/dense-f64/call | 1.10.13 | 10 / 10 | 35262 | [30915.9, 39608.1] | 4112 / 4112 | 5.49245e-09 | ok=10 |
| cd/group-lasso/cd/block-f32/call | 1.13.3 | 10 / 10 | 42745.5 | [39473.8, 46017.2] | 17174.4 / 16968 | 5.83059e-07 | ok=10 |
| cd/group-lasso/cd/block-f64/call | 1.13.3 | 10 / 10 | 61453.1 | [56144.1, 66762.1] | 18006.4 / 17800 | 6.71717e-12 | ok=10 |
| cd/group-lasso/cd/warm-block-f32/call | 1.13.3 | 10 / 10 | 36395.1 | [33802.5, 38987.7] | 14904 / 14904 | 9.51463e-07 | ok=10 |
| cd/group-lasso/cd/warm-block-f64/call | 1.13.3 | 10 / 10 | 54549.9 | [50903, 58196.8] | 15739.2 / 15736 | 5.78772e-12 | ok=10 |
| cd/lasso-B/cd/dense-f32/call | 1.13.3 | 10 / 10 | 35764.8 | [30526.8, 41002.8] | 5824 / 5824 | 2.90908e-06 | ok=10 |
| cd/lasso-B/cd/dense-f64/call | 1.13.3 | 10 / 10 | 62463.5 | [49753.4, 75173.6] | 8256 / 8256 | 1.06546e-11 | ok=10 |
| cd/lasso-B/cd/sparse-f32/call | 1.13.3 | 10 / 10 | 35376.4 | [30202.6, 40550.2] | 5824 / 5824 | 2.90908e-06 | ok=10 |
| cd/lasso-B/cd/sparse-f64/call | 1.13.3 | 10 / 10 | 62044.4 | [48567.1, 75521.7] | 8256 / 8256 | 1.06546e-11 | ok=10 |
| cd/lasso-B/cd/warm-dense-f32/call | 1.13.3 | 10 / 10 | 25542.6 | [23053.8, 28031.4] | 5824 / 5824 | 2.89053e-06 | ok=10 |
| cd/lasso-B/cd/warm-dense-f64/call | 1.13.3 | 10 / 10 | 47513.1 | [39547.2, 55479] | 8256 / 8256 | 2.62505e-11 | ok=10 |
| cd/lasso-B/cd/warm-sparse-f32/call | 1.13.3 | 10 / 10 | 25168.3 | [22601.3, 27735.3] | 5824 / 5824 | 2.89053e-06 | ok=10 |
| cd/lasso-B/cd/warm-sparse-f64/call | 1.13.3 | 10 / 10 | 47697 | [39264.7, 56129.3] | 8256 / 8256 | 2.62505e-11 | ok=10 |
| cd/lasso-C/cd/dense-f32/call | 1.13.3 | 10 / 10 | 44828.5 | [43872.8, 45784.2] | 7096 / 7096 | 4.79371e-07 | ok=10 |
| cd/lasso-C/cd/dense-f64/call | 1.13.3 | 10 / 10 | 89559.6 | [85899.4, 93219.8] | 11256 / 11256 | 7.24643e-12 | ok=10 |
| cd/lasso-C/cd/sparse-f32/call | 1.13.3 | 10 / 10 | 44545.9 | [43691.9, 45399.9] | 7096 / 7096 | 4.79371e-07 | ok=10 |
| cd/lasso-C/cd/sparse-f64/call | 1.13.3 | 10 / 10 | 89145.4 | [85583.3, 92707.5] | 11256 / 11256 | 7.24643e-12 | ok=10 |
| cd/lasso-D/cd/dense-f32/call | 1.13.3 | 10 / 10 | 73793.6 | [72201.3, 75385.9] | 16192 / 16192 | 4.3274e-07 | ok=10 |
| cd/lasso-D/cd/dense-f64/call | 1.13.3 | 10 / 10 | 110170 | [108239, 112101] | 21632 / 21632 | 4.40968e-13 | ok=10 |
| cd/lasso-D/cd/sparse-f32/call | 1.13.3 | 10 / 10 | 73457.1 | [72021.6, 74892.6] | 16192 / 16192 | 4.3274e-07 | ok=10 |
| cd/lasso-D/cd/sparse-f64/call | 1.13.3 | 10 / 10 | 110356 | [108081, 112631] | 21632 / 21632 | 4.40968e-13 | ok=10 |
| cd/lasso-dense/cd/R/call | 1.13.3 | 10 / 10 | 47322.3 | [46653.1, 47991.5] | 6752 / 6752 | 5.75233e-08 | ok=10 |
| cd/lasso-weighted/cd/dense-f32/call | 1.13.3 | 10 / 10 | 5885.8 | [5397.52, 6374.08] | 2112 / 2112 | 4.32305e-07 | ok=10 |
| cd/lasso-weighted/cd/dense-f64/call | 1.13.3 | 10 / 10 | 8882.8 | [7827.96, 9937.64] | 2848 / 2848 | 1.57511e-12 | ok=10 |
| cd/lasso-weighted/cd/sparse-f32/call | 1.13.3 | 10 / 10 | 5999.6 | [5409.61, 6589.59] | 2112 / 2112 | 4.32305e-07 | ok=10 |
| cd/lasso-weighted/cd/sparse-f64/call | 1.13.3 | 10 / 10 | 8924.4 | [7837.1, 10011.7] | 2848 / 2848 | 1.57511e-12 | ok=10 |
| cd/lasso/cd/dense-f32/call | 1.13.3 | 10 / 10 | 5304.3 | [5003.81, 5604.79] | 2096 / 2096 | 3.57172e-07 | ok=10 |
| cd/lasso/cd/dense-f64/call | 1.13.3 | 10 / 10 | 7695.1 | [7289.54, 8100.66] | 2832 / 2832 | 1.3083e-12 | ok=10 |
| cd/lasso/cd/sparse-f32/call | 1.13.3 | 10 / 10 | 5165 | [4906.01, 5423.99] | 2096 / 2096 | 3.57172e-07 | ok=10 |
| cd/lasso/cd/sparse-f64/call | 1.13.3 | 10 / 10 | 7747.2 | [7372.47, 8121.93] | 2832 / 2832 | 1.3083e-12 | ok=10 |
| gradient/lasso-B/apg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 991822 | [820978, 1.16266e+06] | 16160 / 16160 | 5.34974e-10 | ok=10 |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.13.3 | 10 / 10 | 888050 | [650585, 1.12552e+06] | 16160 / 16160 | 7.59748e-11 | ok=10 |
| gradient/lasso-B/apg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000258525 | ok=1, target_missed=9 |
| gradient/lasso-B/apg/dense-f64/call | 1.13.3 | 10 / 10 | 1.06731e+06 | [906940, 1.22767e+06] | 16160 / 16160 | 4.81707e-09 | ok=10 |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 0.000254159 | ok=2, target_missed=8 |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.13.3 | 8 / 10 | nan | [nan, nan] | nan / nan | 1.35043e-08 | ok=8, target_missed=2 |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.62227e+06 | [1.07151e+06, 2.17303e+06] | 11696 / 11696 | 1.81193e-10 | ok=10 |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.13.3 | 10 / 10 | 1.24873e+06 | [639446, 1.85802e+06] | 11696 / 11696 | 7.27499e-11 | ok=10 |
| gradient/lasso-B/pg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000275767 | ok=1, target_missed=9 |
| gradient/lasso-B/pg/dense-f64/call | 1.13.3 | 7 / 10 | nan | [nan, nan] | nan / nan | 2.15671e-08 | ok=7, target_missed=3 |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000435403 | ok=1, target_missed=9 |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.13.3 | 9 / 10 | nan | [nan, nan] | nan / nan | 2.36082e-08 | ok=9, target_missed=1 |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.40113e+06 | [1.27462e+06, 1.52763e+06] | 32032 / 32032 | 1.66286e-10 | ok=10 |
| gradient/lasso-C/apg/dense-f32/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 0.000289786 | ok=2, target_missed=8 |
| gradient/lasso-C/apg/dense-f64/call | 1.13.3 | 10 / 10 | 1.44925e+06 | [1.27359e+06, 1.62492e+06] | 32032 / 32032 | 1.8743e-09 | ok=10 |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.22106e+06 | [992958, 1.44917e+06] | 18752 / 18752 | 1.29959e-10 | ok=10 |
| gradient/lasso-C/pg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000224425 | ok=1, target_missed=9 |
| gradient/lasso-C/pg/dense-f64/call | 1.13.3 | 9 / 10 | nan | [nan, nan] | nan / nan | 1.00388e-08 | ok=9, target_missed=1 |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.61395e+06 | [1.49835e+06, 1.72955e+06] | 31384 / 31384 | 1.36519e-10 | ok=10 |
| gradient/lasso-D/apg/dense-f32/call | 1.13.3 | 3 / 10 | nan | [nan, nan] | nan / nan | 4.15191e-05 | ok=3, target_missed=7 |
| gradient/lasso-D/apg/dense-f64/call | 1.13.3 | 10 / 10 | 1.63054e+06 | [1.49306e+06, 1.76802e+06] | 31384 / 31384 | 3.71883e-09 | ok=10 |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.40137e+06 | [1.29268e+06, 1.51005e+06] | 28008 / 28008 | 1.41756e-10 | ok=10 |
| gradient/lasso-D/pg/dense-f32/call | 1.13.3 | 6 / 10 | nan | [nan, nan] | nan / nan | 2.99049e-05 | ok=6, target_missed=4 |
| gradient/lasso-D/pg/dense-f64/call | 1.13.3 | 10 / 10 | 1.35674e+06 | [1.23805e+06, 1.47543e+06] | 28008 / 28008 | 4.01926e-09 | ok=10 |
| gradient/lasso-weighted/apg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 50766.3 | [48005.8, 53526.8] | 6272 / 6272 | 1.9928e-10 | ok=10 |
| gradient/lasso-weighted/pg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 33940.4 | [28908.7, 38972.1] | 4080 / 4080 | 2.79256e-10 | ok=10 |
| gradient/lasso/apg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 50227.1 | [48261.3, 52192.9] | 6256 / 6256 | 1.0779e-10 | ok=10 |
| gradient/lasso/apg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 9.67056e-05 | ok=1, target_missed=9 |
| gradient/lasso/apg/dense-f64/call | 1.13.3 | 10 / 10 | 52760 | [49856.9, 55663.1] | 6256 / 6256 | 2.05048e-09 | ok=10 |
| gradient/lasso/pg/R/call | 1.13.3 | 10 / 10 | 48764.6 | [48395.9, 49133.3] | 4688 / 4688 | 2.9973e-05 | ok=10 |
| gradient/lasso/pg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 32579.1 | [30425.9, 34732.3] | 4064 / 4064 | 1.28759e-10 | ok=10 |
| gradient/lasso/pg/dense-f32/call | 1.13.3 | 4 / 10 | nan | [nan, nan] | nan / nan | 0.00010668 | ok=4, target_missed=6 |
| gradient/lasso/pg/dense-f64/call | 1.13.3 | 10 / 10 | 31028.5 | [28280, 33777] | 4064 / 4064 | 2.60529e-09 | ok=10 |
