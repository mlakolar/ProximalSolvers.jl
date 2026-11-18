# Task 2b: rerun the baseline matrix and recompute the excess of EVERY run in 512-bit BigFloat against an exact dual bound
# re-derived from the stored θ (see verify_oracle.jl). For certified runs also check excess ≤ reported gap (the production guarantee).
include(joinpath(@__DIR__, "lib.jl"))
setprecision(BigFloat, 512)
const CONFIGS = [("cyclic-dense", (; order = :cyclic, momentum = false, owner = false)), ("random-owner", (; rng = Xoshiro(7), owner = true))]
function exactD(X, y, λ, o)
  Xb = big.(X); θ = big.(o.θ); t = min(big(1), 1 / norm(θ), big(λ) / maximum(abs, Xb' * θ)); t * dot(θ, big.(y))
end
out = open(joinpath(@__DIR__, "..", "out", "baseline_verify_$(VERSION.major).$(VERSION.minor).tsv"), "w")
println(out, join(["id", "T", "start", "config", "converged", "gap", "passes", "excess_exact", "class_exact", "gap_ok", "slack_excess_over_gap"], '\t'))
nfalse = 0; nviol = 0; ncert = 0; maxcert = 0.0
for prob in ORACLE.probs, T in (Float64, Float32)
  o = oracle(prob.id, T); X, y, λ = data(prob, T); Dx = exactD(X, y, λ, o)
  for sk in prob.starts, (cname, ckw) in CONFIGS
    x, r, _, _ = ps_solve(X, y, λ, start_point(prob, sk, o.β); ckw...)
    ex = Float64((Pbig(X, y, λ, x) - Dx) / Dx)
    cls = r.converged ? (ex <= 1e-4 ? "certified" : "FALSE-CERT") : (r.passes >= 20_000 ? "capped" : ex <= 1e-4 ? "missed-cert" : "nonoptimal")
    # sound refutation test of the reported bound: (P - P*)/P* >= (P - U)/U with U = P(β*) ≥ P*; the bound is refuted only if (P-U)/U > gap
    Ub = Pbig(X, y, λ, o.β); lowerrel = Float64((Pbig(X, y, λ, x) - Ub) / Ub)
    gapok = r.converged ? (lowerrel <= Float64(r.gap) * (1 + 1e-12) + 1e-15) : missing
    if r.converged
      global ncert += 1; global maxcert = max(maxcert, ex)
      cls == "FALSE-CERT" && (global nfalse += 1)
      gapok === false && (global nviol += 1)
    end
    println(out, join([prob.id, T, sk, cname, r.converged, r.gap, r.passes, ex, cls, gapok, r.converged ? ex - Float64(r.gap) : ""], '\t')); flush(out)
  end
end
close(out)
println("certified runs=$ncert false-certifications(excess>1e-4)=$nfalse gap-guarantee violations(excess>reported gap)=$nviol max certified excess=$maxcert")
