# What the change test of least-squares CD bounds. At a full pass whose scaled changes are all below
# τ = tol √s ‖y‖, exact coordinate minimization gives, for every coordinate k,
#     |G_k| ≤ √(s a_k) Σ_{j visited after k} √(s a_j) |h_j|  <  (p − 1) tol · √(s a_k) √s ‖y‖,
# with a_k = ‖X_k‖². The statistic below is q = max_k |G_k| / (tol √(s a_k) √s ‖y‖), which the bound
# puts below p − 1 in exact arithmetic; G_k is evaluated in BigFloat at the returned point.
include("<REVIEW>/.codex-orchestrator/audit/study/lib.jl")
setprecision(BigFloat, PREC)
println("Julia ", VERSION)
println(join(["T", "fixture", "loss", "penalty", "l1frac", "order", "momentum", "tol", "passes", "q", "p-1", "kkt_rel_lmax", "cos"], '\t'))
worst = Dict{Any, Float64}()
for T in (Float64, Float32), (name, X0, y0) in fixtures(), loss in (:raw, :mean)
  name == "yzero" && continue
  X, y = T.(X0), T.(y0)
  n, p = size(X)
  s = loss === :raw ? one(T) : one(T) / T(n)
  λmax = Float64(s) * maximum(abs, Float64.(X)' * Float64.(y))
  for (pen, fr, l2f) in (("l1", 1e-3, 0.0), ("l1", 0.1, 0.0), ("l1", 0.5, 0.0), ("enet", 0.1, 0.5)),
      (order, momentum) in ((:cyclic, false), (:random, false), (:random, nothing)), tol in (T === Float64 ? (1e-7, 1e-10) : (1e-7, 1e-5))
    l1, l2 = T(fr * λmax), T(l2f * λmax)
    f = loss === :raw ? LeastSquaresLoss(y, X) : s * LeastSquaresLoss(y, X)
    g = pen == "l1" ? NormL1(l1) : ElasticNet(l1, l2)
    x = zeros(T, p)
    res = quiet(() -> solve!(x, f, g, CDSolver(; order, momentum, tol, rng = Xoshiro(1))))
    res.converged || continue
    Xb, yb, xb, sb = bigv(X), bigv(y), bigv(x), big(s)
    r = yb - Xb * xb
    grad = -sb .* (Xb' * r) .+ big(l2) .* xb
    ny = sqrt(sum(abs2, yb))
    q = zero(BigFloat)
    for k in 1:p
      a = sum(abs2, Xb[:, k])        # the elastic net adds λ2 to the curvature s a
      iszero(a) && continue
      Gk = iszero(xb[k]) ? max(abs(grad[k]) - big(l1), 0) : abs(grad[k] + big(l1) * sign(xb[k]))
      q = max(q, Gk / (big(tol) * sqrt(sb * a) * sqrt(sb) * ny))
    end
    G = maximum(k -> iszero(xb[k]) ? max(abs(grad[k]) - big(l1), 0) : abs(grad[k] + big(l1) * sign(xb[k])), 1:p)
    cosmax = λmax / (Float64(s) * maximum(norm(Float64.(X[:, k])) for k in 1:p) * norm(Float64.(y)))
    tsv(stdout, T, name, loss, pen, fr, order, momentum === nothing ? "default" : momentum, tol, res.passes, Float64(q), p - 1,
        Float64(G / max(big(l1), big(λmax))), cosmax)
    key = (T, tol)
    worst[key] = max(get(worst, key, 0.0), Float64(q) / (p - 1))
  end
end
for k in sort(collect(keys(worst)); by = string)
  @printf("# worst q/(p-1) for %s tol %.0e: %.3g\n", k[1], k[2], worst[k])
end
