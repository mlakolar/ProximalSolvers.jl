# Bitwise export of the generated problems (Julia 1.13), so that the 1.10 cross-check solves the same data:
# out/data/<id>.bin = n, p (Int64), X (column major), y, λ (Float64), little endian.
include(joinpath(@__DIR__, "lib.jl"))
dir = joinpath(HERE, "..", "out", "data"); mkpath(dir)
for p in vcat(dev_problems(), heldout_problems())
  open(joinpath(dir, "$(p.id).bin"), "w") do io
    write(io, Int64(size(p.X, 1)), Int64(size(p.X, 2))); write(io, Float64.(p.X)); write(io, Float64.(p.y)); write(io, Float64(p.λ))
  end
end
println("ok")
