using ProximalSolvers
using ParallelTestRunner

# Every regular test file. Each runs in a fresh module on one of several worker processes
# (ParallelTestRunner), which seeds the global random generator with `Random.seed!(1)`
# before each file. `--jobs=N` or `PTR_NUM_JOBS` sets the number of workers, `--verbose`
# prints per-file init and (Julia 1.11+) compile times, and names after the options select files
# (`julia --project -e 'using Pkg; Pkg.test(; test_args=["--jobs=2", "admm"])'`).
const TESTS = [
  "active_set", "admm", "apg_numerical_failure", "aqua", "audit_regressions", "box_paths",
  "call_limits", "convolution_gap", "coordinate_descent", "diagonal_preconditioner",
  "duality_gap", "examples", "flat_coordinates", "float32_certificates", "gap_stopping",
  "generic_newton", "glm", "group_curvature", "group_lasso", "group_momentum",
  "group_penalties", "image_models", "linesearch", "lla_paths", "low_rank",
  "mixed_precision", "mixed_precision_extended", "multiresponse", "naming",
  "newton_nonconvex", "nonconvex", "nonconvex_blocks", "nonconvex_penalties",
  "path_snapshots", "primal_dual", "product_space", "prox_solvers", "quic", "refit_cache",
  "slope", "slope_hybrid", "sparse_group_paths", "sparse_x", "sqrt_certificates",
  "structured_quadratics", "symmetric_penalties", "symmetric_penalty_combinations",
  "workspaces",
]
# Included by test files, not run on their own.
const HELPERS = ["symmetric_penalty_helpers"]

testsuite = find_tests(@__DIR__)
# test/oracles has an environment of its own and runs separately (test/oracles/README.md).
filter!(((name, _),) -> !startswith(name, "oracles/"), testsuite)
# A file that is neither listed nor a helper, or a listed file that is gone, stops the run
# before any test starts, so that no test silently drops out.
unlisted = sort!(setdiff(collect(keys(testsuite)), TESTS, HELPERS))
missing_files = sort!(setdiff(TESTS ∪ HELPERS, keys(testsuite)))
isempty(unlisted) || error("test files not listed in test/runtests.jl: $(join(unlisted, ", "))")
isempty(missing_files) || error("listed test files not found: $(join(missing_files, ", "))")
foreach(name -> delete!(testsuite, name), HELPERS)

args = parse_args(ARGS)
# Names after the options select files; a selection that matches nothing is an error, not a
# run of zero tests that passes.
filter_tests!(testsuite, args)
isempty(testsuite) && error("no test file matches the selection: $(join(ARGS, " "))")
if args.list === nothing
  commit = haskey(ENV, "GITHUB_SHA") ? ", commit $(ENV["GITHUB_SHA"])" : ""
  cpu = "$(strip(first(Sys.cpu_info()).model)), $(Sys.CPU_THREADS) threads"
  println("ProximalSolvers tests: Julia $VERSION on $(Sys.MACHINE) ($cpu)$commit, ",
          "check-bounds $(Base.JLOptions().check_bounds)")
end

runtests(ProximalSolvers, args; testsuite)
