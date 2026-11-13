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
| [`stage2b_campaign.py`](stage2b_campaign.py) | The campaign driver (standard library only): TOML writer, campaign lock, official gate, preflight checks, source fingerprints, identity and receipt writers, sealing, the engine behind `run` and `pilot`, declared differences, `verify`, the real hooks (subprocess runner, untimed environment probe, depot-cache digest, data-hash check) and `prepare` (`fetch` and `finalize`). It launches `benchmark/run.jl` and measures nothing. |
| [`test_stage2b_campaign.py`](test_stage2b_campaign.py) | Offline tests of the driver (no Julia, no network): the gate and pilot refusals (a stub runner that fails if invoked), every preflight defect, sealing, the stop state, a full-shape run (two strata, 19 cases, 8 repetitions, four roots) that is verified, copied and mutated, `prepare`, the probe conversion, the depot digest and the pilot-schedule derivation over mocked subprocess layers, and the session per base, the probe records and the numeric range checks (#229); and the frozen Stage 2B and Stack A harness identities, verified against the files of their pinned commits read with git. |
| [`export_fingerprints.jl`](export_fingerprints.jl) | The untimed fingerprint exporter (needs Julia and the benchmark environment): loads the real harness of a stack, runs `reset!`, one untimed `call!` and `reset!` on each case state and writes `fingerprints.tsv` rows (section 14 of the specification) in the canonical encoding `ps-stage2b-fp-v1`, with a data-hash sidecar and a summary; fails closed (exit 2) on any missing or unexpected closure field. |
| [`environment_probe.jl`](environment_probe.jl) | Prints the environment inventory of the running Julia process as TOML (the Stage 2A format plus the realpath keys of section 10); run in the environment of a stack. |
| [`test_export_fingerprints.jl`](test_export_fingerprints.jl) | The Julia test of the exporter: the encoder (differing pairs, unsupported types, known answers), the real cases through the harness, the command line; `PS_FP_FULL=true` adds the full scheduled export. |
| [`test_p14_reset.jl`](test_p14_reset.jl) | The Julia test of the P14 reset port (needs Julia and the benchmark environment; not part of the Python tests). |
| [`historical_reference.py`](historical_reference.py), [`historical-reference.tsv`](historical-reference.tsv) | Read-only reference extracted from the verified Stage 2A archive (release `bench-pre06-v1`, asset `pre06-stage2a-campaign-v1.tar.gz`, SHA-256 `1edd64330606d739acf1d7b4ba0643a4fb6a1366bad4c82393e2ba1ffdcc723e`). One row per Julia version and case. Descriptive only. |
| [`test_stage2b_files.py`](test_stage2b_files.py) | Offline tests of the documents, the mapping, the schedule and the historical reference. |
| [`probes/`](probes/) | `reset_semantics.jl` (the probe, run on ProximalBase 0.5.4 and on a probe-only commit of master), `check_reset_probes.py` (its checker), `test_check_reset_probes.py` (offline tests of the checker) and `results/` (the recorded probe outputs). |

## Driver (`stage2b_campaign.py`)

```
python3 -B stage2b_campaign.py preflight --config FILE --base BASE [--official --freeze-sha SHA] [--arms AB,AA] [--julia MM=PATH ...]
python3 -B stage2b_campaign.py prepare   --config FILE --base BASE --step fetch|finalize [--julia MM=PATH ...] [--archive FILE]
python3 -B stage2b_campaign.py run       --config LOCK --base BASE --official --freeze-sha SHA [--julia MM=PATH ...]
python3 -B stage2b_campaign.py pilot     --config PILOT --base BASE [--arms AB] [--julia MM=PATH ...]
python3 -B stage2b_campaign.py verify    --base BASE --out FILE [--config PILOT_CONFIG]
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
The official gate also refuses the historical stack as a candidate (ProximalBase 0.6 only, and no value equal to
the `[stack_a]` identity). The engine needs the depot-cache digest and the data-hash check hooks and records the digest
before and after every process. `verify` is read-only, needs no Julia and works on a copied tree. It recomputes the
checksums, the seals (exactly one per record file, mode 0444), the sidecar and fingerprint coverage, the receipt, the
probe records and the session record, rejects symbolic links, binds the tree to its configuration and campaign ids, and replays `migration_compare.py` on the
tree's own copies, comparing the exit status, refusals, CSV rows, `report.md` and `lists.json` (`--out` is a fresh path
outside the evidence).

**What `verify` trusts.** The mode of an attempt follows from its recorded campaign and schedule identity, never from an
archived flag, and it selects a closed policy-file inventory. Official: `official: true`, a valid `lock.toml`
(required), no `pilot-config.toml`. Pilot (`-pilot` names, `official: false`): the archived `pilot-config.toml` must be
byte-equal to the configuration the verifier holds (`--config`); no `lock.toml`. Only the documented top-level entries
are accepted (`roots`, `logs`, `comparison`, `schedule.toml`, `case-mapping.toml`, `receipt.jsonl`,
`declared-differences.toml`, `checksums.sha256`, the private `installations`, `environments`, `depots`, and the one
configuration file of the mode). A pilot reports `PILOT / NON-OFFICIAL`, verifies only as a pilot and never satisfies
the official gate.

The trusted policy set is the verifier's own `schedule.toml` and `case-mapping.toml`, each tracked and unmodified in
its repository. For an official attempt the archived `schedule.toml` must equal the verifier's, so the required arms,
roots, blocks and counts derive from the trusted schedule, not from the archive (for a pilot they derive from the
archived schedule, which must agree with the held configuration). The archived `case-mapping.toml` must equal the
verifier's (for a pilot too); `campaign.json` records `schedule_sha256` and `case_mapping_sha256` and
`logs/completion.json` binds them together with the digest of `logs/campaign.json` and of the lock (official) or the
pilot configuration. For an official attempt `declared-differences.toml` is recomputed from the archived roots and the
validated lock and must be equal (a pilot's is the minimal `schema = 1`), and the lock is checked again for a 0.6
ProximalBase, a stack B different from `[stack_a]` and a 40-hex `freeze_sha` in `campaign.json`. These are
verification-consistency checks: they do not replace the `run --official` gate or the F1-B approval. In this pre-freeze
state the repository files are a development reference, not an F1-B freeze: official use later requires the verifier
to be an independently selected clean checkout at the approved freeze commit.

**Guarantee.** `verify` enforces the internal consistency of the evidence against the trusted policy files and catches
partial or contradictory edits. It is not a signing system: `checksums.sha256`, the seals and the cross-digests can all
be regenerated by someone who rewrites the whole tree, so it cannot authenticate a fully coordinated forged archive.
The anchors are outside the archive: the Release asset SHA-256 published on #110 (checked by the consumer after
retrieval) and the clean checkout at the F1-B freeze commit.

Exit status: 0 success; 1 completed with non-ok cases (a process exit 2 or comparator exit 1); 2 refused or stopped
(gate, preflight, infrastructure stop, comparator refusal, failed verification); 3 usage or internal error. The
operator workflow, from setup to the verification of a copy, is in the next section.

## Operator workflow

**Setup.** Python 3.11 or later and `git` on `PATH`; one Julia binary per stratum, exactly the builds of
`schedule.toml` (`[julia."1.10"]`, `[julia."1.13"]`), given as `--julia MAJOR.MINOR=ABSOLUTE_PATH` or, for a pilot,
in `[julia]` of the pilot configuration; a Linux host that lets `taskset` pin a process; at least `max(2, min_cpus)` allowed CPUs
(`[resources] min_cpus` of the pilot configuration; the measured one, and the driver keeps itself off it); the verified Stage 2A archive (`--archive`, or `[archive] path`
of a pilot configuration). `prepare --step fetch` needs the network (the package server and the source
repositories); everything after it runs offline. The measurement node must be the one that ran `finalize`.

**Source and dependency locks.** Stack A is the historical identity of `schedule.toml` (`[stack_a]`): ProximalSolvers
`b0de3f7` and ProximalBase 0.5.4 (tag `v0.5.4`, commit and tree pinned). Its environment is the archived Stage 2A
`Project.toml` and `Manifest.toml` of each stratum (the archive's SHA-256 is checked before anything is read, only those
members are extracted, nothing from it is executed), with only the ProximalSolvers `path` line of the Manifest and, on
Julia 1.13, the ProximalSolvers line of `[sources]` rewritten to the role's checkout. Julia 1.13 then reports that the
Manifest is out of sync with the Project, because the Project text changed; `Pkg.resolve()` then changes nothing but
`project_hash`. `prepare` accepts that only if every (name, uuid, version, git-tree-sha1) entry stays identical to the
archived Manifest and to the lock of the Stage 2A campaign definition and no Manifest line other than `path` and
`project_hash` differs; anything else stops (no fresh resolution, no new historical baseline); the diff is kept in
`logs/`. Stack B is described by the campaign lock (TOML, schema 1, committed inside the freeze commit): ProximalSolvers
and ProximalBase commits, trees, package fingerprints and source locators, the frozen `Project.toml` and `Manifest.toml`
of each stratum with their SHA-256, the declared differences with the maintainer's reasons and approval URLs, the harness
port and the approvals. No candidate lock exists yet. A host-specific value (a Julia path, the archive) never goes into
the lock: it is a command-line option.

**The four roles.** `ab-a` and `ab-b` are the two sides of the A/B arm (stack A and stack B); `aa-a` and `aa-b` are two
independent installations of stack A for the A/A arm. Each role has its own clone (`git clone --no-hardlinks`, checked
out detached at the pinned commit, verified clean including untracked and ignored files), its own depot and its own
environment per stratum; two roles never share any of them.

**Official versus pilot.** `run --official --freeze-sha SHA` is the only official route (campaign
`pb06-migration-stage2b-v1`). `pilot` is an engineering smoke: its campaign and schedule ids contain `-pilot`, its base
directory name contains `pilot`, it runs the A/B arm with two independent installations of stack A, with one
repetition and reduced sampling (`[pilot]` of its configuration), and `verify` reports it as `PILOT / NON-OFFICIAL`. A
pilot result is never read as a measurement of anything.

**What `finalize` writes.** On the measurement node, offline, with exactly the formal Julia flags and environment
(`--startup-file=no --history-file=no`, one Julia thread, `JULIA_LOAD_PATH=@:@stdlib`, a private depot first): per role and
stratum `Pkg.precompile()`, two untimed warm-up runs of the role's `run.jl` with `PS_LIST=true` (the second must not
precompile), the exporter (roles `ab-a` and `ab-b`), and the environment probe (`environment-inventory.toml`). Then the
identity files, the two fingerprint files per A/B root (`fingerprints.tsv` and the data-hash sidecar, strata in schedule
order, one header), the depot baselines (`logs/depot-baselines.json`) and the checks of `preflight` on what was observed.
For a pilot it also writes the pilot `schedule.toml`: the committed schedule with only the schedule ids, one repetition
in the order AB, the reduced sampling values and the `[machine]` values of this node changed (`cpu_model`, the
`Sys.CPU_NAME` of each stratum, the measured CPU, `smt_sibling = -1`, and `governor`, `epp`, `no_turbo`, `smt_control` as
sampled, `"unavailable"` where the host has no such file); `logs/pilot-overrides.json` lists every changed key with both
values and the digests. `finalize` refuses to run twice on one base and refuses when fewer than `max(2, min_cpus)` CPUs are allowed. It writes the depot baselines only after its own final checks passed. A failed final check leaves `logs/finalize.json` with state `failed` and its problems, and no baseline; an earlier interruption of the preparation (a step that refuses or is killed) may leave the marker at `started`, also without a baseline. In both cases the official runner refuses, because no valid `finalized` marker and baseline exist. `run --official` and `pilot` refuse to start unless `logs/finalize.json` says `finalized` with no problems and `logs/depot-baselines.json` names every role.

**Candidate-specific freeze (official only).** The campaign needs the F1-B freeze: the lock is committed inside the
freeze commit, whose SHA is posted on #110 with the specification, the mapping, the schedule and the rest of the frozen
files; readiness gates G1 to G8 of `READINESS.md` all hold (G1 a ProximalBase 0.6 candidate commit, G2 the migration PRs
merged, G3 explicit compat, G4 the full suite on both Julia versions, G5 the integration tests, G6 the contract-failure
tests, G7 the ledger rows, G8 the mapping re-validated on the pinned candidate and signed off). `run --official` verifies
what a program can: `HEAD` is the freeze SHA, the checkout is clean, the lock is tracked there, every B field is a full SHA
equal to the fetched checkout, the Manifest digests equal the lock's, every mapping row is approved, and G1 to G8 and the
mapping approvals are non-empty maintainer comment URLs of this repository. What remains the maintainer's: that those
comments say what the gates require, the F1-B freeze comment on #110, and the judgment that the candidate is ready. The
driver never reads an approval flag and no environment variable changes the mode.

**Canonical commands.** From this directory, with `BASE` a fresh directory (pilot: its name contains `pilot`):

```
python3 -B stage2b_campaign.py prepare   --config CONFIG --base BASE --step fetch    [--julia ...] [--archive FILE]
python3 -B stage2b_campaign.py prepare   --config CONFIG --base BASE --step finalize [--julia ...]
python3 -B stage2b_campaign.py preflight --config CONFIG --base BASE [--official --freeze-sha SHA] [--julia ...]
python3 -B stage2b_campaign.py pilot     --config CONFIG --base BASE [--julia ...]
python3 -B stage2b_campaign.py run       --config LOCK   --base BASE --official --freeze-sha SHA [--julia ...]
python3 -B stage2b_campaign.py verify    --base BASE --out FILE [--config CONFIG]
```

Exit status of every command: 0 success, 1 completed with non-ok cases, 2 refused or stopped, 3 usage or internal error;
`preflight` prints every problem it finds and exits 0 only when there is none. A pilot configuration is a TOML file
(strict keys): `schema = 1`, `[campaign]` (`id`), `[schedule]` (`id`), `[pilot]` (`arms`, `samples_target`,
`seconds_limit`, `case_seconds`), `[julia]`, `[source]` (`repository`, optional `proximalbase`), `[archive]` (`path`) and
`[resources]` (`min_cpus`). The same file goes to `prepare`, `pilot` and `verify`. Numeric values are positive numbers
(`samples_target` and `min_cpus` integers); an integer beyond the float range (about 1e308), and an integer duration
above 2**53 (which `float()` would round), is refused like any other invalid value (exit 2; `verify --config` records it),
and `finalize` writes the durations into the pilot schedule as given, without coercion.

**Sessions.** `prepare --step fetch` mints a fresh session id for every base (`session-<UTC compact>-<4 hex>`, the
format of `mint_session_id`) and records it in `logs/session.json` with the campaign id and the SHA-256 of the base's
configuration copy; `finalize` writes it into every `stack-identity.toml`, and the engine takes it from there into the
receipt's `campaign` event, `campaign.json`, `STATE.json`, `completion.json` and every probe record. Two attempts from one
frozen configuration therefore never share a session. A configuration (pilot configuration or lock) that names
`campaign.session_id` is refused by `prepare` (and by the engine on a base with its own session), because every attempt
prepared from it would share that session; `campaign.session_id` remains valid in the parser only so that evidence
prepared before sessions were minted per base still verifies. The pilot schedule must carry the held configuration's `samples_target`, `seconds_limit` and `case_seconds` (the official values when the configuration names none), the official values for every other setting, a prefix of the official repetitions with their official orders, and the configuration's arms: `pilot` refuses to launch otherwise and `verify --config` records the mismatch.

**Fingerprints.** `finalize` runs `export_fingerprints.jl` of the driver's checkout once per role and stratum, untimed,
against that role's own harness, and concatenates the per-stratum files; the exporter's summary (with the cold snapshot
hashes) stays in `logs/`. After each process its `metrics.tsv` must agree
with the sidecar row for row, else the attempt stops (the A/A roots are compared with the `ab-a` sidecar).

**Receipts and seals.** The engine appends one `process` event to `receipt.jsonl` for every launched process, also for a
failed one, with the real start and end times; after each process it seals the six record files (SHA-256 in
`logs/seals.jsonl`, mode 0444) and checks every earlier seal again.

**Probe records.** Every untimed probe of an attempt (the `environment_probe.jl` process and the pinned affinity command;
once per role and stratum before the attempt, phase `preflight`, and once before each formal process, phase `launch`) leaves
one line in `logs/probes.jsonl`: `record = "probe"`, `timed = false`, the campaign, session and schedule ids, the process
it precedes, arm, role, installation, Julia version, repetition, the measured CPU, the outcome (`ok`, or `failed` with the
error) and the observed machine values, and each command's argv, exit status and start and completion times as the hook
read them. A failed probe is recorded before the attempt stops. The probe records are never receipt events and are not
read by the comparator; the engine reads no extra clock for them and the formal command lines are unchanged. A probe that
fails before the attempt begins (phase `preflight`) leaves the base fresh, without a record, like any refusal before a
launch. `verify` requires, for evidence whose `campaign.json` names the log, one valid preflight record per role and
stratum before the campaign started and one launch record per process event that finished before its process started, no
probe command inside any formal process, and ids, installations and the CPU that agree; only a stopped attempt may end
with a record that has no process event (the probe that failed or whose checks stopped it). The digest of every depot's `compiled/` directory is
recorded before and after each process and compared with the previous one of the same installation and with the baseline
that `finalize` wrote: any change stops the attempt. Only a sealed `logs/completion.json` is a success record.

**Interrupted or stopped runs.** A stopped run is preserved and never resumed or retried: `logs/STATE.json` says why,
every record stays, the receipt has an event for every launched process, and the base refuses to launch again. Start a
new base (a new `fetch`) for another attempt; the stopped one is kept as evidence of the stop.

**Verification and copies.** `verify` is read-only and needs no Julia. Run it on the base, copy the tree with `cp -a`
(or `tar`, which keeps modes) and run it again on the copy with its own `--out`; the two classifications must agree. A
pilot needs `--config`, the same file as the one given to `pilot`. The comparator's replay uses the tree's own copies of
the schedule, mapping, declared differences and receipt.

**Failed cases.** A process that exits with 2 completed with at least one non-ok case: its `metrics.tsv` rows with a
status other than `ok` and its `errors.tsv` say which, `logs/STATE.json` and the command output name the process and the
cases, and the comparison reports them under `not_ok` and `failed`. Nothing is retried; a case failure is data.

**Comparing the roots.** `comparison/` holds the output of `migration_compare.py` at run time (`migration-comparison.csv`,
the lists and `refusals.json`); to compare two roots by hand run `migration_compare.py` with the roots, the mapping, the
declared differences, the receipt and `--schedule`, as in the replay of `verify`.

**The descriptive A/A screens.** The A/A arm shows how far two independent installations of the same stack differ in
this environment; the screens that flag a ratio outside the A/A range are descriptive. They label a case, they never
declare a regression or an improvement, and with sub-millisecond cases a noninferiority claim is not supported.

**Re-verifying a copied tree.** Copy the whole base, not only `roots/`, run `verify` on the copy, compare the printed
classification with the original's, and check the SHA-256 of the archived asset against the value posted on #110 before
anything is reported.

**The historical Stage 2A release.** The release `bench-pre06-v1` and its asset are read-only inputs: the archive is
only read (its checksum verified, two files per stratum extracted into a private directory) and is never modified,
replaced or re-uploaded; Stage 2B work never changes `../pre06/`.

**What Stage 2B measures.** The whole stack: a difference between stack A and stack B is a difference of ProximalSolvers,
ProximalBase and their dependencies together (and of the harness port) and cannot be attributed to ProximalBase alone.

## Run the tests

Python 3.11 or later (`tomllib`), standard library only; no Julia, no network. `test_stage2b_campaign.py` also needs
`git` and the full history of the repository (see below).

```
cd benchmark/campaigns/stage2b
python3 -B -m unittest -v
cd probes
python3 -B -m unittest test_check_reset_probes -v
```

The first command lets `unittest` collect tests with its default pattern `test*.py` from this directory. It
runs every `test*.py` module of the directory itself (`test_stage2b_files.py` and `test_migration_compare.py`)
and does **not** pick up `probes/`: the collection descends only into directories that are Python packages, and
`probes/` has no `__init__.py`. The probe checker's tests therefore run with the second command.

**Historical harness identity.** The frozen harness identities are verified against immutable sources, not against
the working tree. `HistoricalHarnessTests` and `FingerprintTests` of `test_stage2b_campaign.py` read
`benchmark/problems.jl`, `certificates.jl`, `cases.jl` and `run.jl` as blobs from the git object store at the pinned
commits, recompute the harness hash with the driver's `harness_hash` (the algorithm of `benchmark/run.jl`) and require:

| Identity | Pinned commit | Harness hash | Required by |
|:--|:--|:--|:--|
| Stage 2B harness (approved P14 port) | `412063d8ac24b84a10ccde09cf072bb396109ffd` (`BASE_COMMIT`) | `0fd2b44dfea0b1f77c2c67228bf149207982ab8b` | `new_harness_hash` of P14 in `case-mapping.toml` |
| Stack A | `b0de3f7fc91767b97197ff4b458207e308998943` (`STACK_A_COMMIT`) | `b7bf3d953ec6e9f9720e74d7895b5cf95a629fd4` | `[stack_a] harness_hash` of `schedule.toml` |

`case-mapping.toml` records the Stage 2B hash as taken at the port commit `fb9b1692069dec4778f24a6732a325ab1c05f1b7`
of #217. That commit is reachable only from the pull-request ref, not from a full clone of the branches; the squash
merge of #217 (`f4f5b3e8e6a1898df1fee05476217a1237bee1cb`) and `BASE_COMMIT` (#219) hold the same four blobs, so the
tests read `BASE_COMMIT`. A missing commit, a missing file, a commit that is not the pinned one or a single changed
byte fails the tests; nothing is skipped. Master may therefore change the four harness files without touching these
identities: `test_stage2b_files.py` and `test_migration_compare.py` no longer read them from the working tree, and a
test of `test_stage2b_files.py` runs every other test of that file against a rewritten scratch harness. The
approved hashes, the mapping and the schedule are unchanged. The tests of the current driver, comparator and
ordinary tools still read the working tree (`compare.py`, `validate.py` and `summarize.py`, which
`migration_compare.py` uses, stay pinned there). An official campaign does not use the working tree either: the
driver clones and verifies its own pinned checkout per role.

**In CI.** The `Benchmark analysis controls` job (`.github/workflows/CI.yml`), required through `PR required jobs`, runs all four offline Python
suites from the repository root, with Python 3.12. The comparator and campaign suites each have a leg of their own (`comparator`, `campaign`); the other two run in the `controls` leg, together with the paired-master diagnostics. The suites:

```
python3 -B benchmark/campaigns/stage2b/test_migration_compare.py
python3 -B benchmark/campaigns/stage2b/test_stage2b_files.py
python3 -B benchmark/campaigns/stage2b/test_stage2b_campaign.py
python3 -B benchmark/campaigns/stage2b/probes/test_check_reset_probes.py
```

Every leg checks out the full history, and the `campaign` leg first checks that the two commits pinned in
`test_stage2b_campaign.py` (`BASE_COMMIT`, `STACK_A_COMMIT`) are present. The tests at those commits fail, rather than
skip, when a commit is missing; a skipped test also fails its step. A failing suite fails its leg, which fails the job's
result (`needs.analysis.result`). `PR required jobs` reads that result, and `PR merge gate` reads the conclusion of `PR required jobs`.

The Julia test
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

**Cache and provenance.** The compiled-cache digest covers every effective `JULIA_DEPOT_PATH` entry of a role (its private
depot and the bundled Julia depots of every stratum it runs): it is the baseline of `finalize` and it is compared before
and after every process and between processes. `prepare --step fetch` always resolves the stack A tag `v0.5.4` to the
pinned commit and tree from `[source] proximalbase` of the configuration or, when none is given, from the default
repository `https://github.com/mlakolar/ProximalBase.jl` (`DEFAULT_PB_SOURCE`); it fails unless that check succeeds, and
records it in `logs/provenance.json` (`pb_tag_check`). A registry copy only confirms the tree. For stack B it creates the
pinned ProximalBase identity checkout (`installations/ab-b/ProximalBase.jl`) for registered and development releases
alike. Preparation logs redact `HOME`, `USER`, `LOGNAME` and `TMPDIR` like `commands.jsonl`.

**Known limits.** The per-launch probe processes run pinned on the measured CPU between formal processes; they are
recorded in `logs/probes.jsonl`, not as receipt events. Evidence made before the session record and the probe log existed
(its `campaign.json` names neither) is verified as before: its session comes from the configuration and no probe record
is required. Two bases prepared in the same second share a session id with probability 1/65536 (four random hex digits,
the existing format); they still differ in their installation ids and base names. Stack B environments
need project and Manifest references that are valid in every base (relative paths); this is untested with a real
candidate (the candidate-lock task). Paths of the producer machine appear in `commands.jsonl` (argv and cwd) and in the
raw `run.jl` metadata by design: evidence is not scrubbed of them, only the environment values above are redacted.

## Stop rule

If any readiness gate of `STAGE2B_PLAN.md` section 5 is unmet when a campaign would start, no official
measurement is taken: the unmet gates are listed in `READINESS.md` and on #110. Probes, pilots and
exploratory runs are labelled exploratory and are never counted as official or described as results.
Today G1 to G7 are unmet: there is no ProximalBase 0.6 candidate commit and no migrated ProximalSolvers
commit. G8 is approved for the implementation and testing of this tooling, with candidate-specific
re-validation and sign-off still required.
