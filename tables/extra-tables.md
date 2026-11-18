# Existing (637f06a) vs fresh (a0a06477): status and inputs on shared cases

Same CPU kind (Xeon E5-2640 v4), Julia 1.10.13 / 1.13.3, harness hashes differ (cases.jl gained cases). Descriptive: these are two revisions in separate jobs, not a paired comparison.

## Julia 1.10.13: 52 shared cases; per-repetition input hashes equal in 52; ok count or worst certificate differs in 2

| Case | Ok runs existing → fresh | Worst certificate existing → fresh |
|---|---:|---:|
| `gradient/lasso-C/pg/dense-f32/call` | 4 → 3 | 0.000163 → 0.000163 |
| `gradient/lasso-D/pg/dense-f32/call` | 7 → 5 | 8.38e-05 → 8.38e-05 |

New in the fresh catalog (10): `cd/group-lasso/cd/block-f32/call`, `cd/group-lasso/cd/block-f64/call`, `cd/group-lasso/cd/warm-block-f32/call`, `cd/group-lasso/cd/warm-block-f64/call`, `cd/lasso-weighted/cd/dense-f32/call`, `cd/lasso-weighted/cd/dense-f64/call`, `cd/lasso-weighted/cd/sparse-f32/call`, `cd/lasso-weighted/cd/sparse-f64/call`, `gradient/lasso-weighted/apg/acc-dense-f64/call`, `gradient/lasso-weighted/pg/acc-dense-f64/call`

## Julia 1.13.3: 52 shared cases; per-repetition input hashes equal in 52; ok count or worst certificate differs in 3

| Case | Ok runs existing → fresh | Worst certificate existing → fresh |
|---|---:|---:|
| `gradient/lasso-B/pg/dense-f32/call` | 2 → 1 | 0.000276 → 0.000276 |
| `gradient/lasso-C/pg/dense-f32/call` | 1 → 1 | 0.000414 → 0.000224 |
| `gradient/lasso-D/pg/dense-f32/call` | 5 → 6 | 6.83e-05 → 2.99e-05 |

New in the fresh catalog (10): `cd/group-lasso/cd/block-f32/call`, `cd/group-lasso/cd/block-f64/call`, `cd/group-lasso/cd/warm-block-f32/call`, `cd/group-lasso/cd/warm-block-f64/call`, `cd/lasso-weighted/cd/dense-f32/call`, `cd/lasso-weighted/cd/dense-f64/call`, `cd/lasso-weighted/cd/sparse-f32/call`, `cd/lasso-weighted/cd/sparse-f64/call`, `gradient/lasso-weighted/apg/acc-dense-f64/call`, `gradient/lasso-weighted/pg/acc-dense-f64/call`

# Eligible timings, fresh series

Mean of the 10 repetition medians in µs, and the case's own 95% interval half-width as % of the mean. Only cases with a finite target and every run ok. Per-case intervals over repetitions, not cross-solver comparisons.

## Julia 1.10.13 (46 timed cases; half-width median 9.2%, range 1.0–63.2%)

| Configuration | lasso | lasso-B | lasso-C | lasso-D | lasso-weighted | group-lasso |
|---|---:|---:|---:|---:|---:|---:|
| apg acc-dense-f64 | 55 (±4%) | 1e+03 (±24%) | 1.33e+03 (±8%) | 1.72e+03 (±5%) | 58.5 (±8%) |  |
| apg acc-warm-dense-f64 |  | 847 (±43%) |  |  |  |  |
| apg dense-f64 |  | 1.02e+03 (±22%) | 1.36e+03 (±9%) | 1.72e+03 (±9%) |  |  |
| apg warm-dense-f64 |  | 751 (±31%) |  |  |  |  |
| cd block-f32 |  |  |  |  |  | 48.9 (±10%) |
| cd block-f64 |  |  |  |  |  | 64.6 (±10%) |
| cd dense-f32 | 7.85 (±6%) | 49 (±13%) | 79 (±1%) | 111 (±3%) | 8.17 (±7%) |  |
| cd dense-f64 | 10.2 (±5%) | 69.7 (±22%) | 109 (±2%) | 134 (±2%) | 11.2 (±10%) |  |
| cd sparse-f32 | 7.88 (±5%) | 48.5 (±13%) | 78.7 (±1%) | 111 (±3%) | 8.12 (±9%) |  |
| cd sparse-f64 | 10.4 (±5%) | 69.8 (±23%) | 108 (±2%) | 131 (±1%) | 11.1 (±9%) |  |
| cd warm-block-f32 |  |  |  |  |  | 43.2 (±10%) |
| cd warm-block-f64 |  |  |  |  |  | 57.1 (±10%) |
| cd warm-dense-f32 |  | 38.3 (±7%) |  |  |  |  |
| cd warm-dense-f64 |  | 55.5 (±16%) |  |  |  |  |
| cd warm-sparse-f32 |  | 39.2 (±7%) |  |  |  |  |
| cd warm-sparse-f64 |  | 55.7 (±15%) |  |  |  |  |
| pg acc-dense-f64 | 37.5 (±8%) | 1.45e+03 (±48%) | 1.16e+03 (±16%) | 1.37e+03 (±8%) | 39.8 (±13%) |  |
| pg acc-warm-dense-f64 |  | 1.04e+03 (±63%) |  |  |  |  |
| pg dense-f64 | 35.3 (±12%) |  | 1.05e+03 (±12%) |  |  |  |

## Julia 1.13.3 (46 timed cases; half-width median 8.5%, range 1.8–48.8%)

| Configuration | lasso | lasso-B | lasso-C | lasso-D | lasso-weighted | group-lasso |
|---|---:|---:|---:|---:|---:|---:|
| apg acc-dense-f64 | 50.2 (±4%) | 992 (±17%) | 1.4e+03 (±9%) | 1.61e+03 (±7%) | 50.8 (±5%) |  |
| apg acc-warm-dense-f64 |  | 888 (±27%) |  |  |  |  |
| apg dense-f64 | 52.8 (±6%) | 1.07e+03 (±15%) | 1.45e+03 (±12%) | 1.63e+03 (±8%) |  |  |
| cd block-f32 |  |  |  |  |  | 42.7 (±8%) |
| cd block-f64 |  |  |  |  |  | 61.5 (±9%) |
| cd dense-f32 | 5.3 (±6%) | 35.8 (±15%) | 44.8 (±2%) | 73.8 (±2%) | 5.89 (±8%) |  |
| cd dense-f64 | 7.7 (±5%) | 62.5 (±20%) | 89.6 (±4%) | 110 (±2%) | 8.88 (±12%) |  |
| cd sparse-f32 | 5.17 (±5%) | 35.4 (±15%) | 44.5 (±2%) | 73.5 (±2%) | 6 (±10%) |  |
| cd sparse-f64 | 7.75 (±5%) | 62 (±22%) | 89.1 (±4%) | 110 (±2%) | 8.92 (±12%) |  |
| cd warm-block-f32 |  |  |  |  |  | 36.4 (±7%) |
| cd warm-block-f64 |  |  |  |  |  | 54.5 (±7%) |
| cd warm-dense-f32 |  | 25.5 (±10%) |  |  |  |  |
| cd warm-dense-f64 |  | 47.5 (±17%) |  |  |  |  |
| cd warm-sparse-f32 |  | 25.2 (±10%) |  |  |  |  |
| cd warm-sparse-f64 |  | 47.7 (±18%) |  |  |  |  |
| pg acc-dense-f64 | 32.6 (±7%) | 1.62e+03 (±34%) | 1.22e+03 (±19%) | 1.4e+03 (±8%) | 33.9 (±15%) |  |
| pg acc-warm-dense-f64 |  | 1.25e+03 (±49%) |  |  |  |  |
| pg dense-f64 | 31 (±9%) |  |  | 1.36e+03 (±9%) |  |  |

