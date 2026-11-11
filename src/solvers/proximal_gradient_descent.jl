"""
    ProximalGradientDescent(; ls=LineSearches.BackTracking(), normalized=false,
                             debias=0, preconditioner=:none)

Historical scalar-step dense LS lasso PGD, retaining its LS image cache, fused
PB proximal call, TFOCS backtracking and FASTA/x/objective OR stopping.
Normalized IHT, debiasing, preconditioning and custom searches are deferred.
"""
struct ProximalGradientDescent{L, P} <: ProximalSolver
  ls::L
  normalized::Bool
  debias::Int
  preconditioner::P
end

Base.summary(::ProximalGradientDescent) = "Proximal Gradient Descent"

ProximalGradientDescent(ls) = ProximalGradientDescent(; ls)
ProximalGradientDescent(ls, normalized::Bool, debias::Int) = ProximalGradientDescent(; ls, normalized, debias)

function ProximalGradientDescent(; ls = LineSearches.BackTracking(), normalized::Bool = false, debias::Integer = 0, preconditioner::Symbol = :none)
  debias >= 0 || throw(ArgumentError("debias must be nonnegative, but it is $debias."))
  !normalized || throw(ArgumentError("normalized IHT is deferred"))
  iszero(debias) || throw(ArgumentError("debiasing is deferred"))
  preconditioner === :none || throw(ArgumentError("preconditioning is deferred"))
  ls isa LineSearches.BackTracking || throw(ArgumentError("only BackTracking is supported"))
  p = nothing
  ProximalGradientDescent(ls, normalized, Int(debias), p)
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
    dz::Z             # F' at A x
end


function initial_state(
          method::ProximalGradientDescent,
          options,
          f,
          g,
          x0::Vector{T}) where T

    grad_f_x = _dense_similar(x0)
    model = _image_model(f)
    z_x = model === nothing ? nothing : _image_buffer(model)
    dz = model === nothing ? nothing : similar(z_x)
    model === nothing || _image!(z_x, model, x0)
    f_x = _value_and_gradient!(grad_f_x, f, x0, model, z_x, dz)
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
                         dz
                         )
end

function update_state!(
    f, g,
    state::ProximalGradientDescentState{T},
    method::ProximalGradientDescent
    ) where T

    # copy x --> x_previous
    _copy!(state.x_previous, state.x)
    state.f_x_previous = state.f_x
    state.g_x_previous = state.g_x
    _copy!(state.grad_f_x_previous, state.grad_f_x)
    state.L *= method.ls.α

    # backtracking loop
    while true
      # find next point
      _step!(state.xhat, state.x_previous, state.grad_f_x_previous, state.L)
      state.g_x = convert(_eltype(state.x), value_and_prox!(state.x, g, state.xhat, one(state.L) / state.L))
      _drop!(state.x)
      state.f_x = _value!(f, state.x, state.model, state.z_x)
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


LineSearches.value_and_gradient_at_x!(state::ProximalGradientDescentState,f) =
  _value_and_gradient!(state.grad_f_x,f,state.x,state.model,state.z_x,state.dz)

function _check_method(m::ProximalGradientDescent)
  !m.normalized && iszero(m.debias) && m.preconditioner === nothing ||
    throw(ArgumentError("normalized IHT, debiasing and preconditioning are deferred"))
  m.ls isa LineSearches.BackTracking || throw(ArgumentError("only BackTracking is supported"))
  0 < m.ls.α <= 1 && 0 < m.ls.β < 1 && m.ls.Lexact > 0 ||
    throw(ArgumentError("invalid BackTracking settings"))
  nothing
end

"""
    solve!(x, f, g, CDSolver())
    solve!(x, f, g, ProximalGradientDescent(), options=ProximalOptions())

Overwrite dense Vector{T} x, T=Float32 or Float64, for same-type Matrix X/Vector
y and unweighted finite nonnegative NormL1. Use `(one(T)/T(n))*LeastSquaresLoss`
for normalized lasso; raw LS keeps its unnormalized meaning. One positive finite
scalar LS wrapper is supported. Borrowed X/y must not alias mutable x or change
during a solve. Results share x; copy it to retain earlier coefficients.
Unsupported inputs/options fail before mutation. Convergence uses historical
stopping tests, not a KKT certificate. Finite intermediate arithmetic is required.
CD errors before scatter preserve input x; PGD step errors restore its last
accepted x and rethrow, without a transaction guarantee for internal counters.
"""
function solve!(x, f, g, method::ProximalGradientDescent,
                options::ProximalOptions = ProximalOptions(); kwargs...)
  _check_keywords(kwargs)
  _check_method(method)
  _check_options(options)
  _check_problem(x, f, g)
  t0 = time()
  state = initial_state(method, options, f, g, x)
  _solve_gradient!(state, f, g, method, options, nothing, t0)
end

