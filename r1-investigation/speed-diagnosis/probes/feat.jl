using InteractiveUtils
function kern(X::Vector{Float64}, r::Vector{Float64})
  b = 0.0; ρ2 = 0.0
  @inbounds @simd for i in eachindex(r)
    b += r[i]*X[i]; ρ2 += r[i]*r[i]
  end
  b, ρ2
end
io = IOBuffer(); code_native(io, kern, Tuple{Vector{Float64},Vector{Float64}}; debuginfo=:none); s = String(take!(io))
println(VERSION, " ", Sys.CPU_NAME, " cpu_target=", Base.JLOptions().cpu_target, " ymm=", count("ymm", s), " zmm=", count("zmm", s), " fma=", count("vfmadd", s), " xmm=", count("xmm", s))
