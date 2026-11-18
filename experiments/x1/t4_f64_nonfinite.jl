include("t4_gen.jl")
function main()
T = Float64; rng = Xoshiro(hash((:wide_full, T, 1))); found = 0; tries = 0
while found < 6 && tries < 20000
  tries += 1
  inp = fam_wide_full(rng, T); inp === nothing && continue
  xk, y, λ, old = inp
  z, err, r, lam, info = step_in(TREES.base, xk, y, λ, old)
  err === nothing && !isfinite(z) || continue
  zs = setprecision(BigFloat, 512) do; bigref(xk, r, old, lam).zstar; end
  abs(zs) <= big(floatmax(T)) || continue
  found += 1
  m, g, x = onecol_model(TREES.base, xk, y, λ, old)
  a, b, ρ2 = TREES.base._column_dot_rsqr(m.ls.X, m.ls.r, 1, T(NaN))
  println("n=", length(xk), " info=", info, " a=", a, " b=", b, " ρ²=", ρ2, " old=", old, " λ=", λ, " c≈", Float64(old + big(b)/big(a)), " z*=", Float64(zs), " base z=", z)
end
end
main()
