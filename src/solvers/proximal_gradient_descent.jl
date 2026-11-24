"""
    ProximalGradientDescent(; ls=LineSearches.BackTracking(), normalized=false,
                             debias=0, preconditioner=:none)

Proximal gradient descent for least squares with `NormL1` or `ElasticNet` (each
optionally weighted), `NormLinf`, `NormL2`, `GroupNormL2`, unweighted `NormL1Nonneg` or
`IndNonnegative()`.
Vector regression uses dense Float32 or Float64 coefficients and same-type data.
For a matrix response, use dense same-type `X`, `Y` and `B` with unweighted
`NormL1(lambda)`.
Each iteration combines a smooth-loss gradient step with the penalty's proximal
operator, using backtracking. Pass [`ProximalOptions`](@ref) as the fifth argument
to [`solve!`](@ref) for stopping and tracing.

```julia
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
beta = zeros(2)
result = solve!(beta, (1/3)*LeastSquaresLoss(y, X), NormL1(0.1),
                ProximalGradientDescent())
```

`converged` is a computed stopping decision, not a coefficient-accuracy promise;
see [the stopping contract](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-stopping/#STOP-01).

# Extended help

`ls` must be `LineSearches.BackTracking`; custom line searches are unsupported.
The compatibility keywords `normalized=false`, `debias=0` and
`preconditioner=:none` are accepted only at their defaults and are not stored.
PGD also solves the graphical lasso with `LogDetLoss(S)` and finite, nonnegative,
symmetric `Matrix` weights in `NormL1(λ₀, Λ)`, where diagonal weights are permitted.
Start from a same-type dense Float32 or Float64 SPD matrix. See [matrix PGD](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-logdet/#PGD-06)
for the supported options and the KKT stopping check.

The entrywise matrix lasso applies the penalty to every coefficient, including
diagonal entries. See [IN-10](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-10).
The weights of an `ElasticNet(lambda1, lambda2, w)` scale only its L1 term; see
[IN-03](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-03).
Weighted matrix regression penalties are deferred. PGD requires dense
coefficients and refuses `SparseIterate`, `BlockIterate` and square-root loss. A group penalty must have the same
parameter type as the data and groups partitioning the coefficients.

`NormL2(lambda)` penalizes the Euclidean norm of the whole coefficient vector. Use
it on a dense vector with raw or positively scaled least squares. See
[the Euclidean-norm input contract](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-11)
and [its stopping check](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-stopping/#STOP-17).

PGD also fits sparse logistic regression with a raw `LogisticLoss(y, X)` (dense
`Matrix{Float64}` design, binary `Vector{Float64}` response, no observation
weights or offset) and `NormL1`, with or without penalty weights, on a
`Vector{Float64}`. The loss is the sum over observations; a zero penalty weight
leaves an intercept column unpenalized. Unsupported logistic inputs are refused when
`solve!` is called, before any write. See [the logistic input contract](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-09).

For nonnegative least squares, use `IndNonnegative()` or `NormL1Nonneg(0)`.
For nonnegative lasso, use unweighted `NormL1Nonneg(lambda)` with a positive level.
Both require a nonnegative starting vector. Infeasible starts are refused before writes, and the proximal
step preserves feasibility. The level must be finite,
nonnegative and representable in the working type. Weighted `NormL1Nonneg` is
unsupported, including an all-ones weight vector. PGD and `CDSolver` (least squares,
a feasible dense `Vector`) accept the unweighted form. See [the input contract](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-07).

A stopping proposal from the iterate, objective or gradient test must pass the
applicable stationarity check. `NormL1`, `ElasticNet`, `NormL2`, `GroupNormL2`,
`NormL1Nonneg`, and `IndNonnegative()` have KKT checks; the nonnegative case uses the constrained
scores at positive and zero coefficients specified by
[STOP-16](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-stopping/#STOP-16).
Use `IndBox` or `IndBallLinf` for box constraints and `IndBallL2` for a
four-coefficient Euclidean ball with a same-type radius. These indicators
require a feasible start and use the generic proximal-gradient check, as does
`NormLinf`. The ℓ1 ball `IndBallL1(r)`, with a radius of the data's type, is
supported for dense `Vector{Float32}` or `Vector{Float64}` least squares on a
numerical route: an accepted iterate can lie outside the ball when its computed
widened ℓ1 norm passes a computed cap decision (not an exact bound on the
violation), and `converged` reports a passing check at the returned point, which
does not certify exact membership; see
[IN-12](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-12). Assess fits with an
independent diagnostic, particularly for Float32 or ill-conditioned designs.
An error in an iteration restores the last accepted coefficients and
is rethrown.

- [Iteration sequence, cache and tracing](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-iteration/#PGD-01).
- [Backtracking and numerical range limits](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/line-search/#LS-01).
- [Stopping criteria and result interpretation](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-stopping/#STOP-01).
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
mutable struct ProximalGradientDescentState{T, X<:VecOrMat{T}, G<:VecOrMat{T}, M, Z, C}
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
    λmax::T         # ‖∇f(0)‖ for the stationarity check: the ∞-norm for NormL1 (logistic loss, matrix response),
                    # NormL1Nonneg and NormLinf, the largest group 2-norm for GroupNormL2, the 2-norm for NormL2
                    # (_scale_norm); -1 until it is computed. The coordinatewise check (scales below) does not
                    # compute it, so it stays -1 in those solves.
    backtrack_simple::Bool  # line search uses function values, not gradients
    backtrack_steps::Int
    f_calls::Int
    grad_calls::Int
    prox_calls::Int
    model::M
    z_x::Z            # A x
    dz::Z             # F' at A x; buffer of the product A d of a checked rejection and, for a logistic loss, of ½ - y (_zero_gradient!)
    verifications::Int  # rejections checked by the computed curvature (one product A d each)
    # true when the last rejection of the current iteration's line search replaced its estimate L̂
    # by the finite computed curvature c of the rejected step (the retry's L is then
    # min(Lexact, max(c, L/β)) for the rejected trial's L, which need not equal c); set by
    # backtrack!, cleared at the start of update_state!
    verified_rejection::Bool
    # the column data of the coordinatewise check (_CoordinateScales, STOP-21) for least squares with NormL1 or
    # ElasticNet on a Vector{Float32} or Vector{Float64}, filled at the first check; nothing for the other problems
    scales::C
end


function initial_state(
          method::ProximalGradientDescent,
          options,
          f,
          g,
          x0::VecOrMat{T}) where T

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
                         false,
                         _coordinate_scales(model, g, x0)
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

    LineSearches.search!(state, method.ls, f, g)
    state
end


LineSearches.value_and_gradient_at_x!(state::ProximalGradientDescentState, f) =
  _value_and_gradient!(state.grad_f_x, state.x, f, state.z_x, state.dz)

# The computed curvature c = m α ‖fl(X d̂)‖²/‖d̂‖² of the rejected step d̂ = state.delta_x, from
# the product X d̂ formed in dz (scratch: _value_and_gradient! writes it before any
# read), with m = 1 in function-value mode and m = 2 in gradient mode. Returns (accepted, c):
# accepted is the comparison of the curvature value with L (in Float64 for Float32 data), and c,
# of type T, is the estimate that the caller uses after a rejection. When the squared norm of
# the step x - x' overflowed in the element type of x with finite entries and f(x) is finite,
# backtrack! has scaled state.delta_x by a power of two s, so d̂ is that scaled step and its
# largest entry is in [1, 4).
function LineSearches.check_rejection!(state::ProximalGradientDescentState, gradient_mode::Bool)
    mul!(state.dz, state.model.X, state.delta_x)
    state.verifications += 1
    _step_curvature(state, gradient_mode ? 2 : 1)
end

# Float64 data: both sums of squares in Float64. Overflow or underflow of either sum can make c
# nonfinite (Inf or NaN; the caller then keeps TFOCS's estimate) or spuriously zero (a finite
# numerator over an overflowed denominator, or an underflowed numerator; the trial is then
# accepted). For a scaled step d̂ (see check_rejection!), ‖d̂‖² is at least 1 and at most about 16n,
# so the denominator neither overflows nor underflows, while ‖fl(X d̂)‖² can still overflow or
# underflow. For an unscaled step, the denominator can overflow when an entry of x - x' is not
# finite, and in a narrow band around the overflow threshold, where norm(x - x')² can be finite
# and the sum of squares not.
function _step_curvature(state::ProximalGradientDescentState{T}, m) where T
    c = m * (T(state.model.α) * (sum(abs2, state.dz) / sum(abs2, state.delta_x)))
    c <= state.L, c
end

# Float32 data. The computed curvature is not used, and the result is (false, Inf32) so that the
# caller keeps TFOCS's estimate, when the calling thread flushes subnormals to zero
# (get_zero_subnormals(), one read of the floating-point control register) or when d̂ has a
# subnormal entry, which a flushing thread could drop from the product. For a scaled step d̂
# (see check_rejection!), that is a nonzero entry d̂ᵢ with |d̂ᵢ| < floatmin(Float32); an entry of
# x - x' with |s (xᵢ - x'ᵢ)| ≤ 2^-150 (half the least positive number) rounds to zero in d̂, is not
# detected, and drops out of both sums of squares and of the product. Otherwise the sums of
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
    # Each product entry has p terms. Combine the absolute errors over nK entries,
    # and sum the errors from subnormal design entries over the coefficient columns.
    rout = state.dz isa Vector ? rn : sqrt(Float64(length(state.dz)))
    w = sqrt(_sumsq64(state.dz)) + 2 * rout * p * fm + rn * fm * l1
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
    solve!(x, f, g, ProximalGradientDescent(), options=ProximalOptions(); feasibility=nothing)
    solve!(x, f, g, AccProxGradDescent(), options=ProximalOptions(); feasibility=nothing)
    solve!(x::BlockIterate, f, g::GroupNormL2, CDSolver())

Minimize a supported penalized regression objective, overwriting `x`, and return
a result whose `minimizer` is that coefficient storage. Use matching
Float32/Float64 data and coefficients. CD additionally accepts sparse/group
iterate storage and row-group matrix-response problems. PGD and APG accept
entrywise matrix-response lasso with unweighted `NormL1` under
[IN-10](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-10). Choose a method and penalty from the
[support matrix](https://mlakolar.github.io/ProximalSolvers.jl/dev/support/).

```julia
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
beta = zeros(2)
result = solve!(beta, (1/3)*LeastSquaresLoss(y, X), NormL1(0.1),
                CDSolver(order=:cyclic, momentum=false))
saved_beta = copy(result.minimizer)
```

The meaning of `converged` depends on the method and loss; see
[result semantics](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/results-failures/#RES-01).

# Extended help

`LeastSquaresLoss` is half the sum of squared residuals. Multiply by `1/n` for
the conventional normalized lasso. One supported positive scalar loss wrapper
is accepted. Penalty levels and weights must meet the relevant input rules.
A zero weight removes the weighted term for its coefficient or group.
For `ElasticNet`, the ridge term still applies to every coefficient.

Do not modify data during a solve, or alias `x` with the data, penalty weights
or other disallowed mutable storage. Results share `x`; copying the result
object alone does not preserve earlier coefficients.

An exception escaping a CD solve leaves the caller's original coefficients
unchanged; a completed finite run, including a pass-limit outcome, commits its final point.
PGD/APG iteration errors restore the last accepted point and rethrow. Internal
counters have no transaction guarantee. A borrowed CD RNG may have advanced
when a numerical failure occurs during a pass. After a successful sparse/group
solve, reacquire active-coordinate/value views because its active storage can
change.

Ridge via uncentered `SqrNormL2(lambda)` is supported with least squares and CD
on a dense vector or one-dimensional `SparseIterate`. Its penalty is
`(lambda/2) * sum(abs2, x)`; `lambda` must be finite, nonnegative and representable
in the coefficient type. Centered penalties, including an all-zero center, and
this penalty with PGD, APG, block/matrix coefficients or square-root loss are refused.
See [supported inputs](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-01).

Group CD requires a `BlockIterate` with the penalty's ordered groups; group
PGD/APG require a same-type `GroupNormL2{T}` and dense coefficients. PGD and APG
accept `NormL2(lambda)` for least squares with a dense coefficient vector.
Square-root lasso is available only with CD, an unscaled loss and an unweighted
positive L1 level; its successful stopping flag requires a certificate.

PGD and APG accept `IndBallL1(r)` on dense `Vector{Float32}` or `Vector{Float64}` least squares
with a same-type dense design, response and radius ([IN-12](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-12)).
A non-`nothing` `feasibility = NumericalFeasibility(...)` overrides the route's tolerances. With
any other penalty, PGD and APG treat `feasibility = nothing` as omitted and refuse a non-`nothing`
value; graphical-lasso PGD and the other solvers refuse the keyword in any form.
On the route, `converged` means the full check passed at the returned point, and `minimum` is the
monitored numerical objective, the cached loss, which can be finite where ProximalBase's strict
indicator is `Inf`; neither certifies exact membership of the returned point.

Use `IndNonnegative()` or `NormL1Nonneg(0)` for nonnegative least squares and
unweighted `NormL1Nonneg(lambda)` for nonnegative lasso. These penalties are accepted
by PGD and by `CDSolver` on a dense `Vector`, with dense same-type least-squares data
and a nonnegative starting vector; APG, and CD on a `SparseIterate`, refuse them. An
infeasible start is refused before writes. PGD's stopping check uses the
constrained KKT residual and the lasso's symmetric gradient scale. `CDSolver` reports
convergence on its change test, so its `converged` flag is not a KKT check; assess its point with an
independent constrained KKT score.
See [inputs](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-07),
[PGD's stopping check](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-stopping/#STOP-16)
and [CD's change test](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/cd-scalar/#CD-03).

- [Supported inputs, dimensions and scalar parameters](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-01).
- [Aliasing and borrowed input requirements](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-05).
- [Results, mutations and numerical failures](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/results-failures/#RES-01).
- [Sparse iterate storage and commitment](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/cd-sparse-iterate/#CDS-01).
- [Group steps and private storage](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/cd-group/#CDG-01).
"""
function solve!(x, f, g, method::ProximalGradientDescent,
                options::ProximalOptions = ProximalOptions(); feasibility = nothing, kwargs...)
  _check_keywords(kwargs)
  _numerical_route(g, feasibility) && return _solve_numerical_l1!(x, f, g, feasibility, method, options, :pgd)
  _check_gradient_problem(x, f, g, :pgd)
  t0 = time()
  g_work = _working_gradient_penalty(g, eltype(x))
  state = initial_state(method, options, f, g_work, x)
  _solve_gradient!(state, f, g_work, method, options, t0)
end

# Numerical stagnation, after an iteration of _solve_gradient!: true for Float32 PGD with ftol = 0
# when the accepted iterate equals the previous one elementwise and the last rejection of the
# iteration's line search replaced its estimate L̂ by a finite computed curvature
# (verified_rejection). It is false for AccProxGradDescent, for Float64 PGD and when ftol > 0.
# The stop it causes is not a convergence or accuracy test.
_stagnated(state, options) = false
_stagnated(state::ProximalGradientDescentState{Float32}, options) =
  iszero(options.ftol) && state.verified_rejection && _unchanged(state.x, state.x_previous)
