# The §18 Float32 reciprocal-overflow fixture of test/cd_numerics.jl and an independent BigFloat-256
# oracle (copied from the test helpers, so the probes do not depend on the test module).
function scaled_problem(::Type{T}, target; xscale = 1.0, zero_column = false) where T
  rng = Xoshiro(99)
  X = randn(rng, 30, 3) * [1 0.5 0.3; 0 1 0.5; 0 0 1]
  y = X * [1.0, -2.0, 0.5] .+ 0.01 .* randn(rng, 30)
  c = target / norm(y)
  zero_column && (X = hcat(X, zeros(30)))
  Matrix{T}(xscale .* X), Vector{T}(c .* y), c / xscale
end
penalty_fraction(T, X, y, α, fraction) = iszero(fraction) ? zero(T) :
  setprecision(BigFloat, 256) do
    T(big(fraction) * maximum(abs, big(α) .* (big.(X)' * big.(y))))
  end
kkt_relative(X, y, α, λ, x) = setprecision(BigFloat, 256) do
  Xb, yb, xb, ab, lb = big.(X), big.(y), big.(x), big(α), big(λ)
  d = ab .* (Xb' * (Xb * xb .- yb))
  v = maximum(j -> iszero(xb[j]) ? max(abs(d[j]) - lb, 0) : abs(d[j] + lb * sign(xb[j])), eachindex(xb))
  Float64(v / max(lb, maximum(abs, ab .* (Xb' * yb))))
end
objective_big(X, y, α, λ, x) = setprecision(BigFloat, 256) do
  Xb, yb, xb = big.(X), big.(y), big.(x)
  big(α) * sum(abs2, yb .- Xb * xb) / 2 + big(λ) * sum(abs, xb)
end
function reference_lasso(X, y, α, λ; passes = 400)
  setprecision(BigFloat, 256) do
    Xb, ab, lb = big.(X), big(α), big(λ)
    b, r = zeros(BigFloat, size(X, 2)), big.(y)
    a = [sum(abs2, Xb[:, k]) for k in axes(X, 2)]
    for _ in 1:passes, k in axes(X, 2)
      iszero(a[k]) && continue
      z = b[k] + sum(Xb[i, k] * r[i] for i in eachindex(r)) / a[k]
      t = lb / (ab * a[k]); new = sign(z) * max(abs(z) - t, 0)
      r .-= Xb[:, k] .* (new - b[k]); b[k] = new
    end
    b
  end
end
function fixture311(; zero_column = false)
  T = Float32
  X, y, c = scaled_problem(T, 100.0; xscale = 3e-6, zero_column)
  α = 1f-30
  f = α * LeastSquaresLoss(y, X)
  λ = penalty_fraction(T, X, y, α, 0.5)
  X, y, c, α, f, λ
end
