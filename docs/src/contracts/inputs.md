# Inputs, storage and scalar parameters

These are the common boundary rules for `solve!`. Solver-specific requirements supplement
them: [scalar CD](@ref CD-01), [sparse CD](@ref CDS-01), [group CD](@ref CDG-01),
[matrix-response CD](@ref CDM-01), [square-root lasso](@ref CDQ-01),
[proximal gradient](@ref PGD-01) and [accelerated proximal gradient](@ref APG-01).

## [IN-01 Array types, dimensions and supported combinations](@id IN-01)

**Statement.**

A supported vector-response solve uses a dense `Matrix{T}` design `X`, a dense `Vector{T}`
response `y`, and coefficients of the same `T`, where `T` is `Float32` or `Float64`.
Dimensions must be positive and consistent, and the supplied data and coefficient entries
must be finite. The sparse-owner gate inspects active values as specified in [CDS-01](@ref).
Mixed array element types are refused, even where ProximalBase function dispatch permits
a heterogeneous call. A sparse design is not supported; sparse coefficients do not change
the design requirement.

| Solver / problem | Coefficient storage | Penalty |
| --- | --- | --- |
| `CDSolver`, least squares | dense `Vector{T}` or one-dimensional `SparseIterate{T}` | `NormL1`, with or without weights, or unweighted `ElasticNet` |
| `CDSolver`, group least squares | `BlockIterate{T}` | matching `GroupNormL2`; see [CDG-01](@ref) |
| `CDSolver`, matrix-response least squares | dense `Matrix{T}` or matching row-group `BlockIterate{T}` | native row-group `GroupNormL2`; see [CDM-01](@ref) |
| `CDSolver`, square-root least squares | dense `Vector{T}` or one-dimensional `SparseIterate{T}` | unweighted `NormL1` with positive level; see [CDQ-01](@ref) |
| `ProximalGradientDescent`, `AccProxGradDescent`, least squares | dense `Vector{T}` | `NormL1`, unweighted `ElasticNet`, `NormLinf`, or `GroupNormL2` under [IN-04](@ref) |

The gradient methods refuse `SparseIterate` and `BlockIterate`; scalar CD refuses
`GroupNormL2`, and all CD storage forms refuse `NormLinf` before any coefficient write
or RNG draw. The latter requires a nonseparable proximal operator; CD's coordinate oracle
requires a separable penalty. Unsupported inputs and options are refused before mutation.
Shape errors use `DimensionMismatch`; unsupported combinations and options use informative
`ArgumentError`s. Finite inputs alone do not promise finite intermediate arithmetic; see
[FP-01](@ref).

Raw `LeastSquaresLoss(y, X)` means `sum(abs2, y-X*x)/2`. A single supported positive
scalar wrapper scales that loss; use `(one(T)/T(n))*LeastSquaresLoss(y, X)` when that
native normalization is intended. This fixed scaling is distinct from the scaled lasso,
which estimates a noise level. The unweighted elastic-net penalty is
`lambda1 * norm(x, 1) + (lambda2/2) * sum(abs2, x)`. Full objectives and algorithms are
specified by their solver contracts. For complete runnable calls, see
[Getting started](../getting-started.md) and the [sparsity tutorial](../sparsity-and-kkt.md).

**Applies to.** All public `solve!` methods; specialized CD layouts retain the additional rules linked above.

**Code.** `src/solve.jl`: `_check_data`, `_check_penalty` and the solver-specific owner gates; public `solve!` dispatch.

**Tests.** `test/core_contracts.jl`, `test/sparse_cd.jl`, `test/group_cd.jl`, `test/multiresponse_cd.jl`, `test/linf.jl`.

**Sources.** `docs/src/numerics.md:L732`, `docs/src/support.md:L316`, `docs/src/support.md:L323`, `docs/src/support.md:L356`, `docs/src/developer/implementation-notes.md:L7`, `docs/src/developer/implementation-notes.md:L192`, `docstring:src/solvers/proximal_gradient_descent.jl:L296`, `docs/src/index.md:L9`, `README.md:L79`, `README.md:L96`, `docs/src/support.md:L130`.

## [IN-02 Penalty levels and the loss scale](@id IN-02)

**Statement.**

Penalty levels must be finite nonnegative real scalars that convert to `T` without
overflow or rounding a nonzero value to zero. A different scalar type is allowed,
including a representable `Float64` literal in a `Float32` solve. A subnormal converted
level is accepted for an unweighted `NormL1`; weighted penalties have the stricter
[IN-03](@ref) rule.

For `Scaled(LeastSquaresLoss(...), s)`, the supported loss scale is either:

- a positive finite `Float32` or `Float64` that converts to a finite nonzero `T`, including
  a subnormal converted value; or
- a positive fixed-width integer (`Int`, `UInt8` or another `Base.BitInteger`) or `Bool`
  that `T` represents exactly. Thus `2^24` is accepted for `Float32` data and `2^24 + 1`
  is refused; for `Float64` the corresponding examples are `2^53` and `2^53 + 1`.

`BigInt`, `BigFloat`, `Rational`, `Float16`, `Irrational`, any other scale type, and an
integer that `T` rounds are refused with `ArgumentError` before any solver writes to
the coefficients. An explicit conversion is possible when its result is finite,
positive and representable under this rule, for example
`Float64(s) * LeastSquaresLoss(y, X)`. The error message suggests that conversion only
when it passes the rule and, for an integer, `Float64(s) == s`; for other types it notes
that conversion may round `s`. The historical API narrowing is recorded in
[HIST-02](@ref).

Validation does not globally convert function parameters or require every intermediate
operation to use `T`. CD, PGD and APG use an accepted loss scale as supplied, combined
with `T` by Julia's promotion. A `Float64` scale in a `Float32` solve retains its
`Float64` value, including where its conversion is subnormal in `Float32`. Arrays and
coefficients remain in `T`; this is not general mixed-precision array support.

CD's `LSModel` stores `s::S`, with `S = promote_type(T, typeof(s))` when that is a concrete
`AbstractFloat` and `S = T` otherwise. The coordinate step and the two stopping scales
form their products with `s` in `S`, rounding to `T` at their iterate or tolerance
boundaries. An integer or `Bool` scale is used there as `T(s)`. The objective instead
comes from the original loss through ProximalBase, which converts integer and `Bool`
scales to `Float64`, forms its scale product in the promoted type of that scale and `T`,
then rounds to `T`. For accepted integer scales, `T(s)` and `Float64(s)` both equal
the real scalar `s`; the conversions in `_lambda_max!` and `_step_curvature` do too.
Arithmetic precision can still differ: with `Float32` data and scale `3`, CD's step
and stopping arithmetic is `Float32`, while the objective product is `Float64`; with
`Float64` data both are `Float64`. The [CD scale branches](@ref CD-08) and
[objective rule](@ref CD-09) give the detailed arithmetic.

The shorthand `1/n` produces a `Float64` scalar; an accepted value is used as
supplied, rather than first rounded to `Float32`. Prefer explicit native scalars
when choosing native arithmetic. In `one(T) / T(n)`,
the conversion of `n` and the division use `T`; its value can differ from `Float64`
`1/n`. The solve uses the value actually supplied, with its loss-scale products in `T`:
```julia
T = Float32
s = one(T) / T(n)
lambda = T(0.1)
f = s * LeastSquaresLoss(y, X)
g = NormL1(lambda)
```

**Applies to.** Penalty scalar parameters and the single `Scaled` least-squares wrapper accepted by the public solvers.

**Code.** `src/solve.jl`: `_scalar_parameter`, `_check_loss_scale`, `_loss_scale_error`; `src/cd/leastsquares.jl`: `LSModel`; `src/solvers/image_models.jl`: scale consumers.

**Tests.** `test/core_contracts.jl`, `test/cd_numerics.jl`, `test/initial_curvature.jl`, `test/stopping_scale.jl`.

**Sources.** `docs/src/numerics.md:L743`, `docs/src/numerics.md:L783`, `docs/src/support.md:L316`, `docs/src/support.md:L323`, `docs/src/support.md:L327`, `docs/src/support.md:L330`, `docs/src/support.md:L334`, `docs/src/developer/implementation-notes.md:L7`, `docstring:src/solvers/proximal_gradient_descent.jl:L296`, `docs/src/getting-started.md:L119`.

## [IN-03 Weighted lasso inputs and rounded coefficients](@id IN-03)

**Statement.**

The weighted-lasso penalty is `lambda * sum(w[j] * abs(x[j]))`, represented by
`NormL1(lambda, w)`. `w` must be a `Vector{T}` with one finite nonnegative entry per
coefficient. An infinite weight, another precision, a view, a range or another array
type is refused. `collect(T, vec(w))` converts another array, taking its entries in
linear order. The mutable coefficients must not alias `w`.

The level passes [IN-02](@ref), and `T(lambda)` must be zero or normal in `T`: a
subnormal level is refused with weights. For every entry, the coefficient
`c_j = T(lambda) * w_j`, with the product rounded in `T`, must be finite and, when
both factors are positive, normal in `T`. Overflow, underflow to zero and a subnormal
positive coefficient are refused with entry `j` named. The rule is on the rounded
coefficient: an exact product slightly below `floatmin(T)` that rounds up to
`floatmin(T)` is accepted. A zero level or zero weight yields the accepted coefficient
zero. A zero weight leaves its variable unpenalized; it does not fix it to zero.
CD's separate [flat-column rule](@ref CD-01) still sets the coefficient of a zero
column to zero, including with a zero weight.

These checks finish before `x` is copied or written and before the RNG is used.
The validation, the PGD/APG stationarity check, and CD's exceptional threshold branch
use the checked `c_j`. PGD/APG score entry `j` with its own `c_j` and use the largest
`c_j` for the penalty part of their stop scale; see [STOP-03](@ref).
ProximalBase's ordinary proximal steps instead form thresholds from the supplied
`lambda` and `w_j` in their working type. This includes the PGD/APG proximal step and
CD's `prox_block` branch. Those thresholds can differ from ones formed from `c_j` by
rounding and, when `lambda` is not `T`, by its conversion error. [CD-04](@ref) specifies
the branch selection and the bound on that error. CD retains its change test.

`Scaled(NormL1(lambda, w), a)` and weighted `ElasticNet` are refused. The
[weighted-lasso tutorial](../examples/problems/weighted_lasso.md) demonstrates an
adaptive lasso with a zero weight using all three solvers.

**Applies to.** Weighted `NormL1` with scalar least-squares CD, PGD or APG; group input checks reuse the rounded-coefficient rule in [IN-04](@ref).

**Code.** `src/solve.jl`: `_check_l1_weights`, `_weighted_level`, `_check_coefficients`; `src/cd/leastsquares.jl`: exceptional threshold branch.

**Tests.** `test/weighted_lasso.jl` (accepted weights, conversion/range/alias refusals and stopping), `test/cd_numerics.jl`.

**Sources.** `docs/src/support.md:L134`, `docs/src/support.md:L137`, `docs/src/support.md:L138`, `docs/src/support.md:L145`, `docs/src/support.md:L147`, `docs/src/support.md:L151`, `docstring:src/solvers/proximal_gradient_descent.jl:L296`, `README.md:L65`, `docs/src/support.md:L130`, `docs/src/glossary.md:L9`.

## [IN-04 Dense group lasso with gradient methods](@id IN-04)

**Statement.**

`ProximalGradientDescent` and `AccProxGradDescent` accept the group lasso on a dense
`Vector{T}` with the common least-squares inputs and scales above. APG also imposes
its [dimension bounds](@ref APG-02). The penalty must be `GroupNormL2{T}`: its level
and weights have the data's element type. Convert explicitly with
`GroupNormL2(T(lambda), groups, T.(w))`. A `Float64` group penalty with `Float32`
data is refused by these methods, although group CD supports it under [CDG-01](@ref).

The groups partition `1:p` and agree with the layout stored in the penalty at
construction. An index above `p` raises `DimensionMismatch`; an empty group, an index
in multiple groups, an omitted index, or a mutation of `g.groups` that disagrees with
the stored layout raises `ArgumentError`. ProximalBase's extent and free-coordinate
logic use its arrays stored at construction; construct the penalty again to change
that layout.

The level and weights pass [IN-03](@ref), with one rounded
`c_k = T(lambda) * w_k` per group. A zero weight leaves its group unpenalized.
`x` must not alias `X`, `y` or the weights. The checks complete before any write to
`x`. ProximalBase supplies the block soft-threshold step. A proposed stop must pass
the [group stationarity check](@ref STOP-05); APG forms one gradient at the accepted
`x` for each such check and includes it in `grad_calls`. Singleton groups with unit
weights have the `NormL1(lambda)` stop scale when no entry of `gradient(f, 0)` has a
subnormal square.

**Applies to.** Dense-vector group least squares with PGD or APG. Scalar CD refuses this penalty; group CD uses its own `BlockIterate` contract.

**Code.** `src/solve.jl`: `_check_dense_group_penalty`; `src/utils.jl`: group stationarity scale and residual.

**Tests.** `test/group_pgd.jl` compares both precisions against references computed from the rounded data in `BigFloat`. Both methods cover block-orthogonal closed forms (raw and `1/n`-scaled, default weights and a zero weight), correlated designs (also against group CD), unit-weight singleton groups against `NormL1`, a zero weight, `lambda = 0` against least squares, a level above the zero-solution threshold, huge `xtol`/`ftol` that must not bypass the check, and stops on both sides of its threshold. PGD alone covers contiguous, permuted and single groups as ranges or vectors, a group of zero columns, and a `Float64` loss scale `1e-300`.

**Sources.** `docs/src/support.md:L205`, `docs/src/support.md:L207`, `docs/src/support.md:L211`, `docs/src/support.md:L214`, `docs/src/support.md:L218`, `docs/src/support.md:L220`, `docs/src/support.md:L222`, `docstring:src/solvers/proximal_gradient_descent.jl:L322`.

## [IN-05 Borrowed inputs and aliasing](@id IN-05)

**Statement.**

`X` and the response are borrowed read-only during a solve: do not mutate them while
the solver is running. The mutable coefficient storage must not alias either input.
Weighted `NormL1` and dense-group PGD/APG also prohibit aliasing the penalty weights;
matrix-response CD has the additional alias rules in [CDM-01](@ref).
For `SparseIterate`, alias checks cover the owner's whole
backing storage, even when it has no active entries; passing
`parent(activevalues(x))` or a reshape of it as `y` or `X` is refused.

`solve!` overwrites its supported coefficient storage. Results share that storage;
use `copy(beta)` to retain earlier coefficients. Extended traces copy coefficients
and gradients. [RES-01](@ref) describes the result fields and [RES-03](@ref) the
solver-specific numerical failure boundary. Validation errors occur before mutation;
private buffers and counters do not have a general transaction guarantee.

**Applies to.** All public solves and their coefficient owners; matrix-response CD adds its explicit matrix alias checks in [CDM-01](@ref).

**Code.** `src/solve.jl`: array/owner alias gates and public wrappers; `src/types.jl`: trace/result storage.

**Tests.** `test/core_contracts.jl`, `test/sparse_cd.jl`, `test/weighted_lasso.jl`, `test/group_pgd.jl`, `test/multiresponse_cd.jl`.

**Sources.** `docs/src/support.md:L350`, `docs/src/developer/implementation-notes.md:L205`, `docstring:src/solvers/proximal_gradient_descent.jl:L334`.

## [IN-06 The infinity-norm penalty](@id IN-06)

**Statement.**

For `NormLinf(lambda)`, PGD and APG minimize
`(s/2) * sum(abs2, y-X*x) + lambda * maximum(abs, x)`, with `s = 1` for an
unscaled loss. They require dense `Vector{T}` coefficients, common-type dense inputs,
and a finite nonnegative level representable under [IN-02](@ref). ProximalBase
already refuses construction of a negative or `NaN` level; the other input refusals
leave `x` unchanged. A wrapper such as `Scaled(NormLinf(lambda), c)` is unsupported.

The ℓ∞ penalty can tie the largest coefficients at a common magnitude and does not
in general give zeros. ProximalBase supplies the proximal operator. In exact arithmetic, zero is a minimizer
exactly when `lambda >= norm(gradient(f, 0), 1) = s * norm(X' * y, 1)`; the relevant
dual norm here is the 1-norm. Proposed stops use the [generic check](@ref STOP-07).
CD refuses this penalty for dense vectors, `SparseIterate` and `BlockIterate` before
mutation or RNG use, as specified in [IN-01](@ref). See the
[infinity-norm tutorial](../examples/problems/linf_regularized_regression.md).

**Applies to.** Least-squares PGD and APG with a `NormLinf` penalty.

**Code.** `src/solve.jl`: `_check_penalty`; `src/utils.jl`: generic stationarity check.

**Tests.** `test/linf.jl` (both gradient methods, zero-solution threshold, dispatch refusals and generic stopping).

**Sources.** `docs/src/support.md:L158`, `docs/src/support.md:L162`, `docstring:src/solvers/proximal_gradient_descent.jl:L296`, `README.md:L91`, `docs/src/support.md:L107`, `docs/src/choosing-solver.md:L345`.
