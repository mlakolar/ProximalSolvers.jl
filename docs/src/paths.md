# Penalty paths and screening

A penalty with a level ``\lambda`` defines a family of problems, and the
solution is usually wanted along a decreasing sequence of levels, to choose
``\lambda`` by cross-validation or an information criterion.
[`solve_path`](@ref) computes it with warm starts and screening, and
`solve!(x, f, g, CDSolver(); continuation)` uses the same machinery to reach
one level.

## Penalty families

These penalties of ProximalBase have a level, and
`solve_path(f, g, λs)` replaces the level of `g` by each ``\lambda``; the
capped ℓ1 and log penalties have paths by local linear approximation (see
[Nonconvex penalties: exact steps or local linear approximation](@ref)):

| Penalty | ``g_\lambda(x)`` | weight of coordinate ``k`` |
|:--------|:-----------------|:---------------------------|
| `NormL1(λ, w)` | ``\lambda\sum_k w_k\lvert x_k\rvert`` | ``w_k`` |
| `NormL1Nonneg(λ, w)` | ``\lambda\sum_k w_k x_k`` on ``x \ge 0`` | ``w_k`` |
| `ElasticNet(λ, λ₂, w)` | ``\lambda\sum_k w_k\lvert x_k\rvert + \tfrac{\lambda_2}{2}\lVert x\rVert^2`` | ``w_k`` |
| `Scaled(ElasticNet(α, 1 - α, w), λ)` | ``\lambda\big(\alpha\sum_k w_k\lvert x_k\rvert + \tfrac{1 - \alpha}{2}\lVert x\rVert^2\big)`` | ``\alpha w_k`` |
| `MCP(λ, a)`, `SCAD(λ, a)` | nonconvex, with slope ``\lambda`` at zero | ``1`` |
| `GroupMCP(λ, groups, w; a)`, `GroupSCAD(λ, groups, w; a)` | MCP and SCAD of the group norms ``\lVert x_{G_k}\rVert_2``, with slope ``\lambda w_k`` at zero | ``w_k`` |
| `GroupNormL2(λ, groups, w)` | ``\lambda\sum_k w_k\lVert x_{G_k}\rVert_2`` | ``w_k`` |
| `Scaled(SparseGroupNormL2(α, 1 - α, groups, w), λ)` | ``\lambda\big(\alpha\lVert x\rVert_1 + (1 - \alpha)\sum_k w_k\lVert x_{G_k}\rVert_2\big)`` | see below |

In each, a coordinate at zero satisfies its slope condition (stationarity, for MCP and SCAD) while
the gradient of the loss over it is at most ``\lambda w_k`` in absolute value,
or in Euclidean norm for a group: the right derivative of every penalty at
zero is ``\lambda w_k``. A coordinate with ``w_k = 0`` is not penalized.

The level of `ElasticNet(λ, λ₂)` is ``\lambda``, with ``\lambda_2`` fixed. The
elastic-net path of glmnet at a fixed mixing ``\alpha`` moves both terms with
``\lambda``: it is the path of `Scaled(ElasticNet(α, 1 - α), λ)`, whose level is
the scale ``\lambda``.

The sparse group lasso of R's SGL and sparsegl fixes the mixture ``\alpha``
and moves both terms with ``\lambda``: it is the path of
`Scaled(SparseGroupNormL2(α, 1 - α, groups, w), λ)` on an
`AtomIterate(p, groups)`, whose level is the scale ``\lambda``; ``\alpha = 0`` is
the group lasso and ``\alpha = 1`` the lasso. A group at zero is optimal while

```math
\big\lVert \operatorname{soft}(\nabla_{G_k} f, \alpha\lambda)\big\rVert_2 \le (1 - \alpha)\lambda w_k ,
```

with ``\operatorname{soft}(v, c)_j = \operatorname{sign}(v_j)(|v_j| - c)_+``, a
condition that the norm of the gradient does not capture. The left side minus
the right is nonincreasing in ``\lambda``, so it holds from a root
``\lambda_k(\nabla_{G_k} f)`` on, and the root takes the place of
``\lVert\nabla_{G_k} f\rVert_2 / w_k`` below: ``\lambda_{\max}`` is the largest
root at zero, and screening compares the roots with the levels. Between the
breakpoints ``\alpha\lambda = |\nabla_j f|`` the squared norm of the
soft-thresholded gradient is a quadratic in ``\lambda``, so the root is exact:
Newton's method from zero, which never passes it on this convex function, finds
the right segment in a few steps, and the root of the quadratic there ends it.
A group with ``w_k = 0`` keeps its ``\ell_1`` term when ``\alpha > 0``. Applied to
a dual point instead of the gradient, the largest root is the dual norm of the
penalty, which builds the dual point of the duality gap and the gap-safe tests
of `CDSolver(; gaptol, gapsafe)` (Ndiaye, Fercoq, Gramfort and Salmon, 2016).

Each of the separable penalties can be restricted to a box,
`Constrained(g, IndBox(l, u))`, which has the level and the weights of `g`; zero
must be in the box, ``l \le 0 \le u``, as glmnet requires of its limits. A
coordinate at zero is then optimal while the part of the gradient that points
into the box is at most ``\lambda w_k``: ``(-\nabla_k f)_+`` if ``u_k > 0`` and
``(\nabla_k f)_+`` if ``l_k < 0``. ``\lambda_{\max}`` and the strong rule use
that part, so that ``\lambda_{\max}`` of the nonnegative lasso,
`Constrained(NormL1(λ), IndBox(0, Inf))`, is
``\max_k (-\nabla_k f(0))_+ / w_k``.

## The largest useful level

Zero minimizes ``f + g_\lambda`` exactly when every penalized coordinate
satisfies this condition at zero:

```math
\lambda_{\max} = \max_{k:\, w_k > 0} \frac{|\nabla_k f(0)|}{w_k}
\qquad\Big(\max_k \frac{\|\nabla_{G_k} f(0)\|_2}{w_k} \text{ for groups}\Big),
```

and ``\max_k \lambda_k(\nabla_{G_k} f(0))`` for the sparse group lasso.

[`lambda_max`](@ref)`(f, g, x)` computes it from the gradient at zero, for
iterates like `x`; for the lasso of ``\|y - X\beta\|^2/(2n)`` it is
``\|X^\top y\|_\infty/n``. With unpenalized coordinates the formula still uses
the gradient at zero, while the smallest level with all penalized
coordinates at zero would use the gradient at the fit of the unpenalized
ones. A common grid is geometric, from ``\lambda_{\max}`` down to
``\epsilon\lambda_{\max}`` with ``\epsilon`` between ``10^{-3}`` and ``10^{-1}``.

## Warm starts and the strong rule

Each level starts from the solution at the level before, which is close when
the levels are close. Screening also uses it to predict which coordinates stay
at zero. Let ``c_j(\lambda) = \nabla_j f(\hat x(\lambda))`` at the solution
``\hat x(\lambda)``. The sequential strong rule of Tibshirani et al. (2012)
leaves coordinate ``j`` out at the level ``\lambda_k`` when

```math
|c_j(\lambda_{k-1})| < (2\lambda_k - \lambda_{k-1})\, w_j .
```

The rule is exact if ``|c_j(\lambda) - c_j(\lambda')| \le w_j|\lambda - \lambda'|``
along the path: then
``|c_j(\lambda_k)| < (2\lambda_k - \lambda_{k-1})w_j + (\lambda_{k-1} - \lambda_k)w_j = \lambda_k w_j``,
and coordinate ``j`` is zero at ``\lambda_k``. For the sparse group lasso the
rule leaves group ``G`` out when its root is below ``2\lambda_k - \lambda_{k-1}``,
that is when
``\lVert\operatorname{soft}(c_G(\lambda_{k-1}), \alpha(2\lambda_k - \lambda_{k-1}))\rVert_2 < (1 - \alpha)(2\lambda_k - \lambda_{k-1})w_G``,
as in sparsegl, and the checks below use the condition of the previous
section. The condition often holds but can fail, so the rule is checked. At each level,

1. the strong set ``S`` holds the coordinates that pass the rule's threshold,
   ``|c_j(\lambda_{k-1})| \ge (2\lambda_k - \lambda_{k-1})w_j``, those that are
   nonzero, and the unpenalized ones;
2. coordinate descent solves the problem with its full passes over ``S``
   instead of all coordinates;
3. one full gradient checks the optimality condition
   ``|\nabla_j f(x)| \le \lambda_k w_j`` of every coordinate outside ``S``; the
   violators join ``S``, and step 2 runs again from the current solution.

The gradient computed in step 3 is the one the rule needs at the next level.

## The accuracy of each level

Each level stops on a certified relative duality gap,

```math
\frac{P_k(x) - D_k(\theta)}{|P_k(x)|} \le \mathrm{gaptol}, \qquad P_k = f + g_{\lambda_k},
```

when the loss and the penalty have one (see [Stopping on the duality
gap](@ref)): the default `gaptol` is [`PATH_GAPTOL`](@ref
ProximalSolvers.PATH_GAPTOL) `= 1e-4`. This bounds objective error when a certificate is available,
without a general coefficient-error guarantee. `gaptol = 1e-3` is a looser target for
cross-validation and prediction; `gaptol = 0` gives back the rule on the
changes. In step 2, coordinate descent
stops on the gap of the problem restricted to ``S``, the coordinates outside
held at zero, at the cost of one pass over ``S``, where the gap of the whole
problem reads every column. The full gradient of step 3 gives the gap of the
whole problem: without violators the two agree up to rounding, since the
coordinates outside ``S`` then satisfy their dual constraints; if it still
exceeds `gaptol`, step 2 runs again to a tenfold smaller target. The results
report this gap per level. [`ProxNewton`](@ref) paths stop their Newton steps
on the gap of the GLM in the same way, with each inner solve stopping on the
gap of its quadratic model at a hundredth of the current gap, and the
intercept, when the model has one, fitted exactly before each gap.

Other losses and penalties, a coordinate without penalty whose gradient is
not zero, [`LLA`](@ref) paths and `gaptol = 0` keep the rule on the changes of
[`CDSolver`](@ref), with its `tol`.
`solve_path` starts the rule at the ``\lambda_{\max}`` of its starting point,
which need not be zero. The results report, per level, the passes and the
number of checks: one when the strong rule made no mistake.

## Calling `solve_path`

`solve_path(f, g, λs, method = CDSolver(); x, screening = true, maxnnz = Inf, callback = nothing, gaptol)`
takes finite nonnegative levels in nonincreasing order; repeated levels and an
empty grid are allowed. The iterate `x` is the starting point and
holds the last solution on return; it defaults to a zero `SparseIterate` when
the loss has columns, and must be given otherwise, as an `AtomIterate` for a
group penalty or a `SymmetricSparseIterate` for a symmetric matrix. The path
stops early after the first solution with more than `maxnnz` nonzero
coordinates, or when `callback(k, λ, x, m)` returns `true`; `m` is the model of
the loss, current for `x`, from which a callback can compute a validation
error, residuals or a gradient. The [`PathResults`](@ref) hold, per level, the
level, the solution as a sparse vector (a sparse matrix for a matrix iterate),
the objective, the passes, whether coordinate descent converged, the number
of checks, and the certified relative gap (`NaN` where the rule on the changes
stopped the level).

## Continuation

`solve!(x, f, g, CDSolver(); continuation = K)` sets `x` to zero and solves at
the ``K + 1`` levels

```math
\lambda_j = \lambda_{\max}\Big(\frac{\lambda}{\lambda_{\max}}\Big)^{j/K}, \qquad j = 0, 1, \dots, K,
```

geometrically from ``\lambda_{\max}`` down to the level ``\lambda`` of `g`, each
warm started from the one before and screened as above (`screening = true`,
the default except on a `SymmetricSparseIterate`, where a coordinate step
changes the gradient everywhere, so that the checks cost more passes than they
save). The levels before `g` only provide warm starts, so they are solved to
the looser tolerance `continuation_tol`, ``\sqrt{\mathrm{tol}}`` by default,
by the rule on the changes, and only `g` itself to the final accuracy: a
relative gap of `gaptol` (`PATH_GAPTOL = 1e-4` by default) when the loss and
the penalty have one, `tol` otherwise; `continuation_tol = tol` solves every
level fully. It returns the solution at `g`. When the level of `g` is zero or at
least ``\lambda_{\max}``, or `g` has no level (`IndBox`, `ZeroFunction`), it
solves from zero directly.

On a convex problem both routes target the same minimum value; coefficient
vectors can differ when the minimizer is not unique. On the lasso design of
[A lasso path](examples/02_lasso_path.md), it took half the passes of a direct
solve from zero, or fewer, at ``0.01\lambda_{\max}``, and fewer at
``0.02\lambda_{\max}``, but more at ``0.05\lambda_{\max}`` and above, where the
direct solve is short anyway.

For MCP and SCAD it also changes the answer. From zero, coordinate descent can
stop at a poor stationary point when ``p \gg n`` and the columns are
correlated; along the levels, the solution follows a branch of stationary
points from the zero solution, as along a path. In
[Other penalties](examples/04_penalties.md), with MCP, it ends at less than
half the objective of the direct solve, with a far smaller estimation error.

## Nonconvex penalties: exact steps or local linear approximation

For a nonconvex penalty the algorithm decides which local solution is
reported, so recreating a published estimator means matching both its penalty
and its algorithm. Two kinds of algorithm compute nonconvex paths here.

**Exact coordinate steps.** `solve_path(f, MCP(1, a), λs)` and its relatives
(`SCAD`, `GroupMCP`, `GroupSCAD`) take each coordinate to the exact minimizer
of the loss along it plus the penalty, as ncvreg and grpreg do (Breheny and
Huang, 2011). λmax, the strong rule and the optimality checks all test a
coordinate at zero by the slope of the penalty there, ``|\nabla_k f| \le \lambda w_k``.
This test agrees with the coordinate step only when the coordinate problem is
convex:

```math
a L_k > 1 \ \text{(MCP)}, \qquad (a - 1) L_k > 1 \ \text{(SCAD)},
```

where ``L_k`` is the curvature of the step along coordinate ``k``: the
diagonal entry of the Hessian for a quadratic loss, the bound on the
curvature of a GLM, the largest eigenvalue of the Gram matrix of a group, and
on a `SymmetricSparseIterate` the curvature over the two entries of an
off-diagonal coordinate, divided by two. When it fails, the step can leave zero
where the test says that zero is optimal, so λmax is wrong and screening
changes the local solution. A path, and continuation, then throw an
`ArgumentError` that names the coordinate. With least squares,
``\|y - X\beta\|^2/(2n)`` on columns of unit variance has ``L_k = 1``, so that
ncvreg's conditions ``a > 1`` and ``a > 2`` suffice; logistic regression by
coordinate descent has ``L_k = 1/4`` on such columns, and MCP needs ``a > 4``.
Otherwise standardize the columns, take a larger ``a``, or use LLA. A single
solve does not use the test and is left alone. Paths of [`ProxNewton`](@ref),
whose curvatures change with the weights of the Newton steps, are not checked.

**Local linear approximation (LLA)**, also called reweighted ℓ1. The capped
ℓ1, log, MCP and SCAD penalties are ``\sum_k p_k(|x_k|)`` with each ``p_k``
concave and nondecreasing on ``[0, \infty)``, so they lie below their tangent at
the current solution. Each stage of LLA minimizes the loss plus the tangent: the
weighted lasso with the weights ``p_k'(|x_k|)`` of the previous stage, from
`ProximalBase.lla_weights!`, or the weighted group lasso with
``p_k'(\|x_{G_k}\|_2)`` for group MCP and SCAD. The slopes are taken from the
right, so that at zero they are ``p_k'(0+)`` and the first stage from zero is
the lasso. Each stage, solved exactly, decreases the loss plus the penalty
(majorization-minimization), and each is convex. The strong rule still needs full optimality rechecks;
gap-safe screening needs a valid dual certificate. The nonconvex-coordinate
curvature condition above does not apply to the weighted convex stages.

`solve_path(f, g, λs, LLA(CDSolver(); stages = 2, tol = 1e-12, start = :lasso))`
runs the stages at each level:

- **The first stage** is, with `start = :lasso`, the lasso with the weights
  ``p_k'(0)``, warm started from the lasso at the previous level, so that every
  level starts again from the lasso, as the papers do. With
  `start = :previous` it takes its weights from the solution at the previous
  level and starts from it, which follows the path more cheaply.
- **The later stages** start from the stage before. `stages` bounds their
  number, the first included, and they stop early once the weights change by
  at most `tol`, relative to the largest; the default `tol` is rounding.
- **Screening.** The first stage uses the strong rule for the step from the
  previous level. A later stage starts from the coordinates that are nonzero or
  violate their condition at the stage before: the weights change only on the
  nonzero coordinates, so the zero ones keep their condition. The optimality
  conditions are checked after every stage.
- **λmax** is that of the first stage, [`lambda_max`](@ref)`(f, g, x)`, which
  for `CappedL1(λ, a, w)` and `LogPenalty(λ, ε, w)` uses the slopes at zero,
  ``\lambda w_k`` and ``\lambda w_k/\varepsilon``.
- **The results** are [`PathResults`](@ref), whose `values` are the loss plus the
  nonconvex penalty, with the passes and checks summed over the stages and the
  number of `stages` at each level.

`solve!(x, f, g, LLA())` runs the stages at the level of `g`, the first with
the weights at `x`, and returns the [`ReweightResults`](@ref) of
[`reweight!`](@ref), on which it is built.

The papers, with their penalties as they define them, and the calls that
compute their estimators:

| Paper | Penalty | Algorithm | Call |
|:------|:--------|:----------|:-----|
| Zou and Li (2008) | SCAD | one LLA stage from an initial estimate | `solve!(x̃, f, SCAD(λ, 3.7), LLA(; stages = 1))` from the unpenalized fit `x̃` |
| Candès, Wakin and Boyd (2008) | ``\sum_k\log(|x_k| + \varepsilon)``, fixed ``\varepsilon`` | reweighted ℓ1 from the ℓ1 solution | `LogPenalty(λ, ε)` with `LLA(; stages = K)`, or many stages and a `tol` |
| T. Zhang (2010) | capped ℓ1, ``\lambda\min(|t|, a)``, fixed cap | multi-stage convex relaxation from the lasso | `solve_path(f, CappedL1(1, a), λs, LLA(; stages = 100))` |
| Shen, Pan and Zhu (2012) | truncated ℓ1 (TLP), ``\lambda\min(|t|/\tau, 1)``, fixed ``\tau`` | difference of convex functions, until the weights stop changing | `CappedL1(λ/τ, τ)`: the path of `CappedL1(1, τ)` at the levels `λs ./ τ`, with `LLA(; stages = 100)` |
| Fan, Xue and Zou (2014) | SCAD, MCP | two LLA stages from zero: the lasso, then one weighted lasso | `solve_path(f, SCAD(1, 3.7), λs, LLA())` |
| Breheny and Huang (2011) | MCP, SCAD, breakpoint ``a\lambda`` | coordinate descent with exact steps | `solve_path(f, MCP(1, 3), λs)` |

The exact steps for the capped ℓ1 and log penalties stay single-level solves: a
path from their coordinate steps would depend on the scale of ``X`` through
``L_k``, and no paper defines one that way.

## References

- R. Tibshirani, J. Bien, J. Friedman, T. Hastie, N. Simon, J. Taylor and
  R. Tibshirani. Strong Rules for Discarding Predictors in Lasso-type Problems.
  *Journal of the Royal Statistical Society B*, 74(2), 2012.
- N. Simon, J. Friedman, T. Hastie and R. Tibshirani. A Sparse-Group Lasso.
  *Journal of Computational and Graphical Statistics*, 22(2), 2013.
- E. Ndiaye, O. Fercoq, A. Gramfort and J. Salmon. GAP Safe Screening Rules
  for Sparse-Group Lasso. *Advances in Neural Information Processing Systems*
  29, 2016.
- J. Friedman, T. Hastie and R. Tibshirani. Regularization Paths for
  Generalized Linear Models via Coordinate Descent. *Journal of Statistical
  Software*, 33(1), 2010.
- P. Breheny and J. Huang. Coordinate Descent Algorithms for Nonconvex
  Penalized Regression, with Applications to Biological Feature Selection.
  *Annals of Applied Statistics*, 5(1), 2011.
- E. J. Candès, M. B. Wakin and S. P. Boyd. Enhancing Sparsity by Reweighted
  ℓ1 Minimization. *Journal of Fourier Analysis and Applications*, 14, 2008.
- H. Zou and R. Li. One-Step Sparse Estimates in Nonconcave Penalized
  Likelihood Models. *Annals of Statistics*, 36(4), 2008.
- T. Zhang. Analysis of Multi-stage Convex Relaxation for Sparse
  Regularization. *Journal of Machine Learning Research*, 11, 2010.
- X. Shen, W. Pan and Y. Zhu. Likelihood-Based Selection and Sharp Parameter
  Estimation. *Journal of the American Statistical Association*, 107(497),
  2012.
- J. Fan, L. Xue and H. Zou. Strong Oracle Optimality of Folded Concave
  Penalized Estimation. *Annals of Statistics*, 42(3), 2014.
