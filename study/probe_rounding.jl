# Ordinary-range rounding cases raised by the review of the first draft (run with the master tree or
# with the X1 tree as the project; TREE names it):
#  A. the correlation Xᵀy cancels to 0 in working precision (X = [1, d, −1], y = 1, d = eps/2, λ = d/8);
#  B. a warm start with a large component in the null space of X ([M, −M] for X = [1 1]);
#  C. the product-underflow input of F1 under the strict options;
#  D. APG under a gradient-call limit.
# For the CD results, wp_kkt is the KKT residual a working-precision gate would compute (fresh residual
# in T, normalized by max(λ, computed λmax)), and stat is the pre-step statistic max_k g_k/√(a_k) in the
# units of the change test, with the threshold tol‖y‖ of the default tol.
include(joinpath(@__DIR__, "lib.jl"))
setprecision(BigFloat, PREC)
const TREE = length(ARGS) > 0 ? ARGS[1] : "master"
println("Julia ", VERSION, ", tree ", TREE, ", package ", pkgdir(ProximalSolvers) == nothing ? "" : basename(pkgdir(ProximalSolvers)))
strict() = ProximalOptions(maxiter = 2000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11)
function wp(X::Matrix{T}, y, λ, x) where T
  r = y - X * x
  grad = -(X' * r)
  G = maximum(k -> iszero(x[k]) ? max(abs(grad[k]) - λ, zero(T)) : abs(grad[k] + λ * sign(x[k])), eachindex(x))
  S = max(λ, maximum(abs, X' * y))
  stat = maximum(k -> (iszero(x[k]) ? max(abs(grad[k]) - λ, zero(T)) : abs(grad[k] + λ * sign(x[k]))) / sqrt(sum(abs2, X[:, k])), eachindex(x))
  G / S, stat, T(1e-7) * norm(y)
end
function report(tag, X::Matrix{T}, y, λ, x0, xs) where T
  R = LassoRef(X, y, one(T), λ, zero(T))
  ms = measures(R, xs)
  f, g = LeastSquaresLoss(y, X), NormL1(λ)
  for (name, run) in (("cd", x -> solve!(x, f, g, CDSolver(order = :cyclic, momentum = false))),
                      ("pgd", x -> solve!(x, f, g, ProximalGradientDescent())),
                      ("apg", x -> solve!(x, f, g, AccProxGradDescent())),
                      ("pgd-strict", x -> solve!(x, f, g, ProximalGradientDescent(), strict())),
                      ("apg-strict", x -> solve!(x, f, g, AccProxGradDescent(), strict())))
    x = copy(x0)
    r = quiet(() -> run(x))
    m = measures(R, x)
    its = r isa PS.CDResults ? r.passes : r.iterations
    extra = ""
    if name == "cd"
      k, st, th = wp(X, y, λ, x)
      extra = @sprintf(" | wp_kkt = %.3g, stat = %.3g against threshold %.3g", k, st, th)
    end
    @printf("%s %s %-10s converged = %-5s its = %-5d exact ‖G‖∞/max(λ, λmax) = %.4g, (F − F*)/F* = %.3g%s\n", tag, T, name, r.converged, its,
            Float64(m.G / max(R.l1, R.λmax)), Float64((m.F - ms.F) / ms.F), extra)
  end
end
for T in (Float64, Float32)
  d = eps(T) / 2
  X = reshape(T[1, d, -1], 3, 1); y = ones(T, 3); λ = d / 8
  xs = [(big(d) - big(λ)) / (2 + big(d)^2)]
  @printf("A %s: computed Xᵀy = %s, exact = %.3g, λ = %.3g\n", T, string(sum(vec(X) .* y)), Float64(d), Float64(λ))
  report("A", X, y, λ, zeros(T, 1), xs)
  M = T === Float32 ? T(2)^20 : T(2)^49
  X = ones(T, 1, 2); y = T[1 / 64]; λ = T(1 / 1024)
  report("B", X, y, λ, T[M, -M], BigFloat[big(15) / 1024, 0])
end
for (T, ex, ey, el) in ((Float64, -500, -700, 300), (Float32, -70, -90, 90))
  X = fill(ldexp(T(1), ex), 2, 1); y = fill(ldexp(T(1), ey), 2); α = ldexp(T(1), el)
  λ = T(ldexp(1.0, el + ex + ey)) * T(2) / 8
  for (name, m) in (("pgd-strict", ProximalGradientDescent()), ("apg-strict", AccProxGradDescent()))
    x = zeros(T, 1)
    r = quiet(() -> solve!(x, α * LeastSquaresLoss(y, X), NormL1(λ), m, strict()))
    @printf("C %s %-10s x = %s converged = %s iterations = %d\n", T, name, string(x[1]), r.converged, r.iterations)
  end
end
let X = reshape([2.0^-27], 1, 1), y = [2.0^-28]
  for limit in (0, 344)
    x = [1.0]
    r = quiet(() -> solve!(x, LeastSquaresLoss(y, X), NormL1(0.0), AccProxGradDescent(),
                           ProximalOptions(ftol = 0, xtol = 1e-300, gradtol = 1e-5, maxiter = 1000, allow_f_increases = true, grad_calls_limit = limit)))
    @printf("D grad_calls_limit = %d: x = %.16g converged = %s iterations = %d grad_calls = %d call_limit_reached = %s\n", limit, x[1], r.converged, r.iterations, r.grad_calls, r.call_limit_reached)
  end
end
