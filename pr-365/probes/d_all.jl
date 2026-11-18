# D: all (type, n, part) combinations of exp_d.jl in one process. args: [part list, default 1,2,3]
include(joinpath(@__DIR__, "r1lib.jl"))
parts = length(ARGS) >= 1 ? parse.(Int, split(ARGS[1], ',')) : [1, 2, 3]
for t in ("32", "64"), n in (1, 2, 3, 5, 30), part in parts
  (part == 3 && n == 1) && continue
  m = Module(:DRun)
  Core.eval(m, :(const DRIVER = true)); Core.eval(m, :(const ARGS = $([t, string(n), string(part)])))
  Base.include(m, joinpath(@__DIR__, "exp_d.jl"))
  flush(stdout)
end
