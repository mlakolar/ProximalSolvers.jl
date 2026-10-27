# Release follow-up measurements

These scripts support the performance issues opened during PR #102. They are
bounded exploratory probes, not a calibrated benchmark campaign.

Use an isolated standard Julia environment containing the selected
ProximalSolvers source, ProximalBase and Statistics. Run, for example:

```sh
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 julia --project=ENV benchmark/release_candidate/reproduce.jl newton
```

The other families are `sqrt`, `pg`, `apg`, `monotone`, `active`, `cd` and
`admm`. The script warms a complete call and reports nine observations,
allocation bytes, convergence, objective and a unit proximal residual. It
includes result construction and per-call solver setup, but excludes data
construction and compilation. Loss-owned caches and ADMM factorization are
warm. It resets coefficients before each solve; RNG state advances between CD
fits. Save the complete output and resolved Manifest with exact source commits.

For decisions, use dedicated hardware with a fixed CPU/power policy, pinned
Julia and dependencies, one Julia and BLAS thread, interleaved paired runs and
multiple independent processes. Establish a common external accuracy target
before comparing times; equal defaults or iteration counts do not establish
matched accuracy. Report failed targets separately from time to convergence.
Separate initialization, warmed `solve!`, result construction and allocations.
Report distributions and uncertainty, including GC and scheduling effects.

Earlier retained probes are in `docs/audit/20261026/performance.jl`,
`performance-batched.jl` and `allocation-stages.jl`. Those files and their
results describe historical source editions and are intentionally unchanged.
