module WorkspaceTests

using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

function same_gradient_result(a, b; atol = 1e-11)
  @test a.minimizer ≈ b.minimizer atol = atol
  @test a.minimum ≈ b.minimum atol = atol
  @test (a.iterations, a.f_calls, a.grad_calls, a.prox_calls, a.backtrack_steps) ==
        (b.iterations, b.f_calls, b.grad_calls, b.prox_calls, b.backtrack_steps)
  @test a.converged == b.converged
  @test isequal(a.gap, b.gap) || isapprox(a.gap, b.gap; atol)
end

@testset "gradient workspaces reset and reuse buffers" begin
  for T in (Float32, Float64), method in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())
    rng = Xoshiro(42)
    X, y = randn(rng, T, 40, 12), randn(rng, T, 40)
    f = T(1 / 40) * LeastSquaresLoss(y, X)
    options = ProximalOptions(; maxiter = 2000, ftol = T === Float32 ? 1e-6 : 1e-12,
                               xtol = T === Float32 ? 1e-6 : 1e-12,
                               gradtol = T === Float32 ? 1e-5 : 1e-10)
    for x in (zeros(T, 12), SparseIterate(T, 12))
      g = NormL1(T(0.03))
      ws = SolverWorkspace(x, f, g, method, options)
      buffers, state = ws.buffers, ws.buffers.state
      for level in (T(0.03), T(0.01), T(0.04))
        start = zeros(T, 12)
        start[2] = T(0.2)
        initial = x isa SparseIterate ? SparseIterate(start) : start
        reinit!(ws, initial)
        ref = solve!(copy(initial), f, NormL1(level), method, options)
        result = solve!(ws, NormL1(level))
        @test result.minimizer === x
        @test ws.buffers === buffers && ws.buffers.state === state
        same_gradient_result(result, ref; atol = T === Float32 ? 3e-5 : 1e-11)
      end
      @test_throws ArgumentError solve!(ws, ElasticNet(T(0.1), T(0.2)))
      @test_throws DimensionMismatch reinit!(ws, x isa SparseIterate ? SparseIterate(T, 11) : zeros(T, 11))
    end
  end
end

@testset "tuple, matrix and generic-loss workspaces" begin
  options = ProximalOptions(; maxiter = 1000, ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10)
  for method in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())
    x = (zeros(3), zeros(2, 2))
    f = SeparableSum(SqrNormL2(1.0, ones(3)), SqrNormL2(2.0, ones(2, 2)))
    g = SeparableSum(NormL1(0.1), NormL1(0.2))
    ws = SolverWorkspace(x, f, g, method, options)
    for _ in 1:2
      reinit!(ws, (zeros(3), zeros(2, 2)))
      result = solve!(ws)
      ref = solve!((zeros(3), zeros(2, 2)), f, g, method, options)
      @test result.minimizer === x
      @test all(a ≈ b for (a, b) in zip(x, ref.minimizer))
      @test result.iterations == ref.iterations
    end
    @test_throws DimensionMismatch reinit!(ws, (zeros(4), zeros(2, 2)))
    mat = zeros(2, 2)
    fm, gm = SqrNormL2(1.0, ones(2, 2)), NormL1(0.1)
    wm = SolverWorkspace(mat, fm, gm, method, options)
    same_gradient_result(solve!(wm), solve!(zeros(2, 2), fm, gm, method, options))
  end
end

@testset "tuple source aliases are rejected before mutation" begin
  x = (zeros(3), ones(3))
  f = SeparableSum(SqrNormL2(), SqrNormL2())
  g = SeparableSum(NormL1(0.1), NormL1(0.1))
  ws = SolverWorkspace(x, f, g, AccProxGradDescent())
  @test_throws ArgumentError reinit!(ws, (x[2], x[1]))
  @test x[1] == zeros(3) && x[2] == ones(3)
  @test_throws ArgumentError SolverWorkspace((x[1], x[1]), f, g, ADMMSolver())
  @test_throws ArgumentError SolverWorkspace((x[1], x[1]), f, g, AccProxGradDescent())
end

@testset "grouped gradient workspaces and nested partitions" begin
  groups = [1:3, 4:6, 7:9, 10:12]
  changed = [1:4, 5:8, 9:12]
  f = SqrNormL2(1.0, collect(0.1:0.1:1.2))
  options = ProximalOptions(; maxiter = 1000, ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10)
  for method in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())
    g = GroupNormL2(0.1, groups)
    ws = SolverWorkspace(AtomIterate(12, groups), f, g, method, options)
    for level in (0.1, 0.03, 0.2)
      reinit!(ws, AtomIterate(12, groups))
      penalty = GroupNormL2(level, groups)
      same_gradient_result(solve!(ws, penalty), solve!(AtomIterate(12, groups), f, penalty, method, options))
    end
    @test_throws ArgumentError solve!(ws, GroupNormL2(0.1, changed))
    # Nested penalties have the same concrete type even when their groups differ.
    ft = SeparableSum(f, SqrNormL2())
    gt = SeparableSum(2.0 * g, NormL1(0.1))
    wt = SolverWorkspace((zeros(12), zeros(2)), ft, gt, method, options)
    @test_throws ArgumentError solve!(wt, SeparableSum(2.0 * GroupNormL2(0.1, changed), NormL1(0.1)))
    result = solve!(wt, SeparableSum(2.0 * GroupNormL2(0.03, groups), NormL1(0.2)))
    @test result.converged
  end
end

@testset "gap and callback configuration is retained" begin
  X, y = Matrix(Diagonal([1., 2., 3.])), ones(3)
  f, g = LeastSquaresLoss(y, X), NormL1(0.1)
  for method in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())
    options = ProximalOptions(; maxiter = 5000, gaptol = 1e-8, gapevery = 2)
    ws = SolverWorkspace(zeros(3), f, g, method, options)
    gap = ws.buffers.gap
    for _ in 1:2
      reinit!(ws, zeros(3))
      result = solve!(ws)
      @test result.converged && result.gap <= options.gaptol
      @test ws.buffers.gap === gap
    end
    calls = Ref(0)
    callback = _ -> (calls[] += 1; true)
    wo = SolverWorkspace(zeros(3), f, g, method,
                         ProximalOptions(; callback, store_trace = true, print_every = 2, maxiter = 100))
    for _ in 1:2
      reinit!(wo, zeros(3))
      result = solve!(wo)
      @test result.iterations == 2
      @test length(result.trace) == 2
    end
    @test calls[] == 2
  end
end

@testset "resizing a shared iterate cannot invalidate scratch storage" begin
  for method in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent(), ADMMSolver(), CDSolver())
    f = QuadraticFunction(Matrix{Float64}(I, 3, 3), -ones(3))
    x = zeros(3)
    ws = SolverWorkspace(x, f, NormL1(0.1), method)
    resize!(x, 4)
    @test_throws DimensionMismatch solve!(ws)
    @test_throws DimensionMismatch reinit!(ws, zeros(3))
  end
end

@testset "coordinate-descent workspace" begin
  rng = Xoshiro(18)
  X, y = randn(rng, 50, 12), randn(rng, 50)
  f = (1 / 50) * LeastSquaresLoss(y, X)
  g, method = NormL1(0.02), CDSolver(; order = :cyclic, tol = 1e-12)
  for x in (zeros(12), SparseIterate(12))
    ws = SolverWorkspace(x, f, g, method)
    model, st = ws.buffers.model, ws.buffers.state
    for λ in (0.02, 0.01, 0.04)
      reinit!(ws, x isa SparseIterate ? SparseIterate(12) : zeros(12))
      result = solve!(ws, NormL1(λ))
      reference = solve!(zeros(12), f, NormL1(λ), method)
      @test result.minimizer === x
      @test x ≈ reference.minimizer atol = 1e-10
      @test result.minimum ≈ reference.minimum atol = 1e-12
      @test result.passes == reference.passes
      @test result.converged && ws.buffers.model === model && ws.buffers.state === st
    end
  end
  groups = [1:3, 4:6, 7:9, 10:12]
  x = AtomIterate(12, groups)
  gg = GroupNormL2(0.02, groups)
  ws = SolverWorkspace(x, f, gg, method)
  @test solve!(ws).converged
  reinit!(ws, AtomIterate(12, groups))
  @test Vector(solve!(ws).minimizer) ≈ Vector(solve!(AtomIterate(12, groups), f, gg, method).minimizer)
  @test_throws ArgumentError reinit!(ws, AtomIterate(12, [1:4, 5:8, 9:12]))
  @test_throws ArgumentError solve!(ws, GroupNormL2(0.02, [1:4, 5:8, 9:12]))
  # Models with an intercept can be supplied directly.
  xs = SparseIterate(12)
  m = cdmodel(f, xs; intercept = true)
  wi = SolverWorkspace(xs, m, g, method)
  @test solve!(wi).converged
  @test isfinite(PS.intercept(m, xs))
end

@testset "coordinate workspace resets gap-safe screening" begin
  y = [1., 0.8, 0.4, 0.2, 0.1, zeros(7)...]
  X = Matrix{Float64}(I, 12, 12)
  X[1, 2] = 0.2 # require several passes so screening precedes certification
  f = LeastSquaresLoss(y, X)
  method = CDSolver(; order = :cyclic, gaptol = 1e-10, gapsafe = true)
  ws = SolverWorkspace(zeros(12), f, NormL1(0.6), method)
  gap = nothing
  for level in (0.6, 0.05, 0.8)
    reinit!(ws, zeros(12))
    result = solve!(ws, NormL1(level))
    ref = solve!(zeros(12), f, NormL1(level), method)
    @test result.minimizer ≈ ref.minimizer atol = 1e-11
    @test result.converged && result.gap <= method.gaptol
    @test result.passes == ref.passes
    gap === nothing || @test ws.buffers.state.gap === gap
    gap = ws.buffers.state.gap
    if level == 0.6
      @test count(gap.keep) < length(y)
    end
  end
end

@testset "ADMM cold and dual warm starts" begin
  options = ProximalOptions(; maxiter = 3000)
  method = ADMMSolver(; adaptive = true, abstol = 1e-9, reltol = 1e-8)
  f, g = SqrNormL2(1., ones(8)), NormL1(0.1)
  ws = SolverWorkspace(zeros(8), f, g, method, options)
  for _ in 1:2
    reinit!(ws, zeros(8))
    result = solve!(ws)
    ref = solve!(zeros(8), f, g, method, options)
    @test result.minimizer === ws.x
    @test result.minimizer ≈ ref.minimizer
    @test result.iterations == ref.iterations
    @test result.ρ == ref.ρ
    @test result.prox_calls == ref.prox_calls
  end
  warm = solve!(ws; warm_start = true)
  @test warm.converged && warm.iterations <= 2
  reinit!(ws, zeros(8))
  @test all(iszero, ws.buffers.u)
  @test ws.buffers.ρ == method.ρ
  # Tuple blocks reuse the same buffers.
  xt = (zeros(3), zeros(2, 2))
  ft = SeparableSum(SqrNormL2(1., ones(3)), SqrNormL2(2., ones(2, 2)))
  gt = SeparableSum(NormL1(0.1), NormL1(0.2))
  wt = SolverWorkspace(xt, ft, gt, method, options)
  @test solve!(wt).converged
  reinit!(wt, (zeros(3), zeros(2, 2)))
  @test all(block -> all(iszero, block), wt.buffers.u)
  @test solve!(wt).converged
end

function workspace_bytes(ws, start)
  reinit!(ws, start); solve!(ws)
  reinit!(ws, start)
  @allocated solve!(ws)
end

@testset "repeated runs avoid dimension-sized solver allocations" begin
  p = 20_000
  f, g = SqrNormL2(), NormL1(0.1)
  options = ProximalOptions(; maxiter = 2)
  start = ones(p)
  for method in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent(), ADMMSolver())
    ws = SolverWorkspace(copy(start), f, g, method, options)
    @test workspace_bytes(ws, start) < 20_000
  end
  fq = QuadraticFunction(Matrix{Float64}(I, 12, 12), -ones(12))
  wc = SolverWorkspace(zeros(12), fq, g, CDSolver(; order = :cyclic, maxpasses = 100))
  @test workspace_bytes(wc, zeros(12)) < 5_000
  @test_throws ArgumentError SolverWorkspace(zeros(12), fq, g, ActiveAccProxGradDescent())
end

end
