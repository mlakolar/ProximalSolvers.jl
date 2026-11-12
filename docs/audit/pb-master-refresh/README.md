# ProximalBase master compatibility refresh

This refresh selects PB `c123d56ba1948e36a8fdbf183a9eea396a16e0d5`
for the minimal dense lasso core. Objective/KKT/reference checks, historical
stopping records and allocations agree with the tested baselines. Solver and
test source are unchanged. The large Float64 PGD timing case is process
sensitive on this host, including in a control that times only BLAS; these
measurements do not establish a narrow timing-equivalence bound for that case.

## Exact sources and interface audit

- Refreshed PS master: `11a0c543e724beb54989fd2bc02ac0472542c517`.
- Previously pinned PB: `2b373c546e247781d9514a7000ef3e010343ca4c`.
- Selected PB master: `c123d56ba1948e36a8fdbf183a9eea396a16e0d5`.
- Selected PB Git tree: `c2e2ddde114a1e7800358595193ee0869830180d`.
- Dependency-only validation PS: `d2ce6245ebe24e773b4e35f25df92acfc9d9eab0`.
- Compatibility PR: [#245](https://github.com/mlakolar/ProximalSolvers.jl/pull/245).

PB advanced beyond the initially observed `eb74a914` through its NormL1 file
extraction (#864). Between the previous pin and the selection, PB moved smooth
function definitions into separate files, moved NormL1 out of separable.jl,
clarified interface documentation and added documentation/benchmark evidence.
`LeastSquaresLoss`, `Scaled`, sparse storage, array steps and the relevant
numerical helpers are byte-unchanged. Independent Codex GPT-6.1-Sol review at
high reasoning compared all 1,292 executable PB source statements after removing
line nodes/docstrings: their normalized AST multiset is identical. The module
include changes load the extracted definitions. No changed consumed API or
required PS runtime correction was found.

Root/docs Project source revisions and the committed Julia 1.10 manifest's PB
revision/tree advance together. PB's Project.toml, direct deps, UUID and
0.6.0-DEV version are unchanged, so no other floor-manifest metadata changes are
needed. README and current architecture documentation identify the new pin;
historical reports retain their original identities. PS version and supported
surface are unchanged. No historical full-package branch is imported.

## Numerical and environment verification

Executed on Linux x86_64, Julia 1.13.3, OpenBLAS ILP64, with one BLAS thread.
The package suite uses two test workers and forced bounds checks. The committed
floor manifest is metadata evidence, not a newly executed Julia 1.10 test.

| Verification | Result | Evidence |
| --- | --- | --- |
| Full Pkg.test sandbox, nine files | 2,053/2,053 assertions | [tests.log](tests.log) |
| Always-run independent paired-source diagnostics | 288/288 records match | [paired.log](paired.log) |
| Pkg.instantiate, precompile and ordinary compiled PB/PS load | Passed, selected PB package path printed | [load.log](load.log) |
| Docs environment/build, doctests and exported API coverage | Passed, deployment disabled locally | [setup](docs-setup.log), [build](docs.log) |
| Naming and Python benchmark analysis controls | Passed | Existing controls, unchanged |

The paired controller checks clean tracked source, full Git identities, actual
loaded paths and Project/src digests in separate fresh processes. It compares
the current selected pair to frozen PS
`64930401cfc0451e886728d916263c4dab2baf36` / PB
`e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291`.
Its 216 lasso cases cover Float32/64, raw/scaled LS,
orthogonal/correlated/nonunique designs, zero/nonzero starts, three penalties,
random CD with default momentum, cyclic CD without momentum, and PGD. The
remaining records check scalar proximal calls and private-owner state.
Independent references use raw Float64 objective/KKT calculations, analytic
or signed-support solutions, and fitted values for nonunique cases. Solver
points, flags and stopping counts match. Existing C0 fixtures and the known
accurate-but-pass-limited Float32 cyclic behavior remain intact.

Project/src SHA256 identities printed by the paired controller:

| Source | SHA256 |
| --- | --- |
| Current PS | `1018fa621d6016bf4af6077c510f99e50be329934b427b97b016e361a6d890a7` |
| Selected PB | `d5cfe6a35c4849ca2407f618eb1bf7359cf2eeadcc153e604a0866745b000364` |

The initial local paired invocation correctly refused the checkout after docs
setup rewrote its relative source path; that path was restored before the
passing clean run recorded here. No failing numerical record was waived.

## Timing and allocations against the previous pin

The old-pin timing baseline is exact PS master `11a0c54` plus PB `2b373c5`.
The candidate uses PS `d2ce624` plus PB `c123d56`; PS runtime source is identical.
Three persistent isolated Julia workers load baseline A1/A2 and candidate B.
Each worker has one Julia and BLAS thread. The final compiled and fresh-JIT
campaigns pin all workers to CPU 2 and serialize measured work. This is a
shared host without exclusive CPU/cache/frequency reservation.

The fixture and independent diagnostics follow the retained extraction audit:
correlated dense lasso, default solvers, deterministic inputs and fresh seeded
CD RNGs. All specialized measurement functions are warmed. Setup, input/RNG
creation, explicit pre-batch GC and independent diagnostics are excluded from
the timed region; ordinary solver validation, storage/caches and result
creation are included. Small cases batch 100 solves; moderate cases batch 20.
Each case has 24 balanced, deterministically shuffled ABA/BAB triplets. Ratios
compare the middle sample with the arithmetic mean of its two brackets and
are oriented candidate/baseline (second baseline/first baseline in controls).
Reported ratios are medians of those 24 ratios.

All eight cases have identical per-solve allocations, minimizer hashes,
objective bits, flags, counters, stopping residuals and independently calculated
objective/KKT results in each campaign. The finite returned objective agrees
with the direct Float64 calculation. PGD defaults retain their historical
OR-based stopping: the KKT column is a separate accuracy observation, not a
claim that `converged=true` certifies `gradtol`.

| Case | Compiled A/A | Compiled B/A | Fresh JIT A/A | Fresh JIT B/A | Bytes/solve A=B | KKT64 |
| --- | --- | --- | --- | --- | --- | --- |
| Float64 128×32 CD | 0.9981 | 1.0050 | 1.0178 | 1.0232 | 6176 | 9.24e-09 |
| Float64 128×32 PGD | 1.0045 | 1.0035 | 1.0108 | 1.0051 | 4272 | 0.000231 |
| Float64 1024×256 CD | 0.9867 | 0.9814 | 1.0364 | 0.9945 | 42008 | 4.7e-09 |
| Float64 1024×256 PGD | 0.9721 | 1.5570 | 1.2072 | 0.8057 | 27560 | 3.22e-05 |
| Float32 128×32 CD | 0.9990 | 0.9890 | 0.9829 | 1.0036 | 3888 | 1.81e-08 |
| Float32 128×32 PGD | 0.9995 | 1.0047 | 1.0211 | 1.0162 | 2512 | 0.000148 |
| Float32 1024×256 CD | 0.9877 | 0.9929 | 1.0015 | 1.0027 | 24704 | 4.49e-08 |
| Float32 1024×256 PGD | 1.0076 | 1.0041 | 0.9980 | 1.0007 | 14336 | 3.16e-05 |

The compiled campaign with component controls is in
[components/summary.json](components/summary.json) and
[components/raw.tsv.gz](components/raw.tsv.gz). The fresh-JIT campaign
(`--compiled-modules=no`) is in [fresh/summary.json](fresh/summary.json) and
[fresh/raw.tsv.gz](fresh/raw.tsv.gz). The earlier compiled confirmation is
retained in [compiled/summary.json](compiled/summary.json) and
[compiled/raw.tsv.gz](compiled/raw.tsv.gz); exploratory short-batch data are in
[exploratory/summary.json](exploratory/summary.json) and
[exploratory/raw.tsv.gz](exploratory/raw.tsv.gz). Earlier exploratory harness
versions had fewer controls; the final reproducible harness is supplied here.

Float64 PGD at 1024×256 varied substantially across processes/campaigns:
candidate/baseline ratios were 1.2138 (exploratory), 1.1135 (compiled), 0.8057
(fresh JIT) and 1.5570 (compiled with component controls). Identical old-source
workers differed by 1.2072 in the fresh-JIT run. In the final run, a separate
control times **only** 200 pairs of `mul!(z,X,x)` and
`mul!(grad,transpose(X),residual)`, without PB or PS calls in the timed block.
Across three rounds of seven samples, its median pair times were about
36.3/34.6/57.6 microseconds for A1/A2/B. The resulting B/A1 BLAS ratio near
1.59 reproduces the solver slowdown's direction and scale outside the solver.
All matrix pointers were 64-byte aligned (offset 64 modulo 4096).

These controls demonstrate process-sensitive BLAS timing. Memory/cache/code
placement is a possible explanation; the exact cause is unresolved and is not
established by pointer alignment or disabling compiled modules. Seven other
final whole-solve ratios lie between 0.9814 and 1.0050. No allocation regression
or consistent source-attributable numerical/timing change was established;
there is **no universal zero-regression or tight Float64-moderate timing claim**.
Independent review accepts the compatibility change with this explicit timing
limitation. No solver changes are justified by the outlier.

## Reproduction and review gates

Use independently fetched exact old/new PB checkouts and PS commits, create
environments with `Pkg.develop` for each source pair, and use the same resolved
non-source packages as the preserved environment A/B Project/Manifest files.
Those files record original absolute paths; replace them with the fresh
checkout locations. Do not use an unverified neighboring checkout.

```sh
export JULIA_DEPOT_PATH=/path/to/depot
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
taskset -c 2 python3 measure.py /path/to/julia /path/to/environment-A /path/to/environment-B /new/output
PS_REFRESH_COMPILED_MODULES=no taskset -c 2 python3 measure.py /path/to/julia /path/to/environment-A /path/to/environment-B /new/fresh-output
```

The final harness verifies loaded package paths, exact PB revisions, agreeing
PS pins, clean tracked sources and before/after source/harness digests. It
refuses missing worker results or numerical/stopping divergence. Raw TSVs
preserve all measured triplets, allocations and diagnostics, not just medians.
`SHA256SUMS` covers the supplied evidence files and scripts.

Normal final-head PR required checks and independent review remain merge
gates. The documentation preview must both build and publish via #244; its
URL is [PR245 preview](https://mlakolar.github.io/ProximalSolvers.jl/previews/PR245/).
Publication and final check/review links are recorded in the PR discussion.
SparseIterate support is a separate proposed restoration and is not implemented
by this compatibility PR. No release/version bump or closure of #234 follows.
