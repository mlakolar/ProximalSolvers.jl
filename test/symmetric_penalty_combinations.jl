module SymmetricPenaltyCombinationTests

using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

include("symmetric_penalty_helpers.jl")

@testset "exact family and wrapper table" begin
  families, wrappers, parameters = exactness_table()
  W = [0.5 1.0; 3.0 0.75]
  Wbar = (W .+ W') ./ 2
  A = Matrix(1.0I, 2, 2)
  f = KronQuadratic(A, A, [-0.2 -0.4; -0.4 -0.1])
  points = ([0.15 0.25; 0.25 0.2], [0.6 0.1; 0.1 0.4])
  starts = (zeros(2, 2), [0.3 0.2; 0.2 0.1])
  for (family, make, box_supported) in families, (wrapper, wrap) in wrappers
    # CappedL1, LogPenalty and NormLq on a box are excluded: ProximalBase
    # allows convex functions and MCP/SCAD/NormL0, not these three families.
    wrapper == "Constrained" && !box_supported && continue
    @testset "$family / $wrapper" begin
      g, gbar = wrap(make(W)), wrap(make(Wbar))
      arrays = (W, Wbar, parameters...)
      for X in points
        # both triangles share Xrc, so wrc φ(Xrc) + wcr φ(Xrc) = 2w̄rc φ(Xrc)
        preserves_parameters(arrays) do
          @test isfinite(g(X)) && isfinite(gbar(X))
          @test g(X) ≈ gbar(X) rtol = 1e-12
        end
      end
      preserves_parameters(arrays) do
        @test PS._symmetric_penalty(gbar, SymmetricSparseIterate(2)) === gbar
      end
      for start in starts
        x, y = SymmetricSparseIterate(start), SymmetricSparseIterate(start)
        # solve the explicitly averaged problem first to verify support
        preserves_parameters(arrays) do
          @test solve!(y, f, gbar, cdsolver()).converged
        end
        preserves_parameters(arrays) do
          r = solve!(x, f, g, cdsolver())
          @test r.converged
          @test Matrix(x) ≈ Matrix(y) atol = 1e-12
          @test r.minimum ≈ f(Matrix(x)) + g(Matrix(x)) rtol = 1e-12 atol = 1e-14
        end
      end
    end
  end
end

@testset "strict parameters reject before mutation" begin
  f = probe()
  cases, arrays = strict_cases()
  for (name, bad, good, has_level) in cases, wrapped in (false, true)
    g = wrapped ? Scaled(bad, 1.25) : bad
    valid = wrapped ? Scaled(good, 1.25) : good
    @testset "$name / wrapped=$wrapped" begin
      preserves_parameters(arrays) do
        x = warm_start()
        rejects_symmetry(x) do
          PS._symmetric_penalty(g, x)
        end
        rejects_symmetry(x) do
          solve!(x, f, g, cdsolver())
        end
        rejects_symmetry(x) do
          solve!(x, f, g, cdsolver(); continuation = 3)
        end
        if has_level && !wrapped
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

@testset "exhaustive identity for absent parameters and other storage" begin
  families, wrappers, arrays = exactness_table()
  x = SymmetricSparseIterate(2)
  absent = (NormL1(0.1), NormL1Nonneg(0.1), ElasticNet(0.1, 0.2), CappedL1(0.1, 1.0),
            LogPenalty(0.1, 1.0), NormLq(0.1, 0.5), Berhu(0.1, 1.0), CheckLoss(0.4),
            EpsInsensitiveLoss(0.1), HingeLoss(), ZeroFunction(), SqrNormL2(0.2),
            IndBox(-1.0, 1.0), KLDivergence(1.0))
  preserves_parameters(arrays) do
    for g in absent, (name, wrap) in wrappers
      # the same nonconvex box exclusions as the exactness table
      name == "Constrained" && g isa Union{CappedL1, LogPenalty, NormLq} && continue
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
    wrapper == "Constrained" && !box_supported && continue
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

@testset "QUIC weight and storage combinations" begin
  S = [1.0 0.5 0.0; 0.5 1.0 0.0; 0.0 0.0 1.2]
  W = [0.0 1.0 1.0; 3.0 0.0 1.0; 1.0 1.0 0.0]
  Wbar = (W .+ W') ./ 2
  f = LogDetLoss(S)
  method = ProxNewton(; tol = 1e-11, inner = cdsolver())
  reference = zeros(3, 3)
  solve!(reference, f, NormL1(0.1, Wbar), method)
  @test !iszero(reference[1, 2])
  for weights in (W, Wbar, Int.(W), Int.(Wbar)), vector_weights in (false, true)
    w = vector_weights ? vec(copy(weights)) : copy(weights)
    for x in (zeros(3, 3), SymmetricSparseIterate(3))
      preserves_parameters((w, W, Wbar)) do
        r = solve!(x, f, NormL1(0.1, w), method)
        @test r.converged
        @test Matrix(x) ≈ reference atol = 1e-10
        @test Matrix(x) == Matrix(x)'
        @test duality_gap(f, NormL1(0.1, w), x).gap <= 1e-8
      end
    end
  end
end

@testset "gradient solver workspace combinations" begin
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

@testset "large weights in sparse QUIC storage" begin
  S = [1.0 0.5; 0.5 1.0]
  W = [0.0 1e308; 1e308 0.0]
  preserves_parameters((W,)) do
    x = SymmetricSparseIterate(2)
    r = solve!(x, LogDetLoss(S), NormL1(1e-309, W), ProxNewton(; tol = 1e-11, inner = cdsolver()))
    @test r.converged && !iszero(x[1, 2])
    @test isfinite(r.minimum) && r.minimum < 2
    @test Matrix(x) == Matrix(x)'
  end
end

@testset "integer vector weights in CD" begin
  S = [1.0 0.5 0.0; 0.5 1.0 0.0; 0.0 0.0 1.2]
  W = [0 1 1; 3 0 1; 1 1 0]
  Wbar = (W .+ W') ./ 2
  f = KronQuadratic(S, S, S)
  reference = SymmetricSparseIterate(3)
  solve!(reference, f, NormL1(0.1, Wbar), cdsolver())
  for weights in (W, Int.(Wbar))
    w = vec(copy(weights))
    preserves_parameters((w, W, Wbar)) do
      x = SymmetricSparseIterate(3)
      solve!(x, f, NormL1(0.1, w), cdsolver())
      @test Matrix(x) ≈ Matrix(reference) atol = 1e-12
    end
  end
end

end
