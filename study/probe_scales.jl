# Exact power-of-two rescalings of one problem (X 2^ex, y 2^ey, λ 2^(ex+ey)); the scaled problem has the
# solution x* 2^(ey−ex) and the minimum F* 2^(2 ey), so the reference of the unscaled problem serves all.
# Also: a group lasso with an unpenalized group (weight 0). One row per solve; a row is flagged when
# converged = true and the exact normalized KKT residual is not below the bound (PGD, APG) or the
# suboptimality is above the target (CD).
include(joinpath(@__DIR__, "lib.jl"))
setprecision(BigFloat, PREC)
println("Julia ", VERSION)
println(join(["T", "ex", "ey", "solver", "status", "converged", "its", "kkt_rel", "subopt", "flag"], '\t'))
const TARGET = Dict(Float64 => 1e-8, Float32 => 1e-5)
function scaled(T, exs, eys)
  _, X0, y0 = fixture("gauss")
  Xu, yu = T.(X0), T.(y0)
  p = size(Xu, 2)
  λu = T(0.1 * maximum(abs, Float64.(Xu)' * Float64.(yu)))
  Ru = LassoRef(Xu, yu, one(T), λu, zero(T))
  refu = reference(Ru, Float64.(Xu), Float64.(yu), 1.0, λu, zero(T))
  nflag = 0
  for ex in exs, ey in eys
    X, y, λ = ldexp.(Xu, ex), ldexp.(yu, ey), ldexp(λu, ex + ey)
    (all(isfinite, X) && all(isfinite, y) && isfinite(λ) && λ >= floatmin(T) && all(v -> iszero(v) || abs(v) >= floatmin(T), X) && all(v -> iszero(v) || abs(v) >= floatmin(T), y)) || continue
    R = LassoRef(X, y, one(T), λ, zero(T))
    Fref = refu.Fref * big(2.0)^(2ey)
    S = max(R.l1, R.λmax)
    f, g = LeastSquaresLoss(y, X), NormL1(λ)
    for (name, run, bound) in (("cd", x -> solve!(x, f, g, CDSolver(order = :cyclic, momentum = false)), NaN),
                               ("cd-random", x -> solve!(x, f, g, CDSolver(rng = Xoshiro(1))), NaN),
                               ("pgd", x -> solve!(x, f, g, ProximalGradientDescent()), max(1e-5, 64 * Float64(eps(T)))),
                               ("apg", x -> solve!(x, f, g, AccProxGradDescent()), max(1e-5, 64 * Float64(eps(T)))))
      x = zeros(T, p)
      try
        r = quiet(() -> run(x))
        m = measures(R, x)
        its = r isa PS.CDResults ? r.passes : r.iterations
        k, so = rel(m.G, S), rel(m.F - Fref, Fref)
        flag = r.converged && (isnan(bound) ? so > TARGET[T] : !(k < bound))
        nflag += flag
        tsv(stdout, T, ex, ey, name, "ok", r.converged, its, k, so, flag ? "FLAG" : "")
      catch e
        tsv(stdout, T, ex, ey, name, "error:" * first(sprint(showerror, e), 70), "", "", "", "", "")
      end
    end
  end
  nflag
end
n64 = scaled(Float64, (-500, -400, -200, -100, 0, 100, 200, 400, 500), (-500, -400, -200, -100, 0, 100, 200, 400, 500))
n32 = scaled(Float32, (-60, -40, -20, 0, 20, 40, 60), (-60, -40, -20, 0, 20, 40, 60))
println("# flagged rows: Float64 ", n64, ", Float32 ", n32)

# group lasso with an unpenalized group
println("# group lasso, weights (0, 1, 1, 1) and (1, 0, 0, 1): converged, passes, exact KKT residual / scale, relative gap at x")
for T in (Float64, Float32), name in ("gauss", "corr95", "colscale"), w in ([0.0, 1, 1, 1], [1.0, 0, 0, 1]), order in (:cyclic, :random)
  _, X0, y0 = fixture(name)
  X, y = T.(X0), T.(y0)
  p = size(X, 2)
  groups = [collect(i:i+2) for i in 1:3:p]
  c = Float64.(X)' * Float64.(y)
  λ = T(0.1 * maximum(norm(c[idx]) for idx in groups))
  g = GroupNormL2(λ, groups, T.(w))
  x = BlockIterate(T, p, g)
  try
    r = quiet(() -> solve!(x, LeastSquaresLoss(y, X), g, CDSolver(order = order, rng = Xoshiro(1))))
    m = group_measures(X, y, one(T), λ, groups, g.w, collect(x))
    @printf("# %s %-8s w=%s %-6s converged=%s passes=%d kkt=%.3g gap=%.3g\n", T, name, string(w), order, r.converged, r.passes, Float64(m.G / m.λmax), Float64((m.F - m.D) / m.F))
  catch e
    @printf("# %s %-8s w=%s %-6s error: %s\n", T, name, string(w), order, first(sprint(showerror, e), 90))
  end
end
