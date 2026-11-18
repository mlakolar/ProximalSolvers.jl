# What a working-precision check at the stop of least-squares CD would see (no such check exists).
# For every converged solve: wp = the KKT residual computed in T from a fresh residual, normalized by
# max(λ, computed λmax), and stat = max_k g_k/√(s a_k), the coordinate KKT residual in the units of the
# change test, against the solve's own threshold. "refused" counts the converged solves that a check
# "stat < threshold" (no precision floor) would not accept; the classes are those of the sweep
# (target 1e-8 / 1e-5 against the reference, decided from the exact objective).
include("<REVIEW>/.codex-orchestrator/audit/study/lib.jl")
setprecision(BigFloat, PREC)
println("Julia ", VERSION)
const DETAIL=open("<TMP>/gate-details.tsv","w")
println(DETAIL,join(["T","fixture","loss","penalty","fr","tol","start","order","stat","threshold","maxchange","wp","subopt_lo","subopt_hi","refgap","Fref","F0"],'\t'))
const TARGET = Dict(Float64 => 1e-8, Float32 => 1e-5)
function wp(X::Matrix{T}, y, s, l1, l2, x) where T
  r = y - X * x
  grad = -s .* (X' * r) .+ l2 .* x
  g(k) = iszero(x[k]) ? max(abs(grad[k]) - l1, zero(T)) : abs(grad[k] + l1 * sign(x[k]))
  S = max(l1, s * maximum(abs, X' * y))
  G = maximum(g, eachindex(x))
  stat = zero(T)
  for k in eachindex(x)
    a = sum(abs2, X[:, k])
    iszero(a) || (stat = max(stat, g(k) / sqrt(s * a)))
  end
  iszero(S) ? T(NaN) : G / S, stat
end
acc = Dict{Any, Vector{Int}}()     # (T, tol, start class) => [converged, refused, refused&within target, above target, above target&refused, wp>=64eps, wp>=1e-5]
worstwp = Dict{Any, Float64}()
for T in (Float64, Float32), (name, X0, y0) in fixtures(), loss in (:raw, :mean)
  name == "yzero" && continue
  X, y = T.(X0), T.(y0)
  n, p = size(X)
  s = loss === :raw ? one(T) : one(T) / T(n)
  λmax = Float64(s) * maximum(abs, Float64.(X)' * Float64.(y))
  for (pen, fr, l2f) in (("l1", 0.0, 0.0), ("l1", 1e-3, 0.0), ("l1", 0.1, 0.0), ("l1", 0.5, 0.0), ("enet", 0.1, 0.5))
    l1, l2 = T(fr * λmax), T(l2f * λmax)
    R = LassoRef(X, y, s, l1, l2)
    ref = reference(R, Float64.(X), Float64.(y), Float64(s), l1, l2)
    ref.Fref > 0 || continue
    f = loss === :raw ? LeastSquaresLoss(y, X) : s * LeastSquaresLoss(y, X)
    g = pen == "l1" ? NormL1(l1) : ElasticNet(l1, l2)
    for (sname, x0) in (("cold", zeros(T, p)), ("ref", T.(ref.xref)), ("pert", T.(ref.xref .* 1.05 .+ 1e-3))), tol in (1e-7, T === Float64 ? 1e-10 : 1e-5), order in (:cyclic, :random)
      x = copy(x0)
      res = quiet(() -> solve!(x, f, g, CDSolver(; order, tol, momentum = false, rng = Xoshiro(1))))
      res.converged || continue
      k, stat = wp(X, y, s, l1, l2, x)
      m = measures(R, x)
      above = rel(m.F - ref.Fref, ref.Fref) > TARGET[T]
      tsv(DETAIL,T,name,loss,pen,fr,tol,sname,order,stat,res.tolerance,res.maxchange,k,rel(m.F-ref.Fref,ref.Fref),rel(m.F-ref.Dref,ref.Dref),rel(ref.Fref-ref.Dref,ref.Fref),Float64(ref.Fref),Float64(measures(R,zeros(p)).F))
      refused = !(stat < res.tolerance)
      key = (T, tol, fr == 0 ? "λ=0" : "λ>0")
      v = get!(acc, key, zeros(Int, 7))
      v[1] += 1; v[2] += refused; v[3] += refused & !above; v[4] += above; v[5] += above & refused
      v[6] += !(k < 64 * eps(T)); v[7] += !(k < 1e-5)
      above || (worstwp[key] = max(get(worstwp, key, 0.0), Float64(k)))
    end
  end
end
println(join(["T", "tol", "penalty", "converged", "refused by stat<threshold", "refused and within target", "above target", "above target and refused", "wp>=64eps", "wp>=1e-5", "worst wp within target"], '\t'))
for key in sort(collect(keys(acc)); by = string)
  v = acc[key]
  println(join(Any[key[1], key[2], key[3], v..., @sprintf("%.3g", get(worstwp, key, NaN))], '\t'))
end

close(DETAIL)
