# Group lasso by block coordinate descent on a `BlockIterate`. `GroupNormL2(λ, groups)` is the
# penalty `λ Σₖ wₖ ‖β[Gₖ]‖₂` with the default weights `wₖ = √|Gₖ|`; the groups may be any
# disjoint index sets, here not contiguous. The iterate is a `BlockIterate` with the same groups,
# in the same order, and `CDSolver` updates one whole group at a time.
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
# takes them from `g`. Cyclic order visits the groups in the order of their numbers.
x = BlockIterate(Float64, p, g)
res = solve!(x, f, g, CDSolver(order = :cyclic, tol = 1e-10))
@assert res.converged && res.minimizer === x
println("passes = ", res.passes, "; converged = ", res.converged)

# `x` is a vector of length `p`; the coordinates of the solver are its groups. After a solve, the
# active coordinates are the numbers of the groups with a nonzero block, in no fixed order, and
# `blockindices(x, k)` lists the entries of group `k` in the order the iterate stores them.
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
grad = s * (X' * (X * beta - y))
function violation(k)
  G = groups[k]
  iszero(norm(beta[G])) && return norm(grad[G]) - lambda * w[k]
  norm(grad[G] + lambda * w[k] * beta[G] / norm(beta[G]))
end
zero_groups = [k for k in eachindex(groups) if iszero(norm(beta[groups[k]]))]
nonzero_groups = setdiff(eachindex(groups), zero_groups)
@assert maximum(violation, nonzero_groups) <= 1e-7
@assert maximum(violation, zero_groups) <= 1e-7
println("largest violation: nonzero groups ", maximum(violation, nonzero_groups),
        ", zero groups ", maximum(violation, zero_groups))
