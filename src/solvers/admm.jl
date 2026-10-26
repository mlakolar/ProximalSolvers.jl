# minimizes f(x) + g(x), where both f and g are proximable, using the
# over-relaxed scaled ADMM of sections 3.1.1, 3.3 and 3.4.3 of
# Boyd et al. (2011), Distributed Optimization and Statistical Learning
# via the Alternating Direction Method of Multipliers, with the residual
# balancing of section 3.4.1

"""
    ADMMSolver(; ρ = 1.0, α = 1.0, abstol = 1e-6, reltol = 1e-4, adaptive = false,
                 abstol_dual = abstol, norm = nothing)

The alternating direction method of multipliers for `f(x) + g(x)` when both
`f` and `g` have easy proximal operators (Boyd et al., *Distributed
Optimization and Statistical Learning via the Alternating Direction Method of
Multipliers*, 2011). It splits `x = z` and iterates

    x ← prox_{f/ρ}(z - u)
    z ← prox_{g/ρ}(α x + (1 - α) z + u)
    u ← u + α x + (1 - α) z_previous - z

`ρ > 0` is the augmented Lagrangian parameter and `α ∈ (0, 2)` the
over-relaxation (`α = 1` is plain ADMM; 1.5 to 1.8 usually converges faster).
It stops when the primal residual `‖x - z‖` is below `√n abstol + reltol ⋅
max(‖x‖, ‖z‖)` and the dual residual `ρ‖z - z_previous‖` below `√n abstol_dual
+ reltol ⋅ ρ‖u‖` (§3.3 of the paper). With `adaptive`, `ρ` balances the two
residuals (§3.4.1): it doubles when the primal residual, relative to its
tolerance, is more than ten times the dual one, halves in the opposite case,
and stays fixed after 50 changes, which keeps the convergence guarantee of a
fixed `ρ`.

`x` is an `Array`, or a tuple of arrays for a problem over several blocks:
with `f = SeparableSum(f1, …, fK)` the x-update is K independent proximal
steps, and `g` may couple the blocks, as the fused graphical lasso does for a
pair of precision matrices. `n` is the total number of entries, and a tuple of
one array computes exactly what the array does.

`norm` is the norm in which the residuals and `‖x‖`, `‖z‖` and `‖u‖` are
measured, a function of an iterate (an array, or a tuple of arrays); `nothing`
is the Euclidean norm, over all the blocks of a tuple. The K blocks of a stacked
array, for example, can be measured by the sum of the norms of its slices,
`x -> sum(k -> LinearAlgebra.norm(view(x, :, :, k)), axes(x, 3))`, and those
of a tuple by `x -> sum(LinearAlgebra.norm, x)`. If `norm` also has a method
`norm(x, y)` for the norm of `x - y`, the residuals are measured with it,
without forming the differences.

Of the [`ProximalOptions`](@ref), only `maxiter`, `time_limit`,
`prox_calls_limit`, `show_trace`, `print_every`, `gaptol` and `gapevery` are
used. With `gaptol > 0` and functions that have a duality gap (see
[`duality_gap`](@ref); among them the graphical lasso, a `LogDetLoss` with a
`NormL1`), the gap at `z` replaces the residual tests. Use with
[`solve!`](@ref); to warm start from a previous result `res`, pass its scaled
dual variable and final penalty parameter:
`solve!(x, f, g, ADMMSolver(; ρ = res.ρ), options; u = res.u)`.
"""
struct ADMMSolver{T<:AbstractFloat, N} <: ProximalSolver
  ρ::T          # augmented Lagrangian parameter, or its starting value
  α::T          # over-relaxation parameter, α ∈ (0, 2); α = 1 is plain ADMM
  abstol::T
  reltol::T
  adaptive::Bool
  abstol_dual::T
  norm::N       # the norm of the residuals, nothing for the Euclidean norm
end

Base.summary(::ADMMSolver) = "ADMM"

function ADMMSolver(; ρ::Real = 1.0, α::Real = 1.0, abstol::Real = 1e-6, reltol::Real = 1e-4,
                    adaptive::Bool = false, abstol_dual::Real = abstol, norm = nothing)
  isfinite(ρ) && ρ > 0 || error("ρ must be finite and positive.")
  0 < α < 2 || error("α must be in (0, 2).")
  all(t -> isfinite(t) && t >= 0, (abstol, abstol_dual, reltol)) ||
    throw(ArgumentError("ADMM tolerances must be finite and nonnegative."))
  T = float(promote_type(typeof(ρ), typeof(α), typeof(abstol), typeof(reltol), typeof(abstol_dual)))
  ADMMSolver{T, typeof(norm)}(T(ρ), T(α), T(abstol), T(reltol), adaptive, T(abstol_dual), norm)
end

"""
    ADMMResults

Returned by [`solve!`](@ref) with an [`ADMMSolver`](@ref): `minimizer`,
`minimum` (`f + g` at the minimizer), `iterations`, `converged`, the final
primal and dual residuals `r_norm`, `s_norm` with their tolerances `eps_pri`,
`eps_dual`, the scaled dual variable `u` (an array, or a tuple like `x`) and
the final penalty parameter `ρ` (for a warm start), and the number of
evaluations: `f_calls` of the value of
`f` (for the trace and `minimum`), `grad_calls` (always `0`) and `prox_calls`
of the proximal operators of `f` and `g`. `call_limit_reached` is `true` when
the solver stopped at `prox_calls_limit` (see [`ProximalOptions`](@ref)), and
`gap` is the relative duality gap at the minimizer when `gaptol > 0`, `NaN`
otherwise. With a computable gap, `converged` reports whether the final gap
meets `gaptol`, including a final check between scheduled checks after a
limit stops the solve. If the gap cannot be computed, convergence uses the
primal and dual residual tests.
"""
struct ADMMResults{T,X}
    minimizer::X
    minimum::T
    iterations::Int
    converged::Bool
    r_norm::T     # primal residual ‖x - z‖
    s_norm::T     # dual residual ρ‖z - z_previous‖
    eps_pri::T
    eps_dual::T
    u::X          # scaled dual variable
    ρ::T          # final penalty parameter
    f_calls::Int
    grad_calls::Int
    prox_calls::Int
    call_limit_reached::Bool
    gap::Float64
end

Base.summary(::ADMMResults) = "ADMM"
minimizer(r::ADMMResults) = r.minimizer
minimum(r::ADMMResults) = r.minimum
iterations(r::ADMMResults) = r.iterations
converged(r::ADMMResults) = r.converged
f_calls(r::ADMMResults) = r.f_calls
grad_calls(r::ADMMResults) = r.grad_calls
prox_calls(r::ADMMResults) = r.prox_calls
call_limit_reached(r::ADMMResults) = r.call_limit_reached

function Base.show(io::IO, r::ADMMResults)
    @printf io "Results of Optimization Algorithm\n"
    @printf io " * Algorithm: %s\n" summary(r)
    @printf io " * Minimum: %e\n" minimum(r)
    @printf io " * Iterations: %d\n" iterations(r)
    @printf io " * Convergence: %s\n" converged(r)
    @printf io "   * primal residual %.2e (tolerance %.2e)\n" r.r_norm r.eps_pri
    @printf io "   * dual residual   %.2e (tolerance %.2e)\n" r.s_norm r.eps_dual
    isnan(r.gap) || @printf io "   * relative duality gap %.2e\n" r.gap
    @printf io " * Final ρ: %e\n" r.ρ
    @printf io "   * Reached a limit on the number of calls: %s\n" call_limit_reached(r)
    @printf io " * f(x) calls: %d\n" f_calls(r)
    @printf io " * ∇f(x) calls: %d\n" grad_calls(r)
    @printf io " * prox calls: %d\n" prox_calls(r)
    return
end

# ‖x - z‖, ‖z - z_previous‖, max(‖x‖, ‖z‖) and ‖u‖, in the Euclidean norm or in
# the norm `nrm`; tmp is a buffer, free after the u-update
_admm_norms(::Nothing, x, z, z_previous, u, tmp) = (_norm_diff(x, z), _norm_diff(z, z_previous), max(_norm(x), _norm(z)), _norm(u))
_admm_norms(nrm, x, z, z_previous, u, tmp) =
  (_normdiff(nrm, x, z, tmp), _normdiff(nrm, z, z_previous, tmp), max(nrm(x), nrm(z)), nrm(u))

# ‖a - b‖ in the norm nrm: from its method of two arrays (or tuples) if it has
# one, otherwise from the difference formed in tmp
_normdiff(nrm, a, b, tmp) = applicable(nrm, a, b) ? nrm(a, b) : nrm(_sub!(tmp, a, b))

# residual balancing: the factor by which to multiply ρ, with each residual
# relative to its tolerance; ρ stays fixed after _max_ρ_changes changes
const _max_ρ_changes = 50

function _ρ_factor(r_norm, eps_pri, s_norm, eps_dual, changes)
  changes >= _max_ρ_changes && return 1
  r, s = r_norm / eps_pri, s_norm / eps_dual
  r > 10 * s ? 2 : s > 10 * r ? 1 // 2 : 1
end

# x is the starting point for z and is overwritten with the solution; u, when
# given, is the starting scaled dual variable, which is overwritten too
function solve!(
    x::Union{Array{T}, Tuple{Array{T}, Vararg{Array{T}}}},
    f::AbstractFunction,
    g::AbstractFunction,
    method::ADMMSolver,
    options::ProximalOptions = ProximalOptions();
    u::Union{Nothing, Array{T}, Tuple{Array{T}, Vararg{Array{T}}}} = nothing
    ) where {T<:AbstractFloat}

  isproximable(f) || throw(ArgumentError("ADMM needs a proximable f (isproximable(f)), but f is a $(typeof(f))."))
  isproximable(g) || throw(ArgumentError("ADMM needs a proximable g (isproximable(g)), but g is a $(typeof(g))."))
  u === nothing || (typeof(u) == typeof(x) && _size(u) == _size(x)) || throw(DimensionMismatch("u must have the size of x"))
  _workspace_noalias(x)
  if u !== nothing
    _workspace_noalias(u)
    _admm_alias(x, u) && throw(ArgumentError("the primal and dual iterates must have separate storage"))
  end
  t0 = time()
  ρ = T(method.ρ)

  z = x
  xk = _copy(x)
  u = u === nothing ? _zero(x) : u
  z_previous = _similar(x)
  tmp = _similar(x)
  gapev = options.gaptol > 0 ? _gapevaluator(f, g, x) : nothing
  _solve_admm!(z, f, g, method, options, xk, u, z_previous, tmp, gapev, t0, ρ)
end

function _solve_admm!(z::Union{AbstractArray{T}, _Blocks{T}}, f, g, method, options,
                      xk, u, z_previous, tmp, gapev, t0 = time(), ρ = T(method.ρ)) where {T}
  α = T(method.α)
  sqrt_n = sqrt(T(_length(z)))

  r_norm = s_norm = eps_pri = eps_dual = T(Inf)
  converged = false
  call_limit_reached = false
  iteration = changes = 0
  f_calls = prox_calls = 0

  # with gaptol, the duality gap at z replaces the residual tests
  options.gaptol > 0 && gapev === nothing &&
    @warn "there is no duality gap for $(nameof(typeof(f))) with $(nameof(typeof(g))); gaptol is ignored." maxlog = 1
  relgap, relgap_iteration = NaN, -1

  options.show_trace && @printf "Iter     Function value   primal res.      dual res.\n"

  while !converged && !call_limit_reached && iteration < options.maxiter && time() - t0 <= options.time_limit
    iteration += 1
    γ = one(T) / ρ

    # x-update: x = prox_{f/ρ}(z - u)
    _sub!(tmp, z, u)
    prox!(xk, f, tmp, γ)

    # z-update with relaxation: z = prox_{g/ρ}(α x + (1 - α) z + u)
    _copyto!(z_previous, z)
    _relax!(tmp, α, xk, z_previous, u)
    prox!(z, g, tmp, γ)

    # u-update
    _sub!(u, tmp, z)
    prox_calls += 2

    # check convergence
    r_norm, s_norm, nxz, nu = _admm_norms(method.norm, xk, z, z_previous, u, tmp)
    s_norm *= ρ
    eps_pri = sqrt_n * T(method.abstol) + T(method.reltol) * nxz
    eps_dual = sqrt_n * T(method.abstol_dual) + T(method.reltol) * ρ * nu
    converged = all(isfinite, (r_norm, s_norm, eps_pri, eps_dual)) && r_norm <= eps_pri && s_norm <= eps_dual
    if gapev !== nothing
      if iteration % options.gapevery == 0
        relgap, relgap_iteration = _relgap!(gapev, f, g, z), iteration
        isnan(relgap) || (converged = relgap <= options.gaptol)
      else
        converged = false
      end
    end
    call_limit_reached = options.prox_calls_limit > 0 && prox_calls >= options.prox_calls_limit

    if options.show_trace && iteration % options.print_every == 0
      @printf "%6d   %14e   %14e   %14e\n" iteration f(z) + g(z) r_norm s_norm
      f_calls += 1
    end

    # balance the residuals; the scaled dual variable u = y/ρ changes with ρ
    if method.adaptive && !converged
      c = _ρ_factor(r_norm, eps_pri, s_norm, eps_dual, changes)
      if c != 1
        ρ *= c
        _rdiv!(u, c)
        changes += 1
      end
    end
  end

  gapev === nothing || relgap_iteration == iteration || (relgap = _relgap!(gapev, f, g, z))
  if gapev !== nothing
    # A limit can stop before the next scheduled gap check. Certify the returned
    # point from its final gap, or from its residuals when that gap is unavailable.
    # Before any iteration the Inf placeholders do not provide a residual test.
    converged = isnan(relgap) ? iteration > 0 && all(isfinite, (r_norm, s_norm, eps_pri, eps_dual)) && r_norm <= eps_pri && s_norm <= eps_dual : relgap <= options.gaptol
  end

  # f(z) for the minimum is one more call
  ADMMResults(z, f(z) + g(z), iteration, converged,
              r_norm, s_norm, eps_pri, eps_dual, u, ρ,
              f_calls + 1, 0, prox_calls, call_limit_reached, relgap)
end

_admm_alias(x::AbstractArray, u::AbstractArray) = Base.mightalias(x, u)
_admm_alias(x::Tuple, u::Tuple) = any(Base.mightalias(a, b) for a in x for b in u)
