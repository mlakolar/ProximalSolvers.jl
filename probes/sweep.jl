# #307 numerical sweep through the public API only, so the same script runs on arms A, B and C.
#   julia --startup-file=no --project=<PS checkout> sweep.jl ARM [quick]
# One CSV row per solve on stdout (header first). For every solve: whether it returned or threw (and
# the message), whether the caller's iterate is unchanged after a throw, whether the loss's scratch
# f.tmp changed, the reported minimum against a 256-bit objective at the returned point, and the
# relative KKT residual of the returned point (256-bit, against the scale as supplied).
using LinearAlgebra, Random
using ProximalSolvers, ProximalBase
const PS = ProximalSolvers
setprecision(BigFloat, 256)
const ARM = ARGS[1]
const QUICK = length(ARGS) > 1 && ARGS[2] == "quick"
BLAS.set_num_threads(1)

base_of(f) = f isa ProximalBase.LeastSquaresLoss ? f : f.f
scale_of(f) = f isa ProximalBase.LeastSquaresLoss ? 1 : f.α
bigobj(X, y, α, λ, x) = big(α) * sum(abs2, big.(X) * big.(x) .- big.(y)) / 2 + big(λ) * sum(abs, big.(x))
function kkt(X, y, α, λ, x)
  Xb, yb, xb = big.(X), big.(y), big.(x)
  G = big(α) .* (Xb' * (Xb * xb .- yb))
  v = [xi != 0 ? abs(G[i] + big(λ) * sign(xi)) : max(abs(G[i]) - big(λ), big(0)) for (i, xi) in enumerate(xb)]
  den = max(big(λ), maximum(abs, big(α) .* (Xb' * yb)), floatmin(Float64))
  Float64(maximum(v) / den)
end
relerr(a, r) = isfinite(a) ? Float64(abs(big(a) - r) / max(abs(r), big(nextfloat(zero(Float64))))) : Inf
esc(s) = replace(first(s, 160), r"[,\n\r]" => ";")
dense(x) = x isa SparseIterate ? [x[i] for i in 1:length(x)] : copy(x)

const ACC = PS.ProximalOptions(maxiter = 10_000, ftol = 0, xtol = 1e-14, gradtol = 1e-10, allow_f_increases = true)
solvers(T) = (("cd", false, () -> PS.CDSolver(order = :cyclic), nothing),
              ("cd-sparse", true, () -> PS.CDSolver(order = :cyclic), nothing),
              ("pg", false, () -> PS.ProximalGradientDescent(), nothing),
              ("apg", false, () -> PS.AccProxGradDescent(), nothing),
              ("pg-acc", false, () -> PS.ProximalGradientDescent(), ACC),
              ("apg-acc", false, () -> PS.AccProxGradDescent(), ACC))

println("arm,version,case,T,scale,solver,start,outcome,message,x_unchanged,tmp_unchanged,minimum,obj_relerr,kkt,iters,converged,stagnated")
function run1(case, f, λ, x0, sname, sparse, mk, opts; start = "cold")
  b = base_of(f); X, y = b.X, b.Y; α = scale_of(f); T = eltype(X)
  tmp0 = copy(b.tmp)
  x = sparse ? SparseIterate(x0) : copy(x0)
  xin = dense(x)
  g = ProximalBase.NormL1(T(λ))
  outcome, msg, res = "ok", "", nothing
  try
    res = opts === nothing ? solve!(x, f, g, mk()) : solve!(x, f, g, mk(), opts)
  catch e
    outcome, msg = "threw", esc(sprint(showerror, e))
  end
  tmpok = isequal(b.tmp, tmp0)
  xd = dense(x)
  if res === nothing
    row = (ARM, VERSION, case, T, string(typeof(α), ":", α), sname, start, outcome, msg, isequal(xd, xin), tmpok,
           "", "", "", "", "", "")
  else
    m = res.minimum
    ref = bigobj(X, y, α, λ, xd)
    it = hasproperty(res, :iterations) ? res.iterations : res.passes
    stg = hasproperty(res, :stagnated) ? res.stagnated : ""
    row = (ARM, VERSION, case, T, string(typeof(α), ":", α), sname, start, outcome, msg, "", tmpok,
           m, relerr(m, ref), kkt(X, y, α, λ, xd), it, res.converged, stg)
  end
  println(join(row, ","))
  flush(stdout)
end
function family(case, f, λfrac; x0 = nothing, starts = ("cold", "warm"), which = nothing)
  b = base_of(f); X, y = b.X, b.Y; α = scale_of(f); T = eltype(X)
  λmax = Float64(maximum(abs, big(α) .* (big.(X)' * big.(y))))
  λ = λfrac * λmax
  for (sname, sparse, mk, opts) in solvers(T)
    which === nothing || sname in which || continue
    (opts !== nothing && T === Float32) && continue          # the acc setting is Float64-only
    for st in starts
      z = x0 === nothing ? zeros(T, size(X, 2)) : copy(x0)
      if st == "warm"
        try solve!(z, f, ProximalBase.NormL1(T(1.25 * λ)), PS.CDSolver(order = :cyclic)) catch end
      end
      run1(case, f, λ, z, sname, sparse, mk, opts; start = st)
    end
  end
end
function design(::Type{T}, n, p; seed = 307, ρ = 0.0) where {T}
  rng = Xoshiro(seed + n + 7p)
  Z = randn(rng, n, p)
  X = sqrt(1 - ρ) .* Z .+ sqrt(ρ) .* randn(rng, n)
  β = zeros(p); β[1:min(3, p)] .= (2.0, -1.5, 1.0)[1:min(3, p)]
  X, β, rng
end
for T in (Float64, Float32)
  X64, β, rng = design(T, 57, 13)
  y64 = X64 * β .+ 0.3 .* randn(rng, 57)
  X, y = T.(X64), T.(y64)
  for (sc, mkf) in (("raw", () -> LeastSquaresLoss(y, X)), ("scaledT", () -> (one(T) / T(57)) * LeastSquaresLoss(y, X)),
                    ("scaled64", () -> (1 / 57) * LeastSquaresLoss(y, X)), ("int3", () -> 3 * LeastSquaresLoss(y, X)))
    T === Float64 && sc == "scaled64" && continue
    family("rand-$sc", mkf(), 0.1)
  end
  QUICK && continue
  # exact and near-exact fits
  Xe, βe, rng = design(T, 40, 8; seed = 11)
  ye = T.(Xe * βe); Xe = T.(Xe)
  family("exact-l0", LeastSquaresLoss(ye, Xe), 0.0; starts = ("cold",))
  family("exact-l1e-6", LeastSquaresLoss(ye, Xe), 1e-6; starts = ("cold",))
  yn = T.(Float64.(Xe) * βe .+ 1e-10 .* randn(rng, 40))
  family("near-l1e-6", (1 / 40) * LeastSquaresLoss(yn, Xe), 1e-6; starts = ("cold",))
  # zero column and cancellation
  Xz = copy(X); Xz[:, 4] .= 0
  family("zerocol", LeastSquaresLoss(y, Xz), 0.1; starts = ("cold",))
  Xc = copy(X64); Xc[:, 1] .= 1e4
  yc = 1e8 .+ Xc * β .+ 0.3 .* randn(rng, 57)
  family("cancel", (1 / 57) * LeastSquaresLoss(T.(yc), T.(Xc)), 0.05; starts = ("cold",))
  # large n (value path at 10^6 rows)
  Xl, βl, rngl = design(T, 1_000_000, 4; seed = 5)
  yl = T.(Xl * βl .+ randn(rngl, 1_000_000)); Xl = T.(Xl)
  family("largen", (1 / 1_000_000) * LeastSquaresLoss(yl, Xl), 0.1; starts = ("cold",), which = ("cd", "pg", "apg"))
  Xl = yl = nothing; GC.gc()
end
QUICK && exit()
# extreme but representable scales (scale as supplied; data scaled so that the objective is O(1))
Xs, βs, rngs = design(Float64, 30, 5; seed = 3)
ys = Xs * βs .+ 0.2 .* randn(rngs, 30)
family("F64-alpha1e-300", 1e-300 * LeastSquaresLoss(ys .* 1e150, Xs .* 1e150), 0.1; starts = ("cold",))
family("F64-alpha1e280", 1e280 * LeastSquaresLoss(ys .* 1e-140, Xs .* 1e-140), 0.1; starts = ("cold",))
family("F64-alpha-subnormal1e-310", 1e-310 * LeastSquaresLoss(ys .* 1e155, Xs .* 1e155), 0.1; starts = ("cold",))
# #277 R1-R5
X1 = fill(1e308, 1, 2)
for s in ("pg", "apg")
  run1("R1", LeastSquaresLoss([1.0], X1), 0.0, [2.0, -2.0], s, false,
       s == "pg" ? (() -> PS.ProximalGradientDescent()) : (() -> PS.AccProxGradDescent()), nothing)
end
X2, β2, r2 = design(Float64, 20, 4; seed = 20277)
y2 = X2 * β2 .+ 0.1 .* randn(r2, 20)
family("R2-underflow", LeastSquaresLoss(y2 .* 1e-160, X2 .* 1e-160), 0.0; starts = ("cold",), which = ("cd", "pg", "apg"))
X3, β3, r3 = design(Float32, 40, 5; seed = 20278)
y3 = Float32.(X3 * β3 .+ 0.1 .* randn(r3, 40)) .* 1f18; X3 = Float32.(X3) .* 1f18
for fr in (0.0, 0.1, 0.5)
  family("R3-f32-alpha1e-39-l$fr", 1e-39 * LeastSquaresLoss(y3, X3), fr; starts = ("cold",), which = ("cd", "pg", "apg"))
end
family("R4-f32-alpha1e-44", 1e-44 * LeastSquaresLoss(y3, X3), 0.1; starts = ("cold",), which = ("cd", "pg", "apg"))
family("R5", 1e-100 * LeastSquaresLoss(fill(1e160, 5), ones(5, 1)), 0.0; starts = ("cold",), which = ("cd", "pg", "apg"))
# an overflowing difference z - Y at the start (z = 1e308, Y = -1e308) with a scale that keeps the value finite
family("zminusY-overflow", 1e-310 * LeastSquaresLoss([-1e308], fill(1e308, 1, 1)), 0.0; x0 = [1.0], starts = ("cold",),
       which = ("cd", "pg", "apg"))
# rollback: APG whose curvature cannot increase finitely (from the test suite)
Xf = fill(sqrt(floatmax(Float64)) * sqrt(2.0) * (1 + 5e-9), 1, 1)
run1("rollback-apg", 0.5 * LeastSquaresLoss([1.0], Xf), 0.0, [0.0], "apg-beta", false,
     () -> PS.AccProxGradDescent(α = 1.0, β = nextfloat(1 / floatmax(Float64))), nothing)
# loss-scale domain (D1): which scales each arm accepts, and the caller's iterate after a refusal
for T in (Float64, Float32)
  Xd, βd, rd = design(T, 20, 3; seed = 9)
  yd = T.(Xd * βd .+ 0.1 .* randn(rd, 20)); Xd = T.(Xd)
  for α in (2, true, UInt8(3), 2^24, 2^24 + 1, 2^53, 2^53 + 1, big(2), big(2.0), 1 // 4, Float16(0.5), π, 0.25f0, 0.25,
            1e-44, 1e-300)
    f = try α * LeastSquaresLoss(yd, Xd) catch; continue end
    for (sname, sparse, mk, opts) in solvers(T)
      opts === nothing || continue
      run1("scale-domain", f, 0.0, T[0.5, -0.5, 0.25], sname, sparse, mk, nothing)
    end
  end
end
