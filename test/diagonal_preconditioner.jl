module DiagonalPreconditionerTests
using Test, Random, LinearAlgebra, SparseArrays
using ProximalBase, ProximalSolvers
const PS = ProximalSolvers

@testset "diagonal metric matches a change of coordinates" begin
  rng = Xoshiro(92)
  for T in (Float32, Float64), solver in (ProximalGradientDescent, AccProxGradDescent)
    X = T.(randn(rng, 60, 8)) .* reshape(T.(10 .^ range(-1, 1; length=8)), 1, :)
    y = T.(randn(rng, 60))
    f = LeastSquaresLoss(y, X)
    d = coordinate_lipschitz!(zeros(T, 8), f)
    root = sqrt.(d)
    fs = LeastSquaresLoss(y, X ./ root')
    g = NormL1(T(0.2))
    gs = NormL1(T(0.2), inv.(root))
    opt = ProximalOptions(; allow_f_increases=true)
    a = PS.initial_state(solver(; preconditioner=:diagonal), opt, f, g, zeros(T, 8))
    b = PS.initial_state(solver(), opt, fs, gs, zeros(T, 8))
    for k in 1:(T === Float32 ? 5 : 12)
      PS.update_state!(f, g, a, solver(; preconditioner=:diagonal))
      PS.update_state!(fs, gs, b, solver())
      atol = T === Float32 ? 3e-4 : 1e-10
      @test root .* a.x ≈ b.x atol=atol
      @test a.L ≈ b.L rtol=atol
      @test PS.g_residual(a) ≈ PS.g_residual(b) atol=atol
      @test PS.convergence_assessment(a, f, g, opt)[1:4] == PS.convergence_assessment(b, fs, gs, opt)[1:4]
    end
    @test a.backtrack_steps == b.backtrack_steps
  end
end

@testset "scaled designs, gaps and reusable metric" begin
  rng = Xoshiro(93)
  X = randn(rng, 100, 12) .* (10 .^ range(0, 3; length=12))'
  y = X * (ones(12) ./ (10 .^ range(0, 3; length=12))) + 0.1randn(rng, 100)
  f, g = LeastSquaresLoss(y, X), NormL1(0.2)
  opt = ProximalOptions(; maxiter=2000, gaptol=1e-6, gapevery=5)
  for solver in (ProximalGradientDescent, AccProxGradDescent)
    x = zeros(12)
    r = solve!(x, f, g, solver(; preconditioner=:diagonal), opt)
    @test r.converged
    @test r.gap <= opt.gaptol
    @test r.iterations < 500
    scalar = solve!(zeros(12), f, g, solver(), opt)
    @test !scalar.converged
    @test scalar.gap > 100 * opt.gaptol
    ws = SolverWorkspace(zeros(12), f, g, solver(; preconditioner=:diagonal), opt)
    metric = ws.buffers.state.metric
    rw = solve!(ws)
    @test rw.minimum ≈ r.minimum
    reinit!(ws, zeros(12))
    @test solve!(ws).minimizer ≈ x
    @test ws.buffers.state.metric === metric
  end
end

@testset "penalties and matrix iterates" begin
  A = Matrix(Diagonal([1., 100., 4., 40.]))
  f = QuadraticFunction(A, [-2., -20., 1., -5.])
  opt = ProximalOptions(; maxiter=1000, ftol=1e-12, xtol=1e-12, gradtol=1e-10)
  penalties = (ZeroFunction(), NormL1(0.1), GroupNormL2(0.1, [1:2, 3:4]), GroupNormLinf(0.1, [1:2, 3:4]), 0.5GroupNormL2(0.1, [1:2, 3:4]),
               IndSimplex(1.0), IndBallL1(1.0))
  for solver in (ProximalGradientDescent, AccProxGradDescent), g in penalties
    x = zeros(4)
    r = solve!(x, f, g, solver(; preconditioner=:diagonal), opt)
    z = zeros(4)
    rs = solve!(z, f, g, solver(), opt)
    @test r.minimum ≈ rs.minimum atol=1e-7
    @test x ≈ z atol=1e-4
  end
  X = [1. 2.; 3. 0.; 1. 4.]
  Y = [1. 0.; 2. 1.; -1. 3.]
  for solver in (ProximalGradientDescent, AccProxGradDescent)
    x = zeros(2, 2)
    solve!(x, LeastSquaresLoss(Y, X), NormL1(0.1), solver(; preconditioner=:diagonal), opt)
    z = zeros(2, 2)
    solve!(z, LeastSquaresLoss(Y, X), NormL1(0.1), solver(), opt)
    @test x ≈ z atol=1e-4
  end
end

@testset "validation and scalar defaults" begin
  @test_throws ArgumentError ProximalGradientDescent(; preconditioner=:unknown)
  @test_throws ArgumentError AccProxGradDescent(; preconditioner=:unknown)
  @test_throws ArgumentError ProximalGradientDescent(; preconditioner=:diagonal, normalized=true)
  for solver in (ProximalGradientDescent, AccProxGradDescent)
    @test_throws ArgumentError solve!(zeros(2), PoissonLoss([0., 1.], ones(2, 2)), NormL1(), solver(; preconditioner=:diagonal))
    @test_throws ArgumentError solve!((zeros(2),), SeparableSum(SqrNormL2()), SeparableSum(NormL1()), solver(; preconditioner=:diagonal))
    # Flat coordinates get unit weights and are still optimized by the prox.
    x = [0., 2.]
    solve!(x, QuadraticFunction(Diagonal([1., 0.]), [-1., 0.]), NormL1(0.1), solver(; preconditioner=:diagonal))
    @test x ≈ [0.9, 0.] atol=1e-4
    f, g = SqrNormL2(), NormL1(0.1)
    a, b = [2., -3.], [2., -3.]
    ra, rb = solve!(a, f, g, solver()), solve!(b, f, g, solver(; preconditioner=:none))
    @test a == b
    @test ra.iterations == rb.iterations
    @test ra.backtrack_steps == rb.backtrack_steps
  end
end

@testset "lazy coordinate curvature contracts" begin
  rng = Xoshiro(94)
  X = randn(rng, 20, 5)
  y = randn(rng, 20)
  for XX in (X, sparse(X)), f in (0.7LeastSquaresLoss(y, XX), 0.7LogisticLoss(Float64.(y .> 0), XX))
    x = SparseIterate(5)
    m = cdmodel(f, x)
    PS.initialize!(m, x)
    for k in 1:5
      a = m isa PS.LSModel ? m.s * PS._sqnorm!(m, k) : PS._curvaturebound!(m, k)
      @test a ≈ coordinate_lipschitz(f, k)
    end
  end
  # Symmetric storage moves both entries: its curvature includes their cross term.
  A = randn(rng, 3, 3); A = A'A + I
  B = randn(rng, 3, 3); B = B'B + I
  f = KronQuadratic(A, B)
  for c in 1:3, r in c:3
    k, l = r + 3(c-1), c + 3(r-1)
    expected = coordinate_lipschitz(f, k)
    r == c || (expected += coordinate_lipschitz(f, l) + 2A[r,c]*B[r,c])
    @test PS._symcurvature(A, B, r, c) ≈ expected
  end
end
end
