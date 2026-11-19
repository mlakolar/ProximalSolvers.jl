# Evidence: ProximalSolvers.jl #155 confirmation round (2026-11-18/19)

Research only. PS master eea50923; prototype = prototype.diff on top of it (not for merge); PB pin a19c59aa;
Julia 1.13.4 (main run) and 1.10.13 (cross-check); x86-64 Linux desktop.
Paths are scrubbed: <RUN> = this directory, <PROTO> = the prototype checkout (eea50923 + prototype.diff),
<WS>/<DEPOT>/<HOME>/<LOCAL>/<TMP> = local machine paths.
- protocol.md: preregistration (sha256 in state.md, hashed before any held-out problem was generated).
- report/: report155_confirm.md (posted on #155), xref156.md (posted on #156).
- scripts/: lib.jl (generators, solves, PDHG), vcert.jl, run_heldout.jl, gen_oracle.jl, oracle_lib.jl, summaries.
- out/: heldout_all_113_*.tsv (main run), heldout_cross_110_*.tsv (1.10 rerun on the 1.13 data),
  cross110_firstattempt/ (discarded attempt, see Deviations), oracle/*.txt (exact text oracle records),
  datahash_{113,110}.txt (problem-data hashes per version).
- dev/: fixture smoke test and the smoothed-step diagnostic.
- perf/: in-process ordinary-path probe (perf_ordinary.jl, perf_{1,2}.tsv) and local.jl logs.
- review/: Codex brief and review.
Omitted: out/data/*.bin (bitwise problem dumps, 49 MB; regenerate with scripts/export_data.jl on Julia 1.13.4,
check against out/datahash_113.txt) and the Julia-1.13-serialized oracle .jls files (out/oracle/*.txt are exact copies).
Limitations: prototypes and timings are research measurements, not production benchmark evidence.
