# ProximalSolvers.jl

**Coordinate descent and (accelerated) proximal gradient descent for least-squares lasso in Julia,
and coordinate descent for the square-root lasso.**

[Documentation](https://mlakolar.github.io/ProximalSolvers.jl/dev/) ·
[Getting started](https://mlakolar.github.io/ProximalSolvers.jl/dev/getting-started/) ·
[Choosing a solver](https://mlakolar.github.io/ProximalSolvers.jl/dev/choosing-solver/) ·
[Sparsity and KKT checks](https://mlakolar.github.io/ProximalSolvers.jl/dev/sparsity-and-kkt/)

The current GitHub **development** version solves

```math
\min_{\beta}\; \frac{1}{2n}\lVert y-X\beta\rVert_2^2
 +\lambda\lVert\beta\rVert_1.
```

It uses [ProximalBase.jl](https://mlakolar.github.io/ProximalBase.jl/dev/)
for losses, penalties and coefficient storage. The registered release may
offer a different API; use the [development installation instructions](https://mlakolar.github.io/ProximalSolvers.jl/dev/getting-started/)
for the version described here.

```julia
using ProximalBase, ProximalSolvers

T = Float64                       # Float32 is also supported
X = T[1 0; 0 2; 0 0]
y = T[2, -2, 0.5]
f = (one(T) / T(length(y))) * LeastSquaresLoss(y, X)
g = NormL1(T(0.1))

beta_cd = zeros(T, size(X, 2))
cd = solve!(beta_cd, f, g, CDSolver(order=:cyclic, momentum=false))

beta_pgd = zeros(T, size(X, 2))
# allow_f_increases=true: at gradtol=1e-10 a solve can otherwise end on a computed
# objective increase (converged = false, f_increased = true)
options = ProximalOptions(maxiter=2000, ftol=1e-14,
                          xtol=1e-12, gradtol=1e-10, allow_f_increases=true)
pgd = solve!(beta_pgd, f, g, ProximalGradientDescent(), options)

beta_apg = zeros(T, size(X, 2))
apg = solve!(beta_apg, f, g, AccProxGradDescent(), options)
```

The examples use **cyclic CD without momentum for reproducible output**.
For an exploratory lasso solve, `CDSolver()` is a reasonable starting
point; it uses random coordinate order, and its results can depend on
the random number generator. Set an explicit `rng` if you want to
reproduce that order.

**For PGD and APG, `converged=true` means that a stopping test proposed a stop and
that the computed KKT residual `‖G‖∞` at the returned point is below
`max(gradtol, 64eps(T)) * max(λ, λmax)` (`λmax = α‖Xᵀy‖∞`, and `λ` the ℓ1 level of the penalty: `λ` of `NormL1(λ)`, the largest
coefficient `T(λ) * maximum(w)` of `NormL1(λ, w)`, `λ1` of `ElasticNet(λ1, λ2)`; the threshold is formed in `T`, where it can round or
overflow for a huge `gradtol`), not that the coefficients have a specified number of
correct digits.** It guarantees only that the computed, normalized residual `‖G‖∞ / max(λ, λmax)` is below
`max(gradtol, 64eps(T))`, with the threshold formed in `T`; it does not
guarantee coefficient accuracy on ill-conditioned designs. Use tighter options and independently check optimality for
results you plan to report. It is a working-precision residual, not an exact-arithmetic
certificate (see [the stationarity check](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/#The-stationarity-check-of-a-stop)). See the
[numerical guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/)
and [solver settings](https://mlakolar.github.io/ProximalSolvers.jl/dev/choosing-solver/).

CD, PGD and APG also solve the weighted least-squares lasso `λ Σⱼ wⱼ|βⱼ|` with `NormL1(λ, w)` (the square-root
lasso below takes no weights). The weights
`w` are a `Vector{T}` of the element type of the data, with one finite nonnegative entry per coefficient,
and `x` must not alias them. `solve!` checks the coefficient `T(λ) wⱼ` of entry `j`, the product rounded in `T`:
it refuses a level `T(λ)` that is subnormal in `T`, and a coefficient that overflows or that is zero or subnormal where
`T(λ)` and `wⱼ` are both positive; a zero level or a zero weight gives the coefficient 0, which is accepted.
A zero weight leaves its coefficient unpenalized (it is not fixed at 0). For PGD and APG the
stopping check scores each coordinate with its own coefficient and takes the largest one as `λ`; the
`converged` flag of CD is still the change test. Where that coefficient is used, and how ProximalBase's proximal
steps differ from it for a level that is not of type `T`, is in
[Supported problems](https://mlakolar.github.io/ProximalSolvers.jl/dev/support/#weighted-lasso-support).
For an example see [the weighted-lasso example](https://mlakolar.github.io/ProximalSolvers.jl/dev/examples/problems/weighted_lasso/)
(the script `examples/problems/weighted_lasso.jl`).

CD, PGD and APG also solve the elastic net, with `ElasticNet(λ1, λ2)` as the penalty
`λ1‖β‖₁ + (λ2/2)‖β‖₂²` (levels `λ1, λ2 ≥ 0`, unweighted); for PGD and APG the stopping check then uses the residual of the
elastic-net optimality condition, with the same bound (`λ2` does not enter it). `CDSolver` works on a dense `Vector` or a
one-dimensional `SparseIterate`; as for the lasso, its `converged` is the change test, not a KKT certificate. In the
normal range the coordinate step of a visit is ProximalBase's `prox_block` of the penalty. At a visit to a column with a
finite positive squared norm whose scaled curvature (the loss scale times that norm) or its reciprocal is below
`floatmin` of the type that combines the scale with the working type, the step with `λ2 = 0` is the lasso's range-safe
form (the threshold formed without the product or its reciprocal), and with `λ2 > 0` the visit is refused during the
pass: the iterate passed to `solve!` is unchanged and a borrowed RNG may have advanced. A visit to a flat column (all
entries 0) sets its coordinate to 0, at the levels that `solve!` accepts. With `maxpasses = 0` no coordinate is visited. See
[the elastic-net example](https://mlakolar.github.io/ProximalSolvers.jl/dev/examples/problems/elastic_net/).

PGD and APG also solve least squares with an ℓ∞ penalty, `NormLinf(λ)` (`λ max|βᵢ|`, finite `λ ≥ 0`), whose stopping
check is on the direct KKT residual of the ∞-norm's subdifferential, an ℓ1 norm, against `max(λ, ‖∇f(0)‖₁)` (see
[the ℓ∞ example](https://mlakolar.github.io/ProximalSolvers.jl/dev/examples/problems/linf_regularized_regression/)); `CDSolver`
refuses `NormLinf`.

The supported problem uses a finite dense `Matrix{T}`, finite `Vector{T}`
response and matching coefficients, where `T` is `Float32` or `Float64`.
CD additionally accepts one-dimensional ProximalBase `SparseIterate`
coefficients, and, for a group lasso, a ProximalBase `BlockIterate` with a
`GroupNormL2` penalty; PGD and accelerated PGD (`AccProxGradDescent`) accept dense
coefficients only. CD also minimizes the square-root lasso `norm(y - X*beta) + lambda * norm(beta, 1)`
with ProximalBase's `SqrtLeastSquaresLoss(y, X)` and `NormL1(lambda)`, `lambda > 0`; there
`converged = true` only when a duality certificate proves the relative gap to be at most `1e-4`, and
`gap` reports that bound. Generalized models,
sparse designs, penalty paths, ADMM and other algorithms are not part
of this development branch; see
[Supported problems](https://mlakolar.github.io/ProximalSolvers.jl/dev/support/).
The [square-root lasso example](https://mlakolar.github.io/ProximalSolvers.jl/dev/examples/problems/square_root_lasso/)
checks a solution from the data.

ProximalBase's linked `/dev/` documentation follows its evolving
`master`, while ProximalSolvers uses a **fixed dependency commit**.
Details can therefore differ; consult the
[exact pinned source and installation guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/getting-started/)
for compatibility.

For development, archival branches, exact dependency pins and CI policy,
see [CONTRIBUTING.md](CONTRIBUTING.md).
