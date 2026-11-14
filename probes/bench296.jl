# Driver for the #296 paired benchmark: builds a probe environment (PS from this checkout, PB at the
# pinned revision, SHA, Statistics), then runs paired296.jl with one Julia thread.
#   julia bench296.jl <rounds> <groups...>
using Pkg, TOML
root = normpath(joinpath(@__DIR__, "..", ".."))
env = joinpath(@__DIR__, "benchenv-$(VERSION.major).$(VERSION.minor)")
src = TOML.parsefile(joinpath(root, "Project.toml"))["sources"]["ProximalBase"]
Pkg.activate(env)
Pkg.add(url = src["url"], rev = src["rev"])
Pkg.develop(path = root)
Pkg.add(["SHA", "Statistics", "PrecompileTools", "Printf", "Random", "SparseArrays", "LinearAlgebra"])
Pkg.instantiate(); Pkg.precompile()
b = joinpath(root, ".codex-orchestrator", "bench")
println("node: ", gethostname() |> h -> "(redacted)", " cpu ", Sys.CPU_NAME, " nthreads(cpu) ", Sys.CPU_THREADS)
println("lscpu: ", read(pipeline(`lscpu`, `grep 'Model name'`), String))
cmd = `$(Base.julia_cmd()) --startup-file=no -t 1 --project=$env $(joinpath(@__DIR__, "paired296.jl")) $(joinpath(b, "base", "src")) $(joinpath(b, "fgr", "src")) $(joinpath(root, "src")) $(ARGS[1]) $(joinpath(root, "benchmark")) $(ARGS[2:end])`
withenv("OPENBLAS_NUM_THREADS" => "1", "OMP_NUM_THREADS" => "1") do
  run(cmd)
end
