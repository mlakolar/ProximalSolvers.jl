# Stage 2B: migration comparison across the ProximalBase 0.6 release

Part of [#110](https://github.com/mlakolar/ProximalSolvers.jl/issues/110). Related:
[mlakolar/ProximalBase.jl#527](https://github.com/mlakolar/ProximalBase.jl/issues/527) (the downstream
migration ledger).

**Status: preparation and tooling only; no official measurement.** This directory holds the methodology, the
workload-compatibility audit, the readiness record, the reset probes with their checker and tests, the
read-only historical reference, the pre-freeze schedule, the specification of the comparison tool and the tool
itself with its synthetic tests. It contains no timing result. It changes nothing in `../pre06/`, in the
published Stage 2A release, in `src/`, in `benchmark/compare.py` or in `benchmark/validate.py`; the only edit of
the benchmark harness is the approved compatibility-only P14 reset port in `benchmark/cases.jl`.

Stage 2B is a **whole-stack** comparison of a pre-0.6 stack (Stack A: ProximalSolvers `b0de3f7`,
ProximalBase 0.5.4) with a migrated stack (Stack B: a new explicit ProximalSolvers commit, a ProximalBase
0.6 candidate commit), under contemporaneous, counterbalanced conditions: eight A/A and eight A/B paired
fresh-process blocks per Julia version, in the order AB, BA, BA, AB, BA, AB, AB, BA by repetition ID. A
difference is never attributed to ProximalBase alone. The Stage 2A archive is historical context, not a
paired experiment.

## Files

| File | Content |
|:--|:--|
| [`STAGE2B_PLAN.md`](STAGE2B_PLAN.md) | The methodology: identities, stacks, Julia strata, readiness gates G1-G8 and their status, the stop rule, the equivalence audit, pilots, A/A control, A/B campaign, extension rule, reporting, diagnosis, archive, freeze gate, PR split, effort estimate, maintainer decisions. |
| [`CASE_MAPPING.md`](CASE_MAPPING.md) | The readable workload-compatibility audit of the 19 cases: matrix, the probe evidence for P04, P05, P10, P13, P14 and D02, and the 0.6 migration paths that no case exercises. |
| [`case-mapping.toml`](case-mapping.toml) | The same audit as data: one `[[case]]` per Stage 2A case, with the class A to D, the approval record (`approved`; for the class B row P14 also the approval URL, scope, port text and `new_harness_hash`), the 0.6-sensitive sites with `file:line`, the work counters and the equivalence check a pilot must pass. |
| [`READINESS.md`](READINESS.md) | The audit of ProximalSolvers against the ledger rows, the readiness probe results, the gates and the maintainer's decisions after PR #215. |
| [`MIGRATION_COMPARE_SPEC.md`](MIGRATION_COMPARE_SPEC.md) | The specification of `migration_compare.py`: accepted and refused differences, the 16 refusal classes with their fields, the schemas of every input and output (root layout, `stack-identity.toml`, receipt, declared differences, fingerprints, outputs), the screens, the near-target flag, the required synthetic tests. |
| [`schedule.toml`](schedule.toml) | The single machine-readable schedule: the eight repetition IDs and their block orders, the frozen sampling settings, the machine policy, the Julia builds and the Stack A identity. A **pre-freeze draft** that the F1-B freeze fixes; no official timing may use it before. |
| [`migration_compare.py`](migration_compare.py) | The whole-stack comparison tool, written to the specification. Reads records only; runs no Julia; never changes `compare.py` or `validate.py`. |
| [`stage2b_fixtures.py`](stage2b_fixtures.py) | Builds the complete synthetic input sets (roots, receipt, mapping, declared differences, fingerprints) that the tests of the tool mutate one item at a time. |
| [`test_migration_compare.py`](test_migration_compare.py) | Offline tests of the tool: one per refusal class, the accepted differences, the per-case classes, the screens and the outputs. |
| [`stage2b_campaign.py`](stage2b_campaign.py) | The campaign driver core (standard library only): TOML writer, campaign lock, official gate, preflight checks, source fingerprints, identity and receipt writers, sealing, the engine behind `run` and `pilot`, declared differences, and `verify`. Julia and the host are injected through `Hooks`; the real Julia hooks and `prepare` are not part of it yet. It launches `benchmark/run.jl` and measures nothing. |
| [`test_stage2b_campaign.py`](test_stage2b_campaign.py) | Offline tests of the driver with mocked hooks: the gate and pilot refusals (a stub runner that fails if invoked), every preflight defect, sealing, the stop state, and a full-shape run (two strata, 19 cases, 8 repetitions, four roots) that is verified, copied and mutated. |
| [`test_p14_reset.jl`](test_p14_reset.jl) | The Julia test of the P14 reset port (needs Julia and the benchmark environment; not part of the Python tests). |
| [`historical_reference.py`](historical_reference.py), [`historical-reference.tsv`](historical-reference.tsv) | Read-only reference extracted from the verified Stage 2A archive (release `bench-pre06-v1`, asset `pre06-stage2a-campaign-v1.tar.gz`, SHA-256 `1edd64330606d739acf1d7b4ba0643a4fb6a1366bad4c82393e2ba1ffdcc723e`). One row per Julia version and case. Descriptive only. |
| [`test_stage2b_files.py`](test_stage2b_files.py) | Offline tests of the documents, the mapping, the schedule and the historical reference. |
| [`probes/`](probes/) | `reset_semantics.jl` (the probe, run on ProximalBase 0.5.4 and on a probe-only commit of master), `check_reset_probes.py` (its checker), `test_check_reset_probes.py` (offline tests of the checker) and `results/` (the recorded probe outputs). |

## Driver (`stage2b_campaign.py`)

```
python3 -B stage2b_campaign.py preflight --config FILE --base BASE [--official --freeze-sha SHA] [--arms AB,AA]
python3 -B stage2b_campaign.py prepare   --config FILE --base BASE --step fetch|finalize
python3 -B stage2b_campaign.py run       --config LOCK --base BASE --official --freeze-sha SHA
python3 -B stage2b_campaign.py pilot     --config PILOT --base BASE [--arms AB]
python3 -B stage2b_campaign.py verify    --base BASE --out FILE
```

`run` and `pilot` share one engine. `run` is the only official route: it needs `--official`, the campaign lock and a
freeze SHA, and proceeds only when `official_gate` lists no unmet gate (HEAD equals the freeze SHA, the checkout is
clean including untracked and ignored files, the lock is tracked at that commit, the migrated commits and trees are
full SHAs equal to the fetched checkouts, the Manifest digests equal the lock's, every class B, C and D mapping row is
approved, and G1 to G8 and the mapping approvals are maintainer comment URLs of this repository). Nothing is read
from the environment. `pilot` is never official: its campaign and schedule ids contain `-pilot` and differ from the
official ones, its base directory name contains `pilot`, and it has no `[stack_b]` table.

`BASE` holds `roots/{ab-a,ab-b,aa-a,aa-b}` (the roots of `migration_compare.py`; arm AB runs ab-a and ab-b, arm AA runs
aa-a and aa-b), the private `installations/`, `environments/` and `depots/` (not evidence), the copies of
`schedule.toml`, `case-mapping.toml` and `lock.toml`, `receipt.jsonl`, `declared-differences.toml`, `logs/` (seals,
commands, hardware samples, per-process output, `STATE.json`, `completion.json`), `comparison/` and
`checksums.sha256`. Processes run strictly one after another, per stratum, arm and repetition in the order of the
schedule, each pinned with `taskset`, in a whitelisted environment. After every process the six record files are
sealed (SHA-256, mode 0444) and all earlier seals are checked again. An exit of 2 (non-ok cases) is kept and reported;
any other outcome stops the attempt: `STATE.json` says why, everything is kept, a receipt event is written for every
launched process, and the base never launches again. Only a sealed `logs/completion.json` is a success record.
`verify` is read-only, needs no Julia and works on a copied tree: it recomputes the checksums, the seals, the
coverage and the receipt, then replays `migration_compare.py` on the tree's own copies and compares the outcome
(`--out` is a fresh path outside the evidence).

Exit status: 0 success; 1 completed with non-ok cases (a process exit 2 or comparator exit 1); 2 refused or stopped
(gate, preflight, infrastructure stop, comparator refusal, failed verification); 3 usage or internal error. The real
Julia hooks, `prepare` and the real pilot flow are added later: those subcommands validate their arguments and exit
with status 3, launching nothing.

## Run the tests

Python 3.11 or later (`tomllib`), standard library only; no Julia, no network.

```
cd benchmark/campaigns/stage2b
python3 -B -m unittest -v
cd probes
python3 -B -m unittest test_check_reset_probes -v
```

The first command lets `unittest` collect tests with its default pattern `test*.py` from this directory. It
runs every `test*.py` module of the directory itself (`test_stage2b_files.py` and `test_migration_compare.py`)
and does **not** pick up `probes/`: the collection descends only into directories that are Python packages, and
`probes/` has no `__init__.py`. The probe checker's tests therefore run with the second command. The Julia test
of the P14 port runs separately, from the repository root, in an environment with ProximalBase, ProximalSolvers
and the standard libraries it uses:

```
JULIA_NUM_THREADS=1 julia --project=<environment> benchmark/campaigns/stage2b/test_p14_reset.jl
```

To regenerate and check the historical reference against an extracted copy of the verified archive (the
script only reads it, binds it to the archive: the SHA-256 of the root `checksums.sha256` listing is pinned in the script
(`LISTING_SHA256`; the tarball digest is provenance only and not checked), every file must match that listing,
and `campaign.toml` and `cases.txt` must equal the frozen `../pre06/` files (exit 1 if anything differs), and prints the SHA-256 of the checked TSV; the directory is
`pre06-stage2a-campaign-v1/`):

```
python3 -I -B historical_reference.py PATH/TO/pre06-stage2a-campaign-v1 --check historical-reference.tsv
```

## Stop rule

If any readiness gate of `STAGE2B_PLAN.md` section 5 is unmet when a campaign would start, no official
measurement is taken: the unmet gates are listed in `READINESS.md` and on #110. Probes, pilots and
exploratory runs are labelled exploratory and are never counted as official or described as results.
Today G1 to G7 are unmet: there is no ProximalBase 0.6 candidate commit and no migrated ProximalSolvers
commit. G8 is approved for the implementation and testing of this tooling, with candidate-specific
re-validation and sign-off still required.
