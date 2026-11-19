# Held-out evaluation (protocol §1–4). Usage: julia run_heldout.jl <worker> <nworkers> [set] [tag]
# set = all (default) | cross (the 1.10 subset of protocol §4: fixtures, N8p20, NE, H-cor seeds 9951–9952;
# M0 and M1 only).
include(joinpath(@__DIR__, "lib.jl"))
const W, NW = parse(Int, ARGS[1]), parse(Int, ARGS[2])
const SET = length(ARGS) >= 3 ? ARGS[3] : "all"
const TAG = length(ARGS) >= 4 ? ARGS[4] : "113"
odir = joinpath(HERE, "..", "out", "oracle")
function orec(id, T)
  VERSION >= v"1.11" && return deserialize(joinpath(odir, "$(id)_$(T).jls"))
  l = readlines(joinpath(odir, "$(id)_$(T).txt"))      # exact text copy (oracle_to_text.jl)
  (; relwidth = parse(Float64, l[1]), exactfit = parse(Bool, l[2]), Ubig = parse(BigFloat, l[3]),
     Dbig = parse(BigFloat, l[4]), β = parse.(Float64, l[5:end]))
end

incross(p) = p.group == "fixture" || startswith(p.id, "N8p20") || startswith(p.id, "NE") ||
             p.id in ("COR-0.05-s9951", "COR-0.05-s9952", "COR-0.2-s9951", "COR-0.2-s9952")
probs = vcat(dev_problems(), heldout_problems())
SET == "cross" && filter!(incross, probs)
# Julia < 1.11: the generators give different data (BLAS/RNG), so load the 1.13 data exported bitwise.
function loaddata(p)
  open(joinpath(HERE, "..", "out", "data", "$(p.id).bin")) do io
    n, q = read(io, Int64), read(io, Int64)
    X = Matrix{Float64}(undef, n, q); read!(io, X); y = Vector{Float64}(undef, n); read!(io, y)
    merge(p, (; X, y, λ = read(io, Float64)))
  end
end
VERSION < v"1.11" && (probs = map(loaddata, probs))
methods = SET == "cross" ? ("M1",) : ("M1", "M1g", "M2", "M2g")
jobs = [(p, T, c, s) for p in probs for T in (Float64, Float32) for c in CONFIGS for s in p.starts]

function classify(X, y, λ, β, o)
  P = Pbig(X, y, λ, β)
  (; excess = Float64((P - o.Dbig) / o.Dbig), lbex = Float64((P - o.Ubig) / o.Ubig), P)
end
cls(certified, excess) = excess <= 1e-4 ? (certified ? "correct-certified" : "nearopt-uncertified") : "nonoptimal"

out = open(joinpath(HERE, "..", "out", "heldout_$(SET)_$(TAG)_$W.tsv"), "w")
cols = ["id", "group", "T", "config", "start", "method", "triggered", "base", "budget", "used", "iters", "matvecs",
        "certified", "via", "ratio", "excess", "lbex", "excess0", "class", "false_cert", "ret_x0", "improved",
        "changed_nodecrease", "worse", "nnz", "n", "p", "exhausted", "secs", "oracle_ok", "opt_exactfit"]
println(out, join(cols, '\t'))
row(d) = (println(out, join([get(d, Symbol(c), "") for c in cols], '\t')); flush(out))

for (i, (prob, T, config, st)) in enumerate(jobs)
  (i % NW == W) || continue
  o = orec(prob.id, T)
  X, y, λ = T.(prob.X), T.(prob.y), T(prob.λ)
  β0 = start_point(prob, st, o.β)
  okor = o.relwidth <= 1e-6
  common = (; id = prob.id, group = prob.group, T = string(T), config, start = st, n = size(X, 1), p = size(X, 2),
            oracle_ok = okor, opt_exactfit = o.exactfit)
  x0, r0, t0, _ = solve_mode(X, y, λ, β0, config; mode = :off)
  trig = !r0.converged && r0.passes < 100_000
  c0 = classify(X, y, λ, x0, o)
  row(Dict(pairs((; common..., method = "M0", triggered = trig, base = r0.passes, used = 0, certified = r0.converged,
                  ratio = r0.gap, excess = c0.excess, lbex = c0.lbex, excess0 = c0.excess, class = cls(r0.converged, c0.excess),
                  false_cert = r0.converged && c0.lbex > r0.gap, ret_x0 = true, improved = false, changed_nodecrease = false,
                  worse = false, nnz = count(!iszero, x0), secs = t0))))
  trig || continue
  cx0 = cert_at(X, y, λ, x0)
  for meth in methods
    if meth in ("M1", "M1g")
      x, r, t, lg = solve_mode(X, y, λ, β0, config; mode = :d2, dual = meth == "M1g" ? m1g_dual : nothing)
      lg === nothing && error("no fallback record for a triggered run: $(prob.id) $T $config $st")
      # the base part of the D2 run must replay M0 exactly
      lg.base == r0.passes || error("base replay differs: $(prob.id) $T $config $st")
      res = (; ret = x, certified = r.converged, via = String(lg.via), ratio = lg.ratio, budget = lg.budget,
             used = lg.used, iters = lg.stages, matvecs = "", secs = lg.secs)
    else
      rng = Xoshiro(7)
      xb, rb, _, _ = solve_mode(X, y, λ, β0, config; mode = :off, rng)
      xb == x0 || error("base replay differs (PDHG): $(prob.id)")
      pd = pdhg_fallback(X, y, λ, xb, rb.passes, config, rng; gen = meth == "M2g")
      res = (; ret = pd.ret, certified = pd.certified, via = pd.via, ratio = pd.ratio, budget = pd.budget,
             used = pd.used, iters = pd.iters, matvecs = pd.matvecs + pd.polish_passes, secs = pd.secs)
    end
    c = classify(X, y, λ, res.ret, o)
    retx0 = res.ret == x0
    cr = cert_at(X, y, λ, res.ret)
    row(Dict(pairs((; common..., method = meth, triggered = true, base = r0.passes, budget = res.budget, used = res.used,
                    iters = res.iters, matvecs = res.matvecs, certified = res.certified, via = res.via, ratio = res.ratio,
                    excess = c.excess, lbex = c.lbex, excess0 = c0.excess, class = cls(res.certified, c.excess),
                    false_cert = res.certified && c.lbex > res.ratio, ret_x0 = retx0, improved = c.P < c0.P,
                    changed_nodecrease = !retx0 && !(cr.pup < cx0.plo), worse = c.P > c0.P, nnz = count(!iszero, res.ret),
                    exhausted = res.used >= res.budget, secs = res.secs))))
  end
end
close(out)
