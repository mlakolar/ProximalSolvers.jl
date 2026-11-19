module NonnegativeLeastSquaresTest
using Test, LinearAlgebra, SparseArrays, ProximalBase, ProximalSolvers

function independent(X, y, beta, scale)
  A, b, v = Float64.(X), Float64.(y), Float64.(beta)
  residual = A * v - b
  (; gradient=Float64(scale) * (A' * residual),
     objective=Float64(scale) * sum(abs2, residual) / 2)
end

@testset "Dense PGD nonnegative least squares $T" for T in (Float32, Float64)
  X = Matrix{T}(I, 4, 4)
  y = T[2, -1.5, 0.1, -0.2]
  g, method = IndNonnegative(), ProximalGradientDescent()
  options = ProximalOptions(maxiter=5000, ftol=eps(T), xtol=1e-12,
    gradtol=T === Float32 ? 1e-5 : 1e-10, allow_f_increases=true)
  tol = T === Float32 ? 5e-5 : 1e-8

  # Correlated columns: the unconstrained solution [2, -1, -2] gives
  # [2, 0, 0] after clipping, but the constrained optimum is [1.2, 0, 0].
  A = T[1 0.8 0; 0 0.6 0; 0 0 1]
  b = A * T[2, -1, -2]
  @testset "$label from $init" for
      (label, design, response, reference, scale) in
        (("identity", X, y, max.(y, 0), T(0.25)),
         ("correlated", A, b, T[1.2, 0, 0], one(T))),
      init in (zero(T), T(0.5))
    beta = fill(init, size(design, 2))
    f = LeastSquaresLoss(response, design)
    loss = isone(scale) ? f : scale * f
    result = solve!(beta, loss, g, method, options)
    @test result.converged
    @test result.minimizer === beta
    @test beta ≈ reference atol=tol rtol=0
    @test all(>=(0), beta)
    @test findall(iszero, beta) == findall(iszero, reference)
    check = independent(design, response, beta, scale)
    @test minimum(check.gradient) >= -tol
    @test maximum(abs, check.gradient[beta .> 0]) <= tol
    @test all(>(0), check.gradient[iszero.(beta)])
    @test maximum(abs, beta .* check.gradient) <= 2tol
    @test result.minimum ≈ check.objective atol=tol rtol=0

    equivalent = fill(init, length(beta))
    zero_penalty = solve!(equivalent, loss, NormL1Nonneg(zero(T)), method, options)
    @test equivalent ≈ beta atol=tol rtol=0
    @test zero_penalty.minimum ≈ result.minimum atol=tol rtol=0
  end

  @testset "Objective proposal at a nonstationary positive coefficient" begin
    A = T[1 0; 0 1/64]
    b = T[2, -1]
    beta = T[2, 1]
    f = LeastSquaresLoss(b, A)
    before = independent(A, b, beta, one(T)).objective
    ftol = 0.01
    result = solve!(beta, f, g, method, ProximalOptions(maxiter=2, ftol=ftol))
    check = independent(A, b, beta, one(T))
    @test 0 < (before - check.objective) / check.objective < ftol
    @test all(>(0), beta)
    @test minimum(check.gradient) >= 0
    @test check.gradient[2] > 0.01
    @test result.iteration_converged
    @test !result.f_converged
    @test !result.converged
  end

  @testset "Refusals before writes" begin
    f = LeastSquaresLoss(y, X)
    start = fill(T(0.3), 4)
    for (beta, loss, penalty, solver) in (
        (T[0.1, -0.1, 0.2, 0], f, g, method),
        (T[0.1, Inf, 0.2, 0], f, g, method),
        (copy(start), LeastSquaresLoss(T[2, NaN, 0.1, -0.2], X), g, method),
        (copy(start), LeastSquaresLoss(y, sparse(X)), g, method),
        (copy(start), LeastSquaresLoss(hcat(y, y), X), g, method),
        (copy(start), f, g, AccProxGradDescent()),
        (copy(start), f, g, CDSolver()),
        (copy(start), f, 2 * g, method),
        (copy(start), zero(T) * f, g, method),
        (copy(start), SqrtLeastSquaresLoss(y, X), g, method),
        (ones(BigFloat, 4), f, g, method),
        (view(copy(start), :), f, g, method),
        (reshape(copy(start), 2, 2), f, g, method),
        (SparseIterate(copy(start)), f, g, method),
        (SparseIterate(copy(start)), f, g, CDSolver()),
        (BlockIterate(copy(start), [[1,2],[3,4]]), f, g, method),
        (BlockIterate(copy(start), [[1,2],[3,4]]), f, g, CDSolver(momentum=false)),
        (start, LeastSquaresLoss(start, X), g, method))
      before = collect(beta)
      @test_throws ArgumentError solve!(beta, loss, penalty, solver)
      @test isequal(collect(beta), before)
    end
    other = T === Float32 ? Float64 : Float32
    @test_throws ArgumentError solve!(zeros(other, 4), f, g, method)
    @test_throws DimensionMismatch solve!(zeros(T, 3), f, g, method)

    # Two dense arrays can share the design's storage through vec.
    row = reshape(copy(start), 1, 4)
    aliased = vec(row)
    before = copy(aliased)
    @test_throws ArgumentError solve!(aliased, LeastSquaresLoss(T[1], row), g, method)
    @test aliased == before
  end
end
end
