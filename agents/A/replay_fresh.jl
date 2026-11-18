# Replay the baseline (same order, shared Xoshiro(7) exactly as baseline.jl) and save every final point.
include("<RUN>/scripts/common.jl")
const CFG(cn) = cn == "cyclic-dense" ? (; order = :cyclic, momentum = false, owner = false) : (; rng = Xoshiro(7), owner = true)

recs = NamedTuple[]
base = [split(l, '\t') for l in readlines(joinpath(@__DIR__, "..", "..", "out", "baseline_1.13.tsv"))[2:end]]
i = 0; mism = 0
for prob in ORACLE.probs, T in (Float64, Float32)
  o = oracle(prob.id, T)
  X, y, λ = data(prob, T)
  for sk in prob.starts, cname in ("cyclic-dense", "random-owner"); ckw = CFG(cname);
    global i += 1
    β0 = start_point(prob, sk, o.β)
    x, r, sec, _ = ps_solve(X, y, λ, β0; ckw...)
    c = classify(X, y, λ, x, o)
    code, _ = certify_at(X, y, λ, x)
    capped = !r.converged && r.passes >= 20_000
    class = r.converged ? (c.optimal ? "certified" : "FALSE-CERT") :
            capped ? "capped" : c.optimal ? "missed-cert(156)" : "nonoptimal(155)"
    b = base[i]
    ok = b[1] == prob.id && b[3] == string(T) && b[4] == string(sk) && b[5] == cname && b[17] == class && b[16] == string(code)
    ok || (global mism += 1; println("MISMATCH ", i, " ", b[1], " ", b[3], " ", b[4], " ", b[5], " base=", b[17], "/", b[16], " now=", class, "/", code))
    push!(recs, (; id = prob.id, T = string(T), start = string(sk), config = cname, β = Vector{Float64}(x), class, code = string(code),
                 converged = r.converged, passes = r.passes))
  end
end
println("runs=", i, " mismatches=", mism)
serialize(joinpath(@__DIR__, "final_points_freshrng.jls"), recs)
