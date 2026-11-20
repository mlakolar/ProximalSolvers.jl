# #400: per-check cost of the NormLinf criteria at one point, given ∇f(x) (which PGD holds and APG forms once per
# check either way), in-process, median of repeated evaluations over a pool of fresh points.
#   gen : u = x - t∇f, prox_{t g}(u), ‖x - p‖∞ (the extra work of STOP-07 beyond the gradient)
#   kkt : kkt_violation(NormLinf(λ), ∇f, x)
#   gap : r = y - X x, ⟨r, y⟩, ‖r‖², ‖∇f‖₁ (the residual from the cached image costs O(n); here X x is timed separately)
#   grad: ∇f(x) = s Xᵀ(X x - y) (for comparison)
using ProximalSolvers, ProximalBase, LinearAlgebra, Random, Printf
BLAS.set_num_threads(1)
println("julia ", VERSION, " CPU ", Sys.cpu_info()[1].model)
function bench(f, pool; reps = 200)
  f(pool[1])
  ts = Float64[]
  acc = 0.0
  for r in 1:reps
    k = mod1(r, length(pool))
    t0 = time_ns()
    acc += f(pool[k])
    push!(ts, (time_ns() - t0) / 1e3)
  end
  sort!(ts)
  ts[length(ts) ÷ 2], acc
end
for T in (Float64, Float32), (n, p) in ((40, 12), (200, 1000), (2000, 5000))
  rng = Xoshiro(400)
  X = T.(randn(rng, n, p)); y = T.(X * [ones(5); zeros(p - 5)] .+ randn(rng, n))
  f = LeastSquaresLoss(y, X)
  λ = T(0.3 * sum(abs, X' * y))
  g = NormLinf(λ)
  L = T(opnorm(Float64.(X))^2)
  # points: iterates of a short PGD run from different starts (ties at the max level as the prox produces them)
  pool = map(1:20) do i
    x = T.(0.01 .* randn(rng, p))
    solve!(x, f, g, ProximalGradientDescent(), ProximalOptions(maxiter = 30 + i, ftol = 0, gradtol = 0, xtol = 1e-300))
    grad = similar(x); gradient!(grad, f, x)
    (x, grad)
  end
  buf, u = zeros(T, p), zeros(T, p)
  t = one(T) / L
  tg, a1 = bench(pool) do (x, grad)
    @. u = x - t * grad
    prox!(buf, g, u, t)
    Float64(maximum(abs(x[i] - buf[i]) for i in eachindex(x)))
  end
  tk, a2 = bench(pool) do (x, grad)
    Float64(kkt_violation(g, grad, x))
  end
  r = zeros(T, n)
  tp, a3 = bench(pool) do (x, grad)
    mul!(r, X, x); r .= y .- r
    Float64(dot(r, y) - sum(abs2, r) + sum(abs, grad))
  end
  tgr, a4 = bench(pool) do (x, grad)
    gradient!(buf, f, x); Float64(buf[1])
  end
  @printf("%s n=%5d p=%5d  median µs: gen-extra %9.2f  kkt %9.2f  gap(incl. Xx) %9.2f  grad %9.2f\n", T, n, p, tg, tk, tp, tgr)
end
