# Recheck of the flagged cells of timing_b.jl (Float32, tiny scale, near-parallel residual): two copies of the base and
# two copies of the head in one process, sides rotated. args: rounds batches
using LinearAlgebra, Random, Logging, Printf
BLAS.set_num_threads(1)
module B0; include("<WORK>/ProximalSolvers.jl-issue353-2-base/src/ProximalSolvers.jl"); end
module B1; include("<WORK>/ProximalSolvers.jl-issue353-2-base/src/ProximalSolvers.jl"); end
module H0; include("<WORK>/ProximalSolvers.jl-issue353-2/src/ProximalSolvers.jl"); end
module H1; include("<WORK>/ProximalSolvers.jl-issue353-2/src/ProximalSolvers.jl"); end
using ProximalBase: SqrtLeastSquaresLoss, NormL1
const ORDER = get(ARGS, 3, "bbhh")
const ALL = Dict('b' => [("base0", B0.ProximalSolvers), ("base1", B1.ProximalSolvers)], 'h' => [("head0", H0.ProximalSolvers), ("head1", H1.ProximalSolvers)])
const SIDES = let cnt = Dict('b' => 0, 'h' => 0); [(cnt[c] += 1; ALL[c][cnt[c]]) for c in ORDER]; end
const ROUNDS = parse(Int, get(ARGS, 1, "15")); const BATCHES = parse(Int, get(ARGS, 2, "7"))
function data(::Type{T}, n, p, sc) where T
  rng = Xoshiro(17 + n + p)
  Z = randn(rng, n, p); β = zeros(p); β[1] = 3.0; y = Z*β .+ 1e-8 .* randn(rng, n)
  T.(ldexp.(Z, sc)), T.(ldexp.(y, sc))
end
function one(PS, X::Matrix{T}, y, λ) where T
  x = zeros(T, size(X, 2))
  t0 = time_ns()
  r = PS.solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), PS.CDSolver(order = :cyclic))
  (time_ns() - t0, r.passes, r.converged, x)
end
function main()
  println("Julia ", VERSION, " rounds=", ROUNDS, " batches=", BATCHES, " sides=", join(first.(SIDES), ","))
  for (T, sc) in ((Float32, -70), (Float64, -520)), (n, p) in ((200, 1), (200, 40), (1000, 100))
    X, y = data(T, n, p, sc)
    λ = T(0.3*maximum(abs, Float64.(X)'*Float64.(y))/norm(Float64.(y)))
    for _ in 1:2, (_, PS) in SIDES; one(PS, X, y, λ); end
    ns = length(SIDES); t = zeros(ns, ROUNDS)
    for r in 1:ROUNDS, i in circshift(1:ns, r)
      best = typemax(UInt64)
      for _ in 1:BATCHES; best = min(best, one(SIDES[i][2], X, y, λ)[1]); end
      t[i, r] = best
    end
    med(v) = sort(v)[(length(v) + 1) ÷ 2]
    ib = findfirst(s -> s[1] == "base0", SIDES)
    @printf("%s n=%4d p=%3d  base0 %9.1f µs |", T, n, p, med(t[ib, :])/1e3)
    for (i, (nm, _)) in enumerate(SIDES); i == ib && continue; @printf("  %s/base0 %.3f [%.3f, %.3f]", nm, med(t[i, :] ./ t[ib, :]), minimum(t[i, :] ./ t[ib, :]), maximum(t[i, :] ./ t[ib, :])); end
    println(); flush(stdout)
  end
end
with_logger(NullLogger()) do; main(); end
