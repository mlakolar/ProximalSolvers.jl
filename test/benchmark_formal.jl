module BenchmarkFormalTest

using Test, LinearAlgebra, Random
import ProximalBase, ProximalSolvers

# The formal harness (benchmark/run.jl with problems.jl, certificates.jl and cases.jl) on the
# current core (#110): which cases are supported or deferred, their inputs, solvers,
# certificates and resets, the source checks, and one small set of formal records checked by
# benchmark/validate.py. Timings are recorded but never compared.
const BENCHMARK = joinpath(dirname(@__DIR__), "benchmark")
const H = Module(:FormalHarness)
Core.eval(H, :(include(path) = Base.include($H, path)))   # run.jl includes its siblings
# run.jl loads standard libraries (SHA, Statistics, Profile) that its own environment lists
# (benchmark/Project.toml) but the package's test target does not; adding them there would
# change the project hash of the committed manifests. They are loaded from the standard
# library directory for this include only.
let added = !("@stdlib" in LOAD_PATH)
  added && push!(LOAD_PATH, "@stdlib")
  try
    Base.include(H, joinpath(BENCHMARK, "run.jl"))
  finally
    added && filter!(!=("@stdlib"), LOAD_PATH)
  end
end
call(f, args...; kwargs...) = Base.invokelatest(f, args...; kwargs...)
groups() = collect(H.CASE_GROUPS)
catalog(suite = "quick"; deferred = false) = call(H.build_catalog, suite, groups(); deferred)
spec(id) = only(filter(s -> s.meta.id == id, catalog("extended")))
spec_deferred(id) = only(filter(s -> s.meta.id == id, catalog("extended"; deferred = true)))
const PB_REV = "c123d56ba1948e36a8fdbf183a9eea396a16e0d5"

const QUICK = sort!(vcat(
  ["cd/$p/cd/$(w)$i-$t/call" for (p, ws) in (("lasso", ("",)), ("lasso-B", ("", "warm-")))
   for w in ws for i in ("dense", "sparse") for t in ("f32", "f64")],
  ["gradient/$p/$solver/$(w)dense-$t/call" for solver in ("pg", "apg")
   for (p, ws) in (("lasso", ("",)), ("lasso-B", ("", "warm-"))) for w in ws for t in ("f32", "f64")],
  ["cd/lasso-dense/cd/R/call", "gradient/lasso/pg/R/call"]))

@testset "supported and deferred cases" begin
  quick, extended = catalog(), catalog("extended")
  @test [s.meta.id for s in quick] == QUICK
  @test length(extended) == 42
  @test issubset(Set(s.meta.id for s in quick), Set(s.meta.id for s in extended))
  deferred = catalog("extended"; deferred = true)
  @test length(deferred) == 100
  @test all(s -> call(H.case_available, s), extended)
  @test all(s -> !isempty(call(H.missing_requirements, s)), deferred)
  # 102 historical IDs (2 supported, 100 deferred) and 40 current-core IDs, all distinct.
  ids = [s.meta.id for s in vcat(extended, deferred)]
  @test allunique(ids) && length(ids) == 142
  for id in ("cd/lasso-dense/cd/B/call", "cd/lasso-dense/cd/R/workspace", "admm/lasso/admm/R/call",
             "gradient/lasso/apg/tight/call", "paths/lasso/cd/grid8/call", "cd/lasso-csc/cd/B/call")
    @test id in ids && !(id in [s.meta.id for s in extended])
  end
  # Requirements, not type names, gate a case: CDSolver exists, but its gap stopping does not.
  @test isdefined(ProximalSolvers, :CDSolver)
  @test "CDSolver: duality-gap stopping (gaptol > 0)" in call(H.missing_requirements, spec_deferred("cd/lasso-dense/cd/B/call"))
  # Targets per precision; current-core variants name the iterate and precision.
  for s in extended
    s.meta.variant == "R" && continue
    @test s.meta.target == (endswith(s.meta.variant, "f32") ? 1e-5 : 1e-8)
    @test s.meta.measure == "relative_gap" && s.meta.phase == "call"
  end
end

@testset "deferred requests" begin
  @test_throws ArgumentError call(H.check_deferred_request, "cd/lasso-dense/cd/B/call", "quick", groups())
  @test_throws ArgumentError call(H.check_deferred_request, "admm/*", "quick", groups())
  err = try
    call(H.check_deferred_request, "admm/lasso/admm/R/call", "quick", groups())
  catch e
    e
  end
  @test occursin("solver ADMMSolver", sprint(showerror, err)) && occursin("PS_LIST=deferred", sprint(showerror, err))
  @test call(H.check_deferred_request, "cd/lasso-dense/cd/*", "quick", groups()) ==
        ["cd/lasso-dense/cd/B/call", "cd/lasso-dense/cd/B/workspace", "cd/lasso-dense/cd/R/workspace"]
  @test isempty(call(H.check_deferred_request, "cd/lasso/cd/dense-f64/call", "quick", groups()))
  # The runner refuses at startup (exit 3) before any record, also for a group with no supported case.
  mktempdir() do dir
    for env in ("PS_CASES" => "cd/lasso-dense/cd/B/call", "PS_GROUPS" => "admm")
      withenv(env, "PS_OUTPUT" => dir, "PS_LIST" => "true") do
        @test redirect_stdio(() -> call(H.main); stderr = devnull) == 3
      end
    end
    @test isempty(readdir(dir))
  end
end

@testset "inputs: stable, shared and exact per precision" begin
  hash(id, rep = 1) = call(spec(id).make, rep).problem_hash
  # The same inputs for CD and PGD, dense and sparse starts; selection does not change them.
  @test hash("cd/lasso/cd/dense-f64/call") == hash("cd/lasso/cd/sparse-f64/call") ==
        hash("gradient/lasso/pg/dense-f64/call")
  @test hash("cd/lasso-B/cd/warm-sparse-f32/call") == hash("gradient/lasso-B/pg/warm-dense-f32/call")
  @test hash("cd/lasso/cd/dense-f64/call") == hash("cd/lasso/cd/dense-f64/call")
  @test hash("cd/lasso/cd/dense-f64/call", 1) != hash("cd/lasso/cd/dense-f64/call", 2)
  @test hash("cd/lasso/cd/dense-f64/call") != hash("cd/lasso/cd/dense-f32/call")
  @test hash("cd/lasso-B/cd/dense-f64/call") != hash("cd/lasso-B/cd/warm-dense-f64/call")
  a = call(H.regression_problem, 1, "extended/design-B"; n = 240, p = 160, design = :B)
  a32 = call(H.core_problem, a, Float32)
  @test eltype(a32.X) == Float32 && a32.X == Float32.(a.X) && iszero(a32.start)
  exact = call(H.exact_problem, a32)
  @test exact.X isa Matrix{Float64} && Float32.(exact.X) == a32.X && exact.λ == Float64(Float32(a.λ))
  # The warm start is the independently certified solution at 1.25λ.
  w = call(H.warm_start, a)
  @test count(!iszero, w) > 0
  @test call(H.lasso_certificate, a.X, a.y, a.s, 1.25a.λ, a.w, w).value <= 1e-12
end

# One timed-style observation as the runner makes it: reset, call, certify.
function observe(state)
  state.reset!()
  output = state.call!()
  output, state.certify(output)
end

@testset "solvers, resets and certificates" begin
  for s in catalog()
    state = call(s.make, 1)
    output, cert = call(observe, state)
    # The minimizer aliases the case's iterate, which reset! overwrites: keep a snapshot.
    solution = copy(Array(output.minimizer))
    @test cert.status == :ok && isfinite(cert.value)
    status = call(H.certificate_status, cert, s.meta)
    if s.meta.solver == "cd" || s.meta.variant == "R"
      @test status == :ok
    else
      # PGD stops when the objective changes by less than one rounding unit, about sqrt(eps)
      # in the coefficients; where it ends relative to the targets depends on rounding (with
      # --check-bounds=yes the small Float64 case ends at 1.7e-8 instead of 1.0e-9).
      @test status in (:ok, :target_missed)
    end
    s.meta.variant == "R" && continue
    T = endswith(s.meta.variant, "f32") ? Float32 : Float64
    sparse = occursin("sparse", s.meta.variant)
    x = output.minimizer
    @test eltype(x) == T && (x isa ProximalBase.SparseIterate) == sparse && x isa (sparse ? Any : Vector{T})
    @test (s.meta.solver == "cd" ? ProximalSolvers.CDResults : ProximalSolvers.OptimizationResults) == typeof(output).name.wrapper
    # The certificate reads only the returned point: a copy certifies identically, and the
    # start is not a solution.
    @test state.certify((; minimizer = copy(Array(x)))).value == cert.value
    state.reset!()
    start = copy(Array(x))
    @test call(H.certificate_status, state.certify((; minimizer = start)), s.meta) == :target_missed
    # Reset restores the start exactly (for a SparseIterate, its active set too), and a
    # repeated call returns the same point.
    if sparse
      @test ProximalBase.nactive(x) == count(!iszero, start)
      @test sort(collect(ProximalBase.activecoordinates(x))) == findall(!iszero, start)
    end
    again, _ = call(observe, state)
    @test Array(again.minimizer) == solution
  end
  # Certificates: the Float64 reference solution, its Float32 rounding, and a perturbation.
  a = call(H.regression_problem, 1, "core/lasso")
  ref = zeros(size(a.X, 2))
  ProximalSolvers.solve!(ref, a.s * ProximalBase.LeastSquaresLoss(a.y, a.X), ProximalBase.NormL1(a.λ),
                         ProximalSolvers.CDSolver(order = :cyclic, tol = 1e-14))
  @test call(H.certify, a, ref).value < 1e-13
  a32 = call(H.exact_problem, call(H.core_problem, a, Float32))
  @test 0 < call(H.certify, a32, Float64.(Float32.(ref))).value < 1e-6
  @test call(H.certify, a, ref .+ 1e-3).value > 1e-6
end

@testset "source identity checks" begin
  base = call(H.proximalbase_identity)
  @test base.source == "git" && base.rev == PB_REV && base.slug_matches
  @test call(H.check_proximalbase, base, "") === nothing
  @test call(H.check_proximalbase, base, PB_REV) === nothing
  @test_throws ErrorException call(H.check_proximalbase, base, "0"^40)
  @test_throws ErrorException call(H.check_proximalbase, merge(base, (; rev = "master")), "")
  @test_throws ErrorException call(H.check_proximalbase, merge(base, (; slug_matches = false)), "")
  @test_throws ErrorException call(H.check_package_revision, dirname(@__DIR__), "0"^40)
  # The loaded checkout's own pin is enforced without PS_EXPECTED_PROXIMALBASE_REV: another
  # full commit and tree (a valid, installed ProximalBase 0.6) is refused, as are path and
  # registry sources and a tree other than the one the committed manifests record.
  pin = call(H.checkout_base_pin, dirname(@__DIR__))
  @test pin.rev == PB_REV && pin.url == "https://github.com/mlakolar/ProximalBase.jl"
  @test pin.trees == ["c2e2ddde114a1e7800358595193ee0869830180d"] && base.tree in pin.trees
  @test call(H.check_proximalbase, base, "", pin) === nothing
  other = merge(base, (; rev = "eb74a914d779371a02e4a6637eaa724aeb66fdf5",
                         tree = "d1da2065a3895cb90aa5d0dd1a008c482602bd00"))
  @test call(H.check_proximalbase, other, "") === nothing          # no pin: historical modes
  @test_throws ErrorException call(H.check_proximalbase, other, "", pin)
  @test_throws ErrorException call(H.check_proximalbase, merge(base, (; url = "https://example.org/ProximalBase.jl")), "", pin)
  @test_throws ErrorException call(H.check_proximalbase, merge(base, (; source = "path", rev = "", url = "")), "", pin)
  @test_throws ErrorException call(H.check_proximalbase, merge(base, (; source = "registry", rev = "", url = "")), "", pin)
  @test_throws ErrorException call(H.check_proximalbase, base, "", merge(pin, (; trees = ["0"^40])))
  @test_throws ErrorException call(H.check_proximalbase, base, "", merge(pin, (; rev = "master")))
  # The historical environment template is unchanged (Stage 2A verification reads it).
  @test occursin("ProximalBase = \"0.5\"", read(joinpath(BENCHMARK, "Project.toml"), String))
end

@testset "entry points refuse an unpinned ProximalBase" begin
  # The test environment with its ProximalBase entry switched to a moving branch: run.jl and
  # local.jl (fresh processes, the real entry points) must both stop with exit 3 before any
  # case runs. The loaded code is unchanged, only the manifest identity differs.
  project = Base.active_project()
  manifest = Base.project_file_manifest_path(project)
  mktempdir() do dir
    cp(project, joinpath(dir, "Project.toml"))
    text = read(manifest, String)
    @test occursin("repo-rev = \"$PB_REV\"", text)
    write(joinpath(dir, basename(manifest)), replace(text, "repo-rev = \"$PB_REV\"" => "repo-rev = \"master\""))
    for name in readdir(dirname(manifest))   # other manifests or preferences of the environment
      name in (basename(manifest), "Project.toml") || cp(joinpath(dirname(manifest), name), joinpath(dir, name))
    end
    env = ("JULIA_LOAD_PATH" => "@:@stdlib", "JULIA_PROJECT" => dir, "JULIA_NUM_THREADS" => "1",
           "PS_OUTPUT" => joinpath(dir, "records"))
    julia = `$(Base.julia_cmd()) --startup-file=no`
    for script in (`$(joinpath(BENCHMARK, "run.jl"))`,
                   `$(joinpath(BENCHMARK, "local.jl")) cd/lasso/cd/dense-f64/call --samples 1 --min 1`)
      out = IOBuffer()
      process = run(pipeline(ignorestatus(addenv(`$julia $script`, env...)); stdout = out, stderr = out))
      text = String(take!(out))
      @test process.exitcode == 3
      @test occursin("moving revision \"master\"", text)
    end
    @test !isdir(joinpath(dir, "records"))
  end
end

function python311()
  for exe in ("python3", "python")
    path = Sys.which(exe)
    path === nothing && continue
    ok = success(pipeline(`$path -c "import sys; assert sys.version_info >= (3, 11)"`; stderr = devnull))
    ok && return path
  end
  nothing
end

@testset "formal records" begin
  mktempdir() do dir
    out = joinpath(dir, "records")
    selected = join(["cd/lasso/cd/dense-f64/call", "cd/lasso/cd/sparse-f32/call",
                     "gradient/lasso/pg/dense-f64/call", "gradient/lasso/pg/dense-f32/call"], ',')
    threads = LinearAlgebra.BLAS.get_num_threads()
    code = try
      withenv("PS_OUTPUT" => out, "PS_CASES" => selected, "PS_SAMPLES" => "5", "PS_SECONDS" => "0.001",
              "PS_EXPECTED_PROXIMALBASE_REV" => PB_REV, "PS_LIST" => nothing) do
        redirect_stdio(() -> call(H.main); stdout = devnull, stderr = devnull)
      end
    finally
      LinearAlgebra.BLAS.set_num_threads(threads)
    end
    # Exit 2: complete records with a non-ok case (PGD in Float32 misses its target).
    @test code in (0, 2)
    meta = H.TOML.parsefile(only(filter(endswith("-metadata.toml"), readdir(out; join = true))))
    @test meta["finished"] && meta["cases"] == 4 && meta["proximalbase_rev"] == PB_REV
    @test meta["proximalbase_source"] == "git" && meta["case_filter"] == selected
    @test meta["harness_hash"] == call(H.fingerprint, BENCHMARK,
      [joinpath(BENCHMARK, f) for f in ("problems.jl", "certificates.jl", "cases.jl", "run.jl")])
    python = python311()
    if python === nothing
      # CI has Python 3.11 or later; a local run without it says so instead of passing.
      get(ENV, "CI", "") == "true" ? @test(python !== nothing) : @test_skip "validate.py needs Python 3.11"
    else
      report = joinpath(dir, "validation.json")
      @test success(pipeline(`$python -B $(joinpath(BENCHMARK, "validate.py")) $out $report`; stdout = devnull))
    end
  end
end

end
