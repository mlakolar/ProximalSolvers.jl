# designs after benchmark/problems.jl regression_problem (core/lasso, lasso-B, lasso-C, lasso-D) and
# benchmark/minimal/explore.jl, plus two stress designs with long active phases and p ≫ |A|
function regression(seed; n, p, ρ = 0.0, fraction = 0.15, k = 5, noise = 0.2)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  if ρ > 0
    for j in 2:p
      @views X[:, j] .= ρ .* X[:, j-1] .+ sqrt(1 - ρ^2) .* X[:, j]
    end
  end
  for j in 1:p
    @views X[:, j] ./= sqrt(sum(abs2, X[:, j]) / n)
  end
  β = zeros(p); β[randperm(rng, p)[1:min(k, p)]] .= rand(rng, (-1.0, 1.0), min(k, p))
  y = X * β + noise * randn(rng, n)
  s = 1 / n
  λ = fraction * maximum(abs, s .* (X' * y))
  (; X, y, s, λ)
end
const PROBLEMS = [
  ("core-lasso 100x32",      () -> regression(1; n = 100, p = 32)),
  ("lasso-B 240x160 r.8",    () -> regression(2; n = 240, p = 160, ρ = 0.8)),
  ("lasso-C 800x120 r.5",    () -> regression(3; n = 800, p = 120, ρ = 0.5)),
  ("lasso-D 180x600",        () -> regression(4; n = 180, p = 600)),
  ("explore 500x200",        () -> regression(5; n = 500, p = 200, fraction = 0.1, k = 8, noise = 0.05)),
  ("stress 200x1000 r.95",   () -> regression(6; n = 200, p = 1000, ρ = 0.95, fraction = 0.05, k = 10)),
  ("stress 100x2000 small-λ", () -> regression(7; n = 100, p = 2000, fraction = 0.02, k = 10)),
]

