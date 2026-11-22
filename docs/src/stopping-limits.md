# Limits of the stopping tests

This page keeps its published links. The full material is now organized in Learn and Contracts.

See the [current section](@ref evidence-stopping-352).

## Select stopping conditions in dense least-squares PGD

Use `stopping` to choose a condition and `limits=MaxIterations(n)` to cap the
number of accepted updates. `AnyOf` accepts the first passing condition.
`AllOf` needs its conditions to pass at the same checkpoint. `IterateChange`
and `ObjectiveChange` measure progress between accepted points. `UserStop`
accepts a predicate over scalar checkpoint metadata. The [stopping contract](@ref STOP-21)
specifies the comparison scales, option conflicts and checks available at the cap.

```julia
using ProximalBase, ProximalSolvers

X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
x = zeros(2)
rule = AllOf(IterateChange(atol=1e-10, rtol=1e-7),
             ObjectiveChange(rtol=1e-8))
r = solve!(x, LeastSquaresLoss(y, X), NormL1(0.1),
           ProximalGradientDescent(); stopping=rule, limits=MaxIterations(200))
termination(r)
```

`termination(r).satisfied` says whether the selected expression passed. A
progress or user stop leaves `r.converged` false. The [result contract](@ref RES-04)
describes the stop reason, winning leaves, observations and counts. Omit both
keywords to use the default PGD stopping policy.

## The criterion and a certificate

See the [current section](@ref RES-01). For square-root lasso, a bounded
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
