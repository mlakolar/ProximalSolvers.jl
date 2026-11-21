module LogisticAPGTest
# Sparse logistic regression with AccProxGradDescent (IN-09, APG-08): a raw LogisticLoss{Float64} on a dense
# Matrix{Float64} with a binary Vector{Float64} response, no observation weights or offset, and NormL1 with or
# without penalty weights on a Vector{Float64}. The references below are computed from the stored data in BigFloat
# with formulas of their own, not with ProximalBase's oracles. The helpers up to `slope_threshold` are the label-wise
# formulas of test/logistic_pgd.jl, copied so that the two files share nothing.
using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

# Stable scalar formulas, for Float64 and BigFloat arguments: neither evaluates exp of a large positive number
sigmoid(t) = t >= 0 ? inv(1 + exp(-t)) : (e = exp(t); e / (1 + e))
softplus(t) = t > 0 ? t + log1p(exp(-t)) : log1p(exp(t))

# The raw loss and its gradient at b, in BigFloat from the stored data, for a binary y. With η = X b and
# sᵢ = 1 - 2yᵢ, the term of observation i is softplus(sᵢηᵢ) = log(1 + e^{ηᵢ}) - yᵢηᵢ, and the derivative
# σ(ηᵢ) - yᵢ is sᵢ σ(sᵢηᵢ). These label-wise forms keep the tail of an observation on the side of its label,
# which softplus(η) - yη and σ(η) - 1 lose to cancellation at large logits, even in BigFloat.
function oracle(X, y, b)
  A, s = big.(X), big.(1 .- 2 .* y)
  η = A * big.(b)
  (; value = sum(softplus.(s .* η)), gradient = A' * (s .* sigmoid.(s .* η)))
end

# cⱼ = λ wⱼ in BigFloat (cⱼ = λ without weights)
coefficient(λ, w, j) = big(λ) * (w === nothing ? 1 : big(w[j]))

# The KKT scores of b for NormL1(λ, w) at the gradient G: max(|Gⱼ| - cⱼ, 0) where bⱼ = 0 and |Gⱼ + cⱼ sign(bⱼ)|
# elsewhere. A zero weight scores |Gⱼ|, the score of an unpenalized coefficient. The largest score is the
# stationarity residual of the composite objective, and each score is the magnitude of the matching entry of the
# element of least norm in the subdifferential of the objective at b.
scores(G, b, λ, w = nothing) =
  [iszero(b[j]) ? max(abs(G[j]) - coefficient(λ, w, j), 0) : abs(G[j] + coefficient(λ, w, j) * sign(b[j]))
   for j in eachindex(b)]

objective(X, y, b, λ, w = nothing) =
  oracle(X, y, b).value + sum(coefficient(λ, w, j) * abs(big(b[j])) for j in eachindex(b))

# The NormL1 of the solves below, with penalty weights where given
penalty(λ, w) = w === nothing ? NormL1(λ) : NormL1(λ, w)

# S = max(λ maxⱼ wⱼ, ‖∇f(0)‖∞) with ∇f(0) = Xᵀ(½ - y): the scale of the solver's stationarity check (STOP-03)
stop_scale(X, y, λ, w = nothing) = max(λ * (w === nothing ? 1 : maximum(w)), norm(X' * (0.5 .- y), Inf))

# The minimizer of the unpenalized raw loss by damped Newton in BigFloat (backtracking on the loss), with the
# ∞-norm of its gradient. It stops when that norm is below 1e-30 or after `iterations` steps; a small
# gradient alone does not show that a minimizer exists (see `nonseparable`).
function newton(X, y; iterations = 100)
  A, s = big.(X), big.(1 .- 2 .* y)
  loss(v) = sum(softplus.(s .* (A * v)))
  gradient(v) = A' * (s .* sigmoid.(s .* (A * v)))
  b = zeros(BigFloat, size(A, 2))
  G = gradient(b)
  for _ in 1:iterations
    norm(G, Inf) < big(10)^-30 && break
    η = A * b
    step = (A' * (A .* (sigmoid.(η) .* sigmoid.(-η)))) \ G
    t, f0 = big(1), loss(b)
    while loss(b - t * step) > f0 - t * dot(G, step) / 4
      t /= 2
      t < big(10)^-20 && error("damped Newton made no progress")
    end
    b -= t * step
    G = gradient(b)
  end
  b, norm(G, Inf)
end

# A numerical witness, computed in BigFloat, that the data (X, y) are not separable, even weakly (see
# test/logistic_pgd.jl for the argument). Returns min(u - c) / max|c|, the margin of the computed corrected weights
# over the computed correction.
function nonseparable(X, y, b)
  r = big.(2 .* y .- 1)
  A = r .* big.(X)
  rank(X) == size(X, 2) || return big(0)
  u = sigmoid.(-r .* (big.(X) * big.(b)))
  c = A * ((A' * A) \ (A' * u))
  minimum(u - c) / maximum(abs, c)
end

# A Float64 estimate of a lower bound on the smallest eigenvalue of the Hessian Xᵀ diag(σ(ηᵢ)σ(-ηᵢ)) X on the
# segment from a to b. In exact arithmetic each ηᵢ moves linearly from (X a)ᵢ to (X b)ᵢ along it, and σ(t)σ(-t)
# decreases in |t|, so the smallest weight of observation i on the segment is at one of the two ends; the
# eigenvalue of the matrix with those weights is computed with eigmin.
function segment_curvature(X, a, b)
  w(t) = sigmoid(t) * sigmoid(-t)
  eigmin(Symmetric(X' * (X .* min.(w.(X * a), w.(X * b)))))
end

# Seeded data: an intercept column of ones, then p covariates with population correlation 1/2 between neighbours
# (standard normal before the scaling), multiplied by `scale`, and responses drawn from the logistic model with
# intercept -0.3 and the planted slopes `signal` on the first covariates. X has p + 1 columns.
function logistic_data(n, p; seed, signal = [1.0, -0.8, 0.6], scale = 1.0)
  rng = Xoshiro(seed)
  Z = randn(rng, n, p)
  for j in 2:p
    Z[:, j] .= 0.5 .* Z[:, j - 1] .+ sqrt(0.75) .* Z[:, j]
  end
  Z .*= scale
  β = zeros(p)
  β[1:length(signal)] .= signal
  y = Float64.(rand(rng, n) .< sigmoid.(-0.3 .+ Z * β))
  [ones(n) Z], y
end

# The raw level above which the slopes vanish when the intercept (column 1) is unpenalized: ‖Zᵀ(ȳ - y)‖∞
slope_threshold(X, y) = norm(X[:, 2:end]' * (sum(y) / length(y) .- y), Inf)

# Options for the accuracy checks: a stop needs a computed KKT residual below 1e-8 S (STOP-04). The iteration limit
# is far above what these problems need. allow_f_increases keeps a rounding-sized increase of the computed objective
# near the solution from ending a run.
const OPTS = ProximalOptions(maxiter = 20_000, ftol = 1e-15, xtol = 1e-12, gradtol = 1e-8, allow_f_increases = true)
# The same with a tighter gradient test, for the references
const REF = ProximalOptions(maxiter = 200_000, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-12, allow_f_increases = true)

# A first-order estimate of the rounding of each entry of the solver's Float64 gradient Xᵀd with d = σ(X b) - y: with
# u = eps/2, |dᵢ| ≤ 1 and M = maxᵢ Σⱼ |Xᵢⱼ||bⱼ|, each entry is off by about n u max|Xᵢⱼ| (n + p M / 4 + 2), from the
# product Xᵀd, the image X b (σ has slope at most ¼) and d. It omits the rounding of the scores and of S.
# It is the same estimate as in test/logistic_pgd.jl.
rounding_bound(X, b) =
  (n = size(X, 1); M = maximum(abs.(X) * abs.(b)); n * eps() / 2 * maximum(abs, X) * (n + size(X, 2) * M / 4 + 2))

# The largest score of b in BigFloat: the independent residual of b for NormL1(λ, w)
kkt_residual(X, y, b, λ, w) = maximum(scores(oracle(X, y, b).gradient, b, λ, w))

# The independent residual of a point at which a solver reported a stop, compared with the solver's threshold τ S,
# τ = max(gradtol, 64eps) (STOP-03, STOP-04), plus an allowance for rounding. The solver's own test is on a residual
# formed from a Float64 gradient, so the BigFloat residual of a point that passes it can exceed τ S by the rounding of
# that gradient, which rounding_bound estimates; the allowance is a platform margin for that. By default the check also
# requires the allowance to be at most 1% of τ S, so that the margin stays small next to the threshold. In the recorded
# runs, the fits whose ratio KKT / (τ S) is printed below were under τ S without the allowance. `margin = false` drops the
# 1% requirement, for a reference solved at a tighter gradtol, where the estimate can exceed 1% of the threshold. Returns
# the BigFloat residual.
function check_stop(X, y, b, λ, w, options; margin = true)
  τ = max(options.gradtol, 64eps())
  S = stop_scale(X, y, λ, w)
  slack = rounding_bound(X, b)
  residual = kkt_residual(X, y, b, λ, w)
  margin && @test slack <= 0.01 * τ * S
  @test residual < big(τ * S + slack)
  residual
end

# The objectives of two points compared through convexity. At a point b, take the element G of the subdifferential of F
# whose coordinates have the smallest magnitudes: |Gⱼ| is the score of coordinate j, with Gⱼ = ∇fⱼ plus the value of
# smallest magnitude in [-cⱼ, cⱼ] at bⱼ = 0 and ∇fⱼ + cⱼ sign(bⱼ) elsewhere. By convexity F(other) ≥ F(b) + ⟨G, other - b⟩, so
# F(b) - F(other) ≤ Σⱼ |Gⱼ| |otherⱼ - bⱼ| ≤ KKT∞(b) ‖b - other‖₁; with the roles exchanged,
# |F(a) - F(b)| ≤ max(KKT∞(a), KKT∞(b)) ‖a - b‖₁. The scores, the objectives and the bound are all BigFloat from the stored
# points. The rounding term covers the rounding of that evaluation at the default BigFloat precision of 256 bits, which
# nothing in this file changes (relative error about 1e-77 per operation): the sums have at most a few hundred terms,
# and 1e-60 relative to the size of the objectives is far above their rounding and far below any Float64 quantity compared.
function objective_gap(X, y, λ, w, a, b)
  ka, kb = kkt_residual(X, y, a, λ, w), kkt_residual(X, y, b, λ, w)
  Fa, Fb = objective(X, y, a, λ, w), objective(X, y, b, λ, w)
  bound = max(ka, kb) * sum(abs, big.(a) - big.(b))
  rounding = big(10)^-60 * (1 + abs(Fa) + abs(Fb))
  (gap = abs(Fa - Fb), bound = bound, rounding = rounding)
end

# The state of a solve as `solve!` forms it, after the gate, and its run through the engine
function apg_run(X, y, λ, w, options; x0 = zeros(size(X, 2)))
  f, g = LogisticLoss(y, X), penalty(λ, w)
  b = copy(x0)
  PS._check_gradient_problem(b, f, g, :gradient)
  method = AccProxGradDescent()
  g_work = PS._working_gradient_penalty(g, Float64)
  state = PS.initial_state(method, options, f, g_work, b)
  result = PS._solve_gradient!(state, f, g_work, method, options)
  b, result, state
end

# Regularized fits: the design with n > p and with p > n, a lasso level with unit penalty weights except a zero weight on
# the intercept, an unweighted level on a design whose intercept is penalized, and random positive penalty weights except
# the intercept's zero. In each fixture both classes are present and each weight but the intercept's is positive, so the
# sublevel sets of the objective are bounded and a minimizer exists (IN-09, unattained minima).
function fixtures()
  X1, y1 = logistic_data(300, 20; seed = 4)
  X2, y2 = logistic_data(60, 150; seed = 14)
  X3, y3 = logistic_data(200, 12; seed = 8)
  X4, y4 = logistic_data(200, 30; seed = 21)
  w4 = [0.0; 0.5 .+ rand(Xoshiro(7), size(X4, 2) - 1)]
  [("n > p, unpenalized intercept", X1, y1, 0.15 * slope_threshold(X1, y1), [0.0; ones(size(X1, 2) - 1)]),
   ("p > n, unpenalized intercept", X2, y2, 0.2 * slope_threshold(X2, y2), [0.0; ones(size(X2, 2) - 1)]),
   ("unweighted", X3, y3, 0.1 * norm(X3' * (0.5 .- y3), Inf), nothing),
   ("random weights, unpenalized intercept", X4, y4, 0.1 * slope_threshold(X4, y4), w4)]
end

# ---- the certified test reads only the design -----------------------------------------------------------------------

# The decision of _bound_certified! for the trial x from the extrapolated point y = xa + ω (xa - xb), as the solver forms
# its arguments (the cached images and their error bound, or the fresh product when `fresh_only`), with the image model m
function decision(m, X, x, xa, xb, ω, L; fresh_only)
  n = size(X, 1)
  extrapolated = ω > 0
  y = extrapolated ? xa .+ ω .* (xa .- xb) : copy(xa)
  za, zb = X * xa, X * xb
  zu = extrapolated ? za .+ ω .* (za .- zb) : za
  zw = X * x
  d = x .- y
  c = PS._bound_constants(Float64, X, PS._frobenius_upper(Float64, X))
  Ey = PS._image_error_bound(c, PS._se_norm_onepass(Float64, sum(abs2, xa), xa),
                             PS._se_norm_onepass(Float64, sum(abs2, xb), xb), extrapolated)
  sd, sx = PS._sumsq2(d, x)
  D, normx = PS._se_norm_onepass(Float64, sd, d), PS._se_norm_onepass(Float64, sx, x)
  iszero(D.s) && return nothing
  PS._bound_certified!(zeros(n), m, zu, zw, d, D, L, Ey, normx, PS._root_scale(Float64, m.α), c, fresh_only)
end

@testset "the certified test gives the same decisions for the logistic image as for least squares at the scale 1/4" begin
  rng = Xoshiro(501)
  X, y = logistic_data(40, 6; seed = 41)
  n, k = size(X)
  logistic = PS._image_model(LogisticLoss(y, X))
  ls = PS._image_model(0.25 * LeastSquaresLoss(y, X))
  @test logistic isa PS._LogisticImage && ls isa PS._LSImage
  @test logistic.α == 0.25 && ls.α == 0.25
  root(m) = (r = PS._root_scale(Float64, m.α); (r.s, r.e))
  @test root(logistic) == root(ls) == (1.0, -1)       # √¼ = ½ = 1.0 * 2^-1
  accepted = rejected = cheap = fresh = 0
  for _ in 1:60
    xa, xb = randn(rng, k), randn(rng, k)
    ω = rand(rng, (0.0, 0.25, 0.9))
    y0 = ω > 0 ? xa .+ ω .* (xa .- xb) : xa
    x = xa .+ 0.3 .* randn(rng, k)
    d = big.(x) .- big.(y0)
    iszero(sum(abs2, d)) && continue
    # the directional curvature ¼‖X d‖²/‖d‖², formed in BigFloat and rounded to Float64; the factors below put L below, at
    # and above it. In exact arithmetic the relaxed image inequality holds from L = q / (1 + 4eps)², with q the BigFloat
    # quotient before that rounding.
    curvature = Float64(sum(abs2, big.(X) * d) / 4 / sum(abs2, d))
    for factor in (1 / 4, 1 / 2, 1, 2, 4), use_fresh in (false, true)
      a = decision(logistic, X, x, xa, xb, ω, curvature * factor; fresh_only = use_fresh)
      b = decision(ls, X, x, xa, xb, ω, curvature * factor; fresh_only = use_fresh)
      @test a == b
      a === nothing && continue
      ok, used_fresh = a
      accepted += ok
      rejected += !ok
      fresh += used_fresh
      cheap += !used_fresh
      # a certified trial satisfies the image inequality ½‖X d‖ ≤ (1 + 4eps) √L ‖d‖ in BigFloat
      ok && @test sum(abs2, big.(X) * d) / 4 <= (1 + 4 * big(eps()))^2 * big(curvature * factor) * sum(abs2, d)
    end
  end
  # the samples exercise acceptance and rejection, and the cached-image path and the fresh product
  @test accepted > 0 && rejected > 0 && fresh > 0 && cheap > 0
end

# ---- accepted trials of real solves ---------------------------------------------------------------------------------

# The iterations of APG on the problem, one `update_state!` at a time. After a call, state.y, state.x and state.L belong to
# the trial that the line search of the update accepted last: y is the extrapolated point (the previous accepted point
# after a restart), x that trial and L its curvature. A provisional trial that the restart of the update discards is
# outside the check. For each update whose final trial has x ≠ y, in BigFloat from the stored data and for ε = eps:
#   - the image inequality that _bound_certified! certifies, ¼‖X d‖² ≤ (1 + 4ε)² L ‖d‖² for d = x - y (a falsifiable
#     statement about the stored points);
#   - the descent inequality f(x) ≤ f(y) + ⟨∇f(y), d⟩ + (L/2)(1 + 4ε)²‖d‖², which follows from it in exact arithmetic
#     because ∇²f ⪯ ¼XᵀX (APG-08). The evaluation rounds in BigFloat at about 1e-77 relative; `slack` is 1e-60 of the
#     size of the terms.
# It returns the counts of updates with a nonzero final step, whose completed L exceeds the decreased initial L of the
# update (α times the previous L, so a rejected trial and a retry happened), with momentum and without a restart, and
# with a restart.
function accepted_trials(X, y, λ, w; iterations)
  f, g = LogisticLoss(y, X), penalty(λ, w)
  x0 = zeros(size(X, 2))
  PS._check_gradient_problem(x0, f, g, :gradient)
  method = AccProxGradDescent()
  g_work = PS._working_gradient_penalty(g, Float64)
  state = PS.initial_state(method, OPTS, f, g_work, x0)
  A = big.(X)
  ε = big(eps())
  nonzero = raised = momentum = restarted = 0
  for _ in 1:iterations
    initial, k, restarts = state.L * method.α, state.k, state.restarts
    PS.update_state!(f, g_work, state, method)
    d = big.(state.x) .- big.(state.y)
    q = sum(abs2, d)
    iszero(q) && continue
    nonzero += 1
    raised += state.L > initial
    momentum += k > 0 && state.restarts == restarts
    restarted += state.restarts > restarts
    L = big(state.L)
    @test sum(abs2, A * d) / 4 <= (1 + 4ε)^2 * L * q
    f0, f1 = oracle(X, y, state.y), oracle(X, y, state.x)
    bound = f0.value + dot(f0.gradient, d) + L / 2 * (1 + 4ε)^2 * q
    slack = big(10)^-60 * (1 + abs(f0.value) + abs(f1.value) + L * q)
    @test f1.value <= bound + slack
  end
  (; nonzero, raised, momentum, restarted)
end

@testset "accepted trials of APG satisfy the certified image inequality and the descent inequality" begin
  for (label, X, y, λ, w) in fixtures()[1:2]
    counts = accepted_trials(X, y, λ, w; iterations = 100)
    println("logistic APG accepted trials, $label: ", counts)
    # the check ran on updates in which L was raised, on updates with momentum and on updates that restarted
    @test counts.nonzero > 0 && counts.raised > 0 && counts.momentum > 0 && counts.restarted > 0
  end
end

@testset "APG starts from the curvature of PGD" begin
  X, y = logistic_data(50, 4; seed = 3)
  k = size(X, 2)
  # ¼‖X‖_F² below 1: the start is that value (PGD-02 with the factor ¼), from an upper bound on ‖X‖_F, in both solvers
  Xs = X ./ 64
  La = PS.initial_state(AccProxGradDescent(), OPTS, LogisticLoss(y, Xs), NormL1(0.1), zeros(k)).L
  Lp = PS.initial_state(ProximalGradientDescent(), OPTS, LogisticLoss(y, Xs), NormL1(0.1), zeros(k)).L
  q = Float64(sum(abs2, big.(Xs)) / 4)
  @test q < 1
  # the two estimates form the sum of squares in different orders, so they agree to within rounding of that sum
  @test La >= q
  @test La ≈ q rtol = 1e-12
  @test La ≈ Lp rtol = 1e-12
  # ¼‖X‖_F² above 1: the start is 1 in both
  @test Float64(sum(abs2, big.(X)) / 4) > 1
  @test PS.initial_state(AccProxGradDescent(), OPTS, LogisticLoss(y, X), NormL1(0.1), zeros(k)).L == 1.0
  @test PS.initial_state(ProximalGradientDescent(), OPTS, LogisticLoss(y, X), NormL1(0.1), zeros(k)).L == 1.0
  # a zero design starts at 1, and a positive estimate that is below floatmin(Float64) at floatmin(Float64) (PGD-02), in both
  for (scale, expected) in ((0.0, 1.0), (1e-170, floatmin()))
    Xz = fill(scale, 3, 2)
    for method in (AccProxGradDescent(), ProximalGradientDescent())
      @test PS.initial_state(method, OPTS, LogisticLoss([1.0, 0.0, 1.0], Xz), NormL1(1.0), zeros(2)).L == expected
    end
  end
end

# ---- accuracy of the solutions ----------------------------------------------------------------------------------------

@testset "regularized fits: objective and KKT scores of every coordinate" begin
  for (index, (label, X, y, λ, w)) in enumerate(fixtures())
    n, k = size(X)
    @test 0 < sum(y) < n
    b = zeros(k)
    r = solve!(b, LogisticLoss(y, X), penalty(λ, w), AccProxGradDescent(), OPTS)
    @test r.minimizer === b
    @test r.converged
    S = stop_scale(X, y, λ, w)
    τ = max(OPTS.gradtol, 64eps())
    s = scores(oracle(X, y, b).gradient, b, λ, w)
    slack = rounding_bound(X, b)
    @test slack <= 0.01 * τ * S
    # every coordinate is below the threshold of the stop (plus the rounding allowance of check_stop), the intercept
    # column's coordinate included: it is unpenalized where w[1] = 0 and penalized in the unweighted fixture
    @test all(<(big(τ * S + slack)), s)
    # the first two fixtures have sparse minimizers with active and inactive coefficients
    index <= 2 && @test 0 < count(!iszero, b) < k
    w === nothing || @test w[1] == 0 && s[1] < big(τ * S + slack)      # the unpenalized intercept: |∂f/∂b₁|
    # the reported objective sums n Float64 terms; a relative 1e-12 covers their rounding
    @test r.minimum ≈ Float64(objective(X, y, b, λ, w)) rtol = 1e-12
    # the objective against PGD's at the same options and against a tight reference, through the convexity bound of
    # objective_gap; the reference is PGD with a tighter gradient test. The bound grows with the residual of each point,
    # so each control converges and has its own independent residual checked: PGD's like APG's, and the reference's
    # at least 100 times below the threshold of the stop of APG and PGD
    bp, bref = zeros(k), zeros(k)
    rp = solve!(bp, LogisticLoss(y, X), penalty(λ, w), ProximalGradientDescent(), OPTS)
    rref = solve!(bref, LogisticLoss(y, X), penalty(λ, w), ProximalGradientDescent(), REF)
    @test rp.converged && rref.converged
    check_stop(X, y, bp, λ, w, OPTS)
    @test check_stop(X, y, bref, λ, w, REF; margin = false) < 0.01 * τ * S
    for other in (bp, bref)
      gap = objective_gap(X, y, λ, w, b, other)
      @test gap.gap <= gap.bound + gap.rounding
    end
    println("logistic APG, $label: iterations = $(r.iterations), trials = $(r.backtrack_steps), ",
            "KKT / (τ S) = $(Float64(kkt_residual(X, y, b, λ, w) / (τ * S)))")
  end
end

@testset "intercept-only model and a level above the slope threshold" begin
  X, y = logistic_data(150, 8; seed = 5)
  n, k = size(X)
  ybar = sum(y) / n
  @test 0 < ybar < 1 && ybar != 0.5
  b0 = log(ybar / (1 - ybar))
  w = [0.0; ones(k - 1)]
  # the intercept column alone, unpenalized and with a zero weight under a positive level: a stop needs
  # |n(σ(b₁) - ȳ)| < 1e-8 S with S = n|½ - ȳ|, and the slope of σ at logit(ȳ) is ȳ(1 - ȳ), so b₁ is within about
  # 1e-8 |½ - ȳ| / (ȳ(1 - ȳ)) of logit(ȳ); 1e-6 leaves a margin
  for (λ, w1) in ((0.0, nothing), (3.0, [0.0]))
    b = [0.0]
    r = solve!(b, LogisticLoss(y, X[:, 1:1]), penalty(λ, w1), AccProxGradDescent(), OPTS)
    @test r.converged
    @test b[1] ≈ b0 atol = 1e-6
    check_stop(X[:, 1:1], y, b, λ, w1, OPTS)
  end
  # with slopes, from a start with nonzero slopes: at a level of at least ‖Zᵀ(ȳ - y)‖∞ the slopes are zero at the
  # minimizer and the intercept is logit(ȳ). Near the minimizer a nonzero slope would score at least about
  # level - level/1.05 > 0.04 level, far above the threshold of a stop, so the run ends with exact zeros.
  for factor in (1.05, 3.0)
    level = factor * slope_threshold(X, y)
    b = [0.0; fill(0.5, k - 1)]
    r = solve!(b, LogisticLoss(y, X), NormL1(level, w), AccProxGradDescent(), OPTS)
    @test r.converged
    @test all(iszero, b[2:end])
    @test b[1] ≈ b0 atol = 1e-6
    check_stop(X, y, b, level, w, OPTS)
  end
end

@testset "unpenalized fit against a damped Newton reference" begin
  X, y = logistic_data(200, 4; seed = 6)
  n, k = size(X)
  bref, gnorm = newton(X, y)
  @test gnorm < 1e-30
  # numerical evidence that a finite minimizer exists (see test/logistic_pgd.jl)
  @test nonseparable(X, y, bref) > 1
  b64 = Float64.(bref)
  Gref = oracle(X, y, b64).gradient
  for g in (NormL1(0.0), NormL1(0.0, zeros(k)))
    b = zeros(k)
    r = solve!(b, LogisticLoss(y, X), g, AccProxGradDescent(), OPTS)
    @test r.converged
    check_stop(X, y, b, 0.0, g.w, OPTS)
    G = oracle(X, y, b).gradient
    # μ estimates a lower bound on the curvature on the segment from b to b64, under which, in exact arithmetic,
    # ‖b - b64‖₂ ≤ ‖∇f(b) - ∇f(b64)‖₂ / μ. The residual is below about 1e-8 S with S of the order of 10 and μ of the
    # order of 10, so the distance is of the order of 1e-8 and 1e-6 leaves a margin.
    μ = segment_curvature(X, b, b64)
    @test μ > 0 && Float64(norm(G - Gref)) / μ <= 1e-6 * max(1, norm(b64, Inf))
    @test norm(b - b64, Inf) <= 1e-6 * max(1, norm(b64, Inf))
    @test r.minimum ≈ Float64(oracle(X, y, bref).value) rtol = 1e-12
  end
end

# A run on a problem with strong logits: a finite result that converged, with the independent residual of the stop, as
# the plan of the tests requires of almost separated regularized problems
function check_hard_case(label, X, y, level, w, start)
  b, r, state = apg_run(X, y, level, w, OPTS; x0 = start)
  @test all(isfinite, b) && isfinite(r.minimum)
  @test r.converged
  residual = check_stop(X, y, b, level, w, OPTS)
  println("logistic APG, $label: iterations = $(r.iterations), trials = $(r.backtrack_steps), restarts = $(state.restarts), ",
          "KKT / S = $(Float64(residual / stop_scale(X, y, level, w))), max |X b| = $(maximum(abs, X * b))")
  @test !isnan(r.g_residual) && !isnan(r.f_residual) && !isnan(r.x_residual)
  @test r.minimum ≈ Float64(objective(X, y, b, level, w)) rtol = 1e-10
  b
end

@testset "strong finite logits and almost separated regularized problems" begin
  # a steep model on covariates of scale 20, from zero and from a start where |X b| is in the thousands, beyond
  # log(floatmax(Float64)) ≈ 709.78, above which exp(|η|) overflows in Float64
  rng = Xoshiro(11)
  n = 80
  X = [ones(n) 20 .* randn(rng, n, 2)]
  y = Float64.(rand(rng, n) .< sigmoid.(X * [0.5, 3.0, -2.0]))
  @test 0 < sum(y) < n
  level = 0.02 * slope_threshold(X, y)
  start = [0.0, 40.0, -40.0]
  @test maximum(abs, X * start) > log(floatmax(Float64))
  b1 = check_hard_case("steep model from zero", X, y, level, [0.0, 1.0, 1.0], zeros(3))
  b2 = check_hard_case("steep model from $start", X, y, level, [0.0, 1.0, 1.0], start)
  # both runs solve the same strictly convex-in-slopes problem; their objectives agree to within the convexity bound
  gap = objective_gap(X, y, level, [0.0, 1.0, 1.0], b1, b2)
  @test gap.gap <= gap.bound + gap.rounding
  # one covariate on an even grid with a penalized slope and an unpenalized intercept: classes separated by the sign of
  # the covariate, and the same with two labels near zero exchanged. On each sublevel set of the objective the positive
  # slope penalty bounds the slope; with the slope bounded and both classes present, the loss grows without bound with
  # |b₁|, so the sublevel sets are bounded and each problem has a finite minimizer.
  z = collect(range(-2.0, 2.0; length = 21))
  X = [ones(21) z]
  y = Float64.(z .> 0)
  check_hard_case("separated, regularized", X, y, 0.01 * slope_threshold(X, y), [0.0, 1.0], zeros(2))
  y[10], y[12] = 1.0, 0.0
  check_hard_case("almost separated, regularized", X, y, 0.01 * slope_threshold(X, y), [0.0, 1.0], zeros(2))
  # strong planted slopes at a small level
  X, y = logistic_data(200, 30; seed = 3, signal = [6.0, -4.0, 3.0, -2.0, 1.0])
  check_hard_case("strong signal, p = 30", X, y, 0.02 * slope_threshold(X, y), [0.0; ones(size(X, 2) - 1)], zeros(size(X, 2)))
end

# ---- momentum and convergence reports -----------------------------------------------------------------------------------

@testset "momentum restarts occur, and no reported stop fails the independent KKT check" begin
  for (label, X, y, λ, w) in fixtures()
    b, r, state = apg_run(X, y, λ, w, OPTS)
    @test r.converged
    check_stop(X, y, b, λ, w, OPTS)
    # some iterations restarted and not all did; the updates with momentum and with a restart are counted in
    # accepted_trials
    @test state.restarts > 0 && state.restarts < r.iterations
  end
  # a converged = true under the default options (gradtol = 1e-5) is also checked; those runs are not required to stop
  # earlier than the tight ones, and their iteration counts are printed
  defaults = ProximalOptions()
  for (label, X, y, λ, w) in fixtures()
    b, r, state = apg_run(X, y, λ, w, defaults)
    r.converged && check_stop(X, y, b, λ, w, defaults)
    println("logistic APG, default options, $label: converged = $(r.converged), iterations = $(r.iterations), ",
            "restarts = $(state.restarts)")
  end
end

@testset "rejected trials: a small start of L is raised and the fit stays accurate" begin
  X, y = logistic_data(200, 12; seed = 8)
  n, k = size(X)
  λ = 0.1 * norm(X' * (0.5 .- y), Inf)
  b, r, state = apg_run(X, y, λ, nothing, OPTS)
  @test r.converged
  # L starts at 1, is multiplied by α < 1 at the start of each iteration, and grows only through a rejected trial; it
  # ends above 1 because the start is far below ¼‖X‖₂² here
  @test PS.initial_state(AccProxGradDescent(), OPTS, LogisticLoss(y, X), NormL1(λ), zeros(k)).L == 1.0
  @test state.L > 1
  check_stop(X, y, b, λ, nothing, OPTS)
end

@testset "a stalled iterate under ftol = 0 (STOP-10) is a KKT point; with ftol > 0 the stop is checked and taken" begin
  # no column of ones, a level above ‖∇f(0)‖∞: the solution is zero, and each trial from zero is zero. The iterate stays
  # at zero, so under ftol = 0 no stop is proposed and the run ends at maxiter; under the default ftol the unchanged
  # iterate proposes a stop, whose stationarity check passes (the residual at zero is zero).
  X, y = logistic_data(60, 5; seed = 31)
  X = X[:, 2:end]
  λ = 1.5 * norm(X' * (0.5 .- y), Inf)
  scale = stop_scale(X, y, λ)
  for options in (ProximalOptions(maxiter = 30, ftol = 0, allow_f_increases = true), ProximalOptions(maxiter = 30))
    b, r, state = apg_run(X, y, λ, nothing, options)
    @test all(iszero, b)
    # the point is optimal: every score is zero in BigFloat (|∇fⱼ(0)| ≤ λ)
    @test all(iszero, scores(oracle(X, y, b).gradient, b, λ))
    @test scale == λ
    @test r.backtrack_steps == r.iterations              # each iteration accepts its first trial, a zero step
    if options.ftol == 0
      @test !r.converged && r.iteration_converged && r.iterations == 30
    else
      @test r.converged && r.iterations < 30
    end
  end
end

# ---- failures -----------------------------------------------------------------------------------------------------------

@testset "an error in an iteration restores the last accepted point" begin
  X, y = logistic_data(60, 3; seed = 9)
  f, g = LogisticLoss(y, X), NormL1(1.0, [0.0, 1.0, 1.0, 1.0])
  method = AccProxGradDescent()
  # Fault injection after an accepted step, as for least squares in test/minimal_core_characterization.jl:
  # L = 0 makes the next trial nonfinite, and its curvature estimate cannot increase.
  state = PS.initial_state(method, ProximalOptions(), f, g, zeros(4))
  PS.update_state!(f, g, state, method)
  accepted = copy(state.x)
  @test accepted != zeros(4)
  state.L = 0.0
  @test_throws r"curvature estimate cannot increase finitely" PS._solve_gradient!(state, f, g, method, ProximalOptions())
  @test state.x == accepted
  # Through solve!: the start has a finite loss and an infinite penalty (c₂|x₂| above floatmax). The first accepted trial
  # keeps x₂ near 1e200, its objective is not finite, and solve! restores the start.
  x0 = [1.0, 1e200]
  x = copy(x0)
  fk, gk = LogisticLoss([1.0], [2.0 0.0]), NormL1(1.0, [1.0, 1e109])
  @test isfinite(fk(x0)) && !isfinite(gk(x0))
  @test_throws ErrorException solve!(x, fk, gk, method)
  @test isequal(x, x0)
end

@testset "an overflowed image is a nonfinite start, trial or extrapolated point" begin
  method = AccProxGradDescent()
  # At the start: X b = [Inf]. ProximalBase gives the loss 0 for an infinite predictor on the side of the label
  # (y = 1) and Inf on the other (y = 0); both starts are refused with the coefficients unchanged.
  for y1 in (1.0, 0.0)
    b = [floatmax(Float64) / 2]
    err = try
      solve!(b, LogisticLoss([y1], fill(8.0, 1, 1)), NormL1(1.0, [0.0]), method)
      nothing
    catch e
      e
    end
    @test err isa ArgumentError && occursin("start from a point where f is finite", sprint(showerror, err))
    @test b == [floatmax(Float64) / 2]
  end
  # In a trial: from zero with X = 2e154 in the single row, NormL1(0.0) and the default factors, the first trial
  # x = ±1e154/0.9 has an overflowing image, so its value is Inf and L is raised (APG-03). The certified test (APG-08)
  # needs L ≥ ¼ X² / (1 + 4eps)² for a nonzero displacement, about 1e308, which is below floatmax(Float64); L starts at 0.9
  # and doubles per rejected trial, so the first update takes at least 1024 trials, and the accepted L is finite. PGD's
  # value-based search with Lexact = 0.9 accepts the same fixture at L = 1.8 (test/logistic_pgd.jl).
  X1 = fill(2e154, 1, 1)
  for (y1, sign) in (([1.0], 1), ([0.0], -1))
    f, g = LogisticLoss(y1, X1), NormL1(0.0)
    state = PS.initial_state(method, ProximalOptions(), f, g, [0.0])
    PS.update_state!(f, g, state, method)
    bound = big(2e154)^2 / 4
    @test big(state.L) * (1 + 4 * big(eps()))^2 >= bound
    @test state.L <= floatmax(Float64)
    @test state.backtrack_steps >= 1024
    @test all(isfinite, X1 * state.x) && isfinite(state.f_x)
    @test state.x ≈ [sign * 1e154 / state.L] rtol = 1e-14
  end
  # With the three rows of response [1, 1, 0], ¼‖X‖_F² is about 3e308, above floatmax, so no finite L is certified for the
  # nonzero first displacement from zero: the search raises and solve! restores the start.
  x3 = [0.0]
  @test_throws r"curvature estimate cannot increase finitely" solve!(x3, LogisticLoss([1.0, 1.0, 0.0], fill(2e154, 3, 1)),
                                                                     NormL1(0.0), method)
  @test x3 == [0.0]
  # The lower bound applies to a nonzero displacement: from [1e-150] with every response entry 1, the Float64 gradient at the
  # start is zero, the first trial equals y, and it is accepted at L = 0.9 (the start 1 decreased by α), for one row and three.
  for n in (1, 3)
    f, g = LogisticLoss(ones(n), fill(2e154, n, 1)), NormL1(0.0)
    state = PS.initial_state(method, ProximalOptions(), f, g, [1e-150])
    PS.update_state!(f, g, state, method)
    @test state.L == 0.9 && state.backtrack_steps == 1 && state.x == state.y == [1e-150]
  end
  # The extrapolated point: X = I, y = [1, 0], x = [1e308, 0] and x_previous = [-1e308, 0] have finite images and values
  # (log 2 and 1e308), but x - x_previous overflows, so the extrapolated point and its image are not finite. The step
  # restarts once from the last accepted point.
  X2, y2 = [1.0 0.0; 0.0 1.0], [1.0, 0.0]
  f, g = LogisticLoss(y2, X2), NormL1(0.0)
  state = PS.initial_state(method, ProximalOptions(), f, g, zeros(2))
  state.x .= [1e308, 0.0]
  state.x_previous .= [-1e308, 0.0]
  state.z_x .= X2 * state.x
  state.z_previous .= X2 * state.x_previous
  state.normx = PS._se_norm(Float64, state.x)
  state.normx_previous = PS._se_norm(Float64, state.x_previous)
  image = similar(state.z_x)
  state.f_x = PS._value!(state.x, f, state.model, image)
  state.g_x = 0.0
  state.k = 1000
  @test isfinite(state.f_x) && isfinite(PS._value!(state.x_previous, f, state.model, image))
  calls = state.grad_calls
  PS.update_state!(f, g, state, method)
  @test state.restarts == 1 && state.k == 1
  # one gradient request at the overflowing y (the logistic oracle is skipped for its nonfinite image, and the request is
  # counted), one at the restart point
  @test state.grad_calls - calls == 2
  @test state.y == state.x_previous == [1e308, 0.0] && state.z_y == state.z_previous
  # the restarted step may round to x == y, so the objective does not increase but need not decrease
  @test isfinite(state.f_x) && state.f_x <= state.f_x_previous
end

@testset "one class with an unpenalized intercept: no finite minimizer" begin
  # y = ones(8) with an intercept column of ones and weight zero: F(b₁) = 8 log(1 + e^{-b₁}) decreases toward 0 as b₁ → +∞,
  # its derivative -8σ(-b₁) is negative at every finite b₁, and no minimizer exists (IN-09). The computed residual can still
  # fall below the threshold, so neither outcome of `converged` is required. The results must be finite, and when
  # convergence is reported the independent BigFloat residual is checked against the threshold of the stop plus the
  # rounding allowance of check_stop.
  X1, y1 = ones(8, 1), ones(8)
  λ, w = 0.1, [0.0]
  options = ProximalOptions(maxiter = 1000, gradtol = 1e-10)
  # from zero, and from a start where σ(-b₁) underflows in Float64
  for start in ([0.0], [1000.0])
    b = copy(start)
    r = solve!(b, LogisticLoss(y1, X1), NormL1(λ, w), AccProxGradDescent(), options)
    @test r.minimizer === b
    @test all(isfinite, b) && isfinite(r.minimum)
    @test isfinite(r.x_residual) && isfinite(r.f_residual) && isfinite(r.g_residual)
    @test oracle(X1, y1, b).gradient[1] < 0     # in BigFloat, nonzero where the Float64 derivative underflows
    println("logistic APG, one class from $start: converged = $(r.converged), iterations = $(r.iterations), b₁ = $(b[1])")
    r.converged && check_stop(X1, y1, b, λ, w, options)
  end
end

@testset "iteration and call limits report nonconvergence" begin
  X, y = logistic_data(200, 12; seed = 10)
  n, k = size(X)
  level = 0.05 * norm(X' * (0.5 .- y), Inf)
  f, g = LogisticLoss(y, X), NormL1(level)
  b = zeros(k)
  r = solve!(b, f, g, AccProxGradDescent(), ProximalOptions(maxiter = 3, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-12))
  @test r.minimizer === b
  @test r.iterations == 3 && r.iteration_converged && !r.converged
  @test r.minimum ≈ Float64(objective(X, y, b, level)) rtol = 1e-12
  b = zeros(k)
  r = solve!(b, f, g, AccProxGradDescent(),
             ProximalOptions(maxiter = 1000, f_calls_limit = 6, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-12))
  @test r.call_limit_reached && !r.converged && r.f_calls >= 6 && r.iterations < 1000
  @test r.minimum ≈ Float64(objective(X, y, b, level)) rtol = 1e-12
end

# ---- counters ---------------------------------------------------------------------------------------------------------

@testset "the counter identities of APG-04 hold for a logistic solve" begin
  X, y = logistic_data(200, 12; seed = 8)
  k = size(X, 2)
  level = 0.1 * norm(X' * (0.5 .- y), Inf)
  f, g = LogisticLoss(y, X), NormL1(level)
  method = AccProxGradDescent()
  # no stationarity check: one gradient per step and one more per restart, one value per trial and at the start
  state = PS.initial_state(method, OPTS, f, g, zeros(k))
  for _ in 1:40
    PS.update_state!(f, g, state, method)
  end
  @test state.restarts > 0
  @test state.grad_calls == 40 + state.restarts
  @test state.backtrack_steps == state.prox_calls
  @test state.f_calls == 1 + state.grad_calls + state.prox_calls
  # a solve: C, the number of stationarity checks, is determined by each identity, and the two must agree. A check is made
  # at each proposed stop, so a converged solve has made at least one (the one that passed) and at most one per iteration;
  # a dedicated KKT check adds no proximal call.
  for options in (OPTS, ProximalOptions())
    b = zeros(k)
    r = solve!(b, f, g, method, options)
    @test r.converged
    check_stop(X, y, b, level, nothing, options)
    C = 1 + r.grad_calls + r.prox_calls - r.f_calls
    state = PS.initial_state(method, options, f, g, zeros(k))
    r2 = PS._solve_gradient!(state, f, g, method, options)
    @test r2.iterations == r.iterations && r2.grad_calls == r.grad_calls
    @test C == r.grad_calls - r.iterations - state.restarts
    @test 1 <= C <= r.iterations
    @test r.backtrack_steps == r.prox_calls
  end
end

# The bytes of a warmed solve, setup included, measured inside a function; the minimum of three runs after one
# warm-up run
function solve_bytes(f, g, x0, o)
  run() = (x = copy(x0); @allocated solve!(x, f, g, AccProxGradDescent(), o))
  run()
  minimum(run() for _ in 1:3)
end

# The largest number of bytes of one of ten warmed iterations (update_state!), measured inside a function
function iteration_bytes(f, g, x0)
  method = AccProxGradDescent()
  state = PS.initial_state(method, ProximalOptions(), f, g, copy(x0))
  PS.update_state!(f, g, state, method)
  bytes = 0
  for _ in 1:10
    bytes = max(bytes, @allocated PS.update_state!(f, g, state, method))
  end
  bytes
end

@testset "a warmed logistic solve allocates no more than the least-squares control" begin
  X, y = logistic_data(100, 8; seed = 13)
  k = size(X, 2)
  g = NormL1(1.0, [0.0; ones(k - 1)])
  # for this fixture and penalty, ten warmed iterations allocate nothing, for logistic and for least squares
  @test iteration_bytes(LogisticLoss(y, X), g, zeros(k)) == 0
  @test iteration_bytes(LeastSquaresLoss(y, X), g, zeros(k)) == 0
  # whole solves of at most 30 iterations each, setup included, with two option sets: xtol = 1e-300 with ftol and
  # gradtol zero, under which the proposal tests do not hold for these solves, and xtol = 1e10, under which the
  # iterate test proposes a stop at each iteration that moves x, so that the stationarity check runs
  for o in (ProximalOptions(maxiter = 30, ftol = 0, xtol = 1e-300, gradtol = 0, allow_f_increases = true),
            ProximalOptions(maxiter = 30, ftol = 0, xtol = 1e10, gradtol = 0, allow_f_increases = true))
    logistic = solve_bytes(LogisticLoss(y, X), g, zeros(k), o)
    control = solve_bytes(LeastSquaresLoss(y, X), g, zeros(k), o)
    println("allocations, xtol = $(o.xtol): logistic $logistic bytes, least squares $control bytes")
    @test logistic <= control
  end
end

# ---- refusals ---------------------------------------------------------------------------------------------------------

# The exception of a refused call and whether x kept its entries (isequal: NaN entries compare equal)
function refusal(x, f, g, method)
  before = collect(x)
  err = try
    solve!(x, f, g, method)
    nothing
  catch e
    e
  end
  err, isequal(collect(x), before)
end

@testset "refusals before any write" begin
  X, y = logistic_data(40, 3; seed = 12)
  n, k = size(X)
  f = LogisticLoss(y, X)
  w = [0.0, 1.0, 1.0, 1.0]
  g = NormL1(1.0, w)
  apg = AccProxGradDescent()
  start = [0.1, -0.2, 0.3, 0.0]
  groups = [[1, 2], [3, 4]]
  row = reshape(copy(start), 1, 4)                  # shares the memory of vec(row)
  Xsq, ysq = X[1:4, :], [0.0, 1.0, 0.0, 1.0]         # n = p, so x can be y or the scratch of the loss
  fsq = LogisticLoss(ysq, Xsq)
  wv = copy(w)
  mutated(change!) = (Xc = copy(X); yc = copy(y); fc = LogisticLoss(yc, Xc); change!(Xc, yc); fc)
  # a NormL1 whose second weight is changed after construction
  reweighted(v) = (wm = copy(w); gm = NormL1(1.0, wm); wm[2] = v; gm)
  cases = [
    # CDSolver on a dense Vector: the solver-kind check, the first check of the gate (`kind` :cd), refuses the loss and
    # names PGD, APG and ProxNewton
    (copy(start), f, g, CDSolver(), ArgumentError,
     "supported only by ProximalGradientDescent, AccProxGradDescent and ProxNewton, on a dense Vector{Float64} " *
     "with a NormL1 penalty; CDSolver does not support it"),
    # matrix coefficients: APG's matrix method needs a least-squares loss, so the logistic gate refuses them
    ([1.0 0.1; 0.1 1.0], f, NormL1(1.0), apg, ArgumentError, "x to be a dense Vector{Float64}"),
    ([1.0 0.1; 0.1 1.0], (1 / n) * f, NormL1(1.0), apg, ArgumentError, "Scaled(LogisticLoss) is not supported"),
    # the loss and the arrays
    (copy(start), (1 / n) * f, g, apg, ArgumentError, "Scaled(LogisticLoss) is not supported"),
    (Float32.(start), LogisticLoss(Float32.(y), Float32.(X)), NormL1(1f0, Float32.(w)), apg, ArgumentError,
     "X::Matrix{Float64} and y::Vector{Float64}"),
    (copy(start), LogisticLoss(y, sparse(X)), g, apg, ArgumentError, "X::Matrix{Float64}"),
    (copy(start), LogisticLoss(y, view(X, :, 1:k)), g, apg, ArgumentError, "X::Matrix{Float64}"),
    (copy(start), LogisticLoss(view(y, 1:n), X), g, apg, ArgumentError, "y::Vector{Float64}"),
    (Float32.(start), f, NormL1(1f0, Float32.(w)), apg, ArgumentError, "x to be a dense Vector{Float64}"),
    (view(copy(start), 1:k), f, g, apg, ArgumentError, "x to be a dense Vector{Float64}"),
    (SparseIterate(copy(start)), f, g, apg, ArgumentError, "x to be a dense Vector{Float64}"),
    (copy(start), LogisticLoss(y, X; weights = ones(n)), g, apg, ArgumentError, "observation weights or an offset"),
    (copy(start), LogisticLoss(y, X; offset = zeros(n)), g, apg, ArgumentError, "observation weights or an offset"),
    # shapes
    (zeros(k + 1), f, NormL1(1.0), apg, DimensionMismatch, "x/y dimensions do not match X"),
    (zeros(k - 1), f, NormL1(1.0), apg, DimensionMismatch, "x/y dimensions do not match X"),
    (zeros(k), LogisticLoss(zeros(0), zeros(0, k)), NormL1(1.0), apg, DimensionMismatch, "positive row and column counts"),
    (zeros(0), LogisticLoss(y, zeros(n, 0)), NormL1(1.0), apg, DimensionMismatch, "positive row and column counts"),
    (copy(start), mutated((Xc, yc) -> resize!(yc, n - 1)), g, apg, DimensionMismatch, "x/y dimensions do not match X"),
    # penalties other than NormL1, then the NormL1 rules
    (copy(start), f, ElasticNet(1.0, 1.0), apg, ArgumentError, "only NormL1"),
    (copy(start), f, NormLinf(1.0), apg, ArgumentError, "only NormL1"),
    (copy(start), f, GroupNormL2(1.0, groups), apg, ArgumentError, "only NormL1"),
    (copy(start), f, NormL1Nonneg(1.0), apg, ArgumentError, "only NormL1"),
    (abs.(start), f, IndNonnegative(), apg, ArgumentError, "only NormL1"),
    (copy(start), f, IndBox(-1.0, 1.0), apg, ArgumentError, "only NormL1"),
    (copy(start), f, SqrNormL2(1.0), apg, ArgumentError, "only NormL1"),
    (copy(start), f, 2 * g, apg, ArgumentError, "only NormL1"),
    (copy(start), f, NormL1(1.0, [0.0, 1.0, 1.0]), apg, DimensionMismatch, "3 weights"),
    (copy(start), f, NormL1(1.0, Float32.(w)), apg, ArgumentError, "penalty weights must be a Vector{Float64}"),
    (copy(start), f, NormL1(1e300, [0.0, 1e10, 1.0, 1.0]), apg, ArgumentError, "overflows"),
    (copy(start), f, reweighted(-1.0), apg, ArgumentError, "penalty weight 2 must be finite and nonnegative"),
    (copy(start), f, reweighted(Inf), apg, ArgumentError, "penalty weight 2 must be finite and nonnegative"),
    (copy(start), f, reweighted(NaN), apg, ArgumentError, "penalty weight 2 must be finite and nonnegative"),
    # aliasing
    (wv, f, NormL1(1.0, wv), apg, ArgumentError, "must not alias the penalty weights"),
    (vec(row), LogisticLoss([1.0], row), g, apg, ArgumentError, "must not alias borrowed X or y"),
    (ysq, fsq, g, apg, ArgumentError, "must not alias borrowed X or y"),
    (fsq.tmp, fsq, g, apg, ArgumentError, "scratch of the loss"),
    # values
    ([0.1, NaN, 0.3, 0.0], f, g, apg, ArgumentError, "finite"),
    ([0.1, Inf, 0.3, 0.0], f, g, apg, ArgumentError, "finite"),
    (copy(start), mutated((Xc, yc) -> (Xc[2, 3] = Inf)), g, apg, ArgumentError, "finite"),
    (copy(start), mutated((Xc, yc) -> (Xc[5, 2] = NaN)), g, apg, ArgumentError, "finite"),
    (copy(start), mutated((Xc, yc) -> (yc[3] = 0.5)), g, apg, ArgumentError,
     "LogisticLoss with AccProxGradDescent needs a binary response: entry 3 of y is 0.5, not 0 or 1"),
    (copy(start), mutated((Xc, yc) -> (yc[3] = NaN)), g, apg, ArgumentError, "LogisticLoss with AccProxGradDescent needs a binary response"),
    (copy(start), mutated((Xc, yc) -> (yc[3] = 2.0)), g, apg, ArgumentError, "LogisticLoss with AccProxGradDescent needs a binary response"),
    (copy(start), LogisticLoss(fill(0.25, n), X), g, apg, ArgumentError, "LogisticLoss with AccProxGradDescent needs a binary response"),
  ]
  for (i, (x, loss, penalty, method, E, message)) in enumerate(cases)
    err, unchanged = refusal(x, loss, penalty, method)
    text = err === nothing ? "" : sprint(showerror, err)
    @test (i, err isa E) == (i, true)
    @test (i, occursin(message, text)) == (i, true)
    @test (i, unchanged) == (i, true)
  end
  # the same inputs with a Float64 start and the binary data are accepted, and PGD keeps its own message for a
  # nonbinary response
  b = copy(start)
  @test solve!(b, f, g, apg).minimizer === b
  err, _ = refusal(copy(start), mutated((Xc, yc) -> (yc[3] = 0.5)), g, ProximalGradientDescent())
  @test err isa ArgumentError && occursin("LogisticLoss with ProximalGradientDescent needs a binary response", sprint(showerror, err))
end

end
