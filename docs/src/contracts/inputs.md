# [Input validation and supported parameters](@id IN-01)

Verbatim migration checkpoint; source provenance is recorded below.

<!-- baseline: docs/src/numerics.md:732-790 -->

A supported solve uses a single floating-point working type
`T = Float32` or `T = Float64` for the design matrix `X`, response
vector `y`, and coefficient iterate. `CDSolver` accepts either a
dense `Vector{T}`, a one-dimensional `SparseIterate` of `T`, or, for the group lasso, a
`BlockIterate{T}`;
`ProximalGradientDescent` and `AccProxGradDescent` accept only a dense `Vector{T}`.
Mixed-precision arrays, such as `Float32` coefficients with a
`Float64` design, are rejected. This is stricter than ProximalBase
function dispatch, which may permit some heterogeneous calls without
guaranteeing their numerical behavior.

**Scalar-parameter exception.** The `NormL1` penalty level `lambda` may be a
finite nonnegative real scalar of a different type, including a `Float64`
literal for a `Float32` solve, and the loss scale in
`Scaled(LeastSquaresLoss(...), s)` is supported in two forms: a positive
finite `Float32` or `Float64`, or a positive fixed-width integer or `Bool`
that `T` represents exactly (`2^24` but not `2^24 + 1` for `Float32` data;
`2^53` but not `2^53 + 1` for `Float64` data). The solver checks that a
penalty level, and a `Float32` or `Float64` loss scale, are representable in `T`
without overflow or loss of a nonzero parameter to zero (a value that is
subnormal in `T` is accepted). A loss scale of any other type (`BigInt`,
`BigFloat`, `Rational`, `Float16`, `Irrational` or another `Real`) or an integer
that `T` rounds is refused with an `ArgumentError` before any solver writes to
the coefficients. **This is an intentional narrowing of the supported API:**
those scales were accepted before the loss value and gradient came from
ProximalBase's oracles (a `BigFloat`, `BigInt` or `Rational{BigInt}` scale made
CD's scalar arithmetic `BigFloat`; an `Int`, `Rational{Int}`, `Irrational`,
`Bool` or `Float16` scale was used there as `T(s)`). Convert the scale
explicitly where the conversion is finite, positive and representable in `T`,
for example `Float64(s) * LeastSquaresLoss(y, X)`; the error message suggests it
when it passes that rule and, for an integer scale, only when `Float64(s)` equals
`s` (for other types it notes that the conversion may round `s`). After the
check, CD, PGD and APG use the loss scale as supplied, combined with `T` by Julia's promotion: a `Float64` scale in a
`Float32` solve keeps its `Float64` value (also where that value is subnormal in
`Float32`). In CD, the coordinate step and the two stopping scales are formed
from that value and rounded to `T` where they enter the iterate or the
tolerance; an integer or `Bool` scale is used there as `T(s)`. The loss part of
CD's reported objective is formed by ProximalBase from the loss as supplied: it
converts an integer or `Bool` scale to `Float64`, forms the product in the
promoted type of the scale and `T`, and rounds the result to `T`. For an integer
or `Bool` scale the check makes `T(s)` and `Float64(s)` both equal `s`, so CD's
step and stopping computations and the objective use the same real scale. The
arithmetic precision can differ: for `Float32` data and the scale `3`, CD's step
and stopping arithmetic is in `Float32` and the objective's product is in
`Float64`; for `Float64` data both are in `Float64`. This convenience does **not**
enable a general mixed-precision model or guarantee that every
intermediate operation uses `T`. Prefer explicit native scalars. Writing
`one(T) / T(n)` chooses a native `T` scale: `n` is converted to `T` and the
division is done in `T`, so the value can differ from the `Float64` `1/n`. The
solve uses that value, and the products with the loss scale are formed in `T`:

```julia
T = Float32
s = one(T) / T(n)
lambda = T(0.1)
f = s * LeastSquaresLoss(y, X)
g = NormL1(lambda)
```

<!-- baseline: docs/src/developer/implementation-notes.md:7-28 -->

The supported solve contract is homogeneous `T = Float32` or
`T = Float64` for the design matrix, response and coefficient iterate.
The boundary checks in `src/solve.jl` enforce matching array element
types, finite data and the solver-specific storage restrictions.
`_scalar_parameter` validates a finite penalty level, and a `Float32` or
`Float64` loss scale, by conversion to `T` and refuses overflow or
nonzero-to-zero underflow. `_check_loss_scale` reads the scale of a `Scaled`
loss through `ProximalBase.leastsquares_data` and accepts a `Float32` or
`Float64` scale that passes that check, and a positive `Base.BitInteger` or
`Bool` scale with `T(α) == α`; a scale of any other type, and an integer that
`T` rounds, is an `ArgumentError` before any write (#307). That is a narrowing
of what was accepted before. For an accepted integer scale, the conversions of
`α` that CD, `_lambda_max!` and `_step_curvature` use (`T(α)` or `Float64(α)`)
and the one that ProximalBase's oracles use (`Float64(α)`) all equal `α`. The
check does **not** globally convert the
original function parameters or ensure that all private arithmetic is of type
`T`. After it CD, PGD and APG use the loss scale as supplied,
combined with `T` by Julia's promotion. CD's `LSModel` stores it as
`s::S` with `S = promote_type(T, typeof(α))` if that is a concrete
`AbstractFloat` type and `S = T` otherwise. The coordinate step and the
two stopping scales form their products with `s` in `S`. The loss part of
the reported objective does not use `s` or `S`: ProximalBase forms it from the

<!-- baseline: docs/src/support.md:133-155 -->


- `w` is a `Vector{T}` with the element type `T` of the data and the coefficients, and one entry per
  coefficient. A `Vector` of the other precision, a view, a range or another array type is refused
  (`collect(T, vec(w))` converts, taking `w` in linear order);
- every weight is finite and nonnegative (an infinite weight is refused);
- the level `lambda` is accepted as above and `T(lambda)` is zero or a normal number of `T` (a level that
  is subnormal in `T` is refused with weights, though an unweighted `NormL1` accepts it), and the coefficient
  `c_j = T(lambda) * w_j` of every entry, the product rounded in `T`, is finite and, where `T(lambda)` and `w_j` are
  both positive, a normal number of `T`. A coefficient that overflows, underflows to zero or is subnormal is
  refused, with the entry `j` named. The rule is on the rounded `c_j`: an exact product slightly below
  `floatmin(T)` that rounds up to `floatmin(T)` is accepted. A zero level or a zero weight gives the
  coefficient 0, which is accepted;
- `x` does not alias `w`, as for `X` and `y`.

These checks run before `x` is copied or written and before the random number generator is
used. A zero weight leaves its coefficient unpenalized: it is not fixed at 0. With CD, a column of
`X` that is zero gets the coefficient 0, also where its weight is zero.

Where `c_j` is used, and where it is not. The checks above, the stopping check of PGD and APG (it scores entry `j` with `c_j` and takes the largest `c_j` as the level `λ` of its scale; see [the stationarity check](@ref "The stationarity check of a stop")), and the coordinate step of CD where it forms its threshold without the product `s * a` use the checked `c_j`. ProximalBase's proximal steps (the proximal step of PGD and APG, and the step of CD where it calls ProximalBase's `prox_block`) form their thresholds from `lambda` and `w_j` in ProximalBase's working type, not from `c_j`. These thresholds and those formed from `c_j` can differ by rounding and, for a `lambda` that is not of type `T`, by the error of converting the level to `T`. When CD takes each step is described in [numerical behavior](numerics.md); the error of `c_j` relative to `lambda * w_j` is described in the [implementation notes](developer/implementation-notes.md). CD's
`converged` remains the change test. A scaled penalty such as `Scaled(NormL1(lambda, w), a)`, and `ElasticNet` with
weights, are refused. [The weighted-lasso tutorial](examples/problems/weighted_lasso.md) solves an adaptive lasso with a zero
weight with all three solvers.

<!-- baseline: docs/src/support.md:164-173 -->

`solve!(x, f, g, AccProxGradDescent())` accept it when `x` is a dense `Vector{T}`, `X` and `y` are as above with the same `T`,
and `lambda` is finite, nonnegative and representable in `T` without overflow or underflow of a nonzero value; a negative or `NaN`
level cannot be constructed (ProximalBase refuses it), and the other refusals leave `x` unchanged. A wrapper such as
`Scaled(NormLinf(lambda), c)` is refused with the other unsupported penalties. `CDSolver` refuses
`NormLinf` for a dense `Vector`, a `SparseIterate` and a `BlockIterate`, before it changes `x` or draws from its random number
generator: this `CDSolver` needs a separable penalty for its coordinate oracle.
The proximal operator is ProximalBase's. In exact arithmetic, 0 is a minimizer exactly when `lambda ≥ ‖∇f(0)‖₁ = s‖Xᵀy‖₁` (not the lasso's
`‖∇f(0)‖∞`). A proposed stop is verified by [the generic check](numerics.md#The-generic-stationarity-check). For an example with both solvers, see
[the ℓ∞ tutorial](examples/problems/linf_regularized_regression.md).

<!-- baseline: docs/src/support.md:215-235 -->

  refused with a `DimensionMismatch`, and an empty group, an index in two groups or in no group, and a change of
  `g.groups` after construction where it disagrees with that layout (ProximalBase's extent and free-coordinate
  logic use the arrays stored at construction) with an `ArgumentError`;
- the level and the weights pass the rules of the [weighted lasso](@ref weighted-lasso-support), with one coefficient
  `c_k = T(lambda) * w_k` per group in place of one per entry (a zero weight leaves its group unpenalized);
- `x` does not alias `X`, `y` or the weights.

These checks run before `x` is written. The proximal step is ProximalBase's block soft threshold. A proposed
stop counts only if ProximalBase's group KKT residual is below `max(gradtol, 64 eps(T)) * S` (for
`AccProxGradDescent`, the check forms `∇f(x)` once per proposed stop and counts it in `grad_calls`), with
`S = max(max_k c_k, max_k ‖[∇f(0)]_{G_k}‖₂)` (see [the stationarity check](@ref "The stationarity check of a stop")).
`test/group_pgd.jl` checks `Float32` and `Float64` solves against references computed from the data in `BigFloat`.
Both `ProximalGradientDescent` and `AccProxGradDescent` run: the closed form on designs with block-orthogonal columns
(raw and `1/n`-scaled loss, default weights and weights with a zero), a correlated design (also against `CDSolver` on a
`BlockIterate`), singleton groups with unit weights against `NormL1(lambda)`, a zero weight, `lambda = 0` against the
least-squares fit, a level above the smallest level with a zero solution, a huge `xtol` or `ftol` that must not stop at a point
that fails the check, and the stop check just below and just above its threshold. Only `ProximalGradientDescent` runs the
contiguous, permuted and single-group layouts given as ranges or as vectors, a group of zero columns, and a `Float64` loss scale
of `1e-300`. Singleton groups with unit weights have the stop scale of `NormL1(lambda)` where no entry of `∇f(0)` has a
subnormal square.

<!-- baseline: docs/src/support.md:316-359 -->

The three numerical arrays use one common `T` (`Float32` or
`Float64`); mixed-element-type `X`, `y` and coefficient arrays
are not supported. The penalty levels must be finite, nonnegative and
representable in `T` without overflow or rounding a nonzero scalar
to zero; it may be supplied in a different scalar type, including
a representable `Float64` literal in a `Float32` problem.

The scale `s` of `Scaled(LeastSquaresLoss(...), s)` multiplies the loss by a fixed number (for example
`s = 1/n`); it does not make the problem the [scaled lasso](glossary.md), which estimates a noise level.
The loss scale is supported as

- a positive finite `Float32` or `Float64` that converts to a finite nonzero
  number of `T` (a value that is subnormal in `T` is accepted, and a `Float64`
  scale in a `Float32` problem is accepted), or
- a positive fixed-width integer (`Int`, `UInt8` and the other `Base.BitInteger`
  types) or `Bool` that `T` represents exactly: `2^24` for `Float32` data, not
  `2^24 + 1`, and `2^53` for `Float64` data, not `2^53 + 1`.

A scale of any other type (`BigInt`, `BigFloat`, `Rational`, `Float16`,
`Irrational` or another `Real`), and an integer that `T` would round, is
refused with an `ArgumentError` before `solve!` writes to the coefficients.
**This narrows the API:** such scales were accepted before the loss value and
gradient were taken from ProximalBase's least-squares oracles. Convert the
scale explicitly, for example `Float64(s) * LeastSquaresLoss(y, X)`, where
`Float64(s)` is finite, positive and representable in `T` as above; the
error message suggests this conversion when it passes that rule and, for an
integer scale, only when `Float64(s)` equals `s`; for other types it notes that
the conversion may round `s`.
The solvers use the supplied scale combined with `T` by Julia's promotion:
a `Float64` scale in a `Float32` problem keeps its `Float64` value, also
where that value is subnormal in `Float32`. The arrays and the coefficients
stay in `T`, so this does not imply mixed-precision array support or a
guarantee about every intermediate arithmetic type.

The data must not be modified while a solve is running. The coefficient
vector (or the supported CD `SparseIterate`) is mutated in place, so do
not alias it to `X` or `y`. To retain a result, save `copy(beta)`.
See [Numerical behavior](numerics.md) for numerical recovery limits,
solver stopping and diagnostics.

For an executable complete example, see [Getting started](getting-started.md).
For using sparse **coefficients**, see the
[sparsity tutorial](sparsity-and-kkt.md). The design matrix still must be
dense, even when the coefficients use `SparseIterate`.

<!-- baseline: src/solvers/proximal_gradient_descent.jl:296-341 -->

Minimize a least-squares lasso (with optional weights), elastic net or ℓ∞-penalized problem (the last with
`ProximalGradientDescent` and `AccProxGradDescent`), or with `CDSolver` a square-root lasso, overwriting `x`.
`x` is a dense `Vector{T}`,
T=Float32 or Float64; `CDSolver` also accepts a one-dimensional `SparseIterate{T}`
(see below), while the gradient methods (`ProximalGradientDescent`, `AccProxGradDescent`) refuse it.
The `BlockIterate` form of `CDSolver` minimizes the group lasso with a `GroupNormL2` penalty on a
`BlockIterate{T}` with the same groups; only `CDSolver` accepts a `BlockIterate`, and `CDSolver` describes it.
`ProximalGradientDescent` and `AccProxGradDescent` also minimize the group lasso on a dense `Vector{T}` (see below). The loss
uses same-type `Matrix` X and `Vector` y. The penalty of the gradient methods is a `NormL1(λ)` or
`NormL1(λ, w)`, an unweighted `ElasticNet(λ1, λ2)` (`λ1 ‖x‖₁ + (λ2/2) ‖x‖²`) or `NormLinf(λ)` (`λ max|xᵢ|`),
whose levels are finite and nonnegative and representable in `T` without overflow or underflow; for a dense
`Vector` or a `SparseIterate`, `CDSolver` accepts the same penalties except `NormLinf` (see [`CDSolver`](@ref)),
which it refuses (its coordinate step needs a separable penalty) before it changes `x` or uses its RNG; its
`BlockIterate` form takes a `GroupNormL2`. The weights `w` of `NormL1(λ, w)` are a
`Vector{T}` with one finite nonnegative entry per entry of `x` (`T` the element type of the data and of `x`),
and `x` must not alias them. `solve!` checks the coefficient `T(λ) wⱼ` of entry `j`, the product rounded in `T`: it must be
finite and, where `T(λ)` and `wⱼ` are both positive, a normal number of `T` (a zero or subnormal product, and a
level `T(λ)` that is subnormal, are refused). The stopping check of PGD and APG uses it; ProximalBase's proximal
steps form their thresholds from `λ` and `wⱼ` in their working type (see
[Supported problems](https://mlakolar.github.io/ProximalSolvers.jl/dev/support/#weighted-lasso-support)). A zero level or weight gives the coefficient 0, which is accepted; a zero
weight leaves its entry unpenalized (it is not fixed at 0). Any other weight array type (a view, a range, a
vector of another element type), a weighted `ElasticNet` and any `Scaled` penalty is refused. Use `(one(T)/T(n))*LeastSquaresLoss` for normalized lasso; raw LS keeps
its unnormalized meaning. One positive finite scalar LS wrapper is supported. `CDSolver` also accepts
ProximalBase's `SqrtLeastSquaresLoss(y, X)` with an unweighted `NormL1(λ)`, `λ > 0`, on a dense `Vector`
or a `SparseIterate` (see [`CDSolver`](@ref)); the gradient methods refuse it, and `CDSolver` refuses it with a weighted `NormL1`.

**Group lasso with `ProximalGradientDescent`.** On a dense `Vector{T}` with the least-squares loss above,
`ProximalGradientDescent` accepts `g = GroupNormL2(λ, groups, w)` (or with the default weights) when `g` is a
`GroupNormL2{T}` (its level and weights have the element type of the data; convert with
`GroupNormL2(T(λ), groups, T.(w))`), its groups partition `1:p` (none empty, no index in two groups,
none in no group, none above `p`) and match the layout stored in the penalty at construction (a change of `g.groups` after
construction is refused where it disagrees with that layout; construct the penalty again), its weights are finite and nonnegative, `T(λ)` is zero or a normal number of `T`,
each coefficient `λ wₖ`, rounded in `T`, is finite and, where `λ` and `wₖ` are both positive, a normal number of `T`,
and `x` does not alias `w`. A zero weight leaves its group unpenalized. The proximal step is ProximalBase's block soft
threshold, and the stopping check uses the group KKT residual of ProximalBase's `kkt_violation` (see
[`ProximalOptions`](@ref)). `AccProxGradDescent` accepts the same `GroupNormL2` with the same stopping check;
`CDSolver` on a dense `Vector` or a `SparseIterate` refuses it.

Borrowed X/y must not alias mutable `x` or change during a solve. Results share
`x`; copy it to retain earlier coefficients. Unsupported inputs/options fail
before mutation. For PGD and APG, a stop of the stopping tests counts only at a point whose
computed KKT residual (for a `NormLinf` penalty, the proximal-gradient residual) meets the bound of
[`ProximalOptions`](@ref), which is not an exact-arithmetic certificate; CD stops by its change test, and for the square-root loss reports
`converged = true` only when a duality certificate passes (see [`CDSolver`](@ref)). Finite intermediate arithmetic is required. PGD step errors restore
its last accepted `x` and rethrow, without a transaction guarantee for internal
counters.

<!-- baseline: docs/src/developer/implementation-notes.md:191-214 -->


Vector y and Matrix X with the same Float32 or Float64 element type are
supported, with positive consistent dimensions and finite entries. The iterate
is a dense Vector of that type for every solver, and additionally a
one-dimensional `SparseIterate` of that type for [`CDSolver`](@ref) only;
[`ProximalGradientDescent`](@ref) and [`AccProxGradDescent`](@ref) refuse every
`SparseIterate`. Use raw PB LS or
one positive finite scalar Scaled LS, and finite nonnegative NormL1 (with optional weights, a `Vector{T}`).
Parameters must be representable; positive values must not round to zero.
Scaling is explicit: raw LS means sum(abs2,y-X*x)/2; divide by n explicitly for
normalized lasso. An accepted loss scale wider than `T` is used as supplied,
combined with `T` by promotion; the penalty level keeps its historical
conversion sites.

X/y are borrowed read-only during solves and must not alias mutable x; for a
`SparseIterate` the check uses the owner's whole backing storage, so even an
owner with no active entries is refused when `parent(activevalues(x))` or a
reshape of it is passed as y or X. Results share x; extended traces copy
x/gradient. Unsupported requests fail before mutation. A CD numerical exception
preserves input x; PGD and APG numerical step exceptions restore their last
accepted point and rethrow. Counters/buffers are not generally transactional. Shape errors are
DimensionMismatch; unsupported combinations/options are informative
ArgumentError.
