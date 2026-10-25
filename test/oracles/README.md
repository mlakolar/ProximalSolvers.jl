# Optional QUIC conic oracle

`quic_hypatia.jl` compares QUIC with Hypatia's log-det cone through JuMP.
It uses four small problems (`p = 3, 6`, with and without diagonal penalties),
checks each solution's positive definiteness and proximal KKT residual, and
compares independently evaluated objectives and coefficients. These are
numerical reference solutions, not symbolic exact solutions.

The optional environment keeps Hypatia, JuMP and MathOptInterface out of the
main package and its normal tests. Run setup and execution inside a Discovery
Slurm allocation, with one Julia/BLAS thread and a run-private depot layer.
From the repository root, with `PROXIMALBASE_SNAPSHOT` set to the desired
ProximalBase checkout:

```sh
julia --startup-file=no --project=test/oracles -e 'using Pkg;
    Pkg.develop(path=pwd());
    Pkg.develop(path=ENV["PROXIMALBASE_SNAPSHOT"]); Pkg.instantiate()'
julia --startup-file=no --project=test/oracles test/oracles/quic_hypatia.jl
```

Discovery job **13377413**, run `20261024T1258Z-ps-issue22`, passed **44/44**
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

The same script checks the graph-fusion and trend-filtering lecture examples
against independent QPs. It verifies the shared strong-convexity lower bound
at arbitrary nonoptimal points, the reconstructed trend-filtering dual, and
objective/coefficient discrepancies for Condat–Vũ and the reference ADMM
algorithms. The 62 additional assertions pass on Julia 1.10.12 and 1.13.2.
