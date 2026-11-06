# Stage 2B methodology: whole-stack comparison across the ProximalBase 0.6 migration

Part of #110. Related: mlakolar/ProximalBase.jl#527 (the downstream migration ledger).

This document is the methodology of Stage 2B. It is **preparation only**: no official measurement exists,
none is taken from this record, and none may be taken until the readiness gates of section 5 are met and
the freeze gate of section 15 is passed. It builds on the Stage 2 design
([`../pre06/STAGE2_PLAN.md`](../pre06/STAGE2_PLAN.md), section 7) and never changes the Stage 2A files in
`../pre06/` or the Stage 2A release.

Companion files: [`CASE_MAPPING.md`](CASE_MAPPING.md) and [`case-mapping.toml`](case-mapping.toml) (the
workload-compatibility audit of the 19 cases), [`READINESS.md`](READINESS.md) (the audit against the
ledger and the gates), [`MIGRATION_COMPARE_SPEC.md`](MIGRATION_COMPARE_SPEC.md) (specification of the
comparison reader, implemented by `migration_compare.py`), [`schedule.toml`](schedule.toml) (the eight-block
schedule and the frozen settings, a pre-freeze draft), [`historical_reference.py`](historical_reference.py) and
[`historical-reference.tsv`](historical-reference.tsv) (the read-only Stage 2A reference).

## 1. Purpose and non-claims

**Purpose.** When ProximalBase 0.6 is released, ProximalSolvers will have been migrated to it. Stage 2B
measures, on the 19 frozen Stage 2A cases and under contemporaneous, counterbalanced conditions, whether
the migrated stack still certifies every workload and how its time compares with the pre-0.6 stack, so
that the maintainer can disposition every material difference before the 0.6 release.

**Non-claims.**

1. **Whole stack, not ProximalBase alone.** The two stacks differ in ProximalSolvers source, in
   ProximalBase, and possibly in declared dependencies and in a compatibility-only harness port. A
   measured difference is a whole-stack migration difference. It is never attributed to ProximalBase
   alone, or to any single change, without separate isolation experiments that are themselves
   preregistered.
2. **The Stage 2A archive is historical context, not a paired experiment.** It was taken at another time,
   on another day's machine state, with different inputs per repetition for most cases. Its means are
   descriptive references and are reported separately from contemporaneous results (section 12).
3. **No universal threshold.** There is no 5% rule and no universal margin. A confidence interval that
   contains 1 is never read as noninferiority. A paired interval is not an approved one-sided test:
   Stage 3 of #110 owns the calibration of formal noninferiority and improvement rules. The per-case
   screens of section 12 are labelled screens taken from the A/A noise, not tests, and carry no error
   rate.
4. **No pairing across Julia versions.** Julia 1.10.13 and Julia 1.13.3 produced different input hashes
   for every case, fixed-input cases included (`historical-reference.tsv`). They are separate strata:
   never pooled, never paired.
5. **A `data_hash` match is never proof of identical workload semantics.** It covers the generated
   arrays only (`benchmark/problems.jl:41-48`). Reset state, working sets, solver configuration and the
   timed operation are checked separately (section 7).
6. **Sub-millisecond cases.** Every primary case is sub-millisecond on the Stage 2A machine; Stage 2A
   itself supports no per-case statistical claim. Stage 2B adds paired contemporaneous blocks, which are
   still few (eight per Julia version): they support a description and a screen, not a verdict.
7. **Historical files stay untouched.** The `pre06/` files, the tag `bench-pre06-v1` and the strict
   `compare.py` are never modified or weakened.

## 2. Identities

Identities are kept distinct everywhere in this directory. A moving branch is never an identity.

| Role | Identity |
|:--|:--|
| Historical measured ProximalSolvers source | commit `b0de3f7fc91767b97197ff4b458207e308998943`, tree `a836d532008782e75f2b2a7e4666fa1df24b34dc`, version 0.3.2; package hash `f37fc61f300ad597a33c7ab5f448d38c865db854` |
| Frozen Stage 2A campaign definition | commit `7b9b5295302bd177046284b017a8304cf5a99341`, campaign `pre06-stage2a-v1`; harness hash `b7bf3d953ec6e9f9720e74d7895b5cf95a629fd4` |
| Historical ProximalBase | registered 0.5.4, release tree `1226119eb2cc6144f7345c727f0e7682632f7826`, tag `v0.5.4` at commit `9c5a43bf0b7e3f51f0a401b785c332200ffa5d7e` |
| Historical archive | release `bench-pre06-v1` (read-only), asset `pre06-stage2a-campaign-v1.tar.gz`, 250,886 bytes, SHA-256 `1edd64330606d739acf1d7b4ba0643a4fb6a1366bad4c82393e2ba1ffdcc723e`; receipt [#110 comment 6691882408](https://github.com/mlakolar/ProximalSolvers.jl/issues/110#issuecomment-6691882408) |
| Julia builds | 1.10.13 (commit `e184dd512e35c5a6e036c9aab5e4de5a3345f62d`) and 1.13.3 (commit `67ac47b9cd855e02134d41d5428ac9f2a73f2694`), separate strata |
| Future migrated ProximalSolvers source | a **new explicit commit**; does not exist yet |
| Future ProximalBase 0.6 candidate | a **new explicit commit** (and, once released, its tag); does not exist yet |
| Stage 2B campaign (identity approved and reserved; not yet a freeze, a tag or a release) | campaign `pb06-migration-stage2b-v1`, release tag `bench-pb06-migration-v1`, asset `pb06-stage2b-campaign-v1.tar.gz`; see section 15 |

Stack A and Stack B are defined by these identities and nothing else.

## 3. Stacks A and B

| | Stack A (historical) | Stack B (migrated) |
|:--|:--|:--|
| ProximalSolvers | the historical measured source `b0de3f7` (clean checkout, tree must equal `a836d532...`) | the new explicit migrated commit (clean checkout, tree recorded) |
| ProximalBase | registered 0.5.4 (tree `1226119e...`) | the 0.6 candidate commit (a SHA, never a branch name); registered version if released |
| Harness (`benchmark/`) | its own checkout: the Stage 2A harness, hash `b7bf3d95...` | its own checkout: the same files, except an approved compatibility-only port (P14, `CASE_MAPPING.md`); Stack B records its own true harness hash |
| Dependencies | the Stage 2A Manifests per Julia version, rebuilt from the archived `Project.toml` and `Manifest.toml` of the archive (never re-resolved) | a fresh resolution, then frozen: full Manifest archived; every difference from A's Manifest is listed in a declared-differences file |
| Compat | unchanged (`ProximalBase = "0.5.3"` admits 0.5.4) | explicit, in the migrated commit's `Project.toml`: the compat entry must admit the candidate; never a silent relaxation and never a `[sources]` override standing in for compat (a path override does not bypass compat, ledger #527) |

How they are pinned and verified:

1. **Separate checkouts.** Each stack has its own checkout of ProximalSolvers and its own harness
   directory. Neither is a worktree of the other's working copy. The checkouts are clean (`git status`
   empty, tree hash equal to the recorded tree).
2. **Separate environments.** One Julia environment per stack and per Julia version, each with its own
   depot, so that no precompiled cache or package version leaks between stacks.
3. **Full Manifests.** The resolved Manifest of each environment is archived with its checksum. The A
   Manifests must equal the Stage 2A ones entry by entry (name, UUID, version, tree), as in
   `campaign.toml` (`[julia."1.10"].lock`, `[julia."1.13"].lock`).
4. **Loaded-tree verification.** Every process records, and the campaign verifies before accepting it,
   what was actually loaded: the package root (`PS_EXPECTED_PACKAGE_ROOT`, `benchmark/run.jl:73-77`),
   the git tree hash of the loaded ProximalSolvers and ProximalBase directories, the package version
   (`pkgversion`), and the source fingerprints `proximalsolvers_hash` and `proximalbase_hash`
   (`benchmark/run.jl:117-119`). A mismatch rejects the process; the record is kept and not used.
5. **Same machine contract.** Julia flags, one Julia thread and one BLAS thread
   (`JULIA_NUM_THREADS=1` and `OPENBLAS_NUM_THREADS=1` come from `campaign.toml`, `[settings]`, lines 81-82;
   `benchmark/run.jl:327` requires one Julia thread and `:328` calls `BLAS.set_num_threads(1)` itself), the sampling settings
   (`PS_SAMPLES=100`, `PS_SECONDS=3`, `PS_CASE_SECONDS=60`) and the case filter of Stage 2A
   (`campaign.toml`, `[settings]`) are identical in both stacks.

The only accepted identity differences, and every refused difference, are listed in
[`MIGRATION_COMPARE_SPEC.md`](MIGRATION_COMPARE_SPEC.md).

## 4. Julia strata

Julia 1.10.13 and Julia 1.13.3 are run as two independent strata with their own pilots, A/A controls,
A/B blocks, records and reports. Within a stratum the stacks are paired by block. Across strata nothing
is pooled and nothing is paired; results are reported side by side. The exact builds of Stage 2A are
used (the readiness probes of this preparation ran on 1.10.12 and 1.13.3; they are exploratory and the
pilot repeats them on the exact builds).

## 5. Readiness gates G1-G8

An official campaign may start only when **every** gate G1-G8 is met; pilots and probes may run while gates are
unmet, only as non-official work (section 6). Status from the Phase 0 reading of
GitHub on 2026-11-06 (also in [`READINESS.md`](READINESS.md)), updated for the maintainer's decisions after
PR #215 ([#110 comment 6694764350](https://github.com/mlakolar/ProximalSolvers.jl/issues/110#issuecomment-6694764350)):

| Gate | Requirement | Status |
|:--|:--|:--|
| G1 | A ProximalBase 0.6 candidate commit exists; it is an explicit commit, not a moving branch | **Unmet.** `master` is `0.6.0-DEV` at `233c11cc284284fbd29df487308b4ee962f875a1` and moves; the last tag is `v0.5.4`; no 0.6 candidate commit or tag exists. The probes used that commit as a probe-only commit, not as a candidate. |
| G2 | The migration PRs of ProximalSolvers are merged, each with its own tests | **Unmet.** No open or merged 0.6 migration PR. Open: #162 (symmetric penalty validation), #163 (block step `prox_coordinate!`), #165 (private iterate fields); also #211 and #213, whose relevance is assessed in `CASE_MAPPING.md`. |
| G3 | ProximalSolvers `Project.toml` compat admits the candidate | **Unmet.** Compat is `ProximalBase = "0.5.3"`. |
| G4 | The full ProximalSolvers package suite is green on Julia 1.10 and 1.13 against the candidate | **Unmet.** No candidate, no migrated source. The readiness probe against master (compat widened in a scratch copy only) is exploratory and recorded in `READINESS.md`; it does not satisfy G4. |
| G5 | Integration tests T07 and FT25-FT28 pass against the commit that will be released | **Unmet.** They are release requirements of the ledger; they depend on the owner redesign (#391 Phase 1, not merged). |
| G6 | Invalid-input and contract-failure tests, independent of the benchmark inputs, cover the paths the 19 cases do not exercise | **Unmet.** No such set is identified for the candidate; `CASE_MAPPING.md` lists the paths that the benchmark cannot gate. |
| G7 | The rows of ledger #527 and of ProximalBase #391 that apply are ticked or explicitly dispositioned by the maintainer | **Unmet.** Every row of #527 is unchecked. |
| G8 | The maintainer approves the case mapping and the P14 port, and signs off the mapping re-validated on the pinned candidate | **Approved for implementation and testing of PR B; candidate sign-off outstanding.** The maintainer approved the provisional classification as the pre-candidate audit (18 class A cases, P14 class B, no class C or D) and the single compatibility-only P14 reset port. This is not a finding that any case works or stays equivalent on a 0.6 candidate: all 19 equivalence checks are re-run on the pinned candidate and the maintainer signs off the result before any official measurement. P04, P05 (group layout) and P13 (private cache) stay candidate-dependent verification, not approval. |

Official timing therefore stays blocked while G1-G7 are unmet, and G8 is complete only at the candidate. The
approvals of the maintainer do not change any of G1-G7.

Merged on ProximalBase `master` as of the same reading (context, not gates): the matrix and values
views of Phase 0 (`matrixview`, `activevalues`), the working-set rule for writes (#424, PR #633), the
coordinates view (#425, PR #672), strong zeros (#428, PR #676), real-only checks (#364, PR #626) and
many numerical-contract PRs. **Not merged:** the `SymmetricSparseIterate` redesign (#391 Phase
1a-1d): on that commit it is still an `AbstractMatrix` with the field `p`.

## 6. Stop rule

An official campaign needs all of G1-G8. If any gate is unmet when a campaign would start, **no official
measurement is taken**. The unmet or pending gates are listed in `READINESS.md` and on #110. Probes, pilots
and exploratory runs may go on while gates are unmet, only as non-official work: they are labelled
exploratory, are never counted as official, and are never described as results (the pilots that need a
migrated Stack B cannot start before G1-G3).

During an official campaign, a new non-ok outcome (`target_missed`, `uncertifiable`, `incomplete`,
`timeout`, `error`) in any case, or an invalid block, stops the interpretation of speed for that case:
the outcome is reported first (section 12, category 1). A faster result at worse certified accuracy is
not a speedup.

## 7. Workload-equivalence audit procedure

Performed before any pilot, recorded in `case-mapping.toml`, reviewed by the maintainer (G8).

1. **Per-case fields.** For each of the 19 cases, in the order of `../pre06/cases.txt`: family, phase,
   inputs and seed key, objective, penalty, initial state, working set, reset operation, solver options,
   certificate, measure and target, work counters, the ProximalBase 0.6 changes that the solver call
   path touches (with `src/` line numbers, or the `git grep` that found none), the provisional class,
   the reason, what verification is still needed and the concrete equivalence check.
2. **Classes.** A: equivalent, unchanged harness. B: equivalent with a reviewed compatibility-only
   harness port. C: semantically changed; requires a separate mapping. D: not comparable or failed. A
   class is provisional until the candidate exists. No class is ever assigned on the strength of a
   `data_hash` match.
3. **Reviewed port in its own narrow PR.** A class B port changes only what 0.6 requires, lists every
   changed line, and goes through its own PR and maintainer approval. Today there is one: P14, approved by
   the maintainer for implementation and testing in PR B (#110 comment 6694764350). The harness reset of the
   iterate `fill!(x, 0.0)` becomes `dropzeros!(fill!(x, 0.0))` for the `SparseIterate` of the lasso path, which
   is the identical operation on ProximalBase 0.5.4 (probe) and restores the cold start on master; the dense
   `Vector` of the two SLOPE paths keeps `fill!(x, 0.0)`. The approval is conditional: the equivalence is
   re-validated on the pinned candidate before official measurement.
4. **Both true harness hashes are preserved.** The port changes the formal harness hash. Stack A keeps
   `b7bf3d95...`, Stack B records its own, taken at the port commit and never written in advance; they are
   never forced equal. The difference is declared in the approved-differences file together with the mapping
   record (`approved`, `approval_url`, `approval_scope`).
5. **Equivalence check, outside every timed region**, per case and per repetition ID used by the pilot:
   the per-array fingerprints of the problem fixture are equal (not only the combined `data_hash`);
   the iterate after `reset!()` (values and active IDs) equals `start` and equals the other stack's; the
   solver RNG state is equal; the printed solver and option fields are equal; the certificate of the
   first and last call is ok at or below the target in both stacks. The concrete list per case is the
   `equivalence_check` field of `case-mapping.toml`.
6. **Open items are open items.** What cannot be known before a migrated solver exists (for example the
   minimizer type of the QUIC path: a dense matrix or a symmetric owner) is recorded as open, not as a
   finding.

## 8. Pilots

Pilots are exploratory. They test that the campaign can run and that the stacks are comparable; they
are never counted as official and their timings are never reported as results.

1. **Stack B correctness pilot**, all 19 cases, on each Julia version: every case runs, certifies at its
   target, and is not `target_missed`, `uncertifiable`, `incomplete`, `timeout` or `error`.
2. **Stack A reproduces its definitions and certificates** on the same machine and Julia versions: the
   catalog, targets and certificate outcomes equal the Stage 2A ones (the reference is
   `historical-reference.tsv`; timings are not compared).
3. **Matched inputs and states.** For each repetition ID, the `data_hash` of A and B match **and** the
   reset states and active IDs, the problem data (per-array fingerprints) and the solver configuration
   are identical, checked outside the timed regions (section 7, item 5).
4. **Achieved accuracy, objective and work counters** are recorded for both stacks (the counters of
   `benchmark/local.jl`, read from the returned result after timing). A descriptive flag, the
   near-target flag, is recorded per case and block. For a finite positive target `t` and a valid certificate
   value `v` it records the continuous `accuracy_fraction = v/t` and the band: `missed/invalid` if the status is
   not `ok`, `v` or `t` is not finite, or `v > t` (the numerical outcome takes precedence); `near target` if
   `0.9 <= v/t <= 1` (within 10% below the target, not a factor of ten); `margin` if `0 <= v/t < 0.9`. The
   actual value and target are always reported with it. The flag is diagnostic only: it is not an additional
   accuracy threshold and not a performance gate (maintainer decision, section 18).
5. **Reset-correctness probes** (`probes/`) are repeated on the exact builds and on the candidate
   commit: the P14 reset, the P04/P05 `AtomIterate` reset, the P13 private names, the symmetric-matrix
   validation and the owner type.
6. **Runtime and contention.** Wall time of a block, load average, the frequency policy and any
   disturbance are recorded, so that the A/A and A/B campaigns can be planned and so that conditions of
   section 10 can be checked.
7. **Status.** Everything in this section is labelled exploratory in the records and in the report.

## 9. A/A control

Purpose: describe the observed per-case spread of the paired design before the A/B campaign: the
variation between two **independent installations built the same way**, run in the same blocks, with the
same inputs and the same hardware policy. Nothing else is read from it.

* **What runs.** Two **independent installations of Stack A**, each built exactly the way Stack A and Stack
  B are built (section 3): its own checkout, its own environment, its own depot and its own precompile
  caches. They are labelled with the roles "A" and "B" of the design and each writes to its own output
  directory (the harness refuses to overwrite records, `benchmark/run.jl:270-271`). Two processes of one
  installation are **not** an A/A control: installation-level effects (package images, code layout, depot
  paths, the precompile state) would then be absent from the A/A range yet present, with one sign, in
  all eight A/B blocks, and would be read as a difference between the stacks. The two installations must
  have identical identity: source commit and tree, ProximalBase commit and tree, Manifest.
* **Blocks.** Eight fresh-process blocks per Julia version, repetition IDs 1-8. Block `i` uses repetition ID `i`
  for both processes, so the A/A blocks see the same generated inputs as the A/B blocks of the same ID
  (`PS_REPETITION` accepts 1 to 10, `benchmark/run.jl:63-64`; eight is within the cap). The blocks are executed in
  this order by repetition ID, identical for the A/A and the A/B campaign:

  | Repetition ID | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
  |---|---|---|---|---|---|---|---|---|
  | Order | AB | BA | BA | AB | BA | AB | AB | BA |

  Four AB and four BA blocks; each order gets two odd and two even repetition IDs, and also two early (IDs 1-4)
  and two late (IDs 5-8) blocks. The machine-readable definition, read by the comparison tool and its tests, is
  [`schedule.toml`](schedule.toml).
* **Hardware policy.** Identical to section 10.
* **When.** Before the A/B campaign, on the same machine state policy, and recorded the same way.
* **Use.** The eight per-block time ratios of each case (role B over role A) give the observed A/A range
  for that case. They are used only to define the descriptive screens of section 12. Eight blocks cannot
  bound the noise: the range is an observation, not an interval, and no calibrated confidence bound.

## 10. A/B campaign

* **Blocks.** Eight paired blocks per Julia version. Block `i` runs Stack A and Stack B on repetition ID
  `i`, so both stacks see the same generated inputs and, because the case order inside a process is
  `shuffle!(scenario_rng(rep, "measurement_order"))` (`benchmark/run.jl:281`), the same case order.
* **Order.** The schedule of section 9, by repetition ID: AB, BA, BA, AB, BA, AB, AB, BA (A then B, or B then
  A). It is the same for the A/A and the A/B campaign. The schedule is balanced overall (four AB, four BA) and
  over odd and even repetition IDs (two odd and two even IDs for each order), so order is not aliased with the
  parity of the repetition ID. An order effect and an input effect are still not estimated separately by the
  screens.
* **Processes.** A fresh Julia process per stack and per block. One Julia thread and one BLAS thread.
* **Hardware.** The pinned CPU policy of Stage 2A is used for continuity only if it is still quiet and
  topologically unchanged: performance-core logical CPU 6 of the i9-13900, with its SMT sibling
  (logical CPU 7) monitored, taskset to that CPU (`campaign.toml`, `[machine]`). Otherwise an equivalent
  exclusive core of the same core type and policy is used and the change is recorded (in `schedule.toml`
  before the freeze). For every block record the SMT sibling occupancy, the frequency governor, the
  energy-performance preference, turbo state, load average, frequencies and temperatures where available.
* **Preservation.** Raw samples, statuses, outliers, timeouts and failures are all preserved. Disturbance
  is recorded, never used to drop a block selectively. A block is excluded only by a rule fixed before
  the campaign and applied to both stacks and all cases; excluded blocks stay in the archive and in the
  report with their reason.

## 11. Pre-specified extension rule

If an important primary case is inconclusive after the eight blocks, a separately preregistered
**extension** may be run, and only as a **new evidence series** with its own campaign identity and archive
entry; an extension beyond ten blocks (the cap below) needs a new preregistered series in any case. The
extension extends every case equally, or follows a rule fixed before the extension starts. It never extends
only the favourable cases, and its results never replace or relabel the eight-block series. The preregistration
states the number of blocks, the order scheme and the reporting rules, and is posted on #110 before any
extension timing is taken.

`PS_REPETITION` is capped at 10 (`benchmark/run.jl:63-64`), and the repetition ID selects the generated
inputs and the case order. The eight-block series uses IDs 1-8, so at most two further IDs (9 and 10) exist.
Blocks beyond ten therefore either **reuse repetition IDs**, with identical inputs and identical case order, so
that those blocks are not independent draws of the inputs; or they are impossible without editing `run.jl`,
which would change the harness hash of both stacks and is not allowed inside this campaign. The extension
preregistration must say which of the two applies, and, if IDs are reused, how the repeated IDs are assigned to
the blocks.

## 12. Reporting

Per case, Julia version and block, from the process medians of the records (`median_ns`, the Stage 2A
statistic):

* the ratio `rho = time_B / time_A`, per block, and the absolute change in nanoseconds;
* the geometric mean of the per-block ratios and the descriptive range (minimum and maximum), per Julia
  version;
* the achieved certificate value and target with the near-target flag of section 8 (the continuous
  `accuracy_fraction` and the band), and the work counters (iterations, passes, calls) of both stacks;
* Julia allocations (bytes per call) and, separately, process RSS, each interpreted on its own (heap
  bytes and RSS mean different things);
* the hardware status of each block (section 10) and **every** failed or invalid block;
* the descriptive Stage 2A means, in a **separate** table labelled historical (section 1, item 2).

**Categories.** Each case is assigned to one of six categories, following the decision matrix of
`../pre06/STAGE2_PLAN.md` (section 7.4). The screens that separate them are operational and
case-specific, taken from the A/A control of the same Julia version; they are **descriptive investigation
screens, not tests**: no 5% default, no significance level or error rate, no noninferiority or no-regression
claim, and the observed A/A ranges are no calibrated confidence bounds. For one case and Julia version, let
`rho_i = time_B / time_A` (process medians) over the eight A/B blocks, and let the eight A/A ratios be the
role-B over role-A process medians of the A/A blocks of the same case and version.

| # | Category | Operational screen |
|:--|:--|:--|
| 1 | Failed or invalid | Any non-ok status, target missed, uncertifiable, incomplete path, timeout or error, or an invalid block, in either stack. Reported first; no timing is interpreted for the case. |
| 2 | Not comparable | Class C or D in `case-mapping.toml`, an approved semantic deviation of the mapping, or a reset-state or solver-configuration fingerprint that differs or is missing (`MIGRATION_COMPARE_SPEC.md`, section 6). Needs an explicit remapping. A refused difference (changed ID, phase, target, measure, `data_hash`, inputs, fixture, timed operation) is not a category: it refuses the whole comparison. |
| 3 | Screened slowdown at matched certified accuracy | **Screened slowdown:** `rho_i > 1` in all eight blocks, both execution orders are represented (they are, by the schedule, if all eight blocks exist), and the geometric mean of the eight `rho_i` is above the largest of the eight A/A ratios of that case and Julia version. It is a screen result, not a reproduced effect. Triggers the diagnosis of section 13 and a maintainer disposition. |
| 4 | Inconclusive | Everything else: `rho_i` of mixed sign, or a geometric mean inside the observed A/A range, or one block driving the result; and **screen not evaluated** when there is no A/A evidence for the case (never a silent pass). The mirror of category 3, a **screened speedup** (`rho_i < 1` in all eight blocks, both orders represented, and the geometric mean of the eight `rho_i` below the smallest of the eight A/A ratios of that case and version), is reported as such, labelled a screen result, and is never offset against slowdowns. |
| 5 | Allocation or RSS change without timing evidence | A difference in allocated bytes per call or in process RSS with the timing category 4 or better. Investigated independently. |
| 6 | Sign-off candidate | No case of category 1, 2 or 3 among the 14 primary cases and no unexplained major loss among the diagnostics. Stage 2B can then be proposed for sign-off; the ledger gates still apply and the sign-off is the maintainer's. This category is no noninferiority or no-regression claim: absence of a screen result in eight blocks says nothing about a difference smaller than the observed noise. |

Properties of the screens, stated so that they are not over-read: 19 cases in 2 Julia strata give **38
screens**, and some flags are expected by chance alone; the screen compares an eight-block geometric mean
with the extreme of eight A/A ratios, which is conservative for a real difference near the noise and says
nothing about one smaller than it; and the schedule is balanced overall (four AB and four BA blocks) and over
odd and even repetition IDs (two odd and two even IDs for each order), so order is not aliased with the parity
of the repetition ID in either the A/A or the A/B series. The tool (`MIGRATION_COMPARE_SPEC.md`) assigns the
classes and the screens; the categories 5 and 6 are the maintainer's reading of its lists.

Presentation rules: intervals, where shown, are descriptive; none is presented as a noninferiority test;
a ratio of cases that mix `call`, `workspace` and `setup` phases is not formed; and nothing is averaged
across Julia versions.

## 13. Regression diagnosis

For every case in category 3, and for every material difference the maintainer asks about, in this
order:

1. Validity: the records of both stacks are complete and ok, the certificates are valid, and no block is
   disturbed.
2. Workload equivalence: fixture fingerprints, reset states and active IDs, solver configuration (section
   7); then the class of the case.
3. Hardware: SMT sibling, load, frequency and temperature of the blocks in question.
4. Work: iteration, pass and call counters of both stacks at matched certified accuracy. A difference
   in work is a different workload for the solver, whatever the time.
5. Cost per unit of work: time divided by the counter, and the share of garbage collection.
6. Allocations and process RSS, interpreted separately.
7. Setup, precompilation and first-call time (never part of the timed region) to rule out confusion.
8. **Isolation experiments**, preregistered one at a time before they run: for example the migrated
   solver on the old ProximalBase if the migration admits it, or a revert of one migration change. Only
   an isolation experiment can attribute a difference to a part of the stack.

Exploratory numbers, such as local fast-loop timings, are never formal evidence. The maintainer's
disposition is recorded for every material unresolved slowdown.

## 14. Larger-diagnostic tier (separate preregistration)

The 19 cases are sub-millisecond. A **separate, preregistered** tier of 3-5 end-to-end workloads of tens
of milliseconds, selected from actual solver usage and from migration risk **before any timing is
seen**, may complement them. It never replaces or relabels the 19, has its own case list, mapping,
certificates, blocks and report, and its conclusions are kept separate. It is not specified further here.

## 15. Evidence archive and gates

**Identity (approved and reserved by the maintainer, #110 comment 6694764350):** campaign
`pb06-migration-stage2b-v1`; GitHub release tag `bench-pb06-migration-v1`; asset
`pb06-stage2b-campaign-v1.tar.gz`. The identifiers are reserved; this is not yet a freeze, a tag or a release.
The Stage 2A release `bench-pre06-v1` and its tag are never touched.

**Contents.** The campaign definition and mapping (frozen files, with their hashes), both stacks'
identities, Manifests and declared-differences file, the pilots' records, the A/A records, the A/B
records (raw samples, metrics, catalogs, errors, metadata), the hardware records per block, the fixture
fingerprint files, the reset and state probes, the migration comparison report, the checksums of every
file, and the receipt.

**Retrieval.** The asset is downloaded independently, its SHA-256 is compared with the receipt on
#110, and the verifier is run on the extracted copy before anything is reported.

**Review and freeze gates.**

* **F1-B (freeze).** The specification (`MIGRATION_COMPARE_SPEC.md`), the mapping, the schedule
  (`schedule.toml`, a pre-freeze draft until then), the repetition count (eight A/A and eight A/B blocks per
  Julia version), the order scheme, the screens and the reporting rules are frozen and posted on #110
  with the exact commit SHA **before** the official campaign. Any later change is a new campaign
  identity; the old one and its evidence are kept.
* Between the pilots and the official campaign: the maintainer approves the mapping (G8) and the P14
  port.

## 16. PR split

| PR | Content |
|:--|:--|
| A (merged as #215) | The methodology, the case mapping, the readiness record, the probes and checkers, the historical reference and the specification of the comparison reader. Documents, probes and offline Python tests only. |
| B (this work, #216) | The approved compatibility-only P14 harness port (changing only what 0.6 requires, with its Julia test), the amendment of the specification and of this plan for the eight-block schedule, `schedule.toml`, and the implementation of `migration_compare.py` per its specification with synthetic fail-closed tests. No official measurement. |
| Migration PR(s) | The ProximalSolvers migration itself, tracked by ledger #527 and by #162, #163 and #165. Separate from #110. |
| C | The evidence receipt: archive checksums, the verified report and the final disposition record. |

## 17. Planned measurement effort

This section is an **estimate** made from the Stage 2A wall times in the archive's receipts
(`julia-1.10|1.13/receipt.jsonl`), for the eight-block schedule of section 9; it is not a measurement of
Stage 2B.

* Stage 2A, five repetitions of the 19 cases on Julia 1.10.13, from the start to the last record
  (receipt timestamps 17:33:19 to 17:36:46 UTC, including setup, work counters and first-call
  receipts): 3 min 27 s; on Julia 1.13.3: 17:36:46 to 17:40:44 UTC, 3 min 58 s.
* One repetition process: about 13.0 s on 1.10.13 and about 16.5 s on 1.13.3 (differences of the
  `rep0N` command timestamps in the same receipts). Stack A's setup took 21.7 s on 1.10.13 and 15.1 s on
  1.13.3. The work-counter process took 14.0 s on 1.10.13 and 17.2 s on 1.13.3, and the 19 first-call
  processes 4.4-6.0 s each on 1.10.13 (101.5 s together) and 5.0-7.1 s each on 1.13.3 (117.1 s together).

| Item | Processes | Estimated process time |
|:--|:--|:--|
| A/A, 8 blocks x 2 processes, per Julia version | 16 + 16 | 16 x 13.0 s + 16 x 16.5 s = 472 s (about 8 min) |
| A/B, 8 blocks x 2 processes, per Julia version | 16 + 16 | 16 x 13.0 s + 16 x 16.5 s = 472 s (about 8 min) |
| Total of the two campaigns | 64 | 944 s, about 16 min of measured process time |

Not included, and to be added by the operator: **the second, independent Stack A installation of the A/A
control** (section 9) on each Julia version, built like Stack A and Stack B (at least the Stage 2A setup
figures above, 21.7 s and 15.1 s, as a lower bound, plus its first precompile), Stack B's own setup and
precompilation of the candidate on each Julia version (not known; the Stage 2A figures are a lower bound), loaded-tree and fixture
verification, the hardware checks between blocks, a quiet-machine wait before each process (up to 300 s
per repetition in the Stage 2A policy; in Stage 2A the repetitions ran back to back), the pilots, and
the exploratory work-counter and first-call receipts (in Stage 2A: counters 14.0 s on 1.10.13 and 17.2 s on
1.13.3; 19 first-call processes of 4.4-6.0 s on 1.10.13 and 5.0-7.1 s on 1.13.3). A planning allowance of one to two hours of exclusive machine time for both
campaigns, excluding the larger-diagnostic tier, is reasonable; it is an allowance, not a promise.

## 18. Maintainer decisions needed

Decided by the maintainer after PR #215 ([#110 comment 6694764350](https://github.com/mlakolar/ProximalSolvers.jl/issues/110#issuecomment-6694764350)):

1. The evidence archive identity (section 15): approved and reserved, not yet a freeze, a tag or a release.
2. The case mapping and the P14 port (G8): approved for implementation and testing of PR B as the
   pre-candidate audit; candidate-specific re-validation and sign-off remain required before any official
   measurement.
3. The near-target flag (section 8, item 4): decided, as a descriptive and diagnostic rule only.
4. The screens of section 12: approved as descriptive investigation screens, not as a significance test or a
   noninferiority rule.
5. The budget: eight A/A and eight A/B blocks per Julia version with the schedule of section 9. If an
   execution constraint makes eight blocks impossible, it is reported before any official data is collected.

Still open:

6. The hardware policy for the official campaign: continue on logical CPU 6, or an equivalent exclusive
   core, if the machine has changed.
7. The preregistration of an extension (section 11), if one is ever needed.
8. The workloads of the larger-diagnostic tier (section 14).
9. Which ProximalBase 0.6 candidate commit, and which migrated ProximalSolvers commit, define Stack B.
10. The disposition of every material unresolved slowdown (section 13).
11. The order of work with the migration PRs (#162, #163, #165) and with ProximalBase #391.
