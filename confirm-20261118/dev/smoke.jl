# Development smoke test (fixtures only; not held-out).
include(joinpath(@__DIR__, "..", "scripts", "lib.jl"))
for prob in dev_problems(), T in (Float64, Float32), config in CONFIGS, st in prob.starts
  X, y, λ = T.(prob.X), T.(prob.y), T(prob.λ)
  β0 = start_point(prob, st, nothing)
  x0, r0, t0, _ = solve_mode(X, y, λ, β0, config; mode = :off)
  x1, r1, t1, l1 = solve_mode(X, y, λ, β0, config; mode = :d2)
  x1g, r1g, _, l1g = solve_mode(X, y, λ, β0, config; mode = :d2, dual = m1g_dual)
  rng = Xoshiro(7); xb, rb, _, _ = solve_mode(X, y, λ, β0, config; mode = :off, rng)
  pd = rb.converged ? nothing : pdhg_fallback(X, y, λ, xb, rb.passes, config, rng)
  @printf "%-5s %-7s %-13s %-5s | M0 conv=%d P=%.6g passes=%d | M1 conv=%d P=%.6g passes=%d gap=%.2e via=%s | M1g conv=%d via=%s | M2 %s\n" prob.id T config st r0.converged Float64(Pbig(X, y, λ, x0)) r0.passes r1.converged Float64(Pbig(X, y, λ, x1)) r1.passes r1.gap (l1 === nothing ? "-" : l1.via) r1g.converged (l1g === nothing ? "-" : l1g.via) (pd === nothing ? "-" : "cert=$(pd.certified) via=$(pd.via) P=$(Float64(Pbig(X, y, λ, pd.ret))) it=$(pd.iters) used=$(pd.used)")
end
