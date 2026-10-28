# Losses for coordinate descent

Coordinate descent needs, for coordinate ``k``, the derivative of the loss
along it and its curvature, and after a step the update of whatever it caches.
[`cdmodel`](@ref)`(f, x)` builds the [`CDModel`](@ref) of a loss of
ProximalBase, which holds the cache; [`solve!`](@ref) builds it on its own,
or takes one built beforehand so that many solves share it.

| Loss | Cache | Step | Penalties |
|:-----|:------|:-----|:----------|
| `LeastSquaresLoss(y, X)`, `GLMLoss(Squared(), y, X; weights, offset)` | residuals ``y - o - X\beta`` | ``O(n)`` | separable, group penalties |
| `LeastSquaresLoss(Y, X)` with a matrix `Y` | residuals ``Y - XB`` | ``O(nq)`` per row of ``B``, exact | `GroupNormL2` on the rows of ``B`` |
| `QuadraticFunction(A, b)` | ``Ax`` | ``O(p)`` dense, ``O(\operatorname{nnz}(A_{:k}))`` sparse, ``O(1)`` diagonal | separable, group penalties |
| `KronQuadratic(A, B, C)` | ``A\Theta B`` | ``O(pq)`` | separable |
| `GLMLoss` with `Logistic` or `Huber` | ``\eta = X\beta + o`` | ``O(n)`` | separable |
| [`SqrtLeastSquaresLoss`](@ref)`(y, X)` | residuals | ``O(n)``, exact | `NormL1` |
| [`SqrtQuadraticFunction`](@ref)`(A, b, c)` | ``Ax`` and the quadratic | ``O(p)``, exact | `NormL1` |

The first four may be scaled, as in `(1/n) * LeastSquaresLoss(y, X)`, which
the formulas below write as a factor ``s``.

## Least squares

For ``f(\beta) = \frac{s}{2}\sum_i w_i (y_i - o_i - x_i^\top\beta)^2``, with
observation weights ``w_i`` and an offset ``o`` (both optional), the model
caches the residuals ``r = y - o - X\beta``. Along coordinate ``k``,

```math
\partial_k f(\beta) = -s \sum_i w_i X_{ik} r_i, \qquad a_k = s \sum_i w_i X_{ik}^2,
```

so the step is
``\beta_k^+ = \operatorname{prox}_{g_k/a_k}\big(\beta_k + \sum_i w_i X_{ik} r_i / \sum_i w_i X_{ik}^2\big)``,
followed by ``r \leftarrow r - (\beta_k^+ - \beta_k) X_k``. Both cost ``O(n)``,
and a coordinate that does not move costs only the inner product. The
curvatures are computed on the first visit to each coordinate and cached. The
gradient that screening and paths need is ``-s X^\top W r``, one product with
``X^\top``. With `intercept = true` the columns and the response are centered
on the fly; see [Coordinate descent](@ref "An unpenalized intercept").

## The multi-response lasso

For an ``n \times q`` response matrix ``Y``,
``f(B) = \frac{s}{2}\lVert Y - 1\beta_0^\top - XB\rVert_F^2`` with a
``p \times q`` matrix ``B``, iterated as an `AtomIterate` over `vec(B)` whose
groups are the rows of ``B``, `[k:p:p*q for k in 1:p]`. With `GroupNormL2` on
these groups it is the multi-response lasso, which selects the same predictors
for all the responses. The model caches the residuals
``R = Y - 1\beta_0^\top - XB``. The curvature of the loss over row ``k`` is
exactly ``s\lVert X_k - \bar x_k\rVert^2`` times the identity, so each block
step minimizes the loss plus the penalty over the row exactly, at a cost of
``O(nq)``. With an intercept, ``\beta_0 = \bar y - B^\top\bar x`` for each
response, and [`intercept`](@ref ProximalSolvers.intercept) returns the vector
of them.

## Quadratics

For ``f(x) = s\,(\tfrac12 x^\top A x + b^\top x + c)`` with ``A`` symmetric
positive semidefinite, the model caches ``u = Ax``:

```math
\partial_k f(x) = s\,(u_k + b_k), \qquad a_k = s A_{kk}, \qquad
u \leftarrow u + (x_k^+ - x_k)\, A_{:k},
```

an ``O(p)`` step for a dense ``A``. A `SparseMatrixCSC` is kept sparse and its
update visits only the stored entries of column ``k``; a `Diagonal` updates
only ``u_k``. These floating-point matrices are shared with the loss, so a new
solve or `initialize!` sees changes made to them in place. A sparse `Symmetric`
wrapper is copied into a full sparse matrix once. Refits form a dense Hessian
only on the selected support.

With ``A = X^\top X/n`` and ``b = -X^\top y/n`` this is the
lasso of ``\|y - X\beta\|^2/(2n)`` up to a constant, at a cost per step
independent of ``n``: the form to use when ``n \gg p``, or when many problems
share one Gram matrix, as the columns of a covariance matrix do.

## Kronecker quadratics

[`KronQuadratic`](@extref ProximalBase.KronQuadratic)`(A, B, C)` is the
quadratic of a ``p \times q`` matrix ``\Theta``,

```math
f(\Theta) = s\Big(\tfrac12\langle\Theta, A\Theta B\rangle + \langle C, \Theta\rangle\Big)
= s\Big(\tfrac12\operatorname{vec}(\Theta)^\top (B\otimes A)\operatorname{vec}(\Theta) + \operatorname{vec}(C)^\top \operatorname{vec}(\Theta)\Big),
```

for symmetric positive semidefinite ``A`` and ``B``. The model caches
``M = A\Theta B`` and never forms the ``pq \times pq`` matrix ``B \otimes A``.

**Entries of ``\Theta``** (a `SparseIterate` holding ``\Theta`` or
``\operatorname{vec}\Theta``). Along the entry ``(r, c)``,

```math
\partial_{rc} f = s\,(M_{rc} + C_{rc}), \qquad a_{rc} = s A_{rr} B_{cc}, \qquad
M \leftarrow M + h\, A_{:r} B_{c:},
```

a rank-one update in ``O(pq)`` for a change ``h``.

**A symmetric ``\Theta``** (a `SymmetricSparseIterate`). An off-diagonal
coordinate ``(r, c)`` moves along ``D = E_{rc} + E_{cr}``. The derivative along
``D`` is ``s\langle D, A\Theta B + C\rangle``, and the curvature is
``s\langle D, ADB\rangle``. With
``\langle e_i e_j^\top, A\, e_k e_l^\top B\rangle = A_{ik} B_{jl}`` for
symmetric ``A`` and ``B``, the four terms of ``\langle D, ADB\rangle`` give

```math
\partial_{rc} f = s\,(M_{rc} + M_{cr} + C_{rc} + C_{cr}), \qquad
a_{rc} = s\,(A_{rr} B_{cc} + A_{cc} B_{rr} + 2 A_{rc} B_{rc}),
```

and the update is the rank-two ``M \leftarrow M + h\,(A_{:r} B_{c:} + A_{:c} B_{r:})``.
A diagonal coordinate is an entry as above. The step then follows
[Coordinates of the iterates](@ref), with the penalty counted twice off the
diagonal. The gradient over symmetric matrices, which screening uses, is
``s\big(\tfrac12(M + M^\top) + \tfrac12(C + C^\top)\big)``.

*The D-trace loss.* For two covariance matrices,
`KronQuadratic(Σx, Σy, Σx - Σy)` is
``\tfrac12\operatorname{tr}(\Sigma_x\Delta\Sigma_y\Delta) - \operatorname{tr}(\Delta(\Sigma_y - \Sigma_x))``,
whose gradient vanishes at ``\Delta = \Sigma_x^{-1} - \Sigma_y^{-1}`` (Zhao, Cai
and Li, 2014): with an ℓ1 penalty it estimates the difference of two
precision matrices directly. The inverse Hessians of DiffPrecTest.jl are
Kronecker quadratics on ``\operatorname{vec}\Theta`` too.

## Generalized linear losses

For ``f(\beta) = s\sum_i w_i\,\ell(\eta_i, y_i)`` with ``\eta = X\beta + o``,
the model caches ``\eta``. A scalar loss whose curvature is bounded,
``\ell'' \le \bar\ell``, gives the majorization step of
[Coordinate descent](@ref "The coordinate step") with

```math
\partial_k f(\beta) = s\sum_i w_i\,\ell'(\eta_i, y_i)\, X_{ik}, \qquad
a_k = s\,\bar\ell \sum_i w_i X_{ik}^2, \qquad
\eta \leftarrow \eta + (\beta_k^+ - \beta_k)\, X_k .
```

The bound is ``\bar\ell = 1/4`` for the logistic loss
``\log(1 + e^\eta) - y\eta``, whose curvature is ``\sigma(\eta)(1 - \sigma(\eta))``,
and ``\bar\ell = 1`` for the Huber loss. A step evaluates ``\ell'`` at every
observation, and the bound is far above the curvature where the fitted
probabilities are near 0 or 1, so the steps are short. [`ProxNewton`](@ref)
uses the curvature at the current point instead; its relative cost depends on
the problem and required accuracy. It also handles the Poisson loss ``e^\eta - y\eta``, whose curvature is
unbounded and which coordinate descent therefore refuses.

## The square-root lasso

[`SqrtLeastSquaresLoss`](@ref)`(y, X)` is ``f(\beta) = \|y - X\beta\|``, the loss
of the square-root lasso (Belloni, Chernozhukov and Wang, 2011). Its penalty
level does not depend on the noise level, since the gradient at the true
coefficients, ``-X^\top\varepsilon/\|\varepsilon\|``, does not depend on the scale
of the noise ``\varepsilon``. The loss is not differentiable where the residuals
vanish, so coordinate descent does not take a majorization step but
minimizes ``f + \lambda\sum_k w_k|\beta_k|`` exactly over each coordinate.

At zero residual the loss is not differentiable and couples the coordinates,
and near an exact fit its curvature along a coordinate, about ``1/\|r\|``, is
far larger than the scale of the stopping rule. Coordinate steps can then stop
far from the minimizer: with ``p \ge n`` and a small penalty, at several times
the minimum. The solver therefore accepts a stop only with a duality gap. With
``\nabla f(\beta) = -X^\top r/\|r\|``, the point ``\theta = t\,r/\|r\|`` with the
largest ``t \le 1`` such that ``\|X^\top\theta\|_\infty \le \lambda`` (weighted
by ``w_k``) is dual feasible, with dual value ``y^\top\theta = t(f(\beta) - \nabla f(\beta)^\top\beta)``.
A run converges when the relative gap ``(P - D)/P`` is at most `gaptol`, or
`1e-4` by default, and the results report it as `gap`. This check runs after
every coordinate-descent run, including path and continuation levels, workspace
reuse and an exhausted pass budget. A small gap does not override an exhausted
budget. The residual direction is tried first, preserving ordinary fits that
already certify.

If that direction does not certify, let ``S`` contain the nonzero coordinates
and every unpenalized coordinate (zero penalty weight or level). With centered
design ``\widetilde X``, observation weights ``W`` and residual ``R``, set
``K = \widetilde X_S^\top W\widetilde X_S``,
``s = \widetilde X_S^\top WR`` and support targets
``c_k = \lambda_k\operatorname{sign}(x_k)`` on nonzero penalized coordinates,
zero on unpenalized coordinates. A rank-revealing solve gives
``\alpha \approx K^+c`` and ``\gamma \approx K^+s``. The joint witness is

```math
\theta = \widetilde X_S\alpha + \beta(R - \widetilde X_S\gamma),\qquad \beta\ge 0.
```

Its actual norm, including the cross term, determines ``\beta``. Scaling then
enforces the norm and penalized constraints. Unpenalized columns and the
intercept require equalities, which are checked to rounding on the scale of
the column norm times the dual norm. The residuals, all products and the dual
value are computed from the constructed vector in weighted observation space,
including zero observation weights and sparse centering shifts. The best
validated dual value is used. If neither candidate is valid, ``\theta=0``
gives a gap of one for a positive objective; coordinate changes alone never
accept a run. A zero objective is certified. The same construction applies to
`SqrtQuadraticFunction`. These losses still do not support the public
`duality_gap` interface or gap-safe screening.

The support has at most 2000 coordinates, including unpenalized ones, and
does not need ``|S|\le n`` or full rank. Factorization buffers grow with the
support and are retained for later runs. At an exact fit, satisfying the
support equations makes the dual value equal to the penalty. Certification
therefore succeeds when these equations determine the dual point or their
least-norm solution satisfies all remaining constraints. This construction
can miss other feasible points. For example, with
``X=[1\ 2;\ 0\ 1]``, ``y=(1,0)``, ``x=(1,0)`` and ``\lambda=0.1``,
``\theta=(0.1,-0.1)`` certifies optimality, but the least-norm support point
needs scaling and reports a gap of ``1/2`` and `converged = false`.
Joint coordinate moves and refinement of this support point are not provided.

An infinite or `NaN` penalty loading fixes the corresponding coordinate at
zero in the coordinate steps and excludes it from the dual constraints. This
includes a zero level times an infinite weight. The certificate follows that
convention; it does not resolve the differing interpretation of ``0\cdot\infty``
in the penalty's value function.

Fix every coordinate but ``k``. With the partial residual
``r = y - X\beta + X_k\beta_k`` and ``x = X_k``, let ``a = \|x\|^2``,
``\sigma = x^\top r`` and ``\rho = \|r\|^2``, and write ``\lambda_k = \lambda w_k``. The
coordinate problem is

```math
\min_t\ \varphi(t) = \sqrt{\rho - 2\sigma t + a t^2} + \lambda_k |t| .
```

``\varphi`` is convex, and its subdifferential at zero is
``-\sigma/\sqrt\rho + [-\lambda_k, \lambda_k]``, so ``t = 0`` is the minimizer
exactly when ``|\sigma| \le \lambda_k\sqrt\rho``. Otherwise the minimizer has the
sign of ``\sigma``. Write the quadratic as ``a(t - \sigma/a)^2 + d`` with
``d = \rho - \sigma^2/a \ge 0`` (by the Cauchy–Schwarz inequality), and
``u = t - \sigma/a``. Setting ``\varphi'(t) = 0`` gives

```math
a u = -\lambda_k \operatorname{sign}(\sigma)\sqrt{a u^2 + d}
\quad\Longrightarrow\quad
u^2\,(a^2 - \lambda_k^2 a) = \lambda_k^2 d ,
```

which has a solution only if ``\lambda_k^2 < a``; this holds, because
``\lambda_k^2\rho < \sigma^2 \le a\rho``. Taking the root with the sign of
``-\sigma``,

```math
t^\star = \frac{1}{a}\left(\sigma - \operatorname{sign}(\sigma)\,\lambda_k\sqrt{\frac{\rho - \sigma^2/a}{1 - \lambda_k^2/a}}\right),
```

which has the sign of ``\sigma`` exactly when ``\sigma^2 > \lambda_k^2\rho``. A step
costs ``O(n)``: two inner products and the update of the residuals. Rounding
can break ``\lambda_k^2 < a`` when ``r`` is nearly parallel to ``x``, and the
code then sets the coordinate to zero.

## The square root of a quadratic

[`SqrtQuadraticFunction`](@ref)`(A, b, c)` is
``f(x) = \sqrt{q(x)}``, ``q(x) = x^\top A x + 2b^\top x + c``, for symmetric
positive semidefinite augmented matrix ``[A\ {-b};\ {-b}^\top\ c]``, so
``q \ge 0``. With ``A = X^\top X/n``,
``b = -X^\top y/n`` and ``c = y^\top y/n`` it is ``\|y - Xx\|/\sqrt n``: the
square-root lasso from sufficient statistics. With ``x_k = t`` and the other
coordinates fixed,

```math
q = q_0 - 2\sigma t + a t^2, \qquad a = A_{kk}, \qquad
\sigma = a x_k - (Ax + b)_k, \qquad q_0 = q(x) - x_k\big(2(Ax + b)_k - a x_k\big),
```

the form of the square-root lasso with ``\rho = q_0``, so the same closed form
gives the step. The model caches ``u = Ax``, updated in ``O(p)``, and the value
``q``. Certification recomputes both, independently of these caches. Its
first-order rounding budget is
``64m\operatorname{eps}(T)(|x|^\top|A||x|+2|b|^\top|x|+|c|)``, with
``m=\max(1,\operatorname{nnz}(x))``. Products in the joint witness have
corresponding budgets for their vector or matrix sums.
Compensated accumulation tightens this bound near cancellation, retaining
exact binary fits. The upper loss and dual norm bounds make the reported gap
conservative up to rounding. The gap also covers a larger cached objective
reported in the results. A quadratic negative beyond its budget violates the
model's PSD assumption and cannot be certified. The support solve discards eigenvalues
at most ``8|S|\operatorname{eps}(T)\|K\|_2``; all constraints and the dual
value are still checked using the resulting coefficients and their cross terms.
An infinite weight keeps a coordinate at zero. With ``A = S``,
``b = -S_{:j}`` and ``c = S_{jj}`` for a covariance matrix ``S``, and an
infinite weight on coordinate ``j``, the loss is
``\|Z_j - Z x\|/\sqrt n`` for the data ``Z`` behind ``S``: the scaled lasso of
variable ``j`` on the others, from which Sun and Zhang (2013) build a sparse
precision matrix estimator, column by column.

## References

- A. Belloni, V. Chernozhukov and L. Wang. Square-Root Lasso: Pivotal Recovery
  of Sparse Signals via Conic Programming. *Biometrika*, 98(4), 2011.
- T. Sun and C.-H. Zhang. Sparse Matrix Inversion with Scaled Lasso. *Journal
  of Machine Learning Research*, 14, 2013.
- S. D. Zhao, T. T. Cai and H. Li. Direct Estimation of Differential Networks.
  *Biometrika*, 101(2), 2014.
