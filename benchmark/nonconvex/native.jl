# Native replacements, using the plain-array starts prepared by legacy.jl.
include("common.jl")
using ProximalBase, ProximalSolvers

struct LatentLoss{T} <: AbstractFunction
    kind::Symbol
    A::Matrix{T}
    B::Matrix{T}
end
ProximalBase.issmooth(::Type{<:LatentLoss}) = true

function (f::LatentLoss)(x::Tuple)
    S, U = x
    theta = Matrix(S) + U * U'
    if f.kind == :logdet
        F = cholesky(Symmetric(theta); check = false)
        issuccess(F) || return Inf
        return dot(f.A, theta) - 2sum(log, diag(F.U))
    end
    dot(theta, f.A * theta * f.B) / 2 + dot(f.A - f.B, theta)
end

function ProximalBase.value_and_gradient!(G::Tuple, f::LatentLoss, x::Tuple)
    S, U = x
    theta = Matrix(S) + U * U'
    if f.kind == :logdet
        F = cholesky(Symmetric(theta); check = false)
        if !issuccess(F)
            fill!(G[1], NaN); fill!(G[2], NaN)
            return Inf
        end
        G[1] .= f.A .- inv(F)
        mul!(G[2], G[1], U, 2.0, 0.0)
        return dot(f.A, theta) - 2sum(log, diag(F.U))
    end
    product = f.A * theta * f.B
    G[1] .= (product .+ product') ./ 2 .+ f.A .- f.B
    mul!(G[2], G[1], U, 2.0, 0.0)
    dot(theta, product) / 2 + dot(f.A - f.B, theta)
end
ProximalBase.gradient!(G::Tuple, f::LatentLoss, x::Tuple) = (value_and_gradient!(G, f, x); G)

const METHODS = (("PG", ProximalGradientDescent()),
                 ("normalized_PG", ProximalGradientDescent(; normalized = true)),
                 ("monotone_APG", MonotoneAccProxGradDescent()))

function native(d, method)
    if d.kind == :dtrace
        x = SymmetricSparseIterate(d.S0)
        f, g = KronQuadratic(d.A, d.B, d.A - d.B), IndBallL0(d.s)
    else
        x = (SymmetricSparseIterate(d.S0), copy(d.U0))
        f = LatentLoss(d.kind == :logdet ? :logdet : :dtrace, d.A, d.B)
        g = SeparableSum(IndBallL0(d.s; diagonal = d.diagonal), ZeroFunction())
    end
    opt = ProximalOptions(; maxiter = MAXITER, ftol = TOL, xtol = 1e-12, gradtol = 1e-8,
                           store_trace = true, time_limit = 30.0)
    initial_value = f(x) + g(x)
    result = solve!(x, f, g, method, opt)
    S, U = d.kind == :dtrace ? (Matrix(x), zeros(d.p, 0)) : (Matrix(x[1]), Matrix(x[2]))
    values = [initial_value; [state.fg_x for state in result.trace]]
    S, U, values, result.iterations, ProximalSolvers.converged(result)
end

function main()
    cases = deserialize(joinpath(ROOT, "cases.jls"))
    solutions = Any[]
    # Compile each method/problem shape separately from the timed repetitions.
    for d in cases[1:min(3, length(cases))], (_, method) in METHODS
        try
            native(d, method)
        catch
            # The measured call below retains the full failure diagnostic.
        end
    end
    open(joinpath(ROOT, "native.tsv"), "w") do io
        record(io, HEADER)
        for d in cases, round in 1:ROUNDS
            # Reverse the native-method order to reduce systematic drift.
            methods = isodd(round) ? METHODS : reverse(METHODS)
            for (label, method) in methods
                try
                    elapsed = @elapsed S, U, values, iterations, converged = native(d, method)
                    F = objective(d, S, U)
                    jump, finite = trace_diagnostics(values)
                    pd = d.kind != :logdet || isposdef(Symmetric(S + U * U'))
                    record(io, (d.name, d.p, d.s, d.rank, label, round, NaN, elapsed,
                        iterations, F, jump, finite, pd, support_string(S, d.diagonal), "returned", "converged=$converged; same legacy-prepared start"))
                    push!(solutions, (; problem = d.name, p = d.p, round, method = label, S, U, objective = F))
                catch err
                    record(io, (d.name, d.p, d.s, d.rank, label, round, NaN, NaN,
                        -1, Inf, Inf, false, false, "", "error", sprint(showerror, err)))
                end
            end
        end
    end
    serialize(joinpath(ROOT, "native_solutions.jls"), solutions)
    data = deserialize(joinpath(ROOT, "regression.jls"))
    n, p = size(data.X)
    f, g = (1 / n) * LeastSquaresLoss(data.y, data.X), IndBallL0(data.s)
    regression_methods = (METHODS..., ("normalized_PG_debias", ProximalGradientDescent(; normalized = true, debias = 3)))
    open(joinpath(ROOT, "native_regression.tsv"), "w") do io
        record(io, ("solver", "round", "seconds", "iterations", "objective", "support", "support_matches_truth", "status", "detail"))
        warmed = Dict{String, Bool}()
        for (label, method) in regression_methods
            try
                solve!(zeros(p), f, g, method, ProximalOptions(; maxiter = min(MAXITER, 20)))
                warmed[label] = true
            catch err
                warmed[label] = false
                record(io, (label, 0, NaN, -1, Inf, "", false, "warmup_error", sprint(showerror, err)))
            end
        end
        for round in 1:ROUNDS, (label, method) in regression_methods
            warmed[label] || continue
            try
                x = zeros(p)
                elapsed = @elapsed res = solve!(x, f, g, method,
                    ProximalOptions(; maxiter = MAXITER, ftol = TOL, xtol = 1e-12, gradtol = 1e-8, time_limit = 30.0))
                support = findall(!iszero, x)
                record(io, (label, round, elapsed, res.iterations, f(x), join(support, ';'),
                            support == data.support, "returned", "centered X and y; implicit optimal intercept zero"))
            catch err
                record(io, (label, round, NaN, -1, Inf, "", false, "error", sprint(showerror, err)))
            end
        end
    end
    println("NATIVE_COMPARISON_COMPLETE")
end
main()
