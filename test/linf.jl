module LinfTests
# NormLinf(λ) with ProximalGradientDescent and AccProxGradDescent on ½α‖Xb - y‖² + λ‖b‖∞. The references are
# independent of the solvers and of ProximalBase's proximal operator: the analytic minimizer of X = [1 1], y = [2],
# λ = 1; the least-squares solution at λ = 0; the zero solution for λ ≥ ‖∇f(0)‖₁; and the KKT residual
# r(x) = min over v in ∂‖x‖∞ of ‖∇f(x) + λ v‖₁ in BigFloat. NormLinf has no dedicated stopping check: the generic
# proximal-gradient check of src/utils.jl verifies its stops.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

const METHODS = (ProximalGradientDescent(), AccProxGradDescent())
const TIGHT = ProximalOptions(maxiter = 20_000, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-11, allow_f_increases = true)

# P(b) = ½‖Xb - y‖² + λ max|bᵢ|, in BigFloat
primal(X, y, λ, b) = (w = big.(X) * big.(b) - big.(y); dot(w, w) / 2 + big(λ) * maximum(abs, big.(b)))

# the KKT residual r(x) in BigFloat: max(‖g‖₁ - λ, 0) at x = 0, and Σ_{i∉M} |gᵢ| + N + |λ - P| otherwise, with M the
# entries of largest magnitude, N = Σ_{i∈M} max(sᵢgᵢ, 0) and P = Σ_{i∈M} max(-sᵢgᵢ, 0)
function kkt(X, y, λ, x)
  g, λ, x = big.(X)' * (big.(X) * big.(x) - big.(y)), big(λ), big.(x)
  m = maximum(abs, x)
  iszero(m) && return Float64(max(norm(g, 1) - λ, 0))
  M = [i for i in eachindex(x) if abs(x[i]) == m]
  a = [sign(x[i]) * g[i] for i in M]
  Float64(sum(abs(g[i]) for i in eachindex(g) if i ∉ M; init = big(0)) + sum(max.(a, 0)) + abs(λ - sum(max.(-a, 0))))
end

function problem(::Type{T}, n, p; seed = 1) where T
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  y = X * [1.5; -1.0; zeros(p - 2)] .+ 0.3 .* randn(rng, n)
  T.(X), T.(y)
end

solve_case(method, X, y, λ, x0, options = ProximalOptions()) =
  (x = copy(x0); r = solve!(x, LeastSquaresLoss(y, X), NormLinf(eltype(X)(λ)), method, options); (x, r))

@testset "analytic X = [1 1], y = [2], λ = 1: β* = (0.75, 0.75), P* = 0.875" begin
  for T in (Float64, Float32), method in METHODS, x0 in (T[0, 0], T[3, -2])
    X, y = T[1 1], T[2]
    @test primal(X, y, 1, [0.75, 0.75]) == big"0.875"
    for (options, tol) in ((ProximalOptions(), T === Float64 ? 1e-4 : 1e-3), (TIGHT, T === Float64 ? 1e-6 : 1e-4))
      x, r = solve_case(method, X, y, 1, x0, options)
      @test r.converged && r.minimizer === x
      @test maximum(abs, x .- 0.75) <= tol
      @test abs(r.minimum - 0.875) <= tol
      @test kkt(X, y, 1, x) <= 10tol
    end
  end
end

@testset "λ = 0: the least-squares solution" begin
  for T in (Float64, Float32), method in METHODS
    X, y = problem(T, 30, 5; seed = 3)
    βls = Float64.((big.(X)' * big.(X)) \ (big.(X)' * big.(y)))
    x, r = solve_case(method, X, y, 0, zeros(T, 5), TIGHT)
    @test r.converged
    @test maximum(abs, x - βls) <= (T === Float64 ? 1e-6 : 2e-3)
  end
end

@testset "λ ≥ ‖∇f(0)‖₁ gives the zero solution; ‖∇f(0)‖∞ ≤ λ < ‖∇f(0)‖₁ does not" begin
  for T in (Float64, Float32), method in METHODS
    X, y = problem(T, 30, 6; seed = 5)
    λc = Float64(norm(big.(X)' * big.(y), 1))
    for m in (1.5, 10), x0 in (zeros(T, 6), T[0.1, -0.2, 0.05, 0.3, -0.1, 0.2])
      x, r = solve_case(method, X, y, m * λc, x0)
      @test all(iszero, x) && r.converged
    end
    # X = I, y = (2, 2, 2): ‖∇f(0)‖∞ = 2 ≤ λ = 3 < ‖∇f(0)‖₁ = 6, and the minimizer is (1, 1, 1)
    x, r = solve_case(method, Matrix{T}(I, 3, 3), T[2, 2, 2], 3, zeros(T, 3), TIGHT)
    @test r.converged && maximum(abs, x .- 1) <= (T === Float64 ? 1e-6 : 1e-4)
  end
end

@testset "a stop proposed far from the minimizer is refused" begin
  for T in (Float64, Float32), method in METHODS, options in (ProximalOptions(maxiter = 2, xtol = 1e10, ftol = 0, gradtol = 0),
                                                              ProximalOptions(maxiter = 2, xtol = 1e-300, ftol = 1e10, gradtol = 0))
    X, y = T[1 1], T[2]
    x, r = solve_case(method, X, y, 1, T[50, -50], options)
    @test !r.converged && !r.x_converged && !r.f_converged && !r.grad_converged && r.iterations == 2
    @test kkt(X, y, 1, x) >= 0.5          # the threshold is 64 eps(T) S (gradtol = 0), S ≥ ‖∇f(0)‖∞ = 2
  end
end

# One check at x of ½(x - 2)² + λ|x| in one variable (X = [1], y = [2], g = NormLinf(1)), with curvature L: t = 1/L,
# ∇f(x) = x - 2, and prox_{t g}(x - t ∇f(x)) at L = 1 is the soft threshold of 2 at 1, so that r = |x - 1|;
# S = max(|∇f(0)|, |∇f(x)|) = 2 for x in [0, 4].
function check_at(method, T, x, g; L = 1, y = 2, options = ProximalOptions())
  f = LeastSquaresLoss(T[y], T[1;;])
  st = PS.initial_state(method, options, f, g, T[x])
  st.x_previous .= st.x .- T(1) / 8
  st.delta_x .= st.x .- st.x_previous
  st.L = T(L)
  grad = copy(method isa ProximalGradientDescent ? st.grad_f_x : st.grad_f_y)
  PS._stationary!(st, f, g, options), st, grad
end

@testset "the check: the boundary r = τ S, the guards, the counters and the buffers" begin
  for T in (Float64, Float32), method in METHODS
    g = NormLinf(T(1))
    # τ = 1e-5 (the default gradtol, above 64 eps(T)) and S = 2: the stop is kept for r < 2e-5
    @test check_at(method, T, 1, g)[1]
    @test check_at(method, T, 1 + 0.9 * 2e-5, g)[1] && check_at(method, T, 1 - 0.9 * 2e-5, g)[1]
    @test !check_at(method, T, 1 + 1.1 * 2e-5, g)[1] && !check_at(method, T, 1 - 1.1 * 2e-5, g)[1]
    @test !check_at(method, T, 0.5, g)[1]
    # the guards: a step 1/L that is not finite and positive; y = 0 at x = 0 (S = 0); a stationary x whose step is
    # below the rounding resolution L eps(T) ‖x‖∞ of the threshold
    for L in (0, Inf, NaN, -1)
      @test !check_at(method, T, 1, g; L)[1]
    end
    @test !check_at(method, T, 0, g; y = 0)[1]
    @test !check_at(method, T, 1, g; L = T === Float64 ? 1e12 : 1e6)[1]
    # one prox per check, and for APG one gradient at x; x, the engines' gradients and x - x_previous are as before
    ref = PS.initial_state(method, ProximalOptions(), LeastSquaresLoss(T[2], T[1;;]), g, T[1])
    ok, st, grad = check_at(method, T, 1, g)
    @test (st.prox_calls, st.grad_calls, st.f_calls) == (ref.prox_calls + 1, ref.grad_calls + (method isa AccProxGradDescent), ref.f_calls)
    @test st.x == T[1] && st.delta_x == st.x .- st.x_previous && st.λmax == 2
    @test isequal(method isa ProximalGradientDescent ? st.grad_f_x : st.grad_f_y, grad)
  end
end

@testset "S = 0 (y = 0): the solve does not report convergence, also at the minimizer x = 0" begin
  for T in (Float64, Float32), method in METHODS
    x, r = solve_case(method, T[1 1; 2 1], T[0, 0], 1, zeros(T, 2), ProximalOptions(maxiter = 20))
    @test !r.converged && r.iterations == 20 && all(iszero, x)
  end
end

@testset "a kept stop costs one prox (and for APG one gradient) more than the same iteration without a proposed stop" begin
  nostop = (xtol = 1e-300, ftol = 0, gradtol = 0)
  for T in (Float64, Float32), method in METHODS
    f, g = LeastSquaresLoss(T[2], T[1 1]), NormLinf(T(5))
    a = solve!(zeros(T, 2), f, g, method, ProximalOptions())
    b = solve!(zeros(T, 2), f, g, method, ProximalOptions(; nostop..., callback = _ -> true))
    @test a.converged && !b.converged && a.iterations == b.iterations == 1
    @test (a.prox_calls, a.grad_calls, a.f_calls) == (b.prox_calls + 1, b.grad_calls + (method isa AccProxGradDescent), b.f_calls)
  end
end

function refused(x, f, g, method, msg, E = ArgumentError)
  original = copy(x)
  @test_throws E(msg) solve!(x, f, g, method)
  @test isequal(x, original)
end

@testset "a tiny accepted L with a large x: a step lost to rounding is not a stop" begin
  # λ = 0, so the mapping is ∇f(x) for every t; the iterate does not move, and L eps(T) alone underflows
  for (T, xv, yv, x0) in ((Float32, 1e-22, 1e8, 1.001e30), (Float64, 1e-160, 1e10, 1.00003e170)), method in METHODS, scale in (1, 2)
    X, y = fill(T(xv), 1, 1), T[yv]
    f = scale == 1 ? LeastSquaresLoss(y, X) : T(scale) * LeastSquaresLoss(y, X)
    x = T[x0]
    r = solve!(x, f, NormLinf(zero(T)), method, ProximalOptions(maxiter = 50))
    @test !r.converged && !r.x_converged && !r.f_converged && !r.grad_converged
  end
end

@testset "refusals before any change of x" begin
  for T in (Float64, Float32)
    X, y, x = T[1 0; 0 2], T[1, -1], T[.3, -.2]
    f = LeastSquaresLoss(y, X)
    for method in METHODS
      refused(copy(x), f, NormLinf(T(Inf)), method, "penalty lambda must be finite and nonnegative")
      generic = method isa ProximalGradientDescent ?
        "only NormL1, ElasticNet (with optional weights), NormLinf, NormL2, GroupNormL2, unweighted NormL1Nonneg, IndNonnegative, IndBox or IndBallL2 is supported" :
        "only NormL1, ElasticNet (with optional weights), NormLinf, NormL2, GroupNormL2, IndBox or IndBallL2 is supported"
      refused(copy(x), f, Scaled(NormLinf(T(.1)), 2), method, generic)
      T === Float32 && refused(copy(x), f, NormLinf(1e300), method,
                               "penalty lambda is not representable without overflow or underflow in Float32")
    end
    msg = "CDSolver does not support NormLinf (its coordinate step needs a separable penalty); use ProximalGradientDescent or AccProxGradDescent"
    for start in (copy(x), SparseIterate(copy(x)))
      rng = Xoshiro(1)
      original = Vector(start)
      @test_throws ArgumentError(msg) solve!(start, f, NormLinf(T(.1)), CDSolver(rng = rng))
      @test Vector(start) == original && rng == Xoshiro(1)
    end
    xb = BlockIterate(T, 2, [1:1, 2:2])
    err = try solve!(xb, f, NormLinf(T(.1)), CDSolver()) catch e e end
    @test err isa ArgumentError && occursin("BlockIterate needs a GroupNormL2 penalty", sprint(showerror, err))
    @test Vector(xb) == zeros(T, 2)
  end
end

@testset "Selectable mapping uses the strict residual comparison ($T, $method)" for
    T in (Float32, Float64), method in METHODS
  X = T[1 0; 0 1]
  y = T[2, 2]
  tight = ProximalGradientMapping(rtol=0.5)
  loose = ProximalGradientMapping(rtol=0.75)
  apg = method isa AccProxGradDescent
  for scale in (one(T), T(0.5))
    f = isone(scale) ? LeastSquaresLoss(y, X) : scale * LeastSquaresLoss(y, X)
    g = NormLinf(2scale)
    x = zeros(T, 2)
    # The prox clips both trial coordinates at t*scale. At x=0 the
    # residual is scale and the reference scale is 2*scale.
    r = solve!(x, f, g, method; stopping=AnyOf(tight, loose))
    t = termination(r)
    @test r.minimizer === x && iszero(x) && r.iterations == 0
    @test r.converged && t.satisfied && t.reason === :rule && t.winning_branch == ((2,),)
    @test map(o -> o.status, t.observations) == (:fail, :pass)
    @test t.observations[2].name === :ProximalGradientMapping
    @test t.observations[2].evidence === :stationarity && t.observations[2].value === true
    @test t.counts == (f_calls=apg ? 2 : 1, grad_calls=2, g_calls=2, prox_calls=1,
                       backtrack_steps=0, rejected_trials=0)

    r = solve!(ones(T, 2), f, g, method; stopping=ProximalGradientMapping(rtol=0))
    @test r.converged && r.iterations == 0 && r.minimizer == ones(T, 2)

    r = solve!(zeros(T, 2), f, g, method; stopping=AnyOf(UserStop(_ -> true), loose))
    t = termination(r)
    @test t.reason === :user && t.observations[2].status === :not_checked
    @test t.counts.f_calls == 1 && t.counts.grad_calls == (apg ? 0 : 1) && t.counts.prox_calls == 0
  end

  r = solve!(zeros(T, 2), LeastSquaresLoss(zeros(T, 2), X), NormLinf(one(T)), method;
             stopping=AnyOf(loose, UserStop(_ -> true)))
  t = termination(r)
  @test t.reason === :user && !r.converged && t.observations[1].status === :fail
end

@testset "Selectable mapping validation and cap ties ($T, $method)" for
    T in (Float32, Float64), method in METHODS
  f = LeastSquaresLoss(T[2, 2], T[1 0; 0 1])
  g = NormLinf(T(2))
  mapping = ProximalGradientMapping(rtol=0.75)
  cap = MaxProximalEvaluations(1)
  for (other, reason, status) in ((mapping, :rule, :pass),
                                  (ProximalGradientMapping(rtol=0.8), :limit, :not_checked))
    r = solve!(zeros(T, 2), f, g, method; stopping=AllOf(mapping, other), limits=cap)
    t = termination(r)
    @test t.iteration == 0 && t.reason === reason && t.limit_reached
    @test r.converged == t.satisfied == (reason === :rule)
    @test t.reached_evaluation_limits === (cap,) && t.counts.prox_calls == 1
    @test t.counts.backtrack_steps == t.counts.rejected_trials == 0
    @test map(o -> o.status, t.observations) == (:pass, status)
  end

  x = fill(floatmax(T) / 2, 2)
  start = copy(x)
  for zero_cap in (MaxIterations(0), MaxObjectiveEvaluations(0),
                   MaxGradientEvaluations(0), MaxProximalEvaluations(0))
    r = solve!(x, f, g, method; stopping=mapping, limits=zero_cap)
    t = termination(r)
    @test r.minimizer === x && x == start && r.minimum === missing
    @test t.reason === :limit && only(t.observations).status === :not_checked
    @test all(iszero, values(t.counts))
  end
  @test_throws ArgumentError solve!(x, f, NormL1(one(T)), method;
      stopping=AnyOf(UserStop(_ -> true), mapping), limits=MaxIterations(0))
  @test_throws ArgumentError solve!(x, f, g, method;
      stopping=AnyOf(mapping, ScaledKKT(rtol=0.75)), limits=MaxIterations(0))
  @test_throws ArgumentError Every(2, mapping)
  @test x == start
end

@testset "APG mapping reads accepted gradient and preserves displacement ($T)" for T in (Float32, Float64)
  f = LeastSquaresLoss(T[2, 2], T[1 0; 0 1])
  g, method = NormLinf(T(2)), AccProxGradDescent(α=1.0, β=0.5)
  mapping = ProximalGradientMapping(rtol=0.375)
  opts = ProximalOptions(store_trace=true, extended_trace=true)
  # The first update is (0,0) -> (1/2,1/2). The accepted gradient gives
  # hypothetical prox (3/4,3/4); the extrapolated gradient gives (1,1).
  rule = AllOf(mapping, IterateChange(atol=0.8))
  r = solve!(zeros(T, 2), f, g, method, opts; stopping=rule, limits=MaxIterations(2))
  t = termination(r)
  @test r.minimizer == fill(T(0.5), 2) && r.trace[1].metadata["x"] == r.minimizer
  @test r.trace[1].metadata["grad_f(y)"] == fill(T(-2), 2)
  @test r.converged && t.reason === :rule && t.iteration == 1
  @test t.observations[2].value ≈ sqrt(0.5)
  @test t.counts == (f_calls=6, grad_calls=4, g_calls=5, prox_calls=4,
                     backtrack_steps=2, rejected_trials=1)

  for (cap, reason, status) in ((MaxProximalEvaluations(3), :limit, :not_checked),
                                (MaxProximalEvaluations(4), :rule, :pass))
    capped = solve!(zeros(T, 2), f, g, method; stopping=mapping, limits=cap)
    t = termination(capped)
    @test capped.minimizer == r.minimizer && capped.minimum === r.minimum
    @test t.reason === reason && t.reached_evaluation_limits === (cap,)
    @test only(t.observations).status === status
  end

  r = solve!(zeros(T, 2), f, g, method;
             stopping=AnyOf(mapping, UserStop(_ -> true)), limits=MaxGradientEvaluations(1))
  t = termination(r)
  @test t.iteration == 0 && t.reason === :user && !t.limit_reached
  @test t.observations[1].status === :not_checked
  @test t.counts.f_calls == 1 && t.counts.grad_calls == t.counts.prox_calls == 0

  r = solve!(zeros(T, 2), f, g, method; stopping=mapping, limits=MaxGradientEvaluations(1))
  t = termination(r)
  @test t.iteration == 1 && t.reason === :limit && t.counts.grad_calls == 1
  @test only(t.observations).status === :not_checked
end

@testset "Mapping tolerance validation" begin
  for invalid in (-1, Inf, NaN, big"1e-1000")
    @test_throws ArgumentError ProximalGradientMapping(rtol=invalid)
  end
end

end
