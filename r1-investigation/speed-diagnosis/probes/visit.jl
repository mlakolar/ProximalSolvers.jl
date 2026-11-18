# W5 (#353, X1): equal-work per-visit probe. At a fixed model state (the converged iterate of master, or the zero
# start), one read-only "pass": for every k the fused column kernel and the step formula, as `coordinate_step!`
# calls them (inlined in this loop), without changing x or the residual. Same inputs on every side, so the work is
# equal whatever the last bits of a side's result. Sides are compiled from source in this process; rounds rotate
# the order; a round's figure is the minimum over batches; ratios are side/base0.
# Usage: julia --project=<ps-353> x1_visit.jl OUT.tsv [rounds=15]
using LinearAlgebra, Random, Logging, Printf
BLAS.set_num_threads(1)
const ROOT = "<WORK>/ProximalSolvers.jl-issue353-r1-perf/.codex-orchestrator/variants"
const SIDESPEC = [Pair(split(kv, "=")...) for kv in split(get(ENV, "X1_SIDES", "base0=base,base1=base,k=k"), ",")]
for (nm, tree) in SIDESPEC
  @eval module $(Symbol("M_", nm)); include(joinpath(Main.ROOT, $(String(tree)), "src/ProximalSolvers.jl")); end
end
using ProximalBase: SqrtLeastSquaresLoss, NormL1, SparseIterate
const SIDES = [(Symbol(nm), getfield(getfield(Main, Symbol("M_", nm)), :ProximalSolvers)) for (nm, _) in SIDESPEC]

function problem(::Type{T}, n, p, seed) where T
  rng = MersenneTwister(seed)
  Z = randn(rng, n, p); b = zeros(p); b[1:min(5, p)] .= (1.0, -2.0, 1.5, -1.0, 0.5)[1:min(5, p)]
  y = Z*b .+ randn(rng, n)
  X, yv = T.(Z), T.(y)
  X, yv, Float64(maximum(abs, X'yv)/norm(yv))
end
# the pass: `col` and `step` are the side's `_column_dot_rsqr` and `_sqrt_minimizer`
@noinline function pass(col::F, step::G, m, xv::Vector{T}, reps::Int) where {F, G, T}
  ls = m.ls; acc = zero(T)
  for _ in 1:reps, k in eachindex(xv)
    a, b, ρ2 = col(ls.X, ls.r, k, ls.a[k])
    acc += step(m, xv[k], a, b, ρ2, k)
  end
  acc
end
function model(PS, f, g, xv::Vector{T}) where T
  x = SparseIterate(copy(xv)); m = PS.cdmodel(f, x); PS.initialize!(m, x); PS._prepare!(m, g, x)
  for k in eachindex(xv); m.ls.a[k] = sum(abs2, view(m.ls.X, :, k)); end      # warm curvature cache, as after a pass
  m
end
function run(out, rounds)
  open(out, "w") do io
    println(io, join(["julia", "workload", "T", "n", "p", "state", "round", "side", "ns", "passes", "converged", "objective", "load1"], '\t'))
    for T in (Float64, Float32), (n, p) in ((20, 10), (100, 60), (400, 40), (30, 120), (1000, 200)), state in (:converged, :zero)
      cf = get(ENV, "V_CELLS", ""); (isempty(cf) || "$T:$n:$p:$state" in split(cf, ",")) || continue
      X, y, λmax = problem(T, n, p, 353 + n + p)
      f, g = SqrtLeastSquaresLoss(y, X), NormL1(0.1*λmax)
      xv = zeros(T, p)
      state === :converged && SIDES[1][2].solve!(xv, f, g, SIDES[1][2].CDSolver(order = :cyclic))
      ms = [model(PS, f, g, xv) for (_, PS) in SIDES]
      reps = clamp(round(Int, 2.0e5/(n*p)), 1, 2000)
      vals = [pass(PS._column_dot_rsqr, PS._sqrt_minimizer, m, xv, 1) for ((_, PS), m) in zip(SIDES, ms)]
      for r in 1:rounds, i in circshift(collect(eachindex(SIDES)), r)
        nm, PS = SIDES[i]; best = Inf
        for _ in 1:7
          t0 = time_ns(); pass(PS._column_dot_rsqr, PS._sqrt_minimizer, ms[i], xv, reps); best = min(best, (time_ns() - t0)/reps)
        end
        println(io, join([string(VERSION), "W5", T, n, p, state, r, nm, @sprintf("%.2f", best), count(!iszero, xv), "-", @sprintf("%.17g", Float64(vals[i])), @sprintf("%.2f", Sys.loadavg()[1])], '\t'))
      end
      flush(io)
    end
  end
end
with_logger(NullLogger()) do; run(ARGS[1], length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 15); end
