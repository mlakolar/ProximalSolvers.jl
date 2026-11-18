# Paired in-process timing of the initial-curvature change (#321): the base kernels (second module), the head,
# a second copy of the head (A/A control) and, for PGD, "option A" (the start from the full Frobenius bound,
# no early exit) alternate in one process. Each arm is the minimum over `batches` batches of `reps` whole
# solves (function barrier, typed sink); the ratio to base is formed per round and the median over rounds is
# reported. Environment: PS321_BASE, PS321_HEAD, PS321_OPTA (directories with src/), PS321_ROUNDS (15),
# PS321_ONLY (regex on the cell label).
using Pkg; VERSION >= v"1.11" && Pkg.instantiate()
using LinearAlgebra, Printf, Random, Statistics, ProximalBase, SHA
BLAS.set_num_threads(1)
println("# Julia ", VERSION, " | threads=", Threads.nthreads(), " blas_threads=", BLAS.get_num_threads(), " | ", BLAS.get_config())
for l in readlines("/proc/cpuinfo"); occursin(r"^model name", l) && (println("# CPU ", split(l, ": ")[2]); break); end
println("# node ", gethostname(), " | job ", get(ENV, "JOB_ID", "-"))

loadmod(name, dir) = (m = Module(name); Base.include(m, joinpath(dir, "src", "ProximalSolvers.jl")); getfield(m, :ProximalSolvers))
# defaults: the head is the active project, option A sits beside this script, the base is the base worktree's remote copy
const VT = "$(VERSION.major).$(VERSION.minor)"
const BASE_DIR = get(ENV, "PS321_BASE", "<cluster-dir>-base/base-$VT/pkg")
const HEAD_DIR = get(ENV, "PS321_HEAD", dirname(Base.active_project()))
const OPTA_DIR = get(ENV, "PS321_OPTA", joinpath(@__DIR__, "optA"))
const B = loadmod(:BaseSide, BASE_DIR)
const H = loadmod(:HeadSide, HEAD_DIR)
const AA = loadmod(:HeadCopy, HEAD_DIR)
const OA = loadmod(:OptionA, OPTA_DIR)
const PREV_DIR = get(ENV, "PS321_PREV", joinpath(@__DIR__, "prev"))     # src/ of the commit before the integer-scale fix
const PV = loadmod(:Previous, PREV_DIR)
println("# prev ", PREV_DIR, "\n# base ", BASE_DIR, "\n# head ", HEAD_DIR, "\n# optA ", OPTA_DIR)
for (nm, d) in (("base", BASE_DIR), ("head", HEAD_DIR))
  println("# ", nm, " source sha256 of src/solvers: ", bytes2hex(sha256(join(read(joinpath(d, "src/solvers", f), String) for f in sort(readdir(joinpath(d, "src/solvers")))))))
end
println("# PB ", pkgdir(ProximalBase), " ", pkgversion(ProximalBase))
const ROUNDS = parse(Int, get(ENV, "PS321_ROUNDS", "15"))
const ONLY = Regex(get(ENV, "PS321_ONLY", ""))
const SINK = Ref(0)

struct Arm{S, M, O}
  name::String
  solve::S
  method::M
  opts::O
end
mkarm(name, m, kind, optkw) = Arm(name, m.solve!, kind === :pgd ? m.ProximalGradientDescent() : m.AccProxGradDescent(), m.ProximalOptions(; optkw...))

@noinline function batch(solve!, reps, method, x, x0, f, g, opts)
  t0 = time_ns(); s = 0
  for _ in 1:reps
    copyto!(x, x0)
    res = solve!(x, f, g, method, opts)
    s += res.iterations
  end
  (time_ns() - t0) / reps, s
end
runbatch(a::Arm, reps, x, x0, f, g) = batch(a.solve, reps, a.method, x, x0, f, g, a.opts)

function design(::Type{T}, n, p; seed = 1, xscale = 1.0) where T
  rng = Xoshiro(seed + 1000n + p)
  X = randn(rng, n, p); X .-= mean(X, dims = 1); X ./= std(X, dims = 1)
  β = zeros(p); β[1:min(p, 5)] .= randn(rng, min(p, 5))
  y = X * β .+ 0.1 .* randn(rng, n)
  (T.(X .* xscale), T.(y .* xscale))
end
lam(X, y, α, c) = c * α * maximum(abs, X' * y)

const WORST = Ref(0.0)
function paired(label, kind, x0, f, g, optkw; opta = false, batches = 8, target_ms = 20.0, gate = true)
  occursin(ONLY, label) || return
  arms = Arm[mkarm("base", B, kind, optkw), mkarm("head", H, kind, optkw), mkarm("aa", AA, kind, optkw)]
  opta && push!(arms, mkarm("optA", OA, kind, optkw))
  x = copy(x0)
  its = Int[]
  for a in arms; runbatch(a, 1, x, x0, f, g); end          # compile
  t, _ = runbatch(arms[1], 1, x, x0, f, g)
  reps = max(1, ceil(Int, target_ms * 1e6 / t))
  for a in arms; runbatch(a, reps, x, x0, f, g); end        # warm
  ratios = [Float64[] for _ in arms]; tb = Float64[]
  for r in 1:ROUNDS
    m = fill(Inf, length(arms))
    for b in 1:batches, (i, a) in enumerate(arms)
      tt, s = runbatch(a, reps, x, x0, f, g)
      SINK[] += s
      m[i] = min(m[i], tt)
    end
    for i in eachindex(arms); push!(ratios[i], m[i] / m[1]); end
    push!(tb, m[1])
  end
  for a in arms; push!(its, runbatch(a, 1, x, x0, f, g)[2]); end
  io = IOBuffer()
  @printf(io, "%s\treps=%d\titers=%s\tbase_us=%.1f", label, reps, join(its, "/"), median(tb) / 1e3)
  for i in 2:length(arms)
    @printf(io, "\t%s/base med=%.4f [%.4f %.4f]", arms[i].name, median(ratios[i]), minimum(ratios[i]), maximum(ratios[i]))
  end
  println(String(take!(io)))
  gate && (WORST[] = max(WORST[], median(ratios[2]) / max(1.0, median(ratios[3]))))
  flush(stdout)
end

println("\n## 1. ordinary cold solves (α = 1/n, standardized, so α‖X‖_F² = p ≥ 2), λ = 0.1 λmax, default options")
for T in (Float64, Float32), (n, p) in ((100, 32), (1000, 100), (5000, 500)), kind in (:pgd, :apg)
  X, y = design(T, n, p); α = 1 / n
  f = Scaled(LeastSquaresLoss(y, X), α); g = NormL1(T(lam(X, y, α, 0.1)))
  paired("ord $kind $T $(n)x$p", kind, zeros(T, p), f, g, (); opta = kind === :pgd)
end
println("\n## 2. tight tolerance (gradtol 1e-9, ftol 0, xtol 1e-12), λ = 0.01 λmax")
for T in (Float64,), (n, p) in ((100, 32), (1000, 100)), kind in (:pgd, :apg)
  X, y = design(T, n, p); α = 1 / n
  f = Scaled(LeastSquaresLoss(y, X), α); g = NormL1(T(lam(X, y, α, 0.01)))
  paired("tight $kind $T $(n)x$p", kind, zeros(T, p), f, g, (gradtol = 1e-9, ftol = 0.0, xtol = 1e-12, maxiter = 2000); opta = kind === :pgd)
end
println("\n## 3. warm start at the solution for 2λ")
for T in (Float64, Float32), (n, p) in ((1000, 100), (5000, 500)), kind in (:pgd, :apg)
  X, y = design(T, n, p); α = 1 / n
  λ1 = T(lam(X, y, α, 0.1))
  f = Scaled(LeastSquaresLoss(y, X), α)
  xw = zeros(T, p); H.solve!(xw, f, NormL1(2 * λ1), H.ProximalGradientDescent(), H.ProximalOptions(gradtol = 1e-8, ftol = 0.0, xtol = 1e-10, maxiter = 5000))
  paired("warm $kind $T $(n)x$p", kind, xw, f, NormL1(λ1), (); opta = kind === :pgd)
end
println("\n## 4. PGD worst case of the scan: 1 to 4 standardized columns, α‖X‖_F² = target (scan reads all p columns unless it exits at s ≥ 2/α)")
for T in (Float64, Float32), p in 1:4, target in (1.0, 2.0, 4.0)
  n = 10000
  X, y = design(T, n, p); α = target / sum(abs2, Float64.(X))
  f = Scaled(LeastSquaresLoss(y, X), α); g = NormL1(T(lam(X, y, α, 0.1)))
  paired("worst pgd $T $(n)x$p α‖X‖²=$target", :pgd, zeros(T, p), f, g, (); opta = true)
end
println("\n## 5. informational: cases where the start changes (the ratio is not a cost, the trajectory differs)")
let X = ones(5, 1), y = fill(1e160, 5), α = 1e-100
  for kind in (:pgd, :apg)
    paired("info R5 $kind", kind, zeros(1), Scaled(LeastSquaresLoss(y, X), α), NormL1(0.0), (); gate = false)
  end
end
let (X, y) = design(Float64, 100, 20), α = 1e-12
  for kind in (:pgd, :apg)
    paired("info alpha1e-12 $kind", kind, zeros(20), Scaled(LeastSquaresLoss(y, X), α), NormL1(lam(X, y, α, 0.1)), (); gate = false)
  end
end
println("\nWORST median(head/base) / max(1, median(aa/base)) over the gated cells: ", round(WORST[], digits = 4))

# ---- allocations -----------------------------------------------------------------------------------
alloc_solve(solve!, x, x0, f, g, m, o) = (copyto!(x, x0); @allocated solve!(x, f, g, m, o))
alloc_fn(fn, ::Type{T}, X, α) where T = @allocated fn(T, X, α)
alloc_apg(ic, rs, fu, ::Type{T}, X, α) where T = @allocated ic(T, rs(T, α), fu(T, X))
if occursin(ONLY, "alloc")
  println("\n## 6. warmed allocations of whole solves (bytes, min of 10 after 3 warm-ups): base / head")
  for T in (Float64, Float32), (n, p) in ((100, 32), (1000, 100)), kind in (:pgd, :apg)
    X, y = design(T, n, p); α = 1 / n
    f = Scaled(LeastSquaresLoss(y, X), α); g = NormL1(T(lam(X, y, α, 0.1)))
    x0 = zeros(T, p); x = copy(x0)
    out = String[]
    for (nm, M) in (("base", B), ("head", H))
      a = mkarm(nm, M, kind, ())
      for _ in 1:3; copyto!(x, x0); a.solve(x, f, g, a.method, a.opts); end
      push!(out, "$nm=$(minimum(alloc_solve(a.solve, x, x0, f, g, a.method, a.opts) for _ in 1:10))")
    end
    println("alloc solve\t$kind\t$T\t$(n)x$p\t", join(out, "\t"))
  end

  println("\n## 6b. integer and Bool loss scales on the full-scan branch (X = [√0.75], y = 1, λ = 0.1; α‖X‖² = 1.5 for α = 2): warmed whole-solve bytes, base / previous commit / head")
  for T in (Float64, Float32), kind in (:pgd, :apg), α in (2.0, 2, Int8(2), true)
    X, y = fill(T(sqrt(0.75)), 1, 1), ones(T, 1)
    f = Scaled(LeastSquaresLoss(y, X), α); g = NormL1(T(0.1))
    x0 = zeros(T, 1); x = copy(x0)
    out = String[]
    for (nm, M) in (("base", B), ("prev", PV), ("head", H))
      a = mkarm(nm, M, kind, ())
      for _ in 1:3; copyto!(x, x0); a.solve(x, f, g, a.method, a.opts); end
      push!(out, "$nm=$(minimum(alloc_solve(a.solve, x, x0, f, g, a.method, a.opts) for _ in 1:10))")
    end
    println("alloc int-scale solve\t$kind\t$T\tα=$(repr(α))\t", join(out, "\t"))
  end
  println("\n## 6c. the start alone with an integer scale on the full-scan branch (bytes): previous commit / head")
  for T in (Float64, Float32), α in (2, true, Int8(2))
    X = fill(T(sqrt(0.75)), 1, 1)
    for M in (PV, H); M._scanned_initial_curvature(T, X, α); alloc_apg(M._initial_curvature, M._root_scale, M._frobenius_upper, T, X, α); end
    println("alloc int-scale start\t$T\tα=$(repr(α))\tPGD scan prev=", alloc_fn(PV._scanned_initial_curvature, T, X, α), " head=", alloc_fn(H._scanned_initial_curvature, T, X, α),
            "\tAPG start prev=", alloc_apg(PV._initial_curvature, PV._root_scale, PV._frobenius_upper, T, X, α), " head=", alloc_apg(H._initial_curvature, H._root_scale, H._frobenius_upper, T, X, α))
  end
  println("\n## 7. warmed allocations of the start (bytes), head")
  inputs = Any[]
  for T in (Float32, Float64)
    Xs, _ = design(T, 100, 8)
    push!(inputs, ("early exit", T, Xs, 1 / 100)); push!(inputs, ("full pass", T, T(1e-3) .* Xs, 1 / 100))
  end
  push!(inputs, ("overflow", Float64, fill(1e200, 5, 2), 1.0))
  for (name, T, X, α0) in inputs, α in (Float32(α0), Float64(α0))
    H._scanned_initial_curvature(T, X, α); alloc_apg(H._initial_curvature, H._root_scale, H._frobenius_upper, T, X, α); OA._scanned_initial_curvature(T, X, α)
    println("alloc start\t$name\t$T\tα::$(typeof(α))\tPGD scan=", alloc_fn(H._scanned_initial_curvature, T, X, α), "\tAPG start=", alloc_apg(H._initial_curvature, H._root_scale, H._frobenius_upper, T, X, α), "\toptionA=", alloc_fn(OA._scanned_initial_curvature, T, X, α))
  end
  println("\n## 8. cost of the start alone (min µs over 300 calls): PGD scan (early exit / full pass), option A (full bound), one product X x, base's L0 = 1 is free")
  tm(f) = (f(); minimum(begin t0 = time_ns(); f(); (time_ns() - t0) / 1e3 end for _ in 1:300))
  for T in (Float64, Float32), (n, p) in ((100, 32), (1000, 100), (5000, 500))
    X, _ = design(T, n, p); α = 1 / n; x = randn(T, p); z = zeros(T, n); Xf = T(1e-3) .* X
    a = tm(() -> H._scanned_initial_curvature(T, X, α)); b = tm(() -> H._scanned_initial_curvature(T, Xf, α))
    c = tm(() -> OA._scanned_initial_curvature(T, X, α)); d = tm(() -> mul!(z, X, x))
    @printf("start cost\t%s\t%dx%d\tscan early exit=%.2f\tscan full pass=%.2f\toptionA=%.2f\tmul!(X,x)=%.2f\n", T, n, p, a, b, c, d)
  end
end
println("sink ", SINK[], "\ndone")
