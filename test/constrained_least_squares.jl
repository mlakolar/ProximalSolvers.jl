module ConstrainedLeastSquaresTest
using Test, LinearAlgebra, SparseArrays, ProximalBase, ProximalSolvers

function project_ball(v, r)
  n = norm(v)
  iszero(n) ? copy(v) : min(1, r / n) * v
end

function certificate(X, y, beta, project)
  A, b, v = Float64.(X), Float64.(y), Float64.(beta)
  n = length(y)
  residual = A * v - b
  t = n / sum(abs2, A)
  gradient = A' * residual / n
  (; objective=sum(abs2, residual) / (2n),
     feasibility=norm(v - project(v), Inf),
     stationarity=norm(v - project(v - t * gradient), Inf) / t)
end

# The relative violation (‖x‖ - r) / r of a stored point, from 256-bit BigFloat arithmetic.
function ball_violation(x, r)
  setprecision(BigFloat, 256) do
    Float64((sqrt(sum(abs2, big.(x))) - big(r)) / big(r))
  end
end

# Whether the reported minimum is the objective that the solver monitors at the returned point: finite, equal to the last
# traced objective when a trace was stored, and equal to the standalone smooth loss at x up to rounding. A zero monitored
# penalty makes it the cached smooth value; the result has no dedicated smooth-term field, so the comparison with the
# standalone loss uses the tolerance sqrt(eps(T)).
function monitored_minimum(result, x, loss)
  T = eltype(x)
  isfinite(result.minimum) && isapprox(result.minimum, loss(x); rtol = sqrt(eps(T))) &&
    (isempty(result.trace) || result.minimum == last(result.trace).fg_x)
end

# function barriers: the call gets concrete argument types, which the loop variable T of a testset does not
alloc_admissible(x, r) = @allocated ProximalSolvers._ball_rounding_admissible(x, r)
alloc_admitted(g, v, x) = @allocated ProximalSolvers._admitted_penalty_value(g, v, x)

# Trial points for which ProximalBase's value of the stored projection onto IndBallL2(r) is Inf although the point is
# within rounding of the ball. The vectors came from a search over one-iteration solves of both methods (offline). The
# tests assert that the stored point after one iteration has value Inf (the tiny cases also assert the fused value of the
# first trial), which detects the loss of the trigger.
# `TINY`: radii below ProximalBase's four-entry range, `2sqrt(4floatmin(T) / eps(T))`, solved with X = 2I and a loss
# scale 1/4 (curvature 1, so the first trial projects `target`). `HUGE`: coefficients whose sum of squares overflows,
# with the design d I so that f stays finite.
const TINY = (
  Float64 = (r = 1e-150, targets = (
    [-1.3936453133661013e-150, 2.2440006126154474e-150, 1.297832774386162e-150, 4.144169983351243e-151],
    [-1.429551341390078e-150, 2.0519376462897603e-150, 1.2481688155665707e-150, 1.1239732484354412e-150])),
  Float32 = (r = 1f-16, targets = (
    Float32[-1.3936453f-16, 2.2440007f-16, 1.2978327f-16, 4.14417f-17],
    Float32[-1.4295514f-16, 2.0519377f-16, 1.2481688f-16, 1.1239733f-16])))
const HUGE = (
  Float64 = (d = 1e-150, cases = (
    (r = 2.1469390911538068e157,
     target = [-1.0066901230778689e158, 1.6209384347904241e158, 9.37480593412712e157, 2.9935127328193755e157]),
    (r = 9.74294903087418e156,
     target = [-2.12133401578938e157, -6.842124054338852e157, 4.962762568833905e157, -4.3567561237789935e157]))),
  Float32 = (d = 1f-17, cases = (
    (r = 7.4026555f18, target = Float32[-2.5851126f19, 3.0241854f19, 5.929007f19, 1.953889f19]),
    (r = 7.3601523f18, target = Float32[6.9790718f19, 1.3375721f19, -1.6822154f19, 9.1948353f18]))))

# Solves from each feasible start and checks the result against the raw data,
# the independent projection `project` and the known minimizer `reference`.
function check_solves(X, y, g, project, reference, starts, method, options, tolerance)
  T = eltype(X)
  inputs = (copy(X), copy(y), g isa IndBox ? (copy(g.l), copy(g.u)) : nothing)
  ref = certificate(X, y, reference, project)
  for start in starts
    @test iszero(g(start)) && certificate(X, y, start, project).feasibility == 0
    beta = copy(start)
    result = solve!(beta, inv(T(size(X, 1))) * LeastSquaresLoss(y, X), g, method, options)
    c = certificate(X, y, beta, project)
    @test result.minimizer === beta
    @test iszero(g(beta))
    @test c.feasibility <= 8eps(T) * max(1, norm(beta, Inf))
    @test c.stationarity <= tolerance
    @test result.minimum ≈ c.objective atol=tolerance rtol=0
    @test c.objective ≈ ref.objective atol=tolerance rtol=0
    @test beta ≈ reference atol=tolerance rtol=0
    @test X == inputs[1] && y == inputs[2]
    if g isa IndBox
      @test (g.l, g.u) == inputs[3]
    end
  end
end

@testset "Dense constrained least squares $T / $(summary(method))" for
    T in (Float64, Float32), method in (ProximalGradientDescent(), AccProxGradDescent())
  X = Matrix(T(2) * I, 4, 4)
  a = T[2, -2, 0.25, 1]
  y = X * a
  f = T(0.25) * LeastSquaresLoss(y, X)
  tolerance = T === Float32 ? 2e-4 : 2e-7
  options = ProximalOptions(maxiter=5000, ftol=eps(T), xtol=1e-12,
    gradtol=T === Float32 ? 1e-5 : 1e-10, allow_f_increases=true)
  A = T[2 0.5 0 0; 0 2 0 0; 0 0 2 0; 0 0 0 2]
  box_ref = T[1, -0.5, 0.25, 0]
  b = A * box_ref - A' \ T[-4, 4, 0, 0]
  ball_ref = T[1, 0, 0, 0]
  ball_response = A * ball_ref + A' \ (8 * ball_ref)
  lower, upper = T[-1, -2, -Inf, 0], T[1, 1, Inf, 0]
  @testset "$label" for (label, design, response, g, project, reference) in (
      ("asymmetric", X, y, IndBox(-0.5, 1), v -> clamp.(v, -0.5, 1), clamp.(a, -0.5, 1)),
      ("coordinatewise", X, y, IndBox(lower, upper), v -> clamp.(v, lower, upper), clamp.(a, lower, upper)),
      ("correlated", A, b, IndBox(T(-0.5), one(T)), v -> clamp.(v, -0.5, 1), box_ref),
      ("active infinity ball", X, y, IndBallLinf(one(T)), v -> clamp.(v, -1, 1), clamp.(a, -1, 1)),
      ("inactive infinity ball", X, y, IndBallLinf(T(3)), v -> clamp.(v, -3, 3), a),
      ("zero infinity ball", X, y, IndBallLinf(zero(T)), v -> zeros(length(v)), zeros(T, 4)),
      ("active Euclidean ball", X, y, IndBallL2(one(T)), v -> project_ball(v, 1), project_ball(a, 1)),
      ("inactive Euclidean ball", X, y, IndBallL2(T(4)), v -> project_ball(v, 4), a),
      ("zero Euclidean ball", X, y, IndBallL2(zero(T)), v -> project_ball(v, 0), zeros(T, 4)),
      ("correlated Euclidean ball", A, ball_response, IndBallL2(one(T)), v -> project_ball(v, 1), ball_ref))
    inputs = (copy(design), copy(response), deepcopy(g))
    for init in (zero(T), T(0.25))
      beta = T.(project(fill(init, 4)))
      loss = T(0.25) * LeastSquaresLoss(response, design)
      result = solve!(beta, loss, g, method, options)
      c = certificate(design, response, beta, project)
      ref = certificate(design, response, reference, project)
      @test result.minimizer === beta
      @test iszero(g(beta))
      @test c.feasibility <= 8eps(T)
      @test c.stationarity <= tolerance
      @test result.minimum ≈ c.objective atol=tolerance rtol=0
      @test c.objective ≈ ref.objective atol=tolerance rtol=0
      @test beta ≈ reference atol=tolerance rtol=0
      @test design == inputs[1] && response == inputs[2]
      if g isa IndBox
        @test (g.l, g.u) == (inputs[3].l, inputs[3].u)
      end
    end
  end

  # With X = sqrt(p) I and n = p the loss is ‖β - c‖²/2, so each constrained
  # minimizer is the coordinatewise clamp of c. Box and infinity-ball support is
  # not limited to four coefficients.
  @testset "Orthogonal dimensions p = $p" for p in (2, 5, 20)
    D = sqrt(T(p)) * Matrix{T}(I, p, p)
    c = T[(j % 4 == 1) ? 2 : (j % 4 == 2) ? -2 : (j % 4 == 3) ? 0.25 : 0 for j in 1:p]
    r = D * c
    cases = Any[
      ("asymmetric box", IndBox(T(-0.5), one(T)), fill(T(-0.5), p), fill(one(T), p), true),
      ("loose box", IndBox(T(-3), T(3)), fill(T(-3), p), fill(T(3), p), false),
      ("active infinity ball", IndBallLinf(one(T)), fill(-one(T), p), fill(one(T), p), true),
      ("inactive infinity ball", IndBallLinf(T(3)), fill(T(-3), p), fill(T(3), p), false)]
    if p == 20
      lo = T[j % 4 == 0 ? 0 : isodd(j) ? -0.75 : -1.5 for j in 1:p]
      hi = T[j % 4 == 0 ? 0 : isodd(j) ? 1 : 0.5 for j in 1:p]
      @test all(lo .<= 0 .<= hi) && any(lo .== hi)
      push!(cases, ("coordinatewise box", IndBox(copy(lo), copy(hi)), lo, hi, true))
    end
    @testset "$label" for (label, g, lo, hi, active) in cases
      project = v -> clamp.(v, lo, hi)
      reference = clamp.(c, lo, hi)
      if active
        @test norm(reference - c, Inf) >= 0.25
      else
        @test all(lo .+ 1 .<= c .<= hi .- 1)
      end
      starts = (zeros(T, p), clamp.(fill(T(0.25), p), lo, hi))
      check_solves(D, r, g, project, reference, starts, method, options, tolerance)
    end
  end

  # A nonorthogonal 8 × 4 design whose Euclidean-ball minimizer β⋆ is built from
  # the KKT conditions: y = X(β⋆ + w) with X'Xw = nμβ⋆ gives ∇F(β⋆) = -μβ⋆, μ > 0,
  # and ‖β⋆‖₂ = r. X'X has eigenvalues 1, 3, 3, 5, so β⋆ is the unique minimizer.
  @testset "Rectangular Euclidean ball" begin
    R = T[1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1; 1 1 0 0; 0 1 1 0; 0 0 1 1; 1 0 0 1]
    βstar, radius, μ = T[1, 0, 0, 0], one(T), T(0.5)
    n = size(R, 1)
    w = (R' * R) \ (T(n) * μ * βstar)
    s = R * (βstar + w)
    A, b = Float64.(R), Float64.(s)
    gradient = A' * (A * βstar - b) / n
    multiplier = -dot(gradient, βstar) / norm(βstar)^2
    @test minimum(eigvals(Symmetric(A' * A))) ≈ 1
    @test norm(βstar) == radius
    @test multiplier ≈ μ atol=16eps(T) rtol=0
    @test norm(gradient + multiplier * βstar, Inf) <= 16eps(T)
    unconstrained = A \ b
    @test norm(unconstrained) >= 2radius
    @test norm(project_ball(unconstrained, radius) - βstar, Inf) >= 0.1
    starts = (zeros(T, 4), T.(project_ball(fill(T(0.25), 4), radius)))
    check_solves(R, s, IndBallL2(radius), v -> project_ball(v, radius), βstar,
      starts, method, options, tolerance)
  end

  @testset "Refusals before writes" begin
    g = IndBox(-one(T), one(T))
    malformed = IndBox(copy(lower), copy(upper))
    malformed.u[1] = T(NaN)
    aliased_bounds = IndBox(fill(T(-1), 4), one(T))
    for (x, loss, penalty, solver) in (
        (T[2, 0, 0, 0], f, g, method),
        (T[2, 0, 0, 0], f, IndBallL2(one(T)), method),
        (zeros(T,4), f, IndBallL2(T(Inf)), method),
        (zeros(T,4), f, IndBallL2(1), method),
        (zeros(T,4), f, IndBallL2(one(T)), CDSolver()),
        (T[NaN, 0, 0, 0], f, g, method),
        (zeros(T,4), LeastSquaresLoss(T[Inf, 0, 0, 0], X), g, method),
        (zeros(T,4), LeastSquaresLoss(y, sparse(X)), g, method),
        (zeros(T,4), SqrtLeastSquaresLoss(y, X), g, method),
        (zeros(T,4), LeastSquaresLoss(hcat(y, y), X), g, method),
        (zeros(T,4), f, g, CDSolver()),
        (zeros(T,4), f, malformed, method),
        (zeros(T,4), f, IndBox(-big"0.5", big"0.5"), method),
        (zeros(T,4), f, IndBox(-1, big(1)), method),
        (aliased_bounds.l, f, aliased_bounds, method),
        (SparseIterate(zeros(T,4)), f, g, method),
        (view(zeros(T,4), :), f, g, method))
      before = collect(x)
      @test_throws ArgumentError solve!(x, loss, penalty, solver)
      @test isequal(collect(x), before)
    end
    @test_throws DimensionMismatch solve!(zeros(T,3), f, g, method)
    @test_throws DimensionMismatch solve!(zeros(T,4), f, IndBox(zeros(T,3), one(T)), method)
    @test_throws ArgumentError IndBox(T(2), one(T))
    @test_throws ArgumentError IndBallL2(T(-1))
    for width in (2, 5)
      D = Matrix{T}(I, width, width)
      x = zeros(T, width)
      @test_throws ArgumentError solve!(x, LeastSquaresLoss(ones(T, width), D), IndBallL2(one(T)), method)
      @test iszero(x)
    end
    if T === Float32
      @test_throws ArgumentError solve!(zeros(T,4), f, IndBox(-0.1, one(T)), method)
    end
  end

  @testset "Projected trials with backtracking" begin
    A = T(4) * X
    b = A * a
    x = zeros(T, 4)
    g = IndBox(T(-1), one(T))
    result = solve!(x, T(0.25) * LeastSquaresLoss(b, A), g, method,
      ProximalOptions(maxiter=2, f_calls_limit=1))
    @test result.backtrack_steps > 1
    @test g(x) == zero(T)
    @test all(v -> -1 <= v <= 1, x)
  end

  @testset "Exceptional Euclidean projection rolls back" begin
    # At the smallest radius the rounded projection of (1, 1, 0, 0)
    # can be outside the ball. The fused oracle reports that value.
    g = IndBallL2(nextfloat(zero(T)))
    x = zeros(T, 4)
    target = T[1, 1, 0, 0]
    loss = T(0.25) * LeastSquaresLoss(X * target, X)
    fixed_step = method isa ProximalGradientDescent ?
      ProximalGradientDescent(ls=ProximalSolvers.LineSearches.BackTracking(α=1.0)) :
      AccProxGradDescent(α=1.0)
    @test_throws r"the gradient step did not produce a finite objective" solve!(x, loss, g, fixed_step)
    @test x == zeros(T, 4)
  end

  # A trial whose stored projection ProximalBase evaluates as Inf is admitted when it is within the rounding
  # tolerance of IN-08: the iteration monitors the smooth value, and the result reports the monitored objective, which is finite.
  @testset "Admitted exterior trial: radius below the four-entry range" begin
    fixed_step = method isa ProximalGradientDescent ?
      ProximalGradientDescent(ls=ProximalSolvers.LineSearches.BackTracking(α=1.0)) :
      AccProxGradDescent(α=1.0)
    r = TINY[Symbol(T)].r
    @test r < 2sqrt(4floatmin(T) / eps(T))
    g = IndBallL2(r)
    for target in TINY[Symbol(T)].targets
      loss = T(0.25) * LeastSquaresLoss(X * target, X)
      # the first trial projects `target`, and ProximalBase evaluates the stored point as Inf
      @test isinf(value_and_prox!(similar(target), g, copy(target), one(T)))
      # one iteration: the trial is accepted although g(x) = Inf
      x = zeros(T, 4)
      one_step = solve!(x, loss, g, fixed_step, ProximalOptions(maxiter=2, prox_calls_limit=1, store_trace=true))
      @test one_step.iterations == 1
      @test isinf(g(x))
      @test isfinite(one_step.minimum)
      @test one_step.minimum == last(one_step.trace).fg_x
      @test ball_violation(x, r) <= 10eps(T)
      @test all(isfinite, x)
      # a point returned in this state is refused as a start by the feasible-start rule, before any write
      before = copy(x)
      @test_throws ArgumentError solve!(x, loss, g, fixed_step)
      @test x == before
      # a solve with the default options completes; its minimum is the monitored objective at the returned point
      x = zeros(T, 4)
      result = solve!(x, loss, g, fixed_step)
      @test result.minimizer === x
      @test ball_violation(x, r) <= 10eps(T)
      @test monitored_minimum(result, x, loss)
      # converged agrees with an independent form of the generic check (L = 1, so t = 1): ∇f(x) = x - target
      setprecision(BigFloat, 256) do
        xb, tb = big.(x), big.(target)
        projected = tb * big(r) / sqrt(sum(abs2, tb))
        residual = maximum(abs, xb - projected)
        scale = max(maximum(abs, tb), maximum(abs, xb - tb))
        threshold = big(T(max(ProximalOptions().gradtol, 64 * Float64(eps(T))))) * scale
        @test result.converged == (residual < threshold)
      end
    end
  end

  @testset "Admitted exterior trial: monitored trace and residual" begin
    fixed_step = method isa ProximalGradientDescent ?
      ProximalGradientDescent(ls=ProximalSolvers.LineSearches.BackTracking(α=1.0)) :
      AccProxGradDescent(α=1.0)
    r, target = TINY[Symbol(T)].r, TINY[Symbol(T)].targets[1]
    g = IndBallL2(r)
    loss = T(0.25) * LeastSquaresLoss(X * target, X)
    x = zeros(T, 4)
    traced = solve!(x, loss, g, fixed_step, ProximalOptions(maxiter=2, prox_calls_limit=1, store_trace=true))
    @test isinf(g(x))
    @test isfinite(traced.minimum)
    @test traced.minimum == last(traced.trace).fg_x
    # the trace and the objective-change residual read the monitored objective, which is finite
    @test length(traced.trace) == 1 && all(t -> isfinite(t.fg_x), traced.trace)
    @test isfinite(traced.f_residual)
  end

  # The smooth term of the minimum is the cached value of the accepted trial, as for the other penalties of these solvers;
  # the penalty term is the monitored penalty. Here the cached value is one unit in the last place above the standalone
  # loss at x = 0.
  @testset "Reported minimum: smooth term and penalty term" begin
    if T === Float32
      y = vcat(fill(ldexp(1f0, 63), 2), fill(ldexp(1f0, 51), 4))
      loss = 2f0 * LeastSquaresLoss(y, zeros(T, 6, 4))
      one_iteration = ProximalOptions(maxiter=2, prox_calls_limit=1, store_trace=true)
      x_ball, x_box = zeros(T, 4), zeros(T, 4)
      ball = IndBallL2(1f0)
      with_ball = solve!(x_ball, loss, ball, method, one_iteration)
      with_box = solve!(x_box, loss, IndBox(-1f0, 1f0), method, one_iteration)
      @test x_ball == x_box == zeros(T, 4)
      @test iszero(ball(x_ball))
      @test with_ball.minimum == last(with_ball.trace).fg_x
      @test isfinite(with_ball.minimum)
      # the same smooth term as with a penalty that is not the ball, and within rounding of the standalone loss
      @test with_ball.minimum == with_box.minimum
      @test isapprox(with_ball.minimum, loss(x_ball); rtol=4eps(T))
    end
  end

  @testset "Admitted exterior trial: sum of squares beyond the range of T" begin
    d = HUGE[Symbol(T)].d
    D = Matrix(d * I, 4, 4)
    for (r, target) in HUGE[Symbol(T)].cases
      g = IndBallL2(r)
      loss = LeastSquaresLoss(D * target, D)
      x = zeros(T, 4)
      one_step = solve!(x, loss, g, method, ProximalOptions(maxiter=2, prox_calls_limit=1, store_trace=true))
      @test one_step.iterations == 1
      @test isinf(g(x))
      @test isfinite(one_step.minimum)
      @test one_step.minimum == last(one_step.trace).fg_x
      @test ball_violation(x, r) <= 10eps(T)
      x = zeros(T, 4)
      result = solve!(x, loss, g, method)
      @test result.minimizer === x
      @test ball_violation(x, r) <= 10eps(T)
      @test monitored_minimum(result, x, loss)
    end
  end

  @testset "Tiny progress at a nonstationary iterate" begin
    A = T[1 0; 0 1/64]
    b = T[2, -1]
    x = T[2, 1]
    r = solve!(x, LeastSquaresLoss(b, A), IndBox(T(-4), T(4)), method,
      ProximalOptions(maxiter=2, ftol=0.01))
    c = certificate(A, b, x, v -> clamp.(v, -4, 4))
    @test c.stationarity > 0.005
    @test !r.converged
  end
end

@testset "Admission of a rounded ball trial $T" for T in (Float32, Float64)
  admissible = ProximalSolvers._ball_rounding_admissible
  admitted = ProximalSolvers._admitted_penalty_value
  u = [0.2, 0.4, 0.4, 0.8]    # a direction; `point` divides it by its norm
  radii = T === Float64 ? (1.0, 1e-150, 1e157) : (1f0, 1f-16, 1f19)
  # The stored point (1 + δ eps) r u / ‖u‖, rounded to T, lies about δ eps outside the ball (δ is a nominal offset before the entries are rounded).
  point(r, δ) = setprecision(BigFloat, 256) do
    T.((1 + δ * big(eps(T))) * big(r) * big.(u) / sqrt(sum(abs2, big.(u))))
  end
  @testset "radius $r" for r in radii
    @test admissible(point(r, 0), r)
    @test admissible(point(r, 2), r)
    @test !admissible(point(r, 12), r)
    @test !admissible(point(r, 11), r)
    # Admitted points violate by at most 10 eps (the bound of IN-08), and rejected points by more than 6 eps
    for δ in 0:0.25:16
      y = point(r, δ)
      violation = ball_violation(y, r) / Float64(eps(T))
      admissible(y, r) ? (@test violation <= 10) : (@test violation > 6)
    end
  end
  @test admissible(T[0, 0, 0, 0], one(T))
  @test admissible(T[-0.0, 0, 0, 0], one(T))
  @test admissible(T[nextfloat(zero(T)), 0, 0, 0], one(T))
  @test !admissible(T[1, NaN, 0, 0], one(T))
  @test !admissible(T[1, Inf, 0, 0], one(T))
  @test !admissible(T[-Inf, 0, 0, 0], one(T))
  @test !admissible(T[0, 0, 0, 0], zero(T))
  @test !admissible(T[1, 0, 0, 0], T(Inf))
  @test !admissible(T[1, 0, 0, 0], T(NaN))
  @test !admissible(fill(floatmax(T), 4), floatmax(T))
  @test admissible(T[floatmax(T), 0, 0, 0], floatmax(T))
  @test !admissible(T[nextfloat(zero(T)), 0, 0, 0], zero(T))
  g = IndBallL2(one(T))
  inside, outside = point(1, 2), point(1, 12)
  @test admitted(g, T(Inf), inside) === zero(T)
  @test admitted(g, T(Inf), outside) === T(Inf)
  @test admitted(g, zero(T), outside) === zero(T)    # a value of zero is returned as it is
  @test isnan(admitted(g, T(NaN), inside))
  @test admitted(g, T(Inf), T[NaN, 0, 0, 0]) === T(Inf)
  # any other penalty, and a radius or vector of another type, keeps the value
  @test admitted(IndBox(-one(T), one(T)), T(Inf), inside) === T(Inf)
  @test admitted(IndNonnegative(), T(Inf), inside) === T(Inf)
  @test admitted(NormL1(T(0.5)), T(3), inside) === T(3)
  @test admitted(IndBallL2(1), T(Inf), inside) === T(Inf)
  # warmed, the checks do not allocate
  box = IndBox(-one(T), one(T))
  for y in (inside, outside)
    admitted(g, T(Inf), y); admissible(y, one(T)); admitted(box, T(Inf), y)
    @test alloc_admitted(g, T(Inf), y) == 0
    @test alloc_admissible(y, one(T)) == 0
    @test alloc_admitted(box, T(Inf), y) == 0
  end
end
end
