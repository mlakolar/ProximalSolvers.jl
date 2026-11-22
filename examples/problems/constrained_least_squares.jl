# Fit a linear model by minimizing the mean squared residual divided by two,
# subject to bounds on the coefficients.
#
#md # ![Unrestricted, clipped and constrained coefficients for a correlated design.](constrained_least_squares.svg)

using LinearAlgebra, Printf, Random, ProximalBase, ProximalSolvers

# ## Box-constrained least squares
#
# ```math
# \min_{\ell\leq\beta\leq u} \frac{1}{2n}\|X\beta-y\|_2^2.
# ```
#
# Projection onto the box clamps each coefficient to its interval. If the
# columns of `X` are orthogonal and have positive norms, the least-squares
# objective separates by coordinate, so clamping the unrestricted minimizer
# solves the constrained problem. For correlated columns, the off-diagonal
# entries of `X'X` couple the coefficients.

# For the projected-gradient diagnostic, use the inverse Frobenius
# curvature bound as a fixed positive step. It depends only on the design.
# A zero mapping is the first-order condition.
function constrained_fit(label, X::Matrix{T}, y, indicator, project, start, reference) where T
  A, b = Float64.(X), Float64.(y)
  n = length(b)
  t = n / sum(abs2, A)
  objective(v) = sum(abs2, A * v - b) / (2n)
  reference_objective = objective(reference)
  tolerance = T === Float32 ? 2e-4 : 2e-7
  options = ProximalOptions(maxiter=5000, ftol=eps(T), xtol=1e-12,
    gradtol=T === Float32 ? 1e-5 : 1e-10, allow_f_increases=true)
  f = inv(T(n)) * LeastSquaresLoss(y, X)
  fits = map((ProximalGradientDescent(), AccProxGradDescent())) do method
    beta = copy(start)
    fit = solve!(beta, f, indicator, method, options)
    v = Float64.(beta)
    gradient = A' * (A * v - b) / n
    violation = norm(v - project(v), Inf)
    stationarity = norm(v - project(v - t * gradient), Inf) / t
    value = objective(v)
    @assert fit.minimizer === beta
    @assert violation <= 8eps(T) * max(1, norm(v, Inf))
    @assert stationarity <= tolerance
    @assert norm(v - reference, Inf) <= tolerance
    @assert isapprox(value, reference_objective; atol=tolerance, rtol=0)
    @assert isapprox(value, fit.minimum; atol=tolerance, rtol=0)
    @printf("%s | %s | objective %.8g | feasibility %.2e | KKT mapping %.2e\n",
      label, summary(method), value, violation, stationarity)
    beta
  end
  fits
end

# The data here are of order one, and the tolerances leave room for rounding
# in the solves and stopping criteria. The diagnostic uses Float64 arithmetic
# for both working types. Its projection is the mathematical formula.
#
# In the exact control, ``X=\sqrt{n}I_4`` and ``y=Xa``, so the loss is
# ``\|\beta-a\|_2^2/2``. The first box has asymmetric scalar bounds. The
# second has coordinatewise bounds and fixes the fourth coefficient at zero.
X_exact = Matrix(2.0I, 4, 4)
a = [2.0, -2.0, 0.25, 1.0]
for (lower, upper) in ((-0.5, 1.0), ([-0.5, -1.0, -1.0, 0.0], [1.0, 0.0, 2.0, 0.0]))
  project = v -> clamp.(v, lower, upper)
  constrained_fit("Orthogonal box", X_exact, X_exact * a, IndBox(lower, upper),
    project, zeros(4), project(a))
end

# For the correlated case, use a seeded, strictly diagonally dominant design.
# Build a response with a known optimum at `beta_ref`. The loss gradient
# there is negative on the first coordinate at its upper bound, positive on
# the second at its lower bound, and zero at the other coordinates. These
# signs certify optimality for the box, and full column rank gives uniqueness.
rng = Xoshiro(422)
X = X_exact + 0.1 * rand(rng, 4, 4)
box_ref = [1.0, -0.5, 0.25, 0.0]
gradient_ref = [-1.0, 1.0, 0.0, 0.0]
y_box = X * box_ref - X' \ (4 * gradient_ref)
box_project(v) = clamp.(v, -0.5, 1.0)
clipped = box_project(X \ y_box)
@assert norm(clipped - box_ref, Inf) > 0.01
box_beta, _ = constrained_fit("Correlated box", X, y_box, IndBox(-0.5, 1.0),
  box_project, zeros(4), box_ref)

# ## Euclidean-ball-constrained least squares
#
# The constraint ``\|\beta\|_2 \leq r`` bounds the total Euclidean size
# of the coefficients. Projection leaves an interior point unchanged and
# radially scales an exterior point to norm ``r``. For the orthogonal
# control this gives the constrained solution directly. With correlated
# columns the solver applies that same projection to successive gradient
# trials. A single projection of the unrestricted fit generally gives a
# different point because the least-squares level sets are ellipsoids.
#
# Use a radius with the same floating-point type as the four coefficients.
# See the [input contract](@ref IN-08) for the projection's numerical range.

function radial_projection(v, radius)
  magnitude = norm(v)
  return iszero(magnitude) ? copy(v) : min(1, radius / magnitude) * v
end

for T in (Float64, Float32)
  design, target = T.(X_exact), T.(a)
  for radius in (one(T), T(4))
    project = v -> radial_projection(v, radius)
    constrained_fit("Orthogonal Euclidean ball, $T radius $radius",
      design, design * target, IndBallL2(radius), project, zeros(T, 4), project(a))
  end
end

# For the correlated active case, prescribe a unit-norm solution and a
# gradient of ``-2\beta_* `` there. This satisfies the normal-cone condition
# with a positive multiplier. The independent reference follows from this
# condition and the full rank of the design.
ball_ref = [0.6, -0.8, 0.0, 0.0]
y_ball = X * ball_ref + X' \ (8 * ball_ref)
ball_project(v) = radial_projection(v, 1.0)
constrained_fit("Correlated Euclidean ball", X, y_ball, IndBallL2(1.0),
  ball_project, zeros(4), ball_ref)

# ## Infinity-ball-constrained least squares
#
# With the same loss and ``\|\beta\|_\infty \leq r``, each coordinate lies
# in ``[-r,r]``. `IndBallLinf(r)` constructs that symmetric box. A
# `NormLinf(lambda)` penalty instead adds ``\lambda\|\beta\|_\infty`` to the
# objective and has no hard upper bound. Its parameter prices coefficient
# magnitude, whereas the radius sets a maximum allowed magnitude.
#
# For the orthogonal control the independent answer is `clamp.(a, -r, r)`.
# The radius of one is active. The radius of three leaves the unrestricted
# minimizer feasible.
for radius in (1.0, 3.0)
  project = v -> clamp.(v, -radius, radius)
  constrained_fit("Infinity ball, radius $radius", X_exact, X_exact * a, IndBallLinf(radius),
    project, zeros(4), project(a))
end

# ## ℓ1-ball-constrained least squares
#
# The constraint ``\|\beta\|_1 \leq r`` bounds the sum of the coefficient
# magnitudes. Projection onto this ball soft-thresholds an exterior point at
# the level that brings its ℓ1 norm to ``r``, so small coefficients become
# exactly zero. ProximalBase's `IndBallL1(r)` is the indicator of the ball.
#
# PGD and APG accept `IndBallL1` only on an opt-in numerical route: pass
# `feasibility = NumericalFeasibility()` to `solve!`; without it, `solve!`
# refuses the indicator. A rounded projection can land slightly outside the
# ball. The route accepts a trial when its ℓ1 norm, summed in `Float64`, is
# below ``r`` plus a small numerical cap by more than a rounding allowance.
# It reports success only when a full check of a support gap and of a
# fixed-step projected-gradient mapping passes: `converged = true` when the
# returned point is classified inside the ball, and
# `approximate_solution = true` when it is classified outside or is not
# classified; then `minimum` is `Inf` or `NaN`, and `smooth_minimum` is the
# loss. The classification, the margin ``\|\beta\|_1 - r`` and the cap are in
# `fit.feasibility`. See [IN-12](@ref) and [RES-04](@ref).
#
# The independent check below projects onto the ball by the sorted-threshold
# formula in `Float64` and forms the same projected-gradient mapping as for
# the other constraints. The ℓ1 norm of the returned point is summed in
# `BigFloat`.

function l1_projection(v, radius)
  sum(abs, v) <= radius && return copy(v)
  m = sort(abs.(v); rev=true)
  total = zero(eltype(v))
  for k in eachindex(m)
    total += m[k]
    threshold = (total - radius) / k
    if k == length(m) || threshold >= m[k+1]
      return sign.(v) .* max.(abs.(v) .- threshold, 0)
    end
  end
end

function l1_ball_fit(label, X::Matrix{T}, y, radius::T, reference) where T
  A, b = Float64.(X), Float64.(y)
  n = length(b)
  t = n / sum(abs2, A)
  tolerance = T === Float32 ? 2e-4 : 2e-7
  f = inv(T(n)) * LeastSquaresLoss(y, X)
  map((ProximalGradientDescent(), AccProxGradDescent())) do method
    beta = zeros(T, 4)
    fit = solve!(beta, f, IndBallL1(radius), method, ProximalOptions(maxiter=2000);
      feasibility=NumericalFeasibility())
    report = fit.feasibility
    v = Float64.(beta)
    gradient = A' * (A * v - b) / n
    stationarity = norm(v - l1_projection(v - t * gradient, Float64(radius)), Inf) / t
    excess = sum(abs, big.(beta)) - big(radius)
    @assert fit.converged || fit.approximate_solution
    @assert fit.converged == (report.membership === :inside)
    @assert excess <= report.cap
    @assert stationarity <= tolerance
    @assert norm(v - reference, Inf) <= tolerance
    @printf("%s | %s | converged %s | approximate %s | membership %s | ‖β‖₁ - r %.1e | KKT mapping %.2e\n",
      label, summary(method), fit.converged, fit.approximate_solution, report.membership,
      Float64(excess), stationarity)
    beta
  end
end

# When the solution lies on the boundary of the ball, the ℓ1 norm of the
# returned point can be within the rounding allowance of ``r``. The point is
# then not classified, and the fit reports `approximate_solution = true`
# rather than `converged = true`, although the check passed.
#
# For the orthogonal control the constrained minimizer is the projection of
# `a`, whose ℓ1 norm is 5.25, onto the ball of radius 2.5.
for T in (Float64, Float32)
  design, target = T.(X_exact), T.(a)
  l1_ball_fit("Orthogonal ℓ1 ball, $T", design, design * target, T(2.5),
    l1_projection(Float64.(target), 2.5))
end

# For the correlated case, prescribe the solution `l1_ref`, with ℓ1 norm one,
# and the loss gradient `-[1, -1, -0.5, 0.25]` there. With multiplier one this
# is the normal-cone condition of the ball: on the support each gradient entry
# is minus the sign of the coefficient, and off it each has magnitude at most
# one. Full column rank makes the solution unique.
l1_ref = [0.6, -0.4, 0.0, 0.0]
y_l1 = X * l1_ref + 4 * (X' \ [1.0, -1.0, -0.5, 0.25])
l1_ball_fit("Correlated ℓ1 ball, Float64", X, y_l1, 1.0, l1_ref)
l1_ball_fit("Correlated ℓ1 ball, Float32", Float32.(X), Float32.(y_l1), 1.0f0, l1_ref)

#!jl using Plots
#!jl p = bar(1:4, hcat(X \ y_box, clipped, box_beta);
#!jl   label=["Unrestricted" "Clipped" "Joint box fit"], color=[:gray65 :orange :teal],
#!jl   xlabel="Coefficient", ylabel="Estimate", xticks=1:4, legend=:outertop, legendcolumns=3)
#!jl savefig(p, "constrained_least_squares.svg")
#!jl nothing
