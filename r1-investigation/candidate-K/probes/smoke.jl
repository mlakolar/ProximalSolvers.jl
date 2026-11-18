include("x1lib.jl")
println(VERSION)
for T in (Float32, Float64)
  xk = T[1,2,-1,.5]; y = T[1,0,2,-1]
  for P in values(TREES)
    println(T, " ", step_in(P, xk, y, T(0.5), zero(T))[1], " ", step_in(P, T(2)^-70 .* xk, T(2)^-30 .* y, T(2)^-71, zero(T))[1])
  end
end
