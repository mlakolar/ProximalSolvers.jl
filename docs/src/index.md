# ProximalSolvers.jl

ProximalSolvers provides coordinate descent and proximal methods for penalized
estimation in Julia. We consider the problem

```math
\min_x F(x) = f(x) + g(x),
```

where ``f`` is a loss and ``g`` is a penalty or a constraint. The package
provides the optimization algorithms, while
[ProximalBase.jl](https://mlakolar.github.io/ProximalBase.jl/dev/)
provides the functions, their gradients and proximal operators, and the iterates.

## Coordinate descent and proximal methods

Coordinate descent updates one coordinate or group at a time, using cached
residuals or matrix products to avoid recomputing the loss after every step.
Furthermore, passes over the active coordinates concentrate the work on a
small set when the solution is sparse. Using the same engine, we compute penalty paths with screening, reweighted
estimates, refits on a selected support, and the inner solves of proximal Newton.

Proximal gradient methods combine a gradient step on the loss with a proximal
step on the penalty. In particular, we can use the nuclear norm for low-rank regression through
its proximal operator, which thresholds the singular values. ADMM instead
splits the problem into two proximal subproblems, one for each term in the
objective.

Both approaches use `solve!(x, f, g, solver)`, which updates the starting point
`x` and returns a summary of the run. In particular, the choice of solver
determines which structure of the loss and penalty the algorithm uses.

## Start here

1. [Getting started](@ref) fits a lasso, computes a penalty path, and solves
   the same problem by proximal gradient.
2. [Choosing a solver](@ref) matches the structure of a problem to an algorithm.
3. [Checking a solution](@ref) explains optimality conditions, residuals and
   duality gaps.

## Methods and applications

| Task | Read |
|:-----|:-----|
| Sparse regression and group penalties | [Coordinate descent](@ref), [Losses for coordinate descent](@ref) |
| A sequence of penalty levels | [Penalty paths and screening](@ref) |
| Adaptive weights, local linear approximation and post-selection refits | [Reweighting and refitting](@ref), [Nonconvex penalties: exact steps or local linear approximation](@ref) |
| Penalized GLMs and the graphical lasso | [Proximal Newton](@ref) |
| Low-rank regression and general proximal problems | [Proximal gradient methods](@ref), [ADMM](@ref) |
| Graph fusion, trend filtering, and the choice of a composite splitting | [Choosing a splitting for a composite problem](@ref composite_lessons) |
| Sparse problems with a restricted gradient calculation | [Active-set proximal gradient](@ref) |
| A loss of your own | [A coordinate descent model of your own](@ref) |

The examples are complete Julia programs, executed when the documentation is
built, with function signatures and options in [Calling the solvers](@ref)
and the [Solver reference](@ref).

Finally, we describe the statistical software collection in
[Related packages and benchmarks](@ref) and collect the general algorithmic
[references](@ref general_references), with further citations on the method pages.
