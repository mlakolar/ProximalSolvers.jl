# Instantiate the active project offline (Julia ≥ 1.11 reads [sources]; 1.10 uses Manifest-v1.10.toml),
# then run the probe named by ARGS[1] with the remaining arguments.
import Pkg
Pkg.instantiate(; io = devnull)
probe = popfirst!(ARGS)
include(joinpath(@__DIR__, probe))
