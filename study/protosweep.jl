# The inputs of sweep378.jl (same designs, penalties, starts; a subset of the configurations) solved by
# master and by each prototype, compiled from source in this process. One TSV row per solve and
# module, with the outcome and the truth of the returned point in BigFloat.
# usage: julia protosweep.jl OUT.tsv scalar|group Float32|Float64 DESIGN_INDEX PROTO [smoke]
const PROTO = abspath(ARGS[5])
include(joinpath(@__DIR__, "lib378.jl"))
include(joinpath(@__DIR__, "protolib.jl"))
setprecision(BigFloat, PREC)
const OUT, FAMILY, DIDX = ARGS[1], ARGS[2], parse(Int, ARGS[4])
const T = ARGS[3] == "Float32" ? Float32 : Float64
const SMOKE = length(ARGS) > 5 && ARGS[6] == "smoke"
const USE = [(n, P) for (n, P) in MODS if n in ("master", "A", "R", "F")]
const HEADER = ["family", "T", "design", "n", "p", "loss", "pen", "l1frac", "l2par", "start", "dir", "j", "container", "order", "momentum",
                "seed", "tol", "relative", "maxpasses", "module", "status", "converged", "passes", "maxchange", "tolerance",
                "kkt_rel", "subopt_lo", "subopt_hi", "tight", "informative", "E"]
ladder(::Type{Float64}) = SMOKE ? (0, 40, 56) : (0, 8, 16, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60)
ladder(::Type{Float32}) = SMOKE ? (0, 14, 24) : (0, 4, 8, 10, 12, 14, 16, 18, 20, 22, 24, 28)
fmt(v) = v isa AbstractFloat ? @sprintf("%.6g", v) : string(v)
row(io, vals) = println(io, join((fmt(v) for v in vals), '\t'))
mom(m) = m === nothing ? "default" : string(m)
errtext(e) = replace(first(sprint(showerror, e), 60), '\t' => ' ', '\n' => ' ')
function starts(X64, y64, xref64, extra, seed)        # as in sweep378.jl
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
function onesolve(io, ids, mkx, f, g, container, order, momentum, seed, tol, maxpasses, truthf)
  for (mname, P) in USE
    x = mkx()
    base = Any[ids..., container, order, mom(momentum), seed, tol, true, maxpasses, mname]
    r = try
      quiet(() -> P.solve!(x, f, g, P.CDSolver(; order, momentum, tol, maxpasses, rng = Xoshiro(seed))))
    catch e
      row(io, vcat(base, Any["error:" * errtext(e)], fill("NA", length(HEADER) - length(base) - 1)))
      continue
    end
    t = truthf(collect(x), r.tolerance)
    row(io, vcat(base, Any["ok", r.converged, r.passes, r.maxchange, r.tolerance, t.kkt_rel, t.subopt_lo, t.subopt_hi, t.tight, t.informative, t.E]))
  end
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
    ridge(ρ0) = ρ0 * Float64(s) * amed
    pens = SMOKE ? [("l1", 0.0, 0.0, 0.0), ("l1", 0.1, 0.0, 0.0), ("enetr", 0.1, 100.0, ridge(100.0))] :
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
      truthf = function (xv, thr)
        m = measures(R, xv)
        t = scalar_truth(R, xv, zeros(T, n))
        (; kkt_rel = rel(m.G, S), subopt_lo = rel(m.F - ref.Fref, ref.Fref), subopt_hi = rel(m.F - ref.Dref, ref.Dref), tight, informative,
           E = Float64(t.E / thr))
      end
      for (sname, dname, j, x0) in starts(X64, y64, Float64.(ref.xref), extra, UInt64(0x378 + DIDX))
        adv = sname == "adv"
        ids = Any["scalar", T, name, n, p, loss, pen, fr, l2p, sname, dname, j]
        for (container, order, momentum, seed) in [(:dense, :cyclic, false, 1), (:dense, :random, nothing, 1), (:sparse, :random, false, 2)]
          for tol in (1e-7, 1e-4)
            mkx = container === :dense ? (() -> copy(x0)) : (() -> SparseIterate(copy(x0)))
            onesolve(io, ids, mkx, f, g, container, order, momentum, seed, tol, adv ? 5000 : (big_design ? 20_000 : 100_000), truthf)
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
      truthf = function (xv, thr)
        m = group_measures(X, y, s, λ, groups, g.w, xv)
        (; kkt_rel = rel(m.G, S), subopt_lo = rel(m.F - mr.F, mr.F), subopt_hi = rel(m.F - mr.D, mr.D), tight, informative, E = NaN)
      end
      for (sname, dname, j, x0) in starts(X64, y64, Float64.(collect(xr)), Pair{String, Vector{Float64}}[], UInt64(0x378 + DIDX))
        adv = sname == "adv"
        ids = Any["group-" * lname, T, name, n, p, loss, "group", fr, 0.0, sname, dname, j]
        for (order, seed) in ((:cyclic, 1), (:random, 1)), tol in (1e-7, 1e-4)
          onesolve(io, ids, () -> BlockIterate(copy(x0), g.groups), f, g, :block, order, nothing, seed, tol, adv ? 5000 : (n * p > 20_000 ? 20_000 : 100_000), truthf)
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
println("done ", FAMILY, " ", T, " design ", DIDX, " ", designs()[DIDX][1], " Julia ", VERSION, " ", Sys.CPU_NAME, " floors ", join((n * "=" * string(floor_of(P)) for (n, P) in USE[2:end]), " "))
