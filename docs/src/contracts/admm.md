# Two-function consensus ADMM

## [ADM-01 Inputs, settings and ownership](@id ADM-01)

**Statement.** `solve!(z, f, g, method::ADMMSolver, options=ProximalOptions(); u=nothing)`
accepts ProximalBase `f = SqrNormL2(λ, c)` and unweighted `g = NormL1(τ)`.
The center `c`, initial consensus variable `z` and any explicit scaled dual
`u` must be finite nonempty `Vector{T}` buffers of equal length, with one common
`T` of `Float32` or `Float64`. The loss level `λ` must be finite and strictly
positive and the penalty level `τ` finite and nonnegative. Both levels must
convert exactly to `T`. The solver borrows `c` for reads. It refuses possible
aliasing among `z`, `c` and explicit `u` using `Base.mightalias`.

`ADMMSolver(; ρ=1, α=1, abstol=1e-6, reltol=1e-4, abstol_dual=abstol, adaptive=false)`
takes a finite positive penalty, relaxation strictly between 0 and 2, and finite
nonnegative tolerances. The solver also checks these bounds after converting to
`T`. A strictly positive tolerance must stay positive. The working proximal
step `inv(ρ)` must be finite and strictly positive in `T`. A positive subnormal
penalty or reciprocal is allowed when both pass these checks.

Function, type, scalar, alias, setting and entry checks precede writes to the
caller. Incompatible lengths and empty vectors raise `DimensionMismatch`. Other
preflight refusals raise `ArgumentError`. The solve runs in private storage.
With `u=nothing`, the initial dual vector is zero. With explicit `u`, the solve
starts from its entries. On normal return, the caller's `z` and explicit `u`
receive the final iterates, and `result.minimizer` and `result.u` refer to those
buffers. With `u=nothing`, `result.u` holds the solver's dual vector. Reuse the
returned `z`, `u` and `ρ` together for a warm start. Copy the buffers to retain
the previous result's vectors. During a solve the caller must keep the buffers
and problem data stable.

**Applies to.** `ADMMSolver` with centered `SqrNormL2` and unweighted `NormL1`.

**Code.** `src/solvers/admm.jl`.

**Tests.** `test/admm.jl` covers input refusals, initial states, ownership and restart.

**Sources.** [Issue #433](https://github.com/mlakolar/ProximalSolvers.jl/issues/433)
and [archived ADMM](https://github.com/mlakolar/ProximalSolvers.jl/blob/9be1773e911a44ec21d49df28cb01fea37c4316e/src/solvers/admm.jl).

## [ADM-02 Iteration, diagnostics and termination](@id ADM-02)

**Statement.** For each iteration with previous consensus variable `z₀` and
scaled dual `u₀`, compute

```math
x = \operatorname{prox}_{f/\rho}(z_0-u_0),\qquad
\hat x = \alpha x+(1-\alpha)z_0,\qquad
z = \operatorname{prox}_{g/\rho}(\hat x+u_0),\qquad
u = (\hat x+u_0)-z.
```

Use ProximalBase `prox!` with step `inv(ρ)` for each proximal update. For `α=1`,
use `x` for `x̂`. For `α<1`, form `z₀ + α(x-z₀)` in working precision. For
`α>1`, form `x + (α-1)(x-z₀)`.
With `N = length(z)`, the working-precision diagnostics are

```math
r_{\rm norm}=\|x-z\|_2,\quad s_{\rm norm}=\rho\|z-z_0\|_2,\quad
\varepsilon_{\rm pri}=\sqrt{N}\,{\tt abstol}+{\tt reltol}\max(\|x\|_2,\|z\|_2),\quad
\varepsilon_{\rm dual}=\sqrt{N}\,{\tt abstol\_dual}+{\tt reltol}\,\rho\|u\|_2.
```

When `reltol` is zero, omit the relative terms. A residual stop requires both
finite residuals to be at most their respective finite tolerances. When both
computed residuals are zero, also check each component's native stationarity
violation at `z`. For `qᵢ = λ(zᵢ-cᵢ)`, the score is `abs(qᵢ + τ*sign(zᵢ))`
at a nonzero `zᵢ` and `max(abs(qᵢ)-τ, 0)` at zero. If a finite score exceeds
`eps_dual`, stop with `status=:stagnated` and `converged=false`. A nonfinite
score is a numerical failure.
This guard addresses a rounded zero-residual point at which the two proximal
updates have lost resolution. A successful `status=:converged` reports the
implemented tests in working precision. The tutorial verifies its fit
independently from the observations.

The supported `ProximalOptions` settings are `maxiter`, `prox_calls_limit`
and `time_limit`. Before beginning an iteration, check the iteration cap,
space for two proximal calls in the remaining call budget, and elapsed time,
in that order. A zero call budget denotes unlimited calls. Time is measured
from the end of preflight and checked before each step, so a step may run
past its limit. A nonpositive time limit permits zero iterations. A completed
step's convergence or stagnation takes precedence over reaching a limit.
Nondefault values for the other stored options are
refused. The shared compatibility-gap settings retain their constructor rules
in [PGD-05](@ref).

On normal return, `iterations` counts complete iterations and `prox_calls`
is twice that count. `minimum` is `f(z)+g(z)` evaluated once after termination.
The `ProximalSolvers.f_calls(result)` and `ProximalSolvers.grad_calls(result)`
accessors report one evaluation of `f(z)` and zero gradient oracle calls.
The four residual and tolerance fields describe the last completed iteration
at the returned `ρ`. With zero iterations, they are `NaN` and `converged=false`.
Limits return `:iteration_limit`, `:prox_calls_limit` or `:time_limit` in
`status`. A numerical failure, including nonfinite proximal arguments or
outputs, updated dual entries, residuals, tolerances or the final objective,
raises an error before committing either caller buffer.

**Applies to.** Every `ADMMSolver` solve and `ADMMResults`.

**Code.** `src/solvers/admm.jl`.

**Tests.** `test/admm.jl` compares with raw objective and KKT references and
checks recurrence, diagnostics, termination, counts and numerical failures.

**Sources.** [Issue #433](https://github.com/mlakolar/ProximalSolvers.jl/issues/433)
and [the phase-0 audit](https://github.com/mlakolar/ProximalSolvers.jl/issues/433#issuecomment-7004162217).

## [ADM-03 Adaptive penalty](@id ADM-03)

**Statement.** With `adaptive=true`, use the previous iteration's residuals and
tolerances to propose a penalty change before the next iteration. Compare the
scores `r_norm/eps_pri` and `s_norm/eps_dual`. The score is zero for zero residual,
including `0/0`, and infinite for positive residual and zero tolerance. Two
infinite scores tie. A primal score greater than ten times the dual score
proposes doubling `ρ`. A dual score greater than ten times the primal score
proposes halving it. The finite scores are compared with scaling to avoid
overflow or underflow in the individual divisions. Take at most 50 changes.

For a candidate multiplier `m`, rescale the dual as `u/m`, preserving the
unscaled dual `ρ*u` up to working-precision rounding. Skip a candidate if its
penalty or reciprocal is nonfinite or zero, the penalty cannot be scaled by
`m` exactly, or any rescaled dual entry would become nonfinite or round from
nonzero to zero. Updates occur between
iterations. The reported `ρ` was used for the final completed iteration and
matches both the diagnostics and the returned scaled dual.

**Applies to.** `ADMMSolver(adaptive=true)`.

**Code.** `src/solvers/admm.jl`.

**Tests.** `test/admm.jl` checks change directions, scaled dual values,
zero tolerances, range limits and agreement at independently measured accuracy.

**Sources.** [Issue #433](https://github.com/mlakolar/ProximalSolvers.jl/issues/433)
and [archived ADMM](https://github.com/mlakolar/ProximalSolvers.jl/blob/9be1773e911a44ec21d49df28cb01fea37c4316e/src/solvers/admm.jl).
