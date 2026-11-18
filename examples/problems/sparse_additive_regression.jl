# Sparse additive regression with a finite spline basis, fitted as a group lasso. The model is
# `y = a + Σⱼ fⱼ(xⱼ) + ε` with one unknown function `fⱼ` per predictor, and the aim is to select
# the predictors whose functions are not zero. Each `fⱼ` is written in a small fixed basis on
# `[0, 1]`, `fⱼ(x) = Σₖ bⱼₖ Bₖ(x)`, and the coefficients `bⱼ` of one predictor form one group.
# The fit minimizes
#
# `(1/(2n)) ‖z − Z b‖² + λ Σⱼ wⱼ ‖b[Gⱼ]‖₂`,  `wⱼ = √|Gⱼ|`,
#
# where `z = y − mean(y)` and `Z` has one centered, orthonormalized block of columns per
# predictor. The squared loss is `(1/n)` times ProximalBase's `LeastSquaresLoss(z, Z)`, which is
# `‖z − Z b‖²/2`. The penalty is `GroupNormL2(λ, groups)` with its default weights, the
# iterate is a `BlockIterate`, and the solver is `CDSolver` with cyclic order; this is the group
# lasso row of [Supported problems](../../support.md). The basic use of these types is explained in
# [Group lasso](group_lasso.md), and this page does not repeat it. The ordinary lasso is
# [Lasso](lasso.md).
#
# What is penalized is the coefficient vector of each block in the orthonormal representation
# built below. In that representation `‖bⱼ‖₂` is the empirical norm of the fitted component of
# predictor `j` on the sample, which is the penalty of the sparse additive model of Ravikumar,
# Lafferty, Liu and Wasserman (2009), *Sparse additive models*, restricted to a fixed finite
# basis; they note that a basis expansion of their model leads to a group lasso. This page is a
# finite-basis group-lasso approximation, not their procedure: that procedure fits each
# component nonparametrically, with smoothers in backfitting, while here each component is
# confined to the span of a fixed set of four piecewise-linear functions. The page shows what the
# group lasso does on such a basis, on one simulated data set.
using LinearAlgebra, Random
using ProximalBase, ProximalSolvers

# `Statistics` is not a dependency of this project, so the mean is a one-line function.
avg(v) = sum(v) / length(v)

# ## The basis
#
# The basis on `[0, 1]` is piecewise linear, `B(x) = [x, (x − 0.25)₊, (x − 0.5)₊, (x − 0.75)₊]`
# with `K = 4` columns. It has no constant column. A combination of the columns whose value is
# constant on `[0, 1]` has slope zero on `[0, 0.25]`, which forces the coefficient of `x` to be
# zero, and then the slope zero on each next interval forces the other coefficients to be zero.
# On the sample, a combination is constant exactly when it takes one value at all sample points,
# and a function that is linear on an interval and takes one value at two distinct points of it
# has slope zero there. The centered columns are therefore linearly independent when the sample
# has at least two distinct points in each of the four intervals, which the rank check below
# confirms for this data.
knots = [0.25, 0.5, 0.75]
K = 1 + length(knots)
basismatrix(x) = hcat(x, (max.(x .- t, 0) for t in knots)...)

# ## Data
#
# There are `n = 200` observations of `p = 6` independent predictors, uniform on `[0, 1]`. The
# generating functions of predictors 1, 2 and 4 are nonlinear, and the functions of predictors
# 3, 5 and 6 are identically zero. The intercept is `a = 1` and the noise has standard
# deviation `0.3`.
rng = Xoshiro(370)
n, p = 200, 6
sigma = 0.3
a_true = 1.0
truth = [x -> 2sin(2π * x), x -> 6(x - 0.5)^2, x -> 0.0, x -> 1.5cos(3π * x), x -> 0.0, x -> 0.0]
true_groups = [1, 2, 4]
X = rand(rng, n, p)
mu = a_true .+ sum(truth[j].(X[:, j]) for j in 1:p)       # the regression function at the sample
y = mu + sigma * randn(rng, n)
@assert all(isfinite, y)

# ## The design matrix
#
# For predictor `j`, `B̃ⱼ = B(X[:, j]) − mⱼ` is the basis matrix with its column means `mⱼ`
# removed, and `B̃ⱼ = Qⱼ Rⱼ` is its thin QR factorization. The block is `Zⱼ = √n Qⱼ`, so that
# `Zⱼᵀ Zⱼ / n = I` up to rounding. Its columns have mean zero because `Qⱼ = B̃ⱼ Rⱼ⁻¹` is a
# combination of centered columns. With `Zⱼ bⱼ` the fitted component on the sample,
# `‖Zⱼ bⱼ‖²/n = ‖bⱼ‖²`: the penalty `‖bⱼ‖₂` is the empirical L2 norm of the fitted component of
# predictor `j` on the training sample.
means, Rs, blocks = Vector{Float64}[], Matrix{Float64}[], Matrix{Float64}[]
for j in 1:p
  B = basismatrix(X[:, j])
  m = vec(sum(B, dims = 1)) / n
  F = qr(B .- m')
  Q, R = Matrix(F.Q), Matrix(F.R)
  @assert size(Q) == (n, K) && size(R) == (K, K)
  @assert rank(B .- m') == K && minimum(abs, diag(R)) > 1e-3     # the centered block has full rank
  @assert norm(B .- m' - Q * R) <= 1e-12 * norm(B)
  push!(means, m); push!(Rs, R); push!(blocks, sqrt(n) * Q)
end
Z = hcat(blocks...)
@assert size(Z) == (n, p * K)
for j in 1:p
  @assert norm(blocks[j]' * blocks[j] / n - I) <= 1e-12
  @assert maximum(abs, sum(blocks[j], dims = 1)) / n <= 1e-12
end
println("worst condition number of a centered block: ",
        round(maximum(cond(basismatrix(X[:, j]) .- means[j]') for j in 1:p), digits = 1))

# The fitted component of predictor `j` at a new point `x` is read from the coefficients through
# the same transformation, `f̂ⱼ(x) = √n (B(x) − mⱼ)ᵀ Rⱼ⁻¹ bⱼ`, because
# `Zⱼ bⱼ = √n Qⱼ bⱼ = √n B̃ⱼ Rⱼ⁻¹ bⱼ`. At the training points it must reproduce `Zⱼ bⱼ`.
groups = [collect(((j - 1) * K + 1):(j * K)) for j in 1:p]
@assert reduce(vcat, groups) == collect(1:(p * K))        # disjoint, in order, covering 1:pK
component(j, b, x) = sqrt(n) * ((basismatrix(x) .- means[j]') * (Rs[j] \ b[groups[j]]))
predict(b, Xnew) = avg(y) .+ sum(component(j, b, Xnew[:, j]) for j in 1:p)

# ## The problem and its penalty levels
#
# The response is centered, `z = y − mean(y)`. Each of the `pK` columns of `Z` has mean zero, so for a fixed
# `b` the minimizer over the intercept `a` of `‖y − a − Z b‖²/(2n)` is `a = mean(y)` and the
# minimum is `‖z − Z b‖²/(2n)`; the intercept of the full fit is `mean(y)`. The group
# optimality condition at `b = 0` is `‖Zⱼᵀ z‖₂/n ≤ λ wⱼ` for each `j`; the problem is convex, so
# `b = 0` is a minimizer when `λ` is at least `λmax = maxⱼ ‖Zⱼᵀ z‖₂ / (n wⱼ)`.
z = y .- avg(y)
@assert abs(sum(z)) <= 1e-12 * n
f = (1 / n) * LeastSquaresLoss(z, Z)
w = fill(sqrt(K), p)
scores = [norm(blocks[j]' * z) / (n * w[j]) for j in 1:p]
lambdamax = maximum(scores)
println("scores = ", round.(scores, digits = 4), "; λmax = ", round(lambdamax, digits = 4))

# The objective and the group optimality conditions are computed here from the data. With
# `g = Zᵀ(Z b − z)/n`, a nonzero group satisfies `g[G] + λ w b[G]/‖b[G]‖ = 0`, and a zero group
# satisfies `‖g[G]‖ ≤ λ w`. The function returns the largest violation over the nonzero groups,
# `‖g[G] + λ w b[G]/‖b[G]‖‖`, and over the zero groups, `max(‖g[G]‖ − λ w, 0)`.
objective(b, lambda) = norm(z - Z * b)^2 / (2n) + lambda * sum(w[j] * norm(b[groups[j]]) for j in 1:p)
function violations(b, lambda)
  grad = Z' * (Z * b - z) / n
  nz, zr = 0.0, 0.0
  for j in 1:p
    G = groups[j]
    if iszero(norm(b[G]))
      zr = max(zr, norm(grad[G]) - lambda * w[j])
    else
      nz = max(nz, norm(grad[G] + lambda * w[j] * b[G] / norm(b[G])))
    end
  end
  nz, zr
end

# The solver tolerance `1e-12` is a threshold on the change of the coefficients over a pass,
# relative to the scale of the response, and `converged` reports that the change test
# passed. The optimality statements below rest on `violations`. Its tolerance `1e-9 λ` is a
# choice made small against the penalty level; the printed violations are the measured values.
function fit(lambda)
  g = GroupNormL2(lambda, groups)
  x = BlockIterate(Float64, p * K, g)
  res = solve!(x, f, g, CDSolver(order = :cyclic, momentum = false, tol = 1e-12))
  @assert res.minimizer === x
  b = Vector(x)
  @assert all(isfinite, b)
  active = sort(collect(activecoordinates(x)))
  @assert active == [j for j in 1:p if any(!iszero, b[groups[j]])]   # active groups = nonzero blocks
  @assert all(collect(blockindices(x, j)) == groups[j] for j in 1:p)
  (; b, active, res, g)
end

# ## At and above `λmax`
#
# Three statements are checked. First, from the data alone: `maximum(scores) <= lambdamax` holds
# by construction, and `b = 0` satisfies the zero-group condition at `λ = λmax`, up to the
# rounding of two different evaluations of the same group score (`violations` computes the
# gradient of the whole design, `scores` the block product).
#
# Second, the solver at `λ = λmax`. There `b = 0` is a minimizer, but the solver compares its
# own evaluation of the group score with `λ wⱼ` at the rounding level, so a block of the size
# of the rounding error can survive, and whether it does depends on the summation order of the
# platform. The check therefore asserts a rounding-level result: each block norm is at most
# `1e-12`, where the coefficients are of order one on this data, and the optimality violations
# are at most `1e-12 λ`.
#
# Third, at `λ = (1 + 10⁻⁶) λmax` and at `λ = 1.5 λmax` the solver returns exact zeros and
# reports no active group. The margin of `10⁻⁶` in relative size is far above rounding, which
# keeps the comparison away from the boundary.
@assert maximum(scores) <= lambdamax
nz0, zr0 = violations(zeros(p * K), lambdamax)
@assert nz0 == 0 && zr0 <= 1e-12 * lambdamax
r = fit(lambdamax)
largest = maximum(norm(r.b[G]) for G in groups)
nz, zr = violations(r.b, lambdamax)
@assert largest <= 1e-12 && nz <= 1e-12 * lambdamax && zr <= 1e-12 * lambdamax
println("at λ = λmax: zero-group violation of b = 0 ", zr0, "; solver: largest block norm ", largest,
        ", violations ", nz, " and ", zr)
for lambda in ((1 + 1e-6) * lambdamax, 1.5 * lambdamax)
  r = fit(lambda)
  @assert isempty(r.active) && all(iszero, r.b)
end
println("all blocks are exactly zero at λ = (1 + 1e-6) λmax and at λ = 1.5 λmax")

# ## Three penalty levels
#
# The levels are fixed fractions of `λmax`. For each, the page checks the objective reported by
# the solver against `objective`, the identity between the centered and the original-scale
# objectives, the optimality conditions, and the reconstruction of the fitted signal from the
# components. It then reports the selected groups and the error of the fitted regression function
# on `2000` fresh points, which is measured against the true regression function, not against the
# noisy response. The noise variance is `σ² = 0.09`. The error of the constant fit `b = 0`, which
# is the fit at `λmax`, is printed first for reference; an estimate that equals the truth has
# error 0.
Xnew = rand(Xoshiro(371), 2000, p)
munew = a_true .+ sum(truth[j].(Xnew[:, j]) for j in 1:p)
err(b) = avg((predict(b, Xnew) - munew) .^ 2)
println("error of the constant fit (b = 0): ", round(err(zeros(p * K)), digits = 4))

fractions = [0.3, 0.1, 0.02]
fits = []
for frac in fractions
  lambda = frac * lambdamax
  r = fit(lambda)
  b = r.b

  ## the reported objective against the independent one
  obj = objective(b, lambda)
  @assert abs(r.res.minimum - obj) <= 1e-10 * (1 + abs(obj))

  ## the intercept: at `a = mean(y)` the derivative in `a` is zero, and the original-scale
  ## objective equals the centered one
  orig(a) = norm(y .- a .- Z * b)^2 / (2n) + lambda * sum(w[j] * norm(b[groups[j]]) for j in 1:p)
  @assert abs(avg(y .- avg(y) .- Z * b)) <= 1e-12
  @assert abs(orig(avg(y)) - obj) <= 1e-12 * (1 + obj)
  @assert orig(avg(y) + 1e-3) > orig(avg(y)) && orig(avg(y) - 1e-3) > orig(avg(y))

  ## the components: the evaluation map at the training points, the reconstruction of `Z b`, and
  ## the group norm as the empirical norm
  for j in 1:p
    cj = component(j, b, X[:, j])
    @assert norm(cj - blocks[j] * b[groups[j]]) <= 1e-10
    @assert abs(avg(cj .^ 2) - norm(b[groups[j]])^2) <= 1e-12
  end
  @assert norm(sum(component(j, b, X[:, j]) for j in 1:p) - Z * b) <= 1e-10
  @assert norm(predict(b, X) - (avg(y) .+ Z * b)) <= 1e-10

  ## the optimality conditions
  nz, zr = violations(b, lambda)
  @assert nz <= 1e-9 * lambda && zr <= 1e-9 * lambda
  println("λ = ", frac, " λmax = ", round(lambda, digits = 4), ": selected groups ", r.active,
          " (true ", true_groups, "); passes = ", r.res.passes,
          "; violations ", nz / lambda, " λ (nonzero), ", zr / lambda, " λ (zero)",
          "; error ", round(err(b), digits = 4),
          "; training residual mean square ", round(avg((y - predict(b, X)) .^ 2), digits = 4))
  push!(fits, (; lambda, r.b, r.active))
end

# At the largest of the three levels some groups are zero and some are not. This is a statement
# about this seed, and the assertion does not claim that the nonzero groups are the true ones.
@assert 0 < length(fits[1].active) < p

# ## Fitted and true components
#
# The fitted components are centered on the training sample, so the true functions are compared
# after subtracting their own sample means over the training rows. The table is for the middle
# level. A predictor whose group is zero has the fitted value `0` on the whole grid.
mid = fits[2]
grid = collect(0.0:0.2:1.0)
for j in (true_groups..., 3)
  c = avg(truth[j].(X[:, j]))
  println("predictor ", j, j in mid.active ? "" : " (zero group)", ": x = ", grid)
  println("   true  ", round.(truth[j].(grid) .- c, digits = 2))
  println("   fitted", round.(component(j, mid.b, grid), digits = 2))
end

# The penalty selects whole groups; it does not make the coefficients inside a selected block
# sparse. At a nonzero block the optimality condition gives `b[G] = −(‖b[G]‖/(λ w)) g[G]`, which
# has a zero entry only where the gradient entry is zero, and a zero group has all `K` entries
# zero. The count below is for the middle level, and the assertion states that each block has
# either all `K` coefficients nonzero (the group is active) or none.
nonzero_per_group = [count(!iszero, mid.b[groups[j]]) for j in 1:p]
println("nonzero coefficients per group: ", nonzero_per_group)
@assert all(nonzero_per_group[j] == (j in mid.active ? K : 0) for j in 1:p)

# ## Limitations
#
# - The fit is a group lasso on a fixed finite basis with fixed knots. The number and place of
#   the knots and the penalty levels are not tuned, and the page does not choose `λ` by
#   cross-validation or an information criterion.
# - The components are piecewise linear with kinks at the knots, so curvature inside a piece is
#   not represented; a different basis gives a different estimate.
# - The group norm `‖bⱼ‖₂` equals the empirical norm of the fitted component on the training
#   sample, whose rows define the centering and the orthonormalization; at other points the
#   empirical norm of the component is a different number. The penalty is the SpAM penalty on a
#   fixed finite basis, and the fit is a finite-basis approximation, not the SpAM procedure,
#   which fits the components nonparametrically with smoothers.
# - The weights `wⱼ = √K` are equal across the predictors, so the penalty is `λ √K Σⱼ ‖bⱼ‖₂`, a
#   rescaling of `λ`.
# - The selected groups are reported for one simulated data set and compared with the truth.
#   They are no guarantee of recovery on other data, and the page asserts none.
# - `CDSolver`'s `converged` is a test of the change over a pass. The optimality statements on
#   this page come from `violations`, which is computed from `Z` and `z`.
# - The data are dense `Float64`; no other element type or iterate is run here.
