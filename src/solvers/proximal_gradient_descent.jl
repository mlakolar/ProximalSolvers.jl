"""
    ProximalGradientDescent(; ls=LineSearches.BackTracking(), normalized=false,
                             debias=0, preconditioner=:none)

Proximal gradient descent (PGD) for least-squares lasso with a dense
`Vector{Float32}` or `Vector{Float64}` coefficient iterate. Each iteration
takes a gradient step for the smooth least-squares loss and applies the
`NormL1` proximal operator (soft thresholding); backtracking adjusts
the step size.

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
configure stopping tolerances and iteration limits. **The defaults may
stop after only 3–4 correct digits on the small tutorial examples.**
`converged=true` means a stopping rule was satisfied, not that the
result is an accurate minimizer. Tighten tolerances and check KKT conditions
independently before reporting numerical results.
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
    backtrack_simple::Bool  # line search uses function values, not gradients
    backtrack_steps::Int
    f_calls::Int
    grad_calls::Int
    prox_calls::Int
    model::M
    z_x::Z            # A x
    dz::Z             # F' at A x; buffer of the product A d of a checked rejection
    verifications::Int  # rejections checked by the computed curvature (one product A d each)
    # true when the last rejection of the current iteration's line search replaced L by the finite
    # computed curvature of a rejected step; set by backtrack!, cleared at the start of update_state!
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
    f_x = _value_and_gradient!(grad_f_x, x0, model, z_x, dz)
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
                         one(T),      # L
                         T(-Inf),     # max_residual
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
      state.f_x = _value!(state.x, state.model, state.z_x)
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
  _value_and_gradient!(state.grad_f_x, state.x, state.model, state.z_x, state.dz)

# The computed curvature c = m α ‖fl(X d̂)‖²/‖d̂‖² of the rejected step d̂ = state.delta_x, from
# the product X d̂ formed in dz (scratch: _image_value_and_gradient! overwrites it before any
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

# Σ vᵢ² of a Float32 vector, accumulated in Float64
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

Minimize a least-squares lasso, overwriting `x`. `x` is a dense `Vector{T}`,
T=Float32 or Float64; `CDSolver` also accepts a one-dimensional `SparseIterate{T}`
(see below), while `ProximalGradientDescent` refuses it. The loss uses same-type
`Matrix` X and `Vector` y, and the penalty is an unweighted finite nonnegative
`NormL1`. Use `(one(T)/T(n))*LeastSquaresLoss` for normalized lasso; raw LS keeps
its unnormalized meaning. One positive finite scalar LS wrapper is supported.
Borrowed X/y must not alias mutable `x` or change during a solve. Results share
`x`; copy it to retain earlier coefficients. Unsupported inputs/options fail
before mutation. Convergence uses historical stopping tests, not a KKT
certificate. Finite intermediate arithmetic is required. PGD step errors restore
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
# iteration's line search replaced L by a finite computed curvature (verified_rejection). It is
# false for every other method, element type and ftol > 0. The stop it causes is not a
# convergence or accuracy test.
_stagnated(state, options) = false
_stagnated(state::ProximalGradientDescentState{Float32}, options) =
  iszero(options.ftol) && state.verified_rejection && _unchanged(state.x, state.x_previous)
