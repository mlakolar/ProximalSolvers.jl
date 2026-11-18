using InteractiveUtils, ProximalBase
const sel(c::T, τ::T) where T = c > τ ? c - τ : (c < -τ ? c + τ : zero(T))
@inline function pnn(v::T, c::T) where T
  lo = -c; m = ifelse(v > lo, v, lo); (v - ifelse(m < c, m, c)) + zero(T)
end
println("### ", VERSION, " ", Sys.CPU_NAME)
for (nm, f) in (("shrink", ProximalBase.shrink), ("select", sel), ("pnn", pnn)), T in (Float64, Float32)
  io = IOBuffer(); code_native(io, f, Tuple{T,T}; debuginfo = :none); s = String(take!(io))
  io2 = IOBuffer(); code_llvm(io2, f, Tuple{T,T}; debuginfo = :none, optimize = true); l = String(take!(io2))
  ins = [split(strip(x))[1] for x in split(s, '\n') if (y = strip(x); !isempty(y) && !startswith(y, '.') && !startswith(y, ';') && !endswith(y, ':') && !startswith(y, '#'))]
  println(rpad("$nm $T", 12), " ninstr=", length(ins), " ", join(sort(unique(ins)), ","))
  nm == "shrink" && T == Float64 && println(l)
end
