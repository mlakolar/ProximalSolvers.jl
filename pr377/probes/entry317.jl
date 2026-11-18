# Counts entries into the guarded branch (gradient mode, product exactly 0, 2/xy_sq not finite)
# at the checked-out source, for the cases of the four #317 tests. Counter-only override of
# backtrack! (source read from the loaded package); the guard line itself is unchanged.
using ProximalSolvers, ProximalBase, LinearAlgebra, Random
const PS = ProximalSolvers; const LS = PS.LineSearches
const HITS = Ref(0); const CALLS = Ref(0)
let src = read(joinpath(pkgdir(PS), "src", "line_searches.jl"), String)
  i1 = findfirst("function backtrack!(", src).start; i2 = findfirst("\nhas_updated_gradient", src).start
  body = src[i1:i2]; old = "        iszero(local_l) || (local_l *= 2. / xy_sq)\n"; @assert occursin(old, body)
  body = replace(body, old => "        Main.CALLS[] += 1\n        (iszero(local_l) && !isfinite(2. / xy_sq)) && (Main.HITS[] += 1)\n" * old)
  Core.eval(LS, Meta.parseall(body))
end
function run(name, f, x0, opts)
  x = copy(x0); HITS[] = 0; CALLS[] = 0
  r = try solve!(x, f, NormL1(0.0), ProximalGradientDescent(), opts) catch e; sprint(showerror, e) end
  println(rpad(name, 40), r isa String ? "ERR $r" : "it=$(r.iterations) conv=$(r.converged)", "  gradient-mode estimates=", CALLS[], "  guarded-branch entries=", HITS[])
end
include(joinpath(@__DIR__, "datasets.jl"))
X, y = data("base")
STRICT = ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11)
println(VERSION)
run("test 1: 1x1 default", 1e-170 * LeastSquaresLoss([1.0], [1.0;;]), [0.0], ProximalOptions())
run("test 2: 30x12 α=1e-200 strict", 1e-200 * LeastSquaresLoss(y, X), zeros(12), STRICT)
s = 1e-6
fd = LeastSquaresLoss([0.0, s * 1e-150], [1.0 0; 0 s])
run("test 3: diag default", fd, [0.0, 0.0], ProximalOptions())
run("test 3: diag maxiter=20000", fd, [0.0, 0.0], ProximalOptions(maxiter = 20_000))
# test 4: the direct call, with the helpers of core_regressions.jl
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
HITS[] = 0; CALLS[] = 0
f4, g4 = 1e-170 * LeastSquaresLoss([1.0], [1.0;;]), NormL1(0.0)
st = pgd_trial(f4, g4, [0.0], 3e-9; gradient_mode = true)
ok = try LS.backtrack!(st, ProximalGradientDescent().ls, f4, g4) catch e; sprint(showerror, e) end
println(rpad("test 4: backtrack! unit", 40), "returned=", ok, "  gradient-mode estimates=", CALLS[], "  guarded-branch entries=", HITS[], "  L=", st.L)
