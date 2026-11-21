module LogisticADMMTest
# Sparse logistic regression with LogisticADMM (LA-01 to LA-05): a raw LogisticLoss{Float64} on a dense
# Matrix{Float64} with a binary response and NormL1, with or without penalty weights, on a Vector{Float64}. The
# references are computed from the stored data in BigFloat with formulas of their own, not with ProximalBase's oracles;
# the solver's own scores are compared with them. The helpers are private to this file.
using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

# Stable scalar formulas, for Float64 and BigFloat arguments
sigmoid(t) = t >= 0 ? inv(1 + exp(-t)) : (e = exp(t); e / (1 + e))
softplus(t) = t > 0 ? t + log1p(exp(-t)) : log1p(exp(t))

# The raw loss and its gradient at b in BigFloat from the stored data, for a binary y. With η = X b and sᵢ = 1 - 2yᵢ the
# term of observation i is softplus(sᵢηᵢ) = log(1 + e^{ηᵢ}) - yᵢηᵢ and its derivative is sᵢ σ(sᵢηᵢ).
function oracle(X, y, b)
  A, s = big.(X), big.(1 .- 2 .* y)
  η = A * big.(b)
  (; value = sum(softplus.(s .* η)), gradient = A' * (s .* sigmoid.(s .* η)))
end

# cⱼ = λ wⱼ in BigFloat (cⱼ = λ without weights)
coefficient(λ, w, j) = big(λ) * (w === nothing ? 1 : big(w[j]))

# The KKT scores of b for NormL1(λ, w) at the gradient G: max(|Gⱼ| - cⱼ, 0) where bⱼ = 0 and |Gⱼ + cⱼ sign(bⱼ)|
# elsewhere. A zero weight scores |Gⱼ|.
scores(G, b, λ, w = nothing) =
  [iszero(b[j]) ? max(abs(G[j]) - coefficient(λ, w, j), 0) : abs(G[j] + coefficient(λ, w, j) * sign(b[j]))
   for j in eachindex(b)]

# The objective and the largest score of b, independently, as Float64
function independent(X, y, b, λ, w = nothing)
  ref = oracle(X, y, b)
  (; objective = Float64(ref.value + sum(coefficient(λ, w, j) * abs(big(b[j])) for j in eachindex(b))),
     score = Float64(maximum(scores(ref.gradient, b, λ, w))))
end

# The minimizer of the unpenalized raw loss by damped Newton in BigFloat, with the ∞-norm of its gradient
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

# Seeded data: an intercept column of ones, then p covariates with population correlation `corr` between neighbours,
# and responses drawn from the logistic model with intercept -0.3 and the planted slopes `signal`.
function logistic_data(n, p; seed, signal = [1.0, -0.8, 0.6], corr = 0.5)
  rng = Xoshiro(seed)
  Z = randn(rng, n, p)
  for j in 2:p
    Z[:, j] .= corr .* Z[:, j - 1] .+ sqrt(1 - corr^2) .* Z[:, j]
  end
  β = zeros(p)
  m = min(length(signal), p)
  β[1:m] .= signal[1:m]
  y = Float64.(rand(rng, n) .< sigmoid.(-0.3 .+ Z * β))
  [ones(n) Z], y
end

# The level above which the slopes vanish when the intercept (column 1) is unpenalized
slope_threshold(X, y) = norm(X[:, 2:end]' * (sum(y) / length(y) .- y), Inf)

# A first-order estimate of the rounding of the entries of the Float64 gradient at b: n u max|X| (n + p M / 4 + 2),
# with u = eps/2 and M = maxᵢ Σⱼ |Xᵢⱼ||bⱼ|, from the product Xᵀd, the image X b and d
rounding_bound(X, b) =
  (n = size(X, 1); M = maximum(abs.(X) * abs.(b)); n * eps() / 2 * maximum(abs, X) * (n + size(X, 2) * M / 4 + 2))

# A regularized problem with an unpenalized intercept: the data, the level, the weights
function problem(n, p; seed, level = 0.2, corr = 0.5)
  X, y = logistic_data(n, p; seed, corr)
  X, y, level * slope_threshold(X, y), [0.0; ones(size(X, 2) - 1)]
end

# The ProxNewton reference at tol = 1e-10, from zero
function reference(X, y, λ, w)
  b = zeros(size(X, 2))
  r = solve!(b, LogisticLoss(y, X), NormL1(λ, w), ProxNewton(tol = 1e-10, maxiter = 500))
  @assert r.converged
  b, r.minimum
end

# The checks of a result against the independent objective and scores; returns them. A converged result also
# passes its residual tests, and its dual and predictor diagnostics are within the bounds of LA-04.
function check_result(r, x, X, y, λ, w = nothing; converged = true)
  ind = independent(X, y, x, λ, w)
  slack = 10 * rounding_bound(X, x) + 1e-12
  n = size(X, 1)
  @test r isa LogisticADMMResults
  @test r.minimizer === x
  @test r.minimum ≈ ind.objective rtol = 1e-12
  @test abs(r.kkt - ind.score) <= slack
  @test length(r.t) == n && length(r.u) == n && all(isfinite, r.t) && all(isfinite, r.u)
  if converged
    @test r.converged && r.stop_reason === :converged
    @test r.kkt <= r.tolerance
    @test ind.score <= r.tolerance + slack
    @test r.r_norm <= r.eps_pri && r.s_norm <= r.eps_dual
    # criterion 3: |σ(t) - y - ρu| within a few eps of the scale of the terms of the scalar residual, with v = t + u
    @test r.predictor_residual <= 16 * eps() * (1 + r.ρ * (norm(r.t, Inf) + norm(r.u, Inf)))
    # the score is 1-Lipschitz in the gradient (∞-norm), and |Xᵀ(ρu - d)|∞ ≤ maxⱼ‖Xⱼ‖ ‖ρu - d‖ with d = σ(X b) - y,
    # ‖ρu - d‖ ≤ √n predictor_residual + r_norm / 4
    gap = maximum(norm, eachcol(X)) * (sqrt(n) * r.predictor_residual + r.r_norm / 4)
    @test r.dual_kkt <= r.kkt + gap + slack
  end
  ind
end

@testset "constructor, defaults and refusals" begin
  m = LogisticADMM()
  @test m.ρ == 0.25 && m.maxiter == 10_000 && m.tol == 1e-7
  @test m.abstol == 1e-8 && m.reltol == 1e-6 && m.abstol_dual == 1e-8
  @test m.inner isa CDSolver && !m.inner.random && m.inner.momentum === false && !m.inner.relative
  @test m.inner.tol == 1e-8 && m.inner.maxpasses == 1000
  @test summary(m) == "Logistic ADMM"
  @test LogisticADMM(abstol = 1e-5).abstol_dual == 1e-5
  @test LogisticADMM(abstol = 1e-5, abstol_dual = 1e-3).abstol_dual == 1e-3
  custom = LogisticADMM(ρ = 2, maxiter = 5, tol = 1e-3, reltol = 0, inner = CDSolver(order = :cyclic, maxpasses = 7))
  @test custom.ρ === 2.0 && custom.maxiter == 5 && custom.tol == 1e-3 && custom.reltol === 0.0
  @test custom.inner.maxpasses == 7
  # the documented range of ρ, after conversion to Float64
  @test LogisticADMM(ρ = 1e-10).ρ == 1e-10 && LogisticADMM(ρ = 1e10).ρ == 1e10
  @test LogisticADMM(ρ = 1 // 4).ρ === 0.25 && LogisticADMM(ρ = big"0.5").ρ === 0.5
  for ρ in (1e-11, 1e11, 0, 0.0, -1.0, NaN, Inf, -Inf, big"1e-400", prevfloat(1e-10), nextfloat(1e10))
    @test_throws ArgumentError LogisticADMM(ρ = ρ)
  end
  # budgets and the inner solver
  @test LogisticADMM(maxiter = 0).maxiter === 0 && LogisticADMM(maxiter = big(3)).maxiter === 3
  @test_throws ArgumentError LogisticADMM(maxiter = -1)
  @test_throws ArgumentError LogisticADMM(inner = CDSolver())                     # the default order is random
  @test_throws ArgumentError LogisticADMM(inner = CDSolver(order = :random, momentum = false))
  @test_throws ArgumentError LogisticADMM(inner = CDSolver(order = :cyclic, maxpasses = 0))
  @test LogisticADMM(inner = CDSolver(order = :cyclic, maxpasses = 1)).inner.maxpasses == 1
  # tolerances: finite, nonnegative and not a positive value that rounds to zero
  for name in (:tol, :abstol, :reltol, :abstol_dual)
    @test getfield(LogisticADMM(; name => 0), name) === 0.0
    for v in (-1e-3, NaN, Inf, -Inf, big"1e-400")
      @test_throws ArgumentError LogisticADMM(; name => v)
    end
  end
  # the positional constructor is the validated one
  inner = CDSolver(order = :cyclic)
  @test LogisticADMM(0.5, 10, 1e-7, 1e-8, 1e-6, 1e-8, inner) isa LogisticADMM
  @test_throws ArgumentError LogisticADMM(0.0, 10, 1e-7, 1e-8, 1e-6, 1e-8, inner)
  @test_throws ArgumentError LogisticADMM(0.5, -1, 1e-7, 1e-8, 1e-6, 1e-8, inner)
  @test_throws ArgumentError LogisticADMM(0.5, 10, 1e-7, 1e-8, 1e-6, 1e-8, CDSolver(order = :random))
end

# ---- the scalar logistic proximal root (LA-03) --------------------------------------------------------------------
# σ(s) - y and the scalar residual in BigFloat, for a binary y (`one` is y == 1)
bigresidual(s::BigFloat, one::Bool) = one ? -1 / (1 + exp(s)) : 1 / (1 + exp(-s))
# The v for which s is an exact root of σ(s) - y + ρ(s - v), compared with the given v, in units of
# eps(Float64) max(|v|, |s|): the backward error of LA-03
function backward(s, v, one, ρ)
  S = big(s)
  vexact = S + bigresidual(S, one) / big(ρ)
  Float64(abs(vexact - big(v)) / (eps(Float64) * max(abs(big(v)), abs(S), big(floatmin(Float64)))))
end
# The root by 2000 bisections of the bracket in 256-bit BigFloat
function bigroot(v, one, ρ)
  setprecision(BigFloat, 256) do
    V, R = big(v), big(ρ)
    lo, hi = one ? (V, V + 1 / R) : (V - 1 / R, V)
    for _ in 1:2000
      m = (lo + hi) / 2
      bigresidual(m, one) + R * (m - V) < 0 ? (lo = m) : (hi = m)
    end
    (lo + hi) / 2
  end
end
# The bound of LA-03 on the backward error, in units of eps(Float64) max(|v|, |t|)
const BACKWARD = 32

@testset "the stable residual σ(t) - y and the curvature" begin
  setprecision(BigFloat, 256) do
    for s in (-800.0, -745.0, -720.0, -50.0, -1.0, -1e-20, 0.0, 1e-20, 0.5, 3.0, 40.0, 720.0, 800.0), one in (false, true)
      r = PS._la_residual(s, one)
      ref = bigresidual(big(s), one)
      # relative error a few eps, or an absolute error below the smallest subnormal where ref is below floatmin
      @test abs(r - ref) <= 4 * eps() * abs(ref) + nextfloat(0.0)
      c = PS._la_curvature(s)
      cref = exp(-abs(big(s))) / (1 + exp(-abs(big(s))))^2
      @test abs(c - cref) <= 4 * eps() * cref + nextfloat(0.0)
    end
  end
  # at t = -720 the residual of y = 0 is subnormal, about 2.0e-313, not zero; 1/(1 + e^{-t}) would round to 0
  r = PS._la_residual(-720.0, false)
  @test issubnormal(r) && 2.0e-313 < r < 2.1e-313
  @test 1 / (1 + exp(720.0)) == 0.0
  @test PS._la_residual(-720.0, true) == -1.0 && PS._la_residual(720.0, true) < 0 && issubnormal(-PS._la_residual(720.0, true))
end

@testset "scalar root: brackets, worked examples and regressions" begin
  # y = 0, v = 0, ρ = 1: t + σ(t) = 0, with the root about -0.40106 in (v - 1/ρ, v) = (-1, 0); y = 1 mirrors it
  t0, k0, ok0 = PS._la_root(0.0, false, 1.0)
  t1, k1, ok1 = PS._la_root(0.0, true, 1.0)
  @test ok0 && ok1 && -1 < t0 < 0 && 0 < t1 < 1
  @test abs(t0 + 0.40106) < 1e-5 && abs(t1 - 0.40106) < 1e-5 && abs(t0 + t1) <= 2 * eps(t1)
  @test backward(t0, 0.0, false, 1.0) <= BACKWARD && backward(t1, 0.0, true, 1.0) <= BACKWARD
  @test k0 > 0 && k1 > 0
  # the midpoint false-root regression: y = 1, v = 40, ρ = 1. The bracket starts at lo = 40 and the Newton point
  # rounds to 40; the root is 40 + 4.2e-18, so the answer is 40, not the midpoint 40.5
  t, k, ok = PS._la_root(40.0, true, 1.0)
  @test ok && t == 40.0
  @test 4.1e-18 < Float64(bigroot(40.0, true, 1.0) - 40) < 4.3e-18
  # the plateau: y = 0, v = 500, ρ = 0.001. The root is about 4.15e-17, and the computed h is exactly 0 at 0, 1e-17
  # and 1e-16, so the test is the backward error, not the distance in ulps
  t, k, ok = PS._la_root(500.0, false, 0.001)
  @test ok && abs(t) < 1e-15
  @test 4.1e-17 < Float64(bigroot(500.0, false, 0.001)) < 4.2e-17
  for s in (0.0, 1e-17, 1e-16)
    @test first(PS._la_scalar(s, 500.0, false, 0.001)) == 0.0
  end
  @test backward(t, 500.0, false, 0.001) <= BACKWARD
  # a subnormal residual: y = 0, v = -720, ρ = 1e-10 and its mirror keep v, the root to the precision of Float64
  for (v, one) in ((-720.0, false), (720.0, true))
    t, k, ok = PS._la_root(v, one, 1e-10)
    @test ok && t == v && backward(t, v, one, 1e-10) <= BACKWARD
  end
  # the side of v: below it for y = 0, above it for y = 1, within 1/ρ
  for v in (-3.0, 0.5, 7.0), ρ in (0.1, 2.0)
    s0, _, _ = PS._la_root(v, false, ρ)
    s1, _, _ = PS._la_root(v, true, ρ)
    @test v - 1 / ρ <= s0 <= v && v <= s1 <= v + 1 / ρ
  end
  # failures: a nonfinite argument and a reduced step cap
  @test PS._la_root(NaN, false, 1.0)[3] == false
  @test PS._la_root(Inf, true, 1.0)[3] == false && PS._la_root(-Inf, false, 1.0)[3] == false
  s, k, ok = PS._la_root(0.0, false, 1.0, 1)
  @test !ok && k == 1 && isfinite(s)
  s, k, ok = PS._la_root(0.0, false, 1.0, 0)
  @test !ok && k == 0
  @test PS._LA_ROOT_CAP == 3 * (34 + 1074 + 2)
end

@testset "scalar root sweep against a 256-bit BigFloat bisection" begin
  worst, maxsteps = 0.0, 0
  for v in (-1e300, 1e300, -800.0, 800.0, -720.0, -50.0, -1.0, 0.0, 1e-3, 3.0, 40.0, 500.0), one in (false, true),
      ρ in (1e-10, 1e-3, 0.25, 1.0, 1e3, 1e10)
    t, k, ok = PS._la_root(v, one, ρ)
    @test (v, one, ρ, ok) == (v, one, ρ, true)
    # in the closed bracket, and the backward error within the bound of LA-03
    lo, hi = one ? (v, v + 1 / ρ) : (v - 1 / ρ, v)
    @test lo <= t <= hi
    b = backward(t, v, one, ρ)
    @test (v, one, ρ, b <= BACKWARD) == (v, one, ρ, true)
    # the bound on v moves the root by at most BACKWARD eps max(|v|, |t|) (dt/dv = ρ/(σ(1 - σ) + ρ) ≤ 1)
    ref = bigroot(v, one, ρ)
    @test abs(big(t) - ref) <= BACKWARD * eps() * max(abs(v), abs(t)) + nextfloat(0.0)
    worst, maxsteps = max(worst, b), max(maxsteps, k)
  end
  @test maxsteps < PS._LA_ROOT_CAP
  @info "scalar root sweep" worst_backward = worst max_steps = maxsteps
end

# ---- the private steps -----------------------------------------------------------------------------------------
@testset "the workspace at the start: the default predictor and dual, and the checked start" begin
  X, y, λ, w = problem(30, 4; seed = 21)
  n, k = size(X)
  f, g = LogisticLoss(y, X), NormL1(λ, w)
  b0 = [0.2; 0.1; zeros(k - 2)]
  m = LogisticADMM()
  ws = PS._la_workspace(copy(b0), f, g, m, nothing, nothing)
  @test ws.eta == X * b0 && ws.t == ws.eta
  @test ws.w == [PS._la_residual(ws.t[i], y[i] == 1) for i in 1:n]           # u = (σ(t) - y)/ρ, held as w = ρu
  ind = independent(X, y, b0, λ, w)
  @test ws.F ≈ ind.objective rtol = 1e-12
  @test abs(ws.kkt - ind.score) <= 1e-10
  @test ws.resp ≈ ws.t .- ws.w ./ m.ρ
  # a supplied t and u
  t0, u0 = randn(Xoshiro(2), n), randn(Xoshiro(3), n)
  ws = PS._la_workspace(copy(b0), f, g, m, t0, u0)
  @test ws.t == t0 && ws.t !== t0 && ws.w == m.ρ .* u0
end

@testset "the β step meets its forcing target with a score independent of the CD residual" begin
  X, y, λ, w = problem(60, 6; seed = 22)
  n, k = size(X)
  f, g = LogisticLoss(y, X), NormL1(λ, w)
  m = LogisticADMM(ρ = 0.5)
  ws = PS._la_workspace(zeros(k), f, g, m, nothing, nothing)
  score, met = PS._la_beta_step!(ws, m)
  @test ws.passes > 0
  @test ws.model.r ≈ ws.resp .- X * ws.b_new atol = 1e-10            # CD keeps its residual at the response
  @test ws.eta_new == X * ws.b_new
  # the score is the KKT score of the least-squares subproblem ρ/2 ‖X b - resp‖² + g(b), here against BigFloat
  q = big(m.ρ) .* (big.(X)' * (big.(X) * big.(ws.b_new) .- big.(ws.resp)))
  ref = Float64(maximum(scores(q, ws.b_new, λ, w)))
  @test abs(score - ref) <= 1e-10
  @test met == (score <= max(0.1 * m.tol, 0.1 * ws.kkt)) && met
  # at a minimizer the target is tight; with a dual far from its fixed point the subproblem's minimizer is far away,
  # and a single pass of budget misses the target: the score is reported, and the target is not met
  bpn, _ = reference(X, y, λ, w)
  one = LogisticADMM(ρ = 0.5, tol = 1e-12, inner = CDSolver(order = :cyclic, momentum = false, relative = false, maxpasses = 1, tol = 0.0))
  ws = PS._la_workspace(copy(bpn), f, g, one, X * bpn, 10 .* randn(Xoshiro(4), n))
  score, met = PS._la_beta_step!(ws, one)
  @test ws.passes == 1 && !met && isfinite(score) && score > max(0.1 * one.tol, 0.1 * ws.kkt)
end

@testset "the t and u steps: one scalar root per observation, and u from the same v" begin
  X, y, λ, w = problem(40, 3; seed = 23)
  n, k = size(X)
  f, g = LogisticLoss(y, X), NormL1(λ, w)
  m = LogisticADMM()
  ws = PS._la_workspace(zeros(k), f, g, m, nothing, nothing)
  PS._la_beta_step!(ws, m)
  @test PS._la_predictor_step!(ws)
  @test ws.roots > 0
  v = ws.eta_new .+ ws.w ./ m.ρ
  for i in 1:n
    @test ws.t_new[i] == PS._la_root(v[i], y[i] == 1, m.ρ)[1]
    @test ws.w_new[i] == m.ρ * (v[i] - ws.t_new[i])
    @test abs(PS._la_residual(ws.t_new[i], y[i] == 1) - ws.w_new[i]) <= 16 * eps() * (1 + m.ρ * abs(v[i]))
  end
  # a failed root (here a reduced cap) stops the step; the steps of the failed root are counted
  ws = PS._la_workspace(zeros(k), f, g, m, nothing, nothing, 0)
  PS._la_beta_step!(ws, m)
  @test !PS._la_predictor_step!(ws)
end

@testset "an iteration that fails a root is discarded" begin
  X, y, λ, w = problem(50, 4; seed = 24)
  n, k = size(X)
  f, g = LogisticLoss(y, X), NormL1(λ, w)
  m = LogisticADMM()
  ws = PS._la_workspace(zeros(k), f, g, m, nothing, nothing)
  @test PS._la_iterate!(ws, m) === :continue
  state = (copy(ws.b), copy(ws.eta), copy(ws.t), copy(ws.w), ws.F, ws.kkt)
  ws.cap = 0
  @test PS._la_iterate!(ws, m) === :prox_failed
  @test (ws.b, ws.eta, ws.t, ws.w, ws.F, ws.kkt) == state
  # the whole solve with a zero cap: no iteration completes, the start is returned with :prox_failed
  b = zeros(k)
  t0, u0 = zeros(n), zeros(n)
  r = PS._solve_logistic_admm!(b, f, g, m, t0, u0; cap = 0)
  @test r.stop_reason === :prox_failed && !r.converged && r.iterations == 0
  @test b == zeros(k) && r.minimizer === b && r.t === t0 && r.u === u0 && t0 == zeros(n) && u0 == zeros(n)
  @test isnan(r.r_norm) && isnan(r.s_norm) && isnan(r.eps_pri) && isnan(r.eps_dual)
  @test isnan(r.inner_kkt) && !r.inner_met && r.passes > 0
  check_result(r, b, X, y, λ, w; converged = false)
  # a failure after completed iterations returns the last completed one
  ref = zeros(k)
  rr = solve!(ref, f, g, LogisticADMM(maxiter = 3))
  b = zeros(k)
  ws = PS._la_workspace(b, f, g, m, nothing, nothing)
  for _ in 1:3
    PS._la_iterate!(ws, m)
  end
  ws.cap = 0
  @test PS._la_iterate!(ws, m) === :prox_failed
  @test ws.b == ref && ws.t == rr.t && ws.w ≈ m.ρ .* rr.u
end

# ---- results against independent references --------------------------------------------------------------------
@testset "intercept-only balance, a zero-penalty fit and the Newton reference" begin
  rng = Xoshiro(3)
  y = Float64.(rand(rng, 40) .< 0.3)
  X = ones(40, 1)
  ȳ = sum(y) / 40
  @test 0 < ȳ < 1
  for g in (NormL1(0.0), NormL1(2.0, [0.0]), NormL1(0.0, [0.0]))
    b = [0.0]
    r = solve!(b, LogisticLoss(y, X), g, LogisticADMM())
    check_result(r, b, X, y, g.λ0, g.w)
    @test b[1] ≈ log(ȳ / (1 - ȳ)) atol = 1e-7
  end
  # identifiable zero-penalty fit against the damped Newton reference in BigFloat
  X, y = logistic_data(200, 4; seed = 6)
  k = size(X, 2)
  bref, gnorm = newton(X, y)
  @test gnorm < 1e-30
  b64 = Float64.(bref)
  for g in (NormL1(0.0), NormL1(0.0, zeros(k)))
    b = zeros(k)
    r = solve!(b, LogisticLoss(y, X), g, LogisticADMM())
    check_result(r, b, X, y, 0.0, g.w)
    @test norm(b - b64, Inf) <= 1e-6 * max(1, norm(b64, Inf))
    @test abs(r.minimum - Float64(oracle(X, y, bref).value)) <= 1e-8 * max(1, r.minimum)
  end
end

@testset "regularized fits against ProxNewton: shapes, correlation, p > n and a large level" begin
  cases = [(200, 6, 0.5, 0.2), (300, 20, 0.5, 0.15), (100, 30, 0.8, 0.1), (50, 200, 0.0, 0.3), (120, 8, 0.0, 1.5)]
  for (i, (n, p, corr, level)) in enumerate(cases)
    X, y, λ, w = problem(n, p; seed = 30 + i, level, corr)
    Xc, yc, wc = copy(X), copy(y), copy(w)
    bpn, Fpn = reference(X, y, λ, w)
    b = zeros(size(X, 2))
    r = solve!(b, LogisticLoss(y, X), NormL1(λ, w), LogisticADMM())
    ind = check_result(r, b, X, y, λ, w)
    # criterion 2: the objective of ProxNewton at tol = 1e-10, to 1e-8 max(1, |F|)
    @test (i, abs(r.minimum - Fpn) <= 1e-8 * max(1, abs(Fpn))) == (i, true)
    @test (i, norm(b - bpn, Inf) <= 1e-4) == (i, true)
    @test r.iterations > 0 && r.passes >= r.iterations && r.root_iterations > 0
    @test X == Xc && y == yc && w == wc
    if level >= 1
      # above the slope threshold the slopes are exactly zero and the intercept is logit(ȳ)
      ȳ = sum(y) / n
      @test all(iszero, b[2:end]) && abs(b[1] - log(ȳ / (1 - ȳ))) <= 1e-7
    else
      @test any(!iszero, b[2:end])
    end
  end
end

@testset "agreement with ProximalGradientDescent and ProxNewton at matched KKT" begin
  X, y, λ, w = problem(300, 20; seed = 4, level = 0.15)
  f, g = LogisticLoss(y, X), NormL1(λ, w)
  ba, bp, bn = zeros(21), zeros(21), zeros(21)
  ra = solve!(ba, f, g, LogisticADMM(tol = 1e-9))
  options = ProximalOptions(maxiter = 20_000, ftol = 1e-15, xtol = 1e-12, gradtol = 1e-10, allow_f_increases = true)
  rp = solve!(bp, f, g, ProximalGradientDescent(), options)
  rn = solve!(bn, f, g, ProxNewton(tol = 1e-9))
  @test ra.converged && rp.converged && rn.converged
  ia, ip, in_ = independent(X, y, ba, λ, w), independent(X, y, bp, λ, w), independent(X, y, bn, λ, w)
  @test max(ia.score, ip.score, in_.score) <= 1e-8
  @test abs(ia.objective - ip.objective) <= 1e-9 * ip.objective && abs(ia.objective - in_.objective) <= 1e-9 * in_.objective
  @test norm(ba - bp, Inf) <= 1e-5 && norm(ba - bn, Inf) <= 1e-5
  @test ia.score <= 1e-9 + 10 * rounding_bound(X, ba) + 1e-12
end

@testset "penalty weights: unit weights, a zero weight on a slope and a very large weight" begin
  X, y = logistic_data(160, 10; seed = 7)
  n, k = size(X)
  level = 0.2 * norm(X' * (0.5 .- y), Inf)
  b1, b2 = zeros(k), zeros(k)
  r1 = solve!(b1, LogisticLoss(y, X), NormL1(level), LogisticADMM())
  r2 = solve!(b2, LogisticLoss(y, X), NormL1(level, ones(k)), LogisticADMM())
  check_result(r1, b1, X, y, level)
  check_result(r2, b2, X, y, level, ones(k))
  @test norm(b1 - b2, Inf) <= 1e-5
  X, y, λ, _ = problem(200, 7; seed = 8, level = 0.3)
  k = size(X, 2)
  w = [0.0; ones(k - 1)]
  w[4] = 0.0
  w[3] = 1e6
  b = zeros(k)
  r = solve!(b, LogisticLoss(y, X), NormL1(λ, w), LogisticADMM())
  check_result(r, b, X, y, λ, w)
  @test b[3] == 0.0 && b[4] != 0.0
end

@testset "extreme finite logits at the start" begin
  # logits (0, 400, -400, 800) with y = (0, 0, 1, 1): two rows are wrong by hundreds of units, one is right by far
  X = [1.0 0.0; 1.0 1.0; 1.0 -1.0; 1.0 2.0]
  y = [0.0, 0.0, 1.0, 1.0]
  w = [0.0, 1.0]
  b = [0.0, 400.0]
  F0 = independent(X, y, b, 0.5, w).objective
  r = solve!(b, LogisticLoss(y, X), NormL1(0.5, w), LogisticADMM())
  @test all(isfinite, b) && isfinite(r.minimum) && isfinite(r.kkt) && r.minimum < F0
  check_result(r, b, X, y, 0.5, w)
  bpn, Fpn = reference(X, y, 0.5, w)
  @test abs(r.minimum - Fpn) <= 1e-8 * max(1, Fpn)
end

@testset "a supplied t and u, a restart from a result, and the warm start at a minimizer" begin
  X, y, λ, w = problem(150, 10; seed = 9)
  n, k = size(X)
  f, g = LogisticLoss(y, X), NormL1(λ, w)
  bpn, Fpn = reference(X, y, λ, w)
  # a nonzero initial predictor and dual: the caller's vectors receive the returned ones
  b = zeros(k)
  t0, u0 = randn(Xoshiro(5), n), 3 .* randn(Xoshiro(6), n)
  r = solve!(b, f, g, LogisticADMM(); t = t0, u = u0)
  check_result(r, b, X, y, λ, w)
  @test r.t === t0 && r.u === u0
  @test abs(r.minimum - Fpn) <= 1e-8 * max(1, Fpn)
  # a restart from the result with its t and u takes few iterations
  r2 = solve!(b, f, g, LogisticADMM(); t = r.t, u = r.u)
  check_result(r2, b, X, y, λ, w)
  @test r2.iterations <= 3
  # the default dual makes a minimizer with its own predictor a fixed point: one iteration from the ProxNewton
  # solution, with the coefficients essentially unchanged
  b = copy(bpn)
  r = solve!(b, f, g, LogisticADMM())
  check_result(r, b, X, y, λ, w)
  @test r.iterations == 1 && norm(b - bpn, Inf) <= 1e-9
  # the same warm start with ρ = 1e3 converges; with the largest ρ, 1e10, it keeps finite outputs and the coefficients
  b = copy(bpn)
  r = solve!(b, f, g, LogisticADMM(ρ = 1e3))
  check_result(r, b, X, y, λ, w)
  @test r.iterations <= 2 && norm(b - bpn, Inf) <= 1e-8
  b = copy(bpn)
  r = solve!(b, f, g, LogisticADMM(ρ = 1e10, maxiter = 3))
  @test all(isfinite, b) && all(isfinite, r.t) && all(isfinite, r.u) && isfinite(r.kkt) && norm(b - bpn, Inf) <= 1e-8
  check_result(r, b, X, y, λ, w; converged = false)
end

@testset "small and large valid ρ, budgets and nonconvergence" begin
  X, y, λ, w = problem(120, 8; seed = 10)
  n, k = size(X)
  f, g = LogisticLoss(y, X), NormL1(λ, w)
  bpn, Fpn = reference(X, y, λ, w)
  for ρ in (0.03, 1.0)
    b = zeros(k)
    r = solve!(b, f, g, LogisticADMM(ρ = ρ))
    check_result(r, b, X, y, λ, w)
    @test abs(r.minimum - Fpn) <= 1e-8 * max(1, Fpn) && r.ρ == ρ
  end
  # a large ρ from a cold start is slow: the budget is spent with finite outputs
  b = zeros(k)
  r = solve!(b, f, g, LogisticADMM(ρ = 1e3, maxiter = 50))
  @test r.stop_reason === :maxiter && !r.converged && r.iterations == 50
  @test all(isfinite, b) && all(isfinite, r.t) && all(isfinite, r.u) && isfinite(r.kkt) && isfinite(r.minimum)
  check_result(r, b, X, y, λ, w; converged = false)
  # the smallest ρ is accepted and gives finite outputs
  b = zeros(k)
  r = solve!(b, f, g, LogisticADMM(ρ = 1e-10, maxiter = 5))
  @test r.iterations == 5 && all(isfinite, b) && all(isfinite, r.t) && all(isfinite, r.u)
  check_result(r, b, X, y, λ, w; converged = false)
  # maxiter = 0: the start, with NaN residuals and the budget reason, also at a minimizer
  for b0 in (zeros(k), copy(bpn))
    b = copy(b0)
    t0, u0 = X * b0, randn(Xoshiro(1), n)
    tc, uc = copy(t0), copy(u0)
    r = solve!(b, f, g, LogisticADMM(maxiter = 0); t = t0, u = u0)
    @test r.stop_reason === :maxiter && !r.converged && r.iterations == 0 && r.passes == 0 && r.root_iterations == 0
    @test b == b0 && t0 == tc && u0 == uc && r.t === t0 && r.u === u0
    @test isnan(r.r_norm) && isnan(r.s_norm) && isnan(r.eps_pri) && isnan(r.eps_dual) && isnan(r.inner_kkt)
    check_result(r, b, X, y, λ, w; converged = false)
  end
  # maxiter = 1: one iteration
  b = zeros(k)
  r = solve!(b, f, g, LogisticADMM(maxiter = 1))
  @test r.iterations == 1 && r.stop_reason === :maxiter && r.passes > 0 && r.root_iterations > 0
  @test all(isfinite, (r.r_norm, r.s_norm, r.eps_pri, r.eps_dual, r.inner_kkt))
  check_result(r, b, X, y, λ, w; converged = false)
  # nonconvergence within a small budget
  b = zeros(k)
  r = solve!(b, f, g, LogisticADMM(maxiter = 3))
  @test r.stop_reason === :maxiter && !r.converged && r.kkt > r.tolerance
end

@testset "the stop needs the residual tests and the KKT test together" begin
  X, y, λ, w = problem(200, 20; seed = 11)
  n, k = size(X)
  f, g = LogisticLoss(y, X), NormL1(λ, w)
  # loose residual tolerances with a tight tol: the first residual pass does not stop the solve
  b = zeros(k)
  tight = solve!(b, f, g, LogisticADMM(abstol = 1e-2, reltol = 1e-2, tol = 1e-9))
  check_result(tight, b, X, y, λ, w)
  @test tight.kkt <= 1e-9
  # the same residual tolerances with a tol above every score stop at the first residual pass, with a larger score
  b = zeros(k)
  loose = solve!(b, f, g, LogisticADMM(abstol = 1e-2, reltol = 1e-2, tol = 1e10))
  @test loose.converged && loose.kkt > 1e-9 && loose.iterations < tight.iterations
  # conversely, a score below tol with residuals above their thresholds does not stop
  b = zeros(k)
  early = solve!(b, f, g, LogisticADMM(abstol = 1e-12, reltol = 0, tol = 1e10, maxiter = 1))
  @test early.kkt <= early.tolerance && (early.r_norm > early.eps_pri || early.s_norm > early.eps_dual)
  @test early.stop_reason === :maxiter && !early.converged
end

@testset "a stalled solve: an iteration that changes no bit of b, t and u" begin
  # X = 0 keeps X b = 0 and the gradient 0; with y = 0 the default dual is w = 1/2 and v = w/ρ = 2. The root of
  # σ(t) + (t - 2)/4 = 0 is 0, and its computed value t₁ satisfies (2 - t₁)/4 = 1/2 when |t₁| < eps(2)/2, so the second
  # iteration repeats the first. With zero residual tolerances the primal residual |t₁|√n stops the convergence test
  # unless t₁ = 0, in which case the first iteration converges.
  t1 = PS._la_root(2.0, false, 0.25)[1]
  @test abs(t1) < eps(2.0) / 2
  X, y = zeros(4, 1), zeros(4)
  b = [0.0]
  r = solve!(b, LogisticLoss(y, X), NormL1(1.0), LogisticADMM(tol = 0, abstol = 0, reltol = 0))
  if iszero(t1)
    @test r.stop_reason === :converged && r.iterations == 1
  else
    @test r.stop_reason === :stalled && !r.converged && r.iterations == 2
    @test r.t == fill(t1, 4) && r.u == fill(2.0, 4) && b == [0.0] && r.r_norm > r.eps_pri
  end
end

@testset "the result type, its accessors and its display" begin
  X, y, λ, w = problem(100, 5; seed = 16)
  b = zeros(size(X, 2))
  r = solve!(b, LogisticLoss(y, X), NormL1(λ, w), LogisticADMM())
  @test r isa LogisticADMMResults && !(r isa ADMMResults) && r.minimizer === b
  @test PS.minimizer(r) === b && PS.minimum(r) == r.minimum && PS.iterations(r) == r.iterations
  @test PS.converged(r) == r.converged && r.tolerance == 1e-7 && r.ρ == 0.25
  @test summary(r) == "Logistic ADMM"
  @test r.inner_met isa Bool && isfinite(r.inner_kkt)
  text = sprint(show, r)
  for part in ("Logistic ADMM", "Stop reason: converged", "Coordinate passes", "Scalar root steps", "primal residual",
               "dual residual", "largest KKT score")
    @test occursin(part, text)
  end
end

@testset "a one-class sample with an unpenalized intercept has no minimizer" begin
  X, y = ones(5, 1), ones(5)
  for g in (NormL1(0.0), NormL1(2.0, [0.0]))
    b = [0.0]
    r = solve!(b, LogisticLoss(y, X), g, LogisticADMM(maxiter = 2000))
    @test r.minimizer === b && isfinite(b[1]) && b[1] > 0 && isfinite(r.minimum) && isfinite(r.kkt)
    @test r.minimum < 5 * log(2)
    @test r.stop_reason in (:converged, :maxiter, :stalled)
    ind = independent(X, y, b, g.λ0, g.w)
    r.converged && @test ind.score <= r.tolerance + 1e-12
  end
end

@testset "numerical exceptions leave the caller's arrays and the inputs unchanged" begin
  # a column whose squared norm underflows: the β step refuses it (CD-04)
  X, y = fill(1e-170, 5, 1), [1.0, 0.0, 1.0, 1.0, 0.0]
  Xc, yc = copy(X), copy(y)
  x, t0, u0 = [1.0], fill(0.5, 5), fill(-0.25, 5)
  err = try
    solve!(x, LogisticLoss(y, X), NormL1(1.0), LogisticADMM(); t = t0, u = u0)
    nothing
  catch e
    e
  end
  @test err isa ArgumentError && occursin("curvature", sprint(showerror, err))
  @test x == [1.0] && t0 == fill(0.5, 5) && u0 == fill(-0.25, 5) && X == Xc && y == yc
  # a coordinate curvature that overflows
  X = [1e200 1.0; 1e200 -1.0; 1e200 2.0]
  y = [0.0, 1.0, 1.0]
  Xc, yc = copy(X), copy(y)
  x = zeros(2)
  err = try
    solve!(x, LogisticLoss(y, X), NormL1(1.0), LogisticADMM())
    nothing
  catch e
    e
  end
  @test err isa ArgumentError && occursin("not finite", sprint(showerror, err))
  @test x == zeros(2) && X == Xc && y == yc
  # starts with a nonfinite predictor or gradient are refused before any write
  X1 = fill(1e308, 3, 1)
  y1 = zeros(3)
  for (start, message) in (([10.0], "start from a point where f is finite"),
                           ([0.1], "start from a point where the gradient of f is finite"))
    x = copy(start)
    err = try
      solve!(x, LogisticLoss(y1, X1), NormL1(1.0), LogisticADMM())
      nothing
    catch e
      e
    end
    @test err isa ArgumentError && occursin(message, sprint(showerror, err))
    @test x == start
  end
end

# ---- refusals before any write -----------------------------------------------------------------------------------
# The exception of a refused call and whether x, and t and u when given, kept their entries (isequal: NaN entries
# compare equal)
function refusal(x, f, g, method; kwargs...)
  before = collect(x)
  given = Dict(k => collect(v) for (k, v) in kwargs if v isa AbstractArray)
  err = try
    solve!(x, f, g, method; kwargs...)
    nothing
  catch e
    e
  end
  err, isequal(collect(x), before) && all(isequal(collect(kwargs[k]), v) for (k, v) in given)
end

@testset "refusals before any write: inputs outside the scope" begin
  X, y = logistic_data(40, 3; seed = 12)
  n, k = size(X)
  f = LogisticLoss(y, X)
  w = [0.0, 1.0, 1.0, 1.0]
  g = NormL1(1.0, w)
  la = LogisticADMM()
  start = [0.1, -0.2, 0.3, 0.0]
  groups = [[1, 2], [3, 4]]
  row = reshape(copy(start), 1, 4)
  Xsq, ysq = X[1:4, :], [0.0, 1.0, 0.0, 1.0]
  fsq = LogisticLoss(ysq, Xsq)
  wv = copy(w)
  Xs, ys = copy(X), copy(y)
  mutated(change!) = (Xc = copy(X); yc = copy(y); fc = LogisticLoss(yc, Xc); change!(Xc, yc); fc)
  reweighted(v) = (wm = copy(w); gm = NormL1(1.0, wm); wm[2] = v; gm)
  cases = [
    # losses other than the raw logistic loss
    (copy(start), LeastSquaresLoss(y, X), g, ArgumentError, "LogisticADMM supports only the raw LogisticLoss"),
    (copy(start), (1 / n) * LeastSquaresLoss(y, X), g, ArgumentError, "LogisticADMM supports only the raw LogisticLoss"),
    (copy(start), SqrNormL2(1.0, zeros(k)), g, ArgumentError, "LogisticADMM supports only the raw LogisticLoss"),
    (copy(start), (1 / n) * f, g, ArgumentError, "Scaled(LogisticLoss) is not supported"),
    # the loss and the arrays
    (Float32.(start), LogisticLoss(Float32.(y), Float32.(X)), NormL1(1f0, Float32.(w)), ArgumentError,
     "X::Matrix{Float64} and y::Vector{Float64}"),
    (copy(start), LogisticLoss(y, sparse(X)), g, ArgumentError, "X::Matrix{Float64}"),
    (copy(start), LogisticLoss(y, view(X, :, 1:k)), g, ArgumentError, "X::Matrix{Float64}"),
    (copy(start), LogisticLoss(view(y, 1:n), X), g, ArgumentError, "y::Vector{Float64}"),
    (Float32.(start), f, NormL1(1f0, Float32.(w)), ArgumentError, "x to be a dense Vector{Float64}"),
    (view(copy(start), 1:k), f, g, ArgumentError, "x to be a dense Vector{Float64}"),
    (SparseIterate(copy(start)), f, g, ArgumentError, "x to be a dense Vector{Float64}"),
    (BlockIterate(copy(start), groups), f, GroupNormL2(1.0, groups), ArgumentError, "x to be a dense Vector{Float64}"),
    ([1.0 0.1; 0.1 1.0], f, NormL1(1.0), ArgumentError, "x to be a dense Vector{Float64}"),
    (copy(start), LogisticLoss(y, X; weights = ones(n)), g, ArgumentError, "observation weights or an offset"),
    (copy(start), LogisticLoss(y, X; offset = zeros(n)), g, ArgumentError, "observation weights or an offset"),
    # shapes
    (zeros(k + 1), f, NormL1(1.0), DimensionMismatch, "x/y dimensions do not match X"),
    (zeros(k - 1), f, NormL1(1.0), DimensionMismatch, "x/y dimensions do not match X"),
    (zeros(k), LogisticLoss(zeros(0), zeros(0, k)), NormL1(1.0), DimensionMismatch, "positive row and column counts"),
    (copy(start), mutated((Xc, yc) -> resize!(yc, n - 1)), g, DimensionMismatch, "x/y dimensions do not match X"),
    # penalties other than NormL1, then the NormL1 rules
    (copy(start), f, ElasticNet(1.0, 1.0), ArgumentError, "only NormL1"),
    (copy(start), f, NormLinf(1.0), ArgumentError, "only NormL1"),
    (copy(start), f, GroupNormL2(1.0, groups), ArgumentError, "only NormL1"),
    (copy(start), f, NormL1Nonneg(1.0), ArgumentError, "only NormL1"),
    (abs.(start), f, IndNonnegative(), ArgumentError, "only NormL1"),
    (copy(start), f, SqrNormL2(1.0), ArgumentError, "only NormL1"),
    (copy(start), f, 2 * g, ArgumentError, "only NormL1"),
    (copy(start), f, NormL1(1.0, [0.0, 1.0, 1.0]), DimensionMismatch, "3 weights"),
    (copy(start), f, NormL1(1.0, Float32.(w)), ArgumentError, "penalty weights must be a Vector{Float64}"),
    (copy(start), f, NormL1(1e300, [0.0, 1e10, 1.0, 1.0]), ArgumentError, "overflows"),
    (copy(start), f, reweighted(-1.0), ArgumentError, "penalty weight 2 must be finite and nonnegative"),
    (copy(start), f, reweighted(NaN), ArgumentError, "penalty weight 2 must be finite and nonnegative"),
    # aliasing of x
    (wv, f, NormL1(1.0, wv), ArgumentError, "must not alias the penalty weights"),
    (vec(row), LogisticLoss([1.0], row), g, ArgumentError, "must not alias borrowed X or y"),
    (ysq, fsq, g, ArgumentError, "must not alias borrowed X or y"),
    (fsq.tmp, fsq, g, ArgumentError, "scratch of the loss"),
    # values
    ([0.1, NaN, 0.3, 0.0], f, g, ArgumentError, "finite"),
    ([0.1, Inf, 0.3, 0.0], f, g, ArgumentError, "finite"),
    (copy(start), mutated((Xc, yc) -> (Xc[2, 3] = Inf)), g, ArgumentError, "finite"),
    (copy(start), mutated((Xc, yc) -> (yc[3] = 0.5)), g, ArgumentError, "LogisticLoss with LogisticADMM needs a binary response"),
    (copy(start), mutated((Xc, yc) -> (yc[3] = NaN)), g, ArgumentError, "LogisticLoss with LogisticADMM needs a binary response"),
    (copy(start), LogisticLoss(fill(0.25, n), X), g, ArgumentError, "LogisticLoss with LogisticADMM needs a binary response"),
  ]
  for (i, (x, loss, penalty, E, message)) in enumerate(cases)
    err, unchanged = refusal(x, loss, penalty, la)
    text = err === nothing ? "" : sprint(showerror, err)
    @test (i, err isa E) == (i, true)
    @test (i, occursin(message, text)) == (i, true)
    @test (i, unchanged) == (i, true)
  end
  @test X == Xs && y == ys
  # the predictor t and the dual u: type, length, overlap with the other arrays and with each other, values
  t0, u0 = zeros(n), zeros(n)
  shared = zeros(2n)
  bad = [
    ((t = Float32.(t0),), ArgumentError, "t must be a dense Vector{Float64}"),
    ((t = view(zeros(n + 1), 1:n),), ArgumentError, "t must be a dense Vector{Float64}"),
    ((u = reshape(zeros(n), n, 1),), ArgumentError, "u must be a dense Vector{Float64}"),
    ((t = zeros(n - 1),), DimensionMismatch, "t has $(n - 1) entries"),
    ((u = zeros(n + 1),), DimensionMismatch, "u has $(n + 1) entries"),
    ((t = y,), ArgumentError, "t must not overlap"),
    ((u = f.tmp,), ArgumentError, "u must not overlap"),
    ((t = vec(view(X, :, 1)),), ArgumentError, "t must be a dense Vector{Float64}"),
    ((t = t0, u = t0), ArgumentError, "t must not overlap"),
    ((t = unsafe_wrap(Array, pointer(shared), n), u = unsafe_wrap(Array, pointer(shared, 2), n)), ArgumentError, "t must not overlap"),
    ((t = [fill(0.0, n - 1); NaN],), ArgumentError, "t must contain only finite values"),
    ((u = [fill(0.0, n - 1); Inf],), ArgumentError, "u must contain only finite values"),
  ]
  for (i, (kw, E, message)) in enumerate(bad)
    err, unchanged = GC.@preserve shared refusal(copy(start), f, g, la; kw...)
    text = err === nothing ? "" : sprint(showerror, err)
    @test (i, err isa E) == (i, true)
    @test (i, occursin(message, text)) == (i, true)
    @test (i, unchanged) == (i, true)
  end
  # t or u overlapping x, X or the penalty weights, on a square design (n = p) so that the lengths agree
  Xn = X[1:k, :]
  fk = LogisticLoss(y[1:k], Xn)
  x = copy(start)
  err, unchanged = refusal(x, fk, g, la; t = x)
  @test err isa ArgumentError && occursin("t must not overlap", sprint(showerror, err)) && unchanged
  wk = copy(w)
  err, unchanged = refusal(copy(start), fk, NormL1(1.0, wk), la; u = wk)
  @test err isa ArgumentError && occursin("u must not overlap", sprint(showerror, err)) && unchanged && wk == w
  Xcol = zeros(k, k)
  fcol = LogisticLoss(zeros(k), Xcol)
  err, unchanged = refusal(copy(start), fcol, NormL1(1.0), la; t = unsafe_wrap(Array, pointer(Xcol), k))
  @test err isa ArgumentError && occursin("t must not overlap", sprint(showerror, err)) && unchanged
  # a product ρ u or a response t - u that is not finite
  err, unchanged = refusal(copy(start), f, g, LogisticADMM(ρ = 1e10); u = fill(1e300, n))
  @test err isa ArgumentError && occursin("ρ * u must be finite", sprint(showerror, err)) && unchanged
  err, unchanged = refusal(copy(start), f, g, la; t = fill(1e308, n), u = fill(-1e308, n))
  @test err isa ArgumentError && occursin("t - u must be finite", sprint(showerror, err)) && unchanged
  # keywords other than t and u, and positional options after the solver, are refused before the gate
  @test_throws ArgumentError("unsupported solve! keywords: foo") solve!(copy(start), f, g, la; foo = 1)
  @test_throws ArgumentError solve!(copy(start), f, g, la, ProximalOptions())
  # the same inputs are accepted with supported t and u
  b = copy(start)
  r = solve!(b, f, g, la; t = t0, u = u0)
  @test r.minimizer === b && r.t === t0 && r.u === u0
end

@testset "the other solvers refuse the logistic loss and name LogisticADMM" begin
  X, y = logistic_data(40, 3; seed = 12)
  n, k = size(X)
  f, g = LogisticLoss(y, X), NormL1(1.0, [0.0, 1.0, 1.0, 1.0])
  start = [0.1, -0.2, 0.3, 0.0]
  for (method, message) in ((AccProxGradDescent(), "LogisticLoss is supported only by ProximalGradientDescent, ProxNewton and LogisticADMM"),
                            (CDSolver(), "LogisticLoss is supported only by ProximalGradientDescent, ProxNewton and LogisticADMM"))
    for loss in (f, (1 / n) * f)
      err, unchanged = refusal(copy(start), loss, g, method)
      @test err isa ArgumentError && occursin(message, sprint(showerror, err)) && unchanged
    end
  end
  # ADMMSolver on a Vector or a Matrix z, with the raw and the scaled loss and a supplied u that is left unchanged
  Λ = [0.0 1.0; 1.0 0.0]
  for loss in (f, (1 / n) * f), (z, u, pen) in (([0.1, -0.2, 0.3, 0.0], [0.01, 0.02, -0.03, 0.04], NormL1(1.0)),
                                               ([1.0 0.1; 0.1 1.0], [0.01 0.02; 0.02 0.03], NormL1(1.0, Λ)))
    zb, ub = copy(z), copy(u)
    err = try
      solve!(z, loss, pen, ADMMSolver(); u = u)
      nothing
    catch e
      e
    end
    @test err isa ArgumentError && occursin("ADMMSolver does not support LogisticLoss; use LogisticADMM", sprint(showerror, err))
    @test z == zb && u == ub
  end
end

end
