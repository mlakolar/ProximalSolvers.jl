module ScaledLasso
# The scaled lasso of Sun and Zhang (2012) from the square-root lasso solver (#331): with r = y − Xβ,
# λ = √n λ₀, P(β) = ‖r‖₂ + λ‖β‖₁ (what `solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(...))`
# minimizes) and L(β, σ) = ‖r‖²/(2nσ) + σ/2 + λ₀‖β‖₁ for σ > 0, the file checks the mathematics that
# the tutorial examples/problems/scaled_lasso.jl relies on, not the square-root solver:
#   1. for r ≠ 0 and σ̂ = ‖r‖/√n: L(β, σ̂) = P(β)/√n, and L(β, σ) − L(β, σ̂) = (σ − σ̂)²/(2σ) ≥ 0 (T1, T2);
#   2. for y ≠ 0 (so P* > 0) and a certified run with gap ≤ 1e-4 whose point has r ≠ 0, the relative gap of
#      L(β̂, σ̂) is at most that of P(β̂), checked against the dual bound of an independent BigFloat
#      computation (T3); at y = 0, P* = 0 and the relative gap is undefined, and the minimizer β = 0 has
#      residual 0 and so no positive σ̂ (another β can have r ≠ 0 and its conditional σ̂). And σ̂ computed
#      in Float32 or Float64 is within a stated rounding bound of σ̂ in BigFloat (T4);
#   3. the tutorial's data have a residual clearly away from zero (T5);
#   4. at r = 0, L(β, ·) = σ/2 + λ₀‖β‖₁ has no minimizing σ > 0, and a small stored nonzero residual is
#      not an exact fit (T6);
#   5. runs without a certificate report `converged = false` and `gap = NaN`, and their σ̂, where r ≠ 0,
#      is the conditional minimizer at their point and nothing more (T7).
# Nothing here claims whether a joint minimum is attained. Following #305, the tests assert truthful flags
# and quality, with a justified tolerance each.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
using Logging: with_logger

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

const UNCERTIFIED = r"stopped without a duality certificate"
const NOTCONVERGED = r"did not converge in maxpasses"

# The result of f() and its log records.
function logged(f)
  logger = Test.TestLogger()
  r = with_logger(f, logger)
  r, logger.logs
end
messages(logs) = [string(l.message) for l in logs]

# Runs f() with BigFloat precision 256 bits, restoring the precision afterwards.
with_big(f) = setprecision(f, BigFloat, 256)

# Seeded data of the tutorial's kind (columns scaled to sum(abs2) ≈ n, five nonzero coefficients, noise 0.5),
# stored in T. λ₀ = 1.1 √(2 log(2p/0.05)/n) is evaluated in Float64 and then converted to T; λ = √T(n) λ₀ is
# formed in T.
function make_problem(T, seed, n, p)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  X ./= sqrt.(sum(abs2, X; dims = 1) ./ n)
  βtrue = [[2.0, -1.5, 1.0, -1.0, 0.75]; zeros(p - 5)]
  y = X * βtrue .+ 0.5 .* randn(rng, n)
  λ₀ = T(1.1 * sqrt(2 * log(2p / 0.05) / n))
  (X = T.(X), y = T.(y), n = n, p = p, λ₀ = λ₀, λ = sqrt(T(n)) * λ₀)
end

# The Float64 evaluation, from the stored values, of λmax = ‖Xᵀy‖∞/‖y‖. In exact arithmetic any level at or
# above λmax gives β = 0; the evaluation is rounded, so it is an approximation of that threshold, and the
# tests compare λ with it only far from the boundary.
lambda_max(X, y) = maximum(abs, Float64.(X)' * Float64.(y)) / norm(Float64.(y))

# One solve from x0 (copied), dense or on a SparseIterate; returns the dense point, the result and the logs.
function sqrt_solve(X, y, λ, x0; owner = false, kwargs...)
  x = owner ? SparseIterate(copy(x0)) : copy(x0)
  r, logs = logged(() -> solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(; kwargs...)))
  @test r.minimizer === x
  Vector(x), r, logs
end

# Quantities in T arithmetic from one computed s = ‖r‖: σ̂ = s/√n, λ₀ = λ/√n, and P = s + λ‖β‖₁.
function stats_T(X, y, λ, β)
  T = eltype(X)
  b = Vector(β)
  r = y - X * b
  s = norm(r)
  sn = sqrt(T(size(X, 1)))
  (r = r, s = s, n = size(X, 1), σ̂ = s / sn, sn = sn, λ₀ = λ / sn, l1 = norm(b, 1), P = s + λ * norm(b, 1))
end
joint_T(st, σ) = st.s^2 / (2 * st.n * σ) + σ / 2 + st.λ₀ * st.l1

# In BigFloat at 256 bits from the stored X, y, λ, β (λ₀ = λ/√n): the relative error of the identity
# L(β, σ̂) = P(β)/√n, the largest error of L(σ) − L(σ̂) = (σ − σ̂)²/(2σ) over σ = σ̂(1 + δ) relative to
# L(σ̂), and whether L(σ) > L(σ̂) for all those δ. Requires r ≠ 0.
function profile_big(X, y, λ, β, δs)
  with_big() do
    b = big.(Vector(β))
    r = big.(y) .- big.(X) * b
    n = size(X, 1)
    sn = sqrt(big(n))
    rsq = sum(abs2, r)
    l1 = sum(abs, b)
    λb = big(λ)
    λ₀ = λb / sn
    L(σ) = rsq / (2n * σ) + σ / 2 + λ₀ * l1
    σ̂ = sqrt(rsq) / sn
    Lh = L(σ̂)
    P = sqrt(rsq) + λb * l1
    errs = [abs((L(σ̂ * (1 + big(δ))) - Lh) - (σ̂ * big(δ))^2 / (2σ̂ * (1 + big(δ)))) / Lh for δ in δs]
    (identity = Float64(abs(Lh - P / sn) / (P / sn)), t2 = Float64(maximum(errs)),
     positive = all(L(σ̂ * (1 + big(δ))) > Lh for δ in δs), σ̂ = Float64(σ̂))
  end
end

# A dual lower bound D ≤ P* from β, computed with 256-bit BigFloat arithmetic: r = y − Xβ ≠ 0,
# g = ‖Xᵀr‖∞/‖r‖, t = min(1, λ/g)(1 − 2^-60), θ = t r/‖r‖ and D = θᵀy. When g = 0, take
# min(1, λ/g) = 1. The two dual feasibility inequalities are checked below. The computation uses X, y, λ
# and β only.
function dual_bound_big(X, y, λ, β)
  with_big() do
    Xb, yb, λb = big.(X), big.(y), big(λ)
    r = yb .- Xb * big.(Vector(β))
    nr = norm(r)
    @assert !iszero(nr)
    g = maximum(abs, Xb' * r) / nr
    t = min(one(BigFloat), λb / g) * (1 - big(2.0)^-60)
    θ = (t / nr) .* r
    @assert norm(θ) <= 1 && maximum(abs, Xb' * θ) <= λb
    dot(θ, yb)
  end
end

# For a dual bound D ≤ P* with D > 0 (so P* > 0) and a point β with r ≠ 0, in BigFloat: whether D/√n ≤ L(β, σ̂), the relative gap
# (L(β, σ̂) − D/√n)/(D/√n) as a Float64, the same for (P(β) − D)/D, and their absolute difference.
function certificate_big(X, y, λ, β, D)
  with_big() do
    b = big.(Vector(β))
    r = big.(y) .- big.(X) * b
    n = size(X, 1)
    sn = sqrt(big(n))
    rsq = sum(abs2, r)
    l1 = sum(abs, b)
    λb = big(λ)
    σ̂ = sqrt(rsq) / sn
    Lh = rsq / (2n * σ̂) + σ̂ / 2 + (λb / sn) * l1
    P = sqrt(rsq) + λb * l1
    relL = (Lh - D / sn) / (D / sn)
    relP = (P - D) / D
    (above = D / sn <= Lh, positive = D > 0, relL = Float64(relL), relP = Float64(relP),
     diff = Float64(abs(relL - relP)))
  end
end

# In the exact-fit cases below, r = 0 is checked in BigFloat. The decreasing field checks L(σ/2) < L(σ) for
# each σ in σs; above checks L(σ) > λ₀‖β‖₁ for each such σ. The limit field is the relative difference
# between λ₀‖β‖₁ and P(β)/√n.
function exact_fit_big(X, y, λ, β, σs)
  with_big() do
    b = big.(Vector(β))
    r = big.(y) .- big.(X) * b
    n = size(X, 1)
    sn = sqrt(big(n))
    l1 = sum(abs, b)
    λ₀ = big(λ) / sn
    L(σ) = sum(abs2, r) / (2n * σ) + σ / 2 + λ₀ * l1
    P = norm(r) + big(λ) * l1
    (zero = all(iszero, r), decreasing = all(L(big(σ) / 2) < L(big(σ)) for σ in σs),
     above = all(L(big(σ)) > λ₀ * l1 for σ in σs), exactform = all(L(big(σ)) == big(σ) / 2 + λ₀ * l1 for σ in σs),
     limit = Float64(abs(λ₀ * l1 - P / sn) / (P / sn)))
  end
end

# The checks of T1 and T2 at one point β with r ≠ 0, X, y, λ in T. `strict` asks for L(σ) > L(σ̂) in T
# arithmetic for |δ| ≥ 1e-1; it is false where σ̂ is so small against λ₀‖β‖₁ that the gain is below
# the rounding of L in T.
const DELTAS = [-0.5, -1e-1, -1e-3, -1e-6, 1e-6, 1e-3, 1e-1, 1.0, 9.0]
function check_profile(X, y, λ, β; strict = true)
  T = eltype(X)
  st = stats_T(X, y, λ, β)
  @test !iszero(st.r)
  # T1 (a): The identity is evaluated in BigFloat from the stored values. The bound 1e-70 is a deliberately
  # generous rounding allowance at 256-bit precision, whose unit roundoff is 2^-256 ≈ 8.6e-78. The check
  # compares the joint and profiled evaluation orders below.
  pb = profile_big(X, y, λ, β, DELTAS)
  @test pb.identity <= 1e-70
  # T2 (big): the identity of L(σ) − L(σ̂) with the same rounding bound relative to L(σ̂), and a strict increase.
  @test pb.t2 <= 1e-70
  @test pb.positive
  # T1 (b): Both sides use the same computed s and ‖β‖₁. Their products, divisions and additions are
  # evaluated in different orders. For the normal finite scalar values in these cases, 16 eps(T) relative is
  # a conservative allowance for the accumulated rounding of those elementary operations.
  @test isapprox(joint_T(st, st.σ̂), st.P / st.sn; rtol = 16 * eps(T))
  # T2 (T): no improvement beyond the same rounding bound for any δ, and, where asked, an increase beyond
  # it for |δ| ≥ 1e-1 (the gain (σ − σ̂)²/(2σ) is at least 0.0045 σ̂, far above 16 eps(T) L at these points).
  Lh = joint_T(st, st.σ̂)
  for δ in DELTAS
    σ = st.σ̂ * (1 + T(δ))
    @test joint_T(st, σ) >= Lh - 16 * eps(T) * Lh
    strict && abs(δ) >= 1e-1 && @test joint_T(st, σ) > Lh + 16 * eps(T) * Lh
  end
  st
end

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@testset "ScaledLasso" begin
  # The problems, solved with a certificate: Float64 twice (n > p and n < p), Float32 dense, Float32 on a
  # SparseIterate (tol = 1e-5, where the default tol is close to the rounding level of Float32 data).
  specs = [("Float64, n > p", Float64, 11, 100, 30, false, (;)),
           ("Float64, n < p", Float64, 12, 60, 80, false, (;)),
           ("Float32, dense", Float32, 13, 100, 30, false, (tol = 1e-5,)),
           ("Float32, SparseIterate", Float32, 14, 100, 30, true, (tol = 1e-5,))]
  cases = map(specs) do (label, T, seed, n, p, owner, kw)
    pr = make_problem(T, seed, n, p)
    @test isfinite(pr.λ) && pr.λ > 0
    @test pr.λ ≈ T(sqrt(n) * Float64(pr.λ₀)) rtol = 4 * eps(T)   # √T(n) λ₀ within rounding of √n λ₀
    @test pr.λ < lambda_max(pr.X, pr.y)
    β, res, logs = sqrt_solve(pr.X, pr.y, pr.λ, zeros(T, p); owner = owner, order = :cyclic, momentum = false, kw...)
    @test res.converged && 0 <= res.gap <= 1e-4
    @test isempty(logs)
    (; label, T, pr..., β, res)
  end

  @testset "T1, T2: profile identity and conditional minimality ($(c.label))" for c in cases
    T = c.T
    rng = Xoshiro(100 + c.p)
    # The certified solver output, β = 0, and three seeded sparse points.
    points = [c.β, zeros(T, c.p)]
    for _ in 1:3
      push!(points, T.(0.1 .* randn(rng, c.p) .* (rand(rng, c.p) .< 0.3)))
    end
    for β in points
      check_profile(c.X, c.y, c.λ, β)
    end
  end

  @testset "T3: certificate transfer ($(c.label))" for c in cases
    D = dual_bound_big(c.X, c.y, c.λ, c.β)
    cb = certificate_big(c.X, c.y, c.λ, c.β, D)
    @test cb.positive
    # D ≤ P* ≤ inf L √n, so D/√n ≤ L at any point.
    @test cb.above
    # The contract target 1e-4 for (P(β̂) − P*)/P* ≤ (P − D)/D, and the same for L(β̂, σ̂).
    @test cb.relP <= 1e-4
    @test cb.relL <= 1e-4
    # The two relative gaps are equal up to BigFloat rounding (L(β̂, σ̂) = P/√n); 1e-60 absolute is far above
    # the rounding of the 256-bit evaluation and far below any gap here.
    @test cb.diff <= 1e-60
  end

  @testset "T4: σ̂ in $(c.label) against BigFloat" for c in cases
    T = c.T
    st = stats_T(c.X, c.y, c.λ, c.β)
    σbig = profile_big(c.X, c.y, c.λ, c.β, [1.0]).σ̂
    # Forward error: with γ = k eps(T)/(1 − k eps(T)), the computed r̃ = fl(y − Xβ) has
    # |r̃ᵢ − rᵢ| ≤ γ_{p+1}(|yᵢ| + (|X||β|)ᵢ), so |‖r̃‖ − ‖r‖| ≤ ‖r̃ − r‖ ≤ γ_{p+1}(‖y‖ + ‖|X||β|‖). The norm
    # of r̃ adds at most (n + 2) eps(T) ‖r̃‖ and ‖r̃‖ ≤ (1 + γ_{p+1})(‖y‖ + ‖|X||β|‖); the square root of n and
    # the division add 2 eps(T). Bound: (p + n + 8) eps(T) (‖y‖ + ‖|X||β|‖)/√n, with 8 absorbing the
    # second-order terms.
    scale = Float64(norm(Float64.(c.y)) + norm(abs.(Float64.(c.X)) * abs.(Float64.(c.β))))
    @test abs(Float64(st.σ̂) - σbig) <= (c.p + c.n + 8) * Float64(eps(T)) * scale / sqrt(c.n)
    @test isfinite(c.λ) && c.λ > 0 && isfinite(st.σ̂) && st.σ̂ > 0
  end

  @testset "T5: the tutorial's data have a clearly nonzero residual" begin
    pr = make_problem(Float64, 2026, 200, 50)
    β, res, logs = sqrt_solve(pr.X, pr.y, pr.λ, zeros(50); order = :cyclic, momentum = false)
    @test res.converged && isempty(logs)
    r = pr.y - pr.X * β
    # The residual of a least-squares fit is the smallest possible, ‖y − Xβ‖ ≥ ‖y − X(X \ y)‖ for every β,
    # up to the rounding of the two computations.
    @test norm(r) >= norm(pr.y - pr.X * (pr.X \ pr.y)) * (1 - 1e-12)
    # With noise of standard deviation 0.5 and ‖y‖² ≈ n(Σβ² + 0.25), the least-squares ratio is about
    # 0.5√(n − p)/‖y‖ ≈ 0.14; the lasso residual is at least that, and 0.05 is far from zero.
    @test norm(r) / norm(pr.y) >= 0.05
    @test norm(r) > 0
  end

  @testset "T6: zero and near-zero residual" begin
    for T in (Float32, Float64)
      # (a) An exact fit with exactly representable data: X = [1 2; 0 1], β = (1, 0), y = Xβ = (1, 0).
      X = T[1 2; 0 1]
      β = T[1, 0]
      y = X * β
      @test iszero(y - X * β)
      λ = T(0.1)
      λ₀ = λ / sqrt(T(2))
      σs = T[1, 1e-3, 1e-6]
      ef = exact_fit_big(X, y, λ, β, σs)
      # r = 0 in BigFloat; L(σ) = σ/2 + λ₀‖β‖₁ holds exactly in BigFloat from the stored values;
      # L decreases strictly when σ is halved; L(σ) > λ₀‖β‖₁ = P(β)/√n (the value approached as σ ↓ 0).
      @test ef.zero && ef.exactform && ef.decreasing && ef.above
      @test ef.limit <= 1e-70
      # The same in T: λ₀‖β‖₁ ≈ 0.07 and the smallest gain σ/4 = 2.5e-7 is more than 3.5e-6 relative, above
      # the eps(Float32) ≈ 1.2e-7 rounding of one sum.
      st = stats_T(X, y, λ, β)
      for σ in σs
        @test joint_T(st, σ) ≈ σ / 2 + λ₀ * norm(β, 1) rtol = 2 * eps(T)
        @test joint_T(st, σ / 2) < joint_T(st, σ)
        @test joint_T(st, σ) > λ₀ * norm(β, 1)
      end

      # (b) A small stored nonzero residual: y₁ = fl(1 + ε), so r₁ = y₁ − 1 is exact (Sterbenz) and nonzero.
      # It is not an exact fit: σ̂ = ‖r‖/√n > 0 is finite and the conditional minimizer.
      for ε in (T == Float64 ? (1e-6, 1e-12) : (1e-3, 1e-6))
        yε = copy(y)
        yε[1] = T(1 + ε)
        @test !iszero(yε - X * β)
        @test (yε - X * β)[1] == yε[1] - 1
        stε = check_profile(X, yε, λ, β; strict = false)
        @test isfinite(stε.σ̂) && stε.σ̂ > 0
      end
    end
  end

  @testset "T6 (c), T7 (a): the solver's exact-fit candidate is uncertified" begin
    for T in (Float32, Float64)
      X = T[1 2; 0 1]
      y = T[1, 0]
      λ = T(0.1)
      β, res, logs = sqrt_solve(X, y, λ, zeros(T, 2); order = :cyclic, momentum = false)
      # No certificate: both flags, and the warning that says so.
      @test !res.converged && isnan(res.gap)
      @test any(occursin(UNCERTIFIED, m) for m in messages(logs))
      # The candidate of this run: the point (1, 0) with a stored residual of zero. For it L(β, ·) has no
      # minimizing σ > 0 (T6 (a)); the run says nothing about the joint minimum.
      @test β == T[1, 0]
      @test iszero(y - X * β)
    end
  end

  @testset "T7 (b): a run stopped by maxpasses is uncertified" begin
    pr = make_problem(Float64, 2026, 200, 50)
    βc, resc, _ = sqrt_solve(pr.X, pr.y, pr.λ, zeros(50); order = :cyclic, momentum = false)
    @test resc.converged
    D = dual_bound_big(pr.X, pr.y, pr.λ, βc)
    β1, res1, logs = sqrt_solve(pr.X, pr.y, pr.λ, zeros(50); order = :cyclic, momentum = false, maxpasses = 1)
    @test !res1.converged && isnan(res1.gap)
    @test any(occursin(NOTCONVERGED, m) for m in messages(logs))
    # Its σ̂ = ‖r‖/√n is the conditional minimizer at that point (T2), and L(β, σ̂) = P(β)/√n is at least
    # D/√n since D ≤ P* ≤ P(β).
    check_profile(pr.X, pr.y, pr.λ, β1)
    @test certificate_big(pr.X, pr.y, pr.λ, β1, D).above
  end
end

end
