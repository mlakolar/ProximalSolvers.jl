# Benchmarks and performance

The documentation makes no formal ranking of solvers by speed. The times printed on the
tutorial pages and on the [solver comparison](examples/comparisons/lasso_solvers.md) are
illustrative: each comes from one machine in one run of the documentation build, on one
problem. They show how to compare solvers at equal accuracy and are not evidence that one
solver is faster than another on other problems, machines or settings.

## Where the formal evidence is

The repository's `benchmark/` directory holds the harness for formal records. It measures
the accuracy of a returned point with certificates that do not depend on a solver's stopping
rule, writes records that a validator checks, and uses A/A noise controls in its A/B
comparisons: a comparison of a revision with itself, which measures the noise of a measurement.
Its documentation is in the repository:

- [benchmark/README.md](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/benchmark/README.md),
  the layout, what runs against master and how to run it;
- [benchmark/HARNESS.md](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/benchmark/HARNESS.md),
  the record format, the certificates and the checks.

A statement about the speed of one solver relative to another needs such a record, at the same
independently measured accuracy, and this documentation does not make one.

## Historical observations

The [strict-accuracy configuration](@ref EVIDENCE-STRICT-01),
[lazy-curvature measurements](@ref evidence-lazy-curvature-cost), and
[cached-residual investigation](@ref evidence-cached-residual-378) retain the
context of earlier measurements. Read their stated problems and environments
before using them to choose a configuration.
