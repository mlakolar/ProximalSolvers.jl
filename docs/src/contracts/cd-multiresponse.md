# Multi-response row-group coordinate descent

These clauses cover a native matrix response and row groups. They complement the
[shared inputs](@ref IN-01), [group penalty rules](@ref CDG-01), and
[result semantics](@ref RES-01).

## [CDM-01 Problem, shapes and row layout](@id CDM-01)

**Statement.**

~~~math
\min_B\quad \frac{s}{2}\|Y-XB\|_F^2+\lambda\sum_{j=1}^p w_j\|B_{j,:}\|_2,
~~~

for `X` of size `n × p`, a response `Y` of size `n × K` and coefficients `B` of size `p × K`; row `j` of `B` is the
group `j`, and the default weights are `w_j = sqrt(K)`. The call is

```julia
groups = [collect(j:p:p*K) for j in 1:p]    # row j of the column-major B
f = (1/n) * LeastSquaresLoss(Y, X)
g = GroupNormL2(lambda, groups)
B = zeros(Float64, p, K)
r = solve!(B, f, g, CDSolver(order = :cyclic, momentum = false))
r.minimizer === B
```

`B`, `X` and `Y` are finite `Matrix{T}` arrays of positive sizes with one common
`T`, either `Float32` or `Float64`; `size(B) == (p, K)` is required. A wrong shape
raises `DimensionMismatch`, and an invalid type, nonfinite data or forbidden alias
raises `ArgumentError`. `B` must share no memory with `X`, `Y`, `g.w` or the loss's
evaluation scratch array. The loss is `LeastSquaresLoss(Y, X)` or one accepted positive
scalar multiple. The penalty type, level and weights obey [CDG-01](@ref).

For every `j`, the ordered group must satisfy `g.groups[j] == j:p:p*K`, otherwise the exception is
`DimensionMismatch`. These groups index `vec(B)`, not the columns of `X`.
`momentum = true` is refused; `nothing` and `false` give plain block CD.

**Applies to.** `CDSolver`; matrix-response least squares with `GroupNormL2` row groups.

**Code.** `src/solve.jl`: matrix-response validation; `src/cd/multiresponse.jl`: `MLSModel`.

**Tests.** `test/multiresponse_cd.jl`: "refusals leave B and the RNG as they were", row-wise KKT and analytic row soft threshold.

**Sources.** `docs/src/support.md:L236`, `docs/src/support.md:L238`, `docs/src/support.md:L242`, `docs/src/support.md:L245`, `docs/src/support.md:L254`, `docs/src/support.md:L257`, `docs/src/support.md:L261`, `docs/src/support.md:L262`, `docs/src/support.md:L265`, `docstring:src/cd/solver.jl:L115`.

## [CDM-02 Native storage and commit semantics](@id CDM-02)

**Statement.**

The model works from the original `X` and `Y`, without a Kronecker design or a
response flattened into a vector. It stores an `n × K` residual and `O(p K)` further
storage; a visit to row `j` costs `O(n K)`. The run uses a private `BlockIterate` over
`vec(B)`. After a completed run with a finite objective, it writes `B` and returns
`B` itself as `minimizer`. A refusal or numerical failure before that commit leaves
`B` unchanged. Input refusals precede copying and any RNG draw; a failure during a run
can already have advanced the borrowed RNG.

A caller-supplied `BlockIterate` over `vec(B)` with the same row groups and loss is also
accepted; that owner is then the iterate, with the group-CD ownership semantics.

**Applies to.** Dense matrix coefficient and matching `BlockIterate` wrappers for native matrix-response CD.

**Code.** `src/solve.jl`: matrix coefficient wrapper; `src/cd/multiresponse.jl`: `MLSModel`, `initialize!`.

**Tests.** `test/multiresponse_cd.jl`: "ownership, the BlockIterate route and incomplete runs", "no Kronecker design is formed".

**Sources.** `docs/src/support.md:L254`, `docs/src/support.md:L257`, `docs/src/support.md:L261`, `docs/src/support.md:L262`, `docs/src/support.md:L265`, `docs/src/support.md:L267`, `docstring:src/cd/solver.jl:L115`.

## [CDM-03 Column preparation, flat rows and the stopping statistic](@id CDM-03)

**Statement.**

When `maxpasses > 0`, preparation refuses a nonzero column of `X` whose squared norm
`a` is nonfinite or below `floatmin(T)`, and a column for which `s * a` or its
reciprocal is below the smallest normal number of the type combining `s` and `T`.
The `ArgumentError` names the row and occurs before the first pass and first RNG draw.
A zero column is allowed: a visit sets its coefficient row to zero when the level and
weight are both positive, and leaves the row unchanged when either is zero.

With `maxpasses = 0`, no row is visited, these column checks are not made, and `B`
keeps its values. With `relative = true` and positive response scale
`sqrt(s * sum(abs2, Y))`, the row change is its displacement norm times `sqrt(s * a)`
up to rounding in the normal range. Other change-test and pass-schedule rules are
those of group CD. `converged` reports that computed change test, not a KKT certificate.

**Applies to.** Native row-group matrix-response CD.

**Code.** `src/cd/multiresponse.jl`: `_prepare!`, `coordinate_step!`; `src/cd/solver.jl`: shared stopping.

**Tests.** `test/multiresponse_cd.jl`: "columns of different scale", "a zero column of X", preparation refusals and zero-pass runs.

**Sources.** `docs/src/support.md:L267`, `docstring:src/cd/solver.jl:L115`.

## [CDM-04 Independent accuracy checks and unsupported alternatives](@id CDM-04)

**Statement.**

For an independent check, form `G = s * X' * (X * B - Y)`. A nonzero row needs
`norm(G[j, :] + lambda * w[j] * B[j, :] / norm(B[j, :]))` to be small; a zero row
needs `norm(G[j, :]) <= lambda * w[j]`. For positive weights, `B = 0` is a minimizer
when `lambda >= s * maximum(norm((X' * Y)[j, :]) / w[j] for j in 1:p)`.
There is no intercept; center the columns of `X` and `Y` before solving when needed.

`ProximalGradientDescent`, `AccProxGradDescent`, a `NormL1` or `ElasticNet` penalty,
`SqrtLeastSquaresLoss`, and a vector response with a matrix coefficient are refused
with `ArgumentError`.

**Applies to.** Matrix-response row-group formulation; the zero-solution formula assumes positive weights.

**Code.** `src/solve.jl`: supported problem dispatch; `src/cd/multiresponse.jl`: native loss model.

**Tests.** `test/multiresponse_cd.jl`: row-wise KKT, λmax, and unsupported-combination refusals.

**Sources.** `docs/src/support.md:L267`, `docstring:src/cd/solver.jl:L115`.
