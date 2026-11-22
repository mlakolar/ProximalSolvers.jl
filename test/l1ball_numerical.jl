module L1BallNumericalTest

# The opt-in numerical IndBallL1 route of PGD and APG (#457 Phase B, policy B1 of #515): the gate (IN-12), the #508
# fixtures with an independent MPFR check of each of their reported successes (RES-04, STOP-22), the result semantics, the cached
# decision (PGD-09), rollback, allocations and the unchanged routes of the other penalties.

using Test, LinearAlgebra, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

setprecision(BigFloat, 256)

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

function solve_fixture(d::Fixture, method; feasibility = NumericalFeasibility(), options = OPTIONS)
  x = copy(d.start)
  r = solve!(x, loss(d), IndBallL1(d.r), method, options; feasibility)
  x, r
end

# ---- the independent MPFR check (research/issue-514/reference.jl, trimmed) ---------------------------------------------

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

# The four quantities of the #514 acceptance, from the stored data, the loss scale as supplied and the radius: the
# violation max(0, ‖x‖₁ - r), the support gap and the fixed-step mapping (at the inverse step T(curvature)) at the
# witness, and the change of the loss between x and the witness.
function independent(X::Matrix{T}, y, alpha, r, x, curvature) where T
  A, Y, s, R = bigdesign(X), BigFloat.(y), BigFloat(alpha), BigFloat(r)
  z = BigFloat.(x)
  signed = sum(abs, z) - R
  w = exact_witness(z, R)
  @test sum(abs, w) <= R
  grad = s .* bigtmul(A, bigmul(A, w) - Y)
  gap = max(zero(R), R * maximum(abs, grad) + dot(grad, w))
  L = BigFloat(T(curvature))
  mapping = L * maximum(abs, w - exact_project_l1(w .- grad ./ L, R))
  objective(v) = s / 2 * sum(abs2, bigmul(A, v) - Y)
  (; signed, violation = max(zero(R), signed), gap, mapping, change = abs(objective(z) - objective(w)))
end

# The budgets of B1 recomputed in the test with unscaled Float64 norms (the route scales them), so they agree with the
# route's to rounding: (cap, gap, mapping, curvature).
function test_budgets(X, y, alpha::Float64, r::Float64; crel, cabs, orel, mrel)
  col = maximum(norm(Float64.(c)) for c in eachcol(X))
  yscaled = sqrt(alpha) * norm(Float64.(y))
  M = sqrt(alpha) * col
  cost = M * yscaled + 1.5 * M^2 * r
  scale = max(yscaled, M * r)^2 / 2
  gap = orel * scale / 2
  (; cap = min(r, cabs + crel * r, iszero(cost) ? Inf : gap / cost), gap,
     mapping = mrel * M * max(yscaled, M * r), curvature = col > 0 ? alpha * col^2 : 1.0)
end
default_budgets(X::Matrix{T}, y, alpha, r) where T =
  T === Float32 ? test_budgets(X, y, Float64(alpha), Float64(r); crel = 1e-5, cabs = 0.0, orel = 1e-5, mrel = 1e-4) :
                  test_budgets(X, y, Float64(alpha), Float64(r); crel = 1e-10, cabs = 0.0, orel = 1e-9, mrel = 1e-8)

# A reported success meets the #514 targets against the independent quantities above.
function check_success(d::Fixture{T}, x, res) where T
  q = res.feasibility
  b = default_budgets(d.X, d.y, d.alpha, d.r)
  @test isapprox(q.cap, b.cap; rtol = 1e-12) && isapprox(q.gap_budget, b.gap; rtol = 1e-12) &&
        isapprox(q.mapping_budget, b.mapping; rtol = 1e-12)
  curvature = PS._l1_budgets(d.X, d.y, Float64(d.alpha), Float64(d.r), PS._feasibility_tolerances(NumericalFeasibility(), T)).curvature
  @test isapprox(curvature, b.curvature; rtol = 1e-12)
  ind = independent(d.X, d.y, d.alpha, d.r, x, curvature)
  @test ind.violation <= BigFloat(q.cap)
  @test ind.gap <= BigFloat(q.gap_budget)
  @test ind.mapping <= BigFloat(q.mapping_budget)
  @test ind.change <= BigFloat(q.gap_budget)
  # the reported membership is consistent with the exact signed margin when it claims a side
  q.membership === :inside && @test ind.signed <= 0
  q.membership === :outside && @test ind.signed > 0
  ind
end

# The result fields that depend on the membership (RES-04), for a result of the route on the data (X, y) of f,
# with radius r. The smooth minimum is compared with ProximalBase's value at x, with an absolute allowance for losses
# at the rounding level of the residual.
function check_result_fields(x, res, f, X, y, r)
  T = eltype(x)
  q = res.feasibility
  @test q isa PS.NumericalFeasibilityReport
  @test res.minimizer === x
  @test res.smooth_minimum isa T && isfinite(res.smooth_minimum)
  @test isapprox(res.smooth_minimum, f(x); rtol = 64eps(T), atol = 64eps(T)^2 * max(1, sum(abs2, Float64.(y))))
  @test q.margin === sum(a -> abs(Float64(a)), x) - Float64(r)
  if q.membership === :inside
    @test res.minimum === res.smooth_minimum
  elseif q.membership === :outside
    @test res.minimum == Inf
  else
    @test q.membership === :unknown && isnan(res.minimum)
  end
  @test !(res.converged && res.approximate_solution)
  res.converged && @test q.membership === :inside
  res.approximate_solution &&
    @test q.membership !== :inside && !res.x_converged && !res.f_converged && !res.grad_converged
  (res.converged || res.approximate_solution) && @test q.checks >= 1 && isfinite(q.gap) && isfinite(q.mapping)
  @test isnan(res.gap)
end
check_result_fields(d::Fixture, x, res) = check_result_fields(x, res, loss(d), d.X, d.y, d.r)

# ---- the gate ----------------------------------------------------------------------------------------------------------

refusal_message(f) = try
  f()
  ""
catch e
  e isa Union{ArgumentError, DimensionMismatch} ? sprint(showerror, e) : rethrow()
end

@testset "gate: refusals before any write ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  X, y = T.(CORRELATED_X), T.(CORRELATED_Y)
  f = LeastSquaresLoss(y, X)
  x0 = T[0.125, -0.0625, 0.0, 0.03125]
  ok = NumericalFeasibility()
  function refused(g, ff = f; kw...)
    x = copy(x0)
    msg = refusal_message(() -> solve!(x, ff, g, method; kw...))
    @test !isempty(msg)
    @test x == x0
    msg
  end
  # the strict default: IndBallL1 without the opt-in, with a message that names it
  @test occursin("feasibility = NumericalFeasibility()", refused(IndBallL1(T(0.6))))
  # the opt-in with another penalty, and a keyword value that is not a NumericalFeasibility
  for g in (NormL1(T(0.1)), IndBallL2(T(1)), IndBox(T(-1), T(1)), NormL2(T(0.1)))
    @test occursin("applies only to IndBallL1", refused(g; feasibility = ok))
  end
  @test occursin("must be a NumericalFeasibility", refused(IndBallL1(T(0.6)); feasibility = 1e-5))
  @test occursin("unsupported solve! keywords", refused(IndBallL1(T(0.6)); feasibility = ok, other = 1))
  # losses and coefficient storage outside the route
  @test occursin("SqrtLeastSquaresLoss", refused(IndBallL1(T(0.6)), SqrtLeastSquaresLoss(y, X); feasibility = ok))
  let B = zeros(T, 4, 2), Y = T[1 0; 0 1; 1 1; 0 0], Bc = copy(B)
    msg = refusal_message(() -> solve!(B, LeastSquaresLoss(Y, X), IndBallL1(T(0.6)), method; feasibility = ok))
    @test occursin("dense Vector", msg) && B == Bc
  end
  let x = zeros(T, 3)
    msg = refusal_message(() -> solve!(x, f, IndBallL1(T(0.6)), method; feasibility = ok))
    @test occursin("dimensions", msg) && x == zeros(T, 3)
  end
  # the radius: zero, infinite, of another type
  @test occursin("radius", refused(IndBallL1(zero(T)); feasibility = ok))
  @test occursin("radius", refused(IndBallL1(T(Inf)); feasibility = ok))
  @test occursin("radius", refused(IndBallL1(T === Float32 ? 0.6 : 0.6f0); feasibility = ok))
  @test occursin("radius", refused(IndBallL1(1); feasibility = ok))
  # the tolerances
  for name in (:coefficient_rtol, :coefficient_atol, :objective_rtol, :mapping_rtol), bad in (NaN, Inf, -1e-3, "1e-5")
    @test occursin(String(name), refused(IndBallL1(T(0.6)); feasibility = NumericalFeasibility(; name => bad)))
  end
  for name in (:objective_rtol, :mapping_rtol)
    @test occursin(String(name), refused(IndBallL1(T(0.6)); feasibility = NumericalFeasibility(; name => 0)))
    # positive as given, zero in Float64
    @test occursin(String(name), refused(IndBallL1(T(0.6)); feasibility = NumericalFeasibility(; name => big"1e-400")))
  end
  # a start over the cap, and a start whose decision is unresolved (on the boundary with a zero cap)
  @test occursin("infeasible", refused(IndBallL1(T(0.1)); feasibility = ok))
  let g = IndBallL1(T(sum(abs, x0)))
    msg = refused(g; feasibility = NumericalFeasibility(coefficient_rtol = 0, coefficient_atol = 0))
    @test occursin("unresolved", msg)
  end
  # an unrepresentable budget: the curvature α maxⱼ‖Xⱼ‖² overflows in T (Float32) or in Float64
  let Xh = copy(X)
    Xh[1, 1] = T === Float32 ? T(1e20) : T(1e200)
    @test occursin("curvature", refused(IndBallL1(T(0.6)), LeastSquaresLoss(y, Xh); feasibility = ok))
  end
  # the logistic loss (Float64 data only)
  if T === Float64
    yb = [1.0, 0.0, 1.0, 0.0]
    @test occursin("LogisticLoss", refused(IndBallL1(0.6), LogisticLoss(yb, X); feasibility = ok))
  end
  # the loss scale rules of the data checks
  T === Float32 && @test occursin("loss scale", refused(IndBallL1(T(0.6)), (2^24 + 1) * f; feasibility = ok))
end

@testset "gate: other solvers keep refusing the keyword" begin
  X, y = CORRELATED_X, CORRELATED_Y
  x0 = zeros(4)
  for (method, g) in ((CDSolver(), IndBallL1(0.6)), (CDSolver(), NormL1(0.1)), (ADMMSolver(), NormL1(0.1)))
    x = copy(x0)
    msg = refusal_message(() -> solve!(x, LeastSquaresLoss(y, X), g, method; feasibility = NumericalFeasibility()))
    @test occursin("unsupported solve! keywords: feasibility", msg) && x == x0
  end
  # graphical-lasso PGD has its own solve! method, which refuses the keyword
  S = [2.0 0.5; 0.5 1.0]
  Θ = Matrix(1.0I, 2, 2)
  msg = refusal_message(() -> solve!(Θ, LogDetLoss(S), NormL1(0.1, ones(2, 2)), ProximalGradientDescent();
                                    feasibility = NumericalFeasibility()))
  @test occursin("unsupported solve! keywords: feasibility", msg) && Θ == Matrix(1.0I, 2, 2)
end

@testset "gate: accepted tolerances and loss scales (Float32 data, $(mname(method)))" for method in METHODS
  T = Float32
  X, y = T.(CORRELATED_X), T.(CORRELATED_Y)
  # zero coefficient tolerances: the cap is 0, so a trial passes only inside the ball by more than the rounding allowance
  x = zeros(T, 4)
  res = solve!(x, LeastSquaresLoss(y, X), IndBallL1(T(4)), method, OPTIONS;
               feasibility = NumericalFeasibility(coefficient_rtol = 0, coefficient_atol = 0))
  @test res.feasibility.cap == 0 && res.converged && res.feasibility.membership === :inside
  # an integer scale and a Float64 scale, used as supplied in the budgets (Float64(α))
  for alpha in (3, 0.1)
    d = Fixture{T}("scale_$alpha", X, y, T(0.6), zeros(T, 4), one(T))
    f = alpha * LeastSquaresLoss(y, X)
    x = zeros(T, 4)
    res = solve!(x, f, IndBallL1(d.r), method, OPTIONS; feasibility = NumericalFeasibility())
    b = default_budgets(X, y, alpha, d.r)
    @test isapprox(res.feasibility.gap_budget, b.gap; rtol = 1e-12)
    @test isapprox(res.feasibility.mapping_budget, b.mapping; rtol = 1e-12)
    check_result_fields(x, res, f, X, y, d.r)
    @test res.converged || res.approximate_solution
    if res.converged || res.approximate_solution
      curvature = PS._l1_budgets(X, y, Float64(alpha), Float64(d.r), PS._feasibility_tolerances(NumericalFeasibility(), T)).curvature
      ind = independent(X, y, alpha, d.r, x, curvature)
      @test ind.violation <= res.feasibility.cap && ind.gap <= res.feasibility.gap_budget &&
            ind.mapping <= res.feasibility.mapping_budget && ind.change <= res.feasibility.gap_budget
    end
  end
end

# ---- the #508 fixtures ------------------------------------------------------------------------------------------------

@testset "#508 fixtures: status class and independent MPFR check ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  for d in fixtures(T)
    @testset "$(d.name)" begin
      x, res = solve_fixture(d, method)
      check_result_fields(d, x, res)
      # each fixture ends with a passing full check under the default tolerances (the ordinary #514 profile)
      @test res.converged || res.approximate_solution
      (res.converged || res.approximate_solution) && check_success(d, x, res)
    end
  end
end

@testset "membership classes on analytic fixtures ($(mname(method)))" for method in METHODS
  # Float32 [1, eps/4] at r = 1: the start passes the cap; ProximalBase's Float32 sum is 1, so its projection copies
  # the point, whose widened mass 1 + 2⁻²⁵ exceeds r by more than the rounding allowance: an approximate solution
  # outside the ball, with minimum Inf.
  d = only(filter(d -> d.name == "stationary_tail_0.25_eps", fixtures(Float32; big = false)))
  x, res = solve_fixture(d, method)
  @test res.feasibility.membership === :outside && res.approximate_solution && !res.converged
  @test res.minimum == Inf && isfinite(res.smooth_minimum) && x == d.start
  @test res.feasibility.margin == ldexp(1.0, -25)
  # Float64 [1, eps/4] at r = 1: the widened mass rounds to 1, so the margin is 0: not classified, minimum NaN.
  d = only(filter(d -> d.name == "stationary_tail_0.25_eps", fixtures(Float64; big = false)))
  x, res = solve_fixture(d, method)
  @test res.feasibility.membership === :unknown && res.approximate_solution && isnan(res.minimum)
  @test res.feasibility.margin == 0
  # an interior solution converges inside the ball, with the smooth minimum as its minimum
  for T in (Float32, Float64)
    d = only(filter(d -> d.name == "l1_correlated_interior", fixtures(T; big = false)))
    x, res = solve_fixture(d, method)
    @test res.converged && !res.approximate_solution && res.feasibility.membership === :inside
    @test res.minimum === res.smooth_minimum
  end
end

# ---- semantics --------------------------------------------------------------------------------------------------------

# x0 = [1, 2 eps] with y = x0 and r = 1: the start passes the cap with a zero loss, and the first projection moves it to
# the boundary, which raises the loss. A mapping tolerance far below the rounding allowance keeps the full check from
# passing, so the solve runs to its limits.
function increase_problem(::Type{T}) where T
  x0 = T[1, 2eps(T)]
  X = Matrix{T}(I, 2, 2)
  x0, LeastSquaresLoss(copy(x0), X), IndBallL1(one(T)), NumericalFeasibility(mapping_rtol = 1e-30)
end

@testset "smooth objective increases: reported, not a stop ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  x0, f, g, a = increase_problem(T)
  @test iszero(f(x0))
  # allow_f_increases = false (the default) does not stop the route at the increase of the first iteration
  x = copy(x0)
  res = solve!(x, f, g, method, ProximalOptions(maxiter = 6, store_trace = true); feasibility = a)
  @test res.iterations == 6 && res.iteration_converged
  @test !res.converged && !res.approximate_solution && res.feasibility.checks >= 1
  @test res.trace[1].fg_x > 0
  # the increase is reported: a callback stop at the first iteration returns with f_increased
  x = copy(x0)
  res = solve!(x, f, g, method, ProximalOptions(callback = s -> true); feasibility = a)
  @test res.iterations == 1 && res.f_increased && !res.converged
  @test !PS._stop_on_gradient_increase(nothing, PS._NumericalL1Ball(g, Matrix{T}(I, 2, 2), copy(x0), 1.0,
                                       (; cap = 0.0, gap = 0.0, mapping = 0.0, curvature = 1.0, col = 1.0, frob = 1.0, ynorm = 1.0),
                                       PS._l1_decision(x0, g, 1e-6), 10), ProximalOptions())
  @test PS._stop_on_gradient_increase(nothing, NormL1(one(T)), ProximalOptions())
end

@testset "limits, ftol = 0, trace and callback ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  x0, f, g, a = increase_problem(T)
  # a call limit counts the full checks (one gradient and one projection each)
  x = copy(x0)
  res = solve!(x, f, g, method, ProximalOptions(maxiter = 100, grad_calls_limit = 8); feasibility = a)
  @test res.call_limit_reached && res.grad_calls >= 8 && res.iterations < 100
  # a time limit ends the solve after the first iteration
  x = copy(x0)
  res = solve!(x, f, g, method, ProximalOptions(maxiter = 100, time_limit = 1e-9); feasibility = a)
  @test res.iterations == 1 && !res.converged && !res.approximate_solution && !res.iteration_converged
  # ftol = 0: the unchanged iterate of the Float64 stationary tail is a structural proposal; its check passes
  for d in filter(d -> startswith(d.name, "stationary_tail"), fixtures(T; big = false))
    x, res = solve_fixture(d, method; options = ProximalOptions(maxiter = 320, ftol = 0))
    @test res.converged || res.approximate_solution
    @test !res.f_converged && res.f_tol == 0
    check_success(d, x, res)
  end
  # the trace and the callback objective are the smooth loss at each accepted iterate, finite where the composite is Inf
  for d in filter(d -> d.name in ("stationary_tail_0.25_eps", "l1_correlated_active", "l1_correlated_transition"), fixtures(T; big = false))
    seen = Float64[]
    x = copy(d.start)
    res = solve!(x, loss(d), IndBallL1(d.r), method,
                 ProximalOptions(maxiter = 320, store_trace = true, extended_trace = true,
                                 callback = tr -> (push!(seen, tr[end].fg_x); false));
                 feasibility = NumericalFeasibility())
    @test length(res.trace) == res.iterations == length(seen)
    @test [s.fg_x for s in res.trace] == seen
    A, Y, s = BigFloat.(d.X), BigFloat.(d.y), BigFloat(d.alpha)
    for st in res.trace
      xk = st.metadata["x"]
      @test isfinite(st.fg_x)
      @test isapprox(st.fg_x, Float64(s / 2 * sum(abs2, A * BigFloat.(xk) - Y)); rtol = 64eps(T), atol = 64floatmin(T))
    end
    @test res.trace[end].fg_x == Float64(res.smooth_minimum)
  end
end

@testset "counter identities ($T)" for T in (Float32, Float64)
  restarts = Int[]
  for d in fixtures(T; big = false), method in METHODS
    x, res = solve_fixture(d, method)
    C = res.feasibility.checks
    if method isa AccProxGradDescent
      # grad_calls = iterations + restarts + C; each trial with a finite xhat projects once, plus one per check
      k = res.grad_calls - res.iterations - C
      @test k >= 0
      push!(restarts, k)
      @test res.prox_calls == res.backtrack_steps + C
      # the loss is evaluated once at the start, once per extrapolated point and once per trial that passes the cap
      @test res.f_calls <= 1 + (res.grad_calls - C) + res.backtrack_steps
    else
      # backtrack_steps omits the zero-step acceptances, at most one per iteration
      @test 0 <= res.prox_calls - C - res.backtrack_steps <= res.iterations
      @test res.grad_calls - C - 1 >= res.iterations
    end
  end
  # on this fixture each trial passes the cap, so each trial evaluates the loss
  d = only(filter(d -> d.name == "l1_correlated_interior", fixtures(T; big = false)))
  x, res = solve_fixture(d, AccProxGradDescent())
  C = res.feasibility.checks
  @test res.f_calls == 1 + (res.grad_calls - C) + (res.prox_calls - C)
  # APG restarts on the route
  @test any(>(0), restarts)
end

@testset "show ($T)" for T in (Float32, Float64)
  d = only(filter(d -> d.name == "l1_correlated_active", fixtures(T; big = false)))
  x, res = solve_fixture(d, ProximalGradientDescent())
  text = sprint(show, res)
  @test occursin("Numerical feasibility: membership $(res.feasibility.membership)", text)
  @test occursin("Approximate solution", text) && occursin("full stopping checks: $(res.feasibility.checks)", text)
  plain = solve!(zeros(T, 4), LeastSquaresLoss(d.y, d.X), NormL1(T(0.1)), ProximalGradientDescent())
  @test !occursin("Numerical feasibility", sprint(show, plain)) && !occursin("Approximate solution", sprint(show, plain))
end

# ---- the cached decision (PGD-09) ----------------------------------------------------------------------------------------

# The decision of x, recomputed in the test from its definition (the widened mass with the same reduction)
function recomputed_decision(x, r, cap)
  s = sum(a -> abs(Float64(a)), x)
  m = s - Float64(r)
  c = (length(x) + 2) * (eps(Float64) / 2)
  noise = c / (1 - c) * max(s, Float64(r))
  membership = m > noise ? :outside : m < -noise ? :inside : iszero(s) && r > 0 ? :inside : :unknown
  code = m - cap < -noise ? :pass : m - cap > noise ? :over : :unresolved
  (; code, membership, margin = m)
end

@testset "cached decision equals the recomputed one ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  for d in fixtures(T; big = false)
    cap = PS._l1_budgets(d.X, d.y, Float64(d.alpha), Float64(d.r), PS._feasibility_tolerances(NumericalFeasibility(), T)).cap
    decisions = []
    x = copy(d.start)
    res = solve!(x, loss(d), IndBallL1(d.r), method,
                 ProximalOptions(maxiter = 320, callback = _ -> (push!(decisions, recomputed_decision(x, d.r, cap)); false));
                 feasibility = NumericalFeasibility())
    @test res.feasibility.cap == cap
    # every accepted iterate passes the cap
    @test length(decisions) == res.iterations && all(dc -> dc.code === :pass, decisions)
    # the report's decision is the decision of the returned point
    @test decisions[end].membership === res.feasibility.membership
    @test decisions[end].margin === res.feasibility.margin
  end
end

# ---- rollback ---------------------------------------------------------------------------------------------------------

@testset "rollback ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  # a callback stop returns the accepted iterate of that iteration
  d = only(filter(d -> d.name == "l1_correlated_active", fixtures(T; big = false)))
  snapshot = T[]
  x = copy(d.start)
  res = solve!(x, loss(d), IndBallL1(d.r), method,
               ProximalOptions(maxiter = 320, callback = s -> (s.iteration == 3 && append!(snapshot, x); s.iteration == 3));
               feasibility = NumericalFeasibility())
  @test res.iterations == 3 && reinterpret(UInt8, x) == reinterpret(UInt8, snapshot)
  # 64 trials from one base point that do not pass: with a zero cap, a start inside the ball by just more than the
  # rounding allowance and a far response, each trial projects onto the boundary (unresolved) until the step is too
  # short, which needs more than 64 doublings of L; the 65th trial raises the line-search error, and x is restored.
  r = one(T)
  x0 = T === Float32 ? fill(prevfloat(T(0.5), 4), 2) : fill(0.5 - ldexp(1.0, -51), 2)
  f = LeastSquaresLoss(fill(T(1e15), 2), Matrix{T}(I, 2, 2))
  a = NumericalFeasibility(coefficient_rtol = 0, coefficient_atol = 0)
  @test PS._l1_decision(x0, IndBallL1(r), 0.0).code === :pass
  x = copy(x0)
  err = try
    solve!(x, f, IndBallL1(r), method, OPTIONS; feasibility = a)
    nothing
  catch e
    e
  end
  @test err isa ErrorException && occursin("line search failed", err.msg) && occursin("64 trials", err.msg)
  @test reinterpret(UInt8, x) == reinterpret(UInt8, x0)
end

# ---- allocations ------------------------------------------------------------------------------------------------------

function route_bytes(f, g, x0, method, maxiter, a)
  o = ProximalOptions(maxiter = maxiter)
  run() = (x = copy(x0); @allocated solve!(x, f, g, method, o; feasibility = a))
  run()
  minimum(run() for _ in 1:3)
end

@testset "allocations do not grow with the iterations ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  # the correlated active fixture with a mapping tolerance far below the rounding allowance of the mapping, so that no
  # full check passes on these data
  X, y = T.(CORRELATED_X), T.(CORRELATED_Y)
  a = NumericalFeasibility(mapping_rtol = 1e-30)
  f, g = LeastSquaresLoss(y, X), IndBallL1(T(0.6))
  x = zeros(T, 4)
  res = solve!(x, f, g, method, ProximalOptions(maxiter = 40); feasibility = a)
  @test res.iterations == 40 && res.feasibility.checks >= 1
  @test route_bytes(f, g, zeros(T, 4), method, 10, a) == route_bytes(f, g, zeros(T, 4), method, 40, a)
end

# ---- the other routes -------------------------------------------------------------------------------------------------

@testset "the other penalties: new result fields ($T, $(mname(method)))" for T in (Float32, Float64), method in METHODS
  X, y = T.(CORRELATED_X), T.(CORRELATED_Y)
  f = LeastSquaresLoss(y, X)
  x = zeros(T, 4)
  res = solve!(x, f, NormL1(T(0.1)), method)
  @test !res.approximate_solution && res.feasibility === nothing
  @test isapprox(res.smooth_minimum, f(x); rtol = 64eps(T))
  @test isapprox(res.minimum, res.smooth_minimum + NormL1(T(0.1))(x); rtol = 8eps(T))
  x = zeros(T, 4)
  res = solve!(x, f, IndBox(T(-0.25), T(0.25)), method)
  @test !res.approximate_solution && res.feasibility === nothing && res.minimum === res.smooth_minimum
end

end
