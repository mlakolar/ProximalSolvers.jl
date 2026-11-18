# Paired in-process timing of the initial-curvature candidate against master's L0 = 1, with an A/A control.
# base, b1 and a second base copy (A/A) alternate in one process; each side is the minimum over `batches` batches of `reps`
# whole solves (function barrier, typed sink); the ratio is formed per round and the median over rounds is reported.
using ProximalSolvers, ProximalBase, LinearAlgebra, Printf, Random, Statistics
const PS = ProximalSolvers
Base.include(PS, joinpath(@__DIR__, "trace_defs.jl"))
BLAS.set_num_threads(1)
println("# Julia ", VERSION, " | ", Sys.CPU_NAME, " | threads=", Threads.nthreads(), " blas_threads=", BLAS.get_num_threads(), " | ", BLAS.get_config())
for l in readlines(`lscpu`); occursin(r"^Model name", l) && println("# ", l); end
println("# PS ", pkgdir(PS), " PB ", pkgdir(ProximalBase), " ", pkgversion(ProximalBase))

function design(::Type{T}, n, p; seed = 1, xscale = 1.0) where T
  rng = Xoshiro(seed + 1000n + p)
  X = randn(rng, n, p); X .-= mean(X, dims = 1); X ./= std(X, dims = 1)
  β = zeros(p); β[1:min(p, 5)] .= randn(rng, min(p, 5))
  y = X * β .+ 0.1 .* randn(rng, n)
  (T.(X .* xscale), T.(y .* xscale))
end
lam(X, y, α, c) = c * α * maximum(abs, X' * y)

@noinline function batch(pol::Symbol, reps, mk, x, x0, f, g, opts)
  t0 = time_ns(); s = 0
  for _ in 1:reps
    copyto!(x, x0)
    res = pol === :reuse ? PS.solve_apg_reuse!(x, f, g, mk, opts) : PS.solve_proto!(x, f, g, mk, opts; L0 = pol)
    s += res.iterations
  end
  (time_ns() - t0) / reps, s
end

function paired(label, mk, x0, f, g, opts; rounds = 15, batches = 8, target_ms = 20.0, cand = (mk isa AccProxGradDescent ? :reuse : :b1x))
  x = copy(x0)
  # calibrate reps
  t, it = batch(:base, 1, mk, x, x0, f, g, opts)
  batch(cand, 1, mk, x, x0, f, g, opts)
  reps = max(1, ceil(Int, target_ms * 1e6 / t))
  r_b1 = Float64[]; r_aa = Float64[]; tb = Float64[]
  for r in 1:rounds
    m = Dict(:base => Inf, :cand => Inf, :base2 => Inf)
    for b in 1:batches, p in (:base, :cand, :base2)
      tt, _ = batch(p === :base2 ? :base : p === :cand ? cand : p, reps, mk, x, x0, f, g, opts)
      m[p] = min(m[p], tt)
    end
    push!(r_b1, m[:cand] / m[:base]); push!(r_aa, m[:base2] / m[:base]); push!(tb, m[:base])
  end
  itb = batch(:base, 1, mk, x, x0, f, g, opts)[2]; it1 = batch(cand, 1, mk, x, x0, f, g, opts)[2]
  @printf("%s\treps=%d\titers base=%d %s=%d\tbase_us=%.1f\t%s/base median=%.4f [min %.4f max %.4f]\tA/A median=%.4f [min %.4f max %.4f]\n", label, reps, itb, cand, it1,
          median(tb) / 1e3, cand, median(r_b1), minimum(r_b1), maximum(r_b1), median(r_aa), minimum(r_aa), maximum(r_aa))
end

println("\n## 1. cost of the Frobenius bound against one product (min over 300 calls, µs)")
println("T\tn\tp\tfrobenius_upper\tmul!(X,x)\tmul!(X',z)\tratio frob/mul")
for T in (Float64, Float32), (n, p) in ((100, 32), (1000, 100), (5000, 500), (20000, 200))
  X, y = design(T, n, p); x = randn(T, p); z = zeros(T, n); gg = zeros(T, p)
  tm(f) = (f(); minimum(begin t0 = time_ns(); f(); (time_ns() - t0) / 1e3 end for _ in 1:300))
  a = tm(() -> PS._frobenius_upper(T, X)); b = tm(() -> mul!(z, X, x)); c = tm(() -> mul!(gg, transpose(X), z))
  @printf("%s\t%d\t%d\t%.2f\t%.2f\t%.2f\t%.2f\n", T, n, p, a, b, c, a / b)
end

println("\n## 2. whole solves, ordinary problems (α‖X‖_F² ≥ 1, so b1 follows master's trajectory), default options")
for T in (Float64, Float32), (n, p) in ((100, 32), (1000, 100), (5000, 500)), (sn, mk) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent()))
  X, y = design(T, n, p); α = 1 / n
  f = α * LeastSquaresLoss(y, X); g = NormL1(T(lam(X, y, α, 0.1)))
  paired("$sn $T n=$n p=$p λ=0.1λmax", mk, zeros(T, p), f, g, ProximalOptions())
end
println("\n## 3. whole solves, a tight tolerance (more iterations per solve)")
for T in (Float64,), (n, p) in ((100, 32), (1000, 100)), (sn, mk) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent()))
  X, y = design(T, n, p); α = 1 / n
  f = α * LeastSquaresLoss(y, X); g = NormL1(T(lam(X, y, α, 0.01)))
  paired("$sn $T n=$n p=$p λ=0.01λmax gradtol=1e-9,ftol=0,xtol=1e-12", mk, zeros(T, p), f, g, ProximalOptions(gradtol = 1e-9, ftol = 0.0, xtol = 1e-12, maxiter = 2000))
end

println("\n## 3b. warm-started solves (start at the solution for 2λ; few iterations)")
for T in (Float64, Float32), (n, p) in ((1000, 100), (5000, 500)), (sn, mk) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent()))
  X, y = design(T, n, p); α = 1 / n
  λ1 = T(lam(X, y, α, 0.1))
  f = α * LeastSquaresLoss(y, X)
  xw = zeros(T, p); solve!(xw, f, NormL1(2 * λ1), ProximalGradientDescent(), ProximalOptions(gradtol = 1e-8, ftol = 0.0, xtol = 1e-10, maxiter = 5000))
  paired("$sn $T warm start n=$n p=$p", mk, xw, f, NormL1(λ1), ProximalOptions())
end

println("\n## 4. whole solves where b1 changes the start (α‖X‖_F² < 1: data in small units)")
for T in (Float64, Float32), s in (1e-2, 1e-3), (sn, mk) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent()))
  n, p = 1000, 100
  X, y = design(T, n, p; xscale = s); α = 1 / n
  f = α * LeastSquaresLoss(y, X); g = NormL1(T(lam(X, y, α, 0.1)))
  paired("$sn $T xscale=$s n=$n p=$p", mk, zeros(T, p), f, g, ProximalOptions())
end

println("\n## 5. warmed allocations per whole solve (bytes), base vs b1 (full pass), b1x (PGD early exit), reuse (APG)")
for T in (Float64, Float32), (n, p) in ((100, 32), (1000, 100)), (sn, mk) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent()))
  X, y = design(T, n, p); α = 1 / n
  f = α * LeastSquaresLoss(y, X); g = NormL1(T(lam(X, y, α, 0.1)))
  x0 = zeros(T, p); x = copy(x0)
  out = String[]
  for pol in (:base, :b1, :b1x, :reuse)
    pol === :reuse && !(mk isa AccProxGradDescent) && continue
    run1() = pol === :reuse ? PS.solve_apg_reuse!(x, f, g, mk, ProximalOptions()) : PS.solve_proto!(x, f, g, mk, ProximalOptions(); L0 = pol)
    for _ in 1:3; copyto!(x, x0); run1(); end
    a = minimum(begin copyto!(x, x0); @allocated(run1()) end for _ in 1:10)
    push!(out, "$pol=$(a)")
  end
  println("alloc\t$sn\t$T\tn=$n p=$p\t", join(out, "\t"))
end
println("done")
