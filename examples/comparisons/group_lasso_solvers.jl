# This example compares block coordinate descent (`CDSolver` on a `BlockIterate`) and proximal
# gradient descent (`ProximalGradientDescent` on a dense `Vector`) on one seeded group lasso, by
# the time each needs to reach the same accuracy. As in
# [Lasso: solvers at equal accuracy](lasso_solvers.md), the accuracy is computed from the problem
# data and the returned coefficients, not read from the solvers, and each solver is run over a
# sweep of tolerances.
#
# ## The problem
#
# The design has `n = 400` rows and `p = 60` columns with an AR(1) correlation `rho = 0.5` between
# neighbouring columns, split into 15 groups of 4 columns that are not contiguous. Three groups
# hold the signal. The penalty is `GroupNormL2(lambda, groups)` with the default weights
# `sqrt(4) = 2` and `lambda = lambda_max / 10`, where `lambda_max` is the smallest level at which
# the zero vector is a minimizer.
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

# ## Independent measures
#
# The objective and the group KKT violation below are computed from `X`, `y`, `lambda`, the weights
# and the coefficients alone. For a group at zero the violation is the excess of the norm of the
# gradient block over `lambda * w[k]`; for a nonzero group it is the norm of
# `grad[G] + lambda * w[k] * beta[G] / norm(beta[G])`. It is divided by `lambda` below.
objective(beta) = sum(abs2, y - X * beta) / (2n) + lambda * sum(k -> w[k] * norm(beta[groups[k]]), eachindex(groups))

function kktviolation(beta)
  grad = X' * (X * beta - y) / n
  maximum(eachindex(groups)) do k
    G = groups[k]
    nb = norm(beta[G])
    iszero(nb) ? max(norm(grad[G]) - lambda * w[k], 0.0) : norm(grad[G] + lambda * w[k] * beta[G] / nb)
  end
end;

# ## Reference solution
#
# The reference objective `fstar` comes from cyclic block coordinate descent at a very small
# tolerance with `relative = false`. Its independent KKT violation is checked.
xref = BlockIterate(Float64, p, g)
refresult = solve!(xref, f, g, CDSolver(order = :cyclic, relative = false, tol = 1e-14, maxpasses = 1_000_000))
reference = Vector(xref)
fstar = objective(reference)
@assert refresult.converged
@assert kktviolation(reference) / lambda <= 1e-10

# ## Sweeps
#
# Each run starts from zero. The time of a setting is the minimum over three timed calls after
# one warm-up call; a timed call allocates the starting iterate, calls `solve!` and, for coordinate
# descent, converts the `BlockIterate` result to a `Vector`, so these costs are included. Coordinate descent is swept over `tol`, and proximal gradient
# descent over one scale used for `xtol` and `gradtol` (with `ftol = 0`).
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

pgdruns = sweep(10.0 .^ (-3:-1:-11),
  scale -> (options = ProximalOptions(maxiter = 100_000, ftol = 0, xtol = scale, gradtol = scale);
            () -> (beta = zeros(p); r = solve!(beta, f, g, ProximalGradientDescent(), options); (beta, r))),
  result -> result.iterations);

# ## Time to the target accuracy
#
# A setting reaches the target when its relative objective gap is at most `gaptarget` and its
# KKT violation divided by `lambda` is at most `kkttarget`; the time to target of a solver is that of
# the first such setting in its sweep, from the loosest to the tightest.
gaptarget = 1e-6
kkttarget = 1e-4
reached(run) = run.gap <= gaptarget && run.kkt <= kkttarget

sweeps = ["CD on a BlockIterate, cyclic" => (cdruns, "tol", "passes"),
          "PGD on a dense Vector" => (pgdruns, "scale", "iterations")]

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

# ## What to take from this
#
# The times illustrate how to compare the two solvers at equal accuracy on this one problem, one
# design and one `lambda`; they come from one machine in one run and are not benchmark evidence
# (see [Benchmarks and performance](../../benchmarks.md)). A CD pass and a PGD iteration are
# different units of work: a full pass visits each group once and an active pass the active groups,
# while a PGD iteration forms products with `X` and its transpose (more of them when its line search
# rejects a trial).
