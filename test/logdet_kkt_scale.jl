module LogDetKKTScale
# Entrywise KKT scales of matrix PGD for the graphical lasso (#492, PGD-08). At a committed point
# the solver divides the violation rᵢⱼ of entry (i, j) by max(1, sᵢsⱼ), sᵢ = sqrt(|Sᵢᵢ + Cᵢᵢ|), and
# reports R = maxᵢⱼ rᵢⱼ / max(1, sᵢsⱼ). Before #492 it divided every entry by the single scale
# max(1, maximum(abs, S), maximum(C)), so one large entry of S or C loosened the stop of every
# other entry. It forms the violations from G = S - inv(Θ) and tests each entry for an uncertain
# rounding of that form (mᵢⱼ = |Sᵢⱼ| + |Gᵢⱼ| + c̃ᵢⱼ > 4dᵢⱼ). If one is uncertain it rebuilds W = inv(Θ)
# from the Cholesky factor and evaluates every violation from the inputs and W by error-free sums,
# because S - inv(Θ) can round a decisive residual away.
#
# References computed here in BigFloat (256 bits unless a test needs more) from the stored data and the
# returned matrices, without ProximalBase's gradient or the solver's helpers (the helpers are called
# only as the objects under test): the inverse, every violation, the scales, R, and a first-order
# estimate of the rounding of the computed score (`rulef`; it compares in Float64). The tests use
# analytic values where an optimum or a fixed point is known (the 2 × 2 fixtures, the 1 × 1 cases, the
# two blockers of the review, the rescaling), direct assertions on the helpers (the uncertainty
# test, the evaluation of one entry), and BigFloat scores at returned points. Fixed points check the
# reported `g_residual` against the definition. Each solve below that reports converged = true is
# checked against R ≤ max(gradtol, 64eps(T)) plus the estimate.
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
# c = T(λ0) Λ of PGD-06. The allowance estimates the rounding of the computed R in working precision with
# the unit roundoff u: a first-order estimate with slack, not a bound for the BLAS kernel in use. The
# inverse from the Cholesky factor has an error of about (p + 4) u κ₁(Θ) ‖Θ⁻¹‖₁ in each entry. The form from
# G = S - W adds u(|Sᵢⱼ| + |Wᵢⱼ|); the form from the inputs adds about 4u rᵢⱼ. Which form the solver uses
# is decided here, as in PGD-08, from the exact gradient: the inputs form if some entry has
# |Sᵢⱼ| + |gᵢⱼ| + c̃ᵢⱼ > 4dᵢⱼ. `inputs` forces the choice. Each entry is divided by its scale, as in R.
# The values are rounded to Float64.
# ---------------------------------------------------------------------------------------------------------
function rulef(Θ, S, c, ::Type{T}; inputs = nothing, bits = 256) where T
  setprecision(BigFloat, bits) do
    p = size(Θ, 1)
    X, A, C = big.(Θ), big.(S), big.(c)
    W = inv(cholesky(Symmetric(X)))
    s = [sqrt(abs(A[i, i] + C[i, i])) for i in 1:p]
    u = big(eps(T)) / 2
    Wnorm = opnorm(W, 1)
    κ = opnorm(X, 1) * Wnorm
    d(i, j) = max(big(1), s[i] * s[j])
    violation(i, j) = (g = A[i, j] - W[i, j];
                       iszero(X[i, j]) ? max(abs(g) - C[i, j], big(0)) : abs(g + sign(X[i, j]) * C[i, j]))
    uncertain = any(Iterators.product(1:p, 1:p)) do (i, j)
      g = A[i, j] - W[i, j]
      ct = (!iszero(X[i, j]) || 2abs(g) >= C[i, j]) ? C[i, j] : big(0)
      abs(A[i, j]) + abs(g) + ct > 4d(i, j)
    end
    compensated = inputs === nothing ? uncertain : inputs
    R, e = big(0), big(0)
    for j in 1:p, i in 1:p
      r = violation(i, j)
      rounding = (p + 4) * u * κ * Wnorm + (compensated ? 4u * r : u * (abs(A[i, j]) + abs(W[i, j])))
      R, e = max(R, r / d(i, j)), max(e, rounding / d(i, j))
    end
    (R = Float64(R), e = Float64(e), uncertain)
  end
end

# The reported residual is the definition, up to the allowance; a converged solve meets the stop rule of
# PGD-08 recomputed here. Returns the BigFloat score and its allowance.
function check_result(r, Θ, S, λ0, Λ, ::Type{T}, o; inputs = nothing, bits = 256) where T
  b = rulef(Θ, S, T(λ0) .* Λ, T; inputs, bits)
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
  # 26% from the optimum. Here the zero entry has |G₁₂| ≥ C₁₂/2 and mᵢⱼ far above 4 max(1, s₁s₂) = 4, so the
  # violations are formed from the inputs and W = inv(Θ).
  for (T, S12, λ0, δ) in ((Float64, 1e9, 1e9 - 0.4, 4e-8), (Float32, 2f0^16, Float64(Float32(65536 - 0.375)), 1e-3))
    S, Λ = T[1 S12; S12 1], ones0(T, 2)
    c = T(λ0) .* Λ
    e = big(S[1, 2]) - big(c[1, 2])                  # the stored S₁₂ - C₁₂, exact
    point(x) = T.(big256(() -> inv2(big(1), big(x))))
    # At Θ = I the diagonal violations vanish and the zero entry has violation S₁₂ - C₁₂ = e, so R = e.
    Θ = Matrix{T}(I, 2, 2)
    r, _ = solve_from(Θ, S, λ0, Λ, ProximalOptions(time_limit = 0))
    b = check_result(r, Θ, S, λ0, Λ, T, options(T))
    @test b.uncertain && PS._logdet_pgd_gform(Θ, S, S .- inv(Θ), c, T[1, 1])[2]
    @test abs(b.R - Float64(e)) <= 1e-12 && abs(r.g_residual - Float64(e)) <= 4 * Float64(eps(T))
    # At the optimum W₁₂ = e. At W₁₂ = e + δ the spacing of the numbers near S₁₂ is more than 2δ, so the
    # computed S₁₂ - W₁₂ is C₁₂ and the gradient form scores the entry as 0, while its violation is δ.
    for offset in (0, δ)
      Θ = point(e + offset)
      @test Θ[1, 2] < 0
      r, _ = solve_from(Θ, S, λ0, Λ, ProximalOptions(time_limit = 0))
      b = check_result(r, Θ, S, λ0, Λ, T, options(T))
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
    check_result(r, Θ, S, λ0, Λ, T, o)
    o = options(T; maxiter = 2)
    r, Θ = solve_from(Matrix{T}(2I, 2, 2), S, λ0, Λ, o)
    b = check_result(r, Θ, S, λ0, Λ, T, o)
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

@testset "the uncertainty test of the pass from G" begin
  # mᵢⱼ = |Sᵢⱼ| + |Gᵢⱼ| + c̃ᵢⱼ against 4dᵢⱼ, with c̃ᵢⱼ = Cᵢⱼ at a nonzero Θᵢⱼ or at a zero with |Gᵢⱼ| ≥ Cᵢⱼ/2, else 0.
  # The helper is called with chosen matrices; the scales are those of S + C (here 1, so dᵢⱼ = 1 or the unit floor).
  gform(Θ, S, G, C, s) = PS._logdet_pgd_gform(Θ, S, G, C, s)
  for T in (Float64, Float32)
    I1 = Matrix{T}(I, 1, 1)
    # a nonzero entry: m = 2 + |g| + 1 against 4, a strict inequality
    @test !gform(I1, fill(T(2), 1, 1), fill(T(1), 1, 1), fill(T(1), 1, 1), T[1])[2]
    @test gform(I1, fill(T(2), 1, 1), fill(T(1.0625), 1, 1), fill(T(1), 1, 1), T[1])[2]
    @test gform(I1, fill(T(2), 1, 1), fill(-T(1.0625), 1, 1), fill(T(1), 1, 1), T[1])[2]
    # the same m with the unit floor of a scale below one
    @test gform(I1, fill(T(2), 1, 1), fill(T(1.0625), 1, 1), fill(T(1), 1, 1), T[0.5])[2]
    # a larger scale raises the threshold: s = 2 gives d = 4 and the threshold 16
    @test !gform(I1, fill(T(8), 1, 1), fill(T(4), 1, 1), fill(T(3), 1, 1), T[2])[2]
    @test gform(I1, fill(T(8), 1, 1), fill(T(6), 1, 1), fill(T(3), 1, 1), T[2])[2]
    # a zero entry: |G₁₂| < C₁₂/2 gives c̃ = 0 and m = 2.9, while |G₁₂| = C₁₂/2 gives c̃ = C₁₂ and m = 9
    Θ0 = T[1 0; 0 1]
    S0 = T[1 0; 0 1]
    C0 = T[0 6; 6 0]
    @test !gform(Θ0, S0, T[0 2.9; 2.9 0], C0, T[1, 1])[2]
    @test gform(Θ0, S0, T[0 3; 3 0], C0, T[1, 1])[2]
    # an entry whose m overflows is uncertain, also where 4dᵢⱼ would overflow
    big_s = T[sqrt(floatmax(T)), sqrt(floatmax(T))]
    @test gform(Θ0, T[1 floatmax(T); floatmax(T) 1], T[0 floatmax(T); floatmax(T) 0], T[0 1; 1 0], big_s)[2]
    # ordinary problems are certain: a positive semidefinite S, zero weights and Θ = I, so Θᵢⱼ = 0 and
    # |Sᵢⱼ| ≤ sᵢsⱼ; a positive-definite S with moderate weights at its optimum; a positive diagonal weight
    for seed in 1:20, p in (2, 5, 12)
      X = randn(Xoshiro(seed), 3, p)                       # fewer rows than columns: rank deficient
      S = Matrix{T}(Symmetric(X' * X ./ 3))
      s = T[sqrt(abs(S[i, i])) for i in 1:p]
      Θ = Matrix{T}(I, p, p)
      @test !gform(Θ, S, S .- Θ, zeros(T, p, p), s)[2]
    end
    S = T[1 0.1; 0.1 1]
    Θ = T[1 0; 0 1] .* T(0.9)
    @test !gform(Θ, S, S .- inv(Θ), T[0 0.5; 0.5 0], T[1, 1])[2]            # Θ₁₂ = 0, |G₁₂| = 0.1 < 0.25
    @test !gform(Θ, T[1 0; 0 1], T[-2 0; 0 -2], T[2 0; 0 2], T[sqrt(3), sqrt(3)])[2]   # Sᵢᵢ = 1, Cᵢᵢ = 2, Gᵢᵢ = -2
    # a diagonal weight that cancels a negative Sᵢᵢ is uncertain
    @test gform(I1, fill(-T(2)^16, 1, 1), fill(-T(2)^16 - 1, 1, 1), fill(T(2)^16 + 1, 1, 1), T[1])[2]
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
    # no penalty, positive-definite S: the returned point is checked against the optimum inv(S) and its score
    S = T[2 0.5 0; 0.5 1 0.125; 0 0.125 1.25]
    Θ0 = Matrix{T}(I, 3, 3)
    r, Θ = solve_from(Θ0, S, 0.0, zeros(T, 3, 3), o)
    check_result(r, Θ, S, 0.0, zeros(T, 3, 3), T, o)
    @test r.converged && maximum(abs, big.(Θ) - inv(big.(S))) <= target(T)
  end
end

@testset "a power-of-two rescaling of S, Λ and Θ scores alike on these fixtures, where the unit floor does not apply" begin
  # S → DSD, Λ → DΛD and Θ → D⁻¹ΘD⁻¹ with D = diag(2ᵏ), k ≥ 0, map the stored problem and the point to an
  # equivalent pair. Cholesky and the inverse commute with a power-of-two scaling unless something under-
  # or overflows, so the gradient becomes DGD and a violation rᵢⱼ becomes DᵢDⱼrᵢⱼ. The scale max(1, sᵢsⱼ)
  # becomes DᵢDⱼ sᵢsⱼ when every Sᵢᵢ ≥ 1 (then sᵢsⱼ ≥ 1 and DᵢDⱼsᵢsⱼ ≥ 1), and R is unchanged. The test
  # observes this agreement on its seeded fixtures; it does not prove it. The unit
  # floor is absolute, so R is not invariant where it applies. The weights here have a zero diagonal; the
  # shift S → S + Diagonal(C) of positive diagonal weights is tested in its own testset below.
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
  # Sᵢᵢ = -B, Cᵢᵢ = B + 1, Θᵢᵢ = 1.25 with B = 2^51 (Float64) or 2^22 (Float32, an analogue): (S - W) + C is 0
  # for the computed W = inv(Θ), while (S + C) - W = 1 - W is about 0.2. The solver reaches this input through a
  # positive diagonal weight (a later testset runs it through solve!); here the helpers are called directly, which
  # also exercises the evaluation from the factor in the scratch matrix.
  for (T, B) in ((Float64, 2.0^51), (Float32, 2f0^22))
    S, C, Θ = fill(-B, 1, 1), fill(B + 1, 1, 1), fill(T(1.25), 1, 1)
    W = inv(Θ)
    G = S .- W
    scales = T[sqrt(abs(S[1] + C[1]))]
    exact = big256(() -> Float64((big(S[1]) + big(C[1])) - 1 / big(Θ[1])))
    @test scales == [1] && 0.19 < exact < 0.21
    @test G[1] + C[1] == 0
    worst, uncertain = PS._logdet_pgd_gform(Θ, S, G, C, scales)
    @test worst == 0 && uncertain                                        # the form from G, and its flag
    @test abs(PS._logdet_pgd_wform(Θ, S, W, G, C, scales) - exact) <= 4 * Float64(eps(T))
    # from the factor in the scratch matrix, which the call overwrites by inv(Θ)
    scratch = copy(Θ)
    @test issuccess(cholesky!(Symmetric(scratch); check = false))
    @test abs(PS._logdet_pgd_kkt!(scratch, Θ, S, G, C, scales) - exact) <= 8 * Float64(eps(T))
    @test abs(scratch[1] - W[1]) <= 2 * eps(T)
    # a certain point leaves the factor alone
    S2, G2, C2 = fill(T(1.5), 1, 1), fill(T(1.5) - W[1], 1, 1), fill(T(0.25), 1, 1)
    scales2 = T[sqrt(T(1.75))]
    @test !PS._logdet_pgd_gform(Θ, S2, G2, C2, scales2)[2]
    scratch = copy(Θ)
    cholesky!(Symmetric(scratch))
    @test PS._logdet_pgd_kkt!(scratch, Θ, S2, G2, C2, scales2) == PS._logdet_pgd_gform(Θ, S2, G2, C2, scales2)[1]
    @test scratch == cholesky(Symmetric(Θ)).U
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
    b = rulef(Θ, S, c, T)
    s = T[sqrt(W[1, 1]), sqrt(W[2, 2]), sqrt(W[3, 3])]
    @test abs(b.R - 5 / 4) <= 1e-5
    r, _ = solve_from(Θ, S, λ0, Λ, ProximalOptions(time_limit = 0))
    @test abs(r.g_residual - 5 / 4) <= 1e-5
    G = S .- inv(cholesky(Symmetric(Θ)))
    # the form from G scores the entry as 1 or 3/2, not 5/4, and flags it
    worst, uncertain = PS._logdet_pgd_gform(Θ, S, G, c, s)
    @test worst in (1, 3 / 2) && uncertain
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
    G = S .- inv(cholesky(Symmetric(Θ)))
    @test abs(G[1, 2] - c[1, 2]) == 0                                      # the form from G: 0
    @test PS._logdet_pgd_gform(Θ, S, G, c, T[sqrt(2), sqrt(2)])[2]
    b = rulef(Θ, S, c, T)
    @test abs(b.R - 1 / 16) <= 1e-5
    r, _ = solve_from(Θ, S, λ0, Λ, ProximalOptions(time_limit = 0))
    @test abs(r.g_residual - b.R) <= b.e
    @test abs(r.g_residual - 1 / 16) <= 1e-5
    # a solve from here does not stop at the gradient form's zero residual
    o = options(T; maxiter = 200)
    r, Θ1 = solve_from(Θ, S, λ0, Λ, o)
    check_result(r, Θ1, S, λ0, Λ, T, o)
  end
end

# ---------------------------------------------------------------------------------------------------------
# Positive diagonal weights (PGD-06 permits them): the cases of #492 that the diagonal weight makes reachable
# ---------------------------------------------------------------------------------------------------------
@testset "a positive diagonal weight that cancels a negative Sᵢᵢ: the table of #492" begin
  # 1 × 1 with S = -(C - 1) and C = λ0 · 1, so S + C = 1, the scale is max(1, sqrt(1)²) = 1 and the optimum is
  # θ = 1. At θ = 1.5 the violation is |S + C - 1/θ| = 1/3, so R = 1/3; before #492 the scale max(1, |S|, C) was
  # about C and the same point scored (1/3)/C. |S| exceeds 2 max(1, 1), so the input form is used. From θ = 2
  # (maxiter 100, ftol = 0) the old rule converged at θ = 1.5, 1 + 3.1e-7, 1.5 and 1.024 in these four cases. On
  # Julia 1.13.4 the solves now converge in 4 to 6 iterations, at θ within 1.2e-13 of 1.
  for (T, s, c) in ((Float64, -2.0^32, 2.0^32 + 1), (Float64, -1000.0, 1001.0),
                    (Float32, -2f0^16, 2f0^16 + 1), (Float32, -4096f0, 4097f0))
    S, Λ, λ0 = fill(T(s), 1, 1), ones(T, 1, 1), Float64(c)
    @test T(λ0) == c && S[1] + T(λ0) == 1
    Θ = fill(T(1.5), 1, 1)
    r, _ = solve_from(Θ, S, λ0, Λ, ProximalOptions(time_limit = 0))
    b = check_result(r, Θ, S, λ0, Λ, T, options(T))
    @test b.uncertain && PS._logdet_pgd_gform(Θ, S, S .- inv(Θ), T(λ0) .* Λ, T[1])[2]
    @test abs(b.R - 1 / 3) <= 1e-15 && abs(r.g_residual - 1 / 3) <= b.e
    o = ProximalOptions(maxiter = 100, gradtol = gradtol(T), ftol = 0)
    r, Θ = solve_from(fill(T(2), 1, 1), S, λ0, Λ, o)
    check_result(r, Θ, S, λ0, Λ, T, o)
    # a = 1, so R is the distance of 1/θ from 1: a converged solve is within the stop tolerance of θ = 1
    @test !r.converged || abs(Θ[1] - 1) <= 4 * τof(T, o)
  end
end

@testset "the 2^51 diagonal numerator through solve!" begin
  # S = -B, C = B + 1 (B = 2^51 in Float64, 2^22 in Float32), Θ = 1.25: the gradient S - 1/Θ rounds so that
  # G + C = 0, while the stored data give R = |(S + C) - 1/Θ| = 0.2.
  for (T, B) in ((Float64, 2.0^51), (Float32, 2f0^22))
    S, Λ, λ0 = fill(-B, 1, 1), ones(T, 1, 1), Float64(B + 1)
    Θ = fill(T(1.25), 1, 1)
    @test (S .- inv(Θ))[1] + T(λ0) == 0
    r, _ = solve_from(Θ, S, λ0, Λ, ProximalOptions(time_limit = 0))
    b = check_result(r, Θ, S, λ0, Λ, T, options(T))
    @test abs(b.R - 0.2) <= 1e-12 && abs(r.g_residual - 0.2) <= b.e && r.g_residual > 0.19
    # a solve from this point does not stop where the gradient form scores 0
    o = options(T; maxiter = 100)
    r, Θ1 = solve_from(Θ, S, λ0, Λ, o)
    check_result(r, Θ1, S, λ0, Λ, T, o)
    @test !r.converged || abs(Θ1[1] - 1) <= 4 * τof(T, o)
  end
end

@testset "covariance shift: the direct and the shifted formulation agree" begin
  # The direct problem (S, λ0 Λ) with a positive diagonal weight and the shifted problem (S + Diagonal(C), zero
  # diagonal weight) have the same objective in exact arithmetic, and the same entry scales aᵢ = Sᵢᵢ + Cᵢᵢ. The
  # stored problems are equal up to the rounding of Sᵢᵢ + Cᵢᵢ in T, which is exact for the 1 × 1 cases (S + C = 1)
  # and which the 3 × 3 case rounds. At one point the two start scores agree within 8eps(T); each solve is judged
  # against the stored problem it solved, and converged solves end within target(T) of each other.
  problems = Any[]
  for (T, s, c) in ((Float64, -2.0^32, 2.0^32 + 1), (Float64, -1000.0, 1001.0),
                    (Float32, -2f0^16, 2f0^16 + 1), (Float32, -4096f0, 4097f0))
    push!(problems, (T = T, S = fill(T(s), 1, 1), λ0 = Float64(c), Λ = ones(T, 1, 1), Θ = fill(T(1.5), 1, 1)))
  end
  for T in (Float64, Float32)
    p = 3
    X = randn(Xoshiro(11), 12, p)
    S = Matrix{T}(Symmetric(X' * X / 12 + I / 2))
    dw = T[1 / 16, 1 / 8, 3 / 16]
    Λ = T[i == j ? dw[i] : 1 / 10 for i in 1:p, j in 1:p]
    Θ = Matrix{T}(Symmetric(inv(Symmetric(S + Diagonal(dw))) .* T.(1 .+ 0.02 .* sin.((1:p) .+ (1:p)'))))
    push!(problems, (T = T, S = S, λ0 = 1.0, Λ = Λ, Θ = Θ))
  end
  for q in problems
    T, S, λ0, Λ, Θ = q.T, q.S, q.λ0, q.Λ, q.Θ
    p = size(S, 1)
    Sshift, Λshift = copy(S), copy(Λ)
    for i in 1:p
      Sshift[i, i] += T(λ0) * Λ[i, i]
      Λshift[i, i] = 0
    end
    r1, _ = solve_from(Θ, S, λ0, Λ, ProximalOptions(time_limit = 0))
    r2, _ = solve_from(Θ, Sshift, λ0, Λshift, ProximalOptions(time_limit = 0))
    @test abs(r1.g_residual - r2.g_residual) <= 8 * Float64(eps(T))
    check_result(r1, Θ, S, λ0, Λ, T, options(T))
    check_result(r2, Θ, Sshift, λ0, Λshift, T, options(T))
    o = p == 1 ? ProximalOptions(maxiter = 100, gradtol = gradtol(T), ftol = 0) : options(T)
    start = p == 1 ? fill(T(2), 1, 1) : Matrix{T}(I, p, p)
    q1, Θ1 = solve_from(start, S, λ0, Λ, o)
    q2, Θ2 = solve_from(start, Sshift, λ0, Λshift, o)
    check_result(q1, Θ1, S, λ0, Λ, T, o)
    check_result(q2, Θ2, Sshift, λ0, Λshift, T, o)
    q1.converged && q2.converged && @test maximum(abs, Θ1 - Θ2) <= target(T)
    # the 3 × 3 problems are well conditioned and converge
    p > 1 && @test q1.converged && q2.converged
  end
end

# ---------------------------------------------------------------------------------------------------------
# The two inputs on which the first implementation of #492 stopped at a decisive violation (round 1 of its review)
# ---------------------------------------------------------------------------------------------------------
@testset "cancellation of W against C where S is small: the unit floor does not bound |W₁₂|" begin
  # D = diag(2ᵃ, 2⁻ᵇ, 1), M = [1 0 1; 0 1 -1; 1 -1 3] with M⁻¹ = [2 -1 -1; -1 2 1; -1 1 1] (det M = 1), Θ = DMD,
  # S = [2^(-2b-1) 1/4 0; 1/4 2^(2b+1) 2ᵇ; 0 2ᵇ 1], and zero weights except C₁₂ = C₂₁ = B = 2^(b-a). Every entry is
  # a power of two times a small integer, so Θ, S and W = D⁻¹M⁻¹D⁻¹ are exact in T, and the computed inverse is W
  # because the scaling by powers of two commutes with the rounding of the Cholesky inverse. W₁₂ = -B, S₁₂ = 1/4,
  # Θ₁₂ = 0, so the violation of entry (1, 2) is (|S₁₂ - W₁₂| - C₁₂) = 1/4 with d₁₂ = 1; the form from G rounds
  # fl(1/4 + B) - B to 0. The small diagonal S₁₁ passes through the unit floor, so |W₁₂| is not bounded by a multiple of d₁₂
  # (the scales are s₁ = 2^(-b-1/2), s₂ = 2^(b+1/2)). The references are analytic: W is built here from the integers,
  # and BigFloat uses 2048 bits because κ(Θ) is about 2^(2a+2b+...) (the 256-bit default does not resolve Θ⁻¹).
  for (T, a, b) in ((Float32, 30, 58), (Float64, 55, 110))
    pw(k) = ldexp(one(T), k)
    D = Diagonal(T[pw(a), pw(-b), 1])
    M = T[1 0 1; 0 1 -1; 1 -1 3]
    Θ = Matrix{T}(D * M * D)
    S = T[pw(-2b - 1) 1/4 0; 1/4 pw(2b + 1) pw(b); 0 pw(b) 1]
    B = pw(b - a)
    Λ = zeros(T, 3, 3)
    Λ[1, 2] = Λ[2, 1] = B
    @test Θ == Θ' && S == S'
    setprecision(BigFloat, 2048) do
      Dinv = Diagonal(BigFloat[ldexp(big(1.0), -a), ldexp(big(1.0), b), 1])
      W = Dinv * BigFloat[2 -1 -1; -1 2 1; -1 1 1] * Dinv
      @test big.(Θ) * W == I                                # the analytic inverse, exactly
      @test W[1, 2] == -big(B)
      @test issuccess(cholesky(Symmetric(big.(S)); check = false))
    end
    scales = T[sqrt(abs(S[i, i])) for i in 1:3]
    G = S .- inv(cholesky(Symmetric(Θ)))
    @test G[1, 2] == B                                       # the form from G: fl(1/4 + B) = B
    @test PS._logdet_pgd_violation(Θ[1, 2], G[1, 2], Λ[1, 2]) == 0
    @test PS._logdet_pgd_gform(Θ, S, G, Λ, scales)[2]        # and the entry is flagged
    @test PS._logdet_pgd_violation(Θ[1, 2], G[1, 2], Λ[1, 2], S[1, 2], -B) == 1 / 4
    r, _ = solve_from(Θ, S, 1.0, Λ, ProximalOptions(time_limit = 0))
    b2 = rulef(Θ, S, Λ, T; bits = 2048)
    @test abs(b2.R - 1 / 4) <= 1e-12 && abs(r.g_residual - 1 / 4) <= 8 * Float64(eps(T))
    o = options(T; maxiter = 20)
    r, Θ1 = solve_from(Θ, S, 1.0, Λ, o)
    @test !r.converged || rulef(Θ1, S, Λ, T; bits = 2048).R <= τof(T, o) * (1 + 4 * eps(T)) + 64 * Float64(eps(T))
  end
end

@testset "an overflowing unused endpoint does not discard the violation at the other" begin
  # B = 0.75 floatmax(T), σ = ±1, Θ = [2 0 1; 0 2 -σ; 1 -σ 2], and S equal to W = Θ⁻¹ = [3 -σ -2; -σ 3 2σ; -2 2σ 4] / 4
  # except that S₁₂ = σB. With C₁₂ = B and every other weight zero, x = S₁₂ - W₁₂ = σ(B + 1/4) at the zero entry. The
  # side of x - C or -x - C that has the sign of x is (|x| - B) = 1/4, and the opposite side is about -2B, whose
  # TwoSum overflows outward, so that side cannot be violated. The first form from the inputs would add S₁₂ + C₁₂
  # (σ = 1) or S₁₂ - C₁₂ (σ = -1) beyond floatmax and fall back to G, which rounds the violation to 0. The scales are
  # s₁ = s₂ = sqrt(0.75), so d₁₂ = 1 and R = 1/4.
  for T in (Float32, Float64), σ in (1, -1)
    B = T(0.75) * floatmax(T)
    Θ = T[2 0 1; 0 2 -σ; 1 -σ 2]
    S = T[0.75 σ*B -0.5; σ*B 0.75 σ/2; -0.5 σ/2 1]
    Λ = zeros(T, 3, 3)
    Λ[1, 2] = Λ[2, 1] = B
    scales = T[sqrt(abs(S[i, i])) for i in 1:3]
    G = S .- inv(cholesky(Symmetric(Θ)))
    # the endpoint on the side of the sign of S₁₂ overflows: S₁₂ + C₁₂ for σ = 1, S₁₂ - C₁₂ for σ = -1
    @test !isfinite(σ == 1 ? S[1, 2] + Λ[1, 2] : S[1, 2] - Λ[1, 2])
    @test abs(G[1, 2]) == B && PS._logdet_pgd_violation(Θ[1, 2], G[1, 2], Λ[1, 2]) == 0
    @test PS._logdet_pgd_gform(Θ, S, G, Λ, scales)[2]
    @test PS._logdet_pgd_violation(Θ[1, 2], G[1, 2], Λ[1, 2], S[1, 2], T(-σ / 4)) == 1 / 4
    r, _ = solve_from(Θ, S, 1.0, Λ, ProximalOptions(time_limit = 0))
    b2 = rulef(Θ, S, Λ, T; bits = 2048)
    @test abs(b2.R - 1 / 4) <= 1e-12 && abs(r.g_residual - 1 / 4) <= 8 * Float64(eps(T)) && abs(r.g_residual - b2.R) <= b2.e
    o = options(T; maxiter = 50)
    r, Θ1 = solve_from(Θ, S, 1.0, Λ, o)
    @test !r.converged || rulef(Θ1, S, Λ, T; bits = 2048).R <= τof(T, o) * (1 + 4 * eps(T)) + 64 * Float64(eps(T))
  end
end

kkt_allocations(args...) = @allocated PS._logdet_pgd_kkt!(args...)

@testset "the KKT evaluation allocates no memory that grows with the dimension" begin
  # The evaluation after the factorization, which the solver's trial has done into the scratch matrix, with a
  # certain point (the pass from G only) and an uncertain one (a large S₁₂ also rebuilds W and evaluates from the
  # inputs). A warmed call allocates nothing on Julia 1.13; on Julia 1.10 a call that returns a Float64 reports
  # 16 bytes (the evaluation before #492 did as well), which does not depend on the dimension.
  for T in (Float64, Float32), uncertain in (false, true)
    bytes = map((12, 36)) do p
      S = wishart(T, p, 5)
      uncertain && (S[1, 2] = S[2, 1] = T(1000))
      Λ, Θ = ones0(T, p) .* T(0.1), Matrix{T}(I, p, p)
      G = S .- inv(Θ)
      scales = T[sqrt(abs(S[i, i])) for i in 1:p]
      @test PS._logdet_pgd_gform(Θ, S, G, Λ, scales)[2] == uncertain
      scratch = similar(Θ)
      measured = 0
      for _ in 1:2
        copyto!(scratch, Θ)
        cholesky!(Symmetric(scratch))
        measured = kkt_allocations(scratch, Θ, S, G, Λ, scales)
      end
      measured
    end
    @test bytes[1] == bytes[2] && bytes[1] <= 16
  end
end

end
