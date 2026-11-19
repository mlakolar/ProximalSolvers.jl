# Independent review brief: #155 confirmation round (D2 vs PDHG), ProximalSolvers.jl

You are the independent reviewer of a RESEARCH-ONLY report about a fallback for square-root lasso coordinate descent
(CD) that stops at nonoptimal exact fits (#155). Nothing is implemented on the basis of this report without maintainer
approval. Check that the claims are correct and supported, that the experiment kept its preregistration, and that the
decision follows from the evidence. One review round only: report everything you find now.
Do not edit any file outside R/review/ (R below). Do not post to GitHub, commit or push.

## Paths
- R = <RUN>
- Drafts to review: R/report/report155_confirm.md (to be posted on #155) and R/report/xref156.md (short note for #156).
- Preregistration: R/protocol.md, hash in R/state.md (sha256 014d9adc…; hashed before any held-out problem was generated).
- Prototype (read-only): <PROTO>,
  diff `git -C <that path> diff eea50923 HEAD -- src` (src/cd/sqrtlasso.jl: δ in `_sqrt_minimizer` and
  `_sqrt_offrange_step`, stage stop in `_stop_check!`, P_up/P_lo/D_lo exposure in `_certify!`, `_fallback!` driver at the
  end of the file; src/cd/solver.jl hook in `_run_cd!`). `_certify!` carries the full rounding proof in its comment.
- Harness: R/scripts/lib.jl (generators, `solve_mode`, `cert_at`, `m1g_dual`, `pdhg_fallback`), R/scripts/vcert.jl
  (generalized validator from the first study), R/scripts/run_heldout.jl, gen_oracle.jl, oracle_lib.jl, summarize.py,
  detail.py, compare_versions.py, export_data.jl, oracle_to_text.jl.
- Raw results: R/out/heldout_all_113_*.tsv (main run, Julia 1.13.4), R/out/heldout_cross_110_*.tsv (1.10.13 rerun on
  the 1.13 data), R/out/cross110_firstattempt/ (discarded first 1.10 attempt), R/out/oracle/ (records), R/out/data/.
- Diagnostic: R/dev/diag_step.jl; smoke test R/dev/smoke.jl (development fixtures).
- Performance: R/perf/perf_ordinary.jl, perf_1.tsv, perf_2.tsv, summ_perf.py; R/perf/local2_{A1,A2,B1}.log (local.jl).
- First study (context only): https://github.com/mlakolar/ProximalSolvers.jl/issues/155#issuecomment-6992343537 and
  <WS>/ProximalSolvers.jl-runs/run-20261118-issue155-156/report/report155.md.
- Julia: `julia +release --project=R/env` (1.13.4, prototype dev'ed, PB pin, JuMP, Clarabel). Small checks are fine;
  write scratch files only under R/review/. Use `python3 -I` for the Python scripts.

## Check specifically
1. Safety of the prototype's return rule: can `_fallback!` ever report `converged = true` without a valid bound, return
   a changed point without P_up(new) < P_lo(x0), or leave the residual cache/objective inconsistent with the returned
   point (copyto!/initialize! after restoring x0)? Are the new P_up and P_lo in `_certify!` valid outward-rounded bounds
   under the existing proof's error model (including the r̂ = 0 case and the range-free N forms)? Is the bank (max of
   D_lo over stage points) a valid lower bound on P* for the ORIGINAL problem, given that the stage points come from
   the smoothed problem?
2. The smoothed step: the fast path (ρ² + δ², d² + δ²) and the off-range branch (scaling by max(M, δ), δs, hypot) — is
   it the minimizer of √(‖r_k − X_k z‖² + δ²) + λ|z|? Is δ = 0 bitwise the production step?
3. Protocol adherence: schedule (δ₀ = F̂(x0) with F̂ = P_up, δ_{j+1} = min(δ_j/5, best F̂), ≤ 8 stages + polish), budget
   min(maxpasses − base, max(2000, 20·base)) never reset, the PDHG definition and its ⌊B/2⌋ + polish split, the held-out
   seeds, the configurations, and the classes/false-certification definitions in run_heldout.jl. Anything changed after
   held-out results were seen? Are the documented deviations complete and harmless?
4. Fair comparison: same problems, budgets and return rule for D2 and PDHG; the work units (CD pass vs PDHG iteration);
   the claim that M1 and M1g are identical on all 599 triggered runs; the claim that PDHG needs the generalized validator.
5. Every number in report155_confirm.md and xref156.md against the TSVs (recompute broadly; flag anything untraceable).
6. The performance claims (prototype probe design, A/A, the local.jl run) and their stated limitations.
7. Whether the decision (GO D2, scoped as a bounded improvement fallback, with the listed limitations) follows from the
   evidence and the preregistered decision rule (protocol.md §5), and whether anything is overstated; whether NO-GO or
   GO PDHG would be better supported. The complexity estimate (prototype +111/−13; production 150–200 src lines).

## Output
Write R/review/review_r1.md with a first line `VERDICT: PASS` or `VERDICT: CHANGES REQUESTED`, then numbered findings,
each tagged BLOCKER (wrong or unsupported claim, safety/false-certification risk, mathematical error, protocol breach) or
NONBLOCKING/EDITORIAL, with file:line evidence and the exact correction you propose. Be precise and brief.
