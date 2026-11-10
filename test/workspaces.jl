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

# A SymmetricSparseIterate (owner) workspace: the state keeps owners for the iterates and dense
# matrices for the trial buffers, reinit! takes a new owner start into the same storage, and each
# solve gives what a fresh solve from the same start gives
@testset "owner gradient workspaces reset and reuse buffers $(summary(method))" for method in (
    ProximalGradientDescent(), ProximalGradientDescent(; normalized = true), AccProxGradDescent(),
    MonotoneAccProxGradDescent())
  rng = Xoshiro(7)
  p = 5
  R = randn(rng, p, p)
  S = R'R / p + I
  C = randn(rng, p, p)
  f = KronQuadratic(S, S, (C + C') / 2)
  options = ProximalOptions(; maxiter = 5000, ftol = 1e-13, xtol = 1e-13, gradtol = 1e-11)
  x = SymmetricSparseIterate(p)
  ws = SolverWorkspace(x, f, NormL1(0.1), method, options)
  buffers, state = ws.buffers, ws.buffers.state
  @test state.x === x && state.x_previous isa SymmetricSparseIterate{Float64}
  @test state.xhat isa Matrix{Float64} && state.delta_x isa Matrix{Float64}
  for level in (0.1, 0.03, 0.2)
    start = SymmetricSparseIterate(p)
    start[2, 1], start[3, 3] = 0.4, -0.1
    activate!(start, tril_index(p, 4, 2))             # an active zero
    reinit!(ws, start)
    @test Matrix(x) == Matrix(start) && nactive(x) == nactive(start)
    ref = solve!(copy(start), f, NormL1(level), method, options)
    result = solve!(ws, NormL1(level))
    @test result.minimizer === x
    @test ws.buffers === buffers && ws.buffers.state === state
    @test Matrix(x) ≈ Matrix(ref.minimizer) atol = 1e-10
    @test result.minimum ≈ ref.minimum atol = 1e-12
    @test (result.converged || result.f_increased) && (ref.converged || ref.f_increased)
    # the extrapolated points of the accelerated methods reuse the slots of the previous solve,
    # so the order of their active coordinates, and with it the rounding, can differ
    if method isa ProximalGradientDescent
      @test (result.iterations, result.f_calls, result.grad_calls, result.prox_calls, result.backtrack_steps) ==
            (ref.iterations, ref.f_calls, ref.grad_calls, ref.prox_calls, ref.backtrack_steps)
    end
  end
  @test_throws ArgumentError reinit!(ws, zeros(p, p))
  @test_throws DimensionMismatch reinit!(ws, SymmetricSparseIterate(p + 1))
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


# FT26 (#164): the dense start of a workspace clears the working set of the iterate
# built from it, and reloads the support in the slot order of 0.5.x's clear and scatter.
@testset "dense start of a coordinate workspace reloads the support (#164)" begin
  # the working sets of 0.5.x after the clear and the scatter
  xs = SparseIterate(6)
  xs[1] = 1.0; xs[4] = 2.0                               # a previous working set, [1, 4]
  @test collect(activecoordinates(xs)) == [1, 4]
  PS._load_dense!(xs, [0.0, 3.0, 0.0, -0.0, NaN, 1.0])
  @test collect(activecoordinates(xs)) == [2, 5, 6] && nactive(xs) == 3
  @test isequal(Vector(xs), [0.0, 3.0, 0.0, 0.0, NaN, 1.0])
  PS._load_dense!(xs, zeros(6))
  @test nactive(xs) == 0 && isempty(activecoordinates(xs))

  xa = AtomIterate(4, [[2, 4], [1, 3]])
  xa[1] = 5.0                                             # a previous working set, [2]
  @test collect(activecoordinates(xa)) == [2]
  PS._load_dense!(xa, [1.0, 0.0, 0.0, 2.0])
  @test collect(activecoordinates(xa)) == [2, 1]          # not the constructor's [1, 2]
  @test Vector(xa) == [1.0, 0.0, 0.0, 2.0]
  PS._load_dense!(xa, [0.0, 0.0, 0.0, 2.0])               # an inactive group stays out
  @test collect(activecoordinates(xa)) == [1] && Vector(xa) == [0.0, 0.0, 0.0, 2.0]

  # a workspace solved twice, the caller's vector changed in between
  rng = Xoshiro(164)
  A, b = randn(rng, 40, 6), randn(rng, 40)
  f = (1 / 40) * LeastSquaresLoss(b, A)
  method = CDSolver(; order = :cyclic, tol = 1e-12)
  for (g, ref) in ((NormL1(0.05), x -> SparseIterate(x)),
                   (GroupNormL2(0.05, [[2, 4, 6], [1, 3, 5]]), x -> AtomIterate(x, [[2, 4, 6], [1, 3, 5]])))
    x = zeros(6)
    ws = SolverWorkspace(x, f, g, method)
    @test solve!(ws).converged
    for start in ([0.0, 0.4, 0.0, 0.0, -0.3, 0.0], [0.5, 0.0, 0.0, 0.2, 0.0, 0.0], zeros(6))
      copyto!(x, start)                                   # the caller's vector is the start
      result = solve!(ws)
      rf = solve!(ref(copy(start)), f, g, method)
      @test result.converged && result.minimizer === x
      @test x ≈ Vector(rf.minimizer) atol = 1e-10
      @test result.minimum ≈ rf.minimum atol = 1e-10
    end
  end
end

# the groups of 1:12 in layouts that are equal as group arrays but separately allocated (range-backed,
# vector-backed, Int32 indices), and layouts that are not equal to them
_layouts() = (
  ranges = [1:3, 4:6, 7:9, 10:12],
  vectors = [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]],
  int32 = [Int32.(1:3), Int32.(4:6), Int32.(7:9), Int32.(10:12)],
  strided = [1:4:12, 2:4:12, 3:4:12, 4:4:12],
)
_other_layouts() = (
  group_order = [4:6, 1:3, 7:9, 10:12],
  within_group = [[2, 1, 3], 4:6, 7:9, 10:12],
  fewer_groups = [1:6, 7:9, 10:12],
  more_groups = [1:3, 4:6, 7:9, 10:11, 12:12],
)

accepts(f, args...) = (f(args...); true)

@testset "workspace partition: equal group arrays of separate allocation are accepted, others rejected" begin
  L, O = _layouts(), _other_layouts()
  for name in keys(L)
    x = AtomIterate(Float64, 12, L[name])
    # the same layout built again, and the equal layouts of the other backings
    for other in (name == :strided ? (:strided,) : (:ranges, :vectors, :int32))
      y = AtomIterate(Float64, 12, L[other])
      @test accepts(PS._workspace_partition, x, y)
      @test accepts(PS._workspace_partition, y, x)
      # asking again, and with the layout remembered by the first call
      @test accepts(PS._workspace_partition, x, y)
    end
    for bad in keys(O)
      y = AtomIterate(Float64, 12, O[bad])
      @test_throws ArgumentError PS._workspace_partition(x, y)
      @test_throws ArgumentError PS._workspace_partition(y, x)
    end
  end
  @test_throws ArgumentError PS._workspace_partition(AtomIterate(Float64, 12, L.ranges), AtomIterate(Float64, 12, L.strided))
  @test PS._workspace_partition(zeros(3), zeros(3)) === nothing
  # a tuple of blocks, each compared with its own layout
  xs = (AtomIterate(Float64, 12, L.ranges), AtomIterate(Float64, 12, L.strided))
  @test accepts(PS._workspace_partition, xs, (AtomIterate(Float64, 12, L.vectors), AtomIterate(Float64, 12, L.strided)))
  @test_throws ArgumentError PS._workspace_partition(xs, (AtomIterate(Float64, 12, L.vectors), AtomIterate(Float64, 12, L.ranges)))
  # a workspace accepts an equal layout of the same type, built apart, and rejects another
  X, y = randn(Xoshiro(3), 20, 12), randn(Xoshiro(4), 20)
  f = (1 / 20) * LeastSquaresLoss(y, X)
  for (groups, bads) in ((L.ranges, ([4:6, 1:3, 7:9, 10:12], [1:6, 7:9, 10:12], [1:3, 4:6, 7:9, 10:11, 12:12])),
                         (L.vectors, ([[2, 1, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]], [[4, 5, 6], [1, 2, 3], [7, 8, 9], [10, 11, 12]],
                                      [[1, 2, 3, 4, 5, 6], [7, 8, 9], [10, 11, 12]], [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11], [12]])),
                         (L.int32, ([Int32.(4:6), Int32.(1:3), Int32.(7:9), Int32.(10:12)],)))
    ws = SolverWorkspace(AtomIterate(Float64, 12, groups), f, GroupNormL2(0.05, groups), AccProxGradDescent(), ProximalOptions(; maxiter = 50))
    @test reinit!(ws, AtomIterate(Float64, 12, deepcopy(groups))) === ws
    for bad in bads
      @test_throws ArgumentError reinit!(ws, AtomIterate(Float64, 12, bad))
    end
  end
end

end
