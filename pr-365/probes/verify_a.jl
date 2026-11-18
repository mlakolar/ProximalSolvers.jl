# A: the Stage 0 counterexamples (tiny column at zero residual, exact fit with nonzero start, y scale families), master vs candidate
include("trees.jl")
using Logging, Random, LinearAlgebra
using ProximalBase: LeastSquaresLoss, SqrtLeastSquaresLoss, NormL1, SparseIterate
run(f) = try r = with_logger(f, NullLogger()); string(r) catch e; "THROWS " * first(sprint(showerror, e), 130) end
println("# julia ", VERSION)
function exactfit(P, X, y, x0, λ)
  x = copy(x0)
  r = P.solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), P.CDSolver(order = :cyclic, momentum = false, maxpasses = 10))
  (x = x, converged = r.converged, gap = r.gap, passes = r.passes, minimum = r.minimum)
end
nbad = 0
function cmp(label, f)
  global nbad
  b = run(() -> f(TREES.base)); c = run(() -> f(TREES.cand))
  same = b == c
  same || (nbad += 1)
  println(same ? "SAME " : "DIFF ", label, "\n    base: ", b, same ? "" : "\n    cand: " * c)
end
cmp("finding 2a: X=fill(1e-150,2,1) y=0 λ=1e-151 zero start", P -> exactfit(P, fill(1e-150, 2, 1), zeros(2), zeros(1), 1e-151))
cmp("finding 2b: exact fit nonzero start", P -> exactfit(P, fill(1e-150, 2, 1), fill(1e-150, 2), ones(1), 1e-151))
# Stage 0 families: n = 30, p = 8, exact power-of-two rescalings
for (nm, sx, sy) in (("X tiny 2^-539", -539, 0), ("X tiny 2^-500", -500, 0), ("X tiny 2^-485", -485, 0), ("X 2^-539, y=0", -539, nothing),
                     ("y tiny 2^-1024", 0, -1024), ("y tiny 2^-700", 0, -700), ("y tiny 2^-485", 0, -485), ("y huge 2^510", 0, 510), ("y huge 2^800", 0, 800), ("y huge 2^1021", 0, 1021),
                     ("X 2^-300 y 2^-300", -300, -300), ("X 2^400, y 2^-500", 400, -500), ("X 2^-540, y 2^500", -540, 500))
  for T in (Float64,)
    rng = Xoshiro(11); n, p = 30, 8
    X0 = randn(rng, n, p); β = zeros(p); β[2] = 1.5; β[5] = -2; y0 = X0*β .+ 0.3 .* randn(rng, n)
    X = ldexp.(X0, sx); y = sy === nothing ? zeros(n) : ldexp.(y0, sy)
    for (kind, x0) in (("zero", zeros(p)), ("warm", fill(ldexp(0.1, sy === nothing ? 0 : sy - sx), p)))
      all(isfinite, X) && all(isfinite, y) && all(isfinite, x0) || continue
      for λf in (0.1, 0.5)
        λ = λf * (sy === nothing ? 1.0 : norm(X'*y, Inf)/norm(y))
        (isfinite(λ) && λ > 0) || (λ = ldexp(λf, sx))
        cmp("$nm $kind λ=$λf", P -> (x = copy(x0); r = P.solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), P.CDSolver(order = :cyclic, maxpasses = 50, rng = Xoshiro(2))); (x = x, converged = r.converged, gap = r.gap, passes = r.passes, minimum = r.minimum)))
      end
    end
  end
end
println("DIFFERENT outcomes: ", nbad)
