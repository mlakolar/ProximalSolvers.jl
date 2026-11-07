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
  # change of the active set starts the history again, in the order of
  # x.active. Group 2 joins last, or first: dropzeros! then moves the last
  # active group into its place
  f = (1 / n) * LeastSquaresLoss(y, X)
  wts = ones(length(groups)); wts[2] = 1e6
  g = GroupNormL2(0.01, groups, wts)
  for (joined, after) in (([1, 2], [1]), ([2, 1, 4], [4, 1]))
    x = AtomIterate(Float64, p, groups)
    for k in joined
      G = groups[k]
      if k == 2
        for j in G
          x[j] = 5.0
        end
      else
        x[G[1]], x[G[2]] = 1.0, -0.5
      end
    end
    @test activecoordinates(x) == joined
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
    @test isactive(x, 2) && activecoordinates(x) == joined
    @test residuals(m) ≈ y - X * Vector(x) atol = 1e-12
    PS._pass!(x, m, g, st, false, false)
    @test !isactive(x, 2) && activecoordinates(x) == after
    PS._momentum_update!(mom, x, m)
    @test mom.k == 1 && mom.na == length(after) && mom.n == 3 * length(after)
    @test mom.xcur[1:mom.n] == reduce(vcat, x[groups[k]] for k in activecoordinates(x))
  end
end

@testset "a momentum refresh keeps the curvatures" begin
  # the refresh computes the moved cache again, as the levels of a path do, and
  # keeps the curvatures of the groups (of the rows for the multi-response
  # model), which depend only on the data; initialize! clears them
  X, y = groupdata(; seed = 158)
  n, p = size(X)
  groups = [i:i+2 for i in 1:3:p]
  Xm, Y = mlsdata(; seed = 159)
  pm, q = size(Xm, 2), size(Y, 2)
  rows = [collect(k:pm:pm*q) for k in 1:pm]
  for (f, x) in (((1 / n) * LeastSquaresLoss(y, X), AtomIterate(Float64, p, groups)),
                 (QuadraticFunction(X' * X / n, -X' * y / n), AtomIterate(Float64, p, groups)),
                 ((1 / n) * LeastSquaresLoss(Y, Xm), AtomIterate(Float64, pm * q, rows)))
    x[1], x[2] = 0.5, -0.3
    m = cdmodel(f, x)
    PS.initialize!(m, x)
    mom = PS._momentum_start!(PS._Momentum{Float64}(), x, m)
    PS._momentum_reset!(mom, x, m)
    mls = m isa PS.MLSModel
    curvatures = mls ? m.a : m.L
    for k in eachindex(curvatures)
      mls ? PS._sqnorm!(m, k) : PS._groupcurvature!(m, x, k)
    end
    @test all(isfinite, curvatures)
    cache = copy(PS._cache(m))
    fill!(PS._cache(m), 0.0)                           # as if it had drifted
    fill!(curvatures, 7.0)
    mom.moved = true
    PS._momentum_refresh!(mom, x, m)
    @test !mom.moved
    @test PS._cache(m) ≈ cache
    @test all(==(7.0), curvatures)
    PS.initialize!(m, x)
    @test all(isnan, curvatures)
  end
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

# FT27 (#165): momentum on the groups and on the stored values, through the public accessors of the iterates.
#
# Recorded trajectories, from the base commit 412063d8ac24b84a10ccde09cf072bb396109ffd (the audited behaviour,
# which reads the iterate fields directly) on ProximalBase 0.5.4, Julia 1.13.3 (the data are the same on every
# Julia version). The data are `ft27_lassodata`
# (seed 11) and the groups of `ft27_groupsets` (the permutation has seed 5), from the generator `ft27_stream`; the
# loss is (1/n) LeastSquaresLoss;
# the penalty levels are those of `ft27_cases`. Floats are the hex digits of the Float64 bit pattern (Float32
# results are widened). `FT27` per case: `passes`, `nactive`, `active` (activecoordinates, in order), `hist`
# (the history after the run: n, na, k, length of the buffers), `k` (the history's k after pass 1, 2, ...),
# `obj` (the objective after pass 1, 2, ...), `xi`/`xv` (the nonzero entries of the final iterate),
# `xcur`/`xprev`/`y` (the first n entries of the history after the run).
const FT27 = Dict{String,NamedTuple}(
  "f64/sparse_lasso" => (passes = 53, nactive = 27, active = [202,3,201,200,192,173,60,224,61,57,147,17,56,69,237,27,130,29,18,227,87,92,105,216,121,189,170],
    hist = [27,27,3,250], k = [1,1,1,1,1,2,3,1,2,3,1,2,3,1,2,3,1,2,2,1,1,1,2,3,1,2,3,1,2,3,1,2,3,1,2,2,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,3,3],
    obj = "3fea02df73920ea8 3fe1a33fb8617c8e 3fe0aac390ff4a03 3fe048fc1a6b0c8d 3fe04464f5795372 3fe0441071fd225d 3fe0440815e1c40c 3fe04407e938055f 3fe04407e002a797 3fe04407df1e78ab 3fe04407df19536c 3fe04407df185be6 3fe04407df184055 3fe04407df183fdd 3fe04407df183fbc 3fe04407df183fb9 3fe04407df183fb9 3fe04407df183fb9 3fe04407df183fba 3fe0255e326320bb 3fe0200f76cda01b 3fe01f65da7d3c46 3fe01f54f320ea87 3fe01f5319ab8638 3fe01f52f1a1c3d3 3fe01f52ef465e66 3fe01f52eefc3305 3fe01f52eef9683d 3fe01f52eef885a3 3fe01f52eef872d6 3fe01f52eef8724a 3fe01f52eef8721b 3fe01f52eef87217 3fe01f52eef87218 3fe01f52eef87217 3fe01f52eef87217 3fe01f5267c365db 3fe01f524742dc0d 3fe01f523dbfb063 3fe01f523c5a8180 3fe01f523c51ef64 3fe01f523c48d69f 3fe01f523c46a65a 3fe01f523c465ab5 3fe01f523c465b8a 3fe01f523c4659a6 3fe01f523c46592b 3fe01f523c46591a 3fe01f523c46591b 3fe01f523c46591a 3fe01f523c465919 3fe01f523c465919 3fe01f523c465918",
    xi = [3,17,18,27,29,56,57,60,61,69,87,92,105,121,130,147,170,173,189,192,200,201,202,216,224,227,237], xv = "3ff8e220ea5fb382 bfed4ddae83c5dae 3faba85337c9e2d0 3fb1b4084e03ac54 3fb70a0478d7dcee bf7139841c76bf80 3f9925cc158b7df0 3fe2bc8e87cd78e0 3fd54e1c7e20f560 3fa2d71242bb9284 3f74626d61d79a40 bf9086228fd35c00 bf822f711694d3c0 3fb0130b030ae108 bff106543ca46ec1 3fb3c10d60c92d82 3f5d0e68d3e77e00 bf59903df06fa600 3fa5315801f51dcc 3fa8e7f491bd8d4c 3ff2144a98516334 bfe22125abc2f66e 3fe4037ef40160d6 bf9ed834f92fbff0 3fa426f3dc3a8db0 3fbfd54eed625814 3f9815536da09a40",
    xcur = "3fe4037ef4583330 3ff8e220ea58b5ea bfe22125ab7a15ec 3ff2144a9847f50e 3fa8e7f485e44cdc bf59903bd08e0100 3fe2bc8e87c231f7 3fa426f3debcd6ec 3fd54e1c7ea9e164 3f9925cc0f0c4190 3fb3c10d627bf4de bfed4ddae7e3673e bf713983a7373d00 3fa2d71243046cb0 3f98155372081a28 3fb1b4084f8e3510 bff106543c87a6e5 3fb70a047bc6e9d2 3faba8533b32fbec 3fbfd54ef246c270 3f74626dcb2ace60 bf90862284b64488 bf822f7126bc3e30 bf9ed834fea136a8 3fb0130afdf0c6fe 3fa5315809c75c7c 3f5d0e6a13cabc00",
    xprev = "3fe4037ef4b985ae 3ff8e220ea41f96e bfe22125aacfe204 3ff2144a983fca56 3fa8e7f46d206600 bf59903711b9a080 3fe2bc8e87a3d7b5 3fa426f3e95d345c 3fd54e1c7fcb6810 3f9925cbfa2bd4d0 3fb3c10d66e34c7e bfed4ddae76027be bf71398294453480 3fa2d71242f9fa7c 3f981553815f1640 3fb1b4085458e5b2 bff106543c511992 3fb70a04832a8bde 3faba853420cf7b8 3fbfd54efd257188 3f74626ea56a2040 bf908622686f5388 bf822f7142de11f0 bf9ed83508d263b0 3fb0130af2d50d68 3fa531581c012d1c 3f5d0e6cf117a100",
    y = "3fe4037ef4314564 3ff8e220ea61ce1c bfe22125abbe2aaf 3ff2144a984b3958 3fa8e7f48fcc42ce bf59903db67c8e00 3fe2bc8e87ce5611 3fa426f3da7cb18c 3fd54e1c7e3611ec 3f9925cc176606aa 3fb3c10d60b90504 bfed4ddae817e70b bf7139841531a6cd 3fa2d71243089a5e 3f9815536be54eeb 3fb1b4084da38802 bff106543c9d7906 3fb70a0478d2429a 3faba85338756401 3fbfd54eededaf9a 3f74626d73de473a bf9086229005d822 bf822f711b7b8316 bf9ed834fa8d8b0b 3fb0130b0262446d 3fa53158027d0909 3f5d0e68ee78c6cd"),
  "f64/gl2_contig" => (passes = 25, nactive = 7, active = [1,41,40,4,13,26,12],
    hist = [35,7,3,250], k = [1,1,1,1,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,3,3],
    obj = "3ff2b250f2245988 3ff07e2524134818 3ff04b09cd71ef62 3ff03e8de78b4228 3ff03c5041120146 3ff03bd4ba003320 3ff03bb17cf93547 3ff03baa996b196e 3ff03ba9fdc53b13 3ff03ba9f0d92450 3ff03ba9edf4ce42 3ff03ba9eda0e892 3ff03ba9eda15c22 3ff03ba9ed9f1a16 3ff03ba9ed9e9cd5 3ff03ba9ed9e8fdd 3ff03ba9ed9e9022 3ff03ba9ed9e8fbe 3ff03ba9ed9e8fa9 3ff03ba9ed9e8fa7 3ff03ba9ed9e8fa7 3ff03ba9ed9e8fa7 3ff03ba9ed9e8fa7 3ff03ba9ed9e8fa6 3ff03ba9ed9e8fa6",
    xi = [1,2,3,4,5,16,17,18,19,20,56,57,58,59,60,61,62,63,64,65,126,127,128,129,130,196,197,198,199,200,201,202,203,204,205], xv = "3f9564b43d632316 bfb38eb6907b6f9c 3ff451a35d611d68 bfb47a3586ae7a00 3fbc91bfb1f61ae4 3f80b5024a3c5208 bfe3b8b3db848357 3fbdde679c2cf98e bfb2d79168033414 bf92c11e5c2d28f4 bfb5282a8ad48ad5 3fb741f092794483 3f89a56013248849 bf90da7ab436973e 3fd23c4caf5bda05 3fc492f4657ee596 bf91db7aeedf408e 3f830f7de970006c 3f8a717d5c98df24 3f6837dfa9e447eb 3fb951d04ebca67f bfb00a1915e5c4a1 bfb97f1911ec3322 3fa2e4faf5542fb0 bfe9b694f7ca1f73 3fb56ac4e24bda52 bfc5ea2c68128f53 bf990eb225190251 3fb2ec47882303b2 3fec681ebd30e7b9 bfe0e0f154900871 3fe18ceaca470411 3fa55d1966eda00f 3fadbbbb1859044b 3fc94bc667d44176",
    xcur = "3f9564b43c285af3 bfb38eb6906ef220 3ff451a35d47eb06 bfb47a35875b10c9 3fbc91bfb3e4b6ef bfe0e0f1547877a5 3fe18ceaca01b9fd 3fa55d19657a57e7 3fadbbbb19b1c1fe 3fc94bc66920a8e6 3fb56ac4e0f28b55 bfc5ea2c6892aa73 bf990eb222ac1bb1 3fb2ec47899454fb 3fec681ebcd6b1a4 3f80b50246eb277e bfe3b8b3db6ca801 3fbdde679b716495 bfb2d7916833111a bf92c11e5cf6067d 3fc492f46640d7bb bf91db7aef359957 3f830f7de9bb34bd 3f8a717d5f5d5b66 3f6837dfaf67e5cf 3fb951d04f9f41c8 bfb00a191712e672 bfb97f19125523be 3fa2e4faf6da5e14 bfe9b694f7da10b4 bfb5282a8a97bc20 3fb741f092508afc 3f89a560120d85b1 bf90da7ab5055bc3 3fd23c4caf7f2efc",
    xprev = "3f9564b43818e1d5 bfb38eb690add041 3ff451a35d09184f bfb47a358974a2b6 3fbc91bfb8904742 bfe0e0f15422dcf6 3fe18ceac949c595 3fa55d1961838d18 3fadbbbb1d52450a 3fc94bc66beb0c51 3fb56ac4ddd551f9 bfc5ea2c69ddc218 bf990eb21f1066d8 3fb2ec478ca52e7a 3fec681ebbfe88dc 3f80b5024267a0ce bfe3b8b3db4e8d57 3fbdde6799f739dc bfb2d79167a5f358 bf92c11e605ea0f3 3fc492f4686c6715 bf91db7af07bbd78 3f830f7deb19d91f 3f8a717d66696e01 3f6837dfbf08e6a4 3fb951d051bff551 bfb00a19195b84a2 bfb97f1912e52c45 3fa2e4faf9a26f2b bfe9b694f7f245b9 bfb5282a8a1ad31c 3fb741f091d0a941 3f89a560101f7e46 bf90da7ab6d6beca 3fd23c4cafbed4dc",
    y = "3f9564b43dc824ff bfb38eb69055cc79 3ff451a35d610c1c bfb47a358684099d 3fbc91bfb2067d34 bfe0e0f1549ab585 3fe18ceaca4b4ef3 3fa55d19671042a0 3fadbbbb183e5a60 3fc94bc66802e788 3fb56ac4e2316f13 bfc5ea2c680e3a97 bf990eb2241d973b 3fb2ec47885a6462 3fec681ebd2d285a 3f80b50248b95d5e bfe3b8b3db78b2ab 3fbdde679c08a8df bfb2d791686b8368 bf92c11e5b98fbe7 3fc492f465629e64 bf91db7aeeb3247d 3f830f7de92ef2fc 3f8a717d5c8bba5b 3f6837dfa9277f13 3fb951d04ec5605e bfb00a1916290d92 bfb97f19121b86bb 3fa2e4faf5bd8a71 bfe9b694f7d061e5 bfb5282a8ac9b2ee 3fb741f09283b214 3f89a56012d32242 bf90da7ab44b3427 3fd23c4caf65b96f"),
  "f64/gl2_strided" => (passes = 25, nactive = 10, active = [1,2,3,50,30,42,27,10,11,17],
    hist = [50,10,3,250], k = [1,1,1,2,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,3,3],
    obj = "3ff35adac22cc21c 3ff15ac72f50125e 3ff106ecde87ea16 3ff0f5396b7f7730 3ff0f1557e18055c 3ff0f0d6069058e2 3ff0f0ad9b456054 3ff0f0a4daac45d8 3ff0f0a40fb25926 3ff0f0a3f8e59619 3ff0f0a3f277fb68 3ff0f0a3f176dcb6 3ff0f0a3f1724dc2 3ff0f0a3f16e90f5 3ff0f0a3f16d9015 3ff0f0a3f16d6b9c 3ff0f0a3f16d6bb4 3ff0f0a3f16d6b12 3ff0f0a3f16d6ae6 3ff0f0a3f16d6ae0 3ff0f0a3f16d6ae0 3ff0f0a3f16d6ae1 3ff0f0a3f16d6ae0 3ff0f0a3f16d6ae2 3ff0f0a3f16d6ae2",
    xi = [1,2,3,10,11,17,27,30,42,50,51,52,53,60,61,67,77,80,92,100,101,102,103,110,111,117,127,130,142,150,151,152,153,160,161,167,177,180,192,200,201,202,203,210,211,217,227,230,242,250], xv = "3f7f550647e7b1ce bfad7c4c7f79c28e 3ff4d90e9a4e98ee 3fb66f01fb674eda bfaa6272ce75df8b bfe52119db120457 3f8396be954d6294 3f99333b092da16a bf932cfe59b33cf1 3fcdbdee1083f599 bf919f8dcc6198e4 bfa667335aa704e2 bfbc214f64f965e1 3fcfa6224ca0f5fc 3fc940d722cf2bff 3f9b559418ca20ae 3f7452f7a3af4e40 3f9fe1e72c174937 bfa5d805ffb80acb bfa37ed2ff332378 bf95a9087cbba266 3fb8e91dade59b8c bfaa5b7968e86ae5 3f67dc9600fda4f9 3f8223adde49b791 3f8481cd61f69eff bf8014741281776a bfe8e5189c2e9b05 3f9c0659119e448f 3faaacc9b34e0642 3fb2bd5890b02d1e bfaff1892142c8b2 bfa4f4aa61b6caef bf72b7d778a1feaa 3fa51e529b4c8366 3fbe0e031ec64792 bf6e832c04d4946d bfbc867aa70e49c1 3fa4eab1c4063737 3fecaee7f9e8741b bfd54b5f743aaa1a 3fdb31c19ee70aaf 3fb0bb5061aa9015 bf28f93ec3b04939 bfabcb1102825da4 3f73512c2f4d942c 3f91d45405164227 bfacd7599e132cd6 3f75c2e5e86d9e11 bfbd47b99f6dae16",
    xcur = "3f7f55063e261a65 bf919f8dd33cc5a6 bf95a90879c26fdc 3fb2bd5891bf95e2 bfd54b5f74e17eb4 bfad7c4c821ef180 bfa667335d5f13d6 3fb8e91dadc6c4cb bfaff1892629aadd 3fdb31c19fd4cc91 3ff4d90e99da3ebb bfbc214f6546279f bfaa5b79670d810f bfa4f4aa62b1ccdd 3fb0bb505fece118 3fcdbdee103aa2c2 bfa37ed2fc406b3b 3faaacc9b28aa3e8 3fecaee7f9666764 bfbd47b9a0264ad5 3f99333b11e9f6e1 3f9fe1e729b520c6 bfe8e5189c4730c2 bfbc867aa6d03546 bfacd7599f2e834d bf932cfe5a484513 bfa5d806000b3b83 3f9c0659118b696b 3fa4eab1c40b447f 3f75c2e5ec2560a6 3f8396be959ae2a9 3f7452f7a29efcb5 bf801474122880fa bf6e832c045deaa8 3f91d45404dbe803 3fb66f01fcbe3ec4 3fcfa6224d2785dd 3f67dc960bebf86a bf72b7d773944399 bf28f93e4a5ee1ce bfaa6272cdc436ac 3fc940d72326beb5 3f8223add964b3dc 3fa51e529bb027b0 bfabcb1101c4d73b bfe52119db0767d0 3f9b5594138e434f 3f8481cd6032fcb3 3fbe0e031f05211d 3f73512c2d9fa06b",
    xprev = "3f7f550624ba2c68 bf919f8de085d1e9 bf95a90873406334 3fb2bd5893b431de bfd54b5f75f79172 bfad7c4c869a2731 bfa6673362d16e8f 3fb8e91dadc30b73 bfaff1892f345969 3fdb31c1a193b70c 3ff4d90e98e71501 bfbc214f66c1ea61 bfaa5b79648ee2c7 bfa4f4aa634d91c9 3fb0bb505d3e001b 3fcdbdee0fe50031 bfa37ed2f704e43d 3faaacc9b0e66586 3fecaee7f865883e bfbd47b9a18b9ead 3f99333b2470f315 3f9fe1e7255f7143 bfe8e5189c69fae6 bfbc867aa67d4e52 bfacd759a21ac5de bf932cfe5bdf40fe bfa5d806011b79c4 3f9c065911c3c332 3fa4eab1c461d8db 3f75c2e5f485624a 3f8396be96755fdb 3f7452f7a0fb6fea bf80147411ba35af bf6e832c03b22fb7 3f91d45404a4220f 3fb66f01ff6d5d77 3fcfa6224e2bb3b4 3f67dc962708f709 bf72b7d768625b5c bf28f93d587c0ba0 bfaa6272ccc9e363 3fc940d72424105e 3f8223adcf4db472 3fa51e529d14fd83 bfabcb1100882f43 bfe52119daeb4641 3f9b5594093ef2a9 3f8481cd5e47373a 3fbe0e031f5435d2 3f73512c2b841b40",
    y = "3f7f550648514664 bf919f8dcdec5a58 bf95a9087c5cdb52 3fb2bd5890f7577d bfd54b5f74724402 bfad7c4c80540f39 bfa667335b3155f2 3fb8e91dadc84221 bfaff189228bcb72 3fdb31c19f220860 3ff4d90e9a3b829f bfbc214f64ae401e bfaa5b79680cf392 bfa4f4aa62737e18 3fb0bb5060ffa17d 3fcdbdee105ce3c9 bfa37ed2fe583ad4 3faaacc9b332bcdc 3fecaee7f9cd270d bfbd47b99f975c7f 3f99333b0a80c533 3f9fe1e72b710094 bfe8e5189c39464d bfbc867aa6f15e74 bfacd7599e033579 bf932cfe59a579e8 bfa5d805ff9e55cf 3f9c06591174df1b 3fa4eab1c3e8a2c1 3f75c2e5e8cbc664 3f8396be95437d62 3f7452f7a346cea0 bf80147412549f18 bf6e832c04a29bd5 3f91d45404f23731 3fb66f01fbab65b0 3fcfa6224cbf7387 3f67dc9601139291 bf72b7d7780ea07e bf28f93eab200447 bfaa6272ce2857fc 3fc940d722c16ad8 3f8223addd6de6d3 3fa51e529b216bc2 bfabcb11024380d1 bfe52119db12a870 3f9b559417adfd2b 3f8481cd60f7b217 3fbe0e031ee57f3b 3f73512c2e776f49"),
  "f64/gl2_vecperm" => (passes = 25, nactive = 8, active = [17,46,40,5,28,15,21,20],
    hist = [40,8,3,250], k = [1,1,1,1,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,3,3],
    obj = "3ff56b9b543d442e 3ff24f8ff4f584a6 3ff1bfa85fae3423 3ff18e825235381f 3ff182776c2712d5 3ff180a0b8a32427 3ff180499cf72bc6 3ff180408b4c9223 3ff1804084d30062 3ff180404e002803 3ff18040423114d4 3ff1804040dc5c7b 3ff1804040df46f6 3ff1804040d70320 3ff1804040d52af4 3ff1804040d4f652 3ff1804040d4f723 3ff1804040d4f5c7 3ff1804040d4f578 3ff1804040d4f570 3ff1804040d4f570 3ff1804040d4f56f 3ff1804040d4f570 3ff1804040d4f570 3ff1804040d4f570",
    xi = [3,8,17,20,22,28,29,39,44,53,60,61,63,64,69,70,76,78,86,91,101,116,118,124,128,130,148,151,160,183,185,186,200,201,202,207,218,221,223,238], xv = "3ff4734f9ae4219c bfbe0f5cb8ef77a8 bfe5fc591996c7a4 3f96267c7e28326a bfc22f8d2e7990a1 bfa59d381262d2d9 3fbd3ae14655a091 3fbc40619207da68 bfb9b437f4fd3ad1 bfaeea21a1b8d8a2 3fd35e8f7a2ef9b0 3fc93739c7d146ea 3fa4126507783014 3fb5424e40aabf1e 3fbc6604719711f7 bfa584c959e8a5e1 3fba26f8c860ee92 bfa43f7cf9be677b bfaa0af92f7a652f 3fb424c687372548 bfae24d0d4a81f1a bf53d7aeee9f7b3a bfc189125ff62df6 3faf7ca8bb57513d bfa48556c8658874 bfe5eef0a5ad3df8 bfb6594e39864b25 3fc55b4618b82b5e bf8362a565f57adb 3f91ac5ad9028e2e bf997d3c9771288e bfbfb57b29bff3f8 3fed74e4c41189e3 bfd130d460d8aa43 3fda5048ec59b363 bfa0379251a5ed51 bf909688d03aaa3a bfa281ee70edce13 3f8956c6cdc16934 bfb04a7e01205818",
    xcur = "bfa281ee6f9fc7bf bfaeea21a151c3ed bfb04a7dffcd02b6 bfa037924eccf65c bfd130d46060fe55 bfaa0af92d4dce41 bfc22f8d2e8fc31a bfbe0f5cb6cb3b63 3fb5424e419d2a51 bfe5eef0a56bdea9 bfa43f7cfe6df49d 3fa4126503d9d5ac 3fc55b461b56ac91 3ff4734f9a5acdb3 bfbfb57b295d3c40 3fbc406191c5ea26 bfa48556c669180c bf909688d65a52bb bf8362a567bdd323 bfe5fc59195c83d1 bfae24d0d538bcde 3fba26f8c7d13035 3fbd3ae1467f73d2 3fd35e8f7ae1a614 bfa59d38118b4a1c bfb6594e399c8097 3fb424c687ddfc9e bfb9b437f6b15db3 3fda5048ec946731 3f8956c6cf248019 3f91ac5ad930e1c9 bfa584c95aaa84d4 3faf7ca8be744167 bfc18912611561ef 3fed74e4c3cad31a 3fbc6604738cda1f bf53d7af1fba7076 3fc93739c92fa90d bf997d3c961a3bae 3f96267c80a719ad",
    xprev = "bfa281ee6d5df1e0 bfaeea21a2392e0e bfb04a7dfd580be6 bfa03792474ee39b bfd130d45f5a83f5 bfaa0af9290db8b4 bfc22f8d2eb719f0 bfbe0f5cb293e3bb 3fb5424e433f9cce bfe5eef0a48c5589 bfa43f7d0b318c9b 3fa41264fd112529 3fc55b46213f15d0 3ff4734f992e20a6 bfbfb57b29b9e1af 3fbc4061925753dd bfa48556c0043016 bf909688e3615e6d bf8362a56d1dbc8a bfe5fc5918f8b29e bfae24d0d6882d6e 3fba26f8c6b84636 3fbd3ae14728e620 3fd35e8f7c9d5ebd bfa59d380fc5a709 bfb6594e39d1bb2a 3fb424c688fbb661 bfb9b437f9ea17ff 3fda5048ecc3dbaa 3f8956c6d44debb7 3f91ac5ad68e88bd bfa584c95ded1570 3faf7ca8c5005b68 bfc1891263aba9c2 3fed74e4c33874b0 3fbc660478247c7c bf53d7af92616c8c 3fc93739cc4d1085 bf997d3c93079464 3f96267c86fae1fb",
    y = "bfa281ee7086ea18 bfaeea21a0f53313 bfb04a7e00c898a3 bfa0379251cc3110 bfd130d460c9fc15 bfaa0af92f010a13 bfc22f8d2e8006c4 bfbe0f5cb87af80d 3fb5424e40f5c952 bfe5eef0a5c548b6 bfa43f7cf952eb04 3fa41265069082ad 3fc55b4618f9b5ab 3ff4734f9ad312eb bfbfb57b29382d47 3fbc4061918bbfdd bfa48556c8f7db3b bf909688d1244e0d bf8362a5659775c7 bfe5fc5919847119 bfae24d0d4b28fd8 3fba26f8c8418dce 3fbd3ae1463bac80 3fd35e8f7a302904 bfa59d381240be8a bfb6594e398735f6 3fb424c6876bb250 bfb9b437f5677995 3fda5048ec816bcd 3f8956c6cd13eea7 3f91ac5ada3e9f01 bfa584c9595cb162 3faf7ca8bbd5d09a bfc18912600c7867 3fed74e4c4055f44 3fbc660471b6992d bf53d7aef1de0ba0 3fc93739c7f0b2dd bf997d3c9754e4ff 3f96267c7e1f2ff4"),
  "f64/sgl_contig" => (passes = 22, nactive = 7, active = [1,41,40,4,26,13,12],
    hist = [35,7,3,250], k = [1,1,1,1,2,3,1,2,3,1,2,3,4,1,2,3,4,1,2,3,3,3],
    obj = "3ff076d9db81cf85 3feba71527f46f6f 3feb08e351d2bfe3 3feae4b6dd167c94 3feae09641cb5570 3feadfdc31de0ee2 3feadfcaa5488c4e 3feadfca1aec573e 3feadfca036efda9 3feadfca0149cae0 3feadfca0140905d 3feadfca013e763b 3feadfca013e224c 3feadfca013e2007 3feadfca013e1ed6 3feadfca013e1e85 3feadfca013e1e78 3feadfca013e1e78 3feadfca013e1e78 3feadfca013e1e79 3feadfca013e1e78 3feadfca013e1e78",
    xi = [3,4,17,18,19,56,57,60,61,126,130,196,197,200,201,202,205], xv = "3ff691c0e956d4a8 bf93b6a81e582ec1 bfe849c5605e4573 3fbf55721f88848c bf89e948585ca9a4 bfb657b9b123b533 3fb74b9e349a16aa 3fdb5e555dae66d5 3fd0943ea31ddd0a 3f917af598629923 bfed11f22bfa21df 3f8fe1f89b2e229a bf9ce81f9152e7d1 3fef24c351516cc6 bfe268f95b19b42c 3fe26268fb7ecafa 3fbc87e834d5e3a7",
    xcur = "0 0 3ff691c0e9650104 bf93b6a82b9a3f99 0 bfe268f95b9d3515 3fe26268fb6b330c 0 0 3fbc87e83963b81c 3f8fe1f879512a95 bf9ce81f964397a0 0 0 3fef24c3515c9214 0 bfe849c55fa8fe1a 3fbf5572210aac1b bf89e948678f512c 0 3f917af5928c5a91 0 0 0 bfed11f22ba41661 3fd0943ea33a3a1e 0 0 0 0 bfb657b9b12be943 3fb74b9e3579be48 0 0 3fdb5e555e00a37d",
    xprev = "0 0 3ff691c0e975a6a3 bf93b6a8417df78d 0 bfe268f95c49460f 3fe26268fb6d4451 0 0 3fbc87e842252667 3f8fe1f8368d36d1 bf9ce81fa2f27eaa 0 0 3fef24c35144c6a7 0 bfe849c55e376d65 3fbf557223e846f3 bf89e9488880636e 0 3f917af58c65469d 0 0 0 bfed11f22b009821 3fd0943ea3cd352e 0 0 0 0 bfb657b9b14fe2c2 3fb74b9e36d56914 0 0 3fdb5e555e813aea",
    y = "0 0 3ff691c0e95e585e bf93b6a822d8c2d1 0 bfe268f95b58617e 3fe26268fb6a5f57 0 0 3fbc87e835e32598 3f8fe1f89405f27d bf9ce81f9130d4cf 0 0 3fef24c3516616a6 0 bfe849c5603cd196 3fbf55721fe53af8 bf89e9485a6216ab 0 3f917af59502628c 0 0 0 bfed11f22be57c14 3fd0943ea2ff6f4b 0 0 0 0 bfb657b9b11d8577 3fb74b9e34eead2a 0 0 3fdb5e555dcd33b8"),
  "f64/sgl_strided" => (passes = 45, nactive = 10, active = [1,2,3,50,27,17,30,11,10,42],
    hist = [50,10,3,250], k = [1,1,1,2,3,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4,1,2,2,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,3,3],
    obj = "3ff0ea285e8a7bd9 3feccdd51d9952e2 3febe6adeab42a8c 3febba6ce5494c52 3febb21cd715597b 3febb15df9b8f7ed 3febb150ce839bbf 3febb14e860efe26 3febb14e38f54664 3febb14e3875fbaa 3febb14e37450a26 3febb14e36f4cf77 3febb14e36e91138 3febb14e36e90176 3febb14e36e8d471 3febb14e36e8c862 3febb14e36e8c6a0 3febb14e36e8c69e 3febb14e36e8c698 3febb14e36e8c696 3febb14e36e8c695 3febb14e36e8c695 3febb14e36e8c695 3febb14e36e8c692 3febb0cde736cdfe 3febb0a1a121a392 3febb09121d21b29 3febb08d599ef7e6 3febb08d0dff3582 3febb08d09f8ec1e 3febb08d08bd0144 3febb08d087e9af0 3febb08d0879ecee 3febb08d0879643a 3febb08d08794295 3febb08d08793db2 3febb08d08793d77 3febb08d08793d5f 3febb08d08793d5a 3febb08d08793d58 3febb08d08793d58 3febb08d08793d59 3febb08d08793d59 3febb08d08793d58 3febb08d08793d58",
    xi = [3,10,11,17,27,50,60,61,92,102,127,130,142,151,152,161,167,180,192,200,201,202,227], xv = "3ff6cac5b9cd62cf 3faf1791e8b905d7 bf84b498414fdc9e bfe99052dcf5e32d 3f97004fa5460416 3fb89da402d5d71b 3fda62ac4bdbff63 3fd0f05172f46eba bf92dec79e6a4cee 3fa40b1c99432995 bf482d124483b731 bfed181b62b5f6f7 3f7e75c4314a7d11 3f8489c7e56ccb36 bf9e18208dbbeaf4 3f93abb4343b319b 3fab3467b22cd8d1 bfa4168425595eec 3f94f8d87b9b8672 3fef77ed551bb031 bfdd942b9676b974 3fe0f709a6a94422 3fa784ebeb9f7116",
    xcur = "0 0 0 3f8489c7e4bfd488 bfdd942b967306c8 0 0 3fa40b1c9bd26ac0 bf9e182092e8b442 3fe0f709a6c0a81a 3ff6cac5b9c1a43b 0 0 0 0 3fb89da402f920ac 0 0 3fef77ed55247a13 0 3f97004fa4bfd8d2 0 bf482d1240d963b4 0 3fa784ebeb038bfe bfe99052dd0fb04c 0 0 3fab3467b398f8b1 0 0 0 bfed181b62bf6d28 bfa41684253aa13a 0 bf84b49840207ac1 3fd0f05172ccae05 0 3f93abb43298d6ab 0 3faf1791e92394e1 3fda62ac4bc63ad0 0 0 0 0 bf92dec79d15e750 3f7e75c42f2f4dd6 3f94f8d87a398093 0",
    xprev = "0 0 0 3f8489c7e258b885 bfdd942b96713b7d 0 0 3fa40b1ca12a9756 bf9e18209e63a893 3fe0f709a6f5173a 3ff6cac5b9a16462 0 0 0 0 3fb89da403d4e884 0 0 3fef77ed5534f7b3 0 3f97004fa35eb20b 0 bf482d1238043185 0 3fa784ebe988f9cb bfe99052dd47a7ca 0 0 3fab3467b728c3a9 0 0 0 bfed181b62dc3f24 bfa41684257df38c 0 bf84b4983cd09af7 3fd0f051725c7f2e 0 3f93abb42e77355e 0 3faf1791e9f92b9c 3fda62ac4b848967 0 0 0 0 bf92dec79b673c87 3f7e75c42c9f5d27 3f94f8d8789d4432 0",
    y = "0 0 0 3f8489c7e5b5dfbc bfdd942b9673be80 0 0 3fa40b1c99af25b7 bf9e18208e511f55 3fe0f709a6abaeda 3ff6cac5b9ce8a92 0 0 0 0 3fb89da402a13722 0 0 3fef77ed551de16d 0 3f97004fa54d1b88 0 bf482d124461de2d 0 3fa784ebeb9af9ac bfe99052dcf94d4d 0 0 3fab3467b22c411b 0 0 0 bfed181b62b3e5f6 bfa41684251fb380 0 bf84b4984173a112 3fd0f05172f98d8e 0 3f93abb4343fe3fd 0 3faf1791e8ce2563 3fda62ac4be081c7 0 0 0 0 bf92dec79dc22ba0 3f7e75c43035ae1c 3f94f8d87ade6587 0"),
  "f64/sgl_vecperm" => (passes = 41, nactive = 9, active = [20,17,46,40,5,21,15,28,38],
    hist = [45,9,2,250], k = [1,1,1,2,1,2,3,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,3,1,2,3,1,2,3,1,2,3,4,1,2,3,4,1,2,2,2],
    obj = "3ff344feeff959e8 3fef50678013e140 3feda6c7c91ecd02 3fed1ce80a9425b8 3fecf25f1d96197f 3fecef93f2ab096f 3feceefda7812876 3feceeef83a32b73 3feceeef47c8f24a 3feceeef3d88b43e 3feceeef3c4425b4 3feceeef3c44094c 3feceeef3c3d834a 3feceeef3c3be4dd 3feceeef3c3bae33 3feceeef3c3bae9e 3feceeef3c3bad8b 3feceeef3c3bad46 3feceeef3c3bad3e 3feceeef3c3bad3e 3feceeef3c3bad3d 3feceeef3c3bad3e 3feceeef3c3bad3e 3fecee408c5e8cf5 3fecee2e841d9ad2 3fecee2ca8cc51cd 3fecee2c81beefd0 3fecee2c7eba606e 3fecee2c7e557678 3fecee2c7e4c6cbe 3fecee2c7e4bf035 3fecee2c7e4bda48 3fecee2c7e4bd786 3fecee2c7e4bd771 3fecee2c7e4bd768 3fecee2c7e4bd765 3fecee2c7e4bd764 3fecee2c7e4bd765 3fecee2c7e4bd765 3fecee2c7e4bd766 3fecee2c7e4bd766",
    xi = [3,17,22,29,39,44,60,61,69,76,91,118,130,151,186,200,201,202,207,227,238], xv = "3ff6ce6d2ad637da bfe9582cc39eb370 bfac643e53a2cbb3 3fb70bce60274aba 3f9953eeb25ab7ce bfa4588bb1908aef 3fdadc62395905a6 3fd1b0e538742f4c 3fb8d8ecdf05a586 3fa2308c9f5843a5 3fa11d7f2c145265 bf5665884125f80f bfeb8a06ede37a84 3f9cd139b923b51b bf9761e9ce48d8fc 3fefee74d0a41ece bfdb00f093de9590 3fe07ae4d41ef541 bf8b3d4f706231ff 3f98247a6801dc5a bfa2f0aed0618a66",
    xcur = "3fb8d8ecddc7788d 0 3fd1b0e5382aec00 0 0 0 0 bfa2f0aed04a27ad bf8b3d4f66fda49e bfdb00f0943cdfbd 0 bfac643e54e7e6d0 0 0 bfeb8a06edd5be8d 0 0 3f9cd139b8042cfb 3ff6ce6d2ad61650 bf9761e9cac7a55e 3f9953eeb32b7450 0 0 0 bfe9582cc3ab2672 0 0 0 bf566588d0520822 3fefee74d097edfb 0 3fa11d7f2c2fe6aa bfa4588bb3052868 3fe07ae4d42c05e1 0 0 3fa2308ca045fd22 3fb70bce602864c1 3fdadc623924e78a 0 0 0 0 0 3f98247a66c53215",
    xprev = "3fb8d8ecdc1d1199 0 3fd1b0e537c4186b 0 0 0 0 bfa2f0aed1208224 bf8b3d4f5d88b225 bfdb00f094c6048c 0 bfac643e562244bf 0 0 bfeb8a06edc399c4 0 0 3f9cd139b5fc1822 3ff6ce6d2ad51088 bf9761e9c7cc0711 3f9953eeb49560ba 0 0 0 bfe9582cc3b65782 0 0 0 bf56658986793e53 3fefee74d0889556 0 3fa11d7f2bad254b bfa4588bb540e05d 3fe07ae4d4454bdd 0 0 3fa2308ca10da907 3fb70bce603979fc 3fdadc6238ecaf0b 0 0 0 0 0 3f98247a64c8d7cb",
    y = "3fb8d8ecde32124a 0 3fd1b0e53844a0e5 0 0 0 0 bfa2f0aed014910f bf8b3d4f695ae13c bfdb00f0941a9689 0 bfac643e54994f54 0 0 bfeb8a06edda47bf 0 0 3f9cd139b8863231 3ff6ce6d2ad657c2 bf9761e9cb868cf1 3f9953eeb2d0f936 0 0 0 bfe9582cc3a85a2e 0 0 0 bf566588a2c83a96 3fefee74d09bc424 0 3fa11d7f2c509702 bfa4588bb2763a6b 3fe07ae4d425b462 0 0 3fa2308ca0141229 3fb70bce60241f72 3fdadc623932f5aa 0 0 0 0 0 3f98247a674448a8"),
  "f32/sparse_lasso" => (passes = 23, nactive = 27, active = [202,3,201,200,192,173,60,224,61,57,147,17,56,69,237,27,130,29,18,227,87,92,105,216,121,189,170],
    hist = [27,27,3,250], k = [1,1,1,1,1,2,3,1,2,2,1,1,1,2,3,1,2,2,1,2,3,3,3],
    obj = "3fea02df20000000 3fe1a33fe0000000 3fe0aac3a0000000 3fe048fc40000000 3fe04464e0000000 3fe0441060000000 3fe0440820000000 3fe0440800000000 3fe04407e0000000 3fe04407c0000000 3fe0255e40000000 3fe0200f80000000 3fe01f65c0000000 3fe01f54e0000000 3fe01f5300000000 3fe01f52c0000000 3fe01f5300000000 3fe01f5300000000 3fe01f5240000000 3fe01f5240000000 3fe01f5240000000 3fe01f5240000000 3fe01f5200000000",
    xi = [3,17,18,27,29,56,57,60,61,69,87,92,105,121,130,147,170,173,189,192,200,201,202,216,224,227,237], xv = "3ff8e21ee0000000 bfed4de340000000 3faba79b80000000 3fb1b3ba00000000 3fb709f180000000 bf713ed800000000 3f99273c00000000 3fe2bc93c0000000 3fd54e0f80000000 3fa2d6a500000000 3f745c5400000000 bf90867300000000 bf822c8200000000 3fb0133340000000 bff1065400000000 3fb3c108c0000000 3f5d0a7000000000 bf59a10000000000 3fa530d800000000 3fa8e8d600000000 3ff2144900000000 bfe2213400000000 3fe4037960000000 bf9ed80700000000 3fa426c880000000 3fbfd51780000000 3f98154900000000",
    xcur = "3fe40392e0000000 3ff8e23780000000 bfe2212ec0000000 3ff2146ca0000000 3fa8eec180000000 bf5adb4000000000 3fe2bc88c0000000 3fa424c700000000 3fd54de980000000 3f992bc500000000 3fb3c0a9c0000000 bfed4dfd80000000 bf718f4c00000000 3fa2d53200000000 3f98105b00000000 3fb1b2ea00000000 bff1066d40000000 3fb7079b00000000 3faba63f00000000 3fbfd12e80000000 3f74170000000000 bf908fda00000000 bf822be800000000 bf9ed4cb00000000 3fb0169d80000000 3fa52c1880000000 3f5beda000000000",
    xprev = "3fe4038b60000000 3ff8e2a1e0000000 bfe2207c00000000 3ff214c320000000 3fa8f02e00000000 bf5cbc8000000000 3fe2bc6ee0000000 3fa4235380000000 3fd54d1fc0000000 3f99323400000000 3fb3bc3e40000000 bfed4dce00000000 bf71ffc400000000 3fa2d7d280000000 3f97fb8d00000000 3fb1b46900000000 bff1068b80000000 3fb703a880000000 3faba30780000000 3fbfcae500000000 3f7399dc00000000 bf90a96200000000 bf8241fc00000000 bf9ed19f00000000 3fb01e6bc0000000 3fa5273c00000000 3f59646000000000",
    y = "3fe40395e0000000 3ff8e20d00000000 bfe2217640000000 3ff2144a00000000 3fa8ee2fc0000000 bf5a1ac000000000 3fe2bc9320000000 3fa4255ba0000000 3fd54e3a40000000 3f99293240000000 3fb3c26e60000000 bfed4e1080000000 bf71624f40000000 3fa2d42500000000 3f9818ad60000000 3fb1b250c0000000 bff1066120000000 3fb7092f40000000 3faba78860000000 3fbfd3b240000000 3f74490e60000000 bf9085a3a0000000 bf82231340000000 bf9ed60fc0000000 3fb0137e40000000 3fa52e0a40000000 3f5cf15340000000"),
  "f32/gl2_contig" => (passes = 13, nactive = 7, active = [1,41,40,4,13,26,12],
    hist = [35,7,3,250], k = [1,1,1,1,1,2,3,4,1,2,3,3,3],
    obj = "3ff2b250e0000000 3ff07e2520000000 3ff04b09c0000000 3ff03e8dc0000000 3ff03c5040000000 3ff03bd4a0000000 3ff03bb180000000 3ff03baa80000000 3ff03baa00000000 3ff03baa00000000 3ff03ba9e0000000 3ff03ba9e0000000 3ff03ba9e0000000",
    xi = [1,2,3,4,5,16,17,18,19,20,56,57,58,59,60,61,62,63,64,65,126,127,128,129,130,196,197,198,199,200,201,202,203,204,205], xv = "3f95649ee0000000 bfb38edd80000000 3ff451a240000000 bfb47a1f00000000 3fbc91c6c0000000 3f80b5ca40000000 bfe3b8be40000000 3fbdde67e0000000 bfb2d75fe0000000 bf92c16ae0000000 bfb5282d20000000 3fb741e080000000 3f89a5aa20000000 bf90da6160000000 3fd23c4260000000 3fc492faa0000000 bf91db7e60000000 3f830f5ec0000000 3f8a719ba0000000 3f683852a0000000 3fb951e140000000 bfb009fb00000000 bfb97f1c00000000 3fa2e503c0000000 bfe9b69760000000 3fb56ad880000000 bfc5ea3060000000 bf990f2760000000 3fb2ec3e00000000 3fec682280000000 bfe0e0eae0000000 3fe18ceac0000000 3fa55d2460000000 3fadbbe3a0000000 3fc94bb260000000",
    xcur = "3f95661dc0000000 bfb38f1200000000 3ff451b420000000 bfb4790300000000 3fbc902080000000 bfe0e0e860000000 3fe18d1c60000000 3fa55ef760000000 3fadbc3200000000 3fc94a62e0000000 3fb56c0320000000 bfc5e9d900000000 bf9912fe80000000 3fb2eab6a0000000 3fec687720000000 3f80bb8540000000 bfe3b8f9c0000000 3fbddf2b00000000 bfb2d6d220000000 bf92c14c40000000 3fc4921ba0000000 bf91daf840000000 3f830ecea0000000 3f8a6fb3e0000000 3f68341de0000000 3fb9516ec0000000 bfb008d4c0000000 bfb97ef3a0000000 3fa2e4ac40000000 bfe9b6a500000000 bfb5285860000000 3fb741d580000000 3f89a70800000000 bf90d96a60000000 3fd23c1280000000",
    xprev = "3f956ad1c0000000 bfb38e2160000000 3ff451e4a0000000 bfb476ccc0000000 3fbc8c3c20000000 bfe0e11c00000000 3fe18d9da0000000 3fa5633e80000000 3fadbc2360000000 3fc9480a20000000 3fb56e5560000000 bfc5e8ed80000000 bf9918ab60000000 3fb2e74680000000 3fec6944c0000000 3f80c4b320000000 bfe3b95580000000 3fbde0fdc0000000 bfb2d6a420000000 bf92bf5300000000 3fc48fa9e0000000 bf91d94d00000000 3f830d5aa0000000 3f8a6a4460000000 3f682722e0000000 3fb9500780000000 bfb006a040000000 bfb97f03c0000000 3fa2e4ad60000000 bfe9b6d0a0000000 bfb528b6a0000000 3fb741f780000000 3f89a94620000000 bf90d79140000000 3fd23bc4c0000000",
    y = "3f95643c20000000 bfb38f7240000000 3ff451a0c0000000 bfb479e580000000 3fbc91af00000000 bfe0e0d3c0000000 3fe18ce8a0000000 3fa55d4160000000 3fadbc37e0000000 3fc94b5320000000 3fb56b1560000000 bfc5ea3740000000 bf9910b960000000 3fb2ec16a0000000 3fec6824e0000000 3f80b7d940000000 bfe3b8d500000000 3fbdde7040000000 bfb2d6e480000000 bf92c21660000000 3fc49315e0000000 bf91dba320000000 3f830f6360000000 3f8a71e080000000 3f68394f20000000 3fb951fe80000000 bfb009b680000000 bfb97eed20000000 3fa2e4abc0000000 bfe9b69380000000 bfb52832a0000000 3fb741c7e0000000 3f89a62260000000 bf90da27a0000000 3fd23c31a0000000"),
  "f32/gl2_strided" => (passes = 13, nactive = 10, active = [1,2,3,50,30,42,27,10,11,17],
    hist = [50,10,3,250], k = [1,1,1,2,1,2,3,4,1,2,3,3,3],
    obj = "3ff35ada80000000 3ff15ac740000000 3ff106ecc0000000 3ff0f53940000000 3ff0f15540000000 3ff0f0d5e0000000 3ff0f0ad80000000 3ff0f0a4a0000000 3ff0f0a3e0000000 3ff0f0a3c0000000 3ff0f0a3c0000000 3ff0f0a3e0000000 3ff0f0a3e0000000",
    xi = [1,2,3,10,11,17,27,30,42,50,51,52,53,60,61,67,77,80,92,100,101,102,103,110,111,117,127,130,142,150,151,152,153,160,161,167,177,180,192,200,201,202,203,210,211,217,227,230,242,250], xv = "3f7f54df80000000 bfad7c3ec0000000 3ff4d913c0000000 3fb66ef7c0000000 bfaa627780000000 bfe5211c80000000 3f83971620000000 3f99328320000000 bf932c94e0000000 3fcdbdf9e0000000 bf919e7fc0000000 bfa6677500000000 bfbc215980000000 3fcfa61fa0000000 3fc940cf40000000 3f9b55a2a0000000 3f745380c0000000 3f9fe1cf80000000 bfa5d78420000000 bfa37f40c0000000 bf95a96ae0000000 3fb8e962c0000000 bfaa5b1dc0000000 3f67dd5660000000 3f8223b000000000 3f84828fc0000000 bf8014d380000000 bfe8e51540000000 3f9c05ce20000000 3faaaca9c0000000 3fb2bd4140000000 bfaff17b00000000 bfa4f45640000000 bf72b80640000000 3fa51e5600000000 3fbe0e0280000000 bf6e83ea00000000 bfbc866e60000000 3fa4ea44c0000000 3fecaef8c0000000 bfd54b33a0000000 3fdb31cfe0000000 3fb0bb53c0000000 bf28e7ce40000000 bfabcaee80000000 3f735082c0000000 3f91d4b780000000 bfacd778a0000000 3f75c24700000000 bfbd473880000000",
    xcur = "3f7f5d8a00000000 bf919662e0000000 bf95adca80000000 3fb2bc33c0000000 bfd54a35e0000000 bfad7a6b40000000 bfa66713a0000000 3fb8ea87e0000000 bfafeec860000000 3fdb315ac0000000 3ff4d97a80000000 bfbc213c20000000 bfaa5a1b40000000 bfa4f38500000000 3fb0bc1a80000000 3fcdbe7580000000 bfa3832560000000 3faaacda20000000 3fecaf97a0000000 bfbd44a440000000 3f9929ec20000000 3f9fe40600000000 bfe8e50500000000 bfbc861740000000 bfacd6bce0000000 bf932a0b60000000 bfa5d4ab40000000 3f9c02d2c0000000 3fa4e7d0c0000000 3f75bcbb20000000 3f83981f00000000 3f7455afe0000000 bf801636c0000000 bf6e86fca0000000 3f91d60ea0000000 3fb66de6a0000000 3fcfa5b380000000 3f67d68300000000 bf72bc8d60000000 bf29212620000000 bfaa62f5c0000000 3fc94078e0000000 3f82277220000000 3fa51dfb60000000 bfabcb2500000000 bfe5213040000000 3f9b58cd80000000 3f84857040000000 3fbe0dffa0000000 3f734eb000000000",
    xprev = "3f7f7126e0000000 bf9189a200000000 bf95b66a80000000 3fb2ba6000000000 bfd548bd80000000 bfad773460000000 bfa665bb60000000 3fb8ec01e0000000 bfafea4aa0000000 3fdb302f00000000 3ff4da48c0000000 bfbc20c560000000 bfaa58c1a0000000 bfa4f44b00000000 3fb0bd1fc0000000 3fcdbf3f80000000 bfa38a7600000000 3faaae3920000000 3fecb0b360000000 bfbd40ec00000000 3f991836a0000000 3f9fe799e0000000 bfe8e4ec80000000 bfbc855580000000 bfacd41280000000 bf932550c0000000 bfa5cf9680000000 3f9bfdc260000000 3fa4e3b000000000 3f75b1ffe0000000 3f8399ce60000000 3f74594a80000000 bf8018b140000000 bf6e8bff60000000 3f91d86300000000 3fb66bdca0000000 3fcfa4f380000000 3f67bfb8c0000000 bf72c6c380000000 bf29a2e960000000 bfaa63cf00000000 3fc93f8d00000000 3f822f2220000000 3fa51cb5c0000000 bfabcbb3e0000000 bfe5215a40000000 3f9b6056a0000000 3f848a40c0000000 3fbe0e3c20000000 3f734bb1c0000000",
    y = "3f7f55b1a0000000 bf919b7ce0000000 bf95aa5740000000 3fb2bceee0000000 bfd54acc60000000 bfad7bb460000000 bfa6679d60000000 3fb8e9f0a0000000 bfaff09440000000 3fdb31d2a0000000 3ff4d92800000000 bfbc216ba0000000 bfaa5aa580000000 bfa4f335c0000000 3fb0bbb200000000 3fcdbe24c0000000 bfa3803860000000 3faaac4dc0000000 3fecaf2620000000 bfbd462120000000 3f99310180000000 3f9fe297a0000000 bfe8e50ec0000000 bfbc8664c0000000 bfacd7cde0000000 bf932befa0000000 bfa5d6b380000000 3f9c04d940000000 3fa4e97780000000 3f75c10600000000 3f83977280000000 3f74543ee0000000 bf80153900000000 bf6e84fb80000000 3f91d52020000000 3fb66eb760000000 3fcfa60040000000 3f67dfa0c0000000 bf72b877c0000000 bf28ed3e60000000 bfaa629ee0000000 3fc940d740000000 3f82245ee0000000 3fa51e7da0000000 bfabcaebe0000000 bfe5211f80000000 3f9b55c9e0000000 3f84838340000000 3fbe0de760000000 3f734fe280000000"),
  "f32/sgl_contig" => (passes = 11, nactive = 7, active = [1,41,40,4,26,13,12],
    hist = [35,7,3,250], k = [1,1,1,1,2,3,1,2,3,3,3],
    obj = "3ff076d9e0000000 3feba71500000000 3feb08e300000000 3feae4b6c0000000 3feae095e0000000 3feadfdc00000000 3feadfca80000000 3feadfc9e0000000 3feadfc9e0000000 3feadfca00000000 3feadfca00000000",
    xi = [3,4,17,18,19,56,57,60,61,126,130,196,197,200,201,202,205], xv = "3ff691c1a0000000 bf93b6f8c0000000 bfe849b560000000 3fbf55ad00000000 bf89eabde0000000 bfb657bec0000000 3fb74baec0000000 3fdb5e5f00000000 3fd0944be0000000 3f917a8580000000 bfed11ebc0000000 3f8fdf0e00000000 bf9ce87660000000 3fef24be00000000 bfe268fe60000000 3fe26268a0000000 3fbc882320000000",
    xcur = "0 0 3ff691ce20000000 bf93bdbd40000000 0 bfe269f3e0000000 3fe2624420000000 0 0 3fbc8a9520000000 3f8fbda880000000 bf9ce5aa40000000 0 0 3fef24ee60000000 0 bfe8494800000000 3fbf580e80000000 bf89f18020000000 0 3f916aef80000000 0 0 0 bfed11c060000000 3fd093bfe0000000 0 0 0 0 bfb657e280000000 3fb74d4ee0000000 0 0 3fdb5ee420000000",
    xprev = "0 0 3ff691d8c0000000 bf93dff620000000 0 bfe26c4900000000 3fe261c200000000 0 0 3fbc8f67e0000000 3f8f896ac0000000 bf9cde0040000000 0 0 3fef25e140000000 0 bfe848a9a0000000 3fbf5d4a80000000 bf89f9ef60000000 0 3f914486c0000000 0 0 0 bfed119ee0000000 3fd0919c60000000 0 0 0 0 bfb6584ba0000000 3fb7510f00000000 0 0 3fdb602980000000",
    y = "0 0 3ff691c9e0000000 bf93b00ce0000000 0 bfe2690500000000 3fe2627820000000 0 0 3fbc88a740000000 3f8fd28e00000000 bf9ce8bb00000000 0 0 3fef248d40000000 0 bfe8498760000000 3fbf55f680000000 bf89ee2060000000 0 3f917a4ca0000000 0 0 0 bfed11cdc0000000 3fd0949ae0000000 0 0 0 0 bfb657b880000000 3fb74bcee0000000 0 0 3fdb5e6200000000"),
  "f32/sgl_strided" => (passes = 20, nactive = 10, active = [1,2,3,50,27,17,30,11,10,42],
    hist = [50,10,2,250], k = [1,1,1,2,3,1,2,3,4,1,2,2,1,2,3,4,1,2,2,2],
    obj = "3ff0ea2860000000 3feccdd500000000 3febe6ade0000000 3febba6ce0000000 3febb21c80000000 3febb15de0000000 3febb15080000000 3febb14e60000000 3febb14e20000000 3febb14e00000000 3febb14e40000000 3febb14e00000000 3febb0cdc0000000 3febb0a180000000 3febb09100000000 3febb08d20000000 3febb08d00000000 3febb08d00000000 3febb08ce0000000 3febb08cc0000000",
    xi = [3,10,11,17,27,50,60,61,92,102,127,130,142,151,152,161,167,180,192,200,201,202,227], xv = "3ff6cabb40000000 3faf17a8c0000000 bf84b2d120000000 bfe99045a0000000 3f96ffa7c0000000 3fb89df000000000 3fda628f00000000 3fd0f00f20000000 bf92e37a60000000 3fa4099140000000 bf482860a0000000 bfed1821c0000000 3f7e7db380000000 3f848b1e80000000 bf9e15db00000000 3f93aa7e80000000 3fab34fb80000000 bfa417be20000000 3f94fe3be0000000 3fef77eca0000000 bfdd942100000000 3fe0f70840000000 3fa7848c60000000",
    xcur = "0 0 0 3f8490a860000000 bfdd93fe40000000 0 0 3fa401fee0000000 bf9e09a320000000 3fe0f6ecc0000000 3ff6caade0000000 0 0 0 0 3fb89e4b40000000 0 0 3fef77e760000000 0 3f96feaf00000000 0 bf481b8d60000000 0 3fa784a8e0000000 bfe99014c0000000 0 0 3fab350e20000000 0 0 0 bfed1826c0000000 bfa41b0680000000 0 bf84adb0c0000000 3fd0ef7c20000000 0 3f93a9a300000000 0 3faf185980000000 3fda627320000000 0 0 0 0 bf92f2c220000000 3f7e978ac0000000 3f950fb1a0000000 0",
    xprev = "0 0 0 3f849698a0000000 bfdd93c740000000 0 0 3fa3f827c0000000 bf9df9d7a0000000 3fe0f6bfe0000000 3ff6cab0c0000000 0 0 0 0 3fb89dfc00000000 0 0 3fef77db40000000 0 3f96fd80c0000000 0 bf48073d00000000 0 3fa784be00000000 bfe98fc560000000 0 0 3fab3377a0000000 0 0 0 bfed181760000000 bfa41de9e0000000 0 bf84a8dca0000000 3fd0ef1f20000000 0 3f93ab5980000000 0 3faf1918e0000000 3fda626c20000000 0 0 0 0 bf9303c4c0000000 3f7eb3da40000000 3f9522eae0000000 0",
    y = "0 0 0 3f848f2c40000000 bfdd940c00000000 0 0 3fa40474a0000000 bf9e0d9600000000 3fe0f6f800000000 3ff6caad20000000 0 0 0 0 3fb89e5f00000000 0 0 3fef77ea60000000 0 3f96fefa80000000 0 bf4820a180000000 0 3fa784a3a0000000 bfe99028a0000000 0 0 3fab3573c0000000 0 0 0 bfed182aa0000000 bfa41a4da0000000 0 bf84aee5c0000000 3fd0ef9360000000 0 3f93a93560000000 0 3faf1829a0000000 3fda6274e0000000 0 0 0 0 bf92ee8180000000 3f7e9076e0000000 3f950ae340000000 0"),
)
# the solve with CDSolver(; order = :cyclic, momentum = false) on the strided groups, same base and data
const FT27_CYCLIC = (passes = 48, minimum = "3ff0f0a3f16d6ae3", active = [1,2,3,50,30,42,27,10,11,17],
  xi = [1,2,3,10,11,17,27,30,42,50,51,52,53,60,61,67,77,80,92,100,101,102,103,110,111,117,127,130,142,150,151,152,153,160,161,167,177,180,192,200,201,202,203,210,211,217,227,230,242,250], xv = "3f7f550647dd2db5 bfad7c4c7f38aa39 3ff4d90e9a5401f7 3fb66f01fb527cda bfaa6272ce8c252e bfe52119db0fe89b 3f8396be954914c8 3f99333b08a37a36 bf932cfe59b14956 3fcdbdee1090b68d bf919f8dcc015182 bfa667335a837595 bfbc214f6512da52 3fcfa6224c961380 3fc940d722cc56fb 3f9b5594193af58f 3f7452f7a3cc4726 3f9fe1e72c2910eb bfa5d805ffb540b5 bfa37ed2ff78837e bf95a9087ce8430b 3fb8e91dadebeb11 bfaa5b796921b261 3f67dc96008bdb2f 3f8223adde78485d 3f8481cd62909767 bf8014741291b2f2 bfe8e5189c2b1c3b 3f9c065911a92171 3faaacc9b36d3feb 3fb2bd58909b7bd1 bfaff18920e9fc54 bfa4f4aa61918df6 bf72b7d7789062bc 3fa51e529b5298ed 3fbe0e031ec5e930 bf6e832c04e8cac5 bfbc867aa7118bd1 3fa4eab1c40bd599 3fecaee7f9f06c23 bfd54b5f742d9669 3fdb31c19ed2c7a6 3fb0bb5061d7f351 bf28f93ec95bf3f4 bfabcb11028885ca 3f73512c2f9550c5 3f91d454052184b4 bfacd7599e081cdb 3f75c2e5e859c753 bfbd47b99f5ff502")

ft27_vec(s) = [reinterpret(Float64, parse(UInt64, w; base = 16)) for w in split(s)]

# Julia's random number streams differ between versions, so the data come from a linear congruential generator:
# numbers k / 2^23 in [-1, 1), the same on every Julia version and platform, and exact in Float32
function ft27_stream(::Type{T}, dims...; seed) where {T}
  s = UInt64(seed)
  A = Array{T}(undef, dims...)
  for i in eachindex(A)
    s = s * 0x5851f42d4c957f2d + 0x14057b7ef767814f
    A[i] = T(Int64(s >> 40) - 2^23) / T(2^23)
  end
  A
end

function ft27_lassodata(T; n = 100, p = 250, seed = 11)
  X = ft27_stream(T, n, p; seed)
  y = T(0.9) .* ft27_stream(T, n; seed = seed + 1)
  for (j, β) in zip([3, 17, 60, 61, 130, 200, 201, 202], T[1.5, -1, 0.8, 0.6, -1.2, 1, -0.7, 0.9])
    for i in 1:n
      y[i] += β * X[i, j]
    end
  end
  X, y
end

ft27_groupsets(p) = Dict(
  "contig" => [i:i+4 for i in 1:5:p],
  "strided" => [k:(p ÷ 5):p for k in 1:(p ÷ 5)],
  "vecperm" => (perm = sortperm(ft27_stream(Float64, p; seed = 5)); [perm[i:i+4] for i in 1:5:p]),
)

# the cases: (key, data, penalty, start)
function ft27_cases(T)
  X, y = ft27_lassodata(T)
  n, p = size(X)
  tag = T === Float64 ? "f64" : "f32"
  λ = T(0.08) * norm(X' * (y .- sum(y) / n), Inf) / n
  cases = Any[("$tag/sparse_lasso", NormL1(λ), SparseIterate(T, p))]
  for (gname, groups) in sort!(collect(ft27_groupsets(p)); by = first)
    T === Float32 && gname == "vecperm" && continue
    λg = T(0.1) * maximum(G -> norm(X[:, G]' * (y .- sum(y) / n)), groups) / n
    w = sqrt.(T.(length.(groups)))
    push!(cases, ("$tag/gl2_$gname", GroupNormL2(λg, groups, w), AtomIterate(T, p, groups)))
    push!(cases, ("$tag/sgl_$gname", SparseGroupNormL2(λg / 2, λg / 2, groups), AtomIterate(T, p, groups)))
  end
  X, y, cases
end

# the momentum passes in cyclic order. CDSolver rejects order = :cyclic with momentum = true, so the internal
# driver runs the passes: the objective after `maxpasses` passes, and the state of the run
function ft27_run(T, f, g, x0, tol, maxpasses)
  x = copy(x0)
  s = CDSolver(; tol, order = :cyclic, maxpasses)
  m = cdmodel(f, x); PS.initialize!(m, x)
  st = PS._CDState(T, x, s)
  st.bestgap, st.gapstalls, st.previouschange = T(Inf), 0, T(Inf)
  gs = PS._gapstart!(st, m, g, x, s)
  PS._cd_momentum!(x, m, g, st, s, gs)
  x, m, st, PS.loss_value(m, x) + g(x)
end

# Float64: element-wise, relative 1e-12. Float32: norm-wise, because Float32 sums round differently with the SIMD
# width and fused multiply-adds of the CPU, so that iterates differ by a few ulps at the scale of the solve
ft27_close(a, b, ::Type{Float64}) = length(a) == length(b) &&
  all(isapprox(a[i], b[i]; rtol = 1e-12, atol = 1e-14) for i in eachindex(a))
ft27_close(a, b, ::Type) = length(a) == length(b) && norm(a .- b, Inf) <= 1e-4 * max(norm(b, Inf), 1)
ft27_scalar_close(a, b, ::Type{Float64}) = isapprox(a, b; rtol = 1e-12)
ft27_scalar_close(a, b, ::Type) = abs(a - b) <= 1e-5 * max(abs(b), 1)

@testset "FT27: cyclic momentum passes equal the recorded trajectories" begin
  grew, restarted, shrank = Ref(0), Ref(0), Ref(0)
  for T in (Float64, Float32)
    X, y, cases = ft27_cases(T)
    n, p = size(X)
    f = (one(T) / n) * LeastSquaresLoss(y, X)
    tol = T === Float64 ? 1e-10 : 1e-5
    for (key, g, x0) in cases
      @testset "$key" begin
        rec = FT27[key]
        x, m, st, obj = ft27_run(T, f, g, x0, tol, 100_000)
        @test st.passes == rec.passes && st.converged
        @test ft27_scalar_close(Float64(obj), ft27_vec(rec.obj)[end], T)
        xfinal = zeros(T, p); xfinal[rec.xi] .= T.(ft27_vec(rec.xv))
        @test ft27_close(Vector(x), xfinal, T)
        @test collect(activecoordinates(x)) == rec.active
        @test nactive(x) == rec.nactive
        mo = st.momentum
        @test [mo.n, mo.na, mo.k, length(mo.xcur)] == rec.hist
        @test ft27_close(mo.xcur[1:mo.n], ft27_vec(rec.xcur), T)
        @test ft27_close(mo.xprev[1:mo.n], ft27_vec(rec.xprev), T)
        @test ft27_close(mo.y[1:mo.n], ft27_vec(rec.y), T)
        # the history holds the active values of the iterate in slot order

        # the objective after every pass, from a fresh run limited to that many passes
        objs, ks, nacts = T[], Int[], Int[]
        for pass in 1:rec.passes
          xp, mp, sp, op = ft27_run(T, f, g, x0, tol, pass)
          push!(objs, op); push!(ks, sp.momentum.k); push!(nacts, nactive(xp))
        end
        @test ft27_close(Float64.(objs), ft27_vec(rec.obj), T)
        # a history started at the final iterate holds its active values, group by group in the working-set
        # order: the order of the recorded slots
        slots = x isa AtomIterate ? T[x[j] for k in activecoordinates(x) for j in atomindices(x, k)] :
                                    copy(activevalues(x)[1:nactive(x)])
        PS._momentum_start!(mo, x, m); PS._momentum_reset!(mo, x, m)
        @test mo.n == length(slots) == length(ft27_vec(rec.xcur)) && mo.xcur[1:mo.n] == slots
        @test mo.na == nactive(x) && mo.k == 1
        @test ks == rec.k
        # the history code ran: a step with β > 0, a restart, and a shrinking working set
        grew[] += any(>(1), ks)
        restarted[] += any(i -> ks[i] < ks[i - 1], 2:length(ks))
        shrank[] += any(i -> nacts[i] < nacts[i - 1], 2:length(nacts))
      end
    end
  end
  @test grew[] == 12      # a momentum step with β > 0 ran in every case
  @test restarted[] >= 1  # a restart ran
  @test shrank[] >= 1     # the history was reset by a change of nactive
end

# the public path: random order with momentum reaches the solution of the plain passes, on a lasso (SparseIterate),
# group lassos with contiguous, strided and vector-backed groups, and the cyclic passes without momentum equal the
# recorded run; the optimality of the returned iterate is checked from the data
@testset "FT27: momentum solves and the optimality of the solution" begin
  X, y = ft27_lassodata(Float64)
  n, p = size(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  λ = 0.08 * norm(X' * (y .- sum(y) / n), Inf) / n
  groupsets = ft27_groupsets(p)
  λg = 0.1 * maximum(G -> norm(X[:, G]' * (y .- sum(y) / n)), groupsets["strided"]) / n
  problems = Any[("lasso", NormL1(λ), SparseIterate(Float64, p), nothing)]
  for gname in ("contig", "strided", "vecperm")
    groups = groupsets[gname]
    w = sqrt.(length.(groups))
    push!(problems, ("gl2 $gname", GroupNormL2(λg, groups, w), AtomIterate(Float64, p, groups), w))
    push!(problems, ("sgl $gname", SparseGroupNormL2(λg / 2, λg / 2, groups), AtomIterate(Float64, p, groups), nothing))
  end
  for (name, g, x0, w) in problems
    @testset "$name" begin
      xp = copy(x0)
      rp = solve!(xp, f, g, CDSolver(; tol = 1e-12, order = :random, momentum = false, rng = Xoshiro(7)))
      xm = copy(x0)
      rm = solve!(xm, f, g, CDSolver(; tol = 1e-12, order = :random, momentum = true, rng = Xoshiro(7)))
      @test rp.converged && rm.converged
      @test Vector(xm) ≈ Vector(xp) atol = 1e-8
      @test rm.minimum ≈ rp.minimum rtol = 1e-10
      @test sort(collect(activecoordinates(xm))) == sort(collect(activecoordinates(xp)))
    end
  end

  # the objective and the optimality of the solution, recomputed from X, y and the penalty
  β(x) = Vector(x)
  grad(b) = X' * (X * b .- y) / n
  @testset "lasso residual" begin
    x = SparseIterate(Float64, p)
    r = solve!(x, f, NormL1(λ), CDSolver(; tol = 1e-12, rng = Xoshiro(7), momentum = true))
    b = β(x)
    @test r.minimum ≈ sum(abs2, X * b .- y) / (2n) + λ * norm(b, 1) rtol = 1e-10
    gr = grad(b)
    @test all(j -> iszero(b[j]) ? abs(gr[j]) <= λ + 1e-9 : abs(gr[j] + λ * sign(b[j])) <= 1e-9, 1:p)
  end
  @testset "group lasso residual" begin
    for gname in ("contig", "strided", "vecperm")
      groups = groupsets[gname]
      w = sqrt.(length.(groups))
      x = AtomIterate(Float64, p, groups)
      r = solve!(x, f, GroupNormL2(λg, groups, w), CDSolver(; tol = 1e-12, rng = Xoshiro(7), momentum = true))
      b = β(x)
      @test r.minimum ≈ sum(abs2, X * b .- y) / (2n) + λg * sum(w[k] * norm(b[groups[k]]) for k in eachindex(groups)) rtol = 1e-10
      gr = grad(b)
      for (k, G) in enumerate(groups)
        if iszero(norm(b[G]))
          @test norm(gr[G]) <= λg * w[k] + 1e-9
        else
          @test norm(gr[G] .+ λg * w[k] .* b[G] ./ norm(b[G])) <= 1e-9
        end
      end
    end
  end

  @testset "cyclic order without momentum equals the recorded run" begin
    groups = groupsets["strided"]
    x = AtomIterate(Float64, p, groups)
    r = solve!(x, f, GroupNormL2(λg, groups), CDSolver(; tol = 1e-12, order = :cyclic, momentum = false))
    xr = zeros(p); xr[FT27_CYCLIC.xi] .= ft27_vec(FT27_CYCLIC.xv)
    @test r.passes == FT27_CYCLIC.passes
    @test ft27_close([Float64(r.minimum)], ft27_vec(FT27_CYCLIC.minimum), Float64)
    @test ft27_close(Vector(x), xr, Float64)
    @test collect(activecoordinates(x)) == FT27_CYCLIC.active
  end
end

# a value written into the history of an active group, 0.0 or -0.0, keeps the group active and the working set as it was
@testset "stored zeros in the history keep their groups active" begin
  p = 12
  for groups in ([1:3, 4:6, 7:9, 10:12], [1:4:12, 2:4:12, 3:4:12, 4:4:12], [[7, 2, 11], [1, 12, 5], [3, 9, 4], [10, 6, 8]])
    x = AtomIterate(Float64, p, groups)
    for k in (3, 1)
      x[groups[k]] .= [0.5, -0.25, 1.0]
    end
    act, na = collect(activecoordinates(x)), nactive(x)
    @test na == 2
    n = PS._nvalues(x)
    @test n == 6
    for z in (0.0, -0.0)
      v = fill(z, n)
      PS._setvalues!(x, v, n)
      @test collect(activecoordinates(x)) == act && nactive(x) == na
      @test all(k -> isactive(x, k), act)
      @test all(j -> x[j] == 0 && signbit(x[j]) == signbit(z), (j for k in act for j in groups[k]))
      @test all(iszero, x[j] for k in setdiff(1:4, act) for j in groups[k])
      vals = Vector{Float64}(undef, n)
      @test PS._values!(vals, x, n) == v
      PS._setvalues!(x, [0.1, z, 0.3, -0.4, z, 0.6], n)
      @test collect(activecoordinates(x)) == act && nactive(x) == na
    end
    # the values come back in slot order
    PS._setvalues!(x, collect(1.0:6.0), n)
    vals = zeros(n); PS._values!(vals, x, n)
    @test vals == collect(1.0:6.0)
    @test [x[j] for k in activecoordinates(x) for j in atomindices(x, k)] == collect(1.0:6.0)
    dropzeros!(x)
    @test nactive(x) == na
  end
  s = SparseIterate(Float64, 8)
  s[2], s[5] = 0.7, -0.2
  act = collect(activecoordinates(s))
  for z in (0.0, -0.0)
    PS._setvalues!(s, fill(z, 2), 2)
    @test collect(activecoordinates(s)) == act && nactive(s) == 2
    @test PS._values!(zeros(2), s, 2) == [z, z]
  end
end

end
