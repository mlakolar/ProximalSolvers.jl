# Test of the Stage 2B fingerprint exporter (export_fingerprints.jl, #110 Stage 4). Nothing here is timed.
#
# From the repository root, in an environment that provides the benchmark dependencies
# (benchmark/Project.toml) and the standard libraries (Test is one):
#   JULIA_NUM_THREADS=1 julia --project=ENV benchmark/campaigns/stage2b/test_export_fingerprints.jl
#
# Environment variables (all optional):
#   PS_FP_HARNESS   the harness directory to test (run.jl, problems.jl, cases.jl, certificates.jl);
#                   default: this checkout's benchmark/
#   PS_FP_SCHEDULE  the schedule of the optional full export; default: stage2b/schedule.toml next to this file
#                   (the successor campaign: ../stage2b-cd/schedule.toml)
#   PS_FP_FULL      "true" also exports every scheduled case for repetitions 1-2 and validates the file
#
# Two harness generations are covered, chosen by what the harness catalog offers. The CURRENT-CORE harness (the
# 21 cd cases of cases.jl core_case_state and the release case cd/lasso-dense/cd/R/call: ProximalSolvers 9f86a808
# and the Stack A harness port of #333) runs on ProximalBase 0.5.4 and on the minimal-core ProximalBase alike. The
# LEGACY harness (the 19 cases of Stage 2A, PS_FP_HARNESS pointing at the frozen harness of 412063d8) needs the
# solver families that the minimal core removed, so its testsets run only where the catalog has those cases; on
# the minimal core they are inapplicable and are not restored (#333).
#
# Groups: 1 the encoder (pairs that must differ, unsupported types, known answers); 2 the real cases through
# the harness: identity checks, data_hash against problem_hash, the reset semantics (current core: the working set
# of the sparse starts and the Float32 problem; legacy: P14, P04, P13 and D04), the certificate file identity,
# fail-closed adapters; 3 the command line: determinism and refusals; 4 (optional) the full scheduled export (with
# an atomic-publication group before it). The script exits non-zero when a check fails and prints
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
const SCHEDULE = abspath(get(ENV, "PS_FP_SCHEDULE", joinpath(@__DIR__, "schedule.toml")))
const CD_SCHEDULE = abspath(joinpath(@__DIR__, "..", "stage2b-cd", "schedule.toml"))
const GROUPS = ["admm", "cd", "gradient", "newton", "paths", "primal_dual", "sgl"]
# The legacy (Stage 2A) cases of the testsets that need the removed solver families.
const IDS = (P02 = "cd/lasso-csc/cd/B/call", P03 = "cd/lasso-dense/cd/B/workspace",
             P04 = "cd/group-lasso/cd/tight/call", P13 = "admm/lasso/admm/construction/setup",
             P14 = "paths/lasso/cd/grid8/call", D04 = "primal_dual/generalized-lasso/condat-vu/tight/call")
# Current-core cases: dense and sparse, cold and warm, Float64 and Float32, and the release case.
const CORE = (dense = "cd/lasso/cd/dense-f64/call", sparse = "cd/lasso/cd/sparse-f64/call",
              dense32 = "cd/lasso/cd/dense-f32/call", sparse32 = "cd/lasso-B/cd/sparse-f32/call",
              warm = "cd/lasso-B/cd/warm-dense-f64/call", warm_sparse = "cd/lasso-B/cd/warm-sparse-f64/call",
              release = "cd/lasso-dense/cd/R/call")

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

# Stand-ins for the CDSolver of the two stacks, in modules named ProximalSolvers as the encoder expects (it reads the
# owner module and the type name): stack A (b0de3f7) has the three fields that the minimal core removed.
module FakeStackA
module ProximalSolvers
struct CDSolver{R}
  maxpasses::Int
  tol::Float64
  random::Bool
  relative::Bool
  anderson::Int
  momentum::Union{Nothing, Bool}
  rng::R
  gaptol::Float64
  gapsafe::Bool
end
end
end
module FakeStackB
module ProximalSolvers
struct CDSolver{R}
  maxpasses::Int
  tol::Float64
  random::Bool
  relative::Bool
  momentum::Union{Nothing, Bool}
  rng::R
end
end
end
fake_a(; tol = 1e-11, maxpasses = 100000, anderson = 0, gaptol = 0.0, gapsafe = false, rng = Xoshiro(9)) =
  FakeStackA.ProximalSolvers.CDSolver(maxpasses, tol, false, true, anderson, nothing, rng, gaptol, gapsafe)
fake_b(; tol = 1e-11, maxpasses = 100000, rng = Xoshiro(9)) =
  FakeStackB.ProximalSolvers.CDSolver(maxpasses, tol, false, true, nothing, rng)
function normalized(f)
  E.NORMALIZE_SOLVER[] = true
  try
    f()
  finally
    E.NORMALIZE_SOLVER[] = false
  end
end
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
# The last two payloads are structs of the loaded package: their digests follow the package's field layout, which
# the two stacks of #333 do not share, so they are checked for determinism and no longer pinned.
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
  )

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
  @testset "ProximalBase with and without AtomIterate (N2, #333)" begin
    # Loading the exporter at all is the first check: PB.AtomIterate is not defined by the minimal-core ProximalBase.
    @test E.HAS_ATOM_ITERATE == isdefined(PB, :AtomIterate)
    @test Vector{Float64} <: E.ITERATE_TYPES && Vector{Float32} <: E.ITERATE_TYPES && Matrix{Float64} <: E.ITERATE_TYPES
    @test PB.SparseIterate <: E.ITERATE_TYPES && PB.SparseIterate <: E.WORKING_SET_TYPES
    @test !(Vector{Float64} <: E.WORKING_SET_TYPES)
    @test (E.HAS_ATOM_ITERATE ? PB.AtomIterate <: E.ITERATE_TYPES && PB.AtomIterate <: E.WORKING_SET_TYPES : true)
    @test E.active_ids(PB.SparseIterate(4)) == Int[] && E.active_ids(zeros(3)) === nothing
  end
  @testset "the solver fingerprint of the successor campaign (O1, #333)" begin
    # Off by default and for every other campaign: the stack A layout differs from the stack B layout.
    @test !E.NORMALIZE_SOLVER[] && fp(fake_a()) != fp(fake_b())
    # Positive: with inert values the three removed fields are omitted and the rows are identical.
    @test normalized(() -> fp(fake_a())) == normalized(() -> fp(fake_b()))
    @test normalized(() -> fp(fake_a(tol = 1e-6, maxpasses = 7))) == normalized(() -> fp(fake_b(tol = 1e-6, maxpasses = 7)))
    # Negative, each field: a value that is not exactly the inert one fails closed (no row), only when normalizing.
    for bad in (fake_a(anderson = 1), fake_a(gaptol = 1e-8), fake_a(gapsafe = true), fake_a(gaptol = -0.0))
      @test normalized(() -> rejects(bad))
      @test hex64(fp(bad))
    end
    # Negative: every shared field still counts, the RNG state included.
    @test normalized(() -> fp(fake_a(tol = 1e-10))) != normalized(() -> fp(fake_b()))
    @test normalized(() -> fp(fake_a(maxpasses = 5))) != normalized(() -> fp(fake_b()))
    @test normalized(() -> fp(fake_a(rng = Xoshiro(10)))) != normalized(() -> fp(fake_b()))
    @test normalized(() -> fp(fake_a())) != normalized(() -> fp(fake_b(tol = 1e-10)))
    # Only CDSolver is touched: other structs of the package are encoded as before.
    @test normalized(() -> fp(PS.ProximalOptions(maxiter = 100))) == fp(PS.ProximalOptions(maxiter = 100))
    # The loaded package: a real CDSolver of either stack matches the stack B layout built from its shared fields.
    real = PS.CDSolver(order = :cyclic, tol = 1e-11, rng = Xoshiro(9))
    shared = (; (n => getfield(real, n) for n in fieldnames(typeof(real)) if !(n in keys(E.REMOVED_CD_FIELDS)))...)
    as_b = FakeStackB.ProximalSolvers.CDSolver(shared.maxpasses, shared.tol, shared.random, shared.relative,
                                               shared.momentum, shared.rng)
    @test normalized(() -> fp(real)) == normalized(() -> fp(as_b))
    # Which schedules switch it on: the successor and no other.
    @test E.read_schedule(CD_SCHEDULE).campaign_id in E.NORMALIZED_CAMPAIGNS
    @test !(E.read_schedule(joinpath(@__DIR__, "schedule.toml")).campaign_id in E.NORMALIZED_CAMPAIGNS)
    @test E.NORMALIZED_CAMPAIGNS == ("stage2b-cd-minimal-core-v1",)
  end
  @testset "solver and option structs" begin
    @test fp(PS.ProximalOptions(maxiter = 100)) != fp(PS.ProximalOptions(maxiter = 101))
    @test fp(PS.ProximalOptions(gradtol = 1e-10)) != fp(PS.ProximalOptions(gradtol = 1e-8))
    @test fp(PS.ProximalOptions(maxiter = 100)) == fp(PS.ProximalOptions(maxiter = 100))
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
      if haskey(KNOWN, label)
        @test E.fingerprint("fixture", label, payload) == KNOWN[label]
      else
        again = Dict(known_payloads())[label]
        @test E.fingerprint("fixture", label, payload) == E.fingerprint("fixture", label, again)
        @test hex64(E.fingerprint("fixture", label, payload))
      end
    end
  end
end

# ---- 2. The real cases through the harness -----------------------------------------------------------
H = E.load_harness(HARNESS_DIR)
const CERT = E.hex_file(joinpath(HARNESS_DIR, "certificates.jl"))

const ALL_GROUPS = collect(String, H.CASE_GROUPS)
catalog_ids(H) = [String(s.meta.id) for s in H.build_catalog("extended", ALL_GROUPS)]
# What the catalog of this harness on this package offers decides which testsets apply.
const LEGACY = IDS.P02 in catalog_ids(H)          # the Stage 2A families (removed from the minimal core)
const CURRENT = CORE.dense in catalog_ids(H)      # the current-core cd cases
println("EXPORTER INFO harness cases: legacy families ", LEGACY, ", current-core cd cases ", CURRENT)
LEGACY || CURRENT || error("the harness offers neither the legacy nor the current-core cases")
# The cases the identity, command line and publication checks run on, and the one the layout checks use.
const CHECKED = LEGACY ? collect(IDS) : collect(CORE)
const FIRST = LEGACY ? IDS.P02 : CORE.dense

catalog_spec(H, id; groups = ALL_GROUPS) = first(s for s in H.build_catalog("extended", groups) if s.meta.id == id)
parts_of(H, spec, state = spec.make(1)) = E.extract_parts(H, spec.meta, state, CERT)
cell(result, kind, name) = first(v for (k, n, v) in result.rows if k == kind && n == name)
# A check closure that captures `exact`, as the check of a current-core case does (a function argument keeps its name;
# a local of a @testset does not).
check_with_exact(exact) = output -> exact
# A call! with the captured names the exporter reads (function arguments keep their names).
call_with(x, method, f, g) = () -> (x, method, f, g)
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
    for id in CHECKED
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
    spec = catalog_spec(H, FIRST)
    state = spec.make(1)
    @test getfield(state.reset!, :x) === getfield(state.call!, :x)
    @test getfield(state.reset!, :method) === getfield(state.call!, :method)
    @test E.family(spec.meta) == :call
    LEGACY && @testset "workspace and primal-dual closures (legacy)" begin
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
    CURRENT && @testset "current-core closures" begin
      for id in (CORE.dense, CORE.sparse32, CORE.release)
        spec = catalog_spec(H, id)
        state = spec.make(1)
        # the check closure of a current-core case captures the Float64 image `exact`, not `a`
        id == CORE.release || @test E.has_field(state.certify, :exact) && !E.has_field(state.certify, :a)
        @test id != CORE.release || E.has_field(state.certify, :a)
        parts = parts_of(H, spec, state)
        @test parts.family == :call && parts.iterate === getfield(state.call!, :x)
        @test parts.solver === getfield(state.call!, :method) && parts.options === nothing
        @test parts.iterate isa Union{Vector{Float64}, Vector{Float32}, PB.SparseIterate}
      end
    end
  end
  @testset "a second make is identical field by field" begin
    spec = catalog_spec(H, LEGACY ? IDS.P14 : CORE.warm_sparse)
    a1, a2 = parts_of(H, spec), parts_of(H, spec)
    @test [E.fingerprint("fixture", n, v) for (n, v) in E.fixture_items(a1)] ==
          [E.fingerprint("fixture", n, v) for (n, v) in E.fixture_items(a2)]
    names = first.(E.fixture_items(a1))
    @test (LEGACY ? "grid" in names : "start" in names) && "X" in names && issorted(names)
  end
  LEGACY && @testset "P14: the cold reset empties the working set" begin
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
  LEGACY && @testset "P04: the active groups are restored to the empty set" begin
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
  LEGACY && @testset "P13: the setup case has no iterate" begin
    spec = catalog_spec(H, IDS.P13)
    result = E.export_case(H, spec.meta, spec.make, 1, CERT)
    @test result.family == :setup
    @test cell(result, "reset", "values") == "none" && cell(result, "reset", "active_ids") == "none"
    descriptor = (; setup = "admm")
    @test cell(result, "config", "solver") == E.fingerprint("config", "solver", descriptor)
    @test cell(result, "config", "options") == E.fingerprint("config", "options", descriptor)
  end
  CURRENT && @testset "current core: the reset restores the start, working set included" begin
    for id in (CORE.sparse, CORE.warm_sparse, CORE.sparse32)
      spec = catalog_spec(H, id)
      state = spec.make(1)
      parts = parts_of(H, spec, state)
      x = parts.iterate
      @test x isa PB.SparseIterate
      before = E.snapshot_rows(parts, E.tls_copy())
      ids0 = sort!(collect(Int, PB.activecoordinates(x)))
      warm = occursin("/warm-", id)
      @test isempty(ids0) == !warm
      empty_set = E.fingerprint("reset", "active_ids", Int[])
      @test (before[("reset", "active_ids")] == empty_set) == !warm
      state.call!()
      used = E.snapshot_rows(parts, E.tls_copy())
      @test used[("reset", "values")] != before[("reset", "values")]    # a solve moves the iterate
      state.reset!()
      after = E.snapshot_rows(parts, E.tls_copy())
      @test after[("reset", "values")] == before[("reset", "values")]
      @test after[("reset", "active_ids")] == before[("reset", "active_ids")]
      @test sort!(collect(Int, PB.activecoordinates(x))) == ids0
      # Negative check: writing into the captured iterate after the reset changes the hash.
      x[3] = 1.5
      changed = E.snapshot_rows(parts, E.tls_copy())
      @test changed[("reset", "values")] != after[("reset", "values")]
      state.reset!()
      @test E.snapshot_rows(parts, E.tls_copy())[("reset", "values")] == before[("reset", "values")]
      result = E.export_case(H, spec.meta, spec.make, 1, CERT)
      @test cell(result, "reset", "values") == before[("reset", "values")]
      @test cell(result, "reset", "active_ids") == before[("reset", "active_ids")]
    end
    for id in (CORE.dense, CORE.dense32, CORE.warm)       # a dense iterate has no working set
      spec = catalog_spec(H, id)
      result = E.export_case(H, spec.meta, spec.make, 1, CERT)
      @test cell(result, "reset", "active_ids") == "none"
    end
  end
  CURRENT && @testset "current core: a Float32 problem is its Float64 image rounded back" begin
    spec = catalog_spec(H, CORE.dense32)
    state = spec.make(1)
    parts = parts_of(H, spec, state)
    @test eltype(parts.a.X) == Float32 && eltype(parts.a.y) == Float32 && eltype(parts.a.start) == Float32
    @test parts.a.s isa Float32 && parts.a.λ isa Float32
    @test H.data_hash(parts.a) == state.problem_hash
    exact = getfield(state.certify, :exact)
    @test eltype(exact.X) == Float64 && Float32.(exact.X) == parts.a.X
    spec64 = catalog_spec(H, CORE.dense)
    @test spec64.make(1).problem_hash != state.problem_hash
    @test E.fingerprint("fixture", "X", parts.a.X) != E.fingerprint("fixture", "X", Float64.(parts.a.X))
    # an image that is not an exact Float32 promotion fails closed, and so does an exact promotion of another problem
    for y in (exact.y .+ 1.0, Float64.(Float32.(exact.y) .+ 1f0))
      fake = H.CaseState(state.reset!, state.call!, check_with_exact(merge(exact, (; y))), state.problem_hash)
      err = try
        E.export_case(H, spec.meta, rep -> fake, 1, CERT)
        nothing
      catch e
        e
      end
      @test err isa E.VerifyError && (occursin("exact Float32 promotion", err.msg) || occursin("live y", err.msg))
    end
  end
  CURRENT && @testset "current core: the live solve inputs are bound to the problem (round-1 fix)" begin
    err_of(make, spec) = try
      E.export_case(H, spec.meta, make, 1, CERT)
      nothing
    catch e
      e
    end
    refused(err, text) = err isa E.VerifyError && occursin(text, err.msg)
    # Positive, the real cases: the live inputs are the problem's, before and after the untimed solve.
    for id in values(CORE)
      spec = catalog_spec(H, id)
      state = spec.make(1)
      parts = parts_of(H, spec, state)
      @test parts.live !== nothing
      @test parts.live() === nothing
      state.reset!(); state.call!()
      @test parts.live() === nothing
      @test E.check_data_hash(H, parts, state) == state.problem_hash
    end
    for id in (CORE.dense, CORE.dense32, CORE.warm_sparse)
      spec = catalog_spec(H, id)
      T = id == CORE.dense32 ? Float32 : Float64
      step = T === Float32 ? Float32(1e-5) : 1e-8
      # Negative: mutate the live objective data or start, the certificate copy and the stored hash stay as they are.
      mutations = [c -> (getfield(c.call!, :f).f.Y[1] += step),
                   c -> (getfield(c.call!, :f).f.X[1, 1] = nextfloat(getfield(c.call!, :f).f.X[1, 1])),
                   id == CORE.warm_sparse ? c -> (getfield(c.reset!, :start)[3] = T(1.5)) :
                                            c -> (getfield(c.reset!, :start)[1] += step)]
      for mutate! in mutations
        make = rep -> (c = spec.make(rep); mutate!(c); c)
        @test refused(err_of(make, spec), "live")
      end
      # Negative: another penalty, another scale, another objective or penalty type, in a fresh call! closure.
      real = spec.make(1)
      f, g, x, method = getfield(real.call!, :f), getfield(real.call!, :g), getfield(real.call!, :x),
                        getfield(real.call!, :method)
      swapped(f2, g2) = rep -> (c = spec.make(rep);
                                H.CaseState(c.reset!, call_with(getfield(c.call!, :x), getfield(c.call!, :method), f2, g2),
                                            c.certify, c.problem_hash))
      @test err_of(swapped(f, g), spec) === nothing                        # the stand-in layout itself is accepted
      @test refused(err_of(swapped(f, PB.NormL1(nextfloat(g.λ0))), spec), "live λ")
      @test refused(err_of(swapped(nextfloat(f.α) * f.f, g), spec), "live s")
      @test refused(err_of(swapped(f, ones(T, 2)), spec), "not a scaled least-squares loss")
      @test refused(err_of(swapped(zeros(T, 2), g), spec), "not a scaled least-squares loss")
    end
    # A dense start that is not the problem's start is refused as well.
    spec = catalog_spec(H, CORE.warm)
    make = rep -> (c = spec.make(rep); getfield(c.reset!, :start)[1] += 1e-8; c)
    @test refused(err_of(make, spec), "live start")
  end
  CURRENT && @testset "current core: the Float32 image must be an exact promotion (round-1 fix)" begin
    spec = catalog_spec(H, CORE.dense32)
    state = spec.make(1)
    exact = getfield(state.certify, :exact)
    for name in (:y, :X, :start, :w)
      tampered = copy(getproperty(exact, name))
      tampered[1] = nextfloat(tampered[1])            # below a Float32 ulp: Float32 rounding would hide it
      fake = H.CaseState(state.reset!, state.call!, check_with_exact(merge(exact, NamedTuple{(name,)}((tampered,)))),
                         state.problem_hash)
      err = try
        E.export_case(H, spec.meta, rep -> fake, 1, CERT)
        nothing
      catch e
        e
      end
      @test err isa E.VerifyError && occursin("exact Float32 promotion", err.msg)
    end
    for (name, value) in ((:s, nextfloat(exact.s)), (:λ, nextfloat(exact.λ)))
      @test_throws E.VerifyError E.core_problem_of("id", merge(exact, NamedTuple{(name,)}((value,))), Float32)
    end
    @test E.core_problem_of("id", exact, Float32).y == Float32.(exact.y)         # the real image is accepted
  end
  CURRENT && @testset "current core: the release case keeps the historical closure layout" begin
    spec = catalog_spec(H, CORE.release)
    state = spec.make(1)
    parts = parts_of(H, spec, state)
    @test E.has_field(state.call!, :own_options) && E.has_field(state.certify, :a)
    @test parts.options === nothing && parts.iterate isa Vector{Float64}
    @test spec.meta.inputs == "fixed" && isnan(spec.meta.target)
    result = E.export_case(H, spec.meta, spec.make, 1, CERT)
    @test cell(result, "config", "options") == E.fingerprint("config", "options", nothing)
  end
  CURRENT && isfile(CD_SCHEDULE) && @testset "the successor schedule lists exactly the cd cases of this harness" begin
    sched = E.read_schedule(CD_SCHEDULE)
    ids = [String(s.meta.id) for s in H.build_catalog(sched.suite, String.(split(sched.groups, ',')))]
    @test length(ids) == 21 && sort(ids) == sort(String.(split(sched.case_filter, ',')))
  end
  @testset "the certificate file is part of the identity" begin
    spec = catalog_spec(H, LEGACY ? IDS.D04 : CORE.dense)
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
        spec2 = catalog_spec(H2, spec.meta.id)
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
    spec = catalog_spec(H, FIRST)
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
    LEGACY && @test_throws E.VerifyError E.export_case(H, catalog_spec(H, IDS.P13).meta, rep -> real, 1, CERT)
    # a Float32 problem is rebuilt from its Float64 image only for the element types the harness rounds to
    @test_throws E.VerifyError E.core_problem_of("id", (; X = zeros(1, 1)), Float16)
    @test_throws E.VerifyError E.core_problem_of("id", (; X = zeros(1, 1)), Float32)
    # an iterate of an unexpected type
    @test_throws E.VerifyError E.check_iterate("id", view(zeros(3), 1:2), "x")
  end
end

# ---- 3. The command line -----------------------------------------------------------------------------
function write_schedule(path, ids; reps = [1, 2])
  open(path, "w") do io
    TOML.print(io, Dict("schedule" => Dict("reps" => reps, "campaign_id" => "export-test"),
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
    ids = collect(CHECKED)
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
    # The cold snapshot hashes are persisted next to the warm ones.
    for entry in summary["case"]
      for label in ("reset_values", "reset_active_ids", "config_solver", "config_options", "file_certificates_jl")
        @test hex64(entry["cold_" * label]) || entry["cold_" * label] == "none"
        @test entry["equal_" * label] == (entry["cold_" * label] == entry["warm_" * label])
      end
      @test entry["cold_equals_warm"] == all(entry["equal_" * l] for l in ("reset_values", "reset_active_ids", "config_solver", "config_options"))
      warm = [r[6] for r in rows if r[2] == entry["id"] && r[3] == string(entry["rep"]) && r[4] == "reset" && r[5] == "values"]
      @test entry["warm_reset_values"] == only(warm)
    end
    by = Dict((e["id"], e["rep"]) => e for e in summary["case"])
    @test by[(FIRST, 1)]["cold_equals_warm"] && by[(FIRST, 1)]["cold_reset_values"] == by[(FIRST, 1)]["warm_reset_values"]
    # Every recorded difference carries two different hashes, and the cold hash is the encoding of the cold state.
    for entry in summary["case"]
      entry["cold_equals_warm"] && continue
      @test entry["cold_reset_values"] != entry["warm_reset_values"]
    end
    p04 = LEGACY ? by[(IDS.P04, 1)] : nothing
    if LEGACY && !p04["cold_equals_warm"]
      zeros_cold = E.fingerprint("reset", "values", (; iterate = (; type = "AtomIterate", values = zeros(32)), rng = nothing))
      @test p04["cold_reset_values"] == zeros_cold && p04["warm_reset_values"] != zeros_cold
    end
  end
end

publish_ok = run_group("atomic publication") do
  listing(dir) = sort(readdir(dir; join = false))
  mktempdir() do dir
    a, b, c = joinpath(dir, "o.tsv"), joinpath(dir, "o.tsv.datahash.tsv"), joinpath(dir, "o.tsv.summary.toml")
    items = [(a, b"A"), (b, b"B"), (c, b"C")]
    @test E.publish!(items) === nothing
    @test listing(dir) == sort(basename.([a, b, c])) && read(a) == b"A" && read(c) == b"C"
    rm.([a, b, c])
    # a regular file appears at the second final name after the checks
    before_state = listing(dir)
    err = try
      E.publish!(items; before = n -> n == 2 && write(b, "mine"))
      nothing
    catch e
      e
    end
    @test err isa E.VerifyError
    @test listing(dir) == sort([basename(b)]) && read(b, String) == "mine"
    rm(b)
    # a dangling symlink appears at the third final name: never followed, never deleted
    ghost = joinpath(dir, "ghost")
    err = try
      E.publish!(items; before = n -> n == 3 && symlink(ghost, c))
      nothing
    catch e
      e
    end
    @test err isa E.VerifyError
    @test listing(dir) == [basename(c)] && islink(c) && !ispath(ghost) && readlink(c) == ghost
    rm(c)
    @test listing(dir) == before_state
    # pre-existing files are kept when the first publication fails
    write(a, "old")
    err = try
      E.publish!(items)
      nothing
    catch e
      e
    end
    @test err isa E.VerifyError && read(a, String) == "old" && listing(dir) == [basename(a)]
  end
  # staging write failure after the second temporary was exclusively created: nothing is left behind
  mktempdir() do dir
    a, b, c = joinpath(dir, "o.tsv"), joinpath(dir, "o.tsv.datahash.tsv"), joinpath(dir, "o.tsv.summary.toml")
    items = [(a, b"A"), (b, b"B"), (c, b"C")]
    write(joinpath(dir, "keep"), "x")
    count = Ref(0)
    E.STAGE_HOOK[] = path -> (count[] += 1; count[] == 2 && error("injected write failure"))
    err = try
      E.publish!(items)
      nothing
    catch e
      e
    finally
      E.STAGE_HOOK[] = nothing
    end
    @test err !== nothing && count[] == 2
    @test sort(readdir(dir)) == ["keep"]
    # the same failure through the command line
    schedule = joinpath(dir, "schedule.toml")
    write_schedule(schedule, [FIRST]; reps = [1])
    count[] = 0
    E.STAGE_HOOK[] = path -> (count[] += 1; count[] == 2 && error("injected write failure"))
    code, _ = try
      cli(dir, "w.tsv", schedule; reps = "1")
    finally
      E.STAGE_HOOK[] = nothing
    end
    @test code != 0 && sort(readdir(dir)) == ["keep", "schedule.toml"]
  end
  # temporary names: not drawn from the default RNG, different even after the RNG is re-seeded
  mktempdir() do dir
    path = joinpath(dir, "o.tsv")
    Random.seed!(7)
    n1 = E.temporary_name(path)
    Random.seed!(7)
    n2 = E.temporary_name(path)
    @test n1 != n2 && dirname(n1) == dir && startswith(basename(n1), ".fp-o.tsv.")
    Random.seed!(11)
    state = copy(Random.default_rng())
    E.publish!([(path, b"A")])
    @test copy(Random.default_rng()) == state
    @test readdir(dir) == ["o.tsv"]
  end
  # through the command line: a sidecar appearing between the existence check and the publication
  mktempdir() do dir
    schedule = joinpath(dir, "schedule.toml")
    write_schedule(schedule, [FIRST]; reps = [1])
    out = joinpath(dir, "z.tsv")
    for (n, target) in ((2, out * ".datahash.tsv"), (3, out * ".summary.toml"))
      E.PUBLISH_HOOK[] = i -> i == n && symlink(joinpath(dir, "nowhere"), target)
      code, _ = try
        cli(dir, "z.tsv", schedule; reps = "1")
      finally
        E.PUBLISH_HOOK[] = nothing
      end
      @test code == 2
      @test listing(dir) == sort(["schedule.toml", basename(target)]) && islink(target)
      rm(target)
    end
    code, _ = cli(dir, "z.tsv", schedule; reps = "1")
    @test code == 0 && length(listing(dir)) == 4
  end
end

# ---- 4. The full scheduled export (opt-in) -----------------------------------------------------------
full_ok = !FULL || run_group("full scheduled export, repetitions 1-2") do
  schedule = SCHEDULE
  sched = E.read_schedule(schedule)
  ids = String.(split(sched.case_filter, ','))
  @test length(ids) == length(unique(ids)) && !isempty(ids)
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
    @test length(unique(r[2] for r in rows)) == length(ids)
    println("EXPORTER INFO full export: ", length(rows), " rows, ", length(ids), " cases, repetitions 1-2")
  end
end

passed = encoder_ok & harness_ok & cli_ok & publish_ok & full_ok
println("FINGERPRINT EXPORTER TEST: ", passed ? "PASS" : "FAIL")
exit(passed ? 0 : 1)
