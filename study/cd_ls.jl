# CD, least squares: lasso, elastic net (scalar) and group lasso (block). One TSV row per solve.
# usage: julia cd_ls.jl OUT.tsv [scalar|group]
include(joinpath(@__DIR__, "lib.jl"))
setprecision(BigFloat, PREC)

const TYPES = length(ARGS) > 2 ? (ARGS[3] == "Float32" ? (Float32,) : (Float64,)) : (Float64, Float32)
const FIX = haskey(ENV, "SMOKE") ? [fixture(ENV["SMOKE"])] : fixtures()
const HEADER = ["family", "T", "fixture", "loss", "penalty", "l1frac", "l1", "l2", "container", "order", "momentum",
                "tol", "relative", "start", "seed", "status", "converged", "passes", "maxchange", "tolerance", "warned",
                "kkt_rel", "kkt_over_l1", "gap_at_x", "subopt_lo", "subopt_hi", "ref_tight", "min_err", "F", "nnz", "Fref", "F0"]

function cd_solver(order, momentum, tol, relative, seed, maxpasses)
  kw = (; order, momentum, relative, maxpasses, rng = Xoshiro(seed))
  tol === nothing ? CDSolver(; kw...) : CDSolver(; tol, kw...)
end

function scalar_runs(io)
  for T in TYPES, (name, X0, y0) in FIX, loss in (:raw, :mean)
    X, y = T.(X0), T.(y0)
    n, p = size(X)
    s = loss === :raw ? one(T) : one(T) / T(n)
    λmax = Float64(s) * maximum(abs, Float64.(X)' * Float64.(y))
    fracs = iszero(λmax) ? [0.0, 1.0] : [0.0, 1e-3, 0.1, 0.5, 1.01, 2.0]
    pens = Tuple{String, Float64, T, T}[]
    for fr in fracs
      l1 = iszero(λmax) ? T(fr) : T(fr * λmax)
      push!(pens, ("l1", fr, l1, zero(T)))
    end
    l2 = iszero(λmax) ? one(T) : T(0.5 * λmax)
    for fr in (0.0, 0.1, 1.01)
      l1 = iszero(λmax) ? T(fr) : T(fr * λmax)
      push!(pens, ("enet", fr, l1, l2))
    end
    for (pen, fr, l1, l2) in pens
      R = LassoRef(X, y, s, l1, l2)
      ref = reference(R, Float64.(X), Float64.(y), Float64(s), l1, l2)
      F0 = measures(R, zeros(p)).F
      tight = ref.Fref > 0 && (ref.Fref - ref.Dref) / ref.Fref <= big(1e-12) && ref.Fref > big(1e-20) * F0
      S = max(R.l1, R.λmax)
      f = loss === :raw ? LeastSquaresLoss(y, X) : s * LeastSquaresLoss(y, X)
      g = pen == "l1" ? NormL1(l1) : ElasticNet(l1, l2)
      starts = (("cold", zeros(T, p)), ("ref", T.(ref.xref)), ("pert", T.(ref.xref .* 1.05 .+ 1e-3)))
      tols = T === Float64 ? (nothing, 1e-4, 1e-10) : (nothing, 1e-4, 1e-5)
      for container in (:dense, :sparse), (order, momentum, seeds) in ((:cyclic, false, (1,)), (:random, nothing, (1, 2)), (:random, false, (1, 2))),
          tol in tols, relative in (true, false), (sname, x0) in starts, seed in seeds
        relative || tol === nothing || continue
        x = container === :dense ? copy(x0) : SparseIterate(copy(x0))
        status, res, msgs = "ok", nothing, String[]
        try
          res, msgs = capture() do
            solve!(x, f, g, cd_solver(order, momentum, tol, relative, seed, 100_000))
          end
        catch e
          status = "error:" * first(sprint(showerror, e), 60)
        end
        row = Any["scalar", T, name, loss, pen, fr, l1, l2, container, order, momentum === nothing ? "default" : momentum,
                  tol === nothing ? "default" : tol, relative, sname, seed, status]
        if res === nothing
          append!(row, fill("NA", length(HEADER) - length(row)))
        else
          xv = collect(x)
          m = measures(R, xv)
          append!(row, Any[res.converged, res.passes, res.maxchange, res.tolerance, length(msgs),
                           rel(m.G, S), rel(m.G, R.l1), rel(m.F - m.D, m.F), rel(m.F - ref.Fref, ref.Fref),
                           rel(m.F - ref.Dref, ref.Dref), tight, rel(abs(big(res.minimum) - m.F), m.F), f64(m.F), count(!iszero, xv), f64(ref.Fref), f64(F0)])
        end
        tsv(io, row...)
      end
    end
    flush(io)
  end
end

function group_runs(io)
  layouts = (("g3", p -> [collect(i:min(i + 2, p)) for i in 1:3:p]),
             ("mixed", p -> p >= 12 ? [[1], [2, 3], [4, 5, 6], collect(7:p)] : [[1], [2, 3], collect(4:p)]))
  for T in TYPES, (name, X0, y0) in FIX, loss in (:raw, :mean), (lname, lay) in layouts
    name == "wide" || name == "wide_exact" ? (lname == "g3" || continue) : nothing
    X, y = T.(X0), T.(y0)
    n, p = size(X)
    s = loss === :raw ? one(T) : one(T) / T(n)
    groups = lay(p)
    g0 = GroupNormL2(one(T), groups)
    w = Float64.(g0.w)
    c = Float64(s) .* (Float64.(X)' * Float64.(y))
    λmax = maximum(norm(c[idx]) / w[k] for (k, idx) in enumerate(groups))
    fracs = iszero(λmax) ? [0.0, 1.0] : [0.0, 1e-3, 0.1, 0.5, 1.01]
    for fr in fracs
      λ = iszero(λmax) ? T(fr) : T(fr * λmax)
      g = GroupNormL2(λ, groups)
      f = loss === :raw ? LeastSquaresLoss(y, X) : s * LeastSquaresLoss(y, X)
      # reference: the package's Float64 solve at a tight threshold, judged by its BigFloat gap
      X64, y64 = Float64.(X), Float64.(y)
      g64 = GroupNormL2(Float64(λ), groups, Float64.(g.w))     # the weights of g, exactly
      xr = BlockIterate(Float64, p, g64)
      f64l = Float64(s) * LeastSquaresLoss(y64, X64)
      try
        quiet() do
          solve!(xr, f64l, g64, CDSolver(order = :cyclic, tol = 1e-15, maxpasses = 200_000))
        end
      catch
      end
      mr = group_measures(X, y, s, λ, groups, g.w, xr)
      if iszero(λ)     # plain least squares: the exact minimum
        R0 = LassoRef(X, y, s, zero(T), zero(T))
        Fs = measures(R0, smooth_minimizer(R0)).F
        mr = (; F = Fs, D = Fs, G = mr.G, λmax = mr.λmax)
      end
      tight = mr.F > 0 && (mr.F - mr.D) / mr.F <= big(1e-12)
      S = max(big(λ), mr.λmax)
      F0 = group_measures(X, y, s, λ, groups, g.w, zeros(p)).F
      tols = T === Float64 ? (nothing, 1e-4, 1e-10) : (nothing, 1e-4, 1e-5)
      for (order, seeds) in ((:cyclic, (1,)), (:random, (1, 2))), tol in tols, relative in (true, false),
          sname in ("cold", "ref"), seed in seeds
        relative || tol === nothing || continue
        x = sname == "cold" ? BlockIterate(T, p, g) : BlockIterate(T.(collect(xr)), g.groups)
        status, res, msgs = "ok", nothing, String[]
        try
          res, msgs = capture() do
            solve!(x, f, g, cd_solver(order, nothing, tol, relative, seed, 100_000))
          end
        catch e
          status = "error:" * first(sprint(showerror, e), 60)
        end
        row = Any["group-" * lname, T, name, loss, "group", fr, λ, 0, "block", order, "none",
                  tol === nothing ? "default" : tol, relative, sname, seed, status]
        if res === nothing
          append!(row, fill("NA", length(HEADER) - length(row)))
        else
          xv = collect(x)
          m = group_measures(X, y, s, λ, groups, g.w, xv)
          append!(row, Any[res.converged, res.passes, res.maxchange, res.tolerance, length(msgs),
                           rel(m.G, S), rel(m.G, big(λ)), rel(m.F - m.D, m.F), rel(m.F - mr.F, mr.F),
                           rel(m.F - mr.D, mr.D), tight, rel(abs(big(res.minimum) - m.F), m.F), f64(m.F), count(!iszero, xv), f64(mr.F), f64(F0)])
        end
        tsv(io, row...)
      end
    end
    flush(io)
  end
end

function main()
  out = ARGS[1]
  which = length(ARGS) > 1 ? ARGS[2] : "scalar"
  open(out, "w") do io
    println(io, join(HEADER, '\t'))
    which == "scalar" ? scalar_runs(io) : group_runs(io)
  end
end
main()
