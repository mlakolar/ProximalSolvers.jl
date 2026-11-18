# X3 item 7 at solve level: sqrt-lasso solves that reach _sqrt_offrange_step's recomputed-norm branch (the call of _scaled_norm / _se_norm)
# and the floor64 comparison, BASE vs X3.
#   julia +lts|+release --project=<WORK>/ps-353 x3_sqrt_solves.jl
const HERE = @__DIR__
include(joinpath(HERE, "loadtrees.jl"))
include(joinpath(HERE, "fp_lib.jl"))
println("Julia ", VERSION, " CPU ", Sys.CPU_NAME)
B = BaseMod.ProximalSolvers
# count the calls of the recomputed norm in BASE (redefine _scaled_norm with a counter; same body)
@eval BaseMod.ProximalSolvers begin
  const _CALLS = Ref(0)
  function _scaled_norm(v::AbstractVector, n::Int)
    _CALLS[] += 1
    M = 0.0
    @inbounds for i in 1:n
      M = max(M, abs(Float64(v[i])))
    end
    (iszero(M) || !isfinite(M)) && return (M, 0)
    e = exponent(M)
    s = 0.0
    @inbounds for i in 1:n
      w = ldexp(Float64(v[i]), -e)
      s += w*w
    end
    (sqrt(s), e)
  end
end
rng = Xoshiro(332)
mods = Any[("base", B), (isempty(ARGS) ? "x3" : ARGS[1], isempty(ARGS) || ARGS[1] == "x3" ? X3Mod.ProximalSolvers : X2Mod.ProximalSolvers)]
t = Tally()
calls_total = 0; solves_with_call = 0; nsolve = 0; extra = 0
for T in (Float32, Float64), (n, p) in ((20, 6), (50, 30), (100, 10)), sc in (T === Float32 ? (2.0^-70, 2.0^-64, 2.0^60) : (2.0^-540, 2.0^-515, 2.0^520)),
    noise in (1e-1, 1e-3, 1e-6), frac in (0.05, 0.3, 0.6), order in (:cyclic, :random), kind in (:cold, :warm)
  X, y, β = lsdata(rng, T, n, p; scale = sc, noise = noise)
  lmax = maximum(abs, Float64.(X)' * Float64.(y)) / norm(Float64.(y))
  λ = T(frac * lmax); (isfinite(λ) && λ > 0) || continue
  global nsolve += 1
  B._CALLS[] = 0
  label = "sqrt $T n=$n p=$p scale=$sc noise=$noise frac=$frac $order $kind"
  compare!(t, label, mods, PS -> begin
    x = SparseIterate(kind === :cold ? zeros(T, p) : T.(0.5 .* β))
    r = PS.solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), PS.CDSolver(; order, rng = Xoshiro(5), tol = T === Float64 ? 1e-9 : 1e-4, maxpasses = 4000))
    (r, x)
  end)
  # base runs once inside compare!, so B._CALLS counts that run (plus nothing from X3)
  c = B._CALLS[]; global calls_total += c; c > 1 && (global solves_with_call += 1); global extra += max(c - 1, 0)
end
println("solves: $nsolve; solves in which BASE called _scaled_norm beyond the one call of _prepare! (the off-range recomputed norm): $solves_with_call; such calls in total: $extra")
println("comparisons=$(t.n) mismatches=$(length(t.mismatches)) (base converged $(t.converged), base threw $(t.errors))")
for (e, c) in t.errmsgs; println("   base threw x", c, ": ", e); end
for m in t.mismatches[1:min(end, 15)]; println("MISMATCH ", first(m, 300)); end
