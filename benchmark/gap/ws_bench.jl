# Working sets against the plain passes of coordinate descent, on the lasso
# designs A–E and a large design (n = 500, p = 100,000, 50 nonzero
# coefficients): one λ (0.1 and 0.02 λmax) from zero, and paths of 50 levels.
# Each run records its time (the fastest of three), passes, the KKT residual
# (kkt_residual, on the scale of the stopping rule) and the relative gap.
#
#     julia --project=benchmark/gap benchmark/gap/ws_bench.jl [--quick] [--out FILE]

include(joinpath(@__DIR__, "problems.jl"))

const QUICK = "--quick" in ARGS
const OUT = let i = findfirst(==("--out"), ARGS); i === nothing ? joinpath(@__DIR__, "ws_results.csv") : ARGS[i+1] end

relgap(f, g, x) = (d = duality_gap(f, g, x); max(d.gap, 0.0) / abs(d.primal))

const SOLVERS = [("plain", CDSolver()), ("workingset", CDSolver(; workingset = true))]

function cases(io, d, f, λmax, p; rounds = 3)
  for frac in (0.1, 0.02), (label, s) in SOLVERS
    g = NormL1(frac * λmax)
    t, r = fastest(() -> solve!(SparseIterate(p), f, g, s); rounds)
    x = r.minimizer
    kkt, gap = kkt_residual(f, g, x), relgap(f, g, x)
    @printf "%-5s %-5.2f %-11s %9.4f s  %6d passes  kkt %.1e  gap %.1e\n" d.name frac label t r.passes kkt gap
    println(io, join((d.name, "single", frac, label, t, r.passes, kkt, gap), ","))
  end
  λs = λmax .* 10 .^ range(0, -2; length = 50)
  for (label, s) in SOLVERS
    t, r = fastest(() -> solve_path(f, NormL1(1.0), λs, s); rounds)
    worst = maximum(relgap(f, NormL1(λ), SparseIterate(Vector(x))) for (λ, x) in zip(r.λ, r.solutions))
    @printf "%-5s path  %-11s %9.4f s  %6d passes  max gap %.1e\n" d.name label t sum(r.passes) worst
    println(io, join((d.name, "path", "", label, t, sum(r.passes), "", worst), ","))
  end
end

function main()
  f, λmax, p = design((name = "warmup", n = 50, p = 100, s = 5, ρ = 0.0, common = 0.0))
  redirect_stdout(devnull) do
    cases(IOBuffer(), (name = "w",), f, λmax, p; rounds = 1)
  end
  designs = QUICK ? [(name = "A", n = 200, p = 1000, s = 20, ρ = 0.0, common = 0.0)] :
            [DESIGNS; (name = "L", n = 500, p = 100_000, s = 50, ρ = 0.0, common = 0.0)]
  open(OUT, "w") do io
    println(io, "design,kind,lambda,solver,seconds,passes,kkt,relgap")
    for d in designs
      f, λmax, p = design(d)
      cases(io, d, f, λmax, p; rounds = d.p >= 100_000 ? 2 : 3)
      flush(io)
    end
  end
  println("wrote ", OUT)
end

main()
