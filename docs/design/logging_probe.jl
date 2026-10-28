# Behavioral evidence for solver_logging.md. Written against ProximalSolvers 34f26a8;
# updated for 0.2.0, which renamed `printEvery` to `print_every`.
# Run with a resolved package environment:
#   julia --startup-file=no --project=. docs/design/logging_probe.jl
# These assertions describe the existing API, not the proposed API.
using Test, LinearAlgebra, ProximalBase, ProximalSolvers

function capture_stdout(f)
    mktemp() do _, io
        result = redirect_stdout(f, io)
        flush(io)
        seekstart(io)
        return result, read(io, String)
    end
end

function problem()
    QuadraticFunction(Matrix(Diagonal([1.0, 10.0, 100.0])), [-1.0, -1.0, -1.0]), NormL1(0.1)
end

@testset "Existing solver progress behavior" begin
    f, g = problem()
    for store_trace in (false, true)
        calls = Int[]
        cb = record -> begin
            state = store_trace ? last(record) : record
            push!(calls, state.iteration)
            @test (record isa AbstractVector) == store_trace
            length(calls) == 2
        end
        options = ProximalOptions(; callback=cb, store_trace, print_every=2,
                                 ftol=1e-300, xtol=1e-300, gradtol=1e-300)
        result = solve!(zeros(3), f, g, ProximalGradientDescent(), options)
        @test calls == [2, 4]
        @test result.iterations == 4
        @test length(result.trace) == (store_trace ? 4 : 0)
        println("PG store_trace=", store_trace, ": callback iterations=", calls,
                ", stored rows=", length(result.trace))
    end

    calls = Ref(0)
    options = ProximalOptions(; maxiter=8, store_trace=true,
                             callback=(_ -> (calls[] += 1; true)))
    result = solve!(zeros(3), f, g, ADMMSolver(), options)
    @test result.iterations > 0
    @test calls[] == 0
    @test !hasproperty(result, :trace)
    println("ADMM: callback calls=", calls[], ", trace field=", hasproperty(result, :trace))

    quiet = solve!(zeros(3), f, g, ADMMSolver(), ProximalOptions(; maxiter=8))
    loud, _ = capture_stdout() do
        solve!(zeros(3), f, g, ADMMSolver(), ProximalOptions(; maxiter=8, show_trace=true))
    end
    @test quiet.minimizer == loud.minimizer
    @test quiet.iterations == loud.iterations
    @test quiet.prox_calls == loud.prox_calls
    @test quiet.f_calls == 1
    @test loud.f_calls == loud.iterations + 1
    println("ADMM: quiet objective f calls=", quiet.f_calls,
            ", displayed objective f calls=", loud.f_calls)

    result, output = capture_stdout() do
        solve!(zeros(2), SqrNormL2(1.0, ones(2)), NormL1(0.1),
               ProximalGradientDescent(), ProximalOptions(; show_trace=true, print_every=100))
    end
    @test result.converged
    @test result.iterations < 100
    @test occursin("Function value", output)
    @test !occursin(r"(?m)^\s*\d+\s", output)
    println("PG: converged at iteration ", result.iterations,
            ", printed numeric rows before show interval=0")

    # The keyword dispatcher selects the continuation driver, which has a
    # required continuation keyword and no per-pass callback contract.
    @test_throws UndefKeywordError solve!(SparseIterate(3), f, g, CDSolver(); callback=(_ -> false))
    println("CD: per-pass callback keyword rejected")
end
println("Runtime: Julia ", VERSION)
