module NonnegativeLassoTest
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers

function independent(X, y, x, lambda, alpha)
  # Accumulate in Float64 to avoid reusing the solver's Float32 rounding path.
  A, b, v = Float64.(X), Float64.(y), Float64.(x)
  grad = Float64(alpha) * (A' * (A * v - b))
  r = maximum(j -> v[j] > 0 ? abs(grad[j] + lambda) : max(-(grad[j] + lambda), 0), eachindex(v))
  (; r, obj=Float64(alpha)/2 * sum(abs2, A*v-b) + lambda*sum(v))
end

@testset "dense PGD nonnegative lasso $T" for T in (Float32, Float64)
  X = Matrix{T}(I, 4, 4)
  y = T[2, -1.5, 0.1, -0.2]
  alpha, lambda = T(0.25), T(0.1)
  f, g = alpha * LeastSquaresLoss(y, X), NormL1Nonneg(lambda)
  opts = ProximalOptions(maxiter=5000, ftol=0, xtol=1e-12,
    gradtol=T === Float32 ? 1e-5 : 1e-10, allow_f_increases=true)
  tol = T === Float32 ? 5e-5 : 1e-8
  for initial in (zeros(T, 4), fill(T(0.5), 4)), level in (lambda, Float64(lambda), 0)
    x = copy(initial)
    r = solve!(x, f, NormL1Nonneg(level), ProximalGradientDescent(), opts)
    reference = max.(y .- T(level)/alpha, 0)
    @test x ≈ reference atol=tol rtol=tol
    @test minimum(x) >= 0
    check = independent(X, y, x, T(level), alpha)
    @test check.r <= tol
    @test r.minimum ≈ check.obj atol=tol rtol=tol
    @test r.minimizer === x
  end
  # A positive derivative on an inactive coordinate satisfies constrained KKT.
  x = zeros(T, 4)
  r = solve!(x, f, g, ProximalGradientDescent(), opts)
  @test r.converged
  @test x[2] == 0
  @test (alpha * (X'*(X*x-y)))[2] > lambda

  # Correlated design: clipping ordinary lasso violates constrained stationarity.
  A = T[1 0.8; 0 0.6]
  b = A * T[2, -1]
  v = zeros(T, 2)
  rr = solve!(v, LeastSquaresLoss(b, A), NormL1Nonneg(T(0.1)), ProximalGradientDescent(), opts)
  @test v ≈ T[1.1, 0] atol=tol rtol=tol
  @test independent(A,b,v,T(0.1),one(T)).r <= tol
  @test rr.minimum ≈ independent(A,b,v,T(0.1),one(T)).obj atol=tol rtol=tol

  # All refusals leave the caller's coefficients unchanged.
  v = fill(T(0.3), 4); before = copy(v)
  @test_throws ArgumentError solve!(v, f, g, AccProxGradDescent())
  @test v == before
  # CDSolver accepts the penalty on a dense Vector (test/cd_nonnegative.jl); its refusals are there too.
  v = fill(T(0.3), 4)
  @test solve!(v, f, g, CDSolver(order=:cyclic, momentum=false)).minimizer === v
  @test minimum(v) >= 0
  for badg in (NormL1Nonneg(lambda, ones(T,4)), NormL1Nonneg(Inf),
               NormL1Nonneg(big(10)^1000), NormL1Nonneg(big(10.0)^(-1000)))
    v = fill(T(0.3), 4); before = copy(v)
    @test_throws ArgumentError solve!(v, f, badg, ProximalGradientDescent())
    @test v == before
  end
  v = T[0.1,-0.1,0.2,0]; before=copy(v)
  @test_throws ArgumentError solve!(v, f, g, ProximalGradientDescent())
  @test v == before
  sparse_x = SparseIterate(zeros(T,4))
  @test_throws ArgumentError solve!(sparse_x,f,g,ProximalGradientDescent())
  @test_throws ArgumentError solve!(sparse_x,f,g,CDSolver())
  block_x = BlockIterate(zeros(T,4), [[1,2],[3,4]])
  @test_throws ArgumentError solve!(block_x,f,g,CDSolver(momentum=false))
  @test_throws ArgumentError solve!(zeros(T,4),SqrtLeastSquaresLoss(y,X),g,ProximalGradientDescent())
end
end
