# #487 round 2: candidate stopping diagnostics for PGD/APG with free (zero-weight) coordinates.
# Research only. The solver's iterates are untouched: the probe replaces only the stationarity gate
# `_stationary!` of the dedicated penalties (NormL1, ElasticNet, GroupNormL2) and dispatches on RULE[]:
#   :cur  the merged rule (verbatim copy of src/utils.jl at the probed SHA)
#   :A    the merged rule with λmax replaced by the profiled λ̂ = ‖[∇f(x̂_F) + λ2 x̂_F]‖ (round-1 prototype)
#   :B    per-entry angle / coordinate-decrease rule: score_i < τ s_i(x),
#         s_i = sqrt(α‖X_i‖² + λ2) · sqrt(α‖Xx − y‖² + λ2‖x‖²)      (least squares, ElasticNet)
#         s_k = sqrt(α‖X_Gk‖_F² + λ2) · sqrt(α‖Xx − y‖² + λ2‖x‖²)   (groups)
#         s_i = ‖X_i‖ · ‖σ(Xx) − y‖                               (logistic)
#   :Bh   tighten-only hybrid: score_i < τ min(max(c_i, λmax), s_i)
#   :C    absolute + relative: score_i < a_i + τ s_i, a_i the first-order rounding floor (below)
#   :E    relative duality gap (least squares only): P(x) − D(θ) ≤ ftol · P(x), θ made dual feasible
#         (free coordinates: projection for λ2 = 0, ridge block for λ2 > 0; then scaled)
# D (backward error) is reported as a classification: the point is precision-limited when τ s_i < a_i for some i.
# Independent references in BigFloat (256 bits): feature-sign active-set method (L1/EN), Newton on active
# groups (groups), Newton on the active set (logistic), each verified by its exact KKT residual.
using ProximalSolvers, ProximalBase, LinearAlgebra, Random, Printf
const PS = ProximalSolvers
setprecision(BigFloat, 256)

const RULE = Ref(:cur)
const CTX = Ref{Any}(nothing)
const NCHK = Ref(0)
const DEDICATED = Union{NormL1, NormL1Nonneg, IndNonnegative, ElasticNet, GroupNormL2, NormL2}

# ---------------- the merged rule, verbatim, with an optional λmax override ----------------
function cur_rule(state, f, g, options, lam_override)
  T = eltype(state.x)
  λmax = lam_override === nothing ? PS._lambda_max!(state, PS._scale_norm(g)) : (state.λmax = T(lam_override))
  grad = PS._gradient_at_x!(state, f)
  gT = PS._converted_penalty(g, T)
  λ = PS._l1_level(gT)
  residual = kkt_violation(gT, grad, state.x)
  S = max(λ, λmax)
  τ = T(max(options.gradtol, 64 * Float64(eps(T))))
  threshold = τ * S
  isfinite(S) && threshold >= floatmin(T) && isfinite(residual) && residual < threshold &&
    (λ <= λmax || PS._entry_thresholds_hold(gT, grad, state.x, τ, λmax))
end

function PS._stationary!(state, f, g::DEDICATED, options::ProximalOptions)
  NCHK[] += 1
  r = RULE[]
  r === :cur && return cur_rule(state, f, g, options, nothing)
  r === :A && return cur_rule(state, f, g, options, CTX[].lhat)
  T = eltype(state.x)
  PS._lambda_max!(state, PS._scale_norm(g))   # first, as in the merged rule: it writes xhat, which APG's gradient uses
  grad = PS._gradient_at_x!(state, f)
  d = diagnose(CTX[], state.x, grad, T(max(options.gradtol, 64 * Float64(eps(T)))), state.λmax, T(options.ftol))
  r === :B ? d.passB : r === :Bh ? d.passBh : r === :C ? d.passC : r === :E ? d.passE : error("rule $r")
end

# ---------------- per-solve context (all in T) ----------------
struct Ctx{T}
  loss::Symbol
  X::Matrix{T}; y::Vector{T}; α::T
  c::Vector{T}            # per entry (L1/EN) or per group coefficient, rounded in T as the solver rounds it
  λ2::T
  groups::Union{Nothing, Vector{Vector{Int}}}
  colsq::Vector{T}        # ‖X_i‖² or ‖X_G‖_F²
  F::Vector{Int}          # free entries (entries of free groups)
  QF::Any                 # pivoted QR of X_F (λ2 = 0, F ≠ ∅), for :E
  z::Vector{T}; dv::Vector{T}; gt::Vector{T}
  lhat::Union{Nothing, T} # profiled λ̂ for :A (nothing when F = ∅)
end

sigm(t) = 1 / (1 + exp(-t))

# scores (signed at zero entries / zero groups), in T, from the solver gradient
function scores_T(C::Ctx{T}, x, grad) where T
  if C.groups === nothing
    [iszero(x[i]) ? abs(grad[i]) - C.c[i] : abs(grad[i] + C.λ2 * x[i] + C.c[i] * sign(x[i])) for i in eachindex(x)]
  else
    map(enumerate(C.groups)) do (k, G)
      nx = norm(view(x, G))
      iszero(nx) ? norm(view(grad, G)) - C.c[k] : norm(view(grad, G) .+ C.c[k] .* view(x, G) ./ nx)
    end
  end
end

function diagnose(C::Ctx{T}, x, grad, τ::T, λmax::T, ftol::T) where T
  u = eps(T) / 2
  X, y = C.X, C.y
  mul!(C.z, X, x)
  sc = scores_T(C, x, grad)
  m = length(sc)
  if C.loss === :ls
    C.dv .= C.z .- y
    Φ2 = C.α * sum(abs2, C.dv) + C.λ2 * sum(abs2, x)        # 2 × (smooth part of F)
    ζ = sqrt(sum(i -> (abs(C.z[i]) + abs(y[i]))^2, eachindex(y)))
    s = [sqrt(C.α * C.colsq[k] + C.λ2) * sqrt(Φ2) for k in 1:m]
    gk = C.groups === nothing ? abs.(grad) : [norm(view(grad, G)) for G in C.groups]
    xk = C.groups === nothing ? abs.(x) : [norm(view(x, G)) for G in C.groups]
    a = [C.α * sqrt(C.colsq[k]) * u * ζ + u * (gk[k] + C.c[k] + C.λ2 * xk[k]) for k in 1:m]
  else
    C.dv .= sigm.(C.z) .- y
    nd = norm(C.dv)
    ζ = sqrt(sum(i -> (sigm(C.z[i]) * (1 - sigm(C.z[i])) * abs(C.z[i]) + sigm(C.z[i]))^2, eachindex(y)))
    s = [sqrt(C.colsq[k]) * nd for k in 1:m]
    gk = abs.(grad)
    a = [sqrt(C.colsq[k]) * u * ζ + u * (gk[k] + C.c[k]) for k in 1:m]
  end
  guard(t) = isfinite(t) && t >= floatmin(T)
  thrB = τ .* s
  thrBh = [τ * min(max(C.c[k], λmax), s[k]) for k in 1:m]
  thrC = a .+ τ .* s
  allfin = all(isfinite, sc)
  passB = allfin && all(k -> guard(thrB[k]) && sc[k] < thrB[k], 1:m)
  passBh = allfin && λmax >= 0 && all(k -> guard(thrBh[k]) && sc[k] < thrBh[k], 1:m)
  passC = allfin && all(k -> guard(thrC[k]) && sc[k] < thrC[k], 1:m)
  ratioB = maximum(k -> sc[k] / thrB[k], 1:m)
  ratioBh = maximum(k -> sc[k] / thrBh[k], 1:m)
  ratioC = maximum(k -> sc[k] / thrC[k], 1:m)
  plimited = any(k -> thrB[k] < a[k], 1:m)
  # duality gap (least squares only)
  passE, gapratio, plE = false, T(NaN), false
  if C.loss === :ls
    q = C.dv                                   # z − y, so ∇f = α Xᵀ q
    P = C.α * sum(abs2, q) / 2 + C.λ2 * sum(abs2, x) / 2 +
        (C.groups === nothing ? sum(C.c .* abs.(x)) : sum(C.c[k] * norm(view(x, G)) for (k, G) in enumerate(C.groups)))
    gt = C.gt
    νsq = C.λ2 * sum(abs2, x)                  # ‖ν‖² with ν = −√λ2 x
    qp = q
    if isempty(C.F)
      gt .= grad .+ C.λ2 .* x
    elseif iszero(C.λ2)
      w = C.QF \ q[:]                          # project q onto null(X_Fᵀ)
      qp = q .- X[:, C.F] * w
      mul!(gt, transpose(X), qp); gt .*= C.α   # one extra product Xᵀ q′ (a Gram X_PᵀX_F would make it O(p|F|))
      gt[C.F] .= 0
    else
      gt .= grad .+ C.λ2 .* x
      for i in C.F                             # ν_i += g̃_i/√λ2 makes X̃_iᵀθ̃ = 0
        νi = -sqrt(C.λ2) * x[i] + gt[i] / sqrt(C.λ2)
        νsq += νi^2 - C.λ2 * x[i]^2
        gt[i] = 0
      end
    end
    κ = one(T)
    if C.groups === nothing
      for i in eachindex(gt)
        C.c[i] > 0 && abs(gt[i]) > C.c[i] && (κ = min(κ, C.c[i] / abs(gt[i])))
      end
    else
      for (k, G) in enumerate(C.groups)
        ng = norm(view(gt, G)); C.c[k] > 0 && ng > C.c[k] && (κ = min(κ, C.c[k] / ng))
      end
    end
    # θ = −√α q′ ; D = κ⟨θ, √α y⟩ − κ²(‖θ‖² + ‖ν‖²)/2
    qy = dot(qp, y)
    D = -κ * C.α * qy - κ^2 * (C.α * sum(abs2, qp) + νsq) / 2
    gap = P - D
    gfloor = u * (C.α * sum(i -> abs(qp[i]) * abs(y[i]), eachindex(y)) + C.α * sum(abs2, qp) + 2P)
    gapratio = gap / (ftol * P)
    plE = ftol * P < gfloor
    passE = isfinite(gap) && P > 0 && !plE && gap <= ftol * P   # a gap below its rounding floor is not resolved
  end
  (; passB, passBh, passC, passE, ratioB, ratioBh, ratioC, gapratio, plimited, plE,
     sB = maximum(s), aB = maximum(a))
end

# ---------------- BigFloat problem, objective, KKT ----------------
struct BP
  loss::Symbol
  X::Matrix{BigFloat}; y::Vector{BigFloat}; α::BigFloat
  c::Vector{BigFloat}; λ2::BigFloat
  blocks::Vector{Vector{Int}}     # singleton blocks for L1/EN
end
smooth(P, b) = P.loss === :ls ? P.α * sum(abs2, P.X * b - P.y) / 2 :
  sum(t -> t > 0 ? t + log1p(exp(-t)) : log1p(exp(t)), P.X * b) - dot(P.y, P.X * b)
gradb(P, b) = P.loss === :ls ? P.α * (P.X' * (P.X * b - P.y)) .+ P.λ2 .* b : P.X' * (sigm.(P.X * b) .- P.y)
pen(P, b) = sum(P.c[k] * norm(b[G]) for (k, G) in enumerate(P.blocks)) + P.λ2 * sum(abs2, b) / 2
obj(P, b) = smooth(P, b) + pen(P, b)
function kkt_b(P, b)   # exact block scores (clipped at zero)
  g = gradb(P, b)
  map(enumerate(P.blocks)) do (k, G)
    nb = norm(b[G])
    iszero(nb) ? max(norm(g[G]) - P.c[k], big(0)) : norm(g[G] .+ P.c[k] .* b[G] ./ nb)
  end
end

# feature-sign search (Lee et al. 2007) for ½α‖Xb − y‖² + λ2‖b‖²/2 + Σ c_i|b_i| with free entries (c_i = 0)
function featuresign(P::BP; start = nothing)
  p = size(P.X, 2)
  H = P.α .* (P.X' * P.X) + P.λ2 * I
  bvec = P.α .* (P.X' * P.y)
  c = [P.c[k] for k in 1:p]
  act = falses(p); s = zeros(Int, p)
  for i in 1:p; iszero(c[i]) && (act[i] = true); end
  x = zeros(BigFloat, p)
  if start !== nothing
    for i in 1:p
      if !iszero(c[i]) && start[i] != 0
        act[i] = true; s[i] = Int(sign(start[i]))
      end
    end
  end
  F(xv) = dot(xv, H * xv) / 2 - dot(bvec, xv) + sum(c .* abs.(xv))
  for outer in 1:2000
    # inner: optimise on the active set with fixed signs, feature-sign line search
    for inner in 1:500
      A = findall(act)
      xn = zeros(BigFloat, p)
      isempty(A) || (xn[A] = H[A, A] \ (bvec[A] .- c[A] .* s[A]))
      bad = [i for i in A if !iszero(c[i]) && sign(xn[i]) != s[i]]
      if isempty(bad)
        x = xn; break
      end
      # candidate points: where a penalized coordinate crosses zero on [x, xn]
      ts = BigFloat[]
      for i in A
        iszero(c[i]) && continue
        if sign(xn[i]) != sign(x[i]) && !iszero(x[i])
          push!(ts, x[i] / (x[i] - xn[i]))
        end
      end
      cand = [x .+ t .* (xn .- x) for t in ts]
      push!(cand, xn)
      vals = [F(v) for v in cand]
      x = cand[argmin(vals)]
      for i in A
        if !iszero(c[i]) && abs(x[i]) < big(1e-70)
          x[i] = 0; act[i] = false; s[i] = 0
        end
      end
      for i in findall(act)
        !iszero(c[i]) && (s[i] = Int(sign(x[i])))
      end
    end
    g = H * x .- bvec
    viol = [(!act[i] && !iszero(c[i])) ? abs(g[i]) - c[i] : big(-1) for i in 1:p]
    j = argmax(viol)
    if viol[j] <= 0
      return x
    end
    act[j] = true; s[j] = -Int(sign(g[j]))
  end
  error("feature-sign did not converge")
end

# Newton on the active groups for multi-column groups (group lasso), from a Float64 start
function group_newton(P::BP, start::Vector{Float64})
  p = size(P.X, 2)
  H0 = P.α .* (P.X' * P.X) + P.λ2 * I
  bvec = P.α .* (P.X' * P.y)
  act = [iszero(P.c[k]) || norm(start[G]) > 0 for (k, G) in enumerate(P.blocks)]
  x = big.(start)
  for outer in 1:50
    A = reduce(vcat, [P.blocks[k] for k in eachindex(P.blocks) if act[k]]; init = Int[])
    for k in eachindex(P.blocks); act[k] || (x[P.blocks[k]] .= 0); end
    for it in 1:200
      R = H0[A, :] * x .- bvec[A]
      J = copy(H0[A, A])
      pos = Dict(j => t for (t, j) in enumerate(A))
      for (k, G) in enumerate(P.blocks)
        (act[k] && !iszero(P.c[k])) || continue
        nb = norm(x[G]); u = x[G] ./ nb
        idx = [pos[j] for j in G]
        R[idx] .+= P.c[k] .* u
        J[idx, idx] .+= P.c[k] / nb .* (I - u * u')
      end
      maximum(abs, R) < big(1e-70) && break
      x[A] .-= J \ R
    end
    g = H0 * x .- bvec
    changed = false
    for (k, G) in enumerate(P.blocks)
      if !act[k] && norm(g[G]) > P.c[k]; act[k] = true; x[G] .= -g[G] .* big(1e-3); changed = true; end
    end
    changed || return x
  end
  error("group Newton did not converge")
end

# Newton on the active set for logistic (signs fixed), from a Float64 ProxNewton start
function logistic_newton(P::BP, start::Vector{Float64})
  p = size(P.X, 2)
  A = [i for i in 1:p if iszero(P.c[i]) || start[i] != 0]
  s = [iszero(P.c[i]) ? 0 : Int(sign(start[i])) for i in 1:p]
  x = big.(start)
  for it in 1:200
    η = P.X * x; σ = sigm.(η)
    g = P.X' * (σ .- P.y)
    R = g[A] .+ P.c[A] .* s[A]
    maximum(abs, R) < big(1e-70) && break
    W = σ .* (1 .- σ)
    H = P.X[:, A]' * (P.X[:, A] .* W)
    x[A] .-= H \ R
  end
  x
end

# Float64 accelerated proximal gradient with restart, a start for the BigFloat refinement
function fista64(X, y, α, c, λ2, blocks; iters = 200_000)
  p = size(X, 2)
  L = α * opnorm(X)^2 + λ2
  x = zeros(p); z = copy(x); t = 1.0
  prox(v) = begin
    o = similar(v)
    for (k, G) in enumerate(blocks)
      nv = norm(v[G]); sh = c[k] / L
      o[G] .= nv > sh ? (1 - sh / nv) .* v[G] : 0.0
    end
    o
  end
  for k in 1:iters
    g = α .* (X' * (X * z .- y)) .+ λ2 .* z
    xn = prox(z .- g ./ L)
    tn = (1 + sqrt(1 + 4t^2)) / 2
    if dot(z .- xn, xn .- x) > 0       # restart
      tn = 1.0; z = copy(xn)
    else
      z = xn .+ ((t - 1) / tn) .* (xn .- x)
    end
    norm(xn .- x, Inf) <= 1e-15 * max(norm(xn, Inf), 1) && (x = xn; break)
    x = xn; t = tn
  end
  x
end

function reference(P::BP; x64 = nothing, dedup = nothing)
  if P.loss === :logistic
    x = logistic_newton(P, x64)
  elseif all(length(G) == 1 for G in P.blocks)
    x = featuresign(P; start = x64)
  else
    x = group_newton(P, x64)
  end
  x
end

# ---------------- one fixture ----------------
const HDR = join(["fixture", "family", "loss", "pen", "T", "method", "rule", "converged", "reason", "iter", "nchk",
  "grad_calls", "prox_calls", "absexcess", "relexcess", "progexcess", "kkt_angle", "kkt_prof", "coef_relerr",
  "rule_ratio", "ratioB", "gapratio", "plimitedB", "plimitedE", "lmax", "lhat", "Fstar", "class"], '\t')

reason(r, maxiter) = r.converged ? "converged" : r.stagnated ? "stagnated" : r.f_increased ? "f_increased" :
  r.iterations >= maxiter ? "maxiter" : "other"

const TOL_ACC = 1e-6

function run_fixture!(rows, name, family; loss = :ls, X, y, λ0, w, λ2 = 0.0, pen = :l1, groups = nothing, α = 1.0,
                      Ts = (Float64, Float32), methods = (ProximalGradientDescent(), AccProxGradDescent()),
                      dedup = nothing, rules = (:cur, :A, :B, :Bh, :C, :E))
  for T in Ts
    XT = T.(X); yT = T.(y); wT = T.(w)
    gsets = groups === nothing ? nothing : [collect(G) for G in groups]
    cT = T(λ0) .* wT                                   # the solver's rounded coefficients
    if pen === :l1
      g = groups === nothing ? NormL1(T(λ0), wT) : GroupNormL2(T(λ0), groups, wT)
    else
      g = ElasticNet(T(λ0), T(λ2), wT)
    end
    f = loss === :logistic ? LogisticLoss(yT, XT) : (α == 1.0 ? LeastSquaresLoss(yT, XT) : Scaled(LeastSquaresLoss(yT, XT), α))
    αT = T(α)
    F = groups === nothing ? findall(iszero, w) : reduce(vcat, [collect(groups[k]) for k in eachindex(groups) if iszero(w[k])]; init = Int[])
    colsq = groups === nothing ? vec(sum(abs2, XT; dims = 1)) : [sum(abs2, XT[:, G]) for G in groups]
    QF = (!isempty(F) && iszero(λ2) && loss === :ls) ? qr(XT[:, F], ColumnNorm()) : nothing
    # A: profiled λ̂ in T (round-1 prototype)
    lhat = nothing
    if !isempty(F) && length(F) < size(X, 2)
      b = zeros(T, size(X, 2))
      if loss === :ls
        XF = XT[:, F]
        b[F] .= iszero(λ2) ? (XF \ yT) : ([sqrt(αT) .* XF; sqrt(T(λ2)) * I(length(F))] \ [sqrt(αT) .* yT; zeros(T, length(F))])
        gF = αT .* (XT' * (XT * b .- yT)) .+ T(λ2) .* b
      else
        bF = zeros(T, length(F)); XF = XT[:, F]
        for _ in 1:100
          s = sigm.(XF * bF); gg = XF' * (s .- yT); H = XF' * (XF .* (s .* (1 .- s)))
          bF .-= H \ gg; norm(gg, Inf) < 1e-14 * length(yT) && break
        end
        b[F] .= bF; gF = XT' * (sigm.(XT * b) .- yT)
      end
      lhat = PS._scale_norm(g)(gF)
    end
    C = Ctx{T}(loss, XT, yT, αT, groups === nothing ? cT : T(λ0) .* wT, T(λ2), gsets, colsq, F, QF,
               zeros(T, length(yT)), zeros(T, length(yT)), zeros(T, size(X, 2)), lhat)
    # BigFloat reference on the T-rounded data
    blocks = groups === nothing ? [[i] for i in 1:size(X, 2)] : gsets
    cb = big.(groups === nothing ? cT : T(λ0) .* wT)
    Pb = BP(loss, big.(XT), big.(yT), big(αT), cb, big(T(λ2)), blocks)
    if dedup === nothing
      x64 = if loss === :logistic
        bn = zeros(Float64, size(X, 2))
        solve!(bn, LogisticLoss(Float64.(yT), Float64.(XT)), NormL1(Float64(T(λ0)), Float64.(wT)), ProxNewton(maxiter = 500, tol = 1e-13))
        bn
      else
        fista64(Float64.(XT), Float64.(yT), Float64(αT), Float64.(cb), Float64(T(λ2)), blocks)
      end
      bstar = reference(Pb; x64)
    else
      keep = setdiff(1:size(X, 2), [dedup])        # exact duplicate free column: solve without it
      Pr = BP(loss, Pb.X[:, keep], Pb.y, Pb.α, Pb.c[keep], Pb.λ2, [[i] for i in eachindex(keep)])
      x64 = fista64(Float64.(XT[:, keep]), Float64.(yT), Float64(αT), Float64.(Pr.c), Float64(T(λ2)), Pr.blocks)
      br = reference(Pr; x64)
      bstar = zeros(BigFloat, size(X, 2)); bstar[keep] .= br
    end
    kb = kkt_b(Pb, bstar)
    gs = gradb(Pb, bstar)
    scalefree = max(maximum(abs, gs), maximum(cb), big(1))
    maximum(kb) / scalefree < big(1e-40) || error("$name $T: reference KKT $(Float64(maximum(kb) / scalefree))")
    Fstar = obj(Pb, bstar)
    # exact free fit (penalized at zero) and λ̂ exact
    bF = zeros(BigFloat, size(X, 2))
    if !isempty(F)
      FF = dedup === nothing ? F : setdiff(F, [dedup])
      if loss === :ls
        XF = Pb.X[:, FF]; bF[FF] .= (Pb.α .* (XF' * XF) + Pb.λ2 * I) \ (Pb.α .* (XF' * Pb.y))
      else
        XF = Pb.X[:, FF]; z = zeros(BigFloat, length(FF))
        for _ in 1:200
          s = sigm.(XF * z); gg = XF' * (s .- Pb.y); H = XF' * (XF .* (s .* (1 .- s)))
          maximum(abs, gg) < big(1e-70) && break; z .-= H \ gg
        end
        bF[FF] .= z
      end
    end
    FbF = obj(Pb, bF)
    gF = gradb(Pb, bF)
    lhat_exact = maximum(norm(gF[G]) for G in blocks)
    # exact B-scale at x*
    if loss === :ls
      Φ2 = Pb.α * sum(abs2, Pb.X * bstar - Pb.y) + Pb.λ2 * sum(abs2, bstar)
      sstar = [sqrt(Pb.α * sum(abs2, Pb.X[:, G]) + Pb.λ2) * sqrt(Φ2) for G in blocks]
    else
      dn = norm(sigm.(Pb.X * bstar) .- Pb.y)
      sstar = [sqrt(sum(abs2, Pb.X[:, G])) * dn for G in blocks]
    end
    lmax0 = Float64(maximum(norm(gradb(Pb, zeros(BigFloat, size(X, 2)))[G] .- Pb.λ2 .* 0) for G in blocks))
    for method in methods, rule in rules
      (rule === :E && loss !== :ls) && continue
      RULE[] = rule; CTX[] = C; NCHK[] = 0
      x = zeros(T, size(X, 2))
      opts = ProximalOptions()
      r = solve!(x, f, g, method, opts)
      nchk = NCHK[]
      RULE[] = :cur
      xb = big.(x)
      Fx = obj(Pb, xb)
      ks = kkt_b(Pb, xb)
      absex = Fx - Fstar
      relex = Float64(absex / abs(Fstar))
      den = length(F) == size(X, 2) ? obj(Pb, zeros(BigFloat, size(X, 2))) - Fstar : FbF - Fstar
      progex = Float64(absex / max(den, big(1e-300)))
      kang = Float64(maximum(ks ./ sstar))
      kprof = Float64(maximum(ks ./ max.(cb, lhat_exact)))
      cre = Float64(maximum(abs, xb - bstar) / max(maximum(abs, bstar), big(1e-300)))
      # diagnostics at the returned point, in T, with a fresh gradient in T
      gx = loss === :ls ? αT .* (XT' * (XT * x .- yT)) : XT' * (sigm.(XT * x) .- yT)
      τ = T(max(opts.gradtol, 64 * Float64(eps(T))))
      λm = T(lmax0)
      dg = diagnose(C, x, gx, τ, λm, T(opts.ftol))
      rr = rule === :B ? dg.ratioB : rule === :Bh ? dg.ratioBh : rule === :C ? dg.ratioC : rule === :E ? dg.gapratio : NaN
      acc = relex <= TOL_ACC
      cls = r.converged ? (acc ? "CC" : "FALSE") : (acc ? "AU" : "NC")
      row = join([name, family, String(loss), string(nameof(typeof(g))) * (pen === :en ? "(λ2=$(λ2))" : ""), string(T),
        method isa ProximalGradientDescent ? "PGD" : "APG", String(rule), r.converged, reason(r, opts.maxiter),
        r.iterations, nchk, r.grad_calls, r.prox_calls,
        @sprintf("%.3e", Float64(absex)), @sprintf("%.3e", relex), @sprintf("%.3e", progex),
        @sprintf("%.3e", kang), @sprintf("%.3e", kprof), @sprintf("%.3e", cre),
        @sprintf("%.3e", Float64(rr)), @sprintf("%.3e", Float64(dg.ratioB)), @sprintf("%.3e", Float64(dg.gapratio)),
        dg.plimited, dg.plE, @sprintf("%.3e", lmax0), @sprintf("%.3e", Float64(lhat_exact)),
        @sprintf("%.6e", Float64(Fstar)), cls], '\t')
      push!(rows, row); println(row); flush(stdout)
    end
  end
end

# λ0 at which every penalized coefficient is zero, given the free fit (Float64)
function lam0_zero(X, y, w, F, λ2; α = 1.0, loss = :ls, groups = nothing)
  p = size(X, 2); b = zeros(p)
  if !isempty(F)
    XF = X[:, F]
    if loss === :ls
      b[F] .= (α .* (XF' * XF) + λ2 * I) \ (α .* (XF' * y))
    else
      z = zeros(length(F))
      for _ in 1:100
        s = sigm.(XF * z); gg = XF' * (s .- y); H = XF' * (XF .* (s .* (1 .- s))); z .-= H \ gg
      end
      b[F] .= z
    end
  end
  g = loss === :ls ? α .* (X' * (X * b .- y)) .+ λ2 .* b : X' * (sigm.(X * b) .- y)
  groups === nothing ? maximum(abs(g[j]) / w[j] for j in 1:p if w[j] > 0) :
    maximum(norm(g[G]) / w[k] for (k, G) in enumerate(groups) if w[k] > 0)
end

want(name) = (f = get(ENV, "PROBE_ONLY", ""); isempty(f) || occursin(Regex(f), name))

function main()
  rows = String[]
  println(HDR)
  # ---- O1 family: #400 offset fixture, one free intercept
  rng = MersenneTwister(400)
  Xo = hcat(ones(50), randn(rng, 50, 9))
  sig = Xo[:, 2:5] * [2.0, -1.5, 1.0, 0.5] .+ 0.5 .* randn(rng, 50)
  w1 = vcat(0.0, ones(9))
  for off in (0.0, 1e2, 1e4, 1e6), (pk, λ2) in ((:l1, 0.0), (:en, 0.0), (:en, 1.0), (:en, 25.0))
    nm = "O1 off=$(off) $(pk)$(pk === :en ? "λ2=$(λ2)" : "")"; want(nm) || continue
    y = off .+ sig
    λ0 = 0.5 * lam0_zero(Xo, y, w1, [1], λ2)
    run_fixture!(rows, nm, "free-offset"; X = Xo, y, λ0, w = w1, λ2, pen = pk)
  end
  if want("O1 centered")
    y = (1e6 .+ sig); y = y .- sum(y) / 50
    run_fixture!(rows, "O1 centered-y control", "control"; X = Xo, y, λ0 = 0.5 * lam0_zero(Xo, y, w1, [1], 0.0), w = w1)
  end
  if want("O1 reduced")
    y = 1e6 .+ sig
    Xr = Xo[:, 2:end] .- sum(Xo[:, 2:end]; dims = 1) ./ 50; yr = y .- sum(y) / 50
    run_fixture!(rows, "O1 reduced-design control", "control"; X = Xr, y = yr, λ0 = 0.5 * lam0_zero(Xo, y, w1, [1], 0.0), w = ones(9))
  end
  # ---- O2: #464 case O, intercept + one predictor free, random weights
  rng = MersenneTwister(400)
  Xo2 = hcat(ones(50), randn(rng, 50, 9))
  yo2 = 1e6 .+ Xo2[:, 2:5] * [2.0, -1.5, 1.0, 0.5] .+ 0.5 .* randn(rng, 50)
  wo = vcat(0.0, 0.0, 2.0 .^ (4 .* rand(MersenneTwister(401), 8) .- 2))
  for (pk, λ2) in ((:l1, 0.0), (:en, 1.0))
    nm = "O2 case-O $(pk)"; want(nm) || continue
    run_fixture!(rows, nm, "free-offset"; X = Xo2, y = yo2, λ0 = 0.5 * lam0_zero(Xo2, yo2, wo, [1, 2], λ2), w = wo, λ2, pen = pk)
  end
  # ---- FC: free non-intercept column with a large mean
  rng = MersenneTwister(402)
  Z = randn(rng, 50, 10); Z[:, 1] .+= 1e3
  yfc = 50.0 .* Z[:, 1] .+ Z[:, 2:5] * [2.0, -1.5, 1.0, 0.5] .+ 0.5 .* randn(rng, 50)
  for (pk, λ2) in ((:l1, 0.0), (:en, 1.0))
    nm = "FC large free column $(pk)"; want(nm) || continue
    run_fixture!(rows, nm, "free-column"; X = Z, y = yfc, λ0 = 0.5 * lam0_zero(Z, yfc, w1, [1], λ2), w = w1, λ2, pen = pk)
  end
  # ---- FN: one free zero-mean predictor, no offset
  if want("FN")
    rng = MersenneTwister(403)
    Z = randn(rng, 50, 10); y = Z * [3.0, 2.0, -1.5, 1.0, 0.5, 0, 0, 0, 0, 0] .+ 0.5 .* randn(rng, 50)
    run_fixture!(rows, "FN free zero-mean column", "free-column"; X = Z, y, λ0 = 0.5 * lam0_zero(Z, y, w1, [1], 0.0), w = w1)
  end
  # ---- MC: intercept + 3 correlated free columns with means, offset 1e4
  if want("MC")
    rng = MersenneTwister(404)
    fac = randn(rng, 50)
    Fc = hcat([5.0 .+ fac .+ 0.3 .* randn(rng, 50) for _ in 1:3]...)
    Pm = randn(rng, 50, 6)
    X = hcat(ones(50), Fc, Pm)
    y = 1e4 .+ Fc * [1.0, -2.0, 0.5] .+ Pm[:, 1:3] * [2.0, -1.0, 0.5] .+ 0.5 .* randn(rng, 50)
    w = vcat(zeros(4), ones(6))
    run_fixture!(rows, "MC correlated free columns", "free-multi"; X, y, λ0 = 0.5 * lam0_zero(X, y, w, 1:4, 0.0), w)
  end
  # ---- RD1/RD2: nearly collinear / exactly duplicated free columns
  rng = MersenneTwister(405)
  x1 = 3.0 .+ randn(rng, 50); zz = randn(rng, 50); Pm = randn(rng, 50, 7)
  yrd = 1e4 .+ 2.0 .* x1 .+ Pm[:, 1:3] * [1.5, -1.0, 0.5] .+ 0.5 .* randn(rng, 50)
  w = vcat(zeros(3), ones(7))
  if want("RD1")
    X = hcat(ones(50), x1, x1 .+ 1e-6 .* zz, Pm)
    run_fixture!(rows, "RD1 nearly collinear free columns", "free-multi"; X, y = yrd, λ0 = 0.5 * lam0_zero(X, yrd, w, 1:3, 0.0), w)
  end
  if want("RD2")
    X = hcat(ones(50), x1, x1, Pm)
    Xk = X[:, [1, 2, 4, 5, 6, 7, 8, 9, 10]]
    λ0 = 0.5 * lam0_zero(Xk, yrd, w[[1, 2, 4, 5, 6, 7, 8, 9, 10]], 1:2, 0.0)
    run_fixture!(rows, "RD2 duplicated free column", "free-multi"; X, y = yrd, λ0, w, dedup = 3)
  end
  # ---- DEP: free column strongly dependent on the penalized columns
  if want("DEP")
    rng = MersenneTwister(406)
    Pm = randn(rng, 50, 9)
    fcol = Pm[:, 1:4] * [1.0, 1.0, 1.0, 1.0] ./ 2 .+ 0.1 .* randn(rng, 50)
    X = hcat(fcol, Pm)
    y = 2.0 .* fcol .+ Pm[:, 1:4] * [-1.0, -1.0, 1.0, 1.0] .+ 0.5 .* randn(rng, 50)
    run_fixture!(rows, "DEP free column dependent on penalized", "free-column"; X, y, λ0 = 0.5 * lam0_zero(X, y, w1, [1], 0.0), w = w1)
  end
  # ---- AF: all coordinates free
  if want("AF1")
    y = 1e6 .+ sig
    run_fixture!(rows, "AF1 all free, offset", "all-free"; X = Xo, y, λ0 = 1.0, w = zeros(10))
  end
  if want("AF2")
    y = Xo * [1e3, 2.0, -1.5, 1.0, 0.5, 0, 0, 0, 0, 0]
    run_fixture!(rows, "AF2 all free, exact fit", "all-free"; X = Xo, y, λ0 = 1.0, w = zeros(10))
  end
  # ---- TW / LW: tiny positive intercept weight; one very large weight
  if want("TW")
    y = 1e6 .+ sig; w = vcat(1e-8, ones(9))
    run_fixture!(rows, "TW tiny intercept weight 1e-8", "tiny-weight"; X = Xo, y, λ0 = 0.5 * lam0_zero(Xo, y, w1, [1], 0.0), w)
  end
  if want("LW")
    y = sig; w = vcat(0.0, ones(8), 1e8)
    run_fixture!(rows, "LW free intercept + weight 1e8", "large-weight"; X = Xo, y, λ0 = 0.5 * lam0_zero(Xo, y, w1, [1], 0.0), w)
  end
  # ---- RS: equivalent rescalings of O1 off=1e4
  yb = 1e4 .+ sig; λb = 0.5 * lam0_zero(Xo, yb, w1, [1], 0.0)
  want("RS base") && run_fixture!(rows, "RS base (O1 off=1e4)", "rescale"; X = Xo, y = yb, λ0 = λb, w = w1)
  want("RS y") && run_fixture!(rows, "RS y×1e3, λ×1e3", "rescale"; X = Xo, y = 1e3 .* yb, λ0 = 1e3 * λb, w = w1)
  if want("RS col")
    X = copy(Xo); X[:, 3] .*= 1e4; w = copy(w1); w[3] *= 1e4
    run_fixture!(rows, "RS column 3 ×1e4, weight ×1e4", "rescale"; X, y = yb, λ0 = λb, w)
  end
  want("RS obj") && run_fixture!(rows, "RS Scaled(LS,1e-4), λ×1e-4", "rescale"; X = Xo, y = yb, λ0 = 1e-4 * λb, w = w1, α = 1e-4)
  # ---- N: ordinary problems, no free coordinate
  for (dn, seed) in (("N1 50x10", 410), ("N2 100x200", 411), ("N3 200x20 AR0.8", 412), ("N4 50x10 uncentered", 413))
    rng = MersenneTwister(seed)
    if startswith(dn, "N2")
      X = randn(rng, 100, 200); β = zeros(200); β[1:5] .= [3.0, -2.0, 1.5, -1.0, 0.5]; y = X * β .+ 0.5 .* randn(rng, 100)
    elseif startswith(dn, "N3")
      n, p = 200, 20; X = zeros(n, p); X[:, 1] = randn(rng, n)
      for j in 2:p; X[:, j] = 0.8 .* X[:, j-1] .+ sqrt(1 - 0.64) .* randn(rng, n); end
      β = zeros(p); β[[1, 5, 10]] .= [2.0, -1.0, 0.5]; y = X * β .+ 0.5 .* randn(rng, n)
    else
      X = randn(rng, 50, 10); y = X * [2.0, -1.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0] .+ 0.5 .* randn(rng, 50)
      startswith(dn, "N4") && (y .+= 10.0)
    end
    p = size(X, 2)
    wr = 2.0 .^ (4 .* rand(MersenneTwister(seed + 100), p) .- 2)
    for frac in (0.9, 0.5, 0.1, 0.01), (wk, w) in (("unw", ones(p)), ("w", wr))
      nm = "$(dn) λ=$(frac)λmax $(wk)"; want(nm) || continue
      λ0 = frac * lam0_zero(X, y, w, Int[], 0.0)
      run_fixture!(rows, nm, "ordinary"; X, y, λ0, w)
    end
    if dn[1:2] in ("N1", "N3")
      for frac in (0.5, 0.1)
        nm = "$(dn) EN λ2=1 λ=$(frac)λmax"; want(nm) || continue
        run_fixture!(rows, nm, "ordinary"; X, y, λ0 = frac * lam0_zero(X, y, ones(p), Int[], 1.0), w = ones(p), λ2 = 1.0, pen = :en)
      end
    end
    if dn[1:2] == "N1" && want("N1 col")
      Xs = copy(X); Xs[:, 2] .*= 1e4; w = ones(p); w[2] = 1e4
      run_fixture!(rows, "N1 column 2 ×1e4, weight ×1e4 (no free)", "rescale"; X = Xs, y, λ0 = 0.5 * lam0_zero(X, y, ones(p), Int[], 0.0), w)
    end
  end
  # ---- IC: ill-conditioned (cond 1e4), slow
  if want("IC")
    rng = MersenneTwister(407)
    U = Matrix(qr(randn(rng, 50, 10)).Q)[:, 1:10]; V = Matrix(qr(randn(rng, 10, 10)).Q)
    X = sqrt(50) .* U * Diagonal(10.0 .^ range(0, -4, length = 10)) * V'
    y = X * [2.0, -1.5, 1.0, 0.5, 0, 0, 0, 0, 0, 0] .+ 0.01 .* randn(rng, 50)
    run_fixture!(rows, "IC ill-conditioned, no free", "ill-conditioned"; X, y, λ0 = 0.1 * lam0_zero(X, y, ones(10), Int[], 0.0), w = ones(10))
    Xi = hcat(ones(50), X[:, 1:9]); yi = 1e4 .+ y
    run_fixture!(rows, "IC ill-conditioned + free intercept, offset 1e4", "ill-conditioned"; X = Xi, y = yi,
                 λ0 = 0.1 * lam0_zero(Xi, yi, w1, [1], 0.0), w = w1)
  end
  # ---- G / G2: GroupNormL2
  if want("G singleton")
    groups = [i:i for i in 1:10]; y = 1e6 .+ sig
    run_fixture!(rows, "G singleton groups, free intercept group, off 1e6", "group"; X = Xo, y, λ0 = 0.5 * lam0_zero(Xo, y, w1, [1], 0.0; groups), w = w1, groups)
  end
  if want("G2")
    rng = MersenneTwister(414)
    X = hcat(ones(50), 2.0 .+ randn(rng, 50))
    for k in 1:4
      B = Matrix(qr(randn(rng, 50, 2)).Q)[:, 1:2] .* sqrt(50); X = hcat(X, B)
    end
    y = 1e4 .+ 1.5 .* X[:, 2] .+ X[:, 3:6] * [1.0, -1.0, 0.5, 0.25] .+ 0.5 .* randn(rng, 50)
    groups = [1:2, 3:4, 5:6, 7:8, 9:10]; w = vcat(0.0, ones(4))
    run_fixture!(rows, "G2 two-column groups, free two-column group, off 1e4", "group"; X, y, λ0 = 0.5 * lam0_zero(X, y, w, [1, 2], 0.0; groups), w, groups)
  end
  # ---- L: logistic PGD (Float64)
  rng = MersenneTwister(7)
  Xl = hcat(ones(200), randn(rng, 200, 5)); wl = vcat(0.0, ones(5))
  for b0 in (0.0, 3.0, 5.0)
    nm = "L logistic b0=$(b0)"; want(nm) || continue
    yl = Float64.(rand(MersenneTwister(8), 200) .< sigm.(b0 .+ Xl[:, 2:6] * [1.0, -1.0, 0.5, 0, 0]))
    run_fixture!(rows, nm * " ybar=$(sum(yl)/200)", "logistic"; loss = :logistic, X = Xl, y = yl,
                 λ0 = 0.5 * lam0_zero(Xl, yl, wl, [1], 0.0; loss = :logistic), w = wl, Ts = (Float64,), methods = (ProximalGradientDescent(),))
  end
  if want("L free column")
    rng = MersenneTwister(9)
    Xf = randn(rng, 200, 6); Xf[:, 1] .+= 2.0
    yl = Float64.(rand(MersenneTwister(10), 200) .< sigm.(0.8 .* Xf[:, 1] .+ Xf[:, 2:4] * [1.0, -1.0, 0.5]))
    run_fixture!(rows, "L free column mean 2 ybar=$(sum(yl)/200)", "logistic"; loss = :logistic, X = Xf, y = yl,
                 λ0 = 0.5 * lam0_zero(Xf, yl, wl, [1], 0.0; loss = :logistic), w = wl, Ts = (Float64,), methods = (ProximalGradientDescent(),))
  end
  for frac in (0.5, 0.1)
    nm = "L ordinary no free λ=$(frac)λmax"; want(nm) || continue
    rng = MersenneTwister(11)
    Xn = randn(rng, 200, 6)
    yl = Float64.(rand(MersenneTwister(12), 200) .< sigm.(Xn[:, 1:3] * [1.0, -1.0, 0.5]))
    run_fixture!(rows, nm, "logistic"; loss = :logistic, X = Xn, y = yl, λ0 = frac * lam0_zero(Xn, yl, ones(6), Int[], 0.0; loss = :logistic),
                 w = ones(6), Ts = (Float64,), methods = (ProximalGradientDescent(),))
  end
  out = get(ENV, "PROBE_OUT", joinpath(@__DIR__, "probe487b-$(VERSION).tsv"))
  open(out, "w") do io; println(io, HDR); foreach(r -> println(io, r), rows); end
end
main()
