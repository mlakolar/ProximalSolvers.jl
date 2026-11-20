# Runs several study processes in parallel, one Julia process each, single-threaded BLAS.
# usage (from the package root): julia --project=. driver.jl OUTDIR [SMOKE=<fixture>] job...
#   job = wl1:<T> | linf-sweep:<T> | linf-traj:<T>
using Pkg
Pkg.instantiate()
const STUDY = @__DIR__
outdir = abspath(ARGS[1])
mkpath(outdir)
jobs = ARGS[2:end]
env = copy(ENV)
env["OPENBLAS_NUM_THREADS"] = "1"
if !isempty(jobs) && startswith(jobs[1], "SMOKE=")
  env["SMOKE"] = split(jobs[1], "=")[2]
  jobs = jobs[2:end]
end
open(joinpath(outdir, "driver.meta"), "w") do io
  println(io, "start ", Libc.strftime("%FT%TZ", time()), " julia ", VERSION, " jobs ", join(jobs, " "),
          " smoke ", get(env, "SMOKE", "-"), " host-cpu ", Sys.cpu_info()[1].model)
end
procs = map(jobs) do j
  kind, T = split(j, ":")
  out = joinpath(outdir, "$(replace(kind, "-" => "_"))_$(T).tsv")
  log = joinpath(outdir, "$(replace(kind, "-" => "_"))_$(T).log")
  args = kind == "wl1" ? [joinpath(STUDY, "wl1.jl"), out, T] :
         [joinpath(STUDY, "linf.jl"), split(kind, "-")[2], out, T]
  cmd = setenv(`$(Base.julia_cmd()) --startup-file=no --project=. $args`, env)
  t0 = time()
  (j, run(pipeline(cmd; stdout = log, stderr = log); wait = false), t0, log)
end
for (j, p, t0, log) in procs
  wait(p)
  msg = "$(j) exit $(p.exitcode) after $(round(time() - t0; digits = 1)) s"
  println(msg)
  open(io -> println(io, msg), joinpath(outdir, "driver.meta"), "a")
  p.exitcode == 0 || println(last(read(log, String), 3000))
end
