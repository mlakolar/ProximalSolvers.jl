# Diagnostic (not part of the evaluation): the in-step smoothed coordinate step against a BigFloat
# minimizer of φ(z) = √(‖r_k − X_k z‖² + δ²) + λ|z|, r_k = r + X_k old, on the fast and off-range branches.
include(joinpath(@__DIR__, "..", "scripts", "lib.jl"))
setprecision(BigFloat, 512)
function bigmin(xk, rk, δ, λ)
  a = sum(abs2, xk); b = dot(xk, rk); c = b / a; d2 = sum(abs2, rk .- c .* xk) + δ^2
  λ >= sqrt(a) && return big(0)
  τ = λ * sqrt(d2) / sqrt(a * (a - λ^2))
  sign(c) * max(abs(c) - τ, big(0))
end
φ(xk, rk, δ, λ, z) = sqrt(sum(abs2, rk .- xk .* z) + δ^2) + λ * abs(z)
worst = 0.0
rng = Xoshiro(1)
for trial in 1:4000, T in (Float64, Float32)
  n, p = rand(rng, 2:12), 3
  scale = trial % 4 == 0 ? T(2.0^-70) : one(T)        # tiny data: off-range branch
  X = T.(randn(rng, n, p)) .* scale
  β = T.(randn(rng, p)); β[rand(rng, 1:p)] = 0
  y = trial % 3 == 0 ? X * β : X * β .+ T.(randn(rng, n)) .* scale .* T(0.1)   # exact fits a third of the time
  λ = T(rand(rng) * 0.8) * norm(X[:, 1])
  x = SparseIterate(copy(β)); m = PS.cdmodel(SqrtLeastSquaresLoss(y, X), x); PS.initialize!(m, x); PS._prepare!(m, NormL1(λ), x)
  δ = T(rand(rng) * 2.0^rand(rng, -20:0)) * (norm(y) + scale)
  m.δ64 = Float64(δ); m.δ2 = δ^2
  k = 1; old = x[k]
  a, b, ρ2 = PS._column_dot_rsqr(m.ls.X, m.ls.r, k, T(NaN))
  z = PS._sqrt_minimizer(m, old, a, b, ρ2, k)
  xk = big.(X[:, k]); rk = big.(m.ls.r) .+ xk .* big(old)
  zb = bigmin(xk, rk, big(Float64(δ)), big(Float64(m.gt.λ0)))
  # objective error of the computed step, relative to φ at the minimizer
  e = Float64((φ(xk, rk, big(Float64(δ)), big(Float64(m.gt.λ0)), big(z)) - φ(xk, rk, big(Float64(δ)), big(Float64(m.gt.λ0)), zb)) /
              φ(xk, rk, big(Float64(δ)), big(Float64(m.gt.λ0)), zb))
  global worst = max(worst, e / eps(T))
end
println("worst relative objective error of the smoothed step, in eps(T): ", worst)
