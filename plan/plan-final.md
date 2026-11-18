## Research plan (pre-registration)

Drafted by the orchestrator. Critiqued by Claude Opus (high), revised. Research only: no implementation PR, no change of a default, no pin change; the review point is the report that will follow on this issue. Audited revision: master `8cc022222d3c90ef86a24ca0c957b02faaf4fc1f`, ProximalBase pin `a19c59aa723d085d5d7cf5242895bda16eb77214`, Julia 1.13.4 and 1.10.13. Long runs on a cluster (Slurm), on CPUs with and without AVX-512. Scripts, raw tables and prototypes will be archived on an evidence branch.

### What the code does

- `_cd_plain!` and `_cd_momentum!` (`src/cd/solver.jl`) stop at a full pass whose largest scaled change is below `tol √s ‖y‖`; `_stop_check!` (`src/cd/models.jl`) returns `:converged` for `LSModel` and `BlockLSModel`. The loop has a second outcome, `:uncertified` (stop with `converged = false` and a warning), used by the square-root lasso.
- A scalar visit (`coordinate_step!`, `src/cd/leastsquares.jl`) forms `b = rᵀX_k` from the cached residual, `c = old + b/a`, `new = prox(c)` and `h = new − old`; a zero `h` returns before any write. The plain loop does not recompute the residual after the start; the momentum loop recomputes it before a full pass when momentum moved the cache.

### Mechanisms to test

Let `u_k` be the step of a visit without the rounding of `old + b/a`, from the visit's own `old`, `b`, `a` (for a nonzero coefficient that keeps its sign, `u = (b/a − τ sign(old) − ρ old)/(1 + ρ)`, `τ = λ1/(s a)`, `ρ = λ2/(s a)`).

- **H1, absorbed step.** `h` differs from `u` by rounding of the order of `eps(T) max(|x_k|, τ_k)`. A visit with a nonzero `h` is controlled by the change test up to a constant (about 2.5 for the lasso away from 0; not when the step lands on 0 with `τ_k ≫ |x_k|`). A visit with `h = 0` at a nonzero coefficient is not: `√(s a_k)|u_k|` can reach `eps(T) √s ‖X_k x_k‖`, whatever the threshold. The reproducer of this issue is such a visit.
- **H2, stale residual at an empty pass.** The cached residual carries the rounding of its initialization, about `eps(T) Σ_k ‖X_k x0_k‖` at the start `x0`, and of every update since. With the reproducer at `λ = 0`, `b = 0` and `u = 0`: the visit's own statistic is blind.
- **H3, stale residual with ordinary convergence.** The same error stays in the cache after the iterate has come back to an ordinary scale. The passes then converge with ordinary nonzero changes to the minimizer of the problem with a perturbed response; the stopping pass is neither empty nor rounding-dominated, and statistics formed from the cached residual do not see it.

### Truth (BigFloat, on the rounded inputs, as in #352)

Exact KKT residual over `max(λ1, λmax)`; bounds on the relative suboptimality against a reference (within the target if the upper bound is at most `1e-8` in Float64 or `1e-5` in Float32; above if the lower bound exceeds it and the minimum exceeds `1e-20 F(0)`; otherwise undecided); `E(x)`, the largest change an exact first visit would make at `x` (for groups, the exact displacement of the majorization step), in the units of the change test; the distance of the cached residual from `y − Xx`. In exact arithmetic a converged pass gives `E ≤ (p − 1)` thresholds (F8 of #352), so `E` above `p` thresholds marks a stop that the change test passed through rounding.

### Sweep (Task 1)

The unmodified package is run through a wrapper model that forwards every call and records each visit (`old`, the visit's `b`, curvature, `h`), the path length and the residual refreshes; every wrapped solve is compared bit for bit with `solve!` (minimizer, passes, flag, last change, RNG state).

- Designs: the ten fixtures of #352 with `y ≠ 0`; generated designs `(40, 12)`, `(100, 30)`, `(50, 200)` at equicorrelation `0`, `0.5`, `0.95`, `0.999` (3 seeds); `(5000, 20)` and `(2000, 50)`; one with column norms over six decades. Raw loss and `1/n` scale.
- Penalties: lasso at `0`, `1e-3`, `0.1`, `0.5` of `λmax`; the elastic net of #352; elastic nets with `λ2/(s a) = 0.01, 1, 100` at the median curvature; a ridge; group lasso (two layouts) at four levels.
- Starts: `xref + 2^j z`, with `z` a null vector, the smallest singular direction, the difference of the two most correlated columns, one coordinate, a dense direction, scaled so that `2^j` is the start's contribution over `‖y‖`; `j` up to 60 (Float64) and 28 (Float32). Ordinary starts: cold, the reference, the reference perturbed, the unpenalized solution, the solution at the next larger level.
- Configurations: dense and `SparseIterate`; cyclic and random order; momentum on and off; `tol` at the default, `1e-4`, and for ordinary starts down to `1e-16` (Float64) and `1e-6` (Float32); `relative = false` on one configuration.

### Diagnostics (Task 2), evaluated offline on every recorded stop, in the working type

| id | statistic | extra work per solve |
|---|---|---|
| A | absorbed steps: `√(s a_k)|u_k|` over the visits of the stopping pass with `h = 0` at a nonzero coefficient | `O(1)` per such visit |
| A0 | the same over all visits of the stopping pass | `O(1)` per visit |
| B | A recomputed after the pass from the cached residual | one product per nonzero coefficient |
| C | the same from a fresh residual, all coordinates; the final-point statistic of #352; the working-precision KKT residual over `max(λ1, λmax)` (the form of the stationarity check of PGD and APG) | a residual and `p` products |
| R | `√s ‖r_cached − r_fresh‖`, fresh residual in `T` (two orders of summation) and in Float64 for Float32 data | a residual |
| P | a priori resolution `eps(T) √s Σ_k ‖X_k‖|x_k|` at the stop, at the start, and with the path length added | `O(nnz)`, or one addition per visit |
| F | refresh the residual at the stop and require one more full pass below the threshold, alone and with A on that pass | a residual and a full pass |

Each with a floor `c eps(T)` for `c` from 0 to 1024, in the unit `√s ‖y‖` and in the per-coordinate unit `max(√s ‖y‖, λ1/√(s a_k))`, at every converged full pass and at empty ones only. Reported per rule as a trade-off curve: stops refused among those above the target, split by mechanism; stops refused among those within the target and among the undecided, by precision and `tol`; extra products; what the result reports on refusal.

### Ordinary path (Task 3)

Prototypes of the rules that survive Task 2 (patches, not for merge). Paired in-process timing: master, a second copy of master and the prototype compiled from source in one process, alternating order; solves of a few microseconds, warm restarts at the solution (one pass and the check), the CD benchmark shapes, dense and `SparseIterate`, both precisions, both Julia versions; warmed allocations. A cell with a median ratio above 1.05 and a control within 1.02 is repeated in a separate run, and escalated if it repeats. The prototypes' outcomes on the sweep's inputs are compared with the offline counts.

### Reading of the results, fixed before the data

- Must keep: every converged stop on an ordinary start that is within the target or undecided, both precisions, at the default `tol` and at `1e-4`, with a positive penalty; thresholds below `eps(T)` are reported separately. The counts are reported for every rule; a rule is a candidate only with zero must-keep refusals on the #352 fixtures (calibration) and on the generated designs (validation), on both Julia versions and both CPU kinds, with a factor 4 to spare in the floor.
- Must refuse: the reproducer of this issue in both precisions and its `λ = 0` variant.
- Efficacy: the share refused among converged stops above the target with `E` above `p` thresholds, by mechanism, and the smallest `j` at which such a stop escapes the rule. A rule that refuses the reproducer and little else is reported as such.
- Scope: `relative = false` and `y = 0` are characterized; the recommendation says whether its contract covers them. Underflow and cancellation of the products (F1, F3 of #352) stay out of scope.
- If no rule is a candidate, the recommendation is documentation only, with the measured trade-off. A floor constant, if recommended, is a new constant that needs approval.

### What the critique changed

- H1's rounding scale now includes the threshold `τ_k`, and the constant 2 is withdrawn (the critic's examples give 2.4 without a sign change and an unbounded ratio when a step lands on 0 with `τ_k ≫ |x_k|`); the per-coordinate floor unit follows from it.
- H3 is new: a stale residual with ordinary nonzero changes, which matches the #352 rows whose stopping passes were not empty.
- Added statistics: the path-length form of P, the refresh-and-confirm rule F, and the #296 form of C.
- Added designs and settings: large `n`, column norms over six decades, elastic nets by `λ2/(s a)`, a ridge, thresholds below `eps(T)`, a second CPU kind.
- The reading can no longer be met by refusing the reproducer alone: the `λ = 0` variant, an efficacy measure, Float64 and undecided stops in the must-keep set, and a calibration/validation split were added.
- Not adopted: recording whether the stopping pass was a forced full pass (the wrapper does not see pass boundaries; the diagnostics do not depend on it); a compensated-arithmetic residual for Float64 (out of scope as a recovery layer; the exact distance is reported as the limit of what a recomputation could see).
