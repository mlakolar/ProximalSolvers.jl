# Phase 1: reproduce the #155 and #156 fixtures on current master, both types, both iterate kinds.
using ProximalBase, ProximalSolvers, LinearAlgebra, Logging
println("Julia ", VERSION, "  PS ", pkgversion(ProximalSolvers), "  PB ", pkgversion(ProximalBase))
println("PS path ", pathof(ProximalSolvers)); println("PB path ", pathof(ProximalBase))
obj(X, y, λ, b) = norm(big.(y) - big.(X) * big.(b)) + big(λ) * norm(big.(b), 1)
function run(X, y, λ, β0; owner = false, kw...)
  x = owner ? SparseIterate(copy(β0)) : copy(β0)
  r = with_logger(NullLogger()) do
    solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(; kw...))
  end
  xv = owner ? Vector(x) : x
  xv, r
end
for T in (Float64, Float32), owner in (false, true)
  println("\n== T = $T, owner = $owner")
  X = T[1 1; 0 0.01]; b0 = T[1, -1]; y = X * b0; λ = T(0.1)
  x, r = run(X, y, λ, b0; owner, order = :cyclic, momentum = false)
  println("#155 from [1,-1]: x = ", x, " converged=", r.converged, " gap=", r.gap, " passes=", r.passes,
          " minimum=", r.minimum, " F(x)=", Float64(obj(X, y, λ, x)), " F(0)=", Float64(obj(X, y, λ, zeros(T, 2))),
          " ‖r̂‖=", norm(Float64.(y) - Float64.(X) * Float64.(x)))
  println("   fields: ", propertynames(r))
  x, r = run(X, y, λ, zeros(T, 2); owner, order = :cyclic, momentum = false)
  println("#155 from 0: x = ", x, " converged=", r.converged, " gap=", r.gap)
  for ord in (:cyclic, :random)
    x, r = run(X, y, λ, b0; owner, order = ord)
    println("#155 from [1,-1] order=$ord default momentum: x=", x, " conv=", r.converged, " gap=", r.gap)
  end
  X = T[1 2; 0 1]; y = T[1, 0]
  x, r = run(X, y, λ, zeros(T, 2); owner, order = :cyclic, momentum = false)
  θ = [0.1, -0.1]
  println("#156 from 0: x = ", x, " converged=", r.converged, " gap=", r.gap, " passes=", r.passes,
          " F(x)=", Float64(obj(X, y, λ, x)), " θ'y=", dot(θ, Float64.(y)), " ‖θ‖=", norm(θ),
          " ‖X'θ‖∞=", maximum(abs, Float64.(X)' * θ))
  x, r = run(X, y, λ, zeros(T, 2); owner, order = :random)
  println("#156 from 0 random: x = ", x, " converged=", r.converged, " gap=", r.gap)
end
