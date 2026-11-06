# Test of the reset of the path cases (#110 Stage 2B): P14 is paths/lasso/cd/grid8/call, and
# the two SLOPE paths share its state builder. The reset must return the iterate to the same
# empty start on ProximalBase 0.5.4 and on the 0.6 development line.
#
# From the repository root, in an environment that provides the benchmark dependencies
# (benchmark/Project.toml) and Test:
#   JULIA_NUM_THREADS=1 julia --project=ENV benchmark/campaigns/stage2b/test_p14_reset.jl
#
# Nothing here is timed and no check depends on a duration. The script exits non-zero when a
# check fails and prints `P14 RESET TEST: PASS` or `P14 RESET TEST: FAIL` as its last line.

using Test, Random, LinearAlgebra, SparseArrays
import ProximalBase, ProximalSolvers

# The harness, loaded as run.jl does for a campaign: problems, certificates, cases, run.
module P14Harness
include(joinpath(@__DIR__, "..", "..", "run.jl"))
end
const H = P14Harness
const PB = ProximalBase

println("P14 RESET TEST: ProximalBase ", pkgversion(PB), ", ProximalSolvers ",
        pkgversion(ProximalSolvers), ", Julia ", VERSION, ", threads ", Threads.nthreads())

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
  println("P14 GROUP ", name, ": ", passed ? "PASS" : "FAIL")
  passed
end

working_set(x) = sort!(collect(Int, PB.activecoordinates(x)))
values_of(x) = collect(Float64, x)
bits(v) = collect(reinterpret(UInt64, collect(Float64, v)))

# Used SparseIterates of size 32: written values, explicitly stored zeros, a mixture, empty.
function used_iterate(kind)
  x = PB.SparseIterate(32)
  if kind in (:values, :mixture)
    for (i, v) in ((3, 1.5), (17, -2.0), (22, 0.25), (30, 4.0))
      x[i] = v
    end
  end
  if kind in (:stored_zeros, :mixture)
    for i in (5, 11, 27)
      x[i] = 2.0
      x[i] = 0.0   # the coordinate stays active with the value zero
    end
  end
  x
end

# ---- 1. The helper on bare SparseIterates ---------------------------------------------------
sparse_ok = run_group("sparse iterate reset") do
  fresh = PB.SparseIterate(32)
  for kind in (:values, :stored_zeros, :mixture, :empty)
    @testset "$kind" begin
      x = used_iterate(kind)
      kind == :empty ? (@test PB.nactive(x) == 0) : (@test PB.nactive(x) > 0)
      # Informational: the historical reset alone, on this ProximalBase version.
      historic = copy(x)
      fill!(historic, 0.0)
      println("P14 INFO sparse $kind: fill!(x, 0.0) alone leaves nactive = ", PB.nactive(historic),
              kind == :empty || PB.nactive(historic) == 0 ? "" : " (the working set is kept)")
      returned = H.clear_path_iterate!(x)
      @test returned === x
      @test all(iszero, values_of(x))
      @test PB.nactive(x) == 0
      @test isempty(PB.activecoordinates(x))
      @test values_of(x) == values_of(fresh) && working_set(x) == working_set(fresh)
      H.clear_path_iterate!(x)   # a second reset changes nothing
      @test all(iszero, values_of(x)) && PB.nactive(x) == 0 && isempty(PB.activecoordinates(x))
      @test values_of(x) == values_of(fresh) && working_set(x) == working_set(fresh)
      # The cleared iterate is usable and equal to a fresh one after a new write.
      x[7] = 1.0
      fresh_written = PB.SparseIterate(32)
      fresh_written[7] = 1.0
      @test values_of(x) == values_of(fresh_written) && working_set(x) == working_set(fresh_written)
    end
  end
end

# ---- 2. The dense iterate of the SLOPE paths, and unsupported types ---------------------------
dense_ok = run_group("dense iterate reset and unsupported types") do
  v = collect(range(-1.0, 2.0; length = 32))
  @test any(!iszero, v)
  returned = H.clear_path_iterate!(v)
  @test returned === v
  @test all(iszero, v) && length(v) == 32 && v isa Vector{Float64}
  H.clear_path_iterate!(v)
  @test all(iszero, v)
  @test_throws ArgumentError H.clear_path_iterate!(ones(4, 4))
  @test_throws ArgumentError H.clear_path_iterate!("not an iterate")
end

# ---- 3. The real cases through the harness catalog ------------------------------------------
case_ids = ("paths/lasso/cd/grid8/call", "paths/slope/slope-apg/grid8/call",
            "paths/slope/slope-hybrid/grid8/call")

# A path output as plain data, copied before the next call can change anything it aliases.
function snapshot(output, slope)
  levels = slope ? output.lambda : output.λ
  (; levels = collect(Float64, levels), solutions = [collect(Float64, β) for β in output.solutions])
end

function same_path(a, b)
  bits(a.levels) == bits(b.levels) && length(a.solutions) == length(b.solutions) &&
    all(bits(x) == bits(y) for (x, y) in zip(a.solutions, b.solutions))
end

function certified(spec, state, output)
  cert = state.certify(output)
  (; status = H.certificate_status(cert, spec.meta), cert_status = cert.status,
     value = cert.value, target = spec.meta.target)
end

cases_ok = run_group("real path cases: reset then call repeats the first call") do
  catalog = H.build_catalog("quick", ["paths"])
  by_id = Dict(spec.meta.id => spec for spec in catalog)
  for id in case_ids
    haskey(by_id, id) || (@test haskey(by_id, id); continue)
    spec = by_id[id]
    slope = startswith(id, "paths/slope/")
    for rep in (1, 2)
      @testset "$id rep $rep" begin
        state = spec.make(rep)
        hash = state.problem_hash
        first_out = state.call!()
        first = snapshot(first_out, slope)
        c1 = certified(spec, state, first_out)
        @test c1.status == :ok && c1.cert_status == :ok && c1.value <= c1.target
        @test !isempty(first.solutions)
        for _ in 1:2   # the second and third call, each after a reset
          state.reset!()
          out = state.call!()
          again = snapshot(out, slope)
          @test same_path(first, again)
          c = certified(spec, state, out)
          @test c.status == :ok && c.cert_status == :ok && c.value <= c.target
        end
        @test state.problem_hash == hash
        @test spec.make(rep).problem_hash == hash
        println("P14 INFO ", id, " rep ", rep, ": ", length(first.solutions), " levels, certified ",
                spec.meta.measure, " ", round(c1.value; sigdigits = 3), " <= ", c1.target)
      end
    end
  end
end

# ---- 4. The solver RNG returns to its seed state --------------------------------------------
rng_ok = run_group("solver RNG reset") do
  method = H.benchmark_method("cd", "tight")
  expected = rand(Xoshiro(9))
  first_draw = rand(method.rng)
  rand(method.rng, 17)   # advance the generator further
  H.reset_solver_rng!(method)
  second_draw = rand(method.rng)
  @test first_draw == expected
  @test second_draw == expected
end

passed = sparse_ok & dense_ok & cases_ok & rng_ok
println("P14 RESET TEST: ", passed ? "PASS" : "FAIL")
exit(passed ? 0 : 1)
