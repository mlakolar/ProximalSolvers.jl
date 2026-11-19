module LogisticPGDTest
# Sparse logistic regression with ProximalGradientDescent (IN-09): a raw LogisticLoss{Float64} on a dense
# Matrix{Float64} with a binary Vector{Float64} response, no observation weights or offset, and NormL1 with or
# without penalty weights on a Vector{Float64}. The references below are computed from the stored data in BigFloat
# with formulas of their own, not with ProximalBase's oracles.
using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

# Stable scalar formulas, for Float64 and BigFloat arguments
sigmoid(t) = t >= 0 ? inv(1 + exp(-t)) : (e = exp(t); e / (1 + e))
softplus(t) = t > 0 ? t + log1p(exp(-t)) : log1p(exp(t))

# The raw loss Σᵢ softplus(ηᵢ) - yᵢηᵢ, η = X b, and its gradient Xᵀ(σ(η) - y), in BigFloat from the stored data
function oracle(X, y, b)
  A, t = big.(X), big.(y)
  η = A * big.(b)
  (; value = sum(softplus.(η) .- t .* η), gradient = A' * (sigmoid.(η) .- t))
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
# ∞-norm of its gradient. It ends when that norm is below 1e-30.
function newton(X, y; iterations = 100)
  A, t = big.(X), big.(y)
  loss(v) = (η = A * v; sum(softplus.(η) .- t .* η))
  b = zeros(BigFloat, size(A, 2))
  G = A' * (sigmoid.(A * b) .- t)
  for _ in 1:iterations
    norm(G, Inf) < big(10)^-30 && break
    μ = sigmoid.(A * b)
    step = (A' * (A .* (μ .* (1 .- μ)))) \ G
    s, f0 = big(1), loss(b)
    while loss(b - s * step) > f0 - s * dot(G, step) / 4
      s /= 2
      s < big(10)^-20 && error("damped Newton made no progress")
    end
    b -= s * step
    G = A' * (sigmoid.(A * b) .- t)
  end
  b, norm(G, Inf)
end

# Seeded data: an intercept column of ones, then p standard normal covariates with correlation 1/2 between
# neighbours, multiplied by `scale`, and responses drawn from the logistic model with intercept -0.3 and the
# planted slopes `signal` on the first covariates.
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

# The independent residual bound used with TIGHT. A stop needs the solver's residual, formed from the Float64
# gradient Xᵀ(σ(X b) - y), below 1e-10 S. That gradient differs from the BigFloat one by rounding of order
# n max|Xᵢⱼ| ‖b‖ eps, below 1e-11 for the fixtures here, while S is at least of order one; 1e-8 S leaves a margin
# of a factor of 100 over the stopping threshold.
const KKT_TOL = 1e-8

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
  @test kkt_violation(g, state.grad_f_x, state.x) < max(TIGHT.gradtol, 64eps()) * max(2.0, state.λmax)
end

@testset "loss value and gradient at zero and at a representative point" begin
  X, y = logistic_data(80, 5; seed = 2)
  n, k = size(X)
  f, g = LogisticLoss(y, X), NormL1(0.5)
  method = ProximalGradientDescent()
  for b in (zeros(k), [0.4, -1.2, 0.8, 0.0, 2.5, -0.3])
    ref = oracle(X, y, b)
    state = PS.initial_state(method, TIGHT, f, g, copy(b))
    # the value sums n terms of order |ηᵢ| ≤ 10 here, and each gradient entry n products of order one, so the
    # Float64 results are within a relative 1e-13 and an absolute 1e-13 n of the BigFloat ones
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
  # ¼‖X‖_F² with one rounding; the solver's upper bound exceeds it by its error allowance γ_{N+3} ≈ 3e-14 (N = 250)
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
  # the first trial (L = 0.9) is rejected: the curvature along it is far above 1 for this design
  @test r.backtrack_steps > r.iterations
  s = scores(oracle(X, y, b).gradient, b, level, w)
  S = stop_scale(X, y, level, w)
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
  @test r.minimum / n ≈ sum(softplus.(η) .- y .* η) / n + (level / n) * sum(abs, b[2:end]) rtol = 1e-12
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
  # logit(ȳ); from a start with nonzero slopes, a converged run has exact zeros (a nonzero slope would score at
  # least level - |∂f/∂bⱼ| ≥ 0.05 level)
  for factor in (1.05, 3.0)
    level = factor * slope_threshold(X, y)
    b = [0.0; fill(0.5, k - 1)]
    r = solve!(b, LogisticLoss(y, X), NormL1(level, [0.0; ones(k - 1)]), ProximalGradientDescent(), TIGHT)
    @test r.converged
    @test all(iszero, b[2:end])
    @test b[1] ≈ b0 atol = 1e-8
  end
end

@testset "unpenalized fit against a damped Newton reference" begin
  X, y = logistic_data(200, 4; seed = 6)
  n, k = size(X)
  bref, gnorm = newton(X, y)
  @test gnorm < 1e-30            # a finite minimizer exists: the data are not separable
  b64 = Float64.(bref)
  μ = sigmoid.(X * b64)
  λmin = eigmin(Symmetric(X' * (X .* (μ .* (1 .- μ)))))
  @test λmin > 0
  for g in (NormL1(0.0), NormL1(0.0, zeros(k)))
    b = zeros(k)
    r = solve!(b, LogisticLoss(y, X), g, ProximalGradientDescent(), TIGHT)
    @test r.converged
    G = Float64.(oracle(X, y, b).gradient)
    # strong convexity near the minimizer: ‖b - b*‖₂ ≤ ‖∇f(b)‖₂ / λmin(∇²f), with a factor 2 for the change of
    # the Hessian along the segment and 1e-12 for the rounding of b* to Float64
    @test norm(b - b64) <= 2 * norm(G) / λmin + 1e-12
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
  S = stop_scale(X, y, level)
  for (r, b) in ((r1, b1), (r2, b2))
    @test maximum(scores(oracle(X, y, b).gradient, b, level)) <= KKT_TOL * S
    @test r.minimum ≈ Float64(objective(X, y, b, level)) rtol = 1e-12
  end
  # n > k and X has full column rank, so the loss is strictly convex and the minimizer is unique; both points
  # have independent residuals below 1e-8 S, which bounds their distance far below 1e-6 for this design
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
  @test maximum(scores(oracle(X, y, state.x).gradient, state.x, level)) <= KKT_TOL * stop_scale(X, y, level)
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
  kkt = Float64(maximum(scores(oracle(X, y, b).gradient, b, level, w)))
  S = stop_scale(X, y, level, w)
  println("logistic PGD, $label: converged = $(r.converged), iterations = $(r.iterations), ",
          "KKT residual / S = $(kkt / S), max |X b| = $(maximum(abs, X * b))")
  @test all(isfinite, b) && isfinite(r.minimum)
  @test !isnan(r.g_residual) && !isnan(r.f_residual) && !isnan(r.x_residual)
  @test !r.converged || kkt <= KKT_TOL * S
  @test r.minimum ≈ Float64(objective(X, y, b, level, w)) rtol = 1e-10
end

@testset "strong finite logits and almost separated regularized problems" begin
  # A steep model on covariates of scale 20, from zero and from a start where |X b| is in the thousands, beyond
  # the range where exp(|η|) is finite in Float64 (|η| ≤ 709)
  rng = Xoshiro(11)
  n = 80
  X = [ones(n) 20 .* randn(rng, n, 2)]
  y = Float64.(rand(rng, n) .< sigmoid.(X * [0.5, 3.0, -2.0]))
  @test 0 < sum(y) < n
  level = 0.02 * slope_threshold(X, y)
  start = [0.0, 40.0, -40.0]
  @test maximum(abs, X * start) > 709
  for s in (zeros(3), start)
    check_hard_case("steep model from $s", X, y, level, [0.0, 1.0, 1.0], s)
  end
  # One covariate on an even grid with a penalized slope and an unpenalized intercept: classes separated by
  # the sign of the covariate, and the same with two labels near zero exchanged. Both classes are present, so the
  # intercept is bounded, and the penalty bounds the slope: each problem has a finite minimizer.
  z = collect(range(-2.0, 2.0; length = 21))
  X = [ones(21) z]
  y = Float64.(z .> 0)
  check_hard_case("separated, regularized", X, y, 0.01 * slope_threshold(X, y), [0.0, 1.0], zeros(2))
  y[10], y[12] = 1.0, 0.0
  check_hard_case("almost separated, regularized", X, y, 0.01 * slope_threshold(X, y), [0.0, 1.0], zeros(2))
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
  cases = [
    # solvers other than PGD, for each coefficient storage
    (copy(start), f, g, AccProxGradDescent(), ArgumentError, "LogisticLoss is supported only by ProximalGradientDescent"),
    (copy(start), f, g, CDSolver(), ArgumentError, "CDSolver does not support it"),
    (SparseIterate(copy(start)), f, g, CDSolver(), ArgumentError, "CDSolver does not support it"),
    (BlockIterate(copy(start), groups), f, GroupNormL2(1.0, groups), CDSolver(momentum = false), ArgumentError,
     "CDSolver does not support it"),
    (zeros(k, 2), f, GroupNormL2(1.0, [collect(j:k:2k) for j in 1:k]), CDSolver(), ArgumentError,
     "CDSolver does not support it"),
    (copy(start), f, NormL1(1.0), ADMMSolver(), ArgumentError, "ADMM requires SqrNormL2"),
    (copy(start), (1 / n) * f, g, AccProxGradDescent(), ArgumentError, "supported only by ProximalGradientDescent"),
    (copy(start), (1 / n) * f, g, CDSolver(), ArgumentError, "CDSolver does not support it"),
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

# The bytes of a warmed solve, measured inside a function; the minimum of three runs after one warm-up run
function solve_bytes(f, g, x0, o)
  run() = (x = copy(x0); @allocated solve!(x, f, g, ProximalGradientDescent(), o))
  run()
  minimum(run() for _ in 1:3)
end

@testset "a warmed logistic solve allocates no more than the least-squares control" begin
  X, y = logistic_data(100, 8; seed = 13)
  k = size(X, 2)
  g = NormL1(1.0, [0.0; ones(k - 1)])
  # without stopping proposals, and with a proposal (and so a stationarity check) at every iteration
  for o in (ProximalOptions(maxiter = 30, ftol = 0, xtol = 1e-300, gradtol = 0, allow_f_increases = true),
            ProximalOptions(maxiter = 30, ftol = 0, xtol = 1e10, gradtol = 0, allow_f_increases = true))
    logistic = solve_bytes(LogisticLoss(y, X), g, zeros(k), o)
    control = solve_bytes(LeastSquaresLoss(y, X), g, zeros(k), o)
    println("allocations, xtol = $(o.xtol): logistic $logistic bytes, least squares $control bytes")
    @test logistic <= control
  end
end

end
