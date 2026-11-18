**Verdict: PASS / NO BLOCKERS**

1. **EDITORIAL — State the normalized, exact-arithmetic visit identity explicitly.** Locations: `report/part1.md:64`; `study/probe_cd_gate.jl:9–11`.

   The timing correction is accepted: the visit-level correspondence is now separated from the measured final-point test. For complete precision, “residual” in that parenthetical means the normalized magnitude, and the identity is an exact-arithmetic statement. For positive curvature and unchanged nonzero sign, it is

   ```text
   |G_k_before| / sqrt(s a_k)
     = (1 + lambda2/(s a_k)) sqrt(s a_k) |h_k|.
   ```

   Evidence: the coordinate minimizer in `src/cd/leastsquares.jl:78–104`, and the exact elastic-net example recorded in `review-r2-evidence/check-delta.txt`, section 5. The probe header already specifies exact arithmetic; the report parenthetical does not.

   **Correction:** say “in exact arithmetic, the normalized residual magnitude at the start of a visit ...”, or use the formula above. This is a units/qualification clarification, not a remaining objection to the experiment or its counts.

2. **EDITORIAL — Update the introductory review-history count.** Location: `report/part1.md:187`, “requested changes twice.”

   The three preserved reviews each start with `**Verdict: REQUEST_CHANGES**`; line 190 now correctly includes round 3 and its one blocker. The introductory count is therefore stale.

   Evidence command: reading the first lines of `review-r1.md`, `review-r2.md` and `review-r3.md` gives three request-changes verdicts. **Correction:** use “requested changes in rounds 1–3.” The corrected sentence at line 193 accurately distinguishes the earlier recommendation reviews from round 3's factual review of the ruling column.

All five round-3 corrections are confirmed:

| Round-3 finding | Revision-4 check |
|---|---|
| 1: unsupported dominance of certificate allowances | **Resolved.** `part1.md:126` removes that explanation, reports the weak independent residual-direction gaps, and states that contributions were not classified across the sweep. The cited probe has finite positive-dual gaps from **0.1713285635** upward; one additional case has a nonpositive dual value. Its tiny allowances and failed certifications support the revised wording. The new `0.17` figure agrees with `review-r3-evidence/nearfit.txt`. |
| 2: precision-only invisibility claim | **Resolved.** `part1.md:159` now limits the claim to the existing working-precision products. |
| 3: timing of the elastic-net correspondence | **Resolved in substance.** Both the report and header separate the start-of-visit comparison from the final-point measurement. Finding 1 above only makes its normalization and arithmetic qualification explicit. |
| 4: PR #365 claim scope | **Resolved.** `part1.md:175` says numerical helpers change and limits #365's claim to unchanged outcome classes, matching the previously checked PR body. |
| 5: review-history timing | **Resolved.** `part1.md:193` accurately scopes what rounds 1–3 reviewed. Finding 2 above is the remaining stale introductory count. |

No remaining substantive claim in the changed sentences exceeds the checked code or evidence. The former blocker is closed. Mathematical verdict: verified within this delta review's scope and the numerical qualifications already stated in the report. Presentation verdict: suitable after the two editorial edits above. The placeholders remain intentional.

Verified:

- HEAD is unchanged at `b8a2c04205f6dc8aadeecc42f4971602ab1b5b89`. Byte/hash comparison against the revision-3 snapshot identifies exactly the two stated changed files: `report/part1.md` and `study/probe_cd_gate.jl`. The gate script from its first `include(...)` through EOF is byte-identical; only its header changed. All other captured source, report, script and evidence files are unchanged, so the existing numerical verification remains applicable.
- Read the full delta and checked each correction against the round-3 review and preserved evidence. The new near-fit description is also consistent with the unchanged tall-fixture sweep rows: no positive independent residual-direction gap in the uncertified release rows is below `1e-4`. No additional numerical claim or solver change was introduced.
- No Julia run, repository test, tracked-file edit, git write command or GitHub post was performed. Earlier reviews/evidence and supplied inputs were not edited. Snapshot manifest and adjacent source bundle are preserved at `<TMP>/snapshot.json`; final verification is recorded in `review-r4-evidence/snapshot-verification.txt`.

Not reverified: unchanged full sweeps, timings, external ruling/PR state, or the full certificate proof. This verdict covers the requested delta and carries forward the earlier reviews' stated numerical and dependency assumptions.
