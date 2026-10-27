# Reweighting and refitting

Many estimators are a sequence of penalized fits: the scaled lasso estimates
the noise level with the coefficients, the adaptive lasso reweights the
penalty from a first fit, and a least squares refit on the selected support
removes the shrinkage of the penalty. [`reweight!`](@ref) and [`refit!`](@ref)
run these on one model of the loss, warm started from the previous solution.

## Reweighting

`reweight!(x, f, g, update, method = CDSolver(); maxiter = 20, tol = 1e-2)`
alternates

```math
x^{(t)} = \operatorname*{argmin}_x\ f(x) + g^{(t)}(x), \qquad
\big(g^{(t+1)}, \delta_t\big) = \texttt{update}\big(g^{(t)}, x^{(t)}, m\big),
```

with each solve warm started from the previous solution, and stops when the
change ``\delta_t`` reported by `update` is below `tol`, or after `maxiter`
solves. The model `m` is current for ``x^{(t)}``, so `update` can read the
residuals ([`residuals`](@ref ProximalSolvers.residuals)`(m)` for least
squares) or the gradient without recomputing them. The
[`ReweightResults`](@ref) hold the last penalty, the next one that `update`
proposed, and whether the change fell below `tol`.

### The scaled lasso

The scaled lasso (Sun and Zhang, 2012) estimates the coefficients and the
noise level together:

```math
\min_{\beta,\ \sigma > 0}\ \frac{\|y - X\beta\|^2}{2n\sigma} + \frac{\sigma}{2} + \lambda_0\|\beta\|_1 .
```

The objective is jointly convex in ``(\beta, \sigma)``: its first term is the
perspective of a convex quadratic. For a fixed ``\sigma``, multiplying by
``\sigma`` shows that ``\beta`` solves the lasso of ``\|y - X\beta\|^2/(2n)``
with level ``\lambda_0\sigma``; for a fixed ``\beta``, the minimizer is
``\sigma = \|y - X\beta\|/\sqrt n``. Alternating the two, with
`update = (g, x, m) -> (σ = norm(residuals(m)) / sqrt(n); (NormL1(λ₀ * σ), change))`,
decreases the objective at every step. At the fixed point,

```math
\frac{X^\top(y - X\beta)}{n} \in \lambda_0\,\frac{\|y - X\beta\|}{\sqrt n}\ \partial\|\beta\|_1 ,
```

which is the optimality condition of the square-root lasso
``\|y - X\beta\|/\sqrt n + \lambda_0\|\beta\|_1``: the two formulations coincide when the residual norm is positive.
[`SqrtLeastSquaresLoss`](@ref) targets this coefficient problem directly,
subject to its documented certificate and exact-fit limitations.

### Weights from a first fit

The adaptive lasso (Zou, 2006) penalizes coefficient ``k`` by
``\lambda w_k`` with ``w_k = 1/|\tilde\beta_k|`` from a first estimate
``\tilde\beta``: large coefficients are penalized little, and those at zero in
``\tilde\beta`` get an infinite weight and stay at zero. Two solves with one
update are `maxiter = 2, tol = 0`. When the weights are expensive, a two-stage
estimator can instead build the model once, `m = cdmodel(f, x)`, and call
`solve!(x, m, g, CDSolver())` for each penalty.

### Concave penalties by reweighted ℓ1

For a concave, nondecreasing ``\rho`` on ``[0, \infty)``, the penalty
``\sum_k \rho(|\beta_k|)`` lies below its tangent at the current ``\beta``,

```math
\rho(|t|) \le \rho(|\beta_k|) + \rho'(|\beta_k|)\,\big(|t| - |\beta_k|\big),
```

a weighted ℓ1 norm with weights ``\rho'(|\beta_k|)`` plus a constant.
Minimizing ``f`` plus the tangent, then updating the weights, is a
majorization-minimization algorithm, and decreases ``f + \sum_k\rho(|\beta_k|)``
at every step (Candès, Wakin and Boyd, 2008; Zou and Li, 2008). For
``\rho(t) = \lambda\varepsilon\log(1 + t/\varepsilon)``, the weights are
``\lambda/(1 + |\beta_k|/\varepsilon)``; the
[post-lasso example](examples/08_refit_and_reweight.md) runs it to convergence.
For the penalties of ProximalBase (`CappedL1`, `LogPenalty`, `MCP`, `SCAD` and
the group versions), [`LLA`](@ref) runs these stages, with the weights of
`ProximalBase.lla_weights!`: `solve!(x, f, g, LLA())` at one level, through
`reweight!`, and `solve_path(f, g, λs, LLA())` along a path, with screening in
every stage (see
[Nonconvex penalties: exact steps or local linear approximation](@ref)).

### Penalty loadings

The lasso with data-driven penalty loadings (Belloni, Chen, Chernozhukov and
Hansen, 2012), for heteroscedastic noise, weights coefficient ``k`` by
``\psi_k = (\sum_i X_{ik}^2 r_i^2/n)^{1/2}``, and recomputes the loadings from
the residuals ``r`` of the latest fit, for a few iterations. They take the
residuals of the least squares refit on the selected support, since the
shrinkage of the lasso inflates its own residuals, and with them the loadings.

## Refitting

`refit!(x, f; support)` minimizes the loss over the vectors supported on
``S``, by default the nonzero coordinates of `x`:

```math
x \leftarrow \operatorname*{argmin}\ \{f(z) : z_j = 0 \text{ for } j \notin S\}.
```

Coordinates outside ``S`` are zeroed before fitting, including when ``S`` is
empty. After a lasso fit this is the post-lasso estimator (Belloni and
Chernozhukov, 2013), which removes the shrinkage of the penalty.

- **Least squares.** With the residuals ``r`` of the current fit, the step
  ``\delta`` on ``S`` solves ``\min_\delta \|W^{1/2}(r - X_S\delta)\|`` by a
  QR factorization with column pivoting of ``W^{1/2}X_S`` (the columns
  centered when the model fits an intercept, whose value then follows from
  ``\bar y - \bar x^\top\beta``). When ``X_S`` has deficient rank, it returns
  a basic solution.
- **Quadratics.** For the other quadratic losses, the step is the Newton
  step on ``S``, ``\delta = -H_{SS}^{-1}\nabla_S f(x)``, which is exact. The
  Hessian is ``sA_{SS}`` for a quadratic, and
  ``s\,A_{r r'}B_{c c'}`` between the entries ``(r, c)`` and ``(r', c')`` of a
  Kronecker quadratic. On a symmetric matrix, the Hessian between the
  coordinates ``(r, c)`` and ``(u, v)`` is ``s\langle D_{rc}, A D_{uv} B\rangle``,
  with ``D_{rc} = E_{rc} + E_{cr}`` off the diagonal and ``E_{rr}`` on it, a sum
  of up to four products ``A_{\cdot\cdot}B_{\cdot\cdot}``. For a model of
  another quadratic loss, the Hessian is built column by column from the
  change of the derivatives after a unit step on each coordinate. The linear
  system is solved by a pivoted QR factorization, which also handles a singular
  ``H_{SS}``.

**Refits along a path of supports.** `refit!(x, f; support, cache)` with a
[`RefitCache`](@ref) keeps the Cholesky factor ``R^\top R = H_{SS}`` of least
squares and of `QuadraticFunction` between calls, and a refit of the same `f`
on a support that differs by a few coordinates updates the factor instead of
computing it again. A coordinate that enters borders the factor, at the cost of
a column of the Hessian and a triangular solve; one that leaves is removed by
Givens rotations in ``O(|S|^2)``. The step is then
``\delta = -H_{SS}^{-1}\nabla_S f(x)`` from two triangular solves. When many
coordinates change the cache factors again, and when an entering coordinate is
nearly a combination of the others it falls back to the pivoted QR
factorization above.

## References

- A. Belloni, D. Chen, V. Chernozhukov and C. Hansen. Sparse Models and
  Methods for Optimal Instruments with an Application to Eminent Domain.
  *Econometrica*, 80(6), 2012.
- A. Belloni and V. Chernozhukov. Least Squares after Model Selection in
  High-Dimensional Sparse Models. *Bernoulli*, 19(2), 2013.
- E. Candès, M. Wakin and S. Boyd. Enhancing Sparsity by Reweighted ℓ1
  Minimization. *Journal of Fourier Analysis and Applications*, 14, 2008.
- T. Sun and C.-H. Zhang. Scaled Sparse Linear Regression. *Biometrika*,
  99(4), 2012.
- H. Zou. The Adaptive Lasso and Its Oracle Properties. *Journal of the
  American Statistical Association*, 101(476), 2006.
- H. Zou and R. Li. One-Step Sparse Estimates in Nonconcave Penalized
  Likelihood Models. *Annals of Statistics*, 36(4), 2008.

Explicit `support` indices must be unique and valid. Entries outside that
support are zeroed before fitting, including for an empty support. A cached
factor is valid for one unchanged loss or model; create a new cache after
changing data, weights, centering or scales, even when dimensions agree.
