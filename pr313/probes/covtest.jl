# Runs scripts/test.jl (the CI runner) with coverage instrumentation, as CI's full tier does.
# Arguments are forwarded, for example: --tier=standard --jobs=4 cd_numerics
ENV["JULIA_TEST_COVERAGE"] = "true"
include(joinpath(@__DIR__, "..", "scripts", "test.jl"))
