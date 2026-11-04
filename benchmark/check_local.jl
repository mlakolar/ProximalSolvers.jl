# Checks for case selection and local exploration (#110 Stage 1). From the package root:
#   JULIA_NUM_THREADS=1 julia --project=ENV benchmark/check_local.jl
using Test, Random
include("local.jl")
const L = PSLocal

ids(specs) = [spec.meta.id for spec in specs]

@testset "Case selection grammar" begin
  catalog = L.build_catalog("extended", collect(L.CASE_GROUPS))
  all_ids = ids(catalog)
  one = "cd/lasso-dense/cd/B/call"
  @test ids(L.select_cases(catalog, one)) == [one]
  @test ids(L.select_cases(catalog, " $one , $one ,")) == [one]
  @test ids(L.select_cases(catalog, "cd/lasso-dense/cd/*")) ==
    filter(startswith("cd/lasso-dense/cd/"), all_ids)
  workspace = L.select_cases(catalog, "*/workspace")
  @test !isempty(workspace) && all(endswith("/workspace"), ids(workspace))
  @test ids(L.select_cases(catalog, "paths/*,$one")) ==
    filter(id -> startswith(id, "paths/") || id == one, all_ids)
  @test L.select_cases(catalog, join(all_ids, ',')) == catalog
  # Exact IDs are not prefixes, and regex metacharacters are literal.
  for bad in ("", " , ", "cd/lasso-dense/cd/B", "cd.lasso-dense/cd/B/call",
              "cd/lasso-dense/cd/B/cal.", "cd/nope/*", "$one,cd/nope")
    @test_throws ArgumentError L.select_cases(catalog, bad)
  end
  quick = L.build_catalog("quick", collect(L.CASE_GROUPS))
  @test_throws ArgumentError L.select_cases(quick, "cd/lasso-A/cd/tight/call")
  @test_throws ArgumentError L.select_cases(L.build_catalog("quick", ["admm"]), one)
end

@testset "Inputs do not depend on selection or order" begin
  catalog = L.build_catalog("extended", collect(L.CASE_GROUPS))
  forward = Dict(spec.meta.id => spec.make(1).problem_hash for spec in catalog)
  Random.seed!(20261103); rand(1000)
  backward = Dict(spec.meta.id => spec.make(1).problem_hash for spec in reverse(catalog))
  @test forward == backward
  for id in ("cd/lasso-dense/cd/B/call", "cd/lasso-csc/cd/B/workspace",
             "gradient/lasso/apg/tight/call", "newton/logistic-l1/prox-newton/B/call",
             "admm/lasso/admm/B/call", "paths/lasso/cd/grid8/call", "cd/lasso-D/cd/tight/call")
    alone = only(L.select_cases(L.build_catalog("extended", collect(L.CASE_GROUPS)), id))
    @test alone.meta == only(spec for spec in catalog if spec.meta.id == id).meta
    @test alone.make(1).problem_hash == forward[id]
  end
  # The hash responds to the draw: fixed inputs repeat across repetitions, draws do not.
  for spec in catalog
    @test (spec.make(2).problem_hash == forward[spec.meta.id]) == (spec.meta.inputs == "fixed")
  end
end

quiet(f) = redirect_stdout(f, devnull)
function explored(spec; samples = 4, case_seconds = 60.0)
  quiet(() -> L.explore_case(spec, 1, samples, 10.0, case_seconds, samples; io = devnull))
end
function variant(spec; call = identity, reset = true, certify = nothing, calls = Ref(0))
  L.CaseSpec(spec.meta, rep -> begin
    state = spec.make(rep)
    L.CaseState(reset ? state.reset! : () -> nothing,
                () -> (calls[] += 1; call(state.call!())),
                certify === nothing ? state.certify : out -> certify(state.certify, out),
                state.problem_hash)
  end)
end
function perturbed(output, value)
  output.minimizer[1] = value
  output
end

@testset "Local results keep certificate and failure statuses" begin
  catalog = L.build_catalog("extended", collect(L.CASE_GROUPS))
  spec(id) = only(L.select_cases(catalog, id))
  for id in ("cd/lasso-dense/cd/B/call", "gradient/lasso/apg/tight/workspace")
    good = explored(spec(id))
    @test good.status == :ok && good.samples == 4 && good.repeatable
    @test good.worst_value <= good.target && good.median_ns > 0
    @test !isempty(good.diagnostics)
    @test explored(variant(spec(id); call = out -> perturbed(out, 10.0))).status == :target_missed
    @test explored(variant(spec(id); call = out -> perturbed(out, NaN))).status == :uncertifiable
  end
  calls = Ref(0)
  failing = explored(variant(spec("cd/lasso-dense/cd/B/call");
    call = out -> (calls[] += 1) >= 3 ? error("deliberate failure") : out))
  @test failing.status == :error && occursin("deliberate failure", failing.failure)
  @test failing.samples == 2   # the failed sample is retained, sampling stops
  slow = explored(variant(spec("cd/lasso-dense/cd/B/call"); call = out -> (sleep(0.02); out));
                  case_seconds = 0.01)
  @test slow.status == :timeout && slow.samples == 0
  # Skipping reset! warm-starts every later call: reported as not repeatable.
  @test !explored(variant(spec("cd/lasso-dense/cd/B/call"); reset = false)).repeatable
  broken = L.CaseSpec(spec("cd/lasso-dense/cd/B/call").meta, rep -> error("deliberate setup failure"))
  failed = explored(broken)
  @test failed.status == :error && failed.samples == 0 && occursin("construction", failed.failure)
  path = explored(spec("paths/lasso/cd/grid8/call"))
  @test path.status == :ok && occursin("passes=", path.diagnostics)
  setup = explored(spec("admm/lasso/admm/construction/setup"))
  @test setup.status == :ok && setup.diagnostics == ""
end

@testset "No timed work after a failed certificate" begin
  catalog = L.build_catalog("extended", collect(L.CASE_GROUPS))
  base = only(L.select_cases(catalog, "cd/lasso-dense/cd/B/call"))
  incomplete(certify, out) = throw(L.IncompletePath("deliberate"))
  # (failing call number, kind) => (status, calls, timed samples)
  for (at, kind, status) in ((1, :missed, :target_missed), (1, :nan, :uncertifiable),
                             (1, :incomplete, :incomplete), (1, :throw, :error),
                             (2, :missed, :target_missed), (3, :nan, :uncertifiable),
                             (3, :incomplete, :incomplete), (3, :throw, :error))
    calls = Ref(0)
    bad() = calls[] == at
    call = out -> !bad() ? out : kind == :missed ? perturbed(out, 10.0) :
      kind == :nan ? perturbed(out, NaN) : kind == :throw ? error("deliberate failure") : out
    certify = (c, out) -> kind == :incomplete && bad() ? incomplete(c, out) : c(out)
    text = sprint(io -> quiet(() -> L.explore_case(variant(base; call, certify, calls),
                                                   1, 25, 10.0, 60.0, 5; io)))
    r = explored(variant(base; call, certify, calls = (calls[] = 0; calls)); samples = 25)
    @test (r.status, calls[], r.samples) == (status, at, at - 1)
    @test r.median_ns === nothing && r.min_ns === nothing && r.median_bytes === nothing
    @test occursin("CHECK cd/lasso-dense/cd/B/call status=$(at == 1 ? status : :ok)", text)
  end
  # An ok but slow validation is rechecked once and times out; nothing is sampled.
  calls = Ref(0)
  slow = explored(variant(base; call = out -> (sleep(0.02); out), calls); case_seconds = 0.01)
  @test (slow.status, calls[], slow.samples) == (:timeout, 2, 0)
  # Ok samples before a failure are not a timing of the failed case.
  calls = Ref(0)
  late = explored(variant(base; call = out -> calls[] == 3 ? perturbed(out, 10.0) : out, calls))
  @test late.status == :target_missed && late.samples == 2 && late.median_ns === nothing
  env = L.environment()
  good = explored(base)
  text = sprint(io -> L.report(io, env, [late]; baseline = [merge(good, (; environment = env))]))
  row = only(l for l in split(text, '\n') if startswith(l, late.id))
  @test occursin(r"target_missed\s+\S+\s+-\s+-\s+2\s+-", row)
  @test occursin("no timing reported", text) && occursin("no ratio (candidate status target_missed)", text)
  @test L.baseline_ratio(late, Dict(k => string(v) for (k, v) in env),
                         Dict(late.id => Dict("id" => late.id, "status" => "ok",
                              "data_hash" => late.data_hash, "median_ns" => "1000")), env)[1] === nothing
end

@testset "Freshness of local.jl, harness, environment and packages" begin
  for pkg in (L.ProximalSolvers, L.ProximalBase)
    root = realpath(dirname(dirname(pathof(pkg))))
    @test L.package_state(root).fingerprint == L.package_fingerprint(root)
  end
  loaded = L.LOADED
  @test loaded.solvers.trusted && !loaded.solvers.preloaded   # this file loaded it
  @test loaded.base.trusted
  @test loaded.local_hash == L.local_hash() && loaded.harness == L.harness_hash()
  ok = L.check_current_source(loaded, nothing)
  @test ok.mode == "static" && ok.solvers == L.package_fingerprint(loaded.solvers.root) &&
    ok.base == L.package_fingerprint(loaded.base.root)
  with(pkg; kw...) = merge(pkg, (; kw...))
  state(pkg; kw...) = with(pkg; state = merge(pkg.state, (; kw...)))
  refused = (
    "local.jl changed" => with(loaded; local_hash = "edited"),
    "harness files changed" => with(loaded; harness = "edited"),
    "project or manifest changed" => with(loaded; environment = "edited"),
    "different path" => with(loaded; base = with(loaded.base; root = "/elsewhere")),
    "cannot be matched" => with(loaded; base = with(loaded.base; trusted = false)),
    "ProximalBase files changed" => with(loaded; base = state(loaded.base; fingerprint = "old")),
    "Project.toml changed" => with(loaded; solvers = state(loaded.solvers; project = "old")),
    "loaded before local.jl" => with(loaded; solvers = with(loaded.solvers; trusted = false)),
    "source changed" => with(loaded; solvers = state(loaded.solvers; fingerprint = "old")))
  for (message, stale) in refused
    err = try L.check_current_source(stale, nothing); nothing catch e; e end
    @test err isa ErrorException && occursin(message, err.msg)
  end
  # A revision cannot clear a changed Project.toml, ProximalBase or local.jl: these are
  # refused before Revise is consulted.
  for (message, stale) in refused[1:7]
    @test_throws ErrorException L.check_current_source(stale, :not_consulted)
  end
end

@testset "Baseline ratios and saved results" begin
  result = explored(only(L.select_cases(L.build_catalog("quick", ["cd"]),
                                        "cd/lasso-dense/cd/B/call")))
  env = L.environment()
  base_env = Dict(k => string(v) for (k, v) in env)
  row = Dict("id" => result.id, "status" => "ok", "data_hash" => result.data_hash,
             "median_ns" => string(2 * result.median_ns))
  ratio, note = L.baseline_ratio(result, base_env, Dict(result.id => row), env)
  @test ratio ≈ 0.5 && occursin("confirm", note) && !occursin("min ratio", note)
  # Agreeing minima keep the verdict; a disagreeing minimum points to interference.
  same = merge(row, Dict("min_ns" => string(2 * result.min_ns)))
  @test occursin("min ratio 0.500; apparent speedup",
                 L.baseline_ratio(result, base_env, Dict(result.id => same), env)[2])
  noisy = merge(row, Dict("min_ns" => string(result.min_ns)))
  @test occursin("disagree", L.baseline_ratio(result, base_env, Dict(result.id => noisy), env)[2])
  for (key, value) in (("data_hash", "0"), ("status", "target_missed"), ("median_ns", ""))
    changed = merge(row, Dict(key => value))
    @test L.baseline_ratio(result, base_env, Dict(result.id => changed), env)[1] === nothing
  end
  for key in ("julia", "cpu_model", "harness_hash", "local_hash", "proximalbase_hash")
    other = merge(base_env, Dict(key => "other"))
    @test L.baseline_ratio(result, other, Dict(result.id => row), env)[1] === nothing
  end
  @test L.baseline_ratio(result, base_env, Dict{String,Dict{String,String}}(), env)[1] === nothing
  # Corrupt or nonpositive baseline values never give a ratio or an exception.
  for bad in ("NaN", "Inf", "-Inf", "0", "-5", "abc", "")
    ratio, note = L.baseline_ratio(result, base_env,
      Dict(result.id => merge(row, Dict("median_ns" => bad, "min_ns" => string(result.min_ns)))), env)
    @test ratio === nothing && occursin("baseline median invalid", note)
    ratio, note = L.baseline_ratio(result, base_env, Dict(result.id => merge(row, Dict("min_ns" => bad))), env)
    @test ratio ≈ 0.5 && !occursin("min ratio", note)
  end
  # Modes are reported when they differ (warm session vs fresh process).
  other_mode = merge(base_env, Dict("execution" => "fresh process"))
  @test occursin("not like for like", L.baseline_ratio(result, other_mode, Dict(result.id => row), env)[2])
  mktempdir() do dir
    path = joinpath(dir, "base.local.tsv")
    L.save_local(path, env, [result])
    @test_throws ErrorException L.save_local(path, env, [result])
    saved_env, saved_rows = L.load_local(path)
    @test saved_env["format"] == L.LOCAL_FORMAT
    @test saved_rows[result.id]["data_hash"] == result.data_hash
    @test L.baseline_ratio(result, saved_env, saved_rows, env)[1] == 1.0
    partial = joinpath(dir, "partial.local.tsv")
    write(partial, "# format=$(L.LOCAL_FORMAT)\nid\tstatus\n$(result.id)\tok\n")
    @test L.baseline_ratio(result, L.load_local(partial)..., env)[1] === nothing
    # An existing --save path is refused before any case runs.
    @test_throws ArgumentError quiet(() -> L.explore("cd/lasso-dense/cd/B/call"; save = path,
                                                     io = devnull))
    # An in-memory baseline carries the environment of its own run.
    first_run = quiet(() -> L.explore("cd/lasso-dense/cd/B/call"; samples = 3, io = devnull))
    @test haskey(only(first_run).environment, "proximalsolvers_hash")
    text = sprint(io -> quiet(() -> L.explore("cd/lasso-dense/cd/B/call"; samples = 3, io,
                                              baseline = first_run)))
    @test occursin("vs baseline: ratio", text)
    write(joinpath(dir, "other.tsv"), "id\tstatus\n")
    @test_throws ErrorException L.load_local(joinpath(dir, "other.tsv"))
    text = sprint(io -> L.report(io, env, [result]; baseline = path))
    @test occursin("EXPLORATORY", text) && occursin("ratio 1.000", text)
    @test !occursin(r"significan|noninferior|no regression"i, text)
    corrupt = joinpath(dir, "corrupt.local.tsv")
    write(corrupt, replace(read(path, String), "\t$(result.median_ns)\t" => "\tNaN\t"))
    text = sprint(io -> L.report(io, env, [result]; baseline = corrupt))
    @test occursin("no ratio (baseline median invalid", text)
  end
end

@testset "Session commands" begin
  commands = """
    --list cd/lasso-dense/cd/B/*

    cd/lasso-dense/cd/B/call --samples 2
    cd/nope/*
    --session
    exit
    cd/lasso-dense/cd/B/call
    """
  out, err = tempname(), tempname()
  open(out, "w") do o
    open(err, "w") do e
      redirect_stdout(o) do
        redirect_stderr(e) do
          @test L.session(IOBuffer(commands), o) == 0
        end
      end
    end
  end
  text = read(out, String)
  @test occursin("LOCAL_SESSION ready", text)
  @test [m[1] for m in eachmatch(r"LOCAL_DONE status=(\d)", text)] == ["0", "0", "3", "3"]
  @test count("CHECK cd/lasso-dense/cd/B/call status=ok", text) == 1   # nothing after exit
  @test occursin("nested --session", read(err, String))
end
