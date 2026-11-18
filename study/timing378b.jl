# Paired in-process timing of the #378 prototypes on the ordinary path. Master, a second copy of master
# (the control) and the prototypes are compiled from source in this process (protolib2.jl). One figure
# per side and round: the minimum over the batches of that round; per case, the median and the largest
# ratio to master over the rounds, the same for the control, the warmed allocations of one solve, and
# whether the outcome (passes, flag) equals master's.
# usage: julia timing378b.jl PROTO [quick]
using Pkg
Pkg.instantiate()
const PROTO = abspath(ARGS[1])
const QUICK = length(ARGS) > 1
include(joinpath(@__DIR__, "protolib2.jl"))
using SparseArrays
BLAS.set_num_threads(1)

# deterministic designs (the generators of lib352.jl, repeated here so that only the modules above are loaded)
mutable struct SM64
  s::UInt64
end
function next!(g::SM64)
  g.s += 0x9e3779b97f4a7c15
  z = g.s
  z = (z ⊻ (z >> 30)) * 0xbf58476d1ce4e5b9
  z = (z ⊻ (z >> 27)) * 0x94d049bb133111eb
  z ⊻ (z >> 31)
end
unif(g::SM64) = (next!(g) >> 11) * 2.0^-53
gaussish(g::SM64) = (s = -6.0; for _ in 1:12; s += unif(g); end; s)
function design(seed, n, p, rho, k)
  g = SM64(seed)
  Z = [gaussish(g) for _ in 1:n, _ in 1:p]
  z0 = [gaussish(g) for _ in 1:n]
  X = sqrt(1 - rho) .* Z .+ sqrt(rho) .* z0
  b = zeros(p)
  for j in 1:k
    b[1 + (7j) % p] = (isodd(j) ? 1.0 : -1.0) * (1 + unif(g))
  end
  X, X * b + 0.5 .* [gaussish(g) for _ in 1:n]
end

function batch(solve::F, method, x, x0, f, g, rng, rng0, reps) where F
  s = 0
  t = time_ns()
  for _ in 1:reps
    copyto!(x, x0)
    copy!(rng, rng0)
    r = solve(x, f, g, method)
    s += r.passes
  end
  (time_ns() - t) / reps, s
end
function side(solve::F, method, x, x0, f, g, rng, rng0, reps, nb) where F
  best = Inf
  for _ in 1:nb
    t, _ = batch(solve, method, x, x0, f, g, rng, rng0, reps)
    best = min(best, t)
  end
  best
end
med(v) = sort(v)[(length(v) + 1) ÷ 2]
mk(x0, container, groups) = container === :dense ? copy(x0) : container === :sparse ? SparseIterate(copy(x0)) : BlockIterate(copy(x0), groups)

function case(name, X::Matrix{T}, y::Vector{T}, pen, frac, container, order, start; tol = 1e-7) where T
  n, p = size(X)
  f = LeastSquaresLoss(y, X)
  groups = [collect(i:min(i + 2, p)) for i in 1:3:p]
  c = Float64.(X)' * Float64.(y)
  g = if pen === :l1
    NormL1(T(frac * maximum(abs, c)))
  elseif pen === :enet
    ElasticNet(T(frac * maximum(abs, c)), T(0.5 * maximum(abs, c)))
  else
    g0 = GroupNormL2(one(T), groups)
    GroupNormL2(T(frac * maximum(norm(c[idx]) / g0.w[k] for (k, idx) in enumerate(groups))), groups)
  end
  sides = Any[]
  x0 = zeros(T, p)
  if start === :warm          # the point master returns from a cold start
    P = MODS[1][2]
    xw = mk(x0, container, groups)
    quiet(() -> P.solve!(xw, f, g, P.CDSolver(; order, tol, rng = Xoshiro(1))))
    x0 = collect(xw)
  end
  for (mname, P) in MODS
    rng, rng0 = Xoshiro(1), Xoshiro(1)
    method = P.CDSolver(; order, tol, rng)
    x, xs0 = mk(x0, container, groups), mk(x0, container, groups)
    r = quiet(() -> (copyto!(x, xs0); copy!(rng, rng0); P.solve!(x, f, g, method)))
    quiet(() -> side(P.solve!, method, x, xs0, f, g, rng, rng0, 2, 2))
    al = quiet(() -> (copyto!(x, xs0); copy!(rng, rng0); @allocated P.solve!(x, f, g, method)))
    push!(sides, (; mname, solve = P.solve!, method, x, xs0, rng, rng0, passes = r.passes, converged = r.converged, al))
  end
  t0 = quiet(() -> side(sides[1].solve, sides[1].method, sides[1].x, sides[1].xs0, f, g, sides[1].rng, sides[1].rng0, 3, 3))
  reps = max(1, round(Int, 3e6 / t0))
  nb = QUICK ? 5 : 15
  rounds = QUICK ? 3 : 9
  ratios = [Float64[] for _ in sides]
  a0 = 0.0
  quiet() do
    for round in 1:rounds
      order_ = isodd(round) ? eachindex(sides) : reverse(eachindex(sides))
      t = zeros(length(sides))
      for i in order_
        s = sides[i]
        t[i] = side(s.solve, s.method, s.x, s.xs0, f, g, s.rng, s.rng0, reps, nb)
      end
      for i in eachindex(sides)
        push!(ratios[i], t[i] / t[1])
      end
      a0 = t[1]
    end
  end
  m = sides[1]
  print(join(Any[name, T, n, p, pen, frac, container, order, start, m.passes, m.converged, round(Int, a0), m.al], '\t'))
  for i in 2:length(sides)
    s = sides[i]
    print('\t', @sprintf("%.3f", med(ratios[i])), '\t', @sprintf("%.3f", maximum(ratios[i])), '\t', s.al, '\t',
          s.passes == m.passes && s.converged == m.converged ? "same" : "passes=$(s.passes),converged=$(s.converged)")
  end
  println()
  flush(stdout)
end

println("Julia ", VERSION, " ", Sys.CPU_NAME, ", load average ", Sys.loadavg(), ", floors: ", join((n * "=" * string(floor_of(P)) for (n, P) in MODS[3:end]), " "))
print(join(["design", "T", "n", "p", "pen", "frac", "container", "order", "start", "passes", "converged", "master ns", "master alloc"], '\t'))
for (mname, _) in MODS[2:end]
  print('\t', mname, " med\t", mname, " max\t", mname, " alloc\t", mname, " outcome")
end
println()
small = [("d40x12_r0", 0x1, 40, 12, 0.0, 4), ("d40x12_r95", 0x2, 40, 12, 0.95, 4), ("d20x60_r0", 0x3, 20, 60, 0.0, 5), ("d100x30_r50", 0x4, 100, 30, 0.5, 6)]
large = [("d200x1000_r50", 0x5, 200, 1000, 0.5, 10), ("d2000x200_r50", 0x6, 2000, 200, 0.5, 10)]
for T in (Float64, Float32)
  for (dname, seed, n, p, rho, k) in (QUICK ? small[1:1] : small)
    X0, y0 = design(seed, n, p, rho, k)
    X, y = T.(X0), T.(y0)
    for start in (:cold, :warm), (container, order) in ((:dense, :cyclic), (:dense, :random), (:sparse, :cyclic), (:sparse, :random)), (pen, frac) in ((:l1, 0.1), (:l1, 0.01), (:enet, 0.1))
      QUICK && !(container === :dense && pen === :l1 && frac == 0.1) && continue
      case(dname, X, y, pen, frac, container, order, start)
    end
    for start in (:cold, :warm), order in (:cyclic, :random)
      QUICK && continue
      case(dname, X, y, :group, 0.1, :block, order, start)
    end
  end
  QUICK && continue
  for (dname, seed, n, p, rho, k) in large
    X0, y0 = design(seed, n, p, rho, k)
    X, y = T.(X0), T.(y0)
    for start in (:cold, :warm), (container, order) in ((:dense, :cyclic), (:sparse, :random)), frac in (0.1, 0.01)
      case(dname, X, y, :l1, frac, container, order, start)
    end
    case(dname, X, y, :group, 0.1, :block, :cyclic, :cold)
  end
end
println("load average ", Sys.loadavg())
