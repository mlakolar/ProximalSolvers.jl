# Change-point detection in a piecewise-constant signal by total-variation denoising. For data
# `y ∈ Rⁿ` the fitted signal `μ` minimizes
#
#     (1/(2n)) Σᵢ (yᵢ − μᵢ)² + λ Σ_{i≥2} |μᵢ − μᵢ₋₁|.
#
# The penalty is the total variation of `μ`, and a jump `μᵢ ≠ μᵢ₋₁` in the fit is a detected change
# point. This page rewrites the problem as an ordinary lasso on a step-function design and solves
# it with `CDSolver`, the lasso row of [Supported problems](../../support.md). It adds no solver
# support. The rewriting is for the first-difference total-variation penalty above; the general fused
# lasso, which has an additional ℓ1 penalty on the coefficients of `μ`, is a different problem (Tibshirani, Saunders,
# Rosset, Zhu and Knight, *Sparsity and smoothness via the fused lasso*, Journal of the Royal
# Statistical Society B, 2005). For the plain lasso, see [Lasso](lasso.md).
#
# ## From total variation to a lasso
#
# Write `θⱼ = μⱼ₊₁ − μⱼ` for `j = 1, …, n − 1` and let `D` be the `n × (n − 1)` matrix with
# `D[i, j] = 1` if `i > j` and `0` otherwise. Every `μ ∈ Rⁿ` has the form `μ = a·1 + Dθ`, with
# `a = μ₁` and the jumps `θ`, and then `Σ_{i≥2} |μᵢ − μᵢ₋₁| = ‖θ‖₁`. The first level `a` is not
# penalized. For a fixed `θ`, the least-squares loss is minimized over `a` at
# `a = mean(y) − mean(D; dims = 1) θ`. With
#
#     z = y − mean(y)   and   X = D − mean(D; dims = 1)
#
# (the columns of `D` centered), the profiled problem is the lasso
#
#     min_θ (1/(2n)) ‖z − Xθ‖² + λ ‖θ‖₁,        μ̂ = mean(y)·1 + Xθ̂.
#
# The fit is `mean(y)·1 + Xθ̂`, not `Xθ̂`: `X` has centered columns, so `Xθ̂` has mean zero.
# ProximalBase's `LeastSquaresLoss(z, X)` is `‖z − Xθ‖²/2`, so the smooth part of the lasso is
# `(1/n) * LeastSquaresLoss(z, X)` and the penalty is `NormL1(λ)`.
#
# A nonzero `θ̂ⱼ` is a change point between observations `j` and `j + 1`: the segment that follows
# starts at observation `j + 1`. For the data `y = [0, 0, 0, 1, 1, 1]`, for example, the jump is
# between observations 3 and 4, and the fit has `θ̂₃ ≠ 0` and a second segment that starts at 4.
using LinearAlgebra, Random
using ProximalBase, ProximalSolvers

# The data of the lasso for a vector `y`: the design `D`, the centered `X` and `z`, and the
# mean of the columns of `D`. The means are computed with `sum`, so the page does not need the
# `Statistics` package.
function tv_lasso_data(y)
  n = length(y)
  D = [i > j ? 1.0 : 0.0 for i in 1:n, j in 1:(n - 1)]
  Dbar = sum(D; dims = 1) / n
  ybar = sum(y) / n
  (; y, n, ybar, D, Dbar = vec(Dbar), X = D .- Dbar, z = y .- ybar)
end;

# The solution of the lasso at the level `λ`, from `θ = 0`, with cyclic order and no momentum so
# that the output is reproducible. The step columns are strongly correlated, so the solver tolerance
# is small: `relative = false` and `tol = 1e-13` make a pass change the coefficients by less than
# `1e-13` in absolute value before the solver reports `converged`. That flag is a change test and
# not an optimality certificate; the checks below use the data instead.
function tv_solve(data, λ)
  (; n, X, z, ybar) = data
  θ = zeros(n - 1)
  f = (1 / n) * LeastSquaresLoss(z, X)
  result = solve!(θ, f, NormL1(λ), CDSolver(order = :cyclic, momentum = false,
                                            relative = false, tol = 1e-13))
  @assert result.converged && result.minimizer === θ
  (; θ, μ = ybar .+ X * θ, result)
end;

# The function below measures optimality of `θ` from `X`, `z`, `λ` and `n` alone. With
# `grad = Xᵀ(Xθ − z)/n` it returns the largest violation of `0 ∈ grad + λ ∂‖θ‖₁`: at a zero
# coefficient the excess of `|grad_j|` over `λ`, and at a nonzero coefficient the distance
# `|grad_j + λ sign(θ_j)|`. It is zero at a minimizer.
function lasso_kkt_residual(X, z, n, λ, θ)
  grad = X' * (X * θ - z) / n
  maximum(iszero(θ[j]) ? max(abs(grad[j]) - λ, 0.0) :
                         abs(grad[j] + λ * sign(θ[j])) for j in eachindex(θ))
end;

# ## Checking a fit
#
# `verify` checks a fit `(θ, μ)` at the level `λ` against the original problem and the lasso. The
# tolerances are for `Float64`.
#
# - Reconstruction: with the profiled `a`, `a·1 + Dθ` equals `μ` and `diff(μ)` equals `θ`. The
#   entries are of order one and a sum has at most `n − 1` terms, so the rounding error is far
#   below the tolerance `1e-12`.
# - Objective: the objective of the original problem at `μ`, `‖y − μ‖²/(2n) + λ Σ|μᵢ − μᵢ₋₁|`,
#   equals the lasso objective at `θ`, within `1e-12` times the larger of one and the objective.
# - Optimality: the KKT residual is at most `1e-9 λ`. With the solver tolerance above, the KKT
#   residuals in the runs below are about `1e-12 λ` or smaller, so `1e-9 λ` leaves a margin of
#   three orders of magnitude for other platforms.
function verify(data, λ, θ, μ)
  (; y, n, ybar, D, Dbar, X, z) = data
  @assert length(θ) == n - 1 && length(μ) == n && all(isfinite, θ) && all(isfinite, μ)
  a = ybar - dot(Dbar, θ)
  @assert maximum(abs, (a .+ D * θ) .- μ) <= 1e-12
  @assert abs(μ[1] - a) <= 1e-12
  @assert maximum(abs, diff(μ) .- θ) <= 1e-12
  objective_original = sum(abs2, y .- μ) / (2n) + λ * sum(abs, diff(μ))
  objective_lasso = sum(abs2, z .- X * θ) / (2n) + λ * norm(θ, 1)
  objective_gap = abs(objective_original - objective_lasso)
  @assert objective_gap <= 1e-12 * max(1.0, objective_original)
  kkt = lasso_kkt_residual(X, z, n, λ, θ)
  @assert kkt <= 1e-9 * λ
  (; kkt, objective_gap, objective = objective_original)
end;

# ## A small noiseless example
#
# Take `y = [0, 0, 0, 1, 1, 1]` and `λ = 0.1`. With `n = 6`, the minimizer of the problem on
# two constant segments of length 3 has the levels `0 + 2λ` and `1 − 2λ` (derived below). They
# are valid while the second level stays above the first, that is for `λ < 1/4`.
y_small = [0.0, 0.0, 0.0, 1.0, 1.0, 1.0]
λ_small = 0.1
data_small = tv_lasso_data(y_small)
fit_small = tv_solve(data_small, λ_small)
verify(data_small, λ_small, fit_small.θ, fit_small.μ)
@assert findall(j -> abs(fit_small.θ[j]) > 1e-8, 1:5) == [3]
@assert maximum(abs, fit_small.μ .- [fill(2λ_small, 3); fill(1 - 2λ_small, 3)]) <= 1e-8
println("θ = ", round.(fit_small.θ; digits = 6), "; μ̂ = ", round.(fit_small.μ; digits = 6),
        "; the second segment starts at observation ", only(findall(!iszero, fit_small.θ)) + 1)

# ## Noiseless data with a closed-form solution
#
# Let `y` be constant on `K` segments, with levels `c₁, …, c_K` and lengths `n₁, …, n_K`, so that
# `n = Σ n_k`. Put `s_k = sign(c_{k+1} − c_k)` for `k = 1, …, K − 1` and `s₀ = s_K = 0`. Suppose
# the total-variation minimizer is constant on the same segments, with the levels `μ_k`, and that
# `sign(μ_{k+1} − μ_k) = s_k` for every `k` (the validity condition below). Then a coordinate of
# the lasso is zero inside a segment and the first-order conditions on the jumps give
#
#     μ_k = c_k + (λ n / n_k) (s_k − s_{k−1}).
#
# For the first and last segment the level moves toward its neighbour by `λ n / n_k`. A segment
# between an up-jump and a down-jump moves down by `2 λ n / n_k`, and a segment between two
# jumps in the same direction does not move. Inside a segment, the partial sums of the residual
# `y − μ` run linearly between `−λ n` and `λ n`, which gives the zero-jump conditions there. For
# the small example above, `n = 6`, `n_k = 3` and `s₁ = 1` give `μ₁ = 2λ` and `μ₂ = 1 − 2λ`.
function tv_levels(c, len, λ)
  n = sum(len)
  s = [0; sign.(diff(c)); 0]        # s[k + 1] is s_k
  [c[k] + λ * n / len[k] * (s[k + 1] - s[k]) for k in eachindex(c)]
end;

# The check below solves the lasso for noiseless data with three segments and compares the
# solution with the closed form. It first checks the validity condition for the closed-form levels
# at `λ`. The comparison covers the fitted levels (the tolerance `1e-8` is the accuracy of the
# solution, and the solution is also checked by `verify`) and the places of the nonzero jumps,
# which are the last observations of the segments before the final one.
c_ctrl = [0.0, 2.0, 1.0]
len_ctrl = [10, 8, 12]
λ_ctrl = 0.05
levels_ctrl = tv_levels(c_ctrl, len_ctrl, λ_ctrl)
@assert all(sign.(diff(c_ctrl)) .* diff(levels_ctrl) .> 0)     # validity condition
y_ctrl = reduce(vcat, fill.(c_ctrl, len_ctrl))
data_ctrl = tv_lasso_data(y_ctrl)
fit_ctrl = tv_solve(data_ctrl, λ_ctrl)
check_ctrl = verify(data_ctrl, λ_ctrl, fit_ctrl.θ, fit_ctrl.μ)
@assert maximum(abs, fit_ctrl.μ .- reduce(vcat, fill.(levels_ctrl, len_ctrl))) <= 1e-8
@assert findall(j -> abs(fit_ctrl.θ[j]) > 1e-8, 1:(sum(len_ctrl) - 1)) == cumsum(len_ctrl)[1:(end - 1)]
println("closed-form levels = ", levels_ctrl, "; fitted levels = ",
        round.(fit_ctrl.μ[cumsum(len_ctrl) .- len_ctrl .+ 1]; digits = 8),
        "; change indices j = ", findall(j -> abs(fit_ctrl.θ[j]) > 1e-8, eachindex(fit_ctrl.θ)),
        "; KKT residual = ", check_ctrl.kkt)

# The fitted levels are shrunk toward each other relative to the data levels `c`, by the amounts
# in the formula. Total-variation denoising is a shrinkage estimator.
println("data levels = ", c_ctrl, "; shrinkage = ", round.(levels_ctrl .- c_ctrl; digits = 8))

# ## One simulated data set
#
# The signal has `n = 120` observations and four constant segments that start at observations
# 1, 31, 66 and 96, with the levels 0, 2, 0.5 and 1.5, and the noise is Gaussian with standard
# deviation 0.4. The seed is fixed, so the output below is reproducible.
rng = Xoshiro(2026)
n = 120
starts_true = [1, 31, 66, 96]
levels_true = [0.0, 2.0, 0.5, 1.5]
len_true = diff([starts_true; n + 1])
μ_true = reduce(vcat, fill.(levels_true, len_true))
y = μ_true .+ 0.4 .* randn(rng, n)
data = tv_lasso_data(y);

# ## The largest penalty level
#
# The point `θ = 0` satisfies the optimality conditions of the lasso when and only when
# `‖Xᵀz‖∞ / n ≤ λ`, that is `λ ≥ λmax = ‖Xᵀz‖∞ / n`. For such `λ` the fit has no jump and is
# the constant `mean(y)`. Three checks follow. First, the KKT residual of `θ = 0` at `λmax`,
# computed from the data, is zero. Second, the solver is run at `λmax` itself, where its comparison
# of a gradient entry with `λ` is at the rounding level, so a coefficient of rounding size can
# remain; the check there is a bound of `1e-12` on the coefficients, which are of order one at
# smaller `λ`, and a KKT residual of at most `1e-12 λmax`. Third, strictly above `λmax`, at
# `(1 + 1e-6) λmax` and at `2 λmax`, the margin is far larger than that rounding, and the solver
# returns `θ = 0` unchanged, so the fit is the constant `mean(y)`.
λmax = norm(data.X' * data.z, Inf) / n
@assert lasso_kkt_residual(data.X, data.z, n, λmax, zeros(n - 1)) == 0
fit_at = tv_solve(data, λmax)
verify(data, λmax, fit_at.θ, fit_at.μ)
@assert maximum(abs, fit_at.θ) <= 1e-12
@assert lasso_kkt_residual(data.X, data.z, n, λmax, fit_at.θ) <= 1e-12 * λmax
for factor in (1 + 1e-6, 2.0)
  fit_above = tv_solve(data, factor * λmax)
  @assert all(iszero, fit_above.θ) && all(==(data.ybar), fit_above.μ)
end
println("λmax = ", round(λmax; digits = 6), "; largest coefficient at λmax = ",
        maximum(abs, fit_at.θ), "; the fit above λmax is the constant ", round(data.ybar; digits = 6))

# ## Fits below the largest level
#
# At each level the fit is checked by `verify`. A segment is a maximal run of observations
# between detected change points, and the table lists its first and last observation and its
# fitted level. The estimated starts are compared with the true starts 31, 66 and 96: for each
# true start, the distance to the nearest estimated start, and the number of estimated starts that
# are more than 5 observations from every true start. These numbers describe this one data set at
# these levels. They are not a statement about how often the lasso recovers the change points.
function segments(μ, θ)
  first_obs = [1; findall(!iszero, θ) .+ 1]
  last_obs = [first_obs[2:end] .- 1; length(μ)]
  [(first = a, last = b, level = μ[a]) for (a, b) in zip(first_obs, last_obs)]
end
for fraction in (0.4, 0.15, 0.05)
  λ = fraction * λmax
  fit = tv_solve(data, λ)
  checks = verify(data, λ, fit.θ, fit.μ)
  est_starts = findall(!iszero, fit.θ) .+ 1
  distance = [isempty(est_starts) ? nothing : minimum(abs.(est_starts .- t)) for t in starts_true[2:end]]
  extra = count(e -> minimum(abs.(e .- starts_true)) > 5, est_starts)
  println("λ = ", fraction, " λmax = ", round(λ; digits = 5), ": ", length(est_starts),
          " estimated change points, starts = ", est_starts)
  println("  distance from the true starts ", starts_true[2:end], " to the nearest estimated start = ",
          distance, "; estimated starts more than 5 observations from every true start = ", extra)
  println("  segments (first:last → level) = ",
          join(("$(s.first):$(s.last) → $(round(s.level; digits = 2))" for s in segments(fit.μ, fit.θ)), ", "))
  println("  mean squared error of the fit against the true signal = ",
          round(sum(abs2, fit.μ .- μ_true) / n; digits = 4), "; KKT residual = ", checks.kkt,
          "; objective difference = ", checks.objective_gap, "; passes = ", fit.result.passes)
end

# ## Limitations
#
# - This is total-variation denoising of a signal, a special case of the fused lasso. It has no
#   ℓ1 penalty on the coefficients of `μ` and no difference operator other than the first
#   difference.
# - The step design `D` is a dense `n × (n − 1)` matrix, so its storage grows like `n²` and a pass of
#   `CDSolver` over all coordinates costs on the order of `n²` operations. The example uses a
#   moderate `n`.
# - The columns of `X` are strongly correlated, so coordinate descent can need many passes at
#   small `λ`. The solver tolerance above is small, and the independent KKT residual, not
#   `converged`, is what the checks rest on. The solver's `maxpasses` bounds the work.
# - The lasso penalty shrinks the fitted levels toward each other (see the closed form above), and
#   on noisy data it can place extra jumps near a true change point. The comparison with the
#   truth above is for one simulated data set, and no claim of consistent recovery of the change
#   points is made.
# - The page uses `Float64` data and `CDSolver` on a dense `Vector`; other element types and
#   iterates are not covered here.
#
# See [Supported problems](../../support.md) for the supported combinations and [Lasso](lasso.md)
# for the lasso on its own.
