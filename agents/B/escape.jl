# Agent B prototypes: strategies to escape non-optimal exact fits of the square-root lasso (#155).
# Research code (no production changes). Everything calls the production solver (`ps_solve`) and the production
# certificate (`certify_at`) from scripts/common.jl.
get(ENV, "ORACLE_PLAIN", "") == "1" ? include(joinpath(@__DIR__, "common_plain.jl")) : include(joinpath(@__DIR__, "..", "..", "scripts", "common.jl"))
using LinearAlgebra

# ---------------------------------------------------------------------------------------------------------
# Objective of the ORIGINAL problem at a point β stored in T, evaluated in Float64 from the T data (for Float32
# data the products are exact in Float64; for Float64 data the rounding is ε‖μ‖). Returns (F̂, E): F̂ = ‖r̂‖+λ‖β‖₁,
# E = error bound ((m+1)ε‖μ̂‖ + (m+2)ε λ‖β‖₁ + tiny), the same model as step 1 of `_certify!`.
function fhat(X::Matrix{T}, y::Vector{T}, λ, β::AbstractVector) where T
  n = length(y)
  r = Float64.(y); μ = abs.(r); m = 0; l1 = 0.0
  for k in eachindex(β)
    v = Float64(β[k]); iszero(v) && continue
    m += 1; l1 += abs(v)
    @inbounds for i in 1:n
      t = Float64(X[i, k]) * v
      r[i] -= t; μ[i] += abs(t)
    end
  end
  ε = eps(Float64)
  F = norm(r) + Float64(λ) * l1
  E = (m + 1) * ε * norm(μ) + (m + 2) * ε * Float64(λ) * l1 + 1e-300
  F, E, r
end
# rigorous-margin decrease test: F̂_new + E_new < F̂_old − E_old
strict_decrease(new, old) = new[1] + new[2] < old[1] - old[2]

# ---------------------------------------------------------------------------------------------------------
# Directional lasso at β (support S, signs s):  ψ(d) = ½‖Xd‖² + λ sᵀd_S + λ‖d_{S^c}‖₁, by coordinate descent in T.
# ρ(d) = −h(d)/‖Xd‖ with h = λ sᵀd_S + λ‖d_{S^c}‖₁: F'(β;d) = ‖Xd‖(1 − ρ(d)) at an exact fit, so ρ > 1 ⇔ descent.
# Stops: ρ ≥ target (descent direction found), ψ no longer decreasing (converged: at a minimizer ρ = ‖Xd*‖ =
# ‖θ_min‖ ≤ 1 iff the exact fit is optimal), or maxpasses. Returns (d, u = Xd, ρ, passes, status).
function dirlasso(X::Matrix{T}, β::AbstractVector, λ::T; maxpasses = 200, target = 2.0, rtol = 1e-7) where T
  n, p = size(X)
  d = zeros(T, p); u = zeros(T, n)
  a = zeros(T, p)
  @inbounds for k in 1:p
    s = zero(T); @simd for i in 1:n; s += X[i, k]^2; end; a[k] = s
  end
  sg = T.(sign.(β)); inS = sg .!= 0
  ψprev = zero(Float64); ρ = 0.0; status = :maxpasses; passes = 0
  for pass in 1:maxpasses
    passes = pass
    @inbounds for k in 1:p
      iszero(a[k]) && continue
      b = zero(T); @simd for i in 1:n; b += X[i, k] * u[i]; end
      g = b - a[k] * d[k]
      new = inS[k] ? -(g + λ * sg[k]) / a[k] : (c = -g / a[k]; τ = λ / a[k]; c > τ ? c - τ : c < -τ ? c + τ : zero(T))
      Δ = new - d[k]
      if !iszero(Δ)
        @simd for i in 1:n; u[i] += Δ * X[i, k]; end
        d[k] = new
      end
    end
    h = 0.0
    @inbounds for k in 1:p
      h += inS[k] ? Float64(sg[k] * d[k]) : abs(Float64(d[k]))
    end
    h *= Float64(λ)
    nu = norm(Float64.(u))
    ρ = nu > 0 ? -h / nu : (h < 0 ? Inf : 0.0)
    ψ = 0.5 * nu^2 + h
    if ρ >= target; status = :descent; break; end
    if pass > 1 && (ψprev - ψ) <= rtol * abs(ψprev)
      status = :converged; break
    end
    ψprev = ψ
  end
  d, u, ρ, passes, status
end

# ---------------------------------------------------------------------------------------------------------
# Exact minimization of φ(t) = ‖r − t u‖ + λ‖β + t d‖₁ over t ≥ 0 (convex; ℓ1 part piecewise linear with
# breakpoints t_k = −β_k/d_k, smooth part √(C (t−t0)² + δ²)); r, u in Float64. Returns t*.
function line_min(r::Vector{Float64}, u::Vector{Float64}, β::AbstractVector, d::AbstractVector, λ)
  C = dot(u, u); ru = dot(r, u); rr = dot(r, r)
  λ = Float64(λ)
  c0 = 0.0
  bk_d = Tuple{Float64, Float64}[]            # (breakpoint t_k, slope change 2|d_k| of the ℓ1 part)
  for k in eachindex(β)
    dk = Float64(d[k]); iszero(dk) && continue
    bk = Float64(β[k])
    if iszero(bk); c0 += abs(dk)
    else
      c0 += dk * sign(bk)
      sign(bk) != sign(dk) && push!(bk_d, (-bk / dk, 2abs(dk)))
    end
  end
  sort!(bk_d; by = first)
  c = λ * c0
  if C == 0.0                                  # u = 0: φ is piecewise linear
    c >= 0 && return 0.0
    for (t, j) in bk_d
      c += λ * j
      c >= 0 && return t
    end
    return Inf
  end
  t0 = ru / C; δ = sqrt(max(rr - ru^2 / C, 0.0)); sC = sqrt(C)
  L = 0.0; idx = 1
  while true
    R = idx <= length(bk_d) ? bk_d[idx][1] : Inf
    if abs(c) < sC
      th = t0 - c * δ / (sC * sqrt(C - c^2))
      th <= L && return L
      th <= R && return th
    elseif c > 0
      return L
    end
    idx > length(bk_d) && return L
    L = R
    c += λ * bk_d[idx][2]
    idx += 1
  end
end

# apply β ← β + t d in T, snapping the coordinates that cross zero at (or before) t to exactly 0
function apply_step(β::AbstractVector{T}, d, t) where T
  βn = Vector{T}(β)
  for k in eachindex(βn)
    iszero(d[k]) && continue
    v = Float64(β[k]) + t * Float64(d[k])
    if !iszero(β[k]) && sign(Float64(β[k])) != sign(Float64(d[k])) && abs(-Float64(β[k]) / Float64(d[k]) - t) <= 8eps() * t
      v = 0.0
    end
    βn[k] = T(v)
  end
  βn
end

# ---------------------------------------------------------------------------------------------------------
# Candidate C: escape by the directional lasso + exact line search on F + strict-decrease acceptance.
# Returns (β_new or nothing, info NamedTuple).
function escape_C(X::Matrix{T}, y::Vector{T}, λ, β; maxpasses = 200, target = 2.0) where T
  F0 = fhat(X, y, λ, β)
  d, u, ρ, ps, st = dirlasso(X, β, T(λ); maxpasses, target)
  info = (; passes = ps, ρ, dstatus = st, visits = ps * size(X, 2), accepted = false, t = NaN)
  ρ <= 1 + 1e-6 && return nothing, info
  u64 = Float64.(X) * Float64.(d)            # recomputed in Float64 (O(np))
  t = line_min(F0[3], u64, β, d, λ)
  (isfinite(t) && t > 0) || return nothing, merge(info, (; t))
  βn = apply_step(β, d, t)
  F1 = fhat(X, y, λ, βn)
  strict_decrease(F1, F0) || return nothing, merge(info, (; t))
  βn, merge(info, (; accepted = true, t, Fold = F0[1], Fnew = F1[1]))
end

# Candidate C, multi-step: up to `inner` successive (direction, exact line search) steps without production CD in between
# (each step re-reads the support, so a coordinate that the line search drove to 0 becomes an off-support constraint).
function escape_Cm(X::Matrix{T}, y::Vector{T}, λ, β; inner = 20, maxpasses = 200, target = 2.0) where T
  β = Vector{T}(β)
  passes = 0; steps = 0; lastρ = NaN; reason = :none
  F0 = fhat(X, y, λ, β)
  for it in 1:inner
    d, u, ρ, ps, st = dirlasso(X, β, T(λ); maxpasses, target)
    passes += ps; lastρ = ρ
    if ρ <= 1 + 1e-6; reason = :nodescent; break; end
    u64 = Float64.(X) * Float64.(d)
    t = line_min(F0[3], u64, β, d, λ)
    if !(isfinite(t) && t > 0); reason = :badline; break; end
    βn = apply_step(β, d, t)
    F1 = fhat(X, y, λ, βn)
    if !strict_decrease(F1, F0); reason = :noaccept; break; end
    β, F0 = βn, F1; steps += 1
  end
  steps == 0 && return nothing, (; accepted = false, passes, ρ = lastρ, visits = passes * size(X, 2), steps, reason)
  β, (; accepted = true, passes, ρ = lastρ, visits = passes * size(X, 2), steps, reason)
end

# ---------------------------------------------------------------------------------------------------------
# Candidate A: restart from zero (A1: accept 0 if F(0) < F(β) strictly; A2: also a full solve from 0, keep better).
function escape_A1(X::Matrix{T}, y::Vector{T}, λ, β) where T
  F0 = fhat(X, y, λ, β)
  βz = zeros(T, length(β)); F1 = fhat(X, y, λ, βz)
  strict_decrease(F1, F0) ? (βz, (; accepted = true, passes = 0, visits = 0)) : (nothing, (; accepted = false, passes = 0, visits = 0))
end

# ---------------------------------------------------------------------------------------------------------
# Candidate B: best pair within the support (closed form block ψ_T, T = {j,k} ⊂ S), then the same exact line search.
# Cost O(|S|² n) for the Gram of the support (capped at 64 support columns, the 64 largest |β|).
function escape_B(X::Matrix{T}, y::Vector{T}, λ, β) where T
  n, p = size(X)
  S = findall(!iszero, β)
  length(S) > 64 && (S = S[sortperm(abs.(β[S]); rev = true)[1:64]])
  length(S) < 2 && return nothing, (; accepted = false, passes = 0, visits = 0, ρ = 0.0)
  Xs = Float64.(X[:, S]); G = Xs' * Xs; sg = sign.(Float64.(β[S])); λf = Float64(λ)
  best, bj, bk, bd = 0.0, 0, 0, zeros(2)
  for j in 1:length(S), k in j+1:length(S)
    g11, g12, g22 = G[j, j], G[j, k], G[k, k]
    s1, s2 = sg[j], sg[k]
    det = g11 * g22 - g12^2
    if det <= 1e-13 * g11 * g22              # (nearly) collinear pair: nullspace-type direction
      v = [g22 == 0 ? 1.0 : -g12 / g11, 1.0]; v = [g12 == 0 ? 0.0 : 1.0, g12 == 0 ? 1.0 : -g11 / g12] # v ∈ null(G)
      v = [-g12, g11]; nv = norm(v); nv == 0 && continue; v ./= nv
      s = s1 * v[1] + s2 * v[2]
      abs(s) < 1e-12 && continue
      ρ = Inf; dd = -sign(s) .* v
    else
      w1 = (g22 * s1 - g12 * s2) / det; w2 = (-g12 * s1 + g11 * s2) / det   # G⁻¹ s
      ρ = λf * sqrt(max(s1 * w1 + s2 * w2, 0.0)); dd = -λf .* [w1, w2]
    end
    if ρ > best; best, bj, bk, bd = ρ, j, k, dd; end
  end
  info = (; accepted = false, passes = 0, visits = length(S)^2 ÷ 2, ρ = best)
  best <= 1 + 1e-6 && return nothing, info
  d = zeros(T, p); d[S[bj]] = T(bd[1]); d[S[bk]] = T(bd[2])
  F0 = fhat(X, y, λ, β)
  u64 = Float64.(X) * Float64.(d)
  t = line_min(F0[3], u64, β, d, λ)
  (isfinite(t) && t > 0) || return nothing, info
  βn = apply_step(β, d, t)
  F1 = fhat(X, y, λ, βn)
  strict_decrease(F1, F0) ? (βn, merge(info, (; accepted = true))) : (nothing, info)
end

# ---------------------------------------------------------------------------------------------------------
# Candidate D: smoothing continuation. Stage j solves F_δj (augmented data [y; δ], [X; 0ᵀ]) by the production
# solver, warm started; after each stage the production certificate at the stage point on the ORIGINAL data.
function smooth_stage(X::Matrix{T}, y::Vector{T}, λ, β, δ; cfg, cap = 20_000) where T
  Xa = vcat(X, zeros(T, 1, size(X, 2))); ya = vcat(y, T(δ))
  ps_solve(Xa, ya, λ, β; cfg..., maxpasses = cap)
end

# ---------------------------------------------------------------------------------------------------------
# Pipelines: stage 1 = the production solver exactly as the baseline (cfg), then, only if it stopped uncertified,
# the fallback `cand`. The last production solve's `converged` (the production certificate) is the final authority.
cfgmaker(name) = name == "cyclic-dense" ? (; order = :cyclic, momentum = false, owner = false) :
                 name == "random-owner" ? (; rng = Xoshiro(7), owner = true) : error("cfg")

# Fallback loop for the escape-type candidates (A1, B, C): escape (accepted only on strict decrease of F), then
# resume the production CD from the new point; at most K escapes.
function fallback_escape(X, y, λ, x, r, cfg, escfun; K = 8, kw...)
  tot = (; esc = 0, att = 0, escpasses = 0, escvisits = 0, respasses = 0, escsec = 0.0)
  esc = att = escpasses = escvisits = respasses = 0; escsec = 0.0
  for e in 1:K
    att += 1
    t = @elapsed (βn, info) = escfun(X, y, λ, x; kw...)
    escsec += t
    escpasses += info.passes; escvisits += info.visits
    βn === nothing && break
    esc += 1
    x, r, sec, _ = ps_solve(X, y, λ, βn; cfg...)
    escsec += sec; respasses += r.passes
    r.converged && break
  end
  x, r, (; esc, att, escpasses, escvisits, respasses, escsec)
end

# A2: an additional full solve from zero; keep the better point (strict rigorous margin, else keep the stuck one)
function fallback_A2(X, y, λ, x, r, cfg)
  xz, rz, sec, _ = ps_solve(X, y, λ, zeros(eltype(X), length(x)); cfg...)
  Fz = fhat(X, y, λ, xz); F0 = fhat(X, y, λ, x)
  acc = strict_decrease(Fz, F0)
  (acc ? xz : x), (acc ? rz : r), (; esc = acc ? 1 : 0, att = 1, escpasses = 0, escvisits = 0, respasses = rz.passes, escsec = sec)
end

# D: smoothing continuation, δ_j = c0 P(β₀) q^j (≥ the floor), production solver per stage, certificate after each stage
function fallback_D(X::Matrix{T}, y::Vector{T}, λ, x, r, cfg; c0 = 1e-2, q = 0.1, J = 8, floorrel = 0.0, polish = true, cap = 20_000, scale = 0) where T
  F0 = fhat(X, y, λ, x)[1]
  ny = norm(Float64.(y))
  scale == 1 && (F0 = min(F0, ny))
  β = copy(x); passes = 0; sec = 0.0; stages = 0
  for j in 0:J-1
    δ = max(c0 * F0 * q^j, floorrel * ny)
    β, rs, s, _ = smooth_stage(X, y, λ, β, δ; cfg, cap)
    passes += rs.passes; sec += s; stages += 1
    code, _ = certify_at(X, y, λ, β)
    if code === :certified
      return β, (; converged = true, gap = NaN), (; esc = stages, att = stages, escpasses = passes, escvisits = passes * size(X, 2), respasses = 0, escsec = sec)
    end
  end
  rr = nothing
  if polish
    β, rr, s, _ = ps_solve(X, y, λ, β; cfg..., maxpasses = cap)
    sec += s
    passes += rr.passes
  end
  info = (; esc = stages, att = stages, escpasses = passes, escvisits = passes * size(X, 2), respasses = 0, escsec = sec)
  conv = rr === nothing ? false : rr.converged
  conv && return β, (; converged = true, gap = rr.gap), info
  # uncertified: keep the point only if F decreased strictly (rigorous margin), else return the original point
  strict_decrease(fhat(X, y, λ, β), fhat(X, y, λ, x)) ? (β, (; converged = false, gap = NaN), info) : (x, r, info)
end

# E: λ-continuation from zero: λ_j geometric from 0.9 λmax to λ, production CD per stage, warm started
function fallback_E(X::Matrix{T}, y::Vector{T}, λ, x, r, cfg; J = 10) where T
  λmax = maximum(abs, X' * y) / norm(y)
  passes = 0; sec = 0.0
  β = zeros(T, length(x)); rs = nothing
  J = λ >= 0.9λmax ? 1 : J                    # at λ ≥ λmax the zero start is the whole path
  for j in 0:J-1
    λj = J == 1 ? λ : T(0.9λmax * (Float64(λ) / (0.9λmax))^(j / (J - 1)))
    j == J - 1 && (λj = λ)
    β, rs, s, _ = ps_solve(X, y, λj, β; cfg...)
    passes += rs.passes; sec += s
  end
  # keep the better of the stuck point and the path end (strict rigorous margin)
  acc = strict_decrease(fhat(X, y, λ, β), fhat(X, y, λ, x))
  (acc ? β : x), (acc ? rs : r), (; esc = acc ? 1 : 0, att = 1, escpasses = passes, escvisits = passes * size(X, 2), respasses = 0, escsec = sec)
end

# ---------------------------------------------------------------------------------------------------------
# D2 = D + dual-witness transfer (research stand-in: the dual bound is computed in BigFloat; production would use the
# outward-rounded D_lo that `_certify!` already forms). At every stage the point β_j gives a dual feasible
# θ_j = t r/‖r‖ (t = min(1, λ/‖Xᵀr/‖r‖‖∞)), hence a lower bound D_j = θ_jᵀy ≤ P*. The best bound so far certifies ANY
# primal point c with (P(c) − D)/D ≤ 1e-4: first the original (stuck) point x (so an optimal exact fit is returned
# unchanged), else the stage point.
function dual_bound(X::Matrix{T}, y::Vector{T}, λ, β) where T
  r = big.(y) - big.(X) * big.(β)
  nr = norm(r); iszero(nr) && return big(0.0)
  θ = r / nr
  g = maximum(abs, big.(X)' * θ)
  t = min(big(1), big(λ) / g)
  t * dot(θ, big.(y))
end
const TARGET = big(prevfloat(1e-4))
cert_ratio(P, D) = D > 0 ? (P - D) / D : big(Inf)

function fallback_D2(X::Matrix{T}, y::Vector{T}, λ, x, r, cfg; c0 = 0.1, q = 0.3, J = 20, cap = 20_000, scale = 0, transfer = true, cross = true) where T
  F0 = fhat(X, y, λ, x)[1]; ny = norm(Float64.(y))
  scale == 1 && (F0 = min(F0, ny))
  Px = Pbig(X, y, λ, x)
  β = copy(x); passes = 0; sec = 0.0; stages = 0; Dbest = big(0.0)
  info() = (; esc = stages, att = stages, escpasses = passes, escvisits = passes * size(X, 2), respasses = 0, escsec = sec)
  for j in 0:J-1
    δ = c0 * F0 * q^j
    β, rs, s, _ = smooth_stage(X, y, λ, β, δ; cfg, cap)
    passes += rs.passes; sec += s; stages += 1
    Dj = dual_bound(X, y, λ, β); Dbest = cross ? max(Dbest, Dj) : Dj
    if transfer && cert_ratio(Px, Dbest) <= TARGET
      return x, (; converged = true, gap = Float64(cert_ratio(Px, Dbest)), via = :transfer), info()
    end
    if cert_ratio(Pbig(X, y, λ, β), Dbest) <= TARGET
      return β, (; converged = true, gap = Float64(cert_ratio(Pbig(X, y, λ, β), Dbest)), via = :stage), info()
    end
  end
  β, rr, s, _ = ps_solve(X, y, λ, β; cfg..., maxpasses = cap)
  sec += s; passes += rr.passes
  Dbest = max(Dbest, dual_bound(X, y, λ, β))
  Pb = Pbig(X, y, λ, β)
  if transfer && cert_ratio(Px, Dbest) <= TARGET
    return x, (; converged = true, gap = Float64(cert_ratio(Px, Dbest)), via = :transfer), info()
  end
  cert_ratio(Pb, Dbest) <= TARGET && return β, (; converged = true, gap = Float64(cert_ratio(Pb, Dbest)), via = :polish), info()
  # uncertified: keep the point with the smaller rigorous objective, and report the honest gap (P(c) − D_bank)/D_bank
  keepβ = strict_decrease(fhat(X, y, λ, β), fhat(X, y, λ, x))
  c = keepβ ? β : x
  (c, (; converged = false, gap = Float64(cert_ratio(keepβ ? Pb : Px, Dbest)), via = :none), info())
end
