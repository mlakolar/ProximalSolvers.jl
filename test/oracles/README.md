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

## Square-root lasso SOCP oracle

Run `julia --project=test/oracles test/oracles/sqrt_hypatia.jl` after instantiating
this environment. Hypatia solves an independent second-order cone formulation
initially with `1e-12` optimality and feasibility tolerances. If termination is
not optimal or either solution status is not feasible, it solves the same
model again with a fresh Hypatia optimizer at `1e-9` tolerances. Each
`HYPATIA_STATUS` line records both attempts' tolerances and statuses
(`attempt_2=nothing` when no retry was needed), and identifies the tolerance
used. The selected result must have optimal termination, feasible primal and
dual points, and a conic bracket of width at most
`1e-7 * max(1, abs(P_conic))`. Its primal and dual objectives supply the
bracket used in the corresponding coordinate-descent certificate checks.
The data and stored-statistics losses have separate conic references.

If both attempts lack optimal termination with feasible primal and dual
points, the reference is unavailable. The optimal-status condition is recorded
as a broken test, and each loss prints `HYPATIA_UNAVAILABLE name=... loss=...`.
Only that reference's conic bracket and certificate comparisons are skipped.
CD runs, independent objective evaluation, and finite nonnegative objective
and gap checks still run. The run at `bbf06e0` with Hypatia 0.11.0 reported
488 passing assertions and eight broken references: the statistics references
of `audit_trap` and all six `noiseless_*` cases (seeds 11101, 11102 and 11103,
each at fractions 0.05 and 0.2), plus the data reference of
`noiseless_seed11102_fraction0.2`. The seven statistics references were rejected
before solving with `stored_augmented_matrix_not_psd`; the log does not record
tolerance retries for them. Only the data reference returned `SLOW_PROGRESS`
with unknown primal and dual statuses at both tolerances. An exact-fit optimum
at the cone apex is a likely source of difficulty for that interior-point
solve. Exact fits likewise reach the apex in a PSD stored-statistics
formulation, but the recorded statistics exclusions are due to indefinite
stored matrices, not demonstrated solver stagnation. If either attempt
produces a usable optimum, all conic assertions run as usual.

The cases cover exact fits from optimal and trapped starts, dependent columns,
the cyclic audit trap, an incomplete witness, six seeded underdetermined
noiseless fits, and twelve seeded ordinary fits. The ordinary fits include
observation weights with zero-weight rows and an intercept, sparse designs
with an intercept, an unpenalized correlated column, and an infinite penalty
weight fixing a coefficient at zero. There is also an ill-conditioned
unpenalized example and a Float32 fit; conic solves always use Float64 data.
Nonfinite penalty loadings fix coefficients at zero in the conic model.

Each case checks coordinate descent's reported relative gap against the conic
bracket, including runs returning `converged = false`. Converged runs must also
agree with the conic dual objective within the reported gap or the default
`1e-4` threshold. Data objectives are evaluated in 256-bit BigFloat, converting
stored data and coefficients before residual arithmetic. Float64 and Float32
cancellation regressions start at `[M, 1, -M, 1]` on three identical unpenalized
columns and one penalized column. Their true starting objectives are about
`2.1`, although ordinary-precision residual arithmetic can return `0.1`.
An invertible coefficient change gives the conic reference a well-conditioned
basis without changing the optimum of about `0.1`.

Weighted centering eliminates intercepts before forming the statistics, and
both loss and penalty are divided by `sqrt(n)`. Rounding means this stored
quadratic can differ from the data problem. Each statistics run therefore
uses its own conic reference obtained by factoring the stored augmented
matrix `[A b; b' c]` in BigFloat and modeling `norm(L * [x; 1])`. Its CD
objective is also evaluated from those same stored statistics in BigFloat.
Statistics lines report the scaled quadratic objective in its own units,
with its own scaled penalty; relative gaps require no conversion.
The Float32 example `X = [1.5]`, `y = [1.8]`, `lambda = 0.75` checks the
positive residual floor introduced by rounding the stored quadratic.

The pivoted BigFloat factorization allows singular PSD matrices and only
tolerates errors at its working precision. If the stored matrix is indefinite,
it is not projected onto the PSD cone: a broken test and a
`STATISTICS_UNAVAILABLE` diagnostic identify the missing convex reference.
CD execution and the independent objective and gap checks still run.
The `M = 2^26` ill-conditioned example includes both losses: its stored Gram
is exact. BigFloat congruence with an invertible coefficient change preserves
its small direction before factorization; the data design satisfies `X * B = I`.

Each `ORACLE_CASE` line reports the case and loss, conic termination status,
`P_CD`, `P_conic`, `D_conic`, relative `gap`, `converged`, and `bound_slack`.
Nonnegative slack means the reported gap bounds suboptimality after allowing
the conic bracket width and the stated rounding allowance. The script prints
solver versions and ends with `SQRT_HYPATIA_ORACLE_PASSED` only after all
assertions pass. These are numerical references, not symbolic certificates.
Unavailable references remain visible as broken tests in the test summary.
