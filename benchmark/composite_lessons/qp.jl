# Independent epigraph QP formulation. Residual variables preserve the sparse
# design rather than explicitly expanding X'X in the model.
import JuMP, HiGHS

function qp_solve(a; tol = 1e-6)
    setup = @elapsed begin
        m = JuMP.Model(HiGHS.Optimizer)
        JuMP.set_silent(m)
        JuMP.set_attribute(m, "threads", 1)
        JuMP.set_attribute(m, "primal_feasibility_tolerance", 1e-9)
        JuMP.set_attribute(m, "dual_feasibility_tolerance", 1e-9)
        JuMP.set_attribute(m, "time_limit", 60.0)
        JuMP.@variable(m, x[1:a.p])
        JuMP.@variable(m, v[1:size(a.D, 1)])
        plus = JuMP.@constraint(m, v .>= a.D * x)
        minus = JuMP.@constraint(m, v .>= -a.D * x)
        if a.X === nothing
            loss = sum((x[i] - a.b[i])^2 for i in 1:a.p) / 2
        else
            JuMP.@variable(m, r[1:length(a.b)])
            JuMP.@constraint(m, r .== a.X * x - a.b)
            loss = sum(r .^ 2) / 2 + a.μ * sum(x .^ 2) / 2
        end
        if a.λ1 > 0
            JuMP.@variable(m, t[1:a.p])
            JuMP.@constraint(m, t .>= x)
            JuMP.@constraint(m, t .>= -x)
            loss += a.λ1 * sum(t)
        end
        JuMP.@objective(m, Min, loss + a.λ2 * sum(v))
    end
    seconds = @elapsed JuMP.optimize!(m)
    JuMP.is_solved_and_feasible(m; dual = true) || error("QP reference failed: $(JuMP.termination_status(m))")
    xv = JuMP.value.(x)
    y = JuMP.dual.(plus) - JuMP.dual.(minus)
    cert = certificate(a, xv, y)
    (; x = xv, y = cert.dual, cert, iterations = missing,
       converged = cert.relative <= tol, setup, seconds, factor_nnz = missing)
end
