# Shared helpers of experiment X1 (issue #353, Stage 0). Loads BASE, X1A, X1B into wrapper modules.
include(joinpath(@__DIR__, "acc_trees.jl"))
using ProximalBase, LinearAlgebra, Random, Printf, Logging
using ProximalBase: SparseIterate, NormL1, SqrtLeastSquaresLoss
const TNAMES = (:base, :cand, :x1d)

# model of ONE column xk (n x 1) with y, level λ, starting value old, in tree P
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

# one coordinate step in tree P. Returns (z, err, r) with z = x[1] after the step (old on a throw).
function step_in(P, xk::Vector{T}, y, λ, old) where T
  m, g, x = onecol_model(P, xk, y, λ, old)
  r = copy(m.ls.r)
  a, b, ρ2 = P._column_dot_rsqr(m.ls.X, m.ls.r, 1, T(NaN))
  n = length(r)
  cl(s) = isfinite(s) & (s >= n*(floatmin(T)/eps(T)))
  info = !(isfinite(a) && !iszero(a)) ? :shared : (cl(a) & cl(ρ2)) ? :clean : all(iszero, r) ? :r0 : :unclean
  z = old; err = nothing
  try
    P.coordinate_step!(m, g, x, 1)
    z = x[1]
  catch e
    err = e
  end
  z, err, r, m.gt.λ0, info
end

# BigFloat reference (precision 512) from the ROUNDED stored inputs; returns a function z -> φ(z) - φ(z*), plus data for the bound
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
# the step_bound of test/sqrt_lasso.jl:305
step_bound(::Type{T}, n, S, ra, λ) where T =
  (37 * (n * eps(T) / 2) / (1 - n * eps(T) / 2) + 56 * eps(T) / 2) * S + 4 * (ra + λ) * nextfloat(zero(T))

# result of one family member in one tree: ratio = excess/bound; :throw, :nonfinite flags
struct Rec; ratio::Float64; thrown::Bool; nonfinite::Bool; msg::String; info::Symbol; repr_ok::Bool; end
function evaluate(xk::Vector{T}, y::Vector{T}, λ::T, old::T, trees = TNAMES) where T
  n = length(xk)
  out = Dict{Symbol,Rec}()
  ref = nothing; rref = nothing
  for nm in trees
    z, err, r, lam, info = step_in(getproperty(TREES, nm), xk, y, λ, old)
    if err !== nothing
      out[nm] = Rec(NaN, true, false, first(split(sprint(showerror, err), '\n')), info, false) ; continue
    end
    if !isfinite(z)
      zs = setprecision(BigFloat, 512) do; abs(bigref(xk, r, old, lam).zstar) <= big(floatmax(T)); end
      out[nm] = Rec(NaN, false, true, "", info, zs); continue
    end
    setprecision(BigFloat, 512) do
      if ref === nothing; ref = bigref(xk, r, old, lam); rref = r
      else r == rref || error("residual differs between trees"); end
      exc = Float64(ref.φ(big(z)) - ref.φs)
      bd = Float64(step_bound(T, n, ref.S, ref.ra, big(lam)))
      out[nm] = Rec(exc/bd, false, false, "", info, true)
    end
  end
  out
end
