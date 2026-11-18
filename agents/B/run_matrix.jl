# usage: julia --project=env agents/B/run_matrix.jl CAND OUTNAME [idregex] [Tfilter]
# CAND: C | B | A1 | A2 | E | D[:c0=..,q=..,J=..,floor=..] | C:target=..,maxpasses=..
include(joinpath(@__DIR__, "escape.jl"))
cand = ARGS[1]; outname = ARGS[2]
idre = length(ARGS) >= 3 ? Regex(ARGS[3]) : r".*"
tf = length(ARGS) >= 4 ? ARGS[4] : "both"
parts = split(cand, ":"; limit = 2)
name = parts[1]
opts = Dict{Symbol, Float64}()
length(parts) == 2 && for kv in split(parts[2], ","); k, v = split(kv, "="); opts[Symbol(k)] = parse(Float64, v); end

const CONFIGS = ["cyclic-dense", "random-owner"]
function fallback_for(name, opts)
  name == "C" && return (X, y, λ, x, r, cfg) -> fallback_escape(X, y, λ, x, r, cfg, escape_C; maxpasses = Int(get(opts, :maxpasses, 200)), target = get(opts, :target, 2.0), K = Int(get(opts, :K, 8)))
  name == "Cm" && return (X, y, λ, x, r, cfg) -> fallback_escape(X, y, λ, x, r, cfg, escape_Cm; maxpasses = Int(get(opts, :maxpasses, 200)), target = get(opts, :target, 2.0), K = Int(get(opts, :K, 8)), inner = Int(get(opts, :inner, 20)))
  name == "B" && return (X, y, λ, x, r, cfg) -> fallback_escape(X, y, λ, x, r, cfg, escape_B; K = Int(get(opts, :K, 8)))
  name == "A1" && return (X, y, λ, x, r, cfg) -> fallback_escape(X, y, λ, x, r, cfg, escape_A1; K = 1)
  name == "A2" && return fallback_A2
  name == "E" && return (X, y, λ, x, r, cfg) -> fallback_E(X, y, λ, x, r, cfg; J = Int(get(opts, :J, 10)))
  name == "D2" && return (X, y, λ, x, r, cfg) -> fallback_D2(X, y, λ, x, r, cfg; c0 = get(opts, :c0, 0.1), q = get(opts, :q, 0.3), J = Int(get(opts, :J, 20)), cap = Int(get(opts, :cap, 20000)), scale = Int(get(opts, :scale, 0)), transfer = get(opts, :transfer, 1.0) == 1.0, cross = get(opts, :cross, 1.0) == 1.0)
  name == "D" && return (X, y, λ, x, r, cfg) -> fallback_D(X, y, λ, x, r, cfg; c0 = get(opts, :c0, 1e-2), q = get(opts, :q, 0.1), J = Int(get(opts, :J, 8)), floorrel = get(opts, :floor, 0.0), cap = Int(get(opts, :cap, 20000)), scale = Int(get(opts, :scale, 0)))
  error("cand $name")
end
fb = fallback_for(name, opts)
fname = joinpath(@__DIR__, "out", outname * ".tsv")
out = open(fname, "w")
println(out, join(["id", "family", "T", "start", "config", "cand", "n", "p", "trig", "base_class", "base_excess", "base_passes",
  "final_conv", "final_class", "excess", "optimal", "rrel", "atfloor", "nnz", "esc", "att", "escpasses", "escvisits", "respasses",
  "fb_seconds", "fb_bytes", "gap", "via"], '\t'))
function klass(conv, optimal, capped = false)
  conv ? (optimal ? "certified" : "FALSE-CERT") : optimal ? "optimal-uncert" : capped ? "capped" : "nonoptimal"
end
with_logger(NullLogger()) do
for prob in ORACLE.probs, T in (Float64, Float32)
  (tf == "both" || tf == string(T)) || continue
  occursin(idre, prob.id) || continue
  (get(ENV, "STARTS", "") == "oracle" && !oracle(prob.id, T).exactfit) && continue
  o = oracle(prob.id, T)
  X, y, λ = data(prob, T)
  sks = get(ENV, "STARTS", "") == "oracle" ? (:oracle,) : prob.starts
  for sk in sks, cname in CONFIGS
    β0 = sk === :oracle ? T.(o.β) : start_point(prob, sk, o.β)
    cfg = cfgmaker(cname)
    x, r, sec1, _ = ps_solve(X, y, λ, β0; cfg...)
    c0 = classify(X, y, λ, x, o)
    bcls = klass(r.converged, c0.optimal, !r.converged && r.passes >= 20_000)
    if r.converged
      println(out, join(Any[prob.id, prob.family, T, sk, cname, cand, size(X, 1), size(X, 2), false, bcls, c0.excess, r.passes, true, bcls, c0.excess,
        c0.optimal, c0.rrel, c0.atfloor, c0.nnz, 0, 0, 0, 0, 0, 0.0, 0, r.gap, "stage1"], '\t'))
      continue
    end
    st = @timed fb(X, y, λ, x, r, cfg)
    xf, rf, info = st.value
    c = classify(X, y, λ, xf, o)
    println(out, join(Any[prob.id, prob.family, T, sk, cname, cand, size(X, 1), size(X, 2), true, bcls, c0.excess, r.passes, rf.converged,
      klass(rf.converged, c.optimal), c.excess, c.optimal, c.rrel, c.atfloor, c.nnz, info.esc, info.att, info.escpasses, info.escvisits, info.respasses,
      round(st.time; digits = 6), st.bytes, rf.gap, hasproperty(rf, :via) ? rf.via : ""], '\t'))
    flush(out)
  end
end
end
close(out)
