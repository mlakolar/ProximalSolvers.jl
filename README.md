# ProximalSolvers.jl #314: post-#296 rerun and pre/post comparison

Not part of the package; nothing here is built or tested. Issue: https://github.com/mlakolar/ProximalSolvers.jl/issues/314.
This is a new baseline, kept separate from the frozen pre-#296 archive `archive/issue-314-evidence` @ `f2c7f94`,
which it does not modify.

- **Code:**
  - PS `55c66400f4800135b4011da839a561a867b1deb8`, a clean detached clone; it is master after #296 (PR #315) merged.
  - ProximalBase pin `c123d56ba1948e36a8fdbf183a9eea396a16e0d5`; the loaded git-tree is `c2e2ddde114a1e7800358595193ee0869830180d` in both environments (`cluster/setup-*.log`, `cluster/env-*-Manifest.toml`). #315 did not change the pin.
  - Harness hash `69e2fe03d14ff60dd3eb970b9f4b42132809fb06`, the same as the pre-#296 run (#315 did not change `benchmark/`).
- **Machine:** cluster (Slurm), `oneweek` partition, exclusive node d18-35 (Intel Xeon E5-2640 v4). One Julia thread and one BLAS thread. Julia 1.10.13 (`j110`) and 1.13.3 (`j113`).
  - Jobs 14246651 and 14246652 (environment prebuild); 14246669 and 14246670 (formal); 14246671 and 14246672 (`conf`). They ran one after another on the same node, with no overlap. See `cluster/sacct.txt`.
- **Protocol:** `PREREGISTRATION-post296.md` (frozen before any run at `55c6640`; checksums in `PREREGISTRATION-post296.sha256`). It keeps the profiles, problems, seeds, targets, certificate and rules of the frozen preregistration. `probes/probe314.jl` is byte-identical to the pre-#296 fixed probe; `job314.sh` differs only in `PSREV`.

## Files

- `phaseA.md`: the formal `run.jl` records (extended/gradient, draws 1–10) and the 20-case probe at `55c6640`, produced by `agg314.py phaseA`.
- `conf-j110.md`, `conf-j113.md`: the confirmation set at `55c6640` (`agg314.py profiles`).
- `compare-pre-post.md`: the per-profile comparison with the pre-#296 run (`probes/compare314.py <pre run dir> <this dir>`). The stop reason (converged, stagnated, maxiter) and the certificate outcome (pass, false success) are kept in separate columns. Return-time ratios compare two runs on different nodes and days, so they are indicative only; the A/A control is within each run.
- `cluster/`: all job outputs, validation, summaries, logs and environment files.
- `local/`: a workstation smoke test (draw 1, one timing round); not used for any claim.
- `SHA256SUMS`: checksums of every other file.
