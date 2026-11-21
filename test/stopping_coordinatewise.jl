module StoppingCoordinatewiseTests
# The coordinatewise stationarity check of ProximalGradientDescent and AccProxGradDescent for dense vector least
# squares with NormL1 or ElasticNet, with or without weights (STOP-21, #487). Coordinate i passes when its signed
# score Gᵢ = kkt_violation(gT, ∇f(x), x, i) is finite and below tᵢ = T(τ √(a nᵢ² + λ2) √(2Φ)), a threshold that is
# finite and at least floatmin(T), with τ = T(max(gradtol, 64 eps(T))), a = Float64(α), nᵢ = ‖Xᵢ‖ and
# Φ = f(x) + (λ2/2)‖x‖² from the stored loss value. Two exact zero scales pass when the score is finite and at most 0:
# (A) a column of stored ±0 entries when λ2 is a stored ±0, (B) x and y with stored ±0 entries. Every other zero or
# nonfinite threshold refuses. The tests below check the zero-scale policy (signed zeros and subnormals under gradual
# underflow; with subnormals flushed, where the decisions are unspecified, only that the setting is restored), the
# range of the threshold arithmetic against a BigFloat recomputation, the decisions of the rule on
# fixtures where the λmax-based rule stopped with a large objective excess, the work of a check, and that the other
# problems keep the λmax-based check. Accuracy is measured from the raw data in 256-bit BigFloat; the active-set
# reference below takes its starting support from a CD solve and is accepted only after its BigFloat checks.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

const METHODS = (ProximalGradientDescent(), AccProxGradDescent())
const DEFAULT = ProximalOptions()

lossof(α, y, X) = isone(α) ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)

# The state of `method` at the point x: initial_state forms the image, the loss value and, for PGD, the gradient at x.
state_at(method, f, g, x, options = DEFAULT) =
  PS.initial_state(method, options, f, PS._working_gradient_penalty(g, eltype(x)), copy(x))

# The decision of the check at x, and the state after it
function check_at(method, f, g, x, options = DEFAULT)
  state = state_at(method, f, g, x, options)
  PS._stationary!(state, f, g, options), state
end

# Each method, T and the decision at x
decisions(f, g, x, options = DEFAULT) = [check_at(m, f, g, x, options)[1] for m in METHODS]

# The value of an _SE (significand × 2^exponent) as a BigFloat
seval(v) = ldexp(BigFloat(v.s), v.e)

stored_zero(v) = (reinterpret(Unsigned, v) << 1) == 0

# The decision of the rule at the state's point, formed here: ProximalBase's scores at the state's gradient, and the
# threshold T(τ sᵢ) with sᵢ = √(α‖Xᵢ‖² + λ2) √(2 f_x + λ2‖x‖²) from the stored loss value f_x, evaluated in 256-bit
# BigFloat from the stored data and rounded once to T; cases A and B by stored ±0 entries. The state is not checked.
function reference_decision(method, f, g, x, options = DEFAULT)
  T = eltype(x)
  state = state_at(method, f, g, x, options)
  grad = copy(PS._gradient_at_x!(state, f))
  gT = PS._converted_penalty(g, T)
  λ2 = gT isa ElasticNet ? gT.λ2 : zero(T)
  model = state.model
  X, y, α = model.X, model.Y, Float64(model.α)
  τ = T(max(options.gradtol, 64 * Float64(eps(T))))
  trivial = all(stored_zero, y) && all(stored_zero, x)
  all(eachindex(x)) do i
    G = kkt_violation(gT, grad, x, i)
    if trivial || (stored_zero(λ2) && all(stored_zero, X[:, i]))
      return isfinite(G) && G <= 0
    end
    t = setprecision(BigFloat, 256) do
      xb, l2 = big.(x), big(λ2)
      T(big(τ) * sqrt(big(α) * sum(abs2, big.(X[:, i])) + l2) * sqrt(2 * big(state.f_x) + l2 * sum(abs2, xb)))
    end
    isfinite(t) && t >= floatmin(T) && isfinite(G) && G < t
  end
end

# f() on a thread that flushes subnormals to zero, restoring the previous setting; nothing where that setting is not
# supported
function flushing(f)
  previous = get_zero_subnormals()
  set_zero_subnormals(true) || return nothing
  try
    f()
  finally
    set_zero_subnormals(previous)
  end
end

# F(x) = α/2 ‖Xx - y‖² + Σ cᵢ|xᵢ| + λ2/2 ‖x‖² in 256-bit BigFloat from the stored values
function objective(X, y, α, c, λ2, x)
  setprecision(BigFloat, 256) do
    Xb, yb, xb = big.(X), big.(y), big.(x)
    big(α) / 2 * sum(abs2, Xb * xb - yb) + sum(big.(c) .* abs.(xb)) + big(λ2) / 2 * sum(abs2, xb)
  end
end

# The minimizer of F in 256-bit BigFloat, from the support and signs of `start`: an active-set iteration that solves
# the stationarity equations on the active set in BigFloat and returns a point whose active penalized coordinates
# have the assumed signs and whose inactive coordinates have |gᵢ| ≤ cᵢ (the residual of the active equations is that of
# the BigFloat solve, not checked separately); an error when no such point is reached in 100 iterations.
function reference_minimizer(X, y, α, c, λ2, start)
  setprecision(BigFloat, 256) do
    Xb, yb, a, cb, l2 = big.(X), big.(y), big(α), big.(c), big(λ2)
    p = size(X, 2)
    H = a .* (Xb' * Xb) + l2 * I
    b = a .* (Xb' * yb)
    act = [iszero(c[i]) || !iszero(start[i]) for i in 1:p]
    sgn = [iszero(c[i]) ? 0 : Int(sign(start[i])) for i in 1:p]
    for _ in 1:100
      A = findall(act)
      x = zeros(BigFloat, p)
      isempty(A) || (x[A] = H[A, A] \ (b[A] .- cb[A] .* sgn[A]))
      g = H * x .- b
      ok = true
      for i in 1:p
        if act[i] && !iszero(c[i]) && sign(x[i]) != sgn[i]
          act[i], sgn[i], ok = false, 0, false
        elseif !act[i] && abs(g[i]) > cb[i]
          act[i], sgn[i], ok = true, -Int(sign(g[i])), false
        end
      end
      ok && return x
    end
    error("the active-set reference did not reach a KKT point")
  end
end

# (F(x) - F*)/|F*| in Float64, with F* from reference_minimizer started at a CD solve of the same problem
function relative_excess(X, y, α, c, λ2, x)
  T = eltype(X)
  start = zeros(T, size(X, 2))
  g = iszero(λ2) ? NormL1(one(T), T.(c)) : ElasticNet(one(T), T(λ2), T.(c))
  solve!(start, lossof(α, y, X), g, CDSolver(order = :cyclic, momentum = false, tol = T === Float64 ? 1e-13 : 1e-6))
  xstar = reference_minimizer(X, y, α, c, λ2, start)
  setprecision(BigFloat, 256) do
    Fstar = objective(X, y, α, c, λ2, xstar)
    Float64((objective(X, y, α, c, λ2, x) - Fstar) / abs(Fstar))
  end
end

# ---------------------------------------------------------------------------------------------------------------
# Zero scales that pass

@testset "y = 0 and x = 0: every penalty stops at the first proposal (case B)" begin
  for T in (Float64, Float32)
    X = T[1 1 0.2; 2 1 0.3; -1 0 0.5; 0.1 1 1; 0.4 0.3 -0.8]
    y = zeros(T, 5)
    w = T[0, 1, 2]
    for g in (NormL1(zero(T)), NormL1(T(0.1)), ElasticNet(zero(T), T(0.5)), ElasticNet(T(0.1), T(0.5)),
              NormL1(T(0.1), w), ElasticNet(T(0.1), T(0.5), w))
      f = LeastSquaresLoss(y, X)
      @test decisions(f, g, zeros(T, 3)) == [true, true]
      for method in METHODS
        x = zeros(T, 3)
        r = solve!(x, f, g, method)
        @test (T, typeof(g), typeof(method), r.converged, r.iterations) == (T, typeof(g), typeof(method), true, 1)
        @test all(iszero, x)
      end
    end
  end
end

@testset "a zero column with λ2 = 0 passes when its score is at most 0 (case A)" begin
  for T in (Float64, Float32)
    X = T[0 1 2; 0 -1 1; 0 2 0; 0 0 1]
    y = T[1, 2, -1, 0.5]
    f = LeastSquaresLoss(y, X)
    λ = T(0.3)
    # x₁ = 0 with c₁ = λ > 0: G₁ = |∇f₁| - λ = -λ, below 0; the other coordinates at the minimizer of the reduced problem
    xstar = T.(reference_minimizer(X, y, 1, fill(Float64(λ), 3), 0, [0, 1, 1]))
    @test xstar[1] == 0 && all(!iszero, xstar[2:3])
    @test decisions(f, NormL1(λ), xstar) == [true, true]
    for method in METHODS
      x = zeros(T, 3)
      r = solve!(x, f, NormL1(λ), method)
      @test r.converged && x[1] == 0
      @test relative_excess(X, y, 1, fill(Float64(λ), 3), 0, x) <= (T === Float64 ? 1e-10 : 1e-5)
    end
    # c₁ = 0 (a zero weight) and x₁ ≠ 0 at a point where the other coordinates are stationary: G₁ = |0 + 0| = 0.
    # The reference is the minimizer of the problem on the nonzero columns.
    w = T[0, 1, 1]
    xw = T.(vcat(3, reference_minimizer(X[:, 2:3], y, 1, fill(Float64(λ), 2), 0, [1, 1])))
    @test decisions(f, NormL1(λ, w), xw) == [true, true]
    for method in METHODS
      x = T[3, 0, 0]
      r = solve!(x, f, NormL1(λ, w), method)
      @test r.converged && x[1] == 3
    end
    # NormL1(0): least squares on the nonzero columns, x₁ = 3
    xl = T.(vcat(3, reference_minimizer(X[:, 2:3], y, 1, zeros(2), 0, [1, 1])))
    @test decisions(f, NormL1(zero(T)), xl) == [true, true]
    # ElasticNet(λ1, λ2 > 0): μ₁ = λ2 > 0, so the zero column is not case A; at x₁ = 0 its score -λ1 passes the
    # positive threshold of the ordinary case
    xe = T.(reference_minimizer(X, y, 1, fill(Float64(λ), 3), 0.5, [0, 1, 1]))
    ok, state = check_at(ProximalGradientDescent(), f, ElasticNet(λ, T(0.5)), xe)
    @test ok && Float64(seval(state.scales.h[1])) == sqrt(0.5)
    ok, state = check_at(ProximalGradientDescent(), f, NormL1(λ), xstar)
    @test state.scales.h[1] === PS._CASE_A
    # a column of -0.0 entries is a zero column too
    Xm = copy(X); Xm[:, 1] .= -zero(T)
    @test decisions(LeastSquaresLoss(y, Xm), NormL1(λ), xstar) == [true, true]
  end
end

@testset "X = 0 stops at x = 0" begin
  for T in (Float64, Float32), g in (NormL1(zero(T)), NormL1(T(0.2)), ElasticNet(T(0.2), T(0.5)))
    X = zeros(T, 5, 3)
    y = T[1, 2, 3, 4, 5]
    f = LeastSquaresLoss(y, X)
    @test decisions(f, g, zeros(T, 3)) == [true, true]
    for method in METHODS
      x = zeros(T, 3)
      r = solve!(x, f, g, method)
      @test r.converged && r.iterations == 1 && all(iszero, x)
    end
  end
end

@testset "a large range: R5 with λ = 0.1 λmax, residual 1e159 (Φ from the stored loss value)" begin
  # X = ones(5, 1), y = fill(1e160, 5), α = 1e-100: λmax = α 5e160 = 5e60, λ = 5e59, minimizer 1e160 - λ/(5α) = 9e159,
  # residual entries -1e159, so a plain Float64 sum of the squared residuals overflows, while f = α/2 ‖r‖² = 2.5e218
  X, y, α = ones(5, 1), fill(1e160, 5), 1e-100
  λ = 0.1 * α * 5e160
  f = lossof(α, y, X)
  for method in METHODS
    ok, state = check_at(method, f, NormL1(λ), [9e159])
    @test ok
    @test isfinite(state.f_x) && 1e218 < state.f_x < 1e219
    # a kept stop has G = 5α |x - 9e159| below τ 5α |x - 1e160|, so |x - 9e159| is below about τ 1e159 = 1e154
    x = zeros(1)
    r = solve!(x, f, NormL1(λ), method)
    @test r.converged && abs(x[1] - 9e159) <= 2e154
  end
end

@testset "a column with entries 1e160: its scaled norm" begin
  # X = [1e160 0; 0 1; 0 1], y = [1e160, 1, -1]: at x = [1, 0] the residual is [0, -1, 1], ∇f = 0 and ‖X₁‖ = 1e160,
  # whose plain Float64 square overflows. One unit in the last place of x₁ gives a residual whose first entry, about
  # 2e144, dominates its norm, so the score of x₁ is close to ‖X₁‖ ‖r‖, far above τ ‖X₁‖ ‖r‖.
  X, y = [1e160 0; 0 1; 0 1], [1e160, 1, -1]
  f = LeastSquaresLoss(y, X)
  for method in METHODS
    ok, state = check_at(method, f, NormL1(0.0), [1.0, 0.0])
    @test ok
    @test seval(state.scales.h[1]) ≈ 1e160 rtol = 4eps()
    @test !check_at(method, f, NormL1(0.0), [nextfloat(1.0), 0.0])[1]
  end
end

# ---------------------------------------------------------------------------------------------------------------
# Zero, underflowed and nonfinite scales that refuse

@testset "an exact fit X x = y ≠ 0: computed Φ = 0 at x ≠ 0 refuses (case C)" begin
  for T in (Float64, Float32), g in (NormL1(zero(T)), NormL1(T(0.5), zeros(T, 2)))
    X, x = T[1 0; 0 1; 1 1], T[1, 2]
    y = X * x
    f = LeastSquaresLoss(y, X)
    for method in METHODS
      ok, state = check_at(method, f, g, x)
      @test !ok && iszero(state.f_x)
      # from the fit itself and from 0: the stop is refused at every proposal; a normal exit, and the point is accurate
      for x0 in (copy(x), zeros(T, 2))
        z = copy(x0)
        r = solve!(z, f, g, method, ProximalOptions(maxiter = 500))
        @test !r.converged && (r.iteration_converged || r.f_increased)
        @test norm(z - x) <= (T === Float64 ? 1e-8 : 1e-3) * norm(x)
      end
    end
  end
end

@testset "a near-exact consistent fit: a residual at the rounding level refuses" begin
  rng = Xoshiro(487)
  for T in (Float64, Float32)
    X = T.(randn(rng, 12, 3))
    β = T[1.5, -2, 0.5]
    y = X * β
    f = LeastSquaresLoss(y, X)
    for method in METHODS
      @test !check_at(method, f, NormL1(zero(T)), β)[1]
      @test !check_at(method, f, NormL1(zero(T)), nextfloat.(β))[1]
      x = zeros(T, 3)
      r = solve!(x, f, NormL1(zero(T)), method, ProximalOptions(maxiter = 2000))
      @test !r.converged
      @test norm(x - β) <= (T === Float64 ? 1e-6 : 1e-2) * norm(β)
    end
  end
end

@testset "a Float64 column of entries 1e-170 has a scaled norm" begin
  # the squares of the entries underflow, so the norm of column 1 comes from the scaled form: √3 · 1e-170. With
  # NormL1(0.1, [1, 0]) at x = [0, x₂*] (x₂* the least-squares coefficient of column 2) both scores are below their
  # normal thresholds; with NormL1(0) coordinate 1 is not stationary there. Each decision equals the BigFloat rule.
  X, y = [1e-170 1; 1e-170 -1; 1e-170 2], [1.0, 2.0, 3.0]
  f = LeastSquaresLoss(y, X)
  x2 = Float64(reference_minimizer(X[:, 2:2], y, 1, [0.0], 0, [1])[1])
  for method in METHODS
    ok, state = check_at(method, f, NormL1(0.1, [1.0, 0.0]), [0.0, x2])
    @test ok
    @test seval(state.scales.h[1]) ≈ sqrt(big(3)) * big(1e-170) rtol = 4eps()
    @test ok == reference_decision(method, f, NormL1(0.1, [1.0, 0.0]), [0.0, x2])
    @test check_at(method, f, ElasticNet(0.1, 1.0, [1.0, 0.0]), [0.0, x2])[1] ==
          reference_decision(method, f, ElasticNet(0.1, 1.0, [1.0, 0.0]), [0.0, x2])
    ok0 = check_at(method, f, NormL1(0.0), [0.0, x2])[1]
    @test !ok0 && ok0 == reference_decision(method, f, NormL1(0.0), [0.0, x2])
    r = solve!(zeros(2), f, NormL1(0.1, [1.0, 0.0]), method)
    @test r.converged
  end
end

@testset "a zero column with x₁ ≠ 0 and c₁ > 0 refuses" begin
  for T in (Float64, Float32)
    X, y = T[0 1; 0 2; 0 -1], T[1, 2, 3]
    f = LeastSquaresLoss(y, X)
    λ = T(0.2)
    x = T.(reference_minimizer(X, y, 1, fill(Float64(λ), 2), 0, [0, 1]))
    @test decisions(f, NormL1(λ), x) == [true, true]
    x[1] = 1
    @test decisions(f, NormL1(λ), x) == [false, false]
    # the solve from x₁ = 1 shrinks x₁ to 0 and then stops
    for method in METHODS
      z = T[1, 0]
      r = solve!(z, f, NormL1(λ), method)
      @test r.converged && z[1] == 0
    end
  end
end

@testset "a tiny loss scale: a threshold below floatmin(T) refuses" begin
  # X = [1; 1], y = [1, -1], x = 0: ∇f = α Xᵀ(-y) = 0 and G = 0; the threshold τ √(2α) √(2α) = 2ατ is a normal
  # number for α = 1 and below floatmin(T) for α = 1e-38 (Float32) or 1e-305 (Float64)
  for (T, tiny) in ((Float32, 1e-38), (Float64, 1e-305))
    X, y = reshape(T[1, 1], 2, 1), T[1, -1]
    for method in METHODS
      @test check_at(method, lossof(1, y, X), NormL1(zero(T)), zeros(T, 1))[1]
      ok, state = check_at(method, lossof(tiny, y, X), NormL1(zero(T)), zeros(T, 1))
      @test !ok && state.f_x > 0
    end
  end
end

@testset "an infinite τ, or a threshold product that overflows, refuses" begin
  # Float32: gradtol = 1e39 converts to τ = Inf32. Float64: X = [1e5; 1e5], y = [1e5, -1e5], x = 0: ∇f = 0,
  # h ρ = √2e10 √2e10 = 2e10, and τ = 1e300 gives a product above floatmax(Float64).
  for (T, s, huge) in ((Float32, 1, 1e39), (Float64, 1e5, 1e300))
    X, y = reshape(T[s, s], 2, 1), T[s, -s]
    f = LeastSquaresLoss(y, X)
    for method in METHODS
      @test check_at(method, f, NormL1(zero(T)), zeros(T, 1))[1]
      @test !check_at(method, f, NormL1(zero(T)), zeros(T, 1), ProximalOptions(gradtol = huge))[1]
    end
  end
end

@testset "a NaN or infinite gradient entry refuses" begin
  for T in (Float64, Float32)
    X, y = T[1 0; 0 1; 1 1], T[1, 2, 2]
    f = LeastSquaresLoss(y, X)
    x = T.(reference_minimizer(X, y, 1, zeros(2), 0, [1, 1]))
    @test decisions(f, NormL1(zero(T)), x) == [true, true]
    for bad in (T(NaN), T(Inf))
      state = state_at(ProximalGradientDescent(), f, NormL1(zero(T)), x)
      state.grad_f_x[1] = bad
      @test !PS._stationary!(state, f, NormL1(zero(T)), DEFAULT)
      # APG forms ∇f(x) from the cached image: an entry of the image that is not finite gives such gradient entries
      state = state_at(AccProxGradDescent(), f, NormL1(zero(T)), x)
      state.z_x[1] = bad
      @test !PS._stationary!(state, f, NormL1(zero(T)), DEFAULT)
    end
  end
end

# ---------------------------------------------------------------------------------------------------------------
# The rule on fixtures where the λmax-based rule stopped early

# The #400/#487 fixture O1: an intercept column and 9 Gaussian columns, n = 50, y = offset + signal + noise, the
# intercept unpenalized; λ0 = ½ λ̂ with λ̂ = maxⱼ |Xⱼᵀ(y - ȳ)| the zero level of the penalized columns with the
# intercept free
function offset_fixture(offset)
  rng = Xoshiro(400)
  X = hcat(ones(50), randn(rng, 50, 9))
  y = offset .+ X[:, 2:5] * [2.0, -1.5, 1.0, 0.5] .+ 0.5 .* randn(rng, 50)
  λhat = maximum(abs, X[:, 2:end]' * (y .- sum(y) / 50))
  X, y, 0.5 * λhat
end

@testset "a free intercept with offset 1e6: converged implies a relative objective excess ≤ 1e-6 (Float64)" begin
  X, y, λ0 = offset_fixture(1e6)
  w = vcat(0.0, ones(9))
  for method in METHODS
    x = zeros(10)
    r = solve!(x, LeastSquaresLoss(y, X), NormL1(λ0, w), method)
    excess = relative_excess(X, y, 1, λ0 .* w, 0, x)
    @test (typeof(method), !r.converged || excess <= 1e-6) == (typeof(method), true)
  end
end

@testset "the centered response with a free intercept converges accurately (Float64)" begin
  X, y, λ0 = offset_fixture(1e6)
  y = y .- sum(y) / 50
  w = vcat(0.0, ones(9))
  for method in METHODS
    x = zeros(10)
    r = solve!(x, LeastSquaresLoss(y, X), NormL1(λ0, w), method)
    @test r.converged
    @test relative_excess(X, y, 1, λ0 .* w, 0, x) <= 1e-6
  end
end

@testset "an intercept weight 1e-8 and one column rescaled with its weight: converged implies accuracy (Float64)" begin
  X, y, λ0 = offset_fixture(1e6)
  Xs = copy(X); Xs[:, 2] .*= 1e4
  # the second fixture is an equivalent reparametrization of the centered problem: column 2 and its weight times 1e4
  yc = y .- sum(y) / 50
  for (Xf, yf, w) in ((X, y, vcat(1e-8, ones(9))), (Xs, yc, vcat(0.0, 1e4, ones(8))))
    for method in METHODS
      x = zeros(10)
      r = solve!(x, LeastSquaresLoss(yf, Xf), NormL1(λ0, w), method)
      excess = relative_excess(Xf, yf, 1, λ0 .* w, 0, x)
      @test (typeof(method), w[1], !r.converged || excess <= 1e-6) == (typeof(method), w[1], true)
    end
  end
end

@testset "ElasticNet with a zero weight: the score includes the ridge derivative" begin
  # X = [1], ElasticNet(1, 1, [0]), x = 1: y = 2 gives ∇f = -1 and G = |-1 + 1| = 0; y = 1 gives ∇f = 0 and
  # G = |0 + 1| = 1, above τ √2 √(2Φ) = τ √2 with Φ = ½
  for T in (Float64, Float32)
    g = ElasticNet(one(T), one(T), T[0])
    @test decisions(LeastSquaresLoss(T[2], T[1;;]), g, T[1]) == [true, true]
    @test decisions(LeastSquaresLoss(T[1], T[1;;]), g, T[1]) == [false, false]
    for method in METHODS
      x = zeros(T, 1)
      r = solve!(x, LeastSquaresLoss(T[3], T[1;;]), g, method)
      # the minimizer of ½(x - 3)² + ½x² is 1.5; a kept stop has |2x - 3| below about τ √2 √((x - 3)² + x²) ≈ 3e-5
      @test r.converged && abs(x[1] - T(1.5)) <= 2e-5
    end
  end
end

# ---------------------------------------------------------------------------------------------------------------
# The work of a check

counters(s::PS.ProximalGradientDescentState) = (s.f_calls, s.grad_calls, s.prox_calls, s.verifications, s.backtrack_steps)
counters(s::PS.AccProxGradDescentState) = (s.f_calls, s.grad_calls, s.prox_calls, s.fallbacks, s.backtrack_steps)
alloc_check(state, f, g, options) = @allocated PS._stationary!(state, f, g, options)

function problem(T, rng = Xoshiro(21))
  X = T.(randn(rng, 20, 5))
  y = T.(randn(rng, 20))
  x = T.(randn(rng, 5))
  X, y, x
end

@testset "counters: PGD adds none, APG adds its gradient at x; no λmax; no allocation after the first check" begin
  for T in (Float64, Float32)
    X, y, x = problem(T)
    raw = LeastSquaresLoss(y, X)
    w = T[0, 1, 2, 0.5, 1]
    for f in (raw, T(0.25) * raw, (T === Float32 ? 0.25 : 0.25f0) * raw, 3 * raw),
        g in (NormL1(T(0.1)), NormL1(T(0.1), w), ElasticNet(T(0.1), T(0.3)), ElasticNet(T(0.1), T(0.3), w),
              NormL1(big"0.1"), ElasticNet(1 // 10, 3 // 10))
      for method in METHODS
        state = state_at(method, f, g, x)
        before = counters(state)
        PS._stationary!(state, f, g, DEFAULT)
        after = counters(state)
        expected = method isa AccProxGradDescent ? before .+ (0, 1, 0, 0, 0) : before
        @test after == expected
        @test state.λmax == -1
        @test alloc_check(state, f, g, DEFAULT) == 0
      end
    end
    # the zero exits: y = 0, x = 0 and a zero column
    for (Xz, yz, xz) in ((X, zeros(T, 20), zeros(T, 5)), (hcat(zeros(T, 20), X[:, 2:end]), y, x))
      f = LeastSquaresLoss(yz, Xz)
      for method in METHODS, g in (NormL1(T(0.1)), ElasticNet(T(0.1), T(0.3)))
        state = state_at(method, f, g, xz)
        PS._stationary!(state, f, g, DEFAULT)
        @test alloc_check(state, f, g, DEFAULT) == 0
      end
    end
  end
end

@testset "the threshold equals a BigFloat recomputation from X, y and x, up to rounding" begin
  for T in (Float64, Float32), α in (1, 0.3), (g, λ2) in ((NormL1(T(0.1), T[0, 1, 2, 0.5, 1]), 0.0),
                                                          (ElasticNet(T(0.1), T(0.7), T[0, 1, 2, 0.5, 1]), 0.7))
    X, y, x = problem(T)
    f = lossof(α, y, X)
    o = ProximalOptions(gradtol = 1e-4)
    for method in METHODS
      state = state_at(method, f, g, x, o)
      PS._stationary!(state, f, g, o)
      τ = T(1e-4)
      c = PS._threshold_factor(τ, state.f_x, PS._ridge_level(PS._converted_penalty(g, T)), state.x)
      t = [PS._coordinate_threshold(T, c, state.scales.h[i]) for i in 1:5]
      reference = setprecision(BigFloat, 256) do
        Xb, yb, xb, a, l2 = big.(X), big.(y), big.(x), big(α), big(T(λ2))
        Φ = a / 2 * sum(abs2, Xb * xb - yb) + l2 / 2 * sum(abs2, xb)
        [big(τ) * sqrt(a * sum(abs2, Xb[:, i]) + l2) * sqrt(2Φ) for i in 1:5]
      end
      @test all(i -> abs(big(t[i]) - reference[i]) <= 30 * eps(T) * reference[i], 1:5)
      # the comparison is strict. PGD at x = 0, with the gradient set to 0 except entry 1, whose weight is 0: the
      # score of entry 1 is |∇f₁| - 0, and the other scores are -cᵢ ≤ 0. A score one unit in the last place below the
      # threshold passes, and a score equal to it does not.
      if method isa ProximalGradientDescent
        gT = PS._converted_penalty(g, T)
        st = state_at(method, f, g, zeros(T, 5), o)
        PS._stationary!(st, f, g, o)
        c1 = PS._threshold_factor(τ, st.f_x, PS._ridge_level(gT), st.x)
        t1 = PS._coordinate_threshold(T, c1, st.scales.h[1])
        for (score, expected) in ((prevfloat(t1), true), (t1, false))
          st.grad_f_x .= 0
          st.grad_f_x[1] = score
          @test kkt_violation(gT, st.grad_f_x, st.x, 1) == score
          @test PS._stationary!(st, f, g, o) == expected
        end
      end
    end
  end
end

# After an iteration, the image, the loss value and the gradient that the check reads are those of the accepted
# iterate: they equal those of a fresh state at the same point (formed by initial_state from X x), and the decision is
# the fresh state's
function same_as_fresh(method, f, g, state, X)
  T = eltype(state.x)
  fresh = state_at(method, f, g, state.x)
  @test state.z_x == X * state.x
  @test state.f_x == PS._value!(copy(state.x), f, state.model, similar(state.z_x))
  held = copy(PS._gradient_at_x!(state, f))
  @test held == PS._gradient_at_x!(fresh, f)
  @test PS._stationary!(state, f, g, DEFAULT) == PS._stationary!(fresh, f, g, DEFAULT)
end

@testset "after a rejected trial, a zero step and an APG restart the check reads the accepted iterate" begin
  for T in (Float64, Float32), g in (NormL1(T(0.05)), ElasticNet(T(0.05), T(0.2)))
    X, y, _ = problem(T)
    f = LeastSquaresLoss(y, X)
    gw = PS._working_gradient_penalty(g, T)
    for method in METHODS
      # a rejected trial: L far below the curvature, so the first trial is rejected and retried (one prox per trial)
      state = state_at(method, f, g, zeros(T, 5))
      state.L = T(1e-3)
      prox = state.prox_calls
      PS.update_state!(f, gw, state, method)
      @test state.prox_calls - prox >= 2
      same_as_fresh(method, f, g, state, X)
      # a zero step: x = 0 with every coefficient above |∇f(0)|, so the proximal step returns 0
      big_g = g isa NormL1 ? NormL1(T(2) * maximum(abs, X' * y)) : ElasticNet(T(2) * maximum(abs, X' * y), T(0.2))
      state = state_at(method, f, big_g, zeros(T, 5))
      PS.update_state!(f, PS._working_gradient_penalty(big_g, T), state, method)
      @test all(iszero, state.x)
      same_as_fresh(method, f, big_g, state, X)
    end
    # an APG restart: X = I, y = 0, from x = [1, 0] with x_previous = [-1, 0] and k = 1000, the extrapolated point is
    # near [3, 0], and with L = 100 the step from it raises the objective, so the step is repeated without momentum
    # from the accepted point [1, 0], which the update copied to x_previous (the initial [-1, 0] entered only the
    # extrapolation)
    Xi, z = Matrix{T}(I, 2, 2), zeros(T, 2)
    fi = LeastSquaresLoss(z, Xi)
    m = AccProxGradDescent()
    st = state_at(m, fi, NormL1(zero(T)), T[1, 0])
    st.x_previous .= T[-1, 0]
    st.z_previous .= Xi * st.x_previous
    st.normx_previous = PS._se_norm(T, st.x_previous)
    st.k = 1000
    st.L = T(100)
    PS.update_state!(fi, NormL1(zero(T)), st, m)
    @test st.restarts == 1
    same_as_fresh(m, fi, NormL1(zero(T)), st, Xi)
  end
end

# ---------------------------------------------------------------------------------------------------------------
# Stored zeros, subnormals and flushing

@testset "exact zero scales read stored bits: signed zeros and subnormals under gradual underflow" begin
  for T in (Float64, Float32)
    d = nextfloat(zero(T))
    # case B with signed zeros
    for (xv, yv) in ((zero(T), zero(T)), (-zero(T), -zero(T)), (-zero(T), zero(T)))
      @test decisions(LeastSquaresLoss(T[yv], T[1;;]), NormL1(zero(T)), T[xv]) == [true, true]
    end
    # subnormal response, iterate or column without flushing: not cases A or B, and the decision is the BigFloat rule's
    for (X, y, x) in ((T[1;;], T[d], T[-0.0]), (T[-d;;], T[1], T[-0.0]), (T[1;;], T[0], T[d]))
      f = LeastSquaresLoss(y, X)
      for method in METHODS
        @test check_at(method, f, NormL1(zero(T)), x)[1] == reference_decision(method, f, NormL1(zero(T)), x)
      end
    end
    # on a thread that flushes subnormals to zero the decisions are unspecified (STOP-21); the run below only checks that
    # the checks return without an error and that the previous setting is restored
    previous = get_zero_subnormals()
    flushing() do
      for (X, y, x) in ((T[1;;], T[d], T[-0.0]), (T[-d;;], T[1], T[-0.0]), (T[1;;], T[0], T[d]))
        f = LeastSquaresLoss(y, X)
        for method in METHODS
          check_at(method, f, NormL1(zero(T)), x)
        end
      end
    end
    @test get_zero_subnormals() == previous
  end
end

@testset "the exact zero scales are not offset invariant, and case A needs a score at most 0" begin
  for T in (Float64, Float32), method in METHODS
    # X = [1] with NormL1(0): x = y = 0 is case B and passes; x = y = 1 has the same zero residual and gradient, and
    # refuses (a computed ρ = 0 outside case B)
    @test check_at(method, LeastSquaresLoss(T[0], T[1;;]), NormL1(zero(T)), T[0])[1]
    @test !check_at(method, LeastSquaresLoss(T[1], T[1;;]), NormL1(zero(T)), T[1])[1]
    # X = [0], y = 0, x = 1 with NormL1(1): a zero residual and a case-A column, whose score |0 + 1| = 1 is positive
    @test !check_at(method, LeastSquaresLoss(T[0], T[0;;]), NormL1(one(T)), T[1])[1]
  end
end

# ---------------------------------------------------------------------------------------------------------------
# The range of the threshold arithmetic

@testset "the range of the threshold: decisions equal the BigFloat rule" begin
  # a threshold product whose first factor would round to a subnormal: score 3.5e-172 above τ sᵢ = 2.84e-172 (refused)
  f = 1e-312 * LeastSquaresLoss([1e308], [2e-154;;])
  g = NormL1(1.9999999999968958e-158)
  o = ProximalOptions(gradtol = 64eps())
  for method in METHODS
    @test !check_at(method, f, g, [0.0], o)[1]
    @test reference_decision(method, f, g, [0.0], o) == false
  end
  # a huge gradtol with a finite threshold: τ sᵢ = 1e308 · 4 · 1e-150 = 4e158, and the score is negative (kept)
  f = LeastSquaresLoss([1e-150], [4.0;;])
  o = ProximalOptions(gradtol = 1e308)
  for method in METHODS
    @test check_at(method, f, NormL1(1e-140), [0.0], o)[1]
    @test reference_decision(method, f, NormL1(1e-140), [0.0], o)
    r = solve!([0.0], f, NormL1(1e-140), method, o)
    @test r.converged && r.iterations == 1
  end
  # ridge energy with a zero loss: X = 0, y = 0, x = 1e-170, ElasticNet(0, 1e300): λ2‖x‖² = 1e-40, threshold
  # τ √λ2 √(λ2‖x‖²) = 2 · 1e150 · 1e-20 = 2e130 against the score 1e130 (kept)
  f = LeastSquaresLoss([0.0], [0.0;;])
  o = ProximalOptions(gradtol = 2.0)
  for method in METHODS
    @test check_at(method, f, ElasticNet(0.0, 1e300), [1e-170], o)[1]
    @test reference_decision(method, f, ElasticNet(0.0, 1e300), [1e-170], o)
  end
  # an iterate whose squared norm overflows with a small ridge level: decisions equal the BigFloat rule
  f = LeastSquaresLoss([0.0], zeros(1, 2))
  for gradtol in (1e-5, 1.0, 2.0), method in METHODS
    o = ProximalOptions(; gradtol)
    @test check_at(method, f, ElasticNet(0.0, 1e-307), [1.3e308, 1.3e308], o)[1] ==
          reference_decision(method, f, ElasticNet(0.0, 1e-307), [1.3e308, 1.3e308], o)
  end
  # a column whose norm exceeds floatmax(Float64) with α = 1e-308: √a ‖X₁‖ and the threshold are finite (kept, ∇f = 0)
  f = 1e-308 * LeastSquaresLoss([0.25, -0.25], fill(1.3e308, 2, 1))
  for method in METHODS
    ok, state = check_at(method, f, NormL1(0.0), [0.0])
    @test ok && ok == reference_decision(method, f, NormL1(0.0), [0.0])
    @test seval(state.scales.h[1]) ≈ big(1e-154) * big(1.3e308) * sqrt(big(2)) rtol = 1e-14
  end
end

# ---------------------------------------------------------------------------------------------------------------
# The other problems keep the λmax-based check

@testset "logistic, group, Euclidean, nonnegative and matrix-response problems compute λmax" begin
  rng = Xoshiro(5)
  # logistic NormL1 (Float64): λmax = ‖Xᵀ(½ - y)‖∞; at x = 0 the score is λmax - λ
  X = randn(rng, 30, 4)
  y = Float64.(rand(rng, 30) .< 0.5)
  f = LogisticLoss(y, X)
  lm = maximum(abs, X' * (0.5 .- y))
  for method in METHODS, (frac, expected) in ((1.01, true), (0.5, false))
    ok, state = check_at(method, f, NormL1(frac * lm), zeros(4))
    @test ok == expected && isapprox(state.λmax, lm, rtol = 1e-14) && state.scales === nothing
  end
  for T in (Float64, Float32)
    X = T.(randn(rng, 20, 4))
    y = T.(randn(rng, 20))
    f = LeastSquaresLoss(y, X)
    G = X' * y
    groups = [1:2, 3:4]
    Λ = maximum(norm(G[k]) for k in groups)
    for method in METHODS, (frac, expected) in ((T(1.01), true), (T(0.5), false))
      ok, state = check_at(method, f, GroupNormL2(frac * Λ, groups, ones(T, 2)), zeros(T, 4))
      @test ok == expected && state.λmax >= 0 && state.scales === nothing
      ok, state = check_at(method, f, NormL2(frac * norm(G)), zeros(T, 4))
      @test ok == expected && state.λmax >= 0 && state.scales === nothing
    end
    for (frac, expected) in ((T(1.01), true), (T(0.5), false))
      ok, state = check_at(ProximalGradientDescent(), f, NormL1Nonneg(frac * maximum(abs, G)), zeros(T, 4))
      expected_nn = expected || maximum(G) <= frac * maximum(abs, G)
      @test ok == expected_nn && state.λmax >= 0 && state.scales === nothing
    end
    Y = T.(randn(rng, 20, 2))
    fm = LeastSquaresLoss(Y, X)
    lmm = maximum(abs, X' * Y)
    for method in METHODS, (frac, expected) in ((T(1.01), true), (T(0.5), false))
      ok, state = check_at(method, fm, NormL1(frac * lmm), zeros(T, 4, 2))
      @test ok == expected && state.λmax >= 0 && state.scales === nothing
    end
  end
end

end
