# #400 part 1: PGD and APG, least squares with weighted NormL1(λ0, w). One TSV row per solve.
# Adapted from the #352 sweep grad.jl: same fixtures, losses, starts and option sets (subset), weights added.
# usage: julia wl1.jl OUT.tsv Float64|Float32
include(joinpath(@__DIR__, "lib400.jl"))
const T = ARGS[2] == "Float32" ? Float32 : Float64
const FIX = haskey(ENV, "SMOKE") ? [fixture(ENV["SMOKE"])] : fixtures()
const HEADER = ["solver", "T", "fixture", "loss", "wset", "l1frac", "lambda0", "options", "start", "status",
                "converged", "exit", "iterations", "x_conv", "f_conv", "g_conv", "f_increased", "at_maxiter", "stagnated",
                "f_calls", "grad_calls", "prox_calls", "x_res", "f_res", "g_res",
                "kkt_rel", "bound", "gap_at_x", "subopt_lo", "subopt_hi", "ref_tight", "min_err", "F", "Fref",
                "first_good_iter", "nnz", "unique", "coef_err", "xref_inf"]

const TARGET = Dict(Float64 => 1e-8, Float32 => 1e-5)
const OPTIONS = [
  ("default", (;), 1e-5),
  ("ftol0", (; maxiter = 20_000, ftol = 0), 1e-5),
  ("gradtol1e-8", (; maxiter = 20_000, gradtol = 1e-8), 1e-8),
  ("strict", (; maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11), 1e-11),
]

exit_class(r) = r.converged ? "converged" : r.stagnated ? "stagnated" : r.iteration_converged ? "maxiter" :
                r.f_increased ? "increase" : "other"

# weight sets: "none" = unweighted NormL1 (control), "unit" = ones, "spread" = 2^[-2, 2] across the coordinates,
# "zeros" = spread with two zero weights (coordinate 1 and the first coordinate of the sparse truth, 1 + 7 % p)
function wsets(p)
  spread = [2.0^(-2 + 4 * (j - 1) / max(p - 1, 1)) for j in 1:p]
  z = copy(spread)
  z[1] = 0
  z[1 + 7 % p] = 0
  [("none", nothing), ("unit", ones(p)), ("spread", spread), ("zeros", z)]
end

function runs(io)
  for (name, X0, y0) in FIX, loss in (:raw, :mean)
    X, y = T.(X0), T.(y0)
    n, p = size(X)
    s = loss === :raw ? one(T) : one(T) / T(n)
    uniq = fullrank(X)
    for (wname, w0) in wsets(p)
      w = w0 === nothing ? ones(T, p) : T.(w0)
      g0 = Float64(s) .* abs.(Float64.(X)' * Float64.(y))
      pos = findall(!iszero, w)
      λ0max = isempty(pos) ? 0.0 : maximum(g0[j] / Float64(w[j]) for j in pos)
      fracs = iszero(λ0max) ? [0.0, 1.0] : [0.0, 1e-3, 0.1, 0.5, 1.01, 2.0]
      for fr in fracs
        λ0 = iszero(λ0max) ? T(fr) : T(fr * λ0max)
        R = WRef(X, y, s, λ0, w)
        ref = wreference(R, Float64.(X), Float64.(y), Float64(s), λ0, w)
        tight = ref.Fref > 0 && (ref.Fref - ref.Dref) / ref.Fref <= big(1e-12)
        S = max(maximum(R.c), R.λmax)
        f = loss === :raw ? LeastSquaresLoss(y, X) : s * LeastSquaresLoss(y, X)
        g = w0 === nothing ? NormL1(λ0) : NormL1(λ0, w)
        starts = (("cold", zeros(T, p)), ("ref", T.(ref.xref)), ("pert", T.(ref.xref .* 1.05 .+ 1e-3)))
        xref_inf = Float64(maximum(abs, ref.xref))
        for (sol, method) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent())),
            (oname, kw, gradtol) in OPTIONS, (sname, x0) in starts
          x = copy(x0)
          status, res = "ok", nothing
          try
            res = quiet() do
              solve!(x, f, g, method, ProximalOptions(; kw..., store_trace = true))
            end
          catch e
            status = "error:" * replace(first(sprint(showerror, e), 60), '\t' => ' ', '\n' => ' ')
          end
          row = Any[sol, T, name, loss, wname, fr, λ0, oname, sname, status]
          if res === nothing
            append!(row, fill("NA", length(HEADER) - length(row)))
          else
            m = wmeasures(R, x)
            goal = Float64(ref.Fref) * (1 + TARGET[T])
            fg = findfirst(st -> st.fg_x <= goal, res.trace)
            cerr = uniq && tight ? Float64(maximum(abs, bigv(x) .- ref.xref)) : NaN
            append!(row, Any[res.converged, exit_class(res), res.iterations, res.x_converged, res.f_converged,
                             res.grad_converged, res.f_increased, res.iteration_converged, res.stagnated,
                             res.f_calls, res.grad_calls, res.prox_calls, res.x_residual, res.f_residual, res.g_residual,
                             rel(m.G, S), max(gradtol, 64 * Float64(eps(T))), rel(m.F - m.D, m.F),
                             rel(m.F - ref.Fref, ref.Fref), rel(m.F - ref.Dref, ref.Dref), tight,
                             rel(abs(big(res.minimum) - m.F), m.F), f64(m.F), f64(ref.Fref),
                             fg === nothing ? -1 : fg, count(!iszero, x), uniq, cerr, xref_inf])
          end
          tsv(io, row...)
        end
      end
      flush(io)
    end
  end
end

open(ARGS[1], "w") do io
  for l in env_lines()
    println(io, "# ", l)
  end
  println(io, join(HEADER, '\t'))
  runs(io)
end
