# First differences promote piecewise constants. Second differences promote
# piecewise linear sequences: a nonzero second difference marks a change in
# slope. For observations on an equally spaced index grid we minimize
# ```math
# \tfrac12\|x-b\|^2+\lambda\|D_2x\|_1,\qquad D_2=B_{p-1}B_p,
# ```
# where B computes adjacent differences. These differences are unscaled;
# changing the grid spacing or sample size changes the meaning of λ.
# This problem has no single call to the chain-TV prox, but chain TV remains
# a useful building block inside a specialized algorithm.

using LinearAlgebra, Printf, ProximalBase, ProximalSolvers
Base.include(@__MODULE__, joinpath(pkgdir(ProximalSolvers), "examples", "support", "primal_dual_lessons.jl"))
using .PrimalDualLessons

a = trend_problem(240)
tol = 1e-6
pd = native_solve(a; tol)
ordinary = split_admm(a; ρ = 10.0, tol)
special = trend_admm(a; tol)

# --- An alternative splitting changes the computation ---
#
# Ordinary ADMM splits z = D₂x and soft-thresholds z. Specialized ADMM
# instead splits α = Bₚx and applies the *direct TV prox* to α. Both have a
# reusable banded linear solve, but the specialized method retains more
# chain structure in its proximal subproblem. This is the central idea of
# Ramdas and Tibshirani's trend-filtering ADMM, detailed in the
# [lecture](@ref composite_lessons). It is a stronger baseline than merely
# comparing two generic primal–dual implementations.

for (name, result) in (("Condat–Vũ", pd), ("ordinary ADMM", ordinary), ("TV-split ADMM", special))
    @assert result.converged
    @printf("%s: %d iterations, relative certificate %.2e\n", name, result.iterations, result.cert.relative)
    @assert norm(result.x - pd.x) <= result.cert.distance_bound + pd.cert.distance_bound + 1e-8
end

# --- A fit is not a benchmark ---
#
# Reaching a small certificate verifies optimization accuracy. It does not
# select a statistically optimal λ or prove that the estimated knots are
# correct. The benchmark reports solve and setup costs at this same target,
# with an independent QP reference. Expect a specialized solver to be a
# serious competitor here: the lesson is how structure determines the
# algorithm, rather than that a general solver should always win.

println((noisy_rmse = norm(a.b - a.truth) / sqrt(a.p),
         fitted_rmse = norm(pd.x - a.truth) / sqrt(a.p)))
