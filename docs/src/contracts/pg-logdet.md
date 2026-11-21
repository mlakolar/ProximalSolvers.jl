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
`Cᵢⱼ = T(λ₀) Λᵢⱼ`, diagonal included, must be finite, and so must each sum
`Sᵢᵢ + Cᵢᵢ` evaluated in `T`.
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
weights, a diagonal effective weight that overflows in `T` and a diagonal sum
`Sᵢᵢ + Cᵢᵢ` that overflows in `T`.

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
factor of the accepted candidate is in the solver's scratch matrix at entry to
the KKT diagnostic of [PGD-08](@ref). That diagnostic overwrites it with the
inverse when it takes its uncertain path, and the next trial that reaches its
factorization writes it again. A trial can fail before it factors, on a
nonfinite argument or a nonfinite or nonsymmetric proposal. The solver commits the candidate only after the gradient and KKT
diagnostics succeed. A thrown numerical error or an interrupted search leaves the
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

**Statement.** Let `C = T(λ₀)Λ`, `aᵢ = Sᵢᵢ + Cᵢᵢ` and `sᵢ = sqrt(|aᵢ|)`, with each
root taken in `T` before any product. Entry `(i, j)` has the scale
`dᵢⱼ = max(1, sᵢ sⱼ)`. A subnormal `aᵢ` does not by itself give a unit scale: in Float64,
`aᵢ = prevfloat(floatmin(Float64))` with `aⱼ = 0.75 floatmax(Float64)` gives `dᵢⱼ ≈ sqrt(3)`.
Under round-to-nearest, `sqrt(floatmax(T))` rounds below the next power of two in both supported
formats and its square is finite, so the root product does not overflow; an underflowing product is
below the unit floor. An infinite sum `aᵢ` would give an infinite scale, or a NaN scale (`Inf·0`) next
to a zero root; the finiteness guard of [PGD-06](@ref) prevents both.
At a committed point, with `G` the symmetrized gradient `S - inv(Θ)` of [PGD-07](@ref), the
violation `rᵢⱼ` of entry `(i, j)` is `abs(Gᵢⱼ + Cᵢⱼ sign(Θᵢⱼ))` where `Θᵢⱼ ≠ 0`, and
`max(abs(Gᵢⱼ) - Cᵢⱼ, 0)` at exact zeros. The start and each committed point have passed
Cholesky in `T`, so their diagonal entries are positive and the diagonal violation is
`abs(Gᵢᵢ + Cᵢᵢ)`; with `Cᵢᵢ = 0` it is `abs(Gᵢᵢ)`. The KKT score is `R = maxᵢⱼ rᵢⱼ / dᵢⱼ`.
Each violation, scale and quotient is evaluated in `T`, over the upper triangle, which repeats
the lower because `Θ`, `S`, `Λ` and the symmetrized `G` are exactly symmetric. `g_residual` is
`R` as a `Float64`. It is a violation relative to the entry's own scale, not a maximum absolute
violation: the two agree where every `dᵢⱼ` is one. The scale of entry `(i, j)` depends only on
`aᵢ` and `aⱼ`, so a weight or an off-diagonal entry of `S` elsewhere, or a large `aₖ` with
`k ∉ {i, j}`, does not enter it. The score that the solver keeps is checked for finiteness, and a
nonfinite score raises an error: the score from `G` when no entry is uncertain, otherwise the score
from the inputs. After a completed step, convergence requires `g_residual ≤ g_tol`, where `g_tol = max(gradtol, 64eps(T))`. The check is
independent of the trial step and the iterate and objective change tests. An accepted
elementwise unchanged point outside the KKT threshold sets
`stagnated=true` and `converged=false`.

**Uncertain entries and the evaluation from the inputs.** The violations above come from `G`,
which carries the rounding of `Sᵢⱼ - (Θ⁻¹)ᵢⱼ`. For each entry the solver evaluates, in `T`, from
the stored `Sᵢⱼ` and the computed `Gᵢⱼ`,
`mᵢⱼ = |Sᵢⱼ| + |Gᵢⱼ| + c̃ᵢⱼ`, where `c̃ᵢⱼ = Cᵢⱼ` at a nonzero `Θᵢⱼ` and at a zero with
`|Gᵢⱼ| ≥ Cᵢⱼ/2`, and `c̃ᵢⱼ = 0` at a zero with `|Gᵢⱼ| < Cᵢⱼ/2`. The entry is *uncertain* if
`mᵢⱼ/4 > dᵢⱼ`; an overflowing `mᵢⱼ` is uncertain. The rationale is an estimate, not a proof.
Starting from the working inverse, the violation from `G` is a few roundings of terms bounded by
`mᵢⱼ`, so the absolute error of that arithmetic is about `2eps(T) mᵢⱼ`; below the threshold that is
at most about `8eps(T) dᵢⱼ`, an eighth of the floor of `g_tol`. The error of the working inverse
itself also enters `G` and the score, and this estimate does not cover it (see the limits). At a zero
with `|Gᵢⱼ| < Cᵢⱼ/2` the computed violation is 0, and the true one is 0 when the error of `|Gᵢⱼ|` is
below `Cᵢⱼ/2`. The test uses stored entries and the computed `G`. The mathematical root product of a
stored positive semidefinite `S` satisfies `|Sᵢⱼ| ≤ sqrt(Sᵢᵢ Sⱼⱼ) ≤ sqrt(aᵢ aⱼ)`, because
`aᵢ = Sᵢᵢ + Cᵢᵢ ≥ Sᵢᵢ ≥ 0` under the nonnegative weights of [PGD-06](@ref). The rounded product
`sᵢ sⱼ` can be slightly below `|Sᵢⱼ|`: stored `S = [3 3; 3 3]` with zero weights gives
`2.9999999999999996` in Float64. Data rounded before storage can also be indefinite, and a large
near-active weight gives a large `Gᵢⱼ`. Where `S` is small but `Wᵢⱼ` and the weight are both large (the
unit floor lets a small diagonal pass), `|Gᵢⱼ|` is about `|Wᵢⱼ|` and the entry is uncertain.

If no entry is uncertain, `g_residual` is the single pass above. If one is, `W = inv(Θ)` is
rebuilt in place from the upper Cholesky factor that the SPD check of that point left in the
solver's scratch matrix ([PGD-07](@ref)), and the violation of every entry is evaluated from `Sᵢⱼ`,
`Wᵢⱼ` and `Cᵢⱼ` by two-sums, without forming `Sᵢⱼ ± Cᵢⱼ` and subject to the fallback below. With
`x = Sᵢⱼ - Wᵢⱼ` written as `h + l` (Knuth's two-sum, written without `@fastmath`, which permits
reassociation, or `muladd`, which permits contraction; the decomposition is exact when `h` and `l`
are both finite, and the final recombination rounds):
- at a nonzero `Θᵢⱼ`, `rᵢⱼ = |x + Cᵢⱼ sign(Θᵢⱼ)|`, with `h + Cᵢⱼ sign(Θᵢⱼ)` also an error-free sum;
- at a zero, `rᵢⱼ = max(x - Cᵢⱼ, -x - Cᵢⱼ, 0)`, each side from its own error-free sum. With a finite
  `Wᵢⱼ`, a side whose sum overflows outward is negative and cannot be violated, so it contributes
  zero and does not discard the other side.

A term that is not finite sends that entry (that side of a zero entry) back to the value from `G`. For
example, with `M = floatmax(T)` and `u = M - prevfloat(M)`, the two-sum of `1.5u` and `-M` has a finite
high term and a NaN low term in Float32 and Float64, so `Sᵢⱼ = 1.5u` with `Wᵢⱼ = M` takes the value from
`G`. Where no fallback applies, the evaluation from the inputs has a relative error of a few `eps(T)` in
the violation, plus the error of `Wᵢⱼ`; an entry that takes the fallback has the error of the form from
`G`. The uncertain path adds one inverse from an existing factor to the evaluations that take it. The
factor is then overwritten, and the next trial that reaches its factorization writes it again.

**Limits.**
- Where `|Sᵢⱼ|` is far above `dᵢⱼ`, the step `Θ - tG` uses `G` as ProximalBase rounds it. That rounding
  is about `eps(T) |Sᵢⱼ|` in `Gᵢⱼ`, so the iterate can lose resolution of about `eps(T) t |Sᵢⱼ|`. A solve may
  then end by stagnation or at an iteration limit with `converged=false`. The off-diagonal cases measured in
  `test/logdet_kkt_scale.jl` did, while its `1 × 1` diagonal cases converged.
- `Wᵢⱼ` carries the rounding of the Cholesky inverse. Its error follows the sensitivity of `Θ`, and the
  score has that error in either evaluation. For `Θ = [2 2; 2 nextfloat(T(2))]` with `S` equal to its stored
  Cholesky inverse and no penalty, `g_residual = 0` and the solve reported `converged=true` in both
  precisions, against independent scores of about 0.5 (Float32) and 1 (Float64). The inverse in `T` does not
  resolve that point.
- Where a diagonal weight cancels a negative `Sᵢᵢ`, state the problem as `S + Diagonal(C)` with
  zero diagonal weight, so that the sum is formed once in `T`.

The matrix rule does not copy the per-entry scale `max(cᵢ, λmax)` of [STOP-03](@ref). A
penalty term in the scale lets a cancelled diagonal pass: with `Sᵢᵢ = -2³²` and `Cᵢᵢ = 2³² + 1`, at `Θᵢᵢ = 3/2`
the violation `1/3` over a scale near `2³²` is about `7.8e-11`, below `gradtol = 5e-10`. The entry scale
`abs(Sᵢᵢ + Cᵢᵢ)` is unchanged by the shift to `S + Diagonal(C)`. The measurements behind the rule are
in the [evidence page](@ref evidence-kkt-scale-492); its [Float32 section](@ref evidence-kkt-scale-492-float32)
and [timing section](@ref evidence-kkt-scale-492-performance) record a Float32 convergence loss and the cost
of the rule on ordinary problems.

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
the uncertainty test, the two evaluations of the KKT score and the rounding-stall checks.
`_solve_gradient!` in `src/solve.jl` handles limit exits and constructs
`OptimizationResults`.

**Tests.** `test/pgd_graphical_lasso.jl` checks, in Float32 and Float64, the
returned points of analytic and seeded problems with zero and positive diagonal
weights. It recomputes positive definiteness, the primal objective and the entrywise
KKT score in BigFloat, together with a numerical estimate of a dual lower bound. These are
those of the problem with the rounded effective coefficients `T(λ₀)Λ`, which is the original
problem for the fixtures whose coefficient products are exact; `test/TESTING.md` lists the
fixtures. It also compares the reported KKT score with the recomputed one, for
direct PGD and for PGD on the covariance-shifted problem. The tests also check reported
counters, the diagonal KKT score at a start with a positive diagonal weight, the
convergence flags at a known fixed point, a rounded Float32 stall outside the threshold and
limit precedence. A call limit during a rejected trial checks the retained iterate, the
reported objective and the `x` and `f` residuals. `test/logdet_kkt_scale.jl` uses analytic
values for the 2 × 2 and 1 × 1 fixtures and for two inputs on which the form from `G` rounds a
decisive violation to zero: a cancellation of `W` against a weight where `S` is small (one sign,
both precisions) and a zero entry with an overflowing unused endpoint (both signs, both
precisions). It also uses direct assertions on the scales, the uncertainty test and the
evaluation of single entries, and BigFloat scores at fixed points and at returned points where
stated (an estimate of the rounding of the computed score is allowed; the two inputs above use
2048 bits, for the condition number of the first and for the exponent gap between the weight
and `1/4` in the second, whose iterate is well conditioned). It covers the diagonal-weight cancellation cases and the `2^51` numerator through
`solve!` (the Float32 case is an analogue), the direct and covariance-shifted formulations,
seeded heterogeneous and ordinary problems, and a power-of-two rescaling on its fixtures. It also
compares the allocation of warmed evaluations at dimensions 12 and 36.

**Sources.** [Approved graphical-lasso PGD stopping rule](https://github.com/mlakolar/ProximalSolvers.jl/issues/444).
[Entrywise KKT normalization](https://github.com/mlakolar/ProximalSolvers.jl/issues/492).
