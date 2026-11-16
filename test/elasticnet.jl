module ElasticNetTests
# ElasticNet(λ1, λ2) with ProximalGradientDescent and AccProxGradDescent on the least-squares loss
# ½α‖Xb - y‖² + λ1‖b‖₁ + (λ2/2)‖b‖² (α = 1 for a raw LeastSquaresLoss, 1/n for Scaled(LS, 1/n)).
# The references are computed from the raw X, y and the levels in 256-bit BigFloat, not with the
# solvers' gradients, caches or kernels: the closed form of an orthogonal design with disjoint column
# supports, and a signed-support solve of the normal equations on a random full-rank design with the
# off-support optimality condition verified. The support and signs of the second one are taken from a
# tight Float64 solve of AccProxGradDescent, and the BigFloat solve is accepted as the minimizer only
# if its signs agree and the off-support condition holds (the second value of `reference`). `converged` is a stopping flag, not an accuracy
# certificate: accuracy comes from the references, and each `converged = true` in this file is
# checked against the independent residual with an allowance for the rounding of the computed
# gradient (`kkt_excess`). Refusals of penalties and of iterates are in test/core_contracts.jl and
# test/accelerated_pgd.jl.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

const METHODS = (ProximalGradientDescent(), AccProxGradDescent())
const DEFAULT = ProximalOptions()
const STRICT = ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11)
const TIGHT = ProximalOptions(maxiter = 20_000, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-11)

lossof(α, y, X) = isone(α) ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)

# the largest |α Xᵀy|, in BigFloat from the T data as given
lambdamax(X, y, α) = setprecision(BigFloat, 256) do
  Float64(maximum(abs, big(α) * (big.(X)' * big.(y))))
end

# The pieces of the independent residual at x, from the T data as given, in BigFloat (precision is
# scoped): G = ‖·‖∞ of the minimal-norm element of ∇f(x) + λ2 x + λ1 ∂‖x‖₁ (|gᵢ| - λ1 clipped at 0
# where xᵢ = 0, |gᵢ + λ2 xᵢ + λ1 sign xᵢ| elsewhere), S = max(λ1, λmax), and the first-order
# rounding allowances eG and eS of the computed gradient and of the computed λmax. With u = eps(T)
# (twice the unit roundoff, as slack), the standard dot-product bounds for d̂ = fl(X x) - y and
# ĝ = α fl(Xᵀ d̂) give, with the exact residual d = X x - y,
#   eG = maxᵢ α Σⱼ |Xⱼᵢ| (e_j + (n+1) u (|d_j| + e_j)) + u (|gᵢ| + λ1 + λ2 |xᵢ|),
#   e_j = (p+1) u (Σₖ |Xⱼₖ||xₖ| + |y_j|),    eS = α (n+1) u maxᵢ Σⱼ |Xⱼᵢ||y_j|.
# They are estimates under that error model, not guarantees for the BLAS kernel in use.
function kktparts(X, y, α, λ1, λ2, x, ::Type{T}) where T
  setprecision(BigFloat, 256) do
    Xb, yb, xb, a, l1, l2 = big.(X), big.(y), big.(x), big(α), big(λ1), big(λ2)
    n, p = size(Xb)
    u = big(eps(T))
    d = Xb * xb - yb
    g = a .* (Xb' * d)
    G = maximum(j -> iszero(xb[j]) ? max(abs(g[j]) - l1, zero(l1)) :
                                     abs(g[j] + l2 * xb[j] + l1 * sign(xb[j])), eachindex(xb))
    S = max(l1, maximum(abs, a .* (Xb' * yb)))
    absX = abs.(Xb)
    e = (p + 1) * u .* (absX * abs.(xb) + abs.(yb))
    eG = maximum(a .* (absX' * (e .+ (n + 1) * u .* (abs.(d) .+ e))) .+ u .* (abs.(g) .+ l1 .+ l2 .* abs.(xb)))
    eS = a * (n + 1) * u * maximum(absX' * abs.(yb))
    Float64.((G, S, eG, eS))
  end
end

# (G - eG - τ (1 + 4u) (S + eS)) / S, at most 0 when the independent residual is within the solver's
# threshold τ S plus the allowances; Inf for S = 0
function kkt_excess(X, y, α, λ1, λ2, x, τ, ::Type{T}) where T
  G, S, eG, eS = kktparts(X, y, α, λ1, λ2, x, T)
  iszero(S) && return Inf
  (G - eG - τ * (1 + 4 * Float64(eps(T))) * (S + eS)) / S
end

# G / S, the independent normalized residual
function kkt_rel(X, y, α, λ1, λ2, x, ::Type{T}) where T
  G, S, _, _ = kktparts(X, y, α, λ1, λ2, x, T)
  G / S
end

# Counts of the solves of this file through `run` and of those that reported converged = true
const NRUN = Ref(0)
const NCONV = Ref(0)

# The solve of x0 with the penalty g. The levels of the reference are the T values the solver uses.
# A converged = true is checked against the independent residual (kkt_excess). Returns (x, result).
function run(method, X, y, α, g, x0, options)
  T = eltype(X)
  x = copy(x0)
  r = solve!(x, lossof(α, y, X), g, method, options)
  NRUN[] += 1
  if r.converged
    NCONV[] += 1
    τ = max(options.gradtol, 64 * Float64(eps(T)))
    @test kkt_excess(X, y, α, T(g.λ1), T(g.λ2), x, τ, T) <= 0
  end
  x, r
end

# The BigFloat minimizer β of ½α‖Xb - y‖² + λ1‖b‖₁ + (λ2/2)‖b‖² for a full-rank X (or λ2 > 0): the
# support and signs come from a tight Float64 solve, β solves (α X_SᵀX_S + λ2 I) β_S = α X_Sᵀy - λ1 s,
# and the second return value says whether β is the minimizer: the signs of β_S agree with s and
# |∇f(β)ᵢ| ≤ λ1 off the support (the optimality condition, in BigFloat).
function reference(X, y, α, λ1, λ2)
  Xf, yf = Float64.(X), Float64.(y)
  b0 = zeros(size(X, 2))
  solve!(b0, lossof(Float64(α), yf, Xf), ElasticNet(Float64(λ1), Float64(λ2)), AccProxGradDescent(), TIGHT)
  setprecision(BigFloat, 256) do
    Xb, yb, a, l1, l2 = big.(X), big.(y), big(α), big(λ1), big(λ2)
    p = size(X, 2)
    S = findall(!iszero, b0)
    s = sign.(b0[S])
    β = zeros(BigFloat, p)
    if !isempty(S)
      XS = Xb[:, S]
      β[S] = (a * XS' * XS + l2 * I) \ (a * XS' * yb - l1 * s)
    end
    g = a .* (Xb' * (Xb * β - yb))
    ok = all(j -> sign(β[j]) == s[findfirst(==(j), S)], S) &&
         all(j -> abs(g[j]) <= l1, setdiff(1:p, S))
    β, ok
  end
end

# (‖x - β‖∞, ‖β‖∞) as Float64
function distance(x, β)
  setprecision(BigFloat, 256) do
    Float64.((maximum(abs, big.(x) .- β), maximum(abs, β)))
  end
end

# (F(x) - F(β), F(β)) as Float64, F from the raw data
function objective_gap(X, y, α, λ1, λ2, x, β)
  setprecision(BigFloat, 256) do
    Xb, yb, a, l1, l2 = big.(X), big.(y), big(α), big(λ1), big(λ2)
    F(b) = a * sum(abs2, yb - Xb * b) / 2 + l1 * sum(abs, b) + l2 / 2 * sum(abs2, b)
    Float64.((F(big.(x)) - F(β), F(β)))
  end
end

# Tolerances for the solves of STRICT on the designs below, relative to ‖β‖∞, to F(β) and to S, in
# Float64 and Float32. They are of the order of 10³ times the accuracy the solves reach on these
# well-conditioned designs (n = 40, p = 10) and are far below the error of a solve that ignores λ2
# (of the order of λ2 / (α ‖X_j‖²), 10% and more for the levels used here).
xtol_of(::Type{Float64}) = 1e-7
xtol_of(::Type{Float32}) = 2e-3
gaptol_of(::Type{Float64}) = 1e-12
gaptol_of(::Type{Float32}) = 1e-4
kkttol_of(::Type{Float64}) = 1e-8
kkttol_of(::Type{Float32}) = 1e-3

# the quality of x against the BigFloat minimizer β of the given penalty levels
function check_quality(label, X, y, α, λ1, λ2, x, β, ::Type{T}) where T
  dx, nβ = distance(x, β)
  gap, F = objective_gap(X, y, α, λ1, λ2, x, β)
  rel = kkt_rel(X, y, α, λ1, λ2, x, T)
  @test (label, dx <= xtol_of(T) * nβ) == (label, true)
  @test (label, -1e-30 <= gap <= gaptol_of(T) * F) == (label, true)
  @test (label, rel <= kkttol_of(T)) == (label, true)
end

function design(::Type{T}, n, p, seed) where T
  rng = Xoshiro(seed)
  X = randn(rng, T, n, p)
  β = zeros(T, p)
  β[1:4] .= T[2.0, -1.5, 1.0, 0.5]
  y = X * β + T(0.3) * randn(rng, T, n)
  X, y
end

# a design whose columns have disjoint supports, so that XᵀX is diagonal in floating point (each
# term of the product of two different columns has a zero factor, so the off-diagonal entries are 0)
function orthogonal(::Type{T}, seed) where T
  rng = Xoshiro(seed)
  X = zeros(T, 8, 4)
  for j in 1:4, i in (2j - 1, 2j)
    X[i, j] = T(1 + rand(rng)) * (rand(rng) < 0.5 ? -1 : 1)
  end
  X, randn(rng, T, 8)
end

# the minimizer for a design with diagonal XᵀX: β_j = shrink(α X_jᵀy, λ1) / (α‖X_j‖² + λ2)
function analytic(X, y, α, λ1, λ2)
  setprecision(BigFloat, 256) do
    Xb, yb, a, l1, l2 = big.(X), big.(y), big(α), big(λ1), big(λ2)
    [begin
       c = a * dot(Xb[:, j], yb)
       sign(c) * max(abs(c) - l1, 0) / (a * dot(Xb[:, j], Xb[:, j]) + l2)
     end for j in 1:size(X, 2)]
  end
end

# the bytes allocated by one call, measured inside a function so that no argument is boxed
residual_allocations(g, x, a, b) = @allocated ProximalSolvers._kkt_residual(g, x, a, b)

@testset "the residual of the stopping check for the elastic net" begin
  for T in (Float32, Float64)
    # for λ2 = 0 the 4-argument method is the 3-argument one, bit for bit, also for -0.0 and signs
    grad = T[0.3, -2, 0, 0.5, -0.0, 7, -0.25, 1]
    for x in (T[0, 1, -0.0, -2, 0.0, 3, 0, 0], T[0.0, -0.0, 0, 0, 0, 0, 0, 0], T[1, -1, 1, -1, 1, -1, 1, -1])
      for λ in (zero(T), T(0.5), T(2), T(10))
        @test ProximalSolvers._kkt_residual(grad, x, λ, zero(λ)) === ProximalSolvers._kkt_residual(grad, x, λ)
      end
    end
    # a NaN gradient entry or iterate entry propagates
    for (g, x) in ((T[NaN, 1], T[0, 1]), (T[1, 1], T[0, NaN]), (T[1, NaN], T[1, 0]))
      @test isnan(ProximalSolvers._kkt_residual(g, x, T(0.5), T(2)))
      @test isnan(ProximalSolvers._kkt_residual(g, x, T(0.5), zero(T)))
    end
    # worked values, λ1 = 1, λ2 = 2, x = [0, 0.5]: a minimizer (residual 0), and a gradient at which
    # entry 2 has residual |-1 + 1| = 0 without the λ2 term and |-1 + 2 * 0.5 + 1| = 1 with it
    x = T[0, 0.5]
    @test ProximalSolvers._kkt_residual(T[0.7, -2.0], x, one(T), T(2)) === zero(T)
    @test ProximalSolvers._kkt_residual(T[1.5, -1.0], x, one(T), T(2)) === one(T)
    @test ProximalSolvers._kkt_residual(T[1.5, -1.0], x, one(T)) === T(0.5)
    # the call allocates nothing once compiled
    g = randn(Xoshiro(1), T, 64)
    x = randn(Xoshiro(2), T, 64)
    x[1:20] .= 0
    a, b = T(0.1), T(0.2)
    ProximalSolvers._kkt_residual(g, x, a, b)
    @test residual_allocations(g, x, a, b) == 0
  end
end

@testset "orthogonal design: the closed-form minimizer of the elastic net" begin
  # λ1 and λ2 as fractions of λmax and of α mean(‖X_j‖²): lasso only, ridge only, both, both zero,
  # and λ1 above λmax (the minimizer is 0, and the solve from x0 = 0 returns x = 0)
  levels = (("lasso", 0.3, 0.0), ("ridge", 0.0, 0.5), ("both", 0.3, 0.5), ("zero", 0.0, 0.0), ("above λmax", 2.0, 0.5))
  for T in (Float32, Float64), scaled in (false, true), (name, f1, f2) in levels, method in METHODS, seed in (1, 2)
    X, y = orthogonal(T, seed)
    α = scaled ? one(T) / T(8) : one(T)
    λ1 = T(f1 * lambdamax(X, y, α))
    λ2 = T(f2 * Float64(α) * sum(abs2, Float64.(X)) / 4)
    β = analytic(X, y, α, λ1, λ2)
    x, r = run(method, X, y, α, ElasticNet(λ1, λ2), zeros(T, 4), STRICT)
    dx, nβ = distance(x, β)
    label = (T, scaled, name, typeof(method), seed)
    if nβ == 0
      @test (label, all(iszero, x)) == (label, true)
    else
      # relative to ‖β‖∞: the solves reach 1e-9 (Float64) and 1e-5 (Float32) here, the tolerance is 1e-7 and 2e-3
      @test (label, dx <= xtol_of(T) * nβ) == (label, true)
    end
  end
end

@testset "random full-rank designs: signed-support BigFloat minimizer, objective gap and KKT residual" begin
  n, p = 40, 10
  for T in (Float32, Float64), scaled in (false, true), f1 in (0.0, 0.1, 0.3), c2 in (0.0, 0.1, 1.0)
    X, y = design(T, n, p, 11)
    α = scaled ? one(T) / T(n) : one(T)
    λ1 = T(f1 * lambdamax(X, y, α))
    λ2 = T(c2 * Float64(α) * sum(abs2, Float64.(X)) / p)
    β, ok = reference(X, y, α, λ1, λ2)
    @test (T, scaled, f1, c2, ok) == (T, scaled, f1, c2, true)
    ok || continue
    for method in METHODS
      label = (T, scaled, f1, c2, typeof(method))
      x, r = run(method, X, y, α, ElasticNet(λ1, λ2), zeros(T, p), STRICT)
      check_quality(label, X, y, α, λ1, λ2, x, β, T)
      run(method, X, y, α, ElasticNet(λ1, λ2), zeros(T, p), DEFAULT)
    end
  end
end

@testset "ElasticNet(λ, 0) reaches the quality of NormL1(λ)" begin
  n, p = 40, 10
  for T in (Float32, Float64), scaled in (false, true), method in METHODS
    X, y = design(T, n, p, 12)
    α = scaled ? one(T) / T(n) : one(T)
    λ = T(0.1 * lambdamax(X, y, α))
    β, ok = reference(X, y, α, λ, zero(T))
    @test ok
    label = (T, scaled, typeof(method))
    x_en, _ = run(method, X, y, α, ElasticNet(λ, zero(T)), zeros(T, p), STRICT)
    x_l1 = zeros(T, p)
    solve!(x_l1, lossof(α, y, X), NormL1(λ), method, STRICT)
    check_quality((label, :elasticnet), X, y, α, λ, zero(T), x_en, β, T)
    check_quality((label, :normL1), X, y, α, λ, zero(T), x_l1, β, T)
  end
end

@testset "stopping honesty: a stop at a point that is stationary for the lasso only is refused" begin
  # X = diag(1, a) with a = 0.01 and y = (0, 1), α = 1, λ1 = 0.2 a, λ2 = 1e-4, gradtol = 1e-3. The
  # warm start is the minimizer of NormL1(λ1), from the closed form. Its first coordinate is 0 and the
  # second is 80. In the first iteration L is of the order of 1 (0.9 with the default options: the
  # initial estimate 1 times the line search factor; the curvature of the step is below it, so the
  # trial is accepted), the soft-threshold part of the step leaves
  # the warm start unchanged up to rounding, and the ridge weight 1/(1 + λ2/L) scales it, so the iterate
  # moves by a relative 1e-4, below xtol, and a test proposes a stop. At that iterate the residual of
  # NormL1(λ1) is of the order of 1e-6, below τ S = 1e-5 (S = λmax = a), while the elastic-net residual
  # is of the order of λ2 x2 = 8e-3, so the stop is refused when the residual includes λ2 x.
  for T in (Float32, Float64), method in METHODS
    X, y = T[1 0; 0 0.01], T[0, 1]
    α = one(T)
    λ1, λ2 = T(0.2 * 0.01), T(1e-4)
    lasso = T.(analytic(X, y, α, λ1, zero(T)))
    @test lasso[1] == 0 && lasso[2] > 50
    options = ProximalOptions(xtol = 1e-1, ftol = 1e-1, gradtol = 1e-3)
    x, r = run(method, X, y, α, ElasticNet(λ1, λ2), lasso, options)
    τ = max(options.gradtol, 64 * Float64(eps(T)))
    G, S, eG, eS = kktparts(X, y, α, λ1, λ2, x, T)
    moved = x != lasso
    # either the solve did not stop, or it stopped at a point whose independent residual is within τ S
    @test (T, typeof(method), !r.converged || (moved && G < τ * S + eG + τ * eS)) == (T, typeof(method), true)
    # the lasso minimizer itself is not stationary for the elastic net, by a margin of 100 τ S
    G0, S0, _, _ = kktparts(X, y, α, λ1, λ2, lasso, T)
    @test G0 > 100 * τ * S0
  end
end

@testset "ridge solutions at x = 0: S = 0 refuses every stop" begin
  for T in (Float32, Float64), method in METHODS
    # y = 0, so the minimizer of ElasticNet(0, 1) from x0 = 0 is x0, and λmax = 0
    X = randn(Xoshiro(3), T, 10, 3)
    x = zeros(T, 3)
    options = ProximalOptions(maxiter = 40)
    r = solve!(x, LeastSquaresLoss(zeros(T, 10), X), ElasticNet(zero(T), one(T)), method, options)
    @test all(iszero, x) && !r.converged && r.iterations == 40 && r.iteration_converged
    # Xᵀy = 0 with y ≠ 0
    X1 = reshape(T[1, 1], 2, 1)
    x = zeros(T, 1)
    r = solve!(x, LeastSquaresLoss(T[1, -1], X1), ElasticNet(zero(T), one(T)), method, options)
    @test all(iszero, x) && !r.converged && r.iterations == 40
  end
end

@testset "level types: Float64 and Int levels, extreme levels" begin
  n, p = 40, 10
  for method in METHODS
    # Float64 levels with Float32 data: the reference uses the Float32 values
    X, y = design(Float32, n, p, 13)
    g = ElasticNet(0.05 * lambdamax(X, y, 1f0), 3.3)
    λ1, λ2 = Float32(g.λ1), Float32(g.λ2)
    β, ok = reference(X, y, 1f0, λ1, λ2)
    @test ok
    x, _ = run(method, X, y, 1f0, g, zeros(Float32, p), STRICT)
    check_quality((:float64levels, typeof(method)), X, y, 1f0, λ1, λ2, x, β, Float32)

    # Int levels: ElasticNet(1, 2) on a small integer design
    Xi, yi = Float64[3 0 1; 0 2 1; 1 1 4; 2 -1 0; 0 1 1], Float64[7, -4, 5, 6, -2]
    β, ok = reference(Xi, yi, 1.0, 1.0, 2.0)
    @test ok && any(!iszero, β)
    x, _ = run(method, Xi, yi, 1.0, ElasticNet(1, 2), zeros(3), STRICT)
    check_quality((:intlevels, typeof(method)), Xi, yi, 1.0, 1.0, 2.0, x, β, Float64)
    x, _ = run(method, Xi, yi, 1.0, ElasticNet(0, 2), zeros(3), STRICT)
    β, ok = reference(Xi, yi, 1.0, 0.0, 2.0)
    @test ok
    check_quality((:intlevels0, typeof(method)), Xi, yi, 1.0, 0.0, 2.0, x, β, Float64)

    # a BigFloat level is accepted like a NormL1 level
    g = ElasticNet(big"0.5", big"2")
    x, _ = run(method, Xi, yi, 1.0, g, zeros(3), STRICT)
    β, ok = reference(Xi, yi, 1.0, 0.5, 2.0)
    @test ok
    check_quality((:bigfloatlevels, typeof(method)), Xi, yi, 1.0, 0.5, 2.0, x, β, Float64)

    # λ2 near the top of the range of T: the minimizer is of the order of 1e-30 or smaller
    for T in (Float32, Float64)
      Xt, yt = design(T, n, p, 14)
      x, r = run(method, Xt, yt, one(T), ElasticNet(T(0.1), floatmax(T) / 8), zeros(T, p), DEFAULT)
      @test all(isfinite, x) && maximum(abs, x) <= 1e-20
    end

    # λ2 subnormal in Float32: accepted, as a Float32 NormL1 level that is subnormal is; the solution
    # is that of the lasso up to the effect of a level of 1e-42
    X, y = design(Float32, n, p, 15)
    λ1 = Float32(0.1 * lambdamax(X, y, 1f0))
    @test issubnormal(Float32(1e-42))
    x, _ = run(method, X, y, 1f0, ElasticNet(λ1, 1e-42), zeros(Float32, p), STRICT)
    β, ok = reference(X, y, 1f0, λ1, 0f0)
    @test ok
    check_quality((:subnormal, typeof(method)), X, y, 1f0, λ1, Float32(1e-42), x, β, Float32)
    # a level that underflows to 0 in Float32 is refused, before any change of x
    x = zeros(Float32, p)
    @test_throws ArgumentError("penalty lambda2 is not representable without overflow or underflow in Float32") solve!(x, LeastSquaresLoss(y, X), ElasticNet(λ1, 1e-60), method)
    @test_throws ArgumentError("penalty lambda1 is not representable without overflow or underflow in Float32") solve!(x, LeastSquaresLoss(y, X), ElasticNet(1e-60, 1f0), method)
    @test all(iszero, x)
  end
end

@testset "a start whose penalty overflows is refused with the iterate restored" begin
  # f(x0) = 0 is finite, the ridge value (λ2/2) x0² = 5e39 is above floatmax(Float32)
  for method in METHODS
    X, y = reshape(Float32[1e-20], 1, 1), Float32[1]
    x0 = Float32[1e20]
    @test isfinite(LeastSquaresLoss(y, X)(x0)) && !isfinite(ElasticNet(0f0, 1f0)(x0))
    x = copy(x0)
    @test_throws r"did not produce a finite objective" solve!(x, LeastSquaresLoss(y, X), ElasticNet(0f0, 1f0), method)
    @test isequal(x, x0)
  end
end

# the bytes allocated by a warmed solve and by the validation of the penalty, measured inside functions
function solve_allocations(method, f, g, x0, options)
  x = copy(x0)
  solve!(x, f, g, method, options)
  minimum(begin
    copyto!(x, x0)
    @allocated solve!(x, f, g, method, options)
  end for _ in 1:3)
end
function validation_allocations(g, ::Type{T}) where T
  PS._check_penalty(g, T, true)
  minimum((@allocated PS._check_penalty(g, T, true)) for _ in 1:3)
end

@testset "allocations: an ElasticNet solve allocates no more than the NormL1 solve, beyond its own penalty validation" begin
  # The validation of the penalty levels (_scalar_parameter, once per solve) allocates a few bytes on
  # some Julia versions and level types, and an ElasticNet validates two levels where NormL1 validates
  # one, so the bytes of the validation are taken out of both counts. The rest of the solve, which is
  # the iteration, must not allocate more for the ElasticNet.
  options = ProximalOptions(maxiter = 30, ftol = 0, xtol = 1e-300, gradtol = 0, allow_f_increases = true)
  for T in (Float32, Float64), scaled in (false, true), method in METHODS
    X, y = design(T, 40, 10, 16)
    α = scaled ? one(T) / T(40) : one(T)
    f = lossof(α, y, X)
    λ = 0.1 * lambdamax(X, y, α)
    x0 = zeros(T, 10)
    for (en, l1) in ((ElasticNet(T(λ), T(0.5)), NormL1(T(λ))), (ElasticNet(λ, 0.5), NormL1(λ)))
      iteration_en = solve_allocations(method, f, en, x0, options) - validation_allocations(en, T)
      iteration_l1 = solve_allocations(method, f, l1, x0, options) - validation_allocations(l1, T)
      @test (T, scaled, typeof(method), iteration_en <= iteration_l1) == (T, scaled, typeof(method), true)
    end
  end
end

# the file's own check that the honesty test above was not vacuous: some solves of the file stopped
@testset "the stopping checks were exercised" begin
  @test NRUN[] > 100
  @test NCONV[] > 10
end

end
