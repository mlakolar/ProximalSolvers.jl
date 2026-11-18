# #352 Stage 0 audit, part 1 of 2: summary, findings, decisions

Research only: no production code, test, default or pin was changed. Audited revision: master `b8a2c04` (after #348, #355, #356, #360), ProximalBase pin `a19c59aa` (loaded tree `138929aa`), Julia 1.13.4 and 1.10.13. Part 2 has the matrix of supported paths, the decision trees with source links, the provenance and how to rerun. Scripts, raw tables and probe outputs: https://github.com/mlakolar/ProximalSolvers.jl/tree/archive/issue-352-evidence. Numbers are for Julia 1.13.4, with 1.10.13 in parentheses where it differs; `evidence/report_numbers.txt` has the query behind each sweep number; the numbers of the probes are in the probe outputs named with them.

## Summary

1. **In the sweep, no `converged = true` contradicted its documented contract.** 165,888 solves (82,944 per Julia version; 11 designs, Float32 and Float64, cold and warm starts) were each evaluated in 600-bit BigFloat on the rounded inputs the solver received. These are high-precision numerical checks, not interval proofs.
   - PGD and APG: of 5,655 (5,652) converged Float64 solves, none has an exact normalized KKT residual at or above `max(gradtol, 64 eps)`. In Float32, 8 of 4,415 (8 of 4,315) exceed it, by at most 2.5 % (4.1 %): the documented difference between the computed and the exact residual.
   - Square-root lasso: 10,766 (10,778) certified solves. The reported `gap` was never below the gap of an independent feasible dual point at the returned iterate, never below the lower-bound evaluation of the suboptimality from the best point found, and always below `1e-4`. No certificate was contradicted; this is not a re-derivation of its proof.
   - Least-squares CD (lasso, elastic net, group lasso) has no independent check. With a positive penalty and the default threshold, all 16,218 (16,182) converged scalar solves that have a tight reference were within the benchmark target (relative suboptimality `1e-8` Float64, `1e-5` Float32); the worst was `1.3e-9` (`1.2e-9`). Group CD is less accurate at the same threshold (48 of 3,529 (3,526) converged solves above the target, by up to `4.6e-5` to `4.7e-5`), inside its contract.
2. **Three mechanisms put `converged = true` at a point that is not a minimizer.** None violates a documented contract; all come from working-precision arithmetic that the stop then trusts.
   - F1: a product underflows before the loss scale is applied (extreme data scales). CD, PGD and APG all return `x = 0`.
   - F2: CD only. A warm start with coefficients far above the solution scale: the cached residual and the coordinate steps round away, the pass changes nothing, and the change test passes. PGD and APG refuse the same point.
   - F3: the correlation `Xᵀy` cancels to 0 at the rounding level of `‖X_k‖ ‖y‖`. All three return `x = 0`; the objective error is negligible, the KKT residual relative to `λmax` is not.
3. **The largest finding is a false negative** (F4). Under `ftol = 0`, an unchanged iterate proposes no stop, so the stationarity check is never asked. A solve that reaches its floating-point fixed point then runs to `maxiter`, or ends with `stagnated = true`, with `converged = false`, at a point whose exact residual is below the bound. With the documented strict configuration, Float32 PGD reports `converged = true` in 12 of 570 solves. A three-line prototype (an unchanged iterate proposes a stop; the check decides) gives 444 (450) of 570 in the sweep and leaves every `ftol > 0` outcome identical. It has two costs, stated in F4, and the maintainer ruled against implementing it as it is.
4. No square-root certificate was contradicted by the checks, but the certificate is first-order in the KKT error (F5): on the seven designs that are not exact or near-exact fits, Float32 solves at the lowest penalty level are rarely certified, although at the default threshold the uncertified points are within `6.5e-5` of the minimum.
5. No shared stop-control code is recommended. The three families stop on three different kinds of evidence (a change test, a computed residual, a proved gap).

## Decisions and ruling

The maintainer ruled on these on 2026-11-18 ([comment](https://github.com/mlakolar/ProximalSolvers.jl/issues/352#issuecomment-6971452004)), after the review of the first draft and before this revision was posted. The recommendations are left as the audit made them.

| # | Decision | Recommendation of the audit | Ruling |
|---|---|---|---|
| D1 | F1 and F3, working-precision products that the stop trusts: (a) document the limitation for all three solvers, (b) decline convergence where a product is at risk, (c) recover the product | (a). The check that PGD and APG already have does not see either case; (b) and (c) are separate designs, neither measured here. | **Documentation only**, for CD, PGD and APG. No extended-precision recovery, no change of default tolerances, no new stopping machinery. |
| D2 | F2, CD reports a pass that rounding emptied as converged: (a) document, (b) research a stop statistic from the unrounded coordinate residual with a precision floor | (a) now; (b) as optional research. The one check measured here (at the returned point, no precision floor) refuses 91 of 480 converged Float32 default solves, none of them above the target. | **Document now, and investigate separately with high priority**, in a research issue linked in the comment after this report. It does not block closing this issue. |
| D3 | F4, exact stall under `ftol = 0`: let an unchanged iterate propose a stop, with the stationarity check deciding, as under `ftol > 0` | GO as one small PR, with the two trade-offs of F4 in its acceptance criteria. | **NO-GO on the current prototype.** The implementation stays as it is. The prototype, its benefits and its costs are recorded in F4. A minimal alternative would need a separate approval before any implementation PR. |
| D4 | F5 to F8: documentation of measured limits | GO as one documentation PR, coordinated with #320. | **Approved**: one consolidated documentation PR, coordinated with #320 and the merged #327 documentation. |
| D5 | Everything in "Keep unchanged" below | No change. | No production solver change is authorized. |

## Findings, ranked

### False-positive convergence

**F1. A product that underflows before the loss scale is applied gives `converged = true` at a point that is not the minimizer, in CD, PGD and APG.** Class: numerical range limitation on inputs that validation accepts, with a documentation gap at the stop; decision D1.

Reproducer (`study/probe_underflow.jl`, both Julia versions, same lines): one column, `X = 2^-500`, `y = 2^-700`, loss scale `2^300`, `λ = α Xᵀy / 8`, all normal Float64 numbers; exact minimizer `5.4e-61`.

| solver (defaults) | returned `x` | `converged` | exact `‖G‖∞ / max(λ, λmax)` | `(F − F*)/F*` |
|---|---|---|---|---|
| CD | 0 | true, 1 pass | 0.875 | 3.27 |
| PGD | 0 | true, 1 iteration | 0.875 | 3.27 |
| APG | 0 | true, 1 iteration | 0.875 | 3.27 |

The Float32 analogue (`X = 2^-70`, `y = 2^-90`, scale `2^90`) gives the same three rows. On the two control rows of #353 (representable product) CD returns the exact minimizer.

- Why PGD and APG pass their check: the gradient is `α` times the rounded `Xᵀ(Xx − y)`, which is 0; `λmax` is computed as 0 for the same reason; so `S = λ`, the computed residual is 0 and `0 < τ S` holds. `numerics.md` already says that an `Xᵀd` that underflows before the scaling is not recovered (lines 765 to 767); it does not say that the stop can then be reported as converged, and it says nothing for CD.
- Consequence for D1: a gate of the kind PGD and APG have, added to CD, would not catch this input. Two other designs exist, neither measured here. A conservative range test could decline convergence when a product may have underflowed; depending on the test, it may also decline some legitimate zero correlations. Recovering the product (for example a scaled dot product when `b` is 0 or subnormal) is a further step, and PGD and APG take their gradient from ProximalBase's oracle.
- How wide it is: #353 measured 57 (Float64) and 4 to 5 (Float32) wrong solves per configuration, all with the binary exponents of the `X` and `y` scales summing to within 8 of the smallest exponent of the type. I did not repeat that scan; I reran its four reproducer rows and added PGD and APG.
- On the Float64 control row PGD and APG end at `maxiter` with `converged = false` far from the minimizer: the initial-curvature problem of #321 (PR #361), reported truthfully.

**F2. CD reports `converged = true` after a pass that rounding left empty, at a point far from the minimizer.** Class: working-precision limitation of the change test, in the ordinary data range, reached through the start; decision D2. Found by the review of the first draft.

Reproducer (`study/probe_rounding.jl`, case B): `X = [1 1]`, `y = [1/64]`, `λ = 1/1024`, start `[M, −M]` with `M = 2^49` (Float64) or `2^20` (Float32).

| solver (defaults) | result | exact `‖G‖∞ / max(λ, λmax)` | `(F − F*)/F*` |
|---|---|---|---|
| CD | the start, `converged = true`, 1 pass | 1.06 | `7.4e16` (Float32 `1.4e8`) |
| PGD, APG | `converged = false` at `maxiter` | 1.06 | the same |

- Mechanism: the residual is initialized as `y − Σ X_k x_k` in working precision, which loses `y` against `M`; each coordinate step is then smaller than half a unit in the last place of the coefficient, so `new == old`; a full pass with no change satisfies `0 < tol`.
- Related degradation is in the sweep. With `λ = 0` on the rank-deficient design, the exact least-squares minimizer has large cancelling coefficients, and the warm starts taken from it give 80 converged solves per precision at the default threshold with an exact KKT residual up to `0.063 λmax` (`0.089`) in Float64 and `0.16 λmax` (`0.15`) in Float32; the cold starts on the same problems end at `1.7e-8 λmax` or below in Float64 and `5.7e-8 λmax` or below in Float32. The stopping pass changed nothing in 24 (8) of the Float32 rows and in none of the Float64 rows; the others stopped on a small nonzero change. The empty-pass mechanism is therefore established for case B, not for all of these rows.
- Unlike F1, a working-precision check would refuse case B: computed from a fresh residual in the working type, its KKT residual is `1.06` of the scale.
- One such check was measured (`study/probe_cd_gate.jl`, 1.13.4). It is evaluated after the solve, at the returned point, from a fresh residual (one more pass of products): the statistic `max_k g_k / √(s a_k)`, the coordinate KKT residual in the units of the change test, compared with the solve's threshold with no precision floor. It refuses 91 of 480 converged Float32 solves at the default threshold with a positive penalty (89 within the target, 2 undecided, none above) and 14 of 480 in Float64 (all within the target). Only 9 of the 91 had a stopping pass that changed nothing (127 of the 480 did, and 66 of the Float64 ones, none refused). The others are refused because this is a stricter test than the change test: at the returned point the statistic contains the coupling with the coordinates visited later (the factor of F8), and the review gave an exact-arithmetic example in which it exceeds the threshold after a valid stopping pass. (A separate point about any visit-level comparison: in exact arithmetic, for the elastic net and a nonzero coefficient whose sign does not change, the normalized residual magnitude at the start of a visit, `|G_k| / √(s a_k)`, is `1 + λ2/(s a_k)` times the scaled change `√(s a_k) |h_k|` of that visit, not equal to it.) So the counts are those of this test. The statistic that a visit could form from its own `b` at `O(1)` was not instrumented, and whether a floor in units of `eps(T)`, a check restricted to empty passes, or another statistic keeps the Float32 solves is the question of the research issue.
- It is not a cure for ill-conditioning: of the converged solves above the target at `λ = 0` in that probe, 20 in Float64 and 36 in Float32, this check refuses 8 and 8; the others have a small residual and a flat objective direction.

**F3. A correlation that cancels at the rounding level gives `converged = true` at `x = 0` with a large KKT residual relative to `λmax`, in CD, PGD and APG.** Class: working-precision limitation, already described for the computed `λmax` in `numerics.md` (lines 144 to 148); decision D1. Found by the review of the first draft.

Reproducer (`study/probe_rounding.jl`, case A): `X = [1, d, −1]`, `y = [1, 1, 1]`, `d = eps(T)/2`, `λ = d/8`. The exact `Xᵀy` is `d`; it is computed as 0. All three solvers return `x = 0` after one pass or iteration with `converged = true`; the exact residual is `0.875 λmax`; the relative objective error is `1.6e-33` (Float32 `4.5e-16`).

- It is F1 without the range: the stop trusts a working-precision product, here one whose exact value is at the rounding level of `‖X_k‖ ‖y‖`. In the unit of F8, `s ‖X_k‖ ‖y‖`, the residual is of the order of `eps(T)`; it is large only relative to a `λmax` that is itself at that level.
- A working-precision gate computes 0 here as well.

Otherwise none in the sweep: see Summary item 1. Two things that are inside the contracts, for the record:

- With a loose user threshold the CD change test is met far from the target, as asked: at `tol = 1e-4`, 696 of 5,700 converged Float64 scalar solves are above `1e-8` (392 of them with a positive penalty).
- Group CD at the default threshold, positive penalty: 42 of 1,770 converged Float64 solves and 6 of 1,759 (1,756) Float32 solves are above the target. With `relative = true`: 12, Float64 only, the largest between `2.8e-7` and `3.7e-7` (lower and upper bound; two underdetermined designs at the lowest level). With `relative = false`: 30 and 6, the largest between `4.6e-5` and `4.7e-5`, with a KKT residual of `3.4e-4 λmax` (`5.3e-4 λmax` in Float32), on the design whose column norms span six decades, after about 33,500 passes. The majorization step of a badly scaled group is slow, and a small step is not a small residual in the unit `λmax` (F8).

### False-negative and inefficient stopping

**F4. Under `ftol = 0` an exact stall withholds `converged = true` from points whose residual is below the bound, and the solve runs on.** Class: intentional contract (#270) that predates the stationarity check (#296); candidate change with a prototype; decision D3, ruled NO-GO for this prototype.

- Mechanism: `convergence_assessment` sets `stalled` when `ftol = 0` and the iterate is unchanged; a stalled iteration sets neither `x_converged` nor `grad_converged` ([`src/utils.jl` L48 to L68](https://github.com/mlakolar/ProximalSolvers.jl/blob/b8a2c04205f6dc8aadeecc42f4971602ab1b5b89/src/utils.jl#L48-L68)), so `_stationary!` is not called. Under `ftol > 0` the same iteration proposes a stop through the `x` test and the check decides. The Float32 stagnation stop (#308) was also added before #296.
- Measured on master (Julia 1.13.4; 570 solves per cell). The middle columns count solves that did not converge although the exact normalized KKT residual is below `max(gradtol, 64 eps)`, on problems with a positive scale `S` (the 12 solves per cell with `y = 0` and `λ = 0` are excluded: the check refuses a zero scale by design). This compares the exact residual with the bound; it does not replay the computed check.

| options | solver, type | converged | not converged, residual below the bound | of those, at `maxiter = 20000` | of those, `stagnated` |
|---|---|---|---|---|---|
| `ftol = 0` | PGD F64 / F32 | 359 / 198 | 191 / 251 | 189 / 192 | 0 / 8 |
| `ftol = 0` | APG F64 / F32 | 358 / 220 | 196 / 249 | 194 / 195 | 0 / 0 |
| strict | PGD F64 / F32 | 314 / 12 | 215 / 538 | 215 / 338 | 0 / 200 |
| strict | APG F64 / F32 | 324 / 214 | 217 / 336 | 217 / 336 | 0 / 0 |

  "strict" is the documented test configuration (`ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11`). Every one of the 208 stagnation stops (215 on 1.10) was at a point with the residual below the bound (largest ratio 0.42; 0.44 on 1.10).
- Typical cases in the sweep: `λ ≥ λmax` from each of the three starts (the solution `x = 0` is reached and never reported: 20,000 iterations, exact residual 0); a warm start at the reference; Float32 strict solves that reach a fixed point whose residual is below the bound.
- Prototype X1 (`study/x1_stall_proposes.diff`): delete the `stalled` exception in the `x` and gradient tests, and report `stagnated` only when the solve did not converge. Library runs of the whole PGD/APG sweep, master against X1:

| in the sweep | Float64 | Float32 |
|---|---|---|
| `ftol > 0` options (4,560 solves): every recorded column identical | 4,560 | 4,560 |
| `ftol = 0` options: newly converged, PGD / APG | 397 / 405 (395 / 397) | 633 / 414 (634 / 412) |
| of the newly converged: recorded objective differs from master's | 0 | 1 |
| converged on master, not on X1 | 0 | 0 |
| `ftol = 0`, converged on X1 with exact KKT at or above the bound | 0 | 0 |
| total iterations, `ftol = 0` options | 18.6 M to 2.65 M (18.6 M to 2.80 M) | 23.2 M to 6.30 M (23.0 M to 6.37 M) |

  The tables record six significant digits and no iterates, so "identical" means identical flags, counts and six-digit objective and residual. On 1.10.13, 2 of the newly converged Float32 solves are above the `1e-5` target while inside the KKT bound, as other converged solves are. The 8 Float32 exceedances of Summary item 1 are in a `ftol > 0` option and are the same on X1.
- **Trade-off 1: X1 makes `ftol = 0` trust the computed check where the default options already do.** On the inputs of F1 and F3, the strict configuration ends at `maxiter` with `converged = false` on master and reports `converged = true` after one iteration on X1 (`study/probe_rounding.jl`, cases A and C, PGD and APG, both precisions). The default options report `converged = true` there on master as well. So the stall rule is not redundant everywhere: it is the one configuration in which those two inputs are reported unconverged.
- **Trade-off 2: APG spends one gradient on each stalled iteration whose check fails, and a call limit can then end a solve that master completes.** Example from the review (`study/probe_rounding.jl`, case D; Float64, one column, `ftol = 0`, `gradtol = 1e-5`): master converges in 340 iterations with 343 gradient calls; X1 needs 349, and with `grad_calls_limit = 344` it stops unconverged at iteration 336. A PR could skip the check while the iterate is unchanged since a refusal (the residual at `x` does not depend on the step size); that variant is not prototyped.
- Checked and unchanged on X1: APG's `x == y` case with `x` different from the previous iterate, and the callback cadence (reviewer probes).
- Cost on the ordinary path: under `ftol > 0` the outcomes are identical, and a paired in-process timing (master, a second copy of master, X1; 24 cells; machine under load) has B/A medians between 0.981 and 1.017 with the A/A control between 0.990 and 1.014, so no difference is resolved.
- Relation to #320: its report found that with `ftol = 0` no harness-design solve misses the target and none reports convergence ("all `stagnated`"). X1 was not among the variants replayed there. It does not make `converged = true` a gap certificate: the Float32 ratio of gap to KKT residual on ill-conditioned low-penalty designs that #320 measured still applies.

**F5. The square-root certificate is first-order in the KKT error, so accurate points go uncertified.** Class: accuracy limit of the residual-direction dual point; documentation, D4.

- Certified solves on the seven designs that are not exact or near-exact fits, `relative = true`, by penalty level (fraction of the level at which the solution is 0):

| level | Float64, default `tol` | Float32, default `tol` | Float32, `tol = 1e-4` | worst suboptimality of an uncertified Float32 point (upper bound) |
|---|---|---|---|---|
| 0.001 | 196 / 210 | 40 / 210 (42) | 24 / 210 | 6.5e-5 (default), 4.6e-3 (`tol = 1e-4`) |
| 0.05 | 210 / 210 | 178 / 210 | 100 / 210 | 3.6e-8 (default), 1.9e-6 (`tol = 1e-4`) |
| 0.3 | 210 / 210 | 210 / 210 | 184 / 210 | 2.2e-7 (`tol = 1e-4`) |
| 0.7 and above | 210 / 210 | 210 / 210 | 208 / 210 at 0.7, all above | 8.4e-9 (`tol = 1e-4`) |

- Why: the dual point is the residual scaled into the feasible set, so the bound loses `(1 − t) ‖r‖`, linear in the relative violation of `|X_kᵀr| ≤ λ ‖r‖`. Measured example (Float64, correlated design, level 0.001, `tol = 1e-4`, 12 solves): after both tightenings the gap of an independent dual point in the residual direction is `1.1e-4` to `2.6e-4`, while the point is within `9.1e-12` (`1.1e-11`) of the minimum. On the failing low-level cases in Float32, rounding of the iterate limits the violation that was reached, and the floor forbids tightening.
- The 14 uncertified Float64 solves at the default are on the design whose response dwarfs the residual, which the docstring names.
- Exact- and near-exact-fit designs (three: underdetermined with and without noise, and a tall noiseless design whose rounded response is within rounding of the column span, not in it; levels up to 0.3 or 0.7): every such solve stops uncertified, `converged = false`, `gap = NaN`, with the warning. The best point found is lower by up to about 17 % (16 % in Float64); that is a lower-bound evaluation of the error. For the interpolating designs this is the situation of #155. The tall design is a near fit; its stop points also have weak residual-direction dual certificates (in the reviewer's probe an independent dual point in the residual direction gives a gap of 0.17 and more, far above `1e-4`, with the certificate's own error allowance negligible). Rounding of the iterate can affect the direction of a small residual; the contributions of that effect and of the certificate's allowances were not classified across the sweep. The status is truthful in all of them.
- With a tightened user threshold (`tol = 1e-10`) on the rank-deficient design, 26 Float64 solves run 100,000 passes without attempting the certificate, at points within `2.8e-8` (`5.3e-8`): the certificate runs only when the change test passes.

**F6. Float32 PGD and APG with the default options end on the objective-increase exit at points within the target.** PGD 70 of 570 (82), APG 67 (77), with the KKT residual a median 4 times above the bound. Class: documented trade-off, owned by #320 (option A). In Float64 the same exit appears at `gradtol = 1e-8`: 35 (37) PGD and 18 (21) APG solves within the target end on an increase.

**F7. The default `tol = 1e-7` with `relative = false` is below Float32 coefficient resolution.** 130 (162) of 5,700 Float32 scalar CD solves and 40 (32) of 1,830 square-root solves run 100,000 passes; the scalar ones with a tight reference are within `5.1e-8` (`3.7e-7`) of the minimum. With the default `relative = true` no scalar solve in the sweep reached `maxpasses` in Float32. Class: documented limitation; one sentence of advice is missing (D4).

**Extreme scales (coordination with #321, nothing new to decide).** On 130 exact power-of-two rescalings of one problem (`X 2^ex`, `y 2^ey`; Float64 exponents up to ±500, 81 pairs; Float32 up to ±60, 49 pairs; `study/probe_scales.jl`, Julia 1.13.4), CD converged on every one, cyclic and random, with an objective excess over the rescaled reference point of at most `2.8e-17` (Float64) and `1e-14` (Float32). PGD and APG with the default options did not converge on any pair with `X` scaled down (`ex ≤ −100` in Float64, 36 pairs; `ex ≤ −20` in Float32, 21 pairs): in Float64 all end at `maxiter = 200`; in Float32 14 end at `maxiter` and the 7 pairs at `ex = −20` end after 46 to 69 iterations (the reviewer's replay of one of them shows the objective-increase exit). The slow start is the initial curvature estimate of #321 (PR #361). PGD also ended on the objective-increase exit after 6 iterations on 10 Float64 and 6 Float32 pairs with `X` scaled up and `y` scaled down, at a relative objective excess of `2.2e-3` (exact KKT residual `0.029` of the scale), and after 9 iterations on the 3 Float32 pairs with `y` at `2^60`, at an excess of `6.8e-10` with the residual `1.3e-5` of the scale, just above the bound. I did not determine the mechanism of these early exits. No converged solve was above its bound or target.

### Reporting and documentation

**F8. The CD docstrings do not say what the change test implies.** Assumptions: exact arithmetic, a full pass without extrapolation, exact minimization at each scalar visit, relative scaling active (`relative = true`, `y ≠ 0`), `τ = tol √s ‖y‖`. Coordinate `k` is at its minimizer when visited, and only the later updates of the pass move its gradient, so

```
|G_k| ≤ s ‖X_k‖ Σ_{j visited after k} ‖X_j‖ |h_j| ≤ (p − 1) · tol · s ‖X_k‖ ‖y‖     (lasso and elastic net)
‖G_k‖ ≤ K · tol · s √ℓ_k ‖y‖                                                          (group lasso, K groups)
```

- The elastic net adds no cross term. Any visiting order gives the first inequality. Momentum does not enter, because the stopping pass has no extrapolation ([`_cd_momentum!`, L367 to L402](https://github.com/mlakolar/ProximalSolvers.jl/blob/b8a2c04205f6dc8aadeecc42f4971602ab1b5b89/src/cd/solver.jl#L367-L402)). The bounds are not strict: both sides are 0 for `p = 1` and for a flat column.
- Group lasso: the visit is a majorization step with `0 ⪯ X_kᵀX_k ⪯ ℓ_k I`, not a block minimization. Its own residual after the step is `s (X_kᵀX_k − ℓ_k I) h_k`, at most `s ℓ_k ‖h_k‖ ≤ √(s ℓ_k) τ`; each later group adds at most `√(s ℓ_k) √(s ℓ_j) ‖h_j‖ ≤ √(s ℓ_k) τ`.
- With the absolute threshold (`relative = false`, or `y = 0`) the scale `‖y‖` drops out: `|G_k| ≤ s tol ‖X_k‖ Σ_{j after k} ‖X_j‖`, and for groups `‖G_k‖ ≤ s tol (ℓ_k + √ℓ_k Σ_{j after k} √ℓ_j)`.
- Check of the scalar relative bound: in 958 converged solves per Julia version (lasso and elastic net, cyclic and random order, with and without momentum) the largest ratio of the exact `|G_k|` to `(p − 1) tol s ‖X_k‖ ‖y‖` was 0.36 (0.51) (`study/probe_cd_bound.jl`). Group check on the column-scaled design (`study/probe_group_colscale.jl`): the last group's residual is `6.75e-7 λmax` against its own-step term `6.82e-7 λmax`; the bound above, with `K = 4`, is `2.7e-6 λmax`.
- What remains unguaranteed, and why the docstring's caution that the flag is not a KKT certificate stays right: the factor `p − 1` or `K`; the unit `s ‖X_k‖ ‖y‖` in place of `λmax` (a factor 5.5 on the correlated design, unbounded in F3); rounding (F2); range (F1).
- One consequence worth a sentence in the docstring: the relative threshold scales with `‖y‖`, so with `λ = 0` and a response dominated by a component in the span of `X`, the relative objective error from a cold start at the default is up to `3.2e-3` in Float64 and `4.8e-3` (`4.9e-3`) in Float32 (the offset design).

**F9. Small items, no change proposed.**
- `maxpasses = 0` warns "did not converge in maxpasses = 0 passes" with `maxchange = NaN`.
- APG forms one gradient per proposing iteration for a check that cannot pass when the computed `S` is 0 (`y = 0`, `λ = 0`: 400 gradient calls in 200 iterations); the scale could be tested first.
- `converged = true` together with `f_increased = true` occurs in 16 PGD and 21 APG (24 and 20) of 570 Float64 default solves; it is documented.
- CD's `minimum` is evaluated from the cached residual. With a positive penalty its largest relative difference from the exact objective at the returned point was: scalar CD at the default threshold `9.3e-15` (`1.2e-14`) in Float64 and `3.0e-6` (`3.3e-6`) in Float32; scalar CD over all thresholds `1.1e-12` (`1.0e-12`) and `3.4e-6` (`3.3e-6`); group CD `2.6e-14` (`1.9e-14`) and `2.3e-4`, on its long runs. With `λ = 0` and the starts of F2 it can be wrong by a factor.

## Keep unchanged

- The change test as the stop of least-squares and group CD. It implies the bounds of F8, and no converged scalar solve with a positive penalty and a tight reference missed the target at the default. The one check measured (F2) refuses Float32 solves that are within the target; F1 and F3 are invisible to the KKT calculation that uses the existing working-precision products.
- The forced full pass after `20 p` active visits (#311).
- The square-root certificate: target `1e-4`, at most two tightenings, the floor, and uncertified meaning `converged = false`, `gap = NaN`.
- The stationarity check of PGD and APG: the threshold `max(gradtol, 64 eps) · max(λ, λmax)`, the `floatmin` requirement, and no convergence at a computed `S = 0`.
- The objective-increase exit and the default `allow_f_increases = false` (#320 owns the Float32 documentation).
- The `stagnated` field: with X1 it reports the stalls that fail the check.
- Result fields and names (`iteration_converged`, the `gap` and `kkt_checks` sentinels), as #280 concluded.
- Default tolerances.
- Separate stopping code per family. The predicates share no state and rest on different evidence; a common layer would add indirection without removing a defect.

## Follow-ups after the ruling

1. **F2 research issue** (zero-change termination of CD; high priority; research only), linked in the comment after this report. `study/probe_cd_gate.jl` and case B of `study/probe_rounding.jl` are its starting measurements.
2. **One consolidated documentation PR** (approved; no code): the limitations F1 to F3 for CD, PGD and APG, with the difference between meeting the implemented stopping criterion and holding an independently certified optimum; what the change test of scalar and group CD implies (F8) and the measured group result; the Float32 limits (F5 to F7); extreme warm starts; the behaviour of `ftol = 0` (F4) as it is. Coordinated with #320 and with the text merged in #327.
3. **F4 is not implemented.** The prototype X1 stays in the evidence archive with its measurements. An alternative would have to improve termination without extra gradient evaluations that matter, without changing call-budget behaviour, and without new misleading successes on the inputs of F1 and F3; none is proposed here. One untested idea for whoever takes it up: evaluate the check once per unchanged iterate, since the residual at `x` does not depend on the step size.
4. Coordination only: #155 and #156 (exact-fit stops; F5 gives the counts), #320 (F6), #321 and PR #361 and #317 (extreme scales).
5. Unmerged code, to audit with the same scripts when it lands: weighted `NormL1` (#350; CD, PGD, APG), `NormLinf` for PGD and APG (#357). #361 changes iteration counts, not a stop test; #362 and #365 change numerical helpers (#365 claims unchanged outcome classes).

## What was not done

- The measures are 600-bit evaluations with ordinary rounding, stored to six significant digits; they are not interval enclosures. The certificate's own rounding proof (in the source comments) was not re-derived.
- The square-root comparison uses an independent dual point (the 600-bit residual, scaled to the boundary of the feasible set), not the production one (the Float64 residual with a conservative scaling).
- Timing ran on a shared machine under load; no difference is resolved, and any later change would have to repeat it.
- The designs are small (20 to 60 rows, 8 to 60 columns). The #353 underflow scan and the #320 Float32 harness records were reused, not repeated. The warm starts of the sweep are near the reference; F2 came from an adversarial start.
- For the exact- and near-exact-fit square-root cases, the rank-deficient lasso cases at the two lowest levels and some group cases, the reference is not tight, and the bounds do not decide every target comparison. The scale probe reports the objective excess over a rescaled reference point, not an upper bound.

## Review

An independent reviewer (Codex `gpt-6.1-sol`, high effort) read the drafts against the code and the raw tables, with its own probes, and requested changes in rounds 1 to 3.

- Round 1 (7 blockers): the classifier now counts a point as above the target from a lower bound, without requiring a tight reference (group CD: 48 solves above the target, not 24); F2 and F3 are new; the two trade-offs of X1 are stated; the bounds of F8 are scoped, given for the absolute threshold, and their probe aligned with the formula; the validation claims are worded as high-precision checks; the D1 argument no longer claims that declining convergence is impossible; zero-weight groups are covered (part 2).
- Round 2 (3 blockers) and round 3 (1 blocker, an unsupported explanation of the near-fit design's uncertified stops, now removed): the check measured in F2 is described as what it is (a final-point test with no floor, not a visit-level statistic), and its counts are no longer attributed to rounding; the exits of the extreme-scale probe are split correctly; the tall noiseless design is called a near-exact fit; several quantifiers and the remaining Julia 1.10 values were corrected.
- Round 4: **PASS / NO BLOCKERS** on this text, with two editorial notes (the wording of the elastic-net parenthetical in F2 and the count in the sentence above), both applied. The reviews and the reviewer's probes are in `review/` of the evidence branch.

Rounds 1 and 2 reviewed the recommendations before the ruling column was added; round 3 checked its statements of fact about the audit.
