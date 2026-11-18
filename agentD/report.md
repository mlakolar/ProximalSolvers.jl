NOTE: the Write tool refused to create `RUN/agentD/report.md` ("subagents should return findings as text, not write report files"), so I did not write it. The full report is below the summary. All scripts and raw outputs ARE in `RUN=<RUN>/agentD/` (index in section 7). If you need the markdown as a file, paste it from here.

# SUMMARY (Agent D, PB inventory and the `NumericalKernels` question)

PB pin a19c59aa, master 13891ccf noted; PS dac9f4b; Julia 1.10.13 and 1.13.4, both loading the pinned PB.

**Size and shape of PB's kernel layer.**
- `src/numerical_kernels.jl` is 778 executable lines (1306 physical). `src/utils.jl` adds 135, of which about 60 are numerical reductions. That is about 15% of PB's 6026 executable `src` lines.
- Blocks, in executable lines:
  - scalar ops and bounded products: 92
  - powers of two and `_pow2_*`: 113
  - `_ExpSum`: 104
  - norms: 111
  - squared-residual kernel: 84
  - ℓ2 index-set kernels: 219
  - Lanczos and `opnorm2`: 55
- Nearly every private primitive has two or more PB consumers (the #865 result). None is exported, and none has a documented guarantee as a primitive. Guarantees live in comments, in per-function pages of `numerics.md`, and in the SqrtLS/oracle accuracy statements.
- Master (`13891ccf`) adds 55 lines to `numerical_kernels.jl` (`_l2_score` and related) and no new exports. It adds PB-internal consumers of `_squares_normal`, `_residual_squares` and `_l2_classified_norm`.
- PB has no directed rounding, no extended-range value type, and no certified norm or spectral bound. `opnorm2` is documented "not a certified upper bound".
- `_scaled_dot` (`nk:252`, plus `iterate_storage.jl:115`, about 8-9 executable lines) has no caller in `src`, on the pin or on master. Only tests call it.

**Real PB↔PS duplicates.** Three, each verified numerically:
1. `_maxabs_diff` is the same as the *public* `norm_diff(x,y,Inf)`.
   - 0 differences in 500 trials, including NaN/Inf/huge.
   - Speed ratio 0.95-1.06 on both Julia versions.
   - Class C. PS can delete 6 lines today, with no PB change.
2. PS `_sumsq_diff` is bitwise identical to private `_sumabs2_diff` (100/100, Float32 and Float64), at the same speed. Class D, 7 lines.
3. PS `_clean_sum` is the same as private `_squares_normal` plus `isfinite` (0 of 20110 disagreements; they differ only at s=+Inf). Class D, 1 line.

Also: PS `_round_up(T,v)` equals Base `T(v, RoundUp)` (0/40020 disagreements, both versions). That is a Base replacement, not PB, and belongs to agent A.

**Same family, different guarantee** (substitution is numerically harmless but not free):
- PS `_scaled_norm` (sqrtlasso, 14 lines) against PB `_residual_squares(v,nothing,Float64)`: same exponent in 18/18 cases, PB more accurate (1.4 u vs up to 26 u at n=4096).
- PS `_se_norm`/`_se_norm_diff`/`_sumsq_scaled*` (30 lines) against `_residual_squares`: PB 1.4 u vs PS 3.1 u. The PS bound would survive numerically, but its proof would then rest on a PB kernel whose error bound is not a stated contract. All of this is cold path.
- `_se_norm_onepass` (APG hot path) uses `s ≥ 4n·floatmin`. PB's `_squares_normal` uses `n·floatmin/eps`, which is 2.1e6 (Float32) or 1.1e15 (Float64) times higher. Swapping would send Float32 steps below about 3e-16 per entry to the cold path. SIM, keep.

**No PB equivalent (class B, keep in PS):** `_SE` and `_se_*` (an extended-range carrier; in range `_se_mul` is bitwise equal to `_scaled_product`, but `2^900·2^900` gives `(1.0, 1800)` in `_SE` and `Inf` in PB), `_frobenius_upper`, `_root_scale`, `_up/_dn/_level_brackets`, `_gram_curvature`, `_column_dot*`, `_distance_sqr`, `_residual_axpy!`, `_sqnorm!`, and the fused PGD/APG reductions.

**Stable is not one-sided.** In the norm rows (n=64 and n=4096; ordinary, large, tiny, mixed), every method has computed < exact in 0.43-0.59 of trials. That covers PB's `_residual_squares` in both R=T and R=Float64, PB `norm_diff`, PS `_se_norm`, PS `_scaled_norm`, and Base `norm`. The only exception is the degenerate mixed row (one term dominates and the error is exactly 0). PB's documented SqrtLS bound is `(n/2+4)eps_T|v|` in `T`. That cannot back a Float32 certificate: at n=10^4 it is 6e-4, above the 1e-4 target.

**PS reaching into PB.** No private `_name` is reached. The four non-exported imports (`leastsquares_data`, `value_from_residual`, `value_from_predictor`, `value_and_gradient_from_predictor!`) are `public` on 1.11+ and importable by name on 1.10. PS does read undocumented struct fields of exported types: `NormL1.λ0/w`, `ElasticNet.λ1/λ2/w`, `GroupNormL2.λ0/w/groups`.

**Allocations.** 103 of 107 warmed rows allocate 0 B on both versions. The exceptions are `opnorm2` (documented to allocate) and `PS._root_scale(T, BigFloat)` (once per solve).

**Interface verdict: defer; option (1), keep helpers private and independent.**
- Best case, a submodule with D1-D3 (the three candidate primitives in the report's section 4.1) removes at most about 40 net PS lines. Those are 3% of the 1439 audited lines, and 30 of them sit in a cold APG fallback.
- PB already has the cheaper supported-name mechanism: qualified `public` names guarded by `VERSION >= v"1.11"` plus the `docs/check_api.jl` coverage check. A submodule would be only a namespace, and moving the code into it touches about 100 call sites or adds an alias layer.
- PB removed its qualified-public `ScalarLoss`/`deriv`/`curvature` interface within 0.6 dev (`migration.md`, #916/#937), so "supported" carries real cost.
- Option (3), a separate package, has no independent consumer and is not warranted.
- Reopen only if all four hold:
  1. At least 50 net PS lines migrate.
  2. PB states an error theorem for the exposed kernel and the PS proofs cite it.
  3. Paired 1.10/1.13 and F32/F64 benchmarks show the hot paths unchanged.
  4. An independent third consumer exists (that last one is the threshold for option 3).
- **PB 0.6:** nothing required. PS-only: C1 (`_maxabs_diff` → `norm_diff(x,y,Inf)`, −6 lines) and `_round_up` → Base. Optional PB hygiene: dead `_scaled_dot`.
- **0.7 research:** D1-D3 as a package, a documented error theorem for the scaled-sum kernel, and certified primitives only with a second real consumer.

**Open doubts.**
- Timings are single-process indicative probes with no CPU pinning.
- `exp_curv` found 0 "clearly below" cases for PB spectral quantities on random data. That is absence of evidence only.
- Cross-package precompile benefit is argued, not measured.
- Whether `_scaled_norm` and `_se_norm` are worth migrating depends on agent A's answer on the sqrt-lasso off-range branch (class E).

---

# FULL REPORT

PB audited: pin `a19c59aa` (tree 138929aa; plain export `RUN/pb-pin-a19c59aa`) as primary; master `13891ccf` (`RUN/pb-master-13891ccf`) noted where it differs. PS audited: `dac9f4b6`. Julia 1.10.13 (`+lts`) and 1.13.4 (`+release`), both loading the pinned PB. `RUN` = `<RUN>`. Executable LOC are from `tools/count_loc.py`. `nk` = `src/numerical_kernels.jl`.

## 0. Bottom line

1. The kernel layer is described in the summary above: 778 + 135 executable lines (about 15% of PB `src`), almost entirely function-internal recovery machinery.
2. Only three PB↔PS pairs are real duplicates. PS can drop 6 lines through an existing public API (no PB change), plus 7 + 1 lines through two private PB names that would have to become supported. That is 14 of the 1439 audited PS lines (about 1%).
3. Two more pairs are "same family, different guarantee" (PS `_scaled_norm`, 14 lines, and PS `_se_norm*`/`_sumsq_scaled*`, 30 lines, against PB `_residual_squares`). Substitution is numerically harmless, since PB is more accurate in every measured case. But the PS proof would then rely on a PB kernel whose error bound is not a stated contract, the gain is cold-path only, and the first one dies anyway if the sqrt-lasso off-range branch becomes a refusal.
4. Everything certificate-related has no PB equivalent. PB's stable norm is below the exact norm in about 50% of trials, so it is not a one-sided bound.
5. Interface verdict: defer, no submodule now (reasons and thresholds in the summary and section 4).
6. Doable now, PS only: replace `_maxabs_diff` by `norm_diff(x, y, Inf)` (−6 executable lines).

## 1. Inventory

### 1.1 Public numerical APIs of PB (pin)

Exports are at `src/ProximalBase.jl:18-25`. Qualified `public` names (Julia 1.11+ only) are at `:27-29`.

| Name | Kind | Documented guarantee | Notes |
|---|---|---|---|
| `shrink(v,c)` | export, nk:15-22 | `sign(v)·max(abs(v)-c,0)`; NaN in `v` propagates | branch-free; used by PS |
| `norm_diff(A,B,p=2)` | export, nk:559-582 | `‖A-B‖` without allocating; 2-norm or max-abs; docstring states no range property | code: ordinary one-pass sum, recomputed in power-of-two units only if the sum overflows or is below `floatmin(T)`; returns `T`, so a norm outside `T` is `Inf` (Float32 `[3e38,3e38]` gives `Inf`) |
| `opnorm2(X)` | export, nk:1257-1269 | Lanczos estimate of `‖X‖₂²`; docstring: "not a certified upper bound" | allocates by design (16-24 kB measured) |
| `lipschitz(f)` | export | bounds `‖X‖₂²`; full spectral norm for dense strided, `‖·‖₁‖·‖∞` otherwise (`smooth.md`) | dense case is an SVD value, not rigorous |
| `f(x)`, `gradient(!)`, `value_and_gradient(!)`, `prox(!)`, `value_and_prox!`, `prox_block(!)`, `value_entry`, `restrict` | exports | `numerics.md`: homogeneous Float32/Float64 is the supported target; ordinary path plus selective recovery; recovered values within `B = 4 n eps (Σ|terms|+|d|)`; "practical safeguards, not a promise of exhaustive range recovery or correctly rounded reductions"; no bitwise or order guarantee | no function offers a directed result |
| `kkt_violation` (3 forms) | export | signed screen of a coordinate assumed zero / score of the actual coordinate / nonnegative full-point measure; master adds GroupNormL2, NormL2, Scaled (#977) | PS uses it in `utils.jl:128` only |
| `ProximalBase.value_from_predictor`, `value_from_residual` | qualified `public` | LS: `(n+8)eps_T|v|` vs 256-bit refs. SqrtLS `α‖r‖₂`: within `(n/2+4)eps_T|v|` plus two subnormal units, finite where `|v|(1+w) ≤ floatmax`, `Inf` above the round-to-nearest threshold times `(1+w)` (proof in the comment of `functions/sqrt_leastsquares.jl`) | domain: strided Float32/Float64 of one type `T` only |
| `ProximalBase.value_and_gradient_from_predictor!`, `leastsquares_data` | qualified `public` | writes `d=z−Y`, `g=α fl(Xᵀd)`; data accessor `(; Y, X, α)` | |
| `tril_index`, `tril_cartesian`, `check_parameters`, `entry_parameters`, `check_symmetric_parameters`, `samegroups` | export or public | index arithmetic and hooks | not floating-point numerics |

Mechanics already in place:
- `VERSION >= v"1.11" && Core.eval(@__MODULE__, Expr(:public, …))` at `ProximalBase.jl:27`.
- On 1.10 the names stay unexported and are reachable qualified or by `using ProximalBase: name`.
- `docs/check_api.jl` requires an explicit `@docs` entry and a `coverage.md` row for every export and public name. Its list of qualified public names is hard-coded.
- There is no Compat.jl dependency. PB's deps are LinearAlgebra, PrecompileTools, SparseArrays.
- PS declares its own public names the same way (`ProximalSolvers.jl:26-28`, with the guard `v"1.11.0-DEV.469"`).

### 1.2 Shape of the private layer

| Block (nk lines) | Exec | Role |
|---|---|---|
| L1-196 scalar ops | 92 | `shrink`, `_shrink_nonneg`, `_positive_product`, `_weight_product`, `_threshold_product`, `_weight_coefficient`, `_scaled_product*`, `_compensated_add` |
| L197-399 powers of two, exponent parts | 113 | `_power_factors`, `_scaled_value_sum`, `_scaled_dot`, `_pow2_weighted`, `_pow2_sum` |
| L400-547 `_ExpSum` | 104 | exact-product accumulator, quadratic underflow tests |
| L548-733 norms and sums | 111 | `norm_diff`, `_norm_diff2`, `_scaled_norm`, `_sumabs2_diff`, `_squares_normal`, SIMD sum loops |
| L734-859 squared-residual kernel | 84 | `_halved_difference`, `_square_exponent`, `_square_scaled_sum`, `_residual_squares`, `_scaled_square_value`, `_square_parts` |
| L860-1216 ℓ2 index-set kernels | 219 | NormL2/GroupNormL2 shrink, value, screen (master adds `_l2_score`) |
| L1217-1306 spectral | 55 | Lanczos, `opnorm2`, `_opnorm_upper` |

`utils.jl` numerical part (about 60 lines): `_maximum_abs` (17), `_all_zero` (5), `_all_zero_early` (13), `_stored_values`, `_int_type`. `_sumabs2` is in `functions/sqrnorml2.jl:64-74`, not in the kernel file.

### 1.3 Private shared primitives (pin; callers are PB `src` only)

Guarantee classes: **O** ordinary arithmetic result; **S** stable value (no spurious intermediate overflow/underflow, accuracy a few eps, not directed); **R** rigorous one-sided bound (none exist in PB). "ldexp" in the 1.10 column marks #896: on 1.10 the final `ldexp` truncates subnormal results (reproduced: `PB._scaled_product(0.75,1,1,-1074)` is `0.0` on 1.10.13 and `5.0e-324` on 1.13.4). All allocation figures are warmed `@allocated` minima (`exp_alloc.jl`): every row listed as 0 measured 0 B on both Julia versions.

| Primitive | file:line | Exec | PB callers (file:line) | Guarantee | Precision | NaN/Inf/0/subnormal | Alloc | 1.10 |
|---|---|---|---|---|---|---|---|---|
| `_shrink_nonneg(v,c)` | nk:36,41,42 | 7 | elasticnet:87,125; norml1:86 | = `shrink` for every `c ≥ 0`; not for `c<0` | F, `@inline`, SIMD | NaN gives NaN; `-0` becomes `+0` | 0 | - |
| `_positive_product(a,b,c)` | nk:52,60 | 7 | elasticnet:189; norml1:67 | O when `floatmin ≤ ab ≤ floatmax`, else S (`_scaled_product`) | F | `(0,Inf,1)` gives 0; `2^-600·2^-600·2^900` gives 4.9e-91 (plain gives 0) | 0 | ldexp |
| `_weight_product`, `_threshold_product(S,γ,λ,w)` | nk:79,96,103 | 16 | norml1:87,91,106,131; elasticnet:91,97; nk:1001 | threshold rounded once to `S` plus a "γλ normal" flag | F | `(0.0,false)` for out-of-range γλ | 0 | ldexp |
| `_scaled_product(a,b,c,k)`, `(w,v,k)` | nk:124,141 | 14 | elasticnet:255; norml1:207; sqrnorml2:292; nk:59,126,308,331,361,505,614,839,1061,1164,1201; symmetric_sparse_iterate:257 | S: `a b c 2^k`, one final `ldexp`; zero factor gives +0; non-finite factor gives the ordinary product; result is a single `T` value, no extended exponent | F, B | `(0,Inf)` gives 0; NaN gives NaN | 0 | **#896** |
| `_scaled_product_retained` | nk:156,160 | 14 | scaled:519 | same, exponent summed in Int (#767) | F | | 0 | ldexp |
| `_compensated_add` | nk:191 | 5 | nk:246,427,430,801,812 | Sum2 error-free addition | any | NaN propagates | 0 | - |
| `_power_factors(T,k)` | nk:213,219,222 | 13 | leastsquares:229; norml1:206; nk:798,808 | two factors with exact product `2^k` for `|k| ≤ 2 exponent(floatmax)` | F fast path | `k=2100` gives `(…,Inf)` | 0 | - |
| `_pow2_weighted`, `_pow2_sum` | nk:280,334,363 | 48 | leastsquares:235 | S: weighted sum of `m·2^e` rounded once | F, B | non-finite term gives ordinary sum | 0 | ldexp |
| `_ExpSum`, `_expsum_add/_value/_quadratic` | nk:415-506 | 74 | linear:243,250; quadratic; norml1; groupnorml2; nk:445,451 | compensated frame sum with Int exponent; bound per `numerics.md` | F, B | zeros skipped | 0 | ldexp |
| `_level_fits`, `_squares_normal(s,n,T)`, `_sum_kept` | nk:130-135, 639, 935 | 5, 1, 1 | `_squares_normal`: sqrnorml2:200; sqrt_ls:167; nk:648,1004,1089,1144,1186 (+2 on master). `_sum_kept`: groupnorml2:146; norml1:232,252. `_level_fits`: norml1:191; scaled:198; sqrnorml2:133,200,227,245,514; nk:659,1142 | triggers: `_squares_normal` is `s ≥ n floatmin/eps`, "no square underflowed by more than eps of the sum" | any T | `_squares_normal(NaN)` false, `(Inf)` **true**, `(0)` false; `_sum_kept(NaN)` true | 0 | - |
| `_sumabs2_diff(x,y)` | nk:618 | 9 | sqrt_ls:94; nk:590,658,668 | O: `Σ abs2(T(x−y))`, `@simd` | F | propagate | 0 | - |
| `_sumabs2`, `_sumabs2_loop`, `_simd_sumabs2`, `_value_loop` | sqrnorml2:64-74; nk:675-701 | ~27 | sqrnorml2:92; sqrt_ls:95; leastsquares:127; nk | O: one vector-lane loop (up to 2^17, or 16..1024, entries) | F | | 0 | - |
| `_halved_difference` | nk:724 | 4 | sqrnorml2:291; nk:741 | S: `a−b`, or `a/2−b/2` with shift 1 where it overflows | F, B | | 0 | - |
| `_square_exponent` (3 methods) | nk:753,768,789 | 15 | nk:826,987,1157 | exponent of the largest residual; codes zero=`typemin`, Inf=`typemax-1`, NaN=`typemax` | F | verified | 0 | - |
| `_square_scaled_sum` | nk:797,807 | 17 | nk:829,989,1164 | Sum2 of `(r·2^-k)²`, exact scaling, in `R` | F, B | | 0 | - |
| **`_residual_squares(x,y,R)`** `-> (s,k)\|nothing` | nk:825 | 6 | leastsquares:242; nk:611,836,853 (+2 on master) | **S**: `Σ μᵢ(xᵢ−yᵢ)² = s 2^(2k)`; `(0,0)` for zero; `nothing` for a non-finite entry; stated in a comment only; accuracy proof in the SqrtLS comment | F, B; `R` ≥ entry width for `y=nothing` | `[ds,0]` gives `(1.0,-1074)` | 0 | - |
| `_scaled_norm(x,y,s,scale)` | nk:610 | 6 | sqrnorml2:91,94; sqrt_ls:177; nk:602 | S: `scale√(Σ…)` rounded once; non-finite gives ordinary `scale√s` | F | | 0 | ldexp |
| `_l2_classified_norm`, `_indexed_sumabs2`, `_IndexedValues` | nk:985, 911, 875 | 19 | groupnorml2; norml2; nk | classified exponent plus scaled norm of an index set | F | NaN/Inf class | 0 | - |
| `_maximum_abs`, `_all_zero` | utils:106,122,136,145 | 22 | norml1:203; normlinf:94,537; iterate_storage:125; elasticnet:271; scaled:449; nk:790,899,1146 | bit-pattern max; OR-of-bits zero test | F fast path | NaN above Inf above finite | 0 | - |
| `_largest_eigenvalue`, `opnorm2`, `_opnorm_upper`, `_opnorm2_upper` | nk:1231,1269,1292-1302 | 38 | leastsquares:334; quadratic:253; interface:557 | Lanczos from below; `_opnorm_upper` is `opnorm(A)` for strided dense (not rigorous), `√(‖A‖₁‖A‖∞)` otherwise (rigorous, loose) | F | | allocates | - |
| `_scaled_dot` | nk:252 (+ iterate_storage:115) | 8 | **none in `src`**; tests only | dead on pin and master | | | | |

Observation (not a PS issue): the public `norm_diff` keeps its ordinary sum when `s ≥ floatmin(T)`, a weaker trigger than `_squares_normal` (`s ≥ n floatmin/eps`). Worst relative error of `norm_diff(v,0)` on Float32 data whose squares are subnormal (n=4096) is 12.7-13.5 u, against 1.2-1.4 u for the kernel route. This is within the documented ordinary tolerance.

### 1.4 What PS imports from PB

`using ProximalBase: …` lines are at `ProximalSolvers.jl:19-21`, `blocks.jl:4`, `cd/leastsquares.jl:1`, `solve.jl:2`, `solvers/image_models.jl:3`. There is no `import ProximalBase` and no `ProximalBase.`-qualified call in `src`.

| PB names used | Exported / public | PS use |
|---|---|---|
| `LeastSquaresLoss`, `SqrtLeastSquaresLoss`, `Scaled`, `NormL1`, `ElasticNet`, `GroupNormL2`, `SparseIterate`, `BlockIterate`, `ncoordinates`, `nactive`, `activecoordinates`, `activevalues`, `blockindices`, `blockview`, `prox_block`, `prox_block!`, `value_and_prox!`, `shrink`, `kkt_violation`, `norm_diff` | exported (and public) | types and operations |
| `leastsquares_data`, `value_from_residual`, `value_from_predictor`, `value_and_gradient_from_predictor!` | **not exported**; `public` on 1.11+ only | explicit `using ProximalBase: name`, which works on 1.10 for non-exported names |

No PB private `_name` is reached (`out-imports.txt`). PS does read **struct fields** of exported types (`g.λ0`, `g.w`, `g.λ1`, `g.λ2`, `g.groups`; `solve.jl:56-80,158-162`, `utils.jl:164-167`, `cd/sqrtlasso.jl:50,51,182,257`, `cd/leastsquares.jl:134-140`). PB publishes no accessor for them.

## 2. PB↔PS similarity matrix

SAME = same algorithm and same guarantee. FORM = same formula, different guarantee. SIM = superficially similar.

| # | PS helper | PB primitive | Verdict | Evidence |
|---|---|---|---|---|
| 1 | `_maxabs_diff` (`blocks.jl`, 6 lines; `apg:289`, `image_models.jl:83`) | public `norm_diff(x,y,Inf)` (nk:575) | **SAME** | 0 differences of 500 incl. NaN/Inf/huge; time ratio 0.95-1.06 over 100..10^6, both versions |
| 2 | `_sumsq_diff` (`image_models.jl:102`, 7 lines; `:244`, APG per trial) | private `_sumabs2_diff` (nk:618) | **SAME** | bitwise identical 100/100 (F32, F64), same speed |
| 3 | `_clean_sum` (`sqrtlasso.jl:137`; `:181,:190`) | private `_squares_normal` (nk:639) | **SAME** + `isfinite` | 0/20110 disagreements; differs only at `s=Inf` |
| 4 | `_scaled_norm` (`sqrtlasso.jl:89`, 14 lines; `:57` setup, `:274` cold) | `_residual_squares(v,nothing,Float64)` + `√s` | **FORM** | same exponent 18/18; `s` within 2e-16; non-finite: PS `(M,0)`, PB `nothing`. Accuracy: PS up to 26 u (n=4096), PB 1.4 u. Indicative time 2.7 vs 1.25 ns/elt (1.10), about equal on 1.13 |
| 5 | `_se_norm`, `_se_norm_diff`, `_sumsq_scaled*` (`image_models.jl:55-91`, 30 lines; `leastsquares.jl:223`, `apg:127`, `image_models.jl:116,120`) | `_residual_squares` | **FORM** | PS scales by `m=max|v|` (a division), plain `@simd` sum, output `_SE`; PB scales by exact `2^-k`, Sum2, output `(s,k)`. Worst error n=4096: PS 3.1 u / 2.4 u (F64/F32), PB 1.4 u; `γ_{n+4}` claim is 4100 u. The proof would have to cite an unstated PB guarantee |
| 6 | `_se_norm_onepass`, `_se_norm_diff_onepass` (APG hot path) | `_squares_normal` | **SIM** | PS threshold `4n floatmin`; PB `n floatmin/eps`, higher by 2.1e6 (F32) / 1.1e15 (F64). n=1000: PB goes cold below `|x|≈3e-16` (F32), `1e-146` (F64); PS below `2e-19`, `3e-154` |
| 7 | `_SE`, `_se_mul/_add/_sub/_le`, `_renormal` (`image_models.jl:27-52`, about 30 lines) | `_scaled_product`, `_ExpSum` | **SIM** | in range `_se_mul` bitwise equals `_scaled_product(a,b,0)` (10000/10000), but `2^900·2^900` gives `Inf` in PB and `(1.0, 1800)` in `_SE`; `_se_add` and `_ExpSum` accuracy equal (0.8-1.06 u), but `_ExpSum` has no multiply, compare or `max(a−b,0)`; no PB `_se_le`/`_se_sub` analogue |
| 8 | `_frobenius_upper`, `_root_scale`, `_significand_exponent` | none | no PB equivalent | |
| 9 | `_gram_curvature`, `_singleton_curvature` (`leastsquares.jl:361-480`) | `opnorm2`, `lipschitz`, `_opnorm_upper` | **SIM** | PS needs `ℓ ≥ λmax` (Weyl margin). 300 random matrices per setting: none of the PB quantities nor the PS bound was clearly below λmax; PS overshoot median 5e-14 (F64), 4e-8 (F32). Random data cannot show absence of a guarantee; PB's contract says "not a certified upper bound" |
| 10 | `_column_dot`, `_column_dot_rsqr`, `_distance_sqr`, `_residual_axpy!`, `_sqnorm!` | none | no PB equivalent | fused BLAS-1 loops over a column and the cached residual |
| 11 | `_round_up(T,v)` (`sqrtlasso.jl:330`, 4 lines) | **Base** `T(v, RoundUp)` | SAME (Base) | 0/40020 differences, both versions |
| 12 | `_up`, `_dn`, `_level_brackets` | none | no PB equivalent | |
| 13 | `_curvature_scale`, `_response_scale_exceptional`, `_se_scale`, `_threshold`, `_exceptional_step` | `_threshold_product`, `_scaled_product` | **SIM** | PB forms `γλw` from three factors; PS forms the quotient `λ/(αa)` and `√s·√a` |
| 14 | `Blocks._norm_diff` | public `norm_diff` | already shared | |
| 15 | `Blocks._norm`, `_norm_inf`, `_dot` | Base | already Base | Float32 `norm([3e38,3e38])` is `Inf` (as is `norm_diff`); `PS._scaled_norm` keeps it (4.24e38) |
| 16 | `_dot_diff`, `_maxabs_axpy`, `_maxabs_residual`, `_maxabs_stepdiff` | none | no PB equivalent | |

## 3. Numerical evidence (executed)

### 3.1 Stable value versus one-sided bound (`exp_norms.jl`)

Compared: PB `_residual_squares` (R=T and R=Float64), PB `norm_diff(v,0)`, PS `_se_norm`, PS `_scaled_norm`, Base `norm`, against a 768-bit BigFloat norm of the rounded inputs. Kinds: ordinary; large (squares overflow); tiny (squares subnormal); mixed. 200 trials per row, n in {64, 4096}.
- Fraction with computed < exact is 0.43-0.59 for all methods in the ordinary/large/tiny rows. None is one-sided. A degenerate mixed row (one term dominates) shows 0.0 or 1.0, which is not a guarantee.
- Worst error over the four kinds, in u_T:
  - PB `_residual_squares`: 1.3-1.4 (R=T); 0 for Float32 data with R=Float64
  - `norm_diff`: 1.6-2.2 (12.7-13.5 on Float32 tiny)
  - PS `_se_norm`: 1.9-3.2
  - PS `_scaled_norm`: 3.3 (n=64), 20-26 (n=4096)
  - plain one-pass `sqrt(sum(abs2,v))`: 5e10 on tiny Float64 rows
  - `γ_{n+4}` in the same units is n+4

### 3.2 Pair 4/5 as a drop-in (`exp_swap.jl`)

Exponent agrees in 18/18 cases. At both PS `_scaled_norm` call sites the data are finite by construction (`solve!` validates `y`; `_sqrt_offrange_step` follows `_check_residual`), so the non-finite protocol difference is unreachable. I read this and did not trace it. Indicative ns/element (min of 5×200 calls, not controlled):
- 1.10: PS `_scaled_norm` 2.7-2.9; PB-based 1.25-1.5.
- 1.13: PS 2.6-3.0; PB-based 2.9-3.0.
- `_se_norm(T)` 0.6-1.3 vs `_residual_squares(T)` 1.2-1.4. Sum2 costs 2-3× the plain loop in Float32, which is irrelevant for a cold fallback.

### 3.3 Allocation (`alloc-table.txt`)

107 rows, Float32 and Float64, both versions: **103 allocate 0 B on both**. That includes `_residual_squares` (3 call forms), `_scaled_norm` on an overflowing vector, `norm_diff` (ordinary, overflowing, underflowing), `value_from_residual` (LS and SqrtLS, ordinary, huge, tiny), `PS._se_norm`, `_se_mul` (4-arg), `_se_add`, `_se_sub`, `_frobenius_upper`, `_root_scale(T,Float64)`. The four non-zero rows: `PB.opnorm2` (16.4 kB and 23.8 kB, by design) and `PS._root_scale(T,BigFloat)` (208 B on 1.10, 368 B on 1.13, once per solve).
Method note: my first script passed `Type` arguments through a vararg wrapper and reported spurious 30-190 B on those rows. I discarded it and re-ran with `@allocated` inside functions with a static type parameter.

### 3.4 Edge behaviour (`exp_edge.jl`, identical on both versions except the #896 line)

- `shrink(NaN,1)` is NaN.
- `_positive_product(0,Inf,1)` is 0.
- `_scaled_product` with a zero factor is +0, even against Inf.
- `_squares_normal(NaN)` is false and `(Inf)` is true.
- `_residual_squares` gives `nothing` for NaN or Inf and `(0.0,0)` for zero.
- `norm_diff([1,NaN],0)` is NaN and `([1,Inf],0)` is Inf.
- Float32 `norm_diff([3e38,3e38],0)` is `Inf`, because the result type is `T`.

## 4. Interface recommendation

### 4.1 Candidate primitives (only those with a real PS consumer today)

| Cand. | Signature | Guarantee (two sentences) | PB consumers | PS consumers | PS lines removed | PB lines added | Total |
|---|---|---|---|---|---|---|---|
| C1 (public today) | `norm_diff(x,y,Inf)` | already public | nk:575 | `apg:289`, `image_models.jl:83` | 6 | 0 | **−6** |
| D1 | `sumabs2_diff(x,y)` | `Σ abs2` of the differences in the common float type, one `@simd` pass; ordinary arithmetic, any summation order, no recovery | nk:590,658,668; sqrt_ls:94 | `image_models.jl:244` | 7 | 1 declaration | about −6, one more supported name |
| D2 | `squares_normal(s,n,T)` | `s ≥ n floatmin/eps`: a kept sum loses at most 2u² to underflowing squares | 7 sites (9 on master) | `sqrtlasso.jl:181,190` | 1 | 1 declaration | 0 (moves a line) |
| D3 | `scaled_sumsq(x,y,R) -> (s,k)\|nothing` | `Σ(xᵢ−yᵢ)² = s 2^(2k)`: residuals formed before exact power-of-two scaling, squares summed by Sum2 in `R`; `nothing` if an entry is non-finite. Relative error `u_R+γ²_{n−1}` plus absolute `n 2^-1073`, stated only in comments today | nk:611,836,853; leastsquares:242; SqrNormL2; NormL2/GroupNormL2 | `sqrtlasso.jl:57,274`; `image_models.jl:116,120`; `apg:127`; `leastsquares.jl:223` | 14 + 30 − about 10 shim | declaration, docstring with a theorem, coverage row, promoted tests | about −25..−35 if both pairs migrate; about −11 for pair 4 alone |

Not promotable (fails the two-consumer test or the two-sentence guarantee):
- `_scaled_product` and `_ExpSum`: PS needs an extended exponent that a single `T` result cannot carry.
- `_pow2_*`, `_l2_*`, `_halved_difference`, `_product_sum_shift`: no PS counterpart.
- `_maximum_abs`, `_all_zero`: PS has no counterpart.
- Any certified or directed primitive: PB has none and PS has one consumer family.

### 4.2 Options

| | (1) private, independent | (2) small supported PB submodule | (3) separate package |
|---|---|---|---|
| Code removed | 0 | about 14-45 PS lines | same plus a new repo |
| Surface added | 0 | 1-3 names plus a namespace; docstring, coverage row and test promotion each | independent versioning and CI |
| Risk | 3 duplicate one-liners stay in PS | PB commits to guarantees stated only in comments; a rename becomes breaking; precedent: PB removed qualified-public `ScalarLoss`/`deriv`/`curvature` within 0.6 dev (`migration.md`, #916/#937) | circular pins, no external consumer |
| Verdict | **now** | **defer** | **no** |

### 4.3 Mechanics if (2) is ever done

- **Declaring a non-exported supported name.** PB already does it: `VERSION >= v"1.11" && Core.eval(@__MODULE__, Expr(:public, …))` (`ProximalBase.jl:27`), with nothing on 1.10, where qualified access and `using ProximalBase: name` work (PS does this for four names). `docs/check_api.jl` enforces docstring and coverage row. Its qualified-name list is hard-coded and would need the new names. `@compat public` is not available.
- **A submodule is not needed for that.** If chosen anyway, the cheapest 1.10-compatible shape is `module NumericalKernels … export … end` inside PB, with `public NumericalKernels` guarded as above. Moving the existing definitions touches about 100 call sites across 11 PB files, or leaves an alias layer (`const scaled_sumsq = _residual_squares`) that removes no code.
- **Precompilation, inlining, dispatch.** Inlining is by method body, not module: `code_typed` of a PS caller of PS `_clean_sum` and of a caller of PB `_squares_normal` both show 0 `:invoke` statements on 1.10 and 1.13. Specializations for `Vector{Float32/Float64}` signatures belong to PB's method and are cached in PB's pkgimage if `src/precompile.jl` covers them, which would need one line per new kernel. A submodule in the same package changes neither load time nor invalidations.
- **Semver at 0.6.0-DEV.** PS requires `ProximalBase = "0.6"` and pins a commit by `[sources]`. Under Pkg's 0.x rule a minor bump is breaking. "Supported" can therefore only mean: stable within 0.6.x, a documented guarantee with a test-evidence row, and a `migration.md` note when changed.

### 4.4 0.6 versus 0.7

- **0.6, PS-only, no PB change:** C1 (`_maxabs_diff` → `norm_diff(x,y,Inf)`, −6) and `_round_up` → Base `T(v,RoundUp)` (−3; agent A's call).
- **0.6, PB-only, optional hygiene:** dead `_scaled_dot` (8-9 lines).
- **0.7 research (PB #698), only with evidence:** D1-D3 as a package, a documented error theorem for the scaled-sum kernel, certified primitives only with a second real consumer.

### 4.5 "Defer" threshold (reopen only if all hold)

1. At least 50 net PS lines would migrate (today at most about 40, 30 of them in a cold APG fallback).
2. PB states an accuracy theorem for the exposed kernel and the PS proofs (`_se_norm`, `_bound_certified!`, `_certify!`) are edited to cite it.
3. Paired Float32/Float64, 1.10/1.13 benchmarks show the hot paths unchanged (`_sumsq_diff` is bitwise identical today, so expected to pass).
4. For option (3) only: a third package independent of PS and PB wants the same primitive.

## 5. Ledger rows

Columns: Helper | Call sites | Purpose (math + guarantee) | Path | PB equivalent | Class | Proposed action | Net savings | Correctness | Performance | Dependencies.

| Helper | Call sites | Purpose | Path | PB equivalent | Class | Action | Net savings | Correctness | Performance | Deps |
|---|---|---|---|---|---|---|---|---|---|---|
| `_maxabs_diff` | `apg:289` (per iteration), `image_models.jl:83` | `max|xᵢ−yᵢ|`; ordinary, NaN propagates | hot | public `norm_diff(x,y,Inf)` | **C** | replace (wrapper `Blocks._norm_diff` already forwards) | −6 PS, 0 PB | equal, 0/500 differences | equal (0.95-1.06); O(1) extra checks | none |
| `_sumsq_diff` | `image_models.jl:244` per APG trial | `Σ(aᵢ−bᵢ)²`, one `@simd` pass; proof uses "any order" | hot | private `_sumabs2_diff` | **D** (tiny) | do not migrate alone; reuse if a supported name appears for another reason | −7 PS, +1 decl PB, about −6 | bitwise 100/100 | identical, 0 B | new public name, `check_api` row |
| `_clean_sum` | `sqrtlasso.jl:181,190` | `isfinite & (s ≥ n floatmin/eps)` | hot | private `_squares_normal` | **D** (tiny) | keep; add a comment naming the PB predicate | 0 | equal except s=Inf | identical | none |
| `_scaled_norm` | `sqrtlasso.jl:57` (once per solve), `:274` (cold) | `‖v‖₂ = s 2^e` in Float64 | setup/cold | `_residual_squares(v,nothing,Float64)` + `√s` | **D** conditional, **E**-linked | decide with agent A: if the off-range step becomes a refusal, one caller (`floor64`) remains and Base `norm` could serve it; otherwise needs D3 | −14+3 (with D3); −14+1 with `Float64(norm(y))`, but a Float32 `y` with ‖y‖ > floatmax(Float32) then gives `Inf` (behaviour change at the extreme) | exponent identical 18/18; `s` within 2e-16 | PB-based faster on 1.10, equal on 1.13 | D3 |
| `_se_norm`, `_se_norm_diff`, `_sumsq_scaled*` | `leastsquares.jl:223` (cold), `apg:127` (once per solve), `image_models.jl:116,120` (fallback) | extended-range `‖v‖` as `_SE`, a priori `γ_{n+4}` | cold/setup | `_residual_squares` | **D**, optional | defer: about 20 net lines in cold paths, moves the APG proof onto an unstated PB guarantee | −30+10 shim (+ D3) | PB more accurate (1.4 vs 3.1 u) | cold fallback 2-3× slower in F32 | D3 plus a PB theorem |
| `_se_norm_onepass`, `_se_norm_diff_onepass` | `apg:238,239`; `image_models.jl:254,244` | one-pass sum when `s ≥ 4n floatmin`, else scaled two-pass | hot | `_squares_normal` (different threshold) | **B** | keep | 0 | PB's trigger would push F32 steps below about 3e-16 to the cold path | PB's trigger slower on small steps | none |
| `_SE`, `_se_mul/_add/_sub/_le`, `_renormal` | `image_models.jl:27-52`, 48 call sites | nonnegative reals as `s 2^e`, one rounding per op, comparisons, `max(a−b,0)` | hot | `_scaled_product`/`_ExpSum` carry a value or an accumulator | **B** | keep (agrees with PS #279 and PB #698) | 0 | `_se_mul` = `_scaled_product` bitwise in range; out of range PB gives Inf | none | none |
| `_frobenius_upper`, `_root_scale`, `_significand_exponent`, `_bound_constants`, `_bound_certified!` | `image_models.jl:137-270`; `apg:154`; `leastsquares.jl:225` | rigorous bounds of the APG acceptance test | setup/hot | none | **B** | keep | 0 | | | |
| `_gram_curvature`, `_singleton_curvature`, `_curvature_deferrable` | `leastsquares.jl:334,361-` | `ℓ ≥ λmax(X_kᵀX_k)` with Weyl margin and eigensolver model | setup | `opnorm2` ("not a certified upper bound"), `lipschitz`, private `_opnorm_upper` | **B** | keep | 0 | no PB quantity carries an upward guarantee (0 of 1800 random trials clearly below λmax: absence of evidence only) | none | none |
| `_column_dot`, `_column_dot_rsqr`, `_distance_sqr`, `_residual_axpy!`, `_sqnorm!` | `leastsquares.jl:97,106,595`; `sqrtlasso.jl:152,163,189` | fused column dot, residual axpy, curvature sum | hot | none (`_scaled_dot` is dead and a different shape) | **B** | keep | 0 | | | |
| `_round_up` | `sqrtlasso.jl:305` | smallest `T ≥ v` | cold | Base `T(v,RoundUp)` | **C** (Base) | agent A to decide | −3 PS | 0/40020 differences | cold | none |
| `_up`, `_dn`, `_level_brackets`, `_CERT_TARGET` | `sqrtlasso.jl:339-342,504-524`; `:51` | outward rounding for the certificate | cold | none | **B** | keep | 0 | | | |
| `_curvature_scale`, `_response_scale_exceptional`, `_se_scale`, `_threshold`, `_exceptional_step` | `leastsquares.jl:96-234` | stopping scales and range-safe coordinate threshold | setup/cold | `_threshold_product` (different formula) | **B**; agent B decides **E** | keep or refuse | 0 | | | |
| `Blocks._norm_diff` | `utils.jl:178` | convergence-assessment norm | hot | public `norm_diff` | **A** | none | 0 | | | |
| `Blocks._norm`, `_norm_inf`, `_dot` | `line_searches.jl:96`; `utils.jl`; `apg:296` | Base norm and dot | hot | Base | **A** | none | 0 | | | |
| `Blocks._dot_diff`, `_maxabs_axpy`, `_maxabs_residual`, `_maxabs_stepdiff` | `line_searches.jl:139`; `apg:295`; `utils.jl:32,84` | fused reductions | hot | none | **B** | keep | 0 | | | |
| `value_from_residual`, `value_from_predictor`, `value_and_gradient_from_predictor!`, `leastsquares_data` | `cd/leastsquares.jl:1,239`; `cd/sqrtlasso.jl:41`; `image_models.jl:3,18-20` | loss values and data at a caller-held residual or predictor | hot | public (qualified) | **A** | none | 0 | PB's SqrtLS bound is in `T`; a Float64 certificate for Float32 data cannot use it: at n=10^4 the Float32 bound is 6e-4, above the 1e-4 target | | none |
| `shrink`, `prox_block(!)`, `value_and_prox!`, `kkt_violation`, `norm_diff` | many | proximal operators and optimality | hot | public | **A** | none | 0 | | | |
| field reads `g.λ0/w/λ1/λ2/groups` | `solve.jl:56-80,158-162`; `utils.jl:164-167`; `cd/sqrtlasso.jl:50,51,182,257`; `cd/leastsquares.jl:134-140` | penalty parameters | setup | no public accessor | outside A-F | note to maintainer only | 0 | | | a PB accessor would be a separate PB decision |

Class F (proof-only text) applies to the certificate comments of `_certify!`, `_gram_curvature`, `_sqrt_ls_*`. They carry no executable duplication and I propose nothing beyond agents A-C's.

## 6. Executed versus inferred, and open doubts

**Executed (both Julia versions unless stated):**
- norm accuracy and direction against 768-bit references
- equivalences: `_clean_sum`/`_squares_normal`, `_round_up`/Base, `_maxabs_diff`/`norm_diff(·,·,Inf)`, `_sumsq_diff`/`_sumabs2_diff`
- in-range `_se_mul` against `_scaled_product` (bitwise)
- `_se_add` against `_ExpSum` error
- warmed allocations of 107 rows
- edge values of the PB kernels
- the #896 truncation
- `code_typed` inlining across the package boundary
- PS imports all exported or public
- PB master versus pin diff

**Inferred from reading only:**
- caller lists (a grep script; a few "callers" in `callers-raw.txt` are method definitions)
- executable LOC (shared counter)
- the unreachability of PS `_scaled_norm`'s non-finite branch at both call sites (read `solve!` validation and `_check_residual`, did not trace)
- semver commentary
- master changes beyond the `_l2_score` addition
- the PB docs build (not run)
- the claim that a Float32 `y` with ‖y‖ > floatmax(Float32) is refused elsewhere (not checked)

**Open doubts:**
- The curvature experiment (0 clearly-below cases on random data) is absence of evidence only. I did not search for an adversarial matrix, since PB's contract already says its quantities are not bounds.
- Timings are single-process probes without CPU pinning or an A/A control. One outlier (`_sumsq_diff` ratio 0.53 on 1.13, Float32, n=1000) is the PS side being slower, which would favour migration; I did not chase it.
- Cross-package precompile benefit is argued from how pkgimages work, not measured.
- I did not test `kkt_violation`, `prox_block!` or the NormL1/GroupNormL2 kernels (all class A, already shared).
- Whether the sqrt-lasso off-range branch, the response-scale recovery and the group curvature bound become refusals (class E) belongs to agents A-C. The rows for `_scaled_norm` and `_se_norm` change value depending on their answer.

## 7. File index (all in `RUN/agentD/`)

- `loc-pb-kernels-utils.txt`, `loc-pb-src-all.txt`, `loc-pb-src-items.txt`: per-item executable LOC of PB.
- `callers.py`, `callers-raw.txt`, `callers_ps.py`, `callers-ps-raw.txt`: caller greps.
- `exp_norms.jl`, `out-norms-{lts,release}.txt`, `norms-summary.txt`: norm accuracy and direction.
- `exp_equiv.jl`, `out-equiv-{lts,release}.txt`: `_clean_sum`, `_round_up`, `_SE` against PB.
- `exp_alloc.jl`, `out-alloc-{lts,release}.txt`, `alloc-table.txt`: warmed allocations.
- `exp_swap.jl`, `out-swap-{lts,release}.txt`: `_scaled_norm` against `_residual_squares`.
- `exp_maxabs.jl`, `out-maxabs-{lts,release}.txt`: `_maxabs_diff` against `norm_diff(·,·,Inf)`.
- `exp_sumsq.jl`, `out-sumsq-{lts,release}.txt`: `_sumsq_diff` against `_sumabs2_diff`.
- `exp_edge.jl`, `out-edge-{lts,release}.txt`: edge values.
- `exp_mech.jl`, `out-mech-{lts,release}.txt`: `public` mechanics, inlining, Float32 range.
- `ps_imports.jl`, `out-imports.txt`: PS imports check.
- `exp_curv.jl`, `out-curv-{lts,release}.txt`: curvature bounds.
- `pbissue-*.json`, `psissue-353.json`: issue text read (PB #698, #865, #366, #843, #896, #911, #915, #960, #961, #970, #972, #976, #977; PS #353).