# #311 diagnosis: trace the stalled run (warm, random, momentum=false, dense; run under
# --code-coverage=user), then at the stalled point check against BigFloat-256:
#  (1) curvature a_k as computed in Float32 vs exact;
#  (2) each Float32 coordinate step vs the exact soft-threshold step from the same Float32 state;
#  (3) where the KKT violation sits (active coordinates vs the coordinate held at 0);
#  (4) the per-pass change of the active coordinates in ulps and against the threshold.
using LinearAlgebra, Random, ProximalBase, ProximalSolvers, Printf, Logging
const PS = ProximalSolvers
include(joinpath(@__DIR__, "fixture311.jl"))

const TRACE = Any[]
@eval PS function _pass!(x, m, g, st::_CDState{T}, full::Bool, scaled::Bool) where {T}
  maxh = if full
    _sweep!(x, m, g, st, scaled, Base.OneTo(ncoordinates(x)))
  else
    _sweep!(x, m, g, st, scaled, activecoordinates(x))
  end
  dropzeros!(x)
  push!($TRACE, (full, Vector(x), maxh, collect(activecoordinates(x))))
  maxh
end

T = Float32
X, y, c, α, f, λ = fixture311()
p = size(X, 2)
x0 = T.(c .* (0.3 .* sin.(1:p)))
solver = CDSolver(; order = :random, momentum = false, maxpasses = 2000, tol = 1e-7, relative = true, rng = Xoshiro(5))
x = copy(x0)
r = with_logger(NullLogger()) do; solve!(x, f, NormL1(λ), solver); end
@printf "Julia %s coverage=%d: converged=%s passes=%d maxchange=%.3e tolerance=%.3e\n" VERSION Base.JLOptions().code_coverage r.converged r.passes r.maxchange r.tolerance
println("x0 = ", x0)
for i in [1:6; length(TRACE)-3:length(TRACE)]
  t = TRACE[i]
  @printf "pass %4d full=%-5s maxh=%.3e active=%s x=%s\n" i t[1] t[3] string(t[4]) string(t[2])
end
b = reference_lasso(X, y, α, λ)
println("BigFloat reference x* = ", Float64.(b))

setprecision(BigFloat, 256) do
  Xb, yb, xb, ab, lb = big.(X), big.(y), big.(x), big(α), big(λ)
  a_exact = [sum(abs2, Xb[:, k]) for k in 1:p]
  a32 = [sum(abs2, X[:, k]) for k in 1:p]  # sequential Float32 sum (the coverage summation order)
  for k in 1:p
    @printf "(1) a_%d: Float32 %.9e exact %.9e rel.err %.2e  τ_k=λ/(α a_k)=%.6e\n" k a32[k] Float64(a_exact[k]) Float64((big(a32[k]) - a_exact[k]) / a_exact[k]) Float64(lb / (ab * a_exact[k]))
  end
  d = ab .* (Xb' * (Xb * xb .- yb))
  for k in 1:p
    v = iszero(xb[k]) ? max(abs(d[k]) - lb, 0) : abs(d[k] + lb * sign(xb[k]))
    @printf "(3) coord %d x=% .7e  |d_k|/λ=%.6f  KKT_k/max(λ,‖αXᵀy‖∞)=%.3e %s\n" k Float64(xb[k]) Float64(abs(d[k]) / lb) Float64(v / max(lb, maximum(abs, ab .* (Xb' * yb)))) (iszero(xb[k]) ? "(held at 0, never visited)" : "")
  end
end

# (2) step accuracy: replay one active pass from the stalled point coordinate by coordinate in Float32
# with the package's own coordinate step, and compare each new value to the exact step from the same
# Float32 state (exact centre x + rᵀX_k/a_k and threshold λ/(α a_k), soft threshold, then rounding).
m = PS.cdmodel(f, nothing)
xs = SparseIterate(copy(x))
PS.initialize!(m, xs)
g = NormL1(λ)
worst = 0.0
for sweep in 1:20, k in collect(ProximalBase.activecoordinates(xs))
  local xk_state = copy(Vector(xs))
  new_exact = setprecision(BigFloat, 256) do
    Xb, yb, xb = big.(X), big.(y), big.(xk_state)
    rb = yb .- Xb * xb                       # exact residual of the Float32 state
    ak = sum(abs2, Xb[:, k])
    z = xb[k] + dot(Xb[:, k], rb) / ak
    t = big(λ) / (big(α) * ak)
    sign(z) * max(abs(z) - t, 0)
  end
  PS.coordinate_step!(m, g, xs, k)
  err_ulps = Float64(abs(big(xs[k]) - new_exact) / eps(Float32(abs(new_exact))))
  global worst = max(worst, err_ulps)
end
@printf "(2) 20 replayed active passes: worst |Float32 step − exact step from same state| = %.2f ulp of the new value\n" worst
# the exact step from the same state is a contraction; what is its size?
let xs = Vector(x)
  dx = setprecision(BigFloat, 256) do
    Xb, yb = big.(X), big.(y)
    xb = big.(xs)
    for k in findall(!iszero, xs)
      rb = yb .- Xb * xb; ak = sum(abs2, Xb[:, k])
      z = xb[k] + dot(Xb[:, k], rb) / ak; t = big(λ) / (big(α) * ak)
      xb[k] = sign(z) * max(abs(z) - t, 0)
    end
    Float64.(xb .- big.(xs))
  end
  println("(4) exact active pass from the stalled point moves x by ", dx, " (coefficient units)")
  println("    ulp of active x: ", [eps(abs(v)) for v in xs], "; ulp of centre ≈2|x|: ", [eps(2abs(v)) for v in xs])
end
# coefficient-unit equivalent of the threshold: tol·√α‖y‖ / √(α a_k)
for k in 1:p
  @printf "(4) threshold in coefficient units, coord %d: %.3f\n" k Float64(r.tolerance / PS.coordinate_scale(m, xs, k))
end
hs = [TRACE[i][3] / r.tolerance for i in 2:length(TRACE)]
@printf "(4) active passes 2..2000: maxchange/tolerance min %.3f median %.3f max %.3f; active set constant = %s\n" minimum(hs) sort(hs)[end÷2] maximum(hs) all(t -> t[4] == TRACE[2][4], TRACE[2:end])
