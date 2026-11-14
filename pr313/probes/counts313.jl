# Deterministic work counts (passes, full/active passes, coordinate visits) and BigFloat-256 KKT for
# ordinary Float32/Float64 lasso problems under master's schedule and forced-full-pass schedules.
# Usage: julia --project=<tree> counts313.jl LABEL  (rows on stdout, prefixed ROW)
using LinearAlgebra, Random, ProximalBase, ProximalSolvers, Printf, Logging
const PS = ProximalSolvers
BLAS.set_num_threads(1)

const NFULL = Ref(0); const NACTIVE = Ref(0); const VISITS = Ref(0)
@eval PS function _pass!(x, m, g, st::_CDState{T}, full::Bool, scaled::Bool) where {T}
  full ? ($NFULL[] += 1) : ($NACTIVE[] += 1)
  $VISITS[] += full ? ncoordinates(x) : nactive(x)
  maxh = if full
    _sweep!(x, m, g, st, scaled, Base.OneTo(ncoordinates(x)))
  else
    _sweep!(x, m, g, st, scaled, activecoordinates(x))
  end
  dropzeros!(x)
  maxh
end

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

kkt_big(X, y, s, λ, x) = setprecision(BigFloat, 256) do
  Xb, yb, xb, sb, lb = big.(X), big.(y), big.(x), big(s), big(λ)
  d = sb .* (Xb' * (Xb * xb .- yb))
  v = maximum(j -> iszero(xb[j]) ? max(abs(d[j]) - lb, 0) : abs(d[j] + lb * sign(xb[j])), eachindex(xb))
  Float64(v / max(lb, maximum(abs, sb .* (Xb' * yb))))
end

function solve1(T, prob, x0, order, momentum, tol, seed)
  f = T(prob.s) * LeastSquaresLoss(T.(prob.y), T.(prob.X))
  x = T.(x0)
  NFULL[] = 0; NACTIVE[] = 0; VISITS[] = 0
  r = with_logger(NullLogger()) do
    solve!(x, f, NormL1(T(prob.λ)), CDSolver(; order, momentum, tol, maxpasses = 100_000, rng = Xoshiro(seed)))
  end
  (; x, r.passes, r.converged, nfull = NFULL[], nactive = NACTIVE[], visits = VISITS[])
end

function main()
  K = isempty(ARGS) ? "tree" : ARGS[1]
  ORD = [(:cyclic, false, 1), (:random, nothing, 1), (:random, nothing, 2), (:random, nothing, 3),
         (:random, false, 1), (:random, false, 2), (:random, false, 3)]
  io = stdout
  println(io, join(["ROW", "problem", "T", "start", "order", "momentum", "seed", "tol", "K", "converged", "passes", "nfull", "nactive", "visits", "kkt"], '\t'))
  for (pname, mk) in PROBLEMS
    prob = mk()
    p = size(prob.X, 2)
    # warm start: the Float64 solution at 1.25λ (cyclic, tight tolerance)
    w = solve1(Float64, merge(prob, (; λ = 1.25prob.λ)), zeros(p), :cyclic, false, 1e-12, 1)
    for T in (Float32, Float64), (sname, x0) in (("cold", zeros(p)), ("warm", w.x)),
        tol in (1e-7, T === Float32 ? 1e-6 : 1e-11), (order, momentum, seed) in ORD
      r = solve1(T, prob, x0, order, momentum, tol, seed)
      kkt = kkt_big(T.(prob.X), T.(prob.y), T(prob.s), T(prob.λ), r.x)
      println(io, join(["ROW", pname, T, sname, order, momentum, seed, tol, K, r.converged, r.passes, r.nfull, r.nactive, r.visits, kkt], '\t'))
    end
    flush(io)
  end
end
main()
