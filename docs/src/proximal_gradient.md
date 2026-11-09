# Proximal gradient methods

[`ProximalGradientDescent`](@ref) and [`AccProxGradDescent`](@ref) minimize
``F = f + g`` for a smooth convex ``f`` and a convex ``g`` whose proximal
operator,

```math
\operatorname{prox}_{\gamma g}(v) = \operatorname*{argmin}_z \; g(z) + \frac{1}{2\gamma}\|z - v\|^2 ,
```

is cheap to compute: soft thresholding for the ℓ1 norm, block soft
thresholding for the group lasso, soft thresholding of the singular values for
the nuclear norm, a projection for the indicator function of a set. They need
two oracles, the gradient of ``f`` and the proximal operator of ``g``, so they
take any pair of functions of ProximalBase that provide them.

## The proximal gradient step

With a step ``1/L``, the step from ``x`` minimizes ``g`` plus the quadratic
model of ``f`` at ``x``:

```math
x^+ = \operatorname*{argmin}_z \; f(x) + \langle \nabla f(x), z - x\rangle + \frac{L}{2}\|z - x\|^2 + g(z)
    = \operatorname{prox}_{g/L}\Big(x - \frac{1}{L}\nabla f(x)\Big).
```

Write ``Q_L(z; x) = f(x) + \langle \nabla f(x), z - x\rangle + \frac{L}{2}\|z - x\|^2``.
If the upper bound

```math
f(x^+) \le Q_L(x^+; x)
```

holds, the step decreases ``F``: since ``x^+`` minimizes ``Q_L(\cdot\,; x) + g``,
which is ``L``-strongly convex, ``F(x^+) \le Q_L(x^+; x) + g(x^+) \le F(x) - \tfrac{L}{2}\|x^+ - x\|^2``.
The bound holds for every ``x`` when ``L`` is at least the Lipschitz constant
``L_f`` of ``\nabla f``, and then the iterates satisfy
``F(x_k) - F^\star \le L\|x_0 - x^\star\|^2/(2k)`` (Beck and Teboulle, 2009).
The solvers do not need ``L_f``: they find a step by backtracking, which also
adapts to the local curvature, often much smaller than ``L_f``.

The fixed points of the step are the minimizers. The optimality condition
``0 \in \nabla f(x) + \partial g(x)`` is equivalent to
``x = \operatorname{prox}_{g/L}(x - \nabla f(x)/L)`` for any ``L > 0``.

## Proximal gradient descent

[`ProximalGradientDescent`](@ref) takes the step above with the backtracking
line search of TFOCS (Becker, Candès and Grant, 2011), the
`BackTracking(; α = 0.9, β = 0.5, Lexact = Inf)` of `ProximalSolvers.LineSearches`.
Each iteration

1. lowers the curvature estimate, ``L \leftarrow \alpha L``, so that the step
   can grow where the curvature is smaller;
2. takes the step ``x^+ = \operatorname{prox}_{g/L}(x - \nabla f(x)/L)``;
3. computes a local Lipschitz estimate ``\hat L`` along ``d = x^+ - x``;
4. accepts the step if ``\hat L \le L`` (or ``L \ge L_{\text{exact}}``), and
   otherwise sets ``L \leftarrow \min(L_{\text{exact}}, \max(\hat L, L/\beta))``
   and returns to step 2.

The estimate ``\hat L`` comes from function values while they can be
compared in floating point:

```math
\hat L = L + \frac{2\,\max\{f(x^+) - Q_L(x^+; x),\, 0\}}{\|d\|^2},
```

the smallest ``L'`` with ``f(x^+) \le Q_{L'}(x^+; x)``. Near the solution
``f(x^+)`` and ``f(x)`` agree to almost all their digits, and the difference
``f(x^+) - Q_L`` is lost to cancellation. Once
``|f(x) - f(x^+)| < 10^{-10}\max\{|f(x)|, |f(x^+)|\}``, the estimate switches
for good to one from gradients,

```math
\hat L = \frac{2\,\langle \nabla f(x^+) - \nabla f(x),\, d\rangle}{\|d\|^2}.
```

For convex ``f``, ``f(x^+) - f(x) - \langle\nabla f(x), d\rangle \le \langle \nabla f(x^+) - \nabla f(x), d\rangle``,
so ``\hat L \le L`` implies the upper bound ``f(x^+) \le Q_L(x^+; x)``. The
second estimate costs a gradient at the trial point, which the next iteration
needs anyway.

**Points off the domain.** A loss can be infinite on part of the space, as
``\operatorname{tr}(S\Theta) - \log\det\Theta`` is off the positive definite
cone. A trial point where ``f`` is not finite gives no estimate and is never
accepted: the search sets ``L \leftarrow L/\beta`` and tries again, past
``L_{\text{exact}}`` if need be. A small enough step from a point of the domain
stays in it, so the search ends. The starting point must be in the domain:
both methods throw an `ArgumentError` when ``f(x_0)`` is not finite, and the
identity is a valid start for the log-determinant loss.

## Accelerated proximal gradient descent

[`AccProxGradDescent`](@ref) takes the proximal gradient step from an
extrapolated point (Nesterov's acceleration, FISTA of Beck and Teboulle, 2009,
in the form of §4.3 of Parikh and Boyd, 2014):

```math
y = x_k + \omega_k (x_k - x_{k-1}), \qquad \omega_k = \frac{k}{k + 3}, \qquad
x_{k+1} = \operatorname{prox}_{g/L}\Big(y - \frac{1}{L}\nabla f(y)\Big),
```

where ``k`` counts the iterations since the last restart, so the first step
after a restart has no momentum. The step size comes from backtracking on the
upper bound at ``y``: starting from ``\alpha L``, ``L`` is divided by
``\beta`` until

```math
f(x_{k+1}) \le f(y) + \langle \nabla f(y), x_{k+1} - y\rangle + \frac{L}{2}\|x_{k+1} - y\|^2 + 10\,\varepsilon \max\{|f(y)|, 1\},
```

with ``\varepsilon`` the machine precision; the last term keeps rounding near
the solution from forcing endless backtracking. With ``\alpha = 1``, ``L``
never decreases, and without restarts this is the accelerated method with
backtracking of Beck and Teboulle (2009), whose objective converges at the
rate ``O(1/k^2)``, against ``O(1/k)`` without momentum. The default
``\alpha = 0.9`` lets the step grow again, as in TFOCS. The number and cost of
backtracking trials depend on the problem; neither setting is uniformly faster.

**Restarts.** Momentum makes the objective oscillate when the extrapolation
overshoots. Following the function-value scheme of O'Donoghue and Candès
(2015), when ``F(x_{k+1}) > F(x_k)`` the iteration is repeated with
``\omega = 0`` from ``y = x_k``, and ``k`` starts again at zero. A step from
``x_k`` itself cannot increase ``F``, so this happens at most once per
iteration, and the objective is nonincreasing. An extrapolated point off the
domain of ``f``, where no step from it exists, restarts the iteration in the
same way; a trial point off the domain fails the upper bound, so backtracking
shortens the step.

## Nonconvex penalties

Both methods also take a ``g`` that is not convex but has a cheap proximal
operator, such as the indicator of the ℓ0 ball `IndBallL0(s)`, `IndBallRank`,
`NormL0`, `MCP` or `SCAD`; its proximal operator is then a minimizer of a
nonconvex problem. The step from ``x`` still minimizes
``Q_L(\cdot\,; x) + g``, so under the upper bound
``F(x^+) \le Q_L(x^+; x) + g(x^+) \le Q_L(x; x) + g(x) = F(x)``: the objective
of proximal gradient descent does not increase in exact arithmetic. A
limit-point stationarity result also requires a proper lower semicontinuous
penalty, suitable smoothness and bounded-step conditions, and bounded
iterates; the function traits do not establish these conditions. With `g = IndBallL0(s)` it is iterative
hard thresholding with a line search, and
`ProximalGradientDescent(; normalized = false, debias = 0)` has two options
from that literature:

- `normalized = true` starts the backtracking of each iteration from the
  normalized step of Blumensath and Davies (2010) instead of from
  ``\alpha L``. With ``d`` the gradient at ``x`` on the support of ``x`` (all
  of it when ``x = 0``) and ``\tau = 1/L``, a quadratic ``f`` has
  ``\langle d, \nabla^2 f\, d\rangle = 2\big(f(x - \tau d) - f(x) + \tau\|d\|^2\big)/\tau^2``,
  and the search starts from ``L = \langle d, \nabla^2 f\, d\rangle / \|d\|^2``,
  whose step ``1/L`` minimizes ``f`` along ``d``. It costs one value of ``f``,
  and keeps ``L`` when the estimate is not positive and finite.
- `debias = k > 0` refits ``f`` on the support of ``x`` with [`refit!`](@ref)
  once the support has not changed for ``k`` iterations, and keeps the refit
  if it lowers ``F``, as MendelIHT does. The refit keeps the support, so it
  stays feasible for an ℓ0 or rank constraint, and each support is refitted
  once. It needs a loss that `refit!` takes and a vector, `SparseIterate` or
  `SymmetricSparseIterate` iterate.

The restarts of [`AccProxGradDescent`](@ref) keep its objective from
increasing for a nonconvex ``g`` too, but its iterates need not approach a
critical point. [`MonotoneAccProxGradDescent`](@ref) is the monotone method of
Li and Lin (2015, Algorithm 2). With ``t_0 = 0``, ``t_1 = 1`` and
``t_{k+1} = (1 + \sqrt{4t_k^2 + 1})/2``, each iteration takes a proximal
gradient step from an extrapolated point,

```math
y_k = x_k + \frac{t_{k-1}}{t_k}(z_k - x_k) + \frac{t_{k-1} - 1}{t_k}(x_k - x_{k-1}),
\qquad z_{k+1} = \operatorname{prox}_{g/L}\Big(y_k - \frac{1}{L}\nabla f(y_k)\Big),
```

with the backtracking of [`AccProxGradDescent`](@ref) on the upper bound at
``y_k``. It keeps ``x_{k+1} = z_{k+1}`` when
``F(z_{k+1}) \le F(x_k) - \delta L\|z_{k+1} - y_k\|^2``, by default with
``\delta = 10^{-3}``. Otherwise it also takes a plain step from ``x_k``, with
its own backtracking, and keeps the better of the two. So the objective never
increases in exact arithmetic under the accepted majorization bounds. The
cited stationarity and accelerated-rate results require their additional
assumptions; numerical backtracking, restarts and approximate proximal
operators do not establish those results by themselves. An
iteration that falls back costs a second gradient and a second search.

For least-squares and generalized linear losses, including scaled losses,
the method caches the images of the iterates under the design matrix.
The image of ``y_k`` is the same combination of the images of ``x_k``,
``z_k`` and ``x_{k-1}``, so it needs no new product. A trial point costs
one product with the design and a gradient one product with its transpose;
the plain fallback reuses the image of ``x_k``. Both candidate images are
kept because the next extrapolation uses ``z_k`` even when the plain
candidate was selected. Each candidate image comes from a direct product,
which prevents accumulated drift. Other smooth losses and tuple iterates
use the original value and gradient oracles.

## Sparse plus low-rank block iterates

All three gradient methods accept tuples of arrays, including
`MonotoneAccProxGradDescent`. The blocks can have different shapes and storage:
a `SymmetricSparseIterate` for a sparse symmetric matrix `S` and a dense
rectangular factor `U`, for example. They use one backtracked step size for
the whole pair and the Euclidean norm across both blocks.

On a `SymmetricSparseIterate`, the three gradient solvers apply the same
parameter rule as [coordinate descent](@ref "Coordinates of the iterates"):
the per-entry parameters of ``g`` that `ProximalBase.check_symmetric_parameters`
covers must be exactly symmetric, or symmetric by type as `Symmetric(W, :L)`,
and otherwise an `ArgumentError` is thrown before anything is written. The
penalty is used as supplied; for the symmetric part of asymmetric weights, pass
``(W + W')/2``, which is a different penalty. On a tuple of iterates the penalty
goes through the same check, which covers the blocks of a `SeparableSum` and the
per-entry parameters that ProximalBase declares, and not user-defined wrappers
or types that declare nothing. A custom penalty or wrapper is responsible for
the symmetric-storage compatibility of its own parameters. The smooth loss
``f`` is not checked.

A `SymmetricSparseIterate` is a point of the space of symmetric matrices with
the Frobenius inner product. The iterates ``x``, ``x'``, the extrapolated
points ``y`` and the candidates of the monotone method keep its type, and ``f``
and its gradient are evaluated at them; the normalized step evaluates ``f`` at
a `SymmetricSparseIterate` that holds its trial point. The solvers do not
symmetrize the gradient that ``f`` returns. `KronQuadratic(A, B, C)` returns at
a `SymmetricSparseIterate` the gradient over symmetric matrices, the symmetric
part of the matrix gradient, which is exactly symmetric and, for ``A \ne B``,
differs from its gradient at a dense matrix. A loss used at a
`SymmetricSparseIterate` must return a symmetric gradient for the trial point
to be symmetric. The trial point ``y - \nabla f(y)/L`` before the proximal
step, the step ``x - x'`` and the gradients are dense matrices; with a
gradient that is exactly symmetric, the trial point is exactly symmetric. With
a gradient that is not, the proximal step of ProximalBase into a
`SymmetricSparseIterate` reads the symmetric part of the trial point, the
stopping rules use the gradient as returned, and the dense proximal step below
and the normalized step throw an `ArgumentError` when the matrix they copy into
a `SymmetricSparseIterate` is not exactly symmetric, as does the tuple route
below when the trial point of a `SymmetricSparseIterate` block is not. Step norms, inner
products and residuals are those of the matrix, both triangles, so an
off-diagonal change counts twice: a change of ``0.1`` in one off-diagonal
coordinate is a step of norm ``0.1\sqrt{2}``. With `debias`, the support is the
set of coordinates whose value is not zero, and an active coordinate that holds
a zero is not in it. For `LinearConstrained`, `IndIntersection` and
`PointwiseMinimum` penalties, also inside `Scaled`, `Translate` and `Tilt`, the
proximal step of a `SymmetricSparseIterate` is taken over matrices into a dense
buffer and copied into the iterate, which throws an `ArgumentError` when that
matrix is not exactly symmetric. A tuple whose penalty is a `SeparableSum` (also
inside `Scaled`) in which a `SymmetricSparseIterate` block has such a penalty
takes one proximal step of ProximalBase for the whole penalty into scratch
blocks: a dense matrix for a `SymmetricSparseIterate` block whose penalty is one
of those three or `IndBallL1`, `IndBallL2`, `IndSimplex` or `IndSphereL2` (also
inside `Scaled` with a positive scale), an emptied `SymmetricSparseIterate` for
any other `SymmetricSparseIterate` block, and a buffer allocated with `similar`
for the other blocks. Each `SymmetricSparseIterate` block must have an exactly
symmetric trial point (an `ArgumentError` before anything is written
otherwise). A `SymmetricSparseIterate` block whose penalty contains `IndBallL0`
takes its trial point as a `SymmetricSparseIterate`, the other blocks as a
dense matrix: at the ProximalBase commit of `Project.toml`, `IndBallL0` counts
a mirrored pair once in a `SymmetricSparseIterate` argument and twice in a
matrix. A trial block of `IndBallL1`, `IndBallL2`, `IndSimplex` or
`IndSphereL2` with exactly one infinite mirrored off-diagonal pair, no other
infinite entry (for `IndSimplex`, no other `+Inf`) and no NaN is refused with an
`ArgumentError` before anything is written: the dense step gives NaN there,
where ProximalBase gives a finite limiting projection into a
`SymmetricSparseIterate`. The result is copied into the iterate after every dense
matrix of a `SymmetricSparseIterate` block is checked to be exactly symmetric,
and an `ArgumentError` is thrown before any block is written when one is not.
The four set families take a dense matrix because the tuple proximal step of
the tested ProximalBase revisions in which `SymmetricSparseIterate` is not an
`AbstractArray` (#737 and a later master) has no `SymmetricSparseIterate`
output for them; their proximal points over matrices agree with those over
symmetric matrices at a symmetric argument. When the loaded ProximalBase has no
such output for `IndBallL0` (the solvers test this once), a tuple on this route
with a `SymmetricSparseIterate` block whose penalty is `IndBallL0` is refused
with an `ArgumentError` before anything is written: a dense matrix would change
the meaning of its cardinality. These roles and refusals are temporary, until
ProximalBase provides these outputs. An exception during the final copy itself,
such as an interrupt, can leave earlier blocks written. ProximalBase refuses
`Translate` and `Tilt` around a tuple with a `SymmetricSparseIterate` block, and
whose parameters are tuples with one block per iterate block, with an
`ArgumentError` that the solvers raise when they evaluate the penalty at the
start point, before anything is written; with an array parameter, ProximalBase
throws a `DimensionMismatch` instead.
The diagonal preconditioner, [`ActiveAccProxGradDescent`](@ref) and
[`ADMMSolver`](@ref) throw an `ArgumentError` before anything is written when
the iterate is a `SymmetricSparseIterate`.

For a latent graphical model, write `Θ = S + U * U'` and supply a smooth
loss with

```math
f(S,U) = \operatorname{tr}(\Sigma\Theta)-\log\det\Theta,\qquad
G = \Sigma-\Theta^{-1},\quad \nabla_S f=G,\quad \nabla_U f=2GU.
```

The loss must test a Cholesky factorization of `Θ` before taking its inverse
or log determinant. Return `Inf` when factorization fails, including from
`value_and_gradient!`, and leave gradient buffers unused at that point. The
line search rejects these trials. With this loss `f`, the solver call is

```julia
x = (SymmetricSparseIterate(Matrix(1.0I, p, p)), copy(U0))
g = SeparableSum(IndBallL0(s; diagonal = false), ZeroFunction())
r = solve!(x, f, g, MonotoneAccProxGradDescent())
```

The same interface applies to a D-trace loss composed with `S + U * U'`.
Its gradient in `S` is the symmetric part of the matrix gradient, and the
factor gradient is twice that symmetric part times `U`. The sign of the
low-rank term is part of the supplied model; a solver does not choose it.

For `ProximalGradientDescent(; normalized = true)`, support restriction is
applied to every block. The unrestricted gradient is used only when the
**entire tuple** is zero. A zero block beside an active block remains
excluded from the curvature trial. For a nonlinear coupled loss this
curvature estimate is a trial heuristic; backtracking still checks the
original loss. Tuple debiasing is not supported: `debias > 0` requires a
single iterate supported by `refit!`.

The symmetric projection requires ProximalBase 0.5.3. When the diagonal counts
toward the sparsity budget, an off-diagonal pair is ranked by its Frobenius
weight `√2 * abs(S[i,j])`. This can select a different support from a legacy
routine that ranks every stored entry by magnitude, even without ties.
These nonconvex problems can also have different local solutions; a lower
objective does not establish a global optimum.

## Stopping rules

The methods stop at the first of these tests to pass, after the iteration
limit, the time limit or a limit on the number of calls, when the callback
returns `true`, or when the objective increases (which rounding can cause
near the solution) unless `allow_f_increases` is set. With ``x'`` the previous
iterate and ``F = f + g``:

- **`ftol`**, the relative change of the objective:
  ``|F(x) - F(x')| / (|F(x)| + \mathrm{ftol}) < \mathrm{ftol}``, or a change
  below the rounding error of ``|F(x)| + |F(x')|``.
- **`xtol`**, the change of the iterate:
  ``\|x - x'\| < \mathrm{xtol}\cdot\max\{\|x\|, 1\}``.
- **`gradtol`**, the residual of the optimality condition, as in FASTA
  (Goldstein, Studer and Baraniuk, 2014).

The residual comes from the step itself. For proximal gradient descent, the
optimality condition of the step from ``x'`` with step size ``1/L`` says that
``v = L(x' - x) - \nabla f(x')`` is a subgradient of ``g`` at ``x``. So

```math
r = \nabla f(x) + v = \nabla f(x) - \nabla f(x') - L(x - x') \in \nabla f(x) + \partial g(x),
```

and ``r = 0`` exactly when ``x`` is a minimizer. The accelerated method steps
from ``y`` and never evaluates ``\nabla f(x)``. Its residual
``\nabla f(x) - \nabla f(y) - L(x - y)`` is at most ``(L + L_f)\|x - y\|``, and
``L\|x - y\|_\infty`` stands in for it; for the monotone method, ``y`` is the
point its kept step came from, ``y_k`` or ``x_k``. The test passes when either the
relative residual or the normalized residual is below `gradtol`:

```math
\frac{\|r\|_\infty}{\max_{j \le k}\|r_j\|_\infty + \mathrm{gradtol}} < \mathrm{gradtol}
\quad\text{or}\quad
\frac{\|r\|_\infty}{\max\{\|\nabla f\|_\infty, \|v\|_\infty\} + \mathrm{gradtol}} < \mathrm{gradtol},
```

with the gradient at ``x`` (at ``y`` for the accelerated method). The first
compares the residual with the largest one seen so far; the second with the
size of the two terms that cancel at the solution.

With `gaptol > 0` and functions that have a duality gap, the relative gap,
computed every `gapevery` iterations, replaces these tests and the stop on an
increasing objective; see [Duality gaps](@ref).

**Choosing tolerances.** Near a minimizer at which ``F`` grows quadratically,
``F(x) - F^\star`` is of the order of ``\|x - x^\star\|^2``, so the objective
can settle before the iterate does. An objective-change threshold such as
`ftol = 1e-12` does not by itself guarantee any number of correct coefficient
digits: the change between iterations is not the error relative to the optimum. When accurate solutions matter, tighten `gradtol` and `xtol`
as well, or check the optimality conditions of the problem afterwards, as the
examples do.

## Sparse iterates

Both methods keep the type of the starting point. With a `SparseIterate`
(or, for the group lasso, an `AtomIterate` with the groups of the penalty),
zeros are dropped after every step, and the products of a least-squares loss
by the iterate cost ``O(n)`` per stored entry or group. For a sparse solution
with many coordinates, [Active-set proximal gradient](@ref) goes further and
works on the active coordinates only.

## References

- A. Beck and M. Teboulle. A Fast Iterative Shrinkage-Thresholding Algorithm
  for Linear Inverse Problems. *SIAM Journal on Imaging Sciences*, 2(1), 2009.
- S. Becker, E. Candès and M. Grant. Templates for Convex Cone Problems with
  Applications to Sparse Signal Recovery. *Mathematical Programming
  Computation*, 3, 2011.
- T. Blumensath and M. E. Davies. Normalized Iterative Hard Thresholding:
  Guaranteed Stability and Performance. *IEEE Journal of Selected Topics in
  Signal Processing*, 4(2), 2010.
- T. Goldstein, C. Studer and R. Baraniuk. A Field Guide to Forward-Backward
  Splitting with a FASTA Implementation. arXiv:1411.3406, 2014.
- H. Li and Z. Lin. Accelerated Proximal Gradient Methods for Nonconvex
  Programming. *Advances in Neural Information Processing Systems* 28, 2015.
- B. O'Donoghue and E. Candès. Adaptive Restart for Accelerated Gradient
  Schemes. *Foundations of Computational Mathematics*, 15, 2015.
- N. Parikh and S. Boyd. Proximal Algorithms. *Foundations and Trends in
  Optimization*, 1(3), 2014.
