# Julia 1.10-compatible baseline runner (no JuMP): reads out/export (written under 1.13) and runs the production solver exactly like baseline.jl.
using ProximalBase, ProximalSolvers, LinearAlgebra, Logging, Random, Printf
const PS = ProximalSolvers
setprecision(BigFloat, 256)
dir = joinpath(@__DIR__, "..", "out", "export")
Pbig(X, y, λ, b) = norm(big.(y) - big.(X) * big.(b)) + big(λ) * norm(big.(b), 1)
function ps_solve(X::Matrix{T}, y::Vector{T}, λ, β0; owner = false, maxpasses = 20_000, kw...) where T
  x = owner ? SparseIterate(T.(β0)) : T.(β0)
  local r
  st = @timed with_logger(NullLogger()) do
    r = solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(; maxpasses, kw...))
  end
  (owner ? Vector(x) : x), r, st.time
end
function certify_at(X::Matrix{T}, y::Vector{T}, λ, β) where T
  x = SparseIterate(T.(β)); f = SqrtLeastSquaresLoss(y, X); g = NormL1(λ)
  m = PS.cdmodel(f, x); PS.initialize!(m, x); PS._prepare!(m, g, x); PS._certify!(m, x)
end
const CONFIGS = [("cyclic-dense", (; order = :cyclic, momentum = false, owner = false)), ("random-owner", (; rng = Xoshiro(7), owner = true))]
lines = readlines(joinpath(dir, "index.tsv"))[2:end]
out = open(joinpath(@__DIR__, "..", "out", "baseline_$(VERSION.major).$(VERSION.minor).tsv"), "w")
println(out, join(["id", "T", "start", "config", "converged", "gap", "passes", "excess", "class", "cert_code"], '\t'))
for ln in lines
  f = split(ln, '\t'); id = f[1]; n = parse(Int, f[2]); p = parse(Int, f[3]); λ = parse(Float64, f[4]); starts = split(f[5], ",")
  D = Dict(Float64 => parse(Float64, f[6]), Float32 => parse(Float64, f[8]))
  X64 = Matrix{Float64}(undef, n, p); y64 = Vector{Float64}(undef, n); st = Dict{Tuple{DataType,String},Vector{Float64}}()
  open(joinpath(dir, id * ".bin")) do io
    read!(io, X64); read!(io, y64)
    for T in (Float64, Float32), sk in starts
      v = Vector{Float64}(undef, p); read!(io, v); st[(T, String(sk))] = v
    end
  end
  for T in (Float64, Float32)
    X, y, λT = T.(X64), T.(y64), T(λ)
    for sk in starts, (cname, ckw) in CONFIGS
      x, r, _ = ps_solve(X, y, λT, T.(st[(T, String(sk))]); ckw...)
      ex = Float64((Pbig(X, y, λT, x) - big(D[T])) / big(D[T]))
      code, _ = certify_at(X, y, λT, x)
      capped = !r.converged && r.passes >= 20_000
      cls = r.converged ? (ex <= 1e-4 ? "certified" : "FALSE-CERT") : capped ? "capped" : ex <= 1e-4 ? "missed-cert(156)" : "nonoptimal(155)"
      println(out, join([id, T, sk, cname, r.converged, r.gap, r.passes, ex, cls, code], '\t')); flush(out)
    end
  end
end
close(out)
