# Run the package tests (test/runtests.jl) with the options CI uses, forwarding the
# arguments to the test runner:
#
#   julia scripts/test.jl                  # every test file, workers chosen by the runner
#   julia scripts/test.jl --jobs=4         # four worker processes (or PTR_NUM_JOBS=4)
#   julia scripts/test.jl --jobs=1 admm    # one worker, only files starting with `admm`
#   julia scripts/test.jl --list           # the test files
#
# JULIA_TEST_COVERAGE=true collects coverage; JULIA_TEST_DEPWARN sets --depwarn (default yes).
using Pkg

depwarn = get(ENV, "JULIA_TEST_DEPWARN", "yes")
depwarn in ("yes", "no", "error") || error("invalid JULIA_TEST_DEPWARN")
coverage = get(ENV, "JULIA_TEST_COVERAGE", "false") == "true"

Pkg.activate(dirname(@__DIR__))
Pkg.test(; coverage, julia_args=`--startup-file=no --check-bounds=yes --depwarn=$depwarn`, test_args=ARGS)
