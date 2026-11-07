# Test of the Stage 2B fingerprint exporter (export_fingerprints.jl, #110 Stage 4). Nothing here is timed.
#
# From the repository root, in an environment that provides the benchmark dependencies
# (benchmark/Project.toml) and the standard libraries (Test is one):
#   JULIA_NUM_THREADS=1 julia --project=ENV benchmark/campaigns/stage2b/test_export_fingerprints.jl
#
# Environment variables (all optional):
#   PS_FP_HARNESS   the harness directory to test (run.jl, problems.jl, cases.jl, certificates.jl);
#                   default: this checkout's benchmark/
#   PS_FP_FULL      "true" also exports all 19 scheduled cases for repetitions 1-2 and validates the file
#
# Groups: 1 the encoder (pairs that must differ, unsupported types, known answers); 2 the real cases through
# the harness: identity checks, data_hash against problem_hash, the reset semantics of P14, P04, P13 and D04, the
# certificate file identity, fail-closed adapters; 3 the command line: determinism and refusals; 4 (optional)
# the full scheduled export. The script exits non-zero when a check fails and prints
# `FINGERPRINT EXPORTER TEST: PASS` or `FINGERPRINT EXPORTER TEST: FAIL` as its last line.

using Test, Random, LinearAlgebra, SparseArrays, TOML
import ProximalBase, ProximalSolvers

include(joinpath(@__DIR__, "export_fingerprints.jl"))
using .ExportFingerprints
const E = ExportFingerprints
const PB = ProximalBase
const PS = ProximalSolvers

const HARNESS_DIR = abspath(get(ENV, "PS_FP_HARNESS", joinpath(@__DIR__, "..", "..")))
const FULL = get(ENV, "PS_FP_FULL", "false") == "true"
const GROUPS = ["admm", "cd", "gradient", "newton", "paths", "primal_dual", "sgl"]
const IDS = (P02 = "cd/lasso-csc/cd/B/call", P03 = "cd/lasso-dense/cd/B/workspace",
             P04 = "cd/group-lasso/cd/tight/call", P13 = "admm/lasso/admm/construction/setup",
             P14 = "paths/lasso/cd/grid8/call", D04 = "primal_dual/generalized-lasso/condat-vu/tight/call")

println("FINGERPRINT EXPORTER TEST: Julia ", VERSION, ", ProximalBase ", pkgversion(PB), ", ProximalSolvers ",
        pkgversion(PS), ", threads ", Threads.nthreads(), ", harness ", basename(HARNESS_DIR))

function run_group(body, name)
  passed = try
    @testset "$name" begin
      body()
    end
    true
  catch err
    err isa Test.TestSetException || rethrow()
    false
  end
  println("EXPORTER GROUP ", name, ": ", passed ? "PASS" : "FAIL")
  passed
end

fp(x) = E.fingerprint("fixture", "t", x)
hex64(s) = occursin(r"^[0-9a-f]{64}$", s)
differ(a, b) = fp(a) != fp(b)
rejects(x) = try
  fp(x)
  false
catch err
  err isa E.EncodeError
end

# ---- 1. The encoder -------------------------------------------------------------------------------
# Known answers: identical on Julia 1.10 and 1.13 (the encoding never depends on Julia's hash or printing). The first
# 14 were also reproduced by an independent implementation of the documented encoding written in Python.
# Regenerate with PS_FP_PRINT_KNOWN=true after a deliberate change of the encoding (a new version name).
known_payloads() = [
  ("nothing", nothing), ("bool", true), ("int64", 42), ("int32", Int32(-7)), ("float64", 0.1),
  ("negative_zero", -0.0), ("float32", 1.5f0), ("string", "λ"), ("symbol", :lasso),
  ("tuple", (1, 2.0, "x")), ("namedtuple", (; a = 1, b = [1.0, 2.0])),
  ("matrix", [1.0 2.0 3.0; 4.0 5.0 6.0]), ("groups", [[1, 2], [3, 4, 5]]),
  ("sparse", sparse([1, 2, 3], [1, 2, 3], [1.0, 0.0, -2.5], 3, 4)),
  ("options", PS.ProximalOptions(maxiter = 100)),
  ("cd_task_local", PS.CDSolver(order = :cyclic, rng = Random.default_rng()))]
const KNOWN = Dict{String, String}(
  "nothing" => "6f1a76d05bf6ce758ed0ae02017d667ebef58fa3179b8da714132f7f632d25af",
  "bool" => "b9b79e6fe26e25a0c92e2bc59a0e22acdcb68ea94da932c88cb110d34cb1f0a5",
  "int64" => "e8e1f4479b50fa8195c9920bb1fbaf9377398ee41a9c84293a5667cfdd372df8",
  "int32" => "130385115bb2494ef046b1c6a7caa2c6a54619b8ea8204642d52ba2c1664e9f5",
  "float64" => "d98125cabefdae46175a6f31fe625620a82ff1a18870f220f27ab1e10c16e8ee",
  "negative_zero" => "de47e7e49bf46fbd58a1a01e6a550e5c424677de6a1ff2c93182f1e49f1e37e5",
  "float32" => "f23a95db5d8ec7ac62775d260d510de4c044c4908232fe1d4af94e470de28cc8",
  "string" => "b87aa034c72e19f473c72ff5bb7c20b9ffe5a7c2772723bd92b4001c7b933e73",
  "symbol" => "9486ade02b4b9dce1acaf51e42ff985f3d09689fef5294ac451a6aaac9ea8164",
  "tuple" => "f4c6127bcf2363d5f3cdfaeb5a751249b5b9ded71a779b5b360a2684f917db3b",
  "namedtuple" => "3e78a76b0755e1bced2bff6bcf8f94f84ee026a60c0091dcf598ae426de1db16",
  "matrix" => "71f67ec3328fcd27c88cc69b4dfe5a46d26fa596b638a982c2a590b668d9a134",
  "groups" => "1e98f425d3c7435ea5ecf191c31df49f3dfd29395359e34d7b341fd95baa7ca1",
  "sparse" => "ff40ea2b29c6cb17f5224ed2df9b8f32f9c894f35824e5415407328c68da63c8",
  "options" => "6ecf96da8106b24c92dcbfa24d32ce5f1e02f6b6e6b91ecf937a757e6f00d1c8",
  "cd_task_local" => "a6ddd1793e3008ac7519d63fa60cad4529896ee03fd6f673a78e75441dd03f94")

encoder_ok = run_group("encoder") do
  nan1 = reinterpret(Float64, 0x7ff8000000000001)
  nan2 = reinterpret(Float64, 0x7ff8000000000002)
  @test isnan(nan1) && isnan(nan2)
  @testset "pairs that must differ" begin
    @test differ(0.0, -0.0)
    @test differ([0.0, 1.0], [-0.0, 1.0])
    @test differ(nan1, nan2)
    @test differ([nan1], [nan2])
    @test fp(nan1) == fp(nan1)
    @test differ(1.0, 1f0) && differ([1.0], [1f0])
    @test differ(1, 1.0) && differ(Int32(1), 1) && differ(true, 1)
    @test differ(:a, "a") && differ("a", "b")
    shapes = [zeros(3), zeros(3, 1), zeros(1, 3), zeros(3, 1, 1)]
    @test length(unique(fp.(shapes))) == length(shapes)
    @test differ(zeros(2, 3), zeros(3, 2)) && differ([1.0 2.0; 3.0 4.0], [1.0 3.0; 2.0 4.0])
    @test differ((; a = 1), (; b = 1)) && differ((1, 2), [1, 2]) && differ((1, 2), (2, 1))
    @test differ("ab", ("a", "b")) && differ(nothing, "nothing") && differ(nothing, false)
    base = sparse([1, 2], [1, 2], [1.0, 2.0], 3, 3)
    stored_zero = sparse([1, 2, 3], [1, 2, 3], [1.0, 2.0, 0.0], 3, 3)
    absent = sparse([1, 2], [1, 2], [1.0, 2.0], 3, 3)
    @test nnz(stored_zero) == 3 && nnz(absent) == 2
    @test differ(stored_zero, absent) && fp(base) == fp(absent)
    @test differ(base, sparse([1, 2], [1, 3], [1.0, 2.0], 3, 3))   # another pattern
    @test differ(base, sparse([1, 2], [1, 2], [1.0, 2.0], 3, 4))   # another shape
    @test differ(base, sparse([1, 2], [1, 2], [1.0, 2.0], 4, 3))
    @test differ(base, sparse([1, 2], [1, 2], [1.0, -2.0], 3, 3))
    @test differ(base, Matrix(base))                               # sparse against dense
    I, J, V = findnz(sparse([1, 3, 2], [1, 1, 2], [1.0, 2.0, 3.0], 3, 3))
    @test differ((I, J, V), (I[[2, 1, 3]], J[[2, 1, 3]], V[[2, 1, 3]]))   # a permuted findnz order
    unsorted = SparseMatrixCSC(3, 1, [1, 3], [3, 1], [1.0, 2.0])
    @test rejects(unsorted)
    @test differ([[1, 2], [3, 4]], [[1], [2, 3, 4]]) && differ([[1, 2], [3]], [[1], [2, 3]])
    @test differ([[1, 2], [3, 4]], [[1, 2, 3], [4]]) && differ([[1, 2], [3, 4]], [[3, 4], [1, 2]])
    empty_set = E.fingerprint("reset", "active_ids", Int[])
    @test hex64(empty_set) && empty_set != "none"
    @test E.fingerprint("reset", "active_ids", Int[]) != E.fingerprint("reset", "active_ids", [0])
    @test E.fingerprint("fixture", "X", 1) != E.fingerprint("fixture", "y", 1)
    @test E.fingerprint("fixture", "X", 1) != E.fingerprint("reset", "X", 1)
    @test fp(1) == fp(1) && hex64(fp(1))
  end
  @testset "unsupported values are errors" begin
    for bad in (sin, x -> x, Ptr{Nothing}(0), Main, stdout, Float64, Core.Box(1), Dict(1 => 2),
                Complex(1.0, 2.0), big(1), view(rand(3), 1:2), Any[1], 'a', 1:3, Ref(1),
                (; f = sin), [sin], PS.ProximalOptions(callback = sin))
      @test rejects(bad)
    end
  end
  @testset "solver and option structs" begin
    @test fp(PS.ProximalOptions(maxiter = 100)) != fp(PS.ProximalOptions(maxiter = 101))
    @test fp(PS.ProximalOptions(gaptol = 1e-10)) != fp(PS.ProximalOptions(gaptol = 1e-8))
    @test fp(PS.CDSolver(tol = 1e-11)) != fp(PS.CDSolver(tol = 1e-10))
    @test fp(PS.CDSolver(order = :cyclic)) != fp(PS.CDSolver(order = :random))
    @test fp(PS.CDSolver(rng = Xoshiro(9))) == fp(PS.CDSolver(rng = Xoshiro(9)))
    @test fp(PS.CDSolver(rng = Xoshiro(9))) != fp(PS.CDSolver(rng = Xoshiro(10)))
    @test fp(PS.CDSolver(rng = Xoshiro(9))) != fp(PS.CDSolver(rng = Random.default_rng()))
    @test fp(PS.AccProxGradDescent()) != fp(PS.AccProxGradDescent(β = 0.4))
    @test fp(PS.AccProxGradDescent()) == fp(PS.AccProxGradDescent())
    c = E.Ctx()
    E.enc!(c, PS.CDSolver(rng = Random.default_rng()))
    @test c.tls
    c = E.Ctx()
    E.enc!(c, PS.CDSolver(rng = Xoshiro(9)))
    @test !c.tls
  end
  @testset "known answers" begin
    payloads = known_payloads()
    if get(ENV, "PS_FP_PRINT_KNOWN", "false") == "true"
      for (label, payload) in payloads
        println("KNOWN ", label, " ", E.fingerprint("fixture", label, payload))
      end
    end
    for (label, payload) in payloads
      @test E.fingerprint("fixture", label, payload) == KNOWN[label]
    end
  end
end

# ---- 2. The real cases through the harness -----------------------------------------------------------
H = E.load_harness(HARNESS_DIR)
const CERT = E.hex_file(joinpath(HARNESS_DIR, "certificates.jl"))

catalog_spec(H, id; groups = GROUPS) = first(s for s in H.build_catalog("extended", groups) if s.meta.id == id)
parts_of(H, spec, state = spec.make(1)) = E.extract_parts(H, spec.meta, state, CERT)
cell(result, kind, name) = first(v for (k, n, v) in result.rows if k == kind && n == name)
bits(v) = collect(reinterpret(UInt64, collect(Float64, v)))

# Copy the four harness files to a fresh directory (the harness is never modified in place).
function copied_harness(f)
  mktempdir() do dir
    for name in E.HARNESS_FILES
      cp(joinpath(HARNESS_DIR, name), joinpath(dir, name))
    end
    f(dir)
  end
end

harness_ok = run_group("real cases") do
  @testset "the harness checks" begin
    @test E.check_certify_methods(H, HARNESS_DIR) >= 1
    @test E.harness_hash(HARNESS_DIR) == H.fingerprint(HARNESS_DIR, [joinpath(HARNESS_DIR, n) for n in E.HARNESS_FILES])
  end
  @testset "every checked case exports; data_hash equals problem_hash" begin
    for id in IDS
      spec = catalog_spec(H, id)
      result = E.export_case(H, spec.meta, spec.make, 1, CERT)
      @test result.data_hash == spec.make(1).problem_hash
      @test hex64(result.data_hash)
      kinds = [(k, n) for (k, n, _) in result.rows]
      @test allunique(kinds)
      for key in E.ROW_ORDER
        @test key in kinds
      end
      @test any(k == "fixture" for (k, _) in kinds)
      @test all(v -> hex64(v) || v == "none", last.(result.rows))
      @test cell(result, "file", "certificates.jl") == CERT
      println("EXPORTER INFO ", id, ": family ", result.family, ", ", length(result.rows), " rows, cold differences ",
              result.cold_differences)
    end
  end
  @testset "closure identities" begin
    spec = catalog_spec(H, IDS.P02)
    state = spec.make(1)
    @test getfield(state.reset!, :x) === getfield(state.call!, :x)
    @test getfield(state.reset!, :method) === getfield(state.call!, :method)
    @test E.family(spec.meta) == :call
    spec = catalog_spec(H, IDS.P03)
    state = spec.make(1)
    @test getfield(state.reset!, :workspace) === getfield(state.call!, :workspace)
    parts = parts_of(H, spec, state)
    @test parts.family == :workspace && parts.iterate === parts.workspace.x
    @test parts.solver === getfield(state.reset!, :method) && parts.options === parts.workspace.options
    spec = catalog_spec(H, IDS.D04)
    state = spec.make(1)
    @test getfield(state.reset!, :x) === getfield(state.call!, :x)
    @test getfield(state.reset!, :y) === getfield(state.call!, :y)
    @test getfield(getfield(state.call!, :gap), :a) === getfield(state.certify, :a)
    parts = parts_of(H, spec, state)
    @test parts.family == :primal_dual && parts.iterate[1] === getfield(state.call!, :x)
    @test parts.iterate[2] === getfield(state.call!, :y)
  end
  @testset "a second make is identical field by field" begin
    spec = catalog_spec(H, IDS.P14)
    a1, a2 = parts_of(H, spec), parts_of(H, spec)
    @test [E.fingerprint("fixture", n, v) for (n, v) in E.fixture_items(a1)] ==
          [E.fingerprint("fixture", n, v) for (n, v) in E.fixture_items(a2)]
    names = first.(E.fixture_items(a1))
    @test "grid" in names && "X" in names && issorted(names)
  end
  @testset "P14: the cold reset empties the working set" begin
    spec = catalog_spec(H, IDS.P14)
    state = spec.make(1)
    parts = parts_of(H, spec, state)
    x = parts.iterate
    @test x isa PB.SparseIterate
    state.call!()
    used = E.snapshot_rows(parts, E.tls_copy())
    state.reset!()
    @test PB.nactive(x) == 0 && isempty(PB.activecoordinates(x)) && all(iszero, collect(Float64, x))
    rows = E.snapshot_rows(parts, E.tls_copy())
    empty_set = E.fingerprint("reset", "active_ids", Int[])
    @test rows[("reset", "active_ids")] == empty_set && empty_set != "none"
    @test rows[("reset", "values")] ==
          E.fingerprint("reset", "values", (; iterate = (; type = "SparseIterate", values = zeros(length(x))), rng = nothing))
    # the same state before the reset is another state (a used solver call leaves values and a working set)
    @test used[("reset", "values")] != rows[("reset", "values")]
    # Negative check: writing into the captured iterate after the reset changes the hash.
    x[3] = 1.5
    changed = E.snapshot_rows(parts, E.tls_copy())
    @test changed[("reset", "values")] != rows[("reset", "values")]
    @test changed[("reset", "active_ids")] != rows[("reset", "active_ids")]
    state.reset!()
    @test E.snapshot_rows(parts, E.tls_copy())[("reset", "values")] == rows[("reset", "values")]
    # The exported rows are those of the state after reset, one call, reset.
    result = E.export_case(H, spec.meta, spec.make, 1, CERT)
    @test cell(result, "reset", "active_ids") == empty_set
    @test cell(result, "reset", "values") == rows[("reset", "values")]
    # The dense iterate of the SLOPE path has no working set.
    slope = catalog_spec(H, "paths/slope/slope-apg/grid8/call")
    sres = E.export_case(H, slope.meta, slope.make, 1, CERT)
    @test cell(sres, "reset", "active_ids") == "none" && sres.family == :path
  end
  @testset "P04: the active groups are restored to the empty set" begin
    spec = catalog_spec(H, IDS.P04)
    state = spec.make(1)
    parts = parts_of(H, spec, state)
    x = parts.iterate
    @test x isa PB.AtomIterate
    state.call!()
    @test PB.nactive(x) > 0
    state.reset!()
    @test PB.nactive(x) == 0 && isempty(PB.activecoordinates(x)) && all(iszero, collect(Float64, x))
    rows = E.snapshot_rows(parts, E.tls_copy())
    @test rows[("reset", "active_ids")] == E.fingerprint("reset", "active_ids", Int[])
    result = E.export_case(H, spec.meta, spec.make, 1, CERT)
    @test cell(result, "reset", "active_ids") == rows[("reset", "active_ids")]
    @test "groups" in [n for (k, n, _) in result.rows if k == "fixture"]
  end
  @testset "P13: the setup case has no iterate" begin
    spec = catalog_spec(H, IDS.P13)
    result = E.export_case(H, spec.meta, spec.make, 1, CERT)
    @test result.family == :setup
    @test cell(result, "reset", "values") == "none" && cell(result, "reset", "active_ids") == "none"
    descriptor = (; setup = "admm")
    @test cell(result, "config", "solver") == E.fingerprint("config", "solver", descriptor)
    @test cell(result, "config", "options") == E.fingerprint("config", "options", descriptor)
  end
  @testset "D04: the certificate file is part of the identity" begin
    spec = catalog_spec(H, IDS.D04)
    base = E.export_case(H, spec.meta, spec.make, 1, CERT)
    @test cell(base, "file", "certificates.jl") == CERT
    @test cell(base, "reset", "active_ids") == "none"
    copied_harness() do dir
      open(joinpath(dir, "certificates.jl"), "a") do io
        write(io, "\n")   # one byte
      end
      cert = E.hex_file(joinpath(dir, "certificates.jl"))
      @test cert != CERT
      H2 = E.load_harness(dir)
      Base.invokelatest() do
        @test E.check_certify_methods(H2, dir) >= 1
        spec2 = catalog_spec(H2, IDS.D04)
        changed = E.export_case(H2, spec2.meta, spec2.make, 1, cert)
        @test cell(changed, "file", "certificates.jl") == cert != cell(base, "file", "certificates.jl")
        # everything else is the same state
        @test [r for r in changed.rows if r[1] != "file"] == [r for r in base.rows if r[1] != "file"]
      end
    end
    # A certify method outside certificates.jl fails closed.
    copied_harness() do dir
      open(joinpath(dir, "cases.jl"), "a") do io
        write(io, "\ncertify(::Int, ::Int) = 1\n")
      end
      H3 = E.load_harness(dir)
      Base.invokelatest() do
        @test_throws E.VerifyError E.check_certify_methods(H3, dir)
      end
    end
  end
  @testset "fail closed on a changed closure layout" begin
    spec = catalog_spec(H, IDS.P02)
    real = spec.make(1)
    fake = H.CaseState(() -> nothing, () -> nothing, output -> nothing, "h")
    err = try
      E.export_case(H, spec.meta, rep -> fake, 1, CERT)
      nothing
    catch e
      e
    end
    @test err isa E.VerifyError && occursin(spec.meta.id, err.msg) && occursin("fields are", err.msg)
    # a reset! without the captured iterate, the real call! and certify
    nox = H.CaseState(() -> nothing, real.call!, real.certify, real.problem_hash)
    err = try
      E.export_case(H, spec.meta, rep -> nox, 1, CERT)
      nothing
    catch e
      e
    end
    @test err isa E.VerifyError && occursin("field x", err.msg) && occursin(spec.meta.id, err.msg)
    # a problem hash that does not belong to the captured fixture
    wrong = H.CaseState(real.reset!, real.call!, real.certify, "0"^64)
    err = try
      E.export_case(H, spec.meta, rep -> wrong, 1, CERT)
      nothing
    catch e
      e
    end
    @test err isa E.VerifyError && occursin("data_hash", err.msg)
    # a case of a known id whose family does not fit the closure it was built with
    p13 = catalog_spec(H, IDS.P13)
    @test_throws E.VerifyError E.export_case(H, p13.meta, rep -> real, 1, CERT)
    # an iterate of an unexpected type
    @test_throws E.VerifyError E.check_iterate("id", view(zeros(3), 1:2), "x")
  end
end

# ---- 3. The command line -----------------------------------------------------------------------------
function write_schedule(path, ids; reps = [1, 2])
  open(path, "w") do io
    TOML.print(io, Dict("schedule" => Dict("reps" => reps),
                        "settings" => Dict("suite" => "extended", "groups" => join(GROUPS, ','),
                                           "case_filter" => join(ids, ',')),
                        "julia" => Dict("x" => Dict("version" => string(VERSION)))))
  end
end

function cli(dir, name, schedule; reps = "1-2", hash = E.harness_hash(HARNESS_DIR), harness = HARNESS_DIR,
             root = dirname(dirname(pathof(PS))))
  out = joinpath(dir, name)
  args = ["--harness", harness, "--expected-package-root", root, "--schedule", schedule, "--reps", reps,
          "--expected-harness-hash", hash, "--out", out]
  code = redirect_stderr(devnull) do
    E.main(args)
  end
  code, out
end

cli_ok = run_group("command line") do
  mktempdir() do dir
    ids = collect(IDS)
    schedule = joinpath(dir, "schedule.toml")
    write_schedule(schedule, ids)
    c1, o1 = cli(dir, "a.tsv", schedule)
    c2, o2 = cli(dir, "b.tsv", schedule)
    @test c1 == 0 && c2 == 0
    @test read(o1) == read(o2)
    @test read(o1 * ".datahash.tsv") == read(o2 * ".datahash.tsv")
    @test read(o1 * ".summary.toml") == read(o2 * ".summary.toml")
    text = String(read(o1))
    @test startswith(text, "julia\tid\trep\tkind\tname\tvalue\n") && endswith(text, "\n") && !occursin('\r', text)
    lines = split(chomp(text), '\n')
    rows = [split(l, '\t') for l in lines[2:end]]
    @test all(length(r) == 6 for r in rows)
    @test length(unique((r[1], r[2], r[3], r[4], r[5]) for r in rows)) == length(rows)   # no duplicate key
    @test unique(r[2] for r in rows) == sort(ids)                                          # catalog order
    @test unique((r[2], r[3]) for r in rows)[1:2] == [(sort(ids)[1], "1"), (sort(ids)[1], "2")]
    summary = TOML.parsefile(o1 * ".summary.toml")
    @test summary["encoding"] == "ps-stage2b-fp-v1" && summary["cases"] == length(ids)
    @test length(summary["exporter_sha256"]) == 64 && summary["harness_hash"] == E.harness_hash(HARNESS_DIR)
    datahash = split(chomp(String(read(o1 * ".datahash.tsv"))), '\n')
    @test datahash[1] == "julia\tid\trep\tdata_hash" && length(datahash) == 1 + 2 * length(ids)
    # Refusals: an existing output, a wrong harness hash, another package root, an undeclared Julia version.
    @test first(cli(dir, "a.tsv", schedule)) == 2
    @test first(cli(dir, "c.tsv", schedule; hash = "0"^40)) == 2
    @test first(cli(dir, "d.tsv", schedule; root = dir)) == 2
    @test !ispath(joinpath(dir, "c.tsv")) && !ispath(joinpath(dir, "d.tsv"))
    other = joinpath(dir, "other.toml")
    write_schedule(other, ids)
    write(other, replace(read(other, String), string(VERSION) => "0.0.1"))
    @test first(cli(dir, "e.tsv", other)) == 2
    @test first(cli(dir, "f.tsv", schedule; reps = "3")) == 2   # not a declared repetition
    @test first(cli(dir, "g.tsv", schedule; reps = "x")) == 1
    @test redirect_stderr(() -> E.main(String[]), devnull) == 1
    @test redirect_stderr(() -> E.main(["--bogus", "1"]), devnull) == 1
    @test E.parse_reps("1-3,5") == [1, 2, 3, 5]
  end
end

# ---- 4. The full scheduled export (opt-in) -----------------------------------------------------------
full_ok = !FULL || run_group("full scheduled export, repetitions 1-2") do
  schedule = joinpath(@__DIR__, "schedule.toml")
  sched = E.read_schedule(schedule)
  ids = String.(split(sched.case_filter, ','))
  @test length(ids) == 19
  mktempdir() do dir
    code, out = cli(dir, "full.tsv", schedule; reps = "1-2")
    @test code == 0
    lines = split(chomp(String(read(out))), '\n')
    rows = [split(l, '\t') for l in lines[2:end]]
    keys_ = [(r[2], parse(Int, r[3]), r[4], r[5]) for r in rows]
    @test allunique(keys_)
    allowed = Set([("reset", "values"), ("reset", "active_ids"), ("config", "solver"), ("config", "options"),
                   ("file", "certificates.jl")])
    for id in ids, rep in 1:2
      mine = [r for r in rows if r[2] == id && r[3] == string(rep)]
      @test !isempty(mine)
      have = Set((r[4], r[5]) for r in mine)
      @test all(k -> k in have, allowed) && any(r[4] == "fixture" for r in mine)
      @test all(r -> r[4] == "fixture" || (r[4], r[5]) in allowed, mine)
      @test all(r -> hex64(r[6]) || (r[6] == "none" && r[4] == "reset" &&
                    (r[5] == "active_ids" || (r[5] == "values" && endswith(id, "/setup")))), mine)
    end
    @test length(unique(r[2] for r in rows)) == 19
    println("EXPORTER INFO full export: ", length(rows), " rows, ", length(ids), " cases, repetitions 1-2")
  end
end

passed = encoder_ok & harness_ok & cli_ok & full_ok
println("FINGERPRINT EXPORTER TEST: ", passed ? "PASS" : "FAIL")
exit(passed ? 0 : 1)
