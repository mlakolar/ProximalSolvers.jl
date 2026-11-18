# The #378 sweep: one TSV row per solve of least-squares CD (unmodified package, probe model), with the
# solver's outcome, the candidate diagnostics in the working type, and the truth in BigFloat.
# usage: julia sweep378.jl OUT.tsv scalar|group Float32|Float64 DESIGN_INDEX [smoke]
include(joinpath(@__DIR__, "lib378.jl"))
setprecision(BigFloat, PREC)
const OUT, FAMILY, DIDX = ARGS[1], ARGS[2], parse(Int, ARGS[4])
const T = ARGS[3] == "Float32" ? Float32 : Float64
const SMOKE = length(ARGS) > 4 && ARGS[5] == "smoke"
const HEADER = ["family", "T", "design", "n", "p", "loss", "pen", "l1frac", "l2par", "start", "dir", "j", "container", "order", "momentum",
                "seed", "tol", "relative", "maxpasses", "status", "converged", "passes", "maxchange", "tolerance", "resp", "equiv", "mism",
                "nabs", "nhnz", "maxhulp", "nnz", "fresh", "A", "A0", "Araw", "Aq", "Aq0", "A0q", "Babs", "Ball", "Bq", "Ballq",
                "C352", "Cu", "Cuq", "K296", "Rimg", "Rinit", "R64", "P", "P0", "path",
                "conf_init", "confAq_init", "conf_img", "confAq_img",
                "kkt_rel", "subopt_lo", "subopt_hi", "tight", "informative", "E", "dres", "amp", "minerr", "F", "Fref"]
ladder(::Type{Float64}) = SMOKE ? (0, 40, 56) : (0, 8, 16, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60)
ladder(::Type{Float32}) = SMOKE ? (0, 14, 24) : (0, 4, 8, 10, 12, 14, 16, 18, 20, 22, 24, 28)
# ordinary starts: the default, a loose one, and thresholds down to below eps(T)
ordinary_tols(::Type{Float64}) = SMOKE ? (1e-7, 1e-16) : (1e-7, 1e-4, 1e-10, 1e-13, 1e-16)
ordinary_tols(::Type{Float32}) = SMOKE ? (1e-7, 1e-5) : (1e-7, 1e-4, 1e-5, 1e-6)
fmt(v) = v isa AbstractFloat ? @sprintf("%.6g", v) : string(v)
row(io, vals) = println(io, join((fmt(v) for v in vals), '\t'))
mom(m) = m === nothing ? "default" : string(m)
errtext(e) = replace(first(sprint(showerror, e), 60), '\t' => ' ', '\n' => ' ')

function starts(X64, y64, xref64, extra, seed)
  out = Tuple{String, String, Int, Vector{T}}[]
  p = length(xref64)
  push!(out, ("cold", "", 0, zeros(T, p)))
  push!(out, ("ref", "", 0, T.(xref64)))
  push!(out, ("pert", "", 0, T.(xref64 .* 1.05 .+ 1e-3)))
  for (name, v) in extra
    push!(out, (name, "", 0, T.(v)))
  end
  for (dname, z) in directions(X64, y64, xref64, SM64(seed)), j in ladder(T)
    x0 = T.(xref64 .+ 2.0^j .* z)
    all(isfinite, x0) && push!(out, ("adv", dname, j, x0))
  end
  out
end

# one solve: the probe run, the package's solve! on the same input, the diagnostics and the truth
function onesolve(io, ids, x0, f, g, X, y, s, container, order, momentum, seed, tol, relative, maxpasses, statsf, truthf)
  mk(rng) = CDSolver(; order, momentum, tol, relative, maxpasses, rng)
  rng1, rng2 = Xoshiro(seed), Xoshiro(seed)
  m1 = mk(rng1)
  status, res, r2, x2 = "ok", nothing, nothing, nothing
  try
    res = quiet(() -> probe_solve(x0, f, g, m1))
  catch e
    status = "error:" * errtext(e)
  end
  try
    x2 = x0 isa Vector ? (container === :dense ? copy(x0) : SparseIterate(copy(x0))) : copy(x0)
    r2 = quiet(() -> solve!(x2, f, g, mk(rng2)))
  catch e
    status == "ok" && (status = "solve-error:" * errtext(e))
  end
  base = Any[ids..., container, order, mom(momentum), seed, tol, relative, maxpasses, status]
  if res === nothing || r2 === nothing
    row(io, vcat(base, fill("NA", length(HEADER) - length(base))))
    return
  end
  st = res.st
  equiv = samebits(collect(res.work), collect(x2)) && r2.passes == st.passes && r2.converged == st.converged && rng1 == rng2 &&
          (r2.maxchange === st.maxchange || (iszero(r2.maxchange) && iszero(st.maxchange)))
  mism = res.w isa ProbeLS ? res.w.mism : 0
  resp = PS.response_scale(res.inner, res.work)
  base = vcat(base, Any[st.converged, st.passes, st.maxchange, st.tolerance, resp, equiv, mism])
  if !st.converged
    row(io, vcat(base, fill("NA", length(HEADER) - length(base))))
    return
  end
  d = statsf(res, m1)
  t = truthf(res)
  P0 = resolution(X, collect(x0), s)
  c = confirm!(res, g, X, y, m1, r -> statsf(r, m1))
  row(io, vcat(base, Any[d.nabs, d.nhnz, d.maxhulp, d.nnz, d.fresh, d.A, d.A0, d.Araw, d.Aq, d.Aq0, d.A0q, d.Babs, d.Ball, d.Bq, d.Ballq,
                         d.C352, d.Cu, d.Cuq, d.K296, d.Rimg, d.Rinit, d.R64, d.P, P0, d.path,
                         c.conf_init, c.confAq_init, c.conf_img, c.confAq_img,
                         t.kkt_rel, t.subopt_lo, t.subopt_hi, t.tight, t.informative, f64(t.E), f64(t.dres), f64(t.amp), t.minerr, f64(t.F), f64(t.Fref)]))
end

function scalar_runs(io)
  name, X0, y0 = designs()[DIDX]
  X, y = T.(X0), T.(y0)
  X64, y64 = Float64.(X), Float64.(y)
  n, p = size(X)
  big_design = n * p > 20_000
  for loss in (:raw, :mean)
    s = loss === :raw ? one(T) : one(T) / T(n)
    λmax = Float64(s) * maximum(abs, X64' * y64)
    iszero(λmax) && continue
    amed = sort([sum(abs2, view(X64, :, k)) for k in 1:p])[(p + 1) ÷ 2]
    ridge(ρ0) = ρ0 * Float64(s) * amed        # λ2 with λ2/(s a) = ρ0 at the median curvature
    # (label, l1 fraction of λmax, the recorded l2 parameter, λ2)
    pens = SMOKE ? [("l1", 0.0, 0.0, 0.0), ("l1", 0.1, 0.0, 0.0), ("enet352", 0.1, 0.5, 0.5 * λmax), ("enetr", 0.1, 100.0, ridge(100.0)), ("ridge", 0.0, 1.0, ridge(1.0))] :
      [("l1", 0.0, 0.0, 0.0), ("l1", 1e-3, 0.0, 0.0), ("l1", 0.1, 0.0, 0.0), ("l1", 0.5, 0.0, 0.0),
       ("enet352", 0.1, 0.5, 0.5 * λmax), ("enetr", 0.1, 0.01, ridge(0.01)), ("enetr", 0.1, 1.0, ridge(1.0)), ("enetr", 0.1, 100.0, ridge(100.0)),
       ("ridge", 0.0, 1.0, ridge(1.0))]
    refs = Dict{Any, Any}()
    for (pen, fr, l2p, λ2) in pens
      l1, l2 = T(fr * λmax), T(λ2)
      R = LassoRef(X, y, s, l1, l2)
      refs[(pen, fr, l2p)] = (R, reference(R, X64, y64, Float64(s), l1, l2))
    end
    xls = Float64.(refs[("l1", 0.0, 0.0)][2].xref)
    for (pen, fr, l2p, λ2) in pens
      R, ref = refs[(pen, fr, l2p)]
      ref.Fref > 0 || continue
      l1, l2 = T(fr * λmax), T(λ2)
      F0 = measures(R, zeros(p)).F
      tight = (ref.Fref - ref.Dref) / ref.Fref <= big(1e-12) && ref.Fref > big(1e-20) * F0
      informative = ref.Fref > big(1e-20) * F0
      S = max(R.l1, R.λmax)
      f = loss === :raw ? LeastSquaresLoss(y, X) : s * LeastSquaresLoss(y, X)
      g = pen == "l1" ? NormL1(l1) : ElasticNet(l1, l2)
      extra = Pair{String, Vector{Float64}}[]
      (fr > 0 || l2 > 0) && all(isfinite, T.(xls)) && push!(extra, "ls" => xls)
      nxt = pen == "l1" ? get(Dict(0.0 => 1e-3, 1e-3 => 0.1, 0.1 => 0.5), fr, nothing) : nothing
      nxt !== nothing && haskey(refs, ("l1", nxt, 0.0)) && push!(extra, "path" => Float64.(refs[("l1", nxt, 0.0)][2].xref))
      statsf = (res, method) -> scalar_stats(res, g, X, y, method)
      truthf = function (res)
        xv = collect(res.work)
        m = measures(R, xv)
        t = scalar_truth(R, xv, res.inner.r)
        (; kkt_rel = rel(m.G, S), subopt_lo = rel(m.F - ref.Fref, ref.Fref), subopt_hi = rel(m.F - ref.Dref, ref.Dref), tight, informative,
           E = t.E, dres = t.dres, amp = t.amp, minerr = rel(abs(big(res.minimum) - m.F), m.F), F = m.F, Fref = ref.Fref)
      end
      for (sname, dname, j, x0) in starts(X64, y64, Float64.(ref.xref), extra, UInt64(0x378 + DIDX))
        adv = sname == "adv"
        ids = Any["scalar", T, name, n, p, loss, pen, fr, l2p, sname, dname, j]
        configs = SMOKE || big_design ? [(:dense, :cyclic, false, 1), (:sparse, :random, nothing, 1), (:dense, :random, false, 1)] :
          [(:dense, :cyclic, false, 1), (:dense, :random, nothing, 1), (:dense, :random, nothing, 2), (:dense, :random, false, 1),
           (:sparse, :cyclic, false, 1), (:sparse, :random, nothing, 1), (:sparse, :random, true, 2), (:sparse, :random, false, 2)]
        # the adversarial ladder runs on half of the configurations
        adv && length(configs) > 4 && (configs = configs[[1, 2, 5, 8]])
        for (container, order, momentum, seed) in configs
          tols = Tuple{Float64, Bool}[(t, true) for t in (adv ? (1e-7, 1e-4) : ordinary_tols(T))]
          container === :dense && order === :cyclic && push!(tols, (1e-7, false))
          for (tol, relative) in tols
            xs = container === :dense ? x0 : SparseIterate(copy(x0))
            onesolve(io, ids, xs, f, g, X, y, s, container, order, momentum, seed, tol, relative, adv ? 5000 : (big_design ? 20_000 : 100_000), statsf, truthf)
          end
        end
      end
      flush(io)
    end
  end
end

function group_runs(io)
  name, X0, y0 = designs()[DIDX]
  X, y = T.(X0), T.(y0)
  X64, y64 = Float64.(X), Float64.(y)
  n, p = size(X)
  layouts = (("g3", p -> [collect(i:min(i + 2, p)) for i in 1:3:p]),
             ("mixed", p -> p >= 12 ? [[1], [2, 3], [4, 5, 6], collect(7:p)] : [[1], [2, 3], collect(4:p)]))
  for loss in (:raw, :mean), (lname, lay) in layouts
    p > n && lname != "g3" && continue
    s = loss === :raw ? one(T) : one(T) / T(n)
    groups = lay(p)
    g0 = GroupNormL2(one(T), groups)
    w = Float64.(g0.w)
    c = Float64(s) .* (X64' * y64)
    λmax = maximum(norm(c[idx]) / w[k] for (k, idx) in enumerate(groups))
    iszero(λmax) && continue
    for fr in (SMOKE ? (0.0, 0.1) : (0.0, 1e-3, 0.1, 0.5))
      λ = T(fr * λmax)
      g = GroupNormL2(λ, groups)
      f = loss === :raw ? LeastSquaresLoss(y, X) : s * LeastSquaresLoss(y, X)
      g64 = GroupNormL2(Float64(λ), groups, Float64.(g.w))
      xr = BlockIterate(Float64, p, g64)
      try
        quiet(() -> solve!(xr, Float64(s) * LeastSquaresLoss(y64, X64), g64, CDSolver(order = :cyclic, tol = 1e-15, maxpasses = 200_000)))
      catch
      end
      mr = group_measures(X, y, s, λ, groups, g.w, xr)
      if iszero(λ)
        R0 = LassoRef(X, y, s, zero(T), zero(T))
        Fs = measures(R0, smooth_minimizer(R0)).F
        mr = (; F = Fs, D = Fs, G = mr.G, λmax = mr.λmax)
      end
      mr.F > 0 || continue
      F0 = group_measures(X, y, s, λ, groups, g.w, zeros(p)).F
      tight = (mr.F - mr.D) / mr.F <= big(1e-12) && mr.F > big(1e-20) * F0
      informative = mr.F > big(1e-20) * F0
      S = max(big(λ), mr.λmax)
      statsf = (res, method) -> block_stats(res, g, X, y, method)
      truthf = function (res)
        xv = collect(res.work)
        m = group_measures(X, y, s, λ, groups, g.w, xv)
        t = block_truth(res, g, X, y)
        (; kkt_rel = rel(m.G, S), subopt_lo = rel(m.F - mr.F, mr.F), subopt_hi = rel(m.F - mr.D, mr.D), tight, informative,
           E = t.E, dres = t.dres, amp = t.amp, minerr = rel(abs(big(res.minimum) - m.F), m.F), F = m.F, Fref = mr.F)
      end
      for (sname, dname, j, x0) in starts(X64, y64, Float64.(collect(xr)), Pair{String, Vector{Float64}}[], UInt64(0x378 + DIDX))
        adv = sname == "adv"
        ids = Any["group-" * lname, T, name, n, p, loss, "group", fr, 0.0, sname, dname, j]
        for (order, seed) in (SMOKE ? ((:cyclic, 1),) : ((:cyclic, 1), (:random, 1), (:random, 2)))
          tols = Tuple{Float64, Bool}[(t, true) for t in (adv ? (1e-7, 1e-4) : ordinary_tols(T))]
          order === :cyclic && push!(tols, (1e-7, false))
          for (tol, relative) in tols
            xs = BlockIterate(copy(x0), g.groups)
            onesolve(io, ids, xs, f, g, X, y, s, :block, order, nothing, seed, tol, relative, adv ? 5000 : (n * p > 20_000 ? 20_000 : 100_000), statsf, truthf)
          end
        end
      end
      flush(io)
    end
  end
end

open(OUT, "w") do io
  println(io, join(HEADER, '\t'))
  FAMILY == "scalar" ? scalar_runs(io) : group_runs(io)
end
println("done ", FAMILY, " ", T, " design ", DIDX, " ", designs()[DIDX][1], " Julia ", VERSION, " ", Sys.CPU_NAME)
