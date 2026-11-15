# ProximalSolvers benchmark summary

Record integrity: valid. Repetitions per Julia version: 10.

Time is the arithmetic mean of the per-repetition medians. Each median uses only ok samples. The Student-t interval uses independent repetitions, never individual samples. One repetition has a NaN interval. The fastest run is never selected.

Every repetition contributes to the summary. If any repetition has no ok samples, the aggregate time and interval are NaN. Status counts include all repetitions, including those with numerical failures. Bytes are aggregated from the same ok samples; mean bytes is the mean of repetition medians. Worst accuracy is the maximum reported worst_value, ignoring NaN values; status counts retain uncertifiable results.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory.

| Case | Julia | Runs with timing / total | Mean median (ns) | 95% interval (ns) | Mean / median bytes | Worst accuracy | Status counts |
|---|---|---:|---:|---:|---:|---:|---|
| gradient/lasso-B/apg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.01465e+06 | [760555, 1.26874e+06] | 15904 / 15904 | 3.38453e-10 | ok=10 |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.10.13 | 10 / 10 | 842932 | [474538, 1.21132e+06] | 15904 / 15904 | 5.60574e-11 | ok=10 |
| gradient/lasso-B/apg/dense-f32/call | 1.10.13 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.0003147 | target_missed=10 |
| gradient/lasso-B/apg/dense-f64/call | 1.10.13 | 10 / 10 | 1.02401e+06 | [803717, 1.24431e+06] | 15904 / 15904 | 5.15948e-09 | ok=10 |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.10.13 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000332694 | ok=1, target_missed=9 |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.10.13 | 10 / 10 | 758489 | [521159, 995819] | 15904 / 15904 | 6.11044e-09 | ok=10 |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.42803e+06 | [730931, 2.12514e+06] | 11504 / 11504 | 1.81951e-10 | ok=10 |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.10.13 | 10 / 10 | 1.00918e+06 | [388401, 1.62995e+06] | 11504 / 11504 | 8.27036e-11 | ok=10 |
| gradient/lasso-B/pg/dense-f32/call | 1.10.13 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.000237667 | target_missed=10 |
| gradient/lasso-B/pg/dense-f64/call | 1.10.13 | 9 / 10 | nan | [nan, nan] | nan / nan | 2.74234e-08 | ok=9, target_missed=1 |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.10.13 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000644369 | ok=1, target_missed=9 |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.10.13 | 8 / 10 | nan | [nan, nan] | nan / nan | 1.08631e-08 | ok=8, target_missed=2 |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.33181e+06 | [1.22362e+06, 1.44e+06] | 32528 / 32528 | 1.4471e-10 | ok=10 |
| gradient/lasso-C/apg/dense-f32/call | 1.10.13 | 4 / 10 | nan | [nan, nan] | nan / nan | 6.82462e-05 | ok=4, target_missed=6 |
| gradient/lasso-C/apg/dense-f64/call | 1.10.13 | 10 / 10 | 1.35981e+06 | [1.22942e+06, 1.49021e+06] | 32528 / 32528 | 7.08895e-09 | ok=10 |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.12837e+06 | [936808, 1.31992e+06] | 19136 / 19136 | 2.40199e-10 | ok=10 |
| gradient/lasso-C/pg/dense-f32/call | 1.10.13 | 4 / 10 | nan | [nan, nan] | nan / nan | 0.000162929 | ok=4, target_missed=6 |
| gradient/lasso-C/pg/dense-f64/call | 1.10.13 | 10 / 10 | 1.04595e+06 | [918450, 1.17345e+06] | 19136 / 19136 | 3.48906e-09 | ok=10 |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.71515e+06 | [1.62371e+06, 1.8066e+06] | 32144 / 32144 | 1.67664e-10 | ok=10 |
| gradient/lasso-D/apg/dense-f32/call | 1.10.13 | 3 / 10 | nan | [nan, nan] | nan / nan | 3.43689e-05 | ok=3, target_missed=7 |
| gradient/lasso-D/apg/dense-f64/call | 1.10.13 | 10 / 10 | 1.71912e+06 | [1.56398e+06, 1.87426e+06] | 32144 / 32144 | 5.17253e-09 | ok=10 |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 1.34049e+06 | [1.25278e+06, 1.42821e+06] | 28544 / 28544 | 1.65263e-10 | ok=10 |
| gradient/lasso-D/pg/dense-f32/call | 1.10.13 | 7 / 10 | nan | [nan, nan] | nan / nan | 8.38089e-05 | ok=7, target_missed=3 |
| gradient/lasso-D/pg/dense-f64/call | 1.10.13 | 9 / 10 | nan | [nan, nan] | nan / nan | 1.16163e-08 | ok=9, target_missed=1 |
| gradient/lasso/apg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 54490.2 | [52679.4, 56301] | 6240 / 6240 | 1.23409e-10 | ok=10 |
| gradient/lasso/apg/dense-f32/call | 1.10.13 | 2 / 10 | nan | [nan, nan] | nan / nan | 9.09694e-05 | ok=2, target_missed=8 |
| gradient/lasso/apg/dense-f64/call | 1.10.13 | 9 / 10 | nan | [nan, nan] | nan / nan | 1.24599e-08 | ok=9, target_missed=1 |
| gradient/lasso/pg/R/call | 1.10.13 | 10 / 10 | 54008.3 | [53659.5, 54357.1] | 4816 / 4816 | 2.88018e-05 | ok=10 |
| gradient/lasso/pg/acc-dense-f64/call | 1.10.13 | 10 / 10 | 37551.7 | [34207.2, 40896.2] | 4112 / 4112 | 1.13688e-10 | ok=10 |
| gradient/lasso/pg/dense-f32/call | 1.10.13 | 2 / 10 | nan | [nan, nan] | nan / nan | 9.23022e-05 | ok=2, target_missed=8 |
| gradient/lasso/pg/dense-f64/call | 1.10.13 | 10 / 10 | 35015.8 | [30869.8, 39161.8] | 4112 / 4112 | 5.49245e-09 | ok=10 |
