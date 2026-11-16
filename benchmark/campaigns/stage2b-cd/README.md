# Stage 2B successor: the CD-only campaign (#333)

This directory defines the **CD-only successor** of Stage 2B. It is **not the original Stage 2B campaign**
`pb06-migration-stage2b-v1`. That campaign (19 cases, freeze inputs at `412063d8`, schedule `stage2b-8block-v1`) is not
executable on the minimal core, and its frozen files in `../stage2b/` are unchanged. Nothing here completes it, and none of its
case IDs are reused.

Records: [#330](https://github.com/mlakolar/ProximalSolvers.jl/issues/330) (the Gate 0 audit and the maintainer's
[ruling](https://github.com/mlakolar/ProximalSolvers.jl/issues/330#issuecomment-6910364487)), [#333](https://github.com/mlakolar/ProximalSolvers.jl/issues/333)
(the successor and its gates), [#110](https://github.com/mlakolar/ProximalSolvers.jl/issues/110) (the parent).

## What is compared

| | Stack A | Stack B |
|---|---|---|
| ProximalSolvers | the harness-only port of #333: parent `b0de3f7fc91767b97197ff4b458207e308998943`, only `benchmark/{problems,certificates,cases,run}.jl` replaced by their bytes at `9f86a808`; branch `archive/stage2b-cd-stack-a-port` | `9f86a808bfac968f5421b9efeb6d0aecd7c1c775` (master after #307), minimal core |
| ProximalBase | registered 0.5.4 (`9c5a43bf`) | `50db4b1ef376cbe01831c3dd019b6be0027db0b6`, `0.6.0-DEV`, tree `4556e470` |
| package hash of ProximalSolvers | `f37fc61f300ad597a33c7ab5f448d38c865db854` (Stage 2A's) | `dc9cb31ffa76847c45f185a47370dfe34832ee47` |
| harness hash | `164fab53cac906e52e5a75e8b93658c1d174c14e` | the same |

Stack B is labelled *minimal-core, post-#307*. It is not a ProximalBase 0.6 release. The solver implementation of Stack A is
that of Stage 2A; only the harness is current, so both stacks run the same benchmark code on the same inputs. The stopping
behaviour of the solvers differs (#293, #294, #295, #311): the primary quantity is the accuracy-qualified end-to-end `solve!`
time, and no result is read automatically as a ProximalBase kernel-efficiency change.

Cases: the 21 current cases of the `cd` group of the extended suite (`PS_LIST=true PS_SUITE=extended PS_GROUPS=cd` on `9f86a808`),
frozen in `schedule.toml`. Protocol: the Stage 2B one (8 A/A + 8 A/B paired fresh-process blocks per Julia stratum,
orders AB BA BA AB BA AB AB BA, 1 Julia thread, 1 BLAS thread, a pinned CPU), strata Julia 1.10.13 and 1.13.3 kept separate,
Discovery EPYC 7513 on an exclusive node, the Stage 2A sampling settings.

## Files

| file | content |
|---|---|
| `schedule.toml` | the schedule, settings, machine, Julia builds and `[stack_a]` (read by `migration_compare.py` and the driver) |
| `case-mapping.toml` | the 21 class A rows, approved by the ruling |
| `lock.toml` | the Stack B candidate: commits, trees, package hashes, the per-stratum environment files and their SHA-256, the declared differences, the approvals |
| `freeze/stack-{a,b}/julia-{1.10,1.13}/` | the environment files (`Project.toml`, `Manifest.toml`) of both stacks, with the ProximalSolvers path relative to the base layout; `SHA256SUMS` lists them. The driver uses the Stack B files through the lock; the Stack A files are what the driver derives from the Stage 2A archive, recorded here for provenance |
| `test_stage2b_cd_files.py` | consistency, identity and unchanged-file tests |

Use it with the existing driver:

    python3 -B benchmark/campaigns/stage2b/stage2b_campaign.py prepare --campaign-dir benchmark/campaigns/stage2b-cd \
        --config benchmark/campaigns/stage2b-cd/lock.toml --base BASE --step fetch --archive STAGE2A_ARCHIVE --julia 1.10=... --julia 1.13=...

`--campaign-dir` defaults to `benchmark/campaigns/stage2b`, the original campaign; every read of `schedule.toml` and
`case-mapping.toml` goes through it.

## Notes for readers

- **Gates.** G1-G7 of the original campaign are replaced for this campaign by the minimal-core correctness and provenance
  gates of #333. The driver's official gate still requires an `[approvals]` table with a maintainer comment URL for each of
  `G1`-`G8`; all of them name the ruling, which is the approval of the replacement, and the case-mapping approval is the same URL.
- **`[harness]` is absent from the lock on purpose.** The comparator treats a `[harness]` table with equal harness hashes as an
  undeclared difference; both stacks run the same harness.
- **`role` in the mapping** is the comparator's positional label (the first 14 declared cases `primary`, the rest `diagnostic`).
  It carries no statistical meaning here: all 21 cases are read alike.
- **`historical-reference.tsv`** (Stage 2A) has no row for these IDs. The comparator prints only the rows that exist, so its
  historical table is empty for this campaign; no change was needed.
- **Inapplicable tests.** `../stage2b/test_p14_reset.jl` ("real path cases") builds the Stage 2A path case on the removed
  solver families: on both stacks with the current harness its two helper groups pass and the group "real path cases" fails
  (the path cases are not in the current catalog). It is documented as inapplicable to the successor and not restored. The
  legacy testsets of `../stage2b/test_export_fingerprints.jl` (workspace, primal-dual, paths, group, setup) likewise run only
  where the harness catalog has those cases.
- Nothing here is a measurement, and nothing is claimed about performance.
