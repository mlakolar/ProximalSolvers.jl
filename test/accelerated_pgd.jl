module AcceleratedPGDTests
# Accelerated proximal gradient descent (AccProxGradDescent) on the dense least-squares
# lasso. Accuracy is checked against references computed from the raw X, y in BigFloat:
# analytic soft-threshold solutions, a duality gap, KKT residuals and a finite-support
# solve; never only against another solver. `converged` is a stopping-rule flag and is
# checked separately from accuracy.
using Test, LinearAlgebra, SparseArrays, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

const TIGHT = ProximalOptions(maxiter = 20_000, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-11)

big_(a) = BigFloat.(a)

# F(b) = s/2 ‖y - X b‖² + λ ‖b‖₁ from the raw data, in BigFloat.
function objective(X, y, s, λ, b)
  r = big_(y) - big_(X) * big_(b)
  BigFloat(s) * sum(abs2, r) / 2 + BigFloat(λ) * sum(abs, big_(b))
end

# The largest violation of 0 ∈ s Xᵀ(X b - y) + λ ∂‖b‖₁.
function kkt(X, y, s, λ, b)
  c = BigFloat(s) * (big_(X)' * (big_(y) - big_(X) * big_(b)))
  λb = BigFloat(λ)
  Float64(maximum(j -> iszero(b[j]) ? max(abs(c[j]) - λb, 0) : abs(c[j] - λb * sign(b[j])), eachindex(b)))
end

# Duality gap F(b) - D(u) ≥ F(b) - F* for λ > 0, with the dual point u = c s r scaled into
# ‖Xᵀu‖∞ ≤ λ and D(u) = ⟨u, y⟩ - ‖u‖²/(2s). Strong convexity in X b then bounds the
# fitted values: s/2 ‖X(b - b*)‖² ≤ gap, whether or not b* is unique.
function gap(X, y, s, λ, b)
  Xb, yb, sb, λb = big_(X), big_(y), BigFloat(s), BigFloat(λ)
  u = sb * (yb - Xb * big_(b))
  m = maximum(abs, Xb' * u)
  u .*= m > λb ? λb / m : one(BigFloat)
  Float64(objective(X, y, s, λ, b) - (sum(u .* yb) - sum(abs2, u) / (2sb)))
end

λmax(X, y, s) = Float64(maximum(abs, BigFloat(s) * (big_(X)' * big_(y))))

# The lasso solution with the support and signs of `b`, from its restricted normal
# equations in BigFloat; a reference only where X restricted to the support has full rank.
function support_reference(X, y, s, λ, b)
  S = findall(!iszero, b)
  ref = zeros(BigFloat, length(b))
  XS = big_(X[:, S])
  ref[S] = (BigFloat(s) * (XS' * XS)) \ (BigFloat(s) * (XS' * big_(y)) - BigFloat(λ) * sign.(big_(b[S])))
  ref
end

loss(y, X, s) = isone(s) ? LeastSquaresLoss(y, X) : s * LeastSquaresLoss(y, X)

function correlated(::Type{T}, n, p; seed = 1, ρ = 0.8) where T
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  for j in 2:p
    X[:, j] .= ρ .* X[:, j - 1] .+ sqrt(1 - ρ^2) .* X[:, j]
  end
  β = zeros(p); β[1:min(4, p)] .= (1.5, -1.0, 0.75, 2.0)[1:min(4, p)]
  y = X * β + 0.1 * randn(rng, n)
  T.(X), T.(y)
end

# A Sylvester Hadamard matrix: ±1 entries with XᵀX = n I exactly in floating point.
hadamard(k) = k == 0 ? ones(1, 1) : (H = hadamard(k - 1); [H H; H -H])

# Fixture tolerances, per precision, relative to the scale of the problem. They are
# chosen for the fixtures of this file, not derived as a general bound: the
# objective-change test (shared with PGD) stops once successive objectives agree to
# about one ulp, and on these fixtures that leaves coefficient, KKT and gap accuracy
# near √eps(T) (1.5e-8 in Float64, 3.5e-4 in Float32). The bounds are about 70 times
# (Float64) and 14 times (Float32) that scale.
coef_tol(::Type{Float64}) = 1e-6
coef_tol(::Type{Float32}) = 5e-3
kkt_tol(::Type{Float64}) = 1e-6
kkt_tol(::Type{Float32}) = 5e-3
# The duality gap is first order in the KKT violation (the dual point is the scaled
# residual); relative to F(0) it is near √eps(T) as well on these fixtures.
gap_tol(::Type{Float64}) = 1e-6
gap_tol(::Type{Float32}) = 5e-3

@testset "orthogonal designs: analytic soft-threshold solutions" begin
  for T in (Float64, Float32), s in (1, 1 / 16)
    H = hadamard(4)                     # 16 × 16
    d = [1.0, 2.0, 0.5, 4.0, 1.0, 0.25, 2.0, 1.0]
    X = T.(H[:, 1:8] .* d')             # XᵀX = 16 diag(d²), exact in T
    y = T.(H[:, 1:8] * [3.0, -2.0, 0.1, 1.0, -0.05, 0.6, 0.0, -1.5] + 0.01 * H[:, 9])
    sT = T(s)
    c = Float64.(big_(X)' * big_(y)) .* Float64(sT)   # s Xᵀy, exact up to rounding of s
    curv = 16 .* Float64(sT) .* d .^ 2
    lmax = λmax(X, y, sT)
    for λ in (0.0, 0.1 * lmax, 0.5 * lmax, lmax, 2 * lmax)
      λT = T(λ)
      exact = sign.(c) .* max.(abs.(c) .- Float64(λT), 0) ./ curv
      for start in (zeros(T, 8), T.(collect(range(-1, 1; length = 8))))
        x = copy(start)
        r = solve!(x, loss(y, X, sT), NormL1(λT), AccProxGradDescent(), TIGHT)
        @test r.minimizer === x
        @test maximum(abs, Float64.(x) - exact) <= coef_tol(T) * max(1, maximum(abs, exact))
        @test kkt(X, y, sT, λT, x) <= kkt_tol(T) * max(1, lmax)
        λ > lmax && @test all(iszero, x)
      end
    end
  end
end

@testset "correlated full rank: gap, KKT and finite-support reference" begin
  for T in (Float64, Float32), (n, p) in ((40, 12), (80, 30)), raw in (true, false)
    X, y = correlated(T, n, p; seed = n + p)
    s = raw ? one(T) : one(T) / T(n)
    lmax = λmax(X, y, s)
    for frac in (0.0, 0.05, 0.3, 1.0, 1.5)
      λ = T(frac * lmax)
      for start in (:zero, :nonzero)
        x = start === :zero ? zeros(T, p) : T.(0.5 .* sin.(1:p))
        r = solve!(x, loss(y, X, s), NormL1(λ), AccProxGradDescent(), TIGHT)
        @test all(isfinite, x) && r.minimizer === x
        # the reported minimum is the objective at x, in the arithmetic of T
        @test abs(Float64(r.minimum) - Float64(objective(X, y, s, λ, x))) <=
              64 * eps(T) * Float64(objective(X, y, s, λ, x) + BigFloat(s) * sum(abs2, big_(y)))
        @test kkt(X, y, s, λ, x) <= kkt_tol(T) * max(1, lmax)
        if frac > 0
          @test gap(X, y, s, λ, x) <= gap_tol(T) * Float64(objective(X, y, s, λ, zeros(T, p)))
        end
        frac > 1 && @test all(iszero, x)
        if 0 < frac < 1 && T == Float64
          ref = support_reference(X, y, s, λ, x)
          @test kkt(X, y, s, λ, Float64.(ref)) <= 1e-12 * max(1, lmax)
          @test maximum(abs, big_(x) - ref) <= coef_tol(T) * max(1, Float64(maximum(abs, ref)))
        end
      end
    end
  end
end

@testset "rank-deficient, duplicated and zero-column designs" begin
  for T in (Float64, Float32)
    X0, y = correlated(T, 20, 30; seed = 7)            # p > n
    Xdup = hcat(X0[:, 1:10], X0[:, 1:5])               # duplicated columns
    Xzero = copy(X0[:, 1:12]); Xzero[:, 3] .= 0; Xzero[:, 9] .= 0
    for X in (X0, Xdup, Xzero)
      n, p = size(X)
      s = one(T) / T(n)
      lmax = λmax(X, y, s)
      for frac in (0.02, 0.2)
        λ = T(frac * lmax)
        x = zeros(T, p)
        r = solve!(x, loss(y, X, s), NormL1(λ), AccProxGradDescent(), TIGHT)
        @test all(isfinite, x)
        @test kkt(X, y, s, λ, x) <= kkt_tol(T) * max(1, lmax)
        g = gap(X, y, s, λ, x)
        @test g <= gap_tol(T) * Float64(objective(X, y, s, λ, zeros(T, p)))
        # Fitted values are unique: s/2 ‖X(x - b*)‖² ≤ gap for every minimizer b*. Compare
        # with a second solve from another start instead of the (nonunique) coefficients.
        z = T.(cos.(1:p))
        solve!(z, loss(y, X, s), NormL1(λ), AccProxGradDescent(), TIGHT)
        gz = gap(X, y, s, λ, z)
        @test gz <= gap_tol(T) * Float64(objective(X, y, s, λ, zeros(T, p)))
        @test kkt(X, y, s, λ, z) <= kkt_tol(T) * max(1, lmax)
        bound = sqrt(2 * max(g, 0) / Float64(s)) + sqrt(2 * max(gz, 0) / Float64(s))
        @test norm(Float64.(big_(X) * (big_(x) - big_(z)))) <= bound + 1e3 * eps(T) * norm(Float64.(X)) * max(1, norm(Float64.(x)))
        # A zero column has a zero gradient; the final coefficients of both fixture solves
        # (from the zero start x and the nonzero start z) are checked to be zero there.
        X === Xzero && @test x[3] == 0 && x[9] == 0 && z[3] == 0 && z[9] == 0
      end
    end
  end
end

@testset "warm starts" begin
  for T in (Float64, Float32)
    X, y = correlated(T, 60, 20; seed = 11)
    s = one(T) / T(60)
    f = loss(y, X, s)
    lmax = λmax(X, y, s)
    λ1, λ2 = T(0.2 * lmax), T(0.16 * lmax)
    x = zeros(T, 20)
    cold = solve!(x, f, NormL1(λ1), AccProxGradDescent(), TIGHT)
    warm = solve!(x, f, NormL1(λ2), AccProxGradDescent(), TIGHT)
    @test kkt(X, y, s, λ2, x) <= kkt_tol(T) * max(1, lmax)
    # a solve started at an accurate solution stays accurate and stops early (the
    # iteration bound is a loose fixture check, not a performance claim)
    again = solve!(x, f, NormL1(λ2), AccProxGradDescent(), TIGHT)
    @test again.iterations <= 50
    @test kkt(X, y, s, λ2, x) <= kkt_tol(T) * max(1, lmax)
  end
end

# A conservative fixture tolerance, not a proved bound, for the rise of the computed
# objective over a step without momentum: the objective in the arithmetic of T can
# differ from the exact one by roughly (n + p) eps(T) times the magnitudes it adds up,
# and a step that satisfies the bound exactly does not increase the exact objective.
function rounding_bound(X, y, s, λ, x)
  T = eltype(x)
  n, p = size(X)
  z = abs.(Float64.(X)) * abs.(Float64.(x))
  4 * (n + p + 4) * eps(T) * (Float64(s) * sum(abs2, abs.(Float64.(y)) .+ z) / 2 + Float64(λ) * sum(abs, Float64.(x)))
end

image_error(z, X, v) = Float64(norm(big_(z) - big_(X) * big_(v)))

@testset "momentum, backtracking rejection, restart and image caches" begin
  for T in (Float64, Float32), raw in (true, false)
    # Ill-conditioned least squares: momentum overshoots, so the objective-increase
    # restart fires; the curvature exceeds the initial L = 1, so the first trial is rejected.
    n, p = 50, 20
    X, y = correlated(T, n, p; seed = 5, ρ = 0.95)
    X .*= T(3)
    s = raw ? one(T) : one(T) / T(n)
    λ = T(0.01 * λmax(X, y, s))
    f, g = loss(y, X, s), NormL1(λ)
    m = AccProxGradDescent()
    absX = opnorm(abs.(Float64.(X)))
    st = PS.initial_state(m, TIGHT, f, g, zeros(T, p))
    momentum_steps, rejected, restarts = 0, 0, 0
    Fprev = st.f_x + st.g_x
    for it in 1:300
      k0, r0, b0 = st.k, st.restarts, st.backtrack_steps
      older = copy(st.x_previous)                # enters the extrapolated image z_y
      PS.update_state!(f, g, st, m)
      restarted = st.restarts > r0
      momentum = k0 > 0 && !restarted            # an accepted step with ω = k/(k+3) > 0
      momentum_steps += momentum
      restarts += restarted
      # a step from y needs one trial; more trials mean rejected trials
      rejected += (st.backtrack_steps - b0) > (restarted ? 2 : 1)
      F = st.f_x + st.g_x
      if momentum
        @test F <= Fprev                         # exact: the restart test compares these values
      else
        @test Float64(F) <= Float64(Fprev) + rounding_bound(X, y, s, λ, st.x)
      end
      # Image caches against exact products, after extrapolation, rejections and
      # restarts, with a conservative fixture tolerance: a product in T is within about
      # p eps(T) |X||v| of the exact one componentwise, and z_y combines the cached
      # images of the last two accepted iterates (x' and the one before it) with
      # |ω| < 1, adding a few roundings.
      tol = (3p + 8) * eps(T) * absX * (norm(Float64.(st.x)) + norm(Float64.(st.x_previous)) +
                                         norm(Float64.(older)))
      @test image_error(st.z_x, X, st.x) <= tol
      @test image_error(st.z_previous, X, st.x_previous) <= tol
      @test image_error(st.z_y, X, st.y) <= tol
      if restarted
        @test st.y == st.x_previous && st.z_y == st.z_previous
        @test st.k == 1
      end
      Fprev = F
    end
    @test momentum_steps > 50
    @test rejected >= 1
    @test restarts >= 1
    @test st.L > 0 && isfinite(st.L)
    # On this ill-conditioned fixture the accelerated solve stops after fewer iterations
    # than PGD with the same options (a fixture check of the acceleration, with a wide
    # margin; not a matched-accuracy performance claim).
    x, z = zeros(T, p), zeros(T, p)
    opts = ProximalOptions(maxiter = 20_000, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-11)
    ra = solve!(x, f, g, m, opts)
    rp = solve!(z, f, g, ProximalGradientDescent(), opts)
    @test kkt(X, y, s, λ, x) <= kkt_tol(T) * max(1, λmax(X, y, s))
    T == Float64 && @test 2 * ra.iterations < rp.iterations
  end
end

# The certified backtracking test (_bound_certified!) against BigFloat references computed
# from X, x and y themselves (the exact X d), never from the cached images. Checked on the
# sampled data below: an accepted trial satisfies α‖X d‖² ≤ (1 + 4eps)² L‖d‖² for the
# stored x and y, with α the loss scale as given (safety), and L ≥ 4α‖X‖_F², a global
# curvature bound, is accepted (liveness).
exact_ratio(α, X, x, y, L) = (d = big_(x) - big_(y);
  BigFloat(α) * sum(abs2, big_(X) * d) / (BigFloat(L) * sum(abs2, d)))

# The images and error bound as the solver forms them: zu fresh (y = x_a), or extrapolated
# from fresh images of x_a and x_b with ω.
function certified(T, X, x, xa, xb, ω, L, α; fresh_only = false)
  n, p = size(X)
  extrapolated = ω > 0
  y = extrapolated ? xa .+ ω .* (xa .- xb) : copy(xa)
  za, zb = X * xa, X * xb
  zu = extrapolated ? za .+ ω .* (za .- zb) : za
  zw = X * x
  d = x .- y
  loss = LeastSquaresLoss(zeros(T, n), X)
  m = PS._image_model(isone(α) ? loss : α * loss)
  bc = PS._bound_constants(T, X)
  # the iterate norms as the solver forms them (one pass when accurate)
  Ey = PS._image_error_bound(bc, PS._se_norm_onepass(T, sum(abs2, xa), xa),
                             PS._se_norm_onepass(T, sum(abs2, xb), xb), extrapolated)
  sd, sx = PS._sumsq2(d, x)
  D, normx = PS._se_norm_onepass(T, sd, d), PS._se_norm_onepass(T, sx, x)
  iszero(D.s) && return nothing, y
  R = promote_type(T, typeof(float(α)))
  ok, fresh = PS._bound_certified!(zeros(T, n), m, zu, zw, d, D, T(L), Ey, normx,
                                   PS._SE{T}(sqrt(R(α))), bc, fresh_only)
  (ok, fresh), y
end

@testset "certified backtracking test against BigFloat references" begin
  rng = Xoshiro(265)
  for T in (Float32, Float64)
    E = T == Float32 ? 40 : 300            # exponent spans of scales and offsets
    tol = (1 + 4eps(T))^2
    accepted = rejected = fallbacks = live = 0
    for trial in 1:600
      n, p = rand(rng, 1:25), rand(rng, 1:25)
      # occasionally data deep in the subnormal range of T
      sub = rand(rng) < 0.15 ? (T == Float32 ? -140 : -1060) : 0
      X = T.(randn(rng, n, p) .* 2.0^(sub == 0 ? rand(rng, -E:E) : rand(rng, -E:0)))
      # a large common offset (large images) with a small difference, or no offset
      c = rand(rng, Bool) ? 2.0^rand(rng, 0:E) : 0.0
      xs = 2.0^sub
      xa = T.((c .+ randn(rng, p)) .* xs); xb = T.((c .+ randn(rng, p)) .* xs)
      x = T.(Float64.(xa) .+ randn(rng, p) .* 2.0^rand(rng, -E÷2:0) .* xs)
      ω = rand(rng, (zero(T), T(0.25), T(0.9), prevfloat(one(T)), one(T)))
      α = rand(rng, (1, T(2.0)^rand(rng, -E÷2:E÷2), 2.0^rand(rng, -E÷2:E÷2),
                     Float32(1 + rand(rng)) * Float32(2.0)^rand(rng, -20:20)))
      T == Float32 && α isa Float64 && !isfinite(Float32(α)) && continue
      T == Float32 && α isa Float64 && iszero(Float32(α)) && continue
      all(isfinite, X) && all(isfinite, x) && all(isfinite, xa) && all(isfinite, xb) || continue
      y = ω > 0 ? xa .+ ω .* (xa .- xb) : xa
      all(isfinite, y) && any(!=(0), x .- y) || continue
      curvature = exact_ratio(α, X, x, y, one(T))
      for factor in (1 / 16, 1 / 2, 1, 2, 16)
        L = curvature * factor
        (L > floatmax(T) || L < floatmin(T)) && continue
        r, y2 = certified(T, X, x, xa, xb, ω, L, α)
        r === nothing && continue
        ok, fresh = r
        fallbacks += fresh
        if ok
          accepted += 1
          @test exact_ratio(α, X, x, y2, T(L)) <= tol           # never accepts a violated bound
        else
          rejected += 1
        end
        rB, _ = certified(T, X, x, xa, xb, ω, L, α; fresh_only = true)
        rB[1] && @test exact_ratio(α, X, x, y2, T(L)) <= tol    # Option B is safe too
      end
      # liveness: a global curvature bound is accepted, for data in the normal range (with
      # subnormal data the products underflow and carry no information, so the test is
      # inconclusive and rejects)
      Lg = 4 * BigFloat(α) * sum(abs2, big_(X))
      if sub == 0 && floatmin(T) <= Lg <= floatmax(T) / 4
        r, _ = certified(T, X, x, xa, xb, ω, Lg, α)
        r === nothing || (@test r[1]; live += 1)
      end
    end
    @test accepted >= 300 && rejected >= 300 && live >= 100 && fallbacks >= 1
  end
end

@testset "certified test: subnormal norms, wide scales and nonfinite inputs" begin
  for T in (Float32, Float64)
    t = nextfloat(zero(T))
    m = PS._image_model(LeastSquaresLoss(zeros(T, 3), ones(T, 3, 1)))
    one_se = PS._SE{T}(one(T))
    # images [t, t] (or three entries) of d = [t] with X = ones: the exact curvature is 2 (3)
    call(k, L) = PS._bound_certified!(zeros(T, k), PS._image_model(LeastSquaresLoss(zeros(T, k), ones(T, k, 1))),
      zeros(T, k), fill(t, k), T[t], PS._se_norm(T, T[t]), T(L), PS._se_zero(T),
      PS._se_norm(T, T[t]), one_se, PS._bound_constants(T, ones(T, k, 1)), false)[1]
    # Subnormal images carry absolute rounding error (underflow) comparable to their size,
    # so a violated bound is rejected and acceptance needs a margin above the curvature.
    @test !call(2, 1) && !call(2, 1.9)       # exact ratio 2 and 2/1.9: rejected
    @test call(2, 20)
    @test !call(3, 1.5) && !call(3, 2.9) && call(3, 30)
    # a nonzero d whose ‖d‖² underflows is compared, not taken for zero
    tiny = T == Float32 ? 1f-30 : 1e-200
    @test iszero(sum(abs2, T[tiny]))
    @test call2 = PS._bound_certified!(zeros(T, 1), PS._image_model(LeastSquaresLoss(zeros(T, 1), ones(T, 1, 1))),
      zeros(T, 1), T[tiny], T[tiny], PS._se_norm(T, T[tiny]), T(1.01), PS._se_zero(T),
      PS._se_norm(T, T[tiny]), one_se, PS._bound_constants(T, ones(T, 1, 1)), false)[1]
    # A nonfinite cached image gives no cheap decision; the fresh product X d, which does
    # not use the cached images, decides (the solver calls the test only with a finite
    # trial value). Here X d = [1, 1], so L = 1.5 is rejected and L = 2.01 accepted.
    m1 = PS._image_model(LeastSquaresLoss(zeros(T, 2), ones(T, 2, 1)))
    bc1 = PS._bound_constants(T, ones(T, 2, 1))
    for zw in (T[NaN, 1], T[Inf, 1])
      r1 = PS._bound_certified!(zeros(T, 2), m1, zeros(T, 2), zw, T[1], PS._se_norm(T, T[1]), T(1.5),
                                PS._se_zero(T), PS._se_norm(T, T[1]), one_se, bc1, false)
      r2 = PS._bound_certified!(zeros(T, 2), m1, zeros(T, 2), zw, T[1], PS._se_norm(T, T[1]), T(2.01),
                                PS._se_zero(T), PS._se_norm(T, T[1]), one_se, bc1, false)
      @test r1 == (false, true) && r2 == (true, true)
    end
    @test !PS._bound_certified!(zeros(T, 2), m1, zeros(T, 2), T[1, 1], T[1], PS._se_norm(T, T[1]),
                                zero(T), PS._se_zero(T), PS._se_norm(T, T[1]), one_se, bc1, false)[1]
  end
  # the loss scale is used as given: a Float64 scale near the smallest Float32 subnormal
  s = 1.49 * Float64(nextfloat(0f0))
  X = reshape(Float32[1f20], 1, 1)
  f = s * LeastSquaresLoss(Float32[1], X)
  st = PS.initial_state(AccProxGradDescent(α = 1.5f-5), TIGHT, f, NormL1(0f0), zeros(Float32, 1))
  PS.update_state!(f, NormL1(0f0), st, AccProxGradDescent(α = 1.5f-5))
  @test s * 1e40 <= (1 + 4eps(Float32))^2 * Float64(st.L)
end

@testset "curvature beyond floatmax with large common images fails with rollback" begin
  # The step from x0 = nextfloat(y/X) has an image difference at the rounding level of
  # the images; the curvature 4e38 exceeds floatmax(Float32), so no trial is certified.
  X = reshape(Float32[2f19], 1, 1); y = Float32[1f10]
  x = Float32[nextfloat(y[1] / X[1])]; x0 = copy(x)
  @test_throws r"cannot increase finitely" solve!(x, LeastSquaresLoss(y, X), NormL1(0f0), AccProxGradDescent())
  @test x == x0
end

@testset "underflow, narrower loss scales and norm budgets" begin
  # A trial whose products underflow to zero: no uphill step is accepted (BigFloat objective).
  t = nextfloat(0f0)
  X = fill(0.25f0, 1, 1); Y = Float32[4t]; λ = 0.99 * Float64(t)
  x = zeros(Float32, 1)
  solve!(x, LeastSquaresLoss(Y, X), NormL1(λ), AccProxGradDescent(α = 0.01))
  F(v) = big(0.5) * (big(X[1]) * big(v[1]) - big(Y[1]))^2 + big(λ) * abs(big(v[1]))
  @test F(x) <= F(zeros(Float32, 1))
  for T in (Float32, Float64)
    tT = nextfloat(zero(T))
    # products that round to zero, and an extrapolated image of a subnormal rounded y
    r, y = certified(T, fill(T(0.25), 1, 1), T[tT], T[0], T[0], zero(T), T(0.01), 1)
    @test r === nothing || !r[1] || exact_ratio(1, fill(T(0.25), 1, 1), T[tT], y, T(0.01)) <= (1 + 4eps(T))^2
    Xe = fill(T(0.25) / floatmin(T), 1, 1)
    α = tT
    L = T(0.8 * BigFloat(α) * BigFloat(Xe[1])^2)
    for fresh in (false, true)
      r, y = certified(T, Xe, T[2tT], T[tT], T[0], T(0.25), L, α; fresh_only = fresh)
      r === nothing || !r[1] || @test exact_ratio(α, Xe, T[2tT], y, L) <= (1 + 4eps(T))^2
    end
  end
  # A Float32 loss scale on Float64 data: √α is not computed in Float32.
  f = 0.5f0 * LeastSquaresLoss([1.0], ones(1, 1))
  st = PS.initial_state(AccProxGradDescent(α = 0.49999999), TIGHT, f, NormL1(0.0), [0.0])
  PS.update_state!(f, NormL1(0.0), st, AccProxGradDescent(α = 0.49999999))
  @test BigFloat(0.5f0) <= (1 + 4eps())^2 * BigFloat(st.L)
  # ... and a curvature just above floatmax(Float64) with such a scale fails with rollback.
  Xf = fill(sqrt(floatmax(Float64)) * sqrt(2.0) * (1 + 5e-9), 1, 1)
  x = [0.0]
  @test_throws r"cannot increase finitely" solve!(x, 0.5f0 * LeastSquaresLoss([1.0], Xf), NormL1(0.0),
                                                  AccProxGradDescent(α = 1.0, β = nextfloat(1 / floatmax(Float64))))
  @test x == [0.0]
  # The fresh-product error bound covers the actual error of a long reduction.
  c = 0.7071977f0; v = Float32[1.4140569f0]
  Xb = fill(c, 1_000_000, 1); Xb[1] = 1
  z = Xb * v
  bc = PS._bound_constants(Float32, Xb)
  E = PS._image_error_bound(bc, PS._se_norm(Float32, v), PS._se_norm(Float32, v), false)
  actual = sqrt(BigFloat(999_999)) * abs(BigFloat(z[2]) - BigFloat(c) * BigFloat(v[1]))
  @test actual <= ldexp(BigFloat(E.s), E.e)
  # ‖X‖_F enters as an upper bound
  Xn = fill(0.7072f0, 1000, 1000); Xn[1] = 1
  nF = PS._frobenius_upper(Float32, Xn)
  @test ldexp(BigFloat(nF.s), nF.e) >= sqrt(1 + (length(Xn) - 1) * BigFloat(0.7072f0)^2)
end

@testset "the fresh-product reference (Option B) on fixtures" begin
  for T in (Float64, Float32)
    X, y = correlated(T, 50, 20; seed = 5, ρ = 0.95)
    X .*= T(3)
    s = one(T) / T(50)
    f, g = loss(y, X, s), NormL1(T(0.01 * λmax(X, y, s)))
    m = AccProxGradDescent()
    for fresh in (false, true)
      st = PS.initial_state(m, TIGHT, f, g, zeros(T, 20))
      st.fresh_only = fresh
      r = PS._solve_gradient!(st, f, g, m, TIGHT)
      @test kkt(X, y, s, g.λ0, st.x) <= kkt_tol(T) * max(1, λmax(X, y, s))
      fresh && @test st.fallbacks == r.prox_calls      # every trial used the fresh product
    end
  end
end

@testset "range counterexamples end to end (BigFloat objective)" begin
  F(f, X, y, s, x) = BigFloat(s) * sum(abs2, big_(y) - big_(X) * big_(x)) / 2
  # xtol is compared with max(‖x‖, 1) and ftol is added to |F| in the objective test, so
  # solutions of size 1e-160 and objectives of size 1e-30 need both far below that
  long = ProximalOptions(maxiter = 500, ftol = 1e-300, xtol = 1e-300, gradtol = 0)
  # weighted curvature 1e-8 with a loss scale of 1e38: no uphill step, solution y/X = 1e13
  X, y = reshape(Float32[1f-23], 1, 1), Float32[1f-10]
  x = zeros(Float32, 1)
  r = solve!(x, 1f38 * LeastSquaresLoss(y, X), NormL1(0f0), AccProxGradDescent(α = 1f-30))
  @test !r.f_increased && F(nothing, X, y, 1f38, x) <= F(nothing, X, y, 1f38, zeros(Float32, 1))
  @test abs(Float64(x[1]) - 1e13) <= 1e-3 * 1e13
  # curvatures near floatmax: X = 1f20 with a Float64 scale 1e-20, X = 1e160 with 1e-20,
  # raw X = 1f19·I: each reaches its solution y/X
  for (T, Xv, yv, s, p) in ((Float32, 1f20, 1f0, 1e-20, 1), (Float64, 1e160, 1.0, 1e-20, 1),
                            (Float32, 1f19, 1f0, 1, 4))
    X = Matrix{T}(Xv * I, p, p); y = fill(T(yv), p)
    f = s == 1 ? LeastSquaresLoss(y, X) : s * LeastSquaresLoss(y, X)
    x = zeros(T, p)
    r = solve!(x, f, NormL1(zero(T)), AccProxGradDescent(), long)
    @test !r.f_increased && all(isfinite, x)
    @test maximum(abs, Float64.(x) ./ (Float64(yv) / Float64(Xv)) .- 1) <= (T == Float32 ? 1e-5 : 1e-12)
  end
end

@testset "a nonfinite value at the extrapolated point restarts the step" begin
  T = Float32
  X, y = Matrix{T}(I, 2, 2), zeros(T, 2)
  f, g = LeastSquaresLoss(y, X), NormL1(zero(T))
  m = AccProxGradDescent()
  st = PS.initial_state(m, TIGHT, f, g, zeros(T, 2))
  # f(x) and f(x') are finite, but y = x + ω (x - x') with ω ≈ 1 overflows f in Float32.
  st.x .= T[1.5f19, 0]; st.x_previous .= T[-1.5f19, 0]
  st.z_x .= X * st.x; st.z_previous .= X * st.x_previous
  st.normx = PS._se_norm(T, st.x); st.normx_previous = PS._se_norm(T, st.x_previous)
  st.f_x = sum(abs2, st.x) / 2; st.g_x = 0
  st.k = 1000
  @test isfinite(st.f_x)
  g0 = st.grad_calls
  PS.update_state!(f, g, st, m)
  @test st.restarts == 1 && st.k == 1
  @test st.grad_calls - g0 == 2                 # one gradient at the overflowing y, one at x'
  @test st.y == st.x_previous == T[1.5f19, 0] && st.z_y == st.z_previous
  @test isfinite(st.f_x) && st.f_x < st.f_x_previous
end

@testset "nonfinite trials, curvature overflow and rollback" begin
  # Trials with L = 1 overflow the image in Float32 (f = Inf); backtracking increases L
  # to about the curvature 1e36, and the solve reaches the solution x = (1, 1).
  T = Float32
  X, y = T[1f18 0; 0 1f18], T[1f18, 1f18]
  x = zeros(T, 2)
  r = solve!(x, LeastSquaresLoss(y, X), NormL1(zero(T)), AccProxGradDescent(), TIGHT)
  @test all(isfinite, x) && r.backtrack_steps > 100
  @test maximum(abs, Float64.(x) .- 1) <= 1e-3
  # The needed curvature 1e40 exceeds floatmax(Float32): L/β overflows and the line
  # search raises instead of looping or accepting a trial; x keeps its last accepted value.
  # In the second fixture the trial steps are so short that ‖x - y‖² underflows to zero
  # while x ≠ y; the bound is still compared (scaled by max |x - y|), so no trial that
  # fails it is accepted and the solve fails with rollback.
  x = zeros(T, 1)
  @test_throws r"cannot increase finitely" solve!(x, LeastSquaresLoss(T[1f-20], reshape(T[1f20], 1, 1)),
                                                  NormL1(zero(T)), AccProxGradDescent())
  @test x == zeros(T, 1)
  # The Float64 analogue has a representable curvature (1e200): the trial whose ‖x - y‖²
  # underflows is compared and rejected until L is large enough, and the accepted step
  # decreases the objective.
  x = zeros(1)
  f64 = LeastSquaresLoss([1e-80], reshape([1e100], 1, 1))
  r = solve!(x, f64, NormL1(0.), AccProxGradDescent())
  @test 0 < x[1] <= 2e-180 && !r.f_increased
  @test objective(reshape([1e100], 1, 1), [1e-80], 1, 0., x) < objective(reshape([1e100], 1, 1), [1e-80], 1, 0., [0.])
  # A step that is entrywise zero is accepted: at the solution x = y = 0 of λ ≥ λmax.
  x = zeros(T, 2)
  r = solve!(x, LeastSquaresLoss(T[1, 1], T[1 0; 0 1]), NormL1(T(2)), AccProxGradDescent())
  @test x == zeros(T, 2) && r.iterations == 1 && r.x_converged
  for start in (zeros(T, 2), T[1f-21, -1f-21])
    x = copy(start)
    @test_throws r"cannot increase finitely" solve!(x, LeastSquaresLoss(T[1, 1], T[1f20 0; 0 1f20]),
                                                    NormL1(zero(T)), AccProxGradDescent(), TIGHT)
    @test x == start
  end
end

# A penalty whose proximal operator throws on a chosen call, so that a step fails after
# accepted iterations, during rejected trials or during a restart.
mutable struct FailingL1{T} <: ProximalBase.AbstractFunction
  inner::NormL1{T, Nothing}
  calls::Int
  fail_at::Int
end
(g::FailingL1)(x) = g.inner(x)
function ProximalBase.value_and_prox!(x::Vector, g::FailingL1, z::Vector, γ::Real)
  g.calls += 1
  g.calls == g.fail_at && error("planted proximal failure")
  ProximalBase.value_and_prox!(x, g.inner, z, γ)
end

@testset "a step error restores the last accepted iterate" begin
  for T in (Float64, Float32)
    X, y = correlated(T, 50, 20; seed = 5, ρ = 0.95)
    X .*= T(3)
    s = one(T) / T(50)
    f = loss(y, X, s)
    λ = T(0.01 * λmax(X, y, s))
    m = AccProxGradDescent()
    after_progress = 0
    for fail_at in 1:60
      g = FailingL1(NormL1(λ), 0, fail_at)
      start = T.(0.1 .* cos.(1:20))
      x = copy(start)
      accepted = Vector{T}[]
      options = ProximalOptions(maxiter = 1000, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-11,
        extended_trace = true, callback = os -> (push!(accepted, copy(os.metadata["x"])); false))
      state = PS.initial_state(m, options, f, g, x)
      @test_throws r"planted proximal failure" PS._solve_gradient!(state, f, g, m, options)
      @test x == (isempty(accepted) ? start : accepted[end])
      after_progress += !isempty(accepted)
    end
    @test after_progress >= 50         # most failures come after accepted iterations
  end
end

function refused(x, f, g, method; options = nothing, kwargs...)
  original = copy(x)
  @test_throws ArgumentError options === nothing ? solve!(x, f, g, method; kwargs...) :
    solve!(x, f, g, method, options; kwargs...)
  @test isequal(x, original)
end

# A penalty that checks the image caches of the state at every trial: z_y and z_previous
# before each trial, and the image z_x of the preceding (rejected) trial point.
mutable struct CheckingL1{T, S} <: ProximalBase.AbstractFunction
  inner::NormL1{T, Nothing}
  X::Matrix{T}
  state::S
  errors::Vector{Float64}   # relative image errors, one row of three per trial
  trials_after_rejection::Int
  last_y::Vector{T}
end
(g::CheckingL1)(x) = g.inner(x)
function ProximalBase.value_and_prox!(x::Vector, g::CheckingL1, z::Vector, γ::Real)
  st = g.state[]
  if st !== nothing
    rel(img, v) = Float64(norm(big_(img) - big_(g.X) * big_(v)) / (norm(big_(g.X) * big_(v)) + 1))
    push!(g.errors, rel(st.z_y, st.y), rel(st.z_previous, st.x_previous))
    # a second trial from the same y follows a rejection; z_x then holds that trial's image
    if st.y == g.last_y
      push!(g.errors, rel(st.z_x, x))
      g.trials_after_rejection += 1
    end
    copyto!(g.last_y, st.y)
  end
  ProximalBase.value_and_prox!(x, g.inner, z, γ)
end

@testset "image caches inside rejected trials; counters" begin
  for T in (Float64, Float32)
    n, p = 50, 20
    X, y = correlated(T, n, p; seed = 5, ρ = 0.95)
    X .*= T(3)
    s = one(T) / T(n)
    f = loss(y, X, s)
    holder = Ref{Any}(nothing)
    g = CheckingL1(NormL1(T(0.01 * λmax(X, y, s))), X, holder, Float64[], 0, fill(T(NaN), p))
    m = AccProxGradDescent()
    st = PS.initial_state(m, TIGHT, f, g, zeros(T, p))
    holder[] = st
    iterations = 150
    for _ in 1:iterations
      PS.update_state!(f, g, st, m)
    end
    @test g.trials_after_rejection >= 1
    @test maximum(g.errors) <= (3p + 8) * eps(T) * 10
    # one gradient per step and one more per restart; one value per trial and at the start
    @test st.grad_calls == iterations + st.restarts
    @test st.f_calls == 1 + st.grad_calls + st.prox_calls
    @test st.backtrack_steps == st.prox_calls
  end
end

@testset "a Float64 loss scale with Float32 data" begin
  X, y = correlated(Float32, 40, 12; seed = 9)
  f = (1 / 40) * LeastSquaresLoss(y, X)       # the scale stays Float64
  @test f.α isa Float64
  λ = Float32(0.1 * λmax(X, y, 1 / 40))
  x = zeros(Float32, 12)
  r = solve!(x, f, NormL1(λ), AccProxGradDescent(), TIGHT)
  @test eltype(x) == Float32 && r.minimum isa Float32
  @test kkt(X, y, 1 / 40, λ, x) <= kkt_tol(Float32) * max(1, λmax(X, y, 1 / 40))
  # a scale that underflows in Float32 is refused before mutation
  refused(zeros(Float32, 12), 1e-60 * LeastSquaresLoss(y, X), NormL1(λ), AccProxGradDescent())
end


@testset "constructor and method settings" begin
  m = AccProxGradDescent()
  @test m.β == 0.5 && m.α == 0.9 && m.preconditioner === nothing
  @test AccProxGradDescent(0.25, 1.0) == AccProxGradDescent(β = 0.25, α = 1.0)
  @test AccProxGradDescent(β = 0.5f0, α = 0.9) isa AccProxGradDescent{Float64}
  @test summary(m) == "Accelerated Proximal Gradient Descent"
  for β in (0.0, 1.0, -0.5, 1.5, NaN, Inf)
    @test_throws ArgumentError AccProxGradDescent(β = β)
  end
  for α in (0.0, -0.1, 1.5, NaN, Inf)
    @test_throws ArgumentError AccProxGradDescent(α = α)
  end
  @test_throws ArgumentError AccProxGradDescent(preconditioner = :diagonal)
  @test_throws TypeError AccProxGradDescent(β = 1 // 2)
  # positional struct constructors bypass the keyword checks; solve! repeats them
  f, g = LeastSquaresLoss([1.], ones(1, 1)), NormL1(.1)
  for bad in (AccProxGradDescent(2.0, 0.9, nothing), AccProxGradDescent(0.5, 0.0, nothing),
              AccProxGradDescent(0.5, 0.9, :diagonal), AccProxGradDescent(NaN, 0.9, nothing))
    refused([0.], f, g, bad)
  end
  # β and α must keep their bounds in the precision of the iterate
  for T in (Float64, Float32)
    X, y = T[1 0; 0 2], T[1, -1]
    f, g = LeastSquaresLoss(y, X), NormL1(T(.1))
    for bad in (AccProxGradDescent(β = 1e-50), AccProxGradDescent(α = 1e-50),
                AccProxGradDescent(β = 1 - 1e-10))
      if T == Float32
        refused(T[.3, -.2], f, g, bad)
      else
        @test PS._check_method(bad, T) === nothing
      end
    end
    # extreme but representable settings still give a bounded solve in Float64; with
    # β = 1e-50 one rejected trial sets L ≈ 1e50, so the objective may not move
    if T == Float64
      for m in (AccProxGradDescent(β = 1e-50), AccProxGradDescent(α = 1e-50))
        x = T[.3, -.2]
        F0 = objective(X, y, 1, T(.1), x)
        r = solve!(x, f, g, m, ProximalOptions(maxiter = 50))
        @test all(isfinite, x) && objective(X, y, 1, T(.1), x) <= F0
      end
    end
  end
end

@testset "unsupported inputs and options are refused before mutation" begin
  for T in (Float64, Float32)
    method = AccProxGradDescent()
    X, y, x = T[1 0; 0 2], T[1, -1], T[.3, -.2]
    f, g = LeastSquaresLoss(y, X), NormL1(T(.1))
    for bad in (sparse(x), reshape(copy(x), 1, 2), view(x, :), SparseIterate(x),
                Int[0, 0], Float16[0, 0], zeros(T === Float32 ? Float64 : Float32, 2))
      refused(bad, f, g, method)
    end
    refused(x, LeastSquaresLoss(y, sparse(X)), g, method)
    refused(x, LeastSquaresLoss(reshape(y, 2, 1), X), g, method)
    refused(x, QuadraticFunction(Matrix{T}(I, 2, 2), zeros(T, 2)), g, method)
    refused(x, Scaled(Scaled(f, 1e-200), 1e-200), g, method)
    refused(x, f, NormL1(T(.1), ones(T, 2)), method)
    refused(x, f, SqrNormL2(T(.1)), method)
    refused(x, f, g, method; screening = true)
    for data in (T[NaN, 0], T[Inf, 0])
      refused(data, f, g, method)
      refused(x, LeastSquaresLoss(data, X), g, method)
    end
    alias_x = copy(x)
    refused(alias_x, LeastSquaresLoss(T[1], reshape(alias_x, 1, 2)), g, method)
    @test_throws DimensionMismatch solve!(zeros(T, 3), f, g, method)
    T === Float32 && refused(x, f, NormL1(1e40), method)
    refused(x, f, g, method; options = ProximalOptions(gaptol = .1))
    valid = ProximalOptions()
    for (field, bad) in ((:maxiter, 1), (:ftol, NaN), (:xtol, 0.), (:gradtol, -1.),
                         (:f_calls_limit, -1), (:print_every, 0), (:time_limit, NaN))
      values = Any[getfield(valid, n) for n in fieldnames(typeof(valid))]
      values[findfirst(==(field), fieldnames(typeof(valid)))] = bad
      refused(x, f, g, method; options = typeof(valid)(values...))
    end
    @test x == T[.3, -.2] && X == T[1 0; 0 2] && y == T[1, -1]
  end
  # a start where f is not finite is refused before any step
  x = [1e200, 1e200]
  @test_throws ArgumentError solve!(x, LeastSquaresLoss([0.], [1e200 1e200]), NormL1(0.), AccProxGradDescent())
  @test x == [1e200, 1e200]
end

@testset "trace, callbacks, limits, result identity and counters" begin
  for T in (Float64, Float32)
    X, y = correlated(T, 40, 15; seed = 3)
    s = one(T) / T(40)
    f, g = loss(y, X, s), NormL1(T(0.05))
    m = AccProxGradDescent()

    x = zeros(T, 15)
    r = solve!(x, f, g, m, ProximalOptions(maxiter = 5000, ftol = 1e-12, xtol = 1e-12,
                                           gradtol = 1e-9, store_trace = true, extended_trace = true))
    @test r.minimizer === x && r.method === m
    @test length(r.trace) == r.iterations
    @test [t.iteration for t in r.trace] == 1:r.iterations
    @test r.trace[end].fg_x == Float64(r.minimum)
    @test haskey(r.trace[end].metadata, "x") && haskey(r.trace[end].metadata, "grad_f(y)")
    @test r.trace[end].metadata["x"] == x
    # one value-and-gradient at y per step (two when it restarts), one value per trial
    @test r.f_calls == 1 + r.grad_calls + r.prox_calls
    @test r.backtrack_steps == r.prox_calls
    @test r.iterations <= r.grad_calls <= 2 * r.iterations
    @test r.grad_calls <= r.prox_calls
    @test isnan(r.gap) && !r.call_limit_reached
    @test occursin("Accelerated Proximal Gradient Descent", sprint(show, r))
    @test r.converged == (r.x_converged || r.f_converged || r.grad_converged)
    @test r.x_residual ≈ norm(Float64.(x) - Float64.(r.trace[end - 1].metadata["x"])) rtol = 1e3 * eps(T)

    # callbacks receive the state, on the print_every cadence, and can stop the solve
    seen = Int[]
    x = zeros(T, 15)
    r = solve!(x, f, g, m, ProximalOptions(maxiter = 5000, print_every = 2,
               callback = os -> (push!(seen, os.iteration); os.iteration >= 6)))
    @test seen == [2, 4, 6] && r.iterations == 6

    # stored traces are passed to the callback instead of the state
    x = zeros(T, 15)
    r = solve!(x, f, g, m, ProximalOptions(maxiter = 5000, store_trace = true,
               callback = tr -> length(tr) >= 3))
    @test r.iterations == 3 && length(r.trace) == 3

    # iteration and call limits
    x = zeros(T, 15)
    r = solve!(x, f, g, m, ProximalOptions(maxiter = 2, ftol = 1e-15, xtol = 1e-15, gradtol = 0))
    @test r.iterations == 2 && r.iteration_converged
    x = zeros(T, 15)
    r = solve!(x, f, g, m, ProximalOptions(maxiter = 5000, ftol = 1e-15, xtol = 1e-15, gradtol = 0,
                                           f_calls_limit = 10))
    @test r.call_limit_reached && r.f_calls >= 10 && !r.converged
    x = zeros(T, 15)
    r = solve!(x, f, g, m, ProximalOptions(time_limit = -1.))
    @test r.iterations == 1

    # a run that stops early is not reported as converged, and x is its last iterate
    x = zeros(T, 15)
    r = solve!(x, f, g, m, ProximalOptions(maxiter = 3, ftol = 1e-15, xtol = 1e-15, gradtol = 0))
    @test !r.converged && kkt(X, y, s, T(0.05), x) > kkt_tol(T)
    @test Float64(r.minimum) ≈ Float64(objective(X, y, s, T(0.05), x)) rtol = 1e3 * eps(T)

    # zero penalty is least squares; the solver keeps native precision
    x = zeros(T, 15)
    r = solve!(x, f, NormL1(zero(T)), m, TIGHT)
    @test eltype(x) == T && r.minimum isa T
    @test kkt(X, y, s, zero(T), x) <= kkt_tol(T) * max(1, λmax(X, y, s))
  end
end

@testset "a warmed step of this fixture allocates nothing" begin
  for T in (Float64, Float32)
    X, y = correlated(T, 30, 10; seed = 2)
    f, g = loss(y, X, one(T) / T(30)), NormL1(T(0.01))
    m = AccProxGradDescent()
    st = PS.initial_state(m, TIGHT, f, g, zeros(T, 10))
    step!(st) = (PS.update_state!(f, g, st, m); nothing)
    step!(st); step!(st)
    @test (@allocated step!(st)) == 0
  end
end

end
