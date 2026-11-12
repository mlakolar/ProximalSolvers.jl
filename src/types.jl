"""
    ProximalSolver

Abstract supertype of CDSolver and ProximalGradientDescent, passed to solve!.
"""
abstract type ProximalSolver end


"""
    ProximalOptions(; maxiter=200, ftol=1e-6, xtol=1e-8, gradtol=1e-5,
      allow_f_increases=false, store_trace=false, show_trace=false,
      extended_trace=false, print_every=1, callback=nothing, time_limit=Inf,
      f_calls_limit=0, grad_calls_limit=0, prox_calls_limit=0, gaptol=0, gapevery=10)

Options for proximal gradient descent (PGD). The defaults prioritize an
exploratory solve rather than a guaranteed number of accurate digits.
PGD stops when **any** of the iterate-change (`xtol`), objective-change
(`ftol`), or gradient/proximal-residual (`gradtol`) criteria succeeds.
`converged=true` is therefore **not** a KKT certificate.

With `allow_f_increases=false` (the default), PGD also stops at the first
iteration whose computed objective `F = f(x) + g(x)`, in the working
precision, exceeds the previous iteration's `F'`. This stop is **not** a
convergence test. At the iteration where any stop occurs, the result
reports `f_increased = F > F'` and
`converged = x_converged || f_converged || grad_converged`, so an
objective-increase stop reports `converged=false` unless one of those
tests also held. The objective test holds when
`|F - F'| / (|F| + ftol) < ftol` or `|F - F'| < eps(|F| + |F'|)`, about two
units in the last place of `F`; a smaller increase therefore reports both
`converged=true` and `f_increased=true`. Near a minimizer the computed
change in `F` is of the size of the rounding error of evaluating `F`, so
whether a strict-tolerance solve ends with `converged=true` or with an
objective-increase stop can depend on the last bits of its trajectory
(CPU, BLAS kernel, compilation) rather than on the accuracy of the point.
`allow_f_increases=true` removes this stop; `f_increased` then only reports
the comparison at the last iteration. `iteration_converged` is
`iterations == maxiter`, which also holds when a test succeeded at that
last iteration. See the
[numerical behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/)
page.

`maxiter` caps iterations; `store_trace`, `show_trace` and
`extended_trace` control reporting. `print_every` sets display/callback
cadence; a callback receives the trace when it is stored, otherwise the
current state. The result display labels an internal gradient/proximal
residual as `|g(x)|`: it is **not** the value of the supplied penalty.

Call/time limits are checked after complete iterations, so counts can exceed
limits by one iteration. A zero call limit means unlimited. Float32/Float64
iterate buffers retain native arithmetic; some scalar tolerances and diagnostics
are held in Float64, without increasing coefficient accuracy.
Positive `gaptol` is not supported; positive `gapevery` has no effect
when `gaptol=0`.
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

function ProximalOptions(; maxiter::Integer = 200,
                         ftol::Real = 1.0e-6,
                         xtol::Real = 1.0e-8,
                         gradtol::Real = 1.0e-5,
                         f_calls_limit::Int = 0,
                         grad_calls_limit::Int = 0,
                         prox_calls_limit::Int = 0,
                         allow_f_increases::Bool = false,
                         store_trace::Bool = false,
                         show_trace::Bool = false,
                         extended_trace::Bool = false,
                         print_every::Integer = 1,
                         callback = nothing,
                         time_limit = Inf,
                         gaptol::Real = 0.0,
                         gapevery::Integer = 10)

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

Result from proximal gradient descent. `minimizer` aliases the caller's
coefficient vector; `minimum` is the reported objective at that iterate.
`iterations` counts steps and `converged` means **at least one** stopping
criterion succeeded, not necessarily that the solution satisfies KKT
optimality. `iteration_converged` reports reaching the iteration limit,
**not** successful convergence.

The result also stores stopping flags, residuals and tolerances, optional
`trace`, call counts and backtracking counts. `backtrack_steps`
includes accepted nonzero line-search trials. `gap=NaN` means a dual
gap was not calculated, not that the gap is zero.
"""
mutable struct OptimizationResults{O<:ProximalSolver, T, N, M, X<:AbstractArray{T, N}}
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

    OptimizationResults{O, T, N, M, X}(fields...) where {O, T, N, M, X} = new{O, T, N, M, X}(fields...)
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

function Base.show(io::IO, r::OptimizationResults)
    @printf io "Results of Optimization Algorithm\n"
    @printf io " * Algorithm: %s\n" summary(r)
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
