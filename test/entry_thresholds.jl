module EntryThresholds
# Per-entry stopping thresholds of PGD and APG for weighted penalties (#464, STOP-03, STOP-05). A proposed stop
# with NormL1(λ0, w) is kept only if every entry score sᵢ is below τ max(cᵢ, λmax), cᵢ = T(λ0) wᵢ, and with
# GroupNormL2 only if every group score is below τ max(cₖ, Λ); before #464 every entry was compared with the single
# threshold τ max(maxᵢ cᵢ, λmax), so one large coefficient raised the threshold of entry i by the factor
# maxⱼ cⱼ / max(cᵢ, λmax).
#
# Independent references, computed here in 256-bit BigFloat from the stored data and the returned coefficients,
# without ProximalBase's kkt_violation or the solvers' helpers: the gradient, the per-entry (per-group) minimal-norm
# KKT scores, the objective, analytic minimizers where they exist, and λmax. Each trajectory solve that reports
# converged = true is checked against every entry's own bound, with a first-order allowance for the rounding of the
# computed gradient (`check_entries`); the fixtures from #464 also check accuracy against analytic minimizers.
# The stop rule itself is checked at fixed points against a rule formed here from ProximalBase's per-entry scores
# (`verdicts`), and ordinary controls check that the earlier single threshold still decides whenever no
# coefficient exceeds λmax.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers
const PGD = ProximalGradientDescent
const APG = AccProxGradDescent
const METHODS = (PGD(), APG())

big256(f) = setprecision(f, BigFloat, 256)
τof(::Type{T}, o = ProximalOptions()) where T = T(max(o.gradtol, 64 * Float64(eps(T))))
sigmoid(t) = t >= 0 ? inv(1 + exp(-t)) : (e = exp(t); e / (1 + e))
softplus(t) = t > 0 ? t + log1p(exp(-t)) : log1p(exp(t))

# ---------------------------------------------------------------------------------------------------------
# BigFloat oracle: least squares ½α‖y - Xb‖² or the raw logistic loss, with ℓ1 coefficients c (or group
# coefficients c with groups G)
# ---------------------------------------------------------------------------------------------------------
gradient(loss, α, X, y, b) = loss === :ls ? big(α) * (big.(X)' * (big.(X) * b - big.(y))) :
  big.(X)' * (sigmoid.(big.(X) * b) .- big.(y))
smooth(loss, α, X, y, b) = loss === :ls ? big(α) * sum(abs2, big.(y) - big.(X) * b) / 2 :
  (η = big.(X) * b; sum(softplus.(η) .- big.(y) .* η))
coefficients(λ0, w) = big(λ0) .* big.(w)           # the exact products of the stored level and weights

l1scores(g, c, b) = [iszero(b[j]) ? max(abs(g[j]) - c[j], big(0)) : abs(g[j] + c[j] * sign(b[j])) for j in eachindex(b)]
groupscores(g, c, G, b) = [iszero(norm(b[Gk])) ? max(norm(g[Gk]) - c[k], big(0)) :
  norm(g[Gk] + c[k] * b[Gk] / norm(b[Gk])) for (k, Gk) in enumerate(G)]

# The rounding allowance of the computed gradient entry j, |α| γ |Xⱼ|ᵀ(|X||x| + |y|) with γ = 4(n + p + 4) u (least
# squares), and for the logistic loss γ |Xⱼ|ᵀ(2 + |X||x|/4): |σ| + |y| ≤ 2, and the rounding of the predictor passed
# through σ, whose Lipschitz constant is 1/4. A first-order estimate with slack (the group norms add a block-size
# factor it does not model), not a bound for the BLAS kernel in use.
function allowance(loss, α, X, y, x, ::Type{T}) where T
  A, xb = abs.(big.(X)), abs.(big.(x))
  γ = 4 * (size(X, 1) + size(X, 2) + 4) * big(eps(T)) / 2
  r = loss === :ls ? A * xb + abs.(big.(y)) : 2 .+ (A * xb) ./ 4
  abs(big(α)) * γ * (A' * r)
end

# Every entry (group) of a converged solve satisfies its own bound τ max(cⱼ, λmax)(1 + 4 eps) + allowance (+ the
# rounding of λmax): the stop rule of #464 recomputed in BigFloat. Returns the largest ratio of a score to its bound.
function check_entries(loss, α, X, y, λ0, w, x, ::Type{T}; groups = nothing, o = ProximalOptions()) where T
  big256() do
    b = big.(x)
    g = gradient(loss, α, X, y, b)
    g0 = gradient(loss, α, X, y, zeros(BigFloat, length(b)))
    c = coefficients(λ0, w)
    e = allowance(loss, α, X, y, x, T)
    e0 = allowance(loss, α, X, y, zero(x), T)
    τ = big(τof(T, o))
    if groups === nothing
      λmax = maximum(abs, g0)
      bound = τ .* max.(c, λmax + maximum(e0)) .* (1 + 4 * big(eps(T))) .+ e .+ big(eps(T)) .* (abs.(g) .+ c)
      s = l1scores(g, c, b)
    else
      λmax = maximum(norm(g0[Gk]) for Gk in groups)
      bound = [τ * max(c[k], λmax + norm(e0)) * (1 + 4 * big(eps(T))) + norm(e[Gk]) + big(eps(T)) * (norm(g[Gk]) + c[k])
               for (k, Gk) in enumerate(groups)]
      s = groupscores(g, c, groups, b)
    end
    Float64(maximum(s ./ bound))
  end
end

objective_excess(loss, α, X, y, c, x, xstar) = big256() do
  F(b) = smooth(loss, α, X, y, b) + sum(c .* abs.(b))
  Fs = F(xstar)
  Float64((F(big.(x)) - Fs) / abs(Fs))
end

# The rule formed here from ProximalBase's per-entry scores at a fixed point, and the solver's verdict there.
function verdicts(method, f, g, x, ::Type{T}, o = ProximalOptions()) where T
  state = PS.initial_state(method, o, f, g, copy(x))
  λmax = PS._lambda_max!(state, PS._scale_norm(g))
  grad = copy(PS._gradient_at_x!(state, f))
  verdict = PS._stationary!(state, f, g, o)
  τ = τof(T, o)
  if g isa GroupNormL2
    c = [g.λ0 * g.w[k] for k in eachindex(g.groups)]
    s = [kkt_violation(g, grad, state.x, first(Gk)) for Gk in g.groups]
  else
    c = g.w === nothing ? fill(T(g.λ0), length(x)) : T(g.λ0) .* g.w
    gT = g.w === nothing ? NormL1(T(g.λ0)) : NormL1(T(g.λ0), g.w)
    s = [kkt_violation(gT, grad, state.x, i) for i in eachindex(x)]
  end
  rule = isfinite(λmax) && all(i -> (t = τ * max(c[i], λmax); t >= floatmin(T) && isfinite(s[i]) && s[i] < t), eachindex(c))
  single = (S = max(maximum(c), λmax); t = τ * S; isfinite(S) && t >= floatmin(T) && isfinite(maximum(s)) &&
            max(maximum(s), zero(T)) < t)
  (; verdict, rule, single, λmax, cmax = maximum(c))
end

# ---------------------------------------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------------------------------------
# #464: a constant free column and an all-zero column with an extreme weight; the minimizer of least squares on
# the free columns, the excluded coefficient 0
function b4_ls(::Type{T}, nfree) where T
  sx, λ = T === Float64 ? (1e150, 1e300) : (1f10, 1f30)
  y = T[0, 1, 1, 1, 1]
  F = nfree == 1 ? fill(sx, 5, 1) : [fill(sx, 5) sx .* T.(1:5)]
  X = hcat(F, zeros(T, 5))
  w = vcat(zeros(T, nfree), one(T))
  xstar = big256() do
    A = big.(F)
    vcat((A' * A) \ (A' * big.(y)), big(0))
  end
  X, y, T(λ), w, xstar
end

function design(::Type{T}, n, p; ρ = 0.5, seed = 1) where T
  rng = Xoshiro(seed)
  Z = randn(rng, n, p)
  X = Z * cholesky([ρ^abs(i - j) for i in 1:p, j in 1:p]).U
  β = zeros(p); β[1:4] .= [2.0, -1.5, 1.0, 0.5]
  T.(X), T.(X * β + 0.5 .* randn(rng, n))
end

# ---------------------------------------------------------------------------------------------------------
@testset "the #464 least-squares fixtures: no false stop, accurate solutions" begin
  for T in (Float64, Float32), nfree in (1, 2), method in METHODS
    X, y, λ, w, xstar = b4_ls(T, nfree)
    x = zeros(T, size(X, 2))
    r = solve!(x, LeastSquaresLoss(y, X), NormL1(λ, w), method)
    # with the two correlated free columns a solve can end by an objective increase (Float32) or reach maxiter (seen
    # with Float64 on another OpenBLAS kernel) without a stop, at a point as accurate as the bound below
    nfree == 1 && @test r.converged
    @test x[end] == 0
    @test !r.converged || check_entries(:ls, 1, X, y, λ, w, x, T) <= 1
    # the free coefficients are those of least squares on the free columns, to the accuracy of the default options
    @test objective_excess(:ls, 1, X, y, coefficients(λ, w), x, xstar) <= (T === Float64 ? 1e-6 : 1e-4)
    # at the midpoint between zero and the minimizer the single threshold τ maxᵢ cᵢ accepts, and the free entries'
    # own thresholds τ λmax reject
    v = verdicts(method, LeastSquaresLoss(y, X), NormL1(λ, w), T.(xstar ./ 2), T)
    @test v.single && !v.rule && !v.verdict
  end
end

@testset "the #464 logistic fixture: the analytic intercept" begin
  X, y = [fill(1e150, 5) zeros(5)], [0.0, 1.0, 1.0, 1.0, 1.0]
  b = zeros(2)
  r = solve!(b, LogisticLoss(y, X), NormL1(1e300, [0.0, 1.0]), PGD())
  @test r.converged
  @test b[2] == 0
  η = X[1, 1] * b[1]                                     # the predictor; the minimizer has η = log 4
  @test abs(η - log(4)) <= 1e-4 * log(4)
  @test check_entries(:logistic, 1, X, y, 1e300, [0.0, 1.0], b, Float64) <= 1
  @test objective_excess(:logistic, 1, X, y, coefficients(1e300, [0.0, 1.0]), b,
                         big256(() -> [log(big(4)) / big(1e150), big(0)])) <= 1e-8
end

@testset "an extreme weight does not loosen the other entries" begin
  # an all-zero column with weight W, or an ordinary column excluded by W; a free first coordinate; a tiny weight
  for T in (Float64, Float32), method in METHODS, kind in (:zero_column, :excluded, :free, :tiny)
    X0, y = design(T, 50, 10)
    λ = T(0.1 * norm(Float64.(X0)' * Float64.(y), Inf))
    for W in (T(1e3), T(1e6), T === Float64 ? 1e100 : 1f30)
      X = kind === :zero_column ? hcat(X0, zeros(T, 50)) : X0
      w = kind === :zero_column ? vcat(ones(T, 10), W) :
          kind === :excluded ? vcat(ones(T, 9), W) :
          kind === :free ? vcat(zero(T), ones(T, 8), W) : vcat(T(1e-6), ones(T, 8), W)
      x = zeros(T, size(X, 2))
      r = solve!(x, LeastSquaresLoss(y, X), NormL1(λ, w), method)
      @test !r.converged || check_entries(:ls, 1, X, y, λ, w, x, T) <= 1
      @test x[end] == 0
      # the coefficient that W excludes stays at zero, so the solution is that of the problem without it; the
      # Float64 solves reach the stop (Float32 PGD can end by an objective increase, as without the column)
      T === Float64 && @test r.converged
    end
  end
end

@testset "logistic: free intercept with an excluded or zero column" begin
  rng = Xoshiro(7)
  Xl = randn(rng, 200, 8)
  y = Float64.(rand(rng, 200) .< sigmoid.(Xl * [1.0, -1.0, 0.5, 0, 0, 0, 0, 0] .+ 0.3))
  Xi = hcat(ones(200), Xl)
  λ = 0.05 * norm(Xi' * (0.5 .- y), Inf)
  for W in (1e3, 1e100), X in (Xi, hcat(Xi, zeros(200)))
    w = size(X, 2) == 9 ? vcat(0.0, ones(7), W) : vcat(0.0, ones(8), W)
    b = zeros(size(X, 2))
    r = solve!(b, LogisticLoss(y, X), NormL1(λ, w), PGD())
    @test r.converged
    @test b[end] == 0
    @test check_entries(:logistic, 1, X, y, λ, w, b, Float64) <= 1
  end
end

@testset "an active coordinate with a coefficient far above λmax" begin
  # X = [2.5 1e6; 0 1], y = [1, -1e6], NormL1(999999.27, [0, 1]): ∇f(0) = (-2.5, 0), so λmax = 2.5, and the
  # minimizer has x₂ = c₂ - 1e6 = -0.73 active and x₁ = (1 - 1e6 x₂)/2.5 = 292000.4. At a near-optimal point the
  # score of x₂ is a cancellation at the scale 1e6 that rounds to a few units; it is judged against τ c₂ ≈ 10, not
  # against τ λmax = 2.5e-5, while the free x₁ is held to τ λmax.
  X, y, λ0, w = [2.5 1e6; 0.0 1.0], [1.0, -1e6], 999999.27, [0.0, 1.0]
  f, g = LeastSquaresLoss(y, X), NormL1(λ0, w)
  xstar = big256() do
    x2 = big(λ0) - big(1e6)
    [(1 - big(1e6) * x2) / big(2.5), x2]
  end
  c = coefficients(λ0, w)
  # the point PGD accepts after its second iteration from [292000.4, -0.73]: its computed score of x₂ is 9.31
  xa = [292000.4, -0.7299999999906868]
  for method in METHODS
    v = verdicts(method, f, g, xa, Float64)
    @test v.verdict == v.rule
    @test v.verdict                               # held to τ max(c₂, λmax), not to τ λmax
    @test v.cmax > v.λmax
  end
  @test objective_excess(:ls, 1, X, y, c, xa, xstar) <= 1e-20
  @test check_entries(:ls, 1, X, y, λ0, w, xa, Float64) <= 1
  for method in METHODS, x0 in ([292000.4, -0.73], Float64.(xstar) .* (1 .+ [1e-9, -1e-6]), zeros(2))
    x = copy(x0)
    r = solve!(x, f, g, method, ProximalOptions(maxiter = 2000))
    @test !r.converged || check_entries(:ls, 1, X, y, λ0, w, x, Float64) <= 1
    # near the minimizer the solves stop at a near-optimal point
    if !iszero(x0)
      @test r.converged
      @test objective_excess(:ls, 1, X, y, c, x, xstar) <= 1e-15
    end
  end
end

@testset "ill-conditioned designs: no false stop" begin
  # X = [1 M; 0 1], y = [1, -M], x₁ free, c₂ = M/10 (condition number about M²): before #464 the stop of a solve
  # from zero could be kept with the free coordinate far from stationary
  for (T, Ms) in ((Float64, (1e6, 1e13)), (Float32, (1f3, 1f5))), M in Ms, method in METHODS
    X, y, λ, w = T[1 M; 0 1], T[1, -M], T(M / 10), T[0, 1]
    x = zeros(T, 2)
    r = solve!(x, LeastSquaresLoss(y, X), NormL1(λ, w), method, ProximalOptions(maxiter = 500))
    @test !r.converged || check_entries(:ls, 1, X, y, λ, w, x, T) <= 1
  end
end

@testset "zero weights and zero scales" begin
  for T in (Float64, Float32), method in METHODS
    X, y = design(T, 30, 5)
    λ = T(0.1 * norm(Float64.(X)' * Float64.(y), Inf))
    # a free coordinate whose ∇f(0) entry is nearly 0 (the response is projected off its column in T): it is held to
    # τ λmax with the global λmax
    yo = y .- X[:, 1] .* (dot(X[:, 1], y) / dot(X[:, 1], X[:, 1]))
    w = T[0, 1, 1, 1, 1e6]
    x = zeros(T, 5)
    r = solve!(x, LeastSquaresLoss(yo, X), NormL1(λ, w), method)
    @test !r.converged || check_entries(:ls, 1, X, yo, λ, w, x, T) <= 1
    T === Float64 && @test r.converged
    # y = 0 with a zero weight: λmax = 0, so a zero-weight entry has a zero threshold and no stop is kept (as for
    # all-zero weights, STOP-04), although x = 0 is the minimizer
    x = zeros(T, 5)
    r = solve!(x, LeastSquaresLoss(zeros(T, 30), X), NormL1(λ, T[0, 1, 1, 1, 1]), method, ProximalOptions(maxiter = 20))
    @test !r.converged
    @test r.iteration_converged
    @test all(iszero, x)
    v = verdicts(method, LeastSquaresLoss(zeros(T, 30), X), NormL1(λ, T[0, 1, 1, 1, 1]), zeros(T, 5), T)
    @test !v.verdict && !v.rule && v.single     # the single threshold τ maxᵢ cᵢ kept it before #464
    # all weights positive with y = 0: every threshold is positive and x = 0 stops
    x = zeros(T, 5)
    r = solve!(x, LeastSquaresLoss(zeros(T, 30), X), NormL1(λ, T[1, 1, 1, 1, 1e6]), method)
    @test r.converged
    @test all(iszero, x)
  end
end

@testset "ordinary weights: the single threshold decides, and the rule matches its definition" begin
  for T in (Float64, Float32), method in METHODS
    X, y = design(T, 40, 8; seed = 3)
    lm = norm(Float64.(X)' * Float64.(y), Inf)
    wo = T.(0.5 .+ 1.5 .* rand(Xoshiro(4), 8))
    f = LeastSquaresLoss(y, X)
    pts = (zeros(T, 8), T.(0.3 .* randn(Xoshiro(5), 8)), T.(0.01 .* sin.(1:8)))
    for (λfac, w) in ((0.1, wo), (0.4, wo), (0.1, ones(T, 8)), (2.0, wo), (0.1, vcat(wo[1:7], T(1e4))), (0.1, vcat(zero(T), wo[2:8])))
      g = NormL1(T(λfac * lm), w)
      for x in pts
        v = verdicts(method, f, g, x, T)
        @test v.verdict == v.rule
        v.cmax <= v.λmax && @test v.verdict == v.single
        v.verdict && @test v.single              # never kept where the single threshold refuses
      end
      x = zeros(T, 8)
      r = solve!(x, f, g, method)
      @test !r.converged || check_entries(:ls, 1, X, y, T(λfac * lm), w, x, T) <= 1
      # the returned point of a converged solve is an accepting point of the same rule
      if r.converged
        v = verdicts(method, f, g, x, T)
        @test v.verdict && v.rule && v.single
      end
    end
    # unit weights decide exactly as the unweighted penalty
    for x in pts
      @test verdicts(method, f, NormL1(T(0.1lm), ones(T, 8)), x, T).verdict == verdicts(method, f, NormL1(T(0.1lm)), x, T).verdict
    end
  end
end

# ---------------------------------------------------------------------------------------------------------
# GroupNormL2
# ---------------------------------------------------------------------------------------------------------
function hadamard(k)
  H = ones(1, 1)
  for _ in 1:k; H = [H H; H -H]; end
  H
end

@testset "GroupNormL2: the #464 analogue and an excluded group" begin
  # singleton groups, the B4 least-squares fixture
  for T in (Float64, Float32), method in METHODS
    X, y, λ, w, xstar = b4_ls(T, 1)
    G = [1:1, 2:2]
    x = zeros(T, 2)
    r = solve!(x, LeastSquaresLoss(y, X), GroupNormL2(λ, G, w), method)
    @test r.converged
    @test check_entries(:ls, 1, X, y, λ, w, x, T; groups = G) <= 1
    @test objective_excess(:ls, 1, X, y, coefficients(λ, w), x, xstar) <= (T === Float64 ? 1e-6 : 1e-4)
  end
  # orthogonal Hadamard columns of equal norm: the minimizer is the block soft threshold of Hᵀy / 64, exactly
  H = hadamard(6)[:, 2:11]
  groups = [1:2, 3:4, 5:6, 7:8, 9:10]
  y0 = H * [2.0, -1.0, 1.0, 0.5, 0, 0, 0, 0, 0, 0] + 0.5 .* randn(Xoshiro(5), 64)
  Λ = maximum(norm((H' * y0)[Gk]) for Gk in groups)
  for T in (Float64, Float32), method in METHODS, w in (T[0, 1, 1, 1, 1e6], T[0, 1, 1, 1, 1e12], T[0.5, 1, 1.5, 2, 1])
    X, y, λ = T.(H), T.(y0), T(0.1Λ)
    xstar = big256() do
      z = big.(X)' * big.(y) ./ 64
      c = coefficients(λ, w)
      vcat([norm(z[Gk]) <= c[k] / 64 ? zeros(BigFloat, 2) : z[Gk] .* (1 - c[k] / (64 * norm(z[Gk]))) for (k, Gk) in enumerate(groups)]...)
    end
    x = zeros(T, 10)
    g = GroupNormL2(λ, groups, w)
    r = solve!(x, LeastSquaresLoss(y, X), g, method)
    # Float32 APG can end by an objective increase without a stop (seen with the bounds checks of Pkg.test on
    # Julia 1.10), at a point that meets every group bound and the accuracy below
    T === Float64 && @test r.converged
    @test !r.converged || check_entries(:ls, 1, X, y, λ, w, x, T; groups) <= 1
    @test all(iszero, x[9:10]) || w[5] < 2
    big256() do
      c = coefficients(λ, w)
      F(b) = sum(abs2, big.(y) - big.(X) * b) / 2 + sum(c[k] * norm(b[Gk]) for (k, Gk) in enumerate(groups))
      @test Float64((F(big.(x)) - F(xstar)) / F(xstar)) <= (T === Float64 ? 1e-8 : 1e-5)
    end
    # the rule at fixed points
    for p in (zeros(T, 10), x, T.(0.1 .* sin.(1:10)))
      v = verdicts(method, LeastSquaresLoss(y, X), g, p, T)
      @test v.verdict == v.rule
      v.cmax <= v.λmax && @test v.verdict == v.single
    end
  end
end

end
