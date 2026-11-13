# alloc_driver.jl tree1 [tree2 ...]: the allocation half of coverage_probe.jl for each tree, same job, same update indices.
#   1. every tree: warm + header + PB guard (envcheck.jl)
#   2. the instrumented reach child on tree 1 only (it fixes the update index k* of every path from the base behavior)
#   3. the alloc child of coverage_probe.jl on each tree with that reach.tsv; compare alloc.tsv of trees 2.. with tree 1
include(joinpath(@__DIR__, "common.jl"))
jl(tree) = `$(Base.julia_cmd()) --project=$(abspath(tree)) --startup-file=no`

function parse_alloc(path)
  d = Dict{Tuple{String,String},NTuple{6,String}}()
  order = Tuple{String,String}[]
  for line in eachline(path)
    f = split(line, '\t')
    f[1] == "A" || continue
    key = (f[2], f[3])
    push!(order, key)
    d[key] = (f[4], f[5], f[6], f[7], f[8], f[9])   # solve bytes, solve note, update bytes, k, update note, signature
  end
  (order, d)
end

function main(trees)
  println("DRIVER julia ", VERSION, " cpu ", Sys.CPU_NAME, " host ", gethostname())
  for t in trees
    println("DRIVER warm ", basename(abspath(t))); flush(stdout)
    run(`$(jl(t)) $(joinpath(@__DIR__, "envcheck.jl"))`)
  end
  mkpath(joinpath(abspath(@__DIR__), "out"))
  root = mktempdir(joinpath(abspath(@__DIR__), "out"); cleanup = false)
  d0 = joinpath(root, "reach"); mkpath(d0)
  println("DRIVER reach child on ", basename(abspath(trees[1]))); flush(stdout)
  run(`$(jl(trees[1])) $(joinpath(@__DIR__, "coverage_probe.jl")) reach $d0`)
  dirs = String[]
  procs = []
  for (j, t) in enumerate(trees)
    d = joinpath(root, string(j, "-", basename(abspath(t)))); mkpath(d)
    cp(joinpath(d0, "reach.tsv"), joinpath(d, "reach.tsv"))
    println("DRIVER alloc child on ", basename(abspath(t))); flush(stdout)
    lg = joinpath(d, "alloc.log")
    push!(procs, run(pipeline(`$(jl(t)) $(joinpath(@__DIR__, "coverage_probe.jl")) alloc $d`; stdout = lg, stderr = lg); wait = false))
    push!(dirs, d)
  end
  for p in procs
    wait(p)
  end
  all(success, procs) || error("an alloc child failed")
  (o1, a1) = parse_alloc(joinpath(dirs[1], "alloc.tsv"))
  println("DRIVER base scenarios ", length(o1))
  for j in 2:length(trees)
    (oj, aj) = parse_alloc(joinpath(dirs[j], "alloc.tsv"))
    label = basename(abspath(trees[j]))
    nsame = 0; ndiff = 0; nhigher = 0; nlower = 0; nsigdiff = 0
    shown = 0
    for k in o1
      haskey(aj, k) || (println("ALLOCCMP ", label, " ", k, " MISSING"); ndiff += 1; continue)
      a, b = a1[k], aj[k]
      a[6] == b[6] || (nsigdiff += 1)
      if a[1:5] == b[1:5]
        nsame += 1
      else
        ndiff += 1
        sa, sb = tryparse(Int, a[1]), tryparse(Int, b[1])
        ua, ub = tryparse(Int, a[3]), tryparse(Int, b[3])
        ((sa !== nothing && sb !== nothing && sb > sa) || (ua !== nothing && ub !== nothing && ub > ua)) && (nhigher += 1)
        ((sa !== nothing && sb !== nothing && sb < sa) || (ua !== nothing && ub !== nothing && ub < ua)) && (nlower += 1)
        shown < 100 && println("ALLOCDIFF ", label, " ", k[1], " ", k[2], " base solve=", a[1], " update=", a[3], "@k", a[4], " | cand solve=", b[1], " update=", b[3], "@k", b[4])
        shown += 1
      end
    end
    println("ALLOCSUMMARY ", label, " scenarios=", length(o1), " identical-bytes=", nsame, " differ=", ndiff,
            " higher=", nhigher, " lower=", nlower, " fingerprint-signature-differs=", nsigdiff)
  end
  # base table of the four default paths for the record
  for k in o1
    (occursin("default", k[1]) || occursin("_default_", k[1])) && println("ALLOCBASE ", k[1], " ", k[2], " solve=", a1[k][1], " update=", a1[k][3], "@k", a1[k][4])
  end
  println("ALLOC_DRIVER DONE")
end
main(ARGS)
