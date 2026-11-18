# Outcomes of the prototypes on the hand-built cases and on ordinary solves, against master.
using Pkg
Pkg.instantiate()
const PROTO = abspath(ARGS[1])
include(joinpath(@__DIR__, "protolib2.jl"))
include(joinpath(@__DIR__, "lib352.jl"))          # fixtures and BigFloat measures (uses the registered package only for references)
setprecision(BigFloat, PREC)
println("Julia ", VERSION, " ", Sys.CPU_NAME)
function run1(tag, X::Matrix{T}, y, g, x0; kw...) where T
  R = LassoRef(X, y, one(T), g isa NormL1 ? T(g.λ0) : T(g.λ1), g isa NormL1 ? zero(T) : T(g.λ2))
  S = max(R.l1, R.λmax)
  println("--- ", tag, " ", T, " ", (; kw...))
  xm = nothing
  for (name, P) in MODS
    x = copy(x0)
    r = quiet(() -> P.solve!(x, LeastSquaresLoss(y, X), g, P.CDSolver(; rng = Xoshiro(1), kw...)))
    m = measures(R, x)
    name == "master" && (xm = copy(x))
    @printf("  %-8s converged=%-5s passes=%-6d KKT/max(λ1,λmax)=%-9.3g same point as master=%s\n", name, r.converged, r.passes, Float64(m.G / S), x == xm)
  end
end
for T in (Float64, Float32)
  M = T === Float32 ? T(2)^20 : T(2)^49
  X = ones(T, 1, 2); y = T[1 / 64]
  for (name, g) in (("reproducer λ=1/1024", NormL1(T(1 / 1024))), ("reproducer λ=0", NormL1(zero(T))), ("reproducer elastic net", ElasticNet(T(1 / 1024), T(1 / 16))))
    run1(name, X, y, g, T[M, -M]; order = :cyclic, momentum = false)
    run1(name, X, y, g, T[M, -M]; order = :random)
  end
  X3 = T[1 1 0; 0 0 1]; y3 = T[1 / 64, 1]
  for λ in (T(1 / 1024), zero(T))
    run1("mixed pass λ=$(λ)", X3, y3, NormL1(λ), T[M, -M, 1 - λ + 2eps(T)]; order = :cyclic, momentum = false)
  end
  for name in ("gauss", "corr95", "wide", "rankdef", "colscale")
    _, X0, y0 = fixture(name)
    Xg, yg = T.(X0), T.(y0)
    λg = T(0.1 * maximum(abs, Float64.(Xg)' * Float64.(yg)))
    p = size(Xg, 2)
    run1(name * " cold", Xg, yg, NormL1(λg), zeros(T, p); order = :cyclic, momentum = false)
    run1(name * " cold", Xg, yg, NormL1(λg), zeros(T, p); order = :random)
    j = T === Float32 ? 22 : 50
    x0 = zeros(T, p); x0[1] = T(2.0^j)
    run1(name * ", x0 = 2^$j e_1", Xg, yg, NormL1(λg), x0; order = :cyclic, momentum = false)
  end
end
