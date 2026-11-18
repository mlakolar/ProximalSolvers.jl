## Investigation of `test/elasticnet.jl:293`: ElasticNet, Float32, macOS (Stage 0)

**Summary.** The failure is a **compiler code-generation defect**: LLVM 20's AArch64 backend, used by Julia 1.13.4. It shows up in **ProximalSolvers' level conversion** (`_converted_penalty(::ElasticNet, T)`). It is **not** a ProximalBase defect, and the test's assumptions are valid. On aarch64 with Julia 1.13 at `-O2`, LLVM's SLP vectorizer combines the two `Rational{Int64} → Float32` conversions of `λ1` and `λ2` into a single `sitofp <2 x i64> to <2 x float>`. The AArch64 backend lowers that as `scvtf.2d` followed by `fcvtn`, i.e. Int64 → Float64 → Float32, which rounds twice. The stop check therefore receives `ElasticNet(1f0, 1f0)` instead of `ElasticNet(T(λ), T(λ)) = ElasticNet(nextfloat(1f0), nextfloat(1f0))`, and the residual is `|−2c + 1 + 1| = 2^-22 = 2.3841858f-7`, exactly the reported value. **The failure is present on master** (`8d2a30e`; HEAD `dac9f4b` doesn't change `src/utils.jl`, `test/elasticnet.jl` or the PB pin). It doesn't come from #350.

### 1. Reproduction

- PS `8d2a30e` (clean worktree), with PB `a19c59aa723d085d5d7cf5242895bda16eb77214` from `[sources]` / `Manifest-v1.10.toml`, unchanged.
- Standalone reproducer: [`.github/probe351/probe.jl`](https://github.com/mlakolar/ProximalSolvers.jl/blob/research/issue-351-probe/.github/probe351/probe.jl) on the scratch branch `research/issue-351-probe` (= `8d2a30e` + the probe workflow; not for merging). Run it with `julia --project=. .github/probe351/probe.jl --native`.
- Isolated test: `julia scripts/test.jl --jobs=1 elasticnet`.
- Probe run: https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/44217009396 (probe at `-O0/-O1/-O2/-O3`, isolated test at baseline, then again with the candidate patch applied in the workspace).

| Platform | Julia / LLVM | `_converted_penalty(...).λ1` | isolated `elasticnet`, baseline | with the patch |
|---|---|---|---|---|
| macOS aarch64 (Apple M1, GHA) | 1.13.4 / LLVM 20.1.8, `-O2` and `-O3` | **`1.0f0`** (wrong) | **fails, exactly the #351 assertion** | passes (1758/1758) |
| macOS aarch64 | 1.13.4 / LLVM 20.1.8, `-O0` and `-O1` | `1.0000001f0` | n/a | n/a |
| macOS aarch64 (M2 Pro) | 1.10.13 / LLVM 15.0.7 | `1.0000001f0` | passes | passes |
| macOS aarch64 | 1.14.0-beta1 / LLVM 23.1.4 | `1.0000001f0` | passes | passes |
| Linux x86_64 (znver4 GHA, local raptorlake) | 1.13.4 / LLVM 20.1.8 | `1.0000001f0` | passes | passes |
| Linux x86_64 (znver3 GHA, local) | 1.10.13 / LLVM 15.0.7 | `1.0000001f0` | passes | passes |

### 2. Numerical trace (macOS aarch64, 1.13.4, `-O2`)

`λ = 1152921573326323713 // 1152921504606846976 = 1 + 2^-24 + 2^-60`: just above the Float32 tie between `1` and `1 + 2^-23`.

```
T(λ)  (Base: T(num)/T(den))          1.0000001f0   0 01111111 00000000000000000000001
T(Float64(λ))  (double rounding)     1.0f0         0 01111111 00000000000000000000000
T(BigFloat(λ), 256 bits) reference   1.0000001f0   0 01111111 00000000000000000000001
scalar sitofp num                    1.1529216f18  0 10111011 00000000000000000000001   (correct)
sitofp <2 x i64> -> <2 x float> num  1.1529215f18  0 10111011 00000000000000000000000   (= 2^60, double-rounded)

_converted_penalty(ElasticNet(λ,λ), T).λ1 / .λ2   1.0f0        <-- the first divergence
_converted_penalty(NormL1(λ), T).λ0               1.0000001f0  (single conversion, not vectorized)
(T(λ1), T(λ2)) inlined into the caller            1.0000001f0  (correct in the probe's own context)

c = T(λ), x = [1], grad = [-2c]
direct Float32 formula |(g + c x) + c sign x|               0.0f0
kkt_violation(ElasticNet(c,c), grad, x)  (@simd Array)      0.0f0
kkt_violation(ElasticNet(c,c), views)    (generic)          0.0f0
kkt_violation(ElasticNet(c,c), grad, x, 1)  (coordinate)    0.0f0
kkt_violation(_converted_penalty(g,T), grad, x | views | 1) 2.3841858f-7   0 01101001 000…  (= 2^-22)
direct formula at the converted coefficients                2.3841858f-7
```

Native code (counts of `scvtf/ucvtf .2d`, `fcvtn`, scalar `scvtf s,x`):

```
_converted_penalty(ElasticNet{Rational{Int64}}, Float32)              (2, 2, 0)   vector, double rounding
_stationary!(PGD state, …, ElasticNet{Rational{Int64}})                (2, 2, 0)   in the solver's own stop check
_stationary!(APG state, …, ElasticNet{Rational{Int64}})                (2, 2, 0)
_converted_penalty(NormL1{Rational{Int64}}, Float32)                  (0, 0, 2)   scalar
same functions on 1.13.4 -O0/-O1, on 1.10.13, and on 1.14.0-beta1     (0, 0, 4)   scalar
```

Every ProximalBase path (`@simd` dense, generic views, coordinate form) returns 0 at the correctly converted coefficients, also on the failing platform. The only divergence is in the coefficients that `_converted_penalty` produces.

### 3. Independent reference

`T(BigFloat(λ))` at 256 bits gives `0x3f800001 = nextfloat(1f0)`, which equals Base's `T(λ) = T(num)/T(den)`: `T(num)` is correctly rounded to `2^60(1+2^-23)`, `den = 2^60` converts exactly, and the quotient is exact. Base therefore defines `T(λ)` as the correctly rounded value, and the test's expectation `kkt_violation(ElasticNet(c,c), [-2c], [1]) = 0` holds exactly in Float32 (`−2c + c + c` involves no rounding). Locally, `llc` shows the same lowering for a bare `sitofp <2 x i64> to <2 x float>` with `-mtriple=arm64-apple-macosx -mcpu=apple-m1` (LLVM 14 and 18): `scvtf.2d v0, v0; fcvtn v0.2s, v0.2d`. On x86-64 the vector conversion is scalarized to `cvtsi2ss`.

### 4. Root cause and responsible component

- **Not A (test construction).** The test builds `grad` and the expected residual from `c = T(λ)`. That is exactly what `src/utils.jl` documents the stop check as using (`ElasticNet(T(λ1), T(λ2))`). The test is doing its job: it detected that, on this platform, the check uses a different rounding of λ, which is precisely the regression it was written for.
- **Not B (ProximalBase).** `kkt_violation(ElasticNet(c, c), …)` is 0 on every PB path, on every platform. No PB issue is warranted.
- **C, caused by the compiler.** The conversion in `_converted_penalty(::ElasticNet, T)` produces non-native coefficients on Julia 1.13 / aarch64 at `-O2` and above. The underlying defect is LLVM's: the AArch64 cost model let the vectorizer form an i64 → f32 vector conversion that has no direct instruction, and the backend lowers it with double rounding. Upstream fixed the vectorizer side in [llvm/llvm-project#130665](https://github.com/llvm/llvm-project/pull/130665) ("Don't try to vectorize fixed point to fp narrowing conversion"), merged 2025-03-25. That fix is in LLVM 21.1.0, not in 20.1.8, and Julia 1.13.4's LLVM 20.1.8 still vectorizes here. GlobalISel received the matching fix in [#132703](https://github.com/llvm/llvm-project/pull/132703). On Julia 1.14.0-beta1 (LLVM 23) even an explicit vector `sitofp` rounds correctly. Julia 1.10 (LLVM 15) has the same faulty lowering (the probe's explicit `llvmcall` double-rounds on macOS 1.10), but its vectorizer doesn't form the pair in this code. Julia 1.12 (LLVM 18) on aarch64 was not tested.

**Scope.** Affected: PGD and APG stop checks (`_stationary!`) with an **`ElasticNet` whose levels are `Rational{Int64}`** (presumably also `Rational{UInt64}`), Float32 data, Julia 1.13 on aarch64. Unaffected: NormL1 (one conversion, not vectorized), `ElasticNet{Int64}` (scalar in the probe), Float32/Float64/BigFloat/Int128 levels (no i64 → f32 hardware conversion is involved), Float64 data (`scvtf.2d` alone is a single rounding), CD (it doesn't use `_converted_penalty`), and the validation in `_check_penalty` (each level is converted in its own `try` call, and a one-ulp difference can't change its finite/zero tests). The coefficients can only differ when a numerator or denominator has **more than 53 significant bits** and hits a Float32 tie after the first rounding. That is about 2^-29 of such integers: 0 of 10⁶ random samples at each length from 25 to 63 bits. Exact `Rational(::Float64)` levels have at most 53-bit numerators and are never affected.

### 5. Can actual stopping decisions be affected?

Only marginally, and only for such hand-built levels. Double rounding moves each coefficient by at most one ulp, `|Δc| ≤ 2^-23 c`. The residual changes by at most `2^-23 (λ1 + λ2‖x‖∞)`, and `S` by at most one ulp. The threshold is `τ S` with `τ ≥ 64 eps(Float32) = 2^-17` and `S ≥ λ1`, so whenever `λ2‖x‖∞ ≲ S` the perturbation is below 1/32 of the smallest threshold. A decision can flip only when the residual lies within that band just below `τ S`, where both outcomes are within the documented tolerance. The iterates themselves are unaffected: PB's prox forms `γλ` from the Rational level in Float64. In the probe's PGD and APG solves on macOS 1.13.4, the residual difference was `2.4e-7` against a threshold of `9.0e-5` (about 1/375). The residual at both the correctly rounded and the double-rounded coefficients (about `2–3e-6`) is far below the threshold, so the decision is the same either way. This is a contract violation (the check is documented to use `T(λ)`), not a practical false-convergence risk.

### 6. Proposed smallest fix (not implemented)

Convert each level in a call of its own, so the two conversions can't be combined into one vector instruction:

```diff
 _converted_penalty(g::NormL1, ::Type{T}) where T = NormL1(T(g.λ0))
-_converted_penalty(g::ElasticNet, ::Type{T}) where T = ElasticNet(T(g.λ1), T(g.λ2))
+# Each level converted in a call of its own (#351): two conversions in one function can be vectorized, and the
+# AArch64 code of LLVM before 21 converts a pair of Int64 to Float32 through Float64, which rounds twice.
+@noinline _converted_level(::Type{T}, λ) where T = T(λ)
+_converted_penalty(g::ElasticNet, ::Type{T}) where T = ElasticNet(_converted_level(T, g.λ1), _converted_level(T, g.λ2))
```

On macOS 1.13.4 with this patch, the coefficients are `nextfloat(1f0)`, no vector conversion remains in `_converted_penalty` or `_stationary!`, and `elasticnet` passes 1758/1758. It also passes on every other leg in the table. The cost is two non-inlined calls per proposed stop, alongside the O(p) `kkt_violation` pass: no hot-loop change, no new tolerance, no change to Rational handling or to the PB pin. It relies on how LLVM optimizes rather than on a language guarantee, but it is the minimal change that restores the documented contract on the affected toolchain, and it becomes unnecessary when Julia moves to LLVM ≥ 21.

**Regression tests:** keep `test/elasticnet.jl:293` unchanged. It is the test that caught the problem. I'd add one direct assertion in the same testset, `@test PS._converted_penalty(ElasticNet(λ, λ), T).λ1 === T(λ)` (and the same for `.λ2`), so that a future failure points at the conversion rather than the residual. Note that this regression is only exercised by the **macOS Nightly leg**; PR CI (Linux x86) can't reproduce it.

**Not recommended:** changing the Rational test level, loosening the equality, or gating it with `@test_broken` on aarch64. Each would hide a real (if tiny) deviation from the documented check.

### 7. Separate issues

- **ProximalBase: no.** PB's kernels are correct on every path tested.
- **Julia upstream: optional.** A request to backport llvm#130665 into Julia's LLVM 20 for 1.13 would fix every Julia user, not just this case. I haven't filed it; that's your call.

Scratch branch `research/issue-351-probe` holds the probe script, workflow and candidate patch. I'll delete it, or archive the logs (with SHA256 manifest) first, whichever you prefer. Stopping here for maintainer approval; no PR has been opened.
