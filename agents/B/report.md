# Agent B report: strategies to escape non-optimal exact fits (#155)

Research only. No production code changed, no commit, no worktree created (all prototypes call the unmodified production
solver `ps_solve` and certificate `certify_at` through `scripts/common.jl`). All paths below are under
`R/agents/B/` with R = `<RUN>`.
Prototype library: `escape.jl`. Runner: `run_matrix.jl CAND OUT [idregex] [T]` (env `STARTS=oracle`, `ORACLE_PLAIN=1` for 1.10).
Raw per-run data: `out/*.tsv`. Summary tables: `out/tables.txt`, `out/dgrid.txt`. Commands: all runs were
`julia --project=$R/env agents/B/run_matrix.jl <CAND> <OUT>` (1.13) with `OPENBLAS_NUM_THREADS=1`; the 1.10 runs use
`ORACLE_PLAIN=1 julia +lts --project=.../ProximalSolvers.jl-issue155 ...` and an id subset (see Finding 10).

## Findings (headline)

1. **Exact-fit optimality is a minimum-norm question, and it also yields the escape direction (proved, checked).**
   At an exact fit β is optimal iff ‖θ_min‖ <= 1, where θ_min is the minimum-norm point of
   Θ(β) = {θ : X_Sᵀθ = λ s, ‖X_{Sᶜ}ᵀθ‖∞ <= λ}; a descent direction exists iff ‖θ_min‖ > 1 (section 1.3). 60/60 random
   instances agree with a SOCP oracle (`out/math_checks.txt`).
2. **Single-coordinate and bounded-block moves cannot work in general (proved).** X = I_n, y = 1, λ in (1/√n, 1/√(n−1)) needs
   all n coordinates; the needed block size is ⌊1/λ²⌋+1 (verified n = 2..7). Candidate B confirms: 2/386 certified in F64.
   Nullspace-only moves are insufficient (#155 has det X = 0.01) but are the escape when |S| > rank X_S (section 1.2).
3. **Best candidate: smoothing continuation with a dual bank (D2).** Production solver on the smoothed problem; keep the best dual lower
   bound seen at any stage; certify either the original stuck point (returned unchanged if it is optimal) or the stage point.
   Julia 1.13, 763 triggered runs: F64 **386/386 certified** (347 via a stage point, 39 via transfer to the unchanged point), F32 **325/377
   certified**; every uncertified F32 run has an honest finite gap 1.0e-4..4.6e-4; 0 false certifications, 0 failed escapes.
   Caveat: D2's dual/primal numbers are computed in BigFloat in the prototype (production needs `_certify!` to expose its D_lo).
4. **Plain smoothing with the production certificate (D)** escapes every nonoptimal run (F64: 380/386 certified, 6 optimal but uncertified;
   F32: 23 certified, 354 optimal but uncertified). It moves optimal exact fits by up to 1e-4 relative, and in F32 it cannot certify because the
   production certificate pairs the dual and the primal point of the same stage (finding 3's bank fixes exactly that).
5. **λ-continuation (E)** (a pure wrapper) reaches an optimal point in 308/347 (F64) nonoptimal runs but certifies nothing new (it ends at exact-fit optima
   that the residual certificate cannot certify), returns points with many nonzeros (304/347 have nnz > n), and leaves 39-40 runs nonoptimal.
6. **The directional-lasso step (C)** is the right theory but a slow escape: with 100 outer x 100 inner steps it still leaves 256 (F64) nonoptimal;
   each exact line search ends at the first zero crossing (a simplex-like pivot). Its value is as a test (ρ(d) > 1 iff not optimal).
7. **Zero restart (A)** helps only the fixtures: A1 (accept 0 if F(0) < F(β)) fixes 14/347 (F64); a full CD solve from 0 (A2) fixes 47/347, because CD from 0
   itself ends at nonoptimal exact fits (101 of 160 zero-start F64 baseline runs).
8. **No false certification anywhere** (every certified run checked against oracle D: excess <= 1e-4, max certified excess 9.9e-5 for D/D2, which stop at the first certified point).
9. **Rounding can fool the decrease test** (`out/rounding_test.txt`): in T arithmetic 22 of 1014 F32 line-search steps are misjudged (21 true decreases rejected,
   1 true increase accepted); the Float64 evaluation with an error margin accepted 0 true increases and refused the 2 true increases created by rounding β to Float32.
10. **Julia 1.10 subset** (126 triggered runs per type) agrees with 1.13 on 282/288 rows (section 5). **Recommended: D2**, one attempt per solve, <= 8 stages,
    charged to `maxpasses`; ~100-130 lines in `src/cd/`, no O(np) buffer if δ is handled inside the model (section 4).

## 1. Mathematics

Notation: exact fit r = y − Xβ = 0, S = supp β, s = sign(β_S), a_k = ‖X_k‖², h(d) = λ(sᵀd_S + ‖d_{Sᶜ}‖₁).

**1.1 Directional derivative (exact).** For t > 0 small, y − X(β+td) = −tXd and ‖β+td‖₁ = ‖β‖₁ + t(sᵀd_S + ‖d_{Sᶜ}‖₁), so
F'(β;d) = ‖Xd‖ + h(d). Checked by finite differences on #155 (`out/math_checks.txt`, section 1).

*Single coordinates.* d = δe_k: k ∉ S gives F' = |δ|(‖X_k‖ + λ) > 0, never descent. k ∈ S gives F' = |δ|‖X_k‖ + λ s_kδ, negative
(δ = −s_k) iff ‖X_k‖ < λ. That is exactly the production branch `λ ≥ √a ⇒ 0`; otherwise CD is blocked. On #155: d = e_1:
F' = 1.1, −e_1: 0.9, ±e_2: 0.9/1.1 (all positive).

**1.2 Nullspace-only corrections are insufficient.** d ∈ null(X) keeps r = 0 and F' = h(d) = λ(sᵀd_S + ‖d_{Sᶜ}‖₁): it only decreases the ℓ1 norm
on the affine set {Xβ = y} (a basis-pursuit LP). In #155, X = [1 1; 0 .01] has det = 0.01, so null(X) = {0} and the exact-fit set is {β}: no
nullspace move exists, yet F(β) = 0.2 > F(0) = 0.01. Escaping requires the residual to increase. Descent direction d = −β = (−1, 1):
F'(β;d) = ‖Xd‖ + λ sᵀd = 0.01 − 0.2 = −0.19. Along d the exact line is φ(t) = ‖tXβ‖ + λ(1−t)‖β‖₁ (t ≤ 1) = 0.01t + 0.2(1−t),
slope −0.19, minimizer t = 1, i.e. β − β = 0, F = 0.01 = P* (λ ≥ λmax = 0.01). In general at an exact fit
φ(t) = t‖Xd‖ + λ‖β+td‖₁ is convex piecewise linear (breakpoints −β_k/d_k), and its exact minimizer is found by sorting breakpoints (O(p log p) after
one product Xd); for r ≠ 0 each segment is √(C(t−t0)²+δ²) + c·t with the closed-form minimizer t0 − cδ/√(C(C−c²)) (`line_min`).
The line d = −β is candidate A: its minimizer is t = 1 iff ‖y‖ < λ‖β‖₁, i.e. F(0) < F(β).
Conversely nullspace moves are *the* escape when X_S is rank deficient: with |S| > rank X_S (CD stops with 14-20 nonzeros at n = 8) and
s ∉ range X_Sᵀ, a direction d ∈ null(X_S) with sᵀd_S < 0 exists; these points are (generically) not optimal.

**1.3 Theorem (exact fits).** Let ρ(d) = −h(d)/‖Xd‖ (∞ if Xd = 0, h < 0) and ρ* = sup_d ρ(d). Then (i) F'(β;d) = ‖Xd‖(1 − ρ(d)),
so a descent direction exists iff ρ* > 1; (ii) the *directional lasso* ψ(d) = ½‖Xd‖² + h(d) has minimum −½ρ*² and, with θ_min the
minimum-norm element of Θ(β), ρ* = ‖θ_min‖ (ρ* = ∞ iff Θ(β) = ∅); (iii) β is optimal iff ρ* ≤ 1.
*Proof.* Scaling d to τd gives ψ(τd) = τ²‖Xd‖²/2 + τh(d), minimized (for h(d) < 0) at τ = −h/‖Xd‖² with value −ρ(d)²/2; maximizing over directions gives (i) and ψ* = −ρ*²/2.
For the dual write ½‖Xd‖² = max_θ(θᵀXd − ½‖θ‖²); then min_d max_θ = max_θ min_d, and min_d[(Xᵀθ + λs)_S·d_S + λ‖d_{Sᶜ}‖₁ + (Xᵀθ)_{Sᶜ}·d_{Sᶜ}] is 0 if
X_Sᵀθ = −λs and ‖X_{Sᶜ}ᵀθ‖∞ <= λ, and −∞ otherwise; so ψ* = −½ min{‖θ‖² : θ in −Θ(β)} (the minimizer d* has θ = Xd*). For (iii): for θ in Θ(β), θᵀy = θᵀXβ = λ‖β‖₁ = P(β), so β is optimal
iff Θ(β) meets the unit ball iff ‖θ_min‖ <= 1. ∎
Checks: #155: θ_min = (0.1, −20), ρ* = 20.00025 (CD on ψ converges to it; extremely slowly, 1e5 passes, because X is ill-conditioned; but only
ρ > 1 is needed). #156: ρ* = ‖θ_min‖ = 0.1414 = the θ = (0.1, −0.1) of the issue (optimal). Random check:
60 exact-fit points (32 optimal, 28 not): (‖θ_min‖ ≤ 1) == (SOCP says optimal) in 60/60; CD-ψ's ρ vs the QP's ‖θ_min‖ within 1.3e-6 relative.
So the same sub-problem yields both a certificate for optimal exact fits (#156) and a descent direction (#155).

**1.4 Bounded blocks do not suffice (AI3 and its generalization).** For T ⊂ {1..n} and d supported on T the best ratio is
ρ_T = λ √(s_Tᵀ(X_TᵀX_T)⁻¹s_T) (equality-constrained min-norm θ; extra coordinates only add constraints, so ρ_T is monotone in T). For X = I_n, y = 1, β = y
(S = all, s = 1): ρ_T = λ√|T|, so a block T descends iff λ√|T| > 1 iff |T| > 1/λ². With λ ∈ (1/√n, 1/√(n−1)) only |T| = n works. Verified by enumeration of all
blocks for n = 2..7 (`out/math_checks.txt`, section 2: best ρ by block size, e.g. n = 3, λ = .6422: [.642, .908, 1.112]; first descending size = n, equal to ⌊1/λ²⌋+1 each time).
For any fixed bound K on the block size take n = K+1: a counterexample. The line-search along −β escapes here (F(0) = √n < λn = F(β)), but #155-type
cases with F(0) ≥ F(β) need other directions (and the noiseless matrix cases, where ‖y‖ = 10.6 ≫ F(β) = 2.59, are of that type).

## 2. Candidates: what was prototyped (`escape.jl`)

Acceptance of an escape on the ORIGINAL objective: F̂ = ‖r̂‖ + λ‖β‖₁ with r̂ recomputed in Float64 from the T data (exact products for F32) and an error
bound E = (m+1)ε‖μ̂‖ + (m+2)ελ‖β‖₁ (the model of step 1 of `_certify!`); accept iff F̂_new + E_new < F̂_old − E_old (`strict_decrease`). Never the cached residual.
Rounding fooling: see Finding 9 and section 3.5.

* **A1** accept β = 0 if strictly better, then CD. **A2** also a full CD solve from 0, keep the strictly better point.
* **B** best pair (j,k) ⊂ S by closed form (G⁻¹s, nullspace direction for collinear pairs; |S| ≤ 64), exact line search, accept on decrease, resume CD, ≤ 8 escapes.
* **C** directional lasso by CD in T (`dirlasso`: stop when ρ ≥ 2, or ψ stalls = converged (then ρ ≤ 1 certifies optimality of the exact fit), or 200 passes), exact line search on F, snap
  zero-crossings to 0, strict-decrease acceptance, resume CD, ≤ K outer escapes. `C` = one step per escape (K = 8); `Cm` = up to `inner` steps without CD in between.
* **D** smoothing: stage j solves F_δj by the production solver on augmented data (ỹ = [y; δ], X̃ = [X; 0ᵀ]) warm started, δ_j = c0·F̂(x₀)·q^j; after every stage `certify_at` on the original data; after J
  stages a production polish; uncertified results are accepted only on strict decrease. **D2** = D plus the dual bank (below).
* **E** λ-continuation: λ_j geometric from 0.9λmax to λ in 10 stages from 0, production CD each, keep the better of {stuck, path end}.

**D2 details (the distinguishing idea).** After stage j, θ_j = t r̂/‖r̂‖ (t = min(1, λ/‖Xᵀr̂/‖r̂‖‖∞)) is dual feasible, so D_j = θ_jᵀy ≤ P*. Keep D_bank = max_j D_j. Any primal point c is certified when
(P(c) − D_bank)/D_bank ≤ prevfloat(1e-4). Test the original point x₀ first (an optimal exact fit is then returned *unchanged*), then the stage point. The prototype evaluates D_j and P(c) in BigFloat (a research
stand-in; production already forms an outward-rounded D_lo inside `_certify!`, which would need to be exposed, plus a rigorous upper bound on P(x₀)). Numbers of "certified" for D2 are therefore for an exact check, not the production certificate; the oracle-D check (Finding 8) shows no false certification.

Dual defect vs δ (`dbg5.jl`, F32, N8p20-0.2-s1, schedule c0 = .1, q = .3): (P*−D_j)/P* = 1.5e-5 at δ = 0.26 (j=0), 1.3e-4 at δ = .023, 2e-3 at δ = 2e-3, then grows to O(1) once ‖r̂‖ reaches the F32 noise floor ~5e-7;
the primal excess is the opposite (0.021 at j=0, 5.1e-5 at j=5, 2.3e-7 at j=10). The own-stage ratio (P_j − D_j)/D_j never drops below 1.2e-3 in this F32 instance; the cross-stage pairing (early dual, late primal) reaches 1e-4 at j≈5.
That is why D (same-stage) cannot certify F32 and D2 can.

## 3. Experiments (Julia 1.13, full preregistered matrix)

Setup: stage 1 = production `ps_solve` with baseline configs (a FRESH `Xoshiro(7)` per run for random-owner, as in the brief; the orchestrator notes that `baseline.jl` shares one RNG object across runs, so my random-owner stage-1 points differ from `baseline_1.13.tsv` in 296 rows by excess, and 14 of 948 rows change class: 8 missed-cert->nonoptimal, 5 nonoptimal->missed-cert, 1 nonoptimal->certified, all random-owner; cyclic rows match exactly, 474/474. I did not replay from Agent A's `final_points.jls`; each stage-1 point is classified by me). Every start of the matrix is used (zero, given, lnfit, warm; both T, both configs): 948 runs, of which 763 end uncertified (trigger;
F64 386 = 347 nonoptimal + 39 optimal-but-uncertified; F32 377 = 338 + 39). The fallback runs only after an uncertified stop, so the other 185 runs are untouched by construction (they execute the same code path; final = stage 1).
Classes: certified (converged, excess ≤ 1e-4), optimal-uncert (not certified, excess ≤ 1e-4 vs oracle D), nonoptimal, FALSE-CERT (certified but excess > 1e-4): **0 FALSE-CERT in every file**.

### 3.1 All triggered runs (`out/tables.txt`, Table 1; files in parentheses)

| candidate | T | cert | optimal-uncert | nonoptimal | base155 now optimal | base156 (n=39): cert/same/moved |
|---|---|---|---|---|---|---|
| A1 zero-compare (A1_113) | 64 | 14 | 39 | 333 | 14/347 | 0/39/0 |
| A1 | 32 | 6 | 39 | 332 | 6/338 | 0/39/0 |
| A2 zero restart (A2_113) | 64 | 28 | 58 | 300 | 47/347 | 0/31/8 |
| A2 | 32 | 19 | 61 | 297 | 41/338 | 0/28/11 |
| B best pair (B113) | 64 | 2 | 45 | 339 | 8/347 | 0/38/1 |
| B | 32 | 2 | 43 | 332 | 6/338 | 0/38/1 |
| C one dir-step x 8 (C113) | 64 | 28 | 45 | 313 | 34/347 | 0/12/27 |
| C | 32 | 19 | 44 | 314 | 24/338 | 0/19/20 |
| C multi 30x8 (Cm113) | 64 | 28 | 92 | 266 | 81/347 | 0/12/27 |
| C multi 30x8 | 32 | 19 | 91 | 267 | 71/338 | 0/19/20 |
| C multi 100x100 (Cm_big) | 64 | 28 | 102 | 256 | 91/347 | 0/12/27 |
| C multi 100x100 | 32 | 19 | 99 | 259 | 79/338 | 0/19/20 |
| E λ-path (E113) | 64 | 28 | 319 | 39 | 308/347 | 0/9/30 |
| E | 32 | 19 | 318 | 40 | 298/338 | 0/9/30 |
| D smoothing, production cert (L1: c0=.3, q=.2, J=8) | 64 | 380 | 6 | 0 | 347/347 | 39/0/0 |
| D | 32 | 23 | 354 | 0 | 338/338 | 4/10/25 |
| **D2 smoothing + dual bank (K7: c0=.3, q=.2, J=8)** | 64 | **386** | 0 | 0 | 347/347 | 39/0/0 |
| **D2** | 32 | **325** | 52 | 0 | 338/338 | **39**/0/0 |

"moved" = final excess differs from the stage-1 excess by > 1e-12 (all stay ≤ 1e-4; none "bad"). The 28 (F64) / 19 (F32) certified runs of A2, C and E are the same ones (analytic #155 and AI3 given starts, 14 sweep and 10 correlated runs where the escape lands at a non-exact-fit optimum).

Per family (D2, `out/tables.txt` Table 3): all families certified in F64 (n8p20, n40p120, n100p400, near-exact, correlated, duplicate columns, sweep, fixtures); F32 non-certified only in
n8p20 (8 of 96) and the λ-sweep SW0.1/0.2 (44 of 48), with honest gaps. Never triggered (untouched, final = stage 1): O60p20 (72 runs), SW0.4 (40), SW0.3 (25), C95 (40), analytic #155/AI3 zero starts (8): 185 of 948 runs.

### 3.2 Cost (Table 2; fallback only, triggered runs)

| candidate | passes med / p90 / max (F64) | passes / stage-1 passes (med) | stages | wall med / max (s) | alloc med / max (MB) |
|---|---|---|---|---|---|
| A2 | 43 / 248 / 5 904 | 1.3 | 0-1 | 1e-4 / 0.10 | 0.01 / 9.6 |
| B | 0 / 0 / 24 (+ O(|S|²n) Gram) | 0 | ≤ 8 escapes | 1e-4 / 0.83 | 0.39 / 78 |
| C 30x8 | 3 027 / 9 567 / 16 520 | 138 | 8 | 4.4e-3 / 0.81 | 5.1 / 87 |
| C 100x100 | 13 642 / 88 801 / 341 260 | 699 | up to 100 | 1.9e-2 / 0.73 | 21 / 3 601 |
| E | 232 / 1 352 / 9 220 | 12 | 1 path of 10 | 2e-4 / 0.21 | 0.09 / 32 |
| D (L1) | 231 / 4 190 / 109 288 | 23 | 6 (max 8) | 3e-4 / 0.35 | 0.23 / 54 |
| D2 (K7)* | 221 / 4 144 / 89 268 | 22 | 5 (max 7) | see note | see note |

F32 rows are similar (`out/tables.txt`). *D2's wall time and allocation in the prototype include BigFloat (median 7 ms, 13 MB); a production D2 costs the passes of D plus O(np) Float64 work per stage (the
dual bound is one residual and one Xᵀr; D's timings are the right estimate). Context: the baseline certified runs take median 48 passes (p90 544, max 1 286); the matrix problems are small (n ≤ 100, p ≤ 400), so seconds are not representative; passes are.
The heavy tail (≥ 20 000 passes, max 89 268 for D2) is from the near-singular λ-sweep problems SW0.1/0.2-s3 (cyclic) where CD on F_δ is itself slow; capping each stage hurts: per-stage cap 2000 passes leaves 7 runs
nonoptimal, cap 500: 35, cap 200: 108 (`out/H2..H4.tsv`).

### 3.3 Smoothing schedules (`out/dgrid.txt`; D with production certificate, then D2)

D (production certificate, relative scale F̂(x₀)): c0 = .01, q = .1, J = 8 (D_a): 366 F64 certified, 11 nonoptimal (J too small). c0 = .1: q = .5, J = 30 (D_b) 380; q = .25, J = 15 (D_c) 380; q = .1, J = 8 (D_d) 377;
floor 1e-6‖y‖ (D_e) 384; c0 = 1, q = .3, J = 20 (D_g) 383; c0 = .1, q = .5, J = 30, floor 1e-5 (D_f) 385; c0 = .1, q = .3, J = 20 (H1) 381; scale min(F̂, ‖y‖) (H7): same 381 (no effect). F32: always 23 certified (the production certificate pairing), 354 optimal.
D2 (F64/F32 certified of 386/377): c0 = .03, q = .3, J = 12: 382/190 (too small a start δ degrades the dual); c0 = .1, J = 12: 386/290; **c0 = .3, J = 12: 386/329**; c0 = 1: 386/327;
c0 = .1, J = 8: 386/290; J = 6: 386/285; **c0 = .3, q = .2, J = 8: 386/325 with 5 stages median, 221 passes median** (K7); c0 = .1, q = .5, J = 12: 386/297 (K8). Ablation (D2 with c0 = .1, q = .3, J = 20): without transfer 386/290 (G0), with transfer 386/290 (G1) (same counts, different returned point), without the cross-stage bank and without transfer 381/23 (G00), i.e. the production behaviour: the bank is what lifts F32.
Reading: (a) a start δ ≈ 0.1-0.3 F̂ gives the best dual bound in F32; (b) ≥ 6 stages suffice in F64, 8 in F32 (δ_min ≈ 4e-6 F̂, a floor of order 1e-5 F̂; the F32 noise floor is ‖r̂‖ ≈ 5e-7-1e-6, i.e. 16 eps(F32)‖y‖ = 1.9e-6‖y‖ is the
natural lower bound for δ and is what `floor64` already is); (c) the scale F̂(x₀) (an upper bound for P*) works, with min(F̂, ‖y‖) no different; (d) δ_min must satisfy δ_min ≲ 1e-4·P*, which F̂ ≥ P* guarantees only up to the factor F̂/P* ≤ 20 on the matrix, absorbed by c0 q^(J-1) = 4.8e-6.

### 3.4 Oracle-start experiment (can a candidate leave an OPTIMAL exact fit unchanged?)

Start at the oracle optimum rounded to T for the 60 exact-fit problems x 2 configs (120 F64 runs, 118 F32 runs), stage 1 = production CD, which leaves 118 uncertified (`out/O_*.tsv`, Table 4):
A2, B, E, C leave the point optimal (max excess 2e-8 F64, 8.9e-7 F32; C and E move some of them within ≤ 1e-6). **D** certifies 118/120 (F64) but moves the point to a smoothed stage point with
excess up to 9.6e-5; in F32 it certifies 2/118 and otherwise returns the stuck point (no strict decrease). **D2 returns the exact-fit optimum unchanged in 120/120 (F64, all certified, 118 via transfer) and 118/118 (F32, 99 certified, 19 honest gap)**.
A156 itself (F64): D2 certifies the unchanged β = (1, 0) after 46 passes (1 stage); D certifies after 182 passes (5 stages) at excess 6.0e-5.

### 3.5 Rounding test (`rounding_test.jl`, `out/rounding_test.txt`)
Steps of candidate C on 8 problems x {F64, F32}: 1 014 F32 steps: naive arithmetic in T gets the sign of ΔF wrong in 22 (21 "no decrease" for true decreases, 1 "decrease" for a true increase);
the Float64 + margin test accepted 0 true increases and refused the 2 true increases that the line search produced after rounding β to Float32; F64: 1 047 steps, no disagreement. The margin E is ~1e-13 here; no accepted decrease was below it in this test (the counter "true decreases below the margin" stayed at 0).

### 3.6 Why C and B fail beyond the fixtures (diagnosis, `dbg3.jl`)
At the stuck point of N8p20-0.2-s1 (17 nonzeros, 3 true) the coefficients are 3 large and 14 spurious in [1e-10, 5e-3]. The ψ direction descends, but the exact line search ends at the first zero crossing
(t ≈ 1e-7..1e-3), one coordinate leaves S per step (a simplex pivot); excess goes 1.436e-3 → 1.05e-3 in 12 steps. After the fix of a zero-snapping bug every step decreases F, but the
rate is linear in the number of pivots (up to |S| − n and back-and-forth). B only sees pairs inside S; at nonoptimal exact fits with |S| > n a descent direction needs a circuit of up to n+1 columns.

## 4. Failure cases, bounds, complexity, recommendation

**A1/A2.** Fail when F(0) ≥ F(β) and CD from 0 reaches a nonoptimal exact fit (noiseless underdetermined families). Cost: 0 / one solve. Complexity ~15 lines. Not recommended (14-47 of 347).

**B.** Success requires the descent block to fit the budget; counterexample family 1.4; |S| > n needs circuits up to n+1. Worst case O(|S|²n) per escape. ~60 lines. 2/386.

**C.** Rigorous stopping (strictly decreasing F), ≤ K·inner steps, each ≤ 200 ψ-passes, so ≤ K·inner·200 passes plus CD; but progress per step is tiny and CD resumption re-expands the support (nnz returns to 14-20). Buffers: d, u, a (n+p+n) lazily.
~100 lines (dirlasso 35, line search 40, loop 25). Failure: slow pivoting (256 nonoptimal at 100x100 budget), ill-conditioned ψ (A155 needs 1e5 passes to converge, 6 to leave). Keep only as an *optimality test* if wanted: ρ(d) ≤ 1 at a converged ψ = optimal exact fit.

**E.** Fails where the path enters the exact-fit region at a nonoptimal support (39-40 runs), returns many-nonzero optima (304/347 have nnz > n), cannot certify, 10 solves. ~30 lines, no new buffers.

**D / D2.** Bounded by J stages (8) + one polish, each a production solve; recommended to charge all passes to the user's `maxpasses` (default 1e5), which bounds total work by the existing budget. Failure modes:
(1) near-singular problems cost up to 9e4 passes (SW0.1/0.2-s3), (2) F32: 52/377 stay uncertified with honest gaps 1.0e-4..4.6e-4 (the dual from Float32 stage points is limited by ‖r̂‖ ≥ 1e-6; an option not tested
is to run the stages on Float64 copies of the rounded data), (3) D without the bank moves optimal points by ≤ 1e-4. Implementation (estimate, not prototyped in the source):
- `src/cd/sqrtlasso.jl`: field `δ²::T` (0 by default) added to `ρ2` before the d² formula in `_sqrt_minimizer` (the augmented column is [X_k; 0], so a, b are unchanged and d² = ρ²+δ²−b²/a), and in `_sqrt_offrange_step` (+3 lines); `_certify!` returns D_lo (+6 lines) and a rigorous P_up(β) helper reusing step 1 (+20 lines). No O(np) buffer
  (the augmented-data prototype copies (n+1)·p·sizeof(T) bytes per stage; the in-model form copies nothing).
- Sparsity of the final points (nnz > n among optimal finals): D 6/386 (F64), 341/377 (F32); D2 35/386, 128/377; E 304/347 (F64). Smoothed solutions are basic-like in F64; F32 points carry rounding-level coefficients.
- `src/cd/solver.jl`: after the loop's `:uncertified` outcome, a fallback driver (~50 lines: schedule, stage solves reusing `_run_cd!`/`st`, bank, candidate tests, polish, acceptance rule), allocation only when it runs (scalars).
- ~100-130 lines of code, ~80 of tests. The existing `_stop_check!` tightenings stay; the fallback starts after them.
The equivalence augmented-data ⇔ in-model δ is an algebraic identity (a, b, ρ²+δ², and the cached r are what the step uses); it was not re-measured in code.

### Recommended escape design: D2 (smoothing continuation with a dual bank)
- **Trigger.** `_stop_check!` returns `:uncertified` (after its ≤ 2 tightenings), maxpasses not exhausted, once per `solve!`. Nothing runs for certified stops or `:capped` runs; the matrix confirms
  185/948 runs (all ordinary O60p20, SW0.3/0.4 mostly, C95 half, analytic zero starts) are never triggered and execute the identical stage-1 path.
- **Schedule.** x₀ = stuck point, F̂₀ = rigorous F(x₀), δ_j = 0.3·0.2^j·F̂₀ for j = 0..7, but not below max(1e-6 F̂₀, 16 eps(T)‖y‖); stage j = production CD on the smoothed problem, warm started, at the user's tolerance.
- **Bank and acceptance.** After each stage compute D_j (rigorous outward-rounded, from the stage residual direction) and D_bank = max_j D_j. Return x₀ unchanged and certified if P_up(x₀) − D_bank ≤ 1e-4·D_bank;
  otherwise the stage point if its own ratio against D_bank is ≤ 1e-4; after stage 8 a production polish on the original problem and the same test. Otherwise return the point with the smaller *rigorous* F upper bound
  (strict decrease with the error margin; else x₀) as uncertified, with the honest ratio (P_up − D_bank)/D_bank available for the warning (1.0-4.6e-4 in the F32 failures).
- **Budget.** ≤ 8 stages + 1 polish, all charged to `maxpasses`; ≤ 1 escape attempt per solve; no repeated trigger.
- **Not recommended:** A, B, C as the escape; E only as a pre-conditioner. If the maintainer prefers not to touch `_certify!`, plain D (no bank) already escapes every case and certifies F64 at the price of moving optimal points by ≤ 1e-4.
- Overlap with #156: D2 certifies all 39 optimal-but-uncertified runs per type (F64 and F32); if the #156 witness lands separately, D2 reduces to its escape role (D with the stage dual used for transfer).

## 5. Limits and open questions

- "Certified" for D2 uses a BigFloat dual in the prototype; the production version (outward-rounded D_lo, rigorous P_up) was not built. Expect it to certify slightly less often (error margins ~1e-13).
- Matrix problems are small (n ≤ 100, p ≤ 400); costs at n·p ~ 1e6 not measured. The 1.10 subset is 126 runs/type (below).
- The random-owner stage 1 differs from the baseline TSV (shared RNG object there; 14 class changes of 948, see section 3); my trigger set is 763 runs, not the baseline's 764 uncertified plus capped. Conclusions are unaffected (cyclic rows match exactly).
- D2/D fixed constants (c0 = .3, q = .2, J = 8) were tuned on this matrix (K1-K8, H1-H7 grids): conjecture that they transfer; no held-out set.
- C's convergence statements are measured, not proved (a proof of finite pivoting would need non-degeneracy).
- Only the stuck point's sign pattern S matters for C/B; dust coordinates (|β_k| ≈ 1e-10) were handled by the strict-decrease margin, not by thresholding.

### 1.10 subset (Finding 10; `out/S110_*.tsv`, `out/fixtures_110.txt`)
Julia 1.10.13, oracle fields and data read from `out/oracle_plain.tsv` / `out/data_plain.tsv` (written on 1.13; the generator differs between versions for larger problems, so the data are exported). Subset: 126 triggered runs per type
(A155/156/AI3, N8p20 s1-3, N40p120 s1-2, N100p400-s1, NE s1, SW0.1/0.3 s1-2, C95 s1-2, D10 s1-2, O60p20-s1). D2: F64 126/126 certified, F32 105/126; D (production cert): F64 126/126, F32 12/126; E: 8/102/16 (cert/optimal/non), Cm: 8/39/79, A2: 8/30/88 (F64).
Against 1.13 on the same rows: D2 final classes agree on 282/288 (266 certified both, 16 optimal-uncert both; 5 cases certified on 1.13 only, 1 on 1.10 only: F32 cases at the margin). The three fixtures give identical results on 1.10 and 1.13 (`diff` of `out/fixtures_11*.txt` is empty up to timings).

### Files
`escape.jl` (prototypes: fhat, dirlasso, line_min, escape_C/Cm/B/A1, fallback_A2/D/D2/E), `run_matrix.jl`, `fixtures.jl`, `math_checks.jl`, `rounding_test.jl`, `export_oracle.jl`, `common_plain.jl` (1.10 loader), `summ.py`, `dsumm.py`, `tables.py`, `dbg1-5.jl` (diagnostics),
`out/` (all TSVs/logs: candidates `A1_113, A2_113, B113, C113, Cm113, Cm_big, E113, D113, D_a..D_g, H1..H7, G0/G00/G1, K1..K8, L1`; oracle-start `O_*`; 1.10 `S110_*`; `tables.txt`, `dgrid.txt`, `math_checks.txt`, `rounding_test.txt`).
