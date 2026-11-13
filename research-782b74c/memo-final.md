## Design memo: gradient-solver helper layers (#279)

**Short answer.** The PGD/APG helper layer is already close to minimal after #268 and #276. The research found:
- one small exact cleanup worth one PR: net −6 lines, one state field, one private export, and one redundant `resize!` path;
- 8 one-line `Blocks` forwards that could become direct `Base`/PB calls, measured as exact, but recommended to **stay**: #230's Stage 2 includes tuple (product-space) iterates, and PB's single-owner methods do not provide the tuple operations;
- a longer list of things that should deliberately stay.

PB provides no drop-in certified replacement for the APG certification arithmetic. Keep `_SE` local unless equivalence or revised error bounds are established. The recommended cleanup preserves the numerical formulas and stopping rules, and recorded outputs agree on the tested corpus. Equal stopping iterations under finite time limits are not established.

Research only. The prototype diffs below are illustrations, not proposed patches. Independently reviewed by Codex (gpt-6.1-sol, high effort) against the code and the evidence over three rounds. Rounds 1 and 2 requested changes, all accepted and applied, including a correction of the base-probe comment's guard-reachability claim and the decision to keep the `Blocks` forwards. Round 3: **PASS / NO BLOCKERS**. Plan: [plan comment](https://github.com/mlakolar/ProximalSolvers.jl/issues/279#issuecomment-6843264053). Base-probe results: [W2 comment](https://github.com/mlakolar/ProximalSolvers.jl/issues/279#issuecomment-6844317377).

**Identities.**
- PS `master` = `782b74c` (#276 merged).
- PB pin `c123d56`, checked on every probe run (manifest tree hash `c2e2ddde…`, recomputed from the loaded directory). PB master snapshot inspected for this research: `1f3e98b`, used for direction only.
- Julia 1.10.12 and 1.13.3, on a cluster (Slurm), one CPU kind (AMD Zen 3), BLAS at 1 thread.

### Preferred design

| | Change | Class | Evidence |
|---|---|---|---|
| **Delete** | `_copy!` (use `_copyto!` at [pgd:121,124](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/solvers/proximal_gradient_descent.jl#L121-L124)) | safe mechanical | fingerprints identical; IR of PGD `update_state!` loses the two `resize!`/length-check branches of `copy!`, nothing else changes |
| **Delete** | APG state field `f_y` (a local in `_prox_grad_step!`, [apg:210-215](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/solvers/accelerated_proximal_gradient_descent.jl#L210-L215)) | safe mechanical | results identical (only the state dump loses the field); 48 bytes less per APG Float64 solve on 27 of 220 probe paths; no `update_state!` allocation changes |
| **Delete** | always-true `iteration > 0` ([utils:9](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/utils.jl#L9); the only call follows `iteration += 1`, [solve:86,103](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/solve.jl#L86-L103)) | safe mechanical | identical; one compare and select fewer |
| **Delete** | unused `f, g, method` of `trace!` ([utils:7](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/utils.jl#L7)) | safe mechanical | identical; calls pass fewer arguments |
| **Consolidate** | `_state_norm`/`_state_normdiff`: one `Union{PGD, APG state}` method each in `utils.jl`, deleting the APG copies ([apg:292-293](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/solvers/accelerated_proximal_gradient_descent.jl#L292-L293)); **keep the state argument** | safe mechanical | identical; IR unchanged for every measured function |
| Keep (measured alternative) | 8 pure forwards (`_eltype`, `_copy`, `_similar`, `_copyto!`, `_norm`, `_norm_diff`, `_norm_inf`, `_dot`); replacing them by direct `Base`/PB calls | **requires owner-API decision** | replacement is byte-identical and its IR unchanged apart from `copy1`'s effect, −9 lines and 8 exports; but #230 Stage 2 plans tuple consumers, #268 ruled to keep them, and `test/core_regressions.jl:90-91` tests two of them |
| Keep | everything in the "deliberately remain" list below | — | — |

**Smallest PR boundary.**
- **PR 1:** the four deletions and the consolidation. `src/blocks.jl`, `src/utils.jl`, `src/solve.jl`, and the two solver files. The diff against `782b74c` is `copy1 + fy + iter0 + trace!-args + snorm`; together they remove about 6 lines (`copy1` −1, `fy` −2, `snorm` −3; `iter0` and the argument drop are line-neutral), one field, one export and three net method definitions. Measured as one tree on both Julia versions (12,856 cases): every result, trace, callback log, exception and output is byte-identical to base. The raw records differ only in the dumped `f_y` state field (2,064 records), and they are identical with that field excluded. Its measured IR differences comprise the instruction removals, changed call signatures/operands and APG field offsets described below. No current test directly references the removed names, the field or the state-norm helpers. On the PR 1 tree, `aqua`, `accelerated_pgd`, `minimal_core_characterization`, `core_regressions` and `core_contracts` pass: 11,517/11,517 on Julia 1.10.12 and 11,534/11,534 on 1.13.3. The rest of the suite and CI were not run.
- **No PR 2 recommended.** The forwards stay unless a new owner-API ruling explicitly replaces their tuple operations. If that ruling comes, `test/core_regressions.jl:90-91` ("retained dense primitives") would change from `PS._norm`/`PS._norm_diff` to `norm`/`norm_diff`.

The gain is small. Leaving PR 1 unimplemented preserves current behaviour; its speed benefit is unmeasured.

### Answers to the questions

**Q1. `Blocks` wrappers and owner extension.** PB at the pin already contains #737: `SymmetricSparseIterate` is not an `AbstractArray`, and it has `Base.eltype`, `copy`, `similar` (returning an owner), `copyto!` (owner←owner, owner←matrix), `LinearAlgebra.norm` and `norm_diff` (PB `src/sparse_iterate.jl:123, 1311, 1821-1871, 2070, 2185-2187` at `c123d56`). Per wrapper:

| wrapper | owner role under #230 Stage 2 | owner method at the pin | adds semantics? | recommendation |
|---|---|---|---|---|
| `_eltype`, `_copy`, `_copyto!`, `_norm`, `_norm_diff` | owner `x`; tuples of owners and arrays | yes for a single owner (Base/PB); these methods alone do not supply the archived blockwise tuple contract | not for a single owner; yes for tuples (#233 maps or combines block by block) | keep |
| `_similar` | owner `x_previous`; trial buffers (`xhat`, `delta_x`, `y`); tuples | `similar` returns a single owner | no added semantics for a single owner; #233 maps over tuple blocks and uses a separate dense `_trial_similar` at owner trial sites | keep; restore the allocation split when owner/tuple support returns |
| `_norm_inf`, `_dot` | dense gradients and steps; tuples | n/a | for tuples only (#233) | keep |
| `_copy!` | as `_copyto!` | none (`copy!` resizes; PB has no owner `copy!`) | no | delete (PR 1) |
| `_dense_similar`, `_sub!`, `_step!`, `_extrapolate_point!` | dense ← owner arithmetic | — | yes (owner-specific loops in #233) | keep |
| `_dot_diff`, `_maxabs_axpy`, `_maxabs_residual`, `_maxabs_diff`, `_maxabs_stepdiff` | fused one-pass reductions in `T` | — | yes (numerical contract) | keep |

- A `SolverVectors`-style adapter is **not worthwhile**: there is one implementation, and an adapter would add a layer, not remove one.
- No dynamic dispatch or piracy arises either way. The forwards are statically resolved one-liners, and Aqua is clean on the prototype that removes them.
- #230 already includes tuple restoration ("Stage 2: proximal gradient, acceleration, and tuples", with `(owner, dense)` tuples). These wrappers therefore retain planned product-space consumers. Prefer retaining the eight forwards unless a new owner-API ruling explicitly replaces those tuple operations; PB's single-owner methods alone do not settle that decision.

**Q2. State norms.** The two definitions are textually identical. #267 added the APG copy. The state argument is unused today, but in archived #233 it dispatched on `s.metric`, which served the diagonal preconditioner (still a deferred keyword).
- One `Union` method keeps that seam and is exact. IR is unchanged for every measured function, on both versions.
- Dropping the state argument is a separate metric/owner decision and is not recommended now.

A related finding belongs to #270. `convergence_assessment` tests `norm(delta_x)` ([utils:33](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/utils.jl#L33)). The trace and `x_residual` report `norm_diff(x, x_previous)` ([utils:14](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/utils.jl#L14), [solve:127](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/solve.jl#L127)). The two differ in bits on 15–29% of corpus iterates, by a few units in the last place on ordinary data. Unifying them changes either the tested or the reported value, so it is not classified here.

**Q3. Shared control plane.** `_solve_gradient!`, `trace!` and `convergence_assessment` are already shared. Prototyped:
- **Shared `solve!` body:** +7 lines, IR unchanged, inference equal. It saves nothing and touches the preflight that #280 owns. **Not worthwhile.**
- **Shared trial-point helper:** step, prox, value and two counters (`pgd:130-134`, `apg:220-224`). +3 lines. On Julia 1.13 Float64 and on 1.10, the helper is not inlined, which changes the compiled PGD and APG steps; fingerprints stay identical. **Not worthwhile.** It would need `@inline` and a timing gate for no conceptual gain.
- **`initial_state`:** the two differ on purpose. PGD evaluates value and gradient (`f_calls = grad_calls = 1`), APG only the value (`grad_calls = 0`). APG swaps image buffers ([apg:180](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/solvers/accelerated_proximal_gradient_descent.jl#L180)) where PGD copies. **Not shared.**
- **`gradient_converged!`:** the same five-line skeleton with different operands. Sharing it needs two hooks to save about five lines and sits on the stop rules (#270). **Not worthwhile.**

**Q4. Line searches.** PGD's TFOCS backtracking ([line_searches:58-114](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/line_searches.jl#L58-L114)) and APG's certified test are different acceptance policies by design. Mixed precision also differs:
- `BackTracking()` stores Float64, so Float32 PGD forms `α L` and `L/β` in Float64 and rounds on store ([pgd:125](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/solvers/proximal_gradient_descent.jl#L125), [line_searches:81,110](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/line_searches.jl#L81)).
- APG converts `α` and `β` to `T` first ([apg:162,183](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/solvers/accelerated_proximal_gradient_descent.jl#L162)). Both forms are reached by the probes on Float32 data.
- Unifying the factor conversions can change Float32 bits. A shared helper could preserve the existing caller-specific conversions, but it offers little beyond the already shared `next_curvature`. **Keep the current arrangement.**

The pieces that are worth sharing already are: `next_curvature`, `_step!`, `value_and_prox!` and `_value!`.

**Q5. `_SE` versus PB numerical kernels.** PB at the pin already has `_parts`, `_parts_product` and `_ExpSum` (`src/utils.jl` ≈561-586; master moved them to `numerical_kernels.jl`) and one-sided magnitude helpers (`_bound_exponent`; master's `_upper_exponent`, "an upper bound only").
- `_SE` (s ∈ [1, 2)) and frexp parts (m ∈ [1/2, 1)) differ by an exact power of two, so the representation is not the obstacle.
- The obstacles are three:
  1. The PB helpers are private.
  2. They return range-safe **point values** (`_ExpSum` with compensated additions) or magnitude bounds, and state **no rounding-error bound**.
  3. The APG constants (`_BoundConstants`, κ = 32u covering "the fixed number of `_SE` products and sums on each side", [image_models:243-247](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/solvers/image_models.jl#L243-L247)) are derived for `_SE`'s own operation count. A replacement must prove equivalence to the operations already covered by κ, or supply revised rounding-error bounds if its arithmetic differs. `_parts`/`_parts_product` normalize and multiply as `_SE` does and could perhaps be shown equivalent; `_ExpSum` (compensated sums) is materially different.
- A point estimate cannot replace the certified bound.
- The cost of the certified test is already measured in #271 and was not re-measured. The measured ordinary APG updates allocate zero bytes. Compilation cost and Float32/Float64 speed relative to PB-based alternatives were not compared.
- **Keep `_SE` local.** If a certified range-safe primitive is ever wanted in PB, it is a PB API proposal for its own issue, not something to borrow from PB internals.

**Q6. Provably unused after #268 and #276.**
- **Unused:** `f_y` as a field, the `iteration > 0` test, and the `trace!` arguments.
- **Kept, because tests or diagnostics read them:** `fresh_only` (internal validation switch, `test/accelerated_pgd.jl:515`), `fallbacks` (:518), `restarts` (:217-220, :562, :697) and `normx_previous` (:556).
- **Kept:** PGD's separate `G` type parameter, as an owner seam (dense gradient beside an owner `x`); `max_residual`, because both current gradient stopping tests read and update it.
- **`convergence_assessment`'s `f, g`:** unused today. Prototyped removal is exact, but historical `docs/audit/20261026/performance*.jl` call it with them. A future duality gap (`gap = NaN` is a documented sentinel) would need `f, g` there. **Keep** unless gap certificates are ruled out.
- **Not reached by the probes:** the `W`, `N` and `normx`/`D` failure branches of the APG test. Overflow of a sum of squares alone takes the scaled fallback, not these branches. On the current least-squares path, finite `f(x)` and `f(y)` keep both cached images within about √floatmax(T) of the response (the residual squares are summed in `T` before the scale is applied), so their difference cannot be nonfinite and `N === nothing` cannot occur there. Reachability of the other two branches has not been established end to end. **Keep them as defensive guards.** *Correction to the base-probe comment:* its claim that all three failure branches are reachable at the overflow edge was unsupported. The finite-value checks exclude `N === nothing` on the current least-squares solver path; reachability of the other failure branches remains unestablished.

### Deliberately remain (do not merge or simplify)

- **Fused reductions** `_dot_diff`, `_maxabs_axpy`, `_maxabs_residual`, `_maxabs_diff`, `_maxabs_stepdiff`: single-pass native-precision reductions. `_maxabs_diff` is also an operand of the certification (`_se_norm_diff`, [image_models:94](https://github.com/mlakolar/ProximalSolvers.jl/blob/782b74c/src/solvers/image_models.jl#L94)).
- **Owner-semantic operations** `_dense_similar`, `_sub!`, `_step!`, `_extrapolate_point!`.
- **The whole APG certification:**
  - `_SE` and `_se_zero/_renormal/_se_le/_se_add/_se_sub`, and `_se_mul`'s fixed arities (a vararg brings #272 back);
  - `_sumsq*`, `_se_norm*` and their one-pass/two-pass fallbacks (both reached);
  - `_unit`, `_gamma`, `_frobenius_upper`, `_significand_exponent`, `_root_scale`, `_BoundConstants`, `_bound_certified!`, `_image_error_bound`, and the defensive `nothing` guards.
- **The two acceptance policies, and their different precision handling.**
- **`LineSearches.has_updated_gradient`** (exported), **`LineSearches.value_and_gradient_at_x!`** (qualified extension hook), `next_curvature`.
- **State fields** `fresh_only`, `fallbacks`, `restarts`, `normx_previous`; PGD's `G` parameter; `convergence_assessment(state, f, g, options)`.
- **`initial_state` per solver.**

### Not worthwhile

- A `SolverVectors` adapter.
- Shared trial-point helper.
- Shared `solve!` body.
- Shared `gradient_converged!`.
- Shared curvature update.
- Replacing `_SE` by PB helpers without an equivalence proof or revised bounds.

### Routed to other issues

- **#270:** tested `norm(delta_x)` versus reported `norm_diff(x, x_previous)` (bit differences on 15–29% of iterates).
- **#277:** a raw `LeastSquaresLoss` gives `α = true`, which takes the 256-bit `BigFloat` route of `_significand_exponent` once per APG solve (nothing per iteration). A `BigFloat` loss scale allocates about 1.2 KB per `update_state!` through the value arithmetic.
- **#280:** the per-iteration trace `Dict()` (public `OptimizationState.metadata`), the `solve!` preflight, the historical `docs/audit` scripts that call `convergence_assessment` with `f, g`, and the stale `project_hash` of `Manifest-v1.10.toml` (Julia 1.10 warns that the manifest is out of date with `Project.toml`).

### Evidence and its limits

- **Fingerprints.** 12,856 seeded PGD/APG cases. Each record has every result field bit-exact, the traces with metadata, the callback logs, `show_trace` output, exceptions and the state after rollback. Every comparison runs in a fresh process per tree, within one job.
  - A/A is byte-identical on both versions.
  - `copy1`, `iter0`, the argument drop, `snorm`, the shared `solve!`, the trial helper and the forwards are each byte-identical to base on both versions.
  - `f_y`'s removal differs only in the state dump (2,064 records); it is identical once that field is excluded.
- **LLVM IR.** Normalized, with an A/A control that is 40 of 40 identical.
  - Unchanged: `snorm`, the shared `solve!`, and the forwards apart from `copy1`'s effect.
  - Changed by removal only: `copy1` (two `resize!` branches), `iter0` (one compare and select), the argument drop, and `f_y` (one load/store, field offsets).
  - Changed by inlining: the trial helper.
- **Other checks.**
  - Inference: equal for every candidate.
  - Allocations were checked for `copy1`, `trial`, `fy`, `all-a` and `all`: unchanged except 48 bytes saved on 27 of 220 scenarios with `f_y` removed. The PR 1 tree gives the same result: 193 of 220 identical, 27 lower by 48 bytes, none higher, on both versions; warmed `update_state!` allocated bytes are unchanged at the measured update indices.
  - Aqua: 11/11 on the all-candidates prototype on both versions.
  - Tests on that prototype: `accelerated_pgd`, `minimal_core_characterization`, `core_contracts` and `core_regressions` all pass, apart from the 4 expected `core_regressions.jl:90-91` errors caused by the forwards.
- **Not done.**
  - **No timing.** No timing was run. The plan pre-registered timing for candidates whose IR changes. PR 1's measured IR differences include instruction removals, changed call signatures/operands and APG field offsets; these observations do not discharge the timing gate. PR 1 remains a mechanically justified candidate with performance acceptance pending. Any coding follow-up requires maintainer authorization, independent review, required CI and benchmark acceptance. The trial helper, the one candidate whose IR changes by inlining, is not recommended. This is a deviation from the plan.
  - **Single CPU kind.** All runs were on AMD Zen 3; AVX-512 hosts were not used. IR equivalence was checked only for the measured specializations on Zen 3.
  - **Scripts not attached.** The probe scripts and outputs (fingerprint harness, coverage probe, IR comparison) are kept with the run. They can be attached on request.

<details><summary>Prototype diff for PR 1 (illustration, never pushed): copy1, iter0, f_y, snorm, trace! arguments; +10/−16 in src</summary>

```diff
diff --git a/src/blocks.jl b/src/blocks.jl
index f21b00e..cec94e4 100644
--- a/src/blocks.jl
+++ b/src/blocks.jl
@@ -2,14 +2,13 @@ module Blocks
 # Private native-vector operations; historical reductions are retained.
 using LinearAlgebra
 using ProximalBase: norm_diff
-export _eltype, _copy, _similar, _dense_similar, _copyto!, _copy!, _sub!, _step!, _norm, _norm_diff, _norm_inf, _dot, _dot_diff, _maxabs_axpy, _maxabs_residual,
+export _eltype, _copy, _similar, _dense_similar, _copyto!, _sub!, _step!, _norm, _norm_diff, _norm_inf, _dot, _dot_diff, _maxabs_axpy, _maxabs_residual,
        _extrapolate_point!, _maxabs_diff, _maxabs_stepdiff
 _eltype(x::AbstractArray) = eltype(x)
 _copy(x::AbstractArray) = copy(x)
 _similar(x::AbstractArray) = similar(x)
 _dense_similar(x::AbstractArray{T}) where {T} = Array{T}(undef, size(x))
 _copyto!(y::AbstractArray, x::AbstractArray) = copyto!(y, x)
-_copy!(y::AbstractArray, x::AbstractArray) = copy!(y, x)
 _sub!(y::AbstractArray, a, b) = (@. y = a - b; y)
 _step!(y::AbstractArray, x, g, L) = (@. y = x - g / L; y)
 _extrapolate_point!(y::AbstractArray, x, xp, ω) = (@. y = x + ω * (x - xp); y)
diff --git a/src/solve.jl b/src/solve.jl
index a542d95..354dab3 100644
--- a/src/solve.jl
+++ b/src/solve.jl
@@ -100,7 +100,7 @@ function _solve_gradient!(state, f, g, method, options, t0 = time())
 
     if tracing
       # update trace; callbacks can stop routine early by returning true
-      stopped_by_callback = trace!(tr, f, g, state, iteration, method, options)
+      stopped_by_callback = trace!(tr, state, iteration, options)
     end
 
     stopped_by_time_limit = time()-t0 > options.time_limit ? true : false
diff --git a/src/solvers/accelerated_proximal_gradient_descent.jl b/src/solvers/accelerated_proximal_gradient_descent.jl
index 9aa5b28..7082e4e 100644
--- a/src/solvers/accelerated_proximal_gradient_descent.jl
+++ b/src/solvers/accelerated_proximal_gradient_descent.jl
@@ -79,7 +79,6 @@ mutable struct AccProxGradDescentState{T, X<:Vector{T}, M, Z}
     f_x_previous::T
     g_x_previous::T
     y::X
-    f_y::T
     grad_f_y::X
     xhat::X
     delta_x::X
@@ -125,7 +124,6 @@ function initial_state(
                          T(NaN),
                          T(NaN),
                          _similar(x0), # extrapolated point y
-                         T(NaN),      # f(y)
                          _dense_similar(x0), # gradient of f at y
                          _similar(x0), # Temporary storage
                          _similar(x0), # x - x_previous
@@ -207,12 +205,12 @@ end
 # f(x) ≤ f(y) + ⟨∇f(y), x - y⟩ + L/2 ‖x - y‖² (with legacy's slack 8eps on L), or until
 # x == y entrywise.
 function _prox_grad_step!(f, g, state::AccProxGradDescentState{T}, β::T) where T
-    state.f_y = _value_and_gradient!(state.grad_f_y, state.y, state.model, state.z_y, state.dz)
+    f_y = _value_and_gradient!(state.grad_f_y, state.y, state.model, state.z_y, state.dz)
     state.f_calls += 1
     state.grad_calls += 1
     # An extrapolated y whose value or gradient overflows gives no step; f(x) = Inf
     # makes the caller restart from x_previous, or, without momentum, fail with rollback.
-    if !(isfinite(state.f_y) && _allfinite(state.grad_f_y))
+    if !(isfinite(f_y) && _allfinite(state.grad_f_y))
       state.f_x = T(Inf)
       return state
     end
@@ -289,9 +287,6 @@ function gradient_converged!(state::AccProxGradDescentState, options::ProximalOp
   residual / (state.max_residual + options.gradtol) < options.gradtol || n_residual < options.gradtol
 end
 
-_state_norm(s::AccProxGradDescentState, x) = _norm(x)
-_state_normdiff(s::AccProxGradDescentState) = _norm_diff(s.x, s.x_previous, 2.)
-
 """
     solve!(x, f, g, AccProxGradDescent(), options=ProximalOptions())
 
diff --git a/src/solvers/proximal_gradient_descent.jl b/src/solvers/proximal_gradient_descent.jl
index 63b3a28..91cb009 100644
--- a/src/solvers/proximal_gradient_descent.jl
+++ b/src/solvers/proximal_gradient_descent.jl
@@ -118,10 +118,10 @@ function update_state!(
     ) where T
 
     # copy x --> x_previous
-    _copy!(state.x_previous, state.x)
+    _copyto!(state.x_previous, state.x)
     state.f_x_previous = state.f_x
     state.g_x_previous = state.g_x
-    _copy!(state.grad_f_x_previous, state.grad_f_x)
+    _copyto!(state.grad_f_x_previous, state.grad_f_x)
     state.L *= method.ls.α
 
     # backtracking loop
diff --git a/src/utils.jl b/src/utils.jl
index 5f0c10a..3e7926e 100644
--- a/src/utils.jl
+++ b/src/utils.jl
@@ -4,9 +4,9 @@
 #
 
 # Records iteration `iteration` and calls the callback; returns whether it stopped the solve.
-function trace!(tr, f, g, state, iteration, method::ProximalSolver, options)
+function trace!(tr, state, iteration, options)
     dt = Dict()
-    if options.extended_trace && iteration > 0
+    if options.extended_trace
         dt["x"] = _copy(state.x)
         extended_trace!(dt, state)
     end
@@ -64,5 +64,5 @@ function gradient_converged!(state::ProximalGradientDescentState{T}, options::Pr
   residual / (state.max_residual + options.gradtol) < options.gradtol || n_residual < options.gradtol
 end
 
-_state_norm(s::ProximalGradientDescentState, x) = _norm(x)
-_state_normdiff(s::ProximalGradientDescentState) = _norm_diff(s.x, s.x_previous, 2.)
+_state_norm(s::Union{ProximalGradientDescentState, AccProxGradDescentState}, x) = _norm(x)
+_state_normdiff(s::Union{ProximalGradientDescentState, AccProxGradDescentState}) = _norm_diff(s.x, s.x_previous, 2.)
```

</details>
