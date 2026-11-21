module LogisticPGDTest
# Sparse logistic regression with ProximalGradientDescent (IN-09): a raw LogisticLoss{Float64} on a dense
# Matrix{Float64} with a binary Vector{Float64} response, no observation weights or offset, and NormL1 with or
# without penalty weights on a Vector{Float64}. The references below are computed from the stored data in BigFloat
# with formulas of their own, not with ProximalBase's oracles.
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
# stationarity residual of the composite objective.
scores(G, b, λ, w = nothing) =
  [iszero(b[j]) ? max(abs(G[j]) - coefficient(λ, w, j), 0) : abs(G[j] + coefficient(λ, w, j) * sign(b[j]))
   for j in eachindex(b)]

objective(X, y, b, λ, w = nothing) =
  oracle(X, y, b).value + sum(coefficient(λ, w, j) * abs(big(b[j])) for j in eachindex(b))

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

# A numerical witness, computed in BigFloat, that the data (X, y) are not separable, even weakly. At any b the
# weights uᵢ = |yᵢ - σ(ηᵢ)| = σ(-rᵢηᵢ), rᵢ = 2yᵢ - 1, are positive and satisfy Aᵀu = -∇f(b) for A = diag(r) X.
# In exact arithmetic the least-squares correction c = A (AᵀA)⁻¹ Aᵀu gives Aᵀ(u - c) = 0, and if u - c > 0 and X
# has full column rank, no d ≠ 0 has rᵢ xᵢᵀd ≥ 0 for every i (0 = Σᵢ (uᵢ - cᵢ) rᵢ xᵢᵀd would force X d = 0), so the
# unpenalized loss has a finite minimizer. Here c and the rank are computed numerically. Returns
# min(u - c) / max|c|, the margin of the computed corrected weights over the computed correction.
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
# intercept -0.3 and the planted slopes `signal` on the first covariates.
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

# Tight options for the accuracy checks: a stop needs a computed KKT residual below 1e-10 S (STOP-04)
const TIGHT = ProximalOptions(maxiter = 20_000, ftol = 1e-15, xtol = 1e-12, gradtol = 1e-10, allow_f_increases = true)

# The tolerance of the independent residual in the checks that use KKT_TOL (with TIGHT). A stop needs the solver's
# residual, formed from its Float64 gradient Xᵀd with d = σ(X b) - y, below 1e-10 S. With u = eps/2, |dᵢ| ≤ 1 and
# M = maxᵢ Σⱼ |Xᵢⱼ||bⱼ|, a first-order estimate of the rounding of each entry of that gradient is
# n u max|Xᵢⱼ| (n + p M / 4 + 2), from the product Xᵀd, the image X b (σ has slope at most ¼) and d; it omits the
# rounding of the KKT scores and of S. `rounding_bound` is this estimate. Where KKT_TOL is used, the check also
# asserts that the estimate is at most 1e-9 and that S ≥ 1, so that 1e-8 S leaves room above 1e-10 S + 1e-9.
# The accuracy evidence is the independent residual itself.
const KKT_TOL = 1e-8
rounding_bound(X, b) = (n = size(X, 1); M = maximum(abs.(X) * abs.(b)); n * eps() / 2 * maximum(abs, X) * (n + size(X, 2) * M / 4 + 2))

# The independent residual of b for NormL1(λ, w) and its tolerance KKT_TOL S, with the rounding estimate and
# S ≥ 1 checked (see KKT_TOL)
function residual_check(X, y, b, λ, w = nothing)
  S = stop_scale(X, y, λ, w)
  @test rounding_bound(X, b) <= 1e-9 && S >= 1
  Float64(maximum(scores(oracle(X, y, b).gradient, b, λ, w))), KKT_TOL * S
end

@testset "the stopping scale is the norm of the logistic gradient at zero" begin
  X, y = logistic_data(120, 6; seed = 1)
  n, k = size(X)
  w = [0.0; ones(k - 1)]
  f, g = LogisticLoss(y, X), NormL1(2.0, w)
  method = ProximalGradientDescent()
  ref = Float64(norm(oracle(X, y, zeros(k)).gradient, Inf))
  state = PS.initial_state(method, TIGHT, f, g, zeros(k))
  @test PS._lambda_max!(state) ≈ ref rtol = 1e-13
  # the least-squares formula α‖Xᵀy‖∞ with α = 1/4 is a different number
  @test !isapprox(state.λmax, 0.25 * norm(X' * y, Inf); rtol = 1e-3)
  # a solve through the engine: its stopping scale is the same norm, and the stop it reports passes the check
  # ‖G‖∞ < τ S with S = max(λ maxⱼ wⱼ, λmax)
  state = PS.initial_state(method, TIGHT, f, g, zeros(k))
  r = PS._solve_gradient!(state, f, g, method, TIGHT)
  @test r.converged
  @test state.λmax ≈ ref rtol = 1e-13
  # wiring: ProximalBase's scorer on the solver's stored gradient, as in the solver's check
  @test kkt_violation(g, state.grad_f_x, state.x) < max(TIGHT.gradtol, 64eps()) * max(2.0, state.λmax)
  # and the independent residual of the same accepted point
  residual, tol = residual_check(X, y, state.x, 2.0, w)
  @test residual <= tol
end

@testset "loss value and gradient at zero and at a representative point" begin
  X, y = logistic_data(80, 5; seed = 2)
  n, k = size(X)
  f, g = LogisticLoss(y, X), NormL1(0.5)
  method = ProximalGradientDescent()
  for b in (zeros(k), [0.4, -1.2, 0.8, 0.0, 2.5, -0.3])
    ref = oracle(X, y, b)
    state = PS.initial_state(method, TIGHT, f, g, copy(b))
    # the value sums n terms of order |ηᵢ| (at most a few tens here), and each gradient entry n products of
    # order one, so the Float64 results are within a relative 1e-13 and an absolute 1e-13 n of the BigFloat ones
    @test state.f_x ≈ Float64(ref.value) rtol = 1e-13
    @test maximum(abs, state.grad_f_x .- ref.gradient) <= 1e-13 * n
    if iszero(b)
      @test Float64(ref.value) ≈ n * log(2) rtol = 1e-15
      @test ref.gradient == big.(X)' * (big(0.5) .- big.(y))
    end
    # central differences of the BigFloat loss with step 1e-20: the truncation error is of order 1e-40 n
    h = big(10)^-20
    for j in 1:k
      e = zeros(BigFloat, k)
      e[j] = h
      fd = (oracle(X, y, big.(b) .+ e).value - oracle(X, y, big.(b) .- e).value) / (2h)
      @test abs(fd - ref.gradient[j]) <= big(10)^-30
      @test abs(state.grad_f_x[j] - fd) <= 1e-13 * n
    end
  end
end

@testset "the curvature factor 1/4 bounds the logistic curvature along a step" begin
  X, y = logistic_data(50, 4; seed = 3)
  k = size(X, 2)
  rng = Xoshiro(30)
  # the inequalities behind the rejected-trial recheck (IN-09), in BigFloat at random points and steps
  for _ in 1:20
    b, d = 3 .* randn(rng, k), randn(rng, k)
    q = sum(abs2, big.(X) * big.(d))
    f0, f1 = oracle(X, y, b), oracle(X, y, big.(b) .+ big.(d))
    @test f1.value <= f0.value + dot(f0.gradient, big.(d)) + q / 8
    @test dot(f1.gradient - f0.gradient, big.(d)) <= q / 4
  end
  # the start of L is min(1, ¼‖X‖_F²) (PGD-02 with the factor ¼) from an upper bound on ‖X‖_F; here ¼‖X‖_F² < 1
  Xs = X ./ 64
  state = PS.initial_state(ProximalGradientDescent(), TIGHT, LogisticLoss(y, Xs), NormL1(0.1), zeros(k))
  @test state.model.α == 0.25
  # ¼‖X‖_F² with one rounding. The solver's bound is above it by its rounding allowances (PGD-02): the factor
  # 1/(1 - γ_{N+3}), with γ_{N+3} ≈ 3e-14 for N = 250, two factors within 1e-15 of one and the final rounding;
  # rtol = 1e-12 covers them.
  q = Float64(sum(abs2, big.(Xs)) / 4)
  @test q < 1
  @test state.L >= q
  @test state.L ≈ q rtol = 1e-12
end

@testset "regularized nonseparable fit with an unpenalized intercept" begin
  X, y = logistic_data(300, 20; seed = 4)
  n, k = size(X)
  @test 0 < sum(y) < n
  level = 0.15 * slope_threshold(X, y)
  w = [0.0; ones(k - 1)]
  b = zeros(k)
  r = solve!(b, LogisticLoss(y, X), NormL1(level, w), ProximalGradientDescent(), TIGHT)
  @test r.minimizer === b
  @test r.converged
  # more trials than iterations: some trials were rejected (the start L = 1 is far below ¼‖X‖₂² here)
  @test r.backtrack_steps > r.iterations
  s = scores(oracle(X, y, b).gradient, b, level, w)
  S = stop_scale(X, y, level, w)
  @test rounding_bound(X, b) <= 1e-9 && S >= 1      # the conditions of KKT_TOL
  active = findall(!iszero, b[2:end]) .+ 1
  inactive = findall(iszero, b[2:end]) .+ 1
  @test !isempty(active) && !isempty(inactive)
  @test s[1] <= KKT_TOL * S                          # intercept: |∂f/∂b₀|
  @test maximum(s[active]) <= KKT_TOL * S
  @test maximum(s[inactive]) <= KKT_TOL * S
  # the reported objective sums n Float64 terms; a relative 1e-12 covers their rounding
  @test r.minimum ≈ Float64(objective(X, y, b, level, w)) rtol = 1e-12
  # F/n is the mean negative log likelihood plus (level/n) ‖b₁:ₚ‖₁
  η = X * b
  @test r.minimum / n ≈ sum(softplus.((1 .- 2 .* y) .* η)) / n + (level / n) * sum(abs, b[2:end]) rtol = 1e-12
end

@testset "intercept-only model and a level above the slope threshold" begin
  X, y = logistic_data(150, 8; seed = 5)
  n, k = size(X)
  ybar = sum(y) / n
  # 0 < ȳ < 1 gives a finite intercept; ȳ ≠ 1/2 gives ∇f(0) ≠ 0 for the intercept column, so S > 0 below
  @test 0 < ybar < 1 && ybar != 0.5
  b0 = log(ybar / (1 - ybar))
  # The intercept column alone, unpenalized and with a zero weight under a positive level. A stop needs
  # |n(σ(b₀) - ȳ)| < 1e-10 S with S = n|½ - ȳ|; the slope of σ at logit(ȳ) is ȳ(1 - ȳ), so b₀ is within about
  # 1e-10 |½ - ȳ| / (ȳ(1 - ȳ)) of logit(ȳ), and 1e-8 leaves a margin.
  for g in (NormL1(0.0), NormL1(3.0, [0.0]))
    b = [0.0]
    r = solve!(b, LogisticLoss(y, X[:, 1:1]), g, ProximalGradientDescent(), TIGHT)
    @test r.converged
    @test b[1] ≈ b0 atol = 1e-8
  end
  # with slopes: at a level of at least ‖Zᵀ(ȳ - y)‖∞ the slopes are zero at the minimizer and the intercept is
  # logit(ȳ). From a start with nonzero slopes the run is expected to end with exact zeros: near the minimizer a
  # nonzero slope would score at least about level - level/1.05 > 0.04 level, far above the stop threshold.
  for factor in (1.05, 3.0)
    level = factor * slope_threshold(X, y)
    b = [0.0; fill(0.5, k - 1)]
    r = solve!(b, LogisticLoss(y, X), NormL1(level, [0.0; ones(k - 1)]), ProximalGradientDescent(), TIGHT)
    @test r.converged
    @test all(iszero, b[2:end])
    @test b[1] ≈ b0 atol = 1e-8
  end
  # At the mathematical threshold the zero slopes are optimal; the computed level can differ from it by rounding,
  # so the slopes are checked against a small tolerance, with the intercept and the independent residual
  level = slope_threshold(X, y)
  w = [0.0; ones(k - 1)]
  b = [0.0; fill(0.5, k - 1)]
  r = solve!(b, LogisticLoss(y, X), NormL1(level, w), ProximalGradientDescent(), TIGHT)
  @test r.converged
  @test maximum(abs, b[2:end]) <= 1e-8
  @test b[1] ≈ b0 atol = 1e-8
  residual, tol = residual_check(X, y, b, level, w)
  @test residual <= tol
end

@testset "unpenalized fit against a damped Newton reference" begin
  X, y = logistic_data(200, 4; seed = 6)
  n, k = size(X)
  bref, gnorm = newton(X, y)
  @test gnorm < 1e-30
  # numerical evidence that a finite minimizer exists: the witness at the Newton point indicates that the data are
  # not separable; that bref is close to the minimizer rests separately on its gradient norm above and on the
  # comparisons below
  @test nonseparable(X, y, bref) > 1
  b64 = Float64.(bref)
  Gref = oracle(X, y, b64).gradient
  for g in (NormL1(0.0), NormL1(0.0, zeros(k)))
    b = zeros(k)
    r = solve!(b, LogisticLoss(y, X), g, ProximalGradientDescent(), TIGHT)
    @test r.converged
    G = oracle(X, y, b).gradient
    # μ estimates a lower bound on the curvature on the segment from b to b64, under which, in exact arithmetic,
    # ‖b - b64‖₂ ≤ ‖∇f(b) - ∇f(b64)‖₂ / μ; this estimate is checked against the tolerance, and the distance itself
    # is checked directly
    μ = segment_curvature(X, b, b64)
    @test μ > 0 && Float64(norm(G - Gref)) / μ <= 1e-7 * max(1, norm(b64, Inf))
    @test norm(b - b64, Inf) <= 1e-7 * max(1, norm(b64, Inf))
    @test r.minimum ≈ Float64(oracle(X, y, bref).value) rtol = 1e-12
  end
end

@testset "unit penalty weights match the unweighted penalty" begin
  X, y = logistic_data(160, 10; seed = 7)
  n, k = size(X)
  level = 0.2 * norm(X' * (0.5 .- y), Inf)
  b1, b2 = zeros(k), zeros(k)
  r1 = solve!(b1, LogisticLoss(y, X), NormL1(level), ProximalGradientDescent(), TIGHT)
  r2 = solve!(b2, LogisticLoss(y, X), NormL1(level, ones(k)), ProximalGradientDescent(), TIGHT)
  @test r1.minimizer === b1 && r2.minimizer === b2
  @test r1.converged && r2.converged
  residuals = map(((r1, b1), (r2, b2))) do (r, b)
    residual, tol = residual_check(X, y, b, level)
    @test residual <= tol
    @test r.minimum ≈ Float64(objective(X, y, b, level)) rtol = 1e-12
    residual
  end
  # In exact arithmetic, with μ a lower bound on the curvature of the objective on the segment between the two
  # points and each residual the ∞-norm of a subgradient, ‖b1 - b2‖₂ ≤ √k (r₁ + r₂) / μ. With μ estimated by
  # segment_curvature, this estimate is checked against 1e-6, and the distance itself is checked directly.
  μ = segment_curvature(X, b1, b2)
  @test μ > 0 && sqrt(k) * sum(residuals) / μ <= 1e-6
  @test r1.minimum ≈ r2.minimum rtol = 1e-10
  @test norm(b1 - b2, Inf) <= 1e-6
end

@testset "rejected trials are rechecked and the fit stays accurate" begin
  X, y = logistic_data(200, 12; seed = 8)
  n, k = size(X)
  level = 0.1 * norm(X' * (0.5 .- y), Inf)
  f, g = LogisticLoss(y, X), NormL1(level)
  method = ProximalGradientDescent()
  state = PS.initial_state(method, TIGHT, f, g, zeros(k))
  r = PS._solve_gradient!(state, f, g, method, TIGHT)
  @test r.converged
  @test r.backtrack_steps > r.iterations    # some trials were rejected
  @test state.verifications > 0             # and rechecked by c = m ¼‖X d̂‖²/‖d̂‖²
  residual, tol = residual_check(X, y, state.x, level)
  @test residual <= tol
end

@testset "the recheck of a rejected trial uses the factor 1/4 in each mode" begin
  # One observation, X = [1], y = [1]: the step d = 1 from u = 0 has ¼‖X d‖²/‖d‖² = ¼. TFOCS's estimates for it,
  # from the independent loss, are at most m ¼ (m = 1 in function-value mode, m = 2 in gradient mode); with L = 0.1
  # the trial is rejected, the recheck returns c = m ¼, and the retry is L = max(c, L/β) = c.
  X1, y1 = fill(1.0, 1, 1), [1.0]
  f, g = LogisticLoss(y1, X1), NormL1(0.0)
  method = ProximalGradientDescent()
  f0, f1 = oracle(X1, y1, [0.0]), oracle(X1, y1, [1.0])
  estimates = (2 * (f1.value - f0.value - f0.gradient[1]), 2 * (f1.gradient[1] - f0.gradient[1]))
  for (gradient_mode, c, estimate) in ((false, 0.25, estimates[1]), (true, 0.5, estimates[2]))
    @test 0.1 < estimate <= c
    state = PS.initial_state(method, ProximalOptions(), f, g, [0.0])
    state.x_previous .= state.x
    state.f_x_previous = state.f_x
    state.grad_f_x_previous .= state.grad_f_x
    state.x .= 1.0
    state.f_x = PS._value!(state.x, f, state.model, state.z_x)
    state.L = 0.1
    state.backtrack_simple = !gradient_mode
    @test !PS.LineSearches.backtrack!(state, method.ls, f, g)
    @test state.verifications == 1 && state.L == c
  end
end

@testset "an error in an iteration restores the last accepted point" begin
  X, y = logistic_data(60, 3; seed = 9)
  f, g = LogisticLoss(y, X), NormL1(1.0, [0.0, 1.0, 1.0, 1.0])
  method = ProximalGradientDescent()
  # Fault injection after an accepted step, as for least squares in test/minimal_core_characterization.jl:
  # L = 0 makes the next trial nonfinite, and its curvature estimate cannot increase.
  state = PS.initial_state(method, ProximalOptions(), f, g, zeros(4))
  PS.update_state!(f, g, state, method)
  accepted = copy(state.x)
  @test accepted != zeros(4)
  state.L = 0.0
  @test_throws r"curvature estimate cannot increase finitely" PS._solve_gradient!(state, f, g, method, ProximalOptions())
  @test state.x == accepted
  # Through solve!: the start has a finite loss and an infinite penalty (c₂|x₂| above floatmax). The curvature
  # estimate starts at min(1, ¼‖X‖_F²) = 1, the first accepted trial keeps x₂ near 1e200, its objective is not
  # finite, and solve! restores the start.
  x0 = [1.0, 1e200]
  x = copy(x0)
  fk, gk = LogisticLoss([1.0], [2.0 0.0]), NormL1(1.0, [1.0, 1e109])
  @test isfinite(fk(x0)) && !isfinite(gk(x0))
  @test_throws ErrorException solve!(x, fk, gk, method)
  @test isequal(x, x0)
end

@testset "an overflowed image is a nonfinite start or trial" begin
  method = ProximalGradientDescent()
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
  # In a trial: from zero with X = 2e154 in every row, the first trial is x = ±1e154/0.9 and its image overflows.
  # With Lexact = 0.9 the line search accepts a trial with a finite value at L = 0.9; the overflowed trial is
  # retried at L = 1.8 instead (LS-02), and the image of that retry, about ±1.1e308, is finite. For y = [1] and
  # y = [0] the overflow is on the side of each label, where ProximalBase returns the loss 0; for y = [1, 1, 0]
  # it is against the third label, where ProximalBase returns Inf.
  for (y1, sign) in (([1.0], 1), ([0.0], -1), ([1.0, 1.0, 0.0], 1))
    X1 = fill(2e154, length(y1), 1)
    f, g = LogisticLoss(y1, X1), NormL1(0.0)
    m = ProximalGradientDescent(ls = PS.LineSearches.BackTracking(Lexact = 0.9))
    state = PS.initial_state(m, ProximalOptions(), f, g, [0.0])
    PS.update_state!(f, g, state, m)
    @test all(isfinite, X1 * state.x) && isfinite(state.f_x)
    @test state.L == 1.8 && state.backtrack_steps == 2
    @test state.x ≈ [sign * 1e154 / 1.8] rtol = 1e-15
  end
  # a large finite image still gets ProximalBase's stable loss: |η| = 800 is beyond log(floatmax(Float64)) ≈ 709.78
  X2, y2, b2 = [1.0 0.0; 0.0 1.0], [0.0, 1.0], [800.0, 800.0]
  state = PS.initial_state(method, ProximalOptions(), LogisticLoss(y2, X2), NormL1(0.0), copy(b2))
  @test state.f_x ≈ Float64(oracle(X2, y2, b2).value) rtol = 1e-15
  @test state.f_x ≈ 800 rtol = 1e-15
  @test state.grad_f_x ≈ Float64.(oracle(X2, y2, b2).gradient) rtol = 1e-15
end

@testset "iteration and call limits report nonconvergence" begin
  X, y = logistic_data(200, 12; seed = 10)
  n, k = size(X)
  level = 0.05 * norm(X' * (0.5 .- y), Inf)
  f, g = LogisticLoss(y, X), NormL1(level)
  b = zeros(k)
  r = solve!(b, f, g, ProximalGradientDescent(), ProximalOptions(maxiter = 3, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-12))
  @test r.minimizer === b
  @test r.iterations == 3 && r.iteration_converged && !r.converged
  @test r.minimum ≈ Float64(objective(X, y, b, level)) rtol = 1e-12
  b = zeros(k)
  r = solve!(b, f, g, ProximalGradientDescent(),
             ProximalOptions(maxiter = 1000, f_calls_limit = 6, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-12))
  @test r.call_limit_reached && !r.converged && r.f_calls >= 6 && r.iterations < 1000
  @test r.minimum ≈ Float64(objective(X, y, b, level)) rtol = 1e-12
end

# A run on a hard problem: finite results, and either a converged run whose independent residual is small or a
# run that reports converged = false
function check_hard_case(label, X, y, level, w, start)
  b = copy(start)
  r = solve!(b, LogisticLoss(y, X), NormL1(level, w), ProximalGradientDescent(), TIGHT)
  @test all(isfinite, b) && isfinite(r.minimum)
  kkt, tol = residual_check(X, y, b, level, w)
  println("logistic PGD, $label: converged = $(r.converged), iterations = $(r.iterations), ",
          "KKT residual / S = $(kkt / (tol / KKT_TOL)), max |X b| = $(maximum(abs, X * b))")
  @test !isnan(r.g_residual) && !isnan(r.f_residual) && !isnan(r.x_residual)
  @test !r.converged || kkt <= tol
  @test r.minimum ≈ Float64(objective(X, y, b, level, w)) rtol = 1e-10
end

@testset "strong finite logits and almost separated regularized problems" begin
  # A steep model on covariates of scale 20, from zero and from a start where |X b| is in the thousands, beyond
  # log(floatmax(Float64)) ≈ 709.78, above which exp(|η|) overflows in Float64
  rng = Xoshiro(11)
  n = 80
  X = [ones(n) 20 .* randn(rng, n, 2)]
  y = Float64.(rand(rng, n) .< sigmoid.(X * [0.5, 3.0, -2.0]))
  @test 0 < sum(y) < n
  level = 0.02 * slope_threshold(X, y)
  start = [0.0, 40.0, -40.0]
  @test maximum(abs, X * start) > log(floatmax(Float64))
  for s in (zeros(3), start)
    check_hard_case("steep model from $s", X, y, level, [0.0, 1.0, 1.0], s)
  end
  # One covariate on an even grid with a penalized slope and an unpenalized intercept: classes separated by
  # the sign of the covariate, and the same with two labels near zero exchanged. On each sublevel set of the
  # objective the positive slope penalty bounds the slope; with the slope bounded and both classes present, the
  # loss grows without bound with |b₀|, so the sublevel sets are bounded and each problem has a finite minimizer.
  z = collect(range(-2.0, 2.0; length = 21))
  X = [ones(21) z]
  y = Float64.(z .> 0)
  check_hard_case("separated, regularized", X, y, 0.01 * slope_threshold(X, y), [0.0, 1.0], zeros(2))
  y[10], y[12] = 1.0, 0.0
  check_hard_case("almost separated, regularized", X, y, 0.01 * slope_threshold(X, y), [0.0, 1.0], zeros(2))
end

@testset "one class with an unpenalized intercept: no finite minimizer" begin
  # y = ones(8) with an intercept column of ones and weight zero: F(b₀) = 8 log(1 + e^{-b₀}) decreases toward 0 as
  # b₀ → +∞, its derivative -8σ(-b₀) is negative at every finite b₀, and no minimizer exists (IN-09). The computed
  # residual can still fall below the threshold, so neither outcome of `converged` is required. The results must
  # be finite; when convergence is reported, the solver's criterion is re-formed at the returned point as the
  # solver forms it (STOP-03, STOP-04), and the independent residual is compared with the same threshold.
  X1, y1 = ones(8, 1), ones(8)
  λ, w = 0.1, [0.0]
  f1 = LogisticLoss(y1, X1)
  options = ProximalOptions(maxiter = 1000, gradtol = 1e-10)
  τ = max(options.gradtol, 64eps())
  threshold = τ * max(λ * maximum(w), norm(X1' * (0.5 .- y1), Inf))
  # from zero, and from a start where σ(-b₀) underflows in Float64
  for start in ([0.0], [1000.0])
    b = copy(start)
    r = solve!(b, f1, NormL1(λ, w), ProximalGradientDescent(), options)
    @test r.minimizer === b
    @test all(isfinite, b) && isfinite(r.minimum)
    @test isfinite(r.x_residual) && isfinite(r.f_residual) && isfinite(r.g_residual)   # r.gap is the NaN sentinel
    G = oracle(X1, y1, b).gradient
    @test G[1] < 0                     # in BigFloat, nonzero where the Float64 derivative underflows
    println("logistic PGD, one class from $start: converged = $(r.converged), iterations = $(r.iterations), ",
            "b₀ = $(b[1]), independent residual = $(-G[1]), threshold = $threshold")
    if r.converged
      G64, d = zeros(1), zeros(8)
      ProximalBase.value_and_gradient_from_predictor!(G64, d, f1, X1 * b)
      residual = kkt_violation(NormL1(λ, w), G64, b)
      @test isfinite(residual) && threshold >= floatmin(Float64) && residual < threshold
      @test maximum(scores(G, b, λ, w)) < big(threshold)
    end
  end
end

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
  pgd = ProximalGradientDescent()
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
    # solvers other than PGD, for each coefficient storage
    (copy(start), f, g, AccProxGradDescent(), ArgumentError, "LogisticLoss is supported only by ProximalGradientDescent"),
    (copy(start), f, g, CDSolver(), ArgumentError, "CDSolver does not support it"),
    (SparseIterate(copy(start)), f, g, CDSolver(), ArgumentError, "CDSolver does not support it"),
    (BlockIterate(copy(start), groups), f, GroupNormL2(1.0, groups), CDSolver(momentum = false), ArgumentError,
     "CDSolver does not support it"),
    (zeros(k, 2), f, GroupNormL2(1.0, [collect(j:k:2k) for j in 1:k]), CDSolver(), ArgumentError,
     "CDSolver does not support it"),
    (copy(start), f, NormL1(1.0), ADMMSolver(), ArgumentError, "ADMMSolver does not support LogisticLoss; use LogisticADMM"),
    (copy(start), (1 / n) * f, NormL1(1.0), ADMMSolver(), ArgumentError, "ADMMSolver does not support LogisticLoss; use LogisticADMM"),
    (copy(start), (1 / n) * f, g, AccProxGradDescent(), ArgumentError, "supported only by ProximalGradientDescent"),
    (copy(start), (1 / n) * f, g, CDSolver(), ArgumentError, "CDSolver does not support it"),
    # matrix coefficients: PGD's matrix method takes only a LogDetLoss, so the logistic gate refuses them
    ([1.0 0.1; 0.1 1.0], f, NormL1(1.0), pgd, ArgumentError, "x to be a dense Vector{Float64}"),
    ([1.0 0.1; 0.1 1.0], (1 / n) * f, NormL1(1.0), pgd, ArgumentError, "Scaled(LogisticLoss) is not supported"),
    # the loss and the arrays
    (copy(start), (1 / n) * f, g, pgd, ArgumentError, "Scaled(LogisticLoss) is not supported"),
    (Float32.(start), LogisticLoss(Float32.(y), Float32.(X)), NormL1(1f0, Float32.(w)), pgd, ArgumentError,
     "X::Matrix{Float64} and y::Vector{Float64}"),
    (copy(start), LogisticLoss(y, sparse(X)), g, pgd, ArgumentError, "X::Matrix{Float64}"),
    (copy(start), LogisticLoss(y, view(X, :, 1:k)), g, pgd, ArgumentError, "X::Matrix{Float64}"),
    (copy(start), LogisticLoss(view(y, 1:n), X), g, pgd, ArgumentError, "y::Vector{Float64}"),
    (Float32.(start), f, NormL1(1f0, Float32.(w)), pgd, ArgumentError, "x to be a dense Vector{Float64}"),
    (view(copy(start), 1:k), f, g, pgd, ArgumentError, "x to be a dense Vector{Float64}"),
    (SparseIterate(copy(start)), f, g, pgd, ArgumentError, "x to be a dense Vector{Float64}"),
    (copy(start), LogisticLoss(y, X; weights = ones(n)), g, pgd, ArgumentError, "observation weights or an offset"),
    (copy(start), LogisticLoss(y, X; offset = zeros(n)), g, pgd, ArgumentError, "observation weights or an offset"),
    # shapes
    (zeros(k + 1), f, NormL1(1.0), pgd, DimensionMismatch, "x/y dimensions do not match X"),
    (zeros(k - 1), f, NormL1(1.0), pgd, DimensionMismatch, "x/y dimensions do not match X"),
    (zeros(k), LogisticLoss(zeros(0), zeros(0, k)), NormL1(1.0), pgd, DimensionMismatch, "positive row and column counts"),
    (zeros(0), LogisticLoss(y, zeros(n, 0)), NormL1(1.0), pgd, DimensionMismatch, "positive row and column counts"),
    (copy(start), mutated((Xc, yc) -> resize!(yc, n - 1)), g, pgd, DimensionMismatch, "x/y dimensions do not match X"),
    # penalties other than NormL1, then the NormL1 rules
    (copy(start), f, ElasticNet(1.0, 1.0), pgd, ArgumentError, "only NormL1"),
    (copy(start), f, NormLinf(1.0), pgd, ArgumentError, "only NormL1"),
    (copy(start), f, GroupNormL2(1.0, groups), pgd, ArgumentError, "only NormL1"),
    (copy(start), f, NormL1Nonneg(1.0), pgd, ArgumentError, "only NormL1"),
    (abs.(start), f, IndNonnegative(), pgd, ArgumentError, "only NormL1"),
    (copy(start), f, IndBox(-1.0, 1.0), pgd, ArgumentError, "only NormL1"),
    (copy(start), f, SqrNormL2(1.0), pgd, ArgumentError, "only NormL1"),
    (copy(start), f, 2 * g, pgd, ArgumentError, "only NormL1"),
    (copy(start), f, NormL1(1.0, [0.0, 1.0, 1.0]), pgd, DimensionMismatch, "3 weights"),
    (copy(start), f, NormL1(1.0, Float32.(w)), pgd, ArgumentError, "penalty weights must be a Vector{Float64}"),
    (copy(start), f, NormL1(1e300, [0.0, 1e10, 1.0, 1.0]), pgd, ArgumentError, "overflows"),
    (copy(start), f, reweighted(-1.0), pgd, ArgumentError, "penalty weight 2 must be finite and nonnegative"),
    (copy(start), f, reweighted(Inf), pgd, ArgumentError, "penalty weight 2 must be finite and nonnegative"),
    (copy(start), f, reweighted(NaN), pgd, ArgumentError, "penalty weight 2 must be finite and nonnegative"),
    # aliasing
    (wv, f, NormL1(1.0, wv), pgd, ArgumentError, "must not alias the penalty weights"),
    (vec(row), LogisticLoss([1.0], row), g, pgd, ArgumentError, "must not alias borrowed X or y"),
    (ysq, fsq, g, pgd, ArgumentError, "must not alias borrowed X or y"),
    (fsq.tmp, fsq, g, pgd, ArgumentError, "scratch of the loss"),
    # values
    ([0.1, NaN, 0.3, 0.0], f, g, pgd, ArgumentError, "finite"),
    ([0.1, Inf, 0.3, 0.0], f, g, pgd, ArgumentError, "finite"),
    (copy(start), mutated((Xc, yc) -> (Xc[2, 3] = Inf)), g, pgd, ArgumentError, "finite"),
    (copy(start), mutated((Xc, yc) -> (Xc[5, 2] = NaN)), g, pgd, ArgumentError, "finite"),
    (copy(start), mutated((Xc, yc) -> (yc[3] = 0.5)), g, pgd, ArgumentError, "binary response"),
    (copy(start), mutated((Xc, yc) -> (yc[3] = NaN)), g, pgd, ArgumentError, "binary response"),
    (copy(start), mutated((Xc, yc) -> (yc[3] = 2.0)), g, pgd, ArgumentError, "binary response"),
    (copy(start), LogisticLoss(fill(0.25, n), X), g, pgd, ArgumentError, "binary response"),
  ]
  for (i, (x, loss, penalty, method, E, message)) in enumerate(cases)
    err, unchanged = refusal(x, loss, penalty, method)
    text = err === nothing ? "" : sprint(showerror, err)
    @test (i, err isa E) == (i, true)
    @test (i, occursin(message, text)) == (i, true)
    @test (i, unchanged) == (i, true)
  end
  # the same inputs with a Float64 start and the binary data are accepted
  b = copy(start)
  @test solve!(b, f, g, pgd).minimizer === b
end

@testset "ADMMSolver refuses a logistic loss before any write to z or u" begin
  X, y = logistic_data(40, 3; seed = 12)
  n, k = size(X)
  Λ = [0.0 1.0; 1.0 0.0]
  storages = [(() -> [0.1, -0.2, 0.3, 0.0], () -> [0.01, 0.02, -0.03, 0.04], NormL1(1.0), "ADMMSolver does not support LogisticLoss; use LogisticADMM"),
              (() -> [1.0 0.1; 0.1 1.0], () -> [0.01 0.02; 0.02 0.03], NormL1(1.0, Λ),
               "ADMMSolver does not support LogisticLoss; use LogisticADMM")]
  for loss in (LogisticLoss(y, X), (1 / n) * LogisticLoss(y, X)), (makez, makeu, g, message) in storages
    z, u = makez(), makeu()
    zbefore, ubefore = copy(z), copy(u)
    err = try
      solve!(z, loss, g, ADMMSolver(); u = u)
      nothing
    catch e
      e
    end
    @test err isa ArgumentError && occursin(message, sprint(showerror, err))
    @test z == zbefore && u == ubefore
  end
end

@testset "CDSolver refuses a logistic loss before any write or draw from its RNG" begin
  X, y = logistic_data(40, 3; seed = 12)
  n, k = size(X)
  start = [0.1, -0.2, 0.3, 0.0]
  groups = [[1, 2], [3, 4]]
  rows = [collect(j:k:2k) for j in 1:k]                 # the rows of a k × 2 coefficient matrix
  storages = [(() -> copy(start), NormL1(1.0), nothing),
              (() -> SparseIterate(copy(start)), NormL1(1.0), nothing),
              (() -> BlockIterate(copy(start), groups), GroupNormL2(1.0, groups), false),
              (() -> BlockIterate(copy(start), groups), GroupNormL2(1.0, groups), true),   # before the momentum check
              (() -> zeros(k, 2), GroupNormL2(1.0, rows), nothing)]
  for loss in (LogisticLoss(y, X), (1 / n) * LogisticLoss(y, X)), (make, g, momentum) in storages
    x = make()
    rng = Xoshiro(5)
    rng_before = copy(rng)
    err, unchanged = refusal(x, loss, g, CDSolver(order = :random, momentum = momentum, rng = rng))
    @test err isa ArgumentError && occursin("CDSolver does not support it", sprint(showerror, err))
    @test unchanged && rng == rng_before
  end
end

# The bytes of a warmed solve, setup included, measured inside a function; the minimum of three runs after one
# warm-up run
function solve_bytes(f, g, x0, o)
  run() = (x = copy(x0); @allocated solve!(x, f, g, ProximalGradientDescent(), o))
  run()
  minimum(run() for _ in 1:3)
end

# The largest number of bytes of one of ten warmed iterations (update_state!), measured inside a function
function iteration_bytes(f, g, x0)
  method = ProximalGradientDescent()
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

end
