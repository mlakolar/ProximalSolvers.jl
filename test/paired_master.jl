module PairedMasterTests

using Test

# Keep Pkg/SHA in a standalone standard-library process, rather than expanding
# the package/test dependency surface just for CI's exact-source control.
const CONTROLS = raw"""
using Test, TOML
include(ARGS[1])
const PM = PairedMasterDiagnostics
const KEYS = PM.expected_record_keys()

# A document with the structure of the probe's output: every optimization record is accurate to its
# reference with consistent stopping flags, and the other records are fixed values. The thresholds in
# the comments below are those of `check_quality` for the record's element type.
function fixture_record(key)
  parts = split(key, "/")
  T = parts[2] == "Float32" ? Float32 : Float64
  record = Dict{String, Any}("optimum" => 2.0, "objective" => 2.0, "kkt" => 0.0, "kkt_scale" => 4.0,
    "minimum" => PM.bits(T(2)), "fitted" => [1.0, -0.5, 0.25, 0.0],
    "reference_fit" => [1.0, -0.5, 0.25, 0.0], "rng_next" => "17")
  if parts[3] != "nonunique"
    record["point"] = PM.bits(T[1, -2])
    record["reference_point"] = [1.0, -2.0]
  end
  if parts[end] == "pgd"
    merge!(record, Dict("iterations" => 12, "iteration_converged" => false, "converged" => true,
      "x_converged" => true, "f_converged" => false, "grad_converged" => false,
      "f_increased" => false, "call_limit_reached" => false))
  else
    merge!(record, Dict("passes" => 3, "converged" => true,
      "maxchange" => PM.bits(T(1e-9)), "tolerance" => PM.bits(T(1e-7))))
  end
  record
end
fixture() = Dict("format" => 1, "records" => Dict(key =>
  PM.is_optimization(key) ? fixture_record(key) : Dict("value" => "unchanged") for key in KEYS))

pick(type, design, method) =
  first(key for key in KEYS if startswith(key, "lasso/$type/$design/") && endswith(key, "/$method"))
elementtype(type) = type == "Float32" ? Float32 : Float64
function failure(f)
  try
    f()
  catch e
    e isa ErrorException && return e.msg
    rethrow()
  end
  ""
end
# The pair of documents when `change!` edits one record of side A or B.
function edited(side, key, change!)
  a, b = fixture(), fixture()
  change!((side == :A ? a : b)["records"][key])
  a, b
end
compare(a, b) = PM.compare_records(a, b; io = devnull)
fails(a, b, pattern) = occursin(pattern, failure(() -> compare(a, b)))
@testset "paired controls: exact source and fail-closed records" begin
  @test PM.exact_sha(PM.PB_A, "baseline") == PM.PB_A
  for invalid in ("master", "0.6", PM.PB_A[1:12], uppercase(PM.PB_A), nothing)
    @test_throws ArgumentError PM.exact_sha(invalid, "revision")
  end
  document = fixture()
  records = document["records"]
  @test length(PM.expected_record_keys()) == 288
  @test PM.compare_records(document, deepcopy(document); io = devnull) == 288
  missing = deepcopy(document)
  delete!(missing["records"], first(PM.expected_record_keys()))
  @test_throws ErrorException PM.compare_records(document, missing; io = devnull)
  changed = deepcopy(document)
  changed["records"]["scalar/Float32/1/1/1"]["value"] = "changed"
  @test_throws ErrorException PM.compare_records(document, changed; io = devnull)
  @test_throws ErrorException PM.checked_records(Dict("format" => 2, "records" => records))
  @test_throws ErrorException PM.checked_records(Dict("format" => 1, "records" => Dict()))
  @test PM.decode(PM.bits(Float32(0.1))) === Float32(0.1)
  @test PM.decode(PM.bits([-0.0, 2.5])) == [-0.0, 2.5]
  mktempdir() do root
    mkpath(joinpath(root, "src"))
    write(joinpath(root, "src", "Fixture.jl"), "module Fixture\nend\n")
    open(joinpath(root, "Project.toml"), "w") do io
      TOML.print(io, Dict("sources" => Dict("ProximalBase" => Dict("url" => PM.PB_URL, "rev" => PM.PB_A))))
    end
    @test PM.pinned_revision(root) == PM.PB_A
    run(`git init --quiet $root`)
    run(`git -C $root add .`)
    run(`git -C $root -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m fixture`)
    sha = readchomp(`git -C $root rev-parse HEAD`)
    identity = PM.checkout_identity(root, sha)
    @test identity["commit"] == sha
    @test length(identity["source_sha256"]) == 64
    @test_throws ErrorException PM.checkout_identity(root, "0000000000000000000000000000000000000000")
    @test_throws ErrorException PM.checkout_identity(root, sha; digest = repeat("0", 64))
    open(io -> println(io, "# source changed"), joinpath(root, "src", "Fixture.jl"), "a")
    @test PM.source_digest(root) != identity["source_sha256"]
    @test_throws ErrorException PM.checkout_identity(root, sha)
  end
end
@testset "paired controls: quality comparison of optimization records" begin
  a, b = fixture(), fixture()
  buffer = IOBuffer()
  @test PM.compare_records(a, b; io = buffer) == 288
  @test isempty(take!(buffer))
  # Accurate solutions with other bits, iteration counts, residuals and RNG state pass; each
  # differing record is printed as a diagnostic line.
  pgd, cd = pick("Float32", "correlated", "pgd"), pick("Float64", "orthogonal", "random")
  b["records"][pgd]["iterations"] = 40
  b["records"][pgd]["kkt"] = 1e-5
  b["records"][pgd]["x_converged"] = false
  b["records"][pgd]["grad_converged"] = true
  b["records"][pgd]["point"] = PM.bits(Float32[1 + 1e-5, -2])
  b["records"][pgd]["rng_next"] = "99"
  b["records"][cd]["passes"] = 4
  b["records"][cd]["rng_next"] = "100"
  b["records"][cd]["objective"] = 2.0 + 1e-6
  @test PM.compare_records(a, b; io = buffer) == 288
  lines = split(String(take!(buffer)), "\n"; keepempty = false)
  @test length(lines) == 2
  @test all(line -> startswith(line, "diagnostic: lasso/"), lines)
  @test occursin("iterations A=12 B=40", only(filter(line -> occursin(pgd, line), lines)))
  @test occursin("passes A=3 B=4", only(filter(line -> occursin(cd, line), lines)))

  for side in (:A, :B), (type, design, method) in (("Float32", "correlated", "pgd"),
      ("Float64", "orthogonal", "random"), ("Float32", "nonunique", "cyclic"), ("Float64", "correlated", "cyclic"))
    key = pick(type, design, method)
    T = elementtype(type)
    tol = PM.quality_tolerance(T)
    # Each check passes just below its threshold and fails just above it.
    for (factor, passes) in ((0.99, true), (1.01, false))
      # objective: tol * max(1, |optimum|) above the optimum, with the returned minimum consistent
      objective = 2.0 + factor * tol * 2.0
      a, b = edited(side, key, r -> (r["objective"] = objective; r["minimum"] = PM.bits(T(objective))))
      passes ? @test(compare(a, b) == 288) : @test(fails(a, b, "independent objective failure"))
      # KKT residual: tol * kkt_scale
      a, b = edited(side, key, r -> r["kkt"] = factor * tol * 4.0)
      passes ? @test(compare(a, b) == 288) : @test(fails(a, b, "independent KKT failure"))
      # returned minimum against the independent objective: tol * max(1, |optimum|)
      a, b = edited(side, key, r -> r["minimum"] = PM.bits(T(2.0 + factor * tol * 2.0)))
      passes ? @test(compare(a, b) == 288) : @test(fails(a, b, "returned objective mismatch"))
      # fitted values: 4 tol * max(1, |reference fit|)
      a, b = edited(side, key, r -> r["fitted"][1] += factor * 4tol)
      passes ? @test(compare(a, b) == 288) : @test(fails(a, b, "independent fitted-value failure"))
      if design != "nonunique"
        # coefficients of a unique design: 4 tol * max(1, |reference point|)
        a, b = edited(side, key, r -> r["point"] = PM.bits(T[1 + factor * 8tol, -2]))
        passes ? @test(compare(a, b) == 288) : @test(fails(a, b, "independent coefficient failure"))
      end
    end
  end
  # A nonunique design checks the fit only: different coefficients pass, a fit error fails.
  key = pick("Float64", "nonunique", "random")
  a, b = fixture(), fixture()
  a["records"][key]["point"], b["records"][key]["point"] = PM.bits([1.0, 0.0, 0.0]), PM.bits([0.0, 1.0, 0.0])
  @test compare(a, b) == 288
  b["records"][key]["fitted"][2] += 1.0
  @test fails(a, b, "independent fitted-value failure")
  a, b = edited(:B, key, r -> r["objective"] = NaN)
  @test fails(a, b, "independent objective failure")
end
@testset "paired controls: stopping flags of the current tree" begin
  pgd, cd = pick("Float32", "correlated", "pgd"), pick("Float64", "orthogonal", "random")
  cyclic = pick("Float32", "orthogonal", "cyclic")
  flags(; kwargs...) = r -> merge!(r, Dict{String, Any}(string(name) => value for (name, value) in kwargs))
  # Truthful records pass, whichever stopping reason a run that did not converge reports.
  stopped(; kwargs...) = flags(; converged = false, x_converged = false, kwargs...)
  for change in (stopped(iterations = PM.PGD_MAXITER, iteration_converged = true),
      stopped(f_increased = true), stopped(call_limit_reached = true),
      flags(f_converged = true, x_converged = false), flags(iterations = PM.PGD_MAXITER, iteration_converged = true))
    a, b = edited(:B, pgd, change)
    @test compare(a, b) == 288
  end
  a, b = edited(:B, cd, flags(passes = PM.CD_MAXPASSES, converged = false))
  @test compare(a, b) == 288
  # Each relation of the flags fails on the current tree.
  broken = (
    (pgd, flags(converged = true, x_converged = false), "converged differs from x, f or gradient"),
    (pgd, flags(converged = false), "converged differs from x, f or gradient"),
    (pgd, flags(iteration_converged = true), "iteration_converged differs from iterations == maxiter"),
    (pgd, flags(iterations = PM.PGD_MAXITER), "iteration_converged differs from iterations == maxiter"),
    (pgd, stopped(), "no convergence and no stopping reason"),
    (cd, flags(maxchange = PM.bits(2e-7)), "converged without maxchange < tolerance"),
    (cd, flags(maxchange = PM.bits(1e-7)), "converged without maxchange < tolerance"),
    (cd, flags(converged = false), "not converged before the pass limit"),
    (cyclic, flags(converged = false, passes = PM.CD_MAXPASSES - 1), "not converged before the pass limit"))
  for (key, change, pattern) in broken
    a, b = edited(:B, key, change)
    @test fails(a, b, pattern)
  end
  a, b = edited(:B, pgd, r -> delete!(r, "grad_converged"))
  @test fails(a, b, "stopping field grad_converged is missing")
  a, b = edited(:B, pgd, flags(x_converged = 1))
  @test fails(a, b, "stopping flag x_converged is not a Boolean")
  # Side A is the frozen extraction: its flags are not checked, its quality is.
  for (key, change, _) in broken
    a, b = edited(:A, key, change)
    @test compare(a, b) == 288
  end
end
@testset "paired controls: exact contracts and the result API surface" begin
  for key in ("scalar/Float32/1/1/1", "scalar/Float64/3/2/5", "owner/Float32/construct", "owner/Float64/scatter")
    for side in (:A, :B)
      a, b = edited(side, key, r -> r["value"] = "changed")
      @test fails(a, b, "paired numerical or API divergence at $key")
    end
  end
  for side in (:A, :B), key in (pick("Float32", "correlated", "pgd"), pick("Float64", "orthogonal", "random"))
    a, b = edited(side, key, r -> r["added_field"] = 1)
    @test fails(a, b, "result field sets differ at $key")
    a, b = edited(side, key, r -> delete!(r, "rng_next"))
    @test fails(a, b, "result field sets differ at $key")
  end
  for side in (:A, :B)
    a, b = fixture(), fixture()
    delete!((side == :A ? a : b)["records"], pick("Float32", "correlated", "pgd"))
    @test fails(a, b, "missing or unexpected diagnostic records")
  end
end
@testset "paired controls: always-run gated Linux job" begin
  workflow = replace(read(joinpath(PM.ROOT, ".github", "workflows", "CI.yml"), String), "\r\n" => "\n")
  analysis = split(split(workflow, "  analysis:\n"; limit = 2)[2], "  verdict:\n"; limit = 2)[1]
  @test occursin("name: Benchmark analysis controls", analysis)
  @test occursin("runs-on: ubuntu-latest", analysis)
  @test occursin("julia-actions/setup-julia@v3", analysis)
  @test occursin("version: '1'", analysis)
  @test occursin("arch: x64", analysis)
  @test occursin("--project=@stdlib scripts/paired_master_diagnostics.jl", analysis)
  @test occursin("python benchmark/check_analysis.py", analysis)
  @test !occursin(r"(?m)^\s*if:", analysis)
  @test !occursin("continue-on-error", analysis)
  @test occursin("needs: [plan, test, analysis]", workflow)
  @test occursin("fail-fast: false", analysis)
  @test occursin("part: [comparator, campaign, controls]", analysis)
  @test occursin("name: Benchmark analysis controls (\${{ matrix.part }})", analysis)
  # Per-step structure of the dispatch steps. Each table row names a step, its owner leg and the
  # commands that the owner arm of the step's `case` must contain; the other two legs must share a
  # no-op arm and any other leg name must reach an error arm. The step text is split at the list-item
  # marker of the steps, and the arms at the arm terminator, which no command in these steps contains.
  # A new dispatch step must be added to the table, because the number of steps with a `case` on the
  # part name is compared with the table size. The quote character is built with a char literal
  # because this script text is a raw string.
  dq = string('"')
  dispatch = string("case ", dq, "\$PART", dq, " in")
  legs = ("comparator", "campaign", "controls")
  unittest_steps = (
    "Stage 2B migration comparator tests",
    "Stage 2B file and fixture tests",
    "Stage 2B campaign-driver tests (including pinned-commit fingerprints)",
    "Stage 2B reset-probe checker tests",
  )
  table = [
    ("Check repository hygiene (required through analysis verdict)", "controls",
      ["python3 scripts/test_repo_hygiene.py", "python3 scripts/check_repo_hygiene.py --base 'HEAD^1'"]),
    ("Check the benchmark analysis", "controls", ["python benchmark/check_analysis.py"]),
    ("Check the sparse coordinate descent analysis", "controls",
      ["python -I benchmark/sparse_cd/check_analysis.py"]),
    ("Check the coordinatedescent comparison analysis", "controls",
      ["python -B benchmark/external/coordinatedescent/check_analysis.py"]),
    ("Pinned Stage 2B commits are in the checkout", "campaign",
      ["benchmark/campaigns/stage2b/test_stage2b_campaign.py", "git cat-file -e"]),
    ("Stage 2B migration comparator tests", "comparator",
      ["python3 -B benchmark/campaigns/stage2b/test_migration_compare.py"]),
    ("Stage 2B file and fixture tests", "controls",
      ["python3 -B benchmark/campaigns/stage2b/test_stage2b_files.py"]),
    ("Stage 2B campaign-driver tests (including pinned-commit fingerprints)", "campaign",
      ["python3 -B benchmark/campaigns/stage2b/test_stage2b_campaign.py"]),
    ("Stage 2B reset-probe checker tests", "controls",
      ["python3 -B benchmark/campaigns/stage2b/probes/test_check_reset_probes.py"]),
    ("Exact-source paired-master diagnostics", "controls",
      ["julia --startup-file=no --project=@stdlib scripts/paired_master_diagnostics.jl"]),
  ]
  steps = split(analysis, "\n      - ")
  @test count(step -> occursin(dispatch, step), steps) == length(table)
  for (name, owner, commands) in table
    matching = [step for step in steps if startswith(step, string("name: ", name, "\n"))]
    @test length(matching) == 1
    isempty(matching) && continue
    step = first(matching)
    @test occursin(dispatch, step)
    arms = [strip(arm) for arm in split(last(split(step, dispatch; limit = 2)), ";;")]
    own = join(filter(arm -> startswith(arm, string(owner, ")")), arms), "\n")
    @test length(filter(arm -> startswith(arm, string(owner, ")")), arms)) == 1
    for command in commands
      @test occursin(command, own)
    end
    if name in unittest_steps
      @test occursin("skipped=", own)
      @test occursin("Ran [1-9][0-9]* tests? in", own)
      @test occursin("grep -qx 'OK'", own)
    end
    others = setdiff(legs, (owner,))
    noop_prefixes = (string(others[1], "|", others[2], ")"), string(others[2], "|", others[1], ")"))
    noop = filter(arm -> any(prefix -> startswith(arm, prefix), noop_prefixes), arms)
    @test length(noop) == 1
    @test occursin("Not part of the", join(noop, "\n"))
    fallback = filter(arm -> startswith(arm, "*)"), arms)
    @test length(fallback) == 1
    @test occursin("::error::Unknown analysis leg", join(fallback, "\n"))
    @test occursin("exit 1", join(fallback, "\n"))
  end
end
"""

@testset "always-run paired-master policy controls" begin
  script = joinpath(dirname(@__DIR__), "scripts", "paired_master_diagnostics.jl")
  command = `$(Base.julia_cmd()) --startup-file=no --project=@stdlib -e $CONTROLS $script`
  @test success(pipeline(addenv(command, "JULIA_LOAD_PATH" => "@stdlib"); stdout = stdout, stderr = stderr))
end

end
