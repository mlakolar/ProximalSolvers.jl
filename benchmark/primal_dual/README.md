# Primal–dual splitting: accuracy and allocation checks

This separate environment compares native `CondatVu` with ProximalAlgorithms
0.7 through `benchmark/proxalg/adapter.jl`. JuMP, HiGHS, ProximalAlgorithms
and ProximalCore are benchmark/oracle dependencies only.

## Reproduce

Instantiate this environment against this checkout and the ProximalBase
companion pinned in `Project.toml`. On Julia 1.10, which ignores `[sources]`,
`Pkg.develop` both checkouts explicitly before instantiating.

```sh
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  julia --project=benchmark/primal_dual -e 'using Pkg; Pkg.instantiate()'
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  julia --project=benchmark/primal_dual benchmark/primal_dual/run.jl
```

`PD_OUT` selects the results directory; `PD_MAXTIME` defaults to 15 seconds
per iterative solve. `PD_ORACLE_ONLY=true` runs only the independent LP/QP
checks. Those checks also run directly with
`julia --project=test/oracles test/oracles/primal_dual.jl`.

## Method

- Quantile ℓ1 regression: `(n,p) = (500,100), (2000,200)`, quantile 0.5,
  Gaussian designs with column squared norms `n`, five planted coefficients
  equal to one, and Gaussian noise. `λ = 0.1 λmax`. Each uses
  `MersenneTwister(23+n+p)`. The reference is an independently modeled HiGHS LP.
- Chain TV: `n = 1000, 10000`, ten random constant levels plus Gaussian noise
  of standard deviation 0.5, `λ = 1`, and a sparse first-difference matrix.
  Each uses `MersenneTwister(23+n)`. The reference is `TotalVariation1D`'s direct
  proximal operator.
- Both libraries use the same relative Fenchel gap, checked every 25 iterations:
  `1e-6` for quantile regression and `1e-8` for TV. A 15-second or one-million
  iteration limit is recorded as nonconvergence even if the primal objective
  already agrees closely with the reference.
- Native fixed steps and ProximalAlgorithms use identical step pairs. Native
  adaptation starts with that same pair. The quantile spectral norm is computed
  once by dense SVD outside all iterative timings; TV uses the analytic bound
  `norm_d = 2`. Data generation and reference solutions are also outside those
  timings. HiGHS timings include model construction and optimization.
- Exact keyword-call signatures, iterations and scheduled gap checks are warmed
  before timing. These are single exploratory timings,
  not estimates across machines or repeated sampling.
- Native iteration bytes measure the warmed `_pd_step!` kernel, excluding setup,
  results, tracing, restarts and occasional gap checks. The unit tests cover
  Float32/Float64, dense/sparse matrices and dense/`SparseIterate` primals on
  Julia 1.10 and current Julia using a function barrier. ProximalAlgorithms'
  per-iteration bytes are the allocation difference between 200 and 100 forced
  iterations, with its ordinary adapter and no gap checks.

`comparison.csv` records objective error, the actual relative gap, convergence,
coefficient and dual errors where an LP supplies them, and iteration bytes.
The stricter oracle tests compare three fixed quantiles at `gaptol = 1e-9`,
including sparse designs, and compare a second-difference generalized lasso
with an independent HiGHS quadratic program. The ordinary tests also compare
TV with accelerated proximal gradient using its direct TV prox.

## Discovery run

Run `20261024T1940Z-ps-issue23` uses one EPYC 7513 core, one BLAS thread,
Julia 1.13.2 and 1.10.12. Source revisions, job scripts, environment manifests,
logs and the lightweight run record are retained under the corresponding
project `.slurm/runs` entry and Discovery run directory.

The reported timings are job `13383190`, benchmark source `ce84a0d`, solver
source `d65e540`, and ProximalBase `1f93b03`. Job `13383043` passed the complete
Julia 1.10 suite, final focused tests, both LP/QP oracle sets, and documentation;
the preceding job passed the full Julia 1.13 suite. The implementation also
passes GitHub CI on current/LTS Linux Julia, macOS and Windows.

| Problem | Size | Native fixed | Native adaptive + restarts | ProximalAlgorithms | Reference |
|:--|:--|--:|--:|--:|--:|
| Quantile ℓ1 | 500 × 100 | 461 ms | 38.8 ms | 897 ms | 114 ms |
| Quantile ℓ1 | 2000 × 200 | 6.66e+03 ms | 381 ms | 1.28e+04 ms | 956 ms |
| TV | 1000 | 17.2 ms | 5.03 ms | 27.7 ms | 0.0169 ms |
| TV | 10000 | 571 ms | 81.2 ms | 853 ms | 0.194 ms |

All iterative runs reach their selected gap target. At identical fixed steps,
both implementations take the same iterations (quantile: 35,975 and 69,225;
TV: 1,525 and 4,850), with matching objectives to rounding. Native adaptation reduces these to 2,825 and 3,575 for quantile
regression, and 350 and 550 for TV.

Ordinary native kernels allocate **0 bytes** in both Julia versions. The
ProximalAlgorithms adapter allocates about **9–240 KB per iteration** here.
This and the native stopping rules, sparse setup, dual warm starts and
adaptation supply the structural reasons requested in issue #23. The direct
chain TV prox remains much faster than either iterative solver.

These quantile results use a known spectral norm and the stated gap target;
they do not establish superiority to LPs including norm setup, across other
designs, or at LP-level accuracy. The LP uses feasibility tolerances `1e-9`.
The small independent oracle tests give maximum coefficient and dual errors
of 9.17e-09 and 3.32e-11 for quantile regression; the generalized-lasso
coefficient difference is at most `1.5e-8` on the two Julia versions.

Raw results: [discovery-20261024.csv](discovery-20261024.csv). Reference rows
use zero iteration/iteration-byte diagnostics as placeholders; those fields
are not measurements of the LP's iterations or the direct prox's allocations.
The first timing pass is retained in the run receipts; the final pass above
warms the exact call signatures and scheduled checks before measurement.
