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

# Settings of the probe's optimization solves that the stopping-flag relations below refer to.
const PGD_MAXITER = 10_000
const CD_MAXPASSES = 100_000

# Bit-exact text for a floating-point value or array; `decode` is its inverse.
bits(v::Union{Float32, Float64}) = string(typeof(v), ":", bitstring(v))
bits(v::AbstractArray) = bits.(v)
function decode(text::AbstractString)
  type, pattern = split(text, ':')
  type == "Float32" ? reinterpret(Float32, parse(UInt32, pattern; base = 2)) :
    type == "Float64" ? reinterpret(Float64, parse(UInt64, pattern; base = 2)) :
    error("unknown floating-point type in a stored value: $type")
end
decode(texts::AbstractArray) = decode.(texts)

# Optimization records ("lasso/<T>/<design>/<scale>/<penalty>/<start>/<method>") are checked for
# solution quality; scalar and owner records are exact contracts.
is_optimization(key) = startswith(key, "lasso/")

# Accuracy threshold for the independent checks, relative to max(1, |optimum|) where it applies.
quality_tolerance(::Type{T}) where T = T == Float32 ? 5e-4 : 2e-6

# Independent quality checks of one optimization record: objective against the reference optimum,
# KKT residual, the returned minimum against the independent objective, fitted values and, for the
# designs with a unique solution, the coefficients. The record holds the solution's independent
# values ("objective", "kkt" and "fitted", computed in Float64 by the probe; "minimum" and "point",
# the exact bits of the returned value and iterate) and the independent reference ("optimum",
# "reference_fit", "reference_point" for unique designs, and "kkt_scale", the scale of the KKT
# threshold). Throws an ErrorException that names the record and `label` at the first failed check.
function check_quality(key, record; label = "")
  parts = split(key, '/')
  T = parts[2] == "Float32" ? Float32 : Float64
  tolerance = quality_tolerance(T)
  context = isempty(label) ? key : "$key $label"
  objective, kkt, optimum = Float64(record["objective"]), Float64(record["kkt"]), Float64(record["optimum"])
  scale = max(1.0, abs(optimum))
  isfinite(objective) && objective - optimum <= tolerance * scale ||
    error("independent objective failure: $context: objective $objective, optimum $optimum")
  kkt <= tolerance * Float64(record["kkt_scale"]) ||
    error("independent KKT failure: $context: $kkt")
  abs(Float64(decode(record["minimum"])) - objective) <= tolerance * scale ||
    error("returned objective mismatch: $context")
  fitted, reference_fit = Float64.(record["fitted"]), Float64.(record["reference_fit"])
  norm_inf(v) = maximum(abs, v)
  norm_inf(fitted - reference_fit) <= 4tolerance * max(1, norm_inf(reference_fit)) ||
    error("independent fitted-value failure: $context")
  if parts[3] != "nonunique"
    point, reference = Float64.(decode(record["point"])), Float64.(record["reference_point"])
    norm_inf(point - reference) <= 4tolerance * max(1, norm_inf(reference)) ||
      error("independent coefficient failure: $context")
  end
  nothing
end

# Truthful stopping flags of one optimization record of the current tree. Each relation below is
# one that the source guarantees under the probe's settings (default ProximalOptions apart from
# maxiter, ftol, xtol and gradtol: no callback, call limits or time limit, allow_f_increases =
# false; CDSolver with maxpasses = CD_MAXPASSES). It is a statement about the flags, not about
# accuracy: `converged = true` is no accuracy evidence here, accuracy comes from `check_quality`.
#
# Proximal gradient descent (src/solve.jl, src/utils.jl):
# - `converged == (x_converged || f_converged || grad_converged)`, because the last
#   convergence_assessment sets all four (src/utils.jl:70, src/solve.jl:98-99) and the result
#   stores them (src/solve.jl:124-134);
# - `iteration_converged == (iterations == PGD_MAXITER)` (src/solve.jl:122-123);
# - the loop ends only when `converged`, `stopped` or `iteration` reaches maxiter
#   (src/solve.jl:85), and under these settings `stopped` is set only by an objective increase
#   (`f_increased`, src/solve.jl:111-114) or a call limit, which `call_limit_reached` reports; so a
#   record that is not `converged` has `iteration_converged`, `f_increased` or `call_limit_reached`.
# Coordinate descent (src/cd/solver.jl):
# - `converged` is set only inside `if full && converged` after `st.maxchange = maxh` and
#   `converged = maxh < tol` of the same pass (src/cd/solver.jl:199-203 and 236-240), so a converged
#   record has `maxchange < tolerance`. The converse is not guaranteed: a run whose last pass was an
#   active pass with a small change, at the pass limit, is not converged;
# - the pass loop `for pass in 1:s.maxpasses` leaves without the `break` only after `maxpasses`
#   passes (src/cd/solver.jl:196-205), and `st.passes = pass` (line 199), so a record that is not
#   `converged` has `passes == CD_MAXPASSES`.
function check_flags(key, record; label = "")
  context = isempty(label) ? key : "$key $label"
  field(name) = haskey(record, name) ? record[name] : error("stopping field $name is missing: $context")
  flag(name) = field(name) isa Bool ? field(name) : error("stopping flag $name is not a Boolean: $context")
  if endswith(key, "/pgd")
    converged, x, f, gradient = flag("converged"), flag("x_converged"), flag("f_converged"), flag("grad_converged")
    converged == (x || f || gradient) ||
      error("stopping flags inconsistent: converged differs from x, f or gradient convergence: $context")
    flag("iteration_converged") == (field("iterations") == PGD_MAXITER) ||
      error("stopping flags inconsistent: iteration_converged differs from iterations == maxiter: $context")
    converged || flag("iteration_converged") || flag("f_increased") || flag("call_limit_reached") ||
      error("stopping flags inconsistent: no convergence and no stopping reason: $context")
  else
    converged = flag("converged")
    !converged || decode(field("maxchange")) < decode(field("tolerance")) ||
      error("stopping flags inconsistent: converged without maxchange < tolerance: $context")
    converged || field("passes") == CD_MAXPASSES ||
      error("stopping flags inconsistent: not converged before the pass limit: $context")
  end
  nothing
end

# One diagnostic line for an optimization record that differs between the two sides.
function print_difference(io, key, left, right)
  names = sort!([name for name in union(keys(left), keys(right)) if get(left, name, nothing) != get(right, name, nothing)])
  count = haskey(left, "iterations") ? "iterations" : "passes"
  println(io, "diagnostic: $key differs in $(join(names, ", ")); $count A=$(left[count]) B=$(right[count]); ",
    "kkt A=$(left["kkt"]) B=$(right["kkt"])")
end

# Optimization records: both sides pass the quality checks, the current tree (B) also passes the
# flag checks, and the field sets agree (the result API surface); bits, trajectories, iteration
# counts and RNG advancement may differ, and a difference is printed, not an error. Scalar and
# owner records are exact. Returns the number of records.
function compare_records(a, b; io::IO = stdout)
  left, right = checked_records(a), checked_records(b)
  for key in expected_record_keys()
    if is_optimization(key)
      check_quality(key, left[key]; label = "(side A)")
      check_quality(key, right[key]; label = "(side B)")
      check_flags(key, right[key]; label = "(side B)")
      Set(keys(left[key])) == Set(keys(right[key])) ||
        error("result field sets differ at $key:\nA=$(sort!(collect(keys(left[key]))))\nB=$(sort!(collect(keys(right[key]))))")
      left[key] == right[key] || print_difference(io, key, left[key], right[key])
    else
      left[key] == right[key] || error("paired numerical or API divergence at $key:\nA=$(left[key])\nB=$(right[key])")
    end
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
