**Reproducible case for the LS coordinate-descent false `converged = true` (from the #353 audit; left to this issue by the maintainer's decision on #353)**

The maintainer's decisions on #353 ([comment](https://github.com/mlakolar/ProximalSolvers.jl/issues/353#issuecomment-6969675059)) leave this finding to #352 and rule out the Float64 refusal of the square-root lasso prototype, so **item 2 of the cross-reference above no longer applies**: #353 will not change any square-root lasso outcome class. This comment makes item 1 self-contained.

**What happens.** With one column, `X` entries `2^-500`, `y` entries `2^-700` and the loss scale `2^300` (all normal Float64 numbers), `λ = α Xᵀy / 8` and the curvature `α XᵀX = 3.8e-211` are normal too, and the minimizer is `(7/8) Xᵀy / XᵀX = 5.4e-61`. The coordinate step forms the correlation `rᵀX_k` before it applies the scale, and that product is `2^-1199`, below the smallest subnormal: it is computed as 0. The step is then 0, the pass changes nothing, the change-based stopping rule is satisfied, and `solve!` returns `x = 0` with `converged = true` after one pass. At `x = 0` the stationarity condition is violated by a factor 8 (`α|Xᵀy|/λ = 8`), and the objective is 4.27 times its minimum. Float32 has the same case at `X = 2^-70`, `y = 2^-90`, `α = 2^90` (there the unscaled curvature `XᵀX` is subnormal, the scaled one is normal). The two control rows (a larger `y`, so the product is representable) converge to the minimizer.

**Where.** `coordinate_step!` of `src/cd/leastsquares.jl` at master `bb20b6a`: the kernel `_column_dot` returns `b = rᵀX_k` in the data type, and the range handling of the step is entered on the scaled curvature, not on a `b` that underflowed to 0 with `r ≠ 0`. The stop then rests on the change of the iterate alone. `docs/src/numerics.md` promises no recovery of every intermediate product, so whether this is (a) a documented limitation, (b) a case where `converged` should be `false`, or (c) a case to recover (the scaled product `α·rᵀX_k` is representable) is the contract question for this audit. #353 does not change it.

**Reproducer** (public API; Julia 1.10.13 and 1.13.4 print the same lines apart from the version):

```julia
# LS coordinate descent: `converged = true` at x = 0 although the minimizer is not 0, because the
# product rᵀX_k underflows. X, y, the loss scale α, λ, the curvature and the minimizer are normal numbers.
using ProximalSolvers, ProximalBase, Logging, Printf
function case(T, ex, ey, el; n = 2)
  X = fill(ldexp(T(1), ex), n, 1); y = fill(ldexp(T(1), ey), n); α = ldexp(T(1), el)
  λ = T(ldexp(1.0, el + ex + ey)) * T(n) / 8         # λ = α XᵀY / 8, so the minimizer is (7/8) Xᵀy / XᵀX ≠ 0
  x = zeros(T, 1)
  r = with_logger(NullLogger()) do
    solve!(x, α * LeastSquaresLoss(y, X), NormL1(λ), CDSolver(order = :cyclic, momentum = false))
  end
  setprecision(BigFloat, 600) do
    Xb, yb, αb, λb = big.(vec(X)), big.(y), big(α), big(λ)
    a, b = sum(abs2, Xb), sum(Xb .* yb)
    xs = (αb * b - λb) / (αb * a)
    F(z) = αb / 2 * sum(abs2, yb .- Xb .* z) + λb * abs(z)
    @printf("%s  X = 2^%d, y = 2^%d, α = 2^%d, λ = %.4g (n = %d, p = 1)\n", T, ex, ey, el, λ, n)
    @printf("  returned x = %.6g, converged = %s, passes = %d\n", x[1], r.converged, r.passes)
    @printf("  exact minimizer %.6g; (F(returned) − F(min))/F(min) = %.3g; KKT at 0: α|Xᵀy|/λ = %.3g (stationary iff ≤ 1)\n",
            Float64(xs), Float64((F(big(x[1])) - F(xs)) / F(xs)), Float64(αb * abs(b) / λb))
    @printf("  XᵀX = %.3g, α XᵀX = %.3g (floatmin = %.3g); Xᵀy exact = %.3g, computed in %s = %s (smallest subnormal %.3g)\n",
            Float64(a), Float64(αb * a), floatmin(T), Float64(b), T, string(sum(y .* vec(X))), nextfloat(zero(T)))
  end
end
println("Julia ", VERSION)
case(Float64, -500, -700, 300)
case(Float64, -500, -300, 300)     # control: the product is 2^-800, representable
case(Float32, -70, -90, 90)
case(Float32, -40, -50, 60)        # control
```

Output at `bb20b6a`:

```
Julia 1.10.13
Float64  X = 2^-500, y = 2^-700, α = 2^300, λ = 2.958e-272 (n = 2, p = 1)
  returned x = 0, converged = true, passes = 1
  exact minimizer 5.44514e-61; (F(returned) − F(min))/F(min) = 3.27; KKT at 0: α|Xᵀy|/λ = 8 (stationary iff ≤ 1)
  XᵀX = 1.87e-301, α XᵀX = 3.8e-211 (floatmin = 2.23e-308); Xᵀy exact = 2^-1199 (1.2e-361), computed in Float64 = 0.0 (smallest subnormal 4.94e-324)
Float64  X = 2^-500, y = 2^-300, α = 2^300, λ = 7.637e-152 (n = 2, p = 1)
  returned x = 1.40607e+60, converged = true, passes = 3
  exact minimizer 1.40607e+60; (F(returned) − F(min))/F(min) = 0; KKT at 0: α|Xᵀy|/λ = 8 (stationary iff ≤ 1)
  XᵀX = 1.87e-301, α XᵀX = 3.8e-211 (floatmin = 2.23e-308); Xᵀy exact = 3e-241, computed in Float64 = 2.999393627791262e-241 (smallest subnormal 4.94e-324)
Float32  X = 2^-70, y = 2^-90, α = 2^90, λ = 2.118e-22 (n = 2, p = 1)
  returned x = 0, converged = true, passes = 1
  exact minimizer 8.34465e-07; (F(returned) − F(min))/F(min) = 3.27; KKT at 0: α|Xᵀy|/λ = 8 (stationary iff ≤ 1)
  XᵀX = 1.43e-42, α XᵀX = 1.78e-15 (floatmin = 1.18e-38); Xᵀy exact = 1.37e-48, computed in Float32 = 0.0 (smallest subnormal 1.4e-45)
Float32  X = 2^-40, y = 2^-50, α = 2^60, λ = 2.328e-10 (n = 2, p = 1)
  returned x = 0.000854492, converged = true, passes = 3
  exact minimizer 0.000854492; (F(returned) − F(min))/F(min) = 0; KKT at 0: α|Xᵀy|/λ = 8 (stationary iff ≤ 1)
  XᵀX = 1.65e-24, α XᵀX = 1.91e-06 (floatmin = 1.18e-38); Xᵀy exact = 1.62e-27, computed in Float32 = 1.6155871e-27 (smallest subnormal 1.4e-45)
```

**Diagnostics that may help the decision.**
- How wide it is: the audit scanned exact power-of-two rescalings of one 40×12 problem with `X`, `y`, `α` and `λ` kept normal. It found 57 (Float64) and 4 to 5 (Float32) solves per configuration that return `converged = true` at a wrong point, all with the sum of the binary exponents of the `X` and `y` scales within 8 of the smallest exponent of the type, and no other wrong answer (`agentB/report.md` section 3, `agentB/scan_pow2.jl` and the `scan_*.tsv` tables on the branch `archive/issue-353-evidence-r3`).
- Where the code decides: `b` comes from the plain `@simd` accumulation of `_column_dot` in the data type; `coordinate_step!` reaches its range handling (`_scaled_prox`, `_outside_band`, `_exceptional_step`) through the scaled curvature `p = m.s a` only, so a `b` that underflowed to 0 at `r ≠ 0` is an ordinary zero step.
- An independent check at the returned point detects it: the stationarity violation is 8 relative to `λ`, not of rounding size.
