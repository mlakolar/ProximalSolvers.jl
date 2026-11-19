# PROTOTYPE timing, NOT production benchmark evidence (first-study design, agents/C/scripts/perf_ordinary.jl).
# Whole solves of ordinary problems (no trigger) with master copies `old`, `ctl` (A/A) and prototype copies
# `new`, `newb` loaded into one process, interleaved in a random order within each repetition.
# Statistic (fixed before running): per cell, the median over repetitions of the paired ratio t(v)/t(old);
# a cell is flagged if both prototype copies exceed 1.05 in both processes (seeds 1 and 2).
# usage: julia perf_ordinary.jl <seed> <out>
using ProximalBase, LinearAlgebra, Random, Logging, Statistics, Printf
const VARS = ["old", "ctl", "new", "newb"]
for v in VARS
  @eval module $(Symbol("M_", v))
    include($(joinpath(@__DIR__, v, "src", "ProximalSolvers.jl")))
  end
end
mod(v) = getfield(getfield(Main, Symbol("M_", v)), :ProximalSolvers)
include(joinpath(@__DIR__, "..", "scripts", "matrix.jl"))
seed = parse(Int, ARGS[1]); outf = ARGS[2]; rng = Xoshiro(seed)
const R = 30
probs = [("sqrt-n60p20", noisy(60, 20, 4, 1.0, 401), 0.1, :sqrt), ("sqrt-n200p50", noisy(200, 50, 4, 1.0, 402), 0.1, :sqrt),
         ("sqrt-n1000p200", noisy(1000, 200, 10, 1.0, 403), 0.1, :sqrt), ("sqrt-n200p600", noisy(200, 600, 5, 0.5, 404), 0.5, :sqrt),
         ("ls-n200p600", noisy(200, 600, 5, 0.5, 405), 0.1, :ls)]
function runsolve(PS, T, X, y, λ, cfg, kind, K)
  f = kind === :sqrt ? SqrtLeastSquaresLoss(y, X) : LeastSquaresLoss(y, X)
  g = NormL1(kind === :sqrt ? λ : λ * norm(y)); last = nothing
  for _ in 1:K
    x = zeros(T, size(X, 2))
    s = cfg === :cyclic ? PS.CDSolver(order = :cyclic, momentum = false) : PS.CDSolver(rng = Xoshiro(1))
    last = PS.solve!(x, f, g, s)
  end
  last
end
out = open(outf, "w"); println(out, "problem\tT\tcfg\tvariant\trep\tK\tseconds_per_solve\tpasses\tconverged")
for (pn, (X0, y0), fr, kind) in probs, T in (Float64, Float32), cfg in (:cyclic, :default)
  X, y = T.(X0), T.(y0); λ = T(fr * lammax(X0, y0))
  with_logger(NullLogger()) do
    for v in VARS; runsolve(mod(v), T, X, y, λ, cfg, kind, 3); end
    infos = Dict(v => runsolve(mod(v), T, X, y, λ, cfg, kind, 1) for v in VARS)
    all(infos[v].passes == infos["old"].passes && infos[v].converged == infos["old"].converged for v in VARS) ||
      error("variants differ in work on $pn $T $cfg")
    t1 = @elapsed runsolve(mod("old"), T, X, y, λ, cfg, kind, 5); K = max(1, ceil(Int, 0.03 / (t1 / 5)))
    for rep in 1:R, v in shuffle(rng, VARS)
      t = @elapsed runsolve(mod(v), T, X, y, λ, cfg, kind, K)
      println(out, join([pn, T, cfg, v, rep, K, t / K, infos["old"].passes, infos["old"].converged], '\t'))
    end
    flush(out)
  end
end
close(out)
