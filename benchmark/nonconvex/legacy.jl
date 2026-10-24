# Run in a separate process/environment bound to CovarianceSelection edba5de.
# --prepare writes plain-array starts from the ORIGINAL legacy initializers.
# The actual measured calls use the original exported/internal routines.
include("common.jl")
using ProximalBase
import CovarianceSelection
const CS = CovarianceSelection

function prepare()
    cases = Any[]
    for p in SIZES
        A, B = covariance_pair(p)
        s, rank = max(p, 2p - 1), 2
        push!(cases, (kind = :dtrace, name = "dtrace", p = p, s = s, rank = 0,
                      A = A, B = B, S0 = zeros(p, p), U0 = zeros(p, 0), diagonal = true))
        delta, _, U, _, _ = CS.differenceLatentPrecisionIHT_init(Symmetric(A), Symmetric(B), s, rank)
        push!(cases, (kind = :latent_dtrace, name = "latent_dtrace", p = p, s = s, rank = rank,
                      A = A, B = B, S0 = Matrix(delta), U0 = Matrix(U), diagonal = true))
        soff = max(2, p ÷ 2)
        # maxIter=0 returns exactly the initializer of the original routine.
        S, _, U, _, _ = CS.covselLatentIHT!(A, 0.0, 0.0, soff, rank; maxIter = 0)
        push!(cases, (kind = :logdet, name = "latent_logdet", p = p, s = soff, rank = rank,
                      A = A, B = B, S0 = Matrix(S), U0 = Matrix(U), diagonal = false))
    end
    serialize(joinpath(ROOT, "cases.jls"), cases)
    serialize(joinpath(ROOT, "regression.jls"), regression_data())
    println("LEGACY_STARTS_PREPARED cases=", length(cases))
end

function run_legacy(d, factor)
    A, B, p = Symmetric(d.A), Symmetric(d.B), d.p
    if d.kind == :dtrace
        eta = factor / (opnorm(A) * opnorm(B))
        S, values = CS.differencePrecisionIHT(A, B, eta, d.s; epsTol = TOL, maxIter = MAXITER)
        return Matrix(S), zeros(p, 0), values, length(values) - 1
    elseif d.kind == :latent_dtrace
        eta = factor / (opnorm(A) * opnorm(B) * max(1.0, 4norm(d.U0)^2))
        S, U = SymmetricSparseIterate(d.S0), copy(d.U0)
        L = U * U'
        out = CS.differenceLatentPrecisionIHT!(S, L, U, zeros(p, p), zeros(p, d.rank),
            A, B, eta, eta, d.s, d.rank;
            options = CS.IHTOptions(; epsTol = TOL, maxIter = MAXITER, checkEvery = 1))
        return Matrix(out[1]), Matrix(out[3]), out[4], out[5]
    end
    initial = d.S0 + d.U0 * d.U0'
    eta = factor * eigmin(Symmetric(initial))^2 / max(1.0, 4norm(d.U0)^2)
    out = CS.covselLatentIHT!(d.A, eta, eta, d.s, d.rank;
                             epsTol = TOL, maxIter = MAXITER, checkEvery = 1)
    Matrix(out[1]), Matrix(out[3]), out[4], out[5]
end

function main()
    if "--prepare" in ARGS
        prepare()
        return
    end
    cases = deserialize(joinpath(ROOT, "cases.jls"))
    solutions = Any[]
    for d in cases[1:min(3, length(cases))]
        try
            run_legacy(d, first(STEP_FACTORS))
        catch
            # The measured call below retains the full failure diagnostic.
        end
    end
    open(joinpath(ROOT, "legacy.tsv"), "w") do io
        record(io, HEADER)
        for d in cases, round in 1:ROUNDS, factor in STEP_FACTORS
            try
                elapsed = @elapsed S, U, values, iterations = run_legacy(d, factor)
                F = objective(d, S, U)
                jump, finite = trace_diagnostics(values)
                pd = d.kind != :logdet || isposdef(Symmetric(S + U * U'))
                record(io, (d.name, d.p, d.s, d.rank, "legacy_fixed", round, factor, elapsed,
                    iterations, F, jump, finite, pd, support_string(S, d.diagonal), "returned", "frozen edba5de"))
                push!(solutions, (; problem = d.name, p = d.p, round, factor, S, U, objective = F))
            catch err
                record(io, (d.name, d.p, d.s, d.rank, "legacy_fixed", round, factor, NaN,
                    -1, Inf, Inf, false, false, "", "error", sprint(showerror, err)))
            end
        end
    end
    serialize(joinpath(ROOT, "legacy_solutions.jls"), solutions)
    println("LEGACY_COMPARISON_COMPLETE")
end
main()
