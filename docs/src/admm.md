# ADMM

The alternating direction method of multipliers, [`ADMMSolver`](@ref),
minimizes ``f(x) + g(x)`` when both ``f`` and ``g`` have proximal operators
that are cheap to compute, and neither needs to be smooth. Examples are the
graphical lasso, where the proximal operator of ``\operatorname{tr}(S\Theta) - \log\det\Theta``
takes one eigendecomposition and that of the ℓ1 norm is soft thresholding,
and least squares with a penalty, where the proximal operator of the loss
reuses one singular value decomposition of ``X`` for every step size.

## The iterations

ADMM splits the variable in two, and solves

```math
\underset{x,\,z}{\text{minimize}} \quad f(x) + g(z) \quad \text{subject to} \quad x = z
```

by alternating minimization of the augmented Lagrangian

```math
L_\rho(x, z, y) = f(x) + g(z) + \langle y, x - z\rangle + \frac{\rho}{2}\|x - z\|^2
```

over ``x`` and over ``z``, followed by a step on the multiplier ``y``. In the
scaled form, with ``u = y/\rho``, and with over-relaxation by
``\alpha \in (0, 2)`` (§3.4.3 of Boyd et al., 2011), each iteration is

```math
\begin{aligned}
x^{k+1} &= \operatorname{prox}_{f/\rho}\big(z^k - u^k\big), \\
\hat x^{k+1} &= \alpha\, x^{k+1} + (1 - \alpha)\, z^k, \\
z^{k+1} &= \operatorname{prox}_{g/\rho}\big(\hat x^{k+1} + u^k\big), \\
u^{k+1} &= u^k + \hat x^{k+1} - z^{k+1}.
\end{aligned}
```

The ``x``-update minimizes ``f(x) + \frac{\rho}{2}\|x - z^k + u^k\|^2``, which
is the proximal operator of ``f`` with step ``1/\rho``, and the ``z``-update
does the same for ``g``. With ``\alpha = 1`` this is plain ADMM; values between
1.5 and 1.8 are common choices; their effect depends on the problem. For closed,
proper, convex ``f`` and ``g`` whose split Lagrangian has a saddle point,
with exact proximal updates the iterates converge to a minimizer for every
``\rho > 0`` and ``\alpha \in (0, 2)`` (Eckstein and Bertsekas, 1992).
The saddle-point condition includes dual attainment and strong duality;
existence of a primal solution alone is not the stated convergence hypothesis
(Boyd et al., 2011, §3.2).

The solver starts from ``z^0 = x``, the given starting point, and ``u^0 = 0``
or a given ``u``. It returns ``z``, which lies in the domain of ``g``: for the
ℓ1 norm it is exactly sparse, while ``x`` is only close to sparse.

## Residuals and stopping

A solution satisfies primal feasibility, ``x = z``, and dual feasibility,
``0 \in \partial f(x) + y`` and ``0 \in \partial g(z) - y``. The optimality
condition of the ``z``-update is
``0 \in \partial g(z^{k+1}) - \rho u^{k+1}``, so the second condition holds at
every iteration. That of the ``x``-update,
``0 \in \partial f(x^{k+1}) + \rho(x^{k+1} - z^k + u^k)``, is, for
``\alpha = 1``, ``0 \in \partial f(x^{k+1}) + \rho u^{k+1} + \rho(z^{k+1} - z^k)``:
the first condition holds up to ``\rho(z^{k+1} - z^k)``. So the two residuals
are

```math
r^{k+1} = x^{k+1} - z^{k+1} \quad\text{(primal)}, \qquad
s^{k+1} = \rho\,(z^{k+1} - z^k) \quad\text{(dual)},
```

and the solver stops when both are small, as in §3.3 of Boyd et al.:

```math
\|r\| \le \sqrt{n}\,\varepsilon_{\text{abs}} + \varepsilon_{\text{rel}} \max\{\|x\|, \|z\|\},
\qquad
\|s\| \le \sqrt{n}\,\varepsilon_{\text{abs,dual}} + \varepsilon_{\text{rel}}\, \rho\|u\|,
```

where ``n`` is the number of entries of ``x``, ``\rho\|u\| = \|y\|``, and
``\varepsilon_{\text{abs}}``, ``\varepsilon_{\text{abs,dual}}`` and
``\varepsilon_{\text{rel}}`` are `abstol`, `abstol_dual` and `reltol`.

The norm is Euclidean by default. `ADMMSolver(; norm)` measures the
residuals, ``\|x\|``, ``\|z\|`` and ``\|u\|`` in another norm, a function of an
array: for a stack of ``K`` matrices, for example, the sum of the norms of
the slices, `x -> sum(k -> norm(view(x, :, :, k)), axes(x, 3))`. If the
function also has a method `norm(x, y)` for the norm of ``x - y``, the
residuals are computed with it, without forming the differences.

With `gaptol > 0` in [`ProximalOptions`](@ref) and functions that have a
duality gap, such as the graphical lasso, the relative gap at ``z`` replaces
the residual tests; see [Duality gaps](@ref).

## Choosing ρ

The parameter ``\rho`` trades the two residuals: a large ``\rho`` enforces
``x = z`` strongly and leaves a large dual residual, a small one the reverse,
and a poor value can slow convergence by orders of magnitude. With
`adaptive = true`, the solver balances the residuals (§3.4.1 of Boyd et al.):
with each residual divided by its tolerance,
``\tilde r = \|r\|/\varepsilon_{\text{pri}}`` and
``\tilde s = \|s\|/\varepsilon_{\text{dual}}``,

```math
\rho \leftarrow \begin{cases}
2\rho & \text{if } \tilde r > 10\, \tilde s, \\
\rho / 2 & \text{if } \tilde s > 10\, \tilde r, \\
\rho & \text{otherwise.}
\end{cases}
```

The multiplier ``y = \rho u`` does not change with ``\rho``, so ``u`` is
divided by the same factor. After 50 changes ``\rho`` stays fixed, which keeps
the convergence guarantee of a fixed ``\rho``.

## Warm starts

A previous result `res` warm starts a nearby problem, such as the next level
of a path of penalties: pass its estimate as the starting point, its scaled
dual variable as the keyword `u`, and its final ``\rho`` to the solver,

```julia
solve!(x, f, g, ADMMSolver(; ρ = res.ρ, adaptive = true), options; u = res.u)
```

Of the [`ProximalOptions`](@ref), ADMM uses `maxiter`, `time_limit`,
`prox_calls_limit`, `show_trace` and `print_every`. Each iteration evaluates
two proximal operators and no function values, except to print the trace and
to report the minimum.

## References

- S. Boyd, N. Parikh, E. Chu, B. Peleato and J. Eckstein. Distributed
  Optimization and Statistical Learning via the Alternating Direction Method of
  Multipliers. *Foundations and Trends in Machine Learning*, 3(1), 2011.
- J. Eckstein and D. P. Bertsekas. On the Douglas–Rachford Splitting Method and
  the Proximal Point Algorithm for Maximal Monotone Operators. *Mathematical
  Programming*, 55, 1992.
