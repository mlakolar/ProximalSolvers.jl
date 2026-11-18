# ProximalSolvers cross-solver readout

Repetitions per Julia version: 10. Descriptive and per case: this readout copies the per-case values of summary.csv (shown here to six significant digits; cross_solver.csv carries them unchanged) and sets cases of different solvers side by side. It does not rank solvers or test differences between them. Each interval is the case's own Student-t interval over repetitions, not a paired comparison between solvers, so overlapping or separate intervals are not a test. The matched-accuracy comparison protocol is #110 (https://github.com/mlakolar/ProximalSolvers.jl/issues/110).

A group holds the cases of one Julia version, problem, phase, certificate measure, target and catalog input mode whose input data hashes agree in every repetition. The hash covers the problem data the solver received, not the solver or its settings; for the current-core cases it also covers the start. Precision and start are read from the case variant and must agree too. A configuration is the catalog solver with the rest of the variant; configurations are listed alphabetically.

A time is shown only when the target is finite and every run is ok, which means the independent certificate met the target in every sample; summary.csv must agree with the records on status counts, timing runs, worst certificate and mean time (intervals are not rechecked). Other cases show their status counts and worst certificate and no time. "Not recorded" marks a configuration that another case of the same problem, phase and start has and that this group lacks in the records; "ungrouped" marks one that was run with all of this group's labels but whose input hash is missing (see "Cases not grouped").

## group-lasso (call)

### Group 1: Julia 1.10.13, precision f32, start cold, relative_gap target 1e-05, inputs 9ebf9d620ca3 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| cd block | cd/group-lasso/cd/block-f32/call | 10 / 10 | 48909.1 | [43831.5, 53986.7] | 1.08829e-06 | ok=10 | shown |

### Group 2: Julia 1.10.13, precision f32, start warm, relative_gap target 1e-05, inputs 513fd9a9a34f (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| cd block | cd/group-lasso/cd/warm-block-f32/call | 10 / 10 | 43249.3 | [38899.2, 47599.4] | 6.82772e-07 | ok=10 | shown |

### Group 3: Julia 1.10.13, precision f64, start cold, relative_gap target 1e-08, inputs dcd33a34224c (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| cd block | cd/group-lasso/cd/block-f64/call | 10 / 10 | 64603.6 | [58441.3, 70765.9] | 4.75226e-12 | ok=10 | shown |

### Group 4: Julia 1.10.13, precision f64, start warm, relative_gap target 1e-08, inputs cd15a63020fd (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| cd block | cd/group-lasso/cd/warm-block-f64/call | 10 / 10 | 57051.4 | [51228.4, 62874.4] | 7.27282e-12 | ok=10 | shown |

### Group 5: Julia 1.13.3, precision f32, start cold, relative_gap target 1e-05, inputs 72b493e6d95b (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| cd block | cd/group-lasso/cd/block-f32/call | 10 / 10 | 42745.5 | [39473.8, 46017.2] | 5.83059e-07 | ok=10 | shown |

### Group 6: Julia 1.13.3, precision f32, start warm, relative_gap target 1e-05, inputs 672cedb718e5 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| cd block | cd/group-lasso/cd/warm-block-f32/call | 10 / 10 | 36395.1 | [33802.5, 38987.7] | 9.51463e-07 | ok=10 | shown |

### Group 7: Julia 1.13.3, precision f64, start cold, relative_gap target 1e-08, inputs 57b6e47e8ffe (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| cd block | cd/group-lasso/cd/block-f64/call | 10 / 10 | 61453.1 | [56144.1, 66762.1] | 6.71717e-12 | ok=10 | shown |

### Group 8: Julia 1.13.3, precision f64, start warm, relative_gap target 1e-08, inputs 345938bba805 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| cd block | cd/group-lasso/cd/warm-block-f64/call | 10 / 10 | 54549.9 | [50903, 58196.8] | 5.78772e-12 | ok=10 | shown |

## lasso (call)

### Group 9: Julia 1.10.13, precision f32, start cold, relative_gap target 1e-05, inputs e246094918ba (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso/apg/dense-f32/call | 2 / 10 |  |  | 9.09694e-05 | ok=2, target_missed=8 | excluded: not every run ok |
| cd dense | cd/lasso/cd/dense-f32/call | 10 / 10 | 7851.5 | [7368.71, 8334.29] | 5.95994e-07 | ok=10 | shown |
| cd sparse | cd/lasso/cd/sparse-f32/call | 10 / 10 | 7879.7 | [7463.35, 8296.05] | 5.95994e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso/pg/dense-f32/call | 2 / 10 |  |  | 9.23022e-05 | ok=2, target_missed=8 | excluded: not every run ok |

### Group 10: Julia 1.10.13, precision f64, start cold, relative_gap target 1e-08, inputs a6cbf3a9253b (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso/apg/acc-dense-f64/call | 10 / 10 | 55029.9 | [52983.6, 57076.2] | 1.23409e-10 | ok=10 | shown |
| apg dense | gradient/lasso/apg/dense-f64/call | 9 / 10 |  |  | 1.24599e-08 | ok=9, target_missed=1 | excluded: not every run ok |
| cd dense | cd/lasso/cd/dense-f64/call | 10 / 10 | 10249.1 | [9782.55, 10715.6] | 2.74712e-12 | ok=10 | shown |
| cd sparse | cd/lasso/cd/sparse-f64/call | 10 / 10 | 10402.4 | [9893.12, 10911.7] | 2.74712e-12 | ok=10 | shown |
| pg acc-dense | gradient/lasso/pg/acc-dense-f64/call | 10 / 10 | 37521.3 | [34584.7, 40457.9] | 1.13688e-10 | ok=10 | shown |
| pg dense | gradient/lasso/pg/dense-f64/call | 10 / 10 | 35262 | [30915.9, 39608.1] | 5.49245e-09 | ok=10 | shown |

### Group 11: Julia 1.10.13, precision not encoded, start not encoded, relative_gap target none, inputs 255abcac728b (fixed)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| pg R | gradient/lasso/pg/R/call | 10 / 10 |  |  | 2.88018e-05 | ok=10 | excluded: no accuracy target |

### Group 12: Julia 1.13.3, precision f32, start cold, relative_gap target 1e-05, inputs 4a1d7fea9474 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso/apg/dense-f32/call | 1 / 10 |  |  | 9.67056e-05 | ok=1, target_missed=9 | excluded: not every run ok |
| cd dense | cd/lasso/cd/dense-f32/call | 10 / 10 | 5304.3 | [5003.81, 5604.79] | 3.57172e-07 | ok=10 | shown |
| cd sparse | cd/lasso/cd/sparse-f32/call | 10 / 10 | 5165 | [4906.01, 5423.99] | 3.57172e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso/pg/dense-f32/call | 4 / 10 |  |  | 0.00010668 | ok=4, target_missed=6 | excluded: not every run ok |

### Group 13: Julia 1.13.3, precision f64, start cold, relative_gap target 1e-08, inputs e4d3263922c3 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso/apg/acc-dense-f64/call | 10 / 10 | 50227.1 | [48261.3, 52192.9] | 1.0779e-10 | ok=10 | shown |
| apg dense | gradient/lasso/apg/dense-f64/call | 10 / 10 | 52760 | [49856.9, 55663.1] | 2.05048e-09 | ok=10 | shown |
| cd dense | cd/lasso/cd/dense-f64/call | 10 / 10 | 7695.1 | [7289.54, 8100.66] | 1.3083e-12 | ok=10 | shown |
| cd sparse | cd/lasso/cd/sparse-f64/call | 10 / 10 | 7747.2 | [7372.47, 8121.93] | 1.3083e-12 | ok=10 | shown |
| pg acc-dense | gradient/lasso/pg/acc-dense-f64/call | 10 / 10 | 32579.1 | [30425.9, 34732.3] | 1.28759e-10 | ok=10 | shown |
| pg dense | gradient/lasso/pg/dense-f64/call | 10 / 10 | 31028.5 | [28280, 33777] | 2.60529e-09 | ok=10 | shown |

### Group 14: Julia 1.13.3, precision not encoded, start not encoded, relative_gap target none, inputs da18adcafa93 (fixed)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| pg R | gradient/lasso/pg/R/call | 10 / 10 |  |  | 2.9973e-05 | ok=10 | excluded: no accuracy target |

## lasso-B (call)

### Group 15: Julia 1.10.13, precision f32, start cold, relative_gap target 1e-05, inputs ef6f1e753972 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-B/apg/dense-f32/call | 0 / 10 |  |  | 0.0003147 | target_missed=10 | excluded: not every run ok |
| cd dense | cd/lasso-B/cd/dense-f32/call | 10 / 10 | 49013.5 | [42819.5, 55207.5] | 3.19554e-06 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/sparse-f32/call | 10 / 10 | 48490.9 | [42038.3, 54943.5] | 3.19554e-06 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-B/pg/dense-f32/call | 0 / 10 |  |  | 0.000237667 | target_missed=10 | excluded: not every run ok |

### Group 16: Julia 1.10.13, precision f32, start warm, relative_gap target 1e-05, inputs 368ed1630fc4 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-B/apg/warm-dense-f32/call | 1 / 10 |  |  | 0.000332694 | ok=1, target_missed=9 | excluded: not every run ok |
| cd dense | cd/lasso-B/cd/warm-dense-f32/call | 10 / 10 | 38288.6 | [35463.7, 41113.5] | 1.37177e-06 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/warm-sparse-f32/call | 10 / 10 | 39175.6 | [36266.3, 42084.9] | 1.37177e-06 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-B/pg/warm-dense-f32/call | 1 / 10 |  |  | 0.000644369 | ok=1, target_missed=9 | excluded: not every run ok |

### Group 17: Julia 1.10.13, precision f64, start cold, relative_gap target 1e-08, inputs 1a27a188c7f8 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-B/apg/acc-dense-f64/call | 10 / 10 | 1.00205e+06 | [758401, 1.24569e+06] | 3.38453e-10 | ok=10 | shown |
| apg dense | gradient/lasso-B/apg/dense-f64/call | 10 / 10 | 1.02032e+06 | [798448, 1.2422e+06] | 5.15948e-09 | ok=10 | shown |
| cd dense | cd/lasso-B/cd/dense-f64/call | 10 / 10 | 69737.8 | [54255.6, 85220] | 3.17081e-11 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/sparse-f64/call | 10 / 10 | 69806.1 | [53604.1, 86008.1] | 3.17081e-11 | ok=10 | shown |
| pg acc-dense | gradient/lasso-B/pg/acc-dense-f64/call | 10 / 10 | 1.45056e+06 | [748011, 2.1531e+06] | 1.81951e-10 | ok=10 | shown |
| pg dense | gradient/lasso-B/pg/dense-f64/call | 9 / 10 |  |  | 2.74234e-08 | ok=9, target_missed=1 | excluded: not every run ok |

### Group 18: Julia 1.10.13, precision f64, start warm, relative_gap target 1e-08, inputs aa41ed5ad0a1 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-B/apg/acc-warm-dense-f64/call | 10 / 10 | 846954 | [478808, 1.2151e+06] | 5.60574e-11 | ok=10 | shown |
| apg dense | gradient/lasso-B/apg/warm-dense-f64/call | 10 / 10 | 751372 | [520363, 982381] | 6.11044e-09 | ok=10 | shown |
| cd dense | cd/lasso-B/cd/warm-dense-f64/call | 10 / 10 | 55487.5 | [46646, 64329] | 3.3179e-11 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/warm-sparse-f64/call | 10 / 10 | 55715 | [47207.8, 64222.2] | 3.3179e-11 | ok=10 | shown |
| pg acc-dense | gradient/lasso-B/pg/acc-warm-dense-f64/call | 10 / 10 | 1.0356e+06 | [381112, 1.69008e+06] | 8.27036e-11 | ok=10 | shown |
| pg dense | gradient/lasso-B/pg/warm-dense-f64/call | 8 / 10 |  |  | 1.08631e-08 | ok=8, target_missed=2 | excluded: not every run ok |

### Group 19: Julia 1.13.3, precision f32, start cold, relative_gap target 1e-05, inputs 7732b9c962e6 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-B/apg/dense-f32/call | 1 / 10 |  |  | 0.000258525 | ok=1, target_missed=9 | excluded: not every run ok |
| cd dense | cd/lasso-B/cd/dense-f32/call | 10 / 10 | 35764.8 | [30526.8, 41002.8] | 2.90908e-06 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/sparse-f32/call | 10 / 10 | 35376.4 | [30202.6, 40550.2] | 2.90908e-06 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-B/pg/dense-f32/call | 1 / 10 |  |  | 0.000275767 | ok=1, target_missed=9 | excluded: not every run ok |

### Group 20: Julia 1.13.3, precision f32, start warm, relative_gap target 1e-05, inputs da29aa3db50d (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-B/apg/warm-dense-f32/call | 2 / 10 |  |  | 0.000254159 | ok=2, target_missed=8 | excluded: not every run ok |
| cd dense | cd/lasso-B/cd/warm-dense-f32/call | 10 / 10 | 25542.6 | [23053.8, 28031.4] | 2.89053e-06 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/warm-sparse-f32/call | 10 / 10 | 25168.3 | [22601.3, 27735.3] | 2.89053e-06 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-B/pg/warm-dense-f32/call | 1 / 10 |  |  | 0.000435403 | ok=1, target_missed=9 | excluded: not every run ok |

### Group 21: Julia 1.13.3, precision f64, start cold, relative_gap target 1e-08, inputs 69a428a8f61b (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-B/apg/acc-dense-f64/call | 10 / 10 | 991822 | [820978, 1.16266e+06] | 5.34974e-10 | ok=10 | shown |
| apg dense | gradient/lasso-B/apg/dense-f64/call | 10 / 10 | 1.06731e+06 | [906940, 1.22767e+06] | 4.81707e-09 | ok=10 | shown |
| cd dense | cd/lasso-B/cd/dense-f64/call | 10 / 10 | 62463.5 | [49753.4, 75173.6] | 1.06546e-11 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/sparse-f64/call | 10 / 10 | 62044.4 | [48567.1, 75521.7] | 1.06546e-11 | ok=10 | shown |
| pg acc-dense | gradient/lasso-B/pg/acc-dense-f64/call | 10 / 10 | 1.62227e+06 | [1.07151e+06, 2.17303e+06] | 1.81193e-10 | ok=10 | shown |
| pg dense | gradient/lasso-B/pg/dense-f64/call | 7 / 10 |  |  | 2.15671e-08 | ok=7, target_missed=3 | excluded: not every run ok |

### Group 22: Julia 1.13.3, precision f64, start warm, relative_gap target 1e-08, inputs a9c77f757ac1 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-B/apg/acc-warm-dense-f64/call | 10 / 10 | 888050 | [650585, 1.12552e+06] | 7.59748e-11 | ok=10 | shown |
| apg dense | gradient/lasso-B/apg/warm-dense-f64/call | 8 / 10 |  |  | 1.35043e-08 | ok=8, target_missed=2 | excluded: not every run ok |
| cd dense | cd/lasso-B/cd/warm-dense-f64/call | 10 / 10 | 47513.1 | [39547.2, 55479] | 2.62505e-11 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/warm-sparse-f64/call | 10 / 10 | 47697 | [39264.7, 56129.3] | 2.62505e-11 | ok=10 | shown |
| pg acc-dense | gradient/lasso-B/pg/acc-warm-dense-f64/call | 10 / 10 | 1.24873e+06 | [639446, 1.85802e+06] | 7.27499e-11 | ok=10 | shown |
| pg dense | gradient/lasso-B/pg/warm-dense-f64/call | 9 / 10 |  |  | 2.36082e-08 | ok=9, target_missed=1 | excluded: not every run ok |

## lasso-C (call)

### Group 23: Julia 1.10.13, precision f32, start cold, relative_gap target 1e-05, inputs c900bb906771 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-C/apg/dense-f32/call | 4 / 10 |  |  | 6.82462e-05 | ok=4, target_missed=6 | excluded: not every run ok |
| cd dense | cd/lasso-C/cd/dense-f32/call | 10 / 10 | 78980.6 | [78189.5, 79771.7] | 5.59476e-07 | ok=10 | shown |
| cd sparse | cd/lasso-C/cd/sparse-f32/call | 10 / 10 | 78659.7 | [77728, 79591.4] | 5.59476e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-C/pg/dense-f32/call | 3 / 10 |  |  | 0.000162929 | ok=3, target_missed=7 | excluded: not every run ok |

### Group 24: Julia 1.10.13, precision f64, start cold, relative_gap target 1e-08, inputs 3e9558914c3c (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-C/apg/acc-dense-f64/call | 10 / 10 | 1.33351e+06 | [1.2249e+06, 1.44212e+06] | 1.4471e-10 | ok=10 | shown |
| apg dense | gradient/lasso-C/apg/dense-f64/call | 10 / 10 | 1.35912e+06 | [1.23109e+06, 1.48714e+06] | 7.08895e-09 | ok=10 | shown |
| cd dense | cd/lasso-C/cd/dense-f64/call | 10 / 10 | 108646 | [105934, 111359] | 6.05071e-12 | ok=10 | shown |
| cd sparse | cd/lasso-C/cd/sparse-f64/call | 10 / 10 | 108291 | [106050, 110531] | 6.05071e-12 | ok=10 | shown |
| pg acc-dense | gradient/lasso-C/pg/acc-dense-f64/call | 10 / 10 | 1.15609e+06 | [969390, 1.34278e+06] | 2.40199e-10 | ok=10 | shown |
| pg dense | gradient/lasso-C/pg/dense-f64/call | 10 / 10 | 1.05013e+06 | [924947, 1.17531e+06] | 3.48906e-09 | ok=10 | shown |

### Group 25: Julia 1.13.3, precision f32, start cold, relative_gap target 1e-05, inputs d8ebd68e9079 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-C/apg/dense-f32/call | 2 / 10 |  |  | 0.000289786 | ok=2, target_missed=8 | excluded: not every run ok |
| cd dense | cd/lasso-C/cd/dense-f32/call | 10 / 10 | 44828.5 | [43872.8, 45784.2] | 4.79371e-07 | ok=10 | shown |
| cd sparse | cd/lasso-C/cd/sparse-f32/call | 10 / 10 | 44545.9 | [43691.9, 45399.9] | 4.79371e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-C/pg/dense-f32/call | 1 / 10 |  |  | 0.000224425 | ok=1, target_missed=9 | excluded: not every run ok |

### Group 26: Julia 1.13.3, precision f64, start cold, relative_gap target 1e-08, inputs 418865b8f450 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-C/apg/acc-dense-f64/call | 10 / 10 | 1.40113e+06 | [1.27462e+06, 1.52763e+06] | 1.66286e-10 | ok=10 | shown |
| apg dense | gradient/lasso-C/apg/dense-f64/call | 10 / 10 | 1.44925e+06 | [1.27359e+06, 1.62492e+06] | 1.8743e-09 | ok=10 | shown |
| cd dense | cd/lasso-C/cd/dense-f64/call | 10 / 10 | 89559.6 | [85899.4, 93219.8] | 7.24643e-12 | ok=10 | shown |
| cd sparse | cd/lasso-C/cd/sparse-f64/call | 10 / 10 | 89145.4 | [85583.3, 92707.5] | 7.24643e-12 | ok=10 | shown |
| pg acc-dense | gradient/lasso-C/pg/acc-dense-f64/call | 10 / 10 | 1.22106e+06 | [992958, 1.44917e+06] | 1.29959e-10 | ok=10 | shown |
| pg dense | gradient/lasso-C/pg/dense-f64/call | 9 / 10 |  |  | 1.00388e-08 | ok=9, target_missed=1 | excluded: not every run ok |

## lasso-D (call)

### Group 27: Julia 1.10.13, precision f32, start cold, relative_gap target 1e-05, inputs 534d5671a511 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-D/apg/dense-f32/call | 3 / 10 |  |  | 3.43689e-05 | ok=3, target_missed=7 | excluded: not every run ok |
| cd dense | cd/lasso-D/cd/dense-f32/call | 10 / 10 | 110971 | [108088, 113855] | 4.48279e-07 | ok=10 | shown |
| cd sparse | cd/lasso-D/cd/sparse-f32/call | 10 / 10 | 111020 | [107466, 114575] | 4.48279e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-D/pg/dense-f32/call | 5 / 10 |  |  | 8.38089e-05 | ok=5, target_missed=5 | excluded: not every run ok |

### Group 28: Julia 1.10.13, precision f64, start cold, relative_gap target 1e-08, inputs e691a9246105 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-D/apg/acc-dense-f64/call | 10 / 10 | 1.71705e+06 | [1.62315e+06, 1.81095e+06] | 1.67664e-10 | ok=10 | shown |
| apg dense | gradient/lasso-D/apg/dense-f64/call | 10 / 10 | 1.72021e+06 | [1.56198e+06, 1.87844e+06] | 5.17253e-09 | ok=10 | shown |
| cd dense | cd/lasso-D/cd/dense-f64/call | 10 / 10 | 134301 | [131735, 136866] | 7.20869e-13 | ok=10 | shown |
| cd sparse | cd/lasso-D/cd/sparse-f64/call | 10 / 10 | 131114 | [129457, 132771] | 7.20869e-13 | ok=10 | shown |
| pg acc-dense | gradient/lasso-D/pg/acc-dense-f64/call | 10 / 10 | 1.36721e+06 | [1.2644e+06, 1.47002e+06] | 1.65263e-10 | ok=10 | shown |
| pg dense | gradient/lasso-D/pg/dense-f64/call | 9 / 10 |  |  | 1.16163e-08 | ok=9, target_missed=1 | excluded: not every run ok |

### Group 29: Julia 1.13.3, precision f32, start cold, relative_gap target 1e-05, inputs 19e6f09bf903 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-D/apg/dense-f32/call | 3 / 10 |  |  | 4.15191e-05 | ok=3, target_missed=7 | excluded: not every run ok |
| cd dense | cd/lasso-D/cd/dense-f32/call | 10 / 10 | 73793.6 | [72201.3, 75385.9] | 4.3274e-07 | ok=10 | shown |
| cd sparse | cd/lasso-D/cd/sparse-f32/call | 10 / 10 | 73457.1 | [72021.6, 74892.6] | 4.3274e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-D/pg/dense-f32/call | 6 / 10 |  |  | 2.99049e-05 | ok=6, target_missed=4 | excluded: not every run ok |

### Group 30: Julia 1.13.3, precision f64, start cold, relative_gap target 1e-08, inputs 92ac0442f0cb (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-D/apg/acc-dense-f64/call | 10 / 10 | 1.61395e+06 | [1.49835e+06, 1.72955e+06] | 1.36519e-10 | ok=10 | shown |
| apg dense | gradient/lasso-D/apg/dense-f64/call | 10 / 10 | 1.63054e+06 | [1.49306e+06, 1.76802e+06] | 3.71883e-09 | ok=10 | shown |
| cd dense | cd/lasso-D/cd/dense-f64/call | 10 / 10 | 110170 | [108239, 112101] | 4.40968e-13 | ok=10 | shown |
| cd sparse | cd/lasso-D/cd/sparse-f64/call | 10 / 10 | 110356 | [108081, 112631] | 4.40968e-13 | ok=10 | shown |
| pg acc-dense | gradient/lasso-D/pg/acc-dense-f64/call | 10 / 10 | 1.40137e+06 | [1.29268e+06, 1.51005e+06] | 1.41756e-10 | ok=10 | shown |
| pg dense | gradient/lasso-D/pg/dense-f64/call | 10 / 10 | 1.35674e+06 | [1.23805e+06, 1.47543e+06] | 4.01926e-09 | ok=10 | shown |

## lasso-dense (call)

### Group 31: Julia 1.10.13, precision not encoded, start not encoded, relative_gap target none, inputs 38507ab1da2c (fixed)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| cd R | cd/lasso-dense/cd/R/call | 10 / 10 |  |  | 5.75233e-08 | ok=10 | excluded: no accuracy target |

### Group 32: Julia 1.13.3, precision not encoded, start not encoded, relative_gap target none, inputs 9582cbe50e20 (fixed)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| cd R | cd/lasso-dense/cd/R/call | 10 / 10 |  |  | 5.75233e-08 | ok=10 | excluded: no accuracy target |

## lasso-weighted (call)

### Group 33: Julia 1.10.13, precision f32, start cold, relative_gap target 1e-05, inputs 51a459ae44eb (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| cd dense | cd/lasso-weighted/cd/dense-f32/call | 10 / 10 | 8170.4 | [7622.33, 8718.47] | 3.79078e-07 | ok=10 | shown |
| cd sparse | cd/lasso-weighted/cd/sparse-f32/call | 10 / 10 | 8123.4 | [7375.62, 8871.18] | 3.79078e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |

### Group 34: Julia 1.10.13, precision f64, start cold, relative_gap target 1e-08, inputs 30da3063e976 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-weighted/apg/acc-dense-f64/call | 10 / 10 | 58517.3 | [53964.5, 63070.1] | 4.16952e-11 | ok=10 | shown |
| cd dense | cd/lasso-weighted/cd/dense-f64/call | 10 / 10 | 11189.1 | [10069.4, 12308.8] | 1.05681e-12 | ok=10 | shown |
| cd sparse | cd/lasso-weighted/cd/sparse-f64/call | 10 / 10 | 11117.6 | [10138, 12097.2] | 1.05681e-12 | ok=10 | shown |
| pg acc-dense | gradient/lasso-weighted/pg/acc-dense-f64/call | 10 / 10 | 39809 | [34601.1, 45016.9] | 6.73921e-11 | ok=10 | shown |

### Group 35: Julia 1.13.3, precision f32, start cold, relative_gap target 1e-05, inputs 0df774aedf8b (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| cd dense | cd/lasso-weighted/cd/dense-f32/call | 10 / 10 | 5885.8 | [5397.52, 6374.08] | 4.32305e-07 | ok=10 | shown |
| cd sparse | cd/lasso-weighted/cd/sparse-f32/call | 10 / 10 | 5999.6 | [5409.61, 6589.59] | 4.32305e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |

### Group 36: Julia 1.13.3, precision f64, start cold, relative_gap target 1e-08, inputs eff65c3da3b4 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-weighted/apg/acc-dense-f64/call | 10 / 10 | 50766.3 | [48005.8, 53526.8] | 1.9928e-10 | ok=10 | shown |
| cd dense | cd/lasso-weighted/cd/dense-f64/call | 10 / 10 | 8882.8 | [7827.96, 9937.64] | 1.57511e-12 | ok=10 | shown |
| cd sparse | cd/lasso-weighted/cd/sparse-f64/call | 10 / 10 | 8924.4 | [7837.1, 10011.7] | 1.57511e-12 | ok=10 | shown |
| pg acc-dense | gradient/lasso-weighted/pg/acc-dense-f64/call | 10 / 10 | 33940.4 | [28908.7, 38972.1] | 2.79256e-10 | ok=10 | shown |

## Cases not grouped

Cases whose inputs cannot be identified are not set beside any other case.

| Julia | Problem | Phase | Precision | Start | Measure | Target | Input mode | Configuration | Case | Ok runs / total | Worst certificate | Status counts | Time |
|---|---|---|---|---|---|---:|---|---|---|---:|---:|---|---|
| None | | | | | | | | | | | | | |
