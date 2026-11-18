# Pilot: the sweep tasks of the ten #352 fixtures only (designs 1 to 10), NPROC at a time, into RESULTS.
using Pkg
Pkg.instantiate()
const RESULTS, NPROC = abspath(ARGS[1]), parse(Int, ARGS[2])
mkpath(RESULTS)
tasks = [(fam, T, d) for d in 1:10 for fam in ("scalar", "group") for T in ("Float32", "Float64")]
t0 = time()
asyncmap(tasks; ntasks = NPROC) do (fam, T, d)
  name = "$(fam)_$(T)_$(lpad(d, 2, '0'))"
  isfile(joinpath(RESULTS, name * ".done")) && return
  cmd = `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(Base.active_project()) $(joinpath(@__DIR__, "sweep378.jl")) $(joinpath(RESULTS, name * ".tsv")) $fam $T $d`
  ok = success(pipeline(addenv(cmd, "OPENBLAS_NUM_THREADS" => "1"); stdout = joinpath(RESULTS, name * ".log"), stderr = joinpath(RESULTS, name * ".err")))
  ok && touch(joinpath(RESULTS, name * ".done"))
  println(round(Int, time() - t0), " s ", ok ? "done " : "FAILED ", name, " ", Sys.CPU_NAME)
  flush(stdout)
end
run(`sh -c "gzip -f $RESULTS/*.tsv"`)
println("pilot finished in ", round(Int, time() - t0), " s")
