module CDElasticNetTests
# ElasticNet(λ1, λ2) with CDSolver on the least-squares loss α/2 ‖y - Xb‖² + λ1‖b‖₁ + (λ2/2)‖b‖²
# (α = 1 for a raw LeastSquaresLoss, 1/n or 2 for a Scaled one), for a dense Vector and a
# one-dimensional SparseIterate, in Float32 and Float64.
#
# The oracle is independent of the solver and of ProximalBase's kkt_violation: from the stored X, y, α,
# λ1, λ2 and the returned point it forms, in 256-bit BigFloat, the gradient α Xᵀ(Xb - y), the residual
# max_j |g_j + λ2 b_j + λ1 sign b_j| (b_j ≠ 0) or max(|g_j| - λ1, 0) (b_j = 0), and the objective. The
# references are BigFloat closed forms for designs with a diagonal XᵀX, for ridge and for least squares,
# and, for the general case, the solve of the support equations
# (α X_AᵀX_A + λ2 I) b_A = α X_Aᵀy - λ1 s_A with the support A and the signs s taken from a tight Float64
# CD solve, accepted as the minimizer if the signs agree and |g_j| ≤ λ1 off the support (`reference`).
#
# Tolerances follow the repository policy for optimization tests: the solve must be accurate to a bound
# tied to `tol` and eps(T), not equal to anything bit for bit. The solves use the tolerance `cdtol(T)`
# (1e-12 in Float64, 1e-6 in Float32; the default 1e-7 is not resolved reliably in Float32). The bounds on
# the distance to the reference relative to ‖b‖∞, on the objective gap relative to F(b) and on the residual
# relative to max(λ1, α‖Xᵀy‖∞) were set from the worst values these solves reach: each is at least 150 times
# that value (the ridge with more columns than rows, which is ill conditioned, takes the factor `slack` = 10;
# the closed forms of the designs with a diagonal XᵀX are asserted to within 100 eps(T) relative to ‖b‖∞ plus
# the largest unpenalized coordinate, where the solves reach 1 eps(T)). The bound on the distance is below
# the difference between the solutions with and without the ridge term for the raw-loss design of seed 11
# at the levels (f1, c2) = (0.05, 0.02): 1.7% (Float32) and 2.8% (Float64) of ‖b‖∞, in independent
# BigFloat references that pass the sign and off-support checks; omitting a term that is 0 changes nothing.
# Bit-for-bit assertions are made where two penalties give the same function, ElasticNet(λ, 0) against
# NormL1(λ), and where an iterate must be unchanged. The solves use order = :cyclic or a seeded Xoshiro:
# CD's default RNG is unseeded.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
import Logging
const PS = ProximalSolvers

const FLOATS = (Float64, Float32)
cdtol(::Type{Float64}) = 1e-12
cdtol(::Type{Float32}) = 1e-6
xbound(::Type{Float64}) = 1e-8
xbound(::Type{Float32}) = 2e-3
gapbound(::Type{Float64}) = 1e-12
gapbound(::Type{Float32}) = 1e-4
kktbound(::Type{Float64}) = 1e-8
kktbound(::Type{Float32}) = 1e-3

alpha_of(scale) = scale === nothing ? 1 : scale
lossof(scale, y, X) = scale === nothing ? LeastSquaresLoss(y, X) : Scaled(LeastSquaresLoss(y, X), scale)
# the loss scales of the tests: raw, a Float scale of the data type, and an integer scale
scales(::Type{T}, n) where T = (nothing, one(T) / T(n), 2)

# ---------------------------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------------------------
function design(::Type{T}, n, p, seed) where T
  rng = Xoshiro(seed)
  X = randn(rng, T, n, p)
  β = zeros(T, p)
  β[1:4] .= T[2.0, -1.5, 1.0, 0.5]
  y = X * β + T(0.3) * randn(rng, T, n)
  X, y
end

# columns with the pairwise correlation ρ
function correlated(::Type{T}, n, p, seed; ρ = 0.9) where T
  rng = Xoshiro(seed)
  common = randn(rng, T, n)
  X = T(sqrt(ρ)) .* common .+ T(sqrt(1 - ρ)) .* randn(rng, T, n, p)
  β = zeros(T, p)
  β[1:3] .= T[2.0, -1.5, 1.0]
  y = X * β + T(0.3) * randn(rng, T, n)
  X, y
end

# disjoint column supports, so that XᵀX is diagonal in floating point
function orthogonal(::Type{T}, seed) where T
  rng = Xoshiro(seed)
  X = zeros(T, 8, 4)
  for j in 1:4, i in (2j - 1, 2j)
    X[i, j] = T(1 + rand(rng)) * (rand(rng) < 0.5 ? -1 : 1)
  end
  X, randn(rng, T, 8)
end

# a square diagonal design with different column scales
function diagonal(::Type{T}, seed) where T
  rng = Xoshiro(seed)
  d = [T(0.5 + 3.5 * rand(rng)) * (rand(rng) < 0.5 ? -1 : 1) for _ in 1:6]
  Matrix(Diagonal(d)), randn(rng, T, 6)
end

lambdamax(X, y, α) = setprecision(BigFloat, 256) do
  Float64(maximum(abs, big(α) * (big.(X)' * big.(y))))
end

# the levels λ1 = f1 λmax and λ2 = c2 α ‖X‖²_F / p, rounded once to T
function levels(::Type{T}, X, y, scale, f1, c2) where T
  α = alpha_of(scale)
  T(f1 * lambdamax(X, y, α)), T(c2 * Float64(α) * sum(abs2, Float64.(X)) / size(X, 2))
end

# ---------------------------------------------------------------------------------------------
# Oracle and references (256-bit BigFloat, from the data as stored)
# ---------------------------------------------------------------------------------------------
# (‖residual‖∞, max(λ1, α‖Xᵀy‖∞)) as Float64 and F(b) as BigFloat
function oracle(X, y, α, λ1, λ2, b)
  setprecision(BigFloat, 256) do
    Xb, yb, bb, a, l1, l2 = big.(X), big.(y), big.(b), big(α), big(λ1), big(λ2)
    d = Xb * bb - yb
    g = a .* (Xb' * d)
    res = maximum(j -> iszero(bb[j]) ? max(abs(g[j]) - l1, 0) : abs(g[j] + l2 * bb[j] + l1 * sign(bb[j])), eachindex(bb))
    scale = max(l1, a * maximum(abs, Xb' * yb))
    F = a * sum(abs2, d) / 2 + l1 * sum(abs, bb) + l2 * sum(abs2, bb) / 2
    Float64(res), Float64(scale), F
  end
end

# (‖x - b‖∞, ‖b‖∞) as Float64, for a BigFloat b
function distance(x, b)
  setprecision(BigFloat, 256) do
    Float64.((maximum(abs, big.(x) .- b), maximum(abs, b)))
  end
end

is_zero(v, ::Type{T}) where T = v isa T && iszero(v)
quiet(f) = Logging.with_logger(f, Logging.NullLogger())

# The BigFloat minimizer of the problem and whether it is verified: the support and signs come from a
# tight Float64 CD solve, and the minimizer solves the support equations; the second value says that
# the signs agree with those of the support and |g_j| ≤ λ1 off the support.
function reference(X, y, α, λ1, λ2)
  Xf, yf = Float64.(X), Float64.(y)
  b0 = zeros(size(X, 2))
  quiet() do
    solve!(b0, Scaled(LeastSquaresLoss(yf, Xf), Float64(α)), ElasticNet(Float64(λ1), Float64(λ2)),
           CDSolver(order = :cyclic, momentum = false, tol = 1e-13))
  end
  setprecision(BigFloat, 256) do
    Xb, yb, a, l1, l2 = big.(X), big.(y), big(α), big(λ1), big(λ2)
    p = size(X, 2)
    S = findall(!iszero, b0)
    s = sign.(b0[S])
    β = zeros(BigFloat, p)
    if !isempty(S)
      XS = Xb[:, S]
      β[S] = (a * XS' * XS + l2 * I) \ (a * XS' * yb - l1 * s)
    end
    g = a .* (Xb' * (Xb * β - yb))
    ok = all(j -> sign(β[j]) == s[findfirst(==(j), S)], S) && all(j -> abs(g[j]) <= l1, setdiff(1:p, S))
    β, ok
  end
end

# β_j = shrink(α X_jᵀy, λ1) / (α ‖X_j‖² + λ2) for a design with a diagonal XᵀX, and the largest
# |α X_jᵀy| / (α ‖X_j‖²) (the scale of the unpenalized coordinates)
function analytic(X, y, α, λ1, λ2)
  setprecision(BigFloat, 256) do
    Xb, yb, a, l1, l2 = big.(X), big.(y), big(α), big(λ1), big(λ2)
    c = [a * dot(Xb[:, j], yb) for j in 1:size(X, 2)]
    q = [a * dot(Xb[:, j], Xb[:, j]) for j in 1:size(X, 2)]
    [sign(c[j]) * max(abs(c[j]) - l1, 0) / (q[j] + l2) for j in eachindex(c)], Float64(maximum(abs.(c) ./ q))
  end
end

# the solution of (α XᵀX + λ2 I) b = α Xᵀy, ridge at λ2 > 0 and least squares at λ2 = 0
function normal_equations(X, y, α, λ2)
  setprecision(BigFloat, 256) do
    Xb, yb, a, l2 = big.(X), big.(y), big(α), big(λ2)
    (a * Xb' * Xb + l2 * I) \ (a * Xb' * yb)
  end
end

# ---------------------------------------------------------------------------------------------
# Solves and checks
# ---------------------------------------------------------------------------------------------
# an owner with the given active IDs, in this slot order, holding the given values (a zero value stays
# an active zero)
function owner(::Type{T}, p, ids, vals) where T
  x = SparseIterate(T, p)
  for (i, v) in zip(ids, vals)
    activate!(x, i)
    x[i] = v
  end
  x
end
snapshot(x) = (size(x), ncoordinates(x), nactive(x), collect(activecoordinates(x)), copy(activevalues(x)))
same_state(a, b) = a[1] == b[1] && a[2] == b[2] && a[3] == b[3] && a[4] == b[4] && isequal(a[5], b[5])
snap(x::SparseIterate) = snapshot(x)
snap(x) = copy(x)
unchanged(a::Tuple, b::Tuple) = same_state(a, b)
unchanged(a, b) = isequal(a, b)

# the iterate of a solve: a dense Vector, an empty SparseIterate, or a SparseIterate holding x0
function startof(kind, x0::Vector{T}) where T
  kind === :dense ? copy(x0) : kind === :empty ? SparseIterate(T, length(x0)) : SparseIterate(copy(x0))
end

# the combinations of order and momentum of the matrix of solves: cyclic order has no momentum
const CONFIGS = ((:cyclic, nothing), (:cyclic, false), (:random, nothing), (:random, false), (:random, true))

function solve_en(X, y, scale, g, start; order = :cyclic, momentum = nothing, tol = cdtol(eltype(X)),
                  seed = 1, maxpasses = 100_000)
  solve!(start, lossof(scale, y, X), g, CDSolver(; order, momentum, tol, maxpasses, rng = Xoshiro(seed)))
end

# the quality of the solve against the BigFloat reference β of the problem, and the fields of the result
function check!(label, X, y, scale, g, x, r, β, ::Type{T}; slack = 1) where T
  α = alpha_of(scale)
  λ1, λ2 = T(g.λ1), T(g.λ2)
  xv = Vector(x)
  res, S, F = oracle(X, y, α, λ1, λ2, xv)
  _, _, Fβ = oracle(X, y, α, λ1, λ2, β)
  dx, nβ = distance(xv, β)
  @test (label, r.converged) == (label, true)
  @test (label, dx <= slack * xbound(T) * nβ) == (label, true)
  gap = Float64(F - Fβ)
  @test (label, -1e-30 * Float64(Fβ) <= gap <= slack * gapbound(T) * Float64(Fβ)) == (label, true)
  @test (label, res <= slack * kktbound(T) * S) == (label, true)
  check_result!(label, X, y, α, λ1, λ2, x, r, T)
end

function check_result!(label, X, y, α, λ1, λ2, x, r, ::Type{T}) where T
  F = Float64(oracle(X, y, α, λ1, λ2, Vector(x))[3])
  n, p = size(X)
  # the objective is formed from a cached residual with one rounding per update: (n + p) eps(T) relative to
  # α/2 ‖y‖² + λ1 ‖x‖₁ + (λ2/2) ‖x‖²
  scale = Float64(α) * sum(abs2, Float64.(y)) / 2 + Float64(λ1) * sum(abs, Float64.(Vector(x))) +
          Float64(λ2) / 2 * sum(abs2, Float64.(Vector(x)))
  @test (label, abs(Float64(r.minimum) - F) <= (n + p) * Float64(eps(T)) * scale) == (label, true)
  @test r.minimizer === x
  @test r.kkt_checks == 0
  @test isnan(r.gap)
end

# the exception of a solve and its message
function failure(f)
  err = try f() catch e e end
  err isa Exception ? (err, sprint(showerror, err)) : (nothing, "")
end

# a solve that is refused: the exception type and message, and neither the iterate nor the RNG changed
function refused(exc, msg, x, f, g; rng_unchanged = true)
  before = snap(x)
  rng = Xoshiro(3)
  rb = copy(rng)
  err, text = failure(() -> solve!(x, f, g, CDSolver(order = :random, rng = rng)))
  @test err isa exc
  @test occursin(msg, text)
  @test unchanged(snap(x), before)
  rng_unchanged && @test rng == rb && rand(rng) == rand(rb)
end

# ---------------------------------------------------------------------------------------------
@testset "the flat-column minimizer is 0 at every level of both penalties" begin
  for T in FLOATS
    big_levels = unique([floatmax(T) / 2, prevfloat(floatmax(T)), floatmax(T), floatmax(T) / 4])
    for λ1 in T[0, 0.3, 1000], λ2 in T[0, 0.7, 1000]
      @test is_zero(PS._coordinate_minimizer(ElasticNet(λ1, λ2), T(0.6), 1), T)
    end
    for λ in big_levels
      @test is_zero(PS._coordinate_minimizer(ElasticNet(zero(T), λ), T(0.6), 1), T)
      @test is_zero(PS._coordinate_minimizer(ElasticNet(λ, zero(T)), T(0.6), 1), T)
      @test is_zero(PS._coordinate_minimizer(ElasticNet(λ, λ), T(0.6), 1), T)
    end
    @test is_zero(PS._coordinate_minimizer(NormL1(T(0.3)), T(0.6), 1), T)
    @test is_zero(PS._coordinate_minimizer(NormL1(zero(T)), T(0.6), 1), T)
    # the same through solve!, with a nonzero start on the flat column
    X, y = design(T, 12, 5, 5)
    X[:, 2] .= 0
    for λ in (zero(T), T(0.5), floatmax(T) / 2), kind in (:dense, :warm)
      x = startof(kind, fill(T(0.7), 5))
      g = ElasticNet(T(0.01), λ)
      r = quiet() do
        solve!(x, LeastSquaresLoss(y, X), g, CDSolver(order = :cyclic, momentum = false, maxpasses = 5))
      end
      @test is_zero(Vector(x)[2], T) && all(isfinite, Vector(x))
    end
  end
end

@testset "random full-rank designs: dense and SparseIterate, raw and Scaled, cyclic and random, momentum" begin
  n, p = 40, 10
  for T in FLOATS, scale in scales(T, n), (f1, c2) in ((0.1, 0.1), (0.3, 1.0), (0.0, 0.5), (0.2, 0.0), (0.05, 0.02))
    X, y = design(T, n, p, 11)
    α = alpha_of(scale)
    λ1, λ2 = levels(T, X, y, scale, f1, c2)
    β, ok = reference(X, y, α, λ1, λ2)
    @test (T, scale, f1, c2, ok) == (T, scale, f1, c2, true)
    ok || continue
    g = ElasticNet(λ1, λ2)
    for kind in (:dense, :empty), (order, momentum) in CONFIGS
      label = (T, scale, f1, c2, kind, order, momentum)
      x = startof(kind, zeros(T, p))
      r = solve_en(X, y, scale, g, x; order, momentum, seed = 7)
      check!(label, X, y, scale, g, x, r, β, T)
    end
  end
end

@testset "a Float64 loss scale on Float32 data: dense and SparseIterate" begin
  n, p = 40, 10
  X, y = design(Float32, n, p, 11)
  scale = 1 / n
  α = alpha_of(scale)
  for (f1, c2) in ((0.1, 0.1), (0.0, 0.5), (0.2, 0.0))
    λ1, λ2 = levels(Float32, X, y, scale, f1, c2)
    β, ok = reference(X, y, α, λ1, λ2)
    @test (f1, c2, ok) == (f1, c2, true)
    ok || continue
    g = ElasticNet(λ1, λ2)
    for kind in (:dense, :empty), (order, momentum) in CONFIGS[[1, 3]]
      x = startof(kind, zeros(Float32, p))
      r = solve_en(X, y, scale, g, x; order, momentum, seed = 7)
      check!((:scale64, f1, c2, kind, order, momentum), X, y, scale, g, x, r, β, Float32)
    end
  end
end

@testset "momentum: the default, false and true with random order, and cyclic order with true" begin
  @test_throws ArgumentError CDSolver(order = :cyclic, momentum = true)
  n, p = 40, 10
  for T in FLOATS, kind in (:dense, :empty), momentum in (nothing, false, true)
    X, y = design(T, n, p, 13)
    λ1, λ2 = levels(T, X, y, nothing, 0.1, 0.3)
    β, ok = reference(X, y, 1, λ1, λ2)
    @test ok
    g = ElasticNet(λ1, λ2)
    for seed in (1, 2, 3)
      x = startof(kind, zeros(T, p))
      r = solve_en(X, y, nothing, g, x; order = :random, momentum, seed)
      check!((T, kind, momentum, seed), X, y, nothing, g, x, r, β, T)
    end
  end
end

@testset "ElasticNet(λ, 0) gives the run of NormL1(λ) bit for bit, also with flat columns" begin
  n, p = 40, 10
  for T in FLOATS, scale in (nothing, one(T) / T(n)), flat in (false, true), frac in (0.0, 0.1, 0.3),
      kind in (:dense, :empty), (order, momentum) in CONFIGS
    X, y = design(T, n, p, 12)
    flat && (X[:, 4] .= 0)
    λ = T(frac * lambdamax(X, y, alpha_of(scale)))
    f = lossof(scale, y, X)
    solver() = CDSolver(; order, momentum, tol = cdtol(T), maxpasses = 400, rng = Xoshiro(5))
    xa, xb = startof(kind, zeros(T, p)), startof(kind, zeros(T, p))
    ra, rb = quiet() do
      solve!(xa, f, NormL1(λ), solver()), solve!(xb, f, ElasticNet(λ, zero(T)), solver())
    end
    label = (T, scale, flat, frac, kind, order, momentum)
    @test (label, isequal(Vector(xa), Vector(xb))) == (label, true)
    @test (label, isequal(ra.minimum, rb.minimum)) == (label, true)
    @test (label, ra.passes, ra.converged, isequal(ra.maxchange, rb.maxchange)) == (label, rb.passes, rb.converged, true)
  end
end

@testset "ridge: λ1 = 0 against (α XᵀX + λ2 I) b = α Xᵀy, also with more columns than rows" begin
  for T in FLOATS, scale in scales(T, 40), (n, p) in ((40, 10), (5, 8)), c2 in (0.01, 1.0, 100.0), kind in (:dense, :empty)
    X, y = design(T, n, p, 21)
    α = alpha_of(scale)
    _, λ2 = levels(T, X, y, scale, 0.0, c2)
    β = normal_equations(X, y, α, λ2)
    g = ElasticNet(zero(T), λ2)
    for (order, momentum) in CONFIGS[[1, 3, 5]]
      x = startof(kind, zeros(T, p))
      r = solve_en(X, y, scale, g, x; order, momentum, seed = 3)
      check!((T, scale, n, p, c2, kind, order, momentum), X, y, scale, g, x, r, β, T; slack = n < p ? 10 : 1)
    end
  end
end

@testset "λ1 = λ2 = 0 is least squares on a full-rank design" begin
  n, p = 40, 10
  for T in FLOATS, scale in scales(T, n), kind in (:dense, :empty), (order, momentum) in CONFIGS[[1, 3]]
    X, y = design(T, n, p, 31)
    β = normal_equations(X, y, alpha_of(scale), 0)
    g = ElasticNet(zero(T), zero(T))
    x = startof(kind, zeros(T, p))
    r = solve_en(X, y, scale, g, x; order, momentum, seed = 4)
    check!((T, scale, kind, order, momentum), X, y, scale, g, x, r, β, T)
  end
end

@testset "uncentered SqrNormL2 with normalized least squares" begin
  for T in FLOATS
    ordinary = design(T, 32, 8, 121)
    wide = design(T, 4, 8, 122)
    correlated_data = correlated(T, 32, 8, 123)
    Xflat, yflat = design(T, 32, 8, 124)
    Xflat[:, end] .= 0
    for (name, (X, y), λ) in ((:ordinary, ordinary, T(0.5)), (:wide, wide, T(0.5)),
                              (:correlated, correlated_data, T(0.5)), (:flat, (Xflat, yflat), T(0.5)),
                              (:unpenalized, ordinary, zero(T)), (:mixed, ordinary, 0.5))
      n, p = size(X)
      α = name === :mixed ? 1 / n : one(T) / T(n)
      f = α * LeastSquaresLoss(y, X)
      β = normal_equations(X, y, α, λ)
      for kind in (:dense, :warm)
        label = (T, name, kind)
        x0 = fill(T(0.3), p)
        x = startof(kind, x0)
        u = startof(kind, x0)
        method = CDSolver(order = :cyclic, momentum = false, tol = cdtol(T))
        r = solve!(x, f, SqrNormL2(λ), method)
        en = solve!(u, f, ElasticNet(zero(λ), λ), method)
        dx, nβ = distance(Vector(x), β)
        @test (label, r.converged && en.converged) == (label, true)
        @test (label, dx <= xbound(T) * nβ) == (label, true)
        @test (label, norm(Vector(x) - Vector(u), Inf) <= 2xbound(T) * nβ) == (label, true)
        check_result!(label, X, y, α, zero(λ), λ, x, r, T)
        name === :flat && @test iszero(x[p])
      end
    end
  end
end

@testset "SqrNormL2 validation and exceptional coordinate steps" begin
  for T in FLOATS
    @test_throws ArgumentError SqrNormL2(T(-1))
    @test_throws ArgumentError SqrNormL2(T(NaN))
    # The second column has positive subnormal curvature, and the first visit changes its coordinate.
    tiny = T === Float32 ? T(1e-20) : T(1e-155)
    X, y = T[1 0; 0 tiny; 0 0], T[2, tiny, 0]
    f = LeastSquaresLoss(y, X)
    flat = LeastSquaresLoss(y, T[1 0; 0 0; 0 0])
    union_center = SqrNormL2{T, Union{Nothing, Vector{T}}}(T(0.5), nothing)
    for kind in (:dense, :warm)
      x = startof(kind, T[0.5, 0])
      refused(ArgumentError, "requires an uncentered SqrNormL2", x, f, SqrNormL2(zero(T), zeros(T, 2)))
      refused(ArgumentError, "constructed as SqrNormL2(lambda)", x, f, union_center)
      refused(ArgumentError, "penalty lambda must be finite and nonnegative", x, f, SqrNormL2(T(Inf)))
      if T === Float32
        for λ in (1e-60, 1e40)
          refused(ArgumentError, "penalty lambda is not representable", x, f, SqrNormL2(λ))
        end
      end
      before = snap(x)
      method = CDSolver(order = :cyclic, momentum = false, relative = false, tol = cdtol(T))
      err, msg = failure(() -> solve!(x, f, SqrNormL2(T(0.5)), method))
      @test err isa ArgumentError && occursin("coordinate 2 is outside the normal range", msg)
      @test unchanged(snap(x), before)
      r = solve!(x, f, SqrNormL2(zero(T)), method)
      @test r.converged && Vector(x) == T[2, 1]
      r = solve!(x, flat, SqrNormL2(zero(T)), method)
      @test r.converged && iszero(x[2])
    end
  end
end

@testset "designs with a diagonal XᵀX against the closed form" begin
  for T in FLOATS, make in (orthogonal, diagonal), scale in scales(T, 8), (λ1, λ2) in ((0, 0), (0.5, 0), (0, 0.7), (0.5, 0.7), (3, 1)),
      kind in (:dense, :empty), order in (:cyclic, :random)
    X, y = make(T, 17)
    α = alpha_of(scale)
    β, cmax = analytic(X, y, α, T(λ1), T(λ2))
    p = size(X, 2)
    g = ElasticNet(T(λ1), T(λ2))
    x = startof(kind, zeros(T, p))
    r = solve_en(X, y, scale, g, x; order, momentum = false, seed = 9)
    label = (T, make, scale, λ1, λ2, kind, order)
    xv = Vector(x)
    dx, nβ = distance(xv, β)
    # a coordinate step is exact for such a design, so the error is that of a few roundings of the step
    @test (label, r.converged) == (label, true)
    @test (label, dx <= 100 * Float64(eps(T)) * (nβ + cmax)) == (label, true)
    @test (label, all(iszero, xv[iszero.(β)])) == (label, true)
    check_result!(label, X, y, α, T(λ1), T(λ2), x, r, T)
  end
end

@testset "correlated design, and warm starts from another point and from a previous solution" begin
  n, p = 40, 8
  for T in FLOATS, scale in (nothing, one(T) / T(n))
    X, y = correlated(T, n, p, 41)
    α = alpha_of(scale)
    pairs = ((0.05, 0.05), (0.1, 0.5), (0.0, 0.2), (0.3, 0.0))
    refs = map(pairs) do (f1, c2)
      λ1, λ2 = levels(T, X, y, scale, f1, c2)
      β, ok = reference(X, y, α, λ1, λ2)
      @test (T, scale, f1, c2, ok) == (T, scale, f1, c2, true)
      (ElasticNet(λ1, λ2), β, ok)
    end
    for kind in (:dense, :warm)
      # a path of warm starts: the previous solution is the start of the next level, in the same iterate
      x = startof(kind, zeros(T, p))
      for (i, (g, β, ok)) in enumerate(refs)
        ok || continue
        r = solve_en(X, y, scale, g, x; order = :cyclic, momentum = false)
        check!((T, scale, kind, :path, i), X, y, scale, g, x, r, β, T)
      end
      # a start that is not a solution of anything, with signs against the solution
      for (i, (g, β, ok)) in enumerate(refs)
        ok || continue
        x0 = T.(-3 .* sign.(Float64.(β)) .+ 0.5)
        x = startof(kind, x0)
        r = solve_en(X, y, scale, g, x; order = :random, seed = i)
        check!((T, scale, kind, :start, i), X, y, scale, g, x, r, β, T)
      end
    end
  end
end

@testset "a SparseIterate with active zeros as the start, and Float64 levels on Float32 data" begin
  n, p = 40, 10
  for T in FLOATS
    X, y = design(T, n, p, 51)
    λ1, λ2 = levels(T, X, y, nothing, 0.1, 0.2)
    β, ok = reference(X, y, 1, λ1, λ2)
    @test ok
    g = ElasticNet(λ1, λ2)
    for order in (:cyclic, :random)
      x = owner(T, p, [7, 2, 5, 1, 9], T[0.4, 0, -0.2, 0, 3])
      r = solve_en(X, y, nothing, g, x; order, momentum = false, seed = 6)
      check!((T, :zeros, order), X, y, nothing, g, x, r, β, T)
    end
    if T === Float32
      g64 = ElasticNet(Float64(λ1), Float64(λ2))
      x = startof(:dense, zeros(T, p))
      r = solve_en(X, y, nothing, g64, x)
      check!((T, :levels64), X, y, nothing, g64, x, r, β, T)
    end
  end
end

@testset "flat columns: the coordinate ends at 0 at each level combination" begin
  n, p = 40, 10
  for T in FLOATS, k in (1, 4, 10), kind in (:dense, :warm), order in (:cyclic, :random),
      (f1, c2) in ((0.0, 0.0), (0.1, 0.0), (0.0, 0.5), (0.1, 0.5))
    X, y = design(T, n, p, 61)
    λ1, λ2 = levels(T, X, y, nothing, f1, c2)
    X[:, k] .= 0
    keep = setdiff(1:p, k)
    βr, ok = reference(X[:, keep], y, 1, λ1, λ2)
    @test (T, k, f1, c2, ok) == (T, k, f1, c2, true)
    ok || continue
    β = zeros(BigFloat, p)
    β[keep] .= βr
    x = startof(kind, fill(T(0.7), p))
    g = ElasticNet(λ1, λ2)
    r = solve_en(X, y, nothing, g, x; order, momentum = false, seed = 8)
    label = (T, k, kind, order, f1, c2)
    @test (label, is_zero(Vector(x)[k], T)) == (label, true)
    check!(label, X, y, nothing, g, x, r, β, T)
  end
end

# the iterate and its starting values of the refusals below
function refusal_problem(::Type{T}; bad) where T
  X, y = design(T, 20, 4, 71)
  bad(X)
  X, y
end

@testset "a nonflat column whose curvature underflows is refused with the existing message, x unchanged" begin
  for T in FLOATS, g in (ElasticNet(T(0.1), T(0.5)), ElasticNet(T(0.1), zero(T)), ElasticNet(zero(T), T(0.5)))
    tiny = T === Float32 ? T(1e-30) : T(1e-170)
    for k in (1, 4), kind in (:dense, :warm)
      X, y = refusal_problem(T; bad = X -> (X[:, k] .= tiny .* sign.(X[:, k])))
      x = startof(kind, fill(T(0.3), 4))
      refused(ArgumentError, "the coordinate curvature underflows", x, LeastSquaresLoss(y, X), g; rng_unchanged = false)
    end
  end
end

@testset "a column with s ‖X_k‖² or its reciprocal below floatmin" begin
  for T in FLOATS
    # small: ‖X_k‖² subnormal for s = 1; large: ‖X_k‖² finite and s ‖X_k‖² overflows
    small = T === Float32 ? T(1e-20) : T(1e-155)
    large, s = T === Float32 ? (T(1e16), T(1e6)) : (T(1e150), T(1e10))
    for (name, scale, col) in (("small", nothing, small), ("large", s, large)), λ1 in (zero(T), T(0.1))
      X, y = design(T, 20, 4, 81)
      X[:, 3] .= col .* X[:, 3]
      # with λ2 = 0 the run is that of NormL1(λ1), bit for bit
      for kind in (:dense, :empty), order in (:cyclic, :random), momentum in (false, nothing)
        label = (T, name, λ1, kind, order, momentum)
        xa, xb = startof(kind, zeros(T, 4)), startof(kind, zeros(T, 4))
        ra, rb = quiet() do
          solve_en(X, y, scale, NormL1(λ1), xa; order, momentum, seed = 2, tol = 1e-6, maxpasses = 2000),
          solve_en(X, y, scale, ElasticNet(λ1, zero(T)), xb; order, momentum, seed = 2, tol = 1e-6, maxpasses = 2000)
        end
        @test (label, isequal(Vector(xa), Vector(xb))) == (label, true)
        @test (label, ra.passes, ra.converged, isequal(ra.maxchange, rb.maxchange)) == (label, rb.passes, rb.converged, true)
        @test (label, isequal(ra.minimum, rb.minimum)) == (label, true)
      end
      # with λ2 > 0 the step has no range-safe form: refused during the pass, x unchanged
      for g in (ElasticNet(λ1, T(0.5)), ElasticNet(λ1, floatmin(T))), kind in (:dense, :warm), order in (:cyclic, :random)
        x = startof(kind, fill(T(0.3), 4))
        before = snap(x)
        err, text = failure(() -> solve_en(X, y, scale, g, x; order, momentum = false, seed = 2))
        label = (T, name, λ1, g.λ2, kind, order)
        @test (label, err isa ArgumentError) == (label, true)
        @test (label, occursin("the coordinate step of coordinate 3 is outside the normal range of $T", text)) == (label, true)
        @test (label, occursin("ElasticNet with lambda2 > 0 has no range-safe step there", text)) == (label, true)
        @test (label, unchanged(snap(x), before)) == (label, true)
      end
    end
  end
end

@testset "rollback: a refusal in a later coordinate leaves the iterate unchanged after earlier ones moved" begin
  for T in FLOATS, kind in (:dense, :warm)
    X, y = design(T, 20, 4, 91)
    small = T === Float32 ? T(1e-20) : T(1e-155)
    X[:, 4] .= small .* X[:, 4]
    g = ElasticNet(T(0.01), T(0.5))
    x = startof(kind, fill(T(0.3), 4))
    before = snap(x)
    err, text = failure(() -> solve_en(X, y, nothing, g, x; order = :cyclic, momentum = false))
    @test err isa ArgumentError && occursin("coordinate 4", text)
    @test unchanged(snap(x), before)
    # the same problem without the column that is refused solves, and moves the iterate
    r = solve_en(X[:, 1:3], y, nothing, g, startof(kind, fill(T(0.3), 3)); order = :cyclic, momentum = false)
    @test r.converged
  end
end

@testset "extreme levels and scales that stay in range" begin
  n, p = 40, 10
  for T in FLOATS
    # data scaled by 1e15: in the normal range of both types, and the solution scales by 1e-15
    for kind in (:dense, :empty), order in (:cyclic, :random)
      X, y = design(T, n, p, 101)
      X .*= T(1e15)
      λ1, λ2 = levels(T, X, y, nothing, 0.1, 0.3)
      β, ok = reference(X, y, 1, λ1, λ2)
      @test (T, :scaled_data, ok) == (T, :scaled_data, true)
      ok || continue
      g = ElasticNet(λ1, λ2)
      x = startof(kind, zeros(T, p))
      r = solve_en(X, y, nothing, g, x; order, momentum = false, seed = 5)
      check!((T, :scaled_data, kind, order), X, y, nothing, g, x, r, β, T)
    end
    # a ridge level that dominates, up to floatmax(T) / 4
    X, y = design(T, n, p, 102)
    for λ2 in T[1e6, 1e12, floatmax(T) / 4], kind in (:dense, :empty)
      β = normal_equations(X, y, 1, λ2)
      g = ElasticNet(zero(T), λ2)
      x = startof(kind, zeros(T, p))
      r = solve_en(X, y, nothing, g, x; order = :cyclic)
      @test (T, λ2, kind, r.converged, all(isfinite, Vector(x))) == (T, λ2, kind, true, true)
      dx, nβ = distance(Vector(x), β)
      @test (T, λ2, kind, dx <= xbound(T) * nβ) == (T, λ2, kind, true)
    end
    # ... with an l1 level of the same size: the coordinates end at 0
    for kind in (:dense, :empty)
      g = ElasticNet(floatmax(T) / 4, floatmax(T) / 4)
      x = startof(kind, fill(T(0.5), p))
      r = solve_en(X, y, nothing, g, x; order = :cyclic)
      @test Vector(x) == zeros(T, p) && r.converged
    end
  end
end

@testset "penalties and iterates that are refused before any write or RNG draw" begin
  for T in FLOATS
    X, y = T[1 0; 0 2; 1 1], T[1, -1, 0.5]
    f = LeastSquaresLoss(y, X)
    en = ElasticNet(T(0.1), T(0.2))
    shared = "CDSolver supports NormL1, unweighted ElasticNet, and uncentered SqrNormL2"
    for kind in (:dense, :warm)
      x0 = T[0.3, -0.2]
      for g in (ElasticNet(T(0.1), T(0.2), ones(T, 2)), ElasticNet(T(0.1), T(0.2), zeros(T, 2)), Scaled(en, 2),
                Scaled(NormL1(T(0.1), ones(T, 2)), 2), Scaled(SqrNormL2(T(0.1)), 2))
        refused(ArgumentError, shared, startof(kind, x0), f, g)
      end
      refused(ArgumentError, "penalty lambda1 must be finite and nonnegative", startof(kind, x0), f, ElasticNet(T(Inf), zero(T)))
      refused(ArgumentError, "penalty lambda2 must be finite and nonnegative", startof(kind, x0), f, ElasticNet(zero(T), T(Inf)))
      refused(DimensionMismatch, "x/y dimensions do not match X", startof(kind, zeros(T, 3)), f, en)
    end
    if T === Float32
      for a in (1e40, 1e-60), kind in (:dense, :warm)
        refused(ArgumentError, "penalty lambda1 is not representable without overflow or underflow in Float32",
                startof(kind, T[0.3, -0.2]), f, ElasticNet(a, 0.1))
        refused(ArgumentError, "penalty lambda2 is not representable without overflow or underflow in Float32",
                startof(kind, T[0.3, -0.2]), f, ElasticNet(0.1, a))
      end
    end
    @test_throws ArgumentError ElasticNet(NaN, 0.1)
    @test_throws ArgumentError ElasticNet(0.1, NaN)
    @test_throws ArgumentError ElasticNet(-0.1, 0.1)
    refused(ArgumentError, "x must be a dense Vector{Float32} or Vector{Float64}", Int[0, 0], f, en)
    # x aliases y or X
    ys = T[1, 2, 3]
    refused(ArgumentError, "must not alias", ys, LeastSquaresLoss(ys, T[1 0 1; 0 2 1; 1 1 0]), ElasticNet(T(0.1), T(0.2)))
    ax = T[0.5, -0.5]
    refused(ArgumentError, "must not alias", ax, LeastSquaresLoss(T[1], reshape(ax, 1, 2)), en)
  end
  # Float32 data with Float64 coefficients
  X32, y32 = Float32[1 0; 0 2; 1 1], Float32[1, -1, 0.5]
  refused(ArgumentError, "X must be Matrix{Float64}", [0.3, -0.2], LeastSquaresLoss(y32, X32), ElasticNet(0.1, 0.2))
end

@testset "maxpasses = 0 and a run that does not converge" begin
  n, p = 40, 10
  for T in FLOATS, kind in (:dense, :warm), order in (:cyclic, :random)
    X, y = design(T, n, p, 111)
    λ1, λ2 = levels(T, X, y, nothing, 0.1, 0.2)
    f = LeastSquaresLoss(y, X)
    x0 = fill(T(0.25), p)
    # maxpasses = 0 reports as the lasso does: no pass, not converged, the iterate unchanged
    ra, rb = nothing, nothing
    xa, xb = startof(kind, x0), startof(kind, x0)
    @test_logs (:warn, r"did not converge in maxpasses = 0") (:warn, r"did not converge in maxpasses = 0") begin
      ra = solve!(xa, f, NormL1(λ1), CDSolver(; order, maxpasses = 0, rng = Xoshiro(1)))
      rb = solve!(xb, f, ElasticNet(λ1, λ2), CDSolver(; order, maxpasses = 0, rng = Xoshiro(1)))
    end
    @test (ra.passes, ra.converged) == (rb.passes, rb.converged) == (0, false)
    @test isequal(Vector(xb), x0) && isequal(Vector(xa), x0)
    check_result!((T, kind, :maxpasses0), X, y, 1, λ1, λ2, xb, rb, T)
    # one pass from a distant start does not reach the tolerance
    X, y = correlated(T, n, p, 112)
    λ1, λ2 = levels(T, X, y, nothing, 0.05, 0.05)
    x = startof(kind, zeros(T, p))
    r = nothing
    @test_logs (:warn, r"did not converge") begin
      r = solve!(x, LeastSquaresLoss(y, X), ElasticNet(λ1, λ2), CDSolver(; order, maxpasses = 1, tol = cdtol(T), rng = Xoshiro(1)))
    end
    @test r.passes == 1 && !r.converged && r.minimizer === x
    check_result!((T, kind, :maxpasses1), X, y, 1, λ1, λ2, x, r, T)
  end
end

end
