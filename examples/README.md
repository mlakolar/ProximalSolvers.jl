# Examples

The scripts here are documentation pages and tests at the same time. The documentation
build turns each registered script into a page (see `docs/make.jl`), and `test/examples.jl`
runs every `.jl` script under this folder, subfolders included. The checks of a script are
`@assert` statements, so a failed check stops the script with an error.

## How the folder is organized

- `problems/` holds one canonical tutorial per optimization problem, named after the
  problem (`lasso.jl`, `elastic_net.jl`, ...). A tutorial can solve its problem with several
  solvers, in separate sections.
- `comparisons/` holds comparisons of solvers on a problem, named `<problem>_solvers.jl`.
- Some tutorials in `problems/` are statistical applications of a supported problem rather than new problems. The documentation lists them under "Statistical applications", and they add no row to the matrix of [Supported problems](../docs/src/support.md).
- A solver is not a problem. A weighted lasso, for example, is `LeastSquaresLoss` with a
  weighted `NormL1(λ, w)`; the current solvers refuse a weighted `NormL1` (deferred, see
  [Supported problems](../docs/src/support.md)). Once the package supports it, it is
  documented under `problems/`, not as a separate solver.

A new script is registered in `docs/make.jl`, which stops with an error when a `.jl` script
under this folder is not registered or a registered script is missing. A change that adds or removes support for a combination of
problem, solver, iterate and element type also changes the matrix of
[Supported problems](../docs/src/support.md).

## The scripts

Run a script from the repository root with `julia --project=. examples/<path>`.

| File | Problem | Solvers it runs | What it checks independently |
| --- | --- | --- | --- |
| `problems/lasso.jl` | Lasso on a small orthogonal design and on a seeded correlated design | `CDSolver` on a dense `Vector` and on a `SparseIterate`; `ProximalGradientDescent`; `AccProxGradDescent` | On the orthogonal design, the closed-form soft-thresholded solution for the `CDSolver` and `ProximalGradientDescent` runs (`λ = 0.1`) and for the `SparseIterate` run (`λ = 1`); on the correlated design and for the three small solutions, a KKT residual (at most `1e-6`) computed from `X`, `y` and the coefficients; the active coordinates of the `SparseIterate` result. The `minimizer === x` assertion is made for the `CDSolver`, `ProximalGradientDescent` and `SparseIterate` runs on the orthogonal design and for the `AccProxGradDescent` run on the correlated design, not for the `ProximalGradientDescent` run on the correlated design |
| `problems/elastic_net.jl` | Elastic net on a seeded correlated design | `ProximalGradientDescent`; `AccProxGradDescent` | The KKT residual (ProximalBase's `kkt_violation` at the gradient computed from `X` and `y`); the reported objective against the objective computed from `X` and `y`; that the two solutions agree; that the elastic-net solution has a smaller Euclidean norm than the lasso solution with the same ℓ1 level |
| `problems/group_lasso.jl` | Group lasso with noncontiguous groups on a seeded design | `CDSolver` on a `BlockIterate` | A group KKT residual computed from the data; that the active groups are the groups with a nonzero block and that some but not all groups are active |
| `problems/square_root_lasso.jl` | Square-root lasso on a seeded design | `CDSolver` on a dense `Vector` and, in `Float32`, on a `SparseIterate` | For the `Float64` solve, the reported objective against the objective computed from `X`, `y`, `λ` and the coefficients; for the `Float64` solve and for the `Float32` solve on a `SparseIterate`, a relative duality gap of at most `1e-4` from a dual point computed from the same data (the script also asserts that the solver reports `converged` in both); for two small exact fits, that the solver reports no certificate (`converged = false`, `gap = NaN`) and, for the second, that a dual point gives the objective of the returned point |
| `problems/sparse_additive_regression.jl` | Sparse additive regression: a group lasso on a centered, orthonormalized piecewise-linear basis with one block per predictor, on a seeded data set | `CDSolver` on a `BlockIterate` | The block dimensions, rank and orthonormality (`ZⱼᵀZⱼ/n = I`) and the partition of the groups; at `λmax`, that `b = 0` meets the zero-group condition up to `1e-12 λ` and that the solver's blocks have norm at most `1e-12` with violations at most `1e-12 λ`, and that all `p` blocks are exactly zero at `(1 + 1e-6) λmax` and at `1.5 λmax`; at three penalty levels, the reported objective against the objective computed from `Z`, `z` and the coefficients, the profiled intercept and the original-scale objective, the group KKT residuals at most `1e-9 λ` computed from the data, that the active groups are the groups with a nonzero block, the evaluation map of the components on the training points and the reconstruction of `Z b`; that some but not all groups are active at the largest level. The selected groups on the noisy data are reported against the truth and not asserted |
| `comparisons/lasso_solvers.jl` | Lasso on a seeded correlated design | Cyclic and random-order `CDSolver`; `ProximalGradientDescent` | The reference solution (cyclic `CDSolver` at a very small tolerance): it reports `converged`, its KKT violation is at most `1e-10 λ`, and its objective agrees with the independent objective; that each solver reaches the accuracy target at some setting of its sweep |

`comparisons/lasso_solvers.jl` measures the time each solver needs to reach the same
independently measured objective gap and KKT violation. Its checks concern accuracy, and none
concerns time. Run as
a script it prints the comparison table and does not load Plots; the plot and the downloadable
notebook are produced by the documentation build, and the notebook needs Plots in its
environment. Its times are illustrative, from one machine and one run, and are not benchmark
evidence; see [Benchmarks and performance](../docs/src/benchmarks.md).

Historical feature examples remain on legacy/full and protected archives.
