# Momentum on the groups of an AtomIterate (CDSolver(; momentum = true)): the
# solutions and paths of the plain passes, fewer passes where the plain ones are
# slow, caches that move exactly with the extrapolated point, and the default
# (momentum = nothing), which stays off on an AtomIterate.

module GroupMomentumTests

using Test, LinearAlgebra, Random, SparseArrays, Statistics
using ProximalBase
using ProximalSolvers
using ProximalSolvers: intercept, residuals
const PS = ProximalSolvers

function groupdata(; n = 120, p = 30, seed = 150)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  β = zeros(p); β[1:3] .= [1.5, -1, 0.5]; β[7:9] .= [1, 1, -1]
  X, X * β .+ 1 .+ 0.3 .* randn(rng, n)
end

# the multi-response data: Y = 1 + X B + noise, with five nonzero rows of B
function mlsdata(; n = 120, p = 20, q = 3, seed = 151)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  B = zeros(p, q); B[1:5, :] .= randn(rng, 5, q)
  X, 1 .+ X * B .+ 0.5 .* randn(rng, n, q)
end

# a solve from zero with and without momentum, each on a model of its own
function both(model, g, x; tol = 1e-12)
  x0, x1 = copy(x), copy(x)
  r0 = solve!(x0, model(x0), g, CDSolver(; tol, momentum = false, rng = Xoshiro(1)))
  r1 = solve!(x1, model(x1), g, CDSolver(; tol, momentum = true, rng = Xoshiro(1)))
  x0, r0, x1, r1
end

@testset "the solutions without momentum" begin
  X, y = groupdata()
  n, p = size(X)
  groups = [i:i+2 for i in 1:3:p]
  w = rand(Xoshiro(2), n) .+ 0.5
  o = 0.1 .* randn(Xoshiro(3), n)
  Xs = sparse(X .* (abs.(X) .> 0.5))
  f = (1 / n) * LeastSquaresLoss(y, X)
  fq = QuadraticFunction(X' * X / n, -X' * y / n)
  λ = 0.1 * maximum(G -> norm(X[:, G]' * (y .- mean(y))), groups) / n
  sgl = Scaled(SparseGroupNormL2(0.5, 0.5, groups, sqrt.(length.(groups))), λ)
  x = AtomIterate(Float64, p, groups)

  # well-conditioned problems (n > p) and convex penalties: the same
  # coefficients, for least squares with and without an intercept, a sparse X,
  # weights and an offset, a quadratic, the group norms, the sparse group lasso
  # and separable penalties applied entry by entry
  cases = ((x -> cdmodel(f, x), GroupNormL2(λ, groups)),
           (x -> cdmodel(f, x; intercept = true), GroupNormL2(λ, groups)),
           (x -> cdmodel((1 / n) * LeastSquaresLoss(y, Xs), x; intercept = true), GroupNormL2(λ, groups)),
           (x -> cdmodel((1 / n) * GLMLoss(ProximalBase.Squared(), y, Xs; weights = w, offset = o), x; intercept = true),
            GroupNormL2(λ, groups)),
           (x -> cdmodel(fq, x), GroupNormL2(λ, groups)),
           (x -> cdmodel(f, x; intercept = true), GroupNormLinf(λ, groups)),
           (x -> cdmodel(fq, x), GroupNormLinf(λ, groups)),
           (x -> cdmodel(f, x; intercept = true), sgl),
           (x -> cdmodel(f, x), SparseGroupNormL2(λ / 2, λ / 2, groups)),
           (x -> cdmodel(f, x; intercept = true), NormL1Nonneg(λ)),
           (x -> cdmodel(f, x; intercept = true), IndBox(-0.5, 0.5)))
  for (model, gc) in cases
    x0, r0, x1, r1 = both(model, gc, x)
    @test r0.converged && r1.converged
    @test nactive(x1) > 0
    @test Vector(x1) ≈ Vector(x0) atol = 1e-8
    @test r1.minimum ≈ r0.minimum rtol = 1e-10
  end

  # the group MCP is not convex: the point momentum reaches is stationary, each
  # group the block step of itself, b[G] = prox_{pₖ/L}(b[G] - ∇_G f(b)/L)
  a = 3.0
  gmcp = GroupMCP(λ, groups; a)
  _, _, x1, r1 = both(x -> cdmodel(f, x), gmcp, x)
  @test r1.converged
  b = Vector(x1)
  grad = X' * (X * b - y) / n
  for (k, G) in enumerate(groups)
    L = eigmax(Symmetric(X[:, G]' * X[:, G] / n))
    @test prox(GroupMCP(λ, [1:length(G)], [gmcp.w[k]]; a), b[G] - grad[G] / L, 1 / L) ≈ b[G] atol = 1e-8
  end

  # the multi-response model with and without an intercept, whose cache is the
  # residual matrix
  Xm, Y = mlsdata()
  pm, q = size(Xm, 2), size(Y, 2)
  rows = [collect(k:pm:pm*q) for k in 1:pm]
  fm = (1 / n) * LeastSquaresLoss(Y, Xm)
  gm = GroupNormL2(0.1 * maximum(k -> norm(Xm[:, k]' * Y), 1:pm) / n, rows)
  for icpt in (false, true)
    x0, r0, x1, r1 = both(x -> cdmodel(fm, x; intercept = icpt), gm, AtomIterate(Float64, pm * q, rows))
    @test r0.converged && r1.converged
    @test Vector(x1) ≈ Vector(x0) atol = 1e-8
    @test r1.minimum ≈ r0.minimum rtol = 1e-10
  end

  # Float32: the tolerance of the passes is that of the precision
  f32 = (1f0 / n) * LeastSquaresLoss(Float32.(y), Float32.(X))
  for g32 in (GroupNormL2(Float32(λ), groups), SparseGroupNormL2(Float32(λ / 2), Float32(λ / 2), groups))
    x0, r0, x1, r1 = both(x -> cdmodel(f32, x; intercept = true), g32, AtomIterate(Float32, p, groups); tol = 1e-6)
    @test r0.converged && r1.converged
    @test eltype(x1) === Float32
    @test Vector(x1) ≈ Vector(x0) atol = 1e-4
    @test r1.minimum ≈ r0.minimum rtol = 1e-5
  end
end

@testset "paths" begin
  X, y = groupdata(; seed = 152)
  n, p = size(X)
  groups = [i:i+2 for i in 1:3:p]
  f = (1 / n) * LeastSquaresLoss(y, X)
  sgl = Scaled(SparseGroupNormL2(0.5, 0.5, groups, sqrt.(length.(groups))), 1.0)

  # every level certified to the gap target, at the objectives of the plain path
  for (g, gapsafe) in ((GroupNormL2(1.0, groups), false), (GroupNormL2(1.0, groups), true), (sgl, false))
    λmax = lambda_max(f, g, AtomIterate(Float64, p, groups))
    λs = λmax .* exp10.(range(0, -2; length = 8))
    paths = map((false, true)) do momentum
      s = CDSolver(; momentum, gapsafe, rng = Xoshiro(1))
      solve_path(f, g, λs, s; x = AtomIterate(Float64, p, groups), gaptol = 1e-8)
    end
    @test all(paths[2].converged)
    @test all(<=(1e-8), paths[2].gap)
    @test all(isapprox.(paths[2].values, paths[1].values; rtol = 3e-8))
  end

  # the multi-response model has no duality gap: the rule on the changes
  Xm, Y = mlsdata(; seed = 153)
  pm, q = size(Xm, 2), size(Y, 2)
  rows = [collect(k:pm:pm*q) for k in 1:pm]
  fm = (1 / n) * LeastSquaresLoss(Y, Xm)
  gm = GroupNormL2(1.0, rows)
  λs = lambda_max(fm, gm, AtomIterate(Float64, pm * q, rows)) .* exp10.(range(0, -2; length = 8))
  paths = map((false, true)) do momentum
    solve_path(fm, gm, λs, CDSolver(; tol = 1e-12, momentum, rng = Xoshiro(1)); gaptol = 0)
  end
  @test all(paths[2].converged)
  @test all(norm(paths[2].solutions[k] - paths[1].solutions[k]) < 1e-8 for k in eachindex(λs))
  # continuation to the last level
  xc = AtomIterate(Float64, pm * q, rows)
  @test solve!(xc, fm, GroupNormL2(λs[end], rows), CDSolver(; tol = 1e-12, momentum = true, rng = Xoshiro(1));
               continuation = 5, gaptol = 0).converged
  @test Vector(xc) ≈ Vector(paths[1].solutions[end]) atol = 1e-8
end

@testset "fewer passes on a block-diagonal multitask design" begin
  # three tasks with their own designs and the rows of B as groups, as in the
  # multitask lasso on a stacked, block-diagonal design; the third task has
  # fewer observations than predictors, and the small level nearly
  # interpolates it, where plain coordinate descent needs many passes
  rng = Xoshiro(150)
  p, ns = 30, (60, 40, 20)
  q = length(ns)
  Xs = [2 .* rand(rng, nt, p) .- 1 for nt in ns]
  B = zeros(p, q); B[1:4, :] .= 2 .* rand(rng, 4, q) .- 1
  y = reduce(vcat, [Xs[t] * B[:, t] .+ 0.1 .* (2 .* rand(rng, ns[t]) .- 1) for t in 1:q])
  X = blockdiag(sparse.(Xs)...)
  groups = [collect(k:p:p*q) for k in 1:p]
  f = (1 / sum(ns)) * LeastSquaresLoss(y, X)
  g = GroupNormL2(1e-3 * lambda_max(f, GroupNormL2(1.0, groups), AtomIterate(Float64, p * q, groups)), groups)
  x0, r0, x1, r1 = both(x -> cdmodel(f, x), g, AtomIterate(Float64, p * q, groups); tol = 1e-8)
  @test r0.converged && r1.converged
  @test r1.passes < r0.passes / 2
  @test r1.minimum ≈ r0.minimum rtol = 1e-10
end

@testset "the history and the caches at the extrapolated point" begin
  X, y = groupdata(; seed = 154)
  n, p = size(X)
  groups = [i:i+2 for i in 1:3:p]
  w = rand(Xoshiro(5), n) .+ 0.5
  o = 0.1 .* randn(Xoshiro(6), n)
  Xs = sparse(X .* (abs.(X) .> 0.5))
  A = X' * X / n

  # three active groups, a pass over them as the solver takes it (a step
  # without momentum, the pass, the update), and the step with β = 1/4: the
  # active entries move to xₖ + (xₖ - xₖ₋₁)/4, the others stay zero, and no
  # group joins or leaves the active set
  function stepped!(m, g, x)
    PS.initialize!(m, x)
    st = PS._CDState(Float64, x, CDSolver(; rng = Xoshiro(7)))
    mom = PS._momentum_start!(st.momentum, x, m)
    PS._momentum_reset!(mom, x, m)
    @test mom.na == 3 && mom.n == 3 * 3 && mom.k == 1
    xprev = Vector(x)
    PS._momentum_step!(mom, x, m)
    @test Vector(x) == xprev && !mom.moved          # β = 0
    PS._pass!(x, m, g, st, false, false)
    PS._momentum_update!(mom, x, m)
    @test mom.k == 2 && !mom.moved
    xcur = Vector(x)
    active, na = copy(activecoordinates(x)), nactive(x)
    @test na == 3
    PS._momentum_step!(mom, x, m)
    @test mom.moved
    @test nactive(x) == na && activecoordinates(x) == active
    @test Vector(x) == xcur .+ (xcur .- xprev) ./ 4
    @test Vector(x) != xcur
    Vector(x)
  end
  function start(x)
    for (j, v) in ((1, 0.5), (2, -0.3), (8, 0.8), (9, -0.4), (13, 0.2))
      x[j] = v
    end
    x
  end

  # least squares, dense with an intercept, sparse with an intercept, and
  # sparse with weights, an offset and an intercept: the residuals
  # y - o - β₀ - Xβ, and δ = x̄'β of a sparse X with them
  for (A_, model) in ((X, x -> cdmodel((1 / n) * LeastSquaresLoss(y, X), x; intercept = true)),
                      (Xs, x -> cdmodel((1 / n) * LeastSquaresLoss(y, Xs), x; intercept = true)),
                      (Xs, x -> cdmodel((1 / n) * GLMLoss(ProximalBase.Squared(), y, Xs; weights = w, offset = o), x;
                                        intercept = true)))
    x = start(AtomIterate(Float64, p, groups))
    m = model(x)
    b = stepped!(m, GroupNormL2(0.01, groups), x)
    offset = m.offset === nothing ? 0.0 : m.offset
    @test residuals(m) ≈ y .- offset .- intercept(m, b) .- A_ * b atol = 1e-12
  end
  # a quadratic: u = Ax
  x = start(AtomIterate(Float64, p, groups))
  m = cdmodel(QuadraticFunction(A, -X' * y / n), x)
  b = stepped!(m, GroupNormL2(0.01, groups), x)
  @test m.u ≈ A * b atol = 1e-12
  # the multi-response model with an intercept: R = Y - 1β₀' - XB
  Xm, Y = mlsdata(; seed = 155)
  pm, q = size(Xm, 2), size(Y, 2)
  rows = [collect(k:pm:pm*q) for k in 1:pm]
  x = AtomIterate(Float64, pm * q, rows)
  for (k, v) in ((1, 0.5), (3, -0.4), (4, 0.3))      # rows 1, 3 and 4 of B
    for c in 1:q
      x[(c - 1) * pm + k] = v * c
    end
  end
  m = cdmodel((1 / n) * LeastSquaresLoss(Y, Xm), x; intercept = true)
  b = stepped!(m, GroupNormL2(0.01, rows), x)
  @test m.R ≈ Y .- intercept(m, b)' .- Xm * reshape(b, pm, q) atol = 1e-12

  # a group extrapolated to exactly zero, 1 + (1 - 5)/4 = 0, stays active for
  # the pass, which keeps it at zero (its weight is large) and drops it; the
  # change of the active set starts the history again
  f = (1 / n) * LeastSquaresLoss(y, X)
  wts = ones(length(groups)); wts[2] = 1e6
  g = GroupNormL2(0.01, groups, wts)
  x = AtomIterate(Float64, p, groups)
  x[1], x[2] = 1.0, -0.5
  for j in groups[2]
    x[j] = 5.0
  end
  m = cdmodel(f, x)
  PS.initialize!(m, x)
  st = PS._CDState(Float64, x, CDSolver(; rng = Xoshiro(7)))
  mom = PS._momentum_start!(st.momentum, x, m)
  PS._momentum_reset!(mom, x, m)
  PS._momentum_step!(mom, x, m)                      # β = 0
  for j in groups[2]
    x[j] = 1.0                                       # as after a pass
  end
  PS.initialize!(m, x)
  PS._momentum_update!(mom, x, m)
  PS._momentum_step!(mom, x, m)                      # β = 1/4
  @test all(iszero, x[groups[2]])
  @test isactive(x, 2) && nactive(x) == 2
  @test residuals(m) ≈ y - X * Vector(x) atol = 1e-12
  PS._pass!(x, m, g, st, false, false)
  @test !isactive(x, 2) && nactive(x) == 1
  PS._momentum_update!(mom, x, m)
  @test mom.k == 1 && mom.na == 1 && mom.n == length(groups[1])
  @test mom.xcur[1:mom.n] == x[groups[1]]
end

@testset "momentum stays off by default on an AtomIterate" begin
  X, y = groupdata(; seed = 156)
  n, p = size(X)
  groups = [i:i+2 for i in 1:3:p]
  f = (1 / n) * LeastSquaresLoss(y, X)
  Xm, Y = mlsdata(; seed = 157)
  pm, q = size(Xm, 2), size(Y, 2)
  rows = [collect(k:pm:pm*q) for k in 1:pm]
  for (fl, g, x) in ((f, GroupNormL2(0.05, groups), AtomIterate(Float64, p, groups)),
                     (QuadraticFunction(X' * X / n, -X' * y / n), GroupNormLinf(0.05, groups), AtomIterate(Float64, p, groups)),
                     ((1 / n) * LeastSquaresLoss(Y, Xm), GroupNormL2(0.05, rows), AtomIterate(Float64, pm * q, rows)))
    x0, x1 = copy(x), copy(x)
    r0 = solve!(x0, fl, g, CDSolver(; tol = 1e-10, rng = Xoshiro(8)))
    r1 = solve!(x1, fl, g, CDSolver(; tol = 1e-10, momentum = false, rng = Xoshiro(8)))
    @test r0.passes == r1.passes
    @test Vector(x0) == Vector(x1)
    m = cdmodel(fl, x)
    @test !PS._usemomentum(CDSolver(), x, m)
    @test PS._usemomentum(CDSolver(; momentum = true), x, m)
  end
end

end
