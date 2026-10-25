# An irregular graph connects coefficients expected to be similar. Sparsity
# selects vertices and fusion encourages equal values across edges. This is
# not a chain TV problem: the graph has cycles and nonlocal edges, and the
# underdetermined design couples the coefficients through the loss.
#
# We minimize
# ```math
# F(x)=\tfrac12\|b-Xx\|^2+\tfrac\mu2\|x\|^2
#       +\lambda_1\|x\|_1+\lambda_2\|Dx\|_1.
# ```
# Ridge makes the minimizer unique, and supplies a computable lower bound
# for comparing algorithms. The [lecture](@ref composite_lessons) derives the
# certificate and both update rules. Reference routines live in
# `examples/support/primal_dual_lessons.jl`; they are teaching code, not API.

using LinearAlgebra, Printf, ProximalBase, ProximalSolvers
Base.include(@__MODULE__, joinpath(pkgdir(ProximalSolvers), "examples", "support", "primal_dual_lessons.jl"))
using .PrimalDualLessons

a = graph_problem(12)
println((observations = length(a.b), coefficients = a.p, edges = size(a.D, 1)))

# --- Separate the simple operations ---
#
# Set `f` to least squares plus ridge, `g` to coefficient ℓ1, and `h` to
# edge ℓ1. The joint prox of `g + h ∘ D` is unavailable, but `prox(g)` is
# soft thresholding and `prox(h*)` clips edge duals to [-λ₂, λ₂]. No normal
# matrix or factorization is required by Condat–Vũ. We use the certified
# bound L = ‖X‖₁‖X‖∞ + μ, rather than an unverified spectral-norm estimate.

tol = 1e-6
pd = native_solve(a; tol)
@assert pd.converged
@printf("Condat–Vũ: %d iterations, relative certificate %.2e\n", pd.iterations, pd.cert.relative)

# --- Compare with a factorization-based alternative ---
#
# ADMM introduces z = [I; D]x. Its x step solves a system with matrix
# X'X + μI + ρ(I + D'D); its z step is weighted soft thresholding. The
# factorization is reused at every step. This is a general linear-constraint
# ADMM reference, distinct from the package's x = z `ADMMSolver` interface.
# Both methods stop at the same certificate, checked every 25 iterations.

ad = split_admm(a; ρ = 1.0, tol)
@assert ad.converged
@printf("Split ADMM: %d iterations, relative certificate %.2e\n", ad.iterations, ad.cert.relative)

# Strong convexity bounds the distance to the unique minimizer. In
# particular, the distance between two approximate solutions is at most
# the sum of their individual certified distance bounds. No assertion about
# elapsed time belongs in a correctness example.

distance = norm(pd.x - ad.x)
bound = pd.cert.distance_bound + ad.cert.distance_bound
@assert distance <= bound + 1e-8
println((solution_distance = distance, certified_bound = bound))

# --- What this comparison teaches ---
#
# Condat–Vũ works directly with X, X', D and D'. ADMM can take fewer steps
# after paying for a factorization. Its advantage depends on fill-in and on
# whether that factorization can be reused across fits. The separate
# benchmark includes setup, checks both methods against a JuMP/HiGHS QP,
# and reports two ADMM penalty parameters. A small graph is a correctness
# example; it cannot establish a large-scale performance advantage.
