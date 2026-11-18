# Experiment C: step accuracy and master-vs-candidate differences, per family and type.
# args: N SEED [fam1,fam2,...]
include("r1lib.jl")
include("exp2_fams.jl")
const N = parse(Int, get(ARGS, 1, "300")); const SEED = parse(Int, get(ARGS, 2, "1"))
function main()
  println("# julia ", VERSION, " N=", N, " seed=", SEED)
  only = length(ARGS) >= 3 ? Symbol.(split(ARGS[3], ',')) : nothing
  repro = open(joinpath(@__DIR__, "exp2c_repro_$(VERSION.major).$(VERSION.minor)_s$(SEED).txt"), "w")
  for (fname, gen) in FAMS, T in (Float32, Float64)
    (only === nothing || fname in only) || continue
    rng = Xoshiro(hash((fname, T, SEED)))
    cnt = 0; tries = 0
    worst = Dict(t => 0.0 for t in TNAMES); over = Dict(t => 0 for t in TNAMES)
    ndiff = 0; maxulp = 0.0; maxrel = 0.0; cls = Dict{Symbol,Int}(); clsdiff = Dict{Symbol,Int}()
    classmis = 0; mism = Dict{String,Int}(); nrep = 0
    cthr = Dict(t => 0 for t in TNAMES); cnf = Dict(t => 0 for t in TNAMES)
    while cnt < N && tries < 20N
      tries += 1
      inp = gen(rng, T); inp === nothing && continue
      out = evaluate(inp...)
      cnt += 1
      b, c = out[:base], out[:cand]
      cls[b.cls] = get(cls, b.cls, 0) + 1
      for t in TNAMES
        o = out[t]; o.thrown && (cthr[t] += 1); o.nonfinite && (cnf[t] += 1)
        if isfinite(o.ratio); o.ratio > worst[t] && (worst[t] = o.ratio); o.ratio > 1 && (over[t] += 1); end
      end
      if oclass(b) != oclass(c)
        classmis += 1; k = string(oclass(b), " => ", oclass(c)); mism[k] = get(mism, k, 0) + 1
        if nrep < 8
          nrep += 1; println(repro, "# MISMATCH ", fname, " ", T, " ", k, " cls=", b.cls)
          println(repro, "xk=", repr(inp[1]), "; y=", repr(inp[2]), "; λ=", repr(inp[3]), "; old=", repr(inp[4]))
        end
      elseif oclass(b) === :value && !(b.z === c.z)
        ndiff += 1; clsdiff[b.cls] = get(clsdiff, b.cls, 0) + 1
        u, rl = zdiff(T, b.z, c.z); maxulp = max(maxulp, u); maxrel = max(maxrel, rl)
      end
      if isfinite(c.ratio) && c.ratio > 1 && nrep < 8
        nrep += 1; println(repro, "# BOUND ", fname, " ", T, " cand ratio=", c.ratio, " base=", b.ratio)
        println(repro, "xk=", repr(inp[1]), "; y=", repr(inp[2]), "; λ=", repr(inp[3]), "; old=", repr(inp[4]))
      end
    end
    @printf("%-14s %-8s cases=%5d | worst excess/bound base=%.3e cand=%.3e | >1: base=%d cand=%d | differ=%d (max %.3g ulp, max rel %.3g) | outcome-class mismatches=%d | throws b/c=%d/%d nonfinite b/c=%d/%d\n",
            fname, T, cnt, worst[:base], worst[:cand], over[:base], over[:cand], ndiff, maxulp, maxrel, classmis, cthr[:base], cthr[:cand], cnf[:base], cnf[:cand])
    println("    master class: ", sort(collect(cls)), "; differ by master class: ", sort(collect(clsdiff)), isempty(mism) ? "" : "; MISMATCHES " * string(sort(collect(mism))))
    flush(stdout)
  end
  close(repro)
end
main()
