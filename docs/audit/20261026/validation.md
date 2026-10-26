# Validation record

Status: validation in progress; the final PR comment records the reviewed head
and CI outcomes. Do not interpret this draft record as an all-pass verdict.

## Editions

- Audit base: `bba7c1a263c83613c68708731eedb4a1e2711f6f`.
- Initial repairs: `3b0f638` plus the subsequent compatibility/documentation
  commits on this branch. The final GitHub summary identifies exact commits.
- Baseline/development ProximalBase: `4dc00b0772b67757bdad3d3933f85fee9e22822f`
  exported from Git into an isolated source directory; version metadata 0.5.3.
- Pending ProximalBase #128: `f4ee1b3a9caa6cd39c8e51f9be5184f06a0336ff`, also
  version metadata 0.5.3. Tested separately; not inferred from the version.
- Released ProximalBase 0.5.2: registry tree
  `459ce7feea2e9455bf304864843cc2a8a329f63b`. The original compat permitted it,
  but package loading fails at `GroupMCP`. The repaired compat excludes it.
- Downstream HEADs and working-source hashes: [source editions](source-editions.json).
  Tests use isolated copies of the tracked working-file editions, including
  existing changes. No sibling Project.toml or branch was changed.

The adjacent compressed patches preserve the downstream runtime/test differences
from their recorded HEADs. To recreate one, check out that HEAD in a fresh clone,
then run `gzip -dc HighDimensionalModels.jl.patch.gz | git apply` in that clone
(adjust the filename per package). Source hashes identify the tested files. The
untracked HDM `fix.md` was excluded and is not a runtime dependency. CovSel is a
second checkout of CovarianceSelection; it is not counted as a fourth downstream.

## Baseline and adverse evidence

The unmodified base passed its complete suite against ProximalBase master on
Julia 1.13.2. Independent probes nevertheless found PS-01/03/04/08. Their logs
are retained with the audit evidence. The first performance harness attempt used
unsupported function division; that harness error was corrected before baseline
measurements. No result from that failed attempt is used as a timing.

During repair, the new active-set check initially exposed Float32 failures.
The measured residual was about 0.006 against 0.00017. A stable least-squares
Taylor-remainder comparison repaired the underlying acceptance issue; the
original Float32 assertions were not weakened. An initially overstrict image
comparison caused a normal Float64 monotone solve to reject representable steps;
image-unit roundoff treatment repaired it. The existing centering case at 1e-7
then solved with BigFloat-checked residual about 1e-8, below its 2.9e-7 threshold;
1e-8 retained the bounded error. The updated test accepts independently accurate
success or bounded failure, not a prescribed error trajectory. The first QUIC
weight-equivalence test used different random schedules; its repair gave both
solves identical generators. ADMM's established ErrorException type for invalid
rho was retained after the compatibility suite identified that difference.

## Reproduction

Use an isolated Julia environment. Explicitly develop the candidate and the
chosen ProximalBase source together; add Aqua and Statistics; execute
`test/runtests.jl` with `--startup-file=no --check-bounds=yes` and one BLAS thread.
For the downstream suites, develop the recorded copied sources and their test
extras in another environment. Use a separate environment/manifest for Julia
1.10. Optional suites require their declared LP/QP dependencies, not hidden
sibling checkout edits. The package's ordinary standard-Pkg workflow does not
require the workspace bootstrap or a particular dependency branch.

## Allocation and timing scope

Local exploratory measurements use Apple M3 Pro (12 logical CPUs), macOS ARM64,
Julia 1.13.2, OpenBLAS ILP64 0.3.30, one Julia computation thread and one BLAS
thread. Seed 90210; dense Float64 design 120 by 40; four signal coefficients;
objective `norm(y-X*x)^2/(2n)+0.05norm(x,1)`. Each complete solve is warmed and
then timed seven times, reporting the minimum. Data generation and function
construction are excluded; solver-state and result allocation are included.
ADMM's supplied loss has already warmed its proximal factorization. Fits are
cold coefficient starts on the same data, not new-response fits or paths.

`performance.jl` is the exact corrected harness. Baseline and repaired scalar
comparisons use the same ProximalBase source. Complete-fit rows include direct
objective/gap and independently written soft-threshold fixed-point checks. Stage
rows reuse state near a solution, exclude history, and include closure/scalar
boxing in this exploratory harness; they do not establish an intrinsic 0-byte
kernel contract. Existing typed-kernel allocation tests provide separate evidence.
Returned results, traces and saved paths intentionally allocate. Float64 CPU
results do not establish BigFloat, GPU or arbitrary storage performance.

Final results, documentation build/visual checks, downstream suites, ordinary
installation and supported-version/platform CI are appended after completion.
