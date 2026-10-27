# Small CPU diagnostics; run with the same environment as performance.jl.
using ProximalBase, ProximalSolvers, LinearAlgebra, SparseArrays, Random
const PS = ProximalSolvers
BLAS.set_num_threads(1)

function measure(label, op; batch = 20)
    op(); op()
    samples = [@timed(for _ in 1:batch; op(); end) for _ in 1:7]
    a = samples[argmin(getproperty.(samples, :time))]
    println(label, '\t', a.time / batch, '\t', a.bytes / batch)
end

function cd_stages(label, f, g, start, check)
    method = CDSolver(order = :cyclic, tol = 1e-11, maxpasses = 5000)
    runone() = solve!(copy(start), f, g, method)
    r = runone()
    residual = check(r.minimizer)
    println("CHECK\t", label, '\t', r.converged, '\t', r.minimum, '\t', residual)
    @assert r.converged && residual < 1e-7
    measure(label * "/complete-cold-fit", runone)
    x = copy(r.minimizer)
    m = cdmodel(f, x)
    PS.initialize!(m, x)
    onepass = CDSolver(order = :cyclic, tol = 0, maxpasses = 1)
    st = PS._CDState(eltype(x), x, onepass)
    measure(label * "/model-construction", () -> cdmodel(f, x))
    measure(label * "/initialize", () -> PS.initialize!(m, x))
    measure(label * "/warmed-pass", () -> PS._cd!(x, m, g, st, onepass))
end

function main()
    rng = Xoshiro(90211)
    n, p, q = 64, 24, 3
    X = randn(rng, n, p)
    y = X[:, 1:3] * [1., -.7, .3] + .1randn(rng, n)
    groups = [k:k+3 for k in 1:4:p]
    g = GroupNormL2(.08, groups, ones(length(groups)))
    f = (1/n) * LeastSquaresLoss(y, X)
    groupcheck(x) = maximum(groups) do G
        grad = X' * (X * Vector(x) - y) / n
        a = Vector(x)[G]; na = norm(a)
        na == 0 ? max(norm(grad[G]) - .08, 0) : norm(grad[G] + .08a / na)
    end
    println("stage\tseconds_min7_per_call\tbytes_per_call")
    cd_stages("atom-group-LS-64x24", f, g, AtomIterate(Float64, p, groups), groupcheck)
    Y = hcat(y, .7y + .1randn(rng, n), -.4y + .1randn(rng, n))
    rows = [collect(k:p:p*q) for k in 1:p]
    gm = GroupNormL2(.08, rows, ones(p))
    fm = (1/n) * LeastSquaresLoss(Y, X)
    matrixcheck(x) = maximum(1:p) do k
        B = reshape(Vector(x), p, q); grad = X' * (X * B - Y) / n
        a = B[k, :]; na = norm(a)
        na == 0 ? max(norm(grad[k, :]) - .08, 0) : norm(grad[k, :] + .08a / na)
    end
    cd_stages("matrix-row-group-LS-64x24x3", fm, gm,
              AtomIterate(Float64, p*q, rows), matrixcheck)
    A = spdiagm(-1 => fill(-.1, p-1), 0 => fill(2., p), 1 => fill(-.1, p-1))
    b = randn(rng, p); fq = QuadraticFunction(A, b); gq = NormL1(.08)
    scalarcheck(x) = norm(Vector(x) - sign.(Vector(x) - (A * Vector(x) + b)) .*
                           max.(abs.(Vector(x) - (A * Vector(x) + b)) .- .08, 0), Inf)
    cd_stages("CSC-quadratic-24", fq, gq, SparseIterate(p), scalarcheck)
    k = 8; U = randn(rng, k, k); V = randn(rng, k, k)
    S, T = U'U/k + I, V'V/k + I
    C = randn(rng, k, k); fk = KronQuadratic(S, T, C)
    kroncheck(x) = begin
        v = Vector(x); grad = vec(S * reshape(v, k, k) * T + C)
        norm(v - sign.(v-grad) .* max.(abs.(v-grad) .- .08, 0), Inf)
    end
    cd_stages("Kronecker-8x8", fk, gq, SparseIterate(k*k), kroncheck)

    # Identical bounded iteration counts isolate intentional history/callback work.
    fixed = (maxiter = 20, ftol = floatmin(Float64), xtol = floatmin(Float64), gradtol = floatmin(Float64), allow_f_increases = true)
    reporting_iterations = Int[]
    for (name, kw) in (("disabled", (;)), ("history", (;store_trace = true)),
                       ("extended-history", (;store_trace = true, extended_trace = true)),
                       ("callback", (;callback = _ -> false)))
        opts = ProximalOptions(; fixed..., kw...)
        r = solve!(zeros(p), f, NormL1(.05), AccProxGradDescent(), opts)
        push!(reporting_iterations, r.iterations)
        println("REPORTING_ITERATIONS\t", name, '\t', r.iterations)
        measure("reporting/" * name, () -> solve!(zeros(p), f, NormL1(.05), AccProxGradDescent(), opts))
    end
    @assert allequal(reporting_iterations)
    path() = solve_path(f, NormL1(1.), [.2, .1, .05], CDSolver(order = :cyclic, tol = 1e-11))
    saved = path()
    @assert all(saved.converged)
    for (lambda, x) in zip(saved.λ, saved.solutions)
        v = Vector(x); grad = X' * (X*v-y)/n
        @assert norm(v - sign.(v-grad) .* max.(abs.(v-grad) .- lambda, 0), Inf) < 1e-7
    end
    measure("path/three-owned-solutions", path)
    ws = SolverWorkspace(zeros(p), f, NormL1(.05), AccProxGradDescent(),
                         ProximalOptions(maxiter=5000,ftol=1e-14,xtol=1e-14,gradtol=1e-9,gaptol=1e-8))
    rw = solve!(ws)
    v = Vector(rw.minimizer); grad = X' * (X*v-y)/n
    fixedpoint = norm(v - sign.(v-grad) .* max.(abs.(v-grad) .- .05, 0), Inf)
    @assert rw.converged && rw.gap <= 1e-8 && fixedpoint < 1e-7
    println("CHECK\tworkspace\t", rw.converged, '\t', rw.gap, '\t', fixedpoint)
    start = zeros(p)
    measure("workspace/reinit", () -> reinit!(ws, start))
    # Start from the same coefficients each time; include the small result object.
    measure("workspace/reinit-and-solve", () -> (reinit!(ws, start); solve!(ws)))
end
main()
