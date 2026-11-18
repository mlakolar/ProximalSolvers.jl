# Runs the sweep tasks (family x precision x design) as separate single-threaded Julia processes,
# NPROC at a time, into RESULTS (one TSV and one log per task; a finished task leaves NAME.done and is
# skipped on a rerun).
# usage: julia driver.jl RESULTS NPROC [smoke]
using Pkg
Pkg.instantiate()
const RESULTS, NPROC = abspath(ARGS[1]), parse(Int, ARGS[2])
const EXTRA = length(ARGS) > 2 ? [ARGS[3]] : String[]
mkpath(RESULTS)
include(joinpath(@__DIR__, "lib378.jl"))     # also precompiles the package once before the workers start
const ND = length(designs())
# largest designs first, so that the long tasks start early
order = sortperm([-prod(size(d[2])) for d in designs()])
tasks = [(fam, T, d) for d in order for fam in ("scalar", "group") for T in ("Float32", "Float64")]
println("Julia ", VERSION, ", ", length(tasks), " tasks, ", NPROC, " at a time, ", Sys.CPU_NAME, ", threads ", Threads.nthreads())
flush(stdout)
t0 = time()
failed = String[]
asyncmap(tasks; ntasks = NPROC) do (fam, T, d)
  name = "$(fam)_$(T)_$(lpad(d, 2, '0'))"
  isfile(joinpath(RESULTS, name * ".done")) && return
  out = joinpath(RESULTS, name * ".tsv")
  cmd = `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(Base.active_project()) $(joinpath(@__DIR__, "sweep378.jl")) $out $fam $T $d $EXTRA`
  ok = success(pipeline(addenv(cmd, "OPENBLAS_NUM_THREADS" => "1"); stdout = joinpath(RESULTS, name * ".log"), stderr = joinpath(RESULTS, name * ".err")))
  if ok
    touch(joinpath(RESULTS, name * ".done"))
  else
    push!(failed, name)
  end
  println(round(Int, time() - t0), " s ", ok ? "done " : "FAILED ", name)
  flush(stdout)
end
println("finished in ", round(Int, time() - t0), " s; failed: ", isempty(failed) ? "none" : join(failed, " "))
isempty(failed) || exit(1)
