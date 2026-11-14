# PR #313 measurements (the implementation of CW20)

- Fix: `9d6c3db8ef5dcc19ace9705e31a803532963c4f8` (code); final head `33c82c2b00a933cfebfaa12873c757a658595d73`, which differs only in a docstring and `docs/src/numerics.md`.
- Base: master `5abe1bc4b4b94b39b466e64d96a2ef77421e9749`.
- Cluster (Slurm), AMD EPYC 7513 (no AVX-512), Julia 1.10.12 and 1.13.3, shared nodes. Each probe runs in a fresh process on each tree (`probes/measure.sh`). `probes/withenv.jl` instantiates the tree's environment first, which Julia 1.13 needs because it has no committed manifest.

## Results

- `results/counts-<version>.tsv`, `.summary.txt`: coordinate visits, passes and BigFloat-256 KKT for 392 runs per tree (`probes/counts313.jl`, summarized by `probes/analyze_counts.py`). The 5 ordinary designs have identical visits in all 280 runs on both versions. All changed runs are on the stress designs: 13 on 1.10.12 and 12 on 1.13.3.
  - Total visits, fix / master: 0.757 (1.10.12) and 0.894 (1.13.3).
  - Worst single run: 1.000 and 1.034.
  - Every run converged, and no run has a KKT violation above 10× master's.
- `results/alloc-<tree>-<version>.txt` (`probes/alloc313.jl`, every `@allocated` inside a function): 0 bytes per full pass and per active pass on both trees and versions. Whole-solve bytes do not grow with `maxpasses`; on 1.13.3 they vary between calls by up to 192 bytes on both trees.
- `results/seeds-<tree>-<version>.txt` and `seedscov-...`: seed scans of the #311 fixture (`probes/seeds313.jl`), default build and coverage-instrumented. 500 seeds × 16 configurations.
  - Master stalls: 191/1000 (1.10.12 default), 356/1000 under coverage on both versions, 0 on 1.13.3 default.
  - Fix: 0 stalls everywhere, no false convergence, worst converged KKT ≤ 2.94e-7.
- Test battery at `9d6c3db`:
  - `cd_numerics`, `minimal_core_characterization`, `sparse_cd`, `core_regressions`: 28761/28761 (1.10.12) and 28762/28762 (1.13.3).
  - `cd_numerics` under coverage: 25248/25248 on both versions.
  - The new `cd_numerics` at the base under coverage: 28 fail and 4 error. These include the original §18 failure, 4 of 436 at Float32 tol 1e-7.
