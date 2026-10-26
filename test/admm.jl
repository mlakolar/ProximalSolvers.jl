module ADMMTest

using Test
using Random
using LinearAlgebra
using ProximalBase
using ProximalSolvers

Random.seed!(1)

# 1000 times the Euclidean norm, with a method for the difference of two arrays
struct Big1000 end
(::Big1000)(x) = 1e3 * LinearAlgebra.norm(x)
(::Big1000)(x, y) = 1e3 * norm_diff(x, y)

@testset "ADMM" begin

  opt = ProximalOptions(; maxiter = 5000)
  p = 10
  Z = randn(50, p)
  S = Symmetric(Z'Z / 50)

  @testset "Gaussian likelihood + no penalty" begin
    X = Matrix(1.0I, p, p)
    res = solve!(X, LogDetLoss(S), ZeroFunction(), ADMMSolver(), opt)
    @test res.converged
    @test X ≈ inv(S) rtol = 1e-3
  end

  @testset "graphical lasso" begin
    λ = 0.1
    for solver in (ADMMSolver(), ADMMSolver(; ρ = 5., α = 1.6))
      X = Matrix(1.0I, p, p)
      res = solve!(X, LogDetLoss(S), NormL1(λ), solver, opt)
      @test res.converged
      @test isposdef(Symmetric(X))

      # KKT conditions for tr(SX) - logdet(X) + λ‖X‖₁:
      # (S - X⁻¹)ᵢⱼ = -λ sign(Xᵢⱼ) where Xᵢⱼ ≠ 0, |(S - X⁻¹)ᵢⱼ| ≤ λ otherwise
      G = S - inv(X)
      nz = abs.(X) .> 1e-4
      @test G[nz] ≈ -λ * sign.(X[nz]) atol = 1e-2
      @test all(abs.(G[.!nz]) .<= λ + 1e-2)
    end
  end

  @testset "Float32" begin
    X32 = Matrix{Float32}(I, p, p)
    res = solve!(X32, LogDetLoss(Symmetric(Float32.(S))), NormL1(0.1f0), ADMMSolver(), opt)
    X64 = Matrix(1.0I, p, p)
    solve!(X64, LogDetLoss(S), NormL1(0.1), ADMMSolver(), opt)
    @test res.converged
    @test eltype(X32) == Float32 && res.minimum isa Float32
    @test X32 ≈ X64 atol = 1e-3
  end

  @testset "adaptive ρ, over-relaxation and warm starts" begin
    λ = 0.1
    tight = (; abstol = 1e-9, reltol = 1e-8)
    X0 = Matrix(1.0I, p, p)
    ref = solve!(copy(X0), LogDetLoss(S), NormL1(λ), ADMMSolver(; tight...), opt)
    for solver in (ADMMSolver(; adaptive = true, tight...), ADMMSolver(; ρ = 100.0, α = 1.6, adaptive = true, tight...))
      X = copy(X0)
      res = solve!(X, LogDetLoss(S), NormL1(λ), solver, opt)
      @test res.converged
      @test X ≈ ref.minimizer atol = 1e-6
      @test res.ρ > 0 && size(res.u) == size(X)
    end
    # from a large ρ, residual balancing lowers it and converges in fewer iterations
    fixed = solve!(copy(X0), LogDetLoss(S), NormL1(λ), ADMMSolver(; ρ = 1e3, tight...), opt)
    adaptive = solve!(copy(X0), LogDetLoss(S), NormL1(λ), ADMMSolver(; ρ = 1e3, adaptive = true, tight...), opt)
    @test adaptive.ρ < 1e3
    @test adaptive.iterations < fixed.iterations
    # a warm start from the iterate, the scaled dual variable and ρ of a solution
    X = copy(ref.minimizer)
    warm = solve!(X, LogDetLoss(S), NormL1(λ), ADMMSolver(; ρ = ref.ρ, tight...), opt; u = copy(ref.u))
    @test warm.converged && warm.iterations <= 2
    @test_throws DimensionMismatch solve!(copy(X0), LogDetLoss(S), NormL1(λ), ADMMSolver(), opt; u = zeros(p + 1, p))
    @test_throws ArgumentError solve!(copy(X0), SqrNormL2(), LogisticLoss(ones(p), ones(p, p)), ADMMSolver(), opt)
  end

  @testset "the norm of the residuals" begin
    λ = 0.1
    X0 = Matrix(1.0I, p, p)
    for adaptive in (false, true)
      ref = solve!(copy(X0), LogDetLoss(S), NormL1(λ), ADMMSolver(; adaptive), opt)
      # the Euclidean norm, given as a function, takes the same iterations
      res = solve!(copy(X0), LogDetLoss(S), NormL1(λ), ADMMSolver(; adaptive, norm = LinearAlgebra.norm), opt)
      @test res.iterations == ref.iterations
      @test res.minimizer ≈ ref.minimizer rtol = 1e-12
      @test res.r_norm ≈ ref.r_norm rtol = 1e-10
      # with a negligible relative tolerance, a norm 1000 times larger makes the
      # absolute tolerance 1000 times smaller: more iterations
      abs_only = (; abstol = 1e-5, reltol = 1e-14)
      ref = solve!(copy(X0), LogDetLoss(S), NormL1(λ), ADMMSolver(; adaptive, abs_only...), opt)
      big = solve!(copy(X0), LogDetLoss(S), NormL1(λ), ADMMSolver(; adaptive, abs_only..., norm = x -> 1e3 * LinearAlgebra.norm(x)), opt)
      @test big.converged
      @test big.iterations > ref.iterations
      @test big.r_norm <= big.eps_pri && big.s_norm <= big.eps_dual
      # a norm with a method for the difference of two arrays measures the
      # residuals with it, and takes the same iterations
      diff = solve!(copy(X0), LogDetLoss(S), NormL1(λ), ADMMSolver(; adaptive, abs_only..., norm = Big1000()), opt)
      @test diff.iterations == big.iterations
      @test diff.minimizer ≈ big.minimizer rtol = 1e-12
    end
  end

  @testset "argument checks" begin
    @test_throws ArgumentError ADMMSolver(; ρ = 0.)
    @test_throws ArgumentError ADMMSolver(; α = 2.)
  end

end

end
