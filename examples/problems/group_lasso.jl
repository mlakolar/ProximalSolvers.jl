# Some predictors belong together: several basis functions can describe one curve,
# or several indicators can describe one categorical factor. Selecting individual
# coefficients may break that structure. Group lasso penalizes each coefficient
# block by its Euclidean norm, encouraging entire groups to become zero together.
# The figure compares the sizes of the true and fitted groups in a small simulation.
#
#md # ![True and fitted coefficient norms for three predefined groups; groups one and three contain simulated signal.](group_lasso.svg)
#
# Group lasso by block coordinate descent on a `BlockIterate`, and by proximal gradient descent
# (plain or accelerated) on a dense vector. `GroupNormL2(λ, groups)` is the
# penalty `λ Σₖ wₖ ‖β[Gₖ]‖₂` with the default weights `wₖ = √|Gₖ|`; the groups may be any
# disjoint index sets, here not contiguous. For `CDSolver` the iterate is a `BlockIterate` with the
# same groups, in the same order, and `CDSolver` updates one whole group at a time.
# `CDSolver` on a `BlockIterate`, and `ProximalGradientDescent` and `AccProxGradDescent` on a dense
# `Vector`, accept a `GroupNormL2` penalty; see [Supported problems](../../support.md) for the accepted inputs.
# ## The statistical objective
#
# For a zero-intercept regression ``y=X\beta+\varepsilon``, minimize
#
# ```math
# \frac{1}{2n}\|y-X\beta\|_2^2+\lambda\sum_k w_k\|\beta_{G_k}\|_2.
# ```
#
# The disjoint groups partition the predictors. The default weights
# ``w_k=\sqrt{|G_k|}`` account for different group sizes. We simulate 60 independent
# observations, eight independent standard-normal predictors, and noise with
# standard deviation 0.1. Groups 1 and 3 carry signal; group 2 is irrelevant.
#
# ## Simulating and fitting the grouped model
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

# ## Reading the group-norm figure
#
# A zero fitted norm removes a whole group. A positive norm keeps the group, but
# does not imply that every coefficient in it is scientifically important: the
# third simulated group even contains one coefficient whose true value is zero.
# The shorter estimated bars show the shrinkage induced by regularization.
#!jl using Plots
#!jl primary_figure = bar(hcat((1:length(groups)) .- 0.18, (1:length(groups)) .+ 0.18),
#!jl   hcat([norm(beta_true[G]) for G in groups],
#!jl   [norm(beta[G]) for G in groups]); bar_width=0.34, label=["True group norm" "Estimated group norm"],
#!jl   color=[:gray :royalblue], xlabel="Predictor group", ylabel="Euclidean coefficient norm",
#!jl   xticks=(1:3, ["1: signal" "2: noise" "3: signal"][:]),
#!jl   title="Group lasso selects coefficient blocks", legend=:outertopright, size=(900, 430))
#!jl savefig(primary_figure, "group_lasso.svg")
#!jl nothing

# ## Independent objective and group KKT checks
#
# `converged` reports that the change in a full pass was small, not that the point is optimal, so
# the solution is checked independently from the data. With `∇ = s Xᵀ(Xβ − y)`, a nonzero group
# satisfies `∇[G] + λ w β[G] / ‖β[G]‖ = 0`, and a zero group satisfies `‖∇[G]‖ ≤ λ w`.
function violation(b, k)
  grad = s * (X' * (X * b - y))
  G = groups[k]
  iszero(norm(b[G])) && return norm(grad[G]) - lambda * w[k]
  norm(grad[G] + lambda * w[k] * b[G] / norm(b[G]))
end
group_objective(b) = sum(abs2, y - X * b) / (2n) +
                     lambda * sum(w[k] * norm(b[groups[k]]) for k in eachindex(groups))
@assert isapprox(res.minimum, group_objective(beta); rtol=1e-10)
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
@assert isapprox(res_pgd.minimum, group_objective(beta_pgd); rtol=1e-10)
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
@assert isapprox(res_apg.minimum, group_objective(beta_apg); rtol=1e-10)
@assert res_apg.converged && maximum(k -> violation(beta_apg, k), eachindex(groups)) <= 1e-7
@assert maximum(abs, beta_apg - beta) <= 1e-6
println("APG: iterations = ", res_apg.iterations, "; largest violation ",
        maximum(k -> violation(beta_apg, k), eachindex(groups)))

# ## One group is the Euclidean norm
#
# With a single group that holds every coefficient and weight one, the group penalty is
# `λ ‖β‖₂`. ProximalBase's `NormL2(λ)` is that penalty, accepted by `ProximalGradientDescent`
# and `AccProxGradDescent` on a dense vector. The two penalties define the same
# objective, and the proximal operations can round differently. In exact arithmetic
# the zero vector minimizes the objective when `λ ≥ s ‖Xᵀy‖₂`. We use one quarter
# of this threshold to obtain a nonzero fit.
lambda_one = 0.25 * s * norm(X' * y)

# Near the solution, rounding can make the computed objective increase.
# Allowing increases lets the solver continue in that case. We check both fits
# against the stationarity condition below.
options_one = ProximalOptions(maxiter = 20_000, gradtol = 1e-10, allow_f_increases = true)
beta_l2 = zeros(p)
solve!(beta_l2, f, NormL2(lambda_one), ProximalGradientDescent(), options_one)
beta_one = zeros(p)
solve!(beta_one, f, GroupNormL2(lambda_one, [collect(1:p)], [1.0]),
       ProximalGradientDescent(), options_one)
@assert !iszero(beta_l2) && !iszero(beta_one)
@assert maximum(abs, beta_l2 - beta_one) <= 1e-6

# The Euclidean-norm optimality condition is checked from the data: at a nonzero point,
# `s Xᵀ(Xβ − y) + λ β / ‖β‖₂ = 0`.
one_group_violation(b) = norm(s * (X' * (X * b - y)) + lambda_one * b / norm(b))
violation_one = max(one_group_violation(beta_l2), one_group_violation(beta_one))
@assert violation_one <= 1e-7
println("one group: largest difference between NormL2 and GroupNormL2 ", maximum(abs, beta_l2 - beta_one),
        "; largest violation ", violation_one)

# ## Limitations
#
# Group selection depends on the chosen grouping, predictor scaling, and penalty
# level. A block penalty does not select variables within a retained block. Overlapping
# groups are outside this example's supported partition, and a small KKT residual
# certifies the optimization rather than the scientific relevance of a group.
#
# ## What we learned
#
# Replacing individual magnitudes by block norms changes the unit of selection from
# a coefficient to a predefined group. The figure reports that selection at the
# group level; the independent checks apply the corresponding block conditions.
