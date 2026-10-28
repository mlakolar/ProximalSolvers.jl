# Optional independent SOCP oracle for square-root lasso certificates.
# After instantiating the optional environment, run from the repository root:
# julia --project=test/oracles test/oracles/sqrt_hypatia.jl
# These are numerical conic references, not symbolic exact solutions.

module SqrtHypatiaOracle

using Test, LinearAlgebra, SparseArrays, Random, Printf
using ProximalBase, ProximalSolvers
using JuMP, Hypatia
import MathOptInterface as MOI

# Work in Float64 even when coordinate descent uses Float32. Nonfinite
# loadings fix coefficients at zero; zero loadings leave them unrestricted.
function hypatia_solution(X, y, loadings; weights = nothing, intercept = false,
                          conic_basis = nothing)
  X64, y64, λ = Matrix{Float64}(X), Float64.(y), Float64.(loadings)
  n, p = size(X64)
  sw = weights === nothing ? ones(n) : sqrt.(Float64.(weights))
  model = Model(() -> Hypatia.Optimizer(; verbose = false, tol_rel_opt = 1e-12,
                                        tol_abs_opt = 1e-12, tol_feas = 1e-12))
  @variable(model, z[1:p])
  # An optional invertible coefficient change improves the conic conditioning.
  # It changes neither the original residuals nor the penalty on β.
  if conic_basis === nothing
    β, design = z, X64
  else
    β = conic_basis * z
    design = X64 * conic_basis
  end
  b0 = intercept ? @variable(model, b0) : 0.0
  @variable(model, t)
  residual = [sw[i] * (y64[i] - b0 - sum(design[i, j] * z[j] for j in 1:p)) for i in 1:n]
  @constraint(model, [t; residual] in MOI.SecondOrderCone(n + 1))
  penalized = findall(v -> isfinite(v) && v > 0, λ)
  for j in findall(v -> !isfinite(v), λ)
    @constraint(model, β[j] == 0)
  end
  @variable(model, a[1:length(penalized)])
  for (k, j) in enumerate(penalized)
    @constraint(model, a[k] >= β[j])
    @constraint(model, a[k] >= -β[j])
  end
  @objective(model, Min, t + sum(λ[j] * a[k] for (k, j) in enumerate(penalized)))
  optimize!(model)
  status, primal, dual = termination_status(model), primal_status(model), dual_status(model)
  strict = (; tol = 1e-12, termination = status, primal, dual)
  fallback = nothing
  used_tol = 1e-12
  if status != MOI.OPTIMAL || primal != MOI.FEASIBLE_POINT || dual != MOI.FEASIBLE_POINT
    # Some exact-fit problems stall at the stricter tolerances. Keep the
    # same JuMP model, but use a fresh optimizer for the less stringent solve.
    set_optimizer(model, () -> Hypatia.Optimizer(; verbose = false, tol_rel_opt = 1e-9,
                                                  tol_abs_opt = 1e-9, tol_feas = 1e-9))
    optimize!(model)
    status, primal, dual = termination_status(model), primal_status(model), dual_status(model)
    fallback = (; tol = 1e-9, termination = status, primal, dual)
    used_tol = 1e-9
  end
  println("HYPATIA_STATUS attempt_1=", strict, " attempt_2=", fallback,
          " used_tol=", used_tol, " termination=", status, " primal=", primal, " dual=", dual)
  # Assertions and objective queries refer only to the attempt actually used.
  @test status == MOI.OPTIMAL
  @test primal == MOI.FEASIBLE_POINT
  @test dual == MOI.FEASIBLE_POINT
  # JuMP queries MOI.DualObjectiveValue, independently of the CD certificate:
  # https://jump.dev/JuMP.jl/stable/manual/solutions/#Objective-values
  P, D = objective_value(model), dual_objective_value(model)
  @test isfinite(P) && isfinite(D)
  @test P - D <= 1e-7 * max(1.0, abs(P))
  # Permit only numerical reversal of the primal/dual bracket.
  @test D - P <= 1e-9 * max(1.0, abs(P))
  (; P, D, status)
end

# Evaluate from the observations, without CD's residual or quadratic caches.
# In particular, do not evaluate Inf * 0 for fixed coefficients.
function data_objective(X, y, β, b0, loadings, weights)
  r = Float64.(y) .- Float64(b0) .- Matrix{Float64}(X) * Float64.(β)
  sw = weights === nothing ? ones(length(y)) : sqrt.(Float64.(weights))
  penalty = 0.0
  for j in eachindex(β)
    if isfinite(loadings[j])
      penalty += Float64(loadings[j]) * abs(Float64(β[j]))
    else
      @test iszero(β[j])
    end
  end
  norm(sw .* r) + penalty
end

function check_certificate(name, loss, result, P_CD, reference)
  P_conic, D_conic, gap = reference.P, reference.D, Float64(result.gap)
  @test isfinite(P_CD) && P_CD >= 0
  @test isfinite(gap) && gap >= 0
  bound = gap * max(P_CD, floatmin(Float64)) + (P_conic - D_conic) +
          1e-9 * max(1.0, P_CD)
  slack = bound - (P_CD - P_conic)
  @printf("ORACLE_CASE name=%s loss=%s termination=%s P_CD=%.12e P_conic=%.12e D_conic=%.12e gap=%.6e converged=%s bound_slack=%.6e\n",
          name, loss, string(reference.status), P_CD, P_conic, D_conic, gap,
          string(result.converged), slack)
  # Check every returned point, including traps and incomplete certificates.
  @test P_CD - P_conic <= bound
  if result.converged
    @test P_CD - D_conic <= max(gap, 1e-4) * P_CD + 1e-9
  end
end

function check_case(name, X, y, λ, start; weights = nothing, intercept = false,
                    penalty_weights = nothing, quadratic = true, conic_basis = nothing)
  T = eltype(y)
  n, p = size(X)
  loadings = penalty_weights === nothing ? fill(λ, p) : λ .* penalty_weights
  @testset "$name" begin
    reference = hypatia_solution(X, y, loadings; weights, intercept, conic_basis)
    # Cyclic order preserves the specified audit trap and makes every start
    # reproducible. No convergence assertion is imposed on incomplete runs.
    method = CDSolver(; order = :cyclic, tol = T === Float32 ? 1e-6 : 1e-10,
                      maxpasses = 10_000)
    x = SparseIterate(copy(start))
    f = SqrtLeastSquaresLoss(y, X; weights)
    g = NormL1(λ, penalty_weights)
    m = cdmodel(f, x; intercept)
    result = solve!(x, m, g, method)
    β = Vector(x)
    b0 = intercept ? ProximalSolvers.intercept(m, β) : zero(T)
    P_CD = data_objective(X, y, β, b0, loadings, weights)
    check_certificate(name, "data", result, P_CD, reference)

    if quadratic
      # Eliminate the intercept by weighted centering. Dividing BOTH the
      # loss and penalty by √n preserves the minimizers and relative gaps.
      w = weights === nothing ? ones(T, n) : weights
      xbar = intercept ? vec(sum(w .* X; dims = 1)) ./ sum(w) : zeros(T, p)
      ybar = intercept ? dot(w, y) / sum(w) : zero(T)
      R = sqrt.(w) .* (Matrix(X) .- transpose(xbar))
      v = sqrt.(w) .* (y .- ybar)
      q = SqrtQuadraticFunction(R' * R / T(n), -R' * v / T(n), dot(v, v) / T(n))
      xq = SparseIterate(copy(start))
      rq = solve!(xq, q, NormL1(λ / sqrt(T(n)), penalty_weights), method)
      βq = Vector(xq)
      bq = intercept ? ybar - dot(xbar, βq) : zero(T)
      # Report both losses in the original objective units. The returned gap
      # is relative, so it needs no rescaling and obeys the same conic bound.
      Pq = data_objective(X, y, βq, bq, loadings, weights)
      check_certificate(name, "statistics", rq, Pq, reference)
    end
  end
end

function ordinary_data(seed; sparse_design = false, correlated = false, T = Float64)
  rng = Xoshiro(seed)
  n, p = 60, 30
  X = randn(rng, n, p)
  sparse_design && (X .*= rand(rng, n, p) .< 0.25)
  correlated && (X[:, 2] .= 0.9 .* X[:, 1] .+ 0.2 .* randn(rng, n))
  β = zeros(p)
  β[1:5] .= [1.0, -0.8, 0.6, -0.4, 0.2]
  y = 1.5 .+ X * β .+ 0.5 .* randn(rng, n)
  X, y = T.(X), T.(y)
  sparse_design ? (sparse(X), y) : (X, y)
end

function oracle_cases()
  println("ORACLE_VERSIONS julia=", VERSION, " Hypatia=", Base.pkgversion(Hypatia),
          " JuMP=", Base.pkgversion(JuMP), " MOI=", Base.pkgversion(MOI),
          " ProximalBase=", Base.pkgversion(ProximalBase),
          " ProximalSolvers=", Base.pkgversion(ProximalSolvers))
  @testset "Square-root certificates versus an independent Hypatia SOCP" begin
    X = reshape([1.0, 2.0], 1, 2)
    check_case("exact_optimal", X, [1.0], 0.1, [0.0, 0.5])
    check_case("exact_trap", X, [1.0], 0.1, [1.0, 0.0])
    check_case("rank_deficient", ones(1, 2), [1.0], 0.1, [0.5, 0.5])
    X, start = [1.0 1.0; 0.0 0.01], [1.0, -1.0]
    check_case("audit_trap", X, X * start, 0.1, start)
    check_case("incomplete", [1.0 2.0; 0.0 1.0], [1.0, 0.0], 0.1, [1.0, 0.0])

    for seed in (11101, 11102, 11103)
      rng = Xoshiro(seed)
      X = randn(rng, 8, 20)
      β = zeros(20)
      β[1:3] .= [1.0, -0.8, 0.5]
      y = X * β
      λmax = norm(X' * y, Inf) / norm(y)
      for fraction in (0.05, 0.2)
        check_case("noiseless_seed$(seed)_fraction$(fraction)", X, y,
                   fraction * λmax, zeros(20))
      end
    end

    for seed in (11201, 11202, 11203)
      for kind in (:weighted, :sparse, :unpenalized, :fixed)
        X, y = ordinary_data(seed; sparse_design = kind === :sparse,
                             correlated = kind === :unpenalized)
        w = kind === :weighted ? 0.5 .+ rand(Xoshiro(seed + 100), length(y)) : nothing
        w === nothing || (w[1:4] .= 0.0)
        pw = ones(size(X, 2))
        kind === :unpenalized && (pw[1] = 0.0)
        kind === :fixed && (pw[1] = Inf)
        λ = 0.2 * norm(X' * y, Inf) / norm(y)
        check_case("ordinary_$(kind)_seed$(seed)", X, y, λ, zeros(size(X, 2));
                   weights = w, intercept = kind in (:weighted, :sparse), penalty_weights = pw)
      end
    end

    M = 2.0^26
    X = [M M-1; 1.0 1.0]
    # B has determinant one and X*B = I exactly in Float64. This avoids
    # transferring the deliberately ill-conditioned columns to the reference.
    B = [1.0 1-M; -1.0 M]
    @test X * B == Matrix{Float64}(I, 2, 2)
    # X'X loses the small direction in Float64, so sufficient statistics do
    # not represent an equivalent problem here; retain the data-loss check.
    check_case("ill_conditioned_unpenalized", X, [0.0, 1.0], 0.0, zeros(2);
               quadratic = false, conic_basis = B)

    X, y = ordinary_data(11301; T = Float32)
    λ = 0.2f0 * norm(X' * y, Inf) / norm(y)
    check_case("ordinary_float32", X, y, λ, zeros(Float32, size(X, 2)))
  end
  println("SQRT_HYPATIA_ORACLE_PASSED")
end

oracle_cases()

end
