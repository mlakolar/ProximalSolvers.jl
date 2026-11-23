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

**Statement.** Let `C = T(λ₀)Λ`, `aᵢ = Sᵢᵢ + Cᵢᵢ` and `sᵢ = sqrt(|aᵢ|)`, with the sum and each root
computed in `T`, each root before any product. [PGD-06](@ref) requires every `aᵢ` to be finite. Entry
`(i, j)` has the scale `dᵢⱼ = max(1, sᵢ sⱼ)`, computed in `T`. At the start and at each committed
point the score is `R = maxᵢⱼ rᵢⱼ / dᵢⱼ` over the upper triangle (`Θ`, `S`, `Λ` and the symmetrized
`G` are exactly symmetric), where `rᵢⱼ` is the violation of entry `(i, j)` defined below. The score is
relative to each entry's own scale. `g_residual` is `Float64(R)`, and a nonfinite score raises an
error. After a completed step, convergence requires `g_residual ≤ g_tol`, where
`g_tol = max(gradtol, 64eps(T))`. The check is independent of the trial step and of the iterate and
objective change tests. An accepted elementwise unchanged point outside the KKT threshold sets
`stagnated=true` and `converged=false`.

**First pass.** With `G = S - inv(Θ)` symmetrized as in [PGD-07](@ref), the first-pass violation of
entry `(i, j)`, diagonal included, is evaluated in `T` as `rᵢⱼ = |Gᵢⱼ + Cᵢⱼ sign(Θᵢⱼ)|` where
`Θᵢⱼ ≠ 0` and `rᵢⱼ = max(|Gᵢⱼ| - Cᵢⱼ, 0)` where `Θᵢⱼ = 0`.

**Uncertainty test.** This is a heuristic test on computed values, evaluated in `T` for each entry of
the upper triangle. Let `c̃ᵢⱼ = Cᵢⱼ` if `Θᵢⱼ ≠ 0` or `2|Gᵢⱼ| ≥ Cᵢⱼ`, and `c̃ᵢⱼ = 0` otherwise, and let
`mᵢⱼ = (|Sᵢⱼ| + |Gᵢⱼ|) + c̃ᵢⱼ`. The entry is uncertain if `mᵢⱼ T(0.25) > dᵢⱼ`. An `mᵢⱼ` that
overflows is uncertain.

**Evaluation from the inputs.** If some entry is uncertain, `W = inv(Θ)` is rebuilt in place from the
upper Cholesky factor that the SPD check of that point left in the solver's scratch matrix
([PGD-07](@ref)); this adds one inverse computed from an existing factor. The pass then attempts to
evaluate the violation of every entry from `Sᵢⱼ`, `Wᵢⱼ` and `Cᵢⱼ` without forming `Sᵢⱼ ± Cᵢⱼ`. All
operations are in `T`. `TwoSum` is Knuth's algorithm, an exact decomposition under round-to-nearest
with gradual underflow when both of its outputs are finite. Let `(h, l) = TwoSum(Sᵢⱼ, -Wᵢⱼ)`.
- At a nonzero `Θᵢⱼ`, let `(h2, l2) = TwoSum(h, Cᵢⱼ sign(Θᵢⱼ))`. Then `rᵢⱼ = |h2 + (l + l2)|`.
- At a zero, let `(u, lu) = TwoSum(h, -Cᵢⱼ)` and `(v, lv) = TwoSum(-h, -Cᵢⱼ)`. Then
  `rᵢⱼ = max(u + (lu + l), v + (lv - l), 0)`.

The additions of the recombinations round. Three cases handle nonfinite terms:
1. If `h` or `l` is not finite, the entry takes its first-pass violation.
2. At a zero, each side is handled separately. If its high term (`u` or `v`) is not finite, the side
   is `-Inf` and its first-pass value, `Gᵢⱼ - Cᵢⱼ` or `-Gᵢⱼ - Cᵢⱼ`, is discarded. If the high term
   is finite but the recombination is not, the side takes that first-pass value.
3. At a nonzero `Θᵢⱼ`, if `h2 + (l + l2)` is not finite, the entry takes its first-pass violation.

**Limits.** These are possibilities, not guarantees.
- Where `|Sᵢⱼ|` is large relative to `dᵢⱼ`, the step `Θ - tG` uses `G` as ProximalBase rounds it, so a
  solve can end by stagnation or at a limit with `converged=false`, as the cancellation runs recorded
  on the [evidence page](@ref evidence-kkt-scale-492) did.
- Rounding in the computed `inv(Θ)` can change the violation and the normalized score, in either pass,
  and this rule does not bound it.
- Where a diagonal weight cancels a negative `Sᵢᵢ`, state the problem as `S + Diagonal(C)` with zero
  diagonal weight.

The evidence page also records the comparison with the per-entry scale of [STOP-03](@ref), the
[Float32 convergence loss](@ref evidence-kkt-scale-492-float32) and the
[timing](@ref evidence-kkt-scale-492-performance) of the rule.

`OptimizationResults.minimizer` aliases the caller's matrix.
`minimum` is `f(Θ) + g(Θ)` there. `x_residual` is
`‖Z - Θ_previous‖_F`, and `f_residual` follows the relative objective
change in [RES-02](@ref). Both are `NaN` before the first completed step.
`x_converged` and `f_converged` require convergence and their respective
change to be below the tolerance. `ftol=0` disables the objective proposal.
`grad_converged` equals `converged`. `f_increased` records an actual
increase on the last completed step, which can occur within the comparison
allowance. The trace is empty, `gap=NaN` and `approximate_solution=false`.

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

**Tests.** `test/pgd_graphical_lasso.jl` checks, in Float32 and Float64, the returned points of
analytic and seeded problems with zero and positive diagonal weights against BigFloat recomputations
of positive definiteness, the primal objective, the entrywise score and a numerical estimate of a dual
lower bound. These are those of the problem with the rounded effective coefficients `T(λ₀)Λ`, which
is the original problem for the fixtures whose coefficient products are exact (`test/TESTING.md` lists
the fixtures). It compares the reported score with the recomputed one, for direct PGD and for PGD on
the covariance-shifted problem, and checks reported counters, the diagonal score at a start with a
positive diagonal weight, the convergence flags at a known fixed point, a rounded Float32 stall outside
the threshold and limit precedence. A call limit during a rejected trial checks the retained iterate, the
reported objective and the `x` and `f` residuals. On its fixtures, `test/logdet_kkt_scale.jl` checks
the reported start score at prescribed points against the definition, the stop rule at the converged
solves of its seeded heterogeneous and ordinary problems, two inputs on which the first pass rounds a
decisive violation to zero (a cancellation of `W` against a weight where `S` is small, with one sign,
and a zero entry with an overflowing unused endpoint, with both signs, each in both precisions), the
diagonal-weight cancellation cases and the `2^51` numerator through `solve!` (the Float32 case is an
analogue), the direct and covariance-shifted formulations, and a power-of-two rescaling where the unit
floor is inactive. It also asserts directly on the scales, the uncertainty test and the evaluation of single
entries, and compares the allocation of warmed evaluations at dimensions 12 and 36. Its BigFloat
references use 256 bits, and 2048 bits for the two inputs above as a chosen reference precision. Its
analytic values are exact-arithmetic references, and its BigFloat scores are reported after conversion
to Float64 and compared with an allowance for the rounding of the computed score.

**Sources.** [Approved graphical-lasso PGD stopping rule](https://github.com/mlakolar/ProximalSolvers.jl/issues/444).
[Entrywise KKT normalization](https://github.com/mlakolar/ProximalSolvers.jl/issues/492).
