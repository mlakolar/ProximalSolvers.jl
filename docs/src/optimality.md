# Checking a solution

A solver reports whether its stopping rule was met, which can depend on
changes in the iterates or an optimality measure. We distinguish residuals
of the optimality conditions from bounds on objective error and explain how
to compute each quantity. The appropriate check depends on the loss, the penalty and the accuracy
needed in the application.

## Optimality conditions

Suppose that ``f`` is convex and differentiable and ``g`` is a proper closed
convex function. A feasible point ``x`` minimizes ``P=f+g`` if and only if

```math
0\in\nabla f(x)+\partial g(x),
```

where ``\partial g`` is the convex subdifferential. For the lasso with
``f(\beta)=\|y-X\beta\|_2^2/(2n)`` and ``g(\beta)=\lambda\|\beta\|_1``, let
``c=\nabla f(\beta)=X^\top(X\beta-y)/n``. The conditions become

```math
\begin{cases}
c_j+\lambda\operatorname{sign}(\beta_j)=0, & \beta_j\ne0,\\
|c_j|\le\lambda, & \beta_j=0.
\end{cases}
```

In particular, the second condition explains both ``\lambda_{\max}`` and the
checks on coordinates excluded by screening. See [The lasso](@ref) for a
direct calculation of these violations.

For a group penalty ``g(x)=\lambda\sum_k w_k\|x_{G_k}\|_2`` with disjoint
groups, a group at zero satisfies its condition when
``\|\nabla_{G_k}f(x)\|_2\le\lambda w_k``. On a nonzero group, the condition is
``\nabla_{G_k}f(x)+\lambda w_k x_{G_k}/\|x_{G_k}\|_2=0``. These are the block
counterparts of the lasso conditions above.

## Coordinate residuals

For a separable penalty and a supported coordinate model with positive
coordinate curvatures, [`kkt_residual`](@ref) measures the largest scaled
coordinate step that would be taken at the current iterate:

```math
R(x)=\max_j\sqrt{a_j}\left|
\operatorname{prox}_{g_j/a_j}\left(x_j-\frac{\nabla_j f(x)}{a_j}\right)-x_j
\right|.
```

With `relative = true`, the default, it divides ``R(x)`` by the response scale
when that scale is positive. The [coordinate descent stopping rule](@ref
"The stopping rule") defines these scales. For least squares, they are
``a_j=\|X_j\|_2^2/n`` and ``\|y\|_2/\sqrt n``, without an intercept or weights.

Using the residual, we check all coordinates at the same point without
changing the iterate. This differs from the largest change observed during
a pass, in which each step starts from the preceding step's updated iterate. Furthermore, its
scale differs from the raw lasso violations displayed above.

For a convex objective, a zero residual characterizes optimality under the
stated conditions. A small residual alone does not give a numerical bound on
objective error without further properties of the problem. The function
applies to the separable penalties and coordinate models listed in its
[reference](@ref kkt_residual).

## Objective error and duality

For ``f(x)=F(Ax)``, the Fenchel dual objective is

```math
D(\theta)=-F^*(\theta)-g^*(-A^\top\theta),
```

where the superscript ``*`` denotes the convex conjugate. Using any dual feasible point, we obtain the bound

```math
0\le P(x)-\inf_z P(z)\le P(x)-D(\theta).
```

Therefore, a duality gap bounds objective error directly, while a bound on
the distance between coefficient vectors requires further assumptions.

### A dual point for the lasso

For the lasso above, suppose that ``\lambda>0``. The dual objective and
its feasible set take the form

```math
D(\theta)=-y^\top\theta-\frac n2\|\theta\|_2^2,
\qquad \|X^\top\theta\|_\infty\le\lambda.
```

Starting from ``u=(X\beta-y)/n``, we choose
``t=\min\{1,\lambda/\|X^\top u\|_\infty\}`` and ``\theta=tu``,
where we take ``t=1`` if the denominator is zero. This scaling makes the dual point
feasible, so ``P(\beta)-D(\theta)`` is an upper bound on the objective error.
At a lasso solution, the gradient already satisfies the dual constraint and
the gap is zero in exact arithmetic.

### Using the certificate

[`duality_gap`](@ref)`(f, g, x)` returns a named tuple with `gap`, `primal` and
`dual`. The solver result instead stores the relative gap in `res.gap`:

```math
\frac{\max\{P(x)-D(\theta),0\}}{\max\{|P(x)|,\mathrm{floatmin}(T)\}},
```

where ``T`` is the floating point type. The clipping handles a negative gap
caused by rounding, and the denominator avoids division by zero. The absolute gap remains useful when the objective is close to zero, where
relative accuracy is sensitive to the denominator. Note that adding a
constant to the objective changes the relative gap but leaves the absolute
gap unchanged.

With `CDSolver(; gaptol = 1e-8)`, coordinate descent stops on the gap: the
rule on the coordinate changes only decides when to compute it, and tightens
until the gap is small enough (see [Stopping on the duality gap](@ref)). The
paths of [`solve_path`](@ref) do this by default, at a relative gap of
`1e-4`. For [`ProximalGradientDescent`](@ref), [`AccProxGradDescent`](@ref)
and [`ADMMSolver`](@ref), use `ProximalOptions(; gaptol, gapevery)` to check it
every `gapevery` iterations in place of their other convergence tests.

The certificate is available for least squares and the squared, logistic,
Poisson and Huber GLM losses with supported convex penalties, and for the
graphical lasso. The [`duality_gap`](@ref) reference lists the supported combinations,
weights and iterate types, and an unsupported combination raises an
`ArgumentError`. A solver asked to use an unavailable
gap warns and falls back to its usual stopping rule.

For a linear composite, [`CondatVu`](@ref) uses the six-argument
`duality_gap(f, g, h, D, x, y)` and the same `gaptol`/`gapevery` options.
See [Primal–dual splitting](@ref) for its feasible dual construction and
conjugate requirements.

With `gapsafe = true`, coordinate descent also uses the gap to remove
coordinates proved zero at the optimum. See [Penalty paths and screening](@ref)
for screening, and Fercoq, Gramfort and Salmon (*Mind the duality gap: safer
rules for the lasso*, 2015) for the underlying gap-safe construction.

## Nonconvex problems

The convex optimality conditions and dual certificates above do not establish
global optimality for MCP, SCAD or other nonconvex penalties. The method pages describe the applicable stationarity conditions and
convergence results for these penalties. In particular, we distinguish
convergence to a stationary point from recovery of the statistical model
that generated the data.
