module CDNumerics
# Coordinate descent and the supplied loss scale (#295). The scale of `Scaled(LeastSquaresLoss, α)`
# is used as supplied in the coordinate step, the two stopping scales and the reported objective,
# combined with the data type `T` by Julia's promotion where that gives a concrete AbstractFloat
# (Float32 data with a Float64 scale keeps the Float64 value). X, y, the residual and the iterate
# stay in `T`. Accuracy is checked in BigFloat from the raw data and the supplied scale.
# The response scale `√α‖y‖` of the relative stopping rule is formed range-safely (#293): the cases
# below fix it where `Σy²` or `α Σy²` overflows or underflows, and where `√α‖y‖` is not a normal
# number of `T`.
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

# max_j |α (Xᵀy)_j| in BigFloat at 256 bits, rounded to a Float64: an approximation to the
# penalty above which x = 0 is the solution (the final rounding to nearest can be below it).
lambda_max(X, y, α) = setprecision(BigFloat, 256) do
  Float64(maximum(abs, big(α) .* (big.(X)' * big.(y))))
end

# The KKT violation of x for α/2 ‖y - Xb‖² + λ‖b‖₁ computed in BigFloat from the data and the
# supplied α, with d = α Xᵀ(X x - y) and e = α Xᵀy: the violation, ‖d‖∞ and ‖e‖∞ as Float64.
function kkt_terms(X, y, α, λ, x)
  setprecision(BigFloat, 256) do
    Xb, yb, xb, ab, lb = big.(X), big.(y), big.(x), big(α), big(λ)
    d = ab .* (Xb' * (Xb * xb .- yb))
    v = maximum(j -> iszero(xb[j]) ? max(abs(d[j]) - lb, 0) : abs(d[j] + lb * sign(xb[j])), eachindex(xb))
    Float64(v), Float64(maximum(abs, d)), Float64(maximum(abs, ab .* (Xb' * yb)))
  end
end
# The violation and the scale max(λ, ‖d‖∞). The accepted violation is max(1e-7, 100 eps(T)) times
# the scale, the form of test/core_regressions.jl.
kkt_violation(X, y, α, λ, x) = ((v, dmax, _) = kkt_terms(X, y, α, λ, x); (v, max(Float64(λ), dmax)))
kkt_tolerance(::Type{T}) where T = max(1e-7, 100eps(T))
# violation / (kkt_tolerance * scale): at most 1 is accepted
kkt_ratio(X, y, α, λ, x) = ((v, s) = kkt_violation(X, y, α, λ, x); v / (kkt_tolerance(eltype(x)) * s))
# The same with the scale max(λ, ‖α Xᵀy‖∞), which does not depend on x; the tests below call it
# with λ = 0 only. In exact arithmetic with λ = 0 the violation equals ‖d‖∞, the scale of
# `kkt_ratio`, so that ratio cannot measure the violation there.
kkt_ratio_response(X, y, α, λ, x) =
  ((v, _, e) = kkt_terms(X, y, α, λ, x); v / (kkt_tolerance(eltype(x)) * max(Float64(λ), e)))

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

# √α ‖y‖ in BigFloat at 256 bits from the data and the supplied scale (the value a response scale
# approximates; a BigFloat, so that it is range-safe).
true_scale(y, α) = setprecision(BigFloat, 256) do
  sqrt(big(α)) * sqrt(sum(abs2, big.(y)))
end

# The KKT violation of x for α/2 ‖y - Xb‖² + λ‖b‖₁ relative to max(λ, ‖α Xᵀy‖∞), as a Float64. The
# ratio is formed in BigFloat, so that it is not limited by the range of Float64: the violation and the
# scale can be far outside it. At most `kkt_tolerance` is accepted.
kkt_relative(X, y, α, λ, x) = setprecision(BigFloat, 256) do
  Xb, yb, xb, ab, lb = big.(X), big.(y), big.(x), big(α), big(λ)
  d = ab .* (Xb' * (Xb * xb .- yb))
  v = maximum(j -> iszero(xb[j]) ? max(abs(d[j]) - lb, 0) : abs(d[j] + lb * sign(xb[j])), eachindex(xb))
  Float64(v / max(lb, maximum(abs, ab .* (Xb' * yb))))
end

# A solve that is refused: it throws an ArgumentError whose message matches `pattern`, and the
# caller's x (a dense vector, or the active coordinates and values of an owner) is as it was. With
# `rng_unchanged` the generator is as it was too, which holds where the solve is refused before any pass.
# Returns the log records of the solve.
function check_refusal(f, g, x0; order, momentum = nothing, owner = false, pattern = r"response scale",
                       rng_unchanged = true, maxpasses = 50)
  rng = Xoshiro(5)
  solver = CDSolver(; order, momentum, maxpasses, rng)
  x = owner ? SparseIterate(copy(x0)) : copy(x0)
  snapshot() = owner ? (collect(ProximalBase.activecoordinates(x)), collect(ProximalBase.activevalues(x))) : copy(x)
  before, rng_before = snapshot(), copy(rng)
  err, logs = logged(() -> try
    solve!(x, f, g, solver)
    nothing
  catch e
    e
  end)
  @test err isa ArgumentError && occursin(pattern, err.msg)
  @test isequal(snapshot(), before)
  rng_unchanged && @test rng == rng_before
  logs
end

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
    # No Float32 sum of squares of the rescaled data comes near floatmax. Without momentum, and in
    # exact arithmetic, CD does not increase the objective F, and α′‖y - Xx‖²/2 ≤ F(x) ≤ F(x0), so
    # the residual of every iterate (in the units of the unscaled data) has
    # ‖y - Xx‖² ≤ ‖y - Xx0‖² + 2λ‖x0‖₁/α′; for a zero start this is ‖y‖². The margin of 64 below
    # (for rounding) is checked for each start and penalty with that bound. It does not cover the
    # momentum runs, whose extrapolated points need not decrease F: there an overflow in the
    # rescaled run would make it differ from the unscaled run and fail `same_run`.
    @test 64 * Float64(c)^2 * max(sum(abs2, Float64.(y)), maximum(sum(abs2, Float64.(X); dims = 1))) <= floatmax(Float32)
    cX, cy = c .* X, c .* y
    @test cX ./ c == X && cy ./ c == y
    lmax = lambda_max(X, y, α′)
    for (order, momentum) in ((:cyclic, nothing), (:random, nothing), (:random, false)),
        owner in (false, true), fraction in (0.0, 0.1, 1.5), warm in (false, true)
      x0 = warm ? Float32.(0.3 .* sin.(1:p)) : zeros(Float32, p)
      λ = Float32(fraction * lmax)
      resid2 = sum(abs2, Float64.(y) .- Float64.(X) * Float64.(x0)) + 2 * Float64(λ) * sum(abs, Float64.(x0)) / Float64(α′)
      @test 64 * Float64(c)^2 * resid2 <= floatmax(Float32)
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
# 5. A response scale below the normal range of Float32 is refused
# ---------------------------------------------------------------------------
# Float32 y of magnitude about 1e-17 with the scale 1e-44: α Σy² is of order 1e-77 in Float64, below
# Float32's range, and its root, of order 3e-39, is subnormal in Float32. The response scale is then
# not a normal number of Float32, and CD refuses the solve before any pass, for a penalty of 0 and
# for one far above λmax: x, the owner state and the generator are as they were. The start is
# warm, so that a pass would change x. The assertions on `p` check these properties for the fixture.
# (With the response scale rounded to 0 the tolerance was the absolute 1e-7, and the first pass was
# accepted as converged also at the penalty 0, at a point that is not a solution.)
@testset "a response scale that is subnormal in Float32 is refused before any pass" begin
  rng = Xoshiro(17)
  X = Float32.(randn(rng, 10, 4))
  y = 1f-17 .* Float32.(1 .+ rand(rng, 10))
  α = 1e-44
  p = α * sum(abs2, Float64.(y))
  @test p < 1e-70 && Float32(p) == 0
  @test issubnormal(Float32(sqrt(p))) && 1f-7 * Float32(sqrt(p)) == 0
  @test 0 < true_scale(y, α) < floatmin(Float32)
  x0 = 0.3f0 .* Float32.(sin.(1:4))
  for λ in (0f0, 1f-30), order in (:cyclic, :random), owner in (false, true)
    check_refusal(α * LeastSquaresLoss(y, X), NormL1(λ), x0; order, owner)
  end
end

# ---------------------------------------------------------------------------
# 6. A coordinate scale below the range of a Float32 product
# ---------------------------------------------------------------------------
# The coordinate scale is the root of α a. With Float32 data and a Float64 scale, α a can round to
# 0 in Float32 (below nextfloat(0f0)/2) or to a subnormal, while its root is a normal Float32 of
# order 1e-23. With a scale of 0, `_visit!` counts the displacement of that coordinate as 0; if that
# holds for all coordinates, CD accepts the first pass as converged at a point that need not be a
# solution. A product that rounds to a subnormal can lose significant digits of the exact product.
# The Float32 data X below have two columns with a ≈ 0.063.
const COLUMN_CURVATURE = 0.063
boundary_problem() = (Float32[.251 .24; 0 .0735], Float32[1e8, 1e8], fill(.2f0, 2))

@testset "a coordinate scale is the root of the supplied scale times the curvature when that product underflows Float32" begin
  X, y, x0 = boundary_problem()
  @test all(k -> abs(sum(abs2, Float64.(X[:, k])) - COLUMN_CURVATURE) < 1e-4, 1:2)
  nf = Float64(nextfloat(0f0))
  # α a: 0.9 and 1.1 times nextfloat(0f0)/2 (the first rounds to 0 in Float32, the second to
  # nextfloat(0f0)) and 0.9 and 1.1 times floatmin(Float32) (subnormal, normal)
  for (label, target) in (("below half the smallest subnormal", 0.9 * nf / 2), ("above half the smallest subnormal", 1.1 * nf / 2),
                          ("below floatmin", 0.9 * Float64(floatmin(Float32))), ("above floatmin", 1.1 * Float64(floatmin(Float32))))
    α = target / COLUMN_CURVATURE
    f = α * LeastSquaresLoss(y, X)
    m = PS.cdmodel(f, SparseIterate(zeros(Float32, 2)))
    @test m isa PS.LSModel{Float32, Float64}
    setprecision(BigFloat, 256) do
      for k in 1:2
        scale = PS.coordinate_scale(m, nothing, k)
        @test scale isa Float32 && scale > 0
        @test scale ≈ sqrt(big(α) * sum(abs2, big.(X[:, k]))) rtol = 2eps(Float32)
      end
    end
    for (order, momentum) in ((:cyclic, false), (:random, false)), owner in (false, true)
      r = cd_solve(f, 0f0, x0; order, momentum, owner)
      @test r.converged && only_warnings(r.logs) && r.passes > 1
      @test kkt_ratio_response(X, y, α, 0.0, r.x) <= 1
    end
  end
  # the reproduction of the review: both coordinate scales were 0 and the response scale was not
  α = 1.1e-44
  f = α * LeastSquaresLoss(y, X)
  m = PS.cdmodel(f, SparseIterate(zeros(Float32, 2)))
  @test Float32(α * sum(abs2, Float64.(X[:, 1]))) == 0 && PS.response_scale(m, nothing) > 0
  for (order, momentum) in ((:cyclic, false), (:random, false), (:random, nothing)), owner in (false, true)
    r = cd_solve(f, 0f0, x0; order, momentum, owner)
    @test r.converged && only_warnings(r.logs) && r.passes > 1
    @test kkt_ratio_response(X, y, α, 0.0, r.x) <= 1
  end
  # Float64 data and a BigFloat scale: a product below the range of Float64 with a root in it
  setprecision(BigFloat, 256) do
    Xd = Float64[1e-155 2e-155; 0 1e-155]
    β = big"1e-320"
    @test issubnormal(Float64(β)) && PS._scale_type(Float64, β) === BigFloat
    md = PS.cdmodel(β * LeastSquaresLoss(Float64[1e-150, 1e-150], Xd), SparseIterate(zeros(2)))
    for k in 1:2
      a = sum(abs2, Xd[:, k])
      @test Float64(β * a) == 0 && 0 < md.s * a
      scale = PS.coordinate_scale(md, nothing, k)
      @test scale isa Float64 && scale > 0
      # a subnormal result: accurate to half the spacing of the subnormals
      @test abs(big(scale) - sqrt(β * big(a))) <= big(nextfloat(0.0)) / 2 * (1 + big(2)^-100)
    end
  end
end

# ---------------------------------------------------------------------------
# 7. A response scale above the range of a Float32 product
# ---------------------------------------------------------------------------
# Float32 y whose sum of squares is exactly floatmax(Float32). With the Float64 scale α > 1, the
# product α Σy² is above floatmax(Float32), but its root is a finite Float32. An infinite response
# scale makes the tolerance infinite, and CD then accepts a first pass with a finite change, at a
# point that need not be a solution. With α = 1 + 2^-26 the Float32 rounding of α Σy² is
# floatmax(Float32); with α = 1 + 3 2^-26 it is Inf (Float32(α) == 1f0 in both).
@testset "a response scale is the root of the supplied scale times Σy² when that product overflows Float32" begin
  X = Float32[1 1; 0 1]
  y = Float32[2f0^52, prevfloat(2f0^64)]
  x0 = fill(.2f0, 2)
  syy = Float32(0)
  for yi in y
    syy += yi * yi
  end
  @test syy == floatmax(Float32)
  for (α, fits) in ((1 + 2.0^-26, true), (1 + 3 * 2.0^-26, false))
    @test Float32(α) == 1f0
    @test isfinite(Float32(α * Float64(syy))) == fits
    f = α * LeastSquaresLoss(y, X)
    m = PS.cdmodel(f, SparseIterate(zeros(Float32, 2)))
    scale = PS.response_scale(m, nothing)
    @test scale isa Float32 && isfinite(scale)
    @test scale ≈ sqrt(big(α) * big(Float64(syy))) rtol = 2eps(Float32)
    for (order, momentum) in ((:cyclic, false), (:random, false)), owner in (false, true)
      r = cd_solve(f, 0f0, x0; order, momentum, owner)
      @test r.converged && only_warnings(r.logs) && r.passes > 1
      @test isfinite(r.tolerance) && r.tolerance ≈ 1f-7 * scale
      @test kkt_ratio_response(X, y, α, 0.0, r.x) <= 1
    end
  end
end

# ---------------------------------------------------------------------------
# 8. An objective that rounds to Inf in Float32 is refused, and x is not changed
# ---------------------------------------------------------------------------
# The reported objective α Σr²/2 is formed in Float64 and rounded to Float32. The second row of X is
# 0, so its residual stays y₂, and the solution is x = 0 with Σr² = fl(y₂²). The two scales below put
# α Σr²/2 just below and just above floatmax(Float32) + 2^103, the Float64 value that is a tie
# between floatmax(Float32) and 2^128 and rounds to even, that is to Inf. Above it CD refuses the
# result with an ArgumentError and leaves x as it was; below it CD returns floatmax(Float32).
@testset "an objective that overflows Float32 is refused and x is unchanged" begin
  X = Float32[1; 0;;]
  y = Float32[0, 1.7f19]
  x0 = Float32[0.5]
  v = y[2] * y[2]
  @test isfinite(v)
  bound = 2 * (Float64(floatmax(Float32)) + 2.0^103) / Float64(v)
  below, above = bound * (1 - 2.0^-30), bound * (1 + 2.0^-30)
  @test Float32(below * Float64(v) / 2) == floatmax(Float32) && Float32(above * Float64(v) / 2) == Inf32
  g = NormL1(0f0)
  for order in (:cyclic, :random), owner in (false, true)
    solver() = CDSolver(; order, momentum = false, rng = Xoshiro(5))
    x = owner ? SparseIterate(copy(x0)) : copy(x0)
    snapshot() = owner ? (collect(ProximalBase.activecoordinates(x)), collect(ProximalBase.activevalues(x))) : copy(x)
    before = snapshot()
    @test_throws ArgumentError solve!(x, above * LeastSquaresLoss(y, X), g, solver())
    @test isequal(snapshot(), before)
    r = solve!(x, below * LeastSquaresLoss(y, X), g, solver())
    @test r.converged && r.minimum === floatmax(Float32) && Vector(x) == [0f0]
  end
end

# ---------------------------------------------------------------------------
# 9. Result types, inference and allocation of the mixed model
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

# ---------------------------------------------------------------------------
# 10. The response scale outside the range of T: CD does not stop after one pass (#293)
# ---------------------------------------------------------------------------
# The response scale √α‖y‖ multiplies the tolerance. It used to be 0 where Σy² or α Σy² underflowed
# (the tolerance became the absolute `tol`) and Inf where either overflowed (the tolerance became Inf);
# either way CD accepted the first pass as converged, with a KKT violation of order 0.1 to 1 of its
# scale. The scale is now formed with exponent-separated arithmetic where the product is not a normal
# number of T. Each case below solves a problem with such a response, at a penalty of 0 and of a fraction
# of λmax (0.1, or less where λ‖x‖₁ would then be too large for T), from a cold and a warm start, in the
# three orders (cyclic, random with the default momentum, random without momentum), on a dense vector
# and on an owner. Each solve converges after more than one pass,
# at a point whose KKT violation for the supplied scale is within the bound, and with a tolerance equal
# to tol times the BigFloat value of √α‖y‖. The data are one fixed problem (30 × 3 and a response near
# the column space) of a given response norm and column scale. For each fixture and penalty below,
# `check_feasible` asserts that the solution has a representable Σr² and objective and that each
# nonzero α a_k is a normal number of T, so that the cases do not test the coordinate scale or the
# reported objective (#294, and the R3 cases below).
const ORDERS = ((:cyclic, nothing), (:random, nothing), (:random, false))

# X (30 × 3, with a zero fourth column if asked) times `xscale`, y with the norm `target`, in T; and
# the factor of the coefficients of the unit problem.
function scaled_problem(::Type{T}, target; xscale = 1.0, zero_column = false) where T
  rng = Xoshiro(99)
  X = randn(rng, 30, 3) * [1 0.5 0.3; 0 1 0.5; 0 0 1]
  y = X * [1.0, -2.0, 0.5] .+ 0.01 .* randn(rng, 30)
  c = target / norm(y)
  zero_column && (X = hcat(X, zeros(30)))
  Matrix{T}(xscale .* X), Vector{T}(c .* y), c / xscale
end

# The minimizer of α/2 ‖y - Xb‖² + λ‖b‖₁ and its residual, by cyclic coordinate descent in BigFloat at 256
# bits from 0 (independent of the solver; a flat column stays at 0).
function reference_lasso(X, y, α, λ; passes = 150)
  setprecision(BigFloat, 256) do
    Xb, ab, lb = big.(X), big(α), big(λ)
    b, r = zeros(BigFloat, size(X, 2)), big.(y)
    a = [sum(abs2, Xb[:, k]) for k in axes(X, 2)]
    for _ in 1:passes, k in axes(X, 2)
      iszero(a[k]) && continue
      z = b[k] + sum(Xb[i, k] * r[i] for i in eachindex(r)) / a[k]
      t = lb / (ab * a[k])
      new = sign(z) * max(abs(z) - t, 0)
      r .-= Xb[:, k] .* (new - b[k])
      b[k] = new
    end
    b, r
  end
end

# The feasibility of a fixture that is expected to converge: at the reference solution Σr² and the
# objective α Σr²/2 + λ‖x‖₁ are below floatmax(T)/4, and every nonzero α a_k lies in
# [floatmin(T), floatmax(T)/4).
function check_feasible(X, y, α, λ)
  T = eltype(X)
  b, r = reference_lasso(X, y, α, λ)
  setprecision(BigFloat, 256) do
    ab, rss = big(α), sum(abs2, r)
    @assert rss < big(floatmax(T)) / 4 "Σr² at the solution is not below floatmax/4"
    @assert ab * rss / 2 + big(λ) * sum(abs, b) < big(floatmax(T)) / 4 "the objective at the solution is not below floatmax/4"
    for k in axes(X, 2)
      a = ab * sum(abs2, big.(X[:, k]))
      iszero(a) || @assert big(floatmin(T)) <= a < big(floatmax(T)) / 4 "α a_$k is outside [floatmin, floatmax/4)"
    end
  end
  nothing
end

function d1_case(label, ::Type{T}, target, α; xscale = 1.0, zero_column = false, fractions = (0.0, 0.1)) where T
  X, y, c = scaled_problem(T, target; xscale, zero_column)
  f = α === nothing ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)
  αo = α === nothing ? 1 : α
  (; label, X, y, α = αo, f, c, fractions, scale = true_scale(y, αo))
end

function d1_cases()
  [d1_case("Float64, Σy² overflows: α = 1e-300, ‖y‖ = 2e154", Float64, 2e154, 1e-300),
   d1_case("Float64, Σy² overflows: raw, ‖y‖ = 2e154", Float64, 2e154, nothing; fractions = (0.0, 0.01)),
   d1_case("Float64, control: α = 1e-300, ‖y‖ = 2e151", Float64, 2e151, 1e-300),
   d1_case("Float64, Σy² underflows: raw, ‖y‖ = 1e-165", Float64, 1e-165, nothing),
   d1_case("Float64, Σy² underflows: α = 1.0, ‖y‖ = 1e-165", Float64, 1e-165, 1.0),
   d1_case("Float64, α Σy² overflows: α = 1e300, ‖y‖ = 3e4", Float64, 3e4, 1e300; fractions = (0.0, 0.01)),
   d1_case("Float64, α Σy² underflows: α = 1e-300, ‖y‖ = 1e-10", Float64, 1e-10, 1e-300),
   d1_case("Float64, subnormal α = 1e-310, ‖y‖ = 1e-10", Float64, 1e-10, 1e-310; xscale = 100.0),
   d1_case("Float64, Σy² overflows, zero column", Float64, 2e154, 1e-300; zero_column = true),
   d1_case("Float64, Σy² underflows, zero column", Float64, 1e-165, nothing; zero_column = true),
   d1_case("Float32, Σy² overflows: α = 1f-30, ‖y‖ = 3e19", Float32, 3e19, 1f-30),
   d1_case("Float32, Σy² overflows: Float64 α = 1e-30, ‖y‖ = 3e19", Float32, 3e19, 1e-30),
   d1_case("Float32, Σy² overflows: raw, ‖y‖ = 3e19", Float32, 3e19, nothing; fractions = (0.0, 1e-3)),
   d1_case("Float32, Σy² underflows: α = 1f0, ‖y‖ = 1e-24", Float32, 1e-24, 1f0),
   d1_case("Float32, Σy² underflows: Float64 α = 1.0, ‖y‖ = 1e-24", Float32, 1e-24, 1.0),
   d1_case("Float32, Σy² underflows: raw, ‖y‖ = 1e-24", Float32, 1e-24, nothing),
   d1_case("Float32, Σy² overflows, zero column", Float32, 3e19, 1f-30; zero_column = true),
   d1_case("Float32, Σy² underflows, zero column", Float32, 1e-24, nothing; zero_column = true)]
end

# One solve of a case: converged without a warning, after more than one pass, with the KKT violation
# within the bound and the tolerance of the BigFloat response scale; a zero column stays 0. The Float64
# solves use tol = 1e-9, so that the KKT bound 1e-7 holds with a margin of about 100.
function check_d1_solve(c, λ, x0; order, momentum, owner)
  T = eltype(c.X)
  tol = T === Float64 ? 1e-9 : 1e-7
  r = cd_solve(c.f, λ, x0; order, momentum, owner, tol)
  @test r.converged && isempty(r.logs)
  @test r.passes > 1
  @test kkt_relative(c.X, c.y, c.α, λ, r.x) <= kkt_tolerance(T)
  @test isapprox(big(r.tolerance), big(T(tol)) * c.scale, rtol = (length(c.y) + 8) * eps(T))
  all(iszero, c.X[:, end]) && @test r.x[end] == 0
  r
end

@testset "CD converges where the response scale is outside the range of T: $(c.label)" for c in d1_cases()
  T = eltype(c.X)
  p = size(c.X, 2)
  lmax = lambda_max(c.X, c.y, c.α)
  @test c.scale > 0
  for fraction in c.fractions
    λ = T(fraction * lmax)
    check_feasible(c.X, c.y, c.α, λ)
    for x0 in (zeros(T, p), T.(c.c .* (0.3 .* sin.(1:p)))), (order, momentum) in ORDERS, owner in (false, true)
      check_d1_solve(c, λ, x0; order, momentum, owner)
    end
  end
end

# ---------------------------------------------------------------------------
# 11. A response scale that is not a normal number of T is refused before any pass
# ---------------------------------------------------------------------------
# √α‖y‖ above floatmax(T) or below floatmin(T) (a subnormal) is not representable at T's precision, so
# CD throws an ArgumentError that names the response scale before the first pass: x, the owner state and
# the generator are as they were (the start is warm, so that a pass would change x; the random orders
# draw from the generator in each pass). A y with a single subnormal entry is refused too. The columns
# (1, 1, 1, 1) and (1, -1, 1, -1) fit y = c (1, 1, 1, 1) with x = (c, 0), where c is a power of two
# or a subnormal, so that the sums of the entries of y and of their differences are exact in any order
# and the residual is 0 after the first column. The same problem with `relative = false` then runs: it
# converges, with the absolute tolerance 1e-7, and no product or sum in it overflows. (For the single
# subnormal entry the residual and the objective underflow.)
function refusal_problem(label, ::Type{T}, y, α, kind) where T
  X = hcat(ones(T, 4), T[1, -1, 1, -1])
  y = Vector{T}(y)
  t = true_scale(y, something(α, 1))
  kind === :over && @assert t > 1.001 * big(floatmax(T)) "√α‖y‖ is not above floatmax"
  kind === :under && @assert 0 < t < 0.999 * big(floatmin(T)) "√α‖y‖ is not in (0, floatmin)"
  (; label, T, X, y, f = α === nothing ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X))
end

function refusal_problems()
  e1 = [1.0, 0.0, 0.0, 0.0]
  [refusal_problem("Float64, √α‖y‖ ≈ 2e308: α = 100, y = 2^1020", Float64, fill(2.0^1020, 4), 100.0, :over),
   refusal_problem("Float64, √α‖y‖ ≈ 2e308: α = 1e300, y = 2^526", Float64, fill(2.0^526, 4), 1e300, :over),
   refusal_problem("Float32, √α‖y‖ ≈ 4e38: α = 400f0, y = 2^123", Float32, fill(2f0^123, 4), 400f0, :over),
   refusal_problem("Float32, √α‖y‖ ≈ 4e38: Float64 α = 400, y = 2^123", Float32, fill(2f0^123, 4), 400.0, :over),
   refusal_problem("Float32, √α‖y‖ ≈ 6e38: α = 1f30, y = 2^78", Float32, fill(2f0^78, 4), 1f30, :over),
   refusal_problem("Float64, √α‖y‖ ≈ 4e-310: α = 1e-220, y = 2^-664", Float64, fill(2.0^-664, 4), 1e-220, :under),
   refusal_problem("Float64, subnormal raw y = 1e-310", Float64, fill(1e-310, 4), nothing, :under),
   refusal_problem("Float64, one subnormal entry, raw", Float64, 1e-320 .* e1, nothing, :under),
   refusal_problem("Float64, one subnormal entry, α = 1.0", Float64, 1e-320 .* e1, 1.0, :under),
   refusal_problem("Float32, √α‖y‖ ≈ 2e-40: α = 1f-20, y = 2^-100", Float32, fill(2f0^-100, 4), 1f-20, :under),
   refusal_problem("Float32, √α‖y‖ ≈ 2e-40: Float64 α = 1e-20, y = 2^-100", Float32, fill(2f0^-100, 4), 1e-20, :under),
   refusal_problem("Float32, subnormal raw y = 1f-39", Float32, fill(1f-39, 4), nothing, :under),
   refusal_problem("Float32, one subnormal entry, raw", Float32, 1f-40 .* e1, nothing, :under),
   refusal_problem("Float32, one subnormal entry, Float64 α = 1.0", Float32, 1f-40 .* e1, 1.0, :under)]
end

@testset "a response scale that is not a normal number of T is refused: $(c.label)" for c in refusal_problems()
  T = c.T
  x0 = T[0.3, -0.2]
  for (order, momentum) in ORDERS, owner in (false, true)
    check_refusal(c.f, NormL1(zero(T)), x0; order, momentum, owner)
    check_refusal(c.f, NormL1(T(1e-3)), x0; order, momentum, owner)
    # relative = false runs the same problem
    solver = CDSolver(; order, momentum, relative = false, maxpasses = 50, rng = Xoshiro(5))
    x = owner ? SparseIterate(zeros(T, 2)) : zeros(T, 2)
    r, logs = logged(() -> solve!(x, c.f, NormL1(zero(T)), solver))
    @test r.converged && isempty(logs) && r.tolerance === T(1e-7)
  end
end

# ---------------------------------------------------------------------------
# 12. A zero response keeps the absolute tolerance
# ---------------------------------------------------------------------------
# For y = 0 the response scale is 0 and `_tolerances` uses the absolute `tol`. The solution is x = 0 at
# any penalty, and the solve starts from x0 of order 1. The KKT violation is absolute here (the response
# gives no scale); it is bounded by 100 kkt_tolerance times the gradient scale α ‖X‖²_F max(1, ‖x0‖∞)
# at the start.
@testset "y = 0: the absolute tolerance, converged at x = 0 ($T)" for T in (Float32, Float64)
  X, _ = plain_data(T, 12, 4; seed = 7)
  y = zeros(T, 12)
  x0 = T.(1 .+ 0.3 .* sin.(1:4))
  for α in (nothing, T(0.5), 2.0), λ in (0, 0.05), (order, momentum) in ORDERS, owner in (false, true)
    αo = something(α, 1)
    f = α === nothing ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)
    r = cd_solve(f, T(λ), x0; order, momentum, owner)
    @test r.converged && isempty(r.logs) && r.passes > 1
    @test r.tolerance === T(1e-7)
    v = kkt_terms(X, y, αo, λ, r.x)[1]
    @test v <= 100 * kkt_tolerance(T) * Float64(αo) * sum(abs2, Float64.(X)) * max(1, maximum(abs, x0))
  end
end

# ---------------------------------------------------------------------------
# 13. The response scale: values, tiers, inference and allocation
# ---------------------------------------------------------------------------
# y = y0 2^k and a scale 1.3 2^j (in Float32, Float64 or BigFloat) over magnitudes that take each of the
# three ways of forming the scale, for both types. The result is within (n + 8) eps(T) of the BigFloat
# value √α‖y‖, which is also what the model's stored scale gives. A refusal is required where √α‖y‖ is
# above floatmax(T) + 16 ulp or below floatmin(T) - 16 ulp; no refusal where it is inside both by 16 ulp;
# between, either a refusal or a normal number of T within the bound. Where the first way (the root of
# the rounded product) or the second (the root of the product in the wider scale type) applies, the
# result is the same bits as that formula. The calls are inferred, and for IEEE scales allocate
# nothing after warm-up.
const Y0 = [0.9, 0.55, 0.7, 1.0, 0.6, 0.8, 0.65]

# 1, 2 or 3: the way that `response_scale` forms the scale of m, from the definitions in the comment
# of `response_scale`.
function sumsq_loop(y)
  s = zero(eltype(y))
  for yi in y
    s += yi * yi
  end
  s
end
function scale_way(m::PS.LSModel{T}) where T
  s = sumsq_loop(m.y)
  p = m.s * s
  q = T(p)
  clean = isfinite(s) && s >= 4 * length(m.y) * floatmin(T)
  clean && floatmin(T) <= q <= floatmax(T) && return 1
  S = typeof(p)
  if clean && S !== T && floatmin(S) <= p <= floatmax(S)
    r = T(sqrt(p))
    floatmin(T) <= r <= floatmax(T) && return 2
  end
  3
end

function check_scale_point(T, y, α, ways)
  X = ones(T, length(y), 1)
  m = PS.LSModel(y, X, α)
  n = length(y)
  t = true_scale(y, m.s)
  band(x) = 16 * big(eps(x))
  below, above = t < big(floatmin(T)) - band(floatmin(T)), t > big(floatmax(T)) + band(floatmax(T))
  inside = big(floatmin(T)) + band(floatmin(T)) < t < big(floatmax(T)) - band(floatmax(T))
  res = try
    PS.response_scale(m, nothing)
  catch e
    e
  end
  if res isa ArgumentError
    @test occursin("response scale", res.msg)
    @test !inside
  else
    @test res isa T && floatmin(T) <= res <= floatmax(T)
    @test !(below || above)
    @test abs(big(res) - t) <= (n + 8) * eps(T) * t
    way = scale_way(m)
    way == 1 && @test res === sqrt(T(m.s * sumsq_loop(y)))
    way == 2 && @test res === T(sqrt(m.s * sumsq_loop(y)))
    push!(ways, way)
    if !(m.s isa BigFloat)
      @test (@inferred PS.response_scale(m, nothing)) === res
      alloc_response(m, nothing)
      @test alloc_response(m, nothing) == 0
    end
  end
  nothing
end

@testset "the response scale over the ranges of y and the loss scale ($T)" for T in (Float32, Float64)
  ks = T === Float32 ? (-145, -140, -100, -70, -40, -10, 0, 10, 40, 70, 100, 120, 125) :
                       (-1070, -1050, -700, -540, -300, -60, 0, 60, 300, 520, 540, 700, 1010, 1020)
  js = T === Float32 ? (-148, -140, -100, -60, -1, 0, 1, 60, 100, 126) :
                       (-1070, -1000, -600, -300, -1, 0, 1, 300, 600, 1000, 1020)
  ways = Set{Int}()
  for k in ks
    y = T.(ldexp.(Y0, k))
    for j in js
      check_scale_point(T, y, ldexp(T(1.3), j), ways)
    end
    if T === Float32     # a Float64 scale on Float32 data
      for j in (-148, -120, -60, -1, 0, 60, 120, 127)
        check_scale_point(T, y, ldexp(1.3, j), ways)
      end
    end
    setprecision(BigFloat, 256) do    # a BigFloat scale, also beyond the range of T
      for j in (-1500, -300, -1, 0, 1, 300, 1500)
        check_scale_point(T, y, big(1.3) * BigFloat(2)^j, ways)
      end
    end
  end
  @test ways == Set([1, 2, 3])
  # a zero response and a zero loss scale give 0, which selects the absolute tolerance
  X = ones(T, 4, 1)
  @test PS.response_scale(PS.LSModel(zeros(T, 4), X, 1.0), nothing) === zero(T)
  @test PS.response_scale(PS.LSModel(T[1, 2, 3, 4], X, 0.0), nothing) === zero(T)
  @test_throws ArgumentError PS.response_scale(PS.LSModel(T[1, Inf, 3, 4], X, 1.0), nothing)
end

# ---------------------------------------------------------------------------
# 14. R3, not changed here: the reported objective still forms Σr² in T
# ---------------------------------------------------------------------------
# The response scale does not limit these problems, but `loss_value` forms Σr² in T, so that CD does
# not report the objective where it is outside T's range. This is left to the ProximalBase
# cached-oracle migration (#277, R3). Where Σr² overflows at the solution (x = 0 at a penalty of 1.5 λmax,
# with Σr² = Σy²), the solve converges and is then refused with a nonfinite-objective error, and x is as
# it was. Where Σr² or α Σr² underflows at the solution, the solve converges and the reported minimum
# (λ = 0) is 0.
@testset "R3: Σr² that overflows at the solution refuses the finished solve, x is unchanged" begin
  for c in (d1_case("Float64, Σy² overflows: α = 1e-300, ‖y‖ = 2e154", Float64, 2e154, 1e-300),
            d1_case("Float32, Σy² overflows: α = 1f-30, ‖y‖ = 3e19", Float32, 3e19, 1f-30))
    T = eltype(c.X)
    @test sum(abs2, big.(c.y)) > big(floatmax(T))
    λ = T(1.5 * lambda_max(c.X, c.y, c.α))
    x0 = T.(c.c .* (0.3 .* sin.(1:3)))
    for (order, momentum) in ORDERS, owner in (false, true)
      logs = check_refusal(c.f, NormL1(λ), x0; order, momentum, owner, pattern = r"nonfinite objective",
                           rng_unchanged = false, maxpasses = 2000)
      @test isempty(logs)
    end
  end
end

@testset "R3: Σr² that underflows at the solution gives a reported minimum of 0" begin
  for c in (d1_case("Float64, Σy² underflows: raw, ‖y‖ = 1e-165", Float64, 1e-165, nothing),
            d1_case("Float64, α Σy² underflows: α = 1e-300, ‖y‖ = 1e-10", Float64, 1e-10, 1e-300),
            d1_case("Float32, Σy² underflows: raw, ‖y‖ = 1e-24", Float32, 1e-24, nothing))
    T = eltype(c.X)
    _, r = reference_lasso(c.X, c.y, c.α, 0.0)
    @test 0 < big(c.α) * sum(abs2, r) / 2 < big(nextfloat(zero(T))) / 2
    for (order, momentum) in ORDERS, owner in (false, true)
      res = check_d1_solve(c, zero(T), zeros(T, 3); order, momentum, owner)
      @test res.minimum === zero(T)
    end
  end
end

end
