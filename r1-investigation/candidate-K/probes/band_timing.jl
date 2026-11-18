# Cost of a solve whose visits leave the fast path through the band exit (a and ρ² in range, γ or γλ not a
# normal number of T): master (band step, O(1) after the fused kernel) against the candidate (the scaled
# cold step, O(n)). Paired in one process, base twice (A/A).
using LinearAlgebra, Random, Logging, Printf
BLAS.set_num_threads(1)
const P = "<WORK>"
module B0; include("<WORK>/ProximalSolvers.jl-issue353-base/src/ProximalSolvers.jl"); end
module B1; include("<WORK>/ProximalSolvers.jl-issue353-base/src/ProximalSolvers.jl"); end
module K;  include("<WORK>/ProximalSolvers.jl-issue353-r1/src/ProximalSolvers.jl"); end
using ProximalBase: SqrtLeastSquaresLoss, NormL1
const SIDES = (("base0", B0.ProximalSolvers), ("base1", B1.ProximalSolvers), ("cand", K.ProximalSolvers))
function data(::Type{T}, n, p, sx, sy) where T
  rng = Xoshiro(11 + n + p)
  Z = randn(rng, n, p); β = zeros(p); β[1:3] .= (1.0, -2.0, 1.5)
  y = Z*β .+ randn(rng, n)
  T.(Z .* sx), T.(y .* sy)
end
# fraction of coordinates whose first visit (from x = 0) fails the band test of the fast path
function bandfrac(X::Matrix{T}, y, λ) where T
  n, p = size(X); cnt = 0
  for k in 1:p
    xk = view(X, :, k); a = sum(abs2, xk); b = dot(xk, y); ρ2 = sum(abs2, y)
    ra = sqrt(a); λ >= ra && continue
    q = b/a; d2 = ρ2 - b*q; d = sqrt(max(d2, zero(T)))
    pp = ra*(sqrt(ra - λ)*sqrt(ra + λ)); γ = d/pp; τ = γ*λ
    ok = (floatmin(T) <= pp) & (floatmin(T) <= γ <= floatmax(T)) & (floatmin(T) <= τ <= floatmax(T))
    cnt += !ok
  end
  cnt/p
end
function one(PS, X::Matrix{T}, y, λ, passes) where T
  x = zeros(T, size(X, 2))
  t0 = time_ns()
  r = PS.solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), PS.CDSolver(order = :cyclic, tol = T(0), maxpasses = passes))
  (time_ns() - t0, r.passes, r.converged, x)
end
function main()
  println("Julia ", VERSION)
  for (T, sx, sy, lab) in ((Float32, 1.0, 1.0, "ordinary (control)"), (Float32, 1e-14, 1e12, "band"), (Float64, 1.0, 1.0, "ordinary (control)"), (Float64, 1e-110, 1e100, "band")),
      (n, p) in ((30, 10), (200, 40), (1000, 100))
    X, y = data(T, n, p, sx, sy)
    λ = T(0.3*maximum(abs, X'y)/norm(y))
    bf = bandfrac(X, y, λ)
    res = [one(PS, X, y, λ, 10) for (_, PS) in SIDES]             # warm
    same = all(r -> r[4] == res[1][4], res); samebits = all(r -> reinterpret.(UInt64, Float64.(r[4])) == reinterpret.(UInt64, Float64.(res[1][4])), res)
    rounds = 9; t = zeros(3, rounds)
    for r in 1:rounds, i in circshift(1:3, r)
      best = typemax(UInt64)
      for _ in 1:7; best = min(best, one(SIDES[i][2], X, y, λ, 10)[1]); end
      t[i, r] = best
    end
    med(v) = sort(v)[(length(v) + 1) ÷ 2]
    @printf("%s %-18s n=%4d p=%3d band exits at x=0: %3.0f%%  passes %s  base0 %8.1f µs  cand/base0 %.3f [%.3f, %.3f]  base1/base0 %.3f  x equal: %s finite: %s\n",
            T, lab, n, p, 100bf, join((r[2] for r in res), "|"), med(t[1, :])/1e3, med(t[3, :] ./ t[1, :]), minimum(t[3, :] ./ t[1, :]), maximum(t[3, :] ./ t[1, :]),
            med(t[2, :] ./ t[1, :]), samebits, all(isfinite, res[3][4]))
  end
end
with_logger(NullLogger()) do; main(); end
