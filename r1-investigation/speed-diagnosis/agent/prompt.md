# Brief: ProximalSolvers.jl #353, R1 (square-root lasso), task D: the Julia 1.10 slowdown of the simplified fast path

A measurement and diagnosis task. You change no branch that will be merged; you work in a scratch worktree and
return findings, tables and (if you find one) a fast-path form that meets the gate, as a patch file.

## Background (local, read-only)
- `S0=<STAGE0-RUN>` (Stage 0 audit material).
  `$S0/report/part-C-r1.md`: recommendation R1 with its performance table. `$S0/experiments/x1/report.md` and
  `$S0/experiments/timing/` (`x1_paired.jl` whole solves, `x1_visit.jl` the read-only per-visit probe,
  `summarize.py`, `shrink_probe.jl`, `infer_check.jl`, `inline_check.jl`, the runs `x1-final-*` with `.tsv`,
  `.summary.txt`, `.load`): how the slowdown was measured.
- The prototypes are the worktrees `<WORK>/ps-353-x1a` … `ps-353-x1e` (each differs from the
  commit `dac9f4b` only in `src/cd/sqrtlasso.jl`; patches in `$S0/experiments/x1/*.patch`): `x1d` is the Stage 0
  recommended fast path (no band test; threshold `τ = (λ/ra)·(d/(√(ra−λ)·√(ra+λ)))` and the exported `shrink`);
  `x1a` keeps master's fast-path arithmetic (`prox_block`, band test) and changes only the out-of-line exits;
  `x1c`, `x1e` were timing diagnostics (a column `view` hypothesis, rejected).
- Measured in Stage 0 (prototype/master, paired, 15 rounds, A/A control within about ±3 %): Julia 1.13.4 parity
  or faster. Julia 1.10.13: solve to convergence at n = 30, p = 120, λ = 0.1 λmax slower by 5.9 % (Float32) and
  4.0 % (Float64) with `-C alderlake`, 12.6 % and 7.7 % with the default target (which is `goldmont`, without
  AVX, on this CPU); the per-visit probe up to +10.6 % (AVX2 target) and +14.6 % (default target; Float64,
  n = 400, p = 40). `x1a`, with master's arithmetic bit for bit, was within 4.3 % on solves but 0.5–25 % slower per
  visit. One contribution was identified: the exported `shrink` (max/min form) takes 4.9 ns in a dependent chain
  on 1.10 against 4.3 ns for the select form ProximalBase uses inside `prox_block`. The rest was not diagnosed.
- Maintainer ruling: "Fix the regression rather than accepting it. Investigate the specific source of the
  regression. Consider type stability, compiler specialization, arithmetic structure, unnecessary conversions,
  allocation behavior, and loss of fast-path optimization. Retain straightforward Float32/Float64 specialization
  when it materially improves performance, but avoid duplicating large numerical implementations. […] No
  reproducible slowdown exceeding 5% on ordinary paths is acceptable." And: effort is bounded; if no
  straightforward form preserves performance, master's fast path stays as it is.
- In parallel another agent builds candidate "K" in `ProximalSolvers.jl-issue353-r1`: **master's fast path kept
  byte for byte** (`_sqrt_minimizer`, `src/cd/sqrtlasso.jl` lines 178–198 at `bb20b6a`), with all three exits
  (lines 181, 190 and the band branch of 197) calling one `@noinline` cold function with the signature
  `(m, old, k)`. You do not edit that worktree.

## Questions to answer, in this order
1. **Does K's shape cost anything on the ordinary path?** In your scratch worktree make the minimal edit: in
   `_sqrt_minimizer` replace the band branch `_sqrt_band_step(c, ra, λ, Float64(d), 0)` by
   `_sqrt_offrange_step(m, old, k)` (the cold body is irrelevant for timing ordinary inputs, they never reach it;
   leave the other functions in place). Compare against the base with the paired harnesses below. Expected:
   parity. If it is not at parity, find out why before anything else (compare `code_native`/`code_llvm` of the
   compiled pass loop and of `coordinate_step!` between base and variant: what moved).
2. **Why were `x1d` and `x1a` slower on Julia 1.10?** Reproduce the two worst cells first (solve n = 30, p = 120,
   Float32, λ = 0.1 λmax; per-visit Float64 n = 400, p = 40), `x1d` and `x1a` against their base, on 1.10 with both
   targets. Then find the cause with evidence, not a guess: `@code_llvm`/`@code_native` of the specialized hot code
   on 1.10 and on 1.13 (instruction counts of `sqrt`, `div`, branches, calls; whether the `@simd` kernel
   `_column_dot_rsqr` still vectorizes and with which width; whether `_sqrt_step`/`_sqrt_minimizer`/`shrink`/
   `prox_block` are inlined; register spills around the cold call; the number of arguments and live values at the
   cold call sites), `@code_warntype`/inference of the changed functions, allocation counts. Vary one thing at a
   time (the Stage 0 diagnostics `x1c`/`x1e` are examples): the shrink form (exported `shrink` against a local
   select form `c > τ ? c − τ : (c < −τ ? c + τ : zero(c))` against `prox_block(m.gt, c, k, γ)`), the extra
   division (`(λ/ra)·(d/w)` has three divisions with `b/a`, master has two), the generic `_sqrt_step(m, X, r, λ, …)`
   with `_column` against a concrete method, the cold call's signature. State which factors explain how much of
   the measured gap.
3. **Is there a band-free fast path within the gate?** Only if question 2 points to one: a fast path without the
   band test (the simplification Stage 0 wanted, 9 lines shorter than master's) whose paired ratios against the
   base, on Julia 1.10 (both targets) and 1.13, stay inside the A/A control on every cell of both harnesses, or
   at least below 1.05 where the control is tight. It must keep the cold-call signature `(m, old, k)` and must not
   refuse or mis-handle anything (the band-free formula is safe only where `a` and `ρ²` pass `_clean_sum`; Stage 0
   showed `(λ/ra)·(d/w)` cannot overflow there). Note that a band-free formula changes the last bits of ordinary
   results (not bit-identical to master), which the candidate K avoids; so the bar for recommending it is a clear
   pass of the gate, not a marginal one. If none passes, say so: keeping master's fast path is then the result.

## How to measure
- Julia: `julia +lts` is 1.10.13, `julia +release` is 1.13.4. For the AVX2 target on 1.10 add `-C alderlake`.
- Paired and in process: base and variant(s) loaded as separate modules from source in one process (the Stage 0
  harnesses do this; copy them into your probes folder and replace their hard-coded tree paths), a second copy of
  the base as the A/A control, sides rotated over rounds, minimum over batches per round, median ratio over
  rounds, one BLAS thread, pinned to one performance core:
  `systemd-run --user --scope -q -p MemoryMax=10G -p MemorySwapMax=0 taskset -c 2 julia +lts --startup-file=no [-C alderlake] --project=<WORK>/ProximalSolvers.jl-issue353-r1-perf <harness> <out.tsv> <rounds>`
  Record `uptime` before and after each timing run. Other agents run tests on this machine at the same time (on
  other cores); a cell whose A/A control swings as widely as the cell is inconclusive: repeat it, and say so if it
  stays inconclusive. Use fewer rounds (5) while diagnosing and 15 for the tables you report. Each Bash call is a
  foreground call with a timeout of at most 600000 ms: restrict a run to the cells you need (the harnesses take
  the case list from their source; edit your copies) so that it fits, and split the final tables into several
  calls. Never start a detached job. One Julia process at a time from you.
- The base for every comparison is `bb20b6a36cc040f7f00088919e331dce27cf257b` (the read-only worktree
  `<WORK>/ProximalSolvers.jl-issue353-base`), not `dac9f4b`: `src/cd/sqrtlasso.jl` is the
  same file at both, so the Stage 0 patches apply. Build each variant as a copy of the `src` tree under
  `<WORK>/ProximalSolvers.jl-issue353-r1-perf/.codex-orchestrator/variants/<name>/src`
  (so several variants load in one process), not by editing tracked files.

## Worktree and limits
- Scratch worktree `<WORK>/ProximalSolvers.jl-issue353-r1-perf` (detached at the base).
  Everything you write goes under its `.codex-orchestrator/` (`probes/`, `variants/`, `out/`). Do not commit, push
  or edit tracked files anywhere. Do not touch the main checkout, `ProximalSolvers.jl-issue353`,
  `ProximalSolvers.jl-issue353-r1`, the base worktree or the `ps-353*` worktrees (reference only).
- No Pkg operation other than `Pkg.instantiate()` of the scratch worktree's project (on 1.13 there is no
  `Manifest.toml` yet). No dependency changes. No ProximalBase edits (if the exported `shrink` is the cause, the
  fix must be on the ProximalSolvers side; ProximalSolvers may call only exported or qualified-public
  ProximalBase names, not private ones such as `_shrink_nonneg`).
- Bounded effort: answer question 1 fully; spend on questions 2 and 3 what a focused investigation takes, and
  stop when either a cause is established or three distinct single-factor variants have failed to explain the gap;
  report what is and is not explained.

## Hand-back (your final message, returned as text; do not write it to a file)
Headings: Answer to question 1 (table: cell, Julia, target, ratio, A/A control, verdict); Answer to question 2
(the cause or causes, each with its evidence: the IR or assembly facts and the single-factor timing that
attributes it; what remains unexplained); Answer to question 3 (the recommended fast-path form as a patch against
`bb20b6a` saved under `.codex-orchestrator/out/`, with its full tables on 1.10 default target, 1.10 AVX2 target
and 1.13; or "none passes" with the tables of the best attempts); Load averages during the reported runs;
Files (scripts and outputs, by path); **Not run**; Open questions. End with `Status: COMPLETE` or
`Status: INCOMPLETE`.
