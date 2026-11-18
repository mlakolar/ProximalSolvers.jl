# #351 reproducer. Run with: julia --project=<PS checkout at 8d2a30e> probe.jl [--native]
using ProximalSolvers, ProximalBase, InteractiveUtils, Printf, LinearAlgebra, Random
const PS = ProximalSolvers
const T = Float32
const NATIVE = "--native" in ARGS

println("Julia ", VERSION, " | ", Sys.MACHINE, " | CPU ", Sys.CPU_NAME, " | LLVM ", Base.libllvm_version,
        " | -O", Base.JLOptions().opt_level)
println("PS ", pkgversion(ProximalSolvers), " at ", pkgdir(ProximalSolvers))
println("PB ", pkgversion(ProximalBase), " at ", pkgdir(ProximalBase))
bits(x::Float32) = (b = bitstring(x); string(b[1], " ", b[2:9], " ", b[10:end]))
show1(name, v) = @printf("  %-52s %-14s %s\n", name, repr(v), v isa Float32 ? bits(v) : "")

λ = 1152921573326323713 // 1152921504606846976          # = 1 + 2^-24 + 2^-60
ref = setprecision(() -> T(BigFloat(λ)), BigFloat, 256)   # correctly rounded, 256-bit evaluation of the exact Rational
println("\n[1-2] the level and its Float32 roundings")
show1("λ", λ)
show1("T(λ)  (Base: T(num)/T(den))", T(λ))
show1("T(Float64(λ))  (double rounding)", T(Float64(λ)))
show1("T(BigFloat(λ, 256 bits))  (reference)", ref)
show1("T(num), T(den) scalar", (T(λ.num), T(λ.den)))

# the hardware/compiler conversion of a pair of Int64 to a pair of Float32, as the SLP vectorizer emits it
vconv(a::Int64, b::Int64) = Base.llvmcall("""
    %v0 = insertelement <2 x i64> undef, i64 %0, i32 0
    %v1 = insertelement <2 x i64> %v0, i64 %1, i32 1
    %r = sitofp <2 x i64> %v1 to <2 x float>
    ret <2 x float> %r""", NTuple{2, VecElement{Float32}}, Tuple{Int64, Int64}, a, b)
v = vconv(λ.num, λ.den)
show1("sitofp <2 x i64> -> <2 x float> of (num, den): num", v[1].value)
show1("  scalar sitofp num", T(λ.num))

println("\n[3] the coefficients of PS._converted_penalty")
g = ElasticNet(λ, λ)
gT = PS._converted_penalty(g, T)
show1("_converted_penalty(ElasticNet(λ,λ), T).λ1", gT.λ1)
show1("_converted_penalty(ElasticNet(λ,λ), T).λ2", gT.λ2)
show1("_converted_penalty(NormL1(λ), T).λ0", PS._converted_penalty(NormL1(λ), T).λ0)
pair(a, b) = (T(a), T(b))
show1("(T(a), T(b)) for two Rational levels, inlined pair", pair(λ, λ))
@noinline cvt(::Type{S}, a) where {S} = S(a)
show1("candidate: ElasticNet(cvt(T, λ1), cvt(T, λ2)).λ1  (@noinline)", ElasticNet(cvt(T, g.λ1), cvt(T, g.λ2)).λ1)
L = 1152921573326323713                                   # an Int64 level with the same bits as num
show1("Int64 level L: T(L)", T(L))
show1("Int64 level L: _converted_penalty(ElasticNet(L,L)).λ1", PS._converted_penalty(ElasticNet(L, L), T).λ1)

println("\n[4-7] the residual at x = [1], grad = [-2c], c = T(λ)")
c = T(λ)
x = T[1]
grad = T[-2c]
direct = abs((grad[1] + c * x[1]) + c * sign(x[1]))
show1("direct Float32 formula |(g + c x) + c sign x|", direct)
show1("kkt_violation(ElasticNet(c,c), grad, x)  (@simd Array path)", kkt_violation(ElasticNet(c, c), grad, x))
show1("kkt_violation(ElasticNet(c,c), view(grad), view(x))  (generic)", kkt_violation(ElasticNet(c, c), view(grad, 1:1), view(x, 1:1)))
show1("kkt_violation(ElasticNet(c,c), grad, x, 1)  (one coordinate)", kkt_violation(ElasticNet(c, c), grad, x, 1))
show1("kkt_violation(_converted_penalty(g,T), grad, x)", kkt_violation(gT, grad, x))
show1("kkt_violation(_converted_penalty(g,T), grad, x, 1)", kkt_violation(gT, grad, x, 1))
show1("kkt_violation(_converted_penalty(g,T), views)", kkt_violation(gT, view(grad, 1:1), view(x, 1:1)))
show1("direct formula at the converted coefficients", abs((grad[1] + gT.λ2 * x[1]) + gT.λ1 * sign(x[1])))
show1("test helper residual_of (PS test/elasticnet.jl:185)", kkt_violation(PS._converted_penalty(ElasticNet(λ, λ), T), grad, x))

println("\n[8] solves: PGD and APG, Float32, ElasticNet(λ, λ) with the Rational level")
rng = Xoshiro(351)
X = randn(rng, T, 40, 12); y = randn(rng, T, 40)
λs = λ * 2 // 1                                           # same bit pattern issue (exact doubling of num)
for method in (ProximalGradientDescent(), AccProxGradDescent())
  xs = zeros(T, 12)
  r = solve!(xs, LeastSquaresLoss(y, X), ElasticNet(λs, λs), method, ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-6))
  gr = X' * (X * xs - y)
  cR, cD = T(λs), T(Float64(λs))
  rc = kkt_violation(ElasticNet(cR, cR), gr, xs); rd = kkt_violation(ElasticNet(cD, cD), gr, xs)
  thr = T(max(1e-6, 64 * Float64(eps(T)))) * max(cR, maximum(abs, X' * y))
  @printf("  %-24s converged=%s iters=%d  residual(T(λ))=%.3e residual(double-rounded)=%.3e |diff|=%.3e threshold=%.3e\n",
          nameof(typeof(method)), r.converged, r.iterations, rc, rd, abs(rc - rd), thr)
end

if NATIVE
  println("\n[9] native code: vector conversions (scvtf/ucvtf .2d followed by fcvtn) per specialization")
  scan(io) = (s = String(take!(io)); (count(r"(scvtf|ucvtf)(\.2d|\s+v\d+\.2d)", s), count(r"fcvtn", s), count(r"scvtf\s+s\d+, x\d+", s)))
  for (name, f, tt) in (("_converted_penalty(ElasticNet{Rational})", PS._converted_penalty, (typeof(g), Type{T})),
                        ("_converted_penalty(NormL1{Rational})", PS._converted_penalty, (typeof(NormL1(λ)), Type{T})),
                        ("_converted_penalty(ElasticNet{Int64})", PS._converted_penalty, (typeof(ElasticNet(L, L)), Type{T})))
    local io = IOBuffer(); code_native(io, f, tt; debuginfo = :none)
    println("  ", rpad(name, 48), " (vector cvt, fcvtn, scalar scvtf s,x) = ", scan(io))
  end
  for mi in Base.specializations(only(methods(PS._stationary!)))
    mi === nothing && continue
    tt = Tuple{mi.specTypes.parameters[2:end]...}
    occursin("Rational", string(tt)) || continue
    local io = IOBuffer(); code_native(io, PS._stationary!, tt; debuginfo = :none)
    println("  _stationary!(", nameof(tt.parameters[1]), ", …, ", tt.parameters[3], ") = ", scan(io))
  end
  println("\n--- code_native _converted_penalty(ElasticNet{Rational{Int64}}, Float32), first lines")
  io = IOBuffer(); code_native(io, PS._converted_penalty, (typeof(g), Type{T}); debuginfo = :none)
  foreach(println, first(filter(l -> !startswith(lstrip(l), r"[;.#]"), split(String(take!(io)), '\n')), 20))
end
