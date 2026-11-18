# Limitation (not a wrong answer): Float32, the LS centre c = old + b/a overflows Float32 while the exact minimizer z* = shrink(c, τ) = 0 is
# representable. The step returns Inf (also the ordinary path would: shrink(Inf, τ) = Inf); `_visit!` then refuses the solve with an
# ArgumentError ("a coordinate step or its stopping scale is not finite"). Column norm 8e-23, residual norm 7e16 (ratio ‖r‖/‖x‖² ≈ 1e61).
include("lib.jl")
T = Float32
xk = T[-7.358385f-23, -1.5394466f-23, 3.3777083f-24]
r  = T[-2.2174184f16, -6.1425987f16, 3.3623907f16]
old = T(-5.6764f35); λ = T(7.525048f-23)
X = reshape(xk, 3, 1); y = copy(r)
m, g, x = make_model(X, y, λ, T[0])
m.ls.r .= r; x[1] = old               # the residual the step starts from (private state set directly)
ref = bigref(xk, r, old, λ)
println("exact minimizer z* = ", Float64(ref.zstar), "   exact centre c = ", Float64(ref.c), "   floatmax(Float32) = ", floatmax(T))
h = PS.coordinate_step!(m, g, x, 1)
println("returned coordinate = ", x[1], "  (branch: ", classify(make_model(X, y, λ, T[0])[1], g, x, 1), " on a fresh model)")
x0 = zeros(T, 1)
try
  solve!(x0, SqrtLeastSquaresLoss(y .+ X[:,1] .* old, X), NormL1(λ), CDSolver(order = :cyclic))
catch e
  println("public solve!: ", first(sprint(showerror, e), 80))
end
