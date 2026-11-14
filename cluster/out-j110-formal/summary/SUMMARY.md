# ProximalSolvers benchmark summary

Record integrity: valid. Repetitions per Julia version: 10.

Time is the arithmetic mean of the per-repetition medians. Each median uses only ok samples. The Student-t interval uses independent repetitions, never individual samples. One repetition has a NaN interval. The fastest run is never selected.

Every repetition contributes to the summary. If any repetition has no ok samples, the aggregate time and interval are NaN. Status counts include all repetitions, including those with numerical failures. Bytes are aggregated from the same ok samples; mean bytes is the mean of repetition medians. Worst accuracy is the maximum reported worst_value, ignoring NaN values; status counts retain uncertifiable results.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory.

| Case | Julia | Runs with timing / total | Mean median (ns) | 95% interval (ns) | Mean / median bytes | Worst accuracy | Status counts |
|---|---|---:|---:|---:|---:|---:|---|
| gradient/lasso-B/apg/dense-f32/call | 1.10.13 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.00176543 | target_missed=10 |
| gradient/lasso-B/apg/dense-f64/call | 1.10.13 | 3 / 10 | nan | [nan, nan] | nan / nan | 4.27398e-07 | ok=3, target_missed=7 |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.10.13 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.00116459 | target_missed=10 |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.10.13 | 3 / 10 | nan | [nan, nan] | nan / nan | 6.80929e-08 | ok=3, target_missed=7 |
| gradient/lasso-B/pg/dense-f32/call | 1.10.13 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.000340936 | target_missed=10 |
| gradient/lasso-B/pg/dense-f64/call | 1.10.13 | 4 / 10 | nan | [nan, nan] | nan / nan | 7.67396e-08 | ok=4, target_missed=6 |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.10.13 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.00114803 | ok=1, target_missed=9 |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.10.13 | 5 / 10 | nan | [nan, nan] | nan / nan | 7.35306e-08 | ok=5, target_missed=5 |
| gradient/lasso-C/apg/dense-f32/call | 1.10.13 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.00133862 | target_missed=10 |
| gradient/lasso-C/apg/dense-f64/call | 1.10.13 | 2 / 10 | nan | [nan, nan] | nan / nan | 3.10535e-07 | ok=2, target_missed=8 |
| gradient/lasso-C/pg/dense-f32/call | 1.10.13 | 2 / 10 | nan | [nan, nan] | nan / nan | 0.000418268 | ok=2, target_missed=8 |
| gradient/lasso-C/pg/dense-f64/call | 1.10.13 | 6 / 10 | nan | [nan, nan] | nan / nan | 4.26555e-08 | ok=6, target_missed=4 |
| gradient/lasso-D/apg/dense-f32/call | 1.10.13 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.00105687 | target_missed=10 |
| gradient/lasso-D/apg/dense-f64/call | 1.10.13 | 3 / 10 | nan | [nan, nan] | nan / nan | 3.15225e-08 | ok=3, target_missed=7 |
| gradient/lasso-D/pg/dense-f32/call | 1.10.13 | 2 / 10 | nan | [nan, nan] | nan / nan | 0.000118787 | ok=2, target_missed=8 |
| gradient/lasso-D/pg/dense-f64/call | 1.10.13 | 4 / 10 | nan | [nan, nan] | nan / nan | 3.55694e-08 | ok=4, target_missed=6 |
| gradient/lasso/apg/dense-f32/call | 1.10.13 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.00228922 | target_missed=10 |
| gradient/lasso/apg/dense-f64/call | 1.10.13 | 4 / 10 | nan | [nan, nan] | nan / nan | 1.97619e-07 | ok=4, target_missed=6 |
| gradient/lasso/pg/R/call | 1.10.13 | 10 / 10 | 33823.6 | [33487.7, 34159.5] | 4816 / 4816 | 0.000769421 | ok=10 |
| gradient/lasso/pg/dense-f32/call | 1.10.13 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.000458039 | target_missed=10 |
| gradient/lasso/pg/dense-f64/call | 1.10.13 | 9 / 10 | nan | [nan, nan] | nan / nan | 1.28427e-08 | ok=9, target_missed=1 |
