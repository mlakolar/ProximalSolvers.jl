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
it minimizes a majorizer, and in both cases ``F`` does not increase. A
coordinate with ``a_k = 0`` and derivative ``G`` goes to a minimizer of
``G(x - \beta_k) + g_k(x)`` when one exists: the minimizer of ``g_k`` nearest
zero, which for the ℓ1 norm is a minimizer while ``|G| \le \lambda_k``, or the
far bound of a box. Along a flat coordinate where this is unbounded below,
such as ``|G| > \lambda_k`` for the ℓ1 norm, ``F`` has no minimizer and the solver
raises an `ArgumentError`. Other penalties with a flat coordinate and nonzero
``G``, such as the elastic net, also raise an error; give the coordinate
positive curvature.

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
  loss along ``D`` and ``a`` its curvature along ``D``. A penalty on the
  matrix counts the entry twice, once in each triangle, so along the coordinate
  it is ``\mu\, g_{rc}(t)`` with ``\mu = 2`` (``\mu = 1`` on the diagonal),
  and

  ```math
  t^+ = \operatorname*{argmin}_t \; G\,(t - t_0) + \frac{a}{2}(t - t_0)^2 + \mu\, g_{rc}(t)
      = \operatorname{prox}_{\mu g_{rc}/a}\Big(t_0 - \frac{G}{a}\Big).
  ```

  The weights of a weighted ℓ1 norm are indexed like the full matrix and must
  be symmetric.
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

The paths of [`solve_path`](@ref) and the last level of continuation stop on
the gap by default, at [`PATH_GAPTOL`](@ref ProximalSolvers.PATH_GAPTOL)
`= 1e-4`; `gaptol = 1e-3` is the faster setting, for cross-validation and
prediction, and `gaptol = 0` gives back the rule on the changes with `tol`. A
single `solve!` keeps the rule on the changes unless `gaptol` is given, so
that a one-off solve stays as accurate as before.

The following historical empirical comparison covers 690 levels of ten lasso paths: the designs A–E
and L of the benchmark (``n = 500`` to ``5000``, ``p = 500`` to ``10^5``, 50
levels down to ``0.01\lambda_{\max}``) and the four AR(1) designs of
CoordinateDescent's `LassoPath` benchmark (``n = 200`` to ``1000``, ``p = 10^3``
to ``10^4``, 100 levels down to ``0.01\lambda_{\max}``, or ``10^{-4}\lambda_{\max}``
when ``n \ge p``). The coefficient error is ``\lVert\hat\beta -
\beta^\star\rVert_\infty / \lVert\beta^\star\rVert_\infty`` against a near-exact
reference, the suboptimality is relative, and the time is that of whole paths
against the rule on the changes, from an interleaved benchmark on one core of
an AMD EPYC 7513 (lasso and logistic paths, CoordinateDescent's `LassoPath`,
`CVLassoPath` and `GLMLassoPath`, neighborhood selection). glmnet 5.1 solved the same problems
(`standardize = FALSE`, `intercept = FALSE`) at its default `thresh = 1e-7`
and at `1e-10` and `1e-14`:

| relative gap ``\varepsilon`` | coefficient error, median / worst | suboptimality, median / worst | time against the rule on the changes | glmnet with about the same accuracy |
|:---|:---|:---|:---|:---|
| ``10^{-3}`` (fast) | ``7\times10^{-4}`` / ``2\times10^{-2}`` | ``7\times10^{-8}`` / ``2\times10^{-6}`` | 0.36 to 0.74 | more accurate than glmnet's default `thresh = 1e-7` (``3\times10^{-3}`` / ``0.5``) |
| ``10^{-4}`` (default) | ``7\times10^{-5}`` / ``5\times10^{-3}`` | ``6\times10^{-10}`` / ``10^{-7}`` | 0.59 to 0.96 (1.1 for a GLM path and 1.2 for a lasso path with ``n = p``) | `thresh = 1e-10` (``10^{-4}`` / ``5\times10^{-2}``) |
| ``10^{-6}`` | ``7\times10^{-7}`` / ``5\times10^{-5}`` | ``6\times10^{-14}`` / ``8\times10^{-12}`` | 0.97 to 1.56 | `thresh = 1e-14` (``10^{-6}`` / ``3\times10^{-3}``) |
| ``10^{-8}`` | ``7\times10^{-9}`` / ``4\times10^{-7}`` | below ``10^{-15}`` | 1.3 to 2.0 | beyond `thresh = 1e-14` |
| rule on the changes, `tol = 1e-7` (`gaptol = 0`) | ``9\times10^{-7}`` / ``2\times10^{-3}`` | ``10^{-13}`` / ``2\times10^{-7}`` | 1 | median as `thresh = 1e-14` |

In those measured workloads, the coefficients were within about ``\varepsilon`` of the solution, relative to
the largest, in the median over the levels, and **within about ``50\varepsilon``
at worst**. These are empirical errors against the chosen reference, not
universal consequences of a duality-gap target. The suboptimality is far below the certified bound ``\varepsilon``,
about ``\varepsilon^2``: the dual point of the rescaled gradient is off the
optimal one by about the error of the fitted values, which enters the gap
linearly (through the slack of the active constraints) and the suboptimality
quadratically. The gap means the same on every design and level, where the
rule on the changes is accurate on some levels and loose on others (its
coefficient error reached ``2\times10^{-3}`` and its gap ``2\times10^{-3}``). [`ProxNewton`](@ref) paths are faster at every target,
since their inner solves stop on the gap too (0.6 times the time at
``10^{-4}`` on a logistic path). glmnet at its default took 1 to 8 times less
time than these paths at ``10^{-4}`` (54 times less with ``n = p``), with
coefficients 9 to 60 times further from the solution in the median (400 times
with ``n = p``); at `thresh = 1e-10`, which matches ``10^{-4}`` in the median,
it took 0.5 to 8 times the time.

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
the two square-root losses. On HighDimensionalModels.jl's benchmark it makes lasso
paths 2.8 to 4.5 times faster and single solves at small penalties 1.3 to 2.2
times; on logistic lasso problems coordinate descent is 1.4 to 5.6 times
faster with it. `momentum = true` turns it on for any model on a
`SparseIterate` or a `SymmetricSparseIterate`, such as the Kronecker quadratic
(off by default: on vectorized matrices with two nonzero entries it was 1.1 to
1.2 times slower, while on the D-trace loss of a symmetric matrix it is up to
1.3 times faster). The cyclic order can stall with momentum, so it refuses
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
`AtomIterate`. On the lasso designs of the benchmark,
`CDSolver(; order = :cyclic, anderson = 5)` takes 1.6 to 2.6 times less time
than the cyclic order alone at ``0.02\lambda_{\max}``.

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
centered, and its coefficient goes to zero. The intercept is not available
with observation weights.

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
