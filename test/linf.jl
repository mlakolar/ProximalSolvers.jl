module LinfTests
# NormLinf(λ) with ProximalGradientDescent and AccProxGradDescent on the least-squares loss
# ½α‖Xb - y‖² + λ‖b‖∞ (α = 1 for a raw LeastSquaresLoss, 1/n and another positive α with a Scaled one).
# The stopping check of a proposed stop is the direct KKT residual r(x) = min over v in ∂‖x‖∞ of ‖∇f(x) + λ v‖₁
# against max(gradtol, 64 eps(T)) max(λ, ‖∇f(0)‖₁) (src/utils.jl). The references do not use ProximalBase's ℓ∞
# proximal operator, and the two solvers are not compared with each other: the analytic minimizer of
# X = [1 1], y = [2], λ = 1; the clip of an identity design, with a clip level found by sorting; the least-squares
# solution at λ = 0; the zero solution above λcrit = ‖∇f(0)‖₁; the duality gap P(b) - D(u) of a converged run, with the
# dual point u = α(Xb - y) scaled into {‖Xᵀu‖₁ ≤ λ}; and the KKT residual itself, as a closed form that is checked here
# against an exact (rational) enumeration of its minimization, evaluated in 4096-bit BigFloat with the gradient formed
# from the data as given at the stored x. `converged` is a stopping flag, not an accuracy certificate: accuracy comes
# from the references, and the flag is checked for what the stopping rule of src/utils.jl says about it (a proposed
# stop passes the residual check, or the solve goes on). The `ProximalOptions` that stop a solve at its first iterate
# (a huge xtol, a loose ftol or gradtol) are used with fixtures whose first iterate is not stationary, which an
# independent residual shows.
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

# r(x) = min over v in ∂‖x‖∞ of ‖g + λ v‖₁ for g = ∇f(x) given: the closed form off + N + |λ - P| (max(‖g‖₁ - λ, 0) at x = 0),
# written here independently of src/utils.jl and checked against an exact enumeration below
function rkkt_ref(x, g, λ)
  m = maximum(abs, x)
  iszero(m) && return max(sum(abs, g) - λ, zero(λ))
  M = [i for i in eachindex(x) if abs(x[i]) == m]
  a = [sign(x[i]) * g[i] for i in M]
  off = sum((abs(g[i]) for i in eachindex(g) if i ∉ M); init = zero(λ))
  off + sum(max.(a, 0)) + abs(λ - sum(max.(-a, 0)))
end

# r(x)/(τ S) at the stored x, in 4096-bit BigFloat from the data as given, with τ = max(gradtol, 64 eps(T)), S = max(λ, α‖Xᵀy‖₁)
function kkt_ratio(X, y, α, λ, x; gradtol = 1e-5)
  T = eltype(X)
  setprecision(BigFloat, 4096) do
    Xb, yb, xb, lb = big.(X), big.(y), big.(x), big(T(λ))
    g = big(α) * (Xb' * (Xb * xb - yb))
    S = max(lb, big(α) * norm(Xb' * yb, 1))
    τ = big(T(max(gradtol, 64 * Float64(eps(T)))))
    Float64(rkkt_ref(xb, g, lb) / (τ * S))
  end
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

# ---- the closed form of the residual -------------------------------------------------------------------

const Q = Rational{BigInt}

# min over the simplex {w ≥ 0, Σw = 1} of Σ|sgᵢ + λ wᵢ|: the minimum of a convex piecewise-linear function on a polytope is
# attained at a vertex of the subdivision by the hyperplanes wᵢ = 0 and wᵢ = κᵢ = -sgᵢ/λ; such a vertex fixes q - 1
# coordinates (each at 0 or at its kink) and takes the last one from Σw = 1
function simplex_min(sg::Vector{Q}, λ::Q)
  q = length(sg)
  λ == 0 && return sum(abs, sg)
  κ = -sg ./ λ
  best = nothing
  for free in 1:q
    others = [i for i in 1:q if i != free]
    for choice in Iterators.product(ntuple(_ -> (false, true), q - 1)...)
      w = zeros(Q, q)
      for (j, i) in enumerate(others)
        w[i] = choice[j] ? κ[i] : zero(Q)
      end
      w[free] = 1 - sum(w[others])
      all(>=(0), w) || continue
      val = sum(abs.(sg .+ λ .* w))
      best = best === nothing ? val : min(best, val)
    end
  end
  best
end

# min over the ℓ1 ball {‖v‖₁ ≤ 1} of Σ|gᵢ + λ vᵢ|: vertices of the arrangement of the kink planes vᵢ = -gᵢ/λ and the facets
# s·v = 1 (s ∈ {±1}^q), q independent planes, kept when inside the ball
function ball_min(g::Vector{Q}, λ::Q)
  q = length(g)
  λ == 0 && return sum(abs, g)
  planes = Tuple{Vector{Q}, Q}[]
  for i in 1:q
    e = zeros(Q, q); e[i] = 1
    push!(planes, (e, -g[i] / λ))
  end
  for s in Iterators.product(ntuple(_ -> (Q(-1), Q(1)), q)...)
    push!(planes, (collect(Q, s), Q(1)))
  end
  best = nothing
  for idx in Iterators.product(ntuple(_ -> 1:length(planes), q)...)
    issorted(idx; lt = <=) || continue
    A = Matrix{Q}(reduce(vcat, (planes[i][1]' for i in idx)))
    b = [planes[i][2] for i in idx]
    iszero(det(A)) && continue
    v = A \ b
    sum(abs, v) <= 1 || continue
    val = sum(abs.(g .+ λ .* v))
    best = best === nothing ? val : min(best, val)
  end
  best
end

@testset "the closed form of the residual against an exact enumeration of its minimization (|M| ≤ 3)" begin
  rng = Xoshiro(338)
  rnd() = Q(rand(rng, -9:9), rand(rng, 1:7))
  for _ in 1:1500            # x ≠ 0: ties (|M| = 1, 2, 3 entries at ±m), entries off M, signs, λ ≥ 0 including 0
    q, noff = rand(rng, 1:3), rand(rng, 0:2)
    m = Q(rand(rng, 1:5), 2)
    s = [rand(rng, Bool) ? Q(1) : Q(-1) for _ in 1:q]
    x = vcat(s .* m, [sign(rnd()) * m * Q(rand(rng, 0:19), 20) for _ in 1:noff])   # |xᵢ| < m off M
    g = [rnd() for _ in 1:(q + noff)]
    perm = randperm(rng, q + noff); x, g = x[perm], g[perm]
    λ = rand(rng, 1:6) == 1 ? Q(0) : Q(rand(rng, 0:12), rand(rng, 1:5))
    inM = [abs(xi) == m for xi in x]
    ref = sum(abs, g[.!inM]; init = Q(0)) + simplex_min([sign(x[i]) * g[i] for i in findall(inM)], λ)
    @test PS._linf_kkt_residual(x, g, λ) == ref
    @test rkkt_ref(x, g, λ) == ref
  end
  for _ in 1:200             # x = 0: the unit ℓ1 ball
    q = rand(rng, 1:3)
    g = [rnd() for _ in 1:q]
    λ = rand(rng, 1:6) == 1 ? Q(0) : Q(rand(rng, 0:12), rand(rng, 1:5))
    @test PS._linf_kkt_residual(zeros(Q, q), g, λ) == ball_min(g, λ)
  end
end

@testset "_linf_kkt_residual at hand-built points: worked values, signs, ties, λ = 0, x = 0, a near-tie" begin
  for T in (Float64, Float32)
    X, y = T[1 1], T[2]
    grad(x) = X' * (X * x - y)
    res(x, λ) = PS._linf_kkt_residual(x, grad(x), T(λ))
    # X = [1 1], y = [2], λ = 1
    @test res(T[0.75, 0.75], 1) == 0
    @test res(T[0.5, 0.5], 1) == 1
    @test res(T[0.75, 0.5], 1) == 1
    @test res(T[0.5, 0.5], 0) == 2                      # λ = 0: ‖g‖₁
    # signs: x = (-0.75, 0.75) has g = (-2, -2), s = (-1, 1): N = 2, P = 2, r = 2 + |1 - 2| = 3
    @test res(T[-0.75, 0.75], 1) == 3
    # a tie of three, g = (-1, -2, 0.5): N = 0.5, P = 3, r = 0.5 + |1 - 3| = 2.5; and entries off M
    @test PS._linf_kkt_residual(T[1, 1, 1], T[-1, -2, 0.5], T(1)) == 2.5
    @test PS._linf_kkt_residual(T[2, 1, -2], T[-1, 3, 1], T(1)) == 4       # M = {1, 3}, off = 3, N = 0, P = 2
    # x = 0, ∇f(0) = (-2, -2), ‖∇f(0)‖₁ = 4: max(4 - λ, 0)
    @test res(T[0, 0], 5) == 0 && res(T[0, 0], 4) == 0 && res(T[0, 0], 3) == 1 && res(T[0, 0], 0) == 4
    @test res(T[-0.0, 0.0], 3) == 1                      # signed zeros are zero
    # a near-tie that is not bitwise: only the larger entry is in M, so r is the exact residual of the stored point, about 1
    δ = T === Float64 ? 1e-8 : 1e-6
    xn = T[0.75, 0.75 * (1 - δ)]
    @test xn[1] != xn[2]
    @test abs(res(xn, 1) - 1) <= 1e-5
  end
end

# ---- the check on hand-built states --------------------------------------------------------------------

# The check on a hand-built state. The problem X = [1 1], y = [2], λ = 1 has ∇f(0) = (-2, -2),
# λcrit = ‖∇f(0)‖₁ = 4, β* = (0.75, 0.75). The curvature L is set only to complete the state: the check does not read it.
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
    @test check_at(method, T, [0.75, 0.75], 2)[1]                 # x = β*: r = 0
    @test !check_at(method, T, [0.5, 0.5], 2)[1]                  # r = 1, far above τ S = 1e-5 · 4
    @test check_at(method, T, [0, 0], 2; λ = 5)[1]                # x = 0, λ ≥ λcrit: r = 0
    @test check_at(method, T, [0, 0], 2; λ = 4)[1]                # λ = λcrit: r = 0
    @test !check_at(method, T, [0, 0], 2; λ = 3)[1]               # r = 1: the optimum is not 0
    # the curvature is not read: the same decision for any L, including the values that a mapping would not evaluate
    for L in (0, Inf, NaN, -2, 1e-40, 1e38)
      @test check_at(method, T, [0.75, 0.75], L)[1]
      @test !check_at(method, T, [0.5, 0.5], L)[1]
    end
    # a near-tie that is not bitwise is refused: only the larger entry is in M, r ≈ 1
    δ = T === Float64 ? 1e-8 : 1e-6
    @test !check_at(method, T, [0.75, 0.75 * (1 - δ)], 2)[1]
    # S = 0 (y = 0, λ = 0), τ S below floatmin(T) (a stationary point at a tiny scale), S not finite: not kept
    @test !check_at(method, T, [0.75, 0.75], 2; λ = 0, y = T[0])[1]
    tiny = T === Float64 ? 1e-310 : T(1e-40)
    @test !check_at(method, T, [tiny, tiny], 2; λ = 0, y = T[2tiny])[1]
    fm = floatmax(T)
    @test !check_at(method, T, [0.4 * fm, 0.4 * fm], 2; y = T[0.8 * fm])[1]    # ‖∇f(0)‖₁ = 1.6 floatmax overflows
    # the check adds one gradient for APG (formed from the cached image) and nothing for PGD, no proximal evaluation,
    # no function value; it caches λcrit and does not write delta_x
    ok, state = check_at(method, T, [0.75, 0.75], 2)
    ref = PS.initial_state(method, ProximalOptions(), lossof(one(T), T[2], T[1 1]), NormLinf(T(1)), T[0.75, 0.75])
    @test state.prox_calls == ref.prox_calls
    @test state.grad_calls == ref.grad_calls + (method isa AccProxGradDescent ? 1 : 0)
    @test state.f_calls == ref.f_calls
    @test state.λmax == 4
    before = copy(state.delta_x)
    PS._stationary!(state, lossof(one(T), T[2], T[1 1]), NormLinf(T(1)), ProximalOptions())
    @test state.delta_x == before && state.delta_x == state.x .- state.x_previous
  end
end

@testset "(f, λ) → (c f, c λ) for a power of two c leaves the decision unchanged (exact scaling)" begin
  for T in (Float64, Float32), method in METHODS
    ks = T === Float64 ? (-20:5:20) : (-8:4:8)
    for x in ([0.75, 0.75], [0.5, 0.5], [0, 0], [0.75, 0.75 * (1 - 1e-6)])
      base = check_at(method, T, x, 2)[1]
      for k in ks
        c = T(2)^k
        @test check_at(method, T, x, 2; λ = c, α = c)[1] == base
      end
    end
  end
end

# ---- the known false certifications of the mapping check -------------------------------------------------

# A nonstationary iterate, a step that is lost to rounding or underflow, is not certified: the KKT residual reads the gradient,
# not the step. The residual ratio r/(τ S) at the returned x is from the BigFloat reference.
@testset "round 1: a subnormal curvature (raw and scaled loss): no false convergence through solve!" begin
  cases = ((Float32, 1e-22, 1e8, 1.001e30, 4e-39), (Float64, 1e-160, 1e10, 1.00003e170, 1e-308))
  for (T, xv, yv, x0, a) in cases, scale in (1, 2)
    X, y = fill(T(xv), 1, 1), T[yv]
    for method in (ProximalGradientDescent(ls = PS.LineSearches.BackTracking(α = T(a))), AccProxGradDescent(α = T(a)))
      f = scale == 1 ? LeastSquaresLoss(y, X) : T(scale) * LeastSquaresLoss(y, X)
      x = T[x0]
      # a callback ends the solve after iteration 1, where the proposed stop was declared converged by the mapping check
      r = solve!(x, f, NormLinf(zero(T)), method, ProximalOptions(callback = _ -> true))
      @test r.iterations == 1 && !r.converged && !r.x_converged
      @test kkt_ratio(X, y, T(scale), 0, x) > 1            # λ = 0: ‖∇f‖₁ is above τ S (3 for Float64, 100 for Float32)
    end
  end
end

@testset "round 2: the step underflows at x = 0 (Float32 diag(1e18, 1e-10); Float64 diag(2^500, 2^-300)): no false convergence" begin
  cases = ((Float32, Float32[1e18 0; 0 1e-10], Float32[0, 1e-20], Float32[1e-18, 0], (;), (1, 2)),
           (Float64, [2.0^500 0; 0 2.0^-300], [0.0, 2.0^-300], [2.0^-500, 0.0], (maxiter = 1500, allow_f_increases = true), (2,)))
  for (T, X, y, x0, opts, scales) in cases, scale in scales, frac in (0.0, 0.01), method in METHODS
    α = T(scale)
    λ = T(frac * lambdacrit(X, y, α))
    f = scale == 1 ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)
    x = copy(x0)
    r = solve!(x, f, NormLinf(λ), method, ProximalOptions(; opts...))
    @test !r.converged
    @test kkt_ratio(X, y, α, λ, x) > 1e3                  # about 1e5: the true residual is ∇f(0) = (0, -1e-30) (resp. 2^-600 scale)
  end
  # the Float64 case with the raw loss: APG (the PGD line search of this case throws, which is not the subject)
  T, X, y = Float64, [2.0^500 0; 0 2.0^-300], [0.0, 2.0^-300]
  x = [2.0^-500, 0.0]
  r = solve!(x, LeastSquaresLoss(y, X), NormLinf(0.0), AccProxGradDescent(), ProximalOptions(maxiter = 1500, allow_f_increases = true))
  @test !r.converged && kkt_ratio(X, y, 1.0, 0.0, x) > 1e3
end

@testset "the displacement case: Float32, λ = 0, X = diag(1, 0.01), y = (0, 0.01), x0 = (0, 1.0001): the unchanged iterate is not kept" begin
  # ∇f = (0, 1e-8) is above τ S = 1e-5 ‖Xᵀy‖₁ = 1e-9, while x - ∇f/L rounds to x for L of order 1
  X, y = Float32[1 0; 0 0.01], Float32[0, 0.01]
  for method in METHODS
    x, r = solve_case(method, X, y, 1f0, 0, Float32[0, 1.0001], ProximalOptions(maxiter = 3))
    @test !r.converged
    @test kkt_ratio(X, y, 1f0, 0, x) > 5
  end
end

# ---- stops proposed at nonstationary iterates ------------------------------------------------------------

# The analytic problem from a start far from β* = (0.75, 0.75): the first accepted iterates are not stationary. A stop that
# xtol or ftol proposes at them is refused, and a loose gradtol sets the bar of the check as well as of the test.
@testset "a stop proposed by xtol or ftol at a nonstationary iterate is not kept" begin
  for T in (Float64, Float32), method in METHODS
    X, y = T[1 1], T[2]
    far = T[50, -50]
    for options in (ProximalOptions(maxiter = 2, xtol = 1e10, ftol = 0, gradtol = 0),
                    ProximalOptions(maxiter = 2, xtol = 1e-300, ftol = 1e10, gradtol = 0),
                    ProximalOptions(maxiter = 2, xtol = 1e10, ftol = 1e10, gradtol = 0))
      x = copy(far)
      r = solve!(x, lossof(one(T), y, X), NormLinf(T(1)), method, options)
      @test !r.converged && !r.x_converged && !r.f_converged && !r.grad_converged && r.iterations == 2
      @test kkt_ratio(X, y, one(T), 1, x) > 1e3
    end
    # a loose gradtol: a kept stop satisfies the independent residual bound, here at most 1.1 τ S (rounding of the gradient)
    for gradtol in (1e-2, 1e-3, 1e-4)
      x = copy(far)
      r = solve!(x, lossof(one(T), y, X), NormLinf(T(1)), method, ProximalOptions(maxiter = 5_000, gradtol = gradtol, ftol = 0))
      @test r.converged
      @test kkt_ratio(X, y, one(T), 1, x; gradtol) <= 1.1
    end
  end
end

# ---- convergence that must be established -----------------------------------------------------------------

@testset "genuine convergence at x = 0, also with many nonzero gradient entries in Float32" begin
  for T in (Float32, Float64), method in METHODS
    p = 200
    X, y = Matrix{T}(I, p, p), ones(T, p)           # ‖∇f(0)‖₁ = 200
    for λ in (201, 20000)
      x, r = solve_case(method, X, y, one(T), λ, zeros(T, p), DEFAULT)
      @test all(iszero, x) && r.converged && r.iterations == 1
    end
    # just below λcrit the optimum is not 0 (the clip level is 1 - λ/p), and the solve converges there
    x, r = solve_case(method, X, y, one(T), 199, zeros(T, p), TIGHT)
    @test r.converged && maximum(abs, x .- T(1 - 199 / 200)) <= (T === Float64 ? 1e-6 : 1e-4)
  end
end

@testset "genuine convergence at a nonzero solution with 200 entries tied at the maximum (Float32 and Float64)" begin
  for T in (Float32, Float64), method in METHODS
    A = 200
    rng = Xoshiro(5)
    y = T.(vcat(2 .* sign.(randn(rng, A)), 0.1 .* randn(rng, 4)))
    p = A + 4
    X = Matrix{T}(I, p, p)
    λ = T(0.5 * sum(abs, y))
    τ = setprecision(BigFloat, 256) do
      a = sort(abs.(big.(y)); rev = true)
      best = zero(BigFloat)
      for k in 1:p
        c = (sum(a[1:k]) - big(λ)) / k
        (k == p || a[k + 1] <= c) && (best = c; break)
      end
      Float64(best)
    end
    x, r = solve_case(method, X, y, one(T), λ, zeros(T, p), TIGHT)
    @test r.converged
    @test maximum(abs, x - sign.(y) .* min.(abs.(y), T(τ))) <= (T === Float64 ? 1e-6 : 1e-4)
    @test count(c -> abs(c) == maximum(abs, x), x) >= A - 5          # the clipped entries are bitwise tied
    @test kkt_ratio(X, y, one(T), λ, x) <= 1.1
  end
end

# A design with condition number `cond`: X = U diag(σ) Vᵀ with σ geometric from 1 to 1/cond
function illcond(T, cond; n = 40, p = 8, seed = 1)
  rng = Xoshiro(seed)
  U = Matrix(qr(randn(rng, n, p)).Q)[:, 1:p]; V = Matrix(qr(randn(rng, p, p)).Q)
  X = U * Diagonal([cond^(-(i - 1) / (p - 1)) for i in 1:p]) * V'
  β = randn(rng, p)
  T.(X), T.(X * β .+ 0.1 .* randn(rng, n))
end

@testset "ill-conditioned designs: a converged run is below the bound, and the moderate ones converge" begin
  for (T, conds) in ((Float64, (1e3, 1e6, 1e12)), (Float32, (1e3, 1e6))), method in METHODS, cond in conds, α in (1.0, 1 / 40)
    X, y = illcond(T, cond; seed = round(Int, log10(cond)))
    α = T(α)
    for frac in (0.0, 0.3, 0.9, 1.001)
      λ = T(frac * lambdacrit(X, y, α))
      x, r = solve_case(method, X, y, α, λ, zeros(T, 8), LONG)
      # converged is not accuracy, but it must not be false: the true residual is within rounding of the bound
      r.converged && @test kkt_ratio(X, y, α, λ, x) <= 1.1
      # above λcrit the zero is found at once; with cond = 1e3 the solves converge
      frac > 1 && @test r.converged && all(iszero, x)
      cond == 1e3 && frac > 0 && @test r.converged        # λ = 0: PGD does not reach the bound in 20000 iterations on these designs (measured), and does not claim to
    end
  end
end

@testset "scaled losses: (α, λ) → (c α, c λ) converges to a point with the same small residual" begin
  for T in (Float64, Float32), method in METHODS, c in (T(1), T(4), T(1) / 8)
    X, y = problem(T, 30, 5; ρ = 0.5, seed = 9)
    α = T(1) / 30
    λ = T(0.3 * lambdacrit(X, y, α))
    x, r = solve_case(method, X, y, c * α, c * λ, zeros(T, 5), LONG)
    @test r.converged
    @test kkt_ratio(X, y, c * α, c * λ, x) <= 1.1
    @test relgap(X, y, c * α, c * λ, x) <= gaptol(T)
  end
end

@testset "when the test cannot establish convergence: converged = false with the residual at or above the bound, or τ S below floatmin" begin
  # a stationary point at a scale where τ S = 1e-5 · 1e-36 is below floatmin(Float32): the guard refuses (r = 0 < τ S would pass otherwise)
  X, y = fill(1f0, 1, 1), Float32[1e-36]
  for method in METHODS
    x = Float32[1e-36]
    r = solve!(x, LeastSquaresLoss(y, X), NormLinf(0f0), method)
    @test !r.converged
    @test kkt_ratio(X, y, 1f0, 0, x) < 1          # the residual is 0: the refusal is the guard's, not a nonzero residual
  end
  # a nonzero residual that is above the bound: a solve cut short at a nonstationary point
  X, y = Float64[1 1], [2.0]
  for method in METHODS
    x = [50.0, -50.0]
    r = solve!(x, LeastSquaresLoss(y, X), NormLinf(1.0), method, ProximalOptions(maxiter = 3))
    @test !r.converged && kkt_ratio(X, y, 1.0, 1, x) > 1
  end
end

@testset "the stop that the check passes comes with the engine's counts: APG adds one gradient, PGD none, neither a proximal evaluation" begin
  # at x0 = 0 with λ above λcrit the first accepted iterate is 0 and the stop it proposes passes the check, so the solve ends
  # at iteration 1; its counts are compared with those of a run stopped there by a callback with no test proposing a stop
  nostop = (xtol = 1e-300, ftol = 0, gradtol = 0)
  for T in (Float64, Float32), method in METHODS
    X, y = T[1 1], T[2]
    f = lossof(one(T), y, X)
    g = NormLinf(T(5))
    a = solve!(zeros(T, 2), f, g, method, ProximalOptions())
    b = solve!(zeros(T, 2), f, g, method, ProximalOptions(; nostop..., callback = _ -> true))
    @test a.converged && a.iterations == 1 && b.iterations == 1 && !b.converged
    @test a.prox_calls == b.prox_calls
    @test a.grad_calls == b.grad_calls + (method isa AccProxGradDescent ? 1 : 0)
    @test a.f_calls == b.f_calls
  end
  # APG: a stop that the check refuses counts its gradient, so it can reach grad_calls_limit
  for T in (Float64, Float32)
    X, y = T[1 1], T[2]
    f, g = lossof(one(T), y, X), NormLinf(T(1))
    far = T[50, -50]
    e0 = solve!(copy(far), f, g, AccProxGradDescent(), ProximalOptions(; nostop..., callback = _ -> true))
    e = solve!(copy(far), f, g, AccProxGradDescent(), ProximalOptions(maxiter = 5, xtol = 1e10, ftol = 0, gradtol = 0, grad_calls_limit = e0.grad_calls + 1))
    @test e.iterations == 1 && e.call_limit_reached && !e.converged
  end
end

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

@testset "BigFloat and Rational{BigInt} levels: correct result and untouched scratch (their scalar arithmetic can allocate)" begin
  # PB forms the radius in a BigFloat product for these levels, which can allocate in the engines' proximal steps (as for
  # NormL1 and ElasticNet levels of these types), and the conversion of the level to T in the check can allocate; no
  # zero-allocation claim is made for them and none is tested
  for T in (Float64, Float32), method in METHODS, level in (big"1.0", big(1) // big(1))
    @test check_at(method, T, [0.75, 0.75], 2; level)[1]
    @test !check_at(method, T, [0.5, 0.5], 2; level)[1]
    g = NormLinf(level)
    @test check_at(method, T, [0.75, 0.75], 2; level)[2].prox_calls == 0
    x = zeros(T, 2)
    r = solve!(x, LeastSquaresLoss(T[2], T[1 1]), g, method, TIGHT)
    @test r.converged && maximum(abs, x - T[0.75, 0.75]) <= (T === Float64 ? 1e-6 : 1e-4)
    @test abs(r.minimum - 0.875) <= (T === Float64 ? 1e-9 : 1e-6)
    @test g.scratch.buf === nothing
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
