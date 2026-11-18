# Classify the three errored assertions of test/sqrt_lasso.jl (lines 359 x2, 363) for X1A / X1B: magnitudes of a, ρ², thresholds.
include("x1lib.jl")
T = Float64
xk = T[1, 2, -1, 0.5]; n = 4; thr = n*(floatmin(T)/eps(T))
s, ys = 530, -400
tiny = T(2)^-s .* xk
for old in (zero(T), T(2)^(ys + s - 2))
  y = T(2)^ys .* T[1, 0, 2, -1]; λ = T(2)^(-s - 1)
  for t in TNAMES
    z, err, r, lam, info = step_in(getproperty(TREES, t), tiny, y, λ, old)
    m, g, x = onecol_model(getproperty(TREES, t), tiny, y, λ, old)
    a, b, ρ2 = getproperty(TREES, t)._column_dot_rsqr(m.ls.X, m.ls.r, 1, T(NaN))
    println("line 359 old=", old, " ", t, ": ", err === nothing ? "ok z=$z" : "THROWS", " | ‖X_k‖=", sqrt(sum(abs2, big.(tiny))) |> Float64, " a=", a, " (n floatmin/eps = ", thr, ", a clean: ", a >= thr, ") ρ²=", ρ2, " (clean: ", ρ2 >= thr, ") ‖r‖=", norm(Float64.(m.ls.r)), " info=", info)
  end
end
sub = T(2)^-1060; y = sub .* T[1, 0, 2, -1]; λ = T(2)^-10
for t in TNAMES
  z, err, r, lam, info = step_in(getproperty(TREES, t), xk, y, λ, zero(T))
  m, g, x = onecol_model(getproperty(TREES, t), xk, y, λ, zero(T))
  a, b, ρ2 = getproperty(TREES, t)._column_dot_rsqr(m.ls.X, m.ls.r, 1, T(NaN))
  println("line 363 ", t, ": ", err === nothing ? "ok z=$z" : "THROWS", " | a=", a, " ρ²=", ρ2, " (computed, underflows to 0: ", iszero(ρ2), ") ‖r‖=", sqrt(sum(abs2, big.(m.ls.r))) |> Float64, " info=", info)
end
