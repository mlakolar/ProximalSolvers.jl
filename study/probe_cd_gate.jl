# What one working-precision check at the stop of least-squares CD would see (no such check exists).
# The check tested here is evaluated AFTER the solve, at the returned point, from a fresh residual in T
# (one more pass of products, O(np)); it is not the statistic a visit could form from its own b.
# For every converged solve: wp = the KKT residual normalized by max(λ, computed λmax), and
# stat = max_k g_k/√(s a_k), the coordinate KKT residual in the units of the change test, compared with
# the solve's own threshold and no precision floor. At the returned point the statistic contains the
# coupling with the coordinates visited later (the factor of the bound F8), so it can exceed the
# threshold in exact arithmetic after a valid stopping pass. (For a visit-level comparison, which is
# not what this probe measures: in exact arithmetic and when
# the sign of a nonzero coefficient does not change, the normalized residual magnitude |G_k|/√(s a_k) at
# the start of a visit is the scaled change √(s a_k)|h_k| of that visit for the lasso and 1 + λ2/(s a_k)
# times it for the elastic net.) "refused" counts the converged solves with stat >= threshold. A solve is within the
# target when the upper bound of its suboptimality against a tight reference is below it, above the
# target when the lower bound against a reference with Fref > 1e-20 F(0) exceeds it (the sweep's rule).
include(joinpath(@__DIR__, "lib.jl"))
setprecision(BigFloat, PREC)
println("Julia ", VERSION)
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
acc = Dict{Any, Vector{Int}}()     # (T, tol, penalty class) => the nine counts of the header below
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
    F0 = measures(R, zeros(p)).F
    tight = (ref.Fref - ref.Dref) / ref.Fref <= big(1e-12) && ref.Fref > big(1e-20) * F0
    informative = ref.Fref > big(1e-20) * F0
    f = loss === :raw ? LeastSquaresLoss(y, X) : s * LeastSquaresLoss(y, X)
    g = pen == "l1" ? NormL1(l1) : ElasticNet(l1, l2)
    for (sname, x0) in (("cold", zeros(T, p)), ("ref", T.(ref.xref)), ("pert", T.(ref.xref .* 1.05 .+ 1e-3))), tol in (1e-7, T === Float64 ? 1e-10 : 1e-5), order in (:cyclic, :random)
      x = copy(x0)
      res = quiet(() -> solve!(x, f, g, CDSolver(; order, tol, momentum = false, rng = Xoshiro(1))))
      res.converged || continue
      k, stat = wp(X, y, s, l1, l2, x)
      m = measures(R, x)
      above = informative && rel(m.F - ref.Fref, ref.Fref) > TARGET[T]
      within = tight && rel(m.F - ref.Dref, ref.Dref) <= TARGET[T]
      refused = !(stat < res.tolerance)
      empty = iszero(res.maxchange)
      key = (T, tol, fr == 0 ? "λ=0" : "λ>0")
      v = get!(acc, key, zeros(Int, 9))
      v[1] += 1; v[2] += refused; v[3] += refused & within; v[4] += above; v[5] += above & refused
      v[6] += !(k < 64 * eps(T)); v[7] += !(k < 1e-5); v[8] += empty; v[9] += empty & refused
      within && (worstwp[key] = max(get(worstwp, key, 0.0), Float64(k)))
    end
  end
end
println(join(["T", "tol", "penalty", "converged", "refused by stat<threshold", "refused and within target", "above target", "above target and refused", "wp>=64eps", "wp>=1e-5", "stopping pass changed nothing", "of those refused", "worst wp within target"], '\t'))
for key in sort(collect(keys(acc)); by = string)
  v = acc[key]
  println(join(Any[key[1], key[2], key[3], v..., @sprintf("%.3g", get(worstwp, key, NaN))], '\t'))
end
