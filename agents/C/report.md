# Agent C report: counterexamples, independent oracles, Julia 1.10, performance feasibility

All paths under D = <RUN>/agents/C (scripts/, out/, proto/).
R = run dir. Julia 1.13.4 env = $R/env unless stated. Nothing here is production evidence; prototypes are research code.
Method of H in my harness: the production solver on augmented data [y; δ], [X; 0ᵀ] (scripts/lib.jl `smooth_stage`), stage points checked by a
BigFloat (256-bit) residual-direction dual D_lo and exact P(β) (stronger than the production Float64 certificate: any H failure here is not an
artefact of outward rounding). Variants: h0 = orchestrator's H (δ_j = 1e-2 P_stuck 10^-j, 10 stages); fix1 = δ_j = P_stuck 10^-j; trk1 = track
(δ_0 = P_stuck, δ_{j+1} = min(δ_j/10, P_best)); trkh = track with half-decade steps; all use production default stage tolerances and
maxpasses 20000 per stage; ratio = (P(best point) − best D_lo over all stages)/best D_lo ≤ 1e-4 (the "decoupled" rule of H).

## Findings

1. H is broken in Float64 (measured, reproducible). Every variant fails on the following:
   a. Small λ, noiseless p > n (SMALLLAM, scripts/hard.jl): n=40,p=120 (seed 11040) and n=100,p=400 (seed 11100), λ = 1e-3 λmax and 1e-4 λmax:
      0 of 4 Float64 problems certified by any of h0/fix1/trk1/trkh (and 0 in Float32); returned excess 0.4–1.0 (stuck point excess 0.85–1.3), 120k–240k passes (every stage hits the 20000-pass
      cap or stops on the change test far from the optimum). Probe (out/smalllam_probe*.txt via scripts/smalllam_probe*.jl): the plain solver from ZERO
      also stops at a dense exact fit (120 nonzeros, rrel 2e-16, excess 1.33) for tol 1e-7 … 0 and 200k passes; H with the stage change threshold tied
      to δ (κδ, κ = 1e-2…1e-6) and 200k passes per stage still stalls at excess 1.1e-2, nnz 44–46 (optimum has 40 basic nonzeros), 8 stages.
      So no schedule/tolerance change of H, within a 10^5-pass budget, repairs it. At λ = 1e-2 λmax H(c=1) certifies in Float64, h0 does not (excess 0.4–0.6, 120k passes).
   b. Natural (not constructed) cold-start problems: COR-n60p150, equicorrelated ρ=0.7, σ=1, k=4, λ = 0.05/0.2 λmax, seeds 20187–20191 (scripts/trigger_freq.jl
      case generator; out/trigger_fired_analysis_summary.txt). Base solver from 0: uncertified exact-fit stop (excess 1.4e-3 … 0.26, nnz 68–150 > n = 60).
      H(trk1, 16 stages): seeds 20187, 20188 certify but with 84 388 and 82 529 passes (base: 238, 171 passes); seeds 20189, 20190, 20191 are NOT certified
      in 16 stages (143 055, 138 108, 132 946 passes; returned excess 1.2e-4, 4.2e-5, 3.6e-5, so the point is good but the bound is missing). out/cor_probe.txt
      (seed 20190): even with 200k passes per stage the smoothed CD stops converging at δ ≲ 5e-4 P*, the dual error stalls at ~3e-4, best ratio only drops under 1e-4 after
      ~4·10^5 cumulative passes (ratio 3.97e-5 at δ = 1e-4 P*, passes 17k, 91k, 200k, 200k…): pass explosion (n=60, p=150!), ~250× the base solve.
   c. WIDE-n100p10000 (seed 13001, 0.1 λmax): h0 (c = 1e-2) does not certify (excess 4e-3 / 6e-3, 140k passes); fix1/trk1 (c = 1) certify in 5 stages (2.4–2.6k passes).
      Same for SMALLLAM at 0.01 λmax and CANCEL: a first stage at δ ≈ 1e-2 P_stuck (as in the orchestrator's probe) is much worse than one at δ ≈ P_stuck.
   d. LOWRANK-n30p60-s1 (seed 6001, singular values 1…1e-10): the stuck point is already optimal (P/P* = 1) but H needs 32 945 passes (4 stages, Float64) to certify;
      the base solve took 3 passes. Cheap certificates of the stuck point do not have this cost.
   e. Fixed schedule scale: with the stuck point 9e6 × P* (HUGE-n20p60, start = least-norm interpolant + 1e6 × nullspace vector), h0 needs all 10 stages (excess 9.9e-5, bound
      right at the limit) and would fail at 1e8 ×; track/adaptive needs 3 stages. P_stuck is a poor scale; the best objective found so far is the right one.
2. What H does NOT fail on in Float64 (so the hypothesis survives these): 114/114 on the first stress catalogue (scripts/stress.jl) for h0, and for fix1/trk1 on all of it: X=I_n (n = 50, 200, 1000,
   λ ∈ (1/√n, 1/√(n−1))), random orthogonal X, I + εG/√n, block-diagonal A155 (invertible X, #155 type), badly scaled columns, y scaled by 2^±40 and 2^±66, duplicated and 1e-8-perturbed
   duplicated columns, cancelling ±1e5 pairs, Vandermonde, λ ∈ {0.5, 0.99, 1.0, 1.01, 1.2} λc around the interpolation threshold λc (bisection with Clarabel), n=200,p=2000, near-exact fits.
   #156-type constructions with an infeasible least-norm support dual (hard2.jl `ex156b`, verified feasLN = false, feasible θ0 exists, n up to 200, |S| up to 100): all Float64 runs certify
   in 1–5 stages (h0 in 1–3). The returned point is never worse than the stuck point (by construction; 0 cases in all tables).
   Totals over stress+hard+hard2 (out/agg_variants.txt, 103 fired Float64 / 97 fired Float32 starts): Float64 certified h0 96, fix1 99, trk1 99, trkh 99 (of 103; the 4 misses are the SMALLLAM
   λ ≤ 1e-3 rows, plus WIDE/SMALLLAM-0.01 for h0); Float32 certified h0 60, fix1 89, trk1 89, trkh 90 (of 97).
3. Float32: why the orchestrator's probe never certified, and what does (out/f32_analysis_summary.txt, delta_curves.tsv; scripts/f32_analysis.jl, delta_curves.jl).
   - Dual error of the residual-direction witness at a Float32 stage point is proportional to the residual resolution: errD ≈ 0.3–0.5 · q, q = u32‖μ‖/‖r‖ (u32 = 2^-24,
     μ = |y| + |X||β| the row magnitudes), measured on 6 problems × 8 δ values (e.g. LARGE-n100p1000: q = 8.3e-4, 8.3e-3, 8.2e-2 → errD 1.4e-4, 2.9e-3, 2.9e-2 at δ/P* = 1e-2, 1e-3, 1e-4;
     ‖r_δ‖ ≈ 0.15 δ). The smoothed primal error is errP ≈ 0.13 δ/P* (needs δ ≲ 7e-4 P* for 1e-4). Both cannot hold at the same point: with q = u32‖μ‖/(0.15 δ), 1e-4 needs δ ≳ 1e3 u32 ‖μ‖ ≈ 6e-5‖μ‖
     while the primal needs δ ≲ 1e-3 P* ≲ 1e-3‖μ‖; they overlap only barely, and the orchestrator's schedule (δ_0 = 1e-2 P_stuck, then smaller) samples only the noisy side. No same-point Float32 certificate near an exact-fit optimum is realistic.
   - Decoupling fixes most cases: D from a LARGE-δ stage (δ ≈ 0.1–10 P*: ‖r‖ ≫ rounding noise; errD 4e-7…3e-6 on the 6 problems), P from a small-δ stage. With the first stage at δ ≈ P_stuck (fix1/trk1) Float32
     certifies 89–90/97 (h0 60/97). Risk: at large δ the support can be wrong (LAMC0.5-n10p30-s1: errD 0.34 at δ = 10 P*), so the grid must also contain δ ≈ P*, and the best D is taken over all stages.
   - Float64 witness (research only): the same δ chain on Float64 copies of the Float32 data gives errD ≤ 1e-4 down to δ ≈ 1e-6 P* in all 6 problems (e.g. 6e-8…2e-5), and (Float32-rounded Float64 point, Float64 D)
     certifies at δ = 1e-4 P*: ratios 1.4e-5, 1.5e-5, 8.1e-6, 1.4e-5, 1.3e-5, 2.9e-5. The cost is a Float64 copy of X (or on-the-fly conversion) plus a second solve; it is not needed when the decoupled Float32 rule works.
   - Float32 limits that remain: NONEXACT-n20p60-s2 (seed 9502, 0.3 λmax, optimum with |S| = n = 20): best ratio ≈ 1.06e-4 (errD floor ≈ 1e-4, errP < 1e-5) for every schedule up to 28 half-decade stages; c=1 variants
     certify 50/51 Float32 starts of the first catalogue. Uncertified Float32 H returns the lowest-P point of the chain, typically a dense one (nnz = p for δ ≲ 1e-6 P*; e.g. 265 nonzeros, n = 100) with true excess 1e-6…1e-5:
     optimal but dense and uncertified. A "return the sparsest point within noise" rule would be needed.
4. Near-exact fits, floor vs exact (out/floor_confusion.txt, from the shared baseline): among the 683+81 uncertified baseline runs, Float32: 335 nonoptimal and 37 optimal points have the residual at the rounding floor with the SAME
   distribution (median ‖r‖/‖y‖ 9.7e-8 vs 9.2e-8; 331/34 are `:failed`, 4/3 `:undefined`); Float64: 130 nonoptimal vs 3 optimal at the floor (rrel median 2.3e-16 for nonoptimal; the 3 optimal ones are exact zeros). So residual size cannot be used
   to decide "this is an optimal exact fit": a residual-at-floor test would accept the 335 nonoptimal Float32 points. The production certificate is rigorous at the true Float32 residual (0 false certificates), which is why only an actual dual witness helps.
5. Trigger safety and cost (out/trigger_freq.tsv, trigger_fired_analysis_summary.txt; scripts/trigger_freq.jl, trigger_analysis.jl). 780 cold-start solves on ordinary-looking problems (n>p σ ∈ {0.1, 1}, λ/λmax 0.02…0.6;
   noisy p>n 0.3…0.9; correlated ρ ∈ {.5,.9,.7}), cyclic and random order, Float64/Float32: 30 stops with `_stop_check!` → :uncertified (3.8%) and 1 capped run. By class: n>p Float64 0/240; n>p Float32 7/240, all at λ = 0.02 λmax, σ = 0.1
   (r* ≠ 0, 2% of ‖y‖; stuck excess 5e-12…4e-11, i.e. already optimal): the trigger fires UNNECESSARILY there (Float32 certificate floor) and H, fix1/trk1, then certifies in 4–5 stages in 3 of 5 problems, never in 2 (16 stages), at 52–96 extra passes
   (vs 27–73 base), returned excess unchanged (≤ 2e-11); harmless but wasted work. The other 23 fires are genuine exact-fit stops (noisy p>n at 0.3 λmax, correlated p>n). The trigger itself costs nothing: it is the `converged = false, uncertified = true`
   flag already computed by `_stop_check!`; with the fallback as a separate function after `_run_cd!` the ordinary path does no extra work.
6. Fallback cost with the δ in the coordinate step (prototype proto/fb, scripts/fallback_cost.jl, out/fallback_cost.txt; NOT production evidence), noiseless n × p from 20×80 up to 500×2000, lnfit start (base 1–3 passes), track c=1 decade schedule:
   stages 5 (Float64 and most Float32), passes 35–99 (13 k for n=20,p=80), total stage-solve time 0.1–3.7 ms (vs base 0.03–3.2 ms), certificate time 0.03–0.6 ms per 5 stages, allocation 0.04–0.37 MB per fallback (O(n+p) state; the augmented-data
   method I used for the stress tables copies X every stage: +3–8 MB per stage at n = 200–500, p = 2000, so a production fallback must use the in-step δ). Buffers can be created lazily at the first stage (SparseIterate, residual and curvature caches, stage state, certificate vectors are already allocated by `_prepare!`); the
   δ-field model needs no extra buffers. The expensive cases are those of Finding 1 (10^5 passes, ~0.1–0.3 s at n=60–100; scales with n·p per pass), so a pass budget for the fallback (a few ×10^3 total) would turn them into honest uncertified returns.
7. Performance of the ordinary square-root path (PROTOTYPE timings, not production benchmark evidence; scripts/perf_ordinary.jl, out/perf_ordinary_summary.txt). One process, 6 compiled copies (old×2, (i)×2, (ii)×2; proto/{old,ctl,v1,v2}), random interleaved order per repetition,
   whole `solve!` timings in loops of K solves (≥ 30 ms each), 2 processes pinned to different cores × 40 repetitions, CPU i5-13600K (hybrid; other agents were running concurrently, hence the wide min/max). Ratios = variant/mean(old, ctl) of the same repetition, medians over 80:
   (i) runtime field `ρ2 += m.δ2` (+1 load/add per step, `d2 += δ2` only in the rare recompute branch): 0.985–1.005; (ii) Bool type parameter on `SqrtLSModel`, `_smooth` is the identity for `false`: 0.994–1.006; A/A (ctl/old): 0.992–1.007; copy-to-copy spread 0.995–1.010.
   Cells: n60p20, n200p50, n1000p200 (ordinary, certified) and n200p600 at 0.5 λmax (p > n, optimum not an exact fit), × Float64/Float32 × cyclic/default (random order, momentum). IQRs ±1–3%. No cell is ≥ 5% slower; two Float32 default cells show (i) 1.2–1.5% FASTER (code placement, not
   claimed). Not measured: the single-step kernel, the step on other CPUs, the Float32 offrange branch with δ. Old, (i), (ii) produce bitwise identical results and pass counts at δ = 0 (scripts/perf_sanity.jl). LS path: the only edited file is src/cd/sqrtlasso.jl (diff proto/variant_i.diff,
   variant_ii_vs_pristine.diff; leastsquares.jl untouched); LS CD solve n200p50 over the 6 copies: ratios 0.996–0.998, IQR ≤ ±1.1% (out/perf_ls.txt). Caveats: the prototype's off-range step (`_sqrt_offrange_step`) ignores δ; r = 0 in the clean path is handled (ρ² = δ²), but exact tiny-scale handling of δ² and a
   stage-specific stop rule were not designed.
8. Alternatives that fail (measured/analytic):
   - Restart from zero: the shared baseline's :zero starts end uncertified at nonoptimal exact fits in 200/320 runs (62%; 40 more missed certificates, 80 certified); SMALLLAM from zero stalls too (finding 1a). So "restart from zero" is no escape.
   - Bounded k-coordinate block moves: X = I_n, y = 1, λ ∈ (1/√n, 1/√(n−1)), start β = 1: a block of k coordinates has directional derivative √k − λk ≥ 0 unless k > 1/λ², i.e. k = n (analytic; ID50/ID200/ID1000 in out/stress2_*). For non-orthogonal X (I + εG/√n, ORTH, ILLINV) only the
     analytic condition λ > 1/√(1ᵀG_T⁻¹1) (G_T Gram of the block) was derived; the minimal block size on PERT was NOT computed. Null-space (circuit) moves need |T| = n+1 columns, so any bounded k < n fails on the AI3/ID family and on n = 8 matrix problems (14–20 nonzeros > n).
   - Nullspace-only moves: invertible X (BLK155, A155-type with m = 10, 50 and ILLINV) has a trivial nullspace; H and CD smoothing handle BLK155 in 1 stage, nullspace methods cannot.
   - Least-norm support certificates: 8 random #156-type problems (n 10…200, |S| 3…100) built with an infeasible least-norm dual and a feasible θ0 (verified): the least-norm certificate cannot certify them (by construction), H certifies the Float64 ones.
9. Agent A's Bcm (agents/A/lib.jl `cand_Bcm` + `vcert`) attacked on 200 uncertified stuck points of my three catalogues (scripts/try_bcm.jl, out/try_bcm.tsv, try_bcm_summary.txt): 0 false certifications in 152 nonoptimal stuck points (also checked
   against BigFloat `bigcert` and the Clarabel oracle); certifies 44/48 optimal stuck points. Misses: LOWRANK-n30p60 (κ(X)=1e10, ratios 0.018, 0.024, status ok: the projection/ridge loses the dual), and F156-n50p200k10-16004 Float32 (|S| = 62 > n = 50, past the gate). Cost: ungated Cholesky of the |S|×|S| Gram
   at a dense stuck point costs 6.1 s at |S| = p = 10 000 (WIDE), 0.17 s at |S| = 2000 (n=200), 0.07–0.08 s at |S| = 1000; the |S| ≤ n gate must come before the factorization. At optimum-type points (|S| ≤ n) calls took ≤ 0.1 ms in my tables.

## Independent oracle and baseline checks (tasks 2 and 3)

- Oracle records (scripts/verify_oracle.jl, out/verify_oracle.txt), 512-bit BigFloat re-derivation of D from the stored θ and U = P(β*) for all 160 records: 0 weak-duality violations; the stored (Float64-rounded) D differs from the exact D by at most
  1.6e-16 relative (stored D can sit above the exact bound by that much, irrelevant at 1e-4); max (U − D)/D = 6.5e-8. Different formulation (β = β⁺ − β⁻, tolerances 1e-14, no equilibration) on 44 records: max (P(β_alt) − D)/D = 2.5e-7 and never below D. So the oracle sandwich P* ∈ [D, U] is proved
  for every record, independently of Clarabel's status strings.
- Baseline re-run on 1.13 and re-judged in BigFloat (scripts/baseline_verify.jl, out/baseline_verify_1.13.tsv): identical 948 class labels (184 certified, 683 nonoptimal, 81 missed); 0 false certifications; max certified excess 1.1e-10; the reported certified bound refuted in 0 runs (test: (P − U)/U ≤ gap with U = P(β*) ≥ P*; the first version of this check compared with D and flagged 8
  A155/AI3 β = 0 runs by the oracle width 1.6e-12 vs gap 4e-16, a check artefact, now corrected).
- Julia 1.10.13 (scripts/export_for110.jl exports X, y, λ, D, U and the exact start vectors from 1.13; scripts/baseline_110.jl runs under `julia +lts --project=…issue155`; out/baseline_1.10.tsv): classes 185 certified / 686 nonoptimal / 77 missed (1.13: 184 / 683 / 81). cyclic-dense: identical (92/348/34) and 0 false certification, max
  certified excess 1.1e-10. All 17 label differences are random-owner runs. Per the orchestrator's correction: my runner builds `Xoshiro(7)` ONCE in CONFIGS and shares it across the runs in the same loop order as baseline.jl (my own 1.13 replay of that loop reproduces all 948 labels). The remaining 1.10/1.13 difference is the RNG itself:
  `rand(Xoshiro(7), n)` is identical, `randperm`/`shuffle!` differ between 1.10.13 ([6,5,8,7,4,2,3,1] vs [4,8,7,2,5,6,3,1] for n=8; scripts/rng_check.jl), and the solver shuffles the visit order.

## Limitations and open questions
- My certificate for H is the BigFloat residual-direction dual (not the production Float64 `_certify!` with outward rounding); where production `certify_at` was also called (stress_H stage logs) it was never more favorable. The stage solver is the production CD on augmented data with default tolerance semantics (relative to ‖ỹ‖);
  a δ-aware stopping rule might change Finding 1b/1c quantitatively but not 1a (tested with κδ).
- Failure catalogue is by construction/search, not a proof; H also was not tried with Anderson/momentum for the stage solver.
- PERT block-size computation, Float32 `_sqrt_offrange_step` with δ, and tiny-scale/overflow behaviour of δ² in production were not studied. Perf timings were taken while other agents were running (A/A ±0.7%, IQR ±1–3%).
- Worktree (detached a0a06477, uncommitted variant (ii) edits in src/cd/sqrtlasso.jl): <WS>/ProximalSolvers.jl-issue155-C. Not deleted; remove with `git worktree remove --force`. Source copies of every variant: D/proto/{old,ctl,v1,v2,fb}/src.
