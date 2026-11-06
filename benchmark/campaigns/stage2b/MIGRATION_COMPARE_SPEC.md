# Specification of `migration_compare.py` (PR B of Stage 2B)

Part of #110. This file is a **specification only**: nothing in this directory implements the tool. The
implementation is PR B of the split in [`STAGE2B_PLAN.md`](STAGE2B_PLAN.md) (section 16) and is written
and reviewed against this text. The methodology, the stacks and the reporting categories are in
`STAGE2B_PLAN.md`; the per-case mapping is [`case-mapping.toml`](case-mapping.toml).

## 1. Why a separate tool

The ordinary comparison, `benchmark/compare.py`, compares two revisions of the same stack under strict
conditions: `validate.py` requires the settings in `MATCH_SETTINGS` (`benchmark/validate.py:25-33`) to
agree, including `harness_hash`, `proximalbase_version` and `proximalbase_hash`, and `compare.py` refuses
any difference in catalog definition or `data_hash` (`benchmark/compare.py:62-75`). A migration
comparison necessarily differs in ProximalBase, in ProximalSolvers and possibly in the harness hash, so
the ordinary tool correctly refuses it. That refusal is a feature and stays: **`compare.py` and
`validate.py` are never changed, never weakened and never parameterized for this use.**
`migration_compare.py` is a separately named tool whose allowlist of differences is narrow, explicit and
declared, and which refuses everything else.

It reads records only. It runs no Julia, needs no network and writes only to a fresh output directory.

## 2. Inputs

```
migration_compare.py --a ROOT_A --b ROOT_B --mapping case-mapping.toml
                     --declared-differences FILE --receipt FILE [--aa ROOT_AA_A ROOT_AA_B]
                     [--fingerprints-a FILE] [--fingerprints-b FILE] --out DIR
```

* `ROOT_A`, `ROOT_B`: two campaign roots in the layout of the Stage 2A archive (per Julia version the
  `raw/julia-<version>-repNN-*` records, `Manifest.toml`, `Project.toml`, the environment inventory and
  the hardware records). A root holds one stack. Each root is first validated with the **unmodified**
  record checks of `validate.py` for everything that does not concern the accepted differences of
  section 3 (file set, headers, statuses, statistics, finished metadata).
* `--receipt`: the campaign receipt of the Stage 2B campaign, a JSON-lines file in the style of the
  Stage 2A `receipt.jsonl` (one event per line with a UTC time stamp). It records the campaign identity
  and, for every process, its stack, Julia version, block, repetition ID and its start and finish times.
  The block order is taken from it: the `run.jl` metadata records no start time stamp (it has `elapsed_s`
  and the finish flag only), so the record files alone cannot say which stack ran first.
* `--mapping`: `case-mapping.toml`, including the class and the approval record of every case.
* `--declared-differences`: a TOML file with the dependency and Manifest differences and the approved
  compatibility-only harness change (section 3, items 3 and 4).
* `--fingerprints-a`, `--fingerprints-b`: the fixture and state fingerprint files of each stack
  (section 6). Defaults: `fingerprints.tsv` in each root.
* `--aa ROOT_AA_A ROOT_AA_B`: optionally the roots of the A/A control (two independent installations of the same Stack A, each built the way Stack A and Stack B are built), used
  only for the descriptive screens of `STAGE2B_PLAN.md` section 12. The A/A pair is checked with the same
  rules, and must have identical stack identity (source commit and tree, ProximalBase commit and tree, Manifest) on both sides, with installation roots, environments and depots that are distinct.
* The tool is told the Julia strata present in each root and compares **each stratum separately**: a
  Julia 1.10 record is never compared with a Julia 1.13 record (section 4, item 1).

## 3. Accepted identity differences, and nothing else

Exactly these may differ between the roots:

1. **ProximalSolvers source:** `proximalsolvers_sha` and `proximalsolvers_hash` (already outside
   `MATCH_SETTINGS`), with the migrated commit recorded as a full 40-hex SHA and a clean tree
   (`proximalsolvers_dirty = false`).
2. **ProximalBase:** `proximalbase_version`, `proximalbase_hash`, and the commit SHA and git tree hash
   in the environment inventory. Stack B's ProximalBase must be an explicit commit SHA, never a branch.
3. **Declared dependency and Manifest differences**, listed entry by entry in the declared-differences
   file (name, UUID, version and tree on each side, and a reason). The set of differences found between
   the two archived Manifests must equal the declared set exactly: an undeclared difference and a
   declared difference that is absent are both refused.
4. **An approved compatibility-only harness hash change**, with its mapping record: `harness_hash` may
   differ only if `case-mapping.toml` lists class B cases with an approval record, and the declared
   file gives the harness hash of each side, the port's commit, and the list of changed lines. Both true
   hashes are recorded and never forced equal. Without an approved record, a differing `harness_hash`
   is refused.

Everything not named above must be equal.

## 4. Refused differences

A refusal is a **global** refusal: the tool prints one line `REFUSED:<CLASS> <field>: <detail>`, writes
`refusals.json` with every refusal found (not only the first), writes no comparison, and exits with
status 2. Usage errors and unreadable inputs exit with status 3. The classes:

| # | Refused difference | Fields checked | Class |
|:--|:--|:--|:--|
| 1 | Julia version or build | `julia`, the build commit and the Julia stratum of each record set; a stratum present in one root and missing in the other | `JULIA` |
| 2 | `data_hash` or generated inputs | `data_hash` of every (Julia, case, repetition) pair; `seed_scheme`; the repetition's input generation (fingerprint files, section 6) | `INPUTS` |
| 3 | Accuracy target or measure | `measure` and `target` of every case, in the catalog, the metrics and the mapping | `TARGET` |
| 4 | Case ID or role | the 19 IDs in `cases.txt` order and the primary/diagnostic roles, against `case-mapping.toml` | `CASE` |
| 5 | Phase | `phase` of every case (call, workspace, setup) | `PHASE` |
| 6 | Timed operation | the catalog fields `problem`, `solver`, `variant`, `suite`, `inputs`; the solver-configuration fingerprints; the identity of the certificate file where the certificate runs inside the timed region (D04) | `OPERATION` |
| 7 | BLAS or thread settings | `julia_threads`, `blas_threads`, `blas`; other than one and one | `THREADS` |
| 8 | Machine identity | `cpu_model`, `cpu`, the logical CPU and the frequency policy recorded in the hardware records, the machine inventory | `MACHINE` |
| 9 | Repetition index set | the set of repetition IDs per Julia version in **each** root must equal the declared set of the frozen campaign (A/B: 1-5; A/A: 1-6), with each ID once per stack. A root whose set differs from the declared set is refused, whether the other root differs from it in the same way or not: two roots that both lack the same declared ID are a `REPETITIONS` refusal, not a per-case FAILED | `REPETITIONS` |
| 10 | Approved case mapping | a case missing from `case-mapping.toml`, a class other than A or B without a separate approved mapping, a class B case without its approval record, a case whose mapping `id`, `role` or `phase` differs from the records | `MAPPING` |
| 11 | Record schema | the headers of the catalog, metrics, samples and errors files, the metadata keys, the schema version of the declared-differences file | `SCHEMA` |
| 12 | Undeclared source or dependency difference | any difference not in section 3 (`harness_hash` without an approval, a Manifest entry not declared, a changed compat entry not declared) | `UNDECLARED` |
| 13 | Sampling settings and selection | `suite`, `groups`, `case_filter`, `samples_target`, `seconds_limit`, `case_seconds`, `profile_seconds` | `SETTINGS` |
| 14 | Unclean or unverified stack | `proximalsolvers_dirty`, a loaded-tree mismatch (`proximalsolvers_path` against the expected root, tree hashes against the recorded ones), an unfinished process | `STACK` |
| 15 | Unfrozen identity | the ProximalSolvers and the ProximalBase identity of each stack must each be a full 40-hex commit SHA with a recorded git tree hash. A branch name, a short SHA or a tag-only identity is refused. The historical Stack A tag `v0.5.4` is accepted only as the tag commit SHA (`9c5a43bf0b7e3f51f0a401b785c332200ffa5d7e`) together with the release tree (`1226119eb2cc6144f7345c727f0e7682632f7826`) | `IDENTITY` |
| 16 | Wrong block order or mixed campaigns | from the campaign receipt (the metadata has no start time stamp): each A/B block's order must equal the frozen schedule AB, BA, AB, BA, AB, and each A/A block's order AB, BA, AB, BA, AB, BA; A and B must belong to one contemporaneous campaign identity and session; a Stack A root taken from another campaign or session, or a block whose processes the receipt does not place in the declared order, is refused | `ORDER` |

A comparison that is refused is invalid **even when every timing number is finite**: no timing is read
before the refusals are evaluated.

## 5. Outputs

All outputs go to a fresh `--out` directory (the tool refuses a non-empty one, as `fresh_output` of
`validate.py` does).

**Precedence.** Section 4 is evaluated first and always wins: a refusal is a property of the pair of roots
and no per-case class is written. In particular a `data_hash` that differs for any (Julia, case,
repetition) pair is the global refusal `INPUTS`, and two roots whose repetition-ID sets differ are the
global refusal `REPETITIONS`. The declared repetition set (A/B 1-5, A/A 1-6) and the declared case set
(the 19 IDs of `cases.txt`) come from the frozen campaign, not from the roots, so a root that lacks a
declared repetition or a declared case is refused (`REPETITIONS`, `CASE`) even when both roots lack the
same one: an equal-but-incomplete pair is a refusal, never a per-case FAILED. The per-case classes below
apply only to what remains after every refusal has been ruled out, and to conditions that concern one
case: its records, its mapping class, its fingerprints.

**Per-case class**, per Julia version, in `migration-comparison.csv`:

* **COMPARABLE**: both stacks have ok records for every repetition in the set; the fingerprints match
  (section 6); the mapping class is A, or B with an approved record; no failed check.
* **NOT COMPARABLE**: the workload is not the same although the records are structurally comparable: a
  fixture, reset-state or solver-configuration fingerprint missing or mismatched while the `data_hash`
  matches (a `data_hash` match is never accepted as proof of identical semantics), a mapping class C or D,
  or an approved semantic deviation recorded in the mapping.
* **FAILED**: a case that is not ok in either stack (`target_missed`, `uncertifiable`, `incomplete` (an
  incomplete path in either stack), `timeout`, `error`), an invalid certificate. A missing case or repetition is not a FAILED
  condition: it is a global refusal (see the precedence paragraph).

**Visible lists**, repeated at the top of `report.md` and in `lists.json`, never hidden in a table and
never summarized away: cases that are not ok, with the status and detail; missing and extra cases and
repetitions per root; invalid certificates; changed inputs; incomplete paths; errors and timeouts;
allocation differences (median and maximum bytes per call, separately from timing); missing diagnostics
(a counter or hardware record that is absent); and the approved semantic deviations of the mapping.

**Per-case numbers**, only for COMPARABLE cases: the per-block ratio `time_B / time_A` of the process
medians, the absolute change, the geometric mean and the descriptive range per Julia version, bytes and
counters of both stacks, and the screens of `STAGE2B_PLAN.md` section 12 computed from `--aa`, each with
its label "screen". Cases of the other two classes show no ratio.

**Reports.** `report.md` states in its first lines that the comparison is a whole-stack comparison, that
no difference is attributed to ProximalBase alone, and that the Stage 2A archive is historical context
and absent from the ratios. The Stage 2A means appear only through `historical-reference.tsv`, in a
separate table. Julia versions are reported side by side, never pooled.

**Exit status.** 0: every case COMPARABLE and ok. 1: a report was written and at least one case is
NOT COMPARABLE or FAILED. 2: refused (section 4). 3: usage error or unreadable input.

## 6. A `data_hash` match is not proof of identical semantics

`data_hash` covers generated arrays only. For every case and stack, a recorded **fixture and state
fingerprint file** must also match. One tab-separated file per stack and Julia version, one row per
`(id, rep, kind, name)`:

| kind | name | value |
|:--|:--|:--|
| `fixture` | each field of the problem (`X`, `y`, `λ`, `w`, `groups`, `S`, `Λ`, `D`, `grid`, ...) | SHA-256 of its bytes (sparse matrices: of `findnz`) |
| `reset` | `values`, `active_ids` | SHA-256 of the iterate's values after `reset!()` and the active IDs |
| `config` | `solver`, `options` | SHA-256 of the printed solver and option fields |
| `file` | `certificates.jl` | SHA-256 (it executes inside the timed call of D04) |

The tool compares the two files key by key. A missing file, a missing key or a different value makes the
case NOT COMPARABLE (and a different `data_hash` is refused earlier, section 4, item 2). The files are
written by the pilots and the campaign outside any timed region (`STAGE2B_PLAN.md` section 7).

## 7. The ordinary tools stay as they are

* `compare.py` and `validate.py` stay unchanged and strict. A test of PR B records the SHA-256 of both
  files at the freeze commit and fails if either changes.
* `migration_compare.py` may import record readers from `validate.py` and `summarize.py`, but it never
  monkeypatches or reconfigures their settings sets, and it does not write into the ordinary tools'
  output formats.
* Its output names differ from those of `compare.py` (`migration-comparison.csv` here has the class column
  and the screens), so that a report cannot be mistaken for an ordinary comparison.

## 8. Required synthetic tests (PR B)

Offline, Python standard library only, on small synthetic roots built by the test. Every test asserts the
exit status and the message class, and uses records in which **all timing numbers are finite**, so that a
pass of the timing alone would wrongly accept.

* One test per refused difference of section 4 (16 tests): Julia version or build; `data_hash` or
  generated inputs; target or measure; case ID or role; phase; timed operation (catalog and
  configuration fingerprint); BLAS or thread settings; machine identity; repetition index set (a missing
  ID in one root, the same missing ID in both roots, a duplicate ID, an extra ID); approved case mapping (missing, unapproved class B, class C without a
  separate mapping, mismatched role); record schema (header, metadata key, declared-file schema);
  undeclared source or dependency difference (an undeclared Manifest entry, a declared entry that is
  absent, a `harness_hash` change without approval); sampling and selection settings; unclean or unverified
  stack; unfrozen identity, class `IDENTITY` (a branch name, a short SHA, a tag name without its commit SHA, a missing tree
  hash; the tag commit SHA plus tree of `v0.5.4` is accepted); wrong block order or mixed campaigns, class `ORDER` (a
  block run B then A in an A-then-B slot, a block missing from the receipt, A and B from different
  campaign identities, a Stack A root from another session).
* Accepted differences: a stack with a different ProximalSolvers SHA and package hash, ProximalBase
  version, SHA and hash, a declared dependency difference and an approved class B harness hash change
  is accepted, and the same pair without the declaration is refused.
* `data_hash` equal but a fixture, reset-state or configuration fingerprint different: NOT COMPARABLE,
  with no ratio in the output. A missing fingerprint file: NOT COMPARABLE.
* Per-case classes: a case with `target_missed` in B: FAILED, listed, no ratio; an incomplete path;
  an invalid certificate; an approved semantic deviation. A repetition missing from both roots is a
  `REPETITIONS` refusal (exit status 2), not a FAILED case, and so is a case missing from both roots (`CASE`).
* A/A mode: identical stack identities on two independent installations accepted, unequal ones refused, two
  processes of one installation refused.
* The visible lists contain every non-ok case, missing and extra case, and every other item of section
  5, and the report starts with the whole-stack statement.
* No Julia versions are pooled: the output of a root with both strata has one set of rows per stratum
  and no row across them.
* The SHA-256 of `compare.py` and `validate.py` equal the recorded values.

## 9. No confidence interval is a noninferiority test

`migration_compare.py` never presents a confidence interval, a screen or a ratio as a noninferiority,
equivalence or no-regression test. Paired intervals are not an approved one-sided test, an interval that
contains 1 is never read as noninferiority, and there is no universal threshold: formal rules are
calibrated by Stage 3 of #110. The screens are labelled screens taken from the A/A control, and a test of
PR B asserts that the report names them as such and contains no claim of noninferiority.
