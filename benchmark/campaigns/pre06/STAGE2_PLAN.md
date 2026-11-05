# Stage 2 design: immutable pre-0.6 solver baseline and later 0.6 migration comparison

**Status: PROPOSAL FOR REVIEW — no cases, environments, or results are frozen by this document.**  
**Tracking:** [ProximalSolvers #110](https://github.com/mlakolar/ProximalSolvers.jl/issues/110) (Stage 2); [ProximalBase #527](https://github.com/mlakolar/ProximalBase.jl/issues/527) (downstream 0.6 migration and release blockers); [Stage 1 PR #203](https://github.com/mlakolar/ProximalSolvers.jl/pull/203) (merged baseline harness).  
**Scope:** design and acceptance contract; no solver changes, numerical tolerance changes, benchmark runs, CI changes, or 0.6 dependency migration in this PR.

## 0. Executive decision and ordering

We need a reproducible record of how the **last known pre-migration ProximalSolvers stack** behaves at independently certified accuracy, **before** modifying its dependency compat or solver code to accommodate ProximalBase 0.6. The archived record then provides a historical reference for migration diagnosis; it is **not**, by itself, a calibrated causal performance comparison across different days or machines.

Split Stage 2 into two separately reviewable deliverables:

1. **Stage 2A (now, P0):** pre-register a small representative case set, pin a 0.5-based software stack, collect fresh-process baseline observations, validate every record, and publish a durable immutable archive and concise baseline receipt. Stage 2A ends only when a different developer could reproduce the campaign.
2. **Stage 2B (during the actual 0.6 downstream migration, P0):** freeze the 0.6 candidate stack; execute **the same meaningful workloads with the same independent certification contract**; compare the two declared stacks with a migration-specific report that explicitly records all dependency differences. Prefer a new contemporaneous, interleaved A/B confirmation run on controlled hardware if the intent is to assess performance change rather than merely describe two historical snapshots.

**Keep #110 open** while Stage 2B and the later statistical/PR evidence stages remain outstanding. The ProximalBase #527 integration and compatibility obligations are separate release blockers and cannot be satisfied by benchmark certificates alone.

### Non-goals and hard boundaries

- Do **not** replace the authoritative `benchmark/run.jl`, `cases.jl`, `certificates.jl`, `validate.py` or the ordinary strict `compare.py`. Stage 1 already delivered `PS_CASES` and fast exploratory `local.jl`.
- Do **not** introduce a generic benchmarking framework, daemon, database, CI performance gate, or new Julia dependencies.
- Do **not** change algorithms, tolerance targets, stopping criteria, numerical work, or fixture generation to make results look better.
- Do **not** regard a certificate from the solver's stopping flag as independent verification: retain the existing post-solve certification.
- Do **not** run a formal Stage 2A campaign in a Revise/warm session. That mode is for development triage only.
- Do **not** force the ordinary comparator to accept mismatched ProximalBase source/Manifest identities. A distinct labeled migration analysis must handle such comparisons.
- Do **not** apply the ProximalBase kernel-level 5% criterion to whole solver workflows. Stage 3 of #110 will calibrate inferential rules separately.

## 1. Inputs, dependencies, and immutable identities

### 1.1 Proposed historical anchor

| Component | Proposed Stage 2A identity | Requirement |
|---|---|---|
| ProximalSolvers | clean commit `b0de3f7fc91767b97197ff4b458207e308998943` (merged Stage 1) | Verify checkout SHA, `Project.toml`, and package source fingerprint; justify any newer alternative **before** freeze |
| ProximalBase | **registered** version `0.5.4` | Resolve via the versioned registry, record the registry git-tree SHA and loaded source fingerprint; do not use current `master` at `0.6.0-DEV` |
| Julia | 1.10.x and 1.13.x, if available | Two **separate campaigns/Manifests/reports**; never pool runtimes or treat cross-Julia data as matched samples |
| BLAS/threads | one Julia thread, one BLAS thread | Record vendor/configuration and verify rather than assume environment variables took effect |
| Benchmark harness | the four-file formal fingerprint from the pinned ProximalSolvers checkout | The **same harness definition** is required for strict within-stack comparisons |
| External packages | full resolved Manifest and downloaded artifact identities | Record active Project/Manifest SHA-256, full dependency manifest, and any path-developed dependency source commit |
| Machine | one identified, documented CPU/OS | Prefer an idle or exclusive host; if shared, characterize contention and restrict claims accordingly |

A version number alone is not a pin. A git SHA alone is insufficient when a manifest includes relative `path` dependencies or uncommitted changes. Archive the Manifest **and** all source identities; report a red flag for dirty trees, replaced registries, a changed loaded path, or mismatched package fingerprints.

`0.5.4` is a proposed primary anchor because it is a registered pre-0.6 release and is compatible with ProximalSolvers's currently declared `ProximalBase = "0.5.3"` compat. Verify this compatibility in an actual clean resolution. A last-0.5 development snapshot (e.g., `ecb00cc5` if independently verified) may be useful as an **optional second, independently labeled reference**, but must not contaminate or replace the registered `0.5.4` series. Do not create that extra campaign by default.

### 1.2 Exact provenance to capture

- UTC run timestamps, campaign ID, git remote URLs, branch (for reference), immutable HEAD SHAs, git dirty status, and package SHA-1 fingerprints computed by the harness.
- `Project.toml` and `Manifest.toml` *bytes* plus SHA-256 for each Julia version; installed package/version/git-tree information; source locations; Julia build/version; BLAS vendor and threads.
- OS/kernel, CPU model and logical/physical cores, architecture, RAM if available, BLAS library, active Julia threads, environment settings, available power/frequency/governor/affinity metadata. Clearly label unavailable hardware fields rather than invent values.
- Exact four-file harness hash, exact `PS_CASES` filter and catalog, dataset seed scheme and repetition numbers, case-specific data hashes, independent measures and targets.
- Command, return code, stdout/stderr, complete raw TSV/TOML files, process timing metadata and file checksums.
- Reproducibility instructions for relocating path-based checkout environments; a copied Manifest pointing to an obsolete absolute path is not sufficient to claim portable reproduction.

**No post-hoc relabeling.** Any change to pinned files or manifest creates a **new campaign identity**. Keep the original raw evidence untouched.

## 2. Pre-registration: select cases before collecting timings

The candidate list is in [`cases-proposed.txt`](cases-proposed.txt). **This file is a review proposal, not the frozen execution input.** Following review, make an explicit freeze commit that copies the approved exact IDs, in approved order, into `cases.txt`, records the SHA-256 of that file and the full campaign settings in `campaign.toml`, and links that freeze commit on #110 **before the primary measurements**.

### 2.1 Selection rubric

A case earns a place because it covers a named solver family, migration-sensitive API, representative workload, or distinct timing phase—not because its observed ratio is favorable. Prefer:

1. Core production solver workflows at a defined independently checked accuracy.
2. Dense versus sparse representations, structured/group iterates, and symmetric matrix owners.
3. End-to-end `call`, warm `workspace` reuse, and isolated `setup` where they answer different questions.
4. Both legacy fixed-input cases (useful for direct repeatability) and seeded draw-input cases (useful for input variation).
5. At least one longer case whose solve time is not dominated by microsecond timer granularity.
6. A small number of diagnostic cases to investigate changes without diluting the primary set.

An exact case ID is `group/problem/solver/variant/phase`. The agent must verify *every* ID using `PS_SUITE=extended PS_LIST=true` and inspect the live `CaseSpec` metadata (group, `suite`, `inputs`, `measure`, `target`, `phase`). Glob patterns are allowed for discovery, **not** in the frozen primary list. Missing, renamed, or changed cases are **errors**, never silently substituted.

### 2.2 Proposed primary cases (14)

| ID | Proposed exact case ID | Why it is primary / sensitive area |
|---|---|---|
| P01 | `cd/lasso-dense/cd/B/call` | Fixed-input dense coordinate descent; baseline CD whole-solve cost (#108) |
| P02 | `cd/lasso-csc/cd/B/call` | Fixed-input CSC/sparse coordinate descent (#108); sparse access/iteration |
| P03 | `cd/lasso-dense/cd/B/workspace` | Reused CD workspace/reset semantics; distinguish warm solver from setup |
| P04 | `cd/group-lasso/cd/tight/call` | Group/block penalty; check actual iterate/AtomIterate path and cover group operations |
| P05 | `sgl/sparse-group/cd/tight/call` | Sparse-group penalty interaction, regularization and restricted coordinates |
| P06 | `cd/weighted-lasso/cd/tight/workspace` | Weighted parameter and workspace handling; numerical/iterate contract |
| P07 | `gradient/lasso/apg/tight/call` | Accelerated proximal gradient; representative full call |
| P08 | `gradient/lasso/apg/tight/workspace` | APG workspace reuse and post-edit allocation/stopping changes |
| P09 | `newton/logistic-weighted-offset/prox-newton/tight/call` | Weighted/offset GLM and Newton path; prox and gradient inner work |
| P10 | `newton/glasso/quic/tight/call` | QUIC and symmetric/LogDetLoss sensitive path from ProximalBase #527 |
| P11 | `admm/lasso/admm/B/call` | Historical fixed-input ADMM solve (#109) |
| P12 | `admm/lasso/admm/B/workspace` | ADMM warmed factorization and workspace reuse |
| P13 | `admm/lasso/admm/construction/setup` | Separate factorization/cache setup; never combine with warmed call timing |
| P14 | `paths/lasso/cd/grid8/call` | Multi-level path completeness, state clearing/reuse, independent certificates |

### 2.3 Proposed diagnostic cases (4)

| ID | Proposed exact case ID | Why it is diagnostic |
|---|---|---|
| D01 | `gradient/lasso/active/B/call` | Active-set/restriction behavior, potential MoreauEnvelope/accessor migration impact |
| D02 | `newton/glasso-larger/quic/tight/call` | Extended larger QUIC to escape microsecond-scale noise |
| D03 | `cd/lasso-D/cd/tight/call` | Extended alternate design/dimension; representation sensitivity |
| D04 | `primal_dual/generalized-lasso/condat-vu/tight/call` | Independent generalized-lasso/primal-dual family |

**Proposed count: 14 primary + 4 diagnostic = 18 exact cases.** Their literal spellings are derived from the current `benchmark/cases.jl` definitions but must still be confirmed with `PS_LIST` on the **pinned** Stage 2A checkout. The diagnostic list is part of the preregistration; results from it must not be cherry-picked to replace unfavorable primary cases.

### 2.4 Relationship to #527 migration ledger (not a replacement for testing)

| #527 change/risk | Evidence provided by this baseline | What benchmarks **cannot** verify |
|---|---|---|
| Exact symmetry in `LogDetLoss`/KronQuadratic; symmetric penalties/owners | QUIC/glasso P10 and extended D02, plus group-related paths where actually exercised | Asymmetric-input rejection, every weight-symmetry edge case, and user-matrix validation require dedicated correctness tests |
| Owner no longer being an `AbstractMatrix`; private fields/accessors | CD/group P04/P05, QUIC P10, paths P14; inspect actual code reachability | All 36+ `x.p` call sites, `nnz`/mutator semantics and private-field removal require source audit and integration tests |
| Zero-clearing / strong-zero / coordinate-view changes | Path reuse P14, workspace P03/P06/P08/P12, sparse P02 | Correctness of aliasing, `fill!`, structural zero and view identity requires adversarial unit tests |
| Nonseparable MoreauEnvelope restriction / active set | D01 active-set diagnostic | Invalid configurations are expected to throw; only targeted tests prove rejection |
| Mixed precision, NaN propagation, invalid step/coefficient handling | Whole-solve workloads at their existing Float64 contract only | These cases do **not** certify NaN/mixed-precision compatibility: retain #527 numerical-contract tests |
| Compat bump for ProximalBase 0.6 | Version and Manifest evidence | Release compatibility and downstream integration are separately required by #527 |

Review the actual types and called methods for group/AtomIterate claims. A benchmark case whose name suggests group behavior is not, by its name alone, proof of exact API reachability. Explicitly document any missing path coverage and link its correctness test or migration ledger entry.

## 3. Freeze gate: what must be signed off before measurement

**Gate F0 — Proposal review.** Maintainer reviews the 18-case selection, primary/diagnostic labels, migration mapping, pinned stack, Julia versions, machine choice, 5-repetition budget, data archive location, and any known missing cases. Corrections are made openly in this plan PR or a separate freeze PR.

**Gate F1 — Immutable freeze.** In an implementation PR separate from this design PR, commit:

- `benchmark/campaigns/pre06/cases.txt`: exact approved IDs, one per line, no commentary or globs.
- `benchmark/campaigns/pre06/campaign.toml`: versioned campaign ID, case list digest, roles, pinned checkout/dependency references, Julia versions, sampling settings, fresh-process policy, hardware eligibility, retry policy and archive destination.
- `benchmark/campaigns/pre06/README.md`: reproduction commands and how to verify hashes; link this design plan.
- Optionally a **tiny orchestration wrapper** around the existing runner if it removes error-prone manual steps. It must not change measurement semantics or invent a new engine.

Record the approved campaign manifest's commit SHA and a timestamped freeze receipt in #110. **Do not run the official performance campaign before F1.** Correctness/setup pilot observations collected before F1 are explicitly discarded for inferential purposes; they cannot be counted as official repetitions.

**Re-freeze conditions:** If an ID does not exist in the pinned checkout, a target is invalid, an environment cannot resolve cleanly, or a specified workload is unusably slow, propose a reasoned versioned amendment, obtain review, and create a new campaign ID. Keep old freeze artifacts and logs. Never rewrite a frozen case list to discard poor results.

## 4. Stage 2A environment setup and correctness pilot

1. Clone/check out the exact approved ProximalSolvers commit **in a clean isolated directory**. Confirm `git status --porcelain` is empty and `git rev-parse HEAD` matches the frozen SHA.
2. From that pinned checkout, use `benchmark/setup.jl` to create a **fresh distinct environment** per Julia version with registered `0.5.4`. No pre-existing `Project.toml` may be overwritten. Verify `Pkg.dependencies()`, loaded package paths, registry tree identity and manifests.
3. Save an immutable copy of each environment's `Project.toml` and `Manifest.toml` *before* formal runs; compute SHA-256. Avoid writing these snapshots into the mutable solver checkout.
4. Use one Julia thread and one BLAS thread; record the detected values from the formal metadata. Keep the formal `run.jl` harness untouched.
5. Check exact case selection via `PS_LIST=true` and compare its list **exactly** against the approved case file (no extras, duplicates or omissions). Inspect `measure`/`target` and case `inputs`.
6. Run `benchmark/check_analysis.py` and a small **correctness/setup pilot** in separate result directories. Ensure every case constructs, returns a valid independent certificate, and produces complete metadata. Flag non-`ok` cases for review; do not edit solver settings to suppress them.
7. Estimate runtime from the pilot; record cold startup, compilation, per-case solve duration, and total expected cost for five fresh repetitions. The pilot is diagnostic and must not become an unregistered selection filter.
8. Confirm that a shared CPU does not have sustained workload interference that makes the campaign unusable. A second machine is optional; choosing a quiet or exclusive machine is preferable to collecting extra noisy replications.

### Proposed settings (to review and then freeze)

| Setting | Proposal | Why |
|---|---|---|
| `PS_SUITE` | `extended` | Makes diagnostic larger cases available |
| `PS_GROUPS` | `cd,sgl,gradient,newton,admm,paths,primal_dual` | Explicitly bounds discovery; `PS_CASES` remains authoritative |
| `PS_CASES` | comma-joined approved `cases.txt` | Exact ID pre-registration |
| `PS_REPETITION` | integer `1..5` | Five **fresh processes**; inputs keyed by scenario and repetition |
| `PS_SAMPLES` | `50` | Within-process timing samples; **not 50 independent replications** |
| `PS_SECONDS` | `1` | At most one accumulated timed second per case after minimum sample requirements |
| `PS_CASE_SECONDS` | `60` | Existing per-call limit; note first validation call is exempt |
| `PS_PROFILE_SECONDS` | `0` | Do not intermingle profiling with measurement |
| `PS_EXPECTED_PACKAGE_ROOT` | exact pinned checkout | Detect accidentally loading a different package |
| `PS_OUTPUT` | clean, unique location for each Julia version and campaign | Preserve completed/interrupted data |
| `JULIA_NUM_THREADS` | `1` | Formal runner requirement |
| BLAS threads | `1` verified in metadata | Required comparability; runner sets this |

The proposal is a **design**, not a hardcoded mandate. Any modification belongs to F0/F1 review and becomes part of the frozen settings. The exact pinned Julia patch versions must be recorded. If extended cases require more than the current timeout, explicitly revise the full campaign **before** official timing, rather than silently changing only a failing repetition.

### Illustrative command recipe (execute only after F1)

All paths below are examples and must be resolved to the frozen checkout and approved archive root. Avoid executing against an active development tree.

```bash
PINNED=/absolute/path/to/clean-pinned-ProximalSolvers
OUT=/absolute/path/to/campaign-results/pre06-julia113
ENV_DIR=/absolute/path/to/campaign-env/pre06-julia113
cd "$PINNED"

julia +1.13 benchmark/setup.jl "$PINNED" "$ENV_DIR" 0.5.4

export JULIA_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export PS_SUITE=extended
export PS_GROUPS=cd,sgl,gradient,newton,admm,paths,primal_dual
export PS_CASES="$(paste -sd, benchmark/campaigns/pre06/cases.txt)"
export PS_SAMPLES=50
export PS_SECONDS=1
export PS_CASE_SECONDS=60
export PS_PROFILE_SECONDS=0
export PS_EXPECTED_PACKAGE_ROOT="$PINNED"
export PS_OUTPUT="$OUT"

PS_LIST=true julia +1.13 --project="$ENV_DIR" benchmark/run.jl

# Use a fresh process for EACH repetition, and preserve non-ok exits.
for REP in 1 2 3 4 5; do
  export PS_REPETITION="$REP"
  julia +1.13 --project="$ENV_DIR" benchmark/run.jl
  STATUS=$?
  printf 'rep=%s exit=%s\n' "$REP" "$STATUS"
  if [ "$STATUS" -eq 3 ]; then
    echo "Recording/startup failure; investigate. Do not overwrite." >&2
    exit 3
  fi
  # Exit 2 preserves complete records with non-ok numerical cases.
done

python3 benchmark/validate.py "$OUT" "$OUT-validation.json" --expected-runs 5
python3 benchmark/summarize.py "$OUT" "$OUT-summary" --expected-runs 5
python3 benchmark/check_analysis.py
```

Do the corresponding Julia 1.10 run in its **own environment, result root and report**, not the same output directory. A wrapper that continues on exit code 2 must still fail the **numerical acceptance decision** and record every adverse case; exit code 0 from the wrapper is not proof of all-`ok` numerical results.

## 5. Stage 2A measurement and retention rules

**Primary unit of independent replication:** a complete fresh Julia process/repetition. The 50 `@timed` samples in a process are used to estimate that process's case median and allocations; they are not independent observations for a confidence interval across environments.

- Run the approved frozen workload list. The runner uses a deterministic shuffled case order per repetition; preserve the order and seed scheme rather than rearranging based on speed.
- Prefer a stable power/temperature/CPU-affinity regime and a quiet host; log available load indicators and other jobs. An uncontrolled shared run is an **observational baseline**, not an inferential release gate.
- Do not drop the largest, slowest or failed repetition. Do not rerun a single adverse case and overwrite its first series. Any rerun is an **additional fully documented campaign** or a predeclared complete-repeat policy.
- Do not report microsecond-scale ±2× swings as reliable regression findings. The Stage 1 campaign observed this with both warm sessions and distinct fresh processes; pair interpretation with machine conditions and longer workloads.
- Record case status independently of timing: `ok`, `target_missed`, `uncertifiable`, `incomplete`, `timeout`, `error`. A case may have a structurally valid record set and still fail numerical acceptance.
- Distinguish phases. Setup/factorization timings and warmed `workspace` or `call` timings are **not additive by definition** and must not be presented as one end-to-end operation without a separate measured definition.
- Include Julia heap allocation medians and process-wide RSS, while explicitly noting that native heap allocations and per-case peak RSS are not captured by the current harness.
- Preserve raw iterations, passes and prox/gradient/factorization counters **when exposed by the returned solver results**. The formal harness does not currently have the exploratory reporter's `diagnostics` column: label unavailable counters honestly, or use a separate untimed diagnostic receipt without modifying formal timing/certification.
- Validate every case and repetition's data hashes. Fixed inputs should have identical hashes for the same fixed scenario across repetitions. Draw inputs can legitimately vary by repetition; they must match between pre/post migration for each matched seed/repetition where comparisons are claimed.

### Integrity gate A (records)

Run `validate.py --expected-runs 5`; check complete expected process prefixes, no overwritten/interrupted results, catalog IDs/order, provenance/settings consistency, seed and data integrity, per-sample metrics, status counts, final metadata, and recorded time/byte statistics. A non-`valid` result blocks baseline publication.

### Numerical gate B (certificates)

Inspect each primary and diagnostic case across **all** repetitions. Report number of `ok`/non-`ok`; worst and median independent certificate value against the frozen target, and the detailed non-`ok` reason. Unexpected failed primary cases block an unconditional “healthy reference” label even when gate A passes; archive them as evidence and ask for a maintainer decision.

### Evidence gate C (machine/noise)

Present case-level median of repetition medians, each repetition's median (not just one aggregate), range/IQR or other descriptive spread, median bytes and any conspicuous instability. Include cold/warm runtime context and machine contention. No percentage noninferiority claim, statistical significance claim or 5% gate is authorized by Stage 2A alone.

### Archival gate D (reproducibility)

Evidence must be available from a **durable** location with an immutable archive checksum and recovery instructions. An expiring Actions artifact by itself does not meet this requirement. Confirm a second checkout can reproduce the case selection, environment identities and validation procedure before declaring Stage 2A complete.

## 6. Exact evidence bundle and publication receipt

Suggested durable archive layout (the implementation may refine naming without losing fields):

```text
pre06-stage2a-campaign-v1/
  README.md                        # purpose, status, links, hardware, commands
  FREEZE.md                        # approval, frozen commit, date, change log
  cases.txt                        # 18 exact IDs, roles stored in campaign.toml
  campaign.toml                    # parameters and immutable references
  checkums.sha256                  # per-file checksums
  julia-1.10/
    Project.toml
    Manifest.toml
    environment-inventory.txt
    machine-inventory.txt
    commands-and-exit-codes.log
    raw/
      julia-1.10.X-rep01-*.tsv / *-metadata*.toml
      ... through rep05
    validation.json
    summary/SUMMARY.md
    summary/summary.csv
  julia-1.13/
    Project.toml
    Manifest.toml
    environment-inventory.txt
    machine-inventory.txt
    commands-and-exit-codes.log
    raw/
      julia-1.13.X-rep01-*.tsv / *-metadata*.toml
      ... through rep05
    validation.json
    summary/SUMMARY.md
    summary/summary.csv
  independent-review.md
```

**Checksums:** produce SHA-256 for all evidence files and for the compressed archive itself; record SHA-256 *outside* the archive as well. Use `shasum -a 256` on macOS or `sha256sum` on Linux. Avoid self-referential checksum bookkeeping mistakes. Archive metadata must say whether the manifest contains machine-specific absolute paths.

**Publication:** upload the immutable bundle to an agreed persistent source (e.g., a correctly maintained repository release asset or project archival storage), not to normal git history and not solely to a short-lived CI artifact. Include its browser URL, archive checksum, retention expectation and retrieval commands on #110. If durable archival credentials/storage are unavailable, finish the checked archive and identify the publication blocker explicitly; **do not claim Stage 2A completed**.

**Git contents should remain small:** versioned campaign files, scripts only if essential, plan, and concise outcome report. No generated `benchmark/results`, Manifests full of machine paths, raw samples, profiles or gigabytes of data committed as ordinary source files.

### Required Stage 2A summary table (separate Julia versions)

| Field | Required |
|---|---|
| Case identifier and role | exact ID; primary or diagnostic; phase; case input type |
| Accuracy | independent measure, target, worst value, number of certified successes/failures |
| Performance | median across fresh-process medians, per-process medians and observed spread |
| Memory/work | per-process Julia allocations, process RSS; iterations/passes/prox etc where actually available |
| Provenance | both package identities, Julia/BLAS/CPU, Manifest SHA-256, harness hash, campaign freeze SHA |
| Evidence | raw file path inside archive, validation result, status and explicit limitations |

Report every primary case, then diagnostics, even if it failed or was extremely slow. Identify very fast cases as **accuracy-sensitive but timing-noise-limited** rather than assigning them a favorable/no-regression verdict.

## 7. Stage 2B: the migration comparison design

Start Stage 2B only after a concrete ProximalBase 0.6 candidate and migrated ProximalSolvers branch are ready for end-to-end testing under #527. The Stage 2A archive is never overwritten.

### 7.1 Two declared stacks, not one hidden variable

- **A:** immutable ProximalSolvers pre-0.6 pin + registered ProximalBase 0.5.4 + frozen dependency Manifest.
- **B:** exact ProximalSolvers migration commit + exact ProximalBase 0.6 candidate SHA/version + its frozen Manifest, compat adjustments and other declared dependency changes.
- The same meaningful input generator, data hashes/seeds, independent accuracy definition, target, phase and case ID must be used wherever possible.
- A changed ProximalSolvers implementation, dependency or numerical stopping rule means the measured difference is a **whole-stack migration difference**, not a causal attribution to ProximalBase alone. Record the exact changes explicitly.

### 7.2 Compatibility audit is upstream of performance

1. Resolve the 0.6 candidate with explicit compatibility; never silently relax compat or use an accidental `[sources]` override. Run #527 integration/correctness gates.
2. Check coverage for symmetric owner / LogDetLoss validation, `x.p` and other private fields, owner clearing, coordinate views, MoreauEnvelope restrictions, strong zeros, NaN/mixed precision, and specialized solver constructors. Add ordinary package/integration tests for missing risks; do not add them as performance-only cases.
3. Verify that the **same test problem** can still be constructed and independently certified. If its semantics differ, mark the case **not directly comparable** and write a reviewable mapping or separate replacement series.
4. Stop and report new `target_missed`, `uncertifiable`, `incomplete`, `timeout` or `error` outcomes before interpreting speed. A faster result at worse certified accuracy is not a valid speedup.

### 7.3 Measurement alignment and noise control

The Stage 2A historical run and a future 0.6 run occur at different times and may use different host conditions. **Do not call those two archives a paired statistical experiment.** For defensible performance decisions:

1. Prefer to run **both immutable A and B stacks again contemporaneously** on the same quiet/exclusive pinned hardware, with five fresh-process paired blocks as an initial pilot (or another prespecified budget supported by noise/cost).
2. Counterbalance the execution order across blocks (A/B, B/A) and preserve exact hardware, Julia, BLAS/thread counts, sampling limits, data hashes, harness and accuracy contract.
3. Distinguish a descriptive historical ratio from a fresh matched-block comparison; explicitly say when cross-stack strict equality checks are intentionally inapplicable.
4. The ordinary `compare.py` intentionally checks ProximalBase/Manifest/harness compatibility. Keep that behavior unchanged. Develop a **separately named migration-only reader/report** *only if needed*, with a narrowly declared allowlist of dependency differences, strict case/input/certificate validation, and a prominent attribution warning.
5. Report per-case ratios and absolute differences for `call`, `workspace` and `setup` individually, along with achieved certificate, allocations, and solver work. Mark noisy or ambiguous differences **inconclusive**.
6. Stage 3 of #110 must calibrate formal one-sided noninferiority/improvement rules; Stage 2 may document practical investigation and maintainer decisions but must not invent a universal significance or 5% margin.

### 7.4 Decision and escalation matrix

| Observed outcome | Action |
|---|---|
| New failed/missed certificate, incomplete path or unconstructible case | **Block acceptance** for that workload; investigate correctness/compat first |
| Changed case definition, target, input, solver phase or hash | **Not comparable**; require explicit remapping and review |
| Substantial reproducible slowdown at matched certified accuracy | Diagnose iteration count versus inner-kernel cost, setup, allocations; document maintainer decision and possible release blocker |
| Small or noisy apparent slowdown/speedup | **Inconclusive** unless calibrated confirmation resolves it; do not automatically block 0.6 on a 2–5% noisy case |
| Large allocation/RSS increase without timing evidence | Investigate independently; heap bytes and RSS have different meanings |
| Candidate passes all matched primary workflows, no unexplained major losses | Stage 2B can be signed off; #527 downstream compatibility/integration release gates still apply |

Stage 2B outputs: two precise stack receipts, frozen case mapping, full raw archives with per-file hashes, fresh matched-block evidence where obtained, an explicit migration comparison report, a list of open incompatibilities and performance changes, and a maintainer signoff. Update the #527 ledger **only for demonstrated resolved migration requirements**.

## 8. Risks, failure containment, and audit log

| Risk | Preventive control / response |
|---|---|
| Hidden ProximalBase 0.6 dependency in a “pre06” result | Registered 0.5.4 resolution, loaded source fingerprint, Manifest and registry git-tree SHA; hard fail |
| Case cherry-picking after seeing results | Primary/diagnostic roles and settings frozen before formal campaign; every attempted series retained |
| Fresh-process compilation mistaken for steady solve | First validation excludes compilation from timed sample medians; report first-call timing separately |
| Tiny cases yielding 2× variations | Explicit noise limitations, longer diagnostic cases, independent repeated processes; no statistical declaration |
| A failed certificate omitted from performance summary | Two independent gates: record integrity **and** numerical acceptance; always list failures |
| Path-dependent environment not reproducible | Archive source SHAs, Manifests, relocation instructions; verify in a second checkout |
| Mixing Julia versions or host types | Separate collections, reports, and comparison strata |
| Unexpectedly expensive cases | Readiness pilot and prespecified budget; any mid-course change creates a versioned amendment |
| Baseline results accidentally overwritten | Unique output roots, runner's refusal to overwrite prefixes, archive before cleanup |
| Publishing only expiring artifacts | Durable store, SHA-256 and URL on #110, retrieval smoke |
| 0.6 comparison falsely attributed to ProximalBase alone | Explicit two-stack manifest, solver migration diff, whole-stack interpretation |
| CI changes disrupt risk-tiered #121 checks | Defer `check_local.jl` smoke to its own issue/PR; do not modify CI in this campaign |

Maintain an audit log on #110 for F0/F1 review, the freeze commit, baseline run ID and machine conditions, validation status, archive URL/checksum, deviations from plan and Stage 2B transition. Do not edit prior historical evidence to remove a deviation; append a correction.

## 9. Work breakdown, PR boundaries, review points

**PR A — this design PR:** review and refine this plan plus `cases-proposed.txt`. No official measurements. The review must settle the case set, pinned ProximalSolvers commit, machine/noise policy, five-repetition budget, two Julia versions and durable archive destination. **Merge only after maintainer approval of the design; merging this PR is not F1.**

**PR B — Stage 2A freeze and runner receipt (small, separate):** create approved `cases.txt` and `campaign.toml`, exact reproducibility instructions, and an optional minimal runner wrapper only where warranted. Confirm `PS_LIST` exactly matches. Commit the freeze, link on #110, and freeze before official timing.

**Execution outside the PR:** run the frozen campaign and integrity/numerical checks without altering source code or settings. Upload the raw evidence outside git.

**PR C — Stage 2A results receipt (docs only if useful):** concise per-case and per-Julia summary with archive/checksum and deviation log; independent review that archive revalidates. Check only the baseline-related Stage 2 checkbox on #110. Keep #110 open.

**Later PR D — Stage 2B migration comparison:** only after the 0.6 compatibility work provides an executable candidate. Its plan must explicitly declare any cross-stack comparator adaptation and independent accuracy matching.

**Separate CI follow-up:** `check_local.jl` smoke on benchmark source changes is valuable, but #121's CI redesign is closed. Track through a small new issue and a separate risk-tiered CI PR; this is not a prerequisite for Stage 2A.

### Acceptance checklist — this design PR

- [ ] All proposed exact IDs checked against the pinned checkout with `PS_LIST` and their metadata inspected.
- [ ] Coverage mapping to #527 reviewed; known unexercised breaking changes identified.
- [ ] Primary/diagnostic roles and sample settings approved **before** F1.
- [ ] Registered ProximalBase 0.5.4 and ProximalSolvers pre-0.6 SHA approved.
- [ ] Julia version and machine/noise policy approved.
- [ ] Durable archive owner/location and retrieval policy approved.
- [ ] No solver, certificate, formal comparator, dependency compat, or CI changes in this PR.
- [ ] #110 remains open and no Stage 2 checkbox is prematurely marked complete.

### Acceptance checklist — Stage 2A (not fulfilled by this PR)

- [ ] Frozen definition linked on #110, with immutable case file/config digests and software sources.
- [ ] Fresh-process repetitions executed for each approved Julia version.
- [ ] Per-series integrity validation passes, with complete file/record coverage.
- [ ] Numerical failures disclosed and dispositioned; primary certified accuracy assessed explicitly.
- [ ] Raw evidence, environment/Manifest identities, logs and checksums stored durably outside git.
- [ ] Independent retrieval/revalidation and concise baseline report complete.
- [ ] Historical baseline checkbox updated without implying the 0.6 comparison is complete.

### Acceptance checklist — Stage 2B (later)

- [ ] Compatible 0.6 candidate passes #527 integration requirements.
- [ ] Frozen workloads, inputs and accuracy thresholds reconciled across two explicit stacks.
- [ ] Any omitted, failed or semantically changed cases clearly reported.
- [ ] Contemporary counterbalanced A/B evidence collected where performance conclusions are needed.
- [ ] Migration-only report distinguishes descriptive ratios from statistically supported decisions.
- [ ] No unexplained material primary-workload degradation remains without maintainer disposition.
- [ ] #110 and #527 updated with separate, accurate completion evidence.

## 10. Decisions explicitly requested from the maintainer

1. **Reference:** registered ProximalBase `0.5.4` + ProximalSolvers `b0de3f7`, or a different justified pre-migration ProximalSolvers SHA?
2. **Case breadth:** approve the proposed 14+4 IDs? Should `slope`, nonconvex, quadratic CD or a separate AtomIterate-specific workload replace any candidate based on the actual #527 code path?
3. **Hardware:** is one measured quiet workstation sufficient for the historical archive, or is a quiet pinned cluster node available? Avoid delaying the archive for an expensive statistical platform that Stage 3 will address.
4. **Replications and versions:** five independent fresh-process runs on Julia 1.10 and 1.13, after a noninferential pilot?
5. **Durable publication:** which repository Release, project archive or object storage is the authoritative long-lived home? Identify who can upload and retrieve it.
6. **Stage 2B authority:** who signs off on workload/accuracy mapping and material-regression dispositions alongside #527 compatibility checks?

**Requested outcome of this PR:** approve a careful, auditable execution contract for Stage 2; do **not** conflate approval with having completed any historical measurement or the future migration comparison.
