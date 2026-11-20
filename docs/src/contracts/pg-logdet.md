# Matrix proximal gradient for the graphical lasso

## [PGD-06 Matrix inputs and ownership](@id PGD-06)

**Statement.** `solve!(Θ, f, g, method::ProximalGradientDescent, options)` solves
the full-matrix objective in [ADM-04](@ref) with ProximalBase `f = LogDetLoss(S)`
and `g = NormL1(λ₀, Λ)`. The start is a nonempty square `Matrix{T}` for
`T ∈ {Float32, Float64}`. The stored `S` and `Λ` are `Matrix{T}` of that same
size. The three matrices have finite entries and exact symmetry by entrywise
equality. `Θ` must pass Cholesky in `T`. The loss weight must be one, `Λ` must be
nonnegative, and `λ₀` must be finite, nonnegative and exactly representable in `T`.
Diagonal weights are permitted. On a positive-definite `Θ`, each `Θᵢᵢ` is positive,
so the penalty `λ₀Λᵢᵢ|Θᵢᵢ|` is linear in the diagonal. Each effective weight
`Cᵢⱼ = T(λ₀) Λᵢⱼ`, diagonal included, must be finite.
Pairwise alias checks include separately wrapped arrays whose memory overlaps.
The solver borrows the inputs for reads and assumes the caller leaves them
unchanged while the solve runs.

The method requires `BackTracking` with `Lexact = Inf`, and the converted
factors satisfy `0 < α ≤ 1` with finite `1/α` and `0 < β < 1` in `T`. Accepted
options are `maxiter`, `ftol`, `xtol`, `gradtol`, `time_limit` and the three
oracle-call limits. Objective increases, tracing, callbacks and print cadence
require their defaults. Additional solve keywords, unsupported functions or
buffer types, and invalid data or parameters raise `ArgumentError`; mismatched
dimensions and empty or nonsquare starts raise `DimensionMismatch`. Preflight
and start diagnostics run before writes to the caller's matrix.

**Applies to.** Dense matrix PGD with the graphical-lasso function pair.

**Code.** `src/solvers/logdet_proximal_gradient.jl` and the shared array
validation primitives in `src/solvers/admm.jl`.

**Tests.** `test/pgd_graphical_lasso.jl` exercises both precisions, invalid
methods, options, dimensions, weights, storage, borrowed buffers and starts.
It accepts positive diagonal weights. It refuses negative and nonfinite diagonal
weights and a diagonal effective weight that overflows in `T`.

**Sources.** [Approved graphical-lasso PGD scope](https://github.com/mlakolar/ProximalSolvers.jl/issues/444).

## [PGD-07 SPD backtracking and rollback](@id PGD-07)

**Statement.** At the current SPD point `Θ`, ProximalBase evaluates the
logdet gradient `G = S - inv(Θ)`. The solver requires finite entries. It
replaces each pair of off-diagonal entries by their mean if their difference
is at most `8eps(T)` times the largest of one and the magnitudes of the
two entries and the corresponding entry of `S`. Larger skew raises an
error. The first search starts at `t = 1`. Subsequent searches start at
`min(1, t_last / T(α))`.

The solver forms exactly symmetric `V = Θ - t G` in private storage and
calls the ProximalBase `prox!(Z, g, V, t)` if `V` is finite. The proposal
must be finite, exactly symmetric and pass Cholesky in `T` before the
solver evaluates its smooth value. With `D = Z - Θ`, it requires both

```math
f(Z) \le f(\Theta) + \langle G,D\rangle + \frac{\|D\|_F^2}{2t},
\qquad f(Z)+g(Z) \le f(\Theta)+g(\Theta)
```

with a working-precision allowance on each comparison. The allowance is
`16eps(T)` times the largest of one and the magnitudes of the two loss
values, the linear term and the quadratic term in the first comparison.
For the composite comparison it scales with the largest of one and the
two composite magnitudes. The term-based scale allows for rounding in the
oracle values and arithmetic near equality, including cancellation in the
model. The two inner products run over the full matrix. A nonfinite
objective or quadratic model fails the comparison.

Each rejection shrinks the step by `T(β)` if the solve has budget to
continue. A search attempts at most 64 trials, with finite positive step
and reciprocal required before each trial. Failure to reduce the step,
an invalid step or 64 rejections raises an error. ProximalBase evaluates
the candidate gradient after its SPD and acceptance checks. The solver
commits the candidate only after the gradient and KKT diagnostics
succeed. A thrown numerical error or an interrupted search leaves the
last committed SPD point in the caller's matrix. The step depends on
local comparisons because the logdet gradient has no global Lipschitz
constant on the SPD cone.

**Applies to.** Matrix PGD after preflight in [PGD-06](@ref).

**Code.** `src/solvers/logdet_proximal_gradient.jl` implements the matrix
step within `_solve_gradient!` in `src/solve.jl`.

**Tests.** `test/pgd_graphical_lasso.jl` verifies an indefinite first
trial, a nonfinite objective, finite backtracking and bounded failure,
invalid reciprocal and rollback after a completed step. It also tests a diagonal
threshold that zeroes a proposal's diagonal, which the Cholesky check rejects
before the search backtracks to a positive-definite step.

**Sources.** [Approved graphical-lasso PGD iteration](https://github.com/mlakolar/ProximalSolvers.jl/issues/444).

## [PGD-08 KKT stopping, limits and results](@id PGD-08)

**Statement.** At a committed point, the KKT score is the largest
entrywise violation divided by `max(1, maximum(abs, S), maximum(C))`, with the
maximum of `C` over all entries, diagonal included. With `G` the symmetrized
gradient of [PGD-07](@ref), the violations are `abs(Gᵢⱼ + Cᵢⱼ sign(Θᵢⱼ))`
at nonzero entries and `max(abs(Gᵢⱼ) - Cᵢⱼ, 0)` at exact zeros. The start and
each committed point have passed Cholesky in `T`, so their diagonal entries are
positive and the diagonal violation is `abs(Gᵢᵢ + Cᵢᵢ)`. With `Cᵢᵢ = 0` it is
`abs(Gᵢᵢ)`. The scale, products and normalized score are evaluated in `T`.
Nonfinite violations raise an error.
After a completed step, convergence requires `g_residual ≤ g_tol`,
where `g_tol = max(gradtol, 64eps(T))`. The check is independent of the
trial step and the iterate and objective change tests. An accepted
elementwise unchanged point outside the KKT threshold sets
`stagnated=true` and `converged=false`.

`OptimizationResults.minimizer` aliases the caller's matrix.
`minimum` is `f(Θ) + g(Θ)` there. `x_residual` is
`‖Z - Θ_previous‖_F`, and `f_residual` follows the relative objective
change in [RES-02](@ref). Both are `NaN` before the first completed step.
`x_converged` and `f_converged` require convergence and their respective
change to be below the tolerance. `ftol=0` disables the objective proposal.
`grad_converged` equals `converged`. `f_increased` records an actual
increase on the last completed step, which can occur within the comparison
allowance. The trace is empty and `gap=NaN`.

`iterations` counts completed steps, including an accepted unchanged
point. `backtrack_steps` counts attempted proposals, including accepted
ones and proposals rejected before the prox. `f_calls` counts value-only
loss calls and the initial combined value/gradient oracle, `grad_calls`
counts gradient-only calls and the same initial combined oracle, and
`prox_calls` counts actual penalty proximal calls. Penalty value
evaluations are outside the smooth loss count. The initial diagnostics
consume one loss and one gradient call. A zero call limit is unlimited.
The solver checks positive call limits and time before the search and
after rejections and completed steps. A completed step may set a limit
flag even when the retained point meets the KKT threshold. An exit by
the iteration, time or call limit returns `converged=false`.
`iteration_converged` records exhaustion of `maxiter`, and
`call_limit_reached` records consumption of any positive call budget.

**Applies to.** Normal matrix PGD returns.

**Code.** `src/solvers/logdet_proximal_gradient.jl` supplies the KKT and
rounding-stall checks. `_solve_gradient!` in `src/solve.jl` handles limit exits
and constructs `OptimizationResults`.

**Tests.** `test/pgd_graphical_lasso.jl` checks, in Float32 and Float64, the
returned point of analytic and seeded problems with zero and positive diagonal
weights. It tests positive definiteness and compares the primal objective and the
KKT score with independent BigFloat values. It also computes a numerical (BigFloat)
estimate of the dual lower bound `logdet(W) + p`. The test builds `W` with
`Wᵢᵢ = Sᵢᵢ + Cᵢᵢ` and clipped off-diagonal entries. It reports the estimate only
after rational-arithmetic checks of the symmetry of `W`, the box
`|Wᵢⱼ - Sᵢⱼ| ≤ Cᵢⱼ` and the positive definiteness of `W`. Otherwise the gap is
`NaN` and the test's bounds on it fail. Analytic fixtures compare direct PGD
with closed-form optima, except one heterogeneous full-weight case without a
closed-form comparison. The seeded fixtures with positive diagonal weights
at `(p, n) = (10, 150)` and `(30, 20)` compare direct PGD with PGD on the shifted
covariance, each judged against the original data. Direct ADMM is compared at
`(10, 150)` only. The tests also check reported counters, the diagonal KKT score
at a start with a positive diagonal weight, a verified fixed point, a rounded
Float32 stall outside the threshold and limit precedence. A call limit during a
rejected trial checks that the shared driver keeps the last accepted point and
its diagnostics.

**Sources.** [Approved graphical-lasso PGD stopping rule](https://github.com/mlakolar/ProximalSolvers.jl/issues/444).
