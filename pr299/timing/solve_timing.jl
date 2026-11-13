# julia --project=<checkout env> solve_timing.jl <label> <rep> <outfile.tsv>
# Supplementary paired PGD/APG solve timing for PR #299 (#279). One fresh process per
# (side, repetition). Each case: seeded data, one warm-up solve, then `batches` batches of
# `inner` solves from a fresh copy of x0; per batch the mean time; recorded: the minimum
# batch mean, the median batch mean, allocated bytes of one warmed solve, iterations and a
# hash of the minimizer bits (results must agree across sides).
using LinearAlgebra, Random, Printf, SHA
using ProximalSolvers, ProximalBase
const PS = ProximalSolvers
BLAS.set_num_threads(1)

label, rep, outfile = ARGS[1], parse(Int, ARGS[2]), ARGS[3]

function problem(::Type{T}, n, p, kind, seed) where {T}
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  if kind == :corr
    ρ = 0.8
    for j in 2:p
      X[:, j] = ρ .* X[:, j-1] .+ sqrt(1 - ρ^2) .* X[:, j]
    end
  end
  β = zeros(p); β[1:min(10, p)] .= randn(rng, min(10, p))
  y = X * β .+ 0.1 .* randn(rng, n)
  X, y = T.(X), T.(y)
  λmax = norm(X' * y, Inf) / n
  f = (one(T) / T(n)) * LeastSquaresLoss(y, X)
  g = NormL1(T(0.1 * λmax))
  f, g, zeros(T, p)
end

const SHAPES = [("small", 50, 20, :iid), ("tall", 500, 100, :iid), ("wide", 100, 500, :iid), ("corr", 200, 200, :corr)]
const OPTS = [("default", () -> ProximalOptions()),
              ("ftol0", () -> ProximalOptions(ftol = 0, xtol = 1e-10, gradtol = 1e-10, maxiter = 2000))]

xhash(x) = bytes2hex(sha1(reinterpret(UInt8, copy(x))))[1:16]

function run_case(f, g, x0, method, opts; batches = 15, inner = 0)
  x = copy(x0); r = solve!(x, f, g, method, opts())          # warm-up and result
  t1 = @elapsed (x = copy(x0); solve!(x, f, g, method, opts()))
  inner = inner > 0 ? inner : clamp(round(Int, 0.02 / max(t1, 1e-7)), 1, 2000)
  means = Float64[]
  for b in 1:batches
    t = 0.0
    for i in 1:inner
      xx = copy(x0)
      t += @elapsed solve!(xx, f, g, method, opts())
    end
    push!(means, t / inner)
  end
  xa = copy(x0); bytes = @allocated solve!(xa, f, g, method, opts())
  sort!(means)
  (minimum(means), means[cld(length(means), 2)], bytes, r.iterations, xhash(r.minimizer), inner)
end

open(outfile, "w") do io
  println(io, "# label=$label rep=$rep julia=$(VERSION) cpu=$(Sys.CPU_NAME) blas=$(BLAS.get_config()) threads=$(BLAS.get_num_threads()) pkg=$(pkgdir(ProximalSolvers)) pb=$(pkgdir(ProximalBase))")
  println(io, "case\tmin_ns\tmedian_ns\tbytes\titerations\txhash\tinner")
  for T in (Float32, Float64), (sname, n, p, kind) in SHAPES, (oname, opts) in OPTS,
      (mname, method) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent()))
    f, g, x0 = problem(T, n, p, kind, 1000 + n + p)
    mn, md, bytes, it, h, inner = run_case(f, g, x0, method, opts)
    @printf(io, "%s/%s/%s/%s\t%d\t%d\t%d\t%d\t%s\t%d\n", mname, T, sname, oname,
            round(Int, 1e9 * mn), round(Int, 1e9 * md), bytes, it, h, inner)
    flush(io)
  end
end
