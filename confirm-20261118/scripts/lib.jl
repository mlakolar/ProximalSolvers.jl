# Harness for the #155 confirmation round (research only). Methods M0, M1 (D2, production bounds,
# in-package prototype), M1g (D2 with the generalized validator as an extra bank source), M2/M2g (PDHG).
using ProximalBase, ProximalSolvers, LinearAlgebra, Logging, Random, Serialization, Printf
const PS = ProximalSolvers
const HERE = @__DIR__
include(joinpath(HERE, "matrix.jl"))          # first-study generators: noiseless, noisy, lammax, start_point
const up = PS._up
const dn = PS._dn
const TARGET = prevfloat(1e-4)
include(joinpath(HERE, "vcert.jl"))           # first-study generalized validator (agents/A/lib.jl)
setprecision(BigFloat, 256)
Pbig(X, y, λ, b) = norm(big.(y) - big.(X) * big.(b)) + big(λ) * norm(big.(b), 1)

# ---- generators (first study: realistic.jl `design`, orch_d2_cor.jl `corr`) -----------------------
using SpecialFunctions: erfcinv
qnorm(u) = -sqrt(2) * erfcinv(2u)
function design(n, p, ρ, s, seed)
  rng = Xoshiro(seed)
  Z = randn(rng, n, p)
  if ρ > 0
    for j in 2:p
      Z[:, j] .= ρ .* Z[:, j-1] .+ sqrt(1 - ρ^2) .* Z[:, j]
    end
  end
  X = Z ./ sqrt.(sum(abs2, Z; dims = 1)) .* sqrt(n)
  β = zeros(p); β[1:s] .= [(-1)^j for j in 1:s]
  X, X * β .+ randn(Xoshiro(seed + 999), n)
end
function corr(n, p, k, σ, ρ, seed)
  rng = Xoshiro(seed); Z = randn(rng, n, p); z0 = randn(rng, n); Z = sqrt(1 - ρ) .* Z .+ sqrt(ρ) .* z0
  b = zeros(p); b[1:k] .= [(-1)^j * (1 + j / k) for j in 1:k]; Z, Z * b .+ σ .* randn(rng, n)
end

# ---- the problem sets (protocol §2) ---------------------------------------------------------------
function dev_problems()
  P = NamedTuple[]
  X = [1.0 1.0; 0.0 0.01]; push!(P, (; id = "A155", group = "fixture", X, y = X * [1.0, -1.0], λ = 0.1, starts = (:zero, :given)))
  push!(P, (; id = "A156", group = "fixture", X = [1.0 2.0; 0.0 1.0], y = [1.0, 0.0], λ = 0.1, starts = (:zero, :given)))
  push!(P, (; id = "AI3", group = "fixture", X = Matrix(1.0I, 3, 3), y = ones(3), λ = 0.65, starts = (:zero, :given)))
  P
end
function heldout_problems()
  P = NamedTuple[]
  add!(id, group, X, y, λ, starts) = push!(P, (; id, group, X, y, λ, starts))
  S3 = (:zero, :lnfit, :warm)
  for f in (0.05, 0.2), s in 9101:9104
    X, y = noiseless(8, 20, 3, s); add!("N8p20-$f-s$s", "H-mat N8p20", X, y, f * lammax(X, y), S3)
  end
  for f in (0.05, 0.2), s in 9201:9203
    X, y = noiseless(40, 120, 5, s); add!("N40p120-$f-s$s", "H-mat N40p120", X, y, f * lammax(X, y), S3)
  end
  for s in 9301:9302
    X, y = noiseless(100, 400, 10, s); add!("N100p400-s$s", "H-mat N100p400", X, y, 0.1 * lammax(X, y), S3)
  end
  for σ in (1e-7, 1e-4), s in 9401:9403
    X, y = noisy(30, 80, 4, σ, s); add!("NE$σ-s$s", "H-mat NE", X, y, 0.05 * lammax(X, y), S3)
  end
  for s in 9501:9503
    X, y = noisy(60, 20, 4, 1.0, s); add!("O60p20-s$s", "H-mat O60p20", X, y, 0.1 * lammax(X, y), S3)
  end
  for f in (0.1, 0.2, 0.3, 0.4), s in 9601:9602
    X, y = noisy(40, 120, 5, 0.5, s); add!("SW$f-s$s", "H-mat SW", X, y, f * lammax(X, y), S3)
  end
  for s in 9701:9703
    X, y = noiseless(40, 120, 5, s; ρ = 0.95); add!("C95-s$s", "H-mat C95", X, y, 0.1 * lammax(X, y), S3)
  end
  for s in 9801:9803
    X, y = noiseless(20, 40, 3, s; dup = 10); add!("D10-s$s", "H-mat D10", X, y, 0.1 * lammax(X, y), S3)
  end
  for (n, p) in ((100, 500), (100, 2000), (50, 1000), (200, 1000)), ρ in (0.0, 0.5, 0.9), s in (5, 20), seed in (9901, 9902)
    X, y = design(n, p, ρ, s, seed)
    add!("R$(n)x$(p)-r$ρ-s$s-$seed", "H-real", X, y, 0.25 * 1.1 * qnorm(1 - 0.05 / (2p)), (:zero,))
  end
  for f in (0.05, 0.2), seed in 9951:9955
    X, y = corr(60, 150, 4, 1.0, 0.7, seed); add!("COR-$f-s$seed", "H-cor", X, y, f * lammax(X, y), (:zero,))
  end
  for f in (1e-2, 1e-3), seed in 9961:9963
    X, y = noiseless(40, 120, 5, seed); add!("SM40-$f-s$seed", "H-small", X, y, f * lammax(X, y), (:zero,))
  end
  X, y = noiseless(100, 400, 10, 9964); add!("SM100-0.001-s9964", "H-small", X, y, 1e-3 * lammax(X, y), (:zero,))
  P
end

# ---- solves ---------------------------------------------------------------------------------------
const CONFIGS = ("cyclic-dense", "random-sparse")
cfgkw(c, rng) = c == "cyclic-dense" ? (; order = :cyclic, momentum = false) : (; rng)
# one production solve with the fallback mode (:off = M0 or a polish, :d2 = M1/M1g); returns
# (x::Vector{T}, result, seconds, fallback log record or nothing)
function solve_mode(X::Matrix{T}, y::Vector{T}, λ, β0, config; mode = :off, dual = nothing, maxpasses = 100_000,
                    rng = Xoshiro(7)) where T
  owner = config == "random-sparse"
  x = owner ? SparseIterate(T.(β0)) : T.(β0)
  PS._FALLBACK[] = mode; PS._FALLBACK_DUAL[] = dual; lg = Any[]; PS._FALLBACK_LOG[] = lg
  local r
  t = @elapsed with_logger(NullLogger()) do
    r = solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(; maxpasses, cfgkw(config, rng)...))
  end
  PS._FALLBACK[] = :d2; PS._FALLBACK_DUAL[] = nothing; PS._FALLBACK_LOG[] = nothing
  (owner ? Vector(x) : x), r, t, isempty(lg) ? nothing : only(lg)
end
# the production certificate at a point β of T (exposed bounds of the prototype)
function cert_at(X::Matrix{T}, y::Vector{T}, λ, β::AbstractVector) where T
  x = SparseIterate(T.(β)); f = SqrtLeastSquaresLoss(y, X); g = NormL1(λ)
  m = PS.cdmodel(f, x); PS.initialize!(m, x); PS._prepare!(m, g, x)
  code, ratio = PS._certify!(m, x)
  (; code, ratio, pup = m.cpup, plo = m.cplo, dlo = m.cdlo)
end
valid(d) = (isfinite(d) && d > 0) ? d : 0.0
# generalized validator dual bound at β with θ̂ (Float64)
function gdual(X64, y64, lo, hi, β64, θ)
  v = vcert(X64, y64, lo, hi, β64, θ)
  valid(v.Dlo)
end
gdual_r(X64, y64, lo, hi, β64) = gdual(X64, y64, lo, hi, β64, y64 .- X64 * β64)
# M1g hook: the generalized validator at θ̂ = r̂ of the current point (Float64 copies cached per X)
const X64CACHE = IdDict{Any, Matrix{Float64}}()
function m1g_dual(m, x)
  X = m.ls.X; X64 = get!(() -> Float64.(X), X64CACHE, X); y64 = Float64.(m.ls.y)
  gdual_r(X64, y64, m.lo64, m.hi64, Float64.(Vector(x)))
end
ratio_of(P, D) = D > 0 ? up(up(P - D) / D) : Inf
shrink(z, t) = sign(z) * max(abs(z) - t, zero(z))

# M2/M2g: PDHG (protocol §1), in T; then a production polish (fallback off) with the remaining budget.
function pdhg_fallback(X::Matrix{T}, y::Vector{T}, λ, x0::Vector{T}, base::Int, config, rng; gen = false) where T
  t0 = time_ns()
  n, p = size(X)
  budget = min(100_000 - base, max(2000, 20base))
  X64, y64 = Float64.(X), Float64.(y); lo, hi = PS._level_brackets(λ)
  c0 = cert_at(X, y, λ, x0); P0, L0 = c0.pup, c0.plo; D = valid(c0.dlo)
  gen && (D = max(D, gdual_r(X64, y64, lo, hi, Float64.(x0))))
  v = fill(1 / sqrt(p), p); L2 = 0.0
  for _ in 1:30
    w = X64 * v; u = X64' * w; L2 = norm(u); v = u / L2
  end
  L = 1.01 * sqrt(L2); ω = norm(y64) / L
  τ, σ = T(0.99 * ω / L), T(0.99 / (ω * L)); λT = T(λ)
  mv = 60; iters = 0; used = 0
  β = copy(x0); βbar = copy(β); θ = zeros(T, n); u = zeros(T, n); g = zeros(T, p); βold = similar(β)
  Kmax = budget ÷ 2
  certified, via, ratio, ret = false, "none", Inf, x0
  for k in 1:Kmax
    mul!(u, X, βbar); mv += 1
    @. θ = θ + σ * (u - y); nθ = norm(θ); nθ > 1 && (θ ./= nθ)
    mul!(g, X', θ); mv += 1
    copyto!(βold, β)
    @. β = shrink(β - τ * g, τ * λT)
    @. βbar = 2β - βold
    iters = k
    if k % 20 == 0 || k == Kmax
      c = cert_at(X, y, λ, β); mv += 1; D = max(D, valid(c.dlo))
      if gen
        D = max(D, gdual(X64, y64, lo, hi, Float64.(β), -Float64.(θ)), gdual_r(X64, y64, lo, hi, Float64.(β))); mv += 2
      end
      r0 = ratio_of(P0, D)
      if r0 <= TARGET
        certified, via, ratio, ret = true, "x0", r0, x0; break
      end
      rb = ratio_of(c.pup, D)
      if rb <= TARGET && c.pup < L0
        certified, via, ratio, ret = true, "pdhg", rb, copy(β); break
      end
    end
  end
  used = iters; polish_passes = 0
  if !certified
    xp, rp, _, _ = solve_mode(X, y, λ, β, config; mode = :off, maxpasses = budget - used, rng)
    polish_passes = rp.passes; used += rp.passes
    c = cert_at(X, y, λ, xp); D = max(D, valid(c.dlo))
    gen && (D = max(D, gdual_r(X64, y64, lo, hi, Float64.(xp))))
    r0 = ratio_of(P0, D); rb = ratio_of(c.pup, D)
    if r0 <= TARGET
      certified, via, ratio, ret = true, "x0", r0, x0
    elseif rb <= TARGET && c.pup < L0
      certified, via, ratio, ret = true, "polish", rb, xp
    elseif c.pup < L0
      via, ratio, ret = "improved", rb, xp
    else
      via, ratio, ret = "kept", r0, x0
    end
  end
  (; ret, certified, via, ratio, budget, used, iters, polish_passes, matvecs = mv, D, P0, L0,
     secs = (time_ns() - t0) / 1e9)
end
