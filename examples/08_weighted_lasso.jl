# Weighted lasso with coordinate descent and with proximal gradient descent, plain and accelerated, on a
# normalized least-squares problem. The weights are those of an adaptive lasso, from a ridge pilot fit, with the
# first coefficient left unpenalized by a zero weight:
#
# ``\min_b \; \frac{1}{2n}\|y - Xb\|^2 + \lambda \sum_j w_j |b_j|``.
#
# `NormL1(λ, w)` is accepted by `CDSolver`, `ProximalGradientDescent` and `AccProxGradDescent`. The weights are a
# `Vector` of the element type of the data, finite and nonnegative, and the solvers use the coefficient `λ wⱼ`
# for entry `j`. A zero weight leaves the entry unpenalized, it does not fix it at 0. Accuracy is checked with a
# KKT residual that is computed here from X, y and the coefficients, with the coefficients `λ wⱼ`, not with the
# solvers' `converged` flags.
using LinearAlgebra, Random, ProximalBase, ProximalSolvers

rng = Xoshiro(2026)
n, p = 200, 20
X = randn(rng, n, p)
beta_true = zeros(p)
beta_true[1:4] .= [2.0, -1.5, 1.0, 0.5]
y = X * beta_true .+ 0.5 .* randn(rng, n)
f = (1 / n) * LeastSquaresLoss(y, X)

# Adaptive weights 1 / |ridge coefficient|; entry 1 is unpenalized.
pilot = (X' * X + I) \ (X' * y)
w = 1 ./ abs.(pilot)
w[1] = 0.0
lambda = 0.02
g = NormL1(lambda, w)

# The optimality condition 0 ∈ Xᵀ(Xβ - y)/n + λ w ∘ ∂|β|, as a residual: |gⱼ| - λ wⱼ clipped at 0 where βⱼ = 0 and
# |gⱼ + λ wⱼ sign βⱼ| elsewhere (for wⱼ = 0 this is |gⱼ|).
function weighted_residual(beta)
    grad = X' * (X * beta - y) / n
    maximum(j -> iszero(beta[j]) ? max(abs(grad[j]) - lambda * w[j], 0.0) : abs(grad[j] + lambda * w[j] * sign(beta[j])), 1:p)
end
objective(beta) = sum(abs2, y - X * beta) / (2n) + lambda * sum(w .* abs.(beta))

options = ProximalOptions(maxiter = 10_000, ftol = 1e-14, xtol = 1e-12, gradtol = 1e-10, allow_f_increases = true)
beta_cd, beta_pgd, beta_apg = zeros(p), zeros(p), zeros(p)
res_cd = solve!(beta_cd, f, g, CDSolver(order = :cyclic, momentum = false, tol = 1e-12))
res_pgd = solve!(beta_pgd, f, g, ProximalGradientDescent(), options)
res_apg = solve!(beta_apg, f, g, AccProxGradDescent(), options)
@assert res_cd.minimizer === beta_cd && res_pgd.minimizer === beta_pgd && res_apg.minimizer === beta_apg
for beta in (beta_cd, beta_pgd, beta_apg)
    @assert weighted_residual(beta) <= 1e-6
end
# the reported objective is the one computed from the data, up to rounding
@assert isapprox(res_cd.minimum, objective(beta_cd); rtol = 1e-10)
@assert isapprox(res_pgd.minimum, objective(beta_pgd); rtol = 1e-10)
@assert isapprox(res_apg.minimum, objective(beta_apg); rtol = 1e-10)
# the three runs reach the same point of this strongly convex problem
@assert maximum(abs, beta_cd - beta_pgd) <= 1e-5 && maximum(abs, beta_cd - beta_apg) <= 1e-5

# The zero weight leaves entry 1 unpenalized (its coefficient is that of a fit without a penalty on it), and the
# adaptive weights keep fewer entries than the unweighted lasso with the same λ.
@assert beta_cd[1] != 0
beta_lasso = zeros(p)
solve!(beta_lasso, f, NormL1(lambda), CDSolver(order = :cyclic, momentum = false, tol = 1e-12))
@assert count(!iszero, beta_cd) < count(!iszero, beta_lasso)

# Weights of another element type than the data are refused, before `x` is touched.
untouched = zeros(p)
err = try solve!(untouched, f, NormL1(lambda, Float32.(w)), CDSolver()) catch e e end
@assert err isa ArgumentError && all(iszero, untouched)

for (name, r, beta) in (("CDSolver", res_cd, beta_cd), ("ProximalGradientDescent", res_pgd, beta_pgd),
                        ("AccProxGradDescent", res_apg, beta_apg))
    println(rpad(name, 24), " iterations = ", r isa ProximalSolvers.CDResults ? r.passes : r.iterations,
            ", KKT residual = ", weighted_residual(beta), ", nonzeros = ", count(!iszero, beta))
end
println("unweighted lasso with the same λ: nonzeros = ", count(!iszero, beta_lasso))
