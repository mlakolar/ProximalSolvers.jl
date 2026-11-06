# Stage 2B readiness record

Part of #110. Related: mlakolar/ProximalBase.jl#527.

This record states what stands between the current state and a valid Stage 2B comparison. It is an audit and a
readiness probe, not a candidate evaluation: no ProximalBase 0.6 candidate and no migrated ProximalSolvers commit
exist yet (Phase 0 table). The probe results are exploratory and are never measurements.

## Phase 0 state

Re-read from GitHub on 2026-11-06 (not copied from the ledger).

| Gate | Finding | Verdict |
|:--|:--|:--|
| ProximalBase 0.6 candidate | `master` is `0.6.0-DEV` at `233c11cc284284fbd29df487308b4ee962f875a1`; the last tag is `v0.5.4`; no 0.6 candidate commit or tag exists; `master` moves. This commit is a probe-only commit, not a candidate; no moving branch is used as an identity. | **Not available** |
| `SymmetricSparseIterate` redesign (#391 Phase 1a-1d) | Not merged: on that commit it is still `<: AbstractMatrix` and has the field `p`. Merged: Phase 0 (`matrixview`, `activevalues`), #424 working-set rule for writes (PR #633), #425 coordinates view (#672), #428 strong zeros (#676), #364 real-only checks (#626), and many numerical-contract PRs. | **Blocking** |
| ProximalSolvers migration | No open or merged 0.6 migration PR. `Project.toml` compat is `ProximalBase = "0.5.3"`. Open: #162 (symmetric penalty validation), #163 (block step `prox_coordinate!`), #165 (private iterate fields), #211, #213. | **Blocking** |
| Ledger mlakolar/ProximalBase.jl#527 | Every row is unchecked. | **Blocking** |

The stop rule applies (`STAGE2B_PLAN.md` section 6): no official measurement; the unmet dependency gates
are listed here and on #110.

## Audit of ProximalSolvers against #527 rows

File and line counts are from `git grep -nP` over `src/` and `ext/` at `7b9b5295302bd177046284b017a8304cf5a99341` (its
`src/` equals the measured `b0de3f7`), comment lines excluded. A count is a pointer for the migration PRs, not a
proof that a site is affected: a name such as `.groups` is also a penalty field, which the contract leaves alone.
The ledger counts 36 `x.p` sites because it includes a test file.

| #527 row | ProximalSolvers sites (audited commit) | Status |
|:--|:--|:--|
| Exact symmetry of `LogDetLoss` and `KronQuadratic` (#269) | `LogDetLoss(` constructed in `cd/quic.jl`, `cd/glm.jl`, `precompile.jl`; `KronQuadratic(` in `precompile.jl`; tests in several files. Probe: master throws `ArgumentError` for an asymmetric matrix. The suite run below fails `test/coordinate_descent.jl:53` (KronQuadratic with a nonsymmetric `C`). | Open (review `quic.jl` rebuild; test fix) |
| `SymmetricSparseIterate` owner redesign, no `AbstractMatrix`, no `x.p` (#391 Phase 1) | `.p`: 33 sites in `cd/drivers.jl`, `gap.jl`, `generic_newton.jl`, `kron.jl`, `kronu.jl`, `models.jl`, `path.jl`, `quic.jl`, `solver.jl` (28 with receiver `x`); `SymmetricSparseIterate`: 105 lines in 17 files. The redesign is not merged, so none of this breaks yet. | Open, blocked on ProximalBase |
| Symmetric penalty parameter validation (#162, ProximalBase #142, T17) | `_symmetric_penalty`: 44 lines in `cd/gap.jl`, `generic_newton.jl`, `lla.jl`, `models.jl`, `path.jl`, `quic.jl`, `solver.jl`, `solve.jl`, `workspaces.jl`; it averages asymmetric weights today. All 109 suite errors below are this exact-symmetry rule meeting a test that passes an asymmetric array (`symmetric_penalty_combinations`, `symmetric_penalties`, `symmetric_penalties_basics`, `flat_coordinates`, `audit_regressions`, and the KronQuadratic `C` of `coordinate_descent`). | Open (#162) |
| Owner clearing and `fill!` semantics (#424) | `fill!(` 36 lines in 17 files. `_clear_start!` (`cd/path.jl:18-19`) already uses `dropzeros!(fill!(x, 0))` for `SparseIterate` and `AtomIterate` (ProximalSolvers #164, v0.3.2); the owner's clear (`path.jl:19`) and the QUIC clears wait for the owner redesign. The harness's own P14 reset is a separate site (class B). | Partly done; owner open |
| `SparseIterate` and `AtomIterate` value-write semantics (#424, #364) | Probe: harness resets behave as stated in `CASE_MAPPING.md` (P14 differs, P04/P05 equal). Solver writes `x[k] = v` and `dropzeros!(x)` after each pass were not probed. | Partly verified |
| Coordinate views and active-set identity (#425) | `coordinates(` 64 lines in 17 files; the ledger says about 20 index by ID (fine); identity or shape use was not checked site by site. The suite passes against master for these files. | Unverified by site; suite green |
| `rmul!`, `lmul!`, `rdiv!`, `ldiv!` of a `SparseIterate` by a non-finite scalar or a zero divisor write every entry (#427, FN-9, PR #526) | The ledger finds no affected site. Independently checked here: `git grep -P` for the four calls over `src/` and `ext/` at the audited commit returns 0 lines (broadcast scaling forms were not searched). | No site found; verified for the four named calls |
| Strong zeros in products (#428) | Not searched in depth (ledger: no sites found). The suite passes against master. | Unverified by site; suite green |
| Private iterate fields to accessors (#163, #165, FT25-FT28) | `.groups` 70 lines in 16 files (includes penalty fields), `.storage` 5, `.nzval` 3, `.nactive` 4, `.active` 4, `.group_of` 4, in `cd/solver.jl`, `cd/groups.jl`, `cd/gap.jl`, `cd/sparsegroup.jl`, `solvers/diagonal_metric.jl` and others; the `atomindices` and `samegroups` replacements exist on master but ProximalSolvers #165 is not implemented. | Open (#165, #163) |
| Nonseparable `MoreauEnvelope` throws in `restrict`, `prox_entry`, `kkt_violation` (#271) | `MoreauEnvelope`: 2 lines (`cd/models.jl`, `cd/solver.jl`). No benchmark case reaches it. | Open, covered by the suite only |
| Numerical contract (#385, #366): NaN, infinite levels, invalid steps, Float16 | Not searched site by site. The suite passes against master except for the symmetry errors. | Suite green apart from symmetry |
| Deprecated 0.4 names; solver-specific dispatch | No use found by the ledger. | Not applicable |
| ADMM setup and private loss/cache interface | The benchmark's P13 setup certificate reads `_svd_cache!`, `V`, `s2`, `sUtY` of `LeastSquaresLoss` (`benchmark/cases.jl:196-206`); the package source has no `_svd_cache` use. The names exist on master. | Re-verify at the candidate |

The cases of the benchmark touch only some of these paths (`CASE_MAPPING.md`, last section); the correctness suite
and the integration tests T07 and FT25-FT28, not the benchmark, are the gate for the rest.

## Readiness probe results

Both probes are exploratory, ran on a cluster, and are not measurements.

**Reset probe** (`probes/reset_semantics.jl`, outputs in `probes/results/`, verdict by
`probes/check_reset_probes.py`): ProximalBase v0.5.4 (`9c5a43bf0b7e3f51f0a401b785c332200ffa5d7e`) against master
`233c11cc284284fbd29df487308b4ee962f875a1`, Julia 1.10.12 and 1.13.3, with the same conclusions on both (the array value hashes are specific to a Julia version, so the checker compares probes of one Julia version only). The probe uses the harness's problem size, `p = 32` (8 groups of 4); its used working sets are synthetic, set by writes and not by a solver call.
The checker prints `RESET PROBE: PASS` on the pair for each version.

* P14: `fill!(x, 0.0)` keeps 4 active coordinates on master (0 on 0.5.4); `dropzeros!(fill!(x, 0.0))` gives the
  empty working set and zero values on both.
* P04, P05: `copyto!(x, start)` of an `AtomIterate` restores values and the active-group layout on both, from a
  cold start and from two warm starts, and a second reset is idempotent.
* P13: `_svd_cache!`, `V`, `s2`, `sUtY` exist on master; self-consistency about 8.7e-16.
* QUIC: `LogDetLoss` of an asymmetric matrix throws `ArgumentError` on master; the harness's matrix is exactly
  symmetric.
* Owner: still an `AbstractMatrix` with the field `p` on master.

**Package-suite probe.** ProximalSolvers at `7b9b5295` (`src/` equal to `b0de3f7`), scratch copy whose compat
was widened to `ProximalBase = "0.5.3, 0.6"` (the repository is untouched), ProximalBase developed from a
detached checkout of master `233c11cc`, `Pkg.test` full tier, 8 workers.

| Julia | Pass | Error | Total | Wall time |
|:--|--:|--:|--:|--:|
| 1.10.12 | 114108 | 109 | 114217 | 5 min 00 s |
| 1.13.3 | 114119 | 109 | 114228 | 5 min 13 s |

The summary of the two runs is kept in `probes/results/suite-probe-summary.md`; the raw logs stay in the run record and are not committed.

Both runs exit with status 1. The 109 errors are identical in count and location on the two versions, in 6 of
55 test files: `symmetric_penalty_combinations` 79, `symmetric_penalties` 20, `symmetric_penalties_basics` 4,
`flat_coordinates` 3, `audit_regressions` 2, `coordinate_descent` 1. Every one is an `ArgumentError` of the form
"the array w (or c, C) of <penalty or loss> must be symmetric on a `SymmetricSparseIterate`", that is the
exact-symmetry rule meeting a test that builds a nonsymmetric parameter, as the ledger anticipated. The other 49
files pass. The probe cannot show the breakage of the owner redesign, which is not on master yet.

Not run: the integration tests T07 and FT25-FT28 (they need the migration), the candidate's own suite, and any
benchmark.

## Gates

| Gate | Requirement | Status |
|:--|:--|:--|
| G1 | A ProximalBase 0.6 candidate commit exists and is not a moving branch. | **Unmet** |
| G2 | ProximalSolvers migration PRs merged with their own tests (#162, #163, #165, owner migration). | **Unmet** |
| G3 | ProximalSolvers compat admits 0.6 explicitly. | **Unmet** (`0.5.3`) |
| G4 | Full package suite green on Julia 1.10 and 1.13 against the candidate. | **Unmet** (109 errors against master, exploratory) |
| G5 | T07 and FT25-FT28 integration tests green. | **Unmet** (cannot run before the migration) |
| G6 | Invalid-input and contract-failure tests independent of the benchmark inputs. | **Unmet** |
| G7 | #527 and #391 rows ticked or dispositioned. | **Unmet** (every row open) |
| G8 | Maintainer approval of the case mapping and the P14 port. | **Pending** (to be requested on #110 after PR A merges, with the PR B proposal; not yet requested) |

No official measurement may start until G1-G8 all hold. Pilots may be prepared earlier only as non-official work (`STAGE2B_PLAN.md` sections 6 and 8), and the pilots that need a migrated Stack B cannot start before G1-G3.
