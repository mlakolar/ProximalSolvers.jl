# An empty problem (p = 0 or n = 0) through the public solvers, base against head, and the helpers on empty arrays.
include(joinpath(@__DIR__, "loader.jl"))
using ProximalBase, Random
B = BaseMod.ProximalSolvers; S = X2Mod.ProximalSolvers
function outcome(f)
  try r = f(); (:ok, r) catch e; (:err, first(split(sprint(showerror, e), '\n'))) end
end
for T in (Float32, Float64), (n, p) in ((5, 0), (0, 3), (0, 0))
  X = zeros(T, n, p); y = zeros(T, n)
  for (nm, mk) in (("apg", PS -> PS.AccProxGradDescent()), ("pgd", PS -> PS.ProximalGradientDescent()), ("cd", PS -> PS.CDSolver()))
    ob = outcome(() -> (x = zeros(T, p); r = B.solve!(x, LeastSquaresLoss(y, X), NormL1(T(0.1)), mk(B)); (r.status, x)))
    oh = outcome(() -> (x = zeros(T, p); r = S.solve!(x, LeastSquaresLoss(y, X), NormL1(T(0.1)), mk(S)); (r.status, x)))
    println(T, " n=", n, " p=", p, " ", nm, ": base ", ob[1], " ", ob[2] isa Tuple ? ob[2][1] : ob[2], " | head ", oh[1], " ", oh[2] isa Tuple ? oh[2][1] : oh[2], ob == oh ? "  SAME" : "  DIFFERENT")
  end
end
for T in (Float32, Float64)
  v = T[]; 
  println(T, " _se_norm(T, []): base ", outcome(() -> B._se_norm(T, v)), " head ", outcome(() -> S._se_norm(T, v)))
  println(T, " _se_norm(T, [], []): base ", outcome(() -> B._se_norm_diff(T, v, v)), " head ", outcome(() -> S._se_norm(T, v, v)))
end
