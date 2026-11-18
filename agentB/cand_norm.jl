# Candidate C2: sqrt-lasso `_scaled_norm(v, n)` (power-of-two scaling by ldexp, Float64) vs PS's `_se_norm(Float64, v)`.
# BigFloat(precision 600) reference ‖v‖ on the rounded inputs. Reports max relative error (in units of eps(Float64)).
using ProximalSolvers, Random, Printf
const PS = ProximalSolvers
setprecision(BigFloat, 600)
bignorm(v) = sqrt(sum(abs2, BigFloat.(v)))
function viaSE(v)
  r = PS._se_norm(Float64, v)
  r === nothing && return (NaN, 0)
  (r.s, r.e)
end
valSE(v) = (r = viaSE(v); isnan(r[1]) ? BigFloat(NaN) : ldexp(BigFloat(r[1]), r[2]))
valScaled(v) = (r = PS._scaled_norm(v, length(v)); iszero(r[1]) ? BigFloat(0) : ldexp(BigFloat(r[1]), r[2]))
function relerr(val, ref)
  iszero(ref) && return iszero(val) ? 0.0 : Inf
  Float64(abs(val - ref) / ref) / eps(Float64)
end
rng = Xoshiro(3)
cases = Pair{String,Function}[]
for T in (Float32, Float64)
  mx = T === Float32 ? 1 : 1   # exponent units
  push!(cases, "$T ordinary n=1000" => () -> randn(rng, T, 1000))
  push!(cases, "$T mixed 2^±40 n=1000" => () -> (T.(randn(rng, 1000) .* exp2.(rand(rng, -40:40, 1000)))))
  T === Float64 && push!(cases, "$T huge (1e300*randn) n=1000" => () -> randn(rng, T, 1000) .* 1e300)
  T === Float64 && push!(cases, "$T tiny (1e-300*randn) n=1000" => () -> randn(rng, T, 1000) .* 1e-300)
  T === Float64 && push!(cases, "$T subnormal-heavy n=1000" => () -> randn(rng, T, 1000) .* 1e-310)
  T === Float64 && push!(cases, "$T one huge + many tiny" => () -> (v = randn(rng, T, 1000) .* 1e-200; v[1] = 1e300; v))
  T === Float64 && push!(cases, "$T [2^1000, 2^-1000]" => () -> T[ldexp(1.5, 1000), ldexp(1.0, -1000)])
  T === Float64 && push!(cases, "$T near floatmax n=10000" => () -> fill(floatmax(T)/2, 10000))
  T === Float32 && push!(cases, "$T huge 1e37 n=1000" => () -> randn(rng, T, 1000) .* 1f37)
  T === Float32 && push!(cases, "$T subnormal-heavy n=1000" => () -> randn(rng, T, 1000) .* 1f-42)
  push!(cases, "$T n=100000 ordinary" => () -> randn(rng, T, 100_000))
end
@printf("%-34s %14s %14s\n", "case (errors in eps(Float64) of ‖v‖)", "_scaled_norm", "_se_norm(F64)")
for (name, gen) in cases
  v = gen(); ref = bignorm(v)
  @printf("%-34s %14.2f %14.2f\n", name, relerr(valScaled(v), ref), relerr(valSE(v), ref))
end
# timing (indicative, cold path only; not a coordinate-loop claim)
function tm(f, v; reps=2000)
  f(v); t = @elapsed for _ in 1:reps; f(v); end; t / reps * 1e6
end
for n in (100, 1000, 100_000)
  v = randn(Xoshiro(1), n)
  @printf("n=%d: _scaled_norm %.2f us   _se_norm(F64) %.2f us   (indicative, one process; not coordinate-loop timing)\n", n, tm(w -> PS._scaled_norm(w, length(w)), v; reps=n<=1000 ? 2000 : 50), tm(w -> PS._se_norm(Float64, w), v; reps=n<=1000 ? 2000 : 50))
end
