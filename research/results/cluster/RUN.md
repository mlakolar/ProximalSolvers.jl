# #311 cluster run (Slurm)

- CPU: AMD EPYC 7513 (no AVX-512). Julia 1.10.12 and 1.13.3, one package depot per version.
- Trees, exported with `git archive`:

  | label | commit | change |
  |---|---|---|
  | M | eb3332f8674fb013b958cd1d02698258e14582c3 | master |
  | C50 | a7672d9bf71b5dd32963f23e1bc28006cc8a0847 | full pass after 50 active passes |
  | CW10 | 0e400796b9ff3b1b2c42ea0731ecc4216029361f | full pass after 10·p active visits |
  | CW20 | ea7dcb3de23e26f9efd318bd96175ae773b1f10a | full pass after 20·p active visits |
  | E | 9407ac34545bbb328e2fdc6eb4d6d69defd4d86c | switchable exploration build (Ref) |

- The bundle of trees and probes was checked on arrival against a SHA-256 manifest (0 failures).

## Main jobs (`cluster/run311.sh`)

- Exclusive nodes were requested first. Their queue estimate was 10–13 hours, over the 2-hour budget, so the jobs were cancelled and rerun on **shared nodes** (4 CPUs each).

  | job | Julia | wall | state |
  |---|---|---|---|
  | 14234353 | 1.10.12 | 9:35 | COMPLETED |
  | 14234354 | 1.13.3 | 9:07 | COMPLETED |

- Success checks passed on both versions: DONE, env.txt, 9 repro files, diag, 2 seed scans, 4 alloc files, timing.tsv (4200 lines), counts.tsv (1569 lines).
- Shared-node noise: the A/A (master against master) spread was ±6% per round on the 1.10.12 node and ±1% on the 1.13.3 node.

## Focused re-timing (`cluster/retime110.sh`)

- Job 14235222, Julia 1.10.12, shared node, each process pinned to one core.
- Ordinary designs only, 101 samples, 12 rotated rounds of M/C50/CW10/CW20/M2.
- Purpose: decide whether the +4.5% CW20 ordinary geomean of the main 1.10.12 run is reproducible. It was not: CW20 0.979 against A/A 0.978.
