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


println("\n## worst case of the early exit: unit-scale problems with few columns (α‖X‖_F² near or below 2), PGD only")
for T in (Float64, Float32), (n, p) in ((10000, 1), (10000, 2), (10000, 3), (2000, 4)), (sn, mk) in (("pgd", ProximalGradientDescent()),)
  X, y = design(T, n, p); α = 1 / n
  f = α * LeastSquaresLoss(y, X); g = NormL1(T(lam(X, y, α, 0.1)))
  paired("$sn $T n=$n p=$p (α‖X‖_F²=$(round(α * sum(abs2, Float64.(X)), digits = 3)))", mk, zeros(T, p), f, g, ProximalOptions())
end
println("done")
