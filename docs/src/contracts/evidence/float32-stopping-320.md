# Float32 PGD and APG stopping: measurements

This page records the measurements behind [STOP-18](@ref), [STOP-19](@ref) and [STOP-20](@ref) (issue
[#320](https://github.com/mlakolar/ProximalSolvers.jl/issues/320)). They are observations at stated revisions, not
solver guarantees.

## [evidence-float32-stopping-320 Study and provenance](@id evidence-float32-stopping-320)

**Statement.** The Phase 0 study of #320 ran Float32 PGD, with Float64 PGD and Float32 APG as controls, at ProximalSolvers `637f06a`, `9f86a80` and `dac9f4b` on Julia 1.10.13 and 1.13.3 (Intel Xeon E5-2640 v4 and Xeon Silver 4116). The designs were the five harness designs `lasso`, `lasso-B` (cold and warm), `lasso-C` and `lasso-D` at `λ = 0.15 λmax`, and an adverse set of seven correlated, equicorrelated, ill-conditioned and wide designs, six of them at `λ = 0.02 λmax`. Each design had 10 draws. Independent gaps and KKT residuals were evaluated in Float64 on the rounded inputs; for the library-run matrix records they were also checked in 256-bit BigFloat. The scripts, preregistration, per-solve summaries and the report are on the branch [`archive/issue-320-evidence`](https://github.com/mlakolar/ProximalSolvers.jl/tree/fb8fb87d2d017b0b4b6a14050697b0f05d8cccd9) at `fb8fb87d`; the report is the [Phase 0 comment](https://github.com/mlakolar/ProximalSolvers.jl/issues/320#issuecomment-6967100343).

- **Exits under the harness options.** In the 240 Float32 PGD records at `dac9f4b` on the Xeon E5-2640 v4 (harness and adverse designs, both Julia versions), the objective test made the first stop proposal in 237 records; no proposal was made in the other 3. All 156 objective-increase exits were rises of one to three Float32 spacings of `F`, 142 of exactly one. The Xeon Silver 4116 rerun had 157 objective-increase exits. These exits form the [STOP-18](@ref) objective-increase class; the flag records only the sign of the change, and the relative size is in `f_residual`.
- **Computed-KKT convergence and the gap.** Under the harness options, on the Xeon E5-2640 v4 and across the three revisions, each of the 231 Float32 PGD records with `converged = true` had an independent normalized KKT residual below `64 eps(Float32) ≈ 7.63e-6`. Among those that missed the `1e-5` target, the ratio of gap to normalized KKT residual was 2.3 to 7.0 on the harness designs and 16.9 to 47.2 on the adverse set. Dividing the [STOP-13](@ref) bound by the normalized residual gives `(2 + k) S/λ` for a positive residual; its leading term `2S/λ` is about 13 at `λ = 0.15 λmax` and 100 at `λ = 0.02 λmax`.
- **Numerical check of [STOP-13](@ref) on the archive.** The archive's per-solve summaries hold 25,200 library-run rows with finite independent gap and KKT residual (all precisions, solvers, option profiles, arms and CPUs; rows of the same solve on several arms are counted separately). The trajectory-derived rows of the simulated gradient-tolerance sweep have no residual and are excluded. With `k` taken as the independent normalized KKT residual divided by the design's nominal `λ / λmax`, no row's gap exceeded `2k + k²`. The largest ratio of gap to that bound was 0.68 for Float32 PGD with `converged = true` (2,119 rows), 0.65 for Float32 APG with `converged = true` (4,830 rows) and 0.55 for Float64 PGD.
- **The residual hypothesis of [STOP-19](@ref).** A passed computed check does not imply it. Among the converged rows above, 14 Float32 APG rows had an independent normalized residual above `τ`, by at most a factor `1.00024`. They are copies, across revisions and CPUs, of two solves: `adv-equi-low-cold` draw 5 with the library defaults on Julia 1.13.3 reported convergence at `1.00024e-5` against `τ = 1e-5`, and `adv-ill-low-cold` draw 6 with `gradtol = 1e-7` on Julia 1.10.13 at `7.6297e-6` against the floor `7.6294e-6`. On the converged rows that meet the hypothesis (2,119 Float32 PGD, 4,816 Float32 APG and 5,906 Float64 PGD), no gap exceeded the ceiling `B` of [STOP-19](@ref), computed with the profile's `τ`; the largest ratio was 0.62.
- The check, run with `python3 -I` on the extracted archive:

  ```python
  import gzip, csv, glob, sys, math
  frac = {"adv-cor-low-cold": .02, "adv-cor-low-warm": .02, "adv-equi-low-cold": .02, "adv-ill-mid-cold": .15,
          "adv-ill-low-cold": .02, "adv-ill-low-warm": .02, "adv-wide-low-cold": .02}   # harness designs: 0.15
  for fn in glob.glob(sys.argv[1] + "/results/*/*/run-summary.tsv.gz"):
      for r in csv.DictReader(gzip.open(fn, "rt"), delimiter="\t"):
          if "lib" not in r["kind"]: continue
          g, kr = float(r["gap_big"] or r["gap"]), float(r["kkt_big"] or r["kkt_rel"])
          if not (math.isfinite(g) and math.isfinite(kr)): continue
          k = kr / frac.get(r["design"], .15)
          assert g <= 2 * k + k * k
  ```

- **Exit fields.** On `1a9f196b` with Julia 1.13.4, a Float32 lasso solve stopped by a callback and one stopped by `time_limit = 0` returned the same flags for both PGD and APG: `converged`, `f_increased`, `stagnated`, `iteration_converged` and `call_limit_reached` were all false after one iteration ([STOP-18](@ref)).

**Applies to.** The recorded Phase 0 populations and revisions; the exit-field probe at `1a9f196b`.

**Code.** Solver source at the recorded revisions; the analysis scripts on the archive branch.

**Tests.** The counts are measurements, not contract accuracy targets.

**Sources.** [Issue #320](https://github.com/mlakolar/ProximalSolvers.jl/issues/320), the Phase 0 report and `archive/issue-320-evidence` at `fb8fb87d`.
