# When predictors enter in groups, a useful model can select an entire collection
# together: for example, the basis terms describing one nonlinear effect. Group lasso
# expresses that preference. We compare three ways to compute the **same** group-lasso
# estimate, requiring independently checked accuracy before comparing their times.
#
# For a partition ``G_1,\ldots,G_K`` of the predictors, the objective is
# ```math
# \min_\beta\quad F(\beta) = \frac{1}{2n}\|y-X\beta\|_2^2
#                         + \lambda\sum_{k=1}^K w_k\|\beta_{G_k}\|_2.
# ```
# The group norms can set whole groups to zero. Here ``w_k=\sqrt{|G_k|}`` gives
# equally sized groups the same penalty convention. We use block coordinate descent
# (CD), proximal gradient descent (PGD), and accelerated proximal gradient descent
# (APG); no separate statistical estimator is introduced for each algorithm.
#
#md # ![Independent group KKT violation and relative objective gap versus measured wall time for CD, PGD, and APG; dashed lines mark common accuracy targets.](group_lasso_solvers.svg)
#
# Each marker is a separate solve from zero at one tolerance setting. A setting reaches
# the common target only when it is below the dashed line in **both** panels. The
# figure lets us compare accuracy and measured effort in this reproducible experiment;
# it is not an iteration history or evidence of a universal speed advantage.
#
# ## A reproducible grouped-regression experiment

#
# The design has `n = 400` rows and `p = 60` columns with an AR(1) correlation `rho = 0.5` between
# neighbouring columns, split into 15 groups of 4 columns that are not contiguous. Three groups
# hold the signal. The penalty is `GroupNormL2(lambda, groups)` with the default weights
# `sqrt(4) = 2` and `lambda = lambda_max / 10`, where `lambda_max` is the smallest level at which
# the zero vector is a minimizer. We generate ``y=X\beta^\star+\varepsilon`` with
# unit-variance Gaussian noise. The random grouping tests that the methods use group
# membership rather than assume adjacent columns belong together.
using LinearAlgebra, Printf, Random, ProximalBase, ProximalSolvers

rho = 0.5
n, p = 400, 60
rng = Xoshiro(3)
Z = randn(rng, n, p)
X = similar(Z)
X[:, 1] = Z[:, 1]
for j in 2:p
  X[:, j] = rho * X[:, j-1] + sqrt(1 - rho^2) * Z[:, j]
end
order = randperm(rng, p)
groups = [order[4k-3:4k] for k in 1:15]
beta0 = zeros(p)
for k in 1:3
  beta0[groups[k]] .= randn(rng, 4)
end
y = X * beta0 + randn(rng, n)

w = fill(2.0, length(groups))
lambda_max = maximum(k -> norm(X[:, groups[k]]' * y) / n / w[k], eachindex(groups))
lambda = lambda_max / 10
f = (1 / n) * LeastSquaresLoss(y, X)
g = GroupNormL2(lambda, groups);

# ## Check accuracy without trusting the stopping flag
#
# The objective and the group KKT violation below are computed from `X`, `y`, `lambda`, the weights
# and the coefficients alone. For a group at zero the violation is the excess of the norm of the
# gradient block over `lambda * w[k]`; for a nonzero group it is the norm of
# `grad[G] + lambda * w[k] * beta[G] / norm(beta[G])`. These are the first-order
# optimality conditions for the displayed objective. The largest violation, divided
# by `lambda`, provides a common stationarity measure despite the solvers' different
# stopping rules. A solver reporting `converged` does not replace this check.
objective(beta) = sum(abs2, y - X * beta) / (2n) + lambda * sum(k -> w[k] * norm(beta[groups[k]]), eachindex(groups))

function kktviolation(beta)
  grad = X' * (X * beta - y) / n
  maximum(eachindex(groups)) do k
    G = groups[k]
    nb = norm(beta[G])
    iszero(nb) ? max(norm(grad[G]) - lambda * w[k], 0.0) : norm(grad[G] + lambda * w[k] * beta[G] / nb)
  end
end;

# ## Construct a reference estimate
#
# The reference objective `fstar` comes from cyclic block coordinate descent at a very small
# tolerance with `relative = false`. Its independent KKT violation is checked.
xref = BlockIterate(Float64, p, g)
refresult = solve!(xref, f, g, CDSolver(order = :cyclic, relative = false, tol = 1e-14, maxpasses = 1_000_000))
reference = Vector(xref)
fstar = objective(reference)
@assert refresult.converged
@assert kktviolation(reference) / lambda <= 1e-10

# ## Compare solver settings from the same start
#
# Each run starts from zero. The time of a setting is the minimum over three timed calls after
# one warm-up call; a timed call allocates the starting iterate, calls `solve!` and, for coordinate
# descent, converts the `BlockIterate` result to a `Vector`, so these costs are included. Coordinate descent is swept over `tol`, and proximal gradient
# descent, plain and accelerated, over one scale used for `xtol` and `gradtol` (with `ftol = 0`).
function measure(run!; repetitions = 3)
  besttime, beta, result = Inf, zeros(p), nothing
  for k in 1:repetitions + 1
    elapsed = @elapsed (beta, result) = run!()
    k > 1 && (besttime = min(besttime, elapsed))
  end
  besttime, beta, result
end

function sweep(settings, runner, work)
  map(settings) do setting
    time, beta, result = measure(runner(setting))
    (setting = setting, time = time, work = work(result), converged = result.converged,
     gap = (objective(beta) - fstar) / abs(fstar), kkt = kktviolation(beta) / lambda)
  end
end

cdruns = sweep(10.0 .^ (-3:-1:-9),
  tol -> (solver = CDSolver(order = :cyclic, tol = tol);
          () -> (x = BlockIterate(Float64, p, g); r = solve!(x, f, g, solver); (Vector(x), r))),
  result -> result.passes)

gradientruns(method) = sweep(10.0 .^ (-3:-1:-11),
  scale -> (options = ProximalOptions(maxiter = 100_000, ftol = 0, xtol = scale, gradtol = scale);
            () -> (beta = zeros(p); r = solve!(beta, f, g, method, options); (beta, r))),
  result -> result.iterations)

pgdruns = gradientruns(ProximalGradientDescent())
apgruns = gradientruns(AccProxGradDescent());

# ## Time to the target accuracy
#
# A setting reaches the target when its relative objective gap is at most `gaptarget` and its
# KKT violation divided by `lambda` is at most `kkttarget`; the time to target of a solver is that of
# the first such setting in its sweep, from the loosest to the tightest.
gaptarget = 1e-6
kkttarget = 1e-4
reached(run) = run.gap <= gaptarget && run.kkt <= kkttarget

sweeps = ["CD on a BlockIterate, cyclic" => (cdruns, "tol", "passes"),
          "PGD on a dense Vector" => (pgdruns, "scale", "iterations"),
          "APG on a dense Vector" => (apgruns, "scale", "iterations")]

function tablerow(name, runs, parameter, unit)
  k = findfirst(reached, runs)
  k === nothing && return @sprintf("| %s | not reached | not reached | not reached | not reached | not reached |", name)
  run = runs[k]
  @sprintf("| %s | %s = %.0e | %.2f | %d %s | %.2e | %.2e |",
           name, parameter, run.setting, 1000 * run.time, run.work, unit, run.gap, run.kkt)
end

table = join(vcat(["| Solver | Setting at target | Time to target (ms) | Work at target | Objective gap | KKT/lambda |",
                   "|:--|:--|--:|--:|--:|--:|"],
                  [tablerow(name, runs, parameter, unit) for (name, (runs, parameter, unit)) in sweeps]), "\n");

# The script prints the table as plain Markdown text; the documentation page shows it rendered.
println(table) #!md
#md using Markdown
#md Markdown.parse(table)

# Each solver must reach the target at some setting of its sweep; this checks accuracy and says
# nothing about time.
for (name, (runs, parameter, unit)) in sweeps
  @assert any(reached, runs) "$name does not reach the target in its sweep"
end

# ## Reproduce and interpret the figure
#
# The left panel plots the independent group KKT residual divided by `lambda`; the
# right plots relative objective gap. Both use logarithmic time and accuracy scales.
# Values below `1e-16` are drawn at that floor so they can appear on a logarithmic axis;
# the table and assertions use the original values. A small or negative objective gap
# can reflect rounding or the finite accuracy of the numerical reference.
# Plot generation runs in the documentation environment. Ordinary script execution
# and the examples test runner compute the table and assertions without loading Plots.
#!jl using Plots
#!jl plotfloor(v) = max(v, 1e-16)
#!jl kktplot = plot(xscale=:log10, yscale=:log10, xlabel="wall time (s)",
#!jl   ylabel="group KKT violation / lambda", legend=false)
#!jl gapplot = plot(xscale=:log10, yscale=:log10, xlabel="wall time (s)",
#!jl   ylabel="relative objective gap", legend=:outerright)
#!jl for (name, (runs, parameter, unit)) in sweeps
#!jl   plot!(kktplot, [run.time for run in runs], [plotfloor(run.kkt) for run in runs];
#!jl     marker=:circle, label=name)
#!jl   plot!(gapplot, [run.time for run in runs], [plotfloor(run.gap) for run in runs];
#!jl     marker=:circle, label=name)
#!jl end
#!jl hline!(kktplot, [kkttarget]; color=:black, linestyle=:dash, label="target")
#!jl hline!(gapplot, [gaptarget]; color=:black, linestyle=:dash, label="target")
#!jl accuracy_plot = plot(kktplot, gapplot; layout=(1, 2), size=(1250, 400),
#!jl   bottom_margin=5Plots.mm, left_margin=5Plots.mm)
#md savefig(accuracy_plot, "group_lasso_solvers.svg")
#md nothing
#nb display(accuracy_plot)
#
# A solver can have a small objective gap before its KKT residual is equally small.
# Read the two panels together: one summarizes objective quality, the other checks
# stationarity. The table identifies the first tested setting satisfying both targets,
# rather than assuming that equal tolerance values mean equal accuracy.
#
# ## Limitations of the comparison
#
# The times illustrate how to compare the solvers at equal accuracy on this one problem, one
# design and one `lambda`; they come from one machine in one run and are not benchmark evidence
# (see [Benchmarks and performance](../../benchmarks.md)). A CD pass and a PGD iteration are
# different units of work: a full pass visits each group once and an active pass the active groups,
# while a PGD or APG iteration forms products with `X` and its transpose (more of them when its line
# search rejects a trial).
#
# The timing protocol here includes starting-iterate allocation and CD's conversion
# back to a dense vector. The [lasso comparison](lasso_solvers.md) times `solve!` alone,
# so times from those two pages should not be read as a comparison of the two models.
# This experiment uses Float64, one seed, one correlation pattern, equally sized
# groups, and one penalty level. Additional seeds, data geometries, and machines can
# change the measured ordering. A good optimization result also does not prove that
# the selected groups are scientifically correct: noise, correlated predictors, and
# the chosen penalty affect support recovery.
#
# ## What we learned
#
# Group structure changes the penalty and its KKT conditions; it does not require
# a separate objective for every solver. We can compare CD, PGD, and APG by computing
# that objective and group residual from each returned fit. Equal independently
# checked accuracy makes the reported effort interpretable, while broader performance
# claims belong in a controlled benchmark study.
