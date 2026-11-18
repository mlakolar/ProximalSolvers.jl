# x1d (the timed variant: lazy column, 4-argument cold call) against x1b (the variant of the correctness runs):
# bitwise-equal solves, or the same exception, on ordinary and rescaled data.
using LinearAlgebra, Random, Logging
const ROOT = "<WORK>"
module MB; include(joinpath(Main.ROOT, "ps-353-x1b/src/ProximalSolvers.jl")); end
module MD; include(joinpath(Main.ROOT, "ps-353-x1d/src/ProximalSolvers.jl")); end
using ProximalBase: SqrtLeastSquaresLoss, NormL1
function outcome(PS, X::Matrix{T}, y, λ, random) where T
  x = zeros(T, size(X, 2))
  try
    r = PS.solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), PS.CDSolver(order = random ? :random : :cyclic, rng = MersenneTwister(7), maxpasses = 2000))
    (:ok, reinterpret(T === Float32 ? UInt32 : UInt64, x), r.passes, r.converged, reinterpret(T === Float32 ? UInt32 : UInt64, r.gap), reinterpret(T === Float32 ? UInt32 : UInt64, r.minimum))
  catch e
    (:throw, typeof(e), first(sprint(showerror, e), 60))
  end
end
function main()
  rng = MersenneTwister(353); n_cases = 0; mism = 0; thr = 0
  with_logger(NullLogger()) do
    for T in (Float32, Float64), (n, p) in ((1, 1), (2, 3), (20, 10), (30, 120), (100, 60)), rep in 1:6, random in (false, true)
      exps = T === Float32 ? (-140, -100, -60, -30, 0, 30, 60, 100) : (-1000, -540, -500, -480, -200, 0, 200, 480, 500, 520, 1000)
      Z = randn(rng, n, p); y0 = Z*randn(rng, p) .* (rep == 1 ? 0.0 : 1.0) .+ randn(rng, n) .* (rep == 2 ? 0.0 : 1.0)
      for sy in exps, sx in (0, exps[2], exps[end-1])
        X = T.(ldexp.(Z, sx)); y = T.(ldexp.(y0, sy))
        (all(isfinite, X) && all(isfinite, y)) || continue
        λ = 0.2*Float64(maximum(abs, X'y))/max(Float64(norm(y)), floatmin(Float64)); (isfinite(λ) && λ > 0 && isfinite(T(λ)) && T(λ) > 0) || continue
        a, b = outcome(MB.ProximalSolvers, X, y, λ, random), outcome(MD.ProximalSolvers, X, y, λ, random)
        n_cases += 1; thr += a[1] === :throw; mism += a != b
        a != b && mism <= 5 && println("MISMATCH ", (T, n, p, sy, sx, random), "\n  ", a, "\n  ", b)
      end
    end
  end
  println(VERSION, ": cases ", n_cases, ", throws ", thr, ", mismatches ", mism)
end
main()
