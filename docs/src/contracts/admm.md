# Two-function consensus ADMM

## [ADM-01 Inputs, settings and ownership](@id ADM-01)

**Statement.** `solve!(z, f, g, method::ADMMSolver, options=ProximalOptions(); u=nothing)`
accepts ProximalBase `f = SqrNormL2(λ, c)` and unweighted `g = NormL1(τ)`;
[ADM-05](@ref) adds the raw least-squares loss. The center `c`, initial consensus variable `z` and any explicit scaled dual
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
a dense matrix, and [ADM-05](@ref) those for the least-squares lasso with a tall
or square design. The settings, ownership and refusal timing above are common to all three.

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

**Applies to.** Every `ADMMSolver` solve and the `ADMMResults` it returns. For the graphical
lasso on a dense matrix, [ADM-04](@ref) replaces the stationarity score, requires
a stored `α` equal to 1 and adds the symmetry and Cholesky rules. For the least-squares
lasso, [ADM-05](@ref) replaces only the stationarity score.

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

**Applies to.** `ADMMSolver(adaptive=true)` on a dense vector, including the
least-squares lasso of [ADM-05](@ref). [ADM-04](@ref) refuses it for a matrix.

**Code.** `src/solvers/admm.jl`.

**Tests.** `test/admm.jl` checks change directions, scaled dual values,
zero tolerances, range limits and agreement at independently measured accuracy.

**Sources.** [Issue #433](https://github.com/mlakolar/ProximalSolvers.jl/issues/433)
and [archived ADMM](https://github.com/mlakolar/ProximalSolvers.jl/blob/9be1773e911a44ec21d49df28cb01fea37c4316e/src/solvers/admm.jl).

## [ADM-04 Graphical lasso on dense matrices](@id ADM-04)

**Statement.** With a dense `Matrix{T}` start `Θ`, where `T` is `Float32` or
`Float64`, `solve!(Θ, f, g, method::ADMMSolver, options=ProximalOptions(); u=nothing)`
applies the iteration below to the problem

```math
\min_{\Theta=\Theta^\top\succ0}\;
P(\Theta)=-\log\det\Theta+\operatorname{tr}(S\Theta)+\lambda_0\sum_{i\ne j}\Lambda_{ij}|\Theta_{ij}|,
```

with ProximalBase `f = LogDetLoss(S)` and `g = NormL1(λ₀, Λ)`, and stops by the
residual tests, limits and working-precision exits of [ADM-02](@ref). The
penalty sums over the full matrix, so each off-diagonal pair appears twice, and
the zero diagonal of `Λ` leaves the diagonal unpenalized. `LogDetLoss` must have
weight one; when `S` is a sample covariance, a normalization such as `1/n` is part
of `S`.

After the entry checks of `solve!` (keywords, options, and the storage and
element type of the start), the matrix path checks, in this order: `f` is a
`LogDetLoss{T}` with weight `w == 1`; `g` is a `NormL1` whose stored weights `g.w`
are a `Matrix{T}`; `Θ` is nonempty and square; `size(S) == size(Θ) == size(Λ)`;
the `α` stored in `method`, after the `ADMMSolver` constructor's conversion,
equals 1, and `method.adaptive == false`; the level `λ₀` is finite, nonnegative
and exactly representable in `T`; the entries of `Θ`, `S` and `Λ` are finite; `Λ`
is nonnegative, exactly symmetric (`Λ[i,j] == Λ[j,i]` for all `i`, `j`) and zero
on the diagonal; `S` and `Θ` are exactly symmetric; an explicit `u` is a
`Matrix{T}` of the same size with finite, exactly symmetric entries; no pair among
`Θ`, `u`, `S` and `Λ` aliases, by `Base.mightalias` or overlapping memory ranges;
the [ADM-01](@ref) settings hold in `T`, with a finite positive `inv(ρ)`; and a
Cholesky factorization of a private copy of `Θ` succeeds in `T`. These checks
precede any write to `Θ` or `u`. The first failing check determines the
exception: `DimensionMismatch` for an empty or non-square `Θ`, a size mismatch
or a wrong-size `u`, and `ArgumentError` for the others. The solver does not
average or symmetrize its inputs. With a matrix start, other function pairs,
mixed element types, a stored `α` other than 1 and `adaptive=true` are refused.
The entry check refuses start types other than the dense vectors of
[ADM-01](@ref) and these dense matrices.

Ownership follows the protocol of [ADM-01](@ref) with matrices in place of
vectors. The solve runs in private storage. With `u=nothing`, the initial scaled
dual is the zero matrix; with explicit `u`, the solve starts from its entries.
On normal return, the caller's `Θ` and explicit `u` receive the final iterates,
and `result.minimizer` and `result.u` refer to those buffers. With `u=nothing`,
`result.u` holds the solver's dual matrix. Reuse the returned `Θ`, `u` and `ρ`
together for a warm start. The solver borrows `S`, stored in `f`, and `Λ`,
retained by reference in `g`, for reads. During a solve the caller must keep the
buffers and problem data unchanged.

Each iteration applies the [ADM-02](@ref) recurrence with `α = 1`:
`x = prox_{f/ρ}(z₀-u₀)` by the ProximalBase `LogDetLoss` `prox!`,
`z = prox_{g/ρ}(x+u₀)` by the `prox!` of `NormL1(T(λ₀), Λ)`, and `u = (x+u₀)-z`.
After each logdet proximal step, `x` must be finite, exactly symmetric and pass a
Cholesky factorization in `T`; otherwise the solve raises an error before any
write to `Θ` or `u`. The consensus iterate `z` after the ℓ₁ step can be
indefinite. The loop does not test its definiteness and does not clip or project
it; a nonfinite `z` fails the dual-update check of [ADM-02](@ref). The residuals
and tolerances are those of [ADM-02](@ref) with Frobenius norms and `N = p²` for
a `p × p` matrix, so `√N = p`. The limit order, counters and nonfinite failures
are those of [ADM-02](@ref).

The returned point is the consensus `z`. Before a normal return at any status,
`z` must be exactly symmetric and pass a Cholesky factorization in `T`;
otherwise the solve raises an error, with no write to `Θ` or `u`. This is a
working-precision test; it does not prove that a matrix close to singular is
positive definite. On a normal return after zero completed iterations, the
returned point is the validated start. `ProximalOptions` requires `maxiter ≥ 2`,
so zero iterations follow from `prox_calls_limit = 1` or from a time limit that
has expired before the first iteration, such as a nonpositive one.

When both computed residuals are zero and pass their tolerances, and `z` has
passed the return-point check above, the solver checks stationarity at `z` in
place of the [ADM-02](@ref) score. With `G = S - inv(z)`, the inverse formed from
a Cholesky factorization, the score of an entry is `|Gᵢᵢ|` on the diagonal,
`|Gᵢⱼ + λ₀Λᵢⱼ sign(zᵢⱼ)|` at a nonzero off-diagonal entry and
`max(|Gᵢⱼ| - λ₀Λᵢⱼ, 0)` at an off-diagonal exact zero, with `λ₀Λᵢⱼ` formed as a
product in `T`. A nonfinite score raises an error. Otherwise, if a score exceeds
`eps_dual`, the status is `:stagnated` and `converged=false`.

On a normal return, `status` is `:converged` when both residual tests passed and
the stationarity check passed where it applies, and `:stagnated` as above.
`:iteration_limit`, `:prox_calls_limit` and `:time_limit` report termination by
the limit checks of [ADM-02](@ref), with `converged=false`; a residual or
stagnation decision on the last permitted iteration takes precedence. `minimum`
follows the objective rule of [ADM-02](@ref) at the returned `z`, so a nonfinite
objective raises an error after the status decision and before any write. The
result is an `ADMMResults{T, Matrix{T}}`. A converged status reports these working-precision
tests and is not an optimality certificate.

**Applies to.** `ADMMSolver` with a dense `Matrix{Float32}` or `Matrix{Float64}`
start, `LogDetLoss` and `NormL1` with `Matrix` weights, fixed `ρ`, a stored
`α = 1` and `adaptive=false`.

**Code.** `src/solvers/admm.jl`: the `Matrix` method of `_solve_admm!`,
`_admm_issymmetric`, `_admm_passes_cholesky!` and `_admm_logdet_stationary`.

**Tests.** `test/admm_graphical_lasso.jl` compares with analytic optima (1×1,
diagonal, 2×2 in both regimes, zero penalty through zero weights or a zero level,
and large penalty) and a seeded sparse precision matrix using a BigFloat
objective, KKT scores and, on those fixtures, a candidate dual matrix that must
pass a BigFloat Cholesky check, with its gap compared against a roundoff
allowance. It replays one step independently,
and checks penalties with declared abstract weight types, limits, stagnation at
diagonal and off-diagonal scores, an indefinite intermediate `z`, a logdet
proximal output that fails the Cholesky check, warm starts, refusals and
numerical failures without writes to the caller's buffers.

**Sources.** [Issue #436](https://github.com/mlakolar/ProximalSolvers.jl/issues/436),
[parent issue #425](https://github.com/mlakolar/ProximalSolvers.jl/issues/425) and
[the Stage 0 report](https://github.com/mlakolar/ProximalSolvers.jl/issues/436#issuecomment-7019530001).

## [ADM-05 Least-squares lasso with a tall or square design](@id ADM-05)

**Statement.** `solve!(β, f, g, method::ADMMSolver, options=ProximalOptions(); u=nothing)`
with the raw ProximalBase loss `f = LeastSquaresLoss(y, X)` and unweighted `g = NormL1(τ)`
minimizes

```math
\tfrac12\|y-X\beta\|_2^2+\tau\|\beta\|_1 .
```

The lasso `(1/2n)‖y-Xβ‖² + λ‖β‖₁` is this problem with `τ = nλ`, and `minimum` is
then `n` times the normalized objective. A scaled loss, such as `(1/n)*LeastSquaresLoss(y, X)`,
is not accepted: the scale belongs to `τ`.

The coefficients `β`, an explicit `u` and the response `y` must be `Vector{Float64}`, and
the design `X` a `Matrix{Float64}`, all stored in `f`. Float32 data and mixed element types
are refused with an `ArgumentError`. The lengths must satisfy `length(y) == size(X,1)` and
`length(β) == size(X,2)`, and an explicit `u` must have the length of `β`; empty or
incompatible lengths raise `DimensionMismatch`. The shape must be tall or square, with
`n = size(X,1) ≥ p = size(X,2) ≥ 1`. A wide design, `n < p`, is refused with an
`ArgumentError`. Entries of `X`, `y`, `β` and an explicit `u` must be finite and `τ` finite
and nonnegative. `β`, an explicit `u`, `y` and `X` must not alias or overlap in memory, by the
check of [ADM-01](@ref), and `f` must have the internal storage that its public constructor
creates. These checks precede every write to the caller's `β` and `u`. All other settings of
[ADM-01](@ref) and [ADM-03](@ref) apply, including `α`, tolerances and `adaptive`, as do the
ownership, initial dual, commit-on-return and warm-start rules of [ADM-01](@ref).

Each iteration is the recurrence of [ADM-02](@ref) in `Float64`. The update of `x` is the
ProximalBase `prox!` of `f` with step `inv(ρ)`, which solves `(XᵀX + ρI)x = Xᵀy + ρ(z₀-u₀)`
through a thin SVD of `X`. The update of `z` is the `prox!` of `NormL1(τ)`. The SVD is
computed on the first `prox!` of `f` and is kept in `f`. Every later iteration, later solve
and other `ρ` or `τ` with the same `f` reuses it, and the solver neither copies nor resets
`f`. Therefore `f` is borrowed exclusively for each solve: no other solve or thread may use
it concurrently, and the caller must call ProximalBase `reset_cache!` on `f`, or construct a
new loss, after changing entries of `X` or `y` in place. The solver imposes no cutoff on `ρ`,
`τ` or the coefficients beyond the finiteness and range checks of [ADM-01](@ref) and
[ADM-03](@ref), and it uses no scaling or extended precision.

The residuals, tolerances, limits, counters and numerical failures are those of
[ADM-02](@ref), with `N = p`. `minimum` is `f(z) + g(z)`, evaluated once after termination.
The stationarity check of [ADM-02](@ref) at two zero residuals uses the score below in place of
the centered one. With `q = Xᵀ(Xz - y)` formed in `Float64`, the score of coordinate `j` is
`|qⱼ + τ sign(zⱼ)|` at a nonzero `zⱼ` and `max(|qⱼ| - τ, 0)` at an exact zero. A finite score
above `eps_dual` gives `status=:stagnated` and `converged=false`; a nonfinite score or `q` is a
numerical failure. The solver does not retry, rescale `ρ` or otherwise recover from that
status. A status of `:converged` reports these working-precision tests, not an optimality
certificate. Verify a fit from the data with the objective and KKT conditions of the lasso.

**Applies to.** `ADMMSolver` with a dense `Vector{Float64}` start, a raw
`LeastSquaresLoss{Float64}` with a vector response and a `Matrix{Float64}` design with
`n ≥ p`, and an unweighted `NormL1`. A wide design is outside this clause. Support for it
depends on ProximalBase and is a follow-up of [issue #458](https://github.com/mlakolar/ProximalSolvers.jl/issues/458).
The matrix path of [ADM-04](@ref) and the centered path of [ADM-01](@ref) are unchanged.

**Code.** `src/solvers/admm.jl`.

**Tests.** `test/admm_leastsquares.jl` compares with orthogonal closed forms, a correlated tall
design, an independent objective and KKT score, one iteration of the recurrence, fixed, relaxed
and adaptive settings, statuses, warm starts and refusals without writes, including the wide
design. The examples `examples/problems/lasso.jl` and `examples/comparisons/lasso_solvers.jl`
check the returned point against the closed form or an independently computed objective and
KKT violation, and the reported objective divided by `n` against the objective computed from
the data.

**Sources.** [Issue #467](https://github.com/mlakolar/ProximalSolvers.jl/issues/467) and
[issue #458](https://github.com/mlakolar/ProximalSolvers.jl/issues/458).
