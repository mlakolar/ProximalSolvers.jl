# The residual case of the docs: nonzero product, subnormal ‖d̂‖², sum(abs2, d̂) = 0 -> error at head
using ProximalSolvers, ProximalBase, LinearAlgebra
const PS = ProximalSolvers; const LS = PS.LineSearches
function pair(f, g, xprev, x, L; gradient_mode = true, method = ProximalGradientDescent())
  st = PS.initial_state(method, ProximalOptions(), f, g, copy(xprev))
  st.backtrack_simple = !gradient_mode
  PS._copyto!(st.x_previous, st.x)
  st.f_x_previous, st.g_x_previous = st.f_x, st.g_x
  PS._copyto!(st.grad_f_x_previous, st.grad_f_x)
  st.L = L
  copyto!(st.x, x)
  st.g_x = convert(eltype(st.x), g(st.x))
  st.f_x = PS._value!(st.x, f, st.model, st.z_x)
  st
end
f = LeastSquaresLoss([0.0, 0.0], [2.0 0; 0 2.0]); g = NormL1(0.0)
for e in (1.2e-162, 1.6e-162)
  st = pair(f, g, [0.0, 0.0], [e, e], 1e-3)
  PS._sub!(st.delta_x, st.x, st.x_previous)
  xy = PS._norm(st.delta_x)^2
  LS.value_and_gradient_at_x!(st, f)
  prod = PS._dot_diff(Float64, st.grad_f_x, st.grad_f_x_previous, st.delta_x)
  st = pair(f, g, [0.0, 0.0], [e, e], 1e-3)
  r = try LS.backtrack!(st, ProximalGradientDescent().ls, f, g) catch ex; sprint(showerror, ex) end
  println("entries ", e, ": xy_sq=", xy, " sum(abs2)=", sum(abs2, st.delta_x), " product=", prod, " -> ", r)
end
