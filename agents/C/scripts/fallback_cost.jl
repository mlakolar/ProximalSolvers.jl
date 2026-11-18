# PROTOTYPE (not production evidence): cost of the smoothing fallback with the δ in the coordinate step (proto/fb) versus the base solve that
# preceded it, vs problem size. Fallback = track schedule, c = 1, half-decade or decade steps, stage solver = change test with the default
# tolerance, certificate evaluated (and timed) after each stage; returns when the BigFloat bound certifies or the stage budget is hit.
ENV["PERT_VARS"] = "old,fb"
include(joinpath(@__DIR__, "perf_load.jl")); include("<RUN>/scripts/matrix.jl")
using Logging, Printf
PS = mod("fb"); PO = mod("old")
setprecision(BigFloat, 256)
Pbig(X, y, λ, b) = norm(big.(y) - big.(X) * big.(b)) + big(λ) * norm(big.(b), 1)
function dres(X, y, λ, β)
  Xb = big.(X); yb = big.(y); r = yb - Xb * big.(β); nr = norm(r); iszero(nr) && return big(0.0)
  t = min(big(1), big(λ) / (maximum(abs, Xb' * r) / nr)); t * dot(r, yb) / nr * (1 - big(10)^-60)
end
println("problem T | base: passes sec | fallback: stages passes sec(stage solves) sec(certs) MB(alloc of stage solves) certified ratio | secs/pass base vs fallback")
for (n, p, k, f, sd) in ((20, 80, 3, 0.1, 31), (50, 200, 5, 0.1, 32), (100, 400, 10, 0.1, 33), (200, 800, 10, 0.1, 34), (200, 2000, 10, 0.05, 35), (500, 2000, 10, 0.1, 36)), T in (Float64, Float32)
  X0, y0 = noiseless(n, p, k, 5000 + sd); X, y = T.(X0), T.(y0); λ = T(f * lammax(X0, y0)); g = NormL1(λ); fl = SqrtLeastSquaresLoss(y, X)
  β0 = T.(pinv(X0) * y0); x = copy(β0)
  r0 = with_logger(NullLogger()) do; PO.solve!(x, fl, g, PO.CDSolver(order = :cyclic, momentum = false)); end
  tb = with_logger(NullLogger()) do; @elapsed (xx = copy(β0); PO.solve!(xx, fl, g, PO.CDSolver(order = :cyclic, momentum = false))); end
  Pst = Pbig(X, y, λ, x); β = copy(x); bestP = Pst; bestD = dres(X, y, λ, x); δ = Float64(Pst)
  passes = 0; ts = 0.0; tc = 0.0; mb = 0.0; certified = false; ns = 0; ratio = Inf
  solver = PS.CDSolver(order = :cyclic, momentum = false, maxpasses = 20_000)
  PS.smoothed_stage!(copy(β), fl, g, solver, δ)   # compile
  for j in 0:15
    j > 0 && (δ = min(δ / 10, Float64(bestP)))
    bytes = @allocated (st = @timed PS.smoothed_stage!(β, fl, g, solver, δ)); ps, cv = st.value
    passes += ps; ts += st.time; mb += bytes / 2^20; ns += 1
    tc += PS.certify_time(fl, g, β, 3)
    P = Pbig(X, y, λ, β); D = dres(X, y, λ, β); bestP = min(bestP, P); bestD = max(bestD, D)
    ratio = bestD > 0 ? Float64((bestP - bestD) / bestD) : Inf
    ratio <= 1e-4 && (certified = true; break)
  end
  @printf "n=%d p=%d k=%d %s | base passes=%d sec=%.4f | fb stages=%d passes=%d solve=%.4fs cert=%.4fs alloc=%.2fMB cert=%s ratio=%.1e | sec/pass base=%.2e fb=%.2e | X MB=%.2f\n" n p k T r0.passes tb ns passes ts tc mb certified ratio tb / r0.passes ts / max(passes, 1) sizeof(X) / 2^20
end
