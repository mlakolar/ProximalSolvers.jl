**Verdict: REQUEST_CHANGES**

1. **BLOCKER — The classifier hides proved target misses when the reference is not tight.** Location: `report/part1.md:51–52`, `report/part2.md:12,17`; `study/summ.py:15–19` (the early `if not tight` return at line 16).

   A tight reference gap is unnecessary for proving that a point is **above** the target. Any feasible reference point gives `F* <= Fref`, hence, for a positive optimum, `(F(x)-Fref)/Fref <= (F(x)-F*)/F*`. The stored `subopt_lo` is useful even when `ref_tight=false`. The classifier discards this evidence before testing the lower bound. This is an analysis defect, not a solver-contract violation.

   Recounting all converged, positive-penalty, default-tolerance group rows gives the following on **both Julia versions**:

   | Precision | Reported misses | Misses established by `subopt_lo` | Hidden by the reference filter |
   |---|---:|---:|---:|
   | Float64 | 24 | **42** | 18 |
   | Float32 | 0 | **6** | 6 |

   For example, `evidence/sweep-release/cd_group_Float64.tsv:3028` is converged, with `subopt_lo=4.60708e-5`, `subopt_hi=4.74953e-5`, and `ref_tight=false`. The Float32 counterpart at line 3028 has `subopt_lo=4.55517e-5`, `subopt_hi=4.69763e-5`. These contradict the reported worst `2.5e-7` and “no Float32 solve.” The largest normalized KKT residual among the corrected misses is **3.41102e-4** in Float64 and **5.26464e-4** in Float32 (LTS Float32: **5.2973e-4**), rather than the reported Float64 maximum `3.3e-4`. The additional Float64 misses are 12 `wide`/`group-g3` rows and 6 `colscale`/`group-mixed` rows; the Float32 misses are the latter layout/design, with `relative=false`. The default positive-penalty group denominator is 3,552 attempted solves, of which 3,529 converge on release and 3,526 on LTS.

   The same filter loses 16 positive-penalty Float64 scalar misses at `tol=1e-4`: the positive-penalty count is **392**, not 376. The total 680 is a tight-reference subset: counting positive-`Fref` lower bounds gives **756** (including 60 tiny-minimum `tall_exact`, zero-penalty rows); retaining that tiny-minimum exclusion but allowing informative loose references gives **696**. Do not interpret `Inf` caused by a zero reference denominator as a proved relative error.

   Evidence command: `python3 .codex-orchestrator/audit/review-r1-evidence/corrections.py`; output: `review-r1-evidence/corrections.txt`. Correction: test a valid lower bound before the tight-reference filter, distinguish proved misses from unresolved accuracy, and regenerate the counts, worst errors, and conclusions. The scalar **default positive-penalty** “none above target” result survives this correction.

2. **BLOCKER — Missing ordinary-range cancellation and adverse warm-start findings.** Location: `report/part1.md:7–14,31,49,124`; fixture/start coverage in `study/lib.jl:48–87`, `study/cd_ls.jl:42`, `study/grad.jl:56`.

   Two supported mechanisms are absent from the report. Neither requires overflow or underflow.

   **Cold correlation cancellation, all three solvers.** Let `d=eps(T)/2`, `X=reshape(T[1,d,-1],3,1)`, `y=ones(T,3)`, and `lambda=d/8`. The exact correlation is `d`, whereas the kernels on this machine compute zero. All three solvers return `x=0`, `converged=true` after one pass/iteration, in Float32 and Float64. The exact normalized KKT residual is **7/8**, since `lambda_max=d` and the violation at zero is `d-lambda`. All nonzero data and relevant products are normal; data magnitudes are at most one. The exact nonzero minimizer is `(d-lambda)/(2+d^2)`. This is a large failure of the normalized mathematical stationarity target, although its objective effect is tiny and the computed/step-change contracts still hold.

   Evidence: `review-r1-evidence/ordinary.jl`, output `ordinary.txt:1–22`; also the larger-correlation variants in `cancellation.jl`/`cancellation.txt`. Mechanism: CD's accumulation in `src/cd/leastsquares.jl:38–51`; PGD/APG's oracle gradient and the separate rounded `lambda_max` product in `src/utils.jl:141–159`. The documentation already discusses correlation cancellation (`docs/src/numerics.md:144–148`), so this belongs among working-precision limitations, not an unsupported-input classification. A new fixture alone is insufficient for Float64: the harness itself chooses penalty levels from a Float64 `X'y` (`study/cd_ls.jl:22–27`, `study/grad.jl:38–42`), which is zero here. Supply the analytic/high-precision penalty level explicitly.

   **CD warm start with a large nullspace component.** Set `X=ones(T,1,2)`, `y=T[1/64]`, `lambda=T(1/1024)`, and start at `[M,-M]`, with `M=2^20` in Float32 or `2^49` in Float64. Cyclic CD without momentum returns the unchanged vector, `converged=true`, after one pass. The exact normalized KKT residual is **1.0625**. Relative suboptimality is **1.3854733938709676e8** / **7.438203255528046e16**, respectively; an analytic optimum is `[15/1024,0]`, with minimum `31/2097152`. See `review-r1-evidence/probe.jl`, output `probe.txt:2–9`.

   Here initialization loses the small response while forming the cached residual (`src/cd/leastsquares.jl:27–34`), and the prox displacement rounds away (`:100–104`). Unlike F1, even a conventional working-precision KKT check would reject this point. The supplied warm starts are close to references and do not exercise this possibility.

   Correction: add these as supported numerical limitations and explicit adversarial coverage. Preserve the distinction between mathematical inaccuracy and violation of the documented computed/change contract. Qualify “otherwise none,” “one false convergence outside the ordinary range,” and the argument for keeping CD unchanged; the narrow statement that the tested flags satisfy their documented contracts need not be reversed.

3. **BLOCKER — D2 needs its newly admitted false positives and call-budget trade-off stated.** Location: `report/part1.md:12,21,56–83,136`.

   The **sweep-scoped** X1 comparisons are reproducible: all 4,560 `ftol>0` rows per precision/version match across every recorded column, no formerly converged sweep row is lost, and no `ftol=0` X1 row exceeds the high-precision KKT threshold. These are not general preservation guarantees.

   First, X1 turns the strict underflow reproducer from `converged=false` at `maxiter` into `converged=true` in one iteration, for **both PGD and APG, both precisions** (`review-r1-evidence/probe.txt:10–17`). It does the same for the ordinary cancellation example in finding 2 (`ordinary.txt:1–22`). The unchanged working-precision gate is fooled; its mere presence does not make all exact-stall suppression mathematically redundant. This does not establish a violation of the computed contract, but it must accompany the proposed change to the strict contract.

   Second, there is a supported **lost solve under a call limit**. Use Float64, `X=reshape([2^-27],1,1)`, `y=[2^-28]`, `x0=[1]`, `NormL1(0)`, APG, and

   ```julia
   ProximalOptions(ftol=0, xtol=1e-300, gradtol=1e-5,
       maxiter=1000, allow_f_increases=true, grad_calls_limit=344)
   ```

   Master converges in **340 iterations, 343 gradients**, at `x=0.5000048396436829`; X1 stops unconverged in **336 iterations, 344 gradients**, at `x=0.5000393375970645`. Without a call limit both converge at iteration 340, with 343 versus 349 gradients. Early stalls fail stationarity; X1's six extra APG checks exhaust the budget. Evidence: `review-r1-evidence/ordinary.jl`, `ordinary.txt:23–32`. This follows directly from `src/utils.jl:156–159` and call-limit checks after assessment in `src/solve.jl:234–245`.

   I checked the requested APG `x==y`, `x!=x_previous` case: both versions give `(false,false,true,true,false)` in the constructed stationary state (`ordinary.txt:33–34`). The callback probe preserves cadence on executed iterations: 48 callbacks at multiples of 7 through iteration 340 in both versions (`edges.txt`). Source order still calls the callback before the stagnation check. The proposed suppression of `stagnated` on a converged iteration is the advertised contract change; a failed-check stall retains the existing predicate.

   Correction: retain D2 as a maintainer choice about **computed** stationarity, add these examples and explicit call-budget acceptance criteria/tests, and limit “no solve lost/no above-bound solve” to the measured settings. Also replace summary “at the same returned points”: even the six-digit objectives differ for one newly converged release Float32 solve (`sweep-release/grad_Float32.tsv:2933` versus `sweep-x1/grad_Float32.tsv:2933`, `6.58742e-15` versus `6.46162e-15`). The archive does not store full iterates, so matching objective/residual columns cannot prove point identity for the others. Across **all** X1 options there are still 8 Float32 exact-KKT exceedances per version, inherited from `ftol>0`; zero is the `ftol=0` result.

4. **BLOCKER — F6's bound needs scope, boundary cases, and matching validation.** Location: `report/part1.md:107–114`; contract table `report/part2.md:11–12`.

   The main scalar derivation is sound **in exact arithmetic, with a full plain pass, exact scalar minimization, nonflat columns, and the scaled relative test**. Elastic net adds no cross-coordinate ridge term after coordinate `k` is visited. Random order simply changes the later-coordinate set; momentum does not invalidate this argument because the stopping pass has no extrapolation (`src/cd/solver.jl:367–398`). A safe foundational inequality is

   ```text
   |G_k| <= s ||X_k|| sum_{j visited after k} ||X_j|| |h_j|.
   ```

   The group extension also works under the stated majorization assumption `0 <= X_k'X_k <= ell_k I`, but needs the own-step residual term `s(X_k'X_k-ell_k I)h_k`, plus later cross-block terms. Bounding these gives the displayed `K` factor. This argument should be supplied; a group visit is not an exact block minimization in general.

   The table currently also attaches the relative bound to `relative=false`, where it is false. A concrete counterexample is `X=[1 1;0 1]`, `y=[delta,0]`, `x0=[0,tol/2]`, `lambda=0`, cyclic/no momentum/absolute stopping. One pass satisfies the change test, but `|G_1|=tol/4`, whereas the displayed RHS is `tol*delta`. With `tol=1e-7`, `delta=1e-12`, the probe prints **2.5e-8 versus 1e-19**, `converged=true`, one pass (`review-r1-evidence/edges.jl`/`edges.txt`). For absolute stopping the scalar bound is instead `s tol ||X_k|| sum_after ||X_j||`; the analogous group bound is `s tol (ell_k + sqrt(ell_k) sum_after sqrt(ell_j))`. Handle the `y=0` absolute fallback separately.

   Strict `< (p-1)...` is also false at `p=1` (and at a flat column): the exact residual is zero and the RHS is zero. Use a non-strict universal bound and identify when strictness applies.

   Two evidence mismatches:

   - `study/probe_cd_bound.jl:31` uses `||X_k||^2 + lambda2/s` in the elastic-net denominator, whereas F6 displays `||X_k||^2`. That validates a weaker, different bound. My corrected rerun, `review-r1-evidence/corrected_bound.jl`/`.tsv`, still has 958 converged rows and a maximum ratio about **0.357**, so the rounded headline 0.36 survives; the Float32 `tol=1e-5` stratum changes from 0.107 to 0.109.
   - The `6.82e-7 lambda_max` in `probe_group_colscale.txt` is the **own-step bound for the last group**, not F6's `K`-group bound. Here `K=4`, so F6 gives approximately **2.728e-6 lambda_max**. The measured `6.75e-7` nearly saturates the stronger last-group bound; it does not “equal the bound of F6.”

   Correction: state the relative and absolute results separately, give the group own-step argument, repair strictness, and align the probes with the stated formulas. The existing docstring's warning that convergence does not guarantee a *small* KKT residual remains appropriate: dimension, data scale and rounding can make the bound large.

5. **BLOCKER — “Same dual point” and rigorous validation claims exceed what the measurement scripts establish.** Location: `report/part1.md:9`, `report/part2.md:17,74`; `study/lib.jl:104–120,123–132,163–206,238–254`; `study/tables.py:41`, `study/sqrt_an.py:9–12`.

   The lasso/elastic-net KKT formula is correct. The elastic-net dual expression is the feasible residual dual for the augmented data; the group and square-root formulas are also mathematically valid, with appropriate nonzero-denominator qualifications. I found no algebraic error in these formulas that explains away a genuinely bad returned point. The reference's origin in CD is acceptable when independent bounds are used.

   However, `sqrt_measures` constructs a dual point from the **600-bit residual** and its maximally feasible scaling. Production `_certify!` uses the **Float64-recomputed residual** and a conservative scaling obtained from rounding bounds (`src/cd/sqrtlasso.jl:441–510`). These generally have different directions and different scalings. `gap_exact_at_x` is not the exact gap of the production dual point. Comparing an independent feasible dual upper bound on suboptimality can still be useful, but it is a different claim.

   Moreover, these BigFloat calculations use ordinary rounding, not interval/outward arithmetic. `reference` sets `Dref=Fref` for a numerically solved smooth problem (`lib.jl:129–132`), and `rel` converts to Float64 before six-significant-digit TSV formatting (`:254,269`). The analysis accepts certificate underestimation up to a relative `1e-5`. Thus “proved lower bound,” “exact,” and “none invalid” need either a rigorous enclosure/margin argument or qualification as high-precision numerical checks. A small invalid bound could be hidden by the comparison slack and serialization.

   Evidence commands: rerunning `study/tables.py` reproduces both archived tables exactly. My strict comparisons on the serialized values also find **zero** `gap < gap_exact_at_x` and **zero** `gap < subopt_lo`, without the `1e-5` slack (`review-r1-evidence/recount.py`/`.txt`). That is reassuring numerical evidence, not recovery of the unrecorded production dual point or a proof from six-digit data.

   Correction: describe the actual independent dual point; retain full-precision values or compare before serialization; distinguish numerical validation from the production rounding proof. If “same dual point” is retained, reconstruct the production `rhat` and `t` and independently enclose their exact dual feasibility and gap. State separately the source-level certificate argument and the empirical checks. No invalid production square-root certificate was demonstrated in this review.

6. **BLOCKER — D1 presents an unsupported impossibility/cost argument.** Location: `report/part1.md:20,31,43–45`.

   F1's observed behavior and immediate explanation are correct: the rounded gradient and rounded `lambda_max` are zero, the positive `lambda` supplies the scale, and the threshold passes the `floatmin` guard (`src/utils.jl:122–146`; ProximalBase's predictor oracle forms the transpose product before scaling). A CD gate using the same working-precision gradient would miss **this reproducer**. Recommendation (a) is defensible as an explicit selective-range/working-precision contract choice.

   But it does not follow that reporting `converged=false` is “not available without the machinery” of recovering the product. A conservative range-risk test can decline convergence without reconstructing the answer; it may also decline legitimate zeros. Distinguishing those zeros more precisely and actually using a recovered correlation in an update are separate design choices. Nor is “two `ldexp` per entry whenever `b` is zero/subnormal” a necessary cost of every recovery design. It describes one possible implementation, with no measured cost here.

   Correction: say that the existing naive gate is insufficient, distinguish conservative refusal/detection from recovery and their false-negative costs, and label the stated recovery cost as an unmeasured candidate. Call F1 an **accepted-input numerical range limitation with a stopping-documentation gap**, rather than implying the public input is unsupported: validation accepts it and the documentation explicitly limits intermediate-product recovery. Do not use the false dichotomy as the reason to choose (a).

7. **BLOCKER — The explicitly requested zero-weight group path is not represented.** Location: `report/part2.md:7,12,71`; `study/cd_ls.jl:83–95`.

   Issue #352 explicitly requests zero weights where supported. Group CD supports finite nonnegative custom weights, including zero (`src/solve.jl:67–89`, `src/cd/solver.jl:73–85`), but every group sweep uses the positive default `sqrt(group size)` weights. This omission is independent of unmerged weighted `NormL1`.

   A minimal reviewer probe uses `X=diag(1,0,2)`, `y=[1,3,2]`, singleton groups, weights `[0,1,2]`, `lambda=1/4`, and a ones start. Both precisions return `[1,0,0.875]`, `converged=true`, three passes, objective **4.96875**, matching the analytic optimum (`review-r1-evidence/edges.jl`/`edges.txt`). It covers a zero-weight group and a positively penalized flat group.

   Correction: add explicit zero/custom-weight coverage and its acceptance measure to the supported-path table and evidence, or clearly mark it as an unmet required task. Do not describe default group weights as exhaustive group-penalty coverage.

8. **NONBLOCKING — F2's “bound holds” table counts undefined normalized residuals as passing evidence.** Location: `report/part1.md:59–68`; `study/lib.jl:254`.

   `rel(0,0)=0` makes the `y=0,lambda1=0` solutions appear below the normalized threshold, although `S=0` and the actual stationarity check intentionally refuses them. Each of the eight release table cells contains **8** such rows. They are not evidence that the solver's own check would pass if asked. Removing them gives:

   | Options / solver | Positive-scale nonconverged points below the exact normalized threshold, F64 / F32 | Of those at maxiter, F64 / F32 |
   |---|---:|---:|
   | ftol0 / PGD | 191 / 251 | 189 / 192 |
   | ftol0 / APG | 196 / 249 | 194 / 195 |
   | strict / PGD | 215 / 538 | 215 / 338 |
   | strict / APG | 217 / 336 | 217 / 336 |

   Evidence: `review-r1-evidence/corrections.py`/`.txt`; compare the explicit `S` and threshold guards in `src/utils.jl:129–132`. Correction: report zero-scale solutions separately, and distinguish an exact normalized-threshold comparison from actually replaying the computed check, including its finite-scale/`floatmin` requirements. F2 remains substantial after this correction; the 208/215 stagnation counts are unaffected.

9. **NONBLOCKING — F7's `minimum` accuracy numbers have unstated filters and omit materially larger group errors.** Location: `report/part1.md:120`.

   The quoted **9.3e-15 / 3e-6** are approximately correct for **release scalar CD at default tolerance** with a positive penalty and finite relative error. They do not describe all CD positive-penalty results. Recomputed maxima are:

   | Scope | Float64 release / LTS | Float32 release / LTS |
   |---|---|---|
   | Scalar, default tol | 9.34939e-15 / 1.19028e-14 | 3.02976e-6 / 3.29165e-6 |
   | Scalar, all swept tolerances | 1.08185e-12 / 1.04744e-12 | 3.39824e-6 / 3.29165e-6 |
   | Group, all positive-penalty rows | 2.6047e-14 / 1.85978e-14 | 2.31798e-4 / 2.32262e-4 |
   | Group, converged positive-penalty rows | 2.6047e-14 / 1.85978e-14 | 1.50275e-4 / 1.50887e-4 |

   These maxima use finite `min_err`; identify zero-objective cases separately. Representative raw evidence: `sweep-release/cd_scalar_Float64.tsv:7693`, `cd_group_Float32.tsv:3266,3268`, `cd_group_Float64.tsv:3028`; complete selections and row numbers are in `review-r1-evidence/corrections.txt`. Correction: state the scalar/default filter, add the group row, and discuss cached-objective drift on the long-running group cases. This does not itself show violation of the documented change test.

10. **NONBLOCKING — Remaining numerical and mathematical scope corrections.** Locations and repairs:

    - **F5, `part1.md:103`:** the release stalled scalar maximum is **5.1216e-8**, but LTS is **3.66724e-7** (`sweep-lts/cd_scalar_Float32.tsv:15125`), so “the scalar ones ... within 5.1e-8” does not cover the parenthesized LTS count. Give both values. The 130/162 and 40/32 counts reproduce.
    - **F6, `part1.md:114`:** `3e-5` to `5e-3` describes the **nonreference** offset starts, not all starts. The release Float64 full range is **1.50292e-20 to 0.00322444**, and Float32 is **0.00181598 to 0.00480091** (LTS maximum 0.00492802). Add the start restriction.
    - **F7, `part1.md:119`:** 16/21 is the release PGD/APG pair. On LTS it is **24/20**. State the version or add the alternate pair.
    - **F3, `part1.md:98`:** the largest stored lower bounds are **0.169928** and **0.157139**, so write “about 17% / 16%,” not “at least 17% / 16%.” These numbers bound suboptimality from below using a best feasible point; the actual maximum error may be larger.
    - **F3, `part1.md:96`:** the residual-direction gap has the stated first-order loss mechanism, but “the suboptimality is quadratic” requires a local smooth/stable-support qualification. Square-root lasso is nonsmooth at coefficient zeros and exact fits, and the sweep includes rank deficiency. It is not a uniform quadratic relation between KKT error and objective error. Present the 12 correlated-design solves as the measured example of the mechanism.
    - **Square-root contract, `part2.md:13`:** the `y=0,x=0` certified special case has `P*=0`; `(P-P*)/P*` is undefined, rather than a relative gap less than `1e-4`. State exact optimality with the package's `gap=0` convention separately (`src/cd/sqrtlasso.jl:438–467`). Scope summary `part1.md:13`'s `6.5e-5` accuracy claim to the seven non-exact-fit designs used in F3, excluding the exact-fit traps.

    Evidence command: `python3 .codex-orchestrator/audit/review-r1-evidence/corrections.py`, plus `recount.py`; outputs are alongside them. These repairs do not reverse F3–F5's qualitative observations. All other report numbers I recomputed agree to the displayed rounding, subject to the filters and limitations above.

Mathematical verdict: needs revision for the counting/validation and contract-scope claims; the central relative-mode CD derivation and the independent objective/KKT/dual formulas are sound with the qualifications above. Presentation verdict: needs revision to distinguish sweep observations, computed contracts, and universal claims. I treated `EVIDENCE_URL` and `SRC` as intentional placeholders.

Verification and limits:

- **Verified:** issue #352 read first with the requested `gh issue view`; audited HEAD `b8a2c04205f6dc8aadeecc42f4971602ab1b5b89`; source paths, stopping predicates, accepted/trial state, full-pass/momentum behavior, certificate/tightening/floor, warnings and result fields; PB pin/tree and loaded reviewer path `<DEPOT>/packages/ProximalBase/2welE/src/ProximalBase.jl`; both archived tables regenerated exactly; headline and subsidiary counts/extrema independently recounted; cross-version agreement counts and X1 pairings; the supplied X1 tree matches the three-line diff. Release-only reviewer probes ran one at a time, each under 600 seconds, with one BLAS thread. No repository test files, git writes, tracked-file edits, or GitHub posts were performed. Reviewer scripts/results and saved issue text are in `review-r1-evidence/`.
- **Not verified:** a full independent rerun of all 165,888 solves, reviewer probes on Julia 1.10, the historical #353 scale scan or #320 harness, performance beyond the supplied shared-machine timing, or an interval proof of every stored BigFloat reference. The square-root rounding proof was checked at the direct-dependency level; standard IEEE error models, gradual underflow, and the documented group eigenvalue model remain assumptions. No invalid production square-root certificate was found. Snapshot manifests and adjacent source bundles are preserved at `<TMP>/snapshot.json`, `pb-snapshot.json`, and `x1-snapshot.json`; final verification status is recorded in `review-r1-evidence/snapshot-verification.txt`.
