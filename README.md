# Evidence for #351: ElasticNet Float32 residual on macOS aarch64

Issue: https://github.com/mlakolar/ProximalSolvers.jl/issues/351. Fix: PR https://github.com/mlakolar/ProximalSolvers.jl/pull/360 (option A′).

**Cause.** On Julia 1.13.4 (LLVM 20.1.8), aarch64, at `-O2`/`-O3`, LLVM's SLP vectorizer combines the two `Rational{Int64}` → `Float32` conversions in `_converted_penalty(::ElasticNet, Float32)` into one `sitofp <2 x i64> to <2 x float>`. The AArch64 NEON lowering emits that as `scvtf.2d` + `fcvtn`: Int64 → Float64 → Float32, which rounds twice. For the test level `1152921573326323713 // 1152921504606846976` (a tie after the first rounding), the converted level is `1f0` instead of `Float32(λ)` = `1.0000001f0`, and `test/elasticnet.jl:293` sees a residual of `2.3841858f-7`.
- The upstream fix is llvm/llvm-project#130665, in LLVM 21.
- Julia 1.10 (LLVM 15) doesn't vectorize this function. Julia 1.14.0-beta1 (LLVM 23) gives the correct result. Linux x86_64 is correct on every version tested.
- ProximalBase is correct, and the test is correct.

**Fix (A′).** Each level not of type `T` is converted in a `@noinline` call of its own; a level of type `T` is returned as it is. For native levels the code of `_stationary!` is identical to before.

## Contents

| path | what |
|---|---|
| `reports/01-root-cause.md` | Stage 0 report, as posted on #351 (issuecomment-6966419423) |
| `reports/02-lifecycle-audit.md` | conversion lifecycle and frequency audit, with options A/A′/B/C and the timings, as posted on #351 (issuecomment-6966770568) |
| `reproducer/probe.jl` | standalone reproducer: the level, `T(λ)` vs `T(Float64(λ))`, bit patterns, `_converted_penalty` coefficients, independent residual, `kkt_violation` variants, a 256-bit BigFloat reference, an `llvmcall` vector-`sitofp` probe, and native-code scan counts (`--native`). Run: `julia --project=<ProximalSolvers checkout> probe.jl --native` |
| `reproducer/ir.jl`, `reproducer/v.ll` | the LLVM IR of `_converted_penalty` for Rational levels; the bare vector and scalar `sitofp` used by the `llvmcall` probe |
| `reproducer/probe351-run44217009396.yml`, `reproducer/probe351.yml` | the temporary GitHub Actions workflows of the two probe runs (macOS aarch64 and Linux; -O0..-O3; isolated test before and after the candidate patch) |
| `reproducer/candidate.patch`, `reproducer/candidate_a2.patch` | option A (helper for every level) and option A′ (helper for levels not of type `T`), as applied by the probe runs |
| `scripts/count.jl` | counts `_converted_penalty` calls per solve (PGD, APG, CD) |
| `scripts/bench_real.jl` | timings of the real `_stationary!` and `solve!` for base, A/A control, A, A′, B, C0, switched in one process |
| `scripts/irdiff.jl` | compares the LLVM IR of `_stationary!` between variants for native levels |
| `scripts/iterlevels.jl` | shows that using converted levels in the iterations would change PGD/APG iterates |
| `scripts/bench_check.jl` | an earlier pool-loop benchmark, superseded by `bench_real.jl`: LICM hoisted the base conversion out of its loop, so it understates the base cost |
| `benchmarks/real_pinned-run1.txt`, `benchmarks/real_pinned-run2-with-Aprime.txt` | `bench_real.jl` output, Julia 1.13.4, Linux x86_64 (Intel Raptor Lake), pinned to one performance core, BLAS 1 thread |
| `logs/run44217009396-*.txt` | probe run 44217009396 (option A) job logs: macOS aarch64 1.13.4 (baseline isolated test fails, patched passes), macOS 1.10.13, macOS 1.14.0-beta1 (`macpre`), Linux 1.13.4 and 1.10.13 |
| `logs/run44219628460-*-Aprime.txt` | probe run 44219628460 (option A′) job logs: macOS aarch64 1.13.4 (baseline fails, A′ passes 1758/1758), Linux 1.13.4 |
| `SHA256SUMS` | checksums of every file above |

Both probe runs used ProximalSolvers `8d2a30e` with the ProximalBase pin `a19c59aa723d085d5d7cf5242895bda16eb77214`. The local scripts take a ProximalSolvers checkout as `--project`. The scratch branch they ran on (`research/issue-351-probe`) was deleted after this archive was made; its two commits are `d229738` (option A) and `1aa26a8` (option A′).

## Final verification of the fix (PR #360, squash-merged as `bb20b6a`)

| path | what |
|---|---|
| `final-verification/nightly-44232029082-macos-aarch64.txt` | Nightly dispatch on the PR branch at `5180395` (code identical to the merged fix; the final commit `6bc57cc` changed only a comment): macOS aarch64, Julia 1.13.4, full tier, 68239/68239, elasticnet 1762/1762. The Linux 1, Linux 1.10 and Windows 1 legs of that run passed too. |
| `final-verification/local-elasticnet-julia-1.10.13.txt`, `…-1.13.4.txt` | `scripts/test.jl elasticnet` at `5180395`, local Linux x86_64, `--check-bounds=yes`: 1751/1751 and 1753/1753 |

PR CI (run 44233083984) and Documentation (run 44233083782) passed at `6bc57cc`. The Codex terminal review passed at `6bc57cc` (two rounds). The full record is the PR's comments and reviews: https://github.com/mlakolar/ProximalSolvers.jl/pull/360.
