# Implementation notes for maintainers

This page preserves the detailed implementation contracts from before the beginner documentation rewrite. It is for contributors, not a prerequisite for solving a lasso. For the beginner-level description, see [Supported problems](../support.md) and [Numerical behavior](../numerics.md).

## Working precision and numerical boundaries

The supported solve contract is homogeneous `T = Float32` or
`T = Float64` for the design matrix, response and coefficient iterate.
The boundary checks in `src/solve.jl` enforce matching array element
types, finite data and the solver-specific storage restrictions.
`_scalar_parameter` validates a finite loss scale or penalty level
by conversion to `T` and refuses overflow or nonzero-to-zero
underflow. It does **not** globally convert the original function
parameters or ensure that all private arithmetic is of type `T`.
This accepted wider-scalar behavior is a narrow historical
compatibility exception, not a generic mixed-precision guarantee.

ProximalBase separately defines the mathematical oracle precision
and exceptional-range behavior. Its selective recovery may avoid
intermediate overflow/underflow for representable values, but the
solver adds independent matrix products, state updates, stopping
and numerical-finiteness checks. Do not infer end-to-end recovery
from a successful ProximalBase oracle or promise a finite result for
every finite input.

The solver retains native `Float32`/`Float64` iterates and their
working accuracy. Some option tolerances and reported scalar
residuals are stored as `Float64`. They are diagnostic storage,
not a promotion of solver iterates or an optimality certificate.
`converged=true` retains its algorithm-specific historical meaning;
use independent objective/KKT checks for accuracy, especially with
`Float32`. BigFloat may be used for independent test references,
not as a supported solver working type.

This is a documentation alignment with the homogeneous numerical
policy tracked in
[ProximalBase PR #857](https://github.com/mlakolar/ProximalBase.jl/pull/857).
No solver arithmetic, precision conversion, stopping, failure
atomicity or scalar-acceptance behavior is changed.

## support.md (previous detailed notes)


Vector y and Matrix X with the same Float32 or Float64 element type are
supported, with positive consistent dimensions and finite entries. The iterate
is a dense Vector of that type for every solver, and additionally a
one-dimensional `SparseIterate` of that type for [`CDSolver`](@ref) only;
[`ProximalGradientDescent`](@ref) and [`AccProxGradDescent`](@ref) refuse every
`SparseIterate`. Use raw PB LS or
one positive finite scalar Scaled LS, and unweighted finite nonnegative NormL1.
Parameters must be representable; positive values must not round to zero.
Scaling is explicit: raw LS means sum(abs2,y-X*x)/2; divide by n explicitly for
normalized lasso. Accepted wider scalars retain historical conversion sites.

X/y are borrowed read-only during solves and must not alias mutable x; for a
`SparseIterate` the check uses the owner's whole backing storage, so even an
owner with no active entries is refused when `parent(activevalues(x))` or a
reshape of it is passed as y or X. Results share x; extended traces copy
x/gradient. Unsupported requests fail before mutation. A CD numerical exception
preserves input x; PGD and APG numerical step exceptions restore their last
accepted point and rethrow. Counters/buffers are not generally transactional. Shape errors are
DimensionMismatch; unsupported combinations/options are informative
ArgumentError.

## CD on a `SparseIterate`

- Only the public active values are checked for finiteness. Every validation
  failure (unsupported owner, element type, shape, active NaN/Inf, data, loss,
  penalty, scalar, option, keyword or alias) happens before the owner is copied
  and before any RNG draw, and leaves the owner untouched.
- The run uses `work = copy(x)`, which keeps the active zeros and the slot order,
  and nothing is rebuilt through a dense vector. Passes, momentum and stopping
  are those of the dense wrapper; the extra storage is O(p).
- A run that completes with a finite objective commits the complete final state
  with a same-shape `copyto!(x, work)` and returns `x` itself as `minimizer`.
  This covers a finite `maxpasses` limit (`converged = false`, with a warning)
  and `maxpasses = 0`, which leaves exactly the entry state, including active
  zeros, signed zeros and order. A normal pass compacts zero coordinates, and
  they are not restored; the order is not sorted.
- A numerical error, such as a nonfinite step, a curvature that underflows or a
  nonfinite final objective, leaves the values, active set, signed zeros and
  order of `x` unchanged. The borrowed RNG may already have advanced; no rollback
  of the RNG is promised. Process termination, out-of-memory conditions and
  concurrent mutation of x, X or y are not covered.
- After a successful call take `activevalues(x)` and `activecoordinates(x)` again:
  the active list may have been replaced or reordered.

## Deferred

Sparse designs, sparse vectors and views as iterates, `SparseIterate` for proximal
gradient descent (plain or accelerated), matrix-shaped, group and symmetric owners, weighted/group
penalties, matrix responses, intercepts/offsets, generalized losses/compositions,
monotone/active-set acceleration and APG diagonal preconditioning, ADMM/Newton,
primal-dual/SLOPE/graphical models, paths/screening/certificates/workspaces/refit
and reweighting are deferred. Nondefault feature requests are refused. gap=NaN
and CD kkt_checks=0 are compatibility sentinels, not computed diagnostics.

This is a breaking support reduction. Version/registration and any public
release remain a separate decision; existing releases are untouched. Protected
archive refs preserve the complete snapshot; legacy/full remains the historical
working branch. Restore capabilities selectively; do not merge it wholesale.


---

## numerics.md (previous detailed notes)


CD runs on a PB SparseIterate that retains stored activation/compaction order: a
private one for a dense vector, and a private copy of the caller's owner for a
`SparseIterate`, which starts with that owner's active zeros and slot order and
which the caller's owner receives, whole, only after a finite completed run. First
full passes admit coordinates, active passes refine them, and only a full pass
strictly below the change tolerance converges. Random LS uses historical
momentum/restarts and refreshes moved residual caches before full checks; the
borrowed RNG advances. Cyclic and explicit momentum=false remain supported.
Zero columns choose the nearest-zero penalty minimizer, including lambda=0.
Nonzero-column curvature underflow is an error. tol=0 stays strict; maxpasses=0
returns unconverged with no updates, and an owner then keeps its exact entry state.
After every pass zero coordinates leave the active set, so an owner that completed
at least one pass has none and their order follows from compaction, which moves the
last active coordinate into the place of a removed one. A nonfinite returned
objective is refused before dense scatter or owner commit; this is not robust
dynamic-range recovery. A nonconverged finite pass-limit return warns, then commits.
A numerical error leaves a caller's owner unchanged but may advance the RNG.
Dense and owner solves from the same canonical state (the owner built from the
dense vector) run the same arithmetic and RNG schedule. A different slot order of
the same active set can change the trajectory and the final point, and the change
stopping rule gives no general bound on the distance to a minimizer or on the KKT
violation: assess accuracy with an independent objective/KKT check.

PGD retains native LS image/value/gradient order, scalar steps, fused PB prox,
TFOCS objective-to-gradient checks, finite curvature-growth refusal and zero-step
gradient refresh. Historical objective/iterate/FASTA convergence tests combine
by OR. Converged does not guarantee KKT below gradtol; objective rounding can
stop even with very small ftol; `ftol = 0` disables the objective test. Check
objective/KKT independently. Native
Float32 may stagnate earlier. Finite inputs do not ensure finite intermediates;
historical LS image exceptional-range limitations remain outside this extraction.

APG (`AccProxGradDescent`) is the historical accelerated method narrowed to the
dense LS core: extrapolation `y = x + k/(k+3)(x - x_previous)`, `L ← αL` before each
iteration, backtracking `L ← L/β` until the LS bound test accepts the trial (see
"The APG bound test" below), and one restart from `y = x_previous` when an extrapolated step raises the computed
objective. `X y` is formed from `X x` and `X x_previous` without a product; a restart
copies `X x_previous`. Departures from `legacy/full`: no metric, tuple, owner or
generic smooth-loss path; β and α are validated and used in `T` (`T(β) < 1` and
`T(α) > 0` after rounding); the objective-scale bound that only guarded a nonfinite
value is dropped, so a nonfinite trial raises `L` through `next_curvature` (which
raises once `L/β` is not a finite increase) instead of failing at once; a trial is
accepted only when the bound is certified by rounding-error bounds ("The APG bound
test" below), where legacy compared rounded squares of cached-image differences with
an 8eps image allowance; a step with `x == y` entrywise is accepted with a
finite value, where legacy raised; a
nonfinite gradient at `y` is treated like a nonfinite value (restart, or failure
without momentum). Each step writes `x_previous ← x` after forming `y` and before the
first trial, so the shared engine's rollback restores the last accepted iterate.
`backtrack_steps` counts every trial, including the accepted one, so it equals
`prox_calls`; `grad_calls` is the number of steps plus restarts and
`f_calls = 1 + grad_calls + prox_calls`. Its gradient residual `L‖x - y‖∞` is a
stopping quantity measured from `y`; it is not an independent KKT residual at `x`.

### The APG bound test

For least squares, `f(x) ≤ f(y) + ⟨∇f(y), d⟩ + L‖d‖²/2` (`d = x - y`) holds iff
`√α ‖X d‖ ≤ √L ‖d‖`. The target is that inequality relaxed by legacy's slack, `√α ‖X d‖
≤ (1 + 4eps) √L ‖d‖`, for the stored `x` and `y`, with `α` the loss scale as given. A
trial with `d ≠ 0` is accepted only when `_bound_certified!` (`src/solvers/image_models.jl`)
certifies the target; every other trial is rejected, so `L` grows.

*Assumptions.* IEEE arithmetic in `T` with gradual underflow, modelled as
`fl(a ∘ b) = (a ∘ b)(1 + δ) + η'` with `|δ| ≤ u = eps(T)/2` and `|η'| ≤ η/2`,
`η = nextfloat(zero(T))` (subnormal additions are exact); and a matrix-vector product that
evaluates each entry as a dot product of `p` multiplications and additions (or fused
multiply-adds) in some order. Then `|fl(X v) - X v| ≤ γ_p |X||v| + 2p η` componentwise,
`γₖ = k u/(1 - k u)`, so `‖fl(X v) - X v‖ ≤ γ_p ‖X‖_F ‖v‖ + 2p √n η`. `k u < 1/8` is required
for `k = max(n, p) + 4` in `T` and `k = n p + 3` in Float64 (`_check_bound_size`, before
mutation; for Float32 this refuses `max(n, p) ≥ 2,097,148`).

*Error bounds.* The cached `z_x` of a trial is a fresh product (bound above with `v = x`).
The cached `z_y` is a copy of a fresh product of `x_a` (first step, restart), or the
extrapolation `fl(z_a + ω(z_a - z_b))` of fresh products of `x_a` and `x_b` with
`y = fl(x_a + ω(x_a - x_b))` and computed `0 < ω ≤ 1`; three roundings per combination (one
an underflowing product) give `E_y = (2γ_p + 16u)‖X‖_F(‖x_a‖ + ‖x_b‖) + 8p√n η + 2√p ‖X‖_F η`,
covering both images, the image error of the rounded `y` and both combinations. `‖X‖_F`
enters as a proved upper bound (`_frobenius_upper`: squares summed in Float64, exactly
representable for Float32 data, in one pass when that is accurate and otherwise after an
exact scaling by the power of two `2^-e` of the maximum (`ldexp`), with `γ_{np+3}` and
underflow terms, rounding up the square root and the conversion), and each computed iterate norm is divided by `1 - γ_{p+4}`. The computed norms
of `Δz = z_x - z_y` and `d̂ = fl(x - y)` are within `γ_{n+4}` and `γ_{p+4}` of the norms of the
stored vectors (a one-pass sum is used only when finite and at least `4n floatmin(T)`; the
scaled two-pass form otherwise), and `‖d̂ - d‖ ≤ u ‖d‖`.

*Decision.* Cheap path: accept when `√α` times the upper bound `‖Δz‖/((1 - γ_{n+4})(1 - u)) + E_x + E_y`
is at most `(1 + 4eps)/(1 + κ) √L ‖d̂‖/((1 + γ_{p+4})(1 + u))`; reject when `√α` times the lower
bound `‖Δz‖/((1 + γ_{n+4})(1 + u)) - E_x - E_y` exceeds `(1 + 4eps)(1 + κ) √L ‖d̂‖/((1 - γ_{p+4})(1 - u))`.
Otherwise form `w = fl(X d̂)` in the residual buffer, with
`‖w - X d‖ ≤ (γ_p + 2u)‖X‖_F ‖d̂‖/((1 - γ_{p+4})(1 - u)) + 2p√n η`, accept when its upper bound passes,
and reject otherwise. `√α` (`_root_scale`) is formed from `α`'s significand and exponent:
exact in its own type for an IEEE Float16/32/64 scale, and otherwise taken after rounding
`α` once to 256 bits inside a scoped BigFloat precision (restored afterwards); the
significand is rounded once to Float64 before its root. So neither a type narrower than `T`,
the active BigFloat precision, nor `α`'s range limits it.
`κ = 32u` covers the roundings of `√L`, of `√α`'s conversion to `T`
and of the fixed number of `_SE` products and sums on each side; the dimension-dependent
errors enter through the factors above. These are conservative bounds: in Float32 the
cheap path is often inconclusive late in a solve and the fresh product decides, and for
data deep in the subnormal range, where the underflow terms can dominate the bounds, a
nonzero step may be rejected until `L` is far above the curvature, or the solve may fail
with rollback.

*Range.* The norms and the bound arithmetic are carried as a significand in `[1, 2)` of
type `T` and an integer binary exponent (`_SE`), so no partial product or sum of the bound,
no ratio of scale factors, and no subnormal norm is rounded to a scalar of `T`. The native
products, the extrapolation and the one-pass sums are evaluated in `T` and enter only
through the bounds above. Under the assumptions, a curvature above `floatmax(T)` is never
certified, so backtracking ends in `next_curvature`'s error and the engine's rollback.

*Edge cases.* `d̂ = 0` entrywise: accepted with a finite value (a stopping policy). A trial
with a nonfinite value or iterate norm is rejected before the test. A nonfinite `Δz` gives no
cheap decision; the fresh product decides. `L = 0` is rejected. Legacy's 8eps image allowance
and zero-`Δz` shortcut are not used.

*Validation.* These checks are samples, not a proof. `test/accelerated_pgd.jl` checks
against BigFloat references computed from `X`, `x` and `y` (the exact `X d`) that no accepted
trial violates the target, over random data with exponent spans of ±40 (Float32) and ±300
(Float64), subnormal-range data, large common offsets, extrapolated images with `ω` up to 1,
loss scales wider and narrower than `T`; that a global curvature bound `4α‖X‖_F²` is accepted
for normal-range data; that the fresh-product-only decision (an internal switch) is safe as
well; the underflow, narrower-scale and long-reduction cases found in review; and that
`_frobenius_upper` bounds `‖X‖_F`. On the 576 ordinary solves of the PR record 4.7% of trials
needed the fresh product; every solve is bit-identical to the fresh-product-only decision,
571 are bit-identical to `legacy/full`, and the 5 that differ (Float32) change the objective
by at most 2e-7 relative.

Callbacks/display sample `print_every`; stored traces include each iteration. A
callback receives the trace when storing, otherwise a state. Limits are checked
after an iteration and counts may overshoot. iteration_converged means a limit,
not success. `ProximalOptions` refuses positive gaptol at construction and does
not store gaptol or gapevery. Solvers, options and `BackTracking` each have one
validating inner constructor (settings are checked as given and after conversion),
so `solve!` does not re-check them; APG still checks β and α in the precision of
the iterate before any state is created.
The retained scalar APIs/results do not introduce a new stopping/logging engine.


---

## internals.md (previous detailed notes)


The thirteen active files are module/types/blocks/line_searches/solve/utils/precompile,
solvers/image_models, proximal_gradient_descent and accelerated_proximal_gradient_descent,
and cd/models/solver/leastsquares. Small native helpers support the separately cached
algorithms and existing result types; PGD and APG share the LS image model, the
gradient engine `_solve_gradient!`, the stopping rules and the result type. CDModel and state hooks are private extraction/test seams, not
promises of custom loss or workspace support. Generic block/metric/certificate/
logging frameworks are deferred.

The dense and `SparseIterate` entry points of CD share one private run on a
PB SparseIterate (model, state, passes, warning and finite-objective check). The
dense wrapper builds that iterate from the vector and scatters the result back.
The owner wrapper copies the caller's owner with `copy`, runs on the copy and
commits with a same-shape `copyto!` through PB's public storage methods only,
after the finite-objective check; it does not rebuild through a dense vector.
Each copy preserves the state of its source: the initial copy keeps the entry
state (active zeros and slot order), and the commit writes the final state of the
working copy, after any compaction, which removes zeros and can reorder slots
during the passes. Validation is split into data
checks shared by both gates and an owner gate that inspects only public active
values and tests aliasing against the original owner. PGD keeps the dense gate and
refuses owners.

The current exact PB pin is `c123d56ba1948e36a8fdbf183a9eea396a16e0d5`. CD uses
its scalar `prox_block` oracle; PGD retains fused `value_and_prox!`. The private PB
SparseIterate contract remains unchanged. PR #237's group/workspace migration is
not imported. The gated analysis job always runs isolated exact-source paired
diagnostics against PB A e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291 and frozen
PS 64930401cfc0451e886728d916263c4dab2baf36 (CD and PGD only), including when package tests are
not selected or reused. Loaded paths, clean Git HEADs and source digests are
checked; version strings never skip probes. C0 and the provenance audit describe
the independent full-suite mathematical/behavioral tests.

Current CI is stable Julia1 Linux x64 only for every tier. Preserve required
checks, full master validation, coverage, benchmark-analysis and conservative
policy-aware nightly reuse. Historical platform runs and the deferred macOS C0
warm-convergence failure remain historical, not newly passing claims.

Historical measured performance tables remain in the repository's
[full-package performance record](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/docs/audit/historical-full-performance.md).
They are not replaced by unmeasured minimal-core claims.
