# Evidence archive: ProximalSolvers.jl #155/#156 joint exact-fit research (2026-11-18)

Research only. PS master a0a06477, PB pin a19c59aa, Julia 1.13.4 and 1.10.13, x86-64 Linux.
Paths are scrubbed: <RUN> = the run directory (this tree), <WS> = the local workspace holding the PS worktree
(`<WS>/ProximalSolvers.jl-issue155` = PS at a0a06477), <DEPOT>/<HOME>/<TMP>/<MEMORY> = local machine paths.
- report/: the posted comments (report155.md on #155, summary156.md on #156).
- scripts/: preregistered matrix (matrix.jl), oracle (oracle.jl), baseline, realistic-λ study, orchestrator checks
  (orch_d2_rigorous.jl, orch_d2_lib.jl, orch_check_cor.jl, orch_d2_cor.jl, orch_smooth_probe.jl).
- out/: raw outputs (oracle.txt, baseline_1.13.tsv, realistic.tsv, orch_d2_rigorous.tsv, ...).
- agents/A (certificates, `vcert` validator and `cand_Bcm` in lib.jl), agents/B (escapes, report.md), agents/C (counterexamples,
  Float32 analysis, Julia 1.10 baseline, performance prototypes as diffs).
- review/: independent Codex review briefs and reviews.
- env/: Project.toml + Manifest.toml of the research environment (JuMP/Clarabel are offline oracles only).
Binary problem dumps (*.jls) other than agents/A/final_points.jls are omitted; the scripts regenerate them from fixed seeds.
Limitations: prototypes and timings are research code, not production benchmark evidence; see the report.
