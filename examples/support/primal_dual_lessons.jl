module PrimalDualLessons

# Reference algorithms for the lecture examples, not additional package API.
using LinearAlgebra, SparseArrays, Random, ProximalBase, ProximalSolvers
export graph_problem, trend_problem, objective, certificate, native_solve,
       split_admm, trend_admm, first_difference

first_difference(p) = spdiagm(p - 1, p, 0 => -ones(p - 1), 1 => ones(p - 1))

function graph_problem(side = 12; seed = 1500 + side)
    rng = MersenneTwister(seed)
    p = side^2
    edges = Set{Tuple{Int,Int}}()
    for j in 1:side, i in 1:side
        k = i + (j - 1) * side
        i < side && push!(edges, (k, k + 1))
        j < side && push!(edges, (k, k + side))
    end
    # The shortcuts break the chain/grid structure; sort for reproducibility.
    for _ in 1:div(p, 4)
        i, j = rand(rng, 1:p, 2)
        i != j && push!(edges, minmax(i, j))
    end
    e = sort!(collect(edges))
    D = sparse(repeat(1:length(e); inner = 2),
               collect(Iterators.flatten(e)), repeat([-1.0, 1.0], length(e)), length(e), p)
    n = div(p, 2)
    X = sparse(rand(rng, 1:n, 8p), repeat(1:p; inner = 8), randn(rng, 8p) / sqrt(8), n, p)
    truth = [i <= div(side, 2) && j <= div(side, 2) ? 2.0 :
             i > div(side, 2) && j > div(side, 2) ? -1.0 : 0.0 for i in 1:side, j in 1:side][:]
    b = X * truth + 0.25randn(rng, n)
    μ, λ1, λ2 = 0.2, 0.05, 0.2
    f = Sum(LeastSquaresLoss(b, X), SqrNormL2(μ))
    # ||X||₂² <= ||X||₁ ||X||∞: no SVD or normal matrix is needed.
    L = opnorm(X, 1) * opnorm(X, Inf) + μ
    (; name = "graph", X, b, D, μ, λ1, λ2, f, L, truth, p)
end

function trend_problem(p = 240; seed = 1600 + p)
    rng = MersenneTwister(seed)
    t = collect(range(0, 1; length = p))
    truth = @. 1 + 3t - 5max(t - 0.25, 0) + 6max(t - 0.6, 0)
    b = truth + 0.2randn(rng, p)
    B = first_difference(p)
    D = first_difference(p - 1) * B
    # These are unscaled differences on the index grid, not derivatives in t.
    (; name = "trend", X = nothing, b, D, μ = 1.0, λ1 = 0.0, λ2 = 8.0,
       f = SqrNormL2(1.0, b), L = 1.0, truth, p)
end

objective(a, x) = a.f(x) + a.λ1 * sum(abs, x) + a.λ2 * sum(abs, a.D * x)

"""
An upper bound on objective suboptimality from a feasible graph/difference
dual and the μ-strongly convex quadratic lower model of f. The lecture derives
this formula. Clipping constructs a feasible dual, including for ADMM iterates.
"""
function certificate(a, x, y)
    yf = clamp.(y, -a.λ2, a.λ2)
    grad = similar(x)
    fx = value_and_gradient!(grad, a.f, x)
    d = a.D' * yf
    z = prox(NormL1(a.λ1), x - (grad + d) / a.μ, 1 / a.μ)
    lower = fx + dot(grad, z - x) + a.μ / 2 * sum(abs2, z - x) +
            a.λ1 * sum(abs, z) + dot(d, z)
    primal = fx + a.λ1 * sum(abs, x) + a.λ2 * sum(abs, a.D * x)
    scale = max(1.0, abs(primal), abs(lower))
    raw = primal - lower
    raw >= -1e-10 * scale || error("negative certificate: $raw")
    gap = max(0.0, raw) # tolerate roundoff only; do not conceal invalid bounds
    (; primal, lower, gap, relative = gap / scale,
       distance_bound = sqrt(2gap / a.μ), dual = yf)
end

function native_solve(a; tol = 1e-6, adaptive = true, maxiter = 200_000, time_limit = 15.0)
    setup = @elapsed begin
        g, h = NormL1(a.λ1), NormL1(a.λ2)
        L = a.X === nothing ? a.L : opnorm(a.X, 1) * opnorm(a.X, Inf) + a.μ
        normD = sqrt(opnorm(a.D, 1) * opnorm(a.D, Inf))
        method = CondatVu(; L, normD, adaptive, restart = adaptive)
        options = ProximalOptions(; maxiter, gaptol = tol, gapevery = 25, time_limit)
        gap = (x, y) -> certificate(a, x, y).relative
        x = zeros(a.p)
    end
    seconds = @elapsed res = solve!(x, a.f, g, h, a.D, method, options; gap)
    cert = certificate(a, x, res.y)
    (; x, y = cert.dual, cert, iterations = res.iterations,
       converged = res.converged && cert.relative <= tol, setup, seconds,
       factor_nnz = 0)
end

# Ordinary two-block ADMM: z = Cx, where C stacks I and D if λ1 > 0.
# Every x step solves the same system; factor it once per solve.
function split_admm(a; ρ = 1.0, tol = 1e-6, maxiter = 200_000, time_limit = 15.0)
    setup = @elapsed begin
        p = a.p
        C = a.λ1 > 0 ? [sparse(I, p, p); a.D] : a.D
        weights = a.λ1 > 0 ? [fill(a.λ1, p); fill(a.λ2, size(a.D, 1))] : fill(a.λ2, size(C, 1))
        H = a.X === nothing ? sparse(I, p, p) : a.X' * a.X + a.μ * I
        rhs0 = a.X === nothing ? a.b : a.X' * a.b
        factor = cholesky(Symmetric(H + ρ * (C' * C)))
        x = zeros(p); z = zeros(size(C, 1)); u = similar(z); fill!(u, 0)
        cx = similar(z); v = similar(z); rhs = similar(x)
        penalty = NormL1(1.0, weights)
    end
    factor_nnz = nnz(sparse(factor.L)) # diagnostic, outside setup/solve timing
    iterations = 0
    converged = false
    started = time_ns()
    seconds = @elapsed for k in 1:maxiter
        @. v = z - u
        mul!(rhs, C', v)
        @. rhs = rhs0 + ρ * rhs
        # CHOLMOD's in-place solve is unavailable in the supported Julia 1.10.
        @static if VERSION >= v"1.13"
            ldiv!(x, factor, rhs)
        else
            copyto!(x, factor \ rhs)
        end
        mul!(cx, C, x)
        @. v = cx + u
        prox!(z, penalty, v, 1 / ρ)
        @. u = u + cx - z
        iterations = k
        if k % 25 == 0
            y = ρ .* view(u, length(u) - size(a.D, 1) + 1:length(u))
            if certificate(a, x, y).relative <= tol
                converged = true
                break
            end
            (time_ns() - started) / 1e9 >= time_limit && break
        end
    end
    y = ρ .* view(u, length(u) - size(a.D, 1) + 1:length(u))
    cert = certificate(a, x, y)
    (; x, y = cert.dual, cert, iterations, converged = converged || cert.relative <= tol,
       setup, seconds, factor_nnz)
end

# Specialized trend-filtering ADMM (Ramdas & Tibshirani): α = Bx and
# ||D₂x||₁ = TV(α). A direct TV prox replaces scalar thresholding.
function trend_admm(a; ρ = a.λ2, tol = 1e-6, maxiter = 200_000, time_limit = 15.0)
    a.name == "trend" || throw(ArgumentError("requires the unweighted chain problem"))
    setup = @elapsed begin
        p = a.p
        B = first_difference(p)
        factor = cholesky(SymTridiagonal([1 + ρ; fill(1 + 2ρ, p - 2); 1 + ρ], fill(-ρ, p - 1)))
        x = zeros(p); α = zeros(p - 1); u = zeros(p - 1)
        bx = similar(α); v = similar(α); rhs = similar(x)
        tv = TotalVariation1D(a.λ2)
    end
    converged = false
    iterations = 0
    started = time_ns()
    seconds = @elapsed for k in 1:maxiter
        @. v = α - u
        mul!(rhs, B', v)
        @. rhs = a.b + ρ * rhs
        copyto!(x, rhs); ldiv!(factor, x)
        mul!(bx, B, x)
        @. v = bx + u
        prox!(α, tv, v, 1 / ρ)
        @. u = u + bx - α
        iterations = k
        if k % 25 == 0
            # B_(p-1)' y = ρu at a TV proximal step; integration recovers y.
            y = -cumsum(ρ .* u)[1:end-1]
            if certificate(a, x, y).relative <= tol
                converged = true
                break
            end
            (time_ns() - started) / 1e9 >= time_limit && break
        end
    end
    y = -cumsum(ρ .* u)[1:end-1]
    cert = certificate(a, x, y)
    (; x, y = cert.dual, cert, iterations, converged = converged || cert.relative <= tol,
       setup, seconds, factor_nnz = 2a.p - 1)
end

end # module
