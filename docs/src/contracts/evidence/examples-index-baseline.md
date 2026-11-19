# [Historical example index](@id EVIDENCE-EXAMPLES-01)

**Statement.**

This page archives `examples/README.md` from the documentation baseline
`a6293e6ff7e654a87babbc5de2314205be13d6c5`. The text below describes the scripts
and checks at that revision. Its original paragraphs, headings, table rows and
numerical qualifications are preserved; only the relative links to Supported
problems and Benchmarks and performance have been adjusted for this page's location.
Paths such as `problems/lasso.jl` in the archive refer to the historical `examples/`
directory.

The [upstream gallery and tutorial update (#417)](https://github.com/mlakolar/ProximalSolvers.jl/commit/1754dce716bff78faf425f211a6aafd8588be77a)
supersedes these descriptions where it revises the example index or tutorial
checks. The current [Examples Gallery](../../examples/index.md) and repository
`examples/README.md` describe the integrated tutorials. The historical statements
below are retained as migration evidence, not as new assertions about current
script behavior or newly executed tests.

The immutable baseline continues to record the identities and hashes of its
14 original scripts. Integration preservation checks compare the current 19
scripts with the accepted upstream integration snapshot. That separate check
preserves the upstream tutorial changes without replacing the original historical
script inventory.

**Applies to.** Historical example descriptions and independent-check claims at the frozen documentation baseline.

**Code.** Baseline `examples/README.md`; current registration and execution remain in `docs/make.jl` and `test/examples.jl`. Migration inventory and integration-script checks are in `scripts/docs_ledger.py` and `scripts/check_docs_layers.py`.

**Tests.** Archive completeness is checked against all 28 original example-index blocks, allowing only the two recorded relative-link target adjustments. This archive makes no new solver accuracy or performance claim.

**Sources.** [Original index at a6293e6](https://github.com/mlakolar/ProximalSolvers.jl/blob/a6293e6ff7e654a87babbc5de2314205be13d6c5/examples/README.md); `examples/README.md:L1`, `examples/README.md:L3`, `examples/README.md:L8`, `examples/README.md:L10`, `examples/README.md:L13`, `examples/README.md:L14`, `examples/README.md:L15`, `examples/README.md:L20`, `examples/README.md:L25`, `examples/README.md:L27`, `examples/README.md:L29`, `examples/README.md:L30`, `examples/README.md:L31`, `examples/README.md:L32`, `examples/README.md:L33`, `examples/README.md:L34`, `examples/README.md:L35`, `examples/README.md:L36`, `examples/README.md:L37`, `examples/README.md:L38`, `examples/README.md:L39`, `examples/README.md:L40`, `examples/README.md:L41`, `examples/README.md:L42`, `examples/README.md:L43`, `examples/README.md:L44`, `examples/README.md:L46`, `examples/README.md:L56`.

---

The historical source follows in full.

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
- Some tutorials in `problems/` are statistical applications of a supported problem rather than new problems. The documentation lists them under "Statistical applications", and they add no row to the matrix of [Supported problems](../../support.md).
- A solver is not a problem. A weighted lasso, for example, is `LeastSquaresLoss` with a
  weighted `NormL1(λ, w)`. `CDSolver`, `ProximalGradientDescent` and `AccProxGradDescent`
  support it (see [Supported problems](../../support.md)), and it is documented in
  `problems/weighted_lasso.jl`, not as a separate solver.

A new script is registered in `docs/make.jl`, which stops with an error when a `.jl` script
under this folder is not registered or a registered script is missing. A change that adds or removes support for a combination of
problem, solver, iterate and element type also changes the matrix of
[Supported problems](../../support.md).

## The scripts

Run a script from the repository root with `julia --project=. examples/<path>`.

| File | Problem | Solvers it runs | What it checks independently |
| --- | --- | --- | --- |
| `problems/lasso.jl` | Lasso on a small orthogonal design and on a seeded correlated design | `CDSolver` on a dense `Vector` and on a `SparseIterate`; `ProximalGradientDescent`; `AccProxGradDescent` | On the orthogonal design, the closed-form soft-thresholded solution for the `CDSolver` and `ProximalGradientDescent` runs (`λ = 0.1`) and for the `SparseIterate` run (`λ = 1`); on the correlated design and for the three small solutions, a KKT residual (at most `1e-6`) computed from `X`, `y` and the coefficients; the active coordinates of the `SparseIterate` result. The `minimizer === x` assertion is made for the `CDSolver`, `ProximalGradientDescent` and `SparseIterate` runs on the orthogonal design and for the `AccProxGradDescent` run on the correlated design, not for the `ProximalGradientDescent` run on the correlated design |
| `problems/weighted_lasso.jl` | Weighted lasso on a seeded design, with adaptive weights from a ridge pilot fit and one zero weight (an unpenalized coefficient) | `CDSolver` on a dense `Vector`; `ProximalGradientDescent`; `AccProxGradDescent` | For each of the three solutions, a weighted KKT residual (at most `1e-6`) computed from `X`, `y`, `λ`, the weights and the coefficients, and the reported objective against the objective computed from the same data; that the three solutions agree (within `1e-5`); that `minimizer === x` for each run; that the unpenalized coefficient is nonzero; that the weights keep fewer nonzero coefficients than the unweighted lasso with the same `λ`; that weights of another element type are refused before `x` is touched |
| `problems/elastic_net.jl` | Elastic net on a seeded correlated design | `ProximalGradientDescent`; `AccProxGradDescent`; `CDSolver` on a dense `Vector` and on a `SparseIterate` | For each solution, the KKT residual (ProximalBase's `kkt_violation` at the gradient computed from `X` and `y`) and the reported objective against the objective computed from `X` and `y`; that the `ProximalGradientDescent` solution and both `CDSolver` solutions agree with the `AccProxGradDescent` solution; that the elastic-net solution has a smaller Euclidean norm than the lasso solution with the same ℓ1 level |
| `problems/group_lasso.jl` | Group lasso with noncontiguous groups on a seeded design | `CDSolver` on a `BlockIterate`; `ProximalGradientDescent` and `AccProxGradDescent` on a dense `Vector` | For each solution, a group KKT residual computed from the data (at most `1e-7`); that the active groups of the `CDSolver` run are the groups with a nonzero block and that some but not all groups are active; that the `ProximalGradientDescent` run reports `converged`, has the zero groups of the `CDSolver` solution and agrees with it (within `1e-6`); that the `AccProxGradDescent` run reports `converged` and agrees with it (within `1e-6`) |
| `problems/square_root_lasso.jl` | Square-root lasso on a seeded design | `CDSolver` on a dense `Vector` and, in `Float32`, on a `SparseIterate` | For the `Float64` solve, the reported objective against the objective computed from `X`, `y`, `λ` and the coefficients; for the `Float64` solve and for the `Float32` solve on a `SparseIterate`, a relative duality gap of at most `1e-4` from a dual point computed from the same data (the script also asserts that the solver reports `converged` in both); for two small exact fits, that the solver reports no certificate (`converged = false`, `gap = NaN`) and, for the second, that a dual point gives the objective of the returned point |
| `problems/linf_regularized_regression.jl` | Least squares with an ℓ∞ penalty (`NormLinf(λ)`): an analytic case (`X = [1 1]`, `y = [2]`, `λ = 1`) and a seeded correlated design (`n = 200`, `p = 40`) at a fraction of `λcrit = ‖∇f(0)‖₁` | `ProximalGradientDescent`; `AccProxGradDescent` (`CDSolver` refuses `NormLinf`) | For the analytic case, the minimizer `(0.75, 0.75)` and the value `0.875` of both solvers; for the seeded design, the reported objective against the objective computed from `X` and `y`, a duality gap (computed from `X`, `y` and the coefficients, at most `1e-8` of the objective, and not below zero by more than `1e-12`) that the solvers report `converged` and agree to `1e-3`, and that in this problem no coefficient is zero and at least two sit at the largest magnitude |
| `problems/sparse_covariance_soft_thresholding.jl` | Covariance thresholding (Rothman, Levina and Zhu, 2009) of a seeded sample covariance: the diagonal is left unpenalized and the off-diagonal entries are soft-thresholded with ProximalBase's `prox` of `NormL1`, which solves the reduced problem in closed form; the estimate is stored in a `SymmetricSparseIterate` | None: no solver is used | The thresholded vector against the closed-form soft threshold, the symmetry and the diagonal of the estimate, that some off-diagonal entries are zero and that the smallest eigenvalue is negative |
| `problems/scaled_lasso.jl` | Scaled lasso (Sun and Zhang, 2012) from the square-root lasso solution on the seeded design of the square-root page: `σ̂ = norm(y - X*β̂)/sqrt(n)` | `CDSolver` on a dense `Vector` | That the solver reports `converged` and a gap of at most `1e-4`; that the residual is nonzero and `σ̂` finite and positive; that the joint objective at `σ̂` equals the reported objective divided by `sqrt(n)` (within `1e-10` relative) and is larger at `0.9σ̂` and `1.1σ̂`; for the exact-fit case of the square-root page, that the run reports no certificate (`converged = false`, `gap = NaN`), that the residual is zero, and that the joint objective at that point decreases strictly along the decreasing values `σ = 1, 0.1, 0.01, 0.001` and stays above `λ₀‖β‖₁` at each of them |
| `problems/change_point_detection.jl` | Total-variation denoising of a piecewise-constant signal, as a lasso on a step design, on small noiseless examples and on one seeded simulated data set | `CDSolver` on a dense `Vector` | For each fit, the reconstruction `mean(y) + Xθ` against `a·1 + Dθ` and `diff(μ)` against `θ` (at most `1e-12`), the original total-variation objective against the lasso objective at the same fit (within `1e-12` times the larger of one and the objective), and a KKT residual (at most `1e-9 λ`) computed from `X`, `z` and `λ`; at `λmax` a zero KKT residual of `θ = 0` computed from the data and, for the solver output there, a bound of `1e-12` on the coefficients and on the KKT residual (relative to `λmax`); at `(1 + 1e-6) λmax` and `2 λmax` an exact zero `θ` and a fit equal to the constant `mean(y)`; on two noiseless examples, the closed-form segment levels (at most `1e-8`) and the places of the nonzero jumps. The noisy data set has no assertion on the detected change points |
| `problems/nodewise_gaussian_graph.jl` | Gaussian graph by neighborhood selection: one lasso per variable on a seeded sample, with a chain-plus-one-edge precision matrix | `CDSolver` on a dense `Vector`, once per variable | For each of the `p` nodes, the KKT residual computed from that node's data (at most `1e-8 λ`) and the reported objective against the objective computed from the data; at `1.01 λmax,j` all coefficients are zero and at `0.9 λmax,j` some are not; an orthogonal-column control against the closed-form soft threshold, with the selected coefficients mapped to the original variable numbers; the sampling convention and the sample covariance against `Σ`; zero diagonal, symmetry of the OR and AND graphs, AND ⊆ OR and the edge counts. The edge recovery is printed, not asserted |
| `problems/sparse_additive_regression.jl` | Sparse additive regression: a group lasso on a centered, orthonormalized piecewise-linear basis with one block per predictor, on a seeded data set | `CDSolver` on a `BlockIterate` | The block dimensions, rank and orthonormality (`ZⱼᵀZⱼ/n = I`) and the partition of the groups; at `λmax`, that `b = 0` meets the zero-group condition up to `1e-12 λ` and that the solver's blocks have norm at most `1e-12` with violations at most `1e-12 λ`, and that all `p` blocks are exactly zero at `(1 + 1e-6) λmax` and at `1.5 λmax`; at three penalty levels, the reported objective against the objective computed from `Z`, `z` and the coefficients, the profiled intercept and the original-scale objective, the group KKT residuals at most `1e-9 λ` computed from the data, that the active groups are the groups with a nonzero block, the evaluation map of the components on the training points and the reconstruction of `Z b`; that some but not all groups are active at the largest level. The selected groups on the noisy data are reported against the truth and not asserted |
| `problems/multitask_group_lasso.jl` | Multi-task regression with shared row sparsity: `(1/(2n))‖Y − XB‖²_F + λ√K Σⱼ‖B[j, :]‖₂` on a seeded data set with `K = 3` tasks, with the matrix response `Y` and one group per row of `B` (`j:p:p*K` in `vec(B)`) | `CDSolver` on a dense `Matrix` coefficient | That the groups partition the entries of `B`, group `j` is row `j` and the penalty with the default weights is `λ√K Σⱼ‖B[j, :]‖₂`; `minimizer === B`; the reported objective against the matrix objective computed from `X`, `Y` and `B̂`; the row KKT residuals (at most `1e-6 λ`) computed from `X`, `Y` and `B̂`; that some but not all rows are selected and each selected row is nonzero in every task; that `B = 0` meets the zero-row condition at `λmax = maxⱼ‖(XᵀY)[j, :]‖/(n√K)`, and on a tiny seeded control that all coefficients are exactly zero at `(1 + 1e-6) λmax` and `2 λmax` and some row is nonzero at `0.9 λmax`. The selected rows on the noisy data are reported against the truth and not asserted |
| `comparisons/lasso_solvers.jl` | Lasso on a seeded correlated design | Cyclic and random-order `CDSolver`; `ProximalGradientDescent` | The reference solution (cyclic `CDSolver` at a very small tolerance): it reports `converged`, its KKT violation is at most `1e-10 λ`, and its objective agrees with the independent objective; that each solver reaches the accuracy target at some setting of its sweep |
| `comparisons/group_lasso_solvers.jl` | Group lasso with noncontiguous groups on a seeded correlated design | Cyclic `CDSolver` on a `BlockIterate`; `ProximalGradientDescent` and `AccProxGradDescent` on a dense `Vector` | The reference solution (cyclic `CDSolver` at a very small tolerance): it reports `converged` and its group KKT violation is at most `1e-10 λ`; that each solver reaches the accuracy target (objective gap and group KKT violation computed from the data) at some setting of its sweep |

`comparisons/lasso_solvers.jl` measures the time each solver needs to reach the same
independently measured objective gap and KKT violation. Its checks concern accuracy, and none
concerns time. Run as
a script it prints the comparison table and does not load Plots; the plot and the downloadable
notebook are produced by the documentation build, and the notebook needs Plots in its
environment. Its times are illustrative, from one machine and one run, and are not benchmark
evidence; see [Benchmarks and performance](../../benchmarks.md).
`comparisons/group_lasso_solvers.jl` does the same for the group lasso, with a table and no plot
or notebook; its times are illustrative in the same sense.

Historical feature examples remain on legacy/full and protected archives.
