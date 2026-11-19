# Exact text copies of the oracle records (Julia 1.10 cannot read 1.13 serialization): one file per
# record, lines: relwidth, exactfit, Ubig, Dbig (256-bit decimal strings), then β (Float64 repr).
using Serialization
setprecision(BigFloat, 256)
dir = joinpath(@__DIR__, "..", "out", "oracle")
for f in readdir(dir)
  endswith(f, ".jls") || continue
  r = deserialize(joinpath(dir, f))
  open(joinpath(dir, replace(f, ".jls" => ".txt")), "w") do io
    println(io, repr(r.relwidth)); println(io, r.exactfit); println(io, string(r.Ubig)); println(io, string(r.Dbig))
    for b in r.β
      println(io, repr(b))
    end
  end
  # round-trip check
  l = readlines(joinpath(dir, replace(f, ".jls" => ".txt")))
  @assert parse(BigFloat, l[3]) == r.Ubig && parse(BigFloat, l[4]) == r.Dbig && parse.(Float64, l[5:end]) == r.β
end
println("ok")
