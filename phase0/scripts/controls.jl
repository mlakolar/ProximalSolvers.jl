# Controls for the initial-curvature candidates: ordinary and adverse least-squares problems, PGD and APG,
# policies base (L0 = 1, master), b1 (min(1, α‖X‖_F²)), b2 (α‖X‖_F²). One TSV line per solve.
# Run: julia --project=. controls.jl [refprec] [policies] [filter]
using ProximalSolvers, ProximalBase, LinearAlgebra, Printf, Random, Statistics
const PS = ProximalSolvers
length(ARGS) >= 1 && (ENV["REFPREC"] = ARGS[1])
include(joinpath(@__DIR__, "ref.jl"))
Base.include(PS, joinpath(@__DIR__, "trace_defs.jl"))
const R = Ref321
policies = length(ARGS) >= 2 ? Symbol.(split(ARGS[2], ",")) : [:base, :b1, :b2]
filt = length(ARGS) >= 3 ? Regex(ARGS[3]) : r"."
println("# Julia ", VERSION, " | ", Sys.CPU_NAME, " | threads=", Threads.nthreads(), " | ref precision ", precision(BigFloat))
for l in readlines(`lscpu`); occursin(r"^Model name", l) && println("# ", l); end

include(joinpath(@__DIR__, "problems.jl"))

solvers = (("pgd", () -> ProximalGradientDescent()), ("apg", () -> AccProxGradDescent()))
println("case\tT\tsolver\tpolicy\tL0\tconverged\titers\toutcome\tf_calls\tgrad_calls\tbacktrack\tfwd_products\tadj_products\tL_final\tkkt_rel\tsubopt_frac\tF_rel_err")
refcache = Dict{String, Any}()
for pr in probs
  occursin(filt, pr.name) || continue
  X, y, α, λ = pr.X, pr.y, pr.α, pr.λ
  xs = get!(refcache, pr.name) do
    try R.xstar(X, y, α, λ; maxpass = 20000, tol = big"1e-45") catch e; nothing end
  end
  Fs = xs === nothing ? nothing : R.F(X, y, α, λ, xs)
  F0 = R.F(X, y, α, λ, pr.x0)
  for (sn, mk) in solvers, pol in policies
    f = (α == 1.0 && startswith(pr.name, "ord-raw")) ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)
    x = copy(pr.x0)
    g = NormL1(λ)
    local out
    try
      res, st, L_init = PS.solve_proto2!(x, f, g, mk(), ProximalOptions(); L0 = pol)
      outcome = res.converged ? "converged" : res.iteration_converged ? "maxiter" : res.f_increased ? "f_increased" : res.stagnated ? "stagnated" : "other"
      fwd = 1 + st.prox_calls + (st isa PS.ProximalGradientDescentState ? st.verifications : st.fallbacks)
      adj = st.grad_calls + (st.λmax >= 0 ? 1 : 0)
      kk = R.kkt(X, y, α, λ, x)
      Fk = R.F(X, y, α, λ, x)
      sub = Fs === nothing ? NaN : Float64((Fk - Fs) / max(F0 - Fs, big(nextfloat(0.0))))
      ferr = Float64(abs(big(res.minimum) - Fk) / max(abs(Fk), big(nextfloat(0.0))))
      @printf("%s\t%s\t%s\t%s\t%.3e\t%s\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%.3e\t%.3e\t%.3e\t%.3e\n", pr.name, pr.T, sn, pol, L_init, res.converged, res.iterations,
              outcome, st.f_calls, st.grad_calls, st.backtrack_steps, fwd, adj, st.L, kk, sub, ferr)
    catch e
      @printf("%s\t%s\t%s\t%s\t-\tfalse\t0\terror:%s\t-\t-\t-\t-\t-\t-\t-\t-\t-\n", pr.name, pr.T, sn, pol, first(split(sprint(showerror, e), '\n')))
    end
  end
end
