# [Group coordinate descent](@id CDG-01)

<!-- Migration source: docs/src/numerics.md:L441-L660 -->

## Group lasso on a BlockIterate

`CDSolver` accepts a `BlockIterate{T}` with a `GroupNormL2` penalty (see
[Supported problems](../support.md)); the coordinates of the solver are the groups. The pass
schedule, `tol`, `relative`, `maxpasses`, the borrowed random number generator, the
not-converged warning and the result type are those of the lasso. The result has
`kkt_checks = 0` and `gap = NaN`, placeholders and not computed certificates, and
`minimizer === x`. A random order permutes the groups.

### The group step

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

### The curvature bound

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

A group whose curvature bound is subnormal in `T` is refused here, where the scalar
lasso accepts a subnormal squared norm of a column. Before these, `solve!` refuses a
receiver that is not a `BlockIterate{Float32}` or `BlockIterate{Float64}`,
`momentum = true`, a penalty that is not a `GroupNormL2{Float32}` or `GroupNormL2{Float64}`,
a level or weight that is not finite, nonnegative and representable in `T` (messages
`penalty lambda` and `group weight`), and groups of `x` and of the penalty that differ in
number, order or membership (`DimensionMismatch`); these input refusals also apply with
`maxpasses = 0`. No fallback rule replaces a refused curvature.

### The stopping statistic

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
[What the change test of coordinate descent implies](@ref "What the change test of coordinate descent implies").

The pass schedule is that of the lasso with groups as the coordinates. A full pass
visits every group and an active pass visits the active groups; after each pass the
groups whose block is entirely zero become inactive. The forced full pass counts group
visits: once the active passes since the last full pass have together visited 20 times as
many groups as there are groups, the next pass is a full pass, whatever the changes.

### Result and failure

The solve runs on a private copy of `x`. A finite completed run, including one that
ends at `maxpasses` with the warning, replaces `x` by one same-layout copy of the final
state; a refusal or numerical error before that leaves the values, the active groups and
their order of `x` unchanged, though a random order may already have drawn from the
generator. The entries of the groups that are inactive at the end are zero; their sign is
not specified. After a solve, take `activecoordinates(x)` again, as for a `SparseIterate`.

<!-- Migration source: docs/src/choosing-solver.md:L263-L299 -->

A coordinate of the solver is a group, so `passes` counts passes over groups and the
active coordinates are group numbers. Each group needs, at most once per solve, a bound
on the largest eigenvalue of `X[:, G]' * X[:, G]`. With `maxpasses = 0` none is prepared.
A group whose columns are all zero needs no product and no eigenvalue computation, and a
group of one column (when `n eps(T) ≤ 1/8`, `n` the number of rows) takes the sum of
squares of its column, as the lasso does. A group of two columns takes the three entries
of its Gram matrix in one pass over its columns and its bound in closed form; inside the
range of that rule (finite `Float32` data, and `Float64` data whose columns are not
extremely small or large, see [Numerical behavior](../numerics.md#The-curvature-bound)) it
needs no eigenvalue computation and no `Float64` copy of its columns. Any other group, and
a group of two columns outside that range, needs the Gram matrix of its columns in
`Float64` from a copy of the columns and, for two or more columns, an eigenvalue
computation. These are done at the first visit that needs them, so a group that stays at
zero and is screened out at each visit never pays for them, except where cheap bounds
cannot rule out a refusal (under the eigenvalue model, for a group that takes the eigenvalue
computation), in which case the bound is computed before the first pass (such a group, or
an ordinary one-column group, already has its bound when it is screened). A visit to a
nonflat group whose block is zero is screened this way, whether or not the group is active,
when the reciprocal of the loss scale is a normal number of its type and either all
correlations of the group are zero or the largest magnitude is at least `2^53 floatmin(T)`;
otherwise the visit takes the full step. The `Float64` copy of the columns and the Gram
matrix are workspace of the solver, allocated when the first bound that uses them is
computed and sized by the largest group of the iterate: `n` times that size, and its
square, in `Float64`. The solver keeps no other copy of the columns. For a group of one coefficient, the penalty is a term of an L1 penalty, and
with the default weights `GroupNormL2` with only singleton groups is the same problem
as `NormL1`, which the dense-vector solvers accept. Momentum does not apply:
`momentum = true` is refused for a `BlockIterate`, and `nothing` or `false` both mean
plain block coordinate descent. The stopping test works as in the relative-tolerance
discussion above with the change of a group, the norm of its displacement; see
[Numerical behavior](../numerics.md). As for the lasso, `converged = true` is not an
optimality certificate: check the group KKT conditions independently, as in the example.
`ProximalGradientDescent` and `AccProxGradDescent` take the block soft threshold of every group at each step and
report `converged = true` only where the group KKT residual passes its check; the
[group lasso tutorial](../examples/problems/group_lasso.md) solves one problem with all three solvers, and
[Group lasso: CD, PGD and APG](../examples/comparisons/group_lasso_solvers.md) compares the three on one
seeded problem.

<!-- Migration source: docs/src/support.md:L174-L204 -->

### Group lasso with coordinate descent

~~~math
\min_\beta\quad \frac{s}{2}\|y-X\beta\|_2^2+\lambda\sum_k w_k\|\beta_{G_k}\|_2,
~~~

with the groups `G_k` of a `GroupNormL2(lambda, groups)` or
`GroupNormL2(lambda, groups, w)`; the default weights are `w_k = sqrt(|G_k|)`.
`solve!(x, f, g, CDSolver(...))` accepts this problem when

- `x` is a `BlockIterate{T}` and the data, the loss and the scale are as above, with
  `T` equal to `Float32` or `Float64`;
- `g` is a `GroupNormL2` whose element type is `Float32` or `Float64`. A `Float64`
  penalty on `Float32` data is accepted. The level `lambda` and every weight must be
  finite, nonnegative and representable in `T` without overflow, and a nonzero value
  must not round to zero;
- the groups of `g` and of `x` are the same, group by group, in the same order and with
  the same ordered members, otherwise `solve!` throws a `DimensionMismatch`. A
  `BlockIterate` is a nonempty partition of `1:p` into disjoint groups, so there are no
  unpenalized coefficients outside the groups; `BlockIterate(T, p, g)` builds one with
  the groups of `g`;
- the solver does not use momentum: `momentum = true` is refused with an
  `ArgumentError`, and `nothing` or `false` both give plain block coordinate descent.

The coordinates of the solver are the groups: a pass visits whole groups, `passes`
counts passes, and the active coordinates of the iterate are group numbers. All
refusals of these inputs (receiver, momentum, penalty, weights, layout, aliasing of
`x` with `X` or `y`, nonfinite values) throw before `x` is copied or the random number
generator is used. [Numerical behavior](../numerics.md) lists the refusals that depend on
the values of `X` and describes the curvature and the stopping statistic of a group.

<!-- Migration source: src/cd/solver.jl:L84-L113 -->

**Group lasso.** With `T` equal to `Float32` or `Float64`, `x = BlockIterate(T, p, g)`
and `g = GroupNormL2(lambda, groups)` (or with weights), the call
`solve!(x, f, g, CDSolver(order=:cyclic, tol=1e-10))` minimizes the least-squares
loss plus `lambda * sum(w[k] * norm(x[groups[k]]))`. The loss is as for the lasso. `g` is a
`GroupNormL2{Float32}` or `GroupNormL2{Float64}` whose level and weights are finite,
nonnegative and representable in `T`, and its groups and those of `x` agree in number,
order and ordered members, otherwise a `DimensionMismatch` is thrown. The coordinates are
the groups, and a pass visits whole groups. `momentum = true` is refused with an
`ArgumentError`; `nothing` and `false` give plain block coordinate descent. The change of
a group is `norm` of its displacement, which `relative=true` multiplies by
`sqrt(s * l)` for a positive response scale, where `l` bounds the largest eigenvalue of
the Gram matrix of the columns of the group; the forced full pass counts group visits.
As for the lasso, `converged` reports this change test and is not a KKT certificate.
The curvature of a flat group, and of a group of one column when `n eps(T) <= 1/8` (`n`
the number of rows), is set before the first pass. That of any other group is computed
at the first visit that needs it when cheap bounds show that no refusal can occur (under the
eigenvalue model for groups of three or more columns and for groups of two columns outside the
range of their closed-form bound), and before the first pass otherwise. A visit to a nonflat group whose block is zero, active or
not, first applies ProximalBase's `prox_block!` to the correlations at the step `1/s`
(skipped when `1/s` is not a normal number of the scale's arithmetic type, or when the
correlations are not all zero and the largest magnitude is below `2^53 * floatmin(T)`) and ends without a
change, and without computing a still-deferred curvature, when the result is zero. Before
the first pass, and before any draw from the RNG, an `ArgumentError` that names the group
refuses a curvature that underflows or overflows in `T` and a step outside the normal
range, for each group whose curvature is computed then. An exception of the eigenvalue
routine (which a group of two columns inside the range of its closed-form bound does not
call), a refusal of a lazily computed curvature, and a trial point or displacement that
is not finite can occur during a pass; `x` is then unchanged, and the RNG may have
advanced. The curvature rule and the refusals are described in the numerical
guide.

