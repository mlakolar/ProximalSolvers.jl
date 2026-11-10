# The proximal gradient solvers, on the lasso
#
#     minimize  ‖b - Aβ‖² / 2 + γ ‖β‖₁.
#
# They need only the gradient of the smooth part and the proximal operator of
# the penalty, so they take any pair of functions of ProximalBase that provide
# them. Each iteration is a gradient step followed by soft thresholding,
#
#     β ← prox_{γ‖⋅‖₁/L}(β - ∇f(β)/L),
#
# with the step 1/L found by backtracking. `AccProxGradDescent` adds momentum,
# with restarts, and `ActiveAccProxGradDescent` runs it on a growing set of
# coordinates, those that violate the optimality conditions.

using ProximalBase, ProximalSolvers, LinearAlgebra, Random, Printf

rng = Xoshiro(10)
n, p = 300, 1000
β_true = (rand(rng, p) .< 0.05) .* randn(rng, p)      # about 50 nonzeros
A = randn(rng, n, p)
A ./= map(norm, eachcol(A))'                           # unit-norm columns
b = A * β_true + 0.03 * randn(rng, n)

f = LeastSquaresLoss(b, A)                              # ‖b - Aβ‖² / 2
γ = 0.02 * norm(A' * b, Inf)                            # β = 0 for γ ≥ ‖A'b‖∞
g = NormL1(γ)
options = ProximalOptions(; maxiter = 5000, ftol = 1e-12, xtol = 1e-10, gradtol = 1e-8);

# --- Three solvers ---
#
# Each overwrites its starting point with the solution. The results count the
# iterations and the evaluations of f, of its gradient and of the proximal
# operator. Each solver runs twice, and the second run is timed.

solvers = ["proximal gradient" => ProximalGradientDescent(), "accelerated" => AccProxGradDescent(),
           "active set" => ActiveAccProxGradDescent()]
fits = map(solvers) do (name, solver)
    local β, res
    for _ in 1:2
        β = zeros(p)
        res = solve!(β, f, g, solver, options)
    end
    t = @elapsed solve!(zeros(p), f, g, solver, options)
    iterations = solver isa ActiveAccProxGradDescent ? res.inner_iterations : res.iterations
    @printf "%-18s %5d iterations   %6.1f ms   objective %.10f\n" name iterations 1000t res.minimum
    (β = β, res = res)
end;
β1, β2, β3 = (fit.β for fit in fits)
r1, r2, r3 = (fit.res for fit in fits);

# Momentum cuts the iterations of proximal gradient descent about in half. The
# active-set solver takes more iterations, but they are on the coordinates of
# the active set only, a few times the size of the support, so they cost a
# fraction of those of the other two, which multiply by all of A. The results
# of the accelerated method:

r2

# --- Watching the iterations ---
#
# `store_trace = true` records the objective and the step size 1/L of every
# iteration. The accelerated method restarts its momentum when the objective
# would increase, so the objective never goes up; the backtracking lets the
# step grow again after each iteration, by the factor 1/α.

tr = solve!(zeros(p), f, g, AccProxGradDescent(), ProximalOptions(; maxiter = 5000, ftol = 1e-12, store_trace = true)).trace
objective = [s.fg_x for s in tr]
for k in filter(<=(length(tr)), [1, 2, 5, 10, 20, 40, 60])
    @printf "iteration %3d   objective %.10f   step %.3f\n" k objective[k] 1 / tr[k].L
end

# --- Single precision and sparse iterates ---
#
# The solvers work in the element type of the starting point. In `Float32` the
# tolerances must stay above its precision, `eps(Float32) ≈ 1.2e-7`, and the
# objective, computed in single precision, stops improving when β is correct to
# about three digits. A `SparseIterate` as the starting point keeps the
# iterates sparse, and the products by them cost O(n) per stored entry.

f32 = LeastSquaresLoss(Float32.(b), Float32.(A))
β32 = zeros(Float32, p)
r32 = solve!(β32, f32, NormL1(Float32(γ)), AccProxGradDescent(), ProximalOptions(; maxiter = 5000, ftol = 1e-6))
βs = SparseIterate(p)
rs = solve!(βs, f, g, AccProxGradDescent(), options)
(float32_error = norm(β32 - β2, Inf), sparse_iterate_error = norm(Vector(βs) - β2, Inf), stored = nactive(βs))

# --- Checks ---
#
# The optimality conditions of the lasso: ∇f(β) = A'(Aβ - b) satisfies
# ∇ₖf(β) = -γ sign(βₖ) where βₖ ≠ 0, and |∇ₖf(β)| ≤ γ where βₖ = 0.

function kkt(β)
    grad = A' * (A * β - b)
    maximum(k -> iszero(β[k]) ? max(abs(grad[k]) - γ, 0.0) : abs(grad[k] + γ * sign(β[k])), 1:p)
end
@assert kkt(β1) < 1e-6 && kkt(β2) < 1e-6 && kkt(β3) < 1e-6
@assert norm(β1 - β2, Inf) < 1e-5 && norm(β3 - β2, Inf) < 1e-5
@assert r3.converged && r2.iterations < r1.iterations && r2.f_calls >= r2.iterations
@assert all(diff(objective) .<= 1e-12)
@assert norm(β32 - β2, Inf) < 1e-2 && norm(Vector(βs) - β2, Inf) < 1e-6
