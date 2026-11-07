# Symmetric penalties, representative cases: the asymmetric L1 reproduction, optimality checked
# independently from the supplied weights, hand-computed optima and linear constraints. Moved
# from test/symmetric_penalties.jl to run in the quick tier (#121); the other cases of
# `symmetric_penalties.jl` stay there.

module SymmetricPenaltyBasicsTests

using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

include("symmetric_penalty_helpers.jl")

# Asymmetric weights on an owner: on the two entries of a pair the penalty is
# (w12 + w21)|z|, which no single weight shows. Raw weights are rejected; the lower
# triangle by type and the symmetric part (W + W')/2 are different penalties that
# the caller chooses, with different solutions.
@testset "asymmetric weights on an owner (T17)" begin
  B = [0.0 3.0; 3.0 0.0]
  A = Matrix(1.0I, 2, 2)
  f = KronQuadratic(A, A, -B)              # ½‖Θ - B‖² up to a constant
  W = [0.0 1.0; 3.0 0.0]
  Wlower, Wbar = Symmetric(W, :L), (W .+ W') ./ 2
  glower, gbar, g = NormL1(0.1, Wlower), NormL1(0.1, Wbar), NormL1(0.1, W)
  saved = copy(W)
  # pair derivative 2(z - 3) + 0.1 (w12 + w21): the pair weights are 3 + 3 and 2 + 2
  dense(gp, z) = f([0.0 z; z 0.0]) + gp([0.0 z; z 0.0])
  grid = 0.0:1e-3:4.0
  @test grid[argmin([dense(glower, z) for z in grid])] ≈ 2.7 atol = 1e-9
  @test grid[argmin([dense(gbar, z) for z in grid])] ≈ 2.8 atol = 1e-9
  @test dense(g, 2.8) ≈ dense(gbar, 2.8)        # a dense matrix has no pairs of variables
  @test dense(g, 2.7) ≈ dense(gbar, 2.7)
  x = warm_start()
  rejects_symmetry(x) do
    PS._symmetric_penalty(g, x)
  end
  rejects_symmetry(x) do
    SolverWorkspace(x, f, g, cdsolver())
  end
  rejects_symmetry(x) do
    SolverWorkspace(x, f, g, ProximalGradientDescent(), gradient_options())
  end
  rejects_symmetry(x) do
    solve!(x, f, g, cdsolver())
  end
  rejects_symmetry(x) do
    solve!(x, f, g, AccProxGradDescent(), gradient_options())
  end
  ws = SolverWorkspace(x, f, glower, cdsolver())
  rejects_in_workspace(ws) do
    solve!(ws, g)
  end
  wg = SolverWorkspace(x, f, glower, ProximalGradientDescent(), gradient_options())
  rejects_in_workspace(wg) do
    solve!(wg, g)
  end
  @test isequal(W, saved)
  for (penalty, expected) in ((glower, 2.7), (gbar, 2.8))
    @test PS._symmetric_penalty(penalty, x) === penalty
    y = SymmetricSparseIterate(2)
    @test solve!(y, f, penalty, cdsolver()).converged
    @test Matrix(y) ≈ [0.0 expected; expected 0.0] atol = 1e-6
    z = SymmetricSparseIterate(2)
    wz = SolverWorkspace(z, f, penalty, ProximalGradientDescent(), gradient_options())
    @test solve!(wz).converged
    @test Matrix(z) ≈ [0.0 expected; expected 0.0] atol = 1e-6
    @test Matrix(z) ≈ Matrix(y) atol = 1e-6
  end
  @test abs(2.8 - 2.7) > 0.05
  @test isequal(W, saved)
end

@testset "independent optimality from the supplied weights" begin
  rng = Xoshiro(113)
  p = 5
  R = randn(rng, p, p)
  S = R'R / p + I
  C = randn(rng, p, p)
  C = (C + C') / 2
  W = 0.2 .+ rand(rng, p, p)
  Wbar = (W + W') / 2
  f = KronQuadratic(S, S, C)
  λ = 0.1
  for ridge in (0.0, 0.2)
    make(w) = iszero(ridge) ? NormL1(λ, w) : ElasticNet(λ, ridge, w)
    # the raw random weights are asymmetric: rejected, with nothing written
    x0 = SymmetricSparseIterate(p)
    x0[2, 1] = 0.5
    rejects_symmetry(x0) do
      solve!(x0, f, make(W), cdsolver())
    end
    g = make(Wbar)
    x = SymmetricSparseIterate(p)
    preserves_parameters((W, Wbar)) do
      @test solve!(x, f, g, cdsolver()).converged
      X = Matrix(x)
      G = S * X * S + C
      @test any(iszero, X) && any(!iszero, X)
      # pair derivatives are 2Grc + 2ρz; diagonal derivatives have multiplicity one
      for c in 1:p, r in c:p
        z = X[r, c]
        h = r == c ? G[r, c] + ridge * z : 2G[r, c] + 2ridge * z
        threshold = λ * (r == c ? Wbar[r, c] : Wbar[r, c] + Wbar[c, r])
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
  Wbar = (W .+ W') ./ 2
  C = [0.0 0.5; -0.5 0.0]
  L = [0.0 0.0; -1.0 0.0]
  Cbar, Lbar = (C .+ C') ./ 2, (L .+ L') ./ 2
  # z² - 0.5z + c|z| gives z = (0.5-c)/2 when 0 ≤ c < 0.5.
  # c is 0.4 for L1/capped/boxed L1 and 0.2 after precomposition by 0.5.
  # the antisymmetric tilt has the symmetric part zero, which leaves the
  # scalar-weight L1 penalty 0.2|z|; the symmetric part of the linear coefficient
  # adds -z, giving 0.75.
  cases = ((NormL1(0.1, Wbar), 0.05), (CappedL1(0.1, 1.0, Wbar), 0.05),
           (Constrained(NormL1(0.1, Wbar), IndBox(-1.0, 1.0)), 0.05),
           (Precompose(NormL1(0.1, Wbar), 0.5), 0.15),
           (Tilt(NormL1(0.1), Cbar), 0.15), (LinearFunction(Lbar), 0.75))
  for (g, z) in cases
    preserves_parameters((W, Wbar, C, L, Cbar, Lbar)) do
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
  # the same problems with the raw asymmetric weights, rejected before anything is written
  raw = (NormL1(0.1, W), CappedL1(0.1, 1.0, W), Constrained(NormL1(0.1, W), IndBox(-1.0, 1.0)),
         Precompose(NormL1(0.1, W), 0.5), Tilt(NormL1(0.1), C), LinearFunction(L))
  for g in raw
    preserves_parameters((W, Wbar, C, L)) do
      x = warm_start()
      rejects_symmetry(x) do
        solve!(x, f, g, cdsolver())
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

end
