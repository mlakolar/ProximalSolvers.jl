### R1. Square-root lasso: one fast formula, Float32 re-run in Float64, Float64 refusal outside the range of the sums — **GO, with a Julia 1.10 timing gate**

**Scope.** `src/cd/sqrtlasso.jl` only. No PB change, no pin change, no change to the certificate, the stop check, scheduling, the RNG or accepted-update semantics.

| | master `dac9f4b` | prototype |
|---|---|---|
| `_sqrt_offrange_step` (power-of-two scaled Float64 step) | 39 exec | deleted |
| `_sqrt_band_step` + `_sqrt_threshold64` (split-exponent threshold) | 12 exec | deleted |
| `_scaled_norm` | 14 exec | deleted; `_prepare!` calls the existing `_se_norm(Float64, y)` |
| `_sqrt_minimizer` | 21 exec, five-comparison band test, `prox_block(gt, c, k, γ)` | 12 exec: `τ = (λ/ra)·(d/(√(ra−λ)·√(ra+λ)))`, `shrink(c, τ)`, no band test |
| cold path | — | `_sqrt_cold`, two methods, 8 exec |
| file total (executable / physical) | 310 / 526 | 244–246 / 426–429 |

Removed: 64–66 executable lines (21 % of the file) and four concepts (the scaled shadow step, the split-exponent threshold, the band test, a third scaled-norm algorithm). Added: one concept, "a Float32 step outside the range is the same formula in Float64", which is the idea `_threshold(::Type{Float32}, …)` in `leastsquares.jl` already uses. The total of PB and PS decreases by the same amount; nothing moves.

**Why the band test can go.** With `a` and `ρ²` passing `_clean_sum` (finite and at least `n·floatmin/eps`), `ra = fl(√a) ≥ √(floatmin/eps)`, `d ≤ √floatmax` and `w = √(ra−λ)·√(ra+λ) ≥ ra·√(eps/2)` for `λ < ra`, so `d/w ≤ √(2·floatmax/floatmin) < floatmax` and `λ/ra < 1`: the product does not overflow, and it underflows only where the exact threshold does. A search over 120,000 inputs per type at that corner found no non-finite `τ` (largest `τ/floatmax` 0.354 in Float64, 0.420 in Float32).

**What changes for callers.**

- *Float32: no accepted input is lost.* Every step that leaves the fast path is re-run in Float64, where the squares of Float32 numbers and their sums stay in the normal range. Two scan points change from a refusal to a certified solve (master's centre `old + b/a` overflows there although the minimizer is representable).
- *Float64: a visit of a column that is not flat is refused* (`ArgumentError`, "rescale the data", before the coordinate or the residual changes) *exactly when one of these holds for the computed sums:* (i) `‖X_k‖² < n·2^-970`, whatever the residual, a zero residual included; (ii) `‖r‖² < n·2^-970` with `r ≠ 0`; (iii) `‖r‖²` is not finite. In norms: `‖X_k‖ < 1.0e-146·√n`, or `0 < ‖r‖ < 1.0e-146·√n`, or `‖r‖ ≳ 1.34e154`. A zero residual with a column in range (the usual exact fit) and `d = 0` (a residual parallel to the column) stay supported, and so do the Float64 band cases (`‖r‖/‖X_k‖²` beyond `1e±300` with both sums in range). A flat column takes the penalty's minimizer before this test, as on master.
- What master returns in the refused Float64 ranges today (public `solve!`, n = 30, p = 8, exact power-of-two rescalings):

| Float64 input | master | prototype |
|---|---|---|
| `‖X_k‖ ∈ [~6e-162, 1.0e-146·√n)`, residual in range (X scaled by 2^-539…2^-485) | converged, certified | refused |
| the same columns with `y = 0` and a zero start (e.g. `X = fill(1e-150, 2, 1)`, `λ = 1e-151`) | converged, `gap = 0` | refused |
| the same columns at an exact fit with a nonzero start (`y = X·1`, start 1) | returned unchanged, `converged = false` | refused |
| `‖y‖ < 1.0e-146·√n` (y scaled by 2^-1024…2^-485) | returned with `converged = false`, `gap = NaN` (the certificate is undefined there) | refused |
| `‖y‖ ≳ 1.34e154` (y scaled by 2^510…2^1021) | returned with `converged = false`, `gap = NaN` | refused |
| everything else | unchanged outcome class | |

So for an extreme `y` the recovery machinery already cannot produce a converged result; the tiny-column range changes from certified (or, at an exact fit, returned) to refused. The rows with `y = 0` and with an exact fit were found by the independent review and reproduced on both Julia versions.

**Correctness evidence** (Julia 1.10.13 and 1.13.4, Float32 and Float64, master and both prototypes loaded in one process on identical inputs).

- Coordinate steps against a BigFloat-512 closed-form minimizer on the rounded stored inputs, compared with `step_bound` of `test/sqrt_lasso.jl:305`: about 356,000 cases per Julia version in 12 families (ordinary, wide scales, nearly and exactly parallel residuals, an unclean recomputed `d²`, `λ` within 4 ulp of `√a`, sums within a factor 2 of the clean threshold, the corner "`ρ²` near the threshold, `d²` unclean, `λ/ra` up to `1 − 4 eps`", cold Float32 inputs, Float64 band inputs, subnormal `λ`; n from 1 to 2000). **No case exceeds the bound in any tree**; the worst excess/bound is 0.089, the same in the three trees. No prototype result is non-finite where master's is finite. Every prototype refusal where master returns matches the inequality above.
- Whole solves: 748 configurations per Julia version (Gaussian, correlated, collinear and exact-fit designs, five sizes, three levels, cyclic and random order, momentum on and off, dense and `SparseIterate`, cold and warm, `y = 0`, `p = 1`, `n = 1`). No change of `converged` and no new refusal. Float64, Gaussian and correlated designs: relative objective difference at most 5.9e-16 and identical pass counts. Float32: relative objective difference at most 2.1e-7; total passes over the certified cases 24,539 against 24,280 on 1.13 and 14,321 against 14,398 on 1.10 (single random-order Float32 runs move by −51 to +278 passes, in both directions).
- Every certified result of every tree (grid and scans, about 7,000 per tree and Julia version) rechecked with an independent BigFloat-256 dual point: true gap ≤ reported gap ≤ 1e-4, no violation.
- Repository tests: `test/sqrt_lasso.jl` 1408 of 1411 pass unchanged; the three errors are the Float64 unit cases at lines 359 (twice: column norm 7.1e-160) and 363 (residual norm 2.0e-319), which become `@test_throws`. Full suite: 68,212 passed, the same three errors.
- Refusals are transactional (24 runs per tree: dense and owner, cold and warm, cyclic and random; the caller's `x` is unchanged). The ordinary pass and the Float32 cold path allocate 0 bytes.
- The PB #896 exposure of the coordinate step (`ldexp` into the subnormal range on Julia 1.10, in the scaled recovery step and in the split-exponent threshold) disappears with those functions. Two `ldexp` calls remain in the file: the reconstruction of `‖y‖` for the tightening floor in `_prepare!`, and an exact one in `_certify!`.

**Performance evidence.** Paired in one process, every side compiled from source, order rotated over 15 rounds, minimum over batches per round, one pinned P-core of an i5-13600K, BLAS at one thread; `base1/base0` is a second copy of master (the A/A control). Entries are the range over cases of the per-case median ratio prototype/master, with the geometric mean.

| workload | Julia | prototype | A/A control |
|---|---|---|---|
| solves: to convergence, and 3 passes from zero (40 cases: 5 sizes × 2 levels × 2 types × 2) | 1.13.4 | 0.923–1.004 (0.978) | 0.995–1.009 |
| | 1.10.13, AVX2 target | 0.942–1.059 (0.992) | 0.983–1.024 |
| | 1.10.13, default target (goldmont on this CPU) | 0.964–1.126 (1.001) | 0.959–1.029 |
| per visit: column kernel + step formula at a fixed state, read-only (20 cases) | 1.13.4 | 0.947–1.039 (0.983) | 0.972–1.005 |
| | 1.10.13, AVX2 target | 1.004–1.106 (1.043) | 0.978–1.038 |
| | 1.10.13, default target | 0.983–1.146 (1.037) | 0.975–1.021 |

On Julia 1.13 the prototype is at parity or faster. **On Julia 1.10 it is not yet within the 5 % rule**: the solve to convergence at n = 30, p = 120, `λ = 0.1 λmax` is slower by 5.9 % (Float32) and 4.0 % (Float64) with the AVX2 target, and by 12.6 % and 7.7 % with the default target, at equal pass counts, and the three-pass solve of the same Float32 case by 5.3 % with the default target; the per-visit probe is slower by 0.4–10.6 % with the AVX2 target and by up to 14.6 % with the default target (Float64, n = 400, p = 40, zero state: 1.146, every one of the 15 rounds between 1.125 and 1.155 against a control between 0.992 and 1.019; 1.119 at the converged state). So the slowdown is not confined to p > n. One contribution is identified: PB's exported `shrink` (the max/min form) takes 4.9 ns in a dependent chain on 1.10 against 4.3 ns for the select form PB uses inside its own prox loops; the rest is not diagnosed. A variant that keeps master's arithmetic bit for bit (`prox_block` and the band test, band exits to the cold path) was also built: it keeps solves within 4.3 % but is 0.5–25 % slower per visit and refuses the Float64 band and every subnormal `λ`, so it is not the recommended form.

**Recommendation: GO**, as its own small PS issue and PR, with these conditions:

1. the Julia 1.10 solve and per-visit ratios are brought inside the A/A control, or the maintainer accepts the measured cost explicitly;
2. the Float64 refusal and the square-root section of `docs/src/numerics.md` (lines 568–611, which describe the scaled step) change in the same approved PR, with the three test assertions and one new refusal test;
3. #352 records the change of the Float64 extreme-`y` outcome from "returned uncertified" to "refused".

If the refusal is not wanted, or the gate cannot be met, the fallback is **R1-min**: delete `_scaled_norm` and call `_se_norm(Float64, ·)` at its two call sites (−13 executable lines net: the 14-line definition goes and the cold caller gains one; one duplicate algorithm fewer; `floor64` moved by at most 1e-15 relative in the 748-solve corpus and by up to 5e-14 at n = 10⁵, where the deleted sequential sum is the less accurate one; no outcome changed in 748 solves, and 2 of 456 targeted tiny-scale solves, both Float64, moved in the last bits).

Not recommended: refusing the Float32 cold inputs as well (4 more lines; loses Float32 data in physical units such as `y ~ 1e-19`, which certify today), relaxing the `_clean_sum` constant (violations up to 1152× the bound), or replacing the outward rounding in `_certify!`.
