# proto_check.jl and the quick timing in one call (two child processes)
using Pkg
Pkg.instantiate()
for (script, extra) in (("proto_check.jl", String[]), ("timing378.jl", ["quick"]))
  run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $(joinpath(@__DIR__, script)) $(ARGS[1]) $extra`)
  println("=====")
end
