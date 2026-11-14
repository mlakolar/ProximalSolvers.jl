# ProximalSolvers benchmark summary

Record integrity: valid. Repetitions per Julia version: 10.

Time is the arithmetic mean of the per-repetition medians. Each median uses only ok samples. The Student-t interval uses independent repetitions, never individual samples. One repetition has a NaN interval. The fastest run is never selected.

Every repetition contributes to the summary. If any repetition has no ok samples, the aggregate time and interval are NaN. Status counts include all repetitions, including those with numerical failures. Bytes are aggregated from the same ok samples; mean bytes is the mean of repetition medians. Worst accuracy is the maximum reported worst_value, ignoring NaN values; status counts retain uncertifiable results.

Intervals include input variability and machine noise. They do not correct for correlated noise or multiple comparisons. Bytes measure Julia heap allocation, not native allocation or peak memory.

| Case | Julia | Runs with timing / total | Mean median (ns) | 95% interval (ns) | Mean / median bytes | Worst accuracy | Status counts |
|---|---|---:|---:|---:|---:|---:|---|
| gradient/lasso-B/apg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.00125548 | ok=1, target_missed=9 |
| gradient/lasso-B/apg/dense-f64/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 1.24191e-07 | ok=2, target_missed=8 |
| gradient/lasso-B/apg/warm-dense-f32/call | 1.13.3 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.000837637 | target_missed=10 |
| gradient/lasso-B/apg/warm-dense-f64/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 9.66406e-08 | ok=2, target_missed=8 |
| gradient/lasso-B/pg/dense-f32/call | 1.13.3 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.00124379 | target_missed=10 |
| gradient/lasso-B/pg/dense-f64/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 6.68142e-08 | ok=2, target_missed=8 |
| gradient/lasso-B/pg/warm-dense-f32/call | 1.13.3 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.00108619 | target_missed=10 |
| gradient/lasso-B/pg/warm-dense-f64/call | 1.13.3 | 2 / 10 | nan | [nan, nan] | nan / nan | 8.65615e-08 | ok=2, target_missed=8 |
| gradient/lasso-C/apg/dense-f32/call | 1.13.3 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.0016327 | target_missed=10 |
| gradient/lasso-C/apg/dense-f64/call | 1.13.3 | 4 / 10 | nan | [nan, nan] | nan / nan | 2.56606e-07 | ok=4, target_missed=6 |
| gradient/lasso-C/pg/dense-f32/call | 1.13.3 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.000447513 | target_missed=10 |
| gradient/lasso-C/pg/dense-f64/call | 1.13.3 | 6 / 10 | nan | [nan, nan] | nan / nan | 4.38008e-08 | ok=6, target_missed=4 |
| gradient/lasso-D/apg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.00116651 | ok=1, target_missed=9 |
| gradient/lasso-D/apg/dense-f64/call | 1.13.3 | 4 / 10 | nan | [nan, nan] | nan / nan | 6.61325e-08 | ok=4, target_missed=6 |
| gradient/lasso-D/pg/dense-f32/call | 1.13.3 | 4 / 10 | nan | [nan, nan] | nan / nan | 0.000177296 | ok=4, target_missed=6 |
| gradient/lasso-D/pg/dense-f64/call | 1.13.3 | 5 / 10 | nan | [nan, nan] | nan / nan | 4.62884e-08 | ok=5, target_missed=5 |
| gradient/lasso/apg/dense-f32/call | 1.13.3 | 0 / 10 | nan | [nan, nan] | nan / nan | 0.00102598 | target_missed=10 |
| gradient/lasso/apg/dense-f64/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 6.7177e-08 | ok=1, target_missed=9 |
| gradient/lasso/pg/R/call | 1.13.3 | 10 / 10 | 30446.2 | [30208.2, 30684.2] | 4688 / 4688 | 0.000772446 | ok=10 |
| gradient/lasso/pg/dense-f32/call | 1.13.3 | 1 / 10 | nan | [nan, nan] | nan / nan | 0.000563329 | ok=1, target_missed=9 |
| gradient/lasso/pg/dense-f64/call | 1.13.3 | 9 / 10 | nan | [nan, nan] | nan / nan | 1.22777e-08 | ok=9, target_missed=1 |
