# Vector SparseIterate CD validation and costs

This evidence accompanies [PR #247](https://github.com/mlakolar/ProximalSolvers.jl/pull/247)
and the [approved ownership contract](https://github.com/mlakolar/ProximalSolvers.jl/issues/246#issuecomment-6811898322).
Public vector SparseIterate input reuses the existing coordinate-descent engine
through a private state-preserving copy. Completed finite results replace the
caller's full working-set state; numerical exceptions before commit leave it
unchanged. PGD remains dense-only.

## Sources and numerical validation

The measured base is PS `4259a3852f10e90f59f30cb61b1d296e279fdfa8`; the
implementation and harness are PS `01f7d1b67929ab23fbc159dee5a956121568d35b`.
Both select PB `c123d56ba1948e36a8fdbf183a9eea396a16e0d5`.
The metadata records full Project/src SHA256 identities and the executed harness
digest. This report and its raw data add no solver or test changes.

Executed with Julia 1.13.3 on Linux x86_64 through Slurm:

| Check | Result | Job |
| --- | --- | --- |
| Test imports, package precompile and ordinary package load | Passed; selected PB source loaded | 14029235 |
| Bounds-checked focused Pkg.test, five files and two workers | 3,390/3,390 assertions | 14029235 |
| Positive sparse-input acceptance probe on base/head | Base rejects at the dense-only gate; head passes both precisions | 14029609 |
| Unmodified independent paired-source diagnostics | 288/288 records match frozen historical sources | 14029609 |
| Documentation build, doctests and exported API coverage | Passed; deployment disabled | 14029609 |
| Benchmark startup canary and full paired measurements | Completed; analyzer coverage and corruption controls pass | 14029610 |

The focused files are `sparse_cd`, `core_contracts`, `core_regressions`, unchanged
`minimal_core_characterization`, and `examples`. They cover independent raw
objective/KKT and orthogonal references, canonical dense/owner equivalence,
unsorted sets and active signed zeros, zero-pass preservation, pass-limit
commit, activation/compaction, warm starts, zero/underflowed columns, rollback
after private updates, validation/alias failures, RNG consumption and original
caller identity. The new API probe independently returns `[1.5,0]`, objective
`0.875` and KKT violation `0` in Float32 and Float64, and compacts the entry
active zero. The same probe fails positive acceptance at the base's unsupported
sparse-input gate.

The paired controller remains unchanged. Its isolated fresh processes check
immutable commits, clean Git states, loaded paths and source digests, then
compare 288 numerical/storage records with frozen PS `64930401cfc0451e886728d916263c4dab2baf36`
and PB `e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291`.
Immutable local Git mirrors populated from the upstream commits supplied its
offline fetches; per-process URL redirects did not change its source or checks.
Final-head required CI and published-preview evidence are recorded in the PR.

## Paired solve measurements

Both PS versions and a second head copy load from source into separate modules
in the same process, sharing the exact PB dependency. Measurements use one
Julia and BLAS thread on an AMD Zen 3 processor. The host was shared and under
load; these are indicative comparisons, not exclusive-machine throughput claims.

Each cell has 30 alternating paired rounds; each side contributes the minimum
of three warmed batches per round. Fresh caller state and seeded RNG creation
are outside timing. Validation, private allocation/copy, model/cache creation,
the unchanged algorithm, result creation and commit are included. All solves
converged within the harness's 2,000-pass cap. Canonical identical states are used
for timing; accuracy from differently ordered working sets is assessed separately
in tests. The 8×100,000 zero-design case is a storage-cost diagnostic with known
zero optimum, not a representative statistical design.

All measured solve cells have matching point/objective hashes, pass counts,
convergence flags, stopping residuals and independent objective/KKT records.
Warmed per-solve allocations match across sides in all three comparisons.
The ratios below are medians of paired head/base, head/head-control and
public-owner/dense-head times. A ratio above one means the numerator route took
longer. The bytes column is per solve and is shared by the compared routes.

| Type | Design | Entry | Dense head/base | Head/control | Owner/dense | Bytes/solve |
| --- | --- | --- | --- | --- | --- | --- |
| Float32 | 128×32 | low | 1.0158 | 0.9901 | 0.9939 | 3,891.2 |
| Float32 | 128×32 | full | 1.0073 | 0.9938 | 0.9974 | 3,891.2 |
| Float32 | 1024×256 | low | 1.0163 | 0.9827 | 1.0250 | 24,716.8 |
| Float32 | 1024×256 | full | 1.0245 | 1.0082 | 0.9989 | 24,716.8 |
| Float32 | 8×100000 | low | 1.0023 | 1.0143 | 0.9619 | 4,401,168 |
| Float32 | 8×100000 | full | 0.9811 | 1.0208 | 0.9824 | 4,401,168 |
| Float64 | 128×32 | low | 0.9720 | 1.0331 | 0.9977 | 6,180 |
| Float64 | 128×32 | full | 0.9749 | 1.0340 | 0.9955 | 6,180 |
| Float64 | 1024×256 | low | 0.9901 | 1.0145 | 1.0117 | 42,024 |
| Float64 | 1024×256 | full | 1.0001 | 1.0070 | 1.0008 | 42,024 |
| Float64 | 8×100000 | low | 0.9678 | 1.0016 | 0.9574 | 6,401,296 |
| Float64 | 8×100000 | full | 0.9569 | 1.0195 | 1.0034 | 6,401,296 |

The largest median dense base/head increase is 2.448%; the largest owner/dense
increase is 2.497%, alongside a largest head/head-control increase of 3.401%.
No cell triggers the preregistered material-repeatable-regression screen of
more than 5% outside the same-source control. Spreads are substantial: the
largest-median dense case has paired p10/p90 ratios about 0.858/1.101, and the
largest-median owner case about 0.914/1.178. This does not establish universal
equivalence or a tight timing bound. It supplies no reason to weaken the
approved numerical-failure guarantees.

## Copy and copy-back costs

SparseIterate retains capacity for the full logical coordinate count. The
private copy therefore allocates O(p) memory even when few entries are active.
The dense wrapper also allocates a private full-capacity iterate; public owner
input is not an O(active)-memory optimization.

The following cells start with 10 active coordinates and copy a state with
10 active coordinates. Times are per-operation medians; allocation bytes are
exact observed counts. Setup and public-state verification are outside timing.

| Type | Coordinates | copy ms | copy bytes | copyto! microseconds | copyto! bytes |
| --- | --- | --- | --- | --- | --- |
| Float32 | 1,000 | 0.008 | 20,296 | 0.611 | 0 |
| Float32 | 100,000 | 0.120 | 2,000,264 | 0.656 | 0 |
| Float32 | 1,000,000 | 2.473 | 20,000,264 | 0.902 | 0 |
| Float64 | 1,000 | 0.006 | 24,264 | 0.766 | 0 |
| Float64 | 100,000 | 0.142 | 2,400,264 | 0.606 | 0 |
| Float64 | 1,000,000 | 1.356 | 24,000,264 | 0.942 | 0 |

At one million coordinates this private copy allocates 20,000,264 bytes for
Float32 or 24,000,264 bytes for Float64. Copy time varies with allocation/cache
conditions; for example, the Float32 low-occupancy copy's p10/p90 are about
1.132/2.668 ms. The full raw records preserve that spread.

Copy-back allocates zero bytes in all 30 measured copy-back cells. Low/low occupancy
uses PB's active-state traversal; replacing a full entry state with a small
result uses its full-map strategy. At one million coordinates, full-to-10
copy-back medians are about 1.284 ms (Float32) and 1.346 ms (Float64), with zero
allocation. The raw grid also covers full/full replacement and occupancies on
both sides of PB's strategy threshold. Each destination starts in the specified
entry state for each measured copy-back. Both copies verify coordinate IDs,
slot order and values through public storage APIs, including active signed zeros.

## Artifacts and reproduction

- [summary.json](summary.json): all paired ratio quantiles, allocations and copy medians.
- [metadata.toml](metadata.toml): exact source identities, environment and harness digest.
- [solve.tsv.gz](solve.tsv.gz): 2,160 solve rows in 36 complete groups.
- [copy.tsv.gz](copy.tsv.gz): 1,800 copy rows in 60 complete groups.
- [Harness and analyzer](../../../benchmark/sparse_cd/README.md): commands and semantics.

Use clean base/head Git worktrees at the recorded commits and instantiate the
root project, not the historical benchmark environment. The harness records its own hash and rejects wrong PB sources, dirty
checkouts, changed source identities and numerical divergence. Its bounded canary is marked and rejected by full-case analysis.
The analyzer requires the complete expected case sets and refuses missing
groups, missing rows, changed diagnostics and nonfinite timing data.
Independent recomputation matched the complete summary and source/harness hashes.

The Julia 1.13 run emitted source-loader binding/world-age warnings during
module setup, outside the timed region. Verified identities and matching records
support these results; the warning remains a forward-compatibility limitation
of the measurement loader. No solver arithmetic, stopping thresholds, PB pin,
package version or release policy changed to obtain these measurements.
