# Baseline: the current production solver over the preregistered matrix. One TSV row per run.
include(joinpath(@__DIR__, "common.jl"))
const CONFIGS = [("cyclic-dense", (; order = :cyclic, momentum = false, owner = false)),
                 ("random-owner", (; rng = Xoshiro(7), owner = true))]
out = open(joinpath(@__DIR__, "..", "out", "baseline_$(VERSION.major).$(VERSION.minor).tsv"), "w")
println(out, join(["id", "family", "T", "start", "config", "opt_exact", "converged", "gap", "passes", "capped",
                   "excess", "optimal", "rrel", "atfloor", "nnz", "cert_code", "class", "seconds"], '\t'))
for prob in ORACLE.probs, T in (Float64, Float32)
  o = oracle(prob.id, T)
  X, y, λ = data(prob, T)
  for sk in prob.starts, (cname, ckw) in CONFIGS
    β0 = start_point(prob, sk, o.β)
    x, r, sec, _ = ps_solve(X, y, λ, β0; ckw...)
    c = classify(X, y, λ, x, o)
    code, _ = certify_at(X, y, λ, x)
    capped = !r.converged && r.passes >= 20_000
    class = r.converged ? (c.optimal ? "certified" : "FALSE-CERT") :
            capped ? "capped" : c.optimal ? "missed-cert(156)" : "nonoptimal(155)"
    println(out, join(Any[prob.id, prob.family, T, sk, cname, o.exactfit, r.converged, r.gap, r.passes, capped,
                          c.excess, c.optimal, c.rrel, c.atfloor, c.nnz, code, class, round(sec; digits = 4)], '\t'))
    flush(out)
  end
end
close(out)
