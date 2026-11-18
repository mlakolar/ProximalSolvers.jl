## Run report

### What changed

`bb20b6a` → `cde5443` (3 commits after the bootstrap): 8 files, +47 −92; in `src/`, 6 files, +34 −85. **45 executable lines fewer** (R2 −28, R4 −17), no public API change.

- **R2 (`226d165`)**: `_maxabs_diff` (→ `_norm_diff(x, y, Inf)`), the summation loop of `_frobenius_upper` (→ `_sumsq64`), `_round_up` (→ `T(v, RoundUp)`), the loops of `_flat_column` and `_flat_group` (→ `all`), `_significand_exponent` with its 256-bit conversion (→ `Float64(α)`); one test loop and two documentation passages follow.
- **R4 (`43a362d`)**: the norm and norm-of-difference kernels of `src/solvers/image_models.jl` are one family with an optional second array.
- **`cde5443`**: one proof comment corrected ("loses at most").

### What was verified, where

| check | where | commit | result |
|---|---|---|---|
| full test tier, Julia 1.10.13 and 1.13.4 | local | `43a362d` | 68,269 / 68,269 and 68,224 / 68,224 pass (base: 68,264 and 68,219; the 5 extra assertions are in the edited loop of `test/cd_numerics.jl`) |
| fingerprint matrix, base against head in one process | local | `226d165`, `43a362d` | 4,806 (1.10.13) and 4,794 (1.13.4) comparisons, 0 mismatches at each commit |
| unit sweeps of the replaced helpers; folded kernels against the four originals | local | `226d165`, `43a362d` | about 6.19 million and 990,000 comparisons per version, all identical |
| warmed allocations | local | `226d165`, `43a362d` | equal on base and head |
| paired timing, 50 cells × 3 configurations, A/A control | local | `43a362d` | largest head/base median 1.023 (control up to 1.021); no cell above 1.05 |
| required PR CI (Linux, Julia 1, full tier; benchmark controls; merge gate), Documentation, Codecov | CI | `cde5443` | passed (runs 44248895297, 44248895258) |
| `Nightly` workflow dispatched on the branch: Linux Julia 1.10, Linux, macOS ARM and Windows with Julia 1 | CI | `cde5443` | all four legs passed (run 44248935976) |
| terminal review, Codex gpt-6.1-sol, high | local | round 1 at `43a362d`: REQUEST_CHANGES (one proof-comment wording); round 2 at `cde5443`: **PASS / NO BLOCKERS** | its own probes: 1,152 extra fingerprints and 2,400 certificate comparisons per version with 0 mismatches, 0 false accepts, timing inside the gate |

The code is identical at `43a362d` and `cde5443` (two comment lines differ), so the local results at `43a362d` stand for the final commit; CI and the Nightly run are at `cde5443` itself.

**Passed:** every pre-registered check of the plan (1 to 7).
**Inconclusive:** nothing.
**Not verified:** bit-identity on other CPUs is not measured directly. The fingerprints compare base and head on one machine; on the other platforms the evidence is the repository's own test suite (the Nightly legs). No cluster or AVX-512 run.
**Remains:** nothing in this PR.

### Limitations, recorded

- Direct calls of the private helpers can differ from the base outside what a public call can pass (argument checks of ProximalBase's `norm_diff`; a scale outside the range of Float64, or a BigFloat scale in its subnormal interval, given to `_root_scale`; a zero-row matrix with an invalid column index in `_flat_column`). The review confirmed that the public gates exclude each.
- An isolated `g_residual` call at 12 coefficients costs 0.5 to 1.6 ns more (8 to 14 %); in solves the largest effect is 2.3 % at p = 12.

### Catch-up

Master moved from `bb20b6a` to `b8a2c04` (#355: an example, README and three documentation files). No file is shared with this PR and the merge is clean, so no merge commit was made; PR CI tested the merge with master.

### Process

Codex headers: model `gpt-6.1-sol`, reasoning effort `high`, in both rounds (the same session, resumed). The round 1 payload was posted with one added note (the reviewer line read "Codex (GPT-6), high"; the launch header is quoted beside it); the round 2 payload was posted unchanged. Tests, fingerprints and timings ran locally because the cluster the workflow uses by default was unreachable.

### Follow-ups

None filed, by the maintainer's instruction for #353. The remaining items of the audit are tracked where the maintainer placed them: `_sqnorm!` on #339, the stopping-status finding on #352, the interface question on ProximalBase #698. The square-root lasso item (R1) continues in #365.
