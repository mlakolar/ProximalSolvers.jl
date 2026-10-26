# Calling the solvers

## The call

The two-term solvers minimize ``f(x) + g(x)`` through [`solve!`](@ref):

```julia
res = solve!(x, f, g, solver)            # CDSolver, ProxNewton
res = solve!(x, f, g, solver, options)   # the proximal gradient solvers and ADMM
res = solve!(x, f, g, h, D, CondatVu(), options)  # f(x) + g(x) + h(D*x)
```

`x` is the starting point, and `solve!` overwrites it with the solution. The
loss `f` and the penalty `g` are functions of ProximalBase. Each solver asks
for some of their oracles, and for an iterate of a certain kind:

| Solver | ``f`` | ``g`` | `x` |
|:-------|:------|:------|:----|
| [`CDSolver`](@ref) | a loss with a coordinate descent model, see [Losses for coordinate descent](@ref) | separable, or a group penalty (`GroupNormL2`, `GroupNormLinf`, ...) | a `SparseIterate`, a `SymmetricSparseIterate`, an `AtomIterate` for a group penalty, or a vector |
| [`ProxNewton`](@ref) | a `GLMLoss`, a `LogDetLoss`, or a smooth loss with a supported quadratic model | separable for vectors; `NormL1` for `LogDetLoss`; see [Other smooth losses](@ref) for generic matrix models | a `SparseIterate` or dense vector; for supported matrix models, a `SymmetricSparseIterate` or symmetric `Matrix` |
| [`ProximalGradientDescent`](@ref), [`AccProxGradDescent`](@ref) | smooth: `issmooth(f)` | proximable: `isproximable(g)` | any array that `f` and `g` take, a `SparseIterate`, or an `AtomIterate` with the groups of a `GroupNormL2` |
| [`MonotoneAccProxGradDescent`](@ref) | smooth | proximable | any array that `f` and `g` take, a `SparseIterate` or a `SymmetricSparseIterate` |
| [`ActiveAccProxGradDescent`](@ref) | smooth, with `restrict` | separable or `GroupNormL2`, with `restrict` and `kkt_violation` | a vector, a `SparseIterate` or an `AtomIterate` |
| [`ADMMSolver`](@ref) | proximable | proximable | an `Array` |

The iterates are those of ProximalBase: a
[`SparseIterate`](@extref ProximalBase.SparseIterate) stores the entries that
have been nonzero and gives ``O(1)`` access to any entry; a
[`SymmetricSparseIterate`](@extref ProximalBase.SymmetricSparseIterate) is a
sparse symmetric matrix whose coordinates are the entries of its lower
triangle; an [`AtomIterate`](@extref ProximalBase.AtomIterate) is a vector
whose coordinates are groups of entries. A solver that takes a dense vector
for coordinate descent or the active-set method converts it to one of these,
and copies the solution back.

The solvers compute in the element type of `x`, `Float64` or `Float32`. In
`Float32`, tolerances below its precision, `eps(Float32) ≈ 1.2e-7`, cannot be
met.

## Options

[`ProximalOptions`](@ref) holds the iteration and call limits, the tolerances
and the tracing of the proximal gradient solvers, which pass them on to each
inner solve of the active-set method:

| Keyword | Default | Meaning |
|:--------|:--------|:--------|
| `maxiter` | `200` | the largest number of iterations |
| `ftol` | `1e-6` | relative change of the objective |
| `xtol` | `1e-8` | relative change of the iterate |
| `gradtol` | `1e-5` | the optimality residual of FASTA |
| `allow_f_increases` | `false` | keep going when the objective increases |
| `time_limit` | `Inf` | the longest run time, in seconds |
| `f_calls_limit`, `grad_calls_limit`, `prox_calls_limit` | `0` | the largest number of evaluations of ``f``, of its gradient and of proximal operators; `0` is no limit |
| `store_trace`, `show_trace`, `extended_trace`, `print_every` | `false`, `false`, `false`, `1` | record or print the progress |
| `callback` | `nothing` | called every `print_every` iterations; returning `true` stops |
| `gaptol`, `gapevery` | `0`, `10` | with `gaptol > 0`, stop when the relative duality gap, computed every `gapevery` iterations, is at most `gaptol` (see [Duality gaps](@ref)) |

The tests of `ftol`, `xtol` and `gradtol` are those of
[Proximal gradient methods](@ref "Stopping rules"); the solver stops when any
of them passes. [`ADMMSolver`](@ref) has its own tolerances and uses only
`maxiter`, `time_limit`, `prox_calls_limit`, `show_trace`, `print_every`,
`gaptol` and `gapevery`.
[`CDSolver`](@ref) and [`ProxNewton`](@ref) take their settings as keywords
of their constructors instead: `CDSolver(; maxpasses, tol, order, relative,
anderson, momentum, rng, gaptol, gapsafe)` and `ProxNewton(; inner, maxiter, tol, β)`.

The call limits are checked after each iteration, which always finishes, so a
count can exceed its limit by the evaluations of one iteration.

## Reusing solver buffers

[`SolverWorkspace`](@ref) keeps the solver-owned buffers between standalone
fits with a fixed loss, solver configuration and iterate shape:

```julia
ws = SolverWorkspace(zeros(size(X, 2)), LeastSquaresLoss(y, X),
                     NormL1(0.1), AccProxGradDescent(), ProximalOptions())
result = solve!(ws)
result = solve!(ws, NormL1(0.05))    # same loss, a different penalty level
reinit!(ws, zeros(size(X, 2)))      # a new start in the existing storage
```

The three gradient solvers, `CDSolver` and `ADMMSolver` support this interface.
For coordinate descent omit `ProximalOptions`; the workspace may also take a
configured `CDModel`, including one with an intercept. Each solve resets its
counters and acceleration history. ADMM also resets its scaled dual variable
and penalty parameter unless `solve!(ws; warm_start = true)` is requested.

The workspace shares the caller's starting array and the result's minimizer;
ADMM results also share its dual buffer. Copy arrays that must survive another
solve. Keep loss data and group partitions fixed, and use separate workspaces
for concurrent solves. User function or proximal-operator allocations, traces,
results and optional refit/Anderson work are separate from buffer reuse.

## Results

| Solver | Result | Fields |
|:-------|:-------|:-------|
| [`ProximalGradientDescent`](@ref), [`AccProxGradDescent`](@ref), [`MonotoneAccProxGradDescent`](@ref) | [`OptimizationResults`](@ref ProximalSolvers.OptimizationResults) | `minimizer`, `minimum`, `iterations`, `converged`, the flags `x_converged`, `f_converged`, `grad_converged` with the final residuals, `f_increased`, `iteration_converged` (the iteration limit was reached), `call_limit_reached`, `backtrack_steps`, `f_calls`, `grad_calls`, `prox_calls`, `trace`, `gap` |
| [`ActiveAccProxGradDescent`](@ref) | [`ActiveSetResults`](@ref ProximalSolvers.ActiveSetResults) | `minimizer`, `minimum`, `outer_iterations`, `inner_iterations`, `converged`, `inner_converged`, `max_violation`, `active_set_size` |
| [`ADMMSolver`](@ref) | [`ADMMResults`](@ref ProximalSolvers.ADMMResults) | `minimizer`, `minimum`, `iterations`, `converged`, the residuals `r_norm`, `s_norm` and their tolerances `eps_pri`, `eps_dual`, the scaled dual variable `u` and the final `ρ`, the counts of calls, `gap` |
| [`CDSolver`](@ref), [`ProxNewton`](@ref) | [`CDResults`](@ref) | `minimizer`, `minimum`, `passes`, `converged`, `maxchange`, `tolerance`, `kkt_checks`, `gap` |
| [`solve_path`](@ref) | [`PathResults`](@ref) | per level: `λ`, `solutions`, `values`, `passes`, `converged`, `kkt_checks`, `stages` |
| [`reweight!`](@ref), `solve!` with [`LLA`](@ref) | [`ReweightResults`](@ref) | `minimizer`, `penalty`, `next`, `iterations`, `converged`, `change`, `passes`, `cd_converged` |

`minimum` is ``f + g`` at the minimizer, and `gap` the relative duality gap
there when it was computed, `NaN` otherwise. For the gradient solvers and ADMM,
`result.converged` reports the selected criterion: with `gaptol > 0` and a
computable gap, the final gap must meet `gaptol`, including when a run stops
at a limit or a callback. The `x_converged`, `f_converged` and `grad_converged`
flags remain diagnostics of the individual residual tests. Without a
computable gap, those tests determine gradient solver convergence, and ADMM
uses its primal and dual residual tests. Printing a result shows a summary.

## Duality gaps

A duality gap bounds the objective error for supported convex problems.
[Checking a solution](@ref) gives the optimality conditions, the dual
construction, and the distinction between absolute and relative gaps. Use
`CDSolver(; gaptol)` or `ProximalOptions(; gaptol, gapevery)` to request a gap
stopping rule where it is available.

## Traces and callbacks

With `store_trace = true` the proximal gradient solvers record an
[`OptimizationState`](@ref) per iteration in `res.trace`: the iteration, the
objective `fg_x`, the relative change of the iterate `dxx` and the inverse step
size `L`. `extended_trace = true` also stores the iterate and the gradient.
`show_trace = true` prints the same every `print_every` iterations. A
`callback` receives the trace, or the current state when the trace is not
stored, and stops the solver by returning `true`.

For the penalty paths of coordinate descent, `solve_path(...; callback)` calls
`callback(k, λ, x, m)` after each level instead; see
[Penalty paths and screening](@ref).

## Naming

Options and solver settings use `snake_case` keywords, such as
`ProximalOptions(; print_every=...)` and `CondatVu(; norm_d=...)`. Invalid
settings raise an `ArgumentError`. Internal solver-state fields are not a
stable extension interface. See [Migrating to this release](@ref) for the
names removed since version 0.1.0.

## Diagonal preconditioning

`ProximalGradientDescent(preconditioner = :diagonal)` and
`AccProxGradDescent(preconditioner = :diagonal)` use the coordinate curvatures
from `coordinate_lipschitz!(D, f)`. This can help when design columns have very
different scales. The default `:none` retains scalar steps.

```julia
x = zeros(size(X, 2))
r = solve!(x, LeastSquaresLoss(y, X), NormL1(0.1),
           AccProxGradDescent(preconditioner = :diagonal),
           ProximalOptions(gaptol = 1e-6, maxiter = 5000))
```

Each trial uses steps `1 ./ (L .* D)`. Backtracking finds the scalar `1/L`
in the norm `sqrt(sum(D .* abs2.(dx)))`; coordinate curvatures alone do not
majorize the loss. Momentum and objective restarts retain their usual form.
The gradient residual and its normalizer use the transformed coordinates
`u = sqrt.(D) .* x`, as do iterate stopping tests and reported iterate residuals.
Duality gaps are evaluated on the original loss and penalty without modification.
For PGD, `ls.Lexact`, if supplied, must bound curvature in this metric.

Zero curvatures receive unit metric entries, so flat coordinates still have
positive steps. Nonfinite or negative curvatures raise `ArgumentError`, as does
a loss without coordinate-curvature support. The penalty must implement
array-step proximal operators, as separable penalties, group norms, the simplex
and the ℓ1 ball do. Group ℓ2 and ℓ∞ norms use a scalar optimality equation
within each group, since ProximalBase's group-step API assumes a constant
metric inside each group. Tuple blocks, `SymmetricSparseIterate`, and combining PGD's
`normalized = true` with diagonal preconditioning are unsupported.
`SolverWorkspace` computes the metric once and reuses it; its loss data must
remain fixed, including across `reinit!` calls.
