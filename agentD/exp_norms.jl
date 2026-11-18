# Numerical comparison of 2-norm kernels: PB (_residual_squares, norm_diff) vs PS (_se_norm, _scaled_norm of sqrtlasso)
# against a 768-bit BigFloat reference, on rounded inputs.  Reports max relative error in units of u_T and the fraction of
# trials with computed < exact (direction), per data kind.
using ProximalBase, ProximalSolvers, Random, LinearAlgebra
const PB = ProximalBase; const PS = ProximalSolvers
setprecision(BigFloat, 768)
emax(T) = exponent(floatmax(T)); emin(T) = exponent(floatmin(T))
function gen(::Type{T}, n, kind, rng) where {T}
    v = randn(rng, T, n)
    if kind === :ordinary; return v
    elseif kind === :large;  return v .* T(2)^(emax(T) - 4 - 6)         # squares overflow, norm representable
    elseif kind === :tiny;   s = T === Float64 ? -530 : -68; return v .* T(2)^s   # squares subnormal
    elseif kind === :mixed
        # half the entries near 2^(emax-10), the other half 2^-40 smaller (their squares are 2^-80 of the larger ones)
        v[1:n÷2] .*= T(2)^(emax(T) - 10); v[n÷2+1:end] .*= T(2)^(emax(T) - 50); return v
    end
end
ex(v) = sqrt(sum(abs2, BigFloat.(v)))
# value of an _SE as BigFloat
sebig(a) = iszero(a.s) ? BigFloat(0) : ldexp(BigFloat(a.s), a.e)
function pbnorm(v, R)      # PB squared-residual kernel norm sqrt(s) 2^k as BigFloat (sqrt rounded in R)
    q = PB._residual_squares(v, nothing, R)
    q === nothing && return nothing
    iszero(q[1]) && return BigFloat(0)
    ldexp(BigFloat(sqrt(q[1])), q[2])
end
function psscaled(v)       # PS sqrtlasso _scaled_norm(v, n): (s, e) Float64
    s, e = PS._scaled_norm(v, length(v))
    iszero(s) ? BigFloat(0) : (isfinite(s) && e == 0 && !(s == 0) ? ldexp(BigFloat(s), e) : ldexp(BigFloat(s), e))
end
function stats(errs, below, u)
    (max = maximum(errs)/u, med = sort(errs)[cld(length(errs),2)]/u, below = count(below)/length(below))
end
println("Julia ", VERSION)
for T in (Float32, Float64), n in (64, 4096), kind in (:ordinary, :large, :tiny, :mixed)
    rng = MersenneTwister(1234)
    u = Float64(eps(T))/2
    res = Dict{String,Vector{Tuple{Float64,Bool}}}()
    add!(k, e, b) = push!(get!(res, k, Tuple{Float64,Bool}[]), (e, b))
    for t in 1:200
        v = gen(T, n, kind, rng)
        x = ex(v)
        rel(c) = c === nothing ? (NaN,false) : (Float64(abs(c - x)/x), c < x)
        add!("PB resq R=T", rel(pbnorm(v, T))...)
        add!("PB resq R=F64", rel(pbnorm(v, Float64))...)
        se = PS._se_norm(T, v)
        add!("PS _se_norm", rel(se === nothing ? nothing : sebig(se))...)
        add!("PS sqrtlasso _scaled_norm", rel(psscaled(v))...)
        # plain one-pass sum in T (the ordinary path of both packages) where it is finite and nonzero
        s = sum(abs2, v); isfinite(s) && s > 0 && add!("plain sqrt(sum abs2) T", rel(BigFloat(sqrt(s)))...)
        # LinearAlgebra.norm (BLAS nrm2 / generic scaled), returns T
        add!("LinearAlgebra.norm", rel(BigFloat(norm(v)))...)
        # PB public norm_diff(v, zeros)
        add!("PB norm_diff(v,0)", rel(BigFloat(PB.norm_diff(v, zeros(T, n))))...)
    end
    println("--- $T n=$n $kind   (max/med rel error in u_T = $(u); frac computed<exact)")
    for k in sort(collect(keys(res)))
        errs = [e for (e,_) in res[k]]; bl = [b for (_,b) in res[k]]
        any(isnan, errs) && (println("   ", rpad(k,28), " nothing/NaN in ", count(isnan, errs), " trials"); errs = filter(!isnan, errs); isempty(errs) && continue; bl = bl[1:length(errs)])
        s = stats(errs, bl, u)
        println("   ", rpad(k, 28), " max=", round(s.max, digits=2), "u  med=", round(s.med, digits=2), "u  below=", round(s.below, digits=2), "  [gamma_{n+4}=", round((n+4), digits=0), "u]")
    end
end
