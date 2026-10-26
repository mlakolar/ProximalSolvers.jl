# Discovery results: reusable-state SLOPE hybrid

These are empirical results on bounded synthetic workloads. Use `SLOPEHybrid()` explicitly; screened APG remains the default.

The optimized hybrid uses reusable cluster state and an APG fallback with the existing stopping rules. The original prototype and its adverse results remain in the parent directory. See [the protocol](README.md) for fixtures, stopping targets, allocation scope, versions and recreation.

Coverage: 1,980 requested path fits across 220 workloads and three repetitions per method. 19,437 returned levels out of 19,440 requested. Every returned level has independent gap and full-residual records.

## Accuracy and retained failures

A fit passes the common targets only when every requested level has relative feasible dual gap <= 1e-6 and null-gradient-normalized fixed-point residual <= 1e-7. A profiled request additionally requires valid native allocation replay and unchanged inputs. Internal Julia stopping flags are stricter and are reported separately; native flags are unavailable.

| Method | Fits passing common accuracy / 660 | Valid profiled requests / 660 | Internal flag failures | Protocol failures | Returned levels |
|---|---:|---:|---:|---:|---:|
| apg | 660 | 660 | 6 | 0 | 6,480 |
| hybrid | 660 | 660 | 0 | 0 | 6,480 |
| libslope | 612 | 612 | unknown | 48 | 6,477 |

All failures and internal flags remain in `evidence/summary.json` and the raw TSVs. Native fits are bounded by a soft 10-second path cap. A native cap or replay failure is not evidence of inability to converge with more time. No speed claim is made for an uncertified pair.

## Paired time and Julia allocation ratios

Ratios are hybrid/APG or libslope/APG; below one favors that method. Each case uses the median of three randomized timing blocks. Every repetition of both methods must be a valid profiled request. Cases with false internal flags remain eligible if the common external target passes. Seeds 1–3 are main; 11–12 are confirmation.

| Cohort | Seeds | rho | Storage | Hybrid certified pairs | Hybrid time ratio | Hybrid wins | Hybrid Julia bytes ratio | Native certified pairs | Native time ratio |
|---|---|---:|---|---:|---:|---:|---:|---:|---:|
| larger | confirmation | 0 | dense | 4/4 | 1.015 | 1 | 0.991 | 4/4 | 1.636 |
| larger | confirmation | 0 | sparse | 4/4 | 1.053 | 1 | 1.216 | 4/4 | 1.404 |
| larger | confirmation | 0.9 | dense | 4/4 | 0.491 | 4 | 0.829 | 1/4 | 0.726 |
| larger | confirmation | 0.9 | sparse | 4/4 | 1.031 | 1 | 1.306 | 4/4 | 1.683 |
| larger | confirmation | 0.99 | dense | 4/4 | 0.322 | 4 | 0.359 | 2/4 | 1.066 |
| larger | confirmation | 0.99 | sparse | 4/4 | 1.074 | 0 | 1.151 | 2/4 | 8.048 |
| larger | main | 0 | dense | 6/6 | 0.919 | 4 | 1.011 | 6/6 | 1.378 |
| larger | main | 0 | sparse | 6/6 | 1.025 | 2 | 1.220 | 6/6 | 1.325 |
| larger | main | 0.9 | dense | 6/6 | 0.496 | 6 | 0.943 | 2/6 | 0.706 |
| larger | main | 0.9 | sparse | 6/6 | 0.942 | 3 | 1.355 | 6/6 | 1.536 |
| larger | main | 0.99 | dense | 6/6 | 0.462 | 6 | 0.468 | 4/6 | 1.285 |
| larger | main | 0.99 | sparse | 6/6 | 1.035 | 2 | 1.227 | 5/6 | 3.826 |
| original | confirmation | 0 | dense | 16/16 | 1.009 | 8 | 1.263 | 16/16 | 2.293 |
| original | confirmation | 0 | sparse | 16/16 | 0.919 | 9 | 1.543 | 16/16 | 2.104 |
| original | confirmation | 0.99 | dense | 16/16 | 0.715 | 16 | 0.632 | 16/16 | 2.737 |
| original | confirmation | 0.99 | sparse | 16/16 | 0.719 | 16 | 1.489 | 16/16 | 2.004 |
| original | main | 0 | dense | 24/24 | 1.039 | 12 | 1.313 | 24/24 | 2.676 |
| original | main | 0 | sparse | 24/24 | 1.037 | 11 | 1.443 | 24/24 | 2.270 |
| original | main | 0.99 | dense | 24/24 | 0.771 | 24 | 0.652 | 23/24 | 3.387 |
| original | main | 0.99 | sparse | 24/24 | 0.703 | 22 | 1.633 | 23/24 | 1.777 |

Overall paired summaries are descriptive across this fixture mix, not estimates for an application workload:

| Seeds | Comparator | Certified pairs | Median time ratio | Time wins | Median Julia byte ratio | Allocation wins |
|---|---|---:|---:|---:|---:|---:|
| main | hybrid | 132/132 | 0.803 | 92 | 1.240 | 37 |
| main | libslope | 123/132 | 2.000 | 16 | n/a | n/a |
| confirmation | hybrid | 88/88 | 0.792 | 60 | 1.239 | 23 |
| confirmation | libslope | 81/88 | 1.936 | 10 | n/a | n/a |

## Allocation traffic and process memory

Julia allocation bytes include output snapshots and bridge buffers. Native requested bytes/calls are from a separate instrumented replay of the unchanged pinned static library; allocations internal to dynamic libraries are outside that counter. These are cumulative requested bytes, not live memory. No native/Julia heap-byte ratio is asserted.

| Method | Median Julia MiB per valid request | Median wrapped native MiB requested | Median native allocation calls |
|---|---:|---:|---:|
| apg | 0.831 | n/a | n/a |
| hybrid | 1.222 | n/a | n/a |
| libslope | 0.039 | 66.474 | 108278 |

Peak RSS below includes startup, imports, compilation, fixture creation and a warm-up plus repeated fit in a separate process for each method. It is not solver workspace alone. Saved solutions are certified in a different process.

| Case | Method | Peak process MiB | Levels | Common accuracy | Native tolerance |
|---:|---|---:|---:|---|---|
| 1 | apg | 566.1 | 6 | true | n/a |
| 1 | hybrid | 584.1 | 6 | true | n/a |
| 1 | libslope | 552.6 | 6 | true | 1e-8 |
| 20 | apg | 565.6 | 12 | true | n/a |
| 20 | hybrid | 595.7 | 12 | true | n/a |
| 20 | libslope | 556.2 | 12 | true | 1e-8 |
| 169 | apg | 611.5 | 12 | true | n/a |
| 169 | hybrid | 615.9 | 12 | true | n/a |
| 169 | libslope | 560.0 | 12 | false | 1e-8 |
| 171 | apg | 551.8 | 12 | true | n/a |
| 171 | hybrid | 587.0 | 12 | true | n/a |
| 171 | libslope | 538.9 | 12 | false | 1e-8 |

The uniform native RSS followup used tolerance 1e-10 with the same 10-second soft cap. It did not make every native path accurate: tighter convergence work can hit the cap. These results supplement the original measurements and do not replace the primary timing/allocation data. Failed rows are not matched-accuracy memory comparisons.

| Case | Native peak process MiB | Levels | Common accuracy | Native tolerance |
|---:|---:|---:|---|---|
| 1 | 556.3 | 6 | true | 1e-10 |
| 20 | 562.1 | 12 | false | 1e-10 |
| 169 | 551.7 | 6 | false | 1e-10 |
| 171 | 534.3 | 12 | true | 1e-10 |

## Work and interpretation

Hybrid requests recorded 745,164 PG/APG steps, 360,480 complete cluster sweeps and 4,224 fallback events. These units have different costs and are summed across repairs and repetitions. They are not exact design-product counts.

Reusable state reduces the prototype's allocation burden, but it does not guarantee fewer bytes than APG on every case. The fallback limits wasted hybrid trials; it does not guarantee a speedup. Read the independent controls and confirmation rows as well as the strongly correlated rows. Selection remains explicit and problem-dependent.

This implementation specializes single-response least-squares SLOPE. It does not introduce a general cluster solver for other penalties or losses. Numerical certificates do not establish statistical FDR guarantees.

Validation, job IDs, source snapshots and the failed development attempts are recorded in `RUN.md`. Plain timing, level certificates, allocation replay diagnostics and memory outputs are retained in `evidence/`.
