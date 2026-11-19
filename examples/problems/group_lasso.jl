# Group lasso by block coordinate descent on a `BlockIterate`, and by proximal gradient descent
# (plain or accelerated) on a dense vector. `GroupNormL2(λ, groups)` is the
# penalty `λ Σₖ wₖ ‖β[Gₖ]‖₂` with the default weights `wₖ = √|Gₖ|`; the groups may be any
# disjoint index sets, here not contiguous. For `CDSolver` the iterate is a `BlockIterate` with the
# same groups, in the same order, and `CDSolver` updates one whole group at a time.
# `CDSolver` on a `BlockIterate`, and `ProximalGradientDescent` and `AccProxGradDescent` on a dense
# `Vector`, accept a `GroupNormL2` penalty; see [Supported problems](../../support.md) for the accepted inputs.
using LinearAlgebra, Random
using ProximalBase, ProximalSolvers

rng = Xoshiro(2024)
n, p = 60, 8
groups = [[1, 4], [2, 3, 5], [6, 7, 8]]
X = randn(rng, n, p)
beta_true = zeros(p)
beta_true[[1, 4]] .= [1.5, -1.0]       # group 1
beta_true[[6, 7, 8]] .= [0.8, 0.0, -0.8]  # group 3; group 2 is zero
y = X * beta_true + 0.1 * randn(rng, n)
s = 1 / n
f = s * LeastSquaresLoss(y, X)

# The point `β = 0` is optimal exactly when `λ` is at least the largest group score
# `s ‖X[:, Gₖ]ᵀ y‖₂ / wₖ`; the penalty level here is a quarter of it.
w = sqrt.(Float64.(length.(groups)))
scores = [s * norm(X[:, G]' * y) / w[k] for (k, G) in enumerate(groups)]
lambda = 0.25 * maximum(scores)
g = GroupNormL2(lambda, groups);

# The solver needs an iterate with the groups of the penalty; `BlockIterate(Float64, p, g)`
# takes them from `g`. With cyclic order, a full pass visits the groups in the order of their
# numbers, and an active pass visits the active groups in the order of their active slots, which
# the removal of zero groups after a pass can change.
x = BlockIterate(Float64, p, g)
res = solve!(x, f, g, CDSolver(order = :cyclic, tol = 1e-10))
@assert res.converged && res.minimizer === x
println("passes = ", res.passes, "; converged = ", res.converged)

# `x` is a vector of length `p`; the coordinates of the solver are its groups. After a solve of at
# least one pass, as here, the active coordinates are the numbers of the groups with a nonzero
# block, in no fixed order (with `maxpasses = 0` the entry state is kept, including active groups
# with a zero block). `blockindices(x, k)` lists the entries of group `k` in the order the iterate
# stores them.
beta = Vector(x)
active = sort(collect(activecoordinates(x)))
@assert active == [k for k in eachindex(groups) if any(!iszero, beta[groups[k]])]
@assert 0 < length(active) < length(groups)
for k in eachindex(groups)
  println("group ", k, ": entries ", collect(blockindices(x, k)), ", block ", beta[groups[k]],
          isactive(x, k) ? "" : "  (zero)")
end
println("active groups = ", active)

# `converged` reports that the change in a full pass was small, not that the point is optimal, so
# the solution is checked independently from the data. With `∇ = s Xᵀ(Xβ − y)`, a nonzero group
# satisfies `∇[G] + λ w β[G] / ‖β[G]‖ = 0`, and a zero group satisfies `‖∇[G]‖ ≤ λ w`.
function violation(b, k)
  grad = s * (X' * (X * b - y))
  G = groups[k]
  iszero(norm(b[G])) && return norm(grad[G]) - lambda * w[k]
  norm(grad[G] + lambda * w[k] * b[G] / norm(b[G]))
end
zero_groups = [k for k in eachindex(groups) if iszero(norm(beta[groups[k]]))]
nonzero_groups = setdiff(eachindex(groups), zero_groups)
@assert maximum(k -> violation(beta, k), nonzero_groups) <= 1e-7
@assert maximum(k -> violation(beta, k), zero_groups) <= 1e-7
println("largest violation: nonzero groups ", maximum(k -> violation(beta, k), nonzero_groups),
        ", zero groups ", maximum(k -> violation(beta, k), zero_groups))

# ## Proximal gradient descent on a dense vector
#
# `ProximalGradientDescent` solves the same problem with a dense `Vector{Float64}` as the iterate
# and the same penalty `g`. The penalty must have the element type of the data (here `Float64`)
# and its groups must partition `1:p`. Each step applies the block soft threshold to every group.
# A stop that a test proposes counts only where the solver's group KKT residual is below
# `max(gradtol, 64 eps) * S`, with `S` the larger of the largest coefficient `λ wₖ` and the largest
# group norm of `s Xᵀy`; `gradtol = 1e-10` asks for a small residual. The residual is computed
# again from the data, as above.
beta_pgd = zeros(p)
res_pgd = solve!(beta_pgd, f, g, ProximalGradientDescent(), ProximalOptions(maxiter = 20_000, gradtol = 1e-10))
@assert res_pgd.converged && res_pgd.minimizer === beta_pgd
@assert maximum(k -> violation(beta_pgd, k), eachindex(groups)) <= 1e-7
@assert [k for k in eachindex(groups) if iszero(norm(beta_pgd[groups[k]]))] == zero_groups
@assert maximum(abs, beta_pgd - beta) <= 1e-6
println("PGD: iterations = ", res_pgd.iterations, "; largest violation ",
        maximum(k -> violation(beta_pgd, k), eachindex(groups)),
        "; largest difference from the CD solution ", maximum(abs, beta_pgd - beta))

# `AccProxGradDescent()` takes the place of `ProximalGradientDescent()` in this call, with the same
# penalty and the same group stopping check, and the same independent check applies. On this problem
# the default options end the run at an increase of the objective of rounding size, before the gradient
# test with `gradtol = 1e-10` passes (`converged` is `false`), so the call sets `allow_f_increases = true`.
beta_apg = zeros(p)
res_apg = solve!(beta_apg, f, g, AccProxGradDescent(),
                 ProximalOptions(maxiter = 20_000, gradtol = 1e-10, allow_f_increases = true))
@assert res_apg.converged && maximum(k -> violation(beta_apg, k), eachindex(groups)) <= 1e-7
@assert maximum(abs, beta_apg - beta) <= 1e-6
println("APG: iterations = ", res_apg.iterations, "; largest violation ",
        maximum(k -> violation(beta_apg, k), eachindex(groups)))
