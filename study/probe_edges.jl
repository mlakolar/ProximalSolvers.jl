# Status at the edges: no pass, a zero threshold, λ ≥ λmax, y = 0, a start at the solution, combined flags.
include(joinpath(@__DIR__, "lib.jl"))
setprecision(BigFloat, PREC)
println("Julia ", VERSION)
name, X0, y0 = fixture("gauss")
for T in (Float64, Float32)
  X, y = T.(X0), T.(y0); n, p = size(X)
  λmax = maximum(abs, Float64.(X)' * Float64.(y))
  f = LeastSquaresLoss(y, X)
  show1(tag, r, msgs) = @printf("%s %-34s converged=%-5s passes=%-6d maxchange=%-10.3g tolerance=%-10.3g gap=%-5s minimum=%.6g warnings=%d %s\n", T, tag, r.converged, r.passes, r.maxchange, r.tolerance, string(r.gap), r.minimum, length(msgs), isempty(msgs) ? "" : first(msgs[1], 70))
  for (tag, g, s, x0) in (("cd maxpasses=0", NormL1(T(0.1λmax)), CDSolver(maxpasses = 0, order = :cyclic), zeros(T, p)),
                         ("cd tol=0", NormL1(T(0.1λmax)), CDSolver(tol = 0, order = :cyclic, maxpasses = 1000), zeros(T, p)),
                         ("cd λ=2λmax cold", NormL1(T(2λmax)), CDSolver(order = :cyclic), zeros(T, p)),
                         ("cd λ=2λmax from ones", NormL1(T(2λmax)), CDSolver(order = :cyclic), ones(T, p)),
                         ("cd maxpasses=1", NormL1(T(0.1λmax)), CDSolver(maxpasses = 1, order = :cyclic), zeros(T, p)))
    x = copy(x0)
    r, msgs = capture(() -> solve!(x, f, g, s))
    show1(tag, r, msgs)
  end
  x = zeros(T, p)
  r, msgs = capture(() -> solve!(x, LeastSquaresLoss(zeros(T, n), X), NormL1(T(1)), CDSolver(order = :cyclic)))
  show1("cd y=0 cold", r, msgs)
  x = ones(T, p)
  r, msgs = capture(() -> solve!(x, LeastSquaresLoss(zeros(T, n), X), NormL1(zero(T)), CDSolver(order = :cyclic)))
  show1("cd y=0 λ=0 from ones", r, msgs)
  # sqrt lasso
  x = zeros(T, p)
  r, msgs = capture(() -> solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(T(0.3 * λmax / norm(Float64.(y)))), CDSolver(order = :cyclic, maxpasses = 0)))
  show1("sqrt maxpasses=0", r, msgs)
  x = zeros(T, p)
  r, msgs = capture(() -> solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(T(0.3 * λmax / norm(Float64.(y)))), CDSolver(order = :cyclic, maxpasses = 2)))
  show1("sqrt maxpasses=2", r, msgs)
  # PGD / APG
  show2(tag, r) = @printf("%s %-34s converged=%-5s iters=%-5d x=%s f=%s g=%s f_increased=%s at_maxiter=%s stagnated=%s grad_calls=%d\n", T, tag, r.converged, r.iterations, r.x_converged, r.f_converged, r.grad_converged, r.f_increased, r.iteration_converged, r.stagnated, r.grad_calls)
  for (sn, m) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent()))
    for (tag, g, o, x0) in (("λ=2λmax cold default", NormL1(T(2λmax)), ProximalOptions(), zeros(T, p)),
                            ("λ=2λmax cold ftol=0", NormL1(T(2λmax)), ProximalOptions(ftol = 0), zeros(T, p)),
                            ("λ=2λmax from ones ftol=0", NormL1(T(2λmax)), ProximalOptions(ftol = 0, maxiter = 2000), ones(T, p)),
                            ("λ=0.1λmax maxiter=2", NormL1(T(0.1λmax)), ProximalOptions(maxiter = 2), zeros(T, p)))
      x = copy(x0)
      show2(sn * " " * tag, quiet(() -> solve!(x, f, g, m, o)))
    end
    x = zeros(T, p)
    show2(sn * " y=0 λ=0", quiet(() -> solve!(x, LeastSquaresLoss(zeros(T, n), X), NormL1(zero(T)), m, ProximalOptions())))
    x = zeros(T, p)
    show2(sn * " y=0 λ=1", quiet(() -> solve!(x, LeastSquaresLoss(zeros(T, n), X), NormL1(one(T)), m, ProximalOptions())))
  end
end
