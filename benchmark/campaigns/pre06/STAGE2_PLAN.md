# Stage 2 design: immutable pre-0.6 solver baseline and later 0.6 migration comparison

**Status: DESIGN. The F0 decisions D1–D6 (§10) are approved by the maintainer ([record](https://github.com/mlakolar/ProximalSolvers.jl/pull/212#issuecomment-6650942186)). No cases, environments, or results are frozen by this document, and merging this PR is not the freeze (F1).**
**Tracking:** [ProximalSolvers #110](https://github.com/mlakolar/ProximalSolvers.jl/issues/110) (Stage 2); [ProximalBase #527](https://github.com/mlakolar/ProximalBase.jl/issues/527) (downstream 0.6 migration and release blockers); [Stage 1 PR #203](https://github.com/mlakolar/ProximalSolvers.jl/pull/203) (fast local exploratory workflow; the formal harness is [#116](https://github.com/mlakolar/ProximalSolvers.jl/issues/116), PR [#118](https://github.com/mlakolar/ProximalSolvers.jl/pull/118)).
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
- Do **not** force the ordinary comparator to accept mismatched ProximalBase versions or source fingerprints. A distinct labeled migration analysis must handle such comparisons. `compare.py` does not see Manifests (§7.3), so Manifests are archived and compared by hand.
- Do **not** apply the ProximalBase kernel-level 5% criterion to whole solver workflows. Stage 3 of #110 will calibrate inferential rules separately.

## 1. Inputs, dependencies, and immutable identities

### 1.1 Historical anchor

| Component | Stage 2A identity | Requirement |
|---|---|---|
| ProximalSolvers | clean commit `b0de3f7fc91767b97197ff4b458207e308998943` (merged Stage 1) | Verify checkout SHA, `Project.toml`, and package source fingerprint; justify any newer alternative **before** freeze |
| ProximalBase | **registered** version `0.5.4` | Resolve via the versioned registry; record ProximalBase's Manifest `git-tree-sha1` (optionally also the General registry commit) and the loaded source fingerprint (`proximalbase_hash`); do not use current `master` at `0.6.0-DEV` |
| Julia | 1.10.x and 1.13.x, if available | Two **separate campaigns/Manifests/reports**; never pool runtimes or treat cross-Julia data as matched samples |
| BLAS/threads | one Julia thread, one BLAS thread | Record vendor/configuration and verify rather than assume environment variables took effect |
| Benchmark harness | the four-file formal fingerprint from the pinned ProximalSolvers checkout | The **same harness definition** is required for strict within-stack comparisons |
| External packages | full resolved Manifest and downloaded artifact identities | Record active Project/Manifest SHA-256, full dependency manifest, and any path-developed dependency source commit |
| Machine | one identified, documented CPU/OS | Prefer an idle or exclusive host; on a hybrid CPU, pin to one performance-core logical CPU (§5); if shared or unpinned, characterize contention and restrict claims accordingly |

A version number alone is not a pin. A git SHA alone is insufficient when a manifest includes relative `path` dependencies or uncommitted changes. Archive the Manifest **and** all source identities; report a red flag for dirty trees, replaced registries, a changed loaded path, or mismatched package fingerprints.

`0.5.4` is the primary anchor because it is a registered pre-0.6 release and is compatible with ProximalSolvers's declared `ProximalBase = "0.5.3"` compat (`Project.toml`). `benchmark/setup.jl <checkout> <env> 0.5.4` resolves ProximalBase 0.5.4 on Julia 1.10.13 and 1.13.3 (§2.5).

A version string alone does not prove the registered release. ProximalBase commit `ecb00cc5` reports `0.5.4` in its `Project.toml`, but it is 202 commits ahead of tag `v0.5.4` and contains the 0.6 breaking changes that #527 lists as already on `master`. It is not a pre-0.6 reference and is not proposed as one. Identify the release by the Manifest's `git-tree-sha1` for ProximalBase and compare it with the tree hash of tag `v0.5.4` (`1226119eb2cc6144f7345c727f0e7682632f7826`). No second reference series is planned.

### 1.2 Exact provenance to capture

The formal runner records the following in `<prefix>-metadata-start.toml` and `-metadata.toml` (`benchmark/run.jl:108-127,304-306`): Julia version, repetition, suite, groups, `case_filter` (the raw `PS_CASES` string), the four-file `harness_hash`, ProximalSolvers path, `HEAD` SHA, dirty flag (tracked files only) and package SHA-1 fingerprint, ProximalBase version and source fingerprint, expected package root, Julia and BLAS thread counts, BLAS configuration, CPU name and the model string of the first CPU, sampling settings, seed scheme, scheduler job ID (or `none`), and, at the end, case counts, elapsed seconds, process maximum RSS and a finished flag. The per-case records are `-catalog.tsv`, `-metrics.tsv` (including `data_hash`), `-samples.tsv` and `-errors.tsv`.

The runner does **not** record the following. The wrapper or an inventory file must capture each item, and the archive must state when one is unavailable rather than invent a value:

- UTC timestamps (only `elapsed_s`), campaign ID, git remote URLs and branch.
- `Project.toml` and `Manifest.toml` *bytes* plus SHA-256 for each Julia version, and installed package versions and git-tree hashes (`Pkg.dependencies()`). `run.jl` records no Manifest identity.
- OS and kernel, logical and physical core counts, architecture, RAM, CPU affinity, governor and turbo state, and load.
- Environment variables, command lines, exit codes and stdout/stderr.
- First-call (compile) timing. The validation call is excluded from the sample statistics. If the metric is required, take it per selected case from the pilot or from a separately labelled `benchmark/local.jl` run, whose `first` column is the first certified call including compilation. `elapsed_s` covers the whole process and cannot substitute.
- Reproducibility instructions for relocating path-based checkout environments; a copied Manifest pointing to an obsolete absolute path is not sufficient to claim portable reproduction.

**No post-hoc relabeling.** Any change to pinned files or manifest creates a **new campaign identity**. Keep the original raw evidence untouched.

## 2. Pre-registration: select cases before collecting timings

The candidate list is in [`cases-proposed.txt`](cases-proposed.txt): one exact ID per line, the 14 primary cases, then the five diagnostic cases D01–D05. **This file is the selection approved at F0, not the frozen execution input.** The explicit freeze commit (F1) copies the approved exact IDs, in the same order, into `cases.txt`, records the SHA-256 of that file and the full campaign settings in `campaign.toml`, and links that freeze commit on #110 **before the primary measurements**.

### 2.1 Selection rubric

A case earns a place because it covers a named solver family, migration-sensitive API, representative workload, or distinct timing phase—not because its observed ratio is favorable. Prefer:

1. Core production solver workflows at a defined independently checked accuracy.
2. Dense versus sparse representations, structured/group iterates, and symmetric matrix owners.
3. End-to-end `call`, warm `workspace` reuse, and isolated `setup` where they answer different questions.
4. Both legacy fixed-input cases (useful for direct repeatability) and seeded draw-input cases (useful for input variation).
5. At least one longer-running case, so that run-to-run noise is small relative to the solve time. Timing is recorded in nanoseconds, so the limit is run-to-run noise, not timer resolution. Every primary case is sub-millisecond (§2.5), so per-case ratios on the primaries are noise-limited; the diagnostics D02, D04 and D05 are the longest cases.
6. A small number of diagnostic cases to investigate changes without diluting the primary set.

An exact case ID is `group/problem/solver/variant/phase`. Verify *every* ID with `PS_SUITE=extended PS_LIST=true`. That command prints only the ID, the suite and the issue (`benchmark/run.jl:323`); take `inputs`, `measure`, `target` and `phase` from `benchmark/cases.jl` or from a run's `-catalog.tsv`. Glob patterns are allowed for discovery, **not** in the frozen list. Missing, renamed, or changed cases are **errors**, never silently substituted.

### 2.2 Primary cases (14)

| ID | Exact case ID | Why it is primary / sensitive area |
|---|---|---|
| P01 | `cd/lasso-dense/cd/B/call` | Fixed-input dense coordinate descent; baseline CD whole-solve cost (#108) |
| P02 | `cd/lasso-csc/cd/B/call` | Fixed-input CSC/sparse coordinate descent (#108); sparse access/iteration |
| P03 | `cd/lasso-dense/cd/B/workspace` | Reused CD workspace/reset semantics; distinguish warm solver from setup |
| P04 | `cd/group-lasso/cd/tight/call` | Group penalty on an `AtomIterate` start (`benchmark/cases.jl:103-104`); covers group operations |
| P05 | `sgl/sparse-group/cd/tight/call` | Sparse-group penalty on an `AtomIterate` start (`benchmark/cases.jl:103-104`) |
| P06 | `cd/weighted-lasso/cd/tight/workspace` | Weighted parameter and workspace handling; numerical/iterate contract |
| P07 | `gradient/lasso/apg/tight/call` | Accelerated proximal gradient; representative full call |
| P08 | `gradient/lasso/apg/tight/workspace` | APG workspace reuse and post-edit allocation/stopping changes |
| P09 | `newton/logistic-weighted-offset/prox-newton/tight/call` | Weighted/offset GLM and Newton path; prox and gradient inner work |
| P10 | `newton/glasso/quic/tight/call` | QUIC through a symmetric owner and `LogDetLoss` (reachability in §2.4) |
| P11 | `admm/lasso/admm/B/call` | Historical fixed-input ADMM solve (#109) |
| P12 | `admm/lasso/admm/B/workspace` | ADMM warmed factorization and workspace reuse |
| P13 | `admm/lasso/admm/construction/setup` | Separate factorization/cache setup; never combine with warmed call timing |
| P14 | `paths/lasso/cd/grid8/call` | Multi-level path completeness and independent certificates; the untimed reset is the harness's own `fill!` (§7.2) |

### 2.3 Diagnostic cases (5)

| ID | Exact case ID | Why it is diagnostic |
|---|---|---|
| D01 | `gradient/lasso/active/B/call` | Active-set solver with a separable `NormL1` penalty (restriction and `kkt_violation` calls) |
| D02 | `newton/glasso-larger/quic/tight/call` | Larger QUIC problem (n = 400, p = 40; P10 has p = 12) on the same code path as P10 |
| D03 | `cd/lasso-D/cd/tight/call` | Extended alternate design: wide (n = 180, p = 600), independent columns (`benchmark/cases.jl:319`) |
| D04 | `primal_dual/generalized-lasso/condat-vu/tight/call` | Independent generalized-lasso/primal-dual family |
| D05 | `gradient/lasso-D/apg/tight/call` | APG on the same wide design as D03; the longest-running case of a primary family (about 1.9 ms) |

**Count: 14 primary + 5 diagnostic = 19 exact cases.** Their literal spellings come from `benchmark/cases.jl` and were confirmed with `PS_LIST` (§2.5); confirm them again on the freeze checkout. The diagnostic list is part of the preregistration; results from it must not be cherry-picked to replace unfavorable primary cases. No `slope` or nonconvex case is included: #527 names no site specific to them, and its numerical contract is covered by the package tests.

### 2.4 Relationship to #527 migration ledger (not a replacement for testing)

Reachability below is read from the code at `b0de3f7` and says which code a case executes, not whether the code is correct.

| #527 change/risk | Reached by these cases | Not reached; needs other evidence |
|---|---|---|
| Exact symmetry of `LogDetLoss` and `KronQuadratic` (#269) | P10, D02: `LogDetLoss(S)` built from an exactly symmetric `S` (`benchmark/problems.jl:180-188`, `benchmark/cases.jl:40`), passed as a `Matrix` start through `solve!(::Matrix, ::LogDetLoss, …)` (`src/cd/quic.jl:231`) into a `SymmetricSparseIterate` | The `Scaled{<:LogDetLoss}` rebuild (`quic.jl:238-241`); user-facing `KronQuadratic` and `kron.jl` (QUIC's inner model is the internal `KronUModel` in `kronu.jl`); asymmetric-input rejection |
| Per-entry parameters of a `SymmetricSparseIterate` must be symmetric | P10, D02: `_symmetric_penalty` receives the symmetric `Λ` and returns it unchanged (`src/cd/models.jl:577`) | Averaging of asymmetric weights (`models.jl:561-578`), which #527 marks definite |
| Owner stops being an `AbstractMatrix` (`x.p`, `nnz`, mutators; #391 Phase 1) | P10, D02: the `x.p` sites in `quic.jl` (lines 51, 62, 156, 194, 213) and the owner `fill!` calls (`quic.jl:91,138,214`). In `kronu.jl`, `coordinate_step!` (line 70) runs through `_visit!` (`src/cd/models.jl:399-400`); the other five `kronu.jl` sites are not traced | The `x.p` sites in `kron.jl`, `drivers.jl:180`, `generic_newton.jl` and `path.jl`. The generic `coordinate_step!` of `models.jl:384,387`: QUIC's `KronUModel` has its own, more specific method (`kronu.jl:69`). `solver.jl:754` (`_copy_dense!`, for a workspace on a symmetric owner; no case builds one). `gap.jl:1031-1033` (`kkt_residual`, a diagnostic that no case calls). `quic.jl:203` (runs only when a component's start is not positive definite; the identity start is). `_clear_start!(::SymmetricSparseIterate)` (`src/cd/path.jl:19`) |
| Zero-clearing and `fill!` semantics (#424) | P03, P06: each warm solve calls `_clear_start!` on a `SparseIterate` through `_load_dense!` (`src/workspaces.jl:238-239,253`) | The owner clear above. P14 never calls `_clear_start!`: `solve_path` starts from the given `x` (`src/cd/path.jl:448-`). Its reset is the harness's `fill!` (§7.2) |
| Coordinate views, strong zeros, private iterate fields (`x.storage`, `x.nzval`, `x.nactive`, `x.active`) | Executed to the extent that the CD, group and path code of these cases runs them (P01–P06, P14) | `_same_support` in the `debias` option of `ProximalGradientDescent` (`src/solvers/proximal_gradient_descent.jl:200,209`; no case sets `debias`); the full set of private-field sites needs a source audit |
| Nonseparable `MoreauEnvelope` restriction | D01 calls `restrict` and `kkt_violation` with a separable `NormL1` (`benchmark/cases.jl:56,65`) | The nonseparable `MoreauEnvelope` branch that #527 says now throws |
| Mixed precision, NaN propagation, invalid step/coefficient handling (the numerical contract) | Whole-solve workloads at their existing Float64 contract only | NaN and mixed-precision compatibility: retain the #527 numerical-contract tests |
| Compat bump for ProximalBase 0.6 | Version and Manifest evidence | Release compatibility and downstream integration, which #527 requires separately |

**Uncovered #527 paths** (not reached by the 19 cases, or not shown to be reached; each needs the test or ledger entry named):

- the `Scaled{<:LogDetLoss}` rebuild (`src/cd/quic.jl:238-241`): #527, row "Exact symmetry";
- asymmetric-weight averaging (`src/cd/models.jl:561-578`): #527, row "`SymmetricSparseIterate` accepts only symmetric values", which asks for validation instead of averaging (#391 Phase 2, T17);
- `_clear_start!(::SymmetricSparseIterate)` (`src/cd/path.jl:19`): #527, row #391 Phase 1;
- `kron.jl` and user-facing `KronQuadratic` (including `src/cd/drivers.jl:180`): #527, row "Exact symmetry";
- the nonseparable `MoreauEnvelope` restriction: #527, row #271;
- private-field and `_same_support` sites not reached: #527, rows "Private iterate fields" and #391 Phase 1. This checkout has 34 `.p` reads of an owner (33 under `src/cd/` and one in `test/coordinate_descent.jl:514`); #527 counts 36 at its search commit;
- the numerical contract: #527, row #385.

Each of these needs a dedicated correctness test or a ledger entry. A benchmark case whose name suggests group or symmetric behavior is not, by its name alone, proof of API reachability.

### 2.5 Verification record

The checkout used here equals `b0de3f7` except for the two documentation files of this PR.

- **Resolution.** `benchmark/setup.jl <checkout> <env> 0.5.4` resolves ProximalBase 0.5.4 on Julia 1.10.13 and 1.13.3, under the declared compat `0.5.3`.
- **IDs.** All 19 IDs are present in `PS_SUITE=extended PS_LIST=true`, which lists 102 cases; the lists are identical on both Julia versions. 16 of the 19 are `quick`; D02, D03 and D05 are `extended`.
- **Certificates.** Each of the 19 cases returned status `ok` in an exploratory `benchmark/local.jl` run (Julia 1.13.3, one fresh process per invocation). Two invocations were made: one on the 18 IDs of the original selection, and one on 32 extended-suite cases that includes D02, D03 and D05. The table's medians come from these.
- **Timing scale.** The table gives the exploratory median of one unpinned process; it is a scale indicator, not a measurement. The primary medians are 3.3–106 µs. The longest of the 19 cases are D05 (1.93 ms), D02 (0.58 ms) and D04 (0.45 ms). The two invocations together give 50 timings of 48 distinct cases (D02 and D03 are in both); the longest are `primal_dual/generalized-larger/condat-vu/tight/call` (3.47 ms) and D05 (1.93 ms).

| ID | Suite | Inputs | Measure | Target | Median (µs) |
|---|---|---|---|---|---:|
| P01 | quick | fixed | relative_gap | 1e-8 | 4.8 |
| P02 | quick | fixed | relative_gap | 1e-8 | 11.7 |
| P03 | quick | fixed | relative_gap | 1e-8 | 3.3 |
| P04 | quick | draw | relative_gap | 1e-6 | 16.1 |
| P05 | quick | draw | relative_gap | 1e-6 | 56.9 |
| P06 | quick | draw | relative_gap | 1e-6 | 3.6 |
| P07 | quick | draw | relative_gap | 1e-6 | 16.7 |
| P08 | quick | draw | relative_gap | 1e-6 | 14.4 |
| P09 | quick | draw | relative_gap | 1e-6 | 71.0 |
| P10 | quick | draw | relative_gap | 1e-6 | 90.7 |
| P11 | quick | fixed | relative_gap | 1e-8 | 21.0 |
| P12 | quick | fixed | relative_gap | 1e-8 | 19.0 |
| P13 | quick | draw | self_consistency | 1e-12 | 106.0 |
| P14 | quick | draw | relative_gap | 1e-6 | 48.0 |
| D01 | quick | fixed | relative_gap | 1e-8 | 29.2 |
| D02 | extended | draw | relative_gap | 1e-6 | 576.2 |
| D03 | extended | draw | relative_gap | 1e-6 | 77.6 |
| D04 | quick | draw | relative_gap | 1e-6 | 454.9 |
| D05 | extended | draw | relative_gap | 1e-6 | 1930 |

D03 measured 207.6 µs in a second unpinned process; see the hardware policy in §5.

## 3. Freeze gate: what must be signed off before measurement

**Gate F0 — Proposal review: passed.** The maintainer approved the F0 decisions D1–D6 on the design PR ([record](https://github.com/mlakolar/ProximalSolvers.jl/pull/212#issuecomment-6650942186)). F0 covered the 19-case selection, the primary/diagnostic labels, the migration mapping, the pinned stack, the Julia versions, the hardware policy (the machine itself is chosen at F1), the five-repetition budget and the data archive location. The decisions are in §10. Later corrections are made openly in this PR or in a separate freeze PR.

**Gate F1 — Immutable freeze.** In an implementation PR separate from this design PR, commit:

- `benchmark/campaigns/pre06/cases.txt`: the 19 approved IDs, in the order of `cases-proposed.txt`, one per line, no commentary or globs.
- `benchmark/campaigns/pre06/campaign.toml`: versioned campaign ID, case list digest, roles, pinned checkout/dependency references, Julia versions, sampling settings, fresh-process policy, hardware eligibility, retry policy and archive destination.
- `benchmark/campaigns/pre06/README.md`: reproduction commands and how to verify hashes; link this design plan.
- Optionally a **tiny orchestration wrapper** around the existing runner if it removes error-prone manual steps. It must not change measurement semantics or invent a new engine.

Record the approved campaign manifest's commit SHA and a timestamped freeze receipt in #110. **Do not run the official performance campaign before F1.** Correctness/setup pilot observations collected before F1 are explicitly discarded for inferential purposes; they cannot be counted as official repetitions.

**Re-freeze conditions:** If an ID does not exist in the pinned checkout, a target is invalid, an environment cannot resolve cleanly, or a specified workload is unusably slow, propose a reasoned versioned amendment, obtain review, and create a new campaign ID. Keep old freeze artifacts and logs. Never rewrite a frozen case list to discard poor results.

## 4. Stage 2A environment setup and correctness pilot

1. Clone/check out the pinned ProximalSolvers commit `b0de3f7fc91767b97197ff4b458207e308998943` **in a clean isolated directory**. Confirm `git status --porcelain` is empty and `git rev-parse HEAD` equals the pinned SHA; `proximalsolvers_sha` in the run metadata will be this SHA. The freeze commit, checked out separately, holds `cases.txt` and adds only campaign files: confirm that its HEAD equals the freeze SHA recorded on #110, that its tree is clean, that `cases.txt` has the SHA-256 recorded in `campaign.toml`, and that its `Project.toml`, `src/`, `ext/` and the four harness files (`benchmark/problems.jl`, `certificates.jl`, `cases.jl`, `run.jl`) equal those of the pinned commit, so that the package and harness fingerprints agree.
2. From that pinned checkout, use `benchmark/setup.jl` to create a **fresh distinct environment** per Julia version with registered `0.5.4`. No pre-existing `Project.toml` may be overwritten. Verify `Pkg.dependencies()`, loaded package paths, ProximalBase's Manifest `git-tree-sha1` and the manifests.
3. Save an immutable copy of each environment's `Project.toml` and `Manifest.toml` *before* formal runs; compute SHA-256. Avoid writing these snapshots into the mutable solver checkout.
4. Use one Julia thread and one BLAS thread; record the detected values from the formal metadata. Keep the formal `run.jl` harness untouched.
5. Check exact case selection: sort the IDs printed by `PS_LIST=true` and compare them **exactly** with the sorted approved case file (no extras, duplicates or omissions). Inspect `measure`, `target` and `inputs` in `benchmark/cases.jl` or in the pilot's `-catalog.tsv`.
6. Run `benchmark/check_analysis.py` and a small **correctness/setup pilot** in separate result directories. Ensure every case constructs, returns a valid independent certificate, and produces complete metadata. Flag non-`ok` cases for review; do not edit solver settings to suppress them.
7. Estimate runtime from the pilot; record cold startup, per-case first-call time (from `local.jl`), per-case solve duration, and total expected cost for five fresh repetitions. The pilot is diagnostic and must not become an unregistered selection filter.
8. Confirm that a shared CPU does not have sustained workload interference that makes the campaign unusable. Apply the hardware policy of §5 (pinning on a hybrid CPU). A second machine is optional; choosing a quiet or exclusive machine is preferable to collecting extra noisy replications.

### Settings (approved at F0; frozen at F1)

| Setting | Value | Why |
|---|---|---|
| `PS_SUITE` | `extended` | Makes diagnostic larger cases available |
| `PS_GROUPS` | `cd,sgl,gradient,newton,admm,paths,primal_dual` | Explicitly bounds discovery; `PS_CASES` remains authoritative |
| `PS_CASES` | comma-joined approved `cases.txt` | Exact ID pre-registration; stored as the `case_filter` match setting, so Stage 2B reuses the raw string byte for byte, and `PS_SUITE` and `PS_GROUPS` as well |
| `PS_REPETITION` | integer `1..5` | Five **fresh processes**; inputs keyed by scenario and repetition. The runner accepts 1..10 (`benchmark/run.jl:64`); later contemporaneous reruns reuse 1..N in fresh output directories |
| `PS_SAMPLES` | `100` | The extended default (`benchmark/run.jl:65`). Within-process timing samples; **not 100 independent replications** |
| `PS_SECONDS` | `3` | The extended default (`benchmark/run.jl:66`). The longest case (about 2 ms) reaches 100 samples in well under a second, so the limit does not bind |
| `PS_CASE_SECONDS` | `60` | Existing per-call limit; note first validation call is exempt |
| `PS_PROFILE_SECONDS` | `0` | Do not intermingle profiling with measurement |
| `PS_EXPECTED_PACKAGE_ROOT` | exact pinned checkout | Detect accidentally loading a different package |
| `PS_OUTPUT` | clean, unique location for each Julia version and campaign | Preserve completed/interrupted data |
| `JULIA_NUM_THREADS` | `1` | Formal runner requirement |
| BLAS threads | `1` verified in metadata | Required comparability; runner sets this |
| CPU affinity | one performance-core logical CPU per process (hybrid CPU) | Same CPU list for every repetition and both stacks; see §5 |

The settings are fixed at F1 and frozen with the campaign. The exact pinned Julia patch versions must be recorded. If extended cases require more than the current timeout, explicitly revise the full campaign **before** official timing, rather than silently changing only a failing repetition.

### Illustrative command recipe (execute only after F1)

All paths below are examples and must be resolved to the frozen checkout and approved archive root. Avoid executing against an active development tree. **The recipe is Linux-only** (`taskset`, `lscpu`, `sha256sum`, sysfs governor files). Choose the host platform at F1: on Linux, verify the performance-core logical CPU IDs before the campaign; on another platform, record an equivalent verified affinity control or label the archive observational (§5). Do not start a campaign with commands the host lacks. `julia +1.10` and `julia +1.13` assume juliaup channels of those names; `validate.py` needs Python 3.11 or later (`tomllib`). `FREEZE` is a checkout of the freeze commit, which holds `cases.txt`; `PINNED` is the clean `b0de3f7` checkout that is measured.

```bash
set -euo pipefail
PINNED=/absolute/path/to/clean-pinned-ProximalSolvers
FREEZE=/absolute/path/to/clean-freeze-checkout
FREEZE_SHA=FREEZE_COMMIT_SHA_RECORDED_ON_110
CASES_SHA256=DIGEST_RECORDED_IN_CAMPAIGN_TOML
OUT=/absolute/path/to/campaign-results/pre06-julia113
ENV_DIR=/absolute/path/to/campaign-env/pre06-julia113
LOG="$OUT-commands.log"
CPU_LIST=PERFORMANCE_CORE_LOGICAL_CPU   # chosen at F1; same for every repetition and stack
CASES="$FREEZE/benchmark/campaigns/pre06/cases.txt"
JULIA=(julia +1.13 --startup-file=no)   # no user startup file (for example Revise) in formal runs

mkdir -p "$(dirname "$OUT")"
command -v taskset lscpu sha256sum > /dev/null

# logged NAME COMMAND...: record the command, keep its stdout and stderr, return its status
logged() {
  local name=$1 status=0; shift
  printf '%s: %s\n' "$name" "$*" >> "$LOG"
  "$@" > "$OUT-$name.out" 2> "$OUT-$name.err" || status=$?
  printf '%s: exit=%s\n' "$name" "$status" >> "$LOG"
  return "$status"
}

# the pinned checkout: exact commit, clean tree
test "$(git -C "$PINNED" rev-parse HEAD)" = b0de3f7fc91767b97197ff4b458207e308998943
test -z "$(git -C "$PINNED" status --porcelain)"
# the freeze checkout: exact commit, clean tree, the digest recorded in campaign.toml
test "$(git -C "$FREEZE" rev-parse HEAD)" = "$FREEZE_SHA"
test -z "$(git -C "$FREEZE" status --porcelain)"
test -s "$CASES"
test "$(sha256sum "$CASES" | cut -d' ' -f1)" = "$CASES_SHA256"
# the freeze commit must leave the measured package and harness files unchanged
git -C "$FREEZE" diff --exit-code b0de3f7fc91767b97197ff4b458207e308998943 HEAD -- \
  Project.toml src ext benchmark/problems.jl benchmark/certificates.jl \
  benchmark/cases.jl benchmark/run.jl

cd "$PINNED"
logged setup "${JULIA[@]}" benchmark/setup.jl "$PINNED" "$ENV_DIR" 0.5.4

export JULIA_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export PS_SUITE=extended
export PS_GROUPS=cd,sgl,gradient,newton,admm,paths,primal_dual
PS_CASES="$(paste -sd, "$CASES")"; export PS_CASES
export PS_SAMPLES=100
export PS_SECONDS=3
export PS_CASE_SECONDS=60
export PS_PROFILE_SECONDS=0
export PS_EXPECTED_PACKAGE_ROOT="$PINNED"
export PS_OUTPUT="$OUT"
env | grep -E '^(PS_|JULIA|OPENBLAS)' | sort > "$OUT-environment.txt"

# The runner selects every matching extended case when PS_CASES is empty, so check first.
test -n "$PS_CASES"
logged list env PS_LIST=true "${JULIA[@]}" --project="$ENV_DIR" benchmark/run.jl
cut -f1 "$OUT-list.out" | sort > "$OUT-ids.txt"
sort "$CASES" | diff - "$OUT-ids.txt"

# Use a fresh process for EACH repetition; log every command and exit code.
for REP in 1 2 3 4 5; do
  export PS_REPETITION="$REP"
  lscpu -e > "$OUT-lscpu-rep$REP.txt"
  uptime >> "$LOG"
  grep . "/sys/devices/system/cpu/cpu$CPU_LIST/cpufreq/scaling_governor" >> "$LOG" || true
  STATUS=0
  logged "rep$REP" taskset -c "$CPU_LIST" "${JULIA[@]}" --project="$ENV_DIR" benchmark/run.jl || STATUS=$?
  taskset -c "$CPU_LIST" sh -c 'taskset -p $$' >> "$LOG"   # the affinity a pinned process gets
  # 0: all cases ok. 2: complete records with non-ok cases. Anything else
  # (a load or recording failure exits 1 or 3) stops the campaign.
  case "$STATUS" in 0|2) ;; *) echo "Stop; investigate. Do not overwrite." >&2; exit "$STATUS" ;; esac
done

# validate.py exits 2 on invalid records, and set -e then stops before summarize.py.
# Keep that: invalid records block publication; do not drop set -e to obtain a summary.
logged validate python3 benchmark/validate.py "$OUT" "$OUT-validation.json" --expected-runs 5
logged summarize python3 benchmark/summarize.py "$OUT" "$OUT-summary" --expected-runs 5
logged check_analysis python3 benchmark/check_analysis.py
```

The `logged` files (`$OUT-*.out`, `$OUT-*.err`, `$OUT-commands.log`, `$OUT-environment.txt`) belong in the archive's `logs/` directory.

Do the corresponding Julia 1.10 run in its **own environment, result root and report**, not the same output directory. A wrapper that continues on exit code 2 must still fail the **numerical acceptance decision** and record every adverse case; exit code 0 from the wrapper is not proof of all-`ok` numerical results. The recipe records the affinity, the governor and the load average of each repetition; add the turbo state where the host exposes it (§5).

## 5. Stage 2A measurement and retention rules

**Primary unit of independent replication:** a complete fresh Julia process/repetition. The 100 `@timed` samples in a process are used to estimate that process's case median and allocations; they are not independent observations for a confidence interval across environments.

- Run the approved frozen workload list. The order in `cases.txt` does not set the run order: the catalog is sorted by ID (`benchmark/cases.jl:353`) and then shuffled with a generator keyed by the repetition (`benchmark/run.jl:281`). The shuffle depends on the catalog, so adding or dropping a case changes the order in every repetition. Preserve the order and seed scheme rather than rearranging based on speed.
- Prefer a stable power/temperature/CPU-affinity regime and a quiet host; log available load indicators and other jobs. An uncontrolled shared run is an **observational baseline**, not an inferential release gate. The hardware policy below applies.
- Do not drop the largest, slowest or failed repetition. Do not rerun a single adverse case and overwrite its first series. Any rerun is an **additional fully documented campaign** or a predeclared complete-repeat policy.
- Do not report microsecond-scale swings of 2× or more as reliable regression findings. In exploratory runs the same case, unpinned, took 77.6 µs in one process and 207.6 µs in another (D03, below); pair interpretation with machine conditions and longer workloads.
- Record case status independently of timing: `ok`, `target_missed`, `uncertifiable`, `incomplete`, `timeout`, `error`. A case may have a structurally valid record set and still fail numerical acceptance.
- Distinguish phases. Setup/factorization timings and warmed `workspace` or `call` timings are **not additive by definition** and must not be presented as one end-to-end operation without a separate measured definition.
- Include Julia heap allocation medians and process-wide RSS, while explicitly noting that native heap allocations and per-case peak RSS are not captured by the current harness.
- The formal records carry no iteration or inner-work counters, which #110 Stage 2 asks for (`METRICS_HEADER`, `benchmark/run.jl:10-13`). Record them in a separate untimed receipt: for each Julia version and stack, run `julia --project=ENV benchmark/local.jl --save FILE <exact IDs>` once. Its `diagnostics` column holds the counters returned by the solvers (`benchmark/local.jl:327-339,436`). The receipt is labelled exploratory, is not accepted by `validate.py` or `compare.py`, and never replaces formal timing or certification.
- Validate every case and repetition's data hashes. `validate.py` checks only the format of `data_hash` (`benchmark/validate.py:243-246`); that fixed-input hashes agree across repetitions is a manual check on `-metrics.tsv`. Draw inputs can legitimately vary by repetition; they must match between the two stacks for each matched seed/repetition where comparisons are claimed (`benchmark/compare.py:73-75` enforces this).

### Hardware and noise policy

On a hybrid CPU (performance and efficiency cores) the core type changes the time by 1.7–1.9×. A probe pinned each process with `taskset` to one logical CPU of a performance core or of an efficiency core, in two interleaved rounds (Julia 1.13.3, one fresh process each, median time per case):

| Case | Performance core, rounds 1 / 2 | Efficiency core, rounds 1 / 2 |
|---|---:|---:|
| `cd/lasso-D/cd/tight/call` | 119.9 / 108.4 µs | 205.9 / 202.0 µs |
| `newton/glasso/quic/tight/call` | 52.5 / 51.8 µs | 90.6 / 91.2 µs |

Unpinned processes gave mixed results: `cd/lasso-D/cd/tight/call` took 77.6 µs in one process and 207.6 µs in another. Core type, migration of a process between cores, SMT siblings and machine load all matter, and an unpinned observation does not say which applied.

- On a hybrid CPU, pin each process to one performance-core logical CPU whose SMT sibling is idle or offline.
- Use the same CPU list for every repetition and for both stacks.
- Record `taskset -p`, `lscpu -e`, the governor and turbo state, and the load average around each repetition.
- `cpu_model` in the metadata does not distinguish core types, so `validate.py` and `compare.py` cannot detect a core-type mismatch; the wrapper log must show the pinning.
- Where pinning is unavailable, label the archive observational.
- The concrete machine is chosen at F1.

### Integrity gate A (records)

Run `validate.py --expected-runs 5` for each Julia version. It checks: complete expected process prefixes (`benchmark/validate.py:299-304`), no interrupted process (:314), metadata completeness and basic sanity (one Julia and one BLAS thread, hash format, loaded root equal to `expected_package_root`), equality of the series settings within a Julia version (:25-30,323-325, including `case_filter` and `proximalsolvers_hash`), a catalog that is identical between repetitions as an unordered mapping (:101-104,328-331), metrics that cover the catalog once, per-sample consistency, status counts, and recorded time/byte statistics.

It does **not** check the following, which are explicit manual or wrapper steps of this gate:

- the catalog IDs equal `cases.txt` (the recipe diffs the sorted `PS_LIST` output before running; repeat the check on `-catalog.tsv`);
- fixed-input `data_hash` values agree across repetitions (only their format is checked);
- the tree is clean (`proximalsolvers_dirty` is only type-checked, :142-143, and is not a series setting), and `proximalsolvers_sha` is the pinned SHA `b0de3f7` in every repetition (it is not a series setting either);
- the Manifest matches the archived copy (the runner records no Manifest identity).

A non-`valid` result or a failed manual step blocks baseline publication.

### Numerical gate B (certificates)

Inspect each primary and diagnostic case across **all** repetitions. Report number of `ok`/non-`ok`; worst and median independent certificate value against the frozen target, and the detailed non-`ok` reason. Unexpected failed primary cases block an unconditional “healthy reference” label even when gate A passes; archive them as evidence and ask for a maintainer decision.

### Evidence gate C (machine/noise)

Present, for each case, the mean of the per-repetition medians (`benchmark/summarize.py:57,78`) and each repetition's median from `-metrics.tsv` (not just one aggregate), range/IQR or other descriptive spread, median bytes and any conspicuous instability. The Student-t interval that `summarize.py` prints is descriptive only: it uses five repetitions, includes input variability and machine noise, and has no multiplicity correction. Include cold/warm runtime context and machine contention. No percentage noninferiority claim, statistical significance claim or 5% gate is authorized by Stage 2A alone.

### Archival gate D (reproducibility)

Evidence must be available from a **durable** location with an immutable archive checksum and recovery instructions. An expiring Actions artifact by itself does not meet this requirement. Confirm a second checkout can reproduce the case selection, environment identities and validation procedure before declaring Stage 2A complete.

## 6. Exact evidence bundle and publication receipt

Suggested durable archive layout (the implementation may refine naming without losing fields):

```text
pre06-stage2a-campaign-v1/
  README.md                        # purpose, status, links, hardware, commands
  FREEZE.md                        # approval, frozen commit, date, change log
  cases.txt                        # 19 exact IDs (14 primary + 5 diagnostic); roles stored in campaign.toml
  campaign.toml                    # parameters and immutable references
  checksums.sha256                 # per-file checksums
  julia-1.10/
    Project.toml
    Manifest.toml
    environment-inventory.txt
    machine-inventory.txt
    commands-and-exit-codes.log
    logs/                      # stdout/stderr of setup, PS_LIST, each repetition, validation; environment
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
    logs/                      # stdout/stderr of setup, PS_LIST, each repetition, validation; environment
    raw/
      julia-1.13.X-rep01-*.tsv / *-metadata*.toml
      ... through rep05
    validation.json
    summary/SUMMARY.md
    summary/summary.csv
  independent-review.md
```

**Checksums:** produce SHA-256 for all evidence files and for the compressed archive itself; record SHA-256 *outside* the archive as well. Use `shasum -a 256` on macOS or `sha256sum` on Linux. Avoid self-referential checksum bookkeeping mistakes. Archive metadata must say whether the manifest contains machine-specific absolute paths.

**Publication (D5, [approved](https://github.com/mlakolar/ProximalSolvers.jl/pull/212#issuecomment-6650942186)):** the durable home is a GitHub Release asset on this repository, under a tag that is not a package release, such as `bench-pre06-v1`. The maintainer uploads it. Post its browser URL, the archive SHA-256, the retention expectation and the retrieval commands on #110. The bundle stays out of normal git history, and an expiring Actions artifact does not meet the requirement. If the upload cannot be made, finish the checked archive and identify the blocker explicitly; **do not claim Stage 2A completed**.

**Git contents should remain small:** versioned campaign files, scripts only if essential, plan, and concise outcome report. No generated `benchmark/results`, Manifests full of machine paths, raw samples, profiles or gigabytes of data committed as ordinary source files.

### Required Stage 2A summary table (separate Julia versions)

| Field | Required |
|---|---|
| Case identifier and role | exact ID; primary or diagnostic; phase; case input type |
| Accuracy | independent measure, target, worst value, number of certified successes/failures |
| Performance | mean of the per-repetition medians (as `summarize.py`), each repetition's median, and observed spread |
| Memory/work | per-process Julia allocations, process RSS; iterations, passes and prox/gradient counts from the untimed receipt (§5), labelled exploratory |
| Provenance | both package identities, Julia/BLAS/CPU, Manifest SHA-256, harness hash, campaign freeze SHA |
| Evidence | raw file path inside archive, validation result, status and explicit limitations |

Report every primary case, then diagnostics, even if it failed or was extremely slow. Identify very fast cases as **accuracy-sensitive but timing-noise-limited** rather than assigning them a favorable/no-regression verdict. Every primary case is sub-millisecond, so none of their per-case ratios is a stand-alone verdict.

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
5. **Harness comparability risks.** The harness itself depends on ProximalBase behavior that 0.6 may change, and a case can then run a different workload under an unchanged data hash and certificate:
   - P14's untimed reset is `fill!(x, 0.0)` on a `SparseIterate` (`benchmark/cases.jl:171`). Under #424, `fill!` no longer removes coordinates, so the reset would keep the previous working set.
   - P04 and P05 reset an `AtomIterate` with `copyto!(x, start)` (`benchmark/cases.jl:128`), which also depends on the value-write semantics of #424.
   - P13 checks the ADMM cache through private ProximalBase API: `PB._svd_cache!` and the loss fields `V`, `s2` and `sUtY` (`benchmark/cases.jl:199-203`).
   - Any port of the harness changes `harness_hash`, which `compare.py` requires to match. A port is therefore a separate reviewed PR that changes only what 0.6 requires and lists every changed line; the maintainer signs off (D6) that each affected case still runs the same workload. A changed reset or check is a case remapping under item 3.

### 7.3 Measurement alignment and noise control

The Stage 2A historical run and a future 0.6 run occur at different times and may use different host conditions. **Do not call those two archives a paired statistical experiment.** For defensible performance decisions:

1. Prefer to run **both immutable A and B stacks again contemporaneously** on the same quiet/exclusive pinned hardware, with five fresh-process paired blocks as an initial pilot (or another prespecified budget supported by noise/cost).
2. Counterbalance the execution order across blocks (A/B, B/A) and preserve exact hardware, Julia, BLAS/thread counts, sampling limits, data hashes, harness and accuracy contract.
3. Distinguish a descriptive historical ratio from a fresh matched-block comparison; explicitly say when cross-stack strict equality checks are intentionally inapplicable.
4. The ordinary `compare.py` requires the `MATCH_SETTINGS` of `benchmark/validate.py:33` (`benchmark/validate.py:25-33`) to agree, including `suite`, `groups`, `julia_threads`, `blas_threads`, `seed_scheme`, `profile_seconds`, ProximalBase version and source fingerprint, harness hash, CPU model, BLAS configuration, sampling settings and case filter, and the catalog definitions and data hashes to agree (`benchmark/compare.py:62-75`). It does not read Manifests, so the Manifests are archived and compared by hand. Keep that behavior unchanged. Develop a **separately named migration-only reader/report** *only if needed*, with a narrowly declared allowlist of dependency differences, strict case/input/certificate validation, and a prominent attribution warning.
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
| Hidden ProximalBase 0.6 dependency in a “pre06” result | Registered 0.5.4 resolution, loaded source fingerprint, Manifest and ProximalBase `git-tree-sha1`; hard fail |
| A `0.5.4` version string on a development commit mistaken for the release | Compare the Manifest `git-tree-sha1` with the tree of tag `v0.5.4`; the version string alone is never accepted |
| Case cherry-picking after seeing results | Primary/diagnostic roles and settings frozen before formal campaign; every attempted series retained |
| Fresh-process compilation mistaken for steady solve | The validation call is excluded from sample medians; the formal records hold no first-call timing; take it per case from the pilot or from a labelled `local.jl` run, never from `elapsed_s` (a whole-process total) |
| Tiny cases yielding 2× variations, or a core-type mismatch on a hybrid CPU | Explicit noise limitations, longer diagnostic cases, independent repeated processes, pinning policy (§5); no statistical declaration |
| A failed certificate omitted from performance summary | Two independent gates: record integrity **and** numerical acceptance; always list failures |
| Path-dependent environment not reproducible | Archive source SHAs, Manifests, relocation instructions; verify in a second checkout |
| Mixing Julia versions or host types | Separate collections, reports, and comparison strata |
| Unexpectedly expensive cases | Readiness pilot and prespecified budget; any mid-course change creates a versioned amendment |
| Baseline results accidentally overwritten | Unique output roots, runner's refusal to overwrite prefixes, archive before cleanup |
| Publishing only expiring artifacts | Durable store, SHA-256 and URL on #110, retrieval smoke |
| 0.6 comparison falsely attributed to ProximalBase alone | Explicit two-stack manifest, solver migration diff, whole-stack interpretation |
| CI changes disrupt risk-tiered #121 checks | Defer `check_local.jl` smoke to its own issue/PR; do not modify CI in this campaign |
| Stage 2B harness port changes the workload silently | Reviewed port with a changed-line list, maintainer sign-off (D6), case remapping (§7.2) |
| Recipe runs the wrong case set or continues after a load failure | `set -euo pipefail`, sorted `PS_LIST` diff against `cases.txt`, continue only on exit 0 or 2, logged exit codes |

Maintain an audit log on #110 for F0/F1 review, the freeze commit, baseline run ID and machine conditions, validation status, archive URL/checksum, deviations from plan and Stage 2B transition. Do not edit prior historical evidence to remove a deviation; append a correction.

## 9. Work breakdown, PR boundaries, review points

**PR A — this design PR:** review and refine this plan plus `cases-proposed.txt`. No official measurements. The maintainer approved the case set, the pinned ProximalSolvers commit, the hardware policy, the five-repetition budget, the two Julia versions and the durable archive destination ([record](https://github.com/mlakolar/ProximalSolvers.jl/pull/212#issuecomment-6650942186)). Merging this PR is not F1.

**PR B — Stage 2A freeze and runner receipt (small, separate):** create approved `cases.txt` and `campaign.toml`, exact reproducibility instructions, and an optional minimal runner wrapper only where warranted. Confirm `PS_LIST` exactly matches. Commit the freeze, link on #110, and freeze before official timing.

**Execution outside the PR:** run the frozen campaign and integrity/numerical checks without altering source code or settings. Upload the raw evidence outside git.

**PR C — Stage 2A results receipt (docs only if useful):** concise per-case and per-Julia summary with archive/checksum and deviation log; independent review that archive revalidates. Check only the baseline-related Stage 2 checkbox on #110. Keep #110 open.

**Later PR D — Stage 2B migration comparison:** only after the 0.6 compatibility work provides an executable candidate. Its plan must explicitly declare any cross-stack comparator adaptation and independent accuracy matching.

**Separate CI follow-up:** `check_local.jl` smoke on benchmark source changes is valuable, but #121's CI redesign is closed. Track through a small new issue and a separate risk-tiered CI PR; this is not a prerequisite for Stage 2A.

### Acceptance checklist — this design PR

- [x] All exact IDs checked with `PS_LIST` (a checkout identical to `b0de3f7` except for the two documentation files) and their metadata inspected (§2.5).
- [ ] Coverage mapping to #527 reviewed; known unexercised breaking changes identified.
- [x] Primary/diagnostic roles and sample settings approved **before** F1 ([record](https://github.com/mlakolar/ProximalSolvers.jl/pull/212#issuecomment-6650942186)).
- [x] Registered ProximalBase 0.5.4 and ProximalSolvers pre-0.6 SHA approved ([record](https://github.com/mlakolar/ProximalSolvers.jl/pull/212#issuecomment-6650942186)).
- [x] Julia version and machine/noise policy approved; the concrete machine is chosen at F1 ([record](https://github.com/mlakolar/ProximalSolvers.jl/pull/212#issuecomment-6650942186)).
- [x] Durable archive owner/location and retrieval policy approved ([record](https://github.com/mlakolar/ProximalSolvers.jl/pull/212#issuecomment-6650942186)).
- [x] No solver, certificate, formal comparator, dependency compat, or CI changes in this PR (it changes only the two files under `benchmark/campaigns/pre06/`).
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

## 10. F0 decisions

Approved by the maintainer on the design PR ([record](https://github.com/mlakolar/ProximalSolvers.jl/pull/212#issuecomment-6650942186)). The decisions fix the content of the freeze (F1); they do not freeze anything themselves.

| | Decision | Outcome |
|---|---|---|
| D1 | **Reference.** | Registered ProximalBase `0.5.4` + ProximalSolvers `b0de3f7`. |
| D2 | **Case breadth.** | The 18 IDs of the original selection and their roles, plus one diagnostic: D05 `gradient/lasso-D/apg/tight/call`, the longest-running case of a primary family. 14 primary + 5 diagnostic = 19. No `slope` or nonconvex case (§2.3). |
| D3 | **Hardware.** | The policy of §5: on a hybrid CPU, one performance-core logical CPU per process, same CPU list for all repetitions and both stacks, affinity and load recorded; otherwise the archive is observational. The concrete machine is chosen at F1. |
| D4 | **Replications and versions.** | Five fresh-process repetitions per Julia version (1.10 and 1.13) after a noninferential pilot, at the extended sampling defaults (`PS_SAMPLES=100`, `PS_SECONDS=3`). |
| D5 | **Durable archive.** | A GitHub Release asset on this repository, under a non-package tag such as `bench-pre06-v1`, uploaded by the maintainer, with the SHA-256 and retrieval commands posted on #110. |
| D6 | **Stage 2B authority.** | The maintainer signs off the workload and accuracy mapping and the material-regression dispositions, recorded on #110 and on ProximalBase #527. |

**Outcome of this PR:** a careful, auditable execution contract for Stage 2. Approval of the design is not the freeze (F1), and it does not mean that any historical measurement or the future migration comparison has been completed.
