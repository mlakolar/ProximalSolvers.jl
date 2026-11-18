# Group CD on the column-scaled fixture: converged = true at the default threshold with a KKT residual
# of 2e-4 relative to λmax. Where does the residual sit, and what does the change test bound?
include(joinpath(@__DIR__, "lib.jl"))
setprecision(BigFloat, PREC)
T = Float64
name, X0, y0 = fixture("colscale")
X, y = T.(X0), T.(y0)
n, p = size(X)
groups = [collect(i:i+2) for i in 1:3:p]
g0 = GroupNormL2(one(T), groups)
c = X' * y
λmax = maximum(norm(c[idx]) / g0.w[k] for (k, idx) in enumerate(groups))
for fr in (1e-3, 0.1), tol in (1e-7, 1e-9, 1e-11, 1e-13)
  λ = fr * λmax
  g = GroupNormL2(λ, groups)
  x = BlockIterate(T, p, g)
  res, msgs = capture() do
    solve!(x, LeastSquaresLoss(y, X), g, CDSolver(order = :cyclic, tol = tol))
  end
  xv = collect(x)
  r = big.(y) - big.(X) * big.(xv)
  grad = -(big.(X)' * r)
  @printf("λ = %.0e λmax, tol = %.0e: converged = %s, passes = %d, maxchange = %.3g, tolerance = %.3g\n", fr, tol, res.converged, res.passes, res.maxchange, res.tolerance)
  for (k, idx) in enumerate(groups)
    bk = big.(xv[idx]); nb = sqrt(sum(abs2, bk))
    v = iszero(nb) ? max(sqrt(sum(abs2, grad[idx])) - λ * g.w[k], 0) : sqrt(sum(abs2, grad[idx] .+ λ * g.w[k] .* bk ./ nb))
    ℓ = maximum(eigvals(Symmetric(X[:, idx]' * X[:, idx])))
    @printf("  group %d: column norms %.2g %.2g %.2g, ‖x_k‖ = %.3g, KKT residual/λmax = %.3g, per entry %s, bound tol·√ℓ‖y‖/λmax = %.3g\n",
            k, (norm(X[:, j]) for j in idx)..., Float64(nb), Float64(v / λmax),
            string(round.(Float64.(abs.(iszero(nb) ? grad[idx] : grad[idx] .+ λ * g.w[k] .* bk ./ nb) ./ λmax); sigdigits = 2)), tol * sqrt(ℓ) * norm(y) / λmax)
  end
  m = group_measures(X, y, one(T), λ, groups, g.w, xv)
  @printf("  relative duality gap at x: %.3g\n", Float64((m.F - m.D) / m.F))
end
