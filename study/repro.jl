# Hand-built cases of #378: the reproducer of the issue and its variants, with the diagnostics of
# lib378.jl and the truth in BigFloat. One block per case.
using Pkg
Pkg.instantiate()
include(joinpath(@__DIR__, "lib378.jl"))
setprecision(BigFloat, PREC)
println("Julia ", VERSION, " ", Sys.CPU_NAME)
g3(v) = @sprintf("%.3g", Float64(v))
function report(tag, X::Matrix{T}, y::Vector{T}, g, x0; order = :cyclic, momentum = false, tol = 1e-7, relative = true, sparse = false, maxpasses = 5000) where T
  l1, l2 = levels(g, T)
  R = LassoRef(X, y, one(T), l1, l2)
  ref = reference(R, Float64.(X), Float64.(y), 1.0, l1, l2)
  f = LeastSquaresLoss(y, X)
  method = CDSolver(; order, momentum, tol, relative, maxpasses, rng = Xoshiro(1))
  xs = sparse ? SparseIterate(copy(x0)) : copy(x0)
  res = quiet(() -> probe_solve(xs, f, g, method))
  x2 = sparse ? SparseIterate(copy(x0)) : copy(x0)
  r2 = quiet(() -> solve!(x2, f, g, CDSolver(; order, momentum, tol, relative, maxpasses, rng = Xoshiro(1))))
  st = res.st
  equiv = samebits(collect(res.work), collect(x2)) && r2.passes == st.passes && r2.converged == st.converged
  xv = collect(res.work)
  m = measures(R, xv)
  S = max(R.l1, R.λmax)
  thr = st.tolerance
  println("--- ", tag, " ", T, " order=", order, " momentum=", momentum, " tol=", tol, " relative=", relative, sparse ? " sparse" : " dense")
  println("  converged=", st.converged, " passes=", st.passes, " maxchange=", g3(st.maxchange), " threshold=", g3(thr), " same as solve!: ", equiv)
  println("  truth: KKT/max(λ1,λmax)=", g3(rel(m.G, S)), " (F−F*)/F*=", iszero(ref.Fref) ? "F*=0" : g3(rel(m.F - ref.Fref, ref.Fref)), " reported minimum error=", g3(rel(abs(big(res.minimum) - m.F), m.F)))
  st.converged || return
  t = scalar_truth(R, xv, res.inner.r)
  d = scalar_stats(res, g, X, y, method)
  resp = PS.response_scale(res.inner, res.work)
  println("  truth: E/threshold=", g3(t.E / thr), " stale residual/threshold=", g3(t.dres / thr), " amplification=", g3(t.amp))
  println("  stopping pass: absorbed visits=", d.nabs, " nonzero changes=", d.nhnz, " fresh residual at its start=", d.fresh)
  println("  A/thr=", g3(d.A / thr), " Aq=", g3(d.Aq), " Aq0=", g3(d.Aq0), " | B: Bq=", g3(d.Bq), " | C: Cuq=", g3(d.Cuq), " C352/thr=", g3(d.C352 / thr), " K296=", g3(d.K296))
  println("  R/thr: image-first=", g3(d.Rimg / thr), " init-order=", g3(d.Rinit / thr), " Float64=", g3(d.R64 / thr),
          " | P/(eps resp): stop=", g3(d.P / (eps(T) * resp)), " start=", g3(resolution(X, x0, one(T)) / (eps(T) * resp)), " path/resp=", g3(d.path / resp))
  c = confirm!(res, g, X, y, method, r -> scalar_stats(r, g, X, y, method))
  println("  refresh + one pass: init-order change/thr=", g3(c.conf_init / thr), " Aq=", g3(c.confAq_init), " | image-first change/thr=", g3(c.conf_img / thr), " Aq=", g3(c.confAq_img))
end
for T in (Float64, Float32)
  M = T === Float32 ? T(2)^20 : T(2)^49
  X = ones(T, 1, 2); y = T[1 / 64]
  for (name, g) in (("reproducer λ=1/1024", NormL1(T(1 / 1024))), ("reproducer λ=0", NormL1(zero(T))), ("reproducer elastic net", ElasticNet(T(1 / 1024), T(1 / 16))))
    report(name, X, y, g, T[M, -M])
    report(name, X, y, g, T[M, -M]; order = :random, momentum = nothing, sparse = true)
    report(name, X, y, g, T[M, -M]; relative = false)
  end
  # a third, independent coordinate that makes a small nonzero change: the stopping pass is not empty
  X3 = T[1 1 0; 0 0 1]; y3 = T[1 / 64, 1]
  for λ in (T(1 / 1024), zero(T))
    report("mixed pass λ=$(λ)", X3, y3, NormL1(λ), T[M, -M, 1 - λ + 2eps(T)])
  end
  # H3: one coordinate far out on a well-conditioned design; the iterate comes back, the cache keeps the error
  _, X0, y0 = fixture("gauss")
  Xg, yg = T.(X0), T.(y0)
  λg = T(0.1 * maximum(abs, Float64.(Xg)' * Float64.(yg)))
  for j in (T === Float32 ? (8, 16, 22) : (24, 40, 50))
    x0 = zeros(T, size(Xg, 2)); x0[1] = T(2.0^j)
    report("gauss, x0 = 2^$j e_1", Xg, yg, NormL1(λg), x0; maxpasses = 100_000)
    report("gauss, x0 = 2^$j e_1", Xg, yg, NormL1(λg), x0; order = :random, momentum = nothing, sparse = true, maxpasses = 100_000)
  end
end
