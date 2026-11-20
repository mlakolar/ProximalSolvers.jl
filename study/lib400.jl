# #400: independent BigFloat measures for the weighted lasso and the ℓ∞-penalized least squares, on top of the
# #352 audit library (fixtures, LassoRef, measures, reference, polish, helpers), which is included unchanged.
# Nothing here reads a solver's own stopping quantities.
include(joinpath(@__DIR__, "..", "archive352", "study", "lib.jl"))
setprecision(BigFloat, PREC)

# ---- environment record ----
using TOML
function manifest_pb()
  dir = dirname(Base.active_project())
  for f in ("Manifest-v$(VERSION.major).$(VERSION.minor).toml", "Manifest.toml")
    path = joinpath(dir, f)
    isfile(path) || continue
    d = TOML.parsefile(path)
    deps = get(d, "deps", d)
    e = get(deps, "ProximalBase", nothing)
    e === nothing && continue
    e = first(e)
    return "$(f): " * join(["$(k)=$(get(e, k, "?"))" for k in ("version", "repo-rev", "git-tree-sha1", "repo-url")], " ")
  end
  "not found"
end
function env_lines()
  pbdir = pkgdir(ProximalBase)
  psdir = pkgdir(ProximalSolvers)
  tree(d) = try
    readchomp(`git -C $d rev-parse HEAD`)
  catch
    "no-git"
  end
  [
    "julia $(VERSION)",
    "ProximalSolvers dir $(psdir)",
    "ProximalBase dir $(pbdir) (slug dir $(basename(pbdir)))",
    "ProximalBase pkgversion $(pkgversion(ProximalBase))",
    "BLAS threads $(LinearAlgebra.BLAS.get_num_threads()) Julia threads $(Threads.nthreads())",
    "CPU $(Sys.cpu_info()[1].model)",
    "active project $(Base.active_project())",
    "manifest ProximalBase entry $(manifest_pb())",
  ]
end

# ======================= weighted lasso:  s/2 ‖y − Xb‖² + Σ c_j |b_j|,  c_j = λ0 w_j (exact product) =======================
struct WRef
  X::Matrix{BigFloat}
  y::Vector{BigFloat}
  s::BigFloat
  c::Vector{BigFloat}
  λmax::BigFloat            # s ‖Xᵀy‖∞ (the solver's scale component)
  U::Vector{Int}            # zero-coefficient coordinates (unpenalized)
  Q::Vector{Vector{BigFloat}} # orthonormal basis of span(X_U)
end
function WRef(X, y, s, λ0, w)
  Xb, yb, sb = bigv(X), bigv(y), big(s)
  c = big(λ0) .* bigv(w)
  U = findall(iszero, c)
  Q = Vector{Vector{BigFloat}}()
  for j in U
    v = copy(Xb[:, j])
    nv0 = sqrt(sum(abs2, v))
    iszero(nv0) && continue
    for q in Q, _ in 1:2
      v .-= dot(q, v) .* q
    end
    nv = sqrt(sum(abs2, v))
    nv > nv0 * big(2.0)^-300 || continue
    push!(Q, v ./ nv)
  end
  WRef(Xb, yb, sb, c, sb * maximum(abs, Xb' * yb), U, Q)
end
project_off(R::WRef, v) = (u = copy(v); for q in R.Q, _ in 1:2; u .-= dot(q, u) .* q; end; u)

# F, the minimal-norm KKT residual ‖G‖∞ and a dual value D ≤ F*: θ = κ P r, P the projection off span(X_U)
# (so X_Uᵀθ = 0 to the BigFloat precision), κ = min(1, min_{c_j>0} c_j / |s X_jᵀ P r|).
function wmeasures(R::WRef, x)
  xb = bigv(x)
  r = R.y - R.X * xb
  grad = -R.s .* (R.X' * r)
  G = zero(BigFloat)
  for j in eachindex(xb)
    v = iszero(xb[j]) ? max(abs(grad[j]) - R.c[j], 0) : abs(grad[j] + R.c[j] * sign(xb[j]))
    G = max(G, v)
  end
  F = R.s / 2 * sum(abs2, r) + sum(R.c .* abs.(xb))
  Pr = isempty(R.Q) ? r : project_off(R, r)
  z = R.s .* (R.X' * Pr)
  κ = big(1)
  for j in eachindex(z)
    iszero(R.c[j]) && continue
    iszero(z[j]) || (κ = min(κ, R.c[j] / abs(z[j])))
  end
  D = R.s * κ * dot(Pr, R.y) - R.s * κ^2 * sum(abs2, Pr) / 2
  (; F, G, D)
end

# the exact stationary point on the support and signs of x (a zero coefficient leaves its sign free)
function wpolish(R::WRef, x)
  A = findall(!iszero, x)
  isempty(A) && return nothing
  XA = R.X[:, A]
  sg = bigv(sign.(x[A]))
  H = R.s .* (XA' * XA)
  rhs = R.s .* (XA' * R.y) .- R.c[A] .* sg
  bA = try
    H \ rhs
  catch
    return nothing
  end
  all(isfinite, bA) || return nothing
  for (k, j) in enumerate(A)
    iszero(R.c[j]) && continue
    sign(bA[k]) == sg[k] || return nothing
  end
  xb = zeros(BigFloat, length(x))
  xb[A] = bA
  xb
end

# reference: Float64 CD (tol 1e-15) on the weighted penalty with the exact-product coefficients rounded to Float64,
# polished on its support; bounds evaluated independently.
function wreference(R::WRef, X64, y64, s64, λ0, w)
  p = size(X64, 2)
  if all(iszero, R.c)
    xs = smooth_minimizer(LassoRef(R.X, R.y, R.s, big(0), big(0), R.λmax))
    m = wmeasures(R, xs)
    return (; Fref = m.F, Dref = m.F, xref = xs)
  end
  cands = Vector{Vector{BigFloat}}([zeros(BigFloat, p)])
  for maxp in (200_000,)
    x = zeros(p)
    try
      quiet() do
        solve!(x, s64 * LeastSquaresLoss(y64, X64), NormL1(Float64(λ0), Float64.(w)),
               CDSolver(order = :cyclic, momentum = false, tol = 1e-15, maxpasses = maxp))
      end
      push!(cands, bigv(x))
      xp = wpolish(R, x)
      xp === nothing || push!(cands, xp)
    catch
    end
  end
  ms = [wmeasures(R, c) for c in cands]
  i = argmin([m.F for m in ms])
  (; Fref = ms[i].F, Dref = max(maximum(m.D for m in ms), zero(BigFloat)), xref = cands[i])
end

# ======================= ℓ∞ penalty:  s/2 ‖y − Xb‖² + λ ‖b‖∞ =======================
struct LRef
  X::Matrix{BigFloat}
  y::Vector{BigFloat}
  s::BigFloat
  λ::BigFloat
  g0inf::BigFloat   # ‖∇f(0)‖∞ = s‖Xᵀy‖∞
  g0one::BigFloat   # ‖∇f(0)‖₁ : 0 is a minimizer iff λ ≥ this
end
LRef(X, y, s, λ) = (Xb = bigv(X); yb = bigv(y); sb = big(s); g0 = sb .* (Xb' * yb);
  LRef(Xb, yb, sb, big(λ), maximum(abs, g0), sum(abs, g0)))

# Euclidean projection of u onto {a ≥ 0, Σ a = r} (sort based), r > 0
function simplex_proj(u::Vector{BigFloat}, r::BigFloat)
  v = sort(u; rev = true)
  cs = zero(BigFloat)
  θ = zero(BigFloat)
  for k in eachindex(v)
    cs += v[k]
    t = (cs - r) / k
    if k == length(v) || v[k+1] <= t
      θ = t
      break
    end
  end
  max.(u .- θ, 0)
end
# Euclidean projection onto the ℓ1 ball of radius r
function l1ball_proj(v::Vector{BigFloat}, r::BigFloat)
  sum(abs, v) <= r && return copy(v)
  sign.(v) .* simplex_proj(abs.(v), r)
end

# F, D (θ = κ r, κ = min(1, λ / ‖s Xᵀr‖₁)), the Euclidean distance from −∇f(x) to λ∂‖x‖∞ (the quantity that
# ProximalBase's full-point kkt_violation(NormLinf(λ), ∇f(x), x) computes, evaluated here independently), the ∞-norm
# of that minimal-norm element, and ‖∇f(x)‖∞.
function lmeasures(R::LRef, x)
  xb = bigv(x)
  r = R.y - R.X * xb
  grad = -R.s .* (R.X' * r)
  m = maximum(abs, xb)
  F = R.s / 2 * sum(abs2, r) + R.λ * m
  g1 = sum(abs, grad)
  κ = iszero(g1) ? big(1) : min(big(1), R.λ / g1)
  D = κ * R.s * dot(r, R.y) - κ^2 * R.s * sum(abs2, r) / 2
  if iszero(m)
    e = grad .- l1ball_proj(grad, R.λ)            # grad + λ v, v in the unit ℓ1 ball, of least norm
  else
    J = findall(i -> abs(xb[i]) == m, eachindex(xb))
    e = copy(grad)
    σ = sign.(xb[J])
    u = -σ .* grad[J]
    a = iszero(R.λ) ? zeros(BigFloat, length(J)) : simplex_proj(u, R.λ)
    e[J] .= grad[J] .+ σ .* a
  end
  (; F, D, K2 = sqrt(sum(abs2, e)), Kinf = maximum(abs, e), ginf = maximum(abs, grad))
end

# exact stationary point for a given face: J (tied at level t with signs σ), the rest free (gradient 0).
# Returns nothing when the system is singular or the result violates the face (|b_F| < t, multipliers ≥ 0).
function lpolish_face(R::LRef, J, σ)
  p = size(R.X, 2)
  Fr = setdiff(1:p, J)
  Z = hcat(R.X[:, Fr], R.X[:, J] * bigv(σ))
  rhs = R.s .* (Z' * R.y)
  rhs[end] -= R.λ
  z = try
    (R.s .* (Z' * Z)) \ rhs
  catch
    return nothing
  end
  all(isfinite, z) || return nothing
  t = z[end]
  t > 0 || return nothing
  all(abs.(z[1:end-1]) .< t) || return nothing
  xb = zeros(BigFloat, p)
  xb[Fr] = z[1:end-1]
  xb[J] = t .* bigv(σ)
  grad = -R.s .* (R.X' * (R.y - R.X * xb))
  all(-bigv(σ) .* grad[J] .>= -big(1e-60) * max(R.λ, big(1))) || return nothing
  xb
end
function lpolish(R::LRef, x)
  m = maximum(abs, x)
  iszero(m) && return nothing
  out = Vector{Vector{BigFloat}}()
  for rt in (1e-12, 1e-9, 1e-6, 1e-4, 1e-3)
    J = findall(i -> abs(x[i]) >= m * (1 - rt), eachindex(x))
    xp = lpolish_face(R, J, sign.(x[J]))
    xp === nothing || push!(out, xp)
  end
  out
end

# reference: candidates from a long Float64 APG and PGD run (strict options), polished on their faces; the bounds
# are evaluated independently (the origin of a candidate does not matter). λ = 0: the least-squares minimizer.
function lreference(R::LRef, X64, y64, s64, λ)
  p = size(X64, 2)
  if iszero(R.λ)
    xs = smooth_minimizer(LassoRef(R.X, R.y, R.s, big(0), big(0), R.g0inf))
    m = lmeasures(R, xs)
    return (; Fref = m.F, Dref = m.F, xref = xs)
  end
  cands = Vector{Vector{BigFloat}}([zeros(BigFloat, p)])
  f = s64 * LeastSquaresLoss(y64, X64)
  for method in (AccProxGradDescent(), ProximalGradientDescent())
    x = zeros(p)
    try
      quiet() do
        solve!(x, f, NormLinf(Float64(λ)), method,
               ProximalOptions(maxiter = 100_000, ftol = 0, xtol = 1e-300, gradtol = 0, allow_f_increases = true))
      end
      push!(cands, bigv(x))
      append!(cands, lpolish(R, x))
    catch
    end
  end
  ms = [lmeasures(R, c) for c in cands]
  i = argmin([m.F for m in ms])
  (; Fref = ms[i].F, Dref = max(maximum(m.D for m in ms), zero(BigFloat)), xref = cands[i])
end

# full column rank in BigFloat (the minimizer is unique for a strictly convex quadratic part)
function fullrank(X)
  n, p = size(X)
  n >= p || return false
  s = svdvals(Float64.(X))
  minimum(s) > 1e-10 * maximum(s)
end
