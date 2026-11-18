Independent Codex review (gpt-6.1-sol, high reasoning effort) of the Stage 0 report, revision r2 (archive commit 63082b3980baf8f82b2d7619e7bf56fdfecb12f1)

VERDICT: PASS / NO BLOCKERS

The two r1 blockers are resolved. I found no remaining GO recommendation that silently loses supported correctness, changes a contract without disclosure, or bypasses the 5% performance gate. One MAJOR correction to a new reachability claim and several MINOR reporting corrections remain below. R1 still requires the stated maintainer refusal ruling and Julia 1.10 performance decision before implementation.

References to `report/REPORT.md` and experiment files below are at archive commit `63082b3980baf8f82b2d7619e7bf56fdfecb12f1`; production `src/...` references are at PS `dac9f4b6819d9321117ee3cf3549e9e46a043f01`. This is a research-report delta review.

Status of the eight r1 findings

| r1 finding | Status | Evidence and remaining work |
|---|---|---|
| 1. Tier-2 deletion loses accepted public inputs | **Resolved** | Removed from the GO bundle and deferred explicitly at report lines 31, 98 and 276. `experiments/x2/x2b.patch` retains all three response-scale tiers. I independently reran the public boundary case against this exact tree on both Julia versions: master and X2b both return `converged=true`, `x=Float32[0.0]`, `tolerance=1.1754944e-38`. The new five-item fingerprint matrix also passes independently, as detailed below. |
| 2. R1 wrongly exempts every zero residual/exact fit | **Partly resolved; blocker resolved** | Report lines 177 and 182–189 now distinguish tiny nonflat columns, zero residuals with clean curvature, and the flat-column bypass. The two review counterexamples are recorded correctly, including the loss of the certified zero solution. Section F at line 340 asks for the appropriate explicit ruling. The old unqualified shorthand survives in ledger line 74; see N4. |
| 3. Wrong ulp units and unfiltered scale counts | **Partly resolved; numerical correction resolved** | Line 276 now uses 42 Float32 ulps and the admitted-scale subset 7,229/3,110, matching `experiments/review-r1/tier2_units-lts.out` and my r1 replay. It no longer presents the 7,530/17,405 direct-model counts as public-domain counts. Add the Julia 1.10 label to those subset statistics. That paragraph also has the scan-count and reproduction-precision errors in N2. |
| 4. Incomplete Julia 1.10 slowdown disclosure | **Resolved** | Lines 15 and 211 now state 12.6% solve and 14.6% per-visit maxima, the p<n case, its 15-round range/control, and the 5.3% three-pass slowdown. Recomputing the raw TSVs gives the same values. Lines 213–217 retain the gate; this is not described as performance-approved. |
| 5. Missing helpers and actual callers | **Partly resolved** | Eight rows were added; the four specifically missing helper groups now appear at lines 135, 138, 139 and 141. Line 86 adds the `_initialize!` caller at `src/cd/solver.jl:476`. The primary class counts and the 76-row total match. The new APG row introduces the unsupported guard-reachability claim in N1, and some new source links/cost labels need the corrections in N3. |
| 6. Unconditional pre-pass group-refusal claim | **Partly resolved; substantive contract correction resolved** | Line 102 now distinguishes predictable pre-pass refusals from lazy eigensolver/nonfinite failures after RNG use, preserves the caller, and identifies allocations inside a pass. This matches `src/cd/leastsquares.jl:327-335,433-480,611-613` and `docs/src/numerics.md:473-482,561-565`. The neighboring `_curvature_deferrable` row at report line 105 still says “no refusal can occur” without the qualification; see N4. |
| 7. BigFloat route called unreachable | **Resolved** | Lines 16, 125 and 233 correctly explain that admitted integer/Bool scales execute the BigFloat conversion on master. Their exact conversion to Float64 justifies replacement. The five-item tree preserves the supplied scale, and the already-disclosed private direct-model BigFloat range loss remains outside the public solve domain. |
| 8. R1-min count/range and predicate equivalence | **Resolved** | Lines 28, 66 and 219 give −13 net for R1-min, distinguish the small-corpus floor change from the approximately 5e-14 large-n observation, and record the targeted last-bit differences. Line 9 qualifies `_clean_sum`/`_squares_normal` equivalence to finite inputs. These match the source and raw evidence. The new description of the 456-case corpus has the small scope error in N5. |

New and remaining findings

**N1 — MAJOR: the new `_prox_grad_step!` row attributes fresh-product failure evidence to different guards.**

Report line 141 says its `nothing` guards “are reachable on an overflowing X d̂.” In `_prox_grad_step!`, the relevant guards test `normx` and `D` at `src/solvers/accelerated_proximal_gradient_descent.jl:238-240`. They are computed from `x` and `x-y` before calling `_bound_certified!` at lines 248–250. An overflowing fresh `X*d̂` instead reaches **`W === nothing` inside `_bound_certified!`**, at `src/solvers/image_models.jl:253-255`.

The evidence report makes precisely this distinction: `agentC/report.md:362` calls the guards in the two routines defensive and singles out `W === nothing` as reachable on an overflowing product. The new ledger drops that distinction. The earlier #279 memo also explicitly left `normx`/`D` failure reachability unestablished end to end; it did not authorize assuming all guards fail at the same overflow edge.

I checked the branch distinction with a constructed helper call on both Julia versions, using `X=[floatmax(Float64)]` and `d=[2.0]`, finite `_SE` norms, and `fresh_only=true`:

```text
D is nothing=false; normx is nothing=false
X*d=[Inf]; W is nothing=true
_bound_certified! returned=(false,true)
```

This is a helper probe, not an end-to-end solve. It shows which guard handles that failure; it does not prove the outer guards unreachable. Correct line 141 to “defensive; end-to-end normx/D failure reachability not established here,” and place the established fresh-product `W` case in the `_bound_certified!` row. Keeping all guards is still the appropriate recommendation. Executed probe: `r2_delta.jl`.

**N2 — MINOR: the deferred tier-2 paragraph undercounts scans and abbreviates away the precision essential to its reproducer.**

At report line 276, “two scans of y instead of one” should be **three total scans instead of one**, or **two additional scans**. The original sum loop remains (`src/cd/leastsquares.jl:197-201`). The replacement then calls `_response_scale_exceptional` → `_se_norm`, which adds the maximum scan and the scaled-square scan (`src/cd/leastsquares.jl:220-225`, `src/solvers/image_models.jl:74-78,55-60`). Restoring tier 2 in X2b removes these additional traversals for tier-2 inputs.

I instrumented a direct-model response-scale call with an `AbstractVector` counting element reads, n=100, `y=ones(Float32,100)`, admitted Float64 scale `1e-43`. On both versions:

```text
master: 200 reads; old six-item X2: 400 reads; X2b: 200 reads
```

The initial loop reads each element twice for `y[i]*y[i]`; the extra 200 reads are the two added 100-element traversals. This instrumentation checks traversal cost, not timing.

Also specify the actual scale recipe in line 276: `Float64(floatmin(Float32))^2 / Float64(s)`, where `s` is the **sequential Float32 sum**. Literal Float32 squaring makes the numerator zero, and replacing `s` by the exact sum changes the boundary case. The archived `experiments/review-r1/verify_findings.jl:11-13` has the correct recipe. Label the 7,229/3,110 counts as Julia 1.10.13 statistics from `tier2_units-lts.out`.

**N3 — MINOR: several new ledger source links and path labels are inaccurate.**

- Report line 137 links PGD `initial_state` and `update_state!` only through source line 160. `update_state!` ends at **167**, including its final gradient refresh. Line 140 links the APG pair only through 196, before the restart branch; it should extend through **212**. The reported 66 and 79 executable-line counts do match the complete functions.
- Line 138 lists `src/line_searches.jl:85-90` as callers, but these are hook declarations. Actual `value_and_gradient_at_x!` calls occur at lines **102,131,136**, and at `src/solvers/proximal_gradient_descent.jl:162`; the `check_rejection!` call at line 159 is correct.
- `_stagnated` is labeled cold at report line 139, but `src/solve.jl:249` calls it **every iteration**. Its true branch/unchanged-vector scan is conditional; the scalar predicate is on the iteration path.
- To complete the newly grouped input guards, include `_check_method` (`src/solvers/accelerated_proximal_gradient_descent.jl:267-272`, called at line 317). It validates the numerical step factors after conversion to the iterate type and is not a constructor excluded by the ledger's introductory exception.

The new B classifications are appropriate. These corrections require no algorithm change and no additional ledger row if the guard is grouped with existing validation.

**N4 — MINOR: corrected detailed claims still have contradictory shorthand elsewhere.**

- Report line 74 still says “Float64 keeps r = 0 and refuses the rest.” Qualify this as **r=0 with clean column curvature**, matching line 177 and the actual cold method. Otherwise it repeats the exception that caused r1 finding 2.
- Line 105 describes `_curvature_deferrable` as a test that “no refusal can occur.” Say **the predictable numerical refusals are excluded under the stated eigensolver model**, matching line 102 and `src/cd/leastsquares.jl:479-480`.
- Line 198 says the only remaining `ldexp` is the exact one in `_certify!`. `rg -n ldexp` finds **two** executable calls in both recommended prototypes: `_prepare!` at prototype `src/cd/sqrtlasso.jl:58` and `_certify!` at X1B line 383 / X1D line 386. The first reconstructs the norm for `floor64` and is not unconditionally exact for subnormal norms. Narrow the PB #896 statement to the removed coordinate-recovery calls. I found no new supported ordinary-solve correctness defect from this surviving floor computation.

**N5 — MINOR: R1-min's targeted corpus includes both types.**

Report line 219 says “2 of 456 targeted tiny-scale Float64 solves.” The **456 is the combined Float32/Float64 corpus**; the two mismatches are Float64. `experiments/x2/x3_sqrt_solves.jl` loops over both types, and `x3_sqrt_solves_x3_release.txt:2-6` reports 456 total comparisons followed by the two Float64 mismatches. Say “2 of 456 targeted tiny-scale solves, both Float64.” The disclosed behavioral effect and the recommendation are unchanged.

Checks run and scope

- Verified report SHA-256 `d15b1514b2a3be43cf42195c20722fce1231a14d642a8b88c503d1e482c5b22b` and byte equality with `git show 63082b3980baf8f82b2d7619e7bf56fdfecb12f1:report/REPORT.md`. Read the full report delta, relevant production definitions, new ledger rows, `x2b.patch`, its loader, and both versions' new fingerprint/test logs. Read the archived reproduction and admitted-scale statistics. The production checkout remains at `dac9f4b6`, with no tracked changes or git writes.
- **Independently reran the exact five-item X2b fingerprint matrix**, loading the review master and X2b side by side, with the archived fingerprint scripts copied into the review probes directory and only their loader redirected. Julia 1.10.13: **4,806 comparisons, 0 mismatches**; Julia 1.13.4: **4,794 comparisons, 0 mismatches**. Per-family totals agree with the new archived logs: 512 group cases, 2,952/2,940 scalar CD cases, 158 square-root cases, and 1,184 PGD/APG cases.
- **Independently reran `test/cd_numerics.jl` against X2b on both versions**, with only the declared numerical test edit `(-1500,...,1500)` → `(-1000,...,1000)` for the direct-model BigFloat scale sweep, plus import redirection to the prototype. Result: **24,400/24,400 assertions passed on each version**. Tier-2 assertions at production test lines 885–889, 915 and 948 remain present. No Pkg operations were used.
- Independently reran the accepted response-scale boundary case against X2b on both versions, and ran the scan-count and APG guard-location probes above. R1's implementation is unchanged; checked its revised predicate against the cold methods, flat-column bypass, the r1 probes, and `experiments/review-r1/verify_findings*`.
- Counted **76 ledger rows**, with primary-label counts **A=13, B=51, C=4, D=3, E=4, housekeeping=1**. Mixed A/B and B/D labels are assigned their first label for this tally, consistently with the report. Using `tools/count_loc.py`: the eight counted master files total **1,439**; X2b totals **1,411**, a net **−28**. The five item savings add up: 7+3+4+10+4=28. R1 64–66 plus R2 28 plus R4 17 gives **109–111**. R1-min remains −13; the folded kernel is still 176→159, −17. These line counts measure deletions/reuse, with nothing moved into PB.
- Recomputed all **nine final timing TSVs** using per-round side/base0 ratios and per-case medians. R1's default-target solve maximum is **1.125941841**, visit maximum **1.145872243**; AVX2 visit maximum **1.105652669**. The new prose discloses these costs and retains the gate. No fresh timings were taken. The R2 allocation/timing evidence and R4 evidence were taken on trees carrying the former sixth change; report lines **235 and 243** now say so explicitly. Their new final-head timing/allocation gates remain necessary. I found no unlabelled reliance on that six-item tree that creates a new correctness or performance approval.
- Rechecked the r1 conclusions relevant to the unchanged recommendations: stable estimates remain distinguished from certified bounds; no PB private API migration, new unconditional BLAS product, CD-loop consolidation, hook deletion, or weakening of the APG certificate is recommended. R3 remains deferred with its changed trajectories and cold-cache limitation disclosed. Q9a now accurately distinguishes the documented change-based stop from mathematical optimality and refers the status question to #352 without inventing a maintainer ruling. R4's separate proof-comment review gate remains appropriate under #279.

Not rerun: the entire repository suite, the full 356,000-step/certificate campaigns, a fresh folded-kernel solve matrix, alternate CPU/BLAS/thread counts, or compile/precompile benchmarks. Their unchanged evidence was reviewed in r1; the additional Julia runs here target the revised five-item bundle and the new claims. No GitHub action other than the requested review comment is part of this review.
