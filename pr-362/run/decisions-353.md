**Maintainer decisions on the Stage 0 report (r3), recorded by the orchestrator before implementation starts**

The maintainer answered the decision memo in the session; the rulings are quoted here verbatim so that the issue holds them.

| Proposal | Decision |
|---|---|
| R2: Five bit-identical deletions | GO |
| R4: Consolidate scaled-norm kernel families | GO |
| R1: Simplify square-root lasso range handling | CONDITIONAL GO |
| `_sqnorm!` deletion | DEFER to #339 |
| `response_scale` tier-2 deletion | DEFER |
| Proof-comment relocation | DEFER |
| New `ProximalBase.NumericalKernels` module | NO-GO |
| Move `_SE` to PB | NO-GO |
| Other rejected migrations and abstractions | NO-GO |
| LS CD false convergence | Handle separately under #352 |

> The objective is **less code and simpler maintenance without sacrificing existing correctness, supported behavior, or ordinary-path performance**. Do not maximize deleted lines at the expense of these requirements.

**R2 and R4** go into one PR ("PR A"), as separate commits, independently mergeable, not waiting for R1. Requirements: public API and current behavior preserved; bit-identical results where Stage 0 claimed them; no change to stopping criteria or convergence statuses; no new abstraction layers; a reproducible slowdown above 5 % needs correction or escalation.

**R1** is approved for continued investigation, not for merging as prototyped:

> **Maintainer ruling: Do not introduce this new refusal as part of #353.** Preserve currently supported successful behavior, including exact-fit and zero-residual cases. It is acceptable to reject inputs that cannot be handled meaningfully by the existing implementation, but do not silently narrow the domain merely to reduce code. Investigate whether the simplified formula can retain the existing numerical range with inexpensive, localized handling. Do not introduce a general fallback or complicated recovery framework.

> **Maintainer ruling: Fix the regression rather than accepting it.** […] No reproducible slowdown exceeding 5% on ordinary paths is acceptable without an explicit maintainer ruling.

> If a straightforward implementation cannot simultaneously preserve behavior and performance: 1. Abandon the larger R1 simplification. 2. Apply only the safe duplicate `_scaled_norm` deletion identified in Stage 0. 3. Document why the larger simplification was rejected. 4. Preserve the existing range-handling implementation. […] The default is to preserve the existing code when simplification has material costs.

A second PR ("PR B") is opened for R1 only if a candidate meets the behavioral and performance requirements; otherwise a small PR deletes the duplicate `_scaled_norm` only. Each PR needs an independent Codex review ending in PASS / NO BLOCKERS on its final commit, green required CI and no open review thread before it is merged. #352, #339 and PB #698 are cross-referenced, not taken into scope.

**Process note.** Master moved from the audited `dac9f4b` to `bb20b6a` (#356, #360); in `src/` only `src/utils.jl` changed, and the Stage 0 patch of R2 applies unchanged. PR A follows; the R1 investigation is reported in comments on this issue.
