# A lasso path: the solutions along a decreasing sequence of penalty levels,
#
#     minimize  ‖y - Xβ‖² / (2n) + λₖ ‖β‖₁,    λ₁ > λ₂ > ⋯ > λ_K,
#
# each warm started from the previous one. `solve_path` screens each level by
# the sequential strong rule of Tibshirani et al. (2012): at λₖ, the full passes
# leave out a coordinate whose gradient at the previous solution is below
# 2λₖ - λₖ₋₁ in absolute value. After convergence it checks the optimality
# conditions of the coordinates left out, and solves again if one is violated.
# A held-out set then picks λ.

using ProximalBase, ProximalSolvers, LinearAlgebra, Random, Statistics, Printf

rng = Xoshiro(2)
Random.seed!(2)
n, p = 300, 2000
X = randn(rng, n, p)
β_true = zeros(p)
β_true[[3, 30, 300, 600, 1200, 1800]] = [1.5, -1.2, 1.0, -0.8, 0.8, 0.6]
y = X * β_true + randn(rng, n)

train, valid = 1:200, 201:300
f = (1 / length(train)) * LeastSquaresLoss(y[train], X[train, :])
λmax = lambda_max(f, NormL1(1.0), SparseIterate(p))
λs = λmax .* 10 .^ range(0, -2; length = 60);

# --- The path ---

path = solve_path(f, NormL1(1.0), λs)
nonzeros = [count(!iszero, b) for b in path.solutions]
for k in (1, 10, 20, 30, 40, 50, 60)
    @printf "λ / λmax = %.3f   nonzeros %3d   passes %3d   optimality checks %d\n" path.λ[k] / λmax nonzeros[k] path.passes[k] path.kkt_checks[k]
end

# Each level starts from the solution at the level before, so it needs few
# passes, and one check of the optimality conditions, which costs one gradient.
# Each level stops once its relative duality gap is at most
# `ProximalSolvers.PATH_GAPTOL = 1e-4` (`path.gap` reports it), which puts the
# coefficients within about `1e-4` of the solution, relative to the largest.
# Screening leaves the solutions as they are: without it, the objective values
# agree to that accuracy, but every full pass visits all 2000 coordinates
# instead of those that the strong rule keeps.

unscreened = solve_path(f, NormL1(1.0), λs; screening = false)
gap = maximum(abs.(path.values .- unscreened.values) ./ path.values)
t_screened = @elapsed solve_path(f, NormL1(1.0), λs)
t_unscreened = @elapsed solve_path(f, NormL1(1.0), λs; screening = false)
(gap = gap, seconds_screened = t_screened, seconds_unscreened = t_unscreened)

# --- Choosing λ on held-out data ---
#
# `callback(k, λ, x, m)` runs after each level, with the solution `x` and the
# model `m` of the loss. Here it records the validation error, and stops the
# path once the error is 10% above its minimum.

Xv, yv = X[valid, :], y[valid]
errors = Float64[]
function validate(k, λ, x, m)
    push!(errors, mean(abs2, yv - Xv * Vector(x)))
    errors[end] > 1.1 * minimum(errors)
end
stopped = solve_path(f, NormL1(1.0), λs; callback = validate)
best = argmin(errors)
(levels_solved = length(stopped.λ), best_λ = stopped.λ[best] / λmax,
 support = findall(!iszero, stopped.solutions[best]))

# --- Checks ---
#
# Every level is certified to the gap target, the optimality conditions hold to
# that accuracy, and screening changes nothing beyond it: two solutions within
# a relative gap ε of the optimum have objective values within ε of each other.

Xt, yt = X[train, :], y[train]
function kkt(b, λ)
    grad = Xt' * (Xt * b - yt) / length(train)
    maximum(k -> iszero(b[k]) ? max(abs(grad[k]) - λ, 0.0) : abs(grad[k] + λ * sign(b[k])), eachindex(b))
end
@assert maximum(abs, path.solutions[1]) < 1e-12        # zero, up to rounding at λmax
@assert all(path.gap .<= ProximalSolvers.PATH_GAPTOL) && all(unscreened.gap .<= ProximalSolvers.PATH_GAPTOL)
@assert all(kkt(Vector(path.solutions[k]), λs[k]) < 1e-3 * λmax for k in eachindex(λs))
@assert gap <= 1.01 * ProximalSolvers.PATH_GAPTOL
@assert length(stopped.λ) < length(λs)
@assert issubset(findall(!iszero, β_true), findall(!iszero, stopped.solutions[best]))
