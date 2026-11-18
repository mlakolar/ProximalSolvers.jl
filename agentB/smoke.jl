include(joinpath(@__DIR__, "instr_load.jl"))
Random.seed!(1)
n,p = 100, 50
X = randn(n,p); y = randn(n)
f = LeastSquaresLoss(y, X); g = NormL1(0.1*maximum(abs.(X'*y)))
x = zeros(p)
cnt_reset!()
r = solve!(x, f, g, CDSolver(order=:cyclic, momentum=false, tol=1e-9))
println(r.passes, " ", r.converged); println(cnt_snapshot())
