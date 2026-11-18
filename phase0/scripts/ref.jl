# Independent 256-bit references for least squares  F(x) = (α/2)‖Xx − y‖² + λ‖x‖₁  (α as supplied).
module Ref321
using LinearAlgebra
setprecision(BigFloat, parse(Int, get(ENV, "REFPREC", "256")))

bf(a) = big.(a)
F(X, y, α, λ, x) = (r = bf(X) * bf(x) .- bf(y); big(α) / 2 * sum(abs2, r) + big(λ) * sum(abs, bf(x)))
G(X, y, α, x) = big(α) .* (bf(X)' * (bf(X) * bf(x) .- bf(y)))
λmax(X, y, α) = maximum(abs, big(α) .* (bf(X)' * bf(y)))
# relative minimal-norm KKT residual ‖G‖∞ / max(λ, λmax) of the lasso (as the solver's stationarity check)
function kkt(X, y, α, λ, x)
  g = G(X, y, α, x); xb = bf(x); lb = big(λ)
  v = [xi != 0 ? abs(g[i] + lb * sign(xi)) : max(abs(g[i]) - lb, 0) for (i, xi) in enumerate(xb)]
  S = max(lb, λmax(X, y, α))
  Float64(maximum(v) / S)
end
# reference minimiser: λ = 0 by normal equations; otherwise cyclic coordinate descent in 256 bits
function xstar(X, y, α, λ; maxpass = 200_000, tol = big"1e-60")
  Xb, yb = bf(X), bf(y); n, p = size(Xb)
  if iszero(λ)
    return (Xb' * Xb) \ (Xb' * yb)
  end
  x = zeros(BigFloat, p); r = Xb * x .- yb; c = [sum(abs2, Xb[:, j]) for j in 1:p]; lb = big(λ) / big(α)
  for pass in 1:maxpass
    dmax = big(0)
    for j in 1:p
      c[j] == 0 && continue
      b = c[j] * x[j] - dot(Xb[:, j], r)
      xn = sign(b) * max(abs(b) - lb, 0) / c[j]
      d = xn - x[j]
      if d != 0
        r .+= Xb[:, j] .* d; x[j] = xn
        dmax = max(dmax, abs(d) * sqrt(c[j]))
      end
    end
    dmax <= tol * (1 + sqrt(sum(abs2, yb))) && break
  end
  x
end
relerr(a, b) = Float64(abs(big(a) - b) / max(abs(b), big(nextfloat(0.0))))
end
