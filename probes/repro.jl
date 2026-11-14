# #296 reproduction: PGD/APG (and CD controls) on tiny loss scales through public solve!.
# Usage: julia --project=. repro.jl [outfile]
using Pkg; Pkg.instantiate(); Pkg.precompile()
using ProximalSolvers, ProximalBase, LinearAlgebra, Random, Printf
include(joinpath(@__DIR__, "ref.jl"))
length(ARGS) >= 2 && (ENV["VARIANT"] = ARGS[2])
length(ARGS) >= 3 && (ENV["SWEEP"] = ARGS[3])
length(ARGS) >= 4 && (ENV["DATASETS"] = ARGS[4])
# VARIANT "impl" measures the checked-out source as is (no prototype overrides)
if get(ENV, "VARIANT", "base") == "impl"
  const VARIANT = Set(["impl"])
else
  include(joinpath(@__DIR__, "variants.jl"))
end
println("VARIANT=", join(sort(collect(VARIANT)), "+"))
const PS = ProximalSolvers

out = length(ARGS) >= 1 ? ARGS[1] : "repro296.tsv"

function data(name; seed = 296)
  rng = Xoshiro(seed)
  if name == "diag"         # steep column 1e6, flat column 1, uncorrelated; y in the flat column
    X = [1e6 0.0; 0.0 1.0; 0.0 0.5]; y = [0.0, 1.0, 0.2]
    return X, y
  elseif name == "orth"     # orthogonal columns with scales 1e6, 1, 1, 1; y orthogonal to column 1
    Q = Matrix(qr(randn(rng, 8, 8)).Q)
    X = Q[:, 1:4] * Diagonal([1e6, 1.0, 1.0, 1.0])
    y = Q[:, 2:4] * [1.0, -1.0, 0.5] + 0.2 * Q[:, 5]
    return X, y
  end
  n, p = name == "big" ? (60, 40) : (30, 12)
  X = randn(rng, n, p)
  β = zeros(p); β[1:4] .= [2.0, -1.5, 1.0, 0.5]
  noise = name == "exact" ? 0.0 : 0.3
  name == "ill" && (X .*= (10.0 .^ range(0, -4; length = p))')
  name == "zerocol" && (X[:, 3] .= 0)
  name == "small" && (X .*= 0.05)
  y = X * β + noise * randn(rng, n)
  X, y
end
const DATASETS = split(get(ENV, "DATASETS", "base"), ',')

const ALPHAS0 = Dict(
  Float64 => [1.0, 1/30, 1e-6, 1e-100, 1e-200, 1e-300, 1e-305, 1e-310],
  Float32 => [1f0, 1f0/30, 1f-6, 1f-20, 1f-30, 1f-35, 1f-37, floatmin(Float32), 1f-39],
)
const ALPHAS = get(ENV, "SWEEP", "") == "1" ?
  Dict(Float64 => [10.0^(-k) for k in 0:2:16], Float32 => [10f0^(-k) for k in 0:2:16]) : ALPHAS0
const FRACS = [0.0, 0.1, 0.5, 1.0]
const OPTS = [
  ("default", ProximalOptions(store_trace = true)),
  ("ftol0", ProximalOptions(ftol = 0, store_trace = true)),
  ("strict", ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true,
                             xtol = 1e-300, gradtol = 1e-11, store_trace = true)),
]
target(::Type{Float64}) = 1e-8
target(::Type{Float32}) = 1e-5

io = open(out, "w")
println(io, join(["data","T","alpha","method","frac","start","opts","accepted","error","converged","x_conv","f_conv","g_conv",
                  "stagnated","f_incr","iters","itlim","f_calls","bt","L_final","dxx_final","g_residual","relgap","relkkt","refkkt","false_success"], '\t'))

for dname in DATASETS
X64, y64 = data(dname)
for T in (Float64, Float32)
  X = T.(X64); y = T.(y64)
  λmax1 = maximum(abs, big.(X)' * big.(y))      # α-free λmax in BigFloat
  for α in ALPHAS[T], frac in FRACS
    λ = T(frac * α * Float64(λmax1))
    frac > 0 && !(λ > 0) && (λ = nextfloat(zero(T)))
    μ = setprecision(() -> big(λ) / big(α), BigFloat, REFPREC)
    key = (T, Float64(α), Float64(frac))
    xstar = ref_lasso(X, y, μ)
    xs64 = Float64.(xstar)
    rng = Xoshiro(7)
    starts = [("cold", zeros(T, size(X, 2))),
              ("warm-rand", T.(randn(rng, size(X, 2)))),
              ("warm-near", T.(xs64 .+ 1e-3 .* randn(rng, size(X, 2))))]
    f = α * LeastSquaresLoss(y, X); g = NormL1(λ)
    for (sname, x0) in starts
      for (mname, method) in (("PGD", ProximalGradientDescent()), ("APG", AccProxGradDescent()))
        for (oname, opts) in OPTS
          x = copy(x0)
          row = Any[dname, T, α, mname, frac, sname, oname]
          try
            r = solve!(x, f, g, method, opts)
            tr = r.trace
            Lf = isempty(tr) ? NaN : tr[end].L
            dxx = isempty(tr) ? NaN : tr[end].dxx
            rg, rk, refk = metrics(x, X, y, α, λ, xstar)
            fs = r.converged && rg > target(T)
            append!(row, [true, "", r.converged, r.x_converged, r.f_converged, r.grad_converged, r.stagnated,
                          r.f_increased, r.iterations, r.iteration_converged, r.f_calls, r.backtrack_steps,
                          Lf, dxx, r.g_residual, rg, rk, refk, fs])
          catch e
            msg = replace(sprint(showerror, e), r"\s+" => " ")[1:min(end, 80)]
            append!(row, [!(e isa ArgumentError), msg, fill("", 18)...])
          end
          println(io, join(string.(row), '\t'))
        end
      end
      # CD control (its own stopping rule)
      x = copy(x0)
      row = Any[dname, T, α, "CD", frac, sname, "cd-default"]
      try
        r = solve!(x, f, g, CDSolver(order = :cyclic, momentum = false))
        rg, rk, refk = metrics(x, X, y, α, λ, xstar)
        append!(row, [true, "", r.converged, "", "", "", "", "", r.passes, "", "", "", "", "", "", rg, rk, refk,
                      r.converged && rg > target(T)])
      catch e
        msg = replace(sprint(showerror, e), r"\s+" => " ")[1:min(end, 80)]
        append!(row, [!(e isa ArgumentError), msg, fill("", 18)...])
      end
      println(io, join(string.(row), '\t'))
    end
  end
end
end
close(io)
println("wrote ", out)
println("=====TSV BEGIN"); print(read(out, String)); println("=====TSV END")
# summary
lines = split.(readlines(out)[2:end], '\t')
nfs = count(l -> l[end] == "true", lines)
println("rows=", length(lines), " false_success=", nfs)
for l in lines
  l[end] == "true" && println(join(l[[1:7; 10:15; 16; 20; 23; 24]], ' '))
end
