# Which reproducers reach the 0·Inf path (gradient mode, dot product 0, 2/‖d̂‖² = Inf) under the
# checked-out L₀ rule? Counter-only override of backtrack! (source read from the loaded package).
using ProximalSolvers, ProximalBase, LinearAlgebra, Random
const PS = ProximalSolvers; const LS = PS.LineSearches
const HITS = Ref(0)
let src = read(joinpath(pkgdir(PS), "src", "line_searches.jl"), String)
  i1 = findfirst("function backtrack!(", src).start; i2 = findfirst("\nhas_updated_gradient", src).start
  body = src[i1:i2]; old = "        local_l *= 2. / xy_sq\n"; @assert occursin(old, body)
  body = replace(body, old => "        (iszero(local_l) && !isfinite(2. / xy_sq)) && (Main.HITS[] += 1)\n" * old)
  Core.eval(LS, Meta.parseall(body))
end
function run(name, f, x0, opts)
  x = copy(x0); HITS[] = 0
  r = try solve!(x, f, NormL1(0.0), ProximalGradientDescent(), opts) catch e; sprint(showerror, e) end
  println(rpad(name, 44), r isa String ? "ERR  $r" : "it=$(r.iterations) conv=$(r.converged)", "  zeroInf_hits=", HITS[], "  x1=", x[end])
end
rng = Xoshiro(296); X = randn(rng, 30, 12); β = zeros(12); β[1:4] .= [2.0, -1.5, 1.0, 0.5]; y = X*β + 0.3*randn(rng, 30)
STRICT = ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11)
run("1x1 α=1e-170 default", 1e-170 * LeastSquaresLoss([1.0], [1.0;;]), [0.0], ProximalOptions())
run("30x12 α=1e-200 strict", 1e-200 * LeastSquaresLoss(y, X), zeros(12), STRICT)
for s in (1e-2, 1e-3, 1e-4, 1e-6), xs in (1e-150, 1e-155, 1e-158, 1e-160, 1e-165)
  # X = diag(1, s): ‖X‖_F² ≥ 1, so L₀ = 1 under both rules; the solution is (0, xs)
  run("diag(1,$s) x*=(0,$xs) default", LeastSquaresLoss([0.0, s*xs], [1.0 0; 0 s]), [0.0, 0.0], ProximalOptions())
end
