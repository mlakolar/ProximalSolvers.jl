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

include(joinpath(@__DIR__, "run.jl"))

const LOCAL_FORMAT = "proximalsolvers-local-exploratory-v1"
const LOCAL_HEADER = ("id", "phase", "status", "construct_s", "first_call_s", "samples",
  "median_ns", "min_ns", "max_ns", "median_bytes", "measure", "target", "worst_value",
  "diagnostics", "data_hash")
const HARNESS_FILES = ("problems.jl", "certificates.jl", "cases.jl", "run.jl")
# Unchanged code repeated within about ±7–9% per quick case on a shared node (#110).
const NOISE_NOTE = 0.10

harness_hash() = fingerprint(@__DIR__, [joinpath(@__DIR__, name) for name in HARNESS_FILES])
package_root() = realpath(dirname(dirname(pathof(ProximalSolvers))))

# Package sources (as in package_fingerprint) and their hashes when last known loaded.
function source_hashes(root = package_root())
  hashes = Dict{String,String}()
  for directory in ("src", "ext")
    path = joinpath(root, directory)
    isdir(path) || continue
    for (folder, _, names) in walkdir(path), name in names
      endswith(name, ".jl") || continue
      file = joinpath(folder, name)
      hashes[relpath(file, root)] = bytes2hex(sha1(read(file)))
    end
  end
  hashes
end

const LOADED = (harness = harness_hash(), source = package_fingerprint(package_root()))
# Files changed after the loaded package cache was written may differ from the loaded
# code (an edit saved between loading ProximalSolvers and including this file), so the
# first run with Revise applies them. Without a cache, it applies every tracked file.
function loaded_hashes(root = package_root())
  origin = get(Base.pkgorigins, Base.PkgId(ProximalSolvers), nothing)
  cache = origin === nothing ? nothing : origin.cachepath
  (cache === nothing || !isfile(cache)) && return Dict{String,String}()
  built = mtime(cache)
  filter(entry -> mtime(joinpath(root, first(entry))) < built, source_hashes(root))
end

const APPLIED = Ref(loaded_hashes())

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

"""
Refuse to time an implementation that may differ from the source on disk.

With Revise tracking ProximalSolvers, queued edits are applied, and then every tracked
file whose content differs from the last applied version is revised directly: Revise
learns of edits from asynchronous file events, which can arrive after a run that
starts right after a save. A failed revision, or a changed file Revise does not track,
requires a restart. Without Revise, any source change since loading requires a restart.
"""
function check_current_source()
  harness_hash() == LOADED.harness ||
    error("benchmark harness files changed since local.jl was loaded; restart, or " *
          "include local.jl again in a REPL")
  revise = isdefined(Main, :Revise) ? getfield(Main, :Revise) : nothing
  id = Base.PkgId(ProximalSolvers)
  tracked = revise !== nothing && isdefined(revise, :pkgdatas) && haskey(revise.pkgdatas, id)
  if !tracked
    package_fingerprint(package_root()) == LOADED.source ||
      error("ProximalSolvers source changed since it was loaded and Revise is not tracking " *
            "it; restart Julia, or load Revise before ProximalSolvers")
    return :static
  end
  isdefined(revise, :revise_file_now) && isdefined(revise, :srcfiles) ||
    error("this Revise version lacks revise_file_now; restart Julia after each edit")
  root = package_root()
  current = source_hashes(root)
  try
    revise.revise(; throw = true)
    data = revise.pkgdatas[id]
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
  APPLIED[] = current   # a file saved during this loop is applied by the next run
  :revise
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
  if validation.status != :error && validation.time_ns !== nothing &&
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
  if !(validation.status in (:error, :timeout))
    timed = 0.0
    while length(rows) < min(minimum_samples, samples) ||
        (length(rows) < samples && timed < seconds)
      row = observe!(probe, meta, case_seconds)
      push!(rows, row)
      push!(observations, row)
      row.time_ns === nothing || (timed += row.time_ns / 1e9)
      row.status in (:error, :timeout) && break
    end
  end
  status = aggregate_status([r.status for r in observations])
  failure = status == :ok ? nothing : first(r for r in observations if r.status == status)
  last_diagnostics = outputs[2] === nothing ? "" : diagnostics(outputs[2])
  values = [r.value for r in observations if isfinite(r.value)]
  ok = [r for r in rows if r.status == :ok]
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

function environment()
  root = package_root()
  revision, dirty = git_identity(root)
  base_root = realpath(dirname(dirname(pathof(ProximalBase))))
  Dict{String,Any}("format" => LOCAL_FORMAT, "julia" => string(VERSION),
    "cpu_model" => Sys.cpu_info()[1].model, "julia_threads" => Threads.nthreads(),
    "blas_threads" => BLAS.get_num_threads(), "harness_hash" => harness_hash(),
    "proximalsolvers_path" => root, "proximalsolvers_sha" => revision,
    "proximalsolvers_dirty" => dirty, "proximalsolvers_hash" => package_fingerprint(root),
    "proximalbase_version" => string(pkgversion(ProximalBase)),
    "proximalbase_hash" => package_fingerprint(base_root),
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
Compare with a baseline from an earlier local run. A ratio is withheld when the
workload, harness or machine differs; otherwise it is an exploratory observation.
"""
function baseline_ratio(result, base_env, base_rows, env)
  row = get(base_rows, result.id, nothing)
  row === nothing && return (nothing, "no baseline for this case")
  for key in ("julia", "cpu_model", "julia_threads", "blas_threads", "harness_hash",
              "proximalbase_hash")
    get(base_env, key, "") == string(env[key]) || return (nothing, "baseline $key differs")
  end
  get(row, "data_hash", "") == result.data_hash || return (nothing, "baseline data_hash differs")
  get(row, "status", "") == "ok" || return (nothing, "baseline status $(get(row, "status", "?"))")
  result.status == :ok || return (nothing, "candidate status $(result.status)")
  base = tryparse(Float64, get(row, "median_ns", ""))
  (base === nothing || base <= 0) && return (nothing, "baseline median unavailable")
  ratio = result.median_ns / base
  # Interference from other processes inflates medians more than minima.
  base_min = tryparse(Float64, get(row, "min_ns", ""))
  low = base_min === nothing || base_min <= 0 || result.min_ns === nothing ? nothing :
    result.min_ns / base_min
  note = low === nothing ? "" : @sprintf("min ratio %.3f; ", low)
  note *= low !== nothing && abs(log(ratio / low)) >= NOISE_NOTE ?
    "median and minimum ratios disagree (interference?); rerun on a quieter machine" :
    abs(log(ratio)) < NOISE_NOTE ? "inside the ~10% spread of unchanged code; not evidence of a change" :
    ratio < 1 ? "apparent speedup; confirm with compare.py before claiming it" :
    "apparent slowdown; investigate"
  (ratio, note)
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
          first(env["harness_hash"], 10))
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
      ratio, note = baseline_ratio(r, base..., env)
      if ratio === nothing
        println(io, "    vs baseline: no ratio (", note, ")")
      else
        saved = (1 - ratio) * r.median_ns / ratio
        println(io, "    vs baseline: ratio ", @sprintf("%.3f", ratio), " (",
                format_time(round(Int, r.median_ns / ratio)), " -> ", format_time(r.median_ns),
                ", apparent ", saved >= 0 ? "saving " : "cost ", format_time(round(Int, abs(saved))),
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
  check_current_source()
  # A revision defines methods in a newer world than this call's; run in the latest
  # world, or the timed code would be the implementation from before the edit.
  Base.invokelatest(explore_selected, patterns, rep, samples, seconds, case_seconds,
                    minimum_samples, baseline, save, io)
end

function explore_selected(patterns, rep, samples, seconds, case_seconds, minimum_samples,
                          baseline, save, io)
  Threads.nthreads() == 1 || @warn "timings with $(Threads.nthreads()) Julia threads; the formal runner requires one"
  BLAS.set_num_threads(1)
  selected = select_cases(build_catalog("extended", collect(CASE_GROUPS)), join(patterns, ','))
  env = environment()   # the source applied for these runs
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
  revise = isdefined(Main, :Revise) && haskey(getfield(Main, :Revise).pkgdatas,
                                               Base.PkgId(ProximalSolvers))
  println(io, "LOCAL_SESSION ready; Revise ", revise ? "tracks ProximalSolvers" :
          "is not tracking: edits need a restart")
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
  exit(PSLocal.cli(ARGS))
end
