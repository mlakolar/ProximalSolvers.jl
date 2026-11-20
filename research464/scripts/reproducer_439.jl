# Reproducer for the shared PGD/APG stopping-scale limitation (STOP-03), PR #439 review finding B4.
# An extreme penalty weight on one coordinate makes S = max(λ maxⱼ wⱼ, ‖∇f(0)‖∞) huge, so the stationarity
# threshold τS is vacuous for the free (zero-weight) coordinates. The evidence printed below is computed in
# BigFloat from the raw data and the analytic minimizer; it does not use the solver's oracles.
# Run from the package root: julia --project=. reproducer.jl
using LinearAlgebra, Printf, ProximalBase, ProximalSolvers

setprecision(BigFloat, 256)
sigmoid(t) = t >= 0 ? inv(1 + exp(-t)) : (e = exp(t); e / (1 + e))
softplus(t) = t > 0 ? t + log1p(exp(-t)) : log1p(exp(t))
const TAU = max(ProximalOptions().gradtol, 64 * eps())
const LAMBDA = 1e300

# value(v) and gradient(v) of the smooth loss in BigFloat; bstar the analytic minimizer (BigFloat); free = the
# zero-weight coordinates
function report(label, X, y, w, b, r, value, gradient, bstar)
  A = big.(X)
  zero_b = zeros(BigFloat, size(X, 2))
  S = max(LAMBDA * maximum(w), Float64(norm(gradient(zero_b), Inf)))
  F(v) = value(v) + big(LAMBDA) * sum(big.(w) .* abs.(big.(v)))
  Fb, Fstar = F(big.(b)), F(bstar)
  free = findall(iszero, w)
  g, g0 = gradient(big.(b))[free], gradient(zero_b)[free]
  println("== ", label, " (Julia ", VERSION, ")")
  @printf("  solver: converged = %s, iterations = %d, f_calls = %d, minimum = %.10g\n",
          r.converged, r.iterations, r.f_calls, r.minimum)
  println("  returned b      = ", b)
  println("  analytic b*     = ", Float64.(bstar))
  @printf("  max |X b - X b*| (predictors) = %.3e\n", Float64(maximum(abs, A * big.(b) - A * bstar)))
  @printf("  objective F(b) = %.10f, F(b*) = %.10f, gap = %.3e (relative %.3e)\n",
          Float64(Fb), Float64(Fstar), Float64(Fb - Fstar), Float64((Fb - Fstar) / Fstar))
  @printf("  free-coordinate KKT max|df/db_free| = %.3e = %.3e of its value at zero (%.3e)\n",
          Float64(maximum(abs, g)), Float64(maximum(abs, g) / maximum(abs, g0)), Float64(maximum(abs, g0)))
  @printf("  stopping scale S = %.3e, threshold tau*S = %.3e (tau = %.1e)\n", S, TAU * S, TAU)
end

# Logistic case (the review's example): column 1 is a constant free intercept column, column 2 is zero with an
# extreme weight. The minimizer has b₂ = 0 and the predictor logit(ȳ) = log 4 (four ones out of five).
function logistic_case()
  X, y, w = [fill(1e150, 5) zeros(5)], [0.0, 1.0, 1.0, 1.0, 1.0], [0.0, 1.0]
  s = big.(1 .- 2 .* y)
  value(v) = sum(softplus.(s .* (big.(X) * v)))
  gradient(v) = big.(X)' * (s .* sigmoid.(s .* (big.(X) * v)))
  b = zeros(2)
  r = solve!(b, LogisticLoss(y, X), NormL1(LAMBDA, w), ProximalGradientDescent())
  report("logistic, ProximalGradientDescent, default options", X, y, w, b, r, value, gradient,
         [log(big(4)) / big(1e150), big(0)])
end

# Weighted least squares, f(b) = ½‖y - X b‖², with the free columns of X and one zero column with an extreme
# weight. The minimizer has a zero last coefficient and least-squares coefficients on the free columns.
function least_squares_case(label, X, y, w, method)
  value(v) = sum(abs2, big.(y) - big.(X) * v) / 2
  gradient(v) = big.(X)' * (big.(X) * v - big.(y))
  free = findall(iszero, w)
  A = big.(X[:, free])
  bstar = zeros(BigFloat, size(X, 2))
  bstar[free] = (A' * A) \ (A' * big.(y))
  b = zeros(size(X, 2))
  r = solve!(b, LeastSquaresLoss(y, X), NormL1(LAMBDA, w), method)
  report("weighted least squares, $label, $(summary(method)), default options", X, y, w, b, r, value, gradient, bstar)
end

logistic_case()
y = [0.0, 1.0, 1.0, 1.0, 1.0]
for method in (ProximalGradientDescent(), AccProxGradDescent())
  least_squares_case("one free column", [fill(1e150, 5) zeros(5)], y, [0.0, 1.0], method)
  least_squares_case("two free columns", [fill(1e150, 5) 1e150 .* collect(1.0:5.0) zeros(5)], y, [0.0, 0.0, 1.0], method)
end
