# Migrating to this release

This page lists the changes from the previous development version (the
`master` branch before this release). Version 0.1.0 in the General registry
predates this API; start from [Getting started](@ref) instead.

This release needs ProximalBase 0.5.3 or later.

## Renamed and removed

| Before | Now |
|---|---|
| `ProximalOptions(; printEvery = k)`, `options.printEvery` | `print_every` |
| `CondatVu(; normD = c)`, `method.normD` | `norm_d` |
| `ProximalOptions(; print_every = 0)` silently used 1 | `ArgumentError` |
| invalid settings of `ProximalOptions`, `ADMMSolver` and the proximal gradient solvers raised `ErrorException` | `ArgumentError` |
| infinite or `NaN` tolerances, `ρ` and penalty levels | `ArgumentError` |

## Changed results

- **Flat coordinates.** Coordinate descent with a zero curvature along a
  coordinate used to send it to the minimizer of the penalty and ignore the
  linear term. It now finds the minimizer of the coordinate problem when it
  exists (zero for the ℓ1 norm while `|G| ≤ λ`, the bound of a box) and raises
  an `ArgumentError` when `f + g` is unbounded below along the coordinate.
  `kkt_residual` reports `Inf` there.
- **Square-root losses.** `SqrtLeastSquaresLoss` and `SqrtQuadraticFunction`
  runs converge only when the relative duality gap is at most `gaptol`, or
  `1e-2` by default, and the results report the gap. Exact or nearly exact fits
  with a positive penalty, common with `p ≥ n` and a small penalty, now return
  `converged = false` with a warning; they used to report convergence at points
  that can be far from the minimizer.
- **Proximal Newton** without a duality gap stops only when the objective has
  stalled and the original problem is stationary; see [Proximal Newton](@ref).
  A run that cannot meet both returns `converged = false` after `maxiter`.
- **Active-set proximal gradient** converges only when the proximal residual of
  the whole problem is at most `gradtol * max(1, ‖∇f(x₀)‖∞)`.
- **ADMM** rejects a dual starting point `u` that shares storage with `x`.
- **`refit!`** sets the coefficients outside `support` to zero, and checks that
  `support` has unique indices in range.
- **Symmetric matrices.** Coordinate descent on a `SymmetricSparseIterate`
  needs symmetric penalty weights. The graphical lasso and generic proximal
  Newton average transposed weights, which leaves the objective unchanged.
- **`duality_gap(f, g, h, D, x, y)`** returns the raw difference of the primal
  and dual values, which can be negative or `NaN` when the dual point is
  infeasible, instead of clipping it at zero.
