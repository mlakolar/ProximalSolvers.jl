# Minimal-core lasso examples

Run `julia --project=. examples/01_cd_lasso.jl`,
`julia --project=. examples/02_pgd_lasso.jl`,
`julia --project=. examples/03_sparse_cd_lasso.jl`,
`julia --project=. examples/04_lasso_solver_comparison.jl` or
`julia --project=. examples/05_apg_lasso.jl`. Each of the first three
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
their iterations and oracle calls; it makes no timing comparison. Historical feature
examples remain on legacy/full and protected archives.
