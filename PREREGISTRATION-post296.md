# #314 post-#296 rerun: addendum (frozen before any cluster run at the new revision)

Written 2026-11-15T01:10Z, after #296 merged (PR #315, `55c66400f4800135b4011da839a561a867b1deb8`), and before
any formal or `conf` problem was solved at that revision. Data seen before writing: one local smoke test only
(the 20 harness cases, draw 1, one timing round, Julia 1.13.4 on a workstation; `local/`, not used for claims).

Authority: maintainer ruling on #314 (issuecomment-6882234445), item 2.

## Unchanged from the frozen preregistration (`run-20261114T1800-issue314/PREREGISTRATION.md`, sha256 in its `.sha256`)

- Profiles D, H, S, P1, P2 and the A/A arm, problems, seeds (`issue314/conf`, draws 1–6; harness draws 1–10),
  certificate (harness `certify`), targets (Float64 `1e-8`, Float32 `1e-5`), definitions (pass, false success,
  reachable, time to target, return time), timing protocol (5 interleaved rounds, one Julia and one BLAS thread,
  exclusive `oneweek` Xeon E5-2640 v4 nodes), Julia 1.10.13 and 1.13.3.
- `probes/probe314.jl` is byte-identical to the frozen run's fixed probe (sha256 `be23663d…`). `job314.sh` changes
  only `PSREV` (and the comment naming it). `agg314.py` is unchanged.
- Code: PS `55c6640` (clean detached clone); PB pin `c123d56b` (tree `c2e2ddde`), unchanged by #315; harness
  files (`benchmark/`) unchanged by #315 (harness hash `69e2fe03…`).

## What changed in the solver (for interpretation only)

#315 adds a stationarity check that must pass before any stop counts as `converged`
(`‖G‖∞ < max(gradtol, 64 eps(T)) · max(λ, λmax)`), makes the objective test relative (`|F−F'|/|F|`), and makes the
gradient test scale-aware. For APG, each check evaluates one gradient and is counted in `grad_calls`, so APG
`products` include it. For Float32, P2's `gradtol = 1e-7` is below `64 eps(Float32) ≈ 7.6e-6`, so the check uses
`7.6e-6` there.

## Rules applied at the new revision

1. **Float64 P2 (the only candidate the ruling authorizes)**, separately for PGD and APG, on `conf` at both
   Julia versions: no false success, and every reachable problem passes; any exception is reported individually
   for the maintainer and not waived. If either fails, P2 is not implemented and the result goes back to the
   maintainer. No profile is changed or tuned.
2. **Phase A**: formal `run.jl` (extended/gradient, draws 1–10) and the 20-case probe, reported as before,
   with the probe-H vs formal-record cross-check.
3. **Float32**: reassessment only, reported descriptively (P1, P2 and S false successes, misses, stop reasons,
   S/APG maxiter rate). No Float32 recommendation is made from this rerun; the ruling's NO-GO stands.
4. **Pre/post comparison**: every table is reported side by side with the frozen `fad90d9` results; stop reason
   and certificate outcome are kept separate.
