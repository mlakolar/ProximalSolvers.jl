module Float32CertificateTests

using Test, LinearAlgebra, Random, SparseArrays
using ProximalBase
using ProximalSolvers
const PS = ProximalSolvers

# The oracle forms the original objective and dual in Float64, independently
# of the model cache and the solver's gap and dual-scale evaluators.
function penalty64(g::Union{NormL1, NormL1Nonneg, ElasticNet}, b, z)
  λ = Float64(g isa ElasticNet ? g.λ1 : g.λ0)
  w = g.w === nothing ? ones(length(b)) : Float64.(g.w)
  c = λ .* w
  ridge = g isa ElasticNet ? Float64(g.λ2) : 0.0
  nonneg = g isa NormL1Nonneg
  P = dot(c, abs.(b)) + ridge * sum(abs2, b) / 2
  nonneg && any(<(0), b) && (P = Inf)
  if ridge > 0
    return P, 1.0, sum(abs2, max.(abs.(z) .- c, 0)) / (2ridge)
  end
  a = nonneg ? -z : abs.(z)
  t = minimum((a[j] > c[j] ? c[j] / a[j] : 1.0 for j in eachindex(b)); init = 1.0)
  P, t, 0.0
end

function penalty64(g::GroupNormL2, b, z)
  c = Float64(g.λ0) .* Float64.(g.w)
  P = sum(c[k] * norm(b[G]) for (k, G) in enumerate(g.groups))
  t = minimum((iszero(norm(z[G])) ? 1.0 : c[k] / norm(z[G]) for (k, G) in enumerate(g.groups)); init = 1.0)
  P, t, 0.0
end

function penalty64(g::Union{SparseGroupNormL2, Scaled{<:SparseGroupNormL2}}, b, z)
  f = g isa SparseGroupNormL2 ? g : g.f
  α = g isa SparseGroupNormL2 ? 1.0 : Float64(g.α)
  c1, c2 = α * Float64(f.λ1), α * Float64(f.λ0) .* Float64.(f.w)
  P = sum(c1 * sum(abs, b[G]) + c2[k] * norm(b[G]) for (k, G) in enumerate(f.groups))
  feasible(t) = all(norm(max.(t .* abs.(z[G]) .- c1, 0)) <= c2[k] for (k, G) in enumerate(f.groups))
  lo, hi = 0.0, 1.0
  if feasible(hi)
    return P, hi, 0.0
  end
  for _ in 1:100
    t = (lo + hi) / 2
    feasible(t) ? (lo = t) : (hi = t)
  end
  P, lo, 0.0
end

function gap64(m, g, b, b0 = PS.intercept(m, b); candidates = nothing)
  X, y, b = Float64.(m.X), Float64.(m.y), Float64.(Vector(b))
  w = m.w === nothing ? ones(length(y)) : Float64.(m.w)
  o = m.offset === nothing ? zeros(length(y)) : Float64.(m.offset)
  s = Float64(m.s)
  r = y .- o .- Float64(b0) .- X * b
  rd = m.intercept ? r .- dot(w, r) / sum(w) : r
  z = -s .* (X' * (w .* rd))
  if candidates !== nothing
    keep = falses(length(b))
    if g isa Union{GroupNormL2, SparseGroupNormL2, Scaled{<:SparseGroupNormL2}}
      f = g isa Scaled ? g.f : g
      for k in candidates
        keep[f.groups[k]] .= true
      end
    else
      keep[candidates] .= true
    end
    z[.!keep] .= 0
  end
  penalty, t, conjugate = penalty64(g, b, z)
  P = s * dot(w, r.^2) / 2 + penalty
  D = s * dot(w, t .* rd .* (y .- o) .- (t .* rd).^2 ./ 2) - conjugate
  (P - D) / max(abs(P), floatmin(Float64))
end

# The large-response oracle evaluates the original dual in BigFloat, rather
# than sharing the residual-sized factorization used by the solver.
function gapbig(m, g::NormL1, b)
  b0 = BigFloat(PS.intercept(m, b))
  X, y, b = BigFloat.(m.X), BigFloat.(m.y), BigFloat.(Vector(b))
  w = m.w === nothing ? ones(BigFloat, length(y)) : BigFloat.(m.w)
  o = m.offset === nothing ? zeros(BigFloat, length(y)) : BigFloat.(m.offset)
  s = BigFloat(m.s)
  r = y .- o .- b0 .- X * b
  rd = m.intercept ? r .- dot(w, r) / sum(w) : r
  z = s .* (X' * (w .* rd))
  c = BigFloat(g.λ0) .* (g.w === nothing ? ones(BigFloat, length(b)) : BigFloat.(g.w))
  t = minimum((iszero(z[j]) ? one(BigFloat) : c[j] / abs(z[j]) for j in eachindex(b)); init = one(BigFloat))
  P = s * dot(w, r.^2) / 2 + dot(c, abs.(b))
  D = s * dot(w, t .* rd .* (y .- o) .- (t .* rd).^2 ./ 2)
  Float64((P - D) / P)
end

function multitask(T, seed; K = 3, n = 60, p = 40, σ = 0.1)
  rng = Xoshiro(seed)
  Xs = [randn(rng, n, p) for _ in 1:K]
  B = zeros(p, K); B[1:5, :] .= randn(rng, 5, K) .+ 1
  ys = [Xs[k] * B[:, k] .+ σ .* randn(rng, n) for k in 1:K]
  X = zeros(K * n, K * p)
  for k in 1:K
    X[(k-1)*n+1:k*n, (k-1)*p+1:k*p] = Xs[k]
  end
  T.(X), T.(reduce(vcat, ys)), [[j + (k - 1) * p for k in 1:K] for j in 1:p]
end

function pathcheck(m, g, λs, x; solver = CDSolver(; rng = Xoshiro(1)), screening = true, require_all = true)
  b0 = Float64[]
  save(k, λ, x, m) = (push!(b0, Float64(PS.intercept(m, x))); false)
  r = solve_path(m, g, λs, solver; x, screening, callback = save)
  require_all && @test all(r.converged)
  @test eltype(r.gap) == eltype(x)
  for k in eachindex(r.λ)
    oracle = gap64(m, PS._with_level(g, r.λ[k]), r.solutions[k], b0[k])
    @test isapprox(r.gap[k], oracle; atol = 1e-9, rtol = 0)
    if r.converged[k]
      @test oracle <= PS.PATH_GAPTOL
      @test r.gap[k] <= PS.PATH_GAPTOL
    end
  end
  r
end

@testset "Float32 multitask certificates" begin
  for (T, K, n, p, seed) in ((Float32, 3, 60, 40, 1), (Float32, 4, 50, 100, 2), (Float64, 3, 60, 40, 1))
    X, y, groups = multitask(T, seed; K, n, p)
    m = cdmodel((1 / size(X, 1)) * LeastSquaresLoss(y, X), nothing)
    g = GroupNormL2(one(T), groups, ones(T, length(groups)))
    λmax = maximum(norm((X' * y)[G]) for G in groups) / size(X, 1)
    λs = T.(λmax .* exp10.(range(0, -3; length = 50)))
    pathcheck(m, g, λs, AtomIterate(T, size(X, 2), groups))
  end
end

@testset "Float32 lasso and group-lasso certificates" begin
  rng = Xoshiro(1)
  n, p = 100, 60
  X = randn(rng, n, p)
  b = zeros(p); b[1:8] .= randn(rng, 8) .+ 1
  y = Float32.(X * b .+ 0.1 .* randn(rng, n))
  X = Float32.(X)
  f = (1 / n) * LeastSquaresLoss(y, X)
  groups = [collect(4k-3:4k) for k in 1:p÷4]
  λmax = maximum(norm(X[:, G]' * y) for G in groups) / n
  λs = Float32.(λmax .* exp10.(range(0, -3; length = 50)))
  pathcheck(cdmodel(f, nothing), GroupNormL2(1f0, groups, ones(Float32, length(groups))), λs,
            AtomIterate(Float32, p, groups))
  λmax = norm(X' * y, Inf) / n
  λs = Float32.(λmax .* exp10.(range(0, -3; length = 50)))
  for icpt in (false, true)
    pathcheck(cdmodel(f, nothing; intercept = icpt), NormL1(1f0), λs, SparseIterate(Float32, p))
  end
  pathcheck(cdmodel(f, nothing; intercept = true), NormL1(1f0), λs, SparseIterate(Float32, p);
            solver = CDSolver(; rng = Xoshiro(1), gapsafe = true))
end

@testset "Float32 weighted and grouped certificates" begin
  rng = Xoshiro(128)
  n, p = 32, 8
  X = randn(rng, Float32, n, p)
  o = randn(rng, Float32, n) ./ 10
  y = X * Float32[1, -1, 0.5, 0, 0, 0, 0, 0] .+ o .+ 2 .+ randn(rng, Float32, n) ./ 5
  w = rand(rng, Float32, n) .+ 0.3f0; w[1:4] .= 0
  pw = rand(rng, Float32, p) .+ 0.4f0
  groups = [collect(k:k+1) for k in 1:2:p]
  gw = Float32[0.7, 1.1, 1.3, 0.9]
  sg = SparseGroupNormL2(0.37f0, 0.63f0, groups, gw)
  for XX in (X, sparse(X .* (abs.(X) .> 0.5f0))), icpt in (false, true)
    f = (1 / n) * GLMLoss(ProximalBase.Squared(), y, XX; weights = w, offset = o)
    for g in (NormL1(0.073f0, pw), NormL1Nonneg(0.073f0, pw), ElasticNet(0.073f0, 0.11f0, pw),
              GroupNormL2(0.073f0, groups, gw), sg, Scaled(sg, 0.137f0))
      grouped = g isa Union{GroupNormL2, SparseGroupNormL2, Scaled}
      x = grouped ? AtomIterate(Float32, p, groups) : SparseIterate(Float32, p)
      m = cdmodel(f, nothing; intercept = icpt)
      s = CDSolver(; gaptol = 1e-4, rng = Xoshiro(1), momentum = true)
      r = solve!(x, m, g, s)
      @test r.converged && r.gap <= s.gaptol
      oracle = gap64(m, g, x)
      @test oracle <= s.gaptol
      @test isapprox(r.gap, oracle; atol = 1e-9, rtol = 0)
      cache, δ = copy(m.r), m.δ
      wide = PS._wide_gap(m, g, x, nothing)
      @test m.r == cache && m.δ == δ
      @test isapprox(PS._relative_gap(wide[1], wide[2]), oracle; atol = 1e-9, rtol = 0)
      dg = duality_gap(m, g, x)
      @test dg.primal isa Float32 && dg.dual isa Float32 && dg.gap isa Float32
      @test isapprox(dg.gap / abs(dg.primal), oracle; atol = 1e-9, rtol = 0)
      if !icpt
        dg = duality_gap(f, g, x)
        @test isapprox(dg.gap / abs(dg.primal), oracle; atol = 1e-9, rtol = 0)
        dg = duality_gap(f, g, Vector(x))
        @test isapprox(dg.gap / abs(dg.primal), oracle; atol = 1e-9, rtol = 0)
      end
    end
  end
  # Exactly centred data still impose the intercept constraint.
  X = reshape(Float32[1, 0, -1], 3, 1)
  m = cdmodel(LeastSquaresLoss(Float32[1e8, 1, -1e8], X), nothing; intercept = true)
  @test m.intercept && iszero(m.ybar) && all(iszero, m.xbar)
  dg = duality_gap(m, NormL1(0f0), SparseIterate(Float32[1e8]))
  @test isapprox(dg.gap / dg.primal, 1 / 3; atol = 1e-7, rtol = 0)
end

@testset "Float32 stagnation and a reachable tight target" begin
  X = Matrix{Float32}(I, 2, 2)
  f = 0.5f0 * LeastSquaresLoss(Float32[1, 2], X)
  for options in ((; order = :cyclic), (; rng = Xoshiro(1), momentum = true), (; order = :cyclic, anderson = 2))
    m = cdmodel(f, nothing)
    x = SparseIterate(Float32, 2)
    s = CDSolver(; maxpasses = 10_000, gaptol = 1e-10, options...)
    r = @test_logs (:warn, r"relative duality gap .* does not certify") solve!(x, m, NormL1(0.1f0), s)
    @test !r.converged && r.gap > s.gaptol
    @test r.passes < 100
    @test isapprox(r.gap, gap64(m, NormL1(0.1f0), x); atol = 1e-9, rtol = 0)
    @test r.tolerance <= 8eps(Float32) * PS.response_scale(m, x)
    xt = SparseIterate(Float32, 2)
    rt = @test_logs solve!(xt, f, NormL1(0.125f0), CDSolver(; gaptol = 1e-7, options...))
    @test rt.converged && rt.gap <= 1e-7
    @test Vector(xt) == Float32[0.75, 1.75]
  end
end

@testset "Wide Fenchel--Young gaps, full and restricted" begin
  X = Float32[1 0 1 2; 0 1 2 1; 1 1 0 1; -1 0 1 0; 0 -1 0 1; 1 -1 1 0]
  y, o = Float32[1, 2, 1, -1, 0, 1], Float32[0.1, -0.2, 0, 0.3, 0, -0.1]
  w = Float32[0.7, 1.2, 0, 0.9, 1.1, 0.6]
  pw, groups, gw = Float32[0.7, 1.3, 0.9, 1.1], [[1, 2], [3, 4]], Float32[0.7, 1.3]
  sg = SparseGroupNormL2(0.37f0, 0.63f0, groups, gw)
  for icpt in (false, true), g in (NormL1(0.13f0, pw), NormL1Nonneg(0.13f0, pw), ElasticNet(0.13f0, 0f0, pw),
                                  ElasticNet(0.13f0, 0.17f0, pw), GroupNormL2(0.13f0, groups, gw), sg, Scaled(sg, 0.137f0)),
      sign in (1f0, -1f0)
    g isa NormL1Nonneg && sign < 0 && continue
    grouped = g isa Union{GroupNormL2, SparseGroupNormL2, Scaled}
    b = Float32[sign * 0.4, 0.25, 0, 0]
    x = grouped ? AtomIterate(b, groups) : SparseIterate(b)
    m = cdmodel(0.3f0 * GLMLoss(ProximalBase.Squared(), y, X; weights = w, offset = o), nothing; intercept = icpt)
    PS.initialize!(m, x)
    for cand in (nothing, grouped ? [1] : [1, 2])
      P, D, t = PS._wide_gap(m, g, x, cand)
      oracle = gap64(m, g, x; candidates = cand)
      @test 0 < t <= 1
      @test isapprox((P - D) / P, oracle; atol = 1e-11, rtol = 0)
    end
  end
  # A tiny slack times a large coefficient must not subtract large products.
  x = SparseIterate(Float32[1e16])
  ζ = prevfloat(0.125)
  actual = PS._wide_penalty_gap(NormL1(0.125f0), x, [-ζ], 1.0, nothing)
  expected = Float64((BigFloat(0.125) - BigFloat(ζ)) * BigFloat(x[1]))
  @test actual == expected
end

@testset "Wide group norms retain tiny gradients" begin
  a = 1f-35
  groups = [[1]]
  f = a * GLMLoss(ProximalBase.Squared(), Float32[0], reshape([a], 1, 1); weights = [a])
  x = AtomIterate([a], groups)
  m = cdmodel(f, nothing)
  PS.initialize!(m, x)
  sg = SparseGroupNormL2(1e-200, 1e-200, groups, [1.0])
  penalties = ((GroupNormL2(1e-200, groups, [1.0]), 1e-200),
               (SparseGroupNormL2(0.0, 1e-200, groups, [1.0]), 1e-200),
               (sg, 2e-200), (Scaled(sg, 0.5), 1e-200))
  for (g, c) in penalties, cand in (nothing, [1])
    P, D, t = PS._wide_gap(m, g, x, cand)
    expected = Float64(BigFloat(c) / BigFloat(a)^5)
    @test isfinite(P) && P > 0
    @test isapprox(t, expected; rtol = 8eps(Float64))
    @test isapprox((P - D) / P, 1; rtol = 8eps(Float64))
  end
  r = @test_logs (:warn, r"relative duality gap .* does not certify") solve!(x, f, first(penalties)[1],
                   CDSolver(; gaptol = 1e-4, order = :cyclic, momentum = false))
  @test !r.converged && isapprox(r.gap, 1; rtol = eps(Float32))
  @test Vector(x) == [a]

  # The directional term also needs the tiny dual norm after scaling.
  b, z, c = Float32[3e-35, 4e-35], Float64[3e-175, 4e-175], 5e-175
  g = GroupNormL2(c, [[1, 2]], [1.0])
  expected = Float64(BigFloat(c) * norm(BigFloat.(b)) + dot(BigFloat.(z), BigFloat.(b)))
  gap = PS._wide_penalty_gap(g, b, z, 1.0, nothing)
  @test isapprox(gap, expected; rtol = 8eps(Float64))
  @test isapprox(PS._groupscale(GroupNormL2(1e-200, [[1, 2]], [1.0]), z, [1], true),
                 1e-200 / 5e-175; rtol = 8eps(Float64))
end

@testset "Wide elastic-net gaps with a tiny ridge stay finite" begin
  a = 1f-35
  f = a * GLMLoss(ProximalBase.Squared(), Float32[1e-35, 1e18], reshape(Float32[1e-35, 0], 2, 1);
                 weights = Float32[1e-35, 1])
  g = ElasticNet(0.0, 1e-300)
  x = SparseIterate(Float32[0])
  m = cdmodel(f, nothing)
  PS.initialize!(m, x)
  # At zero the residual dual point has unit scale and ζ = a^4.
  expected = Float64(BigFloat(a)^8 / (2BigFloat(g.λ2)))
  P, D, t = PS._wide_gap(m, g, x, nothing)
  @test t == 1
  @test isfinite(P - D) && isapprox(P - D, expected; rtol = 8eps(Float64))
  dg = duality_gap(f, g, Float32[0])
  @test isfinite(dg.gap) && isapprox(dg.gap, expected; rtol = 2eps(Float32))
end

@testset "Compensated residuals retain small terms between large columns" begin
  for sparseX in (false, true)
    X = Float32[1 1 1; 1 0 -1]
    X = sparseX ? sparse(X) : X
    m = cdmodel(GLMLoss(ProximalBase.Squared(), Float32[0, 2e16], X;
                       offset = Float32[0.125, 0.125]), nothing; intercept = true)
    fill!(m.xbar, 0)
    m.ybar = 0.25f0
    for x in (Float32[1e16, 1, -1e16], SparseIterate(Float32[1e16, 1, -1e16]))
      @test PS._wide_residuals(m, x) == [-1.375, -0.375]
    end
  end
end

@testset "Large-response gaps avoid dual cancellation" begin
  X = reshape(Float32[1, 0, -1], 3, 1)
  for weighted in (false, true), sparseX in (false, true)
    if weighted
      XX = reshape(Float32[1, 0, -1, 2], 4, 1)
      y, o = Float32[1e16, 5, -1e16, 3], Float32[5e15, 1, -5e15, 3]
      f = 0.25f0 * GLMLoss(ProximalBase.Squared(), y, XX; weights = Float32[2, 1, 2, 0], offset = o)
    else
      f = LeastSquaresLoss(Float32[1e16, 1, -1e16], X)
    end
    base = cdmodel(f, nothing; intercept = true)
    design = sparseX ? sparse(base.X) : base.X
    g = NormL1(1f-22)
    for b0 in (0.125f0, weighted ? 0.8f0 : Float32(1 / 3)), screening in (false, true)
      m = PS.LSModel(base.y, design, base.w, base.offset, base.s; intercept = true)
      # Fix the returned intercept instead of relying on native mean rounding.
      fill!(m.xbar, 0)
      m.ybar = b0
      b = Float32[weighted ? 5e15 : 1e16]
      x = SparseIterate(b)
      rb = BigFloat.(m.y) .- (m.offset === nothing ? 0 : BigFloat.(m.offset)) .-
           BigFloat(b0) .- BigFloat.(m.X) * BigFloat.(Vector(x))
      @test PS._wide_residuals(m, x) == Float64.(rb)
      oracle = gapbig(m, g, x)
      @test b0 == 0.125f0 ? oracle > 0.1 : oracle < PS.PATH_GAPTOL
      # These residuals are exactly recovered. Allow Float64 accumulation
      # error internally and two Float32 roundings in the public ratios.
      P, D, _ = PS._wide_gap(m, g, x, nothing)
      @test isapprox((P - D) / P, oracle; atol = 32eps(Float64), rtol = 0)
      dg = duality_gap(m, g, x)
      @test isapprox(dg.gap / dg.primal, oracle; atol = 32eps(Float64), rtol = 2eps(Float32))
      r = @test_logs (:warn, r"did not converge in maxpasses") solve_path(m, NormL1(1f0), [g.λ0],
                       CDSolver(; maxpasses = 0, order = :cyclic, momentum = false); x, screening)
      @test r.solutions[1] == Vector(x) == b && r.passes[1] == 0
      @test isapprox(r.gap[1], oracle; atol = 32eps(Float64), rtol = eps(Float32))
    end
    for screening in (false, true)
      m = PS.LSModel(base.y, design, base.w, base.offset, base.s; intercept = true)
      x = SparseIterate(Float32, 1)
      # The native solve may reach either point on different platforms.
      r = @test_logs min_level = Base.CoreLogging.Error solve_path(m, NormL1(1f0), [g.λ0],
                       CDSolver(; order = :cyclic, momentum = false); x, screening)
      oracle = gapbig(m, g, x)
      @test !r.converged[1] || oracle <= PS.PATH_GAPTOL
      @test isapprox(r.gap[1], oracle; atol = 32eps(Float64), rtol = eps(Float32))
    end
  end
end

@testset "Centred Newton models retain the intercept constraint at zero means" begin
  X = reshape(Float32[1, 0, -1], 3, 1)
  for icpt in (false, true)
    outer = cdmodel(LogisticLoss(Float32[0, 1, 0], X), nothing; intercept = icpt)
    x = SparseIterate(Float32[1e16])
    s = CDSolver(; order = :cyclic, momentum = false, gaptol = 1e-4)
    ws = PS._NewtonWorkspace(outer, x, s)
    ws.v .= 1
    ws.z .= Float32[1e16, 1, -1e16]
    @test !ws.model.intercept
    icpt && PS._center!(ws, nothing)
    m = ws.model
    @test m.intercept == icpt
    @test iszero(m.ybar) && all(iszero, m.xbar)
    if icpt
      r = @test_logs (:warn, r"relative duality gap .* does not certify") solve!(x, m, NormL1(0f0), s)
      @test !r.converged && isapprox(r.gap, 1 / 3; atol = 2e-8, rtol = 0)
    else
      r = @test_logs solve!(x, m, NormL1(0f0), s)
      @test r.converged && r.gap <= s.gaptol
    end
    @test isapprox(r.gap, gapbig(m, NormL1(0f0), x); atol = 2e-8, rtol = 0)
  end
end

@testset "Final Float32 certificates control the flag and reported gap" begin
  # The native gradient rounds the second constraint down to its threshold.
  X = Float32[1 1; 0 eps(Float32)/4]
  m = cdmodel(LeastSquaresLoss(Float32[1.25, 0.25], X), nothing)
  x = SparseIterate(Float32[1, 0])
  g = NormL1(0.25f0)
  s = CDSolver(; gaptol = 1e-9, order = :cyclic)
  st = PS._CDState(Float32, x, s)
  PS.initialize!(m, x)
  checks = PS._screened!(x, m, g, g.λ0, Float32[0.25, 0], st, s, falses(2))
  @test checks == PS._GAPRETRIES + 1
  @test !st.converged && st.relgap > s.gaptol
  @test isapprox(st.relgap, gap64(m, g, x); atol = 1e-9, rtol = 0)

  # Compare before rounding the certificate to the result's element type.
  checked = false
  for a in (eps(Float32) / 4, eps(Float32) / 2, 3eps(Float32) / 4, 1f-4)
    m = cdmodel(LeastSquaresLoss(Float32[1.25, 0.25], Float32[1 1; 0 a]), nothing)
    PS.initialize!(m, x)
    P, D, _ = PS._wide_gap(m, g, x, nothing)
    gap = PS._relative_gap(P, D)
    rounded = Float64(Float32(gap))
    rounded < gap || continue
    s = CDSolver(; gaptol = (rounded + gap) / 2)
    st = PS._CDState(Float32, x, s)
    gs = PS._gapstart!(st, m, g, x, s)
    available, certified, _ = PS._gapcheck!(gs, x, m, g, st, s, true)
    @test available && !certified && st.relgap <= s.gaptol
    @test PS._fullgap!(st, m, g, x, gs.z) > s.gaptol
    checked = true
    break
  end
  @test checked

  rng = Xoshiro(8128)
  X = randn(rng, Float32, 20, 6)
  y = X * ones(Float32, 6) .+ randn(rng, Float32, 20) ./ 10
  for T in (Float32, Float64), options in ((; order = :cyclic), (; momentum = true, rng = Xoshiro(1)),
                                           (; order = :cyclic, anderson = 2)), maxpasses in (0, 1, 3)
    m = cdmodel((1 / 20) * LeastSquaresLoss(T.(y), T.(X)), nothing)
    x = SparseIterate(T, 6)
    g = NormL1(T(0.01))
    r = @test_logs (:warn, r"did not converge in maxpasses") solve!(x, m, g, CDSolver(; maxpasses, gaptol = 1e-12, options...))
    @test !r.converged && isfinite(r.gap)
    @test isapprox(r.gap, gap64(m, g, x); atol = 1e-7, rtol = 1e-5)
  end
end

# A small logistic diagnostic measures native rounding; it does not provide
# a precision guarantee for other GLM problems.
function logistic_gap64(m, λ, b, b0)
  X, y, b = Float64.(m.X), Float64.(m.y), Float64.(Vector(b))
  η = Float64(b0) .+ X * b
  s = Float64(m.s)
  P = s * sum(log1p.(exp.(η)) .- y .* η) + Float64(λ) * sum(abs, b)
  q = 1 ./ (1 .+ exp.(-η))
  if m.intercept
    c = 0.0
    for _ in 1:12
      q = 1 ./ (1 .+ exp.(-η .- c))
      c -= sum(q .- y) / sum(q .* (1 .- q))
    end
    q = 1 ./ (1 .+ exp.(-η .- c))
  end
  d = q .- y
  t = min(1.0, Float64(λ) / norm(s .* (X' * d), Inf))
  u = clamp.(y .+ t .* d, 0, 1)
  xlogx(v) = iszero(v) ? 0.0 : v * log(v)
  D = -s * sum(xlogx.(u) .+ xlogx.(1 .- u))
  (P - D) / P
end

@testset "Float32 proximal Newton keeps its logistic certificates" begin
  rng = Xoshiro(128)
  n, p = 60, 20
  X = randn(rng, Float32, n, p)
  b = zeros(Float32, p); b[1:4] .= Float32[1, -1, 0.5, -0.5]
  y = Float32.(rand(rng, n) .< 1 ./ (1 .+ exp.(-X * b)))
  f = (1 / n) * LogisticLoss(y, X)
  for icpt in (false, true)
    m = cdmodel(f, nothing; intercept = icpt)
    g = NormL1(1f0)
    λmax = lambda_max(m, g, SparseIterate(Float32, p))
    λs = Float32.(λmax .* exp10.(range(0, -1.5; length = 12)))
    b0 = Float64[]
    save(k, λ, x, m) = (push!(b0, Float64(PS.intercept(m, x))); false)
    r = solve_path(m, g, λs, ProxNewton(; inner = CDSolver(; rng = Xoshiro(1))); x = SparseIterate(Float32, p), devmax = 1,
                   callback = save)
    @test all(r.converged)
    @test all(<=(PS.PATH_GAPTOL), r.gap)
    oracle = [logistic_gap64(m, r.λ[k], r.solutions[k], b0[k]) for k in eachindex(r.λ)]
    @test maximum(abs.(Float64.(r.gap) .- oracle)) < 1e-6
    @test all(<=(PS.PATH_GAPTOL), oracle)
  end
end

end
