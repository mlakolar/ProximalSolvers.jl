module ProxSolversTest

using Test
using Random
using LinearAlgebra
using ProximalBase
using ProximalSolvers

Random.seed!(1)

mutable struct StopAfter
  calls::Int
  limit::Int
end
(callback::StopAfter)(state) = (callback.calls += 1; callback.calls >= callback.limit)

@testset "callable callbacks" for solver in (ProximalGradientDescent(), AccProxGradDescent(),
                                            MonotoneAccProxGradDescent()), store_trace in (false, true)
  callback = StopAfter(0, 2)
  options = ProximalOptions(; callback, store_trace, print_every = 2,
                             ftol = 1e-300, xtol = 1e-300, gradtol = 1e-300)
  @test options.callback === callback
  f = QuadraticFunction(Matrix(Diagonal([1., 10., 100.])), [-1., -1., -1.])
  result = solve!(zeros(3), f, NormL1(0.1), solver, options)
  @test callback.calls == 2
  @test result.iterations == 4
  @test length(result.trace) == (store_trace ? 4 : 0)
end

opt = ProximalOptions(; ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10, maxiter = 5000)

@testset "$(summary(solver))" for solver in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())

  @testset "L2Loss + no penalty" begin
    x = randn(5)
    y = randn(5)

    solve!(x, SqrNormL2(), ZeroFunction(), solver, opt)
    @test norm(x) ≈ 0. atol = 1e-5

    solve!(x, SqrNormL2(1, y), ZeroFunction(), solver, opt)
    @test x ≈ y atol = 1e-5
  end

  @testset "L2Loss + l1 penalty" begin
    x = randn(5)
    y = randn(5) .+ 1.
    g = NormL1(0.1)

    solve!(x, SqrNormL2(1, y), g, solver, opt)
    @test x ≈ prox(g, y) atol = 1e-5
  end

  @testset "L2Loss + nuclear norm" begin
    x = randn(10, 10)
    y = randn(30, 10)
    y = y'y

    U, S, V = svd(y)
    S = max.(S .- 0.1, 0.)
    tx = U * Diagonal(S) * V'

    solve!(x, SqrNormL2(1, y), NuclearNorm(0.1), solver, opt)
    @test x ≈ tx atol = 1e-3
  end

  @testset "quadratic + no penalty" begin
    A = randn(20, 10)
    A = A'A / 20
    b = randn(10)
    f = QuadraticFunction(A, b, 1.)

    x = randn(10)
    solve!(x, f, ZeroFunction(), solver, opt)
    @test x ≈ -(A \ b) atol = 1e-4
  end

  @testset "ridge regression" begin
    n, p = 200, 30
    X = randn(n, p)
    Y = X * ones(p) + 0.1 * randn(n)
    f = QuadraticFunction(X'X / n, -X'Y / n)

    # SqrNormL2(2λ) is λ‖x‖², so the minimizer solves (X'X/n + 2λI) x = X'Y/n
    for λ in (0., 1.)
      hat_beta = zeros(p)
      solve!(hat_beta, f, SqrNormL2(2λ), solver, opt)
      @test hat_beta ≈ (X'X / n + 2λ * I) \ (X'Y / n) atol = 1e-4
    end
  end

  @testset "lasso" begin
    n, p = 100, 50
    X = randn(n, p)
    β = vcat(randn(5), zeros(p - 5))
    Y = X * β + 0.1 * randn(n)
    A, b = X'X / n, -X'Y / n
    λ = 0.1 * norm(b, Inf)

    x = zeros(p)
    res = solve!(x, QuadraticFunction(A, b), NormL1(λ), solver, opt)
    @test res.iterations < opt.maxiter

    # KKT conditions: ∇f(x) = -λ sign(x) on the support, |∇f(x)| ≤ λ off it
    grad = A * x + b
    S = abs.(x) .> 1e-8
    @test any(S)
    @test grad[S] ≈ -λ * sign.(x[S]) atol = 1e-4
    @test all(abs.(grad[.!S]) .<= λ + 1e-4)
  end

end

@testset "gradient residual stops $(summary(solver))" for solver in (ProximalGradientDescent(), AccProxGradDescent(),
                                                                   MonotoneAccProxGradDescent())
  # with ftol and xtol out of reach, only the FASTA residual can stop the solver;
  # it must reach zero at a lasso solution where ∇f(x) ≠ 0
  n, p = 100, 50
  X = randn(n, p)
  Y = X * vcat(randn(5), zeros(p - 5)) + 0.1 * randn(n)
  A, b = X'X / n, -X'Y / n
  λ = 0.1 * norm(b, Inf)

  x = zeros(p)
  opt = ProximalOptions(; ftol = 1e-300, xtol = 1e-300, gradtol = 1e-6, maxiter = 5000)
  res = solve!(x, QuadraticFunction(A, b), NormL1(λ), solver, opt)
  @test res.grad_converged
  @test res.iterations < opt.maxiter
  @test res.g_residual < 1e-5

  # the solver stopped near a solution: KKT conditions hold
  grad = A * x + b
  S = abs.(x) .> 1e-8
  @test grad[S] ≈ -λ * sign.(x[S]) atol = 1e-4
  @test all(abs.(grad[.!S]) .<= λ + 1e-4)
end

@testset "SparseIterate $(summary(solver))" for solver in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())
  # the iterates stay SparseIterates, without stored zeros at the end, and give
  # the dense solution; ‖Y - Xx‖² / (2n) is the quadratic up to a constant
  n, p = 100, 50
  X = randn(n, p)
  Y = X * vcat(randn(5), zeros(p - 5)) + 0.1 * randn(n)
  A, b = X'X / n, -X'Y / n
  g = NormL1(0.1 * norm(b, Inf))
  for f in (QuadraticFunction(A, b), LeastSquaresLoss(Y / sqrt(n), X / sqrt(n)))
    xd, x = zeros(p), SparseIterate(p)
    solve!(xd, f, g, solver, opt)
    res = solve!(x, f, g, solver, opt)
    @test res.minimizer === x
    @test ProximalSolvers.converged(res)
    @test 0 < nnz(x) == count(!iszero, Vector(x)) < p
    @test Vector(x) ≈ xd atol = 1e-5
    @test res.minimum ≈ f(xd) + g(xd)
  end
end

@testset "Float32 $(summary(solver))" for solver in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent(),
                                                    ActiveAccProxGradDescent())
  # the iterates, the minimum and the arithmetic stay in Float32; the solution
  # agrees with Float64 to Float32 accuracy. The tolerances must be above the
  # precision of Float32, eps(Float32) ≈ 1.2e-7
  n, p = 60, 25
  X, Y = randn(n, p), randn(n)
  A, b = X'X / n, -X'Y / n
  for (f32, f64) in ((QuadraticFunction(Float32.(A), Float32.(b)), QuadraticFunction(A, b)),
                     (LeastSquaresLoss(Float32.(Y), Float32.(X)), LeastSquaresLoss(Y, X)))
    x32, x64 = zeros(Float32, p), zeros(p)
    res = solve!(x32, f32, NormL1(0.05f0), solver, ProximalOptions(; maxiter = 5000, ftol = 1e-6, xtol = 1e-6, gradtol = 1e-5))
    solve!(x64, f64, NormL1(0.05), solver, ProximalOptions(; maxiter = 5000, ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10))
    @test eltype(x32) == Float32
    @test res.minimum isa Float32
    @test ProximalSolvers.converged(res)
    @test x32 ≈ x64 atol = 1e-2
  end
end

end
