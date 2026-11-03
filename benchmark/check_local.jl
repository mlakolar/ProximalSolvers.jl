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
function variant(spec; call = identity, reset = true)
  L.CaseSpec(spec.meta, rep -> begin
    state = spec.make(rep)
    L.CaseState(reset ? state.reset! : () -> nothing, () -> call(state.call!()),
                state.certify, state.problem_hash)
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
  for key in ("julia", "cpu_model", "harness_hash", "proximalbase_hash")
    other = merge(base_env, Dict(key => "other"))
    @test L.baseline_ratio(result, other, Dict(result.id => row), env)[1] === nothing
  end
  @test L.baseline_ratio(result, base_env, Dict{String,Dict{String,String}}(), env)[1] === nothing
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
