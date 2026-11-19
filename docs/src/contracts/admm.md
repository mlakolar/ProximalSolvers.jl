# Two-function consensus ADMM

## [ADM-01 Inputs, settings and ownership](@id ADM-01)

**Statement.** `solve!(z, f, g, method::ADMMSolver, options=ProximalOptions(); u=nothing)`
accepts ProximalBase `f = SqrNormL2(λ, c)` and unweighted `g = NormL1(τ)`.
The center `c`, initial consensus variable `z` and any explicit scaled dual
`u` must be finite nonempty `Vector{T}` buffers of equal length, with one common
`T` of `Float32` or `Float64`. The loss level `λ` must be finite and strictly
positive and the penalty level `τ` finite and nonnegative. Both levels must
convert exactly to `T`. The solver borrows `c` for reads. It checks each pair
among `z`, `c` and explicit `u`. A pair is refused when `Base.mightalias`
reports an alias or the vectors' memory ranges overlap.

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

**Applies to.** `ADMMSolver` on a dense vector with centered `SqrNormL2` and
unweighted `NormL1`. [ADM-04](@ref) states the inputs for the graphical lasso on
a dense matrix.

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

**Applies to.** Every `ADMMSolver` solve and `ADMMResults`. For the graphical
lasso on a dense matrix, [ADM-04](@ref) replaces the stationarity score, requires
`α=1` and adds the positive-definiteness rules.

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

**Applies to.** `ADMMSolver(adaptive=true)` on a dense vector. [ADM-04](@ref)
refuses it for a matrix.

**Code.** `src/solvers/admm.jl`.

**Tests.** `test/admm.jl` checks change directions, scaled dual values,
zero tolerances, range limits and agreement at independently measured accuracy.

**Sources.** [Issue #433](https://github.com/mlakolar/ProximalSolvers.jl/issues/433)
and [archived ADMM](https://github.com/mlakolar/ProximalSolvers.jl/blob/9be1773e911a44ec21d49df28cb01fea37c4316e/src/solvers/admm.jl).

## [ADM-04 Graphical lasso on dense matrices](@id ADM-04)

**Statement.** With a dense `Matrix{T}` start `Θ`, where `T` is `Float32` or
`Float64`, `solve!(Θ, f, g, method::ADMMSolver, options=ProximalOptions(); u=nothing)`
minimizes

```math
P(\Theta)=-\log\det\Theta+\operatorname{tr}(S\Theta)+\lambda_0\sum_{i\ne j}\Lambda_{ij}|\Theta_{ij}|
\quad\text{over}\quad \Theta=\Theta^\top\succ0,
```

with ProximalBase `f = LogDetLoss(S)` and `g = NormL1(λ₀, Λ)`. The penalty sums
over the full matrix, so each off-diagonal pair appears twice, and the zero
diagonal of `Λ` leaves the diagonal unpenalized. A factor such as `1/n` belongs
in `S`.

The solver checks, in this order: `f` is a `LogDetLoss{T}` with weight `w == 1`;
`g` is a `NormL1` whose weights are a `Matrix{T}`; `Θ` is nonempty and square;
`size(S) == size(Θ) == size(Λ)`; `method.α == 1` and `method.adaptive == false`;
the level `λ₀` is finite, nonnegative and exactly representable in `T`; the
entries of `Θ`, `S` and `Λ` are finite; `Λ` is nonnegative, exactly symmetric
(`Λ[i,j] == Λ[j,i]` for all `i`, `j`) and zero on the diagonal; `S` and `Θ` are
exactly symmetric; an explicit `u` is a `Matrix{T}` of the same size with finite,
exactly symmetric entries; no pair among `Θ`, `u`, `S` and `Λ` aliases, by
`Base.mightalias` or overlapping memory ranges; the [ADM-01](@ref) settings hold
in `T`, with a finite positive `inv(ρ)`; and a Cholesky factorization of a private
copy of `Θ` succeeds in `T`. These checks precede any write to `Θ` or `u`. An
empty or non-square `Θ` and a size mismatch raise `DimensionMismatch`; the other
refusals raise `ArgumentError`. The solver does not average or symmetrize its
inputs. Other function pairs, other array types, mixed element types, `α ≠ 1`
and `adaptive=true` are refused for matrix input.

Ownership follows [ADM-01](@ref). The solver borrows `S`, stored in `f`, and
`Λ`, retained by reference in `g`, for reads, and the caller must keep them
unchanged during the solve.

Each iteration applies the [ADM-02](@ref) recurrence with `α = 1`:
`x = prox_{f/ρ}(z₀-u₀)` by the ProximalBase `LogDetLoss` `prox!`,
`z = prox_{g/ρ}(x+u₀)` by the weighted `NormL1` `prox!` with `λ₀` converted to
`T`, and `u = (x+u₀)-z`. After each logdet proximal step, `x` must be finite,
exactly symmetric and pass a Cholesky factorization in `T`; otherwise the solve
raises an error before any write to `Θ` or `u`. The consensus iterate `z` after
the ℓ₁ step can be indefinite. The iteration does not check, clip or project it.
The residuals and tolerances are those of [ADM-02](@ref) with Frobenius norms
and `N = p²` for a `p × p` matrix, so `√N = p`. The limit order, counters and
nonfinite failures are those of [ADM-02](@ref).

The returned point is the consensus `z`. Before a normal return at any status,
`z` must be exactly symmetric and pass a Cholesky factorization in `T`;
otherwise the solve raises an error, with no write to `Θ` or `u`. After zero
completed iterations the returned point is the validated start. `ProximalOptions`
requires `maxiter ≥ 2`, so zero iterations follow from `prox_calls_limit = 1` or a
nonpositive time limit.

When both computed residuals are zero and pass their tolerances, the solver
checks stationarity at the positive-definite `z`, in place of the
[ADM-02](@ref) score. With `G = S - inv(z)`, the score of an entry is `|Gᵢᵢ|` on
the diagonal, `|Gᵢⱼ + λ₀Λᵢⱼ sign(zᵢⱼ)|` at a nonzero off-diagonal entry and
`max(|Gᵢⱼ| - λ₀Λᵢⱼ, 0)` at an off-diagonal exact zero, with `λ₀Λᵢⱼ` formed as
a product in `T`. If a finite score exceeds `eps_dual`, the status is
`:stagnated` and `converged=false`. A nonfinite score raises an error.

`status` is `:converged` when both residual tests pass and the stationarity check
passes where it applies, `:stagnated` as above, and `:iteration_limit`,
`:prox_calls_limit` or `:time_limit` at a limit, with `converged=false`. `minimum`
is `f(z)+g(z)` evaluated once at the returned point; a nonfinite value raises an
error before any write. The result is an `ADMMResults{T, Matrix{T}}` with
`result.minimizer === Θ` and, with explicit `u`, `result.u === u`. A converged
status reports these working-precision tests and is not an optimality
certificate.

**Applies to.** `ADMMSolver` with a dense `Matrix{Float32}` or `Matrix{Float64}`
start, `LogDetLoss` and weighted `NormL1`, fixed `ρ`, `α = 1` and
`adaptive=false`.

**Code.** `src/solvers/admm.jl`: the `Matrix` method of `_solve_admm!`,
`_admm_issymmetric`, `_admm_positive_definite!` and `_admm_logdet_stationary`.

**Tests.** `test/admm_graphical_lasso.jl` compares with analytic optima (1×1,
diagonal, 2×2 in both regimes, zero and large penalty) and a seeded sparse
precision matrix using a BigFloat objective, KKT scores and a dual certificate,
replays one step, and checks limits, stagnation, an indefinite intermediate `z`,
warm starts, refusals and numerical failures without caller writes.

**Sources.** [Issue #436](https://github.com/mlakolar/ProximalSolvers.jl/issues/436),
[parent issue #425](https://github.com/mlakolar/ProximalSolvers.jl/issues/425) and
[the Stage 0 report](https://github.com/mlakolar/ProximalSolvers.jl/issues/436#issuecomment-7019530001).
