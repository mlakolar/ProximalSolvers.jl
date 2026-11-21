# Issue #320 Stage 2 evidence (research only)

Widened lasso gap evaluator (candidate C), hypothetical gap stopping on recorded trajectories,
cost measurements, and the design-only stop-reason study (candidate A). No ProximalSolvers source
was changed. Base: ProximalSolvers `49d0242e5cbe93e779bab5ac1e7674d6daf03aaf`; ProximalBase
`bc9e888d09e5fc3c3feb35905dd7a14e70657fa5` (manifests); Julia 1.10.13 and 1.13.4.

- `report/report.md`: the report as posted on issue #320.
- `report/preregistration.md` (+ `.sha256`): fixed before the cluster runs; the sha256 file also
  pins the five probe scripts as they were run. `s2callback.jl` and `analyze.py` were written
  afterwards.
- `report/analysis.txt`: full output of `python3 -I scripts/analyze.py results/cluster <phase0>`
  (section 0 needs the Phase 0 archive, branch `archive/issue-320-evidence` at `fb8fb87d`).
- `scripts/`: `gapeval.jl` (prototype), `s2common.jl`, `s2traj.jl`, `s2degen.jl`, `s2time.jl`,
  `s2callback.jl`, `analyze.py`. Run each as `julia --project=<ProximalSolvers checkout> <script> ...`
  with the checkout at the base commit; the scripts expect to sit at
  `<checkout>/.codex-orchestrator/runs/<run>/scripts/` so that they find `<checkout>/benchmark`
  (or set `S2_HARNESS`).
- `results/cluster/<julia>/`: cluster (Slurm) outputs, with `logs/` and the cluster-side
  `results320s2.sha256` (computed on the cluster before scrubbing, so it does not match the scrubbed logs and provenance files); `results/local/`: the callback check and a local trajectory run (i5-13600K,
  Julia 1.13.4).

Absolute paths and node names are replaced by placeholders (`<cluster-run>`, `<local-projects>`,
`<local-depot>`, `<local-tmp>`, `<node>`). `SHA256SUMS` covers every other file in this tree.
