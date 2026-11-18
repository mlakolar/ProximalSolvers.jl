# Evidence for ProximalSolvers.jl #317 (PR #377)

This branch holds the evidence for #317: Float64 PGD's line search raised `line search failed: nonfinite curvature estimate` when a trial's squared step norm was subnormal and the gradient-difference product was 0, because `0 · Inf` gave NaN. The fix is R2g: `iszero(local_l) || (local_l *= 2. / xy_sq)` in `LineSearches.backtrack!`.

## Revisions

| what | revision |
|---|---|
| research base (memo, recorded 448-solve base) | `b8a2c04205f6dc8aadeecc42f4971602ab1b5b89` |
| PR base (master at start) | `8cc022222d3c90ef86a24ca0c957b02faaf4fc1f` |
| measured head (executable source final) | `6e2f72857103b19be9375d90368a5b091940c4b0` |
| last PR commit before the catch-up merge (comments, docs and tests changed after 6e2f728) | `d96cc2ff722100ed3aea911735d5fb811fa76543` |
| catch-up merge, final PR head | `9ca5c72eae0ec589c2a666749af896023b282b6d` (merges master `1baab8123c063f80e2b7ba6481eb37ae2aa9617b`) |
| PR #361 as merged into master | head `6af5afaea12ba681ea4d5b1e45c909714ce711f7`, merge `16a0bb7baf81f1ec85bdf37831e001d663f1a90b` |
| PR #361 head checked with the fix applied (detached copy, never pushed) | `045428f9b53072d8d118f0af681034eea4891f71` |
| ProximalBase pin | `a19c59aa723d085d5d7cf5242895bda16eb77214` |
| #296 evidence used by the research | branch `archive/issue-296-evidence` at `84399297` |

Records: memo https://github.com/mlakolar/ProximalSolvers.jl/issues/317#issuecomment-6971067820, PR https://github.com/mlakolar/ProximalSolvers.jl/pull/377.

## Environment

- Runs were local, on one Intel 13th-generation desktop CPU (20 hardware threads), with Julia 1.13.4 (`release`) and 1.10.13 (`lts`).
- Scans and timings used one OpenBLAS thread and one Julia thread.
- Test batteries ran inside a memory cap.

## Layout

### `research/` (memo stage, at `b8a2c04`)

`probes/`:
- `variants.jl`: the probe-only overrides M, R1, R2, R2g and R3.
- `scan.jl`: Float32/Float64 by α.
- `scan2.jl`: the 448-solve Float64 scan by α and by data scale, two option sets.
- `diag.jl`: logs the failing rejection.
- `l0probe.jl`: counts guarded-branch entries under the checked-out start rule.
- `minimal.jl`, `strict.jl`, `apg.jl`, `f32*.jl`, `coretest.jl`, `diag_r2g.jl`.

`out/`: one row per solve.
- `scan2-1t-{M,M2,R1,R2,R2g,R3}.tsv` are the authoritative scans: one BLAS thread, seeded CD reference. `scan2-1t-M.tsv` is the **recorded base** of the 448-solve comparison.
- `scan2-{M,R1,R2,R3}.tsv` and `scan-*.tsv` came from earlier runs with multithreaded BLAS and an unseeded random-order CD reference. Their warm-start rows (and relative errors) are not comparable between files. They are kept for completeness and superseded by `scan2-1t-*`.
- `tests-R1-standard.log` and `tests-R2g-standard.log` are the standard test tier with R1 (1 failure) and R2g (all pass) applied locally.

Also in `research/`: `R1.diff`, `R2g.diff`, and `comment.md` (the memo as posted).

### `pr377/` (implementation stage)

`probes/`:
- `newtests.jl`: runs only the #317 testsets against a given project.
- `entry317.jl`: guarded-branch entry counts.
- `paired317.jl`: paired in-process timing over base, head, base2 and head2.
- `residual317.jl`: the documented residual case.
- Copies of the research probes.

`evidence/`:
- `battery-*`: the pre-push test batteries at `6e2f728`, `bf43e6b`, `879a848` and `d96cc2f` (`.meta` plus per-version outputs).
- `newtests-at-base-*`: the new tests fail at the base.
- `newtests-head-r2-release.txt`, `entry-counts-release.txt`.
- `paired317-release.txt`: timing; the `TIME` rows are per round and side, in µs, the minimum of 10 solves; `INFO` holds iterations, flags, warmed bytes and identity of `x`.
- `allocs317-lts.txt`.
- `scan2-head.tsv`, `scan2-base8cc.tsv`, `scanf32-head.tsv`, `scanf32-base8cc.tsv`: behavior preservation at the measured head against base `8cc0222`. Head against the recorded base: 0 of 352 non-error rows differ, and 0 of 448 rows error at head (96 at base).
- `pr361-verify.txt`: the four #317 testsets and the entry counts at #361's head with the fix applied.
- `r2g-src.diff`, `verify.sh`, and the `verify-worktrees-*` checks.

`evidence-merge/` (the catch-up merge, after #361 merged into master first):
- `battery-impl2-9ca5c72*` and `battery-merge-summary.txt`: the battery at the merge, with `initial_curvature` added.
- `entry-counts-merged.txt`: guarded-branch entries at the merge. The `diag` reproducer and the direct `backtrack!` test still reach the guard; the 1×1 and 30×12 cases converge without reaching it under #361's start.
- `scan2-merged.tsv` and `scan2-master1baab.tsv`: the 448-solve scan at the merge and at master `1baab81`. Both have 0 errors, and they are identical on all 448 rows.
- `verify2.log`, the `verify2-worktrees-*` checks, and `../verify2.sh`.

`reviews/`: the five terminal review payloads (Codex gpt-6.1-sol, high), as written by the reviewer, rounds 1–5; round 5 reviews the merge. Their posted copies are on the PR.

## Limitations

- Timings come from one CPU model and a shared desktop machine (load average about 2.3 out of 20 threads). Each case has A/A controls.
- The 448-solve and Float32 scans cover three designs. They show no behavior change on these inputs; they are not a proof for all inputs. The bit-identity argument for all other executions is in the PR's review record.
- The accuracy references are 256-bit BigFloat computations on the rounded data. They do not bound the error of a BLAS kernel.
- Machine paths in logs were replaced with placeholders (`<issue worktree>`, `<run>`, `<home>`, `<tmp>`, and so on). Nothing else was edited.

`SHA256SUMS` covers every other file (`sha256sum -c SHA256SUMS`).
