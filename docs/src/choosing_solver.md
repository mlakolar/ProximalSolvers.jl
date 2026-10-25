# Choosing a solver

We choose a solver according to the structure of the loss and penalty and the
operations available for each term. First, we consider coordinate descent
when the loss has a supported model and the penalty separates over
coordinates or groups.

## Coordinate descent and proximal Newton

| Problem | Solver | Further details |
|:--------|:-------|:----------------|
| Least squares, quadratics, Kronecker quadratics, square-root losses, or supported GLM coordinate steps, with a separable penalty | [`CDSolver`](@ref) | [Losses for coordinate descent](@ref) |
| Supported least-squares or quadratic model, with a group penalty on an `AtomIterate` | [`CDSolver`](@ref) | [Groups](coordinate_descent.md#Groups), [The group lasso](@ref) |
| Penalized logistic, Poisson or Huber regression | [`ProxNewton`](@ref) | [Proximal Newton](@ref), [Generalized linear models](@ref) |
| Graphical lasso, `LogDetLoss` with `NormL1` | [`ProxNewton`](@ref) | [The graphical lasso by QUIC](@ref) |
| Smooth loss supplying a quadratic model supported by coordinate descent | [`ProxNewton`](@ref) | [Other smooth losses](@ref) |

Coordinate descent uses cached residuals or matrix products, so a coordinate
step avoids a full gradient calculation. For example, a dense least-squares
step costs ``O(n)`` operations, compared with ``O(np)`` for the full gradient.
Passes over the active coordinates further reduce the work when the fitted
coefficient vector is sparse.

A separable penalty alone does not give a coordinate descent implementation,
since the loss must provide a model through [`cdmodel`](@ref). We describe
this interface in [A coordinate descent model of your own](@ref), where a
custom model supplies the coordinate derivatives and cache updates.

For a sequence of penalty levels, we use [`solve_path`](@ref) to reuse the
preceding fit and screen coordinates at the new level. Furthermore, [`reweight!`](@ref), [`LLA`](@ref) and
[`refit!`](@ref) build reweighted estimators, local linear approximations and
refits on the same engine.

## Proximal gradient and splitting

| Problem | Solver | Further details |
|:--------|:-------|:----------------|
| Smooth loss and a convex penalty with a proximal operator | [`AccProxGradDescent`](@ref), [`ProximalGradientDescent`](@ref) | [Proximal gradient methods](@ref) |
| Smooth loss and a nonconvex penalty with a proximal operator | [`MonotoneAccProxGradDescent`](@ref), [`ProximalGradientDescent`](@ref) | [Nonconvex penalties](@ref) |
| Single-response least squares with a sorted L1 penalty and a penalty path | [`SLOPEAPG`](@ref) | [Screened SLOPE paths](@ref) |
| Smooth loss, sparse solution, and supported restrictions to active coordinates | [`ActiveAccProxGradDescent`](@ref) | [Active-set proximal gradient](@ref) |
| Convex `f + g + h(D*x)` with a smooth `f` and proximal operators for `g` and `h` | [`CondatVu`](@ref) | [Primal–dual splitting](@ref) |
| Two functions with proximal operators | [`ADMMSolver`](@ref) | [ADMM](@ref) |

Proximal gradient uses a gradient of the loss and a proximal step on the entire
penalty. In particular, it handles the nuclear norm through singular-value
thresholding, as in [Low-rank regression](@ref). ADMM instead requires a
proximal operator for each term, and can be used for the graphical lasso as in
[The graphical lasso by ADMM](@ref).

For a nonconvex penalty, the choice of starting point can affect the solution,
and the method pages state the applicable convergence conditions. Note that
a stopping flag alone does not establish a global minimum of a nonconvex
problem.

## Iterates and accuracy

[`SparseIterate`](@extref ProximalBase.SparseIterate) represents individual
coordinates, [`AtomIterate`](@extref ProximalBase.AtomIterate) represents groups,
and [`SymmetricSparseIterate`](@extref ProximalBase.SymmetricSparseIterate)
represents a symmetric matrix. Dense arrays can be used where the solver and functions support them, as
listed with the options in [Calling the solvers](@ref).

Finally, choose an accuracy measure appropriate to the problem.
[Checking a solution](@ref) explains how a duality gap bounds objective error
and how coordinate residuals measure optimality when no gap is available.
