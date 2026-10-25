# Primal–dual splitting

For a derivation, harder worked problems, and comparisons with QP and ordinary
or specialized ADMM methods, read [Choosing a splitting for a composite problem](@ref composite_lessons).
That lecture explains when this solver is useful and when a specialized
proximal operator or a different splitting is preferable.

[`CondatVu`](@ref) minimizes

```math
f(x)+g(x)+h(Dx),
```

where the three functions are convex, `f` has a globally Lipschitz gradient,
and `g` and `h` have proximal operators. `D` is a dense or sparse real matrix.
The primal iterate is a floating vector or a `SparseIterate`; the dual is a
dense vector of length `size(D, 1)`.

```julia
res = solve!(x, f, g, h, D, CondatVu(), ProximalOptions(maxiter = 100_000))
```

The iteration is

```math
\begin{aligned}
x^+ &= \operatorname{prox}_{\tau g}(x-\tau(\nabla f(x)+D^\top y)),\\
y^+ &= \operatorname{prox}_{\sigma h^*}(y+\sigma D(2x^+-x)).
\end{aligned}
```

ProximalBase's `Conjugate(h)` computes the second proximal operator by
Moreau's identity, retaining its scratch buffer. Cached gradients and products
allow one multiplication by each of `D` and its adjoint per ordinary iteration.
Restart and gap checks perform additional operations.

## Step sizes and adaptation

The condition is `τ*(L/2 + σ*normD^2) < 1`, where `L` bounds the Lipschitz
constant of `∇f` and `normD` bounds the spectral norm of `D`. The defaults use
`lipschitz(f)` and `sqrt(opnorm(D, 1)*opnorm(D, Inf))`, without densifying a
sparse matrix. Supply known tighter bounds through `CondatVu(; L, normD)`.
Some `lipschitz` implementations, including least squares, return numerical
estimates; supply a certified `L` when the formal step guarantee is needed.
Lanczos norm estimates can help choose steps experimentally, but are not
certified upper bounds. Explicit `τ` and `σ` are checked against these bounds.
With `f = ZeroFunction()`, the method is Chambolle–Pock.

By default, every 25 iterations the solver compares the current iterate with
an average since the last restart, using a proximal KKT residual. It applies
the sufficient-decrease, stalled-decrease and long-epoch restart criteria used
by PDLP and CovarianceSelection's CLIME PDHG. At a restart, it smooths the
primal weight from the primal and dual distances traveled. The new step pair
continues to satisfy the Condat–Vũ condition. `restart = false` instead uses
normalized residual balancing when `adaptive = true`.

These rules are heuristics for general composites. The solver makes at most
`max_adaptations = 50` changes, then continues with fixed steps; the fixed-step
convergence result requires the stated convexity and global bounds. Use
`adaptive = false, restart = false` for fixed steps throughout. No Malitsky–Pock
line search or generalization of PDLP's LP rate theorem is claimed.

## Checking and reusing a solution

`res.r_norm` and `res.s_norm` measure the two KKT inclusions, using the
subgradients supplied by the proximal updates. Each is compared with an
absolute plus relative tolerance. The primal residual scales by the largest
of the gradient, adjoint product and proximal subgradient norms. The dual
residual scales by the largest of `norm(D*x)` and its proximal subgradient
norm. This prevents tiny steps from passing merely because the iterates move
little. Set `abstol` and `reltol` in `CondatVu`.

With `ProximalOptions(; gaptol > 0)`, a relative Fenchel gap replaces the
residual stopping rule. The six-argument [`duality_gap`](@ref) evaluates
conjugate values, using dual scaling for a zero smooth term and an ℓ1
penalty. An infeasible dual gives an infinite gap. Unsupported conjugates
raise an error; alternatively supply a valid relative `gap(x, y)` callback.
The final returned pair is checked even when a limit falls between scheduled
checks. Gap evaluation allocates working vectors and is excluded from the
oracle counters, as are user callbacks.

Warm start both iterates and the final step sizes:

```julia
method = CondatVu(τ = res.τ, σ = res.σ, L = L, normD = normD)
next = solve!(res.minimizer, f, next_g, h, D, method, options; y = res.y)
```

Both arrays are overwritten, so copy them if the preceding result must be
preserved. Step sizes must satisfy the bounds of the new problem.

## Quantile regression and generalized lasso

For quantile level `q`, observations `b` and design `X`, use

```julia
f = ZeroFunction()
g = NormL1(λ)
h = Scaled(Translate(CheckLoss(1 - q), b), 1 / length(b))
res = solve!(zeros(size(X, 2)), f, g, h, X, CondatVu(),
             ProximalOptions(maxiter = 500_000, gaptol = 1e-6))
centered_scores = -length(b) .* res.y
rank_scores = centered_scores .+ (1 - q)
```

The sign follows from `h(z) = mean(ρ_q(b-z))`: `res.y` is the subgradient
with respect to predictions. Centered residual scores lie in `[q-1, q]`;
adding `1-q` gives dual rank-score coordinates in `[0,1]`. Penalization
changes their moment constraints. For rank-score
tests, check dual accuracy at the required fixed quantile; objective accuracy
alone does not certify individual dual coordinates. The benchmark includes
small LP comparisons of coefficients and duals. LPs can be faster at moderate
sizes.

For generalized lasso, set `f` to a least-squares loss, `g` to the coefficient
penalty (or `ZeroFunction()`), `h = NormL1(λ)`, and `D` to a sparse difference
or incidence matrix. The example below uses second differences. For ordinary
chain TV denoising, ProximalBase's direct `TotalVariation1D` proximal operator
is the faster available route.

See [benchmark/primal_dual](https://github.com/mlakolar/ProximalSolvers.jl/tree/master/benchmark/primal_dual)
for the oracle checks and comparison with ProximalAlgorithms through the
existing adapter. Neither package is a runtime dependency.
