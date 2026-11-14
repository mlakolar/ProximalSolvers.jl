# Independent 256-bit BigFloat reference for the least-squares lasso
#   P(x) = α/2 ‖y - Xx‖² + λ‖x‖₁
# The minimizer depends only on λ/α, so the reference solves
#   ½‖y - Xx‖² + μ‖x‖₁, μ = big(λ)/big(α),
# from the exact BigFloat values of the T data, by cyclic coordinate descent followed
# by an exact active-set polish (normal equations on the support) and a KKT check.
using LinearAlgebra

const REFPREC = 256

function _cd!(x, Xb, yb, μ, sweeps)
  p = size(Xb, 2)
  cn = [sum(abs2, view(Xb, :, j)) for j in 1:p]
  r = yb - Xb * x
  for _ in 1:sweeps, j in 1:p
    iszero(cn[j]) && continue
    z = dot(view(Xb, :, j), r) + cn[j] * x[j]
    xn = sign(z) * max(abs(z) - μ, 0) / cn[j]
    d = xn - x[j]
    iszero(d) || (r .-= d .* view(Xb, :, j); x[j] = xn)
  end
  x
end

# exact solution on the support/sign pattern of x, or nothing if it is not a KKT point
function _polish(Xb, yb, μ, x)
  p = size(Xb, 2)
  S = findall(j -> abs(x[j]) > 1e-12 * max(1, maximum(abs, x)), 1:p)
  xp = zeros(BigFloat, p)
  if !isempty(S)
    XS = Xb[:, S]; s = sign.(x[S])
    xs = Symmetric(XS' * XS) \ (XS' * yb - μ * s)
    all(sign.(xs) .== s) || return nothing
    xp[S] .= xs
  end
  kkt_unscaled(Xb, yb, μ, xp) <= big(2)^(-200) * max(1, maximum(abs, Xb' * yb)) ? xp : nothing
end

function ref_lasso(X::AbstractMatrix, y::AbstractVector, μ::BigFloat)
  setprecision(BigFloat, REFPREC) do
    Xb = big.(X); yb = big.(y); n, p = size(Xb)
    # support from a Float64 coordinate descent, then an exact polish in BigFloat
    x64 = _cd!(zeros(p), Float64.(X), Float64.(y), Float64(μ), 20000)
    xp = _polish(Xb, yb, μ, big.(x64))
    xp === nothing || return xp
    x = _cd!(big.(x64), Xb, yb, μ, 2000)
    xp = _polish(Xb, yb, μ, x)
    xp === nothing ? x : xp
  end
end

# ‖G‖∞ of the minimal-norm element G of ∇(½‖y-Xx‖²) + μ ∂‖x‖₁
function kkt_unscaled(Xb, yb, μ, x)
  g = Xb' * (Xb * x - yb)
  m = zero(BigFloat)
  for j in eachindex(x)
    gj = iszero(x[j]) ? max(abs(g[j]) - μ, 0) : abs(g[j] + μ * sign(x[j]))
    m = max(m, gj)
  end
  m
end

# Metrics of a returned x (any float type) for the problem (α, X, y, λ), all in BigFloat:
#   relgap = (P(x) - P(x*)) / P(x*)  (P* > 0 for the noisy data used here)
#   relkkt = ‖G‖∞ / ‖Xᵀy‖∞  of the α-free problem, equal to the α-scaled KKT residual
#            over λmax = α ‖Xᵀy‖∞, so it is invariant under rescaling of the objective.
function metrics(x, X, y, α, λ, xstar)
  setprecision(BigFloat, REFPREC) do
    Xb = big.(X); yb = big.(y); μ = big(λ) / big(α); xb = big.(x)
    P(z) = sum(abs2, yb - Xb * z) / 2 + μ * sum(abs, z)
    Ps = P(xstar)
    relgap = (P(xb) - Ps) / (Ps > 0 ? Ps : P(zero(xb)))
    relkkt = kkt_unscaled(Xb, yb, μ, xb) / maximum(abs, Xb' * yb)
    Float64(relgap), Float64(relkkt), Float64(kkt_unscaled(Xb, yb, μ, xstar) / maximum(abs, Xb' * yb))
  end
end
