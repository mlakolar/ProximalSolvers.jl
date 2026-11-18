# Independent review brief (round 1): #155/#156 joint research report, ProximalSolvers.jl

You are the independent reviewer of a RESEARCH-ONLY report about square-root lasso coordinate descent at exact fits in
ProximalSolvers.jl (PS). Nothing will be implemented on the basis of this report without maintainer approval; your job is
to check that what the report claims is correct, supported by the evidence, and that the proposed scope is sound.
Do not edit any file outside <RUN>/review/.
Do not post anything to GitHub, do not commit or push.

## What to review
- R = <RUN>
- The two draft comments: $R/report/report155.md (integrated report for #155) and $R/report/summary156.md (focused #156 summary).
- Code under study (read-only): <WS>/ProximalSolvers.jl-issue155 (PS master a0a06477): src/cd/sqrtlasso.jl
  (coordinate step, `_stop_check!`, `_certify!` with its proof comment), src/cd/solver.jl, test/sqrt_lasso.jl,
  examples/problems/square_root_lasso.jl. Historical machinery: `git -C <WS>/ProximalSolvers.jl show origin/legacy/full:src/cd/sqrtdual.jl`.
- Evidence: $R/state.md (index), $R/scripts/ (matrix, oracle, baseline, realistic, orch_* checks), $R/out/ (raw TSV/text),
  $R/agents/A (certificates; lib.jl contains `vcert`, the generalized Float64 validator, and `cand_Bcm`; agents/A/ORCHESTRATOR_NOTES.md
  summarizes A's report), $R/agents/B/report.md + escape.jl (escapes), $R/agents/C/report.md (counterexamples, Float32, perf).
- Julia: `julia --project=$R/env` (1.13.4, PS dev'ed, PB at pin, JuMP, Clarabel). You may run small checks; write any
  scratch files only under $R/review/. Julia may need to write its compile cache under ~/.julia.

## Check specifically
1. False-certification risks: is every "certified" claim backed by a rigorous bound? In particular audit `vcert`
   ($R/agents/A/lib.jl lines 14–70) against the error model in the `_certify!` comment of src/cd/sqrtlasso.jl: outward
   rounding of every step, t without a cap at 1, D_lo = max(P_lo − gap, t·(θ̂ᵀy)_lo), ratio = min(gap/D_lo, (P_up − D_lo)/D_lo),
   the relaxed N_up range condition. Also `Pup` in $R/scripts/orch_d2_lib.jl and orch_d2_rigorous.jl (the orchestrator's
   rigorous re-check of the D2 escape): is the transfer certificate (P_up(x₀) − D_bank)/D_bank sound?
2. Whether the proposed witness really satisfies the dual constraints (‖tθ̂‖ ≤ 1, ‖Xᵀtθ̂‖∞ ≤ λ, λ bracketed).
3. Whether the escape can fail to decrease the ORIGINAL objective, and whether the return rule can return a worse point
   (note orch_d2_rigorous.jl's uncertified fallback compares upper bounds `Pb < P0`, which the report should describe correctly).
4. Mathematical claims in §2 of report155.md (optimality at r = 0, solvability of support equations, the λ-threshold claim,
   coordinatewise-minimum characterization, the minimum-norm/directional-lasso duality and its sign, F'(β;d*) formula,
   the X = I_n block counterexample and ⌊1/λ²⌋+1, the smoothing facts F ≤ F_δ ≤ F + δ, θ_δ feasibility, F(β_δ) − θ_δᵀy ≤ δ,
   and the claim that only d² → d² + δ² changes in the step).
5. Numerical assumptions around r = 0, and Float32 vs Float64 accuracy claims (rounding floor, "61% of the budget",
   the decoupled-δ explanation, floor confusion 335 vs 37).
6. Every number in the two drafts against the evidence files (spot-check broadly; flag any number you cannot trace).
7. Complexity relative to the historical machinery; the ~100–130 line estimate; the performance claims (prototype, not production).
8. Whether simpler alternatives were overlooked (for #155 and for #156), and whether the decisions (#156 DOCUMENT ONLY,
   #155 RESEARCH FURTHER with a preregistered confirmation round) follow from the evidence. Is anything overstated?

## Output
Write your review to $R/review/review_r1.md with a header line `VERDICT: PASS` or `VERDICT: CHANGES REQUESTED`, then
numbered findings, each tagged BLOCKER (wrong or unsupported claim, false-certification risk, mathematical error) or
NONBLOCKING/EDITORIAL, with file:line evidence and the exact correction you propose. Do not add new explanations that are
not needed; be precise.
