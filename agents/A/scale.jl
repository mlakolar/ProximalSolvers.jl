# Cost of the candidates relative to a CD solve on larger noiseless problems (exact-fit optimum expected).
include(joinpath(@__DIR__, "lib.jl"))
using Printf
function run1(n, p, k, seed, f, T)
  X0, y0 = noiseless(n, p, k, seed); λ = f*lammax(X0, y0)
  X, y, λT = T.(X0), T.(y0), T(λ)
  t0 = time(); x, r, sec, _ = ps_solve(X, y, λT, zeros(T, p); order = :cyclic, momentum = false); tsolve = time() - t0
  β = Float64.(x); Xd, yd, λd = Float64.(X), Float64.(y), Float64(λT)
  chk(θ) = vcert(Xd, yd, λd, λd, β, θ)
  nnz = count(!iszero, β)
  t1 = time(); c = cand_Bcm(Xd, yd, λd, β, chk); tB = time() - t1
  v = c.θ === nothing ? (; ok = false, ratio = NaN) : chk(c.θ)
  t2 = time(); vv = chk(zeros(n) .+ 1e-3); tV = time() - t2        # one validator call (O(np))
  t3 = time(); code, ratio = certify_at(X, y, λT, x); tR = time() - t3
  @printf "%s n=%d p=%d f=%.2f: CD passes=%d conv=%s solve=%.2fs nnz=%d | Bcm ok=%s ratio=%.2e time=%.3fs | validator call %.4fs | production certify %.4fs (%s)\n" T n p f r.passes r.converged tsolve nnz v.ok v.ratio tB tV tR code
end
for T in (Float64, Float32), (n, p, k) in ((100, 400, 10), (500, 2000, 20), (1000, 5000, 30)), f in (0.05, 0.2)
  run1(n, p, k, 7, f, T)
end
