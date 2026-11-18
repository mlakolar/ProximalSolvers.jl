# The scaled lasso of Sun and Zhang (2012) estimates the coefficients and the noise level together by
# minimizing
#
# ```math
# L(\beta, \sigma) = \frac{\|y - X\beta\|_2^2}{2n\sigma} + \frac{\sigma}{2} + \lambda_0 \|\beta\|_1,
# \qquad \sigma > 0.
# ```
#
# For a fixed `β` with residual `r = y - X*β ≠ 0`, `L(β, σ) - L(β, σ̂) = (σ - σ̂)²/(2σ) ≥ 0` at
# `σ̂ = norm(r)/sqrt(n)`, and `L(β, σ̂) = norm(r)/sqrt(n) + λ₀‖β‖₁`. Hence a minimizer `β̂` of the
# [square-root lasso](square_root_lasso.md) at the level `λ = sqrt(n)*λ₀`, together with
# `σ̂ = norm(y - X*β̂)/sqrt(n)`, is a scaled-lasso solution when the residual of `β̂` is nonzero. The package
# has no scaled-lasso function; this page shows the computation with `SqrtLeastSquaresLoss`, `NormL1` and
# `CDSolver`, and what the solver's certificate says about the result. Penalty weights are not supported:
# the square-root lasso refuses a weighted `NormL1`, see [Supported problems](../../support.md).
using LinearAlgebra, Random, ProximalBase, ProximalSolvers

# ## The problem
#
# The data are those of the [square-root lasso](square_root_lasso.md) page: `n = 200`, `p = 50`, columns
# scaled to `sum(abs2, X[:, j]) ≈ n`, five nonzero coefficients and noise of standard deviation 0.5, from
# the same seed. The level is `λ₀ = 1.1*sqrt(2 log(2p/0.05)/n)`; it does not use the noise level. The
# solver takes the unnormalized level `λ = sqrt(n)*λ₀`, which must be positive and finite. This example
# also chooses `λ` below `λmax = ‖Xᵀy‖∞/‖y‖`, as the square-root page does, so that `β = 0` is not a
# minimizer; at or above `λmax`, `β = 0` is a minimizer, which `solve!` accepts but need not return from
# every start (see the exact fits on the square-root page).
rng = Xoshiro(2026)
n, p = 200, 50
X = randn(rng, n, p)
X ./= sqrt.(sum(abs2, X; dims = 1) ./ n)
βtrue = [[2.0, -1.5, 1.0, -1.0, 0.75]; zeros(p - 5)]
y = X * βtrue .+ 0.5 .* randn(rng, n)
λ₀ = 1.1 * sqrt(2 * log(2p / 0.05) / n)
λ = sqrt(n) * λ₀
λmax = maximum(abs, X' * y) / norm(y)
println("λ₀ = ", λ₀, ", λ = ", λ, ", λmax = ", λmax)
@assert isfinite(λ) && λ > 0
@assert λ < λmax

# ## Solving the square-root lasso
#
# The solve is the one of the square-root lasso page: cyclic coordinate descent without momentum, started
# at zero. The result reports the objective value `P(β̂) = norm(y - X*β̂) + λ*norm(β̂, 1)` (`minimum`),
# whether a duality certificate was proved (`converged`), the proved bound on the relative gap (`gap`)
# and the number of passes.
β = zeros(p)
result = solve!(β, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(order = :cyclic, momentum = false))
println("minimum = ", result.minimum, ", converged = ", result.converged, ", gap = ", result.gap,
        ", passes = ", result.passes)
@assert result.converged

# ## The noise level
#
# The residual of the returned point is computed from `X`, `y` and `β`. It is nonzero here, so
# `σ̂ = norm(r)/sqrt(n)` is the minimizer of `L(β̂, ·)` over `σ > 0`. The simulated noise level is 0.5, and
# the residual of the true coefficients gives `norm(y - X*βtrue)/sqrt(n)`; both are printed for comparison
# and are not checked.
r = y - X * β
σ̂ = norm(r) / sqrt(n)
println("norm(r)/norm(y) = ", norm(r) / norm(y))
println("σ̂ = ", σ̂, " (simulated noise level 0.5, norm(y - X*βtrue)/sqrt(n) = ",
        norm(y - X * βtrue) / sqrt(n), ")")
@assert norm(r) > 0
@assert isfinite(σ̂) && σ̂ > 0

# ## The joint objective
#
# The function below evaluates `L` in ordinary arithmetic. At `σ̂` it equals `P(β̂)/√n`, the objective
# that the solver reports divided by `√n`. The two are computed in different orders, so they agree up to
# rounding; the tolerance `1e-10` is far above the rounding of a sum of a few hundred terms in `Float64`.
# At `0.9σ̂` and `1.1σ̂` the value is larger, by `(σ - σ̂)²/(2σ)` as above.
joint_objective(X, y, λ₀, β, σ) = sum(abs2, y - X * β) / (2 * size(X, 1) * σ) + σ / 2 + λ₀ * norm(β, 1)

L̂ = joint_objective(X, y, λ₀, β, σ̂)
println("L(β̂, σ̂) = ", L̂, ", minimum/sqrt(n) = ", result.minimum / sqrt(n))
@assert isapprox(L̂, result.minimum / sqrt(n); rtol = 1e-10)
for σ in (0.9σ̂, 1.1σ̂)
    Lσ = joint_objective(X, y, λ₀, β, σ)
    println("L(β̂, ", σ / σ̂, "σ̂) - L(β̂, σ̂) = ", Lσ - L̂, " (formula: ", (σ - σ̂)^2 / (2σ), ")")
    @assert Lσ > L̂
end

# ## What the certificate says
#
# The infimum of `L` over `β` and `σ > 0` is `P*/√n`, where `P*` is the minimum of the square-root
# objective, because minimizing over `σ` first gives `P(β)/√n` for every `β` with a nonzero residual
# and `λ₀‖β‖₁` (approached as `σ ↓ 0`) for an exact fit. For `y ≠ 0` and `λ > 0` the minimum `P*` is
# positive, since `P(β) = 0` forces `y - X*β = 0` and `β = 0`. A run with `converged = true` proves
# `(P(β̂) - P*)/P* ≤ gap` and, when the residual of `β̂` is nonzero so that `σ̂ > 0`,
# `(L(β̂, σ̂) - inf L)/inf L ≤ gap` as well, with `gap ≤ 1e-4`; both hold for this page's data, where `y ≠ 0`
# and the residual was checked above. For `y = 0`, `P* = 0` is
# attained at `β = 0` with residual 0, so there is no relative gap and no `σ̂` (started at 0, the solver
# certifies `β = 0` with `gap = 0`; from a nonzero start it can end without a certificate); the exact-fit
# discussion below applies. The bound on the objective value does not say how far `σ̂` is from a
# minimizing `σ`. The square-root page
# [checks this certificate independently](square_root_lasso.md#Checking-the-answer-independently) from
# `X`, `y`, `λ` and `β`. A run with `converged = false` and `gap = NaN` has no certificate: its `σ̂` is
# then, where the residual of that point is nonzero, the minimizer of `L(β, ·)` over `σ` at that point, and the
# pair is not presented as a scaled-lasso solution.
println("relative gap bound for L(β̂, σ̂): ", result.gap)
@assert 0 <= result.gap <= 1e-4

# ## [Exact fits](@id scaled-lasso-exact-fit)
#
# Take the second exact-fit case of the square-root page, `X = [1 2; 0 1]`, `y = (1, 0)`, `λ = 0.1`,
# started at 0, so `n = 2` and `λ₀ = 0.1/sqrt(2)`. Its run is uncertified
# (see [Limitation: exact fits](square_root_lasso.md#sqrt-lasso-exact-fit) for the reason), and the point
# it returns has the stored residual `r = 0`.
X2 = [1.0 2.0; 0.0 1.0]
y2 = [1.0, 0.0]
λ2 = 0.1
λ₀2 = λ2 / sqrt(2)
β2 = zeros(2)
r2 = solve!(β2, SqrtLeastSquaresLoss(y2, X2), NormL1(λ2), CDSolver(order = :cyclic, momentum = false))
println("β = ", β2, ", converged = ", r2.converged, ", gap = ", r2.gap, ", residual = ", y2 - X2 * β2)
@assert !r2.converged && isnan(r2.gap)
@assert iszero(y2 - X2 * β2)

# At a point with `r = 0`, `L(β, σ) = σ/2 + λ₀‖β‖₁` decreases strictly as `σ` decreases and stays above
# `λ₀‖β‖₁ = P(β)/√n`, the value it approaches as `σ ↓ 0`. So `L(β, ·)` has no minimizer `σ > 0` for this
# candidate, and no positive `σ̂` is reported for it. The decreasing values below are computed with the
# `joint_objective` above.
σs = [1.0, 0.1, 0.01, 0.001]
Ls = [joint_objective(X2, y2, λ₀2, β2, σ) for σ in σs]
println("λ₀‖β‖₁ = ", λ₀2 * norm(β2, 1), ", L(β, σ) for σ = ", σs, ": ", Ls)
@assert issorted(Ls; rev = true) && allunique(Ls)
@assert all(>(λ₀2 * norm(β2, 1)), Ls)

# The run is uncertified, so this candidate is not presented as a scaled-lasso solution. What it shows is
# about this `β` only: the minimum of `L(β, ·)` over `σ > 0` is not attained. Whether the joint
# minimum of `L` over `β` and `σ > 0` is attained is not decided by this candidate, because another
# square-root lasso minimizer with a nonzero residual may exist. A very small but nonzero residual is not
# an exact fit: then `σ̂ = norm(r)/sqrt(n) > 0` is the minimizer of `L(β, ·)`.
