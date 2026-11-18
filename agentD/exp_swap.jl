# Would PB._residual_squares(v, nothing, Float64) be a drop-in for PS sqrtlasso _scaled_norm(v, n)?  And for PS _se_norm?
using ProximalBase, ProximalSolvers, Random
const PB = ProximalBase; const PS = ProximalSolvers
println("Julia ", VERSION)
function pb_scaled_norm(v, n)           # the candidate replacement of PS._scaled_norm
    q = PB._residual_squares(v, nothing, Float64)
    q === nothing && return :nonfinite
    s, k = q
    (sqrt(s), k)
end
rng = MersenneTwister(11)
cases = Pair{String,Any}[]
for T in (Float64, Float32)
    push!(cases, "randn $T" => randn(rng, T, 257))
    push!(cases, "zeros $T" => zeros(T, 9))
    push!(cases, "one entry $T" => T[0, 0, 3.5, 0])
    push!(cases, "huge $T" => randn(rng, T, 100) .* T(2)^(exponent(floatmax(T)) - 8))
    push!(cases, "tiny normal $T" => randn(rng, T, 100) .* T(2)^(T === Float64 ? -1000 : -120))
    push!(cases, "subnormal $T" => T[nextfloat(zero(T)), 3nextfloat(zero(T)), 0])
    push!(cases, "with Inf $T" => T[1, Inf, 2])
    push!(cases, "with NaN $T" => T[1, NaN, 2])
    push!(cases, "-0 and 0 $T" => T[-0.0, 0.0])
end
println(rpad("case", 18), rpad("PS (s,e)", 44), "PB (s,k)")
for (nm, v) in cases
    a = PS._scaled_norm(v, length(v)); b = pb_scaled_norm(v, length(v))
    ok = b === :nonfinite ? "PB returns nothing; PS returns (M,0) = $(a)" :
         (a[2] == b[2] ? "same exponent, s rel diff = $(a[1] == 0 ? 0.0 : abs(a[1]-b[1])/a[1])" : "EXPONENT DIFFERS")
    println(rpad(nm, 18), rpad(string(a), 44), string(b), "   -> ", ok)
end
# indicative timing (cold-path kernels; ns per element), min of 5 repeats of 200 calls, one process
function bench(f, args...; reps = 200)
    f(args...); best = Inf
    for _ in 1:5
        t = @elapsed for _ in 1:reps; f(args...); end
        best = min(best, t/reps)
    end
    best
end
println("\nIndicative timing, ns/element (min of 5 x 200 calls; NOT a controlled benchmark)")
for T in (Float64, Float32), n in (1000, 100_000)
    v = randn(rng, T, n)
    t1 = bench(PS._scaled_norm, v, n); t2 = bench(pb_scaled_norm, v, n)
    t3 = bench(PS._se_norm, T, v);   t4 = bench(PB._residual_squares, v, nothing, T)
    t5 = bench(PS._sumsq_scaled, v, maximum(abs, v))
    t6 = bench(sum, v)   # plain one pass sum baseline
    println("$T n=$n: PS _scaled_norm ", round(1e9t1/n, digits=2), "  PB _residual_squares(F64)+sqrt ", round(1e9t2/n, digits=2),
            "  PS _se_norm(T) ", round(1e9t3/n, digits=2), "  PB _residual_squares(T) ", round(1e9t4/n, digits=2), "  PS _sumsq_scaled ", round(1e9t5/n, digits=2), "  Base sum ", round(1e9t6/n, digits=2))
end
