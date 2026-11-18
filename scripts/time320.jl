# #320 timing probe: return time versus time-to-target of Float32 PGD under the option profiles, and
# warmed allocations. One process, one loaded revision. Every round times every arm once in a rotating
# order (arms: H, an A/A copy of H, D, S, A, Q, and a solve stopped at k* = the first iterate whose
# independent gap meets the target: "time to target"). Minimum and median over rounds per arm.
#   julia --project=<env> time320.jl <outprefix> <draws a:b> [rounds]
using Printf, Statistics, LinearAlgebra, SHA, TOML
import ProximalSolvers, ProximalBase
outprefix, draws = ARGS[1], ARGS[2]
ROUNDS = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 9
a_, b_ = parse.(Int, split(draws, ':'))
BLAS.set_num_threads(1); Threads.nthreads() == 1 || error("one thread")
harness = get(ENV, "A320_HARNESS", joinpath(@__DIR__, "..", "..", "benchmark"))
const H = Module(:Harness320t)
Core.eval(H, :(import ProximalBase, ProximalSolvers; using LinearAlgebra, SparseArrays, Random, SHA, Printf, Statistics))
Core.eval(H, :(include(p) = Base.include($H, p)))
for f in ("problems.jl", "certificates.jl", "cases.jl"); Base.include(H, joinpath(harness, f)); end
const PS = ProximalSolvers
mkpath(dirname(outprefix))
open(outprefix * "-provenance.txt", "w") do io
  println(io, "julia ", VERSION, " cpu ", Sys.cpu_info()[1].model, " ", Sys.CPU_NAME, " threads ", Threads.nthreads(), " blas ", BLAS.get_num_threads(), " ", BLAS.get_config())
  println(io, "PS ", pkgdir(PS), " PB ", pkgdir(ProximalBase), " project ", Base.active_project())
  println(io, "host ", gethostname(), " rounds ", ROUNDS)
end
profiles(T) = [
  ("D", PS.ProximalOptions()),
  ("H", H.benchmark_options(; residual = true)),
  ("Haa", H.benchmark_options(; residual = true)),
  ("S", PS.ProximalOptions(maxiter = 10_000, ftol = 0, xtol = 1e-300, gradtol = 1e-11, allow_f_increases = true)),
  ("A", H.accuracy_options()),
  ("Q", PS.ProximalOptions(maxiter = 10_000, ftol = 0, xtol = 1e-14, gradtol = H.CORE_TARGETS[T] / 100, allow_f_increases = true))]
designs = [
  ("lasso", r -> H.regression_problem(r, "core/lasso"), false),
  ("lasso-B", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B), false),
  ("lasso-C", r -> H.regression_problem(r, "extended/design-C"; n = 800, p = 120, design = :C), false),
  ("lasso-D", r -> H.regression_problem(r, "extended/design-D"; n = 180, p = 600, design = :D), false)]

# the loop shape of a caller: a function barrier around one solve! on a reset iterate, result kept
@noinline function timed!(x, x0, f, g, m, o)
  copyto!(x, x0)
  t0 = time_ns()
  r = PS.solve!(x, f, g, m, o)
  t = time_ns() - t0
  t, r.iterations, r.converged
end
@noinline function alloc!(x, x0, f, g, m, o)
  copyto!(x, x0)
  b0 = Base.gc_bytes()
  PS.solve!(x, f, g, m, o)
  Base.gc_bytes() - b0
end
indep_gap(ex, x) = (c = H.certify(ex, Float64.(x)); c.status == :ok ? c.value : NaN)

io = open(outprefix * "-timing.tsv", "w")
println(io, join(("julia", "design", "draw", "arm", "min_ns", "median_ns", "iterations", "converged", "alloc_bytes", "kstar", "gap_at_return"), '\t'))
T = Float32
for (design, make, warm) in designs, draw in a_:b_
  a = H.core_problem(make(draw), T; warm); ex = H.exact_problem(a); f, g = H.benchmark_model(a)
  m = PS.ProximalGradientDescent(); x0 = a.start; x = copy(x0)
  # k*: first iteration count whose iterate meets the target (S-like options stopped at maxiter = k)
  kstar = -1
  for k in 2:200
    o = PS.ProximalOptions(maxiter = k, ftol = 0, xtol = 1e-300, gradtol = 0, allow_f_increases = true)
    copyto!(x, x0); PS.solve!(x, f, g, m, o)
    if indep_gap(ex, x) <= H.CORE_TARGETS[T]; kstar = k; break; end
  end
  arms = profiles(T)
  kstar > 0 && push!(arms, ("TTT", PS.ProximalOptions(maxiter = kstar, ftol = 0, xtol = 1e-300, gradtol = 0, allow_f_increases = true)))
  for (n, o) in arms; timed!(x, x0, f, g, m, o); timed!(x, x0, f, g, m, o); end   # warm
  times = Dict(n => Float64[] for (n, _) in arms)
  for round in 1:ROUNDS
    order = circshift(1:length(arms), -(round - 1))
    for i in order
      n, o = arms[i]
      t, _, _ = timed!(x, x0, f, g, m, o)
      push!(times[n], t)
    end
  end
  for (n, o) in arms
    t, its, conv = timed!(x, x0, f, g, m, o)
    al = alloc!(x, x0, f, g, m, o)
    gap = indep_gap(ex, x)
    println(io, join((VERSION, design, draw, n, minimum(times[n]), median(times[n]), its, conv, al, kstar, repr(gap)), '\t'))
  end
  flush(io)
  println(stderr, "timed ", design, " draw ", draw)
end
close(io)
