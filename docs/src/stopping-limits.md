# Limits of the stopping tests

This page keeps its published links. The full material is now organized in Learn and Contracts.

See the [current section](@ref evidence-stopping-352).

## The criterion and a certificate

See the [current section](@ref RES-01). For PGD and APG on least squares with
`NormL1` or `ElasticNet`, a kept stop records that each coordinate's computed score
passed the rule: below its computed threshold, or at most `0` at an exact zero scale,
where no threshold is formed. In exact arithmetic the same comparison would bound
the decrease available from each coordinate, under the conditions of
[STOP-21](@ref); neither bounds the error of the objective or the coefficients in
general, and an exact or near-exact fit can return `converged = false`. For square-root lasso, a bounded
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
