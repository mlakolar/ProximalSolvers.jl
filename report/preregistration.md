# #320 Stage 2 preregistration (fixed before the Discovery runs, 2026-11-21)

Base: ProximalSolvers master `49d0242e` (after #510), ProximalBase as pinned by its manifests.
Research only: no src/ change; the evaluator lives in `scripts/gapeval.jl`.

## Populations
- Designs: the five harness designs (`lasso`, `lasso-B`, `lasso-B-warm`, `lasso-C`, `lasso-D`) and the
  seven Phase 0 adverse designs (`adv-cor-low-{cold,warm}`, `adv-equi-low-cold`, `adv-ill-mid-cold`,
  `adv-ill-low-{cold,warm}`, `adv-wide-low-cold`), draws 1–10, built by the harness exactly as in
  Phase 0 (`scripts/s2common.jl`).
- Arms: Float32 PGD (primary), Float32 APG and Float64 PGD (controls).
- Julia 1.10.13 and 1.13.x; one Julia thread, one BLAS thread.

## Accuracy (s2traj accuracy.tsv, s2degen)
- Reference: BigFloat(256) relative gap at the STOP-13 dual point on the same rounded inputs.
- Statistic: relative error |W1 − big| / big over all BigFloat-evaluated iterates, reported as maximum
  and 99th percentile, separately for iterates whose big gap is within a factor 3 of the target.
  Same for the P−D form, W2 and the rounded-product comparator R32; plus the fraction of iterates
  where R32 underestimates big by more than a factor 2 (Phase 0's measure).
- Degenerate cases: the s2degen list; pass = W1 status and value agree with BigFloat (relative
  error ≤ 1e-10 where the big gap is positive; exact 0 where it is 0).

## Hypothetical stopping (s2traj rules.tsv)
- Rules R1, R10, RK, R1i, RKi at the target tol (1e-5 Float32, 1e-8 Float64), R1 and RK also at
  10·tol and tol/10, as defined in `scripts/s2traj.jl`; H = the current library solve with
  `benchmark_options(residual = true)`.
- Per rule and population: success count, false successes (success with big gap > gaptol),
  nonconverged outcomes (maxiter, stalled, objective increase), median stop iteration minus the
  first iterate whose harness Float64 certificate meets tol (k*), and number of gap evaluations.
- Compared with H: H false successes (converged with big gap > tol) and truthful misses.

## Cost (s2time)
- Float32 PGD, the five harness designs plus `adv-ill-low-cold` and `adv-wide-low-cold`, draws 1–5.
- Statistic: per-problem minimum over 11 rotating rounds; reported ratios W1/G32 (cost of one
  evaluation in gradient-product units) and W1/H (one evaluation as a fraction of a full current
  solve), median and range over problems; allocation per call after warm-up.
- A/A controls: Haa/H and W1aa/W1; the timing is accepted as informative when the median A/A ratio
  is within 0.98–1.02 (otherwise reported with that caveat).
- Projected overhead of a rule = (number of gap evaluations) × W1 / (H solve time), from the same
  problem's s2time row (draws 1–5 only).
