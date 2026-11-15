# ProximalSolvers benchmark summary

Record integrity: valid. Repetitions per Julia version: 10.

Time is the arithmetic mean of the per-repetition medians. Each median uses only ok samples. The Student-t interval uses independent repetitions, never individual samples. One repetition has a NaN interval. The fastest run is never selected.

Every repetition contributes to the summary. If any repetition has no ok samples, the aggregate time and interval are NaN. Status counts include all repetitions, including those with numerical failures. Bytes are aggregated from the same ok samples; mean bytes is the mean of repetition medians. Worst accuracy is the maximum reported worst_value, ignoring NaN values; status counts retain uncertifiable results.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory.

| Case | Julia | Runs with timing / total | Mean median (ns) | 95% interval (ns) | Mean / median bytes | Worst accuracy | Status counts |
|---|---|---:|---:|---:|---:|---:|---|
| gradient/lasso-B/apg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 997328 | [808858, 1.1858e+06] | 16160 / 16160 | 5.34974e-10 | ok=10 |
| gradient/lasso-B/apg/acc-warm-dense-f64/call | 1.13.3 | 10 / 10 | 859635 | [638872, 1.0804e+06] | 16160 / 16160 | 7.59748e-11 | ok=10 |
| gradient/lasso-B/apg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000258525 | ok=1, target_missed=9 |
| gradient/lasso-B/apg/dense-f64/call | 1.13.3 | 10 / 10 | 1.00699e+06 | [856586, 1.1574e+06] | 16160 / 16160 | 4.81707e-09 | ok=10 |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 0.000254159 | ok=2, target_missed=8 |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.13.3 | 8 / 10 | nan | [nan, nan] | nan / nan | 1.35043e-08 | ok=8, target_missed=2 |
| gradient/lasso-B/pg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.55758e+06 | [1.03985e+06, 2.0753e+06] | 11696 / 11696 | 1.81193e-10 | ok=10 |
| gradient/lasso-B/pg/acc-warm-dense-f64/call | 1.13.3 | 10 / 10 | 1.2067e+06 | [622184, 1.79122e+06] | 11696 / 11696 | 7.27499e-11 | ok=10 |
| gradient/lasso-B/pg/dense-f32/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 0.000275767 | ok=2, target_missed=8 |
| gradient/lasso-B/pg/dense-f64/call | 1.13.3 | 7 / 10 | nan | [nan, nan] | nan / nan | 2.15671e-08 | ok=7, target_missed=3 |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000435403 | ok=1, target_missed=9 |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.13.3 | 9 / 10 | nan | [nan, nan] | nan / nan | 2.36082e-08 | ok=9, target_missed=1 |
| gradient/lasso-C/apg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.40731e+06 | [1.28187e+06, 1.53274e+06] | 32032 / 32032 | 1.66286e-10 | ok=10 |
| gradient/lasso-C/apg/dense-f32/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 0.000289786 | ok=2, target_missed=8 |
| gradient/lasso-C/apg/dense-f64/call | 1.13.3 | 10 / 10 | 1.45235e+06 | [1.28017e+06, 1.62453e+06] | 32032 / 32032 | 1.8743e-09 | ok=10 |
| gradient/lasso-C/pg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.21954e+06 | [990982, 1.4481e+06] | 18752 / 18752 | 1.29959e-10 | ok=10 |
| gradient/lasso-C/pg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000413605 | ok=1, target_missed=9 |
| gradient/lasso-C/pg/dense-f64/call | 1.13.3 | 9 / 10 | nan | [nan, nan] | nan / nan | 1.00388e-08 | ok=9, target_missed=1 |
| gradient/lasso-D/apg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.61894e+06 | [1.50201e+06, 1.73587e+06] | 31384 / 31384 | 1.36519e-10 | ok=10 |
| gradient/lasso-D/apg/dense-f32/call | 1.13.3 | 3 / 10 | nan | [nan, nan] | nan / nan | 4.15191e-05 | ok=3, target_missed=7 |
| gradient/lasso-D/apg/dense-f64/call | 1.13.3 | 10 / 10 | 1.63432e+06 | [1.496e+06, 1.77264e+06] | 31384 / 31384 | 3.71883e-09 | ok=10 |
| gradient/lasso-D/pg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 1.43014e+06 | [1.31888e+06, 1.5414e+06] | 28008 / 28008 | 1.41756e-10 | ok=10 |
| gradient/lasso-D/pg/dense-f32/call | 1.13.3 | 5 / 10 | nan | [nan, nan] | nan / nan | 6.82582e-05 | ok=5, target_missed=5 |
| gradient/lasso-D/pg/dense-f64/call | 1.13.3 | 10 / 10 | 1.37929e+06 | [1.26516e+06, 1.49342e+06] | 28008 / 28008 | 4.01926e-09 | ok=10 |
| gradient/lasso/apg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 50035.1 | [48257.5, 51812.7] | 6256 / 6256 | 1.0779e-10 | ok=10 |
| gradient/lasso/apg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 9.67056e-05 | ok=1, target_missed=9 |
| gradient/lasso/apg/dense-f64/call | 1.13.3 | 10 / 10 | 51947.9 | [49062.7, 54833.1] | 6256 / 6256 | 2.05048e-09 | ok=10 |
| gradient/lasso/pg/R/call | 1.13.3 | 10 / 10 | 48518.1 | [48138, 48898.2] | 4688 / 4688 | 2.9973e-05 | ok=10 |
| gradient/lasso/pg/acc-dense-f64/call | 1.13.3 | 10 / 10 | 32207 | [30286.2, 34127.8] | 4064 / 4064 | 1.28759e-10 | ok=10 |
| gradient/lasso/pg/dense-f32/call | 1.13.3 | 4 / 10 | nan | [nan, nan] | nan / nan | 0.00010668 | ok=4, target_missed=6 |
| gradient/lasso/pg/dense-f64/call | 1.13.3 | 10 / 10 | 30805.2 | [28090.5, 33519.9] | 4064 / 4064 | 2.60529e-09 | ok=10 |
