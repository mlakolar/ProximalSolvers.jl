## #317 findings: research and triage (no implementation)

**Setup.**
- Revisions: master `b8a2c04` with ProximalBase pinned at `a19c59aa`.
- Julia 1.13.4 locally, on an Intel i5-13600K with one OpenBLAS thread.
- The evidence branch `archive/issue-296-evidence` (`84399297`) was re-extracted, and its checksums verify.
- Every variant is a probe-only override, run one process per variant. Nothing is in `src`.

### 1. Reproducer and reference

**Archived (#296).**
- Probe: `probes/lserr.jl`.
  - Design: `Xoshiro(296)`, `X = randn(30, 12)`, `β[1:4] = [2, -1.5, 1, 0.5]`, `y = Xβ + 0.3·randn`.
  - Problem: `α·LeastSquaresLoss(y, X)`, `NormL1(0.0)`, cold start `zeros(12)`.
  - Options: `maxiter = 20_000`, `ftol = 0`, `allow_f_increases = true`, `xtol = 1e-300`, `gradtol = 1e-11`.
  - Source: master `fad90d9` plus the F+G+R override, Julia 1.13.3 on an EPYC 7513.
- Matrix (`matrix/repro-impl-*.tsv.gz`, PR at `6d90f25` = F+R+E).
  - Errors: 120 on 1.13.3 and 115 on 1.10.13. All are `line search failed: nonfinite curvature estimate`, Float64 PGD, `strict` options, cold start.
  - Master `fad90d9` had 0 errors, because it stopped falsely at the zero step, which is the #296 defect.
- **The "α ≤ 1e-200" in the issue is a grid artifact.** The matrix goes straight from 1e-100 to 1e-200.

**On current master the same error reproduces** at α = 1e-180, 1e-200, 1e-250 and 1e-300. It occurs with only `maxiter = 20_000` as well as with the strict options.

**Minimal regression reproducer** (default options, 1×1, finishes instantly):

```julia
solve!([0.0], 1e-170 * LeastSquaresLoss([1.0], [1.0;;]), NormL1(0.0), ProximalGradientDescent())
# master: ErrorException("line search failed: nonfinite curvature estimate")
```

The error is raised at `src/line_searches.jl:167`, and the NaN comes from line 140.

### 2. Diagnosis: subnormal `‖d̂‖²`, then `0 · Inf = NaN`

The line search starts at `L = 1` and decays it by 0.9 per iteration. When `α‖X‖² ≪ 1`, the step `d̂ = x - x'` of a cold start is about `α‖∇f‖/L`, far below 1.

1. While `‖d̂‖²` underflows to exactly 0, every trial takes the zero-step exit at line 98. The #315 check refuses the proposed stop, so `L` keeps decaying and `‖d̂‖` grows by 1/0.9 per iteration.
2. Function values no longer change, so TFOCS switches to gradient mode for good (line 129).
3. When `‖d̂‖` reaches about 1e-162, `xy_sq = _norm(d̂)^2` is a **nonzero subnormal** (5e-324 at the failure, in every logged case). Then:
   - `2. / xy_sq` overflows to `Inf`.
   - The gradient-difference dot product `(∇f(x) − ∇f(x'))·d̂ ≈ α‖X d̂‖²` underflows to 0.
   - `local_l = 0 · Inf = NaN`.
4. A NaN estimate skips `check_rejection!` (line 158). `max(NaN, L/β)` is NaN, and the error at line 167 fires.

Logged state at the failure, α = 1e-180:
- `L = 7.0e-17`, against a true curvature `α‖X‖² = 7.3e-179`.
- `max|d̂| = 1.2e-162`, `xy_sq = 5e-324`, `sum(abs2, d̂) = 0`, `f(x) == f(x')`.

The failure does not come from curvature growth or an invalid intermediate. It is underflow of a diagnostic quantity, `‖d̂‖²`, followed by an overflowing reciprocal. The step itself, `x`, `f` and `∇f` are all normal numbers.

- **The trigger is the scale of the step, not α itself.** Scaling `X` and `y` by `√s` with `α = 1` gives the same pattern. The solve fails when the first prox step from the start has norm below about 1.5e-154, so that its square is below `floatmin(Float64)`, and enough iterations remain to grow it into the subnormal window. With `maxiter = 200`, α = 1e-200 does not reach the window. On the three test designs, α ≤ 1e-158 fails and α ≥ 1e-155 does not.
- **Float32 is not affected, by accident.** `2. / xy_sq` is evaluated in Float64, so `2 / 1.4f-45` is finite and the estimate is `0`, not NaN. I logged Float32 solves passing through the subnormal window at 1f-30 and 1f-35 without error. Float64 has no wider type to fall back on.
- **APG is not affected.** It has its own line search, and it converges at α = 1e-158 to 1e-300 with default options.

**Contract.** These inputs fall within the documented input contract:
- `α`, `X`, `y` and `λ` are representable;
- `f(x₀) ≈ 1e-178` and `∇f` are normal numbers;
- the BackTracking docstring already intends a tiny nonzero step whose square underflows to take the zero-step exit.

The square here underflows to a subnormal, not to 0, so it slips past `xy_sq == 0`. The expected outcome is a returned result (`converged=false` if need be), not an exception from a diagnostic underflow.

### 3. Affected scope

- **Ordinary scales are unaffected.** The failure needs a step norm below about 1.5e-154 while `L` is still decaying. That requires `‖prox step‖/L₀ ≲ 1e-154` at the start, or a problem whose coefficients are themselves at that scale.
- The probe counted every time a nonzero subnormal `‖d̂‖²` reached `backtrack!`. The count was 0 in every solve at scales ≥ 1e-155, including α = 1, 1e100 and 1e200, cold and warm, for all designs and λ fractions.
- Warm starts near the solution never reach the window, because the step is absorbed by `x`. They take the exact zero-step exit.
- Scan: 448 solves, made of 3 designs (base 30×12, wide 40×100, correlated 60×20), λ/λmax ∈ {0, 0.1, 0.5}, cold and warm starts, scales 1e200 to 1e-300 by α and by data, and two option sets.
  - Master errored in **96** solves: all cold starts, scale ∈ {1e-158, 1e-200, 1e-300}, both option sets, both arms.

### 4. Narrow remedies evaluated

Each variant ran on the same 448-solve scan.

| Variant | Change | Errors (of 448) | Non-error solves (352) | Standard tier | Verdict |
|---|---|---|---|---|---|
| **R2g** | line 140: `iszero(local_l) \|\| (local_l *= 2. / xy_sq)` | **0** | **bit-identical to master** | **67,774/67,774 pass, no test change** | **preferred** |
| R1 | line 98: zero-step exit when `xy_sq < floatmin(Float64)` instead of `== 0` | 0 | bit-identical | 1 failure: `core_regressions.jl:539` | alternative |
| R2 | `local_l = 2·dot/xy_sq` | 0 | identical here, but rounds differently from master in general | not run | superseded by R2g |
| R3 | R2 plus a Float64 `_step_curvature` from scaled norms `(‖Xd̂‖/‖d̂‖)²` | 0 | **46 changed, 18 of them at α = 1** | not run | rejected: changes ordinary trajectories, adds `nrm2` |

On the 96 formerly failing solves, R1 and R2g give identical results, row for row.

**Why R2g is the narrowest.** It changes behavior only in executions that master ends in this error.
- If `2/xy_sq` is finite, `0 · (2/xy_sq)` is already 0 (of the same sign), so R2g changes nothing.
- The new path exists only when `2/xy_sq = Inf` (`xy_sq < 2/floatmax`, a subnormal) and the dot product is 0. There, master forms NaN and always throws at line 167, or accepts in both versions when `L ≥ Lexact`.
- With R2g the estimate is 0 and the trial is accepted by the ordinary TFOCS test `L̂ ≤ L`.
- Float32 data never take the new path, because `2. / xy_sq` is computed in Float64 and stays finite.
- Function-value mode is untouched. A subnormal-norm rejection there is still checked by the computed curvature, which `core_regressions.jl:528-540` characterizes.
- Cost: one `iszero` test, in gradient-mode trials only. **Not timed**; a paired timing would belong in any implementation PR.

**R1** reaches the same outcome by sending subnormal `‖d̂‖²` to the zero-step exit. That matches the docstring's intent ("a tiny nonzero step whose square underflows"), and it also closes a residual case that R2g leaves open (below; the case is already present in master). But it reverses a characterized behavior.
- The fixture at `core_regressions.jl:528-540` is a function-value-mode step of norm about 1e-157.
- Under R1 it is accepted unchecked: `verifications` goes from 1 to 0, while acceptance, `L` and the mode are unchanged.
- It widens unchecked acceptance from `‖d̂‖ ≲ 2e-162` to `‖d̂‖ < 1.5e-154`.
- Its threshold must be the literal `floatmin(Float64)`, not `floatmin(T)`, because `T` is the line search's parameter type, not the data type.

**Residual case of R2g (not observed, not ruled out).** A subnormal `‖d̂‖²` together with either:
- a nonzero gradient-difference product in gradient mode, or
- rounding noise `f > q` in function-value mode,

gives `L̂ = Inf`, and the check runs. If additionally `sum(abs2, d̂)` underflows to 0 while `_norm(d̂)^2 > 0` (every |d̂ᵢ| ≲ 2e-162), then `c` is not finite and the error can still occur. None of the 448 solves, or the 1×1 cases, reached it.

**Outcome on the 96 formerly failing solves with R2g (= R1):**
- `allow_f_increases = true, ftol = 0`: **48/48 converge**. Max relative error to the exact reference is 1.5e-4, the same as at α = 1 (8.8e-5 to 1.5e-4). The reference uses the lasso's invariance under `(α, λ) → (sα, sλ)`, solved by CD at α = 1, tol 1e-14. They take 3,400–7,000 iterations.
- Default options: 12/48 converge, and 36 end on the documented objective-increase exit with `converged=false`. That matches what master already does at α = 1e-100 and 1e-150, where the solves do not error: 4/16 and 6/16 converge.
- The 1×1 reproducer returns `converged=false` at `maxiter` with a finite `x`, for α = 1e-160 to 1e-200.
- The archived `strict` options on the 30×12 design, λ/λmax ∈ {0, 0.1}:
  - α = 1e-158 and 1e-200 converge in about 3,500 and 4,400 iterations, with relative error about 6e-11. That is the same as α = 1, at 3.3e-11.
  - α = 1e-300 reaches `maxiter = 20_000` with relative error 4.7e-16 but `converged=false`. This is the documented floor of the stop check, not this issue: `τ·S = 1e-11 · 8e-299` is below `floatmin`.

### 5. What neither variant fixes (documented limitation, defer)

The cause shared with the residual tiny-scale behavior is the scale-blind start `L₀ = 1`.
- At α = 1e-300 PGD spends about 6,500 iterations decaying `L`.
- Under the default `allow_f_increases = false`, a tiny-scale solve usually ends on a rounding increase of `F` during that phase. That happens on master too, for 1e-100 to 1e-150 cold starts and for all warm starts at α ≤ 1e-100.
- This is the curvature-initialization follow-up from the #315 report. A Rayleigh-quotient start changed 268/1728 ordinary iteration counts, with a 150× outlier. That is not narrow, and I do not recommend it under #317.

### Recommendation

- **Go for R2g alone**, as a one-line change at `src/line_searches.jl:140`. It would come with:
  - the 1×1 reproducer above as a regression test (expect no throw, a finite `x` and `converged=false` at default `maxiter`);
  - the 30×12 `strict` case at α = 1e-200, expecting `converged=true`;
  - one docstring sentence: "in gradient mode a zero gradient-difference product gives `L̂ = 0`, also when `2/‖d̂‖²` overflows".
  - No existing test changes. `test/stopping_scale.jl` (`solve_case`) already tolerates either outcome.
- **Not recommended:** R1, unless you prefer closing the residual case at the cost of the "subnormal step checked" characterization. Also not R2, R3 or a scale-aware `L₀` under this issue.
- **Document** in the numerics page that Float64 PGD with a cold start at step scales below about 1e-154 (for example `α‖Xᵀy‖ ≲ 1e-154` from `x = 0`) needs about `log(1/(α‖X‖²))/log(1/0.9)` iterations before it makes progress. Under default options it may end with `converged=false` on the objective-increase exit; APG or CD are the better choice there.
- If no implementation is wanted, the fallback is to document the error as a supported-range limitation, at step scales below about 1e-154 for cold starts, and close.

Not related to #352 F1 (false `converged=true` from an underflowed stopping check). Neither R2g nor R1 touches the stopping check.

Probe scripts, the R1 and R2g diffs, raw TSVs, test logs and a SHA256 manifest are kept locally in the research worktree. They will be archived on a pinned branch before the issue is closed.
