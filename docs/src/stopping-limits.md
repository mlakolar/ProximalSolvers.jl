# Limits of the stopping tests

This page keeps its published links. The full material is now organized in Learn and Contracts.

See the [current section](@ref evidence-stopping-352).

## Select stopping conditions in dense least-squares PGD

Use `stopping` to choose a condition and `limits=MaxIterations(n)` to cap the
number of accepted updates. These keywords also apply to `AccProxGradDescent`
on the supported dense least-squares route. `AnyOf` accepts the first passing condition.
`AllOf` needs its conditions to pass at the same checkpoint. `IterateChange`
and `ObjectiveChange` measure progress between accepted points. `UserStop`
accepts a predicate over scalar checkpoint metadata. With `NormL1` or
`ElasticNet`, `ScaledKKT(rtol=...)` checks computed coordinatewise stationarity.
The [stopping contract](@ref STOP-22) specifies the comparison scales, option
conflicts and checks available at the cap.

```julia
using ProximalBase, ProximalSolvers

X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
x = zeros(2)
rule = AllOf(IterateChange(atol=1e-10, rtol=1e-7),
             ScaledKKT(rtol=1e-5))
r = solve!(x, LeastSquaresLoss(y, X), NormL1(0.1),
           ProximalGradientDescent(); stopping=rule, limits=MaxIterations(200))
termination(r)
```

`termination(r).satisfied` says whether the selected expression passed.
`r.converged` is true when the winning branch includes a passing `ScaledKKT`.
The [result contract](@ref RES-04)
describes the stop reason, winning leaves, observations and counts. Omit both
keywords to use the solver’s default stopping policy.

At the [iteration cap](@ref STOP-22), a tie can use stored objective values.
`ScaledKKT`, `IterateChange` and `UserStop` are marked `:not_checked` there.
A solve using `ScaledKKT` alone reports `reason = :limit` and
`converged = false` if it reaches the cap. In APG, an evaluated KKT check
uses the gradient at the accepted point and includes its cost in the
[oracle counts](@ref APG-04).

## [Cap the evaluations in dense least-squares PGD](@id pgd-evaluation-limits)

Use a single call limit or a tuple to cap multiple kinds of work.
`MaxObjectiveEvaluations` counts smooth loss values, and
`MaxGradientEvaluations` counts full gradients. A fused evaluation uses one
of each. `MaxProximalEvaluations` counts the penalty's proximal calls,
including any trials the line search discards.

~~~@example pgd_evaluation_limits
using ProximalBase, ProximalSolvers

x = zeros(1)
f = LeastSquaresLoss([1.0], ones(1, 1))
method = ProximalGradientDescent(ls=ProximalSolvers.LineSearches.BackTracking(α=1.0))
r = solve!(x, f, NormL1(0.0), method;
           limits=(MaxIterations(20), MaxObjectiveEvaluations(4)))
@assert x == [1.0] && r.iterations == 1
@assert termination(r).counts.f_calls == 4
@assert termination(r).reached_evaluation_limits == (MaxObjectiveEvaluations(4),)
termination(r)
~~~

The second trial uses the last smooth value. PGD returns the first accepted
point because completing the second update needs one more smooth value as
part of a fused gradient call. The report counts work on both trials.
See [STOP-23](@ref) for admission and [RES-04](@ref) for the report fields.

## [Cap the evaluations in dense least-squares APG](@id apg-evaluation-limits)

`AccProxGradDescent` accepts the same hard call limits. A line search can
reuse its last gradient for several proximal trials. If acceleration requires a
restart, APG checks the remaining budget before evaluating the restart gradient.

~~~@example apg_evaluation_limits
using ProximalBase, ProximalSolvers

x = zeros(1)
f = LeastSquaresLoss([1.0], ones(1, 1))
r = solve!(x, f, NormL1(0.0), AccProxGradDescent(α=0.75, β=0.375);
           limits=(MaxGradientEvaluations(1), MaxProximalEvaluations(2)))
@assert x == [0.5] && r.iterations == 1
@assert termination(r).counts.grad_calls == 1
@assert termination(r).counts.prox_calls == 2
termination(r)
~~~

The search evaluates one gradient and takes two trials. It accepts the
second and reports both caps. If you add a `ScaledKKT` rule, evaluating
stationarity at the accepted point can require its own smooth value and
gradient. See [STOP-24](@ref) for when that work is allowed.

## [Select stopping conditions in scalar coordinate descent](@id cd-select-stopping)

For dense vector least-squares lasso with unweighted `NormL1`, turn momentum off
and pass a rule, a pass budget, or both. A full sweep visits all coefficients.
An active sweep revisits the active coordinates. Both count toward `MaxPasses`.
`ObjectiveChange` compares consecutive full sweeps. `UserStop` can run after
either kind of sweep before the cap.

~~~@example explicit_cd_stopping
using ProximalBase, ProximalSolvers

X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
x = zeros(2)
r = solve!(x, LeastSquaresLoss(y, X), NormL1(0.5),
           CDSolver(order=:cyclic, momentum=false);
           stopping=ObjectiveChange(), limits=MaxPasses(20))
@assert x == [1.5, -0.875]
@assert termination(r).satisfied
@assert termination(r).counts.full_passes == 2
termination(r)
~~~

The orthogonal columns give the lasso solution `[1.5, -0.875]` on the first
full sweep. The next full sweep has the same objective and satisfies the rule.
Read `termination(r).satisfied` for progress and `termination(r).counts` for
full passes, active passes, visits, and objective evaluations. Check
[full-point stationarity](@ref learn-02) when accuracy matters.
[CD-10](@ref) specifies the checkpoints and their cost.

## [Select stopping conditions in consensus ADMM](@id admm-select-stopping)

For a centered quadratic with an unweighted L1 penalty, use a fixed-penalty
`ADMMSolver` and select either or both native residual tests. The solver
checks them after a complete iteration. The thresholds come from the
solver's `abstol`, `abstol_dual` and `reltol` settings.

~~~@example explicit_admm_stopping
using ProximalBase, ProximalSolvers

z = zeros(1)
f = SqrNormL2(1.0, [3.0])
g = NormL1(1.0)
r = solve!(z, f, g, ADMMSolver(abstol=1e-8, reltol=0.0);
           stopping=AllOf(PrimalResidual(), DualResidual()), limits=MaxIterations(100))
@assert isapprox(z, [2.0]; atol=1e-7, rtol=0.0)
@assert r.converged
termination(r)
~~~

`AllOf` requires both tests to pass. The report gives the residuals and
thresholds for the evaluated leaves, and records any tie with a limit.
For a warm start, keep the returned consensus variable, scaled dual `r.u`
and penalty `r.ρ` together. See [ADM-06](@ref) for when the tests run and
[RES-06](@ref) for the result fields.

Use `limits=(MaxIterations(100), MaxProximalEvaluations(3))` to set both
caps. A complete ADMM iteration takes two proximal calls. A cap of three
therefore permits one iteration, and the report lists the reached
`MaxProximalEvaluations(3)` with `counts.prox_calls == 2`. A residual rule
can still pass on that iteration. See [ADM-07](@ref).

~~~@example explicit_admm_stopping
z_budget = zeros(1)
cap = MaxProximalEvaluations(3)
limited = solve!(z_budget, f, g, ADMMSolver();
                 limits=(MaxIterations(100), cap))
@assert z_budget == [0.5] && limited.u == [1.0]
@assert termination(limited).counts.prox_calls == 2
@assert termination(limited).reached_evaluation_limits == (cap,)
termination(limited)
~~~

## The criterion and a certificate

See the [current section](@ref RES-01). For PGD and APG on least squares with a
dense vector response and `NormL1` or `ElasticNet`, a kept stop records that each coordinate's computed score
passed the rule: below its computed threshold, or at most `0` at an exact zero scale,
where no threshold is formed. In exact arithmetic the same comparison would bound
the decrease available from each coordinate of the model that the check scores,
under the conditions of [STOP-21](@ref) (that model is the objective of the solve
when their coefficients agree); neither bounds the error of the objective or the coefficients in
general, and an exact or near-exact fit can return `converged = false`. The matrix-response
lasso of [IN-10](@ref) keeps the `λmax`-based check of [STOP-03](@ref). For square-root lasso, a bounded
fallback can certify an uncertified stopped point or return a point with a
proved lower objective; recovery at exact fits is not guaranteed. See the
[bounded recovery rule](@ref CDQ-05).

## What the change test of coordinate descent implies

See the [current section](@ref CD-06).

## Products formed in working precision

See the [current section](@ref FP-01).

## A warm start far above the solution scale (coordinate descent)

See the [current section](@ref CD-07).

### The cached residual

See the [current section](@ref CD-05).

### What the study of issue #378 measured

See the [current section](@ref evidence-cached-residual-378).

### No change to the solver

See the [current section](@ref evidence-cached-residual-378).

## Float32

See the [current section](@ref evidence-stopping-352).

## `ftol = 0` at a fixed point

See the [current section](@ref STOP-15).
