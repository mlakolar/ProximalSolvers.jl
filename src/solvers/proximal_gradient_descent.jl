"""
    ProximalGradientDescent(; ls=LineSearches.BackTracking(), normalized=false,
                             debias=0, preconditioner=:none)

Proximal gradient descent (PGD) for least-squares lasso (with optional weights), elastic net or group lasso
(`GroupNormL2`) with a dense `Vector{Float32}` or `Vector{Float64}` coefficient iterate. Each iteration
takes a gradient step for the smooth least-squares loss and applies the
proximal operator of the penalty, soft thresholding for `NormL1` (at the level `λ wⱼ` of entry `j` for
`NormL1(λ, w)`), soft thresholding followed by the ridge weight for `ElasticNet`, and ProximalBase's block soft
threshold for `GroupNormL2` (each group block `v_G` of the input scaled by `max(0, 1 - γ λ wₖ/‖v_G‖₂)` at the step `γ`;
a zero block stays zero); backtracking adjusts
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
[`ProximalOptions`](@ref)); for `GroupNormL2(λ, groups, w)` the residual is the group KKT residual and
`λmax = maxₖ α‖[Xᵀy]_{Gₖ}‖₂`, `λ = T(λ) * maximum(w)`. `converged=true` guarantees only that the computed, normalized KKT
residual `‖G‖∞ / max(λ, λmax)` is below `max(gradtol, 64 eps(T))` (the threshold is formed in
`T`, which can round or overflow; see [`ProximalOptions`](@ref)); it is not an
exact-arithmetic certificate, does not bound the distance to a minimizer and does not
guarantee coefficient accuracy on ill-conditioned designs (see the
[stationarity check](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/#The-stationarity-check-of-a-stop)), and the default tolerances are not a specified number of correct digits. In `Float32`, a solve can report `converged = true` at a relative duality gap above `1e-5`, as in measurements on small benchmark designs (see
[the limits of the stopping tests](https://mlakolar.github.io/ProximalSolvers.jl/dev/stopping-limits/)). Tighten tolerances and
check KKT conditions independently before reporting numerical results.
See the [solver guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/choosing-solver/)
and [numerical behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/).
"""
struct ProximalGradientDescent{L} <: ProximalSolver
  ls::L
  # The only constructor; BackTracking validates its own settings.
  function ProximalGradientDescent(ls::L) where L
    ls isa LineSearches.BackTracking || throw(ArgumentError("only BackTracking is supported"))
    new{L}(ls)
  end
end

Base.summary(::ProximalGradientDescent) = "Proximal Gradient Descent"

ProximalGradientDescent(ls, normalized::Bool, debias::Int) = ProximalGradientDescent(; ls, normalized, debias)

# normalized, debias and preconditioner are accepted at their defaults only and not stored.
function ProximalGradientDescent(; ls = LineSearches.BackTracking(), normalized::Bool = false, debias::Integer = 0, preconditioner::Symbol = :none)
  debias >= 0 || throw(ArgumentError("debias must be nonnegative, but it is $debias."))
  !normalized || throw(ArgumentError("normalized IHT is deferred"))
  iszero(debias) || throw(ArgumentError("debiasing is deferred"))
  preconditioner === :none || throw(ArgumentError("preconditioning is deferred"))
  ProximalGradientDescent(ls)
end

# Native dense iterates/gradients with retained LS image buffers.
mutable struct ProximalGradientDescentState{T, X<:Vector{T}, G<:Vector{T}, M, Z}
    x::X
    f_x::T
    g_x::T
    grad_f_x::G
    x_previous::X
    f_x_previous::T
    g_x_previous::T
    grad_f_x_previous::G
    xhat::X
    delta_x::X
    L::T
    max_residual::T
    λmax::T         # ‖∇f(0)‖ in the norm _scale_norm(g) of the penalty (the ∞-norm for NormL1 and
                    # ElasticNet, the largest group 2-norm for GroupNormL2), -1 until it is computed
    backtrack_simple::Bool  # line search uses function values, not gradients
    backtrack_steps::Int
    f_calls::Int
    grad_calls::Int
    prox_calls::Int
    model::M
    z_x::Z            # A x
    dz::Z             # F' at A x; buffer of the product A d of a checked rejection
    verifications::Int  # rejections checked by the computed curvature (one product A d each)
    # true when the last rejection of the current iteration's line search replaced its estimate L̂
    # by the finite computed curvature c of the rejected step (the retry's L is then
    # min(Lexact, max(c, L/β)) for the rejected trial's L, which need not equal c); set by
    # backtrack!, cleared at the start of update_state!
    verified_rejection::Bool
end


function initial_state(
          method::ProximalGradientDescent,
          options,
          f,
          g,
          x0::Vector{T}) where T

    grad_f_x = _dense_similar(x0)
    model = _image_model(f)
    z_x = _image_buffer(model)
    dz = similar(z_x)
    _image!(z_x, model, x0)
    f_x = _value_and_gradient!(grad_f_x, x0, f, z_x, dz)
    _check_start(f_x)
    g_x = T(g(x0))

    ProximalGradientDescentState(
                         x0,          # Maintain current state in state.x
                         f_x,         # Maintain current f(x) in state.f_x
                         g_x,         # Maintain current g(x) in state.g_x
                         grad_f_x,    # Maintain gradient of f at current x in state.grad_f_x
                         _similar(x0), # Maintain previous state in state.x_previous
                         T(NaN),      # Store previous f in state.f_x_previous
                         T(NaN),      # Store previous g in state.g_x_previous
                         _similar(grad_f_x), # Maintain previous gradient of f in state.grad_f_x_previous for convergence check
                         _similar(x0), # Temporary storage
                         _similar(x0), # Temporary storage for x1 - x0
                         _scanned_initial_curvature(T, model.X, model.α), # L
                         T(-Inf),     # max_residual
                         -one(T),     # λmax, not yet computed
                         true,        # backtrack_simple
                         0,           # backtrack_steps
                         1,           # f_calls
                         1,           # grad_calls
                         0,           # prox_calls
                         model,
                         z_x,
                         dz,
                         0,
                         false
                         )
end

# The start of L from one column-wise pass over X, equal to _initial_curvature of the
# bound that _frobenius_upper forms from the same sum s = Σ Float64(Xᵢⱼ)². The pass stops
# at the end of a column where s is finite and s ≥ thr = 2/α, and the start is one(T). There
# s ≤ (1 + γ_N)‖X‖_F² + N nextfloat(0.0) (the last term for squares that underflow) and, for a
# normal thr, the quotient has relative error at most u, so that α‖X‖_F² ≥ 1 and the bound is
# at least 1 as well, for N u < 1/8 and N nextfloat(0.0) far below thr. There is no early
# exit when thr is not a normal number: 2/α overflows to Inf for α < 2/floatmax(Float64), and is
# subnormal for α > 2/floatmin(Float64). A non-finite s ends the pass, and _frobenius_upper
# then takes its scaled pass.
function _scanned_initial_curvature(::Type{T}, X, α) where {T}
  thr = 2 / Float64(α)
  thr >= floatmin(Float64) || (thr = Inf)
  s = 0.0
  for j in axes(X, 2)
    @inbounds @simd for i in axes(X, 1)
      s += abs2(Float64(X[i, j]))
    end
    isfinite(s) || break
    s >= thr && return one(T)
  end
  _initial_curvature(T, _root_scale(T, α), _frobenius_upper(T, X, s))
end

function update_state!(
    f, g,
    state::ProximalGradientDescentState{T},
    method::ProximalGradientDescent
    ) where T

    # copy x --> x_previous
    _copyto!(state.x_previous, state.x)
    state.f_x_previous = state.f_x
    state.g_x_previous = state.g_x
    _copyto!(state.grad_f_x_previous, state.grad_f_x)
    state.L *= method.ls.α
    state.verified_rejection = false

    # backtracking loop
    while true
      # find next point
      _step!(state.xhat, state.x_previous, state.grad_f_x_previous, state.L)
      state.g_x = convert(_eltype(state.x), value_and_prox!(state.x, g, state.xhat, one(state.L) / state.L))
      state.f_x = _value!(state.x, f, state.model, state.z_x)
      state.prox_calls += 1
      state.f_calls += 1

      # check if enough progress is done
      backtrack!(state, method.ls, f, g) && break
    end
    if has_updated_gradient( state, method.ls ) == false
        LineSearches.value_and_gradient_at_x!(state, f)
        state.f_calls += 1
        state.grad_calls += 1
    end
    state
end


LineSearches.value_and_gradient_at_x!(state::ProximalGradientDescentState, f) =
  _value_and_gradient!(state.grad_f_x, state.x, f, state.z_x, state.dz)

# The computed curvature c = m α ‖fl(X d̂)‖²/‖d̂‖² of the rejected step d̂ = state.delta_x, from
# the product X d̂ formed in dz (scratch: _value_and_gradient! writes it before any
# read), with m = 1 in function-value mode and m = 2 in gradient mode. Returns (accepted, c):
# accepted is the comparison of the curvature value with L (in Float64 for Float32 data), and c,
# of type T, is the estimate that the caller uses after a rejection.
function LineSearches.check_rejection!(state::ProximalGradientDescentState, gradient_mode::Bool)
    mul!(state.dz, state.model.X, state.delta_x)
    state.verifications += 1
    _step_curvature(state, gradient_mode ? 2 : 1)
end

# Float64 data: both sums of squares in Float64. Overflow or underflow of either sum can make c
# nonfinite (Inf or NaN; the caller then keeps TFOCS's estimate) or spuriously zero (a finite
# numerator over an overflowed denominator, or an underflowed numerator; the trial is then
# accepted).
function _step_curvature(state::ProximalGradientDescentState{T}, m) where T
    c = m * (T(state.model.α) * (sum(abs2, state.dz) / sum(abs2, state.delta_x)))
    c <= state.L, c
end

# Float32 data. The computed curvature is not used, and the result is (false, Inf32) so that the
# caller keeps TFOCS's estimate, when the calling thread flushes subnormals to zero
# (get_zero_subnormals(), one read of the floating-point control register) or when d̂ has a
# subnormal entry, which a flushing thread could drop from the product. Otherwise the sums of
# squares are accumulated in Float64, where the square of a finite Float32 is exact, so neither
# sum overflows or underflows, and ‖d̂‖² > 0 for d̂ ≠ 0. An entry of fl(X d̂) that overflowed to
# Inf or NaN makes the curvature nonfinite: the trial is not accepted and the caller keeps
# TFOCS's estimate. Two allowances are added to ‖fl(X d̂)‖ before squaring, under the assumption
# that flushing to zero, by the calling thread or by a BLAS thread, affects only subnormal
# operands and results: τ = 2√n p floatmin(Float32) for underflow of the results, and
# √n floatmin(Float32) ‖d̂‖₁ for subnormal entries of X dropped from the product, each of which
# changes an entry of fl(X d̂) by at most floatmin(Float32) |d̂ⱼ|. They are not a bound on the
# total error of the product, which also carries the rounding of its products and sums, and the
# curvature carries no certificate. The comparison value
# c64 = m α (‖fl(X d̂)‖ + τ + √n floatmin(Float32) ‖d̂‖₁)²/‖d̂‖², in Float64, is at least
# m α τ²/‖d̂‖² > 0 when finite, so a product lost to underflow or flushing does not make it zero.
# Acceptance is c64 ≤ L in Float64. The returned estimate Float32(c64) is used after a rejection
# only, where c64 > L and L is a Float32, so Float32(c64) ≥ L under round-to-nearest; it can
# round to 0 (after an acceptance, where it is unused) and may round to Inf (when the conversion
# overflows).
function _step_curvature(state::ProximalGradientDescentState{Float32}, m)
    get_zero_subnormals() && return false, Inf32
    den, l1, subnormal = _step_norms64(state.delta_x)
    subnormal && return false, Inf32
    n, p = size(state.model.X)
    fm, rn = Float64(floatmin(Float32)), sqrt(Float64(n))
    w = sqrt(_sumsq64(state.dz)) + 2 * rn * p * fm + rn * fm * l1
    c = m * (Float64(state.model.α) * (w^2 / den))
    c <= state.L, Float32(c)
end

# Σ vᵢ² of an array of Float32 or Float64, accumulated in Float64
function _sumsq64(v)
    s = 0.0
    @inbounds @simd for i in eachindex(v)
        s += abs2(Float64(v[i]))
    end
    s
end

# Σ vᵢ² and Σ |vᵢ| of a Float32 vector, accumulated in Float64, and whether an entry is subnormal
function _step_norms64(v)
    s2, s1, subnormal = 0.0, 0.0, false
    @inbounds @simd for i in eachindex(v)
        x = Float64(v[i])
        s2 += abs2(x)
        s1 += abs(x)
        subnormal |= issubnormal(v[i])
    end
    s2, s1, subnormal
end

"""
    solve!(x, f, g, CDSolver())
    solve!(x, f, g, ProximalGradientDescent(), options=ProximalOptions())
    solve!(x, f, g, AccProxGradDescent(), options=ProximalOptions())
    solve!(x::BlockIterate, f, g::GroupNormL2, CDSolver())

Minimize a least-squares lasso (with optional weights) or elastic net, or with `CDSolver` a square-root lasso,
overwriting `x`. `x` is a dense `Vector{T}`,
T=Float32 or Float64; `CDSolver` also accepts a one-dimensional `SparseIterate{T}`
(see below), while the gradient methods (`ProximalGradientDescent`, `AccProxGradDescent`) refuse it.
The `BlockIterate` form of `CDSolver` minimizes the group lasso with a `GroupNormL2` penalty on a
`BlockIterate{T}` with the same groups; only `CDSolver` accepts a `BlockIterate`, and `CDSolver` describes it.
`ProximalGradientDescent` also minimizes the group lasso on a dense `Vector{T}` (see below). The loss
uses same-type `Matrix` X and `Vector` y. The penalty of the gradient methods is a `NormL1(λ)` or
`NormL1(λ, w)` or an unweighted `ElasticNet(λ1, λ2)` (`λ1 ‖x‖₁ + (λ2/2) ‖x‖²`), whose levels are
finite and nonnegative and representable in `T` without overflow or underflow; for a dense `Vector` or a
`SparseIterate`, `CDSolver` accepts the same penalties (see [`CDSolver`](@ref)); its `BlockIterate`
form takes a `GroupNormL2`. The weights `w` of `NormL1(λ, w)` are a
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
computed KKT residual meets the bound of [`ProximalOptions`](@ref), which is not an
exact-arithmetic certificate; CD stops by its change test, and for the square-root loss reports
`converged = true` only when a duality certificate passes (see [`CDSolver`](@ref)). Finite intermediate arithmetic is required. PGD step errors restore
its last accepted `x` and rethrow, without a transaction guarantee for internal
counters.

**CD on a dense vector.** A numerical error, including a nonfinite final
objective, leaves `x` unchanged.

**CD on a `SparseIterate`.** All checks of inputs, options, shapes, finiteness of
the active values, representable parameters and detectable aliases of `x` with X
or y (through its backing storage, whether or not it has active entries) happen
before the iterate is copied and before the RNG is used, so a refused call neither changes `x` nor
advances the RNG. The solve then runs on `work = copy(x)`, which keeps the
values, active zeros and the order of the active coordinates, with the same
passes, activation, per-pass removal of zero coordinates, momentum and stopping
as for a dense vector. It needs O(p) extra storage, and nothing is reconstructed
through a dense vector.

When the run completes, with a finite objective, `x` receives the whole final
state of `work` by a same-shape `copyto!(x, work)`: this includes a finite
`maxpasses` outcome with `converged = false` and its warning, and `maxpasses = 0`,
which leaves exactly the entry state, including active zeros and slot order.
Zeros that a pass removed from `work` are not restored, and the order is not
sorted. The result's `minimizer` is `x` itself. A numerical error (such as a
nonfinite step or objective) throws with the values, the active set, signed zeros
and the order of `x` unchanged; the borrowed RNG may already have advanced.
After a successful call, take `activevalues(x)` and `activecoordinates(x)` again:
handles taken earlier may no longer describe the active set.

**CD on a `BlockIterate`.** The checks of the receiver, momentum, penalty, groups,
parameters, aliasing and finiteness happen before the iterate is copied and before the RNG is
used, and a refused call neither changes `x` nor advances the RNG. The curvature and step
refusals that can be decided from the data follow, before the first pass, before any RNG draw and
only when `maxpasses > 0`, with `x` unchanged; the curvature of a group that is neither flat nor
a one-column group with `n eps(T) <= 1/8` is computed in that preparation, or at the first visit that
needs it when cheap bounds exclude a refusal (under the eigenvalue model for groups of three or more columns and for groups of two columns
outside the range of their closed-form bound), and an exception of its eigenvalue routine or a
refusal at that point happens during a pass, with `x` unchanged and the RNG possibly advanced. The solve
then runs on `work = copy(x)` and `x` receives the final state of `work` by one `copyto!`.
Zero groups are deactivated after a pass, so the active groups of `x` after a solve with at
least one pass are the groups with a nonzero block; with `maxpasses = 0` the entry state is kept,
including active groups whose block is zero. A numerical error leaves
the values and the active groups of `x` unchanged, though the borrowed RNG may already have
advanced. The result's `minimizer` is `x` itself.
"""
function solve!(x, f, g, method::ProximalGradientDescent,
                options::ProximalOptions = ProximalOptions(); kwargs...)
  _check_keywords(kwargs)
  _check_problem(x, f, g)
  t0 = time()
  state = initial_state(method, options, f, g, x)
  _solve_gradient!(state, f, g, method, options, t0)
end

# Numerical stagnation, after an iteration of _solve_gradient!: true for Float32 PGD with ftol = 0
# when the accepted iterate equals the previous one elementwise and the last rejection of the
# iteration's line search replaced its estimate L̂ by a finite computed curvature
# (verified_rejection). It is false for AccProxGradDescent, for Float64 PGD and when ftol > 0.
# The stop it causes is not a convergence or accuracy test.
_stagnated(state, options) = false
_stagnated(state::ProximalGradientDescentState{Float32}, options) =
  iszero(options.ftol) && state.verified_rejection && _unchanged(state.x, state.x_previous)
