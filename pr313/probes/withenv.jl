# Instantiates the tree's root environment (needed on Julia >= 1.11, which takes ProximalBase from
# [sources] and has no committed manifest), then runs the probe ARGS[1] with the remaining ARGS.
using Pkg
Pkg.instantiate()
const PROBE = abspath(ARGS[1])
deleteat!(ARGS, 1)
include(PROBE)
