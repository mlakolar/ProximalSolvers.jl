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
# which reads the iterate fields directly) on ProximalBase 0.5.4, Julia 1.13.3. The data are `ft27_lassodata`
# (seed 11) and the groups of `ft27_groupsets` (the permutation has seed 5); the loss is (1/n) LeastSquaresLoss;
# the penalty levels are those of `ft27_cases`. Floats are the hex digits of the Float64 bit pattern (Float32
# results are widened). `FT27` per case: `passes`, `nactive`, `active` (activecoordinates, in order), `hist`
# (the history after the run: n, na, k, length of the buffers), `k` (the history's k after pass 1, 2, ...),
# `obj` (the objective after pass 1, 2, ...), `xi`/`xv` (the nonzero entries of the final iterate),
# `xcur`/`xprev`/`y` (the first n entries of the history after the run).
const FT27 = Dict{String,NamedTuple}(
  "f64/sparse_lasso" => (passes = 32, nactive = 10, active = [61,3,202,201,200,130,60,134,17,34],
    hist = [10,10,2,250], k = [1,1,1,1,1,2,3,1,2,3,1,2,3,1,2,3,1,2,3,3,1,2,1,2,1,2,1,2,1,2,2,2],
    obj = "3ffa2d511b15e72a 3ff2d52d0c5488c2 3ff13713e82c7b9d 3fefe5d0b5e9da70 3fef6f3060ce5546 3fef66fc448a1ed1 3fef663dee336b3c 3fef6631963d72c5 3fef6630f1f0870c 3fef6630deed4ad0 3fef6630dd6e9338 3fef6630dd58d0da 3fef6630dd564eb5 3fef6630dd56369f 3fef6630dd5634ba 3fef6630dd563482 3fef6630dd563481 3fef6630dd563482 3fef6630dd563482 3fef6630dd563482 3fef662ff4b24b82 3fef662fef5e05bf 3fef662fee9e0636 3fef662fee9b865d 3fef662fee9b71e0 3fef662fee9b7132 3fef662fee9b711f 3fef662fee9b7120 3fef662fee9b7120 3fef662fee9b7120 3fef662fee9b711f 3fef662fee9b711f",
    xi = [3,17,34,60,61,130,134,200,201,202], xv = "3ff65f0fc39fa22e bfec55a7848e66ce 3f4d4c4767ad5300 3fe3deab537b9d8d 3fdfa9414caf8198 bfefe1a330ad09ca 3f9efbbb7b4326f0 3feba0fcf68b00c6 bfe3f2ea10176451 3fe68de116a8919d",
    xcur = "3fdfa9414cbb7b72 3ff65f0fc3a63c86 3fe68de11692623b bfe3f2ea101ceea7 3feba0fcf687f8b4 bfefe1a330a55db4 3fe3deab537483ff 3f9efbbb7c469178 bfec55a7848ddfce 3f4d4c475dfb5200",
    xprev = "3fdfa9414c9f6ce0 3ff65f0fc3b2ed05 3fe68de1165fce44 bfe3f2ea1032026f 3feba0fcf6810712 bfefe1a330928e62 3fe3deab536d4e06 3f9efbbb7ee34aa8 bfec55a784902094 3f4d4c473f611680",
    y = "3fdfa9414cc27f16 3ff65f0fc3a31066 3fe68de1169f0739 bfe3f2ea1017a9b5 3feba0fcf689b51c bfefe1a330aa1188 3fe3deab5376517d 3f9efbbb7b9f632c bfec55a7848d4f9c 3f4d4c4765a1e0e0"),
  "f64/gl2_contig" => (passes = 37, nactive = 9, active = [1,26,4,14,41,13,27,40,12],
    hist = [45,9,5,250], k = [1,1,1,1,1,1,1,2,3,4,5,6,1,2,3,4,5,6,1,2,3,4,5,6,1,2,3,4,5,6,1,2,3,4,5,5,5],
    obj = "4003a7327692c642 400223ba5bf256aa 4001b3e0f7743dcb 40017f51973ebc70 40016848dce10439 40015ef2e4aea9b9 40015b50a9363e9c 400159bd1036d006 400158e6ba1fa836 4001588a17f25d78 4001586cac99bbe5 40015867b5afa5aa 400158685daefd6a 40015867ef53c02a 40015867b13fd30a 4001586795cdf7c3 400158678d095dae 400158678b9695e4 400158678bcd205d 400158678bacd976 400158678b9a7ee6 400158678b925411 400158678b8fb72f 400158678b8f49d4 400158678b8f5ac4 400158678b8f5139 400158678b8f4bc5 400158678b8f4957 400158678b8f4890 400158678b8f486f 400158678b8f4874 400158678b8f4872 400158678b8f4871 400158678b8f4870 400158678b8f4870 400158678b8f486f 400158678b8f486f",
    xi = [1,2,3,4,5,16,17,18,19,20,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,126,127,128,129,130,131,132,133,134,135,196,197,198,199,200,201,202,203,204,205], xv = "3fa6f437b556544c 3f7fa25ee7379ad4 3ff1f5f45f165265 3fa4d2654fd26447 3faf1099729bb880 3f9d8bb854f01fed bfe25a2984ba6e75 3fb2a4cf9c700cd3 3f9376ef86e922b1 bfa6fc8319f41e00 3f70148f93e454fe 3f6954ffa7802525 bf975d67f66085d2 3f9083e9e1843c3e 3fd1238ccd5bdb70 3fd0bee581e05660 3fb545da91860964 3f92b100834927df bf90a4b4a4b43052 3f80eaa7482b2c56 bf9842c93d3b6da6 3f8f6428b6939e6b 3f8f2cf48e390608 3fa1436d3336cb65 3fa44622f1d4118c 3fa689eee32cb5f7 3fab84437212f7f7 3f9e59bd12755902 bfb47d96da47d81b bfe4e7206389b8cb 3f85f967195b8cfc 3f7801d5464eb1d6 bf86d7d909fa24fc 3fa71a3e3b9a0949 3f78080098f087c6 bf8f001568f45bfd bf879196ab365082 bf984f1fca2f2d27 bfc2faae97ec3f67 3fe324f3422c522a bfe10964b42751d5 3fe0aadd19eec097 bfa81996f4d5c3e7 bfb9a8a35d7f9d85 bf9bd2122f827292",
    xcur = "3fa6f437a45d13a7 3f7fa25ef1b307c4 3ff1f5f45fed546a 3fa4d2654ea98b20 3faf109983140b01 3fa689eedfa7dc7c 3fab84436fe79dd5 3f9e59bd0df2c7fd bfb47d96dad4a123 bfe4e72060aa883f 3f9d8bb85bdad352 bfe25a2983e893d2 3fb2a4cf997c175d 3f9376ef8a1e238f bfa6fc831b7026bf bf9842c95b9a2d16 3f8f6428dcd30ba5 3f8f2cf4b63f117a 3fa1436d47e273df 3fa4462308795fa6 bfe10964b3cd5fe6 3fe0aadd1842db22 bfa81996f5c73315 bfb9a8a35b1a110f bf9bd21231d48b77 3fd0bee581aacd50 3fb545da9029c5fd 3f92b10086a7461c bf90a4b4a48f7e4f 3f80eaa75427938d 3f85f96729e34d2f 3f7801d56084eaad bf86d7d91afa6ea3 3fa71a3e4dd30203 3f780800ae6c5dd3 bf8f001550b9b8e4 bf879196bfa6ff41 bf984f1fc183ea55 bfc2faae99c5391a 3fe324f341b6988c 3f70148f72b96282 3f6954ff62faa4e6 bf975d67ef4fffb3 3f9083e9e55afc12 3fd1238ccb0cde90",
    xprev = "3fa6f43789f3bf53 3f7fa25f055d27a0 3ff1f5f46139f722 3fa4d2654ea38c56 3faf10999e57961f 3fa689eedb1ed982 3fab84436e5deef9 3f9e59bd05deca22 bfb47d96dc3a56d7 bfe4e7205bdb117d 3f9d8bb867b3dcb5 bfe25a298269be8b 3fb2a4cf94f1ef73 3f9376ef92592572 bfa6fc831f1aecde bf9842c99215e374 3f8f6429215ef3ca 3f8f2cf4fe12e58a 3fa1436d6d3517ab 3fa446233154341b bfe10964b332c4bf 3fe0aadd15311cfc bfa81996f85797ea bfb9a8a35754416a bf9bd212330406b6 3fd0bee581359535 3fb545da8e32ad2a 3f92b1008bf5f7d5 bf90a4b4a42e2b6b 3f80eaa769ac198f 3f85f967481aa3a0 3f7801d58f567404 bf86d7d939ee8b27 3fa71a3e6f2c8fd9 3f780800d5238700 bf8f00152beb95f2 bf879196e060c1bc bf984f1fb32479a8 bfc2faae9cec43cd 3fe324f340d3c887 3f70148f3b8cb163 3f6954fef1891ee6 bf975d67e2f47077 3f9083e9ebc78daa 3fd1238cc6d4c8df",
    y = "3fa6f437b374b18e 3f7fa25ee6766346 3ff1f5f45f2f4093 3fa4d2654eacf826 3faf1099737fbb82 3fa689eee23f4be6 3fab844370c8940a 3f9e59bd12907d9f bfb47d96da08394e bfe4e720636a39d2 3f9d8bb85515a963 bfe25a2984c356d6 3fb2a4cf9c142e2c 3f9376ef856a227b bfa6fc831957b589 bf9842c93c780e05 3f8f6428b5a7ab90 3f8f2cf48d33bcdf 3fa1436d328ea88f 3fa44622f120e63f bfe10964b425b88f 3fe0aadd1a03da13 bfa81996f4501e09 bfb9a8a35d41f56d bf9bd21231272078 3fd0bee581edc8cd 3fb545da914941e3 3f92b100839ee08e bf90a4b4a4c71b64 3f80eaa747dbd943 3f85f967189f1bca 3f7801d545c409e9 bf86d7d9094a5e58 3fa71a3e3ac467d2 3f780800984cd895 bf8f001565c1ccdc bf879196acf3b4b2 bf984f1fc9ba73dc bfc2faae97f80e6b 3fe324f3423833fd 3f70148f9240a326 3f6954ffa3cdcce6 bf975d67f65fbf43 3f9083e9e1af3b29 3fd1238ccd760f87"),
  "f64/gl2_strided" => (passes = 30, nactive = 10, active = [1,2,3,50,17,13,30,34,11,10],
    hist = [50,10,4,250], k = [1,1,1,2,1,2,3,4,5,1,2,3,4,5,1,2,3,4,5,1,2,3,4,5,1,2,3,4,4,4],
    obj = "40041d0c318372ae 40029b6a150e6e07 400255022a57102b 40023c8b8d2b9f22 40023333c56d050e 40023197a51fd644 400230f173f911ef 400230b84dc79128 400230ab63dc6769 400230aac4f08248 400230aa8b0c93d3 400230aa719a9989 400230aa69984f44 400230aa68249fa9 400230aa68287da2 400230aa681c636e 400230aa68173530 400230aa6815a57e 400230aa6815632e 400230aa68156599 400230aa681562fb 400230aa681561df 400230aa6815618a 400230aa6815617c 400230aa6815617d 400230aa6815617d 400230aa6815617d 400230aa6815617d 400230aa6815617c 400230aa6815617d",
    xi = [1,2,3,10,11,13,17,30,34,50,51,52,53,60,61,63,67,80,84,100,101,102,103,110,111,113,117,130,134,150,151,152,153,160,161,163,167,180,184,200,201,202,203,210,211,213,217,230,234,250], xv = "3f94e1b23a935959 bf8a08c8d1f6aafe 3ff23fe25975ad69 bf82704c33778bf4 3f8b25e397c17e58 3f4c1cde0ecb8a11 bfe33ba09b0b67ac 3fa334818b784620 3fb63357d8a49c72 3fc2ee7fa7245e0e bfa0d1590d0172b7 bfae8aff6bdf5e02 bfa812fc1e4034b5 3fd2b1462ae966dd 3fd116ae3ec72ad1 3f609460dd6e7d37 3fb5f3c750c994b0 bf8f03df495c6e63 bfb1f2d73eb9ce12 3f9c948f3c42e197 bfa77267c9c60ee7 bf8f83edea32abba 3fb83ca347864458 3fb49894d310e0da 3f98945ed30a8462 3f71b09a5158ac48 3f39fda06c463405 bfe2a6de7ea8996e 3fc572aa58b79223 bfaef3cfbe58438e bf840ffdca083284 3fa8aa26aad5315e bfabe1455e171d3a 3f8bb59357d959c4 3f86609c4a33b06c bf6be074de5cbc28 3f998ea848daa403 bf9d2b6115ab8976 bfb26ce11b23b8da 3fe18e8d8c229376 bfd7439e4f95e898 3fd4d1adf70c86df bf9e174e2a543c13 bfa5107e025f580d bfa1ed499c78c697 bf74c051222073a5 3fb798715a6415ae bf9bc2f462689988 3f88cf0deb54bd66 3fb258dece3be3fd",
    xcur = "3f94e1b23f159405 bfa0d1590dad3ef6 bfa77267cf17f0ab bf840ffdd2a53945 bfd7439e4ee84fe1 bf8a08c8c932f81a bfae8aff6b9869c1 bf8f83ede1bbdbdb 3fa8aa26ae63aebb 3fd4d1adf79e1d4b 3ff23fe258d0d210 bfa812fc265dfdae 3fb83ca343447d68 bfabe145514ba3c6 bf9e174e2c53cf14 3fc2ee7fa6e25976 3f9c948f2cd56eba bfaef3cfbefe50a3 3fe18e8d8b7d0787 3fb258deceeb4fd6 bfe33ba09b2582b8 3fb5f3c75065517a 3f39fda01d5ab3f9 3f998ea849fe2305 3fb798715ba6afff 3f4c1cde56cab71e 3f60946108416495 3f71b09a7f5f60f4 bf6be075259b853d bf74c051576a6902 3fa334818cffa1ba bf8f03df45dc79af bfe2a6de7ed33209 bf9d2b610d54d6de bf9bc2f465669ec1 3fb63357daea9b43 bfb1f2d7405c8f24 3fc572aa5abdca2b bfb26ce11ce59e26 3f88cf0dec19fbde 3f8b25e39a4fd938 3fd116ae3e6c7b9c 3f98945ecfa6488d 3f86609c47b144a6 bfa1ed499c93dac1 bf82704c332a3f81 3fd2b1462a35f1a5 3fb49894d28d0e29 3f8bb5935a0f8d59 bfa5107e01b5ce81",
    xprev = "3f94e1b2441fde71 bfa0d1590d2cb967 bfa77267d81f831e bf840ffde1092d48 bfd7439e4d81ca2a bf8a08c8b72ec05e bfae8aff6b88b2e0 bf8f83edd1e81169 3fa8aa26b4d1216f 3fd4d1adf9573769 3ff23fe257a8b0ef bfa812fc3228908c 3fb83ca33bc3ffc4 bfabe1453a712e54 bf9e174e320fa827 3fc2ee7fa6925890 3f9c948f13331efc bfaef3cfbf811406 3fe18e8d8a7f8b03 3fb258ded0680122 bfe33ba09b401dfb 3fb5f3c74f1fb8a9 3f39fd9f70a9429c 3f998ea84a54293a 3fb798715dad4ebe 3f4c1cdeddd8580f 3f60946158268581 3f71b09ad55c6b41 bf6be075aacf7ec7 bf74c051bb14121e 3fa334818f397e26 bf8f03df3f2b8217 bfe2a6de7f2565e9 bf9d2b60fe18beba bf9bc2f469cd89d0 3fb63357df6936c2 bfb1f2d74346d1b5 3fc572aa5e56fa9a bfb26ce12020f60b 3f88cf0deda493ee 3f8b25e39eb91170 3fd116ae3da9907e 3f98945eca39dc22 3f86609c432ce91a bfa1ed499c6eefe0 bf82704c329076d4 3fd2b14628bbc065 3fb49894d12c273c 3f8bb5935e929e18 bfa5107e006a2621",
    y = "3f94e1b23c906ecf bfa0d1590ded81be bfa77267ca942772 bf840ffdcb733f44 bfd7439e4f9b92bc bf8a08c8d23513f8 bfae8aff6ba04532 bf8f83ede9a5c114 3fa8aa26ab2cf561 3fd4d1adf6c1903c 3ff23fe25964e2a0 bfa812fc2078b43f 3fb83ca34704bc3a bfabe1455cb8de7f bf9e174e2975e28a 3fc2ee7fa70a59e9 3f9c948f39a69699 bfaef3cfbebceef2 3fe18e8d8bfbc5c9 3fb258dece2cf730 bfe33ba09b183516 3fb5f3c751081de2 3f39fda073b36ca8 3f998ea849d31fea 3fb798715aa360a0 3f4c1cde1343e6a6 3f609460e04ed41f 3f71b09a5460dbce bf6be074e3018878 bf74c05125959474 3fa334818be2b384 bf8f03df4934f57b bfe2a6de7eaa1819 bf9d2b6114f2e2f0 bf9bc2f46333293a 3fb63357d8ab4d84 bfb1f2d73ee76ddc 3fc572aa58f131f4 bfb26ce11b47f234 3f88cf0deb54afd6 3f8b25e3981b3d1c 3fd116ae3ecdf12b 3f98945ed25c7ec2 3f86609c49f3726c bfa1ed499ca65032 bf82704c337723d8 3fd2b1462af30a45 3fb49894d33d81a0 3f8bb59357ce04fa bfa5107e025ba2b1"),
  "f64/gl2_vecperm" => (passes = 50, nactive = 10, active = [38,42,43,5,49,36,10,23,17,48],
    hist = [50,10,5,250], k = [1,1,1,1,1,1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,1,2,3,3,1,2,3,4,5,1,2,3,4,5,1,2,3,4,1,2,3,4,5,1,2,3,4,5,5,5],
    obj = "400630deb4bfa738 400353a5c9467a1b 4002ce28caa42011 4002af662e1cf7b5 4002a5228535f5f2 4002a26bf381a050 4002a16f1e5daf26 4002a1028707bc6d 4002a0e370ae33f6 4002a0df2891ee4e 4002a0df042e5d7e 4002a0defc901ffc 4002a0defb08378d 4002a0defad5eb08 4002a0defad23d8f 4002a0defad17de2 4002a0defad16901 4002a0defad168d0 4002a0defad1684d 4002a0defad16833 4002a0defad16831 4002a0defad16830 4002a0defad16830 4002a0defad16831 4002840b4817139e 40027a3f321248d7 400276c3c5c53368 4002759a82696041 4002755310c00bf5 4002754c1d9b8be2 4002754b256e5b21 4002754ad70ce99b 4002754ac3000f22 4002754abeed3520 4002754abe82b95b 4002754abe69e9ab 4002754abe62ca8a 4002754abe615686 4002754abe612077 4002754abe611a24 4002754abe6117fe 4002754abe611768 4002754abe611747 4002754abe611744 4002754abe611743 4002754abe611744 4002754abe611743 4002754abe611744 4002754abe611744 4002754abe611743",
    xi = [1,3,4,12,13,14,15,17,20,28,40,48,51,52,59,60,61,67,69,73,91,105,110,117,122,129,130,134,137,145,165,169,174,186,193,197,198,200,201,202,208,218,219,222,223,224,232,239,244,248], xv = "bf80b6ef17a9a4ae 3ff24b52b52bdde7 3f8e512441792cc6 3fa91464ee5dd32e bf7af1188e5d1c68 3fb94df28595baf8 bfb5887971a220bc bfe019325963bde0 bfa4b2f90d1b295c 3f7f3c949cfac81b bf93ff21379513d9 3f8e218f4cb27557 bfb276a9560887e3 bfb1b1e69cbcb96a 3f76dc312eced175 3fce56520717d032 3fd2793a78cad934 3fad57129955d528 3fcf87110ac4754b 3f8990857848228b 3fbfd248b7cdb3fa 3f9b5357c8968ae1 3fbb32b26a3830e2 bf75cfb5537b512a bf63d932d5e1d189 bfc1a24da1cb3a16 bfe0b418cf5ac7e6 3fcb1e90bdf5a637 bfa9d0b165fb07ac bf90103c76d62cbb 3fafc5f78007f1a5 bf9961426143bd97 bf9bf00a311e46e1 bf9b6f3e422e184b bf8939e112a8460b bf94879d8c3ea4c6 bf9cb490b35ebd91 3fe018bffe6bd555 bfd72ed9f46e63c4 3fd033ee8ec34bcc 3fc03f73d94bfd72 3fa4d3ceaf1e9d96 3fab9f8603d877b1 bf7b59e2a5280840 bf8ab06739f44964 bf5c7cd305b5a6cf 3fb34cf535469da2 bfb5eb463e2cbd01 3fa9f544c0376f98 3fb42f425d95dce1",
    xcur = "3f7f3c948f64a0f8 bf7b59e299f7227f bf8ab0672e73579a 3f8990856d7abe79 bf5c7cd2fbd2d85b bf63d932d2041fbd bfb1b1e69d3e0f80 3fd033ee8fa498c3 3fab9f86049b0207 3fa4d3ceaeaaff1d 3fd2793a78f88bf4 3f8e5124421bacbb bf7af1188d85b734 bf9bf00a2fbd40c8 bfa9d0b1673a73cc 3fa9f544bef89adc bfb58879707e5b19 3fcb1e90bcc73d10 bf75cfb54b83301e bf80b6ef1784ddd0 bfa4b2f90d8cf3d2 bfe0b418cf9a0841 bf99614260920809 bfb5eb463e608347 3fbb32b26b0b1e0e bf93ff2139842d91 3fbfd248b8233dc6 3fa91464ee071365 3fad5712988c507c bfd72ed9f408d634 bf9b6f3e41c46108 bfe01932597a8196 3fafc5f77e532fce bfc1a24da17add85 3fb94df285725ee5 bf8939e113fdb136 bf9cb490b2b43266 3fe018bffe65484d 3f8e218f4cdc170f bfb276a955d76467 3fcf87110a1d37b7 3fb34cf5348dfa9e 3ff24b52b52f9d98 3fc03f73d94e539d 3fb42f425d329677 3fce5652084a4362 bf90103c7774db4c 3f9b5357c85dbad1 3f76dc312f64ce81 bf94879d8cfbe4e7",
    xprev = "3f7f3c947cdd654d bf7b59e2896a408e bf8ab0671e88047b 3f8990855f4cf29e bf5c7cd2f1086991 bf63d932ca42e709 bfb1b1e69d51614d 3fd033ee9187a2a1 3fab9f8604e123ac 3fa4d3ceb0a863bd 3fd2793a79661a52 3f8e512440f81230 bf7af1189b2811a6 bf9bf00a3034695c bfa9d0b165f14202 3fa9f544bb6e32ca bfb588796e55443a 3fcb1e90b9a3ebd3 bf75cfb53c8c5833 bf80b6ef12df1767 bfa4b2f90eac575e bfe0b418d00b3084 bf9961426367baaa bfb5eb463e34d149 3fbb32b26aa3fb40 bf93ff21398b518c 3fbfd248b732f83e 3fa91464ec409002 3fad571297bf2296 bfd72ed9f40e6cb3 bf9b6f3e3c380390 bfe0193259b16f66 3fafc5f77dd68c54 bfc1a24da135c4c8 3fb94df285dbe33d bf8939e11d25e601 bf9cb490b1daaf0d 3fe018bffe9facd2 3f8e218f4eaeffcb bfb276a954cd0e8f 3fcf871109b884ae 3fb34cf53224175f 3ff24b52b51d96d8 3fc03f73d8fa9934 3fb42f425b971d7a 3fce5652097fd849 bf90103c787c2661 3f9b5357c8171673 3f76dc31343f77be bf94879d8df38c5f",
    y = "3f7f3c9499fb0c35 bf7b59e2a36c35e4 bf8ab067378c1963 3f8990857594e9d2 bf5c7cd301fd60ce bf63d932d6728948 bfb1b1e69d330554 3fd033ee8e909320 3fab9f860472eecd 3fa4d3cead87ea2f 3fd2793a78b9f175 3f8e512442c24e2f bf7af11885bb3a61 bf9bf00a2f792998 bfa9d0b167f6903f 3fa9f544c0fe8d2f bfb5887971ba682b 3fcb1e90be9246ea bf75cfb554103dc9 bf80b6ef1a2cbce7 bfa4b2f90ce8baf0 bfe0b418cf595ef6 bf9961425ef358d2 bfb5eb463e797b46 3fbb32b26b460d5f bf93ff2139801902 3fbfd248b8ac8a14 3fa91464ef0acc30 3fad571299018f49 bfd72ed9f405a4c7 bf9b6f3e44f00428 bfe01932595b1e44 3fafc5f77e9a68a6 bfc1a24da1a2595f 3fb94df285361345 bf8939e10ec22554 bf9cb490b3307d74 3fe018bffe43ea4a 3f8e218f4bd148ed bfb276a9566f9575 3fcf87110a56c298 3fb34cf535ef0ec2 3ff24b52b539ea98 3fc03f73d97e2bd9 3fb42f425e1db708 3fce565207995c03 bf90103c76de6740 3f9b5357c88618be 3f76dc312c9eb6f0 bf94879d8c6e60a2"),
  "f64/sgl_contig" => (passes = 32, nactive = 8, active = [1,26,13,4,41,40,27,12],
    hist = [40,8,4,250], k = [1,1,1,1,1,2,1,2,3,4,5,1,2,3,4,5,1,2,3,4,5,1,2,3,4,5,1,2,3,4,4,4],
    obj = "40015855909f6ca2 3ffe66b714fb7c7f 3ffcf7800a849068 3ffc3d5160173a4c 3ffc0a52243cbfb1 3ffbf84ace3d0f32 3ffbf26fa5db5e70 3ffbf1690ba9040a 3ffbf0ea3b4339b2 3ffbf0bd429ef83a 3ffbf0b3ce038c02 3ffbf0b3b9a6eea6 3ffbf0b388053681 3ffbf0b3706e8755 3ffbf0b368585aee 3ffbf0b366b5a1ac 3ffbf0b366b480ae 3ffbf0b366ab819b 3ffbf0b366a74c48 3ffbf0b366a5e097 3ffbf0b366a5981b 3ffbf0b366a5980c 3ffbf0b366a59675 3ffbf0b366a595b8 3ffbf0b366a59578 3ffbf0b366a5956c 3ffbf0b366a5956d 3ffbf0b366a5956c 3ffbf0b366a5956c 3ffbf0b366a5956c 3ffbf0b366a5956d 3ffbf0b366a5956d",
    xi = [3,5,17,18,60,61,62,129,130,134,199,200,201,202,204], xv = "3ff457f57a1a452b 3f766b9dbe59a9ac bfe741c45d674bcd 3fa0047e27960350 3fdcde69eb430dfc 3fd7f10cd86bca96 3f9c88703794c90b bf95fccc5015cf5f bfe9a9b33fdb34a6 3f942acdc28e7cba bfb37b01c2dd2cea 3fe725026d1ccc2a bfe21c04c86cda45 3fe36fde9636c4a8 bf893c4fad610e0f",
    xcur = "0 0 3ff457f57a4bf43e 0 3f766b9dd81a1e5a 0 0 0 bf95fccc560c41db bfe9a9b33f23249b 3fd7f10cd872af51 3f9c887037fb04b8 0 0 0 0 bfe741c45d3bc286 3fa0047e27286040 0 0 bfe21c04c8815b80 3fe36fde957d5788 0 bf893c4fa7776c5a 0 0 0 0 bfb37b01c451eed3 3fe725026cf69e08 0 0 0 3f942acdd8718bd7 0 0 0 0 0 3fdcde69ea735b90",
    xprev = "0 0 3ff457f57a88076c 0 3f766b9dfcb2c154 0 0 0 bf95fccc607382f4 bfe9a9b33dfec5de 3fd7f10cd870dac0 3f9c88703b6b8089 0 0 0 0 bfe741c45cedab79 3fa0047e26dfad3e 0 0 bfe21c04c898f8e0 3fe36fde94508aec 0 bf893c4fa106d470 0 0 0 0 bfb37b01c61e7328 3fe725026cb50cff 0 0 0 3f942acdfe6330ee 0 0 0 0 0 3fdcde69e903192b",
    y = "0 0 3ff457f57a2deaa7 0 3f766b9dc5cdccdd 0 0 0 bf95fccc50d8a14e bfe9a9b33fb553fa 3fd7f10cd873999a 3f9c88703642c6d0 0 0 0 0 bfe741c45d62ce0c 3fa0047e274cb9c1 0 0 bfe21c04c8758cd0 3fe36fde9613bdd6 0 bf893c4faaafb84f 0 0 0 0 bfb37b01c36baca8 3fe725026d17668c 0 0 0 3f942acdc578b94c 0 0 0 0 0 3fdcde69eb2b7cc2"),
  "f64/sgl_strided" => (passes = 31, nactive = 9, active = [1,2,3,50,11,30,17,34,10],
    hist = [45,9,4,250], k = [1,1,1,1,1,1,2,3,4,5,1,2,3,4,5,1,2,3,4,5,1,2,3,4,5,1,2,3,4,4,4],
    obj = "40017b64ef9f1453 3ffebd47b3e018fd 3ffdb60eb0f949a5 3ffd5afe7196fa02 3ffd412d635b5cce 3ffd38a3c80c90a4 3ffd35f11a8422f9 3ffd34ce7fbfad6a 3ffd3477ffb104d2 3ffd3468e8c18ccf 3ffd3469245b7346 3ffd3468a9b6d6e8 3ffd346876552982 3ffd346866b0590c 3ffd346863effbdd 3ffd346863ffc0d2 3ffd346863e9dc2a 3ffd346863e05d34 3ffd346863dd6955 3ffd346863dce399 3ffd346863dce6f3 3ffd346863dce2df 3ffd346863dce115 3ffd346863dce086 3ffd346863dce06c 3ffd346863dce06d 3ffd346863dce06c 3ffd346863dce06a 3ffd346863dce06c 3ffd346863dce06c 3ffd346863dce06b",
    xi = [3,17,34,50,52,60,61,67,84,103,110,130,134,184,200,201,202,210,250], xv = "3ff45b115b15e4e0 bfe706261211fa13 3fa4fd02152bec88 3fb2a1340a8239fe bf915b7f74d8f9f0 3fdc573fd51306ff 3fd81bff42aac28e 3f5d34dd9ad613b9 bf9481e31ed4d50b 3f5892c08457219d 3f8700a0a27bf101 bfe914ce78493b57 3fb30fd148a1acab bf9621b7d5637353 3fe687d044ee9891 bfdf2e7f08cef1de 3fe128e6e98a86cb bf84ef1fb47783a6 3f33690db9ab7726",
    xcur = "0 0 0 0 bfdf2e7f08cdcb0c 0 bf915b7f7bbe7ab2 0 0 3fe128e6e82b2821 3ff45b115b3ddea5 0 3f5892c13145fff6 0 0 3fb2a1340ae4d31f 0 0 3fe687d044a172ee 3f33690f65e212cd 0 3fd81bff42ba240e 0 0 0 0 0 bfe914ce7751d4dd 0 0 bfe7062611f64bb6 3f5d34dde3367297 0 0 0 3fa4fd0219adba21 bf9481e323b56b52 3fb30fd14ef1d726 bf9621b7d9e7d65b 0 0 3fdc573fd3d2ea05 3f8700a09d0f97ba 0 bf84ef1fb64b3a89",
    xprev = "0 0 0 0 bfdf2e7f087d0823 0 bf915b7f8a0de168 0 0 3fe128e6e5e0eed5 3ff45b115b7dc86e 0 3f5892c27e6aa7f9 0 0 3fb2a1340c148462 0 0 3fe687d0440c55df 3f33691191008b4d 0 3fd81bff42c0dd80 0 0 0 0 0 bfe914ce75a7f999 0 0 bfe7062611bd34dd 3f5d34de53f73ae0 0 0 0 3fa4fd022170a3c0 bf9481e32bed3ab6 3fb30fd159de3be7 bf9621b7e1d57564 0 0 3fdc573fd1b5a77f 3f8700a0971d75ea 0 bf84ef1fbc2010a5",
    y = "0 0 0 0 bfdf2e7f08f62c80 0 bf915b7f7496c757 0 0 3fe128e6e95044c7 3ff45b115b1de9c0 0 3f5892c08ab3abf4 0 0 3fb2a1340a4cfa7e 0 0 3fe687d044ec0176 3f33690e5052d68d 0 3fd81bff42b6c755 0 0 0 0 0 bfe914ce7826c27f 0 0 bfe706261212d722 3f5d34ddaad60e72 0 0 0 3fa4fd0215cc4552 bf9481e31f9983a0 3fb30fd1497ba4c6 bf9621b7d5f106d6 0 0 3fdc573fd4e18b48 3f8700a0a008a8a2 0 bf84ef1fb360cf7b"),
  "f64/sgl_vecperm" => (passes = 34, nactive = 9, active = [17,36,42,5,49,43,10,48,23],
    hist = [45,9,2,250], k = [1,1,1,1,1,1,2,3,4,5,1,2,3,4,5,1,2,3,4,5,1,2,3,4,5,1,2,3,4,5,1,2,2,2],
    obj = "400442762aae241d 4000c2cdfc0fc9a6 3fff754251fe64bc 3ffec0cfa7b8a867 3ffe698d2c717dc6 3ffe424529b7cb74 3ffe35b004196e0f 3ffe2f2481a27fb3 3ffe2cb12ad26153 3ffe2c286a1d7974 3ffe2c25db65f88a 3ffe2c2365a195a8 3ffe2c223fc52453 3ffe2c21daac83d4 3ffe2c21c581fcb4 3ffe2c21c5305f4e 3ffe2c21c4cefdae 3ffe2c21c4a0e97d 3ffe2c21c490f9db 3ffe2c21c48da506 3ffe2c21c48d9951 3ffe2c21c48d8a1a 3ffe2c21c48d82dc 3ffe2c21c48d8058 3ffe2c21c48d7fd2 3ffe2c21c48d7fd0 3ffe2c21c48d7fce 3ffe2c21c48d7fcc 3ffe2c21c48d7fcc 3ffe2c21c48d7fca 3ffe2c21c48d7fcb 3ffe2c21c48d7fcc 3ffe2c21c48d7fce 3ffe2c21c48d7fce",
    xi = [3,14,15,17,52,60,61,69,91,110,129,130,134,137,200,201,202,208,239], xv = "3ff415664a7336f3 3f99b58e0cfd9d3f bf92fa6f7a4c399a bfe5fb26d8c21fc7 bf90d108b096b3a3 3fdaa95c55b34462 3fd858f292501ae4 3fbd5b9821bb4f26 3fb27688a355347e 3f8bf37b51c4c2a3 bfa42d242999d436 bfe7f45dcf6991fe 3fb346323ef2b391 bf8bcfad0684e763 3fe64af1758edeb6 bfde3f9022924c7d 3fe024066dc8a0aa 3f7a0fc2b527d4c6 bf93ffe485cc139f",
    xcur = "3fbd5b9820f9a1b5 0 3ff415664a7109e1 3f7a0fc2aea3e328 0 0 3fb27688a2f373f0 0 0 bfde3f90229326bd 0 bf90d108aeb4e526 3fe024066e05e913 0 0 0 bf92fa6f78d285e8 3fb346323da97581 0 0 0 bfe7f45dcf8d4c71 0 bf93ffe484fb93f9 3f8bf37b50b5cc22 3fd858f29244f034 0 0 0 bf8bcfad07e2bd4a 0 bfe5fb26d8cfc032 0 bfa42d2428f4d9d1 3f99b58e0c3e73c0 3fdaa95c55df78f0 0 0 0 0 0 0 3fe64af17598c8c9 0 0",
    xprev = "3fbd5b9820492f8d 0 3ff415664a6fc581 3f7a0fc2a8ac90f3 0 0 3fb27688a2abb6c9 0 0 bfde3f902291bc83 0 bf90d108ad39830d 3fe024066e383267 0 0 0 bf92fa6f77582be6 3fb346323c5e0d35 0 0 0 bfe7f45dcfac0de9 0 bf93ffe4845379c4 3f8bf37b4f7bc85b 3fd858f2923d5655 0 0 0 bf8bcfad08ffde54 0 bfe5fb26d8deb98f 0 bfa42d2428489a7b 3f99b58e0b7a0a62 3fdaa95c560bf9c7 0 0 0 0 0 0 3fe64af175a32191 0 0",
    y = "3fbd5b982125be3f 0 3ff415664a715af9 3f7a0fc2b021b7b5 0 0 3fb27688a305633a 0 0 bfde3f902293814c 0 bf90d108af13bdac 3fe024066df956be 0 0 0 bf92fa6f79311c68 3fb346323dfc4f94 0 0 0 bfe7f45dcf859c13 0 bf93ffe485259a86 3f8bf37b51044d14 3fd858f29246d6ac 0 0 0 bf8bcfad079b7508 0 bfe5fb26d8cc01db 0 bfa42d24291fe9a6 3f99b58e0c6f8e18 3fdaa95c55d458ba 0 0 0 0 0 0 3fe64af175963297 0 0"),
  "f32/sparse_lasso" => (passes = 21, nactive = 21, active = [3,61,202,8,60,237,200,201,15,17,203,208,22,40,75,206,130,171,102,167,242],
    hist = [21,21,2,250], k = [1,1,1,1,1,1,1,2,3,4,1,2,3,3,1,2,3,1,2,2,2],
    obj = "3ff3675e00000000 3feafcfce0000000 3fe7483f80000000 3fe595f0c0000000 3fe48ac940000000 3fe4244e40000000 3fe40d1640000000 3fe407e340000000 3fe406bfa0000000 3fe4069b40000000 3fe4069c40000000 3fe4069ae0000000 3fe4069aa0000000 3fe4069a80000000 3fe4064920000000 3fe4063400000000 3fe40631a0000000 3fe4063160000000 3fe4063160000000 3fe4063180000000 3fe4063180000000",
    xi = [3,8,15,17,22,40,60,61,75,102,130,167,171,200,201,202,203,206,208,237,242], xv = "3ff5edf7c0000000 bfa200cbe0000000 bf94499f80000000 bfec6804c0000000 bf6750dc00000000 bfa06aea40000000 3fe79ab6e0000000 3fdd30c1a0000000 bf6b943c00000000 bf68c2d000000000 bff052e960000000 bf740fce00000000 3f822d4000000000 3febbb6480000000 bfe31350a0000000 3fe9208cc0000000 bf95af8e80000000 3f91feb400000000 bfa651a240000000 bf8a506100000000 bf84a65400000000",
    xcur = "3ff5edd660000000 3fdd309120000000 3fe9208120000000 bfa1ff8aa0000000 3fe79a8a60000000 bf8a559200000000 3febbb6600000000 bfe3136960000000 bf944a0600000000 bfec67fe00000000 bf95acc080000000 bfa652dc80000000 bf676a5c00000000 bfa06ad640000000 bf6b851000000000 3f91ff0100000000 bff052e820000000 3f822b2c00000000 bf68cf1400000000 bf7416f600000000 bf84ace700000000",
    xprev = "3ff5ed7d00000000 3fdd304ae0000000 3fe9205340000000 bfa1ff2ba0000000 3fe79a4a60000000 bf8a645000000000 3febbb4b20000000 bfe313b1a0000000 bf944ee400000000 bfec67d7c0000000 bf95ace000000000 bfa652c9c0000000 bf67965c00000000 bfa06982c0000000 bf6b53cc00000000 3f91fd4d80000000 bff052eb80000000 3f822c3900000000 bf68da1800000000 bf7426aa00000000 bf84b9ca00000000",
    y = "3ff5edecc0000000 3fdd30a2c0000000 3fe9208ca0000000 bfa1ffa260000000 3fe79a9a60000000 bf8a51e280000000 3febbb6cc0000000 bfe3135740000000 bf9448ce80000000 bfec680780000000 bf95acb8a0000000 bfa652e140000000 bf675f5c00000000 bfa06b2b20000000 bf6b916100000000 3f91ff6de0000000 bff052e740000000 3f822ae8c0000000 bf68cc5300000000 bf74130900000000 bf84a9ae40000000"),
  "f32/gl2_contig" => (passes = 18, nactive = 11, active = [1,2,15,4,5,12,26,13,42,41,40],
    hist = [55,11,1,250], k = [1,1,1,1,1,2,3,4,5,1,2,3,4,5,6,1,1,1],
    obj = "3ffe88aee0000000 3ffbeaef40000000 3ffb1f97a0000000 3ffacb6f00000000 3ffaaab680000000 3ffa9c7e80000000 3ffa94ba80000000 3ffa913d60000000 3ffa901000000000 3ffa8fd2c0000000 3ffa8fcf40000000 3ffa8fcd40000000 3ffa8fcc60000000 3ffa8fcc20000000 3ffa8fcc20000000 3ffa8fcc00000000 3ffa8fcbe0000000 3ffa8fcc00000000",
    xi = [1,2,3,4,5,6,7,8,9,10,16,17,18,19,20,21,22,23,24,25,56,57,58,59,60,61,62,63,64,65,71,72,73,74,75,126,127,128,129,130,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210], xv = "bf8df13d80000000 bf7328b920000000 3fed627020000000 bf8d6d6620000000 3f739f9cc0000000 bfa458c2c0000000 3fa4f35040000000 bfb718c260000000 bf72103c80000000 3f896cfcc0000000 bfa9ba3d20000000 bfe0021e20000000 bf946766c0000000 bf970a49c0000000 3f862e4b40000000 3f45f68ca0000000 bf65907100000000 bf51176760000000 3f681e8660000000 3f485a0c00000000 3fa3d1b960000000 3f8f3b4780000000 bf7046ee40000000 3f90582660000000 3fdf9a35a0000000 3fc1a568e0000000 3fac3452c0000000 bf92269d00000000 bf8f4eece0000000 3f7e1f7800000000 3f711df9a0000000 3f543768c0000000 3f64e3c8e0000000 3f61f1a200000000 bf703b1ec0000000 bfb9dad8e0000000 bfc1177880000000 3f96e412c0000000 bfb9f18980000000 bfe179f5a0000000 bf7c8e4860000000 bf94494500000000 3f9a579e20000000 3fa75ff8c0000000 3fdf9d5fa0000000 bfdef53c80000000 3fe1f583a0000000 bfc73d6960000000 3fc35af320000000 3fa4a880a0000000 3fa6d81280000000 3f618356e0000000 bfa80fb100000000 bf89129640000000 bf9e557c80000000",
    xcur = "bf8df56900000000 bf7338c740000000 3fed6289a0000000 bf8d67a5a0000000 3f7399dbe0000000 bfa4595860000000 3fa4f41560000000 bfb7197b60000000 bf720fa8e0000000 3f896bea00000000 3f71017460000000 3f5416be60000000 3f64c14860000000 3f61d42080000000 bf702069a0000000 bfa9bbef60000000 bfe0021ec0000000 bf9465b660000000 bf970b2660000000 3f862cfb20000000 3f45ed0360000000 bf6586fb60000000 bf510fc980000000 3f6813b3c0000000 3f484fc180000000 3fa3d1dd00000000 3f8f394a00000000 bf7045b200000000 3f90581ec0000000 3fdf9a35a0000000 bfb9da09e0000000 bfc117a9e0000000 3f96e711c0000000 bfb9f17de0000000 bfe179f9a0000000 3fc1a652a0000000 3fac369960000000 bf922750c0000000 bf8f4f5cc0000000 3f7e1f88c0000000 3fa6d7eae0000000 3f61834a60000000 bfa80fafc0000000 bf891399c0000000 bf9e55c920000000 bfdef4f2c0000000 3fe1f56f80000000 bfc73d8d80000000 3fc35b0a60000000 3fa4a7e5e0000000 bf7c8ba980000000 bf9447a9a0000000 3f9a56ffc0000000 3fa75f5aa0000000 3fdf9d5260000000",
    xprev = "bf8ded6b00000000 bf73048b60000000 3fed6172c0000000 bf8d750120000000 3f73a71620000000 bfa45afa40000000 3fa4f63780000000 bfb71a86e0000000 bf72187260000000 3f89711440000000 3f716f3120000000 3f5496ed60000000 3f6547d860000000 3f624673a0000000 bf708782a0000000 bfa9b63f00000000 bfe001c020000000 bf946d3cc0000000 bf970e7180000000 3f862f07e0000000 3f46433760000000 bf65dafe20000000 bf5152b0a0000000 3f68713f00000000 3f48ab55c0000000 3fa3d2f820000000 3f8f39f3a0000000 bf705e3240000000 3f90558ce0000000 3fdf99df80000000 bfb9dc71c0000000 bfc1183dc0000000 3f96e3cc60000000 bfb9f2ab00000000 bfe1793680000000 3fc1a1bdc0000000 3fac2e3ac0000000 bf9223eb40000000 bf8f4aa2c0000000 3f7e184500000000 3fa6dbc1a0000000 3f6189fd80000000 bfa81384c0000000 bf89154780000000 bf9e5a1620000000 bfdef54c40000000 3fe1f55d60000000 bfc73deda0000000 3fc35b30c0000000 3fa4a98f80000000 bf7c922c80000000 bf944c3620000000 3f9a5c06e0000000 3fa75fd340000000 3fdf9ca320000000",
    y = "bf8df56900000000 bf7338c740000000 3fed6289a0000000 bf8d67a5a0000000 3f7399dbe0000000 bfa4595860000000 3fa4f41560000000 bfb7197b60000000 bf720fa8e0000000 3f896bea00000000 3f71017460000000 3f5416be60000000 3f64c14860000000 3f61d42080000000 bf702069a0000000 bfa9bbef60000000 bfe0021ec0000000 bf9465b660000000 bf970b2660000000 3f862cfb20000000 3f45ed0360000000 bf6586fb60000000 bf510fc980000000 3f6813b3c0000000 3f484fc180000000 3fa3d1dd00000000 3f8f394a00000000 bf7045b200000000 3f90581ec0000000 3fdf9a35a0000000 bfb9da09e0000000 bfc117a9e0000000 3f96e711c0000000 bfb9f17de0000000 bfe179f9a0000000 3fc1a652a0000000 3fac369960000000 bf922750c0000000 bf8f4f5cc0000000 3f7e1f88c0000000 3fa6d7eae0000000 3f61834a60000000 bfa80fafc0000000 bf891399c0000000 bf9e55c920000000 bfdef4f2c0000000 3fe1f56f80000000 bfc73d8d80000000 3fc35b0a60000000 3fa4a7e5e0000000 bf7c8ba980000000 bf9447a9a0000000 3f9a56ffc0000000 3fa75f5aa0000000 3fdf9d5260000000"),
  "f32/gl2_strided" => (passes = 35, nactive = 14, active = [1,2,3,37,50,6,8,35,10,30,27,17,11,40],
    hist = [70,14,1,250], k = [1,1,1,1,1,2,3,1,2,1,2,3,4,1,2,3,4,5,6,6,1,2,3,4,5,6,1,2,3,4,5,6,1,1,1],
    obj = "3ffc016540000000 3ff9e50180000000 3ff94b3300000000 3ff908d5c0000000 3ff8e3a9a0000000 3ff8d09a60000000 3ff8c40440000000 3ff8bd13c0000000 3ff8bb4000000000 3ff8ba0a00000000 3ff8b99080000000 3ff8b93fc0000000 3ff8b91280000000 3ff8b8fe40000000 3ff8b8fb40000000 3ff8b8f8e0000000 3ff8b8f7a0000000 3ff8b8f6c0000000 3ff8b8f6c0000000 3ff8b8f6a0000000 3ff8b27900000000 3ff8afc660000000 3ff8adee00000000 3ff8ace220000000 3ff8ac5760000000 3ff8ac17c0000000 3ff8ac02c0000000 3ff8ac00c0000000 3ff8abff80000000 3ff8abff20000000 3ff8abfec0000000 3ff8abfec0000000 3ff8abfec0000000 3ff8abfec0000000 3ff8abfec0000000",
    xi = [1,2,3,6,8,10,11,17,27,30,35,37,40,50,51,52,53,56,58,60,61,67,77,80,85,87,90,100,101,102,103,106,108,110,111,117,127,130,135,137,140,150,151,152,153,156,158,160,161,167,177,180,185,187,190,200,201,202,203,206,208,210,211,217,227,230,235,237,240,250], xv = "bf6f052bc0000000 bfa47174e0000000 3feda240e0000000 bfae461bc0000000 bfc36e9da0000000 3fa38a5180000000 3f9392e900000000 bfdc70c920000000 3f8fe08d20000000 bfbea1f780000000 bf784ea560000000 3f9972c140000000 bfa2b59b40000000 3fb170ecc0000000 3fc108eae0000000 3f9d3b6060000000 3fa74c0b60000000 3fa1375640000000 bf7e78b940000000 3fe1d2ffa0000000 3fbb9841a0000000 3f976c1a60000000 3f79672780000000 bfa3729d40000000 bf619a9e80000000 3f954ed660000000 bf8dec6ba0000000 bfc2b07840000000 3fa1e94fe0000000 bfa85e76a0000000 bfb07dc920000000 3f917384e0000000 bf82a4a1c0000000 3fa0934720000000 3f6e39cd40000000 bfb81e59c0000000 bf877718c0000000 bfe308f600000000 3f76c4cf60000000 bf9842b820000000 3f390672a0000000 bfb7310d40000000 bf74c41e20000000 bf9c8606c0000000 bfa175c600000000 bfb2b24860000000 bf9ca66840000000 bfb2756bc0000000 bf7cb1e8c0000000 bfbf0f02c0000000 3f7825f640000000 bfa2aeaf60000000 bf7ba5a060000000 bf87fb8d60000000 3f76e11cc0000000 3fe02d3cc0000000 bfd3356e40000000 3fda773280000000 bfc91df600000000 3fb50bdbc0000000 bfb9f73740000000 bfb3028a00000000 bf883f35c0000000 3f9a2ba460000000 3f6a32d240000000 3fc2433900000000 3f49db8e80000000 bfaf9e5d60000000 bf88d2e520000000 3fa8665300000000",
    xcur = "bf6f02a7a0000000 3fc108e840000000 3fa1e899c0000000 bf74cd85e0000000 bfd3358560000000 bfa4714d80000000 3f9d3bc9c0000000 bfa85e6160000000 bf9c87d4a0000000 3fda775800000000 3feda22d80000000 3fa74c8b20000000 bfb07db720000000 bfa17553c0000000 bfc91dcee0000000 3f99736be0000000 3f954f52c0000000 bf984368e0000000 bf87fb6ee0000000 bfaf9f1de0000000 3fb170fa00000000 bfc2b05040000000 bfb731b700000000 3fe02d4ec0000000 3fa866f480000000 bfae468ea0000000 3fa137ae80000000 3f917420c0000000 bfb2b2dbc0000000 3fb50c6480000000 bfc36e88a0000000 bf7e74fdc0000000 bf82a17f80000000 bf9ca59320000000 bfb9f6d4e0000000 bf7853ab80000000 bf619f4b20000000 3f76c9f9a0000000 bf7babc540000000 3f49e00f60000000 3fa38ac4a0000000 3fe1d305a0000000 3fa092cde0000000 bfb27548a0000000 bfb302a040000000 bfbea23f80000000 bfa37238e0000000 bfe3090520000000 bfa2af2ba0000000 3fc2434600000000 3f8fdd5bc0000000 3f79648c80000000 bf8774b280000000 3f78237180000000 3f6a309f20000000 bfdc70ba60000000 3f976c1c80000000 bfb81e31e0000000 bfbf0f4b00000000 3f9a2aebe0000000 3f93916520000000 3fbb967460000000 3f6e375320000000 bf7cb109c0000000 bf883d1b60000000 bfa2b569a0000000 bf8debcb40000000 3f391299c0000000 3f76e11ba0000000 bf88d28500000000",
    xprev = "bf6f2b77c0000000 3fc109cc20000000 3fa1ecfd80000000 bf74d14fa0000000 bfd3351ba0000000 bfa4716be0000000 3f9d3e12e0000000 bfa85c3660000000 bf9c8ddd80000000 3fda75be40000000 3feda101c0000000 3fa748b940000000 bfb07eae00000000 bfa17603c0000000 bfc91e90a0000000 3f997b5560000000 3f95574640000000 bf984a96e0000000 bf88052400000000 bfafa8f1c0000000 3fb1742d20000000 bfc2b0d9a0000000 bfb73229c0000000 3fe02cf900000000 3fa867d860000000 bfae47f6c0000000 3fa13972c0000000 3f91755c40000000 bfb2b3ce80000000 3fb50e1d80000000 bfc3703060000000 bf7e862360000000 bf82a38820000000 bf9ca45160000000 bfb9f8ecc0000000 bf785b48c0000000 bf61a5e2a0000000 3f76d1b520000000 bf7bb4e0e0000000 3f49e3e340000000 3fa38b5fe0000000 3fe1d2f7e0000000 3fa0934000000000 bfb27709e0000000 bfb303f3c0000000 bfbea49320000000 bfa3720cc0000000 bfe30848c0000000 bfa2ae5540000000 3fc2444d80000000 3f8ffbdfa0000000 3f797b9500000000 bf878a6180000000 3f7838fba0000000 3f6a49fb80000000 bfdc6f0560000000 3f976e22c0000000 bfb81f1240000000 bfbf0fbe40000000 3f9a2868c0000000 3f938c67c0000000 3fbb9028c0000000 3f6e34c180000000 bf7cadaee0000000 bf88367420000000 bfa2ba8720000000 bf8df44f20000000 3f3927fa20000000 3f76e64e80000000 bf88d89a00000000",
    y = "bf6f02a7a0000000 3fc108e840000000 3fa1e899c0000000 bf74cd85e0000000 bfd3358560000000 bfa4714d80000000 3f9d3bc9c0000000 bfa85e6160000000 bf9c87d4a0000000 3fda775800000000 3feda22d80000000 3fa74c8b20000000 bfb07db720000000 bfa17553c0000000 bfc91dcee0000000 3f99736be0000000 3f954f52c0000000 bf984368e0000000 bf87fb6ee0000000 bfaf9f1de0000000 3fb170fa00000000 bfc2b05040000000 bfb731b700000000 3fe02d4ec0000000 3fa866f480000000 bfae468ea0000000 3fa137ae80000000 3f917420c0000000 bfb2b2dbc0000000 3fb50c6480000000 bfc36e88a0000000 bf7e74fdc0000000 bf82a17f80000000 bf9ca59320000000 bfb9f6d4e0000000 bf7853ab80000000 bf619f4b20000000 3f76c9f9a0000000 bf7babc540000000 3f49e00f60000000 3fa38ac4a0000000 3fe1d305a0000000 3fa092cde0000000 bfb27548a0000000 bfb302a040000000 bfbea23f80000000 bfa37238e0000000 bfe3090520000000 bfa2af2ba0000000 3fc2434600000000 3f8fdd5bc0000000 3f79648c80000000 bf8774b280000000 3f78237180000000 3f6a309f20000000 bfdc70ba60000000 3f976c1c80000000 bfb81e31e0000000 bfbf0f4b00000000 3f9a2aebe0000000 3f93916520000000 3fbb967460000000 3f6e375320000000 bf7cb109c0000000 bf883d1b60000000 bfa2b569a0000000 bf8debcb40000000 3f391299c0000000 3f76e11ba0000000 bf88d28500000000"),
  "f32/sgl_contig" => (passes = 16, nactive = 9, active = [1,2,42,4,12,13,26,41,40],
    hist = [45,9,3,250], k = [1,1,1,1,1,1,1,2,3,4,5,1,2,3,3,3],
    obj = "3ffb93f800000000 3ff831a0c0000000 3ff6edec60000000 3ff65a2e00000000 3ff60e0dc0000000 3ff5eeb1a0000000 3ff5e0c620000000 3ff5da4f80000000 3ff5d6ba40000000 3ff5d52dc0000000 3ff5d4b300000000 3ff5d49fa0000000 3ff5d49fa0000000 3ff5d49f80000000 3ff5d49f80000000 3ff5d49f80000000",
    xi = [3,6,7,8,17,60,61,62,126,127,129,130,200,201,202,203,204,206,208,210], xv = "3ff1f7c080000000 bf8db73800000000 3f873891e0000000 bfae434e20000000 bfe52bfac0000000 3fe335a860000000 3fd1211960000000 3fa4366bc0000000 bfa36f6cc0000000 bfa7513b00000000 bfa165d800000000 bfe8797660000000 3fe4b8e240000000 bfe0acefa0000000 3fe4e4b1e0000000 bfbb367680000000 3faed6f1a0000000 3f97e52960000000 bf9b398600000000 bf80258000000000",
    xcur = "0 0 3ff1f80040000000 0 0 bf8db9a560000000 3f8733b080000000 bfae429f80000000 0 0 3f97e34f40000000 0 bf9b378620000000 0 bf80265140000000 0 bfe52c06e0000000 0 0 0 0 0 0 0 3fe335de60000000 3fd12169e0000000 3fa43959c0000000 0 0 0 bfa36f9860000000 bfa7547a80000000 0 bfa164c240000000 bfe878fe80000000 bfe0acd720000000 3fe4e4d060000000 bfbb365100000000 3faed6e680000000 0 0 0 0 0 3fe4b8f320000000",
    xprev = "0 0 3ff1f87fc0000000 0 0 bf8dbc9c60000000 3f87292d00000000 bfae406860000000 0 0 3f97ddae40000000 0 bf9b3195e0000000 0 bf80258680000000 0 bfe52c3980000000 0 0 0 0 0 0 0 3fe3364560000000 3fd121eda0000000 3fa43d6660000000 0 0 0 bfa3703760000000 bfa75882e0000000 0 bfa1624a40000000 bfe8785f40000000 bfe0acb8c0000000 3fe4e51980000000 bfbb35be40000000 3faed5fec0000000 0 0 0 0 0 3fe4b92640000000",
    y = "0 0 3ff1f7cd40000000 0 0 bf8db875c0000000 3f8737e520000000 bfae438260000000 0 0 3f97e58fa0000000 0 bf9b39e640000000 0 bf8026a260000000 0 bfe52bf2a0000000 0 0 0 0 0 0 0 3fe335b520000000 3fd1213520000000 3fa437bb20000000 0 0 0 bfa36f58c0000000 bfa752dd80000000 0 bfa165bf00000000 bfe8793e40000000 bfe0ace340000000 3fe4e4b320000000 bfbb368bc0000000 3faed74340000000 0 0 0 0 0 3fe4b8dea0000000"),
  "f32/sgl_strided" => (passes = 23, nactive = 11, active = [1,2,3,17,40,6,8,30,10,11,50],
    hist = [55,11,4,250], k = [1,1,1,1,1,1,1,1,1,2,3,1,2,3,4,5,6,1,2,3,4,4,4],
    obj = "3ff9588440000000 3ff6c566a0000000 3ff5b7d5a0000000 3ff52d30a0000000 3ff4d6ba80000000 3ff49b2300000000 3ff4718ea0000000 3ff456c2e0000000 3ff4483cc0000000 3ff4403ae0000000 3ff43a9f80000000 3ff4376ee0000000 3ff436a080000000 3ff4361900000000 3ff435d080000000 3ff435b200000000 3ff435a940000000 3ff435a880000000 3ff435a860000000 3ff435a840000000 3ff435a840000000 3ff435a840000000 3ff435a840000000",
    xi = [3,6,8,11,17,30,40,51,56,60,61,90,100,102,103,117,130,150,156,160,167,200,201,202,203,206,208,210,230], xv = "3ff2359f20000000 bf8109bce0000000 bfb59557a0000000 3f74bb2cc0000000 bfe64e8600000000 bf65b419a0000000 bf8037da00000000 3fb4835560000000 3f5a74c800000000 3fe44bcae0000000 3fd2cb1c80000000 bf18352f40000000 bfacd6bd40000000 bfa0881200000000 bf5cb8fd40000000 bf94bc7a00000000 bfea136ce0000000 bf78bb7be0000000 bf89f99480000000 bf5c80d4a0000000 bfb1bb8280000000 3fe5781080000000 bfdd030200000000 3fe3c573a0000000 bfb961bbe0000000 3f91bc1780000000 bfb022af80000000 bf917f8be0000000 3fa4aa9420000000",
    xcur = "0 3fb48159a0000000 0 0 bfdd038400000000 0 0 bfa088c7a0000000 0 3fe3c5cf80000000 3ff235ed80000000 0 bf5cda5480000000 0 bfb96085c0000000 bfe64ef780000000 0 bf94b9d240000000 bfb1ba5b60000000 0 bf802dfd80000000 bf18098600000000 0 0 0 bf81025280000000 3f5a62d7e0000000 0 bf89ededa0000000 3f91b411a0000000 bfb593ece0000000 0 0 0 bfb021e860000000 bf6588c600000000 0 bfea13b8c0000000 0 3fa4a66a20000000 0 3fe44bc020000000 0 bf5c7caa00000000 bf917d6a60000000 3f74c14e40000000 3fd2cbe5e0000000 0 0 0 0 bfacd4e820000000 bf78a9c640000000 3fe5785420000000 0",
    xprev = "0 3fb47f4600000000 0 0 bfdd040c40000000 0 0 bfa0891ec0000000 0 3fe3c62f80000000 3ff2364220000000 0 bf5d06e5e0000000 0 bfb95f1b00000000 bfe64f6ae0000000 0 bf94b61100000000 bfb1b92500000000 0 bf8022ac80000000 bf17d1f300000000 0 0 0 bf80fa0500000000 3f5a4f5460000000 0 bf89e11b20000000 3f91ab1780000000 bfb5926900000000 0 0 0 bfb0210060000000 bf656a3800000000 0 bfea140cc0000000 0 3fa4a23480000000 0 3fe44bbb80000000 0 bf5c86ce00000000 bf917b31a0000000 3f74c754a0000000 3fd2ccbac0000000 0 0 0 0 bfacd2a380000000 bf7899abc0000000 3fe578a500000000 0",
    y = "0 3fb4826380000000 0 0 bfdd033fe0000000 0 0 bfa0889c00000000 0 3fe3c59f80000000 3ff235c340000000 0 bf5cc40bc0000000 0 bfb9613b20000000 bfe64ebdc0000000 0 bf94bbb2e0000000 bfb1baf680000000 0 bf8033a600000000 bf18254f80000000 0 0 0 bf81067940000000 3f5a6c99a0000000 0 bf89f456e0000000 3f91b88ec0000000 bfb594aec0000000 0 0 0 bfb0225c60000000 bf65980d00000000 0 bfea138ec0000000 0 3fa4a88500000000 0 3fe44bc280000000 0 bf5c779800000000 bf917e86c0000000 3f74be4b00000000 3fd2cb7b80000000 0 0 0 0 bfacd60a80000000 bf78b1d380000000 3fe5782bc0000000 0"),
)
# the solve with CDSolver(; order = :cyclic, momentum = false) on the strided groups, same base and data
const FT27_CYCLIC = (passes = 62, minimum = "400230aa6815617c", active = [1,2,3,50,17,13,30,34,11,10],
  xi = [1,2,3,10,11,13,17,30,34,50,51,52,53,60,61,63,67,80,84,100,101,102,103,110,111,113,117,130,134,150,151,152,153,160,161,163,167,180,184,200,201,202,203,210,211,213,217,230,234,250], xv = "3f94e1b239985af2 bf8a08c8d205b1a9 3ff23fe2597fd7b8 bf82704c3351ea26 3f8b25e397687326 3f4c1cde08e4b673 bfe33ba09b034591 3fa334818b36c8d8 3fb63357d8883e37 3fc2ee7fa72b580c bfa0d1590c950a28 bfae8aff6bf93cc8 bfa812fc1d1859d3 3fd2b1462ae894b2 3fd116ae3ecb6b6a 3f609460d9c689e0 3fb5f3c750a79f82 bf8f03df49453ec0 bfb1f2d73e9372c9 3f9c948f3d98805a bfa77267c9481362 bf8f83edea9bdd70 3fb83ca347df448f 3fb49894d2f62ac5 3f98945ed384263d 3f71b09a4d7539c8 3f39fda064ac55a7 bfe2a6de7ea9b05d 3fc572aa588450c2 bfaef3cfbe3650fb bf840ffdc9378745 3fa8aa26aaaab9d3 bfabe1455ee41589 3f8bb59357eb1f29 3f86609c4a75b2b3 bf6be074d84688d4 3f998ea84834460b bf9d2b61162d4b16 bfb26ce11af5ad93 3fe18e8d8c35241a bfd7439e4f956e34 3fd4d1adf72c317e bf9e174e2ab4a85d bfa5107e0276c54f bfa1ed499c62d933 bf74c0511d9ef013 3fb798715a49c6fe bf9bc2f461e0d4ee 3f88cf0deae4877b 3fb258dece3e348b")

ft27_vec(s) = [reinterpret(Float64, parse(UInt64, w; base = 16)) for w in split(s)]

function ft27_lassodata(T; n = 100, p = 250, seed = 11)
  rng = Xoshiro(seed)
  X = randn(rng, T, n, p)
  β = zeros(T, p); idx = [3, 17, 60, 61, 130, 200, 201, 202]
  β[idx] .= T[1.5, -1, 0.8, 0.6, -1.2, 1, -0.7, 0.9]
  X, X * β .+ T(0.3) .* randn(rng, T, n)
end

ft27_groupsets(p) = Dict(
  "contig" => [i:i+4 for i in 1:5:p],
  "strided" => [k:(p ÷ 5):p for k in 1:(p ÷ 5)],
  "vecperm" => (perm = randperm(Xoshiro(5), p); [perm[i:i+4] for i in 1:5:p]),
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

ft27_close(a, b, T) = length(a) == length(b) &&
  all(isapprox(a[i], b[i]; rtol = T === Float64 ? 1e-12 : 1e-5, atol = T === Float64 ? 1e-14 : 1e-7) for i in eachindex(a))

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
        @test Float64(obj) ≈ ft27_vec(rec.obj)[end] rtol = (T === Float64 ? 1e-12 : 1e-5)
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
