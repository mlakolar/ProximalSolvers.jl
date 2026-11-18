# Evidence for issue #378 (research: stopping least-squares CD when the cached residual may be stale)

Research only; nothing here is for merge. Audited revision of ProximalSolvers.jl:
`8cc022222d3c90ef86a24ca0c957b02faaf4fc1f` (ProximalBase pin `a19c59aa723d085d5d7cf5242895bda16eb77214`).
All runs: a cluster (Slurm), Julia 1.13.4 and 1.10.13, AMD Zen 3 and Intel Skylake-SP (AVX-512) CPUs.
Placeholders such as `<RUN>` and `<WT>` replace local paths.

| directory | content |
|---|---|
| `plan/` | the pre-registered plan, as posted on the issue |
| `report/` | the report, as posted on the issue |
| `review/` | the three rounds of the independent review of the report, with the reviewer's probes and their output |
| `study/` | every script: `lib352.jl` (fixtures and 600-bit measures of #352), `lib378.jl` (designs, the recording wrapper model, statistics, truth), `sweep378.jl` and `driver.jl` (the sweep), `repro.jl` (hand-built cases), `make_protos.py` (prototypes A, R, F), `make_protos2.py` and `make_protos3.py` (prototype S, first and final build), `protolib*.jl`, `protosweep*.jl`, `protodriver*.jl` (outcome sweeps), `timing378*.jl` (paired timing), `proto_check*.jl`; analysis in Python (standard library): `analyze.py`, `rules2.py`, `rules3.py`, `proto_analyze.py`, `timing_summary.py`, `timing_pair.py`, viewers `tview.py`, `t2view.py` |
| `prototypes/` | the patches against the audited `src`: `A-R-F/`, `S-first-build/`, `S/` (final build, the one the report describes) |
| `tables/` | output of the analysis scripts. `sweep-<v>-<cpu>-tables.txt`: tables T0 to T3 of `analyze.py` (`r` = Julia 1.13.4, `l` = 1.10.13; `epyc` = Zen 3, `xeon` = Skylake-SP); `-rules2.txt`, `-rules3.txt`: further rules; `proto-r` = outcome sweep of A, R, F; `proto2-*` and `proto3-*` = outcome sweeps of S (first and final build); `pilot-r` = the fixtures only |
| `timing/` | raw output of the timing runs (`time-*` = A, R, F; `time2-*` = S, first build; `time3-*` = S, final build; `time3b-*` = the repetition of `time3-*`) and the summaries |
| `cases/` | output of the hand-built cases on master (`repro-release.txt`) and on the prototypes |
| `checksums/` | SHA-256 of every raw result file (`*.tsv.gz`, one row per solve) and of the code that produced them |

The raw rows (about 0.6 GB compressed: four sweeps of 1,667,350 solves, five outcome sweeps of 912,116 inputs) are not on
this branch; their checksums are, and every table here is the output of the archived scripts on them. They are kept with the
run's local records.

`SHA256SUMS` lists every file of this branch.
