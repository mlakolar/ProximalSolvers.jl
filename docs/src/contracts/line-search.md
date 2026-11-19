# [Backtracking line search](@id LS-01)

This relocation checkpoint preserves baseline text before normalization.

<!-- Baseline: src/line_searches.jl:L16-L92; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

    BackTracking(; α = 0.9, β = 0.5, Lexact = Inf)

The backtracking line search of TFOCS (`private/tfocs_backtrack.m`). Each
iteration starts from `L ← α L`, where `1/L` is the step size, and while the
local Lipschitz estimate `L̂` of the step exceeds `L` it retries with
`L ← min(Lexact, max(L̂, L / β))`. `L̂` comes from function values until they
are too close to compare in floating point, and from gradients after that.
An LS trial whose image or value overflows is never accepted: it gives no
estimate, and the search retries with `L ← L / β`.

For [`ProximalGradientDescent`](@ref ProximalSolvers.ProximalGradientDescent)
on its supported least-squares model, a rejected trial with step `d̂ = x - x'`
is decided again by the computed curvature of the step,
`c = m α ‖fl(X d̂)‖²/‖d̂‖²`, from one product `X d̂`, with `m = 1` for
function-value estimates and `m = 2` for gradient estimates (TFOCS's gradient
test `2α ‖X d‖² ≤ L ‖d‖²`). When `L ≥ c` the trial is accepted and the estimate
mode is unchanged; otherwise the retry uses `L ← min(Lexact, max(c, L / β))`
when `c` is finite, and TFOCS's `L ← min(Lexact, max(L̂, L / β))` when it is
not. `c` carries no rounding certificate: when `L` is within rounding of the
curvature along `d̂`, the decision can go either way. For Float32 data the
squared norms are accumulated in Float64, and two allowances are added to
`‖fl(X d̂)‖` before squaring: `2√n p floatmin(Float32)` for underflow of the
results, and `√n floatmin(Float32) ‖d̂‖₁` for subnormal entries of `X` that a
thread flushing subnormals to zero (the calling thread or a BLAS thread) drops
from the product. They assume that flushing affects only subnormal operands and
results, and give no certificate. The curvature value compared with `L`, in
Float64, is then positive when finite, so a product lost to underflow or
flushing does not make it zero. The estimate used for a retry is that value
rounded to Float32, which may round to Inf (when the conversion overflows).
TFOCS's update is kept when the product overflowed, when the calling thread
flushes subnormals to zero, and when `d̂` has a subnormal entry. For Float64 data,
overflow or underflow of `‖fl(X d̂)‖²`, underflow of `‖d̂‖²`, and overflow of `‖d̂‖²` for a
step with a nonfinite entry or in a narrow band around the overflow threshold of `‖d‖²`
(where `norm(d)^2` can be finite and `sum(abs2, d)` not) can make `c` nonfinite (TFOCS's
update is then kept) or spuriously zero (the trial is then accepted). A rejection is not
checked, and keeps TFOCS's update, when its trial value is not finite, when the
computed `‖d̂‖²` is zero (the zero-step exit, which includes a tiny nonzero step
whose square underflows), when `L̂` is NaN, or when a gradient estimate comes
from a gradient `∇f(x)` with a nonfinite entry. Accepted trials are not checked.

When the step `d = x - x'` of a trial has finite entries, `norm(d)^2` overflows in the type of
`x` (the squared norm is `Inf`) and the trial value `f(x)` is finite, the trial is decided on the
scaled step `d̃ = s d`, `s = 2^(-e)` with `e = min(exponent(max |dᵢ|), exponent(floatmax(T)) - 1)`
for the type `T` of `x`, so that `s` is a normal number and the largest entry of `d̃` is in
`[1, 2)`, or in `[2, 4)` when `exponent(max |dᵢ|)` is `exponent(floatmax(T))`. A trial whose
value `f(x)` is not finite is not scaled: it takes the exit for a nonfinite trial value described
above. `L̂` is formed from `d̃`, from `f(x)` and `f(x')` multiplied by `s²` (by shifting their
exponents, since `s²` can underflow), and from the products of `d̃` and `∇f` multiplied by `s`;
in exact arithmetic it equals the estimate at `d`. The trial is then decided as at a
representable scale, up to the rounding of the computed `f` and `∇f`, overflow of the products
`⟨d̃, ∇f(x')⟩` and `⟨∇f(x) - ∇f(x'), d̃⟩` before they are multiplied by `s` (an infinite
product, or a NaN from overflowed terms of opposite sign), and underflow of an entry of `d̃`, of
a scaled function value or of `L̂`. Such a product is not recovered by the scaling: `L̂` is
formed from it by the same expressions as for an unscaled step, with the scaled quantities, so
it can be finite, infinite or NaN (for example, with finite `f(x)` and `f(x')`, a `+Inf`
function-value product gives `L̂ = L`, and the trial is accepted without the check). The check
of a rejected trial reads `d̃`, with `‖d̃‖²` between 1 and about `16n`; for Float32 data it is
also subject to the allowances above, and an entry of `d̃` that is subnormal keeps TFOCS's
update, while an entry of `d` with `|s dᵢ| ≤ 2^-150` rounds to zero in `d̃`, is not detected, and
drops out of both sums of squares and of the product. After an accepted trial the solver state
holds `x - x'` again. A step with a nonfinite entry is not scaled, and neither is a step whose
squared norm underflows.

In gradient mode a zero gradient-difference product gives `L̂ = 0`, and the trial is
accepted. This includes Float64 data with `‖d̂‖²` below `2/floatmax(Float64)` (about
1.1e-308), where `2/‖d̂‖²` overflows and scaling the product would give `0 · Inf = NaN`.
A subnormal `‖d̂‖²` can make the Float64 estimates unreliable, and this does not make a
solve converge at such scales: a solve can still end with `converged = false` or with a
line-search error. One case is not handled: a subnormal `‖d̂‖²` with a nonzero product, or
with function-value rounding noise (`f(x) > q`, with `q` the quadratic model at the trial
`x`), can give `L̂ = Inf`, and when `sum(abs2, d̂)` underflows to 0 while `‖d̂‖² > 0` (every
entry of `d̂` below about 1.57e-162), the computed curvature of the step is not finite and
does not replace that estimate.
See [numerical behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/).

The object holds settings only and can be shared between solves; the
bookkeeping lives in the solver state.

<!-- Baseline: docs/src/numerics.md:L1004-L1074; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

  **Steps whose squared norm overflows.** Suppose the step `d = x - x'` of a trial has
  finite entries, the computed `norm(d)^2` is `Inf` in `T` (a step above about 1.3e154 in
  Float64 and about 1.8e19 in Float32, which includes a step whose norm is itself above
  `floatmax(T)`), and the trial value `f(x)` is finite. The trial is then decided on the
  scaled step `d̃ = s d`, with `s = 2^(-e)` and
  `e = min(exponent(max |dᵢ|), exponent(floatmax(T)) - 1)`, so that `s` is a normal number
  and the largest entry of `d̃` is in `[1, 2)`, or in `[2, 4)` when `exponent(max |dᵢ|)` is
  `exponent(floatmax(T))` (1023 in Float64, 127 in Float32). A trial whose `f(x)` is not
  finite is not scaled: it takes the exit for a nonfinite trial value described above, as before.
  The local estimate `L̂` is computed from `d̃` and from `f(x)` and `f(x')` multiplied by `s²`
  (by shifting their exponents, since `s²` can underflow), with the products of `d̃` and `∇f`
  multiplied by `s`; in exact arithmetic it equals the estimate at `d`. The check of a
  rejected trial reads `d̃`, and after an accepted trial the solver state holds `x - x'` again.
  The trial is decided as at a representable scale, up to the rounding of the computed `f` and
  `∇f`, overflow of the products `⟨d̃, ∇f(x')⟩` and `⟨∇f(x) - ∇f(x'), d̃⟩` before they are
  multiplied by `s`, underflow of an entry of the scaled step, of a scaled function value or
  of `L̂`, and, for Float32 data, the allowances of the check described above. Not changed:
  - a step with a nonfinite entry is not scaled, and its trial is decided as before;
  - a step whose squared norm is subnormal or underflows to zero is not scaled
    ([#317](https://github.com/mlakolar/ProximalSolvers.jl/issues/317));
  - an overflow of `⟨d̃, ∇f(x')⟩` (in the function-value estimate) or of
    `⟨∇f(x) - ∇f(x'), d̃⟩` (in the gradient estimate) before the factor `s`, or a NaN from
    overflowed terms of opposite sign, is not recovered by the scaling. `L̂` is formed from
    that infinite or NaN product by the same expressions as for an unscaled step, with the
    scaled quantities, so it can be finite, infinite or NaN. For example, with finite `f(x)` and
    `f(x')`, a `+Inf` function-value product gives `L̂ = L`, and the trial is accepted without
    the check;
  - an overflow of `‖fl(X d̂)‖²` for a representable `‖d̂‖²` is handled by the check as before;
  - for Float64 data, in a narrow band around the overflow threshold of `‖d‖²`,
    `norm(d)^2` can be finite while the sum of squares of `d` that the check forms
    overflows (in a probe with random `d` of length 10, 100 and 1000, within about
    `2 eps` of the threshold); the step is not scaled, and its trial is decided as before;
  - for Float32 data, a subnormal entry of `d̃` (nonzero, below `floatmin(Float32)`) makes the
    check keep TFOCS's update, as it does for any `d̂` with a subnormal entry, and the check
    does not accept the trial. An entry of `d` with `|s dᵢ| ≤ 2^-150` (half the least positive
    number) rounds to zero in `d̃`, which is not detected: it drops out of both sums of
    squares and of the product (`d = [2^70, 2^-80]` scales to `[1, 0]`). In exact arithmetic
    `X d̃` is `s` times `X d`; the stored product can differ when an entry of `d̃` has
    underflowed (for `X = [0 1]` and the `d` above, `X d̃ = 0` while `s X d = 2^-150`). The
    allowances of the Float32 check are absolute, so they weigh more against `‖fl(X d̃)‖` the
    smaller it is, and they change `c` where it is of the order of the allowances.
- APG handles a failed step in the same way. Its backtracking raises an error, after which the last
  accepted iterate is restored, when the next curvature estimate `L/β` is not a
  finite increase; a trial whose objective is not finite is never accepted.
  An extrapolated point whose objective or gradient is not finite restarts the
  momentum when the step uses momentum; without momentum the step fails, with the
  same rollback. Its line search accepts a step only when the least-squares bound
  `√α ‖X(x - y)‖ ≤ (1 + 4eps) √L ‖x - y‖` is certified by conservative
  floating-point error bounds for the stored `x` and `y`, so it does not subtract
  nearly equal objective values and does not accept a step whose bound check is
  dominated by rounding. It first uses the difference of the cached images `X x`
  and `X y`, whose error is bounded through `‖X‖_F` and the iterate norms; when
  that bound leaves the decision open it computes `X(x - y)` afresh, one extra
  matrix-vector product whose error bound is a relative term proportional to the
  step plus an absolute underflow term, and rejects a step that is still undecided.
  The norms and the bound arithmetic are carried as significand and binary
  exponent, so they do not overflow or round to subnormal values in `T`; the native
  products and their underflow enter only through the bounds. A curvature above
  `floatmax(T)` is never certified, so backtracking then ends in its error with
  rollback. These bounds assume IEEE arithmetic with gradual underflow and a
  matrix-vector product evaluated as dot products; the native products and the
  extrapolation are computed in `T` and enter only through the bounds. The extra
  product is needed more often in Float32, where the bounds are wider relative to
  small late steps; for data deep in the subnormal range, where the underflow terms
  can dominate the bounds, a step may need `L` far above the curvature, or the solve
  may fail with rollback. APG also
  requires `max(n, p) + 4 < 1/(4 eps(T))` and `n p + 3 < 1/(4 eps(Float64))`; larger
  problems are refused before `x` is modified.
- Reaching a pass or iteration limit is not convergence. CD can return
  a finite nonconverged solution with a warning.


