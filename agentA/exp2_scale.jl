include("lib.jl")
# E2: scale sweep. y -> 2^sy y, X -> 2^sx X (level lambda recomputed from the scaled data: 0.3 lambda_max).
# Per cell: branch counts of every visit (6 passes, n=30, p=8), worst step excess/bound against BigFloat,
# and the status of the public solve!.
function cell(T, sx, sy)
  rng = Xoshiro(11)
  n, p = 30, 8
  X0 = randn(rng, Float64, n, p); y0 = randn(rng, Float64, n)
  # scale in Float64 exactly (ldexp), then round to T (rounding to T may overflow/underflow)
  X = T.(ldexp.(X0, sx)); y = T.(ldexp.(y0, sy))
  (all(isfinite, X) && all(isfinite, y)) || return (status = "datainf",)
  (any(!iszero, X) && any(!iszero, y)) || return (status = "datazero",)
  λ64 = 0.3*lam_max(X, y)
  λ = try T(λ64) catch; return (status = "lamfail",) end
  (isfinite(λ) && λ > 0) || return (status = "lamrange",)
  # step-level
  REAL_OFF[] = 0; REAL_BAND[] = 0
  recs, m, x, err = Base.invokelatest(run_passes, X, y, λ, 6)
  cnt, worst, worstz = summarize(recs)
  w = isempty(worst) ? NaN : maximum(values(worst))
  # public solve (fresh)
  res = try
    xs = zeros(T, p)
    r = Base.invokelatest(() -> Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
      solve!(xs, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(order = :cyclic))
    end)
    "conv=$(r.converged) gap=$(isnan(r.gap) ? "NaN" : @sprintf("%.1e", r.gap)) passes=$(r.passes)"
  catch e
    "THROW:" * first(split(sprint(showerror, e), '\n'))[1:min(end, 90)]
  end
  (status = "ok", cnt = cnt, w = w, err = err, solve = res, off = REAL_OFF[], band = REAL_BAND[])
end
function main()
  println("# E2 scale sweep; rows: type sx sy | branches | worst step excess/bound | step err | public solve")
  grids = Dict(Float32 => (-150:15:75, -150:15:75), Float64 => (-1070:100:1020, -1070:100:1020))
  for T in (Float32, Float64)
    sxs, sys = grids[T]
    for sx in sxs, sy in sys
      c = cell(T, sx, sy)
      if c.status != "ok"
        @printf("%s sx=%d sy=%d | %s\n", T, sx, sy, c.status)
      else
        @printf("%s sx=%d sy=%d | %s | %.2e | %s | %s | off=%d band=%d\n", T, sx, sy, fmtcnt(c.cnt), c.w, c.err === nothing ? "-" : first(split(sprint(showerror, c.err), '\n'))[1:min(end,70)], c.solve, c.off, c.band)
      end
    end
  end
end
main()
