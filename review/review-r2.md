**Verdict: REQUEST_CHANGES**

1. **BLOCKER — F2/D2 conflates a final-point KKT experiment with a visit-level statistic, and the precision-floor conclusion does not follow.** Locations: `report/part1.md:24,64–65,159,173`; `study/probe_cd_gate.jl:11–22,39–51`.

   I reproduced the gate summary exactly: **91/480 Float32** and **14/480 Float64** positive-penalty default solves fail the proposed `stat < tolerance` comparison. An instrumented replay also confirms that all 91 and 14 rejected points are within their respective targets using `subopt_hi`, so that particular accuracy assertion is supported.

   However, the experiment computes `stat` **after solve! returns**, using a freshly formed residual and gradient at the final vector. This costs `O(np)` products in the implementation being measured. It does not record the coordinate residual at each visit from that visit's `b`, which could be obtained with constant extra work per visit. Later updates change earlier coordinates' gradients, as F8 itself explains. The 91/14 counts therefore do not measure the acceptance cost of the proposed visit-level predicate.

   A final-point `stat > tolerance` can occur even in **exact arithmetic** after a valid CD stopping pass. For example, set

   ```text
   X = [1 1 1; 0 1 0; 0 0 1], y = [1,0,0], lambda = 0,
   x0 = [1 + 5 tau/2, -6 tau/5, -9 tau/5], tol = tau.
   ```

   One cyclic pass has changes `tau/2, 3 tau/5, 3 tau/5`; their scaled magnitudes are `tau/2, 3 sqrt(2) tau/5, 3 sqrt(2) tau/5`, all below `tau`. Yet the final normalized coordinate residual has maximum **`6 tau/5`**. No coefficient crosses zero and no rounding is involved. Thus rejection by this final-point test is not, by itself, evidence that a *precision* floor is needed. It can reflect a different stopping contract and ordinary cross-coordinate coupling.

   The claimed equality between `g_k/sqrt(s a_k)` and the scaled change is also false for the elastic-net portion of the probe (`src/cd/leastsquares.jl:78–104`). With unchanged nonzero sign, the previsit residual satisfies

   ```text
   |g_k| = (s a_k + lambda2) |h_k|,
   |g_k|/sqrt(s a_k) = (1 + lambda2/(s a_k)) sqrt(s a_k) |h_k|.
   ```

   For `X=y=[1]`, `lambda1=1/10`, `lambda2=1`, and old coefficient 1, the new coefficient is `9/20`: the scaled change is `11/20`, but the normalized previsit residual is `11/10`.

   Finally, the asserted explanation “at the default ... a Float32 solve stops because its steps round to zero” is broader than the replay. **82 of the 91 rejected Float32 stopping passes made nonzero changes**; only 127 of all 480 had zero maximum change. All 14 rejected Float64 stopping passes made nonzero changes. This does not exclude rounding in individual coordinates; it does exclude attributing these counts wholesale to empty passes.

   Evidence: `review-r2-evidence/gate_details.jl`, `gate-details.tsv`, `gate-details-summary.txt`; `check_delta.py`/`check-delta.txt`, sections 4–5, independently check the counts and the exact rational examples. Representative replay row: Float64 `corr95/raw/l1/0.001/cold/cyclic`, default tol, has `stat=8.75216e-7`, threshold `6.28312e-7`, and nonzero `maxchange=5.6606e-7`.

   **Correction:** call 91/14 the rejection counts of this particular *final-point, no-floor* test. Separate its cost and contract from a visit-level predicate; repair the elastic-net identity. Present a precision floor as a research candidate, not a necessity established by these counts. D2(a) remains a defensible maintainer choice, but its rationale must not identify the two experiments or attribute all rejections to rounding.

2. **BLOCKER — The new extreme-scale paragraph misstates exit types and accuracy.** Location: `report/part1.md:133`.

   The 130 scale pairs, two successful CD configurations per pair, CD error extrema, and 36 Float64 scaled-down nonconvergences reproduce. The following Float32 assertions do not:

   - For `ex <= -20`, there are 21 scale pairs per gradient solver, but only **14** end at `maxiter=200`. At `ex=-20`, the seven PGD solves end on an objective increase after **59 or 69 iterations**, and the seven APG solves do so after **46**. See `evidence/probe_scales_release.tsv:383–410`, especially lines 397–398. My replay at `ex=-20,ey=0` prints `converged=false`, `f_increased=true`, `iteration_converged=false` for both methods (`review-r2-evidence/extra-probes.txt`).
   - Of the nine cited early PGD exits with nonnegative `ex`, **six** have relative suboptimality `0.00221049`. The other **three**, at `ey=60`, have error **`6.82635e-10`**, far inside the Float32 target `1e-5`; they are not “far from the minimum.” An example is `evidence/probe_scales_release.tsv:437`. Their KKT residual is `1.32904e-5`, just above the stationarity threshold, which is a different statement.
   - The squared-step-underflow explanation cannot cover all nine cases. For `ex=0,ey=60`, my replay gives last-step norm **1.1196153462784e14** and its Float32 square **1.2535385e28**: no squared-step underflow occurs there. In contrast, at `ex=20,ey=-60`, the last-step norm is **1.0606688465717006e-25**, whose Float32 square is zero. The two subsets require different explanations.

   Evidence: `review-r2-evidence/check-delta.txt`, section 6; `extra_probes.jl`/`extra-probes.txt`. The all-converged-rows bound/target checks on these scale pairs pass.

   **Correction:** report 21 nonconvergences, split into 14 iteration-limit and seven objective-increase exits per solver. Separate the six inaccurate early PGD exits from the three accurate ones. Keep #321 as coordination for the small initial progress, and leave the uninstrumented line-search mechanism unresolved or restrict it to cases where it is demonstrated.

3. **BLOCKER — “Exact-fit optima (three designs)” is false for the rounded tall fixture.** Locations: `report/part1.md:115,126,183`; terminology in `report/part2.md:71` and the associated exact-fit interpretation.

   `tall_exact` is constructed by a floating-point matrix product (`study/lib.jl:79–81`). The supplied rounded response is not generally in the exact column span of the supplied matrix. I checked this fixture in both precisions using **exact rational elimination**, not a residual-size threshold: its first ten equations are nonsingular, and their unique solution fails equation 11. The exact nonzero discrepancy is approximately **6.285166392924303e-16 in Float64** and **1.6618603240466744e-7 in Float32**. Thus no exact fit exists for these rounded data, for any penalty level.

   Evidence: `review-r2-evidence/extra_probes.jl` exports round-trip-exact input values; `check_delta.py`, section 7, converts those IEEE values to rational numbers and performs exact elimination. `check-delta.txt` records the full nonzero rational discrepancies. The source comment already calls this a **near exact fit**.

   **Correction:** describe the three selected fixture families as “exact/near-exact-fit designs.” Distinguish mathematically interpolating optima, rounded near fits, and a computed residual that rounds to zero. Keep the empirical uncertified counts and error lower bounds, but do not attribute every member of the tall family to the nonsmooth exact-fit trap of #155. “The seven selected noninterpolating designs” can describe the F5 table; it should not imply that these exhaust the noninterpolating designs. This repairs a mathematical classification; no invalid production certificate was found.

4. **NONBLOCKING — The new gate's zero-penalty counts use a different accuracy-selection rule.** Locations: `report/part1.md:65`; `study/probe_cd_gate.jl:36,45`; `report/part2.md:17`; `study/summ.py:20–22`.

   The gate experiment admits every positive reference objective. The revised sweep classifier also requires `Fref > 1e-20 F(0)`. Consequently the gate's **56/60 above-target** counts, and **8/18 refused**, include tiny-minimum problems excluded from the report's main classifications. Applying the declared cutoff to the replay gives:

   | Precision | Above target | Of those refused |
   |---|---:|---:|
   | Float64 | **20** | **8** |
   | Float32 | **36** | **8** |

   Evidence: `review-r2-evidence/gate-details.tsv` and `check-delta.txt`, section 4. The raw 56/60 and 8/18 numbers themselves reproduce; the discrepancy is their scope. The conclusion that this gate is not a cure for ill-conditioning survives.

   **Correction:** use one selection rule or explicitly label the additional tiny-minimum cases. Add the `1e-20 F(0)` restriction to part 2's “called above the target” definition; “any reference point with a positive objective” is currently broader than the code. Call this an analysis cutoff, rather than a machine-rounding threshold. The gate's generic “within target” accumulator is implemented as `!above`; use an upper-bound test or an “unresolved” category if retaining that label. For the specific 91/14 default rejections, my upper-bound replay does establish accuracy, as noted in finding 1.

5. **NONBLOCKING — The 80 warm rank-deficient rows establish degraded stationarity, not 80 empty stopping passes.** Location: `report/part1.md:62`, interpreted under F2's empty-pass heading.

   The **80 per precision** count is the **default-tolerance** subset; across all swept tolerances the warm, zero-total-penalty, converged `rankdef` counts are 120 Float64 and 160 Float32. Within those 80 default rows, the stopping pass has zero `maxchange` in **0 Float64 rows on either version**, **24 release Float32 rows**, and **8 LTS Float32 rows**. The reported warm KKT maxima `0.063 (0.089)` and `0.16 (0.15)` reproduce.

   Evidence: raw scalar tables, filtered by `fixture=rankdef`, `l1=l2=0`, `start!=cold`, `converged=true`, `tol=default`; `review-r2-evidence/check-delta.txt`, section 3.

   **Correction:** say that related warm-start numerical degradation occurs in these default-tolerance rows. Do not claim the empty-full-pass mechanism has been established for all 80 without coordinate/cache tracing. A nonzero pass maximum does not rule out rounding in the coordinate responsible for the large KKT residual, so this is a qualification of the causal evidence, not a denial of the numerical failure. The analytic case B and its classification as a supported working-precision limitation are verified.

6. **NONBLOCKING — Group “worst” errors are lower-bound extrema, not determined maxima; the limitations paragraph also overstates missing knowledge.** Locations: `report/part1.md:10,77,183`; `report/part2.md:12`.

   The revised counts are correct. But the quoted worst `4.6e-5` and relative-mode worst `2.8e-7` come from maxima of `subopt_lo`. Among the rows already established above target, the extrema are:

   | Default positive-penalty above-target subset | Maximum lower bound | Maximum upper bound |
   |---|---:|---:|
   | Float64 group, relative=true, both versions | 2.81876e-7 | 3.69397e-7 |
   | Float64 group, relative=false, both versions | 4.60708e-5 | 4.74953e-5 |
   | Float32 group, relative=false, release | 4.55517e-5 | 4.69763e-5 |
   | Float32 group, relative=false, LTS | 4.55496e-5 | 4.69741e-5 |

   Evidence: `review-r2-evidence/check-delta.txt`, section 2; compare `study/report_numbers.py`, item 6, which explicitly queries `subopt_lo`. These subsets do not establish the worst error over *all* converged group solves: among all default positive-penalty relative-mode converged rows, the largest stored upper bound is **1.41795e-6 in Float64** and **1.41779e-6 in Float32**, on both versions; some target comparisons remain unresolved.

   **Correction:** label these values as largest observed error **lower bounds**, or give the brackets. At line 183, replace “only a lower bound ... is known” with “the bounds are not tight enough to decide every target comparison.” An untight reference does not imply absence of an upper bound: the report itself gives a `1.4e-6` upper bound for the rank-deficient scalar subset, and the group rows store finite upper bounds above. These qualifications preserve the corrected target-miss conclusions.

   The new scale probe likewise stores `(F-Fref)/Fref`, not a dual-based upper bound (`study/probe_scales.jl:23,35`). For the “at most” CD accuracy claims in `part1.md:133`, either record/check the reference dual gap and the corresponding upper error or describe the values as objective excesses relative to the reference point. No inaccurate converged scale-probe result was demonstrated; the issue is the direction of the reported evidence.

7. **NONBLOCKING — Add the remaining differing Julia 1.10 numbers under the report's stated convention.** Locations: `report/part1.md:3,10,15,104,124,155`; `report/part2.md:11,14–15`.

   The report says differing LTS values appear in parentheses. These still differ:

   | Item | Release | LTS |
   |---|---:|---:|
   | Worst scalar default positive-penalty tight-reference upper error | 1.26328e-9 (`1.3e-9`) | 1.18367e-9 (`1.2e-9`) |
   | X1 strict Float32 PGD converged | 444 | 450 |
   | X1 Float64 ftol=0 total iterations, master → X1 | 18,577,162 → 2,650,664 | 18,566,192 → 2,804,377 |
   | X1 Float32 ftol=0 total iterations, master → X1 | 23,171,993 → 6,301,340 | 23,041,689 → 6,374,021 |
   | F5 correlated Float64 example maximum `subopt_hi` | 9.0561e-12 | 1.0597e-11 |
   | Scalar Float64 all-tolerance positive-penalty maximum `min_err` | 1.08185e-12 | 1.04744e-12 |
   | PGD maximum exact-KKT exceedance, percent | 2.31% | 2.13% |
   | APG maximum exact-KKT exceedance, percent | 2.54% | 4.06% |

   In particular, part 2's APG row should say about **2.5% (4.1%)**, rather than give the cross-version maximum as the unparenthesized release number. At the displayed precision, the Float64 all-tolerance `min_err` pair is `1.1e-12 (1.0e-12)`.

   Evidence: regenerated `report_numbers.txt` matches the supplied file byte for byte; `review-r2-evidence/independent-recount.txt` and `independent-corrections.txt` independently recompute these sweep extrema and X1 totals. Correction: add the alternate values or explicitly scope each such statement to release only. The F4 table expressly headed “Julia 1.13.4” does not need a duplicate LTS table.

8. **NONBLOCKING — Remaining changed prose needs narrower quantifiers.** Locations and corrections:

   - **D1/F1, `part1.md:48`:** a conservative risk detector *may* reject some legitimate zero correlations. It need not reject `r=0`, `y=0`, or every exactly orthogonal case: a detector can recognize products of zero operands as exact. Replace “would also decline” with a statement about possible false negatives of a specified detector. D1's removal of the detection/recovery impossibility argument is otherwise resolved, and recommendation (a) is defensible as a contract choice.
   - **Keep unchanged, `part1.md:159`:** “F1 and F3 are not visible to a check” is too broad. They are invisible to the **same working-precision KKT calculation**; the report's high-precision measures detect them, and D1 explicitly offers other detection designs. Use the narrower wording.
   - **F4, `part1.md:94`:** “from any start” and “any Float32 strict solve once it reaches its fixed point” exceed the three tested starts and the required positive-scale/threshold conditions. Restrict the examples to the tested starts and to points passing the computed check, including its scale guards. The corrected F4 table itself makes the distinction properly.
   - **F5, `part1.md:124`:** “the iterate cannot bring the violation below about eps ...” is an observed plateau on the difficult cases, not a lower bound valid for all Float32 solutions. Exactly representable stationary points can have zero violation. Say “on the failing low-penalty cases, rounding limits the observed violation ...”. The claimed universal quadratic suboptimality relation from round 1 has been removed, which resolves that objection.
   - **Validation and query descriptions, `part1.md:3,16,187`:** `report_numbers.txt` covers sweep queries, not every new gate, rounding or scale number; those are in separate probe outputs. Say so. “Valid in every solve checked” and “proved lower bound” should read “no numerical contradiction found in the checks” and “high-precision lower-bound evaluation,” consistently with lines 7 and 179–180. The independent-dual-point correction and ordinary-rounding disclaimer are otherwise in place. `REVIEW_STATUS` is an intentional placeholder and is not a finding.

Round-1 dispositions:

| Round-1 finding | Delta status |
|---|---|
| 1: reference filter hides misses | **Resolved:** independent recount confirms 42/6 group misses and scalar 696/392 under the declared cutoff. Its wording needs the cutoff stated, as finding 4 notes. |
| 2: missing cancellation and adverse warm starts | **Coverage resolved:** cases A/B reproduce; F3's analytic error and KKT numbers are correct. New F2/D2's causal/statistic claims need findings 1 and 5 repaired. |
| 3: X1 trade-offs and point identity | **Resolved:** both trade-offs and sweep scope are stated; false point-identity claim removed. Remaining LTS presentation omissions are in finding 7. |
| 4: F6, now F8, bounds | **Resolved:** relative/absolute scope, non-strict inequalities, group own-step argument and corrected elastic-net bound probe are sound. Recorded 958 rows/version and maxima 0.36/0.51 agree. This does not validate the separate gate identity disputed in finding 1. |
| 5: independent dual point / proof strength | **Substantially resolved:** correct point identified, strict stored-value comparisons independently verified, ordinary-rounding limits stated. Residual overstrong wording is listed in finding 8. |
| 6: D1 impossibility and cost claims | **Resolved in substance:** declining convergence and recovery are distinct, unmeasured choices. Residual zero-detector wording is listed in finding 8. |
| 7: zero group weights | **Resolved:** 24 successful probe solves, 12/precision; maximum normalized KKT 7.9e-7 / 7.85e-6. The earlier analytic zero-weight/flat-group case remains valid. |
| 8: zero-scale false-negative counts | **Resolved:** positive-scale F4 counts and explicit distinction from replaying the computed check are correct. |
| 9: cached minimum accuracy scope | **Resolved in substance:** default/all-tolerance scalar and group scopes are distinguished and extrema agree. The remaining rounded LTS value is listed in finding 7. |
| 10: six smaller corrections | **Resolved:** stalled accuracy maxima, cold-start offset scope, flag pairs, approximate percentages, removal of the quadratic claim, and zero-optimum square-root convention are repaired. Finding 3 is an additional exact/near-fit classification correction. |

Mathematical verdict: changes required for the new D2 justification and exact-fit classification. Presentation verdict: changes required to state exit types, bound directions and experimental scope precisely. No production-code change is recommended or authorized by this review.

Verified:

- Delta reviewed at `b8a2c04205f6dc8aadeecc42f4971602ab1b5b89`. Hash comparison confirms unchanged source/docs and all 20 raw sweep TSVs against the round-1 snapshot. Both regenerated tables and `report_numbers.txt` match their supplied versions exactly. Independent recounts cover the changed headline counts, extrema, X1 comparisons, zero-scale exclusions and zero-weight probe output.
- Replayed the new master rounding probe: all numerical/status lines match, apart from the checkout's printed directory name. Replayed the full CD-gate experiment with per-solve output; ran targeted scale probes and exact rational checks. Julia runs were sequential, each under 600 seconds, using the existing pinned setup. F3's tiny objective errors and the gate counterexamples were also checked with exact rational formulas. Evidence is saved in `review-r2-evidence/`; the round-1 review/evidence, supplied report/study/evidence, and tracked files were not edited. No git write commands or GitHub posts were made.

Not verified:

- No full sweep rerun, new LTS Julia run, timing rerun, or new X1 Julia replay in this round; X1's unchanged source and the unchanged raw comparisons were checked, and round-1 adversarial X1 evidence remains applicable. No interval recertification of all BigFloat measures or fresh derivation of the full square-root certificate proof. Standard arithmetic/eigensolver assumptions remain as in round 1; no invalid production square-root certificate was found. Snapshots are preserved at `<TMP>/snapshot.json` with its adjacent source bundle; final verification is recorded in `review-r2-evidence/snapshot-verification.txt`.
