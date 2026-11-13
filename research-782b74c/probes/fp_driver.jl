# fp_driver.jl [--shard i/k] [--limit N] [--serial] tree1 [tree2 ...]
# Runs the corpus on each package source tree (a directory with Project.toml and src/) in a fresh Julia process on this
# node, and compares the record files of trees 2.. with tree 1 byte for byte. Trees are paths relative to the cwd (the
# package root of the sync) or absolute. Records are compared only within this one job (one node, one Julia version).
include(joinpath(@__DIR__, "common.jl"))
include(joinpath(@__DIR__, "fp_compare.jl"))

function parse_args(args)
  shard_i, shard_k, limit, serial = 1, 1, 0, false
  trees = String[]
  i = 1
  while i <= length(args)
    a = args[i]
    if a == "--shard"
      m = match(r"^(\d+)/(\d+)$", args[i + 1]); shard_i, shard_k = parse(Int, m[1]), parse(Int, m[2]); i += 2
    elseif a == "--limit"
      limit = parse(Int, args[i + 1]); i += 2
    elseif a == "--serial"
      serial = true; i += 1
    else
      push!(trees, a); i += 1
    end
  end
  isempty(trees) && error("no trees given")
  (shard_i, shard_k, limit, serial, trees)
end

function child_cmd(tree, rest...)
  `$(Base.julia_cmd()) --project=$(abspath(tree)) --startup-file=no $(joinpath(@__DIR__, "fp_child.jl")) $(collect(rest))`
end

function driver_main(args)
  shard_i, shard_k, limit, serial, trees = parse_args(args)
  println("DRIVER trees: ", join(trees, ", "), "; shard ", shard_i, "/", shard_k, "; limit ", limit, "; serial ", serial)
  println("DRIVER julia ", VERSION, " cpu ", Sys.CPU_NAME, " host ", gethostname())
  outroot = joinpath(abspath(@__DIR__), "out")
  mkpath(outroot)
  outdir = mktempdir(outroot)
  labels = ["t$(i)-$(basename(abspath(t)))" for (i, t) in enumerate(trees)]
  for (t, l) in zip(trees, labels)       # serial warm-up: instantiate, precompile, header and PB guard per tree
    println("DRIVER warm ", l)
    flush(stdout)
    run(child_cmd(t, "warm"))
  end
  recs = [joinpath(outdir, l * ".rec") for l in labels]
  logs = [joinpath(outdir, l * ".log") for l in labels]
  procs = []
  for (j, t) in enumerate(trees)
    cmd = child_cmd(t, recs[j], string(shard_i), string(shard_k), string(limit))
    p = run(pipeline(cmd; stdout = logs[j], stderr = logs[j]); wait = false)
    push!(procs, p)
    serial && wait(p)
  end
  for p in procs
    wait(p)
  end
  ok = true
  for (j, l) in enumerate(labels)
    println("DRIVER ---- log of ", l, " (exit ", procs[j].exitcode, ") ----")
    for line in eachline(logs[j])
      startswith(line, "FP progress") && continue
      println("[", l, "] ", first(line, 300))
    end
    ok &= success(procs[j])
  end
  ok || error("a fingerprint child failed")
  same = true
  for j in 2:length(trees)
    println("DRIVER compare ", labels[1], " vs ", labels[j])
    same &= compare_records(recs[1], recs[j])
  end
  println("DRIVER RESULT ", length(trees) < 2 ? "single tree" : same ? "ALL IDENTICAL to $(labels[1])" : "DIFFERENCES FOUND")
  println("DRIVER comparison command (records vanish with the next sync): julia fp_compare.jl <first>.rec <second>.rec, or cmp")
end

driver_main(ARGS)
