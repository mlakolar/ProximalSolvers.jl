"""
    ProximalSolver

Abstract supertype of the solvers passed to [`solve!`](@ref).
"""
abstract type ProximalSolver end


"""
    ProximalOptions(; maxiter=200, ftol=1e-6, xtol=1e-8, gradtol=1e-5,
      allow_f_increases=false, store_trace=false, show_trace=false,
      extended_trace=false, print_every=1, callback=nothing, time_limit=Inf,
      f_calls_limit=0, grad_calls_limit=0, prox_calls_limit=0, gaptol=0, gapevery=10)

Options for [`ProximalGradientDescent`](@ref) and [`AccProxGradDescent`](@ref).
Configure iteration limits, stopping tolerances, traces and callbacks. Any one
of the iterate, objective or gradient tests can propose a stop; the applicable
computed stationarity check must also pass. Defaults are suitable for an initial
exploratory solve, without promising a particular coefficient accuracy.

```julia
using ProximalSolvers
options = ProximalOptions(maxiter=2000, ftol=1e-13, xtol=1e-11,
                         gradtol=1e-9, store_trace=true)
```

A successful stopping flag is not an exact optimality certificate; see
[the stopping rules](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-stopping/#STOP-01).

[`ADMMSolver`](@ref) uses `maxiter`, `prox_calls_limit` and `time_limit`. It
checks the limits before starting the next pair of proximal calls. See
[the ADMM options contract](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/admm/#ADM-02).
For matrix PGD, see the [accepted settings](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-logdet/#PGD-06)
and [limit checks](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-logdet/#PGD-08).

## Keywords

- `maxiter=200`: iteration limit.
- `ftol=1e-6`: nonnegative objective-change tolerance; `0` disables that test.
- `xtol=1e-8`: iterate-change tolerance.
- `gradtol=1e-5`: gradient/proximal-residual tolerance; the final stationarity
  check has its own working-precision floor.
- `allow_f_increases=false`: stop on a computed objective increase;
  `true` removes that exit without certifying the result.
- `store_trace=false`: retain iteration states in the returned `trace`.
- `show_trace=false`: print the iteration trace.
- `extended_trace=false`: include copied iterates and gradients in trace metadata.
- `print_every=1`: display and callback cadence.
- `callback=nothing`: optional callback; receives the stored trace when tracing
  is enabled, otherwise the current state, and returning `true` requests a stop.
- `time_limit=Inf`: elapsed-time limit in seconds.
- `f_calls_limit=0`, `grad_calls_limit=0`, `prox_calls_limit=0`: limits on smooth-loss,
  gradient and proximal calls, respectively;
  zero means unlimited. Limits are checked after complete iterations, so a count
  can exceed its limit by the work of one iteration.
- `gaptol=0`: reserved dual-gap stopping target; only `0` is accepted.
- `gapevery=10`: reserved interval between dual-gap checks; it must be positive
  but has no effect. Neither gap-related argument is stored.

# Extended help

For `NormL1`, `ElasticNet` and `GroupNormL2`, a proposed stop is checked against
the applicable computed KKT residual; `NormLinf` uses a proximal-gradient
mapping check. Neither certifies coefficient error. Check optimality independently
when the accuracy matters. These options do not configure coordinate descent:
`CDSolver` accepts unweighted `NormL1(lambda)`, weighted `NormL1(lambda, w)`,
`ElasticNet(lambda1, lambda2)` with or without weights `w`, and uncentered `SqrNormL2(lambda)` for dense or
one-dimensional `SparseIterate` least-squares problems and stops by its change test.
On a dense vector, `CDSolver` also accepts unweighted `NormL1Nonneg` and `IndNonnegative()`,
with the same change test for `converged`.

For dense PGD with unweighted `NormL1Nonneg(lambda)` or `IndNonnegative()`
(with `lambda = 0`), the KKT score is
`abs(grad[j] + T(lambda))` at a positive coefficient and
`max(-(grad[j] + T(lambda)), 0)` at zero. The check uses the scale
`max(T(lambda), s * norm(X'y, Inf))` and tolerance floor `64eps(T)`;
the complete threshold guards are in
[STOP-16](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-stopping/#STOP-16).
An infeasible starting point is refused before writes.

With `ftol=0`, an unchanged accepted iterate does not by itself count as
convergence. Float32 PGD can instead report `stagnated=true` and
`converged=false` under the documented stagnation condition. An objective increase,
an iteration/call limit and convergence are separate conditions; inspect the
individual result flags rather than inferring one from another.

The display label `|g(x)|` denotes an internal stopping residual, not the value
of the supplied penalty. Data and iterate buffers keep their working type;
Float64 tolerances or diagnostics do not increase Float32 coefficient accuracy.

- [Exact stopping formulas and exceptional exits](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-stopping/#STOP-01).
- [Iteration order, traces, callbacks and limits](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-iteration/#PGD-01).
- [Result fields and failure behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/results-failures/#RES-01).
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
    NumericalFeasibility(; coefficient_rtol = nothing, coefficient_atol = 0,
                         objective_rtol = nothing, mapping_rtol = nothing)

Opt-in for `IndBallL1(r)` with [`ProximalGradientDescent`](@ref) and
[`AccProxGradDescent`](@ref), passed as the `feasibility` keyword of [`solve!`](@ref).
Without it, `solve!` refuses `IndBallL1`.

```julia
using ProximalBase, ProximalSolvers
X = [1.0 0.25; 0.25 1.0; 0.5 -0.5]
y = [1.0, -0.5, 0.25]
beta = zeros(2)
result = solve!(beta, LeastSquaresLoss(y, X), IndBallL1(0.5), ProximalGradientDescent();
                feasibility = NumericalFeasibility())
result.converged, result.approximate_solution, result.feasibility.membership
```

The tolerances set the numerical feasibility cap on `‖x‖₁ - r` and the support-gap and
mapping budgets of the stopping check. A `nothing` takes the default for the coefficient type
`T` when `solve!` is called: `coefficient_rtol = 1e-5`, `objective_rtol = 1e-5` and
`mapping_rtol = 1e-4` for `Float32`, and `1e-10`, `1e-9` and `1e-8` for `Float64`; a
`nothing` for `coefficient_atol` takes its default `0`. Before writing to `x`, `solve!` refuses
with an `ArgumentError` a tolerance that is not a real number or `nothing`, coefficient
tolerances that are not finite and nonnegative, and objective or mapping tolerances that are not
finite and positive, each judged as given and after conversion to `Float64`. Zero coefficient
tolerances are accepted.

# Extended help

A trial is accepted only when its widened `Float64` ℓ1 mass is below `r + cap` by more
than a rounding allowance; this computed decision can pass at a point classified outside the
ball, whose computed widened mass then exceeds `r` by less than the cap (at most `r`), a computed
comparison rather than an exact bound on the violation. `converged = true` requires a passing full stopping check at a returned point
classified inside the ball; a passing check at a point classified outside or not classified sets
`approximate_solution = true` and `converged = false`. A limit or callback can end a solve without
a passing check; then both flags are false. A callback may read the coefficients and must leave them
and the data unchanged. The inputs and refusals are [IN-12](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-12),
the decision and budgets [FP-05](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/working-precision/#FP-05),
the trials [PGD-09](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-iteration/#PGD-09),
the stopping check [STOP-22](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-stopping/#STOP-22)
and the result fields [RES-04](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/results-failures/#RES-04).
"""
struct NumericalFeasibility{A, B, C, D}
  coefficient_rtol::A
  coefficient_atol::B
  objective_rtol::C
  mapping_rtol::D
end

NumericalFeasibility(; coefficient_rtol = nothing, coefficient_atol = 0, objective_rtol = nothing,
                     mapping_rtol = nothing) =
  NumericalFeasibility(coefficient_rtol, coefficient_atol, objective_rtol, mapping_rtol)

"""
    NumericalFeasibilityReport

The `feasibility` field of an [`OptimizationResults`](@ref ProximalSolvers.OptimizationResults) returned
with the opt-in `IndBallL1` route of [`NumericalFeasibility`](@ref); the other routes store `nothing`.

- `membership`: `:inside`, `:outside` or `:unknown`, the classification of the returned `x` (when
  callbacks leave `x` unchanged) by its computed widened `Float64` ℓ1 mass `s` against the radius `r`,
  with the rounding allowance of
  [FP-05](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/working-precision/#FP-05).
- `margin`: the computed `s - r`, in `Float64`.
- `cap`: the numerical feasibility cap of the solve.
- `gap`, `gap_noise`, `mapping`, `map_noise`: the support gap and fixed-step mapping of the last full
  stopping check, with their rounding allowances; that check can precede the returned iterate. `NaN`
  when no check ran; a failed check can store nonfinite values.
- `gap_budget`, `mapping_budget`: the budgets of the solve, which a full check compares with
  `gap + gap_noise` and `mapping + map_noise`.
- `checks`: the number of full checks of the solve.

The field definitions are [RES-04](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/results-failures/#RES-04)
and [STOP-22](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-stopping/#STOP-22).
"""
struct NumericalFeasibilityReport
  membership::Symbol
  margin::Float64
  cap::Float64
  gap::Float64
  gap_noise::Float64
  gap_budget::Float64
  mapping::Float64
  map_noise::Float64
  mapping_budget::Float64
  checks::Int
end


"""
    OptimizationResults

Result from plain or accelerated proximal gradient descent. `minimizer` aliases
the caller's coefficient array. `minimum` is the reported objective there.
`iterations` counts steps. `converged` means that a stopping proposal passed
the applicable computed stationarity check. Copy `minimizer` before reusing the
coefficient array for another solve. On the opt-in `IndBallL1` route of
[`NumericalFeasibility`](@ref), `minimum` can be `Inf` or `NaN`, and
`approximate_solution`, `smooth_minimum` and `feasibility` report the route's outcome.

`iteration_converged` reports reaching the iteration limit, not successful
optimization; see [result semantics](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/results-failures/#RES-01).

# Extended help

## Fields to inspect

- `method`, `minimizer`, `minimum`: solver, shared coefficients and objective.
- `iterations`, `iteration_converged`: work completed and whether `maxiter` was reached.
- `converged`, `x_converged`, `f_converged`, `grad_converged`: the final stopping
  flags after the stationarity check; the last three are all false when it fails.
- `x_tol`, `f_tol`, `g_tol`, `x_residual`, `f_residual`, `g_residual`: thresholds
  and reported diagnostics, defined precisely by the stopping contract.
- `f_increased`: whether the last computed objective exceeded its predecessor;
  this can coexist with convergence. The result does not store `allow_f_increases`.
- `trace`: stored iteration states when requested.
- `f_calls`, `grad_calls`, `prox_calls`, `backtrack_steps`: oracle and line-search
  counts. PGD and APG do not count every kind of trial identically.
- `call_limit_reached`: a call limit was reached.
- `stagnated`: the documented Float32 PGD stagnation exit; this is not a
  convergence or accuracy certificate, and other exit flags can also be true.
- `gap`: `NaN`, because this result type does not compute a certified duality gap.
- `approximate_solution`: on the `IndBallL1` route, the full stopping check passed at a point
  classified outside the ball or not classified; `false` on the other routes.
- `smooth_minimum`: the stored, computed smooth loss of the solver's last loss evaluation at
  `minimizer`; on the other routes `minimum` adds the computed penalty value to it.
- `feasibility`: a [`NumericalFeasibilityReport`](@ref) on the `IndBallL1` route, `nothing` on the
  other routes.

On the `IndBallL1` route, `minimum` is the smooth loss when the returned point is classified
inside the ball, `Inf` when it is classified outside and `NaN` when it is not classified (a
convention for the loss plus the ball's indicator, which can differ from ProximalBase's rounded
indicator); the trace's `fg_x` ("Function value"), the callback's objective, `f_residual` and
`f_increased` use the smooth loss, and `allow_f_increases = false` does not end the solve on an
increase. These statements about the returned point assume that callbacks leave the coefficients
unchanged. See
[RES-04](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/results-failures/#RES-04).

For `NormL1`, `ElasticNet` and `GroupNormL2`, the stop check uses the applicable
computed KKT residual; `NormLinf` uses the generic proximal-gradient check.
For the graphical lasso, see the [matrix PGD result fields](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-logdet/#PGD-08).
A small residual does not bound coefficient error on an ill-conditioned design.
With `ftol=0`, `f_converged` is false and the objective residual is reported only.

See [the exact stopping definitions](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-stopping/#STOP-01)
and [results and failure rules](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/results-failures/#RES-01).
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
    approximate_solution::Bool
    smooth_minimum::T
    feasibility::Union{Nothing, NumericalFeasibilityReport}

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
approximate_solution(r::OptimizationResults) = r.approximate_solution
smooth_minimum(r::OptimizationResults) = r.smooth_minimum
feasibility(r::OptimizationResults) = r.feasibility


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
    r.feasibility === nothing || _show_feasibility(io, r)
    @printf io " * Backtracking steps: %d\n" backtrack_steps(r)
    @printf io " * f(x) calls: %d\n" f_calls(r)
    @printf io " * ∇f(x) calls: %d\n" grad_calls(r)
    @printf io " * prox calls: %d\n" prox_calls(r)
    return
end

# The lines of the IndBallL1 route (RES-04), printed when the result carries a feasibility report
function _show_feasibility(io::IO, r::OptimizationResults)
    q = r.feasibility
    @printf io "   * Approximate solution (check passed, not classified inside the ball): %s\n" approximate_solution(r)
    @printf io " * Smooth minimum: %e\n" smooth_minimum(r)
    @printf io " * Numerical feasibility: membership %s, ‖x‖₁ - r = %.2e, cap %.2e\n" q.membership q.margin q.cap
    @printf io "   * support gap %.2e + noise %.2e, budget %.2e\n" q.gap q.gap_noise q.gap_budget
    @printf io "   * mapping %.2e + noise %.2e, budget %.2e\n" q.mapping q.map_noise q.mapping_budget
    @printf io "   * full stopping checks: %d\n" q.checks
    return
end
