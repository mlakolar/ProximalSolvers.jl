# Shared loader for the #515 scripts: the frozen #514 research code (B0, the independent
# MPFR reference and the fixtures) in Main, the #515 profile workloads, and the candidates.
include(joinpath(@__DIR__, "..", "issue-514", "load.jl"))
include(joinpath(@__DIR__, "profile_fixtures.jl"))
include(joinpath(@__DIR__, "b1.jl"))
include(joinpath(@__DIR__, "b2.jl"))
