# Optional, independent conic oracle for the graphical lasso. This is not part
# of the normal package tests and adds no main-package runtime dependencies.
# Run package setup AND this script in a cluster (Slurm) allocation. From the
# repository root, with PROXIMALBASE_SNAPSHOT pointing to the pinned dependency:
#
# julia --project=test/oracles -e 'using Pkg; Pkg.develop(path=pwd());
#   Pkg.develop(path=ENV["PROXIMALBASE_SNAPSHOT"]); Pkg.instantiate()'
# julia --project=test/oracles test/oracles/quic_hypatia.jl
#
# The cone and its packing are documented at:
# https://jump.dev/MathOptInterface.jl/stable/reference/standard_form/#MathOptInterface.LogDetConeTriangle
# https://jump.dev/MathOptInterface.jl/stable/reference/standard_form/#MathOptInterface.Scaled
# Hypatia supports the scaled cone directly (src/MathOptInterface/cones.jl):
# https://github.com/jump-dev/Hypatia.jl/blob/master/src/MathOptInterface/cones.jl
# Solver construction and tolerance keywords follow Hypatia's official README
# and src/Solvers/Solvers.jl. These are numerical conic solutions, not exact
# symbolic solutions or a proof of the solver's correctness.

module QUICHypatiaOracle

using Test, LinearAlgebra, Random
using ProximalBase, ProximalSolvers
using JuMP, Hypatia
import MathOptInterface as MOI

function hypatia_solution(S::Matrix{Float64}, Λ::Matrix{Float64}, w::Float64)
  p = size(S, 1)
  model = Model(() -> Hypatia.Optimizer(; verbose = false, tol_rel_opt = 1e-12,
                                        tol_abs_opt = 1e-12, tol_feas = 1e-12))
  @variable(model, Θ[1:p, 1:p], Symmetric)
  @variable(model, t)
  # At u = 1 this is t <= logdet(Θ). The scaled MOI cone uses the upper
  # triangle column by column and multiplies only off-diagonal entries by √2.
  # Supplying the scaling explicitly avoids depending on a solver bridge.
  packed = [i == j ? 1.0 * Θ[i, j] : sqrt(2.0) * Θ[i, j] for j in 1:p for i in 1:j]
  @constraint(model, [t; 1.0; packed] in MOI.Scaled(MOI.LogDetConeTriangle(p)))

  # Only penalized entries need an absolute-value epigraph. Each off-diagonal
  # entry contributes twice to the full-matrix penalty Σᵢⱼ Λᵢⱼ |Θᵢⱼ|.
  penalized = [(i, j) for j in 1:p for i in 1:j if Λ[i, j] > 0]
  costs = [(i == j ? 1.0 : 2.0) * Λ[i, j] for (i, j) in penalized]
  @variable(model, a[1:length(penalized)])
  for (k, (i, j)) in enumerate(penalized)
    @constraint(model, a[k] >= Θ[i, j])
    @constraint(model, a[k] >= -Θ[i, j])
  end
  penalty = sum(costs[k] * a[k] for k in eachindex(costs))
  @objective(model, Min, w * (sum(S[i, j] * Θ[i, j] for i in 1:p, j in 1:p) - t) + penalty)
  optimize!(model)
  println("HYPATIA_STATUS p=", p, " termination=", termination_status(model),
          " primal=", primal_status(model))
  @test termination_status(model) == MOI.OPTIMAL
  @test primal_status(model) == MOI.FEASIBLE_POINT
  Matrix(JuMP.value.(Θ)), objective_value(model)
end

# A continuous KKT residual, unlike a sign test at tiny interior-point entries.
# It is zero iff 0 belongs to w(S - Θ⁻¹) + Λ ∂|Θ|, for the symmetric Λ here.
function prox_residual(Θ, S, Λ, w)
  G = w .* (S .- inv(Symmetric(Θ)))
  res = 0.0
  for j in axes(Θ, 2), i in axes(Θ, 1)
    v = Θ[i, j] - G[i, j]
    proxv = sign(v) * max(abs(v) - Λ[i, j], 0.0)
    res = max(res, abs(Θ[i, j] - proxv))
  end
  res
end

function oracle_cases()
  println("ORACLE_VERSIONS julia=", VERSION, " Hypatia=", Base.pkgversion(Hypatia),
          " JuMP=", Base.pkgversion(JuMP), " MOI=", Base.pkgversion(MOI),
          " ProximalBase=", Base.pkgversion(ProximalBase),
          " ProximalSolvers=", Base.pkgversion(ProximalSolvers))
  @testset "QUIC versus an independent Hypatia log-det cone" begin
    for p in (3, 6), penalize_diagonal in (false, true)
      rng = Xoshiro(2200 + p)
      Z = randn(rng, 5p, p)
      S = Matrix(Symmetric(Z' * Z / (5p) + 0.5I))
      w = p == 3 ? 1.0 : 2.5
      Λ = fill(0.1, p, p)
      penalize_diagonal || (Λ[diagind(Λ)] .= 0.0)
      f, g = LogDetLoss(S, w), NormL1(1.0, Λ)

      Θh, conic_value = hypatia_solution(S, Λ, w)
      @test isposdef(Symmetric(Θh))
      hvalue = f(Θh) + g(Θh)
      scale = max(1.0, abs(hvalue))
      @test abs(hvalue - conic_value) <= 3e-7 * scale
      hres = prox_residual(Θh, S, Λ, w)
      @test hres <= 1e-5

      Θq = SymmetricSparseIterate(p)
      result = solve!(Θq, f, g, ProxNewton(; tol = 1e-11,
                        inner = CDSolver(; order = :cyclic, tol = 1e-10)))
      Θqd = Matrix(Θq)
      qvalue = f(Θqd) + g(Θqd)
      qres = prox_residual(Θqd, S, Λ, w)
      @test result.converged && result.gap <= 1e-11
      @test isposdef(Symmetric(Θqd))
      @test qres <= 1e-6
      @test abs(qvalue - hvalue) <= 3e-7 * scale
      @test norm(Θqd - Θh) <= 2e-4 * max(1.0, norm(Θh))
      @test result.minimum ≈ qvalue rtol = 1e-12
      println("ORACLE_CASE p=", p, " penalized_diagonal=", penalize_diagonal,
              " weight=", w, " quic_value=", qvalue, " hypatia_value=", hvalue,
              " objective_difference=", qvalue - hvalue, " quic_kkt=", qres,
              " hypatia_kkt=", hres, " relative_gap=", result.gap)
    end
  end
  println("QUIC_HYPATIA_ORACLE_PASSED")
end

oracle_cases()

end
