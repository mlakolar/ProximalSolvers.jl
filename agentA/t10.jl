using ProximalBase, ProximalSolvers
for T in (Float32, Float64)
  g = NormL1(T(0.3))
  println(T, " prox_block step 0: ", prox_block(g, T(2.5), 1, zero(T)), "  step Inf: ", prox_block(g, T(2.5), 1, T(Inf)), " step floatmin/2:", prox_block(g, T(2.5), 1, floatmin(T)/2))
end
using ProximalBase
println(ProximalBase.NormL2(1.0f0)(Float32[3,4]), " ", ProximalBase.NormL2(1.0)([1e200, 1e200]), " ", ProximalBase.NormL2(1.0)([1e-200, 1e-200]))
