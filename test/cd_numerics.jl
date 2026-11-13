module CDNumerics
# Coordinate descent and the supplied loss scale (#295). The scale of `Scaled(LeastSquaresLoss, α)`
# is used as supplied in the coordinate step, the two stopping scales and the reported objective,
# combined with the data type `T` by Julia's promotion where that gives a concrete AbstractFloat
# (Float32 data with a Float64 scale keeps the Float64 value). X, y, the residual and the iterate
# stay in `T`. Accuracy is checked in BigFloat from the raw data and the supplied scale.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
using Logging: with_logger, Warn
const PS = ProximalSolvers

# A Real that has no promotion rule with Float32 or Float64.
struct NoPromoScale <: Real
  v::Float64
end
Base.Float32(x::NoPromoScale) = Float32(x.v)
Base.Float64(x::NoPromoScale) = x.v

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# The result of f() and its log records. A run that reaches maxpasses logs one warning.
function logged(f)
  logger = Test.TestLogger()
  r = with_logger(f, logger)
  r, logger.logs
end
const NOTCONVERGED = r"coordinate descent did not converge in maxpasses"
only_warnings(logs) = all(l -> l.level == Warn && occursin(NOTCONVERGED, string(l.message)), logs)

# One CD solve of f + NormL1(λ) from x0, on a dense vector or on an owner, with its own seeded
# generator: everything the solve returns, the final owner state and the generator.
function cd_solve(f, λ, x0; order, momentum = nothing, owner = false, maxpasses = 2000, seed = 5, tol = 1e-7)
  solver = CDSolver(; order, momentum, maxpasses, tol, rng = Xoshiro(seed))
  x = owner ? SparseIterate(copy(x0)) : copy(x0)
  r, logs = logged(() -> solve!(x, f, NormL1(λ), solver))
  state = owner ? (collect(ProximalBase.activecoordinates(x)), collect(ProximalBase.activevalues(x))) : nothing
  (; x = Vector(x), state, minimum = r.minimum, passes = r.passes, converged = r.converged,
     maxchange = r.maxchange, tolerance = r.tolerance, rng = copy(solver.rng), logs)
end
# Equal under isequal (so -0.0 and 0.0 differ and a NaN equals itself) in x, the owner state, the
# minimum, the passes, the converged flag, maxchange and tolerance, and equal in the generator state.
same_run(a, b) =
  isequal((a.x, a.state, a.minimum, a.passes, a.converged, a.maxchange, a.tolerance),
          (b.x, b.state, b.minimum, b.passes, b.converged, b.maxchange, b.tolerance)) && a.rng == b.rng

# Entries of magnitude between 0.1 and 1, so that the squares of the data are far above the
# subnormal range of Float32 and a power-of-two rescaling of the data is exact.
function plain_data(::Type{T}, n, p; seed) where T
  rng = Xoshiro(seed)
  entries(m...) = (v = 2 .* rand(rng, m...) .- 1; T.(sign.(v) .* (0.1 .+ 0.9 .* abs.(v))))
  entries(n, p), entries(n)
end

# max_j |α (Xᵀy)_j| in BigFloat at 256 bits, as a Float64: the smallest penalty that gives x = 0.
lambda_max(X, y, α) = setprecision(BigFloat, 256) do
  Float64(maximum(abs, big(α) .* (big.(X)' * big.(y))))
end

# The KKT violation of x for α/2 ‖y - Xb‖² + λ‖b‖₁ computed in BigFloat from the data and the
# supplied α, and the scale max(λ, ‖d‖∞) with d = α Xᵀ(X x - y), as Float64. The accepted
# violation is max(1e-7, 100 eps(T)) times the scale, the form of test/core_regressions.jl.
function kkt_violation(X, y, α, λ, x)
  setprecision(BigFloat, 256) do
    Xb, yb, xb, ab, lb = big.(X), big.(y), big.(x), big(α), big(λ)
    d = ab .* (Xb' * (Xb * xb .- yb))
    v = maximum(j -> iszero(xb[j]) ? max(abs(d[j]) - lb, 0) : abs(d[j] + lb * sign(xb[j])), eachindex(xb))
    Float64(v), Float64(max(lb, maximum(abs, d)))
  end
end
kkt_tolerance(::Type{T}) where T = max(1e-7, 100eps(T))
# violation / (kkt_tolerance * scale): at most 1 is accepted
kkt_ratio(X, y, α, λ, x) = ((v, s) = kkt_violation(X, y, α, λ, x); v / (kkt_tolerance(eltype(x)) * s))

# The relative distance of the reported objective from F(x) = α/2 ‖y - Xx‖² + λ‖x‖₁ in BigFloat,
# against the scale α/2 ‖y‖² + λ‖x‖₁; at most (n + p) eps(T) is accepted. This is a fixture bound,
# not a derived one: the objective is formed from a cached residual with one rounding per update.
function objective_gap(X, y, α, λ, x, reported)
  setprecision(BigFloat, 256) do
    Xb, yb, xb, ab, lb = big.(X), big.(y), big.(x), big(α), big(λ)
    F = ab * sum(abs2, yb .- Xb * xb) / 2 + lb * sum(abs, xb)
    Float64(abs(big(reported) - F) / (ab * sum(abs2, yb) / 2 + lb * sum(abs, xb)))
  end
end
objective_bound(T, n, p) = (n + p) * eps(T)

# ---------------------------------------------------------------------------
# 1. Power-of-two invariance: the supplied scale, not its rounding to Float32, is used
# ---------------------------------------------------------------------------
# With c = 2^k, y and X scaled by c and α = α′ 2^(-2k) give α c² a = α′ a for the curvature a of a
# column and for the sums of squares of y and of the residual, and leave the coefficients and the
# penalty unchanged. Scaling by a power of two is exact in Float32 while no entry or sum leaves its
# normal range, which the data below keep, so Float32 data with the Float64 scale α′ 2^(-2k) must
# reproduce Float32 data with the Float64 scale α′ bit for bit in each solve below. α is subnormal in
# Float32 and Float32(α) != α, so a solver that rounds the scale to Float32 differs.
@testset "a power-of-two rescaling of the data and of the loss scale leaves CD unchanged (Float32 data, Float64 scale)" begin
  k = 50
  c = 2f0^k
  α′ = 0.3f0 * 2f0^-40
  α = Float64(α′) * 2.0^(-2k)
  @test issubnormal(Float32(α)) && Float32(α) != α && abs(α′) >= floatmin(Float32)
  for (n, p) in ((12, 8), (6, 10))
    X, y = plain_data(Float32, n, p; seed = 100n + p)
    # no Float32 sum of squares of the rescaled data comes near floatmax (without momentum CD does not
    # increase the objective, so in exact arithmetic ‖r‖ ≤ ‖y‖; the factor 64 leaves room for momentum
    # and rounding)
    @test 64 * n * Float64(c)^2 * max(maximum(abs2, X), maximum(abs2, y)) <= floatmax(Float32)
    cX, cy = c .* X, c .* y
    @test cX ./ c == X && cy ./ c == y
    lmax = lambda_max(X, y, α′)
    for (order, momentum) in ((:cyclic, nothing), (:random, nothing), (:random, false)),
        owner in (false, true), fraction in (0.0, 0.1, 1.5), warm in (false, true)
      x0 = warm ? Float32.(0.3 .* sin.(1:p)) : zeros(Float32, p)
      λ = Float32(fraction * lmax)
      a = cd_solve(α * LeastSquaresLoss(cy, cX), λ, x0; order, momentum, owner)
      b = cd_solve(Float64(α′) * LeastSquaresLoss(y, X), λ, x0; order, momentum, owner)
      @test same_run(a, b)
      @test only_warnings(a.logs) && only_warnings(b.logs)
      fraction < 1 && @test !all(iszero, a.x)
      fraction > 1 && !warm && @test all(iszero, a.x) && a.converged
    end
  end
end

# ---------------------------------------------------------------------------
# 2. Float32 data of magnitude 1e18 with the Float64 scale 1e-44 (Float32(α) is subnormal, -1.9%)
# ---------------------------------------------------------------------------
function r4_problem(; n = 24, p = 6, seed = 20277)
  rng = Xoshiro(seed)
  X0 = randn(rng, Float32, n, p)
  y0 = X0[:, 1] .+ 0.1f0 .* randn(rng, Float32, n)
  X, y = 1f18 .* X0, 1f18 .* y0
  # the sums of squares stay below floatmax(Float32)/4
  @assert 4 * max(maximum(sum(abs2, Float64.(X); dims = 1)), sum(abs2, Float64.(y))) < floatmax(Float32)
  X, y
end

@testset "Float32 data, Float64 scale 1e-44: CD solves the supplied scale, not Float32(α)" begin
  α = 1e-44
  @test issubnormal(Float32(α)) && Float32(α) != α
  X, y = r4_problem()
  n, p = size(X)
  lmax = lambda_max(X, y, α)
  for fraction in (0.1, 0.01), (order, momentum) in ((:cyclic, nothing), (:random, nothing)), owner in (false, true)
    λ = Float32(fraction * lmax)
    r = cd_solve(α * LeastSquaresLoss(y, X), λ, zeros(Float32, p); order, momentum, owner)
    @test r.converged && only_warnings(r.logs) && count(!iszero, r.x) >= 1
    # accurate for the supplied α, and not for the problem of Float32(α)
    @test kkt_ratio(X, y, α, λ, r.x) <= 1
    @test kkt_ratio(X, y, Float64(Float32(α)), λ, r.x) > 10
    @test objective_gap(X, y, α, λ, r.x, r.minimum) <= objective_bound(Float32, n, p)
    # checked at the larger penalty, where the residual and so the loss term, which Float32(α) changes
    # by about 2%, is a larger share of the scale
    fraction == 0.1 && @test objective_gap(X, y, Float64(Float32(α)), λ, r.x, r.minimum) > 10 * objective_bound(Float32, n, p)
  end
  # warm start
  λ = Float32(0.1 * lmax)
  r = cd_solve(α * LeastSquaresLoss(y, X), λ, Float32.(0.5 .* cos.(1:p)); order = :random)
  @test r.converged && kkt_ratio(X, y, α, λ, r.x) <= 1
end

# ---------------------------------------------------------------------------
# 3. Float64 data with a BigFloat scale whose Float64 value is subnormal and inexact
# ---------------------------------------------------------------------------
@testset "Float64 data, BigFloat scale with a subnormal Float64 value: CD solves the supplied scale" begin
  setprecision(BigFloat, 256) do
    α = BigFloat(3) * BigFloat(2)^-1074 * 1.3
    @test issubnormal(Float64(α)) && big(Float64(α)) != α
    @test PS._scale_type(Float64, α) === BigFloat
    c = 2.0^480
    X, y = plain_data(Float64, 8, 5; seed = 3)
    X, y = c .* X, c .* y
    n, p = size(X)
    @test 64 * n * max(maximum(abs2, X), maximum(abs2, y)) < floatmax(Float64)
    lmax = lambda_max(X, y, α)
    λ = 0.1 * lmax
    for (order, owner, x0) in ((:cyclic, false, zeros(p)), (:random, false, zeros(p)), (:random, true, 0.3 .* sin.(1:p)))
      r = cd_solve(α * LeastSquaresLoss(y, X), λ, x0; order, owner, tol = 1e-10)
      @test r.converged && only_warnings(r.logs) && count(!iszero, r.x) >= 1
      @test r.minimum isa Float64 && r.tolerance isa Float64 && r.maxchange isa Float64
      @test kkt_ratio(X, y, α, λ, r.x) <= 1
      @test kkt_ratio(X, y, big(Float64(α)), λ, r.x) > 10
      @test objective_gap(X, y, α, λ, r.x, r.minimum) <= objective_bound(Float64, n, p)
    end
  end
end

# ---------------------------------------------------------------------------
# 4. Unchanged same-type contract
# ---------------------------------------------------------------------------
# A scale whose promotion with T is T keeps the scale T(α), as before: the same model value
# and the same solve, bit for bit, as the scale T(α) itself. This includes a Float32 scale on
# Float64 data.
@testset "a scale that promotes to T is T(α) and solves as Scaled(f, T(α))" begin
  for T in (Float32, Float64)
    X, y = plain_data(T, 14, 6; seed = 41)
    f = LeastSquaresLoss(y, X)
    scales = Any[T(0.3), 2, true, 1 // 3, π, Float16(0.3)]
    T === Float64 && push!(scales, 0.1f0)
    for α in scales
      @test PS._scale_type(T, α) === T
      m = PS.cdmodel(Scaled(f, α), SparseIterate(zeros(T, 6)))
      @test m.s isa T && m.s === T(α)
      λ = T(0.2 * lambda_max(X, y, T(α)))
      for (order, owner) in ((:cyclic, false), (:random, true)), x0 in (zeros(T, 6), T.(0.2 .* cos.(1:6)))
        a = cd_solve(Scaled(f, α), λ, x0; order, owner)
        b = cd_solve(Scaled(f, T(α)), λ, x0; order, owner)
        @test same_run(a, b) && !all(iszero, a.x)
        @test only_warnings(a.logs) && only_warnings(b.logs)
      end
    end
    # the unscaled loss keeps one(T)
    @test PS.cdmodel(f, SparseIterate(zeros(T, 6))).s === one(T)
  end
end

@testset "the scale type: the promotion of T and the scale if a concrete AbstractFloat, else T" begin
  @test PS._scale_type(Float32, 1e-44) === Float64
  @test PS._scale_type(Float32, 0.25f0) === Float32
  @test PS._scale_type(Float64, 0.1f0) === Float64
  for α in (2, 1 // 4, π, Float16(0.5), true)
    @test PS._scale_type(Float32, α) === Float32 && PS._scale_type(Float64, α) === Float64
  end
  for T in (Float32, Float64), α in (big"1e-320", big(3), big(1) // 3)
    @test PS._scale_type(T, α) === BigFloat
  end
  @test PS._scale_type(Float32, NoPromoScale(0.25)) === Float32
  @test PS._scale_type(Float64, NoPromoScale(0.25)) === Float64
  X, y = plain_data(Float32, 5, 3; seed = 8)
  @test PS.LSModel(y, X, 1e-44).s === 1e-44
  @test PS.LSModel(y, X, 1e-44) isa PS.LSModel{Float32, Float64}
  @test PS.LSModel(y, X, NoPromoScale(0.25)).s === 0.25f0
  @test PS.LSModel(y, X, 0.1).s === 0.1
  @test PS.LSModel(y, X, 1 // 3).s === Float32(1 // 3)
  @test PS.LSModel(Float64.(y), Float64.(X), 0.1f0).s === Float64(0.1f0)
end

# ---------------------------------------------------------------------------
# 5. A high penalty and a response below the range of a Float32 scale
# ---------------------------------------------------------------------------
# Float32 y of magnitude 1e-17 with the scale 1e-44: Σy² α is 1e-77 in Float64, below Float32's
# range, so the response scale is 0 and the tolerance is the absolute one. Rounding the root
# instead would leave the Float32 subnormal 3.2e-39, whose product with 1f-7 rounds to 0, and
# no pass would then be below the tolerance.
@testset "a tiny response with a small scale converges in one pass on the absolute tolerance" begin
  rng = Xoshiro(17)
  X = Float32.(randn(rng, 10, 4))
  y = 1f-17 .* Float32.(1 .+ rand(rng, 10))
  α = 1e-44
  @test α * sum(abs2, Float64.(y)) < 1e-70 && Float32(α * sum(abs2, Float64.(y))) == 0
  m = PS.cdmodel(α * LeastSquaresLoss(y, X), SparseIterate(zeros(Float32, 4)))
  @test PS.response_scale(m, nothing) === 0f0
  for λ in (0f0, 1f-30), order in (:cyclic, :random), owner in (false, true)
    r = cd_solve(α * LeastSquaresLoss(y, X), λ, zeros(Float32, 4); order, owner, maxpasses = 50)
    @test r.converged && r.passes == 1 && r.tolerance === 1f-7 && isempty(r.logs)
  end
end

# ---------------------------------------------------------------------------
# 6. Result types, inference and allocation of the mixed model
# ---------------------------------------------------------------------------
function mixed_model(α)
  X, y = r4_problem()
  x = SparseIterate(zeros(Float32, size(X, 2)))
  m = PS.cdmodel(α * LeastSquaresLoss(y, X), x)
  PS.initialize!(m, x)
  X, y, m, x
end

alloc_step(m, g, x, k) = @allocated PS.coordinate_step!(m, g, x, k)
alloc_visit(m, g, x, k, scaled) = @allocated PS._visit!(m, g, x, k, scaled)
alloc_value(m, x) = @allocated PS.loss_value(m, x)
alloc_response(m, x) = @allocated PS.response_scale(m, x)
alloc_coordinate(m, x, k) = @allocated PS.coordinate_scale(m, x, k)
alloc_solve(x, f, g, solver) = @allocated solve!(x, f, g, solver)

@testset "the three result boundaries return T and use the supplied scale" begin
  for α in (1e-44, 1e-41)
    X, y, m, x = mixed_model(α)
    n, p = size(X)
    @test m isa PS.LSModel{Float32, Float64} && m.s === α
    g = NormL1(Float32(0.1 * lambda_max(X, y, α)))
    setprecision(BigFloat, 256) do
      Xb, yb, ab = big.(X), big.(y), big(α)
      @test PS.response_scale(m, x) isa Float32
      @test PS.response_scale(m, x) ≈ sqrt(ab * sum(abs2, yb)) rtol = (n + 4) * eps(Float32)
      @test PS.loss_value(m, x) isa Float32
      @test PS.loss_value(m, x) ≈ ab * sum(abs2, yb) / 2 rtol = (n + 4) * eps(Float32)
      for k in 1:p
        PS.coordinate_step!(m, g, x, k)
        @test PS.coordinate_scale(m, x, k) isa Float32
        @test PS.coordinate_scale(m, x, k) ≈ sqrt(ab * sum(abs2, Xb[:, k])) rtol = (n + 4) * eps(Float32)
      end
      xb = big.(Vector(x))
      @test PS.loss_value(m, x) ≈ ab * sum(abs2, yb .- Xb * xb) / 2 rtol = 100eps(Float32)
    end
  end
end

@testset "the mixed model is inferred and allocates nothing in its steps" begin
  X, y, m, x = mixed_model(1e-44)
  g = NormL1(Float32(0.1 * lambda_max(X, y, 1e-44)))
  @test (@inferred PS.coordinate_step!(m, g, x, 1)) isa Float32
  @test (@inferred PS._visit!(m, g, x, 2, true)) isa Float32
  @test (@inferred PS._visit!(m, g, x, 3, false)) isa Float32
  @test (@inferred PS.loss_value(m, x)) isa Float32
  @test (@inferred PS.response_scale(m, x)) isa Float32
  @test (@inferred PS.coordinate_scale(m, x, 4)) isa Float32
  for k in 1:size(X, 2)    # warm the calls for each column
    alloc_step(m, g, x, k)
    alloc_visit(m, g, x, k, true)
  end
  alloc_value(m, x); alloc_response(m, x); alloc_coordinate(m, x, 1)
  @test all(k -> alloc_step(m, g, x, k) == 0, 1:size(X, 2))
  @test all(k -> alloc_visit(m, g, x, k, true) == 0, 1:size(X, 2))
  @test alloc_value(m, x) == 0 && alloc_response(m, x) == 0 && alloc_coordinate(m, x, 1) == 0
end

@testset "a warmed solve with a Float64 scale allocates as one with a Float32 scale" begin
  X, y = plain_data(Float32, 30, 8; seed = 12)
  g = NormL1(0.2f0 * Float32(lambda_max(X, y, 0.25f0)))
  for (order, momentum) in ((:cyclic, nothing), (:random, false))
    solver = CDSolver(; order, momentum, rng = Xoshiro(3))
    mixed, same = 0.25 * LeastSquaresLoss(y, X), 0.25f0 * LeastSquaresLoss(y, X)
    for f in (mixed, same)
      alloc_solve(zeros(Float32, 8), f, g, solver)
    end
    @test alloc_solve(zeros(Float32, 8), mixed, g, solver) == alloc_solve(zeros(Float32, 8), same, g, solver)
  end
end

end
