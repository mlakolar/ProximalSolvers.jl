You are the independent terminal reviewer for ProximalSolvers.jl PR #318 (https://github.com/mlakolar/ProximalSolvers.jl/pull/318), head 39a1dc5e2e1302d5fbed1f168cf6758b145b9777, base master 55c66400f4800135b4011da839a561a867b1deb8. This checkout is at the head. Review `git diff 55c66400f4800135b4011da839a561a867b1deb8 HEAD` (three files: benchmark/cases.jl, benchmark/HARNESS.md, test/benchmark_formal.jl).

Acceptance checklist (the maintainer's decision, https://github.com/mlakolar/ProximalSolvers.jl/issues/314#issuecomment-6882234445, item 5; read it with `gh issue view 314 --comments` if useful):
- Adds exactly 10 IDs `gradient/<design>/{pg,apg}/acc-{dense,warm-dense}-f64/call` in benchmark/cases.jl with `ProximalOptions(maxiter=10_000, ftol=0, xtol=1e-14, gradtol=1e-10, allow_f_increases=true)`; Float64 only; no Float32 acc- cases.
- The 20 existing gradient IDs and their options, the record-only default cases (`*/R/call`), certificates, targets, statuses, benchmark/run.jl, validate.py, compare.py and the Stage 2A/2B campaign definitions and frozen evidence are unchanged.
- benchmark/HARNESS.md gets only a concise mode explanation: `acc-` is a setting, not a converged=true certification; an accurate stagnated/maxiter solve is ok only via the certificate.
- test/benchmark_formal.jl gets only the necessary count tests.
- No stop-reason or counter fields, no new runner, no CI runtime added, no generic framework.

Check correctness: that the 10 new cases construct the same inputs/data hashes as the corresponding existing f64 cases (same draw, warm start), use the intended options (and that existing cases still use `benchmark_options(residual = true)`), that IDs/suite/target/requirements are right, that the default-keyword change to `core_case_state` cannot alter existing cases, that the CI test suite does not now construct or solve the extended cases, and that HARNESS.md text is accurate (including against the post-#296 solver semantics in src/types.jl and docs/src/numerics.md). Look for anything else that would make the PR wrong.

You may run Julia. Command (Julia 1.13 environment with the harness deps prebuilt; package developed from this checkout):
  JULIA_DEPOT_PATH=$PWD/.codex-orchestrator/depot-codex-1.13:$HOME/.julia: timeout 600 julia +release --startup-file=no --heap-size-hint=4G --project=$PWD/.codex-orchestrator/env-113 <script>
Examples: the harness runner with `PS_SUITE=extended PS_GROUPS=gradient PS_CASES='gradient/*/*/acc-*' PS_REPETITION=1 PS_OUTPUT=$PWD/.codex-orchestrator/out benchmark/run.jl`, or `PS_LIST=true`. For the package test file: `JULIA_DEPOT_PATH=... timeout 900 julia +release --startup-file=no --project=$PWD -e 'using Pkg; Pkg.test(test_args=["benchmark_formal"])'`. Put any probe scripts and outputs under .codex-orchestrator/. Do not edit tracked files, do not run git commands that write, do not push or post to GitHub.

Write your review to .codex-orchestrator/review-r1.md: a verdict line `VERDICT: PASS` or `VERDICT: REQUEST_CHANGES`, then numbered findings (severity, file:line, the problem, a concrete fix), then what you checked and the commands you ran with results.
