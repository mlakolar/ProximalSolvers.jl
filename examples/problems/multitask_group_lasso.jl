# Multi-task regression with shared row sparsity, fitted as a group lasso. There are `K`
# regression tasks on the same `n × p` design `X`, with responses `Y ∈ ℝⁿˣᴷ` (one column per
# task) and coefficients `B ∈ ℝᵖˣᴷ` (one column per task, one row per predictor). The fit
# minimizes
#
# `(1/(2n)) ‖Y − X B‖²_F + λ √K Σⱼ ‖B[j, :]‖₂`.
#
# The penalty acts on the rows of `B`: a zero row removes predictor `j` from all `K` tasks at
# once, while a selected row has separate coefficients in each task. This is the penalty
# studied by Obozinski, Wainwright and Jordan (2011), *Support union recovery in
# high-dimensional multivariate regression*, Annals of Statistics 39(1). It is not a low-rank
# (nuclear-norm) estimator: nothing ties the coefficient values across tasks, only the set of
# predictors.
#
# The problem is solved exactly as an ordinary group lasso in the stacked vector
# `vec(B) ∈ ℝᵖᴷ`, with `GroupNormL2`, a `BlockIterate` and `CDSolver`; this is the group lasso
# row of [Supported problems](../../support.md), and the basic use of these types is explained
# in [Group lasso](group_lasso.md). No multi-response solver is involved.
using LinearAlgebra, Random
using ProximalBase, ProximalSolvers

# `Statistics` is not a dependency of this project, so the column means are computed directly.
colmeans(A) = vec(sum(A, dims = 1)) / size(A, 1)

# ## Data
#
# There are `n = 100` observations of `p = 10` correlated predictors and `K = 3` tasks. Three
# rows of the true coefficient matrix are nonzero, with different values (and signs) in the
# three tasks; the other seven rows are zero. Each task has its own intercept, and the noise
# has standard deviation `0.5`.
rng = Xoshiro(393)
n, p, K = 100, 10, 3
sigma = 0.5
true_rows = [2, 5, 8]
B_true = zeros(p, K)
B_true[2, :] = [1.0, -0.8, 0.6]
B_true[5, :] = [-0.7, 0.9, 0.5]
B_true[8, :] = [0.5, 0.4, -1.0]
a_true = [1.0, -2.0, 0.5]
L = cholesky(SymTridiagonal(fill(1.0, p), fill(0.3, p - 1))).L   # neighbor correlation 0.3
draw(rng, m) = 2.0 .+ randn(rng, m, p) * L'
X_raw = draw(rng, n)
Y_raw = a_true' .+ X_raw * B_true + sigma * randn(rng, n, K)

# The model has no unpenalized intercept inside the penalty. Instead the columns of `X` and of
# `Y` are centered. For a fixed `B`, the intercepts that minimize
# `‖Y_raw − 1 aᵀ − X_raw B‖²_F / (2n)` are `a = ȳ − Bᵀ x̄` (the column means of `Y_raw` and
# `X_raw`), and the minimum is `‖Y − X B‖²_F / (2n)` in the centered data. So the fit below is
# the fit with free intercepts, which are recovered afterwards from `B̂`.
xbar, ybar = colmeans(X_raw), colmeans(Y_raw)
X = X_raw .- xbar'
Y = Y_raw .- ybar'
@assert norm(colmeans(X)) <= 1e-12 && norm(colmeans(Y)) <= 1e-12

# ## The stacked problem
#
# Julia stores a matrix by columns, so `vec(B)` lists task 1, then task 2, and so on, and
# entry `B[j, k]` sits at position `(k − 1) p + j`. Then `vec(X B) = (I_K ⊗ X) vec(B)`, so with
# `Z = I_K ⊗ X` (dense, `nK × pK`) and `y = vec(Y)`,
#
# `‖Y − X B‖²_F = ‖y − Z vec(B)‖²₂`.
#
# Row `j` of `B` is the group `Gⱼ = {j, p + j, …, (K − 1) p + j}` of `vec(B)`: one entry from each
# task, for the same predictor, and not contiguous. `GroupNormL2(λ, groups)` has the default
# weights `wⱼ = √|Gⱼ| = √K`, so its value at `vec(B)` is `λ √K Σⱼ ‖B[j, :]‖₂`. The loss is
# `(1/n)` times ProximalBase's `LeastSquaresLoss(y, Z)`, which is `‖y − Z b‖²/2`. The scale is
# `1/n` and not `1/(nK)`: with it the stacked objective equals the matrix objective above.
Z = kron(Matrix{Float64}(I, K, K), X)
y = vec(Y)
groups = [[(k - 1) * p + j for k in 1:K] for j in 1:p]
@assert size(Z) == (n * K, p * K) && length(y) == n * K
@assert length(groups) == p && sort(reduce(vcat, groups)) == collect(1:(p * K))  # a partition
@assert all(vec(reshape(1:(p * K), p, K)[j, :]) == groups[j] for j in 1:p)       # group j = row j
f = (1 / n) * LeastSquaresLoss(y, Z)

# The objective and the optimality conditions are computed from the matrix data `X` and `Y`,
# not from `Z` and `y`. With `G = Xᵀ(X B − Y)/n`, a nonzero row satisfies
# `G[j, :] + λ √K B[j, :]/‖B[j, :]‖ = 0` and a zero row satisfies `‖G[j, :]‖ ≤ λ √K`. The function
# returns the largest violation over the nonzero rows and over the zero rows,
# `max(‖G[j, :]‖ − λ √K, 0)`.
objective(B, lambda) = norm(Y - X * B)^2 / (2n) + lambda * sqrt(K) * sum(norm(view(B, j, :)) for j in 1:p)
function violations(B, lambda)
  G = X' * (X * B - Y) / n
  nz, zr = 0.0, 0.0
  for j in 1:p
    bj, gj = B[j, :], G[j, :]
    if iszero(norm(bj))
      zr = max(zr, norm(gj) - lambda * sqrt(K))
    else
      nz = max(nz, norm(gj + lambda * sqrt(K) * bj / norm(bj)))
    end
  end
  nz, zr
end

# The fit returns `B̂ = reshape(x, p, K)`. The tolerance `1e-12` is a threshold on the change
# of the coefficients over a pass, and `converged` reports only that this change test passed;
# the optimality statements below rest on `violations`.
function fit(X, Y, lambda)
  n, p = size(X)
  K = size(Y, 2)
  Z = kron(Matrix{Float64}(I, K, K), X)
  groups = [[(k - 1) * p + j for k in 1:K] for j in 1:p]
  g = GroupNormL2(lambda, groups)
  x = BlockIterate(Float64, p * K, g)
  res = solve!(x, (1 / n) * LeastSquaresLoss(vec(Y), Z), g,
               CDSolver(order = :cyclic, momentum = false, tol = 1e-12))
  @assert res.minimizer === x
  Bhat = reshape(Vector(x), p, K)
  @assert size(Bhat) == (p, K) && all(isfinite, Bhat)
  @assert norm(Z * vec(Bhat) - vec(X * Bhat)) <= 1e-12 * (1 + norm(X * Bhat))
  rows = sort(collect(activecoordinates(x)))
  @assert rows == [j for j in 1:p if any(!iszero, Bhat[j, :])]   # active groups = nonzero rows
  (; Bhat, rows, res)
end

# ## The penalty level where all rows are zero
#
# At `B = 0` the gradient is `−XᵀY/n`, so `B = 0` is optimal exactly when
# `λ ≥ λmax = maxⱼ ‖(XᵀY)[j, :]‖₂ / (n √K)`. In the stacked problem this is the group score
# `‖Z[:, Gⱼ]ᵀ y‖₂ / (n wⱼ)` of the [Group lasso](group_lasso.md) page, which the first assertion
# compares as a check of the indexing.
lambda_max(X, Y) = maximum(norm(r) for r in eachrow(X' * Y)) / (size(X, 1) * sqrt(size(Y, 2)))
lambdamax = lambda_max(X, Y)
@assert abs(lambdamax - maximum(norm(Z[:, G]' * y) / (n * sqrt(K)) for G in groups)) <= 1e-12 * lambdamax
println("λmax = ", round(lambdamax, digits = 4))

# The threshold is checked on a tiny seeded control (`n = 8`, `p = 4`, `K = 2`): at
# `(1 + 10⁻⁶) λmax` and at `2 λmax` the solver returns exact zeros, and at `0.9 λmax` it returns
# a nonzero row, so the formula is not merely an upper bound.
let rng = Xoshiro(1)
  Xs = randn(rng, 8, 4); Xs .-= colmeans(Xs)'
  Ys = randn(rng, 8, 2); Ys .-= colmeans(Ys)'
  lm = lambda_max(Xs, Ys)
  for lambda in ((1 + 1e-6) * lm, 2 * lm)
    r = fit(Xs, Ys, lambda)
    @assert all(iszero, r.Bhat) && isempty(r.rows)
  end
  @assert !isempty(fit(Xs, Ys, 0.9 * lm).rows)
  println("tiny control: all coefficients zero at (1 + 1e-6) λmax and 2 λmax, ",
          "a nonzero row at 0.9 λmax")
end

# ## A fit
#
# The penalty level is a fixed fraction of `λmax`, chosen so that the fit has both selected
# and unselected rows on this data set. It is not tuned (for example by cross-validation).
lambda = 0.15 * lambdamax
r = fit(X, Y, lambda)
Bhat = r.Bhat

# The stacked objective at `vec(B̂)`, computed from `Z` and `y` and also reported by the solver,
# must equal the matrix objective at `B̂`, and the row conditions must hold.
obj = objective(Bhat, lambda)
b = vec(Bhat)
obj_stacked = norm(y - Z * b)^2 / (2n) + lambda * sum(sqrt(K) * norm(b[G]) for G in groups)
@assert abs(obj_stacked - obj) <= 1e-12 * (1 + obj)
@assert abs(r.res.minimum - obj) <= 1e-10 * (1 + obj)
nz, zr = violations(Bhat, lambda)
@assert nz <= 1e-6 * lambda && zr <= 1e-6 * lambda
@assert 0 < length(r.rows) < p
println("λ = 0.15 λmax = ", round(lambda, digits = 4), ": passes = ", r.res.passes,
        "; objective ", round(obj, digits = 6), "; row violations ", nz, " (nonzero), ",
        zr, " (zero)")
println("true rows ", true_rows, "; selected rows ", r.rows)

# The estimated coefficients, one row per predictor and one column per task. A row is either
# zero in all tasks or (generically) nonzero in all tasks.
println("row   true coefficients        estimated coefficients")
for j in 1:p
  println(lpad(j, 3), "   ", rpad(string(round.(B_true[j, :], digits = 2)), 24),
          round.(Bhat[j, :], digits = 2), j in r.rows ? "" : "  (zero row)")
end

# The intercepts on the original scale are `â = ȳ − B̂ᵀ x̄`. The prediction error is measured on
# `2000` fresh rows against the true regression function `a + Bᵀx`, not against noisy
# responses, separately for each task. The lasso shrinks the selected coefficients toward zero,
# so the error is not zero even when the selected rows are the true ones.
ahat = ybar - Bhat' * xbar
X_new = draw(Xoshiro(394), 2000)
mu_new = a_true' .+ X_new * B_true
mse = colmeans((ahat' .+ X_new * Bhat - mu_new) .^ 2)
mse0 = colmeans((ybar' .- mu_new) .^ 2)     # the intercept-only fit, for reference
println("intercepts: true ", a_true, ", estimated ", round.(ahat, digits = 2))
println("prediction error per task: ", round.(mse, digits = 4),
        " (intercept-only fit: ", round.(mse0, digits = 4), ")")

# ## Shared sparsity and separate fits
#
# Fitting each task alone, for example by a lasso on each column of `Y`, chooses a set of
# predictors for each task, and the sets need not agree. The row penalty instead pools the
# evidence for predictor `j` over the tasks through `‖G[j, :]‖₂`: a predictor with moderate
# effects in every task can be selected, and the selected set is the same for all tasks. Which
# is preferable depends on whether the tasks plausibly share their relevant predictors. With
# `K = 1` the penalty reduces to the lasso penalty `λ |b_j|`.
#
# ## Limitations
#
# - The stacked design `Z = I_K ⊗ X` is formed explicitly and densely, with `K` times as many
#   rows and columns as `X`. This is fine for a small example; it does not use the structure of
#   the Kronecker product.
# - The penalty level is a fixed fraction of `λmax` and is not tuned.
# - The selected rows are reported for one simulated data set and compared with the truth. They
#   are no guarantee of recovery on other data, and the page asserts none.
# - `CDSolver`'s `converged` is a test of the change over a pass. The optimality statements on
#   this page come from `violations`, computed from `X` and `Y`.
# - The data are dense `Float64`; no other element type or iterate is run here.
