# #307 compile/latency driver for one arm and one Julia version.
#   JULIA_DEPOT_PATH=<private depot>:<shared depots...> \
#   julia --startup-file=no --project=ENV latency_driver.jl ARM [REPS=5] [REPS_PRE=3] [REPS_LOAD=REPS] [REP0=0] [META=1]
# ENV is an environment in which `using ProximalSolvers, ProximalBase` loads the arm's checkout
# and its pinned ProximalBase (e.g. the benchmark environment made by benchmark/setup.jl).
# The first entry of DEPOT_PATH must be private to this arm and version: the driver deletes the
# ProximalSolvers and ProximalBase caches there to time precompilation, and checks that the
# caches the children load live there.
# Output lines (stdout), all prefixed "CSV,":
#   CSV,meta,<key>,<value>
#   CSV,precompile,arm,version,rep,pb_s,ps_s,pb_cache_bytes,ps_cache_bytes
#   CSV,load,arm,version,rep,load_s
#   CSV,first,arm,version,solver,T,order,rep,load_ns,load_compile_ns,fixture_ns,fixture_compile_ns,
#       {kind,first_ns,first_compile_ns,second_ns,second_compile_ns,minimum,repeat_equal}×2,ps_cache,pb_cache
using Random
const ARM = ARGS[1]
const OPTS = Dict(split(a, '='; limit = 2) for a in ARGS[2:end] if occursin('=', a))
const REPS = parse(Int, get(OPTS, "REPS", "5"))
const REPS_PRE = parse(Int, get(OPTS, "REPS_PRE", "3"))
const REPS_LOAD = parse(Int, get(OPTS, "REPS_LOAD", string(REPS)))
const REP0 = parse(Int, get(OPTS, "REP0", "0"))   # rep labels are REP0+1..REP0+REPS (interleaved rounds)
const META = get(OPTS, "META", "1") == "1"
const CHILD = joinpath(@__DIR__, "latency_child.jl")
const JL = Base.julia_cmd()
const PROJECT = dirname(Base.active_project())
const DEPOT1 = first(DEPOT_PATH)
const VDIR = "v$(VERSION.major).$(VERSION.minor)"
meta(k, v) = (println("CSV,meta,", k, ",", v); flush(stdout))
meta("arm", ARM); meta("version", VERSION); meta("cpu", Sys.cpu_info()[1].model)
meta("threads", Sys.CPU_THREADS); meta("slurm_job", get(ENV, JOB_ID_VARIABLE, "-"))  # the scheduler's job-ID variable; renamed for the archive
meta("project", PROJECT); meta("depot1", DEPOT1)
meta("loadavg", join(Sys.loadavg(), " "))

env_cmd(c) = addenv(c, "OPENBLAS_NUM_THREADS" => "1", "JULIA_NUM_THREADS" => "1",
                    "JULIA_PKG_OFFLINE" => "true")
jl(code) = env_cmd(`$JL --startup-file=no --project=$PROJECT -e $code`)
dirsize(d) = isdir(d) ? sum((filesize(joinpath(r, f)) for (r, _, fs) in walkdir(d) for f in fs); init = 0) : 0
cachedir(name) = joinpath(DEPOT1, "compiled", VDIR, name)

# Provenance of what loads
META && print(read(jl("""
using ProximalSolvers, ProximalBase
for m in (ProximalSolvers, ProximalBase)
  id = Base.PkgId(m)
  println("CSV,meta,", nameof(m), "_path,", pkgdir(m))
  println("CSV,meta,", nameof(m), "_cache,", Base.pkgorigins[id].cachepath)
end
import Pkg
for (u, d) in Pkg.dependencies()
  d.name == "ProximalBase" && println("CSV,meta,ProximalBase_source,", d.source, " ", d.git_revision, " ", d.tree_hash)
end
"""), String))

# Precompile time: PB then PS, from caches removed in the private depot only
for rep in 1:REPS_PRE
  rm(cachedir("ProximalSolvers"); force = true, recursive = true)
  rm(cachedir("ProximalBase"); force = true, recursive = true)
  pb = parse(Float64, strip(read(jl("t = time(); Base.compilecache(Base.identify_package(\"ProximalBase\")); print(time() - t)"), String)))
  ps = parse(Float64, strip(read(jl("t = time(); Base.compilecache(Base.identify_package(\"ProximalSolvers\")); print(time() - t)"), String)))
  println("CSV,precompile,", join((ARM, VERSION, rep, pb, ps, dirsize(cachedir("ProximalBase")), dirsize(cachedir("ProximalSolvers"))), ","))
  flush(stdout)
end
# leave valid caches in place for the timing runs (one plain load also checks they are used)
run(pipeline(jl("using ProximalSolvers, ProximalBase"); stdout = devnull))

for rep in REP0 .+ (1:REPS_LOAD)
  t = parse(Float64, strip(read(jl("t = time(); using ProximalSolvers, ProximalBase; print(time() - t)"), String)))
  println("CSV,load,", join((ARM, VERSION, rep, t), ","))
  flush(stdout)
end

tasks = [(s, T, o, rep) for rep in REP0 .+ (1:REPS) for s in ("cd", "pg", "apg") for T in ("Float32", "Float64")
                        for o in ("raw-scaled", "scaled-raw")]
shuffle!(Xoshiro(307 + REP0), tasks)
for (s, T, o, rep) in tasks
  out = read(env_cmd(`$JL --startup-file=no --project=$PROJECT $CHILD $ARM $s $T $o $rep`), String)
  line = only(filter(startswith("CSV,first,"), split(out, '\n')))
  occursin(DEPOT1, line) || error("a cache outside the private depot was loaded: $line")
  println(line)
  flush(stdout)
end
meta("loadavg_end", join(Sys.loadavg(), " "))
println("CSV,done")
