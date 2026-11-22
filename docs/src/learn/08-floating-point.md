# [When floating point breaks the textbook](@id learn-08)

**Prerequisites:** [KKT checks](@ref learn-02), [coordinate descent](@ref learn-06)
and [duality gaps](@ref learn-07).

After this chapter you can:

- Separate a stopping decision from the accuracy of the returned coefficients.
- Recognize underflow, cancellation and an unsuitable warm-start scale.
- Recompute a diagnostic from the original data at higher precision.

The earlier derivations use exact arithmetic. A computer stores finite-precision
numbers and evaluates a particular sequence of operations. The four small cases
below come from the package's documented limits. They are demonstrations of
mechanisms, not estimated failure rates for ordinary regression problems.
The authoritative numerical scope is [the working-precision contract](@ref FP-01).

## Case 1: a stopping flag and a coefficient error answer different questions

On an orthogonal design, the lasso solution is available by hand. Compare it
with a default PGD solve and a tighter solve. This makes numerical error visible
without trusting either run as a reference for the other.

~~~@example learn_default_stop
using LinearAlgebra, ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
s, lambda = 1 / length(y), 1.0
analytic = [0.0, -0.25]
function compare_to_analytic(options)
    beta = zeros(2)
    result = solve!(beta, s * LeastSquaresLoss(y, X), NormL1(lambda),
                    ProximalGradientDescent(), options)
    gradient = s * X' * (X * beta - y)
    kkt = maximum(iszero(beta[j]) ? max(abs(gradient[j])-lambda, 0.0) :
        abs(gradient[j]+lambda*sign(beta[j])) for j in eachindex(beta))
    (; converged=result.converged, coefficient_error=maximum(abs, beta-analytic),
       kkt, objective_increased=result.f_increased)
end
default_check = compare_to_analytic(ProximalOptions())
tighter_check = compare_to_analytic(ProximalOptions(maxiter=2000,
    ftol=1e-14, xtol=1e-12, gradtol=1e-10, allow_f_increases=true))
(; default_check, tighter_check)
~~~

The returned flag describes [the implemented stopping rules](@ref STOP-01).
It does not assert that every coefficient equals the exact solution. Near an
optimum, the true objective improvement can also be smaller than evaluation
rounding, so the computed objective may increase by a tiny amount. The final
bits can depend on the arithmetic path. Enabling objective increases changes
that stopping policy; it does not itself certify a fit.

**What to check:** compare with an analytic solution when one is available;
otherwise evaluate independent KKT conditions or a suitable duality gap.

## Case 2: scaling after a product cannot restore lost information

All the inputs below are ordinary finite Float64 numbers. The individual
products forming `X'*y` are too small to survive in Float64. A large loss scale
applied afterwards cannot recover the information already lost. This order of
arithmetic is documented in [the working-precision contract](@ref FP-01).

~~~@example learn_underflow
using LinearAlgebra, ProximalBase, ProximalSolvers
X = fill(2.0^-500, 2, 1)
y = fill(2.0^-700, 2)
s, lambda = 2.0^300, 2.0^-902
computed_correlation = dot(vec(X), y)
reference = setprecision(BigFloat, 256) do
    column, response = BigFloat.(vec(X)), BigFloat.(y)
    scale, level = BigFloat(s), BigFloat(lambda)
    q, a = scale * dot(column, response), scale * sum(abs2, column)
    beta_star = (q - level) / a
    objective(b) = scale * sum(abs2, response-column*b) / 2 + level * abs(b)
    (; beta_star, objective_at_zero=objective(BigFloat(0)),
       optimum=objective(beta_star))
end
runs = map((CDSolver(order=:cyclic, momentum=false),
            ProximalGradientDescent(), AccProxGradDescent())) do solver
    beta = zeros(1)
    result = solve!(beta, s * LeastSquaresLoss(y, X), NormL1(lambda), solver)
    (method=string(nameof(typeof(solver))), coefficient=beta[1], converged=result.converged)
end
(; computed_correlation, exact_solution=Float64(reference.beta_star), runs,
   relative_objective_excess_at_zero=Float64(
       (reference.objective_at_zero-reference.optimum)/reference.optimum))
~~~

The reference calculation converts the original inputs before forming products.
Converting the already computed zero correlation to BigFloat would preserve
zero and miss the problem. In this one-dimensional example the analytic
soft-threshold formula supplies the reference solution.

**What to check:** identify where intermediate products are formed; inspect
the data and loss scales; use higher-precision evaluation from the original
inputs when validating a result. Tightening a stop cannot reconstruct a
product that was already rounded away.

## Case 3: cancellation can hide a correlation

The exact sum `1 + d - 1` is `d`. A sequential floating-point evaluation can
lose `d` when it is added to one. Here that small correlation is all that makes
the minimizer nonzero, and the KKT residual below is measured relative to it.
Different reduction implementations can
change the observed last bits, so the block reports what the running platform
does rather than asserting a particular reduction order.

~~~@example learn_cancellation
using LinearAlgebra, ProximalBase, ProximalSolvers
for T in (Float64, Float32)
    d = eps(T) / 2
    X = reshape(T[1, d, -1], 3, 1)
    y = ones(T, 3)
    lambda = d / 8
    exact_correlation = setprecision(BigFloat, 256) do
        dot(BigFloat.(vec(X)), BigFloat.(y))
    end
    for solver in (CDSolver(order=:cyclic, momentum=false),
                   ProximalGradientDescent(), AccProxGradDescent())
        beta = zeros(T, 1)
        result = solve!(beta, LeastSquaresLoss(y, X), NormL1(lambda), solver)
        relative_kkt = setprecision(BigFloat, 256) do
            column, response = BigFloat.(vec(X)), BigFloat.(y)
            b, level = BigFloat(beta[1]), BigFloat(lambda)
            gradient = dot(column, column*b-response)
            residual = iszero(b) ? max(abs(gradient)-level, BigFloat(0)) :
                abs(gradient+level*sign(b))
            residual / exact_correlation
        end
        println((precision=T, method=string(nameof(typeof(solver))),
                 computed_correlation=dot(vec(X), y),
                 exact_correlation=Float64(exact_correlation),
                 coefficient=beta[1], converged=result.converged,
                 relative_kkt=Float64(relative_kkt)))
    end
end
~~~

A residual can be large relative to this tiny correlation while the objective
error is small relative to the whole objective. These are different accuracy
questions. The limitation and the relation to the computed stationarity check
are described in [working precision](@ref FP-01) and [stopping](@ref STOP-01).

**What to check:** report both the absolute diagnostic and the scale used to
normalize it. Reusing the same rounded product in a second check does not make
that check independent of the original arithmetic error.

## Case 4: a large cancelling warm start can prevent movement

A warm start is useful only if its numerical scale is sensible. Here two huge
coefficients cancel in the prediction. The corrections needed to reach the
small solution can be too small to change either stored coefficient. A full
pass can therefore make no representable progress. The scalar solver's
change test and limitation are specified in [the CD contract](@ref CD-01).

~~~@example learn_warm_start
using LinearAlgebra, ProximalBase, ProximalSolvers
X = ones(1, 2)
y = [1 / 64]
lambda = 1 / 1024
solver = CDSolver(order=:cyclic, momentum=false)
starts = (warm=[2.0^49, -2.0^49], cold=zeros(2))
checks = map(collect(pairs(starts))) do (name, start)
    beta = copy(start)
    result = solve!(beta, LeastSquaresLoss(y, X), NormL1(lambda), solver)
    relative_excess = setprecision(BigFloat, 256) do
        matrix, response = BigFloat.(X), BigFloat.(y)
        level = BigFloat(lambda)
        objective(b) = sum(abs2, response-matrix*b)/2 + level*sum(abs, b)
        optimum_beta = [response[1]-level, BigFloat(0)]
        optimum = objective(optimum_beta)
        (objective(BigFloat.(beta))-optimum)/optimum
    end
    (start=name, unchanged=beta == start, converged=result.converged,
     coefficients=beta, relative_objective_excess=Float64(relative_excess))
end
checks
~~~

The independent reference uses the fact that a nonnegative total coefficient
`beta[1]+beta[2]` can be assigned to one coordinate at minimum L1 cost. Its
optimal total is `y[1]-lambda` for these inputs. Both the warm and cold outputs
are judged against that same analytic optimum.

**What to check:** compare plausible starts, examine coefficient scale, and
recompute `y-X*beta` independently. A stationary cache or an unchanged vector
does not by itself establish objective accuracy.

## Exercises

1. Why does converting `dot(X[:,1], y)` to BigFloat after it is computed not
   repair the underflow example?
2. **Coding:** rerun the warm-start case at several powers of two, and compare
   its `solve!` output with the cold start and the analytic reference.
3. **Coding:** compute both absolute and relative KKT residuals for the
   cancellation case. Explain how a large relative residual can coexist with
   a very small absolute discrepancy.
4. Which of the four cases could be diagnosed by recomputing the objective
   alone? Which also require checking gradients, coefficients or intermediate
   scales?

## Exercise answers

1. The conversion receives the rounded result. Higher-precision arithmetic
   must start from the original inputs before the information is lost.
2. Record the observed transition; it depends on representable spacing and
   the implemented arithmetic. A larger starting coefficient need not mean a
   larger representable correction. Keep the same data and penalty throughout.
3. The denominator is the tiny exact correlation. State both numerator and
   denominator to make the comparison interpretable.
4. An independently evaluated objective against the known reference exposes
   the warm-start and underflow failures. The cancellation example shows why
   an objective-relative target can be satisfied while a gradient-relative
   target is not. The analytic coefficient check also answers a question that
   a stopping flag or recent objective change cannot settle.

Return to [reading solver results](../working-with-results.md) for everyday
interpretation, or consult [the contracts](../contracts/index.md) for the full
rules and evidence.
