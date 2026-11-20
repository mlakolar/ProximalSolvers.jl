# #400 part 2: PGD and APG, least squares with NormLinf(λ).
#   mode "sweep": one TSV row per solve with the #352 option sets (subset); the solver's converged flag against
#                 independent BigFloat measures at the returned point.
#   mode "traj":  one long solve per case with no proposal able to stop it (ftol = 0, gradtol = 0, xtol = 1e-300,
#                 increases allowed, maxiter 20000), the iterates recorded; at every iterate the candidate stopping
#                 criteria are evaluated in the working type T, as an implementation would:
#                   gen  : the existing generic check of STOP-07, r = ‖x − prox_{t g}(x − t∇f(x))‖∞ / t over
#                          S = max(‖∇f(0)‖∞, ‖∇f(x)‖∞), t = 1/L of that iteration
#                   kkt  : ProximalBase's full-point kkt_violation(NormLinf(λ), ∇f(x), x) over the same S
#                   kktl : the same score over S1 = max(λ, ‖∇f(0)‖₁)  (the ℓ∞-penalty analogue of max(λ, λmax))
#                   gap  : the relative duality gap (F − D)/F with θ = κ r, κ = min(1, λ/‖sXᵀr‖₁)
#                   dx   : ‖x − x_prev‖₂ / max(‖x‖₂, 1)      (the xtol test quantity)
#                   df   : |F − F_prev| / |F|                 (the ftol test quantity)
#                 For each criterion and each level τ in TAUS the first iteration with value < τ is recorded, and the
#                 independent BigFloat measures at that iterate. The iteration at which the coefficient error first
#                 reaches 1e-4 (unique references only, Float64 evaluation) is recorded as the oracle time.
# usage: julia linf.jl sweep|traj OUT.tsv Float64|Float32
include(joinpath(@__DIR__, "lib400.jl"))
const MODE = ARGS[1]
const T = ARGS[3] == "Float32" ? Float32 : Float64
const FIX = haskey(ENV, "SMOKE") ? [fixture(ENV["SMOKE"])] : fixtures()
const TARGET = Dict(Float64 => 1e-8, Float32 => 1e-5)
const OPTIONS = [
  ("default", (;), 1e-5),
  ("ftol0", (; maxiter = 20_000, ftol = 0), 1e-5),
  ("gradtol1e-8", (; maxiter = 20_000, gradtol = 1e-8), 1e-8),
  ("strict", (; maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11), 1e-11),
]
const TAUS = [1e-3, 1e-4, 1e-5, 1e-6, 1e-7, 1e-8, 1e-10, 1e-12]
const CRITS = ("gen", "kkt", "kktl", "gap", "dx", "df")
const FRACS = [0.0, 1e-3, 0.1, 0.5, 1.01]

exit_class(r) = r.converged ? "converged" : r.stagnated ? "stagnated" : r.iteration_converged ? "maxiter" :
                r.f_increased ? "increase" : "other"

struct Case
  name::String; loss::Symbol; fr::Float64; λ::T; X::Matrix{T}; y::Vector{T}; s::T
  R::LRef; ref::NamedTuple; tight::Bool; uniq::Bool; f::Any; S0::Float64
end

function cases(fn)
  for (name, X0, y0) in FIX, loss in (:raw, :mean)
    X, y = T.(X0), T.(y0)
    n, p = size(X)
    s = loss === :raw ? one(T) : one(T) / T(n)
    g01 = Float64(s) * sum(abs, Float64.(X)' * Float64.(y))
    fracs = iszero(g01) ? [0.0, 1.0] : FRACS
    uniq = fullrank(X)
    for fr in fracs
      λ = iszero(g01) ? T(fr) : T(fr * g01)
      R = LRef(X, y, s, λ)
      ref = lreference(R, Float64.(X), Float64.(y), Float64(s), λ)
      tight = ref.Fref > 0 ? (ref.Fref - ref.Dref) / ref.Fref <= big(1e-20) : ref.Fref == ref.Dref
      f = loss === :raw ? LeastSquaresLoss(y, X) : s * LeastSquaresLoss(y, X)
      fn(Case(name, loss, fr, λ, X, y, s, R, ref, tight, uniq, f, Float64(R.g0inf)))
    end
  end
end
starts(c) = (("cold", zeros(T, size(c.X, 2))), ("ref", T.(c.ref.xref)), ("pert", T.(c.ref.xref .* 1.05 .+ 1e-3)))
coef_err(c, x) = c.uniq && c.tight ? Float64(maximum(abs, bigv(x) .- c.ref.xref)) : NaN
# measures of a point, normalized: true KKT over the true S, gap, suboptimality bounds, coefficient error
function truth(c, x)
  m = lmeasures(c.R, x)
  S = max(c.R.g0inf, m.ginf)
  (; kkt2 = rel(m.K2, S), kktinf = rel(m.Kinf, S), gap = rel(m.F - m.D, m.F),
     sub_lo = rel(m.F - c.ref.Fref, c.ref.Fref), sub_hi = rel(m.F - c.ref.Dref, c.ref.Dref), cerr = coef_err(c, x))
end

function sweep(io)
  println(io, join(["solver", "T", "fixture", "loss", "l1frac", "lambda", "options", "start", "status", "converged", "exit",
                    "iterations", "x_conv", "f_conv", "g_conv", "stagnated", "grad_calls", "prox_calls", "bound",
                    "kkt2_rel", "kktinf_rel", "gap_at_x", "subopt_lo", "subopt_hi", "ref_tight", "unique", "coef_err",
                    "xref_inf", "first_good_iter"], '\t'))
  cases() do c
    for (sol, method) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent())),
        (oname, kw, gradtol) in OPTIONS, (sname, x0) in starts(c)
      x = copy(x0)
      status, res = "ok", nothing
      try
        res = quiet() do
          solve!(x, c.f, NormLinf(c.λ), method, ProximalOptions(; kw..., store_trace = true))
        end
      catch e
        status = "error:" * replace(first(sprint(showerror, e), 60), '\t' => ' ', '\n' => ' ')
      end
      row = Any[sol, T, c.name, c.loss, c.fr, c.λ, oname, sname, status]
      if res === nothing
        append!(row, fill("NA", 20))
      else
        tr = truth(c, x)
        goal = Float64(c.ref.Fref) * (1 + TARGET[T])
        fg = findfirst(st -> st.fg_x <= goal, res.trace)
        append!(row, Any[res.converged, exit_class(res), res.iterations, res.x_converged, res.f_converged,
                         res.grad_converged, res.stagnated, res.grad_calls, res.prox_calls,
                         max(gradtol, 64 * Float64(eps(T))), tr.kkt2, tr.kktinf, tr.gap, tr.sub_lo, tr.sub_hi,
                         c.tight, c.uniq, tr.cerr, Float64(maximum(abs, c.ref.xref)), fg === nothing ? -1 : fg])
      end
      tsv(io, row...)
    end
    flush(io)
  end
end

# the criteria at one iterate, in T (the gradient by the package's loss, the prox and the score by ProximalBase)
function criteria(c, g, x, xprev, Fx, Fprev, L, grad, buf, xs)
  # ∇f(x)
  gradient!(grad, c.f, x)
  ginf = Float64(maximum(abs, grad))
  S = max(c.S0, ginf)
  # generic: p = prox_{t g}(x − t ∇f(x))
  t = one(T) / T(L)
  @. xs = x - t * grad
  prox!(buf, g, xs, t)
  gen = Float64(maximum(abs, x .- buf) / t)
  kk = Float64(kkt_violation(g, grad, x))
  S1 = max(Float64(c.λ), Float64(c.R.g0one))
  # gap in T: r = y − X x, θ = κ r
  r = c.y .- c.X * x
  z = c.s .* (c.X' * r)
  z1 = sum(abs, z)
  κ = iszero(z1) ? one(T) : min(one(T), c.λ / z1)
  D = κ * c.s * dot(r, c.y) - κ^2 * c.s * sum(abs2, r) / 2
  gp = Float64((Fx - D) / Fx)
  dx = Float64(norm(x .- xprev) / max(norm(x), one(T)))
  df = Fx == Fprev ? 0.0 : Float64(abs(Fx - Fprev) / abs(Fx))
  (gen = gen / S, kkt = kk / S, kktl = kk / S1, gap = gp, dx = dx, df = df)
end

function traj(io)
  hdr = ["solver", "T", "fixture", "loss", "l1frac", "lambda", "start", "iterations", "exit", "ref_tight", "unique",
         "oracle_iter", "final_kkt2", "final_gap", "final_cerr", "crit", "tau", "fire_iter", "kkt2_rel", "kktinf_rel",
         "gap_at_x", "subopt_lo", "coef_err"]
  println(io, join(hdr, '\t'))
  opts = ProximalOptions(maxiter = 20_000, ftol = 0, xtol = 1e-300, gradtol = 0, allow_f_increases = true,
                         store_trace = true, extended_trace = true)
  cases() do c
    p = size(c.X, 2)
    g = NormLinf(c.λ)
    grad, buf, xs = zeros(T, p), zeros(T, p), zeros(T, p)
    for (sol, method) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent())),
        (sname, x0) in starts(c)
      sname == "ref" && continue
      x = copy(x0)
      res = try
        quiet() do
          solve!(x, c.f, g, method, opts)
        end
      catch e
        tsv(io, sol, T, c.name, c.loss, c.fr, c.λ, sname, "NA", "error", fill("NA", length(hdr) - 9)...)
        continue
      end
      xr = Float64.(c.ref.xref)
      first_fire = Dict((k, τ) => 0 for k in CRITS, τ in TAUS)
      oracle = -1
      xprev = copy(x0)
      Fprev = T(Float64(lmeasures(c.R, x0).F))   # the objective at the start, rounded to T
      for st in res.trace
        xk = st.metadata["x"]
        Fx = T(st.fg_x)
        cr = criteria(c, g, xk, xprev, Fx, Fprev, st.L, grad, buf, xs)
        for k in CRITS, τ in TAUS
          first_fire[(k, τ)] == 0 && getfield(cr, Symbol(k)) < τ && (first_fire[(k, τ)] = st.iteration)
        end
        if oracle < 0 && c.uniq && c.tight && maximum(abs, Float64.(xk) .- xr) <= 1e-4
          oracle = st.iteration
        end
        xprev, Fprev = xk, Fx
      end
      fin = truth(c, x)
      byiter = Dict(st.iteration => st.metadata["x"] for st in res.trace)
      cache = Dict{Int, Any}()
      for k in CRITS, τ in TAUS
        it = first_fire[(k, τ)]
        if it == 0
          tsv(io, sol, T, c.name, c.loss, c.fr, c.λ, sname, res.iterations, exit_class(res), c.tight, c.uniq, oracle,
              fin.kkt2, fin.gap, fin.cerr, k, τ, -1, "NA", "NA", "NA", "NA", "NA")
        else
          tr = get!(() -> truth(c, byiter[it]), cache, it)
          tsv(io, sol, T, c.name, c.loss, c.fr, c.λ, sname, res.iterations, exit_class(res), c.tight, c.uniq, oracle,
              fin.kkt2, fin.gap, fin.cerr, k, τ, it, tr.kkt2, tr.kktinf, tr.gap, tr.sub_lo, tr.cerr)
        end
      end
    end
    flush(io)
  end
end

open(ARGS[2], "w") do io
  for l in env_lines()
    println(io, "# ", l)
  end
  MODE == "sweep" ? sweep(io) : traj(io)
end
