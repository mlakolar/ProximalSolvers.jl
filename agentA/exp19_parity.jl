include("lib.jl"); include("optB.jl"); include("optC.jl"); include("optC2.jl")
using Logging
include("exp10_common.jl")
function families(T)
  res = Any[]
  for (n, p) in ((20, 10), (100, 60), (400, 40), (30, 120)), lf in (0.5, 0.1, 0.02), order in (:cyclic, :random)
    rng = Xoshiro(hash((n, p, lf))); X = randn(rng, T, n, p); y = randn(rng, T, n); λ = T(lf*lam_max(X, y))
    push!(res, ((n, p, lf, order), outcome(T, X, y, λ; order)))
  end
  for σ in (0.0, 1e-9), (n, p) in ((30, 100), (50, 20))
    rng = Xoshiro(7); X = T.(randn(rng, n, p)); β0 = zeros(p); β0[1:3] .= (3.0, -2.0, 1.0)
    y = T.(X*β0 .+ σ .* randn(rng, n)); λ = T(0.2*lam_max(X, y))
    push!(res, (("exactfit", σ, n, p), outcome(T, X, y, λ)))
  end
  push!(res, (("y=0",), outcome(T, T[1 2; 3 4; 5 6], zeros(T, 3), T(0.5))))
  push!(res, (("p=1 parallel",), outcome(T, reshape(T[1, 2, -1, 0.5], 4, 1), T[3, 6, -3, 1.5], T(0.5))))
  push!(res, (("dyadic one-hot-like",), outcome(T, T[1 0 1; 1 0 0; 0 1 1; 0 1 0; 1 1 0], T[2, 1, 3, 1, 2], T(0.3))))
  res
end
fa = Dict(T => families(T) for T in (Float32, Float64))
ARGS[1] == "C2" ? install_C2!() : install_B1!()
fb = Dict(T => families(T) for T in (Float32, Float64))
for T in (Float32, Float64)
  nd = 0
  for ((ka, a), (kb, b)) in zip(fa[T], fb[T])
    same = a.ok == b.ok && a.x == b.x && a.passes == b.passes && isequal(a.gap, b.gap) && a.conv == b.conv
    same || (nd += 1; println("  differs: ", ka, " A=", (a.ok, a.conv, a.passes, a.gap, a.msg), " ", ARGS[1], "=", (b.ok, b.conv, b.passes, b.gap, b.msg)))
  end
  println(T, ": ", length(fa[T]), " ordinary/degenerate families, outcomes (x, passes, gap, flags) differing under ", ARGS[1], ": ", nd)
end
