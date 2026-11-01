# Consistent logging for optimization solvers

Design proposal, 24 October 2026.

**Status, 28 October 2026.** This is a proposal, not yet implemented; it is
tracked in #133. It was written against development commit 34f26a8, before
0.2.0. 0.2.0 has since renamed `printEvery` to `print_every`, so the
deprecation of `printEvery` planned under "Compatibility and implementation
sequence" is done. `logging_probe.jl` now uses `print_every`, and it passes all
23 checks on master e72fb4b with Julia 1.13.3. The observations under "Current
capabilities" therefore still hold, apart from that name.

Put a small shared progress interface in **ProximalSolvers**, and forward it from CoordinateDescent and CovarianceSelection. Use Julia's standard `Logging` for structured events, an ordinary `IO` table for interactive output, and a separate scalar trace for analysis. Keep these consumers independent: changing how often a table prints must not change callback frequency or the stored history.

The first implementation should add `TraceOptions`, a typed progress record, a stable callback contract, and common result accessors. Existing logging packages can handle routing, formatting, and files. The meaning of a pass, a residual, or a convergence certificate belongs to the solver interface.

## Current capabilities

The primary package checkout is still named `ProximalOPT.jl`, but its current development branch defines `ProximalSolvers`. The primary CoordinateDescent checkout is also behind development. This assessment uses ProximalSolvers commit `34f26a8037cf4cb9f1b0ae277ebdc73101188623` and CoordinateDescent commit `bc35789dbe42565134da60854274c3a73c7e9068`, fetched from their remotes for this investigation.

| Component | Existing support | Main gap |
| --- | --- | --- |
| PG, accelerated PG, monotone accelerated PG | `show_trace`, `store_trace`, `extended_trace`, `printEvery`, callable `callback`; objective, iterate change, step size | Callback receives a trace vector when storing and a state otherwise; display and callbacks share a cadence; no common elapsed time or termination reason |
| ADMM | Printed objective and primal/dual residuals; final residuals, tolerances, counts, gap | Ignores `store_trace`, `extended_trace`, and `callback`; display evaluates an otherwise unnecessary objective |
| Active-set accelerated PG | Outer table and inner PG logging | The same options reach inner solves, so output mixes levels; outer result has no common trace |
| Coordinate descent | Final `CDResults`, convergence warning, optional final gap and screening checks | No progress table, stored per-pass trace, or per-pass callback |
| Paths, continuation, proximal Newton, LLA, reweighting | Path summaries and `callback(k, λ, x, m)` for completed path levels | Several event meanings and nested iteration counts; no shared observation mechanism |
| CoordinateDescent | Options forwarding, estimator and path convergence fields; private path callbacks collect intercepts | `CDOptions` rejects logging keywords; `_solver` constructs an engine, but reporting must also pass through `_solve!`, paths, Newton and CV |
| CovarianceSelection | ADMM wrappers; `verbose` for a path; several legacy callbacks; automatic IHT adapts the PG trace | Package-specific output and callback adaptation |
| ProximalBase | Warnings for inexact internal projection | No shared optimization history; keep this package focused on functions and operators |

The CovarianceSelection and ProximalBase observations use locally available remote snapshots `dbf3b5f2fb99a73feb67d5a1d7b64b7b38397020` and `c2c917db9b952c3f6b5d508e127dce009fd12b5a`. These secondary remotes could not be refreshed because DNS resolution failed. FunctionalGraphicalModels' checked-out branch also has a separate graphical-lasso loop and convergence warning; integrating such loops is a later adoption step.

The existing PG trace stores **every iteration**, even when `printEvery > 1`. Its docstring says that `printEvery` controls storage too, which disagrees with `update!`. Trace entries use a `Dict` for metadata and force scalar values to `Float64`. Sparse/full iterate copies occur when extended tracing is enabled.

### Behavioral checks

The companion [logging_probe.jl](logging_probe.jl) checks the existing implementation on a small deterministic problem:

- PG callbacks occur at iterations 2 and 4 with `printEvery=2`. With storage enabled, the callback argument becomes a vector containing all four iteration records.
- ADMM calls the supplied callback zero times and returns no trace field despite `store_trace=true`.
- Eight ADMM iterations use one `f` evaluation with output disabled and nine with output enabled. The iterates, iteration count and prox count agree.
- A PG solve converges before `printEvery=100` and prints a header without a numeric row. There is no forced final progress row.
- A per-pass callback keyword on a CD solve is rejected; keyword dispatch selects the continuation driver and reports its missing required keyword.

These are observations of the current API. The examples below describe the proposed API.

The probe passed all 23 checks on Julia 1.10.12 and 1.13.2 with the source snapshots identified above. To repeat it from this ProximalSolvers snapshot with dependencies resolved, run `julia --startup-file=no --project=. docs/design/logging_probe.jl`. It measures behavior, not logging overhead.

## Lessons from other solvers

**Optim.jl** provides familiar names for display and storage, an extended trace, and a callback that can stop a solve. Reuse the vocabulary while giving the new callback a fixed argument type independent of storage. [Optim options](https://julianlsolvers.github.io/Optim.jl/latest/user/config/).

**SCS** separates verbose console output from optional CSV iteration logs and explicitly warns about CSV overhead. **OSQP** returns structured status, objective, residual, iteration, and timing information independently of its `verbose` setting. Adopt this separation of console, optional history, and final statistics. [SCS settings](https://www.cvxgrp.org/scs/api/settings.html), [OSQP settings](https://osqp.org/docs/interfaces/solver_settings.html), [OSQP results](https://osqp.org/docs/interfaces/python.html).

**JuliaSmoothOptimizers** establishes a common execution-statistics contract across solvers and documents callbacks and standard logging. Its full NLPModels interface is a broader integration choice than this task needs. Borrow the shared statistics/accessor pattern. [SolverCore conventions](https://jso.dev/SolverCore.jl/dev/1-jso-compliant/).

## Package choices

| Package | Appropriate role | Recommendation |
| --- | --- | --- |
| Julia `Logging` standard library | Structured events, task-local routing, filtering, warnings | Core dependency; use `with_logger`, leaving global logger selection to the application |
| LoggingExtras.jl | Tee events to destinations, filter, format, and rotate files | Optional application dependency and documented recipes |
| LoggingFormats.jl | JSON serialization of ordinary log events | Optional recipe; flatten our progress record to named scalar fields |
| ProgressLogging.jl with TerminalLoggers.jl | Progress bars for known counts such as folds or penalty levels; indeterminate jobs | Optional adapter after the core API; an iteration limit is not a reliable percentage of convergence |
| SolverLogging.jl | Configurable tabular solver output with verbosity and conditional colors | Consider only behind a console adapter; it does not supply our event, history, or termination contracts |
| TableLogger.jl | Column formatting and selective row printing | Optional console adapter; does not replace solver records or result statistics |
| SolverCore.jl | A broader solver/results ecosystem | Reconsider if we choose NLPModels interoperability; avoid requiring it just for logging |

[Julia Logging](https://docs.julialang.org/en/v1/stdlib/Logging/) supports structured key/value data and avoids computing filtered messages. [LoggingExtras](https://julialogging.github.io/reference/loggingextras/) supplies the routing components. [LoggingFormats](https://julialogging.github.io/reference/loggingformats/), [ProgressLogging](https://julialogging.github.io/ProgressLogging.jl/stable/), and [TerminalLoggers](https://julialogging.github.io/TerminalLoggers.jl/stable/) cover serialization and progress presentation.

Source inspection also gives concrete reasons to keep the default table small and internal. Both [SolverLogging's dependencies](https://github.com/bjack205/SolverLogging.jl/blob/master/Project.toml) and [TableLogger's dependencies](https://github.com/Wikunia/TableLogger.jl/blob/main/Project.toml) include `Formatting`. SolverLogging supports explicit logger instances, but its current [generic IO printing methods](https://github.com/bjack205/SolverLogging.jl/blob/master/src/logger.jl) print to the default stream rather than the supplied `IO`; its `IOStream` methods do use the supplied stream. That requires care for `IOBuffer` and notebook capture. TableLogger uses mutable, dynamically typed row storage in its [implementation](https://github.com/Wikunia/TableLogger.jl/blob/main/src/TableLogger.jl). These are formatting tools that we could wrap; neither removes the need for a solver progress protocol.

Start with `Logging` and the already-used `Printf`. Add adapters when a concrete use needs them. A new standalone ecosystem package is unnecessary while the engines already live in ProximalSolvers.

## Proposed public interface

Every engine accepts the same two new keywords, including engines that currently take positional `ProximalOptions`:

```julia
trace_options = TraceOptions(
    show_trace = true,
    show_every = 10,
    store_trace = true,
    store_every = 1,
)

result = solve!(x, f, g, CDSolver(); trace = trace_options)
history = solver_trace(result)
stats = solver_stats(result)

result = solve!(x, f, g, AccProxGradDescent(),
                ProximalOptions(maxiter = 1000); trace = trace_options)

fit = lasso(X, y, λ; show_trace = true, show_every = 10)
path = LassoPath(X, y; trace = trace_options)
```

CoordinateDescent re-exports `TraceOptions` and the common accessors. Simple `show_trace`, `show_every`, `store_trace`, and `store_every` keywords are conveniences that construct or override `trace`. They are extracted before the existing `_options` keyword validation. Keep reporting configuration on the solve call, separate from `CDSolver` and the statistical `CDOptions` fields.

### Trace options

| Option | Default | Meaning |
| --- | --- | --- |
| `show_trace` | `false` | Print a compact progress table and final summary |
| `show_every` | `10` | Display every N accepted iterations at the selected scope |
| `io` | `stderr` | Table destination; honor any `IO`, including `IOBuffer` |
| `store_trace` | `false` | Retain scalar progress snapshots |
| `store_every` | `1` | Storage interval, independent of display |
| `emit_logs` | `false` | Emit structured progress through the current Julia logger |
| `log_every` | `10` | Structured-event interval, independent of display/storage |
| `callback_every` | `1` | Frequency of the new progress callback |
| `scope` | `:outer` | Root solver/driver updates; `:all` includes nested solves |
| `variables` | `()` | Explicitly requested variable copies in retained history, such as `(:x,)` |
| `max_records` | `10_000` | Bound retained history across the root call and its children; `nothing` requests unbounded storage |
| `metrics` | `:available` | Use already-computed values; a tuple such as `(:objective, :duality_gap)` explicitly requests additional measurements |

Require positive integer intervals and a history capacity of at least two. An explicit convenience keyword overrides the corresponding field of `trace`. Unsupported extra metrics or variable snapshots raise an informative error at entry, instead of being ignored. Validate capabilities separately from whether a particular iterate has an available metric.

Initial and final events bypass sampling intervals. A final displayed state replaces a duplicate progress row where practical and always includes the stop reason. Bounded storage reserves the root's initial and final records and retains the most recent other records within the remaining budget; `stats.trace_truncated` and the dropped-record count expose eviction. Child start/finish records may be evicted under this shared budget. Their final statistics belong in the corresponding result reports rather than depending on history retention.

For `metrics=:available`, unavailable current values are `nothing`, rendered as `—`. Requested extra measurements run only at checkpoints needed by an enabled consumer. A callback that requires an objective every iteration can request it explicitly. No measurement cadence changes the algorithm's convergence-check cadence.

## Progress records and final statistics

Use an immutable `SolverProgress{T,M,C}` record with fixed common fields and concrete `NamedTuple` fields for algorithm metrics and context. Preserve the solver's scalar type `T`; elapsed seconds can be `Float64`.

The common fields are `event` (`:start`, `:iteration`, `:finish`), `solver`, `iteration`, `iteration_unit`, `elapsed`, `objective`, `termination_reason`, `metrics`, and `context`. An objective is always the original objective of the identified solve at its current accepted iterate. A restricted or quadratic inner problem has its own solve identity and objective; it must not masquerade as the outer objective.

| Method | Unit and useful metrics |
| --- | --- |
| PG variants | Accepted step; iterate/objective changes, the method's named optimality residual and tolerance, step size, backtracking and evaluation counts |
| ADMM | Completed primal/dual update; primal and dual residuals **with their thresholds**, rho, prox count; objective at the returned variable `z` when available |
| CD | Completed pass; full/active/candidate pass kind, scaled max change and its threshold, active/candidate sizes, screening and KKT checks, a current gap when computed |
| Proximal Newton | Accepted outer Newton step; outer objective/change, line-search step, inner passes and inner convergence |
| Active-set PG | Outer expansion/solve; active size, additions, outside KKT violation, inner iterations and convergence |
| Path or continuation | Completed penalty level; lambda, nonzeros, objective, passes, convergence and screening checks |
| Reweighting or LLA | Completed outer update/stage; relative weight change, objective identity, inner work/convergence |
| CV | Completed fold or final-data refit, with child path identities; aggregate errors only when the corresponding comparisons are available |

Never label a small CD coordinate change, an accelerated-PG surrogate residual, or a nonconvex stationarity check as a global optimality certificate. Preserve the chosen stopping criterion and whether it was satisfied. With gap-based stopping, show the gap and its tolerance prominently. A cached gap must carry the iteration at which it was evaluated; a stale gap cannot certify the displayed iterate.

`solver_stats(result)` returns final elapsed time, iterations with units, termination reason, convergence criterion, convergence flag, final available metrics, reliable evaluation counts, and trace-retention information. Keep `converged` separate from the reason execution ended: a callback can request stopping on an iterate that already satisfies a convergence test. Preserve both facts. Track limit flags separately when several limits coincide; use deterministic reason precedence: numerical failure, user stop, verified convergence, time limit, evaluation limit, iteration limit. Drivers additionally distinguish completed work, path/model-size limits, and subsolver failure.

All result families expose `solver_stats` and `solver_trace` through a small attached report. Preserve their numerical fields and existing outer constructors, supplying an empty/unknown report for manually constructed legacy results. CoordinateDescent fit/path/CV results retain the engine or driver report rather than reconstructing it from a Boolean. Keep direct struct-field changes localized; do not replace every result with a single universal result type.

The final metrics are measured at the returned iterate after required final checks and any screening repair. Zero iterations and empty paths still have an explicit finish record and reason. Diagnostics unavailable without extra work remain absent even in the final report, except values the existing result API already computes.

## Callback contract

Introduce `progress_callback`, leaving existing `callback` signatures intact during migration:

```julia
stop_after_500 = state -> state.progress.iteration >= 500

result = solve!(x, f, g, CDSolver();
                trace = TraceOptions(show_trace = true),
                progress_callback = stop_after_500)
```

The argument is always `SolverCallbackState(progress, x)`: an immutable scalar progress record plus a borrowed reference to the accepted iterate. High-level estimators therefore expose coefficients without requiring the caller to own their workspace. The reference is valid only during that call: do not mutate it, and call `copy` to retain it. Logs and scalar history never retain that reference. Model-specific quantities such as a GLM intercept are named scalar metrics; the record describes any coefficient scaling used by the solver.

Return `true` to stop; `false` or `nothing` continues. Reject other return values. Accept functions and callable structs. Exceptions propagate to the caller. Changing display, storage, or logger filtering cannot change the callback argument or its schedule.

Call once after each accepted iteration selected by `callback_every` and `scope`; start/finish events do not invoke the control callback. Compute termination after honoring the callback and required final checks, then emit one finish event. Rejected line-search trials do not trigger it. A callback on a child solve requests a cooperative stop of the whole root operation, including a path or CV run; it must not merely advance to the next child.

Private wrapper callbacks, such as intercept collection in `LassoPath`, remain separate and run before observing a completed level, so returned coefficient and intercept paths stay aligned even when stopping early. Legacy callbacks retain their documented behavior; if both old and new callbacks are supplied, either may request a stop.

## Nested solves and concurrency

Create a reporting session per public call. The public entry owns the root context and cancellation flag; internal solves derive child contexts with `solve_id`, `parent_id`, phase, outer iteration, path index/lambda, fold, or tuning parameter as appropriate. Generate IDs without consuming the solver's RNG. Propagate this session explicitly through helpers, including paths that reuse workspaces and call `_cd!` directly.

At `scope=:outer`, a single CD fit shows passes, a Newton fit shows Newton steps, a path shows completed lambda levels, and CV shows fold completion plus the final-data refit phase. `scope=:all` exposes the descendant streams. Root summaries aggregate child work and failures; objective curves are grouped by solve ID, never joined across penalties or folds as though they were one objective.

Callbacks run synchronously on the task owning their iterate. With threaded CV and `scope=:all`, the user callback must be thread safe; it must not assume a deterministic interleaving. The cancellation flag and shared history budget are synchronized. Console rows and shared log/file sinks must serialize each complete row/event. Root-only CV callbacks are invoked by the coordinator on fold completion. No library code replaces the global logger or installs a process-wide output redirection.

Warnings remain standard Julia warnings and stay enabled when `show_trace=false`. Intentional callback stops do not produce a misleading nonconvergence warning. A driver can report a contextual aggregate warning for repeated child failures while retaining the individual child statuses in its report. Unexpected exceptions still propagate.

## Cost and metric semantics

Resolve enabled consumers once at entry and specialize on an internal no-op observer when all reporting and callbacks are disabled. The disabled iteration path must add no formatting, dictionaries, array copies, objective/gradient evaluations, RNG draws, or per-iteration allocations. Final result statistics may require a small fixed report allocation. Measure overhead before setting a numerical performance target.

When enabled, check consumer schedules before collecting optional metrics and build one record for their union. Honor Julia's early log filtering before collecting metrics needed only by a filtered log event. The default trace contains scalars only. `variables=(:x,)` copies the accepted iterate once per stored checkpoint, preserves its sparse/block representation, and needs an explicit warning in documentation about storage proportional to problem size. A gradient copy is supported only when the corresponding gradient and its evaluation point are defined; do not relabel an accelerated method's gradient at `y` as a gradient at `x`.

For CD with momentum or Anderson acceleration, place the observation after the accepted extrapolation or rollback and any required cache refresh. A record must describe one consistent accepted iterate; label the coordinate-change metric as the change measured during the pass rather than implying it also bounds the extrapolation.

ADMM's default record uses the already-computed residuals; computing `f(z)+g(z)` solely for reporting requires `metrics=(:objective,)`. In a split constrained problem this objective can be infinite before primal feasibility even though ADMM is behaving normally. A gap request similarly needs a supported convex primal/dual formulation. Report undefined diagnostics as unavailable, without treating every infinite diagnostic objective as a numerical solver failure.

Count optional diagnostic evaluations separately and include them in documented totals. Counts that an engine cannot yet measure reliably are unavailable. Logging must not call a mutating model initializer or change screening state. For fixed iteration budgets and deterministic callbacks, reporting should leave iterates, RNG consumption and algorithmic work unchanged. With wall-time budgets, reporting overhead is included in elapsed time and can cause an earlier stop; this is expected and should be documented.

## Structured logging and export

With `emit_logs=true`, emit scalar fields at `Info` under `_group=:solver_progress`, including a schema version, solve/parent IDs, method, event, counters, metric values, and context. Use a stable logging statement ID per event kind, not a dynamically generated logging ID for every iteration. Per-solve IDs belong in structured data. This preserves Julia's filtering behavior.

An application can wrap the solve in `with_logger` using a `TeeLogger`, `FileLogger`, or JSON `FormatLogger`. Export the same named scalar fields that populate history; do not ask users to parse console rows or serialize mutable workspaces. Optional table/CSV adapters flatten heterogeneous method metrics into explicit columns with missing values and include metric timestamps and iteration units. Keep serialization dependencies outside core. Console display and structured logging are independent, so applications can choose either or both.

## Compatibility and implementation sequence

1. **Core protocol and CD.** Add the record, report/accessors, `TraceOptions`, no-op/table/history/log consumers, and `progress_callback`. Instrument all CD pass variants and screening/continuation entry points. Consolidate the overlapping keyword signatures for CD `solve!` so plain and continuation solves both accept reporting keywords. Carry context through direct `_cd!` calls, rather than observing only public `solve!`.
2. **PG and ADMM.** Route the new API through the shared protocol, add final rows and ADMM histories/callbacks. Preserve the existing PG `OptimizationTrace`, callback argument and `printEvery` behavior when using the legacy API. New `solver_trace` returns the common scalar history. Avoid maintaining two histories unless the caller explicitly requests both interfaces.
3. **Outer drivers and CoordinateDescent.** Add scopes, cancellation propagation, and reports for Newton, active-set PG, paths, LLA and reweighting. Thread explicit reporting keywords through `_solve!`, `_solveLevels!`, `_lassopath`, cold paths, group/sparse-group/GLM paths, feasible/scaled/robust lasso, varying-coefficient fits, and CV. Preserve the internal intercept callbacks and existing estimator return conventions.
4. **Other packages and export recipes.** Replace CovarianceSelection's ad hoc path output and automatic-IHT trace adaptation with shared reporting while keeping its legacy callback behavior. Add an adapter for FunctionalGraphicalModels' independent optimization loops when those loops adopt the common contract. Document file/JSON/CSV recipes and optional progress bars.

When new `trace` is supplied together with nondefault legacy PG tracing fields, reject the ambiguous combination with a migration message. The legacy `callback` may coexist with `progress_callback` because downstream wrappers still use it internally. Deprecate `printEvery` and the storage-dependent callback argument only in a separately announced breaking release. Keep old PG defaults and storage behavior on the legacy path; the new table's default interval and `stderr` destination apply to the new API.

### Acceptance checks for implementation

- Disabled/enabled reporting produces identical iterates and RNG state for fixed-work runs; extra diagnostics have accurately separated counts. Test callbacks alone, with storage, and with output, including callable structs.
- Every engine implements the contract or rejects unsupported requests at entry. ADMM must actually store history and honor cancellation. Test early convergence before a display interval, zero CD passes, empty paths, limits, failures, and simultaneous stop conditions.
- History entries remain valid after later iterations, workspace reuse, warm starts, and later solves. Scalar mode retains no arrays; explicit sparse snapshots avoid densification; bounded history preserves terminal information and reports truncation.
- Nested and screened runs emit accepted states with correct objective identities, gap evaluation iterations, counts, scope and parent IDs. Cancel inside CD within Newton within a path and verify that the root stops cleanly and returns aligned partial results.
- `IOBuffer` captures all table output. Exceptions propagate, Julia warning filtering remains independent, and scoped loggers are not replaced. Threaded CV keeps complete rows, correct fold IDs and safe cancellation without consuming the optimization RNG.
- Warm allocation/time checks cover disabled reporting, scalar storage, sampled display, and an intentionally expensive metric. Measure on CD, PG and ADMM; do not infer overhead from the tiny behavior probe.

## Owning source locations

- [ProximalOptions and legacy trace types](https://github.com/mlakolar/ProximalSolvers.jl/blob/34f26a8037cf4cb9f1b0ae277ebdc73101188623/src/types.jl#L59), [trace construction and callback dispatch](https://github.com/mlakolar/ProximalSolvers.jl/blob/34f26a8037cf4cb9f1b0ae277ebdc73101188623/src/utils.jl#L6), [PG solve loop](https://github.com/mlakolar/ProximalSolvers.jl/blob/34f26a8037cf4cb9f1b0ae277ebdc73101188623/src/solve.jl#L68).
- [ADMM option support](https://github.com/mlakolar/ProximalSolvers.jl/blob/34f26a8037cf4cb9f1b0ae277ebdc73101188623/src/solvers/admm.jl#L45), [ADMM printing and objective evaluation](https://github.com/mlakolar/ProximalSolvers.jl/blob/34f26a8037cf4cb9f1b0ae277ebdc73101188623/src/solvers/admm.jl#L228).
- [CD solver and results](https://github.com/mlakolar/ProximalSolvers.jl/blob/34f26a8037cf4cb9f1b0ae277ebdc73101188623/src/cd/solver.jl#L91), [pass dispatch](https://github.com/mlakolar/ProximalSolvers.jl/blob/34f26a8037cf4cb9f1b0ae277ebdc73101188623/src/cd/solver.jl#L310), [continuation entry](https://github.com/mlakolar/ProximalSolvers.jl/blob/34f26a8037cf4cb9f1b0ae277ebdc73101188623/src/cd/path.jl#L172).
- [CoordinateDescent options and keyword validation](https://github.com/mlakolar/CoordinateDescent.jl/blob/bc35789dbe42565134da60854274c3a73c7e9068/src/utils.jl#L48), [solver construction and execution](https://github.com/mlakolar/CoordinateDescent.jl/blob/bc35789dbe42565134da60854274c3a73c7e9068/src/utils.jl#L129), [path intercept callback](https://github.com/mlakolar/CoordinateDescent.jl/blob/bc35789dbe42565134da60854274c3a73c7e9068/src/lasso.jl#L963), [threaded folds](https://github.com/mlakolar/CoordinateDescent.jl/blob/bc35789dbe42565134da60854274c3a73c7e9068/src/cv.jl#L131).
