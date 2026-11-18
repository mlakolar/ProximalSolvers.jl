# Paired in-process timing for experiment X1 (#353): square-root lasso CD on ordinary data.
# Sides: base0, base1 (two separately compiled copies of master dac9f4b: the A/A control), x1a, x1b.
# Every side is compiled from source in this process. Each round times every side once (order rotated);
# a side's figure for a round is the minimum over `batches` samples; ratios are side/base0 per round.
# W1 = solve to convergence (cyclic order, default tol); W3 = 3 passes from the zero start with tol = 0 (every side
# does the same visits up to last-bit differences); W2 = `P` passes with tol = 0 (mostly visits at the fixed point:
# equal work only between sides whose results are bit-identical); W4 = `P` passes with tol = 0 at λ = 1.05 λmax, where the
# iterate stays 0: every visit is the column dot and the scalar step formula, with no update, on every side.
# Usage: julia --project=<ps-353> x1_paired.jl OUT.tsv [rounds=15] [quick]
using LinearAlgebra, Random, Logging, Printf, Statistics
BLAS.set_num_threads(1)
const ROOT = "<WORK>/ProximalSolvers.jl-issue353-r1-perf/.codex-orchestrator/variants"
# sides: name=tree pairs from ENV["X1_SIDES"], default base0,base1,x1a,x1b
const SIDESPEC = [Pair(split(kv, "=")...) for kv in split(get(ENV, "X1_SIDES", "base0=base,base1=base,k=k"), ",")]
for (nm, tree) in SIDESPEC
  @eval module $(Symbol("M_", nm)); include(joinpath(Main.ROOT, $(String(tree)), "src/ProximalSolvers.jl")); end
end
using ProximalBase: SqrtLeastSquaresLoss, NormL1
const SIDES = NamedTuple{Tuple(Symbol.(first.(SIDESPEC)))}(Tuple(getfield(getfield(Main, Symbol("M_", nm)), :ProximalSolvers) for (nm, _) in SIDESPEC))

function problem(::Type{T}, n, p, seed; rho = 0.0) where T
  rng = MersenneTwister(seed)
  Z = randn(rng, n, p)
  rho > 0 && (Z .= sqrt(1 - rho) .* Z .+ sqrt(rho) .* randn(rng, n))
  b = zeros(p); b[1:min(5, p)] .= (1.0, -2.0, 1.5, -1.0, 0.5)[1:min(5, p)]
  y = Z*b .+ randn(rng, n)
  X, yv = T.(Z), T.(y)
  λmax = maximum(abs, X'yv)/norm(yv)
  X, yv, Float64(λmax)
end

# one timed solve behind a function barrier; returns (ns, passes, converged, objective)
function onesolve(PS, x::Vector{T}, f, g, solver) where T
  fill!(x, zero(T))
  t0 = time_ns()
  r = PS.solve!(x, f, g, solver)
  t = time_ns() - t0
  (Float64(t), r.passes, r.converged, Float64(r.minimum))
end
function sample(PS, x, f, g, mk, evals, batches)
  best = Inf; info = (0, false, NaN)
  for _ in 1:batches
    tot = 0.0
    for _ in 1:evals
      t, pa, cv, ob = onesolve(PS, x, f, g, mk(PS))
      tot += t; info = (pa, cv, ob)
    end
    best = min(best, tot/evals)
  end
  best, info
end

function run(out, rounds, quick)
  sizes = quick ? [(20, 10), (100, 60)] : [(20, 10), (100, 60), (400, 40), (30, 120), (1000, 200)]
  names = collect(keys(SIDES))
  open(out, "w") do io
    println(io, join(["julia", "workload", "T", "n", "p", "lamfrac", "round", "side", "ns", "passes", "converged", "objective", "load1"], '\t'))
    for T in (Float64, Float32), (n, p) in sizes, lf in (0.5, 0.1), wl in WLS
      cf = get(ENV, "V_CELLS", ""); (isempty(cf) || "$T:$n:$p:$lf:$wl" in split(cf, ",")) || continue
      X, y, λmax = problem(T, n, p, 353 + n + p)
      wl === :W4 && lf != 0.5 && continue      # W4 runs once per size, at λ = 1.05 λmax
      f, g = SqrtLeastSquaresLoss(y, X), NormL1((wl === :W4 ? 1.05 : lf)*λmax)
      P = clamp(round(Int, 2.0e6/(n*p)), 5, 400)
      mk = wl === :W1 ? (PS -> PS.CDSolver(order = :cyclic)) : wl === :W3 ? (PS -> PS.CDSolver(order = :cyclic, tol = 0.0, maxpasses = 3)) :
        (PS -> PS.CDSolver(order = :cyclic, tol = 0.0, maxpasses = P))
      x = zeros(T, p)
      # warm up and size the samples to about 2 ms each
      t1 = 0.0
      for nm in names; t1 = max(t1, sample(SIDES[nm], x, f, g, mk, 1, 3)[1]); end
      evals = clamp(round(Int, 2.0e6/t1), 1, 2000)
      for r in 1:rounds
        order = circshift(names, r)
        for nm in order
          t, (pa, cv, ob) = sample(SIDES[nm], x, f, g, mk, evals, 5)
          println(io, join([string(VERSION), wl, T, n, p, lf, r, nm, @sprintf("%.1f", t), pa, cv, @sprintf("%.17g", ob), @sprintf("%.2f", Sys.loadavg()[1])], '\t'))
        end
        flush(io)
      end
    end
  end
end
const WLS = Tuple(Symbol.(split(get(ENV, "X1_WL", "W1,W3,W2"), ",")))
out = ARGS[1]; rounds = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 15; quick = "quick" in ARGS
with_logger(NullLogger()) do
  run(out, rounds, quick)
end
