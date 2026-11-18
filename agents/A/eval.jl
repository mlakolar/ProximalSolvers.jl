# Evaluate candidates A, ridge, B, D (and the production residual-direction baseline R) on the data sets.
include(joinpath(@__DIR__, "lib.jl"))
const methods = (:R, :A, :ridge, :B, :Bm, :Bcm, :D)

include(joinpath(@__DIR__, "pts.jl"))

function run(pt, m)
  TT = pt.T == "Float64" ? Float64 : Float32
  prob = problem(pt.id); o = oracle(pt.id, TT)
  X, y, λ = data(prob, TT)
  Xd, yd, λd = Float64.(X), Float64.(y), Float64(λ)
  β = pt.β
  chk(θ) = vcert(Xd, yd, λd, λd, β, θ)
  t0 = time()
  local θ, info
  if m === :R
    code, ratio = certify_at(X, y, λ, TT.(β))
    return (; ok = code === :certified, ratio = code === :certified ? ratio : NaN, bigratio = NaN, why = string(code), info = "", sec = time() - t0)
  elseif m === :A;     c = cand_A(Xd, yd, λd, β)
  elseif m === :ridge; c = cand_ridge(Xd, yd, λd, β)
  elseif m === :B;     c = cand_B(Xd, yd, λd, β)
  elseif m === :Bm;    c = cand_Bm(Xd, yd, λd, β, chk)
  elseif m === :Bcm;   c = cand_Bcm(Xd, yd, λd, β, chk)
  elseif m === :D;     c = cand_D(Xd, yd, λd, β, chk)
  end
  sec = time() - t0
  c.θ === nothing && return (; ok = false, ratio = NaN, bigratio = NaN, why = "nocand", info = string(c.info), sec)
  r = chk(c.θ)
  b = bigcert(Xd, yd, λd, β, c.θ)
  why = m === :D && haskey(c.info, :status) && c.info.status === :refuted ? "refuted" : string(r.why)
  (; ok = r.ok, ratio = r.ratio, bigratio = b.ratio, why, info = string(c.info), sec, b)
end

out = open(joinpath(@__DIR__, "out", "eval_main.tsv"), "w")
println(out, join(["set", "id", "T", "start", "config", "method", "ok", "ratio", "bigratio", "why", "lbexc", "excess", "sec", "info"], '\t'))
for pt in points()
  TT = pt.T == "Float64" ? Float64 : Float32
  prob = problem(pt.id); o = oracle(pt.id, TT); X, y, λ = data(prob, TT)
  P = Pbig(X, y, λ, pt.β); lbexc = Float64((P - big(o.U))/big(o.U)); exc = Float64((P - big(o.D))/big(o.D))
  for m in methods
    r = run(pt, m)
    println(out, join(Any[pt.set, pt.id, pt.T, pt.start, pt.config, m, r.ok, r.ratio, r.bigratio, r.why, lbexc, exc, round(r.sec; digits = 5), replace(r.info, '\t' => ' ')], '\t'))
  end
  flush(out)
end
close(out)
