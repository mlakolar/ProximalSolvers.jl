# Choosing a solver

`ProximalSolvers.jl` currently has **two** algorithms for the same
least-squares lasso objective. Both call the losses and proximal operators
provided by `ProximalBase.jl`. Neither is a general-purpose solver for
arbitrary loss/penalty combinations in this development core.

| | Coordinate descent (CD) | Proximal gradient descent (PGD) |
| --- | --- | --- |
| Constructor | `CDSolver()` | `ProximalGradientDescent()` |
| Idea | Update coefficients by coordinate, with full and active passes | Update the full coefficient vector, with backtracking |
| Iterate `x` | Dense `Vector` **or** 1D `SparseIterate` | Dense `Vector` only |
| Configuration | Keywords to `CDSolver` | `ProximalOptions` passed to `solve!` |
| Result type | `CDResults` | `OptimizationResults` |
| Natural starting point | Ordinary lasso, especially if you want active-coordinate storage | Ordinary lasso with full-vector iterations and optional iteration traces |

Neither method is universally faster. Compare them on your workload, using
the **same** objective scaling, initial point, precision and stopping criteria.

## Coordinate descent

~~~julia
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
f = (1 / length(y)) * LeastSquaresLoss(y, X)
g = NormL1(0.1)

x = zeros(2)
cd = CDSolver(order=:cyclic, momentum=false, tol=1e-7)
result = solve!(x, f, g, cd)
~~~

Some useful keyword arguments:

| Option | Meaning |
| --- | --- |
| `maxpasses` | Maximum number of coordinate passes (default `100_000`; zero is allowed) |
| `tol` | Nonnegative strict change threshold (default `1e-7`) |
| `order` | `:random` (default) or `:cyclic` |
| `momentum` | `nothing` (default behavior) or `false`; explicit `true` requires random order |
| `rng` | RNG to use with random order; the supplied RNG can advance |

Randomized coordinate descent uses the historical momentum behavior by
default. For reproducible experiments, supply an RNG of your own and do not
reuse it across comparisons unless you intend its state to advance.
Options for Anderson acceleration, gap-based stopping and screening are
currently unsupported.

### Coordinate descent with a SparseIterate

CD also accepts a **one-dimensional ProximalBase SparseIterate** holding
coefficients, even though the design matrix itself must still be dense:

~~~julia
x_sparse = SparseIterate(2)            # Float64 coefficients
sparse_result = solve!(x_sparse, f, g, CDSolver())
coefficients = Vector(x_sparse)
@assert sparse_result.minimizer === x_sparse
~~~

CD runs on a private state-preserving copy and writes the final state back
after finite completion. A numerical error does not partially overwrite
the caller's `SparseIterate`. The active-coordinate order can change, so
retrieve `activecoordinates(x_sparse)` and `activevalues(x_sparse)` again
after the solve. The copy needs additional storage proportional to the
number of coefficients; it does not make the dense design sparse.

See [Supported API and migration](support.md) for the exact ownership rules.

## Proximal gradient descent

~~~julia
x_pgd = zeros(2)
options = ProximalOptions(maxiter=2000, ftol=1e-14,
                          xtol=1e-12, gradtol=1e-10,
                          store_trace=true)
pgd_result = solve!(x_pgd, f, g, ProximalGradientDescent(), options)
@show pgd_result.iterations
@show length(pgd_result.trace)
~~~

The default method uses the package's supported backtracking line search.
The most useful `ProximalOptions` fields for a first experiment are:

| Option | Meaning |
| --- | --- |
| `maxiter` | Maximum number of PGD iterations (default `200`) |
| `ftol` | Objective-change tolerance (default `1e-6`) |
| `xtol` | Iterate-change tolerance (default `1e-8`) |
| `gradtol` | Gradient-based stopping tolerance (default `1e-5`) |
| `store_trace` | Keep a per-iteration trace in the result |
| `show_trace` | Print iterations while running |
| `time_limit` | Optional time limit; tested after an iteration |

PGD uses a combination of historical stopping tests; a small tolerance
does **not** guarantee the same numerical accuracy. It refuses a
`SparseIterate` coefficient destination. Use a dense vector.

## Supported input checklist

For either solver:

1. `X` must be a nonempty, finite, dense `Matrix{T}` and `y` a finite
   `Vector{T}` of matching row count.
2. `T` must be **Float32 or Float64**, consistently for `X`, `y` and `x`.
   Mixed array types are not automatically converted.
3. The loss must be `LeastSquaresLoss` or one positive finite scalar
   multiple of it; the penalty must be finite, nonnegative,
   **unweighted** `NormL1`.
4. `x` has one entry per column of `X`, and does not alias `X` or `y`.
5. The arrays and finite parameters must stay valid for the duration
   of the solve.

For additional limits and exact error behavior, see
[Supported API and migration](support.md) and
[Numerical behavior](numerics.md).
