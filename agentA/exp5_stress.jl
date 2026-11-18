include("lib.jl")
if get(ENV, "OVERLAY", "") != ""
  include("optB.jl"); include("optC.jl"); include("optC2.jl")
  ENV["OVERLAY"] == "C" ? install_C!() : ENV["OVERLAY"] == "C2" ? install_C2!() : ENV["OVERLAY"] == "B1R" ? (install_B1!(); Core.eval(PS, :(@inline _clean_sum(s::T, n::Int) where T = isfinite(s) & (s >= 4n*floatmin(T))))) : ENV["OVERLAY"] == "C2R" ? (install_C2!(); Core.eval(PS, :(@inline _clean_sum(s::T, n::Int) where T = isfinite(s) & (s >= 4n*floatmin(T))))) : install_B1!()
end
# E5: random stress of the real coordinate step (one column), wide independent scales, near-parallel residuals,
# lambda near sqrt(a). Reports max excess/bound by branch and every violation (ratio > 1) or non-finite result.
function onecol(T, rng)
  n = rand(rng, 2:12)
  lo, hi = T === Float32 ? (-75, 60) : (-520, 500)
  sx = rand(rng, lo:hi); sr = rand(rng, lo:hi)
  xk = T.(ldexp.(randn(rng, n), sx))
  mode = rand(rng, 0:3)
  u = randn(rng, n)
  if mode == 0; ρ = u
  elseif mode == 1; ρ = randn(rng) .* (xk ./ maximum(abs, xk)) .+ 10.0^(-rand(rng)*12) .* u
  elseif mode == 2; ρ = randn(rng) .* (xk ./ maximum(abs, xk))
  else ρ = u .* 10.0 .^ (rand(rng, n) .* 8 .- 4); end
  ρ = T.(ldexp.(ρ, sr))
  (all(isfinite, xk) && all(isfinite, ρ) && any(!iszero, xk)) || return nothing
  ra = sqrt(sum(abs2, Float64.(xk)))
  fk = rand(rng, 1:3)
  f = fk == 1 ? 10.0^(-8*rand(rng)) : fk == 2 ? 1 - 2.0^(-rand(rng, 1:50)) : rand(rng)
  λ = T(f*ra)
  (isfinite(λ) && λ > 0) || return nothing
  old = rand(rng) < 0.5 ? zero(T) : T(ldexp(randn(rng), rand(rng, -20:20) + (sr - sx)))
  isfinite(old) || return nothing
  # model: y chosen so that r = y - x*old equals roughly rho: use y = rho + x*old (rounded) -> r is whatever the model holds
  y = ρ .+ xk .* old
  all(isfinite, y) || return nothing
  (xk, y, λ, old, mode, f)
end
function main(T, N)
  rng = Xoshiro(2718)
  worst = Dict{Symbol,Float64}(); cnt = Dict{Symbol,Int}(); viol = String[]; errs = Dict{String,Int}()
  nt = 0; nunrep = 0
  while nt < N
    t = onecol(T, rng); t === nothing && continue
    xk, y, λ, old, mode, f = t
    n = length(y)
    X = reshape(copy(xk), n, 1)
    m, g, x = make_model(X, y, λ, T[old])
    r0 = copy(m.ls.r)
    v = Base.invokelatest(visit!, m, g, x, 1)
    nt += 1
    cnt[v.branch] = get(cnt, v.branch, 0) + 1
    if v.err !== nothing
      k = first(split(sprint(showerror, v.err), '\n'))[1:min(end,60)]
      errs[k] = get(errs, k, 0) + 1
      continue
    end
    if !isfinite(v.znew)
      # a nonfinite new coordinate is acceptable only when the exact minimizer is not representable in T
      ref = bigref(xk, r0, old, m.gt.λ0)
      unrep = abs(ref.zstar) >= big(floatmax(T))
      unrep || push!(viol, "nonfinite znew with representable z* (=$(Float64(ref.zstar)), c=$(Float64(ref.c))) mode=$mode f=$f branch=$(v.branch)")
      nunrep += unrep; continue
    end
    worst[v.branch] = max(get(worst, v.branch, 0.0), v.ratio)
    if v.ratio > 1
      push!(viol, @sprintf("ratio %.3g branch %s mode %d f %.17g n %d", v.ratio, v.branch, mode, f, n))
    end
  end
  println(T, " N=", nt, " branches: ", fmtcnt(cnt))
  println("  worst ratio by branch: ", worst)
  println("  refusals/throws: ", errs, "; nonfinite result with unrepresentable exact minimizer: ", nunrep)
  println("  violations (ratio>1 or nonfinite): ", length(viol)); foreach(s -> println("    ", s), first(viol, 10))
end
for T in (Float32, Float64); main(T, 40000); end
