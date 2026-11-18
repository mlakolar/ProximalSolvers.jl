## Certification summary for #156 (part of the joint #155/#156 study)

Research only; no production code, no PR; no implementation is authorized by this summary. The integrated report, with the escape study, is on #155: [LINK-155]. Revisions: PS `master` `a0a06477`, PB pin `a19c59aa`, Julia 1.13.4 (and 1.10.13 for the fixtures and baseline). Clarabel/JuMP were used only as offline oracles.

### Reproduction

- `X = [1 2; 0 1]`, `y = [1, 0]`, `λ = 0.1`, from 0 (cyclic): `β = [1, 0]`, `converged = false`, `gap = NaN`, certificate code `:undefined` (r̂ = 0). This holds on both Julia versions, in both types, and for dense and `SparseIterate` iterates.
- The point is optimal: `θ = (0.1, −0.1)` is feasible and `θᵀy = 0.1 = P(β)`.
- The historical support witness that #156 describes was not restored by PR #348.

### How often #156 blocks a correct answer

| | correct answers (excess ≤ 1e-4) | uncertified |
|---|---|---|
| Whole matrix (948 runs, 80 problems) | 265 | 81 (30.6%) |
| Problems with an exact-fit optimum | 77 | **77 (100%)** |
| Other problems | 188 | 4 (2.1%) |

- Only 6 of the 81 have r̂ = 0 exactly (`:undefined`). The other 75 have a tiny nonzero residual whose direction is rounding noise (`:failed`).
- The missed runs are few because CD rarely reaches the right exact fit: on problems with an exact-fit optimum, 633 of 710 runs stop at a nonoptimal exact fit (#155).
- In the realistic λ/4 designs of the #155 report, no run ends near-optimal but uncertified; every exact-fit case there is a #155 stop.

### Mathematics

- At r = 0, β is optimal iff some θ satisfies `‖θ‖ ≤ 1`, `X_Sᵀθ = λs` and `‖X_{S^c}ᵀθ‖∞ ≤ λ`. Every such θ has θᵀy = P(β), so certification is feasibility.
- When the support equations are consistent (s ⊥ null(X_S)), the support-equation solutions form θ₀ + range(X_S)^⊥ with θ₀ = (X_Sᵀ)⁺λs; otherwise there is none and β is not optimal. Θ is the intersection of these solutions with the off-support slabs ‖X_{S^c}ᵀθ‖∞ ≤ λ.
- If Θ is nonempty, its minimum-norm element is θ* = −Xd*, where d* minimizes ½‖Xd‖² + λsᵀd_S + λ‖d_{S^c}‖₁. β is optimal iff ‖θ*‖ ≤ 1; otherwise d* is a descent direction. If Θ is empty, that objective is unbounded below and some d ∈ null(X) with λ(sᵀd_S + ‖d_{S^c}‖₁) < 0 descends.
- **Validation of any candidate.** `P(β) − tθ̂ᵀy = (‖r‖ − tθ̂ᵀr) + Σ_k(λ|β_k| − tβ_k X_kᵀθ̂)`, valid for any θ̂ and β with tθ̂ feasible.
  - A 57-line Float64 outward-rounded validator built on this identity reproduced today's 184-point certified set when θ̂ = r̂/‖r̂‖, with different bounds (it also uses t·(θ̂ᵀy)_lo and (P_up − D_lo)/D_lo). It was sound in about 5,000 BigFloat-checked points and 30,000 fuzz cases.
  - About 70% of `_certify!` is reused. The new parts are one column loop on θ̂, two dot products, and no cap of t at 1.
  - A search for θ̂ is never a proof. Only this validator decides.

### Alternatives compared (certified / N; 0 false certifications in every cell; NEG = 683 nonoptimal stuck points)

| method | missed (81) | exact-fit optima, rounded (119) | NEG (683) | needs |
|---|---|---|---|---|
| residual direction (today) | 0 | 0 | 0 | — |
| A: least-norm support solution | 37 | 72 | 0 | thin SVD/QR of X_S |
| **Bcm**: A + bounded null-space correction (Cholesky of G_S + 1e-12 ridge, alternating projection onto violated slabs and the ball, ≤ 500 sweeps, small support-drop ladder) | **75** | **119** | 0 | \|S\|×\|S\| Cholesky, about 40 lines + validator |
| C: Clarabel feasibility (oracle only) | 75 on the three tested support-drop choices (same as Bcm) | 119 | — | not for production |
| D: directional lasso by CD | 61 (+20 refuted) | 112 | 0 (683 refuted) | no factorization; slow on ill-conditioned supports |
| E: dual bound from a smoothed solve, transplanted to the point | 38/38 F64, 30/43 F32 (43/43 in Float64 working precision) | 59/60 F64, 16/59 F32 | 0 | a second solve |

Notes:
- **Bcm's 6 misses:** for each, Clarabel reported infeasibility on all three tested support-drop choices (drop budgets 1e-6, 1e-5, 3e-5 of ‖β‖₁). The 75 successes match Bcm on this ladder; this does not establish a ceiling over other supports or general approximate dual certificates.
- **Gate:** the proposed design applies |S_eff| ≤ n to each effective support after dropping, before its Gram factorization (the prototype has no gate). At dense stuck points the Gram + Cholesky costs 0.07 s (|S| = 1000) to 6.1 s (|S| = 10,000).
- **Agent C's stress run:** in an independent run on 200 uncertified stuck points, Bcm made 0 false certifications on 152 nonoptimal points and certified 44 of 48 optimal ones (it missed a κ = 1e10 low-rank case and one |S| > n Float32 case).
- **Float32:** among the missed Float32 points the residual-to-objective scale ‖r‖/P reaches 6.1e-5 (the true excess of that point is 1.8e-5). A stored Float32 point is intrinsically uncertifiable at 1e-4 only if its true relative excess exceeds 1e-4; failing to find an accurate witness does not establish that.
- **Residual size cannot replace a witness:** at the Float32 floor, 335 nonoptimal and 37 optimal uncertified runs have the same residual distribution.

### Recommendation for #156: DOCUMENT ONLY now

- A standalone certificate does not pay for itself. It certifies only the uncommon runs where CD already found the correct exact fit, and it adds a factorization, a projection loop and a generalized validator.
- The smoothing-with-dual-bank escape proposed on #155 returned certified answers for all 81 missed cases in the rigorous Float64 replay: the original point was kept in 38/38 Float64 and 41/43 Float32 cases, and two Float32 cases needed a changed stage point. The replay used the generalized validator; whether exposing `_certify!`'s dual lower bound and a primal upper bound alone gives the same coverage is a check for the proposed confirmation round.
- If #155's escape is declined, Bcm (as specified above, gated to |S| ≤ n, validator as final judge) is the recorded design for a separately approved certificate.
- Example 09's #156 section stays correct until either change lands.

Reviewer: independent Codex review (GPT-6.1-sol, high effort), two rounds; every finding is resolved, the last one by the reviewer's own wording. Evidence: [archive link].
