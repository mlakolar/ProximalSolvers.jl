# ttfx_child.jl <solver> <T>: one fresh process, default path. Prints one TTFX line.
t_load = @elapsed using ProximalSolvers
using ProximalBase: LeastSquaresLoss, NormL1
using Random
solver, T = ARGS[1], ARGS[2] == "Float32" ? Float32 : Float64
rng = Xoshiro(1)
X = T.(randn(rng, 50, 20)); y = T.(randn(rng, 50))
m = solver == "pgd" ? ProximalGradientDescent() : AccProxGradDescent()
t_setup = @elapsed (f = (one(T) / T(50)) * LeastSquaresLoss(y, X); g = NormL1(T(0.1)))
x1 = zeros(T, 20)
t_first = @elapsed (r1 = solve!(x1, f, g, m))
x2 = zeros(T, 20)
t_second = @elapsed (r2 = solve!(x2, f, g, m))
println("TTFX_ROW ", solver, " ", T, " load=", t_load, " setup=", t_setup, " first_solve=", t_first, " second_solve=", t_second,
        " iters=", r1.iterations)
