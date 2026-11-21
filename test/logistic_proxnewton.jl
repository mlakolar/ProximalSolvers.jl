module LogisticProxNewtonTest
# Sparse logistic regression with ProxNewton (PN-01 to PN-05): a raw LogisticLoss{Float64} on a dense Matrix{Float64}
# with a binary response and NormL1, with or without penalty weights, on a Vector{Float64}. The references are
# computed from the stored data in BigFloat with formulas of their own, not with ProximalBase's oracles; the
# solver's own scores are compared with them. The helpers are private to this file.
using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

# Stable scalar formulas, for Float64 and BigFloat arguments
sigmoid(t) = t >= 0 ? inv(1 + exp(-t)) : (e = exp(t); e / (1 + e))
softplus(t) = t > 0 ? t + log1p(exp(-t)) : log1p(exp(t))

# The raw loss and its gradient at b in BigFloat from the stored data, for a binary y. With η = X b and sᵢ = 1 - 2yᵢ the
# term of observation i is softplus(sᵢηᵢ) = log(1 + e^{ηᵢ}) - yᵢηᵢ and its derivative is sᵢ σ(sᵢηᵢ), which keeps the
# tail of an observation on the side of its label.
function oracle(X, y, b)
  A, s = big.(X), big.(1 .- 2 .* y)
  η = A * big.(b)
  (; value = sum(softplus.(s .* η)), gradient = A' * (s .* sigmoid.(s .* η)))
end

# cⱼ = λ wⱼ in BigFloat (cⱼ = λ without weights)
coefficient(λ, w, j) = big(λ) * (w === nothing ? 1 : big(w[j]))

# The KKT scores of b for NormL1(λ, w) at the gradient G: max(|Gⱼ| - cⱼ, 0) where bⱼ = 0 and |Gⱼ + cⱼ sign(bⱼ)|
# elsewhere. A zero weight scores |Gⱼ|. The largest score is the stationarity residual of the composite objective.
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

# Seeded data: an intercept column of ones, then p covariates with population correlation 1/2 between neighbours,
# and responses drawn from the logistic model with intercept -0.3 and the planted slopes `signal`.
function logistic_data(n, p; seed, signal = [1.0, -0.8, 0.6])
  rng = Xoshiro(seed)
  Z = randn(rng, n, p)
  for j in 2:p
    Z[:, j] .= 0.5 .* Z[:, j - 1] .+ sqrt(0.75) .* Z[:, j]
  end
  β = zeros(p)
  β[1:length(signal)] .= signal
  y = Float64.(rand(rng, n) .< sigmoid.(-0.3 .+ Z * β))
  [ones(n) Z], y
end

# The level above which the slopes vanish when the intercept (column 1) is unpenalized
slope_threshold(X, y) = norm(X[:, 2:end]' * (sum(y) / length(y) .- y), Inf)

# A first-order estimate of the rounding of the entries of the Float64 gradient at b: n u max|X| (n + p M / 4 + 2),
# with u = eps/2 and M = maxᵢ Σⱼ |Xᵢⱼ||bⱼ|, from the product Xᵀd, the image X b and d
rounding_bound(X, b) =
  (n = size(X, 1); M = maximum(abs.(X) * abs.(b)); n * eps() / 2 * maximum(abs, X) * (n + size(X, 2) * M / 4 + 2))

# A regularized problem with an unpenalized intercept: the data, the level, the weights and the start (intercept-only)
function problem(n, p; seed, level = 0.2)
  X, y = logistic_data(n, p; seed)
  w = [0.0; ones(size(X, 2) - 1)]
  ȳ = sum(y) / n
  X, y, level * slope_threshold(X, y), w, [log(ȳ / (1 - ȳ)); zeros(size(X, 2) - 1)]
end

# The checks of a converged result against the independent objective and scores; returns them
function check_result(r, x, X, y, λ, w = nothing; converged = true)
  ind = independent(X, y, x, λ, w)
  slack = 10 * rounding_bound(X, x) + 1e-12
  @test r isa ProxNewtonResults
  @test r.minimizer === x
  @test r.minimum ≈ ind.objective rtol = 1e-12
  @test abs(r.kkt - ind.score) <= slack
  if converged
    @test r.converged && r.stop_reason === :converged
    @test r.kkt <= r.tolerance
    @test ind.score <= r.tolerance + slack
  end
  ind
end

@testset "constructor, defaults and refusals" begin
  m = ProxNewton()
  @test m.maxiter == 100 && m.tol == 1e-7
  @test m.inner isa CDSolver && !m.inner.random && m.inner.momentum === false && !m.inner.relative
  @test m.inner.tol == 1e-11 && m.inner.maxpasses == 2000
  @test summary(m) == "Proximal Newton"
  custom = ProxNewton(inner = CDSolver(order = :cyclic, maxpasses = 7, tol = 1e-4), maxiter = 5, tol = 1e-3)
  @test custom.inner.maxpasses == 7 && custom.inner.tol == 1e-4 && custom.maxiter == 5 && custom.tol == 1e-3
  # a cyclic inner solver is accepted whatever its relative setting; momentum is unset or off
  @test ProxNewton(inner = CDSolver(order = :cyclic)).inner.relative
  @test ProxNewton(maxiter = big(3)).maxiter === 3
  @test ProxNewton(tol = 1 // 1000).tol === 0.001
  @test ProxNewton(tol = 0).tol === 0.0
  @test ProxNewton(maxiter = 0).maxiter === 0
  # refused settings
  @test_throws ArgumentError ProxNewton(inner = CDSolver())                       # the default order is random
  @test_throws ArgumentError ProxNewton(inner = CDSolver(order = :random, momentum = false))
  @test_throws ArgumentError ProxNewton(maxiter = -1)
  for tol in (-1e-3, NaN, Inf, -Inf, big"1e-400")
    @test_throws ArgumentError ProxNewton(tol = tol)
  end
  @test_throws ArgumentError ProxNewton(CDSolver(order = :random), 10, 1e-7)
  @test_throws ArgumentError ProxNewton(CDSolver(order = :cyclic), -3, 1e-7)
  @test ProxNewton(CDSolver(order = :cyclic), 10, 1e-7) isa ProxNewton
end

@testset "the weighted and fixed models reproduce the gradient and bound the Hessian" begin
  rng = MersenneTwister(177)
  n, p = 9, 5
  X = hcat(ones(n), randn(rng, n, p - 1))
  y = [0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0]
  b = randn(rng, p)
  f = LogisticLoss(y, X)
  η = X * b
  G, d = zeros(p), zeros(n)
  ProximalBase.value_and_gradient_from_predictor!(G, d, f, η)
  ref = oracle(X, y, b)
  X64, t64 = big.(X), big.(X) * big.(b)
  @test G ≈ Float64.(ref.gradient) rtol = 1e-12
  # the weighted model: Aᵀ(A b - r) = ∇f(b) and AᵀA = Xᵀ diag(σ(η)σ(-η)) X
  A, resp, rows = similar(X), zeros(n), zeros(n)
  @test PS._pn_adaptive_model!(A, resp, rows, X, η, d)
  w64 = sigmoid.(t64) .* sigmoid.(-t64)
  @test rows .^ 2 ≈ Float64.(w64) rtol = 1e-13
  @test A' * (A * b - resp) ≈ G rtol = 1e-9
  @test A' * A ≈ Float64.(X64' * Diagonal(w64) * X64) rtol = 1e-12
  # the fixed model, with the loss scale 1/4 and the borrowed X: ¼ Xᵀ(X b - r) = ∇f(b) and the bound ¼ XᵀX
  respf = zeros(n)
  @test PS._pn_fixed_response!(respf, η, d)
  @test respf == η .- 4 .* d
  @test 0.25 * (X' * (X * b - respf)) ≈ G rtol = 1e-9
  for scale in (0.001, 0.1, 1.0, 10.0)
    b2 = b + scale * randn(rng, p)
    Δ = big.(b2) .- big.(b)
    @test oracle(X, y, b2).value <= ref.value + dot(ref.gradient, Δ) + sum(abs2, X64 * Δ) / 8
  end
  # the weights are the curvature of the loss: below the fixed weight 1/4, and equal to it at η = 0
  @test all(rows .^ 2 .<= 0.25)
  zeros_η = zeros(n)
  d0 = zeros(n)
  ProximalBase.value_and_gradient_from_predictor!(zeros(p), d0, f, zeros_η)
  @test PS._pn_adaptive_model!(similar(X), zeros(n), rows, X, zeros_η, d0)
  @test all(==(0.5), rows)
end

@testset "saturated rows: the guarded ratio, the fixed row and the zero row" begin
  xs = ones(5, 1)
  ys = [0.0, 0.0, 0.0, 0.0, 1.0]
  zs = [800.0, -800.0, -150.0, -2000.0, 2000.0]
  fs = LogisticLoss(ys, xs)
  ds = zeros(5)
  ProximalBase.value_and_gradient_from_predictor!(zeros(1), ds, fs, zs)
  @test ds[1] == 1.0 && ds[2] == 0.0 && 0 < ds[3] < 1e-60 && ds[4] == 0.0 && ds[5] == 0.0
  As, rs, ss = similar(xs), zeros(5), zeros(5)
  @test PS._pn_adaptive_model!(As, rs, ss, xs, zs, ds)
  # a wrong-side saturated row has d = 1 and a root below 1/sqrt(eps) times d: the fixed row weight 1/2 and its tangent
  @test ss[1] == 0.5 && rs[1] == 400.0 - 2.0 && As[1, 1] == 0.5
  # a correct-side row keeps its small nonzero root and its small curvature, also where its square underflows
  @test 0 < ss[2] < sqrt(floatmin(Float64))
  @test ss[3] ≈ exp(-75) rtol = 1e-13
  @test ss[3] * (ss[3] * zs[3] - rs[3]) ≈ ds[3] rtol = 1e-8
  # where the root and the derivative both round to zero, the row is zero
  @test ss[4] == 0 && rs[4] == 0 && all(iszero, As[4, :])
  @test ss[5] == 0 && rs[5] == 0 && all(iszero, As[5, :])
  # the fixed response keeps the tangent for every row, finite also at these logits
  rf = zeros(5)
  @test PS._pn_fixed_response!(rf, zs, ds)
  @test rf == zs .- 4 .* ds
  # a nonfinite predictor makes the model unavailable
  @test !PS._pn_fixed_response!(rf, [Inf, 0.0, 0.0, 0.0, 0.0], ds)
end

@testset "the grouped composite slope" begin
  # the signed ℓ1 coefficient joins the gradient before the displacement multiplies it, and a sign change is split
  @test PS._pn_slope([0.3], [1.0], [2.0], [0.7]) == (0.3 + 0.7) * (2.0 - 1.0)
  @test PS._pn_slope([0.3], [1.0], [-2.0], [0.7]) == (0.3 - 0.7) * (-2.0) - (0.3 + 0.7) * 1.0
  @test PS._pn_slope([0.3], [-1.0], [2.0], [0.7]) == (0.3 + 0.7) * 2.0 - (0.3 - 0.7) * (-1.0)
  @test PS._pn_slope([0.3], [-1.0], [-3.0], [0.7]) == (0.3 - 0.7) * (-3.0 - (-1.0))
  @test PS._pn_slope([0.3], [0.0], [2.0], [0.7]) == (0.3 + 0.7) * 2.0
  @test PS._pn_slope([0.3], [0.0], [-2.0], [0.7]) == (0.3 - 0.7) * (-2.0)
  @test PS._pn_slope([0.3], [4.0], [0.0], [0.7]) == (0.3 + 0.7) * (0.0 - 4.0)
  @test PS._pn_slope([0.3], [0.0], [0.0], [0.7]) == 0
  # a sign change: the full-step penalty change is c(|u| - |b|) = c, above the penalty's directional derivative -3c, so
  # the grouped value is an upper bound on the directional derivative G·(u - b) - 3c = -3 (G = 0.3, c = 0.7, b = 1, u = -2)
  @test PS._pn_slope([0.3], [1.0], [-2.0], [0.7]) >= 0.3 * (-3.0) - 3 * 0.7
  # against the exact linearized loss change plus the full penalty change G·(cand - b) + Σ cⱼ(|candⱼ| - |bⱼ|) in BigFloat,
  # with zeros and sign changes
  rng = MersenneTwister(5)
  for _ in 1:30
    p = 12
    G, c = randn(rng, p), rand(rng, p)
    b = randn(rng, p) .* (rand(rng, p) .< 0.6)
    cand = randn(rng, p) .* (rand(rng, p) .< 0.6)
    exact = sum(big(G[j]) * (big(cand[j]) - big(b[j])) + big(c[j]) * (abs(big(cand[j])) - abs(big(b[j])))
                for j in 1:p)
    @test PS._pn_slope(G, b, cand, c) ≈ Float64(exact) atol = 1e-13 rtol = 1e-12
  end
  # cancellation between large penalty totals: every coordinate sits at its subgradient (G = -c, b > 0), so the slope
  # of any displacement is exactly zero, as each term has the factor G + c = 0; a difference of the two penalty
  # totals would carry their rounding of order 1e-10 here
  p = 200
  b = collect(1000.0 .+ (1:p))
  cand = b .+ 1e-9 .* cospi.((1:p) ./ 7)
  @test PS._pn_slope(fill(-0.5, p), b, cand, fill(0.5, p)) == 0
end

@testset "the acceptance rule and the forcing target" begin
  F = 100.0
  slack = 8 * eps(F)
  @test 1e-15 < slack / 10
  # both changes within the rounding of F: accepted only if the score is strictly smaller
  @test PS._pn_accepts(-1e-15, -1e-15, F, 4e-8, 2e-8)
  @test !PS._pn_accepts(-1e-15, -1e-15, F, 4e-8, 4e-8)
  @test !PS._pn_accepts(-1e-15, -1e-15, F, 4e-8, 5e-8)
  @test PS._pn_accepts(1e-15, -1e-15, F, 4e-8, 2e-8)
  # an actual change within the rounding does not meet a requirement beyond it, whatever the score does
  @test !PS._pn_accepts(-1e-15, -1.0, F, 4e-8, 2e-8)
  # beyond the rounding the Armijo comparison decides and the score does not enter
  @test PS._pn_accepts(-1.0, -0.5, F, 1.0, 5.0)
  @test !PS._pn_accepts(-0.1, -0.5, F, 1.0, 0.5)
  @test !PS._pn_accepts(0.5, -1e-3, F, 1.0, 0.5)
  @test PS._pn_accepts(-1e-9, -1e-15, F, 1e-6, 5e-6)
  # the forcing target: max(0.1 tol, min(1/4, sqrt(rho)) rho)
  @test PS._pn_forcing(4.0, 1e-7) == 1.0
  @test PS._pn_forcing(1e-6, 1e-7) ≈ 1e-8 rtol = 1e-12
  @test PS._pn_forcing(1e-2, 0.0) ≈ 1e-3 rtol = 1e-12
end

@testset "the private SparseIterate is loaded from the accepted point" begin
  work = SparseIterate(zeros(6))
  for b in ([0.0, 1.5, 0.0, -2.0, 0.0, 0.25], [3.0, 0.0, 0.0, 0.0, 0.0, 0.0], zeros(6), [0.5, -0.5, 1.0, 2.0, 3.0, 4.0],
            [0.0, 0.0, 0.0, 0.0, 0.0, -1.0])
    PS._pn_load!(work, b)
    @test collect(work) == b
    @test sort(collect(ProximalBase.activecoordinates(work))) == findall(!iszero, b)
    @test ProximalBase.nactive(work) == count(!iszero, b)
  end
end

@testset "the workspace holds the objective, gradient and score at the start" begin
  X, y, λ, wts, b0 = problem(120, 8; seed = 11)
  f, g = LogisticLoss(y, X), NormL1(λ, wts)
  w = PS._pn_workspace(copy(b0), f, g, ProxNewton())
  ind = independent(X, y, b0, λ, wts)
  @test w.b == b0 && w.passes == 0
  @test w.F ≈ ind.objective rtol = 1e-12
  @test w.rho ≈ ind.score atol = 1e-9
  @test w.G ≈ Float64.(oracle(X, y, b0).gradient) rtol = 1e-12
  @test w.c == λ .* wts
end

@testset "the model gradient at a candidate adds the curvature action to the original gradient" begin
  X, y, λ, wts, b0 = problem(120, 8; seed = 12)
  f, g = LogisticLoss(y, X), NormL1(λ, wts)
  rng = MersenneTwister(21)
  b = b0 .+ 0.1 .* randn(rng, length(b0))
  w = PS._pn_workspace(copy(b), f, g, ProxNewton())
  cand = b .+ 0.05 .* randn(rng, length(b))
  cand[3] = 0.0
  copyto!(w.cand, cand)
  ref = oracle(X, y, b)
  X64, t64, Δ = big.(X), big.(X) * big.(b), big.(cand) .- big.(b)
  curvature = sigmoid.(t64) .* sigmoid.(-t64)
  # weighted model
  @test PS._pn_adaptive_model!(w.A, w.resp, w.rows, w.X, w.eta, w.d)
  Gq = ref.gradient + X64' * (curvature .* (X64 * Δ))
  @test PS._pn_surrogate_residual!(w, w.A, 1.0) ≈ Float64(maximum(scores(Gq, cand, λ, wts))) atol = 1e-9
  # fixed model with the loss scale 1/4
  Gf = ref.gradient + X64' * (X64 * Δ) / 4
  @test PS._pn_surrogate_residual!(w, w.X, 0.25) ≈ Float64(maximum(scores(Gf, cand, λ, wts))) atol = 1e-9
end

@testset "the direction of a model meets the forcing target and counts its passes" begin
  X, y, λ, wts, b0 = problem(120, 8; seed = 13)
  f, g = LogisticLoss(y, X), NormL1(λ, wts)
  method = ProxNewton()
  for adaptive in (true, false)
    w = PS._pn_workspace(copy(b0), f, g, method)
    @test adaptive ? PS._pn_adaptive_model!(w.A, w.resp, w.rows, w.X, w.eta, w.d) :
                     PS._pn_fixed_response!(w.resp_fixed, w.eta, w.d)
    used = PS._pn_direction!(w, adaptive, 2000, method.inner.tol, method.tol)
    @test used > 0 && w.passes == used && used <= 2000
    mat, scale = adaptive ? (w.A, 1.0) : (w.X, 0.25)
    @test PS._pn_surrogate_residual!(w, mat, scale) <= PS._pn_forcing(w.rho, method.tol)
    @test PS._pn_slope(w.G, w.b, w.cand, w.c) < 0
    @test w.b == b0                                  # the accepted point is not touched by the inner solve
    # no pass budget: no direction
    w0 = PS._pn_workspace(copy(b0), f, g, method)
    @test PS._pn_direction!(w0, adaptive, 0, method.inner.tol, method.tol) == 0
    @test w0.cand == b0 && w0.passes == 0 && PS._pn_slope(w0.G, w0.b, w0.cand, w0.c) == 0
  end
end

@testset "the inner residual is seeded from the observation derivative, also where the stored images cancel" begin
  # logit 0 in both rows (the images 2^60 and -2^60 of the first two columns cancel exactly), y = (0, 1), d = (1/2, -1/2)
  # and the row root s = 1/2: the response minus the weighted predictor is -d/s = (-1, 1) for the weighted model and
  # -4d = (-2, 2) for the fixed one, and the curvature cache is cleared
  X = [1.0 1.0 -1.0; 1.0 1.0 1.0]
  y = [0.0, 1.0]
  b0 = [2.0^60, -2.0^60, 0.0]
  f, g = LogisticLoss(y, X), NormL1(0.5, [0.0, 0.0, 1.0])
  method = ProxNewton()
  w = PS._pn_workspace(copy(b0), f, g, method)
  @test w.eta == zeros(2) && w.d == [0.5, -0.5] && w.G == [0.0, 0.0, -1.0] && w.rho == 0.5
  @test PS._pn_adaptive_model!(w.A, w.resp, w.rows, w.X, w.eta, w.d) && w.rows == [0.5, 0.5]
  fill!(w.adaptive.a, 1.0)
  PS._pn_direction!(w, true, 0, method.inner.tol, method.tol)    # no pass: only the seeding
  @test w.adaptive.r == [-1.0, 1.0] && all(isnan, w.adaptive.a)
  @test PS._pn_fixed_response!(w.resp_fixed, w.eta, w.d)
  fill!(w.fixed.a, 1.0)
  PS._pn_direction!(w, false, 0, method.inner.tol, method.tol)
  @test w.fixed.r == [-2.0, 2.0] && all(isnan, w.fixed.a)
  # a zero root needs no division: the row has the derivative zero, and the seeded residual is zero
  wz = PS._pn_workspace([0.0, 0.0, 0.0], f, g, method)
  wz.eta[2] = -2000.0
  wz.d[2] = 0.0
  @test PS._pn_adaptive_model!(wz.A, wz.resp, wz.rows, wz.X, wz.eta, wz.d) && wz.rows[2] == 0
  PS._pn_direction!(wz, true, 0, method.inner.tol, method.tol)
  @test wz.adaptive.r[2] == 0 && wz.adaptive.r[1] == -wz.d[1] / wz.rows[1]
  # the same logits with the labels reversed reverse the signs
  wr = PS._pn_workspace(copy(b0), LogisticLoss([1.0, 0.0], X), g, method)
  @test PS._pn_adaptive_model!(wr.A, wr.resp, wr.rows, wr.X, wr.eta, wr.d)
  PS._pn_direction!(wr, true, 0, method.inner.tol, method.tol)
  @test wr.adaptive.r == [1.0, -1.0]
end

@testset "a warm start with large cancelling coefficient images still takes the coordinate step" begin
  # The two large coefficients leave the predictor exactly zero, with the gradient (0, 0, -1) and the score 1/2. Both
  # models start from the residual of the accepted derivative, so the third coefficient can move to 1, which lowers the
  # objective from 2 log 2 to 2 log(1 + e⁻¹) + 1/2 = 1.12652338.
  X = [1.0 1.0 -1.0; 1.0 1.0 1.0]
  y = [0.0, 1.0]
  b0 = [2.0^60, -2.0^60, 0.0]
  w = [0.0, 0.0, 1.0]
  f, g = LogisticLoss(y, X), NormL1(0.5, w)
  start = independent(X, y, b0, 0.5, w)
  @test start.score == 0.5 && start.objective ≈ 2 * log(2)
  b = copy(b0)
  r = solve!(b, f, g, ProxNewton())
  @test r.iterations >= 1 && r.passes > 0 && r.stop_reason !== :stalled
  @test r.minimum < start.objective - 0.2
  ind = check_result(r, b, X, y, 0.5, w)
  @test ind.objective < start.objective - 0.2 && ind.score <= r.tolerance + 1e-12
  @test abs(r.kkt - ind.score) <= 1e-12
  @test b[1:2] == b0[1:2] && b[3] > 0
  # the fixed model alone, through the private test mode of one step, takes the same step from the same start
  method = ProxNewton()
  wk = PS._pn_workspace(copy(b0), f, g, method)
  @test PS._pn_step!(wk, method, (:fixed,))
  @test wk.b[1:2] == b0[1:2] && wk.b[3] ≈ 1
  indf = independent(X, y, wk.b, 0.5, w)
  @test isapprox(wk.F, indf.objective; rtol = 1e-12) && wk.F < start.objective - 0.2
  @test wk.F ≈ 2 * log1p(exp(-1)) + 0.5 rtol = 1e-9
  @test wk.rho < 0.5 && abs(wk.rho - indf.score) <= 1e-12
end

@testset "the objective search accepts, rejects, rounds to nothing and exhausts" begin
  X, y, λ, wts, _ = problem(120, 8; seed = 14)
  f, g = LogisticLoss(y, X), NormL1(λ, wts)
  method = ProxNewton()
  b0 = fill(0.3, size(X, 2))                           # every entry nonzero
  F0, rho0 = let w = PS._pn_workspace(copy(b0), f, g, method)
    w.F, w.rho
  end
  # a model direction is accepted, with the objective, gradient and score of the trial
  w = PS._pn_workspace(copy(b0), f, g, method)
  @test PS._pn_adaptive_model!(w.A, w.resp, w.rows, w.X, w.eta, w.d)
  PS._pn_direction!(w, true, 2000, method.inner.tol, method.tol)
  slope = PS._pn_slope(w.G, w.b, w.cand, w.c)
  @test slope < 0
  @test PS._pn_search!(w, slope)
  @test w.F < F0 && w.b != b0
  ind = independent(X, y, w.b, λ, wts)
  @test w.F ≈ ind.objective rtol = 1e-12
  @test w.rho ≈ ind.score atol = 1e-9
  @test w.G ≈ Float64.(oracle(X, y, w.b).gradient) rtol = 1e-12
  @test w.eta ≈ X * w.b rtol = 1e-14
  # a displacement that rounds to no change is not success, and leaves the point
  w2 = PS._pn_workspace(copy(b0), f, g, method)
  w2.cand .= w2.b .+ 1e-30
  @test !PS._pn_search!(w2, -1.0)
  @test w2.b == b0 && w2.F == F0 && w2.rho == rho0
  # an ascent direction fails at every one of the trials
  w3 = PS._pn_workspace(copy(b0), f, g, method)
  w3.cand .= w3.b .+ 10 .* (w3.G .+ w3.c)
  @test !PS._pn_search!(w3, -1.0)
  @test w3.b == b0 && w3.F == F0 && w3.rho == rho0
end

@testset "work counts even when no trial is accepted, within the pass budget of one iteration" begin
  X, y, λ, wts, _ = problem(120, 8; seed = 15)
  f, g = LogisticLoss(y, X), NormL1(λ, wts)
  b0 = fill(0.3, size(X, 2))
  # the recorded objective is 1000 below any value that a trial can have, so that every trial is rejected
  method = ProxNewton()
  w = PS._pn_workspace(copy(b0), f, g, method)
  w.F -= 1000.0
  @test !PS._pn_step!(w, method)
  @test w.b == b0 && w.passes >= 2                    # the weighted and the fixed model each ran
  # the budget of one iteration is shared by the weighted model, its refinements and the fixed model: with no
  # change test, each run spends its whole allowance (3/4 of the budget for the weighted model, the rest for the other)
  spend = ProxNewton(inner = CDSolver(order = :cyclic, momentum = false, relative = false, tol = 0.0, maxpasses = 8))
  w2 = PS._pn_workspace(copy(b0), f, g, spend)
  w2.F -= 1000.0
  @test !PS._pn_step!(w2, spend)
  @test w2.passes == 8
  # a single pass leaves nothing for the fixed model
  single = ProxNewton(inner = CDSolver(order = :cyclic, momentum = false, relative = false, tol = 0.0, maxpasses = 1))
  w3 = PS._pn_workspace(copy(b0), f, g, single)
  w3.F -= 1000.0
  @test !PS._pn_step!(w3, single)
  @test w3.passes == 1
  # no pass budget: no direction and no step
  nopass = ProxNewton(inner = CDSolver(order = :cyclic, momentum = false, relative = false, maxpasses = 0))
  w4 = PS._pn_workspace(copy(b0), f, g, nopass)
  @test !PS._pn_step!(w4, nopass)
  @test w4.passes == 0 && w4.b == b0
end

@testset "intercept-only models, a zero-penalty fit and the Newton reference" begin
  rng = Xoshiro(3)
  y = Float64.(rand(rng, 40) .< 0.3)
  X = ones(40, 1)
  ȳ = sum(y) / 40
  @test 0 < ȳ < 1
  for g in (NormL1(0.0), NormL1(2.0, [0.0]), NormL1(0.0, [0.0]))
    b = [0.0]
    r = solve!(b, LogisticLoss(y, X), g, ProxNewton(tol = 1e-10))
    check_result(r, b, X, y, g.λ0, g.w)
    @test b[1] ≈ log(ȳ / (1 - ȳ)) atol = 1e-9
  end
  # identifiable zero-penalty fit against the damped Newton reference in BigFloat
  X, y = logistic_data(200, 4; seed = 6)
  k = size(X, 2)
  bref, gnorm = newton(X, y)
  @test gnorm < 1e-30
  b64 = Float64.(bref)
  for g in (NormL1(0.0), NormL1(0.0, zeros(k)))
    b = zeros(k)
    r = solve!(b, LogisticLoss(y, X), g, ProxNewton(tol = 1e-9))
    check_result(r, b, X, y, 0.0, g.w)
    @test norm(b - b64, Inf) <= 1e-7 * max(1, norm(b64, Inf))
    @test r.minimum ≈ Float64(oracle(X, y, bref).value) rtol = 1e-12
  end
end

@testset "regularized fit with an unpenalized intercept: active and inactive coefficients" begin
  X, y = logistic_data(300, 20; seed = 4)
  n, k = size(X)
  level = 0.15 * slope_threshold(X, y)
  w = [0.0; ones(k - 1)]
  Xc, yc, wc = copy(X), copy(y), copy(w)
  b = zeros(k)
  f, g = LogisticLoss(y, X), NormL1(level, w)
  r = solve!(b, f, g, ProxNewton(tol = 1e-9))
  check_result(r, b, X, y, level, w)
  @test r.iterations > 0 && r.iterations <= 50 && r.passes >= r.iterations
  active = findall(!iszero, b[2:end]) .+ 1
  inactive = findall(iszero, b[2:end]) .+ 1
  @test !isempty(active) && !isempty(inactive)
  G = oracle(X, y, b).gradient
  @test abs(G[1]) <= 1e-9 + 10 * rounding_bound(X, b)                       # the unpenalized intercept
  @test all(j -> abs(abs(G[j]) - level) <= 1e-9 + 10 * rounding_bound(X, b), active)
  @test all(j -> abs(G[j]) <= level + 1e-9 + 10 * rounding_bound(X, b), inactive)
  # F/n is the mean negative log likelihood plus (level/n) ‖b₁:ₚ‖₁
  η = X * b
  @test r.minimum / n ≈ sum(softplus.((1 .- 2 .* y) .* η)) / n + (level / n) * sum(abs, b[2:end]) rtol = 1e-12
  # the borrowed inputs are not written
  @test X == Xc && y == yc && w == wc
  # the same problem with ProximalGradientDescent reaches the same point
  bp = zeros(k)
  options = ProximalOptions(maxiter = 20_000, ftol = 1e-15, xtol = 1e-12, gradtol = 1e-10, allow_f_increases = true)
  rp = solve!(bp, f, g, ProximalGradientDescent(), options)
  @test rp.converged
  @test norm(b - bp, Inf) <= 1e-5
  @test abs(r.minimum - rp.minimum) <= 1e-9 * max(1, r.minimum)
end

@testset "the result type, its accessors and its display" begin
  X, y, λ, wts, b0 = problem(100, 5; seed = 16)
  b = copy(b0)
  r = solve!(b, LogisticLoss(y, X), NormL1(λ, wts), ProxNewton())
  @test r isa ProxNewtonResults && r.minimizer === b
  @test PS.minimizer(r) === b && PS.minimum(r) == r.minimum && PS.iterations(r) == r.iterations
  @test PS.converged(r) == r.converged && r.tolerance == 1e-7
  @test summary(r) == "Proximal Newton"
  @test r.converged && r.stop_reason === :converged && r.kkt <= r.tolerance && r.iterations > 0
  text = sprint(show, r)
  @test occursin("Proximal Newton", text) && occursin("Stop reason: converged", text) && occursin("Coordinate passes", text)
  # the returned point is rerun without further work: the start is stationary to the tolerance
  r2 = solve!(b, LogisticLoss(y, X), NormL1(λ, wts), ProxNewton())
  @test r2.converged && r2.iterations == 0 && r2.passes == 0 && r2.stop_reason === :converged
  @test r2.minimum == r.minimum
end

@testset "a zero iteration budget still converges at a stationary start" begin
  # y = (1, 0, 1, 0) and X = 1: the intercept 0 is stationary, with gradient exactly 0
  X, y = ones(4, 1), [1.0, 0.0, 1.0, 0.0]
  b = [0.0]
  r = solve!(b, LogisticLoss(y, X), NormL1(0.0), ProxNewton(maxiter = 0))
  @test r.converged && r.stop_reason === :converged && r.iterations == 0 && r.passes == 0
  @test r.kkt == 0 && isapprox(r.minimum, 4 * log(2); rtol = 1e-14) && b == [0.0]
  # a start that is not stationary is returned unchanged, with the budget reason
  X, y, λ, wts, b0 = problem(80, 4; seed = 17)
  b = copy(b0)
  r = solve!(b, LogisticLoss(y, X), NormL1(λ, wts), ProxNewton(maxiter = 0))
  @test !r.converged && r.stop_reason === :maxiter && r.iterations == 0 && r.passes == 0 && b == b0
  @test r.kkt > r.tolerance
  check_result(r, b, X, y, λ, wts; converged = false)
  # the same start with no pass budget has no direction, so the solve is exactly stalled at the start (PN-01)
  nopass = ProxNewton(inner = CDSolver(order = :cyclic, momentum = false, relative = false, maxpasses = 0))
  b = copy(b0)
  r = solve!(b, LogisticLoss(y, X), NormL1(λ, wts), nopass)
  @test !r.converged && r.stop_reason === :stalled && r.iterations == 0 && r.passes == 0 && b == b0
  check_result(r, b, X, y, λ, wts; converged = false)
end

@testset "budgets: iterations, passes, inner tolerances" begin
  X, y, λ, wts, b0 = problem(120, 8; seed = 18)
  f, g = LogisticLoss(y, X), NormL1(λ, wts)
  # the objective does not increase with the iteration budget, and the reasons are explicit
  objectives = Float64[]
  for k in 0:6
    b = copy(b0)
    r = solve!(b, f, g, ProxNewton(maxiter = k, tol = 1e-12))
    push!(objectives, r.minimum)
    @test r.iterations <= k
    @test r.iterations == k ? r.stop_reason === :maxiter || r.converged : true
    @test r.stop_reason in (:converged, :maxiter, :stalled)
    @test r.converged == (r.stop_reason === :converged)
    check_result(r, b, X, y, λ, wts; converged = false)
  end
  @test all(diff(objectives) .<= 8 .* eps.(objectives[1:end - 1]))
  @test objectives[end] < objectives[1]
  # a single coordinate pass per iteration: the work is counted, and the reason is not convergence at 3 iterations
  single = ProxNewton(inner = CDSolver(order = :cyclic, momentum = false, relative = false, tol = 1e-11, maxpasses = 1),
                      maxiter = 3, tol = 1e-12)
  b = copy(b0)
  r = solve!(b, f, g, single)
  @test !r.converged && r.passes >= r.iterations && r.passes <= r.iterations + 1
  @test (r.stop_reason === :maxiter) == (r.iterations == 3)
  check_result(r, b, X, y, λ, wts; converged = false)
  # a zero change tolerance spends the whole allowance of the weighted model in each iteration, and still converges
  spend = ProxNewton(inner = CDSolver(order = :cyclic, momentum = false, relative = false, tol = 0.0, maxpasses = 40),
                     maxiter = 200, tol = 1e-8)
  b = copy(b0)
  r = solve!(b, f, g, spend)
  check_result(r, b, X, y, λ, wts)
  @test r.iterations > 0 && r.passes >= 30 * r.iterations
  # the inner tolerance only sets the first threshold of each model: loose and tight values reach the same fit
  fits = map((1e-2, 1e-6, 1e-11)) do inner_tol
    method = ProxNewton(inner = CDSolver(order = :cyclic, momentum = false, relative = false, tol = inner_tol,
                                         maxpasses = 2000), maxiter = 300, tol = 1e-9)
    b = copy(b0)
    r = solve!(b, f, g, method)
    check_result(r, b, X, y, λ, wts)
    b
  end
  @test norm(fits[1] - fits[3], Inf) <= 1e-6 && norm(fits[2] - fits[3], Inf) <= 1e-6
  # a cyclic CDSolver with its default (relative) settings is accepted and converges
  b = copy(b0)
  r = solve!(b, f, g, ProxNewton(inner = CDSolver(order = :cyclic), tol = 1e-8, maxiter = 300))
  check_result(r, b, X, y, λ, wts)
end

@testset "penalty weights: unit weights, a zero weight on a slope and a very large weight" begin
  X, y = logistic_data(160, 10; seed = 7)
  n, k = size(X)
  level = 0.2 * norm(X' * (0.5 .- y), Inf)
  b1, b2 = zeros(k), zeros(k)
  r1 = solve!(b1, LogisticLoss(y, X), NormL1(level), ProxNewton(tol = 1e-9))
  r2 = solve!(b2, LogisticLoss(y, X), NormL1(level, ones(k)), ProxNewton(tol = 1e-9))
  check_result(r1, b1, X, y, level)
  check_result(r2, b2, X, y, level, ones(k))
  @test norm(b1 - b2, Inf) <= 1e-6
  @test r1.minimum ≈ r2.minimum rtol = 1e-10
  # an unpenalized slope (weight 0) and a coordinate with a weight so large that it stays at zero
  X, y, λ, _, b0 = problem(200, 7; seed = 8, level = 0.3)
  k = size(X, 2)
  w = [0.0; ones(k - 1)]
  w[4] = 0.0
  w[3] = 1e6
  Xc, yc, wc = copy(X), copy(y), copy(w)
  b = copy(b0)
  r = solve!(b, LogisticLoss(y, X), NormL1(λ, w), ProxNewton(tol = 1e-9))
  check_result(r, b, X, y, λ, w)
  @test b[3] == 0.0
  @test b[4] != 0.0
  G = oracle(X, y, b).gradient
  @test abs(G[4]) <= 1e-9 + 10 * rounding_bound(X, b)                      # the unpenalized slope has a zero score
  @test X == Xc && y == yc && w == wc
  # all coefficients unpenalized on identifiable data, with a zero level and positive weights
  X, y = logistic_data(150, 3; seed = 19)
  k = size(X, 2)
  b = zeros(k)
  r = solve!(b, LogisticLoss(y, X), NormL1(0.0, ones(k)), ProxNewton(tol = 1e-9))
  check_result(r, b, X, y, 0.0, ones(k))
end

@testset "high leverage: a correctly classified row with a small curvature" begin
  # y = (0, 1, 1) at x = (-1, 1, 50) with an unpenalized intercept and the slope penalty 0.1: the minimizer has the
  # intercept 0 and the slope log(19), where the two inner rows have the residual 1/20 and the third has none. The
  # fixed bound gives the slope a curvature about 6600 times the true one, which the weighted model avoids.
  X = [1.0 -1.0; 1.0 1.0; 1.0 50.0]
  y = [0.0, 1.0, 1.0]
  b = [log(2.0), 0.0]
  r = solve!(b, LogisticLoss(y, X), NormL1(0.1, [0.0, 1.0]), ProxNewton(tol = 1e-9))
  check_result(r, b, X, y, 0.1, [0.0, 1.0])
  @test b[1] ≈ 0.0 atol = 1e-6
  @test b[2] ≈ log(19) atol = 1e-6
  @test r.iterations <= 60
end

@testset "extreme logits at the start: saturated rows on both sides of their labels" begin
  # logits (0, 400, -400, 800) with y = (0, 0, 1, 1): two rows are wrong by hundreds of units (they take the fixed row
  # weight), one is right by far (it keeps its tiny weight), and the first row supplies the curvature
  X = [1.0 0.0; 1.0 1.0; 1.0 -1.0; 1.0 2.0]
  y = [0.0, 0.0, 1.0, 1.0]
  w = [0.0, 1.0]
  b = [0.0, 400.0]
  F0 = independent(X, y, b, 0.5, w).objective
  r = solve!(b, LogisticLoss(y, X), NormL1(0.5, w), ProxNewton(tol = 1e-8, maxiter = 5000))
  @test all(isfinite, b) && isfinite(r.minimum) && isfinite(r.kkt)
  @test r.minimum < F0
  check_result(r, b, X, y, 0.5, w)
end

@testset "seeded problems of three shapes: the weighted model, the fixed model alone and the objective" begin
  for (n, p) in ((200, 50), (2000, 200), (100, 600))
    rng = MersenneTwister(447 + n + p)
    X = hcat(ones(n), randn(rng, n, p - 1))
    signal = 0.2 .+ 1.25 .* X[:, 2] .- 0.75 .* X[:, 3]
    y = Float64.(rand(rng, n) .< inv.(1 .+ exp.(-signal)))
    ȳ = sum(y) / n
    λ = 0.25 * norm(X[:, 2:end]' * (ȳ .- y), Inf)
    w = [0.0; ones(p - 1)]
    b0 = [log(ȳ / (1 - ȳ)); zeros(p - 1)]
    f, g = LogisticLoss(y, X), NormL1(λ, w)
    F0 = independent(X, y, b0, λ, w).objective
    tol = 1e-6
    # the weighted model with the fixed fallback
    b = copy(b0)
    r = solve!(b, f, g, ProxNewton(tol = tol, maxiter = 200))
    ind = check_result(r, b, X, y, λ, w)
    @test ind.objective < F0
    # the fixed model alone, through the same search: it also reaches the tolerance, which needs the grouped slope
    # and the score test of a near tie where the objective cannot decide
    method = ProxNewton(tol = tol, maxiter = 2000)
    wk = PS._pn_workspace(copy(b0), f, g, method)
    steps = 0
    while wk.rho > tol && steps < 2000
      PS._pn_step!(wk, method, (:fixed,)) || break
      steps += 1
    end
    @test wk.rho <= tol
    indf = independent(X, y, wk.b, λ, w)
    @test indf.score <= tol + 10 * rounding_bound(X, wk.b) + 1e-12
    @test abs(indf.objective - ind.objective) <= 1e-8 * ind.objective
  end
end

@testset "a one-class sample with an unpenalized intercept has no minimizer" begin
  X, y = ones(5, 1), ones(5)
  for g in (NormL1(0.0), NormL1(2.0, [0.0]))
    b = [0.0]
    r = solve!(b, LogisticLoss(y, X), g, ProxNewton())
    @test r.minimizer === b && isfinite(b[1]) && b[1] > 0 && isfinite(r.minimum) && isfinite(r.kkt)
    @test r.minimum < 5 * log(2)
    @test r.stop_reason in (:converged, :maxiter, :stalled)
    ind = independent(X, y, b, g.λ0, g.w)
    # a small residual at a finite point is what is reported; neither the outcome nor a minimizer is required
    r.converged && @test ind.score <= r.tolerance + 1e-12
  end
end

@testset "underflowing adaptive column takes the fixed model" begin
  X = [1.0 1.0; 1.0 0.0; 1.0 0.0]
  y = [1.0, 1.0, 0.0]
  b = [0.0, 800.0]
  f, g = LogisticLoss(y, X), NormL1(0.1)
  method = ProxNewton(maxiter = 1)
  w = PS._pn_workspace(b, f, g, method)
  @test !PS._pn_adaptive_model!(w.A, w.resp, w.rows, w.X, w.eta, w.d)
  @test 0 < w.A[1, 2] && iszero(abs2(w.A[1, 2]))
  start = independent(X, y, b, g.λ0)
  r = solve!(b, f, g, method)
  ref = independent(X, y, b, g.λ0)
  @test r.iterations == 1 && r.passes > 0
  @test r.stop_reason === :maxiter && !r.converged
  @test ref.objective < start.objective
  @test r.minimum ≈ ref.objective
  @test r.kkt ≈ ref.score
end

@testset "numerical exceptions restore the caller's coefficients and leave the inputs alone" begin
  # This design's column underflows in both the adaptive and fixed models.
  X, y = fill(1e-170, 5, 1), ones(5)
  Xc, yc = copy(X), copy(y)
  x = [1.0]
  err = try
    solve!(x, LogisticLoss(y, X), NormL1(1.0), ProxNewton())
    nothing
  catch e
    e
  end
  @test err isa ArgumentError && occursin("curvature", sprint(showerror, err))
  @test x == [1.0] && X == Xc && y == yc
  # a coordinate curvature that overflows
  X = [1e200 1.0; 1e200 -1.0; 1e200 2.0]
  y = [0.0, 1.0, 1.0]
  Xc, yc = copy(X), copy(y)
  x = zeros(2)
  err = try
    solve!(x, LogisticLoss(y, X), NormL1(1.0), ProxNewton())
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
      solve!(x, LogisticLoss(y1, X1), NormL1(1.0), ProxNewton())
      nothing
    catch e
      e
    end
    @test err isa ArgumentError && occursin(message, sprint(showerror, err))
    @test x == start
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

@testset "refusals before any write: inputs outside the scope" begin
  X, y = logistic_data(40, 3; seed = 12)
  n, k = size(X)
  f = LogisticLoss(y, X)
  w = [0.0, 1.0, 1.0, 1.0]
  g = NormL1(1.0, w)
  pn = ProxNewton()
  start = [0.1, -0.2, 0.3, 0.0]
  groups = [[1, 2], [3, 4]]
  row = reshape(copy(start), 1, 4)
  Xsq, ysq = X[1:4, :], [0.0, 1.0, 0.0, 1.0]
  fsq = LogisticLoss(ysq, Xsq)
  wv = copy(w)
  mutated(change!) = (Xc = copy(X); yc = copy(y); fc = LogisticLoss(yc, Xc); change!(Xc, yc); fc)
  reweighted(v) = (wm = copy(w); gm = NormL1(1.0, wm); wm[2] = v; gm)
  cases = [
    # losses other than the raw logistic loss
    (copy(start), LeastSquaresLoss(y, X), g, pn, ArgumentError, "ProxNewton supports only the raw LogisticLoss"),
    (copy(start), (1 / n) * LeastSquaresLoss(y, X), g, pn, ArgumentError, "ProxNewton supports only the raw LogisticLoss"),
    (copy(start), (1 / n) * f, g, pn, ArgumentError, "Scaled(LogisticLoss) is not supported"),
    # the loss and the arrays
    (Float32.(start), LogisticLoss(Float32.(y), Float32.(X)), NormL1(1f0, Float32.(w)), pn, ArgumentError,
     "X::Matrix{Float64} and y::Vector{Float64}"),
    (copy(start), LogisticLoss(y, sparse(X)), g, pn, ArgumentError, "X::Matrix{Float64}"),
    (copy(start), LogisticLoss(y, view(X, :, 1:k)), g, pn, ArgumentError, "X::Matrix{Float64}"),
    (copy(start), LogisticLoss(view(y, 1:n), X), g, pn, ArgumentError, "y::Vector{Float64}"),
    (Float32.(start), f, NormL1(1f0, Float32.(w)), pn, ArgumentError, "x to be a dense Vector{Float64}"),
    (view(copy(start), 1:k), f, g, pn, ArgumentError, "x to be a dense Vector{Float64}"),
    (SparseIterate(copy(start)), f, g, pn, ArgumentError, "x to be a dense Vector{Float64}"),
    (BlockIterate(copy(start), groups), f, GroupNormL2(1.0, groups), pn, ArgumentError, "x to be a dense Vector{Float64}"),
    ([1.0 0.1; 0.1 1.0], f, NormL1(1.0), pn, ArgumentError, "x to be a dense Vector{Float64}"),
    (copy(start), LogisticLoss(y, X; weights = ones(n)), g, pn, ArgumentError, "observation weights or an offset"),
    (copy(start), LogisticLoss(y, X; offset = zeros(n)), g, pn, ArgumentError, "observation weights or an offset"),
    # shapes
    (zeros(k + 1), f, NormL1(1.0), pn, DimensionMismatch, "x/y dimensions do not match X"),
    (zeros(k - 1), f, NormL1(1.0), pn, DimensionMismatch, "x/y dimensions do not match X"),
    (zeros(k), LogisticLoss(zeros(0), zeros(0, k)), NormL1(1.0), pn, DimensionMismatch, "positive row and column counts"),
    (copy(start), mutated((Xc, yc) -> resize!(yc, n - 1)), g, pn, DimensionMismatch, "x/y dimensions do not match X"),
    # penalties other than NormL1, then the NormL1 rules
    (copy(start), f, ElasticNet(1.0, 1.0), pn, ArgumentError, "only NormL1"),
    (copy(start), f, NormLinf(1.0), pn, ArgumentError, "only NormL1"),
    (copy(start), f, GroupNormL2(1.0, groups), pn, ArgumentError, "only NormL1"),
    (copy(start), f, NormL1Nonneg(1.0), pn, ArgumentError, "only NormL1"),
    (abs.(start), f, IndNonnegative(), pn, ArgumentError, "only NormL1"),
    (copy(start), f, IndBox(-1.0, 1.0), pn, ArgumentError, "only NormL1"),
    (copy(start), f, SqrNormL2(1.0), pn, ArgumentError, "only NormL1"),
    (copy(start), f, 2 * g, pn, ArgumentError, "only NormL1"),
    (copy(start), f, NormL1(1.0, [0.0, 1.0, 1.0]), pn, DimensionMismatch, "3 weights"),
    (copy(start), f, NormL1(1.0, Float32.(w)), pn, ArgumentError, "penalty weights must be a Vector{Float64}"),
    (copy(start), f, NormL1(1e300, [0.0, 1e10, 1.0, 1.0]), pn, ArgumentError, "overflows"),
    (copy(start), f, reweighted(-1.0), pn, ArgumentError, "penalty weight 2 must be finite and nonnegative"),
    (copy(start), f, reweighted(NaN), pn, ArgumentError, "penalty weight 2 must be finite and nonnegative"),
    # aliasing
    (wv, f, NormL1(1.0, wv), pn, ArgumentError, "must not alias the penalty weights"),
    (vec(row), LogisticLoss([1.0], row), g, pn, ArgumentError, "must not alias borrowed X or y"),
    (ysq, fsq, g, pn, ArgumentError, "must not alias borrowed X or y"),
    (fsq.tmp, fsq, g, pn, ArgumentError, "scratch of the loss"),
    # values
    ([0.1, NaN, 0.3, 0.0], f, g, pn, ArgumentError, "finite"),
    ([0.1, Inf, 0.3, 0.0], f, g, pn, ArgumentError, "finite"),
    (copy(start), mutated((Xc, yc) -> (Xc[2, 3] = Inf)), g, pn, ArgumentError, "finite"),
    (copy(start), mutated((Xc, yc) -> (yc[3] = 0.5)), g, pn, ArgumentError, "LogisticLoss with ProxNewton needs a binary response"),
    (copy(start), mutated((Xc, yc) -> (yc[3] = NaN)), g, pn, ArgumentError, "LogisticLoss with ProxNewton needs a binary response"),
    (copy(start), mutated((Xc, yc) -> (yc[3] = 2.0)), g, pn, ArgumentError, "LogisticLoss with ProxNewton needs a binary response"),
    (copy(start), LogisticLoss(fill(0.25, n), X), g, pn, ArgumentError, "LogisticLoss with ProxNewton needs a binary response"),
    # the other solvers name ProxNewton among the solvers of the loss
    (copy(start), f, g, AccProxGradDescent(), ArgumentError, "supported only by ProximalGradientDescent and ProxNewton"),
    (copy(start), f, g, CDSolver(), ArgumentError, "ProximalGradientDescent and ProxNewton"),
  ]
  for (i, (x, loss, penalty, method, E, message)) in enumerate(cases)
    err, unchanged = refusal(x, loss, penalty, method)
    text = err === nothing ? "" : sprint(showerror, err)
    @test (i, err isa E) == (i, true)
    @test (i, occursin(message, text)) == (i, true)
    @test (i, unchanged) == (i, true)
  end
  # keywords and extra arguments are refused before the gate
  @test_throws ArgumentError("unsupported solve! keywords: foo") solve!(copy(start), f, g, pn; foo = 1)
  @test_throws ArgumentError solve!(copy(start), f, g, pn, ProximalOptions())
  # the same inputs with the binary data are accepted
  b = copy(start)
  @test solve!(b, f, g, pn).minimizer === b
  # PGD still accepts the loss, and its binary-response refusal keeps its text
  err, _ = refusal(copy(start), mutated((Xc, yc) -> (yc[3] = 0.5)), g, ProximalGradientDescent())
  @test err isa ArgumentError && occursin("LogisticLoss with ProximalGradientDescent needs a binary response", sprint(showerror, err))
end

end
