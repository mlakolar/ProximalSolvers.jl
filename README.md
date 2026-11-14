# ProximalSolvers.jl #308 Phase 0 evidence (Float32 PGD numerical stagnation)

Archive of the research behind the decision memo on issue #308
(https://github.com/mlakolar/ProximalSolvers.jl/issues/308#issuecomment-6867784097).
Not part of the package; nothing here is built or tested.

- Base: ProximalSolvers.jl `337a6acd3fd7743811a8becde85bf9595e1bd2aa` (PR #287 merged); ProximalBase pinned at
  `c123d56ba1948e36a8fdbf183a9eea396a16e0d5` (git-tree-sha1 `c2e2ddde114a1e7800358595193ee0869830180d`, checked in each
  environment's manifest).
- Cluster (Slurm), exclusive use of one node per Julia version, Intel Xeon E5-2640 v4, one Julia thread and one BLAS
  thread; Julia 1.10.13 (job 14217484) and 1.13.3 (job 14217485). Local exploration used the same scripts with Julia
  1.13.3 on an Intel Core i5-13600K; the 1.13 counterexample results were identical on both machines.

## Files

- `candidate-R-B.diff`: the disposable candidate rule on `337a6acd` (not merged; the implementation is PR #312).
- Scripts: `setup308.jl` (per-version environment with the pinned ProximalBase), `job308.sh` (one job per Julia
  version), `trace308.jl` (per-iteration diagnostics of the unchanged solver: stall, trials, L, mode, objective,
  residual, step in ulps, exact Float64 objective, independent relative gap, exact state recurrence), `matrix308.jl`
  (real-code matrix, base and candidate, strict and harness settings, Float32 and Float64), `cex308.jl`
  (counterexample battery C1–C5 and 400 random problems; rules A_K and R-B evaluated on full baseline trajectories),
  `paired308.jl` (paired in-process timing, base and candidate with A/A copies), `optimum308.jl` (baseline at exact
  optima); aggregators `agg308.py`, `tracesum308.py`, `cexagg.py`, `runs308.py`, `sim308.py`.
- Results per Julia version (`v110-`, `v113-`): `matrix-{base,cand}-{strict,harness}.tsv`, `paired.tsv`, `cex.tsv`,
  `trace-summary.tsv`; one complete per-iteration log `v113-trace-lasso-1.tsv`.
- Aggregates: `agg-matrix-paired.txt`, `agg-traces.txt`, `agg-cex.txt`.
- `SHA256SUMS`: checksums of every other file.

The complete per-iteration logs of all 100 solves (about 100 MB) are not archived; `trace308.jl` regenerates them
deterministically (`julia --project=<env> trace308.jl <outdir> 1:10`).
