# ProximalSolvers.jl #314 evidence: post-fix PGD/APG benchmark coverage and practical stopping profiles

Not part of the package; nothing here is built or tested. Issue: https://github.com/mlakolar/ProximalSolvers.jl/issues/314

- **Code:**
  - PS `fad90d93eb0abca3025ac5a07468b7ebe4c7e323`, a clean detached clone; it includes #286, #287, #312 and #313.
  - ProximalBase pinned at `c123d56ba1948e36a8fdbf183a9eea396a16e0d5`; the loaded git-tree is `c2e2ddde114a1e7800358595193ee0869830180d` in both environments.
  - Harness hash `69e2fe03d14ff60dd3eb970b9f4b42132809fb06`, the same as #281.
- **Machine:** cluster (Slurm), `oneweek` partition, exclusive nodes, all Intel Xeon E5-2640 v4. One Julia thread and one BLAS thread (OpenBLAS, LBT ILP64). Julia 1.10.13 (`j110`) and 1.13.3 (`j113`).
  - Jobs 14239946 and 14239949 (formal); 14240064 (j110 sel; 14239947 crashed, see `PREREGISTRATION.md`); 14239950 (j113 sel); 14239948 and 14239951 (conf). See `cluster/sacct.txt`.
- **Draw inputs differ between Julia versions:** every data hash differs (see `benchmark/campaigns/stage2b/CASE_MAPPING.md`). The two versions are therefore independent replications.

## Files

- `PREREGISTRATION.md` and `PREREGISTRATION.sha256`: the frozen profiles, problems and rules, plus one recorded deviation (a container-type fix). `SELECTION.md` records the selection decision, written before the confirmation files were opened.
- `probes/`:
  - `probe314.jl` loads the harness's `problems.jl`, `certificates.jl` and `cases.jl`. It checks harness data hashes and the shared trajectory, and records flags, counters, products, k*, time to target, return time and allocations.
  - `job314.sh` is the job body; `agg314.py` is the aggregator.
- `cluster/out-<tag>-formal/formal/`: the formal `run.jl` records (`PS_SUITE=extended PS_GROUPS=gradient`, draws 1–10), with `validation.json`, `summary/` and `probe-harness.tsv`.
- `cluster/out-<tag>-probe-{sel,conf}/`: the Phase B probe TSVs. The partial output of the crashed job is kept at `out-j110-probe-sel-FAILED-14239947` and is not used.
- `phaseA.md`, `sel-*.md`, `conf-*.md`: aggregates (regenerate with `agg314.py`).
- `local/`: local exploratory smoke tests (Intel i5-13600K, not used for any claim).
- `SHA256SUMS`: checksums of every other file.

## Reproduce

```sh
git clone https://github.com/mlakolar/ProximalSolvers.jl ps && git -C ps checkout --detach fad90d93eb0abca3025ac5a07468b7ebe4c7e323
julia ps/benchmark/setup.jl "$PWD/ps" env pinned        # per Julia version
export JULIA_NUM_THREADS=1
# formal Phase A (from ps/), draws 1..10:
PS_SUITE=extended PS_GROUPS=gradient PS_REPETITION=$rep PS_OUTPUT=out/formal \
  PS_EXPECTED_PACKAGE_REVISION=fad90d93eb0abca3025ac5a07468b7ebe4c7e323 \
  PS_EXPECTED_PROXIMALBASE_REV=c123d56ba1948e36a8fdbf183a9eea396a16e0d5 julia --project=env benchmark/run.jl
python3 benchmark/validate.py out/formal out/validation.json --expected-runs 10
# probes:
julia --project=env probes/probe314.jl "$PWD/ps" harness out/probe-harness.tsv 1:10 1/1 5
julia --project=env probes/probe314.jl "$PWD/ps" sel out/probe-sel.tsv 1:4 1/1 5
julia --project=env probes/probe314.jl "$PWD/ps" conf out/probe-conf.tsv 1:6 1/1 5
python3 probes/agg314.py phaseA <formal j110> <formal j113> <probe-harness j110> <probe-harness j113>
python3 probes/agg314.py profiles <label> <probe.tsv>...; python3 probes/agg314.py select <probe.tsv>...
```
