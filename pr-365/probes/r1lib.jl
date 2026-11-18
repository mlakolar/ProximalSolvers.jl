# Shared helpers: BASE (master) and CAND in one process; step evaluation against BigFloat-512.
include("trees.jl")
using ProximalBase, LinearAlgebra, Random, Printf, Logging
using ProximalBase: SparseIterate, NormL1, SqrtLeastSquaresLoss
const TNAMES = (:base, :cand)

function onecol_model(P, xk::Vector{T}, y::Vector{T}, λ::T, old::T) where T
  X = reshape(copy(xk), :, 1)
  f = SqrtLeastSquaresLoss(y, X)
  x = SparseIterate(T[old])
  m = P.cdmodel(f, x)
  P.initialize!(m, x)
  g = NormL1(λ)
  P._prepare!(m, g, x)
  m, g, x
end

# classification of a step by MASTER's fast-path conditions: :fast, :sums (a or ρ² unclean), :d2 (recomputed d² unclean),
# :band (p, γ or τ outside the normal range), :shared (a = 0 or non-finite: before the minimizer), :lam (λ ≥ ra)
function classify(xk::Vector{T}, r::Vector{T}, λ::T, old::T) where T
  n = length(xk)
  B = TREES.base
  a, b, ρ2 = B._column_dot_rsqr(reshape(xk, n, 1), r, 1, T(NaN))
  cl(s) = isfinite(s) & (s >= n*(floatmin(T)/eps(T)))
  (isfinite(a) && !iszero(a)) || return :shared
  isfinite(ρ2) || (all(isfinite, r) || return :shared)
  (cl(a) & cl(ρ2)) || return :sums
  ra = sqrt(a)
  λ >= ra && return :lam
  q = b/a
  d2 = ρ2 - b*q
  if d2 < ρ2/16
    d2 = B._distance_sqr(reshape(xk, n, 1), r, 1, q)
    cl(d2) || return :d2
  end
  d = sqrt(d2)
  p = ra*(sqrt(ra - λ)*sqrt(ra + λ))
  γ = d/p
  τ = γ*λ
  ((floatmin(T) <= p) & (floatmin(T) <= γ <= floatmax(T)) & (floatmin(T) <= τ <= floatmax(T))) ? :fast : :band
end

# one coordinate step in tree P. Returns (z, err, r, λ, class)
function step_in(P, xk::Vector{T}, y, λ, old) where T
  m, g, x = onecol_model(P, xk, y, λ, old)
  r = copy(m.ls.r)
  cls = classify(xk, r, λ, old)
  z = old; err = nothing
  try
    P.coordinate_step!(m, g, x, 1)
    z = x[1]
  catch e
    err = e
  end
  z, err, r, m.gt.λ0, cls
end

function bigref(xk::AbstractVector{T}, r::AbstractVector{T}, old::T, λ::T) where T
  setprecision(BigFloat, 512) do
    xb = big.(xk); rb = big.(r); ob = big(old); λb = big(λ)
    a = sum(abs2, xb); b = sum(xb .* rb)
    ρ = rb .+ xb .* ob
    φ(z) = sqrt(sum(abs2, ρ .- xb .* z)) + λb*abs(z)
    ra = sqrt(a)
    c = ob + b/a
    z = if λb >= ra
      big(0)
    else
      d2 = sum(abs2, rb .- (b/a) .* xb)
      d = sqrt(d2)
      τ = iszero(d) ? big(0) : λb*d/sqrt(a*(a - λb^2))
      sign(c) * max(abs(c) - τ, big(0))
    end
    φs = φ(z)
    S = max(sqrt(sum(abs2, ρ)), sqrt(sum(abs2, rb)))
    (φ = φ, φs = φs, S = S, ra = ra, zstar = z, c = c, a = a)
  end
end
step_bound(::Type{T}, n, S, ra, λ) where T =
  (37 * (n * eps(T) / 2) / (1 - n * eps(T) / 2) + 56 * eps(T) / 2) * S + 4 * (ra + λ) * nextfloat(zero(T))

# Rec: ratio = excess/bound (NaN if throw / nonfinite), z, flags
struct Rec; ratio::Float64; z; thrown::Bool; nonfinite::Bool; msg::String; cls::Symbol; repr_ok::Bool; end
function evaluate(xk::Vector{T}, y::Vector{T}, λ::T, old::T; trees = TNAMES) where T
  n = length(xk)
  out = Dict{Symbol,Rec}()
  ref = nothing; rref = nothing
  for nm in trees
    z, err, r, lam, cls = step_in(getproperty(TREES, nm), xk, y, λ, old)
    if err !== nothing
      out[nm] = Rec(NaN, z, true, false, sprint(showerror, err), cls, false); continue
    end
    if !isfinite(z)
      zs = setprecision(BigFloat, 512) do; abs(bigref(xk, r, old, lam).zstar) <= big(floatmax(T)); end
      out[nm] = Rec(NaN, z, false, true, "", cls, zs); continue
    end
    setprecision(BigFloat, 512) do
      if ref === nothing; ref = bigref(xk, r, old, lam); rref = r
      else r == rref || error("residual differs between trees"); end
      exc = Float64(ref.φ(big(z)) - ref.φs)
      bd = Float64(step_bound(T, n, ref.S, ref.ra, big(lam)))
      out[nm] = Rec(exc/bd, z, false, false, "", cls, true)
    end
  end
  out
end
# outcome class: :value, :nonfinite, or the ArgumentError text
oclass(o::Rec) = o.thrown ? Symbol("throw:" * first(o.msg, 80)) : o.nonfinite ? :nonfinite : :value
# difference of two finite steps in ulps of the step (of the larger magnitude) and relative
function zdiff(::Type{T}, a, b) where T
  a == b && return (0.0, 0.0)
  u = max(eps(abs(a)), eps(abs(b)), nextfloat(zero(T)))
  (Float64(abs(big(a) - big(b)) / big(u)), Float64(abs(big(a) - big(b)) / max(abs(big(a)), abs(big(b)))))
end

# ---- cache-controlled step (for the boundary search): the cached residual is set to r directly ----
function step_r(P, xk::Vector{T}, r::Vector{T}, λ::T, old::T) where T
  X = reshape(copy(xk), :, 1)
  x = SparseIterate(T[zero(T)]); x[1] = old
  m = P.cdmodel(SqrtLeastSquaresLoss(copy(r), X), x)
  P.initialize!(m, x)
  copyto!(m.ls.r, r)
  g = NormL1(λ)
  P._prepare!(m, g, x)
  cls = classify(xk, r, λ, old)
  z = old; err = nothing
  try
    P.coordinate_step!(m, g, x, 1)
    z = x[1]
  catch e
    err = e
  end
  z, err, cls
end
function evaluate_r(xk::Vector{T}, r::Vector{T}, λ::T, old::T) where T
  n = length(xk)
  out = Dict{Symbol,Rec}()
  ref = nothing
  for nm in TNAMES
    z, err, cls = step_r(getproperty(TREES, nm), xk, r, λ, old)
    if err !== nothing
      out[nm] = Rec(NaN, z, true, false, sprint(showerror, err), cls, false); continue
    end
    if !isfinite(z)
      zs = setprecision(BigFloat, 512) do; abs(bigref(xk, r, old, λ).zstar) <= big(floatmax(T)); end
      out[nm] = Rec(NaN, z, false, true, "", cls, zs); continue
    end
    setprecision(BigFloat, 512) do
      ref === nothing && (ref = bigref(xk, r, old, λ))
      exc = Float64(ref.φ(big(z)) - ref.φs)
      bd = Float64(step_bound(T, n, ref.S, ref.ra, big(λ)))
      out[nm] = Rec(exc/bd, z, false, false, "", cls, true)
    end
  end
  out
end
