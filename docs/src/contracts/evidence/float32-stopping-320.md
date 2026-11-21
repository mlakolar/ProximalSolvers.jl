# Float32 PGD and APG stopping: measurements

This page records the measurements behind [STOP-18](@ref), [STOP-19](@ref) and [STOP-20](@ref) (issue
[#320](https://github.com/mlakolar/ProximalSolvers.jl/issues/320)). They are observations at stated revisions, not
solver guarantees.

## [evidence-float32-stopping-320 Study and provenance](@id evidence-float32-stopping-320)

**Statement.** The Phase 0 study of #320 ran Float32 PGD, with Float64 PGD and Float32 APG as controls, at ProximalSolvers `637f06a`, `9f86a80` and `dac9f4b` on Julia 1.10.13 and 1.13.3 (Intel Xeon E5-2640 v4 and Xeon Silver 4116). The designs were the five harness designs `lasso`, `lasso-B` (cold and warm), `lasso-C` and `lasso-D` at `λ = 0.15 λmax`, and an adverse set of seven correlated, equicorrelated, ill-conditioned and wide designs, six of them at `λ = 0.02 λmax`. Each design had 10 draws. Independent gaps and KKT residuals were evaluated in Float64 on the rounded inputs and checked in 256-bit BigFloat. The scripts, preregistration, per-solve summaries and the report are on the branch [`archive/issue-320-evidence`](https://github.com/mlakolar/ProximalSolvers.jl/tree/fb8fb87d2d017b0b4b6a14050697b0f05d8cccd9) at `fb8fb87d`; the report is the [Phase 0 comment](https://github.com/mlakolar/ProximalSolvers.jl/issues/320#issuecomment-6967100343).

- **Exits under the harness options.** In the 240 Float32 PGD records at `dac9f4b` (harness and adverse designs, both Julia versions), the objective test made the first stop proposal in 237 records; no proposal was made in the other 3. All 156 objective-increase exits were rises of one to three Float32 spacings of `F`, 142 of exactly one. Both counts concern the [STOP-18](@ref) objective-increase class, whose result does not store the size of the rise.
- **Computed-KKT convergence and the gap.** Under the harness options, each of the 231 Float32 PGD records with `converged = true` had an independent normalized KKT residual below `64 eps(Float32) ≈ 7.63e-6`. Among those that missed the `1e-5` target, the ratio of gap to normalized KKT residual was 2.3 to 7.0 on the harness designs and 16.9 to 47.2 on the adverse set. The bound of [STOP-19](@ref) allows ratios up to about `2S/λ`, that is about 13 at `λ = 0.15 λmax` and 100 at `λ = 0.02 λmax`.
- **Check of [STOP-19](@ref) against the archive.** For each of the 36,036 per-solve summary rows in the archive (all precisions, solvers, option profiles and arms), `k` was taken as the independent normalized KKT residual divided by the design's `λ / λmax`. No row's independent gap exceeded `2k + k²`. The largest ratio of gap to bound was 0.67 for Float32 PGD with `converged = true` (5,570 rows), 0.65 for Float32 APG with `converged = true` (4,998 rows) and 0.55 for Float64 PGD. The check script is in the [#320 Stage 1 comment](https://github.com/mlakolar/ProximalSolvers.jl/issues/320).
- **Exit fields.** On `1a9f196b` with Julia 1.13.4, a Float32 lasso solve stopped by a callback and one stopped by `time_limit = 0` returned identical flags for both PGD and APG: `converged`, `f_increased`, `stagnated`, `iteration_converged` and `call_limit_reached` were all false after one iteration ([STOP-18](@ref)).

**Applies to.** The recorded Phase 0 populations and revisions; the exit-field probe at `1a9f196b`.

**Code.** Solver source at the recorded revisions; the analysis scripts on the archive branch.

**Tests.** The counts are measurements, not contract accuracy targets.

**Sources.** [Issue #320](https://github.com/mlakolar/ProximalSolvers.jl/issues/320), the Phase 0 report and `archive/issue-320-evidence` at `fb8fb87d`.
