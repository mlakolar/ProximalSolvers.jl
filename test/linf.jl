module LinfTests
# NormLinf(λ) with ProximalGradientDescent and AccProxGradDescent on the least-squares loss
# ½α‖Xb - y‖² + λ‖b‖∞ (α = 1 for a raw LeastSquaresLoss, 1/n and another positive α with a Scaled one).
# The references do not use ProximalBase's ℓ∞ proximal operator, and the two solvers are not compared
# with each other: the analytic minimizer of X = [1 1], y = [2], λ = 1; the clip of an identity design,
# with a clip level found by sorting; the least-squares solution at λ = 0; the zero solution above
# λcrit = ‖∇f(0)‖₁; and the duality gap P(b) - D(u) of a converged run, with the dual point
# u = α(Xb - y) scaled into {‖Xᵀu‖₁ ≤ λ}, in 256-bit BigFloat from the T data as given. `converged` is a
# stopping flag, not an accuracy certificate: accuracy comes from the references, and the flag is checked
# for what the stopping rule of src/utils.jl says about it (a proposed stop passes the check of the
# proximal-gradient mapping, or the solve goes on). The `ProximalOptions` that stop a solve at its first
# iterate (a huge xtol, a loose ftol or gradtol) are used with fixtures whose first iterate is not
# stationary, which an independent gap shows.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

const METHODS = (ProximalGradientDescent(), AccProxGradDescent())
const DEFAULT = ProximalOptions()
# Float32 and tight tolerances: the computed objective can increase by rounding near the minimizer, which
# stops a solve with converged = false unless allow_f_increases = true
const TIGHT = ProximalOptions(maxiter = 20_000, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-11, allow_f_increases = true)
const LONG = ProximalOptions(maxiter = 20_000, allow_f_increases = true)

lossof(α, y, X) = isone(α) ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)
name(method) = method isa ProximalGradientDescent ? "PGD" : "APG"

# ---- independent references, in BigFloat, from the T data as given -------------------------------------

# P(b) = α/2 ‖Xb - y‖² + λ max|bᵢ|
function primal(X, y, α, λ, β)
  setprecision(BigFloat, 256) do
    w = big.(X) * big.(β) - big.(y)
    big(α) / 2 * dot(w, w) + big(λ) * maximum(abs, big.(β))
  end
end

# The duality gap P(b) - D(u) and P(b), for u = α(Xb - y) scaled by min(1, λ/‖Xᵀu‖₁) (λ > 0), so that
# ‖Xᵀu‖₁ ≤ λ, and D(u) = -yᵀu - ‖u‖²/(2α). Weak duality gives gap ≥ 0.
function dualgap(X, y, α, λ, β)
  setprecision(BigFloat, 256) do
    Xb, yb, a, l = big.(X), big.(y), big(α), big(λ)
    u = a * (Xb * big.(β) - yb)
    s = norm(Xb' * u, 1)
    s > l && (u = u * (l / s))
    D = -dot(yb, u) - dot(u, u) / (2a)
    P = primal(X, y, α, λ, β)
    Float64(P - D), Float64(P)
  end
end
relgap(X, y, α, λ, β) = ((g, P) = dualgap(X, y, α, λ, β); g / P)

# λcrit = α‖Xᵀy‖₁ as a Float64
lambdacrit(X, y, α) = setprecision(BigFloat, 256) do
  Float64(big(α) * norm(big.(X)' * big.(y), 1))
end

# ‖G_t(b)‖₁ for t = 1/L at the point b, with the clip level found by sorting, not by ProximalBase:
# the proximal point of u = b - ∇f(b)/L is u - proj of u on the ℓ1-ball of radius λ/L
function mapping_residual(X, y, α, λ, β, L)
  setprecision(BigFloat, 256) do
    Xb, yb, bb = big.(X), big.(y), big.(β)
    u = bb - big(α) * (Xb' * (Xb * bb - yb)) / big(L)
    p = clip(u, big(λ) / big(L))
    big(L) * norm(bb - p, 1)
  end
end

# ‖∇f(b)‖₁ = α‖Xᵀ(Xb - y)‖₁ in BigFloat, formed directly (the mapping above forms b - u, which loses a
# gradient that is far below ‖b‖ at 256 bits)
gradnorm1(X, y, α, β) = setprecision(BigFloat, 256) do
  Xb = big.(X)
  big(α) * norm(Xb' * (Xb * big.(β) - big.(y)), 1)
end

# prox of r‖·‖∞ at u: the entries clipped at τ with Σ(|uᵢ| - τ)₊ = r, and 0 when r ≥ ‖u‖₁
function clip(u, r)
  a = sort(abs.(u); rev = true)
  r >= sum(a) && return zero.(u)
  c, τ = zero(r), zero(r)
  for k in eachindex(a)
    c += a[k]
    τ = (c - r) / k
    (k == length(a) || a[k + 1] <= τ) && break
  end
  sign.(u) .* min.(abs.(u), τ)
end

# ---- data ------------------------------------------------------------------------------------------

# A seeded design with AR(1) correlation ρ between neighbouring columns, column scales `scales`, and a
# response from the first columns with noise
function problem(::Type{T}, n, p; ρ = 0.0, seed = 1, scales = ones(p)) where T
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  for j in 2:p
    X[:, j] .= ρ .* X[:, j - 1] .+ sqrt(1 - ρ^2) .* X[:, j]
  end
  X .*= scales'
  β = zeros(p)
  β[1:min(p, 3)] .= (1.5, -1.0, 0.5)[1:min(p, 3)]
  y = X * β .+ 0.3 .* randn(rng, n)
  T.(X), T.(y)
end

function solve_case(method, X, y, α, λ, x0, options)
  T = eltype(X)
  x = copy(x0)
  r = solve!(x, lossof(α, y, X), NormLinf(T(λ)), method, options)
  x, r
end

# the largest tolerance on the relative gap of a converged run, by element type
gaptol(::Type{Float64}) = 1e-3
gaptol(::Type{Float32}) = 1e-2

# ---- the analytic case -------------------------------------------------------------------------------

@testset "analytic X = [1 1], y = [2], λ = 1: β* = (0.75, 0.75), P* = 0.875" begin
  for T in (Float64, Float32), method in METHODS, x0 in (T[0, 0], T[3, -2])
    X, y = T[1 1], T[2]
    βstar = T[0.75, 0.75]
    # the default options: the stop threshold is τ S = 1e-5 max(λ, λcrit = 4) (Float32: 64 eps if larger)
    x, r = solve_case(method, X, y, one(T), 1, x0, DEFAULT)
    @test r.converged
    @test maximum(abs, x - βstar) <= (T === Float64 ? 1e-4 : 1e-3)
    @test abs(r.minimum - 0.875) <= (T === Float64 ? 1e-6 : 1e-5)
    @test r.minimizer === x
    @test relgap(X, y, one(T), 1, x) <= gaptol(T)
    # tight options
    x, r = solve_case(method, X, y, one(T), 1, x0, TIGHT)
    @test r.converged
    @test maximum(abs, x - βstar) <= (T === Float64 ? 1e-6 : 1e-4)
    @test abs(r.minimum - 0.875) <= (T === Float64 ? 1e-9 : 1e-6)
    @test relgap(X, y, one(T), 1, x) <= (T === Float64 ? 1e-8 : 1e-5)
    # at β*: P* = 0.875 and the gap is 0
    @test primal(X, y, one(T), 1, βstar) == big"0.875"
  end
end

# ---- identity design: the minimizer is a clip, with a level found by sorting ------------------------

@testset "identity design: β = clip of y at the level of Σ(|yᵢ| - τ)₊ = λ, with ties" begin
  for T in (Float64, Float32), method in METHODS
    y = T[3, -3, 3, 1, -0.5, 0.25]
    X = Matrix{T}(I, 6, 6)
    for λ in (0.5, 2.0, 5.0, 9.0)
      τ = setprecision(BigFloat, 256) do
        a = sort(abs.(big.(y)); rev = true)
        # τ = (sum of the k largest - λ)/k for the k that makes it consistent
        best = zero(BigFloat)
        for k in 1:6
          c = (sum(a[1:k]) - big(λ)) / k
          (k == 6 || a[k + 1] <= c) && (best = c; break)
        end
        Float64(best)
      end
      βref = sign.(y) .* min.(abs.(y), T(τ))
      x, r = solve_case(method, X, y, one(T), λ, zeros(T, 6), TIGHT)
      @test r.converged
      @test maximum(abs, x - βref) <= (T === Float64 ? 1e-6 : 1e-4)
      # λ ≥ ‖y‖₁ = 10.75 would give 0; λ = 9 is below it
      @test maximum(abs, x) > 0
    end
  end
end

# ---- λ = 0: the least-squares solution -------------------------------------------------------------

@testset "λ = 0: the least-squares solution of a full-column-rank design" begin
  for T in (Float64, Float32), method in METHODS, scale in (one(T), T(1) / 30)
    X, y = problem(T, 30, 5; ρ = 0.3, seed = 3)
    βls = setprecision(BigFloat, 256) do
      Xb = big.(X)
      Float64.((Xb' * Xb) \ (Xb' * big.(y)))
    end
    x, r = solve_case(method, X, y, scale, 0, zeros(T, 5), TIGHT)
    @test r.converged
    @test maximum(abs, x - βls) <= (T === Float64 ? 1e-6 : 2e-3)
    # the QR solution of the Float64 problem is the same point
    T === Float64 && @test maximum(abs, x - (X \ y)) <= 1e-6
  end
end

# ---- λ ≥ λcrit = ‖∇f(0)‖₁: the zero solution; the lasso threshold ‖∇f(0)‖∞ is not the one ----------

@testset "λ at and above λcrit = α‖Xᵀy‖₁ gives 0; ‖∇f(0)‖∞ ≤ λ < ‖∇f(0)‖₁ does not" begin
  for T in (Float64, Float32), method in METHODS, α in (one(T), T(1) / 30)
    p = 6
    X, y = problem(T, 30, p; ρ = 0.5, seed = 5)
    λc = lambdacrit(X, y, α)
    c = 8
    λ = T((1 + c * p * eps(T)) * λc)
    x, r = solve_case(method, X, y, α, λ, zeros(T, p), DEFAULT)
    @test all(iszero, x)
    @test r.converged
    @test primal(X, y, α, λ, x) == big(α) / 2 * dot(big.(y), big.(y))
    for x0 in (zeros(T, p), T[0.1, -0.2, 0.05, 0.3, -0.1, 0.2])
      # 1.5 λcrit and 10 λcrit, from zero and from a nonzero start
      for m in (1.5, 10)
        x, r = solve_case(method, X, y, α, T(m * λc), x0, DEFAULT)
        @test all(iszero, x) && r.converged
      end
    end
    # at the margin of c p eps(T) from a nonzero start the iterates approach 0 and PB's zero fill needs
    # ‖∇f(0) + H x‖₁ ≤ λ, so the test asserts a small ‖x‖∞ at this margin
    x, r = solve_case(method, X, y, α, λ, T[0.1, -0.2, 0.05, 0.3, -0.1, 0.2], LONG)
    @test maximum(abs, x) <= (T === Float64 ? 1e-5 : 1e-3)
    # at λ = λcrit: a small ‖x‖∞ and a small gap (PB's zero fill may or may not apply)
    x, r = solve_case(method, X, y, α, λc, zeros(T, p), LONG)
    λ = T(λc)
    @test maximum(abs, x) <= (T === Float64 ? 1e-6 : 1e-3) * max(1, maximum(abs, y))
    @test primal(X, y, α, λ, x) - primal(X, y, α, λ, zeros(T, p)) <= big"1e-4"
  end
  # contrast: X = I, y = (2, 2, 2): ‖∇f(0)‖∞ = 2 ≤ λ = 3 < ‖∇f(0)‖₁ = 6, so the optimum is (1, 1, 1)
  for T in (Float64, Float32), method in METHODS
    X, y = Matrix{T}(I, 3, 3), T[2, 2, 2]
    x, r = solve_case(method, X, y, one(T), 3, zeros(T, 3), TIGHT)
    @test r.converged
    @test maximum(abs, x - ones(T, 3)) <= (T === Float64 ? 1e-6 : 1e-4)
  end
end

# ---- the grid: raw and scaled loss, starts, correlated, tied, badly scaled columns ------------------

@testset "grid: converged runs have a small independent duality gap" begin
  nconv = Dict{DataType, Int}(Float64 => 0, Float32 => 0)
  ncase = Dict{DataType, Int}(Float64 => 0, Float32 => 0)
  for T in (Float64, Float32), method in METHODS
    designs = (
      ("correlated", problem(T, 40, 8; ρ = 0.9, seed = 11)),
      ("independent", problem(T, 40, 8; ρ = 0.0, seed = 12)),
      ("scales", problem(T, 40, 8; ρ = 0.2, seed = 13, scales = [1, 3, 0.3, 1, 10, 0.1, 1, 2])),
      ("duplicate columns", let (X, y) = problem(T, 40, 6; ρ = 0.3, seed = 14)
        X[:, 4:6] .= X[:, 1:3]
        X, y
      end))
    for (label, (X, y)) in designs, α in (one(T), T(1) / 40, T(0.37)), frac in (0.05, 0.3, 0.8)
      p = size(X, 2)
      λ = T(frac * lambdacrit(X, y, α))
      for x0 in (zeros(T, p), T(0.2) .* T.(sign.(randn(Xoshiro(2), p))))
        x, r = solve_case(method, X, y, α, λ, x0, LONG)
        ncase[T] += 1
        r.converged && (nconv[T] += 1)
        # a converged run is near-optimal in the independent gap
        r.converged && @test relgap(X, y, α, λ, x) <= gaptol(T)
        @test isfinite(r.minimum)
      end
    end
  end
  # the grid is not vacuous: most of its runs converge (all in Float64)
  @test nconv[Float64] == ncase[Float64]
  @test nconv[Float32] >= 0.9 * ncase[Float32]
end

# ---- false convergence ---------------------------------------------------------------------------------

# The analytic problem from a start far from β* = (0.75, 0.75): the first accepted iterates are not
# stationary, which the independent gap shows. A stop proposed by xtol or ftol must not be kept. That the
# test did propose a stop at iteration 1 is read from the counters: the check adds one proximal evaluation,
# so with prox_calls_limit one above the engine's own count after iteration 1 (the count of a run stopped
# there by a callback, with no test proposing a stop) the solve ends at iteration 1 with the limit flag.
@testset "a stop proposed by xtol or ftol at a nonstationary iterate is not kept" begin
  for T in (Float64, Float32), method in METHODS
    X, y = T[1 1], T[2]
    f, g = lossof(one(T), y, X), NormLinf(T(1))
    far = T[50, -50]
    e0 = solve!(copy(far), f, g, method,
                ProximalOptions(xtol = 1e-300, ftol = 0, gradtol = 0, callback = _ -> true))
    @test e0.iterations == 1 && !e0.converged
    for (label, options) in (("huge xtol", (xtol = 1e10, ftol = 0, gradtol = 0)),
                             ("loose ftol", (xtol = 1e-300, ftol = 1e10, gradtol = 0)),
                             ("both", (xtol = 1e10, ftol = 1e10, gradtol = 0)))
      x = copy(far)
      r = solve!(x, f, g, method, ProximalOptions(; maxiter = 5, options..., prox_calls_limit = e0.prox_calls + 1))
      @test r.iterations == 1 && r.call_limit_reached           # a stop was proposed and counted
      @test !r.converged && !r.x_converged && !r.f_converged && !r.grad_converged
      @test relgap(X, y, one(T), 1, x) > 1e-2                    # the iterate is not stationary
      # without the limit the solve goes on from that iterate, and a converged run has a small gap
      x = copy(far)
      r = solve!(x, f, g, method, ProximalOptions(; maxiter = 5_000, options...))
      @test r.iterations > 1
      @test !r.converged || relgap(X, y, one(T), 1, x) <= 1e-2
    end
    # a loose gradtol sets the bar of the check as well as the test: a kept stop satisfies the independent
    # residual bound τ S, with S = max(λ, λcrit) = 4, for the curvature of the last accepted step
    for gradtol in (1e-2, 1e-3, 1e-4)
      x = copy(far)
      r = solve!(x, f, g, method, ProximalOptions(maxiter = 5_000, gradtol = gradtol, ftol = 0, store_trace = true))
      τS = max(gradtol, 64 * Float64(eps(T))) * 4
      @test r.converged
      @test mapping_residual(X, y, one(T), 1, x, r.trace[end].L) <= τS * 1.001
    end
  end
end

@testset "an iterate that did not change, with a step that rounds away, is not kept" begin
  # Float32, λ = 0, X = diag(1, 0.01), y = (0, 0.01), x = (0, 1.0001): ∇f = (0, 1e-8), so ‖∇f‖₁ = 1e-8
  # is above τ S = 1e-5 · ‖Xᵀy‖₁ = 1e-9, while x - ∇f/L rounds to x for L of order 1
  X, y = Float32[1 0; 0 0.01], Float32[0, 0.01]
  x0 = Float32[0, 1.0001]
  grad = Float32.(Float64.(X)' * (Float64.(X) * Float64.(x0) - Float64.(y)))
  @test abs(grad[2]) > 1e-9 * 1.0 && x0[2] - grad[2] / 0.9f0 == x0[2]
  for method in METHODS
    x, r = solve_case(method, X, y, 1f0, 0, x0, ProximalOptions(maxiter = 3))
    @test !r.converged
    # the independent residual at the returned point exceeds the threshold
    τS = 1f-5 * lambdacrit(X, y, 1f0)
    @test mapping_residual(X, y, 1f0, 0, x, 1.0) > τS
  end
end

# The check on a hand-built state. The problem X = [1 1], y = [2], λ = 1 has ∇f(0) = (-2, -2),
# λcrit = ‖∇f(0)‖₁ = 4, β* = (0.75, 0.75).
function check_at(method, T, x, L; λ = 1, α = one(T), y = T[2], options = ProximalOptions(), level = T(λ))
  f = lossof(α, y, T[1 1])
  g = NormLinf(level)
  state = PS.initial_state(method, options, f, g, T.(x))
  state.x_previous .= state.x .+ T(1) / 8
  state.delta_x .= state.x .- state.x_previous
  state.L = T(L)
  PS._stationary!(state, f, g, options), state
end

@testset "_stationary! at hand-built states" begin
  for T in (Float64, Float32), method in METHODS
    # (a) x = β*, L = 2: u = x - ∇f/L = (1, 1) and the clip level is 0.75, so r = 0
    @test check_at(method, T, [0.75, 0.75], 2)[1]
    # (b) x = (0.5, 0.5): ∇f = (-1, -1), u = (1, 1), p = (0.75, 0.75), r = 2 · 0.5 = 1, far above 4e-5
    @test !check_at(method, T, [0.5, 0.5], 2)[1]
    # (c) x = 0 and λ = 5 ≥ λcrit = 4: u = (1, 1), tλ = 2.5 ≥ ‖u‖₁ = 2, the zero fill, r = 0
    @test check_at(method, T, [0, 0], 2; λ = 5)[1]
    # λ = 3 < λcrit at x = 0: not stationary (the optimum is nonzero)
    @test !check_at(method, T, [0, 0], 2; λ = 3)[1]
    # (d) L = 0, Inf, NaN, a subnormal 1/L, a negative L
    for L in (0, Inf, NaN, -2)
      @test !check_at(method, T, [0.75, 0.75], L)[1]
    end
    big_L = T === Float64 ? 1e308 : 3f38      # t = 1/L is subnormal for L > 1/floatmin(T)
    @test issubnormal(one(T) / big_L)
    @test !check_at(method, T, [0.75, 0.75], big_L)[1]
    # S = 0: y = 0 and λ = 0
    @test !check_at(method, T, [0.75, 0.75], 2; λ = 0, y = T[0])[1]
    # a non-finite rounding resolution: ‖x‖₁ overflows
    big_x = T === Float64 ? floatmax(Float64) * 0.6 : floatmax(Float32) * 0.6f0
    ok, state = check_at(method, T, [big_x, -big_x], 2)
    @test !ok
    # S = max(λ, λcrit) is not finite: ‖∇f(0)‖₁ = 1.6 floatmax overflows (x = 0.4 floatmax on both
    # coordinates has the finite value 0, so the state can be built), where r = 0 and ρ is finite
    fm = floatmax(T)
    @test !check_at(method, T, [0.4 * fm, 0.4 * fm], 2; y = T[0.8 * fm])[1]
    # the check counts one proximal evaluation, and for APG one gradient, and no function value
    ok, state = check_at(method, T, [0.75, 0.75], 2)
    ref = PS.initial_state(method, ProximalOptions(), lossof(one(T), T[2], T[1 1]), NormLinf(T(1)), T[0.75, 0.75])
    @test state.prox_calls == ref.prox_calls + 1
    @test state.grad_calls == ref.grad_calls + (method isa AccProxGradDescent ? 1 : 0)
    @test state.f_calls == ref.f_calls
    # λcrit is cached with the 1-norm
    @test state.λmax == 4
  end
end

@testset "the rounding resolution ρ of the displacement is load-bearing (Float32)" begin
  # λ = 0, X = diag(1, 0.01), y = (0, 0.01c), x = (0, c(1 + 1e-4)), c = 1, L = 1: ∇f = (0, 1e-8 c), the
  # step 1e-8 c is below half an ulp of x₂ ≈ c, so x - ∇f/L = x and r computes as 0, while
  # ‖∇f‖₁ = 1e-8 c exceeds τ S = 1e-5 ‖Xᵀy‖₁ = 1e-9 c
  T = Float32
  X, y = T[1 0; 0 0.01], T[0, 0.01]
  x = T[0, 1.0001]
  g = Float64.(X)' * (Float64.(X) * Float64.(x) - Float64.(y))
  τS = 1e-5 * Float64(lambdacrit(X, y, one(T)))
  @test norm(g, 1) > 5 * τS                       # the true residual (L = 1, λ = 0) exceeds the threshold
  @test x - T.(g) == x                            # the step rounds away in Float32
  for method in METHODS
    f = LeastSquaresLoss(y, X)
    state = PS.initial_state(method, ProximalOptions(), f, NormLinf(T(0)), x)
    state.x_previous .= x
    state.L = 1
    @test !PS._stationary!(state, f, NormLinf(T(0)), ProximalOptions())
    @test mapping_residual(X, y, 1, 0, x, 1) > 5 * τS
  end
end

@testset "Float32: a fixed point of the computed map with many clipped entries is not kept when k eps(T) is large" begin
  # X = I, α = 1, λ = a fraction of ‖y‖₁, L = 1: u = x - ∇f(x) = y, and x = the computed clip of y is a fixed
  # point of the computed map (r = 0). The BigFloat residual is far below τ S in both cases, and the clip-level
  # term L eps(T) k s of ρ exceeds τ S for k = 200 clipped entries and not for k = 10 (about k > 84 at the
  # default gradtol, as ρ's other term is small here): the refusal is the check's guard and not a nonzero residual
  T = Float32
  for (A, frac, kept) in ((10, 0.5, true), (200, 0.9, false))
    rng = Xoshiro(7 * A + 1)
    p = A + 3
    y = T.(vcat(2 .* sign.(randn(rng, A)) .* (1 .+ T(1e-7) .* randn(rng, A)), 0.1 .* randn(rng, 3)))
    λ = T(frac * sum(abs, y))
    X = Matrix{T}(I, p, p)
    x = zeros(T, p)
    value_and_prox!(x, NormLinf(λ), y, one(T))
    τS = 1e-5 * max(Float64(λ), lambdacrit(X, y, one(T)))
    @test mapping_residual(X, y, 1, λ, x, 1) < 0.01 * τS
    for method in METHODS
      f, g = LeastSquaresLoss(y, X), NormLinf(λ)
      state = PS.initial_state(method, ProximalOptions(), f, g, copy(x))
      state.x_previous .= x
      state.L = 1
      @test PS._stationary!(state, f, g, ProximalOptions()) == kept
    end
  end
end

# ---- output consistency ----------------------------------------------------------------------------

@testset "the value of the result and the fused proximal value" begin
  for T in (Float64, Float32), method in METHODS
    X, y = problem(T, 30, 5; ρ = 0.5, seed = 21)
    α = T(1) / 30
    λ = T(0.4 * lambdacrit(X, y, α))
    x, r = solve_case(method, X, y, α, λ, zeros(T, 5), LONG)
    @test r.minimizer === x
    @test r.minimum isa T
    @test abs(Float64(r.minimum) - Float64(primal(X, y, α, λ, x))) <= 4 * eps(T) * Float64(primal(X, y, α, λ, x))
    # ProximalBase's fused value equals g at the stored output
    g = NormLinf(λ)
    u = T[0.9, -0.2, 0.6, 1.3, -1.1]
    out = similar(u)
    for γ in (T(0.1), T(0.5), T(2))
      v = value_and_prox!(out, g, u, γ)
      @test v == g(out)
    end
  end
end

@testset "a proposed stop adds one proximal evaluation (and one gradient for APG) to the engine's counts" begin
  # at x0 = 0 with λ above λcrit the first accepted iterate is 0 and the stop it proposes passes the check,
  # so the solve ends at iteration 1 whether the engine's counts are those of a run stopped there by a
  # callback with no test proposing a stop
  nostop = (xtol = 1e-300, ftol = 0, gradtol = 0)
  for T in (Float64, Float32), method in METHODS
    X, y = T[1 1], T[2]
    f = lossof(one(T), y, X)
    g = NormLinf(T(5))
    a = solve!(zeros(T, 2), f, g, method, ProximalOptions())
    b = solve!(zeros(T, 2), f, g, method, ProximalOptions(; nostop..., callback = _ -> true))
    @test a.converged && a.iterations == 1 && b.iterations == 1 && !b.converged
    @test a.prox_calls == b.prox_calls + 1
    @test a.grad_calls == b.grad_calls + (method isa AccProxGradDescent ? 1 : 0)
    @test a.f_calls == b.f_calls
    # a stop at the limit: the count is made before the limit flag is read
    c = solve!(zeros(T, 2), f, g, method, ProximalOptions(prox_calls_limit = b.prox_calls + 1))
    @test c.converged && c.call_limit_reached
    d = solve!(zeros(T, 2), f, g, method, ProximalOptions(prox_calls_limit = b.prox_calls))
    @test d.call_limit_reached
  end
end

@testset "PGD: delta_x and the gradient residual are those the line search left" begin
  for T in (Float64, Float32)
    X, y = T[1 1], T[2]
    f, g = lossof(one(T), y, X), NormLinf(T(1))
    method = ProximalGradientDescent()
    # the check ran at the end of a converged run; the same run stopped at that iteration by a callback
    # with no proposal has the residuals the line search left
    a = solve!(T[3, -2], f, g, method, ProximalOptions())
    @test a.converged
    stopat(k) = ProximalOptions(; xtol = 1e-300, ftol = 0, gradtol = 0, maxiter = 1000,
                                  callback = tr -> tr.iteration >= k, print_every = 1)
    b = solve!(T[3, -2], f, g, method, stopat(a.iterations))
    @test b.iterations == a.iterations
    @test a.g_residual === b.g_residual && a.x_residual === b.x_residual
    # on a hand-built state the check leaves delta_x bitwise as it was
    ok, state = check_at(method, T, [0.75, 0.75], 2)
    @test state.delta_x == state.x .- state.x_previous
    before = copy(state.delta_x)
    PS._stationary!(state, f, g, ProximalOptions())
    @test state.delta_x == before
  end
end

# a function barrier gives the call concrete argument types
alloc_check(state, f, g, options) = @allocated PS._stationary!(state, f, g, options)
@testset "the check allocates nothing for levels of native and small scalar types, and writes nothing into the caller's NormLinf" begin
  # Float32 and Float64 levels, and Int, Float16 and Rational{Int} levels, whose zero is measured here: with such
  # levels ProximalBase's scalar arithmetic in each prox does not allocate
  for T in (Float64, Float32), method in METHODS, level in (T(1), 1.0, 1, Float16(1), 1 // 1)
    f = LeastSquaresLoss(T[2], T[1 1])
    g = NormLinf(level)
    o = ProximalOptions()
    state = PS.initial_state(method, o, f, g, T[0.5, 0.5])
    state.x_previous .= state.x
    PS._stationary!(state, f, g, o)
    @test alloc_check(state, f, g, o) == 0
    # the buffer of g is untouched (a field of the pinned ProximalBase object): ProximalBase uses the
    # distinct output as its threshold buffer
    @test g.scratch.buf === nothing
  end
end

@testset "BigFloat and Rational{BigInt} levels: correct result and untouched scratch (their scalar arithmetic allocates)" begin
  # PB forms the radius in a BigFloat product for these levels, which allocates in each prox, in the engines and in the
  # check (as for NormL1 and ElasticNet levels of these types); no zero-allocation claim is made and none is tested
  for T in (Float64, Float32), method in METHODS, level in (big"1.0", big(1) // big(1))
    @test check_at(method, T, [0.75, 0.75], 2; level)[1]
    @test !check_at(method, T, [0.5, 0.5], 2; level)[1]
    g = NormLinf(level)
    @test check_at(method, T, [0.75, 0.75], 2; level)[2].prox_calls == 1
    x = zeros(T, 2)
    r = solve!(x, LeastSquaresLoss(T[2], T[1 1]), g, method, TIGHT)
    @test r.converged && maximum(abs, x - T[0.75, 0.75]) <= (T === Float64 ? 1e-6 : 1e-4)
    @test abs(r.minimum - 0.875) <= (T === Float64 ? 1e-9 : 1e-6)
    @test g.scratch.buf === nothing
  end
end

# The rounding allowance keeps its scale when L is subnormal (#338 review): ρ = ((‖x‖₁ + k s) eps(T)) L. With the
# product L eps(T) formed first it rounds to 0 for L ≈ 4e-39 (Float32) or 1e-308 (Float64), and an unchanged,
# nonstationary iterate (λ = 0, so G_t = ∇f for every t) was declared converged at iteration 1.
@testset "a subnormal L does not remove the rounding allowance: no false convergence through solve!" begin
  cases = ((Float32, 1e-22, 1e8, 1.001e30, 4e-39), (Float64, 1e-160, 1e10, 1.00003e170, 1e-308))
  for (T, xv, yv, x0, a) in cases, scale in (1, 2)
    X, y = fill(T(xv), 1, 1), T[yv]
    @test T(a) * eps(T) == 0                              # the product that failed rounds to 0 for this L
    for method in (ProximalGradientDescent(ls = PS.LineSearches.BackTracking(α = T(a))), AccProxGradDescent(α = T(a)))
      f = scale == 1 ? LeastSquaresLoss(y, X) : T(scale) * LeastSquaresLoss(y, X)
      x = T[x0]
      # a callback ends the solve after iteration 1, where the proposed stop was declared converged: with the
      # refusal the solve would go on (its line search later fails at this extreme initial α, which is not
      # the subject here)
      r = solve!(x, f, NormLinf(zero(T)), method, ProximalOptions(callback = _ -> true))
      @test r.iterations == 1 && !r.converged && !r.x_converged
      # independent: λ = 0, the mapping is ∇f, which is above τ S at the returned point
      α = T(scale)
      τS = max(1e-5, 64 * Float64(eps(T))) * lambdacrit(X, y, α)
      @test Float64(gradnorm1(X, y, α, x)) > τS
    end
  end
end

@testset "ρ underflows before the multiplication by L: a nonzero allowance that loses its scale is not kept" begin
  # Float32, λ = 0, X = [1], y = [1e-12], x = [1e-40] (subnormal), L = 1e36: x - ∇f/L = x (the step 1e-48 is below the
  # smallest subnormal), so r = 0; (‖x‖₁ eps(T)) = 1.2e-47 rounds to 0 while the true allowance, 1.2e-11, is far above
  # τ S = 1e-17
  T = Float32
  for method in METHODS
    f, g = LeastSquaresLoss(T[1e-12], fill(T(1), 1, 1)), NormLinf(zero(T))
    state = PS.initial_state(method, ProximalOptions(), f, g, T[1e-40])
    state.x_previous .= state.x
    state.L = 1e36
    @test !PS._stationary!(state, f, g, ProximalOptions())
    @test mapping_residual(fill(T(1), 1, 1), T[1e-12], one(T), 0, T[1e-40], 1) > 1e-5 * 1e-12
  end
end

@testset "no proximal evaluation when the guard on L and 1/L returns first" begin
  # Float32, X = [1e19], y = [1], λ = 0, x = 0: the accepted L is about 1e38, so 1/L is subnormal and the check returns
  # before the proximal operator; APG's gradient is formed before the guard and is counted
  T = Float32
  f, g = LeastSquaresLoss(T[1], fill(T(1e19), 1, 1)), NormLinf(zero(T))
  for method in METHODS
    a = solve!(T[0], f, g, method, ProximalOptions(xtol = 1e10, ftol = 0, gradtol = 0, callback = _ -> true))
    b = solve!(T[0], f, g, method, ProximalOptions(xtol = 1e-300, ftol = 0, gradtol = 0, callback = _ -> true))
    @test a.iterations == 1 && b.iterations == 1 && !a.converged
    @test a.prox_calls == b.prox_calls
    @test a.grad_calls == b.grad_calls + (method isa AccProxGradDescent ? 1 : 0)
  end
end

@testset "trace and extended trace" begin
  for T in (Float64, Float32), method in METHODS
    X, y = T[1 1], T[2]
    f, g = lossof(one(T), y, X), NormLinf(T(1))
    r = solve!(T[3, -2], f, g, method, ProximalOptions(store_trace = true))
    @test length(r.trace) == r.iterations && r.converged
    @test r.trace[end].fg_x ≈ Float64(r.minimum) rtol = 1e-5
    r = solve!(T[3, -2], f, g, method, ProximalOptions(store_trace = true, extended_trace = true))
    @test length(r.trace) == r.iterations && haskey(r.trace[end].metadata, "x")
    @test r.trace[end].metadata["x"] == r.minimizer
    @test all(isfinite, r.trace[end].metadata[method isa ProximalGradientDescent ? "grad_f(x)" : "grad_f(y)"])
  end
end

@testset "a step error restores the last accepted x (PGD)" begin
  # 2α‖X d‖²/‖d‖² = 4.5e38 exceeds floatmax(Float32): the rejection is checked, the curvature is Inf
  # as a Float32, and next_curvature raises (the pattern of test/core_regressions.jl)
  f = LeastSquaresLoss(Float32[1], fill(1.5f19, 1, 1))
  g = NormLinf(0f0)
  method = ProximalGradientDescent()
  state = PS.initial_state(method, ProximalOptions(), f, g, Float32[0])
  state.backtrack_simple = false
  state.L = 2.2f38
  @test_throws r"curvature estimate cannot increase finitely" PS._solve_gradient!(state, f, g, method, ProximalOptions())
  @test state.x == Float32[0]
end

# ---- refusals before any change of x ---------------------------------------------------------------------

function refused(x, f, g, method, msg::AbstractString, E = ArgumentError)
  original = copy(x)
  @test_throws E(msg) solve!(x, f, g, method)
  @test isequal(x, original)
end
function refused(x, f, g, method, E::Type)
  original = copy(x)
  @test_throws E solve!(x, f, g, method)
  @test isequal(x, original)
end

@testset "the gradient methods refuse what they do not support, before changing x" begin
  for T in (Float64, Float32), method in METHODS
    X, y, x = T[1 0; 0 2], T[1, -1], T[.3, -.2]
    f = LeastSquaresLoss(y, X)
    g = NormLinf(T(.1))
    @test solve!(copy(x), f, g, method).minimum isa T                  # the accepted problem
    refused(x, f, Scaled(g, 2), method, "only unweighted NormL1, unweighted ElasticNet or NormLinf is supported")
    # a negative or NaN level cannot be constructed (ProximalBase refuses it); an infinite one can
    @test_throws ArgumentError NormLinf(-one(T))
    @test_throws ArgumentError NormLinf(T(NaN))
    refused(x, f, NormLinf(T(Inf)), method, "penalty lambda must be finite and nonnegative")
    if T === Float32
      refused(x, f, NormLinf(1e300), method, "penalty lambda is not representable without overflow or underflow in Float32")
      refused(x, f, NormLinf(1e-50), method, "penalty lambda is not representable without overflow or underflow in Float32")
    else
      refused(x, f, NormLinf(big"1e400"), method, ArgumentError)
    end
    # an unsupported loss
    refused(x, SqrNormL2(T(1)), g, method, "only LeastSquaresLoss or one positive Scaled(LeastSquaresLoss) is supported")
    # a shape mismatch
    refused(zeros(T, 3), f, g, method, "x/y dimensions do not match X", DimensionMismatch)
    # an x that aliases the data
    ya = T[1, 2]
    refused(ya, LeastSquaresLoss(ya, X), g, method, "mutable x must not alias borrowed X or y")
    X1 = T[1 2 3 4]
    refused(vec(X1), LeastSquaresLoss(T[1], X1), g, method, "mutable x must not alias borrowed X or y")
    # mixed element types
    other = T === Float32 ? Float64 : Float32
    refused(other.(x), f, g, method, ArgumentError)
    refused(x, LeastSquaresLoss(other.(y), X), g, method, ArgumentError)
    # nonfinite data and iterate
    Xn = copy(X); Xn[1, 1] = T(NaN)
    refused(x, LeastSquaresLoss(y, Xn), g, method, "x, X and y must contain only finite values")
    refused(T[Inf, 0], f, g, method, "x, X and y must contain only finite values")
    yn = copy(y); yn[2] = T(Inf)
    refused(x, LeastSquaresLoss(yn, X), g, method, "x, X and y must contain only finite values")
    # a SparseIterate and an integer vector are not iterates of the gradient methods
    refused(SparseIterate(x), f, g, method, "x must be a dense Vector{Float32} or Vector{Float64}")
    refused(Int[0, 0], f, g, method, "x must be a dense Vector{Float32} or Vector{Float64}")
    # the gradient gate's message for an unsupported penalty names NormLinf
    refused(x, f, SqrNormL2(T(.1)), method, "only unweighted NormL1, unweighted ElasticNet or NormLinf is supported")
    @test x == T[.3, -.2]
    # a zero level is accepted; the solution is the least-squares one
    @test solve!(copy(x), f, NormLinf(zero(T)), method, TIGHT).converged
  end
end

@testset "CDSolver refuses NormLinf for every iterate, before any change of x or of the RNG" begin
  msg = "CDSolver does not support NormLinf (its coordinate step needs a separable penalty); use ProximalGradientDescent or AccProxGradDescent"
  for T in (Float64, Float32)
    X, y, x = T[1 0; 0 2], T[1, -1], T[.3, -.2]
    f = LeastSquaresLoss(y, X)
    g = NormLinf(T(.1))
    for start in (copy(x), SparseIterate(copy(x)), SparseIterate(T, 2))
      rng = Xoshiro(1)
      before = copy(rng)
      original = Vector(start)
      @test_throws ArgumentError(msg) solve!(start, f, g, CDSolver(rng = rng))
      @test Vector(start) == original
      @test rng == before && rand(rng) == rand(before)
    end
    # the level is not examined first: an unrepresentable level gets the same message
    @test_throws ArgumentError(msg) solve!(copy(x), f, NormLinf(T(Inf)), CDSolver())
    # a BlockIterate is refused by the group gate, which takes a GroupNormL2
    for xb in (BlockIterate(T, 2, [1:1, 2:2]),)
      rng = Xoshiro(1)
      before = copy(rng)
      err = try solve!(xb, f, g, CDSolver(rng = rng)) catch e e end
      @test err isa ArgumentError && occursin("BlockIterate needs a GroupNormL2 penalty", sprint(showerror, err))
      @test Vector(xb) == zeros(T, 2)
      @test rng == before
    end
    # the penalties that CD accepts keep their messages
    refused(copy(x), f, SqrNormL2(T(.1)), CDSolver(), "only unweighted NormL1 or unweighted ElasticNet is supported")
  end
end

@testset "the validation of the penalty keeps its 3-argument form" begin
  @test PS._check_penalty(NormL1(0.1f0), Float32[1], Float32) === nothing
  @test PS._check_penalty(NormL1(0.1), Float32[1], Float32, :gradient) === nothing
  @test PS._check_penalty(NormLinf(0.1), Float32[1], Float32, :gradient) === nothing
  @test_throws ArgumentError PS._check_penalty(NormLinf(0.1), Float32[1], Float32)        # fail closed
  @test_throws ArgumentError PS._check_penalty(NormLinf(0.1), Float32[1], Float32, :cd)
  @test PS._check_penalty(GroupNormL2(0.1, [1:1, 2:2]), BlockIterate(Float32, 2, [1:1, 2:2]), Float32, :block) === nothing
  @test_throws ArgumentError PS._check_penalty(NormLinf(0.1), BlockIterate(Float32, 2, [1:1, 2:2]), Float32, :block)
end

end
