# A categorical predictor, such as a subscription plan, usually needs several dummy columns
# in a regression. Ordinary least squares keeps all those columns; ordinary lasso can select
# individual level contrasts. If our question is instead **which complete factors matter?**,
# group lasso can remove all the contrasts of a factor together.
#
# Here five simulated factors explain a continuous response. Only Region and Channel affect
# its conditional mean. We fit one group per factor, then compare the fitted group norms with
# the known truth. The example uses existing dense least-squares group lasso, not a formula
# interface or a new categorical-data solver.
#
#md # ![Estimated group norms by factor, colored by true relevance, with true norms shown as diamonds.](categorical_group_norms.svg)
#
# Bars show fitted coefficient norms; diamonds show the true norms. A zero bar removes the
# complete factor. Colors identify relevant (blue) and irrelevant (orange) factors in the
# simulation. Below we construct the data, fit this model, and check its numerical accuracy.
using LinearAlgebra, Random
using ProximalBase, ProximalSolvers

# ## Reference coding and the model
#
# Factor j has mⱼ levels, numbered 1 through mⱼ. **Level 1 is the reference:** its row is all
# zeros; level ℓ > 1 has a one in column ℓ − 1. A coefficient is thus a difference from the
# reference level, holding other factors fixed. We omit one column per factor to avoid the
# exact dependence between a full set of dummies and the intercept.
#
# The encoder below needs only Julia arrays. Its groups are disjoint and cover every column.
function reference_encode(levels, nlevels)
  n, q = size(levels)
  @assert q == length(nlevels) && all(m -> m >= 2, nlevels)
  @assert all(1 <= levels[i, j] <= nlevels[j] for i in 1:n, j in 1:q)
  groups = Vector{Vector{Int}}()
  D = zeros(Float64, n, sum(nlevels .- 1))
  offset = 0
  for j in 1:q
    push!(groups, collect(offset .+ (1:(nlevels[j] - 1))))
    for i in 1:n
      ell = levels[i, j]
      ell > 1 && (D[i, offset + ell - 1] = 1.0)
    end
    offset += nlevels[j] - 1
  end
  D, groups
end
colmeans(A) = vec(sum(A, dims = 1)) / size(A, 1)

# We simulate independent, uniformly distributed factors, an additive mean, and independent
# Gaussian errors with standard deviation 0.6. Every level occurs in this seeded sample.
# The intercept 2.0 is the mean response when all factors are at their reference levels.
rng = Xoshiro(410)
n = 200
factor_names = ["Region", "Plan", "Channel", "Device", "Cohort"]
nlevels = [3, 4, 5, 3, 4]
levels = hcat([rand(rng, 1:m, n) for m in nlevels]...)
D, groups = reference_encode(levels, nlevels)
p = size(D, 2)
beta_true = zeros(p)
beta_true[groups[1]] = [2.0, -1.5]
beta_true[groups[3]] = [1.8, -1.3, 1.0, -0.8]
true_relevant = [any(!iszero, beta_true[G]) for G in groups]
a_true, sigma = 2.0, 0.6
y = a_true .+ D * beta_true + sigma * randn(rng, n)

# For the model y = a + Dβ + error, the least-squares intercept at any fixed β is
# a = ȳ − d̄ᵀβ. Centering gives Z = D − 1d̄ᵀ and z = y − ȳ, so profiling out this
# **unpenalized intercept** yields the convex objective
#
# ```math
# \min_\beta\; \frac{1}{2n}\|z-Z\beta\|_2^2
#       +\lambda\sum_{j=1}^5\sqrt{|G_j|}\,\|\beta_{G_j}\|_2.
# ```
#
# The group norm couples a factor's contrasts: a zero block removes that complete factor.
# A selected block can still contain individual zero coefficients. Ordinary lasso instead
# penalizes each dummy coefficient separately and can retain only some level contrasts.
#
# We **do not standardize the dummy columns**. The coefficient norms therefore measure
# reference-level differences in response units. The default weights √|Gⱼ| account for block
# size, but do not make selection invariant to a different reference, contrast basis, scaling,
# or level frequencies. Those choices change the penalty and can change the selected factors.
dbar, ybar = colmeans(D), sum(y) / n
Z, z = D .- dbar', y .- ybar
weights = sqrt.(Float64.(length.(groups)))

# At β = 0, the loss gradient is −Zᵀz/n. All blocks can remain zero exactly when
# λ ≥ λmax = maxⱼ ‖Z[:, Gⱼ]ᵀz‖₂ / (n√|Gⱼ|). We use a fixed fraction of this threshold
# for illustration; it is not a cross-validated choice or a promise of correct selection.
lambda_max(Z, z, groups) = maximum(norm(Z[:, G]' * z) / (size(Z, 1) * sqrt(length(G))) for G in groups)
lambdamax = lambda_max(Z, z, groups)
lambda = 0.12 * lambdamax

# `LeastSquaresLoss(z, Z)` is half the residual sum of squares, so the multiplier is 1/n.
# `BlockIterate(Float64, p, g)` takes exactly the groups of the penalty, in the same order.
# Cyclic coordinate descent updates a whole block at a time; momentum is disabled here.
function fit_groups(Z, z, groups, lambda)
  g = GroupNormL2(lambda, groups)
  x = BlockIterate(Float64, size(Z, 2), g)
  result = solve!(x, (1 / size(Z, 1)) * LeastSquaresLoss(z, Z), g,
                  CDSolver(order = :cyclic, momentum = false, tol = 1e-12))
  @assert result.minimizer === x
  @assert all(collect(blockindices(x, j)) == groups[j] for j in eachindex(groups))
  (; x, beta = Vector(x), result)
end
fit = fit_groups(Z, z, groups, lambda)
beta = fit.beta
true_norms = [norm(beta_true[G]) for G in groups]
estimated_norms = [norm(beta[G]) for G in groups]
selected = findall(!iszero, estimated_norms)

# ## Which factors survive?
#
# A bar at zero means every estimated contrast for that factor is zero. Colors mark the
# known relevance in the simulation; diamonds show the true coefficient norms in this same
# reference coding. Shrinkage usually makes the fitted norms smaller than the true ones.
# This plot compares *complete factors*, rather than counting selected dummy coefficients.
# Plotting runs only in the documentation environment; the standalone script and tests do
# not load Plots. To reproduce the figure locally, run `julia --project=docs docs/make.jl`
# after installing the documentation environment.
#!jl using Plots
#!jl labels = ["$(factor_names[j])\n($(nlevels[j]) levels)" for j in eachindex(groups)]
#!jl colors = [active ? :steelblue : :darkorange for active in true_relevant]
#!jl fig = bar(1:length(groups), estimated_norms; color = colors, label = "",
#!jl           xticks = (1:length(groups), labels), ylabel = "Coefficient group norm",
#!jl           xlabel = "Categorical factor (reference level 1)",
#!jl           title = "Group lasso selects complete factors", size = (850, 420),
#!jl           ylims = (0, 1.2 * maximum(true_norms)), legend = :topright,
#!jl           bottom_margin = 6Plots.mm)
#!jl scatter!(fig, [NaN], [NaN]; marker = :rect, color = :steelblue, label = "Estimate: relevant factor")
#!jl scatter!(fig, [NaN], [NaN]; marker = :rect, color = :darkorange, label = "Estimate: irrelevant factor")
#!jl scatter!(fig, 1:length(groups), true_norms; marker = :diamond, color = :black,
#!jl          markersize = 6, label = "True norm")
#!jl savefig(fig, "categorical_group_norms.svg"); nothing

println("λmax = ", lambdamax, "; λ = 0.12 λmax = ", lambda)
println("factor    levels  contrasts  true relevance  fitted norm  selected")
for j in eachindex(groups)
  println(rpad(factor_names[j], 10), rpad(nlevels[j], 8), rpad(length(groups[j]), 11),
          rpad(true_relevant[j], 16), rpad(round(estimated_norms[j], digits = 4), 13), j in selected)
end
println("selected factors: ", factor_names[selected])

# The table and figure describe this one realization. The assertions require selected and
# unselected factors, but deliberately do not require perfect recovery of the true factors.
@assert 0 < length(selected) < length(groups)

# ## Check the encoding and restore the intercept
#
# We check the dimensions, column partition, and every encoded row. A separate probe visits
# every possible level of each factor, including the all-zero reference row, so a missing
# sample level cannot hide an encoding error.
@assert size(D) == (n, sum(nlevels .- 1)) && eltype(D) == Float64
@assert sort(reduce(vcat, groups)) == collect(1:p)
@assert all(length(groups[j]) == nlevels[j] - 1 for j in eachindex(groups))
for j in eachindex(groups)
  @assert sort(unique(levels[:, j])) == collect(1:nlevels[j])
  @assert D[:, groups[j]] == Float64.([levels[i, j] == ell for i in 1:n, ell in 2:nlevels[j]])
  probe, _ = reference_encode(reshape(collect(1:nlevels[j]), :, 1), [nlevels[j]])
  @assert all(iszero, probe[1, :])
  @assert probe[2:end, :] == Matrix{Float64}(I, nlevels[j] - 1, nlevels[j] - 1)
end
@assert norm(colmeans(Z)) <= 1e-12 && abs(sum(z) / n) <= 1e-12
ahat = ybar - dot(dbar, beta)
fitted = ahat .+ D * beta
@assert norm(fitted - (ybar .+ Z * beta), Inf) <= 1e-12
@assert abs(sum(fitted - y) / n) <= 1e-12  # intercept normal equation
println("reference-level intercept: true = ", a_true, "; estimated = ", ahat)

# ## Independent numerical validation
#
# A small change over a coordinate-descent pass (`converged`) is not an independent
# optimality certificate. We compute the objective and gradient directly from the data.
# Write h = Zᵀ(Zβ − z)/n and wⱼ = √|Gⱼ|. At the optimum, the group KKT conditions are
#
# ```math
# h_{G_j} + \lambda w_j\frac{\beta_{G_j}}{\|\beta_{G_j}\|_2}=0
# \quad (\beta_{G_j}\ne0),\qquad
# \|h_{G_j}\|_2\le\lambda w_j\quad (\beta_{G_j}=0).
# ```
#
# The largest residual below measures violation of these equations/inequalities. For this
# convex problem they certify approximate numerical optimality, not statistical correctness.
objective(Z, z, b, groups, lambda) =
  sum(abs2, Z * b - z) / (2 * size(Z, 1)) +
  lambda * sum(sqrt(length(G)) * norm(b[G]) for G in groups)
function group_kkt(Z, z, b, groups, lambda)
  grad = Z' * (Z * b - z) / size(Z, 1)
  residual = 0.0
  for G in groups
    bg, hg = b[G], grad[G]
    t = lambda * sqrt(length(G))
    violation = iszero(norm(bg)) ? max(norm(hg) - t, 0.0) : norm(hg + t * bg / norm(bg))
    residual = max(residual, violation)
  end
  residual
end
obj = objective(Z, z, beta, groups, lambda)
kkt = group_kkt(Z, z, beta, groups, lambda)
@assert all(isfinite, beta)
@assert abs(fit.result.minimum - obj) <= 1e-10 * (1 + abs(obj))
@assert kkt <= 1e-7 * max(1.0, lambdamax)
@assert sort(collect(activecoordinates(fit.x))) == selected
@assert all(isactive(fit.x, j) == (j in selected) for j in eachindex(groups))
original_obj = sum(abs2, fitted - y) / (2n) + lambda * sum(weights .* estimated_norms)
@assert abs(original_obj - obj) <= 1e-12 * (1 + abs(obj))
@assert group_kkt(Z, z, zeros(p), groups, lambdamax) <= 1e-12 * max(1.0, lambdamax)
println("passes = ", fit.result.passes, "; converged = ", fit.result.converged,
        "; independently computed objective = ", obj, "; KKT residual = ", kkt)

# A tiny control tests the zero-fit threshold through the actual solver. Its two factors
# have 3 and 4 levels, each observed, and its response is seeded noise. A small margin above
# λmax avoids deciding the boundary from floating-point rounding. Both levels return exact
# zero blocks, no active groups, and an independently checked objective and KKT residual.
let levels = hcat([mod1(i, 3) for i in 1:12], [mod1(i, 4) for i in 1:12])
  Ds, Gs = reference_encode(levels, [3, 4])
  Zs = Ds .- colmeans(Ds)'
  zs = randn(Xoshiro(411), 12); zs .-= sum(zs) / length(zs)
  lm = lambda_max(Zs, zs, Gs)
  for ls in (1.01 * lm, 2 * lm)
    control = fit_groups(Zs, zs, Gs, ls)
    @assert all(iszero, control.beta) && isempty(collect(activecoordinates(control.x)))
    @assert group_kkt(Zs, zs, control.beta, Gs, ls) <= 1e-12
    @assert abs(control.result.minimum - objective(Zs, zs, control.beta, Gs, ls)) <= 1e-12
  end
  println("tiny control: no active factor at 1.01 λmax or 2 λmax")
end

# ## Interpretation and limitations
#
# With reference coding, a zero block means no fitted mean differences between any levels
# of that factor, holding other factors fixed. It does not mean that the factor is unrelated
# to the response in every population, or that a selected factor causes the response.
#
# - The simulated mean is additive. Interactions between factors need their own modeling
#   decisions; this fit cannot discover an effect present only through an interaction.
# - Rare levels, correlated factors, and a different contrast coding can change selection.
#   Group-size weights alone do not resolve these issues.
# - The displayed norms depend on the reference coding. They summarize coefficient blocks,
#   not variance explained or a coding-independent measure of importance.
# - λ was fixed for illustration. Prediction tuning needs validation data; selected factors
#   and shrunken coefficients do not supply valid post-selection p-values or intervals.
# - The KKT check establishes optimization accuracy for the chosen objective. It cannot
#   establish recovery of the true factors from noisy observations.
#
# ## What we learned
#
# Reference coding turns factors into identifiable coefficient blocks. Centering handles a
# free intercept, and `GroupNormL2` selects those blocks together using existing group-lasso
# coordinate descent. The group-norm plot explains the selection; independent objective and
# KKT checks tell us whether the numerical fit solves the stated problem.
