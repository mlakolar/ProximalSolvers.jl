module GroupCD
# Group-lasso block coordinate descent (#275): `solve!(x::BlockIterate, f, g::GroupNormL2, CDSolver(...))`
# minimizes (s/2)‖y - Xβ‖² + λ0 Σₖ wₖ ‖β[Gₖ]‖₂. These tests are written from the public contract and from the
# mathematics, with references that do not use the solver's own formulas:
#  * an independent objective, in BigFloat (256 bits) from the data and the supplied scale;
#  * an independent KKT check in Float64 from the raw data, ∇ = s Xᵀ(Xβ - y): for a penalized group with
#    β_G ≠ 0 the stationarity ‖∇_G + λ0 wₖ β_G/‖β_G‖‖, for a penalized group at 0 the screen ‖∇_G‖ - λ0 wₖ
#    (a group with λ0 wₖ = 0 is unpenalized and must have ‖∇_G‖ ≈ 0);
#  * the analytic block soft threshold for designs with XᵀX = c I;
#  * a pseudoinverse least-squares fit, an independent one-pass simulation, the scalar lasso, and a BigFloat
#    Cholesky test of the curvature majorization λmax(X_Gᵀ X_G) ≤ ℓ.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
using Logging: with_logger, Warn
const PS = ProximalSolvers

# ---------------------------------------------------------------------------
# Tolerances (the pre-registered acceptance criteria) and fixtures
# ---------------------------------------------------------------------------
const TYPES = (Float32, Float64)
# stationarity (relative to max(1, λ0)) and relative zero-group screen
kkt_bound(::Type{T}) where T = T === Float64 ? 1e-8 : 1e-4
solve_tol(::Type{T}) where T = T === Float64 ? 1e-12 : 1e-6
pass_limit(::Type{T}) where T = T === Float64 ? 100_000 : 20_000
# Two solutions of one problem: relative objective difference, and the difference of the fitted values X β
# relative to max(1, ‖y‖). The objective gap of a point is at most about (stationarity × distance) and the
# fitted values are strongly convex in F, ‖Xβ₁ - Xβ₂‖ ≤ 2 √(2 gap / s), so the fitted-value bound is
# about the square root of the objective bound.
obj_rtol(::Type{T}) where T = T === Float64 ? 1e-9 : 1e-3
fit_rtol(::Type{T}) where T = T === Float64 ? 1e-5 : 3e-2
# difference of coefficients of the unique solutions of a full-column-rank problem, relative to max(1, ‖β‖)
coef_rtol(::Type{T}) where T = T === Float64 ? 1e-7 : 1e-3

# The result of f() and its log records.
function logged(f)
  logger = Test.TestLogger()
  r = with_logger(f, logger)
  r, logger.logs
end
warned(logs) = length(logs) == 1 && logs[1].level == Warn && occursin("did not converge", string(logs[1].message))

mkloss(y, X, α) = α === nothing ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)
sval(α) = α === nothing ? 1.0 : Float64(α)
# the penalty type that goes with a loss scale: a Float64 scale on Float32 data is paired with a Float64 penalty
ptype_for(::Type{T}, α) where T = (α isa Float64 && T === Float32) ? Float64 : T

penalty(λ, groups, w, ::Type{P}) where P = w === nothing ? GroupNormL2(P(λ), groups) : GroupNormL2(P(λ), groups, P.(w))

# ---------------------------------------------------------------------------
# Independent references
# ---------------------------------------------------------------------------
# The objective (s/2)‖y - Xβ‖² + λ0 Σ wₖ ‖β[Gₖ]‖₂ formed in the number type R from the data and the penalty
function objective_in(::Type{R}, X, y, s, g, β) where R
  Xr, yr, βr = R.(X), R.(y), R.(β)
  r = yr - Xr * βr
  pen = zero(R)
  for (k, G) in enumerate(g.groups)
    pen += R(g.λ0) * R(g.w[k]) * sqrt(sum(abs2, βr[G]))
  end
  R(s) / 2 * sum(abs2, r) + pen
end
objective_big(X, y, s, g, β) = setprecision(BigFloat, 256) do
  Float64(objective_in(BigFloat, X, y, s, g, β))
end
objective_wide(X, y, s, g, β) = objective_in(Float64, X, y, s, g, β)
# the scale (s/2)‖y‖² + penalty at β against which objective differences are measured
objective_scale(X, y, s, g, β) = s / 2 * sum(abs2, Float64.(y)) + objective_wide(X, y, 0.0, g, β) + 1.0e-300

# The independent full KKT of β for the problem: `stat` is the largest stationarity of a penalized group
# with β_G ≠ 0 or of an unpenalized group (λ0 wₖ = 0, then ‖∇_G‖), and `screen` is the largest
# (‖∇_G‖ - λ0 wₖ)/(λ0 wₖ) over penalized groups at 0 (-Inf where there is none).
function kkt_report(X, y, s, g, β)
  Xd, yd, βd = Float64.(X), Float64.(y), Float64.(Vector(β))
  ∇ = s .* (Xd' * (Xd * βd .- yd))
  λ = Float64(g.λ0)
  stat, screen = 0.0, -Inf
  for (k, G) in enumerate(g.groups)
    c = λ * Float64(g.w[k])
    gk, bk = ∇[G], βd[G]
    if iszero(c)
      stat = max(stat, norm(gk))
    elseif all(iszero, bk)
      screen = max(screen, (norm(gk) - c) / c)
    else
      stat = max(stat, norm(gk .+ (c / norm(bk)) .* bk))
    end
  end
  (; stat, screen)
end

# λmax = max over penalized groups of ‖s X_Gᵀ y‖/wₖ: at or above it β = 0 is a solution
function lambda_max(X, y, s, groups, w)
  b = s .* (Float64.(X)' * Float64.(y))
  maximum(k -> norm(b[groups[k]]) / Float64(w[k]), filter(k -> w[k] > 0, eachindex(groups)))
end

# The independent checks of a finished solve
function check_solution(X, y, α, g, x, res; converged = true)
  T = eltype(X)
  s = sval(α)
  n, p = size(X)
  rep = kkt_report(X, y, s, g, x)
  @test rep.stat <= kkt_bound(T) * max(1.0, Float64(g.λ0))
  @test rep.screen <= kkt_bound(T)
  for (k, G) in enumerate(g.groups)
    # after a run of at least one pass, a group is active when it holds a nonzero entry (each pass is
    # followed by `dropzeros!`) and not otherwise, and an inactive group holds +0.0
    nonzero = any(i -> !iszero(x[i]), G)
    @test isactive(x, k) == nonzero
    nonzero || @test all(i -> isequal(x[i], zero(T)), G)
  end
  # results
  @test res.minimizer === x
  @test typeof(res) == CDResults{typeof(x), T}
  @test res.kkt_checks == 0
  @test isnan(res.gap)
  @test res.passes >= 1
  if converged
    @test res.converged
    @test res.maxchange < res.tolerance
  end
  obj = objective_big(X, y, s, g, Vector(x))
  @test abs(Float64(res.minimum) - obj) <= 16 * (n + p) * eps(T) * objective_scale(X, y, s, g, Vector(x))
  rep
end

# One solve of f + g from x (a BlockIterate, solved in place) with its own seeded generator
function run_group_cd(X, y, α, g, x; order = :cyclic, seed = 11, tol = solve_tol(eltype(X)),
                      maxpasses = pass_limit(eltype(X)), relative = true)
  rng = Xoshiro(seed)
  solver = CDSolver(; order, maxpasses, tol, relative, rng)
  res, logs = logged(() -> solve!(x, mkloss(y, X, α), g, solver))
  (; res, x, logs, rng)
end
# a solve from `x0` (default the empty iterate) followed by the independent checks
function solve_and_check(X, y, α, g; x0 = nothing, kw...)
  T = eltype(X)
  x = x0 === nothing ? BlockIterate(T, size(X, 2), g) : x0
  out = run_group_cd(X, y, α, g, x; kw...)
  @test all(l -> l.level == Warn && occursin("did not converge", string(l.message)), out.logs)
  check_solution(X, y, α, g, x, out.res)
  out
end

# ---------------------------------------------------------------------------
# Problem generators
# ---------------------------------------------------------------------------
# Designs: :plain Gaussian; :correlated (a shared factor: correlation about 0.7); :duplicate (columns p and
# p-1 repeat columns 1 and 2); :scaled (column scales 10^-d … 10^d, d = 3 for Float64 and 1 for Float32,
# where the rounding of a Float32 gradient is about eps(Float32) times the scale of the column, which must
# stay well below the bound);
# :wide (a plain design; the caller takes n < p).
# The columns of Z have norm about 1 and ‖y‖ is of order 1, so that the gradient is of order 1 and the
# stationarity bound, absolute for a penalty up to 1 and relative to λ0 above it, is a relative accuracy.
# In a probe before this scaling, with entries of order 1 (gradients of order ‖X‖², about 100 here), Float32
# solves at the tolerance 1e-6 ended with stationarities between 1e-4 and 2e-3, above the bound 1e-4. Two
# causes: the stopping rule bounds one pass's change, not the distance to the solution (the stationarity can
# be that change divided by one minus the contraction factor of the passes), and the rounding of the
# iterate, about eps(Float32) ‖X‖² ‖β‖.
function make_design(::Type{T}, kind::Symbol, n, p; seed) where T
  rng = Xoshiro(seed)
  Z = randn(rng, n, p) ./ sqrt(n)
  β0 = [rand(rng) < 0.4 ? 2randn(rng) : 0.0 for _ in 1:p]
  y = Z * β0 .+ 0.5 .* randn(rng, n) ./ sqrt(n)
  X = if kind === :plain || kind === :wide
    Z
  elseif kind === :correlated
    Z .+ 1.5 .* randn(rng, n) ./ sqrt(n)
  elseif kind === :duplicate
    D = copy(Z)
    D[:, p] = D[:, 1]
    D[:, p - 1] = D[:, 2]
    D
  elseif kind === :scaled
    d = T === Float64 ? 3 : 1
    Z .* (10.0 .^ range(-d, d; length = p))'
  else
    error("unknown design $kind")
  end
  Matrix{T}(X), Vector{T}(y)
end

function split_sizes(v, sizes)
  out = Vector{Vector{Int}}()
  pos = 1
  for s in Iterators.cycle(sizes)
    pos > length(v) && break
    e = min(pos + s - 1, length(v))
    push!(out, v[pos:e])
    pos = e + 1
  end
  out
end
function layout(kind::Symbol, p; seed = 1)
  rng = Xoshiro(seed)
  if kind === :one
    [collect(1:p)]
  elseif kind === :one_range
    [1:p]
  elseif kind === :singletons
    [[j] for j in 1:p]
  elseif kind === :contiguous
    UnitRange{Int}[(first(G):last(G)) for G in split_sizes(collect(1:p), (3, 1, 4, 2, 2))]
  elseif kind === :strided                  # group j holds j, j+K, j+2K, …: sorted but not contiguous
    K = max(2, p ÷ 3)
    [collect(j:K:p) for j in 1:K]
  elseif kind === :reordered                # unsorted indices inside the groups, groups in no index order
    split_sizes(randperm(rng, p), (2, 3, 1, 4))
  elseif kind === :many                     # groups of two
    split_sizes(collect(1:p), (2,))
  else
    error("unknown layout $kind")
  end
end

# weights: nothing (the default √|G|), explicit in [0.5, 2], or explicit with some zero (unpenalized) groups
function weight_vector(kind::Symbol, groups, ::Type{T}, rng) where T
  kind === :default && return nothing
  K = length(groups)
  w = T.(0.5 .+ 1.5 .* rand(rng, K))
  kind === :zero && K > 1 && (w[2:3:end] .= zero(T))
  w
end

# A problem with penalty fraction·λmax (λ0 rounded to T)
function make_problem(::Type{T}, dkind, lkind, wkind, fraction; n = 60, p = 12, α = nothing, seed = 1, ptype = T) where T
  X, y = make_design(T, dkind, n, p; seed)
  groups = layout(lkind, p; seed)
  w = weight_vector(wkind, groups, T, Xoshiro(seed + 1))
  wfull = w === nothing ? sqrt.(T.(length.(groups))) : w
  λ0 = fraction * lambda_max(X, y, sval(α), groups, wfull)
  g = penalty(T(λ0), groups, w, ptype)
  X, y, g
end

# ---------------------------------------------------------------------------
# Orthogonal designs: the analytic block soft threshold
# ---------------------------------------------------------------------------
# For XᵀX = c I the objective is (s/2)‖y - Xβ‖² = (s c/2)‖β - z‖² + const with z = Xᵀy / c, a separable
# sum over groups, so each group minimizes (s c/2)‖β_G - z_G‖² + λ0 wₖ‖β_G‖. Stationarity
# s c (β_G - z_G) + λ0 wₖ β_G/‖β_G‖ = 0 gives β_G ∥ z_G and ‖β_G‖ = ‖z_G‖ - λ0 wₖ/(s c), so
#   β_G = max(0, 1 - λ0 wₖ/(s c ‖z_G‖)) z_G,
# and, for s c > 0 and wₖ > 0, the group is zero when λ0 wₖ ≥ s c ‖z_G‖. (The threshold is λ0 wₖ/(s c), not λ0 wₖ/s.)
function hadamard(n)
  H = ones(1, 1)
  while size(H, 1) < n
    H = [H H; H -H]
  end
  H
end
function orthogonal_design(::Type{T}, p; exponent, seed) where T
  H = hadamard(16)[:, 1:p]
  X = ldexp.(H, exponent)              # entries ±2^exponent: XᵀX = c I exactly, c = 16 · 4^exponent
  Matrix{T}(X), Vector{T}(randn(Xoshiro(seed), 16))
end
function orthogonal_solution(X, y, s, g)
  Xd, yd = Float64.(X), Float64.(y)
  c = sum(abs2, Xd[:, 1])
  @test Xd' * Xd == c * I
  z = (Xd' * yd) ./ c
  β = zeros(length(z))
  for (k, G) in enumerate(g.groups)
    nz = norm(z[G])
    factor = iszero(nz) ? 0.0 : max(0.0, 1 - Float64(g.λ0) * Float64(g.w[k]) / (s * c * nz))
    β[G] = factor .* z[G]
  end
  β, c
end
# a penalty that puts the first half of the groups (by ratio ‖z_G‖ s c/wₖ) at zero and the rest above
function mixed_penalty(X, y, s, groups, w, ::Type{T}, ptype) where T
  Xd, yd = Float64.(X), Float64.(y)
  c = sum(abs2, Xd[:, 1])
  z = (Xd' * yd) ./ c
  wfull = w === nothing ? sqrt.(T.(length.(groups))) : w
  q = sort([s * c * norm(z[G]) / Float64(wfull[k]) for (k, G) in enumerate(groups)])
  a = length(q) ÷ 2
  @test q[a + 1] - q[a] > 1e-3 * q[a + 1]       # the two sides of the threshold are separated
  penalty(T((q[a] + q[a + 1]) / 2), groups, w, ptype)
end

# One cyclic pass from `β0`, with the exact curvature λmax(X_Gᵀ X_G) of each group: u = β_G + X_Gᵀ r/ℓ and
# the shrinkage of u at λ0 wₖ/(s ℓ). The solver's curvature is that value up to a relative margin (at most
# 1e-6, and about 2 n eps(T) for a Float32 singleton), which moves a pass by that margin times the step.
function one_cyclic_pass(X, y, s, g, β0)
  Xd = Float64.(X)
  β = copy(β0)
  r = Float64.(y) - Xd * β
  for (k, G) in enumerate(g.groups)
    B = Xd[:, G]
    ℓ = maximum(eigvals(Symmetric(B' * B)))     # not eigmax: its selected-eigenvalue routine throws on a near-identity Gram on Julia 1.10
    u = β[G] .+ B' * r ./ ℓ
    thr = Float64(g.λ0) * Float64(g.w[k]) / (s * ℓ)
    nu = norm(u)
    new = nu > thr ? (1 - thr / nu) .* u : zero(u)
    r .-= B * (new .- β[G])
    β[G] = new
  end
  β
end

# ---------------------------------------------------------------------------
# White-box checks of the model (frozen names)
# ---------------------------------------------------------------------------
function whitebox_model(X, y, α, g, x)
  m = PS.cdmodel(mkloss(y, X, α), x)
  PS.initialize!(m, x)
  PS._prepare!(m, g, x)
  m
end

# λmax(X_Gᵀ X_G) ≤ ℓ ≤ (1 + ε) λmax(X_Gᵀ X_G), decided in BigFloat by Cholesky factorizations of shifted Gram
# matrices: s I - Gram is positive definite iff s > λmax. So ℓ ≥ λmax holds when ℓ I - Gram is positive
# definite, and ℓ ≤ (1 + ε) λmax holds when (ℓ/(1+ε)) I - Gram is not.
function majorizes(X, G, ℓ, ε)
  setprecision(BigFloat, 256) do
    B = big.(X[:, G])
    Gram = Matrix(B' * B)
    shifted_posdef(s) = issuccess(cholesky(Symmetric(s * I - Gram); check = false))
    shifted_posdef(big(ℓ)) && !shifted_posdef(big(ℓ) / (1 + big(ε)))
  end
end

# the allowed excess over λmax: 1e-6, and 4 n eps(T) where that is larger for a singleton group, whose
# curvature is the sum of squares in T followed by a margin of 2 n eps(T) (the maintainer's ruling on #275),
# about 2e-5 for Float32 and n = 40
curvature_margin(::Type{T}, n, m) where T = m == 1 ? max(1e-6, 4n * eps(T)) : 1e-6

function curvature_cases(::Type{T}) where T
  rng = Xoshiro(201)
  cases = Tuple{String, Matrix{T}, Vector{Vector{Int}}}[]
  orth(n, mk) = Matrix(qr(randn(rng, n, mk)).Q)
  # near-identity Grams: orthonormal columns inside each group
  n = 64
  push!(cases, ("orthonormal", T.(hcat(orth(n, 32), orth(n, 8), orth(n, 3), orth(n, 1))),
                [collect(1:32), collect(33:40), collect(41:43), [44]]))
  # rank-deficient groups, duplicated columns, a column repeated across groups
  a, b, c = randn(rng, 40), randn(rng, 40), randn(rng, 40)
  push!(cases, ("rank-deficient", T.(hcat(a, b, a .+ b, 2 .* a .- b, c, c, c, a)),
                [[1, 2, 3, 4], [5, 6, 7], [8]]))
  # columns scaled from 1e-8 to 1e8 inside a group and as singletons
  scales = 10.0 .^ (-8:4:8)
  push!(cases, ("scaled", T.(hcat(randn(rng, 40, 5) .* scales', randn(rng, 40, 5) .* scales')),
                [collect(1:5), [6], [7], [8], [9], [10]]))
  # dense groups of up to 32 columns, a pair and a singleton
  push!(cases, ("dense", T.(randn(rng, 100, 52)), [collect(1:32), collect(33:49), [50, 51], [52]]))
  # a decaying spectrum inside one group
  U = orth(50, 6)
  push!(cases, ("spectrum", T.(U * Diagonal(10.0 .^ (0:-3:-15)) * orth(6, 6)'), [collect(1:6)]))
  cases
end

function step_allocations(m, g, x, ks)
  total = 0
  for k in ks
    total += @allocated PS.coordinate_step!(m, g, x, k)
  end
  total
end

# ---------------------------------------------------------------------------
# Numerical refusals and special groups
# ---------------------------------------------------------------------------
# A solve that is refused: it throws an ArgumentError whose message contains `fragment`, and the caller's
# iterate (values, active groups in slot order) and the generator are as they were.
function check_block_refusal(X, y, α, g, x0; fragment, order = :random, activezero = (), maxpasses = 50)
  x = BlockIterate(copy(x0), g.groups)
  foreach(k -> activate!(x, k), activezero)
  rng = Xoshiro(5)
  solver = CDSolver(; order, maxpasses, rng)
  snapshot() = (copy(Vector(x)), collect(activecoordinates(x)))
  before, rng_before = snapshot(), copy(rng)
  err, logs = logged(() -> try
    solve!(x, mkloss(y, X, α), g, solver)
    nothing
  catch e
    e
  end)
  @test err isa ArgumentError
  err isa ArgumentError && @test occursin(fragment, err.msg)
  @test isequal(snapshot(), before)
  @test rng == rng_before
  @test isempty(logs)
  err
end

@testset "group_cd" begin

@testset "orthogonal designs: analytic block soft threshold" begin
  p = 12
  for T in TYPES, exponent in (0, -1)
    X, y = orthogonal_design(T, p; exponent, seed = 3 + exponent)
    for α in (nothing, T(0.5), 3.0, 0.3), lkind in (:contiguous, :reordered, :singletons), wkind in (:default, :explicit)
      groups = layout(lkind, p; seed = 5)
      w = weight_vector(wkind, groups, T, Xoshiro(9))
      g = mixed_penalty(X, y, sval(α), groups, w, T, ptype_for(T, α))
      β, c = orthogonal_solution(X, y, sval(α), g)
      x = BlockIterate(T, p, g)
      out = run_group_cd(X, y, α, g, x)
      @test out.res.converged
      @test norm(Float64.(Vector(x)) - β) <= kkt_bound(T) * max(1.0, norm(β))
      for (k, G) in enumerate(g.groups)
        @test isactive(x, k) == any(!iszero, β[G])
      end
      check_solution(X, y, α, g, x, out.res)
    end
  end
  # one group: below and above the threshold
  for T in TYPES
    X, y = orthogonal_design(T, p; exponent = 0, seed = 17)
    groups = [collect(1:p)]
    λmax_ = lambda_max(X, y, 1.0, groups, [sqrt(T(p))])
    for fraction in (0.3, 1.3)
      g = penalty(T(fraction * λmax_), groups, nothing, T)
      β, = orthogonal_solution(X, y, 1.0, g)
      x = BlockIterate(T, p, g)
      out = run_group_cd(X, y, nothing, g, x)
      @test norm(Float64.(Vector(x)) - β) <= kkt_bound(T) * max(1.0, norm(β))
      @test isactive(x, 1) == (fraction < 1)
      check_solution(X, y, nothing, g, x, out.res)
    end
  end
end

# The stopping statistic: the largest ‖Δ_G‖ times √(s ℓ_k) with relative = true. On an orthogonal design the
# first pass from zero moves group k by (c/ℓ_k) β*_G (u = z c/ℓ and the threshold is λ0 wₖ/(s ℓ)), where
# ℓ_k = c up to the rounding margin, so the statistic is max ‖β*_G‖ √(s c) (c/ℓ)^(1/2) ≈ max ‖β*_G‖ √(s c).
@testset "the stopping statistic of the first pass on an orthogonal design" begin
  p = 12
  for T in TYPES, α in (nothing, 2.5), relative in (true, false)
    X, y = orthogonal_design(T, p; exponent = 0, seed = 21)
    groups = layout(:contiguous, p)
    g = mixed_penalty(X, y, sval(α), groups, nothing, T, T)
    β, c = orthogonal_solution(X, y, sval(α), g)
    x = BlockIterate(T, p, g)
    out = run_group_cd(X, y, α, g, x; maxpasses = 1, relative)
    @test warned(out.logs)
    @test out.res.passes == 1
    expected = maximum(norm(β[G]) for G in g.groups) * (relative ? sqrt(sval(α) * c) : 1.0)
    @test isapprox(Float64(out.res.maxchange), expected; rtol = T === Float64 ? 1e-8 : 1e-4)
    tolerance = relative ? solve_tol(T) * sqrt(sval(α)) * norm(Float64.(y)) : solve_tol(T)
    @test isapprox(Float64(out.res.tolerance), tolerance; rtol = 1e-4)
  end
end

# ---------------------------------------------------------------------------
# Random dense designs
# ---------------------------------------------------------------------------
@testset "random dense designs: KKT, objective and results" begin
  idx = 0
  for T in TYPES, dkind in (:plain, :correlated, :duplicate, :scaled),
      lkind in (:one, :one_range, :singletons, :contiguous, :strided, :reordered, :many),
      (wkind, fraction) in ((:default, 0.3), (:explicit, 0.02), (:explicit, 0.3))
    # a group that spans columns of widely different scales converges at a rate set by the condition number
    # of its Gram matrix, which is large there
    dkind === :scaled && lkind in (:one, :one_range, :strided, :reordered) && continue
    idx += 1
    α = (fraction == 0.3 && wkind === :explicit) ? (T === Float32 ? 0.7 : 2.0) : nothing   # a scaled loss on some
    X, y, g = make_problem(T, dkind, lkind, wkind, fraction; α, seed = 1000 + idx, ptype = ptype_for(T, α))
    solve_and_check(X, y, α, g; order = isodd(idx) ? :cyclic : :random, seed = idx)
  end
end

@testset "many groups" begin
  for T in TYPES
    p = 40
    X, y = make_design(T, :correlated, 90, p; seed = 77)
    groups = split_sizes(randperm(Xoshiro(78), p), (1, 4, 2, 3, 2))
    w = weight_vector(:explicit, groups, T, Xoshiro(79))
    g = penalty(T(0.4 * lambda_max(X, y, 1.0, groups, w)), groups, w, T)
    out = solve_and_check(X, y, nothing, g)
    @test 0 < nactive(out.x) < ncoordinates(out.x) == length(groups)
  end
end

@testset "zero-weight (unpenalized) groups" begin
  for T in TYPES, dkind in (:plain, :correlated), lkind in (:contiguous, :strided, :singletons, :reordered)
    X, y, g = make_problem(T, dkind, lkind, :zero, 0.3; seed = 31)
    zerogroups = [k for k in eachindex(g.groups) if iszero(g.w[k])]
    @test !isempty(zerogroups)
    out = solve_and_check(X, y, nothing, g)
    # the unpenalized groups carry nonzero coefficients and (checked above) zero gradient
    @test all(k -> isactive(out.x, k), zerogroups)
  end
end

@testset "penalty level 0 is least squares" begin
  for T in TYPES, (dkind, n, p) in ((:plain, 60, 12), (:correlated, 60, 12), (:duplicate, 60, 12), (:wide, 8, 12)),
      lkind in (:one, :singletons, :contiguous, :reordered)
    X, y = make_design(T, dkind, n, p; seed = 41)
    groups = layout(lkind, p; seed = 3)
    g = penalty(zero(T), groups, nothing, T)
    out = solve_and_check(X, y, nothing, g)
    Xd, yd = Float64.(X), Float64.(y)
    fit = Xd * (pinv(Xd) * yd)
    @test norm(Xd * Float64.(Vector(out.x)) - fit) <= fit_rtol(T) * max(1.0, norm(yd))
  end
end

@testset "penalty at or above λmax gives the zero solution in one pass" begin
  for T in TYPES, lkind in (:one, :singletons, :contiguous, :strided, :reordered), fraction in (1.05, 3.0),
      wkind in (:default, :explicit), α in (nothing, 1.7)
    X, y, g = make_problem(T, :correlated, lkind, wkind, fraction; α, seed = 51)
    x = BlockIterate(T, 12, g)
    out = run_group_cd(X, y, α, g, x)
    @test out.res.passes == 1 && out.res.converged
    @test nactive(x) == 0 && all(isequal(zero(T)), x)
    @test isempty(out.logs)
    rep = check_solution(X, y, α, g, x, out.res)
    @test rep.screen <= 0
    @test isapprox(Float64(out.res.minimum), sval(α) / 2 * sum(abs2, Float64.(y)); rtol = 16 * 60 * eps(T))
  end
end

@testset "equal layouts of different group types" begin
  for T in TYPES
    p = 12
    X, y = make_design(T, :correlated, 60, p; seed = 61)
    ranges = [1:3, 4:4, 5:8, 9:12]
    vectors = [collect(r) for r in ranges]
    w = weight_vector(:explicit, ranges, T, Xoshiro(62))
    λ0 = 0.3 * lambda_max(X, y, 1.0, ranges, w)
    first_solution = nothing
    for (xgroups, ggroups) in ((ranges, vectors), (vectors, ranges), (ranges, ranges), (vectors, vectors))
      g = penalty(T(λ0), ggroups, w, T)
      x = BlockIterate(T, p, xgroups)
      out = run_group_cd(X, y, nothing, g, x)
      check_solution(X, y, nothing, g, x, out.res)
      β = Float64.(Vector(x))
      first_solution === nothing && (first_solution = β)
      @test norm(β - first_solution) <= coef_rtol(T) * max(1.0, norm(first_solution))
    end
  end
end

# ---------------------------------------------------------------------------
# Starting points
# ---------------------------------------------------------------------------
@testset "starting points" begin
  for T in TYPES, α in (nothing, 0.8)
    X, y, g = make_problem(T, :correlated, :strided, :explicit, 0.25; α, seed = 71, ptype = ptype_for(T, α))
    p, K = size(X, 2), length(g.groups)
    s = sval(α)
    ref = BlockIterate(T, p, g)
    out0 = run_group_cd(X, y, α, g, ref)
    check_solution(X, y, α, g, ref, out0.res)
    xref = Float64.(Vector(ref))
    obj_ref = objective_big(X, y, s, g, Vector(ref))
    same(x) = (norm(Float64.(Vector(x)) - xref) <= coef_rtol(T) * max(1.0, norm(xref)) &&
               abs(objective_big(X, y, s, g, Vector(x)) - obj_ref) <= obj_rtol(T) * objective_scale(X, y, s, g, xref))
    # partially active: groups 1 and 3 hold values, the rest is zero and inactive
    x0 = zeros(T, p)
    for k in (1, 3)
      x0[g.groups[k]] .= T.(randn(Xoshiro(k), length(g.groups[k])))
    end
    x = BlockIterate(x0, g.groups)
    @test nactive(x) == 2
    out = run_group_cd(X, y, α, g, x)
    check_solution(X, y, α, g, x, out.res)
    @test same(x)
    # active zero blocks (groups 2 and 4) next to a nonzero one
    x = BlockIterate(T, p, g)
    activate!(x, 2); activate!(x, 4)
    x[g.groups[1][1]] = one(T)
    @test nactive(x) == 3
    out = run_group_cd(X, y, α, g, x)
    check_solution(X, y, α, g, x, out.res)
    @test same(x)
    # every group active and zero
    x = BlockIterate(T, p, g)
    foreach(k -> activate!(x, k), 1:K)
    out = run_group_cd(X, y, α, g, x)
    check_solution(X, y, α, g, x, out.res)
    @test same(x)
    # a warm start at a solution: one full pass changes less than the threshold
    warm = copy(ref)
    out = run_group_cd(X, y, α, g, warm)
    @test out.res.passes == 1 && out.res.converged
    @test out.res.maxchange < out.res.tolerance
    @test same(warm)
    @test isequal(collect(activecoordinates(warm)), collect(activecoordinates(ref)))
  end
  # Float32 data with a Float64 scale that Float32 does not hold, and a Float64 penalty
  X, y, g = make_problem(Float32, :plain, :contiguous, :default, 0.2; α = 0.3, seed = 72, ptype = Float64)
  @test g isa GroupNormL2{Float64} && Float64(Float32(0.3)) != 0.3
  solve_and_check(X, y, 0.3, g)
end

# ---------------------------------------------------------------------------
# Nonunique solutions: objective and fitted values, not coefficients
# ---------------------------------------------------------------------------
# One column repeated inside a group: X = [Z u] with u = Z[:, 1] in group {1, 9}. Then Xβ = Z β' with
# β'₁ = β₁ + β₉ and, for a given sum t, ‖(β₁, β₉)‖ ≥ |t|/√2 with equality at β₁ = β₉. So the problem equals the
# problem on Z with the group {1} of weight w/√2 = 1, the default weight of a singleton (w = √2 for the pair).
@testset "a duplicated column inside a group" begin
  for T in TYPES
    n, q = 60, 8
    Zfull, y = make_design(T, :correlated, n, q; seed = 81)
    Zfull[:, 1] .= T.(Float64.(y) .+ 0.3 .* randn(Xoshiro(82), n) ./ sqrt(n))     # column 1 is y plus noise, so |Xᵀy| is largest there and group {1} is nonzero at 0.3 λmax
    X = hcat(Zfull, Zfull[:, 1])
    gd = [[1, 9], [2, 3], [4], [5, 6, 7], [8]]
    gr = [[1], [2, 3], [4], [5, 6, 7], [8]]
    λ0 = T(0.3 * lambda_max(Zfull, y, 1.0, gr, sqrt.(T.(length.(gr)))))
    gdup, gred = penalty(λ0, gd, nothing, T), penalty(λ0, gr, nothing, T)
    od = solve_and_check(X, y, nothing, gdup)
    orr = solve_and_check(Zfull, y, nothing, gred)
    bd, br = Float64.(Vector(od.x)), Float64.(Vector(orr.x))
    @test isactive(od.x, 1) && !iszero(bd[1])
    fo, fr = objective_big(X, y, 1.0, gdup, bd), objective_big(Zfull, y, 1.0, gred, br)
    @test abs(fo - fr) <= obj_rtol(T) * objective_scale(X, y, 1.0, gdup, bd)
    @test norm(Float64.(X) * bd - Float64.(Zfull) * br) <= fit_rtol(T) * max(1.0, norm(y))
    @test isapprox(bd[1] + bd[9], br[1]; atol = fit_rtol(T) * max(1.0, abs(br[1])))
    @test isapprox(bd[1], bd[9]; atol = fit_rtol(T) * max(1.0, abs(br[1])))
  end
end

@testset "duplicated columns across groups and in rank-deficient groups" begin
  for T in TYPES, lkind in (:contiguous, :strided, :reordered, :singletons), n in (60, 8)
    X, y = make_design(T, :duplicate, n, 12; seed = 91)
    groups = layout(lkind, 12; seed = 4)
    w = weight_vector(:explicit, groups, T, Xoshiro(92))
    g = penalty(T(0.15 * lambda_max(X, y, 1.0, groups, w)), groups, w, T)
    a = solve_and_check(X, y, nothing, g; order = :cyclic)
    b = solve_and_check(X, y, nothing, g; order = :random, seed = 5)
    Fa, Fb = objective_big(X, y, 1.0, g, Vector(a.x)), objective_big(X, y, 1.0, g, Vector(b.x))
    @test abs(Fa - Fb) <= obj_rtol(T) * objective_scale(X, y, 1.0, g, Vector(a.x))
    @test norm(Float64.(X) * Float64.(Vector(a.x)) - Float64.(X) * Float64.(Vector(b.x))) <= fit_rtol(T) * max(1.0, norm(y))
  end
end

# ---------------------------------------------------------------------------
# Random versus cyclic order, and the borrowed generator
# ---------------------------------------------------------------------------
@testset "random and cyclic order reach the same objective; the generator is borrowed" begin
  for T in TYPES
    X, y, g = make_problem(T, :correlated, :reordered, :explicit, 0.2; seed = 101)
    p = size(X, 2)
    runs = Dict{Symbol, Any}()
    for order in (:cyclic, :random)
      x = BlockIterate(T, p, g)
      runs[order] = run_group_cd(X, y, nothing, g, x; order, seed = 7)
      check_solution(X, y, nothing, g, x, runs[order].res)
    end
    Fc = objective_big(X, y, 1.0, g, Vector(runs[:cyclic].x))
    Fr = objective_big(X, y, 1.0, g, Vector(runs[:random].x))
    @test abs(Fc - Fr) <= obj_rtol(T) * objective_scale(X, y, 1.0, g, Vector(runs[:cyclic].x))
    @test norm(Float64.(Vector(runs[:cyclic].x)) - Float64.(Vector(runs[:random].x))) <=
          coef_rtol(T) * max(1.0, norm(Float64.(Vector(runs[:cyclic].x))))
    # cyclic order draws nothing; random order advances the generator
    @test runs[:cyclic].rng == Xoshiro(7)
    @test runs[:random].rng != Xoshiro(7)
    # equal seeds give identical runs and identical generator states
    a = run_group_cd(X, y, nothing, g, BlockIterate(T, p, g); order = :random, seed = 7)
    b = run_group_cd(X, y, nothing, g, BlockIterate(T, p, g); order = :random, seed = 7)
    @test isequal(Vector(a.x), Vector(b.x))
    @test isequal((a.res.minimum, a.res.passes, a.res.converged, a.res.maxchange, a.res.tolerance),
                  (b.res.minimum, b.res.passes, b.res.converged, b.res.maxchange, b.res.tolerance))
    @test a.rng == b.rng && a.rng == runs[:random].rng
    @test isequal(collect(activecoordinates(a.x)), collect(activecoordinates(b.x)))
    c = run_group_cd(X, y, nothing, g, BlockIterate(T, p, g); order = :random, seed = 8)
    @test c.rng != a.rng
    @test abs(objective_big(X, y, 1.0, g, Vector(c.x)) - Fr) <= obj_rtol(T) * objective_scale(X, y, 1.0, g, Vector(c.x))
  end
end

# ---------------------------------------------------------------------------
# maxpasses = 0 and 1
# ---------------------------------------------------------------------------
@testset "maxpasses = 0 keeps the start, its active zero blocks and the generator" begin
  for T in TYPES, α in (nothing, 1.5)
    X, y, g = make_problem(T, :plain, :reordered, :explicit, 0.2; α, seed = 111, ptype = ptype_for(T, α))
    p = size(X, 2)
    x0 = zeros(T, p)
    x0[g.groups[3]] .= T(0.5)
    x = BlockIterate(x0, g.groups)
    activate!(x, 1); activate!(x, 4)           # active zero blocks, after group 3 in the slot order
    values, active = copy(Vector(x)), collect(activecoordinates(x))
    @test active == [3, 1, 4]
    rng = Xoshiro(13)
    rng0 = copy(rng)
    res = @test_logs (:warn, r"did not converge") solve!(x, mkloss(y, X, α), g, CDSolver(; order = :random, maxpasses = 0, rng))
    @test isequal(Vector(x), values)
    @test collect(activecoordinates(x)) == active
    @test rng == rng0
    @test res.passes == 0 && !res.converged && res.minimizer === x
    @test typeof(res) == CDResults{typeof(x), T}
    @test isapprox(Float64(res.minimum), objective_big(X, y, sval(α), g, values); rtol = 16 * (size(X, 1) + p) * eps(T))
  end
end

@testset "maxpasses = 1 commits the state after one cyclic pass" begin
  for T in TYPES, α in (nothing, 2.5), lkind in (:reordered, :strided, :singletons, :contiguous)
    X, y, g = make_problem(T, :correlated, lkind, :explicit, 0.2; α, seed = 121, ptype = ptype_for(T, α))
    p = size(X, 2)
    s = sval(α)
    x0 = zeros(T, p)
    x0[g.groups[1]] .= T(0.25)
    x = BlockIterate(x0, g.groups)
    out = run_group_cd(X, y, α, g, x; maxpasses = 1)
    @test warned(out.logs)
    @test out.res.passes == 1 && !out.res.converged
    β = one_cyclic_pass(X, y, s, g, Float64.(x0))
    @test norm(Float64.(Vector(x)) - β) <= (T === Float64 ? 1e-5 : 1e-3) * max(1.0, norm(β))
    F0, F1 = objective_big(X, y, s, g, x0), objective_big(X, y, s, g, Vector(x))
    @test F1 <= F0 + 16 * eps(T) * objective_scale(X, y, s, g, x0)
    @test isapprox(Float64(out.res.minimum), F1; rtol = 16 * (size(X, 1) + p) * eps(T))
    for (k, G) in enumerate(g.groups)
      @test isactive(x, k) == any(i -> !iszero(x[i]), G)
    end
  end
end

# ---------------------------------------------------------------------------
# Singleton groups against the scalar lasso
# ---------------------------------------------------------------------------
@testset "singleton groups and the scalar lasso agree to a tolerance" begin
  for T in TYPES, α in (nothing, 2.5)
    X, y = make_design(T, :correlated, 60, 12; seed = 131)
    p = 12
    s = sval(α)
    groups = [[j] for j in 1:p]
    λ0 = T(0.1 * lambda_max(X, y, s, groups, ones(T, p)))
    g = penalty(λ0, groups, nothing, ptype_for(T, α))
    @test all(==(1), g.w)
    xb = BlockIterate(T, p, g)
    ob = run_group_cd(X, y, α, g, xb)
    check_solution(X, y, α, g, xb, ob.res)
    xs = zeros(T, p)
    rs, logs = logged(() -> solve!(xs, mkloss(y, X, α), NormL1(λ0),
                                   CDSolver(; order = :cyclic, momentum = false, tol = solve_tol(T), maxpasses = pass_limit(T))))
    @test isempty(logs) && rs.converged
    @test norm(Float64.(Vector(xb)) - Float64.(xs)) <= coef_rtol(T) * max(1.0, norm(xs))
    Fb = objective_big(X, y, s, g, Vector(xb))
    Fs = objective_big(X, y, s, g, xs)
    @test abs(Fb - Fs) <= obj_rtol(T) * objective_scale(X, y, s, g, xs)
    @test all(j -> isactive(xb, j) == !iszero(xs[j]), 1:p)
  end
end

# The references themselves, without the solver
@testset "references" begin
  # the analytic block threshold satisfies the independent KKT to rounding, a perturbation does not
  for T in TYPES
    X, y = orthogonal_design(T, 12; exponent = 0, seed = 1)
    groups = layout(:contiguous, 12)
    for α in (nothing, 3.0)
      g = mixed_penalty(X, y, sval(α), groups, nothing, T, T)
      β, = orthogonal_solution(X, y, sval(α), g)
      rep = kkt_report(X, y, sval(α), g, β)
      @test rep.stat <= 1e-12 * max(1.0, Float64(g.λ0)) && rep.screen <= 1e-12
      @test any(iszero, β) && any(!iszero, β)
      for (j, δ) in ((1, 1e-3), (5, -1e-3), (12, 1e-2))
        βp = copy(β); βp[j] += δ
        @test kkt_report(X, y, sval(α), g, βp).stat > 1e-4 * max(1.0, Float64(g.λ0)) ||
              kkt_report(X, y, sval(α), g, βp).screen > 1e-4
      end
      # the objective of the analytic solution is below that of perturbed points, in BigFloat and Float64
      F = objective_big(X, y, sval(α), g, β)
      @test isapprox(F, objective_wide(X, y, sval(α), g, β); rtol = 1e-12)
      for j in 1:12
        βp = copy(β); βp[j] += 1e-3
        @test objective_big(X, y, sval(α), g, βp) > F
      end
    end
  end
  # the curvature test accepts a value just above λmax and rejects values below it and values too far above it
  X = Float64[2 0; 0 1; 0 0]            # Gram matrix diag(4, 1)
  @test majorizes(X, [1, 2], 4 * (1 + 1e-9), 1e-6)
  @test !majorizes(X, [1, 2], 4 * (1 - 1e-9), 1e-6)
  @test !majorizes(X, [1, 2], 4 * (1 + 2e-6), 1e-6)
  @test majorizes(X, [2], 1.0 * (1 + 1e-9), 1e-6) && !majorizes(X, [2], 0.99, 1e-6)
  # λmax bounds the penalties above which β = 0 solves the problem
  X, y = make_design(Float64, :plain, 60, 12; seed = 5)
  groups = layout(:contiguous, 12)
  w = sqrt.(length.(groups))
  for fraction in (0.99, 1.01)
    g = penalty(fraction * lambda_max(X, y, 1.0, groups, w), groups, nothing, Float64)
    rep = kkt_report(X, y, 1.0, g, zeros(12))
    @test (rep.screen <= 0) == (fraction > 1)
  end
end

@testset "curvature majorization" begin
  for T in TYPES
    for (name, X, groups) in curvature_cases(T)
      y = T.(randn(Xoshiro(5), size(X, 1)))
      g = penalty(T(1), groups, nothing, T)
      x = BlockIterate(T, size(X, 2), g)
      m = whitebox_model(X, y, nothing, g, x)
      @test length(m.ℓ) == length(groups)
      for (k, G) in enumerate(groups)
        @test m.ℓ[k] isa T && isfinite(m.ℓ[k]) && m.ℓ[k] > 0
        @test majorizes(X, G, m.ℓ[k], curvature_margin(T, size(X, 1), length(G)))
      end
    end
    # flat groups have curvature 0, with or without a loss scale
    n = 30
    X = T.(randn(Xoshiro(6), n, 5))
    X[:, 2:3] .= 0
    X[:, 5] .= 0
    y = T.(randn(Xoshiro(7), n))
    for α in (nothing, 2.0)
      g = penalty(T(1), [[1], [2, 3], [4], [5]], nothing, T)
      m = whitebox_model(X, y, α, g, BlockIterate(T, 5, g))
      @test m.ℓ[2] == 0 && m.ℓ[4] == 0
      @test m.ℓ[1] > 0 && m.ℓ[3] > 0
    end
  end
end

# the residual after `initialize!` and after single steps on noncontiguous groups
@testset "residual after initialization and single steps" begin
  for T in TYPES, α in (nothing, 1.3)
    X, y, g = make_problem(T, :correlated, :strided, :explicit, 0.1; α, seed = 141, ptype = ptype_for(T, α))
    n, p = size(X)
    x0 = zeros(T, p)
    for k in (1, 3)
      x0[g.groups[k]] .= T.(randn(Xoshiro(k + 10), length(g.groups[k])))
    end
    x = BlockIterate(x0, g.groups)
    activate!(x, 2)
    m = whitebox_model(X, y, α, g, x)
    # each update rounds the residual by at most eps(T)/2 relative to its entries (|y| + |X||β|), so the
    # error of the norm is bounded by that times the count of updates, p initially and a group each step
    residual_bound(steps) = 4 * (n + p + 10 * steps) * eps(T) * (norm(Float64.(y)) + norm(Float64.(X)) * norm(Float64.(Vector(x))) + 1)
    rref() = Float64.(y) - Float64.(X) * Float64.(Vector(x))
    @test norm(Float64.(m.ls.r) - rref()) <= residual_bound(0)
    for (steps, k) in enumerate((4, 2, 1, 3, 4, 1))
      PS.coordinate_step!(m, g, x, k)
      @test norm(Float64.(m.ls.r) - rref()) <= residual_bound(steps)
    end
  end
end

@testset "an inactive group with a zero step stays inactive" begin
  for T in TYPES
    X, y, g = make_problem(T, :plain, :reordered, :explicit, 3.0; seed = 151)   # above λmax: every step is zero
    x = BlockIterate(T, size(X, 2), g)
    m = whitebox_model(X, y, nothing, g, x)
    for k in 1:ncoordinates(x)
      h = PS.coordinate_step!(m, g, x, k)
      @test h isa T && iszero(h)
      @test !isactive(x, k)
    end
    @test nactive(x) == 0 && all(isequal(zero(T)), x)
    @test m.ls.r == y
  end
end

@testset "coordinate_step! returns the norm of the group change" begin
  for T in TYPES, α in (nothing, 0.9)
    X, y, g = make_problem(T, :correlated, :reordered, :explicit, 0.15; α, seed = 161, ptype = ptype_for(T, α))
    x = BlockIterate(T, size(X, 2), g)
    m = whitebox_model(X, y, α, g, x)
    for k in (2, 4, 1, 3, 2, 4, 1, 3)
      G = g.groups[k]
      before = Float64.([x[i] for i in G])
      h = PS.coordinate_step!(m, g, x, k)
      after = Float64.([x[i] for i in G])
      @test h isa T && h >= 0
      @test isapprox(Float64(h), norm(after - before); rtol = 8eps(T), atol = 0)
    end
  end
end

@testset "coordinate_step! allocates nothing" begin
  for T in TYPES, lkind in (:reordered, :contiguous, :singletons)
    X, y, g = make_problem(T, :correlated, lkind, :explicit, 0.1; seed = 171)
    x = BlockIterate(T, size(X, 2), g)
    m = whitebox_model(X, y, nothing, g, x)
    ks = collect(1:ncoordinates(x))
    step_allocations(m, g, x, ks)          # compile
    @test step_allocations(m, g, x, ks) == 0
    @test step_allocations(m, g, x, ks) == 0
  end
end

@testset "curvature underflow is refused before the first pass" begin
  n = 6
  # Float64: a group of two columns with entries about 1e-170: the entries of the Gram matrix are about
  # 1e-340, below the smallest subnormal 4.9e-324
  rng = Xoshiro(301)
  X = randn(rng, n, 4)
  X[:, 1:2] .*= 1e-170
  y = randn(rng, n)
  g = GroupNormL2(0.5, [[1, 2], [3, 4]])
  x0 = [0.0, 0.0, 0.7, -0.2]
  check_block_refusal(X, y, nothing, g, x0; fragment = "underflows", activezero = (1,))
  check_block_refusal(X, y, 2.0, g, x0; fragment = "underflows")
  # Float32: a singleton column with entries about 1e-25: the squares are about 1e-50, below the smallest
  # subnormal Float32 1.4e-45
  X32 = Float32.(randn(rng, n, 3))
  X32[:, 1] .*= 1f-25
  y32 = Float32.(randn(rng, n))
  g32 = GroupNormL2(0.5f0, [[1], [2, 3]])
  @test sum(abs2, X32[:, 1]) == 0
  check_block_refusal(X32, y32, nothing, g32, Float32[0, 0.4, -0.1]; fragment = "underflows", activezero = (1,))
end

@testset "curvature overflow is refused before the first pass" begin
  n = 6
  rng = Xoshiro(302)
  # Float64: entries about 1e160 give Gram entries about 1e320 > floatmax
  X = randn(rng, n, 4)
  X[:, 1:2] .*= 1e160
  y = randn(rng, n)
  g = GroupNormL2(0.5, [[1, 2], [3, 4]])
  check_block_refusal(X, y, nothing, g, [0.0, 0.0, 0.7, -0.2]; fragment = "overflows", activezero = (1,))
  # Float32 singleton: entries about 1e20, the squared norm exceeds floatmax(Float32) = 3.4e38
  X32 = Float32.(randn(rng, n, 3))
  X32[:, 1] .= 1f20 .* (1 .+ rand(rng, Float32, n))
  @test isinf(sum(abs2, X32[:, 1]))
  y32 = Float32.(randn(rng, n))
  g32 = GroupNormL2(0.5f0, [[1], [2, 3]])
  check_block_refusal(X32, y32, nothing, g32, Float32[0, 0.4, -0.1]; fragment = "overflows")
end

# Step band: with a Float32 loss scale s on Float32 data, a nonflat group of curvature ℓ is refused when
# p = s ℓ or 1/p is below floatmin(Float32) = 1.18e-38 although ℓ is a normal Float32.
#  * small: n = 4 columns of entries 1e-17: ℓ = 4e-34 (normal); s = 1e-6 gives p = 4e-40 < floatmin;
#    two such columns in a group have λmax = 8e-34 and p = 8e-40.
#  * large: n = 4 entries 1e9: ℓ = 4e18; s = 3e19 gives p = 1.2e38 (finite, below floatmax = 3.4e38)
#    and 1/p = 8.3e-39 < floatmin; two such columns have λmax = 8e18, p = 2.4e38 and 1/p = 4.2e-39.
# A Float64 scale on Float32 data forms p in Float64 and has no band.
@testset "an unrepresentable step is refused before the first pass" begin
  n = 4
  rng = Xoshiro(303)
  y = Float32.(randn(rng, n))
  for (entry, α, kind) in ((1f-17, 1f-6, :small), (1f9, 3f19, :large))
    X = Float32.(randn(rng, n, 3))
    X[:, 1] .= entry
    ℓ = sum(abs2, X[:, 1])
    @test floatmin(Float32) <= ℓ < floatmax(Float32)
    p = α * ℓ
    kind === :small && @test p < floatmin(Float32)
    kind === :large && @test floatmin(Float32) <= p < floatmax(Float32) && inv(p) < floatmin(Float32)
    g = GroupNormL2(0.5f0, [[1], [2, 3]])
    check_block_refusal(X, y, α, g, Float32[0, 0.4, -0.1]; fragment = "step of group", activezero = (1,))
    # the same with the constant column inside a group of two (the Gram path)
    X2 = copy(X)
    X2[:, 2] .= entry
    g2 = GroupNormL2(0.5f0, [[1, 2], [3]])
    ℓ2 = Float32(sum(abs2, Float64.(X2[:, 1:2])))      # two equal columns: λmax of the Gram matrix = total sum of squares
    @test floatmin(Float32) <= ℓ2 < floatmax(Float32)
    p2 = α * ℓ2
    kind === :small && @test p2 < floatmin(Float32)
    kind === :large && @test floatmin(Float32) <= p2 < floatmax(Float32) && inv(p2) < floatmin(Float32)
    check_block_refusal(X2, y, α, g2, Float32[0, 0, -0.1]; fragment = "step of group", activezero = (1,))
  end
end

# Float64 group 1 of order-1 columns, group 2 of columns of order 1e-150 (curvature about 1e-300, a normal
# number) and y of order 1e300. In cyclic order group 1 is updated first; for group 2 the slope is about
# 1e150 n and b/ℓ about 1e450 overflows.
@testset "a trial that overflows during a pass is refused with the caller unchanged" begin
  n = 6
  rng = Xoshiro(304)
  X = randn(rng, n, 4)
  X[:, 3:4] .*= 1e-150
  ℓ2 = maximum(eigvals(Symmetric(X[:, 3:4]' * X[:, 3:4])))
  @test floatmin(Float64) <= ℓ2 < 1e-290
  y = 1e300 .* randn(rng, n)
  g = GroupNormL2(1.0, [[1, 2], [3, 4]])
  check_block_refusal(X, y, nothing, g, [0.3, -0.2, 0.0, 0.0]; fragment = "is not finite", order = :cyclic)
end

@testset "a truly flat group solves" begin
  for T in TYPES
    n, p = 10, 6
    X = T.(randn(Xoshiro(311), n, p))
    X[:, 3:4] .= 0
    X[:, 6] .= 0
    y = T.(randn(Xoshiro(312), n))
    groups = [[1, 2], [3, 4], [5], [6]]
    x0 = T[0.2, 0.0, 1.0, -2.0, 0.0, 0.5]
    # penalized flat groups end at zero (also from a nonzero start)
    g = penalty(T(0.2), groups, nothing, T)
    x = BlockIterate(x0, groups)
    out = run_group_cd(X, y, nothing, g, x)
    check_solution(X, y, nothing, g, x, out.res)
    @test !isactive(x, 2) && !isactive(x, 4)
    @test all(isequal(zero(T)), x[3:4]) && isequal(x[6], zero(T))
    # with weight 0 the flat groups keep their starting values
    g0 = penalty(T(0.2), groups, T[1, 0, 1, 0], T)
    x = BlockIterate(x0, groups)
    out = run_group_cd(X, y, nothing, g0, x)
    check_solution(X, y, nothing, g0, x, out.res)
    @test x[3] == T(1) && x[4] == T(-2) && x[6] == T(0.5)
    @test isactive(x, 2) && isactive(x, 4)
    # a scaled loss
    x = BlockIterate(x0, groups)
    out = run_group_cd(X, y, 3.0, g0, x)
    check_solution(X, y, 3.0, g0, x, out.res)
    @test x[3] == T(1) && x[4] == T(-2) && x[6] == T(0.5)
  end
end

@testset "near-identity Grams solve to the KKT tolerance" begin
  for T in TYPES
    n = 40
    Z = randn(Xoshiro(321), n, 12) .+ 0.8 .* randn(Xoshiro(322), n)
    groups = [collect(1:3), collect(4:7), collect(8:12)]
    # orthonormal inside each group, correlated across groups (the groups come from one correlated Z)
    X = T.(hcat((Matrix(qr(Z[:, G]).Q) for G in groups)...))
    for G in groups
      @test norm(Float64.(X[:, G])' * Float64.(X[:, G]) - I) <= 100 * eps(T)
    end
    y = T.(randn(Xoshiro(323), n))
    for fraction in (0.1, 0.5)
      g = penalty(T(fraction * lambda_max(X, y, 1.0, groups, sqrt.(T.(length.(groups))))), groups, nothing, T)
      solve_and_check(X, y, nothing, g)
    end
  end
end

end # @testset "group_cd"

end
