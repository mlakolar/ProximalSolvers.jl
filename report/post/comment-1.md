**Stage 0 report for #353, revision r2 — part 1 of 4: summary, decision memo, direct answers**

# Stage 0 report: numerical helper ownership and duplication between ProximalSolvers and ProximalBase

Audited: ProximalSolvers `dac9f4b6` (master after #348), ProximalBase pin `a19c59aa` (the tree PS loads, verified file by file), ProximalBase master `13891ccf` for comparison; Julia 1.10.13 and 1.13.4. Research only: no production code, pin, contract or benchmark baseline was changed, and no implementation PR or follow-up issue was opened. Four read-only source audits (square-root CD, LS and group CD, PGD/APG, the PB inventory) were integrated here, and three candidates were taken to disposable prototypes with BigFloat references and paired timings. Evidence: branch `archive/issue-353-evidence-r2` (this revision); `archive/issue-353-evidence` holds revision r1 as first reviewed.

*Revision r2.* Revision r1 was reviewed independently (Codex gpt-6.1-sol, high reasoning effort; its comment is on this issue) and returned two blockers and six further findings. All eight are addressed here; the changes are listed at the end of section G.

## A. Audit summary

**How much duplication is there?** Little. The audited PS files hold 1,439 executable lines of solver numerics (`cd/sqrtlasso.jl` 310, `cd/leastsquares.jl` 367, `solvers/image_models.jl` 183, the two gradient solvers 352, `blocks.jl`, `utils.jl`, `line_searches.jl` 227). Against PB's 778-line kernel file there are two PB↔PS pairs with the same algorithm and the same guarantee, `Blocks._maxabs_diff` ≡ the public `norm_diff(x, y, Inf)` (7 lines) and `_sumsq_diff` ≡ private `_sumabs2_diff` (7), and one that agrees on every finite input, `_clean_sum` against private `_squares_normal` (1 line; they differ at `Inf`): 15 PS lines in total. Inside PS there are two more: the square-root solver's `_scaled_norm` repeats `_se_norm(Float64, ·)`, and `_sqnorm!` is a second `Σx²` loop. The rest of what looks alike has different guarantees: PB's kernels return stable values of `T`; PS's APG test and square-root certificate need extended range or one-sided bounds, which PB does not have.

**Is the current ownership appropriate?** Yes, mostly. PS already takes loss values, gradients, prox steps and KKT scores from PB's public oracles and reaches no private PB name. Of 76 ledger rows, 13 are already appropriately shared (A), 51 are solver-specific and stay in PS (B), 4 are true duplicates removable through an existing function (C: one through PB's public API, two through Base, one through PS's own `_se_norm`), 3 are primitives PB keeps private (D, none worth an interface now), 4 are exceptional recovery or generality of low value (E), and 1 is PB housekeeping.

**Top opportunities** (all PS-only; together 109–111 of the 1,439 executable lines, 7.6 %, with nothing added to PB):

1. **R1, square-root lasso (−64 to −66 lines, 21 % of that file).** The Float64 power-of-two recovery step, the split-exponent threshold, the band test and a duplicate scaled norm can be replaced by one formula whose threshold is formed in range, a Float32 re-run of that formula in Float64, and a Float64 refusal when a sum of squares leaves the normal range. Float32 loses no accepted input. Float64 loses non-flat columns with norm below `1.0e-146·√n` (also at a zero residual), nonzero residuals below that norm, and residuals above `1.34e154`; for the extreme-`y` part of that range master already returns `converged = false`. Zero accuracy violations in 356,000 BigFloat-checked steps per Julia version. At parity or faster on Julia 1.13; **on Julia 1.10 the prototype is slower, by up to 12.6 % in a solve (n = 30, p = 120) and up to 14.6 % per visit, which has to be closed or accepted before a merge.**
2. **R2, a bit-identical bundle (−28 lines).** One duplicate of a public PB function, one of Base rounding, one of an existing PS loop, two hand-written `all(iszero, …)`, and a BigFloat conversion that only integer and Bool scales take, where `Float64(α)` is exact. 0 mismatches in 4,800 whole solves per Julia version; timing inside the A/A control.
3. **R4, one scaled-norm kernel instead of two parallel families (−17 lines)**, bit-identical, optional.

**Is a PB submodule justified?** Not now. `ProximalBase.NumericalKernels` would take over at most 30–40 PS lines, most of them in a cold fallback, at the price of a supported namespace and of PS proofs resting on guarantees PB states only in comments. That adds a layer without reducing the combined code. Section E gives the thresholds that would change this.

**Correctness concerns.** No helper in scope returns a wrong answer on supported ordinary inputs (see Q9 for what was run). Four behaviours at extreme scales are recorded as deliberate limitations, one of which reports `converged = true` at a wrong point and is referred to #352.

## Decision memo

| | Item | Effect |
|---|---|---|
| **GO** | **R2** bit-identical bundle (one PS PR) | −28 exec, 1 test edit, no result of `solve!` changes |
| **GO** | **R1** square-root lasso range handling (own PS issue and PR, after a ruling on the Float64 refusal; Julia 1.10 timing gate) | −64…−66 exec, 3 test assertions, docs section; fallback **R1-min** −13 with no refusal |
| **GO, optional** | **R4** folded scaled-norm kernels (after R2) | −17 exec, bit-identical |
| **NO-GO** | `ProximalBase.NumericalKernels` or a separate package now; an extended-range type in PB; PB `norm_diff` in the APG certificate; merging the LS and square-root dot kernels; PB `lipschitz`/`opnorm2` as curvature bounds; refusing LS out-of-band steps; refusing Float32 square-root cold inputs; the bit-identical form of R1; `response_scale` through PB's square-root oracle; closure-based generic reductions | each adds complexity, weakens a certificate or a supported domain, or costs time (reasons and evidence in section C) |
| **DEFER** | **R3** delete `_sqnorm!` (with #339); dropping tier 2 of `response_scale` (it moves accepted inputs at the Float32 normal-range boundary); single-path `response_scale`; a supported PB name for `_residual_squares`/`_sumabs2_diff`/`_squares_normal` (PB #698); moving proof comments to developer docs; a shorter `_level_brackets`; PB housekeeping (`_scaled_dot`, `shrink`) | valid, small, not needed now |

## Direct answers

**Q1. Which PS helpers can be deleted outright?** `_sqrt_offrange_step`, `_sqrt_band_step`, `_sqrt_threshold64`, `_scaled_norm` (R1; the last one also alone); `Blocks._maxabs_diff`, `_round_up`, `_significand_exponent`, the bodies of `_flat_column`/`_flat_group` (R2); `_sumsq_scaled_diff`, `_se_norm_diff`, `_se_norm_diff_onepass` as separate functions (R4); `_sqnorm!` (R3) and tier 2 of `response_scale`, both deferred.

**Q2. Which can already use supported PB APIs without regressions?** One: `_maxabs_diff` → `norm_diff(x, y, Inf)`. Two more go to Base (`T(v, RoundUp)`, `all(iszero, …)`). Everything else that could call PB already does.

**Q3. Which need a small new PB interface?** None that pays for itself. The candidates are `_sumabs2_diff` (7 PS lines), `_squares_normal` (1) and `_residual_squares` (about 20 net, in a cold APG fallback, and only with a stated error theorem).

**Q4. Can square-root lasso reuse LS arithmetic without changing its update?** It already reuses all that is shareable: the `LSModel` with its residual and curvature caches, `_residual_axpy!`, `_flat_column`, `_coordinate_minimizer`, `_refuse_curvature`, both stopping scales and the PB loss value. The remaining overlap is `_scaled_norm`. The two dot kernels must stay separate.

**Q5. Is the square-root exceptional-range machinery proportionate?** Not for Float64: 65 executable lines serve ranges beyond `1e±146`, and for an extreme `y` the result they enable is returned as not converged. Float32 support is worth keeping and costs 8 lines as a re-run in Float64.

**Q6. Should PB expose an extended-range representation to replace `_SE`?** No. PB has no second consumer for compare and clipped subtract, and the move would raise the combined total. Section E lists the contract such a type would need.

**Q7. What must stay in PS whatever the arithmetic interface?** The inequality chain and its constants (they encode PS's matrix-product model), the decision structure of `_bound_certified!` (cheap accept, certified early reject, fresh product, "inconclusive means reject"), the image-error bookkeeping, `_frobenius_upper`, `_check_bound_size`, and all line-search, restart, rollback and stopping decisions. Likewise `_certify!` and its outward rounding.

**Q8. Would `ProximalBase.NumericalKernels` simplify the combined codebase today?** No; it would be another layer.

**Q9. Are any helpers wrong on supported ordinary inputs?** No demonstrated bug. Run: 356,000 square-root steps per Julia version and 4,822 + ~7,000 certificate checks against BigFloat; ~22,000 APG decisions and ~15,000 accepted trials of real solves rechecked in BigFloat; 6,080 ordinary LS, elastic-net and group solves with branch counters; the repository suite. *Deliberate limitations at extreme scales:* (a) LS CD returns `converged = true` at `x = 0` when the product `rᵀX_k` underflows although X, y, the scale, λ, the curvature and the exact minimizer are normal Float64 numbers (X entries `2^-500`, y entries `2^-700`, scale `2^300`; exact minimizer 5.4e-61); the docs promise no end-to-end recovery of every product (that is the documented position, not a maintainer ruling on this case), and the run does satisfy the change-based stopping rule, but the returned point is not the minimizer, so the status question is referred to #352; (b) the square-root centre `old + b/a` can overflow while the minimizer is representable, which is refused, not returned (R1 removes the Float32 instances); (c) the square-root certificate is undefined for Float64 residual sums of squares below `n·2^-969` or not finite, and such solves end uncertified, never falsely certified; (d) PGD and APG stop at `maxiter` without convergence for data scaled by `2^-20` and below (tracked in #316, #321). *Optional accuracy:* `_scaled_norm`'s sequential sum (31–168 eps(Float64) at n = 10⁵), tier 2 of `response_scale` (up to 41.9 ulp), `_sqnorm!`'s in-order sum (64–92 eps); R1 removes the first, the other two are deferred.

**Q10. What is worthwhile for PB 0.6, what is 0.7 research?** PB 0.6 needs nothing from this audit. On the PS side R2 can go now, R4 after it, R1 after a ruling. For 0.7 research under PB #698: a supported scaled sum of squares with a stated theorem, and any certified or extended-range primitive, each only with a second real consumer.
