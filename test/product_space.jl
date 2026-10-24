module ProductSpaceTest

using Test
using Random
using LinearAlgebra
using Statistics
using ProximalBase
using ProximalSolvers

# The fused graphical lasso penalty λ₁(‖A‖₁ + ‖B‖₁) + λ₂‖A - B‖₁ on a pair of
# matrices, with the diagonal left out of the λ₁ term, entry by entry through
# the closed form of NormL1Fused
struct PairFused{T} <: AbstractFunction
  λ1::T
  λ2::T
end
ProximalBase.isproximable(::Type{<:PairFused}) = true
ProximalBase.isconvex(::Type{<:PairFused}) = true

function (f::PairFused)(x::Tuple)
  A, B = x
  v = zero(eltype(A))
  for j in axes(A, 2), i in axes(A, 1)
    v += (i == j ? 0 : f.λ1) * (abs(A[i, j]) + abs(B[i, j])) + f.λ2 * abs(A[i, j] - B[i, j])
  end
  v
end

function ProximalBase.prox!(y::Tuple, f::PairFused, x::Tuple, γ::Real)
  (A, B), (U, V) = x, y
  for j in axes(A, 2), i in axes(A, 1)
    h = NormL1Fused(i == j ? zero(f.λ1) : f.λ1, f.λ2)
    U[i, j], V[i, j] = prox(h, (A[i, j], B[i, j]), γ)
  end
  y
end

ProximalBase.value_and_prox!(y::Tuple, f::PairFused, x::Tuple, γ::Real) = (prox!(y, f, x, γ); f(y))

# the sum of the Euclidean norms of the blocks, with a method for the difference
# of two tuples
struct BlockNorm end
(::BlockNorm)(x::Tuple) = sum(LinearAlgebra.norm, x)
(::BlockNorm)(x::Tuple, y::Tuple) = sum(map(norm_diff, x, y))

solvers = (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())

@testset "a tuple of one array is the array $(summary(method))" for method in (solvers..., ProximalGradientDescent(; normalized = true))
  rng = Xoshiro(1)
  n, p = 60, 20
  X, y = randn(rng, n, p), randn(rng, n)
  f, g = QuadraticFunction(X'X / n, -X'y / n), NormL1(0.05)
  opt = ProximalOptions(; ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10, maxiter = 2000)
  x = zeros(p)
  r1 = solve!(x, f, g, method, opt)
  xt = (zeros(p),)
  r2 = solve!(xt, SeparableSum(f), SeparableSum(g), method, opt)
  @test r2.minimizer === xt
  @test x == xt[1]
  @test (r1.iterations, r1.minimum, r1.f_calls, r1.prox_calls) == (r2.iterations, r2.minimum, r2.f_calls, r2.prox_calls)
  @test (r1.x_residual, r1.f_residual, r1.g_residual) == (r2.x_residual, r2.f_residual, r2.g_residual)
  @test occursin("Minimizer", sprint(show, r2))
end

@testset "normalized steps use the support of the whole product space" begin
  PS = ProximalSolvers
  for T in (Float32, Float64)
    A = T[2 0; 0 5]
    f = SeparableSum(QuadraticFunction(A, T[-1, 2]), SqrNormL2(T(3), ones(T, 2, 1)))
    g = SeparableSum(ZeroFunction(), ZeroFunction())
    method = ProximalGradientDescent(; normalized = true)
    for x0 in ((zeros(T, 2), zeros(T, 2, 1)),
               (T[1, 0], zeros(T, 2, 1)),
               (zeros(T, 2), reshape(T[0.2, 0], 2, 1)))
      st = PS.initial_state(method, ProximalOptions(), f, g, map(copy, x0))
      foreach(copyto!, st.x_previous, st.x)
      foreach(copyto!, st.grad_f_x_previous, st.grad_f_x)
      st.f_x_previous = st.f_x
      st.L = T(2)
      whole = all(block -> all(iszero, block), x0)
      d = map((x, grad) -> map((v, a) -> whole || !iszero(v) ? a : zero(T), x, grad),
              x0, st.grad_f_x)
      dd = sum(block -> sum(abs2, block), d)
      curvature = dot(d[1], A * d[1]) + T(3) * sum(abs2, d[2])
      expected_trial = map((x, dk) -> x .- dk ./ T(2), x0, d)
      PS._normalized_step!(f, st)
      @test st.L ≈ curvature / dd rtol = (T === Float32 ? 2e-5 : 1e-12)
      @test st.xhat[1] ≈ expected_trial[1]
      @test st.xhat[2] ≈ expected_trial[2]
      # A wholly zero block does not expand an already nonempty support.
      !whole && all(iszero, x0[2]) && @test all(iszero, st.xhat[2])
    end
  end
end

@testset "a tuple of one array is the array: ADMM" begin
  rng = Xoshiro(2)
  n, p = 60, 20
  X, y = randn(rng, n, p), randn(rng, n)
  f, g = LeastSquaresLoss(y, X), NormL1(0.5)
  for method in (ADMMSolver(), ADMMSolver(; α = 1.6, adaptive = true))
    x = zeros(p)
    r1 = solve!(x, f, g, method)
    xt = (zeros(p),)
    r2 = solve!(xt, SeparableSum(f), SeparableSum(g), method)
    @test x == xt[1]
    @test (r1.iterations, r1.ρ, r1.r_norm, r1.s_norm) == (r2.iterations, r2.ρ, r2.r_norm, r2.s_norm)
    @test r2.u isa Tuple{Vector{Float64}} && r2.u[1] == r1.u
  end
end

@testset "two separate problems as one $(summary(method))" for method in (solvers..., ADMMSolver(; adaptive = true))
  rng = Xoshiro(3)
  n = 80
  X1, X2 = randn(rng, n, 15), randn(rng, n, 25)
  y1, y2 = randn(rng, n), randn(rng, n)
  if method isa ADMMSolver
    f1, f2 = LeastSquaresLoss(y1, X1), LeastSquaresLoss(y2, X2)
    g1, g2 = NormL1(1.0), NormL1(2.0)
    opt = ProximalOptions(; maxiter = 20_000)
    method = ADMMSolver(; adaptive = true, abstol = 1e-10, reltol = 1e-10)
  else
    f1, f2 = (1 / n) * LeastSquaresLoss(y1, X1), (1 / n) * LeastSquaresLoss(y2, X2)
    g1, g2 = NormL1(0.05), NormL1(0.1)
    opt = ProximalOptions(; ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12, maxiter = 20_000)
  end
  x1, x2 = zeros(15), zeros(25)
  solve!(x1, f1, g1, method, opt)
  solve!(x2, f2, g2, method, opt)
  xt = (zeros(15), zeros(25))
  r = solve!(xt, SeparableSum(f1, f2), SeparableSum(g1, g2), method, opt)
  @test xt[1] ≈ x1 rtol = 1e-6
  @test xt[2] ≈ x2 rtol = 1e-6
  @test r.minimum ≈ f1(x1) + g1(x1) + f2(x2) + g2(x2) rtol = 1e-9
end

@testset "the fused graphical lasso for two groups" begin
  rng = Xoshiro(4)
  p, nx, ny = 15, 200, 150
  Ω = Matrix(SymTridiagonal(fill(1.0, p), fill(0.4, p - 1)))
  Ωy = copy(Ω); Ωy[1, 3] = Ωy[3, 1] = 0.3
  Sx = cov(randn(rng, nx, p) / cholesky(Ω).U')
  Sy = cov(randn(rng, ny, p) / cholesky(Ωy).U')
  n = nx + ny
  f = SeparableSum((nx / n) * LogDetLoss(Sx), (ny / n) * LogDetLoss(Sy))
  g = PairFused(0.05, 0.05)

  x = (Matrix(1.0I, p, p), Matrix(1.0I, p, p))
  r = solve!(x, f, g, ADMMSolver(; α = 1.5, adaptive = true, abstol = 1e-9, reltol = 1e-9), ProximalOptions(; maxiter = 50_000))
  @test ProximalSolvers.converged(r)
  # x is a fixed point of the proximal gradient step, which characterizes the minimizer
  G = (zeros(p, p), zeros(p, p))
  value_and_gradient!(G, f, x)
  γ = 0.1
  step = prox!((zeros(p, p), zeros(p, p)), g, (x[1] - γ * G[1], x[2] - γ * G[2]), γ)
  @test max(norm(step[1] - x[1]), norm(step[2] - x[2])) / γ < 1e-6
  @test issymmetric(x[1]) && issymmetric(x[2])

  # the accelerated gradient method on the pair finds the same solution
  xa = (Matrix(1.0I, p, p), Matrix(1.0I, p, p))
  ra = solve!(xa, f, g, AccProxGradDescent(), ProximalOptions(; ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12, maxiter = 50_000))
  @test ra.minimum ≈ r.minimum rtol = 1e-8
  @test norm(xa[1] - x[1]) + norm(xa[2] - x[2]) < 1e-4

  # warm start from the result
  r2 = solve!(map(copy, x), f, g, ADMMSolver(; ρ = r.ρ, α = 1.5, abstol = 1e-9, reltol = 1e-9), ProximalOptions(; maxiter = 50_000); u = map(copy, r.u))
  @test r2.iterations < r.iterations

  # residuals in the sum of the norms of the blocks (the norm of CovarianceSelection's
  # fusedGraphicalLasso! loop), and the same norm with a method for differences
  blocknorm = x -> sum(LinearAlgebra.norm, x)
  admm(nrm) = ADMMSolver(; α = 1.5, adaptive = true, abstol = 1e-9, reltol = 1e-9, norm = nrm)
  rs = solve!((Matrix(1.0I, p, p), Matrix(1.0I, p, p)), f, g, admm(blocknorm), ProximalOptions(; maxiter = 50_000))
  @test ProximalSolvers.converged(rs)
  @test rs.minimum ≈ r.minimum rtol = 1e-8
  rd = solve!((Matrix(1.0I, p, p), Matrix(1.0I, p, p)), f, g, admm(BlockNorm()), ProximalOptions(; maxiter = 50_000))
  @test rd.iterations == rs.iterations
  @test rd.minimizer[1] ≈ rs.minimizer[1] rtol = 1e-12
end

@testset "a tuple of one array is the array: ADMM with a norm" begin
  rng = Xoshiro(7)
  n, p = 60, 20
  X, y = randn(rng, n, p), randn(rng, n)
  f, g = LeastSquaresLoss(y, X), NormL1(0.5)
  method = ADMMSolver(; adaptive = true, norm = x -> 2 * LinearAlgebra.norm(x))
  tmethod = ADMMSolver(; adaptive = true, norm = x -> 2 * LinearAlgebra.norm(x[1]))
  x = zeros(p)
  r1 = solve!(x, f, g, method)
  xt = (zeros(p),)
  r2 = solve!(xt, SeparableSum(f), SeparableSum(g), tmethod)
  @test x == xt[1]
  @test (r1.iterations, r1.ρ, r1.r_norm, r1.s_norm) == (r2.iterations, r2.ρ, r2.r_norm, r2.s_norm)
end

@testset "Float32 blocks" begin
  rng = Xoshiro(5)
  n = 50
  X1, X2 = randn(rng, Float32, n, 10), randn(rng, Float32, n, 12)
  y1, y2 = randn(rng, Float32, n), randn(rng, Float32, n)
  f = SeparableSum((1f0 / n) * LeastSquaresLoss(y1, X1), (1f0 / n) * LeastSquaresLoss(y2, X2))
  g = SeparableSum(NormL1(0.05f0), NormL1(0.05f0))
  for method in solvers
    xt = (zeros(Float32, 10), zeros(Float32, 12))
    r = solve!(xt, f, g, method, ProximalOptions(; ftol = 1e-6, xtol = 1e-6, gradtol = 1e-5))
    @test r.minimum isa Float32 && eltype(xt[2]) == Float32
  end
  fa = SeparableSum(LeastSquaresLoss(y1, X1), LeastSquaresLoss(y2, X2))
  xt = (zeros(Float32, 10), zeros(Float32, 12))
  r = solve!(xt, fa, SeparableSum(NormL1(1f0), NormL1(1f0)), ADMMSolver(; adaptive = true))
  @test r.minimum isa Float32 && r.u isa Tuple{Vector{Float32}, Vector{Float32}}
end

@testset "no allocations per iteration" begin
  rng = Xoshiro(6)
  n = 50
  X1, X2 = randn(rng, n, 10), randn(rng, n, 12)
  y1, y2 = randn(rng, n), randn(rng, n)
  fq = SeparableSum(QuadraticFunction(X1'X1 / n, -X1'y1 / n), QuadraticFunction(X2'X2 / n, -X2'y2 / n))
  fl = SeparableSum(LeastSquaresLoss(y1, X1), LeastSquaresLoss(y2, X2))
  g = SeparableSum(NormL1(0.01), NormL1(0.01))
  x0 = (zeros(10), zeros(12))
  # an iteration of a gradient method, after a few
  function step_bytes(f, g, method, x0)
    state = ProximalSolvers.initial_state(method, ProximalOptions(), f, g, map(copy, x0))
    for _ in 1:5
      ProximalSolvers.update_state!(f, g, state, method)
    end
    @allocated ProximalSolvers.update_state!(f, g, state, method)
  end
  for method in (solvers..., ProximalGradientDescent(; normalized = true))
    @test step_bytes(fq, g, method, x0) == 0
  end
  # ADMM: the bytes of 40 iterations less those of 20, which never converge to
  # tolerances of 1e-300
  admm = ADMMSolver(; abstol = 1e-300, reltol = 1e-300)
  run(m) = (x = map(copy, x0); r = solve!(x, fl, g, admm, ProximalOptions(; maxiter = m)); r.iterations)
  run(20); run(40)
  b20 = @allocated i20 = run(20)
  b40 = @allocated i40 = run(40)
  @test (i20, i40) == (20, 40)
  @test b40 == b20
end

@testset "errors" begin
  f = SeparableSum(SqrNormL2(), SqrNormL2())
  g = SeparableSum(NormL1(0.1), NormL1(0.1))
  @test_throws DimensionMismatch solve!((zeros(3), zeros(4)), f, g, ADMMSolver(); u = (zeros(3), zeros(5)))
  @test_throws DimensionMismatch solve!((zeros(3), zeros(4)), f, g, ADMMSolver(); u = (zeros(3),))
  @test_throws ArgumentError solve!((zeros(3), zeros(4)), f, g, ProximalGradientDescent(; debias = 1))
end

end
