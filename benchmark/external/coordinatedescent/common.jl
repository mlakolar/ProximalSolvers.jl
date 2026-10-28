using LinearAlgebra, Random, SparseArrays, Statistics, Printf, TOML, SHA

include(joinpath(@__DIR__, "..", "..", "problems.jl"))
include(joinpath(@__DIR__, "..", "..", "certificates.jl"))

const CATALOG_PATH = joinpath(@__DIR__, "catalog.toml")
const HARNESS_ROOT = realpath(joinpath(@__DIR__, "..", ".."))
const PACKAGE_ROOT = realpath(joinpath(@__DIR__, "..", "..", ".."))
const EXTERNAL_STATUS_ORDER = (:error, :timeout, :incomplete, :uncertifiable, :target_missed)
const CATALOG_HEADER = ("id", "group", "problem", "solver", "variant", "phase", "suite",
  "inputs", "issue", "measure", "target")
const EXTERNAL_CATALOG_HEADER = (CATALOG_HEADER..., "case_id", "estimator", "design", "lambda",
  "order", "setting_index", "stopping", "family", "gram_policy")
const METRICS_HEADER = ("id", "group", "phase", "rep", "status", "samples", "ok_samples",
  "median_ns", "mean_ns", "sd_ns", "min_ns", "max_ns", "p95_ns", "gc_share",
  "median_bytes", "mean_bytes", "min_bytes", "max_bytes", "measure", "target",
  "worst_value", "median_value", "data_hash")
const SAMPLES_HEADER = ("id", "rep", "sample", "time_ns", "gc_ns", "bytes", "value", "status")
const ERRORS_HEADER = ("id", "rep", "status", "exception", "stack")
const COEF_HEADER = ("id", "case_id", "setting_index", "rep", "file", "rows", "columns",
  "dtype", "sha256", "lambda_values", "measure", "value", "loadings_change", "status")

tsv_field(::Nothing) = ""
tsv_field(x::AbstractFloat) = repr(x)
tsv_field(x) = replace(string(x), '\t' => ' ', '\n' => ' ', '\r' => ' ')
tsv_line(io, values...) = println(io, join(tsv_field.(values), '\t'))
finite_field(x) = isfinite(x) ? x : nothing
file_sha256(path) = open(io -> bytes2hex(sha256(io)), path)

function write_toml(path, values)
  open(io -> TOML.print(io, values; sorted = true), path, "w")
end

function artifact_path(root, name)
  isabspath(name) && error("artifact paths must be relative")
  path = abspath(joinpath(root, name))
  relative = relpath(path, abspath(root))
  (relative == ".." || startswith(relative, "../")) && error("path leaves artifact directory")
  path
end

function write_array(root, name, array)
  data = vec(Array(array))
  eltype(data) in (Float64, Int64) || error("artifact arrays must be Float64 or Int64")
  words = htol.(reinterpret(UInt64, data))
  path = artifact_path(root, name)
  mkpath(dirname(path))
  open(io -> write(io, words), path, "w")
  Dict("file" => name, "shape" => collect(size(array)), "dtype" => string(eltype(data)),
    "sha256" => file_sha256(path))
end

function read_array(root, spec)
  path = artifact_path(root, spec["file"])
  file_sha256(path) == spec["sha256"] || error("checksum mismatch for $(spec["file"])")
  dims = Int.(spec["shape"])
  !isempty(dims) && all(>(0), dims) || error("invalid array shape")
  T = spec["dtype"] == "Float64" ? Float64 : spec["dtype"] == "Int64" ? Int64 :
    error("unsupported array type")
  bytes = read(path)
  length(bytes) == 8prod(dims) || error("array byte count differs from its shape")
  words = ltoh.(reinterpret(UInt64, bytes))
  reshape(copy(reinterpret(T, words)), dims...)
end

function read_catalog(; suite = "quick")
  suite in ("quick", "extended") || error("suite must be quick or extended")
  catalog = TOML.parsefile(CATALOG_PATH)
  catalog["schema_version"] == 1 || error("unsupported catalog schema")
  cases = filter(c -> suite == "extended" || c["suite"] == "quick", catalog["case"])
  ids = [c["id"] for c in cases]
  length(unique(ids)) == length(ids) || error("duplicate catalog id")
  for c in cases
    join((c["estimator"], c["design"], c["lambda"] == "path" ? "path" :
      string(c["lambda"], "lmax"), c["order"]), '/') == c["id"] || error("invalid catalog id")
    for side in ("legacy", "current")
      haskey(c[side], "defaults") && !isempty(c[side]["ladder"]) || error("missing settings")
    end
  end
  cases
end

function read_artifact(root)
  root = abspath(root)
  manifest = TOML.parsefile(joinpath(root, "manifest.toml"))
  manifest["schema_version"] == 1 && manifest["byte_order"] == "little" &&
    manifest["storage_order"] == "column-major" || error("unsupported artifact schema")
  designs = Dict{String,Any}()
  for design in manifest["design"]
    id = design["id"]
    haskey(designs, id) && error("duplicate artifact design")
    files = Dict(name => read_array(root, spec) for (name, spec) in design["files"])
    n, p = design["n"], design["p"]
    size(files["X"]) == (n, p) && length(files["y"]) == n || error("design shape mismatch")
    for name in ("beta_true", "beta0", "weights", "fixed_loadings")
      length(files[name]) == p || error("wrong $name length")
    end
    indices, offsets = files["group_indices"], files["group_offsets"]
    first(offsets) == 1 && last(offsets) == p + 1 && issorted(offsets) || error("invalid group offsets")
    groups = [Int.(indices[offsets[k]:offsets[k+1]-1]) for k in 1:length(offsets)-1]
    sort(reduce(vcat, groups)) == collect(1:p) || error("groups must partition the columns")
    λpath = Float64.(files["lambda_path"])
    length(λpath) == 50 && issorted(λpath; rev = true) && all(>(0), λpath) || error("invalid path grid")
    designs[id] = (; X = files["X"], y = vec(files["y"]), n, p, groups,
      w_group = vec(files["group_weights"]), w = vec(files["weights"]),
      Γ = vec(files["fixed_loadings"]), β0 = vec(files["beta0"]), λpath,
      λmax = design["lambda_max"], design = id)
  end
  cases = Dict{String,Any}()
  for c in manifest["case"]
    haskey(cases, c["id"]) && error("duplicate artifact case")
    haskey(designs, c["design"]) || error("case has no design")
    cases[c["id"]] = c
  end
  (; root, manifest, designs, cases, sha256 = file_sha256(joinpath(root, "manifest.toml")))
end

function case_data(artifact, case)
  input = get(artifact.cases, case["id"], nothing)
  input === nothing && error("artifact does not contain $(case["id"])")
  for field in ("estimator", "design", "order", "lambda")
    input[field] == case[field] || error("artifact/catalog $field mismatch")
  end
  d = artifact.designs[case["design"]]
  λs = Float64.(input["lambda_values"])
  if case["estimator"] == "path"
    λs == d.λpath || error("case grid differs from artifact grid")
  else
    length(λs) == 1 && only(λs) == case["lambda"] * d.λmax || error("wrong case lambda")
  end
  data = merge(d, (; λ = last(λs), λs, seed = Int(input["solver_seed"])))
  if case["estimator"] == "quadratic"
    # These sufficient statistics are prepared outside every public-API observation.
    data = merge(data, (; A = Matrix(Symmetric(d.X' * d.X / d.n)), b = -(d.X' * d.y) / d.n))
  end
  data
end

struct IncompleteExternalPath <: Exception
  detail::String
end
Base.showerror(io::IO, err::IncompleteExternalPath) = print(io, err.detail)

function certify_case(case, data, output)
  a, kind = data, case["estimator"]
  loading_change = NaN
  refit_converged = nothing
  if kind == "path"
    output.λs == a.λs && length(output.βs) == 50 ||
      throw(IncompleteExternalPath("returned path differs from the explicit 50-level grid"))
    cert = path_certificate([lasso_certificate(a.X, a.y, 1 / a.n, λ, a.w, β)
      for (λ, β) in zip(output.λs, output.βs)])
  elseif kind == "group_lasso"
    cert = group_certificate(a.X, a.y, 1 / a.n, a.λ, a.groups, a.w_group, output.β)
  elseif kind in ("sqrt_lasso", "scaled_lasso")
    cert = weighted_sqrt_lasso_certificate(a.X, a.y, a.λ, a.w, output.β)
  elseif kind == "feasible_lasso"
    result = feasible_lasso_self_consistency(a.X, a.y, a.λ, output.β)
    cert, loading_change = result.certificate, result.loadings_change
    refit_converged = result.refit_converged
  else
    # The quadratic omits y'y/(2n); this least-squares certificate restores it.
    weights = kind == "weighted_lasso" ? a.Γ : a.w
    cert = lasso_certificate(a.X, a.y, 1 / a.n, a.λ, weights, output.β)
  end
  (; certificate = cert, loadings_change = loading_change, refit_converged)
end

function external_fingerprint(root, files)
  io = IOBuffer()
  for file in sort(files)
    write(io, relpath(file, root), '\0', read(file), '\0')
  end
  bytes2hex(sha1(take!(io)))
end

function package_fingerprint(root)
  files = [joinpath(root, "Project.toml")]
  for directory in ("src", "ext")
    path = joinpath(root, directory)
    isdir(path) || continue
    for (folder, _, names) in walkdir(path), name in names
      endswith(name, ".jl") && push!(files, joinpath(folder, name))
    end
  end
  external_fingerprint(root, files)
end

function git_identity(root)
  revision = readchomp(pipeline(`git -C $root rev-parse HEAD`; stderr = devnull))
  dirty = !isempty(readchomp(pipeline(`git -C $root status --porcelain --untracked-files=no`; stderr = devnull)))
  revision, dirty
end

function aggregate_status(statuses)
  for status in EXTERNAL_STATUS_ORDER
    status in statuses && return status
  end
  :ok
end

function timing_statistics(rows)
  ok = filter(r -> r.status == :ok, rows)
  isempty(ok) && return ntuple(_ -> nothing, 11)
  times, bytes = [r.time_ns for r in ok], [r.bytes for r in ok]
  integer(x) = round(Int, x)
  (integer(median(times)), integer(mean(times)), integer(std(times; corrected = false)),
    minimum(times), maximum(times), integer(quantile(times, 0.95)),
    sum(r.gc_ns for r in ok) / max(sum(times), 1), integer(median(bytes)),
    integer(mean(bytes)), minimum(bytes), maximum(bytes))
end
