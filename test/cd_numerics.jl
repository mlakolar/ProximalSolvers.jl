module CDNumerics
# Coordinate descent and the supplied loss scale (#295). The scale of `Scaled(LeastSquaresLoss, α)`
# is used as supplied in the coordinate step, the two stopping scales and the reported objective,
# combined with the data type `T` by Julia's promotion where that gives a concrete AbstractFloat
# (Float32 data with a Float64 scale keeps the Float64 value). X, y, the residual and the iterate
# stay in `T`. Accuracy is checked in BigFloat from the raw data and the supplied scale.
# The response scale `√α‖y‖` of the relative stopping rule is formed range-safely (#293): the cases
# below fix it where `Σy²` or `α Σy²` overflows or underflows, and refuse a computed `√α‖y‖` that is
# not a normal number of `T`. The coordinate scale `√(α a_k)` is formed from the two roots where the
# product `α a_k` is zero, subnormal or overflowing. Where that product or its reciprocal leaves the range
# of the scale type, the coordinate step forms the threshold `λ/(α a_k)` without using them (it still forms
# the product and its reciprocal to choose between the two ways, #294), and an infinite curvature is refused.
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
function cd_solve(f, λ, x0; order, momentum = nothing, owner = false, maxpasses = 2000, seed = 5, tol = 1e-7, relative = true)
  solver = CDSolver(; order, momentum, maxpasses, tol, relative, rng = Xoshiro(seed))
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

# The penalty `fraction` · max_j |α (Xᵀy)_j|, formed in BigFloat at 256 bits and rounded once to T
# (0 for a fraction of 0): λmax itself can be above floatmax(T).
function penalty_fraction(T, X, y, α, fraction)
  iszero(fraction) && return zero(T)
  setprecision(BigFloat, 256) do
    T(big(fraction) * maximum(abs, big(α) .* (big.(X)' * big.(y))))
  end
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
                       rng_unchanged = true, maxpasses = 50, relative = true)
  rng = Xoshiro(5)
  solver = CDSolver(; order, momentum, maxpasses, relative, rng)
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
# order 1e-23. With relative scaling active and a scale of 0, `_visit!` counts the displacement of
# that coordinate as 0; if that holds for all coordinates, CD accepts the first pass as converged at a
# point that need not be a solution. A product that rounds to a subnormal can lose significant digits of the exact product.
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
# 10. An intermediate of the response scale leaves the range of T: CD does not stop after one pass (#293)
# ---------------------------------------------------------------------------
# The response scale √α‖y‖ multiplies the tolerance. It used to be 0 where Σy² or α Σy² underflowed
# (the tolerance became the absolute `tol`) and Inf where either overflowed (the tolerance became Inf);
# either way CD accepted the first pass as converged, with a KKT violation of order 0.1 to 1 of its
# scale. The scale is now formed in a wider type or with exponent-separated arithmetic where the sum or
# the product is not a normal number of T. The final scale is a normal number of T in each case below,
# and the control (‖y‖ = 2e151) keeps Σy² and α Σy² in range. Each case solves a problem with such a
# response, at a penalty of 0 and of a fraction of λmax (0.1, or less where λ‖x‖₁ would then be too
# large for T), from a cold and a warm start, in the three orders (cyclic, random with the default
# momentum, random without momentum), on a dense vector and on an owner. Each solve converges after more
# than one pass, at a point whose KKT violation for the supplied scale is within the bound, and with a
# tolerance equal to tol times the BigFloat value of √α‖y‖. The data are one fixed problem (30 × 3 and a
# response near the column space) of a given response norm and column scale. For each fixture and penalty
# below, `check_feasible` asserts that at the reference solution Σr² and the objective are below
# floatmax(T)/4, and that each nonzero α a_k lies in [floatmin(T), floatmax(T)/4), so that these cases do
# not exercise a coordinate scale whose product α a_k is outside the normal range (section 15 does). It
# checks no lower bound on Σr² or the objective: R3 underflow (a reported minimum of 0) remains possible
# and is covered in section 14.
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
# objective α Σr²/2 + λ‖x‖₁ are below floatmax(T)/4. These are upper bounds; nothing bounds them from
# below, so R3 underflow of the reported minimum remains possible for a fixture that passes (section
# 14). For the columns, `coordinate` selects what is asserted about each nonzero α a_k (in BigFloat):
#   :normal     α a_k lies in [floatmin(T), floatmax(T)/4);
#   :underflow  the root √(α a_k) is a normal number of T and at least one α a_k lies below floatmin(T),
#               so that the coordinate scale is formed from the two roots;
#   :subnormal  α a_k is a subnormal number of T with a finite reciprocal, so that the step coefficient
#               1/(α a_k) is finite and the coordinate scale is formed from the two roots;
#   :overflow   α a_k is above floatmax(T) and its root is at most floatmax(T), so that the step
#               coefficient 1/(α a_k) is 0 and the coordinate scale is formed from the two roots (#294);
#               the curvature a_k is at least floatmin(T) (a normal number);
#   :reciprocal α a_k is below 1/floatmax(T) and its root is a normal number of T, so that the reciprocal
#               1/(α a_k) overflows (#294); the curvature a_k is at least floatmin(T) (a normal number);
#   :subnormal_curvature  every nonzero curvature a_k is below floatmin(T) (a subnormal number of T, which has
#               lost relative precision) and α a_k is below 1/floatmax(T) with a root that is a normal
#               number of T; these fixtures are outside the convergence claims (see `check_honest`);
#   :any        nothing about α a_k.
function check_feasible(X, y, α, λ; coordinate = :normal)
  T = eltype(X)
  b, r = reference_lasso(X, y, α, λ)
  setprecision(BigFloat, 256) do
    ab, rss = big(α), sum(abs2, r)
    @assert rss < big(floatmax(T)) / 4 "Σr² at the solution is not below floatmax/4"
    @assert ab * rss / 2 + big(λ) * sum(abs, b) < big(floatmax(T)) / 4 "the objective at the solution is not below floatmax/4"
    curvatures = [sum(abs2, big.(X[:, k])) for k in axes(X, 2)]
    products = ab .* curvatures
    nonzero = filter(!iszero, products)
    nonzero_curvature = filter(!iszero, curvatures)
    if coordinate === :normal
      for (k, a) in enumerate(products)
        iszero(a) || @assert big(floatmin(T)) <= a < big(floatmax(T)) / 4 "α a_$k is outside [floatmin, floatmax/4)"
      end
    elseif coordinate === :underflow
      @assert all(a -> big(floatmin(T)) <= sqrt(a) <= big(floatmax(T)), nonzero) "a root √(α a_k) is not a normal number of T"
      @assert any(a -> a < big(floatmin(T)), nonzero) "no α a_k is below floatmin"
    elseif coordinate === :overflow
      @assert all(a -> a > big(floatmax(T)) && sqrt(a) <= big(floatmax(T)), nonzero) "an α a_k is not above floatmax with a root of at most floatmax"
      @assert all(a -> a >= big(floatmin(T)), nonzero_curvature) "a curvature a_k is subnormal"
    elseif coordinate === :reciprocal
      @assert all(a -> a < big(1) / big(floatmax(T)) && sqrt(a) >= big(floatmin(T)), nonzero) "an α a_k is not below 1/floatmax with a normal root"
      @assert all(a -> a >= big(floatmin(T)), nonzero_curvature) "a curvature a_k is subnormal"
    elseif coordinate === :subnormal_curvature
      @assert all(a -> a < big(floatmin(T)), nonzero_curvature) "a curvature a_k is not subnormal"
      @assert all(a -> a < big(1) / big(floatmax(T)) && sqrt(a) >= big(floatmin(T)), nonzero) "an α a_k is not below 1/floatmax with a normal root"
    elseif coordinate === :subnormal
      @assert all(a -> big(1) / big(floatmax(T)) < a < big(floatmin(T)), nonzero) "an α a_k is not subnormal with a finite reciprocal"
    else
      @assert coordinate === :any
    end
  end
  nothing
end

function d1_case(label, ::Type{T}, target, α; xscale = 1.0, zero_column = false, fractions = (0.0, 0.1),
                 coordinate = :normal) where T
  X, y, c = scaled_problem(T, target; xscale, zero_column)
  f = α === nothing ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)
  αo = α === nothing ? 1 : α
  (; label, X, y, α = αo, f, c, fractions, coordinate, scale = true_scale(y, αo))
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

# The reported minimum against F(x) = α/2 ‖y - Xx‖² + λ‖x‖₁ in BigFloat at the returned x. Where Σr²
# and α Σr²/2 are normal numbers of T, the gap is within `objective_bound` of the scale of
# `objective_gap`. Where one is not (R3: the loss part is formed from Σr² in T and is subnormal or
# underflows), the reported minimum is within floatmin(T) of F, plus that allowance. The second
# expectation is a fixture bound for the cases here, not a derived one.
function check_reported_objective(X, y, α, λ, x, reported)
  T = eltype(X)
  setprecision(BigFloat, 256) do
    Xb, yb, xb, ab, lb = big.(X), big.(y), big.(x), big(α), big(λ)
    rss = sum(abs2, yb .- Xb * xb)
    normal = big(floatmin(T)) <= rss && big(floatmin(T)) <= ab * rss / 2
    F = ab * rss / 2 + lb * sum(abs, xb)
    allowance = objective_bound(T, size(X, 1), size(X, 2)) * (ab * sum(abs2, yb) / 2 + lb * sum(abs, xb))
    @test abs(big(reported) - F) <= allowance + (normal ? 0 : big(floatmin(T)))
  end
end

# One solve of a case: converged without a warning, after more than one pass, with the KKT violation
# within the bound, the tolerance of the BigFloat response scale and the reported minimum as above; a
# zero column stays 0. The Float64 solves use tol = 1e-9 against the KKT bound 1e-7, a ratio of 100
# between two different quantities (a coefficient-change threshold and a KKT violation); the bound is
# checked on each solve, not implied by the ratio. With `relative = false` the threshold is the
# absolute change `tol ‖y‖ / max_k ‖X_k‖` (with tol = 1e-9 in Float64 and 1e-6 in Float32), the
# coefficient-unit equivalent of the relative threshold at the column of largest norm, and is the
# reported tolerance. The Float32 relative tolerance is `tol32`.
function check_d1_solve(c, λ, x0; order, momentum, owner, relative = true, tol32 = 1e-7)
  T = eltype(c.X)
  tol = T === Float64 ? 1e-9 : tol32
  tol_abs = relative ? tol : (T === Float64 ? 1e-9 : 1e-6) * norm(c.y) / maximum(norm, eachcol(c.X))
  r = cd_solve(c.f, λ, x0; order, momentum, owner, relative, tol = tol_abs)
  @test r.converged && isempty(r.logs)
  @test r.passes > 1
  @test isfinite(r.minimum)
  @test kkt_relative(c.X, c.y, c.α, λ, r.x) <= kkt_tolerance(T)
  relative ? @test(isapprox(big(r.tolerance), big(T(tol)) * c.scale, rtol = (length(c.y) + 8) * eps(T))) :
             @test(r.tolerance == T(tol_abs))
  check_reported_objective(c.X, c.y, c.α, λ, r.x, r.minimum)
  all(iszero, c.X[:, end]) && @test r.x[end] == 0
  r
end

# The solves of one case: each penalty fraction, cold and warm start, order and iterate type, and each
# stopping rule in `relatives`.
function check_d1_case(c; relatives = (true,), tol32 = 1e-7)
  T = eltype(c.X)
  p = size(c.X, 2)
  @test c.scale > 0
  for fraction in c.fractions
    λ = penalty_fraction(T, c.X, c.y, c.α, fraction)
    @test iszero(fraction) || (isfinite(λ) && λ > 0)
    check_feasible(c.X, c.y, c.α, λ; coordinate = c.coordinate)
    for x0 in (zeros(T, p), T.(c.c .* (0.3 .* sin.(1:p)))), (order, momentum) in ORDERS, owner in (false, true),
        relative in relatives
      check_d1_solve(c, λ, x0; order, momentum, owner, relative, tol32)
    end
  end
end

@testset "CD converges with a normal response scale whose intermediates may leave the range of T: $(c.label)" for c in d1_cases()
  check_d1_case(c)
end

# ---------------------------------------------------------------------------
# 11. A response scale that is not a normal number of T is refused before any pass
# ---------------------------------------------------------------------------
# A response scale whose computed value, rounded to T, is not a normal number of T (above floatmax(T) or
# below floatmin(T), a subnormal) is not representable at T's precision, so CD throws an ArgumentError
# that names the response scale before the first pass: x, the owner state and the generator are as they
# were (the start is warm, so that a pass would change x; the random orders draw from the generator in
# each pass). The fixtures have √α‖y‖ at least 0.1% beyond those limits, so that the rounding does not
# decide; within a rounding error of a limit either outcome is allowed (section 13). A y with a single
# subnormal entry is refused too. The columns (1, 1, 1, 1) and (1, -1, 1, -1) fit y = c (1, 1, 1, 1) with
# x = (c, 0), where c is a power of two or a subnormal, so that the sums of the entries of y and of their
# differences are exact in any order and the residual is 0 after the first column. The same problem with
# `relative = false` then runs: it converges, with the absolute tolerance 1e-7, and no product or sum in
# it overflows. (For the single subnormal entry the residual and the objective underflow.) Where Σr² itself
# overflows, `relative = false` does not avoid the refusal: it ends in the nonfinite-objective refusal of R3
# (the last testset of this section).
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

# The refusal suggests `relative = false`. Where Σr² overflows at the solution, that run ends in the
# nonfinite-objective refusal (R3) instead. y = c (1, -1, 1, -1) is orthogonal to the single column of
# ones, so the minimizer is x = 0, Σr² = Σy² overflows T at that minimizer, and √α‖y‖ is above floatmax(T)
# (α = 100 in Float64, 400 in Float32). The refusals below start from the warm x = 0.3.
@testset "relative = false after an overflow refusal can end in the nonfinite-objective refusal ($T)" for (T, c, α) in
    ((Float64, 2.0^1020, 100.0), (Float32, 2f0^123, 400f0))
  y = c .* T[1, -1, 1, -1]
  X = ones(T, 4, 1)
  f = α * LeastSquaresLoss(y, X)
  @test true_scale(y, α) > big(floatmax(T)) && sum(abs2, big.(y)) > big(floatmax(T))
  for (order, momentum) in ORDERS, owner in (false, true)
    check_refusal(f, NormL1(zero(T)), T[0.3]; order, momentum, owner)
    check_refusal(f, NormL1(zero(T)), T[0.3]; order, momentum, owner, relative = false,
                  pattern = r"nonfinite objective", rng_unchanged = false)
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

# ---------------------------------------------------------------------------
# 15. A coordinate scale whose product α a_k underflows to 0 (#293)
# ---------------------------------------------------------------------------
# Where relative scaling is active (the default, with a positive response scale), the coordinate scale
# √(α a_k) multiplies each coordinate change in the stopping test. Where the rounded product α a_k is 0
# (S == T), a scale formed as the root of the rounded product is 0, and a change of that coordinate
# counts as 0; with a normal response scale, CD would then accept the first pass as converged at a large
# KKT violation. In the seven fixtures below (five in Float64 and two in
# Float32, S == T; the penalty is 0, and the positive penalties with such a product are in section 18)
# both α Σy² and α a_k round to 0 while √α ‖y‖ is a normal number. Each runs
# from a cold and a warm start, in the
# three orders, on a dense vector and on an owner: 84 solves, each converged after more than one pass
# with the KKT violation within the bound. The coordinate scale is formed from the two roots,
# √α √a_k, in S (= T here), and is a normal number in these fixtures (`check_feasible` with :underflow
# asserts it).
function coordinate_underflow_cases()
  [d1_case("Float64, α = 1e-300, X·1e-16, ‖y‖ = 1e-13", Float64, 1e-13, 1e-300; xscale = 1e-16, fractions = (0.0,), coordinate = :underflow),
   d1_case("Float64, α = 1e-310, X·1e-8, ‖y‖ = 1e-8", Float64, 1e-8, 1e-310; xscale = 1e-8, fractions = (0.0,), coordinate = :underflow),
   d1_case("Float64, α = 1e-300, X·1e-14, ‖y‖ = 1e-13", Float64, 1e-13, 1e-300; xscale = 1e-14, fractions = (0.0,), coordinate = :underflow),
   d1_case("Float64, α = nextfloat(0.0), ‖X_k‖² ≈ 0.25, ‖y‖ = 0.3", Float64, 0.3, nextfloat(0.0); xscale = sqrt(0.25 / 30), fractions = (0.0,), coordinate = :underflow),
   d1_case("Float64, α = 1e-200, X·1e-63, ‖y‖ = 1e-62", Float64, 1e-62, 1e-200; xscale = 1e-63, fractions = (0.0,), coordinate = :underflow),
   d1_case("Float32, α = 1f-30, X·1e-9, ‖y‖ = 1e-9", Float32, 1e-9, 1f-30; xscale = 1e-9, fractions = (0.0,), coordinate = :underflow),
   d1_case("Float32, α = 1f-20, X·1e-14, ‖y‖ = 1e-14", Float32, 1e-14, 1f-20; xscale = 1e-14, fractions = (0.0,), coordinate = :underflow)]
end

@testset "CD converges where α a_k underflows to 0 and its root is normal: $(c.label)" for c in coordinate_underflow_cases()
  T = eltype(c.X)
  @test all(k -> iszero(T(big(c.α) * sum(abs2, big.(c.X[:, k])))), 1:3)
  check_d1_case(c)
end

# ---------------------------------------------------------------------------
# 16. More cases with a product α a_k outside the normal range (#293; the overflow is converted in #294)
# ---------------------------------------------------------------------------
# Each case is solved and checked as in section 10 (KKT, tolerance, reported minimum, zero column),
# with the assertions of `check_feasible` named by `coordinate`.
#   - Underflow in Float32 with α = nextfloat(0f0) (the Float64 case is in section 15).
#   - A positive penalty where α a_k is subnormal with a finite reciprocal: the step forms the threshold
#     λ/(α a_k) directly (#294) and the coordinate scale comes from the two roots.
#   - A zero column next to coordinate scales that underflow or are subnormal: its scale is 0 and its
#     coordinate stays at the prox of 0.
function coordinate_range_cases()
  [d1_case("Float32, α = nextfloat(0f0), ‖X_k‖² ≈ 0.25, ‖y‖ = 0.3", Float32, 0.3, nextfloat(0f0); xscale = sqrt(0.25 / 30), fractions = (0.0,), coordinate = :underflow),
   d1_case("Float64, penalty with a subnormal α a_k (finite reciprocal): α = 1e-300, X·1.8e-5, ‖y‖ = 1e5", Float64, 1e5, 1e-300; xscale = 1.8e-5, fractions = (0.0, 0.01, 0.1, 0.5), coordinate = :subnormal),
   d1_case("Float32, penalty with a subnormal α a_k (finite reciprocal): α = 1f-30, X·1.3e-5, ‖y‖ = 1e5", Float32, 1e5, 1f-30; xscale = 1.3e-5, fractions = (0.0, 0.01, 0.1, 0.5), coordinate = :subnormal),
   d1_case("Float64, subnormal α a_k with a zero column, penalty 0.1 λmax", Float64, 1e5, 1e-300; xscale = 1.8e-5, zero_column = true, fractions = (0.1,), coordinate = :subnormal),
   d1_case("Float64, α a_k underflows, with a zero column", Float64, 1e-13, 1e-300; xscale = 1e-16, zero_column = true, fractions = (0.0,), coordinate = :underflow),
   d1_case("Float32, α a_k underflows, with a zero column", Float32, 1e-9, 1f-30; xscale = 1e-9, zero_column = true, fractions = (0.0,), coordinate = :underflow)]
end

@testset "CD with a product α a_k below the normal range: $(c.label)" for c in coordinate_range_cases()
  check_d1_case(c)
end

# Overflow of α a_k (#294). In these S == T fixtures α a_k is above floatmax(T) and its root is a normal
# number. The coordinate scale is then the product of the two roots, a finite number (it was Inf, which
# `_visit!` refuses where relative scaling is active), and the step coefficient 1/(α a_k) would be 0, which
# ignores a positive penalty, so the step forms the threshold λ/(α a_k) directly. Each fixture is solved as in
# section 10 (from a cold and a warm start, in the three orders, on a dense vector and an owner, with
# the KKT violation, the tolerance and the reported minimum checked), at a penalty of 0 and of a fraction of
# λmax, and the scale of each column is checked against the BigFloat root. The penalty is a fraction of
# λmax (`penalty_fraction`); the fractions are those for which the reported objective stays below
# floatmax(T) (`check_feasible`). The data are the fixed problem of section 10.
function coordinate_overflow_cases()
  [d1_case("Float64, α = 1e300, X·1e5, ‖y‖ = 1e3", Float64, 1e3, 1e300; xscale = 1e5, fractions = (0.0, 0.1), coordinate = :overflow),
   d1_case("Float32, α = 1f30, X·1e4, ‖y‖ = 1e5", Float32, 1e5, 1f30; xscale = 1e4, fractions = (0.0,), coordinate = :overflow),
   d1_case("Float64, α = 1e300, X·1e5, ‖y‖ = 1e3, with a zero column", Float64, 1e3, 1e300; xscale = 1e5, zero_column = true, fractions = (0.0, 0.1), coordinate = :overflow)]
end

@testset "CD converges where α a_k is above floatmax(T) and the coordinate scale is finite: $(c.label)" for c in coordinate_overflow_cases()
  T = eltype(c.X)
  m = PS.LSModel(c.y, c.X, c.α)
  setprecision(BigFloat, 256) do
    for k in axes(c.X, 2)
      iszero(sum(abs2, c.X[:, k])) && continue
      a = PS._sqnorm!(m, k)
      res = PS.coordinate_scale(m, nothing, k)
      ref = sqrt(big(c.α)) * sqrt(sum(abs2, big.(c.X[:, k])))
      @test isinf(m.s * a) && isfinite(res) && abs(big(res) - ref) <= (length(c.y) + 8) * eps(T) * ref
    end
  end
  check_d1_case(c; relatives = (true, false))
end

# A coordinate step whose centre overflows is refused and leaves x unchanged, also with a threshold that
# overflows. With α = 1 and Float64 columns of norm about 1e-160, a_k is subnormal (about 3e-319), the
# response ‖y‖ = 1e150 is a normal scale, and the largest solution coefficient is above floatmax(Float64)
# (asserted below), so b/a overflows. At a positive penalty (0.25 and 0.5 of λmax) the threshold
# λ/a_k also overflows for at least one column (asserted below; for 0.5 of λmax for every column). That
# threshold is capped at floatmax, and the centre b/a that overflows is still refused rather than set
# to 0, as an infinite level passed to PB's NormL1 prox would set it. The generator is not asserted: the refusal comes within a
# pass.
@testset "a coordinate step whose centre overflows is refused, x unchanged: penalty $fraction λmax" for fraction in (0.0, 0.25, 0.5)
  X, y, _ = scaled_problem(Float64, 1e150; xscale = 1e-160)
  λ = penalty_fraction(Float64, X, y, 1.0, fraction)
  @test all(k -> 0 < sum(abs2, X[:, k]) < floatmin(Float64), 1:3)
  @test maximum(abs, first(reference_lasso(X, y, 1.0, λ))) > big(floatmax(Float64))
  setprecision(BigFloat, 256) do
    τ = [big(λ) / sum(abs2, big.(X[:, k])) for k in 1:3]
    iszero(fraction) || @test any(t -> t > big(floatmax(Float64)), τ)
    fraction == 0.5 && @test all(t -> t > big(floatmax(Float64)), τ)
  end
  for (order, momentum) in ORDERS, owner in (false, true)
    check_refusal(LeastSquaresLoss(y, X), NormL1(λ), [0.3, -0.2, 0.1]; order, momentum, owner,
                  pattern = r"not finite", rng_unchanged = false)
  end
end

# ---------------------------------------------------------------------------
# 17. The coordinate scale: values, branches, inference and allocation
# ---------------------------------------------------------------------------
# One column of n entries 1.3 2^k and a loss scale 1.3 2^j (in Float32, Float64, a Float64 scale on
# Float32 data, or BigFloat) over magnitudes that take each way of forming the coordinate scale (see the
# comment of `coordinate_scale`): 1, the root of the rounded product; 2, the root of the product p in S
# where p is not below floatmin(S) and is finite or the curvature is infinite; 3, the product of the two
# roots where p is zero or subnormal in S, or p is Inf for a finite curvature (tag 4 marks that overflow
# with a root that is a normal number, #294). This holds for both types. Where way 1 or 2 applies the
# result is the same bits as that formula. The result is 0 for a = 0, and Inf for an infinite a and for
# a root more than 4 eps(T) above floatmax(T). Otherwise, where the BigFloat root √(α a), with a the
# computed curvature of the column, is more than 4 eps(T) below floatmax(T), the result is within 2 eps(T)
# of it, plus nextfloat(zero(T)) for a subnormal result. The calls are inferred, and for IEEE scales
# allocate nothing after warm-up (the third way included).
function coordinate_way(m::PS.LSModel{T}, a) where T
  p = m.s * a
  floatmin(T) <= T(p) <= floatmax(T) && return 1
  p < floatmin(typeof(p)) || (isinf(p) && isfinite(a)) ? 3 : 2
end

function check_coordinate_point(T, k, α, ways)
  X = fill(ldexp(T(1.3), k), 6, 1)
  m = PS.LSModel(zeros(T, 6), X, α)
  a = PS._sqnorm!(m, 1)
  way = coordinate_way(m, a)
  res = PS.coordinate_scale(m, nothing, 1)
  @test res isa T
  push!(ways, way)
  overflow = isinf(m.s * a) && isfinite(a)    # an overflowing product of a finite curvature
  setprecision(BigFloat, 256) do
    ref = sqrt(big(m.s) * big(a))
    fm = big(floatmax(T))
    if iszero(a)
      @test res === zero(T)
    elseif isinf(a) || ref > fm * (1 + 4 * eps(T))
      @test res === T(Inf)      # an infinite curvature, or a root above floatmax(T)
    elseif ref < fm * (1 - 4 * eps(T))
      @test abs(big(res) - ref) <= 2 * eps(T) * ref + big(nextfloat(zero(T)))
      overflow && push!(ways, 4)    # an overflowing product with a root that is a normal number
    end
  end
  way == 1 && @test res === sqrt(T(m.s * a))
  way == 2 && @test res === T(sqrt(m.s * a))
  if !(m.s isa BigFloat)
    @test (@inferred PS.coordinate_scale(m, nothing, 1)) === res
    alloc_coordinate(m, nothing, 1)
    @test alloc_coordinate(m, nothing, 1) == 0
  end
  nothing
end

@testset "the coordinate scale over the ranges of the curvature and the loss scale ($T)" for T in (Float32, Float64)
  ks = T === Float32 ? (-80, -70, -60, -55, -40, -20, 0, 20, 40, 55, 60) :
                       (-540, -530, -520, -500, -300, -100, 0, 100, 300, 500, 510, 520)
  js = T === Float32 ? (-148, -140, -100, -60, -1, 0, 1, 60, 100, 126) :
                       (-1070, -1000, -600, -300, -1, 0, 1, 300, 600, 1000, 1020)
  ways = Set{Int}()
  for k in ks, j in js
    check_coordinate_point(T, k, ldexp(T(1.3), j), ways)
  end
  if T === Float32     # a Float64 scale on Float32 data
    for k in ks, j in (-148, -120, -60, -1, 0, 60, 120, 127)
      check_coordinate_point(T, k, ldexp(1.3, j), ways)
    end
  end
  setprecision(BigFloat, 256) do    # a BigFloat scale, also beyond the range of T
    for k in ks, j in (-1500, -300, -1, 0, 1, 300, 1500)
      check_coordinate_point(T, k, big(1.3) * BigFloat(2)^j, ways)
    end
  end
  @test ways == Set([1, 2, 3, 4])
  # a zero column has the scale 0; an infinite curvature the scale Inf
  X = zeros(T, 4, 1)
  @test PS.coordinate_scale(PS.LSModel(zeros(T, 4), X, 1.0), nothing, 1) === zero(T)
  X = fill(T === Float32 ? 1f20 : 1e200, 4, 1)
  @test PS.coordinate_scale(PS.LSModel(zeros(T, 4), X, 1.0), nothing, 1) === T(Inf)
end


# ---------------------------------------------------------------------------
# 18. The coordinate step where α a_k or its reciprocal leaves the range of the scale type (#294)
# ---------------------------------------------------------------------------
# The step of column k is the soft threshold of the centre c = x_k + b/a_k at τ = λ/(α a_k). It used the
# coefficient 1/(α a_k) in PB's NormL1 prox. At a positive penalty that coefficient is 0 where α a_k
# overflows (the penalty was ignored: CD reported converged = true at a KKT violation of about 0.1 or 0.5
# of the scale) and Inf where α a_k is below 1/floatmax (the threshold was Inf, which sets a finite centre
# to 0); at a zero penalty PB keeps a zero threshold for any coefficient. Where α a_k and its reciprocal
# are at least floatmin(S) the step is unchanged; outside that band, S == T here, the step forms τ without
# using the product or its reciprocal (`_scaled_prox` still forms them to choose the way). Each fixture
# below has a normal curvature a_k (asserted by `check_feasible`), so that a_k keeps its relative
# precision while the product α a_k leaves the range. It is solved as in section 10 (from a cold and
# a warm start, in the three orders, on a dense vector and an owner, with the KKT violation against the
# supplied α, the tolerance and the reported objective checked) at a penalty of 0 and of fractions of
# λmax, with relative = true and relative = false. The Float32 relative tolerance is 1e-6, not the 1e-7 of
# section 10: with a penalty of 0.5 λmax the threshold τ is of the order of the coefficients, the centre
# c = x - τ is about twice as large as x, and a Float32 step then has an error of a few ulp of c. A
# threshold of 1e-7 is of that size in coefficient units, and a pass over the active coordinates that
# dithers above it gives no full pass that visits the coordinates at 0, so CD can stop at
# `maxpasses` at a KKT violation of 0.2 (it did under coverage instrumentation, which can change the
# summation order and the inlining). The KKT bound is unchanged.
function step_cases()
  [d1_case("Float64, α a_k overflows: α = 1e300, X·1e5, ‖y‖ = 100", Float64, 100.0, 1e300; xscale = 1e5, fractions = (0.0, 0.1, 0.5), coordinate = :overflow),
   d1_case("Float32, α a_k overflows: α = 1f30, X·1e4, ‖y‖ = 1e3", Float32, 1e3, 1f30; xscale = 1e4, fractions = (0.0, 0.1, 0.5), coordinate = :overflow),
   d1_case("Float64, 1/(α a_k) overflows: α = 1e-300, X·1e-5, ‖y‖ = 100", Float64, 100.0, 1e-300; xscale = 1e-5, fractions = (0.0, 0.1, 0.5), coordinate = :reciprocal),
   d1_case("Float32, 1/(α a_k) overflows: α = 1f-30, X·3e-6, ‖y‖ = 100", Float32, 100.0, 1f-30; xscale = 3e-6, fractions = (0.0, 0.1, 0.5), coordinate = :reciprocal),
   d1_case("Float64, α a_k overflows, with a zero column", Float64, 100.0, 1e300; xscale = 1e5, zero_column = true, fractions = (0.0, 0.1), coordinate = :overflow),
   d1_case("Float32, α a_k overflows, with a zero column", Float32, 1e3, 1f30; xscale = 1e4, zero_column = true, fractions = (0.0, 0.1), coordinate = :overflow),
   d1_case("Float64, 1/(α a_k) overflows, with a zero column", Float64, 100.0, 1e-300; xscale = 1e-5, zero_column = true, fractions = (0.0, 0.1), coordinate = :reciprocal),
   d1_case("Float32, 1/(α a_k) overflows, with a zero column", Float32, 100.0, 1f-30; xscale = 3e-6, zero_column = true, fractions = (0.0, 0.1), coordinate = :reciprocal)]
end

@testset "CD converges where α a_k or its reciprocal is out of range, the penalty is applied: $(c.label)" for c in step_cases()
  check_d1_case(c; relatives = (true, false), tol32 = 1e-6)
end

# A subnormal curvature (out of scope): no false convergence. A column whose squared norm a_k is a subnormal
# number has lost relative precision (about 8 bits in Float32 at X·1e-22 and about 16 bits in Float64 at
# X·1e-160, and each square is rounded to the subnormal grid before the sum), and the step b/a′ for the
# rounded a′ is a step with a different size from b/a, so whether CD converges depends on how far a′ is
# from a and on the summation order. These fixtures (raw least squares, so that
# α a_k = a_k is subnormal and its reciprocal overflows) therefore do not assert convergence. They assert
# the contract: a run that reports converged = true has a KKT violation within the bound (never converged
# = true above it), and a run that does not converge only warns that it reached maxpasses. The oracle is
# the same BigFloat KKT violation as above. The test does not count how many runs converge.
function subnormal_curvature_cases()
  [d1_case("Float64, raw LS: X·1e-160, ‖y‖ = 1", Float64, 1.0, nothing; xscale = 1e-160, fractions = (0.0, 0.1, 0.5), coordinate = :subnormal_curvature),
   d1_case("Float32, raw LS: X·1e-22, ‖y‖ = 1", Float32, 1.0, nothing; xscale = 1e-22, fractions = (0.0, 0.1, 0.5), coordinate = :subnormal_curvature)]
end

# One solve: only warnings in the log; a run that does not converge says so in the log; if converged, the KKT
# violation is within kkt_tolerance and the minimum is finite.
function check_honest(c, λ, x0; order, momentum, owner, relative)
  T = eltype(c.X)
  tol = T === Float64 ? 1e-9 : 1e-6
  tol = relative ? tol : tol * norm(c.y) / maximum(norm, eachcol(c.X))
  r = cd_solve(c.f, λ, x0; order, momentum, owner, relative, tol)
  @test only_warnings(r.logs)
  @test r.converged || !isempty(r.logs)
  if r.converged
    @test kkt_relative(c.X, c.y, c.α, λ, r.x) <= kkt_tolerance(T)
    @test isfinite(r.minimum)
  end
  nothing
end

@testset "subnormal curvature (out of scope): no false convergence: $(c.label)" for c in subnormal_curvature_cases()
  T = eltype(c.X)
  p = size(c.X, 2)
  for fraction in c.fractions
    λ = penalty_fraction(T, c.X, c.y, c.α, fraction)
    check_feasible(c.X, c.y, c.α, λ; coordinate = c.coordinate)
    for x0 in (zeros(T, p), T.(c.c .* (0.3 .* sin.(1:p)))), (order, momentum) in ORDERS, owner in (false, true), relative in (false, true)
      check_honest(c, λ, x0; order, momentum, owner, relative)
    end
  end
end

# Boundaries of the band: the columns have norm 1 up to rounding, so that α a_k is within 1% of α, and α
# is 0.5 and 2 times floatmin(T) and 0.5 and 2 times 1/floatmin(T). The step takes the unchanged
# coefficient where α a_k and its reciprocal are at least floatmin(T) (2 floatmin(T) and 0.5/floatmin(T))
# and forms the threshold directly where not (0.5 floatmin(T), where α a_k is subnormal, and
# 2/floatmin(T), where the reciprocal is subnormal). Each solves with a positive penalty. At 0.5
# floatmin(T) the penalty 0.1 λmax is itself subnormal in T.
function unit_case(label, ::Type{T}, α; target = 0.5, fractions = (0.0, 0.1, 0.5)) where T
  rng = Xoshiro(41)
  X0 = randn(rng, 30, 3)
  X0 ./= sqrt.(sum(abs2, X0; dims = 1))
  y0 = X0 * [1.0, -2.0, 0.5] .+ 0.02 .* randn(rng, 30)
  X, y = Matrix{T}(X0), Vector{T}(y0 .* (target / norm(y0)))
  (; label, X, y, α, f = α * LeastSquaresLoss(y, X), c = target / norm(y0), fractions, coordinate = :any, scale = true_scale(y, α))
end

function boundary_cases()
  cases = []
  for T in (Float32, Float64), (t, form) in ((0.5, :low), (2.0, :low), (0.5, :high), (2.0, :high))
    α = form === :low ? T(t) * floatmin(T) : T(t) / floatmin(T)
    expected = (form === :low && t > 1) || (form === :high && t < 1)    # in the band: the unchanged step
    push!(cases, (; c = unit_case("$T, α = $(t)$(form === :low ? " floatmin" : "/floatmin")", T, α), expected, t, form))
  end
  cases
end

@testset "CD at the boundaries of the band of the step: $(b.c.label)" for b in boundary_cases()
  c, T = b.c, eltype(b.c.X)
  m = PS.LSModel(c.y, c.X, c.α)
  for k in axes(c.X, 2)
    p = m.s * PS._sqnorm!(m, k)
    target = b.form === :low ? b.t * floatmin(T) : b.t / floatmin(T)
    @test 0.99 < p / target < 1.01
    @test (floatmin(T) <= p && floatmin(T) <= inv(p)) == b.expected
  end
  b.form === :low && b.t < 1 && @test issubnormal(penalty_fraction(T, c.X, c.y, c.α, 0.1))
  check_d1_case(c; relatives = (true, false))
end

# The unchanged step: for a model whose p = m.s a and its reciprocal are at least floatmin(S), the
# coordinate after `coordinate_step!` is the value of the former expression
# prox_block(g, old + b/a, k, inv(m.s a)), from a cold and a warm start, with Float32 data and a Float64
# scale (S wider than T), a BigFloat scale, and same-type scales, at magnitudes inside the band (p between
# 4 floatmin(S) and 1/(4 floatmin(S)), checked for each model; a model outside is skipped).
function former_step(m, g, x, k)
  a, b = PS._column_dot(m, k)
  ProximalBase.prox_block(g, x[k] + b / a, k, inv(m.s * a))
end

function band_scales()
  [(Float32, 0.3f0), (Float32, 2), (Float32, 1e30), (Float32, 3e-30), (Float32, 1e-44), (Float32, big"0.3"), (Float32, 1 // 3),
   (Float64, 0.3), (Float64, 1e150), (Float64, 3e-150), (Float64, 0.1f0), (Float64, big"1e-250"), (Float64, big(3))]
end

@testset "inside the band the coordinate step is the former prox_block step (T = $T, scale $(typeof(α)))" for (T, α) in band_scales()
  checked = 0
  for xscale in (1.0, 1e5, 1e-5, 1e-7), fraction in (0.0, 0.2)
    n, p = 12, 4
    X, y = plain_data(T, n, p; seed = 7)
    X = T.(xscale .* X)
    m = PS.cdmodel(α * LeastSquaresLoss(y, X), SparseIterate(zeros(T, p)))
    S = typeof(m.s)
    inside(a) = isfinite(a) && 4 * floatmin(S) <= m.s * a && (m.s * a) * (4 * floatmin(S)) <= 1
    all(k -> inside(PS._sqnorm!(m, k)), 1:p) || continue
    λ = penalty_fraction(T, X, y, α, fraction)
    g = NormL1(λ)
    for warm in (false, true)
      x = SparseIterate(warm ? T.(0.1 .* sin.(1:p)) : zeros(T, p))
      PS.initialize!(m, x)
      for k in 1:p
        expected = former_step(m, g, x, k)
        PS.coordinate_step!(m, g, x, k)
        @test x[k] == expected
        checked += 1
      end
    end
  end
  @test checked > 0
end

# The refusals of the step itself. A column whose squared norm is not finite is refused before the
# coordinate, the residual or the curvature cache changes, in both types and for each kind of scale; a
# penalty that is not the unweighted NormL1 is refused where the product is outside the band (the
# exceptional step is written for NormL1), and a scale type for which the product is outside the band
# is refused with the same message.
@testset "the step refuses a curvature that is not finite and forms no step for a penalty it cannot handle ($T)" for T in (Float32, Float64)
  X, y = plain_data(T, 8, 3; seed = 3)
  X[:, 2] .*= T === Float32 ? 1f20 : 1e160
  @test isinf(sum(abs2, X[:, 2])) && all(isfinite, X)
  for α in (nothing, T(2), 2, 1 // 3, 2.0, big"2.0", big(2), big(2) // 1)
    m = α === nothing ? PS.cdmodel(LeastSquaresLoss(y, X), SparseIterate(zeros(T, 3))) :
                        PS.cdmodel(α * LeastSquaresLoss(y, X), SparseIterate(zeros(T, 3)))
    x = SparseIterate(T.(0.1 .* (1:3)))
    PS.initialize!(m, x)
    r0, x0 = copy(m.r), copy(Vector(x))
    err = try
      PS.coordinate_step!(m, NormL1(T(0.01)), x, 2)
      nothing
    catch e
      e
    end
    @test err isa ArgumentError && occursin("curvature of coordinate 2", err.msg)
    @test m.r == r0 && Vector(x) == x0 && isnan(m.a[2])
  end
  # a weighted penalty where the product is outside the band
  Xs = T.(1e5 .* X[:, [1, 3]])
  m = PS.cdmodel((T === Float32 ? 1f30 : 1e300) * LeastSquaresLoss(y, Xs), SparseIterate(zeros(T, 2)))
  x = SparseIterate(T.([0.1, 0.2]))
  PS.initialize!(m, x)
  a = PS._sqnorm!(m, 1)
  @test isinf(m.s * a)
  err = try
    PS.coordinate_step!(m, NormL1(T(0.01), ones(T, 2)), x, 1)
    nothing
  catch e
    e
  end
  @test err isa ArgumentError && occursin("no range-safe form", err.msg)
  @test Vector(x) == T.([0.1, 0.2])
  # a scale type that is wider than T: the exceptional step is not defined for it (unreachable through solve!)
  W = T === Float32 ? Float64 : BigFloat
  @test_throws ArgumentError PS._exceptional_step(NormL1(T(0.01)), one(T), W(1), one(T), 1)
end

# The exceptional step against PB's prox: for a threshold τ in [0, floatmax(T)] the soft threshold
# `shrink(c, τ)` is bit for bit what PB's NormL1 prox returns at the level τ and the step 1, including signed
# zeros, subnormal thresholds and an infinite or NaN centre.
@testset "shrink is the NormL1 prox at the level τ and the step 1 ($T)" for T in (Float32, Float64)
  taus = T[0, nextfloat(zero(T)), 3 * nextfloat(zero(T)), prevfloat(floatmin(T)), floatmin(T), 1e-3, 0.5, 1, 7, floatmax(T) / 2, prevfloat(floatmax(T)), floatmax(T)]
  centres = T[0, -zero(T), nextfloat(zero(T)), -nextfloat(zero(T)), 1e-30, -1e-30, 0.5, -0.5, 3, -3, floatmax(T), -floatmax(T), Inf, -Inf, NaN]
  for τ in taus, c in centres
    a = ProximalBase.shrink(c, τ)
    b = ProximalBase.prox_block(NormL1(τ), c, 1, one(T))
    @test isequal(a, b) && (isnan(a) || signbit(a) == signbit(b))
  end
  # a zero penalty stays unpenalized at an infinite step coefficient (the former step at λ = 0)
  @test ProximalBase.prox_block(NormL1(zero(T)), T(3), 1, T(Inf)) == T(3)
end

# The threshold λ/(α a): Float32 is within one Float32 ulp of the quotient where that is below floatmax (the
# product of α and a is exact in Float64 and the quotient is rounded to Float64 and then to Float32, which
# can round to the neighbor of the correctly rounded value), and at least floatmax where the quotient is.
# Float64 is within 3 eps(Float64) of the quotient where it is normal, within nextfloat(0.0) + 3 eps of it
# where it is subnormal, and Inf where the quotient exceeds floatmax by more than 3 eps (relative). A
# Float64 or Int level is converted to Float64 first.
function check_float32_threshold(λ, α, a)
  res = PS._threshold(Float32, λ, α, a)
  ref = setprecision(BigFloat, 256) do
    big(λ) / (big(α) * big(a))
  end
  @test res isa Float32
  if ref >= big(floatmax(Float32))
    @test res >= floatmax(Float32)
  else
    @test abs(big(res) - ref) <= big(max(eps(res), eps(min(nextfloat(res), floatmax(Float32)))))
  end
  res
end

@testset "the threshold λ/(α a) over the ranges of α, a and λ (Float32)" begin
  ks = (-140, -100, -60, -20, 0, 20, 60, 100, 120)
  for λ in (0f0, nextfloat(0f0), 1f-30, 0.3f0, 1f10, floatmax(Float32)), jα in ks, ja in ks
    check_float32_threshold(λ, ldexp(1.3f0, jα), ldexp(1.7f0, ja))
    @test PS._threshold(Float32, Float64(λ), ldexp(1.3f0, jα), ldexp(1.7f0, ja)) isa Float32
  end
  @test PS._threshold(Float32, 2, 1f0, 4f0) === 0.5f0
  @test (@inferred PS._threshold(Float32, 0.3, 1.3f0, 2.5f0)) isa Float32
end

# A case where the quotient is not the correctly rounded Float32 value: the exact product of α and a has 48
# significant bits, the Float64 quotient falls on a midpoint between two Float32 values, and the second
# rounding takes the lower one: the result is 2.0000005f0 where the correctly rounded value is 2.0000007f0.
# The one-ulp bound holds (and the result is one of those two neighbors).
@testset "the Float32 threshold is within one ulp where the double rounding is not the correct rounding" begin
  α, a, λ = ldexp(1.7116712f0, -64), ldexp(1.8695179f0, -64), ldexp(1.6000005f0, -126)
  res = check_float32_threshold(λ, α, a)
  @test res in (2.0000005f0, 2.0000007f0)
end

@testset "the threshold λ/(α a) over the ranges of α, a and λ (Float64)" begin
  ks = (-1070, -1000, -600, -300, -100, 0, 100, 300, 600, 1000, 1020)
  for λ in (0.0, nextfloat(0.0), 1e-300, 0.3, 1e100, floatmax(Float64)), jα in ks, ja in ks
    α, a = ldexp(1.3, jα), ldexp(1.7, ja)
    (iszero(α) || iszero(a)) && continue
    res = PS._threshold(Float64, λ, α, a)
    @test res isa Float64
    setprecision(BigFloat, 256) do
      ref = big(λ) / (big(α) * big(a))
      if ref > big(floatmax(Float64)) * (1 + 3 * eps())
        @test res === Inf
      elseif ref > big(floatmax(Float64)) * (1 - 3 * eps())
        @test res >= prevfloat(floatmax(Float64), 4)    # within a few ulp of floatmax or Inf
      elseif ref >= big(floatmin(Float64))
        @test abs(big(res) - ref) <= 3 * eps() * ref
      else
        @test abs(big(res) - ref) <= big(nextfloat(0.0)) + 3 * eps() * ref
      end
    end
  end
  @test PS._threshold(Float64, 2, 1.0, 4.0) === 0.5
  @test PS._threshold(Float64, 0, 1.0, 4.0) === 0.0
  @test (@inferred PS._threshold(Float64, 0.3f0, 1.3, 2.5)) isa Float64
end

# A penalty at which the threshold τ = λ/(α a_k) of each column is at least floatmax(T) gives x = 0, for a
# level of type Int, Float64 and Float32 (λ = 4 is above λmax here, so x = 0 is the minimizer), from a cold
# and a warm start. A threshold above floatmax(T) is capped at floatmax(T), which gives the same 0 for a
# centre that is finite (the refusal of a centre that is not finite is tested above).
function large_threshold_cases()
  cs = (d1_case("Float64, α = 1e-300, X·1e-5", Float64, 100.0, 1e-300; xscale = 1e-5, coordinate = :reciprocal),
        d1_case("Float32, α = 1f-30, X·3e-6", Float32, 100.0, 1f-30; xscale = 3e-6, coordinate = :reciprocal))
  [(c, λ) for c in cs for λ in (4, 4.0, 4f0)]
end

@testset "a threshold above floatmax(T) gives x = 0, level $(typeof(λ)) ($(c.label))" for (c, λ) in large_threshold_cases()
  T = eltype(c.X)
  setprecision(BigFloat, 256) do
    @test all(k -> big(λ) / (big(c.α) * sum(abs2, big.(c.X[:, k]))) >= big(floatmax(T)), 1:3)
  end
  for x0 in (zeros(T, 3), T.(c.c .* (0.3 .* sin.(1:3)))), (order, momentum) in ORDERS, owner in (false, true), relative in (false, true)
    r = cd_solve(c.f, λ, x0; order, momentum, owner, relative, tol = T === Float64 ? 1e-9 : 1e-7)
    @test r.converged && isempty(r.logs) && all(iszero, r.x)
    @test kkt_relative(c.X, c.y, c.α, λ, r.x) <= kkt_tolerance(T)
    check_reported_objective(c.X, c.y, c.α, λ, r.x, r.minimum)
  end
end

# Float32 data with a level of type Float64 (not rounded to Float32 first, and also its Float32
# rounding as a Float64) and of type Int (0) where α a_k is out of range, solved at fractions of λmax
# below 0.5 (a nonzero solution after more than one pass) with both stopping rules.
function level_type_cases()
  [d1_case("Float32, α a_k overflows: α = 1f30, X·1e4", Float32, 1e3, 1f30; xscale = 1e4, coordinate = :overflow),
   d1_case("Float32, 1/(α a_k) overflows: α = 1f-30, X·3e-6", Float32, 100.0, 1f-30; xscale = 3e-6, coordinate = :reciprocal)]
end

@testset "Float32 data with a Float64 level and an Int level where α a_k is out of range: $(c.label)" for c in level_type_cases()
  lmax = lambda_max(c.X, c.y, c.α)
  for λ in (0.1 * lmax, Float64(Float32(0.1 * lmax)), 0.4 * lmax, 0)
    @test λ isa Int || (isfinite(λ) && λ > 0)
    for x0 in (zeros(Float32, 3), Float32.(c.c .* (0.3 .* sin.(1:3)))), (order, momentum) in ORDERS, relative in (false, true)
      tol = 1e-6 * (relative ? 1 : norm(c.y) / maximum(norm, eachcol(c.X)))
      r = cd_solve(c.f, λ, x0; order, momentum, relative, tol)
      @test r.converged && isempty(r.logs) && r.passes > 1 && !all(iszero, r.x)
      @test kkt_relative(c.X, c.y, c.α, λ, r.x) <= kkt_tolerance(Float32)
    end
  end
end

# y = 0 with an extreme loss scale, an absolute penalty and a warm start. The response scale is 0 and the
# stopping threshold is the absolute tol, for both settings of `relative`. The minimizer is x = 0; CD
# reaches it with a step that applies the positive threshold λ/(α a_k) once the iterate is within it (the
# penalty is chosen so that each threshold is between 1e-6 and 0.1, asserted below). Where α a_k overflows
# (the first two fixtures) a step that ignores the penalty would end at a point near 0 that is not 0; where
# 1/(α a_k) overflows (the last two) the former infinite threshold also gives x = 0 here. The reported
# minimum is finite and nonnegative; it is not asserted to be 0, as the loss part forms Σr² from the
# cached residual, which keeps the rounding error of the earlier steps (with a large α that error can give
# a large loss part).
zero_response_cases() =
  [("Float64, α = 1e300, X·1e5", Float64, 1e300, 1e5, floatmax(Float64) / 16),
   ("Float32, α = 1f30, X·1e4", Float32, 1f30, 1e4, floatmax(Float32) / 16),
   ("Float64, α = 1e-300, X·1e-5", Float64, 1e-300, 1e-5, 1e-310),
   ("Float32, α = 1f-30, X·3e-6", Float32, 1f-30, 3e-6, 1f-41)]

@testset "y = 0: an absolute penalty and an extreme loss scale give x = 0 ($label)" for (label, T, α, xscale, λ) in zero_response_cases()
  X, _, _ = scaled_problem(T, 1.0; xscale)
  y = zeros(T, size(X, 1))
  setprecision(BigFloat, 256) do
    @test all(k -> big(1e-6) < big(λ) / (big(α) * sum(abs2, big.(X[:, k]))) < big(0.1), 1:3)
  end
  for x0 in (T.(0.3 .* sin.(1:3)), T[0.3, 0, -0.2]), (order, momentum) in ORDERS, owner in (false, true), relative in (false, true)
    r = cd_solve(α * LeastSquaresLoss(y, X), λ, x0; order, momentum, owner, relative)
    @test r.converged && isempty(r.logs) && r.passes > 1
    @test all(iszero, r.x) && isfinite(r.minimum) && r.minimum >= 0 && r.tolerance == T(1e-7)
  end
end

# A non-finite squared column norm is refused before the first coordinate change: the whole design, or one
# column among normal ones, in both types, for the raw loss and for scales of type T, Float64, Int,
# Rational, BigFloat, BigInt and Rational{BigInt}, with both stopping rules, in the three orders, on a dense
# vector and an owner. The message names the curvature; x and the owner are unchanged (the start is warm, so
# a step would change them), and the generator for the cyclic order. (Before #294 such a run could report
# converged = true after one pass at a KKT violation of about 0.9 to 1 of its scale.)
function infinite_curvature_problem(::Type{T}; one_column) where T
  X, y, _ = scaled_problem(T, 1.0)
  factor = T === Float32 ? 1f19 : 1e160
  one_column ? (X[:, 2] .*= factor) : (X .*= factor)
  @test all(k -> isinf(sum(abs2, X[:, k])) == (!one_column || k == 2), 1:3)
  @test all(isfinite, X)
  X, y
end

@testset "an infinite curvature is refused, x unchanged: $T, $(one_column ? "one column" : "every column")" for T in (Float32, Float64), one_column in (false, true)
  X, y = infinite_curvature_problem(T; one_column)
  for α in (nothing, T(2), 2.0, 2, 1 // 3, big"2.0", big(2), big(2) // 1)
    f = α === nothing ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)
    for λ in (zero(T), T(0.01)), (order, momentum) in ORDERS, owner in (false, true), relative in (true, false)
      check_refusal(f, NormL1(λ), T.([0.3, -0.2, 0.1]); order, momentum, owner, relative,
                    pattern = r"curvature of coordinate", rng_unchanged = order === :cyclic)
    end
  end
end

# Cost: the step is inferred and allocates nothing after warm-up, on the unchanged path and on the exceptional
# one, in both types, with the scale of type T (the exceptional step is for S == T), for `coordinate_step!`
# and for `_visit!` with and without the coordinate scale.
function step_model(T, α, xscale; target = 100.0)
  X, y, _ = scaled_problem(T, target; xscale)
  x = SparseIterate(zeros(T, 3))
  m = α === nothing ? PS.cdmodel(LeastSquaresLoss(y, X), x) : PS.cdmodel(α * LeastSquaresLoss(y, X), x)
  PS.initialize!(m, x)
  m, x, NormL1(penalty_fraction(T, X, y, α === nothing ? 1 : α, 0.1))
end

step_cost_cases() =
  [("Float64, in the band", Float64, 0.7, 1.0, false), ("Float32, in the band", Float32, 0.7f0, 1.0, false),
   ("Float64, α a_k overflows", Float64, 1e300, 1e5, true), ("Float32, α a_k overflows", Float32, 1f30, 1e4, true),
   ("Float64, 1/(α a_k) overflows", Float64, 1e-300, 1e-5, true), ("Float32, 1/(α a_k) overflows", Float32, 1f-30, 3e-6, true),
   ("Float64, raw LS, subnormal curvature (out of scope: cost only)", Float64, nothing, 1e-160, true), ("Float32, raw LS, subnormal curvature (out of scope: cost only)", Float32, nothing, 1e-22, true)]

@testset "the step is inferred and allocates nothing on both paths ($label)" for (label, T, α, xscale, exceptional) in step_cost_cases()
  m, x, g = step_model(T, α, xscale)
  for k in 1:3
    S = typeof(m.s)
    p = m.s * PS._sqnorm!(m, k)
    @test exceptional == !(floatmin(S) <= p && floatmin(S) <= inv(p))
  end
  @test (@inferred PS.coordinate_step!(m, g, x, 1)) isa T
  @test (@inferred PS._visit!(m, g, x, 2, true)) isa T
  @test (@inferred PS._visit!(m, g, x, 3, false)) isa T
  for k in 1:3
    alloc_step(m, g, x, k)
    alloc_visit(m, g, x, k, true)
    alloc_visit(m, g, x, k, false)
  end
  @test all(k -> alloc_step(m, g, x, k) == 0, 1:3)
  @test all(k -> alloc_visit(m, g, x, k, true) == 0, 1:3)
  @test all(k -> alloc_visit(m, g, x, k, false) == 0, 1:3)
end

end
