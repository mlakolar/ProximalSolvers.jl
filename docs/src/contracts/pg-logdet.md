# Matrix proximal gradient for the graphical lasso

## [PGD-06 Matrix inputs and ownership](@id PGD-06)

**Statement.** `solve!(Θ, f, g, method::ProximalGradientDescent, options)` solves
the full-matrix objective in [ADM-04](@ref) with ProximalBase `f = LogDetLoss(S)`
and `g = NormL1(λ₀, Λ)`. The start is a nonempty square `Matrix{T}` for
`T ∈ {Float32, Float64}`. The stored `S` and `Λ` are `Matrix{T}` of that same
size. The three matrices have finite entries and exact symmetry by entrywise
equality. `Θ` must pass Cholesky in `T`. The loss weight must be one, `Λ` must be
nonnegative with zero diagonal, and `λ₀` must be finite, nonnegative and exactly
representable in `T`. Each effective weight `Cᵢⱼ = T(λ₀) Λᵢⱼ` must be finite.
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
the candidate gradient after its SPD and acceptance checks. The Cholesky
factor of the accepted candidate stays in the solver's scratch matrix until
the KKT diagnostic of [PGD-08](@ref) has run, and the next trial factors into
it again. The solver commits the candidate only after the gradient and KKT
diagnostics succeed. A thrown numerical error or an interrupted search leaves the
last committed SPD point in the caller's matrix. The step depends on
local comparisons because the logdet gradient has no global Lipschitz
constant on the SPD cone.

**Applies to.** Matrix PGD after preflight in [PGD-06](@ref).

**Code.** `src/solvers/logdet_proximal_gradient.jl` implements the matrix
step within `_solve_gradient!` in `src/solve.jl`.

**Tests.** `test/pgd_graphical_lasso.jl` verifies an indefinite first
trial, a nonfinite objective, finite backtracking and bounded failure,
invalid reciprocal and rollback after a completed step.

**Sources.** [Approved graphical-lasso PGD iteration](https://github.com/mlakolar/ProximalSolvers.jl/issues/444).

## [PGD-08 KKT stopping, limits and results](@id PGD-08)

**Statement.** Let `C = T(λ₀)Λ`, `aᵢ = Sᵢᵢ + Cᵢᵢ` and `sᵢ = sqrt(|aᵢ|)`, with each
root taken in `T` before any product. Under [PGD-06](@ref) `Cᵢᵢ = 0`, so `aᵢ = Sᵢᵢ`.
Entry `(i, j)` has the scale `dᵢⱼ = max(1, sᵢ sⱼ)`. A tiny or subnormal `aᵢ`
gives `dᵢⱼ = 1`. Each root is at most about `sqrt(floatmax(T))`, so `sᵢ sⱼ` overflows only
if both `aᵢ` and `aⱼ` are within a few `eps(T)` of `floatmax(T)`. At a committed point, with `G = S - inv(Θ)` as in
[PGD-07](@ref), the violation `rᵢⱼ` of entry `(i, j)` is
`abs(Gᵢⱼ + Cᵢⱼ sign(Θᵢⱼ))` where `Θᵢⱼ ≠ 0`, the diagonal included, and
`max(abs(Gᵢⱼ) - Cᵢⱼ, 0)` at exact zeros. The KKT score is
`R = maxᵢⱼ rᵢⱼ / dᵢⱼ`. Each violation, scale and quotient is evaluated in `T`, over the
upper triangle, which repeats the lower because `Θ`, `S`, `Λ` and the symmetrized `G` are
exactly symmetric. `g_residual` is `R` as a `Float64`. It is a violation relative
to the entry's own scale, not a maximum absolute violation: the two agree where
every `dᵢⱼ` is one. The scale of entry `(i, j)` depends only on `aᵢ` and `aⱼ`, so a weight or an
off-diagonal entry of `S` elsewhere, or a large `aₖ` with `k ∉ {i, j}`, does not enter it.
Nonfinite violations raise an error. After a completed step, convergence requires
`g_residual ≤ g_tol`, where `g_tol = max(gradtol, 64eps(T))`. The check is
independent of the trial step and the iterate and objective change tests. An accepted
elementwise unchanged point outside the KKT threshold sets
`stagnated=true` and `converged=false`.

**Cancellation path.** Preflight sets a flag if some stored `abs(Sᵢⱼ)` exceeds
`2 max(1, sᵢ sⱼ)`, the diagonal included. A positive semidefinite `S` has
`abs(Sᵢⱼ) ≤ sqrt(Sᵢᵢ Sⱼⱼ) = sᵢ sⱼ` under [PGD-06](@ref), so it does not set the
flag unless the rounding of its stored entries exceeds the factor two. An indefinite
`S` can set it. With the flag set, the start and each committed point first rebuild
`W = inv(Θ)` in place from the upper Cholesky factor that the SPD check of that point
left in the solver's scratch matrix ([PGD-07](@ref)), and `rᵢⱼ` is formed from the inputs and `W`:
`abs((Sᵢⱼ + Cᵢⱼ sign(Θᵢⱼ)) - Wᵢⱼ)` where `Θᵢⱼ ≠ 0`, and
`max((Sᵢⱼ - Cᵢⱼ) - Wᵢⱼ, Wᵢⱼ - (Sᵢⱼ + Cᵢⱼ), 0)` at exact zeros. The input
combination is evaluated in `T` before `Wᵢⱼ` is subtracted. An entry whose input
combination is not finite uses the form from `G`. The path adds one inverse from an existing
factor to each evaluation; with the flag clear, the evaluation is the single pass above.

**Limits.**
- Where `abs(Sᵢⱼ)` is far above `dᵢⱼ`, the step `Θ - tG` uses `G` as ProximalBase rounds it. That
  rounding is about `eps(T) abs(Sᵢⱼ)` in `Gᵢⱼ`, so the iterate typically does not settle closer than
  about `eps(T) t abs(Sᵢⱼ)` to a stationary point. Such solves typically end by stagnation or a limit with
  `converged=false`.
- `Wᵢⱼ` carries the rounding of the Cholesky inverse, which grows with the condition number of `Θ`.
  The score has that absolute error.
- Where a diagonal weight would cancel a negative `Sᵢᵢ`, state the problem as `S + Diagonal(C)` with
  zero diagonal weight.

The matrix rule does not copy the per-entry scale `max(cᵢ, λmax)` of [STOP-03](@ref). A
penalty term in the scale lets a cancelled diagonal pass: with `Sᵢᵢ = -2³²` and `Cᵢᵢ = 2³² + 1`, at `Θᵢᵢ = 3/2`
the violation `1/3` over a scale near `2³²` is about `7.8e-11`, below `gradtol = 5e-10`. The entry scale
`abs(Sᵢᵢ + Cᵢᵢ)` is unchanged by the shift to `S + Diagonal(C)`. The measurements behind the rule are
in the [evidence page](@ref evidence-kkt-scale-492).

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

**Code.** `src/solvers/logdet_proximal_gradient.jl` supplies the entry scales,
the cancellation flag, the KKT score and the rounding-stall checks.
`_solve_gradient!` in `src/solve.jl` handles limit exits and constructs
`OptimizationResults`.

**Tests.** `test/pgd_graphical_lasso.jl` independently checks SPD, primal
objective, the entrywise KKT score and a feasible dual lower bound for analytic
and seeded problems. It also tests reported counters, a verified fixed point, a
rounded Float32 stall outside the threshold and limit precedence. A call
limit during a rejected trial checks that the shared driver keeps the last
accepted point and its diagnostics. `test/logdet_kkt_scale.jl` checks the
scales, the flag and both evaluation paths against 256-bit BigFloat references
computed from the stored data: the reported `g_residual` at fixed points, each
converged solve of its problems against the stop rule, the analytic optima of the 2 × 2
fixtures, seeded heterogeneous and ordinary problems, a power-of-two rescaling
and the `2^51` numerator in both precisions. It also checks that the evaluation
allocates nothing that grows with the dimension.

**Sources.** [Approved graphical-lasso PGD stopping rule](https://github.com/mlakolar/ProximalSolvers.jl/issues/444).
[Entrywise KKT normalization](https://github.com/mlakolar/ProximalSolvers.jl/issues/492).
