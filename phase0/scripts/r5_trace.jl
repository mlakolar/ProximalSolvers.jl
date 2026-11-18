# Iteration-level trace of PGD/APG on the extreme-scale least-squares cases of #321 and #327.
# Run: julia --project=. .codex-orchestrator/probes/r5_trace.jl [maxiter]
using ProximalSolvers, ProximalBase, LinearAlgebra, Printf, InteractiveUtils
const PS = ProximalSolvers
length(ARGS) >= 2 && (ENV["REFPREC"] = ARGS[2])
include(joinpath(@__DIR__, "ref.jl"))
Base.include(PS, joinpath(@__DIR__, "trace_defs.jl"))
const R = Ref321

function provenance()
  println("# Julia ", VERSION, " | ", Sys.CPU_NAME, " | threads=", Threads.nthreads(), " blas=", BLAS.get_num_threads(), " | ", BLAS.get_config())
  println("# PS: ", pkgdir(PS), "  PB: ", pkgdir(ProximalBase), " pkgversion PB=", pkgversion(ProximalBase))
  for l in readlines(`lscpu`); occursin(r"^Model name", l) && println("# ", l); end
end

fmt(x) = @sprintf("%.4e", Float64(x))
fmtb(x) = @sprintf("%.3e", Float64(x))

function show_trace(name, X, y, α, λ, x0, kind, L0; maxiter = 200, head = 14, every = 20)
  T = eltype(x0)
  f = α * LeastSquaresLoss(y, X); g = NormL1(λ)
  xs = R.xstar(X, y, α, λ)
  Fs = R.F(X, y, α, λ, xs)
  x = copy(x0)
  F0 = R.F(X, y, α, λ, x0)
  res, recs = PS.traced_solve!(kind, x, f, g, ProximalOptions(maxiter = maxiter); L0 = L0)
  println("\n=== ", name, " | ", kind, " | L0 policy ", L0, " | T=", T, " | α=", α, " λ=", λ)
  @printf("start: F(x0)=%s (ref), L_init=%s;  x*=%s  F*=%s\n", fmtb(F0), fmt(res.L_init), fmtb(xs[1]), fmtb(Fs))
  println("iter  L_start     L_end       #trials accepted-L    x[1]         |dx|         grad_prev    ΔG_comp      ΔG_exact     (F-F*)/F0   KKTrel   flags(x,f,g) stop")
  nrec = length(recs)
  for (k, r) in enumerate(recs)
    (k <= head || k % every == 0 || k == nrec) || continue
    isempty(r.error) || (println(@sprintf("%4d  ERROR %s", r.iter, r.error)); continue)
    Fk = R.F(X, y, α, λ, r.x)
    kk = R.kkt(X, y, α, λ, r.x)
    dxn = norm(big.(r.x) .- big.(r.xprev))
    Gp = r.grad_prev[1]
    ΔGc = k < nrec && isempty(recs[k+1].error) ? recs[k+1].grad_prev[1] - r.grad_prev[1] : NaN
    ΔGe = (R.G(X, y, α, r.x) .- R.G(X, y, α, r.xprev))[1]
    nt = length(r.trials)
    Lacc = r.trials[end].L
    @printf("%4d  %s  %s  %d       %s   %s  %s  %s  %s  %s  %s  %s  (%d%d%d)\n", r.iter, fmt(r.L_start), fmt(r.L_end), nt, fmt(Lacc), fmt(r.x[1]),
            fmtb(dxn), fmtb(Gp), fmtb(ΔGc), fmtb(ΔGe), fmtb((Fk - Fs) / F0), fmtb(kk), r.flags.x, r.flags.f, r.flags.g)
  end
  for k in 1:min(2, nrec)
    r = recs[k]; isempty(r.error) || continue
    for (j, t) in enumerate(r.trials)
      println("  trial detail it=", r.iter, " #", j, ": ", join(["$(kk)=$(vv isa AbstractFloat ? fmt(vv) : vv)" for (kk, vv) in pairs(t)], ", "),
              "; f_trial==f_prev: ", t.f == r.fprev)
    end
  end
  println("result: converged=", res.converged, " iterations=", res.iterations, " stop=", res.stop, " L_final=", fmt(res.L),
          " x=", fmt(x[1]), " rel.dist=", fmtb(abs(big(x[1]) - xs[1]) / abs(xs[1])),
          " KKTrel=", fmtb(R.kkt(X, y, α, λ, x)), " f_calls=", res.f_calls, " grad_calls=", res.grad_calls,
          " backtrack_steps=", res.backtrack_steps)
  (res, recs)
end

function main()
  provenance()
  maxiter = isempty(ARGS) ? 200 : parse(Int, ARGS[1])
  policies = length(ARGS) >= 3 ? Symbol.(split(ARGS[3], ",")) : [:base]
  length(ARGS) >= 4 && ARGS[4] == "skipbase" || nothing
  # actual solve! on the unmodified code, for the baseline numbers of #327
  println("\n## unmodified solve! (default ProximalOptions)")
  for (name, X, y, α, λ) in (("R5", ones(5, 1), fill(1e160, 5), 1e-100, 0.0),
                              ("#327", [1.0;;], [1e160], 5e-100, 0.0))
    for (sn, m) in (("PGD", ProximalGradientDescent()), ("APG", AccProxGradDescent()), ("CD", CDSolver()))
      x = [0.0]
      f = α * LeastSquaresLoss(y, X)
      r = try solve!(x, f, NormL1(λ), m) catch e; e end
      if r isa Exception
        println(name, " ", sn, " threw ", sprint(showerror, r))
      else
        println(name, " ", sn, ": converged=", r.converged, " minimum=", r.minimum, " x=", x[1], hasproperty(r, :iterations) ? " iterations=$(r.iterations)" : "")
      end
    end
  end
  println("\n## reference precision: ", precision(BigFloat), " bits")
  println("\n## traced runs")
  cases = (("R5 (X=ones(5,1), y=fill(1e160,5), α=1e-100, λ=0)", ones(5, 1), fill(1e160, 5), 1e-100, 0.0),
           ("#327 (X=[1], y=[1e160], α=5e-100, λ=0)", [1.0;;], [1e160], 5e-100, 0.0))
  for (name, X, y, α, λ) in cases, kind in (:pgd, :apg), pol in policies
    show_trace(name, X, y, α, λ, zeros(1), kind, pol; maxiter = maxiter)
  end
  # penalty positive: λ = 0.1 λmax of R5
  let X = ones(5, 1), y = fill(1e160, 5), α = 1e-100
    λ = 0.1 * Float64(R.λmax(X, y, α))
    for kind in (:pgd, :apg), pol in policies
      show_trace("R5 with λ = 0.1 λmax", X, y, α, λ, zeros(1), kind, pol; maxiter = maxiter)
    end
  end
  # Float32 wide-ratio analogue
  let X = ones(Float32, 5, 1), y = fill(1f20, 5), α = 1e-30
    for kind in (:pgd, :apg), pol in policies
      show_trace("Float32 wide analogue (X=ones(5,1), y=fill(1f20,5), α=1e-30, λ=0)", X, y, α, 0f0, zeros(Float32, 1), kind, pol; maxiter = maxiter)
    end
  end
  # Float32 analogue: squares overflow in Float32, value representable
  let X = ones(Float32, 5, 1), y = fill(1f20, 5), α = 1e-10
    for kind in (:pgd, :apg), pol in policies
      show_trace("Float32 analogue (X=ones(5,1), y=fill(1f20,5), α=1e-10, λ=0)", X, y, α, 0f0, zeros(Float32, 1), kind, pol; maxiter = maxiter)
    end
  end
end
main()
