include("lib.jl"); include("optB.jl"); include("optC.jl"); include("optC2.jl")
using Logging
include("exp10_common.jl")
which = ARGS[1]
which == "C" && install_C!()
which == "C2" && install_C2!()
which == "B1" && install_B1!()
println("### overlay: ", which)
for T in (Float32, Float64)
  rs = T === Float32 ? (-150:135) : (-1075:1030)
  for (nm, f) in (("y scale 2^sy (X=1)", k -> inst(T, 0, k)), ("X scale 2^sx (y=1)", k -> inst(T, k, 0)), ("joint 2^s (y,X)", k -> inst(T, k, k)))
    println(T, " ", nm, ": ", intervals(runs(nm, T, rs, f), collect(rs)))
  end
end
