# Attack on Agent A's support-equation certificate Bcm (agents/A/lib.jl): apply it to the production solver's stuck/final points on all of
# agent C's catalogues (stress, hard, hard2) and judge (a) false certification (vcert ok but BigFloat bound or oracle excess > 1e-4),
# (b) coverage on optimal exact-fit stuck points, (c) cost vs |S|.
include("<RUN>/agents/A/lib.jl")
using Serialization, Printf
setprecision(BigFloat, 256)
files = ["stress_problems.jls", "hard_problems.jls", "hard2_problems.jls"]
out = open(joinpath(@__DIR__, "..", "out", "try_bcm.tsv"), "w")
println(out, join(["set", "id", "T", "start", "n", "p", "nnzS", "stuck_conv", "stuck_excess", "optimal", "Bcm_ok", "Bcm_ratio", "bigratio", "false_cert", "Bcm_secs", "status", "sweeps", "nviol", "εdrop"], '\t'))
nfalse = 0; nrun = 0
for f in files
  S = deserialize(joinpath(@__DIR__, "..", "out", f))
  for pr in S.probs, T in (Float64, Float32)
    rec = S.recs[(pr.id, string(T))]; haskey(rec, :err) && continue
    Xt, yt, λt = T.(pr.X), T.(pr.y), T(pr.λ); X, y, λ = Float64.(Xt), Float64.(yt), Float64(λt)
    for (sn, b0) in pr.starts
      xs, conv, _ = ps_solve(Xt, yt, λt, T.(b0); order = :cyclic, momentum = false)[[1, 2, 2]] |> t -> (t[1], t[2].converged, 0)
      conv && continue
      β = Float64.(xs); excess = Float64((Pbig(X, y, λ, β) - big(rec.D)) / big(rec.D))
      check = θ -> vcert(X, y, λ, λ, β, θ)
      t = @timed cand_Bcm(X, y, λ, β, check)
      c = t.value; ok = hasproperty(c, :r) && c.r.ok
      bigr = c.θ === nothing ? NaN : bigcert(X, y, λ, β, c.θ).ratio
      fc = ok && (excess > 1e-4 || !(bigr <= 1e-4))
      global nrun += 1; fc && (global nfalse += 1)
      println(out, join([f[1:end-12], pr.id, T, sn, size(X, 1), size(X, 2), count(!iszero, β), conv, excess, excess <= 1e-4, ok, hasproperty(c, :r) ? c.r.ratio : NaN, bigr, fc, round(t.time; digits = 4),
                         c.θ === nothing ? "-" : get(c.info, :status, "-"), c.θ === nothing ? "-" : get(c.info, :sweeps, "-"), c.θ === nothing ? "-" : get(c.info, :nviol, "-"), hasproperty(c, :εdrop) ? c.εdrop : ""], '\t')); flush(out)
    end
  end
end
close(out); println("runs=", nrun, " false certifications=", nfalse)
