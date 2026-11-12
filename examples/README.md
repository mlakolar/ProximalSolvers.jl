# Minimal-core lasso examples

Run `julia --project=. examples/01_cd_lasso.jl`,
`julia --project=. examples/02_pgd_lasso.jl`,
`julia --project=. examples/03_sparse_cd_lasso.jl` or
`julia --project=. examples/04_lasso_solver_comparison.jl`. Each checks an independent
analytic solution; the third runs coordinate descent on a caller-owned
`SparseIterate` and also checks that the result shares that owner. The fourth
compares cyclic coordinate descent, random-order coordinate descent and dense
proximal gradient descent on one seeded correlated lasso by the time each needs to
reach the same independently measured objective gap and KKT violation. Its checks
are on accuracy only: the reference solution, the independent objective against the
solver-reported one, and that each solver reaches the target at some swept setting.
Run as a script it prints the comparison table; the plot and the downloadable
notebook appear only in the documentation build, and the notebook needs Plots in its
environment. Historical feature examples remain on legacy/full and protected
archives.
