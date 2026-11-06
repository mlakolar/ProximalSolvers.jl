# Stage 2B: migration comparison across the ProximalBase 0.6 release

Part of [#110](https://github.com/mlakolar/ProximalSolvers.jl/issues/110). Related:
[mlakolar/ProximalBase.jl#527](https://github.com/mlakolar/ProximalBase.jl/issues/527) (the downstream
migration ledger).

**Status: preparation only; no official measurement.** This directory holds the methodology, the
workload-compatibility audit, the readiness record, the reset probes with their checker and tests, the
read-only historical reference and the specification of the comparison reader. It contains no timing
result. It changes nothing in `../pre06/`, in `benchmark/*.jl` or `benchmark/*.py`, in `src/` or in the
published Stage 2A release.

Stage 2B is a **whole-stack** comparison of a pre-0.6 stack (Stack A: ProximalSolvers `b0de3f7`,
ProximalBase 0.5.4) with a migrated stack (Stack B: a new explicit ProximalSolvers commit, a ProximalBase
0.6 candidate commit), under contemporaneous, counterbalanced conditions. A difference is never
attributed to ProximalBase alone. The Stage 2A archive is historical context, not a paired experiment.

## Files

| File | Content |
|:--|:--|
| [`STAGE2B_PLAN.md`](STAGE2B_PLAN.md) | The methodology: identities, stacks, Julia strata, readiness gates G1-G8 and their status, the stop rule, the equivalence audit, pilots, A/A control, A/B campaign, extension rule, reporting, diagnosis, archive, freeze gate, PR split, effort estimate, maintainer decisions. |
| [`CASE_MAPPING.md`](CASE_MAPPING.md) | The readable workload-compatibility audit of the 19 cases: matrix, the probe evidence for P04, P05, P10, P13, P14 and D02, and the 0.6 migration paths that no case exercises. |
| [`case-mapping.toml`](case-mapping.toml) | The same audit as data: one `[[case]]` per Stage 2A case, with the provisional class A to D, the 0.6-sensitive sites with `file:line`, the work counters and the equivalence check a pilot must pass. |
| [`READINESS.md`](READINESS.md) | The audit of ProximalSolvers against the ledger rows, the readiness probe results and the gates.  |
| [`MIGRATION_COMPARE_SPEC.md`](MIGRATION_COMPARE_SPEC.md) | Specification (no implementation) of `migration_compare.py`: accepted and refused differences, outputs, synthetic tests. |
| [`historical_reference.py`](historical_reference.py), [`historical-reference.tsv`](historical-reference.tsv) | Read-only reference extracted from the verified Stage 2A archive (release `bench-pre06-v1`, asset `pre06-stage2a-campaign-v1.tar.gz`, SHA-256 `1edd64330606d739acf1d7b4ba0643a4fb6a1366bad4c82393e2ba1ffdcc723e`). One row per Julia version and case. Descriptive only. |
| [`test_stage2b_files.py`](test_stage2b_files.py) | Offline tests of the files above. |
| [`probes/`](probes/) | `reset_semantics.jl` (the probe, run on ProximalBase 0.5.4 and on a probe-only commit of master), `check_reset_probes.py` (its checker), `test_check_reset_probes.py` (offline tests of the checker) and `results/` (the recorded probe outputs). |

## Run the tests

Python 3.11 or later (`tomllib`), standard library only; no Julia, no network.

```
cd benchmark/campaigns/stage2b
python3 -B -m unittest test_stage2b_files -v
cd probes
python3 -B -m unittest test_check_reset_probes -v
```

To regenerate and check the historical reference against an extracted copy of the verified archive (the
script only reads it; the directory is `pre06-stage2a-campaign-v1/`):

```
python3 -I -B historical_reference.py PATH/TO/pre06-stage2a-campaign-v1 --check historical-reference.tsv
```

## Stop rule

If any readiness gate of `STAGE2B_PLAN.md` section 5 is unmet when a campaign would start, no official
measurement is taken: the unmet gates are listed in `READINESS.md` and on #110. Probes, pilots and
exploratory runs are labelled exploratory and are never counted as official or described as results.
Today every gate is unmet: there is no ProximalBase 0.6 candidate commit and no migrated ProximalSolvers
commit.
