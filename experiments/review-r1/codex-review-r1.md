Independent Codex review (gpt-6.1-sol, high reasoning effort) of the Stage 0 report, revision r1 (archive commit 9747703f9f00f29752fc1778efd134ac54694223)

VERDICT: BLOCKERS

Source references below are PS `dac9f4b6819d9321117ee3cf3549e9e46a043f01`, unless explicitly marked PB or prototype. Report/evidence paths are relative to archive commit `9747703f9f00f29752fc1778efd134ac54694223`. This reviews the research recommendations, not a production PR.

1. **BLOCKER — R2 does lose accepted public inputs at the response-scale boundary.**

   `report/REPORT.md:96,222,228` says deleting tier 2 causes no accepted input to become a refusal. That is false. I reproduced an accepted-to-refused transition through public `solve!` on **both Julia 1.10.13 and 1.13.4**. With `P` referring first to master and then to the X2 module, run:

   ```julia
   function boundary_case(P)
       y = fill(1f-18, 100)
       X = ones(Float32, 100, 1)
       s = 0f0
       for v in y
           s += v*v
       end
       alpha = Float64(floatmin(Float32))^2 / Float64(s)
       P.solve!(zeros(Float32, 1), alpha * LeastSquaresLoss(y, X),
                NormL1(1f0), P.CDSolver(maxpasses=2, momentum=false,
                                      order=:cyclic, tol=1))
   end
   ```

   Output on both versions: `s=1.000001e-34`, `alpha=1.3817856353145052e-42`, `Float32(alpha)=1.382e-42`. Master returns `x=Float32[0.0]`, `converged=true`, `tolerance=1.1754944e-38`. X2 throws `ArgumentError: the response scale ... is not a normal number of Float32`.

   The scale passes `_check_loss_scale` (`src/solve.jl:29-38`); positive Float64 scales subnormal in Float32 are explicitly supported (`docs/src/support.md:102-123`). Master's sequential Float32 sum slightly overestimates the true sum, so tier 2 rounds its root to `floatmin(Float32)`. The more accurate replacement falls below that boundary and `_se_scale` refuses it (`src/cd/leastsquares.jl:204-230`; deletion in `experiments/x2/x2.patch`). The documentation allows boundary roundings to land on either side (`docs/src/numerics.md:34-39`), so this finding does not demand retaining the less accurate estimate. It does invalidate the unconditional preservation claim used to recommend the bundle. Disclose acceptance changes at the normal-range boundaries and test them, or retain the old acceptance behavior. R4 inherits this issue because its tested tree includes R2. Executed review probe: `r2_fixed.jl`, outputs `r2_fixed-lts.out` and `r2_fixed-release.out`.

2. **BLOCKER — R1's stated exact refusal domain incorrectly exempts all zero residuals/exact fits.**

   `report/REPORT.md:167` says the tiny-sum refusal applies with `r != 0` and that “r = 0 exactly (exact fits) ... stay supported”; the ledger repeats that unqualified preservation at `:72`. In the recommended prototype, `_sqrt_cold` requires **both** a clean column curvature and a zero residual. An unclean positive column curvature is refused even when `r=0`. See `experiments/x1/x1d-final.patch`, corresponding prototype `src/cd/sqrtlasso.jl:176-178`.

   Public reproducer, using the corresponding master or X1D module as `P`:

   ```julia
   P.solve!(zeros(1), SqrtLeastSquaresLoss(zeros(2), fill(1e-150, 2, 1)),
            NormL1(1e-151),
            P.CDSolver(order=:cyclic, momentum=false, maxpasses=10))
   ```

   On **both Julia versions**, master returns `[0.0]`, `converged=true`, `gap=0.0`; X1D throws its Float64 range refusal. With `y=fill(1e-150,2)` and initial `x=ones(1)`, master returns the unchanged exact fit uncertified, whereas X1D also throws. These are additional losses within the tiny-column family, contradicting the report's explicit zero-residual exception. The detailed experiment report actually gives the necessary qualification: `experiments/x1/report.md`, section B, “unless r = 0 exactly with a clean.” Carry that qualification into the main ledger, exact predicate, and maintainer ruling request; account separately for the flat-column bypass at `src/cd/sqrtlasso.jl:154-158`. Executed review probe: `r1_edges.jl`, both version outputs.

3. **MAJOR — R2's reported 24.7 ulp bound uses the wrong units and its sample count is not restricted to admitted scales.**

   `report/REPORT.md:96,222` converts “24.727 eps(T)-units” into “24.7 ulp.” But `experiments/x2/c3a_tier2.jl:50` divides the difference by `eps(T)*a`, not by the spacing at `a`. These differ by the significand. I replayed the same Float32/Float64-scale sweep with `Xoshiro(6)` on Julia 1.10.13, measuring spacing by the difference of the positive Float32 bit representations:

   ```text
   tiers=[35137,17405,7458], changed=7530
   max relative-epsilon units=24.727391453351853
   max actual Float32 ulps=42
   admitted tier-2 inputs=7229, admitted changed=3110
   max actual ulps among admitted inputs=42
   ```

   Thus even the supported subset violates the quoted 24.7 ulp maximum. The original sweep does not apply `_check_loss_scale`; it accepts any finite positive Float64 alpha at `:35-40`, including scales that convert to zero or infinity in Float32. The headline 7,530/17,405 counts match its raw output, but cannot be presented as counts of supported `solve!` inputs. The release output also has different counts: 7,727/17,436 (`experiments/x2/c3a_release.txt:2`). Correct the units, identify which version supplies each statistic, and distinguish direct-model probes from the admitted public domain. Executed review probe: `tier2_units.jl`, `tier2_units-lts.out`.

4. **MAJOR — R1's timing prose omits the largest measured per-visit regression.**

   `report/REPORT.md:199` says the per-visit slowdown is 0.4–10.6%, although its own table at `:197` reaches 1.146. Recomputing the per-round ratios from `experiments/timing/x1-final-visit-lts.tsv` gives, for Float64, n=400, p=40, state=zero:

   ```text
   median(x1d/base0) = 1.145872242770474
   median(base1/base0) = 1.0005085005360699
   15-round x1d/base0 range = 1.1245577517098244 .. 1.155460254250268
   15-round base1/base0 range = 0.9917013203824555 .. 1.0194377441196998
   ```

   This is a **14.6%** slowdown, outside the A/A variation in every round, in a configuration with p < n. Default-target Float64 n=400,p=40, converged is also 1.119238. The default-target 3-pass Float32 n=30,p=120,lambda-fraction=0.1 solve is 1.052500, in addition to the convergence cases named in the prose. The table and explicit timing gate already prevent interpreting R1 as performance-approved; retain that gate, but report the full measured extent when requesting acceptance. I independently recomputed all nine final timing TSVs using the same per-round-ratio/per-case-median definition as `summarize.py`.

5. **MAJOR — The ledger is not complete enough to support its “every numerical helper” claim.**

   `report/REPORT.md:53` promises a row for every numerical helper. Searching definitions against the tables identifies omitted live numerical/decision helpers, including:

   - `LineSearches.check_rejection!`, `src/solvers/proximal_gradient_descent.jl:178-182`, called by `src/line_searches.jl:159`. It performs the extra `X*delta_x` verification product; the `_step_curvature` row merely names it as a caller and does not inventory that product or wrapper.
   - `_prox_grad_step!`, `src/solvers/accelerated_proximal_gradient_descent.jl:217-264`, called at `:191`. It owns the explicit zero-step acceptance, norm-failure retry and certified-test dispatch. Coordinate-step and backtracking routines receive rows, but this analogous numerical helper does not.
   - `_stagnated`, `src/solvers/proximal_gradient_descent.jl:327-329`, called by `src/solve.jl:249`. This stopping helper is absent from the broad stopping-quantity row at report `:128`.
   - `_check_loss_scale` and its representability check, `src/solve.jl:29-38`, used at `:103`. This numerical domain guard is essential to the R2 reachability and exact-conversion argument, yet has no source-linked ledger entry.

   Add grouped rows if useful, retaining #352 ownership of stopping policy. No redesign is requested. Also add the actual LS `_initialize!` momentum-refresh caller `src/cd/solver.jl:476`; report `:84` links only `:445` while calling it “momentum refresh.” The production cache argument for R3 is valid: `_visit!` calls `coordinate_step!` before `coordinate_scale`, and both scalar models write the cache before returning (`src/cd/models.jl:33-37`, `src/cd/leastsquares.jl:102`, `src/cd/sqrtlasso.jl:159`). This does not make direct cold-cache calls redundant.

6. **MAJOR — The group-curvature ledger overstates pre-pass refusal guarantees.**

   Report `:100` says `_prepare!`/`_group_curvature!`/`_check_step_band` refusals happen before the first pass and before RNG use. The same row lists the lazy call at `src/cd/leastsquares.jl:612`: deferred groups run `_group_curvature!` during a visit. That function calls the eigensolver route and the band check at `:334-335`. Its initial buffers and eigensolve allocations can likewise occur then (`:327-335`). Under the eigensolver model, `_curvature_deferrable` excludes the predictable numerical refusals, but this is a conditional guarantee: `src/cd/leastsquares.jl:479-480` explicitly leaves eigensolver failure/nonfinite output to lazy computation, and `docs/src/numerics.md:480-482` says a deferred group can still be refused during a pass. The #326 record distinguishes predictable eager refusals from exceptions during lazy computation, after RNG use; `docs/src/numerics.md:561-565` preserves the caller but allows the generator to advance. Qualify the ledger rather than strengthening that existing contract by assertion. This does not invalidate keeping the lazy design.

7. **MINOR — The BigFloat implementation route is reachable; the unsupported generality is what can be removed.**

   The summary at report `:13` calls the BigFloat route unreachable from `solve!`, and ledger `:122` classifies it as generality no longer admitted. On master, admitted integer and Bool scales in APG dispatch to `_significand_exponent(alpha::Real)` and execute the BigFloat conversion (`src/solvers/image_models.jl:164-170`; APG call at `:154`). I checked method dispatch and the validation of `Int128(2)^100` and `true`. Both are admitted and exactly representable in Float64; `Int128(2)^100+1` is refused for Float64 data. The replacement is justified by this exact-representability gate, not dead-code reachability. The report itself acknowledges the removed integer/Bool allocation in the same ledger row. Reconcile these descriptions. I found no admitted-scale rounding defect in `Float64(alpha)`.

8. **MINOR — Two small counting/equivalence statements need qualification.**

   - R1-min is reported as a net 14 executable lines saved (`report:207`), but the available fallback implementation saves **13**: X2 sqrtlasso 306 → X3 sqrtlasso 293, because the cold caller gains an extraction line. `experiments/x2/report.md`, item 7, already states this. Count the actual two-call-site replacement, not just the deleted 14-line definition. The same R1-min sentence also claims `floor64` moves by at most 1e-15 relative, but the wider raw probe `experiments/x2/x3_item7_release.txt:6` records 225.1 eps(Float64), approximately 5.0e-14, for n up to 100,000. Restrict the 1e-15 statement to its measured small-solve corpus or use the wider observed value.
   - The opening claim of three pairs with exactly the same algorithm and guarantee (`report:7`) includes `_clean_sum == _squares_normal`. They share a finite-input threshold, but are not identical predicates: PS rejects Inf (`src/cd/sqrtlasso.jl:137`), PB's predicate accepts it (PB pin `src/numerical_kernels.jl:639`). The ledger already acknowledges this. Qualify the opening equivalence instead of contradicting the ledger.

Checks completed and limits

- Verified the review checkout is `dac9f4b6819d9321117ee3cf3549e9e46a043f01`; compared the supplied report byte-for-byte with `git show 9747703f9f00f29752fc1778efd134ac54694223:report/REPORT.md`. They match. No tracked source was edited and no git write was run.
- Read issue #353's key questions and definition of done, #352, PB #698/#865/#366 including comments, and the supplied earlier rulings #277/#278/#279/#267/#272/#332/#348/#293/#295/#326 via `gh issue view ... --json number,title,body,comments`. Checked the relevant source, numerical/support docs, tests and prototype diffs; compared PB pin/master numerical-kernel files. The master difference is the group KKT score block plus a comment clarification.
- Independently ran the two public counterexamples above on Julia 1.10.13 and 1.13.4. Loaded prototype modules alongside master without Pkg operations. Also ran 5,000 special-value comparisons per type/version for `_maxabs_diff` versus PB infinity `norm_diff`, 5,000 directed-conversion comparisons per type/version, and 5,000 clean-corner threshold checks per type/version: zero mismatches/nonfinite thresholds. These callers supply same-type, one-based, same-shaped Float32/Float64 arrays; PB's extra shape/type checks do not invalidate the proposed duplicate removal on that domain.
- Independently checked 108 near-parallel/tiny-distance steps per type/version against a BigFloat-512 closed-form objective and the repository's step bound. No excess exceeded the bound; worst ratios were 0.000123606 (Float32) and 1.878e-7 (Float64). This supports using an unclean recomputed d² within the existing absolute objective-error allowance; it is not a new universal proof. Source range analysis supports the Float32 rerun claim: a visited nonflat column and nonzero finite Float32 residual have positive square sums far inside Float64's clean range, even at the storage-size limit. A zero residual is the remaining cold case.
- Confirmed the norm helpers return stable estimates, not outward bounds; retaining `_SE`, `_frobenius_upper`, the APG inequality budget and `_certify!` is supported by the source and cited counterexamples. `_scaled_norm` and `_se_norm(Float64, v)` compute the same mathematical norm on their actual finite, full-vector callers, with different rounding and representations. R4 retains the reduction arithmetic and adds a statically dispatched accessor; its bit-identity/timing evidence is a reasonable basis for an optional separate proposal under #279, subject to correcting inherited R2 claims and rereading proof comments. No new unconditional ordinary-path BLAS product was introduced by the prototype diffs. R2's tier-2 replacement does add two scans of y when it enters `_se_norm`; this is reachable mixed-scale setup work, not a per-coordinate cost.
- Checked #278's separate loops/hooks/transaction rulings remain respected. R3 is deferred and discloses changed singleton trajectories, including the 20,000-pass case. The #293/#295 response-scale and supplied-alpha decisions are preserved in the arithmetic intent, with finding 1 qualifying the changed boundary acceptance. No recommendation to mandate historical PB G1–G12 recovery is warranted by the current #366 policy.
- Checked Q9a against `agentB/repro_underflow.jl`, its outputs, `src/cd/leastsquares.jl:38-51`, and `docs/src/numerics.md:7-52,66-75`. It is a real wrong-optimizer example caused by correlation underflow; it does satisfy the documented change-based stopping predicate. Referring its stopping/status implications to #352 is fair. “Deliberate limitation” should mean the documented absence of exhaustive product recovery, not an invented maintainer ruling accepting this particular false-optimality interpretation.
- Recomputed the final timing ranges from raw TSVs, including A/A controls. For R2 and folded kernels I found no additional >5% slowdown hidden outside their controls. R1 retains an unmet performance gate; finding 4 corrects its prose. I did not take new performance timings on the shared machine.
- Ran the supplied `tools/count_loc.py` counting logic on the trees: master files `[310,367,183,156,196,53,96,78]`, total **1,439**; X1B sqrtlasso **244**, X1D **246**; X2 total **1,404** (−35); X3 total **1,380**; folded image_models **159** versus X2 **176** (−17); PB pin kernel **778**. The main totals and 116–118 combined savings are consistent; finding 8 concerns only the fallback.

Numerical spot checks against raw evidence (in addition to recomputing timings):

| Evidence | Independently checked report number |
|---|---|
| `experiments/x2/unit_items_release.txt` | 10,900 max-difference comparisons, 0 mismatches |
| same, root-scale block | 39,982 admitted-scale comparisons, 0 mismatches |
| same, Frobenius block | 8,000 matrices, 0 mismatches |
| same, rounding block | 6,000,068 conversions, 0 mismatches |
| same, flat-column block | release has 89,776; report's 89,775 is the LTS count |
| `experiments/x2/c3a_lts.txt` and replay | 7,530/17,405; 41.87 → 41.9 ulp old error; units/domain correction in finding 3 |
| `experiments/x1/exp2b_tau_release.txt` | 120,000/type; maxima 0.4204482 and 0.3535534 of floatmax; no nonfinite threshold |
| `experiments/x1/exp3_pass_totals.txt` | Float32 passes 24,539/24,280 on release; 14,321/14,398 on LTS |
| `experiments/x2/fp_x2_lts.txt` | 512+2,952+158+1,184 = 4,806; zero recorded mismatches |
| `experiments/x2/fp_sc_release.txt` | 512+2,940+158+1,184 = 4,794; zero recorded mismatches |
| `agentB/cand_gram.out` | PB violations 230+223 = 453/800; PS 0/800 |
| `agentC/out_e7_pb_norm_diff_lts.txt` | PB norm-relative-accuracy violations 153/4,000 and 69/4,000; PS zero |
| `experiments/x2/c4_margin_release.txt` | 768 Float32 / 616 Float64 checks; zero majorization violations; Float32 worst margin fraction 0.25 |
| `experiments/x1/exp6_alloc_release.txt` | 0 B per ordinary pass; Float32 dense solve 14,992 B and sparse momentum solve 21,072 B, equal across trees |

Not checked: no fresh full repository suite, no complete replay of the 356,000-step or thousands-of-certificates campaigns, no independent proof of every APG error constant, no alternate CPU/BLAS/threading campaign, and no new compile-time/precompile study. Raw records were inspected for these larger campaigns; their reported passes are not presented as independently rerun passes. The review establishes the counterexamples above without requiring those larger reruns.
