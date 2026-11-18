# Examples

The scripts here are documentation pages and tests at the same time. The documentation
build turns each script into a page (see `docs/make.jl`), and `test/examples.jl` runs every
script under this folder, subfolders included. A script ends normally only if its own
checks pass.

## How the folder is organized

- `problems/` holds one canonical tutorial per optimization problem, named after the
  problem (`lasso.jl`, `elastic_net.jl`, ...). A tutorial can solve its problem with several
  solvers, in separate sections.
- `comparisons/` holds comparisons of solvers on a problem, named `<problem>_solvers.jl`.
- A solver is not a problem. A weighted lasso, for example, is `LeastSquaresLoss` with
  `NormL1(λ, w)`, solved by the existing solvers; once the package supports it, it is
  documented under `problems/`, not as a separate solver.

A new script is registered in `docs/make.jl`, which stops with an error when a script under
this folder is not registered. A change that adds or removes support for a combination of
problem, solver, iterate and element type also changes the matrix of
[Supported problems](../docs/src/support.md).

## The scripts

Run a script from the repository root with `julia --project=. examples/<path>`.

| File | Problem | Solvers it runs | What it checks independently |
| --- | --- | --- | --- |
| `problems/lasso.jl` | Lasso on a small orthogonal design and on a seeded correlated design | `CDSolver` on a dense `Vector` and on a `SparseIterate`; `ProximalGradientDescent`; `AccProxGradDescent` | The closed-form soft-thresholded solution of the orthogonal problem; a KKT residual computed from `X`, `y` and the coefficients; that each result's `minimizer` is the iterate passed in and that the active coordinates of the `SparseIterate` are those expected |
| `problems/elastic_net.jl` | Elastic net on a seeded correlated design | `ProximalGradientDescent`; `AccProxGradDescent` | The objective from `X` and `y`; the KKT residual (ProximalBase's `kkt_violation` at the gradient computed from `X` and `y`); that the elastic-net solution has a smaller Euclidean norm than the lasso solution with the same ℓ1 level |
| `problems/group_lasso.jl` | Group lasso with noncontiguous groups on a seeded design | `CDSolver` on a `BlockIterate` | A group KKT residual computed from the data; which groups are active |
| `problems/square_root_lasso.jl` | Square-root lasso on a seeded design | `CDSolver` on a dense `Vector` and, in `Float32`, on a `SparseIterate` | The objective and a residual-direction duality gap computed from `X`, `y`, `λ` and the coefficients, not the solver's `converged` flag; two small exact fits, on which the solver reports no certificate |
| `comparisons/lasso_solvers.jl` | Lasso on a seeded correlated design | Cyclic and random-order `CDSolver`; `ProximalGradientDescent` | The time each solver needs to reach the same independently measured objective gap and KKT violation; the reference solution (cyclic coordinate descent at a very small tolerance); that each solver reaches the target at some setting of its sweep |

The checks of `comparisons/lasso_solvers.jl` concern accuracy, and none concerns time. Run as
a script it prints the comparison table and does not load Plots; the plot and the downloadable
notebook are produced by the documentation build, and the notebook needs Plots in its
environment. Its times are illustrative, from one machine and one run, and are not benchmark
evidence; see [Benchmarks and performance](../docs/src/benchmarks.md).

Historical feature examples remain on legacy/full and protected archives.
