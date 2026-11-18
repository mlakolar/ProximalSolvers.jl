# D: boundary-targeted search. args: T n [part]
#   part 1: old = 0 with all λ; part 2: other old values with a few λ.
if @isdefined(DRIVER)      # run by d_all.jl, which loaded r1lib.jl into Main once
  using Printf, Random
  import Main: TREES, TNAMES, evaluate_r, oclass, zdiff
else
  include(joinpath(@__DIR__, "r1lib.jl"))
end
const TT = ARGS[1] == "32" ? Float32 : Float64
const NN = parse(Int, ARGS[2])
const PART = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 0
const T = TT
const base = TREES.base
cl(s, n) = isfinite(s) & (s >= n*(floatmin(T)/eps(T)))
# the computed sum of squares of the uniform vector v·1 (n entries), with the kernel of the step
function csum(v::T, n) where T
  x = fill(v, n); r = zeros(T, n)
  base._column_dot_rsqr(reshape(x, n, 1), r, 1, T(NaN))[1]
end
# first v (searching from a start by bisection over floats) with predicate true
function first_true(pred, lo::T, hi::T) where T      # pred(lo)=false, pred(hi)=true, monotone
  for _ in 1:200
    mid = T(sqrt(Float64(lo)*Float64(hi))); (mid <= lo || mid >= hi) && (mid = lo + (hi - lo)/2)
    (mid <= lo || mid >= hi) && break
    pred(mid) ? (hi = mid) : (lo = mid)
  end
  while nextfloat(lo) < hi
    mid = lo + (hi - lo)/2; (mid <= lo || mid >= hi) && break
    pred(mid) ? (hi = mid) : (lo = mid)
  end
  lo, hi
end
function ladder(n)
  p = precision(T)
  tlo, thi = first_true(v -> cl(csum(v, n), n), nextfloat(zero(T)), T(1))           # last failing, first passing
  elo, ehi = first_true(v -> !isfinite(csum(v, n)), T(1), floatmax(T))                # last finite, first overflowing
  vs = [nextfloat(zero(T)), ldexp(nextfloat(zero(T)), 20), prevfloat(floatmin(T)), floatmin(T), prevfloat(tlo), tlo, thi, nextfloat(thi),
        T(2)^(div(exponent(floatmin(T)), 2)), T(1), T(2)^(div(exponent(floatmax(T)), 2) - 1), elo, ehi, floatmax(T)]
  vs = unique(vs)
  filter(v -> isfinite(v) && v > 0, vs)
end
function shapes(v::T, n, tiny::T) where T     # (uniform, mixed: one big entry and n-1 tiny, alternating sign)
  u = fill(v, n)
  mx = n == 1 ? nothing : (w = fill(tiny, n); w[1] = v; w)
  al = [iseven(i) ? -v : v for i in 1:n]
  (u, mx, al)
end
function lamlist(xk::Vector{T}, r::Vector{T}) where T
  n = length(xk)
  setprecision(BigFloat, 512) do
    xb = big.(xk); rb = big.(r)
    a = sum(abs2, xb); ra = sqrt(a)
    ra_T = ra > big(floatmax(T)) ? floatmax(T) : T(ra)
    out = T[]
    push!(out, ra_T, prevfloat(ra_T), prevfloat(ra_T, 2), nextfloat(ra_T), T(ra/2), T(ra*(1 - big(2)^-10)),
         nextfloat(zero(T)), ldexp(nextfloat(zero(T)), 10), prevfloat(floatmin(T)), floatmin(T))
    # γλ targets from γ0 at λ = ra/2
    b = sum(xb .* rb); q = b/a; d = sqrt(sum(abs2, rb .- q .* xb))
    if d > 0
      γ0 = d / (ra * sqrt(ra^2 - (ra/2)^2))
      for tgt in (big(floatmin(T)), big(floatmax(T)))
        λ0 = tgt / γ0
        (λ0 > big(floatmax(T)) || λ0 < 0) && continue
        l = T(λ0)
        push!(out, prevfloat(l, 2), l, nextfloat(l, 2))
      end
    end
    out = unique(filter(l -> isfinite(l) && l > 0, out))
    out
  end
end
function gammapairs(v::T, n) where T       # r = vr·1 with d/p near floatmin and floatmax, at λ = ra/2
  out = Vector{T}[]
  setprecision(BigFloat, 512) do
    xk = fill(v, n); a = sum(abs2, big.(xk)); ra = sqrt(a)
    p0 = ra * sqrt(ra^2 - (ra/2)^2)
    for tgt in (big(floatmin(T)), big(floatmax(T)))
      vr0 = tgt * p0 / sqrt(big(n))
      (vr0 < big(floatmax(T)) && vr0 > 0) || continue
      v1 = T(vr0)
      for k in (-2, 0, 2); push!(out, fill(k < 0 ? prevfloat(v1, -k) : nextfloat(v1, k), n)); end
    end
  end
  out
end

function main()
  println("# julia ", VERSION, " T=", T, " n=", NN, " part=", PART)
  n = NN
  L = ladder(n)
  println("# ladder (", length(L), "): ", L)
  tiny = nextfloat(zero(T)) * 2^3
  # (x, r) pairs
  pairs = Tuple{Vector{T},Vector{T},String}[]
  for vx in L
    xu, xm, xa = shapes(vx, n, tiny)
    xs = [(xu, "xu")]; xm === nothing || push!(xs, (xm, "xm"))
    for vr in L
      ru, rm, ra_ = shapes(vr, n, tiny)
      rs = [(ru, "ru"), (ra_, "ra")]; rm === nothing || push!(rs, (rm, "rm"))
      for (x, xn) in xs, (r, rn) in rs
        push!(pairs, (x, r, xn * "/" * rn))
      end
    end
    for (x, xn) in xs
      push!(pairs, (x, zeros(T, n), xn * "/r0"))
      for j in (-300, -100, -1, 0, 1, 100, 300)       # parallel, by power of two (exact where in range)
        j = clamp(j, T === Float32 ? -120 : -1000, T === Float32 ? 120 : 1000)
        r = ldexp.(x, j); (all(isfinite, r)) && push!(pairs, (x, r, xn * "/par$j"))
      end
    end
    for r in gammapairs(vx, n); push!(pairs, (fill(vx, n), r, "xu/gam")); end
  end
  if PART == 3
    pairs = Tuple{Vector{T},Vector{T},String}[]
    n >= 2 || (println("# part 3 needs n >= 2"); return)
    emax = exponent(floatmax(T)); pT = precision(T)
    for x1e in (T === Float32 ? (-48, -46, -44, -42, -41) : (-481, -475, -470, -465, -460)), perp in (0, 1, 2, 3)
      for mant in (1.0, 1.1, 1.3737, 1.9999)
      x1 = T(mant)*T(2)^x1e
      x = zeros(T, n); x[1] = x1
      # q* = ulp(floatmax)/2 = 2^(emax - pT); also q* where old = -floatmax; also smaller old
      for qe in (emax - pT, emax - pT + 1, emax - pT - 1), k in -3:3
        q = ldexp(1.0, qe)*(1 + k*ldexp(1.0, -(pT - 1)))
        qT = T(q); r1 = qT*x1
        (isfinite(r1) && r1 > 0) || continue
        for big in (T(2)^(div(emax, 2) - 2), r1, T(2)^(div(emax, 2) - 30), nextfloat(zero(T)), zero(T))
          r = zeros(T, n); r[1] = r1; n >= 2 && (r[2] = big)
          # perpendicular part scale: r[2] with x[2] = 0
          isfinite(sum(abs2, Float64.(r))) || continue
          push!(pairs, (x, r, "qedge x1=$(mant)*2^$x1e q=2^$(qe)(1+$(k)u) perp=$(big)"))
        end
      end
    end
    end
    # x with 2 entries both nonzero (so the cancelling/parallel part exists): r = q x + perpendicular
  end
  println("# (x, r) pairs: ", length(pairs))
  oldlist(x, r) = PART == 3 ? T[floatmax(T), -floatmax(T), prevfloat(floatmax(T), 4)] : PART == 1 ? T[zero(T)] : T[nextfloat(zero(T)), floatmax(T), -floatmax(T), T(2)^(T === Float32 ? 100 : 900), ldexp(nextfloat(zero(T)), 30)]
  cnt = 0; skipped = 0
  worst = Dict(t => 0.0 for t in TNAMES); over = Dict(t => 0 for t in TNAMES)
  zflip = 0; cls = Dict{Symbol,Int}(); classmis = Dict{String,Int}(); ndiff = 0; maxulp = 0.0; maxrel = 0.0
  thr = Dict(t => 0 for t in TNAMES); nf = Dict(t => 0 for t in TNAMES); nrep = 0
  outc = Dict{Symbol,Int}(); clsdiff = Dict{Symbol,Int}(); worstcase = Ref{Any}(nothing); overcases = 0
  for (x, r, label) in pairs
    lams = lamlist(x, r)
    olds = oldlist(x, r)
    for old in olds, (li, λ) in enumerate(lams)
      PART == 2 && li > 8 && !(li in (9, 10)) && continue
      cnt += 1
      out = try evaluate_r(x, r, λ, old) catch e; skipped += 1; continue end
      b, c = out[:base], out[:cand]
      cls[b.cls] = get(cls, b.cls, 0) + 1
      outc[oclass(b) === :value ? :value : oclass(b) === :nonfinite ? :nonfinite : :throw] = get(outc, oclass(b) === :value ? :value : oclass(b) === :nonfinite ? :nonfinite : :throw, 0) + 1
      for t in TNAMES
        o = out[t]; o.thrown && (thr[t] += 1); o.nonfinite && (nf[t] += 1)
        if isfinite(o.ratio); o.ratio > worst[t] && (worst[t] = o.ratio; t === :cand && (worstcase[] = (x, r, λ, old, label, b.cls))); o.ratio > 1 && (over[t] += 1); end
      end
      if oclass(b) != oclass(c)
        k = string(b.cls, ": ", oclass(b), " => ", oclass(c)); classmis[k] = get(classmis, k, 0) + 1
        if nrep < 25
          nrep += 1; println("# MISMATCH ", label, " ", k, " base=", b.z, " ", first(b.msg, 50), " cand=", c.z, " ", first(c.msg, 50))
          println("xk(n=", length(x), ")=", repr(x[1:min(3, end)]), " uniq=", repr(unique(x)), "; r uniq=", repr(unique(r)), "; λ=", repr(λ), "; old=", repr(old))
        end
      elseif oclass(b) === :value && !(b.z === c.z)
        ndiff += 1; clsdiff[b.cls] = get(clsdiff, b.cls, 0) + 1; (iszero(b.z) != iszero(c.z)) && (zflip += 1)
        u, rl = zdiff(T, b.z, c.z); maxulp = max(maxulp, u); maxrel = max(maxrel, rl)
      end
      if isfinite(c.ratio) && c.ratio > 1 && nrep < 25
        nrep += 1; println("# BOUND cand ratio=", c.ratio, " base=", b.ratio, " ", label, " ", b.cls)
        println("xk(n=", length(x), ") uniq=", repr(unique(x)), "; r uniq=", repr(unique(r)), "; λ=", repr(λ), "; old=", repr(old))
      end
    end
  end
  @printf("RESULT %s n=%d part=%d cases=%d skipped=%d | worst excess/bound base=%.3e cand=%.3e | >1: base=%d cand=%d | differ=%d (zero flips %d; max %.3g ulp, max rel %.3g) | outcome-class mismatches=%d | throws b/c=%d/%d nonfinite b/c=%d/%d\n",
          T, n, PART, cnt, skipped, worst[:base], worst[:cand], over[:base], over[:cand], ndiff, zflip, maxulp, maxrel, sum(values(classmis); init = 0), thr[:base], thr[:cand], nf[:base], nf[:cand])
  println("  master outcomes: ", sort(collect(outc)), "; master class: ", sort(collect(cls)), "; differ by master class: ", sort(collect(clsdiff)))
  isempty(classmis) || println("  MISMATCHES: ", sort(collect(classmis)))
  worstcase[] === nothing || println("  cand worst case: ", worstcase[])
end
main()
