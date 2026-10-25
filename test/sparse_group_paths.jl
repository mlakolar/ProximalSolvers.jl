# Paths of the sparse group lasso at a fixed mixture α (ProximalSolvers #60):
# Scaled(SparseGroupNormL2(α, 1 - α, groups, w), λ) has level λ, its exact λmax
# comes from a per-group root, the strong rule and the optimality checks read
# the same condition, and gap-safe screening uses its dual norm.

module SparseGroupPathTests

using Test, LinearAlgebra, Random
using ProximalBase
using ProximalSolvers
const PS = ProximalSolvers

function sgldata(; n = 60, p = 90, gsize = 6, seed = 60)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  β = zeros(p); β[1:3] .= [2, -1.5, 1]; β[7:8] .= [1, -1]; β[13] = 1.5; β[20:21] .= [0.5, 0.8]
  y = X * β + 0.5 * randn(rng, n)
  X, y, [i:i+gsize-1 for i in 1:gsize:p]
end

sgl(α, groups, λ = 1.0; w = sqrt.(length.(groups))) = Scaled(SparseGroupNormL2(α, 1 - α, groups, w), λ)

soft(v, c) = sign.(v) .* max.(abs.(v) .- c, 0)

# the largest violation of the optimality conditions of λ(α‖x‖₁ + (1 - α)Σ wₖ‖x_G‖)
# at x with gradient z: a group at zero needs ‖soft(z_G, αλ)‖ ≤ (1 - α)λwₖ; in a
# nonzero group, zⱼ + αλ sign(xⱼ) + (1 - α)λwₖ xⱼ/‖x_G‖ = 0 where xⱼ ≠ 0 and
# |zⱼ| ≤ αλ where xⱼ = 0
function kkt(z, x, groups, w, α, λ)
  v = 0.0
  for (k, G) in enumerate(groups)
    nx = norm(x[G])
    if iszero(nx)
      v = max(v, norm(soft(z[G], α * λ)) - (1 - α) * λ * w[k])
    else
      for j in G
        if iszero(x[j])
          v = max(v, abs(z[j]) - α * λ)
        else
          v = max(v, abs(z[j] + α * λ * sign(x[j]) + (1 - α) * λ * w[k] * x[j] / nx))
        end
      end
    end
  end
  v
end

# the root by bisection
function root_bisect(v, a, c)
  h(μ) = norm(max.(abs.(v) .- a * μ, 0)) - c * μ
  lo, hi = 0.0, 1.0
  while h(hi) > 0
    hi *= 2
  end
  for _ in 1:200
    mid = (lo + hi) / 2
    h(mid) > 0 ? (lo = mid) : (hi = mid)
  end
  hi
end

@testset "the root of a group" begin
  rng = Xoshiro(1)
  maxerr = 0.0
  for _ in 1:2000
    q = rand(rng, 1:40)
    v = randn(rng, q) .* (rand(rng) < 0.3 ? 1e-3 : 1.0)
    rand(rng) < 0.2 && (v[rand(rng, 1:q)] = 0)
    rand(rng) < 0.2 && q > 1 && (v[2] = -v[1])                  # ties of |v|
    rand(rng) < 0.1 && (v .= round.(v; digits = 1))             # many ties
    a, c = rand(rng), 3 * rand(rng) * (rand(rng) < 0.2 ? 1e-3 : 1.0)
    all(iszero, v) && continue
    maxerr = max(maxerr, abs(PS._sgl_root(v, 1:q, a, c) / root_bisect(v, a, c) - 1))
  end
  @test maxerr < 1e-12
  @test PS._sgl_root(zeros(3), 1:3, 0.5, 0.5) == 0
  @test PS._sgl_root([1.0, -2.0], 1:2, 0.0, 2.0) ≈ sqrt(5) / 2      # the group lasso: ‖v‖/c
  @test PS._sgl_root([1.0, -2.0], 1:2, 0.5, 0.0) ≈ 4                # the lasso: ‖v‖∞/a
  @test PS._sgl_root([1.0, -2.0], 1:2, 0.0, 0.0) == Inf             # no penalty
  @test PS._sgl_root([0.0, 3.0, 0.0, -1.0], 2:3, 1.0, 1.0) ≈ root_bisect([3.0, 0.0], 1.0, 1.0)   # only G counts
  rootbytes(v) = (PS._sgl_root(v, 1:50, 0.3, 0.7); @allocated PS._sgl_root(v, 1:50, 0.3, 0.7))
  @test rootbytes(randn(rng, 50)) == 0
end

@testset "λmax" begin
  X, y, groups = sgldata()
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  x = AtomIterate(p, groups)
  z0 = -X' * y / n
  for α in (0.0, 0.05, 0.5, 0.95, 1.0), w in (sqrt.(length.(groups)), 0.5 .+ rand(Xoshiro(2), length(groups)))
    g = sgl(α, groups; w)
    λmax = lambda_max(f, g, x)
    @test kkt(z0, zeros(p), groups, w, α, λmax) <= 1e-13 * λmax
    @test kkt(z0, zeros(p), groups, w, α, λmax * (1 - 1e-6)) > 0
    # the solver agrees: zero just above λmax, not zero below
    xs = AtomIterate(p, groups)
    solve!(xs, f, sgl(α, groups, λmax * (1 + 1e-9); w), CDSolver(; tol = 1e-12))
    @test all(iszero, Vector(xs))
    xs = AtomIterate(p, groups)
    solve!(xs, f, sgl(α, groups, λmax * (1 - 1e-3); w), CDSolver(; tol = 1e-12))
    @test any(!iszero, Vector(xs))
  end
  # α = 0 is the group lasso and α = 1 the lasso
  @test lambda_max(f, sgl(0.0, groups), x) ≈ lambda_max(f, GroupNormL2(1.0, groups), x) rtol = 1e-14
  @test lambda_max(f, sgl(1.0, groups), x) ≈ lambda_max(f, NormL1(1.0), SparseIterate(p)) rtol = 1e-14
  # a group of weight zero keeps its ℓ1 term when α > 0; without any penalty it
  # is never zero and does not count
  w = ones(length(groups)); w[1] = 0
  z0max1 = norm(z0[groups[1]], Inf)
  @test lambda_max(f, sgl(0.5, groups; w), x) >= z0max1 / 0.5 * (1 - 1e-14)
  w0 = ones(length(groups)); w0[1] = 0
  @test lambda_max(f, sgl(0.0, groups; w = w0), x) ≈ lambda_max(f, GroupNormL2(1.0, groups, w0), x) rtol = 1e-14
end

@testset "paths" begin
  X, y, groups = sgldata()
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  w = sqrt.(length.(groups))
  for α in (0.05, 0.5, 0.95)
    g = sgl(α, groups)
    λmax = lambda_max(f, g, AtomIterate(p, groups))
    λs = λmax .* 10 .^ range(0, -2; length = 25)
    Random.seed!(3)
    a = solve_path(f, g, λs, CDSolver(; tol = 1e-10); x = AtomIterate(p, groups), gaptol = 0)
    b = solve_path(f, g, λs, CDSolver(; tol = 1e-10); x = AtomIterate(p, groups), screening = false, gaptol = 0)
    c = solve_path(f, g, λs, CDSolver(; tol = 1e-10, gapsafe = true); x = AtomIterate(p, groups), gaptol = 0)
    d = solve_path(f, g, λs, CDSolver(; gaptol = 1e-12); x = AtomIterate(p, groups))
    for r in (a, b, c, d)
      @test all(r.converged)
      @test r.λ == λs
    end
    @test a.values ≈ b.values rtol = 1e-10
    @test c.values ≈ b.values rtol = 1e-10
    @test d.values ≈ b.values rtol = 1e-10
    for k in eachindex(λs)
      xa = Vector(a.solutions[k])
      @test xa ≈ Vector(b.solutions[k]) atol = 1e-6
      @test kkt(X' * (X * xa - y) / n, xa, groups, w, α, λs[k]) <= 1e-6 * λs[k]
    end
    # continuation to the last level reaches the same minimum
    xc = AtomIterate(p, groups)
    r = solve!(xc, f, sgl(α, groups, λs[end]), CDSolver(; tol = 1e-10); continuation = 10, gaptol = 0)
    @test r.minimum ≈ b.values[end] rtol = 1e-9
  end
end

@testset "α = 0 and α = 1" begin
  X, y, groups = sgldata(; seed = 61)
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  # α = 0: the group lasso
  λs = lambda_max(f, GroupNormL2(1.0, groups), AtomIterate(p, groups)) .* 10 .^ range(0, -2; length = 15)
  s = solve_path(f, sgl(0.0, groups), λs, CDSolver(; tol = 1e-11); x = AtomIterate(p, groups), gaptol = 0)
  gl = solve_path(f, GroupNormL2(1.0, groups), λs, CDSolver(; tol = 1e-11); x = AtomIterate(p, groups), gaptol = 0)
  @test s.values ≈ gl.values rtol = 1e-10
  @test all(norm(Vector(s.solutions[k]) - Vector(gl.solutions[k])) <= 1e-6 for k in eachindex(λs))
  # α = 1: the lasso, on groups or on single coordinates
  λs = lambda_max(f, NormL1(1.0), SparseIterate(p)) .* 10 .^ range(0, -2; length = 15)
  s = solve_path(f, sgl(1.0, groups), λs, CDSolver(; tol = 1e-11); x = AtomIterate(p, groups), gaptol = 0)
  l1 = solve_path(f, NormL1(1.0), λs, CDSolver(; tol = 1e-11); gaptol = 0)
  @test s.values ≈ l1.values rtol = 1e-10
  @test all(norm(Vector(s.solutions[k]) - Vector(l1.solutions[k])) <= 1e-6 for k in eachindex(λs))
end

@testset "weighted model with groups larger than n" begin
  rng = Xoshiro(62)
  n, p = 20, 60
  X, y = randn(rng, n, p), randn(rng, n)
  wobs = rand(rng, n) .+ 0.5
  f = GLMLoss(ProximalBase.Squared(), y, X; weights = wobs)
  groups = [1:30, 31:45, 46:60]
  w = sqrt.(length.(groups))
  for α in (0.2, 0.8)
    g = sgl(α, groups)
    λmax = lambda_max(f, g, AtomIterate(p, groups))
    λs = λmax .* [1.0, 0.6, 0.3, 0.1]
    a = solve_path(f, g, λs, CDSolver(; tol = 1e-11); x = AtomIterate(p, groups), gaptol = 0)
    b = solve_path(f, g, λs, CDSolver(; tol = 1e-11); x = AtomIterate(p, groups), screening = false, gaptol = 0)
    @test all(a.converged)
    @test a.values ≈ b.values rtol = 1e-9
    for k in eachindex(λs)
      xa = Vector(a.solutions[k])
      @test kkt(-X' * (wobs .* (y - X * xa)), xa, groups, w, α, λs[k]) <= 1e-6 * λs[k]
    end
  end
end

@testset "duality gap" begin
  X, y, groups = sgldata(; seed = 63)
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  α = 0.4
  g = sgl(α, groups, 0.3 * lambda_max(f, sgl(α, groups), AtomIterate(p, groups)))
  λ = g.α
  w = sqrt.(length.(groups))
  # the dual scale makes the point feasible, with one group on the boundary
  z = randn(Xoshiro(4), p)
  t = PS._dualscale(g, z)
  @test 0 < t < 1
  viol = [norm(soft(t * z[G], α * λ)) - (1 - α) * λ * w[k] for (k, G) in enumerate(groups)]
  @test maximum(viol) <= 1e-12 * λ
  @test maximum(viol) >= -1e-12 * λ
  @test PS._dualscale(g, 1e-3 * t * z) == 1
  # the raw penalty has the same dual scale as the scaled one
  @test PS._dualscale(SparseGroupNormL2(α * λ, (1 - α) * λ, groups), z) ≈ t rtol = 1e-14
  # the gap is nonnegative, and small at the solution
  x = AtomIterate(p, groups)
  r = solve!(x, f, g, CDSolver(; tol = 1e-12))
  gp = duality_gap(f, g, x)
  @test gp.gap >= -1e-12
  @test gp.gap <= 1e-9 * abs(gp.primal)
  x0 = AtomIterate(p, groups)
  @test duality_gap(f, g, x0).gap > 1e-3
  @test duality_gap(f, SparseGroupNormL2(α * λ, (1 - α) * λ, groups), x).gap <= 1e-9 * abs(gp.primal)
  # gaptol stops on the gap, with or without gap-safe screening
  for s in (CDSolver(; gaptol = 1e-9), CDSolver(; gaptol = 1e-9, gapsafe = true), CDSolver(; tol = 1e-12, gapsafe = true))
    xs = AtomIterate(p, groups)
    rs = solve!(xs, f, g, s)
    @test rs.converged
    @test rs.gap <= max(s.gaptol, 1e-9)
    @test rs.minimum ≈ r.minimum rtol = 1e-8
  end
  # gap-safe screening removes groups, never one that is nonzero at the solution,
  # for the scaled and the raw penalty
  for gs in (g, SparseGroupNormL2(α * λ, (1 - α) * λ, groups))
    xs = AtomIterate(p, groups)
    s = CDSolver(; tol = 1e-12, gapsafe = true)
    m = cdmodel(f, xs)
    PS.initialize!(m, xs)
    st = PS._CDState(Float64, xs, s.random)
    PS._cd!(xs, m, gs, st, s)
    @test Vector(xs) ≈ Vector(x) atol = 1e-7
    @test count(!, st.gap.keep) >= length(groups) ÷ 2
    @test all(k -> st.gap.keep[k] || all(iszero, Vector(x)[groups[k]]), eachindex(groups))
  end
  # the gradient solvers stop on the gap too
  res = solve!(zeros(p), f, g, AccProxGradDescent(), ProximalOptions(; maxiter = 100_000, gaptol = 1e-8))
  @test f(res.minimizer) + g(res.minimizer) ≈ r.minimum rtol = 1e-7
end

@testset "allocations" begin
  X, y, groups = sgldata()
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  g = sgl(0.5, groups, 0.2 * lambda_max(f, sgl(0.5, groups), AtomIterate(p, groups)))
  function passes_bytes(x, m, g, s)
    PS.initialize!(m, x)
    st = PS._CDState(Float64, x, s.random)
    PS._cd!(x, m, g, st, s)
    L = copy(m.L)
    fill!(x, 0.0); PS.initialize!(m, x)
    copyto!(m.L, L)
    @allocated PS._cd!(x, m, g, st, s)
  end
  for s in (CDSolver(), CDSolver(; gaptol = 1e-9), CDSolver(; gapsafe = true), CDSolver(; gaptol = 1e-9, gapsafe = true))
    x = AtomIterate(p, groups)
    @test passes_bytes(x, cdmodel(f, x), g, s) == 0
  end
end

end
