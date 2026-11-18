# #155/#156 joint research run — state

- Started 2026-11-18. Research only (no production code, no PR).
- Worktree: <WS>/ProximalSolvers.jl-issue155 (detached at origin/master a0a06477).
- PB pin a19c59aa723d085d5d7cf5242895bda16eb77214. Julia 1.13.4 (release), 1.10.13 (lts).
- Research env: env/ (PS dev'ed from the worktree, PB at pin, JuMP 1.32.1, Clarabel 0.11.1, BenchmarkTools 1.8.0).

## Files
- scripts/phase1_repro.jl → out/phase1_113.txt, out/phase1_110.txt (fixtures reproduced; random-order #156 differs by unseeded RNG only)
- scripts/matrix.jl (preregistered matrix, 80 problems), scripts/oracle.jl → out/oracle.jls/.txt (160 records, widths ≤ 6.5e-8, 119 exact-fit optima)
- scripts/common.jl (helpers: ps_solve, certify_at = production `_certify!` at a point, classify)
- scripts/baseline.jl → out/baseline_1.13.tsv (948 runs: 184 certified, 683 nonoptimal(155), 81 missed-cert(156), 0 false certs; max certified excess 1.1e-10)
- scripts/orch_smooth_probe.jl → out/orch_smooth_probe.txt (orchestrator probe: augmented-data smoothing; F64 certifies all 15 probed, F32 escapes but never certifies)

## Agents
- A: certification (#156) → agents/A/
- B: escape (#155) → agents/B/
- C: counterexamples, 1.10, performance → agents/C/ (+ own worktree for perf prototypes)

## Supplementary: realistic λ (scripts/realistic.jl → out/realistic.tsv, 864 runs)
- BCW pivotal λ = 1.1 Φ⁻¹(1−0.05/(2p)) (unnormalized, ‖X_j‖ = √n), Gaussian/AR(0.5)/AR(0.9), s ∈ {5,20}, σ = 1, 4 (n,p) shapes, 3 seeds, cold start.
- λ and λ/2: 288/288 certified per type, no exact-fit optimum.
- λ/4: 120/144 per type have exact-fit optima, all 120 nonoptimal(155) (excess 8e-4 … 0.75, median 2.9e-2); 24 certified (no exact fit).

## Agent A done (record: agents/A/ORCHESTRATOR_NOTES.md). Agent B done (agents/B/report.md).
## Orchestrator rigorous re-check of B's D2 (scripts/orch_d2_rigorous.jl → out/orch_d2_rigorous.tsv)
- Exact-replay start points (A's final_points.jls), 764 triggered runs; dual bound from A's outward-rounded vcert (θ̂ = r̂ at stage point), P_up rigorous.
- F64: 386/386 certified (348 stage point, 38 returned x0 unchanged). F32: 318/378 certified (277 stage, 41 x0); 60 uncertified with honest ratio 1.04e-4..4.7e-4.
- 0 false certifications; every returned point has excess ≤ 1e-4 (both types).
- Passes F64 q50 232 / q90 8803 / max 89268; F32 178 / 5182 / 14104. Returned nnz > n: F64 41, F32 135.
