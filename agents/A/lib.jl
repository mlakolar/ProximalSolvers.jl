# Research prototypes for #156 certification (Agent A). Not production code.
include("<RUN>/scripts/common.jl")
using LinearAlgebra
const up = PS._up
const dn = PS._dn
const TARGET = prevfloat(1e-4)

# ---------------------------------------------------------------------------------------------------
# Float64 validator with outward rounding for an ARBITRARY candidate θ̂ and an ARBITRARY point β
# (generalises `_certify!`: there θ̂ = r̂ and the norm of θ̂ is N). All inputs are exact Float64 values
# (Float32 data are exact in Float64). Returns (; ok, ratio, Dlo, gap, t, why).
# Proof sketch: see report §1.4. With t = min(1, 1/‖θ̂‖, λ/‖Xᵀθ̂‖∞) (each denominator bounded above),
# tθ̂ is dual feasible, P* ≥ tθ̂ᵀy, and  P(β) − tθ̂ᵀy = (‖r‖ − tθ̂ᵀr) + Σ_k (λ|β_k| − tβ_k X_kᵀθ̂).
function vcert(X::Matrix{Float64}, y::Vector{Float64}, lo::Float64, hi::Float64, β::Vector{Float64}, θ::Vector{Float64})
  n, p = size(X)
  ε = eps(Float64); η = nextfloat(0.0); nη = n*η; ψ = (n + 1)*ε
  fail(why) = (; ok = false, ratio = NaN, Dlo = NaN, gap = NaN, t = NaN, why)
  res = copy(y); mag = abs.(y); nb = 0; sb = 0.0
  for k in 1:p
    v = β[k]; iszero(v) && continue
    nb += 1; sb += abs(v)
    @inbounds for i in 1:n
      t = X[i, k]*v; res[i] -= t; mag[i] += abs(t)
    end
  end
  sr = 0.0; smu = 0.0; sθ = 0.0; w = 0.0; Aw = 0.0; wy = 0.0; Ay = 0.0
  @inbounds for i in 1:n
    sr += res[i]*res[i]; smu += mag[i]*mag[i]; sθ += θ[i]*θ[i]
    w += θ[i]*res[i]; Aw += abs(θ[i]*res[i]); wy += θ[i]*y[i]; Ay += abs(θ[i]*y[i])
  end
  (isfinite(sr) & isfinite(smu) & isfinite(sθ) & isfinite(w) & isfinite(wy) & isfinite(sb)) || return fail(:nonfinite)
  Nup = up(sqrt(up(up(sr*(1 + ψ)) + nη)))
  Nlo = sr >= ldexp(Float64(n), -969) ? dn(sqrt(dn(sr*(1 - ψ)))) : 0.0
  Mup = up(sqrt(up(up(smu*(1 + ψ)) + nη)))
  Eup = up(up(((nb + 1)*ε)*Mup) + up(up(Float64(nb)*Float64(n))*η))
  Θup = up(sqrt(up(up(sθ*(1 + ψ)) + nη)))
  bmax = 0.0; amax = 0.0; q = 0.0
  for k in 1:p
    bk = 0.0; ak = 0.0
    @inbounds @simd for i in 1:n
      v = X[i, k]; bk += v*θ[i]; ak += v*v
    end
    (isfinite(bk) & isfinite(ak)) || return fail(:nonfinite)
    bmax = max(bmax, abs(bk)); amax = max(amax, ak)
    iszero(β[k]) || (q += β[k]*bk)
  end
  isfinite(q) || return fail(:nonfinite)
  Rup = up(sqrt(up(up(amax*(1 + ψ)) + nη)))
  Eb = up(up((n*ε)*up(Rup*Θup)) + nη)        # |b_k − b̂_k| ≤ Eb, b_k = X_kᵀθ̂
  G = up(bmax + Eb)
  isfinite(G) || return fail(:nonfinite)
  t = max(0.0, min(dn(1/Θup), dn(lo/G)))      # no cap at 1: tθ̂ is feasible for every t ≥ 0 with tΘup ≤ 1, tG ≤ λ
  wlo = dn(dn(w - up(up((n*ε)*up(Aw*(1 + ψ))) + nη)) - up(Θup*Eup))     # ≤ θ̂ᵀr
  B1 = up(up(Nup + Eup) - dn(t*wlo))                                      # ≥ ‖r‖ − tθ̂ᵀr
  Σup = up(sb*(1 + nb*ε)); Σlo = dn(sb*(1 - nb*ε))
  S1 = up(hi*Σup)
  E2 = up(up(up(up((nb*ε)*bmax) + Eb)*Σup) + nb*η)
  S2 = dn(dn(t*q) - up(t*E2))                                              # ≤ t Σ β_k b_k
  gap = up(B1 + up(S1 - S2))                                               # ≥ P(β) − tθ̂ᵀy
  Plo = dn(max(0.0, dn(Nlo - Eup)) + dn(lo*Σlo))
  D1 = dn(Plo - gap)
  wylo = dn(wy - up(up((n*ε)*up(Ay*(1 + ψ))) + nη))
  D2 = dn(t*wylo)
  Dlo = max(D1, D2)
  isfinite(gap) || return fail(:nonfinite)
  Dlo > 0 || return (; ok = false, ratio = NaN, Dlo, gap, t, why = :Dlo_nonpositive)
  Pup = up(up(Nup + Eup) + S1)
  ratio = max(0.0, min(up(gap/Dlo), up(up(Pup - Dlo)/Dlo)))
  (; ok = ratio <= TARGET, ratio, Dlo, gap, t, why = ratio <= TARGET ? :ok : :ratio)
end

# Exact (BigFloat, 256 bits) validation: scale θ̂ into feasibility, value, gap ratio vs the point β.
function bigcert(X, y, λ, β, θ)
  Xb = big.(X); yb = big.(y); θb = big.(θ); βb = big.(β); λb = big(λ)
  nθ = norm(θb); mc = maximum(abs, Xb'*θb)
  t = max(big(0), min(nθ > 0 ? 1/nθ : big(1e300), mc > 0 ? λb/mc : big(1e300)))
  D = t*dot(θb, yb)
  P = norm(yb - Xb*βb) + λb*sum(abs, βb)
  (; t = Float64(t), D = Float64(D), P = Float64(P), ratio = D > 0 ? Float64((P - D)/D) : Inf, Dbig = D, Pbig = P)
end

# effective support: drop the smallest entries while their total |·| mass ≤ εdrop ‖β‖₁
function effsupport(β::Vector{Float64}, εdrop)
  idx = findall(!iszero, β)
  isempty(idx) && return Int[]
  o = sort(idx; by = k -> abs(β[k]))
  tot = sum(abs, β[idx]); cum = 0.0; drop = 0
  for k in o[1:end-1]
    cum += abs(β[k]); cum <= εdrop*tot ? (drop += 1) : break
  end
  sort(o[drop+1:end])
end

# ---------------------------------------------------------------------------------------------------
# A. least-norm solution of the support equations X_Sᵀθ = λ s via a thin SVD of X_S.
function cand_A(X, y, λ, β; εdrop = 1e-6, rtol = 1e-10)
  S = effsupport(β, εdrop); isempty(S) && return (; θ = nothing, info = (; why = :empty))
  s = sign.(β[S]); XS = X[:, S]
  F = svd(XS); k = count(>(rtol*F.S[1]), F.S)
  θ = F.U[:, 1:k]*((F.V[:, 1:k]'*(λ .* s)) ./ F.S[1:k])
  inc = norm(XS'*θ - λ .* s)/(λ*sqrt(length(S)))         # relative support-equation inconsistency
  (; θ, info = (; ns = length(S), rank = k, nθ = norm(θ), inc, cond = F.S[1]/F.S[end]), S, s, F, k)
end

# ridge-regularised support solve (no rank decision): θ = X_S (X_SᵀX_S + μ I)⁻¹ λ s
function cand_ridge(X, y, λ, β; εdrop = 1e-6, μrel = 1e-10)
  S = effsupport(β, εdrop); isempty(S) && return (; θ = nothing, info = (; why = :empty))
  s = sign.(β[S]); XS = X[:, S]; Gm = Symmetric(XS'*XS)
  μ = μrel*tr(Gm)/length(S)
  w = cholesky(Gm + μ*I) \ (λ .* s)
  (; θ = XS*w, info = (; ns = length(S), nθ = norm(XS*w)))
end

# B. correction inside the affine family θ = θ0 + ν, ν ⊥ range(X_S), ‖θ0‖² + ‖ν‖² ≤ 1, |X_kᵀθ| ≤ λ off support.
# Active-set POCS (cutting-plane + alternating projection onto violated slabs and the ball).
function cand_B(X, y, λ, β; εdrop = 1e-6, rtol = 1e-10, margin = 1e-3, maxsweeps = 500, align = false)
  a = cand_A(X, y, λ, β; εdrop, rtol)
  a.θ === nothing && return a
  n, p = size(X); S, U, k = a.S, a.F.U[:, 1:a.k], a.k
  θ0 = a.θ; n0 = norm(θ0)
  isS = falses(p); isS[S] .= true
  info = (; a.info..., sweeps = 0, nviol = 0, status = :none)
  k == n && return (; θ = θ0, info = (; info..., status = :nullspace_empty))     # support equations determine θ
  ρ2 = (1 - margin)^2 - n0^2
  ρ2 <= 0 && return (; θ = θ0, info = (; info..., status = :ball))
  ρ = sqrt(ρ2); λm = λ*(1 - margin)
  ν = zeros(n)
  if align          # start from the point of the affine family nearest to the residual direction r̂/‖r̂‖
    rr = y - X*β; nr = norm(rr)
    if nr > 0
      u = rr/nr; ν = u - U*(U'*u); nν = norm(ν); nν > ρ && (ν .*= ρ/nν)
    end
  end
  V = Int[]; Wc = Dict{Int, Vector{Float64}}(); wn = Dict{Int, Float64}(); c0 = X'*θ0
  sweeps = 0; status = :maxsweeps
  while sweeps < maxsweeps
    sweeps += 1
    cur = c0 .+ X'*ν                       # O(np) cut generation
    maxv = 0.0; added = false
    for j in 1:p
      isS[j] && continue
      v = abs(cur[j]) - λm
      if v > 1e-12*λ
        maxv = max(maxv, v)
        if !haskey(Wc, j)
          xj = X[:, j]; w = xj - U*(U'*xj); Wc[j] = w; wn[j] = dot(w, w) <= 1e-12*dot(xj, xj) ? 0.0 : dot(w, w); push!(V, j); added = true
        end
      end
    end
    if maxv <= 1e-9*λ ; status = :ok; break; end
    for _ in 1:20, j in V
      w = Wc[j]; wn[j] == 0.0 && continue
      val = c0[j] + dot(X[:, j], ν)         # = c0[j] + wⱼᵀν since ν ⊥ range(X_S) (w = P_N x_j)
      if abs(val) > λm
        ν .-= ((val - sign(val)*λm)/wn[j]) .* w
      end
      nν = norm(ν); nν > ρ && (ν .*= ρ/nν)
    end
  end
  (; θ = θ0 + ν, info = (; info..., sweeps, nviol = length(V), status))
end

# D. minimum-norm certificate via the directional lasso  min_d ½‖Xd‖² + λ sᵀd_S + λ‖d_{S^c}‖₁, θ = −Xd,
# plain cyclic coordinate descent on d (no factorisation). `check(θ̂)` is called every `every` passes;
# it returns a vcert result; stops when certified, when a descent direction is found (refuted:
# F'(β;d) = ‖Xd‖ + σ_C(d) < 0, hence ‖θ*‖ > 1), or at maxpass.
function cand_D(X, y, λ, β, check; εdrop = 1e-6, maxpass = 3000, every = 5)
  n, p = size(X); S = effsupport(β, εdrop)
  isempty(S) && return (; θ = nothing, info = (; why = :empty))
  isS = falses(p); isS[S] .= true
  sg = zeros(p); sg[S] .= sign.(β[S])
  a = vec(sum(abs2, X; dims = 1)); d = zeros(p); u = zeros(n)
  best = nothing; status = :maxpass; pass = 0
  while pass < maxpass
    pass += 1
    for k in 1:p
      a[k] == 0 && continue
      xk = view(X, :, k)
      ck = dot(xk, u) - a[k]*d[k]
      z = isS[k] ? -(ck + λ*sg[k])/a[k] : (v = -ck/a[k]; τ = λ/a[k]; v > τ ? v - τ : v < -τ ? v + τ : 0.0)
      h = z - d[k]
      if h != 0
        @inbounds @simd for i in 1:n
          u[i] += h*xk[i]
        end
        d[k] = z
      end
    end
    nu = norm(u)
    σ = λ*sum((sg[k]*d[k] for k in S); init = 0.0) + λ*sum((abs(d[k]) for k in 1:p if !isS[k]); init = 0.0)
    if nu + σ < -1e-9*λ*max(1, sum(abs, d))                           # F'(β;d) = ‖Xd‖ + σ_C(d) < 0: descent direction, ‖θ*‖>1
      status = :refuted; break
    end
    if pass % every == 0
      θ = -u; r = check(θ)
      best = (; θ = copy(θ), r)
      if r.ok; status = :certified; break; end
    end
  end
  θ = -u
  (; θ, info = (; passes = pass, status, nθ = norm(u), ns = length(S)))
end

# B with a ladder of support-drop budgets: the dropped mass costs at most 2λ·(dropped mass) in the gap,
# so budgets up to ~3e-5 of ‖β‖₁ are affordable against the 1e-4 target. First certified candidate wins.
function cand_Bm(X, y, λ, β, check; ladder = (1e-6, 1e-5, 3e-5))
  last = nothing
  for e in ladder
    c = cand_B(X, y, λ, β; εdrop = e)
    c.θ === nothing && continue
    r = check(c.θ); last = (; c..., r, εdrop = e)
    r.ok && return last
  end
  last === nothing ? (; θ = nothing, info = (; why = :empty)) : last
end

# Bc: B without a rank-revealing factorisation: Cholesky of the |S|×|S| Gram matrix with a tiny ridge μ.
# P_N v ≈ v − X_S (G+μI)⁻¹ X_Sᵀ v. Same active-set POCS. The validator judges the result.
function cand_Bc(X, y, λ, β; εdrop = 1e-6, μrel = 1e-12, margin = 1e-3, maxsweeps = 500)
  n, p = size(X); S = effsupport(β, εdrop); isempty(S) && return (; θ = nothing, info = (; why = :empty))
  s = sign.(β[S]); XS = X[:, S]; Gm = Symmetric(XS'*XS); μ = μrel*tr(Gm)/length(S)
  F = try cholesky(Gm + μ*I) catch; return (; θ = nothing, info = (; why = :chol)) end
  proj(v) = v - XS*(F \ (XS'*v))
  θ0 = XS*(F \ (λ .* s)); n0 = norm(θ0)
  isS = falses(p); isS[S] .= true
  info = (; ns = length(S), nθ = n0, sweeps = 0, nviol = 0, status = :none)
  ρ2 = (1 - margin)^2 - n0^2
  (length(S) >= n || ρ2 <= 0) && return (; θ = θ0, info)
  ρ = sqrt(ρ2); λm = λ*(1 - margin); ν = zeros(n)
  V = Int[]; Wc = Dict{Int, Vector{Float64}}(); wn = Dict{Int, Float64}(); c0 = X'*θ0
  sweeps = 0; status = :maxsweeps
  while sweeps < maxsweeps
    sweeps += 1
    cur = c0 .+ X'*ν; maxv = 0.0
    for j in 1:p
      isS[j] && continue
      v = abs(cur[j]) - λm
      if v > 1e-12*λ
        maxv = max(maxv, v)
        if !haskey(Wc, j); xj = X[:, j]; w = proj(xj); Wc[j] = w; wn[j] = dot(w, w) <= 1e-12*dot(xj, xj) ? 0.0 : dot(w, w); push!(V, j); end
      end
    end
    if maxv <= 1e-9*λ; status = :ok; break; end
    for _ in 1:20, j in V
      w = Wc[j]; wn[j] == 0.0 && continue
      val = c0[j] + dot(X[:, j], ν)
      if abs(val) > λm; ν .-= ((val - sign(val)*λm)/wn[j]) .* w; end
      nν = norm(ν); nν > ρ && (ν .*= ρ/nν)
    end
  end
  (; θ = θ0 + ν, info = (; info..., sweeps, nviol = length(V), status))
end
function cand_Bcm(X, y, λ, β, check; ladder = (1e-6, 1e-5, 3e-5))
  last = nothing
  for e in ladder
    c = cand_Bc(X, y, λ, β; εdrop = e); c.θ === nothing && continue
    r = check(c.θ); last = (; c..., r, εdrop = e); r.ok && return last
  end
  last === nothing ? (; θ = nothing, info = (; why = :empty)) : last
end
