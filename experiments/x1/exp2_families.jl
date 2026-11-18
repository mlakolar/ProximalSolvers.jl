# X1 experiment 2: step accuracy against BigFloat-512, families x type x tree. Usage: julia --project=ps-353 exp2_families.jl N SEED
include("x1lib.jl")
const N = parse(Int, get(ARGS, 1, "300")); const SEED = parse(Int, get(ARGS, 2, "1"))
nsel(rng) = (u = rand(rng); u < 0.02 ? 2000 : u < 0.12 ? 1 : u < 0.27 ? 2 : u < 0.5 ? 3 : u < 0.8 ? 12 : 30)
fin(v) = all(isfinite, v)
function ra_big(xk)
  setprecision(BigFloat, 512) do; sqrt(sum(abs2, big.(xk))); end
end
function lam_from(rng, T, xk; f = nothing)
  ra = ra_big(xk)
  ff = f === nothing ? (u = rand(rng); u < 0.3 ? rand(rng) : u < 0.5 ? 1 - 2.0^(-rand(rng, 1:50)) : u < 0.7 ? 10.0^(-8*rand(rng)) : [0.5, 0.99, 0.999][rand(rng, 1:3)]) : f
  λ = setprecision(BigFloat, 512) do; T(ff*ra); end
  (isfinite(λ) && λ > 0) ? λ : nothing
end
# y from r target and old: y = ρ + xk*old rounded in T
mk(xk::Vector{T}, ρ, λ, old) where T = (y = T.(ρ .+ xk .* big_or(old)); (fin(y) && isfinite(old) && λ !== nothing && fin(xk) && any(!iszero, xk)) ? (xk, y, λ, old) : nothing)
big_or(old) = Float64(old)    # old is small relative or 0; the rounding of y is part of the stored inputs
function gauss(rng, T, n, s)  # T-vector, gaussian scaled by 2^s
  T.(ldexp.(randn(rng, n), s))
end
function dirvec(rng, n)        # unit-ish direction
  u = randn(rng, n); u ./ norm(u)
end
rng_s(T) = T === Float32 ? (-148, 127) : (-1070, 1020)
mod_s(T) = T === Float32 ? (-75, 60) : (-520, 500)
oldval(rng, T, s) = rand(rng) < 0.5 ? zero(T) : T(ldexp(randn(rng), s + rand(rng, -10:10)))

function fam_ordinary(rng, T)
  n = nsel(rng); xk = gauss(rng, T, n, 0); ρ = randn(rng, n); λ = lam_from(rng, T, xk)
  λ === nothing && return nothing; mk(xk, ρ, λ, oldval(rng, T, 0))
end
function fam_wide_mod(rng, T)
  n = nsel(rng); lo, hi = mod_s(T); sx, sr = rand(rng, lo:hi), rand(rng, lo:hi)
  xk = gauss(rng, T, n, sx); ρ = ldexp.(randn(rng, n), sr); λ = lam_from(rng, T, xk)
  λ === nothing && return nothing; fin(T.(ρ)) || return nothing
  mk(xk, T.(ρ), λ, oldval(rng, T, sr - sx))
end
function fam_wide_full(rng, T)
  n = nsel(rng); lo, hi = rng_s(T); sx, sr = rand(rng, lo:hi), rand(rng, lo:hi)
  xk = gauss(rng, T, n, sx); ρ = T.(ldexp.(randn(rng, n), sr)); λ = lam_from(rng, T, xk)
  λ === nothing && return nothing; fin(ρ) || return nothing
  mk(xk, ρ, λ, rand(rng) < 0.7 ? zero(T) : (o = T(ldexp(randn(rng), clamp(sr - sx, -1000, 1000))); isfinite(o) ? o : zero(T)))
end
function fam_near_parallel(rng, T)    # d^2 < rho^2/16: r = c xhat + eps u, incl. exactly parallel (d = 0)
  n = max(nsel(rng), 2); s = rand(rng, -20:20); sr = rand(rng, -20:20)
  xk = gauss(rng, T, n, s); u = randn(rng, n); mode = rand(rng, 1:4)
  xh = Float64.(xk) ./ norm(Float64.(xk))
  ρ = if mode == 1; ldexp.(xh, sr)                                        # exactly parallel up to rounding of xh
      elseif mode == 2; T(2)^(sr) .* xk                                   # exactly parallel (power of two multiple)
      else ldexp.(randn(rng) .* xh .+ 10.0^(-(1 + 11*rand(rng))) .* u, sr) end
  λ = lam_from(rng, T, xk); λ === nothing && return nothing
  mk(xk, T.(ρ), λ, mode == 2 ? zero(T) : oldval(rng, T, 0))
end
function fam_tiny_d(rng, T)           # d^2 nonzero but below n floatmin/eps at ordinary |r|: r = c x + δ e_n, x_n = 0
  n = max(nsel(rng), 2); n = min(n, 30)
  xk = gauss(rng, T, n, 0); xk[n] = 0
  c = randn(rng); s = T === Float32 ? rand(rng, 35:80) : rand(rng, 480:1100)
  ρ = Float64.(c .* xk); ρ = T.(ρ); ρ[n] = T(ldexp(1.0, -s))
  λ = lam_from(rng, T, xk); λ === nothing && return nothing
  mk(xk, ρ, λ, zero(T))
end
function fam_lam_near(rng, T)         # λ within a few ulps of √a, and within 1e-3 relative
  n = nsel(rng); xk = gauss(rng, T, n, 0); ρ = rand(rng) < 0.5 ? randn(rng, n) : (Float64.(xk) .* randn(rng) .+ 1e-6 .* randn(rng, n))
  ra = ra_big(xk); λ0 = T(ra)
  λ = rand(rng) < 0.5 ? (k = rand(rng, -4:4); foldl((v, _) -> k >= 0 ? nextfloat(v) : prevfloat(v), 1:abs(k); init = λ0)) :
      T(ra * (1 - 1e-3*rand(rng)))
  (isfinite(λ) && λ > 0) || return nothing
  mk(xk, T.(ρ), λ, oldval(rng, T, 0))
end
thr(T, n) = n * (floatmin(T)/eps(T))
function fam_thresh(rng, T)           # a or ρ² (or both) within a factor ~2 of n floatmin/eps, above and below
  n = max(nsel(rng), 1); n = min(n, 30); which = rand(rng, 1:3)
  f1, f2 = 2.0^(rand(rng)*3 - 1.5), 2.0^(rand(rng)*3 - 1.5)
  sc = sqrt(Float64(thr(T, n)))     # norm whose square is the threshold
  xn = which != 2 ? sc*sqrt(f1) : 1.0; rn = which != 1 ? sc*sqrt(f2) : 1.0
  if which == 3 && rand(rng) < 0.5; rn = xn*rand(rng, 1:4)*sqrt(f2); end
  xk = T.(dirvec(rng, n) .* xn); ρ = T.(dirvec(rng, n) .* rn)
  λ = lam_from(rng, T, xk); λ === nothing && return nothing
  mk(xk, ρ, λ, rand(rng) < 0.7 ? zero(T) : T(randn(rng)*rn/xn))
end
function fam_corner(rng, T)           # ρ² in thr*[1,1e4] and recomputed d² unclean, λ/ra in {0.5,0.99,0.999,1-4eps}
  n = max(min(nsel(rng), 30), 2)
  U = 10.0^(4*rand(rng)); R = sqrt(thr(T, n)*U)
  f = [0.5, 0.99, 0.999, 1 - 4*eps(T)][rand(rng, 1:4)]
  anear = rand(rng) < 0.5
  xn = anear ? sqrt(thr(T, n))*2.0^(rand(rng)*2) : 2.0^rand(rng, -3:3)
  xh = dirvec(rng, n); xh[n] = 0; xh ./= norm(xh)
  xk = T.(xh .* xn)
  δ = R * 10.0^(-(0.7 + 8*rand(rng)))
  # unclean d²: δ² < thr; ensure
  δ = min(δ, 0.5*sqrt(thr(T, n)))
  ρ = T.(Float64.(xk) ./ norm(Float64.(xk)) .* R); ρ[n] = T(δ)
  rand(rng) < 0.2 && (ρ[n] = zero(T))
  λ = setprecision(BigFloat, 512) do; T(f*ra_big(xk)); end
  (isfinite(λ) && λ > 0) || return nothing
  mk(xk, ρ, λ, zero(T))
end
function fam_far(rng, T)              # one of column/residual far outside the clean range (cold inputs, either type)
  n = max(min(nsel(rng), 30), 1)
  tiny = T === Float32 ? (-148:-40) : (-1070:-480); huge = T === Float32 ? (40:127) : (480:1020)
  pick() = rand(rng) < 0.5 ? rand(rng, tiny) : rand(rng, huge)
  sx, sr = pick(), pick()
  xk = gauss(rng, T, n, sx); ρ = T.(ldexp.(randn(rng, n), sr)); fin(ρ) || return nothing
  λ = lam_from(rng, T, xk); λ === nothing && return nothing
  mk(xk, ρ, λ, zero(T))
end
function fam_band(rng, T)             # a and ρ² clean, ratio ‖r‖/‖x‖² beyond the normal range of d/p
  n = max(min(nsel(rng), 30), 2)
  hi = rand(rng) < 0.5
  if T === Float32
    sx, sr = hi ? (rand(rng, -51:-47), rand(rng, 38:62)) : (rand(rng, 47:62), rand(rng, -51:-38))
  else
    sx, sr = hi ? (rand(rng, -484:-478), rand(rng, 470:509)) : (rand(rng, 485:505), rand(rng, -484:-465))
  end
  xk = gauss(rng, T, n, sx); ρ = T.(ldexp.(randn(rng, n), sr)); fin(ρ) || return nothing
  λ = lam_from(rng, T, xk); λ === nothing && return nothing
  mk(xk, ρ, λ, zero(T))
end
function fam_subnormal_lam(rng, T)
  n = nsel(rng); xk = gauss(rng, T, n, 0); ρ = randn(rng, n)
  j = rand(rng, 0:(T === Float32 ? 23 : 52)); λ = ldexp(nextfloat(zero(T)), j)
  λ = T(λ); mk(xk, T.(ρ), λ, oldval(rng, T, 0))
end
function fam_huge_edge(rng, T)        # a and ρ² within ~1e-6 of floatmax, r ≈ x (Cauchy-Schwarz saturated): b may round to Inf
  n = max(min(nsel(rng), 12), 1)
  xh = dirvec(rng, n); sc = sqrt(Float64(floatmax(T)))*(1 - 1e-6*rand(rng))
  T === Float32 && (sc = sqrt(Float64(floatmax(Float32)))*(1 - 1e-6*rand(rng)))
  xk = T.(xh .* sc); ρ = rand(rng) < 0.5 ? copy(xk) : T.(xh .* sc .* (1 - 1e-7*rand(rng)) .+ 1e-3*sc .* randn(rng, n) .* (rand(rng) < 0.5))
  fin(xk) && fin(ρ) || return nothing
  λ = lam_from(rng, T, xk); λ === nothing && return nothing
  mk(xk, ρ, λ, zero(T))
end
const FAMS = [:ordinary => fam_ordinary, :wide_mod => fam_wide_mod, :wide_full => fam_wide_full, :near_parallel => fam_near_parallel,
              :tiny_d => fam_tiny_d, :lam_near => fam_lam_near, :thresh => fam_thresh, :corner => fam_corner,
              :far => fam_far, :huge_edge => fam_huge_edge, :band => fam_band, :sub_lam => fam_subnormal_lam]
function main()
  println("# julia ", VERSION, " N=", N, " seed=", SEED, ". columns: family type tree | count | worst ratio | #ratio>1 | throws | nonfinite")
  repro = open(joinpath(@__DIR__, "exp2_repro_$(VERSION.major).$(VERSION.minor)_s$(SEED).txt"), "w")
  only = length(ARGS) >= 3 ? Symbol.(split(ARGS[3], ',')) : nothing
  for (fname, gen) in FAMS, T in (Float32, Float64)
    (only === nothing || fname in only) || continue
    rng = Xoshiro(hash((fname, T, SEED)))
    cnt = 0; worst = Dict(t => 0.0 for t in TNAMES); over = Dict(t => 0 for t in TNAMES)
    thr_ = Dict(t => 0 for t in TNAMES); nf = Dict(t => 0 for t in TNAMES); msgs = Dict{String,Int}()
    wl = Dict{Symbol,Any}(t => nothing for t in TNAMES); nrep = 0
    lost = Dict(:x1a => Dict{Symbol,Int}(), :x1b => Dict{Symbol,Int}(), :gain_a => Dict{Symbol,Int}(), :gain_b => Dict{Symbol,Int}())
    nfrep = Dict(t => [0, 0] for t in TNAMES)   # nonfinite results [with z* representable, with z* not representable]
    tries = 0
    while cnt < N && tries < 20N
      tries += 1
      inp = gen(rng, T); inp === nothing && continue
      out = evaluate(inp...)
      cnt += 1
      flag = false
      for t in TNAMES
        o = out[t]
        o.thrown && (thr_[t] += 1; msgs[string(t, ": ", first(o.msg, 60))] = get(msgs, string(t, ": ", first(o.msg, 60)), 0) + 1)
        o.nonfinite && (nf[t] += 1; nfrep[t][o.repr_ok ? 1 : 2] += 1)
        if isfinite(o.ratio)
          o.ratio > worst[t] && (worst[t] = o.ratio; wl[t] = inp)
          o.ratio > 1 && (over[t] += 1)
        end
      end
      ba = out[:base]
      # lost / gained inputs: BASE returns (no throw) and the prototype throws, classified by the inequality (cause = info of the computed a, ρ²)
      for (t, gk) in ((:x1a, :gain_a), (:x1b, :gain_b))
        o = out[t]
        if !ba.thrown && o.thrown; d = lost[t]; d[o.info] = get(d, o.info, 0) + 1
        elseif ba.thrown && !o.thrown; d = lost[gk]; d[:ok] = get(d, :ok, 0) + 1; end
      end
      for t in (:x1a, :x1b)
        o = out[t]
        if ((isfinite(o.ratio) && o.ratio > 1 && !(ba.ratio > 1)) || (o.nonfinite && !ba.nonfinite)) && nrep < 6
          nrep += 1
          println(repro, "# ", fname, " ", T, " tree=", t, " ratio=", o.ratio, " base=", ba.ratio, " nonfinite=", o.nonfinite)
          println(repro, "xk=", repr(inp[1]), "; y=", repr(inp[2]), "; λ=", repr(inp[3]), "; old=", repr(inp[4]))
        end
      end
    end
    for t in TNAMES
      @printf("%-14s %-8s %-5s | %5d | %.3e | %3d | %4d | %3d\n", fname, T, t, cnt, worst[t], over[t], thr_[t], nf[t])
    end
    for (k, v) in sort(collect(msgs)); println("    ", k, " x", v); end
    println("    lost (BASE ok, proto throws) by cause of the computed (a, ρ²): x1a=", sort(collect(lost[:x1a])), " x1b=", sort(collect(lost[:x1b])), "; gained (BASE throws, proto ok): x1a=", lost[:gain_a], " x1b=", lost[:gain_b])
    println("    nonfinite results [z* representable, z* not]: ", join(["$t=$(nfrep[t])" for t in TNAMES], " "))
    flush(stdout)
  end
  close(repro)
end
main()
