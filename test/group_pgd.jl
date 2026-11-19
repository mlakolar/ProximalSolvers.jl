module GroupPGD
# Group lasso with ProximalGradientDescent and AccProxGradDescent on a dense Vector (#395): `solve!(x, f,
# g::GroupNormL2{T}, method, options)` minimizes (s/2)‖y - Xβ‖² + λ Σₖ wₖ ‖β[Gₖ]‖₂. The references are computed
# here from the stored data in 256-bit BigFloat, not with ProximalBase's kkt_violation or the solver's helpers:
#  * the objective, the group KKT residual r = max(0, maxₖ scoreₖ) (scoreₖ = ‖∇_G + cₖ β_G/‖β_G‖‖ at a nonzero
#    group, ‖∇_G‖ - cₖ at a zero group, cₖ = λ wₖ) and the scale S = max(maxₖ cₖ, maxₖ ‖[∇f(0)]_G‖);
#  * the closed-form block soft threshold for designs with block-orthogonal columns, a BigFloat proximal gradient
#    reference for a correlated design, and the least-squares fit for λ = 0.
# A solve through `gsolve` (either method) that reports converged = true is checked against the independent residual (`check_flag`); the
# solver's flags are not otherwise used for acceptance.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers
const PGD = ProximalGradientDescent
const APG = AccProxGradDescent
const METHODS = (PGD(), APG())
mname(method) = method isa PGD ? :pgd : :apg

# ---------------------------------------------------------------------------------------------------------
# Targets (quality, not bits: #305) and options
# ---------------------------------------------------------------------------------------------------------
# independent residual relative to S, relative objective gap, coefficient error relative to max(1, ‖β‖∞)
kkt_target(::Type{T}) where T = T === Float64 ? 1e-8 : 1e-3
gap_target(::Type{T}) where T = T === Float64 ? 1e-10 : 1e-5
coef_target(::Type{T}) where T = T === Float64 ? 1e-8 : 1e-3
strict(::Type{T}) where T = ProximalOptions(maxiter = 50_000, ftol = 0, xtol = 1e-300,
                                            gradtol = T === Float64 ? 1e-11 : 1e-6, allow_f_increases = true)

lossof(X, y, s) = s === nothing ? LeastSquaresLoss(y, X) : s * LeastSquaresLoss(y, X)
sval(::Type{T}, s) where T = s === nothing ? one(T) : s

# ---------------------------------------------------------------------------------------------------------
# Independent references, in BigFloat from the stored data
# ---------------------------------------------------------------------------------------------------------
# For the problem (s/2)‖y - Xβ‖² + Σₖ cₖ ‖β[Gₖ]‖₂ with cₖ = λ0 wₖ (exact products of the stored parameters) at the
# point x: the residual r, the scale S, Λ = maxₖ ‖[∇f(0)]_G‖₂ and its ∞-norm counterpart Λinf = ‖∇f(0)‖∞, the
# objective, and two first-order rounding allowances for what the solver computes in T (u = eps(T), twice the unit
# roundoff, as slack): E for its residual (the gradient from fl(X x) - y and fl(Xᵀ d), the group residual of
# ProximalBase, and cₖ rounded in T) and EΛ for its Λ (the product Xᵀy and the group norm). They are estimates under
# that error model, not bounds for every BLAS kernel.
function independent(X, y, s, groups, λ0, w, x)
  T = eltype(X)
  setprecision(BigFloat, 256) do
    Xb, yb, xb, sb = big.(X), big.(y), big.(x), big(s)
    n, p = size(X)
    d = Xb * xb - yb
    ∇ = sb .* (Xb' * d)
    b0 = sb .* (Xb' * yb)
    mag = sb .* (abs.(Xb)' * (abs.(Xb) * abs.(xb) .+ abs.(yb)))
    mag0 = sb .* (abs.(Xb)' * abs.(yb))
    u = big(eps(T))
    r, Λ, E, EΛ, pen, cmax = big(0), big(0), big(0), big(0), big(0), big(0)
    for (k, G) in enumerate(groups)
      c = big(λ0) * big(w[k])
      cmax = max(cmax, c)
      vG, xG = ∇[G], xb[G]
      nx = norm(xG)
      r = max(r, iszero(nx) ? norm(vG) - c : norm(vG .+ (c / nx) .* xG))
      Λ = max(Λ, norm(b0[G]))
      E = max(E, (n + p + 8) * u * norm(mag[G]) + (length(G) + 8) * u * (norm(vG) + c) + u * c)
      EΛ = max(EΛ, (n + length(G) + 8) * u * norm(mag0[G]))
      pen += c * nx
    end
    (; r, S = max(cmax, Λ), Λ, Λinf = maximum(abs, b0), E, EΛ, obj = sb / 2 * sum(abs2, d) + pen)
  end
end
independent(X, y, s, g::GroupNormL2, x) = independent(X, y, s, g.groups, g.λ0, g.w, x)

# max over groups with wₖ > 0 of s‖[Xᵀy]_G‖/wₖ: the smallest level at which 0 is a minimizer (all weights positive)
lambda_max(X, y, s, groups, w) = setprecision(BigFloat, 256) do
  b = big(s) .* (big.(X)' * big.(y))
  maximum(k -> norm(b[groups[k]]) / big(w[k]), filter(k -> w[k] > 0, eachindex(groups)))
end

const NSOLVES = Ref(0)
const NCONV = Ref(0)

# A solve that reports converged = true has an independent residual below the threshold of the check,
# max(gradtol, 64 eps(T)) S, with the rounding allowances above.
function check_flag(label, X, y, s, g, x, res, options)
  T = eltype(X)
  ind = independent(X, y, s, g, x)
  NSOLVES[] += 1
  if res.converged
    NCONV[] += 1
    τ = max(big(options.gradtol), 64 * big(eps(T)))
    ok = ind.r <= τ * (ind.S + ind.EΛ) * (1 + 8 * big(eps(T))) + ind.E
    @test (label, ok) == (label, true)
  end
  ind
end

# `method` from a copy of x0; returns the point, the result and the independent quantities. `gref` is the penalty
# whose mathematics the independent check uses (g itself, or the singleton GroupNormL2 for a NormL1 run).
function gsolve(label, method, X, y, s, g, x0, options; gref = g)
  x = copy(x0)
  res = solve!(x, lossof(X, y, s), g, method, options)
  @test res.minimizer === x
  x, res, check_flag(label, X, y, sval(eltype(X), s), gref, x, res, options)
end

# ---------------------------------------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------------------------------------
hadamard(m) = m == 1 ? ones(Int, 1, 1) : (H = hadamard(m ÷ 2); [H H; H -H])

# Groups of sizes `sizes`, each on its own rows with the first columns of a ±1 Hadamard matrix of order dₖ, so that
# X_Gᵀ X_G = dₖ I exactly and the columns of different groups are orthogonal.
function block_orthogonal(::Type{T}, seed) where T
  sizes, orders = [2, 3, 1, 4, 2], [4, 4, 2, 8, 4]
  n, p = sum(orders), sum(sizes)
  X = zeros(T, n, p)
  groups = UnitRange{Int}[]
  r = c = 0
  for (m, d) in zip(sizes, orders)
    X[r+1:r+d, c+1:c+m] .= T.(hadamard(d)[:, 1:m])
    push!(groups, c+1:c+m)
    r += d
    c += m
  end
  X, T.(2 .* randn(Xoshiro(seed), n)), groups, orders
end

# β_G = max(0, 1 - cₖ/(s‖uₖ‖)) uₖ/dₖ with uₖ = X_Gᵀ y, the minimizer of (s/2)‖y - Xβ‖² + Σ cₖ‖β_G‖ when
# X_Gᵀ X_G = dₖ I and the groups have disjoint rows. (d = 1, s = 1, u = 2, c = 1: β = 1, where ½(β - 2)² + |β| has
# derivative β - 1 = 0; with s = 1/2, β = 0.)
function block_threshold(X, y, s, groups, orders, λ0, w)
  setprecision(BigFloat, 256) do
    b = big.(X)' * big.(y)
    β = zeros(BigFloat, size(X, 2))
    for (k, G) in enumerate(groups)
      uk, c = b[G], big(λ0) * big(w[k])
      β[G] = max(big(0), 1 - c / (big(s) * norm(uk))) .* uk ./ orders[k]
    end
    β
  end
end

# n = 30, p = 10, AR(1) columns with correlation 0.6, groups of sizes 3, 1, 2 and 4 in permuted order
const CGROUPS = [[7, 2, 5], [1], [10, 3], [4, 6, 8, 9]]
function correlated(::Type{T}) where T
  rng = Xoshiro(395)
  n, p, ρ = 30, 10, 0.6
  Z = randn(rng, n, p)
  X = similar(Z)
  X[:, 1] = Z[:, 1]
  for j in 2:p
    X[:, j] = ρ * X[:, j-1] + sqrt(1 - ρ^2) * Z[:, j]
  end
  β0 = zeros(p)
  β0[[7, 2, 5]] = [1.0, -0.5, 0.8]
  β0[[4, 6, 8, 9]] = [0.3, 0.0, -0.6, 0.4]
  T.(X), T.(X * β0 + 0.5 * randn(rng, n))
end

# A BigFloat proximal gradient reference with step 1/L, L above s λmax(XᵀX), run until its BigFloat group residual
# is at most rtol S. Returns the point (in BigFloat) and whether that residual was reached.
function reference(X, y, s, g; rtol = big"1e-25", maxiter = 200_000)
  setprecision(BigFloat, 256) do
    Xb, yb, sb = big.(X), big.(y), big(s)
    A, b = Xb' * Xb, Xb' * yb
    L = big(1.000001) * sb * big(eigmax(Symmetric(Float64.(A))))
    c = [big(g.λ0) * big(g.w[k]) for k in eachindex(g.groups)]
    β = zeros(BigFloat, size(X, 2))
    for it in 1:maxiter
      z = β .- (sb .* (A * β .- b)) ./ L
      for (k, G) in enumerate(g.groups)
        nz = norm(z[G])
        β[G] = iszero(nz) ? zero(z[G]) : max(big(0), 1 - c[k] / (L * nz)) .* z[G]
      end
      if it % 25 == 0
        ind = independent(X, y, s, g, β)
        ind.r <= rtol * ind.S && return β, true
      end
    end
    β, false
  end
end

# a seeded Gaussian design, n = 25, p = 8
function gaussian(::Type{T}, seed = 7) where T
  rng = Xoshiro(seed)
  X = randn(rng, 25, 8)
  T.(X), T.(X * [1.0, -0.5, 0.0, 0.7, 0.0, 0.0, 0.4, -0.3] + 0.3 * randn(rng, 25))
end

# ---------------------------------------------------------------------------------------------------------
# 1. Block-orthogonal designs: the closed form
# ---------------------------------------------------------------------------------------------------------
@testset "block-orthogonal designs against the closed form ($T)" for T in (Float32, Float64)
  X, y, groups, orders = block_orthogonal(T, 11)
  n, p = size(X)
  for s in (nothing, one(T) / T(n)), wkind in (:default, :custom)
    sv = sval(T, s)
    w = wkind === :default ? sqrt.(T.(length.(groups))) : T[1, 0, 2, 1.5, 0.5]
    # the level between the second and third smallest group scores s‖uₖ‖/wₖ (over the penalized groups)
    scores = setprecision(BigFloat, 256) do
      b = big.(X)' * big.(y)
      sort([big(sv) * norm(b[G]) / big(w[k]) for (k, G) in enumerate(groups) if w[k] > 0])
    end
    λ = T(sqrt(scores[2] * scores[3]))
    g = GroupNormL2(λ, groups, w)
    β = block_threshold(X, y, sv, groups, orders, λ, w)
    zero_groups = [k for k in eachindex(groups) if all(iszero, β[groups[k]])]
    label = (T, s === nothing ? :raw : :scaled, wkind)
    @test (label, 1 <= length(zero_groups) < length(groups)) == (label, true)
    ref = independent(X, y, sv, g, β)
    for method in METHODS
      lab = (label..., mname(method))
      x, res, ind = gsolve(lab, method, X, y, s, g, zeros(T, p), strict(T))
      @test (lab, maximum(abs, big.(x) .- β) <= coef_target(T) * max(1, maximum(abs, β))) == (lab, true)
      @test (lab, (ind.obj - ref.obj) / abs(ref.obj) <= gap_target(T)) == (lab, true)
      @test (lab, ind.r <= kkt_target(T) * ind.S) == (lab, true)
      # the groups that are zero at the minimizer, here with a margin of their scores below λ, are zero in x
      @test (lab, all(k -> all(iszero, x[groups[k]]), zero_groups)) == (lab, true)
    end
  end
end

# ---------------------------------------------------------------------------------------------------------
# 2. A correlated design: PGD and group CD against a BigFloat reference
# ---------------------------------------------------------------------------------------------------------
@testset "correlated design: PGD, APG and group CD against a BigFloat reference ($T)" for T in (Float32, Float64)
  X, y = correlated(T)
  n, p = size(X)
  s = one(T) / T(n)
  w = sqrt.(T.(length.(CGROUPS)))
  λ = T(0.3 * lambda_max(X, y, s, CGROUPS, w))
  g = GroupNormL2(λ, CGROUPS, w)
  β, ok = reference(X, y, s, g)
  @test ok
  ref = independent(X, y, s, g, β)
  x, res, ind = gsolve((T, :pgd), PGD(), X, y, s, g, zeros(T, p), strict(T))
  xa, resa, inda = gsolve((T, :apg), APG(), X, y, s, g, zeros(T, p), strict(T))
  xb = BlockIterate(T, p, g)
  cd = solve!(xb, lossof(X, y, s), g, CDSolver(order = :cyclic, tol = T === Float64 ? 1e-12 : 1e-6, maxpasses = 100_000))
  indcd = independent(X, y, s, g, Vector(xb))
  for (label, q) in (((T, :pgd), ind), ((T, :apg), inda), ((T, :cd), indcd))
    @test (label, (q.obj - ref.obj) / abs(ref.obj) <= gap_target(T)) == (label, true)
    @test (label, q.r <= kkt_target(T) * q.S) == (label, true)
  end
  T === Float64 && @test res.converged && resa.converged
end

# ---------------------------------------------------------------------------------------------------------
# 3. Layouts, and singleton groups against NormL1
# ---------------------------------------------------------------------------------------------------------
@testset "layouts ($T)" for T in (Float32, Float64)
  X, y = gaussian(T)
  n, p = size(X)
  s = one(T) / T(n)
  Xz = copy(X)
  Xz[:, 4] .= 0                         # group [4] of the contiguous layout has a zero column
  layouts = [("contiguous ranges", X, [1:3, 4:4, 5:8]),
             ("contiguous vectors", X, [[1, 2, 3], [4], [5, 6, 7, 8]]),
             ("permuted", X, [[7, 2, 5], [1], [8, 3], [4, 6]]),
             ("one group", X, [collect(8:-1:1)]),
             ("zero column", Xz, [1:3, 4:4, 5:8])]
  objs = Dict{String, BigFloat}()
  for (name, Xl, groups) in layouts
    w = sqrt.(T.(length.(groups)))
    λ = T(0.3 * lambda_max(Xl, y, s, groups, w))
    g = GroupNormL2(λ, groups, w)
    label = (T, name)
    x, res, ind = gsolve(label, PGD(), Xl, y, s, g, zeros(T, p), strict(T))
    @test (label, ind.r <= kkt_target(T) * ind.S) == (label, true)
    objs[name] = ind.obj
    name == "zero column" && @test (label, x[4]) == (label, zero(T))
  end
  # ranges and vectors of the same partition: the same problem
  @test abs(objs["contiguous ranges"] - objs["contiguous vectors"]) <= gap_target(T) * abs(objs["contiguous ranges"])

  # Singleton groups with unit weights are the lasso: on this fixture (no entry of ∇f(0) has a subnormal square) the
  # scale S is the lasso's exactly; each solver's own final
  # point meets the independent residual and the objectives agree within the target (the iterates are not compared).
  λ = T(0.2 * lambda_max(X, y, s, [i:i for i in 1:p], ones(p)))
  gs, gl = GroupNormL2(λ, [i:i for i in 1:p], ones(T, p)), NormL1(λ)
  o = strict(T)
  f = lossof(X, y, s)
  for method in METHODS
    st_g = PS.initial_state(method, o, f, gs, zeros(T, p))
    st_l = PS.initial_state(method, o, f, gl, zeros(T, p))
    Sg = max(PS._l1_level(PS._converted_penalty(gs, T)), PS._lambda_max!(st_g, PS._scale_norm(gs)))
    Sl = max(PS._l1_level(PS._converted_penalty(gl, T)), PS._lambda_max!(st_l, PS._scale_norm(gl)))
    @test st_g.λmax == st_l.λmax
    @test Sg == Sl
    xg, rg, ig = gsolve((T, mname(method), :singletons), method, X, y, s, gs, zeros(T, p), o)
    xl, rl, il = gsolve((T, mname(method), :norml1), method, X, y, s, gl, zeros(T, p), o; gref = gs)
    @test ig.r <= kkt_target(T) * ig.S
    @test il.r <= kkt_target(T) * il.S
    @test abs(ig.obj - il.obj) <= gap_target(T) * abs(il.obj)
  end
end

# ---------------------------------------------------------------------------------------------------------
# 4. Penalty edges
# ---------------------------------------------------------------------------------------------------------
@testset "penalty edges ($T)" for T in (Float32, Float64)
  X, y = gaussian(T, 9)
  n, p = size(X)
  s = one(T) / T(n)
  groups = [1:3, 4:4, 5:8]

  # a zero weight leaves its group unpenalized
  g0 = GroupNormL2(T(0.5 * lambda_max(X, y, s, groups, [1, 1, 1])), groups, T[0, 1, 2])
  for method in METHODS
    x, res, ind = gsolve((T, mname(method), :zero_weight), method, X, y, s, g0, zeros(T, p), strict(T))
    @test ind.r <= kkt_target(T) * ind.S
    @test any(!iszero, x[1:3])
  end

  # λ = 0: the least-squares fit
  gz = GroupNormL2(zero(T), groups)
  βls = setprecision(BigFloat, 256) do
    Xb = big.(X)
    (Xb' * Xb) \ (Xb' * big.(y))
  end
  for method in METHODS
    x, res, ind = gsolve((T, mname(method), :lambda0), method, X, y, nothing, gz, zeros(T, p), strict(T))
    @test maximum(abs, big.(x) .- βls) <= coef_target(T) * max(1, maximum(abs, βls))
  end

  # λ = 1.01 λmax with positive weights: the minimizer is 0, and the solve from 0 reports convergence there
  w = sqrt.(T.(length.(groups)))
  gm = GroupNormL2(T(1.01 * lambda_max(X, y, s, groups, w)), groups, w)
  for method in METHODS
    x, res, ind = gsolve((T, mname(method), :above_lambda_max), method, X, y, s, gm, zeros(T, p), ProximalOptions())
    @test all(iszero, x)
    @test res.converged
  end

  # a tiny loss scale and level (α = 1e-300): Λ is computed without underflow and the solve converges
  if T === Float64
    α = 1e-300
    gt = GroupNormL2(α * 0.3 * Float64(lambda_max(X, y, 1.0, groups, w)), groups, w)
    st = PS.initial_state(PGD(), ProximalOptions(), lossof(X, y, α), gt, zeros(T, p))
    Λ = PS._lambda_max!(st, PS._scale_norm(gt))
    ind0 = independent(X, y, α, gt, zeros(T, p))
    @test Λ > 0
    @test abs(big(Λ) - ind0.Λ) <= ind0.EΛ + 4 * big(eps(T)) * ind0.Λ
    x, res, ind = gsolve((T, :tiny), PGD(), X, y, α, gt, zeros(T, p), ProximalOptions(maxiter = 5_000))
    @test res.converged
  end
end

# ---------------------------------------------------------------------------------------------------------
# 5. Refusals leave the caller's vector unchanged
# ---------------------------------------------------------------------------------------------------------
message(e) = sprint(showerror, e)

function refused(E, fragment, x, f, g, method = PGD())
  before = copy(x)
  err = try
    solve!(x, f, g, method)
    nothing
  catch e
    e
  end
  @test err isa E
  @test err !== nothing && occursin(fragment, message(err))
  @test isequal(x, before)
  err
end

@testset "refusals and caller state ($T)" for T in (Float32, Float64)
  X, y = gaussian(T)
  n, p = size(X)
  f = lossof(X, y, nothing)
  λ = T(0.1)
  start() = T[0.5, -0.0, 0.0, -0.25, 0, 0, 1, -0.0]
  gs = [1:2, 3:8]
  for method in METHODS
    refuse(E, fragment, x, f, g) = refused(E, fragment, x, f, g, method)
    partition = "must partition 1:p"
    refuse(ArgumentError, partition, start(), f, GroupNormL2(λ, [1:2, 4:8]))          # a gap
    refuse(ArgumentError, partition, start(), f, GroupNormL2(λ, [1:2, 3:7]))          # short of p
    refuse(DimensionMismatch, "holds the index 9", start(), f, GroupNormL2(λ, [1:2, 3:9]))
    gm = GroupNormL2(λ, [[1, 2], [3, 4, 5, 6, 7, 8]])
    gm.groups[2][1] = 2                                                                # changed after construction
    refuse(ArgumentError, "appears a second time", start(), f, gm)
    # groups changed after construction into a partition that differs from ProximalBase's cached layout, and an empty group
    stale = "differ from the layout it was constructed with"
    X4, y4 = Matrix{T}(I, 4, 4), T[1, 2, 3, 4]
    g1 = GroupNormL2(T(0.5), [[1], [3, 4]], ones(T, 2))
    push!(g1.groups[1], 2)                     # a partition of 1:4; the cached layout leaves 2 in no group
    refuse(ArgumentError, stale, T[0.5, -0.0, 0, 1], lossof(X4, y4, nothing), g1)
    g2 = GroupNormL2(T(0.5), [[1, 2], [3, 4, 5]])
    pop!(g2.groups[2])                         # a partition of 1:4; the cached layout reaches index 5
    refuse(ArgumentError, stale, T[0.5, -0.0, 0, 1], lossof(X4, y4, nothing), g2)
    g3 = GroupNormL2(T(0.1), [[1], [2]], T[1e20, 1])
    empty!(g3.groups[1]); push!(g3.groups[2], 1)
    refuse(ArgumentError, "group 1 is empty", T[10, -0.0], lossof(Matrix{T}(I, 2, 2), T[1, 1], nothing), g3)
    other = T === Float32 ? Float64 : Float32
    refuse(ArgumentError, "GroupNormL2($T(λ0), groups, $T.(w))", start(), f, GroupNormL2(other(0.1), [1:2, 3:8]))
    for v in (T(NaN), T(Inf))
      xb = start(); xb[3] = v
      refuse(ArgumentError, "finite values", xb, f, GroupNormL2(λ, [1:2, 3:8]))
      Xb = copy(X); Xb[2, 2] = v
      refuse(ArgumentError, "finite values", start(), lossof(Xb, y, nothing), GroupNormL2(λ, [1:2, 3:8]))
      yb = copy(y); yb[5] = v
      refuse(ArgumentError, "finite values", start(), lossof(X, yb, nothing), GroupNormL2(λ, [1:2, 3:8]))
    end
    # x aliasing X, y or the weights
    X1 = T.(randn(Xoshiro(3), 1, p))
    refuse(ArgumentError, "must not alias borrowed X or y", vec(X1), lossof(X1, T[1], nothing), GroupNormL2(λ, [1:2, 3:8]))
    Xs, ys = T.(randn(Xoshiro(4), p, p)), T.(randn(Xoshiro(5), p))
    refuse(ArgumentError, "must not alias borrowed X or y", ys, lossof(Xs, ys, nothing), GroupNormL2(λ, [1:2, 3:8]))
    gw = GroupNormL2(λ, [i:i for i in 1:p], ones(T, p))
    refuse(ArgumentError, "must not alias the penalty weights", gw.w, f, gw)
    # level and weights
    refuse(ArgumentError, "penalty lambda must be finite", start(), f, GroupNormL2(T(Inf), gs))
    refuse(ArgumentError, "penalty weight of group 1 must be finite", start(), f, GroupNormL2(zero(T), gs, T[Inf, 1]))
    big_level, big_weight, small_level, small_weight = T === Float64 ? (1e300, 1e10, 1e-300, 1e-10) : (1f30, 1f10, 1f-30, 1f-10)
    refuse(ArgumentError, "coefficient of group 1, lambda * weight in $T, overflows", start(), f,
            GroupNormL2(big_level, gs, T[big_weight, 1]))
    refuse(ArgumentError, "coefficient of group 1, lambda * weight in $T, is subnormal", start(), f,
            GroupNormL2(small_level, gs, T[small_weight, 1]))
    refuse(ArgumentError, "is subnormal in $T", start(), f, GroupNormL2(floatmin(T) / 4, gs))
    @test isnothing(PS._check_problem(start(), f, GroupNormL2(T(0.5), gs, T[0, 1])))    # a zero weight is accepted
  end
  # both gradient methods accept a group penalty on a dense Vector
  for method in METHODS
    x = start()
    res = solve!(x, f, GroupNormL2(λ, gs), method)
    @test res.minimizer === x && any(!iszero, x)
  end
  # CDSolver refuses GroupNormL2 on dense and sparse coefficients, naming its supported alternatives.
  # The refusal must preserve the caller, while PGD and APG above continue accepting dense group lasso.
  err = refused(ArgumentError, "CDSolver does not support GroupNormL2", start(), f, GroupNormL2(λ, gs), CDSolver())
  @test occursin("CDSolver on a BlockIterate", message(err))
  @test occursin("ProximalGradientDescent or AccProxGradDescent on a dense Vector", message(err))
  xs = SparseIterate(T, p)
  xs[3] = T(0.5)
  before = Vector(xs)
  err = try solve!(xs, f, GroupNormL2(λ, gs), CDSolver()) catch e e end
  @test err isa ArgumentError
  @test err !== nothing && occursin("CDSolver does not support GroupNormL2", message(err))
  @test err !== nothing && occursin("CDSolver on a BlockIterate", message(err))
  @test isequal(Vector(xs), before)
  for method in METHODS
    allowed = method isa PGD ?
      "only NormL1, unweighted ElasticNet, NormLinf, GroupNormL2, unweighted NormL1Nonneg, IndNonnegative, IndBox or IndBallL2 is supported" :
      "only NormL1, unweighted ElasticNet, NormLinf, GroupNormL2, IndBox or IndBallL2 is supported"
    refused(ArgumentError, allowed, start(), f, ProximalBase.NormL2(λ), method)
  end
  refused(ArgumentError, "SqrtLeastSquaresLoss", start(), SqrtLeastSquaresLoss(y, X), GroupNormL2(λ, gs))
end

# ---------------------------------------------------------------------------------------------------------
# 6. The stopping check
# ---------------------------------------------------------------------------------------------------------
@testset "the group check just below and just above its threshold ($T)" for T in (Float32, Float64)
  # X = I, groups [1:2, 3:4], unit weights, λ = 1, gradtol = 1e-3: at x = [0.3, 0.4, 0, 0] with y1 = x1 + x1/‖x1‖ the
  # first group scores 0 and the zero group scores ‖y2‖ - 1 = ρ; S = max(1, ‖y1‖ = 1.5, ‖y2‖) = 1.5
  o = ProximalOptions(gradtol = 1e-3)
  g = GroupNormL2(one(T), [1:2, 3:4], ones(T, 2))
  X = Matrix{T}(I, 4, 4)
  x0 = T[0.3, 0.4, 0, 0]
  for method in METHODS, (factor, verdict) in ((0.99, true), (1.01, false))
    y = T[0.9, 1.2, 1 + factor * 1.5e-3, 0]
    state = PS.initial_state(method, o, LeastSquaresLoss(y, X), g, copy(x0))
    calls = state.grad_calls
    @test PS._stationary!(state, LeastSquaresLoss(y, X), g, o) == verdict
    # APG forms ∇f(x) for the check and counts it; PGD holds it
    @test state.grad_calls - calls == (method isa APG ? 1 : 0)
    ind = independent(X, y, one(T), g, x0)
    @test abs(ind.r / ind.S - factor * 1e-3) <= 1e-3 * 1e-3    # the case is placed 1% from the threshold
  end
end

@testset "state.λmax is the largest group norm of ∇f(0) ($T)" for T in (Float32, Float64)
  X, y = correlated(T)
  n, p = size(X)
  s = one(T) / T(n)
  g = GroupNormL2(T(0.01), CGROUPS)
  state = PS.initial_state(PGD(), ProximalOptions(), lossof(X, y, s), g, zeros(T, p))
  Λ = PS._lambda_max!(state, PS._scale_norm(g))
  @test state.λmax == Λ
  ind = independent(X, y, s, g, zeros(T, p))
  allowed = ind.EΛ + 4 * big(eps(T)) * ind.Λ
  @test abs(big(Λ) - ind.Λ) <= allowed
  @test ind.Λ - ind.Λinf > 100 * allowed     # the ∞-norm of ∇f(0) is not within the allowance
end

@testset "a huge xtol or ftol does not stop at a point that fails the check ($T)" for T in (Float32, Float64)
  X, y = correlated(T)
  n, p = size(X)
  s = one(T) / T(n)
  w = sqrt.(T.(length.(CGROUPS)))
  g = GroupNormL2(T(0.3 * lambda_max(X, y, s, CGROUPS, w)), CGROUPS, w)
  for o in (ProximalOptions(xtol = 1e10, maxiter = 5_000, allow_f_increases = true),
            ProximalOptions(ftol = 1e10, maxiter = 5_000, allow_f_increases = true))
    for method in METHODS
      x, res, ind = gsolve((T, mname(method), o.xtol, o.ftol), method, X, y, s, g, fill(T(10), p), o)
      @test res.iterations > 1
    end
  end
end

# ---------------------------------------------------------------------------------------------------------
# 7. Allocations
# ---------------------------------------------------------------------------------------------------------
function solve_bytes(method, f, g, x0, o)
  run() = (x = copy(x0); @allocated solve!(x, f, g, method, o))
  run()
  minimum(run() for _ in 1:3)
end
mask_bytes(p) = (falses(p); @allocated falses(p))

@testset "a warm group solve allocates no more than the lasso solve and the partition mask ($T)" for T in (Float32, Float64)
  X, y = gaussian(T)
  n, p = size(X)
  f = lossof(X, y, nothing)
  o = ProximalOptions(maxiter = 30, ftol = 0, xtol = 1e-300, gradtol = 0, allow_f_increases = true)
  mask = mask_bytes(p)
  for method in METHODS
    lasso = solve_bytes(method, f, NormL1(T(0.5)), zeros(T, p), o)
    for groups in ([1:3, 4:4, 5:8], [[7, 2, 5], [1], [8, 3], [4, 6]])
      group = solve_bytes(method, f, GroupNormL2(T(0.5), groups), zeros(T, p), o)
      println("allocations, $T, $(mname(method)), $(eltype(groups)) groups: group $group bytes, lasso $lasso bytes, mask $mask bytes")
      @test (T, mname(method), eltype(groups), group <= lasso + mask) == (T, mname(method), eltype(groups), true)
    end
  end
end

# the file's own check that the flag checks were exercised
@testset "the solves of this file were exercised" begin
  println("group PGD and APG: $(NSOLVES[]) solves checked, $(NCONV[]) with converged = true")
  @test NSOLVES[] >= 59
  @test NCONV[] >= 30
end

end
