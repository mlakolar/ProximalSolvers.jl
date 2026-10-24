# Optional reference. Run in an environment containing MendelIHT, after
# legacy.jl --prepare has written the common centered regression data.
# API verified against https://github.com/OpenMendel/MendelIHT.jl/blob/master/src/fit.jl
include("common.jl")

# Resolve the optional module before defining main. Importing it from inside
# main can leave its binding newer than the function's world age, even when
# fit_iht itself is called through invokelatest.
const MENDEL_LOAD = try
    if Base.find_package("MendelIHT") === nothing
        (package = nothing, error = "MendelIHT is not installed in this environment")
    else
        @eval import MendelIHT
        (package = getglobal(@__MODULE__, :MendelIHT), error = nothing)
    end
catch err
    (package = nothing, error = sprint(showerror, err))
end

function main()
    data = deserialize(joinpath(ROOT, "regression.jls"))
    open(joinpath(ROOT, "mendel_regression.tsv"), "w") do io
        record(io, ("solver", "round", "seconds", "iterations", "objective", "support", "support_matches_truth", "status", "detail"))
        if MENDEL_LOAD.package === nothing
            record(io, ("MendelIHT", 0, NaN, -1, Inf, "", false, "unavailable", MENDEL_LOAD.error))
            return
        end
        mendel = MENDEL_LOAD.package
        # Centered X and y make the intercept's least-squares optimum zero.
        # Keep MendelIHT's documented intercept and record its effect through
        # the independently evaluated residual when the field is exposed.
        fit(debias, max_iter) = Base.invokelatest(getglobal(mendel, :fit_iht), data.y, data.X; k = data.s,
            debias, memory_efficient = !debias, verbose = false, init_beta = false,
            max_iter, tol = 1e-8, max_step = 3)
        warmed = Dict{Bool, Bool}()
        for debias in (false, true)
            try
                # Warm both branches long enough to reach support debiasing,
                # which the reference enables only after its first iterations.
                fit(debias, min(MAXITER, 30))
                warmed[debias] = true
            catch err
                warmed[debias] = false
                record(io, ("MendelIHT_debias_$debias", 0, NaN, -1, Inf, "", false,
                            "warmup_error", "memory_efficient=$(!debias); " * sprint(showerror, err)))
            end
        end
        for round in 1:ROUNDS, debias in (false, true)
            warmed[debias] || continue
            try
                elapsed = @elapsed result = fit(debias, MAXITER)
                beta = Vector(result.beta)
                intercept = hasproperty(result, :c) ? first(result.c) : 0.0
                F = sum(abs2, data.y .- data.X * beta .- intercept) / (2length(data.y))
                support = findall(!iszero, beta)
                iterations = hasproperty(result, :iter) ? result.iter :
                             hasproperty(result, :iterations) ? result.iterations : -1
                record(io, ("MendelIHT_debias_$debias", round, elapsed, iterations, F, join(support, ';'),
                    support == data.support, "returned", "version=$(pkgversion(mendel)); memory_efficient=$(!debias); intercept=$intercept"))
            catch err
                record(io, ("MendelIHT_debias_$debias", round, NaN, -1, Inf, "", false, "error",
                            "memory_efficient=$(!debias); " * sprint(showerror, err)))
            end
        end
    end
    println("MENDEL_COMPARISON_COMPLETE")
end
main()
