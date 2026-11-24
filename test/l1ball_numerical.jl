module L1BallNumericalTest

# The IndBallL1 route of PGD and APG (IN-12, FP-05): the gate, the default route and the tolerance override, an
# independent MPFR check of each reported success on the #508 fixtures, converged at points exactly outside and inside
# the ball and the reported minimum, false stationarity under underflow and overflow, the cap at each accepted iterate, rollback and the
# line-search errors, including a nonzero step whose squared norm underflows.

using Test, LinearAlgebra, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

const METHODS = (ProximalGradientDescent(), AccProxGradDescent())
const OPTIONS = ProximalOptions(maxiter = 320)
mname(m) = m isa ProximalGradientDescent ? "PGD" : "APG"

# ---- fixtures (research/issue-514/fixtures.jl at the #515 handoff, the ℓ1 cases) ----------------------------------------

struct Fixture{T}
  name::String
  X::Matrix{T}
  y::Vector{T}
  r::T
  start::Vector{T}
  alpha::T
end

loss(d::Fixture) = isone(d.alpha) ? LeastSquaresLoss(d.y, d.X) : d.alpha * LeastSquaresLoss(d.y, d.X)

const CORRELATED_X = [1 0.375 0.125 -0.125; 0.25 1 -0.25 0.125; -0.125 0.125 1 0.375; 0.125 -0.25 0.125 1]
const CORRELATED_Y = [1, -0.75, 0.375, 0.5]

function fixtures(::Type{T}; big::Bool = true) where T
  out = Fixture{T}[]
  add(name, X, y, r, start = zeros(T, size(X, 2)); alpha = one(T)) =
    push!(out, Fixture{T}(name, X, y, T(r), start, T(alpha)))
  I2 = Matrix{T}(I, 2, 2)
  for k in (-20, 0, 20)
    add("tie_scale_$k", I2, fill(ldexp(one(T), k), 2), ldexp(T(0.1), k))
  end
  for tail in (T(0.25), T(2))
    x = T[1, tail * eps(T)]
    add("stationary_tail_$(tail)_eps", I2, x, one(T), copy(x))
  end
  # the radius one ulp below, at and one ulp above the threshold 1 of the projection of (2, -1), and 1.001
  for (j, r) in enumerate((prevfloat(one(T)), one(T), nextfloat(one(T)), T(1.001)))
    add("active_transition_$j", I2, T[2, -1], r)
  end
  h = eps(T)
  add("rounded_zero_predictor", reshape(T[1+h], 1, 1), T[1.5+2h], T(2), T[1.5])
  X, y = T.(CORRELATED_X), T.(CORRELATED_Y)
  add("l1_correlated_active", X, y, T(0.6))
  add("l1_correlated_scaled", X, y, T(0.6); alpha = T(0.25))
  add("l1_correlated_interior", X, y, T(4))
  add("l1_correlated_transition", X, y, T(1.5), T[-0.75, 0, 0.5, 0])
  if big
    p = 2048
    Xbig = Matrix{T}(I, p, p)
    for (j, r) in enumerate(T[2.048, 843.4569612191655, 1765.9906913347882, 1762.9198115568126])
      add("l1_tied_2048_$j", Xbig, ones(T, p), r)
    end
  end
  out
end

fixture(T, name) = only(filter(d -> d.name == name, fixtures(T; big = false)))

function solve_fixture(d::Fixture, method; options = OPTIONS, kw...)
  x = copy(d.start)
  r = solve!(x, loss(d), IndBallL1(d.r), method, options; kw...)
  x, r
end

# ---- the independent checks ---------------------------------------------------------------------------------------------

# Products with the design in BigFloat; a diagonal design uses its diagonal only.
bigmul(A::Vector{BigFloat}, v) = A .* v
bigmul(A::Matrix{BigFloat}, v) = A * v
bigtmul(A::Vector{BigFloat}, v) = A .* v
bigtmul(A::Matrix{BigFloat}, v) = transpose(A) * v
bigdesign(X) = isdiag(X) ? BigFloat.(diag(X)) : BigFloat.(X)

# Euclidean projection onto the ℓ1 ball of radius r by the sorted threshold, in BigFloat
function exact_project_l1(z::Vector{BigFloat}, r::BigFloat)
  sum(abs, z) <= r && return copy(z)
  m = sort!(abs.(z); rev = true)
  total = zero(r)
  for k in eachindex(m)
    total += m[k]
    threshold = (total - r) / k
    if k == length(m) || threshold >= m[k+1]
      return [copysign(max(zero(r), abs(t) - threshold), t) for t in z]
    end
  end
  error("empty projection")
end

# The test's radial witness: z itself when its ℓ1 mass, summed in the working MPFR precision, is at most r, otherwise z
# scaled down until that sum is at most r (a comparison of rounded MPFR sums, not an exact feasibility test)
function exact_witness(z::Vector{BigFloat}, r::BigFloat)
  s = sum(abs, z)
  s <= r && return z
  w = prevfloat(r / s) .* z
  factor = prevfloat(one(r))
  while sum(abs, w) > r
    w .*= factor
  end
  w
end

# The #514 quantities at 256 bits from the stored data, the loss scale as supplied and the radius: the violation
# max(0, ‖x‖₁ - r), the support gap and the fixed-step mapping (at the inverse step T(curvature)) at the witness, and
# the change of the loss between x and the witness.
function independent(X::Matrix{T}, y, alpha, r, x, curvature) where T
  setprecision(BigFloat, 256) do
    A, Y, s, R = bigdesign(X), BigFloat.(y), BigFloat(alpha), BigFloat(r)
    z = BigFloat.(x)
    w = exact_witness(z, R)
    grad = s .* bigtmul(A, bigmul(A, w) - Y)
    gap = max(zero(R), R * maximum(abs, grad) + dot(grad, w))
    L = BigFloat(T(curvature))
    mapping = L * maximum(abs, w - exact_project_l1(w .- grad ./ L, R))
    objective(v) = s / 2 * sum(abs2, bigmul(A, v) - Y)
    (; violation = max(zero(R), sum(abs, z) - R), gap, mapping, change = abs(objective(z) - objective(w)))
  end
end

# The route's budgets for the default tolerances, checked against a recomputation with LinearAlgebra's `norm`
function route_budgets(X::Matrix{T}, y, alpha, r) where T
  b = PS._l1_budgets(X, y, Float64(alpha), Float64(r), PS._feasibility_tolerances(NumericalFeasibility(), T))
  crel, orel, mrel = T === Float32 ? (1e-5, 1e-5, 1e-4) : (1e-10, 1e-9, 1e-8)
  ρ = Float64(r)
  col = maximum(norm(Float64.(c)) for c in eachcol(X))
  M, yscaled = sqrt(Float64(alpha)) * col, sqrt(Float64(alpha)) * norm(Float64.(y))
  cost = M * yscaled + 1.5 * M^2 * ρ
  gap = orel * max(yscaled, M * ρ)^2 / 4
  @test isapprox(b.gap, gap; rtol = 1e-12)
  @test isapprox(b.mapping, mrel * M * max(yscaled, M * ρ); rtol = 1e-12)
  @test isapprox(b.cap, min(ρ, crel * ρ, iszero(cost) ? Inf : gap / cost); rtol = 1e-12)
  b
end

# The #514 acceptance of a returned point: violation within the cap, gap, mapping and loss change within the budgets
function acceptable(X, y, alpha, r, x)
  b = route_budgets(X, y, alpha, r)
  ind = independent(X, y, alpha, r, x, b.curvature)
  setprecision(BigFloat, 256) do
    ind.violation <= BigFloat(b.cap) && ind.gap <= BigFloat(b.gap) && ind.mapping <= BigFloat(b.mapping) &&
      ind.change <= BigFloat(b.gap)
  end
end

# The result of a route solve with loss f: the reported minimum is the monitored objective f_x + g_x, the cached loss
# (g_x = 0), inside or outside the ball: it equals fg, the last traced or callback objective, when given, and agrees
# with the standalone loss. converged is the OR of the proposal flags.
function check_result_fields(x, res, f; fg = nothing)
  T = eltype(x)
  @test res.minimizer === x
  fg === nothing || @test res.minimum == fg
  @test isfinite(res.minimum) && isapprox(res.minimum, f(x); rtol = 64eps(T), atol = 64floatmin(T))
  @test res.converged == (res.x_converged || res.f_converged || res.grad_converged)
  @test isnan(res.gap)
end

refusal_message(f) = try
  f()
  ""
catch e
  e isa Union{ArgumentError, DimensionMismatch} ? sprint(showerror, e) : rethrow()
end

# ---- the gate ----------------------------------------------------------------------------------------------------------

@testset "gate: refusals before any write ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  X, y = T.(CORRELATED_X), T.(CORRELATED_Y)
  f = LeastSquaresLoss(y, X)
  x0 = T[0.125, -0.0625, 0.0, 0.03125]
  function refused(g, ff = f, x1 = x0; kw...)
    x = copy(x1)
    msg = refusal_message(() -> solve!(x, ff, g, method, OPTIONS; kw...))
    @test !isempty(msg) && isequal(x, x1)
    msg
  end
  # the keyword with another penalty or of another type, and an unknown keyword
  for g in (NormL1(T(0.1)), IndBallL2(T(1)), IndBox(T(-1), T(1)))
    @test occursin("applies only to IndBallL1", refused(g; feasibility = NumericalFeasibility()))
  end
  @test occursin("must be a NumericalFeasibility", refused(IndBallL1(T(0.6)); feasibility = 1e-5))
  @test occursin("unsupported solve! keywords", refused(IndBallL1(T(0.6)); other = 1))
  # losses, storage and data
  @test occursin("SqrtLeastSquaresLoss", refused(IndBallL1(T(0.6)), SqrtLeastSquaresLoss(y, X)))
  @test occursin("dense Vector", refused(IndBallL1(T(0.6)), LeastSquaresLoss(T[1 0; 0 1; 1 1; 0 0], X), zeros(T, 4, 2)))
  @test occursin("dimensions", refused(IndBallL1(T(0.6)), f, zeros(T, 3)))
  T === Float64 && @test occursin("LogisticLoss", refused(IndBallL1(0.6), LogisticLoss([1.0, 0.0, 1.0, 0.0], X)))
  # data of the other precision, and a matrix response with a vector start
  S = T === Float32 ? Float64 : Float32
  @test occursin("mixed array types", refused(IndBallL1(T(0.6)), LeastSquaresLoss(S.(y), S.(X))))
  @test occursin("mixed array types", refused(IndBallL1(T(0.6)), LeastSquaresLoss(hcat(y, y), X)))
  # the radius: zero, infinite, of another type
  for g in (IndBallL1(zero(T)), IndBallL1(T(Inf)), IndBallL1(T === Float32 ? 0.6 : 0.6f0), IndBallL1(1))
    @test occursin("radius", refused(g))
  end
  # the tolerances, including a positive objective tolerance that is zero in Float64
  for name in (:coefficient_rtol, :objective_rtol, :mapping_rtol), bad in (NaN, -1e-3, "1e-5")
    @test occursin(String(name), refused(IndBallL1(T(0.6)); feasibility = NumericalFeasibility(; name => bad)))
  end
  @test occursin("objective_rtol", refused(IndBallL1(T(0.6)); feasibility = NumericalFeasibility(objective_rtol = big"1e-400")))
  # an infeasible start, and a curvature that overflows in T
  @test occursin("infeasible", refused(IndBallL1(T(0.1))))
  let Xh = copy(X)
    Xh[1, 1] = T === Float32 ? T(1e20) : T(1e200)
    @test occursin("curvature", refused(IndBallL1(T(0.6)), LeastSquaresLoss(y, Xh)))
  end
  # CDSolver refuses the keyword
  for g in (IndBallL1(T(0.6)), NormL1(T(0.1)))
    x = copy(x0)
    @test occursin("unsupported solve! keywords: feasibility",
                   refusal_message(() -> solve!(x, f, g, CDSolver(); feasibility = NumericalFeasibility()))) && x == x0
  end
end

# Fully subnormal or underflowing scales fail closed: a design with a nonzero column needs a normal curvature (in
# Float64 and in T) and normal budgets.
@testset "gate: underflowed curvature or budgets ($(mname(method)))" for method in METHODS
  function refused_underflow(x0, f, g, expected)
    x = copy(x0)
    @test occursin(expected, refusal_message(() -> solve!(x, f, g, method, OPTIONS)))
    @test reinterpret(UInt8, x) == reinterpret(UInt8, x0)
  end
  # a subnormal curvature 1e-310 in Float64, with a gap budget that underflows to zero
  refused_underflow([1e-15], LeastSquaresLoss([0.0], reshape([1e-155], 1, 1)), IndBallL1(1e-14), "subnormal")
  # a normal curvature 1e-300 with subnormal budgets
  refused_underflow([0.0], LeastSquaresLoss([1e-150], reshape([1e-150], 1, 1)), IndBallL1(0.5), "subnormal")
  # Float32: a curvature 1e-38 that is normal in Float64 and subnormal in Float32, and fully subnormal data, whose
  # curvature 1e-80 rounds to zero in Float32
  refused_underflow([0.0f0], LeastSquaresLoss([2f-19], reshape([1f-19], 1, 1)), IndBallL1(1.0f0), "subnormal")
  refused_underflow([0.0f0], LeastSquaresLoss([2f-40], reshape([1f-40], 1, 1)), IndBallL1(1.0f0), "curvature")
end

# ---- the default route and the override -----------------------------------------------------------------------------------

@testset "default route without the keyword, and the override ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  X, y = T.(CORRELATED_X), T.(CORRELATED_Y)
  f = LeastSquaresLoss(y, X)
  # without the keyword the route runs with the default tolerances: the same coefficients (bitwise), convergence flag
  # and iteration count as the explicit default
  x1, x2 = zeros(T, 4), zeros(T, 4)
  r1 = solve!(x1, f, IndBallL1(T(0.6)), method, OPTIONS)
  r2 = solve!(x2, f, IndBallL1(T(0.6)), method, OPTIONS; feasibility = NumericalFeasibility())
  @test reinterpret(UInt8, x1) == reinterpret(UInt8, x2)
  @test (r1.converged, r1.iterations) == (r2.converged, r2.iterations)
  check_result_fields(x1, r1, f)
  # the override changes the tolerances: a start on the boundary passes the default cap and is unresolved with a zero cap
  x0 = T[0.125, -0.0625, 0.0, 0.03125]
  g = IndBallL1(T(sum(abs, x0)))
  @test solve!(copy(x0), f, g, method, OPTIONS) isa PS.OptimizationResults
  x = copy(x0)
  msg = refusal_message(() -> solve!(x, f, g, method, OPTIONS;
                                     feasibility = NumericalFeasibility(coefficient_rtol = 0, coefficient_atol = 0)))
  @test occursin("unresolved", msg) && x == x0
end

# ---- accepted-point accuracy on the #508 fixtures ---------------------------------------------------------------------------

# Every reported success meets the #514 targets against the independent MPFR quantities, and the minimum is the last
# traced objective. Which fixtures succeed is pinned only by the analytic cases below.
@testset "#508 fixtures: independent MPFR check of each success ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  successes = 0
  for d in fixtures(T)
    @testset "$(d.name)" begin
      x, res = solve_fixture(d, method; options = ProximalOptions(maxiter = 320, store_trace = true))
      check_result_fields(x, res, loss(d); fg = isempty(res.trace) ? nothing : res.trace[end].fg_x)
      if res.converged
        successes += 1
        @test acceptable(d.X, d.y, d.alpha, d.r, x)
      end
    end
  end
  @test successes > 0
end

@testset "converged and the minimum on analytic fixtures ($(mname(method)))" for method in METHODS
  # [1, eps/4] at r = 1, with y = x: a zero gradient at a point exactly outside the ball, whose widened mass exceeds r
  # in Float32 (1 + 2⁻²⁵, and ProximalBase's projection copies the point) and rounds to r in Float64. The full check
  # passes at the radial witness, so converged is true (IN-12), and the minimum is the monitored objective f_x + g_x,
  # the cached loss, which the trace also reports.
  traced = ProximalOptions(maxiter = 320, store_trace = true)
  for T in (Float32, Float64)
    d = fixture(T, "stationary_tail_0.25_eps")
    x, res = solve_fixture(d, method; options = traced)
    @test res.converged
    @test setprecision(BigFloat, 256) do
      sum(abs, BigFloat.(x)) > d.r
    end
    @test sum(a -> abs(Float64(a)), x) == (T === Float32 ? 1 + 2.0^-25 : 1.0)
    T === Float32 && @test x == d.start && res.minimum == 0
    @test res.minimum == res.trace[end].fg_x
    @test isapprox(res.minimum, loss(d)(x); rtol = 64eps(T), atol = 64floatmin(T))
    @test acceptable(d.X, d.y, d.alpha, d.r, x)
  end
  # an interior solution converges, with the cached loss as its minimum
  for T in (Float32, Float64)
    d = fixture(T, "l1_correlated_interior")
    x, res = solve_fixture(d, method; options = traced)
    @test res.converged
    @test setprecision(BigFloat, 256) do
      sum(abs, BigFloat.(x)) < d.r
    end
    @test res.minimum == res.trace[end].fg_x && isapprox(res.minimum, loss(d)(x); rtol = 64eps(T))
    @test acceptable(d.X, d.y, d.alpha, d.r, x)
  end
end

# ---- false stationarity under underflow ---------------------------------------------------------------------------------

mutable struct CheckStub{T}
  x::Vector{T}
  grad_calls::Int
  prox_calls::Int
end

# The scaled reproducer: X = 1e-155, x = 1e-15, loss scale 1e300. The unscaled Xᵀ(X w - y), about 1e-325, underflows
# to zero before the multiplication by 1e300, so the computed gradient is zero while the exact one is about 1e-25. The
# gate admits the problem (normal curvature 1e-10 and normal budgets); the underflow allowance of the full check fails
# it (FP-05).
@testset "false stationarity: the scaled underflow reproducer ($(mname(method)))" for method in METHODS
  X, y, alpha, r = reshape([1e-155], 1, 1), [0.0], 1e300, 1e-14
  f = alpha * LeastSquaresLoss(y, X)
  # the full check at the start: the computed gradient is exactly zero, and the check fails
  tol = PS._feasibility_tolerances(NumericalFeasibility(), Float64)
  b = PS._l1_budgets(X, y, alpha, r, tol)
  ball = IndBallL1(r)
  route = PS._NumericalL1Ball(ball, X, y, alpha, b, tol, PS._l1_decision([1e-15], ball, b.cap))
  stub = CheckStub([1e-15], 0, 0)
  @test !PS._stationary!(stub, f, route, OPTIONS)
  @test all(iszero, route.gradient)
  # one full check counts one gradient and one projection (STOP-08)
  @test stub.grad_calls == 1 && stub.prox_calls == 1
  # the solve does not report converged, and the returned point misses the budgets in MPFR
  x = [1e-15]
  res = solve!(x, f, IndBallL1(r), method, OPTIONS)
  @test !res.converged
  @test !acceptable(X, y, alpha, r, x)
end

# One example for the factor 2 of the mapping's underflow allowance (FP-05): the exact ℓ1-ball projection is
# 2-Lipschitz in the ∞-norm, not nonexpansive; with ProximalBase's projection this pair expands by 4/3
@testset "an ∞-norm expansion example of the ℓ1-ball projection, ratio 4/3 ($T)" for T in (Float32, Float64)
  ball = IndBallL1(T(3))
  z, z2 = T[3, 3, 3], T[3.125, 2.875, 2.875]
  ratio = Float64(maximum(abs, ProximalBase.prox(ball, z) - ProximalBase.prox(ball, z2))) / Float64(maximum(abs, z - z2))
  @test 1 < ratio <= 2 && isapprox(ratio, 4 / 3; rtol = 64eps(T))
end

# The overflow reproducer (Float32, with a tolerance override): the Hessian is exactly 2⁻¹²⁶ I, so the mapping's trial
# point is y/d = b [4.5, 1.75, 0, 0] (b = 2¹²⁶) for any witness, and its first entry overflows to Inf in Float32.
# Before the guard, the check projected that point: ProximalBase maps the overflowed entry to a finite vertex, so the
# computed mapping was finite and within its budget, while the exact mapping is not. The guarded check fails on the
# nonfinite trial point and skips that projection (FP-05).
@testset "false stationarity: an overflowed mapping trial point ($(mname(method)))" for method in METHODS
  d, b = ldexp(1f0, -70), ldexp(1f0, 126)
  X = Matrix(Diagonal(fill(d, 4)))
  y = ldexp(1f0, 56) .* Float32[4.5, 1.75, 0, 0]
  alpha = ldexp(1f0, 14)
  f = alpha * LeastSquaresLoss(y, X)
  a = NumericalFeasibility(objective_rtol = 0.15, mapping_rtol = 0.01)
  r = 3b
  x = Float32[3b, 0, 0, 0]
  res = solve!(x, f, IndBallL1(r), method, ProximalOptions(maxiter = 2, callback = _ -> true); feasibility = a)
  @test !res.converged
  # the exact mapping at the returned point exceeds its budget in MPFR, so a success would be false
  tol = PS._feasibility_tolerances(a, Float32)
  bud = PS._l1_budgets(X, y, Float64(alpha), Float64(r), tol)
  ind = independent(X, y, alpha, r, x, bud.curvature)
  @test ind.mapping > BigFloat(bud.mapping)
  # the full check at that point fails, after one gradient and without a projection
  ball = IndBallL1(r)
  dec = PS._l1_decision(x, ball, bud.cap)
  @test dec.code === :pass
  route = PS._NumericalL1Ball(ball, X, y, Float64(alpha), bud, tol, dec)
  stub = CheckStub(copy(x), 0, 0)
  @test !PS._stationary!(stub, f, route, OPTIONS)
  @test route.checked && !all(isfinite, route.trial)
  @test stub.grad_calls == 1 && stub.prox_calls == 0
end

# An overflowed 2L in the division allowance (Float64, with a tolerance override): X = 1e154, y = 1e-171, radius
# 1e-150, start 0. The stored curvature L is about 1e308, so 2L overflows to Inf, while the computed quotient δ/L of the
# gradient scale δ ≈ 1e-17 rounds to zero; the mapping trial and its projection are then zero. The division term of
# the mapping allowance, 2 min(L η, δ) = 2δ (η = nextfloat(0.0), FP-05), uses neither 2L nor δ/L and exceeds the
# mapping budget, so the check fails. The exact mapping at the returned point exceeds its budget in MPFR. APG's small β
# lets its trials reach that curvature.
@testset "false stationarity: an overflowed factor of the division allowance ($(mname(method)))" for method in
    (ProximalGradientDescent(), AccProxGradDescent(β = 1 / 10^(308.1 / 60)))
  X, y, r = reshape([1e154], 1, 1), [1e-171], 1e-150
  f = LeastSquaresLoss(y, X)
  a = NumericalFeasibility(mapping_rtol = 1e-180)
  x = [0.0]
  res = solve!(x, f, IndBallL1(r), method, ProximalOptions(maxiter = 2, callback = _ -> true); feasibility = a)
  @test !res.converged
  tol = PS._feasibility_tolerances(a, Float64)
  bud = PS._l1_budgets(X, y, 1.0, r, tol)
  @test isinf(2 * bud.curvature)
  # the exact mapping at the returned point exceeds its budget in MPFR, so a success would be false
  ind = independent(X, y, 1.0, r, x, bud.curvature)
  @test ind.mapping > BigFloat(bud.mapping)
  # the full check at that point: δ is positive, δ/L is zero, the projection is reached, and the check fails
  ball = IndBallL1(r)
  dec = PS._l1_decision(x, ball, bud.cap)
  @test dec.code === :pass
  route = PS._NumericalL1Ball(ball, X, y, 1.0, bud, tol, dec)
  stub = CheckStub(copy(x), 0, 0)
  @test !PS._stationary!(stub, f, route, OPTIONS)
  δ = maximum(abs, route.gradient)
  @test δ > 0 && iszero(δ / bud.curvature)
  @test stub.grad_calls == 1 && stub.prox_calls == 1
end

# A finite 2L with a quotient δ/L that rounds to zero (Float64, with a tolerance override): X = 1e153,
# y = 1e-172, radius 1e-150, start 0. The stored curvature L is about 1e306, so 2L is finite, and δ ≈ 1e-19, so δ/L
# rounds to zero; the mapping trial, its projection and the computed mapping are zero. Before FP-05 formed the division
# term as 2 min(L η, δ), the term 2L min(η, δ/L) was zero as well and the check passed. The exact mapping, about 1e-19,
# exceeds its budget, about 1e-24, in MPFR.
@testset "false stationarity: a division quotient that rounds to zero ($(mname(method)))" for method in
    (ProximalGradientDescent(), AccProxGradDescent(β = 1 / 10^(306.1 / 60)))
  X, y, r = reshape([1e153], 1, 1), [1e-172], 1e-150
  f = LeastSquaresLoss(y, X)
  a = NumericalFeasibility(mapping_rtol = 1e-180)
  x = [0.0]
  res = solve!(x, f, IndBallL1(r), method, ProximalOptions(maxiter = 2, callback = _ -> true); feasibility = a)
  @test !res.converged
  tol = PS._feasibility_tolerances(a, Float64)
  bud = PS._l1_budgets(X, y, 1.0, r, tol)
  @test isfinite(2 * bud.curvature)
  # the exact mapping at the returned point exceeds its budget in MPFR, so a success would be false
  ind = independent(X, y, 1.0, r, x, bud.curvature)
  @test ind.mapping > BigFloat(bud.mapping)
  # the full check at that point: δ is positive, δ/L is zero, the projection is reached, and the check fails
  ball = IndBallL1(r)
  dec = PS._l1_decision(x, ball, bud.cap)
  @test dec.code === :pass
  route = PS._NumericalL1Ball(ball, X, y, 1.0, bud, tol, dec)
  stub = CheckStub(copy(x), 0, 0)
  @test !PS._stationary!(stub, f, route, OPTIONS)
  δ = maximum(abs, route.gradient)
  @test δ > 0 && iszero(δ / bud.curvature) && all(iszero, route.projected)
  @test stub.grad_calls == 1 && stub.prox_calls == 1
end

# A zero design with a zero response: the budgets are zero, the start 0 is exactly stationary, and every term of the
# allowance is an exact zero, including the final product by L of a zero difference (FP-05), so the full check passes.
@testset "a zero design: zero budgets and an exactly stationary start ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  X, y, r = zeros(T, 2, 2), zeros(T, 2), one(T)
  f = LeastSquaresLoss(y, X)
  tol = PS._feasibility_tolerances(NumericalFeasibility(), T)
  bud = PS._l1_budgets(X, y, 1.0, Float64(r), tol)
  @test iszero(bud.gap) && iszero(bud.mapping)
  ball = IndBallL1(r)
  route = PS._NumericalL1Ball(ball, X, y, 1.0, bud, tol, PS._l1_decision(zeros(T, 2), ball, bud.cap))
  stub = CheckStub(zeros(T, 2), 0, 0)
  @test PS._stationary!(stub, f, route, OPTIONS)
  @test stub.grad_calls == 1 && stub.prox_calls == 1
  x = zeros(T, 2)
  res = solve!(x, f, IndBallL1(r), method, ProximalOptions(maxiter = 5, ftol = 0))
  @test res.converged && res.iterations == 1 && iszero(x)
end

# ---- boundary rounding: the cap at each accepted iterate ---------------------------------------------------------------------

# Every accepted iterate passes the cap, recomputed from the callback's vector, and the reported minimum is the last
# callback objective; on the active_transition fixtures the radius sits one ulp below, at and one ulp above
# the projection's threshold.
@testset "each accepted iterate passes the recomputed cap decision ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  for d in fixtures(T; big = false)
    cap = route_budgets(d.X, d.y, d.alpha, d.r).cap
    passed, objectives = Bool[], Float64[]
    x = copy(d.start)
    function record(os)
      push!(passed, PS._l1_decision(x, IndBallL1(d.r), cap).code === :pass)
      push!(objectives, os.fg_x)
      false
    end
    res = solve!(x, loss(d), IndBallL1(d.r), method, ProximalOptions(maxiter = 320, callback = record))
    @test length(passed) == res.iterations && all(passed)
    check_result_fields(x, res, loss(d); fg = isempty(objectives) ? nothing : objectives[end])
  end
end

# ---- B1's progress proposals and objective increases -------------------------------------------------------------------

# The engine of _solve_gradient! driven by hand: per iteration, the gradient and prox calls of convergence_assessment,
# which count the evaluations that its full checks perform, until a success. The fixtures below reach the projection
# whenever they check, so there each check counts one of each.
function checks_per_iteration(d::Fixture, method, options, a)
  x, f = copy(d.start), loss(d)
  c = PS._check_numerical_l1(x, f, IndBallL1(d.r), a, method, :gradient)
  route = PS._NumericalL1Ball(IndBallL1(d.r), c.data.X, c.data.Y, c.alpha, c.budgets, c.tolerances, c.decision)
  state = PS.initial_state(method, options, f, route, x)
  counts, objective_proposal = Int[], Bool[]
  for _ in 1:options.maxiter
    PS._gradient_step!(state, f, route, method, options, time())
    grad0, prox0 = state.grad_calls, state.prox_calls
    converged = PS.convergence_assessment(state, f, route, options)[4]
    push!(counts, state.grad_calls - grad0)
    push!(objective_proposal, PS.f_residual(state.f_x, state.f_x_previous, options.ftol) < options.ftol)
    @test state.prox_calls - prox0 == counts[end]
    converged && break
  end
  counts, objective_proposal
end

# At most one full check per iteration. With a mapping tolerance far below the rounding allowance the checks fail (a
# pass would end the loop early), and with objective_rtol = 1e-3 an iteration with f_residual < ftol = 1e-6 meets both
# the engine's objective test and B1's objective proposal: it still runs one check. Iterations with no proposal run none.
@testset "at most one full check per iteration ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  for d in fixtures(T; big = false)
    counts, _ = checks_per_iteration(d, method, OPTIONS, NumericalFeasibility())
    @test all(<=(1), counts)
  end
  d = fixture(T, "l1_correlated_active")
  counts, proposal = checks_per_iteration(d, method, ProximalOptions(maxiter = 100),
                                          NumericalFeasibility(mapping_rtol = 1e-30, objective_rtol = 1e-3))
  @test length(counts) == 100 && all(<=(1), counts) && 0 in counts
  @test any(proposal) && all(==(1), counts[proposal])
end

# Solves that the engine's tests do not stop (ftol = 0): B1's unchanged-iterate and progress proposals trigger the
# full check at the first iteration, and each success passes the independent MPFR check.
@testset "progress proposals stop at the first iteration ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  I2 = Matrix{T}(I, 2, 2)
  for d in (fixture(T, "rounded_zero_predictor"), fixture(T, "stationary_tail_0.25_eps"),
            Fixture{T}("l1_exact_boundary_stop", I2, T[0.75, 0.75], T(1.5), T[0.75, 0.75], one(T)))
    x, res = solve_fixture(d, method; options = ProximalOptions(maxiter = 320, ftol = 0))
    @test res.iterations == 1 && res.converged
    check_result_fields(x, res, loss(d))
    @test acceptable(d.X, d.y, d.alpha, d.r, x)
  end
end

# x0 = [1, 2 eps] with y = x0 and r = 1: the start has a zero loss, and the first projection moves it to the boundary,
# which raises the loss. A mapping tolerance far below the rounding allowance keeps the full check from passing. With
# allow_f_increases = false the increase is reported in f_increased and the solve continues.
@testset "an objective increase is reported and does not end the solve ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  x0 = T[1, 2eps(T)]
  f, g = LeastSquaresLoss(copy(x0), Matrix{T}(I, 2, 2)), IndBallL1(one(T))
  a = NumericalFeasibility(mapping_rtol = 1e-30)
  # a callback stop after the first iteration reports that iteration's increase
  res = solve!(copy(x0), f, g, method, ProximalOptions(maxiter = 6, callback = _ -> true); feasibility = a)
  @test res.iterations == 1 && res.f_increased && !res.converged
  x1, x2 = copy(x0), copy(x0)
  res = solve!(x1, f, g, method, ProximalOptions(maxiter = 6, store_trace = true); feasibility = a)
  @test res.iterations == 6 && res.iteration_converged && !res.converged
  @test res.trace[1].fg_x > f(x0)
  res2 = solve!(x2, f, g, method, ProximalOptions(maxiter = 6, allow_f_increases = true); feasibility = a)
  @test reinterpret(UInt8, x1) == reinterpret(UInt8, x2) && res.f_increased == res2.f_increased
end

# ---- line-search errors and rollback ----------------------------------------------------------------------------------------

# A trial accepted at Lexact whose working gradient overflows: Float32 singleton X = 1.8, y = -0.8, loss scale 1e38,
# start -0.5, radius 0.7. The projected trial 0.7 is accepted at L = 1 and its scaled gradient, about 3.7e38, overflows.
@testset "PGD: a nonfinite gradient at the accepted trial raises and restores the start" begin
  T = Float32
  x0 = T[-0.5]
  f = T(1e38) * LeastSquaresLoss(T[-0.8], reshape(T[1.8], 1, 1))
  method = ProximalGradientDescent(ls = PS.LineSearches.BackTracking(Lexact = 1.0))
  calls = Ref(0)
  x = copy(x0)
  err = try
    solve!(x, f, IndBallL1(T(0.7)), method, ProximalOptions(callback = _ -> (calls[] += 1; true)))
    nothing
  catch e
    e
  end
  @test err isa ErrorException && occursin("nonfinite", err.msg) && occursin("gradient", err.msg)
  @test reinterpret(UInt8, x) == reinterpret(UInt8, x0)
  @test calls[] == 0
end

# The underflow reproducer (Float64, default numerical settings): X = 1, y = 1e-170, loss scale 1e150, radius 4e-170,
# start 5e-171. At L = 0.9 the projected trial 4e-170 differs from the start, but the squared norm of the step, about
# 1.2e-339, underflows to zero, and the shared backtrack! accepts it as a zero step without its test (LS-02). The route raises
# the line-search error instead, and the engine restores the start (IN-12). APG declines the trial and raises the
# 64-trial error.
@testset "a nonzero step whose squared norm underflows ($(mname(method)))" for method in METHODS
  X, y, alpha, r, x0 = reshape([1.0], 1, 1), [1e-170], 1e150, 4e-170, [5e-171]
  f = alpha * LeastSquaresLoss(y, X)
  x = copy(x0)
  err = try
    solve!(x, f, IndBallL1(r), method, ProximalOptions(maxiter = 5, store_trace = true))
    nothing
  catch e
    e
  end
  expected = method isa ProximalGradientDescent ? "squared norm underflows" : "64 trials"
  @test err isa ErrorException && occursin("line search failed", err.msg) && occursin(expected, err.msg)
  @test reinterpret(UInt8, x) == reinterpret(UInt8, x0)
  if method isa ProximalGradientDescent
    # PGD's step driven by hand: the error leaves the accepted trial in state.x (the engine's rollback is outside the
    # step), with no counted backtracking step; the smooth majorization condition fails there in MPFR
    x = copy(x0)
    c = PS._check_numerical_l1(x, f, IndBallL1(r), NumericalFeasibility(), method, :gradient)
    route = PS._NumericalL1Ball(IndBallL1(r), c.data.X, c.data.Y, c.alpha, c.budgets, c.tolerances, c.decision)
    state = PS.initial_state(method, OPTIONS, f, route, x)
    err = try
      PS._gradient_step!(state, f, route, method, OPTIONS, time())
      nothing
    catch e
      e
    end
    @test err isa ErrorException && occursin("squared norm underflows", err.msg)
    @test state.x_previous == x0 && state.x != x0 && state.backtrack_steps == 0
    @test iszero(norm(state.x - state.x_previous)^2)
    setprecision(BigFloat, 256) do
      loss_big(v) = BigFloat(alpha) / 2 * (BigFloat(v) - BigFloat(y[1]))^2
      v0, v1 = BigFloat(x0[1]), BigFloat(state.x[1])
      grad0 = BigFloat(alpha) * (v0 - BigFloat(y[1]))
      @test loss_big(v1) > loss_big(v0) + grad0 * (v1 - v0) + BigFloat(state.L) / 2 * (v1 - v0)^2
      @test loss_big(v1) > 30 * loss_big(v0)
    end
  end
end

# On this fixture a truly unchanged step is still accepted: X = 1, y = x = 0.5, radius 1 has a zero gradient, so the
# first trial returns the start (for APG the extrapolated point equals the previous point), and the unchanged-iterate
# proposal's check passes inside the ball.
@testset "an unchanged step is accepted ($(mname(method)))" for method in METHODS
  x0 = [0.5]
  x = copy(x0)
  res = solve!(x, LeastSquaresLoss([0.5], reshape([1.0], 1, 1)), IndBallL1(1.0), method,
               ProximalOptions(maxiter = 5, ftol = 0))
  @test res.converged && res.iterations == 1 && reinterpret(UInt8, x) == reinterpret(UInt8, x0)
end

@testset "rollback and the 64-trial error ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  # a callback stop returns the accepted iterate of that iteration
  d = fixture(T, "l1_correlated_active")
  snapshot = T[]
  x = copy(d.start)
  stop3(s) = (s.iteration == 3 && append!(snapshot, x); s.iteration == 3)
  res = solve!(x, loss(d), IndBallL1(d.r), method, ProximalOptions(maxiter = 320, callback = stop3))
  @test res.iterations == 3 && reinterpret(UInt8, x) == reinterpret(UInt8, snapshot)
  # with a zero cap, a start inside the ball by just more than the rounding allowance and a far response, each trial
  # projects onto the boundary (unresolved) until the step is too short, which needs more than 64 doublings of L; the
  # attempted 65th trial forms its step and raises the line-search error before its projection, and x is restored
  r = one(T)
  x0 = T === Float32 ? fill(prevfloat(T(0.5), 4), 2) : fill(0.5 - ldexp(1.0, -51), 2)
  f = LeastSquaresLoss(fill(T(1e15), 2), Matrix{T}(I, 2, 2))
  @test PS._l1_decision(x0, IndBallL1(r), 0.0).code === :pass
  x = copy(x0)
  err = try
    solve!(x, f, IndBallL1(r), method, OPTIONS; feasibility = NumericalFeasibility(coefficient_rtol = 0, coefficient_atol = 0))
    nothing
  catch e
    e
  end
  @test err isa ErrorException && occursin("line search failed", err.msg) && occursin("64 trials", err.msg)
  @test reinterpret(UInt8, x) == reinterpret(UInt8, x0)
end

end
