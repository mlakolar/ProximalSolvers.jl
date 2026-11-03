# Symmetric penalties, representative cases: the asymmetric L1 reproduction, optimality checked
# independently from the supplied weights, hand-computed optima and linear constraints. Moved
# from test/symmetric_penalties.jl to run in the quick tier (#121); the other cases of
# `symmetric_penalties.jl` stay there.

module SymmetricPenaltyBasicsTests

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
