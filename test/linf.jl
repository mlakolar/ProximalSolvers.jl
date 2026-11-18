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
    @test kkt(X, y, 1, x) > 1
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

@testset "refusals before any change of x" begin
  for T in (Float64, Float32)
    X, y, x = T[1 0; 0 2], T[1, -1], T[.3, -.2]
    f = LeastSquaresLoss(y, X)
    for method in METHODS
      refused(copy(x), f, NormLinf(T(Inf)), method, "penalty lambda must be finite and nonnegative")
      refused(copy(x), f, Scaled(NormLinf(T(.1)), 2), method, "only NormL1, unweighted ElasticNet or NormLinf is supported")
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

end
