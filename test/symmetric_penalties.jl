module SymmetricPenaltyTests

using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

include("symmetric_penalty_helpers.jl")

@testset "asymmetric L1 reproduction" begin
  S = [1.0 0.5; 0.5 1.0]
  f = KronQuadratic(S, S, S)
  W = [0.0 1.0; 3.0 0.0]
  Wbar = (W .+ W') ./ 2
  x, y = SymmetricSparseIterate(2), SymmetricSparseIterate(2)
  preserves_parameters((W, Wbar)) do
    @test solve!(x, f, NormL1(0.1, W), cdsolver()).converged
    @test solve!(y, f, NormL1(0.1, Wbar), cdsolver()).converged
    @test Matrix(x) ≈ Matrix(y) atol = 1e-12
  end
end

# keep the assertion code shared while each public solve specializes on its penalty
@noinline function check_exactness(f, g, gbar, arrays, points, starts)
  @nospecialize g gbar
  model = cdmodel(f, SymmetricSparseIterate(2))
  before = map(copy, arrays)
  for X in points
    # both triangles share Xrc, so wrc φ(Xrc) + wcr φ(Xrc) = 2w̄rc φ(Xrc)
    @test isfinite(g(X)) && isfinite(gbar(X))
    @test g(X) ≈ gbar(X) rtol = 1e-12
    check_parameters(arrays, before)
  end
  @test PS._symmetric_penalty(gbar, SymmetricSparseIterate(2)) === gbar
  check_parameters(arrays, before)
  for start in starts
    x, y = SymmetricSparseIterate(start), SymmetricSparseIterate(start)
    # solve the explicitly averaged problem first to verify support
    @test solve!(y, model, gbar, cdsolver()).converged
    check_parameters(arrays, before)
    r = solve!(x, model, g, cdsolver())
    @test r.converged
    @test Matrix(x) ≈ Matrix(y) atol = 1e-12
    @test r.minimum ≈ f(Matrix(x)) + g(Matrix(x)) rtol = 1e-12 atol = 1e-14
    check_parameters(arrays, before)
  end
end

function check_parameters(arrays, before)
  for (a, b) in zip(arrays, before)
    @test isequal(a, b)
  end
end

@testset "representative families and wrappers" begin
  families, wrappers, parameters = exactness_table()
  W = [0.5 1.0; 3.0 0.75]
  Wbar = (W .+ W') ./ 2
  A = Matrix(1.0I, 2, 2)
  f = KronQuadratic(A, A, [-0.2 -0.4; -0.4 -0.1])
  points = ([0.15 0.25; 0.25 0.2], [0.6 0.1; 0.1 0.4])
  starts = (zeros(2, 2), [0.3 0.2; 0.2 0.1])
  for (family, make, _) in families, (wrapper, wrap) in wrappers
    # each family is checked directly; NormL1 exercises each wrapper once
    wrapper != "none" && family != "NormL1" && continue
    @testset "$family / $wrapper" begin
      check_exactness(f, wrap(make(W)), wrap(make(Wbar)), (W, Wbar, parameters...), points, starts)
    end
  end
end

@testset "independent optimality from the supplied weights" begin
  rng = Xoshiro(113)
  p = 5
  R = randn(rng, p, p)
  S = R'R / p + I
  C = randn(rng, p, p)
  C = (C + C') / 2
  W = 0.2 .+ rand(rng, p, p)
  f = KronQuadratic(S, S, C)
  λ = 0.1
  for ridge in (0.0, 0.2)
    g = iszero(ridge) ? NormL1(λ, W) : ElasticNet(λ, ridge, W)
    x = SymmetricSparseIterate(p)
    preserves_parameters((W,)) do
      @test solve!(x, f, g, cdsolver()).converged
      X = Matrix(x)
      G = S * X * S + C
      @test any(iszero, X) && any(!iszero, X)
      # pair derivatives are 2Grc + 2ρz; diagonal derivatives have multiplicity one
      for c in 1:p, r in c:p
        z = X[r, c]
        h = r == c ? G[r, c] + ridge * z : 2G[r, c] + 2ridge * z
        threshold = λ * (r == c ? W[r, c] : W[r, c] + W[c, r])
        if iszero(z)
          @test abs(h) <= threshold + 1e-8
        else
          @test abs(h + threshold * sign(z)) <= 1e-8
        end
      end
      @test kkt_residual(f, g, x; relative = false) <= 1e-8
    end
  end
end

@testset "hand computed optima" begin
  f = probe()
  W = [0.0 1.0; 3.0 0.0]
  C = [0.0 0.5; -0.5 0.0]
  L = [0.0 0.0; -1.0 0.0]
  # z² - 0.5z + c|z| gives z = (0.5-c)/2 when 0 ≤ c < 0.5.
  # c is 0.4 for L1/capped/boxed L1 and 0.2 after precomposition by 0.5.
  # the antisymmetric tilt cancels; the linear coefficient adds -z, giving 0.75.
  cases = ((NormL1(0.1, W), 0.05), (CappedL1(0.1, 1.0, W), 0.05),
           (Constrained(NormL1(0.1, W), IndBox(-1.0, 1.0)), 0.05),
           (Precompose(NormL1(0.1, W), 0.5), 0.15),
           (Tilt(NormL1(0.1), C), 0.15), (LinearFunction(L), 0.75))
  for (g, z) in cases
    preserves_parameters((W, C, L)) do
      x = SymmetricSparseIterate(2)
      result = solve!(x, f, g, cdsolver())
      @test result.converged
      @test Matrix(x) ≈ [0.0 z; z 0.0] atol = 1e-12
      @test result.minimum ≈ f(Matrix(x)) + g(Matrix(x)) atol = 1e-14
      if g === cases[1][1]
        @test result.minimum ≈ -0.0025 atol = 1e-14
      end
    end
  end
end

@testset "strict parameters reject before mutation" begin
  model = cdmodel(probe(), SymmetricSparseIterate(2))
  cases, arrays = strict_cases()
  for (name, g, _, _) in cases
    @testset "$name" begin
      preserves_parameters(arrays) do
        x = warm_start()
        rejects_symmetry(x) do
          PS._symmetric_penalty(g, x)
        end
        rejects_symmetry(x) do
          solve!(x, model, g, cdsolver())
        end
      end
    end
  end
end

@testset "strict upper bounds reject at every entry point" begin
  f = probe()
  cases, arrays = strict_cases()
  for (name, g, valid, has_level) in cases
    # upper bounds exercise every applicable entry point, including paths
    name in ("IndBox u", "Constrained u") || continue
    @testset "$name" begin
      preserves_parameters(arrays) do
        x = warm_start()
        rejects_symmetry(x) do
          solve!(x, f, g, cdsolver(); continuation = 3)
        end
        if has_level
          rejects_symmetry(x) do
            solve_path(f, g, [0.2, 0.1], cdsolver(); x, gaptol = 0)
          end
          rejects_symmetry(x) do
            lambda_max(f, g, x)
          end
        end
        rejects_symmetry(x) do
          kkt_residual(f, g, x)
        end
        rejects_symmetry(x) do
          SolverWorkspace(x, f, g, cdsolver())
        end
        ws = SolverWorkspace(x, f, valid, cdsolver())
        rejects_symmetry(x) do
          solve!(ws, g)
        end
        for method in gradient_methods()
          rejects_symmetry(x) do
            solve!(x, f, g, method, gradient_options())
          end
          rejects_symmetry(x) do
            SolverWorkspace(x, f, g, method, gradient_options())
          end
          wg = SolverWorkspace(x, f, valid, method, gradient_options())
          rejects_symmetry(x) do
            solve!(wg, g)
          end
        end
      end
    end
  end
end

@testset "linear constraints require symmetric parameters" begin
  a = [1.0 0.0; 0.0 1.0]
  asymmetric_a = [1.0 1.0; 0.0 1.0]
  W = [0.0 1.0; 3.0 0.0]
  g = Constrained(NormL1(0.1), IndHyperplane(a, 0.0))
  scalar = Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0))
  bad_normal = Constrained(NormL1(0.1), IndHyperplane(asymmetric_a, 0.0))
  bad_weights = Constrained(NormL1(0.1, W), IndHyperplane(a, 0.0))
  preserves_parameters((a, asymmetric_a, W)) do
    @test PS._symmetric_penalty(g, SymmetricSparseIterate(2)) === g
    @test PS._symmetric_penalty(scalar, SymmetricSparseIterate(2)) === scalar
    x = warm_start()
    rejects_symmetry(x) do
      PS._symmetric_penalty(bad_normal, x)
    end
    # weights inside a linear constraint must already be symmetric
    rejects_symmetry(x) do
      PS._symmetric_penalty(bad_weights, x)
    end
    # trace zero leaves the off-diagonal objective z² - 0.5z + 0.2|z|
    result = solve!(SymmetricSparseIterate(2), probe(), g, AccProxGradDescent(), gradient_options())
    @test result.converged
    @test Matrix(result.minimizer) ≈ [0.0 0.15; 0.15 0.0] atol = 1e-6
    rejects_symmetry(x) do
      solve!(x, probe(), bad_normal, AccProxGradDescent(), gradient_options())
    end
  end
end

@testset "identity for absent parameters and other storage" begin
  families, wrappers, arrays = exactness_table()
  x = SymmetricSparseIterate(2)
  absent = (NormL1(0.1), NormL1Nonneg(0.1), ElasticNet(0.1, 0.2), CappedL1(0.1, 1.0),
            LogPenalty(0.1, 1.0), NormLq(0.1, 0.5), Berhu(0.1, 1.0), CheckLoss(0.4),
            EpsInsensitiveLoss(0.1), HingeLoss(), ZeroFunction(), SqrNormL2(0.2),
            IndBox(-1.0, 1.0), KLDivergence(1.0))
  preserves_parameters(arrays) do
    for g in absent, (name, wrap) in wrappers
      # direct families and wrapped NormL1 cover the identity rule
      name != "none" && !(g isa NormL1) && continue
      penalty = wrap(g)
      @test PS._symmetric_penalty(penalty, x) === penalty
    end
  end
  cases, strict_arrays = strict_cases()
  preserves_parameters(strict_arrays) do
    for (_, _, g, _) in cases
      @test PS._symmetric_penalty(g, x) === g
      wrapped = Scaled(g, 1.25)
      @test PS._symmetric_penalty(wrapped, x) === wrapped
    end
  end
  W = [0.0 1.0; 3.0 0.0]
  other_storage = (SparseIterate(2, 2), AtomIterate(4, [1:2, 3:4]), zeros(2, 2), zeros(4))
  for (family, make, box_supported) in families, (wrapper, wrap) in wrappers
    family == "NormL1" || continue
    wrapper != "none" && continue
    g = wrap(make(W))
    preserves_parameters((W, arrays...)) do
      for y in other_storage
        @test PS._symmetric_penalty(g, y) === g
      end
    end
  end
  g = SeparableSum(NormL1(0.1, [0.0 2.0; 2.0 0.0]), NormL1(0.2))
  @test PS._symmetric_penalty(g, (SymmetricSparseIterate(2), zeros(3))) === g
end

@testset "paths continuation and supplied objective" begin
  f = probe()
  W = [0.0 1.0; 3.0 0.0]
  Wbar = (W .+ W') ./ 2
  g, gbar = NormL1(0.1, W), NormL1(0.1, Wbar)
  preserves_parameters((W, Wbar)) do
    @test lambda_max(f, g, SymmetricSparseIterate(2)) ≈ 0.125
  end
  for screening in (false, true)
    preserves_parameters((W, Wbar)) do
      x, y = warm_start(), warm_start()
      ra = solve!(x, f, g, cdsolver(); continuation = 3, continuation_tol = 1e-13, screening, gaptol = 0)
      rb = solve!(y, f, gbar, cdsolver(); continuation = 3, continuation_tol = 1e-13, screening, gaptol = 0)
      @test ra.converged && rb.converged
      @test Matrix(x) ≈ Matrix(y) atol = 1e-10
      levels = [0.15, 0.1, 0.05]
      pa = solve_path(f, g, levels, cdsolver(); x = warm_start(), screening, gaptol = 0)
      pb = solve_path(f, gbar, levels, cdsolver(); x = warm_start(), screening, gaptol = 0)
      @test pa.λ == pb.λ == levels
      @test all(pa.converged) && all(pb.converged)
      for k in eachindex(levels)
        X = Matrix(pa.solutions[k])
        @test X ≈ Matrix(pb.solutions[k]) atol = 1e-10
        @test pa.values[k] ≈ f(X) + NormL1(levels[k], W)(X) rtol = 1e-12
      end
    end
  end
end

@testset "weight shapes and integer arrays" begin
  S = [1.0 0.5 0.0; 0.5 1.0 0.0; 0.0 0.0 1.2]
  W = [0.0 1.0 1.0; 3.0 0.0 1.0; 1.0 1.0 0.0]
  Wbar = (W .+ W') ./ 2
  fk, fg = KronQuadratic(S, S, S), LogDetLoss(S)
  reference = SymmetricSparseIterate(3)
  solve!(reference, fk, NormL1(0.1, Wbar), cdsolver())
  qref = zeros(3, 3)
  method = ProxNewton(; tol = 1e-11, inner = cdsolver())
  solve!(qref, fg, NormL1(0.1, Wbar), method)
  @test !iszero(qref[1, 2])
  # CD's matrix API uses SymmetricSparseIterate; QUIC also takes dense matrices.
  for weights in (W, Wbar, Int.(W), Int.(Wbar)), vector_weights in (false, true)
    # integer matrices cover integer acceptance; integer vectors stay in the full grid
    eltype(weights) <: Integer && vector_weights && continue
    w = vector_weights ? vec(copy(weights)) : copy(weights)
    preserves_parameters((w,)) do
      prepared = PS._symmetric_penalty(NormL1(0.1, w), SymmetricSparseIterate(3))
      @test size(prepared.w) == size(w)
      @test reshape(prepared.w, 3, 3) == Wbar
      if !issymmetric(reshape(w, 3, 3))
        @test eltype(prepared.w) <: AbstractFloat
      end
    end
    preserves_parameters((w, W, Wbar)) do
      x = SymmetricSparseIterate(3)
      solve!(x, fk, NormL1(0.1, w), cdsolver())
      @test Matrix(x) ≈ Matrix(reference) atol = 1e-12
    end
    # integer weights are checked by CD here and by QUIC in the full grid
    eltype(w) <: Integer && continue
    # pair matrix weights with dense storage and vector weights with sparse storage
    for x in (vector_weights ? SymmetricSparseIterate(3) : zeros(3, 3),)
      preserves_parameters((w, W, Wbar)) do
        r = solve!(x, fg, NormL1(0.1, w), method)
        @test r.converged
        @test Matrix(x) ≈ qref atol = 1e-10
        @test Matrix(x) == Matrix(x)'
        @test duality_gap(fg, NormL1(0.1, w), x).gap <= 1e-8
      end
    end
  end
end

@testset "infinite zero and large finite weights" begin
  f = probe()
  for W in ([0.0 Inf; 1.0 0.0], [0.0 0.0; 4.0 0.0])
    preserves_parameters((W,)) do
      x = SymmetricSparseIterate(2)
      r = solve!(x, f, NormL1(0.1, W), cdsolver())
      @test r.converged && isfinite(r.minimum)
      @test isfinite(f(Matrix(x)) + NormL1(0.1, W)(Matrix(x)))
      z = isinf(W[1, 2]) ? 0.0 : 0.05
      @test Matrix(x) ≈ [0.0 z; z 0.0] atol = 1e-12
      if isfinite(W[1, 2])
        y = SymmetricSparseIterate(2)
        solve!(y, f, NormL1(0.1, [0.0 2.0; 2.0 0.0]), cdsolver())
        @test Matrix(x) ≈ Matrix(y) atol = 1e-12
      end
    end
  end
  M = floatmax(Float64)
  W = [M M; M / 2 M]
  preserves_parameters((W,)) do
    normalized = PS._symmetric_penalty(NormL1(0.1, W), SymmetricSparseIterate(2))
    @test isfinite(normalized.w[1, 2])
    @test normalized.w[1, 2] == normalized.w[2, 1] == 0.75M
    @test normalized.w[1, 1] == normalized.w[2, 2] == M
  end
  S = [1.0 0.5; 0.5 1.0]
  W = [0.0 1e308; 1e308 0.0]
  preserves_parameters((W,)) do
    for x in (zeros(2, 2),)
      r = solve!(x, LogDetLoss(S), NormL1(1e-309, W), ProxNewton(; tol = 1e-11, inner = cdsolver()))
      @test r.converged && !iszero(x[1, 2])
      @test isfinite(r.minimum) && r.minimum < 2
      @test Matrix(x) == Matrix(x)'
    end
  end
end

@testset "workspace supplied penalties and reweighting" begin
  f = probe()
  for W in ([0.0 1.0; 3.0 0.0], [0 1; 3 0])
    Wbar = oftype(W, [0 2; 2 0])
    Wother = oftype(W, [0 2; 4 0])
    g = NormL1(0.1, W)
    x = SymmetricSparseIterate(2)
    ws = SolverWorkspace(x, f, g, cdsolver())
    @test ws.g === g
    for (k, penalty) in enumerate((g, NormL1(0.1, Wbar), NormL1(0.1, Wother)))
      preserves_parameters((W, Wbar, Wother)) do
        fresh = SymmetricSparseIterate(Matrix(x))
        reference = solve!(fresh, f, penalty, cdsolver())
        result = k == 1 ? solve!(ws) : solve!(ws, penalty)
        @test result.converged && reference.converged
        @test Matrix(x) ≈ Matrix(fresh) atol = 1e-12
        @test result.minimum ≈ reference.minimum atol = 1e-14
        @test ws.g === g
      end
    end
  end
  W = [0.0 1.0; 3.0 0.0]
  Wnext = [0.0 0.0; 2.0 0.0]
  g, next = NormL1(0.1, W), NormL1(0.1, Wnext)
  seen = Ref(0)
  update = function (supplied, x, model)
    seen[] += 1
    @test supplied === (seen[] == 1 ? g : next)
    (next, seen[] == 1 ? 1.0 : 0.0)
  end
  preserves_parameters((W, Wnext)) do
    result = reweight!(SymmetricSparseIterate(2), f, g, update, cdsolver(); maxiter = 2)
    @test seen[] == 2 && result.iterations == 2
    @test result.penalty === next && result.next === next
    @test result.cd_converged
    @test Matrix(result.minimizer) ≈ [0.0 0.15; 0.15 0.0] atol = 1e-12
  end
  Wbar = (W .+ W') ./ 2
  preserves_parameters((W, Wbar)) do
    a = solve!(SymmetricSparseIterate(2), f, CappedL1(0.1, 1.0, W), LLA(cdsolver()))
    b = solve!(SymmetricSparseIterate(2), f, CappedL1(0.1, 1.0, Wbar), LLA(cdsolver()))
    @test a.cd_converged && b.cd_converged
    @test Matrix(a.minimizer) ≈ Matrix(b.minimizer) atol = 1e-12
    @test issymmetric(reshape(a.penalty.w, 2, 2))
    @test issymmetric(reshape(a.next.w, 2, 2))
    @test reshape(a.penalty.w, 2, 2) == Wbar
  end
end

@testset "gradient solvers and block workspaces" begin
  f = probe()
  W, Wnext = [0.0 1.0; 3.0 0.0], [0.0 0.0; 2.0 0.0]
  for method in gradient_methods(), blocks in (false, true)
    x = SymmetricSparseIterate(2)
    initial = blocks ? (x,) : x
    loss = blocks ? SeparableSum(f) : f
    penalty = blocks ? SeparableSum(NormL1(0.1, W)) : NormL1(0.1, W)
    replacement = blocks ? SeparableSum(NormL1(0.1, Wnext)) : NormL1(0.1, Wnext)
    preserves_parameters((W, Wnext)) do
      result = solve!(initial, loss, penalty, method, gradient_options())
      @test result.converged
      @test Matrix(x) ≈ [0.0 0.05; 0.05 0.0] atol = 1e-6
    end
    # one positive reuse case complements the full strict workspace checks
    method isa ProximalGradientDescent && !blocks || continue
    preserves_parameters((W, Wnext)) do
      ws = SolverWorkspace(initial, loss, penalty, method, gradient_options())
      @test ws.g === penalty
      @test solve!(ws).converged
      @test Matrix(x) ≈ [0.0 0.05; 0.05 0.0] atol = 1e-6
      @test solve!(ws, replacement).converged
      @test Matrix(x) ≈ [0.0 0.15; 0.15 0.0] atol = 1e-6
      @test ws.g === penalty
    end
  end
end

end
