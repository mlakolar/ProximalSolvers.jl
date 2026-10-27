# Validation record

**Release verdict: blocked.** The repaired source has passed the package and
current-downstream checks below, but no compatible ProximalBase release is
available in General. Register a compatible dependency, resolve without source
overrides, and repeat installation/package tests against that released edition
before considering a ProximalSolvers release. No version bump, tag, release or
merge was performed. The draft PR's final review records exact-head platform CI
and the final reporting commit; it is the completion record for hosted checks.

## Source editions and preservation

- Audit base: `bba7c1a263c83613c68708731eedb4a1e2711f6f`.
- Implementation repairs: `3b0f638`, `18515c5`; budget-warning compatibility and
  ADMM hypothesis corrections: `4a38c8434d00d46c667fff2c7de437e64b83f9ae`.
  Later reporting/manual commits do not change the numerical kernels.
- Development ProximalBase: `4dc00b0772b67757bdad3d3933f85fee9e22822f`,
  Git tree `e928f3e18969abda2ddbecfc4dbf26ff82d80460`, metadata 0.5.3.
- Initial ProximalBase #128: `f4ee1b3a9caa6cd39c8e51f9be5184f06a0336ff`,
  also metadata 0.5.3. Both were exported into separate frozen source directories.
- A later #128 head, `b207d0f9528deda09786bb35066130314ecc9815` (tree
  `85a7b80b55ee5f72b4e062dca1cfd07248ea4afb`), was observed during final validation and
  separately frozen; [hashes](pb-latest-edition.json). Its supplementary package
  and downstream integration results are recorded in the final PR review. The
  initial #128 matrix below always means `f4ee1b3`, not this later head.
- Released ProximalBase 0.5.2: registry tree
  `459ce7feea2e9455bf304864843cc2a8a329f63b`. The original candidate compat
  permitted it, but loading failed at missing `GroupMCP`. Corrected compat
  excludes it; a fresh candidate Git install using only registry dependencies
  now correctly fails resolution, rather than installing an unloadable package.
- Registered ProximalSolvers 0.1.0: tree
  `84e8a80e0c047f1ccaa7429e6c960ea7a27a84f7`. It loads and solves an independent
  orthogonal check with released ProximalBase 0.5.2. Its older API lacks the new
  result `converged` field and coordinate-descent API. Installation guidance
  explicitly distinguishes it from the development examples.

The dirty primary checkout at `9041e236f3de8ffdc02103e5a505993463e00bb1` was
compared separately and preserved; its changes were not overlaid on this branch.
Original sibling HEADs, status and working-source hashes are in
[source-editions.json](source-editions.json). Compressed patches preserve their
runtime/test differences. Recreate one by checking out its recorded HEAD, then
running `gzip -dc HighDimensionalModels.jl.patch.gz | git apply` (adjust the name).
The untracked HDM `fix.md` was excluded. CovSel is a second CovarianceSelection
checkout, not another package.

Fresh downstream masters were separately fetched, exported and hashed in
[current-downstream-editions.json](current-downstream-editions.json). No live
sibling Project.toml, working file or branch was edited. Expected sibling-layout
aliases existed only inside the isolated test area; they selected the same
recorded ProximalBase and solver sources without rewriting package metadata.

## Completed package and installation checks

| Check | Source / environment | Outcome |
|---|---|---|
| Baseline complete suite | Unmodified audit base; PB master; Julia 1.13.2 | Pass, despite the independent counterexamples below |
| Standard `Pkg.test("ProximalSolvers")` | Repaired source; PB #128; Julia 1.13.2 | All 40 files, 237 reported testsets pass; includes Aqua and all 16 examples |
| Standard `Pkg.test("ProximalSolvers")` | Same PB #128; separate Julia 1.10.12 environment/manifest | All 40 files, 237 reported testsets pass |
| Focused active/GLM regressions | PB master; Julia 1.13.2 | Original active-set assertions, new full-residual checks and GLM suites pass |
| Ordinary registry install/load | PS 0.1.0 + PB 0.5.2; Julia 1.13.2 | Independent orthogonal solution passes using the released API |
| Fresh Git install/load | PS `4a38c84` + pinned PB master; Julia 1.13.2 and 1.10.12 | Both pass an independent orthogonal solution and qualified API discovery; no workspace bootstrap or sibling source paths |
| Candidate with released dependencies only | Fresh environment, PS `4a38c84` Git source | Expected unsatisfiable PB minimum; retained negative check |
| Naming / whitespace | Maintained naming checker and `git diff --check` | Pass; `Lexact` retained as an established keyword |
| Hosted implementation checks | `4a38c84`, PB master; Linux Julia 1.10/current, current macOS ARM64 and Windows x64 | [All four platform jobs and evidence checks pass](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/40368394501); [docs pass](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/40368394643) |
| Final reporting-head CI | Same numerical source, final manual/evidence additions | Exact head, checked tree, dependency commits and outcomes are linked in the final PR review |

[Core outcomes](evidence/test-outcomes.json) includes full-log hashes; adjacent
`.log.gz` files retain the complete outputs. The package's numerical oracles
remain trusted dependencies except for the interface and independent numerical
checks described in the ledger. Passing these tests is not a proof for arbitrary
custom losses, proximal operators or storage implementations.

## Downstream compatibility

Full standard `Pkg.test` suites on Julia 1.13.2 with PB #128 and this candidate:

| Consumer | Frozen master | Full-suite result |
|---|---|---|
| HighDimensionalModels | `1b2301933a0832709c71badf7f8d012d2dce6ca4` | 6,114 pass; declared HiGHS, ProximalAlgorithms and StatsModels targets, quantile/raw-score checks, golden comparisons, deprecated API and Aqua included |
| CovarianceSelection | `0b0214f7fa15066cbd2f16355d020c0a0ace84da` | 1,463 pass; MathOptInterface/HiGHS extension and full CLIME/IHT/ADMM suites included |
| DiffPrecTest | `6ba332ce6598273394704ca2859d17362bcf535b` | 20,178 pass; complete structured estimation, support, variance and bootstrap suites with declared JuMP/Ipopt extras |

KernelSmoothing `a99bcc9497d7997106d66ce837705fd70c055687` is the frozen HDM
test dependency; it is not counted as a direct solver consumer. The initial
older dirty HDM working-file edition was also tested separately. Its continuation
wrapper has no `gaptol` forwarding, so its `opt_tol`-based accuracy expectations
fail when the solver's existing path gap default takes precedence. Current HDM
master already exposes `gaptol` and sets it to zero in those accuracy tests.
Do not infer validation of that older working edition from the passing master.
The initial attempt also exposed a test-harness direct-import omission and its
relative `[sources]` layout requirement. Those failures are retained separately.
The complete layout-correct standard `Pkg.test` legacy run has 2,409 passes,
78 failures and zero errors (all sixteen files, deprecated API and Aqua reached).
Its log is retained as `evidence/downstream-legacy-hdm-complete.log.gz`. This
is a failed compatibility result, not a smoke pass; numerical/status/path
assertions in that edition still need its upstream gap-option API and caller
updates before retesting. The old-source failures are not all attributed to
this audit merely because the candidate was used for the run.

A changed warning prefix caused one downstream compatibility failure. Commit
`4a38c84` restores the established budget-exhaustion prefix while retaining a
truthful distinct message for an uncertified square-root point. Current master
passes without a downstream production patch. Private HDM dependencies remain
listed in the architecture/API review; they were retained, not made public.

## Reproduction

In a fresh directory, clone the canonical solver repository as `ProximalOPT.jl`
and clone `ProximalBase.jl` and the four downstream repositories beside it.
Check out the exact candidate/dependency/downstream revisions above. The older
folder spelling accommodates the existing downstream `[sources]` metadata; it
does not select an older module. For the dirty editions, apply the preserved
patches to their recorded HEADs instead of checking out current master.

Use a separate environment for each Julia version and PB source edition:

```julia
using Pkg
root = "/absolute/path/to/isolated/checkouts"
Pkg.activate(joinpath(root, "audit-env"))
Pkg.develop([PackageSpec(path=joinpath(root, name)) for name in
    ["ProximalOPT.jl", "ProximalBase.jl", "HighDimensionalModels.jl",
     "CovarianceSelection.jl", "DiffPrecTest.jl", "KernelSmoothing.jl"]])
for name in ["ProximalSolvers", "HighDimensionalModels", "CovarianceSelection", "DiffPrecTest"]
    Pkg.test(name; julia_args=["--startup-file=no", "--check-bounds=yes"])
end
```

Set `OPENBLAS_NUM_THREADS=1` and run local Julia processes sequentially. `Pkg.test`
installs each package's declared test targets. For a standalone documentation
environment, develop the candidate and chosen PB source, add `Documenter`,
`DocumenterInterLinks`, `Literate` and `Statistics`, then run `docs/make.jl`.
Run the adjacent timing/allocation scripts from an environment explicitly
developing both solver and PB. `install-check.jl` takes mode (`registry`, `git`
or `unsupported`), a fresh environment path and, for Git modes, the exact PS
commit. Compressed manifests retain the actual dependency solutions; their
local path entries must be re-developed at the recreated locations.

## Baseline failures and adverse development evidence

Independent probes found PS-01/03/04/08 even though the baseline suite passed.
The [probe output](evidence/baseline-probes.log) retains the unbounded flat
quadratic, incorrect refit support, ADMM alias corruption and square-root
coordinate trap. The new tests check original objectives, feasibility or
stationarity rather than only agreement between solver variants.

The new active-set check initially exposed Float32 residual about 0.006 against
0.00017. Stable least-squares Taylor-remainder acceptance repaired it without
weakening the original Float32 assertions. An initially overstrict image bound
then rejected ordinary Float64 monotone steps; image-unit roundoff treatment
repaired that. Generic quadratics also needed a cancellation-free remainder and
continued restricted iterations after a heuristic stop. The original active-set
suite passes unchanged. The old implicit-centering case at 1e-7 now can solve
accurately: an independent BigFloat residual is below the requested threshold;
the tighter 1e-8 case retains bounded failure. The test accepts independently
accurate success or a bounded error, without prescribing a failure trajectory.

The first original-gradient GLM guard demanded the second-order objective-change
tolerance from a first-order residual. An accurate Poisson fit had residual
1.3e-9 but was required to reach 1e-14. The additional guard now uses `sqrt(tol)`;
the large-objective-offset false-success regression remains. QUIC equivalence
initially used different random schedules; both runs now use the same generator.
ADMM retains its established ErrorException type for invalid rho.

Retained harness failures include unsupported function division in the first
baseline timing attempt, zero tolerances in the reporting-allocation harness,
a transitive import absent from the active installation project, and using a
new result field on the registered older API. The corrected harnesses and actual
successful results are distinct. One broad optional environment's automatic
precompile reported `Unknown package: SpecialFunctions`; explicit instantiation
and isolated standard package tests passed. No package or sibling source was
patched to conceal these environment/harness errors.

## Allocation and exploratory timing

These are bounded local diagnostics, not a replicated performance campaign.
Hardware: Apple M3 Pro, 12 logical CPUs, macOS ARM64, Julia 1.13.2, OpenBLAS ILP64
0.3.30, one computation thread and one BLAS thread. The development machine was
not reserved; other user processes can affect timing. No general speedup or
platform-wide performance claim follows. Frozen historical benchmark environments
and evidence were not changed; their repository integrity checks remain in CI.
No substantial benchmark or profiling campaign was launched locally.

Seed 90210; dense Float64 design 120 by 40; four signals; objective
`norm(y-X*x)^2/(2n)+0.05norm(x,1)`. Functions/data are constructed before timing.
Each fit starts from zero and includes state/result allocation. ADMM's loss
factorization has warmed before timed fits. The same PB master source is used
for both editions. [performance.jl](performance.jl) retains the original seven
single-fit minima. [performance-batched.jl](performance-batched.jl) investigates
the regressions with seven batches of 100 fits, reporting per-fit minima and
actual evaluation counts. First-call rows include compilation and depend on
execution order; they are not isolated compiler benchmarks.

| Family | Baseline → repaired, microseconds | Iterations/passes | Bytes per fit, baseline → repaired |
|---|---:|---:|---:|
| PG | 35.72 → 40.48 | 20 → 20 | 7,856 → 7,856 |
| APG | 109.30 → 61.69 | 50 → 30 | 9,920 → 9,920 |
| Monotone APG | 56.06 → 83.05 | 20 → 30 | 13,264 → 13,264 |
| Active APG | 573.68 → 54.83 | 270 → 30 inner; one outer each | 42,400 → 43,136 |
| Dense CD | 5.71 → 6.17 | 9 → 9 | 5,568 → 5,568 |
| CSC CD | 15.90 → 16.27 | 9 → 9 | 5,600 → 5,600 |
| ADMM | 40.31 → 41.18 | 50 → 50 | 5,072 → 5,072 |
| Logistic Newton | 80.55 → 80.38 | 72 → 72 CD passes | 15,216 → 15,216 |

Every LS point meets the shared relative-gap target 1e-8 and the independently
written soft-threshold fixed-point check (largest baseline residual 3.64e-10).
The new accelerated points are more accurate in this case, around 1e-13 relative
gap. Logistic Newton has direct proximal residual 4.72e-13 in both editions.
There is no declared Newton gap in that timing row; NaN means unavailable.

The monotone regression is retained: its trajectory changes from 37 to 55
proximal trials and 20 to 30 iterations, reaching a much tighter certificate.
The extra stable image reductions also cost work. PG's slower complete fit has
unchanged counts (43 values, 21 gradients, 22 proximal trials); its measured
steady iteration is 1.38 → 1.33 microseconds. Dense CD, CSC CD and ADMM retain
small adverse complete-fit changes. These data do not isolate all wall-time
causes from machine noise; no uncertainty interval is claimed. Correctness
checks and finite-progress guards were not removed to recover a timing rank.

The stage harness reuses near-stationary state, excludes history, and includes
small closure/scalar boxing: 16–48 bytes in those rows do not establish an
intrinsic nonzero kernel allocation. The separately typed package allocation
regressions pass. [allocation-stages.jl](allocation-stages.jl) additionally checks
atom groups (64×24), matrix-response row groups (64×24×3), CSC quadratics (24)
and Kronecker models (8×8): all four warmed CD passes and initializations measure
zero bytes, with independently checked final residuals below 4.8e-12.
Construction and complete fits intentionally allocate. No dense Kronecker
matrix is constructed.

For an identical 18-iteration Float64 fit, disabled history / stored history /
extended history / a callback allocate 4,288 / 7,760 / 23,600 / 5,728 bytes.
A three-level owned path allocates 7,328 bytes. Reinitialization measures zero;
a reinitialized accurate workspace solve allocates 224 bytes for reporting.
These numbers apply only to the declared shapes, precisions and warmed scopes.
They do not establish BigFloat or GPU allocation behavior.

## Documentation and remaining limits

The maintained manual builds with Documenter/Literate, executes all sixteen
examples, and passes doctests, export coverage and internal/external reference
resolution. The six DOT diagrams render to SVG in normal manual navigation;
source PNG previews and the actual built architecture/equation pages were
visually inspected. Full-size figures are linked. The final PR review records the final hosted documentation build. The local
build has 39 pages and 3,154 checked local references with zero missing targets
or anchors. The checker excludes 78 references to Documenter's deployment-generated
`siteinfo.js` and `versions.js`; those scripts are absent from an undeployed local
preview. This is not an HTTP availability audit of every external URL.

[Preservation checks](evidence/preservation-check.json) confirm the initial
primary diff, HEAD, branch, status and 77 captured source hashes match; the three
checked dirty sibling editions also match their initial HEAD/branch/status and
109 source hashes. All 426 hashed files in the fresh downstream exports match
after testing. Supplemental Julia 1.10 downstream results are recorded in the
final PR review separately from the completed 1.13 table above.

The audit covers every implementation file, public family and maintained
manual area in the adjacent ledger. It does not prove absence of bugs, certify
arbitrary custom oracles, establish universal nonconvex convergence, supply a
joint certificate for positive-penalty exact square-root fits, or validate
physical GPUs, distributed/racy workspace sharing or every optional backend.
A larger replicated performance claim would require separate Discovery work.
Broad logging/status redesigns and private-downstream API migrations remain
separate proposals, not release claims hidden in this repair set.
