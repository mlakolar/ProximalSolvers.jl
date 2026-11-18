include("lib.jl"); include("optB.jl")
using Logging
# E10b: one-axis scans in steps of one binade: y scale 2^sy (X fixed, scale 1), X scale 2^sx (y fixed, level 0.3 lambda_max),
# and joint (y, X) -> 2^s (y, X) with the level rescaled. Outcome under A (current) and under B1 (overlay).
include("exp10_common.jl")
axes_report("A: current code")
install_B1!()
axes_report("B1: overlay (offrange and band replaced by refusals)")
