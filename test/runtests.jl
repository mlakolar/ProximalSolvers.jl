using ProximalSolvers
using ParallelTestRunner

# Every regular test file runs in a fresh module on one of several worker processes
# (ParallelTestRunner), which seeds the global random generator with `Random.seed!(1)` before
# each file. test/tiers.toml gives each file one of the cumulative tiers quick, standard and
# full (test/tiers.jl). Without `--tier`, every file runs (full).
#
#   --tier=quick|standard|full   the files of a tier and the tiers before it
#   --extra=a,b                  these files as well, whatever their tier
#   --list                       the files and their tiers
#   --jobs=N (or PTR_NUM_JOBS)   the number of workers; --verbose adds per-file compile times
#   names                        only the selected files whose names start with one of them
#
# For example `julia scripts/test.jl --tier=quick --extra=workspaces --jobs=4`, or
# `Pkg.test(; test_args=["--tier=quick"])`.
include(joinpath(@__DIR__, "tiers.jl"))
using .TestTiers

testsuite = find_tests(@__DIR__)
manifest = TestTiers.load(joinpath(@__DIR__, "tiers.toml"))
# An unclassified, missing or duplicated file stops every run before any test starts.
TestTiers.check(manifest, keys(testsuite))
# Drop the helpers and the environments of their own (oracles/).
filter!(((name, _),) -> haskey(manifest.tier, name), testsuite)

args = parse_args(ARGS; custom = ["tier", "extra"])

function option_value(flag, example)
  value = args.custom[flag]
  value === nothing && return nothing
  v = something(value)
  (v === nothing || isempty(v)) && error("--$flag needs a value, for example --$flag=$example")
  return String(v)
end

tier = something(option_value("tier", "quick"), "full")
TestTiers.rank(tier) > 0 || error("unknown test tier `$tier`; the tiers are $(join(TIERS, ", "))")
extra = filter(!isempty, String.(strip.(split(something(option_value("extra", "workspaces,admm"), ""), ','))))
for name in extra
  haskey(testsuite, name) || error("--extra: no test file `$name`; `julia scripts/test.jl --list` shows the names")
end

if args.list !== nothing
  println("Test files by tier (each tier also runs the tiers above it):")
  for t in TIERS, name in TestTiers.select(manifest, t)
    manifest.tier[name] == t && println("  ", rpad(t, 9), name)
  end
  exit(0)
end

selected = union(TestTiers.select(manifest, tier), extra)
filter!(((name, _),) -> name in selected, testsuite)
# Names after the options select among those files; a selection that matches nothing is an
# error, not a run of zero tests that passes.
filter_tests!(testsuite, args)
isempty(testsuite) && error("no test file matches the selection: $(join(ARGS, " "))")

label = "tier $tier"
isempty(extra) || (label *= " with " * join(extra, ", "))
isempty(args.positionals) || (label *= ", filtered by " * join(args.positionals, " "))
commit = haskey(ENV, "GITHUB_SHA") ? ", commit $(ENV["GITHUB_SHA"])" : ""
cpu = "$(strip(first(Sys.cpu_info()).model)), $(Sys.CPU_THREADS) threads"
println("ProximalSolvers tests: $label: $(length(testsuite)) files; Julia $VERSION on $(Sys.MACHINE) ($cpu)$commit, ",
        "check-bounds ", ("default", "yes", "no")[Base.JLOptions().check_bounds + 1])
println("  ", join(sort!(collect(keys(testsuite))), " "))

runtests(ProximalSolvers, args; testsuite)
