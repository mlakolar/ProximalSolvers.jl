# Summarize existing solutions inside the same Discovery Slurm allocation.
# This never refits a model. Support disagreements are retained, not repaired.
include("common.jl")
cases = deserialize(joinpath(ROOT, "cases.jls"))
legacy = deserialize(joinpath(ROOT, "legacy_solutions.jls"))
native = deserialize(joinpath(ROOT, "native_solutions.jls"))
# Failed native calls have no solution object; their complete diagnostics stay
# in native.tsv and are counted by the separate raw-TSV aggregation.
support_count(d, S) = count(!iszero(S[r, c]) for c in axes(S, 2) for r in c:size(S, 1)
                            if d.diagonal || r != c)
function feasible_reference(d, row)
    isfinite(row.objective) && all(isfinite, row.S) && all(isfinite, row.U) &&
        issymmetric(row.S) && support_count(d, row.S) <= d.s && size(row.U, 2) <= d.rank &&
        (d.kind != :logdet || isposdef(Symmetric(row.S + row.U * row.U')))
end
open(joinpath(ROOT, "legacy_reference_rejections.tsv"), "w") do io
    record(io, ("problem", "p", "round", "step_factor", "objective", "support_count", "support_budget", "status"))
    for row in legacy
        d = first(filter(x -> x.name == row.problem && x.p == row.p, cases))
        feasible_reference(d, row) && continue
        record(io, (row.problem, row.p, row.round, row.factor, row.objective,
                    support_count(d, row.S), d.s, "ineligible_reference"))
    end
end
open(joinpath(ROOT, "native_vs_legacy.tsv"), "w") do io
    record(io, ("problem", "p", "solver", "round", "native_objective", "best_fixed_step_objective",
                "native_minus_legacy_relative", "same_support", "native_support", "legacy_support", "native_no_worse", "status", "detail"))
    for row in native
        d = first(filter(x -> x.name == row.problem && x.p == row.p, cases))
        matches = filter(x -> x.problem == row.problem && x.p == row.p && feasible_reference(d, x), legacy)
        if isempty(matches)
            record(io, (row.problem, row.p, row.method, row.round, row.objective, Inf, NaN, false,
                        support_string(row.S, d.diagonal), "", false, "unavailable_legacy_reference",
                        "no finite feasible legacy result; inspect legacy.tsv and legacy_reference_rejections.tsv"))
            continue
        end
        reference = matches[argmin(getproperty.(matches, :objective))]
        a, b = support_string(row.S, d.diagonal), support_string(reference.S, d.diagonal)
        delta = (row.objective - reference.objective) / max(1.0, abs(reference.objective))
        record(io, (row.problem, row.p, row.method, row.round, row.objective, reference.objective,
                    delta, a == b, a, b, delta <= 1e-8, "compared",
                    "legacy best over recorded fixed-step grid; nonconvex local solutions may differ"))
    end
end
println("NONCONVEX_COMPARISON_SUMMARIZED")
