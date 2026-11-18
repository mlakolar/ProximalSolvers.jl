# Export the matrix, oracle bounds and the exact start vectors computed under 1.13 to raw binary files for the Julia 1.10 runner.
include(joinpath(@__DIR__, "lib.jl"))
dir = joinpath(@__DIR__, "..", "out", "export"); mkpath(dir)
idx = open(joinpath(dir, "index.tsv"), "w")
println(idx, "id\tn\tp\tlambda\tstarts\tD64\tU64\tD32\tU32\texact64\texact32")
for pr in ORACLE.probs
  n, p = size(pr.X)
  o64, o32 = oracle(pr.id, Float64), oracle(pr.id, Float32)
  open(joinpath(dir, pr.id * ".bin"), "w") do io
    write(io, pr.X); write(io, pr.y)
    for T in (Float64, Float32), sk in pr.starts
      o = oracle(pr.id, T); write(io, Float64.(start_point(pr, sk, o.β)))   # start for the T problem (oracle β of that T)
    end
  end
  println(idx, join([pr.id, n, p, repr(pr.λ), join(pr.starts, ","), repr(o64.D), repr(o64.U), repr(o32.D), repr(o32.U), o64.exactfit, o32.exactfit], '\t'))
end
close(idx)
