# [Proximal gradient iteration](@id PGD-01)

This relocation checkpoint preserves baseline text before normalization.

<!-- Baseline: docs/src/developer/implementation-notes.md:L286-L318; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

PGD retains the native image-then-value-and-gradient order (the value and gradient themselves are ProximalBase's oracles), scalar steps, fused PB prox,
TFOCS objective-to-gradient checks, finite curvature-growth refusal and zero-step
gradient refresh. Objective/iterate/FASTA convergence tests combine by OR. The objective
denominator and the gradient normalizers carry no absolute term: the objective test is
`|F - F'| / |F| < ftol` or the flat form, and the gradient test compares the residual with
`gradtol` times the largest residual so far or times the larger of ‖∇f‖∞ and the proximal-step
residual, against a scale that exceeds `L eps(T) ‖x‖∞`. The iterate test keeps
`xtol * max(‖x‖, 1)`, which for `‖x‖ < 1` is an absolute tolerance. A stop that any of them
proposes is checked once in `_stationary!` (`src/utils.jl`): the minimal-norm KKT residual of
the accepted `x` must be below `max(gradtol, 64 eps(T)) * max(λ, λmax)`, `λmax = α‖Xᵀy‖∞`
(formed once per solve in `xhat` and kept in the state field `λmax`), with `λ` the ℓ1 level of the
penalty. `_stationary!` converts the levels of the penalty to `T` once (`_converted_penalty`; the weights of a
`NormL1`, a `Vector{T}`, are kept as they are) and takes the
level and the residual from that penalty: `_l1_level` is `T(λ0) * maximum(w)`, the largest coefficient, for a
`NormL1` with weights. The
residual is ProximalBase's full-point `kkt_violation` of `NormL1(T(λ0))`, of `NormL1(T(λ0), w)` or of
`ElasticNet(T(λ1), T(λ2))`; for `ElasticNet` it adds `λ2 xᵢ` at the nonzero entries. `λ2` is not in `S`
(the check is the lasso check on the data augmented by `√λ2 I`, see `numerics.md`).
The penalty is validated once by `_check_penalty` in `_check_data`. For an `x` that is not a `BlockIterate`
it accepts a `NormL1` for all solvers (with weights, `_check_l1_weights`: a `Vector{T}` of the length of `x`, finite and nonnegative entries,
no alias with `x`, a level `T(λ0)` that is zero or normal, and the coefficients `T(λ0) wⱼ` finite and, for positive factors, normal) or an unweighted `ElasticNet` for all solvers and refuses any other
penalty; a `BlockIterate` has its own method, for a `GroupNormL2`. The check requires `S =
max(λ, λmax)` finite, that product, formed in `T`, at least `floatmin(T)` and the residual
finite; it does not require the product to be finite. Otherwise the three flags are cleared and the solve continues. PGD uses the `∇f(x)` it holds. APG
forms `∇f(x)` from the cached image `z_x` with `_value_and_gradient!` (ProximalBase's
`value_and_gradient_from_predictor!`), into `xhat`
and `dz`, which the next iteration overwrites before reading, and counts it in `grad_calls`.
The check is a computed working-precision residual, not an exact-arithmetic certificate.
Objective rounding can still end a solve with an objective increase; `ftol = 0`
disables the objective test. Check objective/KKT independently. Native
Float32 may stagnate earlier. Finite inputs do not ensure finite intermediates: the
value is ProximalBase's, which recovers a value whose squares leave the range of `T`,
but the image `X x` and the gradient `α fl(Xᵀd)` are not recovered.

<!-- Baseline: docs/src/developer/implementation-notes.md:L418-L426; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

Callbacks/display sample `print_every`; stored traces include each iteration. A
callback receives the trace when storing, otherwise a state. Limits are checked
after an iteration and counts may overshoot. iteration_converged means a limit,
not success. `ProximalOptions` refuses positive gaptol at construction and does
not store gaptol or gapevery. Solvers, options and `BackTracking` each have one
validating inner constructor (settings are checked as given and after conversion),
so `solve!` does not re-check them; APG still checks β and α in the precision of
the iterate before any state is created.
The retained scalar APIs/results do not introduce a new stopping/logging engine.

<!-- Baseline: src/solvers/proximal_gradient_descent.jl:L2-L47; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

    ProximalGradientDescent(; ls=LineSearches.BackTracking(), normalized=false,
                             debias=0, preconditioner=:none)

Proximal gradient descent (PGD) for least squares with a `NormL1` (lasso, with optional weights), `ElasticNet`,
`NormLinf` or `GroupNormL2` (group lasso) penalty and a dense `Vector{Float32}` or `Vector{Float64}` coefficient
iterate. Each iteration takes a gradient step for the smooth least-squares loss and applies the
proximal operator of the penalty (ProximalBase's `value_and_prox!`): soft thresholding for `NormL1` (at the level
`λ wⱼ` of entry `j` for `NormL1(λ, w)`), soft thresholding followed by the ridge weight for `ElasticNet`, for
`NormLinf`, the point minus its projection onto the ℓ1 ball of radius `λ/L` (a clip of the entries at a common
level), and for `GroupNormL2` the block soft threshold (each group block `v_G` of the input scaled by
`max(0, 1 - γ λ wₖ/‖v_G‖₂)` at the step `γ`; a zero block stays zero); backtracking adjusts
the step size.
The curvature estimate before the first iteration is `min(1, α_f ‖X‖_F²)` for the loss scale
`α_f`, with `‖X‖_F` an upper bound, rounded to `T` and raised to `floatmin(T)` when it is positive and
rounds below that; it is `1` when that product is at least 1 or `X = 0`.

`ProximalGradientDescent()` uses the supported
`LineSearches.BackTracking()` line search. A trial that it rejects is decided
again, except in the cases that the `LineSearches.BackTracking` docstring
lists, by the computed curvature `c` of the step from one product `X d`: it is
accepted when `L ≥ c`, and otherwise the retry uses `c` in place of the
estimate `L̂` when `c` is finite (see `LineSearches.BackTracking` and
[numerical behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/)). The options
`normalized=true`, `debias>0`, `preconditioner!=:none` and custom
line searches are not implemented and are rejected. These constructor
keywords remain for compatibility with earlier versions; their default values
are accepted and not stored.

Pass `ProximalOptions(...)` as the fifth argument to `solve!` to
configure stopping tolerances and iteration limits. A stop that the `xtol`, `ftol` or
`gradtol` test proposes counts only if the computed KKT residual of the iterate is below
`max(gradtol, 64 eps(T)) * max(λ, λmax)`, with `λmax = α‖Xᵀy‖∞` and `λ` the ℓ1 level of the penalty
(`λ` of `NormL1(λ)`, the largest coefficient `T(λ) * maximum(w)` of `NormL1(λ, w)`, `λ1` of `ElasticNet`; see
[`ProximalOptions`](@ref)); for `GroupNormL2(λ, groups, w)` the residual is the group KKT residual,
`λmax = maxₖ α‖[Xᵀy]_{Gₖ}‖₂` and `λ = T(λ) * maximum(w)`; for `NormLinf` the generic proximal-gradient check of
[`ProximalOptions`](@ref) applies instead. For `NormL1`, `ElasticNet` and `GroupNormL2`, `converged=true` guarantees
only that the computed, normalized KKT
residual `‖G‖∞ / max(λ, λmax)` is below `max(gradtol, 64 eps(T))` (the threshold is formed in
`T`, which can round or overflow; see [`ProximalOptions`](@ref)); it is not an
exact-arithmetic certificate, does not bound the distance to a minimizer and does not
guarantee coefficient accuracy on ill-conditioned designs (see the
[stationarity check](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/#The-stationarity-check-of-a-stop)), and the default tolerances are not a specified number of correct digits. In `Float32`, a solve can report `converged = true` at a relative duality gap above `1e-5`, as in measurements on small benchmark designs (see
[the limits of the stopping tests](https://mlakolar.github.io/ProximalSolvers.jl/dev/stopping-limits/)). Tighten tolerances and
check KKT conditions independently before reporting numerical results.
See the [solver guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/choosing-solver/)
and [numerical behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/).

