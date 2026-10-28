include("common.jl")

# Usage: run.jl SIDE ARTIFACT OUTPUT REPETITION [--view defaults|ladder|frozen]
#   [--frozen FILE] [--target 1e-4] [--fixtures] [--suite quick|extended]
#   [--cases ID,...] [--list] [--gram-off]
# Frozen selections use [[selection]] with id, side, target, family and setting_index
# (one-based in ladder followed by gap_ladder). Missing family means coordinate.
# Frozen runs execute the union across families at the single matched target.
# Defaults have setting_index=0. IDs in #116 records
# append /call; rungs append -settingNN to the order component. case_id retains the catalog ID.
# The exact #116 catalog is accompanied by external/<process>-catalog.tsv with added columns.
# Keeping companions in a subdirectory avoids #116's top-level process-prefix discovery.

function runner_settings(args)
  length(args) >= 4 || error("usage: run.jl SIDE ARTIFACT OUTPUT REPETITION [options]")
  side, input, output, repetition = args[1:4]
  side in ("legacy", "current", "current-AA") || error("unknown side")
  rep = parse(Int, repetition)
  1 <= rep <= 99 || error("repetition must be between 1 and 99")
  view, frozen, target, fixtures, listing, gram_off = "defaults", "", 1e-4, false, false, false
  selected = get(ENV, "PS_CASES", "")
  suite = get(ENV, "PS_SUITE", "quick")
  i = 5
  while i <= length(args)
    key = args[i]
    if key in ("--view", "--frozen", "--target", "--cases", "--suite")
      i += 1
      i <= length(args) || error("$key needs a value")
      value = args[i]
      key == "--view" && (view = value)
      key == "--frozen" && (frozen = abspath(value))
      key == "--target" && (target = parse(Float64, value))
      key == "--cases" && (selected = value)
      key == "--suite" && (suite = value)
    elseif key == "--fixtures"
      fixtures = true
    elseif key == "--list"
      listing = true
    elseif key == "--gram-off"
      gram_off = true
    else
      error("unknown option $key")
    end
    i += 1
  end
  view in ("defaults", "ladder", "frozen") || error("unknown view")
  view == "frozen" && !isfile(frozen) && error("--view frozen requires --frozen FILE")
  target == 1e-4 || error("target must be 1e-4")
  gram_off && side == "legacy" && error("--gram-off applies only to current")
  samples = parse(Int, get(ENV, "PS_SAMPLES", suite == "quick" ? "50" : "100"))
  seconds = parse(Float64, get(ENV, "PS_SECONDS", suite == "quick" ? "1" : "3"))
  case_seconds = parse(Float64, get(ENV, "PS_CASE_SECONDS", "120"))
  samples > 0 && isfinite(seconds) && seconds > 0 && isfinite(case_seconds) && case_seconds > 0 ||
    error("sample and time limits must be positive")
  ids = isempty(selected) ? String[] : strip.(split(selected, ','))
  (; side, input = abspath(input), output = abspath(output), rep, view, frozen, target,
    fixtures, listing, gram_off, suite, samples, seconds, case_seconds, ids)
end

function all_rungs(case, side)
  options = case[side]
  vcat(options["ladder"], get(options, "gap_ladder", Any[]))
end

function frozen_selections(config)
  frozen = TOML.parsefile(config.frozen)
  rows = get(frozen, "selection", get(frozen, "case", Any[]))
  rows isa Vector || error("frozen file needs [[selection]] tables")
  definitions = Dict(case["id"] => case for case in read_catalog(; suite = "extended"))
  entries = Dict[]
  for row in rows
    row isa Dict || error("frozen selection entries must be tables")
    id = get(row, "id", get(row, "case_id", ""))
    haskey(definitions, id) || error("unknown frozen selection ID: $id")
    side = get(row, "side", "")
    side in ("legacy", "current") || error("unknown frozen selection side: $side; current-AA uses current entries")
    get(row, "target", config.target) == config.target || error("frozen selection target must be 1e-4 for $id/$side")
    family = get(row, "family", "coordinate")
    family in ("coordinate", "best") || error("unknown frozen selection family: $family")
    side == "legacy" && family != "coordinate" && error("legacy selections require family=coordinate")
    if get(row, "status", "selected") != "not reached"
      index = get(row, "setting_index", nothing)
      count = length(all_rungs(definitions[id], side))
      index isa Integer && !(index isa Bool) && 1 <= index <= count ||
        error("frozen setting_index $index is out of range for $id/$side (expected 1:$count)")
    end
    push!(entries, merge(row, Dict("id" => id, "family" => family, "target" => config.target)))
  end
  entries
end

function frozen_indices(rows, case, side)
  sort!(unique([row["setting_index"] for row in rows if row["id"] == case["id"] &&
    row["side"] == side && get(row, "status", "selected") != "not reached"]))
end

function selected_specs(config)
  cases = read_catalog(; suite = config.suite)
  if !isempty(config.ids)
    all(id -> any(c -> c["id"] == id, cases), config.ids) || error("unknown selected case")
    filter!(c -> c["id"] in config.ids, cases)
  end
  isempty(cases) && error("empty case selection")
  side = config.side == "legacy" ? "legacy" : "current"
  rows = config.view == "frozen" && !config.fixtures ? frozen_selections(config) : Dict[]
  specs = NamedTuple[]
  for case in cases
    rungs = all_rungs(case, side)
    indices = config.fixtures ? [length(case[side]["ladder"])] :
      config.view == "defaults" ? [0] : config.view == "ladder" ? collect(eachindex(rungs)) :
      frozen_indices(rows, case, side)
    isempty(indices) && continue
    if config.gram_off && !(case["estimator"] in ("lasso", "weighted_lasso", "path", "sqrt_lasso"))
      error("--gram-off requires cases with a public gram keyword")
    end
    for index in indices
      0 <= index <= length(rungs) || error("setting index outside catalog")
      settings = deepcopy(index == 0 ? case[side]["defaults"] : rungs[index])
      settings["case_seconds"] = config.case_seconds
      if config.fixtures
        # Coordinate change and relative gap need not have the same magnitude.
        # Fixture-only tolerances are outside the frozen calibration ladders.
        cd = get(settings, side == "legacy" ? "optionsCD" : "options_cd", settings)
        cd[side == "legacy" ? "optTol" : "opt_tol"] = 1e-13
        if case["estimator"] == "feasible_lasso"
          # Preserve the outer fixture tolerance independently of the campaign grid.
          settings[side == "legacy" ? "optTol" : "opt_tol"] = 1e-12
        end
        settings["fixture_tolerance"] = 1e-13
      end
      if config.gram_off
        settings["gram"] = false
        settings["gram_policy"] = "control-gram-disabled"
      end
      variant = case["order"] * (index == 0 ? "" : "-setting$(lpad(index, 2, '0'))") *
        (config.gram_off ? "-gram-off" : "")
      lambda = case["lambda"] == "path" ? "path" : string(case["lambda"], "lmax")
      measure = case["estimator"] == "feasible_lasso" ? "self_consistency" : "relative_gap"
      target = config.fixtures ? (measure == "self_consistency" ? 1e-8 : 1e-10) : NaN
      meta = (; id = join((case["estimator"], case["design"], lambda, variant, "call"), '/'),
        group = case["estimator"], problem = case["design"], solver = lambda, variant,
        phase = "call", suite = case["suite"], inputs = "fixed", issue = "117", measure, target,
        case_id = case["id"], estimator = case["estimator"], design = case["design"], lambda,
        order = case["order"], setting_index = index, stopping = settings["stopping"],
        family = settings["family"], gram_policy = settings["gram_policy"])
      push!(specs, (; case, settings, meta))
    end
  end
  isempty(specs) && error("no settings selected for the requested cases and side")
  specs
end

function effective_specs(config, artifact, specs)
  results = NamedTuple[]
  rows = config.view == "frozen" && !config.fixtures ? frozen_selections(config) : Dict[]
  for spec in specs
    settings = deepcopy(spec.settings)
    if config.side != "legacy" && spec.case["estimator"] == "path"
      d = artifact.designs[spec.case["design"]]
      gram = get(settings, "gram", d.n >= d.p && d.p <= 2000)
      if gram
        settings["stopping"] = "scaled-coordinate-change-auto-gram"
      elseif settings["gaptol"] == "default"
        settings["stopping"] = "relative-duality-gap-default-1e-4"
      end
    end
    if config.view == "frozen" && !config.fixtures
      side = config.side == "legacy" ? "legacy" : "current"
      for row in rows
        if row["id"] == spec.meta.case_id && row["side"] == side &&
            get(row, "status", "selected") != "not reached" && row["setting_index"] == spec.meta.setting_index
          get(row, "settings", settings) == settings || error("frozen options differ from the selected rung")
        end
      end
    end
    push!(results, (; case = spec.case, settings,
      meta = merge(spec.meta, (; stopping = settings["stopping"],
        lambda_values = artifact.cases[spec.meta.case_id]["lambda_values"]))))
  end
  results
end

function start_metadata(config, artifact, specs)
  root = realpath(PACKAGE_ROOT)
  base_root = realpath(dirname(dirname(pathof(ProximalBase))))
  revision, dirty = git_identity(root)
  env_root = dirname(Base.active_project())
  manifest_path = joinpath(env_root, "Manifest.toml")
  manifest = TOML.parsefile(manifest_path)
  manifest["julia_version"] == string(VERSION) || error("Julia differs from the locked environment")
  files = [joinpath(@__DIR__, name) for name in
    ("common.jl", "inputs.jl", "catalog.toml", "legacy.jl", "current.jl", "run.jl")]
  append!(files, [joinpath(HARNESS_ROOT, name) for name in ("problems.jl", "certificates.jl")])
  meta = Dict{String,Any}("julia" => string(VERSION), "rep" => config.rep,
    "suite" => config.suite, "groups" => join(sort!(unique([s.meta.group for s in specs])), ','),
    "harness_hash" => external_fingerprint(PACKAGE_ROOT, files), "proximalsolvers_path" => root,
    "proximalsolvers_sha" => revision, "proximalsolvers_dirty" => dirty,
    "proximalsolvers_hash" => package_fingerprint(root),
    "proximalsolvers_loaded" => config.side != "legacy",
    "proximalbase_version" => string(pkgversion(ProximalBase)),
    "proximalbase_hash" => package_fingerprint(base_root), "expected_package_root" => root,
    "julia_threads" => Threads.nthreads(), "blas_threads" => BLAS.get_num_threads(),
    "blas" => string(BLAS.get_config()), "cpu" => Sys.CPU_NAME, "cpu_model" => Sys.cpu_info()[1].model,
    "samples_target" => config.samples, "seconds_limit" => config.seconds,
    "case_seconds" => config.case_seconds, "profile_seconds" => 0.0,
    "seed_scheme" => "fixed artifact data; global RNG reset to per-case solver_seed before every observation",
    "job_id" => "none", "side" => config.side, "view" => config.fixtures ? "fixtures" : config.view,
    "artifact_sha256" => artifact.sha256, "manifest_sha256" => file_sha256(manifest_path),
    "catalog_sha256" => file_sha256(CATALOG_PATH), "fixture" => config.fixtures,
    "gram_control" => config.gram_off, "compiled_public_api" => true)
  if config.side == "legacy"
    pkgversion(LEGACY) == v"0.6.1" && pkgversion(ProximalBase) == v"0.4.1" || error("wrong legacy environment")
    meta["coordinatedescent_version"] = string(pkgversion(LEGACY))
    meta["solver_package_hash"] = package_fingerprint(dirname(dirname(pathof(LEGACY))))
  else
    pkgversion(ProximalBase) == v"0.5.4" || error("wrong current ProximalBase")
    realpath(dirname(dirname(pathof(ProximalSolvers)))) == root || error("wrong ProximalSolvers checkout")
    hdm = only(manifest["deps"]["HighDimensionalModels"])
    locked = only(TOML.parsefile(joinpath(@__DIR__, "current", "Manifest.toml"))["deps"]["HighDimensionalModels"])
    for field in ("uuid", "repo-rev", "git-tree-sha1", "repo-url")
      hdm[field] == locked[field] || error("HighDimensionalModels $field differs from the locked current manifest")
    end
    occursin(r"^[0-9a-fA-F]{40}$", hdm["repo-rev"]) || error("HighDimensionalModels must pin a commit")
    occursin(r"^[0-9a-fA-F]{40}$", hdm["git-tree-sha1"]) || error("invalid HighDimensionalModels tree hash")
    haskey(hdm, "path") && error("HighDimensionalModels must use its locked repository tree")
    # Repository trees are installed under the UUID/tree-derived depot slug.
    slug = Base.version_slug(Base.UUID(hdm["uuid"]), Base.SHA1(hdm["git-tree-sha1"]))
    loaded = realpath(pkgdir(CURRENT))
    any(Base.DEPOT_PATH) do depot
      path = joinpath(depot, "packages", "HighDimensionalModels", slug)
      isdir(path) && realpath(path) == loaded
    end || error("loaded HighDimensionalModels pkgdir differs from its manifest entry")
    meta["highdimensionalmodels_rev"] = hdm["repo-rev"]
    meta["highdimensionalmodels_tree_hash"] = hdm["git-tree-sha1"]
    meta["highdimensionalmodels_version"] = string(pkgversion(CURRENT))
    meta["solver_package_hash"] = package_fingerprint(dirname(dirname(pathof(CURRENT))))
  end
  if config.view == "frozen"
    meta["frozen_sha256"] = file_sha256(config.frozen)
    side = config.side == "legacy" ? "legacy" : "current"
    rows = filter(r -> r["side"] == side, frozen_selections(config))
    meta["accuracy_targets"] = sort!(unique([r["target"] for r in rows if haskey(r, "target")]))
    meta["not_reached"] = sort!(unique([r["id"] for r in rows if get(r, "status", "") == "not reached"]))
  end
  meta
end

function observe(spec, data, limit, cache = coefficient_certificate_cache())
  output, cert, loading_change = nothing, nothing, NaN
  ns, gc, bytes = nothing, nothing, nothing
  status, detail, stack = :ok, "", ""
  try
    # v0.6.1 src/atom_iterator.jl:71-79 uses rand(range), hence the global RNG.
    # ae44440 src/coordinate_descent.jl:138-144 and src/utils.jl:174-175 pass
    # Random.default_rng() into CDSolver; it is the same task-global seeded stream.
    # Active sets and stopping can diverge, so identical coordinate sequences are not assumed.
    Random.seed!(data.seed)
    timed = @timed run_case(spec.case, data, spec.settings)
    output = timed.value
    ns, gc, bytes = round(Int, timed.time * 1e9), round(Int, timed.gctime * 1e9), Int(timed.bytes)
    try
      result = coefficient_certificate!(cache, output) do
        certify_case(spec.case, data, output)
      end
      cert, loading_change = result.certificate, result.loadings_change
      if cert.status != :ok || !isfinite(cert.value) || cert.value < 0
        status = :uncertifiable
      else
        string(cert.measure) == spec.meta.measure || error("certificate/catalog measure mismatch")
        if isfinite(spec.meta.target) && (cert.value > spec.meta.target ||
            (spec.case["estimator"] == "feasible_lasso" && loading_change > spec.meta.target))
          status = :target_missed
        end
      end
      detail = cert.detail
    catch err
      status = err isa IncompleteExternalPath ? :incomplete : :error
      detail, stack = sprint(showerror, err), sprint(Base.show_backtrace, catch_backtrace())
    end
    if timed.time > limit && status != :error
      status, detail = :timeout, "single public-API call exceeds case_seconds after returning"
    end
  catch err
    status, detail, stack = :error, sprint(showerror, err), sprint(Base.show_backtrace, catch_backtrace())
  end
  value = cert === nothing ? NaN : cert.value
  (; time_ns = ns, gc_ns = gc, bytes, value, status, detail, stack, output, cert, loading_change)
end

function measure_case(spec, data, config)
  rows, observations = NamedTuple[], NamedTuple[]
  cache = coefficient_certificate_cache()
  validation = observe(spec, data, Inf, cache)
  push!(observations, validation)
  if validation.status != :error && validation.time_ns !== nothing &&
      validation.time_ns / 1e9 > spec.settings["case_seconds"]
    validation = observe(spec, data, spec.settings["case_seconds"], cache)
    push!(observations, validation)
  end
  if !config.fixtures && !(validation.status in (:error, :timeout))
    seconds = 0.0
    while length(rows) < 5 || (length(rows) < config.samples && seconds < config.seconds)
      row = observe(spec, data, spec.settings["case_seconds"], cache)
      push!(rows, row)
      push!(observations, row)
      row.time_ns === nothing || (seconds += row.time_ns / 1e9)
      row.status in (:error, :timeout) && break
    end
  end
  status = aggregate_status([row.status for row in observations])
  failure = status == :ok ? nothing : first(row for row in observations if row.status == status)
  final = isempty(rows) ? last(observations) : last(rows)
  (; rows, observations, status, failure, final)
end

function archive_coefficients(io, config, spec, result)
  output, row = result.final.output, result.final
  output === nothing && return
  path = hasproperty(output, :βs)
  βs = path ? output.βs : [output.β]
  isempty(βs) && return
  all(β -> length(β) == length(first(βs)), βs) || error("inconsistent coefficient lengths")
  matrix = reduce(hcat, βs)
  matrix = reshape(matrix, length(first(βs)), length(βs))
  filename = replace(spec.meta.id, '/' => "__") * "__$(spec.meta.setting_index)__rep$(lpad(config.rep, 2, '0')).f64"
  file = joinpath(config.output, "coef", filename)
  ispath(file) && error("refusing to overwrite coefficients")
  descriptor = write_array(joinpath(config.output, "coef"), filename, matrix)
  λs = path ? output.λs : spec.meta.lambda_values
  tsv_line(io, spec.meta.id, spec.meta.case_id, spec.meta.setting_index, config.rep,
    "coef/$filename", size(matrix, 1), size(matrix, 2), "Float64", descriptor["sha256"],
    join(repr.(λs), ','), spec.meta.measure, finite_field(row.value),
    finite_field(row.loading_change), row.status)
  flush(io)
end

function record_case!(metrics, raw, errors, diagnostic, spec, config, result, hash)
  m, rows = spec.meta, result.rows
  for (index, row) in enumerate(rows)
    tsv_line(raw, m.id, config.rep, index, row.time_ns, row.gc_ns, row.bytes,
      finite_field(row.value), row.status)
  end
  values = [row.value for row in rows if isfinite(row.value)]
  tsv_line(metrics, m.id, m.group, m.phase, config.rep, result.status, length(rows),
    count(row -> row.status == :ok, rows), timing_statistics(rows)..., m.measure, m.target,
    isempty(values) ? nothing : maximum(values), isempty(values) ? nothing : median(values), hash)
  if result.status != :ok
    tsv_line(errors, m.id, config.rep, result.status, result.failure.detail, result.failure.stack)
  end
  for (index, row) in enumerate(result.observations)
    cert = row.cert
    tsv_line(diagnostic, m.id, config.rep, index <= length(result.observations) - length(rows) ?
      "validation" : "sample", index, row.status, finite_field(row.value),
      cert === nothing ? nothing : finite_field(cert.primal),
      cert === nothing ? nothing : finite_field(cert.dual), finite_field(row.loading_change))
  end
  foreach(flush, (metrics, raw, errors, diagnostic))
end

function run_fixtures(config, artifact, specs)
  get(artifact.manifest, "fixture", false) || error("fixtures require an inputs.jl --tiny artifact")
  ispath(config.output) && (!isdir(config.output) || !isempty(readdir(config.output))) &&
    error("use a fresh fixture output directory")
  metadata = start_metadata(config, artifact, specs)
  mkpath(joinpath(config.output, "coef"))
  summary = Dict{String,Any}()
  failures = 0
  open(joinpath(config.output, "fixtures.tsv"), "w") do io
    tsv_line(io, "id", "estimator", "side", "status", "measure", "value", "loadings_change", "target", "detail")
    open(joinpath(config.output, "coef", "manifest.tsv"), "w") do coef
      tsv_line(coef, COEF_HEADER...)
      for spec in specs
        data = case_data(artifact, spec.case)
        result = measure_case(spec, data, config)
        row = result.final
        ok = result.status == :ok
        failures += !ok
        push!(get!(summary, spec.meta.estimator, Any[]), ok)
        tsv_line(io, spec.meta.case_id, spec.meta.estimator, config.side, result.status,
          spec.meta.measure, finite_field(row.value), finite_field(row.loading_change), spec.meta.target, row.detail)
        archive_coefficients(coef, config, spec, result)
        println("FIXTURE ", spec.meta.case_id, " status=", result.status,
          " value=", row.value, " loadings_change=", row.loading_change)
      end
    end
  end
  metadata["settings"] = [Dict("id" => s.meta.case_id, "settings" => s.settings) for s in specs]
  metadata["estimators"] = Dict(name => Dict("passed" => all(values), "cases" => length(values))
    for (name, values) in summary)
  metadata["nonok_cases"] = failures
  write_toml(joinpath(config.output, "fixtures.toml"), metadata)
  for name in sort!(collect(keys(summary)))
    println("ESTIMATOR ", name, " side=", config.side, " passed=", all(summary[name]))
  end
  failures == 0 ? 0 : 2
end

function run_records(config, artifact, specs)
  started = time()
  mkpath(config.output)
  stem = "julia-$(VERSION)-rep$(lpad(config.rep, 2, '0'))"
  any(name -> startswith(name, stem), readdir(config.output)) && error("refusing to overwrite process records")
  prefix = joinpath(config.output, stem)
  metadata = start_metadata(config, artifact, specs)
  metadata["external_catalog"] = "external/$stem-catalog.tsv"
  write_toml(prefix * "-metadata-start.toml", metadata)
  mkpath(joinpath(config.output, "external"))
  for (path, header) in ((prefix * "-catalog.tsv", CATALOG_HEADER),
      (joinpath(config.output, metadata["external_catalog"]), EXTERNAL_CATALOG_HEADER))
    open(path, "w") do io
      tsv_line(io, header...)
      for spec in specs
        tsv_line(io, (getproperty(spec.meta, Symbol(field)) for field in header)...)
      end
    end
  end
  write_toml(prefix * "-settings.toml", Dict("case" => [Dict("id" => s.meta.id,
    "case_id" => s.meta.case_id, "setting_index" => s.meta.setting_index, "settings" => s.settings) for s in specs]))
  mkpath(joinpath(config.output, "coef"))
  coef_manifest = joinpath(config.output, "coef", "manifest.tsv")
  new_coef_manifest = !isfile(coef_manifest)
  failures = 0
  diagnostics = Dict{String,Any}()
  order = shuffle!(scenario_rng(config.rep, "external_measurement_order"), copy(specs))
  open(prefix * "-metrics.tsv", "w") do metrics
    open(prefix * "-samples.tsv", "w") do raw
      open(prefix * "-errors.tsv", "w") do errors
        open(prefix * "-diagnostics.tsv", "w") do diagnostic
          open(coef_manifest, "a") do coef
            tsv_line(metrics, METRICS_HEADER...)
            tsv_line(raw, SAMPLES_HEADER...)
            tsv_line(errors, ERRORS_HEADER...)
            tsv_line(diagnostic, "id", "rep", "phase", "observation", "status", "value", "primal", "dual", "loadings_change")
            new_coef_manifest && tsv_line(coef, COEF_HEADER...)
            for spec in order
              hash = ""
              data = nothing
              result = try
                data = case_data(artifact, spec.case)
                # Hash excludes prepared Gram storage, and is identical across sides and rungs.
                hash = data_hash((; artifact = artifact.sha256, case = spec.meta.case_id))
                measure_case(spec, data, config)
              catch err
                failure = (; time_ns = nothing, gc_ns = nothing, bytes = nothing, value = NaN,
                  status = :error, detail = sprint(showerror, err),
                  stack = sprint(Base.show_backtrace, catch_backtrace()), output = nothing,
                  cert = nothing, loading_change = NaN)
                (; rows = NamedTuple[], observations = [failure], status = :error, failure, final = failure)
              end
              record_case!(metrics, raw, errors, diagnostic, spec, config, result, hash)
              archive_coefficients(coef, config, spec, result)
              failures += result.status != :ok
              if result.final.output !== nothing
                info = copy(result.final.output.info)
                if data !== nothing && hasproperty(result.final.output, :β)
                  sigma = norm(data.y - data.X * result.final.output.β) / sqrt(data.n)
                  info["residual_sigma"] = sigma
                  spec.case["estimator"] == "scaled_lasso" && (info["penalty_level"] = data.λ * sigma)
                end
                diagnostics[spec.meta.id] = info
              end
              println("CASE ", spec.meta.id, " status=", result.status)
            end
          end
        end
      end
    end
  end
  write_toml(prefix * "-diagnostics.toml", diagnostics)
  merge!(metadata, Dict("cases" => length(specs), "ok_cases" => length(specs) - failures,
    "nonok_cases" => failures, "elapsed_s" => time() - started,
    "maxrss_bytes" => Sys.maxrss(), "finished" => true))
  temporary = prefix * "-metadata-finalizing.toml"
  write_toml(temporary, metadata)
  mv(temporary, prefix * "-metadata.toml")
  println("REPETITION_FINISHED cases=", length(specs), " nonok=", failures)
  failures == 0 ? 0 : 2
end

function external_main_loaded(config, specs)
  Threads.nthreads() == 1 || error("run with JULIA_NUM_THREADS=1")
  BLAS.set_num_threads(1)
  artifact = read_artifact(config.input)
  artifact.manifest["catalog_sha256"] == file_sha256(CATALOG_PATH) || error("artifact catalog differs")
  specs = effective_specs(config, artifact, specs)
  config.fixtures && return run_fixtures(config, artifact, specs)
  run_records(config, artifact, specs)
end

function main(args = ARGS)
  try
    config = runner_settings(args)
    specs = selected_specs(config)
    if config.listing
      for spec in specs
        tsv_line(stdout, spec.meta.id, spec.meta.suite, spec.meta.setting_index, spec.meta.stopping)
      end
      return 0
    end
    include(joinpath(@__DIR__, config.side == "legacy" ? "legacy.jl" : "current.jl"))
    Base.invokelatest(external_main_loaded, config, specs)
  catch err
    println(stderr, "RECORD_FAILURE ", sprint(showerror, err))
    return 3
  end
end

if abspath(PROGRAM_FILE) == @__FILE__
  exit(main())
end
