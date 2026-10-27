# Optional independent oracles

`quic_hypatia.jl` compares QUIC with Hypatia's log-det cone through JuMP.
It uses four small problems (`p = 3, 6`, with and without diagonal penalties),
checks each solution's positive definiteness and proximal KKT residual, and
compares independently evaluated objectives and coefficients. These are
numerical reference solutions, not symbolic exact solutions.

The optional environment keeps Hypatia, JuMP and MathOptInterface out of the
main package and its normal tests. Run setup and execution on dedicated
hardware or a cluster (Slurm), with one Julia/BLAS thread.
From the repository root, with `PROXIMALBASE_SNAPSHOT` set to the desired
ProximalBase checkout:

```sh
julia --startup-file=no --project=test/oracles -e 'using Pkg;
    Pkg.develop(path=pwd());
    Pkg.develop(path=ENV["PROXIMALBASE_SNAPSHOT"]); Pkg.instantiate()'
julia --startup-file=no --project=test/oracles test/oracles/quic_hypatia.jl
```

A historical run, `20261024T1258Z-ps-issue22`, passed **44/44**
assertions on Julia 1.13.2, Hypatia 0.11.0, JuMP 1.32.1 and MOI 1.54.0.
The tested oracle source was `ff1b581`, with ProximalBase pinned to
`a866768afcca653503af7b174d2fabc3b7c38466`. The largest absolute objective
difference was `1.95e-12`; Hypatia's largest proximal residual was `1.91e-7`.
An earlier attempt at conic tolerances `1e-9` passed the objective comparison
but missed the requested KKT target in two cases. The retained passing run
uses `1e-12` conic tolerances. The log records both solver versions and every
case's diagnostics.

## Primal–dual LP and QP oracles

Run `julia --project=test/oracles test/oracles/primal_dual.jl` after instantiating
this environment. HiGHS independently checks quantile-regression coefficients
and dual scores at three quantiles, with dense and sparse designs, and a
second-difference generalized lasso against a quadratic program.

The same script uses the independent epigraph QP model in `qp.jl` to check the
graph-fusion and trend-filtering lecture examples. It verifies the shared
strong-convexity lower bound at arbitrary nonoptimal points, the reconstructed
trend-filtering dual, and
objective/coefficient discrepancies for Condat–Vũ and the reference ADMM
algorithms. A historical run passed these 62 additional assertions on Julia
1.10.12 and 1.13.2. Historical timing records and recreation commands are in the
[snapshot](https://github.com/mlakolar/ProximalSolvers.jl/tree/f7e3f28026a8e83e0fa18203b39839cf57a1c949/benchmark/composite_lessons).
