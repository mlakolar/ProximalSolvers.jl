# ttfx.jl: time to first solve! with default options, per solver and T, in fresh processes after precompilation.
include(joinpath(@__DIR__, "common.jl"))
ensure_env()
using ProximalBase: LeastSquaresLoss, NormL1
using ProximalSolvers
env_header()
const REPS = 5
rows = Dict{Tuple{String,String},Vector{NTuple{4,Float64}}}()
for solver in ("pgd", "apg"), T in ("Float32", "Float64"), rep in 1:REPS
  cmd = `$(Base.julia_cmd()) --project=$(dirname(Base.active_project())) --startup-file=no $(joinpath(@__DIR__, "ttfx_child.jl")) $solver $T`
  out = read(cmd, String)
  line = first(filter(l -> startswith(l, "TTFX_ROW"), split(out, '\n')))
  println(line)
  vals = Dict(m.captures[1] => parse(Float64, m.captures[2]) for m in eachmatch(r"(load|setup|first_solve|second_solve)=([0-9.eE+-]+)", line))
  push!(get!(rows, (solver, T), NTuple{4,Float64}[]), (vals["load"], vals["setup"], vals["first_solve"], vals["second_solve"]))
end
median(v) = (s = sort(collect(v)); n = length(s); isodd(n) ? s[(n + 1) ÷ 2] : (s[n ÷ 2] + s[n ÷ 2 + 1]) / 2)
println("TTFX summary (median over $REPS fresh processes; seconds): solver | T | load | setup | first solve! | second solve! | min first solve!")
for solver in ("pgd", "apg"), T in ("Float32", "Float64")
  v = rows[(solver, T)]
  col(i) = median(getindex.(v, i))
  println("TTFX ", solver, " | ", T, " | ", round(col(1); digits = 3), " | ", round(col(2); digits = 4), " | ", round(col(3); digits = 4), " | ",
          round(col(4); digits = 5), " | ", round(minimum(getindex.(v, 3)); digits = 4))
end
println("TTFX DONE")
