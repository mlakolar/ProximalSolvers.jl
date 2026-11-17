# Minimal-core lasso examples

Run `julia --project=. examples/01_cd_lasso.jl`,
`julia --project=. examples/02_pgd_lasso.jl`,
`julia --project=. examples/03_sparse_cd_lasso.jl`,
`julia --project=. examples/04_lasso_solver_comparison.jl`,
`julia --project=. examples/05_apg_lasso.jl`,
`julia --project=. examples/06_group_cd_lasso.jl`,
`julia --project=. examples/07_elasticnet.jl` or
`julia --project=. examples/08_weighted_lasso.jl`. Each of the first three
checks an independent analytic solution; the third runs coordinate descent on a
caller-owned `SparseIterate` and also checks that the result shares that owner. The
fourth compares cyclic coordinate descent, random-order coordinate descent and dense
proximal gradient descent on one seeded correlated lasso by the time each needs to
reach the same independently measured objective gap and KKT violation. It does not
use an analytic solution: its reference is a numerical one, cyclic coordinate descent
at a very small tolerance, and its accuracy checks are computed from the data and the
returned coefficients. Its checks concern accuracy and none concerns time: the
reference solution, the independent objective against the solver-reported one, and
that each solver reaches the target at some swept setting. Run as a script it prints
the comparison table and does not load Plots; the plot and the downloadable notebook
are produced by the documentation build, and the notebook needs Plots in its
environment. The fifth runs accelerated proximal gradient descent
(`AccProxGradDescent`) and plain proximal gradient descent with the same options on a
seeded correlated lasso, checks both with an independent KKT residual, and prints
their iterations and oracle calls; it makes no timing comparison. The sixth runs cyclic
coordinate descent for the group lasso on a `BlockIterate` with noncontiguous groups
(`GroupNormL2`) on a seeded problem, prints the groups and the active ones, and checks the
result with an independent group KKT residual computed from the data. The seventh solves a
seeded correlated elastic net (`ElasticNet(λ1, λ2)`) with both gradient methods, checks the
objective from X and y and the KKT residual (ProximalBase's `kkt_violation` at the gradient from X and y), and checks that the elastic-net solution has a
smaller Euclidean norm than the lasso solution with the same ℓ1 level; coordinate descent
refuses an `ElasticNet` (support is planned). The eighth solves a seeded weighted lasso, `NormL1(λ, w)`, with
all three solvers: the weights are adaptive-lasso weights from a ridge pilot fit, with one zero weight (an
unpenalized coefficient). It checks the three solutions with a weighted KKT residual computed in the script from X, y and
the coefficients `λ wⱼ`, the reported objectives, that the three agree, that the unpenalized coefficient is nonzero, that
the weights keep fewer coefficients than the unweighted lasso with the same `λ`, and that weights of another element type
are refused before `x` is touched. Historical feature
examples remain on legacy/full and protected archives.
