# Float32 certificates, representative cases: lasso and group-lasso paths against a Float64
# oracle, stagnation with a reachable target, and the final certificate that sets the flag and
# the reported gap. Moved from test/float32_certificates.jl to run in the quick tier (#121); the
# other cases of `float32_certificates.jl` stay there.

module Float32CertificateBasicsTests

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

end
