# Inputs, storage and scalar parameters

These are the common boundary rules for `solve!`. Solver-specific requirements supplement
them: [scalar CD](@ref CD-01), [sparse CD](@ref CDS-01), [group CD](@ref CDG-01),
[matrix-response CD](@ref CDM-01), [square-root lasso](@ref CDQ-01),
[proximal gradient](@ref PGD-01), [accelerated proximal gradient](@ref APG-01)
and [consensus ADMM](@ref ADM-01).

## [IN-01 Array types, dimensions and supported combinations](@id IN-01)

**Statement.**

A supported vector-response regression solve uses a dense `Matrix{T}` design `X`, a dense `Vector{T}`
response `y`, and coefficients of the same `T`, where `T` is `Float32` or `Float64`.
Dimensions must be positive and consistent, and the supplied data and coefficient entries
must be finite. The sparse-owner gate inspects active values as specified in [CDS-01](@ref).
Mixed array element types are refused, even where ProximalBase function dispatch permits
a heterogeneous call. A sparse design is not supported; sparse coefficients do not change
the design requirement.

| Solver / problem | Coefficient storage | Penalty |
| --- | --- | --- |
| `CDSolver`, least squares | dense `Vector{T}` or one-dimensional `SparseIterate{T}` | `NormL1`, with or without weights, unweighted `ElasticNet`, or uncentered `SqrNormL2` |
| `CDSolver`, group least squares | `BlockIterate{T}` | matching `GroupNormL2`; see [CDG-01](@ref) |
| `CDSolver`, matrix-response least squares | dense `Matrix{T}` or matching row-group `BlockIterate{T}` | native row-group `GroupNormL2`; see [CDM-01](@ref) |
| `CDSolver`, square-root least squares | dense `Vector{T}` or one-dimensional `SparseIterate{T}` | unweighted `NormL1` with positive level; see [CDQ-01](@ref) |
| `ProximalGradientDescent`, `AccProxGradDescent`, least squares | dense `Vector{T}` | `NormL1`, unweighted `ElasticNet`, `NormLinf`, or `GroupNormL2` under [IN-04](@ref) |
| `ProximalGradientDescent`, `AccProxGradDescent`, constrained least squares | feasible dense `Vector{T}` | `IndBox` (including `IndBallLinf`) or four-coefficient `IndBallL2` under [IN-08](@ref) |
| `ProximalGradientDescent`, nonnegative least squares or nonnegative lasso | feasible nonnegative dense `Vector{T}` | `IndNonnegative()` or unweighted `NormL1Nonneg` under [IN-07](@ref) |
| `ProximalGradientDescent`, logistic regression with a raw `LogisticLoss` | dense `Vector{Float64}` | `NormL1`, with or without weights, under [IN-09](@ref) |
| `ADMMSolver`, centered `SqrNormL2` | dense `Vector{T}` | unweighted `NormL1` under [ADM-01](@ref) |

The gradient methods refuse `SparseIterate` and `BlockIterate`; scalar CD refuses
`GroupNormL2`, and all CD storage forms refuse `NormLinf` before any coefficient write
or RNG draw. The latter requires a nonseparable proximal operator; CD's coordinate oracle
requires a separable penalty. Unsupported inputs and options are refused before mutation.
Shape errors use `DimensionMismatch`; unsupported combinations and options use informative
`ArgumentError`s. Finite inputs alone do not promise finite intermediate arithmetic; see
[FP-01](@ref).

Least-squares ridge through `SqrNormL2` is supported only by `CDSolver` on a
dense vector or one-dimensional `SparseIterate`, using the same raw loss or
single supported positive scalar multiple. Construct it as
`SqrNormL2(lambda)`: the coordinate prox requires the declared center type
`Nothing`, that is, `SqrNormL2{<:Real, Nothing}`. A centered penalty is refused
even with a zero center or zero level. A manually constructed union-center type
such as `SqrNormL2{T, Union{Nothing, Vector{T}}}` is also refused even when its
stored center is `nothing`; runtime value alone does not select the prox method.
These are input refusals before copying the caller's owner, coefficient writes
or RNG draws. PGD/APG, square-root loss, group/block coefficients, matrix-response
coefficients and `Scaled(SqrNormL2(...), ...)` remain unsupported for this
concrete penalty. [CD-01](@ref) specifies the objective and [CD-04](@ref) the
separate numerical step refusals after validation.

Raw `LeastSquaresLoss(y, X)` means `sum(abs2, y-X*x)/2`. A single supported positive
scalar wrapper scales that loss; use `(one(T)/T(n))*LeastSquaresLoss(y, X)` when that
native normalization is intended. This fixed scaling is distinct from the scaled lasso,
which estimates a noise level. The unweighted elastic-net penalty is
`lambda1 * norm(x, 1) + (lambda2/2) * sum(abs2, x)`. Full objectives and algorithms are
specified by their solver contracts. For complete runnable calls, see
[Getting started](../getting-started.md) and the [sparsity tutorial](../sparsity-and-kkt.md).

**Applies to.** All public `solve!` methods; specialized CD layouts retain the additional rules linked above.

**Code.** `src/solve.jl`: `_check_data`, `_check_penalty` and the solver-specific owner gates; public `solve!` dispatch.

**Tests.** `test/core_contracts.jl`, `test/sparse_cd.jl`, `test/group_cd.jl`, `test/multiresponse_cd.jl`, `test/linf.jl`, `test/nonnegative_lasso.jl`, `test/logistic_pgd.jl`; `test/cd_elasticnet.jl` checks supported ridge solves plus centered and union-center refusals, while `test/sqrt_lasso.jl` explicitly refuses `SqrNormL2` with square-root loss. Existing generic gates refuse it for PGD/APG and unsupported storage.

**Sources.** `docs/src/numerics.md:L732`, `docs/src/support.md:L316`, `docs/src/support.md:L323`, `docs/src/support.md:L356`, `docs/src/developer/implementation-notes.md:L7`, `docs/src/developer/implementation-notes.md:L192`, `docstring:src/solvers/proximal_gradient_descent.jl:L296`, `docs/src/index.md:L9`, `README.md:L79`, `README.md:L96`, `docs/src/support.md:L130`, `docstring:src/ProximalSolvers.jl:L4`; the later nonnegative-lasso addition is [upstream #413 at fd45a42](https://github.com/mlakolar/ProximalSolvers.jl/commit/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8). The ridge extension is [upstream #420 at 217cde72, exact penalty gate](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/src/solve.jl#L59-L100) and [support note (j)](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/docs/src/support.md#L75-L80).

## [IN-02 Penalty levels and the loss scale](@id IN-02)

**Statement.**

For regression solvers, penalty levels must be finite nonnegative real scalars that convert to `T` without
overflow or rounding a nonzero value to zero. A different scalar type is allowed,
including a representable `Float64` literal in a `Float32` solve. A subnormal converted
level is accepted for an unweighted `NormL1`, the supported unweighted
`NormL1Nonneg` in [IN-07](@ref), or the uncentered `SqrNormL2` ridge penalty
in [IN-01](@ref); weighted `NormL1` has the stricter [IN-03](@ref) rule.
For ridge, zero is also accepted. Negative, NaN or infinite levels are refused,
as are finite levels whose conversion overflows or turns a nonzero value into
zero. A representable level of another real scalar type is allowed; validation
does not globally replace the supplied penalty parameter by `T(lambda)`.
ADMM has its own scalar-parameter rules in [ADM-01](@ref).

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

**Tests.** `test/core_contracts.jl`, `test/cd_numerics.jl`, `test/initial_curvature.jl`, `test/stopping_scale.jl`; ridge construction/validation in `test/cd_elasticnet.jl`, including negative/NaN constructors, an infinite level and Float32 conversions of `1e-60` and `1e40`, plus supported zero and mixed-scalar levels.

**Sources.** `docs/src/numerics.md:L743`, `docs/src/numerics.md:L783`, `docs/src/support.md:L316`, `docs/src/support.md:L323`, `docs/src/support.md:L327`, `docs/src/support.md:L330`, `docs/src/support.md:L334`, `docs/src/developer/implementation-notes.md:L7`, `docstring:src/solvers/proximal_gradient_descent.jl:L296`, `docs/src/getting-started.md:L119`. The unweighted nonnegative-lasso level gate is added by [upstream #413 at fd45a42](https://github.com/mlakolar/ProximalSolvers.jl/commit/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8). Ridge reuses [`_scalar_parameter` at 217cde72](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/src/solve.jl#L11-L21), called by [its new penalty branch](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/src/solve.jl#L75-L79).

## [IN-03 Weighted lasso inputs and rounded coefficients](@id IN-03)

**Statement.**

The weighted-lasso penalty is `lambda * sum(w[j] * abs(x[j]))`, represented by
`NormL1(lambda, w)`. `w` must be a `Vector{T}` with one finite nonnegative entry per
coefficient. An infinite weight, another precision, a view, a range or another array
type is refused. `collect(T, vec(w))` converts another array, taking its entries in
linear order. The mutable coefficients must not alias `w`.
The public call is `solve!(x, f, g, method)`, with `g = NormL1(lambda, w)` and
`method` one of the supported CD, PGD or APG methods.

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
adaptive lasso with a zero weight using all three solvers; its source script is
`examples/problems/weighted_lasso.jl`.

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
With `g = GroupNormL2(λ, groups, w)`, the explicit call forms are
`solve!(x, f, g, ProximalGradientDescent(), options)` and
`solve!(x, f, g, AccProxGradDescent(), options)`, subject to those type and
dimension requirements.

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
With `g = NormLinf(lambda)`, the default-option calls are
`solve!(x, f, g, ProximalGradientDescent())` and
`solve!(x, f, g, AccProxGradDescent())`.

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

## [IN-07 Nonnegative lasso and nonnegative least squares](@id IN-07)

**Statement.**

`ProximalGradientDescent` accepts `IndNonnegative()` and the unweighted penalty
`NormL1Nonneg(lambda)` with a dense least-squares loss. It minimizes
`(s/2) * sum(abs2, y-X*x) + lambda * sum(x)` over `x >= 0`, where `s` is the
accepted loss scale and `lambda = 0` for `IndNonnegative()`. The zero-level form
`NormL1Nonneg(0)` gives the same nonnegative least-squares problem. The data
and coefficients use the same `Float32` or `Float64` type and the shapes,
finite-data, scale and alias rules of [IN-01](@ref), [IN-02](@ref) and [IN-05](@ref).

The coefficient start must be a finite dense `Vector{T}` whose every entry is
nonnegative. A negative starting entry raises `ArgumentError` before any write;
the solver does not project an infeasible start as an initialization step.
The level of `NormL1Nonneg` must be finite, nonnegative and representable in `T` without overflow
or rounding a nonzero value to zero. A representable level of another scalar type
is allowed, as is a subnormal converted level under [IN-02](@ref).

For `NormL1Nonneg`, `g.w` must be `nothing`. An explicit weight vector is refused
even when all its entries are one. APG, coordinate descent, sparse, block or matrix
coefficient owners, matrix responses, square-root loss, `Scaled` penalties and
general penalty compositions are unsupported for these problems. These refusals
precede writes. No intercept is fitted.

The proximal operator enforces feasibility during iterations; its update is
specified in [PGD-01](@ref). A proposed stop uses the constrained stationarity
check in [STOP-16](@ref), with the working-precision guards in [STOP-04](@ref).
The result and failure rules are those of PGD in [RES-01](@ref) and [RES-03](@ref).
The [NNLS tutorial](../examples/problems/nonnegative_least_squares.md) compares
the constraint alone with a positive penalty. The [nonnegative sparse-regression tutorial](../examples/problems/nonnegative_lasso.md)
checks feasibility, the objective and a separately computed constrained KKT residual.

**Applies to.** Dense-vector PGD with least squares and `IndNonnegative()` or unweighted `NormL1Nonneg`.

**Code.** `src/solve.jl`: `_check_penalty` with `kind = :pgd`, `_check_problem`; `src/solvers/proximal_gradient_descent.jl`: the PGD `solve!` gate; `src/utils.jl`: `_converted_penalty` and the dedicated stationarity dispatch.

**Tests.** `test/nonnegative_lasso.jl` covers Float32 and Float64 identity-design references, zero and positive feasible starts, native/Float64/zero levels, objective and minimizer identity, a correlated design, and unchanged inputs after invalid levels, negative starts, weighted penalties and unsupported methods/storage/losses. `examples/problems/nonnegative_lasso.jl` independently checks its fitted example and both-precision exact controls. `test/nonnegative_least_squares.jl` checks direct indicator support with both precisions, scaled and unscaled loss, zero and positive starts, and refusals before writes for invalid data, aliasing, unsupported owners, losses and solvers.

**Sources.** Added after the frozen documentation inventory by [upstream #413 at fd45a42](https://github.com/mlakolar/ProximalSolvers.jl/commit/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8): [input and refusal gates](https://github.com/mlakolar/ProximalSolvers.jl/blob/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8/src/solve.jl), [the support statement](https://github.com/mlakolar/ProximalSolvers.jl/blob/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8/docs/src/support.md#nonnegative-lasso-with-proximal-gradient-descent), and [regression coverage](https://github.com/mlakolar/ProximalSolvers.jl/blob/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8/test/nonnegative_lasso.jl).


## [IN-08 Box- and ball-constrained least squares](@id IN-08)

**Statement.**

For dense least squares and either gradient solver, use `IndBox(l, u)`
or the symmetric box from `IndBallLinf(r)`. The design, response and
coefficient vector obey [IN-01](@ref) and [IN-05](@ref). The solver checks
feasibility of the supplied starting vector before writing to it.

An array bound is copied by ProximalBase into a vector in linear order.
The stored vector must have element type `T` and one entry per coefficient.
Scalar bounds may be Float32, Float64, fixed-width integers or Bool and
must convert exactly to `T`. A lower bound of `-Inf` or an upper bound of `Inf` denotes an
unbounded side. Equal finite bounds fix the coefficient. The stored bounds
must form valid intervals and be disjoint from the coefficient storage.
Treat the stored bounds as read-only during a solve.

Use `IndBallL2(r)` for four coefficients and a finite nonnegative radius
of the same type `T`. At the pinned ProximalBase revision, the rounded
projection is checked and corrected for ordinary trial sums of squares and
positive radii of at least `2sqrt(4floatmin(T) / eps(T))`. Zero radius gives
the singleton at zero. At exceptional scales the upstream oracle can
return `Inf` after projection. In that case an iteration with a nonfinite
objective raises and restores the last accepted point.

The coordinate-descent solver and coefficient storage other than a dense
`Vector{T}` are unsupported for this indicator. Stopping proposals use the
[generic proximal-gradient check](@ref STOP-07).

**Applies to.** Dense Float32 and Float64 PGD and APG with a least-squares loss and the concrete indicators above.

**Code.** `src/solve.jl`: `_check_penalty`, `_check_box`, `_check_problem`.

**Tests.** `test/constrained_least_squares.jl` checks feasibility, optimality, input rules and both precisions.

**Sources.** [Approved scope](https://github.com/mlakolar/ProximalSolvers.jl/issues/422#issuecomment-7001542566) and [ProximalBase numerical contract](https://github.com/mlakolar/ProximalBase.jl/blob/4a737a521d1028228da41e25c16cf963769cd891/docs/src/numerics.md#L176-L187).

## [IN-09 Sparse logistic regression with proximal gradient descent](@id IN-09)

**Statement.**

`ProximalGradientDescent` accepts ProximalBase's raw `LogisticLoss(y, X)` with
`NormL1(lambda)` or `NormL1(lambda, w)` on a dense `Vector{Float64}` and minimizes

```math
F(b)=\sum_{i=1}^n \{\log(1+e^{\eta_i})-y_i\eta_i\}+\lambda\sum_{j=1}^{p} w_j|b_j|,\qquad \eta=Xb,
```

with `w_j = 1` without weights. The loss is the **sum** over the observations, not
the mean: `F/n` is the mean negative log likelihood plus `(lambda/n) * sum(w .* abs.(b))`,
so a mean-scale level `λ` is passed as `n * λ`. There is no automatic intercept: an
intercept is an explicit column of ones in `X` whose penalty weight is zero. Penalty
weights are the weights of `NormL1`; they are not the observation weights of
`LogisticLoss`.

The accepted inputs are:

- a `LogisticLoss{Float64}` whose design is a `Matrix{Float64}` and whose response is
  a `Vector{Float64}` with each entry equal to `0` or `1`, constructed without
  observation weights or an offset (`weights === nothing` and `offset === nothing`);
- coefficients `x::Vector{Float64}`; `X` with positive row and column counts,
  `length(y) == size(X, 1)` and `length(x) == size(X, 2)`; finite entries of `x`
  and `X`;
- a `NormL1` penalty whose level and weights satisfy [IN-02](@ref) and [IN-03](@ref);
  a zero weight leaves its coefficient unpenalized;
- coefficients that do not alias `X`, `y`, the scratch `f.tmp` of the loss or the
  penalty weights.

The gate runs on every solve, before any write to `x`. It reads `y` and `X` at that
call, so an entry of `y` changed to `0.5`, `2.0` or `NaN`, or an entry of `X` changed to
a nonfinite value, after the construction of the loss is refused. ProximalBase's
constructor accepts responses in `[0, 1]`; this solver accepts binary responses only.
Each refusal is an `ArgumentError`, a `DimensionMismatch` for the shapes. For a call
with supported keywords and options, and with coefficient storage that the solver's
gate accepts, the checks run in the order below; the keyword checks of `solve!`, the
option check of `ADMMSolver` and the storage-type checks of the CD gates (a
`SparseIterate` or `BlockIterate` of `Float32` or `Float64`) come first. The order is:
a solver other than PGD; a `Scaled` wrapper; the element type of the loss
and the array types of `X`, `y` and `x`; observation weights or an offset; the
shapes; a penalty that is not a `NormL1`, then the rules of [IN-02](@ref) and
[IN-03](@ref), including the alias check of the weights; aliasing of `x` with `X`, `y`
or `f.tmp`; nonfinite entries of `x` or `X`; an entry of `y` other than `0` and `1`.

`AccProxGradDescent` and `CDSolver` (dense `Vector`, `SparseIterate`, `BlockIterate`
and `Matrix` coefficients) refuse a `LogisticLoss` or a `Scaled` one with an
`ArgumentError` that names `ProximalGradientDescent`, without a write to the
coefficients or a draw from the RNG; for a `BlockIterate` this refusal comes before the
momentum check. `ADMMSolver` refuses it as any function other than its quadratic
([ADM-01](@ref)). `Scaled(LogisticLoss(y, X), a)` is refused because ProximalBase
provides no predictor oracles for it. For a positive finite `a`, the raw loss with the
level `lambda / a` has the same minimizers in exact arithmetic, and is accepted when
`lambda / a` is a level of [IN-02](@ref) and, with weights, its coefficients
`(lambda / a) * w[j]` pass [IN-03](@ref). Other penalties, including wrapped ones,
`Float32` data, sparse designs, views and other array types are refused.

**Iteration.** The trial sequence of [PGD-01](@ref) is unchanged. A trial forms the
image `z = X x` once, in a private buffer, and takes its value from ProximalBase's
`value_from_predictor(f, z)`. The gradient of an accepted point comes from
`value_and_gradient_from_predictor!(G, d, f, z)` at the cached image, which writes
`d` and `G = Xᵀ d`, without forming `X x` again; `d = σ(z) - y` in exact arithmetic,
and ProximalBase evaluates the loss and `d` with formulas that avoid cancellation in
the saturated tails. The image, derivative and gradient buffers are private to the
solve and disjoint from `X`, `y`, `f.tmp` and `x`.

**Overflowed images.** An image `z` with a nonfinite entry gives the loss value `Inf`
without a call of ProximalBase, which returns a finite loss (zero for that entry) for
an infinite predictor on the side of its label and `Inf` on the other side. At the
start, `solve!` then refuses the coefficients with the `ArgumentError` "start from a
point where f is finite", before any write. In a trial, the line search takes its
nonfinite-value branch ([LS-02](@ref)) before its zero-step, curvature and `Lexact`
exits: the trial is not accepted and the search retries with `L/β`, beyond `Lexact` if
need be. The gradient is refreshed only at a trial with a finite value, so at an
image that passed this check. A finite image, however large, goes to ProximalBase's
stable loss; for example a logit of 800, beyond `log(floatmax(Float64)) ≈ 709.78`,
gives the loss 800 for the label 0.

**Curvature factor.** For this loss, in exact arithmetic,
`∇²f(b) = Xᵀ diag(σᵢ(1 - σᵢ)) X ⪯ ¼ XᵀX`, since `0 ≤ σᵢ(1 - σᵢ) ≤ ¼`. The line search
uses the factor `¼` where least squares uses its loss scale `s`. The initial inverse
step is that of [PGD-02](@ref) with `s = ¼`: the `T`-rounded `min(1, ¼ B²)` for the
rounded upper bound `B` on `‖X‖_F`, raised to `floatmin(T)` when positive and below it,
and `1` when `X = 0`. A rejected trial that is eligible under [LS-03](@ref) is rechecked
with `c = m ¼ ‖fl(X d̂)‖² / ‖d̂‖²` (`m = 1` in function-value mode and `m = 2` in gradient
mode). In exact arithmetic, for the trial `x` and the step `d = x - u` from the last
accepted point `u` (`x_previous` in [LS-02](@ref)):

- `f(x) ≤ f(u) + ⟨∇f(u), d⟩ + ⅛‖X d‖²` (Taylor's formula with integral remainder and
  the Hessian bound), so with `m = 1`, `c ≤ L` implies TFOCS's function-value test
  `f(x) ≤ f(u) + ⟨∇f(u), d⟩ + (L/2)‖d‖²`;
- `⟨∇f(x) - ∇f(u), d⟩ ≤ ¼‖X d‖²`, so with `m = 2`, `c ≤ L` implies TFOCS's gradient
  test `2⟨∇f(x) - ∇f(u), d⟩ ≤ L‖d‖²`;
- after a rejection, TFOCS's estimate is `L̂ = 2(f(x) - f(u) - ⟨∇f(u), d⟩)/‖d‖²` in
  function-value mode (where it exceeds `L`) and `L̂ = 2⟨∇f(x) - ∇f(u), d⟩/‖d‖²` in
  gradient mode; each is at most `c`. When the computed `c` is finite it replaces `L̂`,
  and the retry `min(Lexact, max(c, L/β))` is at least TFOCS's
  `min(Lexact, max(L̂, L/β))`, so the retry's step `1/L` is at most TFOCS's; `L/β` and
  `Lexact` enter both. A nonfinite computed `c` leaves TFOCS's estimate.

A scaled displacement ([LS-06](@ref)) gives the same `c` in exact arithmetic. For least
squares the inequalities hold with equality, with `s` in place of `¼`; for the logistic
loss they are one-sided bounds, which is what the recheck needs. These statements are
in exact arithmetic: the computed `c` can be below the exact quotient after rounding or
range loss ([LS-05](@ref)), and the recheck carries no rounding certificate, as for least
squares. After a rejection the retry uses the global factor `¼` along `d̂` rather than
the local weights `σᵢ(1 - σᵢ)`, which can be smaller, so the step can be shorter than
the local curvature allows. With the line search's `α < 1`, the decrease of `L` at the
start of each iteration lets the step grow again; with `α = 1` it does not.

**Stopping.** A proposed stop passes the check of [STOP-03](@ref) with the logistic
gradient and the guards of [STOP-04](@ref). The scale is `S = max(λ, λmax)`, with
`λ = T(lambda) * maximum(w)` (`T(lambda)` without weights) and
`λmax = ‖Xᵀ(½ - y)‖∞ = ‖∇f(0)‖∞`, since `σ(0) = ½`; each `½ - yᵢ` is `±½`, exact for a
binary response. `λmax` is formed at the first stationarity check of a solve, with the
difference `½ - y` in the state's image-length buffer, which the iterations write before
they read it. In exact arithmetic the entry of an intercept column in `Xᵀ(½ - y)` is
`n (½ - ȳ)`, one of the candidates in that maximum. Results, counters and rollback
follow [RES-01](@ref) and [RES-03](@ref).

**Unattained minima.** The problem need not have a minimizer. Let `rᵢ = 2yᵢ - 1` and
call coordinate `j` free when its coefficient `cⱼ = λ wⱼ` is zero. In exact arithmetic:

- if some direction `d` that moves only free coordinates has `rᵢ xᵢᵀd ≥ 0` for every
  observation and `X d ≠ 0` (the data are separated along unpenalized directions), then
  no loss term increases along `d` and at least one decreases, so `F` decreases strictly
  along `d` and its infimum is not attained;
- if no direction `d ≠ 0` that moves only free coordinates has `rᵢ xᵢᵀd ≥ 0` for every
  observation, the sublevel sets of `F` are bounded and a minimizer exists. This
  includes separated data with an intercept column of weight zero, positive weights on
  all other coefficients, a positive level and both classes present: the only candidate
  directions move the intercept alone, and the two classes rule them out.

The simplest unattained case is a one-class sample (all `yᵢ = 1`, or all `yᵢ = 0`) with an
unpenalized intercept column: `F` decreases toward its infimum as the intercept grows
in magnitude, and the derivative of the loss in the intercept tends to zero. The
computed KKT residual can then become arbitrarily small, and it underflows to zero in
`Float64` at a large intercept, so it can fall below the threshold of [STOP-04](@ref):
`converged = true` can be reported at a finite point although no minimizer exists. The
solver does not detect this case; `converged` records only the outcome of the computed
checks of [STOP-01](@ref) and [STOP-03](@ref), and it is not evidence that a minimizer
exists or that the returned point is accurate.

**Shared stopping scale.** The scale `S = max(λ, λmax)` of [STOP-03](@ref) is one number
for all coordinates, and `λ` is the largest coefficient `T(lambda) * maximum(w)`. With an
extreme weight on one coordinate, the threshold `τ S` can exceed the derivative of a free
coordinate at points far from the minimizer, and a proposed stop then passes there. For
`X = [fill(1e150, 5) zeros(5)]`, `y = [0, 1, 1, 1, 1]` and `NormL1(1e300, [0, 1])`, the
minimizer has the second coefficient zero and the predictor `log 4 ≈ 1.386` in the
first column (the logit of `ȳ = 4/5`). With the default options, PGD can stop after
one iteration at the predictor `1.2`, with `converged = true` and an objective above
the minimum by about `0.014`: `S = 1e300` gives the threshold `τ S = 1e295`, while the
derivative in the free intercept is still about a tenth of its value at zero. The
same scale applies to the weighted lasso with PGD and APG ([STOP-03](@ref)), where an
extreme weight can mask an inaccurate free coordinate in the same way. Assess the free
coordinates with an independent residual on their own scale.

**Applies to.** `ProximalGradientDescent` with a raw `LogisticLoss{Float64}` and `NormL1` on a dense `Vector{Float64}`; the logistic refusals of `AccProxGradDescent`, `CDSolver` and `ADMMSolver`. The deferred logistic combinations are listed in [DEF-01](@ref).

**Code.** `src/solve.jl`: `_is_logistic_loss`, `_check_logistic_problem`, `_logistic_method_error`, the logistic branch of `_check_data` and of `_check_problem`; `src/solvers/image_models.jl`: `_LogisticImage`, `_image_model`, `_image_buffer`, `_image!`; `src/utils.jl`: `_lambda_max!` and `_zero_gradient!`.

**Tests.** `test/logistic_pgd.jl`: the stopping scale against `‖Xᵀ(½ - y)‖∞`, and a stop through the engine checked with ProximalBase's scorer and with the independent residual; the value and gradient at zero and at a representative point against label-wise BigFloat formulas and central differences; the inequalities behind the factor `¼`, the initial curvature, and the recheck of a rejected trial in each mode (`c = ¼` and `c = ½` for a unit step, at least TFOCS's estimate); a regularized nonseparable fit with an unpenalized intercept (objective, the KKT scores of the intercept and of the active and inactive slopes, `minimizer === b`, rejected trials, the `F/n` scaling); the intercept-only model and levels at and above the slope threshold; an unpenalized fit against a damped Newton reference, with a certificate that its data are not separable; unit weights against the unweighted penalty; checked rejections; rollback after a fault and through `solve!`; overflowed images at the start (refused, coefficients unchanged) and in a trial (retried, on the side of the label and against it), and a finite logit of 800; iteration and call limits; steep, separated and almost separated regularized problems, including a start with logits beyond `log(floatmax(Float64))`; a one-class sample with an unpenalized intercept (finite results, and a reported convergence consistent with the stationarity criterion recomputed from the data, without requiring either outcome); the refusals above with the coefficients unchanged, including `CDSolver` on each storage with raw and scaled losses and an unchanged RNG; a warmed iteration that allocates nothing and whole solves against the least-squares control. The independent residual bound of these tests is justified by a rounding bound that each check asserts. `examples/problems/logistic_regression.jl` checks its fit independently.

**Sources.** [Issue #438](https://github.com/mlakolar/ProximalSolvers.jl/issues/438) (scope, mathematical contract and tests) and [pull request #439](https://github.com/mlakolar/ProximalSolvers.jl/pull/439) (mini-design); ProximalBase [`LogisticLoss` at 4a737a52](https://github.com/mlakolar/ProximalBase.jl/blob/4a737a521d1028228da41e25c16cf963769cd891/src/functions/logisticloss.jl), the merge of [ProximalBase #1033](https://github.com/mlakolar/ProximalBase.jl/pull/1033).
