# Exploratory local benchmarking for solver development (#110, Stage 1).
#
# Runs selected cases of the formal harness with its own make/reset!/call!/certify
# closures, `observe!` and certificate statuses, and prints a compact report. It writes
# no formal records: its optional TSV is marked exploratory and is not accepted by
# validate.py or compare.py. Usage is in benchmark/README.md ("Local exploration").
#
#   julia --project=ENV benchmark/local.jl [options] CASE_PATTERN...
#   julia> include("benchmark/local.jl"); explore("cd/lasso-dense/cd/B/*")

# A session loads Revise first, when the environment stack provides it, so that it tracks
# ProximalSolvers. Revise is optional and is not a benchmark dependency.
if abspath(PROGRAM_FILE) == (@__FILE__) && "--session" in ARGS
  try
    using Revise
  catch
    println(stderr, "Revise is unavailable; every source edit will require a restart")
  end
end

module PSLocal

using SHA

# What this file loads, recorded before and after loading so that a run never times
# code under a fingerprint of different files. The package fingerprint below is the one
# in run.jl (Project.toml and src/ext .jl files), computed from one read of each file.
function package_state(root)
  files = [joinpath(root, "Project.toml")]
  for directory in ("src", "ext")
    path = joinpath(root, directory)
    isdir(path) || continue
    for (folder, _, names) in walkdir(path), name in names
      endswith(name, ".jl") && push!(files, joinpath(folder, name))
    end
  end
  io, sources = IOBuffer(), Dict{String,String}()
  for file in sort(files)
    name, content = relpath(file, root), read(file)
    write(io, name, '\0', content, '\0')
    name == "Project.toml" || (sources[name] = bytes2hex(sha1(content)))
  end
  (; fingerprint = bytes2hex(sha1(take!(io))), sources,
     project = bytes2hex(sha1(read(joinpath(root, "Project.toml")))))
end

content_hash(paths) = bytes2hex(sha1(join([isfile(p) ? bytes2hex(sha1(read(p))) : "-" for p in paths], ' ')))
const LOCAL_FILE = @__FILE__
local_hash() = content_hash([LOCAL_FILE])
# The active project and manifest decide which dependency versions are loaded.
function environment_files()
  project = Base.active_project()
  project === nothing ? String[] : [project, something(Base.project_file_manifest_path(project), "")]
end
environment_hash() = content_hash(environment_files())

# The package root the active environment resolves now, and the root actually loaded.
function resolved_root(name)
  id = Base.identify_package(name)
  id === nothing && error("the active environment does not provide $name")
  path = Base.locate_package(id)
  path === nothing && error("cannot locate $name in the active environment")
  id, realpath(dirname(dirname(path)))
end
function before_loading(name)
  id, root = resolved_root(name)
  preloaded = Base.root_module_exists(id)
  preloaded && (root = realpath(dirname(dirname(pathof(Base.root_module(id))))))
  (; id, root, preloaded, state = package_state(root))
end
in_depot(root) = any(d -> startswith(root, joinpath(realpath(joinpath(d, "packages")), "")),
                     filter(d -> isdir(joinpath(d, "packages")), DEPOT_PATH))

const HARNESS_FILES = ("problems.jl", "certificates.jl", "cases.jl", "run.jl")
const PRE = (local_hash = local_hash(), environment = environment_hash(),
             harness = content_hash([joinpath(@__DIR__, f) for f in HARNESS_FILES]),
             solvers = before_loading("ProximalSolvers"), base = before_loading("ProximalBase"))

include(joinpath(@__DIR__, "run.jl"))

const LOCAL_FORMAT = "proximalsolvers-local-exploratory-v1"
const LOCAL_HEADER = ("id", "phase", "status", "construct_s", "first_call_s", "samples",
  "median_ns", "min_ns", "max_ns", "median_bytes", "measure", "target", "worst_value",
  "diagnostics", "data_hash")
# Unchanged code repeated within about ±7–9% per quick case on a shared node (#110).
const NOISE_NOTE = 0.10

harness_hash() = fingerprint(@__DIR__, [joinpath(@__DIR__, name) for name in HARNESS_FILES])
package_root() = realpath(dirname(dirname(pathof(ProximalSolvers))))
source_hashes(root = package_root()) = package_state(root).sources

# A package's loaded code is known to match `state` when this file loaded it from files
# that did not change while it loaded, or, for ProximalBase, when it is a registered
# (content-addressed, read-only) depot copy. A package loaded earlier in the session, or
# an edit during loading, leaves the loaded code unknown, so runs are refused until a
# restart, even with Revise.
function after_loading(pre, mod)
  root = realpath(dirname(dirname(pathof(mod))))
  state = package_state(root)
  loaded_here = !pre.preloaded && root == pre.root && state.fingerprint == pre.state.fingerprint
  (; pre.id, root, state = loaded_here ? state : pre.state, preloaded = pre.preloaded,
     trusted = loaded_here || (mod === ProximalBase && in_depot(root)))
end

const LOADED = let unchanged = PRE.local_hash == local_hash() && PRE.environment == environment_hash() &&
    PRE.harness == content_hash([joinpath(@__DIR__, f) for f in HARNESS_FILES])
  # A file changed while loading: keep values that the next check will reject.
  (local_hash = unchanged ? PRE.local_hash : "changed while loading",
   harness = unchanged ? harness_hash() : "changed while loading",
   environment = PRE.environment, solvers = after_loading(PRE.solvers, ProximalSolvers),
   base = after_loading(PRE.base, ProximalBase))
end

# Source versions applied to the loaded methods. They are exact because runs require
# that this file loaded ProximalSolvers (`trusted`).
const APPLIED = Ref(LOADED.solvers.state.sources)
# Set when a file of the loaded package disappears. Revise removes a missing file's
# methods only later (after a grace period, and possibly after the file returns), so
# the loaded methods stay unknown until a restart.
const DELETED = Ref{Union{Nothing,String}}(nothing)
# How this process runs cases; ratios across modes are not like for like.
const EXECUTION = Ref("REPL")

# Solver work counters read from a returned result after timing (never inside it).
const COUNTERS = (:iterations, :passes, :outer_iterations, :inner_iterations, :stages,
                  :f_calls, :grad_calls, :prox_calls, :backtrack_steps, :kkt_checks,
                  :kkt_repairs)

function diagnostics(output)
  parts = String[]
  for name in COUNTERS
    hasproperty(output, name) || continue
    value = getproperty(output, name)
    value isa Integer && push!(parts, "$name=$value")
    value isa AbstractVector{<:Integer} && push!(parts, "$name=$(sum(value))")
  end
  join(parts, ' ')
end

function tracking_revise()
  isdefined(Main, :Revise) || return nothing
  revise = getfield(Main, :Revise)
  isdefined(revise, :pkgdatas) && haskey(revise.pkgdatas, Base.PkgId(ProximalSolvers)) ?
    revise : nothing
end

const RESTART = "restart Julia (or the session)"

"""
Refuse to time an implementation that may differ from the files on disk, and return the
verified ProximalSolvers and ProximalBase fingerprints that label the run.

local.jl, the harness, the active project and manifest, the resolved package paths,
ProximalSolvers' Project.toml and ProximalBase's sources must be as loaded, and this file
must have loaded ProximalSolvers. Without Revise, its files must be unchanged since. With
Revise tracking ProximalSolvers, queued edits are applied, and then every tracked file
whose content differs from the last applied version is revised directly: Revise learns
of edits from asynchronous file events, which can arrive after a run that starts right
after a save. A deleted file, a failed revision, or a changed file Revise does not track
requires a restart.
"""
function check_current_source(loaded = LOADED, revise = tracking_revise())
  DELETED[] === nothing || error("$(DELETED[]) was deleted after ProximalSolvers was " *
    "loaded, so the loaded methods are unknown even if it is restored; $RESTART")
  local_hash() == loaded.local_hash ||
    error("benchmark/local.jl changed since it was loaded; $RESTART, or include local.jl again in a REPL")
  harness_hash() == loaded.harness ||
    error("benchmark harness files changed since local.jl was loaded; $RESTART, or include local.jl again in a REPL")
  environment_hash() == loaded.environment ||
    error("the active project or manifest changed since local.jl was loaded; $RESTART")
  for pkg in (loaded.solvers, loaded.base)
    last(resolved_root(pkg.id.name)) == pkg.root ||
      error("the environment now resolves $(pkg.id.name) to a different path than the loaded one; $RESTART")
  end
  loaded.base.trusted || error("ProximalBase at $(loaded.base.root) was loaded before local.jl " *
    "from a development path, so its loaded code cannot be matched to its files; $RESTART " *
    "and include local.jl before loading ProximalBase")
  base = package_state(loaded.base.root)
  base.fingerprint == loaded.base.state.fingerprint ||
    error("ProximalBase files changed since it was loaded; $RESTART")
  solvers = loaded.solvers
  state = package_state(solvers.root)
  state.project == solvers.state.project ||
    error("ProximalSolvers Project.toml changed since it was loaded; $RESTART")
  solvers.trusted || error("ProximalSolvers was loaded before local.jl, so the loaded methods " *
    "cannot be matched to its files, even with Revise; $RESTART and include local.jl before " *
    "loading ProximalSolvers (load Revise first to apply edits)")
  if revise === nothing
    state.fingerprint == solvers.state.fingerprint ||
      error("ProximalSolvers source changed since it was loaded and Revise is not tracking " *
            "it; $RESTART, or load Revise before ProximalSolvers")
    return (; mode = "static", solvers = state.fingerprint, base = base.fingerprint)
  end
  gone = sort!(collect(setdiff(keys(APPLIED[]), keys(state.sources))))
  if !isempty(gone)
    DELETED[] = join(gone, ", ")
    error("$(DELETED[]) was deleted after ProximalSolvers was loaded, and Revise may still " *
          "run its methods; $RESTART")
  end
  isdefined(revise, :revise_file_now) && isdefined(revise, :srcfiles) &&
    isdefined(revise, :queue_errors) ||
    error("this Revise version lacks revise_file_now; restart Julia after each edit")
  root, current = solvers.root, state.sources
  try
    revise.revise(; throw = true)
    data = revise.pkgdatas[solvers.id]
    files = Dict((isabspath(f) ? relpath(f, root) : f) => f for f in revise.srcfiles(data))
    for (file, hash) in sort!(collect(current))
      get(APPLIED[], file, nothing) == hash && continue
      if haskey(files, file)
        revise.revise_file_now(data, files[file])
      elseif haskey(APPLIED[], file)
        error("$file changed but Revise does not track it")
      end   # a new file that no tracked file includes is not part of the package
    end
  catch err
    error("could not apply ProximalSolvers edits with Revise; restart Julia " *
          "(e.g. after changing a struct): $(sprint(showerror, err))")
  end
  isempty(revise.queue_errors) ||
    error("Revise reports unapplied edits; fix them or restart Julia")
  # A save while edits were applied could leave methods from either version.
  package_state(root).fingerprint == state.fingerprint ||
    error("ProximalSolvers files changed while edits were applied; run the command again")
  APPLIED[] = current
  (; mode = "revise", solvers = state.fingerprint, base = base.fingerprint)
end

function explore_case(spec, rep, samples, seconds, case_seconds, minimum_samples; io = stdout)
  meta = spec.meta
  outputs = Any[nothing, nothing]   # first and last certified outputs
  started = time()
  state = try
    spec.make(rep)
  catch err
    println(io, "CHECK ", meta.id, " status=error (construction)")
    return (; id = meta.id, phase = meta.phase, status = :error, construct_s = time() - started,
            first_call_s = NaN, samples = 0, median_ns = nothing, min_ns = nothing,
            max_ns = nothing, median_bytes = nothing, measure = meta.measure,
            target = meta.target, worst_value = NaN, repeatable = true, diagnostics = "",
            data_hash = "", failure = "construction: " * sprint(showerror, err))
  end
  construct = time() - started
  # Wrap only certification, which observe! runs after the timed call.
  certify = function (output)
    outputs[1] === nothing && (outputs[1] = output)
    outputs[2] = output
    state.certify(output)
  end
  probe = CaseState(state.reset!, state.call!, certify, state.problem_hash)
  observations = NamedTuple[]
  validation = observe!(probe, meta, Inf)
  push!(observations, validation)
  # A failed certificate is final (aggregate_status cannot return to ok), so no further
  # call is made after it; only an ok but slow validation is rechecked for a timeout.
  if validation.status == :ok && validation.time_ns !== nothing &&
      validation.time_ns / 1e9 > case_seconds
    validation = observe!(probe, meta, case_seconds)
    push!(observations, validation)
  end
  println(io, "CHECK ", meta.id, " status=", validation.status, " ", meta.measure, "=",
          isfinite(validation.value) ? @sprintf("%.3g", validation.value) : "NaN",
          isfinite(meta.target) ? @sprintf(" target=%.3g", meta.target) : " target=record")
  flush(io)
  first_diagnostics = outputs[1] === nothing ? "" : diagnostics(outputs[1])
  rows = NamedTuple[]
  if validation.status == :ok
    timed = 0.0
    while length(rows) < min(minimum_samples, samples) ||
        (length(rows) < samples && timed < seconds)
      row = observe!(probe, meta, case_seconds)
      push!(rows, row)
      push!(observations, row)
      row.time_ns === nothing || (timed += row.time_ns / 1e9)
      row.status == :ok || break
    end
  end
  status = aggregate_status([r.status for r in observations])
  failure = status == :ok ? nothing : first(r for r in observations if r.status == status)
  last_diagnostics = outputs[2] === nothing ? "" : diagnostics(outputs[2])
  values = [r.value for r in observations if isfinite(r.value)]
  # A failed case reports no timing: the ok samples before a failure are not a timing of it.
  ok = status == :ok ? rows : NamedTuple[]
  times = [Int(r.time_ns) for r in ok]
  (; id = meta.id, phase = meta.phase, status, construct_s = construct,
     first_call_s = observations[1].time_ns === nothing ? NaN : observations[1].time_ns / 1e9,
     samples = length(rows),
     median_ns = isempty(times) ? nothing : round(Int, median(times)),
     min_ns = isempty(times) ? nothing : minimum(times),
     max_ns = isempty(times) ? nothing : maximum(times),
     median_bytes = isempty(ok) ? nothing : round(Int, median([r.bytes for r in ok])),
     measure = meta.measure, target = meta.target,
     worst_value = isempty(values) ? NaN : maximum(values),
     repeatable = length(unique(values)) <= 1 && first_diagnostics == last_diagnostics,
     diagnostics = last_diagnostics, data_hash = state.problem_hash,
     failure = failure === nothing ? "" : failure.detail)
end

# `verified` is what check_current_source established as loaded; the fingerprints come
# from it, not from a later read of files that may have changed since.
function environment(verified = check_current_source())
  root = LOADED.solvers.root
  revision, dirty = git_identity(root)
  Dict{String,Any}("format" => LOCAL_FORMAT, "julia" => string(VERSION),
    "cpu_model" => Sys.cpu_info()[1].model, "julia_threads" => Threads.nthreads(),
    "blas_threads" => BLAS.get_num_threads(), "harness_hash" => LOADED.harness,
    "local_hash" => LOADED.local_hash, "environment_hash" => LOADED.environment,
    "source_check" => verified.mode, "execution" => EXECUTION[],
    "proximalsolvers_path" => root, "proximalsolvers_sha" => revision,
    "proximalsolvers_dirty" => dirty, "proximalsolvers_hash" => verified.solvers,
    "proximalbase_version" => string(pkgversion(ProximalBase)),
    "proximalbase_hash" => verified.base,
    "load_average" => round(Sys.loadavg()[1]; digits = 2), "cpu_threads" => Sys.CPU_THREADS)
end

function format_time(ns)
  ns === nothing && return "-"
  ns < 1e3 ? @sprintf("%dns", ns) : ns < 1e6 ? @sprintf("%.1fµs", ns / 1e3) :
    ns < 1e9 ? @sprintf("%.2fms", ns / 1e6) : @sprintf("%.2fs", ns / 1e9)
end

function format_bytes(b)
  b === nothing && return "-"
  b < 1024 ? "$(b)B" : b < 1024^2 ? @sprintf("%.1fKiB", b / 1024) : @sprintf("%.1fMiB", b / 1024^2)
end

function save_local(path, env, results)
  ispath(path) && error("refusing to overwrite $path")
  open(path, "w") do io
    println(io, "# Exploratory local results: not a formal benchmark record (#110 Stage 1).")
    for key in sort!(collect(keys(env)))
      println(io, "# ", key, "=", env[key])
    end
    tsv_line(io, LOCAL_HEADER...)
    for r in results
      tsv_line(io, (getproperty(r, Symbol(field)) for field in LOCAL_HEADER)...)
    end
  end
end

function load_local(path)
  env, rows, header = Dict{String,String}(), Dict{String,Dict{String,String}}(), String[]
  for line in eachline(path)
    if startswith(line, "# ") && occursin('=', line)
      key, value = split(line[3:end], '='; limit = 2)
      env[key] = value
    elseif !startswith(line, "#")
      fields = split(line, '\t')
      if isempty(header)
        header = fields
      else
        row = Dict(zip(header, fields))
        haskey(row, "id") && (rows[row["id"]] = row)
      end
    end
  end
  get(env, "format", "") == LOCAL_FORMAT || error("$path is not a local exploratory result")
  env, rows
end

baseline_data(path::AbstractString) = load_local(path)
function baseline_data(results::AbstractVector)
  isempty(results) && throw(ArgumentError("empty baseline"))
  rows = Dict(r.id => Dict(string(f) => (v === nothing ? "" : tsv_field(v))
    for (f, v) in pairs(r) if f != :environment) for r in results)
  Dict{String,String}(k => string(v) for (k, v) in first(results).environment), rows
end

"""
Compare with a baseline from an earlier local run and return `(ratio, note, baseline
median ns)`. A ratio is withheld (`nothing`) when the workload, harness, local runner,
environment or machine differs, or a saved time is not a positive integer number of
nanoseconds; otherwise it is an exploratory observation.
"""
function baseline_ratio(result, base_env, base_rows, env)
  row = get(base_rows, result.id, nothing)
  withheld(why) = (nothing, why, nothing)
  row === nothing && return withheld("no baseline for this case")
  for key in ("julia", "cpu_model", "julia_threads", "blas_threads", "harness_hash",
              "local_hash", "environment_hash", "proximalbase_hash")
    get(base_env, key, "") == string(env[key]) || return withheld("baseline $key differs")
  end
  get(row, "data_hash", "") == result.data_hash || return withheld("baseline data_hash differs")
  get(row, "status", "") == "ok" || return withheld("baseline status $(get(row, "status", "?"))")
  result.status == :ok || return withheld("candidate status $(result.status)")
  # Saved times are positive integer nanoseconds; any other value is corrupt.
  nanoseconds(x) = (n = x isa Integer ? x : tryparse(Int, x); n !== nothing && n > 0 ? Int(n) : nothing)
  base = nanoseconds(get(row, "median_ns", ""))
  base === nothing && return withheld("baseline median invalid or unavailable")
  candidate = something(result.median_ns, 0)
  nanoseconds(candidate) === nothing && return withheld("candidate median unavailable")
  ratio = candidate / base
  # Interference from other processes inflates medians more than minima.
  base_min, candidate_min = nanoseconds(get(row, "min_ns", "")), nanoseconds(something(result.min_ns, 0))
  low = base_min === nothing || candidate_min === nothing ? nothing : candidate_min / base_min
  note = low === nothing ? "" : @sprintf("min ratio %.3f; ", low)
  mode = get(base_env, "execution", "")
  mode == env["execution"] ||
    (note *= "baseline ran as $(isempty(mode) ? "unknown" : mode), candidate as $(env["execution"]): not like for like; ")
  note *= low !== nothing && abs(log(ratio / low)) >= NOISE_NOTE ?
    "median and minimum ratios disagree (interference?); rerun on a quieter machine" :
    abs(log(ratio)) < NOISE_NOTE ? "inside the ~10% spread of unchanged code; not evidence of a change" :
    ratio < 1 ? "apparent speedup; confirm with compare.py before claiming it" :
    "apparent slowdown; investigate"
  (ratio, note, base)
end

function report(io, env, results; baseline = nothing)
  println(io, "\nEXPLORATORY local result: not a formal or statistical comparison (#110 Stage 1)")
  println(io, "julia ", env["julia"], " | ", env["cpu_model"], " | threads julia=",
          env["julia_threads"], " blas=", env["blas_threads"], " | load ", env["load_average"],
          " on ", env["cpu_threads"], " CPU threads")
  env["load_average"] > env["cpu_threads"] / 2 &&
    println(io, "WARNING: the machine is busy; timings and ratios are unreliable")
  println(io, "ProximalSolvers ", first(env["proximalsolvers_sha"], 10),
          env["proximalsolvers_dirty"] ? "+dirty" : "", " src=",
          first(env["proximalsolvers_hash"], 10), " at ", env["proximalsolvers_path"])
  println(io, "ProximalBase ", env["proximalbase_version"], " | harness ",
          first(env["harness_hash"], 10), " | local.jl ", first(env["local_hash"], 10),
          " | source check ", env["source_check"], " | ", env["execution"])
  base = baseline === nothing ? nothing : baseline_data(baseline)
  if base !== nothing
    println(io, "baseline: ProximalSolvers ", first(get(base[1], "proximalsolvers_sha", "?"), 10),
            get(base[1], "proximalsolvers_dirty", "") == "true" ? "+dirty" : "",
            " src=", first(get(base[1], "proximalsolvers_hash", "?"), 10))
  end
  @printf(io, "%-44s %-13s %9s %10s %10s %4s %9s %s\n", "case", "status", "first",
          "median", "min", "n", "alloc", "certificate")
  for r in results
    cert = @sprintf("%s %.2g", r.measure, r.worst_value) *
      (isfinite(r.target) ? @sprintf(" <= %.0e", r.target) : " (record)")
    @printf(io, "%-44s %-13s %9s %10s %10s %4d %9s %s\n", r.id, r.status,
            format_time(isfinite(r.first_call_s) ? round(Int, r.first_call_s * 1e9) : nothing),
            format_time(r.median_ns), format_time(r.min_ns), r.samples,
            format_bytes(r.median_bytes), cert)
    isempty(r.diagnostics) || println(io, "    work: ", r.diagnostics)
    r.phase == "workspace" && println(io, "    phase: warm solve! on a reused workspace; construction and reset excluded")
    r.phase == "setup" && println(io, "    phase: setup only (cache/factorization construction), no solve")
    if r.status != :ok
      detail = isempty(r.failure) ? @sprintf("certified %s %.3g vs target %.3g", r.measure,
        r.worst_value, r.target) : r.failure
      println(io, "    FAILURE (", r.status, "): ", detail, "; no timing reported")
    end
    r.repeatable || println(io, "    WARNING: outputs differ between calls; check reset!/state")
    if r.median_ns !== nothing && r.samples >= 2 && r.median_ns > 1.1 * r.min_ns
      println(io, "    note: noisy, median ", @sprintf("%.0f%%", 100 * (r.median_ns / r.min_ns - 1)),
              " above min")
    end
    if base !== nothing
      ratio, note, base_ns = baseline_ratio(r, base..., env)
      if ratio === nothing
        println(io, "    vs baseline: no ratio (", note, ")")
      else
        saved = base_ns - r.median_ns   # both positive Int, so no overflow
        println(io, "    vs baseline: ratio ", @sprintf("%.3f", ratio), " (",
                format_time(base_ns), " -> ", format_time(r.median_ns),
                ", apparent ", saved >= 0 ? "saving " : "cost ", format_time(abs(saved)),
                " per call); ", note)
      end
    end
  end
  println(io, "first = first certified call, including compilation (excluded from median).")
  println(io, "Ratios are single exploratory observations; use compare.py (README) for claims.")
end

"""
    explore(patterns...; rep=1, samples=25, seconds=0.5, case_seconds=60,
            minimum_samples=3, baseline=nothing, save=nothing, io=stdout)

Run the cases matching `patterns` (exact IDs, or `*` wildcards; see `select_cases`) and
return one NamedTuple per case. `baseline` is a saved local TSV or an earlier result.
"""
function explore(patterns::AbstractString...; rep::Integer = 1, samples::Integer = 25,
                 seconds::Real = 0.5, case_seconds::Real = 60, minimum_samples::Integer = 3,
                 baseline = nothing, save = nothing, io::IO = stdout)
  isempty(patterns) && throw(ArgumentError("name at least one case pattern"))
  1 <= rep <= 10 || throw(ArgumentError("rep must be between 1 and 10"))
  samples >= 1 && minimum_samples >= 1 && seconds > 0 && case_seconds > 0 ||
    throw(ArgumentError("samples, minimum_samples and time limits must be positive"))
  save === nothing || !ispath(save) || throw(ArgumentError("refusing to overwrite $save"))
  verified = check_current_source()
  # A revision defines methods in a newer world than this call's; run in the latest
  # world, or the timed code would be the implementation from before the edit.
  Base.invokelatest(explore_selected, patterns, rep, samples, seconds, case_seconds,
                    minimum_samples, baseline, save, io, verified)
end

function explore_selected(patterns, rep, samples, seconds, case_seconds, minimum_samples,
                          baseline, save, io, verified)
  Threads.nthreads() == 1 || @warn "timings with $(Threads.nthreads()) Julia threads; the formal runner requires one"
  BLAS.set_num_threads(1)
  # A deferred case is refused with the capabilities it lacks (cases.jl), never run.
  check_deferred_request(join(patterns, ','), "extended", collect(CASE_GROUPS))
  selected = select_cases(build_catalog("extended", collect(CASE_GROUPS)), join(patterns, ','))
  env = environment(verified)   # the source applied for these runs
  results = [merge(explore_case(spec, rep, samples, seconds, case_seconds, minimum_samples; io),
                   (; environment = env)) for spec in selected]
  report(io, env, results; baseline)
  save === nothing || save_local(save, env, results)
  results
end

function list_cases(io, patterns)
  catalog = build_catalog("extended", collect(CASE_GROUPS))
  isempty(patterns) || (catalog = select_cases(catalog, join(patterns, ',')))
  for spec in catalog
    tsv_line(io, spec.meta.id, spec.meta.suite, spec.meta.issue)
  end
end

const USAGE = """
usage: julia --project=ENV benchmark/local.jl [options] CASE_PATTERN...
  CASE_PATTERN   exact case ID or pattern with * (any characters); comma lists allowed
  --list         print matching case IDs (all cases without a pattern), then exit
  --samples N    maximum timed samples per case (default 25)
  --seconds S    stop sampling after S timed seconds, after the minimum (default 0.5)
  --min N        minimum timed samples (default 3)
  --rep R        input draw, 1-10 (default 1)
  --save FILE    write an exploratory TSV (refuses to overwrite)
  --baseline FILE  report candidate/baseline median ratios against a saved TSV
  --session      keep Julia running: read one command per stdin line (the options and
                 patterns above, space-separated, unquoted), apply source edits with
                 Revise, and print LOCAL_DONE status=N after each; "exit" stops
Exit status: 0 all cases ok, 2 some case not ok, 3 usage or startup error."""

"""
Read commands from `input`, one per line, and run each as `cli` would, applying source
edits with Revise between commands. Each command ends with a `LOCAL_DONE status=N` line.
"""
function session(input::IO = stdin, io::IO = stdout)
  println(io, "LOCAL_SESSION ready; Revise ", tracking_revise() === nothing ?
          "is not tracking: edits need a restart" : "tracks ProximalSolvers")
  flush(io)
  for line in eachline(input)
    args = split(strip(line))
    isempty(args) && continue
    first(args) in ("exit", "quit") && break
    code = "--session" in args ? (println(stderr, "LOCAL_FAILURE nested --session"); 3) :
      Base.invokelatest(cli, String.(args))
    println(io, "LOCAL_DONE status=", code)
    flush(io)
  end
  0
end

function cli(args)
  try
    options = Dict{String,String}()
    patterns, list = String[], false
    i = 1
    while i <= length(args)
      arg = args[i]
      if arg == "--session"
        return session()
      elseif arg == "--list"
        list = true
      elseif arg in ("--samples", "--seconds", "--min", "--rep", "--save", "--baseline")
        i < length(args) || error("$arg needs a value")
        options[arg] = args[i += 1]
      elseif arg in ("-h", "--help")
        println(USAGE)
        return 0
      elseif startswith(arg, "--")
        error("unknown option $arg")
      else
        push!(patterns, arg)
      end
      i += 1
    end
    if list
      list_cases(stdout, patterns)
      return 0
    end
    results = explore(patterns...;
      samples = parse(Int, get(options, "--samples", "25")),
      seconds = parse(Float64, get(options, "--seconds", "0.5")),
      minimum_samples = parse(Int, get(options, "--min", "3")),
      rep = parse(Int, get(options, "--rep", "1")),
      save = get(options, "--save", nothing), baseline = get(options, "--baseline", nothing))
    all(r -> r.status == :ok, results) ? 0 : 2
  catch err
    println(stderr, "LOCAL_FAILURE ", sprint(showerror, err))
    println(stderr, USAGE)
    3
  end
end

end # module PSLocal

explore(args...; kwargs...) = PSLocal.explore(args...; kwargs...)

if abspath(PROGRAM_FILE) == @__FILE__
  PSLocal.EXECUTION[] = "--session" in ARGS ? "session" : "fresh process"
  exit(PSLocal.cli(ARGS))
end
