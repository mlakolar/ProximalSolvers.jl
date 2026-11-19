# Suppose two algorithms fit the same sparse regression model. One returns quickly,
# but its coefficients are still far from satisfying the optimization conditions.
# Calling it faster would confuse speed with accuracy. This tutorial compares three
# solver configurations after checking their answers on a common scale.
#
# We observe ``y = X\beta^\star + \varepsilon`` with a sparse coefficient vector and
# correlated predictors, and solve the lasso problem
# ```math
# \min_\beta\quad F(\beta) = \frac{1}{2n}\|y-X\beta\|_2^2
#                                  + \lambda\|\beta\|_1.
# ```
# The penalty encourages a small model. Changing the algorithm should change how we
# compute its estimate, rather than change the statistical objective.
#
#md # ![Independent KKT violation and relative objective gap versus measured wall time for three lasso solver configurations; dashed lines mark common accuracy targets.](lasso_solvers.svg)
#
# In the figure, each marker is a **separate solve from zero** at one tolerance setting,
# not a point in one solver's iteration history. The left panel checks stationarity;
# the right checks objective accuracy against a tightly solved reference. A setting
# must lie below both dashed lines to reach the common target. The measured times
# illustrate this experiment; they do not establish a general speed ranking.
#
#md # [Download this example as a Jupyter notebook](@__NAME__.ipynb)
#nb # Plotting cells need Plots in the active environment; the figure appears after the sweep.
#
# ## Why the stopping flags are not enough
#
# Each solver stops by its own rule, documented with `CDSolver` and `ProximalOptions`.
# Coordinate descent measures coefficient changes over a pass; proximal gradient
# descent measures objective, iterate, and gradient/proximal changes. Their tolerances
# are not on a common scale, and `converged` reports the solver's own test rather than
# an independent optimality certificate. We sweep tolerances, check the returned
# coefficients from the data, and report the first setting meeting both accuracy
# targets. The configurations are cyclic coordinate descent without momentum,
# random-order coordinate descent with default momentum and a seeded generator,
# and dense proximal gradient descent.
#
# ## A reproducible correlated-regression experiment
#
# The design has `n = 1000` rows and `p = 200` columns that follow an AR(1) pattern
# with correlation `rho` between neighbouring columns. Twenty coefficients are
# nonzero and the noise has unit variance. The regularization is
# `lambda = lambda_max / 100`, where `lambda_max = maximum(abs, X' * y) / n` is the
# smallest `lambda` at which the zero vector satisfies the KKT conditions of the lasso
# objective below.
using LinearAlgebra, Printf, Random, ProximalBase, ProximalSolvers

rho = 0.9
n, p = 1000, 200
rng = Xoshiro(1)
Z = randn(rng, n, p)
X = similar(Z)
X[:, 1] = Z[:, 1]
for j in 2:p
  X[:, j] = rho * X[:, j-1] + sqrt(1 - rho^2) * Z[:, j]
end
beta0 = zeros(p)
beta0[1:5:100] .= repeat([2, -1.5, 1, -1, 0.8, -0.6, 0.5, -0.4, 0.3, -0.2], 2)
y = X * beta0 + randn(rng, n)

lambda_max = maximum(abs, X' * y) / n
lambda = lambda_max / 100
f = (1 / n) * LeastSquaresLoss(y, X)
g = NormL1(lambda);

# ## What counts as an accurate answer?
#
# The two functions below compute from the problem data `X`, `y`, `n` and `lambda` and
# from the coefficient vector they are given; they use no solver diagnostics, cached
# quantities or reported values. The
# objective is the lasso objective. A KKT residual measures how far the first-order
# optimality conditions are from holding. For a zero coefficient it is the excess of the
# gradient magnitude over `lambda`, and for a nonzero coefficient it is the distance
# of the gradient from `-lambda * sign(beta[j])`. It is divided by `lambda` below.
objective(beta) = sum(abs2, y - X * beta) / (2n) + lambda * sum(abs, beta)

function kktviolation(beta)
  grad = -X' * (y - X * beta) / n
  maximum(j -> iszero(beta[j]) ? max(abs(grad[j]) - lambda, 0.0) :
                                 abs(grad[j] + lambda * sign(beta[j])), eachindex(beta))
end;

# ## Construct a reference estimate
#
# The reference objective value `fstar` comes from cyclic coordinate descent run to
# a very small tolerance with `relative=false`, started from zero. The
# assertions check that its independently measured KKT violation is small and that
# the independent objective matches the objective the solver reports.
reference = zeros(p)
refresult = solve!(reference, f, g,
  CDSolver(order=:cyclic, momentum=false, relative=false, tol=1e-14, maxpasses=1_000_000))
fstar = objective(reference)
@assert refresult.converged
@assert kktviolation(reference) / lambda <= 1e-10
@assert isapprox(fstar, refresult.minimum; rtol=1e-10)

# ## Run the same experiment for each solver
#
# Each run of the sweeps starts from the zero vector. The wall time of a setting is
# the minimum over five timed repetitions of the `solve!` call alone, after one
# warm-up call; the solver object is built before the timer starts. Each random-order
# coordinate descent run gets a new `Xoshiro` generator with the same seed. For each
# setting the sweep records the time, the number of passes (coordinate descent) or
# iterations (proximal gradient descent), the `converged` flag, the relative objective
# gap `(F - fstar) / abs(fstar)` and the KKT violation divided by `lambda`. Coordinate descent is swept over `tol` and proximal gradient
# descent over one scale used for `ftol`, `xtol` and `gradtol` together, with a large
# `maxiter`.
function measure(prepare; repetitions=5)
  besttime = Inf
  beta = zeros(p)
  result = nothing
  for k in 1:repetitions + 1
    run! = prepare()
    beta = zeros(p)
    elapsed = @elapsed result = run!(beta)
    k > 1 && (besttime = min(besttime, elapsed))
  end
  besttime, beta, result
end

function sweep(settings, prepare, work)
  map(settings) do setting
    time, beta, result = measure(() -> prepare(setting))
    (setting = setting, time = time, work = work(result), converged = result.converged,
     gap = (objective(beta) - fstar) / abs(fstar), kkt = kktviolation(beta) / lambda)
  end
end

cdseed = 7
cdtols = 10.0 .^ (-2:-1:-10)
pgdscales = 10.0 .^ (-2:-1:-13)

cyclic = sweep(cdtols,
  tol -> (solver = CDSolver(order=:cyclic, momentum=false, tol=tol);
          beta -> solve!(beta, f, g, solver)),
  result -> result.passes)

randomorder = sweep(cdtols,
  tol -> (solver = CDSolver(order=:random, rng=Xoshiro(cdseed), tol=tol);
          beta -> solve!(beta, f, g, solver)),
  result -> result.passes)

pgd = sweep(pgdscales,
  scale -> (method = ProximalGradientDescent();
            options = ProximalOptions(maxiter=200_000, ftol=scale, xtol=scale, gradtol=scale);
            beta -> solve!(beta, f, g, method, options)),
  result -> result.iterations);

# ## Time to the target accuracy
#
# A setting reaches the target when its relative objective gap is at most `gaptarget`
# and its KKT violation divided by `lambda` is at most `kkttarget`. The time to target
# of a solver is the time of the first setting in its sweep, from the loosest to the
# tightest, that reaches the target. A solver with no such setting is reported as not
# reached. The last column counts the settings in the sweep that the solver flagged
# `converged` while the KKT violation divided by `lambda` exceeded `flagtol`.
gaptarget = 1e-6
kkttarget = 1e-4
flagtol = 1e-3
reached(run) = run.gap <= gaptarget && run.kkt <= kkttarget

sweeps = ["CD, cyclic, no momentum" => (cyclic, "tol", "passes"),
          "CD, random order, default momentum" => (randomorder, "tol", "passes"),
          "Dense proximal gradient descent" => (pgd, "scale", "iterations")]

function tablerow(name, runs, parameter, unit)
  flagged = count(run -> run.converged && run.kkt > flagtol, runs)
  k = findfirst(reached, runs)
  if k === nothing
    @sprintf("| %s | not reached | not reached | not reached | not reached | not reached | %d of %d |",
             name, flagged, length(runs))
  else
    run = runs[k]
    @sprintf("| %s | %s = %.0e | %.2f | %d %s | %.2e | %.2e | %d of %d |",
             name, parameter, run.setting, 1000 * run.time, run.work, unit, run.gap, run.kkt,
             flagged, length(runs))
  end
end

header = ["| Solver | Setting at target | Time to target (ms) | Work at target | Objective gap | KKT/lambda | Settings flagged converged with KKT/lambda > $flagtol |",
          "|:--|:--|--:|--:|--:|--:|--:|"]
table = join(vcat(header, [tablerow(name, runs, parameter, unit)
                           for (name, (runs, parameter, unit)) in sweeps]), "\n");

# The script and the notebook print the table as plain Markdown text. The documentation
# page shows it rendered.
println(table) #!md
#md using Markdown
#md Markdown.parse(table)

# Each solver must reach the target at some setting of its sweep; this checks accuracy
# and says nothing about time.
for (name, (runs, parameter, unit)) in sweeps
  @assert any(reached, runs) "$name does not reach the target in its sweep"
end

# ## Reproduce and interpret the figure
#
# Each line is one solver and each marker one setting of its sweep. The left panel
# shows the KKT violation divided by `lambda` and the right panel the relative
# objective gap, both against the wall time of the setting on logarithmic axes. The
# horizontal lines mark the targets. Values below `1e-16` are drawn at `1e-16`;
# the table and the assertions use the unfloored values. The plotting code is part of
# the documentation page and the notebook and is not run by the plain script.
#!jl using Plots
#!jl plotfloor(v) = max(v, 1e-16)
#!jl kktplot = plot(xscale=:log10, yscale=:log10, xlabel="wall time (s)", ylabel="KKT violation / lambda", legend=false)
#!jl gapplot = plot(xscale=:log10, yscale=:log10, xlabel="wall time (s)", ylabel="relative objective gap", legend=:outerright)
#!jl for (name, (runs, parameter, unit)) in sweeps
#!jl   plot!(kktplot, [run.time for run in runs], [plotfloor(run.kkt) for run in runs];
#!jl         marker=:circle, label=name)
#!jl   plot!(gapplot, [run.time for run in runs], [plotfloor(run.gap) for run in runs];
#!jl         marker=:circle, label=name)
#!jl end
#!jl hline!(kktplot, [kkttarget]; color=:black, linestyle=:dash, label="target")
#!jl hline!(gapplot, [gaptarget]; color=:black, linestyle=:dash, label="target")
#!jl accuracy_plot = plot(kktplot, gapplot; layout=(1, 2), size=(1250, 400), bottom_margin=5Plots.mm, left_margin=5Plots.mm)
#md savefig(accuracy_plot, "lasso_solvers.svg")
#md nothing
#nb display(accuracy_plot)

# ## Limitations of the comparison
#
# Each time above is the minimum of five timed repetitions after a warm-up call. The
# times illustrate how to compare solvers at equal accuracy and are not benchmark
# evidence.
#
#md # The times on this page come from the machine that built the documentation, which
#md # can be a shared continuous-integration runner.
#md # They come from one machine in one run; see [Benchmarks and performance](../../benchmarks.md) for how they differ from the benchmark evidence of the repository.
#nb # The times in this notebook come from the machine that runs its cells.
#
# The random-order timings are for the one seed `cdseed`. The comparison covers this one
# problem, with one correlation level, one `lambda` and one design. Dense proximal
# gradient descent on a `SparseIterate` is not part of it. The last column of the
# table counts, for this problem, the settings whose `converged` flag was set while the
# independent KKT measure was above `flagtol`.
#
# A nearly horizontal objective-gap curve can coexist with a larger KKT residual:
# objective value and stationarity measure different aspects of optimization error.
# Tightening a solver tolerance can increase work without a useful accuracy gain
# once floating-point arithmetic limits the returned answer. Use both panels and the
# table instead of selecting a winner from one low-time marker. The reference itself
# is a numerical fit, not a known exact minimum; very small or negative computed gaps
# can reflect its finite precision. The plot floors gaps for logarithmic display only.
#
# These checks assess optimization, not prediction or variable-selection quality.
# Correlated predictors can make coefficients sensitive even when objective values
# agree closely. Choosing `lambda` and assessing uncertainty require a separate
# statistical analysis. The run excludes other designs, penalty levels, precisions,
# hardware, and solver configurations.
#
# ## What we learned
#
# Compare algorithms on the same objective, starting point, and independently checked
# accuracy target. A solver's stopping flag is useful diagnostic information, but it
# cannot replace that common check. Here the table answers how much measured work
# each configuration needed for this target; a general performance claim needs the
# separate benchmark workflow.
