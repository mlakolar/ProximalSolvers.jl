# Least squares with an ℓ∞ penalty, with proximal gradient descent and accelerated proximal
# gradient descent:
#
# ``\min_b \; \frac{1}{2n}\|y - Xb\|^2 + \lambda \|b\|_\infty, \qquad \|b\|_\infty = \max_j |b_j|.``
#
# `NormLinf(λ)` is accepted by `ProximalGradientDescent` and `AccProxGradDescent`. `CDSolver` refuses it:
# this `CDSolver` needs a separable penalty for its coordinate oracle, and `NormLinf` is not separable.
# Where `NormL1` penalizes the sum of the magnitudes of the coefficients and tends to give zeros,
# `NormLinf` penalizes the largest magnitude. Its proximal operator clips the entries at a common level, which
# can tie several of the largest coefficients at the maximum (as in the problems below, not for every
# problem), and it does not in general give zeros.
#
# A solve declares convergence only when the proximal-gradient mapping at the accepted iterate is small, with the
# ℓ1 norm of the mapping measured against `max(λ, ‖∇f(0)‖₁)`; `‖∇f(0)‖₁` is the smallest level for which 0 is a
# minimizer. (A solve can also end through a limit, an objective increase or stagnation without passing that check.)
# Accuracy below is checked with the objective and a duality gap computed from X and y, not with the `converged` flags.
using LinearAlgebra, Random, ProximalBase, ProximalSolvers

# ## Part A: an analytic case
#
# For `X = [1 1]`, `y = [2]` and `λ = 1` the objective is
# ``(2 - b_1 - b_2)^2/2 + \max(|b_1|, |b_2|)``. At the minimizer `b_1 = b_2 = s` (spreading a fixed sum over
# two coefficients lowers the maximum), and `(2 - 2s)^2/2 + s` is minimized at `s = 3/4`:
# `β* = (0.75, 0.75)` with `P* = 0.875`. The lasso objective with the same data,
# ``(2 - b_1 - b_2)^2/2 + |b_1| + |b_2|``, depends on the sum only for `b ≥ 0`, so every `b ≥ 0` with
# `b_1 + b_2 = 1` minimizes it: the ℓ1 penalty does not prefer the balanced point.
X1, y1 = [1.0 1.0], [2.0]
f1, g1 = LeastSquaresLoss(y1, X1), NormLinf(1.0)
options1 = ProximalOptions(maxiter = 10_000, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-12, allow_f_increases = true)
for method in (ProximalGradientDescent(), AccProxGradDescent()), start in ([0.0, 0.0], [3.0, -2.0])
  b = copy(start)
  r = solve!(b, f1, g1, method, options1)
  @assert r.converged && r.minimizer === b
  @assert maximum(abs, b - [0.75, 0.75]) <= 1e-9
  @assert abs(r.minimum - 0.875) <= 1e-12
end

# ## Part B: a seeded correlated problem
#
# `n = 200` observations and `p = 40` predictors with correlation `0.7^|i-j|` between predictors `i` and
# `j` (an AR(1) design), a known coefficient vector with six large coefficients of similar size, and Gaussian noise.
rng = Xoshiro(2026)
n, p = 200, 40
X = randn(rng, n, p)
for j in 2:p                      # neighbouring columns with correlation 0.7
  X[:, j] .= 0.7 .* X[:, j - 1] .+ sqrt(1 - 0.7^2) .* X[:, j]
end
beta_true = zeros(p)
beta_true[1:6] .= [2.0, 1.8, -1.9, 1.7, -2.0, 1.6]
y = X * beta_true .+ 0.5 .* randn(rng, n)
f = (1 / n) * LeastSquaresLoss(y, X)

# The level is a fraction of ``\lambda_{crit} = \|\nabla f(0)\|_1 = \|X^T y\|_1 / n``, above which the
# solution is 0. (The lasso threshold is the smaller ``\|\nabla f(0)\|_\infty``, which does not apply.)
lambda_crit = norm(X' * y, 1) / n
lambda = 0.3 * lambda_crit
g = NormLinf(lambda)

# The objective from the data, and a duality gap. For `u = (Xb - y)/n` scaled by `min(1, λ/‖Xᵀu‖₁)`, the
# dual objective is ``-y^T u - n\|u\|^2/2``, which is at most the optimal value; the gap is the
# primal value minus it, and it is nonnegative.
objective(b) = sum(abs2, y - X * b) / (2n) + lambda * maximum(abs, b)
function duality_gap(b)
  u = (X * b - y) / n
  u *= min(1, lambda / norm(X' * u, 1))
  objective(b) - (-dot(y, u) - n * dot(u, u) / 2)
end

options = ProximalOptions(maxiter = 20_000, ftol = 1e-14, xtol = 1e-12, gradtol = 1e-9, allow_f_increases = true)
results = Pair{String, Any}[]
betas = Vector{Float64}[]
for (name, method) in (("ProximalGradientDescent", ProximalGradientDescent()), ("AccProxGradDescent", AccProxGradDescent()))
  b = zeros(p)
  r = solve!(b, f, g, method, options)
  push!(results, name => r)
  push!(betas, b)
  @assert r.converged && r.minimizer === b
  @assert isapprox(r.minimum, objective(b); rtol = 1e-10)          # the reported objective is the one from the data
  @assert duality_gap(b) >= -1e-12                                    # weak duality
  @assert duality_gap(b) <= 1e-8 * objective(b)                       # an independent optimality certificate
end
@assert maximum(abs, betas[1] - betas[2]) <= 1e-3                    # both reach the same point, up to the gap's accuracy

# In this problem the ℓ∞ solution has no zero coefficient, and several of its largest coefficients are tied at the maximum.
for ((name, r), b) in zip(results, betas)
  top = maximum(abs, b)
  at_max = count(c -> abs(c) >= (1 - 1e-6) * top, b)
  @assert at_max >= 2 && count(iszero, b) == 0
  println(rpad(name, 24), " objective = ", round(r.minimum; digits = 8), ", iterations = ", r.iterations,
          ", f/grad/prox calls = ", r.f_calls, "/", r.grad_calls, "/", r.prox_calls,
          ", max|b| = ", round(top; digits = 6), ", coefficients at the maximum = ", at_max,
          ", zeros = ", count(iszero, b), ", duality gap = ", duality_gap(b))
end
println("lambda = ", round(lambda; digits = 6), ", lambda_crit = ", round(lambda_crit; digits = 6),
        "; max|b_true| = ", maximum(abs, beta_true))
