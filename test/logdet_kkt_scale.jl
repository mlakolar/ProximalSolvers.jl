module LogDetKKTScale
# Entrywise KKT scales of matrix PGD for the graphical lasso (#492, PGD-08). At a committed point
# the solver divides the violation rᵢⱼ of entry (i, j) by max(1, sᵢsⱼ), sᵢ = sqrt(|Sᵢᵢ + Cᵢᵢ|), and
# reports R = maxᵢⱼ rᵢⱼ / max(1, sᵢsⱼ). Before #492 it divided every entry by the single scale
# max(1, maximum(abs, S), maximum(C)), so one large entry of S or C loosened the stop of every
# other entry. When some stored |Sᵢⱼ| exceeds 2 max(1, sᵢsⱼ), it also forms each violation from the
# input combination Sᵢⱼ ± Cᵢⱼ and W = inv(Θ), because S - inv(Θ) can round a decisive residual away.
#
# Independent references, computed here in 256-bit BigFloat from the stored data and the returned
# matrices, without ProximalBase's gradient or the solver's helpers (the helpers are called only
# as the objects under test): the inverse, every violation, the scales, R, and a first-order
# allowance for the rounding of the computed score (`rulef`). Fixed points check the reported
# `g_residual` against the definition. Each solve below that reports converged = true is checked
# against R ≤ max(gradtol, 64eps(T)) plus that allowance, and the analytic optima of the 2 × 2
# fixtures are checked directly.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers
const PGD = ProximalGradientDescent

big256(f) = setprecision(f, BigFloat, 256)
τof(::Type{T}, o) where T = max(o.gradtol, 64 * Float64(eps(T)))
target(::Type{Float32}) = 5e-4
target(::Type{Float64}) = 1e-8
gradtol(::Type{Float32}) = 0.0
gradtol(::Type{Float64}) = 5e-10
options(::Type{T}; maxiter = 20000) where T = ProximalOptions(; maxiter, gradtol = gradtol(T), ftol = 0)

offdiagonal(::Type{T}, p, f) where T = [i == j ? zero(T) : T(f(min(i, j), max(i, j))) for i in 1:p, j in 1:p]
ones0(::Type{T}, p) where T = offdiagonal(T, p, (i, j) -> 1)

# The inverse of [a b; b a] in BigFloat, exactly symmetric
inv2(a, b) = (d = a^2 - b^2; [a / d -b / d; -b / d a / d])

function solve_from(Θ0, S, λ0, Λ, o)
  Θ = copy(Θ0)
  r = solve!(Θ, LogDetLoss(copy(S)), NormL1(λ0, copy(Λ)), PGD(), o)
  r, Θ
end

# ---------------------------------------------------------------------------------------------------------
# BigFloat oracle for the score R of PGD-08 at a point Θ, from the stored S and the effective weights
# c = T(λ0) Λ of PGD-06. The allowance bounds the rounding of the computed R in working precision with
# the unit roundoff u: a first-order estimate with slack, not a bound for the BLAS kernel in use. The
# inverse from the Cholesky factor has an error of about (p + 4) u κ₁(Θ) ‖Θ⁻¹‖₁ in each entry, and the
# gradient form S - W adds u(|Sᵢⱼ| + |Wᵢⱼ|); the input form adds the rounding of its input combination
# instead of u|Sᵢⱼ|. Each entry is divided by its scale, as in R.
# ---------------------------------------------------------------------------------------------------------
function rulef(Θ, S, c, ::Type{T}; inputs = false) where T
  big256() do
    p = size(Θ, 1)
    X, A, C = big.(Θ), big.(S), big.(c)
    W = inv(cholesky(Symmetric(X)))
    s = [sqrt(abs(A[i, i] + C[i, i])) for i in 1:p]
    u = big(eps(T)) / 2
    Wnorm = opnorm(W, 1)
    κ = opnorm(X, 1) * Wnorm
    R, e = big(0), big(0)
    for j in 1:p, i in 1:p
      d = max(big(1), s[i] * s[j])
      g = A[i, j] - W[i, j]
      r = iszero(X[i, j]) ? max(abs(g) - C[i, j], big(0)) : abs(g + sign(X[i, j]) * C[i, j])
      combination = iszero(X[i, j]) ? max(abs(A[i, j] - C[i, j]), abs(A[i, j] + C[i, j])) :
                    abs(A[i, j] + sign(X[i, j]) * C[i, j])
      rounding = (p + 4) * u * κ * Wnorm + u * (inputs ? combination + abs(W[i, j]) : abs(A[i, j]) + abs(W[i, j]))
      R, e = max(R, r / d), max(e, rounding / d)
    end
    (R = Float64(R), e = Float64(e))
  end
end

# The reported residual is the definition, up to the allowance; a converged solve meets the stop rule of
# PGD-08 recomputed here. Returns the BigFloat score and its allowance.
function check_result(r, Θ, S, λ0, Λ, ::Type{T}, o; inputs = false) where T
  b = rulef(Θ, S, T(λ0) .* Λ, T; inputs)
  @test abs(r.g_residual - b.R) <= b.e
  @test !r.converged || b.R <= τof(T, o) * (1 + 4 * eps(T)) + b.e
  b
end

# ---------------------------------------------------------------------------------------------------------
@testset "zero-diagonal penalty far above the data: the master route of #492" begin
  # S = [1 0.1; 0.1 1], Λ with zero diagonal and ones off it, optimum Θ = I. At Θ = 1.5I the diagonal
  # gradient is 1 - 2/3 = 1/3, the off-diagonal gradient 0.1 is below its penalty, s = (1, 1) and every
  # scale is 1, so R = 1/3. Before #492 the same point scored (1/3) / λ0, which is 3.3e-10 at λ0 = 1e9.
  for (T, λ0) in ((Float64, 1e9), (Float32, 1e4))
    S, Λ = T[1 0.1; 0.1 1], ones0(T, 2)
    o = options(T)
    Θ = Matrix{T}(1.5I, 2, 2)
    r, _ = solve_from(Θ, S, λ0, Λ, ProximalOptions(time_limit = 0))
    @test !r.converged && r.iterations == 0
    @test abs(r.g_residual - 1 / 3) <= 4 * Float64(eps(T))
    check_result(r, Θ, S, λ0, Λ, T, o)

    r, Θ = solve_from(Matrix{T}(2I, 2, 2), S, λ0, Λ, o)
    @test r.converged && !r.stagnated && r.g_residual <= r.g_tol
    @test maximum(abs, big.(Θ) - I) <= target(T)
    check_result(r, Θ, S, λ0, Λ, T, o)
  end
end

@testset "indefinite S: an off-diagonal entry that cancels its penalty" begin
  # S₁₂ = 1e9 (Float64) or 2¹⁶ (Float32) against C₁₂ = S₁₂ - e, with e = 0.4 or 0.375 up to the stored
  # numbers. The optimum is Θ = inv([1 e; e 1]) with Θ₁₂ < 0. Before #492 the solve converged after one step,
  # 26% from the optimum. Here |S₁₂| exceeds 2 max(1, s₁s₂) = 2, so each violation is formed from
  # S₁₂ - C₁₂ and W = inv(Θ).
  for (T, S12, λ0, δ) in ((Float64, 1e9, 1e9 - 0.4, 4e-8), (Float32, 2f0^16, Float64(Float32(65536 - 0.375)), 1e-3))
    S, Λ = T[1 S12; S12 1], ones0(T, 2)
    c = T(λ0) .* Λ
    e = big(S[1, 2]) - big(c[1, 2])                  # the stored S₁₂ - C₁₂, exact
    @test PS._logdet_pgd_cancellation(S, ones(T, 2))
    point(x) = T.(big256(() -> inv2(big(1), big(x))))
    # At Θ = I the diagonal violations vanish and the zero entry has violation S₁₂ - C₁₂ = e, so R = e.
    Θ = Matrix{T}(I, 2, 2)
    r, _ = solve_from(Θ, S, λ0, Λ, ProximalOptions(time_limit = 0))
    b = check_result(r, Θ, S, λ0, Λ, T, options(T); inputs = true)
    @test abs(b.R - Float64(e)) <= 1e-12 && abs(r.g_residual - Float64(e)) <= 4 * Float64(eps(T))
    # At the optimum W₁₂ = e. At W₁₂ = e + δ the spacing of the numbers near S₁₂ is more than 2δ, so the
    # computed S₁₂ - W₁₂ is C₁₂ and the gradient form scores the entry as 0, while its violation is δ.
    for offset in (0, δ)
      Θ = point(e + offset)
      @test Θ[1, 2] < 0
      r, _ = solve_from(Θ, S, λ0, Λ, ProximalOptions(time_limit = 0))
      b = check_result(r, Θ, S, λ0, Λ, T, options(T); inputs = true)
      if offset > 0
        G = S .- inv(cholesky(Symmetric(Θ)))
        @test iszero(G[1, 2] - c[1, 2])
        @test b.R > δ / 2 && r.g_residual > δ / 2
      else
        @test r.g_residual <= 4 * b.e
      end
    end
    # From 2I the solve does not stop where the gradient form scores 0 or a global scale loosens the test: it is not
    # converged or the bound holds. After two steps the reported score is the definition, which checks the
    # reuse of the Cholesky factor inside a step.
    o = options(T; maxiter = 200)
    r, Θ = solve_from(Matrix{T}(2I, 2, 2), S, λ0, Λ, o)
    check_result(r, Θ, S, λ0, Λ, T, o; inputs = true)
    o = options(T; maxiter = 2)
    r, Θ = solve_from(Matrix{T}(2I, 2, 2), S, λ0, Λ, o)
    b = check_result(r, Θ, S, λ0, Λ, T, o; inputs = true)
    @test r.iterations == 2 && b.R > 1e-3
  end
end

@testset "one large variance does not loosen the other entries" begin
  # S = diag(1e9, 1.4) (Float64) or diag(1e5, 1.5) (Float32), no penalty. At Θ = diag(1/S₁₁, 1) the second
  # entry has violation S₂₂ - 1 and scale S₂₂, so R = 0.4/1.4 (or 1/3); the global scale before #492 gave
  # 4e-10 (or 5e-6). The first entry's violation is about eps(T) S₁₁ against its scale S₁₁. PGD makes almost
  # no progress on θ₂₂ here, because its step is limited by the curvature in θ₁₁. The allowance of
  # the rounded inverse is not informative at the condition number 1e9, so the comparisons use the fixed
  # allowance 1e-6, which is far below the scores in question.
  for (T, S, expected) in ((Float64, Diagonal([1e9, 1.4]), 0.4 / 1.4), (Float32, Diagonal(Float32[1e5, 1.5]), 1 / 3))
    S, Λ = Matrix{T}(S), zeros(T, 2, 2)
    Θ = Matrix{T}(Diagonal([inv(S[1, 1]), one(T)]))
    r, _ = solve_from(Θ, S, 0.0, Λ, ProximalOptions(time_limit = 0))
    @test abs(rulef(Θ, S, Λ, T).R - expected) <= 1e-6
    @test abs(r.g_residual - expected) <= 1e-6

    o = options(T; maxiter = 200)
    r, Θ = solve_from(Matrix{T}(I, 2, 2), S, 0.0, Λ, o)
    R = rulef(Θ, S, Λ, T).R
    @test abs(r.g_residual - R) <= 1e-6
    @test !r.converged || R <= τof(T, o) * (1 + 4 * eps(T)) + 1e-6
  end
end

@testset "entry scales: formula, floor and overflow" begin
  # S = [a₁ x; x a₂], Θ = diag(1/a₁, 1/a₂) and λ0 = 0: the diagonal gradients vanish and the only violation
  # is |x| at the zero entry (1, 2), scaled by d₁₂ = max(1, sqrt(a₁) sqrt(a₂)).
  for T in (Float64, Float32)
    for (a, x, d) in (((4, 9), 0.6, 6), ((0.25, 0.25), 0.1, 1), ((4, 16), 0.8, 8))
      S = T[a[1] x; x a[2]]
      Θ = Matrix{T}(Diagonal(inv.(T.(collect(a)))))
      r, _ = solve_from(Θ, S, 0.0, zeros(T, 2, 2), ProximalOptions(time_limit = 0))
      @test abs(r.g_residual - Float64(T(x)) / d) <= 16 * Float64(eps(T))
    end
    # each root is taken before the product, so two large scales do not overflow: s₁s₂ = 1e300 (Float64) or
    # 1e38 (Float32) with a₁a₂ beyond floatmax
    big_a = T === Float64 ? 1e300 : 1f38
    S = Matrix{T}(Diagonal(fill(T(big_a), 2)))
    Θ = Matrix{T}(Diagonal(fill(2 / T(big_a), 2)))
    @test !isfinite(S[1, 1] * S[2, 2])
    r, _ = solve_from(Θ, S, 0.0, zeros(T, 2, 2), ProximalOptions(time_limit = 0))
    @test abs(r.g_residual - 0.5) <= 16 * Float64(eps(T))
    # tiny scales give the unit floor, also for subnormal data: R is the absolute violation
    S = Matrix{T}(Diagonal(fill(nextfloat(zero(T)), 2)))
    Θ = Matrix{T}(Diagonal(fill(one(T), 2)))
    r, _ = solve_from(Θ, S, 0.0, zeros(T, 2, 2), ProximalOptions(time_limit = 0))
    @test r.g_residual == 1
  end
end

@testset "the trigger of the cancellation path" begin
  # |Sᵢⱼ| > 2 max(1, sᵢsⱼ): with a = (4, 4) the scale is 4 and the threshold 8, a strict inequality.
  for T in (Float64, Float32)
    s = T[2, 2]
    @test !PS._logdet_pgd_cancellation(T[4 8; 8 4], s)
    @test PS._logdet_pgd_cancellation(T[4 nextfloat(T(8)); nextfloat(T(8)) 4], s)
    @test PS._logdet_pgd_cancellation(T[4 -nextfloat(T(8)); -nextfloat(T(8)) 4], s)
    @test !PS._logdet_pgd_cancellation(T[4 0; 0 4], s)
    @test !PS._logdet_pgd_cancellation(T[4 -8; -8 4], s)
    # the unit floor applies to small scales
    @test !PS._logdet_pgd_cancellation(T[0.25 2; 2 0.25], T[0.5, 0.5])
    @test PS._logdet_pgd_cancellation(T[0.25 nextfloat(T(2)); nextfloat(T(2)) 0.25], T[0.5, 0.5])
    # a sample covariance, which is positive semidefinite, does not set it in these draws
    for seed in 1:20, p in (2, 5, 12)
      X = randn(Xoshiro(seed), 3, p)                       # fewer rows than columns: rank deficient
      S = Matrix{T}(Symmetric(X' * X ./ 3))
      @test !PS._logdet_pgd_cancellation(S, T[sqrt(abs(S[i, i])) for i in 1:p])
    end
  end
end

# ---------------------------------------------------------------------------------------------------------
# Seeded problems
# ---------------------------------------------------------------------------------------------------------
wishart(::Type{T}, p, seed, n = 4p) where T = (X = randn(Xoshiro(seed), n, p); Matrix{T}(Symmetric(X' * X / n)))

# structural zeros: a few pairs with the weight 1e6, the others 0.1
function structural(T, p, seed)
  pairs = [(i, j) for j in 1:p for i in 1:j-1]
  heavy = Set(pairs[randperm(Xoshiro(seed), length(pairs))[1:max(2, p ÷ 3)]])
  offdiagonal(T, p, (i, j) -> (i, j) in heavy ? 1e6 : 0.1)
end

# two independent blocks, so the inverse of S + I/2 has exact zeros across them and the adaptive
# weights min(cap, 0.05 / |θ̃ᵢⱼ|) equal the cap there
function adaptive(T, p, seed, cap)
  p1 = p ÷ 2
  S1, S2 = wishart(T, p1, seed), wishart(T, p - p1, seed + 1)
  S = [S1 zeros(T, p1, p - p1); zeros(T, p - p1, p1) S2]
  θ = inv(Symmetric(S + T(0.5) * I))
  S, offdiagonal(T, p, (i, j) -> min(cap, 0.05 / abs(θ[i, j])))
end

@testset "heterogeneous penalties: a converged solve meets the entrywise rule" begin
  for T in (Float32, Float64)
    o = options(T)
    solves, converged = 0, 0
    for p in (5, 8, 10), seed in 1:3
      problems = [(wishart(T, p, 1000seed + p), structural(T, p, 31seed + p))]
      for cap in (1e4, 1e6)
        push!(problems, adaptive(T, p, 1000seed + p, cap))
      end
      for (S, Λ) in problems
        r, Θ = solve_from(Matrix{T}(I, p, p), S, 1.0, Λ, o)
        check_result(r, Θ, S, 1.0, Λ, T, o)
        solves += 1
        converged += r.converged
        if r.converged
          @test Θ == Θ' && issuccess(cholesky(Symmetric(Θ); check = false))
          @test r.g_residual <= r.g_tol && !r.stagnated
        end
      end
    end
    # a share of these problems reaches the stop (11 of 27 in Float32 and 13 to 15 in Float64 where it
    # was measured), so the bound above is tested at converged points
    @test converged >= 6
  end
end

@testset "ordinary problems: convergence, the bound and the reported residual" begin
  for T in (Float32, Float64)
    o = options(T)
    for (p, n, level) in ((6, 120, 0.15), (10, 150, 0.12), (10, 150, 0.4))
      S = T.(wishart(Float64, p, 7p, n))
      mult = 0.5 .+ 1.5 .* rand(Xoshiro(3p), p, p)
      for Λ in (ones0(T, p), offdiagonal(T, p, (i, j) -> (mult[i, j] + mult[j, i]) / 2))
        r, Θ = solve_from(Matrix{T}(I, p, p), S, T(level), Λ, o)
        check_result(r, Θ, S, T(level), Λ, T, o)
        @test r.converged && !r.stagnated
      end
    end
    # no penalty: the optimum is inv(S), and the start of a nearby point scores its own residual
    S = T[2 0.5 0; 0.5 1 0.125; 0 0.125 1.25]
    Θ0 = Matrix{T}(I, 3, 3)
    r, Θ = solve_from(Θ0, S, 0.0, zeros(T, 3, 3), o)
    check_result(r, Θ, S, 0.0, zeros(T, 3, 3), T, o)
    @test r.converged && maximum(abs, big.(Θ) - inv(big.(S))) <= target(T)
  end
end

@testset "a power-of-two rescaling of S, Λ and Θ scores alike where the unit floor does not apply" begin
  # S → DSD, Λ → DΛD and Θ → D⁻¹ΘD⁻¹ with D = diag(2ᵏ), k ≥ 0, map the stored problem and the point to an
  # equivalent pair. Cholesky and the inverse commute with a power-of-two scaling unless something under-
  # or overflows, so the gradient becomes DGD and a violation rᵢⱼ becomes DᵢDⱼrᵢⱼ. The scale max(1, sᵢsⱼ)
  # becomes DᵢDⱼ sᵢsⱼ when every Sᵢᵢ ≥ 1 (then sᵢsⱼ ≥ 1 and DᵢDⱼsᵢsⱼ ≥ 1), and R is unchanged. The unit
  # floor is absolute, so R is not invariant where it applies. The shift S → S + Diagonal(C) with a diagonal
  # weight belongs to the integration of PR #483, which lifts the zero-diagonal requirement of PGD-06;
  # here the diagonal weights are zero.
  for T in (Float64, Float32)
    for p in (4, 7), seed in 1:3
      X = randn(Xoshiro(seed + 10p), 3p, p)
      S = T.(X' * X / (3p)) + 2I
      S = Matrix{T}(Symmetric(S))
      Λ = offdiagonal(T, p, (i, j) -> 0.05 * (i + j))
      Θ = Matrix{T}(Symmetric(inv(Symmetric(S + 0.3I)) .* T.(1 .+ 0.01 .* sin.((1:p) .+ (1:p)'))))
      Θ = (Θ + Θ') / 2
      k = [mod(i * seed, 4) for i in 1:p]
      D = Diagonal(T.(2.0 .^ k))
      S2, Λ2, Θ2 = Matrix{T}(D * S * D), Matrix{T}(D * Λ * D), Matrix{T}(inv(D) * Θ * inv(D))
      @test issymmetric(S2) && issymmetric(Λ2) && issymmetric(Θ2)
      for λ0 in T.((1.0, 0.5))
        r, _ = solve_from(Θ, S, λ0, Λ, ProximalOptions(time_limit = 0))
        r2, _ = solve_from(Θ2, S2, λ0, Λ2, ProximalOptions(time_limit = 0))
        @test abs(r.g_residual - r2.g_residual) <= 16 * Float64(eps(T)) * max(1, r.g_residual)
        b = check_result(r, Θ, S, λ0, Λ, T, options(T))
        b2 = check_result(r2, Θ2, S2, λ0, Λ2, T, options(T))
        @test abs(b.R - b2.R) <= 4 * Float64(eps()) * b.R
      end
    end
  end
end

# ---------------------------------------------------------------------------------------------------------
@testset "the 2^51 numerator: S - W rounds a decisive residual to zero" begin
  # Sᵢᵢ = -B, Cᵢᵢ = B + 1, Θᵢᵢ = 1.25 with B = 2^51 (Float64) or 2^22 (Float32): (S - W) + C is 0 for the
  # computed W = inv(Θ), while (S + C) - W = 1 - W is about 0.2. PGD-06 requires zero diagonal weights, so the
  # solver does not reach this input on this revision; the helper is called directly with the flag set.
  for (T, B) in ((Float64, 2.0^51), (Float32, 2f0^22))
    S, C, Θ = fill(-B, 1, 1), fill(B + 1, 1, 1), fill(T(1.25), 1, 1)
    W = inv(Θ)
    G = S .- W
    scales = T[sqrt(abs(S[1] + C[1]))]
    exact = big256(() -> Float64((big(S[1]) + big(C[1])) - 1 / big(Θ[1])))
    @test scales == [1] && 0.19 < exact < 0.21
    @test G[1] + C[1] == 0
    @test PS._logdet_pgd_kkt(Θ, G, C, scales) == 0                       # the gradient form
    @test abs(PS._logdet_pgd_kkt(Θ, S, W, G, C, scales) - exact) <= 4 * Float64(eps(T))
    # from the factor in the scratch matrix, which the call overwrites by inv(Θ)
    scratch = copy(Θ)
    @test issuccess(cholesky!(Symmetric(scratch); check = false))
    @test abs(PS._logdet_pgd_kkt!(scratch, Θ, S, G, C, scales, true) - exact) <= 8 * Float64(eps(T))
    scratch = copy(Θ)
    cholesky!(Symmetric(scratch))
    @test PS._logdet_pgd_kkt!(scratch, Θ, S, G, C, scales, false) == 0   # not flagged: the gradient form
    @test scratch == cholesky(Symmetric(Θ)).U                           # and the factor is left alone
  end
end

@testset "a zero entry whose inverse entry is not zero" begin
  # Θ = tridiagonal(-1, 2, -1) has Θ₁₃ = 0 and (Θ⁻¹)₁₃ = 1/4. S has S₁₃ = B = 3·2^50 (Float64) or 3·2^21
  # (Float32) with C₁₃ = B - 3/2 and every other weight zero, and the other entries of S are those of Θ⁻¹. The
  # violation at the zero entry is (S₁₃ - C₁₃) - W₁₃ = 3/2 - 1/4 = 5/4. The numbers near B are spaced by 1/2
  # and B - 1/4 is a tie, so the gradient form scores the entry as 3/2 or 1, as |G₁₃| - C₁₃ = (B or B - 1/2) - C₁₃.
  for (T, B) in ((Float64, 3 * 2.0^50), (Float32, 3 * 2f0^21))
    Θ = T[2 -1 0; -1 2 -1; 0 -1 2]
    W = T[3 2 1; 2 4 2; 1 2 3] ./ 4
    S = copy(W)
    S[1, 3] = S[3, 1] = B
    Λ = zeros(T, 3, 3)
    Λ[1, 3] = Λ[3, 1] = 1
    λ0 = Float64(B - 3 // 2)
    @test T(λ0) == B - T(3) / 2
    c = T(λ0) .* Λ
    b = rulef(Θ, S, c, T; inputs = true)
    s = T[sqrt(W[1, 1]), sqrt(W[2, 2]), sqrt(W[3, 3])]
    @test PS._logdet_pgd_cancellation(S, s)
    @test abs(b.R - 5 / 4) <= 1e-5
    r, _ = solve_from(Θ, S, λ0, Λ, ProximalOptions(time_limit = 0))
    @test abs(r.g_residual - 5 / 4) <= 1e-5
    G = S .- inv(cholesky(Symmetric(Θ)))
    # the gradient form scores the entry as 1 or 3/2, not 5/4
    @test PS._logdet_pgd_kkt(Θ, G, c, s) in (1, 3 / 2)
  end
end

@testset "an off-diagonal 2^51-type cancellation reached through solve!" begin
  # S₁₂ = 3·2^50 (Float64) or 3·2^21 (Float32), C₁₂ = S₁₂ - 1, S₁₁ = S₂₂ = 2, and Θ the inverse of
  # W = [2 0.875; 0.875 2] (so Θ₁₂ < 0, and Θ is SPD). The numbers near S₁₂ are spaced by 1/2, so the
  # computed S₁₂ - W₁₂ is C₁₂ and the gradient form scores the entry as 0, while the stored data give
  # |(S₁₂ - C₁₂) - W₁₂| = 1/8 and, with the scale s₁s₂ = 2, R = 1/16. This is the matrix analogue of the case above.
  for (T, B) in ((Float64, 3 * 2.0^50), (Float32, 3 * 2f0^21))
    S, Λ = T[2 B; B 2], ones0(T, 2)
    λ0 = Float64(B - 1)
    c = T(λ0) .* Λ
    Θ = T.(big256(() -> inv2(big(2), big(7) / 8)))
    @test Θ[1, 2] < 0 && issuccess(cholesky(Symmetric(Θ); check = false)) && c[1, 2] == B - 1
    @test PS._logdet_pgd_cancellation(S, T[sqrt(2), sqrt(2)])
    G = S .- inv(cholesky(Symmetric(Θ)))
    @test abs(G[1, 2] - c[1, 2]) == 0                                      # the gradient form: 0
    b = rulef(Θ, S, c, T; inputs = true)
    @test abs(b.R - 1 / 16) <= 1e-5
    r, _ = solve_from(Θ, S, λ0, Λ, ProximalOptions(time_limit = 0))
    @test abs(r.g_residual - b.R) <= b.e
    @test abs(r.g_residual - 1 / 16) <= 1e-5
    # a solve from here does not stop at the gradient form's zero residual
    o = options(T; maxiter = 200)
    r, Θ1 = solve_from(Θ, S, λ0, Λ, o)
    check_result(r, Θ1, S, λ0, Λ, T, o; inputs = true)
  end
end

kkt_allocations(args...) = @allocated PS._logdet_pgd_kkt!(args...)

@testset "the KKT evaluation allocates no memory that grows with the dimension" begin
  # The evaluation after the factorization, which the solver's trial has done into the scratch matrix. A warmed
  # call allocates nothing on Julia 1.13; on Julia 1.10 a call that returns a Float64 reports 16 bytes (the
  # evaluation before #492 did as well), which does not depend on the dimension.
  for T in (Float64, Float32), flagged in (false, true)
    bytes = map((12, 36)) do p
      S = wishart(T, p, 5)
      Λ, Θ = ones0(T, p) .* T(0.1), Matrix{T}(I, p, p)
      G = S .- inv(Θ)
      scales = T[sqrt(abs(S[i, i])) for i in 1:p]
      scratch = similar(Θ)
      measured = 0
      for _ in 1:2
        copyto!(scratch, Θ)
        cholesky!(Symmetric(scratch))
        measured = kkt_allocations(scratch, Θ, S, G, Λ, scales, flagged)
      end
      measured
    end
    @test bytes[1] == bytes[2] && bytes[1] <= 16
  end
end

end
