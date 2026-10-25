# The nonconvex penalties of ProximalBase in coordinate descent: the capped ℓ1,
# log and ℓq penalties entry by entry, and group MCP and SCAD on an AtomIterate,
# with paths and screening.

module NonconvexPenaltiesTests

using Test, LinearAlgebra, Random
using ProximalBase
using ProximalSolvers
const PS = ProximalSolvers

function ncvdata(; n = 80, p = 60, seed = 3)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  β = zeros(p); β[1:4] .= [2, -1.5, 1, -1]; β[11:13] .= [1, 1, -1]
  X, X * β + 0.3 * randn(rng, n)
end

# how far b is from a fixed point of coordinate descent on ‖y - Xb‖²/(2n) + g(b):
# the largest change of an entry under its own coordinate step
function coordinate_residual(X, y, g, b)
  n = size(X, 1)
  grad = X' * (X * b - y) / n
  maximum(eachindex(b)) do k
    a = sum(abs2, view(X, :, k)) / n
    abs(prox_entry(g, b[k] - grad[k] / a, k, 1 / a) - b[k])
  end
end

@testset "capped ℓ1, log and ℓq penalties" begin
  X, y = ncvdata()
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  λmax1 = lambda_max(f, NormL1(1.0), SparseIterate(p))
  w = rand(Xoshiro(1), p) .+ 0.5
  # coordinate descent takes any separable penalty: each solve ends at a fixed
  # point of the exact coordinate steps
  for g in (CappedL1(0.1λmax1, 0.8), CappedL1(0.1λmax1, 0.8, w), LogPenalty(0.05λmax1, 0.5),
            LogPenalty(0.05λmax1, 2.0, w), NormLq(0.1λmax1, 0.5), NormLq(0.1λmax1, 2/3, w))
    for order in (:random, :cyclic)
      x = SparseIterate(p)
      x[1:4] .= 1.0                     # ℓq needs a start away from zero, where it is locally optimal
      r = solve!(x, f, g, CDSolver(; order, tol = 1e-12))
      @test r.converged
      @test coordinate_residual(X, y, g, Vector(x)) <= 1e-8
    end
  end
  # but they have no penalty level for exact coordinate descent: their exact
  # coordinate steps jump away from zero where the slope at zero says that zero
  # is locally optimal (here, the capped ℓ1 at the level of the ℓ1 λmax), so
  # paths and screening of CDSolver refuse them; their paths go through LLA
  # (lla_paths.jl), whose λmax, that of the first stage, lambda_max gives
  g = CappedL1(λmax1, 0.8)
  x = SparseIterate(p)
  solve!(x, f, g, CDSolver(; tol = 1e-12))
  @test nactive(x) > 0
  for g in (CappedL1(1.0, 0.8), LogPenalty(1.0, 0.5), NormLq(1.0, 0.5))
    @test_throws ArgumentError solve_path(f, g, [1.0, 0.5])
  end
  @test lambda_max(f, CappedL1(1.0, 0.8), SparseIterate(p)) ≈ λmax1
  @test lambda_max(f, LogPenalty(1.0, 0.5), SparseIterate(p)) ≈ 0.5 * λmax1
  @test_throws ArgumentError lambda_max(f, NormLq(1.0, 0.5), SparseIterate(p))
end

@testset "group MCP and group SCAD" begin
  X, y = ncvdata()
  n, p = size(X)
  groups = [i:i+4 for i in 1:5:p]
  f = (1 / n) * LeastSquaresLoss(y, X)
  λmaxg = lambda_max(f, GroupNormL2(1.0, groups), AtomIterate(Float64, p, groups))
  for (F, a) in ((GroupMCP, 2.5), (GroupSCAD, 3.7))
    g = F(1.0, groups; a)
    @test lambda_max(f, g, AtomIterate(Float64, p, groups)) ≈ λmaxg     # the slope at zero of the group lasso
    λs = λmaxg .* 10 .^ range(0, -1.5; length = 10)
    for screening in (true, false)
      path = solve_path(f, g, λs, CDSolver(; tol = 1e-12); x = AtomIterate(Float64, p, groups), screening, gaptol = 0)
      @test all(path.converged)
      @test norm(path.solutions[1]) <= 1e-12               # zero at λmax, up to rounding at the boundary
      @test count(!iszero, path.solutions[end]) >= 5
      # every group is its own block step: with the group's curvature L,
      # b[G] = prox_{pₖ/L}(b[G] - ∇_G f(b)/L)
      for k in eachindex(λs)
        b = Vector(path.solutions[k])
        grad = X' * (X * b - y) / n
        for (j, G) in enumerate(groups)
          L = eigmax(Symmetric(X[:, G]' * X[:, G] / n))
          one_group = F(λs[k], [1:length(G)], [g.w[j]]; a)
          @test prox(one_group, b[G] - grad[G] / L, 1 / L) ≈ b[G] atol = 1e-8
        end
      end
    end
  end
  # as a → ∞ the penalty becomes the group lasso
  path_l2 = solve_path(f, GroupNormL2(1.0, groups), λmaxg .* [1, 0.3, 0.1], CDSolver(; tol = 1e-12);
                       x = AtomIterate(Float64, p, groups), gaptol = 0)
  path_mcp = solve_path(f, GroupMCP(1.0, groups; a = 1e8), λmaxg .* [1, 0.3, 0.1], CDSolver(; tol = 1e-12);
                        x = AtomIterate(Float64, p, groups), gaptol = 0)
  for k in 1:3
    @test Vector(path_mcp.solutions[k]) ≈ Vector(path_l2.solutions[k]) atol = 1e-6
  end
end

end
