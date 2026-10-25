# Paths, continuation, λmax and screening for penalties with a level on a box,
# Constrained(g, IndBox(l, u)), checked against the optimality conditions
# computed from dense algebra.

module BoxPathTests

using Test, LinearAlgebra, Random, SparseArrays
using ProximalBase
using ProximalSolvers

lsgrad(X, y, x) = X' * (X * x - y) / size(X, 1)
logistic(z) = 1 / (1 + exp(-z))

# largest violation of 0 ∈ g + λ ∂(Σ wᵢ|xᵢ|) + N(x), with N(x) the normal cone
# of the box l ≤ x ≤ u: (-∞, 0] at a lower bound, [0, ∞) at an upper bound
function kkt_box(g, x, λ, l, u, w = ones(length(x)))
  v = 0.0
  for i in eachindex(x)
    c = λ * w[i]
    a, b = x[i] > 0 ? (c, c) : x[i] < 0 ? (-c, -c) : (-c, c)
    lo = x[i] == l[i] ? -Inf : a
    hi = x[i] == u[i] ? Inf : b
    t = -g[i]
    v = max(v, t < lo ? lo - t : t > hi ? t - hi : 0.0)
  end
  v
end

inbox(x, l, u) = all(l .<= x .<= u)
atlevel(g::Union{MCP, SCAD}, λ) = typeof(g)(λ, g.a)

function lassodata(; n = 80, p = 200, seed = 1)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  β = zeros(p); β[1:6] .= [2, -1.5, 1, -1, 0.5, -0.5]
  X, X * β + 0.3 * randn(rng, n)
end

X, y = lassodata()
n, p = size(X)
f = (1 / n) * LeastSquaresLoss(y, X)
z = X' * y / n      # -∇f(0)

# bounds with zero inside: nonnegative, nonpositive, finite and binding, and
# per coordinate (some fixed at zero, some one-sided, some free)
lv = fill(-Inf, p); uv = fill(Inf, p)
lv[1:2:p] .= 0; uv[4:6:p] .= 0; lv[3] = uv[3] = 0; uv[1] = 1.2; lv[2] = -0.6
const BOXES = [
  ("x ≥ 0", fill(0.0, p), fill(Inf, p), IndBox(0.0, Inf)),
  ("x ≤ 0", fill(-Inf, p), fill(0.0, p), IndBox(-Inf, 0.0)),
  ("-0.5 ≤ x ≤ 0.8", fill(-0.5, p), fill(0.8, p), IndBox(-0.5, 0.8)),
  ("per coordinate", lv, uv, IndBox(lv, uv)),
]

@testset "λmax on a box" begin
  for (name, l, u, box) in BOXES
    g = Constrained(NormL1(1.0), box)
    # the part of -∇f(0) that points into the box
    t = [z[k] > 0 ? (u[k] > 0 ? z[k] : 0.0) : (l[k] < 0 ? -z[k] : 0.0) for k in 1:p]
    λmax = lambda_max(f, g, SparseIterate(p))
    @test λmax ≈ maximum(t)
    x = SparseIterate(p)
    solve!(x, f, Constrained(NormL1(λmax * (1 + 1e-9)), box), CDSolver(; tol = 1e-12))
    @test nnz(x) == 0
    solve!(x, f, Constrained(NormL1(λmax * (1 - 1e-3)), box), CDSolver(; tol = 1e-12))
    @test nnz(x) == 1
  end
  # the box does not change λmax when it allows both signs
  @test lambda_max(f, Constrained(NormL1(1.0), IndBox(-1.0, 1.0)), SparseIterate(p)) ≈ maximum(abs, z)
  # weights, as for NormL1
  w = rand(Xoshiro(2), p) .+ 0.5
  @test lambda_max(f, Constrained(NormL1(1.0, w), IndBox(0.0, Inf)), SparseIterate(p)) ≈ maximum(max.(z, 0) ./ w)
end

@testset "paths on a box: $name" for (name, l, u, box) in BOXES
  g = Constrained(NormL1(1.0), box)
  λmax = lambda_max(f, g, SparseIterate(p))
  λs = λmax * (1 + 1e-9) .* 10 .^ range(0, -2; length = 15)   # just above λmax, whatever the rounding
  paths = map((true, false)) do screening
    path = solve_path(f, g, λs, CDSolver(; tol = 1e-10); screening, gaptol = 0)
    @test path.λ == λs && all(path.converged)
    @test screening ? all(>=(1), path.kkt_checks) : all(iszero, path.kkt_checks)
    for k in eachindex(λs)
      b = Vector(path.solutions[k])
      @test inbox(b, l, u)
      @test kkt_box(lsgrad(X, y, b), b, λs[k], l, u) < 1e-6
      @test path.values[k] ≈ sum(abs2, y - X * b) / (2n) + λs[k] * sum(abs, b)
    end
    @test nnz(path.solutions[1]) == 0
    path
  end
  # the same minima with and without screening; near 0.01 λmax the problem is
  # close to interpolation, so the solutions themselves agree only to about 1e-6
  @test paths[1].values ≈ paths[2].values rtol = 1e-10

  # continuation down to one level
  λ = 0.02λmax
  x = SparseIterate(p)
  r = solve!(x, f, Constrained(NormL1(λ), box), CDSolver(; tol = 1e-10); continuation = 10, gaptol = 0)
  @test r.converged && r.kkt_checks >= 11
  @test inbox(Vector(x), l, u)
  @test kkt_box(lsgrad(X, y, Vector(x)), Vector(x), λ, l, u) < 1e-6
end

@testset "the nonnegative lasso: a box or NormL1Nonneg" begin
  w = rand(Xoshiro(3), p) .+ 0.5
  λmax = lambda_max(f, Constrained(NormL1(1.0, w), IndBox(0.0, Inf)), SparseIterate(p))
  λs = λmax .* 10 .^ range(0, -2; length = 10)
  pb = solve_path(f, Constrained(NormL1(1.0, w), IndBox(0.0, Inf)), λs, CDSolver(; tol = 1e-10); gaptol = 0)
  pn = solve_path(f, NormL1Nonneg(1.0, w), λs, CDSolver(; tol = 1e-10); gaptol = 0)
  @test pb.values ≈ pn.values rtol = 1e-10
  @test all(k -> isapprox(Vector(pb.solutions[k]), Vector(pn.solutions[k]); atol = 1e-5), eachindex(λs))
end

@testset "other penalties on a box" begin
  l, u = fill(-0.5, p), fill(Inf, p)
  box = IndBox(-0.5, Inf)
  for (g, ridge) in ((ElasticNet(1.0, 0.1), λ -> 0.1), (Scaled(ElasticNet(0.5, 0.5), 1.0), λ -> 0.5λ))
    gb = Constrained(g, box)
    α = g isa Scaled ? 0.5 : 1.0
    λmax = lambda_max(f, gb, SparseIterate(p))
    @test λmax ≈ maximum(max.(z, 0) .+ max.(-z, 0)) / α     # both directions are open
    λs = λmax .* 10 .^ range(0, -2; length = 10)
    path = solve_path(f, gb, λs, CDSolver(; tol = 1e-10); gaptol = 0)
    for k in eachindex(λs)
      b = Vector(path.solutions[k])
      @test inbox(b, l, u)
      @test kkt_box(lsgrad(X, y, b) .+ ridge(λs[k]) .* b, b, α * λs[k], l, u) < 1e-6
    end
  end
  # nonconvex penalties on a box follow a path of local solutions
  for g in (MCP(1.0, 3.0), SCAD(1.0, 3.7))
    gb = Constrained(g, IndBox(0.0, 1.0))
    λmax = lambda_max(f, gb, SparseIterate(p))
    @test λmax ≈ maximum(max.(z, 0))
    path = solve_path(f, gb, λmax * (1 + 1e-9) .* 10 .^ range(0, -2; length = 10), CDSolver(; tol = 1e-10); gaptol = 0)
    @test all(path.converged)
    @test all(b -> inbox(Vector(b), zeros(p), ones(p)), path.solutions)
    @test nnz(path.solutions[1]) == 0 && nnz(path.solutions[end]) > 0
    x = SparseIterate(p)
    solve!(x, f, Constrained(atlevel(g, 0.05λmax), IndBox(0.0, 1.0)), CDSolver(; tol = 1e-10); continuation = 10, gaptol = 0)
    @test inbox(Vector(x), zeros(p), ones(p))
  end
end

@testset "generalized linear models on a box" begin
  rng = Xoshiro(4)
  nl, pl = 200, 60
  Xl = randn(rng, nl, pl); β = zeros(pl); β[1:4] .= [1.5, -1, 1, -0.8]
  yl = Float64.(rand(rng, nl) .< logistic.(Xl * β))
  fl = (1 / nl) * LogisticLoss(yl, Xl)
  gradl(b) = Xl' * (logistic.(Xl * b) .- yl) / nl
  l, u = zeros(pl), fill(Inf, pl)
  g = Constrained(NormL1(1.0), IndBox(0.0, Inf))
  λmax = lambda_max(fl, g, SparseIterate(pl))
  @test λmax ≈ maximum(max.(-gradl(zeros(pl)), 0))
  λs = λmax .* 10 .^ range(0, -1.5; length = 10)
  for method in (CDSolver(; tol = 1e-10, maxpasses = 10^6), ProxNewton(; tol = 1e-14, inner = CDSolver(; tol = 1e-10)))
    path = method isa ProxNewton ? solve_path(fl, g, λs, method; devmax = 1.0) : solve_path(fl, g, λs, method)
    @test all(path.converged)
    for k in eachindex(λs)
      b = Vector(path.solutions[k])
      @test inbox(b, l, u)
      @test kkt_box(gradl(b), b, λs[k], l, u) < 1e-6
    end
  end
end

@testset "zero must be in the box" begin
  g = Constrained(NormL1(1.0), IndBox(0.1, 1.0))
  @test_throws ArgumentError lambda_max(f, g, SparseIterate(p))
  @test_throws ArgumentError solve_path(f, g, [1.0, 0.5])
  @test_throws ArgumentError solve!(SparseIterate(p), f, Constrained(NormL1(0.01), IndBox(0.1, 1.0)), CDSolver(); continuation = 5)
  # at one level without a path, coordinate descent solves it
  x = SparseIterate(p)
  r = solve!(x, f, Constrained(NormL1(0.01), IndBox(0.1, 1.0)), CDSolver(; tol = 1e-10))
  @test r.converged && inbox(Vector(x), fill(0.1, p), ones(p))
  @test kkt_box(lsgrad(X, y, Vector(x)), Vector(x), 0.01, fill(0.1, p), ones(p)) < 1e-6
  # a box without a penalty level has no path
  @test_throws ArgumentError solve_path(f, Constrained(SqrNormL2(1.0), IndBox(0.0, Inf)), [1.0])
end

end
