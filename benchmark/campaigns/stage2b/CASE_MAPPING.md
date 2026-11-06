# Stage 2B workload-compatibility mapping (#110)

Part of #110. Preparation only: no official measurement exists or is taken from this record.
The machine-readable form is [`case-mapping.toml`](case-mapping.toml); this file explains it. The
numbers and `file:line` citations are at ProximalSolvers `7b9b5295302bd177046284b017a8304cf5a99341`
(the Stage 2A campaign definition; `src/` is byte-identical to the measured source
`b0de3f7fc91767b97197ff4b458207e308998943`, version 0.3.2) and were read from the files, from `git grep`
over `src/` (there is no `ext/` directory at that commit), from the saved probe outputs in
[`probes/results/`](probes/results/) and from the ledger
[ProximalBase #527](https://github.com/mlakolar/ProximalBase.jl/issues/527) as read on 2026-11-06.
Anything not verified is marked `unverified`.

## What this record is for

Stage 2B compares two whole stacks on the 19 Stage 2A cases: Stack A (the historical measured
ProximalSolvers with ProximalBase 0.5.4) against Stack B (a migrated ProximalSolvers with a
ProximalBase 0.6 candidate). A timing comparison is meaningful only when both stacks run the same
workload. This record audits, case by case, whether the harness would run the same workload on a
0.6 candidate, and states the check that a pilot must pass before an official measurement. A
`data_hash` match is never accepted as evidence of identical semantics: it covers the generated
arrays and nothing about reset state, working sets, solver configuration or the timed operation
(`benchmark/problems.jl:41-48`).

## Classes (provisional until a candidate commit exists)

| Class | Meaning |
|:--|:--|
| A | Equivalent with the unchanged harness. A case stays A when the harness needs no edit even if the solver still needs migration; its `verification_needed` then says so. |
| B | Equivalent with a reviewed compatibility-only harness port. |
| C | Semantically changed; requires a separate mapping. |
| D | Not comparable or failed. |

No case is assigned C or D: there is no evidence for either. Class A is a statement about the
harness and about the evidence available today; it is not a statement that the case runs on the
candidate. Every class is revisited at the candidate commit.

## Matrix

| Label | ID | Role | Phase | Class | Reason |
|:--|:--|:--|:--|:--|:--|
| P01 | `cd/lasso-dense/cd/B/call` | primary | call | A | Plain-Vector reset; solver converts internally; no sensitive site found. |
| P02 | `cd/lasso-csc/cd/B/call` | primary | call | A | As P01 with a CSC matrix; fingerprint must cover the sparsity pattern. |
| P03 | `cd/lasso-dense/cd/B/workspace` | primary | workspace | A | Workspace reset on a Vector; the solver already clears its internal iterate with dropzeros!(fill!). |
| P04 | `cd/group-lasso/cd/tight/call` | primary | call | A | AtomIterate reset equivalent (probe); solver reads x.groups: migration #165 and pilot. |
| P05 | `sgl/sparse-group/cd/tight/call` | primary | call | A | AtomIterate reset equivalent (probe); solver writes x.storage and calls prox_coordinate!: #163, #165 and pilot. |
| P06 | `cd/weighted-lasso/cd/tight/workspace` | primary | workspace | A | Workspace on a Vector; weighted L1 on a scaled loss: counters to compare (#213). |
| P07 | `gradient/lasso/apg/tight/call` | primary | call | A | Plain-Vector gradient solver; no iterate type involved. |
| P08 | `gradient/lasso/apg/tight/workspace` | primary | workspace | A | Plain-Vector gradient workspace; no iterate type involved. |
| P09 | `newton/logistic-weighted-offset/prox-newton/tight/call` | primary | call | A | Plain-Vector start; GLM Newton path; open numerical-contract issue #211 to check at the candidate. |
| P10 | `newton/glasso/quic/tight/call` | primary | call | A | Dense start, symmetric S and Lambda; QUIC uses the symmetric owner internally: #162, #165, #391 and the minimizer type are open. |
| P11 | `admm/lasso/admm/B/call` | primary | call | A | Plain-Vector ADMM; only exposure is inside ProximalBase's least-squares prox. |
| P12 | `admm/lasso/admm/B/workspace` | primary | workspace | A | Plain-Vector ADMM workspace; fill! acts on plain arrays only. |
| P13 | `admm/lasso/admm/construction/setup` | primary | setup | A | No solver; depends on private ProximalBase names (_svd_cache!, V, s2, sUtY): re-verify at the candidate. |
| P14 | `paths/lasso/cd/grid8/call` | primary | call | B | Historical fill!(x, 0.0) keeps active coordinates on master; reviewed port dropzeros!(fill!(x, 0.0)) is identical on 0.5.4. |
| D01 | `gradient/lasso/active/B/call` | diagnostic | call | A | Plain-Vector active-set solver; copyto!(x, xs) out of the sparse iterate to verify. |
| D02 | `newton/glasso-larger/quic/tight/call` | diagnostic | call | A | As P10 on n = 400, p = 40. |
| D03 | `cd/lasso-D/cd/tight/call` | diagnostic | call | A | As P01 on a wide design (p = 600). |
| D04 | `primal_dual/generalized-lasso/condat-vu/tight/call` | diagnostic | call | A | Plain vectors; the harness certificate runs inside the timed solve (gap callback). |
| D05 | `gradient/lasso-D/apg/tight/call` | diagnostic | call | A | As P07 on a wide design (p = 600). |

Counts: 14 primary and 5 diagnostic cases; class A: 18, class B: 1 (P14). The five fixed-input cases
of the primary set are P01, P02, P03, P11, P12 and the diagnostic D01 is fixed as well
(`inputs = "fixed"` in `benchmark/campaigns/pre06/campaign.toml`); the other 13 draw their inputs
from the repetition ID (`benchmark/problems.jl:3-9`).

## Findings that apply to several cases

1. **The solver already clears its own iterates; the harness does not.** `src/cd/path.jl:18`
   defines `_clear_start!` as `dropzeros!(fill!(x, 0))` for `SparseIterate` and `AtomIterate`, with a
   source comment (`path.jl:12-15`) that states the ProximalBase 0.6 semantics. The ledger row for
   ProximalBase #424 records that ProximalSolvers was migrated for these two iterate types in
   ProximalSolvers #164 (released in v0.3.2). The CD workspace (`src/workspaces.jl:239`) and
   `solve!(...; continuation)` (`path.jl:270`) call it. `solve_path` does not (`path.jl:448-486`: `x`
   "is the starting point", `path.jl:403-405`), so the clear of the P14 start is the harness reset
   `fill!(x, 0.0)` (`benchmark/cases.jl:171`), which was not part of that migration. That is the one
   harness edit found.
2. **Julia 1.10 and 1.13 produce different input hashes for every case.** In
   `historical-reference.tsv` the first-repetition `data_hash` of all 19 cases differs between the
   two Julia versions, including the six fixed-input cases (the fixed problems are drawn from
   `Xoshiro(90210)`, `benchmark/problems.jl:66`). The two Julia versions are separate strata and are
   never pooled or paired.
3. **Counters can differ between Julia versions on the same case**, because the draw cases receive
   different inputs: for example P07 `iterations=30` on 1.10.13 and `iterations=20` on 1.13.3 in the
   exploratory counters of the Stage 2A archive (`case-mapping.toml`, `work_counters`).
4. **D04 runs the harness certificate inside the timed region.** The solver's stopping rule is the
   harness callback `gap(x, y) = certify(a, (; x, y)).value` (`benchmark/cases.jl:186`), called from
   `src/solvers/primal_dual.jl:301` and `:323`. `benchmark/certificates.jl` must therefore be
   byte-identical in both stacks for D04 to be like for like.
5. **The solver options the 19 cases use never reach the momentum and Anderson code.** Every CD solver
   in the 19 is cyclic with `anderson = 0` (`benchmark/cases.jl:69-70`, `:77`); `_usemomentum` is false
   for them (`src/cd/solver.jl:412-414`) and the Anderson branch is skipped (`:345`). The direct reads
   of `x.nzval`, `x.active`, `x.nactive` and `x.storage` in that code (`solver.jl:540-602`) are not
   exercised by any benchmark case.
6. **The certificate is independent of the solver and of ProximalBase iterates**
   (`benchmark/certificates.jl` reads plain arrays; `benchmark/cases.jl:132` converts the minimizer
   with `Array(...)`). What the certificate sees is the minimizer's converted array: for P10 and D02
   the minimizer type under 0.6 (a dense matrix, or a symmetric owner) is **an open item** until a
   migrated solver exists. At `7b9b5295` it is the caller's dense `Matrix` (`src/cd/quic.jl:231-235`).

## P14 reset: the one harness edit

Historical line, verbatim (`benchmark/cases.jl:171` at `7b9b5295` and `b0de3f7`):

```julia
reset!() = (fill!(x, 0.0); reset_solver_rng!(method); nothing)
```

Proposed compatibility-only port, verbatim (its own narrow PR; the maintainer approves it before any
use):

```julia
reset!() = (dropzeros!(fill!(x, 0.0)); reset_solver_rng!(method); nothing)
```

Evidence (probe `probes/reset_semantics.jl`, outputs in `probes/results/`, Julia 1.10.12 and 1.13.3
give the same result; `pb054.sha` is the v0.5.4 tag commit `9c5a43bf0b7e3f51f0a401b785c332200ffa5d7e`,
`pbmaster.sha` is ProximalBase master `233c11cc284284fbd29df487308b4ee962f875a1`, a probe-only commit
and not a candidate): after a used `SparseIterate` with four active coordinates,

| Reset | ProximalBase 0.5.4 | ProximalBase master (0.6.0-DEV) |
|:--|:--|:--|
| `fill!(x, 0.0)` | all values zero, 0 active | all values zero, **4 active (3, 17, 42, 150)** |
| `dropzeros!(fill!(x, 0.0))` | 0 active, values zero | 0 active, values zero |

The port is therefore the identical operation on 0.5.4 and restores the cold start on master. The
formal `harness_hash` (SHA-1 over `problems.jl`, `certificates.jl`, `cases.jl` and `run.jl`,
`benchmark/run.jl:112-115`) changes with the port. Stack A keeps its true historical hash
`b7bf3d953ec6e9f9720e74d7895b5cf95a629fd4`; Stack B records its own true hash; the two are never
forced equal. The difference is declared in the comparison's approved-differences file, together
with this mapping record (`MIGRATION_COMPARE_SPEC.md`).

## Cases singled out

### P04 (`cd/group-lasso/cd/tight/call`) and P05 (`sgl/sparse-group/cd/tight/call`)

* Start: `ProximalBase.AtomIterate(32, groups)` with eight groups of four (`benchmark/cases.jl:103-104`,
  `problems.jl:163`); reset `copyto!(x, start)` (`cases.jl:128`).
* Probe evidence (`atom.*` keys, `probes/results/`): `copyto!(x, start)` restores the values and the
  active-group layout from a cold start (start: 0 active; used: groups 2, 5, 9), from a warm start
  (start: groups 3, 7; used: 3, 7, 2, 5, 9) and from an overlapping warm start (used: 3, 7, 11), and a
  second reset in a row leaves the same state, on 0.5.4 and on master. The reset operation is
  therefore equivalent. The `values_hash` entries differ between Julia 1.10.12 and 1.13.3 because the
  probe records Julia's `hash` of the (deterministic) value array and `hash` is not stable across Julia
  versions; within each version `start` and `after` agree, which is what the checker tests.
* Solver path (not equivalent until migrated): P04 reads `x.groups[k]`
  (`src/cd/leastsquares.jl:192`, `:558`, `:598`; `src/cd/models.jl:691-692`; `src/cd/gap.jl:200`). P05 has
  no specialized group step: it uses the generic `_groupstep!` (`src/cd/groups.jl:19-48`), which writes
  `x.storage` directly (`:32-42`) and calls `prox_coordinate!(x, g, k, step)` (`:38`), the sites of
  ProximalSolvers #163 and #165. P05 is the one case of the 19 that writes `x.storage`.
* Class A (harness unchanged); `verification_needed` names the solver migration (#165; and #163 for
  P05) and the pilot. The pilot also checks the active-group list after `reset!()` on both stacks.

### P10 (`newton/glasso/quic/tight/call`) and D02 (`newton/glasso-larger/quic/tight/call`)

* Inputs: `S = Matrix(Symmetric(X'X/n + 0.2I))` (`benchmark/problems.jl:183`), exactly symmetric by
  construction, and `Λ = fill(0.08, p, p)` with a zero diagonal (`problems.jl:184-187`), exactly
  symmetric. Objective `LogDetLoss(S)` unscaled, penalty `NormL1(1.0, Λ)` (`benchmark/cases.jl:40`).
* Probe evidence (`quic.*`): `LogDetLoss` of an asymmetric matrix throws `ArgumentError` on master and
  was accepted on 0.5.4; the exactly symmetric harness matrix is accepted on both. The harness is
  therefore not affected by the new validation.
* Solver path: the dense start is wrapped in a `SymmetricSparseIterate` inside the timed call
  (`src/cd/quic.jl:232`). The path reads `x.p` at five sites in `quic.jl` and six in `kronu.jl`,
  calls `_symmetric_penalty` once for real (`quic.jl:159`, the `NormL1` method at `models.jl:592-597`,
  which today averages asymmetric weights; ProximalSolvers #162 changes it to a throw), uses
  `fill!` as a clear on owners (`quic.jl:91`, `:138`, `:203`, `:214`), reads `X[i, j]` of the owner
  (`quic.jl:198`) and `Matrix(...)` conversions (`quic.jl:201`, `:234`). The owner is still an
  `AbstractMatrix` with the field `p` on master (probe `owner.supertype`, `owner.has_p_field`): the
  redesign (ProximalBase #391 Phase 1) is not merged, so none of this can be verified at a candidate
  yet.
* Open item: the minimizer type under 0.6 (dense matrix or symmetric owner) and whether
  `Array(output.minimizer)` is an exactly symmetric dense matrix, which `glasso_certificate` requires
  (`benchmark/certificates.jl:247`). Recorded as open, not as a finding.
* Class A; `verification_needed`: solver migration (#162, #165, the owner redesign, clear semantics)
  and the pilot.

### P13 (`admm/lasso/admm/construction/setup`)

* The timed operation is `PB._svd_cache!(loss)` after constructing the loss (`benchmark/cases.jl:196-200`);
  the certificate reads `loss.V`, `loss.s2`, `loss.sUtY` (`:201-207`), all private to ProximalBase.
* Probe evidence (`setup.*`, master `233c11cc`): `_svd_cache!` exists, the call succeeds, the three
  fields exist, the self-consistency value is 8.69e-16 against the target 1e-12. ProximalSolvers
  never names the cache (`git grep _svd_cache -- src`: 0 sites).
* Class A on the probed master; to be re-verified at the candidate: a rename of any of the four
  names turns the case into class B or D.

### P14 (`paths/lasso/cd/grid8/call`)

See "P14 reset: the one harness edit" above. Further: the case's certificate is the worst level of
eight (`benchmark/cases.jl:143-154`, `certificates.jl:350-356`) and an incomplete grid is an
`IncompletePath` error, not a slow result (`cases.jl:151-152`). The pilot checks `nactive(x) == 0` and
zero values after `reset!()` on both stacks, after a used solve.

### D02

As P10 on the larger problem (`n = 400`, `p = 40`, `benchmark/cases.jl:330-331`).

## Migration paths the 19 cases do not exercise

The benchmark is not the gate for the following. The package correctness suite, the integration
tests T07 and FT25-FT28 of the ledger, and invalid-input tests that do not use the benchmark inputs
are. Counts are from `git grep -n` over `src/` at `7b9b5295`, comment lines excluded where stated.

| 0.6 change (ledger row or issue) | Sites in `src/` | What the 19 cases reach |
|:--|:--|:--|
| `_symmetric_penalty` validation instead of averaging (ProximalSolvers #162; ledger "SymmetricSparseIterate accepts only symmetric values") | 44 lines: 30 in `src/cd/models.jl` (the identity at `:539-541`, the per-penalty methods `:592-674`, the recursion through wrappers) and 14 call sites in 8 other files | Real evaluation only at `src/cd/quic.jl:159` (P10, D02, the `NormL1` method, symmetric weights). The other call sites on case paths receive a non-symmetric iterate and return `g` (`models.jl:539`). Not reached: `gap.jl:1006`, `generic_newton.jl:17`, `lla.jl:133,184`, `path.jl:66,264`, and every penalty method other than `NormL1` (hinge, box, pattern, `SqrNormL2`, KL, `Scaled`, `Tilt`, `Translate`, `Regularize`, `MoreauEnvelope`, `Conjugate`, linear constraints, `SeparableSum` over tuples). |
| Owner clear: `_clear_start!` of `SymmetricSparseIterate` (ledger "#391 Phase 1") | `src/cd/path.jl:19` (called at `path.jl:270` and `workspaces.jl:239`) | Not reached by any case. The owner clears in `src/cd/quic.jl:47,91,138,203,214` are reached by P10 and D02. |
| `MoreauEnvelope` and `Conjugate` `restrict`, `prox_entry`, `kkt_violation` (ledger #271) | 8 mentions of `MoreauEnvelope`, `Conjugate` or `LinearConstrained`; `kkt_violation` at `src/solvers/active_accelerated_proximal_gradient_descent.jl:296`; `prox_entry` at `leastsquares.jl:462`, `models.jl:157`, `glm.jl:644,679` | D01 calls `kkt_violation` with `NormL1` (separable, not affected). No case uses a `MoreauEnvelope`. |
| `x.groups` of `AtomIterate` (ProximalSolvers #165) | 58 non-comment `.groups` sites (iterate and penalty fields together) in 15 files | P04 and P05 only, and only the sites listed in their `sensitive_paths_06`. Not reached: group paths and screening (`path.jl`, `sparsegroup.jl:108,118,125,181`), gap-safe screening (`gap.jl:719`), `lla.jl`, `multiresponse.jl`, `quadratic.jl`, `diagonal_metric.jl`, the active-set group variant, `workspaces.jl:153` partition check (reinit! of an `AtomIterate` workspace). |
| `x.storage`, `x.nzval`, `x.nactive`, `x.active` (ProximalSolvers #163, #165) | `x.storage`: 5 sites (`groups.jl:32,64`, `solver.jl:568,580,599`); `x.nzval`: 3 (`solver.jl:562,574,590`); `x.nactive`: 4 and `x.active`: 4 (`solver.jl:555-556,566,578,597`) | `groups.jl:32,34,36,42` (P05) only. The other `x.storage` site (`groups.jl:64`, the quadratic model), and all of the momentum and Anderson history code, are not reached. |
| `x.p` of the symmetric owner (ledger "#391 Phase 1") | 33 non-comment lines (the ledger counts 36 `x.p` sites including one test file): `drivers.jl` 1, `gap.jl` 2, `generic_newton.jl` 2, `kron.jl` 6, `kronu.jl` 6, `models.jl` 8, `path.jl` 2, `quic.jl` 5, `solver.jl` 1 | `quic.jl` (5) and `kronu.jl` (6) by P10 and D02. Not reached: `kron.jl` (`KronQuadratic`), `generic_newton.jl`, `drivers.jl` (`refit!`, Hessians), `gap.jl:1031,1033`, `models.jl` symmetric screening and weights (`:384-387`, `:426-434`, `:577-578`), `path.jl:9,114`, `solver.jl:754` (symmetric `_copy_dense!`). |
| `coordinates(x)` is a view, `coordinates(x) === x` no longer holds (ledger "#425") | 19 non-comment uses of `coordinates(` (plus 29 of `activecoordinates(`, 17 of `ncoordinates(`) | The uses are on the symmetric owner or in the Anderson history; those on case paths are `quic.jl:48,103,220` and `kronu.jl:47,74,118`. Every use indexes by ID (`cx[k]`); none tests identity. `activecoordinates(x)` is used by all sparse-iterate cases (`leastsquares.jl:191`, `glm.jl:98`, `active_accelerated...:277`). |
| `LogDetLoss(S)` exact symmetry (ledger "#269") | 20 mentions of `LogDetLoss`; the rebuilds at `quic.jl:239,241` (`Scaled` method) and `precompile.jl:56` | P10 and D02 construct `LogDetLoss(S)` of an exactly symmetric `S`. The `Scaled` methods are not reached. |
| Working-set rule for writes (ledger "#424") and coordinates view (#425), strong zeros (#428) | `dropzeros!`: 16 lines in 9 files (including the import and one comment); `fill!`: 37 lines, of which 6 act on iterates (`path.jl:18-19`, `quic.jl:91,138,203,214`) and the rest on plain arrays and model caches | `solver.jl:276` (all CD cases), `gap.jl:685`, `glm.jl:582`, `active_accelerated...:150`. The owner `fill!` sites are `quic.jl` (P10, D02). |
| Block-history momentum, Anderson | 59 lines mentioning `momentum` or `_Momentum` in `src/cd/` | Not reached (cyclic, `anderson = 0`). |
| `refit!`, `lambda_max`, `solve_path` on symmetric or group iterates | `refit` 18 lines, `lambda_max` or `solve_path` 46 lines | Only the `SparseIterate` path P14. |
| `_same_support` on state vectors (ledger row #391 Phase 1, review) | `src/solvers/proximal_gradient_descent.jl:200,209` | Not reached: no case uses `ProximalGradientDescent` (the cases use `AccProxGradDescent`, `ActiveAccProxGradDescent`, ADMM, CD, `ProxNewton`, `CondatVu`). |
| The numerical contract (ledger "#385", tracker #366) and strong zeros (#428) | all of `src/` | Reached implicitly by every case through ProximalBase evaluations; not assessed site by site (the ledger does not either). The certificate and the counters are the pilot's evidence. |

## Unverified claims in this record

The list is repeated in the hand-back of the preparation work and in the readiness record.

1. Whether `src/cd/gap.jl:719` and `src/cd/sparsegroup.jl:150-160` are reached by P04 and P05 (the
   duality-gap path is enabled by `gaptol = 1e-10`; the line-level reach was not traced).
2. Which lines of `src/cd/models.jl` and `src/cd/gap.jl` the QUIC inner coordinate descent reaches
   beyond those named; the `KronUModel` lines `kronu.jl:86,91,100,120` are named from the model's
   methods and not traced.
3. The behaviour of the SparseIterate working-set rules (#424, #425) on the solver's own writes
   `x[k] = v` and `dropzeros!(x)` after every pass, at a candidate: only the reset operations were
   probed, not the solves.
4. Whether ProximalBase #608 (scaled weighted exact-zero recovery, measured by ProximalSolvers #213)
   changes the P06 solve.
5. Whether ProximalSolvers #211 (specialized GLM IRLS alignment with the numerical contract) lands
   before the migration; if it does, P09 changes numerically and needs its own mapping.
6. The behaviour of `copyto!(x, xs)` (generic copy out of a `SparseIterate` into a `Vector`,
   `active_accelerated...:250`, D01) under the 0.6 iterate design.
7. The behaviour of ProximalBase's `LeastSquaresLoss` prox (the SVD cache) for the ADMM cases P11 and
   P12 at the candidate (P13 tests the cache in isolation; the ADMM solve is not probed).
8. The minimizer type of the migrated QUIC path (open item, P10 and D02).
9. Julia 1.10 and 1.13 behaviour of the reset operations is probed on 1.10.12 and 1.13.3, not on the
   measured builds 1.10.13 and 1.13.3; the probe runs identically on both, but the pilot must repeat
   it on the exact builds.
