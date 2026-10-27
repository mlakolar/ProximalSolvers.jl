# Proximal Newton

[`ProxNewton`](@ref) fits penalized generalized linear models,

```math
F(\beta) = s\sum_i w_i\,\ell(\eta_i, y_i) + g(\beta), \qquad \eta = X\beta + o,
```

for a `GLMLoss` of ProximalBase (logistic, Poisson, Huber, or one of your own)
and a separable penalty ``g``, as glmnet does (Friedman, Hastie and Tibshirani,
2010). Each step minimizes a quadratic model of the loss plus the penalty by
coordinate descent, and a line search on ``F`` makes sure the objective
decreases. It also solves the graphical lasso, by QUIC; see
[The graphical lasso by QUIC](@ref).

## The quadratic model

Expand each term of the loss to second order in the linear predictor around
the current ``\eta``:

```math
\ell(\eta_i', y_i) \approx \ell(\eta_i, y_i) + \ell'(\eta_i, y_i)(\eta_i' - \eta_i) + \tfrac12 \ell''(\eta_i, y_i)(\eta_i' - \eta_i)^2
= \tfrac12\, \ell''(\eta_i, y_i)\,(z_i - \eta_i')^2 + \text{const},
```

with the working response ``z_i = \eta_i - \ell'(\eta_i, y_i)/\ell''(\eta_i, y_i)``.
With ``\eta' = X\beta' + o``, the model of the loss is the weighted least
squares loss

```math
\frac{s}{2}\sum_i v_i\,\big(z_i - o_i - x_i^\top\beta'\big)^2, \qquad v_i = w_i\,\ell''(\eta_i, y_i),
```

the iteratively reweighted least squares of generalized linear models, with
the curvatures floored at ``\sqrt{\varepsilon}`` so that the working responses
stay finite. For the logistic loss ``\log(1 + e^\eta) - y\eta``,
``\ell' = \sigma(\eta) - y`` and ``\ell'' = \sigma(\eta)(1 - \sigma(\eta))``,
with ``\sigma`` the logistic function; for the Poisson loss ``e^\eta - y\eta``,
``\ell' = e^\eta - y`` and ``\ell'' = e^\eta``.

## A step

1. Compute the weights ``v`` and the working responses ``z`` at the current
   ``\beta``, and update the least squares model in place.
2. Minimize the model plus ``g`` by coordinate descent (`inner`, a
   [`CDSolver`](@ref)), warm started from ``\beta``, which gives ``\hat\beta``.
   The linear predictor ``\hat\eta = X\hat\beta + o`` comes from the residuals of
   the model, without a product by ``X``.
3. Backtrack along ``d = \hat\beta - \beta``: try ``t = 1, \beta_{\text{ls}}, \beta_{\text{ls}}^2, \dots``
   and accept the first ``t`` with
   ``F(\beta + t d) \le F(\beta) + 10\,\varepsilon|F(\beta)|``, where
   ``\eta + t(\hat\eta - \eta)`` gives the loss without a product by ``X``. If
   ``t`` falls below ``10^{-10}``, the step is abandoned and ``\beta`` kept.

The method stops when ``|F(\beta) - F(\beta^+)| \le \mathrm{tol}\cdot\max\{|F(\beta^+)|, 1\}``,
and the original problem is stationary to the matching accuracy. Each exact
coordinate step ``\Delta_j`` of ``F`` at ``\beta``, with the curvature
``a_j`` of the Newton model there, must satisfy
``\sqrt{a_j}\,|\Delta_j| \le \sqrt{\mathrm{tol}}\, S``; the intercept is checked the
same way when fitted. The reference scale is

```math
S^2 = s\sum_i w_i\frac{\ell'(o_i,y_i)^2}{\max\{\ell''(o_i,y_i),\mathrm{floor}\}}.
```

If all offset scores vanish, the reference is ``S^2=s\sum_i w_i`` instead.
Both sides scale by the square root of a positive scale applied to the loss
and penalty, so the test is invariant to that scaling and to additive loss
constants. The square root of `tol` compares squared coordinate-step measures
in loss units; this is a stopping criterion, not a bound on objective or
coefficient error.
A rejected or stagnant nonstationary step is not convergence. The iteration
limit is `maxiter`. For a convex loss and penalty, and with the
quadratic model strongly convex, ``d`` is a descent direction of ``F`` unless
``\beta`` is a minimizer, and with exact inner solves the method converges,
superlinearly near the solution (Lee, Sun and Saunders, 2014).

## Cost of a Newton step

Coordinate descent on the loss itself ([Losses for coordinate descent](@ref))
uses a global bound on the curvature, ``\sup\ell''``, which for the logistic
loss is ``1/4`` and is far above ``\ell''(\eta_i)`` wherever the fitted
probabilities are close to 0 or 1: its steps are short. It also evaluates
``\ell'`` at every observation in every coordinate step. The quadratic model
uses the curvature at the current point, and its coordinate steps are those of
weighted least squares, which cost ``O(n)`` multiplications without
evaluating the loss. The balance between outer iterations and inner work depends on the data and
accuracy target. Poisson has unbounded curvature, so the direct GLM coordinate
method is unavailable; proximal Newton and gradient methods with backtracking
remain alternatives.

## Intercepts and paths

For a logistic or Poisson loss, `ProxNewton` takes an unpenalized intercept
through the model (`cdmodel(f, x; intercept = true)`), and [`solve_path`](@ref)
takes `ProxNewton` with the same sequential strong rule as coordinate descent.
The path also stops once the fit explains a fraction `devmax = 0.999` of the
null deviance, as glmnet's does:

```julia
yb = Float64.(y .> 0)                                    # binary responses
m = ProximalSolvers.cdmodel((1 / n) * LogisticLoss(yb, X), SparseIterate(p); intercept = true)
λmax = lambda_max(m, NormL1(1.0), SparseIterate(p))      # at the fit with only the intercept
b0 = Float64[]                                           # the intercepts along the path
path = solve_path(m, NormL1(1.0), λmax .* 10 .^ range(0, -2; length = 50), ProxNewton();
                  callback = (k, λ, β, m) -> (push!(b0, ProximalSolvers.intercept(m, β)); false))
```

## The graphical lasso by QUIC

For the graphical lasso,

```math
F(X) = w\big(\operatorname{tr}(SX) - \log\det X\big) + \sum_{ij}\lambda_{ij}\lvert X_{ij}\rvert,
```

`f` a `LogDetLoss(S, w)` (or a scaled one) and `g` a `NormL1` (a matrix of
weights can leave the diagonal free), `ProxNewton` is QUIC (Hsieh, Sustik,
Dhillon and Ravikumar, 2014), on a `SymmetricSparseIterate` or a dense
symmetric matrix. With ``W = X^{-1}``, the step ``\Delta`` minimizes the
second-order model

```math
w\Big(\tfrac12\operatorname{tr}(W\Delta W\Delta) + \operatorname{tr}\big((S - W)\Delta\big)\Big) + g(X + \Delta)
```

by coordinate descent over the free set, the entries that are nonzero or whose
gradient exceeds the penalty, with up to ``2(1 + \lfloor k/3\rfloor)`` passes
at step ``k``, and an Armijo line search keeps ``X`` positive definite. The
solution is block diagonal along the connected components of the graph of the
entries with ``w\lvert S_{ij}\rvert`` above the penalty, so each component is
solved on its own. The method stops when the relative duality gap (see
[Duality gaps](@ref)) is at most `tol`, which the `gap` of the result reports.
`X` is the starting point when it is positive definite; otherwise, zero for
example, the start is the diagonal solution ``1/(S_{ii} + \lambda_{ii}/w)``. A
Newton step costs a few Cholesky factorizations, where an iteration of
[ADMM](@ref) costs an eigendecomposition.

## Other smooth losses

`ProxNewton` also accepts a smooth loss `f` with
`ProximalBase.hashessian(f) == true`. The loss supplies
`quadratic_model(f, x)` and `quadratic_model!(q, f, x)`. Its model must be a
function that `cdmodel(q, x)` supports, such as `LeastSquaresLoss`,
`QuadraticFunction` or `KronQuadratic`, possibly scaled. A custom smooth loss
can return a `QuadraticFunction` with its Hessian and linear term. A Hessian
trait alone does not make an unsupported model usable by coordinate descent.

The quadratic model is a function of the **new point** `z`:

```math
q(z) = f(x) + \langle\nabla f(x), z-x\rangle
       + \tfrac12\langle z-x, \nabla^2 f(x)(z-x)\rangle,
```

up to a constant. The inner solve minimizes `q(z) + g(z)`, warm started at
`x`. The outer step is `d = z - x`; the penalty is evaluated at `z`, without
translating it again. The model buffers are updated with `quadratic_model!`.
The coordinate-descent model is refreshed after each update so that copied
matrices and scalar fields cannot retain the previous Hessian.

The generic path uses an Armijo line search on `f + g`. It rejects nonfinite
trial values, including a trial outside the domain of `f`. A failed line
search leaves the last accepted iterate and reports `converged = false`.
The specialized GLM and graphical-lasso algorithms above retain their own
model updates and stopping rules.

For the generic path, convergence is checked against the gradient of the
original loss at the current iterate. Its unit-step proximal fixed-point
residual is compared with `tol * max(1, norm(x, Inf))`. The residual is zero
when the proximal stationarity condition holds; for a convex objective this
characterizes a global minimizer. `CDResults.maxchange` and `tolerance`
report that residual and its threshold. `gap` is `NaN`, since a generic smooth loss need not provide a
Fenchel dual.

The inner change rule is followed by a proximal-residual check on the
quadratic model. When needed, its tolerance is tightened, sharing the
original `inner.maxpasses` budget across these refinements. The original
objective's residual remains the convergence check for the outer solve.

Dense vectors and `SparseIterate`s are supported. Matrix models can use a
`SymmetricSparseIterate` or a dense symmetric matrix with `NormL1` or
`ZeroFunction`. QUIC and this generic symmetric path follow the same penalty
parameter rule as [coordinate descent](@ref "Coordinates of the iterates"):
transposed `NormL1` weights are averaged, since their sum determines the
penalty on a symmetric pair. Weights can be a matrix or a vector in
column-major order. Penalties on vector iterates must be separable.
The quadratic models must have positive
semidefinite Hessians for the inner coordinate-descent solves to have their
usual interpretation. This generic path does not fit an extra intercept or
construct a screened penalty path; the GLM model interface supplies those
features.

```julia
A = [2.0 0.2; 0.2 1.0]
f = QuadraticFunction(A, [-1.0, 0.5])
x = zeros(2)
r = solve!(x, f, NormL1(0.1), ProxNewton(; tol = 1e-8))
r.converged, r.maxchange, r.tolerance
```

## Settings

`ProxNewton(; inner = CDSolver(; tol = 1e-8), maxiter = 100, tol = 1e-8, β = 0.5)`.
`solve!` returns a [`CDResults`](@ref) whose `passes` sum the inner passes.
The GLM path reports convergence when its outer stopping rule was met and
every inner solve converged. The graphical lasso stops on its duality gap.
The generic path stops on the proximal fixed-point residual described above.

## References

- J. Friedman, T. Hastie and R. Tibshirani. Regularization Paths for
  Generalized Linear Models via Coordinate Descent. *Journal of Statistical
  Software*, 33(1), 2010.
- C.-J. Hsieh, M. A. Sustik, I. S. Dhillon and P. Ravikumar. QUIC: Quadratic
  Approximation for Sparse Inverse Covariance Estimation. *Journal of Machine
  Learning Research*, 15, 2014.
- J. D. Lee, Y. Sun and M. A. Saunders. Proximal Newton-Type Methods for
  Minimizing Composite Functions. *SIAM Journal on Optimization*, 24(3), 2014.
