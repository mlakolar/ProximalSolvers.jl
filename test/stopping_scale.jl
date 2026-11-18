module StoppingScaleTests
# The stopping tests of ProximalGradientDescent and AccProxGradDescent under a change of the scale
# of the loss and of the design columns (#296). A solve that reports converged = true must end at a
# point whose KKT residual is small relative to max(λ, λmax), λmax = α‖Xᵀy‖∞. The residual is
# computed here in 256-bit BigFloat from the raw X, y, the loss scale α and the penalty λ, never
# with the solver's gradient or caches. Only the converged flag is compared with that residual:
# the solvers need not converge, and the tests do not require it, except where a case says so.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

# The designs of the #296 reproduction: `base` (n = 30, p = 12, a lasso signal), `ill` (column
# scales 1 … 1e-4), `zerocol` (a zero third column), and two designs whose columns differ in scale by 1e6:
# `diag` and `orth`.
function data(name)
  rng = Xoshiro(296)
  if name == "diag"
    return [1e6 0.0; 0.0 1.0; 0.0 0.5], [0.0, 1.0, 0.2]
  elseif name == "orth"   # orthogonal columns, scales 1e6, 1, 1, 1; y orthogonal to the first
    Q = Matrix(qr(randn(rng, 8, 8)).Q)
    return Q[:, 1:4] * Diagonal([1e6, 1.0, 1.0, 1.0]), Q[:, 2:4] * [1.0, -1.0, 0.5] + 0.2 * Q[:, 5]
  end
  X = randn(rng, 30, 12)
  β = zeros(12); β[1:4] .= [2.0, -1.5, 1.0, 0.5]
  name == "ill" && (X .*= (10.0 .^ range(0, -4; length = 12))')
  name == "zerocol" && (X[:, 3] .= 0)
  X, X * β + 0.3 * randn(rng, 30)
end

# The exact minimal-norm KKT residual ‖G‖∞ of ∇f(x) + λ ∂‖x‖₁, f(x) = α/2 ‖y - X x‖², and
# S = max(λ, λmax), from the T data as given, in BigFloat (precision is scoped). Returns
#   (‖G‖∞ - eG - τ (1 + 4 eps(T)) (S + eS)) / S,   Inf for S = 0,
# which is at most 0 when the exact residual is within the threshold τ S of the solver's check
# plus the first-order rounding error of what the solver computes. The solver compares its
# computed residual Ĝ with τ Ŝ, where Ŝ uses a computed λmax. With u = eps(T) (twice the unit
# roundoff, as slack), standard dot-product bounds for a computed d̂ = fl(X x) - y and gradient
# ĝ = α fl(Xᵀ d̂) give, from the raw products and the exact residual d = X x - y,
#   eG = max over coordinates i of α Σⱼ |Xⱼᵢ| (e_j + (n+1) u (|d_j| + e_j)) + u (|gᵢ| + λ),
#   e_j = (p+1) u (Σₖ |Xⱼₖ||xₖ| + |y_j|),     eS = α (n+1) u max over i of Σⱼ |Xⱼᵢ||y_j|,
# with eG covering |Ĝ - G| and eS covering |λ̂max - λmax|. These are estimates under that error
# model, not guarantees for every BLAS kernel, and they do not make the computed residual an
# exact one.
function kkt_excess(X, y, α, λ, x, τ, ::Type{T}) where T
  G, S, eG, eS, u = kkt_parts(X, y, α, λ, x, T)
  iszero(S) && return Inf
  setprecision(BigFloat, 256) do
    Float64((G - eG - BigFloat(τ) * (1 + 4u) * (S + eS)) / S)
  end
end

# The exact residual G = ‖G‖∞, S, and the rounding estimates eG, eS and u of kkt_excess, in
# BigFloat (the values keep the 256-bit precision they were formed in)
function kkt_parts(X, y, α, λ, x, ::Type{T}) where T
  setprecision(BigFloat, 256) do
    Xb, yb, xb, a, l = BigFloat.(X), BigFloat.(y), BigFloat.(x), BigFloat(α), BigFloat(λ)
    n, p = size(Xb)
    u = BigFloat(eps(T))
    d = Xb * xb - yb
    g = a .* (Xb' * d)
    G = maximum(j -> iszero(xb[j]) ? max(abs(g[j]) - l, zero(l)) : abs(g[j] + l * sign(xb[j])), eachindex(xb))
    S = max(l, maximum(abs, a .* (Xb' * yb)))
    absX = abs.(Xb)
    e = (p + 1) * u .* (absX * abs.(xb) + abs.(yb))
    eG = maximum(a .* (absX' * (e .+ (n + 1) * u .* (abs.(d) .+ e))) .+ u .* (abs.(g) .+ l))
    eS = a * (n + 1) * u * maximum(absX' * abs.(yb))
    G, S, eG, eS, u
  end
end

# λ = frac α ‖Xᵀy‖∞ in T, from the exact BigFloat value
function penalty(::Type{T}, X, y, α, frac) where T
  λ = setprecision(BigFloat, 256) do
    frac * BigFloat(α) * maximum(abs, BigFloat.(X)' * BigFloat.(y))
  end
  iszero(frac) ? zero(T) : max(T(λ), nextfloat(zero(T)))
end

lossof(α, y, X) = isone(α) ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)

# The solve, or `nothing` when it ends in the line search's error at an extreme scale ("nonfinite
# curvature estimate", a documented limitation), after which the iterate is the last accepted one.
function solve_case(method, y, X, α, λ, x0, options)
  x = copy(x0)
  try
    solve!(x, lossof(α, y, X), NormL1(λ), method, options)
  catch err
    err isa ErrorException && occursin("curvature", err.msg) || rethrow()
    @test all(isfinite, x)
    nothing
  end
end

# The invariant, checked for each result below that has converged = true: the exact residual ‖G‖∞
# is within τ S of the solver's check, τ = max(gradtol, 64 eps(T)), up to the first-order rounding
# estimates of kkt_excess, which come from the raw products of the data and the returned x.
# The solver's contract is on its computed residual; this does not claim an exact-residual bound.
function invariant(label, r, X, y, α, λ, options, ::Type{T}) where T
  r === nothing && return
  r.converged || return
  τ = max(options.gradtol, 64 * Float64(eps(T)))
  excess = kkt_excess(X, y, α, λ, r.minimizer, τ, T)
  @test (label, excess <= 0) == (label, true)
end

const DEFAULT = ProximalOptions()
const STRICT = ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11)
const METHODS = (ProximalGradientDescent(), AccProxGradDescent())

@testset "the memo case: Float64 loss scale 1e-300, cold start, λ = 0.1 λmax (#296)" begin
  X, y = data("base")
  α = 1e-300
  λ = penalty(Float64, X, y, α, 0.1)
  for method in METHODS, (name, options) in (("default", DEFAULT), ("strict", STRICT))
    r = solve_case(method, y, X, α, λ, zeros(12), options)
    invariant((typeof(method), name), r, X, y, α, λ, options, Float64)
  end
end

@testset "Float32 loss scales near floatmin and at 1e-30, cold start, λ = 0.1 λmax (#296)" begin
  X, y = Float32.(data("base")[1]), Float32.(data("base")[2])
  for α in (floatmin(Float32), 1f-30), method in METHODS, (name, options) in (("default", DEFAULT), ("strict", STRICT))
    λ = penalty(Float32, X, y, α, 0.1)
    r = solve_case(method, y, X, α, λ, zeros(Float32, 12), options)
    invariant((typeof(method), α, name), r, X, y, α, λ, options, Float32)
  end
end

@testset "unequal column scales: no false success from a start off in the steep coordinate (#296)" begin
  rng = Xoshiro(7)
  for (name, starts) in (("diag", [[1.0, 0.0]]),
                         ("orth", [zeros(4), [1.0, 0.0, 0.0, 0.0], randn(rng, 4)]))
    X, y = data(name)
    for frac in (0.0, 0.1), x0 in starts, method in METHODS
      λ = penalty(Float64, X, y, 1.0, frac)
      r = solve_case(method, y, X, 1.0, λ, x0, DEFAULT)
      invariant((name, frac, x0, typeof(method)), r, X, y, 1.0, λ, DEFAULT, Float64)
    end
  end
end

@testset "equivalent rescalings (α, λ) and (cα, cλ): converged implies a small relative residual (#296)" begin
  X, y = data("base")
  λ1 = penalty(Float64, X, y, 1.0, 0.1)
  options = ProximalOptions(maxiter = 5000)
  for c in (1e-200, 1e-20, 1.0), x0 in (zeros(12), randn(Xoshiro(7), 12)), method in METHODS
    r = solve_case(method, y, X, c, c * λ1, x0, options)
    invariant((c, x0[1], typeof(method)), r, X, y, c, c * λ1, options, Float64)
    if c == 1 && iszero(x0[1])
      @test r.converged
      method isa AccProxGradDescent && @test r.grad_calls > r.iterations   # the check of the stop is counted
    end
  end
end

@testset "λ ≥ λmax at x = 0 stops at the first iteration with its flags (#296)" begin
  for T in (Float64, Float32), method in METHODS
    X, y = T.(data("base")[1]), T.(data("base")[2])
    λ = T(1.01 * maximum(abs, Float64.(X)' * Float64.(y)))
    x = zeros(T, 12)
    r = solve!(x, LeastSquaresLoss(y, X), NormL1(λ), method)
    @test r.converged && r.iterations == 1 && all(iszero, x)
    @test r.x_converged && r.f_converged && r.grad_converged
    # the counts of the one iteration: the accelerated method evaluates ∇f(x) for the check, PGD
    # uses the gradient it holds
    @test (r.f_calls, r.grad_calls, r.prox_calls) == (3, 2, 1)
  end
end

@testset "gradtol = 0 verifies against 64 eps(T) (#296)" begin
  for T in (Float64, Float32), method in METHODS
    X, y = T.(data("base")[1]), T.(data("base")[2])
    α = one(T) / T(30)
    λ = penalty(T, X, y, α, 0.1)
    options = ProximalOptions(gradtol = 0, maxiter = 5000)
    r = solve_case(method, y, X, α, λ, zeros(T, 12), options)
    invariant((T, typeof(method)), r, X, y, α, λ, options, T)
  end
end

@testset "y = 0: λ = 0 never converges, λ > 0 stops at x = 0 (#296)" begin
  for T in (Float64, Float32), method in METHODS
    X = T[1 1 .2; 2 1 .3; -1 0 .5; .1 1 1; .4 .3 -.8]
    y = zeros(T, 5)
    r = solve!(zeros(T, 3), LeastSquaresLoss(y, X), NormL1(zero(T)), method, ProximalOptions(maxiter = 20))
    @test !r.converged && !r.x_converged && !r.f_converged && !r.grad_converged && r.iteration_converged
    x = zeros(T, 3)
    r = solve!(x, LeastSquaresLoss(y, X), NormL1(T(.1)), method)
    @test r.converged && r.iterations == 1 && all(iszero, x)
  end
end

@testset "a zero column and an ill-conditioned design (#296)" begin
  for name in ("zerocol", "ill"), T in (Float64, Float32), α in (one(T), one(T) / T(30)), method in METHODS
    X, y = T.(data(name)[1]), T.(data(name)[2])
    λ = penalty(T, X, y, α, 0.1)
    for (oname, options) in (("default", DEFAULT), ("strict", STRICT))
      r = solve_case(method, y, X, α, λ, zeros(T, 12), options)
      invariant((name, T, α, oname, typeof(method)), r, X, y, α, λ, options, T)
    end
  end
end

@testset "the relative objective test has no absolute term (#296)" begin
  @test !(PS.f_residual(2.0, 2.000003, 1e-6) < 1e-6)
  @test PS.f_residual(2.0, 2.0000019, 1e-6) < 1e-6
  @test PS.f_residual(1.1e-300, 1e-300, 1e-6) ≈ 1 / 11 rtol = 1e-6
  @test PS.f_residual(0.0, 0.0, 1e-6) === 0.0
  @test PS.f_residual(1e-300, 1.0e-300, 1e-6) === 0.0
end

# PGD state of the one-column problem f(x) = α/2 (y - x)², g = λ|x|, at x, with the gradient at x
# set to `grad`. Only the fields that the checks read are set.
function pgd_state(T, x, y, α, λ, grad, options)
  f, g = lossof(α, T[y], T[1;;]), NormL1(T(λ))
  state = PS.initial_state(ProximalGradientDescent(), options, f, g, T[x])
  state.grad_f_x .= grad
  state, g
end

@testset "the gradient test: resolution of L x, scale of the normalizers, no evidence from zero (#296)" begin
  for T in (Float64, Float32)
    options = ProximalOptions(gradtol = 1e-5)
    function test(L, x, max_residual, residual, N)
      state, _ = pgd_state(T, x, 1, 1, .1, 0, options)
      state.L, state.max_residual = T(L), T(max_residual)
      PS._gradient_test(state, options, T(residual), T(N))
    end
    ρ = 0.9 * eps(T)       # L eps(T) ‖x‖∞ for L = 0.9, ‖x‖∞ = 1
    # a normalizer and a largest residual below the resolution of L x decide nothing
    @test !test(0.9, 1, ρ / 10, 0, ρ / 10)
    # above the resolution a zero residual passes
    @test test(0.9, 1, 10ρ, 0, 10ρ)
    # L = 50, ‖x‖∞ = 3, residual 5e-5 < gradtol max_residual = 1e-4, and ρ ≈ 3.3e-14 < 10
    T === Float64 && @test test(50, 3, 10, 5e-5, 0)
    # a zero residual against zero normalizers is no evidence
    @test !test(0.9, 1, 0, 0, 0)
    # a residual that is not small against either normalizer
    @test !test(0.9, 1, 1, 1, 1)
  end
  # the resolution is the one in the memo case: Float64, a normalizer of 1e-300
  options = ProximalOptions(gradtol = 1e-5)
  state, _ = pgd_state(Float64, 1.0, 1, 1, .1, 0, options)
  state.L, state.max_residual = 0.9, 1e-299
  @test !PS._gradient_test(state, options, 0.0, 1e-300)
end

# One check of a stop: (kept, state) for the point x of the problem with λ and the solver method.
# For PGD the gradient at x is set to -λ sign(x) + G (G the residual of the entry), the response y = λmax
# with the design [1]. For APG the response is chosen so that the gradient that the kernel forms at x is
# x - y = -λ sign(x) + G.
function check(method, T, x, λ, G, options; λmax = 1, α = one(T))
  g = NormL1(T(λ))
  if method isa ProximalGradientDescent
    f = lossof(α, T[λmax / α], T[1;;])
    state = PS.initial_state(method, options, f, g, T[x])
    state.grad_f_x .= -T(λ) * sign(T(x)) + T(G)
  else
    y = iszero(x) ? T(λmax) : T(T(x) + T(λ) * sign(T(x)) - T(G))
    f = lossof(α, T[y], T[1;;])
    state = PS.initial_state(method, options, f, g, T[x])
  end
  PS._stationary!(state, f, g, options), state
end

@testset "the stationarity check of a stop: thresholds, the zero exit, a zero scale and underflow (#296)" begin
  # Float64, λ = 0.1, λmax = 1, gradtol = 1e-5: threshold 1e-5
  o = ProximalOptions(gradtol = 1e-5)
  @test check(ProximalGradientDescent(), Float64, 0.5, .1, 3e-6, o)[1]
  @test !check(ProximalGradientDescent(), Float64, 0.5, .1, 2e-5, o)[1]
  @test check(ProximalGradientDescent(), Float64, 0.5, .1, 3e-6, o)[2].λmax == 1
  # the accelerated method forms the gradient at x from the cached image; S = max(λ, ‖y‖) with y = x + λ - G
  for (G, expected) in ((3e-6, true), (2e-5, false))
    ok, state = check(AccProxGradDescent(), Float64, 0.5, .1, G, o)
    @test ok == expected
    @test state.grad_calls == 1
    @test state.λmax ≈ 0.6 atol = 1e-4
  end
  # the zero-solution exit: x = 0, λ = 1.2 ≥ λmax = 1, so G = 0
  @test check(ProximalGradientDescent(), Float64, 0.0, 1.2, 0.0, o)[1]
  @test check(AccProxGradDescent(), Float64, 0.0, 1.2, 0.0, o, λmax = 1)[1]
  # y = 0 and λ = 0: S = 0, no convergence
  @test !check(ProximalGradientDescent(), Float64, 0.5, 0.0, 0.0, o, λmax = 0)[1]
  # Float32 strict (gradtol = 1e-11): τ = 64 eps(Float32) = 7.63e-6
  o32 = ProximalOptions(gradtol = 1e-11)
  @test check(ProximalGradientDescent(), Float32, 0.5, .1, 5e-6, o32)[1]
  @test !check(ProximalGradientDescent(), Float32, 0.5, .1, 1e-5, o32)[1]
  # Float64 with gradtol = 0: τ = 64 eps = 1.42e-14
  o0 = ProximalOptions(gradtol = 0)
  @test check(ProximalGradientDescent(), Float64, 0.5, .1, 1e-14, o0)[1]
  @test !check(ProximalGradientDescent(), Float64, 0.5, .1, 2e-14, o0)[1]
  # Float32, α = 1e-39: λmax = 5e-38, τ λmax = 3.8e-43 < floatmin(Float32): underflow decides nothing
  ok, state = check(ProximalGradientDescent(), Float32, 0.5, 0.0, 0.0, o32, λmax = 50f-39, α = 1f-39)
  @test !ok
  @test state.λmax ≈ 5f-38 rtol = 1e-3
  # a gradient that is not finite
  @test !check(ProximalGradientDescent(), Float64, 0.5, .1, NaN, o)[1]
end

# a function barrier gives the call concrete argument types
alloc_check(state, f, g, options) = @allocated PS._stationary!(state, f, g, options)
@testset "the stationarity check allocates nothing (#296)" begin
  o = ProximalOptions(gradtol = 1e-5)
  # a level of type T, a BigFloat level and a Rational level
  for T in (Float64, Float32), method in METHODS, level in (T(.1), big"0.1", 1 // 10)
    g = NormL1(level)
    raw = LeastSquaresLoss(T[.6, 1], T[1 0; 0 1])
    # raw, a scale of type T, a Float64 (Float32 data) or Float32 (Float64 data) scale, an integer scale
    for f in (raw, T(.25) * raw, (T === Float32 ? 0.25 : 0.25f0) * raw, 3 * raw)
      state = PS.initial_state(method, o, f, g, T[.5, 0])
      PS._stationary!(state, f, g, o)
      @test alloc_check(state, f, g, o) == 0
    end
  end
end

# The bytes of the conversions that one check must make: a Rational{BigInt} level allocates when it is converted
# to T. The complete check converts each level once, so it allocates no more than the conversions themselves.
convert_bytes(::Type{T}, λ) where T = minimum((@allocated T(λ)) for _ in 1:3)
convert_bytes(::Type{T}, λ1, λ2) where T = minimum((@allocated (T(λ1), T(λ2))) for _ in 1:3)
min_alloc_check(state, f, g, options) = minimum(alloc_check(state, f, g, options) for _ in 1:3)
@testset "the stationarity check converts each level once: Rational{BigInt} levels" begin
  o = ProximalOptions(gradtol = 1e-5)
  λ1, λ2 = big(1) // big(3), big(1) // big(7)
  for T in (Float64, Float32), method in METHODS
    f = LeastSquaresLoss(T[.6, 1], T[1 0; 0 1])
    for (g, bytes) in ((NormL1(λ1), convert_bytes(T, λ1)), (ElasticNet(λ1, λ2), convert_bytes(T, λ1, λ2)))
      @test bytes > 0
      state = PS.initial_state(method, o, f, g, T[.5, 0])
      PS._stationary!(state, f, g, o)
      @test min_alloc_check(state, f, g, o) <= bytes
    end
  end
end

# The residual of the check is ProximalBase's kkt_violation(NormL1(λ), ∇f(x), x) with λ = T(λ0). The
# reference is a local loop of the documented formula with the coefficient c: max(|gᵢ| - c, 0) where
# xᵢ = 0 and |gᵢ + c sign xᵢ| elsewhere, started at 0; the default coefficient is T(λ0), the one
# the solver uses.
function reference_residual(grad::Vector{T}, x::Vector{T}, λ0; c = T(λ0)) where T
  λ = T(c)
  m = zero(T)
  for i in eachindex(grad, x)
    r = iszero(x[i]) ? max(abs(grad[i]) - λ, zero(T)) : abs(grad[i] + λ * sign(x[i]))
    m = max(m, r)
  end
  m
end

@testset "stationarity residual: ProximalBase kkt_violation" begin
  rng = Xoshiro(341)
  for T in (Float32, Float64), λ0 in (0.3, 0.3f0, 2, big"0.3"), n in (0, 1, 16, 17, 300)
    λ = T(λ0)
    for rep in 1:4
      x = T[rand(rng) < 0.4 ? zero(T) : randn(rng, T) for _ in 1:n]
      for i in eachindex(x)
        iszero(x[i]) && rand(rng) < 0.3 && (x[i] = -zero(T))
      end
      # gradients: exactly at the boundary (±λ at zeros, -λ sign xᵢ at nonzeros) for some entries,
      # a random value for the others
      grad = Vector{T}(undef, n)
      for i in 1:n
        grad[i] = rand(rng) < 0.5 ? (iszero(x[i]) ? (rand(rng, Bool) ? λ : -λ) : -λ * sign(x[i])) : 2 * randn(rng, T)
      end
      # the coefficient is λ = T(λ0) on both sides and the entry formulas are evaluated in T, so the
      # results are equal
      @test kkt_violation(NormL1(T(λ0)), grad, x) === reference_residual(grad, x, λ0)
    end
  end
end


# The decision of _stationary! for a penalty level λ0 whose conversion to T depends on how it is
# rounded. The one-column problem has λmax = 1 and x = 1; the gradient is -λ + δ, with the
# coefficient λ = T(λ0) and a perturbation δ that is searched among a few values so that the
# independent residual with the coefficient T(λ0) is below the threshold τ S (τ = 64 eps(T),
# gradtol = 0) and the residual with the coefficient `other`, a different rounding of λ0, is not.
# The solver must keep the stop: it uses the coefficient T(λ0).
function level_decision(T, λ0, other; setup = f -> f())
  o = ProximalOptions(gradtol = 0)
  τ = T(64 * Float64(eps(T)))
  λ = T(λ0)
  @test λ != T(other)
  S = max(λ, one(T))
  threshold = τ * S
  x = T[1]
  found = false
  for k in 2:24, s in (1, -1)
    grad = T[-λ + s * (1 - T(2)^-k) * threshold]
    r_true = reference_residual(grad, x, λ0)
    r_other = reference_residual(grad, x, λ0; c = T(other))
    if r_true < threshold <= r_other
      found = true
      ok = setup() do
        f = LeastSquaresLoss(T[1], T[1;;])
        g = NormL1(λ0)
        state = PS.initial_state(ProximalGradientDescent(), o, f, g, copy(x))
        state.grad_f_x .= grad
        PS._stationary!(state, f, g, o)
      end
      @test ok === true
      break
    end
  end
  @test found
end

@testset "the stationarity check uses the coefficient T(λ0): levels that round differently" begin
  # a BigFloat level stored at 256 bits and used while the precision is 24 (8 for Float32)
  for (T, prec, other) in ((Float64, 24, 0.30000001192092896), (Float32, 8, 0.30078125f0))
    λ0 = setprecision(() -> BigFloat("0.3"), BigFloat, 256)
    @test precision(λ0) == 256 && T(λ0) == T(0.3)
    level_decision(T, λ0, other; setup = f -> setprecision(f, BigFloat, prec))
  end
  # a Rational whose Float32 value is 1.0000001f0, where the rounding through Float64 gives 1.0f0
  λ0 = 1152921573326323713 // 1152921504606846976
  @test Float32(λ0) == 1.0000001f0 && Float32(Float64(λ0)) == 1f0
  level_decision(Float32, λ0, Float32(Float64(λ0)))
  # an Int128 level above the tie of Float32: directly rounded up, but a tie rounded to even after Float64
  λ0 = (Int128(1) << 100) + (Int128(1) << 76) + 1
  @test Float32(λ0) != Float32(Float64(λ0))
  level_decision(Float32, λ0, Float32(Float64(λ0)))
  # a UInt128 level that converts to floatmax(Float32); the penalty validation accepts it
  λ0 = typemax(UInt128) - (UInt128(1) << 103)
  @test Float32(λ0) == floatmax(Float32)
  @test PS._check_penalty(NormL1(λ0), Float32[1], Float32) === nothing
  level_decision(Float32, λ0, Inf32)
end

@testset "a BigFloat level stored at 256 bits, used at precision 24: no false convergence" begin
  λ = setprecision(() -> BigFloat("0.3"), BigFloat, 256)
  r, x = setprecision(BigFloat, 24) do
    x = zeros(1)
    f = LeastSquaresLoss([1.0], ones(1, 1))
    method = ProximalGradientDescent(ls = PS.LineSearches.BackTracking(α = 1.0))
    options = ProximalOptions(maxiter = 10, gradtol = 1e-10, allow_f_increases = true)
    solve!(x, f, NormL1(λ), method, options), x
  end
  @test !r.converged
  @test x[1] ≈ 0.7 atol = 1e-6
end

@testset "PGD strict at loss scale 1e-200, λ = 0: converged, within the stopping guarantee of the least-squares solution (#317)" begin
  # A cold start at this scale gives subnormal squared steps, a zero gradient-difference product
  # and, before #317, the line search's "nonfinite curvature estimate" error.
  X, y = data("base")
  α, λ = 1e-200, 0.0
  x = zeros(12)
  r = solve!(x, lossof(α, y, X), NormL1(λ), ProximalGradientDescent(), STRICT)
  @test r.converged
  invariant("strict 1e-200", r, X, y, α, λ, STRICT, Float64)
  # The reference is the least-squares solution x* of the rounded data, in 256-bit BigFloat. With
  # λ = 0, G = α XᵀX (x - x*), so ‖x - x*‖₂ ≤ ‖G‖₂ / (α σmin²) ≤ √p ‖G‖∞ / (α σmin²). The invariant above
  # bounds ‖G‖∞ by U = eG + τ (1 + 4u)(S + eS) (the stopping threshold τ S plus the rounding
  # estimates of kkt_excess). σmin is the least singular value of X from a backward stable SVD,
  # which is exact for X + E with ‖E‖₂ ≤ p eps σmax, taken here as the error of σmin.
  τ = max(STRICT.gradtol, 64 * eps())
  _, S, eG, eS, u = kkt_parts(X, y, α, λ, x, Float64)
  setprecision(BigFloat, 256) do
    Xb, yb = BigFloat.(X), BigFloat.(y)
    xstar = (Xb' * Xb) \ (Xb' * yb)
    U = eG + BigFloat(τ) * (1 + 4u) * (S + eS)
    σ = svdvals(X)
    σlo = BigFloat(last(σ)) - size(X, 2) * BigFloat(eps()) * BigFloat(first(σ))
    @test σlo > 0
    bound = sqrt(BigFloat(size(X, 2))) * U / (BigFloat(α) * σlo^2)
    @test norm(BigFloat.(x) - xstar) <= bound
  end
end

end
