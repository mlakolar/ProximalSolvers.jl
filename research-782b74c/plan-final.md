## Research plan

Drafted by the orchestrator. Critiqued by Claude Opus (high effort), revised.

The maintainer's standing direction for the research issues #277–#280 applies: each runs in an independent worktree, re-verifies the current PS and PB revisions, reads the actual code, and posts its findings and **one preferred design** on the issue: what can be deleted, what should be consolidated, and what should deliberately remain. **No production-code change and no implementation PR.** Prototype diffs that the memo shows are illustrations, not proposed patches. Any eventual implementation keeps the Float32/Float64 fast paths and the established performance requirements.

### Identities (re-resolved)

- PS `master` = `782b74c` (#276 is merged, so "after accounting for #276" means the merged code).
- The PB pin in `Project.toml` `[sources]` is `c123d56` (the Julia 1.10 manifest pins the same `repo-rev`). PB `master` = `1f3e98b`, 93 commits later.
- Julia 1.10.13 (the compat floor, where #272 showed up) and 1.13.3 (current release; CI runs `'1'`).

### Starting observations (to confirm or refute, with file:line evidence in the memo)

1. **State norms.** `_state_norm(s, x) = _norm(x)` and `_state_normdiff(s) = _norm_diff(s.x, s.x_previous, 2.)` are identical for PGD (`src/utils.jl:67-68`) and APG (`src/solvers/accelerated_proximal_gradient_descent.jl:292-293`). The state argument is unused today. In the archived owner/metric PR #233 (unmerged), it was there to dispatch on `s.metric`, which served the diagonal preconditioner. That preconditioner is still a deferred keyword. Merging the two definitions is exact, but whether to keep the state argument is an **owner/metric API decision**, which is how #268 deferred it.
2. **Tested versus reported step length.** `convergence_assessment` tests `_norm(delta_x)` (`utils.jl:33`). The trace (`utils.jl:14`) and the result's `x_residual` (`solve.jl:127`) report PB `norm_diff(x, x_previous)`. They can differ in bits:
   - `LinearAlgebra.norm` uses `generic_norm2` below length 32 and BLAS `nrm2` from 32 on. For Float32, `generic_norm2` accumulates in Float64.
   - PB's ordinary path accumulates in `T`.
   - Any change of operand here touches the stop rules or the reported numbers, so it goes to **#270**. This issue reports only the measured frequency of the difference.
3. **`Blocks` wrappers and owners.** PB (pin and master) already gives `SymmetricSparseIterate` `eltype`, `copy`, `similar`, `copyto!` and `norm`. So `_eltype`, `_copy`, `_similar`, `_copyto!`, `_norm` and `_norm_diff` add no owner semantics; only their `::AbstractArray` restriction stands in the way. In #233, `_sub!`, `_step!`, `_extrapolate_point!`, `_maxabs_diff`, `_maxabs_stepdiff` and the trial/dense-similar pair carried owner-specific code. Today both states pin every buffer to `X<:Vector{T}` and allocate trial buffers with `_similar`, so owner support would revisit these call sites and structs anyway. The memo gives a per-wrapper table: callers, the Base or PB method an owner would need at the pin and at master, and whether the wrapper adds semantics.
4. **Line searches.** PGD's TFOCS backtracking and APG's certified test are different acceptance policies by design. Mixed precision also differs:
   - `BackTracking()` stores Float64, so Float32 PGD forms `αL` and `L/β` in Float64 and rounds on store (`proximal_gradient_descent.jl:125`, `line_searches.jl:81,110`).
   - APG converts `α` and `β` to `T` first (`accelerated_proximal_gradient_descent.jl:162,183`).
   - A shared curvature-update helper would therefore change Float32 bits. The trial-point blocks (`proximal_gradient_descent.jl:130-134`, `accelerated…jl:220-224`) differ in their `convert` target.
5. **`_SE` versus PB.** The pin already has PB's private `_parts`, `_parts_product` and `_ExpSum` (in `utils.jl`; master moved them to `numerical_kernels.jl`), plus one-sided magnitude helpers (`_bound_exponent`, `_upper_exponent`).
   - `_SE` (s ∈ [1, 2)) and frexp parts (m ∈ [1/2, 1)) differ by an exact power of two, so the arithmetic itself is not the obstacle.
   - The obstacles are three. The PB helpers are private. They give range-safe point values (and `_ExpSum` uses compensated adds), not stated rounding-error bounds. And κ = 32u in `_BoundConstants` is derived for `_SE`'s fixed operation count.
   - A point estimate is never proposed as a certification replacement. A PB-side certified primitive, if worth proposing, is routed to a PB issue; no PB API is sketched here.
6. **Small items.** Unused arguments `f, g, method` of `trace!` and `f, g` of `convergence_assessment`. A branch `iteration > 0` (`utils.jl:9`) that is always true at its only call site. `f_y`, which is written and read inside `_prox_grad_step!` only. `_copy!` and `_copyto!` both used for same-size vector copies (one wrapper would be `_copyto!`: `copy!` resizes, and PB has no owner `copy!`). Not dead: `fresh_only`, `fallbacks`, `restarts`, `normx_previous` (used by the solver or by tests).

### Work

**W1. Inventory (orchestrator, source).** A call-site and dispatch table for every `Blocks` export, the state-norm helpers, `gradient_converged!`, `g_residual`, `extended_trace!`, `value_and_gradient_at_x!`, `has_updated_gradient`, `next_curvature` and the APG certification helpers (`_SE` family, `_BoundConstants`, `_frobenius_upper`, `_root_scale`, `_image_error_bound`, the one-pass/two-pass norms). It covers callers in `src/`, tests, benchmarks and scripts (frozen campaigns excluded); the #233 owner and tuple methods; the planned consumer (#230 Stage 2, PB owner contract `docs/design/symmetric-sparse-iterate-0.6.md`); and the lines and fields a change removes. A **"conflicts with rulings"** column records #268's rulings: kept `Blocks` wrappers, state norms, fused reductions, exported `LineSearches` names, no-op keywords and the bound test; deferred owner seams. Also read: the #276 diff, #230/#224, `docs/src/developer/implementation-notes.md` (APG bound test) and `docs/src/numerics.md`.

**W2. Base probes** (disposable scripts in the run directory; Julia 1.10 and 1.13; Float32 and Float64). For each path, a reached flag from counters or a wrapped hook, plus warmed `@allocated` of `solve!` and of one `update_state!`:
- PGD:
  - default `BackTracking` (Float64) and an all-Float32 `BackTracking`, both with Float32 data;
  - finite `Lexact` and the `L >= Lexact` exit;
  - the simple-to-gradient mode switch;
  - a zero step in both modes;
  - a nonfinite trial value;
  - the `next_curvature` error and the rollback.
- APG:
  - accept, early reject, reject after the fresh product, `W === nothing`, `normx`/`D === nothing`;
  - the one-pass to two-pass norm fallbacks;
  - the scaled branch of `_frobenius_upper`;
  - a non-IEEE `Scaled` α (Int, Rational, BigFloat);
  - `fresh_only`, restart, `x == y`, nonfinite `y`, overflow rollback.
- Engine:
  - `store_trace`, `show_trace`, `extended_trace` alone, callback stop;
  - `time_limit`, the f/grad/prox call limits, `allow_f_increases`;
  - the refusals.
- Sizes: n and p on both sides of 32 and above 1024.

Also measured: how often item 2's two norms differ in bits, split by `T` and by length below or above 32, and TTFX for the default path only (the precompile workload covers default options). The certification cost is not re-measured: #271 has it. At most, a profiler share of the scalar `_se_*` arithmetic on one Float32 and one Float64 case, with no fast path explored.

**W3. Prototypes** (detached prototype worktree; local commits, never pushed). One commit per candidate against `782b74c`, so each one's LOC is separable.
- **C-a, safe-mechanical candidates:** one `_copyto!` wrapper; the unused `trace!`/`convergence_assessment` arguments; the always-true branch; `f_y` as a local; a shared `solve!` setup. For that last one, the call counts (PGD's initial value and gradient against APG's value only) are part of the criterion, and the preflight split is coordinated with #280. A shared trial-point helper is a call-site move only, with no change to the `_value!` seam (#277).
- **C-b, owner-API candidates, prototyped only for exactness and LOC:** a single `_state_norm`/`_state_normdiff`, and dropping the `::AbstractArray` restriction or inlining the pure forwards (static LOC count plus an IR spot check; no timing).
- **Routed elsewhere, not prototyped:** a shared `gradient_converged!` body and any norm-operand change (#270); trace `Dict`/metadata, `solve!` fallbacks and result fields (#280).

**Criteria for "safe mechanical":**
- byte-identical fingerprints against base in fresh processes on the same node, both `T`, both Julia versions (fingerprints never compared across nodes or versions), with `BLAS.set_num_threads(1)` and `Sys.CPU_NAME`/`BLAS.get_config()` recorded;
- unchanged `@code_llvm` (modulo names) of `update_state!`, `_prox_grad_step!`, `backtrack!`, `convergence_assessment` and `_solve_gradient!`;
- unchanged inference;
- `Aqua.test_all` clean;
- identical exception types, messages and post-rollback state;
- warmed allocations not higher.

Timing runs only for a candidate whose IR changes, through the repository's formal harness (pinned revisions, rotated repetitions, A/A control), judged on the median paired ratio with its spread. A reproducible slowdown above 5% on an ordinary path goes to the maintainer.

**Fingerprint corpus.** It reuses the coverage of #268's gradient fingerprint (12,868 PGD/APG records: every result field, traces with metadata, callbacks, limits, `show_trace` output, rollback, refusals; A/A and B/B controls). The script is rebuilt if it cannot be found, and extended with W2's APG branches.

**Environment guard.** Probes never run `scripts/instantiate.jl`, which resolves from local master checkouts. Every output records `pkgdir(ProximalBase)` and its tree hash, and fails unless they match the pin.

**W4. Memo and review.** The memo ranks the opportunities. Each is classified **safe mechanical / requires numerical proof / requires owner-API decision / not worthwhile**, with the smallest PR boundary, LOC and conceptual savings, compiler and owner impact, and evidence (scripts and outputs). It ends with explicit **delete / consolidate / deliberately keep** lists, the keep list including the indispensable fused kernels and the APG certification pieces. A Codex reviewer checks the draft against the code and the evidence before it is posted.

### Where

Julia runs on a cluster (Slurm), apart from the local import check.

### Out of scope

- Least-squares oracle mathematics and loss ownership (#277).
- CD (#278).
- Results, `solve!` fallbacks and API scaffolding (#280).
- Stop rules (#270).
- The Float32 bound-cost study (#271), referenced only.
- Any PB pin change; any production change or PR.

### What the critique changed

- **Q5 against the pin:** PB's significand/exponent helpers are already at the pin. Q5 is answered there, and master is used for direction only.
- **#233's `_norm` family:** these wrappers took owners in #233 through PB's own `norm`. The per-wrapper table now asks whether each wrapper adds semantics at all.
- **`_state_norm`'s state argument:** it was the metric seam in #233, so that consolidation moved from "safe mechanical" to "owner-API decision".
- **Mixed precision:** the Float32 PGD/APG difference in forming `αL` and `L/β` is recorded, and it rules out a shared curvature helper.
- **Probe coverage:** about a dozen reachable branches were added, plus size splits at 32 and 1024.
- **Timing:** in-process two-module timing was replaced by IR equality plus fingerprints. Timing only through the formal harness, for a candidate whose IR changes.
- **Certification cost:** cited from #271 rather than re-measured.
- **Routing:** explicit for #270 (stop operands, `gradient_converged!`), #277 (`_value!` seam) and #280 (metadata, `solve!`).
- **Environment:** the PB pin is guarded in the probe environments, and BLAS threads and CPU kind are recorded.
