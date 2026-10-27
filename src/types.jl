"""
    ProximalSolver

Abstract supertype of the solvers passed to [`solve!`](@ref):
[`ProximalGradientDescent`](@ref), [`AccProxGradDescent`](@ref),
[`MonotoneAccProxGradDescent`](@ref), [`ActiveAccProxGradDescent`](@ref) and
[`ADMMSolver`](@ref) and [`CondatVu`](@ref).
"""
abstract type ProximalSolver end


"""
    ProximalOptions(; kwargs...)

Options for [`solve!`](@ref). The solver stops at the first of: a convergence
test passes, `maxiter` iterations, `time_limit` seconds, a limit on the number
of calls, the objective increases (unless `allow_f_increases`), or `callback`
returns `true`.

# Keywords
- `maxiter = 200`: maximum number of iterations.
- `ftol = 1e-6`: stop when `|F(x) - F(x')| / (|F(x)| + ftol) < ftol`, where
  `F = f + g` and `x'` is the previous iterate.
- `xtol = 1e-8`: stop when `‖x - x'‖ < xtol * max(‖x‖, 1)`.
- `gradtol = 1e-5`: stop when the relative or normalized optimality residual of
  Goldstein, Studer and Baraniuk (FASTA) is below `gradtol`. Not used by
  [`ADMMSolver`](@ref), which has its own tolerances.
- `allow_f_increases = false`: keep iterating when the objective increases.
- `store_trace = false`: record an [`OptimizationState`](@ref) per iteration in
  the results.
- `show_trace = false`: print the progress every `print_every` iterations.
- `extended_trace = false`: also store the iterate and gradient in each state.
- `print_every = 1`: how often to print and call `callback`; stored gradient traces include every iteration.
- `callback = nothing`: a callable object called every `print_every` iterations with
  the trace (if `store_trace`) or the current state; return `true` to stop.
- `time_limit = Inf`: maximum run time in seconds.
- `f_calls_limit = 0`, `grad_calls_limit = 0`, `prox_calls_limit = 0`: stop
  once `f`, the gradient of `f`, or proximal operators (`prox!`) have been
  evaluated this many times; `0` means no limit. The counts are checked after
  each iteration, which always finishes, so a count can exceed its limit by
  the evaluations of one iteration. [`ADMMSolver`](@ref) uses only
  `prox_calls_limit`.
- `gaptol = 0`: with `gaptol > 0`, stop when the relative duality gap
  `(P - D) / |P|` at the iterate is at most `gaptol`, checked every `gapevery`
  iterations, instead of on the `ftol`, `xtol`, `gradtol` tests and an
  increasing objective (or ADMM's residuals): a certificate that `P = f + g` is within `gaptol ⋅ |P|` of its
  minimum (see [`duality_gap`](@ref) for the functions that have a gap; for
  others `gaptol` is ignored, with a warning). Used by
  [`ProximalGradientDescent`](@ref), [`AccProxGradDescent`](@ref) and
  [`ADMMSolver`](@ref); the results report the final relative gap as `gap`.
- `gapevery = 10`: how often to compute the gap when `gaptol > 0`. Each
  evaluation costs about two products with the design.

[`CondatVu`](@ref) uses these limits, tracing and gap options for a linear
composite problem, with its own KKT residual tolerances instead of `ftol`,
`xtol` and `gradtol`. Unsupported composite conjugates raise an error when
`gaptol > 0`; a valid relative gap callback can be supplied instead.

The solvers work in the starting point's element type, including `Float32`
and `Float64`. Tolerances below working precision can produce stagnation or
rounded residuals; they do not imply correspondingly accurate coefficients.
"""
struct ProximalOptions{TCallback}
  maxiter::Int64
  ftol::Float64
  xtol::Float64
  gradtol::Float64
  f_calls_limit::Int
  grad_calls_limit::Int
  prox_calls_limit::Int
  allow_f_increases::Bool
  store_trace::Bool
  show_trace::Bool
  extended_trace::Bool
  print_every::Int64
  callback::TCallback
  time_limit::Float64
  gaptol::Float64
  gapevery::Int
end

function ProximalOptions(;maxiter::Integer       = 200,
                         ftol::Real              = 1.0e-6,
                         xtol::Real              = 1.0e-8,
                         gradtol::Real           = 1.0e-5,
                         f_calls_limit::Int      = 0,
                         grad_calls_limit::Int   = 0,
                         prox_calls_limit::Int   = 0,
                         allow_f_increases::Bool = false,
                         store_trace::Bool       = false,
                         show_trace::Bool        = false,
                         extended_trace::Bool    = false,
                         print_every::Integer    = 1,
                         callback                = nothing,
                         time_limit              = Inf,
                         gaptol::Real            = 0.0,
                         gapevery::Integer       = 10)

  maxiter > 1 || throw(ArgumentError("maxiter must be an integer greater than 1."))
  isfinite(Float64(ftol)) && ftol > 0 || throw(ArgumentError("ftol must be finite and positive."))
  isfinite(Float64(xtol)) && xtol > 0 || throw(ArgumentError("xtol must be finite and positive."))
  isfinite(Float64(gradtol)) && gradtol >= 0 || throw(ArgumentError("gradtol must be finite and nonnegative."))
  isfinite(Float64(gaptol)) && gaptol >= 0 || throw(ArgumentError("gaptol must be finite and nonnegative."))
  min(f_calls_limit, grad_calls_limit, prox_calls_limit) >= 0 || throw(ArgumentError("call limits must be nonnegative."))
  isnan(time_limit) && throw(ArgumentError("time_limit must not be NaN."))
  gapevery > 0 || throw(ArgumentError("gapevery must be positive."))
  print_every > 0 || throw(ArgumentError("print_every must be positive."))

  ProximalOptions{typeof(callback)}(
                  convert(Int64, maxiter),
                  convert(Float64, ftol),
                  convert(Float64, xtol),
                  convert(Float64, gradtol),
                  f_calls_limit,
                  grad_calls_limit,
                  prox_calls_limit,
                  allow_f_increases,
                  store_trace,
                  show_trace,
                  extended_trace,
                  convert(Int64, print_every),
                  callback,
                  time_limit,
                  convert(Float64, gaptol),
                  convert(Int, gapevery)
                  )
end


function print_header(options::ProximalOptions)
  if options.show_trace
    @printf "Iter     Function value       |dx|/|x|       Step Size\n"
  end
end

function print_header(method::ProximalSolver, options::ProximalOptions)
    @printf "Iter     Function value       |dx|/|x|       Step Size\n"
end


"""
    OptimizationState{T<:ProximalSolver}

One iteration of a trace: `iteration`, the objective `fg_x = f(x) + g(x)`,
the relative change `dxx = ‖x - x'‖ / ‖x‖`, the inverse step size `L`, and a
`metadata` dictionary that holds the iterate and gradient when
`extended_trace = true`.
"""
struct OptimizationState{T <: ProximalSolver}
    iteration::Int
    fg_x::Float64
    dxx::Float64
    L::Float64
    metadata::Dict
end

"""
    OptimizationTrace{T}

A `Vector{OptimizationState{T}}`, stored in the results when
`store_trace = true` (see [`ProximalOptions`](@ref)).
"""
OptimizationTrace{T} = Vector{OptimizationState{T}}


function Base.show(io::IO, t::OptimizationState)
    @printf io "%6d   %14e   %14e   %14e\n" t.iteration t.fg_x t.dxx 1. / t.L
    if !isempty(t.metadata)
        for (key, value) in t.metadata
            @printf io " * %s: %s\n" key value
        end
    end
    return
end

function Base.show(io::IO, tr::OptimizationTrace)
    @printf io "Iter     Function value   |dx|/|x|       Step Size\n"
    @printf io "------   --------------   --------       ---------\n"
    for state in tr
        show(io, state)
    end
    return
end



"""
    OptimizationResults

Returned by [`solve!`](@ref) for [`ProximalGradientDescent`](@ref) and
[`AccProxGradDescent`](@ref). Its fields include `minimizer`, `minimum`
(`f + g` at the minimizer), `iterations`, `converged` (the selected
convergence criterion passed), the diagnostic flags `x_converged`,
`f_converged`, `grad_converged`, `f_increased` and `iteration_converged`
(the iteration limit was reached), the final residuals `x_residual`,
`f_residual` and `g_residual` with their tolerances, the `trace`,
`backtrack_steps`, the number of trial steps checked by the backtracking line
search over all iterations (accepted steps included), and the number of
evaluations: `f_calls` of `f` (by `value` or `value_and_gradient!`),
`grad_calls` of its gradient and `prox_calls` of the proximal operator of `g`.
`call_limit_reached` is `true` when the solver stopped at one of the limits in
[`ProximalOptions`](@ref), and `gap` is the relative duality gap at the
minimizer when `gaptol > 0`, `NaN` otherwise. With a computable gap and
`gaptol > 0`, `converged` reports whether that gap meets `gaptol`; the
diagnostic flags still report the individual residual tests. Without a
computable gap, those tests determine `converged`. The minimizer is the `x` passed
to `solve!`: an `Array`, a `SparseIterate`, an `AtomIterate`, or a tuple of
arrays (`N` is 1 for a tuple).
"""
mutable struct OptimizationResults{O<:ProximalSolver,T,N,M,X<:Union{AbstractArray{T,N}, _Blocks{T}}}
    method::O
    minimizer::X
    minimum::T
    iterations::Int
    iteration_converged::Bool
    converged::Bool
    x_converged::Bool
    x_tol::Float64
    x_residual::Float64
    f_converged::Bool
    f_tol::Float64
    f_residual::Float64
    grad_converged::Bool
    g_tol::Float64
    g_residual::Float64
    f_increased::Bool
    trace::OptimizationTrace{M}
    backtrack_steps::Int
    f_calls::Int
    grad_calls::Int
    prox_calls::Int
    call_limit_reached::Bool
    gap::Float64

    # N appears only in the bound of X, which a tuple leaves free, so solve!
    # gives all the parameters
    OptimizationResults{O,T,N,M,X}(fields...) where {O,T,N,M,X} = new{O,T,N,M,X}(fields...)
end

Base.summary(r::OptimizationResults) = summary(r.method)
minimizer(r::OptimizationResults) = r.minimizer
minimum(r::OptimizationResults) = r.minimum
iterations(r::OptimizationResults) = r.iterations
iteration_limit_reached(r::OptimizationResults) = r.iteration_converged
converged(r::OptimizationResults) = r.converged
x_converged(r::OptimizationResults) = r.x_converged
f_converged(r::OptimizationResults) = r.f_converged
f_increased(r::OptimizationResults) = r.f_increased
grad_converged(r::OptimizationResults) = r.grad_converged

x_tol(r::OptimizationResults) = r.x_tol
x_residual(r::OptimizationResults) = r.x_residual
f_tol(r::OptimizationResults) = r.f_tol
f_residual(r::OptimizationResults) = r.f_residual
g_tol(r::OptimizationResults) = r.g_tol
g_residual(r::OptimizationResults) = r.g_residual
backtrack_steps(r::OptimizationResults) = r.backtrack_steps
f_calls(r::OptimizationResults) = r.f_calls
grad_calls(r::OptimizationResults) = r.grad_calls
prox_calls(r::OptimizationResults) = r.prox_calls
call_limit_reached(r::OptimizationResults) = r.call_limit_reached


function _show_minimizer(io::IO, x::AbstractArray)
    @printf io " * Minimizer: [%s%s]\n" join(Iterators.take(x, 2), ",") (length(x) > 2 ? ", ..." : "")
end
_show_minimizer(io::IO, x::Tuple) =
    @printf io " * Minimizer: %d blocks of sizes %s\n" length(x) join(map(b -> join(size(b), "×"), x), ", ")

function Base.show(io::IO, r::OptimizationResults)
    @printf io "Results of Optimization Algorithm\n"
    @printf io " * Algorithm: %s\n" summary(r)
    # if length(join(initial_state(r), ",")) < 40
    #     @printf io " * Starting Point: [%s]\n" join(initial_state(r), ",")
    # else
    #     @printf io " * Starting Point: [%s, ...]\n" join(initial_state(r)[1:2], ",")
    # end
    _show_minimizer(io, minimizer(r))
    @printf io " * Minimum: %e\n" minimum(r)
    @printf io " * Iterations: %d\n" iterations(r)
    @printf io " * Convergence: %s\n" converged(r)
    @printf io "   * |x - x'| < %.1e: %s \n" x_tol(r) x_converged(r)
    @printf io "     |x - x'| = %.2e \n"  x_residual(r)
    @printf io "   * |f(x) - f(x')| / |f(x)| < %.1e: %s\n" f_tol(r) f_converged(r)
    @printf io "     |f(x) - f(x')| / |f(x)| = %.2e \n" f_residual(r)
    @printf io "   * |g(x)| < %.1e: %s \n" g_tol(r) grad_converged(r)
    @printf io "     |g(x)| = %.2e \n"  g_residual(r)
    @printf io "   * stopped by an increasing objective: %s\n" f_increased(r)
    @printf io "   * Reached Maximum Number of Iterations: %s\n" iteration_limit_reached(r)
    @printf io "   * Reached a limit on the number of calls: %s\n" call_limit_reached(r)
    isnan(r.gap) || @printf io "   * relative duality gap %.2e\n" r.gap
    @printf io " * Backtracking steps: %d\n" backtrack_steps(r)
    @printf io " * f(x) calls: %d\n" f_calls(r)
    @printf io " * ∇f(x) calls: %d\n" grad_calls(r)
    @printf io " * prox calls: %d\n" prox_calls(r)
    return
end
