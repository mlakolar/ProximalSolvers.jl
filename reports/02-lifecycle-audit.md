## #351, follow-up: lifecycle and frequency of penalty-level conversion

PS `8d2a30e` with PB pin `a19c59a`. Timings: Julia 1.13.4 on Linux x86_64, i5-13600K pinned to one performance core (`taskset -c 4`), BLAS on 1 thread, two runs each. macOS checks ran on the scratch branch `research/issue-351-probe`. Scripts: `count.jl`, `bench_real.jl`, `irdiff.jl`, `iterlevels.jl` (same approach as `.github/probe351/probe.jl`).

### 1. Call sites and how often each runs

| Where | What it converts | PGD | APG | CD |
|---|---|---|---|---|
| `_check_problem → _check_data → _check_penalty → _scalar_parameter` (`src/solve.jl:11,55-60`) | `T(λ)` per level, separate calls, validation only (result discarded) | once per solve | once per solve | once per solve |
| `initial_state`: `T(g(x0))` | PB value with the **original** `g` | once | once | n/a |
| iteration: `value_and_prox!(x, g, xhat, 1/L)` (`proximal_gradient_descent.jl:153`, `accelerated_…:229`) | PB, with the **original** `g`; PB forms `γλ` in its working type and rounds once (a no-op for levels of type `T`) | every iteration | every iteration | n/a |
| CD step: `prox_block(g, c, k, γ)`; outside the band `_threshold(T, λ, α, a)` (`cd/leastsquares.jl`) | PB with the original `g`; `Float64(λ)` on the rare path | n/a | n/a | every coordinate step |
| **`_converted_penalty(g, T)`** (`src/utils.jl:165`), only caller `_stationary!` (`utils.jl:126`), reached from `convergence_assessment` (`utils.jl:72`) **only when an x/f/gradient test proposes a stop** (`&&` short-circuits) | `ElasticNet(T(λ1), T(λ2))` / `NormL1(T(λ0))`, then the PB constructor | **once per proposed stop** | **once per proposed stop** | **never** |

`_converted_level` doesn't exist on master.

**Counts** (`count.jl` wraps `_converted_penalty` with a counter in a separate session). Settings: designs A, B, C at 100×32, 200×500 and 1000×200; Float32 and Float64; `NormL1`, `ElasticNet` with native levels, and `ElasticNet` with Rational levels; three option sets (default, benchmark-tight, `acc-`).

| | solves | iterations | `_converted_penalty` calls | per solve | max in one solve |
|---|---|---|---|---|---|
| PGD | 54 | 84,637 | 530 | 9.8 | 84 (F64, B 200×500, default, 169 iterations) |
| APG | 54 | 92,178 | 316 | 5.9 | 31 |
| CD | 36 | n/a | **0** | 0 | 0 |

With `acc-` options, a Float64 solve converts exactly once (its one accepted stop). A Float32 solve that reaches `maxiter` without a proposed stop converts zero times.

### 2. Is conversion repeated? Is anything cached?

- **Yes, repeated:** PGD and APG convert the same `g` to the same `T` at every proposed stop. Refused stops are common with the default options (up to half the iterations above).
- **Nothing is cached.** The converted penalty is built, used for `λ` and `kkt_violation`, and dropped. State has no field for it.
- **The repeated cost is almost all PB's `ElasticNet` constructor, not the conversion.** For levels already of type `T`, `T(λ)` is a no-op. The rebuild (`_checknonneg` ×2 plus the inner `NormL1`) costs 2–15 ns: that's variant C0 below, which skips both.

### 3. Is converting once feasible?

- **Inputs are fixed for the whole solve.** The conversion depends only on the levels and `T`. `NormL1` and `ElasticNet` are immutable structs with immutable `Real` levels, and `T` is fixed per solve. Nothing goes stale. Weights, which only #350 adds, are kept by reference whether or not the levels are converted.
- **No new state is needed.** `gT = _converted_penalty(g, T)` could be built once in `_solve_gradient!` and passed to `convergence_assessment` / `_stationary!` instead of `g`. That's about 3 internal lines, with no new allocations, state fields or synchronization.
- **The iterations can't share it.** They use PB's rule (`γλ` formed from the original level in the working type, rounded once). With `gT` passed to the solver instead of `g`, Float32 solves with Float64 or Rational levels give different iterates: 10–61 entries out of 32–500 differ for PGD and APG (`iterlevels.jl`). CD was unchanged here. Converting once would therefore apply to the stop check only.

### 4. Measurements

All in one process. `PS._converted_penalty` is redefined between variants, rounds interleave in alternating order, and one variant is an identical redefinition (the A/A control). Each row times the real `_stationary!` on a real `initial_state`, and whole `solve!` with default options.

- `_stationary!` per call: PGD 40–390 ns (O(p) `kkt_violation`); APG 160 ns–11 µs (it also forms ∇f(x), O(np)).
- `solve!`: 7 µs (100×32) up to 1.7 ms (200×500).

Ranges below are over 4 runs, 6 problems, 2 types, and native and Rational levels.

| variant | Δ per `_stationary!` call | Δ `solve!` |
|---|---|---|
| A/A control | PGD −13…+12 ns; APG −31…+85 ns | −1.8…+3.1% |
| **A** `@noinline` helper | PGD −12…+19 ns; APG −26…+73 ns: inside the A/A spread | −1.7…+1.3%: inside the A/A spread |
| **A′** (A, but only for levels not of type `T`) | native levels: **identical IR** for `_stationary!` (F32/F64 × PGD/APG, `irdiff.jl`); Rational: as A | −2.5…+1.1%: inside the A/A spread |
| **B** helper only for `T == Float32` | Float64 = base; Float32 = A | −1.6…+1.5%: inside the A/A spread |
| **C0** no conversion and no rebuild (lower bound for C) | PGD −15…+8 ns | 100×32 (7–12 µs): consistently −0.4…−1.4% (A/A on those rows within ±0.6%); larger solves: inside the A/A spread |

Per-call differences of a few ns are at the timer's resolution. No variant's slowdown can be told apart from the A/A control at the per-call or per-solve level.

One row in the second A′ run (F32, C 1000×200, Rational, APG) had a disturbed base: its A/A moved −21%. I've left it out.

Conversion itself costs about 0.5–1.2 ns per penalty when inlined. With a `@noinline` helper it's about 2 ns.

### 5. The three approaches

**A: generic `@noinline` helper.**
- Correctness: fixes macOS 1.13.4. At baseline the isolated test fails; with A it passes 1758/1758 (run 44217009396).
- Complexity: 2 lines. No API change.
- Performance: adds a non-inlined call per level per proposed stop, also for ordinary native levels. Measured cost is inside the A/A spread.

**B: helper only for Float32.**
- Correctness: fixes the bug. Only i64→f32 double-rounds; i64→f64 is a single `scvtf.2d`.
- Complexity: 3 lines.
- Performance: Float64 unchanged. The ordinary Float32 path (Float32 levels on Float32 data) still gets a non-inlined identity call, i.e. it is keyed on the wrong condition.

**C: convert once per solve, pass `gT` to the stop check.**
- Correctness: **doesn't remove the bug by itself.** The single conversion is the same `ElasticNet(T(λ1), T(λ2))`. The macOS probe shows that function compiled on its own (not inside a loop) already vectorizes: `_converted_penalty(ElasticNet{Rational}, Float32)` = 2× `scvtf.2d` + 2× `fcvtn`. So C still needs A's helper; C = A + caching.
- Complexity: ~3 internal lines (argument plumbing), no state field.
- Performance: saves the rebuild, at most ~2–15 ns per proposed stop. That's ≈1% on ~10 µs solves and unmeasurable on ≥300 µs solves (≤ 84 × 15 ns = 1.3 µs on a 1.7 ms solve).
- It's an optimization separate from #351, and it doesn't meet the "demonstrated repeated work worth caching" bar.

### 6. Recommendation: A′, the smallest correct change

```diff
 _converted_penalty(g::NormL1, ::Type{T}) where T = NormL1(T(g.λ0))
-_converted_penalty(g::ElasticNet, ::Type{T}) where T = ElasticNet(T(g.λ1), T(g.λ2))
+# A level that is not of type T is converted in a call of its own (#351): two conversions in one function can
+# be vectorized, and the AArch64 code of LLVM before 21 converts a pair of Int64 to Float32 through Float64,
+# which rounds twice. A level already of type T is used as it is.
+_converted_level(::Type{T}, λ::T) where T = λ
+@noinline _converted_level(::Type{T}, λ) where T = T(λ)
+_converted_penalty(g::ElasticNet, ::Type{T}) where T = ElasticNet(_converted_level(T, g.λ1), _converted_level(T, g.λ2))
```

- **Keeps the `T(λ)` contract.** The result is `T(λ)` exactly. For a level already in `T`, `T(λ) === λ`.
- **Ordinary paths unchanged.** Native Float32 and Float64 levels compile to identical IR.
- **Verified on macOS 1.13.4 aarch64.** At baseline the isolated test fails; with A′ it passes 1758/1758, and no vector conversion remains (run 44219628460). The Linux 1.13.4 control passes too.
- **Scope.** Only levels that actually need converting pay one non-inlined call per proposed stop (a few ns, inside the noise). No state, no caching, no tolerance, no change to the iterations, the PB pin, or NormL1 (a single conversion is never paired).
- **Tests.** Keep `test/elasticnet.jl:293` unchanged. Add `@test PS._converted_penalty(ElasticNet(λ, λ), T).λ1 === T(λ)` (and the same for `.λ2`) in the same testset. Only the macOS Nightly leg exercises this regression.

Not recommended for now: C (it doesn't fix the bug by itself, and it saves ≤ ~1% on the smallest solves); B (it adds a call to the ordinary Float32 path); A (A′ gives the same fix at zero cost on ordinary paths).

Stopping here for your decision; nothing has been implemented.
