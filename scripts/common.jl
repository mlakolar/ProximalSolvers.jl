const METHODS = (ProximalGradientDescent(), AccProxGradDescent())
lossof(α, y, X) = Scaled(LeastSquaresLoss(y, X), α)
curvature(X, α) = setprecision(BigFloat, 256) do
  BigFloat(α) * sum(abs2, BigFloat.(X))
end
λmax(X, y, α) = setprecision(BigFloat, 256) do
  BigFloat(α) * maximum(abs, BigFloat.(X)' * BigFloat.(y))
end
function penalty(::Type{T}, X, y, α, frac) where T
  iszero(frac) && return zero(T)
  max(T(frac * λmax(X, y, α)), nextfloat(zero(T)))
end
function kkt_ratio(X, y, α, λ1, λ2, x)
  setprecision(BigFloat, 256) do
    Xb, yb, xb, a = BigFloat.(X), BigFloat.(y), BigFloat.(x), BigFloat(α)
    g = a .* (Xb' * (Xb * xb - yb)) .+ BigFloat(λ2) .* xb
    l = BigFloat(λ1)
    G = maximum(j -> iszero(xb[j]) ? max(abs(g[j]) - l, zero(l)) : abs(g[j] + l * sign(xb[j])), eachindex(xb))
    S = max(l, maximum(abs, a .* (Xb' * yb)))
    Float64(G / S)
  end
end
function standardized(::Type{T}, n, p; seed = 321) where T
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  X .-= sum(X; dims = 1) ./ n
  X ./= sqrt.(sum(abs2, X; dims = 1) ./ (n - 1))
  β = zeros(p); β[1:min(p, 4)] .= (2.0, -1.5, 1.0, 0.5)[1:min(p, 4)]
  y = X * β .+ 0.1 .* randn(rng, n)
  T.(X), T.(y)
end
