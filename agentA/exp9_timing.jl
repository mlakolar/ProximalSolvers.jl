using ProximalSolvers, ProximalBase, Random, Printf, LinearAlgebra
const PS = ProximalSolvers
using ProximalBase: SparseIterate
# Rough indicative probe only (not a benchmark): time per coordinate visit, inlined loop over p columns, min of reps.
function pass_time(m, g, x, p, reps)
  best = Inf
  for _ in 1:reps
    t0 = time_ns()
    for k in 1:p
      PS.coordinate_step!(m, g, x, k)
    end
    best = min(best, (time_ns() - t0) / p)
  end
  best
end
function setup_sqrt(X, y, λ)
  T = eltype(X); f = SqrtLeastSquaresLoss(y, X); x = SparseIterate(zeros(T, size(X, 2)))
  m = PS.cdmodel(f, x); PS.initialize!(m, x); g = NormL1(λ); PS._prepare!(m, g, x); m, g, x
end
function setup_ls(X, y, λ)
  T = eltype(X); f = LeastSquaresLoss(y, X); x = SparseIterate(zeros(T, size(X, 2)))
  m = PS.cdmodel(f, x); PS.initialize!(m, x); m, NormL1(λ), x
end
println("Julia ", VERSION)
for T in (Float32, Float64), n in (50, 500, 5000)
  p = 40; rng = Xoshiro(3)
  X = randn(rng, T, n, p); y = randn(rng, T, n)
  λ = T(0.1 * sqrt(n))       # lasso-type level, ordinary
  λs = T(0.5 * norm(X[:,1]))
  m, g, x = setup_sqrt(X, y, λs); for _ in 1:10; pass_time(m, g, x, p, 1); end   # warm and approach the fixed point
  ts = pass_time(m, g, x, p, 200)
  m, g, x = setup_ls(X, y, λ); for _ in 1:10; pass_time(m, g, x, p, 1); end
  tl = pass_time(m, g, x, p, 200)
  # offrange: y scaled so every visit leaves the clean range (residual squares underflow)
  ysc = T === Float32 ? T(2)^-70 : T(2)^-600
  y2 = y .* ysc
  m, g, x = setup_sqrt(X, y2, λs); for _ in 1:10; pass_time(m, g, x, p, 1); end
  to = pass_time(m, g, x, p, 50)
  @printf("%s n=%5d  ns/visit: LS=%8.0f  sqrt-ordinary=%8.0f (x%.2f of LS)   sqrt-offrange(tiny y)=%9.0f (x%.1f of ordinary)\n", T, n, tl, ts, ts/tl, to, to/ts)
end
