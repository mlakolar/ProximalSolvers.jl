"""
    ProximalSolver

Abstract supertype of CDSolver, ProximalGradientDescent and AccProxGradDescent,
passed to solve!.
"""
abstract type ProximalSolver end


"""
    ProximalOptions(; maxiter=200, ftol=1e-6, xtol=1e-8, gradtol=1e-5,
      allow_f_increases=false, store_trace=false, show_trace=false,
      extended_trace=false, print_every=1, callback=nothing, time_limit=Inf,
      f_calls_limit=0, grad_calls_limit=0, prox_calls_limit=0, gaptol=0, gapevery=10)

Options for proximal gradient descent (PGD); `AccProxGradDescent` uses the
same options and tests. The defaults prioritize an
exploratory solve rather than a guaranteed number of accurate digits.
PGD stops when **any** of the iterate-change (`xtol`), objective-change
(`ftol`), or gradient/proximal-residual (`gradtol`) criteria succeeds.
`converged=true` is therefore **not** a KKT certificate.

`ftol` must be finite and nonnegative. With `ftol > 0`, including the default,
the objective test holds when `|F - F'| / (|F| + ftol) < ftol` or
`|F - F'| < eps(|F| + |F'|)`, where `F = f(x) + g(x)` is the computed objective and
`F'` the previous one. The second form holds when `F == F'` and `|F| + |F'|` is finite,
so a flat computed objective ends the solve with `f_converged=true`, which is not
evidence of an accurate point; in the ordinary range, where `F` and `F'` are normal
floating-point numbers and `|F| + |F'|` is finite, it is about two units in the last
place of `F`. (If `|F| + |F'|`
overflows, `eps` is `NaN` and the second form does not hold.) `ftol = 0` switches
the objective test off: `f_converged` is `false` at every iteration. A positive
`ftol` that rounds to 0 in `Float64` is refused, so that a tiny value does not
mean "off", and `-0.0` is stored as `0.0`.

With `ftol = 0` only, an iteration whose accepted iterate equals the previous one
elementwise (compared by value, so `-0.0 == 0.0`) is no progress: it sets neither
`x_converged` nor `grad_converged`, and the solve continues, subject to the other
tests, the limits and, with `allow_f_increases=false`, the objective-increase stop.
A solve whose iterate stays unchanged until `maxiter`, and does not stop as described
below, ends with `converged=false` and `iteration_converged=true`; the flags then report
no progress, not that the point is wrong. An iterate that differs from the previous
one in any entry is evaluated as usual, including when the norm of the difference
rounds to 0. With `ftol > 0`, an unchanged iterate satisfies the `xtol` test. For
`AccProxGradDescent`, an extrapolated point `y` equal to `x` while `x` differs from
the previous iterate is not a stall: its residual `L * maximum(abs, x - y)` is 0, so
the gradient test holds when `gradtol > 0`.

With `ftol = 0`, `ProximalGradientDescent` on `Vector{Float32}` data also stops, after
the callback has seen the iteration, at an iteration in which both of these hold: the
accepted iterate equals the previous one elementwise, and the last rejection of that
iteration's line search was decided by the computed curvature of the rejected step, which
was finite and replaced the curvature estimate. A rejection that is not checked (a trial
value that is not finite, a NaN estimate, a gradient estimate from a gradient with a
nonfinite entry) or whose computed curvature is not finite does not count, and neither does
an iteration whose first trial is already a zero step (it has no rejection). A later
rejection of the same iteration replaces an earlier one, and nothing carries over from
an earlier iteration. The result then has `stagnated=true`
and `converged=false` (see [`OptimizationResults`](@ref)); this is not a convergence or
accuracy certificate. For `Float64` data, for `AccProxGradDescent` and with `ftol > 0`,
`stagnated` is `false` and the stopping behavior is as described above.

With `allow_f_increases=false` (the default), PGD also stops at the first
iteration whose computed objective `F = f(x) + g(x)`, in the working
precision, exceeds the previous iteration's `F'`. This stop is **not** a
convergence test. At the iteration where any stop occurs, the result
reports `f_increased = F > F'` and
`converged = x_converged || f_converged || grad_converged`, so an
objective-increase stop reports `converged=false` unless one of those
tests also held. With `ftol > 0`, in the ordinary range (`F` and `F'` normal
floating-point numbers, `|F| + |F'|` finite), an increase smaller than about two
units in the last place of `F` passes the objective test and reports both
`converged=true` and `f_increased=true`. With `ftol = 0`, `f_converged` is
`false`, so an increase of any size reports `converged=false` unless the `x` or
gradient test held. Near a minimizer the computed
change in `F` is of the size of the rounding error of evaluating `F`, so
whether a strict-tolerance solve ends with `converged=true` or with an
objective-increase stop can depend on the last bits of its trajectory
(CPU, BLAS kernel, compilation) rather than on the accuracy of the point.
`allow_f_increases=true` removes this stop; `f_increased` then only reports
the comparison at the last iteration. `iteration_converged` is
`iterations == maxiter`, which also holds when a test succeeded at that
last iteration. See the
[numerical behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/)
page, which also describes a strict-accuracy configuration with `ftol = 0`.

`maxiter` caps iterations; `store_trace`, `show_trace` and
`extended_trace` control reporting. `print_every` sets display/callback
cadence; a callback receives the trace when it is stored, otherwise the
current state. The result display labels an internal gradient/proximal
residual as `|g(x)|`: it is **not** the value of the supplied penalty.

Call/time limits are checked after complete iterations, so counts can exceed
limits by one iteration. A zero call limit means unlimited. Float32/Float64
iterate buffers retain native arithmetic; some scalar tolerances and diagnostics
are held in Float64, without increasing coefficient accuracy.
Gap certificates are not implemented: `gaptol` and `gapevery` are accepted
for compatibility but not stored, a positive `gaptol` is refused when the
options are constructed, and `gapevery` (which must be positive) has no effect.
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
  # The only constructor, so every route into ProximalOptions is validated.
  function ProximalOptions(maxiter::Integer, ftol::Real, xtol::Real, gradtol::Real,
                           f_calls_limit::Integer, grad_calls_limit::Integer,
                           prox_calls_limit::Integer, allow_f_increases::Bool,
                           store_trace::Bool, show_trace::Bool, extended_trace::Bool,
                           print_every::Integer, callback::TCallback,
                           time_limit) where TCallback
    # ftol and xtol are checked as given and as stored, so a positive value that
    # converts to 0.0 is refused; a gradtol that converts to 0.0 is stored as 0.0
    f, x, g = Float64(ftol), Float64(xtol), Float64(gradtol)
    maxiter > 1 || throw(ArgumentError("maxiter must be an integer greater than 1."))
    # ftol = 0 switches off the objective test, so a tiny positive ftol must not become it
    isfinite(f) && ftol >= 0 && f >= 0 || throw(ArgumentError("ftol must be finite and nonnegative."))
    ftol > 0 && iszero(f) && throw(ArgumentError("ftol is positive but rounds to 0 in Float64; pass 0 to disable the objective test."))
    isfinite(x) && xtol > 0 && x > 0 || throw(ArgumentError("xtol must be finite and positive."))
    isfinite(g) && gradtol >= 0 && g >= 0 || throw(ArgumentError("gradtol must be finite and nonnegative."))
    min(f_calls_limit, grad_calls_limit, prox_calls_limit) >= 0 || throw(ArgumentError("call limits must be nonnegative."))
    isnan(time_limit) && throw(ArgumentError("time_limit must not be NaN."))
    print_every > 0 || throw(ArgumentError("print_every must be positive."))
    # -0.0 passes the checks above and is stored as +0.0
    new{TCallback}(maxiter, iszero(f) ? 0.0 : f, x, g, f_calls_limit, grad_calls_limit,
                   prox_calls_limit, allow_f_increases, store_trace, show_trace,
                   extended_trace, print_every, callback, time_limit)
  end
end

# gaptol and gapevery are accepted for compatibility and not stored: gap
# certificates are not implemented, so only gaptol = 0 is accepted.
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
  options = ProximalOptions(maxiter, ftol, xtol, gradtol, f_calls_limit, grad_calls_limit,
                            prox_calls_limit, allow_f_increases, store_trace, show_trace,
                            extended_trace, print_every, callback, time_limit)
  isfinite(Float64(gaptol)) && gaptol >= 0 || throw(ArgumentError("gaptol must be finite and nonnegative."))
  gapevery > 0 || throw(ArgumentError("gapevery must be positive."))
  iszero(gaptol) || throw(ArgumentError("gap certificates are deferred"))
  options
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

Result from proximal gradient descent, plain or accelerated. `minimizer` aliases the caller's
coefficient vector; `minimum` is the reported objective at that iterate.
`iterations` counts steps and `converged` means **at least one** stopping
criterion succeeded, not necessarily that the solution satisfies KKT
optimality. `iteration_converged` reports reaching the iteration limit,
**not** successful convergence.

The result also stores stopping flags, residuals and tolerances, optional
`trace`, call counts and backtracking counts. For PGD, `backtrack_steps`
includes accepted nonzero line-search trials; for APG it counts every trial,
including the accepted one. `gap=NaN` means a dual
gap was not calculated, not that the gap is zero.

`f_increased` is `F > F'` at the last iteration, where `F` is the computed
objective and `F'` the previous one. It reports the comparison: an increase
stops the solve only when `allow_f_increases=false`, a setting the result does
not store. With `ftol = 0` (see [`ProximalOptions`](@ref)), `f_tol` is `0.0` and
`f_converged` is `false`, because the objective test is off. `f_residual` is
then reported only and does not decide a stop; it is `|F - F'| / |F|`, with the
value `0.0` for `F = F' = 0` and `Inf` for `F = 0` and `F' != 0`. With `ftol > 0`
it is `|F - F'| / (|F| + ftol)`. On an iteration whose iterate equals the
previous one elementwise, `ftol = 0` sets neither `x_converged` nor
`grad_converged` (see [`ProximalOptions`](@ref) for the accelerated method's
case `x == y`).

`stagnated` is `true` when `ProximalGradientDescent` on `Vector{Float32}` data with
`ftol = 0` stopped after an iteration in which both of these held: the accepted iterate
equals the previous one elementwise, and the last rejection of that iteration's line search
replaced the curvature estimate by the finite computed curvature of the rejected step (see
[`ProximalOptions`](@ref) for the condition). At such a stop `converged`, `x_converged`,
`f_converged` and `grad_converged` are `false` and `x_residual` is `0`. `stagnated=true`
is **not** a certificate of convergence or accuracy: it reports that an iteration left the
iterate unchanged after its line search last rejected a step by that step's computed
curvature, and the returned point need not meet any accuracy target. `stagnated` is `false` for every other method and
element type and with `ftol > 0`. Each stopping flag reports its own condition, so
`stagnated` can be `true` together with `call_limit_reached`, or at an iteration at which
the callback returned `true`.
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
    stagnated::Bool
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
stagnated(r::OptimizationResults) = r.stagnated


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
    if iszero(f_tol(r))
        @printf io "   * objective-change test: disabled (ftol = 0)\n"
    else
        @printf io "   * |f(x) - f(x')| / |f(x)| < %.1e: %s\n" f_tol(r) f_converged(r)
    end
    @printf io "     |f(x) - f(x')| / |f(x)| = %.2e \n" f_residual(r)
    @printf io "   * |g(x)| < %.1e: %s \n" g_tol(r) grad_converged(r)
    @printf io "     |g(x)| = %.2e \n"  g_residual(r)
    @printf io "   * objective increased at the last iteration: %s\n" f_increased(r)
    @printf io "   * Reached Maximum Number of Iterations: %s\n" iteration_limit_reached(r)
    @printf io "   * Reached a limit on the number of calls: %s\n" call_limit_reached(r)
    @printf io "   * Stopped at numerical stagnation: %s\n" stagnated(r)
    isnan(r.gap) || @printf io "   * relative duality gap %.2e\n" r.gap
    @printf io " * Backtracking steps: %d\n" backtrack_steps(r)
    @printf io " * f(x) calls: %d\n" f_calls(r)
    @printf io " * ∇f(x) calls: %d\n" grad_calls(r)
    @printf io " * prox calls: %d\n" prox_calls(r)
    return
end
