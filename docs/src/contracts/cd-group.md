# Group coordinate descent

This is block coordinate descent for a vector-response least-squares loss and a
ProximalBase `BlockIterate`. [CDM-01](@ref) covers matrix responses. Read the shared
[input](@ref IN-01), [precision](@ref FP-01), and [result](@ref RES-01) clauses alongside it.

## [CDG-01 Problem, layouts and input refusals](@id CDG-01)

**Statement.**

The objective is `(s/2) * sum(abs2, y - X*beta) + lambda * sum(w[k] * norm(beta[G_k]))`.
`GroupNormL2(lambda, groups)` uses `w[k] = sqrt(length(G_k))`; explicit weights are allowed.
The iterate is a `BlockIterate{T}` and the finite dense design/response arrays have the
common element type `T`, either `Float32` or `Float64`. The loss and its scale satisfy
[IN-01](@ref).

The explicit-weight constructor is `GroupNormL2(lambda, groups, w)`.
The penalty has element type `Float32` or `Float64`; a Float64 penalty on Float32 data
is accepted. Its level and each weight must be finite, nonnegative and representable
in `T` without overflow or rounding a nonzero value to zero. The groups of the penalty
and iterate must agree in number, order and ordered members, otherwise the error is
`DimensionMismatch`. A `BlockIterate` is a nonempty partition of `1:p`, so there are no
coordinates outside its groups; `BlockIterate(T, p, g)` builds the matching layout.
Construct that iterate as `x = BlockIterate(T, p, g)` and call
`solve!(x, f, g, CDSolver(order=:cyclic, tol=1e-10))` for the baseline's cyclic
example, with the supported solver settings below.

`momentum = true` is refused with `ArgumentError`; `nothing` and `false` both mean
plain block coordinate descent. Input refusals for receiver, momentum, penalty,
weights, layout, aliasing with `X` or `y`, and nonfinite values happen before copying
`x` and before using the RNG. They also apply when `maxpasses = 0`. Level and weight
messages contain `penalty lambda` and `group weight`, respectively.

**Applies to.** Vector-response `CDSolver` with `BlockIterate` and `GroupNormL2`.

**Code.** `src/solve.jl`: group validation and wrapper; `src/cd/leastsquares.jl`: `BlockLSModel`.

**Tests.** `test/group_cd_preflight.jl`: receiver, level/weights, layout, aliasing and keyword tests.

**Sources.** `docs/src/numerics.md:L441`, `docs/src/numerics.md:L443`, `docs/src/numerics.md:L619`, `docs/src/support.md:L174`, `docs/src/support.md:L176`, `docs/src/support.md:L180`, `docs/src/support.md:L184`, `docs/src/support.md:L186`, `docs/src/support.md:L190`, `docs/src/support.md:L195`, `docs/src/support.md:L198`, `docstring:src/cd/solver.jl:L84`, `docstring:src/solvers/proximal_gradient_descent.jl:L367`.

## [CDG-02 Group update](@id CDG-02)

**Statement.**

For a group `k` that is not flat (see below), with entries `G` and the current residual
`r`, the solver uses a number `ℓ_k > 0`, computed as described below, that is meant to
bound the largest eigenvalue of `X[:, G]' * X[:, G]` from above.
A visit forms the trial point `u = x[G] + X[:, G]' * r / ℓ_k` in `T`, replaces the block
by the proximal point of the penalty at `u` with the step `1 / (s ℓ_k)`, `s` the loss
scale, and updates the residual for each entry of the block that changed. The change of
the visit is the 2-norm `‖Δ_G‖₂` of the displacement of the block. A flat group has
`ℓ_k = 0` and takes the proximal point at the step `Inf` instead, without a trial point
(see below). A group whose block does not change is not written, which keeps an inactive
group inactive. A trial point or displacement that is not finite stops the solve with an
`ArgumentError` that names the group, and the iterate of the caller is unchanged; a change
or stopping scale that is not finite is refused as for the lasso.

**Applies to.** A visit of a vector-response block-CD group.

**Code.** `src/cd/leastsquares.jl`: `coordinate_step!(::BlockLSModel, ...)`.

**Tests.** `test/group_cd.jl`: "residual after initialization and single steps", "an inactive group with a zero step stays inactive", "coordinate_step! returns the norm of the group change".

**Sources.** `docs/src/numerics.md:L450`, `docs/src/numerics.md:L452`, `docstring:src/cd/solver.jl:L84`.

## [CDG-03 Zero-group screen](@id CDG-03)

**Statement.**

**The zero-group screen.** When the block of a nonflat group is identically zero (whether
or not the group is active), the visit first forms the correlations `b = X[:, G]' * r` and,
if the two guards below allow, passes them to ProximalBase's `prox_block!` for the group
with the step `1 / s`. If the result is entirely zero, the visit ends with no change:
nothing is written to the iterate or the residual, and a deferred `ℓ_k` is not computed. A
zero block that the screen returns as zero forms no trial point, so it is not refused where
the trial point `b / ℓ_k` of the full step would overflow. In exact arithmetic, the full
step gives a zero block, for any `ℓ_k > 0`, exactly when the norm of `b` is at most
`λ w_k / s`, and the screen tests the same inequality. The guarantee is one-sided: where
the screen returns zero, the positive excess of the norm of `b` over the threshold
`λ w_k / s` is confined to a rounding band around the equality (a screened zero can also be
far inside the zero ball, for example `b = 0`). A nonzero screen result does not imply a
nonzero full step: `b / ℓ_k` can underflow, so the full step can return zero where the
screen does not. Two guards restrict the screen to cases where an entirely zero result is
meant to come from the threshold test, up to such a rounding band:

- the reciprocal `1 / s` formed in the type `S` of the scale must be a finite positive normal
  number of `S`; it is `Inf`, 0 or subnormal otherwise;
- either every correlation `b_i` is zero, or the largest `|b_i|` of the group is at least a
  floor, `2^53 floatmin(T)`, which is far above the underflow range of `T`. Otherwise
  ProximalBase's shrinkage of a very small correlation could round every entry of the result
  to zero although the norm of `b` exceeds the threshold, and a zero result would not certify
  the zero block.

Outside the guards, the screen is bypassed and the visit takes the full step, with the
curvature computed if it is still deferred.

**Applies to.** Nonflat groups whose current block is identically zero, active or inactive.

**Code.** `src/cd/leastsquares.jl`: `_screen_floor`, `coordinate_step!`.

**Tests.** `test/group_cd.jl`: screening, underflow, activation and bypass cases.

**Sources.** `docs/src/choosing-solver.md:L263`, `docs/src/numerics.md:L465`, `docs/src/numerics.md:L481`, `docs/src/numerics.md:L483`, `docs/src/numerics.md:L489`, `docstring:src/cd/solver.jl:L84`, `docs/src/internals.md:L23`.

## [CDG-04 Curvature preparation and bounds](@id CDG-04)

**Statement.**

`ℓ_k` is a bound on the stored values of `X` in `T`, formed as follows. The preparation
runs after the residual is set, before the first pass and any draw from the random number
generator, and only when `maxpasses > 0`; with `maxpasses = 0` it is skipped and the
preparation refusals below do not occur (the refusals of the inputs, the response scale
and the final objective still apply). The preparation computes and checks `ℓ_k` for a flat
group, for an ordinary one-column group and for a group that is not deferred; for a
deferred group it checks only the bounds below, and `ℓ_k` stays `NaN` until the first visit
that needs it.

- **Flat group.** If every entry of `X[:, G]` is exactly 0, `ℓ_k = 0`, set during the
  preparation. The visit takes the minimizer of the penalty alone: a zero block when the
  level and the weight are positive, and the block unchanged when one of them is 0. Its
  stopping scale is 0.
- **Group of one column**, with `n` the number of rows and `n eps(T) ≤ 1/8`. `ℓ_k` is
  computed during the preparation as the next floating-point number above
  `a (1 + 2 n eps(T))`, where `a` is the sum of squares of the column accumulated in `T`.
  The factor is a margin for the rounding of `a`, so `ℓ_k` is larger than the squared norm
  by a relative amount of about `2 n eps(T)`; the scalar lasso step uses `a` itself. The
  two sums are accumulated differently, so they can differ by rounding even before the
  margin.
- **Any other group**, and a group of one column with `n eps(T) > 1/8` (the *Gram route*).
  The Gram matrix `Ĝ` of the columns is formed in `Float64` from a copy of the columns
  (for `Float32` data too). With `t` the trace of `Ĝ`, `m` the size of the group and `d`
  the largest diagonal entry, the bound in `Float64` is the next number above
  `max(μ, d) + 4 (n + m²) eps(Float64) t`, rounded up to `T`, where `μ` is the largest
  eigenvalue of `Ĝ`: all eigenvalues of `Ĝ` are computed and the largest is taken, for a
  group of `m ≥ 2` columns. For a group of one column on this route, `μ` is the diagonal
  entry `Ĝ[1, 1]`, with no eigenvalue computation and no eigenvalue model. The error terms
  that the margin covers are the rounding of `Ĝ`, products that underflow, and, for
  `m ≥ 2`, the eigenvalue computation. The first two follow from standard bounds and
  assume IEEE gradual underflow (subnormal numbers are not flushed to zero); the third
  assumes that the computed eigenvalues are exact eigenvalues of a nearby matrix, within a
  multiple of `eps(Float64)` times the trace, a model of the eigenvalue routine and not a
  proved bound for every input. This is the *general rule*; a group of two columns takes it
  outside the range of the next item.
- **Group of two columns** (on the Gram route). With `x` and `y` the two columns, the
  entries `a = ‖x‖²`, `b = ‖y‖²` and `c = xᵀy` of the Gram matrix are accumulated in
  `Float64` in one pass over the stored columns, without a copy, and `t = a + b` is their
  computed trace. Where `2^-480 ≤ t ≤ 2^500`, the bound in `Float64` is the next number above
  `(t + √((a − b)² + 4c²))/2 + (n + 4) eps(Float64) t`, evaluated in `Float64` and rounded
  up to `T`, with no eigenvalue computation. The first term is the largest eigenvalue of
  the computed Gram matrix in exact arithmetic. Inside this range the bound is proved, with
  no eigenvalue model: assuming IEEE binary64 arithmetic with rounding to nearest and
  gradual underflow, and `n eps(Float64) ≤ 1/8`, it exceeds the largest eigenvalue of the
  exact Gram matrix of the stored columns by at least `((6/7) n + 3) u t`, with
  `u = eps(Float64)/2`, for any order of the summation. The margin is a quarter of that of
  the general rule. Under the same condition on `n`, finite `Float32` data in a group that
  is not flat is inside this range. `Float64` data is outside it where `√t`, the Frobenius
  norm of the two columns up to rounding, is below `2^-240` or above `2^250`, and data with
  a `NaN` or infinite entry is outside it (`t` is then `NaN` or infinite). Outside the range
  the general rule decides, with its refusals.

The two rules for a group of two columns compute slightly different bounds: the margins
differ, and the computed eigenvalue differs from the closed form in the last bits. The
refusal categories and messages are those of the table below, but where the two bounds,
or the steps `s ℓ_k` formed from them and their reciprocals, fall on different sides of a
refusal threshold, the decision can differ from the one that the general rule would make.
For the bound in `Float64` before its rounding up to `T`, the thresholds are
`prevfloat(floatmin(T))` and `floatmax(T)`: a bound at or below `prevfloat(floatmin(T))` is
refused as underflow, a bound strictly above it rounds up to at least `floatmin(T)`, and a
bound above `floatmax(T)` is refused as overflow. For `s ℓ_k` and its reciprocal the
threshold is the smallest normal number of `S` (see below).
Then a bound that the general rule refuses as overflow can be accepted (and then be
refused by the step check, with the step message), a bound that it accepts can be refused
as underflow, and a step decision can change in either direction. The gap between the two
bounds scales with `t`, not with `ℓ_k`, so no fixed relative distance from a threshold is
claimed.

**Applies to.** Vector-response block CD; the arithmetic/model assumptions stated for each bound.

**Code.** `src/cd/leastsquares.jl`: `_prepare!`, `_singleton_curvature`, `_gram_curvature`, `_gram2_curvature`.

**Tests.** `test/group_cd.jl`: "curvature majorization", "closed-form curvature of a group of two columns", and gate/refusal boundary cases.

**Sources.** `docs/src/choosing-solver.md:L263`, `docs/src/numerics.md:L492`, `docs/src/numerics.md:L494`, `docs/src/numerics.md:L503`, `docs/src/numerics.md:L507`, `docs/src/numerics.md:L514`, `docs/src/numerics.md:L529`, `docs/src/numerics.md:L546`, `docstring:src/cd/solver.jl:L84`, `docs/src/internals.md:L23`.

## [CDG-05 Deferred curvature and workspace](@id CDG-05)

**Statement.**

**Lazy computation.** Computing the bound of a group costs a pass over its columns, and on
the general rule a copy of the columns, their Gram matrix and, for two or more columns, an
eigenvalue computation; a group that stays at zero may never need it. During the
preparation, a group on the Gram route gets cheap bounds, formed in `Float64` from the sums
of squares `q_c` of its columns (`n m` operations, no products between columns): with `t`
the sum and `d` the largest of the `q_c`, a lower bound `lo = d (1 − 2 n eps(Float64)) − 2 n η`
and an upper bound `hi = 4 t` on the curvature that the rules above would store (`η` the
smallest positive `Float64`; the bounds assume gradual underflow, and the upper one the
eigenvalue model for a group that takes the eigenvalue computation: three or more columns,
or two columns outside the range of their rule). Under these assumptions, the four conditions below exclude the refusals; a
deferred group can still be refused during a pass through an eigenvalue routine that
throws, or through a violation of the model. The curvature is left uncomputed (`NaN` in the model) only if the type `S` of the scale is `Float32` or
`Float64`, `4 (n + m²) eps(Float64) ≤ 1/16`, `t` is finite, and all of these hold:

1. `lo ≥ 2 m floatmin(Float64)`, so that the trace underflow refusal is not made;
2. `lo ≥ 2 floatmin(T)`, so that the curvature underflow refusal is not made;
3. `hi ≤ floatmax(T) / 2`, so that no overflow refusal is made;
4. `s lo ≥ 2 floatmin(S)` and `s hi ≤ 1 / (2 floatmin(S))`, so that the step band check
   does not refuse.

The curvature is then computed, once per solve, at the first visit that needs it: a visit
whose block is nonzero, or whose block is zero and which the screen above does not remove,
and the band check is made there. A deferred group that stays at zero and is screened out
at each visit never computes its curvature. If any condition fails or the bounds do not
apply, the group is not deferred: the curvature and the band are computed during the
preparation, as for the other groups, and refuse as below, so such a group may already have
a curvature when it is screened. A one-column group with `n eps(T) > 1/8` is on the Gram
route and can be deferred. The bounds do not decide an eigenvalue routine that throws, or a
largest eigenvalue that is not finite: these surface during the preparation for a group
that is not deferred, and at the lazy computation, during a pass, for a deferred group.
How much the lazy computation saves depends on how many groups fail the screen; see
[Cost of the lazy curvature](../choosing-solver.md#Cost-of-the-lazy-curvature).

The Float64 copy of the columns and the Gram matrix are solver workspace, allocated
when the first bound that uses them is computed. They are sized by the largest group:
`n` times that size and its square, respectively, in Float64. The solver keeps no other
copy of the columns. [Lazy-curvature measurements](evidence/lazy-curvature-cost.md)
describe costs on particular designs and are not general performance guarantees.

**Applies to.** Groups taking the Gram route, including one-column groups with `n eps(T) > 1/8`.

**Code.** `src/cd/leastsquares.jl`: `_curvature_deferrable`, `_group_curvature!`, lazy workspaces.

**Tests.** `test/group_cd.jl`: "screened zero groups never compute a curvature (orthogonal designs)", "a screened group activates on a later visit", allocation checks.

**Sources.** `docs/src/choosing-solver.md:L263`, `docs/src/numerics.md:L562`, `docs/src/numerics.md:L576`, `docs/src/numerics.md:L577`, `docs/src/numerics.md:L578`, `docs/src/numerics.md:L579`, `docs/src/numerics.md:L582`, `docstring:src/cd/solver.jl:L84`, `docs/src/internals.md:L23`, `docstring:src/solvers/proximal_gradient_descent.jl:L367`.

## [CDG-06 Step band and numerical refusals](@id CDG-06)

**Statement.**

The step of a nonflat group also needs `s ℓ_k` and its reciprocal to be at least the
smallest normal number of the type `S` that combines `s` with `T`. This band check is made
where the curvature is computed: during the preparation, or at the lazy computation. It cannot fail when `S` is wider than `T`, for example `Float32`
data with a `Float64` loss scale, because the scale then converts to a finite nonzero
`Float32` and the curvature is a normal `Float32` number; it can fail only when `S` is `T`
itself. The scale need not have the data type: `Float64` data `X = fill(2.0^-500, 1, 1)`
with the `Float32` scale `nextfloat(0f0)` has `ℓ_k` about `2^-1000`, a normal `Float64`
number, and `s ℓ_k` is below the smallest normal `Float64` number.

**When the refusals happen.** The refusals below throw an `ArgumentError` that names the
group, and they leave `x` unchanged. Those that are predictable, because the curvature is
computed during the preparation or the four conditions above hold, happen before the first
pass, and the random number generator is unused. A curvature computed lazily is computed
in the same way, and an exception of the eigenvalue routine (which is not caught), a
largest eigenvalue that is not finite (both on the general rule), or a curvature or step
refusal at that point (which the four conditions are meant to exclude) happens during a
pass: `x` is still unchanged, but a random order may already have drawn from the generator.

| Category | Condition | Message contains |
| --- | --- | --- |
| Curvature underflow | the sum of squares of the column of a group of one column with `n eps(T) ≤ 1/8` is below `floatmin(T)`, the trace of `Ĝ` is below `m` times `floatmin(Float64)` (on the general rule), or `ℓ_k` is below `floatmin(T)` | `underflows` |
| Curvature overflow | the sum of squares of that column, `Ĝ`, its trace or its largest eigenvalue is not finite (on the general rule), or `ℓ_k` is infinite in `T` | `overflows` |
| Step | `s ℓ_k` or its reciprocal is outside the normal range | `step of group` |

A group whose curvature is subnormal in `T` is refused, whereas scalar lasso CD accepts
a subnormal squared column norm. No fallback rule replaces a refused curvature.
The preflight input refusals are specified in [CDG-01](@ref).

**Applies to.** Nonflat vector-response block-CD groups, at eager or deferred curvature computation.

**Code.** `src/cd/leastsquares.jl`: `_check_step_band`, curvature routines and refusal helpers.

**Tests.** `test/group_cd.jl`: curvature underflow/overflow, step-band and later-pass rollback cases; `test/group_cd_preflight.jl`.

**Sources.** `docs/src/numerics.md:L595`, `docs/src/numerics.md:L604`, `docs/src/numerics.md:L613`, `docs/src/numerics.md:L614`, `docs/src/numerics.md:L615`, `docs/src/numerics.md:L616`, `docs/src/numerics.md:L617`, `docs/src/numerics.md:L619`, `docstring:src/cd/solver.jl:L84`.

## [CDG-07 Stopping and group visits](@id CDG-07)

**Statement.**

With `relative = true` and a positive response scale, the change of a visit is
`‖Δ_G‖₂ √(s ℓ_k)`, formed by the range-safe rule that the lasso uses for `√(s a)`, and it
is compared with `tol` times the response scale of the lasso. For a group of one column
this is the lasso statistic up to the margin and rounding noted above. A flat group has
scale 0, so its change is 0. With `relative = false`, or for `y = 0`, the change is
`‖Δ_G‖₂` itself. A pass reports the largest change among the groups it visited, and a
full pass whose largest change is below the threshold ends the solve with
`converged = true`.

`converged = true` reports that change test only. It is not a certificate of optimality:
compute the group KKT conditions from the data, as in
the [group lasso tutorial](../examples/problems/group_lasso.md), where for `∇ = s Xᵀ(Xβ − y)` a nonzero group
needs `∇[G] + λ w β[G] / ‖β[G]‖ = 0` and a zero group needs `‖∇[G]‖ ≤ λ w`.
What the change test implies, and how far group CD stopped from a minimizer in the audit, is in
[What the change test of coordinate descent implies](@ref CD-06).

The pass schedule is that of the lasso with groups as the coordinates. A full pass
visits every group and an active pass visits the active groups; after each pass the
groups whose block is entirely zero become inactive. The forced full pass counts group
visits: once the active passes since the last full pass have together visited 20 times as
many groups as there are groups, the next pass is a full pass, whatever the changes.

For singleton groups with default weights the mathematical penalty equals `NormL1`,
but the curvature margin and rounding in [CDG-04](@ref) can change numerical iterates.
`ProximalGradientDescent` and `AccProxGradDescent` instead update all groups with block soft thresholding and apply their
[stationarity check](@ref STOP-01); the
[group tutorial](../examples/problems/group_lasso.md) and
[solver comparison](../examples/comparisons/group_lasso_solvers.md) demonstrate these choices.

**Applies to.** Vector-response group CD; `relative`, `tol` and pass limits have the scalar meanings.

**Code.** `src/cd/solver.jl`: common pass schedule; `src/cd/leastsquares.jl`: group displacement norm and scale.

**Tests.** `test/group_cd.jl`: "the stopping statistic of the first pass on an orthogonal design", independently checked KKT/objective and singleton cases.

**Sources.** `docs/src/choosing-solver.md:L263`, `docs/src/numerics.md:L628`, `docs/src/numerics.md:L630`, `docs/src/numerics.md:L639`, `docs/src/numerics.md:L646`, `docs/src/stopping-limits.md:L95`, `docstring:src/cd/solver.jl:L84`.

## [CDG-08 Results and commit boundary](@id CDG-08)

**Statement.**

The solve runs on a private copy of `x`. A finite completed run, including one that
ends at `maxpasses` with the warning, replaces `x` by one same-layout copy of the final
state; a refusal or numerical error before that leaves the values, the active groups and
their order of `x` unchanged, though a random order may already have drawn from the
generator. After at least one pass, zero groups are deactivated, so the active groups
are exactly those with a nonzero block. With `maxpasses = 0`, the complete entry state
is kept, including active groups whose block is zero. The entries of the groups that
are inactive at the end are zero; their sign is not specified. After a solve, take
`activecoordinates(x)` again, as for a `SparseIterate`.

The result type is the scalar lasso's `CDResults`. `passes` counts group passes,
active coordinates are group numbers, and random order permutes the groups.
`minimizer === x`, `kkt_checks = 0`, and `gap = NaN`; the last two are placeholders,
not computed certificates. The nonconverged warning is the scalar lasso's warning.

**Applies to.** Successful, pass-limited and failed vector-response block-CD runs.

**Code.** `src/solve.jl`: private block iterate and finite completed-run commit; `src/cd/solver.jl`: result construction.

**Tests.** `test/group_cd.jl`: zero-pass ownership, finite one-pass commits and numerical rollback.

**Sources.** `docs/src/numerics.md:L443`, `docs/src/numerics.md:L652`, `docs/src/numerics.md:L654`, `docs/src/support.md:L195`, `docs/src/support.md:L198`, `docstring:src/solvers/proximal_gradient_descent.jl:L367`.
