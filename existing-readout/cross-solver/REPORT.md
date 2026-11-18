# ProximalSolvers cross-solver readout

Repetitions per Julia version: 10. Descriptive and per case: this readout copies the per-case values of summary.csv (shown here to six significant digits; cross_solver.csv carries them unchanged) and sets cases of different solvers side by side. It does not rank solvers or test differences between them. Each interval is the case's own Student-t interval over repetitions, not a paired comparison between solvers, so overlapping or separate intervals are not a test. The matched-accuracy comparison protocol is #110 (https://github.com/mlakolar/ProximalSolvers.jl/issues/110).

A group holds the cases of one Julia version, problem, phase, certificate measure, target and catalog input mode whose input data hashes agree in every repetition. The hash covers the problem data the solver received, not the solver or its settings; for the current-core cases it also covers the start. Precision and start are read from the case variant and must agree too. A configuration is the catalog solver with the rest of the variant; configurations are listed alphabetically.

A time is shown only when the target is finite and every run is ok, which means the independent certificate met the target in every sample; summary.csv must agree with the records on status counts, timing runs, worst certificate and mean time (intervals are not rechecked). Other cases show their status counts and worst certificate and no time. "Not recorded" marks a configuration that another case of the same problem, phase and start has and that this group lacks in the records; "ungrouped" marks one that was run with all of this group's labels but whose input hash is missing (see "Cases not grouped").

## lasso (call)

### Group 1: Julia 1.10.13, precision f32, start cold, relative_gap target 1e-05, inputs e246094918ba (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso/apg/dense-f32/call | 2 / 10 |  |  | 9.09694e-05 | ok=2, target_missed=8 | excluded: not every run ok |
| cd dense | cd/lasso/cd/dense-f32/call | 10 / 10 | 7785.2 | [7392.83, 8177.57] | 5.95994e-07 | ok=10 | shown |
| cd sparse | cd/lasso/cd/sparse-f32/call | 10 / 10 | 7654.2 | [7157.2, 8151.2] | 5.95994e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso/pg/dense-f32/call | 2 / 10 |  |  | 9.23022e-05 | ok=2, target_missed=8 | excluded: not every run ok |

### Group 2: Julia 1.10.13, precision f64, start cold, relative_gap target 1e-08, inputs a6cbf3a9253b (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso/apg/acc-dense-f64/call | 10 / 10 | 54693.5 | [51720.9, 57666.1] | 1.23409e-10 | ok=10 | shown |
| apg dense | gradient/lasso/apg/dense-f64/call | 9 / 10 |  |  | 1.24599e-08 | ok=9, target_missed=1 | excluded: not every run ok |
| cd dense | cd/lasso/cd/dense-f64/call | 10 / 10 | 10400.2 | [9989.74, 10810.7] | 2.74712e-12 | ok=10 | shown |
| cd sparse | cd/lasso/cd/sparse-f64/call | 10 / 10 | 10217.4 | [9783.69, 10651.1] | 2.74712e-12 | ok=10 | shown |
| pg acc-dense | gradient/lasso/pg/acc-dense-f64/call | 10 / 10 | 37587.3 | [34449.4, 40725.2] | 1.13688e-10 | ok=10 | shown |
| pg dense | gradient/lasso/pg/dense-f64/call | 10 / 10 | 34618.9 | [30313, 38924.8] | 5.49245e-09 | ok=10 | shown |

### Group 3: Julia 1.10.13, precision not encoded, start not encoded, relative_gap target none, inputs 255abcac728b (fixed)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| pg R | gradient/lasso/pg/R/call | 10 / 10 |  |  | 2.88018e-05 | ok=10 | excluded: no accuracy target |

### Group 4: Julia 1.13.3, precision f32, start cold, relative_gap target 1e-05, inputs 4a1d7fea9474 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso/apg/dense-f32/call | 1 / 10 |  |  | 9.67056e-05 | ok=1, target_missed=9 | excluded: not every run ok |
| cd dense | cd/lasso/cd/dense-f32/call | 10 / 10 | 5242.6 | [5041.96, 5443.24] | 3.57172e-07 | ok=10 | shown |
| cd sparse | cd/lasso/cd/sparse-f32/call | 10 / 10 | 5301.2 | [5053.68, 5548.72] | 3.57172e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso/pg/dense-f32/call | 4 / 10 |  |  | 0.00010668 | ok=4, target_missed=6 | excluded: not every run ok |

### Group 5: Julia 1.13.3, precision f64, start cold, relative_gap target 1e-08, inputs e4d3263922c3 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso/apg/acc-dense-f64/call | 10 / 10 | 51167 | [48696.7, 53637.3] | 1.0779e-10 | ok=10 | shown |
| apg dense | gradient/lasso/apg/dense-f64/call | 10 / 10 | 52873.2 | [49824.8, 55921.6] | 2.05048e-09 | ok=10 | shown |
| cd dense | cd/lasso/cd/dense-f64/call | 10 / 10 | 7735.3 | [7382.16, 8088.44] | 1.3083e-12 | ok=10 | shown |
| cd sparse | cd/lasso/cd/sparse-f64/call | 10 / 10 | 7919.3 | [7629.43, 8209.17] | 1.3083e-12 | ok=10 | shown |
| pg acc-dense | gradient/lasso/pg/acc-dense-f64/call | 10 / 10 | 32676.8 | [30452.6, 34901] | 1.28759e-10 | ok=10 | shown |
| pg dense | gradient/lasso/pg/dense-f64/call | 10 / 10 | 31112.9 | [28354.6, 33871.2] | 2.60529e-09 | ok=10 | shown |

### Group 6: Julia 1.13.3, precision not encoded, start not encoded, relative_gap target none, inputs da18adcafa93 (fixed)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| pg R | gradient/lasso/pg/R/call | 10 / 10 |  |  | 2.9973e-05 | ok=10 | excluded: no accuracy target |

## lasso-B (call)

### Group 7: Julia 1.10.13, precision f32, start cold, relative_gap target 1e-05, inputs ef6f1e753972 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-B/apg/dense-f32/call | 0 / 10 |  |  | 0.0003147 | target_missed=10 | excluded: not every run ok |
| cd dense | cd/lasso-B/cd/dense-f32/call | 10 / 10 | 49226.5 | [42577, 55876] | 3.19554e-06 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/sparse-f32/call | 10 / 10 | 49033.4 | [42317.9, 55748.9] | 3.19554e-06 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-B/pg/dense-f32/call | 0 / 10 |  |  | 0.000237667 | target_missed=10 | excluded: not every run ok |

### Group 8: Julia 1.10.13, precision f32, start warm, relative_gap target 1e-05, inputs 368ed1630fc4 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-B/apg/warm-dense-f32/call | 1 / 10 |  |  | 0.000332694 | ok=1, target_missed=9 | excluded: not every run ok |
| cd dense | cd/lasso-B/cd/warm-dense-f32/call | 10 / 10 | 38819 | [35877.9, 41760.1] | 1.37177e-06 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/warm-sparse-f32/call | 10 / 10 | 38528.9 | [35623.2, 41434.6] | 1.37177e-06 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-B/pg/warm-dense-f32/call | 1 / 10 |  |  | 0.000644369 | ok=1, target_missed=9 | excluded: not every run ok |

### Group 9: Julia 1.10.13, precision f64, start cold, relative_gap target 1e-08, inputs 1a27a188c7f8 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-B/apg/acc-dense-f64/call | 10 / 10 | 994348 | [727281, 1.26141e+06] | 3.38453e-10 | ok=10 | shown |
| apg dense | gradient/lasso-B/apg/dense-f64/call | 10 / 10 | 983866 | [775437, 1.19229e+06] | 5.15948e-09 | ok=10 | shown |
| cd dense | cd/lasso-B/cd/dense-f64/call | 10 / 10 | 69524.2 | [54203.3, 84845.1] | 3.17081e-11 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/sparse-f64/call | 10 / 10 | 70869.4 | [53574, 88164.8] | 3.17081e-11 | ok=10 | shown |
| pg acc-dense | gradient/lasso-B/pg/acc-dense-f64/call | 10 / 10 | 1.39245e+06 | [745464, 2.03945e+06] | 1.81951e-10 | ok=10 | shown |
| pg dense | gradient/lasso-B/pg/dense-f64/call | 9 / 10 |  |  | 2.74234e-08 | ok=9, target_missed=1 | excluded: not every run ok |

### Group 10: Julia 1.10.13, precision f64, start warm, relative_gap target 1e-08, inputs aa41ed5ad0a1 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-B/apg/acc-warm-dense-f64/call | 10 / 10 | 804810 | [477460, 1.13216e+06] | 5.60574e-11 | ok=10 | shown |
| apg dense | gradient/lasso-B/apg/warm-dense-f64/call | 10 / 10 | 720316 | [514261, 926370] | 6.11044e-09 | ok=10 | shown |
| cd dense | cd/lasso-B/cd/warm-dense-f64/call | 10 / 10 | 54499.9 | [46816.9, 62182.9] | 3.3179e-11 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/warm-sparse-f64/call | 10 / 10 | 55160.9 | [45905.9, 64415.9] | 3.3179e-11 | ok=10 | shown |
| pg acc-dense | gradient/lasso-B/pg/acc-warm-dense-f64/call | 10 / 10 | 1.00629e+06 | [385101, 1.62748e+06] | 8.27036e-11 | ok=10 | shown |
| pg dense | gradient/lasso-B/pg/warm-dense-f64/call | 8 / 10 |  |  | 1.08631e-08 | ok=8, target_missed=2 | excluded: not every run ok |

### Group 11: Julia 1.13.3, precision f32, start cold, relative_gap target 1e-05, inputs 7732b9c962e6 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-B/apg/dense-f32/call | 1 / 10 |  |  | 0.000258525 | ok=1, target_missed=9 | excluded: not every run ok |
| cd dense | cd/lasso-B/cd/dense-f32/call | 10 / 10 | 35694.8 | [30570.7, 40818.9] | 2.90908e-06 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/sparse-f32/call | 10 / 10 | 36033.4 | [30688.7, 41378.1] | 2.90908e-06 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-B/pg/dense-f32/call | 2 / 10 |  |  | 0.000275767 | ok=2, target_missed=8 | excluded: not every run ok |

### Group 12: Julia 1.13.3, precision f32, start warm, relative_gap target 1e-05, inputs da29aa3db50d (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-B/apg/warm-dense-f32/call | 2 / 10 |  |  | 0.000254159 | ok=2, target_missed=8 | excluded: not every run ok |
| cd dense | cd/lasso-B/cd/warm-dense-f32/call | 10 / 10 | 25962.3 | [23721.3, 28203.3] | 2.89053e-06 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/warm-sparse-f32/call | 10 / 10 | 25823.8 | [23065.2, 28582.4] | 2.89053e-06 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-B/pg/warm-dense-f32/call | 1 / 10 |  |  | 0.000435403 | ok=1, target_missed=9 | excluded: not every run ok |

### Group 13: Julia 1.13.3, precision f64, start cold, relative_gap target 1e-08, inputs 69a428a8f61b (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-B/apg/acc-dense-f64/call | 10 / 10 | 1.00799e+06 | [840567, 1.17542e+06] | 5.34974e-10 | ok=10 | shown |
| apg dense | gradient/lasso-B/apg/dense-f64/call | 10 / 10 | 1.01054e+06 | [851727, 1.16935e+06] | 4.81707e-09 | ok=10 | shown |
| cd dense | cd/lasso-B/cd/dense-f64/call | 10 / 10 | 60833.1 | [48543.2, 73123] | 1.06546e-11 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/sparse-f64/call | 10 / 10 | 61227.2 | [48298.7, 74155.7] | 1.06546e-11 | ok=10 | shown |
| pg acc-dense | gradient/lasso-B/pg/acc-dense-f64/call | 10 / 10 | 1.51926e+06 | [1.0118e+06, 2.02671e+06] | 1.81193e-10 | ok=10 | shown |
| pg dense | gradient/lasso-B/pg/dense-f64/call | 7 / 10 |  |  | 2.15671e-08 | ok=7, target_missed=3 | excluded: not every run ok |

### Group 14: Julia 1.13.3, precision f64, start warm, relative_gap target 1e-08, inputs a9c77f757ac1 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-B/apg/acc-warm-dense-f64/call | 10 / 10 | 893111 | [657102, 1.12912e+06] | 7.59748e-11 | ok=10 | shown |
| apg dense | gradient/lasso-B/apg/warm-dense-f64/call | 8 / 10 |  |  | 1.35043e-08 | ok=8, target_missed=2 | excluded: not every run ok |
| cd dense | cd/lasso-B/cd/warm-dense-f64/call | 10 / 10 | 47979.1 | [39779.3, 56178.9] | 2.62505e-11 | ok=10 | shown |
| cd sparse | cd/lasso-B/cd/warm-sparse-f64/call | 10 / 10 | 46715.1 | [39033.4, 54396.8] | 2.62505e-11 | ok=10 | shown |
| pg acc-dense | gradient/lasso-B/pg/acc-warm-dense-f64/call | 10 / 10 | 1.22538e+06 | [624972, 1.82579e+06] | 7.27499e-11 | ok=10 | shown |
| pg dense | gradient/lasso-B/pg/warm-dense-f64/call | 9 / 10 |  |  | 2.36082e-08 | ok=9, target_missed=1 | excluded: not every run ok |

## lasso-C (call)

### Group 15: Julia 1.10.13, precision f32, start cold, relative_gap target 1e-05, inputs c900bb906771 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-C/apg/dense-f32/call | 4 / 10 |  |  | 6.82462e-05 | ok=4, target_missed=6 | excluded: not every run ok |
| cd dense | cd/lasso-C/cd/dense-f32/call | 10 / 10 | 79084.1 | [78306.2, 79862] | 5.59476e-07 | ok=10 | shown |
| cd sparse | cd/lasso-C/cd/sparse-f32/call | 10 / 10 | 78813.4 | [77996.3, 79630.5] | 5.59476e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-C/pg/dense-f32/call | 4 / 10 |  |  | 0.000162929 | ok=4, target_missed=6 | excluded: not every run ok |

### Group 16: Julia 1.10.13, precision f64, start cold, relative_gap target 1e-08, inputs 3e9558914c3c (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-C/apg/acc-dense-f64/call | 10 / 10 | 1.32811e+06 | [1.22192e+06, 1.4343e+06] | 1.4471e-10 | ok=10 | shown |
| apg dense | gradient/lasso-C/apg/dense-f64/call | 10 / 10 | 1.35672e+06 | [1.23114e+06, 1.48231e+06] | 7.08895e-09 | ok=10 | shown |
| cd dense | cd/lasso-C/cd/dense-f64/call | 10 / 10 | 109177 | [106778, 111576] | 6.05071e-12 | ok=10 | shown |
| cd sparse | cd/lasso-C/cd/sparse-f64/call | 10 / 10 | 108294 | [105756, 110831] | 6.05071e-12 | ok=10 | shown |
| pg acc-dense | gradient/lasso-C/pg/acc-dense-f64/call | 10 / 10 | 1.12778e+06 | [936095, 1.31946e+06] | 2.40199e-10 | ok=10 | shown |
| pg dense | gradient/lasso-C/pg/dense-f64/call | 10 / 10 | 1.04401e+06 | [918036, 1.16999e+06] | 3.48906e-09 | ok=10 | shown |

### Group 17: Julia 1.13.3, precision f32, start cold, relative_gap target 1e-05, inputs d8ebd68e9079 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-C/apg/dense-f32/call | 2 / 10 |  |  | 0.000289786 | ok=2, target_missed=8 | excluded: not every run ok |
| cd dense | cd/lasso-C/cd/dense-f32/call | 10 / 10 | 45139.6 | [43786.9, 46492.3] | 4.79371e-07 | ok=10 | shown |
| cd sparse | cd/lasso-C/cd/sparse-f32/call | 10 / 10 | 44587.8 | [43587.2, 45588.4] | 4.79371e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-C/pg/dense-f32/call | 1 / 10 |  |  | 0.000413605 | ok=1, target_missed=9 | excluded: not every run ok |

### Group 18: Julia 1.13.3, precision f64, start cold, relative_gap target 1e-08, inputs 418865b8f450 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-C/apg/acc-dense-f64/call | 10 / 10 | 1.40633e+06 | [1.27866e+06, 1.534e+06] | 1.66286e-10 | ok=10 | shown |
| apg dense | gradient/lasso-C/apg/dense-f64/call | 10 / 10 | 1.4508e+06 | [1.27468e+06, 1.62693e+06] | 1.8743e-09 | ok=10 | shown |
| cd dense | cd/lasso-C/cd/dense-f64/call | 10 / 10 | 89799.1 | [86252.2, 93346] | 7.24643e-12 | ok=10 | shown |
| cd sparse | cd/lasso-C/cd/sparse-f64/call | 10 / 10 | 89154.5 | [85344.3, 92964.7] | 7.24643e-12 | ok=10 | shown |
| pg acc-dense | gradient/lasso-C/pg/acc-dense-f64/call | 10 / 10 | 1.22136e+06 | [993239, 1.44948e+06] | 1.29959e-10 | ok=10 | shown |
| pg dense | gradient/lasso-C/pg/dense-f64/call | 9 / 10 |  |  | 1.00388e-08 | ok=9, target_missed=1 | excluded: not every run ok |

## lasso-D (call)

### Group 19: Julia 1.10.13, precision f32, start cold, relative_gap target 1e-05, inputs 534d5671a511 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-D/apg/dense-f32/call | 3 / 10 |  |  | 3.43689e-05 | ok=3, target_missed=7 | excluded: not every run ok |
| cd dense | cd/lasso-D/cd/dense-f32/call | 10 / 10 | 113101 | [110885, 115317] | 4.48279e-07 | ok=10 | shown |
| cd sparse | cd/lasso-D/cd/sparse-f32/call | 10 / 10 | 112680 | [110048, 115312] | 4.48279e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-D/pg/dense-f32/call | 7 / 10 |  |  | 8.38089e-05 | ok=7, target_missed=3 | excluded: not every run ok |

### Group 20: Julia 1.10.13, precision f64, start cold, relative_gap target 1e-08, inputs e691a9246105 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-D/apg/acc-dense-f64/call | 10 / 10 | 1.71205e+06 | [1.6209e+06, 1.80321e+06] | 1.67664e-10 | ok=10 | shown |
| apg dense | gradient/lasso-D/apg/dense-f64/call | 10 / 10 | 1.71487e+06 | [1.55507e+06, 1.87467e+06] | 5.17253e-09 | ok=10 | shown |
| cd dense | cd/lasso-D/cd/dense-f64/call | 10 / 10 | 135595 | [133087, 138103] | 7.20869e-13 | ok=10 | shown |
| cd sparse | cd/lasso-D/cd/sparse-f64/call | 10 / 10 | 133647 | [131337, 135957] | 7.20869e-13 | ok=10 | shown |
| pg acc-dense | gradient/lasso-D/pg/acc-dense-f64/call | 10 / 10 | 1.33998e+06 | [1.25431e+06, 1.42565e+06] | 1.65263e-10 | ok=10 | shown |
| pg dense | gradient/lasso-D/pg/dense-f64/call | 9 / 10 |  |  | 1.16163e-08 | ok=9, target_missed=1 | excluded: not every run ok |

### Group 21: Julia 1.13.3, precision f32, start cold, relative_gap target 1e-05, inputs 19e6f09bf903 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso-D/apg/dense-f32/call | 3 / 10 |  |  | 4.15191e-05 | ok=3, target_missed=7 | excluded: not every run ok |
| cd dense | cd/lasso-D/cd/dense-f32/call | 10 / 10 | 75018.4 | [73654.4, 76382.4] | 4.3274e-07 | ok=10 | shown |
| cd sparse | cd/lasso-D/cd/sparse-f32/call | 10 / 10 | 74195.6 | [72580.7, 75810.5] | 4.3274e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso-D/pg/dense-f32/call | 5 / 10 |  |  | 6.82582e-05 | ok=5, target_missed=5 | excluded: not every run ok |

### Group 22: Julia 1.13.3, precision f64, start cold, relative_gap target 1e-08, inputs 92ac0442f0cb (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | gradient/lasso-D/apg/acc-dense-f64/call | 10 / 10 | 1.61694e+06 | [1.50018e+06, 1.7337e+06] | 1.36519e-10 | ok=10 | shown |
| apg dense | gradient/lasso-D/apg/dense-f64/call | 10 / 10 | 1.63216e+06 | [1.49512e+06, 1.7692e+06] | 3.71883e-09 | ok=10 | shown |
| cd dense | cd/lasso-D/cd/dense-f64/call | 10 / 10 | 111705 | [110181, 113229] | 4.40968e-13 | ok=10 | shown |
| cd sparse | cd/lasso-D/cd/sparse-f64/call | 10 / 10 | 110540 | [108093, 112986] | 4.40968e-13 | ok=10 | shown |
| pg acc-dense | gradient/lasso-D/pg/acc-dense-f64/call | 10 / 10 | 1.42892e+06 | [1.31724e+06, 1.54061e+06] | 1.41756e-10 | ok=10 | shown |
| pg dense | gradient/lasso-D/pg/dense-f64/call | 10 / 10 | 1.37923e+06 | [1.26196e+06, 1.4965e+06] | 4.01926e-09 | ok=10 | shown |

## lasso-dense (call)

### Group 23: Julia 1.10.13, precision not encoded, start not encoded, relative_gap target none, inputs 38507ab1da2c (fixed)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| cd R | cd/lasso-dense/cd/R/call | 10 / 10 |  |  | 5.75233e-08 | ok=10 | excluded: no accuracy target |

### Group 24: Julia 1.13.3, precision not encoded, start not encoded, relative_gap target none, inputs 9582cbe50e20 (fixed)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| cd R | cd/lasso-dense/cd/R/call | 10 / 10 |  |  | 5.75233e-08 | ok=10 | excluded: no accuracy target |

## Cases not grouped

Cases whose inputs cannot be identified are not set beside any other case.

| Julia | Problem | Phase | Precision | Start | Measure | Target | Input mode | Configuration | Case | Ok runs / total | Worst certificate | Status counts | Time |
|---|---|---|---|---|---|---:|---|---|---|---:|---:|---|---|
| None | | | | | | | | | | | | | |
