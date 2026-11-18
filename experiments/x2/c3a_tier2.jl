# C3a: which inputs change when tier 2 of response_scale is dropped (BASE vs X2), against a BigFloat reference.
#   julia +lts|+release --project=<WORK>/ps-353 c3a_tier2.jl
const HERE = @__DIR__
include(joinpath(HERE, "loadtrees.jl"))
using Random, LinearAlgebra
B = BaseMod.ProximalSolvers; X = X2Mod.ProximalSolvers
println("Julia ", VERSION, " CPU ", Sys.CPU_NAME)
rng = Xoshiro(6)
rsc(PS, y, α) = try PS.response_scale(PS.LSModel(y, ones(eltype(y), length(y), 1), α), nothing) catch e; "ERR" end
exactscale(y, α) = setprecision(() -> sqrt(BigFloat(α) * sum(abs2, BigFloat.(y))), BigFloat, 512)
ulps(v, T, ref) = Float64(abs(BigFloat(v) - ref) / BigFloat(eps(T) * (ref >= BigFloat(floatmin(T)) ? 2.0^floor(log2(Float64(ref))) : floatmin(T))))
# which tier does BASE use? (reimplemented from the BASE source)
function tier(m)
  T = eltype(m.y); s = zero(T); for v in m.y; s += v * v; end
  p = m.s * s; q = T(p)
  (isfinite(s) && s >= 4 * length(m.y) * floatmin(T)) || return 3
  floatmin(T) <= q <= floatmax(T) && return 1
  S = typeof(p)
  if S !== T && floatmin(S) <= p <= floatmax(S)
    r = T(sqrt(p)); floatmin(T) <= r <= floatmax(T) && return 2
  end
  3
end
for (T, S) in ((Float32, Float64), (Float64, BigFloat), (Float32, BigFloat), (Float64, Float64), (Float32, Float32))
  tiers = zeros(Int, 3); changed = 0; tot2 = 0; maxdiff_ulp = 0.0; refuse_base = 0; refuse_x2 = 0; newref = 0; newacc = 0
  err_base = Float64[]; err_x2 = Float64[]; identical_other = 0; other = 0
  for trial in 1:60000
    n = rand(rng, (1, 2, 3, 10, 100, 1000, 10000))
    ey = rand(rng, T === Float32 ? (-70:70) : (-600:600))
    y = T.(randn(rng, n) .* 2.0^ey)
    isfinite(sum(y)) || continue
    # alpha chosen so that p lies around the edges of T: p = α Σy² ≈ 2^l
    s2 = sum(abs2, Float64.(y))
    l = T === Float32 ? rand(rng, -190:190) : rand(rng, -1200:1200)
    αf = 2.0^l / s2 * (0.5 + rand(rng))
    α = S === BigFloat ? BigFloat(αf) * BigFloat(2)^(l > 1000 ? 0 : 0) : S(αf)
    S === Float64 && !(isfinite(α) && α > 0) && continue
    S === Float32 && !(isfinite(α) && α > 0) && continue
    S === BigFloat && (T === Float64) && (α = BigFloat(rand(rng) + 0.5) * BigFloat(2)^rand(rng, -1100:1100) / BigFloat(s2) * BigFloat(2)^l)  # may exceed Float64 range
    m = B.LSModel(y, ones(T, n, 1), α)
    tr = tier(m); tiers[tr] += 1
    a = rsc(B, y, α); b = rsc(X, y, α)
    if tr == 2
      tot2 += 1
      a isa String && (refuse_base += 1); b isa String && (refuse_x2 += 1)
      if !(a isa String) && b isa String; newref += 1; end
      if a === b; else
        changed += 1
        if !(a isa String) && !(b isa String)
          maxdiff_ulp = max(maxdiff_ulp, Float64(abs(BigFloat(a) - BigFloat(b)) / BigFloat(eps(T) * a)) )
          ref = exactscale(y, α); push!(err_base, ulps(a, T, ref)); push!(err_x2, ulps(b, T, ref))
        end
      end
    else
      other += 1; (a === b) && (identical_other += 1)
    end
  end
  println("T=$T S=$S: trials by BASE tier (1,2,3) = $tiers; tier-2 inputs: $tot2, value changed: $changed, max |new-old| = $(round(maxdiff_ulp, digits=3)) eps(T)-units;",
          " BASE refuses $refuse_base, X2 refuses $refuse_x2 (accepted->refused: $newref); tier 1/3 inputs identical: $identical_other/$other")
  if !isempty(err_base)
    println("   tier-2 error vs exact (ulps of T): base mean/max = ", round(sum(err_base)/length(err_base), digits=2), "/", round(maximum(err_base), digits=2),
            "   x2 mean/max = ", round(sum(err_x2)/length(err_x2), digits=2), "/", round(maximum(err_x2), digits=2))
  end
end
# exact-sum cases (the summation error vanishes): where does a changed value come from?
println("\nFloat32 data, Float64 α, n=1 (the T-sum of one square has one rounding): tier 2 vs exceptional")
for (y, α) in ((Float32[1], 1e-40), (Float32[3], 1e45), (Float32[0.1], 2.0^-130), (Float32[1,2,3,4,5,6,7,8,9,10], 1e-41), (fill(0.1f0, 10_000), 1e-41))
  m = B.LSModel(y, ones(Float32, length(y), 1), α)
  println("   y=$(length(y)) entries α=$α  tier=$(tier(m))  base=$(rsc(B, y, α))  x2=$(rsc(X, y, α))  exact=$(Float32(exactscale(y, α)))")
end

# S = BigFloat scale (direct LSModel only; solve! refuses it) with Float64 data: α inside and outside the Float64 range
println("\nFloat64 data, BigFloat scale (direct LSModel only): BASE vs X2 by whether α is inside the Float64 range")
for (nm, rng_e) in (("inside  2^[-1000,1000]", -1000:1000), ("outside 2^[1030,3000] and 2^[-3000,-1080]", vcat(1030:3000, -3000:-1080)))
  tot = 0; chg = 0; newref = 0; maxrel = 0.0; tiers = zeros(Int, 3)
  for _ in 1:20000
    n = rand(rng, (1, 10, 1000)); ey = rand(rng, -600:600)
    y = randn(rng, n) .* 2.0^ey; isfinite(sum(abs2, y)) || continue
    α = BigFloat(0.5 + rand(rng)) * BigFloat(2)^rand(rng, rng_e)
    m = B.LSModel(y, ones(n, 1), α); tiers[tier(m)] += 1
    a = rsc(B, y, α); b = rsc(X, y, α); tot += 1
    if a !== b
      chg += 1
      if a isa String || b isa String; (a isa String) || (newref += 1); else maxrel = max(maxrel, Float64(abs(BigFloat(a) - BigFloat(b)) / BigFloat(a))); end
    end
  end
  println("  $nm: cases=$tot (BASE tiers 1/2/3 = $tiers), value changed=$chg, accepted->refused=$newref, max rel change among accepted-both=$(maxrel)")
end
