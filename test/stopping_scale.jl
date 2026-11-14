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

# ‖G‖∞/max(λ, λmax) for the minimal-norm element G of ∇f(x) + λ ∂‖x‖₁, f(x) = α/2 ‖y - X x‖², and
# S = max(λ, λmax), from the T data as given; Inf for S = 0. BigFloat precision is scoped.
function relative_kkt(X, y, α, λ, x)
  setprecision(BigFloat, 256) do
    Xb, yb, xb, a, l = BigFloat.(X), BigFloat.(y), BigFloat.(x), BigFloat(α), BigFloat(λ)
    g = a .* (Xb' * (Xb * xb - yb))
    G = maximum(j -> iszero(xb[j]) ? max(abs(g[j]) - l, zero(l)) : abs(g[j] + l * sign(xb[j])), eachindex(xb))
    S = max(l, maximum(abs, a .* (Xb' * yb)))
    iszero(S) ? Inf : Float64(G / S)
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

# The invariant, checked for each result below that has converged = true: ‖G‖∞/S is at most τ (1 + 1e-3) + 1e3 eps(T),
# with τ = max(gradtol, 64 eps(T)) the threshold of the solver's own check. The factor 1 + 1e-3 and
# the 1e3 eps(T) allow for the rounding of the residual that the solver computes, against the
# exact residual computed here, which is at most a few eps times the size of the terms of the
# gradient, and the terms are at most about S at the points where the check passes.
function invariant(label, r, X, y, α, λ, options, ::Type{T}) where T
  r === nothing && return
  r.converged || return
  τ = max(options.gradtol, 64 * Float64(eps(T)))
  rel = relative_kkt(X, y, α, λ, r.minimizer)
  @test (label, rel <= τ * (1 + 1e-3) + 1e3 * Float64(eps(T))) == (label, true)
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
  PS._stationary!(state, g, options), state
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
alloc_check(state, g, options) = @allocated PS._stationary!(state, g, options)
@testset "the stationarity check allocates nothing (#296)" begin
  o = ProximalOptions(gradtol = 1e-5)
  for T in (Float64, Float32), method in METHODS
    g = NormL1(T(.1))
    f = LeastSquaresLoss(T[.6, 1], T[1 0; 0 1])
    state = PS.initial_state(method, o, f, g, T[.5, 0])
    PS._stationary!(state, g, o)
    @test alloc_check(state, g, o) == 0
  end
end

end
