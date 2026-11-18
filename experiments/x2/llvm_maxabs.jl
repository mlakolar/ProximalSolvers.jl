# Does PB's norm_diff(x, y, Inf) loop vectorize like PS's @simd _maxabs_diff?  (code_llvm / code_native evidence)
#   julia +lts|+release --project=<WORK>/ps-353 llvm_maxabs.jl
const HERE = @__DIR__
include(joinpath(HERE, "loadtrees.jl"))
using InteractiveUtils, ProximalBase, Random
println("Julia ", VERSION, " CPU ", Sys.CPU_NAME)
old = BaseMod.ProximalSolvers.Blocks._maxabs_diff
new = X2Mod.ProximalSolvers.Blocks._norm_diff
for T in (Float32, Float64)
  x = rand(T, 1000); y = rand(T, 1000)
  llo = sprint(io -> code_llvm(io, old, Tuple{Vector{T}, Vector{T}}; debuginfo = :none, optimize = true))
  lln = sprint(io -> code_llvm(io, ProximalBase.norm_diff, Tuple{Vector{T}, Vector{T}, Float64}; debuginfo = :none, optimize = true))
  nto = sprint(io -> code_native(io, old, Tuple{Vector{T}, Vector{T}}; debuginfo = :none))
  ntn = sprint(io -> code_native(io, ProximalBase.norm_diff, Tuple{Vector{T}, Vector{T}, Float64}; debuginfo = :none))
  write(joinpath(HERE, "llvm_old_$(T)_$(VERSION).ll"), llo); write(joinpath(HERE, "llvm_new_$(T)_$(VERSION).ll"), lln)
  write(joinpath(HERE, "native_old_$(T)_$(VERSION).s"), nto); write(joinpath(HERE, "native_new_$(T)_$(VERSION).s"), ntn)
  cnt(s, pat) = length(collect(eachmatch(pat, s)))
  vecw(s) = (m = match(r"<(\d+) x (float|double)>", s); m === nothing ? "none" : m.match)
  println("\n$T:")
  println("  OLD (@simd _maxabs_diff): vector.body=", cnt(llo, r"vector\.body"), " vector types: ", vecw(llo), " fcmp/select/maximum intrinsics: ",
          cnt(llo, r"fcmp"), "/", cnt(llo, r"select"), "/", cnt(llo, r"llvm\.maximum|llvm\.maxnum"), "   native: packed ops (maxps/maxpd/cmpunord/andps..): ",
          cnt(nto, r"\b(vmax|max)(ps|pd)\b"), " cmpunord ", cnt(nto, r"cmpunord|vcmp"), " ymm ", cnt(nto, r"ymm"), " xmm ", cnt(nto, r"xmm"), " lines=", count(==('\n'), nto))
  println("  NEW (PB norm_diff, p=Inf): vector.body=", cnt(lln, r"vector\.body"), " vector types: ", vecw(lln), " fcmp/select/maximum intrinsics: ",
          cnt(lln, r"fcmp"), "/", cnt(lln, r"select"), "/", cnt(lln, r"llvm\.maximum|llvm\.maxnum"), "   native: packed ops: ",
          cnt(ntn, r"\b(vmax|max)(ps|pd)\b"), " cmpunord ", cnt(ntn, r"cmpunord|vcmp"), " ymm ", cnt(ntn, r"ymm"), " xmm ", cnt(ntn, r"xmm"), " lines=", count(==('\n'), ntn))
  # indicative only (shared machine): ns per element
  function bench(f, args...; reps = 3000)
    f(args...); best = Inf
    for _ in 1:7
      t = @elapsed for _ in 1:reps; f(args...); end
      best = min(best, t / reps)
    end
    best
  end
  for n in (1000, 100_000)
    x = rand(T, n); y = rand(T, n)
    t1 = bench(old, x, y; reps = max(5, 2_000_000 ÷ n)); t2 = bench(new, x, y, Inf; reps = max(5, 2_000_000 ÷ n))
    println("  indicative n=$n: old ", round(1e9t1 / n, digits = 3), " ns/elt, new ", round(1e9t2 / n, digits = 3), " ns/elt, ratio new/old ", round(t2 / t1, digits = 2))
  end
end
