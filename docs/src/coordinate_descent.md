# Coordinate descent

[`CDSolver`](@ref) minimizes

```math
F(x) = f(x) + \sum_k g_k(x_k)
```

one coordinate at a time, where the penalty separates over coordinates (the
weighted ℓ1 norm, the elastic net, MCP, SCAD, the nonnegative ℓ1 norm, bounds)
or over groups of coordinates (the group lasso). The loss ``f`` is one whose
structure coordinate descent knows (see [Losses for coordinate descent](@ref)),
with cached residuals or matrix products: least squares, quadratics, Kronecker
quadratics of matrices, square-root losses and generalized linear losses.

## The coordinate step

Fix every coordinate but ``x_k``. Let ``G = \nabla_k f(x)`` be the derivative
of the loss along the coordinate and ``a_k`` its curvature, exact when ``f`` is
quadratic and otherwise an upper bound. For ``a_k>0``, suppose that
``f(x + t e_k) \le f(x) + G t + \frac{a_k}{2} t^2`` for all ``t``. The step
minimizes this bound plus the penalty of the coordinate:

```math
x_k^+ = \operatorname*{argmin}_t \; G\,(t - x_k) + \frac{a_k}{2}(t - x_k)^2 + g_k(t)
      = \operatorname{prox}_{g_k/a_k}\Big(x_k - \frac{G}{a_k}\Big).
```

The scalar proximal operator is
[`prox_entry`](@extref ProximalBase.prox_entry)`(g, v, i, γ)` of ProximalBase,
so every separable penalty of ProximalBase works without code in this package:
soft thresholding for the ℓ1 norm, ``\operatorname{shrink}(v, \gamma\lambda_1)/(1 + \gamma\lambda_2)``
for the elastic net, firm thresholding for MCP, a clamp for bounds. For a
quadratic loss the step minimizes ``F`` exactly over the coordinate; otherwise
it minimizes a majorizer, and in both cases ``F`` does not increase.

A coordinate with ``a_k = 0`` and derivative ``G`` targets
``\min_x G(x - \beta_k) + \mu g_i(x)``, where ``\mu`` counts the entries moved
by the coordinate (two for a symmetric off-diagonal entry). Norms retain the
minimizer nearest zero while their subgradient contains ``-G/\mu``, and boxes
select their minimizing endpoint directly. The following penalties also have
exact flat-coordinate steps. Write ``s = G/\mu`` and ``c = \lambda w_i``.

| Penalty | Flat-coordinate minimizer |
|:--|:--|
| `ElasticNet(λ1, λ2, w)`, ``\lambda_2 > 0`` | ``-\operatorname{sign}(G)\max(\lvert s\rvert-\lambda_1w_i,0)/\lambda_2`` |
| `SqrNormL2(λ, y)`, ``\lambda > 0`` | ``y_i-s/\lambda``, with ``y_i=0`` when omitted |
| `Berhu(λ, M, w)`, ``c>0`` | Zero for ``\lvert s\rvert\le c``; otherwise ``-\operatorname{sign}(G)M\lvert s\rvert/c`` |
| `NegLog(λ)` | ``\mu\lambda/G`` for ``G>0`` |
| `NegEntropy(λ)` | ``\exp(-s/\lambda-1)`` |
| `KLDivergence(q; λ)` | ``\exp(\log q_i-s/\lambda)`` |
| `Regularize(f, ρ, c)`, convex `f` and ``\rho>0`` | ``\operatorname{prox}_{f_i/\rho}(c_i-s/\rho)``, with ``c_i=0`` when omitted |

A zero ridge parameter reduces to the norm or underlying penalty. A Berhu
entry with zero level or weight minimizes at zero when ``G=0`` and is
unbounded for nonzero ``G``. `NegLog` is unbounded for ``G\le0``.
`Scaled` and `Tilt` reduce to the underlying penalty and its effective slope.
For the exact penalties above, `Translate(f, b)` adds ``b_i`` to the inner
minimizer. `BoxConstrained` clamps an exact finite minimizer or selects the
finite end in an exact unbounded or overflow direction. If the inner answer is
unavailable, the whole boxed penalty uses the generic candidate method with
a fixed-point check in higher precision. Other translated and boxed penalties
keep the generic candidate method on the whole wrapper, preserving its choice
of minimizer.
A translated or clamped point must lie in the inner domain: strictly positive
for `NegLog`, and
nonnegative for `NegEntropy` and `KLDivergence`, including through wrappers.
These rules also apply to least-squares columns that are zero, or constant
with an intercept, on rows with positive weight. When a computed curvature
is zero, the model checks the column entries, including implicit sparse zeros.
A non-flat column whose curvature underflows raises an `ArgumentError` that
requests rescaling; its actual slope is retained by `kkt_residual`.

An unbounded flat subproblem, an unsupported one, or a minimizer or displacement
that cannot be represented in the iterate's element type raises an
`ArgumentError`; [`kkt_residual`](@ref) reports `Inf` there. Unboxed entropy and
KL minimizers that underflow to zero are numerically unavailable. A box
may still have a representable minimizer, including a single feasible domain
point. Numerical rejection does not assert unboundedness. The attempted coordinate
and its cache
are unchanged; earlier coordinates of the pass may already have moved.
Exact formulas and wrapper compositions promote the iterate and penalty parameter
types recursively, using at least Float64 precision and preserving BigFloat
iterates and parameters. They convert once to the iterate's element type, then
check
finiteness, underflow and the domain. Balanced quotients avoid intermediate
overflow and underflow from products and sequential divisions.
Nonconvex penalties with a nonzero effective slope are rejected, including on
a box: a local proximal fixed point does not establish a global minimizer.
Other penalties keep the existing generic flat-candidate method; give an
unsupported coordinate positive curvature.

For a differentiable convex loss and a convex separable penalty, with suitable
regularity and coordinate curvature conditions,
every limit point of coordinate descent that visits each coordinate at least
once in every ``T`` consecutive steps is a minimizer of ``F``: for exact
minimization over each coordinate (Tseng, 2001), and for the majorization
steps of a loss with a bounded curvature (Tseng and Yun, 2009). The solver
interleaves such passes over all coordinates with passes over the active ones,
and stops only after a full pass, as described below. For MCP and SCAD, which
are not convex, coordinate descent converges to a stationary point when the
coordinate problems are convex, as they are for standardized columns (Breheny
and Huang, 2011).

## The lasso update and residual cache

For the running example ``f(\beta)=\|y-X\beta\|_2^2/(2n)`` and
``g(\beta)=\lambda\|\beta\|_1``, write ``r=y-X\beta``. The derivative and
curvature along coordinate ``j`` are

```math
G_j=-\frac{X_j^\top r}{n},\qquad a_j=\frac{\|X_j\|_2^2}{n}.
```

For a nonzero column ``X_j``, substituting these quantities into the
coordinate step gives

```math
\beta_j^+=\operatorname{soft}\left(
\beta_j+\frac{X_j^\top r}{\|X_j\|_2^2},
\frac{n\lambda}{\|X_j\|_2^2}\right),
\qquad
\operatorname{soft}(v,c)=\operatorname{sign}(v)\max\{|v|-c,0\}.
```

After a change ``\Delta=\beta_j^+-\beta_j``, the residual is updated as
``r\leftarrow r-X_j\Delta``. Therefore, a dense coordinate step costs ``O(n)``
operations, without recomputing ``X\beta``. For a sparse design, the update
visits only the nonzero entries of the column. A zero column contributes
nothing to the loss, and its coefficient is set to zero.

The scalar proximal step and the residual cache serve different purposes.
The proximal operator handles the penalty, while the coordinate model uses
the loss structure to compute and update its derivatives cheaply. A full
proximal gradient step uses the same soft thresholding operation on all
coordinates after computing the full gradient.

[Getting started](@ref) runs both algorithms on this objective.
[Checking a solution](@ref) derives the lasso optimality conditions and its
duality gap.

## Coordinates of the iterates

The iterate fixes what a coordinate is.

- On a `SparseIterate`, a coordinate is an entry. The iterate stores the
  entries that have been nonzero: these are the **active** coordinates.
- On a `SymmetricSparseIterate`, the coordinates are the entries ``(r, c)``,
  ``r \ge c``, of the lower triangle of a symmetric matrix ``\Theta``. A step on
  an off-diagonal coordinate moves ``\Theta_{rc}`` and ``\Theta_{cr}``
  together, along ``D = E_{rc} + E_{cr}``. Let ``G`` be the derivative of the
  loss along ``D`` and ``a`` its curvature along ``D``. A separable penalty
  on the full matrix contributes ``h_{rc}(t) = g_{rc}(t) + g_{cr}(t)`` along
  an off-diagonal coordinate, and ``h_{rr}(t) = g_{rr}(t)`` on the diagonal.
  The step is

  ```math
  t^+ = \operatorname*{argmin}_t \; G\,(t - t_0) + \frac{a}{2}(t - t_0)^2 + h_{rc}(t)
      = \operatorname{prox}_{h_{rc}/a}\Big(t_0 - \frac{G}{a}\Big).
  ```

  Per-entry parameters are indexed like the full matrix, as a matrix or a
  vector in column-major order. Solvers average transposed parameters that
  enter the penalty linearly: the weights of `NormL1`, `NormL1Nonneg`,
  `ElasticNet` (L1 term), `CappedL1`, `LogPenalty`, `NormLq`, `Berhu`,
  `CheckLoss`, `EpsInsensitiveLoss` and `HingeLoss`, and the coefficients
  `c` of `Tilt` and `LinearFunction`. The constants `d` are kept. This leaves
  ``g(X)`` unchanged for every symmetric ``X``, up to floating-point rounding.
  With the prepared penalty ``\bar g``, the pair contributes
  ``h_{rc}(t) = 2\bar g_{rc}(t)``.

  Other per-entry parameters must already be symmetric: the bounds `l` and
  `u` of `IndBox`, including the box of `Constrained(g, IndBox)`, the pattern
  `P` of `IndPattern`, the center `y` of `SqrNormL2`, the center `c` of
  `Regularize`, the translation `b` of `Translate`, the labels `y` of
  `HingeLoss` and the reference `q` of `KLDivergence`. An asymmetric one
  raises an `ArgumentError` before mutation.

  Normalization recurses through `Scaled`, `Tilt`, `Translate`, `Regularize`,
  `Constrained(·, IndBox)` and scalar `Precompose`, subject to those symmetry
  requirements. Inside `MoreauEnvelope`, `Conjugate` and linear constraints,
  these parameters must already be symmetric; no averaging is done there.
  The coefficient `a` of a linear constraint must also be symmetric.
  These rules do not extend the penalty families supported by a solver or
  wrapper.

  Symmetric or absent parameters keep the supplied penalty object itself;
  supplied arrays are never changed. Unknown penalty types pass unchanged
  and must have symmetric per-entry parameters. The low-level
  [`coordinate_step!`](@ref ProximalSolvers.coordinate_step!) and
  `prox_coordinate!` kernels also require parameters that are already
  symmetric.

  The same rule applies to [`lambda_max`](@ref), screening, continuation,
  [`solve_path`](@ref), [`kkt_residual`](@ref) and [`SolverWorkspace`](@ref).
  A workspace keeps the supplied `workspace.g` and prepares the penalty again
  at each solve. [`LLA`](@ref) prepares it before forming stage weights, so
  `ReweightResults.penalty` and `next` hold averaged stage weights. With
  [`reweight!`](@ref), `update` receives the supplied penalty, which is also
  kept in the results; each solve prepares it separately. The reported
  minimum uses the supplied objective.

  The pair mean avoids overflow for finite weights. A pair whose sum is below
  twice the smallest subnormal may have a mean that rounds to zero. Infinite
  weights are kept, but some non-L1 families of ProximalBase do not handle
  them in their proximal operators.
- On an `AtomIterate`, a coordinate is a group of entries, for the group
  lasso; see the next section.

## Groups

For the group lasso, ``g(x) = \lambda \sum_k w_k \|x_{G_k}\|_2`` with the
groups of an `AtomIterate`, the step on group ``G = G_k`` majorizes the loss
over the block by a quadratic with curvature ``L_k \ge \lambda_{\max}(\nabla^2_{GG} f)``
and minimizes the majorizer plus the group's penalty (groupwise majorization
descent, Yang and Zou, 2015):

```math
u = x_G - \frac{1}{L_k}\nabla_G f(x), \qquad
x_G^+ = \operatorname{prox}_{(\lambda w_k / L_k)\|\cdot\|_2}(u)
      = \max\Big\{1 - \frac{\lambda w_k}{L_k \|u\|_2},\ 0\Big\}\, u .
```

For least squares, ``L_k = s\,\lambda_{\max}(X_G^\top W X_G)``, computed on the first visit to the group using reusable eigensolver buffers,
and kept for the rest of a path. First use can grow those buffers. A group at zero stays at zero exactly
when ``\|\nabla_G f(x)\|_2 \le \lambda w_k``, its optimality condition, which is
checked first: ``L_k`` is never computed for a group that does not move.

Any other group penalty of ProximalBase on the groups of the `AtomIterate`,
such as `GroupNormLinf` or a sparse group lasso, takes the same majorized
step through its own proximal operator on the group, `prox_coordinate!`, and a
separable penalty takes it entry by entry. When ``L_k = 0`` the loss does not
depend on the group, which goes to the minimizer of the penalty. These steps
work with the least-squares and quadratic models.

## Passes and the active set

A pass visits a set of coordinates once each, in a uniformly random order drawn
afresh for each pass (`order = :random`, from the global random number
generator) or in the order ``1, 2, \dots`` (`order = :cyclic`). A **full**
pass visits every coordinate, or the candidates kept by screening (see
[Penalty paths and screening](@ref)); an **active** pass visits the active
coordinates only. The active set does not change during a pass: a coordinate
that becomes zero stays stored until the end of the pass, when zeros are
dropped.

The passes follow the strategy of glmnet (Friedman, Hastie and Tibshirani,
2010). The first pass is full. After a full pass in which some coordinate
moved by more than the tolerance, active passes follow until one moves no
coordinate by more than the tolerance; then a full pass checks all
coordinates. The method stops after a full pass in which no coordinate moves
by more than the tolerance, or after `maxpasses` passes, with a warning. Most
coordinates of a sparse solution are zero and stay zero, and the active
passes, which do most of the work, never visit them.

## The stopping rule

The change of a coordinate in a pass is measured on the scale of the data. With
`relative = true`, the default, the change of coordinate ``k`` is
``\delta_k = |\Delta x_k|\sqrt{a_k}`` and the tolerance is ``\mathrm{tol}\cdot\sigma``,
where ``\sqrt{a_k}`` and ``\sigma`` come from the model
([`coordinate_scale`](@ref ProximalSolvers.coordinate_scale) and
[`response_scale`](@ref ProximalSolvers.response_scale)).

For least squares, ``f(\beta) = \frac{s}{2}\sum_i w_i (y_i - o_i - x_i^\top\beta)^2``,
the scales are ``\sqrt{a_k} = \sqrt{s}\,\|X_k\|_W`` and
``\sigma = \sqrt{s}\,\|y - o\|_W`` (with the columns and the response centered
when the model fits an intercept). Then ``\delta_k = \sqrt{s}\,\|X_k \Delta\beta_k\|_W``
is the change of the fitted values that the step makes, and the rule reads

```math
\max_k \|X_k \Delta\beta_k\|_W < \mathrm{tol}\cdot \|y - o\|_W .
```

It does not depend on the units of the data: rescaling ``y``, a column of
``X`` (whose coefficient then scales inversely) or the loss leaves it
unchanged. The other models follow the same pattern:

| Model | ``\sqrt{a_k}`` | ``\sigma`` |
|:------|:---------------|:-----------|
| least squares | ``\sqrt{s}\,\lVert X_k\rVert_W`` | ``\sqrt{s}\,\lVert y - o\rVert_W`` |
| quadratic ``s(\tfrac12 x^\top A x + b^\top x + c)`` | ``\sqrt{s A_{kk}}`` | ``\sqrt{s}\max_k \lvert b_k\rvert/\sqrt{A_{kk}}`` |
| Kronecker quadratic | ``\sqrt{a_k}`` | ``\max_k \lvert \partial_k f(0)\rvert/\sqrt{a_k}`` |
| generalized linear, curvature bound ``\bar\ell`` | ``\sqrt{a_k}`` | ``\big(s \sum_i w_i \ell'(o_i, y_i)^2/\bar\ell\big)^{1/2}`` |
| ``\lVert y - X\beta\rVert`` | ``\lVert X_k\rVert/\sqrt{n}`` | ``\lVert y\rVert/\sqrt{n}`` |
| ``\sqrt{x^\top A x + 2b^\top x + c}`` | ``\sqrt{A_{kk}}`` | ``\sqrt{c}`` |

The columns and the response are centered in the rows of least squares and of
``\lVert y - X\beta\rVert`` when the model fits an intercept. For a quadratic
with ``A = X^\top X/n`` and ``b = -X^\top y/n``,
``\sqrt{A_{kk}} = \|X_k\|/\sqrt{n}`` and, by the Cauchy–Schwarz inequality,
``|b_k|/\sqrt{A_{kk}} \le \|y\|/\sqrt{n}``: the scale is a lower bound on that
of least squares. With `relative = false`, or when ``\sigma = 0``, the rule is
absolute: ``\max_k |\Delta x_k| < \mathrm{tol}``.

## Stopping on the duality gap

With `gaptol > 0`, and a loss and penalty with a duality gap (least squares
and the GLMs with the squared, logistic, Poisson, Huber or convolution check loss, with
`NormL1`, `NormL1Nonneg`, `ElasticNet`, `GroupNormL2` or the sparse group
lasso; see [Duality gaps](@ref)), the method stops when the relative gap

```math
\frac{P(x) - D(\theta)}{|P(x)|} \le \mathrm{gaptol}, \qquad P = f + g,
```

at the dual point ``\theta`` built from the gradient is at most `gaptol`. Weak
duality makes this a certificate: ``P(x) - P^\star \le \mathrm{gaptol}\,|P(x)|``.
The rule on the changes then only decides when to compute the gap: its
tolerance starts at ``\mathrm{gaptol}\cdot\sigma``, since the gap of this dual
point is about proportional to the largest scaled change, and after a full
pass with smaller changes the gap is computed; if it is above `gaptol`, the
tolerance falls by ``\tfrac12\mathrm{gaptol}/\mathrm{gap}`` (between 0.01 and
0.5) and the passes go on. With screening, the gap is that of the problem
restricted to the candidate coordinates, the others held at zero, which costs
one pass over them; the optimality check of screening then confirms it with
the full gradient (see [Penalty paths and screening](@ref)). The gap is taken
as at least ``4\epsilon|P|``, the rounding of ``P - D``. Where the dual point
does not exist (a coordinate without penalty whose gradient is not zero), the
rule on the changes with `tol` applies.

For least squares with `Float32` or narrower data, a tentative certificate
and every gap check at the change-tolerance floor use fresh residuals and
`Float64` accumulation. The primal is evaluated at the returned coefficients
and intercept; the dual residuals are centred with the observation weights
when the model fits an intercept. Loss scales and penalty weights are widened
before multiplication. The gap is accumulated from nonnegative Fenchel--Young
terms using residual-sized quantities, so a large response does not cancel
out its certificate. The residual cache used by coordinate updates and
momentum is left intact. Gap-safe screening retains a gap and a dual centre
both computed in `T`.

Narrow types monitor progress below `8eps(T)` times the data scale. The
tolerance can tighten to `eps(T)^2` times that scale while the gap falls,
and a plateau in the changes also ends active passes for a full pass and a
gap check. Progress means a gap at least 10% below the best seen; twelve
consecutive checks without this progress end the run uncertified. A
certificate is compared with `gaptol` in `Float64` before the reported gap
is rounded to `T`. Thus a reachable target below `eps(Float32)` can still
certify, while stagnation reports `converged = false`, a warning and the
gap reached. `Float64` and wider types keep their existing tolerance floor.

GLM certificates other than squared loss remain in `T`, including the outer
certificate of [`ProxNewton`](@ref); its inner least-squares certificates
use the wider accumulation. The native certificate floor `4eps(Float32)`
is about `4.8e-7`, and accumulated rounding can be larger. It is not a
guarantee of GLM gap accuracy. In the small binary-logistic regression paths
tested with and without an intercept, reported gaps differ from a `Float64`
recomputation by less than `1e-6`. This diagnostic is not a general error bound.

The paths of [`solve_path`](@ref) and the last level of continuation stop on
the gap by default, at [`PATH_GAPTOL`](@ref ProximalSolvers.PATH_GAPTOL)
`= 1e-4`; `gaptol = 1e-3` is the faster setting, for cross-validation and
prediction, and `gaptol = 0` gives back the rule on the changes with `tol`. A
single `solve!` keeps the rule on the changes unless `gaptol` is given, so
that a one-off solve stays as accurate as before.

The square-root losses add a final certificate check even with `gaptol = 0`:
the default relative-gap target is `1e-4`. Their coordinate-change rule can
otherwise stop far from a joint minimizer near an exact fit. A positive
`gaptol` sets the certificate target explicitly. When an unpenalized coordinate
prevents dual scaling, the method falls back to coordinate changes; see
[The square-root lasso](@ref) for this limitation and exact-fit behavior.

The [historical gap benchmarks](https://github.com/mlakolar/ProximalSolvers.jl/tree/f7e3f28026a8e83e0fa18203b39839cf57a1c949/benchmark/gap)
retain the workloads, scripts and earlier timing and accuracy comparisons.
They concern earlier source editions and do not establish performance of this
release. A gap target bounds objective error; coefficient error depends on
curvature and identifiability. Compare methods at matched accuracy on the
hardware used for the application.

## Momentum

With the random order, the passes over the active set use Nesterov momentum.
Let ``x_1`` be the active values at a restart, and ``x_{j+1}`` those after the
``j``-th active pass that follows. That pass starts from the extrapolated
point

```math
z = x_j + \omega_j\,(x_j - x_{j-1}), \qquad \omega_j = \frac{j - 1}{j + 2},
```

instead of ``x_j``: the first pass after a restart has no momentum, and the
second has ``\omega_2 = 1/4``. The cache of a built-in model, such as the
residuals of least squares, ``Ax`` of a quadratic or the linear predictor of a
generalized linear loss, is affine in ``x``, so it moves to ``z`` exactly by
the same combination of its two last values, at the cost of a few vector
operations per pass; the square root of a quadratic recomputes its value,
which is not affine. A model of another loss is initialized at ``z``.

The momentum restarts (``j \leftarrow 1``) after every full pass, when the
active set changes, and when the step of a pass points against it,
``(x_{j+1} - z)^\top (x_j - x_{j-1}) < 0``: the gradient restart of
O'Donoghue and Candès (2015). Full passes are never extrapolated, and a cache
moved by the momentum is computed afresh before the next full pass, so the
method stops on a plain full pass, and screening checks an exact gradient.

By default (`momentum = nothing`), momentum is used with the random order on a
`SparseIterate` for least squares, generalized linear losses, quadratics and
the two square-root losses. `momentum = true` turns it on for any model on a
`SparseIterate` or a `SymmetricSparseIterate`, such as the Kronecker quadratic.
Its effect on runtime depends on the problem and should be measured at matched
accuracy. The cyclic order can stall with momentum, so it refuses
`momentum = true`.

## Anderson acceleration

With the cyclic order, a pass over a fixed active set ``S`` is a fixed map
``T``, and the passes are the fixed-point iteration ``x \leftarrow T(x)``.
`anderson = K` extrapolates it (Bertrand and Massias, 2021). It records the
values ``x^{(0)}, \dots, x^{(K)}`` on ``S`` after ``K + 1`` consecutive passes
with the same active set, forms the differences
``U = [x^{(1)} - x^{(0)}, \dots, x^{(K)} - x^{(K-1)}]``, and takes the affine
combination of the last ``K`` iterates whose combined step ``Uc`` is smallest:

```math
c = \frac{(U^\top U + \epsilon I)^{-1}\mathbf 1}{\mathbf 1^\top (U^\top U + \epsilon I)^{-1}\mathbf 1}
= \operatorname*{argmin}_{\mathbf 1^\top c = 1} \|Uc\|^2 \ \ (\epsilon \to 0),
\qquad
x_e = \sum_{i=1}^{K} c_i\, x^{(i)},
```

with ``\epsilon = 10^{-10}\operatorname{tr}(U^\top U)`` for stability. The
extrapolated point is kept only if ``F(x_e) < F(x^{(K)})``, which needs the
value of the loss ([`loss_value`](@ref ProximalSolvers.loss_value)). A full
pass or a change of ``S`` starts a new history. The random order changes
``T`` from pass to pass, so `anderson` is ignored with it, as on an
`AtomIterate`. Compare Anderson and plain passes at matched accuracy;
additional history and extrapolation work can outweigh fewer passes.

## An unpenalized intercept

For least squares and the square-root loss, `cdmodel(f, x; intercept = true)`
minimizes over an unpenalized intercept ``\beta_0`` as well. For a given
``\beta``, the best intercept of ``\frac{s}{2}\|y - \beta_0\mathbf 1 - X\beta\|^2``
is ``\beta_0 = \bar y - \bar x^\top\beta``, with the means ``\bar y`` of
``y - o`` and ``\bar x`` of the columns of ``X``. Substituting it centers the
problem:

```math
\min_{\beta_0} \frac{s}{2}\|y - \beta_0\mathbf 1 - X\beta\|^2
= \frac{s}{2}\big\|(y - \bar y\mathbf 1) - (X - \mathbf 1\bar x^\top)\beta\big\|^2 .
```

The model computes the means once and centers the columns on the fly, so
``X`` is not copied: the residuals are ``r = (y - \bar y\mathbf 1) - (X - \mathbf 1 \bar x^\top)\beta``,
the derivative is ``-s(X_k - \bar x_k\mathbf 1)^\top r`` and the curvature
``s\|X_k - \bar x_k\mathbf 1\|^2``. [`intercept`](@ref ProximalSolvers.intercept)`(m, x)`
returns ``\bar y - \bar x^\top x``. A constant column is exactly zero once
centered, and its coefficient goes to zero. With observation weights, use weighted means and weighted inner products;
the intercept requires a positive sum of weights.

## Settings

`CDSolver(; maxpasses = 100_000, tol = 1e-7, order = :random, relative = true,
anderson = 0, momentum = nothing, rng = Random.default_rng(), gaptol = 0,
gapsafe = false)`. The random orders are drawn from `rng`. The result, a
[`CDResults`](@ref), reports the passes, whether the stopping rule was met, the
largest scaled change in the last pass and the tolerance it was compared with,
and the relative duality gap when `gaptol` or `gapsafe` computed it.

## References

- P. Breheny and J. Huang. Coordinate Descent Algorithms for Nonconvex
  Penalized Regression, with Applications to Biological Feature Selection.
  *Annals of Applied Statistics*, 5(1), 2011.
- Q. Bertrand and M. Massias. Anderson Acceleration of Coordinate Descent.
  *AISTATS*, 2021.
- J. Friedman, T. Hastie and R. Tibshirani. Regularization Paths for
  Generalized Linear Models via Coordinate Descent. *Journal of Statistical
  Software*, 33(1), 2010.
- B. O'Donoghue and E. Candès. Adaptive Restart for Accelerated Gradient
  Schemes. *Foundations of Computational Mathematics*, 15, 2015.
- P. Tseng. Convergence of a Block Coordinate Descent Method for
  Nondifferentiable Minimization. *Journal of Optimization Theory and
  Applications*, 109(3), 2001.
- P. Tseng and S. Yun. A Coordinate Gradient Descent Method for Nonsmooth
  Separable Minimization. *Mathematical Programming*, 117, 2009.
- Y. Yang and H. Zou. A Fast Unified Algorithm for Solving Group-Lasso
  Penalize Learning Problems. *Statistics and Computing*, 25, 2015.
