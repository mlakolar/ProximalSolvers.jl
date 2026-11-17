# Independent derivation of the harness constants that migration_compare.py binds the metadata keys `capabilities` and
# `deferred_cases` to (TRUSTED_HARNESS, #333): CAPABILITIES and the number of deferred cases per suite and group, from
# the pinned benchmark files, never from the records of a run.
#
#     git archive 9f86a808bfac968f5421b9efeb6d0aecd7c1c775 benchmark | tar -x -C DIR
#     julia --startup-file=no derive_harness_constants.jl DIR/benchmark
#
# problems.jl, certificates.jl and cases.jl are loaded with empty stand-ins for ProximalSolvers and ProximalBase:
# `build_catalog` constructs no solver and no data (its docstring), so no package is needed. The output for the
# harness of 164fab53 (9f86a808) is the table of TRUSTED_HARNESS: capabilities as run.jl:232 joins them, and
# per-group deferred counts (quick: 58 over all groups, extended: 100; the groups of a run add).
module ProximalSolvers end
module ProximalBase end
using LinearAlgebra, SparseArrays, Random, Statistics, Printf, TOML, SHA
bench = abspath(ARGS[1])
include(joinpath(bench, "problems.jl"))
include(joinpath(bench, "certificates.jl"))
include(joinpath(bench, "cases.jl"))
println("capabilities=", join(sort!(collect(CAPABILITIES)), ','))
for suite in ("quick", "extended")
    println("suite=$suite groups=ALL deferred=", length(build_catalog(suite, collect(CASE_GROUPS); deferred = true)))
    for group in sort(collect(CASE_GROUPS))
        println("suite=$suite groups=$group deferred=", length(build_catalog(suite, [group]; deferred = true)))
    end
end
