module L1BallNumericalTest

# The IndBallL1 route of PGD and APG (IN-12, FP-05): the gate, the default route and the tolerance override, an
# independent MPFR check of each reported success on the #508 fixtures, converged against approximate_solution and the
# reported minimum, false stationarity under underflow, the cached decision, rollback and the line-search errors.

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

# A point of the ball near z: z itself when it is inside, otherwise z scaled down until its BigFloat ℓ1 norm is ≤ r
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

# The membership of x recomputed from its definition in FP-05 (the widened mass with the same reduction)
function membership(x, r)
  s = sum(a -> abs(Float64(a)), x)
  m = s - Float64(r)
  c = (length(x) + 2) * (eps(Float64) / 2)
  noise = c / (1 - c) * max(s, Float64(r))
  m > noise ? :outside : m < -noise ? :inside : iszero(s) && r > 0 ? :inside : :unknown
end

# The result of a route solve with loss f and radius r: the reported minimum against the recomputed membership of the
# returned point, and the two success flags against each other and against the proposal flags
function check_result_fields(x, res, f, r)
  T = eltype(x)
  @test res.minimizer === x
  side = membership(x, r)
  if side === :inside
    @test isapprox(res.minimum, f(x); rtol = 64eps(T), atol = 64floatmin(T))
  elseif side === :outside
    @test res.minimum == Inf
  else
    @test isnan(res.minimum)
  end
  @test !(res.converged && res.approximate_solution)
  res.converged && @test side === :inside && (res.x_converged || res.f_converged || res.grad_converged)
  res.approximate_solution && @test side !== :inside && !res.x_converged && !res.f_converged && !res.grad_converged
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
  # without the keyword the route runs with the default tolerances: the same result as the explicit default
  x1, x2 = zeros(T, 4), zeros(T, 4)
  r1 = solve!(x1, f, IndBallL1(T(0.6)), method, OPTIONS)
  r2 = solve!(x2, f, IndBallL1(T(0.6)), method, OPTIONS; feasibility = NumericalFeasibility())
  @test reinterpret(UInt8, x1) == reinterpret(UInt8, x2)
  @test (r1.converged, r1.approximate_solution, r1.iterations) == (r2.converged, r2.approximate_solution, r2.iterations)
  check_result_fields(x1, r1, f, T(0.6))
  # the override changes the tolerances: a start on the boundary passes the default cap and is unresolved with a zero cap
  x0 = T[0.125, -0.0625, 0.0, 0.03125]
  g = IndBallL1(T(sum(abs, x0)))
  @test solve!(copy(x0), f, g, method, OPTIONS) isa PS.OptimizationResults
  x = copy(x0)
  msg = refusal_message(() -> solve!(x, f, g, method, OPTIONS;
                                     feasibility = NumericalFeasibility(coefficient_rtol = 0, coefficient_atol = 0)))
  @test occursin("unresolved", msg) && x == x0
  # the other penalties report no approximate solution and the composite minimum
  x = zeros(T, 4)
  res = solve!(x, f, NormL1(T(0.1)), method)
  @test !res.approximate_solution && isapprox(res.minimum, f(x) + NormL1(T(0.1))(x); rtol = 64eps(T))
  @test !occursin("Approximate solution", sprint(show, res))
end

# ---- accepted-point accuracy on the #508 fixtures ---------------------------------------------------------------------------

# Every reported success meets the #514 targets against the independent MPFR quantities, and the minimum follows the
# recomputed membership. The success class of a fixture is pinned only by the analytic cases below.
@testset "#508 fixtures: independent MPFR check of each success ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  successes = 0
  for d in fixtures(T)
    @testset "$(d.name)" begin
      x, res = solve_fixture(d, method)
      check_result_fields(x, res, loss(d), d.r)
      if res.converged || res.approximate_solution
        successes += 1
        @test acceptable(d.X, d.y, d.alpha, d.r, x)
      end
    end
  end
  @test successes > 0
end

@testset "converged, approximate_solution and the minimum on analytic fixtures ($(mname(method)))" for method in METHODS
  # Float32 [1, eps/4] at r = 1, with y = x: a zero gradient and ProximalBase's Float32 sum 1, so the projection copies
  # the point, whose widened mass 1 + 2⁻²⁵ exceeds r by more than the rounding allowance. The check passes outside the
  # ball: an approximate solution, not converged, with minimum Inf; the trace's objective is the loss 0.
  d = fixture(Float32, "stationary_tail_0.25_eps")
  x, res = solve_fixture(d, method; options = ProximalOptions(maxiter = 320, store_trace = true))
  @test res.approximate_solution && !res.converged && x == d.start
  @test membership(x, d.r) === :outside && res.minimum == Inf && res.trace[end].fg_x == 0
  @test occursin("Approximate solution", sprint(show, res))
  # Float64 [1, eps/4] at r = 1: the widened mass rounds to 1, so the point is not classified: minimum NaN
  d = fixture(Float64, "stationary_tail_0.25_eps")
  x, res = solve_fixture(d, method)
  @test res.approximate_solution && !res.converged && membership(x, d.r) === :unknown && isnan(res.minimum)
  # an interior solution converges inside the ball, with the loss as its minimum
  for T in (Float32, Float64)
    d = fixture(T, "l1_correlated_interior")
    x, res = solve_fixture(d, method)
    @test res.converged && !res.approximate_solution && membership(x, d.r) === :inside
    @test isapprox(res.minimum, loss(d)(x); rtol = 64eps(T))
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
  # the solve reports neither success, and the returned point misses the budgets in MPFR
  x = [1e-15]
  res = solve!(x, f, IndBallL1(r), method, OPTIONS)
  @test !res.converged && !res.approximate_solution
  @test !acceptable(X, y, alpha, r, x)
end

# The factor 2 of the mapping's underflow allowance (FP-05): the ℓ1-ball projection is 2-Lipschitz in the ∞-norm, not
# nonexpansive; this pair expands by 4/3
@testset "the ℓ1-ball projection expands an ∞-norm difference by at most 2 ($T)" for T in (Float32, Float64)
  ball = IndBallL1(T(3))
  z, z2 = T[3, 3, 3], T[3.125, 2.875, 2.875]
  ratio = Float64(maximum(abs, ProximalBase.prox(ball, z) - ProximalBase.prox(ball, z2))) / Float64(maximum(abs, z - z2))
  @test 1 < ratio <= 2 && isapprox(ratio, 4 / 3; rtol = 64eps(T))
end

# ---- boundary rounding: the cached decision -------------------------------------------------------------------------------

# Every accepted iterate passes the cap, and the reported minimum follows the decision of the returned point; on the
# active_transition fixtures the radius sits one ulp below, at and one ulp above the projection's threshold.
@testset "cached decision at each accepted iterate ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  for d in fixtures(T; big = false)
    cap = route_budgets(d.X, d.y, d.alpha, d.r).cap
    passed = Bool[]
    x = copy(d.start)
    record(_) = (push!(passed, PS._l1_decision(x, IndBallL1(d.r), cap).code === :pass); false)
    res = solve!(x, loss(d), IndBallL1(d.r), method, ProximalOptions(maxiter = 320, callback = record))
    @test length(passed) == res.iterations && all(passed)
    check_result_fields(x, res, loss(d), d.r)
  end
end

# ---- B1's progress proposals and objective increases -------------------------------------------------------------------

# The engine of _solve_gradient! driven by hand: per iteration, the gradient and prox calls of convergence_assessment,
# which are those of the full checks it runs (one each per check), until a success.
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
    (converged || route.approximate) && break
  end
  counts, objective_proposal
end

# At most one full check per iteration. With a mapping tolerance far below the rounding allowance every check fails,
# and objective_rtol = 1e-3 makes B1's objective proposal hold whenever the engine's objective test (ftol = 1e-6) does:
# such an iteration still runs one check, and an iteration with no proposal runs none.
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
    @test res.iterations == 1 && (res.converged || res.approximate_solution)
    check_result_fields(x, res, loss(d), d.r)
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
  res = solve!(copy(x0), f, g, method, ProximalOptions(maxiter = 1); feasibility = a)
  @test res.iterations == 1 && res.f_increased && !res.converged && !res.approximate_solution
  x1, x2 = copy(x0), copy(x0)
  res = solve!(x1, f, g, method, ProximalOptions(maxiter = 6, store_trace = true); feasibility = a)
  @test res.iterations == 6 && res.iteration_converged && !res.converged && !res.approximate_solution
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
  # 65th trial raises the line-search error, and x is restored
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
