# PROTOTYPE timing, NOT production benchmark evidence. Whole-solve timings of the ordinary square-root path for old / A/A control / (i) / (ii),
# several copies per side, interleaved in random order within each repetition, one process. usage: julia perf_ordinary.jl <seed> <out>
include(joinpath(@__DIR__, "perf_load.jl")); include("<RUN>/scripts/matrix.jl")
using Logging, Statistics, Printf
seed = parse(Int, ARGS[1]); outf = ARGS[2]; rng = Xoshiro(seed)
const R = 40
probs = [("n60p20", noisy(60, 20, 4, 1.0, 401), 0.1), ("n200p50", noisy(200, 50, 4, 1.0, 402), 0.1),
         ("n1000p200", noisy(1000, 200, 10, 1.0, 403), 0.1), ("n200p600-nonexact", noisy(200, 600, 5, 0.5, 404), 0.5)]
function runsolve(PS, T, X, y, λ, cfg, K)
  f = SqrtLeastSquaresLoss(y, X); g = NormL1(λ); last = nothing
  for _ in 1:K
    x = zeros(T, size(X, 2))
    s = cfg === :cyclic ? PS.CDSolver(order = :cyclic, momentum = false) : PS.CDSolver(rng = Xoshiro(1))
    last = PS.solve!(x, f, g, s)
  end
  last
end
out = open(outf, "w"); println(out, "problem\tT\tcfg\tvariant\trep\tK\tseconds_per_solve\tpasses\tconverged")
for (pn, (X0, y0), fr) in probs, T in (Float64, Float32), cfg in (:cyclic, :default)
  X, y = T.(X0), T.(y0); λ = T(fr * lammax(X0, y0))
  with_logger(NullLogger()) do
    # warm-up all variants, calibrate K on old
    for v in VARS; runsolve(mod(v), T, X, y, λ, cfg, 3); end
    t1 = @elapsed runsolve(mod("old"), T, X, y, λ, cfg, 5); K = max(1, ceil(Int, 0.03 / (t1 / 5)))
    info = runsolve(mod("old"), T, X, y, λ, cfg, 1)
    for rep in 1:R, v in shuffle(rng, VARS)
      t = @elapsed runsolve(mod(v), T, X, y, λ, cfg, K)
      println(out, join([pn, T, cfg, v, rep, K, t / K, info.passes, info.converged], '\t'))
    end
    flush(out)
  end
end
close(out)
