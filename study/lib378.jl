# Shared material of the #378 study (zero-change termination of least-squares CD).
#   - lib352.jl: the fixtures, BigFloat measures and references of the #352 audit, unchanged.
#   - probe models: wrappers of the package's LSModel and BlockLSModel that forward every call and
#     record each visit (old value, the visit's own b, curvature, computed displacement) in a ring
#     buffer as long as a full pass. The package's own loop (`_cd!`) runs them, so the passes are the
#     package's; every probed solve is also compared bit for bit with `solve!`.
#   - truth at a returned point, in BigFloat on the rounded inputs.
#   - the candidate diagnostics, computed in the working type as an implementation would.
include(joinpath(@__DIR__, "lib352.jl"))

# ------------------------------------------------------------------ designs
function equicorr(g::SM64, n, p, rho, k)
  Z, z0 = gmat(g, n, p), gvec(g, n)
  X = sqrt(1 - rho) .* Z .+ sqrt(rho) .* z0
  X, X * sparse_truth(g, p, k) + 0.5 * gvec(g, n)
end
function designs()
  out = [f for f in fixtures() if f[1] != "yzero"]
  for (n, p, k) in ((40, 12, 4), (100, 30, 6), (50, 200, 8)), rho in (0.0, 0.5, 0.95, 0.999), seed in 1:3
    g = SM64(UInt64(0x378000 + 1000n + 10p + seed) + reinterpret(UInt64, rho))
    X, y = equicorr(g, n, p, rho, k)
    push!(out, ("gen_$(n)x$(p)_r$(rho)_s$(seed)", X, y))
  end
  # larger n (the rounding of b = rᵀX_k grows with n) and column norms spread over six decades
  for (n, p, k, rho) in ((5000, 20, 5, 0.5), (2000, 50, 6, 0.95))
    g = SM64(UInt64(0x378900 + n + p))
    X, y = equicorr(g, n, p, rho, k)
    push!(out, ("gen_$(n)x$(p)_r$(rho)_s1", X, y))
  end
  let g = SM64(UInt64(0x378a00))
    X, _ = equicorr(g, 100, 30, 0.5, 6)
    Z = gmat(g, 100, 30)
    X = X .* reshape([10.0^(-3 + 6 * (j - 1) / 29) for j in 1:30], 1, 30)
    push!(out, ("gencolscale_100x30", X, Z * sparse_truth(g, 30, 6) + 0.5 * gvec(g, 100)))
  end
  out
end

# ------------------------------------------------------------------ scalar probe model
mutable struct ProbeLS{T, M<:PS.LSModel{T}} <: PS.CDModel{T}
  m::M
  ks::Vector{Int}
  olds::Vector{T}
  bs::Vector{T}
  as::Vector{T}
  hs::Vector{T}
  n::Int        # visits so far
  mism::Int     # visits whose replayed displacement differs from the one the step returned
  path::Float64 # sum over all visits of the scaled change √(s a)|h|
  ninit::Int    # residual initializations (the first one and the refreshes of the momentum loop)
  lastinit::Int # the visit count at the last initialization
end
ProbeLS(m::PS.LSModel{T}, p::Int) where T =
  ProbeLS{T, typeof(m)}(m, zeros(Int, p), zeros(T, p), zeros(T, p), zeros(T, p), zeros(T, p), 0, 0, 0.0, 0, 0)
noteinit!(w) = (w.ninit += 1; w.lastinit = w.n; w)
PS.initialize!(w::ProbeLS, x) = (PS.initialize!(w.m, x); noteinit!(w))
PS._initialize!(w::ProbeLS, x, fresh::Bool) = (PS._initialize!(w.m, x, fresh); noteinit!(w))
PS.coordinate_scale(w::ProbeLS, x, k::Int) = PS.coordinate_scale(w.m, x, k)
PS.response_scale(w::ProbeLS, x) = PS.response_scale(w.m, x)
PS.loss_value(w::ProbeLS, f, x) = PS.loss_value(w.m, f, x)
PS._cache(w::ProbeLS) = PS._cache(w.m)
PS._cache_moved!(w::ProbeLS, x) = (PS._cache_moved!(w.m, x); w)
PS._prepare!(w::ProbeLS, g, x) = (PS._prepare!(w.m, g, x); w)
function PS.coordinate_step!(w::ProbeLS{T}, g, x, k::Int) where T
  m = w.m
  a, b = PS._column_dot(m.X, m.r, k, m.a[k])      # the call the step makes, on the same state
  old = x[k]
  h = PS.coordinate_step!(m, g, x, k)
  if !iszero(a)
    hp = PS._scaled_prox(m, g, old + b / a, k, a) - old
    hp === h || (iszero(hp) && iszero(h)) || (w.mism += 1)
  end
  w.n += 1
  iszero(h) || (w.path += Float64(abs(h)) * Float64(PS._curvature_scale(m, a)))
  i = mod1(w.n, length(w.ks))
  w.ks[i], w.olds[i], w.bs[i], w.as[i], w.hs[i] = k, old, b, a, h
  h
end

# ------------------------------------------------------------------ block probe model
mutable struct ProbeBlock{T, M<:PS.BlockLSModel{T}} <: PS.CDModel{T}
  m::M
  ks::Vector{Int}
  olds::Vector{Vector{T}}
  bs::Vector{Vector{T}}
  ls::Vector{T}
  hs::Vector{T}
  n::Int
  path::Float64
  ninit::Int
  lastinit::Int
end
ProbeBlock(m::PS.BlockLSModel{T}, K::Int) where T =
  ProbeBlock{T, typeof(m)}(m, zeros(Int, K), [T[] for _ in 1:K], [T[] for _ in 1:K], zeros(T, K), zeros(T, K), 0, 0.0, 0, 0)
PS.initialize!(w::ProbeBlock, x) = (PS.initialize!(w.m, x); noteinit!(w))
PS.coordinate_scale(w::ProbeBlock, x, k::Int) = PS.coordinate_scale(w.m, x, k)
PS.response_scale(w::ProbeBlock, x) = PS.response_scale(w.m, x)
PS.loss_value(w::ProbeBlock, f, x) = PS.loss_value(w.m, f, x)
PS._prepare!(w::ProbeBlock, g, x) = (PS._prepare!(w.m, g, x); w)
function PS.coordinate_step!(w::ProbeBlock{T}, g, x, k::Int) where T
  m = w.m
  idx = PB.blockindices(x, k)
  old = T[x[j] for j in idx]
  flat = iszero(m.ℓ[k])
  h = PS.coordinate_step!(m, g, x, k)
  w.n += 1
  iszero(h) || (w.path += Float64(h) * Float64(PS._curvature_scale(m.ls, m.ℓ[k])))
  i = mod1(w.n, length(w.ks))
  w.ks[i], w.olds[i], w.ls[i], w.hs[i] = k, old, m.ℓ[k], h
  w.bs[i] = flat ? fill(T(NaN), length(idx)) : m.b[1:length(idx)]     # b is formed for every group that is not flat
  h
end

wrap(m::PS.LSModel, x) = ProbeLS(m, PB.ncoordinates(x))
wrap(m::PS.BlockLSModel, x) = ProbeBlock(m, PB.ncoordinates(x))

# The package's run (`_run_cd!`) with the probe model in place of the model. x0 is not changed.
function probe_solve(x0, f, g, method)
  work = x0 isa Vector ? SparseIterate(copy(x0)) : copy(x0)
  inner = PS.cdmodel(f, work)
  w = wrap(inner, work)
  PS.initialize!(w, work)
  method.maxpasses > 0 && PS._prepare!(w, g, work)
  st = PS._CDState(eltype(work), work, method)
  PS._cd!(work, w, g, st, method)
  minimum = PS.loss_value(inner, f, work) + g(work)
  (; work, st, w, inner, minimum)
end
# the visits of the last full pass, oldest first (valid when the run stopped at a full pass)
function last_pass(w)
  p = length(w.ks)
  w.n >= p || return Int[]
  [mod1(w.n - p + t, p) for t in 1:p]
end
samebits(a::AbstractVector, b::AbstractVector) = length(a) == length(b) && all(i -> a[i] === b[i] || (iszero(a[i]) && iszero(b[i])), eachindex(a))

# ------------------------------------------------------------------ levels in the working type
levels(g::NormL1, ::Type{T}) where T = (T(g.λ0), zero(T))
levels(g::ElasticNet, ::Type{T}) where T = (T(g.λ1), T(g.λ2))

# ------------------------------------------------------------------ the unrounded step of a scalar visit
# From the visit's own old value, b and curvature: for a nonzero coefficient that keeps its sign,
# u = (b/a − τ sign(old) − ρ old)/(1 + ρ), τ = λ1/(s a), ρ = λ2/(s a), formed without the sum old + b/a
# that absorbs it. At old = 0 the centre b/a is exact and the computed displacement h is the step; where
# the step leaves the sign of old (lands on 0 or crosses), |h| ≥ |old| and h is used.
function ustep(old::T, b::T, a::T, s::T, l1::T, l2::T, h::T) where T
  (iszero(old) || iszero(a)) && return h
  p = s * a
  u1 = (b / a - (l1 / p) * sign(old) - (l2 / p) * old) / (one(T) + l2 / p)
  (old > 0 ? old + u1 > 0 : old + u1 < 0) ? u1 : h
end
ulpsof(h::T, old::T) where T = abs(h) / eps(max(abs(old), abs(old + h)))

# Diagnostics of a scalar stop, in the working type (the run ended at a converged full pass).
# For a rule with a floor, "q" forms: over the visits whose unrounded change is at or above the
# solve's threshold in the solve's own units (the scaled change when relative scaling is active, |u|
# otherwise), the largest v/(eps(T) U_k), with v = √(s a_k)|u_k| and the unit U_k = max(√s‖y‖,
# λ1/√(s a_k)) (q) or √s‖y‖ alone (q0). A rule with the floor c refuses the stop when q ≥ c.
qof(v, unit, ::Type{T}) where T = iszero(v) ? 0.0 : Float64(v) / (Float64(eps(T)) * Float64(unit))
function scalar_stats(res, g, X::Matrix{T}, y::Vector{T}, method) where T
  inner, w, work = res.inner, res.w, res.work
  s = T(inner.s)
  l1, l2 = levels(g, T)
  x = collect(work)
  p = length(x)
  rs = sqrt(s)
  resp = PS.response_scale(inner, work)
  thr = res.st.tolerance
  scaled = method.relative && resp > 0
  unit(sc) = max(resp, l1 / sc)
  A = zero(T); A0 = zero(T); Araw = zero(T); nabs = 0; nhnz = 0; maxhulp = 0.0
  Aq = 0.0; Aq0 = 0.0; A0q = 0.0
  for i in last_pass(w)
    old, b, a, h = w.olds[i], w.bs[i], w.as[i], w.hs[i]
    iszero(a) && continue
    sc = PS._curvature_scale(inner, a)
    u = abs(ustep(old, b, a, s, l1, l2, h))
    v = u * sc
    exceeds = (scaled ? v : u) >= thr
    A0 = max(A0, v)
    exceeds && (A0q = max(A0q, qof(v, unit(sc), T)))
    if iszero(h)
      if !iszero(old)
        nabs += 1; A = max(A, v); Araw = max(Araw, u)
        exceeds && (Aq = max(Aq, qof(v, unit(sc), T)); Aq0 = max(Aq0, qof(v, resp, T)))
      end
    else
      nhnz += 1
      iszero(old) || (maxhulp = max(maxhulp, Float64(ulpsof(h, old))))
    end
  end
  # B: from the cached residual at the returned point, over the nonzero coordinates
  Babs = zero(T); Ball = zero(T); Bq = 0.0; Ballq = 0.0
  for k in 1:p
    old = x[k]
    iszero(old) && continue
    a, b = PS._column_dot(inner.X, inner.r, k, inner.a[k])
    iszero(a) && continue
    sc = PS._curvature_scale(inner, a)
    hp = PS._scaled_prox(inner, g, old + b / a, k, a) - old
    u = abs(ustep(old, b, a, s, l1, l2, hp))
    v = u * sc
    exceeds = (scaled ? v : u) >= thr
    Ball = max(Ball, v)
    exceeds && (Ballq = max(Ballq, qof(v, unit(sc), T)))
    if iszero(hp)
      Babs = max(Babs, v)
      exceeds && (Bq = max(Bq, qof(v, unit(sc), T)))
    end
  end
  # C: from a fresh residual in T, formed image first (the check of #352's probe_cd_gate.jl), its
  # unrounded-step form over all coordinates, and the working-precision KKT residual over
  # max(λ1, λmax) (the form of the stationarity check of PGD and APG, #296)
  rimg = y - X * x
  bf = X' * rimg
  grad = -s .* bf .+ l2 .* x
  C352 = zero(T); Cu = zero(T); Cuq = 0.0; G = zero(T)
  for k in 1:p
    a = sum(abs2, view(X, :, k))
    gk = iszero(x[k]) ? max(abs(grad[k]) - l1, zero(T)) : abs(grad[k] + l1 * sign(x[k]))
    G = max(G, gk)
    iszero(a) && continue
    C352 = max(C352, gk / sqrt(s * a))
    sc = PS._curvature_scale(inner, a)
    hp = PS._scaled_prox(inner, g, x[k] + bf[k] / a, k, a) - x[k]
    u = abs(ustep(x[k], bf[k], a, s, l1, l2, hp))
    v = u * sc
    Cu = max(Cu, v)
    (scaled ? v : u) >= thr && (Cuq = max(Cuq, qof(v, unit(sc), T)))
  end
  S = max(l1, s * maximum(abs, X' * y))
  K296 = iszero(S) ? T(NaN) : G / S
  # R: the cached residual against fresh ones
  rinit = copy(y)
  for k in 1:p
    iszero(x[k]) || (rinit .-= view(X, :, k) .* x[k])
  end
  Rimg = rs * norm(inner.r - rimg)
  Rinit = rs * norm(inner.r - rinit)
  R64 = T === Float32 ? Float64(rs) * norm(Float64.(inner.r) - (Float64.(y) - Float64.(X) * Float64.(x))) : NaN
  P = resolution(X, x, s)
  fresh = w.lastinit == w.n - length(w.ks)
  (; A, A0, Araw, Aq, Aq0, A0q, nabs, nhnz, maxhulp, Babs, Ball, Bq, Ballq, C352, Cu, Cuq, K296, Rimg, Rinit, R64, P,
     path = w.path, fresh, nnz = count(!iszero, x))
end
# the a priori resolution of the residual at x: eps(T) √s Σ_k ‖X_k‖|x_k|
function resolution(X::Matrix{T}, x, s) where T
  P = zero(T)
  for k in eachindex(x)
    iszero(x[k]) || (P += sqrt(sum(abs2, view(X, :, k))) * abs(x[k]))
  end
  eps(T) * sqrt(T(s)) * P
end
# What a refresh of the residual at the stop, followed by one more full pass, would see: the largest
# change of that pass and the absorbed-step statistic on it. Two refreshes: the package's
# `_initialize!` (as the momentum loop does), and the residual formed image first. Run last: it changes
# the point and the cache.
function confirm!(res, g, X::Matrix{T}, y::Vector{T}, method, statsf) where T
  w, work = res.w, res.work
  lsm = res.inner isa PS.BlockLSModel ? res.inner.ls : res.inner
  tol, scaled = PS._tolerances(w, work, method, T)
  save = copy(work)
  out = Float64[]
  for mode in (:init, :image)
    copyto!(work, save)
    PS._initialize!(w, work, false)
    mode === :image && (lsm.r .= y .- X * collect(work))
    maxh = PS._pass!(work, w, g, res.st, true, scaled)
    d = statsf(res)
    push!(out, Float64(maxh), d.Aq)
  end
  (; conf_init = out[1], confAq_init = out[2], conf_img = out[3], confAq_img = out[4])
end

# Truth of a scalar stop, in BigFloat: the measures of lib352, the largest exact first-visit change E
# (in the units of the change test, with the exact residual and exact curvatures), the distance of the
# cached residual from the exact one, and the amplification Σ‖X_k‖|x_k| / ‖y‖.
function scalar_truth(R::LassoRef, x, rcached)
  xb = bigv(x)
  r = R.y - R.X * xb
  E = zero(BigFloat); amp = zero(BigFloat)
  for k in eachindex(xb)
    a = sum(abs2, view(R.X, :, k))
    iszero(a) && continue
    amp += sqrt(a) * abs(xb[k])
    b = dot(view(R.X, :, k), r)
    c = xb[k] + b / a
    τ = R.l1 / (R.s * a)
    t = (max(c - τ, 0) + min(c + τ, 0)) / (1 + R.l2 / (R.s * a))
    E = max(E, sqrt(R.s * a) * abs(t - xb[k]))
  end
  ny = sqrt(sum(abs2, R.y))
  dres = sqrt(R.s) * sqrt(sum(abs2, bigv(rcached) - r))
  (; E, dres, amp = iszero(ny) ? big(NaN) : amp / ny)
end

# ------------------------------------------------------------------ group versions
function ugroup(old::Vector{T}, b::Vector{T}, ℓ::T, s::T, λw::T, h::T) where T
  (all(iszero, old) || iszero(ℓ) || isnan(ℓ)) && return h
  v = old .+ b ./ ℓ
  nv = norm(v)
  c = λw / (s * ℓ)
  nv > c ? norm(b ./ ℓ .- (c / nv) .* v) : norm(old)
end
function block_stats(res, g::GroupNormL2, X::Matrix{T}, y::Vector{T}, method) where T
  inner, w, work = res.inner, res.w, res.work
  ls = inner.ls
  s = T(ls.s)
  x = collect(work)
  rs = sqrt(s)
  resp = PS.response_scale(inner, work)
  thr = res.st.tolerance
  scaled = method.relative && resp > 0
  A = zero(T); A0 = zero(T); Araw = zero(T); nabs = 0; nhnz = 0
  Aq = 0.0; Aq0 = 0.0; A0q = 0.0
  for i in last_pass(w)
    k, old, b, ℓ, h = w.ks[i], w.olds[i], w.bs[i], w.ls[i], w.hs[i]
    (iszero(ℓ) || isnan(ℓ)) && continue
    sc = PS._curvature_scale(ls, ℓ)
    λw = T(g.λ0) * T(g.w[k])
    u = ugroup(old, b, ℓ, s, λw, h)
    v = u * sc
    unit = max(resp, λw / sc)
    exceeds = (scaled ? v : u) >= thr
    A0 = max(A0, v)
    exceeds && (A0q = max(A0q, qof(v, unit, T)))
    if iszero(h)
      if !all(iszero, old)
        nabs += 1; A = max(A, v); Araw = max(Araw, u)
        exceeds && (Aq = max(Aq, qof(v, unit, T)); Aq0 = max(Aq0, qof(v, resp, T)))
      end
    else
      nhnz += 1
    end
  end
  Ball = zero(T); Ballq = 0.0
  for k in 1:PB.ncoordinates(work)
    idx = PB.blockindices(work, k)
    old = T[x[j] for j in idx]
    all(iszero, old) && continue
    ℓ = inner.ℓ[k]
    (iszero(ℓ) || isnan(ℓ)) && continue
    sc = PS._curvature_scale(ls, ℓ)
    λw = T(g.λ0) * T(g.w[k])
    b = T[PS._column_dot(ls.X, ls.r, Int(j), one(T))[2] for j in idx]
    u = ugroup(old, b, ℓ, s, λw, one(T))
    v = u * sc
    Ball = max(Ball, v)
    (scaled ? v : u) >= thr && (Ballq = max(Ballq, qof(v, max(resp, λw / sc), T)))
  end
  rimg = y - X * x
  rinit = copy(y)
  for k in eachindex(x)
    iszero(x[k]) || (rinit .-= view(X, :, k) .* x[k])
  end
  Rimg = rs * norm(ls.r - rimg)
  Rinit = rs * norm(ls.r - rinit)
  R64 = T === Float32 ? Float64(rs) * norm(Float64.(ls.r) - (Float64.(y) - Float64.(X) * Float64.(x))) : NaN
  P = resolution(X, x, s)
  fresh = w.lastinit == w.n - length(w.ks)
  (; A, A0, Araw, Aq, Aq0, A0q, nabs, nhnz, maxhulp = NaN, Babs = T(NaN), Ball, Bq = NaN, Ballq, C352 = T(NaN), Cu = T(NaN), Cuq = NaN,
     K296 = T(NaN), Rimg, Rinit, R64, P, path = w.path, fresh, nnz = count(!iszero, x))
end
# E for groups: the exact displacement of the majorization step with the solver's curvature ℓ_k (a
# deferred curvature is computed here with the solver's routine), times √(s ℓ_k).
function block_truth(res, g::GroupNormL2, X::Matrix{T}, y::Vector{T}) where T
  inner, work = res.inner, res.work
  ls = inner.ls
  Xb, yb, xb, sb = bigv(X), bigv(y), bigv(collect(work)), big(ls.s)
  r = yb - Xb * xb
  E = zero(BigFloat); amp = zero(BigFloat)
  for k in 1:PB.ncoordinates(work)
    idx = collect(Int, PB.blockindices(work, k))
    for j in idx
      amp += sqrt(sum(abs2, view(Xb, :, j))) * abs(xb[j])
    end
    ℓT = inner.ℓ[k]
    iszero(ℓT) && continue
    isnan(ℓT) && (ℓT = PS._group_curvature!(inner, PB.blockindices(work, k), k))
    ℓ = big(ℓT)
    b = Xb[:, idx]' * r
    v = xb[idx] .+ b ./ ℓ
    nv = sqrt(sum(abs2, v))
    c = big(g.λ0) * big(g.w[k]) / (sb * ℓ)
    new = nv > c ? (1 - c / nv) .* v : zero(v)
    E = max(E, sqrt(sb * ℓ) * sqrt(sum(abs2, new .- xb[idx])))
  end
  ny = sqrt(sum(abs2, yb))
  dres = sqrt(sb) * sqrt(sum(abs2, bigv(ls.r) - r))
  (; E, dres, amp = iszero(ny) ? big(NaN) : amp / ny)
end

# ------------------------------------------------------------------ start directions
# Directions z (Float64, on the rounded X), each scaled so that its largest column contribution
# max_k ‖X_k‖|z_k| equals ‖y‖: the start xref + 2^j z then has an amplification of about 2^j.
function directions(X::Matrix{Float64}, y::Vector{Float64}, xref::Vector{Float64}, g::SM64)
  n, p = size(X)
  cn = [norm(view(X, :, k)) for k in 1:p]
  ny = norm(y)
  out = Pair{String, Vector{Float64}}[]
  function add(name, z)
    z = [iszero(cn[k]) ? 0.0 : z[k] for k in 1:p]
    m = maximum(cn .* abs.(z))
    m > 0 && isfinite(m) && push!(out, name => z .* (ny / m))
  end
  F = svd(X; full = true)
  σ = vcat(F.S, zeros(max(0, p - length(F.S))))
  V = F.V
  cut = 1e-12 * σ[1]
  σ[p] <= cut && add("null", V[:, p])
  i = findlast(>(cut), σ)
  i === nothing || i == 1 || add("vmin", V[:, i])
  best, bi, bj = 0.0, 0, 0
  for a in 1:p, b in a+1:p
    (iszero(cn[a]) || iszero(cn[b])) && continue
    c = dot(view(X, :, a), view(X, :, b)) / (cn[a] * cn[b])
    abs(c) > abs(best) && ((best, bi, bj) = (c, a, b))
  end
  if bi > 0
    z = zeros(p); z[bi] = 1 / cn[bi]; z[bj] = -sign(best) / cn[bj]
    add("pair", z)
  end
  k = argmax(abs.(xref) .+ 1e-300 .* (cn .> 0))
  z = zeros(p); z[k] = 1.0
  add("coord", z)
  add("dense", gvec(g, p))
  out
end
