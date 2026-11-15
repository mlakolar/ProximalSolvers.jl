# ProximalSolvers benchmark summary

Record integrity: valid. Repetitions per Julia version: 10.

Time is the arithmetic mean of the per-repetition medians. Each median uses only ok samples. The Student-t interval uses independent repetitions, never individual samples. One repetition has a NaN interval. The fastest run is never selected.

Every repetition contributes to the summary. If any repetition has no ok samples, the aggregate time and interval are NaN. Status counts include all repetitions, including those with numerical failures. Bytes are aggregated from the same ok samples; mean bytes is the mean of repetition medians. Worst accuracy is the maximum reported worst_value, ignoring NaN values; status counts retain uncertifiable results.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory.

| Case | Julia | Runs with timing / total | Mean median (ns) | 95% interval (ns) | Mean / median bytes | Worst accuracy | Status counts |
|---|---|---:|---:|---:|---:|---:|---|
| gradient/lasso-B/apg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000258525 | ok=1, target_missed=9 |
| gradient/lasso-B/apg/dense-f64/call | 1.13.3 | 10 / 10 | 1.00505e+06 | [869647, 1.14046e+06] | 16160 / 16160 | 4.81707e-09 | ok=10 |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 0.000254159 | ok=2, target_missed=8 |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.13.3 | 8 / 10 | nan | [nan, nan] | nan / nan | 1.35043e-08 | ok=8, target_missed=2 |
| gradient/lasso-B/pg/dense-f32/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 0.000275767 | ok=2, target_missed=8 |
| gradient/lasso-B/pg/dense-f64/call | 1.13.3 | 7 / 10 | nan | [nan, nan] | nan / nan | 2.15671e-08 | ok=7, target_missed=3 |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000435403 | ok=1, target_missed=9 |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.13.3 | 9 / 10 | nan | [nan, nan] | nan / nan | 2.36082e-08 | ok=9, target_missed=1 |
| gradient/lasso-C/apg/dense-f32/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 0.000289786 | ok=2, target_missed=8 |
| gradient/lasso-C/apg/dense-f64/call | 1.13.3 | 10 / 10 | 1.44743e+06 | [1.27349e+06, 1.62137e+06] | 32032 / 32032 | 1.8743e-09 | ok=10 |
| gradient/lasso-C/pg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000413605 | ok=1, target_missed=9 |
| gradient/lasso-C/pg/dense-f64/call | 1.13.3 | 9 / 10 | nan | [nan, nan] | nan / nan | 1.00388e-08 | ok=9, target_missed=1 |
| gradient/lasso-D/apg/dense-f32/call | 1.13.3 | 3 / 10 | nan | [nan, nan] | nan / nan | 4.15191e-05 | ok=3, target_missed=7 |
| gradient/lasso-D/apg/dense-f64/call | 1.13.3 | 10 / 10 | 1.62818e+06 | [1.49247e+06, 1.76389e+06] | 31384 / 31384 | 3.71883e-09 | ok=10 |
| gradient/lasso-D/pg/dense-f32/call | 1.13.3 | 5 / 10 | nan | [nan, nan] | nan / nan | 6.82582e-05 | ok=5, target_missed=5 |
| gradient/lasso-D/pg/dense-f64/call | 1.13.3 | 10 / 10 | 1.37559e+06 | [1.26175e+06, 1.48944e+06] | 28008 / 28008 | 4.01926e-09 | ok=10 |
| gradient/lasso/apg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 9.67056e-05 | ok=1, target_missed=9 |
| gradient/lasso/apg/dense-f64/call | 1.13.3 | 10 / 10 | 51880 | [49048, 54712] | 6256 / 6256 | 2.05048e-09 | ok=10 |
| gradient/lasso/pg/R/call | 1.13.3 | 10 / 10 | 48515.2 | [48088.7, 48941.7] | 4688 / 4688 | 2.9973e-05 | ok=10 |
| gradient/lasso/pg/dense-f32/call | 1.13.3 | 4 / 10 | nan | [nan, nan] | nan / nan | 0.00010668 | ok=4, target_missed=6 |
| gradient/lasso/pg/dense-f64/call | 1.13.3 | 10 / 10 | 30641.1 | [28087.9, 33194.3] | 4064 / 4064 | 2.60529e-09 | ok=10 |
