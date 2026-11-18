using ProximalSolvers, InteractiveUtils, ProximalBase, Printf
const PS = ProximalSolvers
println("Julia ", VERSION, " CPU: ", Sys.CPU_NAME)
function nfma(f, types)
  io = IOBuffer()
  code_native(io, f, types; debuginfo = :none)
  s = String(take!(io))
  (count(r"vfm(add|sub|nadd|nsub)\d*s[ds]|vfm(add|sub)\d*p[ds]", s), count(r"vfm", s), length(split(s, '\n')))
end
for T in (Float32, Float64)
  M = PS.SqrtLSModel{T, PS.LSModel{T, T, Matrix{T}, Vector{T}}}
  println(T, " _certify!           (fma instr, total vfm*, lines): ", nfma(PS._certify!, (M, ProximalBase.SparseIterate{T})))
  println(T, " _column_dot_rsqr    : ", nfma(PS._column_dot_rsqr, (Matrix{T}, Vector{T}, Int, T)))
  println(T, " _distance_sqr       : ", nfma(PS._distance_sqr, (Matrix{T}, Vector{T}, Int, T)))
  println(T, " _sqrt_offrange_step : ", nfma(PS._sqrt_offrange_step, (M, T, Int)))
  println(T, " _residual_axpy!     : ", nfma(PS._residual_axpy!, (PS.LSModel{T, T, Matrix{T}, Vector{T}}, Int, T)))
end
