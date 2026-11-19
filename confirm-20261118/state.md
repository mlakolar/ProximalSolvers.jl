# #155 confirmation round — state

- Started 2026-11-18 (local), research only.
- Worktree: ProximalSolvers.jl/.claude/worktrees/research-155-confirm (branch worktree-research-155-confirm, base eea50923).
- Protocol: protocol.md sha256 014d9adca3acb07d56a71c6d7ec7740373d3244e03ef83115fd0221bfd9e7266, hashed 2026-11-19T00:04:31Z, before any held-out problem was generated.
- Prototype commit f06dfaf0 (worktree branch). Package tests: only assertions of today's uncertified exact-fit behaviour fail (sqrt_lasso 408/409/415/416, 587, 825; scaled_lasso 310/311); sparse_cd, core_regressions, cd_numerics pass.
- Oracle: 214 records, max width 1.1e-7 (all resolved).
- Main run (1.13.4, 16 workers): out/heldout_all_113_*.tsv, 3148 rows, 752 base solves, 599 triggered (583 held-out).
- Diagnostic (not evaluation): dev/diag_step.jl smoothed step vs BigFloat, worst 0.37 eps(T) over 8000 cases.
- DEVIATION (cross-check harness only): first 1.10 attempt regenerated data under 1.10; 102/107 problems differ bitwise from the 1.13 data (BLAS/RNG), giving negative "excess" vs the 1.13 oracle on NE-s9402. Moved to out/cross110_firstattempt/. Rerun with the 1.13 data exported bitwise (scripts/export_data.jl, out/data/) and oracle as exact text (scripts/oracle_to_text.jl). Rerun: classes 400/400 equal, work equal 353/400.
- Perf (i5-13600K, idle): sqrt-lasso cases are deferred in the formal harness (local.jl refuses them). (a) In-process interleaved probe perf/perf_ordinary.jl (first-study design; old/ctl master, new/newb prototype; 2 processes x 30 reps; 4 sqrt + 1 LS problems x 2 T x 2 cfg): prototype ratios 0.984-1.014, A/A 0.985-1.026, 0 flagged; work identical. (b) local.jl on cd/lasso, cd/lasso-B, cd/group-lasso (16 cases), order A1(save), A2(A/A), B1: B/A median 0.944-1.010, A/A 0.938-1.196.
- Report: report/report155_confirm.md (GO D2, scoped), report/xref156.md.
- Codex r1 (gpt-6.1-sol high): CHANGES REQUESTED, 6 blocking + 3 editorial; all addressed. Prototype defects (y=0 stale bounds; P_up overflow -> δ=Inf exception) fixed in 9e264a65, verified with review/edge_probes.jl (review/edge_probes_after_fix.log); no held-out effect. Matvec counts disclosed as deviation. No r2 (policy).
