# Architecture

ProximalSolvers composes solver settings, model caches and iterate storage through
Julia fields and specializes public operations with multiple dispatch. Concrete
structs do not inherit from one another. The diagrams below describe source
relationships; grouped boxes abbreviate several concrete types rather than
introducing additional Julia types.

The [DOT sources](https://github.com/mlakolar/ProximalSolvers.jl/tree/master/docs/architecture)
are authoritative. Their SVG renderings are included here. An empty triangular
arrow means subtyping, a diamond means composition through a field, a dashed
blue arrow means dispatch or method extension, and a solid blue arrow means a
runtime call. Dashed red arrows indicate shared storage or a private dependency.
Each diagram labels its edges where their meaning could be ambiguous. Select a
diagram to open the full-size SVG.

## Solver and model types

[![Solver and model types](assets/architecture/types.svg)](assets/architecture/types.svg)

[`ProximalSolver`](@ref) is the abstract supertype for the solver settings.
[`LLA`](@ref) is a separate driver holding a [`CDSolver`](@ref); it is not a
subtype of `ProximalSolver`. [`CDModel`](@ref) is the public abstract type for
coordinate models. Its built-in concrete implementations are internal.

The declarations and include order are in
[`src/ProximalSolvers.jl`](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/src/ProximalSolvers.jl),
[`src/types.jl`](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/src/types.jl)
and [`src/cd/models.jl`](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/src/cd/models.jl).
A solver's immutable settings can contain mutable state owned elsewhere: for
example, `CDSolver` keeps a reference to its random-number generator.

## Dispatch and accepted iterates

[![Runtime dispatch](assets/architecture/runtime.svg)](assets/architecture/runtime.svg)

The entry point dispatches on the method, loss, penalty and iterate types.
The gradient engine in
[`src/solve.jl`](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/src/solve.jl)
constructs or resets state, takes an accepted step, assesses the selected
stopping rule, and returns diagnostics. Rejected gradient trials reuse the
iterate buffer. A failed line search raises an error and `solve!` restores the
last accepted point. A failed numerical step is not convergence.

ADMM and Condat–Vũ have their own splitting and residual equations. Proximal
Newton specializes on a GLM, a log-determinant loss, or a generic quadratic
oracle. The generic route uses the original gradient for stationarity; GLM
objective stagnation also requires a check of that gradient. QUIC stops on the
graphical-lasso certificate. SLOPE drivers check the full proximal equation
after restricted fits. See [Calling the solvers](@ref) for supported storage,
options and result types, and the method pages for equations and assumptions.

An `issmooth` or Hessian trait selects a method; it does not prove Lipschitz
continuity, positive semidefiniteness or oracle accuracy. Those mathematical
conditions remain part of a custom function's contract. Finite precision,
restarts and approximate inner solves do not by themselves inherit a cited
algorithm's convergence rate.

## Coordinate-model operations

[![Coordinate model interface](assets/architecture/coordinates.svg)](assets/architecture/coordinates.svg)

The public extension surface is [`CDModel`](@ref) with `initialize!` and either
`coordinate_step!` or the pair `coordinate_derivatives` and `update_cache!`.
Optional scales control the change rule; `loss_value` provides reporting and
Anderson acceptance; `gradient!` supports penalty levels and screening.
[A coordinate descent model of your own](@ref) gives the signatures.

The scheduling kernels in
[`src/cd/solver.jl`](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/src/cd/solver.jl)
and block kernels in
[`src/cd/groups.jl`](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/src/cd/groups.jl)
are internal. Scalar updates use an exact quadratic curvature or a majorizing
bound. Group updates use a bound on the full block Hessian, not its diagonal.
For symmetric storage an off-diagonal coordinate moves both entries and counts
both penalty terms. A single helper prepares the penalty for coordinate descent,
QUIC, generic symmetric Newton and the gradient solvers on symmetric storage:
it averages parameters that enter linearly and rejects other asymmetric
per-entry parameters, as described in [Coordinates of the iterates](@ref).

A coordinate with zero curvature targets `min G(x - xₖ) + μgᵢ(x)`, with the
coordinate's multiplicity `μ`. Norms and boxes retain their existing steps.
Closed forms also minimize the elastic net, squared ℓ2 norm, Berhu, negative
logarithm, negative entropy and KL divergence; `Regularize` of a convex penalty
completes the square and takes one proximal step. `Scaled` changes `μ`, `Tilt`
changes the effective slope. A small trait identifies exact flat penalties
and their wrappers. `Translate` shifts an exact inner minimizer;
`BoxConstrained` clamps it, or selects the finite end in an exact unbounded
direction. Numerical unavailability propagates through the box. Other translated
and boxed penalties keep the generic method on the whole wrapper. Exact formulas
use balanced quotients and at least Float64 precision, preserving BigFloat
iterates, and convert once at the outer call. Translation and clamping must
preserve the inner domain: positive
for `NegLog`, nonnegative
for `NegEntropy` and `KLDivergence`, also through wrappers. See the formulas in
[The coordinate step](@ref). Least-squares zero columns and intercept-constant
columns use the same flat minimizer. A zero computed curvature triggers a check
of the actual column on rows with positive weight, including implicit sparse
zeros. If the column is not flat, the step rejects underflowed curvature and
the diagnostic retains the actual slope.

Proximal fixed points certify convex affine subproblems only. A nonzero
effective slope with a nonconvex penalty is rejected, including on a box.
Unbounded, unsupported and numerically unavailable flat steps raise an
`ArgumentError`, and `kkt_residual` reports `Inf` there. Numerical rejection
includes entropy or KL underflow to zero and does not assert unboundedness.
The candidate and its displacement are checked in the iterate's element type
before changing the attempted coordinate or its cache; earlier coordinates
of the pass may already have moved. The square-root losses check a relative
duality gap when dual scaling is available; unpenalized coordinates can require
a fallback to the change rule. See [Losses for coordinate descent](@ref).

## Ownership and cache validity

[![Storage ownership](assets/architecture/ownership.svg)](assets/architecture/ownership.svg)

[`SolverWorkspace`](@ref) owns reusable buffers and shares the caller's `x`.
Results share the minimizer and supplied splitting dual arrays. Saved path
solutions and extended-trace arrays are copies. Copy a result array before
reusing its workspace if the old fit must remain available.

Loss data, scales, group partitions, dimensions and solver configuration must
stay fixed during workspace reuse. A new penalty must have the original type
and partition. [`reinit!`](@ref) changes the starting coefficients and clears
ADMM's dual warm start. `solve!(workspace; warm_start = true)` is the explicit
ADMM route for retaining its dual and penalty parameter. These rules appear in
[`src/workspaces.jl`](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/src/workspaces.jl).

Models can reference input matrices, responses and weights. `initialize!`
refreshes the iterate cache; it is not a general invalidation API for changed
data. In particular, centering constants and factorization caches can depend
on same-shape values. Construct a new model or workspace after changing them.
A [`RefitCache`](@ref) belongs to one unchanged loss. Separate workspaces,
models, mutable function buffers and random generators are needed for
concurrent solves. An immutable outer struct does not make its buffers safe
to share between tasks.

## Paths and estimator drivers

[![Estimator drivers](assets/architecture/drivers.svg)](assets/architecture/drivers.svg)

[`solve_path`](@ref) and continuation change penalty levels while reusing the
iterate and model. Strong screening is a prediction; full checks reactivate
excluded violations. Gap-safe screening instead requires a valid dual point
and nonnegative gap. Restricted gaps do not replace full-problem checks.
The paths save independent snapshots and retain unsuccessful levels.

[`LLA`](@ref) and [`reweight!`](@ref) use repeated weighted fits. Their outer
stopping flags describe weight changes, while inner convergence is reported
separately. Nonconvex stages do not certify a global optimum. [`refit!`](@ref)
zeros coordinates outside the requested support and solves on that support,
using pivoted QR or an eligible cached factor. The relevant sources are
[`src/cd/path.jl`](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/src/cd/path.jl),
[`src/cd/lla.jl`](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/src/cd/lla.jl)
and [`src/cd/drivers.jl`](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/src/cd/drivers.jl).

## Package boundaries

[![Package boundaries](assets/architecture/boundaries.svg)](assets/architecture/boundaries.svg)

ProximalBase defines function oracles and iterate storage. ProximalSolvers owns
solver scheduling, coordinate caches and results. HighDimensionalModels adds
statistical preprocessing, estimators, paths and cross-validation; it also
extends the public coordinate-model operations. CovarianceSelection calls
ADMM, gradient and refit operations. DiffPrecTest uses coordinate solves and
paths for structured inverse-Hessian problems.

Built-in model types and helpers such as `SqrtQuadModel`, `_saturated` and
`_hasconjugate` are internal and may change. The public model protocol supplies
the supported route for extensions. Callbacks and traces follow each solver's documented behavior.
