# Specification of `migration_compare.py` (PR B of Stage 2B)

Part of #110. This file is the contract that `migration_compare.py`, its synthetic fixtures
(`stage2b_fixtures.py`) and its tests (`test_migration_compare.py`) in this directory are written and reviewed
against. Where code and this text disagree, this text wins and the code is wrong. The methodology, the stacks
and the reporting categories are in [`STAGE2B_PLAN.md`](STAGE2B_PLAN.md); the per-case mapping is
[`case-mapping.toml`](case-mapping.toml); the schedule is [`schedule.toml`](schedule.toml).

Sections 1 to 9 state the behaviour; sections 10 to 16 give the exact schemas of every file the tool reads and
writes, each with an example. A key of a schema that is not listed is unknown.

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

It reads records only. It runs no Julia, needs no network, uses only the Python standard library (3.11 or
later, `tomllib`) and writes only to a fresh output directory. Its output is deterministic: it contains no clock
time of the run, no host name of the machine that runs it and no absolute path of the machine that runs it or of
any argument path; absolute paths that occur in the free text of the records are cleaned by the rules below, with the
limits listed after them. Every string the tool writes (refusals, standard error, the
lists, the table and the report) is cleaned once, by these rules, in this order. The text is cut at its URL tokens
(rule 1); only the pieces between them are cleaned (rules 2 and 3), so a URL is a boundary and never part of a path:
a path directly before or after a URL token is a token of its own, and its tag is taken from its own text.

1. A complete URL token is kept verbatim: `<scheme>://` (any scheme except `file`) followed by characters other
   than white space, quotes (`'`, `"`, the backquote) and the brackets `< > ( ) [ ] { }`, so that a query or a fragment stays inside it. A `file://` URL
   names a local path and is cleaned like a path.
2. A path given on the command line is replaced by its label (`<a>`, `<b>`, `<aa_a>`, `<aa_b>`, `<receipt>`,
   `<mapping>`, `<declared>`, `<fingerprints_a>`, `<fingerprints_b>`, `<schedule>`, `<out>`); the rest of its
   token is kept after the label.
3. Every other absolute path token is shown as `basename#tag` (when a URL token follows the token directly, the `/` between them is kept). A path token starts at a `/` (or a run of `/`) that is
   not preceded by a word character, `.`, `-` or `/` (so it may follow `=`, `:`, a quote, a bracket, `|` or a
   comma) and extends over every character up to white space, a quote, a bracket of the set above, or one of `,`, `;`, `|` (so `$`, `~`,
   `#`, `=`, `&`, `?`, `:`, `*` and `!` belong to the token); a lone `/` is not a path. The `basename` is the last
   `/`-component and the `tag` is taken from the SHA-256 of the token text with the leading run of `/` collapsed to
   one and the trailing `/` removed: the first 8 lowercase hexadecimal digits, or, if a different token of the same
   run already has those 8 digits, the shortest longer prefix (12, 16, ... 64 digits) that no different token has,
   for example `ProximalSolvers.jl#3fa9c1d2`. A token keeps the tag it was first given, in every channel of the
   run (one cleaning function serves the whole run), so within one run equal paths print equal tags and different
   paths always print different ones; the tag is 8 digits long unless a collision forces more. Tags are
   deterministic for a given input: they depend on the order of the first cleaning call that meets each token, and
   the tool makes its calls in a fixed order (refusals in sorted order, otherwise the report, the table and the
   lists). The directory part of a token is not printed.

A case ID, a fraction such as `1/2`, `and/or` and a lone `/` are not paths. Only POSIX absolute paths are cleaned
(Windows drive letters, backslashes and `~user` forms are outside the scope: the campaign host is Linux).

**Limits of the cleaning of free text from the records** (they follow from the token rules above and are not
defects of the comparison): (a) a URL of any scheme except `file`, for example `ssh://user@host/path`, is kept
verbatim, host name and path included; (b) a path glued to a word character, `.` or `-` (for example `-L/dir/lib`)
is not a token and is kept; (c) a path whose directory names contain white space, a comma, a semicolon, a pipe, a
quote or a bracket is cut at that character, and the rest remains as a relative fragment; (d) two spellings of one
directory that differ only by `.` or `..` segments print different tags (the STACK and ORDER checks compare them in
normal form, but no message prints both); (e) the tag is an unsalted prefix of a hash of the path text, so a reader
can confirm a guessed path by hashing it: it tells two paths apart, it does not hide a guessable one. The text of the
records of a campaign is campaign data that is already in the archive; the cleaning protects the paths of the
machine that runs the tool and keeps the output deterministic.

## 2. Inputs

```
migration_compare.py --a ROOT_A --b ROOT_B --mapping case-mapping.toml
                     --declared-differences FILE --receipt FILE [--aa ROOT_AA_A ROOT_AA_B]
                     [--fingerprints-a FILE] [--fingerprints-b FILE] [--schedule FILE] --out DIR
```

* `ROOT_A`, `ROOT_B`: two campaign roots, Stack A and Stack B, in the layout of section 10 (the Stage 2A archive
  layout plus `stack-identity.toml`). A root holds one stack. Each stratum of each root is first validated with
  the **unmodified** `validate.validate` of `benchmark/validate.py` (section 4.1, rule R1).
* `--receipt`: the campaign receipt (section 12), a JSON-lines file with one event per line. The block order is
  taken from it: the `run.jl` metadata records no start time stamp (it has `elapsed_s` and the finish flag
  only), so the record files alone cannot say which stack ran first.
* `--mapping`: `case-mapping.toml` (section 4.1, rule R10, and the keys `approved`, `approval_url`).
* `--declared-differences`: the declared-differences file (section 13).
* `--fingerprints-a`, `--fingerprints-b`: the fixture and state fingerprint files of each stack (sections 6 and
  14). Default: `fingerprints.tsv` in the respective root. A file that does not exist, whether it is the default
  or a named one, is a missing file (every case NOT COMPARABLE, section 6), not a usage error.
* `--aa ROOT_AA_A ROOT_AA_B`: optionally the roots of the A/A control: two independent installations of the same
  Stack A, each built the way Stack A and Stack B are built. Used only for the descriptive screens of
  `STAGE2B_PLAN.md` section 12. The A/A pair is checked with the same record rules as the A/B pair (JULIA,
  INPUTS for `data_hash`, TARGET, CASE, PHASE, OPERATION for the catalog, THREADS, MACHINE, REPETITIONS, SCHEMA,
  SETTINGS, STACK, IDENTITY) and with the A/A rules of section 12. No fingerprint file is read for the A/A pair.
* `--schedule`: default `schedule.toml` in the directory of the tool (section 16). It is the single
  machine-readable definition of the repetition IDs, the block orders, the sampling settings, the machine
  policy, the Julia builds and the Stack A identity. The tool contains no copy of these values.
* `--out`: a fresh directory (the tool refuses an existing non-empty one, as `fresh_output` of `validate.py`
  does).
* Read-only files next to the tool: `historical-reference.tsv` (only for the separate historical table of
  `report.md`, section 15) and, two directories up, `validate.py` and `summarize.py` (`benchmark/`), imported
  without modification.

The tool compares **each Julia stratum separately**: a Julia 1.10 record is never compared with a Julia 1.13
record. The strata are the keys of `[julia.*]` in `schedule.toml`.

**Declared sets.** The declared case list is the comma-separated `case_filter` of `schedule.toml` `[settings]`
(the 19 IDs of `../pre06/cases.txt`, in that order; the first 14 are the `primary` role, the last 5 the
`diagnostic` role). The declared repetition IDs are `reps` of `schedule.toml` (1 to 8). Both come from the
frozen schedule, never from the roots.

**Exit status.** 0: a comparison run wrote a report and every case of every stratum is COMPARABLE (`--help` also
exits 0, without a report). 1: a report was written
and at least one case is NOT COMPARABLE or FAILED. 2: refused (section 4). 3: a usage error, unreadable input or an
internal error of the tool (an uncaught exception is reported as `INTERNAL ERROR: <exception type>: <message>` on
standard error, the message cleaned as above and cut to 200 characters, and nothing further is written, so that the status is never the interpreter's default 1); a usage error: an argument file
that exists but cannot be read or decoded as UTF-8 text, or an absent `--mapping`, `--declared-differences`,
`--receipt` or `--schedule` file, or a TOML argument file (`--mapping`, `--declared-differences`, `--schedule`)
that is not valid TOML; or `--out` not fresh; nothing is written. A file whose syntax is valid but whose content
violates its schema (a receipt line that is not a JSON object, a fingerprint row with the wrong field count, a
missing key) is a `SCHEMA` refusal, and an absent or unparseable file inside a root is a refusal as well
(section 4.1).

## 3. Accepted identity differences, and nothing else

Exactly these may differ between the roots, and each must be declared (section 13):

1. **ProximalSolvers source:** `proximalsolvers_sha` and `proximalsolvers_hash` of the metadata, and the commit and
   tree of `stack-identity.toml`, with the migrated commit recorded as a full 40-hex SHA and a clean tree
   (`proximalsolvers_dirty = false`).
2. **ProximalBase:** `proximalbase_version`, `proximalbase_hash`, and the commit SHA and git tree hash of
   `stack-identity.toml` and of the environment inventory. Stack B's ProximalBase must be an explicit commit SHA,
   never a branch.
3. **Declared dependency and Manifest differences**, listed entry by entry in the declared-differences file
   (name, UUID, version and tree on each side, and a reason). The set of differences found between the two
   archived Manifests of a stratum must equal the declared set exactly: an undeclared difference and a declared
   difference that is absent are both refused. The same holds for the `[compat]` entries and the `[deps]` of the
   environment `Project.toml`.
4. **An approved compatibility-only harness hash change**, with its mapping record: `harness_hash` may differ
   only if `case-mapping.toml` lists class B cases with an approval record, and the declared file gives the
   harness hash of each side, the port's commit, and the list of changed lines. Both true hashes are recorded and
   never forced equal. Without an approved record, a differing `harness_hash` is refused.

**Treatment of every metadata key** (the keys of `START_KEYS`, `FINAL_KEYS` and `case_filter` of
`benchmark/validate.py`; any other key, or a missing one, is a `SCHEMA` refusal):

| Key | Treatment | Class on violation |
|:--|:--|:--|
| `julia` | equal to `schedule.toml` `[julia.*].version` of the stratum | `JULIA` |
| `suite`, `groups`, `case_filter`, `samples_target`, `seconds_limit`, `case_seconds`, `profile_seconds` | equal to `[settings]` of the schedule (numbers compared as numbers) | `SETTINGS` |
| `seed_scheme` | equal to `[settings]` of the schedule | `INPUTS` |
| `julia_threads`, `blas_threads` | equal to 1 and to `[settings]` | `THREADS` |
| `blas` | equal between the roots of a pair | `THREADS` |
| `cpu_model`, `cpu` | equal to `[machine]` of the schedule (`cpu` of the stratum) | `MACHINE` |
| `harness_hash` | equal between A and B unless declared (section 13); Stack A equal to `[stack_a].harness_hash` | `UNDECLARED`; `IDENTITY` |
| `proximalsolvers_sha`, `proximalsolvers_hash`, `proximalbase_version`, `proximalbase_hash` | the A value and the B value equal the declared pair | `UNDECLARED` |
| `proximalsolvers_sha`, `proximalbase_version` | also equal to `stack-identity.toml` | `STACK` |
| `proximalsolvers_dirty` | `false` | `STACK` |
| `proximalsolvers_path`, `expected_package_root` | `validate.py` checks them against each other; the tool additionally requires `expected_package_root` non-empty and `proximalsolvers_path` equal to `proximalsolvers_dir` of the inventory | `STACK` |
| `rep`, `finished`, `cases`, `ok_cases`, `nonok_cases`, `elapsed_s`, `maxrss_bytes`, `job_id` | per process; not compared between roots (`rep`, `finished`, the counts and `elapsed_s` are used as stated in sections 5 and 12) | |

Everything not named above must be equal. The values of the keys that are checked against the declared set or
against `stack-identity.toml` must be the same in every repetition and in both strata of one root; otherwise the
root is a mixed stack (`STACK`, field `<root>:mixed`).

## 4. Refused differences

A refusal is a **global** refusal: the tool prints one line `REFUSED:<CLASS> <field>: <detail>` on standard
error for every refusal found (not only the first), writes `refusals.json` with every refusal, writes no
comparison, and exits with status 2. Usage errors and unreadable inputs exit with status 3. The classes:

| # | Refused difference | Fields checked | Class |
|:--|:--|:--|:--|
| 1 | Julia version or build | `julia` of every metadata record, `julia` and `commit` of the environment inventory and `julia_version` of the Manifest, each against `schedule.toml` `[julia.*]`; a record file named for another version; a stratum present in one root and missing in the other, or present in a root and not in the schedule | `JULIA` |
| 2 | `data_hash` or generated inputs | `data_hash` of every (Julia, case, repetition) pair; `seed_scheme`; any mismatch of a `fixture` fingerprint row (section 14) | `INPUTS` |
| 3 | Accuracy target or measure | `measure` and `target` of every case, in the catalog, the metrics and the mapping | `TARGET` |
| 4 | Case ID | A declared case missing from either root, including a case absent from both. A case present in a root that is not declared (extra). | `CASE` |
| 5 | Phase | `phase` of every case (call, workspace, setup), in the catalog and the metrics of both roots | `PHASE` |
| 6 | Timed operation | the catalog fields `problem`, `solver`, `variant`, `suite`, `inputs`; the identity of the certificate file (the `file/certificates.jl` fingerprint) | `OPERATION` |
| 7 | BLAS or thread settings | `julia_threads`, `blas_threads`, `blas`; other than one and one | `THREADS` |
| 8 | Machine identity | `cpu_model`, `cpu`, the logical CPU in the receipt, the metadata and the inventory; processes of the receipt that disagree on any machine value (a policy value that all processes share but that differs from the schedule is labelled, not refused: section 5) | `MACHINE` |
| 9 | Repetition index set | the set of repetition IDs per Julia version in **each** root must equal the declared set of the frozen campaign (`reps` of the schedule, 1-8, for the A/B pair and for the A/A pair), with each ID once per stack. A root whose set differs from the declared set is refused, whether the other root differs from it in the same way or not: two roots that both lack the same declared ID are a `REPETITIONS` refusal, not a per-case FAILED | `REPETITIONS` |
| 10 | Approved case mapping | a case missing from `case-mapping.toml`, a class other than A or B without a separate approved mapping, a class B case without its approval record, a case whose mapping `id`, `role` or `phase` differs from the declared set or the records | `MAPPING` |
| 11 | Record schema | the headers of the catalog, metrics, samples and errors files, the metadata keys, the schema version of the declared-differences, mapping and stack-identity files, the receipt, the fingerprint files | `SCHEMA` |
| 12 | Undeclared source or dependency difference | any difference not in section 3 (`harness_hash` without an approval, a Manifest entry not declared, a changed compat entry not declared) and any declared difference that does not exist | `UNDECLARED` |
| 13 | Sampling settings and selection | `suite`, `groups`, `case_filter`, `samples_target`, `seconds_limit`, `case_seconds`, `profile_seconds` | `SETTINGS` |
| 14 | Unclean or unverified stack | `proximalsolvers_dirty`, a loaded-tree mismatch (`proximalsolvers_path` against the expected root, tree hashes and versions against the recorded ones), a mixed stack, an unfinished process | `STACK` |
| 15 | Unfrozen identity | the ProximalSolvers and the ProximalBase identity of each stack must each be a full 40-hex commit SHA with a recorded git tree hash. A branch name, a short SHA or a tag-only identity is refused. The historical Stack A tag `v0.5.4` is accepted only as the tag commit SHA (`9c5a43bf0b7e3f51f0a401b785c332200ffa5d7e`) together with the release tree (`1226119eb2cc6144f7345c727f0e7682632f7826`) | `IDENTITY` |
| 16 | Wrong block order or mixed campaigns | from the campaign receipt (the metadata has no start time stamp): each block's order, in the A/B arm and in the A/A arm, must equal `orders[rep]` of `schedule.toml` (AB, BA, BA, AB, BA, AB, AB, BA for repetition IDs 1 to 8); A and B must belong to one contemporaneous campaign identity and session, and every root must carry the `campaign_id` and `session_id` of the receipt in its `stack-identity.toml`; a Stack A root taken from another campaign or session, or a block whose processes the receipt does not place in the declared order, is refused; the two A/A roles must be distinct installations | `ORDER` |

A comparison that is refused is invalid **even when every timing number is finite**: no timing value is used in any
comparison, ratio, geometric mean, screen or output before every refusal has been evaluated and none was found.
The record validation of `validate.py` and the type check of the tool parse the timing and sample columns only to
validate them (finite, positive, statistics of the samples) and decide no cross-stack question. The tool keeps the
code that uses timing values in one phase function that is entered only after the refusal decision.

### 4.1 Evaluation, fields and messages

The `field` of a refusal is `<scope>:<name>`. The scopes are `a`, `b`, `aa_a`, `aa_b` (one root), `ab` and `aa`
(the A/B pair and the A/A pair), `receipt`, `mapping`, `declared`, `fingerprints_a` and `fingerprints_b`. The
`detail` is free text but always names the Julia version, the case ID and the repetition when they apply, and
the observed and the expected value (a path is shown as `basename#tag`, section 1, so that two different
paths of one run never print alike). `<root>` below stands for `a`, `b`, `aa_a` or `aa_b`. Refusals are listed
in `refusals.json` and on standard error sorted by the row number of the class, then by `field`, then by
`detail`. A check whose input is unavailable because the same root or stratum already has a `SCHEMA`, `JULIA`
or `IDENTITY` refusal is skipped, not guessed, and the skip is as narrow as the missing input: a process whose
records or metadata cannot be read or have a value of the wrong type is left out of the record comparisons, a
file that failed its schema is left out of the checks that read it, and no other check is skipped because of an
unrelated refusal class (one `SCHEMA` item in the receipt hides only the checks that need that item). So a refused
run may show fewer classes than a repaired input would, never more. `validate.py` stops at the first error of a
process, so a second refusal class in the same process may be listed only after the first is fixed (the tests put
different classes in different processes or strata).

| Class | `field` values (exact) | Rule |
|:--|:--|:--|
| `JULIA` | `<root>:stratum`, `<root>:julia` | a directory `julia-<MAJOR.MINOR>` that is not a key of `[julia.*]`, or a key missing in a root; `julia`, inventory `julia` or `commit`, Manifest `julia_version`, or the version in a record file name differing from the schedule |
| `INPUTS` | `ab:data_hash`, `aa:data_hash`, `<root>:seed_scheme`, `ab:fixture` | `data_hash` text differing for a pair in which both rows have a non-empty hash (an empty hash belongs to a `status = error` row before data generation: that pair is not an `INPUTS` refusal, the case is FAILED); `seed_scheme` differing from the schedule; a `fixture` fingerprint row set or value differing (section 14) |
| `TARGET` | `ab:measure`, `ab:target`, `mapping:measure`, `mapping:target` | catalog `measure` or `target` (as numbers) differing between the roots of a pair; the mapping `measure` (its text before the first comma) or `target` (as a number) differing from the catalog of A; metrics rows disagreeing with their catalog (message of `validate.py`, rule R1) |
| `CASE` | `<root>:case` | one refusal per (root, Julia version, case ID) that is declared and has no catalog row (the tool lists an ID absent from both roots once for each root), or has a catalog row and is not declared |
| `PHASE` | `ab:phase`, `<root>:phase` | `phase` differing between A and B (catalog or metrics) or not one of `call`, `workspace`, `setup` |
| `OPERATION` | `ab:catalog`, `ab:certificates` | a catalog column among `problem`, `solver`, `variant`, `suite`, `inputs` differing between A and B for a case (`detail` names the column; `issue` is a descriptive label and is not compared); the `file/certificates.jl` value differing for a (Julia, case, repetition) triple |
| `THREADS` | `<root>:julia_threads`, `<root>:blas_threads`, `ab:blas`, `aa:blas` | a value other than 1; `blas` differing within a pair |
| `MACHINE` | `receipt:machine`, `<root>:cpu_model`, `<root>:cpu` | receipt processes disagreeing on a `machine` value (`cpu` is compared within a stratum), or on `cpu_model`, `cpu` or `logical_cpu` against `[machine]` of the schedule; metadata `cpu_model` or `cpu` or inventory `cpu_model` differing from the schedule, or the inventory `cpu_name` differing from `[machine].cpu` of the stratum (`<root>:cpu`). The policy values `governor`, `epp`, `no_turbo`, `smt_control` that agree among all processes but differ from the schedule are **not** refused: section 5 labels the hardware observational |
| `REPETITIONS` | `<root>:repetitions`, `receipt:repetitions` | the `process coverage` issue of `validate.py` (missing and extra IDs per stratum, rule R1); a `rep` of the receipt outside `reps`; two process events of the receipt with the same (arm, role, Julia, `rep`) |
| `MAPPING` | `mapping:case`, `mapping:role`, `mapping:phase`, `mapping:class`, `mapping:approval` | the mapping must hold exactly the declared IDs once each, in the declared order; `role` must be `primary` for the first 14 and `diagnostic` for the last 5; `phase` must equal the catalog phase of A; `class` must be A or B; class B needs `approved = true` and a non-empty `approval_url`; class C or D needs, as a separate approved mapping, `approved = true`, a non-empty `approval_url` and a non-empty `separate_mapping`, and gives a NOT COMPARABLE case; a `deviation` key needs `approved = true` and a non-empty `approval_url` |
| `SCHEMA` | `<root>:records`, `<root>:metadata_keys`, `<root>:files`, `receipt:schema`, `declared:schema`, `mapping:schema`, `fingerprints_a:schema`, `fingerprints_b:schema` | any other issue of `validate.py` (headers, missing keys, malformed values); a metadata key set other than the allowed one, or a metadata value of a type other than the one the checks read (string, boolean, integer or number as the key requires); a required file of section 10 missing or not parseable inside a root (`raw/`, `Manifest.toml`, `Project.toml`, `environment-inventory.toml`) or lacking a required inventory key (`cpu_name` among them); a fingerprint `none` value outside its allowed rows (section 14); a file whose `schema` is not 1, has an unknown key, a missing key or a value of the wrong type |
| `UNDECLARED` | `declared:proximalsolvers`, `declared:proximalbase`, `declared:manifest`, `declared:compat`, `declared:harness`, `ab:harness_hash` | the observed differences of section 3 and the declared set not equal (section 13): an undeclared one, or a declared one that is absent |
| `SETTINGS` | `<root>:<key>` for `<key>` in `suite`, `groups`, `case_filter`, `samples_target`, `seconds_limit`, `case_seconds`, `profile_seconds`; `<root>:records` | the metadata value differing from `[settings]` of the schedule; the `series settings changed within a Julia version` issue of `validate.py` (rule R1) |
| `STACK` | `<root>:dirty`, `<root>:loaded_tree`, `<root>:mixed`, `<root>:unfinished`, `receipt:process` | `proximalsolvers_dirty` true; `proximalsolvers_sha`, inventory `proximalbase_loaded_tree`, inventory and metadata `proximalbase_version`, the Manifest entries of ProximalSolvers and ProximalBase, or `proximalsolvers_path` differing from `stack-identity.toml`, the inventory or `expected_package_root` (every archived path is compared in normal form, see section 12); values of section 3 differing between repetitions or strata of one root; the unfinished process messages of `validate.py` (rule R1); a receipt process with `complete` false, or `exit` not in {0, 2}, or `exit` 0 with `nonok_cases` of the record above 0, or `exit` 2 with `nonok_cases` equal to 0 |
| `IDENTITY` | `<root>:identity`, `<root>:stack_a`, `<root>:tag` | section 11: a missing key (`campaign_id` and `session_id` included), a value that is not 40 lowercase hex (a branch name, a short SHA), a `registered` release without `tag`, a `tag` without its commit; a Stack A root (`a`, `aa_a`, `aa_b`) whose ProximalSolvers or ProximalBase identity or `harness_hash` differs from `[stack_a]` of the schedule |
| `ORDER` | `receipt:campaign`, `receipt:missing`, `receipt:block`, `receipt:installation`, `receipt:elapsed`, `<root>:campaign`, `<root>:session`, `aa:installation`, `aa:identity` | section 12 |

**R1. Mapping of `validate.py` issues to classes.** For each stratum the tool calls
`validate.validate(<root>/julia-<MAJOR.MINOR>/raw, expected=8, versions=[<full version>])` (`expected` is the
number of declared repetition IDs) and maps each string of `issues` (format `<prefix>: <message>` or `<message>`)
by the first matching rule on the message, with `field` `<root>:records` unless stated:

| The message contains | Class (field) |
|:--|:--|
| `process coverage` | `REPETITIONS` (`<root>:repetitions`) |
| `expected one Julia and one BLAS thread` | `THREADS` (`<root>:julia_threads`) |
| `process is not finished`, `interrupted process` | `STACK` (`<root>:unfinished`) |
| `loaded package root differs` | `STACK` (`<root>:loaded_tree`) |
| `series settings changed within a Julia version` | `SETTINGS` (`<root>:records`) |
| `catalog changed between repetitions` | `OPERATION` (`ab:catalog`) |
| `metric measure differs from catalog`, `metric target differs from catalog` | `TARGET` (`ab:target`) |
| `metric phase differs from catalog`, `unknown phase` | `PHASE` (`<root>:phase`) |
| anything else | `SCHEMA` (`<root>:records`) |

An empty `issues` list is the only acceptable result; `valid` is not otherwise interpreted. `validate.py` parses the sample and timing columns to validate them; the tool uses no timing value before the refusal decision (section 4). Before the call the
tool lists the file names of `raw/`: a `julia-<version>-repNN` prefix whose version is not the full version of the
stratum is a `JULIA` refusal (`<root>:julia`) and that file is left out of `versions`.

**R10. The mapping.** `schema = 1` and, per `[[case]]`, the keys `id`, `role`, `phase`, `measure`, `target`,
`class`, `approved` (a boolean on every row) must be present; further keys (the descriptive audit fields) are
ignored, except `approval_url`, `approval_scope`, `separate_mapping`, `deviation` as used above. The class of a
row is its `class`. A row with `class = "A"` and `approved = false` needs nothing further: there is nothing to
approve.

## 5. Outputs

All outputs go to a fresh `--out` directory. With a refusal only `refusals.json` is written; with exit status 3
nothing is written. Otherwise `migration-comparison.csv`, `lists.json` and `report.md` are written (section 15).

**Precedence.** Section 4 is evaluated first and always wins: a refusal is a property of the pair of roots and no
per-case class is written. In particular a `data_hash` that differs for any (Julia, case, repetition) pair is
the global refusal `INPUTS`, and two roots whose repetition-ID sets differ are the global refusal `REPETITIONS`.
The declared repetition set (`reps` of the schedule, 1-8 for the A/B pair and for the A/A pair) and the declared
case set (the 19 IDs of `case_filter`) come from the frozen campaign, not from the roots, so a root that lacks a
declared repetition or a declared case is refused (`REPETITIONS`, `CASE`) even when both roots lack the same
one: an equal-but-incomplete pair is a refusal, never a per-case FAILED. The per-case classes below apply only
to what remains after every refusal has been ruled out, and to conditions that concern one case: its records,
its mapping class, its fingerprints. **Where the cleanup items are reported:** a missing or extra declared case
is a `CASE` refusal in `refusals.json`; a missing or extra declared repetition is a `REPETITIONS` refusal in
`refusals.json`; a mismatched `data_hash` is an `INPUTS` refusal in `refusals.json`. None of them produces a
comparison, a `report.md` or an entry in `lists.json`.

**Per-case class**, per Julia version, in `migration-comparison.csv`, determined in this order (the first class
that applies; its `reason` lists every reason of that class, joined by ` | `):

1. **FAILED**: in any repetition of the declared set, in either stack, the metrics row of the case has a status
   other than `ok` (`target_missed`, `uncertifiable` (an invalid certificate), `incomplete` (an incomplete path),
   `timeout`, `error`), or its `median_ns` is not finite and positive. Reasons: `status: A rep3 target_missed`
   (root, repetition, status) and `median_ns: B rep3 0`. A missing case or repetition is not a FAILED
   condition: it is a global refusal (precedence paragraph).
2. **NOT COMPARABLE**: the workload is not the same although the records are structurally comparable: a
   reset-state or solver-configuration fingerprint missing or mismatched while the `data_hash` matches (a
   `data_hash` match is never accepted as proof of identical semantics), a missing fingerprint file, a mapping
   class C or D, or an approved semantic deviation (`deviation`) recorded in the mapping. Reasons:
   `fingerprint file missing: A`, `fingerprint row missing: reset/values B rep 3`,
   `fingerprint mismatch: config/options rep 3`, `mapping class C`, `semantic deviation: <text>`. Section 6 gives the exact
   classification of fingerprint conditions.
3. **COMPARABLE**: every repetition of the declared set has an `ok` metrics row with finite positive `median_ns`
   in both roots; the fingerprints match (section 6); the mapping class is A, or B with an approved record; no
   failed check.

**Per-case numbers**, only for COMPARABLE cases (all numbers of a FAILED or NOT COMPARABLE row are empty): per
block `i` (repetition ID `i`) the ratio is `rho_i = median_ns` of the B root over `median_ns` of the A root for
the same Julia version, case and repetition; the absolute change is the difference `median_ns(B) - median_ns(A)`;
`geomean_ratio` is `exp(mean(log rho_i))` over the eight blocks; `ratio_min` and `ratio_max` are the extremes of
the `rho_i`; `a_median_bytes` and `b_median_bytes` are the `median_bytes` of the metrics rows per block; the
accuracy columns are defined in section 16; the screens are defined in section 16 and shown with the label
"screen". Cases of the other two classes show no ratio. **Hardware** of a case: `controlled` only if every process
of the receipt carried the frozen machine policy, that is `governor`, `epp`, `no_turbo` and `smt_control` equal to
the values of `[machine]` in `schedule.toml`; otherwise `observational: governor=<value>, epp=<value>,
no_turbo=<value>, smt_control=<value>` with the values the processes carried (they are equal among the processes:
a disagreement is the `MACHINE` refusal). The rule is the same for every case. An observational campaign is
reported as such at the top of `report.md` and does not change the exit status.

**Visible lists**, repeated at the top of `report.md` and in `lists.json`, never hidden in a table and never
summarized away (the keys and the item fields are in section 15; an empty list is shown as empty, never
omitted): cases that are not ok, with the status and detail; invalid certificates; incomplete paths; errors and
timeouts; allocation differences (median and maximum bytes per call, separately from timing); missing
diagnostics (a fingerprint file or the A/A control that is absent); the approved semantic deviations of the
mapping; the cases that are NOT COMPARABLE with their reason; the cases that FAILED with their reason.

**Reports.** `report.md` states in its first line that the comparison is a whole-stack comparison, that no
difference is attributed to ProximalBase alone, and that the Stage 2A archive is historical context and absent
from the ratios. The Stage 2A means appear only through `historical-reference.tsv`, in a separate table labelled
historical. Julia versions are reported side by side, never pooled.

## 6. A `data_hash` match is not proof of identical semantics

`data_hash` covers generated arrays only. For every case and stack, a recorded **fixture and state
fingerprint file** must also match (the exact format is section 14). The tool compares the two files key by key
for every (Julia, case, repetition). The classification is the **narrow fail-closed reading** of the rule that a
fingerprint mismatch makes a case not comparable, and it is a single decision, written here once:

* **Global `INPUTS` refusal:** `data_hash` mismatch, `seed_scheme` mismatch, and any mismatch of a `fixture`
  fingerprint row (the actual input arrays and parameters) for any (Julia, case, repetition) when both files have
  at least one `fixture` row for it: a name present on one side only, or a differing value. A fixture mismatch
  refuses the whole comparison because changed inputs cannot be salvaged per case.
* **Global `OPERATION` refusal:** a mismatch of the catalog fields (`problem`, `solver`, `variant`, `suite`,
  `inputs`) and of the `file/certificates.jl` fingerprint (the certificate identity).
* **Per-case NOT COMPARABLE** (both stacks otherwise valid, the `data_hash` equal): a mismatch of a `reset` row
  (`values`, `active_ids`) or of a `config` row (`solver`, `options`); a required fingerprint row missing for a
  (Julia, case, repetition) in either file (the required rows are `reset/values`, `reset/active_ids`,
  `config/solver`, `config/options`, `file/certificates.jl` and at least one `fixture` row); a mapping class C or
  D; an approved semantic deviation of the mapping. A missing fingerprint file is the same (every case NOT
  COMPARABLE), not a refusal.

A different `data_hash` is refused earlier (section 4, item 2). The files are written by the pilots and the
campaign outside any timed region (`STAGE2B_PLAN.md` section 7).

## 7. The ordinary tools stay as they are

* `compare.py` and `validate.py` stay unchanged and strict. A test of PR B records the SHA-256 of both files at
  the freeze commit (the files have not changed since `b0de3f7`) and fails if either changes:
  `compare.py` `41568ea9b22d9b36f1aa6ba4e478b380284ee66c338f98dfeed40af104ebf6ab` and `validate.py`
  `0b761e77ae4b88d339d7df3351e5ea0ff732c8cd32f68fbb89d95d4a26f2fc4b`.
* `migration_compare.py` may import record readers from `validate.py` and `summarize.py`, but it never
  monkeypatches or reconfigures their settings sets, and it does not write into the ordinary tools'
  output formats.
* Its output names differ from those of `compare.py` (`migration-comparison.csv` here has the class column
  and the screens), so that a report cannot be mistaken for an ordinary comparison.

## 8. Required synthetic tests (PR B)

Offline, Python standard library only, on small synthetic roots built by `stage2b_fixtures.py`. The fixture
module builds one complete accepted input set (the four roots with two strata and eight repetitions each, the
receipt, the mapping, the declared-differences file, the fingerprint files and a copy of `schedule.toml`) in a
temporary directory; every test changes exactly one item of it. Every test asserts the exit status and the
message class (the `REFUSED:<CLASS>` line on standard error and the class in `refusals.json`), and uses records in which **all timing
numbers are finite**, so that a pass of the timing alone would wrongly accept.

* One test per refused difference of section 4 (16 tests): Julia version or build; `data_hash` or generated
  inputs (a `data_hash`, the `seed_scheme`, a fixture row); target or measure; case ID (a declared case missing
  from one root, the same case missing from both roots, an extra case); phase; timed operation (catalog and
  `file/certificates.jl`); BLAS or thread settings; machine identity (`cpu_model`, `logical_cpu` of the receipt,
  processes disagreeing); repetition index set (a missing ID in one root, the same missing ID in both roots, a
  duplicate process event, an extra ID); approved case mapping (missing, unapproved class B, class C without a
  separate mapping, mismatched role); record schema (header, metadata key, declared-file schema);
  undeclared source or dependency difference (an undeclared Manifest entry, a declared entry that is absent, a
  `harness_hash` change without approval, a compat change not declared); sampling and selection settings; unclean
  or unverified stack (dirty tree, loaded tree, an unfinished process, `exit` 1); unfrozen identity, class `IDENTITY` (a
  branch name, a short SHA, a tag name without its commit SHA, a missing tree hash; the tag commit SHA plus tree
  of `v0.5.4` is accepted); wrong block order or mixed campaigns, class `ORDER` (a block run B then A in an
  A-then-B slot for each of the eight repetition IDs of the schedule, overlapping processes, a block missing from
  the receipt, A and B from different campaign identities, a Stack A root from another session, blocks not in
  increasing time order, a receipt installation different from the root's).
* Accepted differences: a stack with a different ProximalSolvers SHA and package hash, ProximalBase version, SHA
  and hash, a declared dependency difference and an approved class B harness hash change is accepted, and the
  same pair without the declaration is refused.
* `data_hash` equal but a reset-state or configuration fingerprint different: NOT COMPARABLE, with no ratio in
  the output. A fixture fingerprint different: the `INPUTS` refusal. A missing fingerprint file, and a missing
  required row: NOT COMPARABLE.
* Per-case classes: a case with `target_missed` in B: FAILED, listed, no ratio; an incomplete path; an invalid
  certificate; an approved semantic deviation; a case with `exit` 2 in the receipt and a non-ok record is
  FAILED, not refused. A repetition missing from both roots is a `REPETITIONS` refusal (exit status 2), not a
  FAILED case, and so is a case missing from both roots (`CASE`).
* A/A mode: identical stack identities on two independent installations accepted, unequal ones refused
  (`ORDER`, `aa:identity`), two processes of one installation refused (`ORDER`, `aa:installation`: equal
  installation id, equal `proximalsolvers_path`, equal first depot path).
* Screens: all eight `rho_i` above 1 with the geometric mean above the largest A/A ratio is a screened slowdown,
  one `rho_i` equal to or below 1 is inconclusive, the mirror cases, a geometric mean inside the A/A range, and
  no `--aa` (screen not evaluated).
* The near-target flag: `v/t` of 0.9 (near target), 0.89 (margin), 1.0 (near target), above 1 and non-ok
  (missed/invalid).
* The visible lists contain every non-ok case and every other item of section 5, and the report starts with the
  whole-stack statement (section 15).
* No Julia versions are pooled: the output of a root with both strata has one set of rows per stratum and no row
  across them.
* The SHA-256 of `compare.py` and `validate.py` equal the recorded values (section 7).
* `schedule.toml` is read by the tool and by the tests alike; a test mutates a copy of it (a different order
  for one repetition ID, seven repetition IDs) and the tool follows the copy.

## 9. No confidence interval is a noninferiority test

`migration_compare.py` never presents a confidence interval, a screen or a ratio as a noninferiority,
equivalence or no-regression test. Paired intervals are not an approved one-sided test, an interval that
contains 1 is never read as noninferiority, and there is no universal threshold: formal rules are
calibrated by Stage 3 of #110. The screens are descriptive investigation screens taken from the A/A control, not
tests: there is no 5% default, no significance level, and the A/A ranges are no calibrated confidence bounds. A
test of PR B asserts that the report names the screens as such, contains the sentence of section 15, and
contains no claim of noninferiority.

## 10. Root layout (schema 4a)

Each of `ROOT_A`, `ROOT_B`, `ROOT_AA_A` and `ROOT_AA_B`:

```
<root>/
  stack-identity.toml                   section 11 (carries the campaign and session of the receipt)
  fingerprints.tsv                      section 14 (A and B roots only; default location)
  julia-1.10/                           one directory julia-<MAJOR.MINOR> per stratum
    raw/                                the flat record files of validate.py (below)
    Manifest.toml
    Project.toml
    environment-inventory.toml
  julia-1.13/
    ...
```

* `raw/` holds, for each repetition `NN` (two digits) of the declared set and the full Julia version `V` of the
  stratum, exactly the files of `validate.py`: `julia-V-repNN-catalog.tsv`, `-errors.tsv`, `-metrics.tsv`,
  `-samples.tsv`, `-metadata.toml` and `-metadata-start.toml` (a `-profiles.txt` is allowed). The tool runs
  `validate.validate(<that raw directory>, expected=8, versions=[V])` on it unmodified.
* `Manifest.toml` and `Project.toml`: the archived resolved Manifest and the environment `Project.toml` of the
  stratum (Julia Manifest format 2.0 or 2.1: `julia_version`, `manifest_format` and one `[[deps.NAME]]` per
  entry with `uuid` and optional `version`, `git-tree-sha1`, `path`).
* `environment-inventory.toml`: the Stage 2A format. Required keys `julia`, `commit`, `cpu_model`, `cpu_name`
  (`Sys.CPU_NAME`, compared with `[machine].cpu` of the stratum), `blas`, `depot_path` (an array of strings),
  `proximalbase_version`, `proximalbase_loaded_tree`, `proximalsolvers_dir`, `threads` (other Stage 2A keys such
  as `active_project`, `bindir`, `load_path`, `proximalbase_dir` are allowed and ignored) and one `[deps.NAME]` table per dependency (`path`, `registry`, `repo`, `source`,
  `tree`, `uuid`, `version`).

A stratum directory present in one root and not in the other, or present and not in the schedule, is a `JULIA`
refusal. A missing `stack-identity.toml` is an `IDENTITY` refusal (`<root>:identity`); a missing or unparseable
`raw/`, `Manifest.toml`, `Project.toml` or `environment-inventory.toml` is a `SCHEMA` refusal (`<root>:files`).

Example (the first lines of an inventory):

```toml
julia = "1.13.3"
commit = "67ac47b9cd855e02134d41d5428ac9f2a73f2694"
cpu_model = "13th Gen Intel(R) Core(TM) i9-13900"
cpu_name = "raptorlake"
blas = "LBTConfig([ILP64] libopenblas64_.so)"
depot_path = ["<depot>", "<julia depot>"]
proximalbase_version = "0.5.4"
proximalbase_loaded_tree = "1226119eb2cc6144f7345c727f0e7682632f7826"
proximalsolvers_dir = "<checkout>"
threads = 1

[deps.ProximalBase]
tree = "1226119eb2cc6144f7345c727f0e7682632f7826"
uuid = "0a755509-c5b1-5d6f-9b24-59bcda3c37a3"
version = "0.5.4"
```

## 11. `stack-identity.toml` (schema 4b)

```toml
schema = 1
installation = "inst-a1"            # a non-empty string of letters, digits, '.', '_' and '-'
campaign_id = "pb06-migration-stage2b-v1"   # the campaign_id and session_id of the receipt
session_id = "session-0001"

[proximalsolvers]
commit = "b0de3f7fc91767b97197ff4b458207e308998943"
tree = "a836d532008782e75f2b2a7e4666fa1df24b34dc"
version = "0.3.2"

[proximalbase]
commit = "9c5a43bf0b7e3f51f0a401b785c332200ffa5d7e"
tree = "1226119eb2cc6144f7345c727f0e7682632f7826"
version = "0.5.4"
tag = "v0.5.4"                      # optional
release = "registered"              # "registered" or "development"
```

`campaign_id` and `session_id` are required non-empty strings (a missing key is `IDENTITY`, a value of the wrong
type `SCHEMA`); every root of the comparison must carry the `campaign_id` and `session_id` of the `campaign` event
of the receipt (section 12), which binds a root to the campaign and the session that produced it.
`commit` and `tree` are 40 lowercase hexadecimal characters. `schema` other than 1 or an unknown key is a
`SCHEMA` refusal (`<root>:files`). `IDENTITY` refusals (`<root>:identity`, and `<root>:tag` for the tag): a
missing key; a `commit` or `tree` that is not 40 lowercase hex (a branch name, a short SHA, upper case); a
`release` other than the two values; `release = "registered"` without `tag`; a `tag` whose `commit` is missing or
not 40-hex (a tag is never an identity by itself). Stack A's ProximalBase is accepted only as the `[stack_a]`
identity of `schedule.toml` (`<root>:stack_a`). **Cross-checks** (class `STACK`, `<root>:loaded_tree`): the metadata
`proximalsolvers_sha` equals `[proximalsolvers].commit`; `proximalsolvers_dirty` is false; the inventory
`proximalbase_loaded_tree` equals `[proximalbase].tree`; the inventory and metadata `proximalbase_version`
equal `[proximalbase].version`; the Manifest entries of ProximalBase and ProximalSolvers have the versions of
`stack-identity.toml` and, for ProximalBase, `git-tree-sha1` equal to the tree. `installation` is the id that the
receipt uses (section 12).

## 12. The receipt (schema 4c)

JSON lines, one object per line, one file for the A/B arm and the A/A arm of one campaign. Events:

```json
{"event": "campaign", "campaign_id": "pb06-migration-stage2b-v1", "session_id": "session-0001", "schedule_id": "stage2b-8block-v1", "utc": "2026-12-01T08:00:00.000+00:00"}
{"event": "process", "arm": "AB", "role": "A", "julia": "1.13.3", "rep": 1, "block": 1, "installation": "inst-a1", "start_utc": "2026-12-01T09:00:00.000+00:00", "end_utc": "2026-12-01T09:00:16.500+00:00", "exit": 0, "complete": true, "machine": {"cpu_model": "13th Gen Intel(R) Core(TM) i9-13900", "cpu": "raptorlake", "logical_cpu": 6, "governor": "powersave", "epp": "balance_performance", "no_turbo": "0", "smt_control": "on"}}
```

* `campaign` occurs exactly once: keys `campaign_id`, `session_id` (non-empty strings), `schedule_id`, `utc`.
  Zero such events, or two identical ones, are a `SCHEMA` refusal; two that differ in `campaign_id`,
  `session_id` or `schedule_id` are mixed campaigns (`ORDER`, `receipt:campaign`); a `campaign_id` or
  `schedule_id` that differs from `[schedule].campaign_id` or `[schedule].id` is `ORDER`, `receipt:campaign`.
* `process`: `arm` ("AB" or "AA"), `role` ("A" or "B"), `julia` (the full version of a stratum), `rep` (an
  integer), `block` (an integer equal to `rep`), `installation` (string), `start_utc` and `end_utc` (ISO 8601
  with a UTC offset; `end_utc` later than `start_utc`), `exit` (an integer, not a boolean), `complete` (a
  boolean) and `machine` with `cpu_model`, `cpu`, `logical_cpu` (integer), `governor`, `epp`, `no_turbo`,
  `smt_control`. A missing or extra key, a wrong type, a malformed time, `block` different from `rep`, any other
  `event` value, or a line that is not a JSON object is a `SCHEMA` refusal (`receipt:schema`; a receipt file that cannot be
  decoded as UTF-8 text is exit status 3).
* Exactly one `process` per (`arm`, `role`, `julia`, `rep`): a second one is `REPETITIONS`
  (`receipt:repetitions`). The A/B arm needs roles A and B for every stratum and every `rep` of `reps`; with
  `--aa` the A/A arm needs them too (process events of the A/A arm without `--aa` are checked for schema and
  for `MACHINE`, and otherwise ignored). A missing block is `ORDER` (`receipt:missing`).
* Roles and roots: arm AB role A is `ROOT_A`, role B is `ROOT_B`; arm AA role A is `ROOT_AA_A`, role B is
  `ROOT_AA_B`. The `installation` of a process equals the `installation` of its root (`receipt:installation`), and
  the `campaign_id` and `session_id` of every root equal those of the `campaign` event (`ORDER`: `<root>:campaign`,
  `<root>:session`; with no usable `campaign` event the roots are compared with `ROOT_A`).
* **Block order** is the order of the two `start_utc` of a block: the role with the earlier start is first, and
  "AB" means that role A started first. Each process must end before the other starts: a block whose two
  processes overlap, or start together, is `ORDER` (`receipt:block`). The block order must equal
  `[schedule].orders[rep]` for every block of both arms (the same table for AB and AA). Blocks must be in
  increasing time order within an arm and a Julia version: both processes of block `r + 1` start after both
  processes of block `r` have ended (`receipt:block`).
* **Record and receipt agree:** the `elapsed_s` of the final metadata of a process (rep `rep`, the stratum,
  the root of its role) is at most the time between `start_utc` and `end_utc` of its receipt process
  (`ORDER`, `receipt:elapsed`).
* **Unfinished processes** (`STACK`, `receipt:process`): `complete` false; `exit` other than 0 or 2; `exit` 0 with
  `nonok_cases` of the record above 0; `exit` 2 with `nonok_cases` equal to 0. `run.jl` exits 2 when its records
  are complete and at least one case is not ok: that is a FAILED case, not a refusal.
* **A/A pair:** the two roles of the A/A arm must be distinct installations: distinct `installation` ids, distinct
  `proximalsolvers_path` (also `expected_package_root` and the inventory `proximalsolvers_dir`) in the metadata, and distinct first `depot_path` entries in the inventories, all compared in normal form (a run of leading `/` collapses to one, `.` and `..` segments and trailing `/` are removed, symlinks are not followed: two spellings of one directory are one installation); their stack
  identities (`stack-identity.toml` commits, trees, versions, and the Manifest content of each stratum) must be
  identical to each other and to `ROOT_A`'s. Otherwise `ORDER`: `aa:installation` for the distinctness (same
  installation masquerading as two) and `aa:identity` for the identity and Manifest.
* **Machine** (`MACHINE`, `receipt:machine`): every process of the receipt carries the same `machine` values
  (`cpu` may differ between strata only, and equals `[machine].cpu` of the stratum), and `cpu_model`, `cpu` and
  `logical_cpu` equal `[machine]` of the schedule and, for `cpu_model` and `cpu`, the root (metadata `cpu_model`
  and `cpu`, inventory `cpu_model` and `cpu_name`).
* **Collect-all.** Each unusable receipt line gives its own `SCHEMA` refusal and only the checks that need it are
  skipped: an unknown or malformed event never hides the block order, installation, elapsed and exit checks of the
  other processes. A block that has an unusable process event, or a line that may have been a process event and
  cannot be identified, is not reported as missing. The policy values are labelled by the hardware rule of section 5.

## 13. `declared-differences.toml` (schema 4d)

```toml
schema = 1

[proximalsolvers]                   # optional: present exactly when the observed values differ
a_commit = "b0de3f7fc91767b97197ff4b458207e308998943"
b_commit = "<40-hex>"
a_tree = "a836d532008782e75f2b2a7e4666fa1df24b34dc"
b_tree = "<40-hex>"
a_package_hash = "f37fc61f300ad597a33c7ab5f448d38c865db854"
b_package_hash = "<40-hex>"

[proximalbase]                      # optional: present exactly when the observed values differ
a_version = "0.5.4"
b_version = "0.6.0"
a_commit = "9c5a43bf0b7e3f51f0a401b785c332200ffa5d7e"
b_commit = "<40-hex>"
a_tree = "1226119eb2cc6144f7345c727f0e7682632f7826"
b_tree = "<40-hex>"
a_package_hash = "d4747f2ab51212b20d9adcf70e21c2200b090b2a"
b_package_hash = "<40-hex>"

[[manifest]]
name = "ProximalBase"
uuid = "0a755509-c5b1-5d6f-9b24-59bcda3c37a3"
kind = "changed"                    # "changed", "added" or "removed"
a_version = "0.5.4"
b_version = "0.6.0"
a_tree = "1226119eb2cc6144f7345c727f0e7682632f7826"
b_tree = "<40-hex>"
reason = "the migration target"
julia = ["1.10", "1.13"]            # optional: the strata of the entry; default all strata

[[compat]]                          # one per differing [compat] entry of the environment Project.toml
name = "ProximalBase"
a = "0.5"
b = "0.6"
reason = "the compat entry must admit the candidate"

[harness]                           # optional
a_hash = "b7bf3d953ec6e9f9720e74d7895b5cf95a629fd4"
b_hash = "<40-hex>"
port_commit = "<40-hex>"
cases = ["paths/lasso/cd/grid8/call"]
changed_lines = ["-reset!() = ...", "+reset!() = ..."]
approval_url = "https://github.com/mlakolar/ProximalSolvers.jl/issues/110#issuecomment-6694764350"
```

* `schema` other than 1, a missing key, an unknown key (top level, table or entry) or a value of the wrong type
  is `SCHEMA` (`declared:schema`). Hashes, commits and trees are 40 lowercase hex. Only `schema` is required at
  the top level: `[proximalsolvers]`, `[proximalbase]`, `[[manifest]]`, `[[compat]]` and `[harness]` are optional
  and each is present exactly when the corresponding observed difference exists (an identical pair is declared by
  a file that holds only `schema = 1`). Within a table that is present every key is required.
* **Exact correspondence.** Observed values: the A value comes from `ROOT_A` and the B value from `ROOT_B`. The
  observed values of a package differ when any of them (the metadata `proximalsolvers_sha`,
  `proximalsolvers_hash`, `proximalbase_version`, `proximalbase_hash`, the commit, tree and version of
  `stack-identity.toml`) differs between the roots. If they differ, the table (`[proximalsolvers]`,
  `[proximalbase]`) must be present; if they are all equal, it must be absent. If it is present, every `a_*` and
  `b_*` equals the observed value and each `a_*` differs from its `b_*` (a declared difference that does not exist
  is refused). Violations are `UNDECLARED` (`declared:proximalsolvers`, `declared:proximalbase`). A pair whose
  commits differ but whose trees or package hashes are equal cannot be declared (each pair must differ), so it
  fails closed.
* **Manifest.** Per stratum the entries of the two `Manifest.toml` are keyed by (`name`, `uuid`) and compared by
  `version` and `git-tree-sha1` (an absent value is the empty string; the `path` of a path entry is not
  compared). An entry on one side only is `added` (B only, `a_*` empty) or `removed` (A only, `b_*` empty); an
  entry whose version or tree differs is `changed`. The observed differences of a stratum must equal the
  `[[manifest]]` entries that apply to that stratum (`julia` absent means every stratum), as sets of (`name`,
  `uuid`, `kind`, `a_version`, `b_version`, `a_tree`, `b_tree`); `reason` must be non-empty and is not
  compared. An observed difference that is not declared and a declared one that is absent are `UNDECLARED`
  (`declared:manifest`). The ProximalSolvers and ProximalBase entries are among the observed differences and
  must be declared like any other. A `julia` value that is not a stratum of the schedule, or an entry declared
  twice for one stratum, is `SCHEMA`.
* **Project.toml.** Per stratum, `[deps]` (name to UUID) of the environment `Project.toml` must be equal between
  A and B except for names that are declared as `added` or `removed` `[[manifest]]` entries of that stratum, and
  every differing `[compat]` entry (name, A value, B value; an absent entry is the empty string) must be declared
  in `[[compat]]` (`name`, `a`, `b`, `reason`, optional `julia`) with the same exactness: an undeclared
  difference and a declared one that is absent are `UNDECLARED` (`declared:compat`). `[sources]`, `[extras]`,
  `[targets]` and the other tables are not compared.
* **Harness.** The observed harness hashes are the metadata `harness_hash` values (identical across the
  repetitions and strata of a root). If they differ, `[harness]` must be present with `a_hash` and `b_hash`
  equal to them, and `cases` must be exactly the IDs of the class B cases of the mapping, each of them class B
  with `approved = true` and a non-empty `approval_url` equal to `[harness].approval_url`; `changed_lines` is a
  non-empty array of strings. If they are equal, `[harness]` must be absent. A harness hash difference without
  `[harness]`, a `[harness]` with equal hashes, or a `cases` entry that is not class B and approved, is
  `UNDECLARED` (`declared:harness`, or `ab:harness_hash` for the observed difference). Both true hashes are
  recorded and never forced equal.

## 14. Fingerprint files (schema 4e)

`--fingerprints-a` and `--fingerprints-b`: one TSV per stack covering all strata and repetitions, UTF-8, header
exactly `julia`, `id`, `rep`, `kind`, `name`, `value`, tab separated, `\n` line ends:

```
julia	id	rep	kind	name	value
1.13.3	paths/lasso/cd/grid8/call	1	fixture	X	3b6c...(64 hex)
1.13.3	paths/lasso/cd/grid8/call	1	fixture	grid	9d1e...(64 hex)
1.13.3	paths/lasso/cd/grid8/call	1	reset	values	5f0a...(64 hex)
1.13.3	paths/lasso/cd/grid8/call	1	reset	active_ids	none
1.13.3	paths/lasso/cd/grid8/call	1	config	solver	c2d4...(64 hex)
1.13.3	paths/lasso/cd/grid8/call	1	config	options	77ab...(64 hex)
1.13.3	paths/lasso/cd/grid8/call	1	file	certificates.jl	e913...(64 hex)
```

* `julia` is the full Julia version of a stratum, `id` a declared case, `rep` a declared repetition ID.
* Allowed (`kind`, `name`): `fixture` with any non-empty name (each field of the problem: `X`, `y`, `λ`, `w`,
  `groups`, `S`, `Λ`, `D`, `grid`, and so on; value: SHA-256 of its bytes, of `findnz` for a sparse matrix),
  `reset` with `values` or `active_ids` (SHA-256 of the iterate's values after `reset!()`, of the active IDs),
  `config` with `solver` or `options` (SHA-256 of the printed solver and option fields), `file` with
  `certificates.jl` (SHA-256 of the file; it executes inside the timed call of D04). Any other pair is
  `SCHEMA`.
* `value` is 64 lowercase hex characters (SHA-256) or the literal `none`. `none` is allowed only for the two
  `reset` rows: `reset/active_ids` (of an iterate that has no working set, a plain `Vector`; the records cannot
  tell which cases have one, so `none` is accepted for every case) and `reset/values` only for a setup case (a
  case that has no iterate, by the catalog phase of root A). `reset/values = none` for a case of another phase
  is `SCHEMA`. Anything else is `SCHEMA` (`fingerprints_a:schema`,
  `fingerprints_b:schema`), as are a duplicate (`julia`, `id`, `rep`, `kind`, `name`), a row of an undeclared
  stratum, case or repetition, a wrong header and a row with another field count.
* Required for every (`julia`, `id`, `rep`) of the declared sets: `reset/values`, `reset/active_ids`,
  `config/solver`, `config/options`, `file/certificates.jl` and at least one `fixture` row. The files are
  compared key by key between A and B; the classification is section 6: a fixture mismatch (a name on one side
  only, or a differing value) is `INPUTS` (`ab:fixture`), a `file/certificates.jl` mismatch is `OPERATION`
  (`ab:certificates`), a `reset` or `config` mismatch (a value, or `none` against a hash), a required row missing
  in either file, or a missing file, is per-case NOT COMPARABLE.

## 15. Outputs (schema 4f)

**`migration-comparison.csv`**: UTF-8, `\n` line ends, header on the first line, one row per (`julia`, case)
(2 strata of 19 cases: 38 rows), strata in schedule order and cases in declared order, columns in this fixed
order:

```
julia, id, role, phase, class, reason, repetitions, a_ns, b_ns, ratio, abs_diff_ns, geomean_ratio, ratio_min,
ratio_max, measure, target, a_value, b_value, a_accuracy_fraction, b_accuracy_fraction, a_accuracy_band,
b_accuracy_band, a_median_bytes, b_median_bytes, hardware, aa_ratio_min, aa_ratio_max, screen, mapping_class
```

* `julia` is the full version; `role` from the mapping; `class` is `COMPARABLE`, `NOT COMPARABLE` or `FAILED`;
  `reason` as in section 5 (empty for COMPARABLE); `measure` is the catalog measure and `target` the catalog
  target as `repr(float)`; `mapping_class` is the mapping `class`; `hardware` section 5.
* List-valued cells (per block) are semicolon-joined in repetition order: `repetitions` (the IDs `1;...;8`),
  `a_ns` and `b_ns` (the `median_ns` per block), `ratio`, `abs_diff_ns`, `a_value` and `b_value` (the
  `worst_value` per block), `a_accuracy_fraction`, `b_accuracy_fraction`, `a_accuracy_band`, `b_accuracy_band`,
  `a_median_bytes` and `b_median_bytes`. `geomean_ratio`, `ratio_min`, `ratio_max`, `aa_ratio_min`,
  `aa_ratio_max` are scalars. Numbers are written as `repr(float(value))`.
* For a NOT COMPARABLE or FAILED row every numeric and list cell (`repetitions` through `b_median_bytes`,
  `aa_ratio_min`, `aa_ratio_max`, `screen`) is empty; `julia`, `id`, `role`, `phase`, `class`, `reason`, `measure`,
  `target`, `hardware` and `mapping_class` are filled.
* `screen` is one of `screened slowdown`, `screened speedup`, `inconclusive`, `screen not evaluated` (section 16).

```
julia,id,role,phase,class,reason,repetitions,a_ns,...,screen,mapping_class
1.13.3,cd/lasso-dense/cd/B/call,primary,call,COMPARABLE,,1;2;3;4;5;6;7;8,2388.0;...,inconclusive,A
1.13.3,paths/lasso/cd/grid8/call,primary,call,FAILED,status: B rep3 target_missed,,,...,,B
```

**`lists.json`**: an object with exactly these keys in this order, each a list (possibly empty) of objects sorted
by (`julia`, `id`, `rep`, `root`):

| Key | Contents; item fields |
|:--|:--|
| `not_ok` | every metrics row of the A and B roots (`root` "A" or "B") and of the A/A roots (`root` "AA_A", "AA_B") with a status other than `ok`: `julia`, `id`, `rep`, `root`, `status`, `detail` (the `exception` of the errors file), `worst_value` (number or null), `target`, `accuracy_fraction` (number or null), `accuracy_band` |
| `invalid_certificates` | the rows of `not_ok` with status `uncertifiable`: same fields |
| `incomplete_paths` | the rows of `not_ok` with status `incomplete`: same fields |
| `errors_and_timeouts` | the rows of `not_ok` with status `error` or `timeout`: same fields |
| `allocation_differences` | every (`julia`, `id`, `rep`) where both A and B rows are ok and `median_bytes` or `max_bytes` differ: `julia`, `id`, `rep`, `a_median_bytes`, `b_median_bytes`, `a_max_bytes`, `b_max_bytes` |
| `missing_diagnostics` | `what` "fingerprints" (a missing file: `root` "A" or "B"), "aa" (no `--aa`: one item per stratum, or an A/A root with a non-ok or non-positive row for the case: `id`, `rep`), `detail` |
| `semantic_deviations` | every case with a `deviation` or a mapping class C or D: `id`, `class`, `text`, `approval_url`, one per case and stratum |
| `not_comparable` | the cases of class NOT COMPARABLE: `julia`, `id`, `reason` |
| `failed` | the cases of class FAILED: `julia`, `id`, `reason` |

**`refusals.json`**: written alone when the run is refused.

```json
{"schema": 1, "count": 1, "refusals": [{"class": "INPUTS", "field": "ab:data_hash", "detail": "julia 1.13.3 case cd/lasso-dense/cd/B/call rep 3: A 3b6c... differs from B 9d1e..."}]}
```

`count` equals the number of entries; the entries are in the order of section 4.1. Files are written with
`json.dumps(..., indent=2)` and a final newline.

**`report.md`.** Line 1 is exactly: `This is a whole-stack migration comparison. Differences cannot be attributed solely to ProximalBase. The Stage 2A historical archive is descriptive context, not part of the contemporaneous paired ratios.` Line 2 is empty. Then, in this order: the campaign (`campaign_id`, `schedule_id`, `session_id`) and the hardware
label of section 5 (`controlled`, or `observational` with the values); the nine visible lists; for each Julia version, side by
side and never pooled, a table of the cases (`id`, `role`, `class`, `screen`, `geomean_ratio`, `ratio_min`,
`ratio_max`, `aa_ratio_min`, `aa_ratio_max`, `mapping_class`) and, separately, the per-block process RSS
(`maxrss_bytes` of the metadata, one value per process) of A and B, interpreted apart from the Julia
allocations; a table labelled "Historical Stage 2A reference (descriptive; not part of any ratio)" from
`historical-reference.tsv` for the declared cases. The report contains this sentence verbatim: `The screens are
descriptive investigation screens, not tests: there is no significance level, no noninferiority claim and no
no-regression claim, and A/A ranges are not calibrated confidence bounds.` Outside that sentence the report
contains none of the words `noninferior`, `non-inferior`, `no-regression`, `significant`, `equivalent`
(case-insensitive); "screen not evaluated" is shown when there is no A/A evidence for a case. Free text of the report (record
and mapping text, identifiers) is cleaned of absolute paths first (section 1), then the five words are masked as `[term]`, and
only then are the Markdown characters (`|`, line breaks) escaped, so that a path shows the same `basename#tag` in
the report as in the lists and the table; escaped text is never cleaned.

## 16. Schedule, screens and the near-target flag

**`schedule.toml`** (schema 1): `[schedule]` (`id`, `campaign_id`, `reps`, `arms`, `orders`); `[settings]` (the
metadata keys `suite`, `groups`, `case_filter`, `samples_target`, `seconds_limit`, `case_seconds`,
`profile_seconds`, `julia_threads`, `blas_threads`, `seed_scheme`); `[machine]` (`cpu_model`, `cpu` as a table
from stratum to `Sys.CPU_NAME`, `logical_cpu`, `smt_sibling`, `governor`, `epp`, `no_turbo`, `smt_control`);
`[julia."<MAJOR.MINOR>"]` (`version`, `commit`); `[stack_a]` (`harness_hash`, and the tables `proximalsolvers`
and `proximalbase` with the keys of section 11, `tag` and `release` included). The eight repetition IDs and the
orders are:

| Repetition ID | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Order | AB | BA | BA | AB | BA | AB | AB | BA |

(four AB and four BA; each order has two odd and two even IDs). The same table holds for the A/B arm and the
A/A arm; block `i` uses repetition ID `i`. A missing key, `schema` other than 1, `reps` that are not the consecutive integers
from 1 up to at most 10 (the `PS_REPETITION` cap), an order other than `AB` or `BA`, or an `orders` table whose keys
are not exactly `reps` is an error of the tool's own input: exit status 3. The tool follows the file it is given:
`expected` of rule R1, the declared repetition set and the number of blocks of the screens are `len(reps)`; the
frozen schedule has eight.

**Screens** (descriptive investigation screens, not tests: no 5% default, no significance, no noninferiority or
no-regression claim; A/A ranges are no calibrated confidence bounds). For one case and Julia version let
`rho_i = time_B / time_A` (process medians) over the eight A/B blocks and let the A/A ratios be the eight values
of `median_ns` of the A/A role B over role A of the same case, version and repetition ID, defined only when
every A/A row of the case is ok with a finite positive `median_ns`. Then:

* **screened slowdown** if `rho_i > 1` for all eight blocks, both execution orders are represented among the
  blocks (they are, by the schedule, if all eight blocks exist: the tool checks it), and the geometric mean of
  the eight `rho_i` is above the largest of the eight A/A ratios of that case and version;
* **screened speedup** if `rho_i < 1` for all eight, both orders are represented, and the geometric mean is below
  the smallest of the eight A/A ratios;
* otherwise **inconclusive**;
* without A/A evidence (no `--aa`, or an A/A row of the case that is not ok): **screen not evaluated**, never a
  silent pass.

Inequalities are strict; `aa_ratio_min` and `aa_ratio_max` are the extremes of the eight A/A ratios. The screens
exist for COMPARABLE cases only.

**Near-target flag** (descriptive and diagnostic only; never a gate, never an accuracy threshold). For a finite
positive target `t` and a valid certificate value `v` (`worst_value` of the metrics row, status `ok`):
`accuracy_fraction = v / t`. The band is `missed/invalid` if the status is not `ok`, or `v` or `t` is not finite
(or `t` is not positive), or `v > t` (the numerical outcome takes precedence); `near target` if
`0.9 <= v / t <= 1`; `margin` if `0 <= v / t < 0.9`. The continuous ratio and the actual value and target are always reported, not only the
band. It is computed per block for A and for B (`a_accuracy_fraction` and the others) and for every row of
`not_ok`.
