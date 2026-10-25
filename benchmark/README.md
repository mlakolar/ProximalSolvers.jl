# Lasso benchmark

`lasso_bench.jl` times the solvers of ProximalSolvers on the lasso

    minimize  ‖y - Xβ‖² / (2n) + λ ‖β‖₁

against the current HighDimensionalModels API and an independent historical
CoordinateDescent 0.5.6 implementation, with glmnet (through GLMNet.jl) and
Lasso.jl as outside references.

## Running

Run inside the compute allocation, with one BLAS thread:

```sh
julia --startup-file=no benchmark/instantiate_lasso.jl
julia --startup-file=no benchmark/test_lasso_legacy_client.jl
julia --startup-file=no --project=benchmark benchmark/lasso_bench.jl --smoke
julia --startup-file=no --project=benchmark benchmark/lasso_bench.jl --quick
julia --startup-file=no --project=benchmark benchmark/lasso_bench.jl
julia --startup-file=no --project=benchmark benchmark/lasso_summary.jl
```

`test_lasso_legacy_client.jl` is a short stdlib-only check of normal shutdown,
failed handshakes, and cleanup after a closed worker input pipe.

`--smoke` is a bounded end-to-end check on an 80 × 120 design: one tolerance,
four penalty levels, and one timed repetition. It checks every single/default
and path solver, the coefficient dimensions, finite objectives, the reference
KKT residual, and the fitted KKT residuals at the requested tolerance. A solver
error or truncated path makes it fail. Its timing is a plumbing check.
`--quick` keeps the original 300 × 1000 problem and tolerance sweep; the full
run uses the five designs below and can take 1.5 to 3.5 hours.

The run writes `benchmark/results/single.csv` and `path.csv`, which
`lasso_summary.jl` turns into the tables below. Set `PROXIMAL_LASSO_OUT` to
write a check into a separate output directory.

The two environments are intentionally separate. `benchmark/Project.toml`
loads local master checkouts of ProximalSolvers, ProximalBase, and
HighDimensionalModels, together with GLMNet and Lasso. The package formerly
named CoordinateDescent is now HighDimensionalModels; its UUID is unchanged.
`benchmark/legacy_cd/Project.toml` retains the independent historical baseline
CoordinateDescent 0.5.6 and ProximalBase 0.4.0. That frozen comparison uses its
original environment and does not participate in the master development stack.

`instantiate_lasso.jl` prepares both and requires Julia 1.10.8 or later
(`[sources]` needs explicit setup on 1.10). It maintains separate native
`Manifest-v1.10.toml`, `Manifest-v1.13.toml`, etc. locks in each environment,
so rerun setup when switching Julia minor versions. Existing versioned locks
are reused. An existing shared `Manifest.toml` seeds the new lock when its
Julia minor matches; otherwise it is preserved and the new runtime resolves
its own lock from `Project.toml`. This avoids incompatible Statistics entries
when switching runtimes without updating the other runtime's locked packages.
The development paths are sibling master checkouts. The setup script uses the
same recursive master bootstrap as the package and explicitly develops the
current packages together, including on Julia 1.10.

The historical baseline runs in one persistent Julia child process with one BLAS thread.
Each generated design, response, and Gram matrix is serialized to it once,
so it uses the same actual data as the current solvers. Timing is performed
inside that worker after a warm-up call: startup, compilation, serialization,
and IPC are excluded from the solver times. Both package versions and the
runtime/BLAS configuration are printed. The full run still records errors
and unattained accuracy targets as before; `--smoke` makes errors fatal.
Set `PROXIMAL_LEGACY_CD_PROJECT` to use another checkout of the same pinned
historical environment.
Do not point it at the current HighDimensionalModels package, which delegates to
the current solver and would change the independence of the baseline.

Rows labeled `CD 0.5.6` use that historical worker. Rows labeled `CD 0.8` use
the modern package's `snake_case` API in the main process; the CSV package
column and startup log record its exact version. HighDimensionalModels
delegates to ProximalSolvers, so those rows measure its current API and path
handling rather than an independent optimization engine. Both sets use the
same generated data and reproducible random coordinate orders. The reference
solution remains the independent historical fit. The smoke check compares row
identities with the solver lists, including both versions.

## What is measured

Every solver minimizes the same objective, without an intercept or
standardization. The designs have Gaussian columns scaled so that
`‖X[:, k]‖² = n`, `s` nonzero coefficients ±1 at random positions, and noise
with a signal-to-noise ratio of 4.

| design | n | p | s | correlation between columns |
|---|---:|---:|---:|---|
| A | 500 | 2,500 | 50 | none |
| B | 500 | 2,500 | 50 | AR(1), 0.8 between neighbors |
| C | 5,000 | 500 | 50 | AR(1), 0.5 between neighbors |
| D | 1,000 | 20,000 | 20 | none |
| E | 500 | 2,500 | 50 | 0.5 between every pair (a common factor) |

- **One λ** (0.1 λmax and 0.02 λmax), starting from β = 0.
  - Each solver runs over a sweep of its tolerance, from 1e-1 to 1e-16.
  - Each run records its time and its relative suboptimality `(F - F*) / F*`.
  - The tables give the time of the cheapest run that reaches the target.
  - `F*` comes from the isolated historical coordinate descent run to `optTol = 1e-14`; the smoke check verifies its KKT residual.
- **Defaults**: each package with its default options.
- **Path**: 50 λ values from λmax to λmax/100, each warm started from the previous solution. The tables give the time until every λ is within the target.
- **Timing**: each time is the minimum of at least three runs, with one BLAS thread.

The solvers:

| row | what runs |
|---|---|
| CD 0.5.6 random, cyclic, path from λmax, X'X/n | Historical `coordinateDescent!`, with `randomize` and `warmStart`, on residuals or the supplied Gram matrix |
| CD 0.8 random, CD 0.8 cyclic | `coordinate_descent!` with `order = :random` or `:cyclic` |
| CD 0.8 path from λmax | `coordinate_descent!` with `warm_start = false`, solving along a path of 50 penalties |
| CD 0.8 X'X/n | `coordinate_descent!` on `CDQuadraticLoss(X'X/n, -X'y/n)` |
| CD 0.5.6 LassoPath, CD 0.8 LassoPath | Each package's `LassoPath`; 0.8 keeps its automatic Gram choice and includes any construction in the timed call |
| ProxGrad, AccProxGrad, ActiveAccProxGrad | the solvers of this package on `LeastSquaresLoss` |
| AccProxGrad X'X/n, ActiveAccProxGrad X'X/n | the same on `QuadraticFunction(X'X/n, -X'y/n)` |
| glmnet, Lasso.jl | `GLMNet.glmnet` and `Lasso.fit(LassoPath, ...)` |

## Results

These historical results are from 22 October 2026, on one core of an AMD EPYC 7513 (a
compute node of USC's Discovery cluster) with Julia 1.13.2 and one BLAS
thread. They predate the isolated-worker repair and use CoordinateDescent 0.5.1 rather than the now-pinned 0.5.6 baseline. They contain no modern CoordinateDescent 0.8 measurements. The full run took 76 minutes. Package versions:

- this package, then called ProximalOPT, at `8674288`
- ProximalBase 0.4.0
- CoordinateDescent 0.5.1
- GLMNet.jl 0.7.4
- Lasso.jl 0.7.5

### One λ: milliseconds to a relative suboptimality of 1e-6

| solver | A, 0.1 | A, 0.02 | B, 0.1 | B, 0.02 | C, 0.1 | C, 0.02 | D, 0.1 | D, 0.02 | E, 0.1 | E, 0.02 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| CD cyclic | 3.0 | 127 | 3.8 | **65.0** | 1.6 | 8.0 | **33.0** | **290** | 1.9 | 220 |
| CD random | 4.0 | 167 | 7.7 | 167 | 1.8 | 5.6 | 40.7 | 368 | 0.9 | **13.8** |
| CD path from λmax | 14.5 | 271 | 35.5 | 435 | 26.7 | 54.7 | 238 | 750 | 8.4 | 36.9 |
| CD X'X/n | 16.7 | 358 | 17.5 | 331 | 0.2 | **0.6** | – | – | 5.1 | 45.5 |
| ProxGrad | 31.1 | 545 | 93.3 | 594 | 13.0 | 23.8 | 770 | 12594 | 95.8 | 3766 |
| AccProxGrad | 49.0 | 195 | 81.2 | 246 | 21.4 | 25.4 | 2066 | 8438 | 304 | 1465 |
| ActiveAccProxGrad | 6.0 | 75.5 | 7.5 | 95.4 | 4.8 | 19.2 | 38.8 | 310 | 2.5 | 82.8 |
| AccProxGrad X'X/n | 252 | 1004 | 431 | 1332 | 1.5 | 1.9 | – | – | 1604 | 8021 |
| ActiveAccProxGrad X'X/n | **2.2** | **54.5** | **2.6** | 70.3 | **0.1** | 1.0 | – | – | **0.5** | 58.0 |
| glmnet | 29.1 | 1423 | 38.2 | 1226 | 15.1 | 44.2 | 143 | 4837 | 19.8 | 3618 |
| Lasso.jl | 119 | 564 | 133 | 568 | 49.9 | 95.2 | 35.0 | 673 | 18.6 | 187 |
| nonzeros in the solution | 278 | 452 | 221 | 424 | 54 | 227 | 333 | 865 | 40 | 302 |

Column headings give the design and λ/λmax. Bold marks the fastest row in each
column. The X'X/n rows do not include forming X'X/n, which takes 131 ms for A,
83 ms for B, 27 ms for C and 75 ms for E; for D it would need 3.2 GB of memory.
`lasso_summary.jl` also prints the table for a relative suboptimality of 1e-10.

### Path of 50 λ values: seconds until every λ is within the target

| solver | A, 1e-6 | B, 1e-6 | C, 1e-6 | D, 1e-6 | E, 1e-6 | A, 1e-10 | B, 1e-10 | C, 1e-10 | D, 1e-10 | E, 1e-10 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| CD LassoPath | 0.59 | 0.79 | 0.08 | **1.2** | **0.08** | 3.2 | 2.7 | 0.18 | 5.1 | 0.45 |
| CD X'X/n | 3.6 | 1.6 | 0.03 | – | 0.32 | 14.2 | 6.6 | **0.04** | – | 0.98 |
| ProxGrad | 6.9 | 10.3 | 0.41 | ✗ | ✗ | ✗ | ✗ | 0.87 | ✗ | ✗ |
| AccProxGrad | 0.96 | 1.3 | 0.50 | 27.9 | 6.1 | 3.4 | 5.3 | 0.94 | ✗ | ✗ |
| ActiveAccProxGrad | **0.20** | **0.25** | 0.24 | 1.2 | 0.65 | **0.71** | **0.98** | 0.45 | **3.9** | ✗ |
| ActiveAccProxGrad X'X/n | 0.34 | 0.26 | **0.03** | – | 0.39 | ✗ | ✗ | 0.04 | – | ✗ |
| glmnet | 2.0 | 1.7 | 0.32 | 2.7 | 1.8 | ✗ | ✗ | 0.54 | ✗ | ✗ |
| Lasso.jl | 0.55 | 0.77 | 0.09 | 2.0 | 0.13 | ✗ | 2.6 | 0.10 | 6.5 | **0.34** |

Here the X'X/n rows include forming X'X/n. ✗ means the target was not reached
within the sweep: tolerances down to 1e-14, or 90 seconds per solver.

### Default settings at λ = 0.02 λmax

| solver | A: relative gap | A: support errors | E: relative gap | E: support errors |
|---|---:|---:|---:|---:|
| CD `lasso()` | 3.8e-10 | 0 | 1.1e-11 | 0 |
| ProxGrad | 2.0e-3 | 89 | 0.35 | 916 |
| AccProxGrad | 9.4e-5 | 24 | 0.097 | 709 |
| ActiveAccProxGrad | 3.3e-5 | 18 | 1.3e-4 | 11 |
| glmnet | 9.0e-4 | 66 | 3.6e-4 | 24 |
| Lasso.jl | 3.2e-5 | 16 | 1.4e-6 | 1 |

A support error is a coefficient that is zero in one solution and nonzero in
the other. The solution has 452 nonzeros for A and 302 for E.
`lasso_summary.jl` prints all the default-settings tables.

## What the numbers say

- **For one λ, coordinate descent is usually fastest, with `ActiveAccProxGradDescent` close behind.**
  - At a relative gap of 1e-6, coordinate descent beats `ActiveAccProxGrad` by 1.1–3.4× on designs A–D. The exception is A at 0.02 λmax, where `ActiveAccProxGrad` is 1.7× faster (75.5 against 127 ms).
  - On the equicorrelated design E, coordinate descent is 2.9–6× faster than `ActiveAccProxGrad` and over 100× faster than `AccProxGrad`. There the common factor gives X'X/n one very large eigenvalue, which forces the gradient methods of this package to take small steps; the active set keeps those steps cheap.
- **For a path, `ActiveAccProxGradDescent` is fastest when p > n and the columns are not strongly correlated.**
  - On A and B it beats `LassoPath` by about 3× at a gap of 1e-6, and by 2.8–4.5× at 1e-10.
  - On D (p = 20,000) the two are even at 1e-6 (1.2 s each), and `ActiveAccProxGrad` is faster at 1e-10 (3.9 s against 5.1 s).
  - On E it is the other way round: `LassoPath` is 8× faster at 1e-6, and `ActiveAccProxGrad` does not reach 1e-10.
- **When n ≫ p (design C), solve on X'X/n.** `CD X'X/n` and `ActiveAccProxGrad X'X/n` compute the whole path in 0.03 s, including forming X'X/n.
- **Among the gradient solvers of this package, use `ActiveAccProxGradDescent`.**
  - `AccProxGrad` without the active set is up to 123× slower at one λ (304 against 2.5 ms for E at 0.1 λmax), and 23× slower on the path for D (27.9 s against 1.2 s).
  - `ProxGrad` is competitive only at low accuracy on easy problems.
  - The X'X/n variants pay off when n ≫ p, or when X'X/n is already at hand. At one λ, `ActiveAccProxGrad X'X/n` is the fastest row in 5 of the 8 columns where it runs, not counting the 27–131 ms it takes to form X'X/n.
- **Coordinate order matters for coordinate descent.**
  - Cyclic order beats random order in 7 of the 8 cases on A–D, by up to 2.6×.
  - On E cyclic order is 16× slower (220 against 13.8 ms), which is why random order is CoordinateDescent's default.
- **The default options stop early on harder problems.** The defaults are `maxiter = 200` and `ftol = 1e-6`.
  - At 0.02 λmax on A, B and D its solvers stop with relative gaps of 2e-5 to 4e-3 and 12 to 248 support errors.
  - On E, `ProxGrad` and `AccProxGrad` stop with gaps of 0.35 and 0.1 and most of the support wrong; `ActiveAccProxGrad` stops at 1.3e-4 with 11 support errors.
  - For accurate solutions, set `ftol`, `xtol` and `gradtol` to about 1e-10 and raise `maxiter`.
  - CoordinateDescent's defaults reach gaps of 4e-10 or smaller, with no support errors, in every case.
- **glmnet's tolerance is on a different scale.** Its `tol` bounds squared changes in the coefficients, so reaching a gap of 1e-6 at every λ of a path needs a `tol` of about 1e-11. That makes it slow in these tables. At its default `tol`, its paths take a fraction of these times but are only accurate to about 1e-3.
