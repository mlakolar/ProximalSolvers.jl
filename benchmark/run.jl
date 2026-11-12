import ProximalBase, ProximalSolvers
using LinearAlgebra, SparseArrays, Random, Statistics, Printf, TOML, SHA, Profile

include("problems.jl")
include("certificates.jl")
include("cases.jl")

const CATALOG_HEADER = ("id", "group", "problem", "solver", "variant", "phase", "suite",
                        "inputs", "issue", "measure", "target")
const METRICS_HEADER = ("id", "group", "phase", "rep", "status", "samples", "ok_samples",
  "median_ns", "mean_ns", "sd_ns", "min_ns", "max_ns", "p95_ns", "gc_share",
  "median_bytes", "mean_bytes", "min_bytes", "max_bytes", "measure", "target",
  "worst_value", "median_value", "data_hash")
const SAMPLES_HEADER = ("id", "rep", "sample", "time_ns", "gc_ns", "bytes", "value", "status")
const ERRORS_HEADER = ("id", "rep", "status", "exception", "stack")
const CASE_STATUS_ORDER = (:error, :timeout, :incomplete, :uncertifiable, :target_missed)

tsv_field(::Nothing) = ""
tsv_field(x::AbstractFloat) = repr(x)
tsv_field(x) = replace(string(x), '\t' => ' ', '\n' => ' ', '\r' => ' ')
tsv_line(io, values...) = println(io, join(tsv_field.(values), '\t'))
finite_field(x) = isfinite(x) ? x : nothing

function fingerprint(root, files)
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
  fingerprint(root, files)
end

function git_identity(root)
  revision = try
    readchomp(pipeline(`git -C $root rev-parse HEAD`; stderr = devnull))
  catch
    "unavailable"
  end
  dirty = try
    !isempty(readchomp(pipeline(`git -C $root status --porcelain --untracked-files=no`; stderr = devnull)))
  catch
    true
  end
  revision, dirty
end

# The ProximalBase entry of the active manifest and the directory ProximalBase was loaded
# from. A git or registry entry identifies its source by a tree hash, and depot packages
# live in a directory named from that hash, so the loaded directory is checked against it.
function proximalbase_identity()
  root = realpath(dirname(dirname(pathof(ProximalBase))))
  project = Base.active_project()
  manifest = project === nothing ? nothing : Base.project_file_manifest_path(project)
  entry = Dict{String,Any}()
  if manifest !== nothing && isfile(manifest)
    parsed = TOML.parsefile(manifest)
    entries = get(get(parsed, "deps", parsed), "ProximalBase", nothing)
    entries isa AbstractVector && length(entries) == 1 && (entry = only(entries))
  end
  url, rev, tree = get(entry, "repo-url", ""), get(entry, "repo-rev", ""), get(entry, "git-tree-sha1", "")
  source = isempty(entry) ? "unknown" : haskey(entry, "path") ? "path" :
    !isempty(url) ? "git" : !isempty(tree) ? "registry" : "unknown"
  slug_matches = occursin(r"^[0-9a-f]{40}$", tree) &&
    basename(root) == Base.version_slug(Base.UUID(entry["uuid"]), Base.SHA1(tree))
  (; root, source, url, rev, tree, manifest = something(manifest, ""), slug_matches)
end

# Refuse a ProximalBase that a formal record could not identify: a git source at a moving
# revision (a branch name or a short hash), a git or registry source loaded from another
# directory than its manifest tree, and, with PS_EXPECTED_PROXIMALBASE_REV, any source
# other than a git entry at exactly that commit.
function check_proximalbase(identity, expected)
  b = identity
  b.source == "git" && !occursin(r"^[0-9a-f]{40}$", b.rev) &&
    error("ProximalBase tracks the moving revision \"$(b.rev)\"; pin a full commit")
  b.source in ("git", "registry") && !b.slug_matches &&
    error("loaded ProximalBase from $(b.root), not from its manifest tree $(b.tree)")
  isempty(expected) && return nothing
  occursin(r"^[0-9a-f]{40}$", expected) || error("PS_EXPECTED_PROXIMALBASE_REV must be a full commit")
  b.source == "git" && b.rev == expected ||
    error("loaded ProximalBase is $(b.source) $(b.rev); expected the git commit $expected")
  nothing
end

# With PS_EXPECTED_PACKAGE_REVISION, the loaded checkout must be that commit, with no
# tracked or untracked change in Project.toml, src or ext (the fingerprinted files).
function check_package_revision(root, expected)
  isempty(expected) && return nothing
  occursin(r"^[0-9a-f]{40}$", expected) || error("PS_EXPECTED_PACKAGE_REVISION must be a full commit")
  revision, _ = git_identity(root)
  revision == expected || error("loaded ProximalSolvers at revision $revision; expected $expected")
  changes = try
    readchomp(pipeline(`git -C $root status --porcelain -- Project.toml src ext`; stderr = devnull))
  catch
    "unavailable"
  end
  isempty(changes) || error("ProximalSolvers checkout $root differs from $expected: $changes")
  nothing
end

function runner_settings()
  suite = get(ENV, "PS_SUITE", "quick")
  suite in ("quick", "extended") || error("PS_SUITE must be quick or extended")
  groups = sort!(unique(strip.(split(get(ENV, "PS_GROUPS", join(CASE_GROUPS, ',')), ','))))
  isempty(groups) || all(in(CASE_GROUPS), groups) || error("unknown PS_GROUPS entry")
  rep = parse(Int, get(ENV, "PS_REPETITION", "1"))
  1 <= rep <= 10 || error("PS_REPETITION must be between 1 and 10")
  samples = parse(Int, get(ENV, "PS_SAMPLES", suite == "quick" ? "50" : "100"))
  seconds = parse(Float64, get(ENV, "PS_SECONDS", suite == "quick" ? "1" : "3"))
  case_seconds = parse(Float64, get(ENV, "PS_CASE_SECONDS", "60"))
  profile_seconds = parse(Float64, get(ENV, "PS_PROFILE_SECONDS", "0"))
  samples > 0 && isfinite(seconds) && seconds > 0 && isfinite(case_seconds) &&
    case_seconds > 0 && isfinite(profile_seconds) && profile_seconds >= 0 ||
    error("samples and time limits must be positive; profile seconds must be nonnegative")
  output = abspath(get(ENV, "PS_OUTPUT", joinpath(@__DIR__, "results")))
  expected = get(ENV, "PS_EXPECTED_PACKAGE_ROOT", "")
  root = realpath(dirname(dirname(pathof(ProximalSolvers))))
  if !isempty(expected)
    expected = realpath(expected)
    root == expected || error("loaded ProximalSolvers from $root; expected $expected")
  end
  cases = strip(get(ENV, "PS_CASES", ""))
  expected_revision = strip(get(ENV, "PS_EXPECTED_PACKAGE_REVISION", ""))
  check_package_revision(root, expected_revision)
  expected_base = strip(get(ENV, "PS_EXPECTED_PROXIMALBASE_REV", ""))
  base = proximalbase_identity()
  check_proximalbase(base, expected_base)
  (; suite, groups, cases, rep, samples, seconds, case_seconds, profile_seconds, output,
     expected, root, expected_revision, expected_base, base)
end

"""
    select_cases(catalog, filter)

Keep the catalog entries matching a comma-separated `filter` of exact case IDs or
patterns in which `*` matches any characters, including `/`. Every entry must match a
case. Selection keeps catalog order and builds no data: `make` runs later with seeds
keyed by scenario and repetition, so a case's inputs do not depend on the selection.
"""
function select_cases(catalog, filter::AbstractString)
  patterns = [String(strip(p)) for p in split(filter, ',') if !isempty(strip(p))]
  isempty(patterns) && throw(ArgumentError("empty case filter"))
  literal(text) = replace(text, r"[\\^$.|?*+()\[\]{}]" => s"\\\0")
  matchers = map(patterns) do pattern
    occursin('*', pattern) || return ==(pattern)
    regex = Regex("^" * join(literal.(split(pattern, '*')), ".*") * "\$")
    id -> occursin(regex, id)
  end
  for (pattern, matcher) in zip(patterns, matchers)
    any(spec -> matcher(spec.meta.id), catalog) ||
      throw(ArgumentError("no case in the selected suite and groups matches \"$pattern\""))
  end
  [spec for spec in catalog if any(matcher -> matcher(spec.meta.id), matchers)]
end

function start_metadata(settings)
  s = settings
  base_root = realpath(dirname(dirname(pathof(ProximalBase))))
  revision, dirty = git_identity(s.root)
  Dict{String,Any}("julia" => string(VERSION), "rep" => s.rep, "suite" => s.suite,
    "groups" => join(s.groups, ','), "case_filter" => s.cases,
    "harness_hash" => fingerprint(@__DIR__, [joinpath(@__DIR__, name) for name in
      ("problems.jl", "certificates.jl", "cases.jl", "run.jl")]),
    "proximalsolvers_path" => s.root, "proximalsolvers_sha" => revision,
    "proximalsolvers_dirty" => dirty, "proximalsolvers_hash" => package_fingerprint(s.root),
    "proximalbase_version" => string(pkgversion(ProximalBase)),
    "proximalbase_hash" => package_fingerprint(base_root),
    "expected_package_root" => s.expected, "julia_threads" => Threads.nthreads(),
    "blas_threads" => BLAS.get_num_threads(), "blas" => string(BLAS.get_config()),
    "cpu" => Sys.CPU_NAME, "cpu_model" => Sys.cpu_info()[1].model,
    "samples_target" => s.samples, "seconds_limit" => s.seconds,
    "case_seconds" => s.case_seconds, "profile_seconds" => s.profile_seconds,
    "seed_scheme" => "FNV1a64 keyed scenario xor repetition",
    "job_id" => get(ENV, "SLURM_JOB_ID", "none"),
    # Source identities checked at startup (#110); validate.py reads only the keys above.
    "expected_package_revision" => s.expected_revision,
    "expected_proximalbase_rev" => s.expected_base,
    "proximalbase_source" => s.base.source, "proximalbase_url" => s.base.url,
    "proximalbase_rev" => s.base.rev, "proximalbase_tree_sha1" => s.base.tree,
    "proximalbase_path" => s.base.root, "active_manifest" => s.base.manifest,
    "capabilities" => join(sort!(collect(CAPABILITIES)), ','),
    "deferred_cases" => length(build_catalog(s.suite, s.groups; deferred = true)))
end

function write_metadata(path, metadata)
  open(path, "w") do io
    TOML.print(io, metadata; sorted = true)
  end
end

function certificate_status(cert, meta)
  cert.status == :uncertifiable && return :uncertifiable
  cert.status == :ok || error("invalid certificate status $(cert.status)")
  string(cert.measure) == meta.measure || error("certificate measure differs from catalog")
  isfinite(cert.value) && cert.value >= 0 || return :uncertifiable
  isfinite(meta.target) && cert.value > meta.target ? :target_missed : :ok
end

function observe!(state, meta, case_seconds)
  try
    state.reset!()
    timed = @timed state.call!()
    ns = round(Int, timed.time * 1e9)
    gc = round(Int, timed.gctime * 1e9)
    cert, status, detail, stack = nothing, :ok, "", ""
    try
      cert = state.certify(timed.value)
      status = certificate_status(cert, meta)
      detail = cert.detail
    catch err
      cert = nothing
      status = err isa IncompletePath ? :incomplete : :error
      detail = sprint(showerror, err)
      stack = sprint(Base.show_backtrace, catch_backtrace())
    end
    if timed.time > case_seconds && status != :error
      status = :timeout
      detail = "single call exceeds PS_CASE_SECONDS"
    end
    value = cert === nothing ? NaN : cert.value
    (; time_ns = ns, gc_ns = gc, bytes = Int(timed.bytes), value, status, detail, stack)
  catch err
    (; time_ns = nothing, gc_ns = nothing, bytes = nothing, value = NaN,
       status = :error, detail = sprint(showerror, err),
       stack = sprint(Base.show_backtrace, catch_backtrace()))
  end
end

function aggregate_status(statuses)
  for status in CASE_STATUS_ORDER
    status in statuses && return status
  end
  :ok
end

function profile_case!(io, state, meta, seconds)
  seconds > 0 || return
  Profile.clear()
  deadline = time_ns() + round(UInt64, seconds * 1e9)
  while time_ns() < deadline
    state.reset!()
    output = Profile.@profile state.call!()
    certificate_status(state.certify(output), meta) == :ok || error("profile output fails certification")
  end
  println(io, "CASE\t", meta.id)
  Profile.print(io; format = :flat, C = true, sortedby = :count, mincount = 1)
  Profile.print(io; format = :tree, C = true, maxdepth = 22, mincount = 1)
  flush(io)
end

function measure_case(spec, settings, profiles)
  rows = NamedTuple[]
  observations = NamedTuple[]
  hash = ""
  try
    state = spec.make(settings.rep)
    hash = state.problem_hash
    # Validation compiles the operation without contributing to sample statistics.
    validation = observe!(state, spec.meta, Inf)
    push!(observations, validation)
    if validation.status != :error && validation.time_ns !== nothing &&
        validation.time_ns / 1e9 > settings.case_seconds
      validation = observe!(state, spec.meta, settings.case_seconds)
      push!(observations, validation)
    end
    if !(validation.status in (:error, :timeout))
      timed_seconds = 0.0
      while length(rows) < 5 || (length(rows) < settings.samples && timed_seconds < settings.seconds)
        row = observe!(state, spec.meta, settings.case_seconds)
        push!(rows, row)
        push!(observations, row)
        row.time_ns === nothing || (timed_seconds += row.time_ns / 1e9)
        row.status in (:error, :timeout) && break
      end
    end
    if aggregate_status([r.status for r in observations]) == :ok && profiles !== nothing
      profile_case!(profiles, state, spec.meta, settings.profile_seconds)
    end
  catch err
    push!(observations, (; status = :error, detail = sprint(showerror, err),
                        stack = sprint(Base.show_backtrace, catch_backtrace())))
  end
  status = aggregate_status([r.status for r in observations])
  failure = status == :ok ? nothing : first(r for r in observations if r.status == status)
  (; rows, status, failure, hash)
end

function timing_statistics(rows)
  ok = filter(r -> r.status == :ok, rows)
  isempty(ok) && return ntuple(_ -> nothing, 11)
  times = [Int(r.time_ns) for r in ok]
  bytes = [Int(r.bytes) for r in ok]
  integer(x) = round(Int, x)
  (integer(median(times)), integer(mean(times)),
   integer(std(times; corrected = false)),
   minimum(times), maximum(times), integer(quantile(times, 0.95)),
   sum(r.gc_ns for r in ok) / max(sum(times), 1),
   integer(median(bytes)), integer(mean(bytes)), minimum(bytes), maximum(bytes))
end

function record_case!(metrics, raw, errors, spec, settings, result)
  meta, rep, rows = spec.meta, settings.rep, result.rows
  for (i, row) in enumerate(rows)
    tsv_line(raw, meta.id, rep, i, row.time_ns, row.gc_ns, row.bytes,
             finite_field(row.value), row.status)
  end
  values = [r.value for r in rows if isfinite(r.value)]
  worst = isempty(values) ? nothing : maximum(values)
  typical = isempty(values) ? nothing : median(values)
  tsv_line(metrics, meta.id, meta.group, meta.phase, rep, result.status, length(rows),
           count(r -> r.status == :ok, rows), timing_statistics(rows)...,
           meta.measure, meta.target, worst, typical, result.hash)
  if result.status != :ok
    failure = result.failure
    tsv_line(errors, meta.id, rep, result.status, failure.detail, failure.stack)
  end
  flush(raw)
  flush(metrics)
  flush(errors)
end

function run_records(settings, catalog)
  started = time()
  mkpath(settings.output)
  stem = "julia-$(VERSION)-rep$(lpad(settings.rep, 2, '0'))"
  any(name -> startswith(name, stem), readdir(settings.output)) &&
    error("Refusing to overwrite files with prefix $stem; use a fresh PS_OUTPUT")
  prefix = joinpath(settings.output, stem)
  metadata = start_metadata(settings)
  write_metadata(prefix * "-metadata-start.toml", metadata)
  open(prefix * "-catalog.tsv", "w") do io
    tsv_line(io, CATALOG_HEADER...)
    for spec in catalog
      tsv_line(io, (getproperty(spec.meta, Symbol(field)) for field in CATALOG_HEADER)...)
    end
  end
  order = shuffle!(scenario_rng(settings.rep, "measurement_order"), copy(catalog))
  failures = 0
  profiles = settings.profile_seconds > 0 ? open(prefix * "-profiles.txt", "w") : nothing
  try
    profiles === nothing || Profile.init(n = 2_000_000, delay = 0.001)
    open(prefix * "-metrics.tsv", "w") do metrics
      open(prefix * "-samples.tsv", "w") do raw
        open(prefix * "-errors.tsv", "w") do errors
          tsv_line(metrics, METRICS_HEADER...)
          tsv_line(raw, SAMPLES_HEADER...)
          tsv_line(errors, ERRORS_HEADER...)
          for spec in order
            result = measure_case(spec, settings, profiles)
            record_case!(metrics, raw, errors, spec, settings, result)
            failures += result.status != :ok
            println("CASE ", spec.meta.id, " status=", result.status)
          end
        end
      end
    end
  finally
    profiles === nothing || close(profiles)
  end
  merge!(metadata, Dict("cases" => length(catalog), "ok_cases" => length(catalog) - failures,
    "nonok_cases" => failures, "elapsed_s" => time() - started,
    "maxrss_bytes" => Sys.maxrss(), "finished" => true))
  # Publish completion only after every other record has closed successfully.
  temporary = prefix * "-metadata-finalizing.toml"
  write_metadata(temporary, metadata)
  mv(temporary, prefix * "-metadata.toml")
  println("REPETITION_FINISHED cases=", length(catalog), " nonok=", failures,
          " elapsed_s=", metadata["elapsed_s"])
  failures == 0 ? 0 : 2
end

function main()
  try
    settings = runner_settings()
    if get(ENV, "PS_LIST", "false") == "deferred"
      # Deferred cases and the capabilities of the loaded package they lack (cases.jl).
      for spec in build_catalog(settings.suite, settings.groups; deferred = true)
        tsv_line(stdout, spec.meta.id, spec.meta.suite, spec.meta.issue,
                 join(missing_requirements(spec), "; "))
      end
      return 0
    end
    catalog = build_catalog(settings.suite, settings.groups)
    skipped = check_deferred_request(settings.cases, settings.suite, settings.groups)
    isempty(skipped) || println(stderr, "NOTE PS_CASES also matches $(length(skipped)) deferred " *
                                "case(s), not run: ", join(skipped, ", "))
    isempty(settings.cases) || (catalog = select_cases(catalog, settings.cases))
    isempty(catalog) && error("no supported case in the selected suite and groups; " *
                              "PS_LIST=deferred lists the deferred ones")
    if get(ENV, "PS_LIST", "false") == "true"
      for spec in catalog
        tsv_line(stdout, spec.meta.id, spec.meta.suite, spec.meta.issue)
      end
      return 0
    end
    Threads.nthreads() == 1 || error("run with JULIA_NUM_THREADS=1")
    BLAS.set_num_threads(1)
    run_records(settings, catalog)
  catch err
    println(stderr, "RECORD_FAILURE ", sprint(showerror, err))
    return 3
  end
end

if abspath(PROGRAM_FILE) == @__FILE__
  exit(main())
end
