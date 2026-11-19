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
end
