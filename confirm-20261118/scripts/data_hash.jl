# Hash of every generated problem (X, y, λ bits), to compare problem generation across Julia versions.
include(joinpath(@__DIR__, "lib.jl"))
using SHA
for p in vcat(dev_problems(), heldout_problems())
  io = IOBuffer(); write(io, p.X); write(io, p.y); write(io, Float64(p.λ))
  println(p.id, "\t", bytes2hex(sha256(take!(io)))[1:16])
end
