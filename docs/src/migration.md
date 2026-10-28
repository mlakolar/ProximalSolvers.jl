# Migrating to this release

## From 0.2.0 to 0.3.0

Version 0.3.0 needs registered ProximalBase 0.5.3 or later within the 0.5 series.

- **Symmetric matrices.** Coordinate descent on a `SymmetricSparseIterate`
  now averages transposed parameters that enter the penalty linearly; see
  [Coordinates of the iterates](@ref). It accepts asymmetric weights of
  `NormL1`, `NormL1Nonneg` and `ElasticNet` and asymmetric `Tilt` coefficients,
  directly or through `Scaled` and `Tilt`, which 0.2.0 rejected.

  Version 0.2.0 accepted other asymmetric parameters but used only one triangle
  in the coordinate steps. The weights of `CappedL1`, `LogPenalty`, `NormLq`,
  `Berhu`, `CheckLoss`, `EpsInsensitiveLoss` and `HingeLoss`, the coefficients
  of `LinearFunction`, and L1 weights inside `Translate`, `Regularize`,
  `Constrained(·, IndBox)` and scalar `Precompose` are now averaged. Bounds
  (`IndBox`, including constrained penalties), patterns (`IndPattern`),
  centers (`SqrNormL2`, `Regularize`), translations (`Translate`), labels
  (`HingeLoss`) and references (`KLDivergence`) must now be symmetric or an
  `ArgumentError` is raised before mutation. Inside `MoreauEnvelope`,
  `Conjugate` and linear constraints, these per-entry parameters must already
  be symmetric, including the linear constraint's coefficient `a`.

  [`lambda_max`](@ref) and the gradient solvers on symmetric storage also used
  only one triangle in 0.2.0 and now follow the same averaging and rejection
  rule. The graphical lasso and generic symmetric proximal Newton continue
  to average transposed L1 weights. Averaging preserves the supplied objective
  on symmetric matrices, up to floating-point rounding.
- **Float32 and the gap rule.** Coordinate descent on Float32 data with the
  duality-gap stopping rule, the default of paths, raised a `MethodError` once
  the rule tightened its tolerance. It now keeps the tolerance in the element
  type.
- **Group curvatures.** When LAPACK fails to find the largest eigenvalue of a
  group's Gram matrix alone, as some builds do on near-identity matrices such
  as orthonormalized groups, block coordinate descent takes the largest of all
  its eigenvalues. It used to raise a `LAPACKException`.

## From the development version to 0.2.0

These are the changes from the previous development version (the `master`
branch before 0.2.0). Version 0.1.0 in the General registry predates this API;
start from [Getting started](@ref) instead.

Version 0.2.0 needs registered ProximalBase 0.5.3 or later within the 0.5 series.

### Renamed and removed

| Before | Now |
|---|---|
| `ProximalOptions(; printEvery = k)`, `options.printEvery` | `print_every` |
| `CondatVu(; normD = c)`, `method.normD` | `norm_d` |
| `ProximalOptions(; print_every = 0)` silently used 1 | `ArgumentError` |
| invalid settings of `ProximalOptions`, `ADMMSolver` and the proximal gradient solvers raised `ErrorException` | `ArgumentError` |
| infinite or `NaN` tolerances, `ρ` and penalty levels | `ArgumentError` |

### Changed results

- **Flat coordinates.** Coordinate descent with a zero curvature along a
  coordinate used to send it to the minimizer of the penalty and ignore the
  linear term. It now finds the minimizer of the coordinate problem when it
  exists (zero for the ℓ1 norm while `|G| ≤ λ`, the bound of a box) and raises
  an `ArgumentError` when `f + g` is unbounded below along the coordinate.
  Nonconvex affine subproblems with nonzero slope are rejected; unsupported
  flat penalties may also raise an error. `kkt_residual` reports `Inf` when
  no finite supported coordinate minimizer is available.
- **Square-root losses.** `SqrtLeastSquaresLoss` and `SqrtQuadraticFunction`
  runs converge only when the relative duality gap is at most `gaptol`, or
  `1e-4` by default, and the results report the gap. A joint support and residual
  dual point can certify exact fits with a positive penalty and fits with
  unpenalized coordinates. The residual direction is tried first for ordinary
  fits. Coordinate changes alone no longer accept an unpenalized fit: if no
  candidate is valid, the zero dual point gives a gap of one for a positive
  objective. Some exact minimizers can still miss a certificate and return
  `converged = false`. Correlation error bounds and a projection correction
  protect the gap when cancellation hides a constraint or an unrestricted
  direction is ill-conditioned. Compensated residuals and their error bounds
  protect the primal objective from cancellation. Exactly zero unrestricted
  correlation intervals certify without a Gram inverse. Rank decisions use an
  equilibrated Gram matrix; see [The square-root lasso](@ref).
- **Proximal Newton** without a duality gap stops only when the objective has
  stalled and the original problem is stationary; see [Proximal Newton](@ref).
  A run that cannot meet both returns `converged = false` after `maxiter`.
- **Active-set proximal gradient** converges only when the proximal residual of
  the whole problem is at most `gradtol * max(1, ‖∇f(x₀)‖∞)`.
- **ADMM** rejects a dual starting point `u` that shares storage with `x`.
- **`refit!`** sets the coefficients outside `support` to zero, and checks that
  `support` has unique indices in range.
- **Symmetric matrices.** Coordinate descent on a `SymmetricSparseIterate`
  needs symmetric penalty weights, including through `Scaled` and `Tilt`.
  Linear coefficients of a `Tilt` must also be symmetric. These checks occur
  before mutation. The graphical lasso and generic proximal
  Newton average transposed weights, which leaves the objective unchanged.
- **`duality_gap(f, g, h, D, x, y)`** returns the raw difference of the primal
  and dual values, which can be negative or `NaN` when the dual point is
  infeasible, instead of clipping it at zero.
