module CDNonnegativeTests
# IndNonnegative() and unweighted NormL1Nonneg(λ) with CDSolver on a dense Vector (#455): the problem
# (s/2) ‖y - Xb‖² + λ Σ b_j over b ≥ 0 (λ = 0 for the indicator), with the loss LeastSquaresLoss(y, X) (s = 1) or one
# positive Scaled of it, in Float32 and Float64.
#
# The oracle is independent of the solver and of ProximalBase's kkt_violation: `nnkkt` forms, in 256-bit BigFloat
# from X, y, s, λ and the returned point, the gradient s Xᵀ(Xb - y), the constrained KKT score
# max_j (b_j > 0 ? |g_j + λ| : max(0, -(g_j + λ))) relative to s ‖Xᵀy‖∞ + λ, and the objective. The references are
# BigFloat closed forms for designs with a diagonal XᵀX, and, for the general case, cyclic coordinate descent run in
# BigFloat until the score of the oracle is below 1e-40 or 200_000 passes have run (`reference`; `refcheck` asserts the
# score of the returned point). PGD (ProximalGradientDescent) solves the same problems. CD and PGD are compared by
# their external scores and objectives, not by their `converged` flags: for feasible points b1 and b2, with F(b1) >= F(b2)
# and K1 the unnormalized constrained KKT score of b1, convexity gives F(b1) - F(b2) <= K1 ‖b1 - b2‖₁.
#
# All accepted solves use X, y, the start, the loss scale and the penalty level of one type T (Float32 or Float64);
# BigFloat appears in the oracle, the references and the gate refusals of unsupported scalar types.
#
# Tolerances: a score of at most 1e-6 (Float64) or 1e-3 (Float32), and an objective above that of the reference by at
# most 1e-10 (Float64) or 1e-4 (Float32) of the objective at 0. The CD runs use the cyclic order without momentum and the
# tolerance `cdtol(T)` unless a testset says otherwise; the random orders use a seeded Xoshiro, so that runs repeat.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
import Logging
const PS = ProximalSolvers

const FLOATS = (Float64, Float32)
cdtol(::Type{Float64}) = 1e-10
cdtol(::Type{Float32}) = 1e-6
kktbound(::Type{Float64}) = 1e-6
kktbound(::Type{Float32}) = 1e-3
objbound(::Type{Float64}) = 1e-10
objbound(::Type{Float32}) = 1e-4

quiet(f) = Logging.with_logger(f, Logging.NullLogger())
lossof(s, y, X) = s === nothing ? LeastSquaresLoss(y, X) : Scaled(LeastSquaresLoss(y, X), s)
sval(s) = s === nothing ? 1 : s
# the loss scales of the tests: raw, and two scales of the data type
scales(::Type{T}, n) where T = (nothing, one(T) / T(n), T(2))
penalty(kind::Symbol, λ) = kind === :ind ? IndNonnegative() : NormL1Nonneg(λ)
level(kind::Symbol, λ::T) where T = kind === :ind ? zero(T) : λ
is_pzero(v, ::Type{T}) where T = v isa T && iszero(v) && !signbit(v)

# ---------------------------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------------------------
function design(::Type{T}, n, p, seed) where T
  rng = Xoshiro(seed)
  X = randn(rng, T, n, p)
  β = zeros(T, p)
  coef = T[2.0, -1.5, 1.0, 0.5, -1.0]
  β[1:min(p, 5)] .= coef[1:min(p, 5)]
  y = X * β + T(0.3) * randn(rng, T, n)
  X, y
end

# columns generated with the pairwise correlation ρ (the sample correlations vary around it)
function correlated(::Type{T}, n, p, seed; ρ = 0.6) where T
  rng = Xoshiro(seed)
  common = randn(rng, T, n)
  X = T(sqrt(ρ)) .* common .+ T(sqrt(1 - ρ)) .* randn(rng, T, n, p)
  β = zeros(T, p)
  β[1:4] .= T[2.0, -1.5, 1.0, -0.5]
  y = X * β + T(0.3) * randn(rng, T, n)
  X, y
end

# disjoint column supports, so that XᵀX is diagonal in floating point; the response gives the unconstrained
# least-squares coordinates t (rows 2j-1 and 2j are X[i, j] t_j), of which some are negative
function orthogonal(::Type{T}, seed) where T
  rng = Xoshiro(seed)
  X = zeros(T, 8, 4)
  for j in 1:4, i in (2j - 1, 2j)
    X[i, j] = T(1 + rand(rng)) * (rand(rng) < 0.5 ? -1 : 1)
  end
  t = T[2.0, -1.5, 0.4, 0.05]
  y = zeros(T, 8)
  for j in 1:4, i in (2j - 1, 2j)
    y[i] = X[i, j] * t[j]
  end
  X, y, t
end

# a square diagonal design with different column scales, and the response d_j t_j
function diagonal(::Type{T}, seed) where T
  rng = Xoshiro(seed)
  d = [T(0.5 + 3.5 * rand(rng)) * (rand(rng) < 0.5 ? -1 : 1) for _ in 1:6]
  t = T[2.0, -1.5, 0.3, -0.2, 1.0, 0.05]
  Matrix(Diagonal(d)), d .* t, t
end

# max_j s (Xᵀy)_j as Float64: in exact arithmetic the level at and above which 0 is a minimizer (at a zero level of a
# rank-deficient design, nonzero minimizers can exist too; a level rounded to T
# from a multiple f of it can fall on either side of that boundary at f = 1)
smax(X, y, s) = setprecision(BigFloat, 256) do
  Float64(big(sval(s)) * maximum(big.(X)' * big.(y)))
end
level_at(::Type{T}, X, y, s, f) where T = T(f * smax(X, y, s))

# ---------------------------------------------------------------------------------------------
# Oracle and references (256-bit BigFloat, from the data as stored)
# ---------------------------------------------------------------------------------------------
# the score and the objective, as BigFloat, of the point b for (X, y, s, λ)
function nnkkt(X, y, s, λ, b)
  setprecision(BigFloat, 256) do
    Xb, yb, bb, sb, lb = big.(X), big.(y), big.(b), big(sval(s)), big(λ)
    d = Xb * bb - yb
    g = sb .* (Xb' * d)
    num = maximum(j -> bb[j] > 0 ? abs(g[j] + lb) : max(-(g[j] + lb), zero(BigFloat)), eachindex(bb))
    den = sb * maximum(abs, Xb' * yb) + lb
    (; score = iszero(den) ? num : num / den, viol = num, objective = sb * sum(abs2, d) / 2 + lb * sum(bb))
  end
end

# the minimizer of the problem: cyclic coordinate descent in BigFloat from 0 until the score is below 1e-40
function reference(X, y, s, λ)
  setprecision(BigFloat, 256) do
    Xb, yb, sb, lb = big.(X), big.(y), big(sval(s)), big(λ)
    n, p = size(Xb)
    a = [sum(abs2, view(Xb, :, j)) for j in 1:p]
    b = zeros(BigFloat, p)
    r = copy(yb)
    for pass in 1:200_000
      for j in 1:p
        iszero(a[j]) && continue
        xj = view(Xb, :, j)
        c = b[j] + dot(xj, r) / a[j]
        new = max(c - lb / (sb * a[j]), zero(BigFloat))
        h = new - b[j]
        if !iszero(h)
          r .-= h .* xj
          b[j] = new
        end
      end
      pass % 10 == 0 && nnkkt(Xb, yb, sb, lb, b).score < big"1e-40" && break
    end
    b
  end
end

# the reference, with the check that its own score at return is below 1e-30
function refcheck(X, y, s, λ)
  ref = reference(X, y, s, λ)
  @test nnkkt(X, y, s, λ, ref).score < 1e-30
  ref
end

# the objective difference of two feasible points against the bound K ‖b1 - b2‖₁ of the one with the larger objective,
# K its unnormalized constrained KKT score; the allowance 1e-30 F(0) covers the 256-bit rounding of the diagnostics
function objective_bound_holds(X, y, s, λ, b1, b2)
  k1, k2 = nnkkt(X, y, s, λ, b1), nnkkt(X, y, s, λ, b2)
  hi, lo, khi = k1.objective >= k2.objective ? (b1, b2, k1) : (b2, b1, k2)
  klo = khi === k1 ? k2 : k1
  setprecision(BigFloat, 256) do
    F0 = big(sval(s)) * sum(abs2, big.(y)) / 2
    d = sum(abs, big.(hi) .- big.(lo))
    khi.objective - klo.objective <= khi.viol * d + big"1e-30" * F0
  end
end

# b_j = max((Xᵀy)_j - λ/s, 0) / ‖X_j‖² for a design with a diagonal XᵀX, and the scale |(Xᵀy)_j| / ‖X_j‖² of each
# coordinate
function closed(X, y, s, λ)
  setprecision(BigFloat, 256) do
    Xb, yb, sb, lb = big.(X), big.(y), big(sval(s)), big(λ)
    c = [dot(Xb[:, j], yb) for j in 1:size(X, 2)]
    a = [dot(Xb[:, j], Xb[:, j]) for j in 1:size(X, 2)]
    [max(c[j] - lb / sb, 0) / a[j] for j in eachindex(c)], [abs(c[j]) / a[j] for j in eachindex(c)]
  end
end

# the objective of the point b relative to the objective at 0, s/2 ‖y‖², for the gap to a reference
function relgap(X, y, s, λ, b, ref)
  F = nnkkt(X, y, s, λ, b).objective
  Fr = nnkkt(X, y, s, λ, ref).objective
  F0 = setprecision(BigFloat, 256) do
    big(sval(s)) * sum(abs2, big.(y)) / 2
  end
  Float64((F - Fr) / F0)
end

# ---------------------------------------------------------------------------------------------
# Solves and checks
# ---------------------------------------------------------------------------------------------
function cdsolve!(b, X, y, s, g; order = :cyclic, momentum = false, tol = cdtol(eltype(b)), seed = 1,
                  maxpasses = 100_000)
  quiet() do
    solve!(b, lossof(s, y, X), g, CDSolver(; order, momentum, tol, maxpasses, rng = Xoshiro(seed)))
  end
end

function pgdsolve!(b, X, y, s, g)
  T = eltype(b)
  options = ProximalOptions(maxiter = 50_000, ftol = 1e-15, xtol = 1e-14, gradtol = T === Float32 ? 1e-4 : 1e-10,
                            allow_f_increases = true)
  quiet() do
    solve!(b, lossof(s, y, X), g, ProximalGradientDescent(), options)
  end
end

# the point b of a solve is feasible and finite, has the external score of at most `bound`, and, for a reference,
# an objective within `objbound` of it; the reported minimum is the objective up to the rounding of its cached form
function check!(label, X, y, s, kind, λ, b, r, ref, ::Type{T}; bound = kktbound(T)) where T
  @test (label, all(>=(0), b), all(isfinite, b)) == (label, true, true)
  k = nnkkt(X, y, s, level(kind, λ), b)
  @test (label, k.score <= bound) == (label, true)
  if ref !== nothing
    gap = relgap(X, y, s, level(kind, λ), b, ref)
    @test (label, -1e-12 <= gap <= objbound(T)) == (label, true)
  end
  n, p = size(X)
  scale = Float64(sval(s)) * sum(abs2, Float64.(y)) / 2 + Float64(level(kind, λ)) * sum(Float64.(b))
  @test (label, abs(Float64(r.minimum) - Float64(k.objective)) <= 4 * (n + p) * Float64(eps(T)) * scale) ==
        (label, true)
  @test r.minimizer === b
end

# the exception of a solve and its message
function failure(f)
  err = try f() catch e e end
  err isa Exception ? (err, sprint(showerror, err)) : (nothing, "")
end

snap(x::SparseIterate) = (size(x), ncoordinates(x), nactive(x), collect(activecoordinates(x)), copy(activevalues(x)))
snap(x::Vector) = copy(x)
snap(x::Matrix) = copy(x)
snap(x) = collect(x)
unchanged(a::Tuple, b::Tuple) = a[1] == b[1] && a[2] == b[2] && a[3] == b[3] && a[4] == b[4] && isequal(a[5], b[5])
unchanged(a, b) = isequal(a, b)

# a solve that is refused: the exception type and message, and neither the iterate nor the RNG changed
function refused(exc, msg, x, f, g)
  before = snap(x)
  rng = Xoshiro(3)
  rb = copy(rng)
  err, text = failure(() -> solve!(x, f, g, CDSolver(order = :random, rng = rng)))
  @test err isa exc
  @test occursin(msg, text)
  @test unchanged(snap(x), before)
  @test rng == rb && rand(rng) == rand(rb)
end

# ---------------------------------------------------------------------------------------------
@testset "closed forms: diagonal and disjoint-support designs, raw and scaled loss ($T)" for T in FLOATS
  for (name, (X, y, t)) in (("diagonal", diagonal(T, 5)), ("disjoint", orthogonal(T, 6))), s in scales(T, size(X, 1)),
      kind in (:l1nn, :ind), f in (0.0, 0.1, 0.5), start in (:zero, :warm, :negzero)
    kind === :ind && f > 0 && continue
    λ = level_at(T, X, y, s, f)
    p = size(X, 2)
    b = start === :zero ? zeros(T, p) : start === :warm ? fill(T(0.5), p) : fill(-zero(T), p)
    r = cdsolve!(b, X, y, s, penalty(kind, λ))
    ref, scale = closed(X, y, s, level(kind, λ))
    label = (T, name, s, kind, f, start)
    @test (label, r.converged) == (label, true)
    for j in 1:p
      if iszero(ref[j])
        @test (label, j, is_pzero(b[j], T)) == (label, j, true)
      else
        err = abs(big(b[j]) - ref[j])
        @test (label, j, err <= 100 * big(eps(T)) * max(ref[j], scale[j])) == (label, j, true)
      end
    end
    check!(label, X, y, s, kind, λ, b, r, ref, T; bound = 100 * Float64(eps(T)))
  end
  # on the diagonal design, a coordinate whose unconstrained least-squares optimum t_j is negative ends at 0, with
  # g_j + λ ≥ 0 for its gradient g_j (Float64 diagnostic)
  X, y, t = diagonal(T, 5)
  λ = level_at(T, X, y, nothing, 0.1)
  b = fill(T(0.5), 6)
  cdsolve!(b, X, y, nothing, NormL1Nonneg(λ))
  g = Float64.(X)' * (Float64.(X) * Float64.(b) - Float64.(y))
  for j in findall(<(0), t)
    @test is_pzero(b[j], T)
    @test g[j] + Float64(λ) >= 0
  end
  @test any(>(0), b)
end

@testset "single coordinates: the centre, the threshold and the projection ($T)" for T in FLOATS
  # one step (maxpasses = 1) on X = [1], y = [v]: in exact arithmetic the centre is c = v from any start, and the step
  # is max(c - λ/s, 0)
  one_step(X, y, s, g, b0) = begin
    b = [b0]
    cdsolve!(b, X, y, s, g; maxpasses = 1)
    b[1]
  end
  X = ones(T, 1, 1)
  for b0 in T[0, 1, 0.25]
    @test is_pzero(one_step(X, T[-0.3], nothing, NormL1Nonneg(T(0.1)), b0), T)
    @test isapprox(one_step(X, T[0.5], nothing, NormL1Nonneg(T(0.1)), b0), T(0.4); rtol = 8 * eps(T))
    @test is_pzero(one_step(X, T[-0.3], nothing, IndNonnegative(), b0), T)
    @test one_step(X, T[0.5], nothing, IndNonnegative(), b0) == T(0.5)
  end
  # with a = 4 and s = 2 the threshold is λ/8
  X4 = T[2;;]
  @test isapprox(one_step(X4, T[1], T(2), NormL1Nonneg(T(0.1)), T(0)), T(0.5 - 0.1 / 8); rtol = 8 * eps(T))
  @test is_pzero(one_step(X4, T[-1], T(2), NormL1Nonneg(T(0.1)), T(0.2)), T)
  # the starts [0, 1] and [-0.0, 1] are accepted, and the solution of the identity design does not depend on them
  for b in (T[0, 1], T[-0, 1], T[-0.0, 1])
    r = cdsolve!(copy(b), T[1 0; 0 1], T[0.5, -2], nothing, IndNonnegative())
    @test r.minimizer == T[0.5, 0]
  end
end

@testset "the flat-column minimizer is +0 at sampled levels of both penalties ($T)" for T in FLOATS
  levels = unique(T[0, 0.3, floatmax(T) / 4, prevfloat(floatmax(T)), floatmax(T), nextfloat(zero(T))])
  for old in T[0.6, 0, 1e3]
    @test is_pzero(PS._coordinate_minimizer(IndNonnegative(), old, 1), T)
    for λ in levels
      @test is_pzero(PS._coordinate_minimizer(NormL1Nonneg(λ), old, 1), T)
    end
  end
  # the same through solve!, with a positive start on the flat column
  X, y = design(T, 12, 5, 5)
  X[:, 2] .= 0
  for g in (IndNonnegative(), NormL1Nonneg(T(0.5)), NormL1Nonneg(floatmax(T) / 2)), order in (:cyclic, :random)
    b = fill(T(0.7), 5)
    cdsolve!(b, X, y, nothing, g; order, maxpasses = 5)
    @test is_pzero(b[2], T) && all(isfinite, b) && all(>=(0), b)
  end
end

@testset "correlated and p > n designs against a BigFloat reference and PGD ($T)" for T in FLOATS
  cases = (("corr", correlated(T, 30, 6, 21)..., (:l1nn, :ind)), ("wide", design(T, 5, 8, 22)..., (:l1nn,)))
  for (name, X, y, kinds) in cases, s in scales(T, size(X, 1)), kind in kinds, f in (kind === :ind ? (0.0,) : (0.1, 0.4))
    λ = level_at(T, X, y, s, f)
    g = penalty(kind, λ)
    ref = refcheck(X, y, s, level(kind, λ))
    label = (T, name, s, kind, f)
    b = zeros(T, size(X, 2))
    r = cdsolve!(b, X, y, s, g)
    @test (label, r.converged) == (label, true)
    check!(label, X, y, s, kind, λ, b, r, ref, T)
    # warm start from a positive point
    bw = fill(T(0.5), size(X, 2))
    rw = cdsolve!(bw, X, y, s, g)
    check!((label, :warm), X, y, s, kind, λ, bw, rw, ref, T)
    # PGD on the same problem, to the same external score bound
    bp = zeros(T, size(X, 2))
    rp = pgdsolve!(bp, X, y, s, g)
    kp = nnkkt(X, y, s, level(kind, λ), bp)
    @test (label, :pgd, all(>=(0), bp), kp.score <= kktbound(T)) == (label, :pgd, true, true)
    gap = relgap(X, y, s, level(kind, λ), bp, ref)
    @test (label, :pgd, -1e-12 <= gap <= objbound(T)) == (label, :pgd, true)
    # the objectives of the two fits differ by at most the bound derived from the measured scores
    @test (label, objective_bound_holds(X, y, s, level(kind, λ), b, bp)) == (label, true)
  end
end

@testset "the default tolerance reaches the external score bound ($T)" for T in FLOATS
  for (X, y) in (correlated(T, 30, 6, 23), design(T, 40, 8, 24), design(T, 5, 8, 25)), kind in (:l1nn, :ind)
    kind === :ind && size(X, 1) < size(X, 2) && continue
    λ = level_at(T, X, y, nothing, 0.2)
    b = zeros(T, size(X, 2))
    r = quiet() do
      solve!(b, LeastSquaresLoss(y, X), penalty(kind, λ), CDSolver(order = :cyclic, momentum = false))
    end
    @test r.converged
    k = nnkkt(X, y, nothing, level(kind, λ), b)
    @test (T, kind, size(X), k.score <= kktbound(T)) == (T, kind, size(X), true)
    @test all(>=(0), b) && all(isfinite, b)
  end
end

@testset "NormL1Nonneg(0) is IndNonnegative(), and a level above s max_j (Xᵀy)_j gives 0 ($T)" for T in FLOATS
  for (X, y) in (correlated(T, 30, 6, 26), design(T, 40, 8, 27)), s in scales(T, 30)
    b1, b2 = zeros(T, size(X, 2)), zeros(T, size(X, 2))
    r1 = cdsolve!(b1, X, y, s, NormL1Nonneg(zero(T)))
    r2 = cdsolve!(b2, X, y, s, IndNonnegative())
    @test isequal(b1, b2)
    @test isequal(r1.minimum, r2.minimum) && r1.passes == r2.passes
    λ = level_at(T, X, y, s, 1.01)   # 1.01 times the boundary
    for start in (zeros(T, size(X, 2)), fill(T(0.7), size(X, 2)))
      b = copy(start)
      r = cdsolve!(b, X, y, s, NormL1Nonneg(λ))
      @test all(j -> is_pzero(b[j], T), eachindex(b))
      @test nnkkt(X, y, s, λ, b).score <= kktbound(T)
    end
  end
end

@testset "a level exactly at s max_j (Xᵀy)_j gives 0 on a dyadic design ($T)" for T in FLOATS
  X, y = Matrix{T}(I, 2, 2), T[1, 0.5]
  for start in (zeros(T, 2), fill(T(0.5), 2))
    b = copy(start)
    cdsolve!(b, X, y, nothing, NormL1Nonneg(one(T)))
    @test all(j -> is_pzero(b[j], T), 1:2)
  end
end

@testset "starts: zero, positive, -0.0 entries; the returned point is feasible and finite ($T)" for T in FLOATS
  X, y = correlated(T, 30, 6, 28)
  λ = level_at(T, X, y, nothing, 0.2)
  ref = refcheck(X, y, nothing, λ)
  starts = (zeros(T, 6), fill(T(0.5), 6), fill(-zero(T), 6), T[-0.0, 1, 0, 3, -0.0, 0.1], fill(floatmin(T), 6))
  for kind in (:l1nn, :ind), (i, start) in enumerate(starts)
    b = copy(start)
    g = penalty(kind, λ)
    r = cdsolve!(b, X, y, nothing, g)
    check!((T, kind, i), X, y, nothing, kind, λ, b, r, kind === :ind ? refcheck(X, y, nothing, 0) : ref, T)
  end
end

@testset "flat columns: the coordinate ends at +0 and the others solve the reduced problem ($T)" for T in FLOATS
  X, y = correlated(T, 30, 6, 29)
  for k in (1, 3, 6), kind in (:l1nn, :ind), start in (0.7, 0.0)
    Xf = copy(X)
    Xf[:, k] .= 0
    λ = level_at(T, Xf, y, nothing, 0.1)
    keep = setdiff(1:6, k)
    ref = zeros(BigFloat, 6)
    ref[keep] .= refcheck(Xf[:, keep], y, nothing, level(kind, λ))
    b = fill(T(start), 6)
    r = cdsolve!(b, Xf, y, nothing, penalty(kind, λ))
    label = (T, k, kind, start)
    @test (label, is_pzero(b[k], T)) == (label, true)
    check!(label, Xf, y, nothing, kind, λ, b, r, ref, T)
    # the reduced problem has the same solution on the other coordinates
    br = zeros(T, 5)
    cdsolve!(br, Xf[:, keep], y, nothing, penalty(kind, λ))
    @test (label, maximum(abs, b[keep] - br) <= 100 * sqrt(eps(T)) * max(maximum(abs, br), 1)) == (label, true)
  end
end

@testset "orders: cyclic, random, and momentum, each from a seeded RNG ($T)" for T in FLOATS
  X, y = correlated(T, 30, 6, 30)
  λ = level_at(T, X, y, nothing, 0.2)
  ref = refcheck(X, y, nothing, λ)
  for kind in (:l1nn, :ind), (order, momentum) in ((:cyclic, nothing), (:cyclic, false), (:random, nothing),
                                                    (:random, false), (:random, true))
    b = fill(T(0.3), 6)
    r = cdsolve!(b, X, y, nothing, penalty(kind, λ); order, momentum, seed = 5)
    check!((T, kind, order, momentum), X, y, nothing, kind, λ, b, r, kind === :ind ? refcheck(X, y, nothing, 0) : ref, T)
    @test r.converged
  end
  # the default CDSolver (random order, default momentum) from the RNG of a seed is reproducible
  b1, b2 = zeros(T, 6), zeros(T, 6)
  quiet() do
    solve!(b1, LeastSquaresLoss(y, X), NormL1Nonneg(λ), CDSolver(rng = Xoshiro(9)))
    solve!(b2, LeastSquaresLoss(y, X), NormL1Nonneg(λ), CDSolver(rng = Xoshiro(9)))
  end
  @test isequal(b1, b2) && all(>=(0), b1)
end

# ---------------------------------------------------------------------------------------------
# The coordinate step outside the band of p = s a and 1/p
# ---------------------------------------------------------------------------------------------
# The allowances for the threshold τ = λ/(α a) (the test levels are of type T, so the conversion to Float64 of the
# level is exact) are those of the existing tests of `_threshold`: Float32 within one
# Float32 ulp of the quotient where it is below floatmax; Float64 within 3 eps relative where normal, plus
# nextfloat(0.0) where subnormal. Returns the allowed absolute error of τ̂ and whether the quotient is in the capped
# region: at or above floatmax(T) for Float32, above floatmax(T) (1 - 3 eps) for Float64. In that region the sweep
# accepts a capped threshold within four floats below floatmax(T).
function tau_allowance(::Type{Float32}, τ̂::Float32, ref)
  ref >= big(floatmax(Float32)) && return big(0), true
  max(big(eps(τ̂)), big(eps(min(nextfloat(τ̂), floatmax(Float32))))), false
end
function tau_allowance(::Type{Float64}, τ̂::Float64, ref)
  ref > big(floatmax(Float64)) * (1 - 3 * eps()) && return big(0), true
  ref >= big(floatmin(Float64)) && return 3 * big(eps()) * ref, false
  big(nextfloat(0.0)) + 3 * big(eps()) * ref, false
end

@testset "the exceptional steps of IndNonnegative and NormL1Nonneg against BigFloat ($T)" for T in FLOATS
  ks = T === Float32 ? (-140, -100, -60, -20, 0, 20, 60, 100, 120) : (-1070, -1000, -600, -300, -100, 0, 100, 300, 600, 1000, 1020)
  tiny = nextfloat(zero(T))
  λs = T[0, tiny, 3tiny, T === Float32 ? 1e-30 : 1e-300, 0.3, 1, 1e10, floatmax(T) / 4]
  centres = T[0.3, -2, 1e5, 1e-30, -floatmax(T) / 2, 0, -0.0]
  counts = Dict(:cases => 0, :outside => 0)
  bad = String[]
  check(ok, info...) = ok || (length(bad) < 10 && push!(bad, join(string.(info), ", ")); false)
  setprecision(BigFloat, 256) do
    for jα in ks, ja in ks
      α, a = ldexp(T(1.3), jα), ldexp(T(1.7), ja)
      (iszero(α) || iszero(a)) && continue
      outside = !(floatmin(T) <= α * a <= floatmax(T) && floatmin(T) <= inv(α * a))
      for c in centres
        # IndNonnegative: max(c, 0), at +0 for a nonpositive centre
        res = PS._exceptional_step(IndNonnegative(), c, α, a, 1)
        check(res isa T && res == max(big(c), 0) && !signbit(res), "IndNonnegative", c, α, a, res)
        for λ in λs
          info = (λ, α, a, c)
          res = PS._exceptional_step(NormL1Nonneg(λ), c, α, a, 1)
          ref_τ = big(λ) / (big(α) * big(a))
          τ̂ = min(PS._threshold(T, λ, α, a), floatmax(T))
          Δτ, atmax = tau_allowance(T, τ̂, ref_τ)
          # in the capped region of `tau_allowance` the threshold is within 4 floats below floatmax(T); elsewhere within
          # the allowance
          check(atmax ? τ̂ >= prevfloat(floatmax(T), 4) : abs(big(τ̂) - ref_τ) <= Δτ, "threshold", info...)
          ref = max(big(c) - ref_τ, 0)
          allowed = Δτ + big(eps(T)) * abs(ref) + big(tiny)
          check(res isa T && isfinite(res) && !signbit(res), "result", info..., res)
          check(abs(big(res) - ref) <= allowed, "step against max(c - λ/(α a), 0)", info..., res)
          iszero(λ) && check(res == max(c, zero(T)), "level 0", info...)
          counts[:cases] += 1
          counts[:outside] += outside
        end
      end
      # a centre of +Inf stays +Inf and a NaN centre stays NaN (both refused by `_visit!`), and -Inf gives +0
      for g in (IndNonnegative(), NormL1Nonneg(T(0.3)), NormL1Nonneg(zero(T)))
        check(PS._exceptional_step(g, T(Inf), α, a, 1) === T(Inf), "+Inf", typeof(g), α, a)
        check(isnan(PS._exceptional_step(g, T(NaN), α, a, 1)), "NaN", typeof(g), α, a)
        check(is_pzero(PS._exceptional_step(g, T(-Inf), α, a, 1), T), "-Inf", typeof(g), α, a)
      end
    end
  end
  @test isempty(bad)
  isempty(bad) || foreach(println, bad)
  @test counts[:outside] > 500
  # a scale type wider than T has no such step (unreachable through solve!), as for NormL1
  W = T === Float32 ? Float64 : BigFloat
  @test_throws ArgumentError PS._exceptional_step(IndNonnegative(), one(T), W(1), one(T), 1)
  @test_throws ArgumentError PS._exceptional_step(NormL1Nonneg(T(0.1)), one(T), W(1), one(T), 1)
end

# One CD step through solve! on a single column outside the band: s a overflows (Inf) or is subnormal, so that
# the step is formed by `_exceptional_step`. The result is max(c - λ/(s a), 0) for the centre c = b0 + Xᵀ(y - X b0) / a
# of the stored data, from BigFloat. On the base branch these solves are refused by the penalty gate, and an
# exceptional step of these penalties would be refused as having no range-safe form.
@testset "one coordinate step with s a outside the band through solve! ($T)" for T in FLOATS
  # overflow: y = 0.01 X, so that s ‖y‖² is finite, and λ/(s a) is about 4e-4; subnormal: y = 2 X, and λ/(s a) is about
  # 0.5 (the quotients of the stored values are formed in BigFloat below)
  big_s, big_λ = T === Float32 ? (T(1e38), T(1e36)) : (T(1e307), T(1e305))
  small_s = T === Float32 ? T(1e-30) : T(1e-300)
  small_λ = T === Float32 ? T(1.25e-39) : T(1.25e-309)
  X = T[3.0; 4.0]
  for (name, s, λ, mult) in (("overflow", big_s, big_λ, 0.01), ("subnormal", small_s, small_λ, 2.0)), ysign in (1, -1),
      b0 in T[0, 0.25 * mult], kind in (:l1nn, :ind, :zero)
    Xs = name == "subnormal" ? T[3e-5; 4e-5] : X
    y = T(mult * ysign) .* vec(Xs)
    a = sum(abs2, Xs)
    p = s * a
    @test !(floatmin(T) <= p && floatmin(T) <= inv(p))
    g = kind === :ind ? IndNonnegative() : NormL1Nonneg(kind === :zero ? zero(T) : λ)
    b = [b0]
    r = quiet() do
      solve!(b, Scaled(LeastSquaresLoss(y, reshape(Xs, :, 1)), s), g, CDSolver(order = :cyclic, momentum = false, maxpasses = 1))
    end
    label = (T, name, ysign, b0, kind)
    expected, scale = setprecision(BigFloat, 256) do
      Xb, yb, sb, ab = big.(Xs), big.(y), big(s), sum(abs2, big.(Xs))
      c = big(b0) + dot(Xb, yb - Xb * big(b0)) / ab
      τ = kind === :l1nn ? big(λ) / (sb * ab) : zero(BigFloat)
      max(c - τ, 0), max(abs(c), τ)
    end
    @test (label, isfinite(b[1]) && b[1] >= 0) == (label, true)
    @test (label, abs(big(b[1]) - expected) <= 64 * big(eps(T)) * scale + 2 * big(nextfloat(zero(T)))) == (label, true)
    ysign == -1 && @test (label, is_pzero(b[1], T)) == (label, true)
    @test r.minimizer === b
  end
end

# ---------------------------------------------------------------------------------------------
@testset "refusals before any write or RNG draw ($T)" for T in FLOATS
  X, y = T[1 0; 0 2; 1 1], T[1, -1, 0.5]
  f = LeastSquaresLoss(y, X)
  g1, g0 = NormL1Nonneg(T(0.1)), IndNonnegative()
  x0 = T[0.3, 0.2]
  # an accepted solve first, so that a refusal below is not a refusal of the fixture
  let b = copy(x0)
    @test solve!(b, f, g1, CDSolver(order = :cyclic, momentum = false)).minimizer === b
  end
  for g in (g1, g0)
    # a negative start, a negative subnormal start and a -Inf or NaN start are refused, not projected
    for bad in (T[-0.1, 0.2], T[0.3, -nextfloat(zero(T))], T[0.3, -floatmin(T)], T[0.3, -Inf], T[NaN, 0.2], T[0.3, Inf])
      refused(ArgumentError, "", copy(bad), f, g)
    end
    refused(ArgumentError, "requires a feasible starting point", T[-0.1, 0.2], f, g)
    refused(ArgumentError, "requires a feasible starting point", T[0.3, -nextfloat(zero(T))], f, g)
    # coefficients other than a dense Vector
    refused(ArgumentError, "on a dense Vector only", SparseIterate(copy(x0)), f, g)
    refused(ArgumentError, "on a dense Vector only", SparseIterate(T, 2), f, g)
    refused(ArgumentError, "", BlockIterate(copy(x0), [[1], [2]]), f, g)
    refused(ArgumentError, "", zeros(T, 2, 2), LeastSquaresLoss(hcat(y, y), X), g)
    refused(ArgumentError, "x must be a dense Vector", zeros(T, 2, 2), f, g)
    refused(ArgumentError, "x must be a dense Vector", view(copy(x0), :), f, g)
    # losses and penalties
    refused(ArgumentError, "Matrix responses need a compatible matrix coefficient layout", copy(x0), LeastSquaresLoss(hcat(y, y), X), g)
    refused(ArgumentError, "unsupported type", copy(x0), big"2.0" * f, g)
    refused(ArgumentError, "unsupported type", copy(x0), (1 // 3) * f, g)
    # a logistic loss, raw or scaled (Float64 data only)
    fl = LogisticLoss([0.0, 1.0, 1.0], Float64.(X))
    refused(ArgumentError, "LogisticLoss is supported only by ProximalGradientDescent", Float64.(x0), fl, g)
    refused(ArgumentError, "LogisticLoss is supported only by ProximalGradientDescent", Float64.(x0), (1 / 3) * fl, g)
    refused(ArgumentError, "", copy(x0), SqrtLeastSquaresLoss(y, X), g)
    refused(ArgumentError, "CDSolver supports NormL1", copy(x0), f, Scaled(g, 2))
    # types: Float32 data with Float64 coefficients and the converse
    refused(ArgumentError, "X must be Matrix{Float64}", Float64.(x0), LeastSquaresLoss(Float32.(y), Float32.(X)), g)
    refused(ArgumentError, "X must be Matrix{Float32}", Float32.(x0), LeastSquaresLoss(Float64.(y), Float64.(X)), g)
    # a loss with a zero scale
    refused(ArgumentError, "", copy(x0), zero(T) * f, g)
    refused(DimensionMismatch, "x/y dimensions do not match X", zeros(T, 3), f, g)
    # x aliases y or X
    ys = T[1, 2, 3]
    refused(ArgumentError, "must not alias", ys, LeastSquaresLoss(ys, T[1 0 1; 0 2 1; 1 1 0]), g)
    ax = T[0.5, 0.5]
    refused(ArgumentError, "must not alias", ax, LeastSquaresLoss(T[1], reshape(ax, 1, 2)), g)
  end
  # weighted NormL1Nonneg
  refused(ArgumentError, "weighted NormL1Nonneg is not supported", copy(x0), f, NormL1Nonneg(T(0.1), ones(T, 2)))
  refused(ArgumentError, "weighted NormL1Nonneg is not supported", copy(x0), f, NormL1Nonneg(T(0.1), zeros(T, 2)))
  # invalid levels
  for (λ, msg) in ((T(Inf), "must be finite and nonnegative"), (big(10)^1000, "not representable"),
                   (big(10.0)^(-1000), "not representable"))
    refused(ArgumentError, msg, copy(x0), f, NormL1Nonneg(λ))
  end
  if T === Float32
    refused(ArgumentError, "overflow or underflow in Float32", copy(x0), f, NormL1Nonneg(1e300))
    refused(ArgumentError, "overflow or underflow in Float32", copy(x0), f, NormL1Nonneg(1e-300))
  end
  # a negative or NaN level is refused by the constructor of NormL1Nonneg itself
  @test_throws Exception NormL1Nonneg(-T(0.1))
  @test_throws Exception NormL1Nonneg(T(NaN))
  # APG refuses both penalties
  for g in (g1, g0)
    refused_apg = copy(x0)
    @test_throws ArgumentError solve!(refused_apg, f, g, AccProxGradDescent())
    @test refused_apg == x0
  end
end

@testset "X and y are not modified by a solve ($T)" for T in FLOATS
  X, y = correlated(T, 30, 6, 31)
  X0, y0 = copy(X), copy(y)
  λ = level_at(T, X, y, nothing, 0.2)
  for kind in (:l1nn, :ind), s in scales(T, 30)
    b = zeros(T, 6)
    cdsolve!(b, X, y, s, penalty(kind, λ))
    @test X == X0 && y == y0
  end
end

# The loss borrows X and y: a change after its construction is a change of the data at the call.
@testset "data changed after the loss was built: the solve uses the data at the call ($T)" for T in FLOATS
  for kind in (:l1nn, :ind)
    X, y = correlated(T, 30, 6, 32)
    f = LeastSquaresLoss(y, X)
    @test f.X === X
    λ = level_at(T, X, y, nothing, 0.2)
    X[:, 2] .*= T(1.5)
    y .+= T(0.25)
    g = penalty(kind, λ)
    b = zeros(T, 6)
    r = quiet() do
      solve!(b, f, g, CDSolver(order = :cyclic, momentum = false, tol = cdtol(T)))
    end
    ref = refcheck(X, y, nothing, level(kind, λ))
    check!((T, :changed, kind), X, y, nothing, kind, λ, b, r, ref, T)
    # a NaN written after the construction is refused with the coefficients and the RNG unchanged
    X[3, 1] = T(NaN)
    refused(ArgumentError, "finite", fill(T(0.3), 6), f, g)
  end
end

# A refusal during a pass after an earlier coordinate has moved leaves the caller's coefficients unchanged. In each
# fixture column 1 moves in the private run (checked at the model), and the cyclic order visits it before column 3.
@testset "rollback: a refusal at column 3 after column 1 moved leaves the start unchanged ($T)" for T in FLOATS
  X0, y = design(T, 20, 4, 91)
  huge = T === Float32 ? T(1e20) : T(1e160)
  tiny = T === Float32 ? T(1e-30) : T(1e-170)
  for (name, col, start, msg) in (("nonfinite curvature", huge .* X0[:, 3], zeros(T, 4), "the curvature of coordinate 3"),
                                  ("curvature rounds to zero", tiny .* sign.(X0[:, 3]), fill(T(0.3), 4),
                                   "the coordinate curvature underflows")),
      g in (NormL1Nonneg(T(0.01)), IndNonnegative())
    X = copy(X0)
    X[:, 3] .= col
    f = LeastSquaresLoss(y, X)
    label = (T, name, typeof(g))
    @test (label, isinf(sum(abs2, X[:, 3])) == startswith(name, "nonfinite")) == (label, true)
    xs = SparseIterate(copy(start))
    m = PS.cdmodel(f, xs)
    PS.initialize!(m, xs)
    h = PS.coordinate_step!(m, g, xs, 1)
    @test (label, !iszero(h) && xs[1] != start[1]) == (label, true)
    err, text = failure(() -> PS.coordinate_step!(m, g, xs, 3))
    @test (label, err isa ArgumentError && occursin(msg, text)) == (label, true)
    b = copy(start)
    rng = Xoshiro(3)
    rb = copy(rng)
    err, text = failure(() -> solve!(b, f, g, CDSolver(order = :cyclic, momentum = false, rng = rng)))
    @test (label, err isa ArgumentError && occursin(msg, text)) == (label, true)
    @test (label, isequal(b, start)) == (label, true)
  end
  # the same problem without that column solves
  X = copy(X0)
  b = fill(T(0.3), 3)
  r = cdsolve!(b, X[:, [1, 2, 4]], y, nothing, NormL1Nonneg(T(0.01)))
  @test r.converged && all(>=(0), b)
end

# ---------------------------------------------------------------------------------------------
# The bytes of a solve with a fixed number of passes (tol = 0 runs to the cap), measured after one warm-up run, as the
# minimum of three runs. The two budgets pay the same fixed cost, which the difference removes.
function pass_bytes(f, g, x0, passes)
  run() = quiet() do
    x = copy(x0)
    @allocated solve!(x, f, g, CDSolver(order = :cyclic, momentum = false, tol = 0.0, maxpasses = passes))
  end
  run()
  minimum(run() for _ in 1:3)
end

# the bytes of 6 more passes (8 against 2), divided by 6
pass_increment(f, g, x0) = (pass_bytes(f, g, x0, 8) - pass_bytes(f, g, x0, 2)) / 6

@testset "the mean bytes per added pass (passes 3 to 8, cyclic, no momentum) of the nonnegative penalties are at most those of NormL1 ($T)" for T in FLOATS
  X, y = design(T, 40, 8, 24)
  λ = level_at(T, X, y, nothing, 0.1)
  f = LeastSquaresLoss(y, X)
  for x0 in (zeros(T, 8), fill(T(0.5), 8))
    l1 = pass_increment(f, NormL1(λ), x0)
    for g in (NormL1Nonneg(λ), IndNonnegative())
      nn = pass_increment(f, g, x0)
      @test (T, typeof(g), nn <= l1) == (T, typeof(g), true)
      nn == l1 || println("bytes per pass, $T, $(typeof(g)): $nn, NormL1 $l1")
    end
  end
end

end
