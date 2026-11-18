**Verdict: REQUEST_CHANGES**

1. **BLOCKER — The new explanation that the certificate's rounding allowance dominates on the tall near-fit design is contradicted by representative solves.** Location: `report/part1.md:126`, “the tall design is a near fit, where the residual is at rounding level and the certificate's rounding allowance dominates.”

   Calling the rounded tall design a near fit resolves round 2's classification error. The newly added causal explanation does not follow from that classification. Certification uses Float64 even for Float32 iterates; rounding of the iterate and the certificate's own rounding allowances are different effects.

   I reproduced cold, cyclic, no-momentum, default-tolerance solves on `tall_exact`, at penalty fractions 0.001, 0.3 and 0.7. For fraction 0.7:

   | Quantity | Float64 | Float32 |
   |---|---:|---:|
   | Recomputed residual norm | 5.42554e-10 | 4.46528e-6 |
   | Certificate residual-error allowance `Eup` | 4.69036e-14 | 4.69035e-14 |
   | `Eup / P` | 2.72546e-15 | 2.72546e-15 |
   | Fresh production certificate ratio at the returned vector | 0.1713278647 | 0.2889009887 |
   | Independent 600-bit residual-direction gap | 0.1713285635 | 0.2889009887 |

   The independent dual point uses the 600-bit residual and is evaluated without the production certificate's rounding margins; it is not a reconstruction of the production dual point. Its gap is already far above `1e-4`. In the Float32 example the production and independent ratios agree to about 12 decimal places: the certificate's error allowance is not the dominant reason for refusal. At fraction 0.001, the independent gaps are approximately **17.2141 / 78.7656**, again comparable to the production ratios **17.2107 / 78.7656**, despite `Eup/P` of only about `5.25e-12`. At Float32 fraction 0.3 the independent residual-direction dual value is itself nonpositive.

   Evidence: `review-r3-evidence/nearfit.jl` and `nearfit.txt`. The probe evaluates `Eup` with the source formula in `src/cd/sqrtlasso.jl:506,518`; production gap assembly and decision are at lines 519–525. The independent point is `study/lib.jl:239–250`. These are numerical checks with the same precision qualifications as the report, not interval proofs.

   **Correction:** remove the assertion of dominance. A supported replacement is: “The tall design is a near fit; these points also have weak residual-direction dual certificates. Rounding of the iterate can affect the direction of a small residual. The relative contributions of that effect and the certificate's error allowances were not classified across the sweep.” If retaining a stronger causal claim, provide the relevant term decomposition for the cases to which it applies. The observed nonconvergence, truthful flags, near-fit classification and recommendation to preserve the certificate remain supported. This is a new explanatory overreach, not a remaining failure to make the round-2 exact/near-fit correction.

2. **NONBLOCKING — Limit the invisibility claim to the existing products/evaluation order.** Location: `report/part1.md:159`, “F1 and F3 are invisible to a KKT calculation in working precision.”

   The existing gate misses them, but working precision alone does not make detection impossible. In Float64, F1's `alpha * (2*X*y)` evaluates to zero, whereas `2*(alpha*X)*y` gives the representable correlation **2.3661043723335494e-271**, using only Float64 operations. For F3, `(1+d)-1` is zero but `(1-1)+d` gives **1.1102230246251565e-16**. These are evaluation-order examples, not proposed recovery implementations.

   Evidence: `review-r3-evidence/check_revision.py` / `check-revision.txt`; compare the actual unscaled transpose products in `src/cd/leastsquares.jl:38–51` and `src/utils.jl:141–145`.

   **Correction:** “F1 and F3 are invisible to the KKT calculation using the existing working-precision oracle products.” This does not change D1, the measured failures, or the ruling.

3. **EDITORIAL — Make the timing of the elastic-net correspondence explicit.** Locations: `report/part1.md:64`; `study/probe_cd_gate.jl:6–10`.

   The experiment is now correctly identified as a final-point check, and the unmeasured visit-level alternative is separated. The factor `1 + lambda2/(s a_k)` is the exact-arithmetic correspondence between the residual **at the start of a coordinate visit** and that visit's displacement, provided the nonzero sign is unchanged. At the returned vector it can instead describe a hypothetical next visit; it is not an identity with that coordinate's displacement in the recorded stopping pass. For example, the round-2 one-coordinate elastic-net example has nonzero displacement `11/20` but zero final KKT residual in exact arithmetic.

   Evidence: `src/cd/leastsquares.jl:78–104`; the exact example in `review-r2-evidence/check-delta.txt`, section 5. No gate counts are affected.

   **Correction:** label the residual in the correspondence `g_k_before_visit`, or move the factor to a separate sentence explicitly about the visit-level comparison. Keep the final-point coupling explanation separate. This is a clarification of an otherwise resolved round-2 finding.

4. **NONBLOCKING — Narrow the new description of PR #365's claim.** Location: `report/part1.md:175`, “#362 and #365 claim unchanged results.”

   The current body of PR #365 promises “no change of outcome classes”; it does not promise bit-identical numerical results or iteration counts. The report should preserve that distinction when recording unmerged work relevant to stopping.

   Evidence: `gh pr view 365 --repo mlakolar/ProximalSolvers.jl --json number,title,state,mergedAt,body`; saved output `review-r3-evidence/pr365.json`. The PR is open and its body describes the duplicated scaled-norm deletion and unchanged outcome classes. No unmerged implementation was audited here.

   **Correction:** “#365 claims unchanged outcome classes,” separately from whatever numerical invariance #362 claims. The reference to merged #327 documentation is supported by ancestor commit `515f430a` (PR #356), whose title names #327; #327 is the documentation issue, not a PR.

5. **EDITORIAL — Restrict the last review-history sentence to rounds 1 and 2.** Location: `report/part1.md:193`, “the reviewer saw the recommendations, not the ruling column.”

   That accurately describes the earlier review inputs. This round also inspected the ruling column for factual audit claims, as requested; it did not reconsider the maintainer's decisions. The historical blocker counts are correct: seven in round 1 and three in round 2.

   **Correction:** “Rounds 1 and 2 reviewed the recommendations before the ruling column was added; round 3 checked its factual audit statements.” `RULING_URL`, `F2_ISSUE`, `EVIDENCE_URL`, `SRC` and `REVIEW_STATUS` are intentional placeholders and are not findings.

Round-2 dispositions:

| Round-2 finding | Revision-3 result |
|---|---|
| 1: final-point versus visit-level gate; unsupported floor necessity | **Resolved in substance.** The measured predicate, extra products, 91/14 rejection counts, zero-change counts, coupling example and uninstrumented alternative are distinguished. A floor is a research question. Finding 3 above is a timing clarification. |
| 2: extreme-scale exits and inaccurate/accurate subsets | **Resolved.** The 36/21 scale-pair counts, Float32 14/7 exit split, 10/6 inaccurate early PGD exits and three accurate high-response exits match the raw rows. No mechanism is now claimed. |
| 3: rounded tall fixture incorrectly called exactly fitting | **Resolved.** Both parts correctly call it a near fit. The new assertion about certificate allowances is the separate blocker in finding 1 above. |
| 4: gate accuracy-selection rule | **Resolved.** All nine count columns and the displayed worst-residual column agree with an independent classification of the round-2 per-solve replay, in all eight strata. In particular: 91 Float32 rejections, 89 within the declared tight-reference rule, two unresolved, none established above; zero-penalty above/refused counts 20/8 and 36/8. |
| 5: 80 warm rows incorrectly attributed to empty passes | **Resolved.** The default-tolerance scope, 0 Float64 and 24 (8) Float32 empty-pass counts, and limited causal conclusion are explicit. |
| 6: lower-bound extrema and missing upper bounds | **Resolved.** The group intervals describe the established above-target subsets, the limitations acknowledge unresolved comparisons, and scale-probe values are explicitly objective excesses over the reference point. |
| 7: missing LTS numbers | **Resolved.** Scalar error `1.2e-9`, X1 strict count 450, iteration totals, correlated example `1.1e-11`, scalar minimum error `1.0e-12`, and PGD/APG percentage pairs all match. |
| 8: overbroad remaining prose | **Resolved in substance.** Detection/recovery scope, tested starts, observed Float32 limitations, validation strength and query provenance are repaired. Finding 2 above further narrows the remaining precision-only shorthand. |

All changed audit numbers reproduce at their displayed rounding. Both regenerated tables and `report_numbers.txt` match the supplied files byte for byte. The new gate's “two unresolved” label follows the deliberately stricter tight-reference rule; it does not contradict the round-2 observation that their numerical upper bounds were already below the target.

Mathematical verdict: one new causal explanation requires correction; the prior blocking findings are repaired. Presentation verdict: suitable after the localized corrections above. The documentation-only and separate-research rulings were treated as maintainer decisions, not as proposals for this reviewer to approve or implement.

Verified:

- Revision 3 at `b8a2c04205f6dc8aadeecc42f4971602ab1b5b89`; exactly four previously captured files changed from revision 2: the two report parts, gate script and gate output. Source/docs and all 20 raw sweep TSVs are unchanged. Recomputed the changed gate classifications, report tables and sweep numbers; checked the group intervals, warm-pass counts, scale subsets, LTS corrections and review-history counts against raw or preserved independent per-solve data. The scale probe's rescaled references have numerical relative dual gaps about `1.55e-180` / `2.49e-180`, far below the target margins, supporting the numerical target comparisons on these particular scale pairs.
- Ran targeted near-fit/dual-point probes sequentially on Julia 1.13.4, each under 600 seconds, using the existing pinned project and writable depot. Read-only GitHub checks corroborate #327/#365 facts. Evidence and reproducible scripts are in `review-r3-evidence/`. No supplied report/study/evidence, earlier review/evidence, or tracked files were edited; no git write commands, repository tests or GitHub posts were used.

Not verified:

- No full sweep, new LTS solver run, timing rerun, or new X1 solver replay in this round; unchanged source and prior evidence remain applicable. No interval recertification or fresh proof of the complete square-root certificate. The ruling itself is accepted from the user's supplied context; its placeholder link was not independently validated. Snapshot manifest and adjacent source bundle are preserved at `<TMP>/snapshot.json`; final source/dependency verification is saved in `review-r3-evidence/snapshot-verification.txt`.
