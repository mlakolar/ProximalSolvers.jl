## Decision needed from the maintainer: this PR changes outcomes at an exact tie of the tightening floor

**The work on this PR is paused here. It is not merged and not changed until the maintainer answers.**

### What the review found (blocker 1), verified by the orchestrator

The tightening floor of the square-root stop check is `floor64 = 16 eps(T) ‖y‖`. A tightening `tol → tol/100` is allowed when the new threshold is at least the floor. With a relative threshold the two sides are `(user tol) · ‖y‖ / 100^k` and `16 eps ‖y‖`, where the first `‖y‖` comes from `response_scale` and the second, on master, from `_scaled_norm`. This PR takes the second from `_se_norm`, which differs from `_scaled_norm` in the last bit for about 40 % of vectors.

At almost every tolerance that difference cannot matter. It matters when the two sides are equal up to rounding, which happens when the user tolerance is `1600 eps(Float64)` or `160000 eps(Float64)` (so that `tol/100` or `tol/100²` is `16 eps`), or one ulp from them. There the last bit decides whether a tightening is made.

Measured, base `6e583f7` against head `4c2efd7` in one process, 300 seeded Float64 problems per tolerance (n = 100, p = 8), relative threshold, public `solve!`:

| tolerance | Julia | identical | `converged` true → false | false → true | same flag, other pass count or final tolerance |
|---|---|---|---|---|---|
| `1600 eps` | 1.10.13 | 255 | 8 | 1 | 36 |
| `1600 eps` | 1.13.4 | 239 | 9 | 1 | 51 |
| `160000 eps` | 1.10.13 | 254 | 6 | 1 | 39 |
| `160000 eps` | 1.13.4 | 244 | 5 | 1 | 50 |
| `prevfloat(1600 eps)` | 1.10.13 / 1.13.4 | 244 / 246 | 1 / 0 | 7 / 6 | 48 / 48 |
| `nextfloat(1600 eps)` | 1.10.13 / 1.13.4 | 281 / 282 | 2 / 3 | 0 / 0 | 17 / 15 |
| `1599 eps`, `1601 eps`, `16000 eps`, `1e-10`, `1e-12`, the default | both | 300 | 0 | 0 | 0 |
| Float32 data, the same ten tolerances in `eps(Float32)` | both | 300 | 0 | 0 | 0 |

So: no change at any tolerance away from the tie, and at the tie about one solve in six changes its pass count or final tolerance and about one in forty changes `converged`, in both directions but mostly from true to false. The certificate itself is unaffected: every `converged = true` on either side is a certified result.

For context, master is not fully stable at this tie either, because `response_scale` sums with `@simd`: the same master source compiled for a target without AVX gives a different pass count or final tolerance in 4 of 120 (1.10.13) and 3 of 120 (1.13.4) of these tie solves, and with bounds checking in 1 of 120 on 1.10.13. In those runs the `converged` flag did not change.

This contradicts criterion 4 of the plan of this PR ("no solve changes its outcome class or pass count because of it") and the statement of the Stage 0 report that deleting `_scaled_norm` is safe: the corpora behind that statement did not contain a tolerance on the tie.

### The second finding (blocker 2)

`_scaled_norm` normalizes by an exact power of two; `_se_norm` divides by the largest magnitude and reconstructs the norm by a rounded product. The error analysis of the step in `test/sqrt_lasso.jl` says the out-of-range paths have "the same counts or fewer roundings in T" as the fast path, which is true with `_scaled_norm` and false with `_se_norm` in Float64. No probe found a step outside the bound (worst excess/bound 0.12), but the proof would have to be extended by the extra rounding terms.

Together the two findings say that `_scaled_norm` is not a pure duplicate of `_se_norm`: it has two properties the rest of the file uses (a deterministic sequential sum for the floor, exact scaling for the proof).

### Options

**A. Merge this PR after fixing the proof (accept the tie change).** −13 executable lines, one norm algorithm fewer. Cost: Float64 solves whose relative tolerance is within an ulp of `1600 eps` or `160000 eps` can change their pass count and, about one time in forty, their `converged` flag; the floor's last bit becomes CPU-dependent (it already is on the other side of the comparison); the proof comment of the step gains rounding terms. The reviewer's blocker 1 would need the maintainer's explicit override, which the reviewer then acknowledges.

**B. Close this PR without merging (recommended).** `src/cd/sqrtlasso.jl` stays exactly as on master, and R1 of #353 ends with no code change. This is the default the maintainer set ("preserve the existing code when simplification has material costs"; "preserve currently supported successful behavior"), and it costs 13 lines that turn out to carry two used properties. The findings are recorded on #353 so that the question is not reopened without them.

**C. Make the tie independent of a second norm** (for example, form the floor from the same `‖y‖` as the threshold). That would remove the instability on master too and let `_scaled_norm` go, but it changes the stopping rule, which #352 owns; it is not proposed here.

**Recommendation: B.** The gain of A is small, and the two findings remove the premise ("a duplicate") on which the deletion was approved. C is the right place to revisit it, under #352, if the maintainer wants the tie made deterministic.

Evidence: `evidence/floor-tie/` of this run (scripts `floor_tie.jl`, `floor_tie2.jl`; raw outputs), to be archived with the rest of the implementation-phase evidence of #353.
