# julia run.jl BASELINE_ENV CANDIDATE_ENV OUTPUT_CSV [REPETITIONS]
using Distributed
length(ARGS) >= 3 || error("run.jl BASELINE_ENV CANDIDATE_ENV OUTPUT_CSV [REPETITIONS]")
baseline, candidate, output = abspath.(ARGS[1:3])
repetitions = length(ARGS) > 3 ? parse(Int, ARGS[4]) : 10
repetitions >= 10 || error("at least 10 paired repetitions required")
workers_by_mode = Dict("baseline" => only(addprocs(1; exeflags=`--startup-file=no --project=$baseline`)),
                       "none" => only(addprocs(1; exeflags=`--startup-file=no --project=$candidate`)))
workers_by_mode["diagonal"] = workers_by_mode["none"]
worker_file = joinpath(@__DIR__, "worker.jl")
for w in unique(values(workers_by_mode))
  remotecall_fetch(include, w, worker_file)
end
cases = ("ls-well", "ls-scaled", "logistic-scaled")
solvers = ("pgd", "apg")
modes = ("baseline", "none", "diagonal")
invoke(c, s, m) = remotecall_fetch(Core.eval, workers_by_mode[m], Main, :(trial($c, $s, $m)))
# Compile and warm all measured paths before timing. Workers stay alive.
for c in cases, s in solvers, m in modes
  invoke(c, s, m)
end
mkpath(dirname(output))
open(output, "w") do io
  println(io, "rep,case,solver,mode,seconds,bytes,iterations,gap,converged,objective,backtracks")
  for rep in 1:repetitions, c in cases, s in solvers
    results = Dict()
    order = isodd(rep) ? modes : reverse(modes)
    for m in order
      r = invoke(c, s, m)
      results[m] = r
      println(io, join((rep, c, s, m, r.seconds, r.bytes, r.iterations, r.gap, r.converged, r.objective, r.backtracks), ','))
      flush(io)
    end
    a, b = results["baseline"], results["none"]
    @assert a.coefficients == b.coefficients
    @assert a.iterations == b.iterations && a.backtracks == b.backtracks
    @assert a.gap == b.gap && a.objective == b.objective
    @assert results["diagonal"].converged
  end
end
rmprocs(unique(values(workers_by_mode)))
println("BENCHMARK_VALIDATED: ", repetitions, " interleaved repetitions, baseline/none exact equality")
