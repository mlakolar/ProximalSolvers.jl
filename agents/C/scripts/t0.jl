include(joinpath(@__DIR__, "lib.jl"))
for id in ["A156", "N8p20-0.2-s1", "N100p400-s1"], T in (Float64, Float32)
  prob = problem(id); o = oracle(id, T); X, y, λ = data(prob, T)
  sk = :given in prob.starts ? :given : :lnfit
  β0, conv, ps = stuck_point(X, y, λ, T.(start_point(prob, sk, o.β)))
  t = @timed fallback(X, y, λ, β0; stages = 6)
  f = t.value
  println(id, " ", T, " conv0=", conv, " certified=", f.certified, " stages=", f.nstages, " passes=", f.passes, " ratio=", f.ratio, " Pstuck=", f.Pstuck, " P=", f.P, " Pstar∈[", o.D, ",", o.U, "]")
  for l in f.log; println("   ", l); end
end
