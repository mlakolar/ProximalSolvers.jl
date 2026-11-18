# the core_regressions.jl:528-540 case, under whatever src is checked out
using ProximalSolvers, ProximalBase, LinearAlgebra
const PS = ProximalSolvers
include(joinpath(@__DIR__, "fixture_defs.jl"))
method = ProximalGradientDescent()
X, y = pgd_fixture(); f = (1 / 7) * LeastSquaresLoss(y, X)
st = pgd_trial(f, NormL1(0.), zeros(3), 1e157); st.f_x_previous -= 10
d = st.x .- st.x_previous
println("xy_sq=", PS._norm(d)^2, " sum(abs2,d)=", sum(abs2, d), " floatmin=", floatmin(Float64))
acc = PS.LineSearches.backtrack!(st, method.ls, f, NormL1(0.))
println("accepted=", acc, " verifications=", st.verifications, " L=", st.L, " backtrack_simple=", st.backtrack_simple, " grad_calls=", st.grad_calls)
