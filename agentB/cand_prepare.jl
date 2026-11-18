# Cost of `_prepare!` for singleton groups (in-order `_sqnorm!`) against a whole group solve. Real private functions, production code.
using ProximalSolvers, ProximalBase, Random, Printf, Logging
const PS = ProximalSolvers
function prep_time(T, n, p, gs; reps=20)
  rng = Xoshiro(1); X = randn(rng, T, n, p); y = randn(rng, T, n)
  f = LeastSquaresLoss(y, X)
  groups = [collect((i-1)*gs+1:i*gs) for i in 1:p÷gs]
  g = GroupNormL2(T(0.3*maximum(abs.(X'*y))), groups)
  x = BlockIterate(T, p, g)
  m = PS.cdmodel(f, x); PS.initialize!(m, x); PS._prepare!(m, g, x)
  tp = Inf
  for _ in 1:reps
    PS.initialize!(m, x)
    tp = min(tp, @elapsed PS._prepare!(m, g, x))
  end
  ts = Inf
  for _ in 1:5
    x = BlockIterate(T, p, g)
    ts = min(ts, @elapsed with_logger(NullLogger()) do; solve!(x, f, g, CDSolver(order=:cyclic, tol=T===Float32 ? 1e-6 : 1e-9)); end)
  end
  # what a SIMD sum of squares would cost for the same columns (the `a` of _column_dot) for comparison
  tq = Inf
  for _ in 1:reps
    tq = min(tq, @elapsed (for j in 1:p; sum(abs2, view(X, :, j)); end))
  end
  (tp, ts, tq)
end
for T in (Float32, Float64), (n, p, gs) in ((100, 200, 1), (1000, 1000, 1), (1000, 1000, 5), (10000, 200, 1))
  tp, ts, tq = prep_time(T, n, p, gs)
  @printf("%s n=%d p=%d group size %d: _prepare! %.3f ms; whole solve %.3f ms (prepare = %.1f%%); simd Σx² of all columns: %.3f ms\n", T, n, p, gs, 1e3tp, 1e3ts, 100tp/ts, 1e3tq)
end
