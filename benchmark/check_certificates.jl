using Test

include("problems.jl")
include("certificates.jl")

function check_values(cert, primal, dual)
  @test cert.status == :ok
  @test cert.primal ≈ primal atol = 2e-12 rtol = 2e-12
  @test cert.dual ≈ dual atol = 2e-12 rtol = 2e-12
  @test cert.value ≈ max(primal - dual, 0) / max(abs(primal), floatmin(Float64)) atol = 2e-12
end

function check_weak_duality(cert)
  @test cert.status == :ok
  @test isfinite(cert.value) && cert.value >= 0
  @test cert.primal >= cert.dual - 8eps() * max(abs(cert.primal), abs(cert.dual))
end

function large_orthogonal_control()
  n = 2048
  X = [isodd(count_ones((i - 1) & mask)) ? -1.0 : 1.0 for i in 1:n, mask in (1, 2, 4, 8)]
  b = [1.3, -0.9, 0.7, -0.4]
  noise = [isodd(count_ones((i - 1) & 16)) ? -0.25 : 0.25 for i in 1:n]
  (; X, y = X * b + noise, b, noise, n, s = 1 / n)
end

function check_accumulated_roundoff(cert, scale, terms; wrong_dual = 2cert.dual)
  @test cert.status == :ok
  @test cert.value <= 1e-11
  @test relative_certificate(cert.primal, cert.dual + 1e-9 * abs(cert.primal);
                             scale, terms).status == :uncertifiable
  @test relative_certificate(cert.primal, wrong_dual; scale, terms).status == :uncertifiable
  rounding = 8eps() * terms * (abs(cert.primal) + abs(cert.dual) + scale)
  rounded = relative_certificate(cert.primal, cert.primal + rounding; scale, terms)
  @test rounded.status == :ok
  @test rounded.value == 0
end

@testset "Relative gap and path domain" begin
  check_values(relative_certificate(0.0, 0.0), 0.0, 0.0)
  @test relative_certificate(1.0, nextfloat(1.0)).value == 0
  @test relative_certificate(1.0, 1.001).status == :uncertifiable
  @test relative_certificate(Inf, 0.0).status == :uncertifiable
  @test relative_certificate(0.0, NaN).status == :uncertifiable
  @test relative_certificate(1.0, 1.0; scale = Inf).status == :uncertifiable
  @test relative_certificate(1.0, 1.0; terms = 0).status == :uncertifiable
  @test relative_certificate(0.0, -1.0).status == :ok
  good = [relative_certificate(2.0, 1.0), relative_certificate(3.0, 1.0)]
  @test path_certificate(good).value == 2 / 3
  @test path_certificate(Certificate[]).status == :uncertifiable
  @test path_certificate([good; uncertifiable("control")]).status == :uncertifiable
end

@testset "Accumulated roundoff on large orthogonal problems" begin
  a = large_orthogonal_control()
  X, y, b, n, s, λ = a.X, a.y, a.b, a.n, a.s, 0.05
  @test X' * X == n * Matrix{Float64}(I, 4, 4)
  @test X' * a.noise == zeros(4)
  least_squares = lasso_certificate(X, y, s, 0.0, ones(4), b)
  @test least_squares.status == :ok && least_squares.value <= 64eps()
  θ = s .* a.noise
  P, D = s * sum(abs2, y - X * b) / 2, dot(y, θ) - sum(abs2, θ) / (2s)
  scale = s * sum(abs2, y) / 2
  check_accumulated_roundoff(relative_certificate(P, D; scale, terms = n), scale, n;
    wrong_dual = dot(y, θ) - sum(abs2, θ) / (4s))

  groups, wg, α = [[1, 2], [3, 4]], [1.0, 1.2], 0.4
  β_group, β_sparse_group = zeros(4), zeros(4)
  for (k, g) in enumerate(groups)
    β_group[g] = (1 - λ * wg[k] / norm(b[g])) .* b[g]
    z = cert_soft.(b[g], λ * α)
    β_sparse_group[g] = (1 - λ * (1 - α) * wg[k] / norm(z)) .* z
  end
  w = [0.7, 1.4, 0.9, 1.2]
  β_lasso, β_weighted = cert_soft.(b, λ), cert_soft.(b, λ .* w)
  levels = [0.10, 0.08, 0.06, 0.04]
  β_slope = cert_soft.(b, levels)
  controls = (
    ("L1", lasso_certificate(X, y, s, λ, ones(4), β_lasso),
     λ * sum(abs, β_lasso), lasso_dual_point(X, y, s, λ, ones(4), β_lasso)),
    ("weighted L1", lasso_certificate(X, y, s, λ, w, β_weighted),
     λ * dot(w, abs.(β_weighted)), lasso_dual_point(X, y, s, λ, w, β_weighted)),
    ("group", group_certificate(X, y, s, λ, groups, wg, β_group),
     λ * sum(wg[k] * norm(β_group[g]) for (k, g) in enumerate(groups)),
     group_dual_point(X, y, s, λ, groups, wg, β_group)),
    ("sparse group", sparse_group_certificate(X, y, s, λ, α, groups, wg, β_sparse_group),
     λ * (α * sum(abs, β_sparse_group) + (1 - α) * sum(wg[k] * norm(β_sparse_group[g])
       for (k, g) in enumerate(groups))),
     sparse_group_dual_point(X, y, s, λ, α, groups, wg, β_sparse_group)),
    ("SLOPE", slope_certificate(X, y, s, levels, β_slope),
     dot(levels, sort!(abs.(β_slope); rev = true)), slope_dual_point(X, y, s, levels, β_slope)))
  for (name, cert, penalty, θ) in controls
    @testset "$name" begin
      scale = s * sum(abs2, y) / 2 + penalty
      # Doubling s in the dual quadratic denominator breaks the loss scaling.
      wrong_dual = dot(y, θ) - sum(abs2, θ) / (4s)
      check_accumulated_roundoff(cert, scale, n; wrong_dual)
    end
  end

  λsqrt = 1.0
  rnorm = norm(a.noise) / sqrt(1 - length(b) * λsqrt^2 / n)
  βsqrt = b - (λsqrt * rnorm / n) .* sign.(b)
  sqrt_cert = sqrt_lasso_certificate(X, y, λsqrt, βsqrt)
  check_accumulated_roundoff(sqrt_cert, norm(y) + λsqrt * sum(abs, βsqrt), n)
end

@testset "Least squares and weighted L1" begin
  X, y, β = Matrix{Float64}(I, 2, 2), [2.0, -1.0], [1.5, -0.5]
  check_values(lasso_certificate(X, y, 1.0, 0.5, ones(2), β), 1.25, 1.25)
  check_values(lasso_certificate(X, y, 1.0, 0.5, ones(2), zeros(2)), 2.5, 1.09375)
  # Scaling the loss changes the soft threshold from λ to λ/s.
  check_values(lasso_certificate(X, y, 0.5, 0.5, ones(2), [1.0, 0.0]), 1.0, 1.0)
  check_values(lasso_certificate(X, y, 1.0, 0.5, [2.0, 1.0], [1.0, -0.5]), 1.875, 1.875)
  free = lasso_certificate(X, y, 1.0, 0.5, [0.0, 1.0], [2.0, -0.5])
  @test free.measure == :kkt_residual && free.value == 0 && free.primal == 0.375
  @test lasso_certificate(X, y, 1.0, 0.5, [0.0, 1.0], zeros(2)).value == 2
  @test lasso_certificate(X, zeros(2), 1.0, 0.5, ones(2), zeros(2)).value == 0
  for bad in (NaN, Inf)
    @test lasso_certificate(X, y, 1.0, 0.5, ones(2), [bad, 0.0]).status == :uncertifiable
    @test lasso_certificate(X, y, bad, 0.5, ones(2), β).status == :uncertifiable
    @test lasso_certificate(X, y, 1.0, bad, ones(2), β).status == :uncertifiable
    @test lasso_certificate(X, y, 1.0, 0.5, [bad, 1.0], β).status == :uncertifiable
  end
end

@testset "Group and sparse group polar constraints" begin
  X, y, groups, w = Matrix{Float64}(I, 2, 2), [3.0, 4.0], [[1, 2]], [1.0]
  check_values(group_certificate(X, y, 1.0, 1.0, groups, w, 0.8y), 4.5, 4.5)
  check_values(group_certificate(X, y, 1.0, 1.0, groups, w, zeros(2)), 12.5, 4.5)
  β = (1 - 1 / sqrt(13)) .* [2.0, 3.0]
  optimum = 5.5 + sqrt(13)
  check_values(sparse_group_certificate(X, y, 1.0, 2.0, 0.5, groups, w, β), optimum, optimum)
  check_values(sparse_group_certificate(ones(1, 1), [2.0], 1.0, 1.0, 0.5, [[1]], [1.0],
                                        [0.0]), 2.0, 1.5)
  for certificate in ((v, yy) -> group_certificate(X, yy, 1.0, 1.0, groups, w, v),
                       (v, yy) -> sparse_group_certificate(X, yy, 1.0, 1.0, 0.5, groups, w, v))
    @test certificate(zeros(2), zeros(2)).value == 0
    for bad in (NaN, Inf)
      @test certificate([bad, 0.0], y).status == :uncertifiable
      @test certificate(zeros(2), [bad, 0.0]).status == :uncertifiable
    end
  end
  @test group_certificate(X, y, 1.0, 1.0, [[1, 2], [2]], [1.0, 1.0], β).status == :uncertifiable
end

@testset "SLOPE cumulative constraints" begin
  X, y, λ = Matrix{Float64}(I, 2, 2), [3.0, 1.0], [1.0, 0.5]
  check_values(slope_certificate(X, y, 1.0, λ, [2.0, 0.5]), 2.875, 2.875)
  check_values(slope_certificate(X, y, 1.0, λ, zeros(2)), 5.0, 25 / 9)
  check_values(slope_certificate(X, [3.0, 2.9], 1.0, λ, [2.2, 2.2]), 3.865, 3.865)
  @test slope_certificate(X, zeros(2), 1.0, λ, zeros(2)).value == 0
  for bad in (NaN, Inf)
    @test slope_certificate(X, y, 1.0, λ, [bad, 0.0]).status == :uncertifiable
    @test slope_certificate(X, y, 1.0, [bad, 0.5], zeros(2)).status == :uncertifiable
  end
end

@testset "Logistic weights, offset and entropy" begin
  X, y, β = ones(1, 1), [1.0], [log(3.0)]
  optimum = log(4.0) - 0.75log(3.0)
  check_values(logistic_certificate(X, y, 1.0, 0.25, [1.0], [0.0], β), optimum, optimum)
  check_values(logistic_certificate(X, y, 1.0, 0.25, [1.0], [0.0], [0.0]), log(2.0), optimum)
  shifted = 6optimum - 1.5 * 0.2
  check_values(logistic_certificate(X, y, 2.0, 1.5, [3.0], [0.2], β .- 0.2), shifted, shifted)
  @test logistic_certificate(X, y, 1.0, 0.25, [0.0], [0.0], [0.0]).value == 0
  for bad in (NaN, Inf)
    @test logistic_certificate(X, y, 1.0, 0.25, [1.0], [0.0], [bad]).status == :uncertifiable
    @test logistic_certificate(X, y, 1.0, 0.25, [bad], [0.0], β).status == :uncertifiable
    @test logistic_certificate(X, y, 1.0, 0.25, [1.0], [bad], β).status == :uncertifiable
  end
end

@testset "Square-root scale and exact fits" begin
  X, y = ones(1, 1), [2.0]
  check_values(sqrt_lasso_certificate(X, y, 2.0, [0.0]), 2.0, 2.0)
  check_values(sqrt_lasso_certificate(X, y, 2.0, [1.0]), 3.0, 2.0)
  check_values(sqrt_lasso_certificate(X, y, 0.5, [0.0]), 2.0, 1.0)
  check_values(sqrt_lasso_certificate(Matrix{Float64}(I, 2, 2), [3.0, 4.0], 2.0, zeros(2)), 5.0, 5.0)
  @test sqrt_lasso_certificate(X, y, 0.5, [2.0]).status == :uncertifiable
  @test sqrt_lasso_certificate(X, [0.0], 0.5, [0.0]).status == :uncertifiable
  @test sqrt_lasso_certificate(X, y, 0.5, [2.0 - 1e-8]; fit_floor = 1e-7).status == :uncertifiable
  for bad in (NaN, Inf)
    @test sqrt_lasso_certificate(X, y, 0.5, [bad]).status == :uncertifiable
  end
end

@testset "Quadratic residual and companion least-squares dual" begin
  A, b, c, λ = Matrix{Float64}(I, 2, 2), [2.0, -1.0], 2.5, 0.5
  at_solution = quadratic_certificate(A, b, c, λ, [1.5, -0.5])
  @test at_solution.value == 0 && at_solution.primal == 1.25 && isnan(at_solution.dual)
  nonoptimal = quadratic_certificate(A, b, c, λ, zeros(2))
  @test nonoptimal.value == 1.5 && nonoptimal.primal == 2.5
  @test quadratic_certificate(A, zeros(2), 0.0, λ, zeros(2)).value == 0
  problem = (; key = "analytic/quadratic", kind = :quadratic, A, b, c, λ,
               X = A, y = b, s = 1.0, w = ones(2))
  @test certify(problem, [1.5, -0.5]).dual == 1.25
  for bad in (NaN, Inf)
    @test quadratic_certificate(A, b, c, λ, [bad, 0.0]).status == :uncertifiable
  end
end

@testset "Graphical lasso log determinant" begin
  S, Λ = fill(2.0, 1, 1), fill(0.5, 1, 1)
  optimum = 1 + log(2.5)
  check_values(glasso_certificate(S, Λ, fill(0.4, 1, 1)), optimum, optimum)
  check_values(glasso_certificate(S, Λ, ones(1, 1)), 2.5, 1 + log(1.5))
  @test glasso_certificate(zeros(1, 1), zeros(1, 1), fill(exp(1.0), 1, 1)).status == :uncertifiable
end

@testset "Graphical lasso domains and zero objective" begin
  @test glasso_certificate([1.0 2.0; 2.0 1.0], zeros(2, 2), Matrix{Float64}(I, 2, 2)).status == :uncertifiable
  @test glasso_certificate(ones(1, 1), zeros(1, 1), -ones(1, 1)).status == :uncertifiable
  # S=1/e and Θ=e have P=D=0, with a positive definite dual.
  zero = glasso_certificate(fill(inv(exp(1.0)), 1, 1), zeros(1, 1), fill(exp(1.0), 1, 1))
  @test zero.status == :ok && abs(zero.primal) < 1e-15
  for bad in (NaN, Inf)
    @test glasso_certificate(ones(1, 1), zeros(1, 1), fill(bad, 1, 1)).status == :uncertifiable
  end
end

@testset "Generalized lasso strongly convex lower bound" begin
  X, y, D = ones(1, 1), [2.0], ones(1, 1)
  check_values(generalized_lasso_certificate(X, y, 1.0, 1.0, D, 0.25, 0.5, [0.625], [0.5]),
               1.609375, 1.609375)
  check_values(generalized_lasso_certificate(X, y, 1.0, 1.0, D, 0.25, 0.5, [0.0], [0.0]),
               2.0, 0.46875)
  @test generalized_lasso_certificate(X, [0.0], 1.0, 1.0, D, 0.25, 0.5, [0.0], [0.0]).value == 0
  @test generalized_lasso_bound(X, y, 1.0, 1.0, D, 0.25, 0.5, [0.0], [10.0]).dual == [0.5]
  for bad in (NaN, Inf)
    @test generalized_lasso_certificate(X, y, 1.0, 1.0, D, 0.25, 0.5, [bad], [0.0]).status == :uncertifiable
    @test generalized_lasso_certificate(X, y, 1.0, 1.0, D, 0.25, 0.5, [0.0], [bad]).status == :uncertifiable
  end
end

@testset "Nonconvex fixed points and deterministic hard thresholding" begin
  X = ones(1, 1)
  mcp = mcp_certificate(X, [2.0], 1.0, 0.5, 3.0, 1.0, [2.0])
  @test mcp.value == 0 && mcp.primal == 0.375 && isnan(mcp.dual)
  @test mcp_certificate(X, [2.0], 1.0, 0.5, 3.0, 1.0, [0.0]).value == 2.0
  scad = scad_certificate(X, [3.0], 1.0, 0.5, 4.0, 1.0, [3.0])
  @test scad.value == 0 && scad.primal == 0.625 && isnan(scad.dual)
  @test scad_certificate(X, [3.0], 1.0, 0.5, 4.0, 1.0, [0.0]).value == 3.0
  @test cert_mcp_prox(1.0, 0.5, 3.0, 1.0) ≈ 0.75
  @test cert_scad_prox(1.5, 0.5, 4.0, 1.0) == 1.25
  @test mcp_certificate(X, [2.0], 1.0, 0.5, 0.5, 1.0, [0.0]).status == :uncertifiable
  @test scad_certificate(X, [2.0], 1.0, 0.5, 3.0, 0.5, [0.0]).status == :uncertifiable
  for certificate in (mcp_certificate, scad_certificate)
    @test certificate(X, [0.0], 1.0, 0.5, 4.0, 1.0, [0.0]).value == 0
    for bad in (NaN, Inf)
      @test certificate(X, [2.0], 1.0, 0.5, 4.0, 1.0, [bad]).status == :uncertifiable
    end
  end
  A, y = Matrix{Float64}(I, 2, 2), [2.0, 1.0]
  optimum = iht_certificate(A, y, 1.0, 1, 1.0, [2.0, 0.0])
  @test optimum.value == 0 && optimum.primal == 0.5 && isnan(optimum.dual)
  @test iht_certificate(A, y, 1.0, 1, 1.0, zeros(2)).value == 2
  @test iht_certificate(A, y, 1.0, 1, 1.0, y).status == :uncertifiable
  @test iht_certificate(A, zeros(2), 1.0, 1, 1.0, zeros(2)).value == 0
  @test cert_hard_threshold([1.0, -1.0, 1.0], 1) == [1.0, 0.0, 0.0]
  for bad in (NaN, Inf)
    @test iht_certificate(A, y, 1.0, 1, 1.0, [bad, 0.0]).status == :uncertifiable
  end
end

@testset "Random points: feasibility and weak duality" begin
  rng = scenario_rng(1, "certificate-controls")
  for _ in 1:16
    X, y, β = randn(rng, 7, 4), randn(rng, 7), randn(rng, 4)
    s, λ, w = 0.3, 0.7, 0.2 .+ rand(rng, 4)
    check_weak_duality(lasso_certificate(X, y, s, λ, w, β))
    θ = lasso_dual_point(X, y, s, λ, w, β)
    @test all(abs.(X' * θ) .<= λ .* w .+ 1e-13)
    groups, wg = [[1, 2], [3, 4]], [0.7, 1.2]
    check_weak_duality(group_certificate(X, y, s, λ, groups, wg, β))
    θ = group_dual_point(X, y, s, λ, groups, wg, β)
    @test all(norm((X' * θ)[g]) <= λ * wg[k] + 1e-13 for (k, g) in enumerate(groups))
    α = 0.4
    check_weak_duality(sparse_group_certificate(X, y, s, λ, α, groups, wg, β))
    θ = sparse_group_dual_point(X, y, s, λ, α, groups, wg, β)
    @test all(norm(cert_soft.((X' * θ)[g], λ * α)) <= λ * (1 - α) * wg[k] + 1e-13
              for (k, g) in enumerate(groups))
    weights = [0.8, 0.6, 0.4, 0.2]
    check_weak_duality(slope_certificate(X, y, s, weights, β))
    θ = slope_dual_point(X, y, s, weights, β)
    @test all(cumsum(sort!(abs.(X' * θ); rev = true)) .<= cumsum(weights) .+ 1e-13)
    labels, obs, offset = Float64.(rand(rng, Bool, 7)), rand(rng, 7), randn(rng, 7)
    check_weak_duality(logistic_certificate(X, labels, s, λ, obs, offset, β))
    point = logistic_dual_point(X, labels, s, λ, obs, offset, β)
    @test all(u -> 0 <= u <= 1, point.u)
    @test cert_maxabs(X' * point.θ) <= λ + 1e-13
    @test point.θ ≈ s .* obs .* (labels - point.u) atol = 1e-14
    check_weak_duality(sqrt_lasso_certificate(X, y, λ, β))
    θ = sqrt_dual_point(X, y, λ, β)
    @test norm(θ) <= 1 + 1e-13 && cert_maxabs(X' * θ) <= λ + 1e-13
    a = (; key = "random/quadratic", kind = :quadratic, X, y, s, λ, w = ones(4),
           A = s * X' * X, b = s * X' * y, c = s * sum(abs2, y) / 2)
    q = certify(a, β)
    @test q.value ≈ cert_maxabs(β - cert_soft.(β - (a.A * β - a.b), λ))
    check_weak_duality(q)
    M, N = randn(rng, 4, 4), randn(rng, 4, 4)
    S, Θ, Λ = M' * M + I, N' * N + I, fill(0.05, 4, 4)
    check_weak_duality(glasso_certificate(S, Λ, Θ))
    W = glasso_dual_matrix(S, Λ, Θ)
    @test isposdef(Symmetric(W)) && maximum(abs.(W - S) - Λ) < 1e-13
    D, v, μ = randn(rng, 3, 4), randn(rng, 3), 0.8
    check_weak_duality(generalized_lasso_certificate(X, y, s, μ, D, 0.0, λ, β, v))
    bound = generalized_lasso_bound(X, y, s, μ, D, 0.0, λ, β, v)
    @test cert_maxabs(bound.dual) <= λ
    qdual = s * X' * y - D' * bound.dual
    exact = s * sum(abs2, y) / 2 - dot(qdual, (s * X' * X + μ * I) \ qdual) / 2
    @test bound.lower <= exact + 1e-12 && exact <= bound.primal + 1e-12
    L = s * opnorm(X)^2
    # Nonconvex residuals have no dual value and make no weak-duality claim.
    for certificate in (mcp_certificate, scad_certificate)
      residual = certificate(X, y, s, λ, 4.0, L, β)
      @test residual.status == :ok && residual.value >= 0 && isnan(residual.dual)
    end
    sparse_β = cert_hard_threshold(β, 2)
    residual = iht_certificate(X, y, s, 2, L, sparse_β)
    @test residual.status == :ok && residual.value >= 0 && isnan(residual.dual)
    @test count(!iszero, cert_hard_threshold(β, 2)) <= 2
  end
end

@testset "Problem generation and hashes" begin
  @test rand(scenario_rng(1, "design/A/12x8"), UInt64) == rand(Xoshiro(0xff8c9ca4a22a3198), UInt64)
  for design in (:A, :B, :C, :D, :E)
    a = lasso_design(design, 1; n = 12, p = 8, s = 3)
    b = lasso_design(design, 1; n = 12, p = 8, s = 3)
    @test a.X == b.X && a.y == b.y && count(!iszero, a.β) == 3
    @test vec(sum(abs2, a.X; dims = 1)) ≈ fill(12.0, 8)
    @test data_hash(a) == data_hash(b) && length(data_hash(a)) == 64
    @test data_hash(a) != data_hash(lasso_design(design, 2; n = 12, p = 8, s = 3))
  end
  @test data_hash((; x = [1.0, 2.0], a = 3)) == data_hash((; a = 3, x = [1.0, 2.0]))
  @test data_hash((; X = sparse([1.0 0.0; 0.0 2.0]))) ==
    data_hash((; X = sparse([1.0 0.0; 0.0 2.0])))
  a = release_problem(:cd)
  rng = Xoshiro(90210)
  X = randn(rng, 120, 40)
  @test a.X == X && a.y == X[:, 1:4] * [1.0, -1.0, 0.5, -0.5] + randn(rng, 120)
  a = batched_problem(:cd)
  rng = Xoshiro(90210)
  X = randn(rng, 120, 40)
  @test a.X == X && a.y == X[:, 1:4] * [1.0, -0.5, 0.7, 0.2] + 0.1randn(rng, 120)
  @test batched_problem(:newton).y == Float64.(rand(Xoshiro(90212), 120) .<
    1 ./ (1 .+ exp.(-X[:, 1:3] * [1.0, -0.5, 0.7])))
  @test lambda_grid(2.0, 0.1, 3) ≈ [2.0, sqrt(0.4), 0.2]
  @test lambda_grid(2.0, 0.1, 1) == [2.0]
  @test lambda_max(Matrix{Float64}(I, 2, 2), [2.0, -1.0]; s = 1.0) == 2
end

if Base.find_package("ProximalSolvers") !== nothing
  import ProximalSolvers
  @testset "Accumulated logistic roundoff at a tight package solution" begin
    PS, PB = ProximalSolvers, ProximalSolvers.ProximalBase
    a = large_orthogonal_control()
    rng = scenario_rng(1, "large-certificate-logistic")
    η = a.X * [0.4, -0.3, 0.2, -0.1]
    y = Float64.(rand(rng, a.n) .< cert_sigmoid.(η))
    weights, offset, λ = 0.75 .+ 0.5rand(rng, a.n), zeros(a.n), 0.02
    loss = a.s * PB.LogisticLoss(y, a.X; weights, offset)
    method = PS.ProxNewton(tol = 1e-14,
      inner = PS.CDSolver(tol = 1e-14, order = :cyclic, maxpasses = 5000))
    result = PS.solve!(PB.SparseIterate(4), loss, PB.NormL1(λ), method)
    β = Array(result.minimizer)
    cert = logistic_certificate(a.X, y, a.s, λ, weights, offset, β)
    η = a.X * β + offset
    point = logistic_dual_point(a.X, y, a.s, λ, weights, offset, β)
    scale = a.s * sum(weights .* (abs.(cert_log1pexp.(η)) + abs.(y .* η) +
      abs.(cert_entropy.(point.u)))) + λ * sum(abs, β)
    @test result.converged
    check_accumulated_roundoff(cert, scale, a.n)
  end
  @testset "Secondary package agreement at analytic solutions" begin
    PS, PB = ProximalSolvers, ProximalSolvers.ProximalBase
    X = Matrix{Float64}(I, 2, 2)
    controls = (
      (PB.LeastSquaresLoss([2.0, -1.0], X), PB.NormL1(0.5), [1.5, -0.5],
       lasso_certificate(X, [2.0, -1.0], 1.0, 0.5, ones(2), [1.5, -0.5])),
      (PB.LeastSquaresLoss([3.0, 4.0], X), PB.GroupNormL2(1.0, [[1, 2]], [1.0]), [2.4, 3.2],
       group_certificate(X, [3.0, 4.0], 1.0, 1.0, [[1, 2]], [1.0], [2.4, 3.2])),
      (PB.LeastSquaresLoss([2.0], ones(1, 1)), PB.SparseGroupNormL2(0.5, 0.5, [[1]], [1.0]), [1.0],
       sparse_group_certificate(ones(1, 1), [2.0], 1.0, 1.0, 0.5, [[1]], [1.0], [1.0])),
      (2.0 * PB.LogisticLoss([1.0], ones(1, 1); weights = [3.0], offset = [0.2]),
       PB.NormL1(1.5), [log(3.0) - 0.2],
       logistic_certificate(ones(1, 1), [1.0], 2.0, 1.5, [3.0], [0.2], [log(3.0) - 0.2])),
      (PB.LogDetLoss(fill(2.0, 1, 1)), PB.NormL1(0.5), fill(0.4, 1, 1),
       glasso_certificate(fill(2.0, 1, 1), fill(0.5, 1, 1), fill(0.4, 1, 1))))
    for (f, g, β, certificate) in controls
      own = PS.duality_gap(f, g, β)
      @test certificate.primal ≈ own.primal atol = 2e-12
      @test certificate.dual ≈ own.dual atol = 2e-12
      @test abs(own.gap) < 2e-12 && certificate.value < 2e-12
    end
    f, g, grid = PB.LeastSquaresLoss([2.0, -1.0], X), PB.NormL1(1.0), [0.5, 0.25]
    path = PS.solve_path(f, g, grid, PS.CDSolver(order = :cyclic, tol = 1e-13, gaptol = 1e-10))
    @test path.λ == grid && length(path.solutions) == length(grid)
    for i in eachindex(grid)
      certificate = lasso_certificate(X, [2.0, -1.0], 1.0, grid[i], ones(2), Array(path.solutions[i]))
      @test certificate.value ≈ path.gap[i] atol = 2e-12
    end
    for (penalty, value, prox) in ((PB.MCP(0.5, 3.0), cert_mcp_value, cert_mcp_prox),
                                  (PB.SCAD(0.5, 3.7), cert_scad_value, cert_scad_prox))
      β, γ = [-2.0, -0.8, 0.0, 0.4, 1.3, 3.0], 0.5
      @test PB.prox(penalty, β, γ) ≈ prox.(β, 0.5, penalty.a, γ)
      @test penalty(β) ≈ sum(value.(β, 0.5, penalty.a))
    end
    @test PB.prox(PB.IndBallL0(1), [2.0, 1.0], 1.0) == [2.0, 0.0]
    @test PB.prox(PB.SLOPE([1.0, 0.5]), [3.0, 2.9], 1.0) ≈ [2.2, 2.2]
    @test PS.SqrtLeastSquaresLoss([3.0, 4.0], X)(zeros(2)) == 5.0
    include(joinpath(@__DIR__, "..", "examples", "support", "primal_dual_lessons.jl"))
    X, y, D, x, v = ones(1, 1), [2.0], ones(1, 1), [0.2], [0.1]
    a = (; f = PB.Sum(PB.LeastSquaresLoss(y, X), PB.SqrNormL2(1.0)), μ = 1.0,
           D, λ1 = 0.25, λ2 = 0.5)
    reference = PrimalDualLessons.certificate(a, x, v)
    independent = generalized_lasso_certificate(X, y, 1.0, 1.0, D, 0.25, 0.5, x, v)
    @test independent.primal ≈ reference.primal && independent.dual ≈ reference.lower
  end
else
  @info "Package agreement checks skipped: ProximalSolvers is not in this environment"
end

@testset "Normalized weighted square-root lasso" begin
  X, y, λ, w = reshape([1.0, 1.0], 2, 1), [2.0, 0.0], 0.2, [1.5]
  level = λ * w[1]
  β = [1 - level / sqrt(1 - level^2)]
  cert = weighted_sqrt_lasso_certificate(X, y, λ, w, β)
  @test cert.status == :ok && cert.value < 1e-14
  @test cert.primal ≈ norm(y - X * β) / sqrt(2) + λ * dot(w, abs.(β))
  θ = weighted_sqrt_dual_point(X, y, λ, w, β)
  @test norm(θ) <= 1 / sqrt(2) + 1e-14
  @test abs(only(X' * θ)) <= λ * w[1] + 1e-14
  @test weighted_sqrt_lasso_certificate(X, y, λ, w, [0.0]).value > 0.05
  @test weighted_sqrt_lasso_certificate(X, y, λ / sqrt(2), w, β).value > 1e-4
  @test weighted_sqrt_lasso_certificate(ones(1, 1), [1.0], λ, [1.0], [1.0]).status == :uncertifiable
  for bad in ([0.0], [-1.0], [NaN], [Inf])
    @test weighted_sqrt_lasso_certificate(X, y, λ, bad, β).status == :uncertifiable
  end
end

@testset "Feasible-lasso residual-loadings fixed point" begin
  X, y, λ = reshape([1.0, 1.0], 2, 1), [2.0, 0.0], 0.2
  β = [1 - λ / sqrt(1 - λ^2)]
  @test feasible_lasso_loadings(X, y) ≈ [sqrt(2)]
  @test feasible_lasso_loadings(X, y - X * β) ≈ [inv(sqrt(1 - λ^2))]
  cert = feasible_lasso_self_consistency(X, y, λ, β)
  @test cert.certificate.measure == :self_consistency && cert.certificate.status == :ok
  @test cert.certificate.value < 1e-14 && cert.loadings_change < 1e-14 && cert.refit_converged
  nonoptimal = feasible_lasso_self_consistency(X, y, λ, [0.0])
  @test nonoptimal.certificate.value > 0.1 && nonoptimal.loadings_change > 0.1
  bounded = feasible_lasso_self_consistency(X, y, λ, [0.0]; maxpasses = 1)
  gap = lasso_certificate(X, y, 1 / size(X, 1), λ, feasible_lasso_loadings(X, y), [0.0])
  @test bounded.certificate.status == :ok && bounded.certificate.measure == :self_consistency
  @test bounded.certificate.value == gap.value == nonoptimal.certificate.value
  @test bounded.certificate.primal == gap.primal && bounded.certificate.dual == gap.dual
  @test isnan(bounded.loadings_change) && !bounded.refit_converged
  @test occursin("secondary loadings change unavailable", bounded.certificate.detail)
  @test feasible_lasso_self_consistency(X, y, λ, [NaN]).certificate.status == :uncertifiable
  @test feasible_lasso_self_consistency(X, y, λ, β; maxpasses = 0).certificate.status == :uncertifiable
  @test feasible_lasso_self_consistency(zeros(2, 1), y, λ, [0.0]).certificate.status == :uncertifiable
end

@testset "Feasible-lasso interpolation guard" begin
  X = Matrix{Float64}(I, 2, 2)
  y, λ = [2.0, -1.0], 0.2
  detail = "interpolating fit: residual at rounding level; residual-loading gap not numerically meaningful"
  for β in (copy(y), (1 - 0.5e-8) .* y)
    result = feasible_lasso_self_consistency(X, y, λ, β)
    @test result.certificate.status == :uncertifiable
    @test result.certificate.measure == :self_consistency && result.certificate.detail == detail
    @test isnan(result.certificate.value) && isnan(result.loadings_change) && !result.refit_converged
  end
  outside = feasible_lasso_self_consistency(X, y, λ, (1 - 2e-8) .* y)
  @test outside.certificate.status == :ok
  X = reshape([1.0, 1.0], 2, 1)
  y, β = [2.0, 0.0], [1 - λ / sqrt(1 - λ^2)]
  result = feasible_lasso_self_consistency(X, y, λ, β)
  gap = lasso_certificate(X, y, 0.5, λ, feasible_lasso_loadings(X, y - X * β), β)
  @test result.certificate.status == :ok && result.certificate.value == gap.value
  @test result.certificate.value < 1e-14 && result.loadings_change < 1e-14 && result.refit_converged
end

@testset "Bitwise coefficient certificate reuse" begin
  cache, calls = coefficient_certificate_cache(), Ref(0)
  compute() = (calls[] += 1; (; certificate = :control, loadings_change = NaN,
    refit_converged = false))
  β = [0.0, 1.0]
  first = coefficient_certificate!(compute, cache, (; β))
  again = coefficient_certificate!(compute, cache, (; β = copy(β), info = :different))
  @test calls[] == 1 && again === first
  @test isnan(again.loadings_change) && !again.refit_converged
  β[1] = -0.0
  coefficient_certificate!(compute, cache, (; β))
  @test calls[] == 2
  coefficient_certificate!(compute, cache, (; β = [0.0, 1.0]))
  @test calls[] == 2
  for bits in (0x7ff8000000000001, 0x7ff8000000000002)
    coefficient_certificate!(compute, cache, (; β = [reinterpret(Float64, bits)]))
  end
  @test calls[] == 4
  path = (; βs = [[0.0, 1.0], [2.0, 3.0]], λs = [0.2, 0.1])
  coefficient_certificate!(compute, cache, path)
  coefficient_certificate!(compute, cache, deepcopy(path))
  @test calls[] == 5
  path.βs[2][1] += 1.0
  coefficient_certificate!(compute, cache, path)
  @test calls[] == 6
  path.λs[2] /= 2
  coefficient_certificate!(compute, cache, path)
  @test calls[] == 7
end
