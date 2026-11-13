# Evidence for ProximalSolvers.jl #279 and PR #299

Disposable research and verification scripts. They are not package code and not proposed patches. This archive preserves how the #279 conclusions and the PR #299 verification were obtained.

## Revisions

| What | Revision |
|---|---|
| Research snapshot (design memo) | PS `782b74c2b781e1811b6d113b9f8993463a75ee15` |
| PR #299 base (master) | PS `3408e1fc24840596e4f67deb797699e7338aa213` |
| PR #299 head | PS `76625855677230c1c02803d754f072ac0fb7aec9` |
| PR #299 squash merge | PS `22294a9afb1789836c2d5c51af6c9f799b61b3e5` |
| ProximalBase pin (all of the above) | `c123d56ba1948e36a8fdbf183a9eea396a16e0d5` (manifest `git-tree-sha1` `c2e2ddde114a1e7800358595193ee0869830180d`) |
| Julia | 1.10.12 and 1.13.3 |

Records: issue #279 (plan, base-probe results and design memo) and PR #299 (plan, round comment, Codex review, run report).

## Layout

- `research-782b74c/`
  - `probes/`: the research harness, run against `782b74c`.
  - `prototypes/`: the candidate diffs measured for the memo. These are illustrations: `copy1`, `args`, `iter0`, `fy`, `snorm`, `trial`, `solve`, `fwd`, `all`, and `pr1`, the recommended bundle.
  - `path-table.txt`: path coverage and allocations at `782b74c`.
  - `memo-final.md`, `plan-final.md`: copies of the posted texts.
- `pr299/`
  - `probes/`: the same harness rebaselined against `3408e1f`. It adds `corpus_f.jl` (716 `ftol = 0` cases from #270), the by-name IR lookup and the new coverage rows.
  - `timing/`: `solve_timing.jl` and `solve_compare.py`, the supplementary paired solve timing.
  - `summaries/`: the formal-harness `REPORT.md` files (A/B and A/A per Julia version) and the solve-timing `AB`/`AA` tables.
  - `plan-final.md`: copy of the posted plan.

## Reproduce

All scripts check on load that ProximalBase is the pinned commit (`common.jl`). They never call `scripts/instantiate.jl`, which resolves from local development checkouts.

1. **Trees.** For each revision to compare, extract a package tree: `git archive <sha> | tar -x -C probes/trees/<name>`. A control is a second extraction of the base.
2. **Fingerprints.** `julia --project=. probes/fp_driver_proto.jl probes/trees/base-a probes/trees/base-b probes/trees/head`
   - Run it from a checkout that holds `probes/`, with the root project instantiated from the committed manifest.
   - It runs one fresh process per tree, writes a canonical record per corpus case, and compares each tree with the first byte for byte. It then repeats the comparison without the `f_y` state-dump lines.
   - Compare only within one run: the same node and the same Julia version.
   - Positive or zero `time_limit` values are not fingerprintable on tiny problems; the corpus uses negative limits.
3. **IR and inference.** `julia --project=. probes/ir_driver.jl <trees...>`: normalized `code_llvm` per function, looked up by name, plus `return_types`/`@inferred`, each against the first tree.
4. **Allocations.** `julia --project=. probes/alloc_driver.jl <trees...>` (warmed `solve!` and `update_state!` on the coverage scenarios).
5. **Coverage.** `julia --project=. probes/coverage_probe.jl` (branch counters on text-transformed copies of single functions; anchors are specific to the revision).
6. **Formal timing.** Follow `benchmark/HARNESS.md`, "paired comparison":
   - a fixed harness copy from a committed checkout of the base;
   - `benchmark/setup.jl <checkout> <env> pinned` for each side;
   - `PS_SUITE=extended PS_GROUPS=gradient`;
   - `PS_EXPECTED_PACKAGE_REVISION` and `PS_EXPECTED_PROXIMALBASE_REV` set, one thread on one pinned core, 5 rotated repetitions;
   - `benchmark/compare.py` for A/B and A/A.
7. **Solve timing.** In each side's benchmark environment, for each repetition run `julia --project=<env> timing/solve_timing.jl <side> <rep> <dir>/<side>-rep<rep>.tsv`, rotating the order of the sides. Then run `python3 timing/solve_compare.py <dir> before after` (and `before control` for A/A).

## Results (PR #299, head vs master)

- **Fingerprints:** 13,572 cases. A/A is byte-identical. A/B is identical apart from the removed `f_y` line in 2,183 APG state dumps. Both hold on Julia 1.10.12 and 1.13.3.
- **Inference:** equal. **Allocations:** 109 of 628 scenarios lower, none higher. **IR:** only the expected removals.
- **Solve timing:** geometric mean A/B 0.9984 (1.13.3) and 0.9972 (1.10.12), against A/A 1.0015 and 0.9978. No case is above +5%, and iterations and minimizers are equal.
- **Formal harness:** 1–2 timed cases per version, all inconclusive. The other cases are `target_missed` on every side.
