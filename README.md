# ProximalSolvers.jl PR #318: premerge formal series and checks

Not part of the package. PR: https://github.com/mlakolar/ProximalSolvers.jl/pull/318 (head `39a1dc5e2e1302d5fbed1f168cf6758b145b9777`, base `55c6640`). Decision item 6 of https://github.com/mlakolar/ProximalSolvers.jl/issues/314#issuecomment-6882234445.

- **Code:** PS `39a1dc5` (clean detached clone); ProximalBase `c123d56b`, loaded tree `c2e2ddde` in both environments; harness hash `164fab53cac906e52e5a75e8b93658c1d174c14e` (changed from `69e2fe03…` because the PR edits `benchmark/cases.jl`).
- **Machine:** cluster (Slurm), `oneweek`, exclusive node d18-35 (Xeon E5-2640 v4); one Julia thread and one BLAS thread; Julia 1.10.13 and 1.13.3. Jobs 14246851/14246852 (prebuild), 14247175/14247176 (formal; sequential, no overlap). `cluster/sacct.txt`.
- **Run:** `probes/job314.sh <julia> <tag> <root> formal`: `run.jl` with `PS_SUITE=extended PS_GROUPS=gradient`, repetitions 1–10, then `validate.py` (valid on both) and `summarize.py`. Exit code 2 on every repetition means non-`ok` cases exist (the existing harness-setting cases that miss their targets), which the runner allows.
- **Checks:** `verify-pr318.py ../run-20261115T0100-issue314-post296 .` gives `verify-pr318.md`.
- **Codex review:** `codex-brief-r1.md`, `codex-review-r1.md` (gpt-6.1-sol, high; VERDICT: PASS).
- `SHA256SUMS`: checksums of every other file.
