# Paired in-process timing for #353 PR A (#362). Sides: base0, base1 (master twice: A/A control) and head (the worktree
# at its current commit). Every side is compiled from source in this process; rounds rotate the order; a round's figure
# is the minimum over batches. Workloads: APG and PGD lasso to their stop (R2 and R4 touch APG's per-iteration
# `g_residual`, its certified-bound test and its setup); CD lasso (control: untouched code), CD group lasso with
# singleton groups and with groups of 4 (controls).
# Usage: julia --project=<worktree> pra_paired.jl OUT.tsv [rounds=15]
using LinearAlgebra, Random, Logging, Printf
BLAS.set_num_threads(1)
const ROOT = "<WORK>"
const SIDESPEC = ["base0" => joinpath(ROOT, "ProximalSolvers.jl-issue353-base"), "base1" => joinpath(ROOT, "ProximalSolvers.jl-issue353-base"),
                  "head" => joinpath(ROOT, "ProximalSolvers.jl-issue353")]
for (nm, tree) in SIDESPEC
  @eval module $(Symbol("M_", nm)); include(joinpath($tree, "src/ProximalSolvers.jl")); end
end
using ProximalBase: LeastSquaresLoss, NormL1, GroupNormL2, BlockIterate
const SIDES = [(Symbol(nm), getfield(getfield(Main, Symbol("M_", nm)), :ProximalSolvers)) for (nm, _) in SIDESPEC]

function problem(::Type{T}, n, p, seed) where T
  rng = MersenneTwister(seed)
  Z = randn(rng, n, p); b = zeros(p); b[1:min(5, p)] .= (1.0, -2.0, 1.5, -1.0, 0.5)[1:min(5, p)]
  y = Z*b .+ randn(rng, n)
  T.(Z), T.(y)
end
its(r) = hasproperty(r, :passes) ? r.passes : hasproperty(r, :iterations) ? r.iterations : -1
function one(PS, wl::Symbol, X::Matrix{T}, y, λ, gs) where T
  p = size(X, 2)
  if wl === :apg || wl === :pgd
    x = zeros(T, p); m = wl === :apg ? PS.AccProxGradDescent() : PS.ProximalGradientDescent()
    t0 = time_ns(); r = PS.solve!(x, LeastSquaresLoss(y, X), NormL1(T(λ)), m); t = time_ns() - t0
  elseif wl === :cd
    x = zeros(T, p)
    t0 = time_ns(); r = PS.solve!(x, LeastSquaresLoss(y, X), NormL1(T(λ)), PS.CDSolver(order = :cyclic)); t = time_ns() - t0
  else
    groups = [collect((k - 1)*gs + 1:min(k*gs, p)) for k in 1:cld(p, gs)]
    g = GroupNormL2(T(λ/sqrt(gs)), groups); x = BlockIterate(T, p, g)
    t0 = time_ns(); r = PS.solve!(x, LeastSquaresLoss(y, X), g, PS.CDSolver(order = :cyclic, tol = T === Float64 ? 1e-8 : 1e-5)); t = time_ns() - t0
  end
  (Float64(t), its(r), r.converged, Float64(r.minimum))
end
function sample(PS, wl, X, y, λ, gs, evals, batches)
  best = Inf; info = (0, false, NaN)
  for _ in 1:batches
    tot = 0.0
    for _ in 1:evals; t, a, b, c = one(PS, wl, X, y, λ, gs); tot += t; info = (a, b, c); end
    best = min(best, tot/evals)
  end
  best, info
end
function run(out, rounds)
  open(out, "w") do io
    println(io, join(["julia", "workload", "T", "n", "p", "lamfrac", "round", "side", "ns", "passes", "converged", "objective", "load1"], '\t'))
    for T in (Float64, Float32), (wl, gs) in ((:apg, 0), (:pgd, 0), (:cd, 0), (:group1, 1), (:group4, 4)), (n, p) in ((20, 12), (100, 60), (400, 40), (40, 120), (1000, 200))
      X, y = problem(T, n, p, 353 + n + p)
      λ = 0.1*Float64(maximum(abs, X'y))
      names = collect(eachindex(SIDES))
      t1 = maximum(sample(SIDES[i][2], wl, X, y, λ, gs, 1, 2)[1] for i in names)
      evals = clamp(round(Int, 2.0e6/t1), 1, 2000)
      for r in 1:rounds, i in circshift(names, r)
        t, (pa, cv, ob) = sample(SIDES[i][2], wl, X, y, λ, gs, evals, 5)
        println(io, join([string(VERSION), wl, T, n, p, 0.1, r, SIDES[i][1], @sprintf("%.1f", t), pa, cv, @sprintf("%.17g", ob), @sprintf("%.2f", Sys.loadavg()[1])], '\t'))
      end
      flush(io)
    end
  end
end
with_logger(NullLogger()) do; run(ARGS[1], length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 15); end
