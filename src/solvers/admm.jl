"""
    ADMMSolver(; ρ=1.0, α=1.0, abstol=1e-6, reltol=1e-4, abstol_dual=abstol, adaptive=false)

Solve `SqrNormL2(λ, c) + NormL1(τ)` by scaled consensus ADMM on a dense
`Vector{Float32}` or `Vector{Float64}` with a same-type center `c`.
`ρ` is the positive penalty and `α ∈ (0, 2)` controls relaxation. The absolute
and relative tolerances control the primal and dual residual tests. Set
`adaptive=true` to rebalance the penalty between iterations.

See [the ADMM contract](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/admm/#ADM-01)
for the supported inputs and iteration rules.
"""
struct ADMMSolver{T<:AbstractFloat} <: ProximalSolver
  ρ::T
  α::T
  abstol::T
  reltol::T
  abstol_dual::T
  adaptive::Bool

  function ADMMSolver(; ρ::Real = 1.0, α::Real = 1.0, abstol::Real = 1e-6,
                      reltol::Real = 1e-4, abstol_dual::Real = abstol, adaptive::Bool = false)
    T = float(promote_type(typeof(ρ), typeof(α), typeof(abstol), typeof(reltol), typeof(abstol_dual)))
    settings = _admm_settings(T, ρ, α, abstol, reltol, abstol_dual)
    new{T}(settings..., adaptive)
  end
end

Base.summary(::ADMMSolver) = "ADMM"

function _admm_settings(::Type{T}, ρ, α, abstol, reltol, abstol_dual) where T
  _scalar_parameter(ρ, T, "ρ"; positive=true)
  _scalar_parameter(α, T, "α"; positive=true)
  α < 2 && T(α) < T(2) || throw(ArgumentError("α must be in (0, 2) before and after conversion"))
  _scalar_parameter(abstol, T, "abstol")
  _scalar_parameter(reltol, T, "reltol")
  _scalar_parameter(abstol_dual, T, "abstol_dual")
  T(ρ), T(α), T(abstol), T(reltol), T(abstol_dual)
end

"""
    ADMMResults

The result of [`solve!`](@ref) with an [`ADMMSolver`](@ref). `minimizer` aliases
the caller's vector and `minimum` is the objective there. `iterations` counts
completed iterations, with two proximal calls each in `prox_calls`.

`r_norm`, `s_norm`, `eps_pri` and `eps_dual` describe the final residual tests.
They are `NaN` if no iteration ran. `u` is the final scaled dual variable and
`ρ` is the penalty used for the final tests, or the starting penalty if no
iteration ran. An explicit dual buffer passed to `solve!` also aliases the
result. `status` records the exit and `converged` is true for
`:converged`. See the [ADMM contract](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/admm/#ADM-01).
"""
struct ADMMResults{T}
  minimizer::Vector{T}
  minimum::T
  iterations::Int
  converged::Bool
  r_norm::T
  s_norm::T
  eps_pri::T
  eps_dual::T
  u::Vector{T}
  ρ::T
  prox_calls::Int
  status::Symbol
end

Base.summary(::ADMMResults) = "ADMM"
minimizer(r::ADMMResults) = r.minimizer
minimum(r::ADMMResults) = r.minimum
iterations(r::ADMMResults) = r.iterations
converged(r::ADMMResults) = r.converged
f_calls(::ADMMResults) = 1
grad_calls(::ADMMResults) = 0
prox_calls(r::ADMMResults) = r.prox_calls
call_limit_reached(r::ADMMResults) = r.status === :prox_calls_limit
iteration_limit_reached(r::ADMMResults) = r.status === :iteration_limit
stagnated(r::ADMMResults) = r.status === :stagnated

function Base.show(io::IO, r::ADMMResults)
  println(io, "ADMM results (", r.status, ")")
  @printf io " * Minimum: %e\n" r.minimum
  @printf io " * Iterations: %d (%d proximal calls)\n" r.iterations r.prox_calls
  @printf io " * Primal residual: %.2e (tolerance %.2e)\n" r.r_norm r.eps_pri
  @printf io " * Dual residual: %.2e (tolerance %.2e)\n" r.s_norm r.eps_dual
  @printf io " * Penalty: %e\n" r.ρ
  return nothing
end

function _check_admm_options(options)
  defaults = ProximalOptions()
  (options.ftol == defaults.ftol && options.xtol == defaults.xtol && options.gradtol == defaults.gradtol &&
   options.f_calls_limit == 0 && options.grad_calls_limit == 0 && !options.allow_f_increases &&
   !options.store_trace && !options.show_trace && !options.extended_trace &&
   options.print_every == defaults.print_every && options.callback === nothing) ||
    throw(ArgumentError("ADMM supports only maxiter, time_limit and prox_calls_limit from ProximalOptions"))
  nothing
end

function _admm_level(level, ::Type{T}, name; positive=false) where T
  _scalar_parameter(level, T, name; positive)
  native = T(level)
  native == level || throw(ArgumentError("$name must be exactly representable in $T"))
  native
end

"""
    solve!(z, f, g, method::ADMMSolver, options=ProximalOptions(); u=nothing)

Minimize `f(z) + g(z)` and store the returned consensus iterate in `z`.
Use `f = SqrNormL2(λ, c)` with a finite positive level and an unweighted
`g = NormL1(τ)` with a finite nonnegative level. The levels must be exactly
representable in the common Float32 or Float64 element type of `z` and `c`.
The initial scaled dual is zero by default. Pass an independent, same-type
buffer as `u` to start from its entries. Caller buffers are committed on
normal return. Pass the returned iterate, scaled dual and penalty together to
restart a solve. See [`ADMMResults`](@ref) and the
[ADMM input and result contract](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/admm/#ADM-01).
"""
function solve!(z, f, g, method::ADMMSolver, options::ProximalOptions = ProximalOptions(); u=nothing, kwargs...)
  _check_keywords(kwargs)
  _check_admm_options(options)
  z isa Union{Vector{Float32}, Vector{Float64}} || throw(ArgumentError("z must be a dense Float32 or Float64 vector"))
  _solve_admm!(z, f, g, method, options, u)
end

function _solve_admm!(initial_z::Vector{T}, f, g, method, options, initial_u) where T
  f isa SqrNormL2{<:Real, Vector{T}} || throw(ArgumentError("ADMM requires SqrNormL2 with a same-type dense vector center"))
  g isa NormL1{<:Real, Nothing} || throw(ArgumentError("ADMM requires an unweighted NormL1 penalty"))
  c = f.y
  !isempty(initial_z) && length(initial_z) == length(c) ||
    throw(DimensionMismatch("z and the center must have the same positive length"))
  _admm_mightalias(initial_z, c) && throw(ArgumentError("z must not alias the center"))
  _allfinite(initial_z) && _allfinite(c) || throw(ArgumentError("z and the center must contain only finite values"))
  if initial_u !== nothing
    initial_u isa Vector{T} || throw(ArgumentError("u must be a dense $T vector like z"))
    length(initial_u) == length(initial_z) || throw(DimensionMismatch("u and z must have the same length"))
    (_admm_mightalias(initial_u, initial_z) || _admm_mightalias(initial_u, c)) &&
      throw(ArgumentError("u must not alias z or the center"))
    _allfinite(initial_u) || throw(ArgumentError("u must contain only finite values"))
  end

  λ = _admm_level(f.λ, T, "λ"; positive=true)
  τ = _admm_level(g.λ0, T, "τ")
  ρ, α, abstol, reltol, abstol_dual = _admm_settings(T, method.ρ, method.α, method.abstol, method.reltol, method.abstol_dual)
  γ = inv(ρ)
  isfinite(γ) && γ > zero(T) || throw(ArgumentError("1/ρ must be finite and positive in $T"))

  # Use native levels for the two oracles and the fixed-point check.
  f = SqrNormL2(λ, c)
  g = NormL1(τ)
  t0 = time_ns()
  z = copy(initial_z)
  next_z = similar(z)
  x = similar(z)
  u = initial_u === nothing ? zeros(T, length(z)) : copy(initial_u)
  tmp = similar(z)
  sqrt_n = sqrt(T(length(z)))
  abs_pri, abs_dual = sqrt_n * abstol, sqrt_n * abstol_dual
  max_prox_pairs = options.prox_calls_limit == 0 ? typemax(Int) : options.prox_calls_limit ÷ 2

  iterations = penalty_changes = 0
  r_norm = s_norm = eps_pri = eps_dual = T(NaN)
  status = :iteration_limit
  while iterations < options.maxiter
    if iterations == max_prox_pairs
      status = :prox_calls_limit
      break
    elseif options.time_limit < Inf && (time_ns() - t0) * 1e-9 >= options.time_limit
      status = :time_limit
      break
    end

    # Apply a change only when an iteration can use it. On exit ρ, u and
    # the residual diagnostics correspond to the same completed iteration.
    if method.adaptive && iterations > 0 && penalty_changes < 50
      balance = _admm_balance(r_norm, eps_pri, s_norm, eps_dual)
      candidate_ρ, candidate_γ = _admm_adjust_penalty!(tmp, u, ρ, γ, balance)
      if candidate_ρ != ρ
        ρ, γ = candidate_ρ, candidate_γ
        u, tmp = tmp, u
        penalty_changes += 1
      end
    end

    _admm_subtract!(tmp, z, u) || error("ADMM formed a nonfinite x-prox argument")
    prox!(x, f, tmp, γ)
    # A nonfinite x-prox output also makes its relaxed argument nonfinite.
    _admm_relaxed_argument!(tmp, x, z, u, α) ||
      error("ADMM produced a nonfinite x-prox output or z-prox argument")
    prox!(next_z, g, tmp, γ)
    # The argument was finite, so this check also rejects a nonfinite z-prox output.
    _admm_subtract!(u, tmp, next_z) ||
      error("ADMM produced a nonfinite z-prox output or scaled dual variable")

    r_norm = _norm_diff(x, next_z)
    s_norm = ρ * _norm_diff(next_z, z)
    eps_pri, eps_dual = abs_pri, abs_dual
    if !iszero(reltol)
      eps_pri += reltol * max(_norm(x), _norm(next_z))
      eps_dual += reltol * (ρ * _norm(u))
    end
    all(isfinite, (r_norm, s_norm, eps_pri, eps_dual)) || error("ADMM produced nonfinite residual diagnostics")
    iterations += 1
    z, next_z = next_z, z

    if r_norm <= eps_pri && s_norm <= eps_dual
      status = if iszero(r_norm) && iszero(s_norm) && !_admm_stationary(z, c, λ, τ, eps_dual)
        :stagnated
      else
        :converged
      end
      break
    end
  end

  objective = f(z) + g(z)
  isfinite(objective) || error("ADMM produced a nonfinite objective at the return point")
  calls = Base.checked_mul(2, iterations)
  copyto!(initial_z, z)
  if initial_u !== nothing
    copyto!(initial_u, u)
    u = initial_u
  end
  ADMMResults(initial_z, objective, iterations, status === :converged,
              r_norm, s_norm, eps_pri, eps_dual, u, ρ, calls, status)
end

function _admm_mightalias(a::Vector, b::Vector)
  Base.mightalias(a, b) && return true
  # Separately wrapped dense vectors can overlap despite distinct storage identities.
  GC.@preserve a b begin
    a_start = UInt(pointer(a))
    b_start = UInt(pointer(b))
    a_start <= b_start ? b_start - a_start < UInt(sizeof(a)) : a_start - b_start < UInt(sizeof(b))
  end
end

function _admm_subtract!(out, a, b)
  finite = true
  @inbounds @simd for i in eachindex(out, a, b)
    value = a[i] - b[i]
    out[i] = value
    finite &= isfinite(value)
  end
  finite
end

function _admm_relaxed_argument!(out, x, z, u, α)
  finite = true
  if isone(α)
    @inbounds @simd for i in eachindex(out, x, u)
      value = x[i] + u[i]
      out[i] = value
      finite &= isfinite(value)
    end
  else
    # Anchor at z below one to retain α when subtracting one would round it away.
    anchor, weight = α < one(α) ? (z, α) : (x, α - one(α))
    @inbounds @simd for i in eachindex(out, x, z, u)
      value = (anchor[i] + weight * (x[i] - z[i])) + u[i]
      out[i] = value
      finite &= isfinite(value)
    end
  end
  finite
end

# Compare r / ep and s / ed without dividing by zero or forming unbounded ratios.
function _admm_balance(r, ep, s, ed)
  iszero(r) && return iszero(s) ? 0 : -1
  iszero(s) && return 1
  iszero(ep) && return iszero(ed) ? 0 : 1
  iszero(ed) && return -1

  r_mantissa, r_exponent = frexp(r)
  s_mantissa, s_exponent = frexp(s)
  ep_mantissa, ep_exponent = frexp(ep)
  ed_mantissa, ed_exponent = frexp(ed)
  exponent = r_exponent + ed_exponent - s_exponent - ep_exponent
  # The ratio of the two mantissa products is between 1/4 and 4.
  exponent >= 6 && return 1
  exponent <= -6 && return -1
  primal = ldexp(r_mantissa * ed_mantissa, exponent)
  dual = s_mantissa * ep_mantissa
  primal > 10 * dual ? 1 : dual > 10 * primal ? -1 : 0
end

function _admm_adjust_penalty!(trial, u, ρ::T, γ, balance) where T
  iszero(balance) && return ρ, γ
  multiplier = balance > 0 ? T(2) : T(0.5)
  candidate_ρ = ρ * multiplier
  # Reversibility also rejects a rounded halving in the subnormal range.
  (isfinite(candidate_ρ) && candidate_ρ > zero(T) && candidate_ρ / multiplier == ρ) || return ρ, γ
  candidate_γ = inv(candidate_ρ)
  (isfinite(candidate_γ) && candidate_γ > zero(T)) || return ρ, γ
  valid = true
  @inbounds @simd for i in eachindex(trial, u)
    value = u[i] / multiplier
    trial[i] = value
    valid &= isfinite(value) & (!iszero(value) | iszero(u[i]))
  end
  valid ? (candidate_ρ, candidate_γ) : (ρ, γ)
end

# Rounded proximal updates can yield two zero residuals away from a stationary
# point. Check the centered quadratic/L1 stationarity violation on that exit.
function _admm_stationary(z, c, λ, τ, tolerance)
  stationary = true
  @inbounds for i in eachindex(z, c)
    grad = λ * (z[i] - c[i])
    violation = iszero(z[i]) ? max(abs(grad) - τ, zero(τ)) : abs(grad + copysign(τ, z[i]))
    isfinite(violation) || error("ADMM produced a nonfinite stationarity diagnostic")
    stationary &= violation <= tolerance
  end
  stationary
end
