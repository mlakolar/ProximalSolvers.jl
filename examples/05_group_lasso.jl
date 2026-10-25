# The group lasso, for coefficients that enter or leave the model together,
# such as the dummy variables of a factor or the basis functions of one
# covariate:
#
#     minimize  ‖y - Xβ‖² / (2n) + λ Σₖ wₖ ‖β[Gₖ]‖₂,    wₖ = √|Gₖ|.
#
# `GroupNormL2(λ, groups)` is the penalty. Its proximal operator shrinks each
# group towards zero in Euclidean norm and sets the groups with
# ‖x[Gₖ]‖₂ ≤ γλwₖ exactly to zero. Coordinate descent works on an
# `AtomIterate`, whose coordinates are the groups: each step majorizes the loss
# over one group and applies the proximal operator of its norm. The proximal
# gradient solvers take the same problem from a plain vector.

using ProximalBase, ProximalSolvers, LinearAlgebra, Random, Printf

rng = Xoshiro(5)
Random.seed!(5)
sizes = repeat([2, 3, 5, 10], 25)                 # 100 groups, 500 coefficients
ends = cumsum(sizes)
groups = [(e - s + 1):e for (s, e) in zip(sizes, ends)]
n, p = 300, sum(sizes)
X = randn(rng, n, p)
β_true = zeros(p)
for k in (1, 2, 3, 4, 50)                         # five groups, of all sizes
    β_true[groups[k]] .= 1.0
end
y = X * β_true + randn(rng, n)
f = (1 / n) * LeastSquaresLoss(y, X);

# --- Coordinate descent over groups ---
#
# For a group at zero the step is skipped while ‖∇_G f(β)‖₂ ≤ λwₖ, which is the
# optimality condition of a zero group; λmax is the largest ratio
# ‖∇_G f(0)‖₂ / wₖ.

λmax = lambda_max(f, GroupNormL2(1.0, groups), AtomIterate(p, groups))
g = GroupNormL2(0.2λmax, groups)
β = AtomIterate(p, g)                             # shares the groups of g
res = solve!(β, f, g, CDSolver(; tol = 1e-10))
selected = findall(k -> any(!iszero, β[groups[k]]), eachindex(groups))

# --- A path ---
#
# `solve_path` takes the iterate to start from; for groups it must be an
# `AtomIterate` with the groups of the penalty.

λs = λmax .* 10 .^ range(0, -1.5; length = 20)
path = solve_path(f, GroupNormL2(1.0, groups), λs; x = AtomIterate(p, groups), gaptol = 1e-10)
[count(k -> any(!iszero, b[groups[k]]), eachindex(groups)) for b in path.solutions]'

# --- By proximal gradient ---
#
# The accelerated proximal gradient method works on all coordinates at once;
# the active-set version runs it on the groups that violate the optimality
# conditions, adding and removing whole groups. Both stop on the relative
# change of the objective here, which is quadratic in the distance to the
# solution: `ftol = 1e-12` gives about six correct digits of β.

β1, β2 = zeros(p), zeros(p)
opts = ProximalOptions(; maxiter = 10_000, ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10)
r1 = solve!(β1, f, g, AccProxGradDescent(), opts)
r2 = solve!(β2, f, g, ActiveAccProxGradDescent(), opts)
@printf "coordinate descent  %4d passes       objective %.10f\n" res.passes res.minimum
@printf "accelerated         %4d iterations   objective %.10f\n" r1.iterations r1.minimum
@printf "active set          %4d iterations   objective %.10f   (%d outer)\n" r2.inner_iterations r2.minimum r2.outer_iterations

# --- Checks ---
#
# At a solution, a nonzero group satisfies ∇_G f(β) = -λwₖ β[G] / ‖β[G]‖₂, and a
# zero group ‖∇_G f(β)‖₂ ≤ λwₖ. The largest violation of these conditions:

function kkt(b, λ)
    grad = X' * (X * b - y) / n
    maximum(eachindex(groups)) do k
        G, wk = groups[k], sqrt(length(groups[k]))
        nb = norm(b[G])
        iszero(nb) ? max(norm(grad[G]) - λ * wk, 0.0) : norm(grad[G] + λ * wk * b[G] / nb)
    end
end
(cd = kkt(Vector(β), 0.2λmax), accelerated = kkt(β1, 0.2λmax), active_set = kkt(β2, 0.2λmax))

@assert res.converged && r2.converged
@assert issubset([1, 2, 3, 4, 50], selected)
@assert kkt(Vector(β), 0.2λmax) < 1e-8
@assert kkt(β1, 0.2λmax) < 1e-5 && kkt(β2, 0.2λmax) < 1e-5
@assert maximum(abs, β1 - Vector(β)) < 1e-5 && maximum(abs, β2 - Vector(β)) < 1e-5
@assert maximum(abs, path.solutions[1]) < 1e-12        # zero, up to rounding at λmax
@assert all(kkt(Vector(path.solutions[k]), λs[k]) < 1e-8 for k in eachindex(λs))
