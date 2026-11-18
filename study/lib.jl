# Shared material of the #352 stopping audit: deterministic fixtures, independent BigFloat
# measures of a returned point (KKT residual, rigorous duality gap, objective), and references.
# Nothing here uses a solver's own stopping quantities. All measures are evaluated on the
# rounded inputs the solver received (X, y, the loss scale and the levels as values of T).
using ProximalSolvers, ProximalBase, LinearAlgebra, Logging, Printf, SparseArrays, Random
const PS = ProximalSolvers
const PB = ProximalBase
const PREC = 600

# ---- deterministic numbers (splitmix64; only +, *, shifts, so inputs are the same on every Julia) ----
mutable struct SM64
  s::UInt64
end
function next!(g::SM64)
  g.s += 0x9e3779b97f4a7c15
  z = g.s
  z = (z ⊻ (z >> 30)) * 0xbf58476d1ce4e5b9
  z = (z ⊻ (z >> 27)) * 0x94d049bb133111eb
  z ⊻ (z >> 31)
end
unif(g::SM64) = (next!(g) >> 11) * 2.0^-53
# approximately standard normal: a sum of 12 uniforms minus 6 (no libm call)
function gaussish(g::SM64)
  s = -6.0
  for _ in 1:12
    s += unif(g)
  end
  s
end
gmat(g, n, p) = [gaussish(g) for _ in 1:n, _ in 1:p]
gvec(g, n) = [gaussish(g) for _ in 1:n]

# ---- fixtures: (name, X, y) in Float64; the caller rounds them to T ----
function hadamard(n)
  H = ones(1, 1)
  while size(H, 1) < n
    H = [H H; H -H]
  end
  H
end
function sparse_truth(g, p, k)
  b = zeros(p)
  for j in 1:k
    b[1 + (7j) % p] = (isodd(j) ? 1.0 : -1.0) * (1 + unif(g))
  end
  b
end
function fixtures()
  out = Tuple{String, Matrix{Float64}, Vector{Float64}}[]
  g = SM64(0x352)
  # orthogonal columns (exactly, in both precisions)
  X = hadamard(32)[:, 2:9]
  push!(out, ("orth", X, X * sparse_truth(g, 8, 3) + 0.5 * gvec(g, 32)))
  # i.i.d. columns
  X = gmat(g, 40, 12)
  push!(out, ("gauss", X, X * sparse_truth(g, 12, 4) + 0.5 * gvec(g, 40)))
  # equicorrelated, rho = 0.95
  Z, z0 = gmat(g, 40, 12), gvec(g, 40)
  X = sqrt(0.05) .* Z .+ sqrt(0.95) .* z0
  push!(out, ("corr95", X, X * sparse_truth(g, 12, 4) + 0.5 * gvec(g, 40)))
  # rank deficient: 6 independent columns, 4 exact copies or sums, 2 near copies
  B = gmat(g, 40, 6)
  X = hcat(B, B[:, 1], B[:, 2] + B[:, 3], B[:, 4] - B[:, 5], 2 .* B[:, 6],
           B[:, 1] + 1e-6 .* gvec(g, 40), B[:, 2] + 1e-9 .* gvec(g, 40))
  push!(out, ("rankdef", X, X * sparse_truth(g, 12, 4) + 0.5 * gvec(g, 40)))
  # underdetermined, noisy
  X = gmat(g, 20, 60)
  push!(out, ("wide", X, X * sparse_truth(g, 60, 5) + 0.5 * gvec(g, 20)))
  # underdetermined, exact fit
  X = gmat(g, 20, 60)
  push!(out, ("wide_exact", X, X * sparse_truth(g, 60, 5)))
  # a zero column and a column orthogonal to y by construction
  X = gmat(g, 40, 12)
  X[:, 3] .= 0
  push!(out, ("zerocol", X, X * sparse_truth(g, 12, 4) + 0.5 * gvec(g, 40)))
  # column norms spread over 10^-3 .. 10^3
  X = gmat(g, 40, 12) .* reshape([10.0^(-3 + 6 * (j - 1) / 11) for j in 1:12], 1, 12)
  push!(out, ("colscale", X, gmat(g, 40, 12) * sparse_truth(g, 12, 4) + 0.5 * gvec(g, 40)))
  # tall and noiseless (near exact fit with a small penalty)
  X = gmat(g, 60, 10)
  push!(out, ("tall_exact", X, X * sparse_truth(g, 10, 3)))
  # response dwarfs the residual: a large offset in the span of X
  X = hcat(ones(50), gmat(g, 50, 9))
  push!(out, ("offset", X, 1e6 .+ X[:, 2:end] * sparse_truth(g, 9, 3) + 0.5 * gvec(g, 50)))
  # y = 0
  push!(out, ("yzero", gmat(g, 30, 8), zeros(30)))
  out
end
fixture(name) = only(f for f in fixtures() if f[1] == name)

# ---- BigFloat measures for  s/2 ‖y − Xb‖² + λ1 ‖b‖₁ + λ2/2 ‖b‖² ----
bigv(v) = BigFloat.(v)
struct LassoRef
  X::Matrix{BigFloat}
  y::Vector{BigFloat}
  s::BigFloat
  l1::BigFloat
  l2::BigFloat
  λmax::BigFloat
end
LassoRef(X, y, s, l1, l2) = (Xb = bigv(X); yb = bigv(y); sb = big(s);
  LassoRef(Xb, yb, sb, big(l1), big(l2), sb * maximum(abs, Xb' * yb)))

# F(x), the minimal-norm KKT residual ‖G‖∞, and a dual value D ≤ F* (weak duality), for a point x.
# Dual of the lasso on the augmented data [√s X; √λ2 I], [√s y; 0]: D(θ) = ⟨θ, ỹ⟩ − ‖θ‖²/2 for
# ‖X̃ᵀθ‖∞ ≤ λ1, with θ = κ r̃, r̃ = ỹ − X̃x, κ = min(1, λ1/‖X̃ᵀr̃‖∞). X̃ᵀr̃ = −(∇f(x) + λ2 x).
function measures(R::LassoRef, x)
  xb = bigv(x)
  r = R.y - R.X * xb
  grad = -R.s .* (R.X' * r) .+ R.l2 .* xb
  G = zero(BigFloat)
  for j in eachindex(xb)
    v = iszero(xb[j]) ? max(abs(grad[j]) - R.l1, 0) : abs(grad[j] + R.l1 * sign(xb[j]))
    G = max(G, v)
  end
  F = R.s / 2 * sum(abs2, r) + R.l1 * sum(abs, xb) + R.l2 / 2 * sum(abs2, xb)
  gn = maximum(abs, grad)
  κ = iszero(gn) ? big(1) : min(big(1), R.l1 / gn)
  D = κ * R.s * dot(r, R.y) - κ^2 * (R.s * sum(abs2, r) + R.l2 * sum(abs2, xb)) / 2
  (; F, G, D)
end

# A reference for the minimum: bounds Dref ≤ F* ≤ Fref from the best point found. The candidate
# points come from the package's own Float64 CD at a tight threshold and are then polished in
# BigFloat on the candidate's support (the stationarity equations of the support, solved exactly);
# the bounds themselves are evaluated independently, so the origin of the point does not matter.
function reference(R::LassoRef, X64::Matrix{Float64}, y64::Vector{Float64}, s64, l1, l2)
  p = size(X64, 2)
  if iszero(R.l1)
    xs = smooth_minimizer(R)
    Fs = measures(R, xs).F
    return (; Fref = Fs, Dref = Fs, xref = xs)
  end
  best = measures(R, zeros(p))
  bestx = zeros(BigFloat, p)
  cands = Vector{Vector{BigFloat}}()
  for order in (:cyclic,)
    x = zeros(p)
    f = s64 * LeastSquaresLoss(y64, X64)
    g = iszero(l2) ? NormL1(Float64(l1)) : ElasticNet(Float64(l1), Float64(l2))
    try
      with_logger(NullLogger()) do
        solve!(x, f, g, CDSolver(order = order, momentum = false, tol = 1e-15, maxpasses = 200_000))
      end
      push!(cands, bigv(x))
      xp = polish(R, x)
      xp === nothing || push!(cands, xp)
    catch
    end
  end
  for c in cands
    m = measures(R, c)
    if m.F < best.F || (m.F == best.F && m.D > best.D)
      best, bestx = m, c
    end
  end
  D = maximum(measures(R, c).D for c in cands; init = best.D)
  (; Fref = best.F, Dref = max(D, zero(BigFloat)), xref = bestx)
end
# λ1 = 0: the objective is a convex quadratic, minimized exactly (to the BigFloat precision) on a
# maximal set of linearly independent columns when λ2 = 0 (the minimum of least squares depends only
# on the column span), and on all columns when λ2 > 0. Returns the minimizer, zero off that set.
function smooth_minimizer(R::LassoRef)
  n, p = size(R.X)
  keep = Int[]
  if iszero(R.l2)
    Q = Vector{Vector{BigFloat}}()
    for j in 1:p
      v = copy(R.X[:, j])
      nv0 = sqrt(sum(abs2, v))
      iszero(nv0) && continue
      for q in Q, _ in 1:2
        v .-= dot(q, v) .* q
      end
      nv = sqrt(sum(abs2, v))
      nv > nv0 * big(2.0)^-300 || continue
      push!(Q, v ./ nv)
      push!(keep, j)
    end
  else
    keep = collect(1:p)
  end
  xb = zeros(BigFloat, p)
  isempty(keep) && return xb
  XA = R.X[:, keep]
  xb[keep] = (R.s .* (XA' * XA) + R.l2 * I) \ (R.s .* (XA' * R.y))
  xb
end
# The exact stationary point on the support and signs of x (BigFloat linear solve); nothing when the
# system is singular or the result leaves the sign pattern.
function polish(R::LassoRef, x)
  A = findall(!iszero, x)
  isempty(A) && return nothing
  XA = R.X[:, A]
  sg = bigv(sign.(x[A]))
  H = R.s .* (XA' * XA) + R.l2 * I
  rhs = R.s .* (XA' * R.y) .- R.l1 .* sg
  bA = try
    H \ rhs
  catch
    return nothing
  end
  all(isfinite, bA) && all(sign.(bA) .== sg) || return nothing
  xb = zeros(BigFloat, length(x))
  xb[A] = bA
  xb
end

# ---- group lasso measures:  s/2 ‖y − Xb‖² + λ Σ w_k ‖b_k‖ ----
function group_measures(X, y, s, λ, groups, w, x)
  Xb, yb, xb, sb, lb, wb = bigv(X), bigv(y), bigv(collect(x)), big(s), big(λ), bigv(w)
  r = yb - Xb * xb
  grad = -sb .* (Xb' * r)
  G = zero(BigFloat)
  t = big(1)
  S = zero(BigFloat)
  g0 = sb .* (Xb' * yb)
  for (k, idx) in enumerate(groups)
    gk, bk = grad[idx], xb[idx]
    nb = sqrt(sum(abs2, bk))
    v = iszero(nb) ? max(sqrt(sum(abs2, gk)) - lb * wb[k], 0) : sqrt(sum(abs2, gk .+ lb * wb[k] .* bk ./ nb))
    G = max(G, v)
    a = sqrt(sum(abs2, gk))
    if iszero(lb * wb[k])
      iszero(a) || (t = zero(BigFloat))
    else
      a > 0 && (t = min(t, lb * wb[k] / a))
    end
    # the scale of the residual: the level at which group k leaves 0, or the gradient norm at 0 of an
    # unpenalized group
    S = max(S, sqrt(sum(abs2, g0[idx])) / (iszero(wb[k]) ? big(1) : wb[k]))
  end
  F = sb / 2 * sum(abs2, r) + lb * sum(wb[k] * sqrt(sum(abs2, xb[idx])) for (k, idx) in enumerate(groups))
  D = t * sb * dot(r, yb) - t^2 * sb * sum(abs2, r) / 2
  (; F, G, D, λmax = S)
end

# ---- square-root lasso measures:  ‖y − Xb‖ + λ ‖b‖₁ ; dual: max θᵀy, ‖θ‖ ≤ 1, ‖Xᵀθ‖∞ ≤ λ ----
function sqrt_measures(X, y, λ, x)
  Xb, yb, xb, lb = bigv(X), bigv(y), bigv(collect(x)), big(λ)
  r = yb - Xb * xb
  nr = sqrt(sum(abs2, r))
  P = nr + lb * sum(abs, xb)
  if iszero(nr)
    return (; P, D = zero(BigFloat), exactfit = true)
  end
  z = Xb' * r ./ nr
  zn = maximum(abs, z)
  t = iszero(zn) ? big(1) : min(big(1), lb / zn)
  (; P, D = t * dot(r, yb) / nr, exactfit = false)
end

# ---- helpers ----
rel(a, b) = iszero(b) ? (iszero(a) ? 0.0 : Inf) : Float64(a / b)
f64(x) = Float64(x)
quiet(f) = with_logger(f, NullLogger())
# captures whether a warning was logged
struct CountLogger <: AbstractLogger
  msgs::Vector{String}
end
Logging.min_enabled_level(::CountLogger) = Logging.Warn
Logging.shouldlog(::CountLogger, args...) = true
Logging.handle_message(l::CountLogger, level, msg, args...; kwargs...) = (push!(l.msgs, string(msg)); nothing)
function capture(f)
  l = CountLogger(String[])
  r = with_logger(f, l)
  r, l.msgs
end
tsv(io, vals...) = println(io, join((v isa AbstractFloat ? @sprintf("%.6g", v) : string(v) for v in vals), '\t'))
