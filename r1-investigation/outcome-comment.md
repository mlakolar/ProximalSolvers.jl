## R1 (square-root lasso range handling): investigation result — the larger simplification is not taken; only the duplicate `_scaled_norm` goes

Under the maintainer's rulings (no new refusal; fix the Julia 1.10 slowdown; if a straightforward form cannot keep behavior and performance, delete only the duplicate `_scaled_norm`), three forms were built and measured against master `bb20b6a` on Julia 1.10.13 and 1.13.4, Float32 and Float64. None was pushed. The orchestrator's decision follows the stopping rule: **R1-min**.

### What was tried

| | Form | Executable lines of `src/cd/sqrtlasso.jl` (master 310) | Range | Ordinary path | Cost |
|---|---|---|---|---|---|
| Stage 0 prototype | band-free fast path, Float64 refusal | 244–246 (−64 to −66) | **narrower** (ruled out) | last bits change; 1.10 up to +12.6 % per solve | — |
| **K** | master's fast path kept byte for byte; one rescaled Float64 step replaces `_sqrt_offrange_step`, `_sqrt_band_step`, `_sqrt_threshold64`; `_scaled_norm` deleted | 286 (−24) | unchanged | **bit-identical**, timing at parity | solves whose visits take the band exit are **2.7 to 20 times slower** |
| **K + band-free fast path** | as K, with the fast path forming the threshold in range and a local three-line soft threshold | about 285 (not built as one tree) | unchanged | last bits change in 1 to 4 % of steps; passes the 5 % gate, about 5 % faster per visit | a local copy of a private ProximalBase helper |
| **R1-min** | `_scaled_norm` deleted, its two callers use the existing `_se_norm(Float64, ·)` | 297 (−13) | unchanged | bit-identical | the tightening floor moves by about 1e-15 relative on the tested corpora (4e-14 at n = 10^5) |

### Findings

1. **Range can be kept without a refusal, cheaply in code.** After scaling the column and the residual by powers of two, the scaled sums lie between 1 and 4n, so the plain formula `τ̃ = (λ̃/√ã)·(d̃/(√(√ã − λ̃)·√(√ã + λ̃)))` needs no band test there, and one out-of-line step can serve all three exits of the fast path. Verification of K: 3,376,180 boundary-targeted steps per Julia version (sums at, just below and just above the clean threshold and the overflow edge; each band condition at `floatmin` and `floatmax`; `λ` at `√a` and its neighbours and subnormal; `r = 0`; `r` parallel to the column; `old` at 0, ±`floatmax` and subnormal; extreme exponent gaps) with 0 changes of outcome class and every returned value inside the step bound of `test/sqrt_lasso.jl` (worst excess/bound 0.061, the same as master); about 360,000 random steps in 12 families, 0 above the bound (worst ratio 0.12, as on master); 748 + 454 whole solves and the 158 square-root fingerprints bitwise identical to master, the two counterexamples of the Stage 0 review included; `test/sqrt_lasso.jl` 1411 / 1411 with no assertion changed; allocations equal. One guard was needed to keep master's outcome on 4 of the boundary inputs (a non-finite centre at the band exit, which master returns for `_visit!` to refuse).
2. **But K moves the band exit from an O(1) step to an O(n) one.** Master handles a threshold outside the normal range of the data type (`γ` or `γλ` not normal while both sums are in range) with a few Float64 operations after the fused kernel. K sends those visits through the rescaled step. On problems whose visits all take that exit (Float32 data with column and response scales about 26 decades apart; Float64 about 210 decades apart), 10 passes cost, candidate over master, paired in one process with an A/A control within 2 %:

   | type | n × p | Julia 1.10.13 | Julia 1.13.4 |
   |---|---|---|---|
   | Float32 | 30 × 10 | 2.9 | 3.6 |
   | Float32 | 200 × 40 | 6.2 | 11.6 |
   | Float32 | 1000 × 100 | 6.0 | 20.1 |
   | Float64 | 30 × 10 | 2.7 | 3.1 |
   | Float64 | 200 × 40 | 5.5 | 8.0 |
   | Float64 | 1000 × 100 | 5.4 | 11.1 |

   The ordinary control rows of the same run are at 0.94 to 1.00. Such data are far from ordinary, but master supports them at full speed, and keeping the cheap band step brings back exactly the two helpers whose removal is K's gain over R1-min (12 of the 24 lines).
3. **The Julia 1.10 slowdown of the Stage 0 prototype is the exported `shrink`, and nothing else.** On Julia 1.10, `max(v − c, 0) + min(v + c, 0)` compiles to two sign tests through a general-purpose register with data-dependent branches; on 1.13 it compiles to branch-free `maximum`/`minimum`. Single-factor variants, per visit on 1.10 against master: the exported `shrink` in place of `prox_block` 1.08 to 1.24; a select-form soft threshold 0.98 to 1.03; the band test removed with `prox_block` kept 0.983 and 0.994 (the two targets, at the cell where the prototype was slowest). The extra division of the band-free formula, the column view, the generic step method and the signature of the cold call each measure inside the control. (The separate slowdown of the Stage 0 variant that kept master's arithmetic came from an `iszero(d) |` term in its range test, which the vectorizer turns into packed compares; it is present on 1.13 as well.) A correction to the Stage 0 report: Julia 1.10 does not compile without AVX on the measuring CPU. Its default target reports the name `goldmont` but uses the host's feature set (the same loop compiles to `ymm` and fused multiply-add instructions by default and to neither with an explicit `-C goldmont`), so the two Julia 1.10 columns of the Stage 0 tables differ in tuning, not in vector width.
4. **A band-free fast path does pass the gate** when it carries its own three-line select-form soft threshold: 120 solve cells and 60 per-visit cells over Julia 1.10 (two targets) and 1.13, none above 1.05 or above the control, per-visit geometric mean 0.94 to 0.95; 480,000 steps per Julia version against a BigFloat reference with 0 above the bound. It would also remove K's band cost, since band inputs then stay on the fast path.

### Why R1-min

The combination "K + band-free fast path" is the only form that keeps the range and the speed everywhere. Against R1-min it saves about 11 more executable lines, and it costs: the last bits of ordinary square-root lasso results change (1 to 4 % of steps; a few Float32 solves change their pass count by one or two), a private ProximalBase helper is copied into ProximalSolvers because the exported one is slow on Julia 1.10, and both the fast path and the out-of-line path of a verified step are rewritten. By the maintainer's rule ("the default is to preserve the existing code when simplification has material costs"; R1 "must earn its complexity and performance tradeoffs"), that is not earned. So:

- **Implemented, as its own small PR:** `_scaled_norm` deleted; `_prepare!` and `_sqrt_offrange_step` call `_se_norm(Float64, ·)` (−13 executable lines; a third scaled-norm algorithm gone). The fast path, `_sqrt_band_step`, `_sqrt_threshold64` and the range handling of `_sqrt_offrange_step` stay as they are.
- **Not implemented:** K and the band-free fast path. Their patches, probe scripts and tables are kept with the evidence of this run and will be archived on a branch at the close of this issue.
- **One observation for ProximalBase, no request:** on Julia 1.10 the exported `shrink` costs 8 to 24 % per visit in a scalar coordinate loop against the select form ProximalBase uses inside its own prox loops. It is the same observation as the housekeeping note on ProximalBase #698; no issue is opened for it.

All timings are local, paired in one process with A/A controls, on a shared machine.
