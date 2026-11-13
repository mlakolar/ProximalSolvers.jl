"""
    ProximalGradientDescent(; ls=LineSearches.BackTracking(), normalized=false,
                             debias=0, preconditioner=:none)

Proximal gradient descent (PGD) for least-squares lasso with a dense
`Vector{Float32}` or `Vector{Float64}` coefficient iterate. Each iteration
takes a gradient step for the smooth least-squares loss and applies the
`NormL1` proximal operator (soft thresholding); backtracking adjusts
the step size.

`ProximalGradientDescent()` uses the supported
`LineSearches.BackTracking()` line search. A trial that it rejects is checked
with the certified least-squares bound of [`AccProxGradDescent`](@ref), except
in the cases that the `LineSearches.BackTracking` docstring lists: a
rejection that the bound refutes is accepted, and otherwise the retry replaces
the estimate `L̂` by `min(L̂, U)`, where `U` is a certified upper bound on the `L`
that the bound needs (see `LineSearches.BackTracking` and
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
    dz::Z             # F' at A x; buffer of the fresh A d of a checked rejection
    z_previous::Z     # A x_previous, once an iteration has started
    bound::Union{Nothing, _BoundConstants{T}}  # constants of the bound test, built at the first checked rejection
    rootα::Union{Nothing, _SE{T}}   # √α (see _root_scale), built when function-value mode first needs it
    root2α::Union{Nothing, _SE{T}}  # √(2α), built when gradient mode first needs it
    certify::Bool     # the dimensions satisfy the bound's size condition (_bound_size_ok)
    verifications::Int  # rejections checked by the certified bound
    fallbacks::Int    # fresh products A d formed for those checks
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
                         similar(z_x), # A x_previous
                         nothing,
                         nothing,
                         nothing,
                         _bound_size_ok(T, size(model.X)...),
                         0,
                         0
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
    # A x_previous = A x; the old buffer of A x_previous receives the trial images
    state.z_previous, state.z_x = state.z_x, state.z_previous
    state.L *= method.ls.α

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

# The check of a backtracking rejection of the trial state.x from state.x_previous, d ≠ 0,
# with the certified least-squares bound of _bound_certified!: of α‖X d‖² ≤ L‖d‖² when
# gradient_mode is false (function-value mode) and of 2α‖X d‖² ≤ L‖d‖² when it is true, each
# with the slack (1 + 4eps) on √L. Returns (true, Inf) when the bound is certified, and
# otherwise (false, U), U an upper bound on the L that the bound needs for this d (see
# _curvature_cap). U is Inf when the dimensions fail the size condition, when a norm or
# fl(X d̂) is not finite, and when the bound exceeds floatmax(T). z_previous is the fresh
# product of x_previous (update_state! swaps it in), so its error bound is that of one product.
function LineSearches.verify_rejection!(state::ProximalGradientDescentState{T}, gradient_mode::Bool) where T
    state.certify || return false, T(Inf)
    sd, sx = _sumsq2(state.delta_x, state.x)
    normx = _se_norm_onepass(T, sx, state.x)
    D = _se_norm_onepass(T, sd, state.delta_x)
    xp = state.x_previous
    normxp = _se_norm_onepass(T, sum(abs2, xp), xp)
    (normx === nothing || D === nothing || normxp === nothing) && return false, T(Inf)
    c = _pgd_bound!(state)
    rootscale = gradient_mode ? _pgd_root2α!(state) : _pgd_rootα!(state)
    Ey = _image_error_bound(c, normxp, normxp, false)
    state.verifications += 1
    ok, fresh = _bound_certified!(state.dz, state.model, state.z_previous, state.z_x, state.delta_x,
                                  D, state.L, Ey, normx, rootscale, c, false)
    state.fallbacks += fresh
    ok && return true, T(Inf)
    U, loose = _curvature_upper(state.dz, state.z_previous, state.z_x, D, Ey, normx, rootscale, c, fresh)
    if loose && !fresh
        mul!(state.dz, state.model.X, state.delta_x)
        state.fallbacks += 1
        U, _ = _curvature_upper(state.dz, state.z_previous, state.z_x, D, Ey, normx, rootscale, c, true)
    end
    false, U
end

function _pgd_bound!(state::ProximalGradientDescentState{T}) where T
    b = state.bound
    b === nothing || return b
    b = _bound_constants(T, state.model.X)
    state.bound = b
    b
end

function _pgd_rootα!(state::ProximalGradientDescentState{T}) where T
    r = state.rootα
    r === nothing || return r
    r = _root_scale(T, state.model.α)
    state.rootα = r
    r
end

function _pgd_root2α!(state::ProximalGradientDescentState{T}) where T
    r = state.root2α
    r === nothing || return r
    r = _root_scale(T, state.model.α, 1)
    state.root2α = r
    r
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
