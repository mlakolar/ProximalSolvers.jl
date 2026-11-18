function pgd_trial(f, g, x0, L; gradient_mode = false, method = ProximalGradientDescent())
  st = PS.initial_state(method, ProximalOptions(), f, g, copy(x0))
  st.backtrack_simple = !gradient_mode
  PS._copyto!(st.x_previous, st.x)
  st.f_x_previous, st.g_x_previous = st.f_x, st.g_x
  PS._copyto!(st.grad_f_x_previous, st.grad_f_x)
  st.L = L
  PS._step!(st.xhat, st.x_previous, st.grad_f_x_previous, st.L)
  st.g_x = convert(eltype(st.x), PS.value_and_prox!(st.x, g, st.xhat, one(L) / L))
  st.f_x = PS._value!(st.x, f, st.model, st.z_x)
  st
end

# A trial at the given point x from xprev at curvature L, with the stored values as
# update_state! leaves them before backtrack!
function pgd_pair_trial(f, g, xprev, x, L; method = ProximalGradientDescent())
  st = PS.initial_state(method, ProximalOptions(), f, g, copy(xprev))
  PS._copyto!(st.x_previous, st.x)
  st.f_x_previous, st.g_x_previous = st.f_x, st.g_x
  PS._copyto!(st.grad_f_x_previous, st.grad_f_x)
  st.L = L
  copyto!(st.x, x)
  st.g_x = convert(eltype(st.x), g(st.x))
  st.f_x = PS._value!(st.x, f, st.model, st.z_x)
  st
end

pgd_fixture() = ([1. 1 .2; 2 1 .3; -1 0 .5; .1 1 1; .4 .3 -.8; -.2 .8 .1; .6 -.1 .2],
                 [2., 1, -1, .4, -.5, .7, .9])

