# Always execute both exact-source probes; this is independent of test-tier reuse.
# Run with julia --startup-file=no --project=@stdlib scripts/paired_master_diagnostics.jl.
module PairedMasterDiagnostics

using SHA, TOML

const ROOT = dirname(@__DIR__)
const PS_URL = "https://github.com/mlakolar/ProximalSolvers.jl"
const PB_URL = "https://github.com/mlakolar/ProximalBase.jl"
const PS_A = "64930401cfc0451e886728d916263c4dab2baf36"
const PB_A = "e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291"

function exact_sha(value, label)
  value isa AbstractString && occursin(r"^[0-9a-f]{40}$", value) ||
    throw(ArgumentError("$label must be a full lowercase Git commit SHA"))
  String(value)
end

function pinned_revision(root)
  source = TOML.parsefile(joinpath(root, "Project.toml"))["sources"]["ProximalBase"]
  get(source, "url", nothing) == PB_URL || error("unexpected ProximalBase source URL")
  exact_sha(get(source, "rev", nothing), "ProximalBase revision")
end

function source_digest(root)
  files = ["Project.toml"]
  for (dir, _, names) in walkdir(joinpath(root, "src")), name in names
    endswith(name, ".jl") && push!(files, relpath(joinpath(dir, name), root))
  end
  length(files) > 1 || error("no source files in $root")
  context = SHA.SHA2_256_CTX()
  for path in sort!(files)
    SHA.update!(context, codeunits(path * "\0"))
    SHA.update!(context, read(joinpath(root, path)))
    SHA.update!(context, UInt8[0])
  end
  bytes2hex(SHA.digest!(context))
end

function checkout_identity(root, revision; digest = nothing)
  revision = exact_sha(revision, "checkout revision")
  actual = readchomp(`git -C $root rev-parse HEAD`)
  actual == revision || error("wrong Git HEAD in $root: $actual, expected $revision")
  isempty(readchomp(`git -C $root status --porcelain --untracked-files=no`)) ||
    error("tracked checkout is dirty: $root")
  actual_digest = source_digest(root)
  digest === nothing || actual_digest == digest || error("source changed in $root")
  Dict("commit" => actual, "source_sha256" => actual_digest, "root" => realpath(root))
end

function expected_record_keys()
  keys = String[]
  for T in ("Float32", "Float64"), design in ("orthogonal", "correlated", "nonunique"),
      scale in 1:2, penalty in 1:3, start in 1:2, method in ("random", "cyclic", "pgd")
    push!(keys, "lasso/$T/$design/$scale/$penalty/$start/$method")
  end
  for T in ("Float32", "Float64"), penalty in 1:3, step in 1:2, value in 1:5
    push!(keys, "scalar/$T/$penalty/$step/$value")
  end
  for T in ("Float32", "Float64"), phase in ("construct", "activate", "zero", "compact", "copy", "scatter")
    push!(keys, "owner/$T/$phase")
  end
  sort!(keys)
end

function checked_records(document)
  get(document, "format", nothing) == 1 || error("unknown paired diagnostic format")
  records = document["records"]
  sort!(collect(keys(records))) == expected_record_keys() || error("missing or unexpected diagnostic records")
  all(record -> record isa AbstractDict && !isempty(record), values(records)) || error("empty diagnostic record")
  records
end

function compare_records(a, b)
  left, right = checked_records(a), checked_records(b)
  for key in expected_record_keys()
    left[key] == right[key] || error("paired numerical or API divergence at $key:\nA=$(left[key])\nB=$(right[key])")
  end
  length(left)
end

function fetch_checkout(url, revision, destination)
  revision = exact_sha(revision, "fetched revision")
  run(`git init --quiet $destination`)
  run(`git -C $destination remote add origin $url`)
  run(`git -C $destination fetch --quiet --depth=1 origin $revision`)
  run(`git -C $destination checkout --quiet --detach FETCH_HEAD`)
  checkout_identity(destination, revision)
end

const SETUP = raw"""
using Pkg
Pkg.activate(ARGS[1])
Pkg.develop([Pkg.PackageSpec(path=ARGS[2]), Pkg.PackageSpec(path=ARGS[3])])
Pkg.instantiate()
"""

function run_pair(root = ROOT)
  # Never use neighboring development checkouts or decide to skip from a version string.
  pb_b = pinned_revision(root)
  ps_b = exact_sha(readchomp(`git -C $root rev-parse HEAD`), "current PS revision")
  current_identity = checkout_identity(root, ps_b)
  mktempdir() do work
    ps_a_root, pb_a_root, pb_b_root = (joinpath(work, name) for name in ("ps-A", "pb-A", "pb-B"))
    fetch_checkout(PS_URL, PS_A, ps_a_root)
    fetch_checkout(PB_URL, PB_A, pb_a_root)
    fetch_checkout(PB_URL, pb_b, pb_b_root)
    pinned_revision(ps_a_root) == PB_A || error("frozen PS extraction pin changed")
    documents = Dict{String, Any}()
    for (label, ps_root, ps_sha, pb_root, pb_sha) in
        (("A", ps_a_root, PS_A, pb_a_root, PB_A), ("B", root, ps_b, pb_b_root, pb_b))
      ps_identity = checkout_identity(ps_root, ps_sha)
      pb_identity = checkout_identity(pb_root, pb_sha)
      environment = joinpath(work, "environment-$label")
      settings = ["JULIA_LOAD_PATH" => "@:@stdlib", "JULIA_PKG_PRECOMPILE_AUTO" => "0",
                  "OPENBLAS_NUM_THREADS" => "1"]
      run(addenv(`$(Base.julia_cmd()) --startup-file=no --project=@stdlib -e $SETUP $environment $pb_root $ps_root`, settings...))
      output = joinpath(work, "result-$label.toml")
      probe = joinpath(ROOT, "scripts", "paired_master_probe.jl")
      command = `$(Base.julia_cmd()) --startup-file=no --compiled-modules=no --check-bounds=yes --project=$environment $probe $ps_root $ps_sha $(ps_identity["source_sha256"]) $pb_root $pb_sha $(pb_identity["source_sha256"])`
      open(output, "w") do io
        run(pipeline(addenv(command, settings...); stdout = io))
      end
      document = TOML.parsefile(output)
      checked_records(document)
      document["provenance"]["PS"] == ps_identity || error("loaded PS identity mismatch")
      document["provenance"]["PB"] == pb_identity || error("loaded PB identity mismatch")
      documents[label] = document
      println("$label PS=$(ps_sha) source=$(ps_identity["source_sha256"]) path=$(ps_identity["root"])")
      println("$label PB=$(pb_sha) source=$(pb_identity["source_sha256"]) path=$(pb_identity["root"])")
      println("$label Julia=$(document["provenance"]["julia"]) BLAS=$(document["provenance"]["blas"])")
    end
    count = compare_records(documents["A"], documents["B"])
    checkout_identity(root, ps_b; digest = current_identity["source_sha256"])
    println("Paired exact-source diagnostics passed: $count records; both fresh processes executed.")
  end
  nothing
end

end

if abspath(PROGRAM_FILE) == @__FILE__
  isempty(ARGS) || error("paired diagnostics accepts no arguments")
  PairedMasterDiagnostics.run_pair()
end
