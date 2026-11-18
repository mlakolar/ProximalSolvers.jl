# CD, square-root lasso. One TSV row per solve; the reference of a problem is the best primal value and
# the best dual value over every point seen (all runs and the Float64 tight-threshold candidates), each
# evaluated in BigFloat.
# usage: julia sqrt.jl OUT.tsv [Float64|Float32]
include(joinpath(@__DIR__, "lib.jl"))
setprecision(BigFloat, PREC)
const TYPES = length(ARGS) > 1 ? (ARGS[2] == "Float32" ? (Float32,) : (Float64,)) : (Float64, Float32)
const FIX = haskey(ENV, "SMOKE") ? [fixture(ENV["SMOKE"])] : fixtures()
const HEADER = ["T", "fixture", "lfrac", "lambda", "container", "order", "momentum", "tol", "relative", "start", "seed",
                "status", "converged", "gap", "passes", "maxchange", "tolerance", "warning", "exactfit_at_x",
                "gap_exact_at_x", "subopt_lo", "subopt_hi", "ref_gap", "min_err", "P", "nnz"]

function warning_kind(msgs)
  isempty(msgs) && return "none"
  any(occursin("without a duality certificate", m) for m in msgs) && return "uncertified"
  any(occursin("did not converge in maxpasses", m) for m in msgs) && return "maxpasses"
  "other"
end

function runs(io)
  for T in TYPES, (name, X0, y0) in FIX
    X, y = T.(X0), T.(y0)
    n, p = size(X)
    X64, y64 = Float64.(X), Float64.(y)
    ny = norm(y64)
    λmax = iszero(ny) ? 0.0 : maximum(abs, X64' * y64) / ny
    fracs = iszero(λmax) ? [1.0] : [1e-3, 0.05, 0.3, 0.7, 1.01, 2.0]
    for fr in fracs
      λ = iszero(λmax) ? T(fr) : T(fr * λmax)
      f = SqrtLeastSquaresLoss(y, X)
      g = NormL1(λ)
      # candidates for the reference: Float64 solves at tight thresholds
      cands = Vector{Vector{Float64}}()
      for (tol, rel_) in ((1e-13, true), (1e-15, false))
        xc = zeros(p)
        try
          quiet() do
            solve!(xc, SqrtLeastSquaresLoss(y64, X64), NormL1(Float64(λ)),
                   CDSolver(order = :cyclic, momentum = false, tol = tol, relative = rel_, maxpasses = 200_000))
          end
          push!(cands, xc)
        catch
        end
      end
      Pbest, Dbest = sqrt_measures(X, y, λ, zeros(p)).P, zero(BigFloat)
      xbest = zeros(p)
      for c in cands
        m = sqrt_measures(X, y, λ, c)
        m.P < Pbest && ((Pbest, xbest) = (m.P, c))
        Dbest = max(Dbest, m.D)
      end
      Dbest = max(Dbest, sqrt_measures(X, y, λ, zeros(p)).D)
      starts = (("cold", zeros(T, p)), ("ref", T.(xbest)), ("pert", T.(xbest .* 1.05 .+ 1e-3)))
      tols = T === Float64 ? (nothing, 1e-4, 1e-10) : (nothing, 1e-4, 1e-5)
      rows = Vector{Any}[]
      ms = Any[]
      for container in (:dense, :sparse), (order, momentum, seeds) in ((:cyclic, false, (1,)), (:random, nothing, (1, 2)), (:random, false, (1, 2))),
          tol in tols, relative in (true, false), (sname, x0) in starts, seed in seeds
        relative || tol === nothing || continue
        x = container === :dense ? copy(x0) : SparseIterate(copy(x0))
        status, res, msgs = "ok", nothing, String[]
        try
          kw = (; order, momentum, relative, maxpasses = 100_000, rng = Xoshiro(seed))
          res, msgs = capture() do
            solve!(x, f, g, tol === nothing ? CDSolver(; kw...) : CDSolver(; tol, kw...))
          end
        catch e
          status = "error:" * first(sprint(showerror, e), 60)
        end
        row = Any[T, name, fr, λ, container, order, momentum === nothing ? "default" : momentum,
                  tol === nothing ? "default" : tol, relative, sname, seed, status]
        if res === nothing
          push!(ms, nothing)
        else
          xv = collect(x)
          m = sqrt_measures(X, y, λ, xv)
          m.P < Pbest && (Pbest = m.P)
          Dbest = max(Dbest, m.D)
          push!(ms, (; m, res, kind = warning_kind(msgs), nnz = count(!iszero, xv)))
        end
        push!(rows, row)
      end
      refgap = rel(Pbest - Dbest, Dbest)
      for (row, e) in zip(rows, ms)
        if e === nothing
          append!(row, fill("NA", length(HEADER) - length(row)))
        else
          m, res = e.m, e.res
          append!(row, Any[res.converged, res.gap, res.passes, res.maxchange, res.tolerance, e.kind, m.exactfit,
                           rel(m.P - m.D, m.D), rel(m.P - Pbest, Pbest), rel(m.P - Dbest, Dbest), refgap,
                           rel(abs(big(res.minimum) - m.P), m.P), f64(m.P), e.nnz])
        end
        tsv(io, row...)
      end
      flush(io)
    end
  end
end

open(ARGS[1], "w") do io
  println(io, join(HEADER, '\t'))
  runs(io)
end
