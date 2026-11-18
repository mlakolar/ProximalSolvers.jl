# PGD and APG, least squares with NormL1 or ElasticNet. One TSV row per solve.
# usage: julia grad.jl OUT.tsv [Float64|Float32]
include(joinpath(@__DIR__, "lib.jl"))
setprecision(BigFloat, PREC)
const TYPES = length(ARGS) > 1 ? (ARGS[2] == "Float32" ? (Float32,) : (Float64,)) : (Float64, Float32)
const FIX = haskey(ENV, "SMOKE") ? [fixture(ENV["SMOKE"])] : fixtures()
const HEADER = ["solver", "T", "fixture", "loss", "penalty", "l1frac", "l1", "l2", "options", "start", "status",
                "converged", "exit", "iterations", "x_conv", "f_conv", "g_conv", "f_increased", "at_maxiter", "stagnated",
                "f_calls", "grad_calls", "prox_calls", "backtracks", "x_res", "f_res", "g_res",
                "kkt_rel", "bound", "gap_at_x", "subopt_lo", "subopt_hi", "ref_tight", "min_err", "F", "Fref", "F0",
                "first_good_iter", "nnz"]

const TARGET = Dict(Float64 => 1e-8, Float32 => 1e-5)
# name => (keywords, gradtol): the options of a solve, with the trace stored (it records the computed
# objective of every iteration and does not change the arithmetic of the solve)
const OPTIONS = [
  ("default", (;), 1e-5),
  ("default-20k", (; maxiter = 20_000), 1e-5),
  ("allow-inc", (; maxiter = 20_000, allow_f_increases = true), 1e-5),
  ("ftol0", (; maxiter = 20_000, ftol = 0), 1e-5),
  ("gradtol1e-8", (; maxiter = 20_000, gradtol = 1e-8), 1e-8),
  ("strict", (; maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11), 1e-11),
]

function exit_class(r, maxiter)
  r.converged && return "converged"
  r.stagnated && return "stagnated"
  r.iteration_converged && return "maxiter"
  r.f_increased && return "increase"
  "other"
end

function runs(io)
  for T in TYPES, (name, X0, y0) in FIX, loss in (:raw, :mean)
    X, y = T.(X0), T.(y0)
    n, p = size(X)
    s = loss === :raw ? one(T) : one(T) / T(n)
    λmax = Float64(s) * maximum(abs, Float64.(X)' * Float64.(y))
    fracs = iszero(λmax) ? [0.0, 1.0] : [0.0, 1e-3, 0.1, 0.5, 1.01, 2.0]
    pens = Tuple{String, Float64, T, T}[]
    for fr in fracs
      push!(pens, ("l1", fr, iszero(λmax) ? T(fr) : T(fr * λmax), zero(T)))
    end
    l2 = iszero(λmax) ? one(T) : T(0.5 * λmax)
    for fr in (0.0, 0.1, 1.01)
      push!(pens, ("enet", fr, iszero(λmax) ? T(fr) : T(fr * λmax), l2))
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
      for (sol, method) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent())),
          (oname, kw, gradtol) in OPTIONS, (sname, x0) in starts
        x = copy(x0)
        status, res = "ok", nothing
        try
          res = quiet() do
            solve!(x, f, g, method, ProximalOptions(; kw..., store_trace = true))
          end
        catch e
          status = "error:" * first(sprint(showerror, e), 60)
        end
        row = Any[sol, T, name, loss, pen, fr, l1, l2, oname, sname, status]
        if res === nothing
          append!(row, fill("NA", length(HEADER) - length(row)))
        else
          m = measures(R, x)
          # the first iteration whose computed objective is within the target of the reference minimum
          goal = Float64(ref.Fref) * (1 + TARGET[T])
          fg = findfirst(st -> st.fg_x <= goal, res.trace)
          maxiter = get(kw, :maxiter, 200)
          append!(row, Any[res.converged, exit_class(res, maxiter), res.iterations, res.x_converged, res.f_converged,
                           res.grad_converged, res.f_increased, res.iteration_converged, res.stagnated,
                           res.f_calls, res.grad_calls, res.prox_calls, res.backtrack_steps,
                           res.x_residual, res.f_residual, res.g_residual,
                           rel(m.G, S), max(gradtol, 64 * Float64(eps(T))), rel(m.F - m.D, m.F),
                           rel(m.F - ref.Fref, ref.Fref), rel(m.F - ref.Dref, ref.Dref), tight,
                           rel(abs(big(res.minimum) - m.F), m.F), f64(m.F), f64(ref.Fref), f64(F0),
                           fg === nothing ? -1 : fg, count(!iszero, x)])
        end
        tsv(io, row...)
      end
    end
    flush(io)
  end
end

open(ARGS[1], "w") do io
  println(io, join(HEADER, '\t'))
  runs(io)
end
